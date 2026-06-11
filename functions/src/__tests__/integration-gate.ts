/**
 * Shared emulator gate for the BUT-839-style integration suites.
 *
 * Contract: unreachable emulator(s) → SKIP (exit 0) on local Java-less
 * machines, HARD FAIL (exit 1) in CI. Centralized so the CI policy, host
 * addressing, and timeout can never drift between suites — a missed edit in
 * one copy would make a CI lane exit 0 while the suite never ran.
 */

import * as http from "http";

/** True when any HTTP answer arrives on the port (incl. 501 from storage). */
export function probe(hostPort: string): Promise<boolean> {
  return new Promise((resolve) => {
    const [host, portStr] = hostPort.split(":");
    const req = http.request(
      { host, port: Number(portStr), path: "/", method: "GET", timeout: 3000 },
      (res) => {
        res.resume();
        resolve(true);
      },
    );
    req.on("error", () => resolve(false));
    req.on("timeout", () => {
      req.destroy();
      resolve(false);
    });
    req.end();
  });
}

/**
 * Probe every named emulator; on any miss, exit 1 in CI or print SKIP and
 * exit 0 locally. `startHint` is shown in the local SKIP message.
 */
export async function requireEmulatorsOrSkip(
  emulators: { name: string; hostPort: string }[],
  startHint: string,
): Promise<void> {
  const results = await Promise.all(
    emulators.map(async (e) => ({ ...e, up: await probe(e.hostPort) })),
  );
  const missing = results
    .filter((r) => !r.up)
    .map((r) => `${r.name} (${r.hostPort})`)
    .join(", ");
  if (!missing) return;

  if (process.env.CI) {
    console.error(`FAIL: emulator(s) not reachable in CI: ${missing}`);
    process.exit(1);
  }
  console.log(
    `SKIP: emulator(s) not reachable locally: ${missing}.\nStart with: ${startHint}`,
  );
  process.exit(0);
}
