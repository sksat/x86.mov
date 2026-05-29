// turbo86 handover E2E (backend selector).
//
// Verifies the explorer's side of the handover protocol driven through
// the execution-backend *selector*: selecting turbo86 + Run forwards a
// Vm snapshot as a JSON `LoadContext`, a turbo86 `Stdout` Outbound joins
// the console, and switching back to movie86 mid-run sends a `Pause` and
// absorbs the `Paused` snapshot back into the local Vm (reverse
// handover). We deliberately do **not** open a real cross-origin
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

test('explorer forwards on backend-select+Run and reverses on switch-back', async ({
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

    // Select turbo86 as the execution backend. The Vm is stopped, so
    // this just records the choice (deferred handover) and reveals the
    // turbo86 connection strip — no socket opens yet.
    await page.getByTestId('backend-opt-turbo86').click();
    await expect(page.getByTestId('turbo86-handover')).toBeVisible();

    // Run on the turbo86 backend == forward handover. URL defaults to
    // ws://127.0.0.1:1234; the stubbed WebSocket accepts anything.
    await page.getByTestId('vm-run').click();

    // Status flips to `forwarded: N regions, mode=trap` once the stub
    // fires `open` and the page snapshots + sends LoadContext.
    await expect(page.getByTestId('turbo86-status')).toContainText(
        /forwarded:/,
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

    // Play turbo86's role: send a `stdout` Outbound back through the
    // stub. It joins the same Console the local movie86 run feeds.
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
    await expect(page.getByTestId('stdout')).toContainText(
        /hello from turbo86/,
        { timeout: 2_000 },
    );

    // Live mirroring: a `video_mode` + `mem_update` Outbound pair should
    // be absorbed into the local Vm (setActiveVideoMode + writeMem) so
    // the canvas keeps up while turbo86 runs. We echo a forward region so
    // writeMem targets a mapped address; the assertion is just that the
    // round-trip raises no errors (checked at the end).
    await page.evaluate((forward) => {
        const ctx = JSON.parse(forward).context;
        const inst = (
            globalThis as unknown as {
                __t86Spy: { instance: { emit: (ev: object) => void } };
            }
        ).__t86Spy.instance;
        inst.emit({
            type: 'message',
            data: JSON.stringify({ type: 'video_mode', mode: 0x13 }),
        });
        inst.emit({
            type: 'message',
            data: JSON.stringify({ type: 'mem_update', regions: ctx.regions }),
        });
    }, sent[0]!);

    // Reverse handover: switch back to movie86 *while turbo86 runs*.
    // The page must send a `{type:'pause'}` Inbound and then absorb the
    // `Paused` Outbound back into the local Vm. We echo the captured
    // forward context as the Paused frame so loadContextInto has a
    // valid (regs + regions) snapshot to restore.
    await page.getByTestId('backend-opt-movie86').click();
    await expect
        .poll(
            () =>
                page.evaluate(() => {
                    const s = (
                        globalThis as unknown as {
                            __t86Spy: { sent: string[] };
                        }
                    ).__t86Spy.sent;
                    return s.some((f) => {
                        try {
                            return JSON.parse(f).type === 'pause';
                        } catch {
                            return false;
                        }
                    });
                }),
            { timeout: 5_000 },
        )
        .toBe(true);

    await page.evaluate((forward) => {
        const ctx = JSON.parse(forward).context;
        const inst = (
            globalThis as unknown as {
                __t86Spy: { instance: { emit: (ev: object) => void } };
            }
        ).__t86Spy.instance;
        inst.emit({
            type: 'message',
            data: JSON.stringify({
                type: 'paused',
                regs: ctx.regs,
                regions: ctx.regions,
                signal: 0,
                reason: 'test',
            }),
        });
    }, sent[0]!);
    await expect(page.getByTestId('turbo86-status')).toContainText(
        /reverse: applied/,
        { timeout: 5_000 },
    );

    // No unhandled errors during the round-trip.
    expect(consoleErrors.filter((m) => /TypeError|ReferenceError/.test(m))).toEqual(
        [],
    );
});
