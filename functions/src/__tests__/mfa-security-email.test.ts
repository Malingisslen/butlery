/**
 * BUT-2142: the security e-mail for two-step verification. It must reach
 * Resend with the owner's address and nothing secret, and a failure must never
 * escape (a recovery or an enrollment is not undone by a mail).
 */

import { runTests, assertEqual, UnitCase } from "./_unit-runner";
import {
  buildMfaSecurityEmail,
  notifyMfaSecurityEvent,
  sendMfaSecurityEmail,
} from "../account/mfa-security-email";

interface Sent {
  url: string;
  init: RequestInit;
}

function recordingFetch(sent: Sent[], status = 200): typeof fetch {
  return (async (url: string, init: RequestInit) => {
    sent.push({ url, init });
    return { ok: status >= 200 && status < 300, status } as Response;
  }) as unknown as typeof fetch;
}

const TRANSPORT = { apiKey: "re_test", from: "Butlery <konto@example.com>" };

const cases: UnitCase[] = [
  {
    name: "both events have a Swedish and an English line, and say what to do",
    fn: async () => {
      for (const event of ["codes-created", "recovered"] as const) {
        const { subject, text } = buildMfaSecurityEmail(event);
        assertEqual(subject.startsWith("Butlery: "), true, `${event} subject`);
        assertEqual(text.includes("Om det inte var du"), true, `${event} sv advice`);
        assertEqual(text.includes("If this was not you"), true, `${event} en advice`);
      }
      assertEqual(
        buildMfaSecurityEmail("recovered").text.includes("reservkod"),
        true,
        "recovery mail names the backup code",
      );
    },
  },
  {
    name: "the mail goes to Resend with the owner's address and the key as bearer",
    fn: async () => {
      const sent: Sent[] = [];
      const ok = await sendMfaSecurityEmail(
        { ...TRANSPORT, fetchFn: recordingFetch(sent) },
        "anna@example.com",
        "recovered",
      );
      assertEqual(ok, true, "accepted");
      assertEqual(sent.length, 1, "one request");
      assertEqual(sent[0].url, "https://api.resend.com/emails", "Resend endpoint");
      assertEqual(sent[0].init.method, "POST", "method");
      const headers = sent[0].init.headers as Record<string, string>;
      assertEqual(headers.Authorization, "Bearer re_test", "bearer key");
      const body = JSON.parse(String(sent[0].init.body));
      assertEqual(body.to, "anna@example.com", "recipient");
      assertEqual(body.from, TRANSPORT.from, "sender");
      assertEqual(body.text, buildMfaSecurityEmail("recovered").text, "body");
      assertEqual(body.subject, buildMfaSecurityEmail("recovered").subject, "subject");
    },
  },
  {
    name: "a missing key, sender or address skips without calling Resend",
    fn: async () => {
      const sent: Sent[] = [];
      const fetchFn = recordingFetch(sent);
      assertEqual(
        await sendMfaSecurityEmail({ ...TRANSPORT, apiKey: "", fetchFn }, "a@b.se", "codes-created"),
        false,
        "no key",
      );
      assertEqual(
        await sendMfaSecurityEmail({ ...TRANSPORT, from: "", fetchFn }, "a@b.se", "codes-created"),
        false,
        "no sender",
      );
      assertEqual(
        await sendMfaSecurityEmail({ ...TRANSPORT, fetchFn }, "", "codes-created"),
        false,
        "no address",
      );
      assertEqual(sent.length, 0, "nothing sent");
    },
  },
  {
    name: "a refusal or a network error resolves false and never throws",
    fn: async () => {
      const refused = await sendMfaSecurityEmail(
        { ...TRANSPORT, fetchFn: recordingFetch([], 422) },
        "a@b.se",
        "codes-created",
      );
      assertEqual(refused, false, "refused");
      const thrown = await sendMfaSecurityEmail(
        {
          ...TRANSPORT,
          fetchFn: (async () => {
            throw new Error("offline");
          }) as unknown as typeof fetch,
        },
        "a@b.se",
        "codes-created",
      );
      assertEqual(thrown, false, "network error");
    },
  },
  {
    name: "a Resend that never answers is given up on, not waited for",
    fn: async () => {
      const hanging = ((_url: string, init: RequestInit) =>
        new Promise((_resolve, reject) => {
          init.signal?.addEventListener("abort", () => reject(new Error("aborted")));
        })) as unknown as typeof fetch;
      // The test's own deadline: without it, a send that never settles leaves
      // no pending work and the process exits 0 before the footer.
      let guard: NodeJS.Timeout | undefined;
      const ok = await Promise.race([
        sendMfaSecurityEmail(
          { ...TRANSPORT, fetchFn: hanging, timeoutMs: 20 },
          "a@b.se",
          "recovered",
        ),
        new Promise<never>((_resolve, reject) => {
          guard = setTimeout(() => reject(new Error("send did not give up within 1 s")), 1000);
        }),
      ]).finally(() => clearTimeout(guard));
      assertEqual(ok, false, "timed out");
    },
  },
  {
    name: "the production notifier never throws when the account lookup fails",
    fn: async () => {
      let sends = 0;
      await notifyMfaSecurityEvent(
        "uid-x",
        "recovered",
        async () => {
          throw new Error("auth/user-not-found");
        },
        async () => {
          sends++;
          return true;
        },
      );
      assertEqual(sends, 0, "nothing sent without an address");
      let to = "";
      await notifyMfaSecurityEvent("uid-x", "codes-created", async () => "anna@example.com", async (_t, address) => {
        to = address;
        return true;
      });
      assertEqual(to, "anna@example.com", "the looked-up address is used");
    },
  },
];

void runTests("mfa-security-email (BUT-2142)", cases);
