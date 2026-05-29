// The interactive Run loop for the in-browser Vm, extracted from
// index.html's `doRun` so the follow-vs-batch cadence is unit-testable
// (see tests/runloop.mjs) without a DOM or the wasm Vm.
//
// Why a single loop instead of two: the demo offers two display
// strategies (see movie86/wasm/CLAUDE.md "Display strategy: follow vs
// periodic"), and the user must be able to switch between them *while a
// run is in flight*. The earlier shape picked the strategy once — it
// read `follow` into a const and branched into one of two `while`
// loops — so toggling the Follow checkbox mid-run had no effect until
// the next Run. Here the two strategies live in one loop and the
// controls are re-read every iteration via `readControls()`, so flipping
// Follow (or retuning delay / batch / refresh) takes effect on the next
// step. The two strategies themselves are unchanged and deliberately
// kept distinct — they answer different questions ("show me each step"
// vs "keep me roughly informed while it runs hot").
//
// All side effects and inputs are injected (`io`):
//   shouldContinue() -> bool   keep looping? (false on Stop / halt)
//   readControls()    -> { follow, delayMs, batchSize, refreshMs }
//                              read FRESH each iteration — this is the
//                              whole point of the extraction
//   stepOne()                  advance the Vm by one instruction
//   stepBatch(batchSize)       advance the Vm by `batchSize` instructions
//   render()                   repaint the UI from current Vm state
//   sleep(ms)  -> Promise      yield to the browser so Stop stays live
//   now()      -> ms           monotonic clock (performance.now)
export async function runLoop(io) {
    const { shouldContinue, readControls, stepOne, stepBatch, render, sleep, now } = io;
    let lastRender = now();
    while (shouldContinue()) {
        const { follow, delayMs, batchSize, refreshMs } = readControls();
        if (follow) {
            // Follow: one instruction per frame, render every step, sleep
            // `delayMs` so the user can watch the highlight move.
            stepOne();
            render();
            lastRender = now();
            await sleep(delayMs);
        } else {
            // Periodic dump: batch steps cheaply, render only once every
            // `refreshMs` so the wasm boundary overhead stays low on a
            // hot guest. Yield with sleep(0) to keep Stop responsive.
            stepBatch(batchSize);
            const t = now();
            if (t - lastRender >= refreshMs) {
                render();
                lastRender = t;
            }
            await sleep(0);
        }
    }
    // Flush the final state once the loop ends (halt / Stop / mode tail)
    // so the last batch's effects are always on screen.
    render();
}
