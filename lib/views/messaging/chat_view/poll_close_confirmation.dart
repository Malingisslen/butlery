import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/common_dialog_actions.dart';
import 'package:butlery/models/messaging/poll.dart';

/// Asks before a poll is closed, naming who wins if it closes now.
///
/// Closing has no way back, so the creator sees the tally the close would
/// resolve on, not just a button that acts at once.
Future<bool> confirmPollClose(BuildContext context, Poll poll) async {
  final l10n = context.l10n;
  final leader = poll.leader;
  final tied = poll.tiedLeaders;
  final String message;
  if (leader == null) {
    message = l10n.pollCloseConfirmNoVotes;
  } else if (tied.length > 1) {
    message = l10n.pollCloseConfirmTie(
      tied.map((o) => o.text).join(', '),
      leader.text,
    );
  } else {
    message = l10n.pollCloseConfirmLeader(leader.text, leader.voteCount);
  }
  final confirmed = await CommonDialogActions.showActionConfirmation(
    context: context,
    title: l10n.pollCloseConfirmTitle,
    message: message,
    confirmText: l10n.pollCloseConfirmAction,
    cancelText: l10n.pollCloseConfirmKeepOpen,
  );
  return confirmed == true;
}
