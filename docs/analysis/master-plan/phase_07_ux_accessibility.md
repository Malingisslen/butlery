# Phase 7: UX, Accessibility & Polish (~5 days)

Color contrast, semantics, Colors.* cleanup, i18n completion, platform compliance.

---

## P7-01 — Add Semantics to interactive elements [CRIT]

**Source**: R06:2.1
**Files**: `lib/widgets/` (many files)
**Fix**: Many `InkWell`/`GestureDetector` widgets lack screen reader labels. Only ~56 `Semantics` in code vs hundreds of interactive elements. Prioritize navigation and primary actions.
**Effort**: 3-5d

---

## P7-02 — Fix color contrast failures [HIGH]

**Source**: R06:2.2
**Files**: `lib/theme/app_colors.dart:67,23,39`
**Fix**: `textLight` (#999999) on `cream` (#F8F4E8) = 2.6:1 (FAIL). `forestGreen` (#4A7C59) on `cream` = 4.3:1 (FAIL for normal text). Darken textLight to ~#767676. Adjust forestGreen on cream to large text only.
**Effort**: 1d

---

## P7-03 — Add heading semantics [HIGH]

**Source**: R06:2.3
**Fix**: No `Semantics(header: true)` or heading-level annotations anywhere. Screen reader navigation by headings impossible.
**Effort**: 2d

---

## P7-04 — Form field Semantics labels [HIGH]

**Source**: R06:2.4
**Files**: `lib/widgets/common/input/`, `lib/widgets/tagging/`
**Fix**: Custom widgets and tag filters have no explicit accessibility labels.
**Effort**: 2d

---

## P7-05 — Replace remaining 361 `Colors.*` references [HIGH]

**Source**: R06:1.1
**Files**: 158 in 36 view files, 203 in 75 widget files (down from 1,879)
**Fix**: Replace with theme tokens. ~27 are `Colors.transparent` (benign). Dark mode broken for these elements.
**Effort**: 2-3d

---

## P7-06 — Externalize final ~21 hardcoded strings [MED]

**Source**: R06:4.1
**Files**: `animated_pressable.dart`, `debounced_button.dart`, `responsive_grid.dart`, `comment_debug_panel.dart`, `group_dialogs.dart`, ~5 more
**Fix**: Move to ARB files.
**Effort**: 4h

---

## P7-07 — RTL readiness cleanup [MED]

**Source**: R06:4.2
**Fix**: 104 `EdgeInsets.only` (58 files) vs 35 `EdgeInsetsDirectional` (22 files). Replace `EdgeInsets.only(left/right)` with `EdgeInsetsDirectional`. Fix 9 `Alignment.centerLeft/Right` and 2 `TextAlign.left/right`.
**Effort**: 2d

---

## P7-08 — Reconcile ARB key count mismatch [MED]

**Source**: R06:4.3
**Files**: `lib/l10n/app_sv.arb` (5,449 keys), `app_en.arb` (5,937 keys)
**Fix**: Identify and resolve 488 key difference.
**Effort**: 1d

---

## P7-09 — ~15 error messages leak raw exception text [HIGH]

**Source**: R01:H4.3
**Files**: `lib/l10n/app_sv.arb:408,434,466,1448` plus ~10 more
**Fix**: Map `{error}` parameters to user-friendly categories instead of raw exception text.
**Effort**: 3h

---

## P7-10 — ~15 silent catch-and-return-null patterns [HIGH]

**Source**: R01:H4.1
**Files**: `import_manager.dart:58-77`, `url_import_strategy.dart:42-69`, `content_detector_service.dart:361`, `arla_recipe_parser.dart:68`, `ica_recipe_parser.dart:86`, `youtube_transcript_service.dart` (5 blocks)
**Fix**: Return Result type or throw typed exceptions instead of silently returning null.
**Effort**: 4h

---

## P7-11 — Translate ~40 Swedish code comments to English [MED]

**Source**: R01:M5.3
**Files**: `recipe_list_viewmodel.dart:496-534`, `form_fields_manager.dart:152,328,333`, `user_service.dart:324,329`, `collaborative_status_viewmodel.dart:90,317,391`, ~25 more
**Fix**: Translate to English per CLAUDE.md rule.
**Effort**: 2h

---

## P7-12 — Remove 4 section dividers [LOW]

**Source**: R01:M5.4
**Files**: `parsing_correction.dart:31,45,62`, `ingredient_data.dart:78`
**Fix**: Remove `// === Section ===` style dividers.
**Effort**: 15 min

---

## P7-13 — Remove ~35 lines of commented-out code [LOW]

**Source**: R01:L5.1
**Files**: `deep_link_service.dart:322-335` (14 lines), 6 other files
**Effort**: 30 min

---

## P7-14 — TextFormField widgets without validators [MED]

**Source**: R01:M4.1
**Files**: `assisted_import_dialog.dart:239-298` (4 fields), `edit_group_dialog.dart:164`
**Fix**: Add validators using ValidationUtils.
**Effort**: 2h

---

## P7-15 — `double.parse()`/`int.parse()` without try-catch [MED]

**Source**: R01:M4.2
**Files**: `shopping_item_dialog.dart:324`, `json_serializable_mixin.dart:283,299`, `personal_tag_color_picker.dart:44`
**Fix**: Replace with `tryParse` or wrap in try-catch.
**Effort**: 1h

---

## P7-16 — macOS Release entitlements minimal [MED]

**Source**: R06:5.3
**Files**: `macos/Runner/Release.entitlements`
**Fix**: Add network.client (needed for Firebase), camera, photos entitlements.
**Effort**: 2h

---

## P7-17 — Focus traversal configuration [MED]

**Source**: R06:2.5
**Fix**: No `FocusTraversalGroup`, `FocusOrder`, or custom `FocusTraversalPolicy`. Keyboard/switch users may encounter illogical tab order.
**Effort**: 2d

---

## P7-18 — Version still at 1.0.0+1 [LOW]

**Source**: R01:M7.3
**Files**: `pubspec.yaml:4`
**Fix**: Establish semantic versioning scheme before release.
**Effort**: 30 min

---

## P7-19 — Capitalize app name in manifests [LOW]

**Source**: R06:6.6
**Files**: AndroidManifest.xml, Info.plist
**Fix**: "butlery" → "Butlery" for store display.
**Effort**: 5 min

---

## P7-20 — iOS permission descriptions may be Swedish-only [LOW]

**Source**: R06:4.5
**Files**: `ios/Runner/Info.plist`
**Fix**: Localize permission descriptions for non-Swedish users.
**Effort**: 30 min per locale

---

## P7-21 — Notification error response leaks internal details [LOW]

**Source**: R02:F-09
**Files**: `functions/src/notifications/send-notification.ts:265-268`
**Fix**: Sanitize error response.
**Effort**: 30 min

---

## P7-22 — `.then()` without `.catchError()` [LOW]

**Source**: R01:L4.1
**Files**: `feature_flag_service.dart:177`, `recipe_parser_service.dart:431`
**Effort**: 15 min

---

## P7-23 — Python site-packages in lib/ [LOW]

**Source**: R02:C-16
**Files**: `lib/site-packages/`
**Fix**: Move out of lib/ directory.
**Effort**: 5 min

---

## P7-24 — Dark mode comment inconsistency [LOW]

**Source**: R06:1.3
**Files**: `lib/theme/app_colors.dart`
**Fix**: Dark mode described as "not in scope" but ColorScheme.fromSeed dark mode exists. Clarify in comments.
**Effort**: 15 min
