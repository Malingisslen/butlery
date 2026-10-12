import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/auth/auth_field_theme.dart';
import 'package:butlery/widgets/common/brand/butlery_lockup.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';

/// The locked logo lockup on the page background with one line under it
/// (Skarmar v12 del 2 #inloggning): a centred 148 px lockup in a
/// `padding:56px 28px 0` block, no divider underneath. The logo is never
/// written as text.
class AuthWordmarkHeader extends StatelessWidget {
  const AuthWordmarkHeader({required this.subtitle, super.key});

  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 56, 28, 0),
      child: Column(
        children: [
          const ButleryLockup(),
          const SizedBox(height: 10),
          Text(
            subtitle,
            textAlign: TextAlign.center,
            // The drawing's 13/400 has no role; bodyMedium (14/400) keeps the
            // weight. The 12/400 caption role failed the rendered
            // text-contrast check at 360 dp in both modes.
            style: AppTextStyles.bodyMedium.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

/// The page every signed-out screen stands on: the wordmark and one line,
/// then the form on the page background, with no top bar. Sign-in, the
/// guest start, "Skapa konto" from a guest and "Välj nytt lösenord" all use
/// it, so they read as one place.
class AuthSurface extends StatelessWidget {
  const AuthSurface({required this.subtitle, required this.child, super.key});

  /// The line under the wordmark: what this screen is for.
  final String subtitle;

  /// The form.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surface,
      body: SafeArea(
        child: SingleChildScrollView(
          child: ButleryPageBody.centered(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                AuthWordmarkHeader(subtitle: subtitle),
                Padding(
                  padding: ButleryPageBody.margin(
                    context,
                    top: AppDimensions.space32,
                    bottom: AppDimensions.space24,
                  ),
                  child: AuthFieldTheme(
                    child: AutofillGroup(child: child),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
