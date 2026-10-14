// lib/widgets/common/sheets/butlery_sheet_header.dart
//
// The head of a sheet: the title on the left, the × on the right. Before this
// every sheet drew its own row, with its own padding and its own IconButton.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/buttons/butlery_close_button.dart';

class ButlerySheetHeader extends StatelessWidget {
  const ButlerySheetHeader({
    required this.title,
    this.closeLabel,
    this.onClose,
    this.subtitle,
    this.trailing,
    this.leading,
    this.trailingTopInset = 0,
    super.key,
  });

  final String title;

  /// Names what the × closes. Without it the header draws no ×: a sheet that
  /// is dismissed by a button in its body has no use for one.
  final String? closeLabel;

  /// The × pops the sheet when null.
  final VoidCallback? onClose;

  final String? subtitle;

  /// An action before the ×, such as a text button.
  final Widget? trailing;

  /// A glyph before the title, as the swap icon on the substitution sheet.
  final Widget? leading;

  /// Pushes [trailing] and the × down, for a sheet whose first line is taller
  /// than the buttons.
  final double trailingTopInset;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsetsDirectional.only(
        start: AppDimensions.space24,
        end: AppDimensions.space8,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (leading != null) ...[
            ExcludeSemantics(child: leading!),
            const SizedBox(width: AppDimensions.space12),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    title,
                    style: AppTextStyles.titleLarge.copyWith(
                      color: cs.onSurface,
                    ),
                  ),
                ),
                if (subtitle != null)
                  Text(
                    subtitle!,
                    style: AppTextStyles.captionBase.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          if (trailing != null || closeLabel != null)
            Padding(
              padding: EdgeInsets.only(top: trailingTopInset),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ?trailing,
                  if (closeLabel != null)
                    ButleryCloseButton(
                      semanticLabel: closeLabel!,
                      onPressed: onClose,
                    ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
