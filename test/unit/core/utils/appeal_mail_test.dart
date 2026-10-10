// BUT-2222: the appeal mail body is built from the four values it is given.
// What the view passes in (privacy condition 5) is pinned in
// test/widget/views/settings/my_reports_view_test.dart.
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/utils/appeal_mail.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/social/content_report.dart';
import 'package:butlery/widgets/social/report_outcome_labels.dart';

void main() {
  final sv = AppLocalizationsSv();

  test('body has report id, date, reason and outcome', () {
    final outcome = reportOutcomeText(
      sv,
      ReportStatus.closed,
      ModeratorDecision.contentRemoved,
    );

    final body = buildReportAppealBody(
      sv,
      reportId: 'rep-123',
      date: '1 okt 2026',
      reason: 'Skräppost',
      outcome: outcome,
    );

    expect(body, contains('rep-123'));
    expect(body, contains('1 okt 2026'));
    expect(body, contains('Skräppost'));
    expect(body, contains(outcome));
  });

  test('mailto goes to the appeals address with subject and body', () {
    final uri = buildAppealMailUri(subject: 'S', body: 'B');
    expect(uri.scheme, 'mailto');
    expect(uri.path, 'overklagande@butlery.se');
    expect(uri.queryParameters, {'subject': 'S', 'body': 'B'});
  });
}
