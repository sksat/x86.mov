add_llvm_component_library(LLVMMovInfo
  MovTargetInfo.cpp

  LINK_COMPONENTS
  MC
  Support
)
