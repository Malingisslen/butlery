/// Import first recipe page for the onboarding wizard.
/// Provides inline URL import instead of navigating to a separate screen.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/data/recipes/recipe_seeds.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/viewmodels/smart_import_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/onboarding/onboarding_parts.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

class OnboardingImportPage extends StatelessWidget {
  const OnboardingImportPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => SmartImportViewModel(
        importManager: ServiceLocator.get<ImportManager>(),
      ),
      child: const _OnboardingImportContent(),
    );
  }
}

class _OnboardingImportContent extends StatefulWidget {
  const _OnboardingImportContent();

  @override
  State<_OnboardingImportContent> createState() =>
      _OnboardingImportContentState();
}

class _OnboardingImportContentState extends State<_OnboardingImportContent> {
  final _urlController = TextEditingController();
  bool _fromClipboard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final viewModel = context.read<SmartImportViewModel>();
      await viewModel.checkClipboardForUrl();
      if (!mounted) return;
      final url = viewModel.clipboardUrl;
      if (url != null) {
        setState(() => _fromClipboard = true);
        _urlController.text = url;
        viewModel.updateInput(url);
      }
    });
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final viewModel = context.watch<SmartImportViewModel>();

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OnboardingIntro(
            title: l10n.onboardingImportTitle,
            description: l10n.onboardingImportDescription,
          ),
          const SizedBox(height: AppDimensions.space24),

          // Inline URL input
          StyledInput(
            controller: _urlController,
            square: true,
            hint: l10n.onboardingImportUrlTitle,
            prefixIcon: const ButleryIcon(ButleryIcons.link),
            suffixIcon: AppIconButton(
              icon: ButleryIcons.copy,
              semanticLabel: l10n.commonPaste,
              onPressed: () => _pasteFromClipboard(viewModel),
            ),
            onChanged: (value) {
              _fromClipboard = false;
              viewModel.updateInput(value);
            },
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _handleImport(viewModel),
          ),
          if (_fromClipboard) ...[
            const SizedBox(height: AppDimensions.space8),
            Row(
              children: [
                ButleryIcon(
                  ButleryIcons.info,
                  size: AppDimensions.iconSizeS,
                  color: cs.onSurfaceVariant,
                ),
                const SizedBox(width: AppDimensions.space8),
                Expanded(
                  child: Text(
                    l10n.onboardingImportFromClipboard,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: AppDimensions.space16),

          // Importing says what it does and draws the plate line along the
          // button's bottom edge, never a spinner (Komponentark v1:365,
          // :372). The step's one filled action is "Klar" in the nav row.
          ActionButtons.outlinedButton(
            context,
            label: l10n.importRecipeTitle,
            loadingText: viewModel.progressMessage,
            icon: ButleryIcons.download,
            isLoading: viewModel.isImporting,
            onPressed: viewModel.canImport
                ? () => _handleImport(viewModel)
                : null,
            isExpanded: true,
            square: true,
          ),

          // Success state
          if (viewModel.phase == ImportPhase.complete &&
              viewModel.importedRecipe != null) ...[
            const SizedBox(height: AppDimensions.space16),
            Container(
              padding: const EdgeInsets.all(AppDimensions.space12),
              decoration: BoxDecoration(
                color: context.modeColors.surfaceTintSuccess,
              ),
              child: Row(
                children: [
                  ButleryIcon(
                    ButleryIcons.circleCheck,
                    color: context.modeColors.onSuccessContainer,
                  ),
                  const SizedBox(width: AppDimensions.space8),
                  Expanded(
                    child: Text(
                      viewModel.importedRecipe!.title,
                      style: AppTextStyles.titleMedium,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],

          // Error state
          if (viewModel.phase == ImportPhase.error &&
              viewModel.error != null) ...[
            const SizedBox(height: AppDimensions.space16),
            Text(
              viewModel.error!,
              style: AppTextStyles.bodySmall.copyWith(color: cs.error),
            ),
            const SizedBox(height: AppDimensions.space4),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: ButleryTextButton(
                label: l10n.commonRetry,
                icon: ButleryIcons.refreshCw,
                onPressed: () => _handleImport(viewModel),
              ),
            ),
          ],

          const SizedBox(height: AppDimensions.space16),

          // Alternative: photo import (still navigates)
          _PhotoRow(
            title: l10n.onboardingImportPhotoTitle,
            description: l10n.onboardingImportPhotoDescription,
            onTap: () {
              Navigator.of(context).pushNamed(Routes.photoImport);
            },
          ),

          const SizedBox(height: AppDimensions.space16),
          Text(
            l10n.onboardingImportSkipNote(
              onboardingCountKey(RecipeSeeds.allRecipes.length),
              RecipeSeeds.allRecipes.length,
            ),
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
              height: 1.5,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard(SmartImportViewModel viewModel) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || clipboardData?.text == null) return;
    setState(() => _fromClipboard = false);
    _urlController.text = clipboardData!.text!;
    viewModel.updateInput(clipboardData.text!);
  }

  Future<void> _handleImport(SmartImportViewModel viewModel) async {
    // BUT-545: dedicated onboarding-import outcome events. Fire attempted
    // before the import call so we count attempts even when the network
    // request never resolves.
    AnalyticsService.tryLog(AnalyticsEvents.onboardingImportAttempted);

    final result = await viewModel.startImport();
    if (!mounted) return;

    if (result is ImportSucceeded) {
      AnalyticsService.tryLog(
        AnalyticsEvents.onboardingImportSucceeded,
        parameters: {'recipe_title_length': result.recipe.title.length},
      );
      // Mark on the wizard VM so completeOnboarding doesn't fire skipped.
      // Read via Provider — the OnboardingImportPage is rendered inside the
      // OnboardingView's ChangeNotifierProvider scope.
      try {
        context.read<OnboardingViewModel>().markOnboardingImportSucceeded();
      } catch (_) {
        // Standalone page (not inside the wizard) — nothing to mark.
      }
      // The manualEntry route reads 'initialRecipe' (see app_router.dart) —
      // 'recipe' was silently dropped, opening the editor blank.
      Navigator.of(context).pushNamed(
        Routes.manualEntry,
        arguments: {
          'initialRecipe': result.recipe,
          // Keep the wizard flow: save pops back here, not out to a recipe detail.
          'navigateToDetailOnSave': false,
        },
      );
    }
  }
}

class _PhotoRow extends StatelessWidget {
  final String title;
  final String description;
  final VoidCallback onTap;

  const _PhotoRow({
    required this.title,
    required this.description,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Semantics(
      button: true,
      label: title,
      excludeSemantics: true,
      onTap: onTap,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              vertical: AppDimensions.space12,
            ),
            decoration: BoxDecoration(
              border: Border.symmetric(
                horizontal: BorderSide(color: cs.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                ButleryIcon(
                  ButleryIcons.camera,
                  size: AppDimensions.iconSizeM,
                  color: cs.onSurface,
                ),
                const SizedBox(width: AppDimensions.space16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: AppTextStyles.titleMedium.copyWith(
                          color: cs.onSurface,
                        ),
                      ),
                      Text(
                        description,
                        style: AppTextStyles.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const ButleryChevron(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
