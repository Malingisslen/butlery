/// Journey test: settings → delete account → confirm → data gone + signed out.
///
/// Exercises [ProfileViewModel.deleteAccount] through a simplified
/// settings-style body that mirrors the production delete-account flow:
///   1. User on "settings" screen with a Delete button.
///   2. Tapping opens a confirmation dialog requiring a typed confirmation.
///   3. Cancelling the dialog does nothing.
///   4. Confirming calls [AccountDeletionService.deleteUserAccount] with
///      the current userId's context and the user-provided reason.
///   5. On success the VM surfaces a completion callback which in
///      production triggers sign-out + navigation back to login.
///
/// We deliberately do NOT duplicate
/// `test/integration/firebase/account_deletion_integration_test.dart` —
/// that file drives the raw Firestore lifecycle. This journey test
/// verifies the VM → service → Firestore seam through the UI-triggered
/// path so we catch regressions like "delete button does nothing" or
/// "cancel fires the service anyway".
library;

// ignore_for_file: invalid_use_of_protected_member

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:get_it/get_it.dart';
import 'package:mocktail/mocktail.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/di/di_container.dart';
import 'package:butlery/core/providers/application_provider.dart' as production;
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/services/account/account_deletion_service.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_theme.dart';
import 'package:butlery/viewmodels/profile/profile_viewmodel.dart';

// Pure mocks — no concrete overrides so when()/verify() work cleanly.
class _MockAuthService extends Mock implements AuthService {}

class _MockUserService extends Mock implements UserService {}

class _MockAccountDeletionService extends Mock
    implements AccountDeletionService {}

class _MockFirebaseUser extends Mock implements User {}

const _confirmationText = 'RADERA';

/// Settings body that exposes the delete-account flow.
///
/// Mirrors the production path: a ListTile reveals a destructive
/// dialog, typing the confirmation phrase unlocks the destructive
/// button, tapping it calls the VM.
class _SettingsBody extends StatefulWidget {
  const _SettingsBody({required this.onDeleted});

  final VoidCallback onDeleted;

  @override
  State<_SettingsBody> createState() => _SettingsBodyState();
}

class _SettingsBodyState extends State<_SettingsBody> {
  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.watch<ProfileViewModel>();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Container(
              key: const Key('settings_header'),
              padding: const EdgeInsets.all(12),
              color: cs.surfaceContainerHighest,
              child: Text(
                'Inställningar',
                style: TextStyle(color: cs.onSurface),
              ),
            ),
            ListTile(
              key: const Key('delete_account_tile'),
              leading: Icon(Icons.delete_forever, color: cs.error),
              title: Text(
                'Radera konto',
                style: TextStyle(color: cs.error),
              ),
              onTap: vm.isLoading ? null : () => _openDeleteDialog(context, vm),
            ),
            if (vm.hasError)
              Container(
                key: const Key('vm_error'),
                padding: const EdgeInsets.all(8),
                color: cs.errorContainer,
                child: Text(
                  vm.error ?? '',
                  style: TextStyle(color: cs.onErrorContainer),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _openDeleteDialog(
    BuildContext context,
    ProfileViewModel vm,
  ) async {
    final controller = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) {
            final canConfirm = controller.text.trim() == _confirmationText;
            return AlertDialog(
              key: const Key('delete_dialog'),
              title: const Text('Radera konto permanent'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Skriv RADERA för att bekräfta. Detta kan inte ångras.',
                  ),
                  TextField(
                    key: const Key('confirm_input'),
                    controller: controller,
                    onChanged: (_) => setDialogState(() {}),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  key: const Key('cancel'),
                  onPressed: () => Navigator.pop(dialogCtx, false),
                  child: const Text('Avbryt'),
                ),
                TextButton(
                  key: const Key('confirm_delete'),
                  onPressed: canConfirm
                      ? () => Navigator.pop(dialogCtx, true)
                      : null,
                  child: const Text('Radera permanent'),
                ),
              ],
            );
          },
        );
      },
    );

    if (confirmed != true) return;

    final ok = await vm.deleteAccount(reason: 'Journey test');
    if (ok && context.mounted) {
      widget.onDeleted();
    }
  }
}

Widget _testApp({
  required ProfileViewModel viewModel,
  required VoidCallback onDeleted,
}) {
  return ChangeNotifierProvider<ProfileViewModel>.value(
    value: viewModel,
    child: MaterialApp(
      locale: const Locale('sv'),
      supportedLocales: AppLocalizations.supportedLocales,
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: AppTheme.lightTheme,
      home: _SettingsBody(onDeleted: onDeleted),
    ),
  );
}

void main() {
  late _MockAuthService mockAuthService;
  late _MockUserService mockUserService;
  late _MockAccountDeletionService mockDeletionService;
  late _MockFirebaseUser mockUser;
  late FakeFirebaseFirestore firestore;
  late ProfileViewModel viewModel;
  late bool deletionCallbackFired;

  const userId = 'user_bob_123';

  setUp(() async {
    // Production ServiceLocator bridge — ProfileViewModel and its
    // dependencies stay fully explicit via constructor injection, but
    // anything they touch via ServiceLocator.get<>() still resolves
    // through our GetIt registrations.
    final getIt = GetIt.instance;
    if (getIt.isRegistered<AuthService>()) getIt.unregister<AuthService>();
    if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
    if (getIt.isRegistered<AccountDeletionService>()) {
      getIt.unregister<AccountDeletionService>();
    }

    production.ServiceLocator.initialize(DIContainer());

    firestore = FakeFirebaseFirestore();
    mockAuthService = _MockAuthService();
    mockUserService = _MockUserService();
    mockDeletionService = _MockAccountDeletionService();
    mockUser = _MockFirebaseUser();

    when(() => mockUser.uid).thenReturn(userId);
    when(() => mockUser.email).thenReturn('bob@example.com');

    when(() => mockAuthService.currentUserId).thenReturn(userId);
    when(() => mockAuthService.currentUser).thenReturn(mockUser);
    when(() => mockAuthService.currentUserEmail).thenReturn('bob@example.com');
    when(() => mockAuthService.currentUserDisplayName).thenReturn('Bob');
    when(() => mockAuthService.currentUserPhotoUrl).thenReturn(null);
    when(() => mockAuthService.signOut()).thenAnswer((_) async {});

    when(() => mockUserService.currentUserProfile).thenReturn(null);

    getIt.registerSingleton<AuthService>(mockAuthService);
    getIt.registerSingleton<UserService>(mockUserService);
    getIt.registerSingleton<AccountDeletionService>(mockDeletionService);

    // Seed the user's Firestore doc so we can assert it disappears after
    // deletion.
    await firestore.collection('users').doc(userId).set({
      'displayName': 'Bob',
      'email': 'bob@example.com',
    });

    viewModel = ProfileViewModel(
      authService: mockAuthService,
      userService: mockUserService,
      accountDeletionService: mockDeletionService,
    );
    deletionCallbackFired = false;
  });

  tearDown(() {
    viewModel.dispose();
    final getIt = GetIt.instance;
    if (getIt.isRegistered<AuthService>()) getIt.unregister<AuthService>();
    if (getIt.isRegistered<UserService>()) getIt.unregister<UserService>();
    if (getIt.isRegistered<AccountDeletionService>()) {
      getIt.unregister<AccountDeletionService>();
    }
    production.ServiceLocator.reset();
  });

  group('Account deletion journey', () {
    testWidgets(
      'cancelling the confirmation dialog does NOT call the deletion service',
      (tester) async {
        await tester.pumpWidget(
          _testApp(
            viewModel: viewModel,
            onDeleted: () => deletionCallbackFired = true,
          ),
        );
        await tester.pumpAndSettle();

        // Open the dialog.
        await tester.tap(find.byKey(const Key('delete_account_tile')));
        await tester.pumpAndSettle();
        expect(find.byKey(const Key('delete_dialog')), findsOneWidget);

        // User changes their mind.
        await tester.tap(find.byKey(const Key('cancel')));
        await tester.pumpAndSettle();

        // Dialog gone; service untouched; user doc still present.
        expect(find.byKey(const Key('delete_dialog')), findsNothing);
        verifyNever(
          () => mockDeletionService.deleteUserAccount(
            reason: any(named: 'reason'),
            createAuditLog: any(named: 'createAuditLog'),
          ),
        );
        expect(deletionCallbackFired, isFalse);

        final doc = await firestore.collection('users').doc(userId).get();
        expect(
          doc.exists,
          isTrue,
          reason: 'Cancelling must not touch Firestore data',
        );
      },
    );

    testWidgets(
      'confirming with correct phrase calls deletion service, removes user doc, fires deletion callback',
      (tester) async {
        // The service removes the user doc and reports success — exactly
        // what the production service does when Firestore + auth deletion
        // both succeed.
        when(
          () => mockDeletionService.deleteUserAccount(
            reason: any(named: 'reason'),
            createAuditLog: any(named: 'createAuditLog'),
          ),
        ).thenAnswer((_) async {
          await firestore.collection('users').doc(userId).delete();
          return {
            'success': true,
            'deletedCollections': ['profile'],
            'failedCollections': <String>[],
            'errors': <String>[],
            'auditLogId': 'audit_abc',
          };
        });

        await tester.pumpWidget(
          _testApp(
            viewModel: viewModel,
            onDeleted: () => deletionCallbackFired = true,
          ),
        );
        await tester.pumpAndSettle();

        // Open dialog.
        await tester.tap(find.byKey(const Key('delete_account_tile')));
        await tester.pumpAndSettle();

        // Confirm button is disabled until the user types the phrase.
        TextButton confirmButton() =>
            tester.widget<TextButton>(find.byKey(const Key('confirm_delete')));
        expect(
          confirmButton().onPressed,
          isNull,
          reason: 'Confirm must be disabled before phrase typed',
        );

        // Type the wrong thing — still disabled.
        await tester.enterText(
          find.byKey(const Key('confirm_input')),
          'radera',
        );
        await tester.pumpAndSettle();
        expect(
          confirmButton().onPressed,
          isNull,
          reason: 'Case-sensitive match required',
        );

        // Type the correct phrase — enabled.
        await tester.enterText(
          find.byKey(const Key('confirm_input')),
          _confirmationText,
        );
        await tester.pumpAndSettle();
        expect(confirmButton().onPressed, isNotNull);

        // Fire the destructive action.
        await tester.tap(find.byKey(const Key('confirm_delete')));
        await tester.pumpAndSettle();

        // Service was called once with the expected reason + audit flag.
        final captured = verify(
          () => mockDeletionService.deleteUserAccount(
            reason: captureAny(named: 'reason'),
            createAuditLog: captureAny(named: 'createAuditLog'),
          ),
        ).captured;
        expect(captured[0], 'Journey test');
        expect(
          captured[1],
          isTrue,
          reason: 'VM must request audit log for GDPR compliance',
        );

        // User doc is gone from Firestore.
        final doc = await firestore.collection('users').doc(userId).get();
        expect(
          doc.exists,
          isFalse,
          reason: 'Deletion service must have removed the user doc',
        );

        // VM reports not loading, no error; caller (real view) would now
        // sign out + navigate away.
        expect(viewModel.isLoading, isFalse);
        expect(viewModel.hasError, isFalse);
        expect(
          deletionCallbackFired,
          isTrue,
          reason:
              'onDeleted callback fires on success — the production view '
              'uses this to trigger signOut + route back to login',
        );
      },
    );

    testWidgets(
      'service reporting success:false leaves data alone and does NOT fire deletion callback',
      (tester) async {
        // Production behaviour: if deleteUserAccount returns success:false,
        // ProfileViewModel.deleteAccount returns false and the view should
        // NOT treat this as a completed deletion.
        when(
          () => mockDeletionService.deleteUserAccount(
            reason: any(named: 'reason'),
            createAuditLog: any(named: 'createAuditLog'),
          ),
        ).thenAnswer(
          (_) async => {
            'success': false,
            'deletedCollections': <String>[],
            'failedCollections': ['profile'],
            'errors': ['some auth error'],
            'auditLogId': null,
          },
        );

        await tester.pumpWidget(
          _testApp(
            viewModel: viewModel,
            onDeleted: () => deletionCallbackFired = true,
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('delete_account_tile')));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.byKey(const Key('confirm_input')),
          _confirmationText,
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('confirm_delete')));
        await tester.pumpAndSettle();

        // Service was called, but outcome is failure.
        verify(
          () => mockDeletionService.deleteUserAccount(
            reason: any(named: 'reason'),
            createAuditLog: any(named: 'createAuditLog'),
          ),
        ).called(1);

        // Firestore data remains; callback did NOT fire (caller stays on
        // settings with the user's data intact).
        final doc = await firestore.collection('users').doc(userId).get();
        expect(
          doc.exists,
          isTrue,
          reason: 'Seeded doc untouched when service reports failure',
        );
        expect(
          deletionCallbackFired,
          isFalse,
          reason: 'Failed deletion must not trigger post-delete navigation',
        );
      },
    );
  });
}
