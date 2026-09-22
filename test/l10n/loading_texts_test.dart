// Laddningstexterna som paket 2 lägger till (oanvända tills vyerna tar in dem
// i paket 4). Varje text säger vad som hämtas (produktregler.md:304) och
// skrivs med tecknet … med mellanslag före (content-style-guide.md:63).

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

const _keys = [
  'loadingAdminAccess',
  'loadingConsents',
  'loadingFeedbackEntries',
  'loadingImage',
  'loadingMetrics',
  'loadingReports',
  'loadingOpsLog',
  'loadingParsingStats',
  'loadingFamily',
  'loadingIngredientSearch',
  'loadingCommunityGuidelines',
  'loadingTerms',
  'loadingWeeklyMenu',
  'loadingNotifications',
  'loadingPersonalTags',
  'loadingAllergenPreferences',
  'loadingMfaSettings',
  'loadingMyReports',
  'loadingNotificationPreferences',
  'loadingTag',
  'loadingShoppingList',
  'loadingShoppingLists',
  'loadingGroupMembers',
  'loadingProfile',
];

Map<String, dynamic> _arb(String name) =>
    jsonDecode(File('lib/l10n/$name').readAsStringSync())
        as Map<String, dynamic>;

void main() {
  for (final file in ['app_sv.arb', 'app_en.arb']) {
    test('$file carries every loading text in the ongoing form', () {
      final arb = _arb(file);
      for (final key in _keys) {
        final value = arb[key];
        expect(value, isA<String>(), reason: '$key missing in $file');
        final text = value as String;
        expect(text.endsWith(' …'), isTrue, reason: '$key: "$text"');
        expect(text.contains('...'), isFalse, reason: '$key: "$text"');
        expect(text.contains('!'), isFalse, reason: '$key: "$text"');
      }
    });
  }
}
