// Multi-input link test.
//
// Exercises the link()-with-multiple-objects code path (and, optionally,
// the extraLibs / extraInputs / searchPaths options) added on top of the
// single-object link. The .s and .o stages for each piece are already
// covered byte-identical by tests/run.sh and tests/run-as.sh — this
// runner asserts that the *combined* link's ELF byte-matches the same
// link done with host /usr/bin/ld.
//
// Fixtures live in tests/fixtures/multi-*.c. Each pair (multi-<group>.c
// + multi-<group>-helper.c) is linked together; the .o files come from
// the committed tests/goldens-o/ tree.

import { existsSync, readFileSync, writeFileSync, mkdtempSync, chmodSync } from 'node:fs';
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
const missing = required.filter(p => !existsSync(p));
if (missing.length) {
    console.error('FAIL: required artifacts missing — run');
    console.error('  make build-wasm-as build-wasm-ld-browser stage-link-libs');
    for (const p of missing) console.error('  missing:', p);
    process.exit(1);
}

const { link, LIB_PATHS } = await import(wrapper);

const libs = Object.fromEntries(
    LIB_PATHS.map(p => [p, readFileSync(join(libDir, p.replace(/^\//, '')))])
);

// Native ld baseline: same flags the wrapper's link() uses, but with host
// paths instead of MEMFS ones. Returns the linked ELF as a Buffer.
function hostLink(objPaths, extraArgs = []) {
    const tmp = mkdtempSync(join(tmpdir(), 'movfuscator-multi-'));
    const out = join(tmp, 'out.elf');
    const B  = join(root, 'vendor/movfuscator/build');
    const SF = join(root, 'vendor/movfuscator/movfuscator/lib');
    const args = [
        '-m', 'elf_i386', '--hash-style=gnu',
        '-dynamic-linker', '/lib/ld-linux.so.2',
        '-L', B, '-L', `${B}/gcc/32`, '-L', '/usr/lib32', '-L', '/lib32',
        '-lgcc', '-lc', '-lm',
        ...extraArgs,
        `${B}/crt0.o`,
        ...objPaths,
        `${B}/crtf.o`, `${B}/crtd.o`, `${SF}/softfloat32.o`,
        '-o', out,
    ];
    const res = spawnSync('/usr/bin/ld', args, { encoding: 'buffer' });
    if (res.status !== 0) {
        throw new Error(
            `native ld failed (exit ${res.status})\n${res.stderr?.toString() || ''}\n`
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

let pass = 0, fail = 0, skip = 0;
class SkipTest extends Error { constructor(reason) { super(reason); this.name = 'SkipTest'; } }
async function runTest(name, fn) {
    try {
        await fn();
        console.log(`PASS ${name}`);
        pass++;
    } catch (e) {
        if (e instanceof SkipTest) {
            console.log(`SKIP ${name} — ${e.message}`);
            skip++;
            return;
        }
        console.log(`FAIL ${name}`);
        console.log('  |', String(e.message || e).split('\n').join('\n  | '));
        fail++;
    }
}

// --- Test 1: plain multi-object link, byte-identical vs host /usr/bin/ld ---
await runTest('multi-add (Record<string,Uint8Array>)', async () => {
    const aPath = join(goldensO, 'multi-add.o');
    const bPath = join(goldensO, 'multi-add-helper.o');
    if (!existsSync(aPath) || !existsSync(bPath)) {
        throw new Error('multi-add goldens missing — run `make goldens-o`');
    }
    const a = readFileSync(aPath);
    const b = readFileSync(bPath);
    const wasmElf = await link({
        'multi-add.o': a,
        'multi-add-helper.o': b,
    }, libs);
    const hostElf = hostLink([aPath, bPath]);
    if (!bytesEqual(wasmElf, hostElf)) {
        throw new Error(`wasm ELF ${wasmElf.length} B != host ELF ${hostElf.length} B`);
    }
});

// --- Test 2: array form — same payload, different surface ---
await runTest('multi-add (Uint8Array[])', async () => {
    const aPath = join(goldensO, 'multi-add.o');
    const bPath = join(goldensO, 'multi-add-helper.o');
    const wasmElf = await link(
        [readFileSync(aPath), readFileSync(bPath)],
        libs,
    );
    // Array form synthesizes obj0.o/obj1.o filenames, so symtab differs
    // from the Record form. Re-link host ld with /tmp copies named the
    // same way to keep the byte comparison meaningful.
    const tmp = mkdtempSync(join(tmpdir(), 'movfuscator-multi-arr-'));
    writeFileSync(join(tmp, 'obj0.o'), readFileSync(aPath));
    writeFileSync(join(tmp, 'obj1.o'), readFileSync(bPath));
    const hostElf = hostLink([join(tmp, 'obj0.o'), join(tmp, 'obj1.o')]);
    if (!bytesEqual(wasmElf, hostElf)) {
        throw new Error(`wasm ELF ${wasmElf.length} B != host ELF ${hostElf.length} B`);
    }
});

// --- Test 3: extraLibs + extraInputs + searchPaths smoke ---
// Stage host /usr/lib32/libpthread.a under a caller-chosen MEMFS dir via
// extraInputs, point ld at it via searchPaths, and ask for it via
// extraLibs. On modern glibc libpthread.a is mostly a stub (everything
// moved into libc), so the link still succeeds and produces a
// byte-identical ELF to the same link done with host ld.
await runTest('extraLibs + extraInputs + searchPaths (-lpthread)', async () => {
    const aPath = join(goldensO, 'multi-add.o');
    const bPath = join(goldensO, 'multi-add-helper.o');
    const libpthreadPath = '/usr/lib32/libpthread.a';
    if (!existsSync(libpthreadPath)) throw new SkipTest('/usr/lib32/libpthread.a not installed');
    const libpthread = readFileSync(libpthreadPath);
    const wasmElf = await link({
        'multi-add.o': readFileSync(aPath),
        'multi-add-helper.o': readFileSync(bPath),
    }, libs, {
        extraLibs:   ['pthread'],
        searchPaths: ['/extralibs'],
        extraInputs: { '/extralibs/libpthread.a': new Uint8Array(libpthread) },
    });
    const hostElf = hostLink([aPath, bPath], ['-lpthread']);
    if (!bytesEqual(wasmElf, hostElf)) {
        throw new Error(`wasm ELF ${wasmElf.length} B != host ELF ${hostElf.length} B`);
    }
});

// --- Test 4: compileToElf with Record<string,string> source ---
await runTest('compileToElf (multi-source)', async () => {
    const { compileToElf, parseElfHeader } = await import(wrapper);
    const aSrc = readFileSync(join(root, 'tests/fixtures/multi-add.c'), 'utf8');
    const bSrc = readFileSync(join(root, 'tests/fixtures/multi-add-helper.c'), 'utf8');
    const elf = await compileToElf({
        'multi-add': aSrc,
        'multi-add-helper': bSrc,
    });
    const h = parseElfHeader(elf);
    if (!h || 'raw' in h) throw new Error(`unexpected ELF header: ${JSON.stringify(h)}`);
    if (h.type !== 'EXEC (executable)') throw new Error(`expected EXEC, got ${h.type}`);
    if (h.machine !== 'i386')          throw new Error(`expected i386, got ${h.machine}`);
});

// --- Test 5: compileToElf multi-source produces a runnable ELF ---
//
// Upstream movfuscator has a cross-`.o` ABI bug (issue #9): the caller
// emits a libc-style external call protocol while the callee waits on
// the internal compare protocol, so master_loop deadlocks. The wrapper
// works around that for the multi-source compileToElf path by feeding a
// single TU to the codegen, which keeps every CALL on the internal
// protocol.
//
// Native-execution signal: the program must complete on its own (signal
// === null). Upstream's crt0 exits with the dynamic linker's status —
// typically 1, not main()'s return value — so we don't pin the exact
// exit code, only that the process didn't have to be killed.
await runTest('compileToElf (multi-source) runs natively without hanging', async () => {
    const { compileToElf } = await import(wrapper);
    const aSrc = readFileSync(join(root, 'tests/fixtures/multi-add.c'), 'utf8');
    const bSrc = readFileSync(join(root, 'tests/fixtures/multi-add-helper.c'), 'utf8');
    const elf = await compileToElf({
        'multi-add': aSrc,
        'multi-add-helper': bSrc,
    });
    const tmp = mkdtempSync(join(tmpdir(), 'movfuscator-multi-run-'));
    const elfPath = join(tmp, 'multi-add.elf');
    writeFileSync(elfPath, elf);
    chmodSync(elfPath, 0o755);
    const res = spawnSync(elfPath, [], { timeout: 5000, encoding: 'buffer' });
    if (res.signal !== null) {
        throw new Error(
            `multi-add ELF was killed by ${res.signal} (timed out — cross-.o deadlock?)`
            + `\n  ${elfPath}`,
        );
    }
    if (typeof res.status !== 'number') {
        throw new Error(
            `multi-add ELF did not exit cleanly (status=${res.status}, signal=${res.signal})`
            + `\n  ${elfPath}`,
        );
    }
});

console.log();
console.log(`results: ${pass} passed, ${fail} failed${skip ? `, ${skip} skipped` : ''}`);
process.exit(fail ? 1 : 0);
