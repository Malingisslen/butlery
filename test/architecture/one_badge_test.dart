// Komponentark v1 has two badges, the status pill (§08) and the counter
// (v1:741), and UnifiedBadge draws both (BUT-2373). A class under lib/ named
// like a badge or a pill builds a UnifiedBadge instead of drawing its own
// box. The classes below still draw their own: each is pinned with the
// reason it has not moved, so a new hand-drawn badge reddens, and so does a
// move that forgets to shrink the list.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _notYetMoved = <String>{
  // Genomgångens spår D1 owns the admin views.
  'lib/views/admin/feedback_inbox_view.dart _StatusPill',
  'lib/views/admin/moderator_review_view.dart _StatusPill',
  // Genomgångens spår B owns the rating entry view.
  'lib/views/family/family_rating_entry_view.dart _YouBadge',
  // An avatar of initials, not a badge.
  'lib/views/social/collaborative_shopping/collaborative_shopping_items.dart _AssigneeBadge',
  // A neutral info chip with no border, decided in B83-2.
  'lib/widgets/common/indicators/admin_badge.dart AdminBadge',
  // Material's Badge on a navigation glyph.
  'lib/widgets/common/navigation/butlery_bottom_navigation.dart NavBadgedIcon',
  // Marks over a photo, on its own overlay plate.
  'lib/widgets/image/components/primary_badge.dart PrimaryBadge',
  'lib/widgets/recipe/cook_snap_gallery.dart _PhotoCountBadge',
  'lib/widgets/recipe/cook_snap_photo_carousel.dart _CounterBadge',
  // The import platform with its brand glyph.
  'lib/widgets/import/platform_badge_widget.dart PlatformBadgeWidget',
  // The saffron "NY" in a calendar cell, drawn for the cell (B-41).
  'lib/widgets/menu/menu_new_badge.dart MenuNewBadge',
  // The rating pill, an accepted mockup departure.
  'lib/widgets/recipe/butlery_betyg_pill.dart ButleryBetygPill',
  // Allergen and diet verdicts; their tone and wording are safety copy.
  'lib/widgets/tagging/allergen_status_badge.dart AllergenStatusBadge',
  'lib/widgets/tagging/dietary_status_badge.dart DietaryStatusBadge',
  'lib/widgets/tagging/tag_status_badge.dart TagStatusBadge',
  'lib/widgets/tagging/tag_status_badge.dart TagStatusBadgeCompact',
};

/// Strips comments so a sentence that names a class is not counted.
String _code(String path) => File(path)
    .readAsStringSync()
    .replaceAll('\r\n', '\n')
    .replaceAll(RegExp(r'/\*[\s\S]*?\*/'), '')
    .replaceAll(RegExp(r'//[^\n]*'), '');

final _badgeClass = RegExp(
  r'^class (_?\w*(?:Badge|Pill)\w*) extends (\w+)',
  multiLine: true,
);

Set<String> _ownBadges() {
  final found = <String>{};
  for (final file in Directory('lib').listSync(recursive: true)) {
    if (file is! File || !file.path.endsWith('.dart')) continue;
    final path = file.path.replaceAll(r'\', '/');
    if (path.startsWith('lib/widgets/common/badges/')) continue;
    final code = _code(path);
    final classes = _badgeClass.allMatches(code).toList();
    for (final m in classes) {
      if (m.group(2) == 'State') continue;
      final next = RegExp(r'^class ', multiLine: true)
          .allMatches(code, m.end)
          .firstOrNull;
      final body = code.substring(m.end, next?.start ?? code.length);
      if (!body.contains('UnifiedBadge.')) found.add('$path ${m.group(1)}');
    }
  }
  return found;
}

void main() {
  test('every badge in lib/ is a UnifiedBadge', () {
    expect(_ownBadges(), _notYetMoved);
  });
}
