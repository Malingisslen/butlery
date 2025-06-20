// lib/viewmodels/recipe_form_viewmodel.dart
// REFAKTORERAD: Nu hanterar ViewModel alla TextEditingControllers via FormFieldsManager
// UPPDATERAD: Stöd för flera bilder per recept med kamera/galleri

import 'package:flutter/material.dart'; // För TextEditingController
import 'package:uuid/uuid.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../services/image_picker_service.dart';
import '../services/auth_service.dart';
import '../core/injection.dart';
import '../core/form/form_fields_manager.dart';
import '../core/utils/logger.dart';

/// ViewModel för recept-formulär (skapa/redigera)
/// Nu med fullständig controller-hantering enligt MVVM
/// OCH stöd för flera bilder med kamera/galleri!
class RecipeFormViewModel extends ChangeNotifier {
  final RecipeService _recipeService;
  final AnalyticsService _analyticsService;
  final StorageService _storageService;
  final ImagePickerService _imagePickerService;
  final AuthService _authService;
  final _uuid = const Uuid();

  // FormFieldsManagers för dynamiska fält
  late final FormFieldsManager _ingredientsManager;
  late final FormFieldsManager _instructionsManager;
  late final FormFieldsManager _tagsManager;

  // State
  Recipe? _originalRecipe;
  bool _isSaving = false;
  String? _error;

  // Form data
  String _title = '';
  String _description = '';
  String _mealType = 'Middag';
  int? _portions;
  int? _timeMinutes;
  double? _rating;
  List<String> _imageUrls = []; // NY! Ersätter imageUrl
  String? _sourceUrl;
  List<String> _ingredients = [''];
  List<String> _instructions = [''];
  List<String> _tags = [''];

  // Tillgängliga måltidstyper
  static const List<String> mealTypes = [
    'Frukost',
    'Lunch',
    'Middag',
    'Dessert',
    'Mellanmål',
    'Fika',
  ];

  // NY! Max antal bilder
  static const int maxImages = 5;

  RecipeFormViewModel({
    RecipeService? recipeService,
    AnalyticsService? analyticsService,
    StorageService? storageService,
    ImagePickerService? imagePickerService,
    AuthService? authService,
    Recipe? initialRecipe,
    bool isTemplate = false,
  }) : _recipeService = recipeService ?? sl<RecipeService>(),
       _analyticsService = analyticsService ?? sl<AnalyticsService>(),
       _storageService = storageService ?? sl<StorageService>(),
       _imagePickerService = imagePickerService ?? sl<ImagePickerService>(),
       _authService = authService ?? sl<AuthService>() {
    // Initiera FormFieldsManagers UTAN callbacks - håll det enkelt!
    _ingredientsManager = FormFieldsManager();
    _instructionsManager = FormFieldsManager();
    _tagsManager = FormFieldsManager();

    // Ladda initial data om det finns
    if (initialRecipe != null) {
      if (isTemplate) {
        loadRecipeAsTemplate(initialRecipe);
      } else {
        loadRecipe(initialRecipe);
      }
    }
  }

  // ===== GETTERS =====

  bool get isSaving => _isSaving;
  String? get error => _error;
  bool get hasError => _error != null;
  bool get isEditMode => _originalRecipe != null;

  String get title => _title;
  String get description => _description;
  String get mealType => _mealType;
  int? get portions => _portions;
  int? get timeMinutes => _timeMinutes;
  double? get rating => _rating;
  List<String> get imageUrls => _imageUrls; // NY!
  bool get canAddMoreImages => _imageUrls.length < maxImages; // NY!
  String? get sourceUrl => _sourceUrl;
  List<String> get ingredients => _ingredients;
  List<String> get instructions => _instructions;
  List<String> get tags => _tags;

  // Controller getters för Views
  List<TextEditingController> get ingredientControllers =>
      _ingredientsManager.getControllers(_ingredients);

  List<TextEditingController> get instructionControllers =>
      _instructionsManager.getControllers(_instructions);

  List<TextEditingController> get tagControllers =>
      _tagsManager.getControllers(_tags);

  // Validation
  bool get isValid =>
      _title.trim().isNotEmpty &&
      _ingredients.any((i) => i.trim().isNotEmpty) &&
      _instructions.any((i) => i.trim().isNotEmpty);

  // ===== SETTERS =====

  void setTitle(String value) {
    _title = value;
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
    notifyListeners();
  }

  void setMealType(String value) {
    if (mealTypes.contains(value)) {
      _mealType = value;
      notifyListeners();
    }
  }

  void setPortions(String value) {
    _portions = int.tryParse(value);
    notifyListeners();
  }

  void setTimeMinutes(String value) {
    _timeMinutes = int.tryParse(value);
    notifyListeners();
  }

  void setRating(String value) {
    _rating = double.tryParse(value.replaceAll(',', '.'));
    notifyListeners();
  }

  void setSourceUrl(String value) {
    _sourceUrl = value.trim().isEmpty ? null : value.trim();
    notifyListeners();
  }

  // ===== IMAGE OPERATIONS - UPPDATERADE! =====

  /// Välj och ladda upp bild från kamera eller galleri
  Future<void> pickAndUploadImage(BuildContext context) async {
    // Visa dialog för att välja källa
    final source = await _imagePickerService.showImageSourceDialog(context);
    if (source == null) return;

    // Välj bild
    final imageFile = await _imagePickerService.pickImage(source);
    if (imageFile == null) return;

    // Visa laddningsindikator
    if (context.mounted) {
      _imagePickerService.showUploadingDialog(context);
    }

    try {
      // Hämta användar-ID
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('Ingen inloggad användare');
      }

      // Ladda upp bild till Firebase Storage
      final imageUrl = await _storageService.uploadImageFile(imageFile, userId);

      if (imageUrl != null) {
        // Lägg till URL i listan
        addImageUrl(imageUrl);

        AppLogger.info('Bild uppladdad och tillagd till recept');
      } else {
        throw Exception('Kunde inte ladda upp bild');
      }
    } catch (e) {
      AppLogger.error('Fel vid bilduppladdning: $e');
      if (context.mounted) {
        _imagePickerService.showImageError(
          context,
          'Kunde inte ladda upp bild: ${e.toString()}',
        );
      }
    } finally {
      // Stäng laddningsdialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  /// Välj flera bilder från galleri
  Future<void> pickMultipleImages(BuildContext context) async {
    // Beräkna hur många bilder som kan läggas till
    final remainingSlots = maxImages - _imageUrls.length;
    if (remainingSlots <= 0) {
      _imagePickerService.showImageError(
        context,
        'Du kan max ha $maxImages bilder per recept',
      );
      return;
    }

    // Välj flera bilder
    final imageFiles = await _imagePickerService.pickMultipleImages(
      maxImages: remainingSlots,
    );

    if (imageFiles.isEmpty) return;

    // Visa laddningsindikator
    if (context.mounted) {
      _imagePickerService.showUploadingDialog(
        context,
        message: 'Laddar upp ${imageFiles.length} bilder...',
      );
    }

    try {
      // Hämta användar-ID
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('Ingen inloggad användare');
      }

      // Ladda upp alla bilder
      final uploadedUrls = await _storageService.uploadMultipleImages(
        imageFiles,
        userId,
        onProgress: (completed, total) {
          // TODO: Uppdatera progress i dialog om vi vill
        },
      );

      // Lägg till alla URL:er
      for (final url in uploadedUrls) {
        if (_imageUrls.length < maxImages) {
          addImageUrl(url);
        }
      }

      AppLogger.info('${uploadedUrls.length} bilder uppladdade');
    } catch (e) {
      AppLogger.error('Fel vid uppladdning av flera bilder: $e');
      if (context.mounted) {
        _imagePickerService.showImageError(
          context,
          'Kunde inte ladda upp alla bilder',
        );
      }
    } finally {
      // Stäng laddningsdialog
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  /// Lägg till bild från URL (behåll för bakåtkompatibilitet)
  void addImageUrl(String url) {
    if (_imageUrls.length < maxImages && url.trim().isNotEmpty) {
      _imageUrls.add(url.trim());
      notifyListeners();

      AppLogger.info('Bild tillagd. Totalt ${_imageUrls.length} bilder.');
    }
  }

  /// Ta bort bild vid index (uppdaterad för att ta bort från Storage också)
  void removeImageAt(int index) async {
    if (index >= 0 && index < _imageUrls.length) {
      final imageUrl = _imageUrls[index];

      // Ta bort från listan först
      _imageUrls.removeAt(index);
      notifyListeners();

      // Om det är en Firebase Storage URL, ta bort från Storage också
      if (imageUrl.contains('firebasestorage.googleapis.com')) {
        await _storageService.deleteImage(imageUrl);
      }

      AppLogger.info('Bild borttagen. ${_imageUrls.length} bilder kvar.');
    }
  }

  /// Flytta bild (för att ändra ordning)
  void reorderImage(int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }
    final imageUrl = _imageUrls.removeAt(oldIndex);
    _imageUrls.insert(newIndex, imageUrl);
    notifyListeners();

    AppLogger.info('Bild flyttad från position $oldIndex till $newIndex');
  }

  /// Sätt primärbild (flytta till första positionen)
  void setPrimaryImage(int index) {
    if (index > 0 && index < _imageUrls.length) {
      final imageUrl = _imageUrls.removeAt(index);
      _imageUrls.insert(0, imageUrl);
      notifyListeners();

      AppLogger.info('Bild vid index $index satt som primärbild');
    }
  }

  // ===== LIST OPERATIONS - REFAKTORERADE =====

  void updateIngredient(int index, String value) {
    if (index >= 0 && index < _ingredients.length) {
      _ingredients[index] = value;

      // Auto-add ny rad om sista fältet fylls i
      if (index == _ingredients.length - 1 && value.trim().isNotEmpty) {
        _ingredients.add('');
      }
      // Ta bort tomma rader (utom sista)
      else if (value.trim().isEmpty && index < _ingredients.length - 1) {
        _ingredients.removeAt(index);
        _ingredientsManager.removeController(index);
      }

      notifyListeners();
    }
  }

  void addIngredient() {
    _ingredients.add('');
    _ingredientsManager.addController();
    notifyListeners();
  }

  void removeIngredient(int index) {
    if (_ingredients.length > 1 && index >= 0 && index < _ingredients.length) {
      _ingredients.removeAt(index);
      _ingredientsManager.removeController(index);
      // Säkerställ att vi alltid har minst ett tomt fält
      if (_ingredients.isEmpty) {
        _ingredients.add('');
      }
      notifyListeners();
    }
  }

  void updateInstruction(int index, String value) {
    if (index >= 0 && index < _instructions.length) {
      _instructions[index] = value;
      // Behövs inte här eftersom FormFieldsManager hanterar detta via callback
    }
  }

  void addInstruction() {
    _instructions.add('');
    notifyListeners();
  }

  void removeInstruction(int index) {
    if (_instructions.length > 1 &&
        index >= 0 &&
        index < _instructions.length) {
      _instructions.removeAt(index);
      _instructionsManager.removeController(index);
      // Säkerställ att vi alltid har minst ett tomt fält
      if (_instructions.isEmpty) {
        _instructions.add('');
      }
      notifyListeners();
    }
  }

  void updateTag(int index, String value) {
    if (index >= 0 && index < _tags.length) {
      _tags[index] = value;
      // Behövs inte här eftersom FormFieldsManager hanterar detta via callback
    }
  }

  void addTag() {
    _tags.add('');
    notifyListeners();
  }

  void removeTag(int index) {
    if (_tags.length > 1 && index >= 0 && index < _tags.length) {
      _tags.removeAt(index);
      _tagsManager.removeController(index);
      // Säkerställ att vi alltid har minst ett tomt fält
      if (_tags.isEmpty) {
        _tags.add('');
      }
      notifyListeners();
    }
  }

  // ===== ACTIONS =====

  /// Ladda recept för redigering
  void loadRecipe(Recipe recipe) {
    _originalRecipe = recipe;
    _title = recipe.title;
    _description = recipe.description;
    _mealType = recipe.mealType;
    _portions = recipe.portions;
    _timeMinutes = recipe.timeMinutes;
    _rating = recipe.rating;
    _imageUrls = List.from(recipe.imageUrls); // NY! Kopia av bildlistan
    _sourceUrl = recipe.sourceUrl;
    _ingredients = [...recipe.ingredients, ''];
    _instructions = [...recipe.instructions, ''];
    _tags = [...(recipe.tags ?? []), ''];
    notifyListeners();
  }

  /// Ladda recept som template (för import/parse)
  void loadRecipeAsTemplate(Recipe recipe) {
    // Sätt INTE _originalRecipe - detta håller isEditMode = false
    _title = recipe.title;
    _description = recipe.description;
    _mealType = recipe.mealType;
    _portions = recipe.portions;
    _timeMinutes = recipe.timeMinutes;
    _rating = recipe.rating;
    _imageUrls = List.from(recipe.imageUrls); // NY!
    _sourceUrl = recipe.sourceUrl;
    _ingredients = [...recipe.ingredients, ''];
    _instructions = [...recipe.instructions, ''];
    _tags = [...(recipe.tags ?? []), ''];
    notifyListeners();
  }

  /// Spara recept
  Future<bool> saveRecipe() async {
    if (!isValid) {
      _setError('Fyll i alla obligatoriska fält');
      return false;
    }

    _setSaving(true);

    try {
      final recipe = Recipe(
        id: _originalRecipe?.id ?? _uuid.v4(),
        title: _title.trim(),
        description: _description.trim(),
        mealType: _mealType,
        portions: _portions,
        timeMinutes: _timeMinutes,
        ingredients:
            _ingredients
                .map((i) => i.trim())
                .where((i) => i.isNotEmpty)
                .toList(),
        instructions:
            _instructions
                .map((i) => i.trim())
                .where((i) => i.isNotEmpty)
                .toList(),
        tags: _tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
        rating: _rating,
        imageUrls: _imageUrls, // NY!
        sourceUrl: _sourceUrl,
      );

      RecipeOperationResult result;

      if (isEditMode) {
        // Försök först uppdatera
        result = await _recipeService.updateRecipe(recipe);

        // Om receptet inte finns, skapa det istället
        if (!result.isSuccess && result.message.contains('not-found')) {
          debugPrint('Recipe not found in Firestore, creating new one instead');
          result = await _recipeService.addRecipe(recipe);
        }
      } else {
        result = await _recipeService.addRecipe(recipe);
      }

      if (result.isSuccess) {
        // Analytics för antal bilder
        await _analyticsService.logRecipeCreated(
          source: isEditMode ? 'edit' : 'manual',
          hasImage: _imageUrls.isNotEmpty,
        );

        _error = null;
        return true;
      } else {
        _setError(result.message);
        return false;
      }
    } catch (e) {
      _setError('Kunde inte spara recept: ${e.toString()}');
      return false;
    } finally {
      _setSaving(false);
    }
  }

  /// Rensa fel
  void clearError() {
    _error = null;
    notifyListeners();
  }

  /// Återställ formulär
  void reset() {
    _originalRecipe = null;
    _title = '';
    _description = '';
    _mealType = 'Middag';
    _portions = null;
    _timeMinutes = null;
    _rating = null;
    _imageUrls = []; // NY!
    _sourceUrl = null;
    _ingredients = [''];
    _instructions = [''];
    _tags = [''];
    _error = null;

    // Återställ managers
    _ingredientsManager.reset();
    _instructionsManager.reset();
    _tagsManager.reset();

    notifyListeners();
  }

  // ===== PRIVATE METHODS =====

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  // Dispose-metod för att rensa upp FormFieldsManagers
  @override
  void dispose() {
    _ingredientsManager.dispose();
    _instructionsManager.dispose();
    _tagsManager.dispose();
    super.dispose();
  }
}
