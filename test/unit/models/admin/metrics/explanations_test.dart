/// Direct unit tests for the metric [explanations] map (BUT-1149 coverage
/// burndown — previously zero direct coverage).
///
/// The info-dialog reads explanations[key] for the metric on screen. The thing
/// worth guarding is completeness: every MetricKey must have an explanation (a
/// missing key would be a runtime gap in the dialog), and each explanation's
/// three accessors must return non-empty localized text.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/admin/metrics/explanations.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';

void main() {
  final l = lookupAppLocalizations(const Locale('en'));

  test('every MetricKey has an explanation', () {
    for (final key in MetricKey.values) {
      expect(explanations.containsKey(key), isTrue, reason: key.name);
    }
  });

  test('each explanation returns non-empty what/how/why text', () {
    explanations.forEach((key, e) {
      expect(e.whatIsIt(l).trim(), isNotEmpty, reason: '${key.name}.what');
      expect(e.howCalculated(l).trim(), isNotEmpty, reason: '${key.name}.how');
      expect(e.whyImportant(l).trim(), isNotEmpty, reason: '${key.name}.why');
    });
  });
}
