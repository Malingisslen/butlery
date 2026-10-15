import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/viewmodels/auth_viewmodel.dart';
import 'package:butlery/views/auth/mfa_challenge_view.dart';
import 'package:butlery/views/auth/provider_link_view.dart';
import 'package:butlery/widgets/common/brand/provider_button.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';

/// "Fortsätt med Google" and "Fortsätt med Apple" above the e-mail form, with
/// the "eller" line under them (BUT-916 mockup, screen 1). Nothing is drawn
/// where neither provider is offered (desktop).
///
/// Both buttons keep their providers' own colours: Google's white or dark
/// fill with a grey edge, Apple's black in light mode and white in dark
/// (Apple HIG). Only the app's square corners are ours.
class SocialSignInButtons extends StatelessWidget {
  const SocialSignInButtons({
    super.key,
    required this.viewModel,
    required this.onSignedIn,
  });

  final AuthViewModel viewModel;

  /// Called once a sign-in (with its second factor or link step, if any) has
  /// gone through.
  final void Function({bool signedInWithBackupCode}) onSignedIn;

  @override
  Widget build(BuildContext context) {
    final offered = [
      for (final provider in SignInProvider.values)
        if (viewModel.isProviderOffered(provider)) provider,
    ];
    if (offered.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final provider in offered) ...[
          ProviderButton(
            provider: provider,
            onPressed: viewModel.isLoading
                ? null
                : () => _run(context, provider),
          ),
          const SizedBox(
            height: AppDimensions.space8 + AppDimensions.space4,
          ),
        ],
        const SizedBox(height: AppDimensions.space8),
        ButleryLabelledDivider(label: context.l10n.commonOr),
        const SizedBox(height: AppDimensions.space24),
      ],
    );
  }

  Future<void> _run(BuildContext context, SignInProvider provider) async {
    final navigator = Navigator.of(context);
    final outcome = await viewModel.signInWithProvider(provider);
    if (!context.mounted) return;
    switch (outcome) {
      case ProviderSignInOutcome.signedIn:
        onSignedIn();
      case ProviderSignInOutcome.mfaRequired:
        final challenge = viewModel.pendingMfaChallenge;
        if (challenge == null) return;
        final result = await navigator.push<MfaChallengeResult>(
          MaterialPageRoute(
            builder: (_) =>
                MfaChallengeView(challenge: challenge, provider: provider),
          ),
        );
        if (result != null && context.mounted) {
          onSignedIn(
            signedInWithBackupCode:
                result == MfaChallengeResult.signedInWithBackupCode,
          );
        }
      case ProviderSignInOutcome.linkNeedsPassword:
        final result = await navigator.push<MfaChallengeResult>(
          MaterialPageRoute(builder: (_) => const ProviderLinkView()),
        );
        if (result != null && context.mounted) {
          onSignedIn(
            signedInWithBackupCode:
                result == MfaChallengeResult.signedInWithBackupCode,
          );
        }
      case ProviderSignInOutcome.cancelled:
      case ProviderSignInOutcome.failed:
        break;
    }
  }
}
