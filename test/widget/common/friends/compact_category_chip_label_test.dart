// BUT-2155: a chosen chip on the theme's ink fill takes a paper label, so a
// chip that fills its chosen state with surface.raised instead must set its
// own ink label, or the name turns paper on a pale plate in light mode.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/friend_category.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/common/friends/category_selection_widgets.dart';

void main() {
  for (final (name, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    testWidgets(
      'a chosen compact category chip takes onSurface for its label ($name)',
      (
        tester,
      ) async {
        final category = FriendCategory(
          id: 'c1',
          ownerId: 'u1',
          name: 'Familjen',
          createdAt: DateTime(2026),
          updatedAt: DateTime(2026),
        );
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: Builder(
                builder: (context) =>
                    CategorySelectionWidgets.compactCategoryChip(
                      context,
                      category: category,
                      isSelected: true,
                      onTap: () {},
                    ),
              ),
            ),
          ),
        );
        final style = DefaultTextStyle.of(
          tester.element(find.text('Familjen')),
        ).style;
        expect(style.color, theme.colorScheme.onSurface);
      },
    );
  }
}
