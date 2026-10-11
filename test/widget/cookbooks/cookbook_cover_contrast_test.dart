import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/tagging/cookbook_details.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/widgets/cookbooks/cookbook_cover.dart';

import '../../infrastructure/helpers/widget_test_app.dart';

void main() {
  const minimumRatio = 4.5;

  for (final (themeName, theme) in [
    ('light', AppTheme.lightTheme),
    ('dark', AppTheme.darkTheme),
  ]) {
    group('cover title on every swatch, $themeName theme', () {
      for (final key in CookbookCoverPalette.keys) {
        testWidgets('"$key" reads at 4.5:1 or better', (tester) async {
          late Color background;
          await tester.pumpWidget(
            createLocalizedTestApp(
              child: Theme(
                data: theme,
                child: Builder(
                  builder: (context) {
                    background = CookbookCoverPalette.color(context, key);
                    return SizedBox(
                      width: 200,
                      height: 200,
                      child: CookbookCoverView(
                        name: 'Mormors favoriter',
                        cover: CookbookCover(colorKey: key),
                        imageUrl: null,
                      ),
                    );
                  },
                ),
              ),
            ),
          );

          // The colour the cover really paints its title with.
          final title = tester.widget<Text>(find.text('Mormors favoriter'));
          final ink = title.style!.color!;

          expect(
            CookbookCoverPalette.contrastRatio(ink, background),
            greaterThanOrEqualTo(minimumRatio),
            reason: 'swatch "$key" ($background) with title colour $ink',
          );
        });
      }
    });
  }

  testWidgets('the palette keys resolve to distinct swatches in each theme', (
    tester,
  ) async {
    // Keeps the loop above from testing one colour six times.
    for (final theme in [AppTheme.lightTheme, AppTheme.darkTheme]) {
      final seen = <Color>{};
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: Theme(
            data: theme,
            child: Builder(
              builder: (context) {
                for (final key in CookbookCoverPalette.keys) {
                  seen.add(CookbookCoverPalette.color(context, key));
                }
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );
      expect(seen.length, CookbookCoverPalette.keys.length);
    }
  });
}
