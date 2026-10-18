// BUT-2385: a push is rendered in every supported language on the sending
// device, because the recipient's language is only known to the server.
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/models/notification_batch.dart';
import 'package:butlery/services/notifications/modules/notification_content_manager.dart';
import 'package:butlery/services/notifications/notification_translations.dart';
import 'package:butlery/services/notifications/notification_types.dart';
import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/services/notifications/recipe_activity_strategies.dart';

void main() {
  group('translateStrategy', () {
    test('renders the strategy in both languages with the same variables', () {
      final t = translateStrategy(NotificationStrategy.friendRequest, {
        'senderName': 'Anna',
      });

      expect(t['sv']!.title, 'Ny vänskapsförfrågan');
      expect(t['sv']!.body, 'Anna vill bli vän med dig');
      expect(t['en']!.title, 'New friend request');
      expect(t['en']!.body, 'Anna wants to be your friend');
    });

    test(
      'a per-language variable overrides the plain one in that language only',
      () {
        final t = translateStrategy(
          RecipeActivityStrategies.ratingNotice,
          {'recipeName': 'Köttbullar', 'message': 'plain'},
          variablesByLocale: {
            'sv': {'message': 'Kim gav 4 stjärnor'},
            'en': {'message': 'Kim gave 4 stars'},
          },
        );

        expect(t['sv']!.body, 'Kim gav 4 stjärnor');
        expect(t['en']!.body, 'Kim gave 4 stars');
        expect(t['en']!.title, 'Rating for Köttbullar');
        expect(t['sv']!.title, 'Betyg på Köttbullar');
      },
    );

    test(
      'a language the strategy lacks falls back to that language default',
      () {
        const onlySwedish = NotificationStrategy(
          notificationType: 'test',
          destination: NotificationDestination(NotificationRoutes.home),
          type: NotificationType.immediate,
          priority: NotificationPriority.high,
          category: NotificationCategory.system,
          localization: {'title_sv': 'Hej', 'body_sv': 'Hallå'},
        );

        final t = translateStrategy(onlySwedish, const {});

        expect(t['sv']!.title, 'Hej');
        expect(t['en']!.title, AppLocalizationsEn().notificationDefaultTitle);
        expect(t['en']!.body, AppLocalizationsEn().notificationDefaultBody);
      },
    );
  });

  group('localizedVariables', () {
    test('builds the value once per supported language', () {
      final built = localizedVariables(
        (l) => {'message': l.notificationRatingMilestoneCount(10)},
      );

      expect(
        built['sv']!['message'],
        AppLocalizationsSv().notificationRatingMilestoneCount(10),
      );
      expect(
        built['en']!['message'],
        AppLocalizationsEn().notificationRatingMilestoneCount(10),
      );
      expect(built['sv']!['message'], isNot(built['en']!['message']));
    });
  });

  group('NotificationTemplate', () {
    test(
      'fromStrategy keeps the Swedish top-level text and adds translations',
      () {
        final template = NotificationTemplate.fromStrategy(
          NotificationStrategy.friendRequest,
          {'senderName': 'Anna'},
        );

        expect(template.title, 'Ny vänskapsförfrågan');
        expect(
          template.translations!['en']!.body,
          'Anna wants to be your friend',
        );
      },
    );

    test(
      'createTemplate carries the per-language variables into translations',
      () {
        final template = NotificationContentManager(userId: 'u').createTemplate(
          strategy: RecipeActivityStrategies.ratingNotice,
          variables: {'recipeName': 'Pasta', 'message': 'sender language'},
          variablesByLocale: {
            'sv': {'message': 'svenska'},
            'en': {'message': 'english'},
          },
        );

        expect(template.translations!['sv']!.body, 'svenska');
        expect(template.translations!['en']!.body, 'english');
      },
    );

    test(
      'translations survive the batch round trip through Firestore maps',
      () {
        final original = NotificationTemplate.fromStrategy(
          NotificationStrategy.friendRequest,
          {'senderName': 'Anna'},
        );

        final restored = NotificationTemplateSerializer.fromMap(
          original.toMap(),
        );

        expect(restored.translations!['en']!.title, 'New friend request');
        expect(restored.translations!['sv']!.body, 'Anna vill bli vän med dig');
      },
    );

    test(
      'a batch saved before translations existed reads back without them',
      () {
        final restored = NotificationTemplateSerializer.fromMap({
          'title': 'Gammal',
          'body': 'Notis',
          'data': <String, dynamic>{},
        });

        expect(restored.translations, isNull);
      },
    );
  });

  group('batch summary', () {
    test('is written in the requested language', () {
      final sv = NotificationContentManager.batchContentFor(
        'recipes',
        3,
        AppLocalizationsSv(),
      );
      final en = NotificationContentManager.batchContentFor(
        'recipes',
        3,
        AppLocalizationsEn(),
      );

      expect(sv['title'], 'Ny receptaktivitet');
      expect(sv['body'], '3 nya händelser på dina recept');
      expect(en['title'], 'New recipe activity');
      expect(en['body'], '3 new events on your recipes');
    });
  });
}
