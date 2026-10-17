/**
 * Recipient-language selection for push text (BUT-2385).
 *
 * The sending device cannot know the recipient's language, so it sends the
 * push rendered in every language the app ships (`localized`) and this helper
 * picks the one the recipient chose. The strings stay in the app; the server
 * only chooses. Anything it cannot place falls back to the plain title/body,
 * which is what every push carried before this existed.
 */

import * as admin from "firebase-admin";

export const NOTIFICATION_LOCALES = ["sv", "en"] as const;
export type NotificationLocale = (typeof NOTIFICATION_LOCALES)[number];

export interface LocalizedText {
  title: string;
  body: string;
}

export type LocalizedTexts = Partial<Record<NotificationLocale, LocalizedText>>;

// Same caps the batch callable puts on title/body.
const MAX_TITLE = 100;
const MAX_BODY = 500;

function isLocale(value: string): value is NotificationLocale {
  return (NOTIFICATION_LOCALES as readonly string[]).includes(value);
}

/**
 * The usable entries of a client-supplied `localized` value. Never rejects:
 * an entry in a language this server does not know, or without text, is
 * dropped, and an over-long one is cut to the caps. The push itself must not
 * fail over a translation, since a recipe or display name can make a rendered
 * title longer than the caps.
 */
export function usableLocalized(raw: unknown): LocalizedTexts {
  const result: LocalizedTexts = {};
  if (typeof raw !== "object" || raw === null || Array.isArray(raw)) {
    return result;
  }
  for (const code of NOTIFICATION_LOCALES) {
    const text = (raw as Record<string, unknown>)[code];
    if (typeof text !== "object" || text === null) continue;
    const { title, body } = text as Record<string, unknown>;
    if (typeof title !== "string" || title.length === 0) continue;
    if (typeof body !== "string" || body.length === 0) continue;
    result[code] = {
      title: title.slice(0, MAX_TITLE),
      body: body.slice(0, MAX_BODY),
    };
  }
  return result;
}

/** The recipient's chosen language, or null when none is stored or it is unknown. */
export async function readRecipientLocale(
  userId: string
): Promise<NotificationLocale | null> {
  const snap = await admin
    .firestore()
    .collection("users")
    .doc(userId)
    .collection("settings")
    .doc("preferences")
    .get();
  const value = snap.exists ? snap.data()?.preferredLocale : undefined;
  return typeof value === "string" && isLocale(value) ? value : null;
}

export interface ResolveTextOptions {
  userId: string;
  title?: string;
  body?: string;
  localized?: unknown;
  /** Test seam: production resolves to `readRecipientLocale`. */
  getLocale?: typeof readRecipientLocale;
}

/**
 * The title and body to send. Costs one document read, and only when the
 * sender supplied translations. A failed read keeps the sender's text: a push
 * in the wrong language beats no push.
 */
export async function resolveText(
  opts: ResolveTextOptions
): Promise<{ title?: string; body?: string }> {
  const { userId, title, body, localized, getLocale = readRecipientLocale } = opts;
  const texts = usableLocalized(localized);
  if (Object.keys(texts).length === 0) return { title, body };

  let locale: NotificationLocale | null = null;
  try {
    locale = await getLocale(userId);
  } catch {
    return { title, body };
  }
  const chosen = locale ? texts[locale] : undefined;
  return chosen ? { title: chosen.title, body: chosen.body } : { title, body };
}
