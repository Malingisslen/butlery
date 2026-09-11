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
        // isBlocked, not getFriendshipStatus: the enum answers `friends`
        // before it answers `blocked`, so a block whose cleanup is still in
        // flight would put an already-blocked person back in this list
        // (BUT-2022).
        .where((id) => !widget.friendsViewModel.isBlocked(id))
        .toList();

    if (candidates.isEmpty) {
      if (mounted) setState(() => _members = const []);
      return;
    }

    // `getUserProfiles` now reports which candidate ids it could not resolve,
    // and why (BUT-2027) — so a genuinely profile-less candidate (a deleted
    // account) and a failed read are told apart. Only the latter is a
    // failure here: it means we cannot say who is left to block, where the
    // former means we asked and correctly found nobody.
    final result = await _userService.getUserProfiles(candidates);
    if (!mounted) return;
    if (result.unavailableIds.isNotEmpty) {
      AppLogger.error(
        'Could not resolve ${result.unavailableIds.length}/'
        '${candidates.length} block candidate profile(s)',
      );
      setState(() => _failed = true);
      return;
    }
    setState(() => _members = result.profiles);
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
