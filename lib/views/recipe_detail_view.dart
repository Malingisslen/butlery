// lib/views/recipe_detail_view.dart
// UPPDATERAD för Fas 16 med smart portionsskalning

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:share_plus/share_plus.dart';
import '../models/recipe.dart';
import '../viewmodels/recipe_detail_viewmodel.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/portion_scaler.dart'; // NY IMPORT!
import '../widgets/recipe_image_carousel.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';
import '../services/share_service.dart';

/// ✨ UPPDATERAD RECEPTDETALJ-VY MED SMART PORTIONSSKALNING
class RecipeDetailView extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailView({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => sl<RecipeDetailViewModel>(param1: recipe),
      child: const _RecipeDetailViewContent(),
    );
  }
}

class _RecipeDetailViewContent extends StatefulWidget {
  const _RecipeDetailViewContent();

  @override
  State<_RecipeDetailViewContent> createState() =>
      _RecipeDetailViewContentState();
}

class _RecipeDetailViewContentState extends State<_RecipeDetailViewContent> {
  final ShareService _shareService = sl<ShareService>();

  // State för portionsskalning
  int _currentPortions = 1;
  List<String> _scaledIngredients = [];
  bool _isScaled = false;

  @override
  void initState() {
    super.initState();
    // Initiera med originalvärden
    final viewModel = context.read<RecipeDetailViewModel>();
    _currentPortions = viewModel.recipe.portions ?? 4;
    _scaledIngredients = List.from(viewModel.recipe.ingredients);
  }

  Future<void> _deleteRecipe(BuildContext context) async {
    final viewModel = context.read<RecipeDetailViewModel>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Ta bort recept'),
            content: Text(
              'Är du säker på att du vill ta bort "${viewModel.recipe.title}"?',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, false),
                child: const Text('Avbryt'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(dialogContext, true),
                style: TextButton.styleFrom(
                  foregroundColor: AppTheme.errorColor,
                ),
                child: const Text('Ta bort'),
              ),
            ],
          ),
    );

    if (confirmed == true && context.mounted) {
      final success = await viewModel.deleteRecipe();

      if (context.mounted) {
        if (success) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Recept borttaget'),
              backgroundColor: AppTheme.successColor,
            ),
          );
          Navigator.pop(context);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(viewModel.error ?? 'Kunde inte ta bort recept'),
              backgroundColor: AppTheme.errorColor,
            ),
          );
        }
      }
    }
  }

  Future<void> _shareRecipe(BuildContext context) async {
    final viewModel = context.read<RecipeDetailViewModel>();

    // Dela med skalade ingredienser om användaren har justerat portioner
    final recipeToShare =
        _isScaled
            ? viewModel.recipe.copyWith(
              portions: _currentPortions,
              ingredients: _scaledIngredients,
            )
            : viewModel.recipe;

    final result = await _shareService.shareRecipe(recipeToShare);

    if (result.status == ShareResultStatus.success && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _isScaled
                ? 'Recept delat med $_currentPortions portioner!'
                : 'Recept delat!',
          ),
          backgroundColor: AppTheme.successColor,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  void _onPortionChanged(int newPortions, List<String> scaledIngredients) {
    setState(() {
      _currentPortions = newPortions;
      _scaledIngredients = scaledIngredients;
      _isScaled =
          newPortions !=
          (context.read<RecipeDetailViewModel>().recipe.portions ?? 4);
    });
  }

  // NY METOD för att visa bilder i fullskärm
  Future<void> _showFullscreenImages(
    BuildContext context,
    List<String> imageUrls,
    int initialIndex,
  ) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder:
            (context) => _FullscreenImageViewer(
              imageUrls: imageUrls,
              initialIndex: initialIndex,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeDetailViewModel>();

    return MainLayoutMenu(
      currentIndex: null,
      body: Scaffold(
        appBar: AppBar(
          title: Text(viewModel.recipe.title),
          actions: [
            IconButton(
              icon: AppTheme.actionIcon(context, Icons.share),
              onPressed: () => _shareRecipe(context),
              tooltip:
                  _isScaled
                      ? 'Dela med $_currentPortions portioner'
                      : 'Dela recept',
            ),
            IconButton(
              icon: AppTheme.actionIcon(context, Icons.delete),
              onPressed:
                  viewModel.isDeleting ? null : () => _deleteRecipe(context),
              tooltip: 'Ta bort recept',
            ),
          ],
        ),
        body: Stack(
          children: [
            SingleChildScrollView(
              padding: AppTheme.screenPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // UPPDATERAD: Bildkarusell istället för enkel bild
                  if (viewModel.hasImages)
                    RecipeImageCarousel(
                      imageUrls: viewModel.recipe.imageUrls,
                      height: AppTheme.imageHeightMedium,
                      onTap:
                          () => _showFullscreenImages(
                            context,
                            viewModel.recipe.imageUrls,
                            0,
                          ),
                    ),
                  if (viewModel.hasImages) AppTheme.mediumGap,

                  // Måltidstyp
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppTheme.spacingSm,
                      vertical: AppTheme.spacingXs,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primaryContainer,
                      borderRadius: AppTheme.chipRadius,
                    ),
                    child: Text(
                      viewModel.recipe.mealType,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: Theme.of(context).colorScheme.onPrimaryContainer,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                  AppTheme.mediumGap,

                  // Beskrivning
                  if (viewModel.recipe.description.isNotEmpty) ...[
                    Text(
                      viewModel.recipe.description,
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    AppTheme.mediumGap,
                  ],

                  // Metadata
                  _buildMetadata(context, viewModel),
                  AppTheme.largeGap,

                  // Source URL om den finns
                  if (viewModel.recipe.sourceUrl != null &&
                      viewModel.recipe.sourceUrl!.isNotEmpty) ...[
                    _buildSourceUrl(context, viewModel),
                    AppTheme.largeGap,
                  ],

                  // Taggar
                  if (viewModel.hasTags) ...[
                    Text(
                      'Taggar',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    AppTheme.smallGap,
                    Wrap(
                      spacing: AppTheme.spacingSm,
                      runSpacing: AppTheme.spacingXs,
                      children:
                          viewModel.recipe.tags!
                              .map((tag) => AppTheme.tagChip(tag))
                              .toList(),
                    ),
                    AppTheme.largeGap,
                  ],

                  // NY! PORTIONSSKALNING MED SMART INGREDIENS-UPPDATERING
                  PortionScaler(
                    originalPortions: viewModel.recipe.portions ?? 4,
                    originalIngredients: viewModel.recipe.ingredients,
                    onPortionChanged: _onPortionChanged,
                    minPortions: 1,
                    maxPortions: 20,
                  ),
                  AppTheme.largeGap,

                  // Instruktioner
                  _buildInstructions(context, viewModel),
                  AppTheme.extraLargeGap,

                  // Redigera-knapp
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: AppTheme.actionIcon(context, Icons.edit),
                      label: const Text('Redigera recept'),
                      style: AppTheme.primaryButtonStyle,
                      onPressed: () async {
                        await Navigator.pushNamed(
                          context,
                          '/redigeraRecept',
                          arguments: viewModel.recipe,
                        );
                      },
                    ),
                  ),
                  AppTheme.mediumGap,
                ],
              ),
            ),

            // Loading overlay
            if (viewModel.isDeleting)
              Container(
                color: Colors.black26,
                child: Center(
                  child: Container(
                    padding: AppTheme.cardPadding,
                    decoration: BoxDecoration(
                      color: AppTheme.cardColor,
                      borderRadius: AppTheme.largeRadius,
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        AppTheme.mediumLoadingIndicator(),
                        AppTheme.smallGap,
                        Text(
                          'Tar bort recept...',
                          style: AppTheme.subtitleStyle,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadata(BuildContext context, RecipeDetailViewModel viewModel) {
    return Container(
      width: double.infinity,
      padding: AppTheme.cardPadding,
      decoration: AppTheme.infoBoxDecoration(context),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _buildMetadataItem(
                context,
                Icons.people,
                // Visa nuvarande portioner (kan vara skalad)
                '$_currentPortions ${_currentPortions == 1 ? 'portion' : 'portioner'}',
                isHighlighted: _isScaled,
              ),
              _buildMetadataItem(
                context,
                Icons.access_time,
                '${viewModel.timeDisplay} min',
              ),
              if (viewModel.hasRating)
                _buildMetadataItem(
                  context,
                  Icons.star,
                  viewModel.ratingDisplay,
                ),
            ],
          ),
          if (viewModel.hasRating) ...[
            AppTheme.smallGap,
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(5, (i) {
                final rating = viewModel.recipe.rating!;
                if (i + 1 <= rating) {
                  return Icon(Icons.star, color: AppTheme.starColor, size: 20);
                } else if (i + 0.5 <= rating) {
                  return Icon(
                    Icons.star_half,
                    color: AppTheme.starColor,
                    size: 20,
                  );
                }
                return Icon(
                  Icons.star_border,
                  color: AppTheme.starColor,
                  size: 20,
                );
              }),
            ),
          ],

          // "Tillagad idag"-knapp
          AppTheme.mediumGap,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final success = await viewModel.markAsCooked();
                if (success && context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        viewModel.recipe.lastCookedText == null
                            ? 'Markerad som tillagad för första gången! 🎉'
                            : 'Uppdaterad som tillagad idag!',
                      ),
                      backgroundColor: AppTheme.successColor,
                      duration: const Duration(seconds: 2),
                    ),
                  );
                }
              },
              icon: Icon(
                viewModel.recipe.wasCookedRecently
                    ? Icons.check_circle
                    : Icons.restaurant,
              ),
              label: Text(
                viewModel.recipe.lastCookedText ?? 'Markera som tillagad',
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor:
                    viewModel.recipe.wasCookedRecently
                        ? AppTheme.successColor
                        : Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color:
                      viewModel.recipe.wasCookedRecently
                          ? AppTheme.successColor
                          : Theme.of(context).colorScheme.outline,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetadataItem(
    BuildContext context,
    IconData icon,
    String text, {
    bool isHighlighted = false,
  }) {
    return Column(
      children: [
        Icon(
          icon,
          size: AppTheme.iconSizeAction,
          color:
              isHighlighted
                  ? Theme.of(context).colorScheme.primary
                  : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        AppTheme.tinyGap,
        Text(
          text,
          style: AppTheme.captionStyle.copyWith(
            color:
                isHighlighted
                    ? Theme.of(context).colorScheme.primary
                    : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  Widget _buildSourceUrl(
    BuildContext context,
    RecipeDetailViewModel viewModel,
  ) {
    final sourceUrl = viewModel.recipe.sourceUrl!;
    final isFromArchive =
        sourceUrl == 'Från Butlerys arkiv' ||
        sourceUrl == 'Importerat från Butlery-arkivet';

    return InkWell(
      onTap:
          isFromArchive
              ? null
              : () async {
                final uri = Uri.parse(sourceUrl);
                if (await canLaunchUrl(uri)) {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } else {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Kunde inte öppna länken: $sourceUrl'),
                        backgroundColor: AppTheme.errorColor,
                      ),
                    );
                  }
                }
              },
      borderRadius: AppTheme.mediumRadius,
      child: Container(
        width: double.infinity,
        padding: AppTheme.cardPadding,
        decoration: AppTheme.infoBoxDecoration(context),
        child: Row(
          children: [
            Icon(
              isFromArchive ? Icons.archive : Icons.link,
              size: AppTheme.iconSizeAction,
              color: Theme.of(context).colorScheme.primary,
            ),
            SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Källa',
                    style: AppTheme.captionStyle.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    sourceUrl,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color:
                          isFromArchive
                              ? Theme.of(context).colorScheme.onSurface
                              : Theme.of(context).colorScheme.primary,
                      decoration:
                          isFromArchive ? null : TextDecoration.underline,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
            if (!isFromArchive)
              Icon(
                Icons.open_in_new,
                size: AppTheme.iconSizeInfo,
                color: Theme.of(context).colorScheme.primary,
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildInstructions(
    BuildContext context,
    RecipeDetailViewModel viewModel,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Instruktioner', style: Theme.of(context).textTheme.headlineSmall),
        AppTheme.smallGap,
        ...viewModel.recipe.instructions.asMap().entries.map((entry) {
          final index = entry.key;
          final instruction = entry.value;
          return Container(
            width: double.infinity,
            margin: EdgeInsets.only(bottom: AppTheme.spacingSm),
            padding: AppTheme.cardPadding,
            decoration: BoxDecoration(
              border: Border.all(color: Theme.of(context).colorScheme.outline),
              borderRadius: AppTheme.mediumRadius,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.onPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
                SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    instruction,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }
}

// NY KLASS för fullskärmsvisning av bilder
class _FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const _FullscreenImageViewer({
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<_FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<_FullscreenImageViewer> {
  late PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('${_currentIndex + 1} / ${widget.imageUrls.length}'),
      ),
      body: PageView.builder(
        controller: _pageController,
        onPageChanged: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        itemCount: widget.imageUrls.length,
        itemBuilder: (context, index) {
          return InteractiveViewer(
            minScale: 0.5,
            maxScale: 4.0,
            child: Center(
              child: RecipeImageCarousel(
                imageUrls: [widget.imageUrls[index]],
                height: MediaQuery.of(context).size.height,
              ),
            ),
          );
        },
      ),
    );
  }
}
