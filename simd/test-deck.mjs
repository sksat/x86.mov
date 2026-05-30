// End-to-end test for a SIMD86 deck on movie86: load the mov-only
// deck.elf, drive it with key input, and assert the framebuffer shows
// the expected slide — including the mid-deck resolution change (slide 1
// switches video mode 13h → 6Ah). Proves the whole flip + set_video_mode
// path: pushInput → CALL_POLL_INPUT → deck.c index move → (mode change) →
// blit of the new slide at its framebuffer address.
//
// Run against the movie86 wasm build (../movie86/wasm/build/browser);
// run `make -C movie86/wasm build-wasm` first. Standalone:
//
//   node test-deck.mjs
//
// Slide colours/resolutions mirror kvm2026-kansai/deck.toml.

import { readFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const m86 = `${here}/../movie86/wasm`;

const wasm = await readFile(`${m86}/build/browser/movie86_wasm_bg.wasm`);
const mod = await import(`${m86}/build/browser/movie86_wasm.js`);
await mod.default({ module_or_path: wasm });
const { KEY, modeForNumber } = await import(`${m86}/movie86.mjs`);

// RGBA u32 (little-endian 0xAABBGGRR) for a `color:RRGGBB` slide.
const rgba = (r, g, b) => ((255 << 24) | (b << 16) | (g << 8) | r) >>> 0;
// Mirrors deck.toml: [320x200 #303048, 800x600 #482a18, 800x600 #5a1e2e].
const SLIDES = [
    { mode: 0x13, color: rgba(0x30, 0x30, 0x48) },
    { mode: 0x6a, color: rgba(0x48, 0x2a, 0x18) },
    { mode: 0x6a, color: rgba(0x5a, 0x1e, 0x2e) },
];

// 800x600 blits ~480k px through the wasm emulator, so give it room.
const BUDGET = 800_000_000n;
const BATCH = 8_000_000n;

const elf = new Uint8Array(await readFile(`${here}/kvm2026-kansai/deck.elf`));
const vm = new mod.Vm(elf);

// Sample a mid-screen background pixel for the deck's current mode.
function bg() {
    const m = modeForNumber(vm.activeVideoMode);
    if (!m) return null;
    const px = (m.height >> 1) * m.width + (m.width >> 1);
    const b = vm.readMem(m.addr + px * 4, 4);
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
    // Slide 0: low-res 320x200, mode 13h.
    assert.ok(stepUntil(() => vm.activeVideoMode === SLIDES[0].mode && bg() === SLIDES[0].color,
        'slide 0 (320x200)'), 'slide 0 not shown at mode 13h');

    // Right → slide 1: resolution change to 800x600 (mode 6Ah).
    vm.pushInput(KEY.RIGHT);
    assert.ok(stepUntil(() => vm.activeVideoMode === SLIDES[1].mode && bg() === SLIDES[1].color,
        'slide 1 (800x600, mode change)'), 'Right did not switch to slide 1 @ 800x600');

    // Right → slide 2: same mode, new colour.
    vm.pushInput(KEY.RIGHT);
    assert.ok(stepUntil(() => bg() === SLIDES[2].color, 'slide 2'),
        'Right did not advance to slide 2');

    // Left → back to slide 1.
    vm.pushInput(KEY.LEFT);
    assert.ok(stepUntil(() => bg() === SLIDES[1].color, 'back to slide 1'),
        'Left did not go back to slide 1');

    console.log(`ok  deck  320x200 -> (mode change) 800x600 flips via Right/Left  steps=${vm.steps}`);
} catch (e) {
    console.error(`FAIL deck: ${e.message}`);
    failed = 1;
} finally {
    vm.free();
}

process.exit(failed);
