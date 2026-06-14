# Sprint Backlog

## Sprint: tagging — area drained, no buildable tickets — 2026-06-14 (iter-153)

Focus = `tagging` area label. **Warning: the tagging area is fully drained.** Of all 107 open Backlog tickets, exactly ONE carries the `tagging` label — **BUT-907** — and every other tagging-labeled ticket (BUT-480/929/994/998/1012/1042/1055/1170/1172/1185/1186/1188) is already **Done** and shipped. The tag subsystem's bulk ops (delete/merge/rename), the >500-recipe batch chunking, the watchTags() get+invalidation migration, the stale-subscription rebind fix, and the merge-loop VM extraction all landed across iters 15→ recent.

BUT-907 is the only tagging-labeled open ticket, and it is NOT a tagging task — `tagging` is one of five area labels on it (shopping/menu/tagging/recipe/idea) because deleting a tag is one of several things a future trash bin could hold. It is a Low-priority, "defer until beta", speculative **new** persistent Trash & Recovery subsystem (new `trash/{userId}/...` Firestore schema + a new Settings → Trash view + a TTL-sweeper Cloud Function). That is a product decision Malin's own ticket parks for later — not a bug or an obvious-benefit cleanup. Per the mandate gate it goes to **needsApproval**, not a batch. I am NOT manufacturing build work to fill N.

**No batches this iteration.** Nothing in the tagging focus is safe to auto-build or auto-close.

### Needs you (not built — flagged for your call)
- **BUT-907** (Low, idea) — EPIC: persistent Trash & Recovery view beyond the 7-second snackbar undo. Builds a brand-new soft-delete subsystem (`trash/{userId}/{collection}/{id}` with 30-day TTL), a Trash view under Settings, per-item restore / permanent-delete, and a Cloud Function TTL sweeper. Your own ticket marks it "Low — defer until beta; snackbars cover urgent recovery, trash view is comfort." Recommendation: **leave deferred** — it's a sizeable new feature with new data schema + a Cloud Function, the panic-window recovery (snackbar undo) is already shipped on every destructive surface, and it's explicitly a post-beta power-user comfort. Reframe as a real epic with sub-tickets when you decide trash-bin recovery is worth the schema + ops cost; don't let the loop build it speculatively.

### Obsolete (done in git, still open in Linear)
- None in the tagging focus. All tagging tickets that git shows shipped are already correctly marked Done in Linear.

### Note for the loop
If you want the loop to keep producing tagging-area work, the well is dry — the next `/sprint-execute` should either drop `--focus tagging` (the live volume is in `backend`, `recipe`, `social`, `import`, `menu`, `tech-debt`) or you should groom BUT-907 into concrete child tickets first.

### Post-Sprint Steps
- [ ] No implementation — nothing selected. No analyze/test/commit needed for code.
- [ ] No Linear transitions — no ticket moved to Todo (nothing buildable selected).

---
## ARCHIVED — iter-152 (menu: BUT-1278 unit-merge aggregation Tier A, BUT-1279 staple-exclusion + BUT-1043 weekly-menu copy/bulk-move + BUT-930 onboarding sample-menu seed Tier B — all shipped, commit 1711d297c; BUT-1179 flagged Needs-you) · iter-151 (import flow: BUT-1040/931 text-import, BUT-947 multi-URL, BUT-903 multi-photo, BUT-1205 re-extract — all shipped, commits 673f80c87 + 10325a5bb; BUT-653/656/684/941 flagged needsApproval) · iter-150 (social conflict-cleanup + activity/sharing UI: BUT-1267/1266 Tier A, BUT-1220/1000/949 Tier B; BUT-1265 obsolete-closed) · iter-149 (BUT-1265 conflictStream end-to-end delivery test — landed `f37c9af03`) · iter-148 (BUT-1263/1264 recoverLocalVersion test-gaps — HEAD d4ee51b0f) · iter-147 (BUT-1262 realtime data-loss-path sign-off) · iter-146 (BUT-1053/1247/1250) · iter-145 (BUT-1251/1246/1249 Done) · iter-144 (BUT-648/1057 In Review) · iter-143 (BUT-1245/626 Done) · äldre i git-historiken
