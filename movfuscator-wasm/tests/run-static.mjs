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
//      --hash-style=gnu` on the same crt + softfloat32 + caller stub set.
//   2. The resulting ELF has no PT_INTERP / PT_DYNAMIC program headers.
//   3. The default (dynamic) path is byte-unchanged.
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

// Static link command-line baseline. Matches the order
// `crt0.o input.o crtf.o crtd.o softfloat32.o stub.o` from
// `movie86/wasm/examples/sources/build-mandelbrot.sh` — caller-supplied
// stubs come *after* the runtime so they resolve crt0's undefineds.
function hostStaticLink(objPath, stubPath) {
    const tmp = mkdtempSync(join(tmpdir(), 'movfuscator-static-'));
    const out = join(tmp, 'out.elf');
    const B = join(root, 'vendor/movfuscator/build');
    const SF = join(root, 'vendor/movfuscator/movfuscator/lib');
    const args = [
        '-m', 'elf_i386', '--hash-style=gnu',
        '-static',
        '-L', B, '-L', `${B}/gcc/32`, '-L', '/usr/lib32', '-L', '/lib32',
        `${B}/crt0.o`,
        objPath,
        `${B}/crtf.o`, `${B}/crtd.o`, `${SF}/softfloat32.o`,
        stubPath,
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

let pass = 0, fail = 0;
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
    const wasmElf = await link(
        { 'return42.o': new Uint8Array(obj), 'stub.o': STUB.bytes },
        libs,
        { static: true },
    );
    const hostElf = hostStaticLink(oPath, STUB.path);
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

// --- Test 3: dynamic path non-regression ---
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

console.log();
console.log(`results: ${pass} passed, ${fail} failed`);
process.exit(fail ? 1 : 0);
