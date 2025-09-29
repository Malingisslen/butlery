// lib/widgets/shopping/shopping_templates_widget.dart

import 'package:flutter/material.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/widgets/styled/styled_widgets.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';

/// Shopping Templates Widget
/// 
/// Displays available shopping templates and allows creating lists from them
class ShoppingTemplatesWidget extends StatelessWidget {
  final List<Map<String, dynamic>> templates;
  final Function(String templateId, String listName) onCreateFromTemplate;
  final VoidCallback? onCreateNewTemplate;
  final bool isLoading;

  const ShoppingTemplatesWidget({
    super.key,
    required this.templates,
    required this.onCreateFromTemplate,
    this.onCreateNewTemplate,
    this.isLoading = false,
  });

  @override
  Widget build(BuildContext context) {
    if (isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (templates.isEmpty) {
      return _buildEmptyState();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(),
        const SizedBox(height: AppDimensions.spacingM),
        _buildTemplateGrid(),
      ],
    );
  }

  Widget _buildHeader() {
    return Row(
      children: [
        const Icon(
          Icons.library_books,
          color: AppColors.primary,
          size: AppDimensions.iconSizeL,
        ),
        const SizedBox(width: AppDimensions.spacingS),
        Text(
          'Shoppingmallar',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        const Spacer(),
        if (onCreateNewTemplate != null)
          IconButton(
            onPressed: onCreateNewTemplate,
            icon: const Icon(
              Icons.add,
              color: AppColors.primary,
            ),
            tooltip: 'Skapa ny mall',
          ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Container(
      padding: const EdgeInsets.all(AppDimensions.spacingL),
      decoration: BoxDecoration(
        color: AppColors.surfaceVariant.withValues(alpha: 0.3),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        border: Border.all(
          color: AppColors.outline.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.library_books_outlined,
            color: AppColors.outline,
            size: AppDimensions.iconSizeXxl,
          ),
          const SizedBox(height: AppDimensions.spacingM),
          const Text(
            'Inga shoppingmallar än',
            style: AppTextStyles.titleSmall,
          ),
          const SizedBox(height: AppDimensions.spacingS),
          const Text(
            'Skapa mallar från dina vanligaste inköpslistor för att spara tid.',
            style: AppTextStyles.bodyMedium,
            textAlign: TextAlign.center,
          ),
          if (onCreateNewTemplate != null) ...[
            const SizedBox(height: AppDimensions.spacingM),
            StyledButton.primary(
              text: 'Skapa första mallen',
              icon: const Icon(Icons.add),
              onPressed: onCreateNewTemplate,
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildTemplateGrid() {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      cacheExtent: 1000, // Performance optimization: cache more items
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: AppDimensions.spacingM,
        mainAxisSpacing: AppDimensions.spacingM,
        childAspectRatio: 0.85,
      ),
      itemCount: templates.length,
      itemBuilder: (context, index) {
        final template = templates[index];
        return _buildTemplateCard(context, template);
      },
    );
  }

  Widget _buildTemplateCard(BuildContext context, Map<String, dynamic> template) {
    final String name = template['name'] ?? 'Namnlös mall';
    final String? description = template['description'];
    final int itemCount = (template['items'] as List<dynamic>?)?.length ?? 0;
    final int useCount = template['useCount'] ?? 0;
    final List<String> tags = List<String>.from(template['tags'] ?? []);

    return Card(
      elevation: AppDimensions.elevationLow,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
      ),
      child: InkWell(
        onTap: () => _showCreateFromTemplateDialog(context, template),
        borderRadius: BorderRadius.circular(AppDimensions.radiusM),
        child: Padding(
          padding: const EdgeInsets.all(AppDimensions.spacingM),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Template header
              Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: AppColors.primaryContainer.withValues(alpha: 0.3),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                    ),
                    child: const Icon(
                      Icons.library_books,
                      color: AppColors.primary,
                      size: AppDimensions.iconSizeM,
                    ),
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          name,
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (description != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            description,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.onSurface.withValues(alpha: 0.6),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingM),
              
              // Template stats
              Row(
                children: [
                  Icon(
                    Icons.shopping_cart,
                    size: AppDimensions.iconSizeS,
                    color: AppColors.onSurface.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$itemCount artiklar',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.favorite,
                    size: AppDimensions.iconSizeS,
                    color: AppColors.error.withValues(alpha: 0.6),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '$useCount',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.onSurface.withValues(alpha: 0.6),
                    ),
                  ),
                ],
              ),
              
              // Tags
              if (tags.isNotEmpty) ...[
                const SizedBox(height: AppDimensions.spacingS),
                Wrap(
                  spacing: 4,
                  runSpacing: 4,
                  children: tags.take(3).map((tag) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppDimensions.spacingS,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                    ),
                    child: Text(
                      tag,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.secondary,
                        fontSize: 10,
                      ),
                    ),
                  )).toList(),
                ),
              ],
              
              const Spacer(),
              
              // Create button
              SizedBox(
                width: double.infinity,
                child: ActionButtons.outlinedButton(
                  context,
                  label: 'Skapa lista',
                  onPressed: () => _showCreateFromTemplateDialog(context, template),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showCreateFromTemplateDialog(BuildContext context, Map<String, dynamic> template) {
    final nameController = TextEditingController(text: template['name'] ?? '');
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text(
          'Skapa lista från mall',
          style: AppTextStyles.titleMedium,
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Mall: ${template['name']}',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.onSurface.withValues(alpha: 0.6),
              ),
            ),
            const SizedBox(height: AppDimensions.spacingM),
            StyledInput(
              controller: nameController,
              label: 'Listnamn',
              autofocus: true,
            ),
            const SizedBox(height: AppDimensions.spacingM),
            Container(
              padding: const EdgeInsets.all(AppDimensions.spacingM),
              decoration: BoxDecoration(
                color: AppColors.info.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppDimensions.radiusS),
                border: Border.all(
                  color: AppColors.info.withValues(alpha: 0.2),
                ),
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.info_outline,
                    color: AppColors.info,
                    size: AppDimensions.iconSizeM,
                  ),
                  const SizedBox(width: AppDimensions.spacingS),
                  Expanded(
                    child: Text(
                      'Alla artiklar från mallen kommer att läggas till i den nya listan.',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.info,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          StyledButton.secondary(
            text: 'Avbryt',
            onPressed: () => Navigator.of(context).pop(),
          ),
          StyledButton.primary(
            text: 'Skapa lista',
            onPressed: () {
              final listName = nameController.text.trim();
              if (listName.isNotEmpty) {
                Navigator.of(context).pop();
                onCreateFromTemplate(template['id'], listName);
              }
            },
          ),
        ],
      ),
    );
  }
}