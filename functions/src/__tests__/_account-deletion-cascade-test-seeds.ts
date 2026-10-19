/**
 * Seeds, row builders and the pass/fail collector shared by the account-deletion
 * cascade suites (`account-deletion-cascade*.test.ts`). Moved out of the single
 * cascade test file.
 */

import { type DeletionResult } from "../account/account-deletion-cascade";
import { FakeFirestore } from "./_account-deletion-cascade-fake-firestore";

interface ScenarioResult {
  name: string;
  passed: boolean;
  reason?: string;
}

const results: ScenarioResult[] = [];

export function check(name: string, condition: boolean, reason?: string): void {
  results.push({ name, passed: condition, reason });
}

export const asDb = (db: FakeFirestore) =>
  db as unknown as import("firebase-admin").firestore.Firestore;

export const UID = "deleted-uid";

export const OTHER = "other-uid";

export const THIRD = "third-uid";

export function seedMessage(
  db: FakeFirestore,
  id: string,
  conversationId: string,
  senderId: string,
): void {
  db.set(`messages/${id}`, {
    conversationId,
    senderId,
    senderDisplayName: senderId === UID ? "Malin" : "Anna",
    senderAvatarUrl: `https://example.test/${senderId}.jpg`,
    content: `content of ${id}`,
  });
}

/** A residual-probe result envelope, fresh for each probe call. */
export function emptyResult(): DeletionResult {
  return {
    deletedCollections: [],
    failedCollections: [],
    errors: [],
    retained: [],
  };
}

export function sawResidual(result: { failedCollections: string[] }): boolean {
  return result.failedCollections.includes("residual_data_detected");
}

export async function probeAfter(db: FakeFirestore, result: DeletionResult): Promise<void> {
  const { probeResidualData } = require("../account/account-deletion-cascade");
  await probeResidualData(asDb(db), UID, result);
}

export function finishSuite(label: string): void {
  let failed = 0;
  for (const r of results) {
    if (r.passed) {
      console.log(`  PASS  ${r.name}`);
    } else {
      console.log(`  FAIL  ${r.name}${r.reason ? `\n        ${r.reason}` : ""}`);
      failed++;
    }
  }

  console.log(
    `\n${label}: ${results.length - failed}/${results.length} passing`,
  );
  if (failed > 0) process.exit(1);
}
