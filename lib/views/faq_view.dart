/// FAQ view displaying common questions and answers for Butlery users.

import 'package:flutter/material.dart';

import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';

/// Simple FAQ page with Swedish Q&A content in expandable tiles.
class FaqView extends StatelessWidget {
  const FaqView({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AdaptiveAppBar(
        title: context.l10n.profileFaq,
        titleStyle: AppTextStyles.headerTitle.copyWith(color: cs.onPrimary),
        backgroundColor: cs.primary,
        foregroundColor: cs.onPrimary,
      ),
      backgroundColor: cs.surfaceContainerHighest,
      bottomNavigationBar: LayoutScaffolds.detailBottomNav(context),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: ListView(
            padding: AppDimensions.screenPadding,
            children: [
              _FaqTile(
                question: context.l10n.faqQ1,
                answer: context.l10n.faqA1,
              ),
              _FaqTile(
                question: context.l10n.faqQ2,
                answer: context.l10n.faqA2,
              ),
              _FaqTile(
                question: context.l10n.faqQ3,
                answer: context.l10n.faqA3,
              ),
              _FaqTile(
                question: context.l10n.faqQ4,
                answer: context.l10n.faqA4,
              ),
              _FaqTile(
                question: context.l10n.faqQ5,
                answer: context.l10n.faqA5,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Single expandable FAQ tile.
class _FaqTile extends StatelessWidget {
  final String question;
  final String answer;

  const _FaqTile({required this.question, required this.answer});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return ExpansionTile(
      title: Text(
        question,
        style: AppTextStyles.titleMedium.copyWith(
          color: cs.onSurface,
        ),
      ),
      tilePadding: EdgeInsets.zero,
      childrenPadding: const EdgeInsets.only(
        bottom: AppDimensions.spacingMd,
      ),
      shape: Border(
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
