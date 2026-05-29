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

        // Round-trip: send a snapshot of a tight-loop guest, let it
        // run for a bit, send Pause, receive Paused, restore back
        // into the local Vm. Verifies the full reverse-handoff loop
        // including the Pause Inbound + turbo86's Paused with sparse
        // Regions + `loadContextInto` absorbing it. The guest is
        // `jmp $` (EB FE — 2-byte tight loop) at entry; turbo86 will
        // be stuck in wait4 until Pause is sent.
        try {
            const entry = 0x08048000;
            const jmpSelf = new Uint8Array([0xEB, 0xFE]);
            const snapshotIntoVm = {
                regs: {
                    eax: 0, ebx: 0, ecx: 0, edx: 0,
                    esi: 0, edi: 0, ebp: 0,
                    esp: 0x701FFFF0, eip: entry, eflags: 0,
                },
                regions: [{ addr: entry, bytes: jmpSelf }],
            };

            const url = `ws://127.0.0.1:${port}/`;
            const ws = new WebSocket(url);
            const events = [];
            const pauseEvent = new Promise((resolve, reject) => {
                ws.addEventListener('open', () => {
                    ws.send(wrapper.makeLoadContextMessage(snapshotIntoVm, 'host'));
                    // Let the guest spin briefly so we're exercising
                    // the "no-syscall tight loop, Pause via SIGSTOP"
                    // path that turbo86's server tests already pin.
                    setTimeout(() => ws.send(JSON.stringify({ type: 'pause' })), 100);
                }, { once: true });
                ws.addEventListener('message', (e) => {
                    const msg = wrapper.parseOutboundMessage(e.data);
                    events.push(msg);
                    if (msg.type === 'paused') resolve(msg);
                });
                ws.addEventListener('close', () => {
                    if (!events.some(e => e.type === 'paused')) {
                        reject(new Error('WS closed without Paused'));
                    }
                });
                ws.addEventListener('error', reject, { once: true });
            });
            const paused = await pauseEvent;
            ws.close();

            // turbo86's Paused must carry a non-empty `regions`
            // array (sparse stack snapshot etc.) and `regs.eip`
            // pointing at the jmp instruction.
            assert.equal(paused.regs.eip, entry,
                `paused EIP ${paused.regs.eip.toString(16)} != entry ${entry.toString(16)}`);
            assert.ok(paused.regions.length >= 1,
                `paused.regions should be non-empty, got ${paused.regions.length}`);

            // Restore into a fresh local Vm that has the jmp ELF
            // loaded — same entry address, so the in-range region
            // (code) lands and any stack-region in the snapshot is
            // skipped. After restore, vm.eip must match what turbo86
            // sent back.
            //
            // To get a Vm at the jmp's base, we synthesize a one-
            // page ELF in code rather than building one on disk —
            // simpler than maintaining a "jmp $" fixture.
            //
            // Actually simpler: load the bundled return42 ELF (which
            // is at 0x08048000 too), then loadContextInto with the
            // paused snapshot. The restored EIP / regs / code at
            // entry will all match turbo86's Paused.
            const elfBytes = new Uint8Array(
                await readFile(`${root}/examples/return42.elf`),
            );
            const vm = new wasmMod.Vm(elfBytes);
            try {
                const { applied, skipped } = wrapper.loadContextInto(vm, paused);
                assert.ok(applied >= 1,
                    `expected ≥1 region applied, got applied=${applied} skipped=${skipped}`);
                assert.equal(vm.eip, entry,
                    `restored EIP ${vm.eip.toString(16)} != ${entry.toString(16)}`);
                // The jmp-self bytes must be at entry (turbo86's
                // snapshot included the code region).
                const at = vm.readMem(entry, 2);
                assert.deepEqual(Array.from(at), [0xEB, 0xFE],
                    `restored bytes at entry != jmp-self`);
            } finally {
                vm.free();
            }
            console.log('ok  full round-trip (snapshot → turbo86 → Pause → loadContextInto)');
        } catch (e) {
            console.error(`FAIL full round-trip: ${e.stack || e.message}`);
            failed++;
        }

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

        // VideoMode Outbound + setActiveVideoMode round-trip. This is
        // the canvas-rendering path: turbo86 catches a `mov [ABI+0x010],
        // al` (CALL_SET_VIDEO_MODE) and emits a VideoMode event; the
        // frontend has to flip the local Vm's activeVideoMode so the
        // canvas pane picks the right FB region. An earlier version
        // wrote the mode byte to the ABI page via `writeMem` — but the
        // ABI page is unmapped in FlatMemory, so the write silently
        // no-oped and the canvas placeholder stayed visible. The fix
        // (lib.rs::setActiveVideoMode) is what this pin guards.
        try {
            // Guest: mov al, 0x13 ; mov [0x1FFE0010], al ; mov eax, 1 ;
            // mov ebx, 0 ; int 0x80 — sets mode 13h via the mov-only
            // ABI then exits 0. The ABI write triggers VideoMode on
            // both host and trap mode (signal-dispatch policy is past
            // the ABI gate).
            const setModeCode = new Uint8Array([
                0xB0, 0x13,                   // mov al, 0x13
                0xA2, 0x10, 0x00, 0xFE, 0x1F, // mov [0x1FFE0010], al
                0xB8, 0x01, 0x00, 0x00, 0x00, // mov eax, 1   (SYS_exit)
                0xBB, 0x00, 0x00, 0x00, 0x00, // mov ebx, 0
                0xCD, 0x80,                   // int 0x80
            ]);
            const events = await runHandover(
                { regs: { ...ctx.regs }, regions: [{ addr: 0x08048000, bytes: setModeCode }] },
                'host',
            );
            const videoMode = events.find(e => e.type === 'video_mode');
            assert.ok(videoMode,
                `expected video_mode event, got types=${events.map(e => e.type).join(',')}`);
            assert.equal(videoMode.mode, 0x13,
                `VideoMode.mode = ${videoMode.mode}, expected 0x13`);

            // Now exercise the frontend response: a fresh Vm has no
            // active mode; setActiveVideoMode(videoMode.mode) must
            // flip it. This is what index.html's `case 'video_mode'`
            // does — pin the seam end-to-end so a regression on
            // either side fires.
            const elfBytes = new Uint8Array(
                await readFile(`${root}/examples/return42.elf`),
            );
            const vm = new wasmMod.Vm(elfBytes);
            try {
                assert.equal(vm.activeVideoMode, undefined,
                    `fresh Vm should have undefined activeVideoMode, got ${vm.activeVideoMode}`);
                vm.setActiveVideoMode(videoMode.mode);
                assert.equal(vm.activeVideoMode, 0x13,
                    `setActiveVideoMode(0x13) didn't flip activeVideoMode — got ${vm.activeVideoMode}`);
            } finally {
                vm.free();
            }
            console.log('ok  real turbo86 handover (VideoMode → setActiveVideoMode flips mode)');
        } catch (e) {
            console.error(`FAIL VideoMode E2E: ${e.stack || e.message}`);
            failed++;
        }

        // MemUpdate Outbound + writeMem round-trip. Pin the periodic-
        // snapshot path: LoadContext carries `mem_update_interval_ms`,
        // turbo86 emits MemUpdate events while the guest runs, the
        // frontend applies each region's bytes to the local Vm via
        // writeMem. We drive a tight jmp-self loop so the only events
        // turbo86 emits are MemUpdates (no Exit until Pause), then
        // Pause to terminate.
        try {
            const entry = 0x08048000;
            // jmp $ (EB FE — 2-byte tight loop) at entry. We seed an
            // arbitrary sentinel byte right after so we can prove the
            // MemUpdate carried real memory bytes back to us.
            const sentinelOffset = 2;
            const sentinel = 0x5A;
            const tightLoop = new Uint8Array([0xEB, 0xFE, sentinel]);
            const loopCtx = {
                regs: {
                    eax: 0, ebx: 0, ecx: 0, edx: 0,
                    esi: 0, edi: 0, ebp: 0,
                    esp: 0x701FFFF0, eip: entry, eflags: 0,
                },
                regions: [{ addr: entry, bytes: tightLoop }],
            };

            const url = `ws://127.0.0.1:${port}/`;
            const ws = new WebSocket(url);
            const events = [];
            const done = new Promise((resolve, reject) => {
                ws.addEventListener('open', () => {
                    ws.send(wrapper.makeLoadContextMessage(loopCtx, 'host', 50));
                    // Give the ticker a few cadences (50 ms × ~6 = ~300 ms)
                    // so we definitely see multiple MemUpdate events,
                    // then Pause to drain.
                    setTimeout(() => ws.send(JSON.stringify({ type: 'pause' })), 300);
                }, { once: true });
                ws.addEventListener('message', (e) => {
                    events.push(wrapper.parseOutboundMessage(e.data));
                });
                ws.addEventListener('close', resolve, { once: true });
                ws.addEventListener('error', reject, { once: true });
            });
            await done;

            const memUpdates = events.filter(e => e.type === 'mem_update');
            assert.ok(memUpdates.length >= 2,
                `expected ≥2 MemUpdate events at 50 ms cadence over 300 ms, got ${memUpdates.length}`);

            // Pick the first MemUpdate whose regions contain entry —
            // turbo86 may also include stack regions. Apply via the
            // same writeMem path the frontend uses, then verify the
            // sentinel byte lands at entry+2.
            const elfBytes = new Uint8Array(
                await readFile(`${root}/examples/return42.elf`),
            );
            const vm = new wasmMod.Vm(elfBytes);
            try {
                const update = memUpdates.find(u =>
                    u.regions.some(r =>
                        r.addr <= entry && entry < r.addr + r.bytes.length));
                assert.ok(update,
                    `no MemUpdate covered entry ${entry.toString(16)}`);
                let applied = 0;
                for (const r of update.regions) {
                    applied += vm.writeMem(r.addr, r.bytes);
                }
                assert.ok(applied > 0,
                    `writeMem applied 0 bytes from MemUpdate — frontend would render an empty canvas`);
                const at = vm.readMem(entry, 3);
                assert.deepEqual(Array.from(at), [0xEB, 0xFE, sentinel],
                    `MemUpdate bytes at entry round-trip mismatch: got ${Array.from(at)}`);
            } finally {
                vm.free();
            }

            // Insns field check: turbo86 samples
            // perf_event_open(PERF_COUNT_HW_INSTRUCTIONS) on each
            // tick and embeds the cumulative count in MemUpdate.
            // jmp-self retires the same instruction over and over so
            // the counter should march forward steadily. Soft-skip
            // the actual assertion when the kernel denied the counter
            // (`insns: 0` on every event) — locked-down CI / paranoid
            // sandboxes default to perf_event_paranoid=3 which
            // refuses unprivileged perf_event_open, and the runtime
            // path is already designed to fall back to "frontend
            // shows event count" there.
            const nonZero = memUpdates.filter(u => u.insns > 0);
            if (nonZero.length === 0) {
                console.log(`skip MemUpdate.insns assertion: perf_event_open unavailable (paranoid kernel?)`);
            } else {
                assert.ok(nonZero.length >= 2,
                    `expected ≥2 MemUpdates with insns>0, got ${nonZero.length}/${memUpdates.length}`);
                // Counts must be monotonically non-decreasing for a
                // tight loop. (Equal would only happen if perf gave us
                // the same sample twice — fine; strictly less is a bug.)
                for (let i = 1; i < nonZero.length; i++) {
                    assert.ok(nonZero[i].insns >= nonZero[i - 1].insns,
                        `MemUpdate.insns went backwards: ${nonZero[i - 1].insns} → ${nonZero[i].insns}`);
                }
                assert.ok(nonZero[nonZero.length - 1].insns > nonZero[0].insns,
                    `MemUpdate.insns did not advance across ${nonZero.length} ticks (final=${nonZero[nonZero.length - 1].insns} initial=${nonZero[0].insns}) — perf counter stuck?`);
            }
            console.log(`ok  real turbo86 handover (MemUpdate ×${memUpdates.length} → writeMem applies bytes + insns ${nonZero.length > 0 ? '✓' : 'unavailable'})`);
        } catch (e) {
            console.error(`FAIL MemUpdate E2E: ${e.stack || e.message}`);
            failed++;
        }

        // Reservations E2E. Without it, a canvas demo that handed over
        // mid-flight (post-mmap_request, pre-first-FB-write) would
        // SIGSEGV on the next pixel store: the sender's mmap_request
        // side-effect is invisible in Regs/Regions, the receiver has
        // no idea the page is supposed to be mapped, and a write to
        // 0xA0000 traps. The Reservation roundtrip lets turbo86
        // replay the mmap at LoadContext so the same write succeeds.
        try {
            const entry = 0x08048000;
            const fbAddr = 0x000A_0000;
            // Guest: mov [0xA0000], 0x12345678 ; mov eax, 1 ;
            // mov ebx, 42 ; int 0x80. The write tests the page was
            // actually mapped (a SIGSEGV would surface as Paused
            // signal=11 with no Exit).
            const code = new Uint8Array([
                0xC7, 0x05, 0x00, 0x00, 0x0A, 0x00, 0x78, 0x56, 0x34, 0x12,
                0xB8, 0x01, 0x00, 0x00, 0x00,
                0xBB, 0x2A, 0x00, 0x00, 0x00,
                0xCD, 0x80,
            ]);
            const ctxWithReservation = {
                regs: {
                    eax: 0, ebx: 0, ecx: 0, edx: 0,
                    esi: 0, edi: 0, ebp: 0,
                    esp: 0x701FFFF0,
                    eip: entry,
                    eflags: 0,
                },
                regions: [{ addr: entry, bytes: code }],
                reservations: [{ addr: fbAddr, size: 0x1000 }],
            };
            const events = await runHandover(ctxWithReservation, 'host');
            assert.equal(events.length, 1,
                `expected 1 event (Exit), got ${events.length} (Paused → Reservation handling failed?)`);
            assert.equal(events[0].type, 'exit',
                `expected exit (not ${events[0].type} signal=${events[0].signal ?? '-'})`);
            assert.equal(events[0].code, 42,
                `expected exit 42, got ${events[0].code}`);

            console.log('ok  real turbo86 handover (Reservation → FB page mmap\'d → guest writes succeed)');
        } catch (e) {
            console.error(`FAIL Reservation E2E: ${e.stack || e.message}`);
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
