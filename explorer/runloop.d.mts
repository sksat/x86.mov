// Sidecar TS declarations for the framework-free run loop (runloop.mjs).
// TS auto-picks `<basename>.d.mts` next to a .mjs import, so the React
// hook (`src/hooks/useMovie86Vm.ts`) sees real types here while the Node
// unit suite (`tests/runloop.test.mjs`) uses the runtime module directly.
// Mirrors the explorer.mjs / explorer.d.mts pairing.

/** Controls re-read on every loop iteration so the UI can change them
 *  mid-run (this is what makes the Follow toggle live). */
export interface RunLoopControls {
    /** Follow: one step + render per frame. Off: batched periodic dump. */
    follow: boolean;
    /** Sleep between steps in follow mode (ms). */
    delayMs: number;
    /** Instructions per batch in periodic-dump mode. */
    batchSize: bigint;
    /** Min ms between renders in periodic-dump mode. */
    refreshMs: number;
}

/** Side effects + inputs injected by the caller (the React hook). */
export interface RunLoopIo {
    /** Keep looping? false on Stop or halt. */
    shouldContinue(): boolean;
    /** Read the live controls for this iteration. */
    readControls(): RunLoopControls;
    /** Advance the Vm by one instruction. */
    stepOne(): void;
    /** Advance the Vm by `batchSize` instructions. */
    stepBatch(batchSize: bigint): void;
    /** Snapshot Vm state into React. */
    render(): void;
    /** Yield to the event loop so Stop stays responsive. */
    sleep(ms: number): Promise<void>;
    /** Monotonic clock (performance.now). */
    now(): number;
}

/** Drive the Vm step loop until `shouldContinue()` is false. */
export function runLoop(io: RunLoopIo): Promise<void>;
