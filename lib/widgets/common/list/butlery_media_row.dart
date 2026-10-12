// lib/widgets/common/list/butlery_media_row.dart
//
// A list row with something to look at at its start: a person's avatar or a
// recipe's picture, then a name and a line under it, and at the end a control,
// a state or a chevron.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/list/butlery_list.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class ButleryMediaRow extends StatelessWidget {
  const ButleryMediaRow({
    required this.leading,
    required this.title,
    this.titleSuffix,
    this.subtitle,
    this.meta,
    this.extraLine,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.chevron = false,
    this.muted = false,
    this.semanticLabel,
    this.selected,
    super.key,
  });

  /// The avatar or picture.
  final Widget leading;

  final String title;

  /// Quiet words after the name on the same line, such as "· du".
  final String? titleSuffix;

  /// The line under the name, in secondary text.
  final String? subtitle;

  /// A line of its own making where the words are not enough, such as time
  /// and a star with the rating. Drawn in place of [subtitle].
  final Widget? meta;

  /// A third line, set in italics: what the sender wrote with a share.
  final String? extraLine;

  /// A control or a state at the end of the row. It keeps its own semantics.
  final Widget? trailing;

  /// Null draws a row that is not a control by itself, such as a member
  /// whose only action is [trailing].
  final VoidCallback? onTap;

  /// A second set of actions for the row, as a sheet. Needs [onTap].
  final VoidCallback? onLongPress;

  /// The row leads somewhere: the chevron at its end.
  final bool chevron;

  /// A row for something no longer there, in secondary text.
  final bool muted;

  /// What a screen reader says for the whole row when the title and the line
  /// under it do not say which row it is.
  final String? semanticLabel;

  /// Non-null for a row that is picked or not picked, as in a list of friends
  /// to choose from; a screen reader says the state with the name.
  final bool? selected;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final titleColor = muted ? cs.onSurfaceVariant : cs.onSurface;
    final content = ConstrainedBox(
      constraints: const BoxConstraints(
        minHeight: AppDimensions.minTouchTarget,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: AppDimensions.space12),
        child: Row(
          children: [
            ExcludeSemantics(child: leading),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text.rich(
                    TextSpan(
                      text: title,
                      style: AppTextStyles.bodyBold.copyWith(color: titleColor),
                      children: [
                        if (titleSuffix != null)
                          TextSpan(
                            text: ' · $titleSuffix',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (meta != null)
                    DefaultTextStyle(
                      style: AppTextStyles.captionBase.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                      child: meta!,
                    )
                  else if (subtitle != null)
                    Text(
                      subtitle!,
                      style: AppTextStyles.captionBase.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  if (extraLine != null)
                    Padding(
                      padding: const EdgeInsets.only(top: AppDimensions.space4),
                      child: Text(
                        extraLine!,
                        style: AppTextStyles.captionBase.copyWith(
                          color: cs.onSurfaceVariant,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                ],
              ),
            ),
            if (trailing != null) ...[
              const SizedBox(width: AppDimensions.space8),
              trailing!,
            ],
            if (chevron) ...[
              const SizedBox(width: AppDimensions.space8),
              const ButleryChevron(),
            ],
          ],
        ),
      ),
    );

    if (onTap == null) {
      return Semantics(container: true, label: semanticLabel, child: content);
    }
    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: semanticLabel,
      onLongPress: onLongPress,
      child: PressFill(
        surface: PressSurface.base,
        child: InkWell(onTap: onTap, onLongPress: onLongPress, child: content),
      ),
    );
  }
}
