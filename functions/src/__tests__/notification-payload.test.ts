/**
 * BUT-641: Notification payload schema helper tests.
 *
 * Verifies the contract enforced by `buildNotificationPayload`:
 *   1. Schema fields (route, targetId, notificationType) are always present.
 *   2. All values are strings (FCM data payload is string-only).
 *   3. additionalData is merged in but cannot overwrite schema fields.
 *   4. Unknown or missing routes throw a clear error.
 *
 * Run with: npx ts-node src/__tests__/notification-payload.test.ts
 */

import {
  buildNotificationPayload,
  NOTIFICATION_ROUTES,
} from "../shared/notification-payload";

interface UnitCase {
  name: string;
  fn: () => void;
}

function assertEqual<T>(actual: T, expected: T, msg: string): void {
  if (actual !== expected) {
    throw new Error(`${msg}: expected ${JSON.stringify(expected)}, got ${JSON.stringify(actual)}`);
  }
}

function assertThrows(fn: () => unknown, msgIncludes: string): void {
  let threw: unknown;
  try {
    fn();
  } catch (e) {
    threw = e;
  }
  if (!(threw instanceof Error)) {
    throw new Error(`expected throw including "${msgIncludes}", got no error`);
  }
  if (!threw.message.includes(msgIncludes)) {
    throw new Error(
      `expected throw including "${msgIncludes}", got: "${threw.message}"`
    );
  }
}

const cases: UnitCase[] = [
  {
    name: "produces correct shape with required fields only",
    fn: () => {
      const out = buildNotificationPayload({
        route: "/recipe",
        targetId: "recipe-1",
        notificationType: "recipe_shared",
      });
      assertEqual(out.route, "/recipe", "route");
      assertEqual(out.targetId, "recipe-1", "targetId");
      assertEqual(out.notificationType, "recipe_shared", "notificationType");
      assertEqual(Object.keys(out).length, 3, "key count");
    },
  },
  {
    name: "all values are strings (no Number/null/undefined slip through)",
    fn: () => {
      const out = buildNotificationPayload({
        route: "/recipe",
        targetId: "recipe-1",
        notificationType: "recipe_shared",
        additionalData: {
          // Deliberately mixed types — caller may have a legacy field shape.
          // The helper must coerce or drop, never let non-string into the map.
          legacyCount: 42 as unknown as string,
          maybeNull: null,
          maybeUndefined: undefined,
          okString: "hello",
        },
      });
      // Every value in the output must be a string.
      for (const [k, v] of Object.entries(out)) {
        if (typeof v !== "string") {
          throw new Error(`key "${k}" has non-string value: ${typeof v}`);
        }
      }
      assertEqual(out.legacyCount, "42", "legacyCount coerced");
      assertEqual(out.okString, "hello", "okString preserved");
      // null / undefined dropped, not stringified.
      if ("maybeNull" in out) throw new Error("null should be dropped");
      if ("maybeUndefined" in out) throw new Error("undefined should be dropped");
    },
  },
  {
    name: "additionalData merges with schema fields without overwriting them",
    fn: () => {
      const out = buildNotificationPayload({
        route: "/recipe",
        targetId: "recipe-1",
        notificationType: "recipe_shared",
        additionalData: {
          // Caller tries to overwrite schema fields — schema must win.
          route: "/winback",
          targetId: "WRONG",
          notificationType: "WRONG_TYPE",
          extra: "preserved",
        },
      });
      assertEqual(out.route, "/recipe", "schema route wins");
      assertEqual(out.targetId, "recipe-1", "schema targetId wins");
      assertEqual(out.notificationType, "recipe_shared", "schema notificationType wins");
      assertEqual(out.extra, "preserved", "non-conflicting key preserved");
    },
  },
  {
    name: "additionalData passes through senderName / imageUrl style extras",
    fn: () => {
      const out = buildNotificationPayload({
        route: "/recipe",
        targetId: "recipe-1",
        notificationType: "recipe_shared",
        additionalData: {
          senderName: "Anna",
          imageUrl: "https://example.com/x.png",
          recipeTitle: "Köttbullar",
        },
      });
      assertEqual(out.senderName, "Anna", "senderName");
      assertEqual(out.imageUrl, "https://example.com/x.png", "imageUrl");
      assertEqual(out.recipeTitle, "Köttbullar", "recipeTitle");
    },
  },
  {
    name: "empty targetId is allowed (winback / inbox-style routes)",
    fn: () => {
      const out = buildNotificationPayload({
        route: "/winback",
        targetId: "",
        notificationType: "winback_d7",
      });
      assertEqual(out.route, "/winback", "route");
      assertEqual(out.targetId, "", "empty targetId");
      assertEqual(out.notificationType, "winback_d7", "notificationType");
    },
  },
  {
    name: "throws when route is missing",
    fn: () => {
      assertThrows(
        () =>
          buildNotificationPayload({
            // @ts-expect-error — testing runtime validation
            route: undefined,
            targetId: "x",
            notificationType: "y",
          }),
        "`route` is required"
      );
    },
  },
  {
    name: "throws when route is empty string",
    fn: () => {
      assertThrows(
        () =>
          buildNotificationPayload({
            route: "",
            targetId: "x",
            notificationType: "y",
          }),
        "`route` is required"
      );
    },
  },
  {
    name: "throws when route is unknown",
    fn: () => {
      assertThrows(
        () =>
          buildNotificationPayload({
            route: "/some_made_up_route",
            targetId: "x",
            notificationType: "y",
          }),
        "unknown route"
      );
    },
  },
  {
    name: "throws when notificationType is missing",
    fn: () => {
      assertThrows(
        () =>
          buildNotificationPayload({
            route: "/recipe",
            targetId: "x",
            notificationType: "",
          }),
        "`notificationType` is required"
      );
    },
  },
  {
    name: "throws when targetId is not a string (e.g. undefined)",
    fn: () => {
      assertThrows(
        () =>
          buildNotificationPayload({
            route: "/recipe",
            // @ts-expect-error — testing runtime validation
            targetId: undefined,
            notificationType: "y",
          }),
        "`targetId` is required"
      );
    },
  },
  {
    name: "all 6 allowlisted routes accepted",
    fn: () => {
      for (const route of NOTIFICATION_ROUTES) {
        const out = buildNotificationPayload({
          route,
          targetId: route === "/winback" || route === "/friend_request" ? "" : "id-1",
          notificationType: "test",
        });
        assertEqual(out.route, route, `accepts ${route}`);
      }
    },
  },
  {
    name: "allowlist is exactly the 6 BUT-641 routes (no drift)",
    fn: () => {
      const expected = [
        "/recipe",
        "/friend_request",
        "/comment_thread",
        "/cooking_session",
        "/menu_voting",
        "/winback",
      ];
      assertEqual(NOTIFICATION_ROUTES.length, expected.length, "route count");
      for (const r of expected) {
        if (!(NOTIFICATION_ROUTES as readonly string[]).includes(r)) {
          throw new Error(`expected route "${r}" missing from allowlist`);
        }
      }
    },
  },
];

function runTests(): void {
  console.log("BUT-641: Notification payload helper tests\n");
  console.log("==========================================\n");

  let failed = 0;
  for (const c of cases) {
    try {
      c.fn();
      console.log(`  PASS  ${c.name}`);
    } catch (err) {
      failed++;
      console.log(`  FAIL  ${c.name}`);
      console.log(`        ${err instanceof Error ? err.message : err}`);
    }
  }

  const total = cases.length;
  console.log(
    `\n${total - failed}/${total} passed` + (failed ? `, ${failed} failed` : "")
  );
  if (failed > 0) process.exit(1);
}

runTests();
