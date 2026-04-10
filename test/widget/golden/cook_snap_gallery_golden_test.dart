import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/recipe/cook_snap_gallery.dart';
import 'package:butlery/models/cook_snap.dart';
import '../../infrastructure/helpers/widget_test_app.dart';
import '../../test_support/base_unit_test.dart';

void main() {
  group('CookSnapGallery Golden Tests', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    testWidgets('empty gallery matches golden', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SizedBox(
            width: 375,
            child: CookSnapGallery(
              snaps: const [],
              isLoading: false,
              isUploading: false,
              currentUserId: 'user1',
              onAdd: () {},
              onDelete: (_) {},
              onReport: (_) {},
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(CookSnapGallery),
        matchesGoldenFile('goldens/cook_snap_gallery_empty.png'),
      );
    });

    testWidgets('gallery with snaps matches golden', (tester) async {
      final snaps = [
        CookSnap(
          id: 'snap1',
          recipeId: 'recipe1',
          userId: 'user2',
          userDisplayName: 'Anna',
          photoUrl: 'https://example.com/photo1.jpg',
          createdAt: DateTime.now().subtract(const Duration(days: 2)),
        ),
        CookSnap(
          id: 'snap2',
          recipeId: 'recipe1',
          userId: 'user1',
          userDisplayName: 'Erik',
          photoUrl: 'https://example.com/photo2.jpg',
          createdAt: DateTime.now().subtract(const Duration(days: 5)),
        ),
      ];

      await tester.pumpWidget(
        createLocalizedTestApp(
          child: SizedBox(
            width: 375,
            child: CookSnapGallery(
              snaps: snaps,
              isLoading: false,
              isUploading: false,
              currentUserId: 'user1',
              onAdd: () {},
              onDelete: (_) {},
              onReport: (_) {},
            ),
          ),
        ),
      );

      await expectLater(
        find.byType(CookSnapGallery),
        matchesGoldenFile('goldens/cook_snap_gallery_with_snaps.png'),
      );
    });
  });
}
