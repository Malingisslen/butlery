// lib/views/skriv_sjalv_recept_view.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/common/indicators/loading_indicator.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/widgets/common/first_recipe_celebration_overlay.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/image/universal_image_manager.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/core/utils/swedish_decimal_input.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/layout_components.dart';
import 'package:butlery/views/recipe_detail/recipe_save_navigation.dart';
import 'package:butlery/widgets/recipe/recipe_draft_recovery_handler.dart';
import 'package:butlery/widgets/recipe/recipe_image_picker.dart';
import 'package:butlery/widgets/recipe/parse_confidence_review.dart';
import 'package:butlery/widgets/recipe/recipe_form/sectioned_ingredient_list_builder.dart';
import 'package:butlery/widgets/tagging/personal_tag_selector.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/keyboard/keyboard_submittable_form.dart';
import 'package:butlery/theme/butlery_colors_extension.dart';

class SkrivSjalvReceptView extends StatelessWidget {
  final Recipe? initialRecipe;
  final bool isTemplate;

  /// After a successful save, navigate to the new recipe's detail page (default)
  /// so the user sees what they created. Onboarding passes false to keep its own
  /// flow — see [RecipeSaveNavigation].
  final bool navigateToDetailOnSave;

  const SkrivSjalvReceptView({
    super.key,
    this.initialRecipe,
    this.isTemplate = false,
    this.navigateToDetailOnSave = true,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeFormViewModel(
        recipeService: ServiceLocator.get(),
        initialRecipe: initialRecipe,
        isTemplate: isTemplate,
      ),
      child: _SkrivSjalvReceptViewContent(
        navigateToDetailOnSave: navigateToDetailOnSave,
      ),
    );
  }
}

class _SkrivSjalvReceptViewContent extends StatefulWidget {
  const _SkrivSjalvReceptViewContent({required this.navigateToDetailOnSave});

  final bool navigateToDetailOnSave;

  @override
  State<_SkrivSjalvReceptViewContent> createState() =>
      _SkrivSjalvReceptViewContentState();
}

class _SkrivSjalvReceptViewContentState
    extends State<_SkrivSjalvReceptViewContent> {
  final _formKey = GlobalKey<FormState>();

  // CRITICAL FIX: Track save operation to prevent navigation race conditions
  bool _isSaving = false;
  bool _showQualityWarning = true;

  // Enhanced upload notification system
  StreamSubscription<UploadNotificationEvent>? _uploadNotificationSubscription;

  // CRITICAL FIX: Store TextEditingControllers in State to prevent text scrambling
  // Creating new controllers on every build causes cursor position to reset to 0
  TextEditingController? _titleController;
  TextEditingController? _descriptionController;
  TextEditingController? _portionsController;
  TextEditingController? _timeMinutesController;
  TextEditingController? _ratingController;
  TextEditingController? _sourceUrlController;
  bool _controllersInitialized = false;

  @override
  void initState() {
    super.initState();
    _setupUploadNotifications();

    // Check for draft recovery after widget build
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (mounted) {
        await RecipeDraftRecoveryHandler.checkAndShowDraftRecovery(context);
      }
    });
  }

  /// Initialize text controllers with ViewModel values (called once on first build)
  void _initializeControllersIfNeeded(RecipeFormViewModel viewModel) {
    if (_controllersInitialized) return;

    _titleController = TextEditingController(text: viewModel.title);
    _descriptionController = TextEditingController(text: viewModel.description);
    _portionsController = TextEditingController(
      text: (viewModel.portions?.toString()).orEmpty(),
    );
    _timeMinutesController = TextEditingController(
      text: (viewModel.timeMinutes?.toString()).orEmpty(),
    );
    _ratingController = TextEditingController(
      // BUT-1910: `toString()` seeds "4.5" with a PERIOD, which is the same
      // cross-screen inconsistency `PantryItem.formattedQuantity` was changed
      // to remove. Harmless to the stored value — an untouched field never
      // re-enters `onChanged` — but the user reads it.
      text: viewModel.rating == null
          ? ''
          : formatSwedishDecimal(viewModel.rating!),
    );
    _sourceUrlController = TextEditingController(
      text: viewModel.sourceUrl.orEmpty(),
    );
    _controllersInitialized = true;
  }

  /// Setup upload notification listener for background events
  void _setupUploadNotifications() {
    _uploadNotificationSubscription = RecipeFormViewModel
        .uploadNotificationStream
        .listen(
          (event) {
            if (!mounted) return;

            _handleUploadNotification(event);
          },
          onError: (error) {
            AppLogger.error(
              '🔔 NOTIFICATION: Error in upload notification stream: $error',
            );
          },
        );
  }

  /// Handle upload notification events with appropriate UI feedback
  void _handleUploadNotification(UploadNotificationEvent event) {
    AppLogger.info(
      '🔔 NOTIFICATION: Received ${event.trigger.name}: ${event.message}',
    );

    // Show snackbar notification based on priority
    switch (event.priority) {
      case NotificationPriority.critical:
      case NotificationPriority.high:
        UtilityComponents.showErrorSnackbar(context, event.message);
        break;
      case NotificationPriority.medium:
        UtilityComponents.showSuccessSnackbar(context, event.message);
        break;
      case NotificationPriority.low:
        // For low priority, only show if it's a completion or success event
        if (event.trigger == UploadNotificationTrigger.allCompleted ||
            event.trigger == UploadNotificationTrigger.retrySuccess) {
          UtilityComponents.showSuccessSnackbar(context, event.message);
        }
        break;
    }
  }

  Future<void> _saveRecipe() async {
    // CRITICAL FIX: Prevent multiple simultaneous save operations
    if (_isSaving) {
      AppLogger.warning('Save already in progress, ignoring duplicate request');
      return;
    }

    // CRITICAL FIX: Safe form validation to prevent null pointer crashes
    final currentState = _formKey.currentState;
    if (currentState == null || !currentState.validate()) return;

    // CRITICAL FIX: Set saving state to prevent navigation race conditions
    setState(() {
      _isSaving = true;
    });

    try {
      final viewModel = context.read<RecipeFormViewModel>();
      final savedRecipe = await viewModel.saveRecipe();

      if (mounted) {
        if (savedRecipe != null) {
          if (viewModel.isFirstRecipe) {
            await FirstRecipeCelebrationOverlay.show(
              context,
              recipeTitle: savedRecipe.title,
            );
          } else {
            final tagResult = savedRecipe.tagResult;

            if (tagResult != null && tagResult.hasFailed) {
              UtilityComponents.showWarningSnackbar(
                context,
                context.l10n.recipeSavedTaggingFailed,
              );
            } else if (tagResult != null && tagResult.tags.isNotEmpty) {
              final coverage = (tagResult.coverage * 100).toInt();
              UtilityComponents.showSuccessSnackbar(
                context,
                context.l10n.recipeSavedWithTags(
                  tagResult.tags.length,
                  coverage,
                ),
              );
            } else {
              UtilityComponents.showSuccessSnackbar(
                context,
                context.l10n.recipeSaved,
              );
            }
          }
          if (mounted) {
            RecipeSaveNavigation.afterSuccessfulSave(
              context,
              savedRecipe,
              navigateToDetail: widget.navigateToDetailOnSave,
            );
          }
        } else {
          // After in-helper retries are exhausted (`withRetry` in the
          // recipe-save path), surface "Försök igen" so the user can try again
          // without re-typing the form.
          UtilityComponents.showErrorSnackbarWithRetry(
            context,
            viewModel.error ?? context.l10n.recipeCouldNotSave,
            onRetry: _saveRecipe,
          );
        }
      }
    } finally {
      // CRITICAL FIX: Always clear saving state, even on error
      if (mounted) {
        setState(() {
          _isSaving = false;
        });
      }
    }
  }

  // Image picker - delegated to RecipeImagePicker
  Future<void> _pickImage(RecipeFormViewModel viewModel) async {
    await RecipeImagePicker.showAndPick(context: context, viewModel: viewModel);
  }

  // Helper method to check if there are unsaved changes
  bool _hasUnsavedChanges(RecipeFormViewModel viewModel) {
    // Consider form as having unsaved changes if any field has content
    // IMMEDIATE FIX: Safe null checking to prevent crashes
    return viewModel.title.isNotEmpty ||
        viewModel.description.isNotEmpty ||
        viewModel.ingredients.any(
          (ingredient) => ingredient.trim().isNotEmpty,
        ) ||
        viewModel.instructions.any(
          (instruction) => instruction.trim().isNotEmpty,
        ) ||
        viewModel.tags.any((tag) => tag.trim().isNotEmpty) ||
        viewModel.imageUrls.isNotEmpty ||
        (viewModel.portions ?? 0) > 0 ||
        (viewModel.timeMinutes ?? 0) > 0 ||
        (viewModel.rating ?? 0) > 0 ||
        (viewModel.sourceUrl?.isNotEmpty ?? false);
  }

  // Show confirmation dialog for unsaved changes
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
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeFormViewModel>();
    // BUT-1845: read the stored meal type ONCE per build; the dropdown's items
    // and its selected value must both come from this.
    final mealTypeOptions = RecipeFormViewModel.mealTypeOptions(
      viewModel.mealType,
    );

    // CRITICAL FIX: Initialize controllers once on first build
    _initializeControllersIfNeeded(viewModel);

    return PopScope(
      canPop:
          !_isSaving &&
          !viewModel
              .isSaving, // CRITICAL FIX: Prevent navigation during save operations (check both states)
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop) {
          // CRITICAL FIX: Block navigation if save is in progress (check both states)
          if (_isSaving || viewModel.isSaving) {
            if (context.mounted) {
              UtilityComponents.showWarningSnackbar(
                context,
                context.l10n.recipeWaitWhileSaving,
              );
            }
            return;
          }

          if (_hasUnsavedChanges(viewModel)) {
            final shouldPop = await _showUnsavedChangesDialog(context) ?? false;

            // CRITICAL FIX: Re-check save state after dialog to prevent race conditions
            if (shouldPop &&
                context.mounted &&
                !_isSaving &&
                !viewModel.isSaving) {
              Navigator.of(context).pop();
            } else if (shouldPop && (_isSaving || viewModel.isSaving)) {
              // Show warning if save started during dialog
              if (context.mounted) {
                UtilityComponents.showWarningSnackbar(
                  context,
                  context.l10n.recipeSaveStartedDuringDialog,
                );
              }
            }
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AdaptiveAppBar(
          title: viewModel.isEditMode
              ? context.l10n.recipeEdit
              : context.l10n.recipeWriteNew,
          backgroundColor: Theme.of(context).colorScheme.surface,
          foregroundColor: Theme.of(context).colorScheme.onSurface,
          iconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.primary,
            size: AppDimensions.iconSizeL,
          ),
          actionsIconTheme: IconThemeData(
            color: Theme.of(context).colorScheme.primary,
            size: AppDimensions.iconSizeL,
          ),
          actions: [
            if (viewModel.isAutoSaving)
              const Padding(
                padding: EdgeInsetsDirectional.only(
                  end: AppDimensions.paddingM,
                ),
                child: LoadingIndicator(
                  size: AppDimensions.iconSizeS,
                  strokeWidth: 2,
                ),
              )
            else if (viewModel.hasRecentAutoSave)
              Padding(
                padding: const EdgeInsetsDirectional.only(
                  end: AppDimensions.paddingM,
                ),
                child: Icon(
                  Icons.cloud_done_outlined,
                  size: AppDimensions.iconSizeM,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
          ],
        ),
        body: Stack(
          children: [
            // ✅ RESPONSIVE: Center and constrain form on large screens
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
                child: Padding(
                  padding: AppDimensions.responsiveContentPadding(context),
                  child: KeyboardSubmittableForm(
                    formKey: _formKey,
                    onSubmit: () {
                      if (_isSaving ||
                          viewModel.isSaving ||
                          !viewModel.isValid) {
                        return;
                      }
                      _saveRecipe();
                    },
                    // BUT-701: scope keyboard tab-order to this form so Tab
                    // walks the fields in visual order. No visual change.
                    child: FocusTraversalGroup(
                      child: ListView(
                        children: [
                          // Parse quality warning for imported recipes
                          if (viewModel.needsReview && _showQualityWarning)
                            _buildQualityWarningBanner(context, viewModel),
                          // Meal type - Custom layout to fix text cutoff
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                context.l10n.recipeMealType,
                                style: AppTextStyles.bodySmall.copyWith(
                                  color: Theme.of(
                                    context,
                                  ).colorScheme.onSurfaceVariant,
                                ),
                              ),
                              const SizedBox(
                                height: 4.0,
                              ), // Minimal gap between label and dropdown
                              // BUT-1845: items and initialValue must come from
                              // ONE read of the stored value — the dropdown's
                              // constructor assert re-checks the match on every
                              // build.
                              DropdownButtonFormField<String>(
                                initialValue: mealTypeOptions.selected,
                                isExpanded: true,
                                decoration: const InputDecoration(
                                  contentPadding: EdgeInsets.symmetric(
                                    horizontal: AppDimensions.paddingL,
                                    vertical: AppDimensions.paddingM,
                                  ),
                                  border: OutlineInputBorder(),
                                ),
                                style: AppTextStyles.bodyMedium,
                                items: mealTypeOptions.values
                                    .map(
                                      (mt) => DropdownMenuItem(
                                        value: mt,
                                        child: Text(mt),
                                      ),
                                    )
                                    .toList(),
                                onChanged: (value) {
                                  if (value != null) {
                                    viewModel.setMealType(value);
                                  }
                                },
                              ),
                            ],
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),

                          // Bildhantering med UniversalImageManager
                          UniversalImageManager.recipeEdit(
                            imageUrls: viewModel.imageUrls,
                            onRemoveImage: viewModel.removeImageAt,
                            onSetPrimary: (index) {
                              AppLogger.debug(
                                '🌟 RECIPE_VIEW: onSetPrimary called with index $index, imageUrls length: ${viewModel.imageUrls.length}',
                              );
                              if (index < viewModel.imageUrls.length) {
                                final imageUrl = viewModel.imageUrls[index];
                                AppLogger.debug(
                                  '🌟 RECIPE_VIEW: Setting primary image to: $imageUrl',
                                );
                                viewModel.setPrimaryImage(imageUrl);
                              } else {
                                AppLogger.warning(
                                  '⚠️ RECIPE_VIEW: Index $index out of bounds for imageUrls (length: ${viewModel.imageUrls.length})',
                                );
                              }
                            },
                            userId:
                                ServiceLocator.get<PermissionService>()
                                    .currentUserId ??
                                '',
                            onPickImage: () => _pickImage(viewModel),
                            maxImages: 5,
                            isLoading: viewModel
                                .isUploadingImage, // Add loading indicator
                            // Enhanced Upload Progress Parameters
                            uploadStatuses: viewModel.imageUploadStatuses,
                            onRetryUpload: viewModel.retryImageUpload,
                            onCancelUpload: (pathOrUrl) async {
                              // BUT-932: wrap remove with undo SnackBar. The
                              // VM defers Storage deletion until save, so undo
                              // restores the image without re-uploading.
                              await viewModel.cancelImageUpload(pathOrUrl);
                              if (!context.mounted) return;
                              if (!viewModel.hasPendingImageDeletion) return;
                              SnackBarUtils.showSuccessWithAction(
                                context,
                                context.l10n.imageRemovedUndoMessage,
                                actionLabel: context.l10n.commonUndo,
                                onAction: viewModel.restoreLastImageDeletion,
                                duration: const Duration(seconds: 5),
                              );
                            },
                            uploadQueueStatus: viewModel.uploadQueueStatusText,
                            // Bulk Upload Management Parameters
                            uploadManagementSummary:
                                viewModel.uploadManagementSummary,
                            onRetryAllFailed: viewModel.retryAllFailedUploads,
                            onCancelAllActive: viewModel.cancelAllActiveUploads,
                            onClearAllFailed: viewModel.clearAllFailedUploads,
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),

                          // Titel
                          StyledInput(
                            controller: _titleController,
                            label: context.l10n.recipeTitle,
                            textInputAction: TextInputAction.next,
                            onChanged: viewModel.setTitle,
                            showWarning: viewModel.fieldsNeedingImprovement
                                .contains('title'),
                            validator: FormValidators.combine([
                              FormValidators.required(context.l10n.recipeTitle),
                              FormValidators.minLength(
                                3,
                                context.l10n.recipeTitle,
                              ),
                              FormValidators.maxLength(
                                100,
                                context.l10n.recipeTitle,
                              ),
                              // BUT-517: block profanity at validator level
                              // (BEFORE the API call).
                              FormValidators.contentFilter(
                                context.l10n.recipeTitle,
                              ),
                            ]),
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),

                          // Beskrivning
                          StyledInput(
                            controller: _descriptionController,
                            label: context.l10n.recipeDescription,
                            maxLines: 2,
                            minLines: 2,
                            textInputAction: TextInputAction.next,
                            onChanged: viewModel.setDescription,
                            validator: FormValidators.combine([
                              FormValidators.maxLength(
                                500,
                                context.l10n.recipeDescription,
                              ),
                              // BUT-517
                              FormValidators.contentFilter(
                                context.l10n.recipeDescription,
                              ),
                            ]),
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),

                          // Portioner
                          StyledInput(
                            controller: _portionsController,
                            label: context.l10n.recipePortions,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            onChanged: (value) =>
                                viewModel.setPortions(int.tryParse(value)),
                            showWarning: viewModel.fieldsNeedingImprovement
                                .contains('portions'),
                            validator: FormValidators.portions(),
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),

                          // Tid
                          StyledInput(
                            controller: _timeMinutesController,
                            label: context.l10n.recipeTimeMinutes,
                            keyboardType: TextInputType.number,
                            textInputAction: TextInputAction.next,
                            onChanged: (value) =>
                                viewModel.setTimeMinutes(int.tryParse(value)),
                            showWarning: viewModel.fieldsNeedingImprovement
                                .contains('totalTime'),
                            validator: FormValidators.cookingTime(),
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),

                          // Ingredienser — sectioned editor (PR #211)
                          SectionedIngredientListBuilder(
                            label: context.l10n.recipeIngredient,
                            rows: viewModel.state.ingredientSectionState.rows,
                            lineControllers: viewModel.ingredientControllers,
                            headingControllerFor: viewModel
                                .state
                                .ingredientSectionState
                                .headingController,
                            onLineChanged: viewModel.updateIngredient,
                            onAddLine: viewModel.addIngredient,
                            onRemoveLine: viewModel.removeIngredient,
                            onReorder: viewModel.moveIngredientRow,
                            onAddHeading: viewModel.addIngredientHeading,
                            onRemoveHeading: viewModel.removeIngredientHeading,
                            onMoveLineToSection:
                                viewModel.moveIngredientLineToSection,
                            canAddHeading: viewModel
                                .state
                                .ingredientSectionState
                                .canAddHeading,
                          ),

                          // BUT-925: per-ingredient confidence review, shown
                          // only for fresh imports that still have a cached
                          // ParsedRecipe (30-min TTL in ParsedRecipeCache).
                          if (viewModel.parsedIngredients != null &&
                              viewModel.parsedIngredients!.isNotEmpty) ...[
                            const SizedBox(height: AppDimensions.spacingM),
                            ParseConfidenceReview(
                              ingredients: viewModel.parsedIngredients!,
                            ),
                          ],
                          const SizedBox(height: AppDimensions.spacingXl),

                          // Instruktioner
                          _buildDynamicList(
                            label: context.l10n.recipeInstruction,
                            controllers: viewModel.instructionControllers,
                            onUpdate: viewModel.updateInstruction,
                            onAdd: viewModel.addInstruction,
                            onRemove: viewModel.removeInstruction,
                            onReorder: viewModel.reorderInstruction,
                            viewModel: viewModel,
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),

                          // Personal tags selector
                          PersonalTagSelector(
                            selectedTagIds: viewModel.tags
                                .where((t) => t.isNotEmpty)
                                .toList(),
                            onChanged: viewModel.setPersonalTagNames,
                            title: context.l10n.recipePersonalTags,
                            showManageButton: true,
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),

                          // Betyg
                          StyledInput(
                            controller: _ratingController,
                            label: context.l10n.recipeRating,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            inputFormatters: const [
                              SwedishDecimalInputFormatter(),
                            ],
                            textInputAction: TextInputAction.next,
                            // BUT-1910: `double.tryParse` returns null on a
                            // comma, so "8,5" set no rating at all and said
                            // nothing. The validator was never the problem —
                            // `FormValidators.rating()` does its own
                            // comma-aware parse, so the field looked valid
                            // while the value was silently dropped.
                            onChanged: (value) =>
                                viewModel.setRating(parseSwedishDecimal(value)),
                            validator: FormValidators.rating(),
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),

                          // Source URL field
                          StyledInput(
                            controller: _sourceUrlController,
                            label: context.l10n.recipeSourceUrl,
                            hint: context.l10n.recipeSourceUrlHint,
                            helperText:
                                viewModel.sourceUrl ==
                                    context.l10n.recipeSharedFromApp
                                ? context.l10n.recipeImportedFromShare
                                : context.l10n.recipeSourceUrlHelper,
                            prefixIcon: const Icon(
                              Icons.link,
                              size: AppDimensions.iconSizeAction,
                            ),
                            keyboardType: TextInputType.url,
                            onChanged: viewModel.setSourceUrl,
                            validator: FormValidators.recipeSourceUrl(),
                          ),
                          const SizedBox(height: AppDimensions.spacingXl),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // CRITICAL FIX: Loading overlay for both local and ViewModel saving states
            // ✅ RESPONSIVE: Constrained loading overlay
            if (_isSaving || viewModel.isSaving)
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
                      message: context.l10n.recipeSaving,
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: BottomActionContainer(
          // BUT-403: `btn-save-recipe` identifier for browser a11y tree.
          child: Semantics(
            identifier: 'btn-save-recipe',
            button: true,
            enabled: !(_isSaving || viewModel.isSaving || !viewModel.isValid),
            label: context.l10n.recipeSave,
            child: Container(
              key: const ValueKey('test-skriv-sjalv-save'),
              child: UtilityComponents.primaryButton(
                context,
                label: context.l10n.recipeSave,
                icon: Icons.save,
                onPressed:
                    (_isSaving || viewModel.isSaving || !viewModel.isValid)
                    ? null
                    : _saveRecipe,
                isLoading: _isSaving || viewModel.isSaving,
                loadingText: context.l10n.statusSaving,
                isExpanded: true,
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDynamicList({
    required String label,
    required List<TextEditingController> controllers,
    required Function(int, String) onUpdate,
    required VoidCallback onAdd,
    required Function(int) onRemove,
    required RecipeFormViewModel viewModel,
    void Function(int, int)? onReorder,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppDimensions.spacingM),
        if (controllers.isNotEmpty && onReorder != null)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: controllers.length,
            onReorder: onReorder,
            proxyDecorator: (child, index, animation) {
              return AnimatedBuilder(
                animation: animation,
                builder: (context, child) => Material(
                  elevation: animation.value * 4,
                  borderRadius: BorderRadius.circular(
                    AppDimensions.borderRadiusS,
                  ),
                  child: child,
                ),
                child: child,
              );
            },
            itemBuilder: (context, index) {
              return Padding(
                key: ValueKey('${label}_$index'),
                padding: const EdgeInsets.only(bottom: AppDimensions.spacingS),
                child: Row(
                  children: [
                    ReorderableDragStartListener(
                      index: index,
                      child: const Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: AppDimensions.spacingS,
                        ),
                        child: Icon(
                          Icons.drag_handle,
                          size: AppDimensions.iconSizeM,
                        ),
                      ),
                    ),
                    Expanded(
                      child: StyledInput(
                        controller: controllers[index],
                        hint: '$label ${index + 1}',
                        textInputAction: TextInputAction.next,
                        maxLines: null,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        // No auto-grow on the first character — it was jarring
                        // (a new empty field popped in mid-type). Use the
                        // explicit "+ Add" button below to add a row.
                        onChanged: (value) => onUpdate(index, value),
                      ),
                    ),
                    if (controllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: context.l10n.commonRemoveLabel(
                          '$label ${index + 1}',
                        ),
                        onPressed: () => onRemove(index),
                      ),
                  ],
                ),
              );
            },
          )
        else ...[
          for (int index = 0; index < controllers.length; index++)
            Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: StyledInput(
                        controller: controllers[index],
                        hint: '$label ${index + 1}',
                        textInputAction: TextInputAction.next,
                        maxLines: null,
                        minLines: 1,
                        keyboardType: TextInputType.multiline,
                        // No auto-grow on the first character — it was jarring
                        // (a new empty field popped in mid-type). Use the
                        // explicit "+ Add" button below to add a row.
                        onChanged: (value) => onUpdate(index, value),
                      ),
                    ),
                    if (controllers.length > 1)
                      IconButton(
                        icon: const Icon(Icons.delete),
                        tooltip: context.l10n.commonRemoveLabel(
                          '$label ${index + 1}',
                        ),
                        onPressed: () => onRemove(index),
                      ),
                  ],
                ),
                const SizedBox(height: AppDimensions.spacingS),
              ],
            ),
        ],
        if (controllers.isEmpty)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text(context.l10n.recipeAddItem(label)),
            onPressed: onAdd,
          ),
      ],
    );
  }

  String _localizeFieldName(BuildContext context, String field) =>
      switch (field) {
        'title' => context.l10n.recipeTitle,
        'ingredients' => context.l10n.recipeIngredients,
        'instructions' => context.l10n.recipeInstructions,
        'portions' => context.l10n.recipePortions,
        'totalTime' => context.l10n.recipeTimeMinutes,
        _ => field,
      };

  Widget _buildQualityWarningBanner(
    BuildContext context,
    RecipeFormViewModel viewModel,
  ) {
    final quality = viewModel.parseQuality ?? 0.0;
    final qualityPercent = (quality * 100).toInt();
    final fields = viewModel.fieldsNeedingImprovement;
    final colors = context.butleryColors;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppDimensions.spacingL),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(AppDimensions.paddingM),
        decoration: BoxDecoration(
          color: colors.warningContainer,
          borderRadius: BorderRadius.circular(AppDimensions.borderRadiusM),
          border: Border.all(
            color: colors.warning.withValues(alpha: 0.4),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.warning_amber_rounded,
                  color: colors.warning,
                  size: AppDimensions.iconSizeM,
                ),
                const SizedBox(width: AppDimensions.spacingS),
                Expanded(
                  child: Text(
                    context.l10n.importParseQualityWarning(qualityPercent),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: colors.onWarningContainer,
                    ),
                  ),
                ),
                Semantics(
                  label: context.l10n.a11yDismissParseQualityWarning,
                  button: true,
                  child: GestureDetector(
                    onTap: () => setState(() => _showQualityWarning = false),
                    child: Icon(
                      Icons.close,
                      size: AppDimensions.iconSizeS,
                      color: colors.onWarningContainer,
                    ),
                  ),
                ),
              ],
            ),
            if (fields.isNotEmpty) ...[
              const SizedBox(height: AppDimensions.spacingS),
              Text(
                '${context.l10n.importFieldsNeedReviewPrefix}: ${fields.map((f) => _localizeFieldName(context, f)).join(', ')}',
                style: AppTextStyles.bodySmall.copyWith(
                  color: colors.onWarningContainer.withValues(alpha: 0.7),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    // Cancel upload notification subscription to prevent memory leaks
    _uploadNotificationSubscription?.cancel();

    // CRITICAL FIX: Dispose text controllers to prevent memory leaks
    _titleController?.dispose();
    _descriptionController?.dispose();
    _portionsController?.dispose();
    _timeMinutesController?.dispose();
    _ratingController?.dispose();
    _sourceUrlController?.dispose();

    AppLogger.debug(
      'SkrivSjalvReceptView disposed - notification subscription and controllers disposed',
    );
    super.dispose();
  }
}
