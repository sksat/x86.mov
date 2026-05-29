import { useEffect, useRef } from 'react';
import { cn } from '@/lib/utils';
import type { Movie86Vm } from '@/lib/wrappers';
import type { VmTick } from '@/hooks/useMovie86Vm';

interface DisassemblyProps {
    vm: Movie86Vm | null;
    tick: VmTick | null;
    rows?: number;
}

/**
 * Live disasm pane for the embedded movie86 Vm. Pulls `disasmAt(addr)`
 * row-by-row starting from EIP. The decoded `text` is whatever the
 * wasm wrapper produces — today, Rust's `Debug` form (`Mov { ... }`);
 * the parallel `movie86/disasm-display` PR replaces it with proper
 * AT&T syntax (`movl %ecx, %eax`). This component renders the text
 * verbatim either way, so the PR lands transparently.
 *
 * Fixed row height + scrolling preserves the "no jitter while running"
 * property the existing demo carefully maintains (see movie86/wasm/
 * CLAUDE.md "Don't let panes resize"). The container's height is set
 * by the caller via Tailwind / inline style; rows are pinned to 1.4 em.
 */
export function Disassembly({ vm, tick, rows = 16 }: DisassemblyProps) {
    const bodyRef = useRef<HTMLDivElement | null>(null);
    // Hooks must run on every render in the same order — keep the
    // scroll effect above any early returns. The effect guards
    // internally on the panel actually being mounted with a cursor row.
    useEffect(() => {
        const body = bodyRef.current;
        const cur = body?.querySelector<HTMLElement>('.dr-cur');
        if (!body || !cur) return;
        const top = cur.offsetTop;
        const bot = top + cur.offsetHeight;
        const vTop = body.scrollTop;
        const vBot = vTop + body.clientHeight;
        if (top < vTop) body.scrollTop = top;
        else if (bot > vBot) body.scrollTop = bot - body.clientHeight;
    });

    if (!vm || !tick) {
        return (
            <p className="text-xs text-muted-foreground">
                (load a program to populate disassembly)
            </p>
        );
    }
    const eip = tick.eip;
    const lines: { addr: number; bytes: Uint8Array; text: string; cur: boolean }[] = [];
    let addr = eip;
    for (let i = 0; i < rows; i++) {
        const d = vm.disasmAt(addr);
        if (!d) break;
        lines.push({
            addr,
            bytes: d.bytes,
            text: d.text,
            cur: addr === eip,
        });
        addr += d.len;
        d.free();
    }
    return (
        <div
            ref={bodyRef}
            className="h-72 overflow-auto font-mono text-xs tabular-nums"
            data-testid="disassembly"
        >
            {lines.length === 0 ? (
                <div className="text-muted-foreground">
                    (no decodable instructions at {fmt32(eip)})
                </div>
            ) : (
                lines.map((row) => (
                    <DisasmRow key={row.addr} {...row} />
                ))
            )}
        </div>
    );
}

function DisasmRow({
    addr,
    bytes,
    text,
    cur,
}: {
    addr: number;
    bytes: Uint8Array;
    text: string;
    cur: boolean;
}) {
    return (
        <div
            className={cn(
                'grid grid-cols-[8ch_18ch_1fr] gap-2 h-[1.4em] whitespace-nowrap px-1 rounded-sm',
                cur && 'bg-yellow-200/70 dark:bg-yellow-500/30 font-semibold dr-cur',
            )}
        >
            <span className="text-muted-foreground">
                {addr.toString(16).padStart(8, '0')}
            </span>
            <span className="text-foreground/70">
                {Array.from(bytes)
                    .map((b) => b.toString(16).padStart(2, '0'))
                    .join(' ')}
            </span>
            <span className="truncate">{text}</span>
        </div>
    );
}

function fmt32(v: number) {
    return '0x' + (v >>> 0).toString(16).padStart(8, '0');
}
