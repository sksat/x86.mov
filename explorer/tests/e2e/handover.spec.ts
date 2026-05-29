// turbo86 handover E2E.
//
// Drives the deployed (or locally previewed) explorer:
//
//   1. picks an example fixture so movie86 has a real static ELF to
//      snapshot;
//   2. spawns a real turbo86 binary on `ws://127.0.0.1:<port>`;
//   3. clicks "Send to local turbo86";
//   4. asserts the wire round-trip reaches the turbo86 side and that
//      the explorer's session status reflects an Outbound event
//      (Stdout / Exit / Fault — any reply confirms the handshake
//      survived the LoadContext schema and the explorer parses it).
//
// Gates on `TURBO86_BIN=/path/to/turbo86`. When unset the spec skips
// cleanly so non-Linux CI runners (or runs without a built turbo86)
// don't fail. movie86/wasm/tests/turbo86_handover.mjs follows the same
// gating convention.

import { expect, test } from '@playwright/test';
import { spawn, type ChildProcessWithoutNullStreams } from 'node:child_process';
import { createServer } from 'node:net';

const TURBO86_BIN = process.env.TURBO86_BIN;

test.skip(!TURBO86_BIN, 'set TURBO86_BIN to run turbo86 handover E2E');

async function pickFreePort(): Promise<number> {
    return await new Promise((resolve, reject) => {
        const srv = createServer();
        srv.listen(0, '127.0.0.1', () => {
            const addr = srv.address();
            if (addr && typeof addr === 'object') {
                const port = addr.port;
                srv.close(() => resolve(port));
            } else {
                srv.close(() => reject(new Error('no port')));
            }
        });
        srv.on('error', reject);
    });
}

interface T86 {
    proc: ChildProcessWithoutNullStreams;
    url: string;
}

async function spawnTurbo86(): Promise<T86> {
    const port = await pickFreePort();
    const addr = `127.0.0.1:${port}`;
    const proc = spawn(
        TURBO86_BIN!,
        [
            '-addr',
            addr,
            // Allow Playwright's about:blank navigations + the live
            // preview URL to actually upgrade WS — turbo86's default
            // Origin allow-list covers x86.mov + pages.dev, but the
            // Playwright host the test runs from sends Origin =
            // `http://localhost:4173` for `vite preview` and an
            // explicit baseURL Origin for staging. `*` reads anything.
            '-allow-origin',
            '*',
        ],
        { stdio: ['ignore', 'pipe', 'pipe'] },
    );
    // Wait for the listener log line.
    await new Promise<void>((resolve, reject) => {
        const onData = (buf: Buffer) => {
            const s = buf.toString();
            if (s.includes('listening') || s.includes('ws://') || s.includes(addr)) {
                cleanup();
                resolve();
            }
        };
        const onErr = (e: Error) => {
            cleanup();
            reject(e);
        };
        const onExit = (code: number | null) => {
            cleanup();
            reject(new Error(`turbo86 exited prematurely (${code})`));
        };
        const cleanup = () => {
            proc.stdout?.off('data', onData);
            proc.stderr?.off('data', onData);
            proc.off('error', onErr);
            proc.off('exit', onExit);
        };
        proc.stdout?.on('data', onData);
        proc.stderr?.on('data', onData);
        proc.on('error', onErr);
        proc.on('exit', onExit);
        setTimeout(() => {
            cleanup();
            reject(new Error('turbo86 boot timed out'));
        }, 5_000);
    });
    return { proc, url: `ws://${addr}` };
}

test('explorer hands a static example off to a real turbo86 over WS', async ({ page }) => {
    test.setTimeout(120_000);

    const t86 = await spawnTurbo86();
    try {
        const consoleErrors: string[] = [];
        page.on('console', (msg) => {
            const t = msg.type();
            if (t === 'error' || t === 'warning') consoleErrors.push(`${t}: ${msg.text()}`);
        });
        page.on('pageerror', (e) => consoleErrors.push(`pageerror: ${e.message}`));
        page.on('requestfailed', (r) =>
            consoleErrors.push(`requestfailed: ${r.url()} (${r.failure()?.errorText})`),
        );
        page.on('response', (r) => {
            if (r.status() >= 400) {
                consoleErrors.push(`http ${r.status()}: ${r.url()}`);
            }
        });

        await page.goto('');

        // Production UX has no "pick a fixture" preset — the panel is
        // for the compiled binary or an upload. Until issue #36 fixes
        // the compile→run path's static-link gap, drive the upload
        // input directly with a known-good static ELF (return42.elf
        // ships under /movie86/examples/ via the movie86/wasm
        // stage-deploy).
        const elfBytes = await page.evaluate(async () => {
            const r = await fetch('/movie86/examples/return42.elf');
            if (!r.ok) throw new Error(`return42.elf fetch: ${r.status}`);
            const buf = await r.arrayBuffer();
            return Array.from(new Uint8Array(buf));
        });
        await page.getByTestId('elf-upload-input').setInputFiles({
            name: 'return42.elf',
            mimeType: 'application/octet-stream',
            buffer: Buffer.from(elfBytes),
        });

        try {
            await expect(page.getByTestId('vm-run')).toBeEnabled({ timeout: 10_000 });
        } catch (e) {
            console.log('captured errors:', JSON.stringify(consoleErrors, null, 2));
            throw e;
        }

        // Override the turbo86 URL field with our test instance, mode=trap
        // so the kernel signal model matches movie86's software trap.
        await page.getByTestId('turbo86-url').fill(t86.url);
        await page.getByTestId('turbo86-send').click();

        // The status span flips to `sent LoadContext: N regions` on
        // successful snapshot. Then turbo86 replies with an Outbound
        // (Stdout / Exit / Fault) — that flips the status to
        // `turbo86 → ...`.
        await expect(page.getByTestId('turbo86-status')).toContainText(
            /sent LoadContext/,
            { timeout: 10_000 },
        );
        await expect(page.getByTestId('turbo86-status')).toContainText(
            /turbo86 →/,
            { timeout: 30_000 },
        );

        // No unhandled errors during the round-trip.
        expect(consoleErrors.filter((m) => /TypeError|ReferenceError/.test(m))).toEqual([]);
    } finally {
        t86.proc.kill('SIGTERM');
    }
});
