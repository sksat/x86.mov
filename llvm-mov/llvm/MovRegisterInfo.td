//===-- MovRegisterInfo.td -------------------------------*- tablegen -*-===//
//
// 8 general-purpose 32-bit registers, named like the x86 set so the printer
// can emit them verbatim. The encoding values (`HWEncoding`) mirror the x86
// modR/M reg field — useful later when we attach an MCCodeEmitter; harmless
// while we're text-only.
//
//===----------------------------------------------------------------------===//

class MovReg<bits<4> num, string n> : Register<n> {
  let Namespace          = "Mov";
  let HWEncoding{3-0}    = num;
}

def EAX : MovReg<0, "eax">, DwarfRegNum<[0]>;
def ECX : MovReg<1, "ecx">, DwarfRegNum<[1]>;
def EDX : MovReg<2, "edx">, DwarfRegNum<[2]>;
def EBX : MovReg<3, "ebx">, DwarfRegNum<[3]>;
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

// Singleton class for the shift-amount slot. x86's variable-amount shifts
// must take their count in CL — we don't model 8-bit subregisters yet,
// so the constraint is expressed at the i32 level and the printer hardcodes
// `cl` in the asm. Selection in MovISelDAGToDAG.cpp does an explicit
// CopyToReg ECX before emitting the shift.
def CCR : RegisterClass<"Mov", [i32], 32, (add ECX)>;
