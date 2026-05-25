//===-- MovCallingConv.td --------------------------------*- tablegen -*-===//
//
// Minimum cdecl-flavoured calling convention: i32 return in EAX, i32 arguments
// passed on the stack (caller-cleaned), no floating-point handling yet.
//
//===----------------------------------------------------------------------===//

// Stage 3.5: i1/i8/i16 narrow ints now ride i32 slots in the cdecl ABI.
// CCPromoteToType<i32> stamps the LocVT/LocInfo so LowerFormalArguments and
// LowerReturn can issue the matching TRUNCATE / ANY_EXTEND nodes around
// the 4-byte memory slot.
def CC_Mov : CallingConv<[
  CCIfType<[i1, i8, i16], CCPromoteToType<i32>>,
  CCIfType<[i32], CCAssignToStack<4, 4>>
]>;

def RetCC_Mov : CallingConv<[
  CCIfType<[i1, i8, i16], CCPromoteToType<i32>>,
  CCIfType<[i32], CCAssignToReg<[EAX]>>
]>;

// Callee-saved: cdecl ultimately wants EBX, ESI, EDI, EBP preserved across
// calls — but until [[MovFrameLowering]] emits a real prologue/epilogue
// (stage 4+) we cannot honour that contract. Advertising a CSR set we can't
// preserve is worse than admitting none: register allocation would happily
// hand a value EBX, the function would clobber it, and the caller's invariant
// would break silently. Empty set keeps the contract truthful at stage 0–3;
// re-add the cdecl set the same commit that lands prologue/epilogue.
def CSR_Mov : CalleeSavedRegs<(add)>;
