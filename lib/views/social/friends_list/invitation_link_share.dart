// lib/views/social/friends_list/invitation_link_share.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/deep_link_service.dart';
import 'package:share_plus/share_plus.dart';
import 'package:uuid/uuid.dart';

class InvitationLinkShare {
  static Future<void> shareInvitationLink(
    BuildContext context,
    FriendsViewModel viewModel,
  ) async {
    final userId = viewModel.currentUserId;
    if (userId == null) return;
    await shareInvitationLinkForUser(context, userId);
  }

  /// Needs no FriendsViewModel, so any context can share the link.
  static Future<void> shareInvitationLinkForUser(
    BuildContext context,
    String userId,
  ) async {
    final subject = context.l10n.socialInviteSubject;
    try {
      final invitationId = const Uuid().v4();
      final url = DeepLinkService.generateFriendInvitationLink(
        invitationId: invitationId,
        fromUserId: userId,
      );
      await SharePlus.instance.share(ShareParams(text: url, subject: subject));
    } catch (e) {
      AppLogger.error('Failed to share invitation link', e);
      if (!context.mounted) return;
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.socialInviteLinkShareFailed,
      );
    }
  }

  static Future<void> copyInvitationLink(
    BuildContext context,
    FriendsViewModel viewModel,
  ) async {
    final userId = viewModel.currentUserId;
    if (userId == null) return;
    try {
      final invitationId = const Uuid().v4();
      final url = DeepLinkService.generateFriendInvitationLink(
        invitationId: invitationId,
        fromUserId: userId,
      );
      await Clipboard.setData(ClipboardData(text: url));
      if (!context.mounted) return;
      SnackBarUtils.showSuccess(context, context.l10n.commonLinkCopied);
    } catch (e) {
      AppLogger.error('Failed to copy invitation link', e);
      if (!context.mounted) return;
      SnackBarUtils.showFailure(
        context,
        what: context.l10n.socialInviteLinkCopyFailed,
      );
    }
  }
}
