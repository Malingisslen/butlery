import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// A muted one-line "what this tab shows" helper, with an info icon. Lets the
/// bespoke (non-registry) admin tabs teach themselves too, matching the
/// per-metric "i" dialogs on the registry tabs.
class AdminHelpText extends StatelessWidget {
  final String text;
  const AdminHelpText({required this.text, super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppDimensions.paddingM,
        AppDimensions.paddingM,
        AppDimensions.paddingM,
        0,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, size: 16, color: cs.outline),
          const SizedBox(width: AppDimensions.spacingXs),
          Expanded(
            child: Text(
              text,
              style:
                  AppTextStyles.bodySmall.copyWith(color: cs.onSurfaceVariant),
            ),
          ),
        ],
      ),
    );
  }
}
