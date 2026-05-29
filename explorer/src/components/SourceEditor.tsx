import CodeMirror from '@uiw/react-codemirror';
import { cpp } from '@codemirror/lang-cpp';
import { EditorView } from '@codemirror/view';
import { useMemo } from 'react';
import { cn } from '@/lib/utils';

interface SourceEditorProps {
    value: string;
    onChange: (next: string) => void;
    className?: string;
    /** Pixel height — fixed to keep the layout from shifting as the
     *  user types longer programs. Defaults to 480 to roughly match the
     *  paired IR + asm panes. */
    height?: number;
    readOnly?: boolean;
    /** Used by the E2E test to target the textarea inside the CodeMirror
     *  shadow tree. */
    'data-testid'?: string;
}

/**
 * The C source pane. Uses CodeMirror v6 with the cpp language; wired
 * to a controlled `value` so the parent owns the source and can persist
 * to URL / localStorage / pass into the compiler.
 */
export function SourceEditor({
    value,
    onChange,
    className,
    height = 480,
    readOnly,
    ...rest
}: SourceEditorProps) {
    const extensions = useMemo(
        () => [
            cpp(),
            // Wrap long printf strings instead of horizontal-scrolling
            // them — the panes are narrow on a typical 1440 px layout.
            EditorView.lineWrapping,
        ],
        [],
    );
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
                onChange={onChange}
                extensions={extensions}
                height={`${height}px`}
                editable={!readOnly}
                basicSetup={{
                    lineNumbers: true,
                    foldGutter: true,
                    highlightActiveLine: true,
                    bracketMatching: true,
                    closeBrackets: true,
                    autocompletion: false,
                }}
            />
        </div>
    );
}
