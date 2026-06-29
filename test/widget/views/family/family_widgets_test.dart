/// Widget tests for the "Min familj" presentation widgets.
///
/// These take plain models (no ViewModel / ServiceLocator), so they verify the
/// row rendering contract directly: a family member shows its name, age-band
/// label and allergen badges (or the "no allergies" chip), is tappable, and
/// carries the edit accessibility label. The screen's logic is covered by the
/// MinFamiljViewModel unit tests.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/views/family/family_widgets.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

DinerProfile _diner({
  String name = 'Liam',
  DinerAgeBand band = DinerAgeBand.child,
  Set<String> allergens = const {},
}) => DinerProfile.create(
  householdId: 'hh-1',
  name: name,
  ageBand: band,
  createdBy: 'user-malin',
  allergenPreferences: allergens.isEmpty
      ? null
      : UserAllergenPreferences(
          trackedAllergens: allergens,
          trackedDietary: const {},
        ),
);

void main() {
  group('FamilyMemberRow', () {
    testWidgets('shows name, age-band label and allergen badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyMemberRow(
            profile: _diner(allergens: {'gluten'}),
            onTap: () {},
          ),
        ),
      );

      expect(find.text('Liam'), findsOneWidget);
      expect(find.text('barn'), findsOneWidget); // ageBandChild (sv)
      expect(find.text('Gluten'), findsOneWidget); // allergen label
    });

    testWidgets('shows the "no allergies" chip when there are none', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyMemberRow(profile: _diner(), onTap: () {}),
        ),
      );

      expect(find.text('inga allergier'), findsOneWidget);
    });

    testWidgets('is tappable and carries the edit a11y label', (tester) async {
      var tapped = false;
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyMemberRow(
            profile: _diner(),
            onTap: () => tapped = true,
          ),
        ),
      );

      expect(
        find.bySemanticsLabel(RegExp('Redigera familjemedlem')),
        findsOneWidget,
      );
      await tester.tap(find.byType(FamilyMemberRow));
      expect(tapped, isTrue);
      handle.dispose();
    });

    testWidgets('a teen still reads as its age band', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyMemberRow(
            profile: _diner(band: DinerAgeBand.teen),
            onTap: () {},
          ),
        ),
      );
      expect(find.text('tonåring'), findsOneWidget);
    });
  });

  group('FamilyAccountRow', () {
    HouseholdRosterMember account() =>
        HouseholdRosterMember.fromUser(userId: 'u', displayName: 'Malin');

    testWidgets('shows the admin tag when the member is an admin', (
      tester,
    ) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyAccountRow(member: account(), isAdmin: true),
        ),
      );
      expect(find.text('Malin'), findsOneWidget);
      expect(find.text('admin'), findsOneWidget);
    });

    testWidgets('omits the admin tag for a non-admin member', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: FamilyAccountRow(member: account(), isAdmin: false),
        ),
      );
      expect(find.text('admin'), findsNothing);
    });
  });

  group('FamilyAvatar', () {
    testWidgets('renders initials from the name', (tester) async {
      await tester.pumpWidget(
        createLocalizedTestApp(
          child: const FamilyAvatar(name: 'Emma', color: Colors.purple),
        ),
      );
      expect(find.text('E'), findsOneWidget);
    });
  });
}
