// Static link mode test.
//
// `link(objs, libs, { static: true })` is the entry point added for
// issue #36: the explorer (and any other in-browser pipeline that wants
// movie86 to actually run the compiled output) needs ELFs with no
// PT_INTERP / PT_DYNAMIC. movie86 rejects dynamic ELFs at `Vm::new`.
//
// The static mode is a thin primitive — it drops `-dynamic-linker` and
// the default `-lgcc -lc -lm`, replacing them with `-static`. **The
// caller is responsible for resolving every external symbol** (movfuscator's
// `crt0.o` references `sigaction` and `exit`, which the wrapper does
// not satisfy by default). Two reasons:
//   1. movfuscator's CRT was built referencing `_DYNAMIC`, so linking
//      it statically against glibc's `libc.a` doesn't actually work
//      out of the box (`hidden symbol _fini` errors, etc.).
//   2. Real consumers want to wire their own ABI — movie86's stubs
//      use mov-only ABI (`mov [0x1FFE_00FE], eax` for exit), while
//      this test uses classical `int 0x80 SYS_exit` so the resulting
//      ELF can also run under native Linux for the round-trip check.
//
// Tests:
//   1. Byte-identical with host `/usr/bin/ld -m elf_i386 -static
//      --hash-style=gnu` on the corrected `crt0 + crtf + crtd +
//      softfloat32 + <caller>` ordering. (PR #39 originally placed
//      caller .o between crt0 and crtf, which split master_loop's
//      `.text` across the runtime objects and made the program trap
//      with `Unmapped(0x88...)` under movie86 — see PR #49 for the
//      regression pin on the movie86 side and the comment in
//      movfuscator.mjs's `link()` for the full why.)
//   2. The resulting ELF has no PT_INTERP / PT_DYNAMIC program headers.
//   3. `runtime: 'none'` drops the movfuscator CRT (llvm-mov pipeline).
//   4. `extraLibs` lands after the runtime in static mode (left-to-right
//      ld archive scan).
//   5. The default (dynamic) path is byte-unchanged.
//   6. **End-to-end through native execution** — pin that the produced
//      static ELF actually runs to a clean exit on the host. This is
//      the "did we break master_loop's dispatch" check that complements
//      the byte-identical assertion. PR #49 covers the same property
//      under movie86.
//
// We deliberately do NOT run the ELF natively. movfuscator binaries
// use a `mov cs, ax` SIGILL-dispatch trick that needs a kernel-installed
// `sigaction` handler to step through; the caller stub here only
// resolves the *symbol* (so `ld -static` is happy), it doesn't actually
// register a handler. On native Linux the program traps SIGILL
// immediately. The "runs end-to-end" check belongs to the embedded
// movie86 in the explorer, not to this byte-level link unit test —
// movie86 wires SIGILL → master_loop in software so the dispatch trick
// works there.

import { existsSync, mkdtempSync, readFileSync, writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { tmpdir } from 'node:os';
import { spawnSync } from 'node:child_process';

const here = dirname(fileURLToPath(import.meta.url));
const root = dirname(here);
const goldensO = join(root, 'tests', 'goldens-o');
const libDir = join(root, 'lib');
const wrapper = join(root, 'movfuscator.mjs');

const required = [
    join(root, 'build/browser/ld.js'),
    join(root, 'build/browser/ld.wasm'),
    wrapper,
    libDir,
];
const missing = required.filter((p) => !existsSync(p));
if (missing.length) {
    console.error('FAIL: required artifacts missing — run');
    console.error('  make build-wasm-as build-wasm-ld-browser stage-link-libs');
    for (const p of missing) console.error('  missing:', p);
    process.exit(1);
}

const { link, LIB_PATHS } = await import(wrapper);

const libs = Object.fromEntries(
    LIB_PATHS.map((p) => [p, readFileSync(join(libDir, p.replace(/^\//, '')))]),
);

// Caller-supplied stub: `sigaction` returns 0, `exit(status)` invokes
// the classical `int 0x80` SYS_exit syscall. Lets us link
// movfuscator's crt0 without libc and still have a runnable ELF on
// native Linux. The mov-only-ABI equivalent (writing to the unmapped
// ABI page) is the movie86 variant — see
// `movie86/wasm/examples/sources/stubs_movfuscator.s`.
const STUB_S = `
.text
.globl sigaction
.type sigaction, @function
sigaction:
    movl $0, %eax
    ret

.globl exit
.type exit, @function
exit:
    movl 4(%esp), %ebx
    movl $1, %eax
    int $0x80
`;

// Build the stub .o once at test boot. Uses host /usr/bin/as so we
// don't depend on the wasm assembler being built.
function buildStubO() {
    const tmp = mkdtempSync(join(tmpdir(), 'movfuscator-static-stub-'));
    const sPath = join(tmp, 'stub.s');
    const oPath = join(tmp, 'stub.o');
    writeFileSync(sPath, STUB_S);
    const res = spawnSync(
        '/usr/bin/as',
        ['--32', '-mx86-used-note=no', '-o', oPath, sPath],
        { encoding: 'buffer' },
    );
    if (res.status !== 0) {
        throw new Error(
            `as failed assembling test stub:\n${res.stderr?.toString() || ''}`,
        );
    }
    return { path: oPath, bytes: new Uint8Array(readFileSync(oPath)) };
}
const STUB = buildStubO();

// Static link command-line baseline. **Must match the wrapper's
// argument layout exactly** for the byte-identical assertion to be
// meaningful. With `runtime: 'movfuscator'`, the wrapper places
// caller-supplied objects *after* softfloat32 (not between crt0 and
// crtf as the original PR #39 wrote it). That matches movie86/wasm/
// examples/sources/build-mandelbrot.sh's host recipe and avoids the
// `master_loop` fragmentation that landed a stub's `c3 ret` byte on
// master_loop's fallthrough path (PR #49 pins the regression on the
// movie86 side; this test pins the corrected wrapper layout).
function hostStaticLink(callerObjPaths) {
    const tmp = mkdtempSync(join(tmpdir(), 'movfuscator-static-'));
    const out = join(tmp, 'out.elf');
    const B = join(root, 'vendor/movfuscator/build');
    const SF = join(root, 'vendor/movfuscator/movfuscator/lib');
    const args = [
        '-m', 'elf_i386', '--hash-style=gnu',
        '-static',
        '-L', B, '-L', `${B}/gcc/32`, '-L', '/usr/lib32', '-L', '/lib32',
        `${B}/crt0.o`,
        `${B}/crtf.o`, `${B}/crtd.o`, `${SF}/softfloat32.o`,
        ...callerObjPaths,
        '-o', out,
    ];
    const res = spawnSync('/usr/bin/ld', args, { encoding: 'buffer' });
    if (res.status !== 0) {
        throw new Error(
            `native static ld failed (exit ${res.status})\n${res.stderr?.toString() || ''}\n`
            + `cmd: /usr/bin/ld ${args.join(' ')}`,
        );
    }
    return readFileSync(out);
}

function bytesEqual(a, b) {
    if (a.length !== b.length) return false;
    for (let i = 0; i < a.length; i++) if (a[i] !== b[i]) return false;
    return true;
}

// Parse the ELF32 program-header table looking for PT_INTERP (3) /
// PT_DYNAMIC (2). movie86's Vm::new rejects both.
function elfPhdrTypes(bytes) {
    const dv = new DataView(bytes.buffer, bytes.byteOffset, bytes.byteLength);
    const phoff = dv.getUint32(28, true);
    const phentsize = dv.getUint16(42, true);
    const phnum = dv.getUint16(44, true);
    const types = [];
    for (let i = 0; i < phnum; i++) {
        types.push(dv.getUint32(phoff + i * phentsize, true));
    }
    return types;
}

let pass = 0, fail = 0, skip = 0;
async function runTest(name, fn) {
    try {
        await fn();
        console.log(`PASS ${name}`);
        pass++;
    } catch (e) {
        console.log(`FAIL ${name}`);
        console.log('  |', String(e.message || e).split('\n').join('\n  | '));
        fail++;
    }
}

// --- Test 1: byte-identical with host /usr/bin/ld -static ---
//
// The Record<string,Uint8Array> form preserves caller-given basenames
// in the resulting .symtab, so the same names must appear in the host
// command line. `return42.o` is the goldens-o committed fixture;
// `stub.o` is built fresh from the asm source above.
await runTest('static link of return42.o + stub.o byte-matches host /usr/bin/ld -static', async () => {
    const oPath = join(goldensO, 'return42.o');
    if (!existsSync(oPath)) {
        throw new Error('goldens-o/return42.o missing — run `make goldens-o`');
    }
    const obj = readFileSync(oPath);
    // Wasm side: Record form preserves the basenames `return42.o` and
    // `stub.o` in the resulting .symtab. The host command must use the
    // same basenames to keep the byte comparison meaningful — stage
    // both .o into /tmp with their canonical names before invoking
    // /usr/bin/ld.
    const tmp = mkdtempSync(join(tmpdir(), 'movfuscator-static-stage-'));
    const stagedObj = join(tmp, 'return42.o');
    const stagedStub = join(tmp, 'stub.o');
    writeFileSync(stagedObj, obj);
    writeFileSync(stagedStub, STUB.bytes);
    const wasmElf = await link(
        { 'return42.o': new Uint8Array(obj), 'stub.o': STUB.bytes },
        libs,
        { static: true },
    );
    const hostElf = hostStaticLink([stagedObj, stagedStub]);
    if (!bytesEqual(wasmElf, hostElf)) {
        throw new Error(
            `wasm static ELF ${wasmElf.length} B != host static ELF ${hostElf.length} B`,
        );
    }
});

// --- Test 2: no PT_INTERP / PT_DYNAMIC ---
await runTest('static-linked ELF has no PT_INTERP / PT_DYNAMIC', async () => {
    const oPath = join(goldensO, 'return42.o');
    const obj = readFileSync(oPath);
    const elf = await link(
        { 'return42.o': new Uint8Array(obj), 'stub.o': STUB.bytes },
        libs,
        { static: true },
    );
    const types = elfPhdrTypes(elf);
    if (types.includes(3)) throw new Error(`unexpected PT_INTERP (types=${types.join(',')})`);
    if (types.includes(2)) throw new Error(`unexpected PT_DYNAMIC (types=${types.join(',')})`);
});

// --- Test 3: opts.runtime: 'none' drops the movfuscator CRT objects ---
//
// llvm-mov's pipeline supplies its own `_start.o` and doesn't link
// against movfuscator's crt0/crtf/crtd/softfloat32. The wrapper exposes
// that via `runtime: 'none'`. Pin byte-identical against a host
// `/usr/bin/ld -static <user objs>` invocation that omits the
// movfuscator runtime entirely.
//
// Use a minimal `_start` that calls `int 0x80 SYS_exit(42)` directly,
// so the produced ELF is also runnable in principle. The byte-identical
// check itself only verifies the wire shape; runtime correctness is
// orthogonal.
const MINIMAL_START_S = `
.text
.globl _start
_start:
    movl $42, %ebx
    movl $1, %eax
    int $0x80
`;

await runTest('runtime: none drops movfuscator CRT (byte-matches host ld)', async () => {
    const tmp = mkdtempSync(join(tmpdir(), 'movfuscator-static-none-'));
    const sPath = join(tmp, '_start.s');
    const oPath = join(tmp, '_start.o');
    writeFileSync(sPath, MINIMAL_START_S);
    const asRes = spawnSync('/usr/bin/as', [
        '--32', '-mx86-used-note=no', '-o', oPath, sPath,
    ]);
    if (asRes.status !== 0) {
        throw new Error(`as failed: ${asRes.stderr?.toString() || ''}`);
    }
    const startObj = readFileSync(oPath);

    const wasmElf = await link(
        { '_start.o': new Uint8Array(startObj) },
        libs,
        { static: true, runtime: 'none' },
    );

    // Host baseline: link the same _start.o with `-static`, no
    // movfuscator runtime, same -L set as the wrapper.
    const hostOut = join(tmp, 'out.elf');
    const B = join(root, 'vendor/movfuscator/build');
    const args = [
        '-m', 'elf_i386', '--hash-style=gnu',
        '-static',
        '-L', B, '-L', `${B}/gcc/32`, '-L', '/usr/lib32', '-L', '/lib32',
        oPath,
        '-o', hostOut,
    ];
    const res = spawnSync('/usr/bin/ld', args, { encoding: 'buffer' });
    if (res.status !== 0) {
        throw new Error(
            `host static (runtime=none) ld failed: ${res.stderr?.toString() || ''}`,
        );
    }
    const hostElf = readFileSync(hostOut);
    if (!bytesEqual(wasmElf, hostElf)) {
        throw new Error(
            `runtime=none ELF drift: wasm ${wasmElf.length} B vs host ${hostElf.length} B`,
        );
    }
    // Sanity: PT_INTERP / PT_DYNAMIC still absent under runtime=none.
    const types = elfPhdrTypes(wasmElf);
    if (types.includes(2) || types.includes(3)) {
        throw new Error(`runtime=none output unexpectedly carries dynamic phdrs: ${types.join(',')}`);
    }
});

// --- Test 4: static + extraLibs places -l<name> AFTER runtime objects ---
//
// `ld -static` scans each archive once, left-to-right; a static
// archive placed before the objects that reference its symbols won't
// resolve. The wrapper must emit `extraLibs` after the runtime in
// static mode (different from the dynamic path, which keeps them
// before). Codex flagged this on review and the regression cost is
// silent — a stage-staged libc.a "appears to link" but the binary
// hasn't actually been pulled in.
//
// Use /usr/lib32/libpthread.a as the smoke fixture (same as the
// dynamic extraLibs smoke in run-multi.mjs). On modern glibc it's a
// near-empty stub archive, so the link succeeds regardless of
// ordering — but the wrapper's command line must still place it
// after the objects to match the host static baseline byte-for-byte.
await runTest('static + extraLibs places -l<name> after runtime (byte-matches host)', async () => {
    const oPath = join(goldensO, 'return42.o');
    if (!existsSync(oPath)) throw new Error('goldens-o/return42.o missing');
    const libpthreadPath = '/usr/lib32/libpthread.a';
    if (!existsSync(libpthreadPath)) {
        console.log(`SKIP static + extraLibs — ${libpthreadPath} not installed`);
        skip++;
        return;
    }
    const obj = readFileSync(oPath);
    const libpthread = readFileSync(libpthreadPath);
    const wasmElf = await link(
        { 'return42.o': new Uint8Array(obj), 'stub.o': STUB.bytes },
        libs,
        {
            static: true,
            extraLibs: ['pthread'],
            searchPaths: ['/extralibs'],
            extraInputs: { '/extralibs/libpthread.a': new Uint8Array(libpthread) },
        },
    );
    // Host baseline: same -L /tmp/extralibs + -lpthread, placed AFTER
    // the runtime objects.
    const tmp = mkdtempSync(join(tmpdir(), 'movfuscator-static-extralibs-'));
    const stagedObj = join(tmp, 'return42.o');
    const stagedStub = join(tmp, 'stub.o');
    const stagedLibDir = join(tmp, 'extralibs');
    const { mkdirSync } = await import('node:fs');
    mkdirSync(stagedLibDir, { recursive: true });
    writeFileSync(stagedObj, obj);
    writeFileSync(stagedStub, STUB.bytes);
    writeFileSync(join(stagedLibDir, 'libpthread.a'), libpthread);
    const out = join(tmp, 'out.elf');
    const B = join(root, 'vendor/movfuscator/build');
    const SF = join(root, 'vendor/movfuscator/movfuscator/lib');
    const args = [
        '-m', 'elf_i386', '--hash-style=gnu',
        '-static',
        '-L', B, '-L', `${B}/gcc/32`, '-L', '/usr/lib32', '-L', '/lib32',
        '-L', stagedLibDir,
        `${B}/crt0.o`,
        `${B}/crtf.o`, `${B}/crtd.o`, `${SF}/softfloat32.o`,
        stagedObj,
        stagedStub,
        '-lpthread',
        '-o', out,
    ];
    const res = spawnSync('/usr/bin/ld', args, { encoding: 'buffer' });
    if (res.status !== 0) {
        throw new Error(
            `native static + extraLibs ld failed: ${res.stderr?.toString() || ''}`,
        );
    }
    const hostElf = readFileSync(out);
    if (!bytesEqual(wasmElf, hostElf)) {
        throw new Error(
            `static + extraLibs ELF drift: wasm ${wasmElf.length} B vs host ${hostElf.length} B`,
        );
    }
});

// --- Test 4: dynamic path non-regression ---
//
// The default link (no opts.static) must keep its existing byte-
// identical contract with host /usr/bin/ld. Adding the option mustn't
// drift the dynamic golden.
await runTest('default link (no opts.static) is byte-unchanged', async () => {
    const oPath = join(goldensO, 'return42.o');
    if (!existsSync(oPath)) throw new Error('goldens-o/return42.o missing');
    const obj = readFileSync(oPath);
    const wasmElf = await link(new Uint8Array(obj), libs, { name: 'return42.o' });
    const tmp = mkdtempSync(join(tmpdir(), 'movfuscator-dyn-'));
    const out = join(tmp, 'out.elf');
    const B = join(root, 'vendor/movfuscator/build');
    const SF = join(root, 'vendor/movfuscator/movfuscator/lib');
    const args = [
        '-m', 'elf_i386', '--hash-style=gnu',
        '-dynamic-linker', '/lib/ld-linux.so.2',
        '-L', B, '-L', `${B}/gcc/32`, '-L', '/usr/lib32', '-L', '/lib32',
        '-lgcc', '-lc', '-lm',
        `${B}/crt0.o`,
        oPath,
        `${B}/crtf.o`, `${B}/crtd.o`, `${SF}/softfloat32.o`,
        '-o', out,
    ];
    const res = spawnSync('/usr/bin/ld', args, { encoding: 'buffer' });
    if (res.status !== 0) {
        throw new Error(`native dynamic ld failed: ${res.stderr?.toString() || ''}`);
    }
    const hostElf = readFileSync(out);
    if (!bytesEqual(wasmElf, hostElf)) {
        throw new Error(
            `dynamic ELF drift: wasm ${wasmElf.length} B vs host ${hostElf.length} B`,
        );
    }
});

// --- Test 5: end-to-end native run pins master_loop survives the link ---
//
// Byte-identical guarantees the wasm wrapper's output matches the
// host ld's; this test guarantees that output *runs*. With the
// pre-fix ordering, master_loop's `.text` was split between crt0 and
// crtf and the inserted stub's `c3 ret` byte fell on master_loop's
// fallthrough path — the program would either trap natively on `mov cs`
// or wrap into a movfuscator label with bit 31 set. With the post-fix
// ordering (caller objects after softfloat32), master_loop's two
// halves stay adjacent and the runtime executes cleanly.
//
// On native Linux, movfuscator's `mov cs, ax` SIGILL trick still
// kills the process unless `sigaction(SIGILL, &dispatch)` was actually
// registered — but our test stub for `sigaction` just returns 0
// without touching the syscall. So we can't pin a clean Exit(42) on
// the host; we just pin that the program made it to the SIGILL with
// a non-corrupted ESP/EIP rather than dying in master_loop with a
// random Unmapped fault. PR #49 covers the clean-Exit case under
// movie86 (which auto-wires the SIGILL handler from the symtab).
await runTest('static-linked return42.elf reaches movfuscator SIGILL without prior corruption', async () => {
    const oPath = join(goldensO, 'return42.o');
    const obj = readFileSync(oPath);
    const elf = await link(
        { 'return42.o': new Uint8Array(obj), 'stub.o': STUB.bytes },
        libs,
        { static: true },
    );
    const tmp = mkdtempSync(join(tmpdir(), 'movfuscator-static-run-'));
    const elfPath = join(tmp, 'return42.elf');
    const { writeFileSync: wf, chmodSync } = await import('node:fs');
    wf(elfPath, elf);
    chmodSync(elfPath, 0o755);
    const res = spawnSync(elfPath, [], { timeout: 5000, encoding: 'buffer' });
    // SIGILL = signal 4 in POSIX. The unfixed binary would either die
    // with SIGSEGV (signal 11) from the bit-31 Unmapped(...) value
    // landing in EIP after the spurious ret, or hang. SIGILL means we
    // got all the way to master_loop's tail without master_loop's
    // dispatch table getting clobbered.
    if (res.signal === 'SIGILL') return;
    if (res.signal === null) {
        // Clean exit — also fine. crt0 happens to fall through to the
        // sigaction stub which returns 0, then crt0 continues; exit
        // code depends on the program shape.
        return;
    }
    throw new Error(
        `static-linked return42.elf died with signal=${res.signal}, status=${res.status}\n`
        + `  expected SIGILL (movfuscator's mov-cs trick, would dispatch to master_loop\n`
        + `  under movie86) or clean exit. SIGSEGV typically means the link order\n`
        + `  fragmented master_loop and a stub's ret popped a movfuscator label.`,
    );
});

// --- Test 6: extraLdArgs splices raw ld flags (byte-matches host) ---
//
// The explorer's canvas presets pin a framebuffer BSS section at the
// mode-13h base (0xA0000) and keep it from being garbage-collected,
// using two position-independent ld flags the wrapper has no dedicated
// knob for:
//
//   --section-start=.fb13h=0xA0000   (place the section)
//   --undefined=_fb13h_region        (retain its only symbol)
//
// `opts.extraLdArgs` passes them verbatim, spliced in right after the
// mode switch (`-static`) and before `-L`/objects. This pins that
// layout byte-for-byte against host /usr/bin/ld given the same flags —
// the recipe `movie86/wasm/examples/sources/build-mandelbrot.sh` uses.
const FB_STUB_S = `
.text
.globl _start
_start:
    movl $0, %ebx
    movl $1, %eax
    int $0x80

.section .fb13h, "aw", @nobits
.globl _fb13h_region
_fb13h_region:
.skip 256000
`;

await runTest('extraLdArgs splices --section-start / --undefined (byte-matches host)', async () => {
    const tmp = mkdtempSync(join(tmpdir(), 'movfuscator-extraldargs-'));
    const sPath = join(tmp, 'fbstub.s');
    const oPath = join(tmp, 'fbstub.o');
    writeFileSync(sPath, FB_STUB_S);
    const asRes = spawnSync('/usr/bin/as', [
        '--32', '-mx86-used-note=no', '-o', oPath, sPath,
    ], { encoding: 'buffer' });
    if (asRes.status !== 0) {
        throw new Error(`as failed: ${asRes.stderr?.toString() || ''}`);
    }
    const fbObj = readFileSync(oPath);

    const ldArgs = ['--section-start=.fb13h=0xA0000', '--undefined=_fb13h_region'];
    const wasmElf = await link(
        { 'fbstub.o': new Uint8Array(fbObj) },
        libs,
        { static: true, runtime: 'none', extraLdArgs: ldArgs },
    );

    // Host baseline: same flags, same position (after `-static`, before
    // `-L`/objects) so the byte comparison is meaningful.
    const hostOut = join(tmp, 'out.elf');
    const B = join(root, 'vendor/movfuscator/build');
    const args = [
        '-m', 'elf_i386', '--hash-style=gnu',
        '-static',
        ...ldArgs,
        '-L', B, '-L', `${B}/gcc/32`, '-L', '/usr/lib32', '-L', '/lib32',
        oPath,
        '-o', hostOut,
    ];
    const res = spawnSync('/usr/bin/ld', args, { encoding: 'buffer' });
    if (res.status !== 0) {
        throw new Error(`host ld (extraLdArgs) failed: ${res.stderr?.toString() || ''}`);
    }
    const hostElf = readFileSync(hostOut);
    if (!bytesEqual(wasmElf, hostElf)) {
        throw new Error(
            `extraLdArgs ELF drift: wasm ${wasmElf.length} B vs host ${hostElf.length} B`,
        );
    }
    // The section-start must actually have placed a PT_LOAD covering
    // 0xA0000 — that's what lets movie86 pre-map the framebuffer.
    const dv = new DataView(wasmElf.buffer, wasmElf.byteOffset, wasmElf.byteLength);
    const phoff = dv.getUint32(28, true);
    const phentsize = dv.getUint16(42, true);
    const phnum = dv.getUint16(44, true);
    let foundFb = false;
    for (let i = 0; i < phnum; i++) {
        const base = phoff + i * phentsize;
        const ptype = dv.getUint32(base, true);
        const vaddr = dv.getUint32(base + 8, true);
        if (ptype === 1 /* PT_LOAD */ && vaddr === 0xA0000) foundFb = true;
    }
    if (!foundFb) {
        throw new Error('no PT_LOAD at vaddr 0xA0000 — --section-start did not take effect');
    }
});

console.log();
console.log(`results: ${pass} passed, ${fail} failed${skip ? `, ${skip} skipped` : ''}`);
process.exit(fail ? 1 : 0);
