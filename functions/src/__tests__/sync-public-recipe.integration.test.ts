/**
 * Kärnflöde steg 10E: emulator-backed tests for `reconcilePublicRecipe`, the
 * transaction behind `syncPublicRecipe`, plus the pure allowlist it copies
 * through.
 *
 * Prerequisite: Firestore emulator running (127.0.0.1:8080).
 * Run: npx ts-node src/__tests__/sync-public-recipe.integration.test.ts
 */

const PROJECT_ID = "butlery-sync-public-recipe-integration";
process.env.FIRESTORE_EMULATOR_HOST = "127.0.0.1:8080";
process.env.GCLOUD_PROJECT = PROJECT_ID;

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: PROJECT_ID });
}
const db = admin.firestore();

import {
  PUBLIC_COPY_KEYS,
  buildPublicCopy,
  copyInputsChanged,
  isOwnStorageImage,
  isPhotoScan,
  wantsProfile,
} from "../recipes/public-recipe-copy";
import { PublicImageStore, parseDownloadUrl, publicImagePath } from "../recipes/public-recipe-images";
import {
  OwnerStanding,
  PublicPhotosPendingError,
  StalePhotosError,
  reconcilePublicRecipe,
} from "../recipes/sync-public-recipe";

type Data = admin.firestore.DocumentData;

const RUN = Date.now().toString(36);
let seq = 0;
const nextUid = () => `spr${RUN}u${seq++}`;

let run = 0;
let failed = 0;
function check(name: string, ok: boolean, detail?: string): void {
  run++;
  if (ok) {
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}${detail ? ` — ${detail}` : ""}`);
  }
}

/** Storage stand-in: records which public photos exist per recipe. */
class FakeImages implements PublicImageStore {
  readonly created = new Map<string, number>();
  get objects(): Set<string> {
    return new Set(this.created.keys());
  }
  /** Creation time stamped on a new object; old by default, so prune may take it. */
  clock: () => number = () => Date.now() - 60_000;
  /** Runs inside ensure, to change the recipe while its photos are being made. */
  onEnsure: (() => Promise<unknown>) | null = null;
  async ensure(uid: string, recipeId: string, sourceUrl: string): Promise<string | null> {
    const hook = this.onEnsure;
    this.onEnsure = null;
    if (hook) await hook();
    const source = parseDownloadUrl(sourceUrl);
    if (!source) return null;
    const path = publicImagePath(uid, recipeId, source.path);
    if (!this.created.has(path)) this.created.set(path, this.clock());
    return `https://firebasestorage.googleapis.com/v0/b/${source.bucket}/o/${encodeURIComponent(path)}?alt=media&token=pub`;
  }
  async prune(uid: string, recipeId: string, keep: ReadonlySet<string>, createdBeforeMs: number): Promise<number> {
    const prefix = `users/${uid}/public_recipes/${recipeId}/`;
    let young = 0;
    for (const [o, at] of [...this.created]) {
      if (!o.startsWith(prefix) || keep.has(o)) continue;
      if (at < createdBeforeMs) this.created.delete(o);
      else young++;
    }
    return young;
  }
  ageAll(): void {
    for (const o of this.created.keys()) this.created.set(o, Date.now() - 60_000);
  }
  count(uid: string, recipeId: string): number {
    return [...this.objects].filter((o) => o.startsWith(`users/${uid}/public_recipes/${recipeId}/`)).length;
  }
}
const images = new FakeImages();
const sync = (uid: string, id: string, standing: OwnerStanding | null) =>
  reconcilePublicRecipe(db, uid, id, standing, images);

const ADULT: OwnerStanding = { ageCompliant: true, guest: false, emailVerified: true };
const OLD = admin.firestore.Timestamp.fromMillis(Date.now() - 48 * 60 * 60 * 1000);

function ownImage(uid: string, name = "a.jpg"): string {
  const object = encodeURIComponent(`users/${uid}/recipes/${name}`);
  return `https://firebasestorage.googleapis.com/v0/b/butlery.appspot.com/o/${object}?alt=media&token=t`;
}

/** A recipe carrying every personal field the copy must never hold. */
function recipe(uid: string, core: Data = {}, top: Data = {}): Data {
  return {
    type: 0,
    core: {
      id: "ignored",
      title: "Kanelbullar",
      description: "Mjuka",
      portions: 12,
      timeMinutes: 40,
      ingredients: ["5 dl vetemjöl", "2 tsk kanel"],
      structuredIngredients: [
        { amount: 5, unit: "dl", name: "vetemjöl", raw: "5 dl vetemjöl", ingredientId: "secret-id", rating: 5 },
      ],
      instructions: ["Blanda", "Grädda"],
      mealType: "Bakning",
      imageUrls: [ownImage(uid), "https://evil.example/pixel.png", ownImage("someone-else")],
      thumbnailUrl: ownImage(uid, "thumb.jpg"),
      createdBy: uid,
      showOnProfile: true,
      rating: 5,
      personalTags: [{ id: "t", name: "Mammas" }],
      personalTagIds: ["t"],
      tagOverrides: { gluten: "free" },
      isFavorite: true,
      lastCookedAt: OLD,
      cookCount: 7,
      averageRating: 4.5,
      familyAverage: 4,
      tagResult: { tags: [] },
      isPublic: true,
      updatedAt: OLD,
      createdAt: OLD,
      ...core,
    },
    socialData: null,
    ...top,
  };
}

async function seedOwner(uid: string, user: Data = {}, profile: Data | null = { publicRecipeCount: 0 }) {
  await db.doc(`users/${uid}`).set({ createdAt: OLD, ...user });
  if (profile) await db.doc(`public_profiles/${uid}`).set({ displayName: "Anna", ...profile });
}

const recipeRef = (uid: string, id: string) => db.doc(`users/${uid}/recipes/${id}`);
const copyRef = (uid: string, id: string) => db.doc(`users/${uid}/public_recipes/${id}`);
const countOf = async (uid: string) => (await db.doc(`public_profiles/${uid}`).get()).get("publicRecipeCount");

/** Every key anywhere in [value]. */
function keysDeep(value: unknown, out: Set<string> = new Set()): Set<string> {
  if (Array.isArray(value)) value.forEach((v) => keysDeep(v, out));
  else if (value && typeof value === "object" && !(value instanceof admin.firestore.Timestamp)) {
    for (const [k, v] of Object.entries(value)) {
      out.add(k);
      keysDeep(v, out);
    }
  }
  return out;
}

const PERSONAL = [
  "rating", "personalTags", "personalTagIds", "tagOverrides", "isFavorite", "lastCookedAt",
  "cookCount", "averageRating", "familyAverage", "tagResult", "sourceArtefact", "socialData",
  "memberPermissions", "ingredientId", "showOnProfile", "isPublic", "createdBy",
];

async function pure(): Promise<void> {
  const uid = "u1";
  const copy = buildPublicCopy(uid, "r1", recipe(uid));
  const allowed = new Set<string>(PUBLIC_COPY_KEYS);
  const extra = Object.keys(copy).filter((k) => !allowed.has(k));
  check("the copy holds only allowlisted top-level keys", extra.length === 0, JSON.stringify(extra));
  const leaked = PERSONAL.filter((k) => keysDeep(copy).has(k));
  check("no personal field appears at any depth", leaked.length === 0, JSON.stringify(leaked));
  check(
    "only the owner's own Storage images are kept",
    JSON.stringify(copy.imageUrls) === JSON.stringify([ownImage(uid)]) && copy.thumbnailUrl === ownImage(uid, "thumb.jpg"),
    JSON.stringify(copy.imageUrls),
  );
  check("ownerId is the path uid", copy.ownerId === uid && copy.id === "r1");
  check("an outside host is not an own image", !isOwnStorageImage("https://evil.example/x.jpg", uid));
  check(
    "a path escaping the owner's prefix is not an own image",
    !isOwnStorageImage(ownImage(uid, "../../other/x.jpg"), uid),
  );
  check("a javascript: source URL is dropped", buildPublicCopy(uid, "r", recipe(uid, { sourceUrl: "javascript:alert(1)" })).sourceUrl === null);
  check("a photo import is a scan", isPhotoScan(recipe(uid, { sourceArtefact: { type: "photoOcr", payload: "x" } })));
  check("a web import is not a scan", !isPhotoScan(recipe(uid, { sourceArtefact: { type: "url", payload: "x" } })));
  const scanCopy = buildPublicCopy(uid, "r", recipe(uid, { sourceArtefact: { type: "photoOcr", payload: "x" } }));
  check(
    "a photo import's pictures never reach the copy",
    (scanCopy.imageUrls as unknown[]).length === 0 && scanCopy.thumbnailUrl === null,
  );
  check(
    "a cook count change alone needs no work",
    !copyInputsChanged(recipe(uid), recipe(uid, { cookCount: 8, lastCookedAt: admin.firestore.Timestamp.now() })),
  );
  check("a title change needs work", copyInputsChanged(recipe(uid), recipe(uid, { title: "Bullar" })));
  check(
    "sharing the recipe with a member needs work",
    copyInputsChanged(recipe(uid), recipe(uid, {}, { socialData: { memberPermissions: { friend: "view" } } })),
  );
  check(
    "a flat document's top-level flag does not ask for the profile",
    !wantsProfile({ showOnProfile: true, title: "x" }) && wantsProfile(recipe(uid)),
  );
  check("a change of recipe type needs work", copyInputsChanged(recipe(uid), recipe(uid, {}, { type: 1 })));
  check(
    "a timestamp that is not a Timestamp is not copied",
    buildPublicCopy(uid, "r", recipe(uid, { updatedAt: { nested: "x" } })).updatedAt === null,
  );
}

async function scenarios(): Promise<void> {
  {
    const uid = nextUid();
    await seedOwner(uid);
    await recipeRef(uid, "r").set(recipe(uid));
    const r1 = await sync(uid, "r", ADULT);
    const r2 = await sync(uid, "r", ADULT);
    const copy = await copyRef(uid, "r").get();
    check("publishing writes the copy", r1.action === "written" && copy.exists && copy.get("title") === "Kanelbullar");
    const urls = copy.get("imageUrls") as string[];
    check(
      "the copy points at its own public photo, never at the recipe's",
      urls.length === 1 && urls[0].includes(encodeURIComponent(`users/${uid}/public_recipes/r/`)) &&
        !urls.includes(ownImage(uid)) && images.count(uid, "r") === 2,
      JSON.stringify(urls),
    );
    check("a duplicate delivery counts once", (await countOf(uid)) === 1 && r2.action === "written", `count ${await countOf(uid)}`);

    await recipeRef(uid, "r").update({ "core.showOnProfile": false });
    const r3 = await sync(uid, "r", ADULT);
    check("unpublishing removes the copy and the count", r3.action === "deleted" && !(await copyRef(uid, "r").get()).exists && (await countOf(uid)) === 0);
    check("unpublishing deletes the public photos, so their links stop working", images.count(uid, "r") === 0);

    const r4 = await sync(uid, "r", ADULT);
    check("a late replay after unpublishing does not bring the copy back", r4.action === "unchanged" && !(await copyRef(uid, "r").get()).exists && (await countOf(uid)) === 0);
  }

  {
    const uid = nextUid();
    await seedOwner(uid);
    await recipeRef(uid, "r").set(recipe(uid, { isPublic: true }));
    await recipeRef(uid, "r").update({ "core.showOnProfile": admin.firestore.FieldValue.delete() });
    const r = await sync(uid, "r", ADULT);
    check("an old client's isPublic:true alone publishes nothing", r.refusal === "not-requested" && !(await copyRef(uid, "r").get()).exists);
  }

  {
    const uid = nextUid();
    await seedOwner(uid);
    await recipeRef(uid, "r").set(recipe(uid));
    await sync(uid, "r", ADULT);
    await recipeRef(uid, "r").delete();
    const r = await sync(uid, "r", ADULT);
    check("deleting the recipe deletes the copy", r.refusal === "recipe-gone" && !(await copyRef(uid, "r").get()).exists && (await countOf(uid)) === 0);
  }

  const refusals: [string, Data, Data, OwnerStanding | null, Data | null, string][] = [
    ["a minor", { isMinor: true }, {}, ADULT, null, "minor"],
    ["an account without the age claim", {}, {}, { ...ADULT, ageCompliant: false }, null, "age"],
    ["a guest", {}, {}, { ...ADULT, guest: true }, null, "guest"],
    ["an unverified account younger than an hour", { createdAt: admin.firestore.Timestamp.now() }, {}, { ...ADULT, emailVerified: false }, null, "not-matured"],
    ["an Auth account that is gone", {}, {}, null, null, "account-gone"],
    ["a collaborative recipe", {}, {}, ADULT, { socialData: { memberPermissions: { friend: "view" } } }, "shared"],
    ["a shared recipe type", {}, {}, ADULT, { type: 1 }, "shared"],
  ];
  for (const [label, user, core, standing, top, refusal] of refusals) {
    const uid = nextUid();
    await seedOwner(uid, user);
    await recipeRef(uid, "r").set(recipe(uid, core, top ?? {}));
    const r = await sync(uid, "r", standing);
    check(`${label} is not shown on the profile`, r.refusal === refusal && !(await copyRef(uid, "r").get()).exists, JSON.stringify(r));
  }

  {
    const uid = nextUid();
    await seedOwner(uid);
    await recipeRef(uid, "r").set(recipe(uid));
    await sync(uid, "r", ADULT);
    await db.doc(`erasures_in_progress/${uid}`).set({ startedAtMs: Date.now() });
    await db.doc(`public_profiles/${uid}`).delete();
    await db.doc(`users/${uid}`).delete();
    const r = await sync(uid, "r", ADULT);
    check("during an erasure the copy is removed", r.refusal === "erasure" && !(await copyRef(uid, "r").get()).exists);
    check("an erasure's late event never recreates the profile", !(await db.doc(`public_profiles/${uid}`).get()).exists);
    await recipeRef(uid, "r").delete();
    await db.doc(`erasures_in_progress/${uid}`).delete();
    const late = await sync(uid, "r", ADULT);
    check(
      "a late event after the erasure leaves neither copy nor profile",
      late.action === "unchanged" && !(await copyRef(uid, "r").get()).exists && !(await db.doc(`public_profiles/${uid}`).get()).exists,
    );
  }

  {
    const uid = nextUid();
    await seedOwner(uid);
    await recipeRef(uid, "r").set(recipe(uid, { sourceUrl: "https://example.se/bullar", sourceAuthor: "Kocken" }));
    const r = await sync(uid, "r", ADULT);
    const copy = await copyRef(uid, "r").get();
    check(
      "an imported recipe is shown, with its source and author (Malin 2026-10-31)",
      r.action === "written" && copy.get("sourceUrl") === "https://example.se/bullar" && copy.get("sourceAuthor") === "Kocken",
    );
    await recipeRef(uid, "r").update({ "core.imageUrls": [] , "core.thumbnailUrl": null });
    await sync(uid, "r", ADULT);
    check("a photo removed from the recipe is removed from the profile", images.count(uid, "r") === 0);
  }

  {
    const uid = nextUid();
    await seedOwner(uid, {}, { publicRecipeCount: 100 });
    await recipeRef(uid, "r").set(recipe(uid));
    const r = await sync(uid, "r", ADULT);
    check("past the per-user cap a new copy is refused", r.refusal === "limit" && (await countOf(uid)) === 100);
  }

  {
    const uid = nextUid();
    await seedOwner(uid);
    await recipeRef(uid, "r").set(recipe(uid));
    await sync(uid, "r", ADULT);
    await recipeRef(uid, "r").update({ "socialData.memberPermissions.friend": "view" });
    const r = await sync(uid, "r", ADULT);
    check(
      "sharing a recipe already shown removes its copy and its count",
      r.refusal === "shared" && !(await copyRef(uid, "r").get()).exists && (await countOf(uid)) === 0 &&
        images.count(uid, "r") === 0,
      JSON.stringify(r),
    );
    const shared = await recipeRef(uid, "r").get();
    check(
      "sharing turns the owner's profile choice off",
      shared.get("core.showOnProfile") === false &&
        shared.get("core.showOnProfileChangedAt") instanceof admin.firestore.Timestamp,
    );
    const stamp = shared.get("core.showOnProfileChangedAt") as admin.firestore.Timestamp;
    const again = await sync(uid, "r", ADULT);
    check(
      "the trigger's own write is a no-op",
      again.refusal === "not-requested" &&
        (await recipeRef(uid, "r").get()).get("core.showOnProfileChangedAt").isEqual(stamp),
      JSON.stringify(again),
    );
    await recipeRef(uid, "r").update({ "socialData.memberPermissions": {} });
    const unshared = await sync(uid, "r", ADULT);
    check(
      "unsharing it later does not put it back on the profile",
      unshared.refusal === "not-requested" && !(await copyRef(uid, "r").get()).exists && (await countOf(uid)) === 0,
      JSON.stringify(unshared),
    );
  }

  {
    // Shared while another refusal comes first: the choice is still turned off.
    const uid = nextUid();
    await seedOwner(uid, { isMinor: true });
    await recipeRef(uid, "r").set(recipe(uid, {}, { socialData: { memberPermissions: { friend: "view" } } }));
    const r = await sync(uid, "r", ADULT);
    check(
      "a shared recipe loses the profile choice even when the owner is refused first",
      r.refusal === "minor" && (await recipeRef(uid, "r").get()).get("core.showOnProfile") === false,
      JSON.stringify(r),
    );
  }

  {
    const uid = nextUid();
    await seedOwner(uid, {}, null);
    await recipeRef(uid, "r").set(recipe(uid));
    const r = await sync(uid, "r", ADULT);
    check(
      "without a profile document nothing is published, so the cap holds",
      r.refusal === "profile-gone" && !(await copyRef(uid, "r").get()).exists && images.count(uid, "r") === 0,
      JSON.stringify(r),
    );
  }

  {
    const uid = nextUid();
    await seedOwner(uid);
    await recipeRef(uid, "r").set(recipe(uid, { thumbnailUrl: null }));
    images.onEnsure = () => recipeRef(uid, "r").update({ "core.imageUrls": [ownImage(uid, "b.jpg")] });
    let stale = false;
    try {
      await sync(uid, "r", ADULT);
    } catch (err) {
      stale = err instanceof StalePhotosError;
    }
    check(
      "a recipe whose photos change mid-run is not written without them",
      stale && !(await copyRef(uid, "r").get()).exists,
    );
    const retry = await sync(uid, "r", ADULT);
    const urls = (await copyRef(uid, "r").get()).get("imageUrls") as string[];
    check(
      "the redelivery shows the new photo",
      retry.action === "written" && urls.length === 1 &&
        urls[0].includes(encodeURIComponent(publicImagePath(uid, "r", `users/${uid}/recipes/b.jpg`))),
      JSON.stringify(urls),
    );
  }

  {
    const uid = nextUid();
    await seedOwner(uid);
    await recipeRef(uid, "r").set(recipe(uid, { thumbnailUrl: null }));
    await sync(uid, "r", ADULT);
    // An older delivery that prunes after a newer one keeps the newer photo:
    // the keep set comes from the recipe as it is, not from the old run.
    await recipeRef(uid, "r").update({ "core.imageUrls": [ownImage(uid, "b.jpg")] });
    await sync(uid, "r", ADULT);
    const keptB = [...images.objects].includes(publicImagePath(uid, "r", `users/${uid}/recipes/b.jpg`));
    check("the new photo is kept and the old one removed", keptB && images.count(uid, "r") === 1);
  }

  {
    const uid = nextUid();
    await seedOwner(uid);
    await recipeRef(uid, "r").set(recipe(uid, { thumbnailUrl: null }));
    images.clock = () => Date.now();
    await sync(uid, "r", ADULT);
    images.clock = () => Date.now() - 60_000;
    await recipeRef(uid, "r").update({ "core.showOnProfile": false });
    let pending = false;
    try {
      await sync(uid, "r", ADULT);
    } catch (err) {
      pending = err instanceof PublicPhotosPendingError;
    }
    check(
      "unpublishing at once leaves the copy gone and asks to run again for the photo",
      pending && !(await copyRef(uid, "r").get()).exists && images.count(uid, "r") === 1,
    );
    images.ageAll();
    await sync(uid, "r", ADULT);
    check("the run after that deletes the photo", images.count(uid, "r") === 0);
  }

  {
    const uid = nextUid();
    await seedOwner(uid, {}, { publicRecipeCount: 0 });
    await copyRef(uid, "r").set({ id: "r" });
    await recipeRef(uid, "r").set(recipe(uid, { showOnProfile: false }));
    await sync(uid, "r", ADULT);
    check("the count never goes below zero", (await countOf(uid)) === 0);
  }
}

async function main(): Promise<void> {
  await pure();
  await scenarios();
  console.log(`\n${run - failed}/${run} passed`);
  if (failed > 0) process.exit(1);
}

main().catch((err) => {
  console.error(err);
  process.exit(1);
});
