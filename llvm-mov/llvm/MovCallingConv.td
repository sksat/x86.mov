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
  // Stage 6b — byval struct passing. cdecl puts the struct's bytes
  // directly on the outgoing arg stack at the struct's natural
  // alignment; CCPassByVal<MinSize, MinAlign> says the floor is
  // i32-sized + i32-aligned. The actual size / alignment come from
  // the call site's ArgFlagsTy.
  CCIfByVal<CCPassByVal<4, 4>>,
  CCIfType<[i1, i8, i16], CCPromoteToType<i32>>,
  CCIfType<[i32], CCAssignToStack<4, 4>>
]>;

def RetCC_Mov : CallingConv<[
  CCIfType<[i1, i8, i16], CCPromoteToType<i32>>,
  // Stage 6b — two-i32 (EDX:EAX) multi-value returns enable Rust's
  // 8-byte struct returns (e.g. `(ptr, ptr)`, `(usize, usize)`)
  // without forcing sret. cdecl convention: first i32 in EAX, second
  // in EDX. Aggregate returns bigger than 8 bytes still use sret,
  // which the LowerCall path handles separately.
  CCIfType<[i32], CCAssignToReg<[EAX, EDX]>>
]>;

// Callee-saved: cdecl says EBX, ESI, EDI, EBP. EBP is excluded from this
// list because MovFrameLowering owns it as the frame pointer (always
// reserved, always saved/restored in emitPrologue/emitEpilogue with the
// PUSH32r/POP32r pair). Adding EBP here on top would result in a double
// save. PEI uses storeRegToStackSlot/loadRegFromStackSlot (the stage-4b
// real implementations) to spill the CSRs it actually finds used.
def CSR_Mov : CalleeSavedRegs<(add EBX, ESI, EDI)>;
