import { initSyncer, mergeJson, version } from "/wasm/index.mjs";
import { toList } from "/gleam/opto_sync_gleam_web/gleam.mjs";
import {
  Mutation,
  encode_retry_snapshot,
} from "/gleam/opto_sync_gleam_web/worker.mjs";

const DATABASE = "opto-sync-gleam-wasm";
const STORE = "mutations";
const TAG = "opto-sync-gleam-multiplex";

function openDatabase() {
  return new Promise((resolve, reject) => {
    const request = indexedDB.open(DATABASE, 1);
    request.onupgradeneeded = () => {
      request.result.createObjectStore(STORE, { keyPath: "id" });
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => reject(request.error);
  });
}

async function transact(mode, operation) {
  const database = await openDatabase();
  return new Promise((resolve, reject) => {
    const transaction = database.transaction(STORE, mode);
    const result = operation(transaction.objectStore(STORE));
    transaction.oncomplete = () => {
      database.close();
      resolve(result instanceof IDBRequest ? result.result : result);
    };
    transaction.onerror = () => reject(transaction.error);
    transaction.onabort = () => reject(transaction.error);
  });
}

async function enqueue(input) {
  const mutation = Object.freeze({
    id: input.id ?? crypto.randomUUID(),
    payload: input.payload,
    createdAt: input.createdAt ?? Date.now(),
  });
  await transact("readwrite", (store) => store.put(mutation));
  await self.registration.sync?.register(TAG);
}

async function send(lane, body, syncerVersion) {
  const response = await fetch(`/api/sync/${lane}`, {
    method: "POST",
    headers: {
      "content-type": "application/json",
      "x-opto-sync-lane": lane,
      "x-syncer-wasm-version": syncerVersion,
    },
    body,
  });
  if (!response.ok) throw new Error(`${lane} failed with ${response.status}`);
  return response.json();
}

async function flush() {
  const rows = await transact("readonly", (store) => store.getAll());
  if (rows.length === 0) return;

  const immutableRows = Object.freeze(rows.map((row) => Object.freeze({ ...row })));
  const gleamBatch = toList(
    immutableRows.map((row) => new Mutation(row.id, row.payload, row.createdAt)),
  );
  const body = encode_retry_snapshot(gleamBatch);

  await initSyncer();
  const wasmProbe = mergeJson(
    '{"runtime":"gleam","queued":0}',
    JSON.stringify({ runtime: "gleam", queued: immutableRows.length }),
  );
  if (!wasmProbe.includes('"runtime":"gleam"')) {
    throw new Error("WebAssembly reconciliation probe failed");
  }

  const outcomes = await Promise.allSettled([
    send("upload", body, version()),
    send("realtime", body, version()),
  ]);
  if (outcomes.some((outcome) => outcome.status === "rejected")) {
    throw new Error("partial multiplex delivery; exact IndexedDB batch retained");
  }

  await transact("readwrite", (store) => {
    for (const mutation of immutableRows) store.delete(mutation.id);
  });
}

self.addEventListener("install", (event) => event.waitUntil(self.skipWaiting()));
self.addEventListener("activate", (event) => event.waitUntil(self.clients.claim()));
self.addEventListener("message", (event) => {
  if (event.data?.type === "OPTO_SYNC_ENQUEUE") event.waitUntil(enqueue(event.data.mutation));
  if (event.data?.type === "OPTO_SYNC_WAKE") event.waitUntil(flush());
});
self.addEventListener("sync", (event) => {
  if (event.tag === TAG) event.waitUntil(flush());
});
self.addEventListener("periodicsync", (event) => {
  if (event.tag === TAG) event.waitUntil(flush());
});

