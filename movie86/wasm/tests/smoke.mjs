// End-to-end smoke test for movie86-wasm. Loads the wasm module the
// same way the browser will (via the wasm-bindgen --target web shim,
// pre-fed the .wasm bytes since Node doesn't have fetch+import.meta
// in the same way), then runs each bundled example ELF through both
// `runElf` (one-shot) and the step-driven `Vm` API, asserting exit
// code, stdout, and that the Vm path's step count + halt reason match
// the one-shot's. Catches:
//
//   - the JS ↔ Rust glue regressing in a way cargo build alone misses,
//   - example-elf bytes drifting away from what movie86 can load,
//   - default max_steps being too small for the bundled examples,
//   - Vm.stepN / regs / drain getters diverging from runElf semantics.
//
// Invoked from .github/workflows/movie86-wasm.yaml after build-wasm.

import { readFile } from 'node:fs/promises';
import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const root = `${here}/..`;

const wasm = await readFile(`${root}/build/browser/movie86_wasm_bg.wasm`);
const mod  = await import(`${root}/build/browser/movie86_wasm.js`);
await mod.default({ module_or_path: wasm });
const wrapper = await import(`${root}/movie86.mjs`);

const cases = [
    { name: 'return42',   expectExit: 42, expectStdout: ''         },
    { name: 'hello',      expectExit: 0,  expectStdout: 'Hello\n'  },
    { name: 'call_greet', expectExit: 0,  expectStdout: 'Hi!\n'    },
];

const dec = new TextDecoder();

let failed = 0;
for (const c of cases) {
    const elf = new Uint8Array(await readFile(`${root}/examples/${c.name}.elf`));

    // 1) one-shot runElf path
    const r = mod.runElf(elf, undefined);
    const oneShot = { exit: r.exitCode, fault: r.fault, stdout: r.stdout, steps: r.steps };
    r.free();

    // 2) step-driven Vm path — same elf, batched stepN until halt.
    const vm = new mod.Vm(elf);
    let stdoutBytes = new Uint8Array(0);
    while (!vm.haltReason) {
        vm.stepN(10000n);
        const chunk = vm.drainStdout();
        if (chunk.length) {
            const merged = new Uint8Array(stdoutBytes.length + chunk.length);
            merged.set(stdoutBytes); merged.set(chunk, stdoutBytes.length);
            stdoutBytes = merged;
        }
    }
    const stepped = {
        exit: vm.exitCode,
        fault: vm.haltReason,
        stdout: dec.decode(stdoutBytes),
        steps: vm.steps,
    };
    vm.free();

    try {
        // one-shot expectations
        assert.equal(oneShot.fault, undefined,
            `${c.name}: runElf unexpected fault ${oneShot.fault}`);
        assert.equal(oneShot.exit, c.expectExit,
            `${c.name}: runElf exit ${oneShot.exit} != ${c.expectExit}`);
        assert.equal(oneShot.stdout, c.expectStdout,
            `${c.name}: runElf stdout ${JSON.stringify(oneShot.stdout)} != ${JSON.stringify(c.expectStdout)}`);

        // step-driven Vm should agree with the one-shot byte-for-byte.
        assert.equal(stepped.exit, oneShot.exit,
            `${c.name}: Vm exit ${stepped.exit} != runElf ${oneShot.exit}`);
        assert.equal(stepped.stdout, oneShot.stdout,
            `${c.name}: Vm stdout disagrees with runElf`);
        assert.equal(stepped.steps, oneShot.steps,
            `${c.name}: Vm steps ${stepped.steps} != runElf ${oneShot.steps}`);

        console.log(`ok  ${c.name}  exit=${oneShot.exit} steps=${oneShot.steps}`);
    } catch (e) {
        console.error(`FAIL ${c.name}: ${e.message}`);
        failed++;
    }
}

// --- Vm introspection API surface ---
//
// The runElf↔Vm parity loop above exercises stepN / regs / haltReason /
// exitCode / drainStdout, but the demo also depends on disasmAt,
// readMem, sigsegvHandler / sigillHandler, memBase / memLen. Verify
// those on a known-shape fixture (return42: entry 0x1000, first insn
// is `mov ebx, 42` = BB 2A 00 00 00, no signal handlers).
try {
    const elf = new Uint8Array(await readFile(`${root}/examples/return42.elf`));
    const vm = new mod.Vm(elf);
    try {
        // EIP must fall inside the mapped region the loader handed us.
        assert.ok(
            vm.memBase <= vm.eip && vm.eip < vm.memBase + vm.memLen,
            `eip ${vm.eip.toString(16)} not inside [${vm.memBase.toString(16)}, ${(vm.memBase + vm.memLen).toString(16)})`,
        );

        // disasmAt at entry: the first instruction of return42 is
        // `mov ebx, 42` encoded as BB 2A 00 00 00 (5 bytes).
        const d = vm.disasmAt(vm.eip);
        assert.ok(d != null, 'disasmAt(entry) returned null');
        try {
            assert.equal(d.len, 5, `mov ebx, imm32 should be 5 bytes, got ${d.len}`);
            assert.deepEqual(
                Array.from(d.bytes),
                [0xbb, 0x2a, 0x00, 0x00, 0x00],
                `disasmAt bytes mismatch: got ${Array.from(d.bytes).map(b => b.toString(16).padStart(2, '0')).join(' ')}`,
            );
            assert.ok(d.text.includes('Mov'), `disasmAt text should mention Mov, got ${d.text}`);
        } finally {
            d.free();
        }

        // readMem in-range: same 5 bytes as disasmAt
        const inRange = vm.readMem(vm.eip, 5);
        assert.deepEqual(
            Array.from(inRange),
            [0xbb, 0x2a, 0x00, 0x00, 0x00],
            'readMem(eip, 5) disagrees with disasmAt bytes',
        );

        // readMem out-of-range: address well past the mapped region.
        // Pick something high enough to be safe across loader layouts.
        const farAway = 0xfff0_0000 >>> 0;
        assert.equal(
            vm.readMem(farAway, 16).length, 0,
            'readMem past mapped region should return an empty array',
        );

        // Signal handlers: return42 doesn't define `dispatch` or
        // `master_loop`, so both getters surface undefined.
        assert.equal(vm.sigsegvHandler, undefined, `sigsegvHandler expected undefined, got ${vm.sigsegvHandler}`);
        assert.equal(vm.sigillHandler,  undefined, `sigillHandler expected undefined, got ${vm.sigillHandler}`);

        // return42 also doesn't `int 0x10`, so no video mode is active.
        // Run to completion and check the getter stays undefined.
        while (!vm.haltReason) vm.stepN(100n);
        assert.equal(vm.activeVideoMode, undefined,
            `return42 shouldn't touch BIOS — activeVideoMode expected undefined, got ${vm.activeVideoMode}`);

        console.log('ok  Vm introspection (return42)');
    } finally {
        vm.free();
    }
} catch (e) {
    console.error(`FAIL Vm introspection: ${e.message}`);
    failed++;
}

// --- Canvas pipeline smoke ---
//
// canvas_smile draws a yellow filled circle at (160, 100) in mode 13h
// (320×200 RGBA mapped at 0xA0000). Run to completion, then verify
// that (a) a known-yellow pixel landed where we expect, and (b) a
// corner pixel stayed BSS-zero. This is the only test that exercises
// the multi-PT_LOAD loader path + the demo's memory-mapped framebuffer
// convention end-to-end.
try {
    const elf = new Uint8Array(await readFile(`${root}/examples/canvas_smile.elf`));
    const vm = new mod.Vm(elf);
    try {
        while (!vm.haltReason) vm.stepN(20000n);
        assert.equal(vm.exitCode, 0,
            `canvas_smile should exit 0, got ${vm.exitCode} (halt=${vm.haltReason})`);

        // FB layout: mode 13h base 0xA0000, RGBA, stride = 320 * 4.
        const FB_ADDR = 0x000A_0000;
        const FB_W = 320;
        const centerOffset = (100 * FB_W + 160) * 4;
        const center = vm.readMem(FB_ADDR + centerOffset, 4);
        // The face fill is rgba(255, 220, 60, 255).
        assert.deepEqual(Array.from(center), [255, 220, 60, 255],
            `canvas_smile center pixel = ${Array.from(center).join(',')} (expected 255,220,60,255)`);

        // Top-left corner should still be BSS-zeroed (face doesn't reach here).
        const corner = vm.readMem(FB_ADDR, 4);
        assert.deepEqual(Array.from(corner), [0, 0, 0, 0],
            `canvas_smile (0,0) = ${Array.from(corner).join(',')} (expected all-zero BSS)`);

        // The example's prologue is `mov eax, 0x13 ; int 0x10` (set
        // VGA mode 13h). After running, the host should have recorded
        // that mode as active.
        assert.equal(vm.activeVideoMode, 0x13,
            `canvas_smile should set VGA mode 13h — activeVideoMode = ${vm.activeVideoMode}`);

        console.log(`ok  canvas_smile  exit=0 mode=0x13 center=yellow corner=zero`);
    } finally {
        vm.free();
    }
} catch (e) {
    console.error(`FAIL canvas_smile: ${e.message}`);
    failed++;
}

// --- Mode-switch smoke ---
//
// canvas_modes sets VGA mode 13h, paints a red rect, then `int 0x10`-
// switches to mode 12h, paints a blue rect, exits. After the run:
//   - vm.activeVideoMode must be 0x12 (the *last* mode set)
//   - mode 13h's region must show red at its drawing center
//   - mode 12h's region must show blue at its drawing center
// Catches bios_call mode-set being a one-shot, the wrong region
// getting written, or a stale `active_video_mode` after a second
// `int 0x10`.
try {
    const elf = new Uint8Array(await readFile(`${root}/examples/canvas_modes.elf`));
    const vm = new mod.Vm(elf);
    try {
        while (!vm.haltReason) vm.stepN(50000n);
        assert.equal(vm.exitCode, 0,
            `canvas_modes should exit 0, got ${vm.exitCode} (halt=${vm.haltReason})`);
        assert.equal(vm.activeVideoMode, 0x12,
            `canvas_modes ends with mode 12h set — activeVideoMode = ${vm.activeVideoMode}`);
        // Mode 13h center (320×200, red rect at (160,100)).
        const m13 = vm.readMem(0xA0000 + (100 * 320 + 160) * 4, 4);
        assert.deepEqual(Array.from(m13), [220, 60, 60, 255],
            `canvas_modes mode-13h center = ${Array.from(m13).join(',')} (expected 220,60,60,255)`);
        // Mode 12h center (640×480, blue rect at (320,240)).
        const m12 = vm.readMem(0x100000 + (240 * 640 + 320) * 4, 4);
        assert.deepEqual(Array.from(m12), [60, 120, 240, 255],
            `canvas_modes mode-12h center = ${Array.from(m12).join(',')} (expected 60,120,240,255)`);
        console.log('ok  canvas_modes  active=0x12 red@13h blue@12h');
    } finally {
        vm.free();
    }
} catch (e) {
    console.error(`FAIL canvas_modes: ${e.message}`);
    failed++;
}

// --- llvm-mov Mandelbrot smoke (partial run) ---
//
// canvas_mandelbrot.elf is real C compiled through clang -O2 → llvm-mov-llc;
// a full run takes ~90 s, way too long for CI. So we step a fixed budget
// and verify that (a) the new 0xB0..0xB7 + 0xC6 decoders didn't trap on
// the way in, (b) the `int 0x10` mode-set ran, and (c) at least one
// FB pixel got written (i.e. the loop body is actually executing).
// Catches: decoder regressions, BIOS dispatch breaking, or a silent loop
// where execution stalls before reaching the framebuffer-paint phase.
try {
    const elf = new Uint8Array(await readFile(`${root}/examples/canvas_mandelbrot.elf`));
    const vm = new mod.Vm(elf);
    try {
        vm.stepN(30_000_000n);
        assert.equal(vm.haltReason, undefined,
            `canvas_mandelbrot unexpected early halt: ${vm.haltReason}`);
        assert.equal(vm.activeVideoMode, 0x13,
            `canvas_mandelbrot should set VGA mode 13h — activeVideoMode = ${vm.activeVideoMode}`);
        const fb = vm.readMem(0xA0000, 320 * 200 * 4);
        let colored = 0;
        for (let i = 3; i < fb.length; i += 4) if (fb[i] === 255) colored++;
        assert.ok(colored > 0,
            `canvas_mandelbrot should have written at least one pixel after 30M steps (got ${colored})`);
        console.log(`ok  canvas_mandelbrot (partial)  steps=${vm.steps} pixels=${colored}/64000`);
    } finally {
        vm.free();
    }
} catch (e) {
    console.error(`FAIL canvas_mandelbrot: ${e.message}`);
    failed++;
}

// --- Turbo86 handover surface ---
//
// The demo's "Send to local turbo86" button needs two things from the
// wasm side:
//   1. A canonical Context snapshot (regs + sparse memory regions) matching
//      turbo86's proto.Context schema, so a peer engine can pick the session
//      up via LoadContext.
//   2. A wire-format-compatible JSON encoder so the browser can serialize
//      that snapshot into a frame turbo86's UnmarshalInbound accepts
//      byte-for-byte.
//
// Verify both on return42: snapshot at entry, check that regs.eip /
// regs.esp track the Vm's getters, the first instruction bytes survive
// into a non-empty region, and the wire JSON has the exact shape
// turbo86 expects (`type=load_context`, lowercase keys, base64 bytes).
try {
    const elf = new Uint8Array(await readFile(`${root}/examples/return42.elf`));
    const vm = new mod.Vm(elf);
    try {
        const ctx = wrapper.snapshotContext(vm);

        // Regs must reflect the live Vm: full GPR file + EIP, plus
        // EFLAGS = 0 (movie86 doesn't model flags but the schema
        // field is preserved for turbo86 parity).
        assert.equal(ctx.regs.eip, vm.eip, 'snapshot eip != vm.eip');
        const gprs = vm.regs;
        assert.equal(ctx.regs.eax, gprs[0], 'snapshot eax');
        assert.equal(ctx.regs.ecx, gprs[1], 'snapshot ecx');
        assert.equal(ctx.regs.edx, gprs[2], 'snapshot edx');
        assert.equal(ctx.regs.ebx, gprs[3], 'snapshot ebx');
        assert.equal(ctx.regs.esp, gprs[4], 'snapshot esp');
        assert.equal(ctx.regs.ebp, gprs[5], 'snapshot ebp');
        assert.equal(ctx.regs.esi, gprs[6], 'snapshot esi');
        assert.equal(ctx.regs.edi, gprs[7], 'snapshot edi');
        assert.equal(ctx.regs.eflags, 0, 'snapshot eflags should be 0');

        // Regions must be non-empty and sparse — return42 has at
        // least one non-zero page (its code) at the loader's mem base.
        assert.ok(Array.isArray(ctx.regions), 'regions is not an array');
        assert.ok(ctx.regions.length >= 1,
            `expected ≥1 sparse region, got ${ctx.regions.length}`);
        // The first region must contain the entry-point code: the
        // first 5 bytes of return42 are mov ebx, 42 (BB 2A 00 00 00).
        const entryRegion = ctx.regions.find(r =>
            r.addr <= vm.eip && vm.eip + 5 <= r.addr + r.bytes.length);
        assert.ok(entryRegion, `no region covers EIP=${vm.eip.toString(16)}`);
        const off = vm.eip - entryRegion.addr;
        assert.deepEqual(
            Array.from(entryRegion.bytes.subarray(off, off + 5)),
            [0xbb, 0x2a, 0x00, 0x00, 0x00],
            'entry-point bytes inside the snapshot region disagree with the ELF',
        );

        // Wire-format encoder: must match turbo86's proto.Inbound
        // shape — lowercase `type`/keys, base64 bytes, mode string.
        const frame = wrapper.makeLoadContextMessage(ctx, 'host');
        const parsed = JSON.parse(frame);
        assert.equal(parsed.type, 'load_context');
        assert.equal(parsed.mode, 'host');
        assert.equal(parsed.context.regs.eip, vm.eip);
        assert.equal(parsed.context.regs.eflags, 0);
        assert.ok(Array.isArray(parsed.context.regions));
        assert.equal(parsed.context.regions.length, ctx.regions.length);
        // Each region's bytes round-trip through base64.
        for (let i = 0; i < parsed.context.regions.length; i++) {
            const wireRegion = parsed.context.regions[i];
            assert.equal(wireRegion.addr, ctx.regions[i].addr);
            assert.equal(typeof wireRegion.bytes, 'string',
                'wire `bytes` must be a base64 string, not an array');
            const decoded = Buffer.from(wireRegion.bytes, 'base64');
            assert.deepEqual(
                Array.from(decoded),
                Array.from(ctx.regions[i].bytes),
                `region[${i}] base64 round-trip mismatch`,
            );
        }

        // Mode defaults to host when omitted — matching turbo86's Go
        // side `mode == ""` → ModeHost fallback (we emit it explicitly
        // to keep the wire deterministic, but the caller can rely on
        // the default).
        const defaultFrame = JSON.parse(wrapper.makeLoadContextMessage(ctx));
        assert.equal(defaultFrame.mode, 'host');

        // Trap mode round-trips literally.
        const trapFrame = JSON.parse(wrapper.makeLoadContextMessage(ctx, 'trap'));
        assert.equal(trapFrame.mode, 'trap');

        console.log('ok  handover snapshot + wire format (return42)');
    } finally {
        vm.free();
    }
} catch (e) {
    console.error(`FAIL handover surface: ${e.stack || e.message}`);
    failed++;
}

// --- cycle.elf: partial-step decode coverage ---
//
// The other fixtures terminate, so the runElf parity loop above ends
// naturally. `cycle.elf` is an infinite call/ret + jmp loop, so it
// never halts on its own — but the decoder must still walk every
// instruction it contains without UnknownOpcode. Run for enough
// steps to cover all five `pN` functions plus the bottom `jmp _start`
// and check we collected a few iterations of "1 2 3 4 5\n" on
// stdout. This would have caught a regression where the source-
// rebuild emitted `EB rel8` (short jmp) instead of `E9 rel32`, which
// the movie86 decoder doesn't accept.
try {
    const elf = new Uint8Array(await readFile(`${root}/examples/cycle.elf`));
    const vm = new mod.Vm(elf);
    try {
        // Each iteration is 5 prints + a jmp; ~80 instructions covers
        // a handful of full cycles. Drain stdout periodically so we
        // don't overflow the buffer between checks.
        let stdout = new Uint8Array(0);
        for (let i = 0; i < 5; i++) {
            vm.stepN(200n);
            const chunk = vm.drainStdout();
            if (chunk.length) {
                const merged = new Uint8Array(stdout.length + chunk.length);
                merged.set(stdout); merged.set(chunk, stdout.length);
                stdout = merged;
            }
            assert.equal(vm.haltReason, undefined,
                `cycle halted unexpectedly after batch ${i}: ${vm.haltReason}`);
        }
        const text = new TextDecoder().decode(stdout);
        // Expect at least two full "1 2 3 4 5\n" iterations to have
        // landed by now.
        const matches = text.match(/1 2 3 4 5\n/g) || [];
        assert.ok(matches.length >= 2,
            `expected ≥2 iterations of "1 2 3 4 5\\n", got ${matches.length}: ${JSON.stringify(text)}`);
        console.log(`ok  cycle (${matches.length} iterations × "1 2 3 4 5\\n")`);
    } finally {
        vm.free();
    }
} catch (e) {
    console.error(`FAIL cycle decode coverage: ${e.stack || e.message}`);
    failed++;
}

// --- Vm round-trip: snapshot → mutate → restore ---
//
// `wrapper.snapshotContext(vm)` + `wrapper.loadContextInto(vm, ctx)`
// is the symmetry that lets the demo round-trip back from turbo86:
// `Paused` arrives with a Context, the user clicks Restore, and the
// local Vm absorbs that state to resume execution. Pin both
// directions here: capture a snapshot, perturb the Vm by stepping
// past it, then restore and verify the perturbations are gone.
try {
    const elf = new Uint8Array(await readFile(`${root}/examples/return42.elf`));
    const vm = new mod.Vm(elf);
    try {
        // Snapshot at entry: EIP = ELF entry, regs all zero, code
        // bytes already in mapped memory.
        const entryCtx = wrapper.snapshotContext(vm);
        const entryEip = vm.eip;
        const entryEbx = vm.regs[3];  // EBX index in Reg32 order

        // Step past `mov ebx, 42; mov eax, 1` so EBX changes and
        // EIP advances 10 bytes (two 5-byte mov-imm32 instructions).
        vm.stepN(2n);
        assert.equal(vm.regs[3], 42, 'EBX should be 42 after first mov');
        assert.notEqual(vm.eip, entryEip, 'EIP should have advanced');

        // Restore from the entry snapshot: regs + memory back to what
        // they were before the steps. EBX must be back to its
        // pre-step value (typically 0), EIP back to entry.
        const summary = wrapper.loadContextInto(vm, entryCtx);
        assert.equal(vm.eip, entryEip,
            `restored EIP ${vm.eip.toString(16)} != entry ${entryEip.toString(16)}`);
        assert.equal(vm.regs[3], entryEbx,
            `restored EBX ${vm.regs[3]} != entry ${entryEbx}`);
        assert.ok(summary.applied >= 1, 'expected at least one region applied');

        // After restore, stepping should reproduce the original
        // behavior — re-run the program from entry, expect Exit(42).
        while (!vm.haltReason) vm.stepN(100n);
        assert.equal(vm.exitCode, 42,
            `re-executed after restore: exit ${vm.exitCode} != 42`);

        console.log('ok  Vm round-trip (snapshot → mutate → restore → reexecute)');
    } finally {
        vm.free();
    }
} catch (e) {
    console.error(`FAIL Vm round-trip: ${e.stack || e.message}`);
    failed++;
}

// --- Lossy restore: regions outside mapped memory are skipped ---
//
// turbo86's Paused snapshot may include a stack region (0x70000000+)
// that movie86's much smaller FlatMemory can't fit. The restore must
// skip those regions instead of erroring — the summary's `skipped`
// count is what the UI uses to surface this to the user. Build a
// synthetic Context with one in-range region and one wildly out-of-
// range region; verify the in-range one lands and the other is
// counted as skipped.
try {
    const elf = new Uint8Array(await readFile(`${root}/examples/return42.elf`));
    const vm = new mod.Vm(elf);
    try {
        const fakeCtx = {
            regs: {
                eax: 0xAAAA_AAAA, ebx: 0xBBBB_BBBB, ecx: 0, edx: 0,
                esi: 0, edi: 0, ebp: 0, esp: vm.regs[4],
                eip: vm.eip, eflags: 0,
            },
            regions: [
                // In-range — should land.
                { addr: vm.eip, bytes: new Uint8Array([0xCD, 0x80]) },
                // Out-of-range — should be skipped.
                { addr: 0x7000_0000, bytes: new Uint8Array([0x12, 0x34]) },
            ],
        };
        const summary = wrapper.loadContextInto(vm, fakeCtx);
        assert.equal(summary.applied, 1, `expected 1 applied, got ${summary.applied}`);
        assert.equal(summary.skipped, 1, `expected 1 skipped, got ${summary.skipped}`);
        assert.equal(vm.regs[0], 0xAAAA_AAAA, 'EAX should be loaded');
        // Verify the in-range bytes actually landed at EIP.
        const at = vm.readMem(vm.eip, 2);
        assert.deepEqual(Array.from(at), [0xCD, 0x80],
            'in-range region bytes should have replaced the code');
        console.log('ok  Vm loadContext skips out-of-range regions');
    } finally {
        vm.free();
    }
} catch (e) {
    console.error(`FAIL Vm loadContext lossy restore: ${e.stack || e.message}`);
    failed++;
}

if (failed > 0) {
    console.error(`${failed} smoke test(s) failed`);
    process.exit(1);
}
console.log('all smoke tests passed');
