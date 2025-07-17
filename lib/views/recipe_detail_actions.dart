// lib/views/recipe_detail_actions.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../viewmodels/recipe_detail_viewmodel.dart';
import '../viewmodels/social_recipe_viewmodel.dart';
import '../widgets/image/universal_image_manager.dart' as img;
import '../widgets/common/universal_share_dialog.dart';
import '../viewmodels/universal_share_dialog_viewmodel.dart';
import '../theme/app_theme.dart';
import '../core/injection.dart';
import '../services/share_service.dart';
import '../services/user_service.dart';
import '../repositories/firebase/firebase_auth_repository.dart';
import '../core/dialogs/dialog_factory.dart';
import '../core/utils/snackbar_utils.dart';

/// A helper class containing action methods and helper methods for RecipeDetailView
/// This class can be used as a mixin or helper class to provide common functionality
/// for recipe detail view actions.
class RecipeDetailActions {
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
  
  /// Helper method to safely show snackbar messages
  void showSnackBarSafely(BuildContext context, String message, {bool isError = false}) {
    if (context.mounted) {
      if (isError) {
        SnackBarUtils.showError(context, message);
      } else {
        SnackBarUtils.showSuccess(context, message);
      }
    }
  }
  
  /// Helper method to safely pop navigation
  void popSafely(BuildContext context) {
    if (context.mounted) {
      Navigator.pop(context);
    }
  }
  
  /// Initialize the actions with recipe data
  void initializeActions(BuildContext context) {
    final viewModel = context.read<RecipeDetailViewModel>();
    _currentPortions = viewModel.recipe.portions ?? 4;
    _scaledIngredients = List.from(viewModel.recipe.ingredients);
  }
  
  /// Delete recipe action with confirmation dialog
  Future<void> deleteRecipe(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();

    final confirmed = await DialogFactory.showConfirmation(
      context,
      title: 'Ta bort recept',
      message: 'Är du säker på att du vill ta bort "${viewModel.recipe.title}"?',
      isDangerous: true,
    );

    if (!context.mounted || confirmed != true) return;

    final success = await viewModel.deleteRecipe();

    if (!context.mounted) return;

    if (success) {
      showSnackBarSafely(context, 'Recept borttaget');
      popSafely(context);
    } else {
      showSnackBarSafely(
        context,
        viewModel.error ?? 'Kunde inte ta bort recept',
        isError: true,
      );
    }
  }
  
  /// Share recipe action
  Future<void> shareRecipe(BuildContext context) async {
    if (!context.mounted) return;

    final viewModel = context.read<RecipeDetailViewModel>();

    // Share with scaled ingredients if user has adjusted portions
    final recipeToShare = _isScaled
        ? viewModel.recipe.copyWith(
            portions: _currentPortions,
            ingredients: _scaledIngredients,
          )
        : viewModel.recipe;

    await _shareService.shareRecipe(recipeToShare);
    if (!context.mounted) return;

    final message = _isScaled
        ? 'Recept delat med $_currentPortions portioner!'
        : 'Recept delat!';

    showSnackBarSafely(context, message);
  }
  
  /// Show social share dialog
  Future<void> showSocialShareDialog(BuildContext context) async {
    if (!context.mounted) return;

    final socialViewModel = context.read<SocialRecipeViewModel>();

    await showDialog(
      context: context,
      builder: (context) => UniversalShareDialog.recipe(
        recipe: socialViewModel.recipe,
        viewModel: sl<UniversalShareDialogViewModel>(),
        initialMessage: "Kolla detta recept!",
        availableFriends: socialViewModel.friends,
      ),
    );
    if (!context.mounted) return;
  }
  
  /// Handle portion changes
  void onPortionChanged(BuildContext context, int newPortions, List<String> scaledIngredients) {
    _currentPortions = newPortions;
    _scaledIngredients = scaledIngredients;
    _isScaled = newPortions != (context.read<RecipeDetailViewModel>().recipe.portions ?? 4);
  }
  
  /// Show fullscreen image viewer
  Future<void> showFullscreenImages(
    BuildContext context,
    List<String> imageUrls,
    int initialIndex,
  ) async {
    if (!context.mounted) return;

    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => FullscreenImageViewer(
          imageUrls: imageUrls,
          initialIndex: initialIndex,
        ),
      ),
    );
    if (!context.mounted) return;
  }
  
  /// Toggle comments expansion
  void toggleCommentsExpansion(BuildContext context) {
    _isCommentsExpanded = !_isCommentsExpanded;
    
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
      showSnackBarSafely(context, 'Kommentar publicerad!');
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
          showSnackBarSafely(context, 'Profil skapad! Starta om appen.');
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
        showSnackBarSafely(context, message);
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
        showSnackBarSafely(
          context,
          'Kunde inte öppna länken: $sourceUrl',
          isError: true,
        );
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
      backgroundColor: AppTheme.dark,
      appBar: AppBar(
        backgroundColor: AppTheme.transparent,
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