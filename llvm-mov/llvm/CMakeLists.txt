# TableGen umbrella for the Mov target. Every .inc consumer below depends on
# MovCommonTableGen so a single tablegen run satisfies the whole tree.
set(LLVM_TARGET_DEFINITIONS Mov.td)

tablegen(LLVM MovGenRegisterInfo.inc   -gen-register-info)
tablegen(LLVM MovGenInstrInfo.inc      -gen-instr-info)
tablegen(LLVM MovGenSubtargetInfo.inc  -gen-subtarget)
tablegen(LLVM MovGenAsmWriter.inc      -gen-asm-writer)
tablegen(LLVM MovGenDAGISel.inc        -gen-dag-isel)
tablegen(LLVM MovGenCallingConv.inc    -gen-callingconv)

add_public_tablegen_target(MovCommonTableGen)

# MC layer + Target info first — the codegen library links against them.
add_subdirectory(MCTargetDesc)
add_subdirectory(TargetInfo)

add_llvm_component_library(LLVMMovCodeGen
  MovAsmPrinter.cpp
  MovFrameLowering.cpp  # header-only currently; placeholder for the .cpp once it has body
  MovISelDAGToDAG.cpp
  MovISelLowering.cpp
  MovInstrInfo.cpp
  MovRegisterInfo.cpp
  MovSubtarget.cpp
  MovTargetMachine.cpp

  LINK_COMPONENTS
  Analysis
  AsmPrinter
  CodeGen
  CodeGenTypes
  Core
  MC
  SelectionDAG
  Support
  Target
  MovDesc
  MovInfo

  DEPENDS
  MovCommonTableGen
)
