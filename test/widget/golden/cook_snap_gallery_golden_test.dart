import 'dart:io' show Platform;

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/widgets/recipe/cook_snap_gallery.dart';
import 'package:butlery/models/cook_snap.dart';

import '../../test_support/base_unit_test.dart';
import 'golden_helper.dart';

void main() {
  group('CookSnapGallery Golden Tests', () {
    setUpAll(() async {
      await BaseUnitTest.setupUnit();
    });

    butleryGolden(
      'empty gallery matches golden',
      file: 'goldens/cook_snap_gallery_empty.png',
      width: 375,
      height: null,
      target: find.byType(CookSnapGallery),
      build: () => CookSnapGallery(
        snaps: const [],
        isLoading: false,
        isUploading: false,
        currentUserId: 'user1',
        onAdd: () {},
        onDelete: (_) {},
        onReport: (_) {},
      ),
    );

    // CachedNetworkImage (added in c11afc720) uses flutter_cache_manager,
    // which uses sqflite. On macOS widget-test runners the native sqflite
    // plugin isn't initialised and an async gap in CacheStore bypasses
    // the path_provider + com.tekartik.sqflite MethodChannel stubs in
    // golden_helper. Ubuntu + windows are unaffected. Skip this single
    // test on macOS; the empty-gallery golden still proves the widget
    // renders correctly there.
    if (!Platform.isMacOS) {
      butleryGolden(
        'gallery with snaps matches golden',
        file: 'goldens/cook_snap_gallery_with_snaps.png',
        width: 375,
        height: null,
        target: find.byType(CookSnapGallery),
        build: () {
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
          return CookSnapGallery(
            snaps: snaps,
            isLoading: false,
            isUploading: false,
            currentUserId: 'user1',
            onAdd: () {},
            onDelete: (_) {},
            onReport: (_) {},
          );
        },
      );
    }
  });
}
