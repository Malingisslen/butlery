// lib/views/edit_recipe_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/auth_service.dart';
import '../models/recipe_unified.dart';
import '../viewmodels/recipe_form_viewmodel.dart';
import '../viewmodels/collaborative_status_viewmodel.dart';
import '../widgets/common/state_widget.dart';
import '../theme/app_colors.dart';
import '../theme/app_dimensions.dart';
import '../core/injection.dart';
import 'edit_recipe/edit_recipe_actions.dart';
import 'edit_recipe/edit_recipe_app_bar.dart';
import 'edit_recipe/edit_recipe_banners.dart';
import 'edit_recipe/edit_recipe_bottom_bar.dart';
import 'edit_recipe/edit_recipe_form_fields.dart';

/// Edit Recipe View - Facade using focused view components
/// 
/// This view has been refactored to use the focused components pattern:
/// - edit_recipe_actions.dart - Save and fork functionality
/// - edit_recipe_app_bar.dart - AppBar with collaborative status
/// - edit_recipe_banners.dart - Smart banners for status display
/// - edit_recipe_bottom_bar.dart - Permissions-based action buttons
/// - edit_recipe_form_fields.dart - All form fields and inputs
/// - edit_recipe_image_picker.dart - Image picker modal
/// - edit_recipe_dynamic_list.dart - Dynamic list builder
class EditRecipeView extends StatelessWidget {
  final Recipe recipe;

  const EditRecipeView({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        // AuthService
        ChangeNotifierProvider<AuthService>.value(value: sl<AuthService>()),

        // RecipeFormViewModel
        ChangeNotifierProvider<RecipeFormViewModel>(
          create: (_) => RecipeFormViewModel(
            recipeService: sl(),
            analyticsService: sl(),
            initialRecipe: recipe,
          ),
        ),

        // CollaborativeStatusViewModel
        ChangeNotifierProvider<CollaborativeStatusViewModel>(
          create: (_) => sl<CollaborativeStatusViewModel>(),
        ),
      ],
      child: _EditRecipeViewContent(recipe: recipe),
    );
  }
}

class _EditRecipeViewContent extends StatefulWidget {
  final Recipe recipe;

  const _EditRecipeViewContent({required this.recipe});

  @override
  State<_EditRecipeViewContent> createState() => _EditRecipeViewContentState();
}

class _EditRecipeViewContentState extends State<_EditRecipeViewContent> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeFormViewModel>();

    return Scaffold(
      // AppBar with collaborative status
      appBar: EditRecipeAppBar.build(context, widget.recipe),

      // Permissions-based bottom navigation bar
      bottomNavigationBar: EditRecipeBottomBar.build(
        context,
        () => EditRecipeActions.saveRecipe(context, _formKey, widget.recipe.id),
        () => EditRecipeActions.forkRecipe(context, _formKey),
      ),

      body: Stack(
        children: [
          // Main content with banners and form
          Column(
            children: [
              // Smart banners (collaborative + permissions)
              EditRecipeBanners.buildSmartBanners(context, widget.recipe),
              
              // Form content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.all(AppDimensions.paddingL),
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: EditRecipeFormFields.buildFormFields(context, viewModel),
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay
          if (viewModel.isSaving)
            Container(
              color: AppColors.backgroundBeige.withValues(alpha: 0.8),
              child: Center(
                child: StateWidget.loading(
                  message: 'Uppdaterar recept...',
                ),
              ),
            ),
        ],
      ),
    );
  }
}
