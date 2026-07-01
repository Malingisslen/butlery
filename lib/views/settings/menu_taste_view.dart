// Settings > "Meny och smak" (BUT-1320, UI half).
//
// Surfaces the two weekly-menu tuning controls — cooking skill level + cuisine
// affinities — in a point-of-use where the user understands they steer the menu
// suggestions (not just a social bio field). The controls and their persistence
// are shared with the profile-edit "cooking identity" section via
// [CookingPreferenceControls] + [UserProfileViewModel.saveProfile]; nothing is
// duplicated here, so the two entry points can never drift apart.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/views/social/user_profile_edit/cooking_preference_controls.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_card.dart';

class MenuTasteView extends StatefulWidget {
  const MenuTasteView({super.key});

  @override
  State<MenuTasteView> createState() => _MenuTasteViewState();
}

class _MenuTasteViewState extends State<MenuTasteView> {
  late final UserProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // Factory registration → own instance, disposed here (matches profile-edit).
    _viewModel = ServiceLocator.get<UserProfileViewModel>();
  }

  @override
  void dispose() {
    _viewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<UserProfileViewModel>.value(
      value: _viewModel,
      child: const _MenuTasteContent(),
    );
  }
}

class _MenuTasteContent extends StatefulWidget {
  const _MenuTasteContent();

  @override
  State<_MenuTasteContent> createState() => _MenuTasteContentState();
}

class _MenuTasteContentState extends State<_MenuTasteContent> {
  // Local in-flight guard: UserProfileViewModel.isLoading tracks avatar upload
  // only, not saveProfile(), so without this a double-tap during the save
  // round-trip would fire two concurrent writes. Profile-edit masks this by
  // popping on success; this screen stays put, so it guards locally.
  bool _saving = false;

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserProfileViewModel>();
    final cs = Theme.of(context).colorScheme;

    // Enabled when there are unsaved changes and no save is in flight. A save
    // that can't succeed (e.g. a rare empty-displayName profile) surfaces an
    // error via _save's failure branch rather than being silently disabled;
    // backing out with unsaved changes is caught by the PopScope below.
    final canSave = viewModel.hasUnsavedChanges && !_saving;

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        final shouldPop = await _handleBackNavigation(viewModel);
        if (shouldPop && context.mounted) Navigator.of(context).pop();
      },
      child: Scaffold(
        appBar: AdaptiveAppBar(title: context.l10n.settingsMenuTasteTitle),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Point-of-use intro: makes clear these steer the weekly menu.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.tune,
                        color: cs.primary,
                        size: AppDimensions.iconSizeAction,
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Expanded(
                        child: Text(
                          context.l10n.menuTasteIntro,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingL),
                  StyledCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingL),
                      child: CookingPreferenceControls(viewModel: viewModel),
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingXl),
                  ActionButtons.primaryButton(
                    context,
                    label: context.l10n.commonSave,
                    onPressed: canSave ? _save : null,
                    isLoading: _saving,
                    isExpanded: true,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (_saving) return; // in-flight guard: one save per tap, no double write
    final viewModel = context.read<UserProfileViewModel>();
    setState(() => _saving = true);
    try {
      final success = await viewModel.saveProfile();
      if (!mounted) return;
      if (success) {
        SnackBarUtils.showSuccess(context, context.l10n.menuTasteSaved);
      } else {
        // Mirror the profile-edit save path — surface the failure instead of
        // leaving the user with un-saved changes and no explanation.
        SnackBarUtils.showError(
          context,
          viewModel.error ?? context.l10n.profileCouldNotSave,
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// Guards back-navigation: with unsaved menu-tuning changes, offer save /
  /// discard / cancel (mirrors the profile-edit exit guard) so a change isn't
  /// silently lost on pop. Returns true when it's safe to leave.
  Future<bool> _handleBackNavigation(UserProfileViewModel viewModel) async {
    if (!viewModel.hasUnsavedChanges) return true;
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.profileUnsavedChanges),
        content: Text(dialogContext.l10n.profileUnsavedChangesMessage),
        actions: [
          ActionButtons.secondaryButton(
            dialogContext,
            label: dialogContext.l10n.commonDiscard,
            onPressed: () => Navigator.pop(dialogContext, true),
          ),
          ActionButtons.secondaryButton(
            dialogContext,
            label: dialogContext.l10n.commonCancel,
            onPressed: () => Navigator.pop(dialogContext, false),
          ),
          ActionButtons.primaryButton(
            dialogContext,
            label: dialogContext.l10n.commonSave,
            onPressed: () async {
              Navigator.pop(dialogContext, false);
              await _save();
            },
          ),
        ],
      ),
    );
    return shouldDiscard ?? false;
  }
}
