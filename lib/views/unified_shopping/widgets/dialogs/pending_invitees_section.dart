import 'dart:async';

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/social_request.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/services/unified/operations/list_invitation_operations.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Pending invitations to one shared list (BUT-2089), shown in the member
/// dialog. The `social_requests` read rule lets a sender see only their own
/// rows, so the list is the signed-in user's invitations; the same rule lets
/// only the sender delete one, which is why every row here is revocable.
class PendingInviteesSection extends StatefulWidget {
  const PendingInviteesSection({
    required this.operations,
    required this.listId,
    required this.nameFor,
    this.onPendingChanged,
    super.key,
  });

  final ListInvitationOperations operations;
  final String listId;
  final String Function(String userId) nameFor;

  /// The invitee ids with a live invitation, for the friend picker.
  final ValueChanged<Set<String>>? onPendingChanged;

  @override
  State<PendingInviteesSection> createState() => _PendingInviteesSectionState();
}

class _PendingInviteesSectionState extends State<PendingInviteesSection> {
  StreamSubscription<List<SocialRequest>>? _subscription;
  List<SocialRequest> _pending = const [];
  final Set<String> _revoking = {};

  @override
  void initState() {
    super.initState();
    _subscription = widget.operations.pendingSentForList(widget.listId).listen(
      (rows) {
        if (!mounted) return;
        setState(() => _pending = rows);
        widget.onPendingChanged?.call({for (final r in rows) r.toUserId});
      },
      // Optional chrome: a failed read leaves the section empty.
      onError: (Object _) {},
    );
  }

  @override
  void dispose() {
    unawaited(_subscription?.cancel());
    super.dispose();
  }

  Future<void> _revoke(SocialRequest invitation) async {
    if (!_revoking.add(invitation.id)) return;
    setState(() {});
    final outcome = await widget.operations.revokeListInvitation(
      invitation.id,
    );
    _revoking.remove(invitation.id);
    if (!mounted) return;
    setState(() {});
    final l10n = context.l10n;
    if (outcome == ListInvitationOutcome.revoked) {
      SnackBarUtils.showSuccess(context, l10n.listInviteRevoked);
    } else if (outcome == ListInvitationOutcome.offline) {
      SnackBarUtils.showFailure(context, what: l10n.errorNetwork);
    } else {
      SnackBarUtils.showFailure(context, what: l10n.listInviteRevokeFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_pending.isEmpty) return const SizedBox.shrink();
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(l10n.listInvitePendingHeading, style: AppTextStyles.titleMedium),
        const SizedBox(height: AppDimensions.spacingSm),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 132),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final invitation in _pending)
                Column(
                  key: ValueKey('pending-invitee-${invitation.id}'),
                  children: [
                    ListTile(
                      dense: true,
                      title: Text(
                        widget.nameFor(invitation.toUserId),
                        style: AppTextStyles.contentTitle,
                      ),
                      subtitle: Text(
                        l10n.listInviteNotAnsweredYet,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                      trailing: Text(
                        l10n.listInviteStatusPending,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                    if (invitation.fromUserId ==
                        widget.operations.currentUserId)
                      Align(
                        alignment: AlignmentDirectional.centerEnd,
                        child: TextButton(
                          onPressed: _revoking.contains(invitation.id)
                              ? null
                              : () => _revoke(invitation),
                          child: Text(l10n.listInviteRevoke),
                        ),
                      ),
                  ],
                ),
            ],
          ),
        ),
        const Divider(),
      ],
    );
  }
}

/// The level an invitation seats the invitee with. Admin is not offered: the
/// callable only invites as view or edit, and admin is a level change after
/// the invitee has joined.
class InviteLevelPicker extends StatelessWidget {
  const InviteLevelPicker({
    required this.value,
    required this.onChanged,
    super.key,
  });

  final SharedListPermission value;
  final ValueChanged<SharedListPermission>? onChanged;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final disabledText = AppModeColors.textDisabled(
      Theme.of(context).brightness,
    );
    return SegmentedButton<SharedListPermission>(
      showSelectedIcon: false,
      style: ButtonStyle(
        // The token, not the theme's translucent default, while a send is busy.
        foregroundColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.disabled) ? disabledText : null,
        ),
      ),
      segments: [
        ButtonSegment(
          value: SharedListPermission.view,
          label: Text(l10n.shoppingPermissionView),
        ),
        ButtonSegment(
          value: SharedListPermission.edit,
          label: Text(l10n.shoppingPermissionEdit),
        ),
      ],
      selected: {value},
      onSelectionChanged: onChanged == null
          ? null
          : (selection) => onChanged!(selection.first),
    );
  }
}
