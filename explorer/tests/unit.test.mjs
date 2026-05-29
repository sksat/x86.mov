// Node-level unit tests for `explorer.mjs` — the unified compile API
// that wraps movfuscator-wasm and llvm-mov-wasm behind a single shape.
// Run via `node --test tests/unit.test.mjs` (or `make test-unit`).
//
// These tests do **not** touch the actual wasm pipelines (which need a
// `make build` upstream and ~80 MB of clang.wasm); they pin the
// module's *surface*: exported names, supported compiler ids, normalized
// result shape, error behaviour for unknown compilers. The full
// compile + run round-trip lives in the Playwright E2E (tests/e2e/),
// which is gated on `make build` having produced the wasm artifacts.

import { test } from 'node:test';
import assert from 'node:assert/strict';

test('explorer.mjs exports COMPILERS list', async () => {
    const mod = await import('../explorer.mjs');
    assert.ok(Array.isArray(mod.COMPILERS), 'COMPILERS must be an array');
    assert.deepEqual(
        [...mod.COMPILERS].sort(),
        ['llvm-mov', 'movfuscator'],
        'two compilers exposed today',
    );
});

test('explorer.mjs exports compileWithCompiler', async () => {
    const mod = await import('../explorer.mjs');
    assert.equal(typeof mod.compileWithCompiler, 'function');
});

test('compileWithCompiler rejects unknown compiler ids loudly', async () => {
    const { compileWithCompiler } = await import('../explorer.mjs');
    await assert.rejects(
        () => compileWithCompiler({ compiler: 'gcc', source: 'int main(){return 0;}' }),
        /unknown compiler.*gcc/i,
        'mistyped compiler ids should fail fast at the boundary',
    );
});

test('compileWithCompiler uses injected wrappers (no real wasm load)', async () => {
    // Dependency-inject the two compiler wrappers + the assembler /
    // linker so this test stays a unit test: no clang.wasm load, no
    // ~24 MB lib bundle fetch. Verifies the orchestration logic
    // (which pipeline stages are called in which order, and how the
    // normalized result is assembled) without spinning up Emscripten.
    const calls = [];
    const fakeAsm = '/* movfuscator asm */\n';
    const fakeIr = '; ModuleID = "in.c"\n';
    const fakeLlvmAsm = '/* llvm-mov asm */\n';
    const fakeObj = new Uint8Array([0x7f, 0x45, 0x4c, 0x46, 0x01]);
    const fakeElf = new Uint8Array([0x7f, 0x45, 0x4c, 0x46, 0x01, 0x01]);

    const wrappers = {
        movfuscator: {
            compile: async (src, headers) => {
                calls.push(['mov-compile', src, headers]);
                return fakeAsm;
            },
            assemble: async (asm) => {
                calls.push(['assemble', asm]);
                return fakeObj;
            },
            link: async (obj, libs, opts) => {
                calls.push(['link', obj.length, opts?.name]);
                return fakeElf;
            },
        },
        llvmMov: {
            cToIR: async (src, opts) => {
                calls.push(['cToIR', src, opts]);
                return fakeIr;
            },
            compile: async (ir, opts) => {
                calls.push(['llvm-compile', ir, opts]);
                return fakeLlvmAsm;
            },
        },
    };

    const { compileWithCompiler } = await import('../explorer.mjs');

    const movRes = await compileWithCompiler({
        compiler: 'movfuscator',
        source: 'int main(){return 42;}',
        wrappers,
    });
    assert.equal(movRes.compiler, 'movfuscator');
    assert.equal(movRes.ir, null, 'movfuscator does not expose IR');
    assert.equal(movRes.asm, fakeAsm);
    assert.equal(movRes.elf, fakeElf);
    assert.ok(movRes.timings.total >= 0);
    assert.deepEqual(
        calls.map(c => c[0]),
        ['mov-compile', 'assemble', 'link'],
        'movfuscator order: compile → assemble → link',
    );

    calls.length = 0;
    const llvmRes = await compileWithCompiler({
        compiler: 'llvm-mov',
        source: 'int main(){return 42;}',
        opts: { optLevel: '2', clangFlags: ['-DFOO=1'] },
        wrappers,
    });
    assert.equal(llvmRes.compiler, 'llvm-mov');
    assert.equal(llvmRes.ir, fakeIr, 'llvm-mov exposes the IR pane');
    assert.equal(llvmRes.asm, fakeLlvmAsm);
    assert.equal(llvmRes.elf, fakeElf);
    assert.deepEqual(
        calls.map(c => c[0]),
        ['cToIR', 'llvm-compile', 'assemble', 'link'],
        'llvm-mov order: cToIR → compile (IR→asm) → assemble → link',
    );
    // Opt level + clang flags must reach the C-frontend; mtriple must
    // override the i386 triple clang stamps into the IR otherwise
    // llvm-mov-llc refuses with "expected mov-... triple".
    const cIrCall = calls.find(c => c[0] === 'cToIR');
    assert.equal(cIrCall[2].optLevel, '2');
    assert.deepEqual(cIrCall[2].clangFlags, ['-DFOO=1']);
    const irCompileCall = calls.find(c => c[0] === 'llvm-compile');
    assert.ok(
        irCompileCall[2].mtriple?.startsWith('mov-'),
        'IR → asm must force a mov-* triple, not the clang default',
    );
});
