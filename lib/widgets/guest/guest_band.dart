import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/press_fill.dart';
import 'package:butlery/widgets/guest/guest_builder.dart';
import 'package:butlery/widgets/guest/guest_upgrade_launcher.dart';

/// "Du provar som gäst · Skapa konto" on surface.raised, drawn only for a
/// guest. [GuestBand.actionKey] is the tappable "Skapa konto".
class GuestBand extends StatelessWidget {
  const GuestBand({
    this.launcher = const GuestUpgradeLauncher(),
    this.padding = EdgeInsets.zero,
    super.key,
  });

  static const Key actionKey = ValueKey<String>('guest-band-action');

  final GuestUpgradeLauncher launcher;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return GuestBuilder(
      builder: (context, isGuest) {
        if (!isGuest) return const SizedBox.shrink();
        final cs = Theme.of(context).colorScheme;
        final l10n = context.l10n;
        final radius = BorderRadius.circular(AppDimensions.radiusControl);
        return Padding(
          padding: padding,
          child: Material(
            color: cs.surfaceContainerHighest,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsetsDirectional.only(
                start: AppDimensions.space16,
              ),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      l10n.guestBandLabel,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: cs.onSurface,
                      ),
                    ),
                  ),
                  ExcludeSemantics(
                    child: Padding(
                      padding: const EdgeInsetsDirectional.only(
                        start: AppDimensions.space8,
                      ),
                      child: Text(
                        '·',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: cs.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
                  Semantics(
                    button: true,
                    child: PressFill(
                      surface: PressSurface.raised,
                      child: InkWell(
                        key: actionKey,
                        borderRadius: radius,
                        onTap: () => launcher.launch(context),
                        child: ConstrainedBox(
                          constraints: const BoxConstraints(
                            minHeight: AppDimensions.minTouchTarget,
                          ),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: AppDimensions.space16,
                            ),
                            child: Center(
                              child: Text(
                                l10n.guestCreateAccount,
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: cs.onSurface,
                                  decoration: TextDecoration.underline,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
