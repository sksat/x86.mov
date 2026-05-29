import { useEffect, useRef, useState, useCallback } from 'react';
import { loadMovie86, type Movie86Vm, type Movie86Wrapper } from '@/lib/wrappers';

export interface VmTick {
    eip: number;
    regs: Uint32Array;
    steps: bigint;
    haltReason: string | null;
    exitCode: number | null;
    activeVideoMode: number | null;
}

export interface UseMovie86VmReturn {
    /** The currently-mounted Vm; null between loads. */
    vm: Movie86Vm | null;
    /** Last sampled live state. Updated by `tick()` and after each
     *  Step / Run batch. Don't poll the Vm directly — let React
     *  re-render via this signal so the panes stay consistent. */
    tick: VmTick | null;
    /** The wasm wrapper module (FRAMEBUFFER_MODES + helpers). */
    movie86: Movie86Wrapper | null;
    /** Replace the active program. Frees the previous Vm. */
    loadElf: (bytes: Uint8Array) => Promise<void>;
    step: () => void;
    /** Drive a Run loop until halt or `stop()`. Returns when halted. */
    run: (opts?: { batchSize?: bigint; refreshMs?: number }) => Promise<void>;
    stop: () => void;
    reset: () => Promise<void>;
    running: boolean;
    refresh: () => void;
    /** Pulls accumulated stdout/stderr bytes off the Vm. Called on
     *  every render tick. Buffers persist across drains. */
    drainOutput: () => { stdout: Uint8Array; stderr: Uint8Array };
}

/**
 * Wraps the movie86 Vm in React-friendly state. The Vm itself is
 * mutable Rust state behind a wasm boundary — the hook is responsible
 * for snapshotting it into `VmTick` so renders stay deterministic.
 *
 * Run-loop shape mirrors the existing movie86 demo: batch + periodic
 * refresh. The actual cadence (batchSize / refreshMs) is left to the
 * caller — different surfaces want different defaults.
 */
export function useMovie86Vm(): UseMovie86VmReturn {
    const [movie86, setMovie86] = useState<Movie86Wrapper | null>(null);
    const [vm, setVm] = useState<Movie86Vm | null>(null);
    const [tick, setTick] = useState<VmTick | null>(null);
    const [running, setRunning] = useState(false);

    const elfBytesRef = useRef<Uint8Array | null>(null);
    const runIdRef = useRef(0);

    useEffect(() => {
        let cancelled = false;
        loadMovie86().then((m) => {
            if (!cancelled) setMovie86(m);
        });
        return () => {
            cancelled = true;
        };
    }, []);

    // Always free the Vm on unmount.
    useEffect(() => {
        return () => {
            vm?.free();
        };
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, []);

    const sampleTick = useCallback((v: Movie86Vm): VmTick => ({
        eip: v.eip,
        regs: new Uint32Array(v.regs),
        steps: v.steps,
        haltReason: v.haltReason,
        exitCode: v.exitCode,
        activeVideoMode: v.activeVideoMode,
    }), []);

    const refresh = useCallback(() => {
        if (vm) setTick(sampleTick(vm));
    }, [vm, sampleTick]);

    const loadElf = useCallback(
        async (bytes: Uint8Array) => {
            if (!movie86) throw new Error('movie86 wasm not loaded yet');
            // Cancel any in-flight Run.
            runIdRef.current++;
            setRunning(false);
            if (vm) vm.free();
            elfBytesRef.current = bytes;
            const next = await movie86.loadVm(bytes);
            setVm(next);
            setTick(sampleTick(next));
        },
        [movie86, vm, sampleTick],
    );

    const step = useCallback(() => {
        if (!vm || vm.haltReason) return;
        vm.stepN(1n);
        setTick(sampleTick(vm));
    }, [vm, sampleTick]);

    const run = useCallback(
        async ({ batchSize = 50_000n, refreshMs = 100 } = {}) => {
            if (!vm || vm.haltReason) return;
            const myRun = ++runIdRef.current;
            setRunning(true);
            let lastRender = performance.now();
            try {
                while (myRun === runIdRef.current && !vm.haltReason) {
                    vm.stepN(batchSize);
                    const now = performance.now();
                    if (now - lastRender >= refreshMs) {
                        setTick(sampleTick(vm));
                        lastRender = now;
                    }
                    await new Promise((r) => setTimeout(r, 0));
                }
                setTick(sampleTick(vm));
            } finally {
                if (myRun === runIdRef.current) setRunning(false);
            }
        },
        [vm, sampleTick],
    );

    const stop = useCallback(() => {
        runIdRef.current++;
        setRunning(false);
    }, []);

    const reset = useCallback(async () => {
        if (!elfBytesRef.current) return;
        await loadElf(elfBytesRef.current);
    }, [loadElf]);

    const drainOutput = useCallback(() => {
        if (!vm) return { stdout: new Uint8Array(), stderr: new Uint8Array() };
        return { stdout: vm.drainStdout(), stderr: vm.drainStderr() };
    }, [vm]);

    return {
        vm,
        tick,
        movie86,
        loadElf,
        step,
        run,
        stop,
        reset,
        running,
        refresh,
        drainOutput,
    };
}
