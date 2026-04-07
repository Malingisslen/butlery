/// Bottom sheet for suggesting alternative recipes on a menu slot vote.

// lib/widgets/menu/suggest_alternative_sheet.dart

import 'package:flutter/material.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/layout_components.dart';

/// Shows a bottom sheet for selecting recipes to suggest as vote alternatives.
class SuggestAlternativeSheet {
  static Future<Recipe?> show(
    BuildContext context, {
    required List<Recipe> availableRecipes,
    List<String> excludeRecipeIds = const [],
  }) {
    return showModalBottomSheet<Recipe>(
      context: context,
      isScrollControlled: true,
      builder: (context) => _SheetContent(
        availableRecipes: availableRecipes,
        excludeRecipeIds: excludeRecipeIds,
      ),
    );
  }
}

class _SheetContent extends StatefulWidget {
  final List<Recipe> availableRecipes;
  final List<String> excludeRecipeIds;

  const _SheetContent({
    required this.availableRecipes,
    required this.excludeRecipeIds,
  });

  @override
  State<_SheetContent> createState() => _SheetContentState();
}

class _SheetContentState extends State<_SheetContent> {
  final _searchController = TextEditingController();
  List<Recipe> _filtered = [];

  @override
  void initState() {
    super.initState();
    _filtered = _getFilteredRecipes('');
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  List<Recipe> _getFilteredRecipes(String query) {
    return widget.availableRecipes
        .where((r) => !widget.excludeRecipeIds.contains(r.id))
        .where((r) =>
            query.isEmpty ||
            r.title.toLowerCase().contains(query.toLowerCase()))
        .take(20)
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return DraggableScrollableSheet(
      initialChildSize: 0.6,
      maxChildSize: 0.9,
      minChildSize: 0.3,
      expand: false,
      builder: (context, scrollController) {
        return SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(
                maxWidth: LayoutComponents.valueFor(
                  context: context,
                  mobile: double.infinity,
                  tablet: 600,
                  desktop: 600,
                ),
              ),
              child: Column(
                children: [
                  // Handle
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        vertical: AppDimensions.spacingM),
                    child: Container(
                      width: AppDimensions.spacingXl * 2,
                      height: AppDimensions.spacingXxs,
                      decoration: BoxDecoration(
                        color: cs.onSurfaceVariant,
                        borderRadius:
                            BorderRadius.circular(AppDimensions.spacingXxs),
                      ),
                    ),
                  ),

                  // Title
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingL),
                    child: Text(
                      context.l10n.menuVoteSuggestAlternative,
                      style: AppTextStyles.sectionHeader,
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingM),

                  // Search field
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppDimensions.paddingL),
                    child: TextField(
                      controller: _searchController,
                      decoration: InputDecoration(
                        hintText: context.l10n.commonSearch,
                        prefixIcon: const Icon(Icons.search),
                        border: const OutlineInputBorder(),
                      ),
                      onChanged: (query) {
                        setState(() => _filtered = _getFilteredRecipes(query));
                      },
                    ),
                  ),
                  const SizedBox(height: AppDimensions.spacingS),

                  // Recipe list
                  Expanded(
                    child: _filtered.isEmpty
                        ? Center(
                            child: Text(
                              context.l10n.menuVoteNoAlternatives,
                              style: AppTextStyles.bodyMedium
                                  .copyWith(color: cs.onSurfaceVariant),
                            ),
                          )
                        : ListView.builder(
                            controller: scrollController,
                            itemCount: _filtered.length,
                            padding: const EdgeInsets.symmetric(
                                horizontal: AppDimensions.paddingL),
                            itemBuilder: (context, index) {
                              final recipe = _filtered[index];
                              return ListTile(
                                onTap: () => Navigator.pop(context, recipe),
                                leading: recipe.imageUrls.isNotEmpty
                                    ? ClipRRect(
                                        child: Image.network(
                                          recipe.imageUrls.first,
                                          width: AppDimensions.avatarSizeM,
                                          height: AppDimensions.avatarSizeM,
                                          fit: BoxFit.cover,
                                        ),
                                      )
                                    : Container(
                                        width: AppDimensions.avatarSizeM,
                                        height: AppDimensions.avatarSizeM,
                                        color: cs.surfaceContainer,
                                        child: Icon(
                                          Icons.restaurant,
                                          color: cs.onSurfaceVariant,
                                        ),
                                      ),
                                title: Text(
                                  recipe.title,
                                  style: AppTextStyles.titleSmall,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                subtitle: Text(
                                  recipe.mealType,
                                  style: AppTextStyles.bodySmall
                                      .copyWith(color: cs.onSurfaceVariant),
                                ),
                              );
                            },
                          ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
