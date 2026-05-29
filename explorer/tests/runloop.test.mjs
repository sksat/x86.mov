// Node-level unit tests for the explorer's interactive Run loop
// (`../runloop.mjs`). Run via `node --test` (wired into `make test-unit`).
//
// The explorer embeds the movie86 Vm and — like the movie86 demo — wants
// two display strategies behind a "Follow" toggle: one-step-per-frame
// (watch each mov land) vs refreshMs-throttled batch (keep up on a hot
// guest). The headline requirement, and the bug movie86 just fixed, is
// that the loop must read the controls FRESH every iteration so the
// Follow toggle (and step delay) can be flipped *mid-run*. These tests
// pin that without React or wasm by injecting every side effect.
//
// This is the explorer's own copy of the loop (it deliberately keeps the
// sibling subprojects at arm's length — runtime URL, no bundling — so it
// doesn't import movie86/wasm/runloop.mjs). The shape is intentionally
// the same; this suite is what keeps the two honest independently.

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { runLoop } from '../runloop.mjs';

// Live Follow toggle: start in follow mode, flip it off after the second
// step. The loop must switch to batch stepping immediately — only
// possible if it re-reads readControls() each iteration.
test('reads Follow fresh each iteration (live toggle)', async () => {
    let i = 0;
    let follow = true;
    const seq = [];
    await runLoop({
        shouldContinue: () => i < 4,
        readControls: () => ({ follow, delayMs: 0, batchSize: 100n, refreshMs: 0 }),
        stepOne: () => { seq.push('one'); i++; if (i === 2) follow = false; },
        stepBatch: () => { seq.push('batch'); i++; },
        render: () => {},
        sleep: async () => {},
        now: () => 0,
    });
    assert.deepEqual(seq, ['one', 'one', 'batch', 'batch']);
});

test('follow mode steps once and renders every iteration', async () => {
    let i = 0, ones = 0, renders = 0;
    await runLoop({
        shouldContinue: () => i < 3,
        readControls: () => ({ follow: true, delayMs: 0, batchSize: 1n, refreshMs: 0 }),
        stepOne: () => { ones++; i++; },
        stepBatch: () => { throw new Error('stepBatch must not run in follow mode'); },
        render: () => { renders++; },
        sleep: async () => {},
        now: () => 0,
    });
    assert.equal(ones, 3);
    assert.equal(renders, 3 + 1, 'per-iteration renders plus one final render');
});

// Scripted clock so the refreshMs throttle is deterministic:
//   call 1 (pre-loop lastRender) -> 0
//   iter 1 -> 50  (<100: no render)   iter 2 -> 150 (>=100: render)
//   iter 3 -> 200 (<100: no render)   iter 4 -> 320 (>=100: render)
// Two in-loop renders + one unconditional final render = 3.
test('batch mode throttles render by refreshMs and renders once at the end', async () => {
    let i = 0, renders = 0;
    const sizes = [];
    const clock = [0, 50, 150, 200, 320];
    let tick = 0;
    await runLoop({
        shouldContinue: () => i < 4,
        readControls: () => ({ follow: false, delayMs: 0, batchSize: 10n, refreshMs: 100 }),
        stepOne: () => { throw new Error('stepOne must not run in batch mode'); },
        stepBatch: (n) => { sizes.push(n); i++; },
        render: () => { renders++; },
        sleep: async () => {},
        now: () => clock[tick++],
    });
    assert.equal(renders, 3, 'two throttled renders + one final render');
    assert.deepEqual(sizes, [10n, 10n, 10n, 10n], 'batchSize forwarded to stepBatch');
});

test('does not step when shouldContinue is false from the start', async () => {
    let steps = 0, renders = 0;
    await runLoop({
        shouldContinue: () => false,
        readControls: () => ({ follow: true, delayMs: 0, batchSize: 1n, refreshMs: 0 }),
        stepOne: () => { steps++; },
        stepBatch: () => { steps++; },
        render: () => { renders++; },
        sleep: async () => {},
        now: () => 0,
    });
    assert.equal(steps, 0, 'no stepping when the loop should not run');
    assert.equal(renders, 1, 'still flushes one final render');
});
