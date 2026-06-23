import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/views/recipe_detail/recipe_detail_shared_widgets.dart';

/// BUT-1041: the recipe-detail source link picks a platform-aware leading icon
/// purely by sniffing the URL host — no sourceType enum / schema migration.
/// These tests pin that host→icon contract so the affordance keeps reading as
/// "media" for video imports and "external link" for everything else.
void main() {
  group('RecipeDetailSharedWidgets.sourceIcon', () {
    test('YouTube watch URLs map to the play icon', () {
      expect(
        RecipeDetailSharedWidgets.sourceIcon(
          'https://www.youtube.com/watch?v=abc123',
        ),
        Icons.play_circle_outline,
      );
    });

    test('youtu.be short links map to the play icon', () {
      expect(
        RecipeDetailSharedWidgets.sourceIcon('https://youtu.be/abc123'),
        Icons.play_circle_outline,
      );
    });

    test('YouTube subdomains (m.youtube.com) still map to the play icon', () {
      expect(
        RecipeDetailSharedWidgets.sourceIcon('https://m.youtube.com/watch?v=x'),
        Icons.play_circle_outline,
      );
    });

    test('TikTok URLs map to the music icon', () {
      expect(
        RecipeDetailSharedWidgets.sourceIcon(
          'https://www.tiktok.com/@chef/video/123',
        ),
        Icons.music_note,
      );
    });

    test('TikTok share subdomains (vm.tiktok.com) map to the music icon', () {
      expect(
        RecipeDetailSharedWidgets.sourceIcon('https://vm.tiktok.com/ABCDEF/'),
        Icons.music_note,
      );
    });

    test('generic web recipe sources map to the external-link icon', () {
      expect(
        RecipeDetailSharedWidgets.sourceIcon('https://www.ica.se/recept/xyz'),
        Icons.open_in_new,
      );
    });

    test('hostless input (no parseable host) falls back to external-link', () {
      // 'not a url' parses to a relative ref with an empty host → fallback.
      expect(
        RecipeDetailSharedWidgets.sourceIcon('not a url'),
        Icons.open_in_new,
      );
    });

    test('mixed-case host input still maps correctly', () {
      // Uri.host already RFC-normalizes case; the .toLowerCase() in sourceIcon
      // is dead-defensive. This pins the user-visible result regardless.
      expect(
        RecipeDetailSharedWidgets.sourceIcon('https://YouTube.com/watch?v=x'),
        Icons.play_circle_outline,
      );
    });
  });
}
