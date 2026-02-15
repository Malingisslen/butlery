// lib/views/cooking_mode_view.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/cooking_mode_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Full-screen landscape cooking mode with ingredients left, instructions right.
/// Keeps screen awake and forces landscape orientation while active.
class CookingModeView extends StatefulWidget {
  final Recipe recipe;

  const CookingModeView({super.key, required this.recipe});

  @override
  State<CookingModeView> createState() => _CookingModeViewState();
}

class _CookingModeViewState extends State<CookingModeView> {
  @override
  void initState() {
    super.initState();
    // Force landscape and keep screen awake
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
    WakelockPlus.enable();
    // Hide system UI for immersive cooking experience
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  @override
  void dispose() {
    // Restore all orientations and screen sleep
    SystemChrome.setPreferredOrientations(DeviceOrientation.values);
    WakelockPlus.disable();
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CookingModeViewModel(recipe: widget.recipe),
      child: const _CookingModeContent(),
    );
  }
}

class _CookingModeContent extends StatelessWidget {
  const _CookingModeContent();

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final vm = context.watch<CookingModeViewModel>();

    return Scaffold(
      backgroundColor: cs.primary,
      body: SafeArea(
        child: Column(
          children: [
            _buildTopBar(context, vm),
            Expanded(
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Left panel: ingredients (~35%)
                  Expanded(
                    flex: 35,
                    child: _IngredientsPanel(vm: vm),
                  ),
                  // Vertical divider
                  Container(
                    width: 1,
                    color: cs.surface.withValues(alpha: 0.2),
                  ),
                  // Right panel: instructions (~65%)
                  Expanded(
                    flex: 65,
                    child: _InstructionsPanel(vm: vm),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, CookingModeViewModel vm) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        color: cs.primary,
        border: Border(
          bottom: BorderSide(
            color: cs.surface.withValues(alpha: 0.2),
          ),
        ),
      ),
      child: Row(
        children: [
          // Recipe title
          Expanded(
            child: Text(
              vm.title.toLowerCase(),
              style: AppTextStyles.appBarTitle.copyWith(
                color: cs.onPrimary,
                fontSize: 20,
                letterSpacing: 1,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          // Close button
          Material(
            color: cs.surface,
            borderRadius: BorderRadius.zero,
            child: InkWell(
              onTap: () => Navigator.pop(context),
              child: SizedBox(
                width: 40,
                height: 40,
                child: Icon(
                  Icons.close,
                  color: cs.primary,
                  size: AppDimensions.iconSizeM,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Left panel displaying scaled ingredients with portion controls.
class _IngredientsPanel extends StatelessWidget {
  final CookingModeViewModel vm;

  const _IngredientsPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.primary,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Portion scaler controls
          Container(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.5),
              border: Border(
                bottom: BorderSide(
                  color: cs.surface.withValues(alpha: 0.15),
                ),
              ),
            ),
            child: Row(
              children: [
                Text(
                  'Portioner',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onPrimary,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                _buildPortionButton(
                  context,
                  icon: Icons.remove,
                  onPressed:
                      vm.currentPortions > CookingModeViewModel.minPortions
                          ? () => vm.updatePortions(vm.currentPortions - 1)
                          : null,
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingL,
                  ),
                  child: Text(
                    '${vm.currentPortions}',
                    style: AppTextStyles.bodyBold.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: cs.onPrimary,
                    ),
                  ),
                ),
                _buildPortionButton(
                  context,
                  icon: Icons.add,
                  onPressed:
                      vm.currentPortions < CookingModeViewModel.maxPortions
                          ? () => vm.updatePortions(vm.currentPortions + 1)
                          : null,
                ),
              ],
            ),
          ),
          // Ingredient list
          Expanded(
            child: ListView.builder(
              padding: const EdgeInsets.symmetric(
                horizontal: AppDimensions.spacingMd,
                vertical: AppDimensions.spacingSm,
              ),
              itemCount: vm.scaledIngredients.length,
              itemBuilder: (context, index) {
                return Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.spacingTight,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 6,
                        height: 6,
                        margin: const EdgeInsets.only(top: 8, right: 12),
                        decoration: BoxDecoration(
                          color: cs.onPrimary,
                          shape: BoxShape.rectangle,
                        ),
                      ),
                      Expanded(
                        child: Text(
                          vm.scaledIngredients[index],
                          style: AppTextStyles.bodyLarge.copyWith(
                            color: cs.onPrimary,
                            fontSize: 16,
                            height: 1.5,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPortionButton(
    BuildContext context, {
    required IconData icon,
    required VoidCallback? onPressed,
  }) {
    final cs = Theme.of(context).colorScheme;
    final isEnabled = onPressed != null;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            border: Border.all(
              color: isEnabled
                  ? cs.onPrimary
                  : cs.onPrimary.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
          child: Icon(
            icon,
            size: AppDimensions.iconSizeL,
            color:
                isEnabled ? cs.onPrimary : cs.onPrimary.withValues(alpha: 0.3),
          ),
        ),
      ),
    );
  }
}

/// Right panel displaying numbered cooking instructions.
class _InstructionsPanel extends StatelessWidget {
  final CookingModeViewModel vm;

  const _InstructionsPanel({required this.vm});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      color: cs.primary.withValues(alpha: 0.8),
      child: ListView.builder(
        padding: const EdgeInsets.all(AppDimensions.spacingLg),
        itemCount: vm.instructions.length,
        itemBuilder: (context, index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.spacingLg),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Step number badge
                Container(
                  width: 36,
                  height: 36,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: cs.surface,
                  ),
                  child: Text(
                    '${index + 1}',
                    style: AppTextStyles.bodyBold.copyWith(
                      color: cs.primary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingMd),
                // Instruction text
                Expanded(
                  child: Text(
                    vm.instructions[index],
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: cs.onPrimary,
                      fontSize: 18,
                      height: 1.7,
                    ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
