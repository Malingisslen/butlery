/**
 * Bug-36: client-supplied domain must be validated before it becomes a
 * site_configs document ID.
 *
 * What this proves: validateDomain accepts only real lowercase hostnames and
 * rejects the malformed / injection-shaped values a client could send to
 * auto-create config docs (empty, path-like with "/", whitespace, single
 * label without a TLD, oversized). www. is stripped and case is normalized.
 *
 * Run with: npx ts-node src/__tests__/log-parse-event-domain.test.ts
 */

import { validateDomain } from "../events/log-parse-event";
import { assertEqual, runTests, UnitCase } from "./_unit-runner";

const cases: UnitCase[] = [
  {
    name: "accepts a normal hostname",
    fn: async () => {
      assertEqual(validateDomain("ica.se"), "ica.se", "ica.se");
    },
  },
  {
    name: "strips www. and lowercases",
    fn: async () => {
      assertEqual(
        validateDomain("WWW.Koket.SE"),
        "koket.se",
        "www + case normalization"
      );
    },
  },
  {
    name: "accepts multi-label subdomains",
    fn: async () => {
      assertEqual(
        validateDomain("recept.api.example.com"),
        "recept.api.example.com",
        "subdomain"
      );
    },
  },
  {
    name: "rejects empty string",
    fn: async () => {
      assertEqual(validateDomain(""), null, "empty");
    },
  },
  {
    name: "rejects non-string",
    fn: async () => {
      assertEqual(validateDomain(42), null, "number");
      assertEqual(validateDomain(null), null, "null");
      assertEqual(validateDomain(undefined), null, "undefined");
    },
  },
  {
    name: "rejects path-like value containing a slash (cannot be a Firestore doc id)",
    fn: async () => {
      assertEqual(validateDomain("evil.com/../etc"), null, "slash injection");
      assertEqual(validateDomain("a/b"), null, "bare slash");
    },
  },
  {
    name: "rejects whitespace and control-ish junk",
    fn: async () => {
      assertEqual(validateDomain("foo bar.com"), null, "space");
      assertEqual(validateDomain("   "), null, "blank");
    },
  },
  {
    name: "rejects single label without a TLD",
    fn: async () => {
      assertEqual(validateDomain("localhost"), null, "no dot");
    },
  },
  {
    name: "rejects leading/trailing dots and double dots",
    fn: async () => {
      assertEqual(validateDomain(".com"), null, "leading dot");
      assertEqual(validateDomain("ica.se."), null, "trailing dot");
      assertEqual(validateDomain("ica..se"), null, "double dot");
    },
  },
  {
    name: "rejects oversized input",
    fn: async () => {
      const huge = "a".repeat(260) + ".com";
      assertEqual(validateDomain(huge), null, "over 253 chars");
    },
  },
];

runTests("Bug-36: validateDomain hostname validation", cases);
