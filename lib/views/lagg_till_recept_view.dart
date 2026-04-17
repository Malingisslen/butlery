/// Recipe addition view with 4 simplified import method options.
///
/// **UI Redesign:** Simplified from 7 buttons to 4 buttons in a 2x2 grid:
/// - Importera länk (rust) → /smartImport
/// - Skriv manuellt (green) → /skrivSjalv
/// - Från bild (green) → /photoImport
/// - Från arkiv (rust) → /importFranArkiv

// lib/views/lagg_till_recept_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/main_view_header.dart';
import 'package:butlery/widgets/common/illustrations/vegetable_illustration.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Recipe addition view with simplified 2x2 grid of import options.
class LaggTillReceptView extends StatelessWidget {
  const LaggTillReceptView({super.key});

  void _navigate(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    final padding = AppDimensions.responsiveContentPadding(context);

    return Scaffold(
      appBar: MainViewHeader(
        title: context.l10n.addRecipeTitle,
        ghostIllustration: VegetableType.redOnion,
      ),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: BoxConstraints(
              maxWidth: LayoutComponents.valueFor(
                context: context,
                mobile: double.infinity,
                tablet: 500,
                desktop: 600,
              ),
            ),
            child: Padding(
              padding: padding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: AppDimensions.spacingSm),
                  // Quick capture — full-width entry point
                  FilledButton.icon(
                    onPressed: () => _navigate(context, Routes.quickCapture),
                    icon: const Icon(Icons.flash_on),
                    label: Text(context.l10n.quickCaptureTitle),
                    style: FilledButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(AppDimensions.buttonHeight),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingMd),
                  // 2x2 grid with 4 import options
                  Expanded(
                    child: _buildButtonGrid(context),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Builds the 2x2 button grid with alternating rust/green colors.
  Widget _buildButtonGrid(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Calculate button size to fit a 2x2 grid with spacing
        const spacing = AppDimensions.spacingMd;
        final buttonWidth = (constraints.maxWidth - spacing) / 2;
        final buttonHeight = (constraints.maxHeight - spacing) / 2;
        final buttonSize =
            buttonWidth < buttonHeight ? buttonWidth : buttonHeight;

        // Clamp to reasonable sizes
        final size = buttonSize.clamp(120.0, AppDimensions.gridButtonSize);

        return Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Row 1: Import link (rust) + Write manually (green)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AddRecipeButton(
                    label: context.l10n.recipeImportLink,
                    icon: Icons.link,
                    color: Theme.of(context).colorScheme.secondary,
                    size: size,
                    onTap: () => _navigate(context, '/smartImport'),
                  ),
                  const SizedBox(width: spacing),
                  _AddRecipeButton(
                    label: context.l10n.recipeWriteManually,
                    icon: Icons.edit,
                    color: Theme.of(context).colorScheme.primary,
                    size: size,
                    onTap: () => _navigate(context, '/skrivSjalv'),
                  ),
                ],
              ),
              const SizedBox(height: spacing),
              // Row 2: From image (green) + From archive (rust) — diagonal pattern
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AddRecipeButton(
                    label: context.l10n.recipeFromImage,
                    icon: Icons.image,
                    color: Theme.of(context).colorScheme.primary,
                    size: size,
                    onTap: () => _navigate(context, '/photoImport'),
                  ),
                  const SizedBox(width: spacing),
                  _AddRecipeButton(
                    label: context.l10n.recipeFromArchive,
                    icon: Icons.archive,
                    color: Theme.of(context).colorScheme.secondary,
                    size: size,
                    onTap: () => _navigate(context, '/importFranArkiv'),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// Single button in the add recipe grid.
class _AddRecipeButton extends StatelessWidget {
  const _AddRecipeButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: Material(
        color: color,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          child: Padding(
            padding: const EdgeInsets.all(AppDimensions.spacingMd),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  icon,
                  size: AppDimensions.iconSizeXl,
                  color: Theme.of(context).colorScheme.onPrimary,
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  label,
                  style: AppTextStyles.labelMedium.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
