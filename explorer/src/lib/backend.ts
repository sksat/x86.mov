// TS facade in front of `../../backend.mjs` — the framework-free
// decision logic for the execution-backend selector, covered by
// `tests/backend.test.mjs`. Keep this thin: the no-React unit suite and
// the React app both work against the .mjs, so the app reuses it without
// forking the rule table.

import {
    BACKENDS as _BACKENDS,
    planBackendSelect as _planBackendSelect,
    planRun as _planRun,
} from '../../backend.mjs';

export type BackendId = 'movie86' | 'turbo86';

export const BACKENDS = _BACKENDS as readonly BackendId[];

export type SelectAction =
    | 'none'
    | 'select'
    | 'forward-handover'
    | 'reverse-handover';

export type RunAction = 'local-run' | 'forward-handover';

export function planBackendSelect(p: {
    current: BackendId;
    target: BackendId;
    running: boolean;
}): { backend: BackendId; action: SelectAction } {
    return _planBackendSelect(p) as { backend: BackendId; action: SelectAction };
}

export function planRun(p: { backend: BackendId }): RunAction {
    return _planRun(p) as RunAction;
}
