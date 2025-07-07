// lib/views/edit_recipe_view.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:image_picker/image_picker.dart';
import '../services/auth_service.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart'; // ✅ FIX: Lägg till UserProfile import
import '../viewmodels/recipe_form_viewmodel.dart';
import '../widgets/common/utility_components.dart';
import '../widgets/common/social_components.dart'; // ✅ FIX: Ändra till SocialComponents
import '../widgets/image/universal_image_manager.dart';
import '../theme/app_theme.dart';
import '../core/validators/form_validators.dart';
import '../core/injection.dart';

/// ✨ FIXAD REDIGERA RECEPT VY - Provider-problemet löst + alla imports korrekta
class EditRecipeView extends StatelessWidget {
  final Recipe recipe;

  const EditRecipeView({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    // ✅ FIX: Skapa en MultiProvider som inkluderar både RecipeFormViewModel OCH AuthService
    return MultiProvider(
      providers: [
        // AuthService måste vara tillgänglig för hela widget-trädet
        Provider<AuthService>.value(value: sl<AuthService>()),

        // RecipeFormViewModel som consumer kan läsa
        ChangeNotifierProvider<RecipeFormViewModel>(
          create: (_) => RecipeFormViewModel(
            recipeService: sl(),
            analyticsService: sl(),
            storageService: sl(),
            imagePickerService: sl(),
            authService:
                sl<AuthService>(), // ✅ Använd service locator direkt här
            initialRecipe: recipe,
          ),
        ),
      ],
      child: const _EditRecipeViewContent(),
    );
  }
}

class _EditRecipeViewContent extends StatefulWidget {
  const _EditRecipeViewContent();

  @override
  State<_EditRecipeViewContent> createState() => _EditRecipeViewContentState();
}

class _EditRecipeViewContentState extends State<_EditRecipeViewContent> {
  final _formKey = GlobalKey<FormState>();

  Future<void> _saveRecipe() async {
    if (!_formKey.currentState!.validate()) return;

    final viewModel = context.read<RecipeFormViewModel>();
    final success = await viewModel.saveRecipe();

    if (mounted) {
      if (success) {
        UtilityComponents.showSuccessSnackbar(context, 'Ändringar sparade!');
        Navigator.pop(context, true);
      } else {
        UtilityComponents.showErrorSnackbar(
            context, viewModel.error ?? 'Kunde inte spara ändringar');
      }
    }
  }

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
              UtilityComponents.showErrorSnackbar(context, 'Ogiltig URL');
            }
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<RecipeFormViewModel>();
    // ✅ FIX: Nu läser vi AuthService från Provider istället för direkt context.read
    final authService = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Redigera recept'),
        // ✅ BONUS: Lägg till indikator om det är ett kollaborativt recept
        backgroundColor: _isCollaborativeRecipe()
            ? AppTheme.primaryColor.withValues(alpha: 0.1)
            : null,
        actions: [
          // ✅ BONUS: Visa collaborative indicator
          if (_isCollaborativeRecipe())
            Padding(
              padding: EdgeInsets.only(right: AppTheme.spacingMd),
              child: Center(
                child: SocialComponents.collaborativeStatusBadge(
                  text: 'Delat',
                  icon: Icons.people,
                ),
              ),
            ),
        ],
      ),
      bottomNavigationBar: Padding(
        padding: AppTheme.screenPadding,
        child: UtilityComponents.primaryButton(
          context,
          label: 'Spara ändringar',
          icon: Icons.save,
          onPressed:
              viewModel.isSaving || !viewModel.isValid ? null : _saveRecipe,
          isLoading: viewModel.isSaving,
          loadingText: 'Sparar...',
          isExpanded: true,
        ),
      ),
      body: Stack(
        children: [
          // ✅ ÅTERANVÄNDBAR: Collaborative banner
          Column(
            children: [
              if (_isCollaborativeRecipe())
                SocialComponents.collaborativeBanner(
                  title: 'Du redigerar tillsammans med andra',
                  subtitle: 'Ändringar synkas automatiskt med andra deltagare',
                  participants:
                      _getMockParticipants(), // ✅ FIX: Ersätt med riktig data
                  totalParticipants: 4,
                ),
              Expanded(
                child: Padding(
                  padding: AppTheme.screenPadding,
                  child: Form(
                    key: _formKey,
                    child: ListView(
                      children: [
                        // Måltidstyp
                        DropdownButtonFormField<String>(
                          value: viewModel.mealType,
                          decoration:
                              const InputDecoration(labelText: 'Måltidstyp'),
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
                        AppTheme.mediumGap,

                        // Bildhantering med UniversalImageManager
                        UniversalImageManager.recipeEdit(
                          imageUrls: viewModel.imageUrls,
                          userId: authService.currentUser?.uid ?? '',
                          onAddImage: viewModel.addImageUrl,
                          onRemoveImage: viewModel.removeImageAt,
                          onSetPrimary: viewModel.setPrimaryImage,
                          onPickImage: () => _pickImage(viewModel),
                          maxImages: 5,
                        ),
                        AppTheme.largeGap,

                        // Titel
                        TextFormField(
                          initialValue: viewModel.title,
                          decoration: const InputDecoration(labelText: 'Titel'),
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
                          decoration:
                              const InputDecoration(labelText: 'Beskrivning'),
                          onChanged: viewModel.setDescription,
                          validator:
                              FormValidators.maxLength(500, 'Beskrivning'),
                        ),
                        AppTheme.mediumGap,

                        // Portioner
                        TextFormField(
                          initialValue: viewModel.portions?.toString() ?? '',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Antal portioner',
                          ),
                          onChanged: viewModel.setPortions,
                          validator: FormValidators.portions(),
                        ),
                        AppTheme.mediumGap,

                        // Tid
                        TextFormField(
                          initialValue: viewModel.timeMinutes?.toString() ?? '',
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Tid (minuter)',
                          ),
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
                        ),
                        AppTheme.mediumGap,

                        // Instruktioner
                        _buildDynamicList(
                          label: 'Instruktion',
                          controllers: viewModel.instructionControllers,
                          onUpdate: viewModel.updateInstruction,
                          onAdd: viewModel.addInstruction,
                          onRemove: viewModel.removeInstruction,
                        ),
                        AppTheme.mediumGap,

                        // Taggar
                        _buildDynamicList(
                          label: 'Tagg',
                          controllers: viewModel.tagControllers,
                          onUpdate: viewModel.updateTag,
                          onAdd: viewModel.addTag,
                          onRemove: viewModel.removeTag,
                        ),
                        AppTheme.mediumGap,

                        // Betyg
                        TextFormField(
                          initialValue: viewModel.rating?.toString() ?? '',
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          decoration:
                              const InputDecoration(labelText: 'Betyg (0–5)'),
                          onChanged: viewModel.setRating,
                          validator: FormValidators.rating(),
                        ),
                        AppTheme.mediumGap,

                        // Source URL-fält
                        TextFormField(
                          initialValue: viewModel.sourceUrl ?? '',
                          decoration: InputDecoration(
                            labelText: 'Källa (URL)',
                            hintText: 'https://exempel.com/recept',
                            helperText: 'Länk till originalreceptet',
                            prefixIcon: Icon(
                              Icons.link,
                              size: AppTheme.iconSizeAction,
                            ),
                          ),
                          keyboardType: TextInputType.url,
                          onChanged: viewModel.setSourceUrl,
                          validator: FormValidators.url(),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),

          // Loading overlay med UtilityComponents
          if (viewModel.isSaving)
            UtilityComponents.loadingOverlay(
              isLoading: true,
              loadingMessage: 'Uppdaterar recept...',
            ),
        ],
      ),
    );
  }

  // ✅ BONUS: Helper för att kolla om det är kollaborativt recept
  bool _isCollaborativeRecipe() {
    // För nu returnerar vi false, men här kan du lägga till logik
    // för att kolla om receptet är delat/kollaborativt
    // Du kan till exempel kolla om recipe.sourceUrl innehåller sharing-info
    // eller om det finns metadata som indikerar delning
    return false; // TODO: Implementera check för kollaborativa recept
  }

  // ✅ SOCIAL COMPONENTS: Mock data för demo - ersätt med riktig data senare
  List<UserProfile> _getMockParticipants() {
    return [
      UserProfile(
        uid: 'user1',
        displayName: 'Anna',
        email: 'anna@example.com',
        bio: 'Gillar att baka',
        avatarUrl: null,
        isSearchable: true,
        allowEmailSearch: false,
        publicRecipeCount: 12,
        friendsCount: 8,
        joinedAt: DateTime.now().subtract(const Duration(days: 30)),
        lastActiveAt: DateTime.now().subtract(const Duration(minutes: 5)),
        isOnline: true,
      ),
      UserProfile(
        uid: 'user2',
        displayName: 'Erik',
        email: 'erik@example.com',
        bio: 'Matlagning är min passion',
        avatarUrl: null,
        isSearchable: true,
        allowEmailSearch: false,
        publicRecipeCount: 25,
        friendsCount: 15,
        joinedAt: DateTime.now().subtract(const Duration(days: 60)),
        lastActiveAt: DateTime.now().subtract(const Duration(hours: 2)),
        isOnline: false,
      ),
      UserProfile(
        uid: 'user3',
        displayName: 'Lisa',
        email: 'lisa@example.com',
        bio: 'Hemkock och mamma',
        avatarUrl: null,
        isSearchable: true,
        allowEmailSearch: false,
        publicRecipeCount: 7,
        friendsCount: 12,
        joinedAt: DateTime.now().subtract(const Duration(days: 15)),
        lastActiveAt: DateTime.now().subtract(const Duration(minutes: 30)),
        isOnline: true,
      ),
      // Fler deltagare här...
    ];
  }

  Widget _buildDynamicList({
    required String label,
    required List<TextEditingController> controllers,
    required Function(int, String) onUpdate,
    required VoidCallback onAdd,
    required Function(int) onRemove,
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
                    maxLines: null,
                    keyboardType: TextInputType.multiline,
                    onChanged: (value) => onUpdate(index, value),
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
        if (controllers.isEmpty ||
            (controllers.isNotEmpty && controllers.last.text.isNotEmpty))
          TextButton.icon(
            icon: const Icon(Icons.add),
            label: Text('Lägg till $label'),
            onPressed: onAdd,
          ),
      ],
    );
  }
}
