import 'package:butlery/widgets/common/sheets/butlery_sheet.dart';
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/distinct_initials.dart';
import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/family/who_is_eating_viewmodel.dart';
import 'package:butlery/views/family/family_widgets.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/common/input/butlery_checkbox.dart';

/// Outcome of the who's-eating picker.
///
/// [skipped] = "hoppa över": log the cook with no attendance (historical
/// behavior); the presence flow treats it as "no change". Otherwise
/// [attendeeMemberIds] holds the selected members. [applyToWholeDay] is a
/// BUT-1611 presence signal — "Hela dagen" sets both meal slots, "Denna
/// måltid" sets one; it is always false in the cook-log flow.
class WhoAteResult {
  final bool skipped;
  final List<String> attendeeMemberIds;
  final bool applyToWholeDay;

  /// The week menu's meal sheet only: the user chose the dish instead of
  /// changing who is home.
  final bool openRecipe;

  const WhoAteResult.attended(
    this.attendeeMemberIds, {
    this.applyToWholeDay = false,
  }) : skipped = false,
       openRecipe = false;
  const WhoAteResult.skipped()
    : skipped = true,
      attendeeMemberIds = const [],
      applyToWholeDay = false,
      openRecipe = false;
  const WhoAteResult.openRecipe()
    : skipped = false,
      attendeeMemberIds = const [],
      applyToWholeDay = false,
      openRecipe = true;
}

/// Presentation config for the shared roster picker — lets the cook-log flow
/// and the BUT-1611 presence flow reuse one sheet with their own copy.
class _PickerConfig {
  final String title;
  final String subtitle;
  final String Function(int count) confirmLabel;
  final String? skipLabel; // null → no skip action (presence)
  final String? wholeDayLabel; // null → no whole-day action (cook-log)
  final bool allowEmpty; // presence permits an explicit "nobody home"

  /// Presence only: the word beside each row's box, and the line under the
  /// title that counts who is home and the portions they make.
  final String? homeLabel;
  final String? awayLabel;
  final String Function(int home)? summary;

  /// Presence on the week menu only: a way to the dish itself.
  final String? openRecipeLabel;

  const _PickerConfig({
    required this.title,
    required this.subtitle,
    required this.confirmLabel,
    this.skipLabel,
    this.wholeDayLabel,
    this.allowEmpty = false,
    this.homeLabel,
    this.awayLabel,
    this.summary,
    this.openRecipeLabel,
  });
}

/// Present the "vem åt?" picker on a "lagat idag" tap.
///
/// Loads the roster first because the solo-account case (roster ≤ 1) skips the
/// sheet entirely — the feature stays invisible until a household has family
/// members. Returns `null` when the sheet is dismissed (no cook logged), a
/// [WhoAteResult.skipped] for "hoppa över", or [WhoAteResult.attended] with the
/// selected members on "klar".
Future<WhoAteResult?> showWhoIsEatingSheet(
  BuildContext context, {
  required String recipeTitle,
}) {
  final l10n = context.l10n;
  return _showRosterPicker(
    context,
    allowCreateHousehold: true,
    config: _PickerConfig(
      title: l10n.whoAteTitle,
      subtitle: recipeTitle,
      confirmLabel: l10n.whoAteConfirm,
      skipLabel: l10n.whoAteSkip,
    ),
  );
}

/// BUT-1611: present the "vem är hemma?" picker for one meal [slotLabel]
/// (e.g. "lunch på måndag"), seeded with that slot's current [seedMemberIds]
/// (empty = nobody, absent-selection callers pass the whole roster). Read-only
/// roster resolution — opening the menu never creates a household. Returns
/// `null`/skipped on dismiss/solo, [WhoAteResult.attended] with
/// `applyToWholeDay` distinguishing "Denna måltid" from "Hela dagen".
Future<WhoAteResult?> showWhoIsHomeSheet(
  BuildContext context, {
  required String slotLabel,
  required List<String> seedMemberIds,
  bool offerRecipe = false,
}) {
  final l10n = context.l10n;
  return _showRosterPicker(
    context,
    seedMemberIds: seedMemberIds,
    allowCreateHousehold: false,
    config: _PickerConfig(
      title: l10n.menuPresenceSheetTitle,
      subtitle: slotLabel,
      confirmLabel: (_) => l10n.menuPresenceThisMeal,
      wholeDayLabel: l10n.menuPresenceWholeDay,
      allowEmpty: true,
      homeLabel: l10n.menuPresenceHome,
      awayLabel: l10n.menuPresenceAway,
      summary: (home) => l10n.menuPresenceHomeSummary(home, home),
      openRecipeLabel: offerRecipe ? l10n.menuPresenceOpenRecipe : null,
    ),
  );
}

Future<WhoAteResult?> _showRosterPicker(
  BuildContext context, {
  required bool allowCreateHousehold,
  required _PickerConfig config,
  List<String>? seedMemberIds,
}) async {
  final vm = WhoIsEatingViewModel();
  await vm.load(
    seedMemberIds: seedMemberIds,
    allowCreateHousehold: allowCreateHousehold,
  );
  if (!context.mounted) {
    vm.dispose();
    return null;
  }

  // A roster-load blip must not be mistaken for "no family": both recover by
  // making no change, but keep the reasons distinct so a transient failure on a
  // real household reads as a degraded load, not a solo account.
  if (vm.hasError) {
    vm.dispose();
    return const WhoAteResult.skipped();
  }

  // Solo account (just the owner) → no picker, exactly as before the feature
  // existed. It stays invisible until family is added.
  if (vm.roster.length <= 1) {
    vm.dispose();
    return const WhoAteResult.skipped();
  }

  final result = await showButlerySheet<WhoAteResult>(
    context: context,
    builder: (_) => ChangeNotifierProvider<WhoIsEatingViewModel>.value(
      value: vm,
      child: _WhoIsEatingSheet(config: config),
    ),
  );
  vm.dispose();
  return result;
}

class _WhoIsEatingSheet extends StatelessWidget {
  final _PickerConfig config;

  const _WhoIsEatingSheet({required this.config});

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<WhoIsEatingViewModel>();
    final cs = Theme.of(context).colorScheme;
    final canConfirm = config.allowEmpty || vm.selectedCount > 0;
    // Over the whole roster, so two members with the same initials do not
    // share an avatar.
    final initials = distinctInitials([
      for (final m in vm.roster) m.displayName,
    ]);
    final summary = config.summary;
    final selectedMembers = [
      for (final m in vm.roster)
        if (vm.isSelected(m.memberId)) m,
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(
          AppDimensions.space24,
          AppDimensions.space12,
          AppDimensions.space24,
          AppDimensions.space24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              config.title,
              style: AppTextStyles.headlineSmall.copyWith(color: cs.onSurface),
            ),
            const SizedBox(height: AppDimensions.space4),
            Text(
              config.subtitle,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.labelMedium.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
            if (summary != null) ...[
              const SizedBox(height: AppDimensions.space16),
              Row(
                children: [
                  _FaceStack(
                    members: selectedMembers,
                    initials: [
                      for (final m in selectedMembers)
                        initials[vm.roster.indexOf(m)],
                    ],
                  ),
                  if (selectedMembers.isNotEmpty)
                    const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: Text(
                      summary(vm.selectedCount),
                      style: AppTextStyles.labelLarge.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: AppDimensions.space12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                // On a phone the app-wide "!" feedback button floats over
                // this list at the same right edge, so without this inset it
                // covers a row's checkbox (BUT-2261). The buttons below sit
                // lower than it and keep the full width.
                padding: const EdgeInsetsDirectional.only(
                  end: AppDimensions.minTouchTarget + AppDimensions.space8,
                ),
                itemCount: vm.roster.length,
                separatorBuilder: (_, _) => const ButleryDivider(spacing: 1),
                itemBuilder: (_, i) {
                  final member = vm.roster[i];
                  final selected = vm.isSelected(member.memberId);
                  return _DinerToggleRow(
                    member: member,
                    initials: initials[i],
                    selected: selected,
                    statusLabel: selected ? config.homeLabel : config.awayLabel,
                    onTap: () => vm.toggle(member.memberId),
                  );
                },
              ),
            ),
            const SizedBox(height: AppDimensions.space16),
            ActionButtons.primaryButton(
              context,
              onPressed: canConfirm
                  ? () => Navigator.pop(
                      context,
                      WhoAteResult.attended(vm.selectedMemberIds),
                    )
                  : null,
              icon: ButleryIcons.circleCheck,
              label: config.confirmLabel(vm.selectedCount),
              isExpanded: true,
            ),
            if (config.wholeDayLabel != null) ...[
              const SizedBox(height: AppDimensions.space8),
              ActionButtons.outlinedButton(
                context,
                onPressed: canConfirm
                    ? () => Navigator.pop(
                        context,
                        WhoAteResult.attended(
                          vm.selectedMemberIds,
                          applyToWholeDay: true,
                        ),
                      )
                    : null,
                label: config.wholeDayLabel!,
                isExpanded: true,
              ),
            ],
            if (config.openRecipeLabel != null) ...[
              const SizedBox(height: AppDimensions.space8),
              ButleryTextButton(
                expanded: true,
                onPressed: () =>
                    Navigator.pop(context, const WhoAteResult.openRecipe()),
                label: config.openRecipeLabel!,
              ),
            ],
            if (config.skipLabel != null) ...[
              const SizedBox(height: AppDimensions.space8),
              ButleryTextButton(
                expanded: true,
                tone: ButleryTextButtonTone.muted,
                onPressed: () =>
                    Navigator.pop(context, const WhoAteResult.skipped()),
                label: config.skipLabel!,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// The faces of the members who are chosen, overlapping, at most three.
class _FaceStack extends StatelessWidget {
  const _FaceStack({required this.members, required this.initials});

  final List<HouseholdRosterMember> members;
  final List<String> initials;

  static const double _face = 28;
  static const int _max = 3;

  @override
  Widget build(BuildContext context) {
    final shown = members.take(_max).toList();
    if (shown.isEmpty) return const SizedBox.shrink();
    const step = _face - AppDimensions.space8;
    return ExcludeSemantics(
      child: SizedBox(
        width: _face + (shown.length - 1) * step,
        height: _face,
        child: Stack(
          children: [
            for (var i = 0; i < shown.length; i++)
              PositionedDirectional(
                start: i * step,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.surface,
                      width: 2,
                    ),
                  ),
                  child: FamilyAvatar(
                    name: shown[i].displayName,
                    initials: initials[i],
                    color: parseAvatarColor(context, shown[i].avatarColor),
                    size: _face,
                    round: true,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// One toggleable roster member row inside the picker: a hairline row, the
/// face, the name, and a checkbox. With [statusLabel] the word "hemma" or
/// "borta" stands beside the box; without it the row carries the age band.
class _DinerToggleRow extends StatelessWidget {
  final HouseholdRosterMember member;
  final String initials;
  final bool selected;
  final String? statusLabel;
  final VoidCallback onTap;

  const _DinerToggleRow({
    required this.member,
    required this.initials,
    required this.selected,
    required this.onTap,
    this.statusLabel,
  });

  String _tag(BuildContext context) {
    final l10n = context.l10n;
    // Accounts have no age band — they read as adults; diner profiles use their
    // coarse age band label.
    if (member.type == HouseholdMemberType.user || member.ageBand == null) {
      return l10n.ageBandAdult;
    }
    return ageBandLabel(l10n, member.ageBand!);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      toggled: selected,
      label: context.l10n.a11yToggleDiner,
      child: Material(
        type: MaterialType.transparency,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(minHeight: 56),
              child: Row(
                children: [
                  FamilyAvatar(
                    name: member.displayName,
                    initials: initials,
                    color: parseAvatarColor(context, member.avatarColor),
                    size: 28,
                    round: true,
                  ),
                  const SizedBox(width: AppDimensions.space12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          member.displayName,
                          style: AppTextStyles.labelLargeBold.copyWith(
                            color: cs.onSurface,
                          ),
                        ),
                        if (statusLabel == null)
                          Text(
                            _tag(context),
                            style: AppTextStyles.captionBold.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (statusLabel != null) ...[
                    Text(
                      statusLabel!,
                      style: AppTextStyles.labelMedium.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                  ],
                  ExcludeSemantics(
                    child: IgnorePointer(
                      child: ButleryCheckbox(
                        value: selected,
                        onChanged: (_) {},
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
