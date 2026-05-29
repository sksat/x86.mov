import { Play, Loader2 } from 'lucide-react';
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
import type { CompilerId, OptLevel } from '@/lib/compiler';

interface CompilerControlsProps {
    compiler: CompilerId;
    onCompilerChange: (next: CompilerId) => void;
    optLevel: OptLevel;
    onOptLevelChange: (next: OptLevel) => void;
    extraFlags: string;
    onExtraFlagsChange: (next: string) => void;
    onCompile: () => void;
    busy: boolean;
}

/**
 * Top control bar — picks compiler + opt level + extra flags, fires
 * Compile. Each control is reusable in isolation (Select / Input /
 * Button are shadcn primitives) so a follow-up that adds e.g. a
 * preset picker can drop in alongside without refactoring this row.
 *
 * Layout: flex-wrap so on a 1280 px screen everything sits on one row;
 * on mobile the controls stack vertically per Tailwind's default
 * gap-based wrap.
 */
export function CompilerControls({
    compiler,
    onCompilerChange,
    optLevel,
    onOptLevelChange,
    extraFlags,
    onExtraFlagsChange,
    onCompile,
    busy,
}: CompilerControlsProps) {
    const isLlvm = compiler === 'llvm-mov';
    return (
        <div className="flex flex-wrap items-end gap-3">
            <div className="flex flex-col gap-1.5">
                <Label htmlFor="compiler">Compiler</Label>
                <Select
                    value={compiler}
                    onValueChange={(v) => onCompilerChange(v as CompilerId)}
                >
                    <SelectTrigger id="compiler" className="w-[240px]" data-testid="compiler-select">
                        <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="movfuscator">
                            movfuscator-wasm (LCC + mov backend)
                        </SelectItem>
                        <SelectItem value="llvm-mov">
                            llvm-mov clang (LLVM 22 + mov target)
                        </SelectItem>
                    </SelectContent>
                </Select>
            </div>

            <div className="flex flex-col gap-1.5">
                <Label htmlFor="opt-level">Opt</Label>
                <Select
                    value={optLevel}
                    onValueChange={(v) => onOptLevelChange(v as OptLevel)}
                    disabled={!isLlvm}
                >
                    <SelectTrigger id="opt-level" className="w-[120px]" data-testid="opt-level-select">
                        <SelectValue />
                    </SelectTrigger>
                    <SelectContent>
                        <SelectItem value="0">-O0</SelectItem>
                        <SelectItem value="1">-O1</SelectItem>
                        <SelectItem value="2">-O2</SelectItem>
                        <SelectItem value="3">-O3</SelectItem>
                        <SelectItem value="s">-Os</SelectItem>
                        <SelectItem value="z">-Oz</SelectItem>
                    </SelectContent>
                </Select>
            </div>

            <div className="flex flex-col gap-1.5 grow min-w-[280px]">
                <Label htmlFor="extra-flags">
                    {isLlvm
                        ? 'Clang flags (space-separated)'
                        : 'movfuscator has no -O flags'}
                </Label>
                <Input
                    id="extra-flags"
                    value={extraFlags}
                    onChange={(e) => onExtraFlagsChange(e.target.value)}
                    placeholder={
                        isLlvm
                            ? '-DFOO=1 -fno-builtin'
                            : '(disabled for movfuscator)'
                    }
                    disabled={!isLlvm}
                    data-testid="extra-flags"
                />
            </div>

            <Button
                onClick={onCompile}
                disabled={busy}
                className="ml-auto"
                data-testid="compile-button"
            >
                {busy ? (
                    <Loader2 className="h-4 w-4 animate-spin" />
                ) : (
                    <Play className="h-4 w-4" />
                )}
                {busy ? 'Compiling…' : 'Compile'}
            </Button>
        </div>
    );
}
