// "Prova utan konto" (BUT-920): the questions a new account answers, birth
// year and the terms, before a guest is signed in.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/services/guest/guest_start_coordinator.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/app/auth/auth_wrapper.dart';
import 'package:butlery/widgets/auth/auth_surface.dart';
import 'package:butlery/widgets/auth/birth_year_dropdown.dart';
import 'package:butlery/widgets/auth/terms_consent_row.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/styled/field_helper_line.dart';

/// Says that the server refused the age, when the guest start screen is no
/// longer there to show it.
Future<void> showGuestTooYoungDialog(BuildContext context) {
  return showDialog<void>(
    context: context,
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
}

/// A guest start that failed after its screen was gone says so on the
/// screen it fell back to, once that screen is drawn.
void showPendingGuestStartFailure(State<StatefulWidget> screen) {
  final failure = ServiceLocator.tryGet<GuestStartCoordinator>()
      ?.takePendingFailure();
  if (failure == null) return;
  WidgetsBinding.instance.addPostFrameCallback((_) {
    if (!screen.mounted) return;
    final context = screen.context;
    if (failure == GuestStartOutcome.tooYoung) {
      showGuestTooYoungDialog(context);
    } else {
      SnackBarUtils.showFailure(context, what: context.l10n.guestStartFailed);
    }
  });
}

class GuestStartView extends StatefulWidget {
  const GuestStartView({super.key});

  static const Key birthYearKey = ValueKey('guestStart.birthYear');
  static const Key submitKey = ValueKey('guestStart.submit');
  static const Key backKey = ValueKey('guestStart.back');

  /// Where a started guest goes: the same gate a sign-in leads to, whichever
  /// route this screen was pushed over. Overridable in tests.
  @visibleForTesting
  static WidgetBuilder destinationBuilder = (context) => const AuthWrapper();

  @override
  State<GuestStartView> createState() => _GuestStartViewState();
}

class _GuestStartViewState extends State<GuestStartView> {
  GuestStartCoordinator? _coordinator;
  int? _birthYear;
  bool _termsAccepted = false;
  bool _tooYoung = false;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _coordinator = ServiceLocator.tryGet<GuestStartCoordinator>();
  }

  Future<void> _submit() async {
    if (_busy) return;
    final l10n = context.l10n;
    final year = _birthYear;
    if (year == null) {
      SnackBarUtils.showWarning(context, l10n.onboardingAgeGateBirthYearHint);
      return;
    }
    // Refused here, before any account exists.
    if (!GuestStartCoordinator.isOldEnough(year)) {
      setState(() => _tooYoung = true);
      return;
    }
    if (!_termsAccepted) {
      SnackBarUtils.showWarning(context, l10n.authTermsAcceptRequired);
      return;
    }
    final coordinator = _coordinator;
    if (coordinator == null) {
      SnackBarUtils.showFailure(context, what: l10n.guestStartFailed);
      return;
    }

    setState(() => _busy = true);
    final outcome = await coordinator.start(year);
    // Unmounted, the failure stays with the coordinator for the sign-in
    // screen to show.
    if (!mounted) return;
    coordinator.takePendingFailure();
    switch (outcome) {
      case GuestStartOutcome.started:
        await Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(builder: GuestStartView.destinationBuilder),
          (_) => false,
        );
      case GuestStartOutcome.tooYoung:
        setState(() {
          _busy = false;
          _tooYoung = true;
        });
      case GuestStartOutcome.failed:
        setState(() => _busy = false);
        SnackBarUtils.showFailure(context, what: l10n.guestStartFailed);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return PopScope(
      canPop: !_busy,
      child: AuthSurface(
        subtitle: l10n.guestTryWithoutAccount,
        child: _tooYoung ? const _TooYoungPanel() : _buildForm(context),
      ),
    );
  }

  Widget _buildForm(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          l10n.guestStartBody,
          style: AppTextStyles.bodyLarge.copyWith(color: cs.onSurfaceVariant),
        ),
        const SizedBox(height: AppDimensions.space24),
        BirthYearDropdown(
          dropdownKey: GuestStartView.birthYearKey,
          selected: _birthYear,
          onChanged: _busy ? null : (year) => setState(() => _birthYear = year),
        ),
        FieldHelperLine(l10n.guestStartYearNote),
        const SizedBox(height: AppDimensions.space16),
        TermsConsentRow(
          accepted: _termsAccepted,
          onChanged: _busy
              ? null
              : (value) => setState(() => _termsAccepted = value),
        ),
        const SizedBox(height: AppDimensions.space16),
        HeroButton(
          key: GuestStartView.submitKey,
          label: l10n.commonContinue,
          onPressed: _submit,
          busy: _busy,
          expand: true,
        ),
        const SizedBox(height: AppDimensions.space8),
        TextButton(
          key: GuestStartView.backKey,
          onPressed: _busy ? null : () => Navigator.of(context).maybePop(),
          child: Text(l10n.guestStartBackToSignIn),
        ),
      ],
    );
  }
}

/// Under 15: the words onboarding's blocked screen uses. No account exists,
/// so there is nothing to sign out of; the way out is back.
class _TooYoungPanel extends StatelessWidget {
  const _TooYoungPanel();

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ButleryIcon(
          ButleryIcons.lock,
          size: AppDimensions.iconSizeHero,
          color: cs.onSurface,
        ),
        const SizedBox(height: AppDimensions.space32),
        Text(
          l10n.onboardingAgeGateTooYoungTitle,
          style: AppTextStyles.headlineSmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.space16),
        Text(
          l10n.onboardingAgeGateTooYoungBody,
          style: AppTextStyles.bodyLarge.copyWith(color: cs.onSurfaceVariant),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: AppDimensions.spacingXxl),
        SizedBox(
          height: AppDimensions.buttonHeight,
          child: ElevatedButton(
            onPressed: () => Navigator.of(context).maybePop(),
            child: Text(l10n.commonBack),
          ),
        ),
        const SizedBox(height: AppDimensions.space16),
        TextButton(
          onPressed: () => showDialog<void>(
            context: context,
            builder: (ctx) => AlertDialog(
              title: Text(ctx.l10n.onboardingAgeGateParentInfoTitle),
              content: Text(ctx.l10n.onboardingAgeGateParentInfoBody),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(ctx).pop(),
                  child: Text(ctx.l10n.commonClose),
                ),
              ],
            ),
          ),
          child: Text(
            l10n.onboardingAgeGateParentOption,
            textAlign: TextAlign.center,
          ),
        ),
      ],
    );
  }
}
