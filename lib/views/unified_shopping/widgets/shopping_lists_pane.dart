// lib/views/unified_shopping/widgets/shopping_lists_pane.dart

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/unified/unified_shopping_list.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/unified_shopping_viewmodel.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// BUT-723: Inköp on a tablet in landscape, the lists on the left and the
/// active list or the pantry on the right under its own [bar].
class ShoppingTwoPanes extends StatelessWidget {
  const ShoppingTwoPanes({
    required this.lists,
    required this.bar,
    required this.detail,
    this.floatingActionButton,
    this.bottomBar,
    super.key,
  });

  final Widget lists;
  final ButleryTopBar bar;
  final Widget detail;

  /// The right side's own, so they stand under the list and not across both
  /// sides.
  final Widget? floatingActionButton;
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(
          width: AppDimensions.detailPaneListWidth,
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: context.l10n.a11yDetailPaneList,
            child: lists,
          ),
        ),
        SizedBox(
          width: AppDimensions.dividerHeight,
          child: ColoredBox(color: cs.outlineVariant),
        ),
        Expanded(
          child: Semantics(
            container: true,
            explicitChildNodes: true,
            label: context.l10n.a11yDetailPaneDetail,
            child: Scaffold(
              appBar: bar,
              body: detail,
              // The add button fills the width it is given, so it is
              // centred with its own margins rather than placed from the end.
              floatingActionButtonLocation:
                  FloatingActionButtonLocation.centerFloat,
              floatingActionButton: floatingActionButton == null
                  ? null
                  : Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.spacingMd,
                      ),
                      child: floatingActionButton,
                    ),
              bottomNavigationBar: bottomBar,
            ),
          ),
        ),
      ],
    );
  }
}

/// BUT-723: the left side of Inköp on a tablet in landscape. The right side
/// is the active list, so picking a card makes that list active.
class ShoppingListsPane extends StatelessWidget {
  const ShoppingListsPane({
    required this.viewModel,
    required this.bar,
    required this.tabBar,
    required this.showLists,
    required this.onPickList,
    required this.onCreateList,
    super.key,
  });

  final UnifiedShoppingViewModel viewModel;

  /// The tab's root bar, drawn by the view that owns it.
  final ButleryTopBar bar;
  final Widget tabBar;

  /// False while Skafferiet is the chosen tab: the pantry then fills the
  /// right side and the left keeps only the title and the tabs.
  final bool showLists;
  final ValueChanged<String> onPickList;
  final VoidCallback onCreateList;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final lists = viewModel.lists;

    return ColoredBox(
      color: cs.surface,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The bar's preferred height is its ceiling at 200 % text; below
          // it the bar takes what its content needs, as under a Scaffold.
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: bar.preferredSize.height,
            ),
            child: bar,
          ),
          tabBar,
          if (showLists)
            Expanded(
              child: ListView(
                padding: const EdgeInsets.all(AppDimensions.spacingMd),
                children: [
                  for (final list in lists)
                    _ShoppingListCard(
                      key: ValueKey('shopping-pane-list-${list.id}'),
                      list: list,
                      isActive: list.id == viewModel.activeList?.id,
                      onTap: () => onPickList(list.id),
                    ),
                  const SizedBox(height: AppDimensions.spacingSm),
                  OutlinedButton.icon(
                    key: const ValueKey('shopping-pane-new-list'),
                    onPressed: onCreateList,
                    icon: const ButleryIcon(ButleryIcons.plus),
                    label: Text(context.l10n.shoppingNewShoppingList),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ShoppingListCard extends StatelessWidget {
  const _ShoppingListCard({
    required this.list,
    required this.isActive,
    required this.onTap,
    super.key,
  });

  final UnifiedShoppingList list;
  final bool isActive;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final detail = [
      context.l10n.shoppingItemCount(list.items.length),
      if (list.isCollaborative) context.l10n.shoppingPermissionShared,
    ].join(' · ');

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingSm),
      child: Material(
        color: cs.surfaceContainerHighest,
        // As Meny's dish cards: the card already sits on the selected
        // surface, so the chosen one takes the border instead of a fill.
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
          side: isActive
              ? BorderSide(color: cs.onSurface, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: Semantics(
          label: context.l10n.a11yShoppingPickList,
          button: true,
          selected: isActive,
          child: PressFill(
            surface: PressSurface.raised,
            child: InkWell(
              onTap: onTap,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingMd,
                  vertical: AppDimensions.spacingSm,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      list.name,
                      style: AppTextStyles.titleMedium,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      detail,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
