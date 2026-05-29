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
    /// `jmp rel32` (opcode `E9 cd`) — unconditional near jump. The
    /// displacement is added to the address of the **next** instruction.
    JmpRel32(i32),
    /// `int n` (opcode `CD ib`) — software interrupt. Only `int 0x80`
    /// (Linux syscall) is wired to a handler; other vectors trap.
    Int(u8),
    /// `push r32` (opcode `50+rd`). Decrements ESP by 4 then stores the
    /// register; for `push esp` the stored value is the **original** ESP
    /// (Intel SDM, modern post-8086 behavior).
    PushR32(Reg32),
    /// `pop r32` (opcode `58+rd`). Loads `[esp]` into the register and
    /// increments ESP by 4. For `pop esp` the final ESP is the popped
    /// value, not `old_esp + 4`.
    PopR32(Reg32),
    /// `call rel32` (opcode `E8 cd`). Pushes the address of the next
    /// instruction (so `ret` can return there) and jumps to
    /// `next_eip + disp`.
    CallRel32(i32),
    /// `ret` near (opcode `C3`). Pops a 32-bit return address from
    /// `[esp]` and sets EIP to it; ESP increments by 4. Does not
    /// handle `ret imm16` (opcode `C2 iw`), which movfuscator output
    /// doesn't emit (cdecl callers pop their own args).
    Ret,
    /// `mov cs, r16` (opcode `8E /r` with `reg=001`) — modelled as an
    /// indirect jump to the **full 32-bit** value of the source's parent
    /// register. movfuscator uses this as its main control-flow trick:
    /// writing to CS raises #GP on real x86, a SIGSEGV handler decodes
    /// the trap and transfers to EAX. For us, the trap is irrelevant —
    /// we just do the jump directly.
    MovfuscatorDispatchJump(Reg32),
    /// `mov sreg, r/m16` (opcode `8E /r`) with `reg != 001`. We don't
    /// model segment registers in flat 32-bit mode, so this is a no-op.
    MovToOtherSegReg,
    /// `jmp r/m32` indirect through memory (opcode `FF /4`, mod≠11).
    /// Only the memory form is observed in movfuscator output (crtf's
    /// `.plt` dispatch). Register-indirect `jmp r32` (FF /4, mod=11)
    /// can be added if it ever appears.
    JmpIndirectMem32(EffectiveAddress),
}

// ---------- AT&T-syntax Display impls --------------------------------
//
// Why AT&T (gas) syntax: the .s files emitted by movfuscator and
// llvm-mov-llc throughout this repo are gas-flavoured (`movl $42, %ebx`),
// so matching that keeps cross-referencing the disassembly pane with the
// source assembly cheap.
//
// `Display` for `Insn` has no notion of the instruction's own EIP, so
// rel32 / rel8 jumps render as signed displacements (`+0x40`, `-0x05`)
// rather than absolute target addresses. The wasm `Vm::disasmAt` caller
// owns the address; resolving the absolute target is a future polish
// step done at that layer (with the `addr + insn_len + disp` arithmetic
// the formatter can't see from here).

impl core::fmt::Display for Reg32 {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        let name = match self {
            Self::Eax => "eax",
            Self::Ecx => "ecx",
            Self::Edx => "edx",
            Self::Ebx => "ebx",
            Self::Esp => "esp",
            Self::Ebp => "ebp",
            Self::Esi => "esi",
            Self::Edi => "edi",
        };
        write!(f, "%{name}")
    }
}

impl core::fmt::Display for Reg16 {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        let name = match self {
            Self::Ax => "ax",
            Self::Cx => "cx",
            Self::Dx => "dx",
            Self::Bx => "bx",
            Self::Sp => "sp",
            Self::Bp => "bp",
            Self::Si => "si",
            Self::Di => "di",
        };
        write!(f, "%{name}")
    }
}

impl core::fmt::Display for Reg8 {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        let name = match self {
            Self::Al => "al",
            Self::Cl => "cl",
            Self::Dl => "dl",
            Self::Bl => "bl",
            Self::Ah => "ah",
            Self::Ch => "ch",
            Self::Dh => "dh",
            Self::Bh => "bh",
        };
        write!(f, "%{name}")
    }
}

impl core::fmt::Display for EffectiveAddress {
    /// AT&T memory form: `disp(%base,%index,scale)`.
    ///
    /// Omits every component that's the encoding's default:
    /// - no `disp` part when `disp == 0` and at least one of base/index
    ///   is present (a `(%eax)` reads as `[%eax + 0]`; the leading `0`
    ///   is omitted the same way gas does).
    /// - no `(%base,%index,scale)` group when both base and index are
    ///   absent — that's the disp32-only `moffs` form, rendered as a
    ///   bare hex address.
    /// - scale is elided when it's 1 and an index is present
    ///   (`(%eax,%ecx)` is `(%eax,%ecx,1)` in gas-canonical form, but
    ///   gas itself prints the short form; we follow.)
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        let has_addr_part = self.base.is_some() || self.index.is_some();

        // Displacement.
        //
        // - Pure absolute (`disp32`-only) operands: render unsigned —
        //   `0x80000000` reads as an address, never `-0x80000000`. The
        //   decoder packs the disp into an `i32` so the top half of the
        //   address space arrives sign-extended; the cast lifts it back
        //   to the original 32-bit pattern.
        // - Memory operands with a base / index: the disp is a signed
        //   relative offset (`-0x4(%ebp)` for a local), so emit the
        //   signed form — matching objdump.
        if self.disp != 0 || !has_addr_part {
            if has_addr_part && self.disp < 0 {
                let mag = i64::from(self.disp).unsigned_abs();
                write!(f, "-{mag:#x}")?;
            } else {
                write!(f, "{:#x}", self.disp.cast_unsigned())?;
            }
        }

        if has_addr_part {
            f.write_str("(")?;
            if let Some(b) = self.base {
                write!(f, "{b}")?;
            }
            if let Some(i) = self.index {
                write!(f, ",{i},{}", self.scale)?;
            }
            f.write_str(")")?;
        }
        Ok(())
    }
}

impl core::fmt::Display for Operand {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        match self {
            Self::Reg32(r) => write!(f, "{r}"),
            Self::Reg16(r) => write!(f, "{r}"),
            Self::Reg8(r) => write!(f, "{r}"),
            Self::Imm32(v) => write!(f, "${v:#x}"),
            Self::Imm16(v) => write!(f, "${v:#x}"),
            Self::Imm8(v) => write!(f, "${v:#x}"),
            Self::Mem32(ea) | Self::Mem16(ea) | Self::Mem8(ea) => write!(f, "{ea}"),
        }
    }
}

impl Insn {
    /// Mov-mnemonic suffix from the *destination* operand's width.
    /// (mov always has matching widths, so dst is sufficient.)
    fn mov_suffix(dst: &Operand) -> &'static str {
        match dst {
            Operand::Reg32(_) | Operand::Imm32(_) | Operand::Mem32(_) => "l",
            Operand::Reg16(_) | Operand::Imm16(_) | Operand::Mem16(_) => "w",
            Operand::Reg8(_) | Operand::Imm8(_) | Operand::Mem8(_) => "b",
        }
    }
}

/// Render a rel32 / rel8 displacement as a signed hex offset. Used by
/// `jmp` / `call` since `Display` doesn't know the instruction's own
/// EIP and therefore can't compute the absolute target. Callers that
/// want absolute (`jmp 0x08048040`) compute it themselves.
fn fmt_rel(f: &mut core::fmt::Formatter<'_>, off: i32) -> core::fmt::Result {
    if off < 0 {
        let mag = i64::from(off).unsigned_abs();
        write!(f, "-{mag:#x}")
    } else {
        write!(f, "+{:#x}", off.cast_unsigned())
    }
}

impl core::fmt::Display for Insn {
    fn fmt(&self, f: &mut core::fmt::Formatter<'_>) -> core::fmt::Result {
        match self {
            Self::Mov { dst, src } => {
                let suf = Self::mov_suffix(dst);
                write!(f, "mov{suf} {src}, {dst}")
            }
            Self::JmpRel32(off) => {
                f.write_str("jmp ")?;
                fmt_rel(f, *off)
            }
            Self::CallRel32(off) => {
                f.write_str("call ")?;
                fmt_rel(f, *off)
            }
            Self::Int(n) => write!(f, "int ${n:#x}"),
            Self::PushR32(r) => write!(f, "pushl {r}"),
            Self::PopR32(r) => write!(f, "popl {r}"),
            Self::Ret => f.write_str("ret"),
            Self::MovfuscatorDispatchJump(r) => {
                // Real bytes were `mov %ax, %cs`; we model it as an
                // indirect jump to the source's parent 32-bit register.
                // Render as `mov %<r>, %cs` so it matches the on-disk
                // mnemonic — the dispatch-jump semantics are an
                // emulator-side decision the disassembly doesn't need
                // to surface.
                let r16 = match r {
                    Reg32::Eax => "%ax",
                    Reg32::Ecx => "%cx",
                    Reg32::Edx => "%dx",
                    Reg32::Ebx => "%bx",
                    Reg32::Esp => "%sp",
                    Reg32::Ebp => "%bp",
                    Reg32::Esi => "%si",
                    Reg32::Edi => "%di",
                };
                write!(f, "movw {r16}, %cs")
            }
            Self::MovToOtherSegReg => f.write_str("movw <r/m16>, <sreg>"),
            Self::JmpIndirectMem32(ea) => write!(f, "jmp *{ea}"),
        }
    }
}

#[cfg(test)]
mod display_tests {
    use super::*;
    use alloc::format;

    // --- mov r32, r32 / r32, imm32 ---

    #[test]
    fn mov_r32_r32_att() {
        let insn = Insn::Mov {
            dst: Operand::Reg32(Reg32::Eax),
            src: Operand::Reg32(Reg32::Ecx),
        };
        assert_eq!(format!("{insn}"), "movl %ecx, %eax");
    }

    #[test]
    fn mov_r32_imm32_att() {
        let insn = Insn::Mov {
            dst: Operand::Reg32(Reg32::Ebx),
            src: Operand::Imm32(42),
        };
        assert_eq!(format!("{insn}"), "movl $0x2a, %ebx");
    }

    // --- mov r/m32, r32 with base+disp32 ---

    #[test]
    fn mov_mem_base_disp32_dst_att() {
        let ea = EffectiveAddress {
            base: Some(Reg32::Edi),
            index: None,
            scale: 1,
            disp: 0x0804_90a0_i32,
        };
        let insn = Insn::Mov {
            dst: Operand::Mem32(ea),
            src: Operand::Reg32(Reg32::Eax),
        };
        assert_eq!(format!("{insn}"), "movl %eax, 0x80490a0(%edi)");
    }

    // --- mov r32, r/m32 with SIB ---

    #[test]
    fn mov_r32_mem_sib_att() {
        // mov edx, (%eax,%ecx,4)
        let ea = EffectiveAddress {
            base: Some(Reg32::Eax),
            index: Some(Reg32::Ecx),
            scale: 4,
            disp: 0,
        };
        let insn = Insn::Mov {
            dst: Operand::Reg32(Reg32::Edx),
            src: Operand::Mem32(ea),
        };
        assert_eq!(format!("{insn}"), "movl (%eax,%ecx,4), %edx");
    }

    // --- byte moves ---

    #[test]
    fn mov_r8_imm8_att() {
        // The B0+rb form llvm-mov emits for set_video_mode's mov dl, 0x13.
        let insn = Insn::Mov {
            dst: Operand::Reg8(Reg8::Dl),
            src: Operand::Imm8(0x13),
        };
        assert_eq!(format!("{insn}"), "movb $0x13, %dl");
    }

    #[test]
    fn mov_rm8_imm8_att() {
        // The C6 /0 form for byte-granular spill init.
        let ea = EffectiveAddress {
            base: Some(Reg32::Eax),
            index: None,
            scale: 1,
            disp: 4,
        };
        let insn = Insn::Mov {
            dst: Operand::Mem8(ea),
            src: Operand::Imm8(0x4),
        };
        assert_eq!(format!("{insn}"), "movb $0x4, 0x4(%eax)");
    }

    // --- moffs form (no base, no index, disp32 only) ---

    #[test]
    fn mov_eax_moffs_att() {
        let ea = EffectiveAddress {
            base: None,
            index: None,
            scale: 1,
            disp: 0x1234_5678,
        };
        let insn = Insn::Mov {
            dst: Operand::Reg32(Reg32::Eax),
            src: Operand::Mem32(ea),
        };
        assert_eq!(format!("{insn}"), "movl 0x12345678, %eax");
    }

    // --- 16-bit mov ---

    #[test]
    fn mov_r16_r16_att() {
        let insn = Insn::Mov {
            dst: Operand::Reg16(Reg16::Ax),
            src: Operand::Reg16(Reg16::Dx),
        };
        assert_eq!(format!("{insn}"), "movw %dx, %ax");
    }

    // --- jmp / call / ret ---

    #[test]
    fn jmp_rel32_positive_relative_form() {
        // Display doesn't know EIP; renders as signed displacement.
        let insn = Insn::JmpRel32(0x40);
        assert_eq!(format!("{insn}"), "jmp +0x40");
    }

    #[test]
    fn jmp_rel32_negative_relative_form() {
        let insn = Insn::JmpRel32(-5);
        assert_eq!(format!("{insn}"), "jmp -0x5");
    }

    #[test]
    fn call_rel32_relative_form() {
        let insn = Insn::CallRel32(0x80);
        assert_eq!(format!("{insn}"), "call +0x80");
    }

    #[test]
    fn ret_is_bare() {
        assert_eq!(format!("{}", Insn::Ret), "ret");
    }

    // --- push / pop / int ---

    #[test]
    fn push_r32_att() {
        assert_eq!(format!("{}", Insn::PushR32(Reg32::Ebx)), "pushl %ebx");
    }

    #[test]
    fn pop_r32_att() {
        assert_eq!(format!("{}", Insn::PopR32(Reg32::Eax)), "popl %eax");
    }

    #[test]
    fn int_imm8_att() {
        assert_eq!(format!("{}", Insn::Int(0x80)), "int $0x80");
        assert_eq!(format!("{}", Insn::Int(0x81)), "int $0x81");
    }

    // --- jmp indirect memory ---

    #[test]
    fn jmp_indirect_mem_att() {
        let ea = EffectiveAddress {
            base: None,
            index: None,
            scale: 1,
            disp: 0x0804_a000_i32,
        };
        let insn = Insn::JmpIndirectMem32(ea);
        assert_eq!(format!("{insn}"), "jmp *0x804a000");
    }

    // --- mov cs, ax (movfuscator dispatch trick, lowered form) ---

    #[test]
    fn movfuscator_dispatch_jump_renders_as_mov_seg() {
        let insn = Insn::MovfuscatorDispatchJump(Reg32::Eax);
        assert_eq!(format!("{insn}"), "movw %ax, %cs");
    }

    // --- effective-address edge cases ---

    #[test]
    fn ea_base_only_no_disp_renders_without_zero() {
        let ea = EffectiveAddress {
            base: Some(Reg32::Esp),
            index: None,
            scale: 1,
            disp: 0,
        };
        assert_eq!(format!("{ea}"), "(%esp)");
    }

    #[test]
    fn ea_negative_disp_renders_as_signed_hex() {
        let ea = EffectiveAddress {
            base: Some(Reg32::Eax),
            index: None,
            scale: 1,
            disp: -1,
        };
        assert_eq!(format!("{ea}"), "-0x1(%eax)");
    }

    #[test]
    fn ea_pure_disp32_has_no_paren_group() {
        let ea = EffectiveAddress {
            base: None,
            index: None,
            scale: 1,
            disp: 0x2000,
        };
        assert_eq!(format!("{ea}"), "0x2000");
    }

    #[test]
    fn ea_pure_disp32_high_address_renders_unsigned() {
        // disp32 ≥ 0x8000_0000 packs into i32 as a negative value
        // (the decoder doesn't widen, since the operand is 32 bits on
        // the wire). Absolute addresses must render unsigned all the
        // same — `mov eax, 0x80000000` reads as a high address, not
        // `-0x80000000`. Codex review on the introduction PR flagged
        // this; pin the behaviour so any future refactor keeps it.
        let ea = EffectiveAddress {
            base: None,
            index: None,
            scale: 1,
            disp: 0x8000_0000_u32.cast_signed(),
        };
        assert_eq!(format!("{ea}"), "0x80000000");
    }

    #[test]
    fn ea_base_plus_negative_disp_renders_signed() {
        // The signed form is the right one when there's a base — a
        // local at `[ebp - 4]` reads as `-0x4(%ebp)`. Pinning the
        // contrast against the unsigned-disp32 case above so the
        // two branches don't drift.
        let ea = EffectiveAddress {
            base: Some(Reg32::Ebp),
            index: None,
            scale: 1,
            disp: -0x4,
        };
        assert_eq!(format!("{ea}"), "-0x4(%ebp)");
    }
}
