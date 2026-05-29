import { useEffect, useMemo, useRef } from 'react';
import type { Movie86Vm, Movie86Wrapper } from '@/lib/wrappers';
import type { VmTick } from '@/hooks/useMovie86Vm';

interface CanvasProps {
    vm: Movie86Vm | null;
    tick: VmTick | null;
    movie86: Movie86Wrapper | null;
}

/**
 * Active framebuffer canvas. Mirrors `movie86/wasm/index.html`'s
 * "render only the active mode" rule: ELFs that don't `int 0x10` (or
 * mov-only equivalent) show no canvas at all. The CSS scales the
 * pixel-art-style output up to ~240 px on the long side.
 */
export function Canvas({ vm, tick, movie86 }: CanvasProps) {
    const canvasRef = useRef<HTMLCanvasElement | null>(null);
    const imageDataRef = useRef<ImageData | null>(null);
    const lastModeRef = useRef<number | null>(null);

    const active = tick?.activeVideoMode ?? null;
    const mode = useMemo(() => {
        if (active == null || !movie86) return null;
        return movie86.modeForNumber(active) ?? null;
    }, [active, movie86]);

    useEffect(() => {
        if (!mode || !canvasRef.current) {
            imageDataRef.current = null;
            lastModeRef.current = null;
            return;
        }
        if (lastModeRef.current !== mode.modeNumber) {
            const ctx = canvasRef.current.getContext('2d');
            if (!ctx) return;
            imageDataRef.current = new ImageData(mode.width, mode.height);
            lastModeRef.current = mode.modeNumber;
        }
        if (!vm) return;
        const data = vm.readMem(mode.addr, mode.byteLength);
        const ctx = canvasRef.current.getContext('2d');
        if (!ctx || !imageDataRef.current) return;
        if (data.length === mode.byteLength) {
            imageDataRef.current.data.set(data);
            ctx.putImageData(imageDataRef.current, 0, 0);
        } else {
            ctx.fillStyle = '#000';
            ctx.fillRect(0, 0, mode.width, mode.height);
        }
    }, [vm, tick, mode]);

    if (!mode) {
        return (
            <p className="text-xs text-muted-foreground">
                (no video mode set — guest must call{' '}
                <code>mov ax, NN ; int 0x10</code> or the mov-only ABI
                equivalent first)
            </p>
        );
    }
    const scale = Math.max(1, Math.floor(240 / Math.max(mode.width, mode.height)));
    return (
        <div className="flex flex-col gap-2">
            <p className="text-xs text-muted-foreground tabular-nums">
                {mode.id} (<code>0x{mode.modeNumber.toString(16)}</code>) @ 0x
                {mode.addr.toString(16).padStart(8, '0')} ·{' '}
                {mode.byteLength.toLocaleString()} B
            </p>
            <canvas
                ref={canvasRef}
                width={mode.width}
                height={mode.height}
                style={{
                    width: `${mode.width * scale}px`,
                    height: `${mode.height * scale}px`,
                    imageRendering: 'pixelated',
                    background: '#000',
                }}
                className="border self-start"
                data-testid="canvas"
            />
        </div>
    );
}
