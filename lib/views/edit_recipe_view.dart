/// Comprehensive recipe editing view with all components inlined for maintainability.
/// This view provides complete recipe editing interface following MVVM architecture,
/// specializing in recipe editing, collaborative features, and comprehensive form management.
/// **Single Responsibility Focus:**
/// - Recipe Editing Interface Excellence with form validation
/// - Collaborative Status Integration with permission management
/// - Multi-Provider Coordination with service integration
/// - Loading Overlay Management with user feedback
/// **Components Inlined** (all previously separate files):
/// - edit_recipe_actions.dart: Save and fork functionality
/// - edit_recipe_app_bar.dart: AppBar with collaborative status
/// - edit_recipe_banners.dart: Smart banners for status display
/// - edit_recipe_bottom_bar.dart: Permissions-based action buttons
/// - edit_recipe_form_fields.dart: All form fields and inputs
/// - edit_recipe_image_picker.dart: Image picker modal
/// - edit_recipe_dynamic_list.dart: Dynamic list builder
/// **Multi-Provider Architecture:**
/// - AuthService for user authentication and permission management
/// - RecipeFormViewModel for recipe editing state and form coordination
/// - CollaborativeStatusViewModel for collaborative editing awareness

// lib/views/edit_recipe_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/social_components.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/widgets/image/universal_image_manager.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/widgets/recipe/recipe_image_picker.dart';
import 'package:butlery/widgets/recipe/recipe_form/dynamic_list_builder.dart';

/// Comprehensive recipe editing view with all components inlined.
class EditRecipeView extends StatelessWidget {
  final Recipe recipe;

  const EditRecipeView({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(
            value: ServiceLocator.get<AuthService>()),
        ChangeNotifierProvider<RecipeFormViewModel>(
          create: (_) => RecipeFormViewModel(
            recipeService: ServiceLocator.get(),
            initialRecipe: recipe,
          ),
        ),
        ChangeNotifierProvider<CollaborativeStatusViewModel>(
          create: (_) => ServiceLocator.get<CollaborativeStatusViewModel>(),
        ),
      ],
      child: _EditRecipeViewContent(recipe: recipe),
    );
  }
}

/// Recipe editing view content managing form state and component lifecycle.
class _EditRecipeViewContent extends StatefulWidget {
  final Recipe recipe;

  const _EditRecipeViewContent({required this.recipe});

  @override
  State<_EditRecipeViewContent> createState() => _EditRecipeViewContentState();
}

/// Recipe editing view content state with all inlined components.
class _EditRecipeViewContentState extends State<_EditRecipeViewContent> {
  final _formKey = GlobalKey<FormState>();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeFormViewModel>();

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop) {
          if (viewModel.hasUnsavedChanges) {
            final shouldPop = await _showUnsavedChangesDialog(context) ?? false;
            if (shouldPop && context.mounted) {
              Navigator.of(context).pop();
            }
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: _buildAppBar(context, widget.recipe),
        bottomNavigationBar: _buildBottomBar(context, viewModel),
        body: Stack(
          children: [
            // ✅ RESPONSIVE: Center and constrain content on large screens
            Center(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: LayoutComponents.valueFor(
                    context: context,
                    mobile: double.infinity,
                    tablet: 800,
                    desktop: 900,
                  ),
                ),
                child: Column(
                  children: [
                    _buildSmartBanners(context, widget.recipe),
                    Expanded(
                      child: Padding(
                        padding:
                            AppDimensions.responsiveContentPadding(context),
                        child: Form(
                          key: _formKey,
                          child: ListView(
                            children: _buildFormFields(context, viewModel),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // ✅ RESPONSIVE: Loading overlay also constrained
            if (viewModel.isSaving)
              ColoredBox(
                color: AppColors.backgroundBeige.withValues(alpha: 0.8),
                child: Center(
                  child: ConstrainedBox(
                    constraints: BoxConstraints(
                      maxWidth: LayoutComponents.valueFor(
                        context: context,
                        mobile: double.infinity,
                        tablet: 500,
                        desktop: 600,
                      ),
                    ),
                    child: StateWidget.loading(
                      message: 'Uppdaterar recept...',
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  PreferredSizeWidget _buildAppBar(BuildContext context, Recipe recipe) {
    return PreferredSize(
      preferredSize: const Size.fromHeight(kToolbarHeight),
      child: Consumer<CollaborativeStatusViewModel>(
        builder: (context, collaborativeViewModel, child) {
          final status = collaborativeViewModel.getRecipeCollaborativeStatus(
            recipe.id,
            recipe,
          );
          final isCollaborative = status.isCollaborative;

          return AppBar(
            title: const Text('Redigera recept'),
            backgroundColor: isCollaborative
                ? AppColors.primaryBlue.withValues(alpha: 0.1)
                : null,
            actions: [
              if (isCollaborative)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                      end: AppDimensions.spacingL),
                  child: Center(
                    child:
                        SocialCollaborativeComponents.collaborativeStatusBadge(
                      text: 'Delat',
                      icon: Icons.people,
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSmartBanners(BuildContext context, Recipe recipe) {
    return Consumer2<CollaborativeStatusViewModel, RecipeFormViewModel>(
      builder: (context, collaborativeViewModel, recipeViewModel, child) {
        return Column(
          children: [
            _buildCollaborativeBanner(context, recipe),
            SocialCollaborativeComponents.smartPermissionsBanner(
              context: context,
              viewModel: recipeViewModel,
            ),
          ],
        );
      },
    );
  }

  Widget _buildCollaborativeBanner(BuildContext context, Recipe recipe) {
    return Consumer<CollaborativeStatusViewModel>(
      builder: (context, collaborativeViewModel, child) {
        final status = collaborativeViewModel.getRecipeCollaborativeStatus(
          recipe.id,
          recipe,
        );

        if (!status.isCollaborative) return const SizedBox.shrink();

        return SocialCollaborativeComponents.collaborativeBanner(
          title: 'Du redigerar tillsammans med andra',
          subtitle: 'Angringar synkas automatiskt med andra deltagare',
          context: context,
          contentId: recipe.id,
          contentType: 'recipe',
        );
      },
    );
  }

  Widget _buildBottomBar(BuildContext context, RecipeFormViewModel viewModel) {
    if (viewModel.editMode == null) {
      return BottomActionContainer(
        child: UtilityComponents.primaryButton(
          context,
          label: 'Spara ändringar',
          icon: Icons.save,
          onPressed: viewModel.isSaving || !viewModel.isValid
              ? null
              : () => _saveRecipe(context),
          isLoading: viewModel.isSaving,
          loadingText: 'Sparar...',
          isExpanded: true,
        ),
      );
    }

    return BottomActionContainer(
      child: UtilityComponents.permissionsActionButtons(
        context: context,
        editMode: viewModel.editModeEnum ?? EditMode.noAccess,
        onSave: viewModel.isSaving || !viewModel.isValid
            ? null
            : () => _saveRecipe(context),
        onFork: viewModel.isForking || !viewModel.isValid
            ? null
            : () => _forkRecipe(context),
        isSaving: viewModel.isSaving,
        isForking: viewModel.isForking,
        isExpanded: true,
      ),
    );
  }

  List<Widget> _buildFormFields(
      BuildContext context, RecipeFormViewModel viewModel) {
    return [
      // Meal type dropdown
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Måltidstyp',
            style: AppTextStyles.bodySmall.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppDimensions.spacingXs),
          DropdownButtonFormField<String>(
            initialValue: viewModel.mealType,
            isExpanded: true,
            decoration: const InputDecoration(
              contentPadding: EdgeInsets.symmetric(
                horizontal: AppDimensions.paddingL,
                vertical: AppDimensions.paddingM,
              ),
              border: OutlineInputBorder(),
            ),
            style: AppTextStyles.bodyMedium,
            items: RecipeFormViewModel.mealTypes
                .map((mt) => DropdownMenuItem(value: mt, child: Text(mt)))
                .toList(),
            onChanged: (value) {
              if (value != null) viewModel.setMealType(value);
            },
          ),
        ],
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Image management
      UniversalImageManager.recipeEdit(
        imageUrls: viewModel.imageUrls,
        onRemoveImage: viewModel.removeImageAt,
        onSetPrimary: (index) {
          if (index < viewModel.imageUrls.length) {
            final imageUrl = viewModel.imageUrls[index];
            viewModel.setPrimaryImage(imageUrl);
          }
        },
        userId: ServiceLocator.get<PermissionService>().currentUserId ?? '',
        onPickImage: () => RecipeImagePicker.showAndPick(
          context: context,
          viewModel: viewModel,
        ),
        maxImages: 5,
        isLoading: viewModel.isUploadingImage,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Title field
      TextFormField(
        initialValue: viewModel.title,
        decoration: const InputDecoration(labelText: 'Titel'),
        style: AppTextStyles.bodyMedium,
        textInputAction: TextInputAction.next,
        onChanged: viewModel.setTitle,
        validator: FormValidators.combine([
          FormValidators.required('Titel'),
          FormValidators.maxLength(100, 'Titel'),
        ]),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Description field
      TextFormField(
        initialValue: viewModel.description,
        maxLines: 2,
        decoration: const InputDecoration(labelText: 'Beskrivning'),
        style: AppTextStyles.bodyMedium,
        textInputAction: TextInputAction.next,
        onChanged: viewModel.setDescription,
        validator: FormValidators.maxLength(500, 'Beskrivning'),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Portions field
      TextFormField(
        initialValue: viewModel.portions?.toString() ?? '',
        decoration: const InputDecoration(labelText: 'Portioner'),
        style: AppTextStyles.bodyMedium,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        onChanged: (value) => viewModel.setPortions(int.tryParse(value)),
        validator: FormValidators.portions(),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Time field
      TextFormField(
        initialValue: viewModel.timeMinutes?.toString() ?? '',
        decoration: const InputDecoration(labelText: 'Tid (min)'),
        style: AppTextStyles.bodyMedium,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        onChanged: (value) => viewModel.setTimeMinutes(int.tryParse(value)),
        validator: FormValidators.cookingTime(),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Ingredients dynamic list
      DynamicListBuilder(
        label: 'Ingrediens',
        controllers: viewModel.ingredientControllers,
        onUpdate: viewModel.updateIngredient,
        onAdd: viewModel.addIngredient,
        onRemove: viewModel.removeIngredient,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Instructions dynamic list
      DynamicListBuilder(
        label: 'Instruktion',
        controllers: viewModel.instructionControllers,
        onUpdate: viewModel.updateInstruction,
        onAdd: viewModel.addInstruction,
        onRemove: viewModel.removeInstruction,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Tags dynamic list
      DynamicListBuilder(
        label: 'Tagg',
        controllers: viewModel.tagControllers,
        onUpdate: viewModel.updateTag,
        onAdd: viewModel.addTag,
        onRemove: viewModel.removeTag,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Rating field
      TextFormField(
        initialValue: viewModel.rating?.toString() ?? '',
        decoration: const InputDecoration(labelText: 'Betyg (0–5)'),
        style: AppTextStyles.bodyMedium,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        onChanged: (value) => viewModel.setRating(double.tryParse(value)),
        validator: FormValidators.rating(),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Source URL field
      TextFormField(
        initialValue: viewModel.sourceUrl ?? '',
        decoration: InputDecoration(
          labelText: 'Källa (URL)',
          hintText: 'Valfritt: länk till originalreceptet',
          helperText: viewModel.sourceUrl == 'Delad från annan app'
              ? 'Importerat från delning'
              : 'Länk till originalreceptet',
          prefixIcon: const Icon(
            Icons.link,
            size: AppDimensions.iconSizeAction,
          ),
        ),
        style: AppTextStyles.bodyMedium,
        keyboardType: TextInputType.url,
        onChanged: viewModel.setSourceUrl,
        validator: FormValidators.recipeSourceUrl(),
      ),
    ];
  }

  Future<void> _saveRecipe(BuildContext context) async {
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      AppLogger.warning('Form validation failed for recipe save');
      return;
    }

    AppLogger.info('Form validation passed, proceeding with recipe save');
    final viewModel = context.read<RecipeFormViewModel>();
    final savedRecipe = await viewModel.saveRecipe();

    if (context.mounted) {
      if (savedRecipe != null) {
        final collaborativeViewModel =
            context.read<CollaborativeStatusViewModel>();
        collaborativeViewModel.invalidateRecipeStatus(widget.recipe.id);

        UtilityComponents.showSuccessSnackbar(context, 'Ändringar sparade!');
        Navigator.pop(context, true);
      } else {
        UtilityComponents.showErrorSnackbar(
            context, viewModel.error ?? 'Kunde inte spara ändringar');
      }
    }
  }

  /// Fork recipe functionality for collaborative editing (inlined from edit_recipe_actions.dart)
  Future<void> _forkRecipe(BuildContext context) async {
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) {
      AppLogger.warning('Form validation failed for recipe fork');
      return;
    }

    AppLogger.info('Form validation passed, proceeding with recipe fork');
    final viewModel = context.read<RecipeFormViewModel>();
    final forkedRecipe = await viewModel.saveFork();

    if (context.mounted) {
      if (forkedRecipe != null) {
        UtilityComponents.showSuccessSnackbar(
          context,
          'Din kopia av receptet sparades!',
        );
        Navigator.pop(context, true);
      } else {
        UtilityComponents.showErrorSnackbar(
          context,
          viewModel.error ?? 'Kunde inte spara din kopia',
        );
      }
    }
  }

  /// Shows confirmation dialog for unsaved changes
  Future<bool?> _showUnsavedChangesDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Osparade ändringar'),
        content: const Text(
            'Du har osparade ändringar. Vill du verkligen lämna utan att spara?'),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: 'Fortsätt redigera',
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ActionButtons.primaryButton(
            context,
            label: 'Lämna utan att spara',
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    AppLogger.debug('EditRecipeView disposed');
    super.dispose();
  }
}
