// turbo86 handover E2E.
//
// Verifies the explorer's side of the handover protocol — the Vm
// snapshot it builds, the JSON `LoadContext` message it sends over the
// WebSocket, and the UI's reaction to a turbo86 `Stdout` / `Exit`
// Outbound reply. We deliberately do **not** open a real cross-origin
// WS in this test: Playwright's headless Chromium enforces a stricter
// secure-origin policy than production Chrome and blocks `ws://127.
// 0.0.1` from `https://*.pages.dev` even with PNA + web-security
// disabled (verified — turbo86 logs zero connect attempts while the
// page reports readyState=CLOSED). The wire-shape parity with a real
// turbo86 is already pinned by `movie86/wasm/tests/turbo86_handover.mjs`
// (Node test, no browser sandbox), so duplicating that here would
// only add false-failure surface.
//
// Instead, an `addInitScript` swaps `window.WebSocket` for a stub that
// records every constructor call + `send()` payload. The test feeds a
// canned Outbound back via the stub's `dispatchEvent('message', ...)`
// and asserts the UI surfaces it the same way it would for a real
// turbo86.

import { expect, test } from '@playwright/test';

test.skip(!process.env.E2E_BASE_URL, 'set E2E_BASE_URL to run this spec');

test.setTimeout(120_000);

test('explorer builds a LoadContext payload and handles turbo86 Outbound replies', async ({
    page,
}) => {
    const consoleErrors: string[] = [];
    page.on('console', (msg) => {
        if (msg.type() === 'error') consoleErrors.push(msg.text());
    });
    page.on('pageerror', (e) => consoleErrors.push(`pageerror: ${e.message}`));

    // Stub the WebSocket *before* any page script runs. The stub
    // captures the URL + every send() payload on `globalThis.__t86Spy`
    // and forwards `dispatchTestMessage` calls back into the page as
    // synthetic `message` events.
    await page.addInitScript(() => {
        const spy = {
            url: null as string | null,
            sent: [] as string[],
            instance: null as unknown as {
                listeners: Record<string, ((ev: unknown) => void)[]>;
                emit: (ev: { type: string;[k: string]: unknown }) => void;
            },
        };
        (globalThis as unknown as { __t86Spy: typeof spy }).__t86Spy = spy;

        class StubWS {
            url: string;
            readyState = 0;
            binaryType = 'arraybuffer';
            listeners: Record<string, ((ev: unknown) => void)[]> = {};
            static CONNECTING = 0;
            static OPEN = 1;
            static CLOSING = 2;
            static CLOSED = 3;
            constructor(url: string) {
                this.url = url;
                spy.url = url;
                spy.instance = this as unknown as typeof spy.instance;
                // async open so the caller can attach listeners first
                setTimeout(() => {
                    this.readyState = 1;
                    this.emit({ type: 'open' });
                }, 0);
            }
            addEventListener(type: string, fn: (ev: unknown) => void) {
                (this.listeners[type] ??= []).push(fn);
            }
            removeEventListener(type: string, fn: (ev: unknown) => void) {
                const arr = this.listeners[type];
                if (!arr) return;
                this.listeners[type] = arr.filter((f) => f !== fn);
            }
            send(data: string) {
                spy.sent.push(typeof data === 'string' ? data : '<binary>');
            }
            close() {
                this.readyState = 3;
                this.emit({ type: 'close' });
            }
            emit(ev: { type: string;[k: string]: unknown }) {
                (this.listeners[ev.type] ?? []).forEach((fn) => fn(ev));
            }
        }
        // @ts-expect-error overwriting global
        globalThis.WebSocket = StubWS;
    });

    await page.goto('');

    // Drop a known static ELF into the upload input so movie86 has a
    // Vm to snapshot. return42 ships under /movie86/examples/ on the
    // deploy.
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
    await expect(page.getByTestId('vm-run')).toBeEnabled({ timeout: 10_000 });

    // Drive handover. URL field defaults to ws://127.0.0.1:1234 — the
    // stubbed WebSocket accepts anything, so we leave it.
    await page.getByTestId('turbo86-send').click();

    // The status flips through `sent LoadContext: N regions, mode=trap`
    // once the stub fires `open` and the page calls send().
    await expect(page.getByTestId('turbo86-status')).toContainText(
        /sent LoadContext/,
        { timeout: 5_000 },
    );

    // Inspect the captured send() payload — JSON, matches the
    // turbo86 LoadContext schema (lowercase `type`, regs object,
    // base64-encoded region bytes).
    const sent: string[] = await page.evaluate(() => {
        const s = (
            globalThis as unknown as {
                __t86Spy: { sent: string[] };
            }
        ).__t86Spy.sent;
        return s.slice();
    });
    expect(sent.length).toBeGreaterThan(0);
    const msg = JSON.parse(sent[0]!);
    expect(msg.type).toBe('load_context');
    expect(msg.mode).toBe('trap');
    expect(typeof msg.context).toBe('object');
    expect(typeof msg.context.regs).toBe('object');
    expect(Array.isArray(msg.context.regions)).toBe(true);
    expect(msg.context.regions.length).toBeGreaterThan(0);
    // Each region carries `addr` (number) + `bytes` (base64 string).
    for (const region of msg.context.regions) {
        expect(typeof region.addr).toBe('number');
        expect(typeof region.bytes).toBe('string');
        // base64 of non-empty bytes — at least one '=' / 'A-Za-z0-9/+'.
        expect(region.bytes).toMatch(/^[A-Za-z0-9+/]+=*$/);
    }

    // Now play turbo86's role: send an Outbound `stdout` event back
    // through the stub. The page should flip turbo86-status to
    // `turbo86 → stdout`.
    await page.evaluate(() => {
        const inst = (
            globalThis as unknown as {
                __t86Spy: { instance: { emit: (ev: object) => void } };
            }
        ).__t86Spy.instance;
        inst.emit({
            type: 'message',
            data: JSON.stringify({
                type: 'stdout',
                bytes: btoa('hello from turbo86\n'),
            }),
        });
    });
    await expect(page.getByTestId('turbo86-status')).toContainText(
        /turbo86 → stdout/,
        { timeout: 2_000 },
    );

    // And again with an `exit` event — same path, different topic.
    await page.evaluate(() => {
        const inst = (
            globalThis as unknown as {
                __t86Spy: { instance: { emit: (ev: object) => void } };
            }
        ).__t86Spy.instance;
        inst.emit({
            type: 'message',
            data: JSON.stringify({ type: 'exit', code: 42 }),
        });
    });
    await expect(page.getByTestId('turbo86-status')).toContainText(
        /turbo86 → exit/,
        { timeout: 2_000 },
    );

    // No unhandled errors during the round-trip.
    expect(consoleErrors.filter((m) => /TypeError|ReferenceError/.test(m))).toEqual(
        [],
    );
});
