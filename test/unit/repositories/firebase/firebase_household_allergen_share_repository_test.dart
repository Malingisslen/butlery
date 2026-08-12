/// Unit tests for FirebaseHouseholdAllergenShareRepository (BUT-1693).
///
/// Pure-Dart; FakeFirebaseFirestore with a REAL FirebaseHouseholdRepository
/// wired to the same store, so membership checks run end-to-end. Focus:
/// (1) a share is only ever written by the member it describes, under a valid
/// Art. 9 consent; (2) reads are scoped to household membership; (3) a share
/// without intact consent is not a declaration and never reaches a caller —
/// that member keeps BUT-1663's safety floor.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:fake_cloud_firestore/fake_cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/exceptions/permission_exceptions.dart';
import 'package:butlery/models/household.dart';
import 'package:butlery/models/household_allergen_share.dart';
import 'package:butlery/repositories/firebase/firebase_household_allergen_share_repository.dart';
import 'package:butlery/repositories/firebase/firebase_household_repository.dart';

import '../../../infrastructure/mocks/production_mocks.dart';

const _malin = 'user-malin';
const _johan = 'user-johan';
const _stranger = 'user-stranger';
const _householdId = 'hh-1';
const _otherHouseholdId = 'hh-2';

FirebaseHouseholdAllergenShareRepository _repo(
  FakeFirebaseFirestore fs, {
  String authedUserId = _malin,
}) {
  final mockAuth = FakeAuthRepository();
  mockAuth.setAuthState(
    user: FakeUser(uid: authedUserId),
    userId: authedUserId,
    isAuthenticated: true,
  );
  return FirebaseHouseholdAllergenShareRepository(
    firestore: fs,
    authRepository: mockAuth,
    householdRepository: FirebaseHouseholdRepository(
      firestore: fs,
      authRepository: mockAuth,
    ),
  );
}

Future<void> _seedHousehold(
  FakeFirebaseFirestore fs, {
  List<String> members = const [_malin, _johan],
}) {
  final hh = Household(
    id: _householdId,
    name: Household.defaultName,
    members: [
      for (final userId in members)
        HouseholdMember(
          userId: userId,
          permission: userId == _malin
              ? SharedListPermission.admin
              : SharedListPermission.edit,
          addedAt: DateTime.utc(2026, 1, 1),
        ),
    ],
    createdBy: _malin,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
  return fs.collection('households').doc(hh.id).set(hh.toFirestore());
}

/// A second household Malin also belongs to, so a household-scoping test can
/// hold the owner constant and vary only the household.
Future<void> _seedOtherHousehold(FakeFirebaseFirestore fs) {
  final hh = Household(
    id: _otherHouseholdId,
    name: Household.defaultName,
    members: [
      HouseholdMember(
        userId: _malin,
        permission: SharedListPermission.admin,
        addedAt: DateTime.utc(2026, 1, 1),
      ),
    ],
    createdBy: _malin,
    createdAt: DateTime.utc(2026, 1, 1),
    updatedAt: DateTime.utc(2026, 1, 1),
  );
  return fs.collection('households').doc(hh.id).set(hh.toFirestore());
}

HouseholdAllergenShare _share({
  String userId = _malin,
  String householdId = _householdId,
  Set<String> allergens = const {'ägg'},
  Set<String> dietary = const {},
  bool consentGranted = true,
  String consentVersion = HouseholdAllergenShare.currentConsentVersion,
  // A plain nullable parameter cannot express "no timestamp": `?? default`
  // would swallow it and the test would pass vacuously.
  bool withConsentTimestamp = true,
  DateTime? grantedAt,
}) => HouseholdAllergenShare(
  householdId: householdId,
  userId: userId,
  trackedAllergens: allergens,
  trackedDietary: dietary,
  includeUnknownInMenu: true,
  consentGranted: consentGranted,
  consentVersion: consentVersion,
  consentGrantedAt: withConsentTimestamp
      ? (grantedAt ?? DateTime.utc(2026, 8, 12))
      : null,
  updatedAt: DateTime.utc(2026, 8, 12),
);

void main() {
  group('FirebaseHouseholdAllergenShareRepository', () {
    late FakeFirebaseFirestore fs;

    setUp(() async {
      fs = FakeFirebaseFirestore();
      await _seedHousehold(fs);
    });

    group('writing is a self-declaration under consent', () {
      test('a member can share their own list', () async {
        final created = await _repo(fs).create(_share());

        expect(created.id, '${_householdId}_$_malin');
        final stored = await fs
            .collection('household_allergen_shares')
            .doc(created.id)
            .get();
        expect(stored.exists, isTrue);
        expect(stored.data()!['userId'], _malin);
        expect(stored.data()!['trackedAllergens'], ['ägg']);
      });

      test('writing a share that describes SOMEONE ELSE is refused', () async {
        // Malin is signed in; the payload claims to be Johan's list. Both are
        // members of the same household, so only ownership stops this.
        expect(
          () => _repo(fs).create(_share(userId: _johan)),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test('writing without consent is refused', () async {
        expect(
          () => _repo(fs).create(_share(consentGranted: false)),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test('writing with a consent record but no timestamp is refused', () {
        // An unreadable timestamp is not a consent record; Art. 7(1) needs to
        // show WHEN it was given.
        expect(
          () => _repo(fs).create(_share(withConsentTimestamp: false)),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test(
        'a member cannot point their share at a household they are not in',
        () async {
          expect(
            await _repo(
              fs,
            ).validateCreatePermission(_malin, _share(householdId: 'hh-999')),
            isFalse,
          );
        },
      );

      test(
        'a second create cannot overwrite an existing share, so the consent '
        'record cannot be re-dated by a save flow',
        () async {
          final repo = _repo(fs);
          await repo.create(_share());

          await expectLater(
            repo.create(_share(grantedAt: DateTime.utc(2030, 1, 1))),
            throwsA(isA<ValidationException>()),
          );

          final stored = await fs
              .collection('household_allergen_shares')
              .doc('${_householdId}_$_malin')
              .get();
          expect(
            (stored.data()!['consentGrantedAt'] as Timestamp).toDate().toUtc(),
            DateTime.utc(2026, 8, 12),
          );
        },
      );

      test('a grant under an outdated consent version is refused', () async {
        expect(
          () => _repo(fs).create(_share(consentVersion: 'v0-old-wording')),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test(
        'an edit is refused when the STORED record carries no valid consent',
        () async {
          final repo = _repo(fs);
          await repo.create(_share());
          await fs
              .collection('household_allergen_shares')
              .doc('${_householdId}_$_malin')
              .update({'consentGranted': false});

          // Otherwise fresh Art. 9 data lands under a non-consent record —
          // never read back, but stored, which is the part that matters.
          await expectLater(
            repo.update(_share(allergens: {'skaldjur'})),
            throwsA(isA<PermissionDeniedException>()),
          );
        },
      );

      test('createBatch applies the same guard as create', () async {
        expect(
          () => _repo(fs).createBatch([_share(), _share(userId: _johan)]),
          throwsA(isA<SecurityViolationException>()),
        );
      });

      test(
        'an edit cannot re-point an existing share at another household',
        () async {
          final repo = _repo(fs);
          final created = await repo.create(_share());

          expect(
            await repo.validateUpdatePermission(
              _malin,
              created.id,
              _share(householdId: _otherHouseholdId),
            ),
            isFalse,
          );
        },
      );

      test('an edit drops a stale key the current writer never emits', () async {
        // `set()` over `update()` is what makes this true. Asserting only that
        // a retracted allergen disappears would be vacuous — toFirestore emits
        // a fixed key set, so a merge would replace that array too.
        final repo = _repo(fs);
        await repo.create(_share(allergens: {'ägg', 'skaldjur'}));
        await fs
            .collection('household_allergen_shares')
            .doc('${_householdId}_$_malin')
            .update({'legacyField': 'left over from an older writer'});

        await repo.update(_share(allergens: {'ägg'}));

        final stored = await fs
            .collection('household_allergen_shares')
            .doc('${_householdId}_$_malin')
            .get();
        expect(stored.data()!['trackedAllergens'], ['ägg']);
        expect(
          stored.data()!.containsKey('legacyField'),
          isFalse,
          reason: 'a full overwrite leaves nothing of the old document behind',
        );
      });

      test('an edit cannot re-date or re-version the consent record', () async {
        // The Art. 7(1) evidence. An ordinary preference edit carries the
        // STORED consent forward; only a fresh grant may write it.
        final repo = _repo(fs);
        await repo.create(_share());

        await repo.update(
          _share(
            allergens: {'ägg', 'skaldjur'},
            consentVersion: 'v99-from-a-stale-client',
          ),
        );

        final stored = await fs
            .collection('household_allergen_shares')
            .doc('${_householdId}_$_malin')
            .get();
        expect(stored.data()!['consentVersion'], 'v1');
        expect(
          (stored.data()!['consentGrantedAt'] as Timestamp).toDate().toUtc(),
          DateTime.utc(2026, 8, 12),
        );
        expect(stored.data()!['trackedAllergens'], containsAll(['skaldjur']));
      });
    });

    group('reading is scoped to household membership', () {
      test('a household member reads every valid share in it', () async {
        await _repo(fs).create(_share());
        await _repo(fs, authedUserId: _johan).create(_share(userId: _johan));

        final shares = await _repo(
          fs,
          authedUserId: _johan,
        ).getByHousehold(_householdId);

        expect(shares.map((s) => s.userId), containsAll([_malin, _johan]));
      });

      test('a non-member reads nothing', () async {
        await _repo(fs).create(_share());

        expect(
          await _repo(
            fs,
            authedUserId: _stranger,
          ).getByHousehold(_householdId),
          isEmpty,
        );
      });

      test(
        'a share whose consent was revoked in place is not returned',
        () async {
          await _repo(fs).create(_share());
          // Simulate a document left behind with consentGranted flipped off.
          await fs
              .collection('household_allergen_shares')
              .doc('${_householdId}_$_malin')
              .update({'consentGranted': false});

          expect(await _repo(fs).getByHousehold(_householdId), isEmpty);
          expect(await _repo(fs).getOwn(_householdId), isNull);
        },
      );

      test('getOwn returns null when the member has not shared', () async {
        expect(await _repo(fs).getOwn(_householdId), isNull);
      });

      test('getOwn returns the member their own share', () async {
        // The positive half. Without it, `getOwn` could `return null`
        // unconditionally and the suite would stay green — while every member
        // in the app looked like they had never shared.
        final repo = _repo(fs);
        await repo.create(_share(allergens: {'ägg', 'skaldjur'}));

        final own = await repo.getOwn(_householdId);

        expect(own, isNotNull);
        expect(own!.userId, _malin);
        expect(own.trackedAllergens, {'ägg', 'skaldjur'});
      });

      test('the query is scoped to the household it was asked for', () async {
        // Same owner in both households, so neither the roster filter nor the
        // consent filter can be what excludes the other one — only the
        // householdId query can.
        await _seedOtherHousehold(fs);
        final repo = _repo(fs);
        await repo.create(_share());
        await repo.create(
          _share(householdId: _otherHouseholdId, allergens: {'selleri'}),
        );

        final shares = await repo.getByHousehold(_householdId);

        expect(shares, hasLength(1));
        expect(shares.single.trackedAllergens, {'ägg'});
      });

      test(
        'a document whose body claims a DIFFERENT member than its path is '
        'skipped, and does not take the household down with it',
        () async {
          // The insider forgery: a row whose BODY names a peer, retiring that
          // peer's safety floor with a list they never declared. The client
          // guard refuses to write one; this proves a row that reached storage
          // some other way is not believed on the way out. The fixture sits at
          // `hh-1_forged`, which is nobody's own path — the mechanism under
          // test is the body/path disagreement, whatever the path is.
          await _repo(fs).create(_share());
          await fs
              .collection('household_allergen_shares')
              .doc('${_householdId}_forged')
              .set(_share(userId: _johan).toFirestore());

          final shares = await _repo(fs).getByHousehold(_householdId);

          expect(shares.map((s) => s.userId), [_malin]);
        },
      );

      test(
        'a share left behind by someone who has LEFT the household stops '
        'filtering its menu',
        () async {
          await _repo(fs, authedUserId: _johan).create(_share(userId: _johan));
          // Johan leaves; his share document is still there. Re-seeded through
          // the model, because `memberUserIds` is a projection derived from
          // `members` — writing the projection alone would prove nothing.
          await _seedHousehold(fs, members: const [_malin]);

          final shares = await _repo(fs).getByHousehold(_householdId);

          expect(shares, isEmpty);
        },
      );
    });

    test(
      'read() does not hand back a share whose consent was withdrawn',
      () async {
        // The inherited single-document read is public too, and the class
        // contract says a share without valid consent must be treated exactly
        // like no share.
        final repo = _repo(fs);
        await repo.create(_share());
        await fs
            .collection('household_allergen_shares')
            .doc('${_householdId}_$_malin')
            .update({'consentGranted': false});

        expect(await repo.read('${_householdId}_$_malin'), isNull);
      },
    );

    test(
      'readCacheFirst applies the same consent filter as read()',
      () async {
        // The cache-first twin is public on Repository<T> as well, and it is
        // the half that ships untested: with its override deleted, read()
        // stays green while a withdrawn share is handed to a caller through
        // the cache path.
        final repo = _repo(fs);
        await repo.create(_share());
        await fs
            .collection('household_allergen_shares')
            .doc('${_householdId}_$_malin')
            .update({'consentGranted': false});

        expect(await repo.readCacheFirst('${_householdId}_$_malin'), isNull);
      },
    );

    test('readCacheFirst still returns a share with intact consent', () async {
      // The positive control. Without it the test above is also satisfied by
      // an override that returns null unconditionally.
      final repo = _repo(fs);
      await repo.create(_share());

      final own = await repo.readCacheFirst('${_householdId}_$_malin');

      expect(own?.trackedAllergens, {'ägg'});
    });

    test(
      'the inherited whole-collection reads are refused, not filtered',
      () async {
        // Both sweeps skip the consent filter and the roster check, and
        // watchAll runs no permission check at all — either override deleted
        // means one call reads every household's Art. 9 data. Seeded, so the
        // refusal cannot be mistaken for an empty collection.
        final repo = _repo(fs);
        await repo.create(_share());

        expect(() => repo.readAll(), throwsUnsupportedError);
        expect(() => repo.watchAll(), throwsUnsupportedError);
      },
    );

    group('withdrawal', () {
      test(
        'a corrupt or forged row at your OWN id is still erasable',
        () async {
          // Erasure is decided from the path, not the body. Reading the body
          // would hit the identity check, which throws — leaving the one
          // document a member most needs to delete undeletable (Art. 17).
          await fs
              .collection('household_allergen_shares')
              .doc('${_householdId}_$_malin')
              .set(_share(userId: _johan).toFirestore());

          await _repo(fs).revoke(_householdId);

          final stored = await fs
              .collection('household_allergen_shares')
              .doc('${_householdId}_$_malin')
              .get();
          expect(stored.exists, isFalse);
        },
      );

      test('revoke deletes the document', () async {
        final repo = _repo(fs);
        await repo.create(_share());

        await repo.revoke(_householdId);

        final stored = await fs
            .collection('household_allergen_shares')
            .doc('${_householdId}_$_malin')
            .get();
        expect(stored.exists, isFalse);
      });

      test(
        'an absent share can only be deleted at your OWN id, not someone '
        'else\'s',
        () async {
          // `delete(id)` is public on Repository<T>, and the decision is made
          // from the path alone — so it must bind the document to the caller
          // whether or not the document is there.
          final repo = _repo(fs);

          expect(
            await repo.validateDeletePermission(
              _malin,
              '${_householdId}_$_malin',
            ),
            isTrue,
            reason: 'withdrawal must stay idempotent',
          );
          expect(
            await repo.validateDeletePermission(
              _malin,
              '${_householdId}_$_johan',
            ),
            isFalse,
          );
        },
      );

      test(
        'a member removed from the household can no longer EDIT their share '
        'into it',
        () async {
          final repo = _repo(fs, authedUserId: _johan);
          await repo.create(_share(userId: _johan));
          await _seedHousehold(fs, members: const [_malin]);

          // Deleting their own share stays possible — that is the erasure
          // right — but writing new Art. 9 data into a household they have
          // left must not be.
          await expectLater(
            repo.update(_share(userId: _johan, allergens: {'selleri'})),
            throwsA(isA<PermissionDeniedException>()),
          );
        },
      );

      test(
        'a member removed from the household can still erase their own share',
        () async {
          // Delete is ownership-only ON PURPOSE, with no membership conjunct:
          // harmonising it with create/update would leave someone who has been
          // removed unable to erase their own Art. 9 data while the household
          // kept reading it. This is the test that fails if a later reader
          // "tidies" the asymmetry away.
          final repo = _repo(fs, authedUserId: _johan);
          await repo.create(_share(userId: _johan));
          await _seedHousehold(fs, members: const [_malin]);

          await repo.revoke(_householdId);

          final stored = await fs
              .collection('household_allergen_shares')
              .doc('${_householdId}_$_johan')
              .get();
          expect(stored.exists, isFalse);
        },
      );

      test('another member may not delete your share', () async {
        await _repo(fs).create(_share());

        expect(
          await _repo(fs, authedUserId: _johan).validateDeletePermission(
            _johan,
            '${_householdId}_$_malin',
          ),
          isFalse,
        );
      });
    });
  });
}
