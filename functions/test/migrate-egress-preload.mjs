// Preloaded (`node --import`) into migration CLI runs started by
// migrate_scripts.emulator.test.mjs: every connection except loopback on the
// ports in MIGRATE_IT_ALLOWED_PORTS is refused before it leaves the process.
import { installEgressGuard } from "../scripts/seed-emulator-egress.mjs";

const ports = (process.env.MIGRATE_IT_ALLOWED_PORTS ?? "")
  .split(",")
  .filter(Boolean)
  .map(Number);
const guard = installEgressGuard({ allowedPorts: ports });
if (!(await guard.selfTest())) {
  console.error("egress guard inactive");
  process.exit(98);
}
process.on("exit", () => {
  const blocked = guard.blockedAttempts().length;
  if (blocked > 0) console.error(`egress blocked ${blocked} attempt(s)`);
});
