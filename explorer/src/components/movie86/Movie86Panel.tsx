import { useEffect, useRef, useState } from 'react';
import { AlertCircle, Pause, Play, RefreshCw, StepForward, Upload } from 'lucide-react';
import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';
import { Button } from '@/components/ui/button';
import { Separator } from '@/components/ui/separator';
import { Registers } from './Registers';
import { Disassembly } from './Disassembly';
import { Memory } from './Memory';
import { Canvas } from './Canvas';
import { Console } from './Console';
import { fmt32, fmtBytes } from '@/lib/utils';
import type { UseMovie86VmReturn } from '@/hooks/useMovie86Vm';

interface Movie86PanelProps {
    elf: Uint8Array | null;
    movie86Vm: UseMovie86VmReturn;
    /** Trailing actions slot — used for the turbo86 handover button so
     *  it sits inside the engine card without taking another row. */
    actions?: React.ReactNode;
}

/**
 * The "embedded movie86" half of the explorer page. Composed of small
 * panes (Registers, Disassembly, Memory, Canvas, Console) that are
 * reused individually in their own modules — same shape the parent
 * movie86 demo arrives at but split into discrete React components
 * for reuse downstream.
 *
 * The actual Vm lifecycle lives in `useMovie86Vm`; this component is
 * pure rendering + Run / Step / Reset wiring.
 *
 * Input paths:
 *  - **Primary**: `elf` prop — the freshly-compiled binary from the
 *    upper Compile row. The compiled output is what the page is *for*;
 *    it auto-loads here as soon as the compile finishes.
 *  - **Optional escape hatch**: `Upload ELF` button — accepts any
 *    user-supplied ELF. Useful for inspecting or running a binary the
 *    explorer didn't produce.
 *
 * Today the in-browser pipelines (movfuscator-wasm + llvm-mov via the
 * shared binutils-wasm `ld`) always pass `-dynamic-linker`, so movie86
 * (which only loads **static** ELFs) rejects the auto-load with
 * `LoadError: DynamicLinkingUnsupported`. We surface that error in a
 * banner so the user knows to either upload a static ELF or wait for
 * issue #36 (static-link option in movfuscator-wasm) — *not* by
 * stuffing pre-built fixtures into a preset dropdown, which would push
 * the explorer's intent away from "run what you compiled".
 */
export function Movie86Panel({ elf, movie86Vm, actions }: Movie86PanelProps) {
    const {
        vm,
        tick,
        running,
        run,
        step,
        stop,
        reset,
        loadElf,
        drainOutput,
        follow,
        setFollow,
        delayMs,
        setDelayMs,
    } = movie86Vm;

    const [stdout, setStdout] = useState('');
    const [stderr, setStderr] = useState('');
    const [loadError, setLoadError] = useState<string | null>(null);
    const fileInputRef = useRef<HTMLInputElement | null>(null);

    // Load the latest compiled ELF when it changes — but also re-fire
    // once the movie86 wasm wrapper finishes loading. A fast compile
    // path (movfuscator hits, no clang.wasm cold-start) can produce an
    // ELF before `useMovie86Vm` has resolved the dynamic import, and
    // `loadElf` rejects with `movie86 wasm not loaded yet`. Depending
    // on `movie86Vm.movie86` here makes the effect re-run as soon as
    // the wrapper handle becomes available, so the cached ELF lands
    // without forcing the user to recompile.
    const movie86Ready = movie86Vm.movie86;
    useEffect(() => {
        if (!elf || !movie86Ready) return;
        setStdout('');
        setStderr('');
        setLoadError(null);
        loadElf(elf).catch((e) => {
            const msg = (e as Error).message ?? String(e);
            console.error('movie86 loadElf failed', e);
            setLoadError(msg);
        });
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [elf, movie86Ready]);

    const loadFromBytes = async (bytes: Uint8Array) => {
        setStdout('');
        setStderr('');
        setLoadError(null);
        try {
            await loadElf(bytes);
        } catch (e) {
            const msg = (e as Error).message ?? String(e);
            console.error('movie86 loadElf failed', e);
            setLoadError(msg);
        }
    };

    const onUpload = async (file: File) => {
        const bytes = new Uint8Array(await file.arrayBuffer());
        await loadFromBytes(bytes);
    };

    // Drain stdout/stderr on every tick.
    useEffect(() => {
        const out = drainOutput();
        if (out.stdout.length) {
            setStdout((prev) => prev + decoder.decode(out.stdout));
        }
        if (out.stderr.length) {
            setStderr((prev) => prev + decoder.decode(out.stderr));
        }
    }, [tick, drainOutput]);

    return (
        <Card>
            <CardHeader className="pb-2">
                <div className="flex items-center justify-between gap-3 flex-wrap">
                    <div>
                        <CardTitle className="text-base">Run · movie86</CardTitle>
                        <CardDescription>
                            In-browser ELF32 i386 emulator. The latest compile
                            auto-loads here; click Run to step until halt.
                        </CardDescription>
                    </div>
                    <div className="flex items-center gap-2">
                        <Button
                            variant="ghost"
                            size="sm"
                            onClick={() => fileInputRef.current?.click()}
                            data-testid="elf-upload"
                            title="Upload an arbitrary static ELF (optional escape hatch)"
                        >
                            <Upload className="h-3.5 w-3.5" />
                            Upload
                        </Button>
                        <Button
                            variant="outline"
                            size="sm"
                            onClick={() => reset()}
                            disabled={!vm}
                            data-testid="vm-reset"
                        >
                            <RefreshCw className="h-3.5 w-3.5" />
                            Reset
                        </Button>
                        <label
                            className="flex items-center gap-1.5 text-xs text-muted-foreground select-none"
                            title="Follow: step one instruction per frame and redraw every step (watch each mov land). Off: run in fast batches and refresh periodically. Toggle any time — including mid-run."
                        >
                            <input
                                type="checkbox"
                                className="h-3.5 w-3.5 accent-primary"
                                checked={follow}
                                onChange={(e) => setFollow(e.target.checked)}
                                data-testid="vm-follow"
                            />
                            Follow
                        </label>
                        <label
                            className="flex items-center gap-1 text-xs text-muted-foreground"
                            title="Step delay (ms) between instructions while Follow is on."
                        >
                            delay
                            <input
                                type="number"
                                min={0}
                                step={50}
                                value={delayMs}
                                onChange={(e) => setDelayMs(Number(e.target.value))}
                                disabled={!follow}
                                className="w-14 rounded-md border bg-background px-1.5 py-0.5 text-xs tabular-nums disabled:opacity-50"
                                data-testid="vm-delay"
                            />
                            ms
                        </label>
                        <Button
                            variant="outline"
                            size="sm"
                            onClick={step}
                            disabled={!vm || !!tick?.haltReason}
                            data-testid="vm-step"
                        >
                            <StepForward className="h-3.5 w-3.5" />
                            Step
                        </Button>
                        {running ? (
                            <Button
                                size="sm"
                                variant="destructive"
                                onClick={stop}
                                data-testid="vm-run"
                            >
                                <Pause className="h-3.5 w-3.5" />
                                Stop
                            </Button>
                        ) : (
                            <Button
                                size="sm"
                                onClick={() => run()}
                                disabled={!vm || !!tick?.haltReason}
                                data-testid="vm-run"
                            >
                                <Play className="h-3.5 w-3.5" />
                                Run
                            </Button>
                        )}
                        {actions}
                    </div>
                </div>
            </CardHeader>
            <CardContent className="grid gap-4">
                <input
                    ref={fileInputRef}
                    type="file"
                    accept=".elf,application/octet-stream"
                    hidden
                    onChange={(e) => {
                        const f = e.target.files?.[0];
                        if (f) onUpload(f);
                        e.target.value = '';
                    }}
                    data-testid="elf-upload-input"
                />
                {loadError && (
                    <div
                        className="flex items-start gap-2 rounded-md border border-destructive/40 bg-destructive/5 p-3 text-xs"
                        data-testid="load-error"
                        role="alert"
                    >
                        <AlertCircle className="h-4 w-4 text-destructive shrink-0 mt-0.5" />
                        <div>
                            <p className="font-semibold text-destructive">
                                movie86 couldn't load the ELF.
                            </p>
                            <p className="text-muted-foreground mt-1">
                                {loadError}
                            </p>
                            {/DynamicLinkingUnsupported|dynamic/i.test(loadError) && (
                                <p className="text-muted-foreground mt-1">
                                    The in-browser <code>ld</code> currently
                                    only emits dynamic ELFs (see
                                    <code> -dynamic-linker</code> in
                                    movfuscator-wasm's link command). movie86
                                    needs static ELFs. Pick an example fixture
                                    above or upload a static ELF to keep
                                    going; the inspection panes (IR / asm /
                                    ELF hex) still work for the dynamic
                                    output.
                                </p>
                            )}
                        </div>
                    </div>
                )}
                <StatusRow tick={tick} memBase={vm?.memBase} memLen={vm?.memLen} />
                <Separator />

                <div className="grid gap-4 xl:grid-cols-[14rem_minmax(0,1fr)_minmax(0,1fr)] lg:grid-cols-[14rem_minmax(0,1fr)] grid-cols-1">
                    <Pane title="Registers">
                        <Registers
                            tick={tick}
                            sigsegv={vm?.sigsegvHandler}
                            sigill={vm?.sigillHandler}
                        />
                    </Pane>
                    <Pane title="Disassembly">
                        <Disassembly vm={vm} tick={tick} />
                    </Pane>
                    <Pane title="Memory">
                        <Memory vm={vm} tick={tick} />
                    </Pane>
                </div>

                <Pane title="Canvas">
                    <Canvas vm={vm} tick={tick} movie86={movie86Vm.movie86} />
                </Pane>

                <Console stdout={stdout} stderr={stderr} />
            </CardContent>
        </Card>
    );
}

const decoder = new TextDecoder('utf-8', { fatal: false });

function Pane({ title, children }: { title: string; children: React.ReactNode }) {
    return (
        <div className="flex flex-col gap-2">
            <h3 className="text-xs uppercase tracking-wide text-muted-foreground">
                {title}
            </h3>
            <div className="rounded-md border bg-card p-3 min-h-0">{children}</div>
        </div>
    );
}

function StatusRow({
    tick,
    memBase,
    memLen,
}: {
    tick: import('@/hooks/useMovie86Vm').VmTick | null;
    memBase?: number;
    memLen?: number;
}) {
    const cards: { v: string; k: string; tone?: 'exit' | 'fault' }[] = [
        { v: tick ? fmtSteps(tick.steps) : '—', k: 'total mov' },
        {
            v: tick?.haltReason ?? (tick ? 'running' : '—'),
            k: 'halt',
            tone: tick?.haltReason
                ? tick.haltReason.startsWith('Exit(')
                    ? 'exit'
                    : 'fault'
                : undefined,
        },
        { v: tick?.exitCode != null ? String(tick.exitCode) : '—', k: 'exit' },
        {
            v:
                memBase != null && memLen != null
                    ? `${fmt32(memBase)} +${fmtBytes(memLen)} B`
                    : '—',
            k: 'memory',
        },
    ];
    return (
        <div className="grid grid-cols-2 sm:grid-cols-4 gap-2">
            {cards.map((c) => (
                <div
                    key={c.k}
                    className="rounded-md border bg-gradient-to-b from-muted/40 to-muted/10 p-2 min-w-0"
                >
                    <div
                        className={
                            'text-sm font-semibold tabular-nums break-words ' +
                            (c.tone === 'exit'
                                ? 'text-emerald-600 dark:text-emerald-400'
                                : c.tone === 'fault'
                                  ? 'text-destructive'
                                  : '')
                        }
                    >
                        {c.v}
                    </div>
                    <div className="text-[0.7rem] uppercase tracking-wide text-muted-foreground">
                        {c.k}
                    </div>
                </div>
            ))}
        </div>
    );
}

function fmtSteps(n: bigint): string {
    const s = n.toString();
    return s.replace(/\B(?=(\d{3})+(?!\d))/g, ',');
}
