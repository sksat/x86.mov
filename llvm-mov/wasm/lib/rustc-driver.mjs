// rustc-driver.mjs
//
// Drives a wasm-hosted rustc artefact via the `wasmtime` CLI (Node
// mode; the browser-side driver will live next to this file once
// the explorer integration starts). The caller (`rsToIR` in
// ../llvm-mov.mjs) passes the `spec` row from `RUSTC_VERSIONS` so
// this module stays agnostic about which Rust version is in use.
//
// Cache layout: build/rustc-cache/<versionKey>/dist/
//   bin/rustc.wasm                          ← decompressed rustc.wasm
//   lib/rustlib/<target>/lib/*.rlib …       ← per-target sysroot
//   .complete-rustc                          ← idempotency marker
//   .complete-sysroot-<target>               ← idempotency marker
//
// Invocation pattern (matches what we proved on the CLI):
//
//   wasmtime run \
//     -S threads=y -S preview2=n -W threads=y -W shared-memory=y \
//     --dir tmp::/ --dir dist \
//     --env RUST_MIN_STACK=16777216 \
//     dist/bin/rustc.wasm \
//     --sysroot=dist - --target=<triple> --edition=<edition> \
//     --crate-type=lib --emit=llvm-ir --out-dir=/tmp \
//     [-C opt-level=<lvl>] [-C codegen-units=1]
//
// rustc reads the source from stdin (`-`) and emits `rust_out.ll`
// into /tmp (which is the host run dir mounted at guest /). We then
// read that file and return its contents.
//
// wasmtime path resolution: PATH first, then ~/.local/wasmtime, then
// throw a clear "install wasmtime" message.

import { spawn } from 'node:child_process';
import { createWriteStream } from 'node:fs';
import { promises as fsp } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { pipeline } from 'node:stream/promises';
import { Readable } from 'node:stream';
import zlib from 'node:zlib';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const WASM_ROOT = path.resolve(__dirname, '..');
const CACHE_ROOT = path.join(WASM_ROOT, 'build', 'rustc-cache');

async function exists(p) {
    try { await fsp.stat(p); return true; }
    catch { return false; }
}

// In-process dedup for cold-cache artefact preparation. Two concurrent
// `rsToIR()` calls on the same versionKey would otherwise both kick
// off the same fetch (wasting bandwidth at best; race-renaming the
// same .tmp file at worst). Keying by absolute marker path lets us
// share the single Promise for as long as it's in flight; the entry
// drops on settle so the next cold start can retry on failure.
const _inFlight = new Map();
function once(key, fn) {
    const pending = _inFlight.get(key);
    if (pending) return pending;
    const p = (async () => fn())().finally(() => {
        if (_inFlight.get(key) === p) _inFlight.delete(key);
    });
    _inFlight.set(key, p);
    return p;
}

// Per-process unique suffix for the staging .tmp file. Even across
// processes (e.g. two `make test-rust` runs sharing the same cache),
// each writes to its own staging path; the final rename is the only
// shared step, and POSIX rename is atomic.
function stagingPath(destPath) {
    const suffix = `${process.pid}.${(Math.random() * 0xffffffff) | 0}`;
    return `${destPath}.${suffix}.tmp`;
}

// Locate wasmtime. PATH wins; fall back to the user-local install
// location at ~/.local/wasmtime/ (where our README's setup instructions
// place it).
async function resolveWasmtime() {
    const fromEnv = process.env.WASMTIME;
    if (fromEnv && await exists(fromEnv)) return fromEnv;
    // PATH probe — spawn a no-op to see if it resolves.
    const onPath = await new Promise((resolve) => {
        const p = spawn('wasmtime', ['--version'], { stdio: 'ignore' });
        p.on('error', () => resolve(null));
        p.on('exit', (code) => resolve(code === 0 ? 'wasmtime' : null));
    });
    if (onPath) return onPath;
    const userLocal = path.join(process.env.HOME ?? '', '.local', 'wasmtime', 'wasmtime');
    if (await exists(userLocal)) return userLocal;
    throw new Error(
        'wasmtime not found (looked in $PATH and ~/.local/wasmtime/). ' +
        'Install: gh release download --repo bytecodealliance/wasmtime ' +
        "--pattern '*x86_64-linux.tar.xz', extract to ~/.local/wasmtime/, " +
        'or set $WASMTIME to the binary path.',
    );
}

// Decompress brotli stream → file at destPath, atomically via a per-PID
// random-suffixed *.tmp rename. Concurrent callers in the same process
// are dedup'd one layer up via `once()`; concurrent callers in
// *different* processes each write to their own staging path and the
// final rename picks a winner (POSIX rename is atomic, so the file at
// destPath is always intact).
async function downloadAndDecompressBrotli(url, destPath) {
    await fsp.mkdir(path.dirname(destPath), { recursive: true });
    const res = await fetch(url);
    if (!res.ok) throw new Error(`fetch ${url}: ${res.status} ${res.statusText}`);
    const tmpPath = stagingPath(destPath);
    try {
        await pipeline(
            Readable.fromWeb(res.body),
            zlib.createBrotliDecompress(),
            createWriteStream(tmpPath),
        );
        await fsp.rename(tmpPath, destPath);
    } catch (e) {
        await fsp.unlink(tmpPath).catch(() => {});
        throw e;
    }
}

// Stream brotli-decompress → tar -x into destDir. Uses the system `tar`
// (no npm dep). The sysroot tarballs from rust_wasm/v0.2.0/ are flat —
// just .rlib files + a self-contained/ subdir at the top level — so we
// extract them into <destDir>/lib/rustlib/<target>/lib/ so the resulting
// tree matches what `rustc --sysroot=<root>` walks.
async function downloadAndExtractSysroot(url, destDir, target) {
    const targetLibDir = path.join(destDir, 'lib', 'rustlib', target, 'lib');
    await fsp.mkdir(targetLibDir, { recursive: true });
    const res = await fetch(url);
    if (!res.ok) throw new Error(`fetch ${url}: ${res.status} ${res.statusText}`);
    await new Promise((resolve, reject) => {
        const tar = spawn('tar', ['x'], { cwd: targetLibDir, stdio: ['pipe', 'inherit', 'inherit'] });
        tar.on('error', reject);
        tar.on('exit', (code) => code === 0 ? resolve() : reject(new Error(`tar exited ${code}`)));
        const br = zlib.createBrotliDecompress();
        br.pipe(tar.stdin);
        br.on('error', reject);
        Readable.fromWeb(res.body).pipe(br);
    });
}

// Local artefacts (e.g. self-built rustc from scripts/build-wasm-rustc.sh)
// short-circuit the fetch path: the script is the only thing that's
// allowed to populate them, and missing files mean the script hasn't
// run yet. We surface that as an actionable error instead of trying
// to download a placeholder URL.
function missingLocalArtefact(versionKey, what, expectedPath) {
    return new Error(
        `local artefact missing for rustcVersion=${versionKey}: ` +
        `${what} not found at ${expectedPath}. ` +
        `Run scripts/build-wasm-rustc.sh (multi-hour build; see ` +
        `../CLAUDE.md "Self-hosted artefact" §) to populate it.`,
    );
}

async function ensureRustcWasm(versionDir, artefacts, versionKey, onProgress) {
    const marker = path.join(versionDir, '.complete-rustc');
    if (await exists(marker)) return;
    if (artefacts.local) {
        const wasmPath = path.join(versionDir, 'dist', 'bin', 'rustc.wasm');
        if (!(await exists(wasmPath))) {
            throw missingLocalArtefact(versionKey, 'rustc.wasm', wasmPath);
        }
        await fsp.writeFile(marker, '');
        return;
    }
    await once(`rustc:${marker}`, async () => {
        // Re-check after potentially awaiting another in-flight call —
        // the dedup'd peer may have completed the work for us.
        if (await exists(marker)) return;
        onProgress?.({ stage: 'fetch-rustc' });
        const wasmPath = path.join(versionDir, 'dist', 'bin', 'rustc.wasm');
        await downloadAndDecompressBrotli(artefacts.rustcWasm, wasmPath);
        await fsp.writeFile(marker, '');
    });
}

async function ensureSysroot(versionDir, artefacts, target, versionKey, onProgress) {
    const marker = path.join(versionDir, `.complete-sysroot-${target}`);
    if (await exists(marker)) return;
    if (artefacts.local) {
        const sysrootDir = path.join(versionDir, 'dist', 'lib', 'rustlib', target, 'lib');
        if (!(await exists(sysrootDir))) {
            throw missingLocalArtefact(versionKey, `sysroot for ${target}`, sysrootDir);
        }
        await fsp.writeFile(marker, '');
        return;
    }
    await once(`sysroot:${marker}`, async () => {
        if (await exists(marker)) return;
        onProgress?.({ stage: 'fetch-sysroot' });
        const url = `${artefacts.sysrootBase}/${target}.tar.br`;
        await downloadAndExtractSysroot(url, path.join(versionDir, 'dist'), target);
        await fsp.writeFile(marker, '');
    });
}

function runWasmtime(wasmtime, versionDir, runDir, args, source) {
    return new Promise((resolve, reject) => {
        const wasmtimeArgs = [
            'run',
            '-S', 'threads=y',
            '-S', 'preview2=n',
            '-W', 'threads=y',
            '-W', 'shared-memory=y',
            '--dir', `${runDir}::/`,
            '--dir', 'dist',
            '--env', 'RUST_MIN_STACK=16777216',
            'dist/bin/rustc.wasm',
            ...args,
        ];
        const stderrChunks = [];
        const child = spawn(wasmtime, wasmtimeArgs, {
            cwd: versionDir,
            stdio: ['pipe', 'pipe', 'pipe'],
        });
        child.on('error', reject);
        child.stdout.on('data', () => {});           // discard rustc stdout (status only)
        child.stderr.on('data', (d) => stderrChunks.push(d));
        child.on('exit', (code) => {
            const stderr = Buffer.concat(stderrChunks).toString('utf8');
            if (code !== 0) {
                reject(new Error(
                    `wasmtime exited ${code} running rustc:\n${stderr}`,
                ));
            } else {
                resolve({ stderr });
            }
        });
        child.stdin.end(source);
    });
}

export async function rsToIRImpl(source, spec, opts) {
    const wasmtime = await resolveWasmtime();
    // `versionKey` is the RUSTC_VERSIONS row key; rsToIR threads it
    // through so the cache layout stays human-inspectable
    // (build/rustc-cache/<versionKey>/) without re-deriving it from
    // the spec.
    const versionKey = opts.versionKey ?? spec.rustVersion;
    const versionDir = path.join(CACHE_ROOT, versionKey);
    await fsp.mkdir(versionDir, { recursive: true });

    await ensureRustcWasm(versionDir, opts.artefacts, versionKey, opts.onProgress);
    await ensureSysroot(versionDir, opts.artefacts, opts.target, versionKey, opts.onProgress);

    // One run dir per invocation: rustc emits `rust_out.ll` into it
    // (via --out-dir=/tmp + tmp::/ mount → host = runDir).
    const runDir = await fsp.mkdtemp(path.join(tmpdir(), 'rustc-wasm-'));
    try {
        opts.onProgress?.({ stage: 'run-rustc' });
        const rustcArgs = [
            '--sysroot=dist',
            '-',                       // source via stdin
            `--target=${opts.target}`,
            `--edition=${opts.edition}`,
            '--crate-type=lib',
            '--emit=llvm-ir',
            // `runDir` is mounted at guest `/`; out-dir = guest /
            // means host file appears directly under runDir/, no
            // subdir gymnastics.
            '--out-dir=/',
            '-C', 'codegen-units=1',
            ...(opts.optLevel ? ['-C', `opt-level=${opts.optLevel}`] : []),
        ];
        await runWasmtime(wasmtime, versionDir, runDir, rustcArgs, source);
        // rustc's default crate-name for stdin input is `rust_out`.
        const llPath = path.join(runDir, 'rust_out.ll');
        return await fsp.readFile(llPath, 'utf8');
    } finally {
        await fsp.rm(runDir, { recursive: true, force: true }).catch(() => {});
    }
}
