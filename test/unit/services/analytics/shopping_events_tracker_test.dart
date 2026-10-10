import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/account/user_consent.dart';
import 'package:butlery/repositories/interfaces/analytics_repository.dart';
import 'package:butlery/services/account/consent_service.dart';
import 'package:butlery/services/analytics/trackers/shopping_events_tracker.dart';

import '../../../test_support/base_unit_test.dart';

class _MockAnalyticsRepo extends Mock implements AnalyticsRepository {}

class _MockConsentService extends Mock implements ConsentService {}

void main() {
  late _MockAnalyticsRepo repo;
  late _MockConsentService consent;
  late ShoppingEventsTracker tracker;

  setUpAll(() async {
    await BaseUnitTest.setupUnit();
    registerFallbackValue(<String, Object>{});
    registerFallbackValue(ConsentPurpose.analytics);
  });

  setUp(() {
    repo = _MockAnalyticsRepo();
    when(
      () => repo.logEvent(
        name: any(named: 'name'),
        parameters: any(named: 'parameters'),
      ),
    ).thenAnswer((_) async {});
    consent = _MockConsentService();
    when(() => consent.hasConsent(any())).thenAnswer((_) async => true);
    tracker = ShoppingEventsTracker(repository: repo)
      ..setConsentService(consent);
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  ({String name, Map<String, Object>? params}) sent() {
    final call = verify(
      () => repo.logEvent(
        name: captureAny(named: 'name'),
        parameters: captureAny(named: 'parameters'),
      ),
    ).captured;
    return (
      name: call[0] as String,
      params: call[1] as Map<String, Object>?,
    );
  }

  group('logShoppingListItemAdded', () {
    // A rename of these keys would orphan any query filtering on them, and
    // nothing at the call sites would notice.
    test('a recipe bulk add carries source, item_count and list_id under '
        'their warehouse names', () async {
      await tracker.logShoppingListItemAdded(
        listId: 'list-1',
        source: 'recipe',
        itemCount: 12,
      );

      final event = sent();
      expect(event.name, 'shopping_list_item_added');
      expect(event.params, {
        'list_id': 'list-1',
        'source': 'recipe',
        'item_count': 12,
      });
    });

    test('a call without source or count sends only the list id', () async {
      await tracker.logShoppingListItemAdded(listId: 'list-1');

      expect(sent().params, {'list_id': 'list-1'});
    });

    test('without analytics consent nothing is sent', () async {
      when(() => consent.hasConsent(any())).thenAnswer((_) async => false);

      await tracker.logShoppingListItemAdded(
        listId: 'list-1',
        source: 'recipe',
        itemCount: 3,
      );

      verifyNever(
        () => repo.logEvent(
          name: any(named: 'name'),
          parameters: any(named: 'parameters'),
        ),
      );
    });
  });

  group('logShoppingListCreated', () {
    test('a menu-generated list carries source menu_generated and the '
        'initial count under their warehouse names', () async {
      await tracker.logShoppingListCreated(
        listId: 'list-2',
        listType: 'personal',
        initialItemCount: 20,
        source: 'menu_generated',
      );

      final event = sent();
      expect(event.name, 'shopping_list_created');
      expect(event.params, {
        'list_id': 'list-2',
        'list_type': 'personal',
        'initial_item_count': 20,
        'source': 'menu_generated',
      });
    });

    test('a call without the optional fields omits their keys rather than '
        'sending nulls', () async {
      await tracker.logShoppingListCreated(
        listId: 'list-2',
        listType: 'shared',
      );

      expect(sent().params, {'list_id': 'list-2', 'list_type': 'shared'});
    });
  });
}
