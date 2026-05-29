//! Instruction decoder.
//!
//! Pure function: bytes in, `(Insn, length)` out. No CPU or memory state
//! flows through here so the same decoder can drive execution, a future
//! disassembler, and any coverage tooling.

use crate::insn::{EffectiveAddress, Insn, Operand, Reg16, Reg32, Reg8};
use crate::Fault;

/// Decode one instruction from `bytes` starting at offset 0.
///
/// On success returns the decoded instruction and the number of bytes it
/// consumed. The length is `u8` because an x86 instruction is at most 15
/// bytes — see Intel SDM Vol. 2 "Instruction Length Limit".
pub fn decode(bytes: &[u8]) -> Result<(Insn, u8), Fault> {
    let b0 = *bytes.first().ok_or(Fault::DecodeTruncated)?;
    // 0x66 is the operand-size override prefix. With it, opcodes that
    // would normally be 32-bit become their 16-bit variants.
    let (operand_size_16, rest) = if b0 == 0x66 {
        (true, &bytes[1..])
    } else {
        (false, bytes)
    };
    let prefix_len = u8::from(operand_size_16);

    let opcode = *rest.first().ok_or(Fault::DecodeTruncated)?;
    let (insn, body_len) = match (operand_size_16, opcode) {
        // mov r8, imm8 — opcode B0+rb ib. Per DESIGN.md, this encoding
        // wasn't in movfuscator output (it widens byte moves to 32-bit)
        // and used to trap; llvm-mov's CodeGen does emit it, so we
        // accept the form here per DESIGN's "fill the gap when it
        // actually fires" stance.
        (false, 0xB0..=0xB7) => {
            let dst = Reg8::from_index(opcode - 0xB0);
            let imm = *rest.get(1).ok_or(Fault::DecodeTruncated)?;
            (
                Insn::Mov {
                    dst: Operand::Reg8(dst),
                    src: Operand::Imm8(imm),
                },
                2,
            )
        }
        // mov r32, imm32 — opcode B8+rd id (no 16-bit override path used)
        (false, 0xB8..=0xBF) => {
            let dst = Reg32::from_index(opcode - 0xB8);
            let imm = read_u32_le(rest, 1)?;
            (
                Insn::Mov {
                    dst: Operand::Reg32(dst),
                    src: Operand::Imm32(imm),
                },
                5,
            )
        }
        (false, 0x88) => decode_mov_rm_r_8(rest, /* dir_to_reg */ false)?,
        (false, 0x89) => decode_mov_rm_r_32(rest, /* dir_to_reg */ false)?,
        (false, 0x8A) => decode_mov_rm_r_8(rest, /* dir_to_reg */ true)?,
        (false, 0x8B) => decode_mov_rm_r_32(rest, /* dir_to_reg */ true)?,
        (false, 0xC6) => decode_mov_rm8_imm8(rest)?,
        (false, 0xC7) => decode_mov_rm32_imm32(rest)?,
        // moffs MOV forms (A0/A1/A2/A3, 5 bytes) — short encodings of
        // mov al/ax/eax to/from an absolute address. See decode_moffs.
        (false, 0xA0..=0xA3) | (true, 0xA1 | 0xA3) => decode_moffs(opcode, operand_size_16, rest)?,
        // 16-bit variants: 66 89 /r and 66 8B /r
        (true, 0x89) => decode_mov_rm_r_16(rest, /* dir_to_reg */ false)?,
        (true, 0x8B) => decode_mov_rm_r_16(rest, /* dir_to_reg */ true)?,
        // jmp rel32 — opcode E9 cd
        (false, 0xE9) => {
            let off = read_i32_le(rest, 1)?;
            (Insn::JmpRel32(off), 5)
        }
        // int imm8 — opcode CD ib
        (false, 0xCD) => {
            let n = *rest.get(1).ok_or(Fault::DecodeTruncated)?;
            (Insn::Int(n), 2)
        }
        // push r32 — opcode 50+rd
        (false, 0x50..=0x57) => {
            let r = Reg32::from_index(opcode - 0x50);
            (Insn::PushR32(r), 1)
        }
        // pop r32 — opcode 58+rd
        (false, 0x58..=0x5F) => {
            let r = Reg32::from_index(opcode - 0x58);
            (Insn::PopR32(r), 1)
        }
        // call rel32 — opcode E8 cd
        (false, 0xE8) => {
            let off = read_i32_le(rest, 1)?;
            (Insn::CallRel32(off), 5)
        }
        // ret near — opcode C3
        (false, 0xC3) => (Insn::Ret, 1),
        // mov sreg, r/m16 — opcode 8E /r. movfuscator only uses this
        // with mod=11 and the dispatch trick (`mov cs, ax`).
        (false, 0x8E) => decode_mov_to_sreg(rest)?,
        // jmp r/m32 indirect — opcode FF /4
        (false, 0xFF) => decode_ff_group(rest)?,
        _ => return Err(Fault::UnknownOpcode(opcode)),
    };
    Ok((insn, body_len + prefix_len))
}

/// Decode `mov sreg, r/m16` (opcode 8E /r). ModR/M `reg` field selects
/// the segment register: 1 = CS (movfuscator's dispatch trick), other
/// values are real segment regs we treat as no-op writes.
fn decode_mov_to_sreg(rest: &[u8]) -> Result<(Insn, u8), Fault> {
    let modrm_byte = *rest.get(1).ok_or(Fault::DecodeTruncated)?;
    let m = parse_modrm(modrm_byte);
    if m.mod_ != 0b11 {
        // We've only seen mod=11 in movfuscator output. Memory-source
        // form (`mov cs, [m16]`) is technically valid but we have no
        // need yet — surface as UnknownOpcode so the unhandled case
        // is loud.
        return Err(Fault::UnknownOpcode(0x8E));
    }
    let src = Reg32::from_index(m.rm); // parent reg of the r/m16 sub-reg
    let insn = if m.reg == 1 {
        Insn::MovfuscatorDispatchJump(src)
    } else {
        Insn::MovToOtherSegReg
    };
    Ok((insn, 2))
}

/// Decode the FF opcode family. `reg` field of the ModR/M byte selects:
///   /0  inc r/m32       — not yet supported
///   /1  dec r/m32       — not yet supported
///   /2  call r/m32      — not yet supported (movfuscator goes through E8)
///   /3  call FAR        — not yet supported
///   /4  jmp r/m32       — the indirect jmp movfuscator's crtf uses
///   /5  jmp FAR         — not yet supported
///   /6  push r/m32      — not yet supported (50+rd covers reg-only)
fn decode_ff_group(rest: &[u8]) -> Result<(Insn, u8), Fault> {
    let modrm_byte = *rest.get(1).ok_or(Fault::DecodeTruncated)?;
    let m = parse_modrm(modrm_byte);
    if m.reg != 4 {
        return Err(Fault::UnknownOpcode(0xFF));
    }
    // jmp r/m32. mod=11 is the register-indirect form (`jmp ecx`
    // etc.); the canvas demo's hand-written stubs use it as the
    // mov+jmp replacement for `ret` (`pop ecx ; jmp ecx`) so the
    // resulting .text has no `ret` opcode (upstream issue #42).
    if m.mod_ == 0b11 {
        return Ok((Insn::JmpReg32(Reg32::from_index(m.rm)), 2));
    }
    let (ea, ea_extra) = parse_effective_address_32(m.mod_, m.rm, &rest[2..])?;
    Ok((Insn::JmpIndirectMem32(ea), 2 + ea_extra))
}

/// Decode one of the moffs MOV forms — the short (no-ModR/M) encodings
/// that move AL/AX/EAX to or from a 32-bit absolute address.
///
/// - `A0` / `A2`: AL ↔ [disp32]   (8-bit, ignores any 0x66 prefix)
/// - `A1` / `A3`: EAX ↔ [disp32]  (32-bit by default, 16-bit with `66`)
fn decode_moffs(opcode: u8, operand_size_16: bool, rest: &[u8]) -> Result<(Insn, u8), Fault> {
    let disp = read_i32_le(rest, 1)?;
    let mem = no_base_disp(disp);
    let insn = match (opcode, operand_size_16) {
        (0xA0, _) => Insn::Mov {
            dst: Operand::Reg8(Reg8::Al),
            src: Operand::Mem8(mem),
        },
        (0xA2, _) => Insn::Mov {
            dst: Operand::Mem8(mem),
            src: Operand::Reg8(Reg8::Al),
        },
        (0xA1, false) => Insn::Mov {
            dst: Operand::Reg32(Reg32::Eax),
            src: Operand::Mem32(mem),
        },
        (0xA3, false) => Insn::Mov {
            dst: Operand::Mem32(mem),
            src: Operand::Reg32(Reg32::Eax),
        },
        (0xA1, true) => Insn::Mov {
            dst: Operand::Reg16(Reg16::Ax),
            src: Operand::Mem16(mem),
        },
        (0xA3, true) => Insn::Mov {
            dst: Operand::Mem16(mem),
            src: Operand::Reg16(Reg16::Ax),
        },
        _ => return Err(Fault::UnknownOpcode(opcode)),
    };
    Ok((insn, 5))
}

/// 16-bit twin of [`decode_mov_rm_r_32`]: handles `66 89 /r` and `66 8B /r`.
/// The 0x66 prefix has been consumed by the caller; `bytes` starts with
/// the opcode byte.
fn decode_mov_rm_r_16(bytes: &[u8], dir_to_reg: bool) -> Result<(Insn, u8), Fault> {
    let modrm_byte = *bytes.get(1).ok_or(Fault::DecodeTruncated)?;
    let m = parse_modrm(modrm_byte);
    let reg_side = Operand::Reg16(Reg16::from_index(m.reg));

    if m.mod_ == 0b11 {
        let rm_side = Operand::Reg16(Reg16::from_index(m.rm));
        let (dst, src) = if dir_to_reg {
            (reg_side, rm_side)
        } else {
            (rm_side, reg_side)
        };
        return Ok((Insn::Mov { dst, src }, 2));
    }

    let (ea, ea_extra) = parse_effective_address_32(m.mod_, m.rm, &bytes[2..])?;
    let rm_side = Operand::Mem16(ea);
    let (dst, src) = if dir_to_reg {
        (reg_side, rm_side)
    } else {
        (rm_side, reg_side)
    };
    Ok((Insn::Mov { dst, src }, 2 + ea_extra))
}

/// 8-bit twin of [`decode_mov_rm_r_32`]: handles `88 /r` and `8A /r`.
/// Effective-address shape is identical to the 32-bit case (the address
/// is always 32-bit; only the operand width differs), so the SIB / disp
/// parser is shared.
fn decode_mov_rm_r_8(bytes: &[u8], dir_to_reg: bool) -> Result<(Insn, u8), Fault> {
    let modrm_byte = *bytes.get(1).ok_or(Fault::DecodeTruncated)?;
    let m = parse_modrm(modrm_byte);
    let reg_side = Operand::Reg8(Reg8::from_index(m.reg));

    if m.mod_ == 0b11 {
        let rm_side = Operand::Reg8(Reg8::from_index(m.rm));
        let (dst, src) = if dir_to_reg {
            (reg_side, rm_side)
        } else {
            (rm_side, reg_side)
        };
        return Ok((Insn::Mov { dst, src }, 2));
    }

    let (ea, ea_extra) = parse_effective_address_32(m.mod_, m.rm, &bytes[2..])?;
    let rm_side = Operand::Mem8(ea);
    let (dst, src) = if dir_to_reg {
        (reg_side, rm_side)
    } else {
        (rm_side, reg_side)
    };
    Ok((Insn::Mov { dst, src }, 2 + ea_extra))
}

/// `C6 /0` — `mov r/m8, imm8`. Same shape as `C7 /0 imm32` but with
/// a 1-byte immediate and 8-bit operand. movfuscator output never
/// hits this (it widens byte stores to 32-bit), but `llvm-mov` does
/// emit it — see DESIGN.md's "fill the gap when it actually fires"
/// stance on the `C6` opcode.
fn decode_mov_rm8_imm8(bytes: &[u8]) -> Result<(Insn, u8), Fault> {
    let modrm_byte = *bytes.get(1).ok_or(Fault::DecodeTruncated)?;
    let m = parse_modrm(modrm_byte);
    if m.reg != 0 {
        // /0 = mov; other digits are reserved (UD).
        return Err(Fault::UnknownOpcode(0xC6));
    }
    if m.mod_ == 0b11 {
        let imm = *bytes.get(2).ok_or(Fault::DecodeTruncated)?;
        return Ok((
            Insn::Mov {
                dst: Operand::Reg8(Reg8::from_index(m.rm)),
                src: Operand::Imm8(imm),
            },
            3,
        ));
    }
    let (ea, ea_extra) = parse_effective_address_32(m.mod_, m.rm, &bytes[2..])?;
    let imm_off = 2 + usize::from(ea_extra);
    let imm = *bytes.get(imm_off).ok_or(Fault::DecodeTruncated)?;
    let total_len = 2 + ea_extra + 1;
    Ok((
        Insn::Mov {
            dst: Operand::Mem8(ea),
            src: Operand::Imm8(imm),
        },
        total_len,
    ))
}

fn decode_mov_rm32_imm32(bytes: &[u8]) -> Result<(Insn, u8), Fault> {
    let modrm_byte = *bytes.get(1).ok_or(Fault::DecodeTruncated)?;
    let m = parse_modrm(modrm_byte);
    // The ModR/M `reg` field is a /digit selector for C7. /0 is mov;
    // other digits are reserved encodings (UD).
    if m.reg != 0 {
        return Err(Fault::UnknownOpcode(0xC7));
    }
    if m.mod_ == 0b11 {
        let imm = read_u32_le(bytes, 2)?;
        return Ok((
            Insn::Mov {
                dst: Operand::Reg32(Reg32::from_index(m.rm)),
                src: Operand::Imm32(imm),
            },
            6,
        ));
    }
    let (ea, ea_extra) = parse_effective_address_32(m.mod_, m.rm, &bytes[2..])?;
    let imm_off = 2 + usize::from(ea_extra);
    let imm = read_u32_le(bytes, imm_off)?;
    let total_len = 2 + ea_extra + 4;
    Ok((
        Insn::Mov {
            dst: Operand::Mem32(ea),
            src: Operand::Imm32(imm),
        },
        total_len,
    ))
}

/// Shared decoder for the two ModR/M-encoded 32-bit mov forms:
/// `89 /r` (store reg -> r/m) and `8B /r` (load r/m -> reg).
/// `dir_to_reg` selects which side the ModR/M `reg` field is on.
fn decode_mov_rm_r_32(bytes: &[u8], dir_to_reg: bool) -> Result<(Insn, u8), Fault> {
    let modrm_byte = *bytes.get(1).ok_or(Fault::DecodeTruncated)?;
    let m = parse_modrm(modrm_byte);
    let reg_side = Operand::Reg32(Reg32::from_index(m.reg));

    // mod=11 → r/m is a register, no further bytes.
    if m.mod_ == 0b11 {
        let rm_side = Operand::Reg32(Reg32::from_index(m.rm));
        let (dst, src) = if dir_to_reg {
            (reg_side, rm_side)
        } else {
            (rm_side, reg_side)
        };
        return Ok((Insn::Mov { dst, src }, 2));
    }

    let (ea, ea_extra) = parse_effective_address_32(m.mod_, m.rm, &bytes[2..])?;
    let rm_side = Operand::Mem32(ea);
    let (dst, src) = if dir_to_reg {
        (reg_side, rm_side)
    } else {
        (rm_side, reg_side)
    };
    Ok((Insn::Mov { dst, src }, 2 + ea_extra))
}

/// One decoded ModR/M byte. Fields are kept as raw bit-fields so the
/// caller can dispatch on the encoded form without re-extracting them.
#[derive(Debug, Clone, Copy)]
struct ModRm {
    mod_: u8, // top 2 bits
    reg: u8,  // middle 3 bits
    rm: u8,   // low 3 bits
}

fn parse_modrm(b: u8) -> ModRm {
    ModRm {
        mod_: (b >> 6) & 0b11,
        reg: (b >> 3) & 0b111,
        rm: b & 0b111,
    }
}

/// Parse the post-ModR/M bytes of a 32-bit memory operand.
///
/// Returns the resolved effective address plus the number of extra bytes
/// consumed (SIB and/or displacement). Caller is responsible for the
/// `mod=11` register-direct case before invoking this.
fn parse_effective_address_32(
    mod_: u8,
    rm: u8,
    rest: &[u8],
) -> Result<(EffectiveAddress, u8), Fault> {
    if rm == 0b100 {
        // SIB byte follows the ModR/M byte.
        let sib = *rest.first().ok_or(Fault::DecodeTruncated)?;
        let (ea, disp_bytes) = parse_sib_address(mod_, sib, &rest[1..])?;
        return Ok((ea, 1 + disp_bytes));
    }

    match mod_ {
        0b00 if rm == 0b101 => {
            // disp32 only — no base, no index.
            let disp = read_i32_le(rest, 0)?;
            Ok((no_base_disp(disp), 4))
        }
        0b00 => Ok((base_only(Reg32::from_index(rm)), 0)),
        0b01 => {
            let disp = i32::from(read_i8(rest, 0)?);
            Ok((base_disp(Reg32::from_index(rm), disp), 1))
        }
        0b10 => {
            let disp = read_i32_le(rest, 0)?;
            Ok((base_disp(Reg32::from_index(rm), disp), 4))
        }
        _ => unreachable!("mod=11 handled by caller"),
    }
}

/// Parse the SIB-byte family of effective addresses. `rest` starts with
/// the displacement bytes (if any) — the SIB byte itself has already been
/// consumed by the caller. Returns the `EffectiveAddress` and the number
/// of displacement bytes consumed (does NOT include the SIB byte).
fn parse_sib_address(mod_: u8, sib: u8, rest: &[u8]) -> Result<(EffectiveAddress, u8), Fault> {
    let scale = 1u8 << ((sib >> 6) & 0b11);
    let index_field = (sib >> 3) & 0b111;
    let base_field = sib & 0b111;

    // index == 100 means "no index" (encoded ESP slot is reused as the
    // sentinel — see Intel SDM Vol. 2A, Table 2-3).
    let index = if index_field == 0b100 {
        None
    } else {
        Some(Reg32::from_index(index_field))
    };

    // base == 101 with mod == 00 means "no base, disp32 follows".
    // For mod == 01 / 10 the base IS EBP, with disp8 / disp32 as usual.
    let (base, disp, disp_bytes) = match (mod_, base_field) {
        (0b00, 0b101) => (None, read_i32_le(rest, 0)?, 4),
        (0b00, b) => (Some(Reg32::from_index(b)), 0, 0),
        (0b01, b) => (Some(Reg32::from_index(b)), i32::from(read_i8(rest, 0)?), 1),
        (0b10, b) => (Some(Reg32::from_index(b)), read_i32_le(rest, 0)?, 4),
        _ => unreachable!("mod=11 has no SIB byte"),
    };

    Ok((
        EffectiveAddress {
            base,
            index,
            scale,
            disp,
        },
        disp_bytes,
    ))
}

fn no_base_disp(disp: i32) -> EffectiveAddress {
    EffectiveAddress {
        base: None,
        index: None,
        scale: 1,
        disp,
    }
}

fn base_only(base: Reg32) -> EffectiveAddress {
    EffectiveAddress {
        base: Some(base),
        index: None,
        scale: 1,
        disp: 0,
    }
}

fn base_disp(base: Reg32, disp: i32) -> EffectiveAddress {
    EffectiveAddress {
        base: Some(base),
        index: None,
        scale: 1,
        disp,
    }
}

fn read_u32_le(bytes: &[u8], off: usize) -> Result<u32, Fault> {
    let slice = bytes.get(off..off + 4).ok_or(Fault::DecodeTruncated)?;
    Ok(u32::from_le_bytes([slice[0], slice[1], slice[2], slice[3]]))
}

fn read_i32_le(bytes: &[u8], off: usize) -> Result<i32, Fault> {
    let slice = bytes.get(off..off + 4).ok_or(Fault::DecodeTruncated)?;
    Ok(i32::from_le_bytes([slice[0], slice[1], slice[2], slice[3]]))
}

fn read_i8(bytes: &[u8], off: usize) -> Result<i8, Fault> {
    bytes
        .get(off)
        .copied()
        .map(|b| i8::from_le_bytes([b]))
        .ok_or(Fault::DecodeTruncated)
}

#[cfg(test)]
mod tests {
    use super::*;

    fn mov_r32_imm32(dst: Reg32, imm: u32) -> Insn {
        Insn::Mov {
            dst: Operand::Reg32(dst),
            src: Operand::Imm32(imm),
        }
    }

    fn mov_r32_r32(dst: Reg32, src: Reg32) -> Insn {
        Insn::Mov {
            dst: Operand::Reg32(dst),
            src: Operand::Reg32(src),
        }
    }

    fn mem32(disp: i32) -> Operand {
        Operand::Mem32(EffectiveAddress {
            base: None,
            index: None,
            scale: 1,
            disp,
        })
    }

    fn mem32_base(base: Reg32, disp: i32) -> Operand {
        Operand::Mem32(EffectiveAddress {
            base: Some(base),
            index: None,
            scale: 1,
            disp,
        })
    }

    #[test]
    fn mov_eax_imm32() {
        let (insn, len) = decode(&[0xb8, 0x2a, 0x00, 0x00, 0x00]).unwrap();
        assert_eq!(len, 5);
        assert_eq!(insn, mov_r32_imm32(Reg32::Eax, 42));
    }

    #[test]
    fn mov_ecx_imm32_max() {
        let (insn, len) = decode(&[0xb9, 0xff, 0xff, 0xff, 0xff]).unwrap();
        assert_eq!(len, 5);
        assert_eq!(insn, mov_r32_imm32(Reg32::Ecx, 0xffff_ffff));
    }

    #[test]
    fn mov_edi_imm32_endian() {
        let (insn, _) = decode(&[0xbf, 0x78, 0x56, 0x34, 0x12]).unwrap();
        assert_eq!(insn, mov_r32_imm32(Reg32::Edi, 0x1234_5678));
    }

    #[test]
    fn all_eight_regs_via_opcode_low_bits() {
        let regs = [
            Reg32::Eax,
            Reg32::Ecx,
            Reg32::Edx,
            Reg32::Ebx,
            Reg32::Esp,
            Reg32::Ebp,
            Reg32::Esi,
            Reg32::Edi,
        ];
        for (i, expected) in regs.iter().enumerate() {
            let opcode = 0xB8 + u8::try_from(i).unwrap();
            let (insn, _) = decode(&[opcode, 0, 0, 0, 0]).unwrap();
            assert_eq!(insn, mov_r32_imm32(*expected, 0));
        }
    }

    // --- 8B /r — mov r32, r/m32 ---

    #[test]
    fn mov_r32_r32_via_8b_mod11() {
        // 8b d8  →  mov ebx, eax  (reg=011 r/m=000, mod=11)
        let (insn, len) = decode(&[0x8b, 0xd8]).unwrap();
        assert_eq!(len, 2);
        assert_eq!(insn, mov_r32_r32(Reg32::Ebx, Reg32::Eax));
    }

    #[test]
    fn mov_r32_disp32_via_8b_mod00_rm101() {
        // 8b 1d 78 56 34 12  →  mov ebx, ds:0x12345678
        let (insn, len) = decode(&[0x8b, 0x1d, 0x78, 0x56, 0x34, 0x12]).unwrap();
        assert_eq!(len, 6);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Reg32(Reg32::Ebx),
                src: mem32(0x1234_5678_i32),
            }
        );
    }

    #[test]
    fn mov_r32_mem_base_via_8b_mod00() {
        // 8b 18  →  mov ebx, [eax]  (reg=011, mod=00, r/m=000 → base=eax, no disp)
        let (insn, len) = decode(&[0x8b, 0x18]).unwrap();
        assert_eq!(len, 2);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Reg32(Reg32::Ebx),
                src: mem32_base(Reg32::Eax, 0),
            }
        );
    }

    #[test]
    fn mov_r32_mem_base_disp8_via_8b_mod01() {
        // 8b 58 ff  →  mov ebx, [eax - 1]  (disp8 = 0xff = -1 sign-extended)
        let (insn, len) = decode(&[0x8b, 0x58, 0xff]).unwrap();
        assert_eq!(len, 3);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Reg32(Reg32::Ebx),
                src: mem32_base(Reg32::Eax, -1),
            }
        );
    }

    #[test]
    fn mov_r32_mem_base_disp32_via_8b_mod10() {
        // 8b 98 78 56 34 12  →  mov ebx, [eax + 0x12345678]
        let (insn, len) = decode(&[0x8b, 0x98, 0x78, 0x56, 0x34, 0x12]).unwrap();
        assert_eq!(len, 6);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Reg32(Reg32::Ebx),
                src: mem32_base(Reg32::Eax, 0x1234_5678_i32),
            }
        );
    }

    // --- 89 /r — mov r/m32, r32 ---

    #[test]
    fn mov_r32_r32_via_89_mod11() {
        // 89 c3  →  mov ebx, eax  (reg=000 r/m=011 — note operands swapped vs 8B)
        let (insn, len) = decode(&[0x89, 0xc3]).unwrap();
        assert_eq!(len, 2);
        assert_eq!(insn, mov_r32_r32(Reg32::Ebx, Reg32::Eax));
    }

    #[test]
    fn mov_disp32_r32_via_89_mod00_rm101() {
        // 89 05 78 56 34 12  →  mov ds:0x12345678, eax
        let (insn, len) = decode(&[0x89, 0x05, 0x78, 0x56, 0x34, 0x12]).unwrap();
        assert_eq!(len, 6);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: mem32(0x1234_5678_i32),
                src: Operand::Reg32(Reg32::Eax),
            }
        );
    }

    // --- SIB ---

    fn mem32_sib(base: Option<Reg32>, index: Option<Reg32>, scale: u8, disp: i32) -> Operand {
        Operand::Mem32(EffectiveAddress {
            base,
            index,
            scale,
            disp,
        })
    }

    #[test]
    fn sib_no_base_with_index_scale_disp32() {
        // 8b 04 85 78 56 34 12  →  mov eax, [eax*4 + 0x12345678]
        // reg=000 mod=00 r/m=100  SIB: ss=10 index=000 base=101  disp32
        let (insn, len) = decode(&[0x8b, 0x04, 0x85, 0x78, 0x56, 0x34, 0x12]).unwrap();
        assert_eq!(len, 7);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Reg32(Reg32::Eax),
                src: mem32_sib(None, Some(Reg32::Eax), 4, 0x1234_5678_i32),
            }
        );
    }

    #[test]
    fn sib_base_plus_index_scale1() {
        // 8b 14 0a  →  mov edx, [edx + ecx]
        // reg=010 mod=00 r/m=100  SIB: ss=00 index=001 base=010
        let (insn, len) = decode(&[0x8b, 0x14, 0x0a]).unwrap();
        assert_eq!(len, 3);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Reg32(Reg32::Edx),
                src: mem32_sib(Some(Reg32::Edx), Some(Reg32::Ecx), 1, 0),
            }
        );
    }

    #[test]
    fn sib_base_esp_no_index() {
        // 8b 04 24  →  mov eax, [esp]
        // reg=000 mod=00 r/m=100  SIB: ss=00 index=100 (none) base=100 (esp)
        let (insn, len) = decode(&[0x8b, 0x04, 0x24]).unwrap();
        assert_eq!(len, 3);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Reg32(Reg32::Eax),
                src: mem32_sib(Some(Reg32::Esp), None, 1, 0),
            }
        );
    }

    #[test]
    fn sib_base_disp8() {
        // 8b 44 24 04  →  mov eax, [esp + 4]
        // reg=000 mod=01 r/m=100  SIB: ss=00 index=100 base=100  disp8=04
        let (insn, len) = decode(&[0x8b, 0x44, 0x24, 0x04]).unwrap();
        assert_eq!(len, 4);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Reg32(Reg32::Eax),
                src: mem32_sib(Some(Reg32::Esp), None, 1, 4),
            }
        );
    }

    // --- moffs forms (A0/A1/A2/A3) ---

    #[test]
    fn moffs_mov_eax_from_abs() {
        // a1 78 56 34 12 → mov eax, ds:0x12345678
        // 1-byte shorter than the equivalent 8b 05 ... encoding.
        let (insn, len) = decode(&[0xa1, 0x78, 0x56, 0x34, 0x12]).unwrap();
        assert_eq!(len, 5);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Reg32(Reg32::Eax),
                src: mem32(0x1234_5678_i32),
            }
        );
    }

    #[test]
    fn moffs_mov_abs_from_eax() {
        // a3 78 56 34 12 → mov ds:0x12345678, eax
        let (insn, len) = decode(&[0xa3, 0x78, 0x56, 0x34, 0x12]).unwrap();
        assert_eq!(len, 5);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: mem32(0x1234_5678_i32),
                src: Operand::Reg32(Reg32::Eax),
            }
        );
    }

    #[test]
    fn moffs_mov_al_byte_forms() {
        // a0 .. → mov al, byte ds:disp32
        let (insn, _) = decode(&[0xa0, 0x00, 0x20, 0x00, 0x00]).unwrap();
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Reg8(Reg8::Al),
                src: Operand::Mem8(EffectiveAddress {
                    base: None,
                    index: None,
                    scale: 1,
                    disp: 0x2000,
                }),
            }
        );
        // a2 .. → mov byte ds:disp32, al
        let (insn, _) = decode(&[0xa2, 0x00, 0x20, 0x00, 0x00]).unwrap();
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Mem8(EffectiveAddress {
                    base: None,
                    index: None,
                    scale: 1,
                    disp: 0x2000,
                }),
                src: Operand::Reg8(Reg8::Al),
            }
        );
    }

    #[test]
    fn moffs_mov_with_66_prefix_is_16bit() {
        // 66 a1 .. → mov ax, word ds:disp32
        let (insn, len) = decode(&[0x66, 0xa1, 0x00, 0x20, 0x00, 0x00]).unwrap();
        assert_eq!(len, 6);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Reg16(Reg16::Ax),
                src: Operand::Mem16(EffectiveAddress {
                    base: None,
                    index: None,
                    scale: 1,
                    disp: 0x2000,
                }),
            }
        );
        // 66 a3 .. → mov word ds:disp32, ax
        let (insn, _) = decode(&[0x66, 0xa3, 0x00, 0x20, 0x00, 0x00]).unwrap();
        assert_eq!(
            insn,
            Insn::Mov {
                dst: Operand::Mem16(EffectiveAddress {
                    base: None,
                    index: None,
                    scale: 1,
                    disp: 0x2000,
                }),
                src: Operand::Reg16(Reg16::Ax),
            }
        );
    }

    // --- C7 /0 — mov r/m32, imm32 ---

    #[test]
    fn mov_mem_disp32_imm32_via_c7() {
        // c7 05 78 56 34 12 ef be ad de
        //   →  mov dword [0x12345678], 0xdeadbeef
        let (insn, len) =
            decode(&[0xc7, 0x05, 0x78, 0x56, 0x34, 0x12, 0xef, 0xbe, 0xad, 0xde]).unwrap();
        assert_eq!(len, 10);
        assert_eq!(
            insn,
            Insn::Mov {
                dst: mem32(0x1234_5678_i32),
                src: Operand::Imm32(0xdead_beef),
            }
        );
    }

    #[test]
    fn mov_reg_imm32_via_c7_mod11_is_equivalent_to_b8() {
        // c7 c0 2a 00 00 00  →  mov eax, 42  (reg=000 mod=11 r/m=000)
        let (insn, len) = decode(&[0xc7, 0xc0, 0x2a, 0x00, 0x00, 0x00]).unwrap();
        assert_eq!(len, 6);
        assert_eq!(insn, mov_r32_imm32(Reg32::Eax, 42));
    }

    #[test]
    fn c7_with_nonzero_reg_field_is_reserved() {
        // c7 /1 ... — /1 is not mov; reserved encoding.
        assert_eq!(
            decode(&[0xc7, 0xc8, 0x00, 0x00, 0x00, 0x00]).unwrap_err(),
            Fault::UnknownOpcode(0xC7),
        );
    }

    #[test]
    fn mov_r8_imm8_via_b0_through_b7() {
        // b2 13 → mov dl, 0x13  (Reg8::Dl = index 2)
        let (insn, len) = decode(&[0xB2, 0x13]).unwrap();
        assert_eq!(len, 2);
        match insn {
            Insn::Mov {
                dst: Operand::Reg8(r),
                src: Operand::Imm8(v),
            } => {
                assert_eq!(r, Reg8::Dl);
                assert_eq!(v, 0x13);
            }
            other => panic!("expected Mov Reg8 ← Imm8, got {other:?}"),
        }
    }

    #[test]
    fn mov_rm8_imm8_via_c6_with_disp8() {
        // c6 40 04 04  →  mov BYTE PTR [eax+0x4], 0x4
        // (modrm=40: mod=01 reg=000 r/m=000 = [EAX+disp8]; disp8=0x04; imm8=0x04)
        let (insn, len) = decode(&[0xc6, 0x40, 0x04, 0x04]).unwrap();
        assert_eq!(len, 4);
        match insn {
            Insn::Mov {
                dst: Operand::Mem8(ea),
                src: Operand::Imm8(v),
            } => {
                assert_eq!(v, 0x04);
                assert_eq!(ea.base, Some(Reg32::Eax));
                assert_eq!(ea.disp, 4);
                assert!(ea.index.is_none());
            }
            other => panic!("expected Mov Mem8 ← Imm8, got {other:?}"),
        }
    }

    #[test]
    fn c6_with_nonzero_reg_field_is_reserved() {
        // c6 /1 — same /digit story as c7: only /0 is mov.
        assert_eq!(
            decode(&[0xc6, 0xc8, 0x00]).unwrap_err(),
            Fault::UnknownOpcode(0xC6),
        );
    }

    #[test]
    fn sib_disp32_truncated_is_decode_error() {
        // SIB with mod=00 base=101 (disp32) but disp truncated to 2 bytes
        assert_eq!(
            decode(&[0x8b, 0x04, 0x85, 0x78, 0x56]).unwrap_err(),
            Fault::DecodeTruncated,
        );
    }

    // --- jmp rel32 ---

    #[test]
    fn jmp_rel32_positive() {
        // e9 78 56 34 12 → jmp +0x12345678
        let (insn, len) = decode(&[0xe9, 0x78, 0x56, 0x34, 0x12]).unwrap();
        assert_eq!(len, 5);
        assert_eq!(insn, Insn::JmpRel32(0x1234_5678));
    }

    #[test]
    fn jmp_rel32_negative_disp() {
        // e9 fb ff ff ff → jmp -5 (i.e. an infinite loop on a 5-byte jmp)
        let (insn, _) = decode(&[0xe9, 0xfb, 0xff, 0xff, 0xff]).unwrap();
        assert_eq!(insn, Insn::JmpRel32(-5));
    }

    #[test]
    fn jmp_reg32_via_ff_4_modrm_11() {
        // ff e1  →  jmp ecx   (FF /4, mod=11, r/m=001 = ECX)
        // Used by the canvas stubs as `pop ecx ; jmp ecx`'s second
        // half — the mov+jmp replacement for `ret` so .text has zero
        // ret opcodes (upstream issue #42).
        let (insn, len) = decode(&[0xff, 0xe1]).unwrap();
        assert_eq!(len, 2);
        assert_eq!(insn, Insn::JmpReg32(Reg32::Ecx));
    }

    // --- int n ---

    #[test]
    fn int_0x80_decodes_as_int_with_vector() {
        let (insn, len) = decode(&[0xcd, 0x80]).unwrap();
        assert_eq!(len, 2);
        assert_eq!(insn, Insn::Int(0x80));
    }

    #[test]
    fn int_other_vector_still_decodes() {
        // Decoder accepts any vector; execution decides what to do.
        let (insn, _) = decode(&[0xcd, 0x03]).unwrap();
        assert_eq!(insn, Insn::Int(0x03));
    }

    #[test]
    fn empty_input_is_truncated() {
        assert_eq!(decode(&[]).unwrap_err(), Fault::DecodeTruncated);
    }

    #[test]
    fn mov_with_missing_imm_bytes_is_truncated() {
        assert_eq!(
            decode(&[0xb8, 0x01, 0x02]).unwrap_err(),
            Fault::DecodeTruncated,
        );
    }

    #[test]
    fn mov_r32_disp32_truncated_disp() {
        // 8B opcode + ModR/M for [disp32], but only 2 disp bytes
        assert_eq!(
            decode(&[0x8b, 0x1d, 0x78, 0x56]).unwrap_err(),
            Fault::DecodeTruncated,
        );
    }

    #[test]
    fn unknown_opcode_reported_with_byte() {
        assert_eq!(decode(&[0x00]).unwrap_err(), Fault::UnknownOpcode(0x00));
        assert_eq!(decode(&[0x90]).unwrap_err(), Fault::UnknownOpcode(0x90));
    }
}
