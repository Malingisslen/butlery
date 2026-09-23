// lib/views/social/group_detail/group_members_list.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/views/social/group_detail/group_member_card.dart';
import 'package:butlery/views/social/group_detail/group_invitation_card.dart';
import 'package:butlery/views/social/group_detail/group_detail_actions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/feedback/partial_outcome.dart';

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

  /// The last bulk removal when only some went (P5-U33). Cleared by "Klart",
  /// by Avbryt and by the next removal.
  MemberRemovalOutcome? _partial;

  bool get _canAddMembers =>
      ServiceLocator.get<PermissionService>().canInviteToGroup(widget.group.id);

  /// The members this user may select: the ones she may remove. Mirrors
  /// GroupMemberCard's rule — never yourself, never the owner, and only for
  /// the owner or an admin. Identity is the uid, never the row.
  int get _selectableCount {
    final permissions = ServiceLocator.get<PermissionService>();
    final group = widget.group;
    if (!permissions.isOwner(group.ownerId) &&
        !permissions.isGroupAdmin(group.id)) {
      return 0;
    }
    return widget.members
        .where(
          (m) => m.uid != permissions.currentUserId && m.uid != group.ownerId,
        )
        .length;
  }

  void _enterSelection(String uid) {
    setState(() {
      _selectionMode = true;
      _selectedIds.add(uid);
    });
  }

  /// "Välj" in the section's header row (B-46; Skarmar v12 etapp 9
  /// #flervalingang: "sektionens rubrikrad").
  void _startSelection() {
    setState(() => _selectionMode = true);
  }

  /// Taking the last tick off leaves selection mode (produktregler.md:878).
  void _toggle(String uid) {
    setState(() {
      if (!_selectedIds.remove(uid)) _selectedIds.add(uid);
      if (_selectedIds.isEmpty) _selectionMode = false;
    });
  }

  void _cancelSelection() {
    setState(() {
      _selectionMode = false;
      _selectedIds.clear();
      _partial = null;
    });
  }

  Future<void> _removeSelected() async {
    final selected = widget.members
        .where((m) => _selectedIds.contains(m.uid))
        .toList(growable: false);
    if (selected.isEmpty) return;
    setState(() => _partial = null);

    // removeMultipleMembers shows its own bulk-confirm dialog and reports the
    // two whole outcomes; a partial one is shown here, by the rows.
    final outcome = await GroupDetailActions.removeMultipleMembers(
      context,
      selected,
      widget.group,
    );
    if (!mounted || outcome == null) return;
    if (outcome.isComplete) {
      _cancelSelection();
      widget.onMemberRemoved();
      return;
    }
    if (outcome.isPartial) {
      // The ones that did not go stay selected and the mode stays open, so
      // the attempt can be made again (produktregler.md:908, :878; Skarmar
      // v12 etapp 9 #flergrupp). Identity is the uid.
      setState(() {
        _selectedIds
          ..clear()
          ..addAll(outcome.failed.map((m) => m.uid));
        _partial = outcome;
      });
      widget.onMemberRemoved();
    }
    // None went: the selection is left as it was, and the failure snackbar
    // says so.
  }

  /// "Klart" closes the outcome and leaves selection mode: the user's own
  /// act (produktregler.md:878; Skarmar v12 etapp 9:392).
  void _closePartial() => _cancelSelection();

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
            // P5-U31: the list lives in the group view's scroll, so the
            // section's header row carries "Välj", and Avbryt takes its
            // place in selection mode (Skarmar v12 etapp 9 #flervalingang;
            // produktregler.md:870-874). text.primary on the page surface in
            // both modes (cs.onSurface; tokens.json:54).
            if (_selectionMode)
              ButleryCancelSelectionButton(
                key: const ValueKey('group-members-selection-cancel'),
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                onPressed: _cancelSelection,
              )
            else if (ButlerySelectButton.shownFor(_selectableCount))
              ButlerySelectButton(
                key: const ValueKey('group-members-select-enter'),
                semanticLabel: context.l10n.selectionEnterMembers,
                foregroundColor: Theme.of(context).colorScheme.onSurface,
                onPressed: _startSelection,
              ),
          ],
        ),
        const SizedBox(height: AppDimensions.spacingL),

        // Members section
        if (members.isNotEmpty) ...[
          Text(
            context.l10n.groupMembersCount(members.length),
            style: AppTextStyles.titleMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurface,
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

        if (_partial != null) ...[
          const SizedBox(height: AppDimensions.spacingL),
          _buildPartialOutcome(context, _partial!),
        ],

        // Pending invitations section
        if (pendingInvitations.isNotEmpty) ...[
          if (members.isNotEmpty)
            const SizedBox(height: AppDimensions.spacingXl),
          Text(
            context.l10n.groupPendingInvitationsCount(
              pendingInvitations.length,
            ),
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

  /// P5-U33: "En av två togs bort" below the rows (Skarmar v12 etapp 9
  /// :390-393, #flergrupp): what went, who did not and why, and the way on.
  /// Those who did not go are still selected above.
  Widget _buildPartialOutcome(
    BuildContext context,
    MemberRemovalOutcome outcome,
  ) {
    final l = context.l10n;
    return PartialOutcome(
      key: const ValueKey('group-members-partial-outcome'),
      title: l.groupMembersPartialTitle(
        outcome.removedIds.length,
        outcome.removedIds.length + outcome.failed.length,
      ),
      message: l.groupMembersPartialMessage,
      items: [
        for (final member in outcome.failed)
          PartialOutcomeItem(
            id: member.uid,
            label: member.displayName,
            reason: l.groupMemberRemoveNotSaved,
          ),
      ],
      actions: [
        TextButton(
          key: const ValueKey('group-members-partial-done'),
          onPressed: _closePartial,
          child: Text(l.partialOutcomeDone),
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
        border: Border.all(color: cs.onSurface.withValues(alpha: 0.3)),
      ),
      // The counter, "{n} valda" in tabular figures, and the action; Avbryt
      // sits in the header row (produktregler.md:873, :876).
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsetsDirectional.only(
              start: AppDimensions.spacingSm,
            ),
            child: Semantics(
              liveRegion: true,
              child: Text(
                context.l10n.bulkSelectedCount(count),
                key: const ValueKey('group-members-selection-count'),
                style: AppTextStyles.titleSmall.copyWith(
                  color: cs.onSurface,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
          ),
          const Spacer(),
          TextButton.icon(
            onPressed: count > 0 ? _removeSelected : null,
            icon: const Icon(Icons.person_remove),
            label: Text(context.l10n.groupRemoveSelectedCount(count)),
            style: TextButton.styleFrom(
              foregroundColor: cs.error,
              // Off at zero with the name readable (produktregler.md:876), in
              // the disabled role on surface.raised, never a fade
              // (tokens.json:71-74, :198).
              disabledForegroundColor: AppModeColors.textDisabled(
                cs.brightness,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
