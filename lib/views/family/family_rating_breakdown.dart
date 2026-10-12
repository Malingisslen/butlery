import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/utils/distinct_initials.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/viewmodels/family/family_rating_breakdown_viewmodel.dart';
import 'package:butlery/views/family/family_rating_entry_view.dart';
import 'package:butlery/views/family/family_widgets.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// Collapsible recipe-detail section: the household's family-rating breakdown
/// (average + per-diner rows), with community + personal comparison for shared
/// recipes. Collapsed by default. Hidden entirely until the household has rated.
/// Each diner row deep-links into the rating-entry screen focused on that
/// member.
class FamilyRatingBreakdown extends StatefulWidget {
  final Recipe recipe;

  const FamilyRatingBreakdown({super.key, required this.recipe});

  @override
  State<FamilyRatingBreakdown> createState() => _FamilyRatingBreakdownState();
}

class _FamilyRatingBreakdownState extends State<FamilyRatingBreakdown> {
  late final FamilyRatingBreakdownViewModel _vm;
  bool _expanded = false;

  @override
  void initState() {
    super.initState();
    _vm = FamilyRatingBreakdownViewModel(recipeId: widget.recipe.id)
      ..startListening();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FamilyRatingBreakdownViewModel>.value(
      value: _vm,
      child: Consumer<FamilyRatingBreakdownViewModel>(
        builder: (context, vm, _) {
          // Nothing to show until the household has rated this recipe.
          if (!vm.hasFamilyRatings) return const SizedBox.shrink();
          return _section(context, vm);
        },
      ),
    );
  }

  Future<void> _editMember(BuildContext context, String memberId) async {
    await showFamilyRatingEntry(
      context,
      recipeId: widget.recipe.id,
      recipeTitle: widget.recipe.title,
      presentMemberIds: [memberId],
    );
    // The live family_ratings listener refreshes the breakdown automatically
    // once the entry write lands — no manual reload needed (BUT-1461).
  }

  Widget _section(BuildContext context, FamilyRatingBreakdownViewModel vm) {
    final l10n = context.l10n;
    final initials = distinctInitials([
      for (final r in vm.rows) r.member.displayName,
    ]);
    return Padding(
      padding: AppDimensions.paddingOnlyTop8,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, vm, l10n),
          if (_expanded) ...[
            Container(
              height: 2,
              margin: const EdgeInsets.only(top: AppDimensions.space4),
              color: Theme.of(context).colorScheme.onSurface,
            ),
            const SizedBox(height: AppDimensions.space12),
            _hero(context, vm, l10n),
            const SizedBox(height: AppDimensions.space8),
            for (var i = 0; i < vm.rows.length; i++)
              _dinerRow(context, vm.rows[i], l10n, initials[i]),
            _comparison(context, l10n),
            _legend(context, l10n),
          ],
        ],
      ),
    );
  }

  Widget _header(
    BuildContext context,
    FamilyRatingBreakdownViewModel vm,
    AppLocalizations l10n,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: _expanded,
      label: l10n.a11yToggleRatingBreakdown,
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: PressSurface.raised,
          child: InkWell(
            onTap: () => setState(() => _expanded = !_expanded),
            child: Container(
              padding: AppDimensions.paddingVertical8,
              decoration: BoxDecoration(
                border: Border(left: BorderSide(color: cs.outline, width: 3)),
              ),
              child: Row(
                children: [
                  const SizedBox(width: AppDimensions.space8),
                  Text(
                    l10n.familyRatingSectionTitle,
                    style: AppTextStyles.bodyBold.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.space8),
                  _familyPill(context, vm.familyAverageDisplay, l10n),
                  const Spacer(),
                  ButleryIcon(
                    _expanded
                        ? ButleryIcons.chevronUp
                        : ButleryIcons.chevronDown,
                    color: cs.outline,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _familyPill(
    BuildContext context,
    String value,
    AppLocalizations l10n, {
    bool large = false,
  }) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: large
          ? const EdgeInsets.symmetric(
              horizontal: AppDimensions.space16,
              vertical: AppDimensions.space8,
            )
          : AppDimensions.statusPillPadding,
      decoration: BoxDecoration(
        color: cs.primary,
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Text(
        l10n.familyRatingHouseholdPill(value),
        style: (large ? AppTextStyles.bodySmallBold : AppTextStyles.labelSmall)
            .copyWith(color: cs.onPrimary),
      ),
    );
  }

  Widget _hero(
    BuildContext context,
    FamilyRatingBreakdownViewModel vm,
    AppLocalizations l10n,
  ) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space4),
      child: Row(
        children: [
          _familyPill(context, vm.familyAverageDisplay, l10n, large: true),
          const SizedBox(width: AppDimensions.space12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.familyRatingAverageLabel,
                style: AppTextStyles.bodyBold,
              ),
              Text(
                l10n.familyRatingCount(vm.familyCount),
                style: AppTextStyles.captionText.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _dinerRow(
    BuildContext context,
    DinerRatingDisplay row,
    AppLocalizations l10n,
    String initials,
  ) {
    final cs = Theme.of(context).colorScheme;
    final isHolder =
        row.member.type == HouseholdMemberType.user && !row.isProxy;
    return Semantics(
      button: true,
      label: l10n.a11yEditMemberRating,
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: PressSurface.raised,
          child: InkWell(
            onTap: () => _editMember(context, row.member.memberId),
            child: Container(
              padding: AppDimensions.paddingVertical8,
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: cs.outlineVariant),
                ),
              ),
              child: Row(
                children: [
                  FamilyAvatar(
                    name: row.member.displayName,
                    color: parseAvatarColor(context, row.member.avatarColor),
                    size: 40,
                    round: true,
                    initials: initials,
                  ),
                  const SizedBox(width: AppDimensions.space8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                row.member.displayName,
                                style: AppTextStyles.bodyBold,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            if (isHolder) ...[
                              const SizedBox(width: AppDimensions.space4),
                              Text(
                                '· ${l10n.familyRatingYou}',
                                style: AppTextStyles.captionBold.copyWith(
                                  color: cs.onSurface,
                                ),
                              ),
                            ],
                          ],
                        ),
                        if (row.isProxy && row.enteredByName != null)
                          Text(
                            '${l10n.familyRatingProxyEntered(row.enteredByName!)}'
                            ' · ${_shortDate(row.lastUpdated)}',
                            style: AppTextStyles.captionText.copyWith(
                              color: cs.onSurfaceVariant,
                              fontStyle: FontStyle.italic,
                            ),
                          )
                        else
                          Text(
                            l10n.familyRatingUpdated(
                              _shortDate(row.lastUpdated),
                            ),
                            style: AppTextStyles.captionText.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  _StarNumber(value: row.stars.toDouble()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Locale-free `d/m` (matches the recipe-comment fallback format).
  String _shortDate(DateTime d) => '${d.day}/${d.month}';

  /// Community average (shared recipes) + the user's own personal rating, shown
  /// as a comparison below the family rows. Sourced from the recipe itself.
  Widget _comparison(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    final recipe = widget.recipe;
    final communityAvg = recipe.core.averageRating;
    final communityCount = recipe.core.ratingCount;
    final showCommunity = !recipe.isPersonal && communityAvg != null;
    final personal = recipe.rating;
    final showPersonal = personal != null && personal > 0;
    if (!showCommunity && !showPersonal) return const SizedBox.shrink();

    return Container(
      margin: AppDimensions.paddingOnlyTop12,
      padding: AppDimensions.paddingOnlyTop12,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant, width: 2)),
      ),
      child: Column(
        children: [
          if (showCommunity)
            _compareRow(
              context,
              color: cs.onSurfaceVariant,
              label: l10n.familyRatingCommunityLabel,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    communityAvg.toStringAsFixed(1).replaceAll('.', ','),
                    style: AppTextStyles.bodyBold.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                  if (communityCount != null) ...[
                    const SizedBox(width: AppDimensions.space4),
                    Text(
                      '· ${l10n.familyRatingCount(communityCount)}',
                      style: AppTextStyles.captionText.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (showCommunity && showPersonal)
            const SizedBox(height: AppDimensions.space12),
          if (showPersonal)
            _compareRow(
              context,
              color: AppModeColors.actionPrimary(cs.brightness),
              label: l10n.familyRatingYourOwnLabel,
              trailing: _StarNumber(value: personal),
            ),
        ],
      ),
    );
  }

  /// Colour/term key so the green-vs-rust(-vs-gold) pills are never a guess —
  /// this is the "explained when you look into a recipe" legend.
  Widget _legend(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: AppDimensions.paddingOnlyTop12,
      padding: AppDimensions.paddingVertical8,
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: cs.outlineVariant)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ButleryIcon(
            ButleryIcons.info,
            size: AppDimensions.iconSize14,
            color: cs.outline,
          ),
          const SizedBox(width: AppDimensions.space8),
          Expanded(
            child: Text(
              l10n.familyRatingLegend,
              style: AppTextStyles.captionText.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _compareRow(
    BuildContext context, {
    required Color color,
    required String label,
    required Widget trailing,
  }) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            Container(width: 10, height: 10, color: color),
            const SizedBox(width: AppDimensions.space8),
            Text(
              label,
              style: AppTextStyles.bodyBold,
            ),
          ],
        ),
        trailing,
      ],
    );
  }
}

/// A rating as one star and the number ("★ 5,0"), as Skarmar v12 del 3
/// #betygsoversikt draws a row's verdict.
class _StarNumber extends StatelessWidget {
  const _StarNumber({required this.value});

  final double value;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        ButleryIcon(
          ButleryIcons.star,
          size: AppDimensions.iconSize14,
          color: context.modeColors.starGold,
        ),
        const SizedBox(width: AppDimensions.space4),
        Text(
          value.toStringAsFixed(1).replaceAll('.', ','),
          style: AppTextStyles.bodyBold.copyWith(color: cs.onSurface),
        ),
      ],
    );
  }
}
