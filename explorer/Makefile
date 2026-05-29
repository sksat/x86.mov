# Explorer subproject. Vite + React + TS + Tailwind v3 + shadcn/ui.
# Mirrors the shape of movfuscator-wasm/Makefile and movie86/wasm/Makefile
# so the deploy workflow can treat all three subprojects uniformly.

SHELL := bash
.SHELLFLAGS := -eu -o pipefail -c

NPM ?= npm

# Default target — local dev: ensure deps + serve the Vite dev server.
.PHONY: dev
dev: node_modules
	$(NPM) run dev

.PHONY: serve
serve: build
	$(NPM) run preview -- --host

.PHONY: build
build: node_modules
	$(NPM) run build

.PHONY: typecheck
typecheck: node_modules
	$(NPM) run typecheck

.PHONY: test
test: test-unit

.PHONY: test-unit
test-unit:
	$(NPM) run test:unit

.PHONY: test-e2e
test-e2e: build playwright
	$(NPM) run test:e2e

# Browser binary lives in ~/.cache/ms-playwright after this; cached on
# CI by actions/cache so this becomes a no-op after the first run.
.PHONY: playwright
playwright: node_modules
	npx playwright install --with-deps chromium

.PHONY: stage-deploy
stage-deploy: build
	bash scripts/stage-deploy.sh

.PHONY: clean
clean:
	rm -rf node_modules dist test-results playwright-report

node_modules: package.json
	$(NPM) install
	@touch node_modules
