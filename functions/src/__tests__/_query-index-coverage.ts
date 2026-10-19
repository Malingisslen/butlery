/**
 * Checks a query's shape against `firestore.indexes.json`, so a query that
 * would throw FAILED_PRECONDITION in production fails a unit test instead.
 *
 * `makeRecordingDb()` stands in for Firestore and records each query's path,
 * filters and orderBy, and keeps every query it ran in `gets`. `servingComposite()` says whether the declared
 * composites serve that shape: equality and array-contains fields first (in
 * any order), then the range or orderBy field, ascending unless an orderBy
 * says otherwise. A shape with no range and no orderBy on a second field is
 * served by the automatic single-field indexes and needs no composite. Only
 * collection-scope shapes with at most one orderBy are judged.
 */

import * as fs from "fs";
import * as path from "path";

export interface RecordedQuery {
  path: string[];
  group: boolean;
  filters: Array<{ field: string; op: string }>;
  orderBy: Array<{ field: string; direction: "asc" | "desc" }>;
}

interface IndexField {
  fieldPath: string;
  order?: "ASCENDING" | "DESCENDING";
  arrayConfig?: "CONTAINS";
}

interface CompositeIndex {
  collectionGroup: string;
  queryScope: "COLLECTION" | "COLLECTION_GROUP";
  fields: IndexField[];
}

const INDEXES_PATH = path.join(__dirname, "..", "..", "..", "firestore.indexes.json");

export function declaredComposites(): CompositeIndex[] {
  return JSON.parse(fs.readFileSync(INDEXES_PATH, "utf8")).indexes as CompositeIndex[];
}

export function makeRecordingDb(): Record<string, unknown> & { gets: RecordedQuery[] } {
  const gets: RecordedQuery[] = [];
  function query(rec: RecordedQuery): Record<string, unknown> {
    return {
      _rec: rec,
      where(field: string, op: string) {
        return query({ ...rec, filters: [...rec.filters, { field, op }] });
      },
      orderBy(field: string, direction: "asc" | "desc" = "asc") {
        return query({ ...rec, orderBy: [...rec.orderBy, { field, direction }] });
      },
      limit() {
        return query(rec);
      },
      doc(id: string) {
        return {
          collection(sub: string) {
            return query({ ...rec, path: [...rec.path, id, sub], filters: [], orderBy: [] });
          },
        };
      },
      get: async () => {
        gets.push(rec);
        return { docs: [], size: 0, empty: true };
      },
    };
  }
  const fresh = (name: string, group: boolean): RecordedQuery => ({
    path: [name],
    group,
    filters: [],
    orderBy: [],
  });
  return {
    gets,
    collection: (name: string) => query(fresh(name, false)),
    collectionGroup: (name: string) => query(fresh(name, true)),
  };
}

export function recorded(q: unknown): RecordedQuery {
  return (q as { _rec: RecordedQuery })._rec;
}

/** `true` when the shape needs no composite or a declared one serves it. */
export function servingComposite(
  rec: RecordedQuery,
  indexes: CompositeIndex[] = declaredComposites(),
): boolean {
  if (rec.group) {
    throw new Error("servingComposite: a collectionGroup shape needs a fieldOverrides check");
  }
  if (rec.orderBy.length > 1) return false;
  const equality = rec.filters.filter((f) => f.op === "==").map((f) => f.field);
  const contains = rec.filters
    .filter((f) => f.op === "array-contains")
    .map((f) => f.field);
  const ranges = [
    ...new Set(
      rec.filters
        .filter((f) => f.op !== "==" && f.op !== "array-contains")
        .map((f) => f.field),
    ),
  ];
  if (ranges.length > 1) return false;
  const order =
    rec.orderBy[0] ??
    (ranges.length === 1 ? { field: ranges[0], direction: "asc" as const } : undefined);
  if (order !== undefined && ranges.length === 1 && order.field !== ranges[0]) {
    return false;
  }
  const prefix = equality.length + contains.length;
  if (order === undefined || prefix === 0) return true;

  const group = rec.path[rec.path.length - 1];
  const scope = rec.group ? "COLLECTION_GROUP" : "COLLECTION";
  const want = order.direction === "desc" ? "DESCENDING" : "ASCENDING";
  return indexes.some((idx) => {
    if (idx.collectionGroup !== group || idx.queryScope !== scope) return false;
    if (idx.fields.length !== prefix + 1) return false;
    const head = idx.fields.slice(0, prefix);
    const last = idx.fields[prefix];
    return (
      equality.every((e) => head.some((f) => f.fieldPath === e && f.order !== undefined)) &&
      contains.every((c) => head.some((f) => f.fieldPath === c && f.arrayConfig === "CONTAINS")) &&
      last.fieldPath === order.field &&
      last.order === want
    );
  });
}
