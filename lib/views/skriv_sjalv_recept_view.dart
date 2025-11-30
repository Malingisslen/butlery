// lib/views/skriv_sjalv_recept_view.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_text_styles.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/core/constants/app_strings.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/viewmodels/recipe_form_viewmodel.dart';
import 'package:butlery/widgets/common/utility_components.dart';
import 'package:butlery/widgets/common/state_widget.dart';
import 'package:butlery/widgets/image/universal_image_manager.dart';
import 'package:butlery/core/validators/form_validators.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/services/upload/upload_models.dart';
import 'package:butlery/widgets/common/dialogs/draft_recovery_dialog.dart';
import 'package:butlery/core/utils/snackbar_utils.dart';
import 'package:butlery/widgets/common/buttons/action_buttons.dart';
import 'package:butlery/widgets/styled/styled_input.dart';
import 'package:butlery/widgets/common/layout/layout_containers.dart';
import 'package:butlery/widgets/common/layout_components.dart';

class SkrivSjalvReceptView extends StatelessWidget {
  final Recipe? initialRecipe;
  final bool isTemplate;

  const SkrivSjalvReceptView({
    super.key,
    this.initialRecipe,
    this.isTemplate = false,
  });

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => RecipeFormViewModel(
        recipeService: ServiceLocator.get(),
        initialRecipe: initialRecipe,
        isTemplate: isTemplate,
      ),
      child: const _SkrivSjalvReceptViewContent(),
    );
  }
}

class _SkrivSjalvReceptViewContent extends StatefulWidget {
  const _SkrivSjalvReceptViewContent();

  @override
  State<_SkrivSjalvReceptViewContent> createState() =>
      _SkrivSjalvReceptViewContentState();
}

class _SkrivSjalvReceptViewContentState
    extends State<_SkrivSjalvReceptViewContent> {
  final _formKey = GlobalKey<FormState>();

  // CRITICAL FIX: Track save operation to prevent navigation race conditions
  bool _isSaving = false;

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
      await _checkAndShowDraftRecovery();
    });
  }

  /// Initialize text controllers with ViewModel values (called once on first build)
  void _initializeControllersIfNeeded(RecipeFormViewModel viewModel) {
    if (_controllersInitialized) return;

    _titleController = TextEditingController(text: viewModel.title);
    _descriptionController = TextEditingController(text: viewModel.description);
    _portionsController = TextEditingController(
        text: viewModel.portions?.toString() ?? '');
    _timeMinutesController = TextEditingController(
        text: viewModel.timeMinutes?.toString() ?? '');
    _ratingController = TextEditingController(
        text: viewModel.rating?.toString() ?? '');
    _sourceUrlController = TextEditingController(
        text: viewModel.sourceUrl ?? '');
    _controllersInitialized = true;
  }

  /// Setup upload notification listener for background events
  void _setupUploadNotifications() {
    _uploadNotificationSubscription =
        RecipeFormViewModel.uploadNotificationStream.listen(
      (event) {
        if (!mounted) return;

        _handleUploadNotification(event);
      },
      onError: (error) {
        AppLogger.error(
            '🔔 NOTIFICATION: Error in upload notification stream: $error');
      },
    );
  }

  /// Handle upload notification events with appropriate UI feedback
  void _handleUploadNotification(UploadNotificationEvent event) {
    AppLogger.info(
        '🔔 NOTIFICATION: Received ${event.trigger.name}: ${event.message}');

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

  /// Check for available drafts and show recovery dialog if needed
  Future<void> _checkAndShowDraftRecovery() async {
    if (!mounted) return;

    final viewModel = context.read<RecipeFormViewModel>();

    // Only check for drafts when creating new recipes (not editing existing ones)
    if (viewModel.isEditMode) {
      AppLogger.debug(
          '🔄 DRAFT_RECOVERY: Skipping draft check - editing existing recipe');
      return;
    }

    try {
      final availableDrafts = await viewModel.getAvailableDrafts();

      if (availableDrafts.isEmpty) {
        AppLogger.debug('🔄 DRAFT_RECOVERY: No drafts available');
        return;
      }

      AppLogger.info(
          '🔄 DRAFT_RECOVERY: Found ${availableDrafts.length} available drafts');

      if (mounted) {
        final selectedDraftId =
            await context.showDraftRecovery(availableDrafts);

        if (selectedDraftId != null && mounted) {
          await _restoreDraft(selectedDraftId);
        } else {
          AppLogger.info('🔄 DRAFT_RECOVERY: User chose to start fresh');
        }
      }
    } catch (e) {
      AppLogger.error('🔄 DRAFT_RECOVERY: Error checking for drafts: $e');
      // Don't show error to user - draft recovery is optional functionality
    }
  }

  /// Restore draft with user feedback
  Future<void> _restoreDraft(String draftId) async {
    if (!mounted) return;

    try {
      // Show loading state
      SnackBarUtils.showLoading(context, AppStrings.restoringDraft);

      final viewModel = context.read<RecipeFormViewModel>();
      final success = await viewModel.loadFromDraft(draftId);
      if (mounted) {
        if (success) {
          // Show success feedback with field count
          final formData = viewModel.serializeCurrentFormData();
          final fieldCount = _countRestoredFields(formData);

          UtilityComponents.showSuccessSnackbar(
            context,
            AppStrings.draftRestoredWithCount(fieldCount),
          );

          AppLogger.info(
              '🔄 DRAFT_RECOVERY: Draft restored successfully - $fieldCount fields loaded');
        } else {
          UtilityComponents.showErrorSnackbar(
            context,
            AppStrings.couldNotRestoreDraft,
          );

          AppLogger.error(
              '🔄 DRAFT_RECOVERY: Failed to restore draft: $draftId');
        }
      }
    } catch (e) {
      AppLogger.error('🔄 DRAFT_RECOVERY: Error restoring draft: $e');

      if (mounted) {
        UtilityComponents.showErrorSnackbar(
          context,
          AppStrings.couldNotRestoreDraft,
        );
      }
    }
  }

  /// Count non-empty fields in restored form data for user feedback
  int _countRestoredFields(Map<String, dynamic> formData) {
    int count = 0;

    // Core fields
    if (_isNotEmpty(formData['title'])) count++;
    if (_isNotEmpty(formData['description'])) count++;
    if (formData['portions'] != null && formData['portions'] > 0) count++;
    if (formData['timeMinutes'] != null && formData['timeMinutes'] > 0) count++;
    if (_isNotEmpty(formData['sourceUrl'])) count++;

    // Dynamic lists
    final ingredients = formData['ingredients'] as List<String>? ?? [];
    count += ingredients.where((i) => i.trim().isNotEmpty).length;

    final instructions = formData['instructions'] as List<String>? ?? [];
    count += instructions.where((i) => i.trim().isNotEmpty).length;

    final tags = formData['tags'] as List<String>? ?? [];
    count += tags.where((t) => t.trim().isNotEmpty).length;

    // Images
    final imageUrls = formData['imageUrls'] as List<String>? ?? [];
    count += imageUrls.length;

    return count;
  }

  /// Helper method for checking non-empty values
  bool _isNotEmpty(dynamic value) {
    return value != null && value.toString().trim().isNotEmpty;
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
          // ✅ MIGRERAD: Använd UtilityComponents.showSuccessSnackbar
          UtilityComponents.showSuccessSnackbar(context, 'Recept sparat!');
          // MEDIUM PRIORITY FIX: Better navigation that preserves user context
          // Navigate to recipe detail or back to recipes list instead of clearing entire stack
          Navigator.of(context)
              .pop(savedRecipe); // Return to previous screen with saved recipe
        } else {
          // ✅ MIGRERAD: Använd UtilityComponents.showErrorSnackbar
          UtilityComponents.showErrorSnackbar(
              context, viewModel.error ?? 'Kunde inte spara recept');
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

  // FÖRENKLAD SMART BILDVÄLJARE
  Future<void> _pickImage(RecipeFormViewModel viewModel) async {
    AppLogger.info('🎯 BUTTON_TAP: _pickImage called');

    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(AppDimensions.paddingL),
              child: Text(
                AppStrings.addImage,
                style: AppTextStyles.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.photo_camera,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text(AppStrings.takePhoto),
              subtitle: const Text(AppStrings.useCamera),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text(AppStrings.fromGallery),
              subtitle: Text(
                viewModel.canAddMoreImages
                    ? AppStrings.selectUpToImages(
                        RecipeFormViewModel.maxImages -
                            viewModel.imageUrls.length)
                    : AppStrings.selectFromGallery,
              ),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Avbryt'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    AppLogger.info('🎯 BUTTON_TAP: User choice: $choice');

    if (choice == null || !mounted) {
      AppLogger.info(
          '🎯 BUTTON_TAP: Choice was null or not mounted, returning');
      return;
    }

    // MEDIUM PRIORITY FIX: Enhanced error handling for image operations
    try {
      switch (choice) {
        case 'camera':
          AppLogger.info(
              '🎯 BUTTON_TAP: Calling viewModel.pickImageFromCamera (direct)');
          await viewModel.pickImageFromCamera(context);
          break;
        case 'gallery':
          // HIGH PRIORITY FIX: Use canAddMoreImages and proper limit checking instead of hardcoded 4
          if (viewModel.canAddMoreImages &&
              (RecipeFormViewModel.maxImages - viewModel.imageUrls.length) >
                  1) {
            AppLogger.info(
                '🎯 BUTTON_TAP: Calling viewModel.pickMultipleImagesFromGallery (direct)');
            await viewModel.pickMultipleImagesFromGallery(context);
          } else {
            AppLogger.info(
                '🎯 BUTTON_TAP: Calling viewModel.pickImageFromGallery (direct single)');
            await viewModel.pickImageFromGallery(context);
          }
          break;
      }
    } catch (e) {
      AppLogger.error('🎯 BUTTON_TAP: Error during image selection: $e');
      if (mounted) {
        UtilityComponents.showErrorSnackbar(context,
            'Kunde inte välja bild. Kontrollera att appen har behörighet att använda kamera/galleri.');
      }
    }
  }

  // Helper method to check if there are unsaved changes
  bool _hasUnsavedChanges(RecipeFormViewModel viewModel) {
    // Consider form as having unsaved changes if any field has content
    // IMMEDIATE FIX: Safe null checking to prevent crashes
    return viewModel.title.isNotEmpty ||
        viewModel.description.isNotEmpty ||
        viewModel.ingredients
            .any((ingredient) => ingredient.trim().isNotEmpty) ||
        viewModel.instructions
            .any((instruction) => instruction.trim().isNotEmpty) ||
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
        title: const Text('Osparade ändringar'),
        content: const Text(
            'Du har osparade ändringar. Vill du verkligen lämna utan att spara?'),
        actions: [
          ActionButtons.secondaryButton(
            context,
            label: 'Fortsätt skriva',
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
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeFormViewModel>();

    // CRITICAL FIX: Initialize controllers once on first build
    _initializeControllersIfNeeded(viewModel);

    return PopScope(
      canPop: !_isSaving &&
          !viewModel
              .isSaving, // CRITICAL FIX: Prevent navigation during save operations (check both states)
      onPopInvokedWithResult: (bool didPop, Object? result) async {
        if (!didPop) {
          // CRITICAL FIX: Block navigation if save is in progress (check both states)
          if (_isSaving || viewModel.isSaving) {
            if (context.mounted) {
              UtilityComponents.showWarningSnackbar(
                  context, 'Vänta medan receptet sparas...');
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
                UtilityComponents.showWarningSnackbar(context,
                    'En sparning påbörjades under valet. Vänta medan receptet sparas...');
              }
            }
          } else {
            Navigator.of(context).pop();
          }
        }
      },
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            viewModel.isEditMode ? 'Redigera recept' : 'Skriv nytt recept',
          ),
          backgroundColor: AppColors.backgroundBeige,
          foregroundColor: AppColors.textDark,
          iconTheme: const IconThemeData(
            color: AppColors.primaryBlue,
            size: AppDimensions.iconSizeL,
          ),
          actionsIconTheme: const IconThemeData(
            color: AppColors.primaryBlue,
            size: AppDimensions.iconSizeL,
          ),
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
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                    // Måltidstyp - Custom layout to fix text cutoff
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Måltidstyp',
                          style: AppTextStyles.bodySmall.copyWith(
                            color:
                                Theme.of(context).colorScheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(
                            height:
                                4.0), // Minimal gap between label and dropdown
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
                              .map(
                                (mt) => DropdownMenuItem(
                                    value: mt, child: Text(mt)),
                              )
                              .toList(),
                          onChanged: (value) {
                            if (value != null) viewModel.setMealType(value);
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
                            '🌟 RECIPE_VIEW: onSetPrimary called with index $index, imageUrls length: ${viewModel.imageUrls.length}');
                        if (index < viewModel.imageUrls.length) {
                          final imageUrl = viewModel.imageUrls[index];
                          AppLogger.debug(
                              '🌟 RECIPE_VIEW: Setting primary image to: $imageUrl');
                          viewModel.setPrimaryImage(imageUrl);
                        } else {
                          AppLogger.warning(
                              '⚠️ RECIPE_VIEW: Index $index out of bounds for imageUrls (length: ${viewModel.imageUrls.length})');
                        }
                      },
                      userId: ServiceLocator.get<PermissionService>()
                              .currentUserId ??
                          '',
                      onPickImage: () => _pickImage(viewModel),
                      maxImages: 5,
                      isLoading:
                          viewModel.isUploadingImage, // Add loading indicator
                      // Enhanced Upload Progress Parameters
                      uploadStatuses: viewModel.imageUploadStatuses,
                      onRetryUpload: viewModel.retryImageUpload,
                      onCancelUpload: viewModel.cancelImageUpload,
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
                      label: 'Titel',
                      textInputAction: TextInputAction.next,
                      onChanged: viewModel.setTitle,
                      validator: FormValidators.combine([
                        FormValidators.required('Titel'),
                        FormValidators.maxLength(100, 'Titel'),
                      ]),
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Beskrivning
                    StyledInput(
                      controller: _descriptionController,
                      label: 'Beskrivning',
                      maxLines: 2,
                      minLines: 2,
                      textInputAction: TextInputAction.next,
                      onChanged: viewModel.setDescription,
                      validator: FormValidators.maxLength(500, 'Beskrivning'),
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Portioner
                    StyledInput(
                      controller: _portionsController,
                      label: 'Portioner',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) =>
                          viewModel.setPortions(int.tryParse(value)),
                      validator: FormValidators.portions(),
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Tid
                    StyledInput(
                      controller: _timeMinutesController,
                      label: 'Tid (min)',
                      keyboardType: TextInputType.number,
                      textInputAction: TextInputAction.next,
                      onChanged: (value) =>
                          viewModel.setTimeMinutes(int.tryParse(value)),
                      validator: FormValidators.cookingTime(),
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Ingredienser
                    _buildDynamicList(
                      label: 'Ingrediens',
                      controllers: viewModel.ingredientControllers,
                      onUpdate: viewModel.updateIngredient,
                      onAdd: viewModel.addIngredient,
                      onRemove: viewModel.removeIngredient,
                      viewModel: viewModel,
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Instruktioner
                    _buildDynamicList(
                      label: 'Instruktion',
                      controllers: viewModel.instructionControllers,
                      onUpdate: viewModel.updateInstruction,
                      onAdd: viewModel.addInstruction,
                      onRemove: viewModel.removeInstruction,
                      viewModel: viewModel,
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Taggar
                    _buildDynamicList(
                      label: 'Tagg',
                      controllers: viewModel.tagControllers,
                      onUpdate: viewModel.updateTag,
                      onAdd: viewModel.addTag,
                      onRemove: viewModel.removeTag,
                      viewModel: viewModel,
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Betyg
                    StyledInput(
                      controller: _ratingController,
                      label: 'Betyg (0–5)',
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      textInputAction: TextInputAction.next,
                      onChanged: (value) =>
                          viewModel.setRating(double.tryParse(value)),
                      validator: FormValidators.rating(),
                    ),
                    const SizedBox(height: AppDimensions.spacingXl),

                    // Source URL-fält
                    StyledInput(
                      controller: _sourceUrlController,
                      label: 'Källa (URL)',
                      hint: 'Valfritt: länk till originalreceptet',
                      helperText: viewModel.sourceUrl == 'Delad från annan app'
                          ? 'Importerat från delning'
                          : 'Länk till originalreceptet',
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

            // CRITICAL FIX: Loading overlay for both local and ViewModel saving states
            // ✅ RESPONSIVE: Constrained loading overlay
            if (_isSaving || viewModel.isSaving)
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
                      message: 'Sparar recept...',
                    ),
                  ),
                ),
              ),
          ],
        ),
        bottomNavigationBar: BottomActionContainer(
          child: UtilityComponents.primaryButton(
            context,
            label: 'Spara recept',
            icon: Icons.save,
            onPressed: (_isSaving || viewModel.isSaving || !viewModel.isValid)
                ? null
                : _saveRecipe,
            isLoading: _isSaving || viewModel.isSaving,
            loadingText: 'Sparar...',
            isExpanded: true,
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
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: AppDimensions.spacingM),
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
                      onChanged: (value) {
                        onUpdate(index, value);
                        // Add new field when typing in the last field and it becomes non-empty
                        if (index == controllers.length - 1 &&
                            value.trim().isNotEmpty &&
                            value.length == 1) {
                          // Only on first character to prevent duplicates
                          WidgetsBinding.instance.addPostFrameCallback((_) {
                            onAdd();
                          });
                        }
                      },
                    ),
                  ),
                  if (controllers.length > 1)
                    IconButton(
                      icon: const Icon(Icons.delete),
                      onPressed: () => onRemove(index),
                    ),
                ],
              ),
              const SizedBox(height: AppDimensions.spacingS),
            ],
          ),
        if (controllers.isEmpty)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text('Lägg till $label'),
            onPressed: onAdd,
          ),
      ],
    );
  }

  @override
  void dispose() {
    // HIGH PRIORITY FIX: Proper resource disposal to prevent memory leaks
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
        'SkrivSjalvReceptView disposed - notification subscription and controllers disposed');
    super.dispose();
  }
}
