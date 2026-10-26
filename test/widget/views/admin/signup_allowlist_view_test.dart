// The admin "Gästlista" tab (BUT-2452): the empty and error states, an expired
// invite still listed and marked, and "Ta bort" removing only after the
// confirmation dialog says yes.
import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/admin/signup_invite.dart';
import 'package:butlery/repositories/interfaces/signup_allowlist_repository.dart';
import 'package:butlery/viewmodels/admin/signup_allowlist_viewmodel.dart';
import 'package:butlery/views/admin/signup_allowlist_view.dart';
import 'package:butlery/widgets/common/dialogs/destructive_confirmation_dialog.dart';

import '../../../infrastructure/helpers/widget_test_app.dart';

class _FakeRepo implements SignupAllowlistRepository {
  _FakeRepo([List<SignupInvite> invites = const []])
    : stored = {for (final i in invites) i.email: i};

  final Map<String, SignupInvite> stored;
  final List<String> removed = [];
  Object? listError;

  @override
  Future<List<SignupInvite>> listInvites() async {
    if (listError != null) throw listError!;
    return stored.values.toList();
  }

  @override
  Future<void> invite(String email) async {
    stored[email] = SignupInvite(email: email, invitedAt: clock.now());
  }

  @override
  Future<void> remove(String email) async {
    removed.add(email);
    stored.remove(email);
  }
}

void main() {
  final sv = AppLocalizationsSv();

  Future<void> pump(WidgetTester tester, _FakeRepo repo) async {
    await tester.pumpWidget(
      createLocalizedTestApp(
        wrapInScaffold: false,
        child: SignupAllowlistView(
          viewModel: SignupAllowlistViewModel(repository: repo),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('an empty list says nobody is invited, with the form above', (
    tester,
  ) async {
    await pump(tester, _FakeRepo());

    expect(find.text(sv.adminGuestListEmpty), findsOneWidget);
    expect(find.text(sv.adminGuestListEmailLabel), findsOneWidget);
    expect(find.text(sv.adminGuestListInvite), findsOneWidget);
  });

  testWidgets('a failed load shows the error state, not the empty one', (
    tester,
  ) async {
    final repo = _FakeRepo()
      ..listError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
    await pump(tester, repo);

    expect(find.text(sv.adminGuestListLoadFailed), findsOneWidget);
    expect(find.text(sv.adminGuestListEmpty), findsNothing);
  });

  testWidgets('an expired invite stays listed and is marked utgången', (
    tester,
  ) async {
    final now = clock.now();
    final invitedAt = now.subtract(const Duration(days: 31));
    await pump(
      tester,
      _FakeRepo([
        SignupInvite(
          email: 'gammal@example.com',
          invitedAt: invitedAt,
          expireAt: now.subtract(const Duration(days: 1)),
        ),
        SignupInvite(
          email: 'ny@example.com',
          invitedAt: now,
          expireAt: now.add(const Duration(days: 30)),
        ),
      ]),
    );

    expect(find.text('gammal@example.com'), findsOneWidget);
    expect(
      find.text(
        '${invitedAt.day}/${invitedAt.month} · ${sv.adminGuestListExpired}',
      ),
      findsOneWidget,
    );
    expect(find.text('${now.day}/${now.month}'), findsOneWidget);
    expect(find.text(sv.adminGuestListRemove), findsNWidgets(2));
  });

  testWidgets('Ta bort removes only after the dialog is confirmed', (
    tester,
  ) async {
    final now = clock.now();
    final repo = _FakeRepo([
      SignupInvite(
        email: 'anna@example.com',
        invitedAt: now,
        expireAt: now.add(const Duration(days: 30)),
      ),
    ]);
    await pump(tester, repo);

    await tester.tap(find.text(sv.adminGuestListRemove));
    await tester.pumpAndSettle();
    expect(find.byType(DestructiveConfirmationDialog), findsOneWidget);
    expect(
      find.text(sv.adminGuestListRemoveMessage('anna@example.com')),
      findsOneWidget,
    );

    await tester.tap(
      find.descendant(
        of: find.byType(DestructiveConfirmationDialog),
        matching: find.text(sv.adminGuestListRemove),
      ),
    );
    await tester.pumpAndSettle();

    expect(repo.removed, ['anna@example.com']);
    expect(find.text('anna@example.com'), findsNothing);
    expect(find.text(sv.adminGuestListEmpty), findsOneWidget);
  });

  testWidgets('cancelling the dialog keeps the invite', (tester) async {
    final now = clock.now();
    final repo = _FakeRepo([
      SignupInvite(
        email: 'anna@example.com',
        invitedAt: now,
        expireAt: now.add(const Duration(days: 30)),
      ),
    ]);
    await pump(tester, repo);

    await tester.tap(find.text(sv.adminGuestListRemove));
    await tester.pumpAndSettle();
    await tester.tapAt(const Offset(5, 5));
    await tester.pumpAndSettle();

    expect(repo.removed, isEmpty);
    expect(find.text('anna@example.com'), findsOneWidget);
  });

  testWidgets('a successful invite clears the field and lists the address', (
    tester,
  ) async {
    final repo = _FakeRepo();
    await pump(tester, repo);

    await tester.enterText(find.byType(TextField), ' Bo@Example.com ');
    await tester.tap(find.text(sv.adminGuestListInvite));
    await tester.pumpAndSettle();

    expect(repo.stored.keys, ['bo@example.com']);
    expect(find.text('bo@example.com'), findsOneWidget);
    expect(
      tester.widget<TextField>(find.byType(TextField)).controller!.text,
      isEmpty,
    );
  });
}
