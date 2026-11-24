/**
 * BUT-2490: the server's copy of a recurring-day rule row ("fast dag") and the
 * check a GROUP's rule list passes before `setGroupRecurringDayRules` stores it.
 *
 * This check mirrors `RecurringDayRule` and `RecurringDayRules` in
 * `lib/models/menu/recurring_day_rule.dart`;
 * `test/unit/security/group_recurring_day_rules_drift_test.dart` reads this
 * file and fails when the two disagree.
 *
 * A bad row rejects the whole list rather than being dropped: the app builds
 * canonical rows, so a bad one comes from a hand-rolled client.
 */

/** Seven days times lunch and middag. */
export const MAX_RECURRING_DAY_RULES = 14;

export const RECURRING_RULE_KEYS = [
  "id",
  "weekday",
  "meal",
  "kind",
  "value",
  "quick",
  "paused",
] as const;

export const RECURRING_RULE_MEALS = ["lunch", "middag"] as const;

export const RECURRING_RULE_KINDS = [
  "tag",
  "proteinCategory",
  "dietary",
  "quick",
] as const;

/** Every food a non-quick rule may name, with the kind it is matched by. */
export const RECURRING_FOODS = [
  { kind: "proteinCategory", value: "fish" },
  { kind: "tag", value: "taco" },
  { kind: "dietary", value: "vegetarisk" },
  { kind: "tag", value: "pasta-dish" },
  { kind: "tag", value: "soppa" },
  { kind: "proteinCategory", value: "poultry" },
] as const;

export interface RecurringDayRuleRow {
  id: string;
  weekday: number;
  meal: string;
  kind: string;
  value: string;
  quick: boolean;
  paused: boolean;
}

export type RecurringDayRulesCheck =
  | { ok: true; rows: RecurringDayRuleRow[] }
  | { ok: false; problem: string };

function isPlainObject(value: unknown): value is Record<string, unknown> {
  if (value === null || typeof value !== "object" || Array.isArray(value)) {
    return false;
  }
  const proto = Object.getPrototypeOf(value);
  return proto === Object.prototype || proto === null;
}

function includes(list: readonly string[], value: unknown): value is string {
  return typeof value === "string" && list.includes(value);
}

/** An absent flag is false; anything but a boolean is refused. */
function flag(row: Record<string, unknown>, key: string): boolean | null {
  const value = row[key];
  if (value === undefined) return false;
  return typeof value === "boolean" ? value : null;
}

function checkRow(
  raw: unknown,
  index: number,
): { row: RecurringDayRuleRow } | { problem: string } {
  const at = `row ${index}`;
  if (!isPlainObject(raw)) return { problem: `${at}: not an object` };
  for (const key of Object.keys(raw)) {
    if (!includes(RECURRING_RULE_KEYS, key)) {
      return { problem: `${at}: unknown key` };
    }
  }
  const weekday = raw.weekday;
  if (
    typeof weekday !== "number" ||
    !Number.isInteger(weekday) ||
    weekday < 1 ||
    weekday > 7
  ) {
    return { problem: `${at}: weekday` };
  }
  const meal = raw.meal;
  if (!includes(RECURRING_RULE_MEALS, meal)) return { problem: `${at}: meal` };
  const kind = raw.kind;
  if (!includes(RECURRING_RULE_KINDS, kind)) return { problem: `${at}: kind` };
  const quick = flag(raw, "quick");
  const paused = flag(raw, "paused");
  if (quick === null || paused === null) return { problem: `${at}: flag` };
  const value = raw.value === undefined ? "" : raw.value;
  if (typeof value !== "string") return { problem: `${at}: value` };
  if (kind === "quick") {
    if (value !== "" || !quick) return { problem: `${at}: quick rule` };
  } else if (!RECURRING_FOODS.some((f) => f.kind === kind && f.value === value)) {
    return { problem: `${at}: value` };
  }
  const id = `${weekday}-${meal}`;
  if (raw.id !== id) return { problem: `${at}: id` };
  return { row: { id, weekday, meal, kind, value, quick, paused } };
}

/**
 * Checks [input] and returns the rows REBUILT from the checked fields, so what
 * is stored never carries the caller's bytes beyond the values listed above.
 */
export function checkRecurringDayRules(input: unknown): RecurringDayRulesCheck {
  if (!Array.isArray(input)) return { ok: false, problem: "not a list" };
  if (input.length > MAX_RECURRING_DAY_RULES) {
    return { ok: false, problem: "too many rules" };
  }
  const rows: RecurringDayRuleRow[] = [];
  const seen = new Set<string>();
  for (let i = 0; i < input.length; i++) {
    const result = checkRow(input[i], i);
    if ("problem" in result) return { ok: false, problem: result.problem };
    if (seen.has(result.row.id)) {
      return { ok: false, problem: `row ${i}: duplicate id` };
    }
    seen.add(result.row.id);
    rows.push(result.row);
  }
  return { ok: true, rows };
}
