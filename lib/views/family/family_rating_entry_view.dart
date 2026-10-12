import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/core/utils/distinct_initials.dart';
import 'package:butlery/widgets/common/butlery_top_bar.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/l10n/app_localizations.dart';
import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/family/family_rating_entry_viewmodel.dart';
import 'package:butlery/views/family/family_widgets.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/layout/tinted_note.dart';
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
      // A subpage (Komponentark v1:71-78). The recipe is the line under the
      // title, in the bar's own foreground: the old saffron text on ink was
      // not readable (tokens.json text roles; saffron is never text on ink).
      appBar: ButleryTopBar.undersida(
        title: l10n.familyRatingTitle,
        secondaryLine: recipeTitle,
        secondaryLineIsLive: false,
      ),
      // Only the INITIAL load replaces the form with a spinner; during save()
      // the form + (disabled) actions stay put so the screen doesn't flicker.
      body: (vm.isLoading && vm.present.isEmpty)
          ? StateWidget.loading(message: l10n.loadingFamily)
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
    // Holder name powers the "inmatat av {name}" attribution on proxy rows.
    String? holderName;
    for (final m in vm.present) {
      if (vm.isHolder(m.memberId)) {
        holderName = m.displayName;
        break;
      }
    }

    final initials = distinctInitials([
      for (final m in vm.present) m.displayName,
    ]);

    return ListView(
      padding: AppDimensions.paddingAll16,
      children: [
        for (var i = 0; i < vm.present.length; i++)
          _DinerRatingRow(
            member: vm.present[i],
            initials: initials[i],
            stars: vm.starsFor(vm.present[i].memberId),
            isHolder: vm.isHolder(vm.present[i].memberId),
            holderName: holderName,
            onChanged: (s) => vm.setStars(vm.present[i].memberId, s),
          ),
        const SizedBox(height: AppDimensions.space16),
        _privateNote(context, l10n),
      ],
    );
  }

  Widget _privateNote(BuildContext context, AppLocalizations l10n) {
    return TintedNote(
      child: Text.rich(
        TextSpan(
          children: [
            TextSpan(text: '${l10n.familyRatingNoteSkip} '),
            TextSpan(
              text: l10n.familyRatingNoteCounts,
              style: AppTextStyles.bodySmallBold,
            ),
            TextSpan(text: l10n.familyRatingNoteAnonymous),
          ],
        ),
        style: TintedNote.textStyle(context),
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
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space16,
          AppDimensions.space8,
          AppDimensions.space16,
          AppDimensions.space16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ActionButtons.primaryButton(
              context,
              onPressed: (vm.hasAnyRating && !vm.isLoading)
                  ? () => _save(context)
                  : null,
              icon: ButleryIcons.check,
              label: l10n.familyRatingSave,
              isExpanded: true,
            ),
            const SizedBox(height: AppDimensions.space8),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                onPressed: () => Navigator.of(context).pop(),
                style: TextButton.styleFrom(
                  minimumSize: const Size.fromHeight(40),
                  foregroundColor: cs.onSurfaceVariant,
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
  final String initials;
  final ValueChanged<int> onChanged;

  const _DinerRatingRow({
    required this.member,
    required this.initials,
    required this.stars,
    required this.isHolder,
    required this.holderName,
    required this.onChanged,
  });

  /// A proxy row is another *account holder* entered on this device — flag that
  /// it won't overwrite their own private rating. Diner profiles never mirror,
  /// so they need no such note.
  bool get _isProxyUser => member.type == HouseholdMemberType.user && !isHolder;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    final locale = Localizations.localeOf(context).toString();
    final score = NumberFormat.decimalPatternDigits(
      locale: locale,
      decimalDigits: 1,
    ).format(stars);
    final name = isHolder
        ? '${member.displayName} · ${l10n.familyRatingYou}'
        : member.displayName;
    return Container(
      padding: const EdgeInsets.symmetric(vertical: AppDimensions.space16),
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              FamilyAvatar(
                name: member.displayName,
                color: parseAvatarColor(context, member.avatarColor),
                initials: initials,
                size: AppDimensions.space32 * 2,
                round: true,
              ),
              const SizedBox(width: AppDimensions.space16),
              Expanded(
                child: Text(
                  name,
                  style: AppTextStyles.titleMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                stars == 0 ? l10n.familyRatingNotSet : score,
                style: stars == 0
                    ? AppTextStyles.bodyMedium.copyWith(
                        color: cs.onSurfaceVariant,
                      )
                    : AppTextStyles.titleMedium,
              ),
            ],
          ),
          const SizedBox(height: AppDimensions.space8),
          StarRatingRow(
            rating: stars.toDouble(),
            size: AppDimensions.iconSizeL,
            slot: AppDimensions.minTouchTarget,
            solidEmpty: true,
            onRatingChanged: (v) => onChanged(v.toInt()),
            semanticsLabel: (s) =>
                l10n.a11yRateStarsForMember(member.displayName, s),
          ),
          if (_isProxyUser && holderName != null) ...[
            const SizedBox(height: AppDimensions.space4),
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
    );
  }
}
