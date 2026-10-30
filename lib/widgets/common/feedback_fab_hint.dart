import 'package:flutter/rendering.dart';
import 'package:shared_preferences/shared_preferences.dart';

const String feedbackFabHintShownKey = 'feedback_fab_hint_shown';

/// Whether any text or icon of [page] lies under a 3x3 sample grid of
/// [fabRect] (global coordinates). The "!" hint is only worth a person's
/// attention when the button really hides something, and a hit test is the
/// one check that sees what the page paints without every screen reporting
/// itself. Icons paint through paragraphs too, so ⋮ and arrows count.
bool feedbackFabCoversContent(RenderBox page, Rect fabRect) {
  for (final fx in const [0.2, 0.5, 0.8]) {
    for (final fy in const [0.2, 0.5, 0.8]) {
      final global = Offset(
        fabRect.left + fabRect.width * fx,
        fabRect.top + fabRect.height * fy,
      );
      final result = BoxHitTestResult();
      page.hitTest(result, position: page.globalToLocal(global));
      if (result.path.any((entry) => entry.target is RenderParagraph)) {
        return true;
      }
    }
  }
  return false;
}

Future<bool> feedbackFabHintShown() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(feedbackFabHintShownKey) ?? false;
  } catch (_) {
    // Without storage the hint could repeat every launch, so stay quiet.
    return true;
  }
}

Future<void> markFeedbackFabHintShown() async {
  try {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(feedbackFabHintShownKey, true);
  } catch (_) {
    // Best-effort; see feedbackFabHintShown.
  }
}
