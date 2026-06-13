// Privacy settings section extracted from user_profile_edit_view.dart to keep
// the parent under the 634-line baseline. Pure relocation — no logic changes.

import 'package:flutter/material.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

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
              SwitchListTile(
                title: Text(context.l10n.profileVisibleInSearch),
                subtitle: Text(context.l10n.profileVisibleInSearchDescription),
                value: viewModel.isSearchable,
                onChanged: viewModel.updateIsSearchable,
                secondary: const Icon(Icons.search),
              ),
              const Divider(height: 1),
              SwitchListTile(
                title: Text(context.l10n.profileSearchableByEmail),
                subtitle:
                    Text(context.l10n.profileSearchableByEmailDescription),
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
            ],
          ),
        ),
      ],
    );
  }
}
