import CodeMirror from '@uiw/react-codemirror';
import { EditorState } from '@codemirror/state';
import { EditorView } from '@codemirror/view';
import { StreamLanguage } from '@codemirror/language';
import { gas } from '@codemirror/legacy-modes/mode/gas';
import { useMemo } from 'react';
import { cn } from '@/lib/utils';

export type CodeViewerLanguage = 'gas' | 'llvm' | 'plain';

interface CodeViewerProps {
    value: string;
    language: CodeViewerLanguage;
    className?: string;
    height?: number;
    'data-testid'?: string;
}

// Minimal LLVM IR highlighter — a real grammar is overkill for a
// read-only display pane. Highlights:
//   - keywords / common opcodes
//   - registers (`%name`)
//   - globals (`@name`)
//   - integer / float literals
//   - line comments (`;`)
// CodeMirror's StreamLanguage gives us this with a few lines.
const LLVM_KEYWORDS = new Set([
    'define', 'declare', 'global', 'constant', 'private', 'internal',
    'external', 'linkonce', 'weak', 'common', 'appending', 'dllimport',
    'dllexport', 'thread_local', 'datalayout', 'target', 'triple',
    'source_filename', 'attributes', 'metadata',
    'i1', 'i8', 'i16', 'i32', 'i64', 'i128', 'half', 'float', 'double',
    'fp80', 'fp128', 'void', 'label', 'token', 'x86_mmx',
    'ptr', 'getelementptr', 'inbounds',
    'true', 'false', 'null', 'undef', 'poison', 'zeroinitializer',
    'nocapture', 'readonly', 'readnone', 'noalias', 'nonnull',
    'signext', 'zeroext', 'inreg', 'sret', 'noinline', 'alwaysinline',
    'inlinehint', 'optsize', 'optnone', 'noredzone', 'noimplicitfloat',
    'nounwind', 'uwtable', 'speculatable', 'mustprogress', 'willreturn',
    'norecurse', 'nofree', 'memory', 'sanitize_address',
    'add', 'sub', 'mul', 'sdiv', 'udiv', 'srem', 'urem',
    'fadd', 'fsub', 'fmul', 'fdiv', 'frem',
    'shl', 'lshr', 'ashr', 'and', 'or', 'xor',
    'icmp', 'fcmp', 'phi', 'select',
    'call', 'tail', 'musttail', 'ret', 'br', 'switch', 'invoke',
    'alloca', 'load', 'store', 'fence', 'cmpxchg', 'atomicrmw',
    'bitcast', 'trunc', 'zext', 'sext', 'fptrunc', 'fpext',
    'fptoui', 'fptosi', 'uitofp', 'sitofp', 'ptrtoint', 'inttoptr',
    'extractelement', 'insertelement', 'shufflevector',
    'extractvalue', 'insertvalue',
    'eq', 'ne', 'ugt', 'uge', 'ult', 'ule', 'sgt', 'sge', 'slt', 'sle',
    'oeq', 'one', 'ogt', 'oge', 'olt', 'ole', 'ord', 'uno',
    'aggregate', 'unnamed_addr', 'local_unnamed_addr', 'align', 'volatile',
    'nsw', 'nuw', 'exact', 'fast', 'arcp', 'nnan', 'ninf', 'nsz',
]);

const llvmLanguage = StreamLanguage.define({
    name: 'llvm',
    startState: () => ({ inComment: false }),
    token(stream) {
        if (stream.eatSpace()) return null;
        if (stream.match(/;.*/)) return 'comment';
        if (stream.match(/"(?:[^"\\]|\\.)*"/)) return 'string';
        if (stream.match(/[%@][\w.$-]+/)) return 'variableName';
        if (stream.match(/[!][\w.$-]+/)) return 'meta';
        if (stream.match(/-?\d+\.\d+(?:e[-+]?\d+)?/i)) return 'number';
        if (stream.match(/-?0x[0-9a-fA-F]+/)) return 'number';
        if (stream.match(/-?\d+/)) return 'number';
        const ident = stream.match(/[\w.]+/);
        if (ident) {
            const word = (ident as RegExpMatchArray)[0];
            if (LLVM_KEYWORDS.has(word)) return 'keyword';
            return null;
        }
        stream.next();
        return null;
    },
});

/**
 * Read-only code pane. Switches the underlying language extension to
 * one of:
 *   - `gas`   → `.s` mov-only x86 output (movfuscator + llvm-mov tail)
 *   - `llvm`  → LLVM IR (llvm-mov path only)
 *   - `plain` → no highlighting; used for ELF hex dump or status text
 */
export function CodeViewer({ value, language, className, height = 480, ...rest }: CodeViewerProps) {
    const extensions = useMemo(() => {
        const out = [EditorState.readOnly.of(true), EditorView.lineWrapping];
        if (language === 'gas') {
            out.push(StreamLanguage.define(gas));
        } else if (language === 'llvm') {
            out.push(llvmLanguage);
        }
        return out;
    }, [language]);
    return (
        <div
            className={cn(
                'rounded-md border bg-card overflow-hidden font-mono text-sm',
                className,
            )}
            data-testid={rest['data-testid']}
        >
            <CodeMirror
                value={value}
                extensions={extensions}
                height={`${height}px`}
                editable={false}
                basicSetup={{
                    lineNumbers: true,
                    foldGutter: false,
                    highlightActiveLine: false,
                    bracketMatching: false,
                    closeBrackets: false,
                    autocompletion: false,
                }}
            />
        </div>
    );
}
