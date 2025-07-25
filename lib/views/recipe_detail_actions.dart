// lib/views/recipe_detail_actions.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../viewmodels/recipe_detail_viewmodel.dart';
import '../viewmodels/social_recipe_viewmodel.dart';
import '../widgets/image/universal_image_manager.dart' as img;
import '../widgets/common/universal_share_dialog.dart';
import '../viewmodels/universal_share_dialog_viewmodel.dart';
import '../theme/app_colors.dart';
import '../core/injection.dart';
import '../services/share_service.dart';
import '../services/user_service.dart';
import '../repositories/firebase/firebase_auth_repository.dart';
import '../core/base/base_action_handler.dart';

/// Refactored RecipeDetailActions using BaseActionHandler patterns
/// 
/// This class provides standardized action methods for recipe detail operations
/// with consistent error handling, user feedback, and validation.
class RecipeDetailActions extends BaseActionHandler with ActionStateMixin {
  @override
  String get serviceName => 'RecipeDetailActions';
  
  /// Reference to the share service
  final ShareService _shareService = sl<ShareService>();
  
  /// State for portion scaling
  int _currentPortions = 1;
  List<String> _scaledIngredients = [];
  bool _isScaled = false;
  
  /// State for comments section
  bool _isCommentsExpanded = false;
  
  // Getters for state access
  int get currentPortions => _currentPortions;
  List<String> get scaledIngredients => _scaledIngredients;
  bool get isScaled => _isScaled;
  bool get isCommentsExpanded => _isCommentsExpanded;
  
  /// Initialize the actions with recipe data
  void initializeActions(BuildContext context) {
    final viewModel = context.read<RecipeDetailViewModel>();
    _currentPortions = viewModel.recipe.portions ?? 4;
    _scaledIngredients = List.from(viewModel.recipe.ingredients);
  }
  
  /// Delete recipe action with confirmation dialog using BaseActionHandler
  Future<void> deleteRecipe(BuildContext context) async {
    if (!validateContext(context)) return;

    final viewModel = context.read<RecipeDetailViewModel>();
    final recipeName = viewModel.recipe.title;

    await executeDeleteAction(
      context: context,
      deleteAction: () => viewModel.deleteRecipe(),
      itemName: recipeName,
      itemType: 'recept',
      warningMessage: 'Receptet kommer att tas bort permanent.',
      icon: Icons.restaurant,
      successMessage: 'Receptet "$recipeName" har tagits bort',
      errorMessage: 'Kunde inte ta bort receptet',
      popOnSuccess: true,
      metadata: {
        'recipe_id': viewModel.recipe.id,
        'recipe_name': recipeName,
      },
    );
  }
  
  /// Share recipe action using BaseActionHandler
  Future<void> shareRecipe(BuildContext context) async {
    if (!validateContext(context)) return;

    final viewModel = context.read<RecipeDetailViewModel>();

    await executeAction(
      context: context,
      action: () async {
        // Share with scaled ingredients if user has adjusted portions
        final recipeToShare = _isScaled
            ? viewModel.recipe.copyWith(
                portions: _currentPortions,
                ingredients: _scaledIngredients,
              )
            : viewModel.recipe;

        await _shareService.shareRecipe(recipeToShare);
        return true;
      },
      successMessage: _isScaled
          ? 'Recept delat med $_currentPortions portioner!'
          : 'Recept delat!',
      errorMessage: 'Kunde inte dela recept',
      metadata: {
        'recipe_id': viewModel.recipe.id,
        'is_scaled': _isScaled,
        'portions': _currentPortions,
      },
    );
  }
  
  /// Show social share dialog using BaseActionHandler
  Future<void> showSocialShareDialog(BuildContext context) async {
    if (!validateContext(context)) return;

    final socialViewModel = context.read<SocialRecipeViewModel>();

    await executeAction(
      context: context,
      action: () async {
        await showDialog(
          context: context,
          builder: (context) => UniversalShareDialog.recipe(
            recipe: socialViewModel.recipe,
            viewModel: sl<UniversalShareDialogViewModel>(),
            initialMessage: "Kolla detta recept!",
            availableFriends: socialViewModel.friends,
          ),
        );
        return true;
      },
      successMessage: 'Delningsalternativ visade',
      errorMessage: 'Kunde inte visa delningsalternativ',
      metadata: {
        'recipe_id': socialViewModel.recipe.id,
        'friends_count': socialViewModel.friends.length,
      },
    );
  }
  
  /// Handle portion changes
  void onPortionChanged(BuildContext context, int newPortions, List<String> scaledIngredients) {
    _currentPortions = newPortions;
    _scaledIngredients = scaledIngredients;
    _isScaled = newPortions != (context.read<RecipeDetailViewModel>().recipe.portions ?? 4);
  }
  
  /// Show fullscreen image viewer using BaseActionHandler
  Future<void> showFullscreenImages(
    BuildContext context,
    List<String> imageUrls,
    int initialIndex,
  ) async {
    if (!validateContext(context) || !validateRequired([imageUrls], 'showing fullscreen images')) {
      return;
    }

    if (imageUrls.isEmpty) {
      showErrorMessage(context, 'Inga bilder tillgängliga');
      return;
    }

    await navigateTo(
      context,
      FullscreenImageViewer(
        imageUrls: imageUrls,
        initialIndex: initialIndex,
      ),
    );
  }
  
  /// Toggle comments expansion with feedback
  void toggleCommentsExpansion(BuildContext context) {
    if (!validateContext(context)) return;
    
    _isCommentsExpanded = !_isCommentsExpanded;
    showInfoMessage(
      context,
      _isCommentsExpanded ? 'Kommentarer utvidgade' : 'Kommentarer dolda',
    );
    
    // Load comments when expanding for the first time
    if (_isCommentsExpanded) {
      final socialViewModel = context.read<SocialRecipeViewModel>();
      if (!socialViewModel.hasComments) {
        socialViewModel.refreshComments();
      }
    }
  }
  
  /// Handle comment posting
  Future<void> postComment(BuildContext context, SocialRecipeViewModel socialViewModel) async {
    final success = await socialViewModel.postComment();
    if (!context.mounted) return;
    if (success) {
      showSuccessMessage(context, 'Kommentar publicerad!');
    }
  }
  
  /// Handle creating user profile
  Future<void> createUserProfile(BuildContext context) async {
    final userService = sl<UserService>();
    final authUser = FirebaseAuthRepository().currentUser;
    
    if (authUser != null) {
      final displayName = authUser.displayName ?? authUser.email!.split('@')[0];
      
      final profile = await userService.createOrUpdateProfile(
        displayName: displayName,
        isSearchable: true,
        allowEmailSearch: false,
      );
      
      if (profile != null) {
        if (context.mounted) {
          showSuccessMessage(context, 'Profil skapad! Starta om appen.');
        }
      }
    }
  }
  
  /// Handle "mark as cooked" action
  Future<void> markAsCooked(BuildContext context) async {
    final viewModel = context.read<RecipeDetailViewModel>();
    final success = await viewModel.markAsCooked();
    
    if (success) {
      if (context.mounted) {
        final message = viewModel.recipe.lastCookedText == null
            ? 'Markerad som tillagad för första gången! 🎉'
            : 'Uppdaterad som tillagad idag!';
        showSuccessMessage(context, message);
      }
    }
  }
  
  /// Handle source URL click
  Future<void> handleSourceUrlClick(BuildContext context, String sourceUrl) async {
    final isFromArchive = sourceUrl == 'Från Butlerys arkiv' ||
        sourceUrl == 'Importerat från Butlery-arkivet';
    
    if (isFromArchive) return;
    
    final uri = Uri.parse(sourceUrl);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    } else {
      if (context.mounted) {
        showErrorMessage(context, 'Kunde inte öppna länken: $sourceUrl');
      }
    }
  }
  
  /// Format comment time for display
  String formatCommentTime(DateTime dateTime) {
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

/// Fullscreen image viewer widget
class FullscreenImageViewer extends StatefulWidget {
  final List<String> imageUrls;
  final int initialIndex;

  const FullscreenImageViewer({
    super.key,
    required this.imageUrls,
    required this.initialIndex,
  });

  @override
  State<FullscreenImageViewer> createState() => _FullscreenImageViewerState();
}

class _FullscreenImageViewerState extends State<FullscreenImageViewer> {
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
      backgroundColor: AppColors.backgroundDark,
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
              child: img.UniversalImageManager.carousel(
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