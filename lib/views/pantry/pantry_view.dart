/// Pantry view ("Skafferiet") — displays the user's tracked ingredients
/// organized by location with expiry tracking and an add bottom sheet.
///
/// Designed as a sub-tab under the shopping area — does not own its own
/// Scaffold or app bar. Wrap in a parent that provides layout chrome.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/viewmodels/pantry/pantry_viewmodel.dart';
import 'package:butlery/views/pantry/add_pantry_item_sheet.dart';
import 'package:butlery/views/pantry/pantry_item_card.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/widgets/common/loading_state_builder.dart';

class PantryView extends StatefulWidget {
  const PantryView({super.key});

  @override
  State<PantryView> createState() => _PantryViewState();
}

class _PantryViewState extends State<PantryView> {
  late final PantryViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = ServiceLocator.get<PantryViewModel>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _vm.loadPantry();
    });
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<PantryViewModel>.value(
      value: _vm,
      child: const _PantryViewContent(),
    );
  }
}

class _PantryViewContent extends StatelessWidget {
  const _PantryViewContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<PantryViewModel>();

    return Stack(
      children: [
        LoadingStateBuilder<List<PantryItem>>(
          isLoading: viewModel.isLoading,
          error: viewModel.error,
          data: viewModel.items,
          onErrorRetry: () {
            viewModel.clearError();
            viewModel.loadPantry();
          },
          emptyBuilder: (context) => _PantryEmptyState(
            onAdd: () => _showAddSheet(context, viewModel),
          ),
          builder: (context, items) => const _PantrySections(),
        ),
        Positioned(
          right: AppDimensions.spacingLg,
          bottom: AppDimensions.spacingLg,
          child: _PantryFab(
            onPressed: () => _showAddSheet(context, viewModel),
          ),
        ),
      ],
    );
  }

  Future<void> _showAddSheet(
    BuildContext context,
    PantryViewModel viewModel,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Theme.of(context).colorScheme.surface,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      builder: (sheetContext) => ChangeNotifierProvider<PantryViewModel>.value(
        value: viewModel,
        child: const AddPantryItemSheet(),
      ),
    );
  }
}

class _PantrySections extends StatelessWidget {
  const _PantrySections();

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<PantryViewModel>();
    final l10n = context.l10n;

    final expiring = vm.expiringItems;

    return ListView(
      padding: const EdgeInsets.only(
        top: AppDimensions.spacingMd,
        bottom: 96,
      ),
      children: [
        if (expiring.isNotEmpty)
          _PantrySection(
            title: l10n.pantrySectionExpiring,
            icon: Icons.schedule,
            items: expiring,
            initiallyExpanded: true,
          ),
        _PantrySection(
          title: l10n.pantrySectionFridge,
          icon: Icons.kitchen,
          items: vm.itemsByLocation(PantryLocation.fridge),
        ),
        _PantrySection(
          title: l10n.pantrySectionFreezer,
          icon: Icons.ac_unit,
          items: vm.itemsByLocation(PantryLocation.freezer),
        ),
        _PantrySection(
          title: l10n.pantrySectionPantry,
          icon: Icons.inventory_2_outlined,
          items: vm.itemsByLocation(PantryLocation.pantry),
        ),
        _PantrySection(
          title: l10n.pantrySectionSpiceRack,
          icon: Icons.grass_outlined,
          items: vm.itemsByLocation(PantryLocation.spiceRack),
        ),
      ],
    );
  }
}

class _PantrySection extends StatelessWidget {
  const _PantrySection({
    required this.title,
    required this.icon,
    required this.items,
    this.initiallyExpanded = false,
  });

  final String title;
  final IconData icon;
  final List<PantryItem> items;
  final bool initiallyExpanded;

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) return const SizedBox.shrink();

    final cs = Theme.of(context).colorScheme;

    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        0,
        AppDimensions.spacingLg,
        AppDimensions.spacingMd,
      ),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          left: BorderSide(color: cs.primary, width: 4),
          bottom: BorderSide(
            color: context.butleryColors.recipeCardBottomBorder,
            width: 3,
          ),
        ),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          initiallyExpanded: initiallyExpanded,
          tilePadding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.spacingLg,
            vertical: AppDimensions.spacingXs,
          ),
          childrenPadding: EdgeInsets.zero,
          leading: Icon(icon, color: cs.primary, size: AppDimensions.iconSizeM),
          title: Row(
            children: [
              Text(
                title.toLowerCase(),
                style: AppTextStyles.titleSmall.copyWith(
                  letterSpacing: 2,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Text(
                '${items.length}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
          children: [
            for (final item in items)
              PantryItemCard(key: ValueKey(item.id), item: item),
          ],
        ),
      ),
    );
  }
}

class _PantryFab extends StatelessWidget {
  const _PantryFab({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.primary,
      elevation: 4,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.zero),
      child: Semantics(
        label: context.l10n.a11yPantryAddItem,
        button: true,
        child: InkWell(
          onTap: onPressed,
          child: SizedBox(
            width: 56,
            height: 56,
            child: Icon(
              Icons.add,
              color: cs.onPrimary,
              size: AppDimensions.iconSizeL,
            ),
          ),
        ),
      ),
    );
  }
}

class _PantryEmptyState extends StatelessWidget {
  const _PantryEmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.paddingXl),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const VegetableIllustration(
              type: VegetableType.broccoli,
              size: 100,
            ),
            const SizedBox(height: AppDimensions.spacingLg),
            Text(
              l10n.pantryEmptyTitle,
              style: AppTextStyles.headlineSmall.copyWith(color: cs.primary),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              l10n.pantryEmptyDescription,
              style: AppTextStyles.bodyMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppDimensions.spacingXl),
            SizedBox(
              width: double.infinity,
              child: ActionButtons.primaryButton(
                context,
                label: l10n.pantryAddIngredient,
                onPressed: onAdd,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
