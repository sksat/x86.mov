// End-to-end test for the SIMD86 "acceleration boost": load the real
// deck.elf into a movie86 Vm, advance it to slide 0 (as the browser does
// before boost), snapshot it via the exact browser path
// (snapshotContext + makeLoadContextMessage), hand it to a REAL turbo86
// over WebSocket, and assert the native session actually runs instead of
// faulting on arrival.
//
// This reproduces the live failure "boost flashes rainbow then reverts to
// movie86": ws.onopen fires (the rainbow), turbo86 then drops the session
// (ws.onclose → revert). The drop means the handed-over guest faulted on
// turbo86. The browser only surfaces it as a disconnect; this test makes
// the *reason* observable (a `fault`/Paused-signal event, or no forward
// progress) so a deck/handover regression breaks loudly in CI.
//
// Gating mirrors movie86/wasm/tests/turbo86_handover.mjs:
//   - TURBO86_BIN=/path/to/turbo86 node simd/test-boost.mjs   (prebuilt)
//   - else build from source if `go` is on PATH
//   - else skip cleanly (Node-only env).
// Needs the movie86 wasm build (make -C movie86/wasm build-wasm) and a
// built simd/kvm2026-kansai/deck.elf (./simd/build-deck.sh).

import { readFile, mkdtemp, rm } from 'node:fs/promises';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';
import { tmpdir } from 'node:os';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const m86 = `${here}/../movie86/wasm`;
const repoRoot = `${here}/..`;

const wasm = await readFile(`${m86}/build/browser/movie86_wasm_bg.wasm`);
const wasmMod = await import(`${m86}/build/browser/movie86_wasm.js`);
await wasmMod.default({ module_or_path: wasm });
const wrapper = await import(`${m86}/movie86.mjs`);
const { snapshotContext, makeLoadContextMessage, parseOutboundMessage } = wrapper;

const DECK = `${here}/kvm2026-kansai/deck.elf`;
const MODE = 0x74; // the 320x180 fallback deck's uniform video mode

// --- locate or build turbo86 (same policy as the movie86 handover E2E) ---
async function resolveTurbo86Binary() {
    if (process.env.TURBO86_BIN) return { path: process.env.TURBO86_BIN, cleanup: null };
    const hasGo = await new Promise((resolve) => {
        const c = spawn('go', ['version'], { stdio: 'ignore' });
        c.on('error', () => resolve(false));
        c.on('exit', (code) => resolve(code === 0));
    });
    if (!hasGo) return null;
    const tmpDir = await mkdtemp(join(tmpdir(), 'turbo86-boost-'));
    const binPath = join(tmpDir, 'turbo86');
    await new Promise((resolve, reject) => {
        const c = spawn('go', ['build', '-o', binPath, './cmd/turbo86'],
            { cwd: `${repoRoot}/turbo86`, stdio: 'inherit' });
        c.on('exit', (code) => code === 0 ? resolve() : reject(new Error(`go build exit ${code}`)));
        c.on('error', reject);
    });
    return { path: binPath, cleanup: () => rm(tmpDir, { recursive: true, force: true }) };
}

function pickPort() { return 20000 + Math.floor(Math.random() * 20000); }

async function waitForTurbo86Ready(port, timeoutMs = 5000) {
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

// Step the Vm until slide 0 is on screen (mode set + framebuffer painted),
// matching the browser state at the moment the user hits boost.
function advanceToSlide0(vm) {
    const BUDGET = 800_000_000n, BATCH = 8_000_000n;
    let spent = 0n;
    while (spent < BUDGET) {
        if (vm.haltReason) throw new Error(`guest halted (${vm.haltReason}) before slide 0`);
        if (vm.activeVideoMode === MODE) {
            const m = wrapper.modeForNumber(MODE);
            const fb = vm.readMem(m.addr, m.byteLength);
            // non-zero somewhere → slide was blitted
            if (fb.length === m.byteLength && fb.some(b => b !== 0)) return;
        }
        vm.stepN(BATCH);
        spent += BATCH;
    }
    throw new Error('Vm never reached a painted slide 0');
}

async function main() {
    const bin = await resolveTurbo86Binary();
    if (!bin) {
        console.log('skip test-boost: TURBO86_BIN unset and `go` not on PATH');
        return;
    }
    let failed = 0;
    const port = pickPort();
    const child = spawn(bin.path, ['--addr', `127.0.0.1:${port}`],
        { stdio: ['ignore', 'inherit', 'inherit'] });
    try {
        await waitForTurbo86Ready(port);

        const elf = new Uint8Array(await readFile(DECK));
        const vm = new wasmMod.Vm(elf);
        let snap;
        try {
            advanceToSlide0(vm);
            snap = snapshotContext(vm);
        } finally {
            vm.free();
        }

        // Diagnostics: where does the snapshot land relative to turbo86's
        // 16 MiB stub region [0x08048000, 0x09048000)? Anything past the
        // top must ride turbo86's dynamic-mmap path; anything the runner
        // can't place is what kills the session.
        const TOP = 0x09048000;
        const overflow = snap.regions.filter(r => r.addr + r.bytes.length > TOP && r.addr < 0x70000000);
        const totalMiB = (snap.regions.reduce((a, r) => a + r.bytes.length, 0) / 1048576).toFixed(1);
        console.log(`info  snapshot: ${snap.regions.length} regions, ${totalMiB} MiB total`);
        for (const r of snap.regions) {
            console.log(`info    region 0x${r.addr.toString(16)} .. 0x${(r.addr + r.bytes.length).toString(16)} (${(r.bytes.length / 1048576).toFixed(2)} MiB)`);
        }
        if (overflow.length) {
            console.log(`info  ${overflow.length} region(s) extend past the stub top 0x${TOP.toString(16)} (need dynamic mmap)`);
        }

        // Hand over exactly as the browser does, ask for the FB stream,
        // let it run, then Pause. A healthy boost yields video_mode +
        // mem_update events and NO fault; the live bug shows up as a
        // `fault`/`paused signal` or an immediate close with nothing.
        const url = `ws://127.0.0.1:${port}/`;
        const ws = new WebSocket(url);
        const events = [];
        let opened = false;
        await new Promise((resolve) => {
            // Settle exactly once. After we send Pause, turbo86 ends the
            // session and the socket may close abnormally (code 1006),
            // which fires a late `error` event — that's expected here, not
            // a deck failure, so resolve on either close or error and let
            // the assertions below judge by the collected events (handshake
            // opened? any fault? did the deck make progress?).
            let settled = false;
            const finish = () => { if (!settled) { settled = true; clearTimeout(timer); resolve(); } };
            const timer = setTimeout(() => { try { ws.close(); } catch { /* */ } }, 2500);
            ws.addEventListener('open', () => {
                opened = true;
                ws.send(makeLoadContextMessage(snap, 'host', 100));
                setTimeout(() => ws.send(JSON.stringify({ type: 'pause' })), 1200);
            }, { once: true });
            ws.addEventListener('message', (e) => {
                try { events.push(parseOutboundMessage(e.data)); } catch { /* ignore */ }
            });
            ws.addEventListener('close', finish, { once: true });
            ws.addEventListener('error', finish, { once: true });
        });

        const types = events.map(e => e.type);
        console.log(`info  opened=${opened} events=[${types.join(', ') || '(none)'}]`);
        const fault = events.find(e => e.type === 'fault');
        const memUpdates = events.filter(e => e.type === 'mem_update');
        const paused = events.find(e => e.type === 'paused');
        // We Pause the session ourselves (SIGSTOP = 19) to end the test, so
        // a `paused` carrying signal 19 is the *expected* clean stop — not a
        // crash. A guest crash shows up as a `fault` event or a `paused` on
        // a fatal signal we did NOT send (SIGSEGV 11 / SIGILL 4 / SIGBUS 7),
        // typically with no prior mem_update (dead on arrival).
        const SIGSTOP = 19;
        const crashPaused = paused && paused.signal && paused.signal !== SIGSTOP ? paused : null;
        if (fault) console.log(`info  fault: ${fault.reason}`);
        if (paused) console.log(`info  paused signal=${paused.signal} (19=SIGSTOP, our Pause)`);

        try {
            assert.ok(opened, 'WebSocket never opened (turbo86 rejected the handshake)');
            assert.ok(!fault, `turbo86 faulted during boost: ${fault?.reason}`);
            assert.ok(!crashPaused,
                `guest stopped on fatal signal ${crashPaused?.signal} (not our SIGSTOP) — a crash, not a clean pause`);
            // Forward progress: framebuffer streaming proves the deck is
            // actually executing natively under turbo86, not dead on arrival.
            assert.ok(memUpdates.length >= 1,
                `no mem_update — guest made no progress after handover (events: ${types.join(',') || 'none'})`);
            console.log(`ok  boost handover: deck runs on turbo86 (${memUpdates.length} mem_update frames, clean pause, no fault)`);
        } catch (e) {
            console.error(`FAIL boost handover: ${e.message}`);
            failed++;
        }
    } finally {
        child.kill('SIGTERM');
        if (bin.cleanup) await bin.cleanup();
    }
    if (failed) process.exit(1);
}

await main();
