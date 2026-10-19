/**
 * BUT-2414: the message, realtime and legacy fixtures for
 * `erasure-residue.test.ts`, in the shape `_erasure-residue-cases.ts`
 * describes.
 */

import { FakeFirestore } from "./_fake-firestore";
import { OTHER, STRAY, SectionCase, T0, T0_ISO, THIRD, UID } from "./_erasure-residue-cases";

function many(db: FakeFirestore, n: number, path: (i: number) => string, data: object): void {
  for (let i = 0; i < n; i++) db.seed(path(i), { ...data });
}

function expect(cond: boolean, msg: string): void {
  if (!cond) throw new Error(msg);
}

const ROWS = 2001;

export const CASES_2: SectionCase[] = [
  {
    section: "messages_in_left_conversations",
    idKey: "messageId",
    rows: ["m1", "m4", "p1", "p3"],
    seed: (db) => {
      db.seed("conversations/Cleft", { participantIds: [OTHER] });
      db.seed("conversations/Cin", { participantIds: [UID, OTHER] });
      db.seed("messages/m1", {
        senderId: UID, senderDisplayName: "Me", conversationId: "Cleft", content: "hej",
        type: "text", sentAt: T0, reactions: { heart: [OTHER] }, ...STRAY,
      });
      db.seed("messages/m2", { senderId: UID, conversationId: "Cin", content: "kvar" });
      db.seed("messages/m3", { senderId: OTHER, conversationId: "Cleft", content: "deras" });
      db.seed("messages/m4", { senderId: UID, conversationId: "Cgone", content: "borta" });
      db.seed("messages/p1", {
        senderId: UID, conversationId: "Cleft", type: "poll", content: "Omröstning", ...STRAY,
        metadata: {
          poll: {
            creatorId: UID, question: "Vad äter vi?", isClosed: false, ...STRAY,
            options: [{ id: "o1", text: "Pasta", voterIds: [OTHER], ...STRAY }],
          },
        },
      });
      db.seed("messages/p2", {
        senderId: UID, conversationId: "Cin", type: "poll",
        metadata: { poll: { creatorId: UID, question: "Stannar" } },
      });
      // Planted: any sender can write the requester's uid into poll.creatorId.
      db.seed("conversations/Cx", { participantIds: [OTHER, THIRD] });
      db.seed("messages/p3", {
        senderId: OTHER, conversationId: "Cx", type: "poll", content: "deras text",
        metadata: { poll: { creatorId: UID, question: "Deras fråga" } },
      });
    },
    check: ([m1, , p1, p3]) => {
      expect(m1.content === "hej" && m1.sentAt === T0_ISO && m1.type === "text", "message fields");
      expect(m1.sent_by_you === true && !("poll" in m1), "plain message");
      expect(!("senderDisplayName" in m1) && !("reactions" in m1), "no name, no reactions");
      const poll = p1.poll as Record<string, unknown>;
      expect(poll.question === "Vad äter vi?", "poll question");
      expect(JSON.stringify(poll.options) === '[{"id":"o1","text":"Pasta"}]', "options without voters");
      expect(
        JSON.stringify(p3) ===
          '{"messageId":"p3","sent_by_you":false,"names_you_as_poll_creator":true}',
        "a planted row carries none of the planter's message",
      );
    },
    overCap: (db) => {
      db.seed("conversations/Cleft", { participantIds: [OTHER] });
      many(db, 5001, (i) => `messages/x${i}`, { senderId: UID, conversationId: "Cleft" });
    },
  },
  {
    section: "realtime_menus",
    idKey: "menuId",
    rows: ["M1", "M2", "M3"],
    seed: (db) => {
      db.seed("realtime_menus/M1", {
        ownerId: UID, ownerDisplayName: "Me", participants: { [OTHER]: "edit" },
        participantIds: [UID, OTHER], data: { dishes: ["x"] }, createdAt: T0, lastEditedBy: UID,
        ...STRAY,
      });
      db.seed("realtime_menus/M2", {
        ownerId: OTHER, ownerDisplayName: "Them", lastEditedBy: UID,
        lastEditedByDisplayName: "Me", participantIds: [OTHER], ...STRAY,
      });
      db.seed("realtime_menus/M3", {
        ownerId: OTHER, participantIds: [OTHER, UID],
        participants: { [UID]: "view", [OTHER]: "owner" }, ...STRAY,
      });
      db.seed("realtime_menus/M4", { ownerId: OTHER, participantIds: [OTHER] });
    },
    check: ([m1, m2, m3]) => {
      expect(JSON.stringify(m1.relation) === '["owner"]', "an owned menu is not also joined or edited");
      expect(m1.ownerDisplayName === "Me" && !("data" in m1) && !("participants" in m1), "owner fields");
      expect(JSON.stringify(m2.relation) === '["last_editor"]' && m2.lastEditedBy === UID, "editor");
      expect(!("ownerDisplayName" in m2), "the owner's name is not the requester's");
      expect(m3.permission === "view", "own permission");
    },
    overCap: (db) => many(db, ROWS, (i) => `realtime_menus/o${i}`, { ownerId: UID }),
  },
  {
    section: "realtime_menu_votes",
    idKey: "voteId",
    rows: ["v1"],
    seed: (db) => {
      db.seed("realtime_menus/M3", { ownerId: OTHER, participantIds: [OTHER, UID] });
      db.seed("realtime_menus/M3/votes/v1", { votes: { [UID]: "o1", [OTHER]: "o2" }, ...STRAY });
      db.seed("realtime_menus/M3/votes/v2", { votes: { [OTHER]: "o2" } });
      db.seed("realtime_menus/M1", { ownerId: UID, participantIds: [UID] });
      db.seed("realtime_menus/M1/votes/v3", { votes: { [UID]: "o9" } });
    },
    check: ([row]) => expect(row.optionId === "o1" && row.menuId === "M3", "own choice only"),
    overCap: (db) => {
      db.seed("realtime_menus/M3", { ownerId: OTHER, participantIds: [UID] });
      many(db, ROWS, (i) => `realtime_menus/M3/votes/v${i}`, { votes: { [UID]: "o" } });
    },
  },
  {
    section: "realtime_presence",
    idKey: "resourceId",
    rows: ["M1", "R1"],
    seed: (db) => {
      db.seed("realtime_resources/R1", { ownerId: OTHER, participantIds: [UID, OTHER] });
      db.seed(`realtime_resources/R1/presence/${UID}`, { displayName: "Me", lastSeen: T0, ...STRAY });
      db.seed(`realtime_resources/R1/presence/${OTHER}`, { displayName: "Them" });
      db.seed("realtime_menus/M1", { ownerId: UID, participantIds: [UID] });
      db.seed(`realtime_menus/M1/presence/${UID}`, { displayName: "Me", isActive: true });
      db.seed("realtime_resources/R9", { ownerId: OTHER, participantIds: [OTHER] });
      db.seed(`realtime_resources/R9/presence/${UID}`, { displayName: "Left" });
    },
    check: ([m1, r1]) => {
      expect(m1.collection === "realtime_menus" && r1.collection === "realtime_resources", "collections");
    },
    overCap: (db) => many(db, ROWS, (i) => `realtime_resources/o${i}`, { ownerId: UID }),
  },
  {
    section: "realtime_resources_last_edited",
    idKey: "resourceId",
    rows: ["R2"],
    seed: (db) => {
      db.seed("realtime_resources/R2", {
        ownerId: OTHER, ownerDisplayName: "Them", lastEditedBy: UID,
        lastEditedByDisplayName: "Me", lastEditedAt: T0, ...STRAY,
      });
      db.seed("realtime_resources/R3", { ownerId: UID, lastEditedBy: UID });
      db.seed("realtime_resources/R4", { ownerId: OTHER, lastEditedBy: THIRD });
    },
    overCap: (db) =>
      many(db, ROWS, (i) => `realtime_resources/e${i}`, { ownerId: OTHER, lastEditedBy: UID }),
  },
  {
    section: "legacy_recipes",
    idKey: "recipeId",
    rows: ["r1"],
    seed: (db) => {
      db.seed("recipes/r1", { userId: UID, title: "Gammal", ...STRAY });
      db.seed("recipes/r2", { userId: OTHER, title: "Deras" });
    },
    overCap: (db) => many(db, ROWS, (i) => `recipes/x${i}`, { userId: UID }),
  },
  {
    section: "legacy_shopping_lists",
    idKey: "listId",
    rows: ["L1", "L2"],
    seed: (db) => {
      db.seed(`users/${UID}/shopping_lists/L1`, { name: "Gammal lista", ...STRAY });
      db.seed(`users/${UID}/shopping_lists/L1/items/i1`, { name: "Mjölk", ...STRAY });
      // A parent that is gone still has its items, which `listDocuments` reaches.
      db.seed(`users/${UID}/shopping_lists/L2/items/i2`, { name: "Ägg" });
      db.seed(`users/${OTHER}/shopping_lists/L3`, { name: "Deras" });
    },
    check: ([l1, l2]) => {
      expect(JSON.stringify(l1.items) === '[{"itemId":"i1","name":"Mjölk"}]', "items projected");
      expect((l2.items as unknown[]).length === 1, "orphaned items found");
    },
    overCap: (db) => many(db, ROWS, (i) => `users/${UID}/shopping_lists/l${i}`, { name: "x" }),
  },
  {
    section: "legacy_comments",
    idKey: "commentId",
    rows: ["c1"],
    seed: (db) => {
      db.seed("users/u2/recipes/r/comments/c1", { commentedBy: UID, text: "Gott", ...STRAY });
      db.seed("users/u2/recipes/r/comments/c2", { commentedBy: OTHER, text: "Deras" });
    },
    overCap: (db) => many(db, ROWS, (i) => `users/u2/recipes/r${i}/comments/c`, { commentedBy: UID }),
  },
  {
    section: "legacy_ratings",
    idKey: "ratingId",
    rows: ["g1"],
    seed: (db) => {
      db.seed("users/u2/recipes/r/ratings/g1", { ratedBy: UID, rating: 4, ...STRAY });
      db.seed("users/u2/recipes/r/ratings/g2", { ratedBy: OTHER, rating: 1 });
    },
    overCap: (db) => many(db, ROWS, (i) => `users/u2/recipes/r${i}/ratings/g`, { ratedBy: UID }),
  },
  {
    section: "legacy_menus_received",
    idKey: "menuId",
    rows: ["mn1"],
    seed: (db) => {
      db.seed("menus/mn1", { sharedToUserIds: [UID], sharedByUserId: OTHER, title: "Deras", ...STRAY });
      db.seed("menus/mn2", { sharedToUserIds: [OTHER] });
    },
    check: ([row]) => expect(Object.keys(row).join() === "menuId", "only the id"),
    overCap: (db) => many(db, ROWS, (i) => `menus/x${i}`, { sharedToUserIds: [UID] }),
  },
  {
    section: "legacy_shared_with",
    idKey: "shareId",
    rows: ["sw1"],
    seed: (db) => {
      db.seed("shared_content/sw1", { sharedWith: [UID], sharedByUserId: OTHER, ...STRAY });
      db.seed("shared_content/sw2", { sharedWith: [OTHER] });
    },
    check: ([row]) => expect(Object.keys(row).join() === "shareId", "only the id"),
    overCap: (db) => many(db, ROWS, (i) => `shared_content/x${i}`, { sharedWith: [UID] }),
  },
];
