// lib/widgets/common/navigation/add_sheet.dart
//
// PQ-17: what the shell's plus opens. Skarmar v12 del 1 #plussheet: "Mitten-
// plus öppnar ark: Snabbspara är arkets enda fyllda hjältehandling,
// importvägarna ligger som pappersytor med inkkontur. Handtag i
// border-control, 12 px överkant. Fokus flyttas in i arket, fälls in och
// återgår till plusknappen vid stängning."
//
// The modal route moves focus into the sheet and hands it back to the plus
// when the sheet closes; the sheet's 12 px top edge is the theme's
// (navigation_themes.dart bottomSheetTheme).
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Opens the add sheet. A choice closes the sheet and opens its view on the
/// navigator below it, so Back returns to where the plus was.
Future<void> showButleryAddSheet(BuildContext context) {
  final navigator = Navigator.of(context);
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    // surface.base, as drawn (#plussheet); the handle is the theme's.
    backgroundColor: cs.surface,
    builder: (sheetContext) => ButleryAddSheet(
      onChoose: (route) {
        Navigator.of(sheetContext).pop();
        navigator.pushNamed(route);
      },
    ),
  );
}

/// The sheet's content: the hero "Snabbspara" and the import routes.
class ButleryAddSheet extends StatelessWidget {
  const ButleryAddSheet({required this.onChoose, super.key});

  /// Called with the chosen view's route.
  final ValueChanged<String> onChoose;

  static const Key quickSaveKey = ValueKey<String>('test-add-sheet-quick-save');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    const gap = SizedBox(width: AppDimensions.spacingSm);
    return SingleChildScrollView(
      padding: const EdgeInsetsDirectional.fromSTEB(
        AppDimensions.layoutMargin,
        0,
        AppDimensions.layoutMargin,
        AppDimensions.layoutMargin,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(l10n.addRecipeTitle, style: AppTextStyles.subpageTitle),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          // The sheet's one filled hero (#plussheet): action.primary behind
          // text.onActionPrimary, the named hero style in both modes.
          Semantics(
            identifier: 'btn-quick-save',
            child: FilledButton(
              key: quickSaveKey,
              style: ComponentThemes.heroButtonStyle(cs).copyWith(
                alignment: AlignmentDirectional.centerStart,
                padding: const WidgetStatePropertyAll(
                  EdgeInsets.symmetric(
                    horizontal: AppDimensions.spacingMd,
                    vertical: AppDimensions.spacingSm,
                  ),
                ),
              ),
              onPressed: () => onChoose(Routes.quickCapture),
              child: Row(
                children: [
                  const ButleryIcon(ButleryIcons.zap),
                  const SizedBox(width: AppDimensions.spacingSm),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.addSheetQuickSaveTitle,
                          style: AppTextStyles.labelLarge,
                        ),
                        Text(
                          l10n.addSheetQuickSaveSubtitle,
                          style: AppTextStyles.captionBase,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Row(
            children: [
              _RouteTile(
                identifier: 'btn-import-url',
                label: l10n.recipeImportLink,
                icon: ButleryIcons.link,
                onTap: () => onChoose(Routes.smartImport),
              ),
              gap,
              _RouteTile(
                identifier: 'btn-write-manually',
                label: l10n.recipeWriteManually,
                icon: ButleryIcons.pencil,
                onTap: () => onChoose(Routes.manualEntry),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Row(
            children: [
              _RouteTile(
                identifier: 'btn-photo-import',
                label: l10n.recipeFromImage,
                icon: ButleryIcons.image,
                onTap: () => onChoose(Routes.photoImport),
              ),
              gap,
              _RouteTile(
                identifier: 'btn-archive-import',
                label: l10n.recipeFromArchive,
                icon: ButleryIcons.archive,
                onTap: () => onChoose(Routes.importFromArchive),
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          // Not drawn in #plussheet. Voice import was reachable from the old
          // "lägg till" tab, so it stays one tap away here, as a paper tile
          // like the other import routes.
          Row(
            children: [
              _RouteTile(
                identifier: 'btn-voice-import',
                label: l10n.recipeVoiceImport,
                icon: ButleryIcons.mic,
                onTap: () => onChoose(Routes.voiceImport),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A paper tile with an ink outline (#plussheet): surface.base with a 1.5 px
/// text.primary edge and text.primary content, which is ink in light mode and
/// paper in dark mode (tokens.json semantic text.primary).
class _RouteTile extends StatelessWidget {
  const _RouteTile({
    required this.identifier,
    required this.label,
    required this.icon,
    required this.onTap,
  });

  final String identifier;
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  static const double _edge = 1.5;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      side: BorderSide(color: cs.onSurface, width: _edge),
    );
    return Expanded(
      child: Semantics(
        identifier: identifier,
        button: true,
        child: Material(
          key: ValueKey('test-add-sheet-$identifier'),
          color: cs.surface,
          shape: shape,
          child: InkWell(
            customBorder: shape,
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingSm,
                  vertical: AppDimensions.spacingMd,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    ButleryIcon(icon, color: cs.onSurface),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      label,
                      textAlign: TextAlign.center,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurface,
                        fontWeight: FontWeight.w600,
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
