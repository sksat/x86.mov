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
    const fakeStartObj = new Uint8Array([0x7f, 0x45, 0x4c, 0x46, 0x02]);
    const fakeElf = new Uint8Array([0x7f, 0x45, 0x4c, 0x46, 0x01, 0x01]);

    const wrappers = {
        movfuscator: {
            compile: async (src, headers) => {
                calls.push(['mov-compile', src, headers]);
                return fakeAsm;
            },
            assemble: async (asm) => {
                calls.push(['assemble', asm]);
                // Distinguish the _start.s asm so the llvm-mov path
                // assertions below can confirm it's the auto-staged one.
                return asm.includes('_start:') ? fakeStartObj : fakeObj;
            },
            link: async (objs, libs, opts) => {
                calls.push(['link', objs, opts]);
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
    // movfuscator path keeps the historical dynamic / movfuscator-CRT
    // recipe — the explorer doesn't force static here because the
    // movie86 master_loop fault is a separate investigation.
    const movLinkCall = calls.find(c => c[0] === 'link');
    assert.notEqual(movLinkCall[2]?.static, true,
        'movfuscator path should stay dynamic until the master_loop fault is fixed');

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
    // llvm-mov calls `assemble` twice: once for the user asm, once for
    // the auto-staged `_start.s` that drives main() then hits the
    // mov-only ABI exit address. Link then receives both objects in a
    // Record so the basenames land in the ELF's .symtab in a
    // predictable order.
    assert.deepEqual(
        calls.map(c => c[0]),
        ['cToIR', 'llvm-compile', 'assemble', 'assemble', 'link'],
        'llvm-mov order: cToIR → compile → assemble user → assemble _start → link',
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
    // The link call must be the movie86-compatible flavour:
    //   - static (no PT_INTERP / PT_DYNAMIC)
    //   - runtime: 'none' (caller-supplied _start, no movfuscator CRT)
    //   - inputs are a Record so both _start.o and the user .o end up
    //     in the link command, with _start.o first so ld -static
    //     pulls main from the user .o left-to-right.
    const llvmLinkCall = calls.find(c => c[0] === 'link');
    const [, llvmLinkObjs, llvmLinkOpts] = llvmLinkCall;
    assert.equal(llvmLinkOpts?.static, true, 'llvm-mov path must link statically');
    assert.equal(llvmLinkOpts?.runtime, 'none',
        'llvm-mov path must use runtime: none (caller supplies _start)');
    assert.equal(typeof llvmLinkObjs, 'object');
    assert.ok(!(llvmLinkObjs instanceof Uint8Array),
        'llvm-mov link inputs must be a Record so both _start.o and explorer.o stage');
    const objNames = Object.keys(llvmLinkObjs);
    assert.deepEqual(objNames, ['_start.o', 'explorer.o'],
        '_start.o must come before the user object so ld -static resolves main()');
    assert.equal(llvmLinkObjs['_start.o'], fakeStartObj);
    assert.equal(llvmLinkObjs['explorer.o'], fakeObj);
});

test('compileWithCompiler — caller linkOpts override the llvm-mov defaults', async () => {
    // The explorer's own UI doesn't surface a Static toggle, but the
    // public API still lets a caller flip back to dynamic / movfuscator
    // runtime if they want to inspect that variant. Spread order in
    // explorer.mjs puts caller opts last, so the override actually wins.
    const calls = [];
    const wrappers = {
        movfuscator: {
            assemble: async () => new Uint8Array([0x7f]),
            link: async (objs, libs, opts) => {
                calls.push({ objs, opts });
                return new Uint8Array([0x7f, 0x45]);
            },
        },
        llvmMov: {
            cToIR: async () => 'ir',
            compile: async () => 'asm',
        },
    };
    const { compileWithCompiler } = await import('../explorer.mjs');
    await compileWithCompiler({
        compiler: 'llvm-mov',
        source: 'int main(){return 0;}',
        opts: { linkOpts: { static: false, runtime: 'movfuscator' } },
        wrappers,
    });
    assert.equal(calls[0].opts.static, false, 'caller can opt back to dynamic');
    assert.equal(calls[0].opts.runtime, 'movfuscator',
        'caller can opt back to the movfuscator CRT');
});

test("compileWithCompiler — linkProfile 'canvas13h' wires the framebuffer stubs (llvm-mov)", async () => {
    // The explorer's canvas presets (mode-13h mandelbrot) need three
    // things the plain llvm-mov path doesn't: the mov-only ABI stubs
    // (`set_video_mode` / `mmap_request` / `exit`) plus a `.fb13h` BSS
    // section pinned at the VGA base 0xA0000. `opts.linkProfile:
    // 'canvas13h'` is the declarative switch that assembles the stubs
    // object, threads it into the link inputs, and injects the two raw
    // ld flags (`--section-start` + `--undefined`). The mov-only-ABI asm
    // lives in explorer.mjs, not in the preset data, so presets stay
    // pure source strings.
    const calls = [];
    const wrappers = {
        movfuscator: {
            assemble: async (asm) => {
                calls.push(['assemble', asm]);
                // Tag each assembled object by which recipe it came from
                // so the link assertions can identify them.
                if (asm.includes('_start:')) return new Uint8Array([1]);
                if (asm.includes('set_video_mode')) return new Uint8Array([2]);
                return new Uint8Array([3]);
            },
            link: async (objs, libs, opts) => {
                calls.push(['link', objs, opts]);
                return new Uint8Array([0x7f, 0x45]);
            },
        },
        llvmMov: {
            cToIR: async () => 'ir',
            compile: async () => 'asm',
        },
    };
    const { compileWithCompiler } = await import('../explorer.mjs');
    await compileWithCompiler({
        compiler: 'llvm-mov',
        source: 'int main(void){ return 0; }',
        opts: { linkProfile: 'canvas13h' },
        wrappers,
    });

    // The stubs source must be assembled (in addition to user asm +
    // _start.s), so `assemble` runs three times for the canvas profile.
    const assembleCalls = calls.filter((c) => c[0] === 'assemble');
    assert.ok(
        assembleCalls.some((c) => c[1].includes('set_video_mode')),
        'canvas13h must assemble the mov-only ABI framebuffer stubs',
    );

    const [, linkObjs, linkOpts] = calls.find((c) => c[0] === 'link');
    assert.ok(!(linkObjs instanceof Uint8Array), 'link inputs must be a Record');
    assert.deepEqual(
        Object.keys(linkObjs),
        ['_start.o', 'explorer.o', 'stubs.o'],
        'stubs.o must join _start.o + the user object in the link inputs',
    );
    assert.equal(linkOpts.static, true, 'canvas13h still links statically');
    assert.equal(linkOpts.runtime, 'none', 'canvas13h keeps runtime: none');
    assert.deepEqual(
        linkOpts.extraLdArgs,
        ['--section-start=.fb13h=0xA0000', '--undefined=_fb13h_region'],
        'canvas13h must pin .fb13h at 0xA0000 and keep its region symbol live',
    );
});

test('compileWithCompiler — no linkProfile leaves the llvm-mov link inputs minimal', async () => {
    // Regression guard: the default (profile-less) llvm-mov path must
    // NOT link the canvas stubs or inject section-start flags — every
    // existing preset (return42, hello, …) links just `_start.o` + the
    // user object, with no extraLdArgs.
    const calls = [];
    const wrappers = {
        movfuscator: {
            assemble: async () => new Uint8Array([1]),
            link: async (objs, libs, opts) => {
                calls.push({ objs, opts });
                return new Uint8Array([0x7f]);
            },
        },
        llvmMov: { cToIR: async () => 'ir', compile: async () => 'asm' },
    };
    const { compileWithCompiler } = await import('../explorer.mjs');
    await compileWithCompiler({
        compiler: 'llvm-mov',
        source: 'int main(void){ return 0; }',
        wrappers,
    });
    const { objs, opts } = calls[0];
    assert.deepEqual(Object.keys(objs), ['_start.o', 'explorer.o'],
        'default path links no stubs.o');
    assert.equal(opts.extraLdArgs, undefined,
        'default path injects no raw ld flags');
});
