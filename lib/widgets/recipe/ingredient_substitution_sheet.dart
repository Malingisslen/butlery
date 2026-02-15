import 'package:flutter/material.dart';

import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/ingredient_substitution.dart';
import 'package:butlery/services/ingredient_substitution_service.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

/// Bottom sheet displaying substitution options for an ingredient.
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
  late Future<IngredientSubstitution?> _future;

  @override
  void initState() {
    super.initState();
    final service = ServiceLocator.get<IngredientSubstitutionService>();
    _future = service.getSubstitutions(widget.ingredientName);
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return SafeArea(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header
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

          // Content
          FutureBuilder<IngredientSubstitution?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return Padding(
                  padding: const EdgeInsets.all(AppDimensions.spacingXl),
                  child: Center(
                    child: SizedBox(
                      width: AppDimensions.spinnerSizeSmall,
                      height: AppDimensions.spinnerSizeSmall,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: cs.primary,
                      ),
                    ),
                  ),
                );
              }

              final substitution = snapshot.data;
              if (substitution == null || substitution.substitutions.isEmpty) {
                return _buildEmptyState(context);
              }

              return _buildOptionsList(context, substitution.substitutions);
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
          'Inga ersattningar hittades',
          style: AppTextStyles.bodyMedium.copyWith(
            color: cs.onSurfaceVariant,
            fontStyle: FontStyle.italic,
          ),
        ),
      ),
    );
  }

  Widget _buildOptionsList(
      BuildContext context, List<SubstitutionOption> options) {
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

  Widget _buildOptionCard(BuildContext context, SubstitutionOption option) {
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
          // Name + ratio row
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
              if (option.ratio != null)
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
                    option.ratio!,
                    style: AppTextStyles.metadataEmphasized.copyWith(
                      color: cs.primary,
                    ),
                  ),
                ),
            ],
          ),

          // Notes
          if (option.notes != null) ...[
            const SizedBox(height: AppDimensions.spacingXs),
            Text(
              option.notes!,
              style: AppTextStyles.bodySmall.copyWith(
                color: cs.onSurfaceVariant,
              ),
            ),
          ],

          // Dietary tags
          if (option.dietaryTags.isNotEmpty) ...[
            const SizedBox(height: AppDimensions.spacingSm),
            Wrap(
              spacing: AppDimensions.spacingXs,
              runSpacing: AppDimensions.spacingXs,
              children: option.dietaryTags.map((tag) {
                return Container(
                  padding: AppDimensions.paddingSymmetric4x2,
                  decoration: BoxDecoration(
                    color: cs.surfaceContainerHigh,
                    border: Border.all(color: cs.surfaceContainerHigh),
                  ),
                  child: Text(
                    tag,
                    style: AppTextStyles.metadataEmphasized.copyWith(
                      color: cs.onSurfaceVariant,
                      fontSize: 11,
                    ),
                  ),
                );
              }).toList(),
            ),
          ],
        ],
      ),
    );
  }
}
