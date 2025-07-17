// lib/widgets/content_card.dart - FIXAD MED 100% APPTHEME

import 'package:flutter/material.dart';
import '../../models/recipe.dart';
import '../../theme/app_theme.dart';
import '../image/universal_image_manager.dart';
import '../image/image_config.dart';

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
        style: AppTheme.metadataStyle, // ✅ AppTheme style
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
                size: AppTheme.iconSizeSmall, // ✅ AppTheme constant
                color: recipe.wasCookedRecently
                    ? AppTheme.successColor // ✅ AppTheme color
                    : AppTheme.textSecondary, // ✅ AppTheme color
              ),
              AppTheme.smallHorizontalGap, // ✅ AppTheme gap
              Text(
                recipe.lastCookedText!,
                style: AppTheme.captionStyle.copyWith(
                  // ✅ AppTheme style
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
          statusWidgets.add(AppTheme.smallGap); // ✅ AppTheme gap
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
                size: AppTheme.iconSizeSmall, // ✅ AppTheme constant
                color: AppTheme.starColor, // ✅ AppTheme color
              );
            }),
          ),
        );
      }

      // Lägg till source URL indikator
      if (recipe.sourceUrl != null && recipe.sourceUrl!.isNotEmpty) {
        if (statusWidgets.isNotEmpty) {
          statusWidgets.add(AppTheme.smallHorizontalGap); // ✅ AppTheme gap
        }
        statusWidgets.insert(
            0,
            Icon(
              Icons.link,
              size: AppTheme.iconSizeInfo, // ✅ AppTheme constant
              color: AppTheme.primaryColor, // ✅ AppTheme color
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
        decoration: _getCardDecoration(context), // ✅ Pass context
        child: InkWell(
          onTap: onTap,
          borderRadius: AppTheme.extraLargeRadius, // ✅ AppTheme radius
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
          AppTheme.mediumHorizontalGap, // ✅ AppTheme gap
        ],

        // Innehållsbild
        _buildContentImage(),
        AppTheme.mediumHorizontalGap, // ✅ AppTheme gap

        // Huvudinnehåll
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Titel och typ-indikator
              _buildTitleRow(context),
              AppTheme.smallGap, // ✅ AppTheme gap

              // Metadata (portioner, tid etc.)
              if (adapter.getMetadataWidget() != null) ...[
                adapter.getMetadataWidget()!,
                AppTheme.smallGap, // ✅ AppTheme gap
              ],

              // Status widget (betyg, "senast tillagd" etc.)
              if (adapter.getStatusWidget() != null) ...[
                adapter.getStatusWidget()!,
                AppTheme.mediumGap, // ✅ AppTheme gap
              ],

              // Beskrivning (om showFullDetails)
              if (showFullDetails &&
                  adapter.displayDescription != null &&
                  adapter.displayDescription!.isNotEmpty) ...[
                Text(
                  adapter.displayDescription!,
                  style: AppTheme.subtitleStyle, // ✅ AppTheme style
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                AppTheme.mediumGap, // ✅ AppTheme gap
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
          AppTheme.smallHorizontalGap, // ✅ AppTheme gap
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
        _buildContentImage(size: AppTheme.thumbnailSize), // ✅ AppTheme constant
        AppTheme.smallHorizontalGap, // ✅ AppTheme gap

        // Endast titel och typ
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildTitleRow(context),
              if (adapter.getMetadataWidget() != null) ...[
                AppTheme.tinyGap, // ✅ AppTheme gap
                adapter.getMetadataWidget()!,
              ],
            ],
          ),
        ),

        if (trailing != null) ...[
          AppTheme.smallHorizontalGap, // ✅ AppTheme gap
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
          aspectRatio: AppTheme.imageAspectRatio, // ✅ AppTheme constant
          width: double.infinity,
        ),
        AppTheme.mediumGap, // ✅ AppTheme gap

        // Titel och metadata under
        Padding(
          padding: EdgeInsets.symmetric(horizontal: AppTheme.spacingSm),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                adapter.displayTitle,
                style: AppTheme.cardTitleStyle, // ✅ AppTheme style
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (adapter.getTypeIndicator() != null) ...[
                AppTheme.tinyGap, // ✅ AppTheme gap
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
            style: AppTheme.cardTitleStyle, // ✅ AppTheme style
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (adapter.getTypeIndicator() != null) ...[
          AppTheme.smallHorizontalGap, // ✅ AppTheme gap
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
      final imageUrl = adapter.displayImageUrls.isNotEmpty ? adapter.displayImageUrls.first : '';
      return UniversalImageManager.cached(
        imageUrl: imageUrl,
        size: ImageSize.card, // Use ImageSize enum instead of double
        borderRadius: AppTheme.roundRadius, // ✅ AppTheme radius
      );
    }

    // För andra typer, bygg en generisk bildwidget
    final imageSize = size ?? AppTheme.recipeImageSize; // ✅ AppTheme constant

    return Container(
      width: width ?? imageSize,
      height: aspectRatio != null ? null : imageSize,
      decoration: BoxDecoration(
        color: AppTheme.backgroundColor, // ✅ AppTheme color
        borderRadius: AppTheme.roundRadius, // ✅ AppTheme radius
        border: Border.all(color: AppTheme.dividerColor), // ✅ AppTheme color
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
      color: AppTheme.textTertiary, // ✅ AppTheme color
      size: AppTheme.iconSizeMedium, // ✅ AppTheme constant
    );
  }

  /// Bygger taggar
  Widget _buildTags() {
    if (adapter.displayTags == null || adapter.displayTags!.isEmpty) {
      return const SizedBox.shrink();
    }

    return Wrap(
      spacing: AppTheme.spacingSm, // ✅ AppTheme spacing
      runSpacing: AppTheme.spacingXs, // ✅ AppTheme spacing
      children: adapter.displayTags!
          .take(3)
          .map((tag) => AppTheme.tagChip(tag)) // ✅ AppTheme widget
          .toList(),
    );
  }

  /// Standard margin baserat på typ
  EdgeInsets _getDefaultMargin() {
    switch (style) {
      case ContentCardStyle.compact:
        return EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm, // ✅ AppTheme spacing
          vertical: AppTheme.spacingXs, // ✅ AppTheme spacing
        );
      case ContentCardStyle.grid:
        return EdgeInsets.all(AppTheme.spacingXs); // ✅ AppTheme spacing
      case ContentCardStyle.detailed:
        return AppTheme.recipeCardMargin; // ✅ AppTheme margin
    }
  }

  /// Standard padding baserat på typ
  EdgeInsets _getDefaultPadding() {
    switch (style) {
      case ContentCardStyle.compact:
        return EdgeInsets.symmetric(
          horizontal: AppTheme.spacingSm, // ✅ AppTheme spacing
          vertical: AppTheme.spacingSm, // ✅ AppTheme spacing
        );
      case ContentCardStyle.grid:
        return EdgeInsets.all(AppTheme.spacingSm); // ✅ AppTheme spacing
      case ContentCardStyle.detailed:
        return AppTheme.recipeCardPadding; // ✅ AppTheme padding
    }
  }

  /// Card decoration
  BoxDecoration _getCardDecoration(BuildContext context) {
    return AppTheme.recipeCardDecoration; // ✅ AppTheme decoration
  }
}
