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

/// BUT-403 identifier scheme (browser a11y tree hooks):
///  - `btn-quick-save`  → Snabbspara (top full-width button)
///  - `btn-import-url`  → "Importera länk" grid button
///  - `btn-write-manually` → "Skriv manuellt" grid button
///  - `btn-photo-import` → "Från bild" grid button
///  - `btn-archive-import` → "Från arkiv" grid button
///
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
                  // Quick capture — full-width entry point. Title + subtitle
                  // clarify that this saves only name + meal type (no import).
                  Semantics(
                    identifier: 'btn-quick-save',
                    button: true,
                    label: context.l10n.quickCaptureTitle,
                    child: FilledButton(
                      key: const ValueKey('test-lagg-till-quick-save'),
                      onPressed: () => _navigate(context, Routes.quickCapture),
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(
                          AppDimensions.buttonHeight,
                        ),
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppDimensions.paddingL,
                          vertical: AppDimensions.paddingM,
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.flash_on),
                          const SizedBox(width: AppDimensions.spacingSm),
                          Flexible(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  context.l10n.quickCaptureTitle,
                                  style: AppTextStyles.labelLarge,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  context.l10n.quickCaptureSubtitle,
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Theme.of(context)
                                        .colorScheme
                                        .onPrimary
                                        .withValues(alpha: 0.85),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
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
        final buttonSize = buttonWidth < buttonHeight
            ? buttonWidth
            : buttonHeight;

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
                    key: const ValueKey('test-lagg-till-import-url'),
                    semanticIdentifier: 'btn-import-url',
                    label: context.l10n.recipeImportLink,
                    icon: Icons.link,
                    color: Theme.of(context).colorScheme.secondary,
                    size: size,
                    onTap: () => _navigate(context, '/smartImport'),
                  ),
                  const SizedBox(width: spacing),
                  _AddRecipeButton(
                    key: const ValueKey('test-lagg-till-write-manually'),
                    semanticIdentifier: 'btn-write-manually',
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
                    key: const ValueKey('test-lagg-till-photo-import'),
                    semanticIdentifier: 'btn-photo-import',
                    label: context.l10n.recipeFromImage,
                    icon: Icons.image,
                    color: Theme.of(context).colorScheme.primary,
                    size: size,
                    onTap: () => _navigate(context, '/photoImport'),
                  ),
                  const SizedBox(width: spacing),
                  _AddRecipeButton(
                    key: const ValueKey('test-lagg-till-archive-import'),
                    semanticIdentifier: 'btn-archive-import',
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
    super.key,
    required this.label,
    required this.icon,
    required this.color,
    required this.size,
    required this.onTap,
    this.semanticIdentifier,
  });

  final String label;
  final IconData icon;
  final Color color;
  final double size;
  final VoidCallback onTap;

  /// BUT-403 — identifier exposed on the browser a11y tree.
  final String? semanticIdentifier;

  @override
  Widget build(BuildContext context) {
    final tile = SizedBox(
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

    if (semanticIdentifier != null) {
      return Semantics(
        identifier: semanticIdentifier,
        button: true,
        label: label,
        child: tile,
      );
    }
    return tile;
  }
}
