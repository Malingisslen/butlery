/// BUT-2154: the stored `reason` is an id; the screens that list reports show
/// the Swedish label for an id and the saved text for older reports.
library;

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/report_reason.dart';
import 'package:butlery/widgets/social/report_reason_labels.dart';

void main() {
  final l10n = AppLocalizationsSv();

  test('a known id shows its Swedish label', () {
    expect(reportReasonDisplay(l10n, 'abuse'), 'Olämpligt innehåll');
    expect(reportReasonDisplay(l10n, 'spam'), 'Spam');
    expect(reportReasonDisplay(l10n, 'harassment'), 'Trakasseri');
    expect(reportReasonDisplay(l10n, 'copyright'), 'Upphovsrättsintrång');
    expect(reportReasonDisplay(l10n, 'other'), 'Annat');
  });

  test('older free text is shown as it was saved', () {
    expect(
      reportReasonDisplay(l10n, 'Olämpligt innehåll'),
      'Olämpligt innehåll',
    );
    expect(reportReasonDisplay(l10n, 'Spam'), 'Spam');
    expect(reportReasonDisplay(l10n, 'något helt annat'), 'något helt annat');
  });

  test('an id the dialog never offers shows its raw id, not a blank', () {
    expect(reportReasonDisplay(l10n, 'csam'), 'csam');
    expect(reportReasonDisplay(l10n, 'misinformation'), 'misinformation');
  });

  test('every reason the dialog offers has a label', () {
    for (final reason in ReportReason.offered) {
      expect(reason.label(l10n), isNotNull, reason: reason.name);
    }
  });
}
