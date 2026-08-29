---
paths:
  - "lib/app/**"
  - "lib/views/**"
  - "lib/widgets/**"
  - "lib/viewmodels/**"
---

# Lessons Digest — Flutter app surface

Lessons that only bind while writing or running the Flutter UI layer. Counted by the same
drift tripwire as the core digest (`knowledge.digestFiles`), so these are as in-force as any
other lesson — they simply do not load in sessions that never open app code.

- `BaseViewModel.executeAsync` fails LOUD (throws `StateError`) on a disposed VM BY DESIGN — its non-nullable `Future<T>` can't return a fake `null`; the fail-silent siblings differ only because their return types allow it. Don't "harmonise" it; guard callers with `if (isDisposed) return;` (BUT-1462, sweep in BUT-1628).
- A global `Shortcuts` layer in `MaterialApp.builder` sits BELOW `DefaultTextEditingShortcuts`, so it beats the framework for a focused field — a bare Backspace→back binding stopped every text field from deleting, for months, behind a comment claiming the opposite. Bind only chords, or make the action DISABLE itself in an `EditableText` (BUT — login password field, 2026-08-07).
- A `Semantics` node's RECT isn't guaranteed to match its widget's paint bounds — `FeedbackFAB`'s node measured the full viewport, so every tap opened the feedback dialog instead (BUT-1837). `main.dart` forces semantics on every web start, so a malformed node breaks browser automation and screen-reader users identically.
- A blank white page under `flutter run -d web-server` is usually DWDS, not your code — debug mode holds `main()` until the Dart Debug Chrome extension connects, no console error. Call `window.$dartRunMain()` from the console to boot instantly instead of restarting the dev server (2026-08-13).
- Measure a fixed-size CONTAINER empty before adding to it — the recipe grid tile already overflowed by 70px at 1x and 175px at 2x, silently clipped in release, so "add a row" was not implementable until the container was fixed. A constant aspect ratio cannot hold text that scales; that is a bug class, not a tuning question (BUT-1895).
- A plan that PREDICTS a layout must vary the axis it was not worried about: the recipe grid's text block needs 244px at 2x on 360dp and 272 on 320dp, and keeps growing as the tile narrows because the badge row wraps onto another run — a step, not a curve, so no formula fits and a short prediction clips silently in release. Two refuted remedies in one ticket family means change the SHAPE of the answer (size the row to its tallest card) rather than fit a third curve. The same pass found the tile's photo already collapsing to 28px at 1x, 1px on 320dp and ZERO from 1.5x — an `Expanded` image is the slack, and slack runs out before anyone files a bug (BUT-1911).
- Measure a new badge row's WIDTH against its box before budgeting its height: a 2-column tile gives 88 logical pixels on 360dp and 68 on 320dp, while "vegansk" needs 111 and "vegetarisk" 145 at NORMAL text size. And check the stated fallback exists — icon-only was not available, because the badge takes its icon from the STATUS, so two diets render the same leaf (BUT-1906).
- A UI branch keyed on a CONJUNCTION of two state fields is a claim about every writer of both, in order: `saveFailed && canUndoRemoval` read as "a failed undo" and was also true for any other edit whose compute threw, because `_edit` sets the notice BEFORE it clears the undo arm — the retry would have restored a dish the user removed minutes earlier. Don't lengthen the condition; name the case at the one point that knows both halves (an enum value set where the answer is known), and remember the missing test was cross-group — a MOVE failing inside an UNDO's test group (BUT-1971, 2026-08-29).
