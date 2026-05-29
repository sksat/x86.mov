import { Cpu, Server } from 'lucide-react';
import { cn } from '@/lib/utils';
import { BACKENDS, type BackendId } from '@/lib/backend';

const META: Record<BackendId, { label: string; icon: typeof Cpu; title: string }> = {
    movie86: {
        label: 'movie86',
        icon: Cpu,
        title: 'In-browser emulator (default)',
    },
    turbo86: {
        label: 'turbo86',
        icon: Server,
        title: 'Native ptrace backend over WebSocket',
    },
};

interface BackendSelectorProps {
    backend: BackendId;
    onSelect: (target: BackendId) => void;
    /** Disable the whole control (e.g. before a Vm is loaded). */
    disabled?: boolean;
}

/**
 * Segmented [movie86 | turbo86] toggle for the execution backend. The
 * selection — not a one-shot button — is the whole point: picking a
 * backend while running hands the live state over (forward/reverse);
 * picking while stopped just records the choice for the next Run. The
 * decision itself lives in `backend.mjs`; this is pure presentation.
 */
export function BackendSelector({ backend, onSelect, disabled }: BackendSelectorProps) {
    return (
        <div
            className="inline-flex items-center rounded-md border bg-muted/30 p-0.5"
            role="radiogroup"
            aria-label="execution backend"
            data-testid="backend-select"
        >
            {BACKENDS.map((id) => {
                const { label, icon: Icon, title } = META[id];
                const active = id === backend;
                return (
                    <button
                        key={id}
                        type="button"
                        role="radio"
                        aria-checked={active}
                        title={title}
                        disabled={disabled}
                        onClick={() => onSelect(id)}
                        data-testid={`backend-opt-${id}`}
                        data-active={active}
                        className={cn(
                            'inline-flex items-center gap-1.5 rounded-sm px-2.5 py-1 text-xs font-medium transition-colors',
                            'disabled:opacity-50 disabled:pointer-events-none',
                            active
                                ? 'bg-background shadow-sm text-foreground'
                                : 'text-muted-foreground hover:text-foreground',
                        )}
                    >
                        <Icon className="h-3.5 w-3.5" />
                        {label}
                    </button>
                );
            })}
        </div>
    );
}
