import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:butlery/models/auth/mfa_types.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/buttons/hero_button.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/styled/styled_card.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// The phone-number step of enabling two-step verification: a visible,
/// editable country code, the national number and the full number as it
/// will be sent.
class MfaPhoneInputForm extends StatelessWidget {
  const MfaPhoneInputForm({
    super.key,
    required this.countryCodeController,
    required this.phoneController,
    required this.busy,
    required this.onSend,
  });

  final TextEditingController countryCodeController;
  final TextEditingController phoneController;
  final bool busy;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.mfaAddPhoneNumber,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(context.l10n.mfaSmsDescription),
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  flex: 2,
                  child: TextField(
                    key: const ValueKey('mfa.countryCode'),
                    controller: countryCodeController,
                    keyboardType: TextInputType.phone,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[+\d]')),
                    ],
                    decoration: InputDecoration(
                      labelText: context.l10n.mfaCountryCodeLabel,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingSm),
                Expanded(
                  flex: 5,
                  child: TextField(
                    key: const ValueKey('mfa.phoneNumber'),
                    controller: phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      labelText: context.l10n.mfaPhoneNumber,
                      hintText: context.l10n.mfaNationalNumberHint,
                      prefixIcon: const ButleryIcon(ButleryIcons.smartphone),
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ),
              ],
            ),
            ListenableBuilder(
              listenable: Listenable.merge([
                countryCodeController,
                phoneController,
              ]),
              builder: (context, _) {
                final number = parseMfaPhone(
                  countryCode: countryCodeController.text,
                  national: phoneController.text,
                ).number;
                if (number == null) return const SizedBox.shrink();
                return Padding(
                  padding: const EdgeInsets.only(top: AppDimensions.spacingSm),
                  child: Text(
                    context.l10n.mfaCodeWillBeSentTo(number.display),
                    key: const ValueKey('mfa.sendTo'),
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                );
              },
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            // The step's one saffron action (Skarmar v12 etapp 6 'MFA —
            // lägg till telefon', "Skicka kod").
            HeroButton(
              label: context.l10n.mfaSendCode,
              onPressed: onSend,
              busy: busy,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// The step where the SMS code is typed.
class MfaCodeVerificationForm extends StatelessWidget {
  const MfaCodeVerificationForm({
    super.key,
    required this.sentTo,
    required this.codeController,
    required this.busy,
    required this.onCancel,
    required this.onVerify,
  });

  final String sentTo;
  final TextEditingController codeController;
  final bool busy;
  final VoidCallback onCancel;
  final VoidCallback onVerify;

  @override
  Widget build(BuildContext context) {
    return StyledCard(
      child: Padding(
        padding: const EdgeInsets.all(AppDimensions.spacingMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              context.l10n.mfaEnterVerificationCode,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppDimensions.spacingSm),
            Text(context.l10n.mfaCodeSentTo(sentTo)),
            const SizedBox(height: AppDimensions.spacingMd),
            // One field for all six digits, so the whole code can be pasted
            // or autofilled from the SMS (Skarmar v12 del 3 #mfa,
            // "Sex siffror i ett fält").
            TextField(
              key: const ValueKey('mfa.codeField'),
              controller: codeController,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              maxLength: 6,
              decoration: InputDecoration(
                labelText: context.l10n.mfaSixDigitCode,
                prefixIcon: const ButleryIcon(ButleryIcons.lock),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingMd),
            Row(
              children: [
                Expanded(
                  child: ActionButtons.secondaryButton(
                    context,
                    label: context.l10n.commonCancel,
                    onPressed: onCancel,
                    isExpanded: true,
                  ),
                ),
                const SizedBox(width: AppDimensions.spacingL),
                // "Verifiera" is the view's one saffron action (Skarmar v12
                // del 3 #mfa; Grafisk manual v6:219).
                Expanded(
                  child: HeroButton(
                    label: context.l10n.mfaVerify,
                    onPressed: onVerify,
                    busy: busy,
                    expand: true,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class MfaErrorBanner extends StatelessWidget {
  const MfaErrorBanner({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
        border: Border.all(
          color: Theme.of(context).colorScheme.error.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        children: [
          ButleryIcon(
            ButleryIcons.triangleAlert,
            color: Theme.of(context).colorScheme.onErrorContainer,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: Theme.of(context).colorScheme.onErrorContainer,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
