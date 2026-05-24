// Bench helper: runs the full browser-mode pipeline on one .c file.
//
// Pipeline: compile (cpp + rcc) → assemble (as) → link (ld) → ELF bytes.
// Used by scripts/bench.sh under hyperfine; output is discarded — we only
// care about how long the full chain takes.

import { compile, assemble, link } from '../web/movfuscator.mjs';
import { readFileSync, readdirSync } from 'node:fs';
import { dirname, basename, join } from 'node:path';
import { fileURLToPath } from 'node:url';

if (process.argv.length < 3) {
    console.error('usage: node bench-browser.mjs FIXTURE.c');
    process.exit(2);
}

const fixturePath = process.argv[2];
const fixtureDir = dirname(fixturePath);
const here = dirname(fileURLToPath(import.meta.url));
const libDir = join(here, '..', 'web', 'lib');

const src = readFileSync(fixturePath, 'utf8');

// Sibling .h files (e.g. md5.h alongside upstream-md5.c) → MEMFS root.
const headers = Object.fromEntries(
    readdirSync(fixtureDir)
        .filter(f => f.endsWith('.h'))
        .map(h => [h, readFileSync(join(fixtureDir, h), 'utf8')])
);

// Link inputs — preloaded from web/lib/ so we don't try to fetch over HTTP.
// Same set as web/movfuscator.mjs LIB_PATHS.
const LIB_PATHS = [
    '/lib32/libc.so.6',
    '/lib32/libm.so.6',
    '/lib32/ld-linux.so.2',
    '/lib/ld-linux.so.2',
    '/usr/lib32/libc.so',
    '/usr/lib32/libm.so',
    '/usr/lib32/libc_nonshared.a',
    '/movfuscator/libgcc.a',
    '/movfuscator/crt0.o',
    '/movfuscator/crtf.o',
    '/movfuscator/crtd.o',
    '/movfuscator/softfloat32.o',
];
const libs = Object.fromEntries(
    LIB_PATHS.map(p => [p, readFileSync(join(libDir, p.replace(/^\//, '')))])
);

const name = basename(fixturePath, '.c') + '.o';

const asm = await compile(src, headers);
const obj = await assemble(asm);
await link(obj, libs, { name });
