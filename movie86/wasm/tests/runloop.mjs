// Unit tests for the interactive Run loop (`runloop.mjs`).
//
// The loop is extracted from index.html's `doRun` precisely so this
// logic is testable without a DOM or the wasm Vm: every side effect
// (stepping, rendering, sleeping, reading the clock) and every control
// input (the Follow toggle + delay / batch / refresh) is injected.
//
// The headline behaviour these tests pin — and the bug that motivated
// the extraction — is that `runLoop` must read the controls FRESH on
// every iteration. The pre-extraction code snapshotted `follow` once at
// the top of the run, so flipping the checkbox mid-run did nothing. A
// passing "live toggle" test below is only possible if the loop polls
// readControls() each pass.
//
// Run standalone: `node tests/runloop.mjs` (no build / wasm needed).

import assert from 'node:assert/strict';
import { runLoop } from '../runloop.mjs';

let failed = 0;
async function test(name, fn) {
    try {
        await fn();
        console.log(`ok  ${name}`);
    } catch (e) {
        console.error(`FAIL ${name}: ${e.stack || e.message}`);
        failed++;
    }
}

// --- live Follow toggle: the regression this whole change is about ---
//
// Start in follow mode (one-step-per-frame), then flip follow off after
// the second step. The loop must switch to batch stepping immediately,
// which is only observable if it re-reads the control each iteration.
await test('reads Follow fresh each iteration (live toggle)', async () => {
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

// --- follow on: one step + one render per iteration, plus a final render ---
await test('follow mode steps once and renders every iteration', async () => {
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

// --- follow off: batch stepping with refreshMs-throttled rendering ---
//
// `now()` is fed a scripted clock so the throttle is deterministic:
//   call 1 (pre-loop lastRender) -> 0
//   iter 1 -> 50   (50-0   <100  : no render)
//   iter 2 -> 150  (150-0  >=100 : render, lastRender=150)
//   iter 3 -> 200  (200-150<100  : no render)
//   iter 4 -> 320  (320-150>=100 : render, lastRender=320)
// Two in-loop renders + one unconditional final render = 3.
await test('batch mode throttles render by refreshMs and renders once at the end', async () => {
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

// --- shouldContinue gates the loop (Stop / halt) ---
await test('does not step when shouldContinue is false from the start', async () => {
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

if (failed > 0) {
    console.error(`${failed} runloop test(s) failed`);
    process.exit(1);
}
console.log('all runloop tests passed');
