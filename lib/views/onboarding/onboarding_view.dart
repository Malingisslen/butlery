/// Main onboarding wizard view with PageView navigation.
import 'package:flutter/material.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';
import 'package:provider/provider.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/services/onboarding/onboarding_hold.dart';
import 'package:butlery/viewmodels/onboarding_viewmodel.dart';
import 'package:butlery/views/onboarding/onboarding_age_gate_blocked_view.dart';
import 'package:butlery/views/onboarding/onboarding_age_gate_page.dart';
import 'package:butlery/views/onboarding/onboarding_welcome_page.dart';
import 'package:butlery/views/onboarding/onboarding_allergen_page.dart';
import 'package:butlery/views/onboarding/onboarding_setup_page.dart';
import 'package:butlery/widgets/common/brand/butlery_cloche.dart';
import 'package:butlery/widgets/onboarding/onboarding_parts.dart';
import 'package:butlery/views/onboarding/onboarding_import_page.dart';

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
  // age-gate → welcome → allergen → import. Keep in sync with the PageView
  // children list and the viewmodel's _lastPageIndex (pageCount-1).
  static const int _pageCount = 4;
  static const Duration _doneScreenTime = Duration(milliseconds: 1800);

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: widget.initialPage);
  }

  @override
  void dispose() {
    // Not during the unmount: the wrapper listening to the hold rebuilds.
    if (OnboardingHold.active.value) {
      Future.microtask(() => OnboardingHold.active.value = false);
    }
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
      // Android's back goes one step back, like the Tillbaka button; the first
      // step and the setup page have nowhere to go.
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        if (viewModel.showsSetup || viewModel.isCompleting) return;
        if (viewModel.isFirstPage) return;
        _goBack(context, viewModel);
      },
      child: Scaffold(
        backgroundColor: cs.surface,
        body: SafeArea(
          child: ButleryPageBody(
            width: PageWidth.text,
            // The wizard stays mounted under the setup page so a failed
            // completion lands on the page the user left, not on page 0.
            child: Stack(
              children: [
                Offstage(
                  offstage: viewModel.showsSetup,
                  child: TickerMode(
                    enabled: !viewModel.showsSetup,
                    child: ExcludeFocus(
                      excluding: viewModel.showsSetup,
                      child: _buildWizard(context, viewModel),
                    ),
                  ),
                ),
                if (viewModel.showsSetup) const OnboardingSetupPage(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildWizard(BuildContext context, OnboardingViewModel viewModel) {
    return Padding(
      padding: EdgeInsets.symmetric(
        horizontal: AppDimensions.layoutMarginOf(context),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildTopBar(context, viewModel),
          const Align(
            alignment: AlignmentDirectional.centerStart,
            child: ButleryClocheMark(),
          ),
          const SizedBox(height: AppDimensions.space16),
          const OnboardingPlateRule(),
          const SizedBox(height: AppDimensions.space24),
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: viewModel.setPage,
              children: const [
                OnboardingAgeGatePage(),
                OnboardingWelcomePage(),
                OnboardingAllergenPage(),
                OnboardingImportPage(),
              ],
            ),
          ),
          const SizedBox(height: AppDimensions.space16),
          OnboardingStepDashes(
            count: _pageCount,
            current: viewModel.currentPage,
          ),
          const SizedBox(height: AppDimensions.space16),
          _buildNavigation(context, viewModel),
          const SizedBox(height: AppDimensions.space16),
        ],
      ),
    );
  }

  // The skip link keeps its row on the age gate, so the mark stands at the
  // same height on every step.
  Widget _buildTopBar(BuildContext context, OnboardingViewModel viewModel) {
    final cs = Theme.of(context).colorScheme;

    return SizedBox(
      height: AppDimensions.minTouchTarget,
      child: Align(
        alignment: AlignmentDirectional.centerEnd,
        // Age-gating is compliance, not an optional step — no skip.
        child: viewModel.isAgeGatePage
            ? null
            : TextButton(
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
      ),
    );
  }

  // Next / Complete is ink, square-cornered, as the bell sketch draws it
  // (Skarmar v12 del 2 #onboarding). Before a birth year is chosen on the age
  // gate it is an empty frame, never ink at 50 %. Completing keeps the name
  // and draws the plate line.
  Widget _buildNavigation(BuildContext context, OnboardingViewModel viewModel) {
    return OnboardingNavButtons(
      nextKey: const ValueKey('onboarding.next'),
      nextLabel: viewModel.isLastPage
          ? context.l10n.onboardingComplete
          : context.l10n.onboardingNext,
      onNext: viewModel.isAgeGatePage && viewModel.selectedBirthYear == null
          ? null
          : () => _handleNext(context, viewModel),
      busy: viewModel.isCompleting,
      onBack: viewModel.isFirstPage ? null : () => _goBack(context, viewModel),
    );
  }

  void _goBack(BuildContext context, OnboardingViewModel viewModel) {
    viewModel.previousPage();
    _pageController.previousPage(
      duration: AnimationUtils.getDuration(
        context,
        const Duration(milliseconds: 300),
      ),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _handleNext(
    BuildContext context,
    OnboardingViewModel viewModel,
  ) async {
    if (viewModel.isLastPage) {
      await _completeOnboarding(context, viewModel);
      return;
    }

    // BUT-1386 (ADR-0002): the age gate (page 0) is where the server-side check
    // runs and mints the `ageCompliant` claim. Verify BEFORE advancing so a
    // user who abandons and resumes in a later session already carries the
    // claim (resume re-enters PAST the gate, so this never re-fires for them).
    if (viewModel.isAgeGatePage) {
      final result = await viewModel.verifyAgeGate();
      if (!context.mounted) return;
      switch (result) {
        case AgeGateAdvanceResult.rejected:
          // CF deleted the under-15 account server-side: butler rejection +
          // sign-out + route to start. Do NOT advance.
          await _handleAgeRejection(context);
          return;
        case AgeGateAdvanceResult.error:
          // Infrastructure failure — keep the user on the gate so they retry.
          SnackBarUtils.showFailure(context, what: context.l10n.errorGeneric);
          return;
        case AgeGateAdvanceResult.compliant:
          break; // fall through to advance
      }
    }

    viewModel.nextPage();
    if (!context.mounted) return;
    _pageController.nextPage(
      duration: AnimationUtils.getDuration(
        context,
        const Duration(milliseconds: 300),
      ),
      curve: Curves.easeInOut,
    );
  }

  Future<void> _skipOnboarding(
    BuildContext context,
    OnboardingViewModel viewModel,
  ) async {
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
    BuildContext context,
    OnboardingViewModel viewModel,
  ) async {
    final success = await viewModel.completeOnboarding();
    if (!context.mounted) return;
    if (success) {
      // Let "Varsågod. Det är dukat." be read before the app opens.
      // Reading time, so reduced motion keeps it.
      await Future<void>.delayed(_doneScreenTime);
      if (!context.mounted) return;
      OnboardingHold.active.value = false;
      Navigator.of(context).pushNamedAndRemoveUntil(
        Routes.home,
        (route) => false,
      );
    } else if (viewModel.ageRejected) {
      // BUT-1386 (ADR-0002): the verifySignupAge CF rejected the account as
      // under-15 and has already deleted the Auth record server-side. Show a
      // quiet butler-voice rejection, clear the now-invalid local session, and
      // return the user to the start screen.
      await _handleAgeRejection(context);
    } else {
      SnackBarUtils.showFailure(context, what: context.l10n.errorGeneric);
    }
  }

  Future<void> _handleAgeRejection(BuildContext context) async {
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(ctx.l10n.onboardingAgeRejectedTitle),
        content: Text(ctx.l10n.onboardingAgeRejectedBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: Text(ctx.l10n.commonClose),
          ),
        ],
      ),
    );
    // The CF already deleted the Auth account; clear local auth state so the
    // app doesn't linger on a dangling session.
    try {
      await ServiceLocator.get<AuthService>().signOut();
    } catch (_) {
      // Best-effort — the server-side account is already gone.
    }
    if (!context.mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil(
      Routes.auth,
      (route) => false,
    );
  }
}
