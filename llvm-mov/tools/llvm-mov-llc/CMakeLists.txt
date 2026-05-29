add_llvm_executable(llvm-mov-llc
  main.cpp
)

# Place the binary under build/bin/ so test/Execution/run.sh and downstream
# tooling have a predictable path regardless of the source-tree layout.
set_target_properties(llvm-mov-llc PROPERTIES
  RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

target_link_libraries(llvm-mov-llc
  PRIVATE
  LLVMMovCodeGen
  LLVMMovDesc
  LLVMMovInfo
)

# Distros differ on how LLVM ships: apt.llvm.org installs the per-
# component static libs (libLLVMCodeGen.a, …), while Arch (and any
# `LLVM_LINK_LLVM_DYLIB=ON` build) ships a single monolithic
# `libLLVM.so` and *no* component archives — there, mapping components
# to `-lLLVM<Component>` fails to link. Prefer the dylib when LLVM was
# built that way; fall back to component libs otherwise.
if(LLVM_LINK_LLVM_DYLIB)
  target_link_libraries(llvm-mov-llc PRIVATE LLVM)
else()
  llvm_map_components_to_libnames(LLVM_LIBS
    AsmPrinter
    CodeGen
    Core
    IRReader
    MC
    ScalarOpts
    SelectionDAG
    Support
    Target
    TransformUtils
  )
  target_link_libraries(llvm-mov-llc PRIVATE ${LLVM_LIBS})
endif()
