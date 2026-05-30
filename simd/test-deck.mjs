// End-to-end test for a SIMD86 deck: load the mov-only deck.elf into
// movie86, then drive it with key input and assert the framebuffer
// shows the expected slide. Proves the whole flip path — pushInput →
// CALL_POLL_INPUT → deck.c index move → blit of the new slide.
//
// Runs against the movie86 wasm build (../movie86/wasm/build/browser);
// run `make -C movie86/wasm build-wasm` first. Standalone:
//
//   node test-deck.mjs

import { readFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const m86 = `${here}/../movie86/wasm`;

const wasm = await readFile(`${m86}/build/browser/movie86_wasm_bg.wasm`);
const mod = await import(`${m86}/build/browser/movie86_wasm.js`);
await mod.default({ module_or_path: wasm });
const { KEY } = await import(`${m86}/movie86.mjs`);

const FB = 0xa0000;
const W = 320;

// Slide background colours from gen_deck.py BACKGROUNDS, as RGBA u32
// (little-endian 0xAABBGGRR).
const rgba = (r, g, b) => ((255 << 24) | (b << 16) | (g << 8) | r) >>> 0;
const SLIDE_BG = [
    rgba(30, 30, 46),
    rgba(40, 54, 24),
    rgba(60, 30, 30),
    rgba(24, 40, 54),
];

const BUDGET = 600_000_000n;
const BATCH = 5_000_000n;

const elf = new Uint8Array(await readFile(`${here}/kvm2026-kansai/deck.elf`));
const vm = new mod.Vm(elf);

// Sample a background pixel (mid-screen, clear of border + markers).
function bg() {
    const b = vm.readMem(FB + (150 * W + 160) * 4, 4);
    if (b.length < 4) return null;
    return (b[0] | (b[1] << 8) | (b[2] << 16) | (b[3] << 24)) >>> 0;
}

function stepUntil(pred, label) {
    let spent = 0n;
    while (spent < BUDGET) {
        if (vm.haltReason) throw new Error(`guest halted (${vm.haltReason}) waiting for ${label}`);
        if (pred()) return true;
        vm.stepN(BATCH);
        spent += BATCH;
    }
    return pred();
}

let failed = 0;
try {
    assert.ok(stepUntil(() => vm.activeVideoMode === 0x13, 'video mode'), 'no video mode 13h');
    assert.ok(stepUntil(() => bg() === SLIDE_BG[0], 'slide 0'), 'slide 0 not shown initially');

    vm.pushInput(KEY.RIGHT);
    assert.ok(stepUntil(() => bg() === SLIDE_BG[1], 'slide 1'), 'Right did not advance to slide 1');

    vm.pushInput(KEY.RIGHT);
    assert.ok(stepUntil(() => bg() === SLIDE_BG[2], 'slide 2'), 'Right did not advance to slide 2');

    vm.pushInput(KEY.LEFT);
    assert.ok(stepUntil(() => bg() === SLIDE_BG[1], 'back to slide 1'), 'Left did not go back to slide 1');

    vm.pushInput(KEY.HOME);
    assert.ok(stepUntil(() => bg() === SLIDE_BG[0], 'Home → slide 0'), 'Home did not jump to slide 0');

    console.log(`ok  deck  flips through slides via Right/Left/Home  steps=${vm.steps}`);
} catch (e) {
    console.error(`FAIL deck: ${e.message}`);
    failed = 1;
} finally {
    vm.free();
}

process.exit(failed);
