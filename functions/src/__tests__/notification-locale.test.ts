/**
 * BUT-2385: a push is written in the recipient's language.
 *
 * The sender ships the text in every supported language (`localized`); the
 * server picks the recipient's. These cases pin the choice, the fallbacks and
 * the cleaning of what was sent, then run the whole dispatch to prove the chosen text is what
 * reaches both the delivery path and the quiet-hours gate.
 *
 * Run with: npx ts-node src/__tests__/notification-locale.test.ts
 */

import {
  resolveText,
  usableLocalized,
} from "../shared/notification-locale";
import { dispatchNotification } from "../notifications/send-notification";

let failed = 0;

function check(name: string, ok: boolean, detail = ""): void {
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}${detail ? `\n        ${detail}` : ""}`);
  }
}

const localized = {
  sv: { title: "Ny vänskapsförfrågan", body: "Anna vill bli vän med dig" },
  en: { title: "New friend request", body: "Anna wants to be your friend" },
};

async function resolveCases(): Promise<void> {
  const base = { userId: "u1", title: "Ny vänskapsförfrågan", body: "sv-fallback", localized };

  const en = await resolveText({ ...base, getLocale: async () => "en" });
  check("english recipient gets the english text", en.title === "New friend request");

  const sv = await resolveText({ ...base, getLocale: async () => "sv" });
  check("swedish recipient gets the swedish text", sv.body === "Anna vill bli vän med dig");

  const none = await resolveText({ ...base, getLocale: async () => null });
  check("no stored language keeps the plain text", none.body === "sv-fallback");

  const partial = await resolveText({
    ...base,
    localized: { sv: localized.sv },
    getLocale: async () => "en",
  });
  check("a language the sender left out keeps the plain text", partial.body === "sv-fallback");

  const boom = await resolveText({
    ...base,
    getLocale: async () => {
      throw new Error("firestore down");
    },
  });
  check("a failed lookup keeps the plain text", boom.body === "sv-fallback");

  let lookups = 0;
  const old = await resolveText({
    userId: "u1",
    title: "t",
    body: "b",
    getLocale: async () => {
      lookups++;
      return "en";
    },
  });
  check(
    "an older app sends no translations: no read, plain text",
    lookups === 0 && old.title === "t" && old.body === "b"
  );

  const long = await resolveText({
    ...base,
    localized: { en: { title: "t".repeat(150), body: "b" } },
    getLocale: async () => "en",
  });
  check("resolveText sends the cut title", long.title?.length === 100);

  const bad = await resolveText({
    ...base,
    localized: { en: { title: 5, body: "x" } },
    getLocale: async () => "en",
  });
  check("a malformed value is ignored, not trusted", bad.body === "sv-fallback");
}

function usableCases(): void {
  check("absent gives nothing", Object.keys(usableLocalized(undefined)).length === 0);
  check("sv and en are kept", Object.keys(usableLocalized(localized)).length === 2);
  check(
    "an unsupported language is dropped, the rest kept",
    JSON.stringify(Object.keys(usableLocalized({ de: localized.en, en: localized.en }))) ===
      '["en"]'
  );
  check("an array gives nothing", Object.keys(usableLocalized([])).length === 0);
  check(
    "an entry with an empty title is dropped",
    usableLocalized({ en: { title: "", body: "x" } }).en === undefined
  );
  check(
    "an entry with an empty body is dropped",
    usableLocalized({ en: { title: "x", body: "" } }).en === undefined
  );
  const long = usableLocalized({ en: { title: "t".repeat(150), body: "b".repeat(700) } });
  check(
    "an over-long entry is cut to the caps, not rejected",
    long.en?.title.length === 100 && long.en?.body.length === 500
  );
}

async function dispatchCase(): Promise<void> {
  const sent: { title: string; body: string }[] = [];
  const gated: { title: string; body: string }[] = [];
  const result = await dispatchNotification({
    targetUserId: "u1",
    title: localized.sv.title,
    body: localized.sv.body,
    localized,
    data: {
      route: "/friend_request",
      targetId: "",
      notificationType: "friend_request",
    },
    getLocale: async () => "en",
    gate: async ({ payload }) => {
      gated.push({ title: payload?.title ?? "", body: payload?.body ?? "" });
      return { action: "proceed", reason: "test-stub" } as const;
    },
    preferenceAwareSend: async (_userId, notification) => {
      sent.push(notification);
      return { sent: true, reason: "sent", successCount: 1, failureCount: 0 };
    },
    recordEvent: async () => undefined,
  });
  check("dispatch succeeds", result.success && result.successCount === 1);
  check(
    "the delivery path gets the recipient's language",
    sent.length === 1 && sent[0].title === "New friend request"
  );
  check(
    "the quiet-hours gate sees the same text it would queue",
    gated.length === 1 && gated[0].body === "Anna wants to be your friend"
  );
}

(async () => {
  console.log("notification-locale (BUT-2385)");
  await resolveCases();
  usableCases();
  await dispatchCase();
  if (failed > 0) {
    console.log(`\n${failed} failed`);
    process.exit(1);
  }
  console.log("\nAll passed");
})();
