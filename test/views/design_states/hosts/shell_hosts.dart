/// P8-U01 hosts: dialogs, auth/OTP, admin and the legal pages.
library;

import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart' show FirebaseAuthException;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/admin/anomaly_report.dart';
import 'package:butlery/models/feedback_entry.dart';
import 'package:butlery/repositories/anomaly_repository.dart';
import 'package:butlery/repositories/interfaces/feedback_repository.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/views/admin/admin_shell.dart';
import 'package:butlery/views/admin/feedback_inbox_view.dart';
import 'package:butlery/views/auth/email_verification_view.dart';
import 'package:butlery/views/legal/community_guidelines_view.dart';
import 'package:butlery/widgets/common/dialogs/base_dialog.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';
import '../state_harness.dart';
import '../state_host.dart';
import 'host_helpers.dart';

class _MockFeedbackRepository extends Mock implements FeedbackRepository {}

class _MockAnomalyRepository extends Mock implements AnomalyRepository {}

/// The page a dialog opens over.
Widget _dialogOver(void Function(BuildContext context) open) => OpensOnMount(
  open: open,
  page: Scaffold(body: Center(child: Text(sv.hemGreetingWelcome))),
);

/// Admin: the feedback inbox reads its entries from the repository stream.
StreamController<List<FeedbackEntry>> _adminRepositories(HostContext ctx) {
  final stream = StreamController<List<FeedbackEntry>>.broadcast();
  ctx.disposers.add(() => unawaited(stream.close()));
  final repo = _MockFeedbackRepository();
  when(
    () => repo.watchFeedback(
      status: any(named: 'status'),
      limit: any(named: 'limit'),
    ),
  ).thenAnswer((_) => stream.stream);
  TestServiceLocator.registerMock<FeedbackRepository>(repo);
  final anomalies = _MockAnomalyRepository();
  when(anomalies.getLatest).thenAnswer((_) async => AnomalyReport.empty);
  TestServiceLocator.registerMock<AnomalyRepository>(anomalies);
  return stream;
}

FeedbackEntry _entry(String id, String text) => FeedbackEntry(
  id: id,
  userId: 'u1',
  category: FeedbackCategory.bug,
  description: text,
  recentInteractions: const [],
  createdAt: DateTime.utc(2026, 9, 20, 8),
);

/// Auth: the OTP gate resolves AuthService in initState.
MockAuthService _auth({Future<void> Function()? send}) {
  final auth = MockAuthService()..setAuthState(isAuthenticated: true);
  when(auth.reloadUser).thenAnswer((_) async {});
  when(auth.sendEmailVerification).thenAnswer((_) => send?.call() ?? _done());
  TestServiceLocator.registerMock<AuthService>(auth);
  return auth;
}

Future<void> _done() async {}

Future<void> _tapResend(WidgetTester tester) async {
  await tester.tap(find.text(sv.emailVerificationResend));
  await tester.pump();
}

final shellHosts = <String, StateHost>{
  'dialog-sheet::DEFAULT': StateHost(
    build: (ctx) async => _dialogOver(
      (context) => unawaited(
        // The household sharing question, as
        // lib/views/settings/widgets/household_allergen_sharing_tile.dart:144
        // asks it.
        ConfirmationDialog.show(
          context,
          title: sv.householdAllergenShareConfirmTitle,
          message: sv.householdAllergenShareConfirmBody,
          titleIcon: ButleryIcons.lock,
          primaryActionIcon: ButleryIcons.lock,
          primaryActionText: sv.householdAllergenShareConfirmAction,
        ),
      ),
    ),
  ),
  'dialog-sheet::LOADING': StateHost(
    build: (ctx) async => _dialogOver(
      (context) => LoadingDialog.show(context, message: sv.recipeSaving),
    ),
  ),
  'auth-otp::DEFAULT': StateHost(
    build: (ctx) async {
      _auth();
      return const EmailVerificationView(email: 'anna@example.com');
    },
  ),
  'auth-otp::LOADING': StateHost(
    build: (ctx) async {
      final pending = Completer<void>();
      _auth(send: () => pending.future);
      return const EmailVerificationView(email: 'anna@example.com');
    },
    reach: (tester, ctx) => _tapResend(tester),
  ),
  // BEVIS is AuthActionHandler, a handler with no screen; the OTP gate is
  // where auth shows being offline: a resend without a network.
  'auth-otp::OFFLINE': StateHost(
    online: false,
    build: (ctx) async {
      _auth(
        send: () =>
            Future.error(FirebaseAuthException(code: 'network-request-failed')),
      );
      return const EmailVerificationView(email: 'anna@example.com');
    },
    reach: (tester, ctx) async {
      await _tapResend(tester);
      await tester.pump();
    },
  ),
  'admin::DEFAULT': StateHost(
    build: (ctx) async {
      final stream = _adminRepositories(ctx);
      scheduleMicrotask(
        () => stream.add([
          _entry('f1', 'Knappen Spara svarar inte i receptredigeraren'),
          _entry('f2', 'Veckomenyn visar fel vecka efter midnatt'),
        ]),
      );
      return const AdminShell();
    },
  ),
  'admin::EMPTY': StateHost(
    build: (ctx) async {
      final stream = _adminRepositories(ctx);
      scheduleMicrotask(() => stream.add(const []));
      return const FeedbackInboxView();
    },
  ),
  'juridik::DEFAULT': StateHost(
    build: (ctx) async => const CommunityGuidelinesView(),
    reach: (tester, ctx) async {
      // The markdown asset is read off the fake clock (the pattern of
      // test/widget/views/legal/legal_states_test.dart:82-93).
      for (var i = 0; i < 50; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 20)),
        );
        await tester.pump();
        if (find.text(sv.loadingCommunityGuidelines).evaluate().isEmpty) {
          break;
        }
      }
    },
  ),
};
