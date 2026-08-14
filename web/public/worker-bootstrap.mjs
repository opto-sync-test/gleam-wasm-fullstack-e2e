const registration = await navigator.serviceWorker.register("/service-worker.js", {
  type: "module",
});

const ready = await navigator.serviceWorker.ready;
const worker = registration.active ?? ready.active;

window.optoSyncGleam = Object.freeze({
  enqueue(payload) {
    worker?.postMessage({
      type: "OPTO_SYNC_ENQUEUE",
      mutation: { payload: JSON.stringify(payload) },
    });
  },
  wake() {
    worker?.postMessage({ type: "OPTO_SYNC_WAKE" });
  },
});

window.addEventListener("online", () => window.optoSyncGleam.wake());

