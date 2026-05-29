import { useEffect, useState } from 'react';
import { Pause, Play, RefreshCw, StepForward } from 'lucide-react';
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
 */
export function Movie86Panel({ elf, movie86Vm, actions }: Movie86PanelProps) {
    const { vm, tick, running, run, step, stop, reset, loadElf, drainOutput } =
        movie86Vm;

    const [stdout, setStdout] = useState('');
    const [stderr, setStderr] = useState('');

    // Load the latest compiled ELF when it changes.
    useEffect(() => {
        if (!elf) return;
        setStdout('');
        setStderr('');
        loadElf(elf).catch((e) => console.error('movie86 loadElf failed', e));
        // eslint-disable-next-line react-hooks/exhaustive-deps
    }, [elf]);

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
                            In-browser ELF32 i386 emulator. Loads the latest
                            compile automatically; click Run to step until halt.
                        </CardDescription>
                    </div>
                    <div className="flex items-center gap-2">
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
