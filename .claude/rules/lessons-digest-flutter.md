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
