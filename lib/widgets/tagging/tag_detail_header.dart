/// Usage line for the tag page: how many recipes carry the tag and how many
/// of its rules are on.
library;

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/models/tagging/personal_tag.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

class TagDetailHeader extends StatelessWidget {
  final PersonalTag tag;
  final int usageCount;

  const TagDetailHeader({
    super.key,
    required this.tag,
    required this.usageCount,
  });

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).colorScheme.onSurfaceVariant;
    final style = AppTextStyles.captionBase.copyWith(color: muted);

    return Padding(
      padding: const EdgeInsets.only(top: AppDimensions.space8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(context.l10n.tagDetailRecipeCount(usageCount), style: style),
          if (tag.rules.isNotEmpty)
            Text(
              context.l10n.tagDetailRulesActive(
                tag.rules.where((r) => r.isEnabled).length,
                tag.rules.length,
              ),
              style: style,
            ),
        ],
      ),
    );
  }
}
