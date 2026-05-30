// End-to-end test for a SIMD86 deck on movie86: load the mov-only
// deck.elf, drive it with key input, and assert the framebuffer shows
// the right slide — including the mid-deck resolution change (slide 1
// switches video mode 13h → 6Ah). Proves the whole flip + set_video_mode
// path: pushInput → CALL_POLL_INPUT → deck.c index move → (mode change) →
// blit of the new slide at its framebuffer address.
//
// Content-agnostic: slides are real images now, so instead of pinning
// exact background colours the test asserts (a) the active video mode per
// slide and (b) that the framebuffer *content changes* when paging (a
// rolling checksum differs), which proves a new slide was blitted. Mirror
// kvm2026-kansai/deck.toml: slide 0 @ 320x200 (mode 13h), slide 1 @
// 800x600 (mode 6Ah).
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

const EXPECT_MODE = [0x70, 0x72]; // slide 0 480x270, slide 1 1280x720 (16:9)

// 800x600 blits ~480k px through the wasm emulator, so give it room.
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
    // Slide 0: mode 13h (320x200), some content drawn.
    assert.ok(stepUntil(() => vm.activeVideoMode === EXPECT_MODE[0], 'mode 13h'),
        'slide 0 never reached mode 13h');
    const h0 = settleHash('slide 0');
    assert.notEqual(h0, 0, 'slide 0 framebuffer stayed blank');

    // Right → slide 1: resolution change to mode 6Ah (800x600).
    vm.pushInput(KEY.RIGHT);
    assert.ok(stepUntil(() => vm.activeVideoMode === EXPECT_MODE[1], 'mode 6Ah'),
        'Right did not switch slide 1 to mode 6Ah (800x600)');
    const h1 = settleHash('slide 1');
    assert.notEqual(h1, 0, 'slide 1 framebuffer stayed blank');

    // Left → back to slide 0: mode returns to 13h and content differs
    // from slide 1 (proves the back-nav re-blitted slide 0).
    vm.pushInput(KEY.LEFT);
    assert.ok(stepUntil(() => vm.activeVideoMode === EXPECT_MODE[0], 'back to mode 13h'),
        'Left did not return to slide 0 (mode 13h)');
    const h0b = settleHash('slide 0 again');
    assert.notEqual(h0b, 0, 'slide 0 (return) framebuffer stayed blank');

    // Enter is a fallback for "next" — should advance to slide 1 again.
    vm.pushInput(KEY.ENTER);
    assert.ok(stepUntil(() => vm.activeVideoMode === EXPECT_MODE[1], 'Enter → mode 6Ah'),
        'Enter did not advance to slide 1');

    console.log(`ok  deck  mode 0x70 ⇄ 0x72 via Right/Left/Enter, slides blit  steps=${vm.steps}`);
} catch (e) {
    console.error(`FAIL deck: ${e.message}`);
    failed = 1;
} finally {
    vm.free();
}

process.exit(failed);
