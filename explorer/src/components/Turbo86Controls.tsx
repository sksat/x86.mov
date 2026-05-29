import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select';
import type { HandoverMode, UseTurbo86SessionReturn } from '@/hooks/useTurbo86Session';

interface Turbo86ControlsProps {
    turbo86: UseTurbo86SessionReturn;
    /** Lock the address/mode while a session is live — they only take
     *  effect on the next forward handover. */
    locked?: boolean;
}

/**
 * The turbo86 connection strip — WebSocket address, handover mode, and
 * the live session status. Surfaced inline under the run controls only
 * while turbo86 is the selected backend. Replaces the old one-shot
 * `Turbo86Handover` "Send" button: the *backend toggle* now triggers the
 * handover, so this is pure configuration + status.
 */
export function Turbo86Controls({ turbo86, locked }: Turbo86ControlsProps) {
    return (
        <div
            className="flex flex-wrap items-end gap-3 rounded-md border bg-muted/10 p-3"
            data-testid="turbo86-handover"
        >
            <div className="flex flex-col gap-1.5 grow min-w-[20ch]">
                <Label htmlFor="turbo86-url">turbo86 URL</Label>
                <Input
                    id="turbo86-url"
                    value={turbo86.url}
                    onChange={(e) => turbo86.setUrl(e.target.value)}
                    placeholder="ws://127.0.0.1:1234"
                    disabled={locked}
                    data-testid="turbo86-url"
                />
            </div>
            <div className="flex flex-col gap-1.5">
                <Label htmlFor="turbo86-mode">mode</Label>
                <Select
                    value={turbo86.mode}
                    onValueChange={(v) => turbo86.setMode(v as HandoverMode)}
                    disabled={locked}
                >
                    <SelectTrigger id="turbo86-mode" className="w-[120px]">
                        <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="trap">trap</SelectItem>
                        <SelectItem value="host">host</SelectItem>
                    </SelectContent>
                </Select>
            </div>
            <span
                className="text-xs text-muted-foreground tabular-nums ml-auto self-end"
                data-testid="turbo86-status"
            >
                {turbo86.connected ? '● ' : '○ '}
                {turbo86.status}
            </span>
        </div>
    );
}
