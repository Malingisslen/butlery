import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/repositories/interfaces/user_repository.dart';
import 'package:butlery/services/auth/sessions_revoked_notice.dart';
import 'package:butlery/utils/shared_preferences_safe.dart';

/// BUT-2481: after signing in again, says once that the owner's other devices
/// were signed out. One read of the profile document per sign-in on this
/// device. Never throws.
Future<void> showSessionsRevokedNoticeIfDue(BuildContext context) async {
  try {
    final auth = ServiceLocator.tryGet<AuthRepository>();
    final users = ServiceLocator.tryGet<UserRepository>();
    final user = auth?.currentUser;
    if (auth == null || users == null || user == null) return;
    final lastSignIn = user.metadata.lastSignInTime;
    final prefs = await tryGetSharedPreferences(logTag: 'SessionsRevoked');
    if (prefs == null) return;
    final notice = SessionsRevokedNotice(prefs: prefs);
    if (!notice.needsCheck(lastSignIn)) return;
    final revokedAt = await users.fetchSessionsRevokedAt(user.uid);
    await notice.markChecked(lastSignIn!);
    final when = await notice.due(revokedAt);
    if (when == null || !context.mounted) return;
    final l10n = context.l10n;
    final date = DateFormat.MMMd(l10n.localeName).format(when.toLocal());
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.settingsSignOutEverywhereTitle),
        content: Text(l10n.signOutEverywhereNotice(date)),
        actions: [
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: Text(l10n.commonClose),
          ),
        ],
      ),
    );
  } catch (e) {
    AppLogger.warning('SessionsRevoked: skipped (${e.runtimeType})');
  }
}
