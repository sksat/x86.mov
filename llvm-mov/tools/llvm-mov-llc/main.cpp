//===-- llvm-mov-llc.cpp - .ll -> mov-target asm driver -------------------===//
//
// Self-contained replacement for `llc -mtriple=mov-...`. We don't depend on
// stock `llc --load`-style plugin loading (it's brittle across distro builds);
// instead, we statically register the Mov target right here and run a tiny
// version of llc's codegen pipeline.
//
// Usage:
//   llvm-mov-llc input.ll [-o output.s]
//   echo '...' | llvm-mov-llc -o -
//
//===----------------------------------------------------------------------===//

#include "llvm/Analysis/TargetTransformInfo.h"
#include "llvm/CodeGen/CommandFlags.h"
#include "llvm/IR/LLVMContext.h"
#include "llvm/IR/LegacyPassManager.h"
#include "llvm/IR/Module.h"
#include "llvm/IRReader/IRReader.h"
#include "llvm/MC/TargetRegistry.h"
#include "llvm/Pass.h"
#include "llvm/Support/CommandLine.h"
#include "llvm/Support/FileSystem.h"
#include "llvm/Support/InitLLVM.h"
#include "llvm/Support/SourceMgr.h"
#include "llvm/Support/ToolOutputFile.h"
#include "llvm/Support/WithColor.h"
#include "llvm/Support/raw_ostream.h"
#include "llvm/Target/TargetMachine.h"
#include "llvm/Target/TargetOptions.h"
#include "llvm/TargetParser/Triple.h"

using namespace llvm;

// Statically registered by the Mov target libraries; declared here so the
// linker pulls them in without -Wl,--whole-archive games.
extern "C" void LLVMInitializeMovTargetInfo();
extern "C" void LLVMInitializeMovTarget();
extern "C" void LLVMInitializeMovTargetMC();
extern "C" void LLVMInitializeMovAsmPrinter();

static cl::opt<std::string> InputFilename(cl::Positional,
                                          cl::desc("<input .ll | -> stdin>"),
                                          cl::init("-"));
static cl::opt<std::string> OutputFilename("o",
                                           cl::desc("Output filename ('-' for stdout)"),
                                           cl::value_desc("filename"),
                                           cl::init("-"));
static cl::opt<std::string> MTriple("mtriple",
                                    cl::desc("Override target triple"),
                                    cl::init("mov-unknown-linux-gnu"));

int main(int argc, char **argv) {
  InitLLVM X(argc, argv);

  // Register our backend with the global registry. Same pattern llc uses,
  // just narrowed to the one target we care about.
  LLVMInitializeMovTargetInfo();
  LLVMInitializeMovTarget();
  LLVMInitializeMovTargetMC();
  LLVMInitializeMovAsmPrinter();

  cl::ParseCommandLineOptions(argc, argv,
                              "llvm-mov-llc — .ll -> mov-target asm\n");

  LLVMContext Ctx;
  SMDiagnostic Err;
  std::unique_ptr<Module> M = parseIRFile(InputFilename, Err, Ctx);
  if (!M) {
    Err.print(argv[0], errs());
    return 1;
  }

  // Resolve the effective triple. Three sources, in priority order:
  //   1. explicit -mtriple on the command line
  //   2. the input module's `target triple = "..."`
  //   3. the cl::opt default ("mov-unknown-linux-gnu")
  //
  // Silently overwriting the module's triple (the old behaviour) would
  // miscompile any frontend-produced IR — e.g. `rustc --emit=llvm-ir`
  // emits `i686-...` and we'd reinterpret pointer/aggregate layout as
  // a Mov module without diagnosing the mismatch. So if the module has
  // a triple and the user did NOT pass -mtriple, we honour the module's
  // — but its architecture must be `mov`, otherwise we refuse.
  Triple TheTriple;
  if (MTriple.getNumOccurrences() > 0) {
    TheTriple = Triple(MTriple);
  } else if (!M->getTargetTriple().str().empty()) {
    TheTriple = M->getTargetTriple();
  } else {
    TheTriple = Triple(MTriple); // cl::opt default
  }

  // Refuse anything that isn't a Mov triple — both arch-name and
  // legacy-arch-enum, since older IR can use either form.
  if (TheTriple.getArchName() != "mov" &&
      TheTriple.getArch() != Triple::UnknownArch) {
    WithColor::error(errs(), argv[0])
        << "input module triple '" << TheTriple.str()
        << "' is not a Mov triple; pass -mtriple=mov-... to override.\n";
    return 1;
  }

  std::string ErrorString;
  const Target *TheTarget =
      TargetRegistry::lookupTarget(/*ArchName=*/"mov", TheTriple, ErrorString);
  if (!TheTarget) {
    WithColor::error(errs(), argv[0]) << ErrorString;
    return 1;
  }

  TargetOptions Options;
  std::unique_ptr<TargetMachine> TM(TheTarget->createTargetMachine(
      TheTriple, /*CPU=*/"", /*Features=*/"", Options,
      Reloc::Static, std::nullopt, CodeGenOptLevel::Default));
  if (!TM) {
    WithColor::error(errs(), argv[0]) << "could not allocate TargetMachine\n";
    return 1;
  }

  // Same story for data layout: if the module supplied one and it differs
  // from ours, refuse rather than silently re-laying-out the program.
  std::string TargetLayout = TM->createDataLayout().getStringRepresentation();
  const std::string &ModuleLayout = M->getDataLayoutStr();
  if (!ModuleLayout.empty() && ModuleLayout != TargetLayout) {
    WithColor::error(errs(), argv[0])
        << "input module data layout '" << ModuleLayout
        << "' does not match the Mov target's '" << TargetLayout << "'.\n";
    return 1;
  }
  M->setDataLayout(TM->createDataLayout());
  M->setTargetTriple(TheTriple);

  std::error_code EC;
  auto Out = std::make_unique<ToolOutputFile>(OutputFilename, EC,
                                              sys::fs::OF_None);
  if (EC) {
    WithColor::error(errs(), argv[0]) << EC.message() << "\n";
    return 1;
  }

  legacy::PassManager PM;
  if (TM->addPassesToEmitFile(PM, Out->os(), /*DwoOut=*/nullptr,
                              CodeGenFileType::AssemblyFile,
                              /*DisableVerify=*/false)) {
    WithColor::error(errs(), argv[0])
        << "target does not support assembly file emission\n";
    return 1;
  }

  PM.run(*M);
  Out->keep();
  return 0;
}
