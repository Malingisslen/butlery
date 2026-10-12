/// FAQ view displaying common questions and answers for Butlery users.

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/icons/butlery_expansion_chevron.dart';
import 'package:butlery/widgets/common/layout/butlery_page.dart';
import 'package:butlery/widgets/common/layout/page_rule.dart';

/// Simple FAQ page with Swedish Q&A content in expandable tiles. The first
/// answer stands open, as the sketch draws it.
class FaqView extends StatelessWidget {
  const FaqView({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final questions = [
      (l10n.faqQ1, l10n.faqA1),
      (l10n.faqQ2, l10n.faqA2),
      (l10n.faqQ3, l10n.faqA3),
      (l10n.faqQ4, l10n.faqA4),
      (l10n.faqQ5, l10n.faqA5),
    ];
    return ButleryPage.undersida(
      title: l10n.profileFaq,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const AccentRule(),
          Expanded(
            child: ListView(
              padding: ButleryPageBody.margin(
                context,
                bottom: AppDimensions.space24,
              ),
              children: [
                for (var i = 0; i < questions.length; i++)
                  _FaqTile(
                    question: questions[i].$1,
                    answer: questions[i].$2,
                    initiallyExpanded: i == 0,
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Single expandable FAQ tile.
class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;
  final bool initiallyExpanded;

  const _FaqTile({
    required this.question,
    required this.answer,
    required this.initiallyExpanded,
  });

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExpansionTile(
      initiallyExpanded: initiallyExpanded,
      // On the page's paper with a hairline, not the theme's raised tile.
      backgroundColor: Colors.transparent,
      collapsedBackgroundColor: Colors.transparent,
      trailing: const ButleryExpansionChevron(),
      title: Text(
        question,
        style: AppTextStyles.titleBold.copyWith(color: cs.onSurface),
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(
        bottom: AppDimensions.space16,
      ),
      shape: Border(
        bottom: BorderSide(
          color: cs.outlineVariant,
          width: AppDimensions.borderWidthStandard,
        ),
      ),
      collapsedShape: Border(
        bottom: BorderSide(
          color: cs.outlineVariant,
          width: AppDimensions.borderWidthStandard,
        ),
      ),
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: Text(
            answer,
            style: AppTextStyles.bodyMedium.copyWith(
              color: cs.onSurfaceVariant,
            ),
          ),
        ),
      ],
    );
  }
}
