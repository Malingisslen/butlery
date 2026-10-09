import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// The receipt on the sign-in screen after a new password was saved from a
/// reset link (BUT-2170, decision B1). Same card as the session-end notice
/// above the login form.
class PasswordResetDoneNotice extends StatelessWidget {
  const PasswordResetDoneNotice({super.key, required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final cs = Theme.of(context).colorScheme;
    return Container(
      key: const ValueKey('auth.passwordResetDoneNotice'),
      margin: const EdgeInsets.symmetric(horizontal: AppDimensions.spacingXl),
      padding: const EdgeInsets.all(AppDimensions.spacingMd),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ButleryIcon(
            ButleryIcons.circleCheck,
            color: context.modeColors.success,
            size: AppDimensions.iconSizeM,
          ),
          const SizedBox(width: AppDimensions.spacingSm),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                l10n.passwordResetDoneNotice,
                style: AppTextStyles.bodyMedium.copyWith(color: cs.onSurface),
              ),
            ),
          ),
          IconButton(
            tooltip: l10n.commonClose,
            icon: ButleryIcon(ButleryIcons.x, color: cs.onSurfaceVariant),
            onPressed: onClose,
          ),
        ],
      ),
    );
  }
}
