// lib/widgets/social/shared_content_row.dart
//
// One shared recipe, menu or shopping list as a row (Skarmar v12
// #delat-med-mig): the picture, the name, who shared it and when, what they
// wrote, and at the end "Spara" or the quiet "Sparad". Delat med mig and a
// friend's shared recipes draw it, so a shared thing looks the same on both.
library;

import 'package:flutter/material.dart';

import 'package:butlery/widgets/common/surfaces/butlery_outlined_box.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/badges/unified_badge.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/recipe_thumb.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/list/butlery_list_sheet.dart';
import 'package:butlery/widgets/common/list/butlery_media_row.dart';

class SharedContentRow extends StatelessWidget {
  const SharedContentRow({
    required this.leading,
    required this.title,
    required this.onOpen,
    this.subtitle,
    this.meta,
    this.message,
    this.saved = false,
    this.saving = false,
    this.onSave,
    this.saveLabel,
    this.savedLabel,
    this.unread = false,
    this.framed = false,
    this.onActions,
    super.key,
  });

  final Widget leading;
  final String title;
  final String? subtitle;

  /// Replaces [subtitle] where the line needs more than words.
  final Widget? meta;

  /// What the sender wrote with the share.
  final String? message;

  /// Already in the user's own: the control is the quiet "Sparad".
  final bool saved;

  /// The save is running; the control cannot be pressed twice.
  final bool saving;

  final VoidCallback? onSave;
  final String? saveLabel;
  final String? savedLabel;

  /// Not opened yet: "· ny" after the name.
  final bool unread;

  /// Each row in a box of its own, as on one friend's page; unframed rows sit
  /// between hairlines.
  final bool framed;
  final VoidCallback onOpen;

  /// Long-press: reply, hide, stop sharing.
  final VoidCallback? onActions;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final row = ButleryMediaRow(
      leading: leading,
      title: title,
      titleSuffix: unread ? l10n.sharedNewMark : null,
      subtitle: subtitle,
      meta: meta,
      extraLine: message == null || message!.isEmpty ? null : '”$message”',
      trailing: saved
          ? UnifiedBadge.status(
              label: savedLabel ?? l10n.sharedSavedState,
              tone: BadgeTone.success,
              icon: ButleryIcons.check,
            )
          : onSave == null
          ? null
          : _SaveButton(
              label: saveLabel ?? l10n.sharedSaveAction,
              onPressed: saving ? null : onSave,
            ),
      onTap: onOpen,
      onLongPress: onActions,
    );
    if (!framed) return row;
    final cs = Theme.of(context).colorScheme;
    return ButleryOutlinedBox(
      paintOnly: true,
      borderColor: cs.outlineVariant,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppDimensions.space12,
          ),
          child: row,
        ),
      ),
    );
  }
}

/// The picture of a shared menu or list, which has none of its own: the
/// recipe plate with the kind's glyph on it.
class SharedKindThumb extends StatelessWidget {
  const SharedKindThumb({required this.icon, super.key});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ClipRRect(
      borderRadius: BorderRadius.circular(AppDimensions.radiusControl),
      child: SizedBox(
        width: RecipeThumb.size,
        height: RecipeThumb.size,
        child: ColoredBox(
          color: context.modeColors.surfaceTintSuccess,
          child: Center(
            child: ButleryIcon(
              icon,
              size: AppDimensions.iconSizeL,
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ),
    );
  }
}

/// The outlined "Spara": the row's one action.
class _SaveButton extends StatelessWidget {
  const _SaveButton({required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return ActionButtons.outlinedButton(
      context,
      label: label,
      onPressed: onPressed,
    );
  }
}

/// What a long-press on a shared row offers: answer the sender, hide it from
/// the list, or stop it being shared. The hide and stop steps confirm
/// themselves.
Future<void> showSharedContentActions(
  BuildContext context, {
  required String title,
  required VoidCallback onDismiss,
  required VoidCallback onUnshare,
  VoidCallback? onReply,
}) async {
  final l10n = context.l10n;
  final choice = await showButleryListSheet<VoidCallback>(
    context,
    title: title,
    rows: (sheetContext) => [
      if (onReply != null)
        ButleryListRow(
          label: l10n.sharedReplyToSender,
          leading: ButleryIcons.reply,
          onTap: () => Navigator.of(sheetContext).pop(onReply),
        ),
      ButleryListRow(
        label: l10n.commonHide,
        leading: ButleryIcons.x,
        onTap: () => Navigator.of(sheetContext).pop(onDismiss),
      ),
      ButleryListRow.danger(
        label: l10n.unshareButton,
        onTap: () => Navigator.of(sheetContext).pop(onUnshare),
      ),
    ],
  );
  choice?.call();
}
