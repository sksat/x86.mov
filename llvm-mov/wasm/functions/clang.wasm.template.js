// Cloudflare Pages Function: same-origin proxy for clang.wasm.
//
// clang.wasm is hosted on a GitHub Release because it exceeds CF Pages'
// 25 MiB/file upload limit, but the release endpoint serves the asset
// without CORS headers — a cross-origin `fetch()` from the demo origin
// is blocked by the browser and the wasm loader hangs.
//
// This function lives at the path Emscripten's default loader expects
// (`./build/clang.wasm` relative to clang.js, i.e.
// `/llvm-mov/build/clang.wasm`). It server-side-fetches the release
// asset and re-emits it with `Access-Control-Allow-Origin: *` and a
// proper `Content-Type: application/wasm`.
//
// The release URL is templated in by scripts/stage-deploy.sh at deploy
// time (see the `__CLANG_WASM_RELEASE_URL__` placeholder below). This
// file stays out of the static-asset path the demo serves, so the
// substitution only affects the deployed artefact.

const RELEASE_URL = '__CLANG_WASM_RELEASE_URL__';

export async function onRequest(context) {
    // CORS preflight — wasm streaming compile may issue one even though
    // a simple GET wouldn't normally need it.
    if (context.request.method === 'OPTIONS') {
        return new Response(null, {
            status: 204,
            headers: {
                'Access-Control-Allow-Origin': '*',
                'Access-Control-Allow-Methods': 'GET, HEAD, OPTIONS',
                'Access-Control-Max-Age': '86400',
            },
        });
    }

    const upstream = await fetch(RELEASE_URL, {
        // GH redirects to release-assets.githubusercontent.com (Azure
        // blob). Follow it transparently.
        redirect: 'follow',
        // Forward Range so the browser's streaming compile can resume.
        headers: forwardRangeHeaders(context.request),
    });

    if (!upstream.ok) {
        return new Response(`upstream ${upstream.status} ${upstream.statusText}`, {
            status: 502,
            headers: { 'Access-Control-Allow-Origin': '*' },
        });
    }

    const headers = new Headers();
    headers.set('Content-Type', 'application/wasm');
    headers.set('Access-Control-Allow-Origin', '*');
    headers.set('Cache-Control', 'public, max-age=86400, immutable');
    // Preserve length/range info from upstream so big fetches behave.
    for (const h of ['Content-Length', 'Content-Range', 'Accept-Ranges', 'ETag']) {
        const v = upstream.headers.get(h);
        if (v) headers.set(h, v);
    }

    return new Response(upstream.body, {
        status: upstream.status,
        headers,
    });
}

function forwardRangeHeaders(req) {
    const out = new Headers();
    for (const h of ['Range', 'If-Range', 'If-None-Match']) {
        const v = req.headers.get(h);
        if (v) out.set(h, v);
    }
    return out;
}
