# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

The repo backs the `x86.mov` site. Each subproject lives in its own directory at the top level and carries its own `CLAUDE.md` with the architecture, conventions, and gotchas that matter when working in it — read those before touching files inside.

## Conventions

- **TDD-driven development.** New behaviour starts with a failing test, then implementation; intentional codegen / output changes update the relevant golden files in the same commit. Silently regenerating goldens to make a failing test pass defeats the point.
