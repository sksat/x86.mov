cmake_minimum_required(VERSION 3.20)
project(llvm-mov CXX C)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# We require LLVM 22.x. `find_package(LLVM 22)` would request an exact 22.0,
# which doesn't match an installed 22.1.x, so we look up unconstrained and
# enforce the major range manually.
find_package(LLVM REQUIRED CONFIG)
message(STATUS "Found LLVM ${LLVM_PACKAGE_VERSION}")
message(STATUS "Using LLVMConfig.cmake in: ${LLVM_DIR}")
if(LLVM_PACKAGE_VERSION VERSION_LESS 22.0
    OR LLVM_PACKAGE_VERSION VERSION_GREATER_EQUAL 23.0)
    message(FATAL_ERROR "llvm-mov requires LLVM 22.x (found ${LLVM_PACKAGE_VERSION})")
endif()

# Pull in AddLLVM / TableGen / HandleLLVMOptions
list(APPEND CMAKE_MODULE_PATH ${LLVM_CMAKE_DIR})

# `TableGen.cmake` requires LLVM_TABLEGEN_EXE to be set when used out-of-tree.
# Prefer the version-tagged binary that ships next to the matching cmake dir
# (e.g. `/usr/lib/llvm-22/bin/llvm-tblgen`), falling back to `llvm-tblgen`.
if(NOT DEFINED LLVM_TABLEGEN_EXE)
    find_program(LLVM_TABLEGEN_EXE
        NAMES "llvm-tblgen-${LLVM_VERSION_MAJOR}" llvm-tblgen
        HINTS "${LLVM_TOOLS_BINARY_DIR}"
        REQUIRED)
endif()
message(STATUS "Using llvm-tblgen: ${LLVM_TABLEGEN_EXE}")

include(AddLLVM)
include(TableGen)
include(HandleLLVMOptions)

include_directories(SYSTEM ${LLVM_INCLUDE_DIRS})
separate_arguments(LLVM_DEFINITIONS_LIST NATIVE_COMMAND ${LLVM_DEFINITIONS})
add_compile_definitions(${LLVM_DEFINITIONS_LIST})

# Allow includes like #include "MovGenRegisterInfo.inc" to find generated files
# next to our hand-written headers without long path prefixes.
include_directories(
    ${CMAKE_CURRENT_SOURCE_DIR}/llvm
    ${CMAKE_CURRENT_BINARY_DIR}/llvm
)

# The full backend (libLLVMMovCodeGen + LLVMMovDesc + LLVMMovInfo).
add_subdirectory(llvm)

# Self-contained `llc`-equivalent driver — links against libLLVMMov* + libLLVM-22.
add_subdirectory(tools/llvm-mov-llc)

enable_testing()
