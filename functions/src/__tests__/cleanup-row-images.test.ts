/**
 * `onRecipeCommentDeleted` and `onCookSnapDeleted` (BUT-2337, BUT-2346) — unit
 * tests with a fake bucket and a fake Firestore, no emulator.
 *
 * A deleted row takes the images under its author's own folder with it, and
 * nothing else: another account's files, another folder of the author's, and
 * a path that climbs out are refused. A deleted cook snap also takes its
 * owner's `cooked` feed event.
 *
 * Run: npx ts-node src/__tests__/cleanup-row-images.test.ts
 */

import * as admin from "firebase-admin";
if (!admin.apps.length) {
  admin.initializeApp({ projectId: "butlery-test-cleanup-row-images" });
}

const {
  handleCommentDeleted,
  handleCookSnapDeleted,
  handleCookSnapFeedEvents,
  onCookSnapDeletedEvent,
  onRecipeCommentDeleted,
  onCookSnapDeleted,
  // eslint-disable-next-line @typescript-eslint/no-require-imports
} = require("../cleanup/cleanup-row-images");

const UID = "author-uid";
const OTHER = "other-uid";

let failed = 0;
let passed = 0;
function check(name: string, ok: boolean, detail = ""): void {
  if (ok) {
    passed++;
    console.log(`  PASS  ${name}`);
  } else {
    failed++;
    console.log(`  FAIL  ${name}${detail ? `\n        ${detail}` : ""}`);
  }
}

const url = (p: string): string =>
  `https://firebasestorage.googleapis.com/v0/b/bucket/o/${encodeURIComponent(p)}?alt=media&token=t`;

class FakeBucket {
  deleted: string[] = [];
  failOn = new Map<string, number | string>();
  file(path: string) {
    return {
      delete: async () => {
        const code = this.failOn.get(path);
        if (code !== undefined) {
          throw Object.assign(new Error(`delete failed: ${path}`), { code });
        }
        this.deleted.push(path);
      },
    };
  }
}

async function commentImagesAreDeleted(): Promise<void> {
  const bucket = new FakeBucket();
  const a = `users/${UID}/comment_images/comment_1_aaaa.jpg`;
  const b = `users/${UID}/comment_images/comment_2_bbbb.png`;
  const result = await handleCommentDeleted(bucket, "c1", {
    authorId: UID,
    imageUrls: [url(a), url(b)],
  });
  check(
    "a deleted comment's images are deleted",
    JSON.stringify(bucket.deleted.sort()) === JSON.stringify([a, b].sort()),
    JSON.stringify(bucket.deleted),
  );
  check("…and counted", result?.deleted === 2 && result?.failed === 0);
}

async function commentGuardRefusesOtherPaths(): Promise<void> {
  const bucket = new FakeBucket();
  const own = `users/${UID}/comment_images/ok.jpg`;
  const result = await handleCommentDeleted(bucket, "c1", {
    authorId: UID,
    imageUrls: [
      url(`users/${OTHER}/comment_images/theirs.jpg`),
      url(`users/${UID}/recipes/photo.jpg`),
      url(`users/${UID}/avatars/me.jpg`),
      url(`users/${UID}/comment_images/../recipes/photo.jpg`),
      url(`users/${UID}/comment_images/`),
      "https://example.com/not-storage.jpg",
      42,
      url(own),
    ],
  });
  check(
    "only the author's own comment image is deleted",
    JSON.stringify(bucket.deleted) === JSON.stringify([own]),
    JSON.stringify(bucket.deleted),
  );
  check(
    "…and the six refused URLs are counted as failed",
    result?.failed === 6,
    JSON.stringify(result),
  );
}

async function commentWithoutImagesOrAuthor(): Promise<void> {
  const bucket = new FakeBucket();
  check(
    "a comment without images does nothing",
    (await handleCommentDeleted(bucket, "c1", { authorId: UID, text: "x" })) ===
      null && bucket.deleted.length === 0,
  );
  check(
    "a comment without an author keeps its images",
    (await handleCommentDeleted(bucket, "c1", {
      imageUrls: [url(`users/${UID}/comment_images/a.jpg`)],
    })) === null && bucket.deleted.length === 0,
  );
  check(
    "a delete event without data does nothing",
    (await handleCommentDeleted(bucket, "c1", undefined)) === null,
  );
}

async function commentDeleteFailuresDoNotStopTheRest(): Promise<void> {
  const bucket = new FakeBucket();
  const gone = `users/${UID}/comment_images/gone.jpg`;
  const broken = `users/${UID}/comment_images/broken.jpg`;
  const fine = `users/${UID}/comment_images/fine.jpg`;
  bucket.failOn.set(gone, 404);
  bucket.failOn.set(broken, 503);
  const result = await handleCommentDeleted(bucket, "c1", {
    authorId: UID,
    imageUrls: [url(gone), url(broken), url(fine)],
  });
  check(
    "a 404 and a failed delete do not stop the next image",
    JSON.stringify(bucket.deleted) === JSON.stringify([fine]),
    JSON.stringify(bucket.deleted),
  );
  check(
    "…the 404 is not a failure, the 503 is",
    result?.failed === 1 && result?.deleted === 1,
    JSON.stringify(result),
  );
}

async function cookSnapPhotosAndThumbnailsAreDeleted(): Promise<void> {
  const bucket = new FakeBucket();
  const cover = `users/${UID}/recipes/snap_1.jpg`;
  const second = `users/${UID}/recipes/snap_2.jpg`;
  const thumb = `users/${UID}/recipes/thumbnails/snap_1_thumb.jpg`;
  const result = await handleCookSnapDeleted(bucket, "s1", {
    userId: UID,
    photoUrl: url(cover),
    photoUrls: [url(cover), url(second)],
    thumbnailUrl: url(thumb),
  });
  const deleted = new Set(bucket.deleted);
  check(
    "a deleted cook snap's photos are deleted, the repeated cover once",
    deleted.has(cover) &&
      deleted.has(second) &&
      bucket.deleted.filter((p) => p === cover).length === 1,
    JSON.stringify(bucket.deleted),
  );
  check(
    "…with their thumbnails",
    deleted.has(thumb) &&
      deleted.has(`users/${UID}/recipes/thumbnails/snap_2_thumb.jpg`),
    JSON.stringify(bucket.deleted),
  );
  check("…and nothing failed", result?.failed === 0, JSON.stringify(result));
}

async function cookSnapGuardRefusesOtherPaths(): Promise<void> {
  const bucket = new FakeBucket();
  await handleCookSnapDeleted(bucket, "s1", {
    userId: UID,
    photoUrls: [
      url(`users/${OTHER}/recipes/theirs.jpg`),
      url(`users/${UID}/comment_images/c.jpg`),
      url(`users/${UID}/recipes/%2e%2e/avatars/me.jpg`),
    ],
  });
  check(
    "a cook snap naming another account's or another folder's file deletes nothing",
    bucket.deleted.length === 0,
    JSON.stringify(bucket.deleted),
  );
  check(
    "a cook snap without an owner keeps its photos",
    (await handleCookSnapDeleted(bucket, "s1", {
      photoUrls: [url(`users/${UID}/recipes/a.jpg`)],
    })) === null && bucket.deleted.length === 0,
  );
}

async function cookSnapUrlListIsCapped(): Promise<void> {
  const bucket = new FakeBucket();
  const paths = Array.from(
    { length: 10 },
    (_, i) => `users/${UID}/recipes/thumbnails/p${i}.jpg`,
  );
  await handleCookSnapDeleted(bucket, "s1", {
    userId: UID,
    photoUrls: paths.map(url),
  });
  check(
    "a cook snap carrying more URLs than the app writes deletes only the first 7",
    bucket.deleted.length === 7 &&
      paths.slice(0, 7).every((p) => bucket.deleted.includes(p)),
    JSON.stringify(bucket.deleted),
  );
}

type Row = Record<string, unknown>;

function fieldAt(row: Row, path: string): unknown {
  return path.split(".").reduce<unknown>(
    (v, key) => (v && typeof v === "object" ? (v as Row)[key] : undefined),
    row,
  );
}

// Applies every filter by dot-path, so a query missing a filter matches more.
class FakeFeedDb {
  events = new Map<string, Row>();
  queries = 0;
  failQuery = false;
  collection(name: string) {
    const filters: [string, string, unknown][] = [];
    let cap = Infinity;
    const query = {
      where: (field: string, op: string, value: unknown) => {
        filters.push([field, op, value]);
        return query;
      },
      limit: (n: number) => {
        cap = n;
        return query;
      },
      get: async () => {
        this.queries++;
        if (this.failQuery) throw new Error("firestore unavailable");
        if (name !== "activity_events") return { docs: [] };
        const docs = [...this.events.entries()]
          .filter(([, row]) =>
            filters.every(([f, op, v]) => {
              const actual = fieldAt(row, f);
              return op === "in" ? (v as unknown[]).includes(actual) : actual === v;
            }),
          )
          .slice(0, cap)
          .map(([id, row]) => ({ ref: id, data: () => row }));
        return { docs };
      },
    };
    return query;
  }
  batch() {
    const refs: string[] = [];
    return {
      delete: (ref: unknown) => refs.push(ref as string),
      commit: async () => {
        for (const ref of refs) this.events.delete(ref);
      },
    };
  }
}

const COVER = url(`users/${UID}/recipes/cover.jpg`);
const SECOND = url(`users/${UID}/recipes/second.jpg`);

function cooked(actorId: string, photoUrl: string): Row {
  return {
    actorId,
    type: "cooked",
    recipeId: "r1",
    extraData: { photoUrl, photoUrls: [photoUrl], caption: "Gott" },
  };
}

async function snapDeleteTakesOnlyTheOwnersCookedEvent(): Promise<void> {
  const db = new FakeFeedDb();
  db.events.set("mine", cooked(UID, COVER));
  db.events.set("theirs", cooked(OTHER, COVER));
  db.events.set("mine-shared", { ...cooked(UID, COVER), type: "shared" });
  db.events.set("mine-other-snap", cooked(UID, url(`users/${UID}/recipes/x.jpg`)));
  db.events.set("mine-started", { actorId: UID, type: "startedCooking", recipeId: "r1" });
  const deleted = await handleCookSnapFeedEvents(db, "s1", {
    userId: UID,
    photoUrl: COVER,
    photoUrls: [COVER, SECOND],
  });
  check("the owner's cooked event for the snap is deleted", !db.events.has("mine"));
  check(
    "another account's event carrying the same URL is kept",
    db.events.has("theirs"),
  );
  check(
    "the owner's non-cooked event carrying the same URL is kept",
    db.events.has("mine-shared"),
  );
  check(
    "the owner's events for other snaps are kept",
    db.events.has("mine-other-snap") && db.events.has("mine-started"),
  );
  check("…and one event is counted", deleted === 1, String(deleted));
}

async function feedEventReadIsCapped(): Promise<void> {
  const db = new FakeFeedDb();
  for (let i = 0; i < 11; i++) db.events.set(`e${i}`, cooked(UID, COVER));
  const deleted = await handleCookSnapFeedEvents(db, "s1", {
    userId: UID,
    photoUrls: [COVER],
  });
  check(
    "eleven matching events: the first ten are deleted, one is kept",
    deleted === 10 && db.events.size === 1,
    `deleted=${deleted} kept=${db.events.size}`,
  );
}

async function attackerSnapCannotReachVictimEvent(): Promise<void> {
  const db = new FakeFeedDb();
  const victimCover = url(`users/${OTHER}/recipes/cover.jpg`);
  db.events.set("victim", cooked(OTHER, victimCover));
  await handleCookSnapFeedEvents(db, "s1", {
    userId: UID,
    photoUrls: [victimCover],
  });
  check(
    "a snap that copies someone else's photo URL leaves their event",
    db.events.has("victim"),
  );
}

async function anyOfTheSnapsUrlsLinksTheEvent(): Promise<void> {
  const legacy = new FakeFeedDb();
  legacy.events.set("e", cooked(UID, COVER));
  await handleCookSnapFeedEvents(legacy, "s1", { userId: UID, photoUrl: COVER });
  check("a legacy snap with only photoUrl takes its event", !legacy.events.has("e"));

  const reordered = new FakeFeedDb();
  reordered.events.set("e", cooked(UID, SECOND));
  await handleCookSnapFeedEvents(reordered, "s1", {
    userId: UID,
    photoUrls: [COVER, SECOND],
  });
  check(
    "an event whose photo is not the snap's current cover is still taken",
    !reordered.events.has("e"),
  );
}

async function nothingToMatchReadsNothing(): Promise<void> {
  const db = new FakeFeedDb();
  db.events.set("e", { ...cooked(UID, ""), extraData: { photoUrl: "" } });
  const cases: [string, Row | undefined][] = [
    ["no data", undefined],
    ["no owner", { photoUrls: [COVER] }],
    ["no photo", { userId: UID }],
    ["an empty-string photo", { userId: UID, photoUrl: "", photoUrls: [""] }],
  ];
  for (const [label, data] of cases) {
    await handleCookSnapFeedEvents(db, "s1", data);
    check(
      `a snap with ${label} reads and deletes nothing`,
      db.queries === 0 && db.events.has("e"),
      `queries=${db.queries}`,
    );
  }
}

async function eachHalfSurvivesTheOtherFailing(): Promise<void> {
  const photo = `users/${UID}/recipes/cover.jpg`;
  const snap = { userId: UID, photoUrls: [url(photo)] };

  const bucket = new FakeBucket();
  const failingDb = new FakeFeedDb();
  failingDb.failQuery = true;
  await onCookSnapDeletedEvent(bucket, failingDb, "s1", snap);
  check(
    "a failed feed query still deletes the photos",
    bucket.deleted.includes(photo),
    JSON.stringify(bucket.deleted),
  );

  const db = new FakeFeedDb();
  db.events.set("e", cooked(UID, url(photo)));
  const throwingBucket = {
    file: () => {
      throw new Error("storage unavailable");
    },
  };
  await onCookSnapDeletedEvent(throwingBucket, db, "s1", snap);
  check("a failed photo delete still deletes the event", !db.events.has("e"));
}

function triggersListenOnTheRowPaths(): void {
  const comment = (onRecipeCommentDeleted as { __endpoint?: Record<string, unknown> })
    .__endpoint;
  const snap = (onCookSnapDeleted as { __endpoint?: Record<string, unknown> })
    .__endpoint;
  const filters = (e: Record<string, unknown> | undefined) =>
    JSON.stringify((e?.eventTrigger as Record<string, unknown>)?.eventFilterPathPatterns);
  check(
    "onRecipeCommentDeleted listens on recipe_comments/{commentId}",
    filters(comment).includes("recipe_comments/{commentId}"),
    filters(comment),
  );
  check(
    "onCookSnapDeleted listens on cook_snaps/{snapId}",
    filters(snap).includes("cook_snaps/{snapId}"),
    filters(snap),
  );
}

async function main(): Promise<void> {
  console.log("BUT-2337: images of a deleted comment or cook snap");
  await commentImagesAreDeleted();
  await commentGuardRefusesOtherPaths();
  await commentWithoutImagesOrAuthor();
  await commentDeleteFailuresDoNotStopTheRest();
  await cookSnapPhotosAndThumbnailsAreDeleted();
  await cookSnapGuardRefusesOtherPaths();
  await cookSnapUrlListIsCapped();
  console.log("BUT-2346: a deleted cook snap takes its feed event");
  await snapDeleteTakesOnlyTheOwnersCookedEvent();
  await feedEventReadIsCapped();
  await attackerSnapCannotReachVictimEvent();
  await anyOfTheSnapsUrlsLinksTheEvent();
  await nothingToMatchReadsNothing();
  await eachHalfSurvivesTheOtherFailing();
  triggersListenOnTheRowPaths();
  console.log(`\n${passed}/${passed + failed} passed`);
  if (failed > 0) process.exit(1);
}

main().catch((e) => {
  console.error(e);
  process.exit(1);
});
