/// Member picker for blocking someone from inside a group conversation.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/services/user_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/friends_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/messaging/components/group_member_item.dart';

/// Picks which member of a group to block. Returns the chosen profile, or
/// null. It returns the whole profile because the caller needs the display
/// name for the confirm dialog, and this is where it was loaded.
class BlockGroupMemberDialog extends StatefulWidget {
  final List<String> participantIds;
  final FriendsViewModel friendsViewModel;

  const BlockGroupMemberDialog({
    super.key,
    required this.participantIds,
    required this.friendsViewModel,
  });

  static Future<UserProfile?> show(
    BuildContext context, {
    required List<String> participantIds,
    required FriendsViewModel friendsViewModel,
  }) {
    return showDialog<UserProfile>(
      context: context,
      builder: (_) => BlockGroupMemberDialog(
        participantIds: participantIds,
        friendsViewModel: friendsViewModel,
      ),
    );
  }

  @override
  State<BlockGroupMemberDialog> createState() => _BlockGroupMemberDialogState();
}

class _BlockGroupMemberDialogState extends State<BlockGroupMemberDialog> {
  late final UserService _userService;
  late final PermissionService _permissionService;
  List<UserProfile>? _members;
  bool _failed = false;

  @override
  void initState() {
    super.initState();
    _userService = ServiceLocator.get<UserService>();
    _permissionService = ServiceLocator.get<PermissionService>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _members = null;
      _failed = false;
    });

    final candidates = widget.participantIds
        .where((id) => id != _permissionService.currentUserId)
        .where(
          (id) =>
              widget.friendsViewModel.getFriendshipStatus(id) !=
              FriendshipStatus.blocked,
        )
        .toList();

    if (candidates.isEmpty) {
      if (mounted) setState(() => _members = const []);
      return;
    }

    // `getUserProfiles` swallows its own repository failure and returns what
    // it has — [] on a total failure, a subset on a partial one. So a throw is
    // not the signal: zero profiles for a non-empty candidate list is. Without
    // this the empty state would tell the user there is nobody to block, which
    // is a claim about the GROUP made when nothing loaded.
    //
    // Two residuals, named rather than left to be discovered. A PARTIAL
    // failure still renders a subset with no notice, so a member you cannot
    // see is a member you cannot block; closing that needs a caller-visible
    // failure signal on `getUserProfiles`, which has other callers. And a
    // group whose every candidate has no public profile at all (deleted
    // accounts) lands in the error state permanently, with a retry that can
    // never succeed.
    try {
      final profiles = await _userService.getUserProfiles(candidates);
      if (!mounted) return;
      if (profiles.isEmpty) {
        AppLogger.error(
          'No profiles returned for ${candidates.length} block candidates',
        );
        setState(() => _failed = true);
        return;
      }
      setState(() => _members = profiles);
    } catch (e) {
      AppLogger.error('Failed to load group members for blocking', e);
      if (mounted) setState(() => _failed = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(context.l10n.chatBlockGroupMemberTitle),
      content: SizedBox(
        width: double.maxFinite,
        child: _buildContent(context),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: Text(context.l10n.commonCancel),
        ),
      ],
    );
  }

  Widget _buildContent(BuildContext context) {
    if (_failed) {
      return StateWidget.error(
        message: context.l10n.errorGeneric,
        actionLabel: context.l10n.commonRetry,
        onAction: _load,
      );
    }

    final members = _members;
    if (members == null) return StateWidget.loading();

    if (members.isEmpty) {
      return StateWidget.empty(
        title: context.l10n.chatBlockGroupMemberEmpty,
        icon: Icons.block,
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      padding: const EdgeInsets.only(top: AppDimensions.spacingS),
      itemCount: members.length,
      itemBuilder: (context, index) {
        final member = members[index];
        return GroupMemberItem(
          displayName: member.displayName,
          avatarUrl: member.avatarUrl,
          // Label names the ACTION only — the row's own Text carries the
          // name, and the two are concatenated into one announcement.
          semanticsLabel: context.l10n.a11yBlockGroupMember,
          onTap: () => Navigator.of(context).pop(member),
        );
      },
    );
  }
}
