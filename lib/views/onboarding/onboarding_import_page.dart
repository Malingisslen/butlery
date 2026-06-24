/// Import first recipe page for the onboarding wizard.
/// Provides inline URL import instead of navigating to a separate screen.
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/analytics/analytics_events.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/import/import_manager.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/viewmodels/smart_import_viewmodel.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

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
    final viewModel = context.watch<SmartImportViewModel>();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppDimensions.paddingXl),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: AppDimensions.spacingXl),
          Text(
            context.l10n.onboardingImportTitle,
            style: AppTextStyles.headlineMedium.copyWith(
              color: cs.primary,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingSm),
          Text(
            context.l10n.onboardingImportDescription,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXl),

          // Inline URL input
          TextField(
            controller: _urlController,
            onChanged: viewModel.updateInput,
            decoration: InputDecoration(
              hintText: context.l10n.onboardingImportUrlTitle,
              prefixIcon: const Icon(Icons.link),
              suffixIcon: IconButton(
                icon: const Icon(Icons.content_paste),
                tooltip: context.l10n.commonPaste,
                onPressed: () => _pasteFromClipboard(viewModel),
              ),
              border: const OutlineInputBorder(),
            ),
            keyboardType: TextInputType.url,
            textInputAction: TextInputAction.go,
            onSubmitted: (_) => _handleImport(viewModel),
          ),

          const SizedBox(height: AppDimensions.spacingMd),

          // Import button
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: viewModel.canImport && !viewModel.isImporting
                  ? () => _handleImport(viewModel)
                  : null,
              icon: viewModel.isImporting
                  ? LoadingIndicator(
                      size: AppDimensions.iconSizeS,
                      strokeWidth: 2,
                      color: cs.onPrimary,
                    )
                  : const Icon(Icons.download),
              label: Text(
                viewModel.isImporting
                    ? viewModel.progressMessage
                    : context.l10n.importRecipeTitle,
              ),
            ),
          ),

          // Success state
          if (viewModel.phase == ImportPhase.complete &&
              viewModel.importedRecipe != null) ...[
            const SizedBox(height: AppDimensions.spacingMd),
            Container(
              padding: const EdgeInsets.all(AppDimensions.paddingM),
              decoration: BoxDecoration(
                color: context.butleryColors.success.withValues(
                  alpha: AppDimensions.opacityVeryLight,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.check_circle,
                    color: context.butleryColors.success,
                  ),
                  const SizedBox(width: AppDimensions.spacingSm),
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
            const SizedBox(height: AppDimensions.spacingMd),
            Text(
              viewModel.error!,
              style: AppTextStyles.bodySmall.copyWith(color: cs.error),
            ),
            const SizedBox(height: AppDimensions.spacingS),
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: TextButton.icon(
                onPressed: () => _handleImport(viewModel),
                icon: const Icon(Icons.refresh),
                label: Text(context.l10n.commonRetry),
              ),
            ),
          ],

          const SizedBox(height: AppDimensions.spacingMd),

          // Alternative: photo import card (still navigates)
          _ImportOptionCard(
            icon: Icons.camera_alt_outlined,
            title: context.l10n.onboardingImportPhotoTitle,
            description: context.l10n.onboardingImportPhotoDescription,
            onTap: () {
              Navigator.of(context).pushNamed(Routes.photoImport);
            },
          ),

          const Spacer(),
          Center(
            child: Text(
              context.l10n.onboardingImportSkipNote,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.outline,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
        ],
      ),
    );
  }

  Future<void> _pasteFromClipboard(SmartImportViewModel viewModel) async {
    final clipboardData = await Clipboard.getData(Clipboard.kTextPlain);
    if (!mounted || clipboardData?.text == null) return;
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

class _ImportOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final VoidCallback onTap;

  const _ImportOptionCard({
    required this.icon,
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
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            color: cs.surfaceContainerHighest,
            border: Border.all(color: cs.outlineVariant),
          ),
          padding: const EdgeInsets.all(AppDimensions.paddingL),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: cs.primary.withValues(
                    alpha: AppDimensions.opacityLight,
                  ),
                ),
                child: Icon(
                  icon,
                  size: AppDimensions.iconSizeL,
                  color: cs.primary,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.titleMedium),
                    const SizedBox(height: AppDimensions.spacingXs),
                    Text(
                      description,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Icon(
                Icons.chevron_right,
                color: cs.outline,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
