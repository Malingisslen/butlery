/**
 * BUT-2414: the files under the requester's Storage folder, which the cascade
 * step `storage_files` deletes with `deleteFiles({ prefix })` (Malin
 * 2026-10-20: "Lista filerna").
 *
 * Each row is built field by field: the path inside the folder, size, type and
 * two dates. Nothing from the object's custom metadata (where a download token
 * lives), no URL and no file contents. The listing pages with
 * `autoPaginate: false` and asks only for what is left of cap + 1, so a folder
 * over the cap declines without being listed whole.
 */

import { userStoragePrefix } from "../../account/account-deletion-cascade";
import { MAX_SECTION_ROWS, SectionDef } from "./account-sections";
import { Decline, Row, sortRows } from "./project";

export const STORAGE_SECTIONS: readonly SectionDef[] = [
  {
    name: "storage_files",
    read: async (_database, uid, bucket) => {
      const prefix = userStoragePrefix(uid);
      const rows: Row[] = [];
      // Placeholders are skipped, so they get a bound of their own.
      let scanned = 0;
      let pageToken: string | undefined;
      do {
        const [files, next] = await bucket().getFiles({
          prefix,
          autoPaginate: false,
          maxResults: MAX_SECTION_ROWS + 1 - rows.length,
          pageToken,
        });
        scanned += files.length;
        for (const file of files) {
          // A folder placeholder, not a file.
          if (file.name.endsWith("/")) continue;
          rows.push({
            path: file.name.slice(prefix.length),
            size: file.metadata.size === undefined ? null : Number(file.metadata.size),
            contentType: file.metadata.contentType ?? null,
            timeCreated: file.metadata.timeCreated ?? null,
            updated: file.metadata.updated ?? null,
          });
        }
        if (rows.length > MAX_SECTION_ROWS) {
          throw new Decline("storage_files", rows.length);
        }
        if (scanned > 2 * MAX_SECTION_ROWS) {
          throw new Decline("storage_files_scanned", scanned);
        }
        pageToken = next?.pageToken;
      } while (pageToken);
      return sortRows(rows, "path");
    },
  },
];
