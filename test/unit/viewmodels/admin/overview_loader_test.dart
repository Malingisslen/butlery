/// The overview loader (BUT-2407): each read is attempted on its own, so one
/// failing source marks only its own row unavailable and the rest still resolve.
library;

import 'package:clock/clock.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/admin/anomaly_report.dart';
import 'package:butlery/models/admin/metrics/metric_key.dart';
import 'package:butlery/models/admin/metrics/metric_value.dart';
import 'package:butlery/models/admin/overview_status.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/models/tagging/ingredient_change_request.dart';
import 'package:butlery/repositories/anomaly_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/repositories/interfaces/ingredient_change_request_repository.dart';
import 'package:butlery/repositories/interfaces/signup_allowlist_repository.dart';
import 'package:butlery/repositories/ops_log_repository.dart';
import 'package:butlery/services/admin/metrics_assembler.dart';
import 'package:butlery/viewmodels/admin/overview_loader.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../test_support/base_unit_test.dart';

class _Anomalies extends Fake implements AnomalyRepository {
  @override
  Future<AnomalyReport> getLatest() async => AnomalyReport.empty;
}

class _Metrics extends Fake implements MetricsAssembler {
  @override
  Future<Map<MetricKey, MetricValue>> resolve(
    Set<MetricKey> keys,
    AppLocalizations l10n, {
    bool force = false,
  }) async => {
    MetricKey.importSuccess: const ScalarMetric(50),
    MetricKey.importFailure: const ScalarMetric(0),
  };
}

class _Feedback extends Fake implements FeedbackRepository {
  @override
  Stream<List<FeedbackEntry>> watchFeedback({
    FeedbackStatus? status,
    int limit = 50,
  }) => Stream.value([]);
}

class _Proposals extends Fake implements IngredientChangeRequestRepository {
  @override
  Stream<List<IngredientChangeRequest>> watchOpen() => Stream.value([]);
}

class _Ops extends Fake implements OpsLogRepository {
  DateTime? receipt;
  Object? error;
  @override
  Future<DateTime?> getLatestReceiptAt() async {
    if (error != null) throw error!;
    return receipt;
  }
}

class _Allowlist extends Fake implements SignupAllowlistRepository {
  int pending = 0;
  Object? error;
  @override
  Future<int> countPending() async {
    if (error != null) throw error!;
    return pending;
  }
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnitWithProductionLocator();
  });

  final now = DateTime(2026, 11, 9, 12);
  late _Ops ops;
  late _Allowlist allowlist;

  setUp(() {
    ops = _Ops()..receipt = now.subtract(const Duration(days: 1));
    allowlist = _Allowlist();
    TestServiceLocator.registerSingleton<AnomalyRepository>(_Anomalies());
    TestServiceLocator.registerSingleton<MetricsAssembler>(_Metrics());
    TestServiceLocator.registerSingleton<FeedbackRepository>(_Feedback());
    TestServiceLocator.registerSingleton<IngredientChangeRequestRepository>(
      _Proposals(),
    );
    TestServiceLocator.registerSingleton<OpsLogRepository>(ops);
    TestServiceLocator.registerSingleton<SignupAllowlistRepository>(allowlist);
  });

  Future<OverviewRow> row(OverviewTarget target) => withClock(
    Clock.fixed(now),
    () async => (await loadOverviewRows(
      AppLocalizationsSv(),
    )).singleWhere((r) => r.target == target),
  );

  test('a receipt 9 days old needs a look and names the 9 days', () async {
    ops.receipt = now.subtract(const Duration(days: 9));
    final r = await row(OverviewTarget.ops);
    expect(r.status, OverviewStatus.needsLook);
    expect(r.advice, OverviewAdvice.opsStale);
    expect(r.number, 9);
  });

  test('no receipt at all is opsNone', () async {
    ops.receipt = null;
    expect((await row(OverviewTarget.ops)).advice, OverviewAdvice.opsNone);
  });

  test('pending invites are informational, never needsLook', () async {
    allowlist.pending = 3;
    final r = await row(OverviewTarget.guestList);
    expect(r.advice, OverviewAdvice.guestPending);
    expect(r.number, 3);
    expect(r.status, OverviewStatus.ok);
  });

  test('a failing ops read leaves only the ops row unavailable', () async {
    ops.error = StateError('denied');
    allowlist.pending = 3;
    expect((await row(OverviewTarget.ops)).status, OverviewStatus.unavailable);
    expect(
      (await row(OverviewTarget.guestList)).advice,
      OverviewAdvice.guestPending,
    );
  });

  test(
    'a failing countPending leaves only the guest row unavailable',
    () async {
      allowlist.error = StateError('denied');
      expect(
        (await row(OverviewTarget.guestList)).status,
        OverviewStatus.unavailable,
      );
      expect((await row(OverviewTarget.ops)).advice, OverviewAdvice.opsOk);
    },
  );
}
