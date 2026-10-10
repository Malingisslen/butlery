import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/distinct_initials.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/diner_profile.dart';
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/models/user_allergen_preferences.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

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

/// Parse a stored `#RRGGBB` hex into a [Color]; falls back to the theme's
/// primary.
Color parseAvatarColor(BuildContext context, String? hex) {
  if (hex != null && hex.startsWith('#') && hex.length == 7) {
    final value = int.tryParse(hex.substring(1), radix: 16);
    if (value != null) return Color(value).withAlpha(255);
  }
  return Theme.of(context).colorScheme.primary;
}

/// Square colored avatar with initials (SQUARE design language).
class FamilyAvatar extends StatelessWidget {
  final String name;
  final Color color;
  final double size;
  final String? initials;

  const FamilyAvatar({
    super.key,
    required this.name,
    required this.color,
    this.size = 42,
    this.initials,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: color,
      alignment: Alignment.center,
      child: Text(
        initials ?? initialsFor(name),
        style: AppTextStyles.bodyMedium.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

/// Joins a row's facts with " · " and starts the line with a capital, since
/// the age-band and role labels are written in lower case for running text.
String _subtitle(List<String> parts) {
  final line = parts.join(' · ');
  if (line.isEmpty) return line;
  return line[0].toUpperCase() + line.substring(1);
}

/// The leading avatar and the two lines every family row draws, at the size
/// and spacing of a ButleryListRow so the rows sit in its sections.
class _FamilyRowContent extends StatelessWidget {
  final Widget avatar;
  final String name;
  final String subtitle;
  final bool chevron;

  const _FamilyRowContent({
    required this.avatar,
    required this.name,
    required this.subtitle,
    this.chevron = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.minTouchTarget,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(
          vertical: AppDimensions.spacingSm + 2,
        ),
        child: Row(
          children: [
            avatar,
            const SizedBox(width: AppDimensions.spacingL),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  if (subtitle.isNotEmpty)
                    Text(
                      subtitle,
                      style: AppTextStyles.captionBase.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (chevron) ...[
              const SizedBox(width: AppDimensions.spacingSm),
              ExcludeSemantics(
                child: ButleryIcon(
                  ButleryIcons.chevronRight,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Read-only row for a household account holder.
class FamilyAccountRow extends StatelessWidget {
  final HouseholdRosterMember member;
  final bool isAdmin;
  final bool isCurrentUser;
  final String? initials;

  const FamilyAccountRow({
    super.key,
    required this.member,
    required this.isAdmin,
    this.isCurrentUser = false,
    this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final parts = [
      if (isCurrentUser) l10n.familyYou,
      if (isAdmin) l10n.familyRoleAdmin,
    ];
    return Semantics(
      container: true,
      child: _FamilyRowContent(
        avatar: FamilyAvatar(
          name: member.displayName,
          color: parseAvatarColor(context, member.avatarColor),
          size: _avatarSize,
          initials: initials,
        ),
        name: member.displayName,
        subtitle: _subtitle(parts.isEmpty ? [l10n.ageBandAdult] : parts),
      ),
    );
  }
}

/// Tappable row for a non-account family member (opens the edit form).
class FamilyMemberRow extends StatelessWidget {
  final DinerProfile profile;
  final VoidCallback onTap;
  final String? initials;

  const FamilyMemberRow({
    super.key,
    required this.profile,
    required this.onTap,
    this.initials,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final allergens =
        profile.allergenPreferences?.trackedAllergens
            .map(AllergenPreferenceOptions.getAllergenLabel)
            .join(', ') ??
        '';

    return Semantics(
      container: true,
      button: true,
      label: l10n.a11yEditFamilyMember,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: onTap,
          child: _FamilyRowContent(
            avatar: FamilyAvatar(
              name: profile.name,
              color: parseAvatarColor(context, profile.avatarColor),
              size: _avatarSize,
              initials: initials,
            ),
            name: profile.name,
            subtitle: _subtitle([
              ageBandLabel(l10n, profile.ageBand),
              if (allergens.isNotEmpty) allergens,
            ]),
            chevron: true,
          ),
        ),
      ),
    );
  }
}

const double _avatarSize = 36;
