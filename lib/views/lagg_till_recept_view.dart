// lib/views/lagg_till_recept_view.dart

import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// BUT-403 identifier scheme (browser a11y tree hooks):
///  - `btn-quick-save`  → Snabbspara (top full-width button)
///  - `btn-import-url`  → "Importera länk" grid button
///  - `btn-write-manually` → "Skriv manuellt" grid button
///  - `btn-photo-import` → "Från bild" grid button
///  - `btn-archive-import` → "Från arkiv" grid button
class LaggTillReceptView extends StatelessWidget {
  const LaggTillReceptView({super.key});

  void _navigate(BuildContext context, String routeName) {
    Navigator.pushNamed(context, routeName);
  }

  @override
  Widget build(BuildContext context) {
    final padding = AppDimensions.responsiveContentPadding(context);

    return Scaffold(
      // The root bar for now (Komponentark v1:60-68). Whether "Lägg till"
      // stays a tab or becomes an action in the shell is Q-P4-06b
      // (produktregler.md:1056) and is not decided here.
      appBar: ButleryTopBar.rot(title: context.l10n.addRecipeTitle),
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
                          const ButleryIcon(ButleryIcons.zap),
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
                                  // Full paper on ink, never a faded
                                  // copy (tokens.json:40-53 opacityLadder).
                                  style: AppTextStyles.labelSmall.copyWith(
                                    color: Theme.of(
                                      context,
                                    ).colorScheme.onPrimary,
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
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AddRecipeButton(
                    key: const ValueKey('test-lagg-till-import-url'),
                    semanticIdentifier: 'btn-import-url',
                    label: context.l10n.recipeImportLink,
                    icon: ButleryIcons.link,
                    saffron: true,
                    size: size,
                    onTap: () => _navigate(context, '/smartImport'),
                  ),
                  const SizedBox(width: spacing),
                  _AddRecipeButton(
                    key: const ValueKey('test-lagg-till-write-manually'),
                    semanticIdentifier: 'btn-write-manually',
                    label: context.l10n.recipeWriteManually,
                    icon: ButleryIcons.pencil,
                    saffron: false,
                    size: size,
                    onTap: () => _navigate(context, '/skrivSjalv'),
                  ),
                ],
              ),
              const SizedBox(height: spacing),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AddRecipeButton(
                    key: const ValueKey('test-lagg-till-photo-import'),
                    semanticIdentifier: 'btn-photo-import',
                    label: context.l10n.recipeFromImage,
                    icon: ButleryIcons.image,
                    saffron: false,
                    size: size,
                    onTap: () => _navigate(context, '/photoImport'),
                  ),
                  const SizedBox(width: spacing),
                  _AddRecipeButton(
                    key: const ValueKey('test-lagg-till-archive-import'),
                    semanticIdentifier: 'btn-archive-import',
                    label: context.l10n.recipeFromArchive,
                    icon: ButleryIcons.archive,
                    saffron: true,
                    size: size,
                    onTap: () => _navigate(context, '/importFranArkiv'),
                  ),
                ],
              ),
              const SizedBox(height: spacing),
              _AddRecipeButton(
                key: const ValueKey('test-lagg-till-voice-import'),
                semanticIdentifier: 'btn-voice-import',
                label: context.l10n.recipeVoiceImport,
                icon: ButleryIcons.mic,
                saffron: false,
                size: size,
                onTap: () => _navigate(context, '/voiceImport'),
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
    required this.saffron,
    required this.size,
    required this.onTap,
    this.semanticIdentifier,
  });

  final String label;
  final IconData icon;

  /// Saffron (action.primary) rather than ink.
  final bool saffron;
  final double size;
  final VoidCallback onTap;

  /// BUT-403 — identifier exposed on the browser a11y tree.
  final String? semanticIdentifier;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
    );
    Widget content(Color foreground) => Padding(
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ButleryIcon(
            icon,
            size: AppDimensions.iconSizeXl,
            color: foreground,
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            label,
            style: AppTextStyles.labelMedium.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
    final tile = SizedBox(
      width: size,
      height: size,
      child: saffron
          ? SaffronPress(
              shape: shape,
              onTap: onTap,
              builder: (context, pressed) => content(
                pressed
                    ? AppModeColors.onActionPrimaryPressed(cs.brightness)
                    : AppModeColors.onActionPrimary(cs.brightness),
              ),
            )
          : Material(
              color: cs.primary,
              shape: shape,
              child: PressFill(
                surface: PressSurface.ink,
                child: InkWell(
                  onTap: onTap,
                  customBorder: shape,
                  child: content(cs.onPrimary),
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
