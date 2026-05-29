import { useEffect, useRef } from 'react';
import { cn } from '@/lib/utils';

interface ConsoleProps {
    stdout: string;
    stderr: string;
}

/**
 * Two-column stdout/stderr panel. Sticky-to-bottom only when the user
 * was already at the bottom — scrolling up to inspect earlier output
 * stays put as new lines land.
 */
export function Console({ stdout, stderr }: ConsoleProps) {
    return (
        <div className="grid gap-3 sm:grid-cols-2 grid-cols-1">
            <ConsolePane label="stdout" text={stdout} data-testid="stdout" />
            <ConsolePane label="stderr" text={stderr} err data-testid="stderr" />
        </div>
    );
}

function ConsolePane({
    label,
    text,
    err,
    ...rest
}: {
    label: string;
    text: string;
    err?: boolean;
    'data-testid'?: string;
}) {
    const ref = useRef<HTMLPreElement | null>(null);
    useEffect(() => {
        const el = ref.current;
        if (!el) return;
        const atBottom = el.scrollHeight - el.scrollTop - el.clientHeight < 5;
        if (atBottom) el.scrollTop = el.scrollHeight;
    }, [text]);
    return (
        <div className="flex flex-col">
            <h3 className="text-xs uppercase tracking-wide text-muted-foreground mb-1">
                {label}
            </h3>
            <pre
                ref={ref}
                className={cn(
                    'min-h-[6rem] max-h-[18rem] overflow-auto rounded-md border p-2 font-mono text-xs whitespace-pre',
                    err ? 'border-destructive/40 bg-destructive/5' : 'bg-muted/20',
                )}
                data-testid={rest['data-testid']}
            >
                {text}
            </pre>
        </div>
    );
}
