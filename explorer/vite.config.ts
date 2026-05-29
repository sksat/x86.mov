import { defineConfig, type Connect, type Plugin } from 'vite';
import react from '@vitejs/plugin-react';
import fs from 'node:fs';
import path from 'node:path';

// Deployment target is `dist/explorer/` at the repo root, mirrored by
// `scripts/stage-deploy.sh`. `base: './'` produces URL-relative asset
// references in the built HTML so the bundle works at both
// `https://x86.mov/explorer/` and PR-preview subpaths without
// needing a rebuild per environment.
//
// The cross-subproject wasm wrappers (`../movfuscator-wasm/movfuscator.mjs`,
// `../movie86/wasm/movie86.mjs`, `../llvm-mov/wasm/llvm-mov.mjs`) and their
// `build/browser/` siblings live outside this Vite root. We don't bundle
// them — they're loaded at runtime via dynamic import from a deploy-time
// relative path so the giant clang.wasm chunks stay in their own
// subproject's URL space (the deploy chunks + caches them under their
// hashed filenames). `server.fs.allow` opens the parent for dev-time
// serving; `optimizeDeps.exclude` keeps Vite's prebundler from trying
// to crawl them.

// Dev-only middleware: the explorer page references sibling subprojects
// via the same URLs they get on the deployed site
// (`/movfuscator-wasm/...`, `/movie86/...`, `/llvm-mov/...`), but at dev
// time the bytes live one level up in the source tree, with the wrappers
// nested under `wasm/` for movie86 and llvm-mov. This middleware maps
// the deploy URLs back to source-tree paths so `npm run dev` works
// against the worktree without manual symlinks.
const SIBLING_DEV_MAP: Record<string, string> = {
    '/movfuscator-wasm/': '../movfuscator-wasm/',
    '/movie86/':           '../movie86/wasm/',
    '/llvm-mov/':          '../llvm-mov/wasm/',
};

function siblingSubprojects(): Plugin {
    return {
        name: 'x86mov-sibling-subprojects',
        configureServer(server) {
            const handler: Connect.NextHandleFunction = (req, res, next) => {
                const url = req.url ?? '';
                for (const [prefix, srcPrefix] of Object.entries(SIBLING_DEV_MAP)) {
                    if (!url.startsWith(prefix)) continue;
                    const rel = url.slice(prefix.length).split('?')[0]!.split('#')[0]!;
                    const absPath = path.resolve(__dirname, srcPrefix, rel);
                    // server.fs.allow scoping check: absPath must stay
                    // within the parent worktree.
                    const allowedRoot = path.resolve(__dirname, '..');
                    if (!absPath.startsWith(allowedRoot + path.sep)) {
                        return next();
                    }
                    fs.stat(absPath, (err, stat) => {
                        if (err || !stat.isFile()) return next();
                        const ext = path.extname(absPath).toLowerCase();
                        const ctype = ext === '.mjs' || ext === '.js'
                            ? 'application/javascript'
                            : ext === '.wasm'
                                ? 'application/wasm'
                                : ext === '.json'
                                    ? 'application/json'
                                    : ext === '.css'
                                        ? 'text/css'
                                        : 'application/octet-stream';
                        res.setHeader('Content-Type', ctype);
                        fs.createReadStream(absPath).pipe(res);
                    });
                    return;
                }
                return next();
            };
            // Run before Vite's built-in static handler so the deploy
            // URLs win over any accidental same-name files in /public/.
            server.middlewares.use(handler);
        },
    };
}

export default defineConfig({
    base: './',
    resolve: {
        alias: {
            '@': path.resolve(__dirname, './src'),
        },
    },
    plugins: [react(), siblingSubprojects()],
    server: {
        fs: {
            allow: [path.resolve(__dirname, '..')],
        },
    },
    optimizeDeps: {
        // These are loaded at runtime via dynamic import with an
        // absolute /<subproject>/ URL. Don't let the prebundler chase
        // them — it would try to resolve their internal
        // `./build/browser/*.js` imports against a path that doesn't
        // exist until each subproject runs its own `make build`.
        exclude: [
            'movfuscator-wasm',
            'movie86-wasm',
            'llvm-mov-wasm',
        ],
    },
    build: {
        outDir: '../dist/explorer',
        emptyOutDir: true,
        sourcemap: true,
        target: 'es2022',
    },
});
