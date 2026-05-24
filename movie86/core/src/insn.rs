//! Decoded instruction representation.
//!
//! Only the forms the decoder currently emits are listed. Add a variant
//! when the decoder learns a new form — never speculatively.

/// 32-bit general-purpose register, indexed by the encoded register number
/// used in opcode-low-bits and ModR/M `reg` / `r/m` fields.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Reg32 {
    Eax = 0,
    Ecx = 1,
    Edx = 2,
    Ebx = 3,
    Esp = 4,
    Ebp = 5,
    Esi = 6,
    Edi = 7,
}

impl Reg32 {
    /// Map an encoded 3-bit register field to the corresponding register.
    ///
    /// # Panics
    /// Panics on values > 7. The decoder is responsible for masking the
    /// field to 3 bits before calling this.
    #[must_use]
    pub fn from_index(i: u8) -> Self {
        match i {
            0 => Self::Eax,
            1 => Self::Ecx,
            2 => Self::Edx,
            3 => Self::Ebx,
            4 => Self::Esp,
            5 => Self::Ebp,
            6 => Self::Esi,
            7 => Self::Edi,
            _ => panic!("Reg32::from_index: 3-bit field expected, got {i}"),
        }
    }
}

/// A decoded instruction.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Insn {
    /// `mov r32, imm32` — opcode `B8+rd id`.
    MovR32Imm32 { dst: Reg32, imm: u32 },
}
