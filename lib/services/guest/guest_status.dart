import 'package:butlery/services/auth_service.dart';

extension GuestStatus on AuthService {
  /// A guest is a Firebase anonymous user. Nobody is one until sign-in as a
  /// guest ships, so every guest surface stays hidden until then.
  bool get isGuest => currentUser?.isAnonymous ?? false;
}
