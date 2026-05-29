import { clsx, type ClassValue } from 'clsx';
import { twMerge } from 'tailwind-merge';

/** shadcn's standard helper — collapses conditional Tailwind classes and
 *  deduplicates conflicting utilities (e.g. `p-2 p-4` → `p-4`). */
export function cn(...inputs: ClassValue[]) {
    return twMerge(clsx(inputs));
}

/** Format a byte length with thousands separators. */
export function fmtBytes(n: number): string {
    return n.toLocaleString();
}

/** 32-bit value as `0xXXXXXXXX`. */
export function fmt32(v: number): string {
    return '0x' + (v >>> 0).toString(16).padStart(8, '0');
}

/** Hex dump a Uint8Array; truncates beyond `maxBytes`. Returns plain
 *  text rows suitable for a <pre> block. */
export function hexDump(bytes: Uint8Array, maxBytes = 4096): string {
    const limit = Math.min(bytes.length, maxBytes);
    const lines: string[] = [];
    for (let i = 0; i < limit; i += 16) {
        const chunk = bytes.subarray(i, i + 16);
        const offset = i.toString(16).padStart(8, '0');
        const hex = Array.from(chunk)
            .map((b) => b.toString(16).padStart(2, '0'))
            .join(' ')
            .padEnd(48);
        const ascii = Array.from(chunk)
            .map((b) => (b >= 0x20 && b < 0x7f ? String.fromCharCode(b) : '.'))
            .join('');
        lines.push(`${offset}  ${hex}  ${ascii}`);
    }
    if (bytes.length > limit) {
        const more = (bytes.length - limit).toLocaleString();
        lines.push('', `... ${more} more bytes truncated`);
    }
    return lines.join('\n');
}

/** Trigger a browser file download for in-memory bytes. Used by
 *  download-{ll,s,o,elf} buttons. */
export function downloadBlob(name: string, bytes: Uint8Array | string, mime: string) {
    // Cast to BlobPart — TS 5.7 narrows Uint8Array's buffer type to
    // ArrayBufferLike which includes SharedArrayBuffer, but Blob's
    // BlobPart union only accepts the plain ArrayBuffer variant. The
    // runtime cast is safe; we never construct SharedArrayBuffer-backed
    // Uint8Arrays here.
    const blob = new Blob([bytes as BlobPart], { type: mime });
    const url = URL.createObjectURL(blob);
    const a = document.createElement('a');
    a.href = url;
    a.download = name;
    a.click();
    setTimeout(() => URL.revokeObjectURL(url), 0);
}
