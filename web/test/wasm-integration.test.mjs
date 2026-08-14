import assert from "node:assert/strict";
import test from "node:test";

import { toList } from "../build/dev/javascript/opto_sync_gleam_web/gleam.mjs";
import {
  Mutation,
  encode_retry_snapshot,
} from "../build/dev/javascript/opto_sync_gleam_web/worker.mjs";
import {
  initSyncer,
  mergeJson,
  version,
} from "../../vendor/opto-sync-clients/syncer.c/bindings/wasm/index.mjs";

test("compiled Gleam batch runs beside the real syncer.c WebAssembly engine", async () => {
  const batch = toList([
    new Mutation("g-2", '{"title":"later"}', 2),
    new Mutation("g-1", '{"title":"first"}', 1),
  ]);
  const encoded = encode_retry_snapshot(batch);

  assert.match(encoded, /^\[{"id":"g-1"/);
  assert.match(encoded, /{"id":"g-2"/);

  await initSyncer();
  const merged = JSON.parse(mergeJson('{"server":true}', '{"gleam":true}'));
  assert.deepEqual(merged, { server: true, gleam: true });
  assert.match(version(), /^0\.2\./);
});

