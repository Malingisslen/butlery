// "Portioner som standard" on Familj & hushåll (Mer, omtänkt del 2): the
// household-size default that pre-sets recipe portions and scales the weekly
// menu (BUT-1322), chosen in a sheet instead of on a page of its own.
//
// Persistence goes through [UserProfileViewModel.saveProfile], the path the
// profile-edit screen uses, so the value cannot drift between the two and the
// household_size_changed event still fires.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/user_profile_viewmodel.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Opens the sheet. A drag down leaves the stored value as it was; only Klar
/// saves.
Future<void> showHouseholdPortionsSheet(BuildContext context) {
  final cs = Theme.of(context).colorScheme;
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    backgroundColor: cs.surface,
    builder: (_) => const HouseholdPortionsSheet(),
  );
}

/// Public so widget tests can pump it without a route.
class HouseholdPortionsSheet extends StatefulWidget {
  const HouseholdPortionsSheet({super.key});

  @override
  State<HouseholdPortionsSheet> createState() => _HouseholdPortionsSheetState();
}

class _HouseholdPortionsSheetState extends State<HouseholdPortionsSheet> {
  late final UserProfileViewModel _viewModel;

  @override
  void initState() {
    super.initState();
    // Factory registration: an instance of its own, disposed with the sheet.
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
      child: const _PortionsContent(),
    );
  }
}

class _PortionsContent extends StatelessWidget {
  const _PortionsContent();

  Future<void> _done(BuildContext context) async {
    final viewModel = context.read<UserProfileViewModel>();
    // BUT-1459: saveProfile refuses a re-entrant call; bail so that refusal is
    // not reported as a failed save.
    if (viewModel.isSaving) return;
    if (!viewModel.hasUnsavedChanges) {
      Navigator.of(context).pop();
      return;
    }
    final success = await viewModel.saveProfile();
    if (!context.mounted) return;
    if (success) {
      SnackBarUtils.showSuccess(context, context.l10n.householdPortionsSaved);
      Navigator.of(context).pop();
    } else {
      // The sheet stays open with the change, so it can be tried again.
      SnackBarUtils.showFailure(
        context,
        what: viewModel.error ?? context.l10n.profileCouldNotSave,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<UserProfileViewModel>();
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final size = viewModel.householdSize;
    final margin = AppDimensions.layoutMarginOf(context);

    return SingleChildScrollView(
      padding: EdgeInsetsDirectional.fromSTEB(
        margin,
        0,
        margin,
        AppDimensions.layoutMargin,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              l10n.householdPortionsTitle,
              style: AppTextStyles.subpageTitle,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            l10n.settingsHouseholdSizeHint,
            style: AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
          ),
          const SizedBox(height: AppDimensions.spacingMd),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                // Below 1 goes back to null, each recipe's own portions.
                onPressed: size == null
                    ? null
                    : () => viewModel.updateHouseholdSize(
                        size <= UserProfile.minHouseholdSize ? null : size - 1,
                      ),
                icon: const ButleryIcon(ButleryIcons.minus),
                tooltip: l10n.a11yDecreaseHouseholdSize,
              ),
              Expanded(
                child: Text(
                  size?.toString() ?? l10n.householdSizeRecipeDefault,
                  textAlign: TextAlign.center,
                  style:
                      (size == null
                              ? AppTextStyles.titleMedium
                              : AppTextStyles.statNumber)
                          .copyWith(
                            color: size == null
                                ? cs.onSurfaceVariant
                                : cs.onSurface,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                ),
              ),
              IconButton(
                onPressed:
                    (size != null && size >= UserProfile.maxHouseholdSize)
                    ? null
                    : () => viewModel.updateHouseholdSize((size ?? 0) + 1),
                icon: const ButleryIcon(ButleryIcons.plus),
                tooltip: l10n.a11yIncreaseHouseholdSize,
              ),
            ],
          ),
          if (size != null)
            Align(
              alignment: AlignmentDirectional.center,
              child: TextButton(
                onPressed: () => viewModel.updateHouseholdSize(null),
                child: Text(l10n.householdSizeUseRecipeDefault),
              ),
            ),
          const SizedBox(height: AppDimensions.spacingMd),
          HeroButton(
            label: l10n.commonDone,
            onPressed: viewModel.isSaving ? null : () => _done(context),
            busy: viewModel.isSaving,
            busyLabel: l10n.statusSaving,
            expand: true,
          ),
        ],
      ),
    );
  }
}
