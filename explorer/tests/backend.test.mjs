// Node-level unit tests for `backend.mjs` — the framework-free decision
// logic behind the explorer's execution-backend *selector* (movie86 vs
// turbo86). Run via `node --test tests/backend.test.mjs` (or
// `make test-unit`).
//
// The selector replaces the old one-shot "hand off to turbo86" button
// with a real choice of execution backend. The product rules (decided
// with the user) are:
//
//   - The user can switch backend while STOPPED or while RUNNING.
//   - Switching to the SAME backend is a no-op.
//   - Switching movie86 → turbo86 while STOPPED just records the choice;
//     the actual transfer is deferred until the next Run.
//   - Switching movie86 → turbo86 while RUNNING transfers the live state
//     immediately (forward handover: snapshot → LoadContext).
//   - Switching turbo86 → movie86 while RUNNING pulls the live state
//     back (reverse handover: Pause → Paused → loadContext).
//   - Switching turbo86 → movie86 while STOPPED just records the choice.
//   - "Run" means "run on the selected backend": movie86 → local step
//     loop; turbo86 → forward handover (start native execution there).
//
// This module is pure (no React, no wasm, no WebSocket) so the rules can
// be pinned in Node the same way `explorer.mjs`'s compiler dispatch is.

import { test } from 'node:test';
import assert from 'node:assert/strict';

test('backend.mjs exports BACKENDS list', async () => {
    const mod = await import('../backend.mjs');
    assert.ok(Array.isArray(mod.BACKENDS), 'BACKENDS must be an array');
    assert.deepEqual(
        [...mod.BACKENDS].sort(),
        ['movie86', 'turbo86'],
        'two execution backends exposed today',
    );
});

test('backend.mjs exports planBackendSelect + planRun', async () => {
    const mod = await import('../backend.mjs');
    assert.equal(typeof mod.planBackendSelect, 'function');
    assert.equal(typeof mod.planRun, 'function');
});

test('planBackendSelect rejects unknown backend ids loudly', async () => {
    const { planBackendSelect } = await import('../backend.mjs');
    assert.throws(
        () => planBackendSelect({ current: 'movie86', target: 'qemu', running: false }),
        /unknown backend.*qemu/i,
        'mistyped backend ids should fail fast at the boundary',
    );
    assert.throws(
        () => planBackendSelect({ current: 'vbox', target: 'movie86', running: false }),
        /unknown backend.*vbox/i,
    );
});

test('planBackendSelect — selecting the current backend is a no-op', async () => {
    const { planBackendSelect } = await import('../backend.mjs');
    for (const backend of ['movie86', 'turbo86']) {
        for (const running of [false, true]) {
            assert.deepEqual(
                planBackendSelect({ current: backend, target: backend, running }),
                { backend, action: 'none' },
                `re-selecting ${backend} (running=${running}) does nothing`,
            );
        }
    }
});

test('planBackendSelect — movie86 → turbo86 while STOPPED just records the choice', async () => {
    const { planBackendSelect } = await import('../backend.mjs');
    assert.deepEqual(
        planBackendSelect({ current: 'movie86', target: 'turbo86', running: false }),
        { backend: 'turbo86', action: 'select' },
        'stopped switch is deferred — Run will perform the forward handover',
    );
});

test('planBackendSelect — movie86 → turbo86 while RUNNING forwards immediately', async () => {
    const { planBackendSelect } = await import('../backend.mjs');
    assert.deepEqual(
        planBackendSelect({ current: 'movie86', target: 'turbo86', running: true }),
        { backend: 'turbo86', action: 'forward-handover' },
        'switching to turbo86 mid-run hands the live state over',
    );
});

test('planBackendSelect — turbo86 → movie86 while STOPPED just records the choice', async () => {
    const { planBackendSelect } = await import('../backend.mjs');
    assert.deepEqual(
        planBackendSelect({ current: 'turbo86', target: 'movie86', running: false }),
        { backend: 'movie86', action: 'select' },
    );
});

test('planBackendSelect — turbo86 → movie86 while RUNNING pulls the state back', async () => {
    const { planBackendSelect } = await import('../backend.mjs');
    assert.deepEqual(
        planBackendSelect({ current: 'turbo86', target: 'movie86', running: true }),
        { backend: 'movie86', action: 'reverse-handover' },
        'switching back to movie86 mid-run reverse-hands the live state back',
    );
});

test('planRun — movie86 runs locally, turbo86 forwards', async () => {
    const { planRun } = await import('../backend.mjs');
    assert.equal(
        planRun({ backend: 'movie86' }),
        'local-run',
        'Run on movie86 drives the local step loop',
    );
    assert.equal(
        planRun({ backend: 'turbo86' }),
        'forward-handover',
        'Run on turbo86 means "start native execution there" = forward handover',
    );
});

test('planRun rejects unknown backend ids loudly', async () => {
    const { planRun } = await import('../backend.mjs');
    assert.throws(
        () => planRun({ backend: 'qemu' }),
        /unknown backend.*qemu/i,
    );
});
