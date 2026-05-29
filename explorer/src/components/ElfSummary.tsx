import { Button } from '@/components/ui/button';
import { Download } from 'lucide-react';
import { downloadBlob, fmtBytes, hexDump } from '@/lib/utils';

interface ElfSummaryProps {
    elf: Uint8Array | null;
    obj: Uint8Array | null;
    /** parseElfHeader from movfuscator-wasm. Caller resolves the lazy
     *  import and threads the function in to keep this component pure. */
    parseElfHeader?: (bytes: Uint8Array) => null | { raw: string } | {
        class: 'ELF32';
        data: 'little-endian';
        type: string;
        machine: string;
        entry: string;
        sections: number;
    };
    /** Optional explicit pane height to match the asm tab. Without
     *  this the dump can grow taller than the source/IR columns and
     *  break the flat three-column row. */
    height?: number;
}

/**
 * The "binary" tab content. Shows a parsed ELF32 header summary if
 * available, a hex dump of the first ~4 KiB, and Download buttons for
 * the .o (relocatable) and the linked ELF.
 *
 * Previously this was a standalone Card; now it lives inside the
 * CompileOutput Tabs panel so the wrapper is the lean two-section
 * layout (header row + hex dump) — no Card chrome of its own. The
 * CompileOutput card carries the title + description.
 */
export function ElfSummary({
    elf,
    obj,
    parseElfHeader,
    height = 480,
}: ElfSummaryProps) {
    const parsed = elf && parseElfHeader ? parseElfHeader(elf) : null;
    const baseClass =
        'flex flex-col gap-3 font-mono text-xs rounded-md border bg-card p-3';

    return (
        <div
            className={baseClass}
            style={{ height: `${height}px` }}
        >
            <div className="flex items-center justify-between gap-3">
                <span className="text-xs text-muted-foreground">
                    ELF32 header + hex dump (first ~4 KiB).
                </span>
                <div className="flex gap-2">
                    <Button
                        variant="outline"
                        size="sm"
                        onClick={() =>
                            obj && downloadBlob('explorer.o', obj, 'application/x-object')
                        }
                        disabled={!obj}
                    >
                        <Download className="h-3.5 w-3.5" />
                        .o
                    </Button>
                    <Button
                        variant="outline"
                        size="sm"
                        onClick={() =>
                            elf &&
                            downloadBlob('explorer.elf', elf, 'application/x-executable')
                        }
                        disabled={!elf}
                    >
                        <Download className="h-3.5 w-3.5" />
                        ELF
                    </Button>
                </div>
            </div>
            {parsed && 'class' in parsed ? (
                <ElfHeaderTable header={parsed} size={elf ? elf.length : 0} />
            ) : parsed && 'raw' in parsed ? (
                <pre className="rounded border bg-muted/30 p-2 whitespace-pre-wrap">
                    {parsed.raw}
                </pre>
            ) : elf ? (
                <p className="text-muted-foreground">
                    (parser unavailable — load movfuscator-wasm)
                </p>
            ) : (
                <p className="text-muted-foreground">
                    Compile a source to produce an ELF.
                </p>
            )}
            {elf && (
                <pre
                    className="rounded border bg-muted/30 p-2 overflow-auto flex-1 min-h-0 whitespace-pre"
                    data-testid="elf-hexdump"
                >
                    {hexDump(elf)}
                </pre>
            )}
        </div>
    );
}

function ElfHeaderTable({
    header,
    size,
}: {
    header: {
        class: 'ELF32';
        data: 'little-endian';
        type: string;
        machine: string;
        entry: string;
        sections: number;
    };
    size: number;
}) {
    const rows: [string, string][] = [
        ['size', `${fmtBytes(size)} bytes`],
        ['class', header.class],
        ['data', header.data],
        ['type', header.type],
        ['machine', header.machine],
        ['entry', header.entry],
        ['sections', header.sections.toString()],
    ];
    return (
        <dl className="grid grid-cols-[max-content_1fr] gap-x-4 gap-y-1 text-xs">
            {rows.map(([k, v]) => (
                <div key={k} className="contents">
                    <dt className="text-muted-foreground">{k}</dt>
                    <dd>{v}</dd>
                </div>
            ))}
        </dl>
    );
}
