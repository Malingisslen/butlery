// Privacy settings section extracted from user_profile_edit_view.dart to keep
// the parent under the 634-line baseline. Pure relocation — no logic changes.

import 'package:flutter/material.dart';
import 'package:butlery/models/social/activity_event.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';

/// Four privacy toggles: search visibility, email search, online status,
/// activity feed.
class PrivacySettingsSection extends StatelessWidget {
  final UserProfileViewModel viewModel;

  const PrivacySettingsSection({
    super.key,
    required this.viewModel,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Semantics(
          header: true,
          child: Text(
            context.l10n.profilePrivacySettings,
            style: AppTextStyles.titleMedium,
          ),
        ),
        const SizedBox(height: AppDimensions.spacingL),
        BorderedContainer(
          child: Column(
            children: [
              // BUT-1629: for a minor this toggle is the deliberate opt-in and
              // routes through the server-side callable (the ordinary save can
              // never make a minor discoverable — see setSearchableOptIn); for
              // an adult it is the same local edit as before, persisted on Save.
              SwitchListTile(
                title: Text(context.l10n.profileVisibleInSearch),
                subtitle: Text(context.l10n.profileVisibleInSearchDescription),
                value: viewModel.isSearchable,
                // Disabled during a save: for a minor both this toggle and the
                // save write isSearchable, and letting them interleave could
                // re-enable discoverability just after a deliberate opt-out.
                onChanged: viewModel.isSaving
                    ? null
                    : (value) async {
                        final ok = await viewModel.setSearchableOptIn(value);
                        if (!ok && context.mounted) {
                          SnackBarUtils.showError(
                            context,
                            viewModel.error ??
                                context.l10n.errorCouldNotUpdateSearchability,
                          );
                        }
                      },
                secondary: const Icon(Icons.search),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(context.l10n.profileSearchableByEmail),
                subtitle: Text(
                  context.l10n.profileSearchableByEmailDescription,
                ),
                value: viewModel.allowEmailSearch,
                onChanged: viewModel.updateAllowEmailSearch,
                secondary: const Icon(Icons.email),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(context.l10n.profileShowOnlineStatus),
                subtitle: Text(context.l10n.profileShowOnlineStatusDescription),
                value: viewModel.showOnlineStatus,
                onChanged: viewModel.updateShowOnlineStatus,
                secondary: const Icon(Icons.podcasts),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(context.l10n.privacyShareActivityTitle),
                subtitle: Text(context.l10n.privacyShareActivitySubtitle),
                value: viewModel.shareActivityToFeed,
                onChanged: viewModel.updateShareActivityToFeed,
                secondary: const Icon(Icons.dynamic_feed),
              ),
              // BUT-1220: per-event-type toggles sit under the master switch.
              // They only have effect while the master toggle is on, so we
              // disable them (greyed, non-interactive) when broadcasting is off.
              _ActivityTypeToggles(viewModel: viewModel),
            ],
          ),
        ),
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

    return Column(
      children: [
        const Divider(height: 1),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppDimensions.spacingL,
            AppDimensions.spacingM,
            AppDimensions.spacingL,
            0,
          ),
          child: Align(
            alignment: Alignment.centerLeft,
            child: Text(
              context.l10n.privacyActivityTypesTitle,
              style: AppTextStyles.labelMedium,
            ),
          ),
        ),
        for (final (type, label) in rows)
          SwitchListTile(
            title: Text(label),
            value: masterOn && viewModel.isActivityEventTypeEnabled(type),
            onChanged: masterOn
                ? (value) => viewModel.updateActivityEventType(type, value)
                : null,
            dense: true,
          ),
      ],
    );
  }
}
