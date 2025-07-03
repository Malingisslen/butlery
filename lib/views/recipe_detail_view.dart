// lib/views/recipe_detail_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/recipe.dart';
import '../viewmodels/recipe_detail_viewmodel.dart';
import '../viewmodels/social_recipe_viewmodel.dart';
import '../widgets/main_layout_menu.dart';
import '../widgets/portion_scaler.dart';
import '../widgets/recipe_image_carousel.dart';
import '../widgets/user_avatar.dart';
import '../widgets/universal_share_dialog.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';
import '../services/share_service.dart';
import '../services/user_service.dart';

class RecipeDetailView extends StatelessWidget {
  final Recipe recipe;

  const RecipeDetailView({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => sl<RecipeDetailViewModel>(param1: recipe),
        ),
        ChangeNotifierProvider(
          create: (_) => sl<SocialRecipeViewModel>(param1: recipe),
        ),
      ],
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

  // State för kommentarssektion
  bool _isCommentsExpanded = false;

  // ✅ HELPER-METODER FÖR SÄKER CONTEXT ANVÄNDNING
  void _showSnackBarSafely(String message, {Color? backgroundColor}) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: backgroundColor ?? AppTheme.successColor,
        ),
      );
    }
  }

  void _popSafely() {
    if (mounted) {
      Navigator.pop(context);
    }
  }

  @override
  void initState() {
    super.initState();
    // Initiera med originalvärden
    final viewModel = context.read<RecipeDetailViewModel>();
    _currentPortions = viewModel.recipe.portions ?? 4;
    _scaledIngredients = List.from(viewModel.recipe.ingredients);
  }

  // ✅ SÄKER: _deleteRecipe med helper-metoder
  Future<void> _deleteRecipe(BuildContext context) async {
    if (!mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
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

    if (!mounted || confirmed != true) return;

    final success = await viewModel.deleteRecipe();

    if (!mounted) return;

    if (success) {
      _showSnackBarSafely('Recept borttaget');
      _popSafely();
    } else {
      _showSnackBarSafely(
        viewModel.error ?? 'Kunde inte ta bort recept',
        backgroundColor: AppTheme.errorColor,
      );
    }
  }

  // ✅ SÄKER: _shareRecipe med helper-metod
  Future<void> _shareRecipe(BuildContext context) async {
    if (!mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();

    // Dela med skalade ingredienser om användaren har justerat portioner
    final recipeToShare = _isScaled
        ? viewModel.recipe.copyWith(
            portions: _currentPortions,
            ingredients: _scaledIngredients,
          )
        : viewModel.recipe;

    await _shareService.shareRecipe(recipeToShare);

    final message = _isScaled
        ? 'Recept delat med $_currentPortions portioner!'
        : 'Recept delat!';

    _showSnackBarSafely(message);
  }

  Future<void> _showSocialShareDialog(BuildContext context) async {
    if (!mounted) return;

    final socialViewModel = context.read<SocialRecipeViewModel>();

    await showDialog(
      context: context,
      builder: (context) => UniversalShareDialog.recipe(
        recipe:
            socialViewModel.recipe, // ✅ KORREKT: använd getter från ViewModel
        initialMessage: "Kolla detta recept!",
        availableFriends: socialViewModel.friends,
      ),
    );
  }

  void _onPortionChanged(int newPortions, List<String> scaledIngredients) {
    setState(() {
      _currentPortions = newPortions;
      _scaledIngredients = scaledIngredients;
      _isScaled = newPortions !=
          (context.read<RecipeDetailViewModel>().recipe.portions ?? 4);
    });
  }

  // ✅ SÄKER: _showFullscreenImages
  Future<void> _showFullscreenImages(
    BuildContext context,
    List<String> imageUrls,
    int initialIndex,
  ) async {
    if (!mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => _FullscreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeDetailViewModel>();
    final socialViewModel = context.watch<SocialRecipeViewModel>();

    return MainLayoutMenu(
      currentIndex: null,
      body: Scaffold(
        appBar: AppBar(
          title: Text(viewModel.recipe.title),
          actions: [
            // ✨ UPPDATERAD: Enhanced social share ikon
            IconButton(
              icon: AppTheme.actionIcon(context, Icons.people_outline),
              onPressed: () => _showSocialShareDialog(context),
              tooltip: socialViewModel.friends.isEmpty
                  ? 'Lägg till vänner för att dela'
                  : 'Dela med vänner',
            ),
            // Befintlig regular share
            IconButton(
              icon: AppTheme.actionIcon(context, Icons.share),
              onPressed: () => _shareRecipe(context),
              tooltip: _isScaled
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
                  // Bildkarusell
                  if (viewModel.hasImages)
                    RecipeImageCarousel(
                      imageUrls: viewModel.recipe.imageUrls,
                      height: AppTheme.imageHeightMedium,
                      onTap: () => _showFullscreenImages(
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
                            color: Theme.of(context)
                                .colorScheme
                                .onPrimaryContainer,
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

                  // Source URL
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
                      children: viewModel.recipe.tags!
                          .map((tag) => AppTheme.tagChip(tag))
                          .toList(),
                    ),
                    AppTheme.largeGap,
                  ],

                  // Portionsskalning
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
                  AppTheme.largeGap,

                  // ✨ UPPDATERAD: Social kommentarssektion
                  _buildCommentsSection(context, socialViewModel),
                  AppTheme.largeGap,

                  // ✅ SÄKER: Redigera-knapp
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton.icon(
                      icon: AppTheme.actionIcon(context, Icons.edit),
                      label: const Text('Redigera recept'),
                      style: AppTheme.primaryButtonStyle,
                      onPressed: () async {
                        if (!mounted) return;
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

          // ✅ SÄKER: "Tillagad idag"-knapp med helper-metod
          AppTheme.mediumGap,
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () async {
                final success = await viewModel.markAsCooked();
                if (success) {
                  final message = viewModel.recipe.lastCookedText == null
                      ? 'Markerad som tillagad för första gången! 🎉'
                      : 'Uppdaterad som tillagad idag!';
                  _showSnackBarSafely(message);
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
                foregroundColor: viewModel.recipe.wasCookedRecently
                    ? AppTheme.successColor
                    : Theme.of(context).colorScheme.primary,
                side: BorderSide(
                  color: viewModel.recipe.wasCookedRecently
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
          color: isHighlighted
              ? Theme.of(context).colorScheme.primary
              : Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        AppTheme.tinyGap,
        Text(
          text,
          style: AppTheme.captionStyle.copyWith(
            color: isHighlighted
                ? Theme.of(context).colorScheme.primary
                : Theme.of(context).colorScheme.onSurfaceVariant,
            fontWeight: isHighlighted ? FontWeight.w600 : FontWeight.normal,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ✅ SÄKER: _buildSourceUrl med helper-metod
  Widget _buildSourceUrl(
    BuildContext context,
    RecipeDetailViewModel viewModel,
  ) {
    final sourceUrl = viewModel.recipe.sourceUrl!;
    final isFromArchive = sourceUrl == 'Från Butlerys arkiv' ||
        sourceUrl == 'Importerat från Butlery-arkivet';

    return InkWell(
      onTap: isFromArchive
          ? null
          : () async {
              final uri = Uri.parse(sourceUrl);
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri, mode: LaunchMode.externalApplication);
              } else {
                _showSnackBarSafely(
                  'Kunde inte öppna länken: $sourceUrl',
                  backgroundColor: AppTheme.errorColor,
                );
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
                          color: isFromArchive
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

  // ✨ FÖRBÄTTRAD KOMMENTARSSEKTION
  Widget _buildCommentsSection(
      BuildContext context, SocialRecipeViewModel socialViewModel) {
    return Container(
      width: double.infinity,
      decoration: AppTheme.infoBoxDecoration(context),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header med expand/collapse
          InkWell(
            onTap: () {
              setState(() {
                _isCommentsExpanded = !_isCommentsExpanded;
              });

              // Ladda kommentarer när man expanderar första gången
              if (_isCommentsExpanded && !socialViewModel.hasComments) {
                socialViewModel.refreshComments();
              }
            },
            child: Padding(
              padding: AppTheme.cardPadding,
              child: Row(
                children: [
                  Icon(
                    Icons.comment_outlined,
                    size: AppTheme.iconSizeAction,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  SizedBox(width: AppTheme.spacingSm),
                  Expanded(
                    child: Text(
                      socialViewModel.hasComments
                          ? 'Kommentarer (${socialViewModel.comments.length})'
                          : 'Kommentarer',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                            color: Theme.of(context).colorScheme.primary,
                          ),
                    ),
                  ),
                  if (socialViewModel.friends.isNotEmpty)
                    Icon(
                      _isCommentsExpanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                ],
              ),
            ),
          ),

          // Expandable kommentarinnehåll
          if (_isCommentsExpanded) ...[
            Divider(height: 1, color: Theme.of(context).colorScheme.outline),
            Padding(
              padding: AppTheme.cardPadding,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Kommentarer lista
                  if (socialViewModel.isLoadingComments)
                    Center(
                      child: Padding(
                        padding: EdgeInsets.all(AppTheme.spacingMd),
                        child: Column(
                          children: [
                            AppTheme.smallLoadingIndicator(),
                            AppTheme.smallGap,
                            Text(
                              'Laddar kommentarer...',
                              style: AppTheme.captionStyle,
                            ),
                          ],
                        ),
                      ),
                    )
                  else if (socialViewModel.commentsError != null)
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingMd),
                      decoration: BoxDecoration(
                        color: AppTheme.errorColor.withValues(alpha: 0.1),
                        borderRadius: AppTheme.smallRadius,
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.error_outline, color: AppTheme.errorColor),
                          SizedBox(width: AppTheme.spacingSm),
                          Expanded(
                            child: Text(
                              socialViewModel.commentsError!,
                              style: TextStyle(color: AppTheme.errorColor),
                            ),
                          ),
                        ],
                      ),
                    )
                  else if (!socialViewModel.hasComments)
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingMd * 2),
                      child: Column(
                        children: [
                          Icon(
                            Icons.chat_bubble_outline,
                            size: 48,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          AppTheme.mediumGap,
                          Text(
                            'Inga kommentarer än',
                            style: Theme.of(context).textTheme.titleMedium,
                            textAlign: TextAlign.center,
                          ),
                          AppTheme.smallGap,
                          Text(
                            'Bli först att kommentera detta recept!',
                            style: AppTheme.captionStyle,
                            textAlign: TextAlign.center,
                          ),
                        ],
                      ),
                    )
                  else
                    ...socialViewModel.topLevelComments.map((comment) =>
                        _buildCommentItem(context, socialViewModel, comment)),

                  AppTheme.mediumGap,

                  // DEBUG INFO + SKAPA PROFIL
                  Builder(
                    builder: (context) {
                      final userService = sl<UserService>();
                      final authUser = FirebaseAuth.instance.currentUser;

                      return Container(
                        padding: EdgeInsets.all(AppTheme.spacingSm),
                        color: Colors.yellow[100],
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text('🔍 DEBUG INFO:',
                                style: TextStyle(fontWeight: FontWeight.bold)),
                            Text(
                                'SocialViewModel.currentUser: ${socialViewModel.currentUser?.displayName ?? "NULL"}'),
                            Text(
                                'UserService.currentUserProfile: ${userService.currentUserProfile?.displayName ?? "NULL"}'),
                            Text(
                                'FirebaseAuth.currentUser: ${authUser?.email ?? "NULL"}'),
                            Text(
                                'UserService loading: ${userService.isLoading}'),
                            Text(
                                'UserService error: ${userService.error ?? "none"}'),

                            AppTheme.smallGap,

                            // ✅ SÄKER: SNABBFIX: Skapa profil-knapp med helper-metod
                            if (authUser != null &&
                                userService.currentUserProfile == null)
                              ElevatedButton(
                                onPressed: () async {
                                  final displayName = authUser.displayName ??
                                      authUser.email!.split('@')[0];

                                  final profile =
                                      await userService.createOrUpdateProfile(
                                    displayName: displayName,
                                    isSearchable: true,
                                    allowEmailSearch: false,
                                  );

                                  if (profile != null) {
                                    _showSnackBarSafely(
                                        'Profil skapad! Starta om appen.');
                                  }
                                },
                                child: Text('Skapa Profil'),
                              ),
                          ],
                        ),
                      );
                    },
                  ),
                  AppTheme.smallGap,

                  // Kommentarsformulär (för alla inloggade användare)
                  // DEBUG: Visa alltid för inloggade användare
                  if (socialViewModel.currentUser != null)
                    _buildCommentForm(context, socialViewModel)
                  else
                    Container(
                      padding: EdgeInsets.all(AppTheme.spacingMd),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.surfaceContainer,
                        borderRadius: AppTheme.mediumRadius,
                      ),
                      child: Column(
                        children: [
                          Icon(
                            Icons.person_add_outlined,
                            size: 32,
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                          AppTheme.smallGap,
                          Text(
                            'Skapa profil för att kommentera',
                            style: Theme.of(context).textTheme.titleSmall,
                            textAlign: TextAlign.center,
                          ),
                          AppTheme.smallGap,
                          FilledButton.icon(
                            onPressed: () =>
                                Navigator.pushNamed(context, '/profile/edit'),
                            icon: const Icon(Icons.person_add),
                            label: const Text('Skapa profil'),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ✅ SÄKER: Kommentarsformulär med helper-metod
  Widget _buildCommentForm(
      BuildContext context, SocialRecipeViewModel socialViewModel) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (socialViewModel.isReplying) ...[
          Container(
            padding: EdgeInsets.all(AppTheme.spacingSm),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.surfaceContainer,
              borderRadius: AppTheme.mediumRadius,
            ),
            child: Row(
              children: [
                Icon(
                  Icons.reply,
                  size: AppTheme.iconSizeInfo,
                  color: Theme.of(context).colorScheme.primary,
                ),
                SizedBox(width: AppTheme.spacingSm),
                Expanded(
                  child: Text(
                    'Svarar på kommentar',
                    style: AppTheme.captionStyle.copyWith(
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ),
                IconButton(
                  onPressed: socialViewModel.cancelReply,
                  icon: Icon(
                    Icons.close,
                    size: AppTheme.iconSizeInfo,
                  ),
                  constraints: const BoxConstraints(),
                  padding: EdgeInsets.zero,
                ),
              ],
            ),
          ),
          AppTheme.smallGap,
        ],
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            UserAvatar.social(
              displayName: socialViewModel.currentUser?.displayName ?? 'Du',
              imageUrl: socialViewModel.currentUser?.avatarUrl,
              size: 48,
            ),
            SizedBox(width: AppTheme.spacingSm),
            Expanded(
              child: TextField(
                onChanged: socialViewModel.updateNewCommentText,
                decoration: InputDecoration(
                  hintText: socialViewModel.isReplying
                      ? 'Skriv ditt svar...'
                      : 'Skriv en kommentar...',
                  border: OutlineInputBorder(
                    borderRadius: AppTheme.mediumRadius,
                  ),
                  contentPadding: EdgeInsets.all(AppTheme.spacingSm),
                ),
                maxLines: 3,
                minLines: 1,
              ),
            ),
            SizedBox(width: AppTheme.spacingSm),
            IconButton(
              onPressed: socialViewModel.newCommentText.trim().isNotEmpty &&
                      !socialViewModel.isPostingComment
                  ? () async {
                      final success = await socialViewModel.postComment();
                      if (success) {
                        _showSnackBarSafely('Kommentar publicerad!');
                      }
                    }
                  : null,
              icon: socialViewModel.isPostingComment
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: AppTheme.smallLoadingIndicator(),
                    )
                  : Icon(Icons.send),
              style: IconButton.styleFrom(
                backgroundColor:
                    socialViewModel.newCommentText.trim().isNotEmpty
                        ? Theme.of(context).colorScheme.primary
                        : null,
                foregroundColor:
                    socialViewModel.newCommentText.trim().isNotEmpty
                        ? Theme.of(context).colorScheme.onPrimary
                        : null,
              ),
            ),
          ],
        ),
      ],
    );
  }

  // Kommentarsitem (samma som innan)
  Widget _buildCommentItem(
    BuildContext context,
    SocialRecipeViewModel socialViewModel,
    dynamic comment,
  ) {
    return Container(
      margin: EdgeInsets.only(bottom: AppTheme.spacingSm),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              UserAvatar.small(
                displayName: socialViewModel.getAuthorDisplayName(comment),
                imageUrl: socialViewModel.getAuthorAvatarUrl(comment),
              ),
              SizedBox(width: AppTheme.spacingSm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          socialViewModel.getAuthorDisplayName(comment),
                          style:
                              Theme.of(context).textTheme.labelMedium?.copyWith(
                                    fontWeight: FontWeight.w600,
                                  ),
                        ),
                        SizedBox(width: AppTheme.spacingSm),
                        Text(
                          _formatCommentTime(comment.createdAt),
                          style: AppTheme.captionStyle,
                        ),
                      ],
                    ),
                    AppTheme.tinyGap,
                    Text(
                      comment.text,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    AppTheme.tinyGap,
                    Row(
                      children: [
                        // Gilla-knapp
                        InkWell(
                          onTap: () =>
                              socialViewModel.toggleCommentLike(comment.id),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacingXs,
                              horizontal: AppTheme.spacingSm,
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  socialViewModel.hasLikedComment(comment)
                                      ? Icons.favorite
                                      : Icons.favorite_border,
                                  size: AppTheme.iconSizeInfo,
                                  color:
                                      socialViewModel.hasLikedComment(comment)
                                          ? AppTheme.errorColor
                                          : Theme.of(context)
                                              .colorScheme
                                              .onSurfaceVariant,
                                ),
                                if (comment.likeCount > 0) ...[
                                  SizedBox(width: AppTheme.spacingXs),
                                  Text(
                                    '${comment.likeCount}',
                                    style: AppTheme.captionStyle,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        // Svara-knapp
                        InkWell(
                          onTap: () => socialViewModel.setReplyTo(comment.id),
                          child: Padding(
                            padding: EdgeInsets.symmetric(
                              vertical: AppTheme.spacingXs,
                              horizontal: AppTheme.spacingSm,
                            ),
                            child: Text(
                              'Svara',
                              style: AppTheme.captionStyle.copyWith(
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),

          // Svar på kommentaren
          ...socialViewModel.getReplies(comment.id).map((reply) => Padding(
                padding: EdgeInsets.only(left: AppTheme.spacingLg),
                child: _buildCommentItem(context, socialViewModel, reply),
              )),
        ],
      ),
    );
  }

  String _formatCommentTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}

// BEFINTLIG KLASS: Fullskärmsvisning av bilder (samma som innan)
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
