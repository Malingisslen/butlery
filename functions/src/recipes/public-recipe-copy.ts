/**
 * The profile copy of a recipe its owner chose to show (kärnflöde steg 10E).
 *
 * Other users never read `users/{uid}/recipes`: that document carries the
 * owner's rating, cook history, captured source text and the uids the recipe
 * is shared with, and rules cannot hide single fields. They read the copy at
 * `users/{uid}/public_recipes/{recipeId}`, which only `syncPublicRecipe`
 * writes. Everything here is pure so the allowlist can be tested at every
 * depth without an emulator.
 */

import { Timestamp } from "firebase-admin/firestore";
import { Collections } from "../shared/collections";

type Data = Record<string, unknown>;

export const PUBLIC_RECIPES = Collections.publicRecipes;

/** Copies one user may have; past it the newest publish is refused. */
export const MAX_PUBLIC_RECIPES_PER_USER = 100;

const MAX_TEXT = 2000;
const MAX_TITLE = 200;
const MAX_LIST = 200;
const MAX_IMAGES = 10;

/**
 * The fields whose change alters the copy, plus the opt-in itself. A write
 * that changes none of them (a cook count, a rating, a tag pass) needs no
 * work, so the trigger can return before reading anything.
 */
const COPY_INPUT_FIELDS = [
  "showOnProfile",
  "title",
  "description",
  "portions",
  "timeMinutes",
  "prepTimeMinutes",
  "cookTimeMinutes",
  "ingredients",
  "structuredIngredients",
  "instructions",
  "mealType",
  "cuisine",
  "difficulty",
  "imageUrls",
  "thumbnailUrl",
  "sourceUrl",
  "sourceAuthor",
  "sourceArtefact",
] as const;

function isData(value: unknown): value is Data {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** The `core` map, or the document itself for recipes stored flat. */
export function coreOf(doc: Data | null | undefined): Data | null {
  if (!doc) return null;
  return isData(doc.core) ? doc.core : doc;
}

/**
 * Only the `core` map counts: that is the field the rules gate, and a flat
 * legacy document could carry a top-level flag the rules never checked.
 */
export function wantsProfile(doc: Data | null | undefined): boolean {
  return !!doc && isData(doc.core) && doc.core.showOnProfile === true;
}

function memberIds(doc: Data): string[] {
  const social = doc.socialData;
  const members = isData(social) ? social.memberPermissions : null;
  return isData(members) ? Object.keys(members).sort() : [];
}

/**
 * Whether the write can change the copy at all: a copied field, the opt-in,
 * or an input of a refusal (sharing the recipe removes its copy).
 */
export function copyInputsChanged(before: Data | null, after: Data | null): boolean {
  const b = coreOf(before);
  const a = coreOf(after);
  if (!before || !after || !b || !a) return true;
  if (JSON.stringify(before.type ?? null) !== JSON.stringify(after.type ?? null)) return true;
  if (JSON.stringify(memberIds(before)) !== JSON.stringify(memberIds(after))) return true;
  return COPY_INPUT_FIELDS.some(
    (f) => JSON.stringify(b[f] ?? null) !== JSON.stringify(a[f] ?? null),
  );
}

/**
 * A recipe read from a photo. Its photos may be the scanned cookbook page,
 * which is someone else's work however the text is used, so none of them is
 * copied to the profile.
 */
export function isPhotoScan(doc: Data | null | undefined): boolean {
  const artefact = coreOf(doc)?.sourceArtefact;
  return isData(artefact) && artefact.type === "photoOcr";
}

/** A shared or collaborative recipe is never shown on one person's profile. */
export function isSharedWithOthers(doc: Data | null | undefined): boolean {
  if (!doc) return false;
  // `RecipeSerialization.toFirestore` stores the enum index; 0 is personal.
  const type = doc.type;
  if (type != null && type !== 0 && type !== "personal") return true;
  const social = doc.socialData;
  if (isData(social)) {
    const members = social.memberPermissions;
    if (isData(members) && Object.keys(members).length > 0) return true;
  }
  return false;
}

function text(value: unknown, max: number = MAX_TEXT): string | null {
  if (typeof value !== "string") return null;
  return value.length > max ? value.slice(0, max) : value;
}

function count(value: unknown): number | null {
  return typeof value === "number" && Number.isFinite(value) && value >= 0 ? value : null;
}

function textList(value: unknown): string[] {
  if (!Array.isArray(value)) return [];
  return value
    .filter((v): v is string => typeof v === "string")
    .slice(0, MAX_LIST)
    .map((v) => text(v) as string);
}

/** Each structured line rebuilt from named fields, so nothing nested rides along. */
function structuredList(value: unknown): Data[] | null {
  if (!Array.isArray(value)) return null;
  const out: Data[] = [];
  for (const item of value.slice(0, MAX_LIST)) {
    if (!isData(item)) continue;
    const line: Data = { name: text(item.name) ?? "", raw: text(item.raw) ?? "" };
    if (typeof item.amount === "number" && Number.isFinite(item.amount)) line.amount = item.amount;
    const unit = text(item.unit, 40);
    if (unit !== null) line.unit = unit;
    const note = text(item.note, 400);
    if (note !== null) line.note = note;
    const section = text(item.section, 200);
    if (section !== null) line.section = section;
    out.push(line);
  }
  return out;
}

/**
 * A Firebase Storage download URL for an object under the owner's own
 * `users/{uid}/` prefix. Anything else (another user's photo carried by a
 * copy, an outside host that would log every viewer's IP) is dropped.
 */
export function isOwnStorageImage(url: unknown, uid: string): url is string {
  if (typeof url !== "string") return false;
  let parsed: URL;
  try {
    parsed = new URL(url);
  } catch {
    return false;
  }
  if (parsed.protocol !== "https:") return false;
  if (parsed.hostname !== "firebasestorage.googleapis.com") return false;
  const match = /^\/v0\/b\/[^/]+\/o\/([^/]+)$/.exec(parsed.pathname);
  if (!match) return false;
  let objectPath: string;
  try {
    objectPath = decodeURIComponent(match[1]);
  } catch {
    return false;
  }
  return objectPath.startsWith(`users/${uid}/`) && !objectPath.includes("..");
}

/** A Firestore Timestamp, or null: anything else could carry a nested map. */
function timestamp(value: unknown): Timestamp | null {
  return value instanceof Timestamp ? value : null;
}

function httpsUrl(value: unknown): string | null {
  if (typeof value !== "string") return null;
  try {
    const parsed = new URL(value);
    return parsed.protocol === "https:" ? value.slice(0, MAX_TEXT) : null;
  } catch {
    return null;
  }
}

/**
 * The copy's fields. `updatedAt`/`createdAt` are the source's timestamps so
 * the copy sorts like the recipe; `syncedAt` is set by the
 * caller. `imageUrls` and `thumbnailUrl` here are still the owner's own photo
 * URLs: the caller swaps each for its public copy (public-recipe-images.ts)
 * and drops any it could not copy.
 */
export function buildPublicCopy(uid: string, recipeId: string, doc: Data): Data {
  const core = coreOf(doc) ?? {};
  const scan = isPhotoScan(doc);
  const images = !scan && Array.isArray(core.imageUrls)
    ? core.imageUrls.filter((u) => isOwnStorageImage(u, uid)).slice(0, MAX_IMAGES)
    : [];
  const thumb = !scan && isOwnStorageImage(core.thumbnailUrl, uid) ? core.thumbnailUrl : null;

  const copy: Data = {
    id: recipeId,
    ownerId: uid,
    title: text(core.title, MAX_TITLE) ?? "",
    description: text(core.description),
    portions: count(core.portions),
    timeMinutes: count(core.timeMinutes),
    prepTimeMinutes: count(core.prepTimeMinutes),
    cookTimeMinutes: count(core.cookTimeMinutes),
    ingredients: textList(core.ingredients),
    instructions: textList(core.instructions),
    mealType: text(core.mealType, 100) ?? "",
    cuisine: text(core.cuisine, 100),
    difficulty: text(core.difficulty, 100),
    imageUrls: images,
    thumbnailUrl: thumb,
    sourceUrl: httpsUrl(core.sourceUrl),
    sourceAuthor: text(core.sourceAuthor, MAX_TITLE),
    createdAt: timestamp(core.createdAt),
    updatedAt: timestamp(core.updatedAt),
  };
  const structured = structuredList(core.structuredIngredients);
  if (structured !== null) copy.structuredIngredients = structured;
  return copy;
}

/** Every key a copy may hold. The test asserts the built copy against it. */
export const PUBLIC_COPY_KEYS = [
  "id",
  "ownerId",
  "title",
  "description",
  "portions",
  "timeMinutes",
  "prepTimeMinutes",
  "cookTimeMinutes",
  "ingredients",
  "structuredIngredients",
  "instructions",
  "mealType",
  "cuisine",
  "difficulty",
  "imageUrls",
  "thumbnailUrl",
  "sourceUrl",
  "sourceAuthor",
  "createdAt",
  "updatedAt",
  "syncedAt",
] as const;
