// Preloaded (`node --import`) into audit CLI runs that must never load the
// Firebase SDK: resolving any firebase-admin / @google-cloud module throws.
import { registerHooks } from "node:module";

registerHooks({
  resolve(specifier, context, nextResolve) {
    if (/^(firebase-admin|@google-cloud\/|google-gax)/.test(specifier)) {
      console.error("firebase-admin load attempted");
      throw new Error("firebase-admin must not be loaded");
    }
    return nextResolve(specifier, context);
  },
});
