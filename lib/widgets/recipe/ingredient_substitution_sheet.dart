import 'package:flutter/material.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
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
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppDimensions.paddingL),
            child: Row(
              children: [
                Icon(
                  Icons.swap_horiz,
                  color: cs.primary,
                  size: AppDimensions.iconSizeL,
                ),
                const SizedBox(width: AppDimensions.spacingM),
                Expanded(
                  child: Text(
                    widget.ingredientName,
                    style: AppTextStyles.titleMedium,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(context).pop(),
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(),
                ),
              ],
            ),
          ),
          Divider(height: 1, color: cs.surfaceContainerHigh),
          FutureBuilder<List<IngredientSubstitution>>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingXl),
                  child: Center(
                    child: LoadingIndicator(
                      size: AppDimensions.spinnerSizeSmall,
                      strokeWidth: 2,
                      color: cs.primary,
                    ),
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
      padding: const EdgeInsets.all(AppDimensions.spacingXl),
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
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        itemCount: options.length,
        separatorBuilder: (_, __) =>
            const SizedBox(height: AppDimensions.spacingSm),
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
      padding: const EdgeInsets.all(AppDimensions.paddingM),
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
                  style: AppTextStyles.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                    color: cs.onSurface,
                  ),
                ),
              ),
              Container(
                padding: AppDimensions.paddingSymmetric4x2,
                decoration: BoxDecoration(
                  color: cs.primary
                      .withValues(alpha: AppDimensions.opacityVeryLight),
                  border: Border.all(
                    color: cs.primary
                        .withValues(alpha: AppDimensions.opacityMediumLight),
                  ),
                ),
                child: Text(
                  _formatRatio(option.ratio),
                  style: AppTextStyles.metadataEmphasized.copyWith(
                    color: cs.primary,
                  ),
                ),
              ),
            ],
          ),
          if (option.context != null && option.context!.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingXs),
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
