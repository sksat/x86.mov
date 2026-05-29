// BMP decode benchmark at 16:9 resolutions, wasm vs turbo86 native.
//
// Same shape as png_decode/bench.mjs but the rust crate handles 32bpp
// BMP. Sizes target the standard 16:9 ladder so the table maps onto
// real display resolutions.

import { readFile, writeFile } from 'node:fs/promises';
import { spawn, spawnSync } from 'node:child_process';

const TURBO86_BIN = process.env.TURBO86_BIN;
const BMP_CRATE = process.env.BMP_CRATE;
const WASM_DIR = process.env.MOVIE86_WASM_DIR;

const wasm = await readFile(`${WASM_DIR}/build/browser/movie86_wasm_bg.wasm`);
const mod = await import(`${WASM_DIR}/build/browser/movie86_wasm.js`);
await mod.default({ module_or_path: wasm });
const wrapper = await import(`${WASM_DIR}/movie86.mjs`);

function makeBmp(W, H) {
    const pixelOff = 54;
    const pxSize = W * H * 4;
    const fsize = pixelOff + pxSize;
    const hdrFile = Buffer.alloc(14);
    hdrFile.write('BM', 0);
    hdrFile.writeUInt32LE(fsize, 2);
    hdrFile.writeUInt32LE(pixelOff, 10);
    const hdrDib = Buffer.alloc(40);
    hdrDib.writeUInt32LE(40, 0);
    hdrDib.writeInt32LE(W, 4);
    hdrDib.writeInt32LE(H, 8);  // positive = bottom-up
    hdrDib.writeUInt16LE(1, 12);
    hdrDib.writeUInt16LE(32, 14);
    hdrDib.writeUInt32LE(0, 16);
    hdrDib.writeUInt32LE(pxSize, 20);
    hdrDib.writeInt32LE(2835, 24);
    hdrDib.writeInt32LE(2835, 28);
    const px = Buffer.alloc(pxSize);
    let o = 0;
    for (let y = H - 1; y >= 0; y--) {
        for (let x = 0; x < W; x++) {
            px[o++] = ((x + y) * 2) & 0xff;  // B
            px[o++] = (y * 4) & 0xff;        // G
            px[o++] = (x * 4) & 0xff;        // R
            px[o++] = 0xff;                  // A
        }
    }
    return Buffer.concat([hdrFile, hdrDib, px]);
}

const SIZES = [
    [320, 180],   // 16:9 small
    [640, 360],   // nHD
    [854, 480],   // FWVGA
    [1280, 720],  // HD
    [1920, 1080], // FHD
];

console.log('size        | px        | wasm time      MIPS    steps           | native time    speedup');
console.log('------------+-----------+----------------------------------------+------------------------');

for (const [W, H] of SIZES) {
    const bmp = makeBmp(W, H);
    await writeFile(`${BMP_CRATE}/fixtures/test_${W}x${H}.bmp`, bmp);

    const src = await readFile(`${BMP_CRATE}/src/main.rs`, 'utf8');
    const patched = src
        .replace(/const W: usize = \d+;/, `const W: usize = ${W};`)
        .replace(/const H: usize = \d+;/, `const H: usize = ${H};`)
        .replace(/test_\d+x\d+\.bmp/, `test_${W}x${H}.bmp`);
    await writeFile(`${BMP_CRATE}/src/main.rs`, patched);

    const build = spawnSync('cargo', ['build', '--release', '--quiet'],
        { cwd: BMP_CRATE, stdio: ['ignore', 'ignore', 'inherit'] });
    if (build.status !== 0) {
        console.log(`${W}x${H}: BUILD FAIL`);
        continue;
    }
    const elfPath = `${BMP_CRATE}/target/i686-unknown-linux-gnu/release/rust-mov-bmp-decode-fb`;
    const elfBytes = new Uint8Array(await readFile(elfPath));
    const pixels = W * H;

    // wasm
    let wasmTime, wasmSteps, wasmRate, wasmExit;
    try {
        const vm = new mod.Vm(elfBytes);
        const tStart = performance.now();
        const MAX = 50_000_000_000n;
        const BATCH = 10_000_000n;
        while (!vm.haltReason && vm.steps < MAX) {
            vm.stepN(BATCH);
        }
        wasmTime = performance.now() - tStart;
        wasmSteps = vm.steps;
        wasmRate = Number(wasmSteps) / wasmTime / 1000;
        wasmExit = vm.exitCode;
        vm.free();
    } catch (e) {
        console.log(`${W}x${H}: WASM ERROR ${e.message}`);
        continue;
    }

    // native handover
    let nativeTime = NaN;
    try {
        const port = 20000 + Math.floor(Math.random() * 20000);
        const child = spawn(TURBO86_BIN, ['--addr', `127.0.0.1:${port}`], {
            stdio: 'ignore',
        });
        for (let i = 0; i < 80; i++) {
            try {
                const probe = new WebSocket(`ws://127.0.0.1:${port}/`);
                await new Promise((resolve, reject) => {
                    probe.addEventListener('open', resolve, { once: true });
                    probe.addEventListener('error', reject, { once: true });
                });
                probe.close();
                break;
            } catch {
                await new Promise(r => setTimeout(r, 25));
            }
        }
        const vm = new mod.Vm(elfBytes);
        const ctx = wrapper.snapshotContext(vm);
        vm.free();
        const ws = new WebSocket(`ws://127.0.0.1:${port}/`);
        const tStart = performance.now();
        await new Promise((resolve, reject) => {
            ws.addEventListener('open', () => {
                ws.send(wrapper.makeLoadContextMessage(ctx, 'host'));
            }, { once: true });
            ws.addEventListener('message', () => {});
            ws.addEventListener('close', resolve, { once: true });
            ws.addEventListener('error', reject, { once: true });
        });
        nativeTime = performance.now() - tStart;
        child.kill('SIGKILL');
        await new Promise(r => setTimeout(r, 30));
    } catch (e) {
        console.log(`${W}x${H}: NATIVE ERROR ${e.message}`);
    }

    const speedup = wasmTime / nativeTime;
    const fmtMs = (ms) => ms >= 60_000 ? `${(ms/60_000).toFixed(1)} min` : `${(ms/1000).toFixed(1)} s`;
    console.log(
        `${W}x${H}`.padEnd(11) + ' | ' +
        `${pixels.toLocaleString().padStart(8)}` + ' | ' +
        fmtMs(wasmTime).padStart(10) + '  ' +
        wasmRate.toFixed(2).padStart(5) + 'M  ' +
        wasmSteps.toString().padStart(13) + ' | ' +
        fmtMs(nativeTime).padStart(10) + '  ' +
        speedup.toFixed(0).padStart(5) + 'x'
    );
}

process.exit(0);
