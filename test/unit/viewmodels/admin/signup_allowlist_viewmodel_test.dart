/// The guest-list tab's ViewModel (BUT-2452): an address is normalised the way
/// the blocking function looks it up before anything is written, a bad or
/// duplicate address never reaches the repository as a write, and a refused or
/// offline write leaves the list on screen with a message under the field.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/models/admin/signup_invite.dart';
import 'package:butlery/repositories/interfaces/signup_allowlist_repository.dart';
import 'package:butlery/viewmodels/admin/signup_allowlist_viewmodel.dart';

import '../../../test_support/base_unit_test.dart';

class _FakeRepo implements SignupAllowlistRepository {
  final Map<String, SignupInvite> stored = {};
  final List<String> invited = [];
  final List<String> removed = [];
  Object? listError;
  Object? writeError;

  @override
  Future<List<SignupInvite>> listInvites() async {
    if (listError != null) throw listError!;
    return stored.values.toList();
  }

  @override
  Future<void> invite(String email) async {
    if (writeError != null) throw writeError!;
    if (stored.containsKey(email)) throw const SignupInviteExistsException();
    invited.add(email);
    stored[email] = SignupInvite(
      email: email,
      invitedAt: DateTime(2026, 10, 24),
    );
  }

  @override
  Future<void> remove(String email) async {
    if (writeError != null) throw writeError!;
    removed.add(email);
    stored.remove(email);
  }
}

void main() {
  setUpAll(() async {
    await BaseUnitTest.setupUnit();
  });

  late _FakeRepo repo;
  late SignupAllowlistViewModel vm;

  setUp(() {
    repo = _FakeRepo();
    vm = SignupAllowlistViewModel(repository: repo);
  });

  tearDown(() => vm.dispose());

  group('invite', () {
    test(
      'normalises before the write: trims and lower-cases, keeps plus-tags and dots',
      () async {
        final ok = await vm.invite('  Anna.B+Test@Example.COM ');
        expect(ok, isTrue);
        expect(repo.invited, ['anna.b+test@example.com']);
        expect(vm.invites.map((i) => i.email), ['anna.b+test@example.com']);
        expect(vm.actionError, isNull);
      },
    );

    test('a non-address is refused without a write', () async {
      for (final bad in [
        '',
        'anna',
        'anna@example',
        'an na@example.com',
        'a/b@example.com',
      ]) {
        expect(await vm.invite(bad), isFalse, reason: bad);
      }
      expect(repo.invited, isEmpty);
      expect(vm.actionError, AppLocale.current.adminGuestListInvalidEmail);
    });

    test('an address over 254 characters is refused without a write', () async {
      final long = '${'a' * 250}@example.com';
      expect(await vm.invite(long), isFalse);
      expect(repo.invited, isEmpty);
    });

    test('a duplicate shows its own message and keeps the list', () async {
      await vm.invite('anna@example.com');
      expect(await vm.invite('ANNA@example.com'), isFalse);
      expect(vm.actionError, AppLocale.current.adminGuestListDuplicate);
      expect(vm.invites, hasLength(1));
    });

    test('permission-denied shows the save error and keeps the list', () async {
      await vm.invite('anna@example.com');
      repo.writeError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(await vm.invite('bo@example.com'), isFalse);
      expect(vm.actionError, AppLocale.current.adminGuestListSaveFailed);
      expect(vm.invites.map((i) => i.email), ['anna@example.com']);
      expect(vm.isSubmitting, isFalse);
    });

    test('offline shows the network message', () async {
      repo.writeError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      expect(await vm.invite('bo@example.com'), isFalse);
      expect(vm.actionError, AppLocale.current.errorNetwork);
    });

    test(
      'a non-Firebase failure still ends in the save error, not a throw',
      () async {
        repo.writeError = StateError('signed out');
        expect(await vm.invite('bo@example.com'), isFalse);
        expect(vm.actionError, AppLocale.current.adminGuestListSaveFailed);
      },
    );
  });

  group('remove', () {
    test('removes the entry from the store and the list', () async {
      await vm.invite('anna@example.com');
      await vm.invite('bo@example.com');
      expect(await vm.remove('anna@example.com'), isTrue);
      expect(repo.removed, ['anna@example.com']);
      expect(vm.invites.map((i) => i.email), ['bo@example.com']);
    });

    test('a refused removal keeps the row', () async {
      await vm.invite('anna@example.com');
      repo.writeError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      expect(await vm.remove('anna@example.com'), isFalse);
      expect(vm.invites, hasLength(1));
      expect(vm.actionError, AppLocale.current.adminGuestListSaveFailed);
    });
  });

  group('load', () {
    test('a failed load sets the error state', () async {
      repo.listError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'permission-denied',
      );
      await vm.load();
      expect(vm.error, AppLocale.current.adminGuestListLoadFailed);
      expect(vm.invites, isEmpty);
    });

    test('an offline load says so', () async {
      repo.listError = FirebaseException(
        plugin: 'cloud_firestore',
        code: 'unavailable',
      );
      await vm.load();
      expect(vm.error, AppLocale.current.errorNetwork);
    });
  });
}
