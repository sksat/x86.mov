// End-to-end smoke test for movie86-wasm. Loads the wasm module the
// same way the browser will (via the wasm-bindgen --target web shim,
// pre-fed the .wasm bytes since Node doesn't have fetch+import.meta
// in the same way), then runs each bundled example ELF through both
// `runElf` (one-shot) and the step-driven `Vm` API, asserting exit
// code, stdout, and that the Vm path's step count + halt reason match
// the one-shot's. Catches:
//
//   - the JS ↔ Rust glue regressing in a way cargo build alone misses,
//   - example-elf bytes drifting away from what movie86 can load,
//   - default max_steps being too small for the bundled examples,
//   - Vm.stepN / regs / drain getters diverging from runElf semantics.
//
// Invoked from .github/workflows/movie86-wasm.yaml after build-wasm.

import { readFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const root = `${here}/..`;

const wasm = await readFile(`${root}/build/browser/movie86_wasm_bg.wasm`);
const mod  = await import(`${root}/build/browser/movie86_wasm.js`);
await mod.default({ module_or_path: wasm });

const cases = [
    { name: 'return42',   expectExit: 42, expectStdout: ''         },
    { name: 'hello',      expectExit: 0,  expectStdout: 'Hello\n'  },
    { name: 'call_greet', expectExit: 0,  expectStdout: 'Hi!\n'    },
];

const dec = new TextDecoder();

let failed = 0;
for (const c of cases) {
    const elf = new Uint8Array(await readFile(`${root}/examples/${c.name}.elf`));

    // 1) one-shot runElf path
    const r = mod.runElf(elf, undefined);
    const oneShot = { exit: r.exitCode, fault: r.fault, stdout: r.stdout, steps: r.steps };
    r.free();

    // 2) step-driven Vm path — same elf, batched stepN until halt.
    const vm = new mod.Vm(elf);
    let stdoutBytes = new Uint8Array(0);
    while (!vm.haltReason) {
        vm.stepN(10000n);
        const chunk = vm.drainStdout();
        if (chunk.length) {
            const merged = new Uint8Array(stdoutBytes.length + chunk.length);
            merged.set(stdoutBytes); merged.set(chunk, stdoutBytes.length);
            stdoutBytes = merged;
        }
    }
    const stepped = {
        exit: vm.exitCode,
        fault: vm.haltReason,
        stdout: dec.decode(stdoutBytes),
        steps: vm.steps,
    };
    vm.free();

    try {
        // one-shot expectations
        assert.equal(oneShot.fault, undefined,
            `${c.name}: runElf unexpected fault ${oneShot.fault}`);
        assert.equal(oneShot.exit, c.expectExit,
            `${c.name}: runElf exit ${oneShot.exit} != ${c.expectExit}`);
        assert.equal(oneShot.stdout, c.expectStdout,
            `${c.name}: runElf stdout ${JSON.stringify(oneShot.stdout)} != ${JSON.stringify(c.expectStdout)}`);

        // step-driven Vm should agree with the one-shot byte-for-byte.
        assert.equal(stepped.exit, oneShot.exit,
            `${c.name}: Vm exit ${stepped.exit} != runElf ${oneShot.exit}`);
        assert.equal(stepped.stdout, oneShot.stdout,
            `${c.name}: Vm stdout disagrees with runElf`);
        assert.equal(stepped.steps, oneShot.steps,
            `${c.name}: Vm steps ${stepped.steps} != runElf ${oneShot.steps}`);

        console.log(`ok  ${c.name}  exit=${oneShot.exit} steps=${oneShot.steps}`);
    } catch (e) {
        console.error(`FAIL ${c.name}: ${e.message}`);
        failed++;
    }
}

// --- Vm introspection API surface ---
//
// The runElf↔Vm parity loop above exercises stepN / regs / haltReason /
// exitCode / drainStdout, but the demo also depends on disasmAt,
// readMem, sigsegvHandler / sigillHandler, memBase / memLen. Verify
// those on a known-shape fixture (return42: entry 0x1000, first insn
// is `mov ebx, 42` = BB 2A 00 00 00, no signal handlers).
try {
    const elf = new Uint8Array(await readFile(`${root}/examples/return42.elf`));
    const vm = new mod.Vm(elf);
    try {
        // EIP must fall inside the mapped region the loader handed us.
        assert.ok(
            vm.memBase <= vm.eip && vm.eip < vm.memBase + vm.memLen,
            `eip ${vm.eip.toString(16)} not inside [${vm.memBase.toString(16)}, ${(vm.memBase + vm.memLen).toString(16)})`,
        );

        // disasmAt at entry: the first instruction of return42 is
        // `mov ebx, 42` encoded as BB 2A 00 00 00 (5 bytes).
        const d = vm.disasmAt(vm.eip);
        assert.ok(d != null, 'disasmAt(entry) returned null');
        try {
            assert.equal(d.len, 5, `mov ebx, imm32 should be 5 bytes, got ${d.len}`);
            assert.deepEqual(
                Array.from(d.bytes),
                [0xbb, 0x2a, 0x00, 0x00, 0x00],
                `disasmAt bytes mismatch: got ${Array.from(d.bytes).map(b => b.toString(16).padStart(2, '0')).join(' ')}`,
            );
            assert.ok(d.text.includes('Mov'), `disasmAt text should mention Mov, got ${d.text}`);
        } finally {
            d.free();
        }

        // readMem in-range: same 5 bytes as disasmAt
        const inRange = vm.readMem(vm.eip, 5);
        assert.deepEqual(
            Array.from(inRange),
            [0xbb, 0x2a, 0x00, 0x00, 0x00],
            'readMem(eip, 5) disagrees with disasmAt bytes',
        );

        // readMem out-of-range: address well past the mapped region.
        // Pick something high enough to be safe across loader layouts.
        const farAway = 0xfff0_0000 >>> 0;
        assert.equal(
            vm.readMem(farAway, 16).length, 0,
            'readMem past mapped region should return an empty array',
        );

        // Signal handlers: return42 doesn't define `dispatch` or
        // `master_loop`, so both getters surface undefined.
        assert.equal(vm.sigsegvHandler, undefined, `sigsegvHandler expected undefined, got ${vm.sigsegvHandler}`);
        assert.equal(vm.sigillHandler,  undefined, `sigillHandler expected undefined, got ${vm.sigillHandler}`);

        console.log('ok  Vm introspection (return42)');
    } finally {
        vm.free();
    }
} catch (e) {
    console.error(`FAIL Vm introspection: ${e.message}`);
    failed++;
}

// --- Canvas pipeline smoke ---
//
// canvas_smile draws a yellow filled circle at (160, 100) in mode 13h
// (320×200 RGBA mapped at 0xA0000). Run to completion, then verify
// that (a) a known-yellow pixel landed where we expect, and (b) a
// corner pixel stayed BSS-zero. This is the only test that exercises
// the multi-PT_LOAD loader path + the demo's memory-mapped framebuffer
// convention end-to-end.
try {
    const elf = new Uint8Array(await readFile(`${root}/examples/canvas_smile.elf`));
    const vm = new mod.Vm(elf);
    try {
        while (!vm.haltReason) vm.stepN(20000n);
        assert.equal(vm.exitCode, 0,
            `canvas_smile should exit 0, got ${vm.exitCode} (halt=${vm.haltReason})`);

        // FB layout: mode 13h base 0xA0000, RGBA, stride = 320 * 4.
        const FB_ADDR = 0x000A_0000;
        const FB_W = 320;
        const centerOffset = (100 * FB_W + 160) * 4;
        const center = vm.readMem(FB_ADDR + centerOffset, 4);
        // The face fill is rgba(255, 220, 60, 255).
        assert.deepEqual(Array.from(center), [255, 220, 60, 255],
            `canvas_smile center pixel = ${Array.from(center).join(',')} (expected 255,220,60,255)`);

        // Top-left corner should still be BSS-zeroed (face doesn't reach here).
        const corner = vm.readMem(FB_ADDR, 4);
        assert.deepEqual(Array.from(corner), [0, 0, 0, 0],
            `canvas_smile (0,0) = ${Array.from(corner).join(',')} (expected all-zero BSS)`);

        console.log(`ok  canvas_smile  exit=0 center=yellow corner=zero`);
    } finally {
        vm.free();
    }
} catch (e) {
    console.error(`FAIL canvas_smile: ${e.message}`);
    failed++;
}

if (failed > 0) {
    console.error(`${failed} smoke test(s) failed`);
    process.exit(1);
}
console.log('all smoke tests passed');
