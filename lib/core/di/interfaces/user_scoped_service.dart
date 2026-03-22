/// Marker interface for services that hold user-specific state.
///
/// Services implementing this are registered in the GetIt user-session scope
/// and automatically disposed on logout via [popUserScope].
abstract class UserScopedService {
  /// Clear all user-specific state. Called automatically when the user
  /// session scope is popped (logout). Implementations should cancel
  /// subscriptions, clear caches, and reset initialization flags.
  void resetForLogout();
}
