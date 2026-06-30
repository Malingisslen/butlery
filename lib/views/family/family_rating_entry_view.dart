import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/viewmodels/family/family_rating_entry_viewmodel.dart';
import 'package:butlery/views/family/family_widgets.dart';
import 'package:butlery/widgets/common/star_rating_row.dart';
import 'package:butlery/widgets/common/state_widget.dart';

/// Open the "vad tyckte ni?" family rating-entry screen. Auto-chained after the
/// who's-eating pick (pass the diners who ate as [presentMemberIds]) and from
/// the manual "Betygsätt som familj" button (pass null → whole roster).
Future<void> showFamilyRatingEntry(
  BuildContext context, {
  required String recipeId,
  required String recipeTitle,
  List<String>? presentMemberIds,
}) {
  return Navigator.of(context).push(
    MaterialPageRoute(
      builder: (_) => FamilyRatingEntryView(
        recipeId: recipeId,
        recipeTitle: recipeTitle,
        presentMemberIds: presentMemberIds,
      ),
    ),
  );
}

class FamilyRatingEntryView extends StatefulWidget {
  final String recipeId;
  final String recipeTitle;
  final List<String>? presentMemberIds;

  const FamilyRatingEntryView({
    super.key,
    required this.recipeId,
    required this.recipeTitle,
    this.presentMemberIds,
  });

  @override
  State<FamilyRatingEntryView> createState() => _FamilyRatingEntryViewState();
}

class _FamilyRatingEntryViewState extends State<FamilyRatingEntryView> {
  late final FamilyRatingEntryViewModel _vm;

  @override
  void initState() {
    super.initState();
    _vm = FamilyRatingEntryViewModel(
      recipeId: widget.recipeId,
      presentMemberIds: widget.presentMemberIds,
    )..load();
  }

  @override
  void dispose() {
    _vm.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<FamilyRatingEntryViewModel>.value(
      value: _vm,
      child: _FamilyRatingEntryContent(recipeTitle: widget.recipeTitle),
    );
  }
}

class _FamilyRatingEntryContent extends StatelessWidget {
  final String recipeTitle;

  const _FamilyRatingEntryContent({required this.recipeTitle});

  Future<void> _save(BuildContext context) async {
    final vm = context.read<FamilyRatingEntryViewModel>();
    final ok = await vm.save();
    if (!context.mounted) return;
    if (ok) {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final vm = context.watch<FamilyRatingEntryViewModel>();

    return Scaffold(
      backgroundColor: cs.surface,
      appBar: AppBar(
        title: Text(l10n.familyRatingTitle),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(20),
          child: Padding(
            padding: const EdgeInsetsDirectional.only(
              start: 16,
              bottom: 8,
              end: 16,
            ),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                recipeTitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(color: cs.secondary),
              ),
            ),
          ),
        ),
      ),
      // Only the INITIAL load replaces the form with a spinner; during save()
      // the form + (disabled) actions stay put so the screen doesn't flicker.
      body: (vm.isLoading && vm.present.isEmpty)
          ? StateWidget.loading()
          : _body(context, vm, l10n),
      bottomNavigationBar: (vm.isLoading && vm.present.isEmpty)
          ? null
          : _actions(context, vm, l10n),
    );
  }

  Widget _body(
    BuildContext context,
    FamilyRatingEntryViewModel vm,
    AppLocalizations l10n,
  ) {
    final cs = Theme.of(context).colorScheme;
    // Holder name powers the "inmatat av {name}" attribution on proxy rows.
    String? holderName;
    for (final m in vm.present) {
      if (vm.isHolder(m.memberId)) {
        holderName = m.displayName;
        break;
      }
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          l10n.familyRatingIntro,
          style: AppTextStyles.bodySmall.copyWith(color: cs.outline),
        ),
        const SizedBox(height: 16),
        for (final member in vm.present)
          _DinerRatingRow(
            member: member,
            stars: vm.starsFor(member.memberId),
            isHolder: vm.isHolder(member.memberId),
            holderName: holderName,
            onChanged: (s) => vm.setStars(member.memberId, s),
          ),
        const SizedBox(height: 8),
        _privateNote(context, l10n),
      ],
    );
  }

  Widget _privateNote(BuildContext context, AppLocalizations l10n) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(12),
      color: cs.surface,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.lock_outline,
            size: 15,
            color: cs.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              l10n.familyRatingPrivateNote,
              style: AppTextStyles.captionText.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _actions(
    BuildContext context,
    FamilyRatingEntryViewModel vm,
    AppLocalizations l10n,
  ) {
    final cs = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: (vm.hasAnyRating && !vm.isLoading)
                    ? () => _save(context)
                    : null,
                icon: const Icon(Icons.check, size: 18),
                label: Text(l10n.familyRatingSave),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: cs.primary,
                  foregroundColor: cs.surface,
                ),
              ),
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  foregroundColor: cs.outline,
                ),
                child: Text(l10n.whoAteSkip),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One diner's avatar + name + interactive gold star row.
class _DinerRatingRow extends StatelessWidget {
  final HouseholdRosterMember member;
  final int stars;
  final bool isHolder;
  final String? holderName;
  final ValueChanged<int> onChanged;

  const _DinerRatingRow({
    required this.member,
    required this.stars,
    required this.isHolder,
    required this.holderName,
    required this.onChanged,
  });

  String _tag(BuildContext context) {
    final l10n = context.l10n;
    if (member.type == HouseholdMemberType.user || member.ageBand == null) {
      return l10n.ageBandAdult;
    }
    return ageBandLabel(l10n, member.ageBand!);
  }

  /// A proxy row is another *account holder* entered on this device — flag that
  /// it won't overwrite their own private rating. Diner profiles never mirror,
  /// so they need no such note.
  bool get _isProxyUser => member.type == HouseholdMemberType.user && !isHolder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
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
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        member.displayName,
                        style: AppTextStyles.titleSmall,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (isHolder) ...[
                      const SizedBox(width: 8),
                      _YouBadge(label: l10n.familyRatingYou),
                    ],
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  _tag(context),
                  style: AppTextStyles.captionText.copyWith(
                    color: cs.outline,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                StarRatingRow(
                  rating: stars.toDouble(),
                  size: 30,
                  onRatingChanged: (v) => onChanged(v.toInt()),
                  semanticsLabel: (s) =>
                      l10n.a11yRateStarsForMember(member.displayName, s),
                ),
                if (_isProxyUser && holderName != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    l10n.familyRatingProxyNote(holderName!),
                    style: AppTextStyles.captionText.copyWith(
                      color: cs.onSurfaceVariant,
                      fontStyle: FontStyle.italic,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _YouBadge extends StatelessWidget {
  final String label;
  const _YouBadge({required this.label});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: context.butleryColors.heroPaleGreen,
        border: Border.all(color: cs.primary),
      ),
      child: Text(
        label,
        style: AppTextStyles.captionText.copyWith(
          color: cs.primary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
