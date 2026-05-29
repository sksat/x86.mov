import { useCallback, useRef, useState } from 'react';
import type { Movie86Vm, Movie86Wrapper } from '@/lib/wrappers';

export type HandoverMode = 'host' | 'trap';

export interface UseTurbo86SessionReturn {
    url: string;
    setUrl: (u: string) => void;
    mode: HandoverMode;
    setMode: (m: HandoverMode) => void;
    /** Human-readable last-event line (mirrors the old handover status). */
    status: string;
    /** turbo86 is actively executing the handed-over program. */
    running: boolean;
    /** The WebSocket is open. */
    connected: boolean;
    /** Accumulated turbo86 stdout/stderr (decoded). The run panel
     *  concatenates these after the local movie86 output so a handover's
     *  console stays contiguous. */
    stdout: string;
    stderr: string;
    /** Drop accumulated output (called when a fresh ELF loads). */
    clearOutput: () => void;
    /** Snapshot the live Vm and ship it to turbo86 (forward handover).
     *  Opens the WebSocket on first use and keeps it open so a later
     *  reverse handover can Pause the guest. */
    forward: (vm: Movie86Vm, movie86: Movie86Wrapper) => Promise<void>;
    /** Pause turbo86, await its `Paused` snapshot, and load it back into
     *  the local Vm (reverse handover). Resolves once the state lands. */
    reverse: (vm: Movie86Vm, movie86: Movie86Wrapper) => Promise<void>;
    /** Stop turbo86 execution (SIGKILL the guest) without pulling state
     *  back — the turbo86-side analogue of movie86's Stop button. */
    stop: () => void;
    disconnect: () => void;
}

const decoder = new TextDecoder('utf-8', { fatal: false });

type Outbound = ReturnType<Movie86Wrapper['parseOutboundMessage']>;
type PausedCtx = {
    regs: Record<string, number>;
    regions: { addr: number; bytes: Uint8Array }[];
};

/**
 * Owns the *persistent* turbo86 WebSocket session behind the backend
 * selector. The previous one-shot handover opened a fresh socket per
 * send and closed it — fine when turbo86 was a fire-and-forget sink, but
 * a backend *selection* needs the socket to stay open so the user can
 * switch back (reverse handover Pauses the live guest and pulls its
 * state home).
 *
 * The forward / reverse mechanics (snapshotContext, makeLoadContextMessage,
 * Pause inbound, Paused outbound, loadContextInto) all live in the
 * movie86 wrapper already and are pinned by
 * `movie86/wasm/tests/turbo86_handover.mjs`; this hook only sequences
 * them against React state.
 */
export function useTurbo86Session(): UseTurbo86SessionReturn {
    const [url, setUrl] = useState('ws://127.0.0.1:1234');
    const [mode, setMode] = useState<HandoverMode>('trap');
    const [status, setStatus] = useState('idle');
    const [running, setRunning] = useState(false);
    const [connected, setConnected] = useState(false);
    const [stdout, setStdout] = useState('');
    const [stderr, setStderr] = useState('');

    const wsRef = useRef<WebSocket | null>(null);
    const movie86Ref = useRef<Movie86Wrapper | null>(null);
    // Resolver for the in-flight reverse handover, fulfilled when the
    // `Paused` outbound arrives.
    const pausedResolverRef = useRef<((ctx: PausedCtx) => void) | null>(null);

    const handleMessage = useCallback((ev: MessageEvent) => {
        const movie86 = movie86Ref.current;
        if (!movie86) return;
        let msg: Outbound;
        try {
            const text =
                typeof ev.data === 'string'
                    ? ev.data
                    : decoder.decode(ev.data as ArrayBuffer);
            msg = movie86.parseOutboundMessage(text);
        } catch {
            setStatus('turbo86 → (unparsable)');
            return;
        }
        switch (msg.type) {
            case 'stdout':
                setStdout((p) => p + decoder.decode(msg.bytes as Uint8Array));
                break;
            case 'stderr':
                setStderr((p) => p + decoder.decode(msg.bytes as Uint8Array));
                break;
            case 'exit':
                setRunning(false);
                setStatus(`turbo86 → exit ${msg.code as number}`);
                break;
            case 'fault':
                setRunning(false);
                setStatus(`turbo86 → fault: ${msg.reason as string}`);
                break;
            case 'paused': {
                setStatus(`turbo86 → paused (${msg.reason as string})`);
                const resolve = pausedResolverRef.current;
                pausedResolverRef.current = null;
                resolve?.({
                    regs: msg.regs as Record<string, number>,
                    regions: msg.regions as { addr: number; bytes: Uint8Array }[],
                });
                break;
            }
            // video_mode / mem_update arrive mid-run; live canvas mirroring
            // is a follow-up (see Turbo86Handover history). Ignore for now.
            default:
                break;
        }
    }, []);

    const teardown = useCallback(() => {
        setConnected(false);
        setRunning(false);
        wsRef.current = null;
    }, []);

    const ensureOpen = useCallback(
        (target: string) =>
            new Promise<WebSocket>((resolve, reject) => {
                const existing = wsRef.current;
                if (existing && existing.readyState === WebSocket.OPEN) {
                    resolve(existing);
                    return;
                }
                let ws: WebSocket;
                try {
                    ws = new WebSocket(target);
                } catch (e) {
                    reject(e as Error);
                    return;
                }
                ws.binaryType = 'arraybuffer';
                wsRef.current = ws;
                ws.addEventListener('open', () => {
                    setConnected(true);
                    resolve(ws);
                });
                ws.addEventListener('message', handleMessage);
                ws.addEventListener('error', () => {
                    const states = ['CONNECTING', 'OPEN', 'CLOSING', 'CLOSED'];
                    const rs = states[ws.readyState] ?? `?${ws.readyState}`;
                    setStatus(`ws error (readyState=${rs}; see DevTools)`);
                    reject(new Error(`ws error (readyState=${rs})`));
                });
                ws.addEventListener('close', () => {
                    setStatus((p) => `${p} · closed`);
                    teardown();
                    // A pending reverse can never complete on a closed socket.
                    const resolve2 = pausedResolverRef.current;
                    pausedResolverRef.current = null;
                    resolve2?.({ regs: {}, regions: [] });
                });
            }),
        [handleMessage, teardown],
    );

    const forward = useCallback(
        async (vm: Movie86Vm, movie86: Movie86Wrapper) => {
            movie86Ref.current = movie86;
            setStatus('connecting…');
            const ws = await ensureOpen(url);
            const ctx = movie86.snapshotContext(vm);
            ws.send(movie86.makeLoadContextMessage(ctx, mode));
            setRunning(true);
            setStatus(`forwarded: ${ctx.regions.length} regions, mode=${mode}`);
        },
        [ensureOpen, url, mode],
    );

    const reverse = useCallback(
        async (vm: Movie86Vm, movie86: Movie86Wrapper) => {
            movie86Ref.current = movie86;
            const ws = wsRef.current;
            if (!ws || ws.readyState !== WebSocket.OPEN) {
                setRunning(false);
                setStatus('reverse: no live turbo86 session');
                return;
            }
            setStatus('reverse: pausing turbo86…');
            const ctx = await new Promise<PausedCtx>((resolve) => {
                pausedResolverRef.current = resolve;
                ws.send(JSON.stringify({ type: 'pause' }));
            });
            setRunning(false);
            if (ctx.regions.length === 0 && Object.keys(ctx.regs).length === 0) {
                setStatus('reverse: aborted (session closed before Paused)');
                return;
            }
            const { applied, skipped } = movie86.loadContextInto(vm, ctx);
            setStatus(`reverse: applied ${applied} regions (skipped ${skipped})`);
        },
        [],
    );

    const stop = useCallback(() => {
        const ws = wsRef.current;
        if (ws && ws.readyState === WebSocket.OPEN) {
            ws.send(JSON.stringify({ type: 'stop' }));
        }
        setRunning(false);
        setStatus('turbo86 → stop sent');
    }, []);

    const disconnect = useCallback(() => {
        const ws = wsRef.current;
        if (ws && ws.readyState <= WebSocket.OPEN) ws.close();
        teardown();
    }, [teardown]);

    const clearOutput = useCallback(() => {
        setStdout('');
        setStderr('');
    }, []);

    return {
        url,
        setUrl,
        mode,
        setMode,
        status,
        running,
        connected,
        stdout,
        stderr,
        clearOutput,
        forward,
        reverse,
        stop,
        disconnect,
    };
}
