/// Widget tests for AdaptiveIcon + AdaptiveIcons static helpers.
///
/// To flip the platform between tests we set
/// `debugDefaultTargetPlatformOverride` inside a try/finally that resets it
/// BEFORE the testWidgets body returns — Flutter's binding verifies all
/// foundation debug vars are unset between tests.
library;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/widgets/common/icons/adaptive_icon.dart';

Widget _wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

Future<T> onPlatform<T>(
  TargetPlatform platform,
  Future<T> Function() body,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    return await body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

T onPlatformSync<T>(TargetPlatform platform, T Function() body) {
  debugDefaultTargetPlatformOverride = platform;
  try {
    return body();
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
}

void main() {
  group('default constructor', () {
    testWidgets('uses materialIcon when no cupertinoIcon provided', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await tester.pumpWidget(
          _wrap(
            const AdaptiveIcon(materialIcon: Icons.alarm),
          ),
        );
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.icon, Icons.alarm);
      });
    });

    testWidgets('uses cupertinoIcon on iOS when provided', (tester) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await tester.pumpWidget(
          _wrap(
            const AdaptiveIcon(
              materialIcon: Icons.alarm,
              cupertinoIcon: CupertinoIcons.alarm,
            ),
          ),
        );
        expect(
          tester.widget<Icon>(find.byType(Icon)).icon,
          CupertinoIcons.alarm,
        );
      });
    });

    testWidgets('uses materialIcon on Android even when cupertinoIcon set', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          _wrap(
            const AdaptiveIcon(
              materialIcon: Icons.alarm,
              cupertinoIcon: CupertinoIcons.alarm,
            ),
          ),
        );
        expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.alarm);
      });
    });

    testWidgets('forwards size + color + semanticLabel', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          _wrap(
            const AdaptiveIcon(
              materialIcon: Icons.alarm,
              size: 36,
              color: Colors.red,
              semanticLabel: 'alarm-label',
            ),
          ),
        );
        final icon = tester.widget<Icon>(find.byType(Icon));
        expect(icon.size, 36);
        expect(icon.color, Colors.red);
        expect(icon.semanticLabel, 'alarm-label');
      });
    });
  });

  group('named factories — Material side', () {
    testWidgets('AdaptiveIcon.book → Icons.book', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(
          _wrap(const AdaptiveIcon.book(semanticLabel: 'l')),
        );
        expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.book);
      });
    });

    testWidgets('AdaptiveIcon.add → Icons.add', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(_wrap(const AdaptiveIcon.add()));
        expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.add);
      });
    });

    testWidgets('AdaptiveIcon.delete → Icons.delete', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(_wrap(const AdaptiveIcon.delete()));
        expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.delete);
      });
    });

    testWidgets('AdaptiveIcon.favorite → Icons.favorite', (tester) async {
      await onPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(_wrap(const AdaptiveIcon.favorite()));
        expect(tester.widget<Icon>(find.byType(Icon)).icon, Icons.favorite);
      });
    });

    testWidgets('outlined variants map to *_outlined material icons', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.android, () async {
        await tester.pumpWidget(_wrap(const AdaptiveIcon.bookOutlined()));
        expect(
          tester.widget<Icon>(find.byType(Icon)).icon,
          Icons.book_outlined,
        );
      });
    });
  });

  group('named factories — iOS side picks Cupertino', () {
    testWidgets('AdaptiveIcon.book on iOS → CupertinoIcons.book', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await tester.pumpWidget(_wrap(const AdaptiveIcon.book()));
        expect(
          tester.widget<Icon>(find.byType(Icon)).icon,
          CupertinoIcons.book,
        );
      });
    });

    testWidgets('AdaptiveIcon.delete on iOS → CupertinoIcons.trash', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await tester.pumpWidget(_wrap(const AdaptiveIcon.delete()));
        expect(
          tester.widget<Icon>(find.byType(Icon)).icon,
          CupertinoIcons.trash,
        );
      });
    });

    testWidgets('AdaptiveIcon.edit on iOS → CupertinoIcons.pencil', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await tester.pumpWidget(_wrap(const AdaptiveIcon.edit()));
        expect(
          tester.widget<Icon>(find.byType(Icon)).icon,
          CupertinoIcons.pencil,
        );
      });
    });

    testWidgets('AdaptiveIcon.close on iOS → CupertinoIcons.xmark', (
      tester,
    ) async {
      await onPlatform(TargetPlatform.iOS, () async {
        await tester.pumpWidget(_wrap(const AdaptiveIcon.close()));
        expect(
          tester.widget<Icon>(find.byType(Icon)).icon,
          CupertinoIcons.xmark,
        );
      });
    });
  });

  group('AdaptiveIcons static helpers', () {
    test('Android getters return Material icons', () {
      onPlatformSync(TargetPlatform.android, () {
        expect(AdaptiveIcons.book, Icons.book);
        expect(AdaptiveIcons.add, Icons.add);
        expect(AdaptiveIcons.calendar, Icons.calendar_today);
        expect(AdaptiveIcons.cart, Icons.shopping_cart);
        expect(AdaptiveIcons.share, Icons.share);
        expect(AdaptiveIcons.settings, Icons.settings);
        expect(AdaptiveIcons.star, Icons.star);
        expect(AdaptiveIcons.favorite, Icons.favorite);
        expect(AdaptiveIcons.grid, Icons.grid_view);
        expect(AdaptiveIcons.chevronRight, Icons.chevron_right);
      });
    });

    test('iOS getters return Cupertino icons', () {
      onPlatformSync(TargetPlatform.iOS, () {
        expect(AdaptiveIcons.book, CupertinoIcons.book);
        expect(AdaptiveIcons.add, CupertinoIcons.add);
        expect(AdaptiveIcons.calendar, CupertinoIcons.calendar);
        expect(AdaptiveIcons.cart, CupertinoIcons.cart);
        expect(AdaptiveIcons.share, CupertinoIcons.share);
        expect(AdaptiveIcons.settings, CupertinoIcons.gear);
        expect(AdaptiveIcons.star, CupertinoIcons.star_fill);
        expect(AdaptiveIcons.favorite, CupertinoIcons.heart_fill);
        expect(AdaptiveIcons.grid, CupertinoIcons.square_grid_2x2);
        expect(AdaptiveIcons.chevronRight, CupertinoIcons.chevron_right);
      });
    });

    test('outlined getters return their outlined variants on Android', () {
      onPlatformSync(TargetPlatform.android, () {
        expect(AdaptiveIcons.bookOutlined, Icons.book_outlined);
        expect(AdaptiveIcons.starOutlined, Icons.star_border);
        expect(AdaptiveIcons.favoriteOutlined, Icons.favorite_border);
        expect(AdaptiveIcons.bookmarkOutlined, Icons.bookmark_border);
      });
    });

    test('visibility / visibilityOff pair', () {
      onPlatformSync(TargetPlatform.iOS, () {
        expect(AdaptiveIcons.visibility, CupertinoIcons.eye);
        expect(AdaptiveIcons.visibilityOff, CupertinoIcons.eye_slash);
      });
    });
  });

  // BUT-944: the semantic concept aliases. These pin the concept→glyph
  // convention (heart→favourite, star→primary, bookmark→saved-template) so a
  // future edit can't silently re-point a concept at the wrong glyph
  // (e.g. `primaryFilled => bookmark`). They also guard that the aliases stay
  // exactly equivalent to the underlying shape getters the codemod replaced —
  // that equivalence is what makes the migration glyph-preserving on every
  // platform.
  group('AdaptiveIcons semantic concept aliases (BUT-944)', () {
    test('Material side: concepts map to heart / star / bookmark glyphs', () {
      onPlatformSync(TargetPlatform.android, () {
        expect(AdaptiveIcons.favouriteFilled, Icons.favorite);
        expect(AdaptiveIcons.favouriteOutline, Icons.favorite_border);
        expect(AdaptiveIcons.primaryFilled, Icons.star);
        expect(AdaptiveIcons.primaryOutline, Icons.star_border);
        expect(AdaptiveIcons.savedTemplate, Icons.bookmark);
        expect(AdaptiveIcons.savedTemplateOutline, Icons.bookmark_border);
      });
    });

    test('iOS side: concepts follow their underlying adaptive shape getter', () {
      onPlatformSync(TargetPlatform.iOS, () {
        expect(AdaptiveIcons.favouriteFilled, CupertinoIcons.heart_fill);
        expect(AdaptiveIcons.primaryFilled, CupertinoIcons.star_fill);
        // savedTemplate aliases bookmark, whose iOS glyph is the *_fill variant.
        expect(AdaptiveIcons.savedTemplate, CupertinoIcons.bookmark_fill);
      });
    });

    test(
      'aliases are exactly equivalent to the shape getters they replaced',
      () {
        // Holds on the test platform (Android) and, because both sides resolve
        // through the same `_isIOS` branch, on iOS too — proving the codemod is
        // glyph-preserving rather than glyph-changing.
        onPlatformSync(TargetPlatform.android, () {
          expect(AdaptiveIcons.favouriteFilled, AdaptiveIcons.favorite);
          expect(
            AdaptiveIcons.favouriteOutline,
            AdaptiveIcons.favoriteOutlined,
          );
          expect(AdaptiveIcons.primaryFilled, AdaptiveIcons.star);
          expect(AdaptiveIcons.primaryOutline, AdaptiveIcons.starOutlined);
          expect(AdaptiveIcons.savedTemplate, AdaptiveIcons.bookmark);
          expect(
            AdaptiveIcons.savedTemplateOutline,
            AdaptiveIcons.bookmarkOutlined,
          );
        });
      },
    );

    test('concepts are distinct — no two semantic names share a glyph', () {
      onPlatformSync(TargetPlatform.android, () {
        final glyphs = {
          AdaptiveIcons.favouriteFilled,
          AdaptiveIcons.primaryFilled,
          AdaptiveIcons.savedTemplate,
        };
        expect(
          glyphs,
          hasLength(3),
          reason: 'favourite, primary and saved-template must not collide',
        );
      });
    });
  });
}
