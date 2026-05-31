// rustc-host-driver.mjs
//
// Drives the *host* `rustc` (whatever's on $PATH or pointed at by
// `opts.rustc`) as a subprocess and returns LLVM IR text. The sibling
// `rustc-driver.mjs` drives a wasm-hosted rustc through wasmtime; this
// one trades "everything in wasm" for "works today, with the host's
// rustup target add" — useful as the explorer's Rust-frontend bypass
// while the in-wasm rustc story is still pending an i686-aware artefact
// (see ../CLAUDE.md "Rust frontend (in progress)" §).
//
// Node-only by construction (subprocess + filesystem). A browser-side
// driver would need a server endpoint or a wasm rustc — neither is in
// scope here.

import { spawn } from 'node:child_process';
import { promises as fsp } from 'node:fs';
import { tmpdir } from 'node:os';
import path from 'node:path';

export async function rsHostToIRImpl(source, opts) {
    const rustc = opts.rustc ?? process.env.RUSTC ?? 'rustc';
    const target = opts.target ?? 'i686-unknown-linux-gnu';
    const edition = opts.edition ?? '2024';
    const crateType = opts.crateType ?? 'lib';
    const optLevel = opts.optLevel ?? '2';

    const runDir = await fsp.mkdtemp(path.join(tmpdir(), 'rs-host-'));
    try {
        // Use a stable basename. rustc bakes the crate name (= file
        // basename minus `.rs`) into the IR's source_filename and into
        // the emitted `<name>.ll` filename, so picking it explicitly
        // makes the output path predictable for the read-back below.
        const stem = (opts.name ?? 'in.rs').replace(/\.rs$/, '');
        const srcPath = path.join(runDir, `${stem}.rs`);
        await fsp.writeFile(srcPath, source);

        const args = [
            `--edition=${edition}`,
            `--crate-type=${crateType}`,
            `--target=${target}`,
            '--emit=llvm-ir',
            '-C', 'panic=abort',
            '-C', 'overflow-checks=false',
            '-C', `opt-level=${optLevel}`,
            '-C', 'debuginfo=0',
            '-C', 'strip=symbols',
            ...(opts.rustcFlags ?? []),
            srcPath,
            '--out-dir', runDir,
        ];

        opts.onProgress?.({ stage: 'run-host-rustc' });
        const stderrChunks = [];
        await new Promise((resolve, reject) => {
            const child = spawn(rustc, args, { stdio: ['ignore', 'pipe', 'pipe'] });
            child.on('error', reject);
            child.stdout.on('data', () => {});                // silence
            child.stderr.on('data', (d) => stderrChunks.push(d));
            child.on('exit', (code) => {
                const stderr = Buffer.concat(stderrChunks).toString('utf8');
                if (code !== 0) {
                    reject(new Error(
                        `host rustc exited ${code} (target=${target}, edition=${edition}):\n${stderr}`,
                    ));
                } else {
                    resolve();
                }
            });
        });

        const llPath = path.join(runDir, `${stem}.ll`);
        return await fsp.readFile(llPath, 'utf8');
    } finally {
        await fsp.rm(runDir, { recursive: true, force: true }).catch(() => {});
    }
}
