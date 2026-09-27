// lib/views/hem/hem_empty_state.dart
//
// HEM-HERO: Hem with no recipes, Skarmar v12 del 4 #hemtom (:587-615) and
// produktregler.md:284-288 (§ 6.4): "Beskriver läget, inte problemet, och har
// en hjältehandling: Lägg till recept. Under den ligger högst tre genvägar
// som förklarar sig med en rad var. Allergipåminnelsen ligger sist och är en
// länk, inte en dialog." No illustration (B-19).
//
// The greeting above it ("Välkommen, Maja") is HemGreeting in HemSection.
//
// Interpretations:
// * The card title is 19/700 in the drawing; the nearest role is titleLarge
//   (17/600) in bold.
// * The allergy note's surface is surface.raised (tokens.json:108-111);
//   the drawing's slot is #e6ead9 in light mode.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';

/// Hem when the library is empty (#hemtom).
class HemEmptyState extends StatelessWidget {
  const HemEmptyState({super.key});

  static const Key addRecipeKey = ValueKey('hem-empty-add-recipe');
  static const Key allergyLinkKey = ValueKey('hem-empty-allergy-link');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final b = cs.brightness;
    final shortcuts = [
      (
        route: Routes.smartImport,
        title: l10n.hemEmptyLinkTitle,
        body: l10n.hemEmptyLinkBody,
        icon: Icons.link,
      ),
      (
        route: Routes.photoImport,
        title: l10n.hemEmptyPhotoTitle,
        body: l10n.hemEmptyPhotoBody,
        icon: Icons.photo_camera_outlined,
      ),
      (
        route: Routes.manualEntry,
        title: l10n.hemEmptyWriteTitle,
        body: l10n.hemEmptyWriteBody,
        icon: Icons.edit_outlined,
      ),
    ];

    return SingleChildScrollView(
      key: const ValueKey('hem-empty-state'),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        AppDimensions.spacingLg - 2,
        AppDimensions.spacingLg,
        AppDimensions.spacingLg,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The card: border.subtle outline (colorScheme.outlineVariant,
          // #CCD1C2 light, rgba(245,244,237,.18) dark; tokens.json:124-127).
          Container(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.spacingMd + 4,
              AppDimensions.spacingLg - 2,
              AppDimensions.spacingMd + 4,
              AppDimensions.spacingLg - 2,
            ),
            decoration: BoxDecoration(
              border: Border.all(color: cs.outlineVariant),
              borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.hemEmptyTitle,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: cs.onSurface,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingSm),
                Text(
                  l10n.hemEmptyBody,
                  // text.secondary (onSurfaceVariant), as drawn.
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.spacingMd),
                // The one saffron action (produktregler.md:286).
                Semantics(
                  identifier: 'btn-add-recipe',
                  child: FilledButton.icon(
                    key: addRecipeKey,
                    style: ComponentThemes.heroButtonStyle(cs),
                    onPressed: () =>
                        Navigator.pushNamed(context, Routes.addRecipe),
                    icon: const Icon(Icons.add),
                    label: Text(l10n.addRecipeTitle),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.spacingMd + 4),
          Text(
            l10n.hemEmptyShortcuts.toUpperCase(),
            semanticsLabel: l10n.hemEmptyShortcuts,
            style: AppTextStyles.labelSmall.copyWith(
              color: cs.onSurfaceVariant,
              letterSpacing: 1.5,
            ),
          ),
          const SizedBox(height: AppDimensions.space4),
          for (final shortcut in shortcuts)
            _ShortcutRow(
              route: shortcut.route,
              title: shortcut.title,
              body: shortcut.body,
              icon: shortcut.icon,
            ),
          const SizedBox(height: AppDimensions.spacingMd + 4),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space12,
              vertical: AppDimensions.spacingSm + AppDimensions.spacingXs,
            ),
            decoration: BoxDecoration(
              color: cs.primaryContainer,
              borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
            ),
            child: Text(
              l10n.hemEmptyAllergyNote,
              // text.body: #37453A light, #F5F4ED dark (tokens.json:58-60).
              style: AppTextStyles.labelMedium.copyWith(
                color: AppModeColors.textBody(b),
                fontWeight: FontWeight.w400,
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: TextButton.icon(
              key: allergyLinkKey,
              // text.link: #8A5212 light, #DCA968 dark (tokens.json:228-231);
              // #hemtom :118 draws #8a5212.
              style: TextButton.styleFrom(
                foregroundColor: context.modeColors.info,
              ),
              onPressed: () =>
                  Navigator.pushNamed(context, Routes.settingsAllergens),
              iconAlignment: IconAlignment.end,
              icon: const Icon(Icons.chevron_right),
              label: Text(l10n.hemEmptyAllergyLink),
            ),
          ),
        ],
      ),
    );
  }
}

/// One shortcut: a title with its one-line explanation, 64 dp tall, a
/// border.subtle rule under it (#hemtom :115).
class _ShortcutRow extends StatelessWidget {
  const _ShortcutRow({
    required this.route,
    required this.title,
    required this.body,
    required this.icon,
  });

  final String route;
  final String title;
  final String body;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      identifier: 'hem-shortcut-$route',
      child: InkWell(
        key: ValueKey('hem-shortcut-$route'),
        onTap: () => Navigator.pushNamed(context, route),
        child: Container(
          constraints: const BoxConstraints(minHeight: 64),
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: cs.outlineVariant)),
          ),
          child: Row(
            children: [
              Icon(icon, color: cs.onSurface, size: AppDimensions.iconSizeM),
              const SizedBox(width: AppDimensions.spacingSm + 4),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: AppDimensions.spacingSm,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        body,
                        style: AppTextStyles.labelMedium.copyWith(
                          color: cs.onSurfaceVariant,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: cs.onSurfaceVariant,
                size: AppDimensions.iconSizeM,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
