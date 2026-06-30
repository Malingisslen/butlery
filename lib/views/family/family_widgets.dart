import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

/// Swedish (localized) label for a coarse age band.
String ageBandLabel(AppLocalizations l10n, DinerAgeBand band) {
  switch (band) {
    case DinerAgeBand.toddler:
      return l10n.ageBandToddler;
    case DinerAgeBand.child:
      return l10n.ageBandChild;
    case DinerAgeBand.teen:
      return l10n.ageBandTeen;
    case DinerAgeBand.adult:
      return l10n.ageBandAdult;
  }
}

/// Parse a stored `#RRGGBB` hex into a [Color]; falls back to the brand green.
Color parseAvatarColor(String? hex) {
  if (hex != null && hex.startsWith('#') && hex.length == 7) {
    final value = int.tryParse(hex.substring(1), radix: 16);
    if (value != null) return Color(0xFF000000 | value);
  }
  // Context-less helper: fall back to the brand forest-green literal
  // (0xFF4A7C59, the value behind cs.primary) so callers in other files
  // need no signature change.
  return const Color(0xFF4A7C59);
}

String _initials(String name) {
  final parts = name.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty);
  if (parts.isEmpty) return '?';
  if (parts.length == 1) return parts.first.characters.first.toUpperCase();
  return (parts.first.characters.first + parts.last.characters.first)
      .toUpperCase();
}

/// A rust-accented section divider (mirrors the settings section style).
class FamilySectionHeader extends StatelessWidget {
  final String title;
  final String? trailing;

  const FamilySectionHeader({super.key, required this.title, this.trailing});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      header: true,
      child: Container(
        padding: const EdgeInsetsDirectional.only(
          start: AppDimensions.paddingM,
        ),
        decoration: BoxDecoration(
          border: Border(left: BorderSide(color: cs.secondary, width: 3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: AppTextStyles.titleSmall.copyWith(color: cs.primary),
            ),
            if (trailing != null)
              Text(
                trailing!,
                style: AppTextStyles.bodySmall.copyWith(
                  color: cs.outline,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Square colored avatar with initials (SQUARE design language).
class FamilyAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;

  const FamilyAvatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 42,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: color,
      alignment: Alignment.center,
      child: Text(
        _initials(name),
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  final bool emphasized;
  const _TagChip(this.label, {this.emphasized = false});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: emphasized ? context.butleryColors.heroPaleGreen : cs.surface,
        border: Border.all(
          color: emphasized ? cs.primary : cs.outlineVariant,
        ),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionText.copyWith(
          color: emphasized ? cs.primary : cs.outline,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

class _AllergenBadge extends StatelessWidget {
  final String label;
  const _AllergenBadge(this.label);

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      color: cs.error.withValues(alpha: 0.1),
      child: Text(
        label,
        style: AppTextStyles.captionText.copyWith(
          color: cs.error,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Read-only row for a household account holder.
class FamilyAccountRow extends StatelessWidget {
  final HouseholdRosterMember member;
  final bool isAdmin;

  const FamilyAccountRow({
    super.key,
    required this.member,
    required this.isAdmin,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cs.surface,
        border: Border(
          left: BorderSide(color: cs.primary, width: 4),
          bottom: const BorderSide(color: AppColors.rustLight, width: 3),
        ),
      ),
      child: Row(
        children: [
          FamilyAvatar(
            name: member.displayName,
            color: parseAvatarColor(member.avatarColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(member.displayName, style: AppTextStyles.titleSmall),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    if (isAdmin)
                      _TagChip(l10n.familyRoleAdmin, emphasized: true),
                    _TagChip(l10n.ageBandAdult),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Tappable row for a non-account family member (opens the edit form).
class FamilyMemberRow extends StatelessWidget {
  final DinerProfile profile;
  final VoidCallback onTap;

  const FamilyMemberRow({
    super.key,
    required this.profile,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final allergens =
        profile.allergenPreferences?.trackedAllergens.toList() ?? const [];

    return Semantics(
      button: true,
      label: l10n.a11yEditFamilyMember,
      child: InkWell(
        onTap: onTap,
        child: Container(
          margin: const EdgeInsets.only(bottom: 10),
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: cs.surface,
            border: Border(
              left: BorderSide(color: cs.secondary, width: 4),
              bottom: const BorderSide(color: AppColors.rustLight, width: 3),
            ),
          ),
          child: Row(
            children: [
              FamilyAvatar(
                name: profile.name,
                color: parseAvatarColor(profile.avatarColor),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(profile.name, style: AppTextStyles.titleSmall),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 6,
                      runSpacing: 4,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        _TagChip(ageBandLabel(l10n, profile.ageBand)),
                        if (allergens.isEmpty)
                          _TagChip(l10n.familyNoAllergies)
                        else
                          for (final a in allergens)
                            _AllergenBadge(
                              AllergenPreferenceOptions.getAllergenLabel(a),
                            ),
                      ],
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: cs.outline),
            ],
          ),
        ),
      ),
    );
  }
}
