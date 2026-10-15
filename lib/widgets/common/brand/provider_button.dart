// lib/widgets/common/brand/provider_button.dart
//
// "Fortsätt med Google" and "Fortsätt med Apple". The button keeps its
// provider's own colours (Google's white or dark fill with a grey edge,
// Apple's black in light mode and white in dark, Apple HIG); only the square
// corners are ours.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/auth/provider_sign_in_types.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/brand_colors.dart';
import 'package:butlery/widgets/common/brand/provider_logos.dart';

class ProviderButton extends StatelessWidget {
  const ProviderButton({
    super.key,
    required this.provider,
    required this.onPressed,
  });

  final SignInProvider provider;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (fill, text, edge) = switch (provider) {
      SignInProvider.google =>
        dark
            ? (
                BrandColors.googleButtonDarkFill,
                BrandColors.googleButtonDarkText,
                BrandColors.googleButtonDarkStroke,
              )
            : (
                BrandColors.googleButtonLightFill,
                BrandColors.googleButtonLightText,
                BrandColors.googleButtonLightStroke,
              ),
      SignInProvider.apple =>
        dark
            ? (BrandColors.appleWhite, BrandColors.appleBlack, null)
            : (BrandColors.appleBlack, BrandColors.appleWhite, null),
    };
    final label = switch (provider) {
      SignInProvider.google => context.l10n.authContinueWithGoogle,
      SignInProvider.apple => context.l10n.authContinueWithApple,
    };
    final logo = switch (provider) {
      SignInProvider.google => const GoogleLogo(),
      SignInProvider.apple => AppleLogo(color: text),
    };
    return SizedBox(
      height: AppDimensions.buttonHeight,
      child: TextButton(
        key: ValueKey('auth.provider.${provider.analyticsMethod}'),
        onPressed: onPressed,
        style: TextButton.styleFrom(
          backgroundColor: fill,
          foregroundColor: text,
          disabledBackgroundColor: fill,
          disabledForegroundColor: text,
          shape: RoundedRectangleBorder(
            side: edge == null ? BorderSide.none : BorderSide(color: edge),
          ),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            logo,
            const SizedBox(
              width: AppDimensions.space8 + AppDimensions.space4,
            ),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.titleMedium.copyWith(color: text),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
