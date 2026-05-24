//===-- MovCallingConv.td --------------------------------*- tablegen -*-===//
//
// Minimum cdecl-flavoured calling convention: i32 return in EAX, i32 arguments
// passed on the stack (caller-cleaned), no floating-point handling yet.
//
//===----------------------------------------------------------------------===//

def CC_Mov : CallingConv<[
  // Promote anything narrower to i32 — we only have GPR32 right now.
  CCIfType<[i1, i8, i16], CCPromoteToType<i32>>,

  // All i32 arguments go on the stack, 4-byte slots.
  CCIfType<[i32], CCAssignToStack<4, 4>>
]>;

def RetCC_Mov : CallingConv<[
  CCIfType<[i1, i8, i16], CCPromoteToType<i32>>,
  CCIfType<[i32], CCAssignToReg<[EAX]>>
]>;

// Callee-saved: cdecl says EBX, ESI, EDI, EBP. We keep ESP unsaved (stack
// pointer) and EAX/ECX/EDX as scratch.
def CSR_Mov : CalleeSavedRegs<(add EBX, ESI, EDI, EBP)>;
