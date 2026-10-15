import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/views/auth/guest_start_view.dart';
import 'package:butlery/widgets/common/buttons/butlery_text_button.dart';

/// "Prova utan konto" on the sign-in screen (BUT-920): a guest tries the app
/// first and can make an account later without losing what they saved.
class GuestEntryButton extends StatelessWidget {
  const GuestEntryButton({required this.enabled, super.key});

  static const Key buttonKey = ValueKey('auth.tryWithoutAccount');

  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return ButleryTextButton(
      key: buttonKey,
      label: context.l10n.guestTryWithoutAccount,
      onPressed: enabled
          ? () => Navigator.of(context).push(
              MaterialPageRoute<void>(builder: (_) => const GuestStartView()),
            )
          : null,
    );
  }
}
