// lib/views/social/group_detail/group_members_list.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/views/social/group_detail/group_member_card.dart';
import 'package:butlery/views/social/group_detail/group_invitation_card.dart';
import 'package:butlery/views/social/group_detail/group_detail_actions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// GroupMembersList - Members list component.
///
/// Displays group members and pending invitations with actions, including
/// BUT-1038 long-press multi-select + bulk removal of members.
class GroupMembersList {
  /// Public factory kept stable so the existing call site in
  /// `group_detail_view.dart` is unchanged; returns a stateful widget that
  /// owns the multi-select state.
  static Widget build(
    BuildContext context, {
    required List<UserProfile> members,
    required List<GroupInvitation> pendingInvitations,
    required FriendCategory group,
    required VoidCallback onAddMembers,
    required VoidCallback onMemberRemoved,
    required VoidCallback onInvitationCancelled,
  }) {
    return _GroupMembersListView(
      members: members,
      pendingInvitations: pendingInvitations,
      group: group,
      onAddMembers: onAddMembers,
      onMemberRemoved: onMemberRemoved,
      onInvitationCancelled: onInvitationCancelled,
    );
  }
}

class _GroupMembersListView extends StatefulWidget {
  const _GroupMembersListView({
    required this.members,
    required this.pendingInvitations,
    required this.group,
    required this.onAddMembers,
    required this.onMemberRemoved,
    required this.onInvitationCancelled,
  });

  final List<UserProfile> members;
  final List<GroupInvitation> pendingInvitations;
  final FriendCategory group;
  final VoidCallback onAddMembers;
  final VoidCallback onMemberRemoved;
  final VoidCallback onInvitationCancelled;

  @override
  State<_GroupMembersListView> createState() => _GroupMembersListViewState();
}

class _GroupMembersListViewState extends State<_GroupMembersListView> {
  bool _selectionMode = false;
  final Set<String> _selectedIds = {};

  bool get _canAddMembers =>
      ServiceLocator.get<PermissionService>().canInviteToGroup(widget.group.id);

  void _enterSelection(String uid) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(uid);
    });
  }

  void _toggle(String uid) {
    setState(() {
      if (!_selectedIds.remove(uid)) _selectedIds.add(uid);
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
    });
  }

  Future<void> _removeSelected() async {
    final selected = widget.members
        .where((m) => _selectedIds.contains(m.uid))
        .toList(growable: false);
    if (selected.isEmpty) return;

    // removeMultipleMembers shows its own bulk-confirm dialog + partial-fail
    // reporting and returns the number actually removed.
    final removed = await GroupDetailActions.removeMultipleMembers(
      context,
      selected,
      widget.group,
    );
    if (!mounted) return;
    if (removed > 0) {
      _cancelSelection();
      widget.onMemberRemoved();
    }
  }

  @override
  Widget build(BuildContext context) {
    final members = widget.members;
    final pendingInvitations = widget.pendingInvitations;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header with add button (hidden during selection to reduce noise).
        Row(
          children: [
            Text(
              context.l10n.groupMembersAndInvitations,
              style: AppTextStyles.titleBold,
            ),
            const Spacer(),
            if (_canAddMembers && !_selectionMode)
              TextButton.icon(
                onPressed: widget.onAddMembers,
                icon: const Icon(Icons.person_add),
                label: Text(context.l10n.commonAdd),
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingL),

        // Members section
        if (members.isNotEmpty) ...[
          Text(
            context.l10n.groupMembersCount(members.length),
            style: AppTextStyles.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingS),
          if (_selectionMode) _buildSelectionBar(context),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: members.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppDimensions.spacingS),
            itemBuilder: (context, index) {
              final member = members[index];
              return KeyedSubtree(
                key: ValueKey(member.uid),
                child: GroupMemberCard.build(
                  context,
                  member,
                  widget.group,
                  widget.onMemberRemoved,
                  isSelectionMode: _selectionMode,
                  isSelected: _selectedIds.contains(member.uid),
                  onSelectionToggle: () => _toggle(member.uid),
                  onEnterSelection: () => _enterSelection(member.uid),
                ),
              );
            },
          ),
        ],

        // Pending invitations section
        if (pendingInvitations.isNotEmpty) ...[
          if (members.isNotEmpty)
            const SizedBox(height: AppDimensions.spacingXl),
          Text(
            context.l10n
                .groupPendingInvitationsCount(pendingInvitations.length),
            style: AppTextStyles.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.tertiary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingS),
          ListView.separated(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: pendingInvitations.length,
            separatorBuilder: (context, index) =>
                const SizedBox(height: AppDimensions.spacingS),
            itemBuilder: (context, index) {
              final invitation = pendingInvitations[index];
              return KeyedSubtree(
                key: ValueKey(invitation.id),
                child: GroupInvitationCard.build(
                  context,
                  invitation,
                  widget.onInvitationCancelled,
                ),
              );
            },
          ),
        ],

        // Empty state
        if (members.isEmpty && pendingInvitations.isEmpty)
          StateWidget.empty(
            title: context.l10n.groupNoMembersYet,
            subtitle: context.l10n.groupNoMembersDescription,
            icon: Icons.people_outline,
          ),
      ],
    );
  }

  /// Inline bulk-action bar shown above the member list while selecting.
  /// Inline (not a Scaffold bottom bar) because this list lives inside the
  /// parent's scroll view — keeps selection self-contained.
  Widget _buildSelectionBar(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final count = _selectedIds.length;

    return Container(
      margin: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingL,
        vertical: AppDimensions.spacingS,
      ),
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.spacingXs,
        AppDimensions.spacingXxs,
        AppDimensions.spacingS,
        AppDimensions.spacingXxs,
      ),
      decoration: BoxDecoration(
        color: cs.primaryContainer,
        border: Border.all(color: cs.primary.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          IconButton(
            icon: const Icon(Icons.close),
            tooltip: context.l10n.commonCancel,
            visualDensity: VisualDensity.compact,
            onPressed: _cancelSelection,
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: count > 0 ? _removeSelected : null,
            icon: const Icon(Icons.person_remove),
            label: Text(context.l10n.groupRemoveSelectedCount(count)),
            style: TextButton.styleFrom(foregroundColor: cs.error),
          ),
        ],
      ),
    );
  }
}
