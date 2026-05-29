import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';
import { CodeViewer } from '@/components/CodeViewer';
import { ElfSummary } from '@/components/ElfSummary';
import type { CompileResult } from '@/lib/compiler';
import type { MovfuscatorWrapper } from '@/lib/wrappers';

interface CompileOutputProps {
    result: CompileResult | null;
    /** When non-null, displayed above the IR pane as a status / error. */
    statusMessage: string | null;
    /** ELF header parser, forwarded into the binary pane. Lazy-loaded
     *  with movfuscator-wasm. */
    parseElfHeader?: MovfuscatorWrapper['parseElfHeader'];
}

/**
 * The three middle panes — IR | asm | binary. Each is a Card so the
 * Compiler-Explorer aesthetic carries through; the IR pane is hidden
 * (returns null inside the grid) when the active compiler doesn't
 * surface IR (movfuscator).
 */
export function CompileOutput({
    result,
    statusMessage,
    parseElfHeader,
}: CompileOutputProps) {
    const showIr = !result || result.ir !== null;
    return (
        <div
            className="grid gap-3"
            style={{
                gridTemplateColumns: showIr
                    ? 'repeat(3, minmax(0, 1fr))'
                    : 'repeat(2, minmax(0, 1fr))',
            }}
        >
            {showIr && (
                <Card className="flex flex-col">
                    <CardHeader className="pb-2">
                        <CardTitle className="text-base">LLVM IR</CardTitle>
                        <CardDescription>
                            clang -emit-llvm output (mov-* triple forced
                            downstream).
                        </CardDescription>
                    </CardHeader>
                    <CardContent className="flex-1 min-h-0 pt-0">
                        <CodeViewer
                            value={result?.ir ?? statusMessage ?? '(compile to populate)'}
                            language="llvm"
                            height={480}
                            data-testid="ir-pane"
                        />
                    </CardContent>
                </Card>
            )}

            <Card className="flex flex-col">
                <CardHeader className="pb-2">
                    <CardTitle className="text-base">mov-only asm</CardTitle>
                    <CardDescription>
                        x86-32 GAS syntax. Both pipelines emit a
                        byte-identical `.s` shape for the as.wasm / ld.wasm tail.
                    </CardDescription>
                </CardHeader>
                <CardContent className="flex-1 min-h-0 pt-0">
                    <CodeViewer
                        value={result?.asm ?? statusMessage ?? '(compile to populate)'}
                        language="gas"
                        height={480}
                        data-testid="asm-pane"
                    />
                </CardContent>
            </Card>

            <ElfSummary
                elf={result?.elf ?? null}
                obj={result?.obj ?? null}
                parseElfHeader={parseElfHeader}
            />
        </div>
    );
}
