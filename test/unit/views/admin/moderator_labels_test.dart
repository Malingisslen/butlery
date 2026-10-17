/// The moderator list shows stored values; a wrong label here tells a
/// moderator the wrong thing about a report. `inappropriate` is the one
/// pre-id reason that was an English word and must not be shown raw.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_en.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/models/social/content_type.dart';
import 'package:butlery/views/admin/moderator_labels.dart';

void main() {
  final sv = AppLocalizationsSv();
  final en = AppLocalizationsEn();

  group('moderatorReasonLabel', () {
    test('the old English word "inappropriate" gets today\'s label', () {
      expect(
        moderatorReasonLabel(sv, 'inappropriate'),
        sv.reportReasonInappropriate,
      );
      expect(
        moderatorReasonLabel(en, 'inappropriate'),
        en.reportReasonInappropriate,
      );
      expect(moderatorReasonLabel(sv, 'inappropriate'), isNot('inappropriate'));
    });

    test('a reason id gets its label', () {
      expect(moderatorReasonLabel(sv, 'spam'), sv.reportReasonSpam);
      expect(moderatorReasonLabel(sv, 'abuse'), sv.reportReasonInappropriate);
    });

    test('free text saved before reasons had ids is shown as saved', () {
      expect(moderatorReasonLabel(sv, 'Något helt annat'), 'Något helt annat');
    });
  });

  group('moderatorContentTypeLabel', () {
    test('every content type has a non-empty label', () {
      for (final type in ContentType.values) {
        expect(
          moderatorContentTypeLabel(sv, type),
          isNotEmpty,
          reason: '$type',
        );
      }
    });

    test('two types never share a label', () {
      final labels = {
        for (final type in ContentType.values)
          moderatorContentTypeLabel(sv, type),
      };
      expect(labels.length, ContentType.values.length);
    });
  });

  group('feedbackCategoryLabel', () {
    test('each category maps to its own label', () {
      expect(
        feedbackCategoryLabel(sv, FeedbackCategory.bug),
        sv.feedbackCategoryBug,
      );
      expect(
        feedbackCategoryLabel(sv, FeedbackCategory.featureRequest),
        sv.feedbackCategoryFeatureRequest,
      );
      expect(
        feedbackCategoryLabel(sv, FeedbackCategory.general),
        sv.feedbackCategoryGeneral,
      );
    });
  });
}
