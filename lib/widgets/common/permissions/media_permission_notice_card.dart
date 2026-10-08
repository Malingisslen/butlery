import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart' show ImageSource;

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/utils/os_permission_helper.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/component_themes.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';

/// A camera or photo-library answer explained where the image was wanted,
/// per flow 07 (flows-roles-budget.md:98-106; produktregler.md:680-687):
///
/// - denied: [deniedMessage], with "Fråga igen";
/// - permanently denied: the same, with "Öppna inställningar" instead;
/// - blocked by the device: says so, with no button to fix it;
/// - limited ("valda bilder"): its own state with "Välj fler bilder", never
///   an error (Skarmar v12 etapp 3 #behfoton).
///
/// When the answer stopped the pick, [fallbackLabel] and [onFallback] offer
/// another way to the same result; they are left out where there is none.
///
/// Colours, both modes: the card is slot 834 in #behfoton, #E6EAD9 light =
/// cs.surfaceContainerHighest and #24382C dark = cs.primary; text and glyph
/// are cs.onSurface (#24382C light, #F5F4ED dark). The hint line is slot 620,
/// #627061 light / #C9D3C4 dark.
class MediaPermissionNoticeCard extends StatelessWidget {
  const MediaPermissionNoticeCard({
    super.key,
    required this.source,
    required this.outcome,
    required this.deniedMessage,
    required this.onAskAgain,
    required this.onOpenSettings,
    this.fallbackLabel,
    this.onFallback,
    this.fallbackKey,
  });

  final ImageSource source;
  final OsPermissionOutcome outcome;

  /// What a plain no stops, said where the image was wanted.
  final String deniedMessage;
  final VoidCallback onAskAgain;
  final VoidCallback onOpenSettings;
  final String? fallbackLabel;
  final VoidCallback? onFallback;
  final Key? fallbackKey;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final l10n = context.l10n;
    final camera = source == ImageSource.camera;

    final message = switch (outcome) {
      OsPermissionOutcome.limited => l10n.permPhotosLimited,
      OsPermissionOutcome.permanentlyDenied =>
        camera
            ? l10n.permCameraPermanentlyDenied
            : l10n.permPhotosPermanentlyDenied,
      OsPermissionOutcome.restricted =>
        camera ? l10n.permCameraRestricted : l10n.permPhotosRestricted,
      _ => deniedMessage,
    };

    final label = fallbackLabel;
    final actions = <Widget>[
      if (outcome == OsPermissionOutcome.denied)
        OutlinedButton(
          key: const ValueKey('permission-ask-again'),
          style: ComponentThemes.outlinedButtonStyle(cs),
          onPressed: onAskAgain,
          child: Text(l10n.permAskAgain),
        ),
      if (outcome == OsPermissionOutcome.permanentlyDenied)
        OutlinedButton(
          key: const ValueKey('permission-open-settings'),
          style: ComponentThemes.outlinedButtonStyle(cs),
          onPressed: onOpenSettings,
          child: Text(l10n.permOpenSettings),
        ),
      if (outcome == OsPermissionOutcome.limited)
        OutlinedButton.icon(
          key: const ValueKey('permission-choose-more'),
          style: ComponentThemes.outlinedButtonStyle(cs),
          onPressed: onOpenSettings,
          icon: const ButleryIcon(ButleryIcons.plus),
          label: Text(l10n.permPhotosChooseMore),
        ),
      if (!outcome.isUsable && label != null && onFallback != null)
        TextButton(key: fallbackKey, onPressed: onFallback, child: Text(label)),
    ];

    return Container(
      key: ValueKey('photo-permission-notice-${outcome.name}'),
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.paddingM),
      color: cs.brightness == Brightness.dark
          ? cs.primary
          : cs.surfaceContainerHighest,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExcludeSemantics(
                child: ButleryIcon(
                  camera ? ButleryIcons.camera : ButleryIcons.image,
                  color: cs.onSurface,
                  size: AppDimensions.iconSizeM,
                ),
              ),
              const SizedBox(width: AppDimensions.spacingSm),
              Expanded(
                child: Text(
                  message,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: cs.onSurface,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
          if (outcome == OsPermissionOutcome.limited) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Text(
              l10n.permPhotosLimitedHint,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppModeColors.textBodyMuted(cs.brightness),
              ),
            ),
          ],
          if (actions.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Wrap(
              spacing: AppDimensions.spacingSm,
              runSpacing: AppDimensions.spacingXs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: actions,
            ),
          ],
        ],
      ),
    );
  }
}
