/// Main onboarding wizard view with PageView navigation.
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
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

class OnboardingView extends StatelessWidget {
  const OnboardingView({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => OnboardingViewModel(),
      child: const _OnboardingContent(),
    );
  }
}

class _OnboardingContent extends StatefulWidget {
  const _OnboardingContent();

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
    _pageController = PageController();
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
                        ? SizedBox(
                            width: AppDimensions.iconSizeM,
                            height: AppDimensions.iconSizeM,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: cs.surfaceContainerHighest,
                            ),
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
