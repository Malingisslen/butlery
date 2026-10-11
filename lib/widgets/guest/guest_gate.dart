import 'package:flutter/widgets.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/services/guest/guest_status.dart';
import 'package:butlery/widgets/guest/guest_account_sheet.dart';

/// For an action that needs an account: when the current user is a guest, opens
/// the sheet for [reason] and returns true, and the caller stops there.
bool offerAccountIfGuest(BuildContext context, GuestAccountReason reason) {
  if (!(ServiceLocator.tryGet<AuthService>()?.isGuest ?? false)) return false;
  showGuestAccountSheet(context, reason);
  return true;
}
