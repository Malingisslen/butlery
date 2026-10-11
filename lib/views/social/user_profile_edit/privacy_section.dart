// Privacy settings section extracted from user_profile_edit_view.dart to keep
// the parent under the 634-line baseline.

import 'package:flutter/material.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';

class PrivacySettingsSection extends StatelessWidget {
  final UserProfileViewModel viewModel;

  const PrivacySettingsSection({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ButleryListSection(
          title: l10n.profilePrivacySettings,
          rows: [
            // BUT-1629: for a minor this toggle is the deliberate opt-in and
            // routes through the server-side callable (the ordinary save can
            // never make a minor discoverable — see setSearchableOptIn); for
            // an adult it is the same local edit as before, persisted on Save.
            ButleryListRow.toggle(
              label: l10n.profileVisibleInSearch,
              subtitle: l10n.profileVisibleInSearchDescription,
              checked: viewModel.isSearchable,
              // Disabled during a save: for a minor both this toggle and the
              // save write isSearchable, and letting them interleave could
              // re-enable discoverability just after a deliberate opt-out.
              enabled: !viewModel.isSaving,
              onChanged: (value) async {
                final ok = await viewModel.setSearchableOptIn(value);
                if (!ok && context.mounted) {
                  SnackBarUtils.showFailure(
                    context,
                    what:
                        viewModel.error ??
                        context.l10n.errorCouldNotUpdateSearchability,
                  );
                }
              },
            ),
            ButleryListRow.toggle(
              label: l10n.profileSearchableByEmail,
              subtitle: l10n.profileSearchableByEmailDescription,
              checked: viewModel.allowEmailSearch,
              onChanged: viewModel.updateAllowEmailSearch,
            ),
            ButleryListRow.toggle(
              label: l10n.profileShowOnlineStatus,
              subtitle: l10n.profileShowOnlineStatusDescription,
              checked: viewModel.showOnlineStatus,
              onChanged: viewModel.updateShowOnlineStatus,
            ),
            // BUT-2221: written at once, like the minor search opt-in; a
            // minor sees it switched off with the reason as its subtitle.
            ButleryListRow.toggle(
              label: l10n.privacyShowNameOnDishesTitle,
              subtitle: viewModel.isMinor
                  ? l10n.privacyShowNameOnDishesMinor
                  : l10n.privacyShowNameOnDishesSubtitle,
              checked: viewModel.showNameOnSharedDishes,
              enabled: !viewModel.isMinor,
              onChanged: (value) async {
                final ok = await viewModel.setShowNameOnSharedDishes(value);
                if (!ok && context.mounted) {
                  SnackBarUtils.showFailure(
                    context,
                    what:
                        viewModel.error ??
                        context.l10n.errorCouldNotSaveDishCredit,
                  );
                }
              },
            ),
            ButleryListRow.toggle(
              label: l10n.privacyShareActivityTitle,
              subtitle: l10n.privacyShareActivitySubtitle,
              checked: viewModel.shareActivityToFeed,
              onChanged: viewModel.updateShareActivityToFeed,
            ),
          ],
        ),
        // BUT-1220: per-event-type toggles sit under the master switch.
        // They only have effect while the master toggle is on, so they are
        // disabled while broadcasting is off.
        _ActivityTypeToggles(viewModel: viewModel),
      ],
    );
  }
}

/// BUT-1220: nested per-event-type opt-outs under the activity-feed master
/// toggle. Each row maps to an [ActivityEventType]; an unset entry reads as on.
class _ActivityTypeToggles extends StatelessWidget {
  final UserProfileViewModel viewModel;

  const _ActivityTypeToggles({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final masterOn = viewModel.shareActivityToFeed;

    // Order mirrors a typical cooking flow; addedIngredient is an internal
    // depth event, intentionally not surfaced as a user-facing broadcast toggle.
    final rows = <(ActivityEventType, String)>[
      (ActivityEventType.cooked, context.l10n.privacyActivityTypeCooked),
      (ActivityEventType.shared, context.l10n.privacyActivityTypeShared),
      (
        ActivityEventType.startedCooking,
        context.l10n.privacyActivityTypeStartedCooking,
      ),
      (ActivityEventType.pinged, context.l10n.privacyActivityTypePinged),
    ];

    return ButleryListSection(
      title: context.l10n.privacyActivityTypesTitle,
      rows: [
        for (final (type, label) in rows)
          ButleryListRow.toggle(
            label: label,
            checked: masterOn && viewModel.isActivityEventTypeEnabled(type),
            enabled: masterOn,
            onChanged: (value) =>
                viewModel.updateActivityEventType(type, value),
          ),
      ],
    );
  }
}
