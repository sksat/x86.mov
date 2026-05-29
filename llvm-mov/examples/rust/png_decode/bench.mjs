// PNG decode benchmark across resolutions, wasm vs turbo86 native.
//
// For each size in `SIZES`:
//   1. Generate a stored-block PNG fixture at that resolution.
//   2. Recompile the rust crate with W/H consts patched.
//   3. Run the produced ELF through (a) movie86 wasm with step
//      counting and (b) turbo86 native via WS handover.
//   4. Print one row of (W×H, wasm time, wasm MIPS, wasm steps,
//      native time, speedup).
//
// Requires:
//   TURBO86_BIN  — path to a turbo86 binary built from origin/mov tip
//                  (has mov-only ABI support).
//   PNG_CRATE    — path to llvm-mov/examples/rust/png_decode crate dir.
//   MOVIE86_WASM_DIR — path to movie86/wasm dir with build/browser/ ready.

import { readFile, writeFile } from 'node:fs/promises';
import { spawn, spawnSync } from 'node:child_process';
import zlib from 'node:zlib';

const TURBO86_BIN = process.env.TURBO86_BIN;
const PNG_CRATE = process.env.PNG_CRATE;
const WASM_DIR = process.env.MOVIE86_WASM_DIR;
if (!TURBO86_BIN || !PNG_CRATE || !WASM_DIR) {
    throw new Error('TURBO86_BIN, PNG_CRATE, MOVIE86_WASM_DIR required');
}

// Load wasm Vm.
const wasm = await readFile(`${WASM_DIR}/build/browser/movie86_wasm_bg.wasm`);
const mod = await import(`${WASM_DIR}/build/browser/movie86_wasm.js`);
await mod.default({ module_or_path: wasm });
const wrapper = await import(`${WASM_DIR}/movie86.mjs`);

// PNG generator (stored-block IDAT, RGBA gradient).
function makePng(W, H) {
    const img = Buffer.alloc(H * (1 + W * 4));
    let o = 0;
    for (let y = 0; y < H; y++) {
        img[o++] = 0;  // filter type 0
        for (let x = 0; x < W; x++) {
            img[o++] = (x * 4) & 0xff;
            img[o++] = (y * 4) & 0xff;
            img[o++] = ((x + y) * 2) & 0xff;
            img[o++] = 0xff;
        }
    }
    const idat = zlib.deflateSync(img, { level: 0 });
    function chunk(name, data) {
        const buf = Buffer.alloc(4 + name.length + data.length + 4);
        buf.writeUInt32BE(data.length, 0);
        buf.write(name, 4);
        data.copy(buf, 4 + name.length);
        // CRC32
        const crc = require('node:zlib').crc32(Buffer.concat([Buffer.from(name), data]));
        buf.writeUInt32BE(crc >>> 0, 4 + name.length + data.length);
        return buf;
    }
    // Node lacks zlib.crc32 in old versions; fall back to a tiny impl.
    function crc32(buf) {
        const table = new Uint32Array(256);
        for (let i = 0; i < 256; i++) {
            let c = i;
            for (let k = 0; k < 8; k++) c = (c & 1) ? (0xEDB88320 ^ (c >>> 1)) : (c >>> 1);
            table[i] = c;
        }
        let c = 0xFFFFFFFF;
        for (const b of buf) c = table[(c ^ b) & 0xFF] ^ (c >>> 8);
        return (c ^ 0xFFFFFFFF) >>> 0;
    }
    function chunk2(name, data) {
        const head = Buffer.from(name);
        const body = Buffer.concat([head, data]);
        const out = Buffer.alloc(4 + body.length + 4);
        out.writeUInt32BE(data.length, 0);
        body.copy(out, 4);
        out.writeUInt32BE(crc32(body), 4 + body.length);
        return out;
    }
    const sig = Buffer.from([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);
    const ihdr = Buffer.alloc(13);
    ihdr.writeUInt32BE(W, 0);
    ihdr.writeUInt32BE(H, 4);
    ihdr[8] = 8;   // bit depth
    ihdr[9] = 6;   // color type RGBA
    ihdr[10] = 0;  // compression
    ihdr[11] = 0;  // filter
    ihdr[12] = 0;  // interlace
    return Buffer.concat([
        sig,
        chunk2('IHDR', ihdr),
        chunk2('IDAT', idat),
        chunk2('IEND', Buffer.alloc(0)),
    ]);
}

const SIZES = [
    [64, 64],
    [128, 128],
    [256, 256],
    [512, 512],
    // [1024, 1024],  // skip if movie86 wasm is too slow
    // [1920, 1080],
];

console.log('size       | wasm time   wasm MIPS   wasm steps   | native time   speedup');
console.log('-----------+-------------------------------------+----------------------');

for (const [W, H] of SIZES) {
    // 1. Regenerate fixture.
    await writeFile(`${PNG_CRATE}/fixtures/test_${W}x${H}.png`, makePng(W, H));

    // 2. Patch consts + include path.
    const src = await readFile(`${PNG_CRATE}/src/main.rs`, 'utf8');
    let patched = src
        .replace(/const W: usize = \d+;/, `const W: usize = ${W};`)
        .replace(/const H: usize = \d+;/, `const H: usize = ${H};`)
        .replace(/test_\d+x\d+\.png/, `test_${W}x${H}.png`);
    await writeFile(`${PNG_CRATE}/src/main.rs`, patched);

    // 3. Recompile.
    const build = spawnSync('cargo', ['build', '--release', '--quiet'],
        { cwd: PNG_CRATE, stdio: ['ignore', 'ignore', 'inherit'] });
    if (build.status !== 0) {
        console.log(`${W}x${H}: BUILD FAIL`);
        continue;
    }
    const elfPath = `${PNG_CRATE}/target/i686-unknown-linux-gnu/release/rust-mov-png-decode`;
    const elfBytes = new Uint8Array(await readFile(elfPath));

    // 4. movie86 wasm — count steps until halt.
    let wasmTime, wasmSteps, wasmRate;
    {
        const vm = new mod.Vm(elfBytes);
        const tStart = performance.now();
        const MAX = 5_000_000_000n;
        const BATCH = 5_000_000n;
        while (!vm.haltReason && vm.steps < MAX) {
            vm.stepN(BATCH);
        }
        wasmTime = performance.now() - tStart;
        wasmSteps = vm.steps;
        wasmRate = Number(wasmSteps) / wasmTime / 1000;
        vm.free();
    }

    // 5. turbo86 native — handover and time end-to-end.
    let nativeTime;
    {
        const port = 20000 + Math.floor(Math.random() * 20000);
        const child = spawn(TURBO86_BIN, ['--addr', `127.0.0.1:${port}`], {
            stdio: 'ignore',
        });
        // Wait for ready.
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
            // Ignore unknown Outbound types like video_mode.
            ws.addEventListener('message', () => {});
            ws.addEventListener('close', resolve, { once: true });
            ws.addEventListener('error', reject, { once: true });
        });
        nativeTime = performance.now() - tStart;
        child.kill('SIGKILL');
        await new Promise(r => setTimeout(r, 30));
    }

    const speedup = wasmTime / nativeTime;
    console.log(
        `${W}x${H}`.padEnd(10) + ' | ' +
        `${wasmTime.toFixed(0).padStart(8)} ms  ` +
        `${wasmRate.toFixed(2).padStart(6)} M  ` +
        `${wasmSteps.toString().padStart(11)}  | ` +
        `${nativeTime.toFixed(0).padStart(8)} ms     ` +
        `${speedup.toFixed(0).padStart(5)}x`
    );
}

process.exit(0);
