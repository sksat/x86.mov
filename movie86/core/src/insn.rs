//! Decoded instruction representation.
//!
//! Only the forms the decoder currently emits are listed. Add variants /
//! operand kinds when the decoder learns a new form — never speculatively.

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
    /// Panics on values > 7. The decoder masks the field to 3 bits before
    /// calling this.
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

/// 16-bit general-purpose register (low half of the matching 32-bit reg).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Reg16 {
    Ax = 0,
    Cx = 1,
    Dx = 2,
    Bx = 3,
    Sp = 4,
    Bp = 5,
    Si = 6,
    Di = 7,
}

impl Reg16 {
    /// Map an encoded 3-bit register field to the corresponding 16-bit register.
    ///
    /// # Panics
    /// Panics on values > 7.
    #[must_use]
    pub fn from_index(i: u8) -> Self {
        match i {
            0 => Self::Ax,
            1 => Self::Cx,
            2 => Self::Dx,
            3 => Self::Bx,
            4 => Self::Sp,
            5 => Self::Bp,
            6 => Self::Si,
            7 => Self::Di,
            _ => panic!("Reg16::from_index: 3-bit field expected, got {i}"),
        }
    }

    /// The 32-bit register this 16-bit register aliases (always the low half).
    #[must_use]
    pub fn parent(self) -> Reg32 {
        match self {
            Self::Ax => Reg32::Eax,
            Self::Cx => Reg32::Ecx,
            Self::Dx => Reg32::Edx,
            Self::Bx => Reg32::Ebx,
            Self::Sp => Reg32::Esp,
            Self::Bp => Reg32::Ebp,
            Self::Si => Reg32::Esi,
            Self::Di => Reg32::Edi,
        }
    }
}

/// 8-bit general-purpose register.
///
/// Index 0..=3 are low bytes of EAX/ECX/EDX/EBX; 4..=7 are high bytes of
/// the same four registers (AH/CH/DH/BH).
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
#[repr(u8)]
pub enum Reg8 {
    Al = 0,
    Cl = 1,
    Dl = 2,
    Bl = 3,
    Ah = 4,
    Ch = 5,
    Dh = 6,
    Bh = 7,
}

impl Reg8 {
    /// Map an encoded 3-bit register field (under no REX prefix) to the
    /// corresponding 8-bit register.
    ///
    /// # Panics
    /// Panics on values > 7.
    #[must_use]
    pub fn from_index(i: u8) -> Self {
        match i {
            0 => Self::Al,
            1 => Self::Cl,
            2 => Self::Dl,
            3 => Self::Bl,
            4 => Self::Ah,
            5 => Self::Ch,
            6 => Self::Dh,
            7 => Self::Bh,
            _ => panic!("Reg8::from_index: 3-bit field expected, got {i}"),
        }
    }

    /// The 32-bit register this 8-bit register aliases, and the bit shift
    /// at which its byte sits within that register's value (0 for low
    /// bytes, 8 for AH/CH/DH/BH).
    #[must_use]
    pub fn parent(self) -> (Reg32, u8) {
        match self {
            Self::Al => (Reg32::Eax, 0),
            Self::Cl => (Reg32::Ecx, 0),
            Self::Dl => (Reg32::Edx, 0),
            Self::Bl => (Reg32::Ebx, 0),
            Self::Ah => (Reg32::Eax, 8),
            Self::Ch => (Reg32::Ecx, 8),
            Self::Dh => (Reg32::Edx, 8),
            Self::Bh => (Reg32::Ebx, 8),
        }
    }
}

/// `base + index * scale + disp` — the general 32-bit effective address.
///
/// Either or both of `base` / `index` may be absent. `scale` is 1, 2, 4,
/// or 8. `disp` is signed and zero when the encoding has no displacement.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub struct EffectiveAddress {
    pub base: Option<Reg32>,
    pub index: Option<Reg32>,
    pub scale: u8,
    pub disp: i32,
}

/// One source or destination of an instruction. Variants carry their own
/// width so a `Mov { dst, src }` with mismatched widths is a decoder bug,
/// not a representable state.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Operand {
    Reg32(Reg32),
    Reg16(Reg16),
    Reg8(Reg8),
    Imm32(u32),
    Imm16(u16),
    Imm8(u8),
    Mem32(EffectiveAddress),
    Mem16(EffectiveAddress),
    Mem8(EffectiveAddress),
}

/// A decoded instruction.
#[derive(Debug, Clone, Copy, PartialEq, Eq)]
pub enum Insn {
    /// `mov dst, src`. `dst` and `src` must have matching widths.
    Mov { dst: Operand, src: Operand },
}
