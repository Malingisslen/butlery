// lib/widgets/common/diff_field_row.dart
//
// One changed field as the drawn conflict screen sets it (Skarmar v12 del 3
// #28): the field's name in capitals, then one line per version with a square
// marker, the version's name and its text. Shared by the edit conflict and
// the suggestion view.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/section_heading.dart';

class DiffVersion {
  const DiffVersion({
    required this.name,
    required this.text,
    required this.marker,
    this.emphasised = false,
    this.badge,
  });

  final String name;

  /// Null or empty is drawn as [DiffFieldRow.emptyText], in italics.
  final String? text;
  final Color marker;

  /// The version that applies now is drawn in bold.
  final bool emphasised;

  /// The small pill at the end of the line ("GÄLLER").
  final String? badge;
}

class DiffFieldRow extends StatelessWidget {
  const DiffFieldRow({
    required this.title,
    required this.versions,
    required this.emptyText,
    super.key,
  });

  final String title;
  final List<DiffVersion> versions;
  final String emptyText;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(title),
        const SizedBox(height: AppDimensions.space8),
        for (final v in versions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.space8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: AppDimensions.space12,
                  height: AppDimensions.space12,
                  margin: const EdgeInsets.only(top: AppDimensions.space4),
                  decoration: BoxDecoration(
                    color: v.marker,
                    borderRadius: BorderRadius.circular(
                      AppDimensions.radiusKnob,
                    ),
                  ),
                ),
                const SizedBox(width: AppDimensions.space8),
                SizedBox(
                  width: AppDimensions.space32 * 2 + AppDimensions.space8,
                  child: Text(
                    v.name,
                    style: AppTextStyles.labelMediumBold.copyWith(
                      color: cs.onSurfaceVariant,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    (v.text == null || v.text!.isEmpty) ? emptyText : v.text!,
                    style:
                        (v.emphasised
                                ? AppTextStyles.bodySmallBold
                                : AppTextStyles.bodyMedium)
                            .copyWith(
                              color: cs.onSurface,
                              fontStyle: (v.text == null || v.text!.isEmpty)
                                  ? FontStyle.italic
                                  : FontStyle.normal,
                            ),
                  ),
                ),
                if (v.badge != null) ...[
                  const SizedBox(width: AppDimensions.space8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.space8,
                      vertical: AppDimensions.space4,
                    ),
                    decoration: BoxDecoration(
                      border: Border.all(color: cs.outlineVariant),
                      borderRadius: BorderRadius.circular(
                        AppDimensions.radiusPill,
                      ),
                    ),
                    child: Text(
                      v.badge!.toUpperCase(),
                      style: AppTextStyles.overline.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ),
      ],
    );
  }
}
