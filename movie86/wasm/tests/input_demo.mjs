// End-to-end test for the generic button-input demo (input_demo.elf)
// and, through it, the whole mov-only input ABI: JS pushInput →
// CALL_POLL_INPUT → guest poll → framebuffer change.
//
// The smoke test (smoke.mjs) covers the small int-0x80 examples; this
// one is a separate, slower test because input_demo is a ~10 MB
// movfuscator binary that needs tens of millions of guest movs just to
// run its crt0 + reach the poll loop. Not wired into the fast CI smoke
// path — run it explicitly:
//
//   node tests/input_demo.mjs
//
// Asserts:
//   1. the guest sets video mode 13h,
//   2. it draws the initial (green) block at screen center,
//   3. pressing Right moves the block right and clears the old cells —
//      proving a pushInput() key actually reaches the guest and changes
//      what it draws.

import { readFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const root = `${here}/..`;

const wasm = await readFile(`${root}/build/browser/movie86_wasm_bg.wasm`);
const mod = await import(`${root}/build/browser/movie86_wasm.js`);
await mod.default({ module_or_path: wasm });
const { KEY } = await import(`${root}/movie86.mjs`);

// Mirrors input_demo.c.
const FB = 0xa0000;
const W = 320;
const H = 200;
const BLK = 16;
const STEP = 8;
const GREEN = 0xff00ff00;
const BLACK = 0xff000000;

const X0 = ((W - BLK) / 2) | 0; // 152
const Y0 = ((H - BLK) / 2) | 0; // 92
const MIDY = Y0 + BLK / 2; // 100

// Total guest-instruction budget before we give up waiting for a state.
// movfuscator's crt0 alone is millions of movs; the initial draw adds
// more. Generous on purpose — the test is correctness, not speed.
const BUDGET = 400_000_000n;
const BATCH = 4_000_000n;

const elf = new Uint8Array(await readFile(`${root}/examples/input_demo.elf`));
const vm = new mod.Vm(elf);

function pixel(px, py) {
    const b = vm.readMem(FB + (py * W + px) * 4, 4);
    if (b.length < 4) return null;
    return (b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24)) >>> 0;
}

// Step in batches until `pred()` holds or the budget runs out. Returns
// true if the predicate was satisfied.
function stepUntil(pred, label) {
    let spent = 0n;
    while (spent < BUDGET) {
        if (vm.haltReason) {
            throw new Error(`guest halted (${vm.haltReason}) while waiting for: ${label}`);
        }
        if (pred()) return true;
        vm.stepN(BATCH);
        spent += BATCH;
    }
    return pred();
}

let failed = 0;
try {
    // 1) video mode 13h
    assert.ok(stepUntil(() => vm.activeVideoMode === 0x13, 'video mode 13h'),
        'guest never set video mode 13h');

    // 2) initial green block at center
    assert.ok(stepUntil(() => pixel(X0 + BLK / 2, MIDY) === GREEN, 'initial block'),
        'initial green block never drawn at center');

    // 3) Right moves the block right and clears the old left edge.
    vm.pushInput(KEY.RIGHT);
    const newCovered = X0 + BLK + STEP / 2; // inside new block, outside old
    const oldEdge = X0 + 1; // old left edge, uncovered after the move
    assert.ok(stepUntil(() => pixel(newCovered, MIDY) === GREEN, 'block moved right'),
        'block did not move right after pushInput(RIGHT)');
    assert.equal(pixel(oldEdge, MIDY), BLACK,
        'old block cell was not cleared after moving right');

    console.log(`ok  input_demo  videoMode=13h, block draws + responds to Right  steps=${vm.steps}`);
} catch (e) {
    console.error(`FAIL input_demo: ${e.message}`);
    failed = 1;
} finally {
    vm.free();
}

process.exit(failed);
