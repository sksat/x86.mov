//===-- MovCallingConv.td --------------------------------*- tablegen -*-===//
//
// Minimum cdecl-flavoured calling convention: i32 return in EAX, i32 arguments
// passed on the stack (caller-cleaned), no floating-point handling yet.
//
//===----------------------------------------------------------------------===//

// Stage 2: i32-only. The `CCPromoteToType<i32>` rule for i1/i8/i16 is a
// no-op in practice — SelectionDAG type-legalizes them to i32 before CC
// dispatch sees them — and keeping it gave the false impression that
// narrow integer args were supported. We drop the rule (and check
// Ins[i].ArgVT in LowerFormalArguments) so attempting i8/i16 fails
// loudly instead of silently routing through an extending load that
// MOV32rm can't match. Re-enable the promotion (with matching DAG
// unpacking in LowerFormalArguments) at stage 3.
def CC_Mov : CallingConv<[
  CCIfType<[i32], CCAssignToStack<4, 4>>
]>;

def RetCC_Mov : CallingConv<[
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
