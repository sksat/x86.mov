//===-- MovRegisterInfo.td -------------------------------*- tablegen -*-===//
//
// 8 general-purpose 32-bit registers, named like the x86 set so the printer
// can emit them verbatim. The encoding values (`HWEncoding`) mirror the x86
// modR/M reg field — useful later when we attach an MCCodeEmitter; harmless
// while we're text-only.
//
// Stage 7-prep adds the low-byte aliases AL/CL/DL/BL with a proper sub_8bit
// subreg relationship, so MovOnlyLegalize (post-RA) can build mov-only
// table-lookup sequences via `mov al, byte ptr [...]` style addressing
// without surprising the register allocator about ECX/EAX/EBX/EDX overlap.
//
//===----------------------------------------------------------------------===//

// Sub-register index for the low 8 bits of a 32-bit register.
def sub_8bit : SubRegIndex<8>;
def sub_8bit_hi : SubRegIndex<8, 8>;

class MovReg<bits<4> num, string n> : Register<n> {
  let Namespace          = "Mov";
  let HWEncoding{3-0}    = num;
}

// Low-byte registers. Same HWEncoding low 3 bits as their parents.
def AL : Register<"al"> { let Namespace = "Mov"; let HWEncoding{2-0} = 0; }
def CL : Register<"cl"> { let Namespace = "Mov"; let HWEncoding{2-0} = 1; }
def DL : Register<"dl"> { let Namespace = "Mov"; let HWEncoding{2-0} = 2; }
def BL : Register<"bl"> { let Namespace = "Mov"; let HWEncoding{2-0} = 3; }
def AH : Register<"ah"> { let Namespace = "Mov"; let HWEncoding{2-0} = 4; }
def CH : Register<"ch"> { let Namespace = "Mov"; let HWEncoding{2-0} = 5; }
def DH : Register<"dh"> { let Namespace = "Mov"; let HWEncoding{2-0} = 6; }
def BH : Register<"bh"> { let Namespace = "Mov"; let HWEncoding{2-0} = 7; }

let SubRegIndices = [sub_8bit, sub_8bit_hi] in {
def EAX : MovReg<0, "eax">, DwarfRegNum<[0]> { let SubRegs = [AL, AH]; }
def ECX : MovReg<1, "ecx">, DwarfRegNum<[1]> { let SubRegs = [CL, CH]; }
def EDX : MovReg<2, "edx">, DwarfRegNum<[2]> { let SubRegs = [DL, DH]; }
def EBX : MovReg<3, "ebx">, DwarfRegNum<[3]> { let SubRegs = [BL, BH]; }
}

// The remaining 32-bit regs have no 8-bit subreg in x86 (ESP/EBP/ESI/EDI
// can be accessed as 8-bit only in 64-bit mode via REX). For our 32-bit
// target they stay byte-less.
def ESP : MovReg<4, "esp">, DwarfRegNum<[4]>;
def EBP : MovReg<5, "ebp">, DwarfRegNum<[5]>;
def ESI : MovReg<6, "esi">, DwarfRegNum<[6]>;
def EDI : MovReg<7, "edi">, DwarfRegNum<[7]>;

// Allocation order: caller-saved scratch first, then callee-saved, then the
// stack pointer last (and the frame pointer if we ever reserve EBP).
def GPR32 : RegisterClass<"Mov", [i32], 32,
  (add EAX, ECX, EDX, EBX, ESI, EDI, EBP, ESP)>;

// A separate class without ESP/EBP — used for any RegOperand that must not
// be the stack or (later) frame pointer.
def GPR32_NOSP : RegisterClass<"Mov", [i32], 32,
  (add EAX, ECX, EDX, EBX, ESI, EDI)>;


// Stage 6f — the GPR32s that actually have an addressable low byte.
// Only EAX/ECX/EDX/EBX carry a sub_8bit; ESI/EDI/EBP/ESP do not. Making
// this a class lets the STORE8 pseudo constrain its source operand, so
// register allocation guarantees a byte-nameable register and the post-RA
// expansion is a single `mov byte ptr [mem], <low byte>` with no spill, no
// borrowed scratch register, and nothing to save or restore.
def GPR32_ABCD : RegisterClass<"Mov", [i32], 32, (add EAX, ECX, EDX, EBX)>;

// 8-bit register class. Stage 7-prep introduces it for the MovOnlyLegalize
// pass to address byte-wide loads/stores into lookup tables. RA never sees
// virtual GR8 registers — the legalize pass (post-RA) uses physreg names
// directly via BuildMI. Listing the low and high byte names in a class lets
// the .td-level instruction patterns and MOV8 instructions name a proper
// RegisterClass.
def GR8 : RegisterClass<"Mov", [i8], 8,
  (add AL, CL, DL, BL, AH, CH, DH, BH)>;

// Singleton class for the shift-amount slot. x86's variable-amount shifts
// must take their count in CL — we don't model 8-bit subregisters in the
// shift selector yet, so the constraint is expressed at the i32 level and
// the printer hardcodes `cl` in the asm. Selection in MovISelDAGToDAG.cpp
// does an explicit CopyToReg ECX before emitting the shift.
def CCR : RegisterClass<"Mov", [i32], 32, (add ECX)>;

// EFLAGS — x86's status register. CMP writes the result of a compare
// here; Jcc reads it. We model it as a physical register so RA sees the
// Def/Use dependence, but we don't put it in any allocatable class — no
// virtual register ever lives here, and the CMP→Jcc dependence is
// additionally glued (in the SelectionDAG) so the scheduler can't slip
// a flag-clobbering instruction between them.
def EFLAGS : Register<"eflags"> {
  let Namespace = "Mov";
}
