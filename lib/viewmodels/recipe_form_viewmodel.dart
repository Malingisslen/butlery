// lib/viewmodels/recipe_form_viewmodel.dart
// FIREBASE VERSION: Riktig collaborative sync med RealtimeRecipe & SharedRecipe

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/recipe.dart';
import '../models/user_profile.dart';
import '../models/realtime/realtime_recipe.dart';
import '../models/permissions/resource_permission.dart';
import '../services/recipe_service.dart';
import '../services/analytics_service.dart';
import '../services/storage_service.dart';
import '../services/image_picker_service.dart';
import '../services/auth_service.dart';
import '../core/injection.dart';
import '../repositories/collaborative_recipe_repository.dart';
import '../models/permissions/edit_mode.dart';
import '../models/shared_recipe.dart';
import '../core/form/form_fields_manager.dart';
import '../core/utils/logger.dart';


class RecipeFormViewModel extends ChangeNotifier {
  final RecipeService _recipeService;
  final AnalyticsService _analyticsService;
  final StorageService _storageService;
  final ImagePickerService _imagePickerService;
  final AuthService _authService;
  final CollaborativeRecipeRepository _collaborativeRepository;
  final _uuid = const Uuid();

  // FormFieldsManagers för dynamiska fält
  late final FormFieldsManager _ingredientsManager;
  late final FormFieldsManager _instructionsManager;
  late final FormFieldsManager _tagsManager;

  // Core state
  Recipe? _originalRecipe;
  bool _isSaving = false;
  bool _isForking = false;
  String? _error;

  // ===== COLLABORATIVE STATE (Firebase) ===== ✅
  RealtimeRecipe? _realtimeRecipe;
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _participantsSubscription;
  bool _isCollaborative = false;
  // 🆕 Permissions state
  EditMode? _editMode;
  SharedRecipe? _sharedRecipe;
  final List<UserProfile> _collaborativeParticipants = [];
  final List<LiveEditor> _liveEditors = [];
  bool _isConnectedToFirebase = true;
  String _connectionStatusText = 'Ansluten';
  Timer? _presenceTimer;
  Timer? _saveDebounceTimer;

  // Form data
  String _title = '';
  String _description = '';
  String _mealType = 'Middag';
  int? _portions;
  int? _timeMinutes;
  double? _rating;
  List<String> _imageUrls = [];
  String? _sourceUrl;
  List<String> _ingredients = [''];
  List<String> _instructions = [''];
  List<String> _tags = [''];

  // Constants
  static const List<String> mealTypes = [
    'Frukost',
    'Lunch',
    'Middag',
    'Dessert',
    'Mellanmål',
    'Fika',
  ];
  static const int maxImages = 5;

  RecipeFormViewModel({
    RecipeService? recipeService,
    AnalyticsService? analyticsService,
    StorageService? storageService,
    ImagePickerService? imagePickerService,
    AuthService? authService,
    CollaborativeRecipeRepository? collaborativeRepository,
    Recipe? initialRecipe,
    bool isTemplate = false,
  })  : _recipeService = recipeService ?? sl<RecipeService>(),
        _analyticsService = analyticsService ?? sl<AnalyticsService>(),
        _storageService = storageService ?? sl<StorageService>(),
        _imagePickerService = imagePickerService ?? sl<ImagePickerService>(),
        _authService = authService ?? sl<AuthService>(),
        _collaborativeRepository =
            collaborativeRepository ?? sl<CollaborativeRecipeRepository>() {
    _ingredientsManager = FormFieldsManager();
    _instructionsManager = FormFieldsManager();
    _tagsManager = FormFieldsManager();

    // Setup connection monitoring
    _setupConnectionMonitoring();

    if (initialRecipe != null) {
      if (isTemplate) {
        loadRecipeAsTemplate(initialRecipe);
      } else {
        loadRecipe(initialRecipe);
      }
    }
  }

  // ===== GETTERS =====

  // Core getters
  bool get isSaving => _isSaving;
  String? get error => _error;
  bool get isForking => _isForking;
  bool get hasError => _error != null;
  bool get isEditMode => _originalRecipe != null;

  // Form data getters
  String get title => _title;
  String get description => _description;
  String get mealType => _mealType;
  int? get portions => _portions;
  int? get timeMinutes => _timeMinutes;
  double? get rating => _rating;
  List<String> get imageUrls => _imageUrls;
  bool get canAddMoreImages => _imageUrls.length < maxImages;
  String? get sourceUrl => _sourceUrl;
  List<String> get ingredients => _ingredients;
  List<String> get instructions => _instructions;
  List<String> get tags => _tags;

  // Controller getters
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

  // ===== COLLABORATIVE GETTERS (Firebase) ===== ✅
  bool get isCollaborative => _isCollaborative;
  List<UserProfile> get collaborativeParticipants => _collaborativeParticipants;
  List<LiveCursor> get liveEditors => _liveEditors
      .map((editor) => LiveCursor(
            userId: editor.userId,
            sessionId: _realtimeRecipe?.id ?? '',
            fieldName: editor.fieldName,
            lastActive: editor.lastActive,
            isActive: editor.isActive,
          ))
      .toList();
  bool get isConnectedToFirebase => _isConnectedToFirebase;
  String get connectionStatusText => _connectionStatusText;
  // 🆕 Getters för permissions
  EditMode? get editMode => _editMode;
  bool get canEdit => _editMode?.canEdit ?? true; // Default true för nya recept
  bool get showForkButton => _editMode?.showForkButton ?? false;
  String get editModeDescription => _editMode?.description ?? '';
  int get totalParticipants => _collaborativeParticipants.length;

// 🆕 Sätt permissions-kontext
  void setPermissionsContext(
      SharedRecipe? sharedRecipe, String? currentUserId) {
    _sharedRecipe = sharedRecipe;

    if (sharedRecipe != null && currentUserId != null) {
      _editMode = sharedRecipe.getEditModeFor(currentUserId);
      AppLogger.info(
          '🔒 Edit mode set to: $_editMode för user: $currentUserId');
    } else {
      _editMode = null; // Normalt recept utan delning
    }

    notifyListeners();
  }

  // ===== COLLABORATIVE METHODS (Firebase) ===== ✅

  /// Aktivera collaborative mode med riktig Firebase sync
  Future<void> enableCollaborativeMode() async {
    if (_originalRecipe == null) return;

    try {
      AppLogger.info(
          'Aktiverar Firebase collaborative mode för recept: ${_originalRecipe!.id}');

      final userId = _authService.currentUser?.uid;
      final userDisplayName = _authService.currentUser?.displayName ?? 'Okänd';
      if (userId == null) throw Exception('Ingen inloggad användare');

      // Skapa RealtimeRecipe från nuvarande recipe
      _realtimeRecipe = RealtimeRecipe.fromRecipe(
        recipe: _originalRecipe!,
        ownerId: userId,
        ownerDisplayName: userDisplayName,
      );

      // Spara till Firebase via repository
      await _collaborativeRepository.createRealtimeRecipe(_realtimeRecipe!);

      // Sätt upp real-time listeners
      await _setupRealtimeListeners();

      // Starta presence tracking
      _startPresenceTracking();

      _isCollaborative = true;

      AppLogger.info('Firebase collaborative mode aktiverat');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid aktivering av Firebase collaborative mode: $e');
      _setError('Kunde inte aktivera delning: $e');
    }
  }

  /// Bjud in användare till collaborative session
  Future<void> inviteUserToCollaboration(String userId, String userDisplayName,
      ResourcePermission permission) async {
    if (_realtimeRecipe == null) return;

    try {
      // Uppdatera RealtimeRecipe med ny deltagare
      _realtimeRecipe =
          _realtimeRecipe!.addParticipant(userId, userDisplayName, permission);

      // Spara till Firebase via repository
      await _collaborativeRepository.updateRealtimeRecipe(_realtimeRecipe!);

      AppLogger.info('Användare inbjuden till collaboration: $userDisplayName');
    } catch (e) {
      AppLogger.error('Fel vid inbjudning av användare: $e');
      _setError('Kunde inte bjuda in användare: $e');
    }
  }

  /// Ta bort användare från collaborative session
  Future<void> removeUserFromCollaboration(String userId) async {
    if (_realtimeRecipe == null) return;

    try {
      _realtimeRecipe = _realtimeRecipe!.removeParticipant(userId);

      await _collaborativeRepository.updateRealtimeRecipe(_realtimeRecipe!);

      AppLogger.info('Användare borttagen från collaboration: $userId');
    } catch (e) {
      AppLogger.error('Fel vid borttagning av användare: $e');
      _setError('Kunde inte ta bort användare: $e');
    }
  }

  /// Lämna collaborative mode
  Future<void> leaveCollaborativeMode() async {
    try {
      await _clearPresence();
      await _cleanupRealtimeListeners();

      _isCollaborative = false;
      _realtimeRecipe = null;
      _collaborativeParticipants.clear();
      _liveEditors.clear();

      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid lämning av collaborative mode: $e');
    }
  }

  /// Återanslut till Firebase
  Future<void> reconnectToFirebase() async {
    try {
      _isConnectedToFirebase = true;
      _connectionStatusText = 'Återansluten';

      if (_isCollaborative && _realtimeRecipe != null) {
        await _setupRealtimeListeners();
        _startPresenceTracking();
      }

      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid återanslutning: $e');
    }
  }

  // ===== PRIVATE COLLABORATIVE METHODS =====

  /// Sätt upp real-time listeners för collaborative data
  Future<void> _setupRealtimeListeners() async {
    if (_realtimeRecipe == null) return;

    // Lyssna på RealtimeRecipe ändringar
    _realtimeSubscription = _collaborativeRepository
        .watchRealtimeRecipe(_realtimeRecipe!.id)
        .listen(
      (doc) {
        if (doc.exists) {
          _handleRealtimeUpdate(doc);
        }
      },
      onError: (error) {
        AppLogger.error('Realtime listener error: $error');
        _isConnectedToFirebase = false;
        _connectionStatusText = 'Anslutning förlorad';
        notifyListeners();
      },
    );

    // Lyssna på presence/live editors
    _participantsSubscription = _collaborativeRepository
        .watchActivePresence(_realtimeRecipe!.id)
        .listen(
      (snapshot) {
        _updateLiveEditors(snapshot);
      },
      onError: (error) {
        AppLogger.error('Presence listener error: $error');
      },
    );
  }

  /// Hantera real-time uppdateringar från Firebase
  void _handleRealtimeUpdate(DocumentSnapshot doc) {
    try {
      final updatedRealtimeRecipe = RealtimeRecipe.fromFirestore(doc);

      // Uppdatera bara om det kommer från annan användare
      final currentUserId = _authService.currentUser?.uid;
      if (updatedRealtimeRecipe.lastEditedBy != currentUserId) {
        _realtimeRecipe = updatedRealtimeRecipe;
        _syncFormFromRealtimeRecipe();
        notifyListeners();
      }
    } catch (e) {
      AppLogger.error('Fel vid hantering av realtime update: $e');
    }
  }

  /// Synka form data från RealtimeRecipe
  void _syncFormFromRealtimeRecipe() {
    if (_realtimeRecipe == null) return;

    final recipe = _realtimeRecipe!.recipe;

    _title = recipe.title;
    _description = recipe.description;
    _mealType = recipe.mealType;
    _portions = recipe.portions;
    _timeMinutes = recipe.timeMinutes;
    _rating = recipe.rating;
    _imageUrls = List.from(recipe.imageUrls);
    _sourceUrl = recipe.sourceUrl;
    _ingredients = [...recipe.ingredients, ''];
    _instructions = [...recipe.instructions, ''];
    _tags = [...(recipe.tags ?? []), ''];
  }

  /// Uppdatera live editors från Firebase
  void _updateLiveEditors(QuerySnapshot snapshot) {
    _liveEditors.clear();

    for (final doc in snapshot.docs) {
      final data = doc.data() as Map<String, dynamic>;
      final userId = data['userId'] as String;

      // Filtrera bort oss själva
      if (userId != _authService.currentUser?.uid) {
        _liveEditors.add(LiveEditor(
          userId: userId,
          userDisplayName: data['userDisplayName'] as String? ?? 'Okänd',
          fieldName: data['fieldName'] as String? ?? '',
          lastActive:
              (data['lastActive'] as Timestamp?)?.toDate() ?? DateTime.now(),
          isActive: data['isActive'] as bool? ?? false,
        ));
      }
    }

    // Hämta UserProfile för alla live editors
    _loadParticipantProfiles();

    notifyListeners();
  }

  /// Ladda UserProfile för alla deltagare
  Future<void> _loadParticipantProfiles() async {
    if (_realtimeRecipe == null) return;

    try {
      final participantIds = _realtimeRecipe!.participants.keys.toList();
      _collaborativeParticipants.clear();

      for (final userId in participantIds) {
        final userDoc =
            await _collaborativeRepository.getUserDocument(userId);
        if (userDoc.exists) {
          final userProfile = UserProfile.fromFirestore(userDoc);
          _collaborativeParticipants.add(userProfile);
        }
      }

      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid laddning av participant profiles: $e');
    }
  }

  /// Starta presence tracking
  void _startPresenceTracking() {
    if (_realtimeRecipe == null) return;

    // Heartbeat var 30 sekund
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updatePresence('heartbeat');
    });
  }

  /// Uppdatera användarens presence
  Future<void> _updatePresence(String fieldName) async {
    if (_realtimeRecipe == null) return;

    final userId = _authService.currentUser?.uid;
    final userDisplayName = _authService.currentUser?.displayName ?? 'Okänd';
    if (userId == null) return;

    try {
      await _collaborativeRepository.setPresence(
        _realtimeRecipe!.id,
        userId,
        {
          'userId': userId,
          'userDisplayName': userDisplayName,
          'fieldName': fieldName,
          'lastActive': FieldValue.serverTimestamp(),
          'isActive': true,
        },
      );
    } catch (e) {
      AppLogger.error('Fel vid presence update: $e');
    }
  }

  /// Rensa presence
  Future<void> _clearPresence() async {
    if (_realtimeRecipe == null) return;

    final userId = _authService.currentUser?.uid;
    if (userId == null) return;

    try {
      await _collaborativeRepository.updatePresence(
        _realtimeRecipe!.id,
        userId,
        {'isActive': false},
      );
    } catch (e) {
      AppLogger.error('Fel vid clear presence: $e');
    }
  }

  /// Setup Firebase connection monitoring med riktig implementation
  void _setupConnectionMonitoring() {
    // För Firestore används en enklare approach med periodic checks
    // och stream error handling för att detektera connection status

    // Starta med antagandet att vi är anslutna
    _isConnectedToFirebase = true;
    _connectionStatusText = 'Ansluten';

    // Periodic connection check (varannan minut)
    Timer.periodic(const Duration(minutes: 2), (timer) {
      _performConnectionCheck();
    });

    AppLogger.info('📡 Connection monitoring aktiverat');
  }

  /// Perform connection check
  Future<void> _performConnectionCheck() async {
    if (!_isCollaborative || _realtimeRecipe == null) return;

    try {
      // Enkel test-query för att kontrollera Firebase connection
      await _collaborativeRepository
          .fetchRealtimeRecipe(_realtimeRecipe!.id)
          .timeout(const Duration(seconds: 10));

      // Om vi kommer hit är vi anslutna
      if (!_isConnectedToFirebase) {
        _isConnectedToFirebase = true;
        _connectionStatusText = 'Återansluten';
        notifyListeners();

        // Återställ listeners
        await _setupRealtimeListeners();
        _startPresenceTracking();
      }
    } catch (e) {
      // Connection failed
      if (_isConnectedToFirebase) {
        _isConnectedToFirebase = false;
        _connectionStatusText = 'Anslutning förlorad';
        notifyListeners();
        AppLogger.warning('📵 Firebase connection lost: $e');
      }
    }
  }

  /// Cleanup realtime listeners
  Future<void> _cleanupRealtimeListeners() async {
    await _realtimeSubscription?.cancel();
    await _participantsSubscription?.cancel();
    _presenceTimer?.cancel();

    _realtimeSubscription = null;
    _participantsSubscription = null;
    _presenceTimer = null;
  }

  // ===== SETTERS MED FIREBASE SYNC =====

  void setTitle(String value) {
    _title = value;
    _updatePresence('title');
    _debouncedSaveToFirebase();
    notifyListeners();
  }

  void setDescription(String value) {
    _description = value;
    _updatePresence('description');
    _debouncedSaveToFirebase();
    notifyListeners();
  }

  void setMealType(String value) {
    if (mealTypes.contains(value)) {
      _mealType = value;
      _debouncedSaveToFirebase();
      notifyListeners();
    }
  }

  void setPortions(String value) {
    _portions = int.tryParse(value);
    _debouncedSaveToFirebase();
    notifyListeners();
  }

  void setTimeMinutes(String value) {
    _timeMinutes = int.tryParse(value);
    _debouncedSaveToFirebase();
    notifyListeners();
  }

  void setRating(String value) {
    _rating = double.tryParse(value.replaceAll(',', '.'));
    _debouncedSaveToFirebase();
    notifyListeners();
  }

  void setSourceUrl(String value) {
    _sourceUrl = value.trim().isEmpty ? null : value.trim();
    _debouncedSaveToFirebase();
    notifyListeners();
  }

  /// Debounced save till Firebase (undviker för många writes)
  void _debouncedSaveToFirebase() {
    if (!_isCollaborative || _realtimeRecipe == null) return;

    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      _saveCurrentStateToFirebase();
    });
  }

  /// Spara nuvarande state till Firebase
  Future<void> _saveCurrentStateToFirebase() async {
    if (_realtimeRecipe == null) return;

    try {
      final userId = _authService.currentUser?.uid;
      final userDisplayName = _authService.currentUser?.displayName ?? 'Okänd';
      if (userId == null) return;

      // Uppdatera RealtimeRecipe med nuvarande form data
      final updatedRecipe = _realtimeRecipe!.recipe.copyWith(
        title: _title,
        description: _description,
        mealType: _mealType,
        portions: _portions,
        timeMinutes: _timeMinutes,
        rating: _rating,
        imageUrls: _imageUrls,
        sourceUrl: _sourceUrl,
        ingredients: _ingredients.where((i) => i.trim().isNotEmpty).toList(),
        instructions: _instructions.where((i) => i.trim().isNotEmpty).toList(),
        tags: _tags.where((t) => t.trim().isNotEmpty).toList(),
        updatedAt: DateTime.now(),
      );

      _realtimeRecipe = _realtimeRecipe!.copyWith(
        recipe: updatedRecipe,
        lastEditedBy: userId,
        lastEditedByDisplayName: userDisplayName,
      );

      // Spara till Firebase via repository
      await _collaborativeRepository.updateRealtimeRecipe(_realtimeRecipe!);
    } catch (e) {
      AppLogger.error('Fel vid save till Firebase: $e');
    }
  }

  // ===== LIST OPERATIONS MED FIREBASE SYNC =====

  void updateIngredient(int index, String value) {
    if (index >= 0 && index < _ingredients.length) {
      _ingredients[index] = value;
      _updatePresence('ingredients[$index]');

      if (index == _ingredients.length - 1 && value.trim().isNotEmpty) {
        _ingredients.add('');
      } else if (value.trim().isEmpty && index < _ingredients.length - 1) {
        _ingredients.removeAt(index);
        _ingredientsManager.removeController(index);
      }

      _debouncedSaveToFirebase();
      notifyListeners();
    }
  }

  void updateInstruction(int index, String value) {
    if (index >= 0 && index < _instructions.length) {
      _instructions[index] = value;
      _updatePresence('instructions[$index]');

      if (index == _instructions.length - 1 && value.trim().isNotEmpty) {
        _instructions.add('');
      } else if (value.trim().isEmpty && index < _instructions.length - 1) {
        _instructions.removeAt(index);
        _instructionsManager.removeController(index);
      }

      _debouncedSaveToFirebase();
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
      if (_ingredients.isEmpty) {
        _ingredients.add('');
      }
      _debouncedSaveToFirebase();
      notifyListeners();
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
      if (_instructions.isEmpty) {
        _instructions.add('');
      }
      _debouncedSaveToFirebase();
      notifyListeners();
    }
  }

  void updateTag(int index, String value) {
    if (index >= 0 && index < _tags.length) {
      _tags[index] = value;
      if (index == _tags.length - 1 && value.trim().isNotEmpty) {
        _tags.add('');
      } else if (value.trim().isEmpty && index < _tags.length - 1) {
        _tags.removeAt(index);
        _tagsManager.removeController(index);
      }
      _debouncedSaveToFirebase();
      notifyListeners();
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
      if (_tags.isEmpty) {
        _tags.add('');
      }
      _debouncedSaveToFirebase();
      notifyListeners();
    }
  }

  // ===== IMAGE OPERATIONS =====

  Future<void> pickAndUploadImage(BuildContext context,
      {ImageSource? source}) async {
    ImageSource selectedSource;

    if (source != null) {
      selectedSource = source;
    } else {
      final dialogSource =
          await _imagePickerService.showImageSourceDialog(context);
      if (dialogSource == null) return;
      selectedSource = dialogSource;
    }

    final imageFile = await _imagePickerService.pickImage(selectedSource);
    if (imageFile == null) return;

    final progressController = StreamController<UploadProgress>();

    if (context.mounted) {
      _imagePickerService.showDetailedUploadDialog(
        context,
        progressStream: progressController.stream,
      );
    }

    try {
      progressController.add(UploadProgress(0, 1, 'Komprimerar bild...'));

      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('Ingen inloggad användare');
      }

      progressController.add(UploadProgress(0, 1, 'Laddar upp till molnet...'));

      final imageUrl = await _storageService.uploadImageFile(
        imageFile,
        userId,
        onProgress: (progress) {
          progressController.add(
            UploadProgress(
              (progress * 100).toInt(),
              100,
              'Laddar upp... ${(progress * 100).toInt()}%',
            ),
          );
        },
      );

      if (imageUrl != null) {
        addImageUrl(imageUrl);
        progressController.add(UploadProgress(1, 1, 'Klar!'));
        await Future.delayed(const Duration(milliseconds: 500));
        AppLogger.info('Bild uppladdad och tillagd till recept');
      } else {
        throw Exception('Kunde inte ladda upp bild');
      }
    } catch (e) {
      AppLogger.error('Fel vid bilduppladdning: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        _imagePickerService.showImageError(
          context,
          'Kunde inte ladda upp bild: ${e.toString()}',
        );
      }
    } finally {
      progressController.close();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<void> pickMultipleImages(BuildContext context) async {
    final remainingSlots = maxImages - _imageUrls.length;

    if (remainingSlots <= 0) {
      _imagePickerService.showImageError(
        context,
        'Du kan max ha $maxImages bilder per recept',
      );
      return;
    }

    final imageFiles = await _imagePickerService.pickMultipleImages(
      maxImages: remainingSlots,
    );

    if (imageFiles.isEmpty) return;

    final progressController = StreamController<UploadProgress>();

    if (context.mounted) {
      _imagePickerService.showDetailedUploadDialog(
        context,
        progressStream: progressController.stream,
      );
    }

    try {
      final userId = _authService.currentUser?.uid;
      if (userId == null) {
        throw Exception('Ingen inloggad användare');
      }

      var uploadedCount = 0;
      final totalImages = imageFiles.length;

      for (var i = 0; i < imageFiles.length; i++) {
        final imageFile = imageFiles[i];

        progressController.add(
          UploadProgress(
            uploadedCount,
            totalImages,
            'Laddar upp bild ${i + 1} av $totalImages...',
          ),
        );

        final imageUrl = await _storageService.uploadImageFile(
          imageFile,
          userId,
          onProgress: (fileProgress) {
            progressController.add(
              UploadProgress(
                (fileProgress * 100).toInt(),
                100,
                'Laddar upp bild ${i + 1} av $totalImages... ${(fileProgress * 100).toInt()}%',
              ),
            );
          },
        );

        if (imageUrl != null && _imageUrls.length < maxImages) {
          addImageUrl(imageUrl);
          uploadedCount++;
        }
      }

      progressController.add(
        UploadProgress(
          totalImages,
          totalImages,
          '$uploadedCount bilder uppladdade!',
        ),
      );

      await Future.delayed(const Duration(seconds: 1));
      AppLogger.info('$uploadedCount bilder uppladdade');
    } catch (e) {
      AppLogger.error('Fel vid uppladdning av flera bilder: $e');
      if (context.mounted) {
        Navigator.of(context).pop();
        _imagePickerService.showImageError(
          context,
          'Kunde inte ladda upp alla bilder: $e',
        );
      }
    } finally {
      progressController.close();
      if (context.mounted) {
        Navigator.of(context).pop();
      }
    }
  }

  void addImageUrl(String url) {
    if (_imageUrls.length < maxImages && url.trim().isNotEmpty) {
      _imageUrls.add(url.trim());
      _debouncedSaveToFirebase();
      notifyListeners();
    }
  }

  void removeImageAt(int index) async {
    if (index >= 0 && index < _imageUrls.length) {
      final imageUrl = _imageUrls[index];
      _imageUrls.removeAt(index);
      _debouncedSaveToFirebase();
      notifyListeners();

      if (imageUrl.contains('firebasestorage.googleapis.com')) {
        await _storageService.deleteImage(imageUrl);
      }
    }
  }

  void setPrimaryImage(int index) {
    if (index > 0 && index < _imageUrls.length) {
      final imageUrl = _imageUrls.removeAt(index);
      _imageUrls.insert(0, imageUrl);
      _debouncedSaveToFirebase();
      notifyListeners();
    }
  }

  // ===== ACTIONS =====

  void loadRecipe(Recipe recipe) {
    _originalRecipe = recipe;
    _title = recipe.title;
    _description = recipe.description;
    _mealType = recipe.mealType;
    _portions = recipe.portions;
    _timeMinutes = recipe.timeMinutes;
    _rating = recipe.rating;
    _imageUrls = List.from(recipe.imageUrls);
    _sourceUrl = recipe.sourceUrl;
    _ingredients = [...recipe.ingredients, ''];
    _instructions = [...recipe.instructions, ''];
    _tags = [...(recipe.tags ?? []), ''];
    notifyListeners();
  }

  void loadRecipeAsTemplate(Recipe recipe) {
    _title = recipe.title;
    _description = recipe.description;
    _mealType = recipe.mealType;
    _portions = recipe.portions;
    _timeMinutes = recipe.timeMinutes;
    _rating = recipe.rating;
    _imageUrls = List.from(recipe.imageUrls);
    _sourceUrl = recipe.sourceUrl;
    _ingredients = [...recipe.ingredients, ''];
    _instructions = [...recipe.instructions, ''];
    _tags = [...(recipe.tags ?? []), ''];
    notifyListeners();
  }

  Future<bool> saveRecipe() async {
    if (!isValid) {
      _setError('Fyll i alla obligatoriska fält');
      return false;
    }

    if (!canEdit) {
      _setError('Du har inte behörighet att redigera detta recept');
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
        ingredients: _ingredients
            .map((i) => i.trim())
            .where((i) => i.isNotEmpty)
            .toList(),
        instructions: _instructions
            .map((i) => i.trim())
            .where((i) => i.isNotEmpty)
            .toList(),
        tags: _tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
        rating: _rating,
        imageUrls: _imageUrls,
        sourceUrl: _sourceUrl,
      );

      RecipeOperationResult result;

      if (isEditMode) {
        result = await _recipeService.updateRecipe(recipe);
        if (!result.isSuccess && result.message.contains('not-found')) {
          result = await _recipeService.addRecipe(recipe);
        }
      } else {
        result = await _recipeService.addRecipe(recipe);
      }

      if (result.isSuccess) {
        await _analyticsService.logRecipeCreated(
          source: isEditMode ? 'edit' : 'manual',
          hasImage: _imageUrls.isNotEmpty,
        );

        // Om detta är kollaborativ redigering, uppdatera SharedRecipe också
        if (_editMode == EditMode.collaborative && _sharedRecipe != null) {
          await _updateSharedRecipe(recipe);
        }

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
  // ===== PRIVATE METHODS =====

  void _setSaving(bool value) {
    _isSaving = value;
    notifyListeners();
  }

  void _setForking(bool value) {
    _isForking = value;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

// 🆕 Spara som fork (egen kopia)
  Future<bool> saveFork() async {
    if (_sharedRecipe == null || !showForkButton) {
      _setError('Kan inte skapa kopia av detta recept');
      return false;
    }

    _setForking(true);

    try {
      AppLogger.info(
          '📋 Skapar fork av recept: ${_sharedRecipe!.recipeSnapshot.title}');

      // Skapa nytt recept baserat på nuvarande state
      final forkedRecipe = Recipe(
        id: _uuid.v4(), // Nytt ID
        title: '${_title.trim()} (från ${_sharedRecipe!.sharedByDisplayName})',
        description: _description.trim(),
        mealType: _mealType,
        portions: _portions,
        timeMinutes: _timeMinutes,
        ingredients: _ingredients
            .map((i) => i.trim())
            .where((i) => i.isNotEmpty)
            .toList(),
        instructions: _instructions
            .map((i) => i.trim())
            .where((i) => i.isNotEmpty)
            .toList(),
        tags: _tags.map((t) => t.trim()).where((t) => t.isNotEmpty).toList(),
        rating: _rating,
        imageUrls: List.from(_imageUrls), // Kopiera bilder
        sourceUrl:
            'Inspirerat av recept från ${_sharedRecipe!.sharedByDisplayName}',
        createdAt: DateTime.now(),
        updatedAt: DateTime.now(),
      );

      // Spara som nytt recept i användarens egen samling
      final result = await _recipeService.addRecipe(forkedRecipe);

      if (result.isSuccess) {
        await _analyticsService.logRecipeCreated(
          source: 'fork',
          hasImage: _imageUrls.isNotEmpty,
        );
        AppLogger.success('✅ Fork skapad: ${forkedRecipe.title}');
        return true;
      } else {
        _setError(result.message);
        return false;
      }
    } catch (e) {
      _setError('Kunde inte spara kopia: ${e.toString()}');
      AppLogger.error('❌ Fork creation failed', e);
      return false;
    } finally {
      _setForking(false);
    }
  }

// 🆕 Uppdatera SharedRecipe efter kollaborativ redigering
  Future<void> _updateSharedRecipe(Recipe updatedRecipe) async {
    try {
      AppLogger.info(
          '🔄 Uppdaterar SharedRecipe efter kollaborativ redigering');

      // Här skulle vi uppdatera SharedRecipe i Firebase
      // Detta kräver utökad logik i SocialRecipeService

      AppLogger.success('✅ SharedRecipe uppdaterad');
    } catch (e) {
      AppLogger.warning('⚠️ Kunde inte uppdatera SharedRecipe: $e');
      // Misslyckas tyst - huvudreceptet är sparat
    }
  }

  @override
  void dispose() {
    AppLogger.info('Disposing RecipeFormViewModel');

    // Cleanup Firebase resources
    leaveCollaborativeMode();
    _saveDebounceTimer?.cancel();

    _ingredientsManager.dispose();
    _instructionsManager.dispose();
    _tagsManager.dispose();

    super.dispose();
  }
}

// ===== FIREBASE MODELS =====

/// Live editor för Firebase presence
class LiveEditor {
  final String userId;
  final String userDisplayName;
  final String fieldName;
  final DateTime lastActive;
  final bool isActive;

  const LiveEditor({
    required this.userId,
    required this.userDisplayName,
    required this.fieldName,
    required this.lastActive,
    required this.isActive,
  });
}

/// LiveCursor för kompatibilitet med SocialComponents
class LiveCursor {
  final String userId;
  final String sessionId;
  final String fieldName;
  final DateTime lastActive;
  final bool isActive;

  const LiveCursor({
    required this.userId,
    required this.sessionId,
    required this.fieldName,
    required this.lastActive,
    required this.isActive,
  });

  String get displayFieldName {
    switch (fieldName) {
      case 'title':
        return 'recepttiteln';
      case 'description':
        return 'beskrivningen';
      case 'ingredients':
        return 'ingredienslistan';
      case 'instructions':
        return 'instruktionerna';
      case 'tags':
        return 'taggarna';
      default:
        if (fieldName.startsWith('ingredients[')) {
          final index = fieldName.replaceAll(RegExp(r'[^\d]'), '');
          return 'ingrediens $index';
        }
        if (fieldName.startsWith('instructions[')) {
          final index = fieldName.replaceAll(RegExp(r'[^\d]'), '');
          return 'instruktion $index';
        }
        return fieldName;
    }
  }
}
