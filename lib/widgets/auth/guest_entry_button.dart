import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/views/auth/guest_start_view.dart';

/// "Prova utan konto" on the sign-in screen (BUT-920): a guest tries the app
/// first and can make an account later without losing what they saved.
class GuestEntryButton extends StatelessWidget {
  const GuestEntryButton({required this.enabled, super.key});

  static const Key buttonKey = ValueKey('auth.tryWithoutAccount');

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return TextButton(
      key: buttonKey,
      onPressed: enabled
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GuestStartView()),
            )
          : null,
      child: Text(
        context.l10n.guestTryWithoutAccount,
        style: AppTextStyles.titleMedium.copyWith(color: cs.onPrimaryContainer),
      ),
    );
  }
}
