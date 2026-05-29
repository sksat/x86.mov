import { defineConfig } from 'vite';
import react from '@vitejs/plugin-react';
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

export default defineConfig({
    base: './',
    resolve: {
        alias: {
            '@': path.resolve(__dirname, './src'),
        },
    },
    plugins: [react()],
    server: {
        // Dev: serve the whole worktree so /movfuscator-wasm/... etc.
        // resolve as siblings of the Vite dev URL space.
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
