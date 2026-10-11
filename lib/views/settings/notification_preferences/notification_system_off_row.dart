import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// Shown at the top when notifications are off in the phone: a 1.5 px error
/// outline, a warning glyph and a way to the system settings.
class NotificationSystemOffRow extends StatelessWidget {
  const NotificationSystemOffRow({required this.onOpenSettings, super.key});

  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    return Container(
      key: const ValueKey('notification-system-off-row'),
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.spacingMd,
        vertical: AppDimensions.spacingSm,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: cs.error, width: 1.5),
        borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: ButleryIcon(
                  ButleryIcons.triangleAlert,
                  color: cs.error,
                  size: AppDimensions.iconSizeS,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Text(
                  l10n.notifSystemOffRow,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: cs.error,
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: AlignmentDirectional.centerEnd,
            child: Semantics(
              button: true,
              label: l10n.a11yOpenSystemSettings,
              onTap: onOpenSettings,
              excludeSemantics: true,
              child: TextButton(
                key: const ValueKey('notification-system-off-open'),
                onPressed: onOpenSettings,
                child: Text(l10n.permOpenSettings),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
