import { useState } from 'react';
import { Send } from 'lucide-react';
import { Button } from '@/components/ui/button';
import { Input } from '@/components/ui/input';
import { Label } from '@/components/ui/label';
import {
    Select,
    SelectContent,
    SelectItem,
    SelectTrigger,
    SelectValue,
} from '@/components/ui/select';
import type { Movie86Vm, Movie86Wrapper } from '@/lib/wrappers';

interface Turbo86HandoverProps {
    vm: Movie86Vm | null;
    movie86: Movie86Wrapper | null;
}

type HandoverMode = 'host' | 'trap';

/**
 * One-shot handover button + the WebSocket address controls. Lifts the
 * existing movie86 demo's handover flow into a self-contained
 * component — the WS, the LoadContext build, the Outbound log surface
 * live here. A future iteration can introduce a session pane that
 * surfaces Outbound events; for now the button takes a snapshot and
 * fires LoadContext, matching the example workflow turbo86 ships with.
 */
export function Turbo86Handover({ vm, movie86 }: Turbo86HandoverProps) {
    const [url, setUrl] = useState('ws://127.0.0.1:1234');
    const [mode, setMode] = useState<HandoverMode>('trap');
    const [status, setStatus] = useState<string>('idle');
    const [busy, setBusy] = useState(false);

    const doSend = async () => {
        if (!vm || !movie86) return;
        setBusy(true);
        setStatus('connecting…');
        let ws: WebSocket;
        try {
            ws = new WebSocket(url);
        } catch (e) {
            setStatus(`ws constructor failed: ${(e as Error).message}`);
            setBusy(false);
            return;
        }
        ws.binaryType = 'arraybuffer';
        ws.addEventListener('open', () => {
            try {
                const ctx = movie86.snapshotContext(vm);
                ws.send(movie86.makeLoadContextMessage(ctx, mode));
                setStatus(
                    `sent LoadContext: ${ctx.regions.length} regions, mode=${mode}`,
                );
            } catch (e) {
                setStatus(`snapshot failed: ${(e as Error).message}`);
                ws.close();
            }
        });
        ws.addEventListener('message', (ev) => {
            try {
                const msg = movie86.parseOutboundMessage(
                    typeof ev.data === 'string' ? ev.data : new TextDecoder().decode(ev.data),
                );
                setStatus(`turbo86 → ${msg.type}`);
            } catch {
                setStatus('turbo86 → (unparsable)');
            }
        });
        ws.addEventListener('error', (ev) => {
            // The DOM `error` event has no detail. Log the URL +
            // readyState so the user (and the E2E suite) can tell
            // "couldn't reach turbo86" from "connected then dropped".
            const states = ['CONNECTING', 'OPEN', 'CLOSING', 'CLOSED'];
            const rs = states[ws.readyState] ?? `?${ws.readyState}`;
            console.error('ws error', { url, readyState: rs, event: ev });
            setStatus(`ws error (readyState=${rs}; see DevTools)`);
        });
        ws.addEventListener('close', () => {
            setStatus((prev) => `${prev} · closed`);
            setBusy(false);
        });
    };

    return (
        <div
            className="flex flex-wrap items-end gap-3 rounded-md border bg-muted/10 p-3"
            data-testid="turbo86-handover"
        >
            <div className="flex flex-col gap-1.5 grow min-w-[20ch]">
                <Label htmlFor="turbo86-url">turbo86 URL</Label>
                <Input
                    id="turbo86-url"
                    value={url}
                    onChange={(e) => setUrl(e.target.value)}
                    placeholder="ws://127.0.0.1:1234"
                    data-testid="turbo86-url"
                />
            </div>
            <div className="flex flex-col gap-1.5">
                <Label htmlFor="turbo86-mode">mode</Label>
                <Select
                    value={mode}
                    onValueChange={(v) => setMode(v as HandoverMode)}
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
            <Button
                onClick={doSend}
                disabled={!vm || !movie86 || busy}
                data-testid="turbo86-send"
            >
                <Send className="h-4 w-4" />
                Send to local turbo86
            </Button>
            <span
                className="text-xs text-muted-foreground tabular-nums ml-auto self-end"
                data-testid="turbo86-status"
            >
                {status}
            </span>
        </div>
    );
}
