import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/cook_snap.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// BUT-1214: pre-upload dialog offering the per-snap visibility override —
/// "Samma som receptet" (default) or "Bara jag". [message] is the BUT-901
/// audience disclosure built by the caller (public wording or the resolved
/// shared-audience names). Returns the chosen visibility, null on cancel.
///
/// Square design-language restyle approved 2026-06-11 (in-review sign-off):
/// squared dialog on cream, Josefin lowercase title, boxed option tiles with
/// square check indicators instead of Material radios.
Future<CookSnapVisibility?> showCookSnapVisibilityDialog(
  BuildContext context, {
  required String message,
}) {
  var selected = CookSnapVisibility.sameAsRecipe;
  return showDialog<CookSnapVisibility>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setDialogState) => AlertDialog(
        backgroundColor: Theme.of(ctx).colorScheme.surface,
        shape: const RoundedRectangleBorder(),
        title: Row(
          children: [
            Icon(Icons.visibility_outlined,
                size: AppDimensions.iconSizeS,
                color: Theme.of(ctx).colorScheme.onPrimaryContainer),
            const SizedBox(width: AppDimensions.spacingXs),
            Expanded(
              child: Text(
                ctx.l10n.cookSnapVisibilityTitle.toLowerCase(),
                style: AppTextStyles.headlineSmall.copyWith(fontSize: 18),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message),
            const SizedBox(height: AppDimensions.spacingSm),
            _VisibilityOptionTile(
              key: const ValueKey('cook-snap-visibility-same'),
              title: ctx.l10n.cookSnapVisibilityChoiceSame,
              selected: selected == CookSnapVisibility.sameAsRecipe,
              onTap: () => setDialogState(
                  () => selected = CookSnapVisibility.sameAsRecipe),
            ),
            const SizedBox(height: AppDimensions.spacingXs),
            _VisibilityOptionTile(
              key: const ValueKey('cook-snap-visibility-only-me'),
              title: ctx.l10n.cookSnapVisibilityChoiceOnlyMe,
              subtitle: ctx.l10n.cookSnapVisibilityChoiceOnlyMeHint,
              selected: selected == CookSnapVisibility.onlyMe,
              onTap: () =>
                  setDialogState(() => selected = CookSnapVisibility.onlyMe),
            ),
          ],
        ),
        actions: [
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Theme.of(ctx).colorScheme.onSurfaceVariant,
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: () => Navigator.pop(ctx),
            child: Text(ctx.l10n.commonCancel),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(ctx).colorScheme.primary,
              foregroundColor: Theme.of(ctx).colorScheme.onPrimary,
              shape: const RoundedRectangleBorder(),
            ),
            onPressed: () => Navigator.pop(ctx, selected),
            child: Text(ctx.l10n.cookSnapVisibilityConfirm),
          ),
        ],
      ),
    ),
  );
}

/// Radio-style picker tile in the square design language: boxed row with an
/// 18x18 square check indicator (selected = green fill + white check, like the
/// filter toggles). Selection state is exposed via `Semantics(selected:)` per
/// the radio-picker a11y rule.
class _VisibilityOptionTile extends StatelessWidget {
  const _VisibilityOptionTile({
    super.key,
    required this.title,
    this.subtitle,
    required this.selected,
    required this.onTap,
  });

  /// Tile inner padding and indicator-to-text gap (16px; between spacingSm
  /// and spacingMd — matches the approved square-dialog preview).
  static const double _gap = AppDimensions.spacingSm + 4;

  final String title;
  final String? subtitle;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      label: subtitle == null ? title : '$title. $subtitle',
      button: true,
      selected: selected,
      inMutuallyExclusiveGroup: true,
      child: InkWell(
        onTap: onTap,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(_gap),
          decoration: BoxDecoration(
            color: selected
                ? cs.primaryContainer.withValues(alpha: 0.6)
                : cs.surfaceContainerHighest,
            border: Border.all(
              color: selected ? cs.primary : AppColors.creamDarker,
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 18,
                height: 18,
                margin: const EdgeInsets.only(top: 1),
                decoration: BoxDecoration(
                  color: selected ? cs.primary : null,
                  border: selected
                      ? null
                      : Border.all(color: AppColors.creamDarker, width: 2),
                ),
                child: selected
                    ? Icon(Icons.check, size: 14, color: cs.onPrimary)
                    : null,
              ),
              const SizedBox(width: _gap),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.bodyMedium),
                    if (subtitle != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Text(
                          subtitle!,
                          style: AppTextStyles.bodySmall
                              .copyWith(color: cs.onSurfaceVariant),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
