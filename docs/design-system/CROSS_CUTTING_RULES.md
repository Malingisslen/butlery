# Cross-Cutting UI Rules

The single reference for the app-wide interaction conventions that every view must follow,
so screens don't drift apart. This is the design-system half of **BUT-1159**; the
machine-checkable a11y/tap-target rules and the full copy of each pattern live in
[`.claude/rules/ui-conventions.md`](../../.claude/rules/ui-conventions.md) — this file is the
human-facing summary + decision trees, and points at the canonical Dart implementations.

> **When you build or change a view, conform to every rule below.** If a screen needs a
> deliberate exception, add a one-line `// BUT-<id> exception:` comment at the call site and
> note it here.

---

## 1. Destructive-action confirmation (BUT-954) · 2. Long-press semantics (BUT-948)

These two rules are canonical in [`.claude/rules/ui-conventions.md`](../../.claude/rules/ui-conventions.md)
(auto-loaded every session, with the full class tables, exception lists, and canonical Dart
sites). Not repeated here to avoid drift — read them there. The rules below (§3–§5, hover,
top bars) are the decisions that live **only** here.

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

## Platform-adaptive top bars (BUT-706 / BUT-1362)

Use `AdaptiveAppBar` (`lib/widgets/common/adaptive_app_bar.dart`) for `Scaffold.appBar` — it
renders a native `CupertinoNavigationBar` on iOS and a Material `AppBar` everywhere else. It
supports title (nullable, auto-ellipsized) / actions / leading / centerTitle / backgroundColor /
foregroundColor / titleStyle / bottom / iconTheme / actionsIconTheme / systemOverlayStyle /
elevation. ~39 screens are migrated; new screens should use it rather than a raw `AppBar`.

**Exception — collapsing `SliverAppBar` headers stay Material.** Bars inside a `CustomScrollView`
(recipe-detail's Hero-image header, `butlery_header`, the shared-content and menu-preview headers)
keep a Material `SliverAppBar`: an image/flexibleSpace header or a custom-widget title has no
`CupertinoSliverNavigationBar` equivalent, and the simple ones' iOS large-title treatment is a
visual/UX decision (tracked in BUT-1362), not a mechanical swap. Each carries a `// BUT-706:`
comment explaining why.

## Status of the BUT-1159 children

- **BUT-954** (destructive-confirm) — rule canonical in `ui-conventions.md`; applied across the canonical sites.
- **BUT-948** (long-press) — rule + exceptions canonical in `ui-conventions.md`.
- **BUT-964** (primary-action placement) — rule documented (§3); Friends FAB completed in BUT-1357.
- **BUT-944** (icon convention) — shipped; documented (§4).
- **BUT-961** (date/time) — shipped; documented (§5).
