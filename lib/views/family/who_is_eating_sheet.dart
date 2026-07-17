import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/family_rating.dart' show HouseholdMemberType;
import 'package:butlery/models/household_roster_member.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/family/who_is_eating_viewmodel.dart';
import 'package:butlery/views/family/family_widgets.dart';

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

  const WhoAteResult.attended(
    this.attendeeMemberIds, {
    this.applyToWholeDay = false,
  }) : skipped = false;
  const WhoAteResult.skipped()
    : skipped = true,
      attendeeMemberIds = const [],
      applyToWholeDay = false;
}

/// Presentation config for the shared roster picker — lets the cook-log flow
/// and the BUT-1611 presence flow reuse one sheet with their own copy.
class _PickerConfig {
  final String title;
  final String subtitle;
  final IconData subtitleIcon;
  final String Function(int count) confirmLabel;
  final String? skipLabel; // null → no skip action (presence)
  final String? wholeDayLabel; // null → no whole-day action (cook-log)
  final bool allowEmpty; // presence permits an explicit "nobody home"

  const _PickerConfig({
    required this.title,
    required this.subtitle,
    required this.subtitleIcon,
    required this.confirmLabel,
    this.skipLabel,
    this.wholeDayLabel,
    this.allowEmpty = false,
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
      subtitleIcon: Icons.restaurant_outlined,
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
}) {
  final l10n = context.l10n;
  return _showRosterPicker(
    context,
    seedMemberIds: seedMemberIds,
    allowCreateHousehold: false,
    config: _PickerConfig(
      title: l10n.menuPresenceSheetTitle,
      subtitle: slotLabel,
      subtitleIcon: Icons.home_outlined,
      confirmLabel: (_) => l10n.menuPresenceThisMeal,
      wholeDayLabel: l10n.menuPresenceWholeDay,
      allowEmpty: true,
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

  final result = await showModalBottomSheet<WhoAteResult>(
    context: context,
    backgroundColor: Theme.of(context).colorScheme.surface,
    isScrollControlled: true,
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

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                color: cs.outlineVariant,
              ),
            ),
            Text(
              config.title,
              style: AppTextStyles.headlineSmall.copyWith(color: cs.primary),
            ),
            const SizedBox(height: 6),
            Row(
              children: [
                Icon(config.subtitleIcon, size: 15, color: cs.secondary),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    config.subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.secondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: vm.roster.length,
                separatorBuilder: (_, _) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final member = vm.roster[i];
                  return _DinerToggleRow(
                    member: member,
                    selected: vm.isSelected(member.memberId),
                    onTap: () => vm.toggle(member.memberId),
                  );
                },
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: canConfirm
                    ? () => Navigator.pop(
                        context,
                        WhoAteResult.attended(vm.selectedMemberIds),
                      )
                    : null,
                icon: const Icon(Icons.how_to_reg, size: 18),
                label: Text(config.confirmLabel(vm.selectedCount)),
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size.fromHeight(48),
                  backgroundColor: cs.primary,
                  foregroundColor: cs.surface,
                ),
              ),
            ),
            if (config.wholeDayLabel != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: canConfirm
                      ? () => Navigator.pop(
                          context,
                          WhoAteResult.attended(
                            vm.selectedMemberIds,
                            applyToWholeDay: true,
                          ),
                        )
                      : null,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size.fromHeight(44),
                    foregroundColor: cs.primary,
                    side: BorderSide(color: cs.primary),
                  ),
                  child: Text(config.wholeDayLabel!),
                ),
              ),
            ],
            if (config.skipLabel != null) ...[
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () =>
                      Navigator.pop(context, const WhoAteResult.skipped()),
                  style: TextButton.styleFrom(
                    minimumSize: const Size.fromHeight(40),
                    foregroundColor: cs.outline,
                  ),
                  child: Text(config.skipLabel!),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One toggleable roster member row inside the picker.
class _DinerToggleRow extends StatelessWidget {
  final HouseholdRosterMember member;
  final bool selected;
  final VoidCallback onTap;

  const _DinerToggleRow({
    required this.member,
    required this.selected,
    required this.onTap,
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
      label: context.l10n.a11yToggleDiner(member.displayName),
      child: InkWell(
        onTap: onTap,
        child: Opacity(
          opacity: selected ? 1.0 : 0.5,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: cs.surface,
              border: Border(
                left: BorderSide(
                  color: selected ? cs.primary : cs.outlineVariant,
                  width: 4,
                ),
                bottom: BorderSide(
                  color: selected ? AppColors.rustLight : cs.outlineVariant,
                  width: 3,
                ),
              ),
            ),
            child: Row(
              children: [
                FamilyAvatar(
                  name: member.displayName,
                  color: parseAvatarColor(member.avatarColor),
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        member.displayName,
                        style: AppTextStyles.titleSmall,
                      ),
                      const SizedBox(height: 3),
                      Text(
                        _tag(context),
                        style: AppTextStyles.captionText.copyWith(
                          color: cs.outline,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                _CheckBox(selected: selected),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _CheckBox extends StatelessWidget {
  final bool selected;
  const _CheckBox({required this.selected});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: selected ? cs.primary : Colors.transparent,
        border: Border.all(
          color: selected ? cs.primary : cs.outlineVariant,
          width: 2,
        ),
      ),
      child: selected
          ? const Icon(Icons.check, size: 18, color: Colors.white)
          : null,
    );
  }
}
