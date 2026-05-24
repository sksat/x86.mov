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
