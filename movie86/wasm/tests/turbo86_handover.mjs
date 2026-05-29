// Real-turbo86 end-to-end smoke for the wasm handover plumbing.
//
// Wires the production browser path (snapshotContext + makeLoadContextMessage
// + parseOutboundMessage from movie86.mjs) up to an actual `turbo86`
// process and drives a session start-to-finish over WebSocket. The
// browser tab and this test exercise the same code paths — if turbo86
// drifts away from the wire format the demo would silently break;
// this test catches the drift in CI before a user does.
//
// Gating:
//   - `TURBO86_BIN=/path/to/turbo86 node tests/turbo86_handover.mjs`
//     runs against an already-built binary.
//   - Without `TURBO86_BIN` we look for `go` on PATH and build the
//     binary on the fly; falling back further (no go either) skips
//     the test cleanly so a Node-only environment (Cloudflare Pages
//     preview, contributor without Go) doesn't break the build.
//
// Test shape: build a Context that codes a trivial `exit(42)` via
// `int 0x80` at turbo86's stub-code base (`0x08048000`), hand it to
// turbo86 with `LoadContext{mode: "host"}`, and assert a single
// `Exit(42)` event flows back.

import { readFile, mkdtemp, rm } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const root = `${here}/..`;
const repoRoot = `${root}/../..`;

const wasm = await readFile(`${root}/build/browser/movie86_wasm_bg.wasm`);
const wasmMod = await import(`${root}/build/browser/movie86_wasm.js`);
await wasmMod.default({ module_or_path: wasm });
const wrapper = await import(`${root}/movie86.mjs`);

// --- locate or build turbo86 ---
async function resolveTurbo86Binary() {
    if (process.env.TURBO86_BIN) return { path: process.env.TURBO86_BIN, cleanup: null };

    // Fall back to building from source. Skip if go isn't on PATH —
    // running this test on a non-Go-equipped CI shouldn't be a hard
    // failure; the Rust-side CLI handover test in
    // `movie86/cli/tests/handover_turbo86.rs` already covers the
    // turbo86 side from a different language. This file adds the JS
    // path on top.
    const hasGo = await new Promise((resolve) => {
        const c = spawn('go', ['version'], { stdio: 'ignore' });
        c.on('error', () => resolve(false));
        c.on('exit', (code) => resolve(code === 0));
    });
    if (!hasGo) return null;

    const tmpDir = await mkdtemp(join(tmpdir(), 'turbo86-test-'));
    const binPath = join(tmpDir, 'turbo86');
    await new Promise((resolve, reject) => {
        const c = spawn(
            'go',
            ['build', '-o', binPath, './cmd/turbo86'],
            { cwd: `${repoRoot}/turbo86`, stdio: 'inherit' },
        );
        c.on('exit', (code) =>
            code === 0 ? resolve() : reject(new Error(`go build exit ${code}`)));
        c.on('error', reject);
    });
    return { path: binPath, cleanup: () => rm(tmpDir, { recursive: true, force: true }) };
}

// --- spawn turbo86 on an ephemeral port ---
function pickPort() {
    // A naive "ask the OS for a port" via net.createServer().listen(0)
    // would work, but the bound listener might still be in TIME_WAIT
    // when turbo86 tries to grab the same port. Picking a random high
    // port and relying on the readiness wait below is simpler and
    // matches what the CLI's handover_turbo86 test does on the Rust
    // side.
    return 20000 + Math.floor(Math.random() * 20000);
}

async function waitForTurbo86Ready(port, timeoutMs = 4000) {
    const deadline = Date.now() + timeoutMs;
    while (Date.now() < deadline) {
        try {
            const ws = new WebSocket(`ws://127.0.0.1:${port}/`);
            await new Promise((resolve, reject) => {
                ws.addEventListener('open', resolve, { once: true });
                ws.addEventListener('error', reject, { once: true });
            });
            ws.close();
            return;
        } catch {
            await new Promise(r => setTimeout(r, 50));
        }
    }
    throw new Error(`turbo86 did not become ready on port ${port}`);
}

// --- the actual test ---
async function main() {
    const bin = await resolveTurbo86Binary();
    if (!bin) {
        console.log('skip turbo86_handover: TURBO86_BIN unset and `go` not on PATH');
        return;
    }
    let failed = 0;
    const port = pickPort();
    const child = spawn(bin.path, ['--addr', `127.0.0.1:${port}`], {
        stdio: ['ignore', 'inherit', 'inherit'],
    });
    try {
        await waitForTurbo86Ready(port);

        // Build a Context that exits with code 42 via `int 0x80`. The
        // raw machine code is `B8 01 00 00 00 BB 2A 00 00 00 CD 80`
        // (mov eax,1; mov ebx,42; int 0x80) — turbo86 maps the code
        // region at 0x08048000 (see stub/_stub.s), so the entry must
        // live there, not at the 0x1000 the movie86 examples use.
        const code = new Uint8Array([
            0xB8, 0x01, 0x00, 0x00, 0x00, // mov eax, 1   (SYS_exit)
            0xBB, 0x2A, 0x00, 0x00, 0x00, // mov ebx, 42
            0xCD, 0x80,                   // int 0x80
        ]);
        const ctx = {
            regs: {
                eax: 0, ebx: 0, ecx: 0, edx: 0,
                esi: 0, edi: 0, ebp: 0,
                esp: 0x701FFFF0,  // top of stub's 2 MiB stack mmap (see DESIGN.md)
                eip: 0x08048000,
                eflags: 0,
            },
            regions: [{ addr: 0x08048000, bytes: code }],
        };

        async function runHandover(handoverCtx, mode) {
            const events = [];
            const url = `ws://127.0.0.1:${port}/`;
            const ws = new WebSocket(url);
            await new Promise((resolve, reject) => {
                ws.addEventListener('open', () => {
                    ws.send(wrapper.makeLoadContextMessage(handoverCtx, mode));
                }, { once: true });
                ws.addEventListener('message', (e) => {
                    events.push(wrapper.parseOutboundMessage(e.data));
                });
                ws.addEventListener('close', resolve, { once: true });
                ws.addEventListener('error', reject, { once: true });
            });
            return events;
        }

        try {
            const events = await runHandover(ctx, 'host');
            assert.equal(events.length, 1, `expected 1 event (Exit), got ${events.length}`);
            assert.equal(events[0].type, 'exit', `expected exit event, got ${events[0].type}`);
            assert.equal(events[0].code, 42, `expected exit 42, got ${events[0].code}`);
            console.log('ok  real turbo86 handover (exit 42)');
        } catch (e) {
            console.error(`FAIL real turbo86 handover: ${e.message}`);
            failed++;
        }

        // Third path: real Vm snapshot. Load each bundled example
        // into a wasm Vm, take a snapshot via the same
        // `wrapper.snapshotContext` the browser button uses, hand it
        // straight to turbo86. This is the path that broke when
        // example ELFs were linked at 0x1000 (below turbo86's stub
        // mapping); the rebase to 0x08048000 is what this test pins.
        // A regression here surfaces as `fault write context region
        // 0x...: input/output error` from /proc/PID/mem, exactly what
        // users saw.
        const vmCases = [
            // name, expected exit code, expected stdout bytes (or null).
            { name: 'return42',   exit: 42, stdout: null },
            { name: 'hello',      exit: 0,  stdout: 'Hello\n' },
            { name: 'call_greet', exit: 0,  stdout: 'Hi!\n' },
        ];
        for (const tc of vmCases) {
            try {
                const elfBytes = new Uint8Array(
                    await readFile(`${root}/examples/${tc.name}.elf`),
                );
                const vm = new wasmMod.Vm(elfBytes);
                let ctx;
                try {
                    assert.ok(
                        0x08048000 <= vm.eip && vm.eip < 0x09048000,
                        `${tc.name}: EIP ${vm.eip.toString(16)} is outside turbo86's [0x08048000, 0x09048000) RWX region — examples need rebasing`,
                    );
                    ctx = wrapper.snapshotContext(vm);
                } finally {
                    vm.free();
                }
                const events = await runHandover(ctx, 'host');
                const exit = events.find(e => e.type === 'exit');
                assert.ok(exit, `${tc.name}: no exit event in ${events.length} events`);
                assert.equal(exit.code, tc.exit,
                    `${tc.name}: exit ${exit.code} != ${tc.exit}`);
                if (tc.stdout !== null) {
                    const stdoutBytes = events
                        .filter(e => e.type === 'stdout')
                        .reduce((acc, e) => {
                            const merged = new Uint8Array(acc.length + e.bytes.length);
                            merged.set(acc); merged.set(e.bytes, acc.length);
                            return merged;
                        }, new Uint8Array(0));
                    const stdout = new TextDecoder().decode(stdoutBytes);
                    assert.equal(stdout, tc.stdout,
                        `${tc.name}: stdout ${JSON.stringify(stdout)} != ${JSON.stringify(tc.stdout)}`);
                }
                console.log(`ok  real turbo86 handover (Vm.snapshotContext → ${tc.name}.elf → exit ${tc.exit})`);
            } catch (e) {
                console.error(`FAIL real turbo86 handover (${tc.name}): ${e.message}`);
                failed++;
            }
        }

        // Second handover: write(1, "Hi\n", 3) then exit(0). Exercises
        // the Stdout event path so we know the base64 decode plumbing
        // in `parseOutboundMessage` survives a real round-trip — JSON
        // shape alone wouldn't catch a byte-length mismatch.
        try {
            // The string "Hi\n" lives at offset 0x22 — counted from
            // the actual instruction byte length above (5+5+5+5+2 for
            // write setup + int 80, then 5+5+2 for exit setup + int
            // 80 = 0x22 bytes). Putting the message after all code
            // keeps the layout flat: EIP never reaches the data bytes
            // because the exit syscall ends the session first.
            const writeCode = new Uint8Array([
                0xB8, 0x04, 0x00, 0x00, 0x00, // mov eax, 4   (SYS_write)
                0xBB, 0x01, 0x00, 0x00, 0x00, // mov ebx, 1   (stdout)
                0xB9, 0x22, 0x80, 0x04, 0x08, // mov ecx, 0x08048022 (msg)
                0xBA, 0x03, 0x00, 0x00, 0x00, // mov edx, 3
                0xCD, 0x80,                   // int 0x80
                0xB8, 0x01, 0x00, 0x00, 0x00, // mov eax, 1   (SYS_exit)
                0xBB, 0x00, 0x00, 0x00, 0x00, // mov ebx, 0
                0xCD, 0x80,                   // int 0x80
                0x48, 0x69, 0x0A,             // "Hi\n" at offset 0x22
            ]);
            const writeCtx = {
                regs: { ...ctx.regs },
                regions: [{ addr: 0x08048000, bytes: writeCode }],
            };
            const events = await runHandover(writeCtx, 'host');
            // Expect Stdout then Exit, in that order.
            assert.equal(events.length, 2,
                `expected Stdout + Exit, got ${events.length} events`);
            assert.equal(events[0].type, 'stdout');
            assert.deepEqual(Array.from(events[0].bytes), [0x48, 0x69, 0x0A],
                `stdout bytes mismatch: got ${Array.from(events[0].bytes)}`);
            assert.equal(events[1].type, 'exit');
            assert.equal(events[1].code, 0);
            console.log('ok  real turbo86 handover (write "Hi\\n" + exit 0)');
        } catch (e) {
            console.error(`FAIL real turbo86 handover (write): ${e.message}`);
            failed++;
        }
    } finally {
        child.kill('SIGTERM');
        if (bin.cleanup) await bin.cleanup();
    }
    if (failed) {
        process.exit(1);
    }
}

await main();
