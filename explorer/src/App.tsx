import { useCallback, useEffect, useMemo, useState } from 'react';
import { GithubIcon } from 'lucide-react';
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select';
import { Label } from '@/components/ui/label';
import { Separator } from '@/components/ui/separator';
import { SourceEditor } from '@/components/SourceEditor';
import { CompilerControls } from '@/components/CompilerControls';
import { CompileOutput } from '@/components/CompileOutput';
import { Movie86Panel } from '@/components/movie86/Movie86Panel';
import { Turbo86Handover } from '@/components/Turbo86Handover';
import {
    compile,
    type CompileResult,
    type CompilerId,
    type OptLevel,
} from '@/lib/compiler';
import { loadMovfuscator, type MovfuscatorWrapper } from '@/lib/wrappers';
import { useMovie86Vm } from '@/hooks/useMovie86Vm';
import { DEFAULT_PRESET, PRESETS } from '@/lib/presets';

/**
 * Top-level Explorer composition. Three rows on a wide screen:
 *   1. Source editor + compile controls
 *   2. IR | asm | binary panes (a compiler-explorer-style strip)
 *   3. Embedded movie86 emulator with turbo86 handover
 *
 * State lives here (source, compiler, opts, last compile result) so
 * each sub-component stays pure / reusable. URL persistence is a
 * follow-up — for now, presets give the user a quick reset.
 */
export function App() {
    const [source, setSource] = useState<string>(DEFAULT_PRESET.source);
    const [compiler, setCompiler] = useState<CompilerId>('llvm-mov');
    const [optLevel, setOptLevel] = useState<OptLevel>('2');
    const [extraFlags, setExtraFlags] = useState<string>('');
    const [presetId, setPresetId] = useState<string>(DEFAULT_PRESET.id);

    const [result, setResult] = useState<CompileResult | null>(null);
    const [statusMessage, setStatusMessage] = useState<string | null>(null);
    const [busy, setBusy] = useState(false);
    const [parseElf, setParseElf] = useState<
        MovfuscatorWrapper['parseElfHeader'] | undefined
    >(undefined);
    const [statusBar, setStatusBar] = useState<{
        kind: 'idle' | 'busy' | 'ok' | 'err';
        text: string;
    }>({ kind: 'idle', text: 'ready' });

    const movie86Vm = useMovie86Vm();

    // Lazy-load the ELF parser when the page first renders so the
    // header pane can render the moment a compile completes.
    useEffect(() => {
        loadMovfuscator()
            .then((m) => setParseElf(() => m.parseElfHeader))
            .catch(() => {
                /* movfuscator-wasm bytes missing — header summary will
                   fall back to a "(parser unavailable)" message. */
            });
    }, []);

    const onPresetChange = useCallback((id: string) => {
        setPresetId(id);
        const p = PRESETS.find((p) => p.id === id);
        if (p) setSource(p.source);
    }, []);

    const onCompile = useCallback(async () => {
        setBusy(true);
        setStatusMessage(null);
        setStatusBar({ kind: 'busy', text: `compiling with ${compiler}…` });
        try {
            const flags = extraFlags
                .split(/\s+/)
                .map((s) => s.trim())
                .filter(Boolean);
            const res = await compile({
                compiler,
                source,
                opts: {
                    optLevel,
                    clangFlags: flags,
                    onProgress: (stage) =>
                        setStatusBar({ kind: 'busy', text: `compiling — ${stage}` }),
                },
            });
            setResult(res);
            setStatusBar({
                kind: 'ok',
                text: `compiled in ${Math.round(res.timings.total)} ms · ${res.elf.length} B ELF`,
            });
        } catch (e) {
            const msg = (e as Error).message ?? String(e);
            setResult(null);
            setStatusMessage(msg);
            setStatusBar({ kind: 'err', text: msg });
        } finally {
            setBusy(false);
        }
    }, [compiler, source, optLevel, extraFlags]);

    const elf = useMemo(() => result?.elf ?? null, [result]);

    return (
        <div className="min-h-svh">
            <Header />
            <main className="mx-auto max-w-screen-2xl px-4 py-4 flex flex-col gap-4">
                {/* Source + controls */}
                <Card>
                    <CardHeader className="pb-2">
                        <div className="flex items-start justify-between gap-3 flex-wrap">
                            <div>
                                <CardTitle className="text-base">C source</CardTitle>
                                <CardDescription>
                                    Edit and click Compile. The result feeds the
                                    embedded movie86 below.
                                </CardDescription>
                            </div>
                            <div className="flex items-end gap-2">
                                <div className="flex flex-col gap-1.5">
                                    <Label htmlFor="preset">Preset</Label>
                                    <Select value={presetId} onValueChange={onPresetChange}>
                                        <SelectTrigger
                                            id="preset"
                                            className="w-[260px]"
                                            data-testid="preset-select"
                                        >
                                            <SelectValue />
                                        </SelectTrigger>
                                        <SelectContent>
                                            {PRESETS.map((p) => (
                                                <SelectItem key={p.id} value={p.id}>
                                                    {p.label}
                                                </SelectItem>
                                            ))}
                                        </SelectContent>
                                    </Select>
                                </div>
                            </div>
                        </div>
                    </CardHeader>
                    <CardContent className="pt-0 grid gap-3">
                        <SourceEditor
                            value={source}
                            onChange={setSource}
                            height={300}
                            data-testid="source-editor"
                        />
                        <CompilerControls
                            compiler={compiler}
                            onCompilerChange={setCompiler}
                            optLevel={optLevel}
                            onOptLevelChange={setOptLevel}
                            extraFlags={extraFlags}
                            onExtraFlagsChange={setExtraFlags}
                            onCompile={onCompile}
                            busy={busy}
                        />
                        <StatusBar {...statusBar} />
                    </CardContent>
                </Card>

                <CompileOutput
                    result={result}
                    statusMessage={statusMessage}
                    parseElfHeader={parseElf}
                />

                <Separator />

                <Movie86Panel
                    elf={elf}
                    movie86Vm={movie86Vm}
                    actions={null}
                />

                <Turbo86Handover vm={movie86Vm.vm} movie86={movie86Vm.movie86} />

                <Footer />
            </main>
        </div>
    );
}

function Header() {
    return (
        <header className="border-b">
            <div className="mx-auto max-w-screen-2xl px-4 py-3 flex items-center justify-between gap-3">
                <div className="flex items-baseline gap-3">
                    <h1 className="text-lg font-semibold tracking-tight">
                        <a href="../" className="hover:underline">
                            x86.mov
                        </a>{' '}
                        / Explorer
                    </h1>
                    <p className="text-xs text-muted-foreground">
                        compile · inspect · run · hand off — all in the browser
                    </p>
                </div>
                <a
                    href="https://github.com/sksat/x86.mov"
                    target="_blank"
                    rel="noreferrer"
                    className="text-xs text-muted-foreground hover:text-foreground inline-flex items-center gap-1"
                >
                    <GithubIcon className="h-3.5 w-3.5" />
                    sksat/x86.mov
                </a>
            </div>
        </header>
    );
}

function Footer() {
    return (
        <footer className="text-[0.7rem] text-muted-foreground border-t pt-3 mt-2">
            <p>
                movfuscator + LCC: vendored at the pinned upstream SHA · llvm-mov
                clang: out-of-tree LLVM 22 target · movie86: Rust no_std emulator
                · turbo86: ptrace-driven native exec — pieces compose by sharing a
                mov-only `int 0x80` / `int 0x10` / ABI-page ABI. All run client-
                side; nothing leaves your tab except the explicit turbo86
                handover.
            </p>
        </footer>
    );
}

function StatusBar({ kind, text }: { kind: 'idle' | 'busy' | 'ok' | 'err'; text: string }) {
    const cls =
        kind === 'busy'
            ? 'text-amber-600 dark:text-amber-400'
            : kind === 'ok'
              ? 'text-emerald-600 dark:text-emerald-400'
              : kind === 'err'
                ? 'text-destructive'
                : 'text-muted-foreground';
    return (
        <p
            className={'text-xs tabular-nums ' + cls}
            data-testid="status"
            role="status"
            aria-live="polite"
        >
            {text}
        </p>
    );
}
