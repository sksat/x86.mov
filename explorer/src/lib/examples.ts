// Test-only fixture loader.
//
// The explorer's primary intent is "run what you just compiled" — the
// production UI doesn't expose pre-built ELFs as picker presets. This
// loader exists so the E2E suite can feed a known static ELF through
// the upload path without depending on a real movfuscator + static
// link build chain (see issue #36) yet.
//
// The fixture files themselves live under `movie86/wasm/examples/` and
// are already deployed at `/movie86/examples/` by the movie86/wasm
// stage-deploy. The test pulls them through that URL.

export async function loadExampleElf(filename: string): Promise<Uint8Array> {
    const base =
        typeof document !== 'undefined' ? document.baseURI : 'http://localhost/';
    const url = new URL(`../movie86/examples/${filename}`, base).href;
    const r = await fetch(url);
    if (!r.ok) {
        throw new Error(`fetch ${url}: ${r.status} ${r.statusText}`);
    }
    return new Uint8Array(await r.arrayBuffer());
}
