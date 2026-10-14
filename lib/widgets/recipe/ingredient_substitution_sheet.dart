import 'package:flutter/material.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/indicators/plate_line.dart';
import 'package:butlery/widgets/common/layout/butlery_divider.dart';
import 'package:butlery/widgets/common/sheets/butlery_sheet_header.dart';
import 'package:butlery/models/cooking/ingredient_substitution.dart';
import 'package:butlery/services/cooking/substitution_suggestion_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Bottom sheet displaying substitution options for an ingredient on the
/// recipe detail page. Read-only — tapping a row does not mutate the recipe
/// (the cooking-mode sheet in `lib/widgets/cooking/substitution_bottom_sheet.dart`
/// owns the "replace in recipe" flow).
class IngredientSubstitutionSheet extends StatefulWidget {
  final String ingredientName;

  const IngredientSubstitutionSheet({
    super.key,
    required this.ingredientName,
  });

  @override
  State<IngredientSubstitutionSheet> createState() =>
      _IngredientSubstitutionSheetState();
}

class _IngredientSubstitutionSheetState
    extends State<IngredientSubstitutionSheet> {
  late Future<List<IngredientSubstitution>> _future;

  @override
  void initState() {
    super.initState();
    final service = ServiceLocator.get<SubstitutionSuggestionService>();
    _future = service.suggestFor(widget.ingredientName);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ButlerySheetHeader(
            title: widget.ingredientName,
            closeLabel: context.l10n.commonClose,
          ),
          const SizedBox(height: 1, child: ButleryDivider()),
          FutureBuilder<List<IngredientSubstitution>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.all(AppDimensions.space32),
                  child: PlateLine(
                    semanticLabel: context.l10n.loadingSubstitutions,
                  ),
                );
              }

              final options = snapshot.data ?? const [];
              if (options.isEmpty) {
                return _buildEmptyState(context);
              }

              return _buildOptionsList(context, options);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.all(AppDimensions.space32),
      child: Center(
        child: Text(
          context.l10n.substitutionEmptyState,
          style: AppTextStyles.bodyMedium.copyWith(
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsList(
    BuildContext context,
    List<IngredientSubstitution> options,
  ) {
    return Flexible(
      child: ListView.separated(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.space16,
          vertical: AppDimensions.space12,
        ),
        itemCount: options.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: AppDimensions.space8),
        itemBuilder: (context, index) =>
            _buildOptionCard(context, options[index]),
      ),
    );
  }

  Widget _buildOptionCard(
    BuildContext context,
    IngredientSubstitution option,
  ) {
    final cs = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(AppDimensions.space12),
      decoration: BoxDecoration(
        color: cs.surfaceContainerHighest,
        border: Border.all(color: cs.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  option.name,
                  style: AppTextStyles.bodyBold.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
              Container(
                padding: AppDimensions.badgePadding,
                decoration: BoxDecoration(
                  color: cs.surface,
                  border: Border.all(color: cs.outlineVariant),
                ),
                child: Text(
                  _formatRatio(option.ratio),
                  style: AppTextStyles.labelMedium.copyWith(
                    color: cs.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (option.context != null && option.context!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.space4),
            Text(
              option.context!,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }

  // Matches the cooking-mode ratio badge formatting (see _RatioBadge in
  // substitution_bottom_sheet.dart) so both entry points render the same way.
  String _formatRatio(double ratio) =>
      ratio == 1.0 ? '1:1' : '${(ratio * 100).round()}%';
}
