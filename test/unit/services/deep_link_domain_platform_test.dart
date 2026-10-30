/// A shared https link only opens the app when the phone's own link
/// verification names the host the app builds links on. butlery.app was never
/// ours, so no registration may claim it.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/deep_link_service.dart';

void main() {
  final host = Uri.parse(DeepLinkService.generateProfileLink('x')).host;

  test('shared links are built on butlery.se', () {
    expect(host, 'butlery.se');
  });

  test('Android verifies the shared-link host and not butlery.app', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android:host="$host"'));
    expect(manifest, isNot(contains('android:host="butlery.app"')));
  });

  test('both iOS builds claim the shared-link host and not butlery.app', () {
    for (final path in [
      'ios/Runner/Runner.entitlements',
      'ios/Runner/Release.entitlements',
    ]) {
      final entitlements = File(path).readAsStringSync();
      expect(entitlements, contains('applinks:$host<'), reason: path);
      expect(
        entitlements,
        isNot(contains('applinks:butlery.app<')),
        reason: path,
      );
    }
  });

  test('iOS opens every path the app builds, in the app', () {
    final aasa =
        jsonDecode(
              File(
                'web/.well-known/apple-app-site-association',
              ).readAsStringSync(),
            )
            as Map<String, dynamic>;
    final details =
        (aasa['applinks'] as Map<String, dynamic>)['details'] as List<dynamic>;
    final patterns = [
      for (final d in details) ...(d as Map<String, dynamic>)['paths'] as List,
    ].cast<String>();

    // iOS matches a pattern against the path alone: `/recipe/*` does not
    // match `/recipe`, which is what the app builds.
    bool opensApp(String path) => patterns.any(
      (p) => p.endsWith('*')
          ? path.startsWith(p.substring(0, p.length - 1))
          : path == p,
    );

    final built = {
      'invitation': DeepLinkService.generateFriendInvitationLink(
        invitationId: 'i',
        fromUserId: 'u',
      ),
      'recipe': DeepLinkService.generateRecipeShareLink(
        recipeId: 'r',
        fromUserId: 'u',
      ),
      'menu': DeepLinkService.generateMenuShareLink(
        menuId: 'm',
        fromUserId: 'u',
      ),
      'shopping list': DeepLinkService.generateShoppingListShareLink(
        listId: 'l',
        fromUserId: 'u',
      ),
      'profile': DeepLinkService.generateProfileLink('u'),
      'short link': '${DeepLinkService.baseUrl}/s/Ab3dE5gH',
    };
    for (final entry in built.entries) {
      expect(
        opensApp(Uri.parse(entry.value).path),
        isTrue,
        reason: '${entry.key} link ${entry.value} would open in Safari',
      );
    }
  });
}
