/// <reference types="vite/client" />

// Side-effect CSS imports — Vite handles them at build time; the
// declaration silences TS's module-not-found warning.
declare module '*.css';
