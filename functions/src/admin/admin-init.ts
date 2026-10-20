/**
 * Shared Firebase Admin initialization for admin scripts.
 *
 * Handles credential discovery (Firebase CLI application default credentials)
 * and idempotent app initialization. The target project is never defaulted:
 * `requireProject` takes it from `--project` and refuses before anything is
 * initialized.
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";
import { requireProject, RequireProjectOptions } from "./require-project";

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
 * The key file the script will run with. A named key always wins: replacing it
 * would run the script with a credential other than the one `requireProject`
 * checked.
 */
export function resolveCredentialPath(
  env: NodeJS.ProcessEnv,
  find: () => string | null = findFirebaseCredentials,
): string | undefined {
  return env.GOOGLE_APPLICATION_CREDENTIALS || find() || undefined;
}

/**
 * Initialize Firebase Admin for the project named by `--project`.
 * Idempotent — safe to call multiple times for the same project.
 */
export function initializeAdminApp(
  options: RequireProjectOptions & {
    findCredentials?: () => string | null;
  } = {},
): admin.app.App {
  const env = options.env ?? process.env;
  const credPath = resolveCredentialPath(env, options.findCredentials);
  const projectId = requireProject({
    ...options,
    env: { ...env, GOOGLE_APPLICATION_CREDENTIALS: credPath },
  });

  if (admin.apps.length) {
    const existing = admin.app();
    if (existing.options.projectId !== projectId) {
      throw new Error(
        `REFUSED: an admin app for "${existing.options.projectId}" is ` +
          `already initialized, but --project is "${projectId}".`,
      );
    }
    return existing;
  }

  // The SDK reads the key from process.env, so it must hold exactly the one
  // requireProject checked.
  if (!credPath) {
    delete process.env.GOOGLE_APPLICATION_CREDENTIALS;
  } else if (credPath !== process.env.GOOGLE_APPLICATION_CREDENTIALS) {
    process.env.GOOGLE_APPLICATION_CREDENTIALS = credPath;
    console.error(`Using credentials: ${credPath}`);
  }
  console.error(`Target project: ${projectId}`);
  return admin.initializeApp({
    credential: admin.credential.applicationDefault(),
    projectId,
  });
}
