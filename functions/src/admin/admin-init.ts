/**
 * Shared Firebase Admin initialization for admin scripts.
 *
 * Handles credential discovery (Firebase CLI application default credentials)
 * and idempotent app initialization.
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";

const PROJECT_ID = "butlery-app-1";

/**
 * Finds Firebase CLI application default credentials.
 * Firebase CLI stores these in %APPDATA%/firebase/ on Windows
 * or ~/.config/firebase/ on macOS/Linux.
 */
export function findFirebaseCredentials(): string | null {
  const candidates: string[] = [];

  // Windows: %APPDATA%/firebase/
  if (process.env.APPDATA) {
    const dir = path.join(process.env.APPDATA, "firebase");
    if (fs.existsSync(dir)) {
      const files = fs
        .readdirSync(dir)
        .filter((f) => f.endsWith("_application_default_credentials.json"));
      candidates.push(...files.map((f) => path.join(dir, f)));
    }
  }

  // macOS/Linux: ~/.config/firebase/
  const home = process.env.HOME || process.env.USERPROFILE || "";
  if (home) {
    const dir = path.join(home, ".config", "firebase");
    if (fs.existsSync(dir)) {
      const files = fs
        .readdirSync(dir)
        .filter((f) => f.endsWith("_application_default_credentials.json"));
      candidates.push(...files.map((f) => path.join(dir, f)));
    }
  }

  return candidates[0] || null;
}

/**
 * Initialize Firebase Admin with auto-discovered credentials.
 * Idempotent — safe to call multiple times.
 */
export function initializeAdminApp(): void {
  if (admin.apps.length) return;

  const credPath = findFirebaseCredentials();
  if (credPath) {
    process.env.GOOGLE_APPLICATION_CREDENTIALS = credPath;
    console.error(`Using credentials: ${credPath}`);
  }
  admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId: PROJECT_ID,
  });
}
