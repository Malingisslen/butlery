import 'package:firebase_core/firebase_core.dart' show FirebaseException;

import 'package:butlery/core/l10n/app_locale.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/admin/signup_invite.dart';
import 'package:butlery/repositories/interfaces/signup_allowlist_repository.dart';
import 'package:butlery/viewmodels/base_viewmodel.dart';

/// ViewModel for the admin "Gästlista" tab (BUT-2452): who may create an
/// account while the guest-list gate is on.
///
/// Errors are logged without the address; an address is personal data and
/// the entry itself is its only copy.
class SignupAllowlistViewModel extends BaseViewModel {
  final SignupAllowlistRepository _repository;

  List<SignupInvite> _invites = const [];
  String? _actionError;
  bool _isSubmitting = false;

  SignupAllowlistViewModel({SignupAllowlistRepository? repository})
    : _repository =
          repository ?? ServiceLocator.get<SignupAllowlistRepository>();

  /// Entries, newest invite first.
  List<SignupInvite> get invites => _invites;

  /// What went wrong with the last invite or removal; shown under the field
  /// so the list stays visible.
  String? get actionError => _actionError;
  bool get isSubmitting => _isSubmitting;

  Future<void> load() async {
    var offline = false;
    final ok = await executeAsyncVoid(() async {
      try {
        _invites = await _repository.listInvites();
      } on FirebaseException catch (e) {
        offline = e.code == 'unavailable';
        rethrow;
      }
    }, errorPrefix: AppLocale.current.adminGuestListLoadFailed);
    if (!ok && offline) setError(AppLocale.current.errorNetwork);
  }

  Future<void> refresh() => load();

  /// Returns true when the address was added, so the view can clear the field.
  Future<bool> invite(String raw) async {
    final l = AppLocale.current;
    final email = normalizeInviteEmail(raw);
    if (email.length > 254 || !inviteEmailPattern.hasMatch(email)) {
      _setActionError(l.adminGuestListInvalidEmail);
      return false;
    }
    return _submit(() async {
      await _repository.invite(email);
      _invites = await _repository.listInvites();
    });
  }

  Future<bool> remove(String email) => _submit(() async {
    await _repository.remove(email);
    _invites = [
      for (final i in _invites)
        if (i.email != email) i,
    ];
  });

  Future<bool> _submit(Future<void> Function() op) async {
    if (_isSubmitting || isDisposed) return false;
    _isSubmitting = true;
    _actionError = null;
    notifyListeners();
    try {
      await op();
      return true;
    } on SignupInviteExistsException {
      _actionError = AppLocale.current.adminGuestListDuplicate;
      return false;
    } on FirebaseException catch (e) {
      AppLogger.warning('Guest list write failed: ${e.code}');
      _actionError = e.code == 'unavailable'
          ? AppLocale.current.errorNetwork
          : AppLocale.current.adminGuestListSaveFailed;
      return false;
    } catch (e) {
      AppLogger.warning('Guest list write failed: ${e.runtimeType}');
      _actionError = AppLocale.current.adminGuestListSaveFailed;
      return false;
    } finally {
      _isSubmitting = false;
      if (!isDisposed) notifyListeners();
    }
  }

  void _setActionError(String message) {
    _actionError = message;
    notifyListeners();
  }
}
