// backend.mjs — framework-free decision logic for the explorer's
// execution-backend *selector* (movie86 vs turbo86).
//
// Kept pure (no React, no wasm, no WebSocket) and lives at the
// subproject root next to `explorer.mjs` so the rules can be pinned in
// Node (`tests/backend.test.mjs`) the same way the compiler dispatch is.
// The React layer (Movie86Panel + useMovie86Vm + the turbo86 session)
// reads these decisions and performs the side effects; it must NOT fork
// the rule table into a component — update this module instead.
//
// Product model (decided with the user):
//   - movie86 is the default backend (in-browser emulator).
//   - turbo86 is the native ptrace-driven backend reached over WebSocket.
//   - The user can switch backend while STOPPED or while RUNNING.
//   - "Run" runs on the *selected* backend: movie86 → local step loop,
//     turbo86 → forward handover (start native execution there).
//
// Switch outcomes are expressed as an `action` the caller dispatches:
//   'none'             no-op (re-selected the active backend)
//   'select'           just record the choice; transfer is deferred to Run
//   'forward-handover' snapshot the live Vm → LoadContext → turbo86
//   'reverse-handover' Pause turbo86 → Paused → loadContext back to movie86

export const BACKENDS = Object.freeze(['movie86', 'turbo86']);

// Fail fast on a mistyped id at the boundary — mirrors `explorer.mjs`'s
// "unknown compiler" guard so a typo surfaces as a loud throw rather
// than a silently-wrong backend.
function assertBackend(id) {
    if (!BACKENDS.includes(id)) {
        throw new Error(
            `unknown backend: ${JSON.stringify(id)} (expected one of ${BACKENDS.join(', ')})`,
        );
    }
}

/**
 * Decide what happens when the user picks `target` while `current` is
 * the active backend and `running` reflects whether execution is live.
 *
 * @param {{ current: string, target: string, running: boolean }} p
 * @returns {{ backend: string, action: 'none'|'select'|'forward-handover'|'reverse-handover' }}
 */
export function planBackendSelect({ current, target, running }) {
    assertBackend(current);
    assertBackend(target);

    // Re-selecting the active backend never moves state.
    if (target === current) return { backend: current, action: 'none' };

    // A stopped switch only records the choice — the actual transfer is
    // deferred until the next Run (which, on turbo86, forwards). A live
    // switch transfers the running state right away, in whichever
    // direction it's headed: movie86 → turbo86 forwards a snapshot,
    // turbo86 → movie86 pulls the paused state back.
    if (!running) return { backend: target, action: 'select' };
    return {
        backend: target,
        action: target === 'turbo86' ? 'forward-handover' : 'reverse-handover',
    };
}

/**
 * Decide what "Run" does on the currently-selected backend.
 *
 * @param {{ backend: string }} p
 * @returns {'local-run'|'forward-handover'}
 */
export function planRun({ backend }) {
    assertBackend(backend);
    return backend === 'movie86' ? 'local-run' : 'forward-handover';
}
