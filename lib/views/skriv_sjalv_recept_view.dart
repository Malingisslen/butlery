// lib/views/skriv_sjalv_recept_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import 'package:butlery/theme/app_theme.dart';
import '../models/recipe.dart';
import '../viewmodels/recipe_form_viewmodel.dart';
import '../widgets/common/utility_components.dart';
import '../widgets/common/state_widget.dart';
import '../widgets/image/universal_image_manager.dart';
import '../core/validators/form_validators.dart';
import '../core/injection.dart';
import '../services/permission_service.dart';

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
        recipeService: sl(),
        analyticsService: sl(),
        storageService: sl(),
        imagePickerService: sl(),
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

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = context.read<RecipeFormViewModel>();
    final success = await viewModel.saveRecipe();

    if (mounted) {
      if (success) {
        // ✅ MIGRERAD: Använd UtilityComponents.showSuccessSnackbar
        UtilityComponents.showSuccessSnackbar(context, 'Recept sparat!');
        Navigator.pushNamedAndRemoveUntil(context, '/', (r) => false);
      } else {
        // ✅ MIGRERAD: Använd UtilityComponents.showErrorSnackbar
        UtilityComponents.showErrorSnackbar(
            context, viewModel.error ?? 'Kunde inte spara recept');
      }
    }
  }

  // FÖRENKLAD SMART BILDVÄLJARE
  Future<void> _pickImage(RecipeFormViewModel viewModel) async {
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(AppTheme.spacingMd),
              child: Text(
                'Lägg till bild',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.photo_camera,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Ta foto'),
              subtitle: const Text('Använd kameran'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: Icon(
                Icons.photo_library,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: const Text('Från galleriet'),
              subtitle: Text(
                viewModel.canAddMoreImages
                    ? 'Välj upp till ${RecipeFormViewModel.maxImages - viewModel.imageUrls.length} bilder'
                    : 'Välj en bild från galleriet',
              ),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            const Divider(height: 1),
            ListTile(
              leading: Icon(
                Icons.link,
                color: Theme.of(context).colorScheme.secondary,
              ),
              title: const Text('Lägg till från URL'),
              subtitle: const Text('För bilder från webben'),
              onTap: () => Navigator.pop(context, 'url'),
            ),
            ListTile(
              leading: const Icon(Icons.close),
              title: const Text('Avbryt'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );

    if (choice == null || !mounted) return;

    switch (choice) {
      case 'camera':
        await viewModel.pickAndUploadImage(context, source: ImageSource.camera);
        break;
      case 'gallery':
        if (viewModel.canAddMoreImages && viewModel.imageUrls.length < 4) {
          await viewModel.pickMultipleImages(context);
        } else {
          await viewModel.pickAndUploadImage(
            context,
            source: ImageSource.gallery,
          );
        }
        break;
      case 'url':
        final controller = TextEditingController();
        final url = await showDialog<String>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Lägg till bild från URL'),
            content: TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: 'Bild-URL',
                hintText: 'https://exempel.com/bild.jpg',
              ),
              keyboardType: TextInputType.url,
              autofocus: true,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Avbryt'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, controller.text),
                child: const Text('Lägg till'),
              ),
            ],
          ),
        );

        if (url != null && url.isNotEmpty) {
          if (Uri.tryParse(url) != null &&
              (url.startsWith('http://') || url.startsWith('https://'))) {
            viewModel.addImageUrl(url);
          } else {
            if (mounted) {
              UtilityComponents.showErrorSnackbar(context,
                  'Ogiltig URL. Använd en fullständig URL som börjar med http:// eller https://');
            }
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeFormViewModel>();

    return Scaffold(
      appBar: AppBar(
        title: Text(
          viewModel.isEditMode ? 'Redigera recept' : 'Skriv nytt recept',
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: AppTheme.screenPadding,
            child: Form(
              key: _formKey,
              child: ListView(
                padding: EdgeInsets.only(
                  bottom: AppTheme.spacingXxl + AppTheme.spacingMd,
                ),
                children: [
                  // Måltidstyp
                  DropdownButtonFormField<String>(
                    value: viewModel.mealType,
                    decoration: const InputDecoration(labelText: 'Måltidstyp'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    items: RecipeFormViewModel.mealTypes
                        .map(
                          (mt) => DropdownMenuItem(value: mt, child: Text(mt)),
                        )
                        .toList(),
                    onChanged: (value) {
                      if (value != null) viewModel.setMealType(value);
                    },
                  ),
                  AppTheme.mediumGap,

                  // Bildhantering med UniversalImageManager
                  UniversalImageManager.recipeEdit(
                    imageUrls: viewModel.imageUrls,
                    onAddImage: viewModel.addImageUrl,
                    onRemoveImage: viewModel.removeImageAt,
                    onSetPrimary: viewModel.setPrimaryImage,
                    userId: sl<PermissionService>().currentUserId ?? "",
                    onPickImage: () => _pickImage(viewModel),
                    maxImages: 5,
                  ),
                  AppTheme.largeGap,

                  // Titel
                  TextFormField(
                    initialValue: viewModel.title,
                    decoration: const InputDecoration(labelText: 'Titel'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textInputAction: TextInputAction.next,
                    onChanged: viewModel.setTitle,
                    validator: FormValidators.combine([
                      FormValidators.required('Titel'),
                      FormValidators.maxLength(100, 'Titel'),
                    ]),
                  ),
                  AppTheme.mediumGap,

                  // Beskrivning
                  TextFormField(
                    initialValue: viewModel.description,
                    maxLines: 2,
                    decoration: const InputDecoration(labelText: 'Beskrivning'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textInputAction: TextInputAction.next,
                    onChanged: viewModel.setDescription,
                    validator: FormValidators.maxLength(500, 'Beskrivning'),
                  ),
                  AppTheme.mediumGap,

                  // Portioner
                  TextFormField(
                    initialValue: viewModel.portions?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'Portioner'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onChanged: viewModel.setPortions,
                    validator: FormValidators.portions(),
                  ),
                  AppTheme.mediumGap,

                  // Tid
                  TextFormField(
                    initialValue: viewModel.timeMinutes?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'Tid (min)'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    keyboardType: TextInputType.number,
                    textInputAction: TextInputAction.next,
                    onChanged: viewModel.setTimeMinutes,
                    validator: FormValidators.cookingTime(),
                  ),
                  AppTheme.mediumGap,

                  // Ingredienser
                  _buildDynamicList(
                    label: 'Ingrediens',
                    controllers: viewModel.ingredientControllers,
                    onUpdate: viewModel.updateIngredient,
                    onAdd: viewModel.addIngredient,
                    onRemove: viewModel.removeIngredient,
                    viewModel: viewModel,
                  ),
                  AppTheme.mediumGap,

                  // Instruktioner
                  _buildDynamicList(
                    label: 'Instruktion',
                    controllers: viewModel.instructionControllers,
                    onUpdate: viewModel.updateInstruction,
                    onAdd: viewModel.addInstruction,
                    onRemove: viewModel.removeInstruction,
                    viewModel: viewModel,
                  ),
                  AppTheme.mediumGap,

                  // Taggar
                  _buildDynamicList(
                    label: 'Tagg',
                    controllers: viewModel.tagControllers,
                    onUpdate: viewModel.updateTag,
                    onAdd: viewModel.addTag,
                    onRemove: viewModel.removeTag,
                    viewModel: viewModel,
                  ),
                  AppTheme.mediumGap,

                  // Betyg
                  TextFormField(
                    initialValue: viewModel.rating?.toString() ?? '',
                    decoration: const InputDecoration(labelText: 'Betyg (0–5)'),
                    style: Theme.of(context).textTheme.bodyMedium,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.next,
                    onChanged: viewModel.setRating,
                    validator: FormValidators.rating(),
                  ),
                  AppTheme.mediumGap,

                  // Source URL-fält
                  TextFormField(
                    initialValue: viewModel.sourceUrl ?? '',
                    decoration: InputDecoration(
                      labelText: 'Källa (URL)',
                      hintText: 'Valfritt: länk till originalreceptet',
                      helperText: viewModel.sourceUrl == 'Delad från annan app'
                          ? 'Importerat från delning'
                          : 'Länk till originalreceptet',
                      prefixIcon: Icon(
                        Icons.link,
                        size: AppTheme.iconSizeAction,
                      ),
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                    keyboardType: TextInputType.url,
                    onChanged: viewModel.setSourceUrl,
                    validator: (value) {
                      if (value == null || value.isEmpty) return null;
                      if (value.startsWith('Delad från') ||
                          value.startsWith('Importerad från') ||
                          value.contains('Butlery')) {
                        return null;
                      }
                      return FormValidators.url()(value);
                    },
                  ),
                ],
              ),
            ),
          ),

          // Loading overlay med StateWidget
          if (viewModel.isSaving)
            Container(
              color: AppTheme.overlayLight,
              child: Center(
                child: StateWidget.loading(
                  message: 'Sparar recept...',
                ),
              ),
            ),
        ],
      ),

      // ✅ MIGRERAD: ActionButton.primary → UtilityComponents.primaryButton
      bottomNavigationBar: Padding(
        padding: AppTheme.screenPadding,
        child: UtilityComponents.primaryButton(
          context,
          label: 'Spara recept',
          icon: Icons.save,
          onPressed:
              viewModel.isSaving || !viewModel.isValid ? null : _saveRecipe,
          isLoading: viewModel.isSaving,
          loadingText: 'Sparar...',
          isExpanded: true,
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
        Text(label, style: AppTheme.formLabelStyle),
        AppTheme.smallGap,
        ...controllers.asMap().entries.map((entry) {
          final index = entry.key;
          final controller = entry.value;

          return Padding(
            padding: EdgeInsets.only(bottom: AppTheme.spacingSm),
            child: Row(
              children: [
                Expanded(
                  child: TextFormField(
                    controller: controller,
                    decoration: InputDecoration(
                      hintText: '$label ${index + 1}',
                    ),
                    style: Theme.of(context).textTheme.bodyMedium,
                    textInputAction: TextInputAction.next,
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onChanged: (value) {
                      onUpdate(index, value);
                      if (index == controllers.length - 1 && value.isNotEmpty) {
                        WidgetsBinding.instance.addPostFrameCallback((_) {
                          onAdd();
                        });
                      }
                    },
                  ),
                ),
                if (controllers.length > 1)
                  IconButton(
                    icon: AppTheme.actionIcon(context, Icons.delete),
                    onPressed: () => onRemove(index),
                  ),
              ],
            ),
          );
        }),
        if (controllers.isEmpty)
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text('Lägg till $label'),
            onPressed: onAdd,
          ),
      ],
    );
  }
}
