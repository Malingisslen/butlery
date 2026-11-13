import 'package:butlery/models/user_profile.dart';

/// The facade's own-profile state, handed to the parts [UserService] delegates
/// to. Every read and write goes back to the facade, so there is still one
/// profile, one cache and one ChangeNotifier that views listen to.
///
/// [userId] is the facade's `currentUserId` (PermissionService, the auth
/// source); [profile] is its `currentUserProfile`.
class OwnProfilePort {
  OwnProfilePort({
    required String? Function() userId,
    required UserProfile? Function() readProfile,
    required void Function(UserProfile?) writeProfile,
    required void Function(String userId, UserProfile profile) cacheProfile,
    required void Function() notifyListeners,
    required void Function(String message) setError,
    required void Function() clearError,
    required void Function(bool loading) setLoading,
    required bool Function() hasError,
    required void Function(bool pending) setTermsPending,
  }) : _userId = userId,
       _readProfile = readProfile,
       _writeProfile = writeProfile,
       _cacheProfile = cacheProfile,
       _notifyListeners = notifyListeners,
       _setError = setError,
       _clearError = clearError,
       _setLoading = setLoading,
       _hasError = hasError,
       _setTermsPending = setTermsPending;

  final String? Function() _userId;
  final UserProfile? Function() _readProfile;
  final void Function(UserProfile?) _writeProfile;
  final void Function(String, UserProfile) _cacheProfile;
  final void Function() _notifyListeners;
  final void Function(String) _setError;
  final void Function() _clearError;
  final void Function(bool) _setLoading;
  final bool Function() _hasError;
  final void Function(bool) _setTermsPending;

  String? get userId => _userId();
  UserProfile? get profile => _readProfile();
  set profile(UserProfile? value) => _writeProfile(value);
  bool get hasError => _hasError();
  void setTermsPending(bool value) => _setTermsPending(value);

  void cacheProfile(String userId, UserProfile profile) =>
      _cacheProfile(userId, profile);
  void notifyListeners() => _notifyListeners();
  void setError(String message) => _setError(message);
  void clearError() => _clearError();
  void setLoading(bool loading) => _setLoading(loading);
}
