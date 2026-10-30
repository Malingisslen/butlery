// lib/widgets/common/list/status_row.dart
//
// A row that says how one thing came out ('Från fil', result
// mode): a status glyph first, the name, an optional line under it in the
// tone of the status, and a hairline under the row. Rows that can be ticked
// pass [checked] so a screen reader hears the state the glyph draws.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/press_fill.dart';

class StatusRow extends StatelessWidget {
  const StatusRow({
    required this.leading,
    required this.title,
    required this.onTap,
    this.detail,
    this.detailColor,
    this.checked,
    super.key,
  });

  /// The status glyph, drawn in a 24 dp slot.
  final Widget leading;
  final String title;
  final String? detail;

  /// Defaults to the secondary text tone.
  final Color? detailColor;

  /// Null for a row that is not a tick.
  final bool? checked;
  final VoidCallback onTap;

  static const double _slot = 24;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: cs.outlineVariant)),
      ),
      child: Semantics(
        label: detail == null ? title : '$title, $detail',
        checked: checked,
        button: checked == null,
        excludeSemantics: true,
        onTap: onTap,
        child: PressFill(
          surface: PressSurface.base,
          child: InkWell(
            onTap: onTap,
            child: ConstrainedBox(
              constraints: const BoxConstraints(
                minHeight: AppDimensions.minTouchTarget,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  vertical: AppDimensions.space12,
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: _slot,
                      height: _slot,
                      child: Center(child: leading),
                    ),
                    const SizedBox(width: AppDimensions.space12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            title,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color: cs.onSurface,
                            ),
                          ),
                          if (detail != null)
                            Text(
                              detail!,
                              style:
                                  (detailColor == null
                                          ? AppTextStyles.bodySmall
                                          : AppTextStyles.bodySmallBold)
                                      .copyWith(
                                        color:
                                            detailColor ?? cs.onSurfaceVariant,
                                      ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
