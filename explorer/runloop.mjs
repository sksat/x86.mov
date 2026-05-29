// Interactive Run loop for the explorer's embedded movie86 Vm.
//
// Like the movie86 demo, the explorer offers two display strategies
// behind a "Follow" toggle:
//   - Follow:        stepN(1) + render() per frame — watch each mov land.
//   - Periodic dump: stepN(batchSize) per frame, render() only every
//                    refreshMs — keep the wasm boundary cheap on a hot
//                    guest. (default)
// The two strategies live in ONE loop and the controls (follow / delay /
// batch / refresh) are re-read via readControls() on EVERY iteration, so
// flipping Follow — or retuning the cadence — takes effect on the next
// step, even while a run is in flight. Reading the toggle once up front
// (the shape movie86 originally shipped) is exactly what made it
// impossible to switch mid-run.
//
// This is the explorer's OWN copy of the loop. The subproject keeps its
// siblings at arm's length (loaded at runtime via /<subproject>/ URLs,
// never bundled), so rather than statically import movie86/wasm's
// runloop.mjs we own a small, framework-free copy here — same shape,
// pinned independently by tests/runloop.test.mjs. It's pure logic: the
// React hook (useMovie86Vm) injects stepping/rendering/timing, and
// `runloop.d.mts` gives TS consumers the types.
//
// io contract:
//   shouldContinue() -> bool   keep looping? (false on Stop / halt)
//   readControls()    -> { follow, delayMs, batchSize, refreshMs }
//                              read FRESH each iteration
//   stepOne()                  advance the Vm by one instruction
//   stepBatch(batchSize)       advance the Vm by `batchSize` instructions
//   render()                   snapshot Vm state into React (setTick)
//   sleep(ms)  -> Promise      yield so Stop stays responsive
//   now()      -> ms           monotonic clock (performance.now)
export async function runLoop(io) {
    const { shouldContinue, readControls, stepOne, stepBatch, render, sleep, now } = io;
    let lastRender = now();
    while (shouldContinue()) {
        const { follow, delayMs, batchSize, refreshMs } = readControls();
        if (follow) {
            stepOne();
            render();
            lastRender = now();
            await sleep(delayMs);
        } else {
            stepBatch(batchSize);
            const t = now();
            if (t - lastRender >= refreshMs) {
                render();
                lastRender = t;
            }
            await sleep(0);
        }
    }
    render();
}
