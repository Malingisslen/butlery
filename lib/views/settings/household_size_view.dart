// Settings > "Hushållsstorlek" (BUT-1594).
//
// A single control: the household-size default that pre-sets recipe portions
// and scales the weekly menu (BUT-1322). Persistence goes through
// [UserProfileViewModel.saveProfile], the same path the profile-edit screen
// uses, so the value can never drift between the two entry points.
//
// History: this screen was "Meny och smak" (BUT-1320) and also carried the
// weekly-menu cuisine-affinity + cooking-skill tuning controls. BUT-1594
// removed those nudges from the menu (they double-counted taste on a menu drawn
// from the user's own recipes); the cuisine/skill controls still live on the
// profile-edit "cooking identity" section as social bio data.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_card.dart';

class HouseholdSizeView extends StatefulWidget {
  const HouseholdSizeView({super.key});

  @override
  State<HouseholdSizeView> createState() => _HouseholdSizeViewState();
}

class _HouseholdSizeViewState extends State<HouseholdSizeView> {
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
      child: const _HouseholdSizeContent(),
    );
  }
}

class _HouseholdSizeContent extends StatefulWidget {
  const _HouseholdSizeContent();

  @override
  State<_HouseholdSizeContent> createState() => _HouseholdSizeContentState();
}

class _HouseholdSizeContentState extends State<_HouseholdSizeContent> {
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
        appBar: AdaptiveAppBar(title: context.l10n.settingsHouseholdSizeTitle),
        body: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 700),
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(AppDimensions.paddingL),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Point-of-use intro: makes clear this sets the default
                  // portion count for recipes and the weekly menu.
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.groups,
                        color: cs.primary,
                        size: AppDimensions.iconSizeAction,
                      ),
                      const SizedBox(width: AppDimensions.spacingM),
                      Expanded(
                        child: Text(
                          context.l10n.householdSettingsIntro,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppDimensions.spacingL),
                  // BUT-1322: household-size default for the portion scaler.
                  StyledCard(
                    child: Padding(
                      padding: const EdgeInsets.all(AppDimensions.paddingL),
                      child: _HouseholdSizeControl(viewModel: viewModel),
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
        SnackBarUtils.showSuccess(context, context.l10n.householdSettingsSaved);
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

  /// Guards back-navigation: with an unsaved household-size change, offer save /
  /// discard / cancel (mirrors the profile-edit exit guard) so a change isn't
  /// silently lost on pop. Returns true when it's safe to leave.
  ///
  /// Save must both persist AND leave (like the profile-edit guard): the dialog
  /// closes with a [_ExitChoice], then Save awaits the write and only pops the
  /// screen if it succeeded — so a failed save keeps the user here with their
  /// unsaved change and the error, rather than silently discarding it.
  Future<bool> _handleBackNavigation(UserProfileViewModel viewModel) async {
    if (!viewModel.hasUnsavedChanges) return true;
    final choice = await showDialog<_ExitChoice>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.profileUnsavedChanges),
        content: Text(dialogContext.l10n.profileUnsavedChangesMessage),
        actions: [
          ActionButtons.secondaryButton(
            dialogContext,
            label: dialogContext.l10n.commonDiscard,
            onPressed: () => Navigator.pop(dialogContext, _ExitChoice.discard),
          ),
          ActionButtons.secondaryButton(
            dialogContext,
            label: dialogContext.l10n.commonCancel,
            onPressed: () => Navigator.pop(dialogContext, _ExitChoice.cancel),
          ),
          ActionButtons.primaryButton(
            dialogContext,
            label: dialogContext.l10n.commonSave,
            onPressed: () => Navigator.pop(dialogContext, _ExitChoice.save),
          ),
        ],
      ),
    );
    switch (choice) {
      case _ExitChoice.discard:
        return true;
      case _ExitChoice.save:
        await _save();
        // Leave only if the save actually landed; a failed save (error shown by
        // _save) keeps the user here with their change intact.
        return !viewModel.hasUnsavedChanges;
      case _ExitChoice.cancel:
      case null:
        return false;
    }
  }
}

/// Outcome of the unsaved-changes exit dialog on [HouseholdSizeView].
enum _ExitChoice { save, discard, cancel }

/// BUT-1322: stepper for the household-size default (how many people the user
/// usually cooks for). Null renders as "Receptets standard"; stepping below 1
/// — or the explicit clear button — returns to null, so the default state is
/// always recoverable. Persistence goes through
/// [UserProfileViewModel.saveProfile], the same path the profile-edit screen
/// uses.
class _HouseholdSizeControl extends StatelessWidget {
  final UserProfileViewModel viewModel;

  const _HouseholdSizeControl({required this.viewModel});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final size = viewModel.householdSize;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // No card label: the screen title ("Hushållsstorlek") already names
        // this, so the card leads straight with the explanatory hint.
        Text(
          context.l10n.settingsHouseholdSizeHint,
          style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppDimensions.spacingXs),
        Row(
          children: [
            IconButton(
              // Below 1 clears back to null ("recipe default").
              onPressed: size == null
                  ? null
                  : () => viewModel.updateHouseholdSize(
                      size <= UserProfile.minHouseholdSize ? null : size - 1,
                    ),
              icon: const Icon(Icons.remove),
              tooltip: context.l10n.a11yDecreaseHouseholdSize,
            ),
            Expanded(
              child: Text(
                size?.toString() ?? context.l10n.householdSizeRecipeDefault,
                textAlign: TextAlign.center,
                style: AppTextStyles.titleMedium.copyWith(
                  color: size == null ? cs.onSurfaceVariant : cs.onSurface,
                ),
              ),
            ),
            IconButton(
              onPressed: (size != null && size >= UserProfile.maxHouseholdSize)
                  ? null
                  : () => viewModel.updateHouseholdSize((size ?? 0) + 1),
              icon: const Icon(Icons.add),
              tooltip: context.l10n.a11yIncreaseHouseholdSize,
            ),
          ],
        ),
        if (size != null)
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: TextButton(
              onPressed: () => viewModel.updateHouseholdSize(null),
              child: Text(context.l10n.householdSizeUseRecipeDefault),
            ),
          ),
      ],
    );
  }
}
