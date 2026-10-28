// lib/widgets/common/state/hem_empty_state.dart
//
// HEM-HERO: Hem with no recipes
// No illustration (B-19).
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
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';

import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/widgets/common/navigation/add_sheet.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';

/// Hem when the library is empty.
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
        icon: ButleryIcons.link,
      ),
      (
        route: Routes.photoImport,
        title: l10n.hemEmptyPhotoTitle,
        body: l10n.hemEmptyPhotoBody,
        icon: ButleryIcons.camera,
      ),
      (
        route: Routes.manualEntry,
        title: l10n.hemEmptyWriteTitle,
        body: l10n.hemEmptyWriteBody,
        icon: ButleryIcons.pencil,
      ),
    ];

    return SingleChildScrollView(
      key: const ValueKey('hem-empty-state'),
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.space24,
        AppDimensions.space24,
        AppDimensions.space24,
        AppDimensions.space24,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // The card: border.subtle outline (colorScheme.outlineVariant,
          // #CCD1C2 light, rgba(245,244,237,.18) dark; tokens.json:124-127).
          ButleryOutlinedBox(
            padding: const EdgeInsets.fromLTRB(
              AppDimensions.space24,
              AppDimensions.space24,
              AppDimensions.space24,
              AppDimensions.space24,
            ),
            borderColor: cs.outlineVariant,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    l10n.hemEmptyTitle,
                    style: AppTextStyles.titleLargeBold.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
                const SizedBox(height: AppDimensions.space8),
                Text(
                  l10n.hemEmptyBody,
                  // text.secondary (onSurfaceVariant), as drawn.
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppDimensions.space16),
                // The one saffron action.
                Semantics(
                  identifier: 'btn-add-recipe',
                  child: HeroButton(
                    key: addRecipeKey,
                    onPressed: () => showButleryAddSheet(context),
                    icon: ButleryIcons.plus,
                    label: l10n.addRecipeTitle,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space24),
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
          const SizedBox(height: AppDimensions.space24),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppDimensions.space12,
              vertical: AppDimensions.space12,
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
              ),
            ),
          ),
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: ButleryTextButton(
              key: allergyLinkKey,
              tone: ButleryTextButtonTone.link,
              onPressed: () =>
                  Navigator.pushNamed(context, Routes.settingsAllergens),
              icon: ButleryIcons.chevronRight,
              iconAtEnd: true,
              label: l10n.hemEmptyAllergyLink,
            ),
          ),
        ],
      ),
    );
  }
}

/// One shortcut: a title with its one-line explanation, 64 dp tall, a
/// border.subtle rule under it.
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
      child: PressFill(
        surface: PressSurface.base,
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
                ButleryIcon(
                  icon,
                  color: cs.onSurface,
                  size: AppDimensions.iconSizeM,
                ),
                const SizedBox(width: AppDimensions.space12),
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      vertical: AppDimensions.space8,
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
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const ButleryChevron(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
