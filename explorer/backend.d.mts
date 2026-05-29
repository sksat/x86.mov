// Sidecar TS declarations for the framework-free backend-selector
// decision module. TS auto-picks `<basename>.d.mts` next to a .mjs
// import, so the React app (`src/lib/backend.ts`) sees real types here
// while the Node unit suite (`tests/backend.test.mjs`) uses the runtime
// module directly.

export type BackendId = 'movie86' | 'turbo86';

export const BACKENDS: readonly BackendId[];

export function planBackendSelect(p: {
    current: BackendId;
    target: BackendId;
    running: boolean;
}): {
    backend: BackendId;
    action: 'none' | 'select' | 'forward-handover' | 'reverse-handover';
};

export function planRun(p: { backend: BackendId }): 'local-run' | 'forward-handover';
