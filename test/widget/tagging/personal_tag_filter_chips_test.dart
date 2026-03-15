import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/widgets/common/search_filter/personal_tag_filter_chips.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

PersonalTag _tag(String id, String name) {
  final now = DateTime(2026, 1, 1);
  return PersonalTag(id: id, name: name, createdAt: now, updatedAt: now);
}

void main() {
  final testTags = [
    _tag('tag-1', 'Favoriter'),
    _tag('tag-2', 'Snabblagat'),
    _tag('tag-3', 'Helg'),
  ];

  group('PersonalTagFilterChipsWidget', () {
    testWidgets('renders include chips for all provided tags', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: PersonalTagFilterChipsWidget(
            tags: testTags,
            selectedTagIds: const {},
            onToggle: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Favoriter'), findsOneWidget);
      expect(find.text('Snabblagat'), findsOneWidget);
      expect(find.text('Helg'), findsOneWidget);
    });

    testWidgets('selected chip shows checkmark', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: PersonalTagFilterChipsWidget(
            tags: testTags,
            selectedTagIds: const {'tag-1'},
            onToggle: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // FilterChip with selected=true renders a checkmark
      final chips = tester.widgetList<FilterChip>(find.byType(FilterChip));
      final selectedChip = chips.firstWhere(
        (c) => c.selected,
      );
      expect(selectedChip.showCheckmark, isTrue);
    });

    testWidgets('tapping a chip calls onToggle with correct tag ID',
        (tester) async {
      String? tappedId;
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: PersonalTagFilterChipsWidget(
            tags: testTags,
            selectedTagIds: const {},
            onToggle: (id) => tappedId = id,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('Snabblagat'));
      expect(tappedId, 'tag-2');
    });

    testWidgets('exclude section renders when configured', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: PersonalTagFilterChipsWidget(
            tags: testTags,
            selectedTagIds: const {},
            onToggle: (_) {},
            showExcludeSection: true,
            onExcludeToggle: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Exclude section has its own set of chips
      // Total FilterChips = 3 include + 3 exclude = 6
      expect(find.byType(FilterChip), findsNWidgets(6));
    });

    testWidgets('exclude section hidden when showExcludeSection is false',
        (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: PersonalTagFilterChipsWidget(
            tags: testTags,
            selectedTagIds: const {},
            onToggle: (_) {},
            showExcludeSection: false,
            onExcludeToggle: (_) {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only include chips
      expect(find.byType(FilterChip), findsNWidgets(3));
    });

    testWidgets('empty state shows create button when onManageTags provided',
        (tester) async {
      bool manageTapped = false;
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: PersonalTagFilterChipsWidget(
            tags: const [],
            selectedTagIds: const {},
            onToggle: (_) {},
            onManageTags: () => manageTapped = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Should find an add icon button
      expect(find.byIcon(Icons.add), findsOneWidget);
      await tester.tap(find.byIcon(Icons.add));
      expect(manageTapped, isTrue);
    });

    testWidgets('empty state shows nothing when onManageTags is null',
        (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: PersonalTagFilterChipsWidget(
            tags: const [],
            selectedTagIds: const {},
            onToggle: (_) {},
            onManageTags: null,
          ),
        ),
      );
      await tester.pumpAndSettle();

      // SizedBox.shrink — no TextButton, no FilterChip
      expect(find.byType(TextButton), findsNothing);
      expect(find.byType(FilterChip), findsNothing);
    });

    testWidgets('manage tags icon button calls onManageTags', (tester) async {
      bool called = false;
      await tester.pumpWidget(
        createLocalizedTestApp(
          wrapInScrollView: true,
          child: PersonalTagFilterChipsWidget(
            tags: testTags,
            selectedTagIds: const {},
            onToggle: (_) {},
            onManageTags: () => called = true,
          ),
        ),
      );
      await tester.pumpAndSettle();

      final settingsButton = find.byIcon(Icons.settings);
      expect(settingsButton, findsOneWidget);
      await tester.tap(settingsButton);
      expect(called, isTrue);
    });
  });
}
