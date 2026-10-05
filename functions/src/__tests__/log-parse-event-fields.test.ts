/**
 * BUT-2238: the one parse event an import writes carries channel, strategy,
 * outcome, error code and AI cost. sanitizeParseEvent keeps each only when
 * it is valid, and drops the fields the old per-strategy events sent.
 *
 * Run with: npx ts-node src/__tests__/log-parse-event-fields.test.ts
 */

import {
  countsForSite,
  isLoggable,
  sanitizeParseEvent,
} from "../events/log-parse-event";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const failure = {
  channel: "text",
  strategy: "text",
  outcome: "failure",
  errorCode: "noRecipeContent",
  success: false,
  parseTimeMs: 40,
};

const cases: UnitCase[] = [
  {
    name: "keeps a valid failure event's channel, strategy, outcome and code",
    fn: async () => {
      const f = sanitizeParseEvent(failure);
      assertEqual(f.channel, "text", "channel");
      assertEqual(f.strategy, "text", "strategy");
      assertEqual(f.outcome, "failure", "outcome");
      assertEqual(f.errorCode, "noRecipeContent", "errorCode");
    },
  },
  {
    name: "drops values outside each list",
    fn: async () => {
      const f = sanitizeParseEvent({
        channel: "website",
        strategy: "ocr",
        outcome: "maybe",
        errorCode: "noRecipeContent",
      });
      assertEqual(f.channel, null, "channel");
      assertEqual(f.strategy, null, "strategy");
      assertEqual(f.outcome, null, "outcome");
      assertEqual(f.errorCode, null, "a code without a failure outcome");
    },
  },
  {
    name: "an unknown error code is dropped",
    fn: async () => {
      const f = sanitizeParseEvent({ ...failure, errorCode: "Kunde inte" });
      assertEqual(f.errorCode, null, "errorCode");
    },
  },
  {
    name: "a recipe outcome carries no error code",
    fn: async () => {
      const f = sanitizeParseEvent({ ...failure, outcome: "recipe" });
      assertEqual(f.errorCode, null, "errorCode");
    },
  },
  {
    name: "AI cost is kept in USD and clamped to 0..1",
    fn: async () => {
      assertEqual(
        sanitizeParseEvent({ ...failure, estimatedCostUsd: 0.0012 })
          .estimatedCostUsd,
        0.0012,
        "kept"
      );
      assertEqual(
        sanitizeParseEvent({ ...failure, estimatedCostUsd: 7 })
          .estimatedCostUsd,
        1,
        "clamped"
      );
      assertEqual(
        sanitizeParseEvent({ ...failure, estimatedCostUsd: "0.1" as never })
          .estimatedCostUsd,
        null,
        "not a number"
      );
    },
  },
  {
    name: "the old source and totalCostSek fields are not stored",
    fn: async () => {
      const f = sanitizeParseEvent({
        ...failure,
        source: "url",
        totalCostSek: 3,
      } as never) as Record<string, unknown>;
      assertEqual("source" in f, false, "source");
      assertEqual("totalCostSek" in f, false, "totalCostSek");
    },
  },
  {
    name: "a link event keeps its url and derives the domain from it",
    fn: async () => {
      const f = sanitizeParseEvent({
        ...failure,
        channel: "link",
        url: "https://www.ica.se/recept/x/?token=hemligt",
      });
      assertEqual(f.url, "https://www.ica.se/recept/x/", "token stripped");
      assertEqual(f.domain, "ica.se", "domain");
    },
  },
  {
    name: "success is the outcome, not a separate client flag",
    fn: async () => {
      assertEqual(
        sanitizeParseEvent({ ...failure, success: true }).success,
        false,
        "a failure claiming success"
      );
      assertEqual(
        sanitizeParseEvent({ ...failure, outcome: "recipe" }).success,
        true,
        "a recipe"
      );
    },
  },
  {
    name: "an event needs a link or a channel",
    fn: async () => {
      assertEqual(isLoggable(sanitizeParseEvent({ parseTimeMs: 1 })), false, "neither");
      assertEqual(isLoggable(sanitizeParseEvent(failure)), true, "channel");
    },
  },
  {
    name: "only a live parse of a recipe site moves the site counters",
    fn: async () => {
      const live = {
        channel: "link",
        strategy: "url",
        outcome: "recipe",
        url: "https://www.ica.se/recept/x/",
      };
      assertEqual(countsForSite(sanitizeParseEvent(live)), true, "live parse");
      assertEqual(
        countsForSite(sanitizeParseEvent({ ...live, fromCache: true })),
        false,
        "cache hit"
      );
      for (const strategy of ["youtube", "tiktok", "instagram", "cache"]) {
        assertEqual(
          countsForSite(sanitizeParseEvent({ ...live, strategy })),
          false,
          strategy
        );
      }
      assertEqual(
        countsForSite(sanitizeParseEvent({ ...live, channel: "text" })),
        false,
        "pasted text naming a url"
      );
    },
  },
];

runTests("BUT-2238: sanitizeParseEvent", cases);
