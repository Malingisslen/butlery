/// The calm card an empty view shows in place of its list: an outline, a title
/// and a line of what to do, drawn as Hem's empty state is (Skarmar v12 del 4
/// #hemtom): 1 px border.subtle, 12 dp radius, no tint, no illustration (B-19).
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class EmptyNoticeCard extends StatelessWidget {
  const EmptyNoticeCard({
    super.key,
    required this.title,
    required this.body,
    this.action,
  });

  final String title;
  final String body;

  /// The one action the card offers, if it offers one.
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppDimensions.space16 + AppDimensions.space4,
        vertical: AppDimensions.space24,
      ),
      decoration: BoxDecoration(
        border: Border.all(color: cs.outlineVariant),
        borderRadius: BorderRadius.circular(AppDimensions.radiusCard),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Semantics(
            header: true,
            child: Text(
              title,
              style: AppTextStyles.titleLargeBold.copyWith(color: cs.onSurface),
            ),
          ),
          const SizedBox(height: AppDimensions.space8),
          Text(
            body,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
          if (action != null) ...[
            const SizedBox(height: AppDimensions.space16),
            action!,
          ],
        ],
      ),
    );
  }
}
