# Gleam + WebAssembly full-stack OptoSync E2E

This fixture tests both Gleam runtimes used by a real full-stack application:

- a BEAM/Mist server uses the official OptoSync Gleam protocol client and the
  native `syncer.c` binding from the recursively pinned client submodule;
- a JavaScript-targeted Gleam worker creates the immutable, ordered retry body;
- a module service worker persists mutations in IndexedDB, initializes the real
  `syncer.c` WebAssembly build, and sends the exact Gleam body concurrently on
  upload and realtime lanes;
- Background Sync, Periodic Background Sync, explicit app wake, and online wake
  all retry without deleting the durable batch after a partial delivery.

The Mist server serves the compiled Gleam module tree and the upstream WASM
module tree directly, so relative ES-module imports resolve the same way they do
in a deployed app. Its path validation prevents asset traversal.

## Run locally

```sh
git submodule update --init --recursive
(cd web && gleam build --target javascript && gleam test --target javascript)
(cd web && node --test test/wasm-integration.test.mjs)
(cd server && gleam test && gleam run)
```

Then open <http://127.0.0.1:4000>. The page registers the module service worker;
`window.optoSyncGleam.enqueue(payload)` adds an offline mutation and
`window.optoSyncGleam.wake()` requests a flush.

No hosted Supabase or other secret is used by this fixture. The separate
Laravel/Livewire fixture boots Supabase locally in CI for its database and
Realtime contract.

