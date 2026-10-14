import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/invitations/invitation_target.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/social/social_facade.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/menus/butlery_menu.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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
      padding: padding ?? const EdgeInsets.all(AppDimensions.space16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        border: Border(
          top: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
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
            ButleryTextButton(
              onPressed: onSelectAll,
              label: context.l10n.commonSelectAll,
            ),
          if (showDeselectAll && onDeselectAll != null)
            ButleryTextButton(
              onPressed: onDeselectAll,
              label: context.l10n.commonDeselectAll,
            ),
          if (showInvert && onInvertSelection != null)
            ButleryTextButton(
              onPressed: onInvertSelection,
              label: context.l10n.socialInvertLabel,
            ),
          if (showSend && onSendInvitations != null)
            ActionButtons.primaryButton(
              context,
              onPressed: selectedCount > 0 ? onSendInvitations : null,
              label: context.l10n.commonSend,
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
        PressFill(
          surface: PressSurface.ink,
          child: FloatingActionButton(
            onPressed: onAddTarget,
            tooltip: addTooltip,
            heroTag: 'add_target',
            child: const ButleryIcon(ButleryIcons.plus),
          ),
        ),
      );
    }

    if (showCreate && onCreateGroup != null) {
      buttons.add(
        PressFill(
          surface: PressSurface.ink,
          child: FloatingActionButton(
            onPressed: onCreateGroup,
            tooltip: createTooltip,
            heroTag: 'create_group',
            child: const ButleryIcon(ButleryIcons.usersPlus),
          ),
        ),
      );
    }

    if (showSend && onSendInvitations != null) {
      buttons.add(
        Builder(
          builder: (context) => PressFill(
            surface: PressSurface.ink,
            child: FloatingActionButton.extended(
              onPressed: onSendInvitations,
              tooltip: sendTooltip,
              heroTag: 'send_invitations',
              icon: const ButleryIcon(ButleryIcons.send),
              label: Text(sendTooltip ?? context.l10n.commonSend),
              // A labelled FAB is a pill, not the theme's circle (Komponentark
              // v1:665, tokens.json space.radius.pill).
              shape: const StadiumBorder(),
            ),
          ),
        ),
      );
    }

    if (buttons.isEmpty) return const SizedBox.shrink();
    if (buttons.length == 1) return buttons.first;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: buttons.reversed
          .map(
            (button) => Padding(
              padding: AppDimensions.paddingOnlyBottom16,
              child: button,
            ),
          )
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
      padding: padding ?? const EdgeInsets.all(AppDimensions.space16),
      child: Row(
        children: [
          Text(
            context.l10n.invitationTargetsSelectedCount(selectedTargets.length),
            style: AppTextStyles.contentLabel,
          ),
          const Spacer(),
          if (showRemove && onBulkRemove != null)
            ButleryTextButton(
              onPressed: onBulkRemove,
              icon: ButleryIcons.trash2,
              label: removeText ?? context.l10n.commonDelete,
              tone: ButleryTextButtonTone.danger,
            ),
          if (showExport && onBulkExport != null)
            ButleryTextButton(
              onPressed: onBulkExport,
              icon: ButleryIcons.download,
              label: exportText ?? context.l10n.commonExport,
            ),
          if (showInvite && onBulkInvite != null)
            ActionButtons.primaryButton(
              context,
              onPressed: onBulkInvite,
              icon: ButleryIcons.send,
              label: inviteText ?? context.l10n.invitationSendInvitations,
            ),
        ],
      ),
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
    return Builder(
      builder: (context) => ButleryMenu<String>(
        semanticLabel: context.l10n.socialMoreOptions,
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
        choices: [
          if (showView && onView != null)
            ButleryMenuChoice(
              value: 'view',
              label: context.l10n.invitationView,
              icon: ButleryIcons.eye,
            ),
          if (showEdit && onEdit != null)
            ButleryMenuChoice(
              value: 'edit',
              label: context.l10n.commonEdit,
              icon: ButleryIcons.pencil,
            ),
          if (showInvite && onInvite != null)
            ButleryMenuChoice(
              value: 'invite',
              label: context.l10n.invitationSendInvitation,
              icon: ButleryIcons.send,
            ),
          if (showRemove && onRemove != null)
            ButleryMenuChoice(
              value: 'remove',
              label: context.l10n.commonDelete,
              icon: ButleryIcons.trash2,
              danger: true,
            ),
        ],
      ),
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
    final resolvedRightColor = rightColor ?? cs.onSurface;
    final resolvedLeftLabel = leftLabel ?? context.l10n.commonDelete;
    final resolvedRightLabel = rightLabel ?? context.l10n.invitationInvite;

    return Dismissible(
      key: UniqueKey(),
      background:
          leftAction ??
          Container(
            color: resolvedLeftColor,
            alignment: AlignmentDirectional.centerStart,
            padding: const EdgeInsetsDirectional.only(start: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ButleryIcon(
                  ButleryIcons.trash2,
                  color: cs.surfaceContainerHighest,
                ),
                Text(
                  resolvedLeftLabel,
                  style: AppTextStyles.buttonTextLight.copyWith(
                    color: cs.surfaceContainerHighest,
                  ),
                ),
              ],
            ),
          ),
      secondaryBackground:
          rightAction ??
          Container(
            color: resolvedRightColor,
            alignment: AlignmentDirectional.centerEnd,
            padding: const EdgeInsetsDirectional.only(end: 20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ButleryIcon(
                  ButleryIcons.send,
                  color: cs.surfaceContainerHighest,
                ),
                Text(
                  resolvedRightLabel,
                  style: AppTextStyles.buttonTextLight.copyWith(
                    color: cs.surfaceContainerHighest,
                  ),
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
