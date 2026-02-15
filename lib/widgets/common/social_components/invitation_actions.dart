import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/common/social/social_facade.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Invitation action widgets.
class InvitationActions {
  /// Build quick selection buttons.
  static Widget quickSelectionButtons(
    BuildContext context, {
    VoidCallback? onSelectAll,
    VoidCallback? onSelectNone,
    VoidCallback? onSelectFriends,
    VoidCallback? onSelectGroups,
    String? selectAllText,
    String? selectNoneText,
    String? selectFriendsText,
    String? selectGroupsText,
    EdgeInsets? padding,
    MainAxisAlignment alignment = MainAxisAlignment.spaceEvenly,
  }) {
    return SocialFacade.quickSelectionButtons(
      context,
      onSelectAll: onSelectAll ?? () {},
      onDeselectAll: onSelectNone ?? () {},
      onInvertSelection: () {},
    );
  }

  /// Build selection action bar
  /// Action bar for selected targets
  static Widget selectionActionBar(
    BuildContext context, {
    required int selectedCount,
    VoidCallback? onSelectAll,
    VoidCallback? onDeselectAll,
    VoidCallback? onInvertSelection,
    VoidCallback? onSendInvitations,
    bool showSelectAll = true,
    bool showDeselectAll = true,
    bool showInvert = true,
    bool showSend = true,
    EdgeInsets? padding,
  }) {
    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .primary
            .withValues(alpha: AppDimensions.opacityVeryLight),
        border: Border(
          top: BorderSide(
              color: Theme.of(context)
                  .colorScheme
                  .primary
                  .withValues(alpha: AppDimensions.opacityMediumLight)),
        ),
      ),
      child: Row(
        children: [
          Text(
            context.l10n.invitationTargetsSelectedCount(selectedCount),
            style: AppTextStyles.contentLabel,
          ),
          const Spacer(),
          if (showSelectAll && onSelectAll != null)
            TextButton(
              onPressed: onSelectAll,
              child: Text(context.l10n.commonSelectAll),
            ),
          if (showDeselectAll && onDeselectAll != null)
            TextButton(
              onPressed: onDeselectAll,
              child: Text(context.l10n.commonDeselectAll),
            ),
          if (showInvert && onInvertSelection != null)
            TextButton(
              onPressed: onInvertSelection,
              child: Text(context.l10n.socialInvertLabel),
            ),
          if (showSend && onSendInvitations != null)
            ElevatedButton(
              onPressed: selectedCount > 0 ? onSendInvitations : null,
              child: Text(context.l10n.commonSend),
            ),
        ],
      ),
    );
  }

  /// Build floating action buttons
  /// FAB for primary actions
  static Widget floatingActionButtons({
    VoidCallback? onAddTarget,
    VoidCallback? onSendInvitations,
    VoidCallback? onCreateGroup,
    bool showAdd = true,
    bool showSend = true,
    bool showCreate = false,
    String? addTooltip,
    String? sendTooltip,
    String? createTooltip,
  }) {
    final buttons = <Widget>[];

    if (showAdd && onAddTarget != null) {
      buttons.add(
        FloatingActionButton(
          onPressed: onAddTarget,
          tooltip: addTooltip,
          heroTag: 'add_target',
          child: const Icon(Icons.add),
        ),
      );
    }

    if (showCreate && onCreateGroup != null) {
      buttons.add(
        FloatingActionButton(
          onPressed: onCreateGroup,
          tooltip: createTooltip,
          heroTag: 'create_group',
          child: const Icon(Icons.group_add),
        ),
      );
    }

    if (showSend && onSendInvitations != null) {
      buttons.add(
        Builder(
          builder: (context) => FloatingActionButton.extended(
            onPressed: onSendInvitations,
            tooltip: sendTooltip,
            heroTag: 'send_invitations',
            icon: const Icon(Icons.send),
            label: Text(sendTooltip ?? context.l10n.commonSend),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    if (buttons.length == 1) return buttons.first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: buttons.reversed
          .map((button) => Padding(
                padding: AppDimensions.paddingOnlyBottom16,
                child: button,
              ))
          .toList(),
    );
  }

  /// Build bulk operation buttons.
  static Widget bulkOperationButtons(
    BuildContext context, {
    required List<InvitationTarget> selectedTargets,
    VoidCallback? onBulkInvite,
    VoidCallback? onBulkRemove,
    VoidCallback? onBulkExport,
    bool showInvite = true,
    bool showRemove = true,
    bool showExport = false,
    String? inviteText,
    String? removeText,
    String? exportText,
    EdgeInsets? padding,
  }) {
    if (selectedTargets.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: padding ?? const EdgeInsets.all(AppDimensions.spacingMd),
      child: Row(
        children: [
          Text(
            context.l10n.invitationTargetsSelectedCount(selectedTargets.length),
            style: AppTextStyles.contentLabel,
          ),
          const Spacer(),
          if (showRemove && onBulkRemove != null)
            TextButton.icon(
              onPressed: onBulkRemove,
              icon: Icon(Icons.delete,
                  color: Theme.of(context).colorScheme.error),
              label: Text(removeText ?? context.l10n.commonDelete),
              style: TextButton.styleFrom(
                  foregroundColor: Theme.of(context).colorScheme.error),
            ),
          if (showExport && onBulkExport != null)
            TextButton.icon(
              onPressed: onBulkExport,
              icon: const Icon(Icons.download),
              label: Text(exportText ?? context.l10n.commonExport),
            ),
          if (showInvite && onBulkInvite != null)
            ElevatedButton.icon(
              onPressed: onBulkInvite,
              icon: const Icon(Icons.send),
              label: Text(inviteText ?? context.l10n.invitationSendInvitations),
            ),
        ],
      ),
    );
  }

  /// Build batch action dialog
  /// Dialog for confirming batch operations
  static Widget batchActionDialog({
    required BuildContext context,
    required String title,
    required String message,
    required List<InvitationTarget> targets,
    required VoidCallback onConfirm,
    VoidCallback? onCancel,
    String? confirmText,
    String? cancelText,
    bool isDangerous = false,
  }) {
    return AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: AppDimensions.spacingMd),
          Text(
            context.l10n.invitationAffectedTargets,
            style: AppTextStyles.contentLabel,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: targets.length,
              itemBuilder: (context, index) {
                final target = targets[index];
                return ListTile(
                  dense: true,
                  leading: Icon(
                    target.type == InvitationTargetType.group
                        ? Icons.group
                        : Icons.person,
                    size: AppDimensions.iconSizeM,
                  ),
                  title: Text(
                    target.displayName,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  subtitle: Text(
                    context.l10n
                        .shareGroupMembersCount(target.memberCount ?? 0),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: onCancel ?? () => Navigator.of(context).pop(),
          child: Text(cancelText ?? context.l10n.commonCancel),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.of(context).pop();
            onConfirm();
          },
          style: isDangerous
              ? ElevatedButton.styleFrom(
                  backgroundColor: Theme.of(context).colorScheme.error)
              : null,
          child: Text(confirmText ?? context.l10n.commonContinue),
        ),
      ],
    );
  }

  /// Build target context menu.
  static Widget targetContextMenu({
    required InvitationTarget target,
    VoidCallback? onView,
    VoidCallback? onEdit,
    VoidCallback? onRemove,
    VoidCallback? onInvite,
    bool showView = true,
    bool showEdit = true,
    bool showRemove = true,
    bool showInvite = true,
  }) {
    return PopupMenuButton<String>(
      onSelected: (action) {
        switch (action) {
          case 'view':
            onView?.call();
            break;
          case 'edit':
            onEdit?.call();
            break;
          case 'invite':
            onInvite?.call();
            break;
          case 'remove':
            onRemove?.call();
            break;
        }
      },
      itemBuilder: (context) => [
        if (showView && onView != null)
          PopupMenuItem(
            value: 'view',
            child: ListTile(
              leading: const Icon(Icons.visibility),
              title: Text(context.l10n.invitationView),
              dense: true,
            ),
          ),
        if (showEdit && onEdit != null)
          PopupMenuItem(
            value: 'edit',
            child: ListTile(
              leading: const Icon(Icons.edit),
              title: Text(context.l10n.commonEdit),
              dense: true,
            ),
          ),
        if (showInvite && onInvite != null)
          PopupMenuItem(
            value: 'invite',
            child: ListTile(
              leading: const Icon(Icons.send),
              title: Text(context.l10n.invitationSendInvitation),
              dense: true,
            ),
          ),
        if (showRemove && onRemove != null)
          PopupMenuItem(
            value: 'remove',
            child: Builder(
              builder: (context) => ListTile(
                leading: Icon(Icons.delete,
                    color: Theme.of(context).colorScheme.error),
                title: Text(context.l10n.commonDelete,
                    style: AppTextStyles.bodyMediumError),
                dense: true,
              ),
            ),
          ),
      ],
    );
  }

  /// Build swipe actions
  /// Swipe actions for list items
  static Widget swipeActions(
    BuildContext context, {
    required Widget child,
    VoidCallback? onSwipeLeft,
    VoidCallback? onSwipeRight,
    Widget? leftAction,
    Widget? rightAction,
    String? leftLabel,
    String? rightLabel,
    Color? leftColor,
    Color? rightColor,
  }) {
    final cs = Theme.of(context).colorScheme;
    final resolvedLeftColor = leftColor ?? cs.error;
    final resolvedRightColor = rightColor ?? cs.primary;
    final resolvedLeftLabel = leftLabel ?? context.l10n.commonDelete;
    final resolvedRightLabel = rightLabel ?? context.l10n.invitationInvite;

    return Dismissible(
      key: UniqueKey(),
      background: leftAction ??
          Container(
            color: resolvedLeftColor,
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.delete, color: cs.surfaceContainerHighest),
                Text(
                  resolvedLeftLabel,
                  style: AppTextStyles.buttonTextLight,
                ),
              ],
            ),
          ),
      secondaryBackground: rightAction ??
          Container(
            color: resolvedRightColor,
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsetsDirectional.only(end: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.send, color: cs.surfaceContainerHighest),
                Text(
                  resolvedRightLabel,
                  style: AppTextStyles.buttonTextLight,
                ),
              ],
            ),
          ),
      onDismissed: (direction) {
        if (direction == DismissDirection.startToEnd) {
          onSwipeLeft?.call();
        } else if (direction == DismissDirection.endToStart) {
          onSwipeRight?.call();
        }
      },
      child: child,
    );
  }
}
