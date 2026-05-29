import { useCallback, useState } from 'react';
import { planBackendSelect, planRun, type BackendId } from '@/lib/backend';
import type { UseMovie86VmReturn } from './useMovie86Vm';
import type { UseTurbo86SessionReturn } from './useTurbo86Session';

export interface UseExecBackendReturn {
    /** Currently-selected execution backend. */
    backend: BackendId;
    /** Unified run state across both backends. */
    running: boolean;
    /** Pick a backend. Defers, forwards, or reverses per the rule table
     *  in `backend.mjs` (`planBackendSelect`). */
    selectBackend: (target: BackendId) => void;
    /** Run on the selected backend: movie86 → local loop, turbo86 →
     *  forward handover (`planRun`). */
    run: () => void;
    /** Stop the selected backend's execution. */
    stop: () => void;
}

/**
 * Coordinator that turns the framework-free decisions in `backend.mjs`
 * into side effects on the two concrete backends — the in-browser
 * `useMovie86Vm` loop and the `useTurbo86Session` WebSocket. Keeping the
 * rule table in the .mjs (and only the dispatch here) is the same
 * "decide in Node, act in React" split `compiler.ts` uses for the
 * compile pipeline.
 */
export function useExecBackend(
    movie86Vm: UseMovie86VmReturn,
    turbo86: UseTurbo86SessionReturn,
): UseExecBackendReturn {
    const [backend, setBackend] = useState<BackendId>('movie86');
    const running = movie86Vm.running || turbo86.running;

    const selectBackend = useCallback(
        (target: BackendId) => {
            const { vm, movie86 } = movie86Vm;
            const plan = planBackendSelect({ current: backend, target, running });
            setBackend(plan.backend);
            switch (plan.action) {
                case 'forward-handover':
                    movie86Vm.stop();
                    if (vm && movie86) void turbo86.forward(vm, movie86);
                    break;
                case 'reverse-handover':
                    if (vm && movie86) {
                        void turbo86
                            .reverse(vm, movie86)
                            .then(() => movie86Vm.refresh());
                    }
                    break;
                // 'none' / 'select' just record the choice (already set above).
                default:
                    break;
            }
        },
        [backend, running, movie86Vm, turbo86],
    );

    const run = useCallback(() => {
        const { vm, movie86 } = movie86Vm;
        if (planRun({ backend }) === 'local-run') {
            void movie86Vm.run();
        } else if (vm && movie86) {
            void turbo86.forward(vm, movie86);
        }
    }, [backend, movie86Vm, turbo86]);

    const stop = useCallback(() => {
        if (backend === 'movie86') movie86Vm.stop();
        else turbo86.stop();
    }, [backend, movie86Vm, turbo86]);

    return { backend, running, selectBackend, run, stop };
}
