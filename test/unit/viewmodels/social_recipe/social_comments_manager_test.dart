/// BUT-1419: Comments maturity gate wired into SocialCommentsManager.
///
/// Mirrors the server `isAccountMatured()` Firestore-rule predicate on the
/// client so a fresh, unverified account gets a clear "verify your email"
/// message instead of an opaque permission-denied. These tests pin the
/// behavioral contract: an immature account is blocked BEFORE the backend is
/// touched, and a matured account posts normally.
///
/// The load-bearing assertion is `verifyNever(addComment)` in the blocked
/// case — it proves the guard fails CLOSED on the client (no backend write),
/// not merely that an error string was set. If the guard were removed from
/// `postComment`, that test would fail.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:butlery/l10n/app_localizations_sv.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/auth/account_maturity_helper.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/operations/social_recipe_operations.dart';
import 'package:butlery/viewmodels/social_recipe/social_comments_manager.dart';

import '../../../test_support/base_unit_test.dart';
import '../../../infrastructure/di/test_service_locator.dart';
import '../../../infrastructure/mocks/production_mocks.dart';

// ---------------------------------------------------------------------------
// Local mocks
//
// We deliberately do NOT use MockUnifiedRecipeService from production_mocks
// here: its `.social` getter is a hard-wired FakeSocialRecipeOperations whose
// `addComment` always returns a non-null id and cannot be verified/stubbed via
// mocktail. To assert `verifyNever(addComment)` and to stub the return id, we
// mock UnifiedRecipeService + SocialRecipeOperations directly.
// ---------------------------------------------------------------------------

class _MockRecipeService extends Mock implements UnifiedRecipeService {}

class _MockSocialOps extends Mock implements SocialRecipeOperations {}

class _MockUser extends Mock implements User {}

class _MockAuthRepository extends Mock implements AuthRepository {}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// An AccountMaturityHelper whose `now` is fixed so that a profile joined at
/// 2026-01-01T00:00 is either well within (not matured) or well outside
/// (matured) the 60-minute window.
AccountMaturityHelper _fixedHelper(bool matured) => AccountMaturityHelper(
  window: const Duration(minutes: 60),
  now: matured
      ? () =>
            DateTime.utc(2026, 1, 1, 2, 0) // 2h after joinedAt → matured
      : () => DateTime.utc(2026, 1, 1, 0, 30), // 30 min after → not matured
);

UserProfile _profile() => UserProfile(
  uid: 'test-user',
  displayName: 'Anna',
  email: 'anna@example.com',
  joinedAt: DateTime.utc(2026, 1, 1, 0, 0),
  lastActiveAt: DateTime.utc(2026, 1, 1, 0, 0),
);

/// An AuthRepository whose currentUser reports [emailVerified] (or no user).
AuthRepository _authRepo({bool? emailVerified}) {
  final repo = _MockAuthRepository();
  if (emailVerified == null) {
    when(() => repo.currentUser).thenReturn(null);
  } else {
    final user = _MockUser();
    when(() => user.emailVerified).thenReturn(emailVerified);
    when(() => repo.currentUser).thenReturn(user);
  }
  return repo;
}

void main() {
  setUpAll(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    await BaseUnitTest.setupUnit();
  });

  tearDownAll(() async {
    await BaseUnitTest.teardownUnit();
  });

  late _MockRecipeService recipeService;
  late _MockSocialOps social;

  setUp(() async {
    // The manager's constructor calls ServiceLocator.tryGet for optional
    // collaborators (content filter, friends). Initialize the test locator so
    // those resolve (or cleanly return null) rather than throwing.
    await TestServiceLocator.initialize();

    recipeService = _MockRecipeService();
    social = _MockSocialOps();
    when(() => recipeService.social).thenReturn(social);
    // Default happy-path stub; individual tests override as needed.
    when(
      () => social.addComment(
        recipeId: any(named: 'recipeId'),
        content: any(named: 'content'),
        parentCommentId: any(named: 'parentCommentId'),
        imageUrls: any(named: 'imageUrls'),
      ),
    ).thenAnswer((_) async => 'comment-1');
    when(
      () => social.getComments(
        recipeId: any(named: 'recipeId'),
        limit: any(named: 'limit'),
        before: any(named: 'before'),
        includeReplies: any(named: 'includeReplies'),
      ),
    ).thenAnswer((_) async => []);
  });

  tearDown(() async {
    BaseUnitTest.resetMocks();
    await TestServiceLocator.reset();
  });

  SocialCommentsManager buildManager({
    required bool matured,
    bool? emailVerified,
  }) {
    final userService = MockUserService();
    when(() => userService.currentUserProfile).thenReturn(_profile());
    return SocialCommentsManager(
      recipeService,
      maturityHelper: _fixedHelper(matured),
      userService: userService,
      authRepository: _authRepo(emailVerified: emailVerified),
    );
  }

  group('SocialCommentsManager.postComment — maturity gate (BUT-1419)', () {
    test(
      'immature account is blocked BEFORE the backend is touched',
      () async {
        // Intent: proves the client guard fails closed — a fresh (30-min-old),
        // unverified account must not reach addComment, and must surface the
        // localized "verify your email" message.
        final manager = buildManager(matured: false, emailVerified: false);
        manager.updateNewCommentText('en kommentar');

        await manager.postComment('recipe-1');

        // Load-bearing: no backend write happened.
        verifyNever(
          () => social.addComment(
            recipeId: any(named: 'recipeId'),
            content: any(named: 'content'),
            parentCommentId: any(named: 'parentCommentId'),
            imageUrls: any(named: 'imageUrls'),
          ),
        );
        // Message surfaced (assert against the l10n source of truth, not a
        // hardcoded Swedish literal, so a copy tweak won't break this test).
        expect(
          manager.commentsError,
          AppLocalizationsSv().newAccountSocialBlockedComment,
        );

        manager.dispose();
      },
    );

    test(
      'matured account (email verified) posts normally and clears text',
      () async {
        final manager = buildManager(matured: true, emailVerified: true);
        manager.updateNewCommentText('en kommentar');

        await manager.postComment('recipe-1');

        verify(
          () => social.addComment(
            recipeId: 'recipe-1',
            content: 'en kommentar',
            parentCommentId: any(named: 'parentCommentId'),
            imageUrls: any(named: 'imageUrls'),
          ),
        ).called(1);
        expect(
          manager.newCommentText,
          isEmpty,
          reason: 'a successful post clears the compose field',
        );
        expect(
          manager.commentsError,
          isNull,
          reason: 'the maturity block message must not be set on success',
        );

        manager.dispose();
      },
    );

    test(
      'matured by age alone (>60 min old, still unverified) posts normally',
      () async {
        // Domain invariant the happy-path email case would miss: the gate
        // opens on account AGE even when email is unverified. Uses a null
        // firebaseUser so only joinedAt vs the 60-min window decides.
        final manager = buildManager(matured: true, emailVerified: null);
        manager.updateNewCommentText('äldre konto');

        await manager.postComment('recipe-1');

        verify(
          () => social.addComment(
            recipeId: 'recipe-1',
            content: 'äldre konto',
            parentCommentId: any(named: 'parentCommentId'),
            imageUrls: any(named: 'imageUrls'),
          ),
        ).called(1);

        manager.dispose();
      },
    );
  });
}
