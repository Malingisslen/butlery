/// Reading `firestore.rules` as text, for the guards under this directory.
///
/// Two of them now parse the same file, and the comment strip below is the
/// half that is load-bearing rather than tidy: every assertion either guard
/// makes matches happily inside a comment, so commenting a constraint out is
/// SELF-COMPENSATING — counts do not move, anchors still resolve, extractors
/// pull the commented text. A second hand-typed copy of that strip is the
/// exact failure class this whole test family exists to fight, which is why it
/// lives here instead of in each caller.
library;

/// Removes block and line comments so no assertion can be satisfied by prose.
///
/// The `[^:]` guard on the line-comment pattern keeps a `://` inside a URL from
/// being eaten. `firestore.rules` currently contains no URL, so it is belt and
/// braces — and cheaper than discovering the exception later.
String withoutCStyleComments(String source) => source
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAllMapped(
      RegExp(r'(^|[^:])//.*$', multiLine: true),
      (m) => m.group(1)!,
    );

/// The slice of [rules] from [anchor] up to the next `match `, or null when the
/// anchor is gone.
///
/// Bounded at the next `match ` so a caller cannot borrow a neighbouring
/// block's text and report health that belongs to a different rule. A null
/// return is a fact the caller must assert on: an anchor that stopped resolving
/// is a rule that was renamed or removed, never a pass.
String? rulesBlock(String rules, String anchor) {
  final at = rules.indexOf(anchor);
  if (at == -1) return null;
  final next = rules.indexOf('match ', at + anchor.length);
  return rules.substring(at, next == -1 ? rules.length : next);
}
