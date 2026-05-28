add_llvm_component_library(LLVMMovDesc
  MovInstPrinter.cpp
  MovMCAsmInfo.cpp
  MovMCTargetDesc.cpp

  LINK_COMPONENTS
  MC
  MCDisassembler
  Support
  MovInfo

  DEPENDS
  MovCommonTableGen
)
