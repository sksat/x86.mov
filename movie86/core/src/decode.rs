//! Instruction decoder.
//!
//! Pure function: bytes in, `(Insn, length)` out. No CPU or memory state
//! flows through here so the same decoder can drive execution, a future
//! disassembler, and any coverage tooling.

use crate::insn::{Insn, Operand, Reg32};
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
        _ => Err(Fault::UnknownOpcode(b0)),
    }
}

fn read_u32_le(bytes: &[u8], off: usize) -> Result<u32, Fault> {
    let slice = bytes.get(off..off + 4).ok_or(Fault::DecodeTruncated)?;
    Ok(u32::from_le_bytes([slice[0], slice[1], slice[2], slice[3]]))
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

    #[test]
    fn mov_eax_imm32() {
        // b8 2a 00 00 00  →  mov eax, 42
        let (insn, len) = decode(&[0xb8, 0x2a, 0x00, 0x00, 0x00]).unwrap();
        assert_eq!(len, 5);
        assert_eq!(insn, mov_r32_imm32(Reg32::Eax, 42));
    }

    #[test]
    fn mov_ecx_imm32_max() {
        // b9 ff ff ff ff  →  mov ecx, 0xffffffff
        let (insn, len) = decode(&[0xb9, 0xff, 0xff, 0xff, 0xff]).unwrap();
        assert_eq!(len, 5);
        assert_eq!(insn, mov_r32_imm32(Reg32::Ecx, 0xffff_ffff));
    }

    #[test]
    fn mov_edi_imm32_endian() {
        // bf 78 56 34 12  →  mov edi, 0x12345678  (little-endian operand)
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
    fn unknown_opcode_reported_with_byte() {
        assert_eq!(decode(&[0x00]).unwrap_err(), Fault::UnknownOpcode(0x00));
        assert_eq!(decode(&[0x90]).unwrap_err(), Fault::UnknownOpcode(0x90));
    }
}
