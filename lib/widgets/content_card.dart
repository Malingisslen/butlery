// lib/widgets/content_card.dart

import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../theme/app_theme.dart';
import 'cached_recipe_image.dart';

/// 🔥 GENERISK KORTKOMPONENT SOM ERSÄTTER:
/// - recipe_card.dart
/// - optimized_card.dart
/// + framtida kort-typer (menyer, inköpslistor etc.)
///
/// ✨ FÖRDELAR:
/// - Type-safe med composition pattern
/// - Prestanda-optimerad med RepaintBoundary
/// - 100% AppTheme compliant
/// - Flexibla display modes
/// - Enkel att utöka för nya content-typer

/// Enum för olika kort-typer
enum ContentCardType {
  recipe,
  menu,
  shoppingList,
  // Lägg till nya typer här i framtiden
}

/// Enum för olika display-stilar
enum ContentCardStyle {
  detailed, // Full visning med alla detaljer
  compact, // Kompakt visning utan beskrivning/taggar
  grid, // För grid-layout (framtida användning)
}

/// Adapter class för att hantera olika innehållstyper
/// Använder composition istället för inheritance för flexibilitet
class ContentCardAdapter {
  final dynamic item;
  final ContentCardType type;

  const ContentCardAdapter({
    required this.item,
    required this.type,
  });

  String get displayTitle {
    if (item is Recipe) {
      return (item as Recipe).title;
    }
    // Lägg till andra typer här i framtiden
    return 'Unknown Item';
  }

  String get displaySubtitle {
    if (item is Recipe) {
      return (item as Recipe).mealType;
    }
    return '';
  }

  String? get displayDescription {
    if (item is Recipe) {
      final description = (item as Recipe).description;
      return description.isNotEmpty ? description : null;
    }
    return null;
  }

  List<String> get displayImageUrls {
    if (item is Recipe) {
      return (item as Recipe).imageUrls;
    }
    return [];
  }

  List<String>? get displayTags {
    if (item is Recipe) {
      return (item as Recipe).tags;
    }
    return null;
  }

  Widget? getTypeIndicator() {
    if (item is Recipe) {
      return AppTheme.mealTypeChip((item as Recipe).mealType);
    }
    return null;
  }

  Widget? getMetadataWidget() {
    if (item is Recipe) {
      final recipe = item as Recipe;
      final portionsText = recipe.portions != null
          ? '${recipe.portions} portioner'
          : '? portioner';
      final timeText = recipe.timeMinutes != null
          ? '${recipe.timeMinutes} minuter tillagningstid'
          : '? minuter';

      return Text(
        '$portionsText | $timeText',
        style: AppTheme.metadataStyle,
      );
    }
    return null;
  }

  Widget? getStatusWidget() {
    if (item is Recipe) {
      final recipe = item as Recipe;
      List<Widget> statusWidgets = [];

      // Lägg till "Senast tillagad" info
      if (recipe.lastCookedText != null) {
        statusWidgets.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.restaurant,
                size: AppTheme.iconSizeSmall,
                color: recipe.wasCookedRecently
                    ? AppTheme.successColor
                    : AppTheme.textSecondary,
              ),
              SizedBox(width: AppTheme.spacingXs),
              Text(
                recipe.lastCookedText!,
                style: AppTheme.captionStyle.copyWith(
                  color: recipe.wasCookedRecently
                      ? AppTheme.successColor
                      : AppTheme.textSecondary,
                  fontWeight: recipe.wasCookedRecently
                      ? FontWeight.w500
                      : FontWeight.normal,
                ),
              ),
            ],
          ),
        );
      }

      // Lägg till betyg
      if (recipe.rating != null) {
        if (statusWidgets.isNotEmpty) {
          statusWidgets.add(SizedBox(height: AppTheme.spacingSm));
        }

        statusWidgets.add(
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(5, (index) {
              final rating = recipe.rating ?? 0;
              IconData icon;
              if (index + 1 <= rating) {
                icon = Icons.star;
              } else if (index + 0.5 <= rating) {
                icon = Icons.star_half;
              } else {
                icon = Icons.star_border;
              }
              return Icon(
                icon,
                size: AppTheme.iconSizeSmall,
                color: AppTheme.starColor,
              );
            }),
          ),
        );
      }

      // Lägg till source URL indikator
      if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
        if (statusWidgets.isNotEmpty) {
          statusWidgets.add(SizedBox(width: AppTheme.spacingXs));
        }
        statusWidgets.insert(
            0,
            Icon(
              Icons.link,
              size: AppTheme.iconSizeInfo,
              color: AppTheme.primaryColor,
            ));
      }

      return statusWidgets.isNotEmpty
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: statusWidgets,
            )
          : null;
    }
    return null;
  }
}

/// 🔥 GENERISK CONTENT CARD KOMPONENT
class ContentCard extends StatelessWidget {
  final ContentCardAdapter adapter;
  final ContentCardStyle style;
  final VoidCallback? onTap;
  final Widget? trailing;
  final Widget? leading; // För framtida anpassningar
  final bool showFullDetails;
  final EdgeInsets? customMargin;
  final EdgeInsets? customPadding;

  const ContentCard({
    super.key,
    required this.adapter,
    this.style = ContentCardStyle.detailed,
    this.onTap,
    this.trailing,
    this.leading,
    this.showFullDetails = true,
    this.customMargin,
    this.customPadding,
  });

  /// Factory constructor för Recipe cards (bakåtkompatibilitet)
  factory ContentCard.recipe({
    required Recipe recipe,
    VoidCallback? onTap,
    Widget? trailing,
    bool showFullDetails = true,
    EdgeInsets? customMargin,
    EdgeInsets? customPadding,
  }) {
    return ContentCard(
      adapter: ContentCardAdapter(
        item: recipe,
        type: ContentCardType.recipe,
      ),
      onTap: onTap,
      trailing: trailing,
      showFullDetails: showFullDetails,
      customMargin: customMargin,
      customPadding: customPadding,
    );
  }

  /// Factory constructor för kompakta Recipe cards
  factory ContentCard.compactRecipe({
    required Recipe recipe,
    VoidCallback? onTap,
    Widget? trailing,
  }) {
    return ContentCard(
      adapter: ContentCardAdapter(
        item: recipe,
        type: ContentCardType.recipe,
      ),
      style: ContentCardStyle.compact,
      onTap: onTap,
      trailing: trailing,
      showFullDetails: false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // ✅ PRESTANDA-OPTIMERING: RepaintBoundary wrapper
    return RepaintBoundary(
      child: Container(
        margin: customMargin ?? _getDefaultMargin(),
        decoration: _getCardDecoration(),
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.extraLargeRadius,
          child: Padding(
            padding: customPadding ?? _getDefaultPadding(),
            child: _buildCardContent(context),
          ),
        ),
      ),
    );
  }

  /// Bygger huvudinnehållet baserat på style
  Widget _buildCardContent(BuildContext context) {
    switch (style) {
      case ContentCardStyle.compact:
        return _buildCompactLayout(context);
      case ContentCardStyle.grid:
        return _buildGridLayout(context);
      case ContentCardStyle.detailed:
        return _buildDetailedLayout(context);
    }
  }

  /// Detaljerad layout (standard RecipeCard layout)
  Widget _buildDetailedLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Leading widget (om tillgänglig)
        if (leading != null) ...[
          leading!,
          SizedBox(width: AppTheme.spacingMd),
        ],

        // Innehållsbild
        _buildContentImage(),
        SizedBox(width: AppTheme.spacingMd),

        // Huvudinnehåll
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titel och typ-indikator
              _buildTitleRow(context),
              SizedBox(height: AppTheme.spacingSm - 2),

              // Metadata (portioner, tid etc.)
              if (adapter.getMetadataWidget() != null) ...[
                adapter.getMetadataWidget()!,
                SizedBox(height: AppTheme.spacingSm - 2),
              ],

              // Status widget (betyg, "senast tillagd" etc.)
              if (adapter.getStatusWidget() != null) ...[
                adapter.getStatusWidget()!,
                SizedBox(height: AppTheme.spacingSm),
              ],

              // Beskrivning (om showFullDetails)
              if (showFullDetails &&
                  adapter.displayDescription != null &&
                  adapter.displayDescription!.isNotEmpty) ...[
                Text(
                  adapter.displayDescription!,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                SizedBox(height: AppTheme.spacingSm),
              ],

              // Taggar (om showFullDetails)
              if (showFullDetails &&
                  adapter.displayTags != null &&
                  adapter.displayTags!.isNotEmpty) ...[
                _buildTags(),
              ],
            ],
          ),
        ),

        // Trailing widget
        if (trailing != null) ...[
          SizedBox(width: AppTheme.spacingSm),
          trailing!,
        ],
      ],
    );
  }

  /// Kompakt layout för mindre utrymmen
  Widget _buildCompactLayout(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Mindre bild för kompakt layout
        _buildContentImage(size: 50),
        SizedBox(width: AppTheme.spacingSm),

        // Endast titel och typ
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleRow(context),
              if (adapter.getMetadataWidget() != null) ...[
                SizedBox(height: AppTheme.spacingXs),
                adapter.getMetadataWidget()!,
              ],
            ],
          ),
        ),

        if (trailing != null) ...[
          SizedBox(width: AppTheme.spacingSm),
          trailing!,
        ],
      ],
    );
  }

  /// Grid layout för framtida användning
  Widget _buildGridLayout(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Bild överst
        _buildContentImage(
          aspectRatio: 16 / 9,
          width: double.infinity,
        ),
        SizedBox(height: AppTheme.spacingSm),

        // Titel och metadata under
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                adapter.displayTitle,
                style: AppTheme.cardTitleStyle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (adapter.getTypeIndicator() != null) ...[
                SizedBox(height: AppTheme.spacingXs),
                adapter.getTypeIndicator()!,
              ],
            ],
          ),
        ),
      ],
    );
  }

  /// Bygger titel-raden med typ-indikator
  Widget _buildTitleRow(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            adapter.displayTitle,
            style: AppTheme.cardTitleStyle,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (adapter.getTypeIndicator() != null) ...[
          SizedBox(width: AppTheme.spacingSm),
          adapter.getTypeIndicator()!,
        ],
      ],
    );
  }

  /// Bygger innehållsbilden
  Widget _buildContentImage({
    double? size,
    double? width,
    double? aspectRatio,
  }) {
    // För Recipe-typ, använd CachedRecipeImage
    if (adapter.type == ContentCardType.recipe && adapter.item is Recipe) {
      return CachedRecipeImage(
        imageUrls: adapter.displayImageUrls,
        size: size ?? AppTheme.recipeImageSize,
        borderRadius: AppTheme.roundRadius,
      );
    }

    // För andra typer, bygg en generisk bildwidget
    final imageSize = size ?? AppTheme.recipeImageSize;

    return Container(
      width: width ?? imageSize,
      height: aspectRatio != null ? null : imageSize,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor,
        borderRadius: AppTheme.roundRadius,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: aspectRatio != null
          ? AspectRatio(
              aspectRatio: aspectRatio,
              child: _buildPlaceholderContent(),
            )
          : _buildPlaceholderContent(),
    );
  }

  /// Bygger placeholder-innehåll för icke-recipe typer
  Widget _buildPlaceholderContent() {
    IconData icon;
    switch (adapter.type) {
      case ContentCardType.menu:
        icon = Icons.restaurant_menu;
        break;
      case ContentCardType.shoppingList:
        icon = Icons.shopping_cart;
        break;
      case ContentCardType.recipe:
        icon = Icons.fastfood;
        break;
    }

    return Icon(
      icon,
      color: AppTheme.textTertiary,
      size: AppTheme.iconSizeMedium,
    );
  }

  /// Bygger taggar
  Widget _buildTags() {
    if (adapter.displayTags == null || adapter.displayTags!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: AppTheme.spacingSm - 2,
      runSpacing: AppTheme.spacingXs,
      children: adapter.displayTags!
          .take(3)
          .map((tag) => AppTheme.tagChip(tag))
          .toList(),
    );
  }

  /// Standard margin baserat på typ
  EdgeInsets _getDefaultMargin() {
    switch (style) {
      case ContentCardStyle.compact:
        return EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm,
          vertical: AppTheme.spacingXs,
        );
      case ContentCardStyle.grid:
        return EdgeInsets.all(AppTheme.spacingXs);
      case ContentCardStyle.detailed:
        return AppTheme.recipeCardMargin;
    }
  }

  /// Standard padding baserat på typ
  EdgeInsets _getDefaultPadding() {
    switch (style) {
      case ContentCardStyle.compact:
        return EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm,
          vertical: AppTheme.spacingSm,
        );
      case ContentCardStyle.grid:
        return EdgeInsets.all(AppTheme.spacingSm);
      case ContentCardStyle.detailed:
        return AppTheme.recipeCardPadding;
    }
  }

  /// Card decoration
  BoxDecoration _getCardDecoration() {
    return AppTheme.recipeCardDecoration;
  }
}
