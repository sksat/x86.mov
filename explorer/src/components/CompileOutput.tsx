import {
    Card,
    CardContent,
    CardDescription,
    CardHeader,
    CardTitle,
} from '@/components/ui/card';
import {
    Tabs,
    TabsContent,
    TabsList,
    TabsTrigger,
} from '@/components/ui/tabs';
import { CodeViewer } from '@/components/CodeViewer';
import { ElfSummary } from '@/components/ElfSummary';
import type { CompileResult } from '@/lib/compiler';
import type { MovfuscatorWrapper } from '@/lib/wrappers';

interface CompileOutputProps {
    result: CompileResult | null;
    /** When non-null, displayed inside an empty pane as a status / error
     *  hint instead of the placeholder text. */
    statusMessage: string | null;
    /** ELF header parser, forwarded into the binary tab. Lazy-loaded
     *  with movfuscator-wasm. */
    parseElfHeader?: MovfuscatorWrapper['parseElfHeader'];
    /** Column height in pixels — kept consistent with the SourceEditor
     *  / IRPane heights so the three-column layout stays flat. */
    height?: number;
}

/**
 * Right-most column in the Compiler-Explorer-style strip. Holds the
 * mov-only asm and the linked binary in **one** tabbed pane so the
 * horizontal real estate goes to source / IR / output equally. Tabs
 * default to `asm` because that's what the user is here for — the
 * binary view is a follow-up step (download / hex inspect / disasm).
 *
 * The asm tab uses CodeMirror's gas language. The binary tab shows
 * the ELF32 header summary + hex dump + Download buttons (same shape
 * as the old standalone ElfSummary card).
 */
export function CompileOutput({
    result,
    statusMessage,
    parseElfHeader,
    height = 480,
}: CompileOutputProps) {
    return (
        <Card className="flex flex-col h-full">
            <CardHeader className="pb-2">
                <CardTitle className="text-base">Output</CardTitle>
                <CardDescription>
                    mov-only x86 assembly (GAS syntax) and the linked
                    ELF32 binary. Both pipelines emit a byte-identical
                    `.s` shape for the as.wasm / ld.wasm tail.
                </CardDescription>
            </CardHeader>
            <CardContent className="flex-1 min-h-0 pt-0 flex flex-col">
                <Tabs defaultValue="asm" className="flex-1 flex flex-col">
                    <TabsList className="self-start mb-2" data-testid="output-tabs">
                        <TabsTrigger value="asm" data-testid="output-tab-asm">
                            asm
                        </TabsTrigger>
                        <TabsTrigger value="binary" data-testid="output-tab-binary">
                            binary
                        </TabsTrigger>
                    </TabsList>
                    <TabsContent value="asm" className="flex-1 min-h-0 m-0">
                        <CodeViewer
                            value={
                                result?.asm ??
                                statusMessage ??
                                '(compile to populate)'
                            }
                            language="gas"
                            height={height}
                            data-testid="asm-pane"
                        />
                    </TabsContent>
                    <TabsContent value="binary" className="flex-1 min-h-0 m-0">
                        <ElfSummary
                            elf={result?.elf ?? null}
                            obj={result?.obj ?? null}
                            parseElfHeader={parseElfHeader}
                            height={height}
                        />
                    </TabsContent>
                </Tabs>
            </CardContent>
        </Card>
    );
}
