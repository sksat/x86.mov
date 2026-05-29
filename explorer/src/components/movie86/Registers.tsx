import { useMemo, useRef } from 'react';
import { cn, fmt32 } from '@/lib/utils';
import type { VmTick } from '@/hooks/useMovie86Vm';

const REG_NAMES = ['EAX', 'ECX', 'EDX', 'EBX', 'ESP', 'EBP', 'ESI', 'EDI'] as const;

interface RegistersProps {
    tick: VmTick | null;
    sigsegv?: number | null;
    sigill?: number | null;
}

/**
 * Read-only register panel. Highlights values that changed since the
 * last render — same trick the existing demo uses to make stepping
 * visible at a glance.
 *
 * EFLAGS / segment registers are intentionally not displayed: movie86
 * doesn't model EFLAGS (none of the supported instructions touch it)
 * and segment registers are flat-mode constants. See
 * movie86/wasm/CLAUDE.md for the rationale.
 */
export function Registers({ tick, sigsegv, sigill }: RegistersProps) {
    const prevRegsRef = useRef<Uint32Array | null>(null);
    const prevEipRef = useRef<number | null>(null);

    const changed = useMemo(() => {
        const out = { eip: false, regs: new Array<boolean>(REG_NAMES.length).fill(false) };
        if (!tick) return out;
        if (prevEipRef.current !== null && prevEipRef.current !== tick.eip) {
            out.eip = true;
        }
        if (prevRegsRef.current) {
            for (let i = 0; i < REG_NAMES.length; i++) {
                if (prevRegsRef.current[i] !== tick.regs[i]) out.regs[i] = true;
            }
        }
        prevRegsRef.current = tick.regs;
        prevEipRef.current = tick.eip;
        return out;
    }, [tick]);

    if (!tick) {
        return (
            <div className="text-xs text-muted-foreground">
                (load a program to populate registers)
            </div>
        );
    }
    return (
        <div className="font-mono text-sm" data-testid="registers">
            <RegRow name="EIP" value={tick.eip} highlighted={changed.eip} eip />
            {REG_NAMES.map((name, i) => (
                <RegRow
                    key={name}
                    name={name}
                    value={tick.regs[i]}
                    highlighted={changed.regs[i]}
                />
            ))}
            <hr className="my-2 border-dashed border-border" />
            <RegRow
                name="SIGSEGV"
                value={sigsegv ?? null}
                highlighted={false}
                hint={sigsegv == null ? '(none)' : undefined}
            />
            <RegRow
                name="SIGILL"
                value={sigill ?? null}
                highlighted={false}
                hint={sigill == null ? '(none)' : undefined}
            />
            <p className="mt-2 text-[0.7rem] leading-tight text-muted-foreground">
                Handlers populated from the ELF symbol table at load time
                (movfuscator's <code>dispatch</code> /{' '}
                <code>master_loop</code>). EFLAGS / segment registers
                intentionally not modelled.
            </p>
        </div>
    );
}

function RegRow({
    name,
    value,
    highlighted,
    eip,
    hint,
}: {
    name: string;
    value: number | null;
    highlighted: boolean;
    eip?: boolean;
    hint?: string;
}) {
    return (
        <div className="grid grid-cols-[5rem_1fr] gap-2">
            <span
                className={cn(
                    'text-muted-foreground',
                    eip && 'text-primary font-semibold',
                )}
            >
                {name}
            </span>
            <span
                className={cn(
                    'tabular-nums',
                    eip && 'text-primary',
                    highlighted && 'bg-yellow-200/70 dark:bg-yellow-500/30 rounded px-1 -mx-1',
                )}
            >
                {value == null ? hint ?? '—' : fmt32(value)}
            </span>
        </div>
    );
}
