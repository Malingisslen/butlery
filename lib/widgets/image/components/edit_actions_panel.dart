import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/icons/adaptive_icon.dart';

/// Floating action buttons for image editing operations
class EditActionsPanel extends StatelessWidget {
  final bool canAddImage;
  final bool canSetPrimary;
  final VoidCallback? onAddImage;
  final VoidCallback? onSetPrimary;
  final VoidCallback? onRemoveImage;

  const EditActionsPanel({
    super.key,
    this.canAddImage = true,
    this.canSetPrimary = false,
    this.onAddImage,
    this.onSetPrimary,
    this.onRemoveImage,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: AppDimensions.spacingMd,
      right: AppDimensions.spacingMd,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (canAddImage)
            _EditActionButton(
              icon: Icons.add_photo_alternate_outlined,
              onTap: onAddImage,
              tooltip: context.l10n.imageAddImage,
            ),
          const SizedBox(height: AppDimensions.spacingSm),
          if (canSetPrimary)
            _EditActionButton(
              icon: AdaptiveIcons.primaryOutline,
              onTap: onSetPrimary,
              tooltip: context.l10n.imageSetAsPrimary,
            ),
          const SizedBox(height: AppDimensions.spacingSm),
          _EditActionButton(
            icon: Icons.delete_outline,
            onTap: onRemoveImage,
            tooltip: context.l10n.imageRemoveImage,
            isDestructive: true,
          ),
        ],
      ),
    );
  }
}

class _EditActionButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final String tooltip;
  final bool isDestructive;

  const _EditActionButton({
    required this.icon,
    this.onTap,
    required this.tooltip,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: Material(
        color: isDestructive ? cs.error : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
        child: Semantics(
          label: context.l10n.a11yEditImageAction(tooltip),
          button: true,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
            child: Container(
              padding: const EdgeInsets.all(AppDimensions.spacingSm),
              child: Icon(
                icon,
                size: AppDimensions.iconSizeM,
                color:
                    isDestructive ? cs.surfaceContainerHighest : cs.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
