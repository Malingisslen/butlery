import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/distinct_initials.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/stored_display_name.dart';
import 'package:butlery/models/unified/unified_shopping_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart'
    show ClaimOutcome, ClaimResult;
import 'package:butlery/viewmodels/collaborative_shopping_viewmodel.dart';
import 'package:butlery/widgets/common/avatar_circle.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/shopping/shopping_row.dart';
import 'package:flutter/material.dart';

class CollaborativeItemCard extends StatelessWidget {
  final UnifiedShoppingItem item;
  final bool isCompleted;
  final bool greyed;
  final CollaborativeShoppingViewModel viewModel;
  final Function(String itemId) onToggleItem;

  const CollaborativeItemCard({
    super.key,
    required this.item,
    required this.isCompleted,
    required this.greyed,
    required this.viewModel,
    required this.onToggleItem,
  });

  @override
  Widget build(BuildContext context) {
    final uid = viewModel.currentUserId;
    final isMine =
        item.assignedToUserId != null &&
        item.assignedToUserId == uid &&
        !isCompleted;
    final isClaimableByMe =
        !isCompleted && item.assignedToUserId == null && viewModel.canEdit;
    final canRelease = isMine && viewModel.canEdit;

    return KeyedSubtree(
      key: ValueKey('collab-item-${item.id}'),
      child: _maybeWrapSwipe(
        context: context,
        isClaimableByMe: isClaimableByMe,
        canRelease: canRelease,
        child: ShoppingRow(
          name: item.name,
          amount: item.quantityText,
          note: item.note,
          checked: item.bought,
          muted: greyed,
          onTap: viewModel.canView ? () => onToggleItem(item.id) : null,
          semanticLabel: item.displayText,
          trailing: _buildTrailing(context),
        ),
      ),
    );
  }

  /// Wrap the tile in a Dismissible for swipe-right-to-claim on mobile.
  /// confirmDismiss returns false so the row snaps back; we trigger the
  /// claim/unclaim call via the confirm hook.
  Widget _maybeWrapSwipe({
    required BuildContext context,
    required bool isClaimableByMe,
    required bool canRelease,
    required Widget child,
  }) {
    if (!isClaimableByMe && !canRelease) return child;
    final cs = Theme.of(context).colorScheme;
    final label = canRelease ? context.l10n.lamnaTillbaka : context.l10n.tarJag;
    final background = Container(
      alignment: AlignmentDirectional.centerStart,
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.space16),
      color: cs.primaryContainer,
      child: Text(label, style: AppTextStyles.bodyBold),
    );
    return Dismissible(
      key: ValueKey('swipe-${item.id}'),
      direction: DismissDirection.startToEnd,
      background: background,
      confirmDismiss: (_) async {
        await _handleClaimAction(context, release: canRelease);
        return false;
      },
      child: child,
    );
  }

  Widget _buildTrailing(BuildContext context) {
    final widgets = <Widget>[];
    final buyer = knownStoredName(item.purchasedByDisplayName);
    if (item.bought && buyer != null) {
      // #inkop: a bought row names who bought it, in the secondary tone.
      widgets.add(
        Text(
          buyer,
          style: AppTextStyles.bodySmall.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }
    if (item.assignedToUserId != null) {
      widgets.add(
        AvatarCircle(
          glyph: _assigneeInitials(),
          size: AvatarCircleSize.inline,
        ),
      );
      widgets.add(const SizedBox(width: AppDimensions.space4));
    } else if (viewModel.canEdit && !item.bought) {
      widgets.add(
        ButleryTextButton(
          onPressed: () => _handleClaimAction(context, release: false),
          label: context.l10n.tarJag,
        ),
      );
    }
    widgets.addAll(viewModel.getItemTrailingWidgets(item));
    return Row(mainAxisSize: MainAxisSize.min, children: widgets);
  }

  // Over every assignee on the list, done or not, so two people with the
  // same initials do not share a badge.
  String _assigneeInitials() {
    final names = <String>{
      for (final i in [
        ...viewModel.activeItems,
        ...viewModel.completedItemsList,
      ])
        if (i.assignedToUserId != null) i.assignedToDisplayName.orEmpty(),
    }.toList();
    final own = item.assignedToDisplayName.orEmpty();
    return distinctInitials(names)[names.indexOf(own)];
  }

  Future<void> _handleClaimAction(
    BuildContext context, {
    required bool release,
  }) async {
    final result = release
        ? await viewModel.unclaimItem(item.id)
        : await viewModel.claimItem(item.id);
    if (!context.mounted) return;
    _maybeShowSnackBar(context, result);
  }

  void _maybeShowSnackBar(BuildContext context, ClaimResult result) {
    if (result.outcome != ClaimOutcome.conflict) return;
    final name = storedNameOr(
      result.conflictingDisplayName,
      context.l10n.shoppingUnknownUser,
    );
    // Informs, never Ångra.
    SnackBarUtils.showInfo(context, context.l10n.nagonAnnanTogDen(name));
  }
}
