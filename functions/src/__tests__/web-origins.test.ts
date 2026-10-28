/**
 * Every callable that sets `cors` takes the shared origin list. An inline list
 * once left all 24 callables refusing the web app on butlery-prod.web.app,
 * because each named only butlery.app (BUT-2432).
 *
 * Run: npx ts-node src/__tests__/web-origins.test.ts
 */

import * as fs from "fs";
import * as path from "path";
import { runTests, UnitCase, assertEqual } from "./_unit-runner";
import { WEB_CALLABLE_ORIGINS } from "../shared/web-origins";

function sourceFiles(dir: string): string[] {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((e) => {
    const full = path.join(dir, e.name);
    if (e.isDirectory()) return e.name === "__tests__" ? [] : sourceFiles(full);
    return e.name.endsWith(".ts") ? [full] : [];
  });
}

const cases: UnitCase[] = [
  {
    name: "the list holds the production, admin and staging hosts",
    fn: () => {
      assertEqual(
        JSON.stringify([...WEB_CALLABLE_ORIGINS].sort()),
        JSON.stringify([
          "https://butlery-app-staging.firebaseapp.com",
          "https://butlery-app-staging.web.app",
          "https://butlery-prod-admin.web.app",
          "https://butlery-prod.firebaseapp.com",
          "https://butlery-prod.web.app",
          "https://butlery.se",
          "https://www.butlery.se",
        ]),
        "WEB_CALLABLE_ORIGINS",
      );
    },
  },
  {
    name: "no callable outside tests sets cors to anything but the shared list",
    fn: () => {
      const root = path.resolve(__dirname, "..");
      const offenders = sourceFiles(root)
        .filter((f) =>
          /cors:\s*(?!WEB_CALLABLE_ORIGINS\b)\S/.test(fs.readFileSync(f, "utf8"))
        )
        .map((f) => path.relative(root, f));
      assertEqual(JSON.stringify(offenders), "[]", "files with another cors value");
    },
  },
];

runTests("web-origins", cases);
