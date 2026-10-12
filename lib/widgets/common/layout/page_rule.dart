// lib/widgets/common/layout/page_rule.dart
//
// The 2 px ink rule the light subpage bar stands over in the sketches
// (Notisval, Min familj): it closes the header and starts the content.
library;

import 'package:flutter/material.dart';

import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/widgets/common/layout/butlery_page_body.dart';

class PageRule extends StatelessWidget {
  const PageRule({super.key}) : _inline = false;

  /// Without the page margin, inside a list that already has it.
  const PageRule.inline({super.key}) : _inline = true;

  final bool _inline;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: _inline ? EdgeInsets.zero : ButleryPageBody.margin(context),
      child: Container(
        height: AppDimensions.borderWidthThick,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}

/// The saffron dash with a hairline after it that opens a reading page
/// (Vanliga frågor, Integritetspolicy, Min samling): the sketches' quiet
/// stand-in for a heading.
class AccentRule extends StatelessWidget {
  const AccentRule({super.key}) : _inline = false;

  /// Without the page margin, for a rule drawn inside a column that already
  /// has it, such as a reading page's scroll body.
  const AccentRule.inline({super.key}) : _inline = true;

  final bool _inline;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: _inline
          ? const EdgeInsets.symmetric(vertical: AppDimensions.space8)
          : ButleryPageBody.margin(
              context,
              top: AppDimensions.space16,
              bottom: AppDimensions.space8,
            ),
      child: ExcludeSemantics(
        child: Row(
          children: [
            Container(
              width: AppDimensions.space24,
              height: AppDimensions.space4,
              decoration: BoxDecoration(
                color: cs.secondary,
                borderRadius: BorderRadius.circular(AppDimensions.space4 / 2),
              ),
            ),
            const SizedBox(width: AppDimensions.space12),
            Expanded(
              child: Container(
                height: AppDimensions.borderWidthStandard,
                color: cs.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
