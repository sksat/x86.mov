import type { Movie86Vm } from '@/lib/wrappers';
import type { VmTick } from '@/hooks/useMovie86Vm';
import { cn } from '@/lib/utils';

interface MemoryProps {
    vm: Movie86Vm | null;
    tick: VmTick | null;
    /** Number of 16-byte rows. */
    rows?: number;
}

/**
 * 16×N memory hex viewer anchored at `(EIP & ~0xF)`. Highlights the
 * instruction's full byte span via the decoder so cursor + disassembly
 * agree on the next instruction.
 *
 * Same clamping behaviour as the existing demo: `readMem` returns
 * shorter slices near region edges; we render whatever we got and let
 * the row count shrink rather than padding with garbage.
 */
export function Memory({ vm, tick, rows = 16 }: MemoryProps) {
    if (!vm || !tick) {
        return (
            <p className="text-xs text-muted-foreground">
                (load a program to populate memory)
            </p>
        );
    }
    const eip = tick.eip;
    const base = (eip & ~0xf) >>> 0;
    const bytes = vm.readMem(base, rows * 16);
    if (bytes.length === 0) {
        return (
            <p className="text-xs text-muted-foreground">
                (addr {fmt32(base)} outside the mapped region)
            </p>
        );
    }
    const insnAtEip = vm.disasmAt(eip);
    const insnLen = insnAtEip ? insnAtEip.len : 1;
    insnAtEip?.free();
    const insnEnd = (eip + insnLen) >>> 0;
    const rowsOut: { off: number; chunk: Uint8Array }[] = [];
    for (let r = 0; r < Math.ceil(bytes.length / 16); r++) {
        rowsOut.push({
            off: base + r * 16,
            chunk: bytes.subarray(r * 16, r * 16 + 16),
        });
    }
    return (
        <div className="font-mono text-xs tabular-nums" data-testid="memory">
            {rowsOut.map((row) => (
                <div key={row.off} className="h-[1.4em] whitespace-pre">
                    <span className="text-muted-foreground">
                        {row.off.toString(16).padStart(8, '0')}
                    </span>
                    {'  '}
                    {Array.from(row.chunk).map((b, i) => {
                        const a = (row.off + i) >>> 0;
                        const hi = a >= eip && a < insnEnd;
                        return (
                            <span
                                key={i}
                                className={cn(
                                    hi &&
                                        'bg-yellow-200/70 dark:bg-yellow-500/30 rounded',
                                )}
                            >
                                {b.toString(16).padStart(2, '0')}
                                {i === 15 ? '' : ' '}
                            </span>
                        );
                    })}
                    {'  '}
                    <span className="text-muted-foreground">
                        {Array.from(row.chunk)
                            .map((b) =>
                                b >= 0x20 && b < 0x7f ? String.fromCharCode(b) : '.',
                            )
                            .join('')}
                    </span>
                </div>
            ))}
        </div>
    );
}

function fmt32(v: number) {
    return '0x' + (v >>> 0).toString(16).padStart(8, '0');
}
