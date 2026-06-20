/// Main onboarding wizard view with PageView navigation.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/onboarding/onboarding_age_gate_blocked_view.dart';
import 'package:butlery/views/onboarding/onboarding_age_gate_page.dart';
import 'package:butlery/views/onboarding/onboarding_welcome_page.dart';
import 'package:butlery/views/onboarding/onboarding_allergen_page.dart';
import 'package:butlery/views/onboarding/onboarding_dietary_page.dart';
import 'package:butlery/views/onboarding/onboarding_import_page.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';

class OnboardingView extends StatelessWidget {
  /// When non-null, the wizard jumps to this page index on first frame
  /// (BUT-675 resume). null/0 starts the user at the age-gate as before.
  final int initialPage;

  const OnboardingView({super.key, this.initialPage = 0});

  @override
  Widget build(BuildContext context) {
    // BUT-744: VM is constructed via the DI factory (single source of truth
    // for service wiring). `initialPage` is page-level state — it's applied
    // to the VM via [setInitialPage] so the wizard's currentPage matches the
    // PageController's starting index without re-running step-completion logic.
    return ChangeNotifierProvider<OnboardingViewModel>(
      create: (_) {
        final vm = ServiceLocator.get<OnboardingViewModel>();
        if (initialPage != 0) {
          vm.setInitialPage(initialPage);
        }
        return vm;
      },
      child: _OnboardingContent(initialPage: initialPage),
    );
  }
}

class _OnboardingContent extends StatefulWidget {
  final int initialPage;

  const _OnboardingContent({this.initialPage = 0});

  @override
  State<_OnboardingContent> createState() => _OnboardingContentState();
}

class _OnboardingContentState extends State<_OnboardingContent> {
  late final PageController _pageController;
  // age-gate → welcome → allergen → dietary → import. Keep in sync with the
  // PageView children list and the viewmodel's _lastPageIndex (pageCount-1).
  static const int _pageCount = 5;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<OnboardingViewModel>();
    final cs = Theme.of(context).colorScheme;

    // Short-circuit before any Firestore write if the picked year is under 15.
    if (viewModel.selectedBirthYear != null && !viewModel.isAgeGatePassed) {
      return const OnboardingAgeGateBlockedView();
    }

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                children: [
                  // Top bar with skip button
                  _buildTopBar(context, viewModel),
                  // Page content
                  Expanded(
                    child: PageView(
                      controller: _pageController,
                      onPageChanged: viewModel.setPage,
                      children: const [
                        OnboardingAgeGatePage(),
                        OnboardingWelcomePage(),
                        OnboardingAllergenPage(),
                        OnboardingDietaryPage(),
                        OnboardingImportPage(),
                      ],
                    ),
                  ),
                  // Bottom section: dot indicators + navigation button
                  _buildBottomSection(context, viewModel),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTopBar(BuildContext context, OnboardingViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.paddingL,
        vertical: AppDimensions.paddingS,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          // Age-gating is compliance, not an optional step — no skip.
          if (!viewModel.isAgeGatePage)
            TextButton(
              onPressed: viewModel.isCompleting
                  ? null
                  : () => _skipOnboarding(context, viewModel),
              child: Text(
                context.l10n.onboardingSkip,
                style: AppTextStyles.labelLarge.copyWith(
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildBottomSection(
      BuildContext context, OnboardingViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.paddingXl),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Dot indicators (square style)
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pageCount, (index) {
              final isActive = index == viewModel.currentPage;
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppDimensions.spacingXs,
                ),
                child: AnimatedContainer(
                  duration: AnimationUtils.getDuration(
                      context, const Duration(milliseconds: 200)),
                  width: isActive ? 24 : 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isActive
                        ? cs.primary
                        : cs.primary
                            .withValues(alpha: AppDimensions.opacityLight),
                  ),
                ),
              );
            }),
          ),
          const SizedBox(height: AppDimensions.spacingLg),
          // Navigation buttons
          Row(
            children: [
              // Back button (hidden on first page)
              if (!viewModel.isFirstPage)
                Expanded(
                  child: SizedBox(
                    height: AppDimensions.buttonHeight,
                    child: OutlinedButton(
                      onPressed: () {
                        viewModel.previousPage();
                        _pageController.previousPage(
                          duration: AnimationUtils.getDuration(
                              context, const Duration(milliseconds: 300)),
                          curve: Curves.easeInOut,
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        side: BorderSide(color: cs.primary),
                        shape: const RoundedRectangleBorder(),
                      ),
                      child: Text(
                        context.l10n.onboardingBack,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: cs.primary,
                        ),
                      ),
                    ),
                  ),
                ),
              if (!viewModel.isFirstPage)
                const SizedBox(width: AppDimensions.spacingSm),
              // Next / Complete button
              Expanded(
                child: SizedBox(
                  height: AppDimensions.buttonHeight,
                  child: ElevatedButton(
                    onPressed: viewModel.isCompleting ||
                            (viewModel.isAgeGatePage &&
                                viewModel.selectedBirthYear == null)
                        ? null
                        : () => _handleNext(context, viewModel),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: cs.primary,
                      foregroundColor: cs.surfaceContainerHighest,
                      shape: const RoundedRectangleBorder(),
                      disabledBackgroundColor: cs.primary
                          .withValues(alpha: AppDimensions.opacityHalf),
                    ),
                    child: viewModel.isCompleting
                        ? LoadingIndicator(
                            size: AppDimensions.iconSizeM,
                            strokeWidth: 2,
                            color: cs.surfaceContainerHighest,
                          )
                        : Text(
                            viewModel.isLastPage
                                ? context.l10n.onboardingComplete
                                : context.l10n.onboardingNext,
                            style: AppTextStyles.labelLarge.copyWith(
                              color: cs.surfaceContainerHighest,
                            ),
                          ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _handleNext(
      BuildContext context, OnboardingViewModel viewModel) async {
    if (viewModel.isLastPage) {
      await _completeOnboarding(context, viewModel);
    } else {
      viewModel.nextPage();
      _pageController.nextPage(
        duration: AnimationUtils.getDuration(
            context, const Duration(milliseconds: 300)),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _skipOnboarding(
      BuildContext context, OnboardingViewModel viewModel) async {
    // Confirm first — skipping means no allergen/dietary setup, which has a
    // safety implication, so make the choice deliberate.
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.onboardingSkipConfirmTitle),
        content: Text(ctx.l10n.onboardingSkipConfirmMessage),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: Text(ctx.l10n.commonCancel),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: Text(ctx.l10n.onboardingSkip),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    await _completeOnboarding(context, viewModel);
  }

  Future<void> _completeOnboarding(
      BuildContext context, OnboardingViewModel viewModel) async {
    final success = await viewModel.completeOnboarding();
    if (!context.mounted) return;
    if (success) {
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.home,
        (route) => false,
      );
    } else {
      SnackBarUtils.showError(context, context.l10n.errorGeneric);
    }
  }
}
