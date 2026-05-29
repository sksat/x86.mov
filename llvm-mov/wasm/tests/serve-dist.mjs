// Mini static server that mimics the bits of Cloudflare Pages our
// deploy depends on:
//   - Serves files from `../../dist/` (repo-root `dist/`).
//   - Parses `dist/_headers` and applies the matching rules to each
//     response, so `Content-Encoding: gzip` etc. land on the
//     clang.wasm-{hash}.gz URL the same way they do in prod.
//   - Sets correct MIME types for .wasm / .mjs / .js / .html so
//     Emscripten's streaming compile and ES-module imports work.
//
// Used by `make test-e2e-dist` to drive demo.spec.js against the
// staged deploy contents (with gzip) instead of the raw source tree.
// CI runs both paths.

import { createServer } from 'node:http';
import { readFileSync, statSync, existsSync } from 'node:fs';
import { join, extname, dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const here = dirname(fileURLToPath(import.meta.url));
// tests/ → wasm/ → llvm-mov/ → repo root → dist/
const distRoot = resolve(here, '..', '..', '..', 'dist');
const port = parseInt(process.env.PORT || '8089', 10);
// `SERVE_DIST_STRIP_ENCODING=1` drops `Content-Encoding` from every
// applied _headers rule. We use it to fake a browser that lacks
// native `Content-Encoding: zstd` support: the raw zstd bytes flow
// through, and the wrapper's magic-byte check has to route them
// through fzstd. Without this knob the production-shape E2E never
// exercises the JS-decompression path on a CI runner whose Chromium
// natively decodes zstd.
const stripEncoding = process.env.SERVE_DIST_STRIP_ENCODING === '1';

const MIME = {
    '.html': 'text/html; charset=utf-8',
    '.js':   'application/javascript',
    '.mjs':  'application/javascript',
    '.wasm': 'application/wasm',
    '.json': 'application/json',
    '.gz':   'application/octet-stream', // overridden by _headers
};

// Parse the CF Pages `_headers` file. Each rule is a path pattern
// followed by indented header lines until a blank line:
//
//   /llvm-mov/build/clang.wasm-*
//     Content-Encoding: gzip
//     Cache-Control: ...
//
// We mirror CF Pages' matching: a single trailing `*` matches any
// suffix; otherwise the pattern is a literal match.
function parseHeadersFile(path) {
    if (!existsSync(path)) return [];
    const text = readFileSync(path, 'utf8');
    const rules = [];
    let current = null;
    for (const raw of text.split('\n')) {
        const trimmedEnd = raw.replace(/\s+$/, '');
        if (trimmedEnd === '') {
            if (current) { rules.push(current); current = null; }
            continue;
        }
        if (/^\s/.test(raw)) {
            const m = trimmedEnd.match(/^\s+([^:]+):\s*(.*)$/);
            if (m && current) current.headers[m[1].trim()] = m[2];
        } else {
            if (current) rules.push(current);
            current = { pattern: trimmedEnd, headers: {} };
        }
    }
    if (current) rules.push(current);
    return rules;
}

function matchPattern(urlPath, pattern) {
    if (pattern.endsWith('*')) {
        return urlPath.startsWith(pattern.slice(0, -1));
    }
    return urlPath === pattern;
}

const headerRules = parseHeadersFile(join(distRoot, '_headers'));

function resolvePath(urlPath) {
    // Strip query / fragment, decode percent-escapes, refuse traversal.
    const cleaned = decodeURIComponent(urlPath.split(/[?#]/)[0]);
    if (cleaned.includes('..')) return null;
    const fsPath = join(distRoot, cleaned);
    if (!fsPath.startsWith(distRoot)) return null;
    if (existsSync(fsPath) && statSync(fsPath).isDirectory()) {
        return join(fsPath, 'index.html');
    }
    return fsPath;
}

createServer((req, res) => {
    const fsPath = resolvePath(req.url || '/');
    if (!fsPath || !existsSync(fsPath)) {
        res.writeHead(404, { 'Content-Type': 'text/plain' });
        res.end('404 not found\n');
        return;
    }
    const body = readFileSync(fsPath);
    const headers = {};
    const mime = MIME[extname(fsPath)];
    if (mime) headers['Content-Type'] = mime;
    // _headers rules win over the MIME default.
    for (const rule of headerRules) {
        if (matchPattern(req.url || '/', rule.pattern)) {
            for (const [k, v] of Object.entries(rule.headers)) {
                if (stripEncoding && k.toLowerCase() === 'content-encoding') continue;
                headers[k] = v;
            }
        }
    }
    // Node won't auto-set Content-Length when we pass a Buffer to .end,
    // but the playwright test paths benefit from one being present (we
    // use it in the wrapper to drive the download progress bar).
    headers['Content-Length'] = String(body.byteLength);
    res.writeHead(200, headers);
    res.end(body);
}).listen(port, '127.0.0.1', () => {
    const enc = stripEncoding ? ', stripping Content-Encoding (fzstd path)' : '';
    console.log(`serve-dist on http://127.0.0.1:${port}/ (root=${distRoot}, _headers rules=${headerRules.length}${enc})`);
});
