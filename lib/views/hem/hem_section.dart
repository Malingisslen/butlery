// lib/views/hem/hem_section.dart
//
// HEM-HERO (package 6): the top of Hem, above the recipe library.
//
//   Skarmar v12 del 1 #hemrecept (:124-150): "hälsning + ikväll överst,
//       receptbiblioteket direkt under". The date line and the greeting, then
//       the ink "Ikväll" band with "Börja laga" (saffron), "Byt rätt"
//       (outlined in paper) and the pantry line "allt i skafferiet".
//   Skarmar v12 del 4 #hemladdar (:616-650) and #hemfel (:704-742): in
//       hem_plan_states.dart.
//   Skarmar v12 del 4 #hemoffline (:651-703): the offline banner at the top
//       (P3-U05, mounted by the view), the plan as usual, and under it
//       "Planen hämtades 07:12 — kan ha ändrats av någon annan sedan dess."
//   produktregler.md:276-280 (§ 6.2) the greeting by the clock and the date
//       "Torsdag 9 juli", proportional, neither a control.
//   Grafisk manual v6:219 and produktregler.md:292: one saffron action.
//
// Interpretations:
// * "Byt rätt" and "Visa sparad plan" open the week menu (the Meny tab),
//   where the dish is changed and the saved plan is shown; no drawing shows
//   where they lead.
// * The ink band takes surface.ink in both modes (tokens.json:112-115); what
//   stands on it takes its on-ink values (see _TonightCard).
// * The buttons keep the 48 dp touch target (tokens.json touchTarget.min);
//   #hemrecept draws them 40 px tall.
// * The build differs from the drawings, for lack of a token
//   that carries both drawn values (Skarmar v12 del 1 and del 4 slot values):
//   - Muted text (the date line, #hemtom's body and "Snabbaste vägarna",
//     #hemladdar's text, #hemoffline's "Planen hämtades") is drawn in
//     --r04slot-620, #627061 light and #C9D3C4 dark. #C9D3C4 is
//     text.bodyMuted dark (tokens.json:174-177), but text.bodyMuted light is
//     #37453A, so it is built as text.secondary (onSurfaceVariant, #5B6959 /
//     #A9B2A0, tokens.json). The dark value needs the same missing
//     member (D1) as the rail's.
//   - The #hemladdar skeleton and the #hemtom allergy note are drawn in
//     --r04slot-836 / -832, #E6EAD9 light and #24382C dark. No token has
//     that pair; they are built as surface.raised (primaryContainer, #E6EAD9
//     / #2F4437, tokens.json:108-111).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/viewmodels/hem/hem_viewmodel.dart';
import 'package:butlery/views/hem/hem_plan_states.dart';
import 'package:butlery/widgets/common/butlery_focus_ring.dart';

/// The greeting for the hour of [now] (produktregler.md:278): 05–11 "God
/// morgon", 11–17 "Hej", 17–22 "God kväll", 22–05 "God natt".
String hemGreeting(AppLocalizations l10n, DateTime now) {
  final h = now.hour;
  if (h >= 5 && h < 11) return l10n.hemGreetingMorning;
  if (h >= 11 && h < 17) return l10n.hemGreetingDay;
  if (h >= 17 && h < 22) return l10n.hemGreetingEvening;
  return l10n.hemGreetingNight;
}

/// The first name out of a profile's display name, or null when there is
/// none ("saknas det står bara hälsningen", produktregler.md:278).
String? hemFirstName(String? displayName) {
  final trimmed = displayName.orEmpty().trim();
  if (trimmed.isEmpty) return null;
  return trimmed.split(RegExp(r'\s+')).first;
}

/// "Torsdag 9 juli": the weekday written out, no full stop, no year
/// (produktregler.md:279).
String hemDate(BuildContext context, DateTime now) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final text = DateFormat('EEEE d MMMM', locale).format(now);
  return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
}

/// The top of Hem: the greeting and what the week's plan says about tonight.
class HemSection extends StatelessWidget {
  const HemSection({
    required this.viewModel,
    required this.now,
    required this.firstName,
    required this.libraryEmpty,
    required this.isOnline,
    required this.onStartCooking,
    required this.onOpenMenu,
    super.key,
  });

  final HemViewModel viewModel;

  /// The time the greeting and date are for.
  final DateTime now;

  /// The profile's first name, or null.
  final String? firstName;

  /// The library has no recipes: the greeting is "Välkommen" and the plan
  /// is not shown (produktregler.md:271, row 4; #hemtom).
  final bool libraryEmpty;

  /// Whether the device is online; offline, the plan carries its fetch time.
  final bool isOnline;

  final ValueChanged<Recipe> onStartCooking;

  /// Opens the week menu ("Byt rätt", "Visa sparad plan").
  final VoidCallback onOpenMenu;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: viewModel,
      builder: (context, _) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          HemGreeting(now: now, firstName: firstName, welcome: libraryEmpty),
          if (!libraryEmpty) ..._plan(context),
        ],
      ),
    );
  }

  List<Widget> _plan(BuildContext context) {
    switch (viewModel.status) {
      case HemPlanStatus.loading:
        return const [HemPlanLoading()];
      case HemPlanStatus.failed:
        return [
          HemPlanError(onRetry: viewModel.load, onShowSavedPlan: onOpenMenu),
        ];
      case HemPlanStatus.ready:
        final hero = viewModel.hero;
        if (hero == null) return const [];
        final fetchedAt = viewModel.fetchedAt;
        return [
          const SizedBox(height: AppDimensions.space12),
          HemTonightCard(
            hero: hero,
            onStartCooking: onStartCooking,
            onSwap: onOpenMenu,
          ),
          if (!isOnline && fetchedAt != null)
            HemFetchedAtLine(fetchedAt: fetchedAt),
        ];
    }
  }
}

/// The date line and the greeting (#hemrecept :128-131; #hemtom :101-102).
class HemGreeting extends StatelessWidget {
  const HemGreeting({
    required this.now,
    required this.firstName,
    required this.welcome,
    super.key,
  });

  final DateTime now;
  final String? firstName;

  /// The empty state's "Välkommen" in place of the greeting by the clock.
  final bool welcome;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final greeting = welcome ? l10n.hemGreetingWelcome : hemGreeting(l10n, now);
    final name = firstName;
    final date = hemDate(context, now);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        AppDimensions.spacingLg,
        AppDimensions.spacingLg,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drawn in capitals (text-transform); read as written.
          Semantics(
            label: date,
            child: ExcludeSemantics(
              child: Text(
                date.toUpperCase(),
                key: const ValueKey('hem-date'),
                // text.secondary: #5B6959 light, #A9B2A0 dark
                // (tokens.json:62-65), colorScheme.onSurfaceVariant.
                style: AppTextStyles.labelMedium.copyWith(
                  color: cs.onSurfaceVariant,
                  letterSpacing: 2,
                ),
              ),
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          Semantics(
            header: true,
            child: Text(
              name == null
                  ? greeting
                  : l10n.hemGreetingWithName(greeting, name),
              key: const ValueKey('hem-greeting'),
              // Display compact 26/700 in text.primary (onSurface).
              style: AppTextStyles.displaySmall.copyWith(color: cs.onSurface),
            ),
          ),
        ],
      ),
    );
  }
}

/// The ink "Ikväll" band (#hemrecept :133-141).
///
/// Colours on surface.ink, the same in both modes:
/// * surface: surface.ink #24382C, colorScheme.primary in both schemes
///   (tokens.json:112-115);
/// * eyebrow: context.modeColors.accentOnInk (#hemrecept :134 draws #e09d50
///   light, #dca968 dark): text.accent #DCA968 in dark, 5.91:1, like every
///   other accent text (produktbeslut R6-01 = A); palette.saffronLight
///   #E09D50 in light, 5.43:1, because text.accent's light #A15A0A is
///   2.37:1 on ink;
/// * the dot and "Börja laga": action.primary saffron #CE7C1E with
///   text.onActionPrimary #17251D (tokens.json:137-140, :81-85);
/// * title and "Byt rätt": paper #F5F4ED, colorScheme.onPrimary;
/// * "Byt rätt" outline: paper at the on-ink 0.35 step (tokens.json:40-53),
///   drawn `rgba(245,244,237,.35)`;
/// * pantry line: #A9B2A0, AppModeColors.textSecondaryOnInk, drawn
///   `color:#93a48d`;
/// * focus rings: paper, as on every dark surface (tokens.json:155-160).
class HemTonightCard extends StatelessWidget {
  const HemTonightCard({
    required this.hero,
    required this.onStartCooking,
    required this.onSwap,
    super.key,
  });

  final HemHero hero;
  final ValueChanged<Recipe> onStartCooking;
  final VoidCallback onSwap;

  static const Key startCookingKey = ValueKey('hem-start-cooking');
  static const Key swapKey = ValueKey('hem-swap-dish');
  static const Key cardKey = ValueKey('hem-tonight-card');

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final recipe = hero.recipe;
    final paper = cs.onPrimary;
    final label = hero.isTonight
        ? l10n.hemTonight
        : _weekday(context, hero.entry.day.isoWeekday);
    final meta = [
      label,
      if (recipe?.timeMinutes != null)
        l10n.hemMetaMinutes(recipe!.timeMinutes!),
      if (recipe?.portions != null) l10n.hemMetaPortions(recipe!.portions!),
    ].join(' · ');

    return Container(
      key: cardKey,
      color: cs.primary,
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        AppDimensions.space12,
        AppDimensions.spacingLg,
        AppDimensions.space12,
      ),
      child: FocusRingSurface(
        brightness: Brightness.dark,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Semantics(
              label: meta,
              child: ExcludeSemantics(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Container(
                      width: 7,
                      height: 7,
                      decoration: BoxDecoration(
                        color: cs.secondary,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 7),
                    Expanded(
                      child: Text(
                        meta.toUpperCase(),
                        style: AppTextStyles.labelMedium.copyWith(
                          color: context.modeColors.accentOnInk,
                          letterSpacing: 1,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              recipe?.title ?? hero.entry.recipeTitle,
              key: const ValueKey('hem-tonight-title'),
              style: AppTextStyles.headlineSmall.copyWith(color: paper),
            ),
            const SizedBox(height: AppDimensions.spacingSm + 2),
            Wrap(
              spacing: AppDimensions.spacingSm,
              runSpacing: AppDimensions.spacingSm,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                if (recipe != null)
                  FilledButton(
                    key: startCookingKey,
                    style: ComponentThemes.heroButtonStyle(cs).copyWith(
                      minimumSize: const WidgetStatePropertyAll(
                        Size(0, AppDimensions.minTouchTarget),
                      ),
                    ),
                    onPressed: () => onStartCooking(recipe),
                    child: Text(l10n.hemStartCooking),
                  ),
                OutlinedButton(
                  key: swapKey,
                  style: OutlinedButton.styleFrom(
                    foregroundColor: paper,
                    minimumSize: const Size(0, AppDimensions.minTouchTarget),
                    side: BorderSide(
                      color: paper.withValues(alpha: 0.35),
                      width: 1.5,
                    ),
                  ),
                  onPressed: onSwap,
                  child: Text(l10n.hemSwapDish),
                ),
                if (hero.allInPantry)
                  Text(
                    l10n.hemAllInPantry,
                    key: const ValueKey('hem-all-in-pantry'),
                    style: AppTextStyles.labelMedium.copyWith(
                      color: AppModeColors.textSecondaryOnInk(),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  static String _weekday(BuildContext context, int isoWeekday) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    // 2024-01-01 is a Monday.
    final day = DateTime(2024, 1, isoWeekday);
    final text = DateFormat('EEEE', locale).format(day);
    return text.isEmpty ? text : text[0].toUpperCase() + text.substring(1);
  }
}

/// "Planen hämtades 07:12 – kan ha ändrats av någon annan sedan dess."
/// (#hemoffline :187; produktregler.md:294, a timestamp, never grey text).
class HemFetchedAtLine extends StatelessWidget {
  const HemFetchedAtLine({required this.fetchedAt, super.key});

  final DateTime fetchedAt;

  @override
  Widget build(BuildContext context) {
    final locale = Localizations.localeOf(context).toLanguageTag();
    final time = DateFormat.Hm(locale).format(fetchedAt);
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.spacingLg,
        AppDimensions.spacingSm,
        AppDimensions.spacingLg,
        0,
      ),
      child: Text(
        context.l10n.hemPlanFetchedAt(time),
        key: const ValueKey('hem-fetched-at'),
        // text.secondary on paper, colorScheme.onSurfaceVariant: #5B6959
        // light, #A9B2A0 dark (tokens.json).
        style: AppTextStyles.labelMedium.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
