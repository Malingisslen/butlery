import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/family/family_rating_breakdown_viewmodel.dart';
import 'package:butlery/views/family/family_rating_entry_view.dart';
import 'package:butlery/views/family/family_widgets.dart';
import 'package:butlery/widgets/common/star_rating_row.dart';

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
    _vm = FamilyRatingBreakdownViewModel(recipeId: widget.recipe.id)..load();
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
    await _vm.load(); // reflect any change made on the entry screen
  }

  Widget _section(BuildContext context, FamilyRatingBreakdownViewModel vm) {
    final l10n = context.l10n;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _header(context, vm, l10n),
          if (_expanded) ...[
            const SizedBox(height: 12),
            _hero(context, vm, l10n),
            const SizedBox(height: 8),
            for (final row in vm.rows) _dinerRow(context, row, l10n),
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
    return Semantics(
      button: true,
      toggled: _expanded,
      label: l10n.a11yToggleRatingBreakdown,
      child: InkWell(
        onTap: () => setState(() => _expanded = !_expanded),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 8),
          decoration: const BoxDecoration(
            border: Border(left: BorderSide(color: AppColors.rust, width: 3)),
          ),
          child: Row(
            children: [
              const SizedBox(width: 10),
              Text(
                l10n.familyRatingSectionTitle,
                style: AppTextStyles.titleSmall.copyWith(
                  color: AppColors.forestGreen,
                ),
              ),
              const SizedBox(width: 10),
              _familyPill(vm.familyAverageDisplay),
              const Spacer(),
              Icon(
                _expanded ? Icons.expand_less : Icons.expand_more,
                color: AppColors.textLight,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _familyPill(String value) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      color: AppColors.forestGreen,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.groups_outlined, size: 14, color: AppColors.cream),
          const SizedBox(width: 4),
          Text(
            value,
            style: AppTextStyles.labelSmall.copyWith(
              color: AppColors.cream,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _hero(
    BuildContext context,
    FamilyRatingBreakdownViewModel vm,
    AppLocalizations l10n,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: const BoxDecoration(
        color: AppColors.greenPale,
        border: Border(
          left: BorderSide(color: AppColors.forestGreen, width: 4),
          bottom: BorderSide(color: AppColors.rustLight, width: 3),
        ),
      ),
      child: Row(
        children: [
          _familyPill(vm.familyAverageDisplay),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l10n.familyRatingAverageLabel,
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              Text(
                l10n.familyRatingCount(vm.familyCount),
                style: AppTextStyles.captionText.copyWith(
                  color: AppColors.textLight,
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
  ) {
    final isHolder =
        row.member.type == HouseholdMemberType.user && !row.isProxy;
    return Semantics(
      button: true,
      label: l10n.a11yEditMemberRating(row.member.displayName),
      child: InkWell(
        onTap: () => _editMember(context, row.member.memberId),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 9),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: AppColors.cream, width: 1),
            ),
          ),
          child: Row(
            children: [
              FamilyAvatar(
                name: row.member.displayName,
                color: parseAvatarColor(row.member.avatarColor),
                size: 34,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            row.member.displayName,
                            style: AppTextStyles.bodyMedium.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        if (isHolder) ...[
                          const SizedBox(width: 6),
                          Text(
                            l10n.familyRatingYou,
                            style: AppTextStyles.captionText.copyWith(
                              color: AppColors.forestGreen,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ],
                    ),
                    if (row.isProxy && row.enteredByName != null)
                      Text(
                        l10n.familyRatingProxyEntered(row.enteredByName!),
                        style: AppTextStyles.captionText.copyWith(
                          color: AppColors.textMedium,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    Text(
                      l10n.familyRatingUpdated(_shortDate(row.lastUpdated)),
                      style: AppTextStyles.captionText.copyWith(
                        color: AppColors.textLight,
                      ),
                    ),
                  ],
                ),
              ),
              StarRatingRow(rating: row.stars.toDouble(), size: 16),
            ],
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
    final recipe = widget.recipe;
    final communityAvg = recipe.core.averageRating;
    final communityCount = recipe.core.ratingCount;
    final showCommunity = !recipe.isPersonal && communityAvg != null;
    final personal = recipe.rating;
    final showPersonal = personal != null && personal > 0;
    if (!showCommunity && !showPersonal) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.only(top: 14),
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: AppColors.cream, width: 2)),
      ),
      child: Column(
        children: [
          if (showCommunity)
            _compareRow(
              context,
              color: AppColors.rust,
              label: l10n.familyRatingCommunityLabel,
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    communityAvg.toStringAsFixed(1).replaceAll('.', ','),
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textLight,
                    ),
                  ),
                  if (communityCount != null) ...[
                    const SizedBox(width: 8),
                    Text(
                      l10n.familyRatingCount(communityCount),
                      style: AppTextStyles.captionText.copyWith(
                        color: AppColors.textMedium,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          if (showCommunity && showPersonal) const SizedBox(height: 12),
          if (showPersonal)
            _compareRow(
              context,
              color: AppColors.warning,
              label: l10n.familyRatingYourOwnLabel,
              trailing: StarRatingRow(rating: personal, size: 16),
            ),
        ],
      ),
    );
  }

  /// Colour/term key so the green-vs-rust(-vs-gold) pills are never a guess —
  /// this is the "explained when you look into a recipe" legend.
  Widget _legend(BuildContext context, AppLocalizations l10n) {
    return Container(
      margin: const EdgeInsets.only(top: 14),
      padding: const EdgeInsets.all(10),
      color: AppColors.cream,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Icon(
            Icons.info_outline,
            size: 14,
            color: AppColors.textLight,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.familyRatingLegend,
              style: AppTextStyles.captionText.copyWith(
                color: AppColors.textMedium,
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
            const SizedBox(width: 8),
            Text(
              label,
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
        trailing,
      ],
    );
  }
}
