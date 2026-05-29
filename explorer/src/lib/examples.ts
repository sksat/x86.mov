// Pre-built static ELF fixtures for the embedded movie86 panel.
//
// movie86 only loads *static* ELFs (PT_INTERP / PT_DYNAMIC are
// rejected at `Vm::new`), but the in-browser movfuscator-wasm and
// llvm-mov pipelines both go through binutils-wasm `ld` with
// `-dynamic-linker /lib/ld-linux.so.2` — producing dynamically linked
// ELFs that movie86 refuses to load. Until movfuscator-wasm grows a
// `-static` link option, the explorer exposes the existing committed
// fixtures so the Run / Step / Send-to-turbo86 buttons have something
// to actually do.
//
// Fixtures come from `movie86/wasm/examples/` (already deployed at
// `/movie86/examples/` per the movie86/wasm stage-deploy). Loading
// them in the explorer reuses the same deploy URL — no duplicate copy.

export interface ExampleElf {
    id: string;
    label: string;
    /** Sibling-relative URL — resolved via `loadExampleElf()`. */
    path: string;
    description: string;
}

export const EXAMPLE_ELFS: readonly ExampleElf[] = [
    {
        id: 'return42',
        label: 'return42 — exits with code 42',
        path: 'movie86/examples/return42.elf',
        description: 'Smallest meaningful program; useful for sanity-checking the run path.',
    },
    {
        id: 'hello',
        label: 'hello — write "Hello\\n" + exit',
        path: 'movie86/examples/hello.elf',
        description: 'Mov-only ABI write + exit (no int 0x80).',
    },
    {
        id: 'call_greet',
        label: 'call_greet — direct CALL / RET',
        path: 'movie86/examples/call_greet.elf',
        description: 'Verifies stack ops + call/ret in the emulator.',
    },
    {
        id: 'cycle',
        label: 'cycle — print "1 2 3 4 5" forever',
        path: 'movie86/examples/cycle.elf',
        description: 'Tight CALL/RET loop. Hit Stop to interrupt.',
    },
    {
        id: 'canvas_bars',
        label: 'canvas_bars — mode 13h color bars',
        path: 'movie86/examples/canvas_bars.elf',
        description: 'Sets a VGA framebuffer, blits SMPTE-style bars.',
    },
    {
        id: 'canvas_smile',
        label: 'canvas_smile — mode 13h smiley',
        path: 'movie86/examples/canvas_smile.elf',
        description: 'Same canvas as bars; different art.',
    },
];

/**
 * Fetch a fixture ELF by its catalogue id. The URL is resolved against
 * `document.baseURI`, so the same code works in dev (the Vite middleware
 * rewrites `/movie86/...` → `../movie86/wasm/...`) and in prod (CF Pages
 * serves the deployed fixtures directly).
 */
export async function loadExampleElf(id: string): Promise<Uint8Array> {
    const entry = EXAMPLE_ELFS.find((e) => e.id === id);
    if (!entry) throw new Error(`unknown example: ${id}`);
    const base =
        typeof document !== 'undefined'
            ? document.baseURI
            : 'http://localhost/';
    const url = new URL(`../${entry.path}`, base).href;
    const r = await fetch(url);
    if (!r.ok) {
        throw new Error(`fetch ${url}: ${r.status} ${r.statusText}`);
    }
    return new Uint8Array(await r.arrayBuffer());
}
