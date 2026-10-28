// lib/widgets/common/diff_field_row.dart
//
// Shared by the edit conflict and
// the suggestion view.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/layout/word_fit.dart';
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionHeading(title),
        const SizedBox(height: AppDimensions.space8),
        for (final v in versions)
          Padding(
            padding: const EdgeInsets.only(bottom: AppDimensions.space8),
            child: isLargeText(context)
                ? _stacked(context, v)
                : _line(context, v),
          ),
      ],
    );
  }

  Widget _marker(DiffVersion v) => Container(
    width: AppDimensions.space12,
    height: AppDimensions.space12,
    margin: const EdgeInsets.only(top: AppDimensions.space4),
    decoration: BoxDecoration(
      color: v.marker,
      borderRadius: BorderRadius.circular(AppDimensions.radiusKnob),
    ),
  );

  Widget _badge(BuildContext context, String badge) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space8,
        vertical: AppDimensions.space4,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppDimensions.radiusPill),
      ),
      child: Text(
        badge.toUpperCase(),
        style: AppTextStyles.overline.copyWith(color: cs.onSurfaceVariant),
      ),
    );
  }

  Widget _name(BuildContext context, DiffVersion v) => Text(
    v.name,
    style: AppTextStyles.labelMediumBold.copyWith(
      color: Theme.of(context).colorScheme.onSurfaceVariant,
    ),
  );

  Widget _text(BuildContext context, DiffVersion v) {
    final cs = Theme.of(context).colorScheme;
    final empty = v.text == null || v.text!.isEmpty;
    return Text(
      empty ? emptyText : v.text!,
      style:
          (v.emphasised
                  ? AppTextStyles.bodySmallBold
                  : AppTextStyles.bodyMedium)
              .copyWith(
                color: cs.onSurface,
                fontStyle: empty ? FontStyle.italic : FontStyle.normal,
              ),
    );
  }

  Widget _line(BuildContext context, DiffVersion v) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _marker(v),
      const SizedBox(width: AppDimensions.space8),
      SizedBox(
        width: AppDimensions.space32 * 2 + AppDimensions.space8,
        child: _name(context, v),
      ),
      Expanded(child: _text(context, v)),
      if (v.badge != null) ...[
        const SizedBox(width: AppDimensions.space8),
        _badge(context, v.badge!),
      ],
    ],
  );

  // At large text the version's name would take a third of the width and
  // leave its text a sliver, so the text goes under the name.
  Widget _stacked(BuildContext context, DiffVersion v) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      _marker(v),
      const SizedBox(width: AppDimensions.space8),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: AppDimensions.space8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                _name(context, v),
                if (v.badge != null) _badge(context, v.badge!),
              ],
            ),
            _text(context, v),
          ],
        ),
      ),
    ],
  );
}
