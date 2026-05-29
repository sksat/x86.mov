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

# LLVM ships in two link flavours. apt.llvm.org (Debian/Ubuntu CI) provides
# per-component static archives (libLLVMCodeGen.a, ...). Arch's `llvm` package
# ships ONLY the monolithic libLLVM.so and sets LLVM_LINK_LLVM_DYLIB=ON, so the
# per-component names below don't exist as link targets there. Pick the flavour
# the installed LLVM actually offers.
if(LLVM_LINK_LLVM_DYLIB)
  set(LLVM_LIBS LLVM)
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
endif()

target_link_libraries(llvm-mov-llc PRIVATE ${LLVM_LIBS})
