// Regression test: serializing a LoadContext whose regions are large
// (hundreds of MiB) must not throw. This guards the bug where SIMD86's
// deck snapshot (~160 MiB of guest RGBA) blew up in
// makeLoadContextMessage with Firefox's "allocation size overflow" —
// btoa() over one ~160 MiB binary string tried to allocate the ~213 MiB
// base64 output contiguously. The fix base64-encodes in 3-byte-aligned
// chunks; this test pins it so a future "simplification" back to a
// single btoa() fails loudly.
//
// Pure JS — no wasm, no turbo86 — so it runs in the fast `node` test set.
// We import the wrapper's makeLoadContextMessage and feed it a synthetic
// Context with a region big enough to trip the old code path, then assert
// the produced JSON round-trips back to the original bytes.
//
//   node tests/large_handover.mjs

import { dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import assert from 'node:assert/strict';

const here = dirname(fileURLToPath(import.meta.url));
const { makeLoadContextMessage, parseOutboundMessage } = await import(`${here}/../movie86.mjs`);

let failed = 0;

// ~96 MiB single region: comfortably past the point where a one-shot
// btoa() of the binary string overflowed in the field report, while
// staying small enough to serialize in a couple of seconds under Node's
// default heap. The deck that surfaced the bug was 160 MiB; 96 MiB is
// enough to exercise the multi-chunk base64 path (CHUNK = 0x18000) many
// times over.
const SIZE = 96 * 1024 * 1024;

try {
    const bytes = new Uint8Array(SIZE);
    // A non-constant pattern so base64 chunk boundaries actually matter
    // (all-zero bytes would hide an off-by-one in the 3-byte alignment).
    for (let i = 0; i < SIZE; i++) bytes[i] = (i * 7 + 13) & 0xff;

    const ctx = {
        regs: { eax: 0, ebx: 0, ecx: 0, edx: 0, esi: 0, edi: 0, ebp: 0, esp: 0x701FFFF0, eip: 0x08048000, eflags: 0 },
        regions: [{ addr: 0x00400000, bytes }],
        reservations: [],
    };

    const t0 = Date.now();
    const frame = makeLoadContextMessage(ctx, 'host', 100); // must not throw
    const dt = Date.now() - t0;
    assert.ok(frame.length > SIZE, `frame (${frame.length}) should exceed raw size`);

    // Decode the base64 region back and verify byte-for-byte. parseOutbound
    // isn't symmetric with LoadContext, so decode the JSON directly with the
    // same base64 path the receiver uses (atob), proving the chunked encode
    // produced valid, boundary-correct base64.
    const obj = JSON.parse(frame);
    const b64 = obj.context.regions[0].bytes;
    const bin = atob(b64);
    assert.equal(bin.length, SIZE, `decoded length ${bin.length} != ${SIZE}`);
    // Spot-check a scatter of offsets (full compare would double memory).
    for (const off of [0, 1, 2, 3, 0x17FFF, 0x18000, 0x18001, SIZE - 1]) {
        assert.equal(bin.charCodeAt(off) & 0xff, (off * 7 + 13) & 0xff,
            `byte mismatch at ${off}`);
    }

    console.log(`ok  large handover  ${(SIZE / 1048576) | 0} MiB region → ${(frame.length / 1048576) | 0} MiB JSON in ${dt} ms, base64 round-trips`);
} catch (e) {
    console.error(`FAIL large handover: ${e.message}`);
    failed = 1;
}

process.exit(failed);
