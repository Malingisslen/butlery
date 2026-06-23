# Cross-Cutting UI Rules

The single reference for the app-wide interaction conventions that every view must follow,
so screens don't drift apart. This is the design-system half of **BUT-1159**; the
machine-checkable a11y/tap-target rules and the full copy of each pattern live in
[`.claude/rules/ui-conventions.md`](../../.claude/rules/ui-conventions.md) — this file is the
human-facing summary + decision trees, and points at the canonical Dart implementations.

> **When you build or change a view, conform to all five rules below.** If a screen needs a
> deliberate exception, add a one-line `// BUT-<id> exception:` comment at the call site and
> note it here.

---

## 1. Destructive-action confirmation (BUT-954)

Pick the friction pattern by **recoverability**, not by how scary the verb sounds.

| Class | When | Pattern |
| --- | --- | --- |
| **Reversible-destructive** | item is trivially recreatable/restorable (pantry row, image attachment, own comment) | delete immediately + "Ångra" snackbar (7s, `SnackBarUtils.showSuccessWithAction` + restore path). **No confirm dialog.** |
| **Hard-destructive** | user-authored content gone after the undo window (recipe delete, bulk delete, personal-tag delete) | confirm dialog **and**, where a restore path exists, a 5–7s snackbar undo |
| **Light action** | reversible state flip with an obvious inverse (claim/release shopping item, mark step done, favourite) | **no friction at all** — never a dialog or undo |

Canonical: `mina_recept/recipe_card_widget.dart` + `recipe_delete_manager.dart` (hard),
`pantry/pantry_item_card.dart` (reversible), `collaborative_shopping_items.dart` claim flow
(light). If undo is impossible for a hard-destructive action, say so in the dialog body
("Detta går inte att ångra").

---

## 2. Long-press semantics (BUT-948)

On **list-selection surfaces**, long-press enters multi-select (long-press → `enterSelection`,
then a bulk-action bar replaces the FAB). Canonical: `pantry/pantry_item_card.dart`,
`unified_shopping/widgets/shopping_item_tiles.dart`, `personal_tags/personal_tag_widgets.dart`,
`social/group_detail/group_member_card.dart`.

**Documented exceptions** (long-press is a contextual menu or feature affordance, NOT
multi-select — each carries a `// BUT-948 exception:` comment):
- **Conversations list** / **chat messages** — opens the message/conversation action menu.
- **Cooking mode** — long-press an ingredient opens substitutions; an instruction step opens
  the step timer.

Rule for new long-presses: selectable list → multi-select; otherwise add a `// BUT-948
exception:` comment explaining the contextual/feature intent. A user must never get a
different long-press meaning without a documented reason.

---

## 3. Primary-action placement (BUT-964 / BUT-1357)

The **primary create-action for the current list is a square FAB**; the app-bar overflow is
for secondary actions. FABs are square app-wide (theme-enforced, BUT-964).

Decision tree:
- A screen showing a **list you can add to** → square FAB as the create-action (e.g. Friends
  tab "Lägg till vän", Groups tab "Skapa grupp").
- A **detail screen** (not a list) → keep the primary action in the app-bar (documented
  exception, e.g. `tag_detail_view.dart`).
- **Recipe-add** intentionally lives in the bottom-nav "Lägg till" tab (owner decision) — keep.

---

## 4. Favourite / featured / saved icon convention (BUT-944)

One icon per *concept* — use the semantic aliases in
`lib/widgets/common/icons/adaptive_icon.dart` at call sites, not raw `Icons.*`:
- **Heart** (`AdaptiveIcons.favouriteFilled` / `favouriteOutline`) → personal preference
  (favourite, like; the `isFavorite` boolean on Recipe).
- **Star** (`primaryFilled` / `primaryOutline`) → system designation (primary image, featured).
- **Bookmark** (`savedTemplate` / `savedTemplateOutline`) → template / saved-for-later.

Colour (BUT-1213): active personal favourite → `colorScheme.primary` (green); active social
like → `colorScheme.error` (red); inactive → `onSurfaceVariant`. **Exception:** recipe-detail
hero buttons render every icon green by design, so the heart there doesn't signal state.

---

## 5. Date/time formatting (BUT-961)

Three intentional styles via `ContextualTimeFormatter`
(`lib/core/utils/contextual_time_formatter.dart`) — never ad-hoc `DateTime.toString()`:
- **compact** ("5min", "2d") — tight surfaces (list rows, notifications, cook-snap badges).
- **standard** ("2 days ago", "Now") — body text (comments, friend requests, shared cards).
- **dateTime** ("May 22, 2026 3:45 PM") — permanent records (group creation, admin reports).

All three auto-promote to an absolute date (`yMMMd`) once content ages past 7 days. New code
reaches for this helper; existing `TimeAgoFormatter` / `DateFormat` call sites migrate as touched.

---

## Web/desktop hover (BUT-710 / BUT-1358)

Custom interactive cards that paint their own decoration (so `InkWell`'s hover is suppressed)
use `HoverableCard` to gain a subtle pointer-hover lift + click cursor on web/desktop, with
`enabled:` reflecting real interactivity. Reduced-motion is respected. Canonical:
`recipe_card.dart`, `menu_card.dart`, `message_bubble.dart`, `friend_card.dart`,
`shopping_list_card.dart`.

---

## Status of the BUT-1159 children

- **BUT-954** (destructive-confirm) — rule documented (§1), applied across the canonical sites.
- **BUT-948** (long-press) — rule + exceptions documented (§2).
- **BUT-964** (primary-action placement) — rule documented (§3); Friends FAB completed in BUT-1357.
- **BUT-944** (icon convention) — shipped; documented (§4).
- **BUT-961** (date/time) — shipped; documented (§5).
