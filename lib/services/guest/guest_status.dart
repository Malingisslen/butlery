import 'package:butlery/services/auth_service.dart';

extension GuestStatus on AuthService {
  /// A guest is a Firebase anonymous user: "Prova utan konto" signs one in,
  /// and linking an e-mail makes it an account with the same uid.
  bool get isGuest => currentUser?.isAnonymous ?? false;
}
