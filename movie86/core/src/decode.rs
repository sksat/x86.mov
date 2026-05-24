//! Instruction decoder.
//!
//! Pure function: bytes in, `(Insn, length)` out. No CPU or memory state
//! flows through here so the same decoder can drive execution, a future
//! disassembler, and any coverage tooling.

use crate::insn::{EffectiveAddress, Insn, Operand, Reg32};
use crate::Fault;

/// Decode one instruction from `bytes` starting at offset 0.
///
/// On success returns the decoded instruction and the number of bytes it
/// consumed. The length is `u8` because an x86 instruction is at most 15
/// bytes — see Intel SDM Vol. 2 "Instruction Length Limit".
pub fn decode(bytes: &[u8]) -> Result<(Insn, u8), Fault> {
    let b0 = *bytes.first().ok_or(Fault::DecodeTruncated)?;
    match b0 {
        // mov r32, imm32 — opcode B8+rd id
        0xB8..=0xBF => {
            let dst = Reg32::from_index(b0 - 0xB8);
            let imm = read_u32_le(bytes, 1)?;
            Ok((
                Insn::Mov {
                    dst: Operand::Reg32(dst),
                    src: Operand::Imm32(imm),
                },
                5,
            ))
        }
        // mov r/m32, r32 — opcode 89 /r
        0x89 => decode_mov_rm_r_32(bytes, /* dir_to_reg */ false),
        // mov r32, r/m32 — opcode 8B /r
        0x8B => decode_mov_rm_r_32(bytes, /* dir_to_reg */ true),
        // mov r/m32, imm32 — opcode C7 /0
        0xC7 => decode_mov_rm32_imm32(bytes),
        _ => Err(Fault::UnknownOpcode(b0)),
    }
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
        (0b01, b) => (
            Some(Reg32::from_index(b)),
            i32::from(read_i8(rest, 0)?),
            1,
        ),
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

    fn mem32_sib(
        base: Option<Reg32>,
        index: Option<Reg32>,
        scale: u8,
        disp: i32,
    ) -> Operand {
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

    // --- C7 /0 — mov r/m32, imm32 ---

    #[test]
    fn mov_mem_disp32_imm32_via_c7() {
        // c7 05 78 56 34 12 ef be ad de
        //   →  mov dword [0x12345678], 0xdeadbeef
        let (insn, len) = decode(&[
            0xc7, 0x05, 0x78, 0x56, 0x34, 0x12, 0xef, 0xbe, 0xad, 0xde,
        ])
        .unwrap();
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
    fn sib_disp32_truncated_is_decode_error() {
        // SIB with mod=00 base=101 (disp32) but disp truncated to 2 bytes
        assert_eq!(
            decode(&[0x8b, 0x04, 0x85, 0x78, 0x56]).unwrap_err(),
            Fault::DecodeTruncated,
        );
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
