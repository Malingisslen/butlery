// lib/widgets/social/profile_header.dart
//
// The head of a person's page: a round avatar beside the name and one line
// under it, the bio on paper and the person's two figures (Skarmar v12
// del 3 #publikprofil and etapp 5-7 #18). A friend's profile and a public
// profile both draw it, so the two pages cannot drift apart.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/user_avatar.dart';

/// One figure of a person: "14" and "vänner".
class ProfileStat {
  const ProfileStat({required this.value, required this.label});

  final int value;
  final String label;
}

/// How the figures sit under the bio.
enum ProfileStatsLayout {
  /// Each figure large over its label, side by side (a friend's profile).
  stacked,

  /// One running line, the figures in bold ("8 vänner · 12 publika recept").
  inline,
}

class ProfileHeader extends StatelessWidget {
  const ProfileHeader({
    required this.displayName,
    required this.stats,
    this.avatarUrl,
    this.subline,
    this.bio,
    this.statsLayout = ProfileStatsLayout.stacked,
    super.key,
  });

  final String displayName;
  final String? avatarUrl;

  /// "Vänner sedan mars 2026" or "@lovisalagar · medlem sedan 2025".
  final String? subline;

  /// Shown only when it has text.
  final String? bio;

  final List<ProfileStat> stats;
  final ProfileStatsLayout statsLayout;

  static const double _avatarSize = 56;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final hasBio = bio != null && bio!.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            UserAvatar(
              imageUrl: avatarUrl,
              displayName: displayName,
              explicitSize: _avatarSize,
              round: true,
              announceName: false,
            ),
            const SizedBox(width: AppDimensions.space16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Semantics(
                    header: true,
                    child: Text(
                      displayName,
                      style: AppTextStyles.headlineMedium.copyWith(
                        color: cs.onSurface,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (subline != null)
                    Text(
                      subline!,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        if (hasBio) ...[
          const SizedBox(height: AppDimensions.space16),
          Text(bio!, style: AppTextStyles.bodyMedium),
        ],
        if (stats.isNotEmpty) ...[
          const SizedBox(height: AppDimensions.space16),
          statsLayout == ProfileStatsLayout.stacked
              ? _StackedStats(stats: stats)
              : _InlineStats(stats: stats),
        ],
      ],
    );
  }
}

class _StackedStats extends StatelessWidget {
  const _StackedStats({required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var i = 0; i < stats.length; i++) ...[
          if (i > 0) const SizedBox(width: AppDimensions.space24),
          Semantics(
            container: true,
            label: '${stats[i].value} ${stats[i].label}',
            excludeSemantics: true,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${stats[i].value}',
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: cs.onSurface,
                  ),
                ),
                Text(
                  stats[i].label,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _InlineStats extends StatelessWidget {
  const _InlineStats({required this.stats});

  final List<ProfileStat> stats;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final muted = AppTextStyles.bodyMedium.copyWith(color: cs.onSurfaceVariant);
    return Text.rich(
      TextSpan(
        style: muted,
        children: [
          for (var i = 0; i < stats.length; i++) ...[
            if (i > 0) const TextSpan(text: ' · '),
            TextSpan(
              text: '${stats[i].value}',
              style: AppTextStyles.bodyBold.copyWith(color: cs.onSurface),
            ),
            TextSpan(text: ' ${stats[i].label}'),
          ],
        ],
      ),
    );
  }
}
