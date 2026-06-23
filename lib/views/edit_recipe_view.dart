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
import 'package:butlery/widgets/realtime/conflict_banner.dart';
import 'package:provider/provider.dart';
import 'package:butlery/services/auth_service.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/viewmodels/collaborative_status_viewmodel.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/state_widget.dart';
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
import 'package:butlery/widgets/common/input/portion_scaler.dart';
import 'package:butlery/widgets/tagging/tag_editor_dialog.dart';
import 'package:butlery/widgets/tagging/personal_tag_selector.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/keyboard/keyboard_submittable_form.dart';
import 'package:butlery/widgets/recipe/related_recipes_editor.dart';

/// Comprehensive recipe editing view with all components inlined.
class EditRecipeView extends StatefulWidget {
  final Recipe recipe;

  const EditRecipeView({super.key, required this.recipe});

  @override
  State<EditRecipeView> createState() => _EditRecipeViewState();
}

class _EditRecipeViewState extends State<EditRecipeView> {
  late final CollaborativeStatusViewModel _collaborativeStatusViewModel;

  @override
  void initState() {
    super.initState();
    _collaborativeStatusViewModel =
        ServiceLocator.get<CollaborativeStatusViewModel>();
  }

  @override
  void dispose() {
    _collaborativeStatusViewModel.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthService>.value(
          value: ServiceLocator.get<AuthService>(),
        ),
        ChangeNotifierProvider<RecipeFormViewModel>(
          create: (_) => RecipeFormViewModel(
            recipeService: ServiceLocator.get(),
            initialRecipe: widget.recipe,
          ),
        ),
        ChangeNotifierProvider<CollaborativeStatusViewModel>.value(
          value: _collaborativeStatusViewModel,
        ),
      ],
      child: _EditRecipeViewContent(recipe: widget.recipe),
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
  late final String _currentUserId;

  @override
  void initState() {
    super.initState();
    _currentUserId = ServiceLocator.get<PermissionService>().currentUserId
        .orEmpty();
  }

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
                    LayoutComponents.offlineIndicator(),
                    _buildSmartBanners(context, widget.recipe),
                    // BUT-1162: surface silent collaborative-edit conflict
                    // resolutions on this recipe (drop-in; collapses when idle).
                    ConflictBanner(filterDocId: widget.recipe.id),
                    Expanded(
                      child: Padding(
                        padding: AppDimensions.responsiveContentPadding(
                          context,
                        ),
                        child: KeyboardSubmittableForm(
                          formKey: _formKey,
                          onSubmit: () {
                            if (viewModel.isSaving || !viewModel.isValid) {
                              return;
                            }
                            _saveRecipe(context);
                          },
                          // BUT-701: scope keyboard tab-order to this form so
                          // Tab walks the fields in visual order (matches the
                          // shopping_item_dialog pattern). No visual change.
                          child: FocusTraversalGroup(
                            child: ListView(
                              children: _buildFormFields(context, viewModel),
                            ),
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
                color: Theme.of(context).colorScheme.surface.withValues(
                  alpha: AppDimensions.opacityVeryDark,
                ),
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
                      message: context.l10n.recipeUpdating,
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
      child: Selector<CollaborativeStatusViewModel, bool>(
        selector: (_, vm) =>
            vm.getRecipeCollaborativeStatus(recipe.id, recipe).isCollaborative,
        builder: (context, isCollaborative, child) {
          return AppBar(
            title: Text(context.l10n.recipeEdit),
            backgroundColor: isCollaborative
                ? Theme.of(context).colorScheme.primary.withValues(
                    alpha: AppDimensions.opacityVeryLight,
                  )
                : null,
            actions: [
              Selector<RecipeFormViewModel, (bool, bool)>(
                selector: (_, vm) => (vm.isAutoSaving, vm.hasRecentAutoSave),
                builder: (context, state, _) {
                  final (isAutoSaving, hasRecentAutoSave) = state;
                  if (isAutoSaving) {
                    return const Padding(
                      padding: EdgeInsetsDirectional.only(
                        end: AppDimensions.spacingL,
                      ),
                      child: Center(
                        child: LoadingIndicator(
                          size: AppDimensions.iconSizeS,
                          strokeWidth: 2,
                        ),
                      ),
                    );
                  } else if (hasRecentAutoSave) {
                    return Padding(
                      padding: const EdgeInsetsDirectional.only(
                        end: AppDimensions.spacingL,
                      ),
                      child: Center(
                        child: Icon(
                          Icons.cloud_done_outlined,
                          size: AppDimensions.iconSizeM,
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
              if (isCollaborative)
                Padding(
                  padding: const EdgeInsetsDirectional.only(
                    end: AppDimensions.spacingL,
                  ),
                  child: Center(
                    child:
                        SocialCollaborativeComponents.collaborativeStatusBadge(
                          text: context.l10n.socialShared,
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
    return Column(
      children: [
        _buildCollaborativeBanner(context, recipe),
        Selector<RecipeFormViewModel, String?>(
          selector: (_, vm) => vm.editMode,
          builder: (context, _, __) {
            final recipeViewModel = context.read<RecipeFormViewModel>();
            return SocialCollaborativeComponents.smartPermissionsBanner(
              context: context,
              viewModel: recipeViewModel,
            );
          },
        ),
      ],
    );
  }

  Widget _buildCollaborativeBanner(BuildContext context, Recipe recipe) {
    return Selector<CollaborativeStatusViewModel, bool>(
      selector: (_, vm) =>
          vm.getRecipeCollaborativeStatus(recipe.id, recipe).isCollaborative,
      builder: (context, isCollaborative, child) {
        if (!isCollaborative) return const SizedBox.shrink();

        return SocialCollaborativeComponents.collaborativeBanner(
          title: context.l10n.socialEditingTogether,
          subtitle: context.l10n.socialChangesSyncAutomatically,
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
          label: context.l10n.commonSaveChanges,
          icon: Icons.save,
          onPressed: viewModel.isSaving || !viewModel.isValid
              ? null
              : () => _saveRecipe(context),
          isLoading: viewModel.isSaving,
          loadingText: context.l10n.statusSaving,
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
    BuildContext context,
    RecipeFormViewModel viewModel,
  ) {
    return [
      // Meal type dropdown
      Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            context.l10n.recipeMealType,
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
        userId: _currentUserId,
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
        decoration: InputDecoration(labelText: context.l10n.recipeTitle),
        style: AppTextStyles.bodyMedium,
        textInputAction: TextInputAction.next,
        onChanged: viewModel.setTitle,
        validator: FormValidators.combine([
          FormValidators.required(context.l10n.recipeTitle),
          FormValidators.minLength(3, context.l10n.recipeTitle),
          FormValidators.maxLength(100, context.l10n.recipeTitle),
          // BUT-517: block profanity at validator level (BEFORE the API call).
          FormValidators.contentFilter(context.l10n.recipeTitle),
        ]),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Description field
      TextFormField(
        initialValue: viewModel.description,
        maxLines: 2,
        decoration: InputDecoration(labelText: context.l10n.recipeDescription),
        style: AppTextStyles.bodyMedium,
        textInputAction: TextInputAction.next,
        onChanged: viewModel.setDescription,
        validator: FormValidators.combine([
          FormValidators.maxLength(500, context.l10n.recipeDescription),
          // BUT-517
          FormValidators.contentFilter(context.l10n.recipeDescription),
        ]),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Portions field
      TextFormField(
        initialValue: (viewModel.portions?.toString()).orEmpty(),
        decoration: InputDecoration(labelText: context.l10n.recipePortions),
        style: AppTextStyles.bodyMedium,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        onChanged: (value) => viewModel.setPortions(int.tryParse(value)),
        validator: FormValidators.portions(),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Time field
      TextFormField(
        initialValue: (viewModel.timeMinutes?.toString()).orEmpty(),
        decoration: InputDecoration(labelText: context.l10n.recipeTimeMinutes),
        style: AppTextStyles.bodyMedium,
        keyboardType: TextInputType.number,
        textInputAction: TextInputAction.next,
        onChanged: (value) => viewModel.setTimeMinutes(int.tryParse(value)),
        validator: FormValidators.cookingTime(),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Portion scaler — scale ingredients when portions change.
      // Uses immutable original recipe data as base to prevent compounding
      // rounding errors on repeated scaling.
      if (viewModel.portions != null &&
          viewModel.portions! > 0 &&
          widget.recipe.core.portions != null &&
          widget.recipe.core.portions! > 0)
        Padding(
          padding: const EdgeInsets.only(bottom: AppDimensions.spacingXl),
          child: PortionScaler(
            originalPortions: widget.recipe.core.portions!,
            originalIngredients: widget.recipe.ingredients
                .where((i) => i.trim().isNotEmpty)
                .toList(),
            onPortionChanged: viewModel.scaleIngredientsToPortions,
          ),
        ),

      // Ingredients dynamic list
      DynamicListBuilder(
        label: context.l10n.recipeIngredient,
        controllers: viewModel.ingredientControllers,
        onUpdate: viewModel.updateIngredient,
        onAdd: viewModel.addIngredient,
        onRemove: viewModel.removeIngredient,
        onReorder: viewModel.reorderIngredient,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Instructions dynamic list
      DynamicListBuilder(
        label: context.l10n.recipeInstruction,
        controllers: viewModel.instructionControllers,
        onUpdate: viewModel.updateInstruction,
        onAdd: viewModel.addInstruction,
        onRemove: viewModel.removeInstruction,
        onReorder: viewModel.reorderInstruction,
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Personal tags selector (select from predefined tags)
      // Users can create new tags via the "Hantera" button
      PersonalTagSelector(
        selectedTagIds: viewModel.tags.where((t) => t.isNotEmpty).toList(),
        onChanged: viewModel.setPersonalTagNames,
        title: context.l10n.recipePersonalTags,
        showManageButton: true,
      ),
      const SizedBox(height: AppDimensions.spacingM),

      // Auto-generated tags management (allergens, dietary, etc.)
      _buildManageTagsButton(context, viewModel),
      const SizedBox(height: AppDimensions.spacingXl),

      // Rating field
      TextFormField(
        initialValue: (viewModel.rating?.toString()).orEmpty(),
        decoration: InputDecoration(labelText: context.l10n.recipeRating),
        style: AppTextStyles.bodyMedium,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        textInputAction: TextInputAction.next,
        onChanged: (value) => viewModel.setRating(double.tryParse(value)),
        validator: FormValidators.rating(),
      ),
      const SizedBox(height: AppDimensions.spacingXl),

      // Source URL field
      TextFormField(
        initialValue: viewModel.sourceUrl.orEmpty(),
        decoration: InputDecoration(
          labelText: context.l10n.recipeSourceUrl,
          hintText: context.l10n.recipeSourceUrlHint,
          helperText: viewModel.sourceUrl == context.l10n.recipeSharedFromApp
              ? context.l10n.recipeImportedFromShare
              : context.l10n.recipeSourceUrlHelper,
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
      const SizedBox(height: AppDimensions.spacingXl),

      // BUT-1057: Related recipes section — link/unlink other recipes.
      // Only shown when editing an existing recipe (originalRecipe != null).
      if (viewModel.originalRecipe != null)
        RelatedRecipesEditor(
          currentRecipeId: viewModel.originalRecipe!.id,
          relatedRecipes: viewModel.relatedRecipes,
          onLink: viewModel.linkRelatedRecipe,
          onUnlink: viewModel.unlinkRelatedRecipe,
        ),
    ];
  }

  Widget _buildManageTagsButton(
    BuildContext context,
    RecipeFormViewModel viewModel,
  ) {
    final hasAutoTags = viewModel.recipe?.tagResult?.tags.isNotEmpty ?? false;

    return OutlinedButton.icon(
      onPressed: () => _openTagEditor(context, viewModel),
      icon: const Icon(Icons.local_offer_outlined),
      label: Text(
        hasAutoTags
            ? context.l10n.recipeManageAllTags
            : context.l10n.recipeAddTags,
        style: AppTextStyles.bodyMedium,
      ),
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(
          horizontal: AppDimensions.paddingL,
          vertical: AppDimensions.paddingM,
        ),
        side: BorderSide(color: Theme.of(context).colorScheme.primary),
        foregroundColor: Theme.of(context).colorScheme.primary,
      ),
    );
  }

  Future<void> _openTagEditor(
    BuildContext context,
    RecipeFormViewModel viewModel,
  ) async {
    final recipe = viewModel.recipe;
    if (recipe == null) return;

    final result = await TagEditorDialog.show(context, recipe);
    if (result != null) {
      viewModel.setTagOverrides(result);
      if (context.mounted) {
        UtilityComponents.showSuccessSnackbar(
          context,
          context.l10n.recipeTagsUpdated,
        );
      }
    }
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
        final collaborativeViewModel = context
            .read<CollaborativeStatusViewModel>();
        collaborativeViewModel.invalidateRecipeStatus(widget.recipe.id);

        UtilityComponents.showSuccessSnackbar(
          context,
          context.l10n.recipeChangesSaved,
        );
        Navigator.pop(context, true);
      } else {
        UtilityComponents.showErrorSnackbar(
          context,
          viewModel.error ?? context.l10n.recipeCouldNotSaveChanges,
        );
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
          context.l10n.recipeCopySaved,
        );
        Navigator.pop(context, true);
      } else {
        UtilityComponents.showErrorSnackbar(
          context,
          viewModel.error ?? context.l10n.recipeCouldNotSaveCopy,
        );
      }
    }
  }

  /// Shows confirmation dialog for unsaved changes
  Future<bool?> _showUnsavedChangesDialog(BuildContext context) {
    return showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.recipeUnsavedChangesTitle),
        content: Text(context.l10n.confirmUnsavedChanges),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: context.l10n.recipeContinueEditing,
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ActionButtons.primaryButton(
            context,
            label: context.l10n.recipeLeaveWithoutSaving,
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
