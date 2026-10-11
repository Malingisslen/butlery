import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/user_service.dart';

/// BUT-1400: records that [uid] accepted the current terms, at the moment the
/// account is made: a sign-up, a guest start or a guest becoming an account
/// (BUT-920). Best-effort: a failure is logged and swallowed, because this
/// record must never block a sign-up.
Future<void> recordTermsAcceptance(
  UserRepository repository,
  String uid,
) async {
  try {
    await repository.recordTermsAcceptance(
      uid,
      UserService.currentTermsVersion,
    );
  } catch (e) {
    AppLogger.warning('⚠️ Kunde inte registrera villkorsgodkännande: $e');
  }
}
