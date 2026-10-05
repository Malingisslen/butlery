/**
 * BUT-2239: scoring and cost cap for the nightly `recipe_from_url` AI corpus.
 *
 * Run with: npx ts-node src/__tests__/golden-recipe-from-url-core.test.ts
 */

import {
  GoldenInput,
  mayCall,
  scorePage,
  skippedSummary,
  summariseRun,
} from "../admin/golden-recipe-from-url-core";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const page: GoldenInput = {
  id: "arla-chokladbollar",
  url: "https://www.arla.se/recept/chokladbollar/",
  text: "Chokladbollar ...",
  goldTitle: "Chokladbollar",
  goldIngredientKeys: ["smör", "socker", "havregryn"],
};

const cases: UnitCase[] = [
  {
    name: "a gold key is found inside a longer extracted name",
    fn: () => {
      const s = scorePage(page, {
        id: page.id,
        title: " chokladbollar ",
        ingredientNames: ["Rumsvarmt smör", "strösocker"],
        estimatedCost: 0.0012,
      });
      assertEqual(s.titleMatches, true, "title compared trimmed, any case");
      assertEqual(s.ingredientsFound, 2, "smör and socker, not havregryn");
      assertEqual(s.goldIngredients, 3, "gold size");
    },
  },
  {
    name: "a failed call scores nothing and keeps its error",
    fn: () => {
      const s = scorePage(page, { id: page.id, estimatedCost: 0.001, error: "boom" });
      assertEqual(s.titleMatches, false, "no title");
      assertEqual(s.ingredientsFound, 0, "no ingredients");
      assertEqual(s.error, "boom", "error kept");
    },
  },
  {
    name: "the summary sums cost and flags a run over the cap",
    fn: () => {
      const outcomes = [
        { id: page.id, estimatedCost: 0.6 },
        { id: "b", estimatedCost: 0.5 },
      ];
      const under = summariseRun([page], outcomes, 1.2);
      assertEqual(under.calls, 2, "calls counted from outcomes");
      assertEqual(under.total_cost_usd, 1.1, "cost summed");
      assertEqual(under.over_cap, false, "1.1 is under 1.2");
      assertEqual(summariseRun([page], outcomes, 1.0).over_cap, true, "1.1 is over 1.0");
    },
  },
  {
    name: "a page with no outcome is reported as not run",
    fn: () => {
      const s = summariseRun([page], [], 1.0);
      assertEqual(s.pages[0].error, "not run", "missing outcome named");
      assertEqual(s.calls, 0, "no calls");
    },
  },
  {
    name: "the run stops before a call that could cross the cap",
    fn: () => {
      assertEqual(mayCall(0.99, 0.01, 1.0), true, "exactly at the cap is allowed");
      assertEqual(mayCall(0.995, 0.01, 1.0), false, "could cross the cap");
    },
  },
  {
    name: "a skipped run reports zero calls and the reason",
    fn: () => {
      const s = skippedSummary("no key", 1.0);
      assertEqual(s.skipped, true, "skipped");
      assertEqual(s.reason, "no key", "reason");
      assertEqual(s.total_cost_usd, 0, "no cost");
    },
  },
];

runTests("golden-recipe-from-url-core (BUT-2239)", cases);
