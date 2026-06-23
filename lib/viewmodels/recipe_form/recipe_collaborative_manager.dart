// lib/viewmodels/recipe_form/recipe_collaborative_manager.dart

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:butlery/services/connectivity_monitoring_service.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/live_editor.dart';
import 'package:butlery/models/permissions/resource_permission.dart';
import 'package:butlery/models/permissions/edit_mode.dart';
import 'package:butlery/models/shared_recipe.dart';
import 'package:butlery/services/permission_service.dart';
import 'package:butlery/repositories/collaborative_recipe_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/utils/log_sanitizer.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Manages real-time collaborative editing for recipe forms.
class RecipeCollaborativeManager extends ChangeNotifier
    with StreamManagementMixin {
  final PermissionService _permissionService;
  final CollaborativeRecipeRepository _collaborativeRepository;
  final ConnectivityMonitoringService _connectivityService;

  RealtimeRecipe? _realtimeRecipe;
  StreamSubscription? _realtimeSubscription;
  StreamSubscription? _participantsSubscription;
  bool _isCollaborative = false;

  EditMode? _editMode;
  SharedRecipe? _sharedRecipe;
  final List<UserProfile> _collaborativeParticipants = [];
  final List<LiveEditor> _liveEditors = [];
  bool _isConnectedToFirebase = true;
  String _connectionStatusText = '';
  Timer? _presenceTimer;
  Timer? _saveDebounceTimer;

  RecipeCollaborativeManager({
    PermissionService? permissionService,
    CollaborativeRecipeRepository? collaborativeRepository,
    ConnectivityMonitoringService? connectivityService,
  }) : _permissionService =
           permissionService ?? ServiceLocator.get<PermissionService>(),
       _collaborativeRepository =
           collaborativeRepository ??
           ServiceLocator.get<CollaborativeRecipeRepository>(),
       _connectivityService =
           connectivityService ??
           ServiceLocator.get<ConnectivityMonitoringService>();

  bool get isCollaborative => _isCollaborative;
  bool get isConnectedToFirebase => _isConnectedToFirebase;
  String get connectionStatusText => _connectionStatusText;
  List<UserProfile> get collaborativeParticipants =>
      List<UserProfile>.from(_collaborativeParticipants);
  List<LiveEditor> get liveEditors => List<LiveEditor>.from(_liveEditors);
  RealtimeRecipe? get realtimeRecipe => _realtimeRecipe;
  EditMode? get editMode => _editMode;
  SharedRecipe? get sharedRecipe => _sharedRecipe;

  bool get canEdit => _editMode == EditMode.edit;
  bool get canView => _editMode == EditMode.view || canEdit;
  bool get hasPermissions => _editMode != null;

  Future<void> enableCollaborativeMode(Recipe recipe) async {
    if (_isCollaborative) return;

    try {
      AppLogger.info(
        'Aktiverar Firebase collaborative mode för recept: ${recipe.id}',
      );

      final userId = _permissionService.currentUserId;
      final userDisplayName =
          _permissionService.currentUser?.displayName ?? '?';
      if (userId == null) {
        throw Exception(AppLocale.current.errorNoUserLoggedIn);
      }

      _realtimeRecipe = RealtimeRecipe.fromRecipe(
        recipe: recipe,
        ownerId: userId,
        ownerDisplayName: userDisplayName,
      );

      await _collaborativeRepository.createRealtimeRecipe(_realtimeRecipe!);
      await _setupRealtimeListeners();
      _startPresenceTracking();

      _isCollaborative = true;

      AppLogger.info('Firebase collaborative mode aktiverat');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid aktivering av Firebase collaborative mode: $e');
      throw Exception(AppLocale.current.errorGeneric);
    }
  }

  Future<void> inviteUserToCollaboration(
    String userId,
    String userDisplayName,
    ResourcePermission permission,
  ) async {
    if (_realtimeRecipe == null) return;

    try {
      _realtimeRecipe = _realtimeRecipe!.addParticipant(
        userId,
        userDisplayName,
        permission,
      );
      await _collaborativeRepository.updateRealtimeRecipe(_realtimeRecipe!);

      AppLogger.info(
        'Användare inbjuden till collaboration: ${userDisplayName.maskedName}',
      );
      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid inbjudning av användare: $e');
      throw Exception(AppLocale.current.errorGeneric);
    }
  }

  Future<void> removeUserFromCollaboration(String userId) async {
    if (_realtimeRecipe == null) return;

    try {
      _realtimeRecipe = _realtimeRecipe!.removeParticipant(userId);
      await _collaborativeRepository.updateRealtimeRecipe(_realtimeRecipe!);

      AppLogger.info(
        'Användare borttagen från collaboration: ${userId.maskedUserId}',
      );
      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid borttagning av användare: $e');
      throw Exception(AppLocale.current.errorGeneric);
    }
  }

  Future<void> leaveCollaborativeMode() async {
    if (!_isCollaborative) return;

    try {
      await _cleanupRealtimeListeners();
      await _clearPresence();

      _isCollaborative = false;
      _realtimeRecipe = null;
      _editMode = null;
      _sharedRecipe = null;
      _collaborativeParticipants.clear();
      _liveEditors.clear();

      AppLogger.info('Collaborative mode avslutad');
      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid avslutning av collaborative mode: $e');
    }
  }

  Future<void> reconnectToFirebase() async {
    if (!_isCollaborative || _realtimeRecipe == null) return;

    try {
      await _cleanupRealtimeListeners();
      await _setupRealtimeListeners();
      _startPresenceTracking();

      AppLogger.info('Återansluten till Firebase');
    } catch (e) {
      AppLogger.error('Fel vid återanslutning till Firebase: $e');
    }
  }

  Future<void> updateRecipeInFirebase(Recipe recipe) async {
    if (!_isCollaborative || _realtimeRecipe == null) return;

    _saveDebounceTimer?.cancel();
    _saveDebounceTimer = Timer(const Duration(milliseconds: 500), () async {
      try {
        _realtimeRecipe = _realtimeRecipe!.copyWith(recipe: recipe);
        await _collaborativeRepository.updateRealtimeRecipe(_realtimeRecipe!);

        AppLogger.debug('Recipe data uppdaterad i Firebase');
      } catch (e) {
        AppLogger.error('Fel vid uppdatering av recipe data i Firebase: $e');
        _isConnectedToFirebase = false;
        _connectionStatusText = AppLocale.current.errorNetwork;
        notifyListeners();
      }
    });
  }

  Future<void> _setupRealtimeListeners() async {
    if (_realtimeRecipe == null) return;

    _realtimeSubscription = _collaborativeRepository
        .getRealtimeRecipeStream(_realtimeRecipe!.id)
        .listen(
          (realtimeRecipe) {
            if (realtimeRecipe != null) {
              _handleRealtimeUpdate(realtimeRecipe);
            }
          },
          onError: (error) {
            AppLogger.error('Fel i realtime listener: $error');
            _isConnectedToFirebase = false;
            _connectionStatusText = AppLocale.current.errorNetwork;
            notifyListeners();
          },
        );

    _participantsSubscription = _collaborativeRepository
        .getParticipantsStream(_realtimeRecipe!.id)
        .listen(
          (participants) {
            _updateLiveEditors(participants);
          },
          onError: (error) {
            AppLogger.error('Fel i participants listener: $error');
          },
        );

    _setupConnectivityMonitoring();
  }

  void _handleRealtimeUpdate(RealtimeRecipe realtimeRecipe) {
    if (_realtimeRecipe == null) return;

    final oldRecipe = _realtimeRecipe!;
    _realtimeRecipe = realtimeRecipe;

    if (oldRecipe.recipe != realtimeRecipe.recipe) {
      notifyListeners();
    }

    _loadParticipantsProfiles();
  }

  void _updateLiveEditors(List<LiveEditor> editors) {
    _liveEditors.clear();
    _liveEditors.addAll(editors);
    notifyListeners();
  }

  Future<void> _loadParticipantsProfiles() async {
    if (_realtimeRecipe == null) return;

    try {
      _collaborativeParticipants.clear();

      for (final entry in _realtimeRecipe!.participants.entries) {
        final profile = await _permissionService.getUserProfile(entry.key);
        if (profile != null) {
          _collaborativeParticipants.add(profile);
        }
      }

      notifyListeners();
    } catch (e) {
      AppLogger.error('Fel vid laddning av deltagarprofiler: $e');
    }
  }

  void _startPresenceTracking() {
    _presenceTimer = Timer.periodic(const Duration(seconds: 30), (timer) {
      _updatePresence();
    });
    _updatePresence();
  }

  void _updatePresence() {
    if (!_isCollaborative || _realtimeRecipe == null) return;

    final userId = _permissionService.currentUserId;
    final userDisplayName = _permissionService.currentUser?.displayName ?? '?';

    if (userId == null) return;

    try {
      _collaborativeRepository.updateUserPresence(
        _realtimeRecipe!.id,
        userId,
        userDisplayName,
      );
    } catch (e) {
      AppLogger.error('Fel vid uppdatering av presence: $e');
    }
  }

  Future<void> _clearPresence() async {
    if (_realtimeRecipe == null) return;

    final userId = _permissionService.currentUserId;
    if (userId == null) return;

    try {
      await _collaborativeRepository.clearUserPresence(
        _realtimeRecipe!.id,
        userId,
      );
    } catch (e) {
      AppLogger.error('Fel vid rensning av presence: $e');
    }
  }

  void _setupConnectivityMonitoring() {
    _connectivityService.startMonitoring();
    _connectivityService.addListener(_onConnectivityChanged);
    _onConnectivityChanged();
  }

  void _onConnectivityChanged() {
    _isConnectedToFirebase = _connectivityService.isConnectedToFirebase;
    _connectionStatusText = _connectivityService.connectionStatusText;
    notifyListeners();
  }

  Future<void> _cleanupRealtimeListeners() async {
    await _realtimeSubscription?.cancel();
    await _participantsSubscription?.cancel();
    _presenceTimer?.cancel();
    _saveDebounceTimer?.cancel();

    _realtimeSubscription = null;
    _participantsSubscription = null;
    _presenceTimer = null;
    _saveDebounceTimer = null;
  }

  @override
  void dispose() {
    _cleanupRealtimeListeners();
    _clearPresence();
    _connectivityService.removeListener(_onConnectivityChanged);
    super.dispose();
  }
}
