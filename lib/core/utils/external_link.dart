/// Whether a stored string may be presented, and opened, as an external link.
///
/// BUT-1819. Butlery's `sourceUrl` is a PROVENANCE field, not a URL field: a
/// dozen writers put a sentence in it (`'Butlerys receptsamling'` on the seeds,
/// `'Från Butlerys arkiv'` on an archive import, and a localized sentence on
/// realtime shares. `recipeCopiedFrom(title)` belongs on this list by design
/// but has no LIVE producer: its only writer is
/// `RecipeFactory.createPersonalCopy`, which nothing calls today). The recipe detail view
/// nonetheless wrapped every non-empty value in `Semantics(link: true)` and a
/// tap target, so a value that can never open rendered as a dead link — and a
/// hostile `javascript:` value rendered as a live one.
///
/// So this predicate governs RENDERING first and launching second. A caller that
/// only guards the launch still draws a link that refuses to work; a caller that
/// guards the draw never offers the tap at all.
///
/// ## Why another scheme check
///
/// Several already exist, and one of them IS reachable from a widget (through
/// `recipeSourceUrl()`, never directly) and IS stricter than this:
/// `FormValidators.url()` requires a non-empty host with a dot in it. Its sibling `recipeSourceUrl()` is NOT stricter — it returns
/// "valid" for any value containing the word `Butlery`, so the seed string
/// `'Butlerys receptsamling'` passes it and is refused here. Two drafts of this
/// comment got this wrong in opposite directions; both were caught by a
/// reviewer opening `form_validators.dart`.
///
/// What is actually new is the pairing: a predicate whose answer decides whether
/// a value is DRAWN as a link, colocated with the launcher that enforces the
/// same answer. The validators return a localized error string for a form field,
/// which is not a shape a build method should branch on.
library;

import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

/// `http`/`https` with a non-empty host, and nothing else.
///
/// The two checks catch different things, and it is worth being exact about
/// which, because a first draft of this comment credited the wrong one (run and
/// verified 2026-08-10):
///
/// - The SCHEME check stops the provenance sentences. `'Butlery recipe
///   collection'` parses to an empty scheme AND an empty host, so it dies on
///   the scheme line and never reaches the host line.
/// - The HOST check stops `'https:'` and `'http://'` — both parse with a real
///   http/https scheme and an empty host, so a scheme-only predicate would wave
///   them through.
/// - `Uri.tryParse` returning null stops a colon whose prefix is not a legal
///   scheme, as in `'Kopierat från: Pannkakor'` (spaces before the colon). A
///   colon is not itself decisive: `'Recept: 4 portioner'` parses with
///   `scheme == 'recept'` and dies on the scheme line instead. Both reach
///   false; only the line differs.
///
/// All three land on false, by three different lines.
bool isSafeExternalUrl(String? value) {
  if (value == null || value.isEmpty) return false;
  final uri = Uri.tryParse(value);
  if (uri == null) return false;
  if (uri.scheme != 'http' && uri.scheme != 'https') return false;
  return uri.host.isNotEmpty;
}

/// Opens [uri] only when [isSafeExternalUrl] accepts it.
///
/// Returns false, without launching, when the scheme is not http/https or when
/// the launch itself fails — so a caller can show its own message. Belt and
/// braces behind the render guard: a call site that has not adopted the guard
/// still cannot open `javascript:`.
///
/// **No `canLaunchUrl` pre-check, deliberately.** An earlier version had one,
/// inherited from the code this replaced rather than chosen. `launchUrl`
/// already reports failure, so the pre-check adds no information — and it can
/// subtract: the plugin's own doc says `canLaunchUrl` "will always return false
/// unless the application has been configured to allow querying the system",
/// which is a PERMISSION answer wearing a capability name. Android declares the
/// `<queries>` entries; **`ios/Runner/Info.plist` declares no
/// `LSApplicationQueriesSchemes`**, and iOS is a live build target. The failure
/// is one-directional — a working link that silently does nothing — and
/// `LinkifiedText` does not even read this bool, so a user would experience
/// "tapping does nothing" with nothing to report.
///
/// A `PlatformException` is folded into `false` here rather than thrown, so
/// callers keep ONE meaning for a failed open: the OS would not take it.
Future<bool> openExternalLink(Uri uri) async {
  if (!isSafeExternalUrl(uri.toString())) return false;
  try {
    return await launchUrl(uri, mode: LaunchMode.externalApplication);
  } on PlatformException {
    return false;
  }
}
