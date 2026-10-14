// lib/widgets/common/list/butlery_item_row.dart
//
// The row for a thing in a list: a person, a category, a choice in a sheet.
// ButleryListRow is the settings-style row (label, value, chevron);
// this one leads with a widget (an avatar, a swatch, a glyph) and ends with
// a widget (a button, a count). It replaces ListTile in views.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_mode_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_glyph.dart';
import 'package:butlery/widgets/common/icons/butlery_icons.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/press_fill.dart';

/// The edge a row can carry.
enum ButleryItemRowEdge { none, selected, error }

class ButleryItemRow extends StatelessWidget {
  const ButleryItemRow({
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingIcon,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.subtitleWidget,
    this.edge = ButleryItemRowEdge.none,
    this.excludeTitleSemantics = false,
    this.danger = false,
    this.selected = false,
    this.showChevron = false,
    this.showCheck = false,
    this.enabled = true,
    this.padded = true,
    this.titleMaxLines,
    super.key,
  }) : assert(
         leading == null || leadingIcon == null,
         'Give a leading widget or a leading glyph, not both.',
       ),
       assert(
         subtitle == null || subtitleWidget == null,
         'Give a subtitle string or a subtitle widget, not both.',
       );

  final String title;
  final String? subtitle;

  /// An avatar, a colour swatch or any widget at the start.
  final Widget? leading;

  /// A glyph at the start, in secondary ink.
  final IconData? leadingIcon;

  /// A button or a count at the end, before the chevron or the check.
  final Widget? trailing;

  /// Null makes the row read-only unless [onLongPress] is set.
  final VoidCallback? onTap;

  /// The shortcut into multi-select on a selectable list (BUT-948).
  final VoidCallback? onLongPress;

  /// A subtitle that is more than one string, such as a failure line in the
  /// error colour. Replaces [subtitle].
  final Widget? subtitleWidget;

  /// An edge around the row: the chosen row in a multi-select, or the
  /// row whose action failed. An error edge replaces the selected one.
  final ButleryItemRowEdge edge;

  /// Leaves the title out of the announcement when something else on the
  /// row already carries the name, so it is not read twice.
  final bool excludeTitleSemantics;

  /// The row removes something: its glyph and title are drawn in error.
  final bool danger;

  /// The row is the chosen one: surface.selected behind it, the title in bold
  /// ink, read out as selected.
  final bool selected;

  /// A chevron: the row leads somewhere.
  final bool showChevron;

  /// A check at the end of the chosen row. Drawn only when [selected].
  final bool showCheck;

  final bool enabled;

  /// The row's own side margin. Off inside a container that already has one.
  final bool padded;

  final int? titleMaxLines;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleColour = !enabled
        ? AppModeColors.textDisabled(cs.brightness)
        : danger
        ? cs.error
        : cs.onSurface;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.minTouchTarget,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: padded ? AppDimensions.space16 : 0,
          vertical: AppDimensions.space8,
        ),
        child: Row(
          children: [
            if (leading != null) ...[
              ExcludeSemantics(child: leading!),
              const SizedBox(width: AppDimensions.space12),
            ] else if (leadingIcon != null) ...[
              ExcludeSemantics(
                child: ButleryIcon(
                  leadingIcon!,
                  color: danger ? cs.error : cs.onSurfaceVariant,
                ),
              ),
              const SizedBox(width: AppDimensions.space12),
            ],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  ExcludeSemantics(
                    excluding: excludeTitleSemantics,
                    child: Text(
                      title,
                      maxLines: titleMaxLines,
                      overflow: titleMaxLines == null
                          ? null
                          : TextOverflow.ellipsis,
                      style:
                          (selected
                                  ? AppTextStyles.bodyBold
                                  : AppTextStyles.bodyMedium)
                              .copyWith(color: titleColour),
                    ),
                  ),
                  if (subtitleWidget != null)
                    subtitleWidget!
                  else if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTextStyles.captionBase.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppDimensions.space8),
              trailing!,
            ],
            if (selected && showCheck) ...[
              const SizedBox(width: AppDimensions.space8),
              ExcludeSemantics(
                child: ButleryIcon(ButleryIcons.check, color: cs.tertiary),
              ),
            ] else if (showChevron) ...[
              const SizedBox(width: AppDimensions.space8),
              const ButleryChevron(),
            ],
          ],
        ),
      ),
    );

    final edgeColour = switch (edge) {
      ButleryItemRowEdge.none => null,
      ButleryItemRowEdge.selected => cs.onSurface,
      ButleryItemRowEdge.error => cs.error,
    };
    final body = edgeColour == null
        ? content
        : DecoratedBox(
            position: DecorationPosition.foreground,
            decoration: BoxDecoration(
              border: Border.all(
                color: edgeColour,
                width: AppDimensions.borderWidthOutlinedEdge,
              ),
            ),
            child: content,
          );

    if (onTap == null && onLongPress == null) {
      return Semantics(
        container: true,
        selected: selected ? true : null,
        child: body,
      );
    }
    return Semantics(
      container: true,
      button: true,
      selected: selected ? true : null,
      enabled: enabled,
      child: Material(
        color: selected ? cs.surfaceContainerHighest : Colors.transparent,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: enabled ? onTap : null,
            onLongPress: enabled ? onLongPress : null,
            child: body,
          ),
        ),
      ),
    );
  }
}
