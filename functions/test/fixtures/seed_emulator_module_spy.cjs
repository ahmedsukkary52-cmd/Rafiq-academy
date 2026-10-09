// Preloaded with `node --require` by seed_emulator_run.test.mjs: reports at
// exit whether any firebase-admin module was loaded into the CJS cache
// (ESM imports of CJS packages are cached there too).
const Module = require("node:module");
const { sep } = require("node:path");

process.on("exit", () => {
  const marker = `${sep}node_modules${sep}firebase-admin${sep}`;
  const loaded = Object.keys(Module._cache).some((key) => key.includes(marker));
  process.stderr.write(`SEED_SPY firebase-admin-loaded=${loaded}\n`);
});
