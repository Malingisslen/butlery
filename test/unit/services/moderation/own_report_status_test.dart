// The pre-deletion check answers THREE things, not two (ADR-0019).
//
// `user_moderation`'s read rule is a `hasOnly` allowlist and fails CLOSED: the
// day any writer adds a field to that document, the read is refused for EVERY
// user rather than narrowed. Collapsed into a bool, that outage is
// indistinguishable from "nobody has ever been reported" — and the warning
// would stop firing for exactly the people with an open case, indefinitely,
// with nothing reddening.
//
// So `unknown` exists, and these cases pin that it is produced on every failure
// path and never confused with `none`. The UI treats the two identically, which
// is Trust & Safety's condition and also why this distinction cannot be tested
// from the screen: it only shows up here.

import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/repositories/firebase/firebase_report_repository.dart';
import 'package:butlery/repositories/firestore_repository.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart' as auth;
import 'package:butlery/services/moderation/report_service.dart';

class _FakeReportRepository implements FirebaseReportRepository {
  _FakeReportRepository({
    this.counters,
    this.throws = false,
    this.hang = false,
  });

  final ModerationCounters? counters;
  final bool throws;
  final bool hang;

  @override
  Future<ModerationCounters?> fetchOwnModerationCounters(String userId) async {
    if (throws) throw StateError('permission-denied');
    if (hang) await Future<void>.delayed(const Duration(minutes: 1));
    return counters;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeAuthRepository implements auth.AuthRepository {
  _FakeAuthRepository(this.uid);

  final String? uid;

  @override
  String? get currentUserId => uid;

  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

class _FakeFirestoreRepository implements FirestoreRepository {
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}

ReportService _service(_FakeReportRepository repo, {String? uid = 'u1'}) {
  return ReportService(
    reportRepository: repo,
    authRepository: _FakeAuthRepository(uid),
    firestoreRepository: _FakeFirestoreRepository(),
  );
}

void main() {
  test('a positive counter answers reported', () async {
    final service = _service(
      _FakeReportRepository(
        counters: const ModerationCounters(totalReports: 2),
      ),
    );

    expect(await service.ownReportStatus(), OwnReportStatus.reported);
  });

  test('a zero counter answers none — confirmed, not a failure', () async {
    // An absent document is a legitimate answer: the rule's `resource == null`
    // arm permits it, and it means nobody has ever reported this person.
    final service = _service(
      _FakeReportRepository(
        counters: const ModerationCounters(totalReports: 0),
      ),
    );

    expect(await service.ownReportStatus(), OwnReportStatus.none);
  });

  test('a null from the repository answers unknown, never none', () async {
    // This is the whole point of the enum. The repository returns null when the
    // read FAILED or was denied — including the fail-closed allowlist case,
    // which denies every user at once.
    final service = _service(_FakeReportRepository(counters: null));

    expect(await service.ownReportStatus(), OwnReportStatus.unknown);
  });

  test('a throw answers unknown rather than escaping', () async {
    // It runs on the path to a deletion the user asked for; a moderation check
    // must not be able to take that flow down.
    final service = _service(_FakeReportRepository(throws: true));

    expect(await service.ownReportStatus(), OwnReportStatus.unknown);
  });

  test('a signed-out caller answers unknown', () async {
    final service = _service(
      _FakeReportRepository(
        counters: const ModerationCounters(totalReports: 9),
      ),
      uid: null,
    );

    expect(await service.ownReportStatus(), OwnReportStatus.unknown);
  });

  test(
    'a slow read times out into unknown, not into none',
    () async {
      // The delete-account confirmation opens instantly today, so the check is
      // bounded. The direction of the timeout matters: answering `none` would
      // silently drop the warning for a reported person on a bad connection.
      final service = _service(_FakeReportRepository(hang: true));

      expect(
        await service.ownReportStatus(),
        OwnReportStatus.unknown,
      );
    },
    timeout: const Timeout(Duration(seconds: 15)),
  );

  test('the bound is short enough not to warrant a spinner', () async {
    // Pinned as a value rather than described: the plan's reasoning for having
    // no loading state rests on this number being small.
    expect(
      ReportService.ownReportLookupTimeout,
      lessThanOrEqualTo(const Duration(seconds: 3)),
    );
  });
}
