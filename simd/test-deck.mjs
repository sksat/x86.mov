// End-to-end test for a SIMD86 deck on movie86: load the mov-only
// deck.elf, drive it with key input, and assert the framebuffer shows
// the right slide. Proves the whole flip path: pushInput →
// CALL_POLL_INPUT → deck.c index move → blit of the new slide at its
// framebuffer address.
//
// The shipped deck is uniform 320x180 (mode 0x74, 16:9) — the
// resolution compromise that keeps the whole slide blob inside
// turbo86's 16 MiB boost region (see test-deck-size.py). So there's no
// mid-deck mode change to assert; instead, content-agnostic: the test
// asserts (a) the deck reaches the expected video mode and (b) the
// framebuffer *content changes* when paging (a rolling checksum
// differs), which proves a new slide was blitted.
//
// Run against the movie86 wasm build (../movie86/wasm/build/browser);
// `make -C movie86/wasm build-wasm` first. Standalone: node test-deck.mjs

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

const MODE = 0x74; // every slide is 320x180 (mode 0x74, 16:9) — uniform deck

// Each 320x180 slide blits ~58k px through the wasm emulator; the step
// budget is generous so a slow CI box still finishes a transition.
const BUDGET = 800_000_000n;
const BATCH = 8_000_000n;

const elf = new Uint8Array(await readFile(`${here}/kvm2026-kansai/deck.elf`));
const vm = new mod.Vm(elf);

// Cheap rolling checksum over a sample of the active framebuffer — used to
// tell "a different slide is now on screen" without pinning exact pixels.
function fbHash() {
    const m = modeForNumber(vm.activeVideoMode);
    if (!m) return 0;
    const fb = vm.readMem(m.addr, m.byteLength);
    if (fb.length < m.byteLength) return 0;
    let h = 2166136261 >>> 0;
    // Sample every ~997th byte (prime stride) to keep it fast but sensitive.
    for (let i = 0; i < fb.length; i += 997) {
        h = (h ^ fb[i]) >>> 0;
        h = Math.imul(h, 16777619) >>> 0;
    }
    return h;
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

// Settle: step until the framebuffer hash stops changing (blit finished),
// returning the stable hash. Avoids reading a half-painted frame.
function settleHash(label) {
    let last = fbHash(), stable = 0;
    let spent = 0n;
    while (spent < BUDGET && stable < 3) {
        vm.stepN(BATCH);
        spent += BATCH;
        const h = fbHash();
        if (h === last) stable++;
        else { stable = 0; last = h; }
        if (vm.haltReason) throw new Error(`guest halted (${vm.haltReason}) settling ${label}`);
    }
    return last;
}

let failed = 0;
try {
    // Slide 0: reaches mode 0x74 (320x180), some content drawn.
    assert.ok(stepUntil(() => vm.activeVideoMode === MODE, 'mode 0x74'),
        'slide 0 never reached mode 0x74');
    const h0 = settleHash('slide 0');
    assert.notEqual(h0, 0, 'slide 0 framebuffer stayed blank');

    // Right → slide 1: same mode (uniform deck), but a different slide is
    // blitted, so the framebuffer content (rolling hash) must change.
    vm.pushInput(KEY.RIGHT);
    assert.ok(stepUntil(() => fbHash() !== h0, 'slide 1 content'),
        'Right did not blit a new slide (framebuffer unchanged)');
    const h1 = settleHash('slide 1');
    assert.notEqual(h1, h0, 'slide 1 content matches slide 0');
    assert.equal(vm.activeVideoMode, MODE, 'slide 1 left mode 0x74');

    // Left → back to slide 0: content returns to slide 0 (differs from
    // slide 1), proving the back-nav re-blitted.
    vm.pushInput(KEY.LEFT);
    assert.ok(stepUntil(() => fbHash() !== h1, 'back to slide 0 content'),
        'Left did not re-blit slide 0');
    const h0b = settleHash('slide 0 again');
    assert.notEqual(h0b, h1, 'back-nav content still matches slide 1');
    assert.equal(h0b, h0, 're-blitted slide 0 differs from the first time');

    // Enter is a fallback for "next" — should advance off slide 0 again.
    vm.pushInput(KEY.ENTER);
    assert.ok(stepUntil(() => fbHash() !== h0b, 'Enter advances'),
        'Enter did not advance to the next slide');

    console.log(`ok  deck  mode 0x74 uniform, Right/Left/Enter blit new slides  steps=${vm.steps}`);
} catch (e) {
    console.error(`FAIL deck: ${e.message}`);
    failed = 1;
} finally {
    vm.free();
}

process.exit(failed);
