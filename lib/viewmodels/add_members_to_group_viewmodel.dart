// lib/viewmodels/add_members_to_group_viewmodel.dart - KOMPLETT med debug-prints

import 'package:flutter/foundation.dart';
import '../models/friend_category.dart';
import '../models/user_profile.dart';
import '../services/friends_service.dart';
import '../services/friend_categories_service.dart';
import '../services/group_invitation_service.dart'; // ✅ NYTT: Importera GroupInvitationService
import '../core/utils/logger.dart';

/// 🔍 AI INFO BLOCK:
/// Component: Add Members to Group ViewModel - KOMPLETT med riktiga gruppinbjudningar + DEBUG
/// File: viewmodels/add_members_to_group_viewmodel.dart
/// Quick Guide: Använder GroupInvitationService för riktiga gruppinbjudningar med omfattande debug
/// Dependencies IN: FriendsService, FriendCategoriesService, GroupInvitationService
/// Dependencies OUT: AddMembersToGroupView, GroupInvitation notifications
/// Data flow: Load available friends → Select members → Send GROUP invitations → Handle responses
/// State management: ChangeNotifier med search, selection, invitation state
/// Purpose: Skickar RIKTIGA gruppinbjudningar som mottagaren kan acceptera/avvisa + DEBUG
/// Common issues: Duplicate invitations, permission checking, network failures
/// Test coverage: 0% (uppdaterad komponent med debug)
/// Performance: ⚡ Cached friend lists, optimized search, batch operations
/// Analytics: 📊 Group invitation actions tracking
/// Code smells: ✅ Nu använder rätt service för gruppinbjudningar + debug output
/// Connected to: FriendsService, FriendCategoriesService, GroupInvitationService
/// Used in phases: 18.5 - Avancerad medlemshantering med riktiga inbjudningar + DEBUG

class AddMembersToGroupViewModel extends ChangeNotifier {
  final FriendsService _friendsService;
  final FriendCategoriesService _categoriesService;
  final GroupInvitationService
      _groupInvitationService; // ✅ NYTT: GroupInvitationService

  // Group info
  final String groupId;
  FriendCategory? _group;

  // Available friends state
  List<UserProfile> _availableFriends = [];
  List<UserProfile> _filteredFriends = [];
  String _searchQuery = '';

  // Selection state
  final Set<String> _selectedFriendIds = {};

  // Invitation state
  bool _isSendingInvitations = false;
  String? _invitationError;
  final Map<String, String> _invitationStatus = {}; // userId -> status

  // Loading states
  bool _isLoading = false;
  String? _error;

  AddMembersToGroupViewModel({
    required this.groupId,
    required FriendsService friendsService,
    required FriendCategoriesService categoriesService,
    required GroupInvitationService groupInvitationService, // ✅ NYTT: Parameter
  })  : _friendsService = friendsService,
        _categoriesService = categoriesService,
        _groupInvitationService = groupInvitationService {
    // ✅ NYTT: Spara referens

    // ✅ DEBUG: Konstruktor debug - FÖRSTA RADEN
    debugPrint(
        '🔍 DEBUG: AddMembersToGroupViewModel konstruktor - groupId: $groupId');
    debugPrint(
        '🔍 DEBUG: Services injected - FriendsService: ${friendsService.runtimeType}');
    debugPrint(
        '🔍 DEBUG: Services injected - FriendCategoriesService: ${categoriesService.runtimeType}');
    debugPrint(
        '🔍 DEBUG: Services injected - GroupInvitationService: ${groupInvitationService.runtimeType}');

    AppLogger.info(
        '🔄 Initialiserar AddMembersToGroupViewModel för grupp: $groupId');
    _initializeData();
  }

  // ===== GETTERS =====

  /// Group data
  FriendCategory? get group => _group;
  String get groupName => _group?.name ?? 'Grupp';

  /// Friends data
  List<UserProfile> get availableFriends =>
      List.unmodifiable(_availableFriends);
  List<UserProfile> get filteredFriends => List.unmodifiable(_filteredFriends);
  int get availableFriendsCount => _availableFriends.length;

  /// Search state
  String get searchQuery => _searchQuery;
  bool get hasSearchQuery => _searchQuery.isNotEmpty;

  /// Selection state
  Set<String> get selectedFriendIds => Set.unmodifiable(_selectedFriendIds);
  List<UserProfile> get selectedFriends => _filteredFriends
      .where((friend) => _selectedFriendIds.contains(friend.uid))
      .toList();
  int get selectedCount => _selectedFriendIds.length;
  bool get hasSelectedFriends => _selectedFriendIds.isNotEmpty;

  /// Invitation state
  bool get isSendingInvitations => _isSendingInvitations;
  String? get invitationError => _invitationError;
  Map<String, String> get invitationStatus =>
      Map.unmodifiable(_invitationStatus);

  /// General state
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;

  /// UI helpers
  bool get canSendInvitations => hasSelectedFriends && !_isSendingInvitations;
  bool get showEmptyState => _filteredFriends.isEmpty && !_isLoading;

  // ===== INITIALIZATION =====

  Future<void> _initializeData() async {
    debugPrint('🔍 DEBUG: _initializeData() kallad');

    try {
      _setLoading(true);
      _clearError();

      // Hämta gruppinformation
      debugPrint('🔍 DEBUG: Hämtar gruppinformation för $groupId');
      _group = _categoriesService.getCategoryById(groupId);
      if (_group == null) {
        debugPrint('🔍 DEBUG: Gruppen hittades inte: $groupId');
        _setError('Gruppen hittades inte');
        return;
      }

      debugPrint('🔍 DEBUG: Grupp hittad: ${_group!.name}');

      // Hämta tillgängliga vänner (som inte redan är medlemmar)
      await _loadAvailableFriends();

      AppLogger.success(
          '✅ AddMembersToGroupViewModel initialiserad för "${_group!.name}"');
      debugPrint('🔍 DEBUG: _initializeData() komplett');
    } catch (e) {
      AppLogger.error(
          '❌ Fel vid initialisering av AddMembersToGroupViewModel', e);
      debugPrint('🔍 DEBUG: _initializeData() fel: $e');
      _setError('Kunde inte ladda data: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadAvailableFriends() async {
    debugPrint('🔍 DEBUG: _loadAvailableFriends() start');

    if (_group == null) {
      debugPrint('🔍 DEBUG: Ingen grupp, hoppar över vänladdning');
      return;
    }

    // Hämta alla vänner
    final allFriends = _friendsService.friends;
    debugPrint('🔍 DEBUG: Totala vänner från service: ${allFriends.length}');

    // Filtrera bort befintliga gruppmedlemmar
    final currentMemberIds = _group!.friendUserIds.toSet();
    debugPrint('🔍 DEBUG: Nuvarande medlemmar i grupp: $currentMemberIds');

    _availableFriends = allFriends
        .where((friend) => !currentMemberIds.contains(friend.uid))
        .toList();

    debugPrint(
        '🔍 DEBUG: Vänner efter medlemsfiltrering: ${_availableFriends.length}');

    // ✅ NYTT: Filtrera även bort de som redan har väntande inbjudningar
    _availableFriends = _availableFriends.where((friend) {
      // Kontrollera om det redan finns en väntande inbjudan
      final existingInvitation = _groupInvitationService.sentInvitations
          .where((inv) =>
              inv.groupId == groupId &&
              inv.toUserId == friend.uid &&
              inv.isPending)
          .isNotEmpty;

      if (existingInvitation) {
        debugPrint(
            '🔍 DEBUG: Filtrerar bort ${friend.displayName} - har väntande inbjudan');
      }

      return !existingInvitation;
    }).toList();

    debugPrint(
        '🔍 DEBUG: Vänner efter inbjudningsfiltrering: ${_availableFriends.length}');

    // Sortera alfabetiskt
    _availableFriends.sort((a, b) => a.displayName.compareTo(b.displayName));

    // Uppdatera filtrerad lista
    _applySearchFilter();

    AppLogger.info(
        '👥 ${_availableFriends.length} tillgängliga vänner att bjuda in (efter filtrering av väntande inbjudningar)');
    debugPrint('🔍 DEBUG: _loadAvailableFriends() komplett');
  }

  // ===== SEARCH ACTIONS =====

  /// Uppdatera sökfrågan och filtrera vänner
  void updateSearch(String query) {
    debugPrint('🔍 DEBUG: updateSearch() kallad med: "$query"');
    _searchQuery = query.trim().toLowerCase();
    _applySearchFilter();
    notifyListeners();
  }

  /// Rensa sökning
  void clearSearch() {
    debugPrint('🔍 DEBUG: clearSearch() kallad');
    _searchQuery = '';
    _applySearchFilter();
    notifyListeners();
  }

  void _applySearchFilter() {
    if (_searchQuery.isEmpty) {
      _filteredFriends = List.from(_availableFriends);
    } else {
      _filteredFriends = _availableFriends
          .where((friend) =>
              friend.displayName.toLowerCase().contains(_searchQuery) ||
              (friend.bio?.toLowerCase().contains(_searchQuery) ?? false))
          .toList();
    }
    debugPrint(
        '🔍 DEBUG: Search filter applied - ${_filteredFriends.length} results');
  }

  // ===== SELECTION ACTIONS =====

  /// Växla val av vän
  void toggleFriendSelection(String friendId) {
    debugPrint('🔍 DEBUG: toggleFriendSelection() kallad för: $friendId');

    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
      AppLogger.info('❌ Avmarkerad vän: $friendId');
    } else {
      _selectedFriendIds.add(friendId);
      AppLogger.info('✅ Markerad vän: $friendId');
    }

    debugPrint('🔍 DEBUG: Valda vänner nu: ${_selectedFriendIds.length}');
    notifyListeners();
  }

  /// Kontrollera om en vän är vald
  bool isFriendSelected(String friendId) {
    return _selectedFriendIds.contains(friendId);
  }

  /// Välj alla synliga vänner
  void selectAllVisible() {
    debugPrint('🔍 DEBUG: selectAllVisible() kallad');
    _selectedFriendIds.clear();
    _selectedFriendIds.addAll(_filteredFriends.map((f) => f.uid));
    AppLogger.info(
        '✅ Markerade alla synliga vänner (${_selectedFriendIds.length})');
    debugPrint(
        '🔍 DEBUG: Alla synliga vänner valda: ${_selectedFriendIds.length}');
    notifyListeners();
  }

  /// Rensa alla val
  void clearAllSelections() {
    debugPrint('🔍 DEBUG: clearAllSelections() kallad');
    _selectedFriendIds.clear();
    AppLogger.info('❌ Rensade alla val');
    notifyListeners();
  }

  // ===== INVITATION ACTIONS =====

  /// ✅ UPPDATERAD: Skicka RIKTIGA gruppinbjudningar till valda vänner
  Future<bool> sendInvitations({String? personalMessage}) async {
    // ✅ DEBUG: Method entry - FÖRSTA RADEN
    debugPrint('🔍 DEBUG: ===== sendInvitations() KALLAD =====');
    debugPrint(
        '🔍 DEBUG: sendInvitations kallad - använder GroupInvitationService: ${_groupInvitationService.runtimeType}');
    debugPrint('🔍 DEBUG: Personal message: $personalMessage');
    debugPrint('🔍 DEBUG: Selected friends: ${_selectedFriendIds.toList()}');
    debugPrint('🔍 DEBUG: Group: ${_group?.name} (ID: $groupId)');

    if (!canSendInvitations || _group == null) {
      debugPrint(
          '🔍 DEBUG: Cannot send invitations - canSend: $canSendInvitations, group: ${_group != null}');
      AppLogger.warning(
          '⚠️ Kan inte skicka inbjudningar - villkor inte uppfyllda');
      return false;
    }

    try {
      _isSendingInvitations = true;
      _clearInvitationError();
      _invitationStatus.clear();
      notifyListeners();

      final selectedUserIds = _selectedFriendIds.toList();
      AppLogger.info(
          '📨 Skickar RIKTIGA gruppinbjudningar till ${selectedUserIds.length} vänner');
      debugPrint(
          '🔍 DEBUG: Processing ${selectedUserIds.length} users: $selectedUserIds');

      // ✅ DEBUG: Kontrollera parametrar före API-anrop
      debugPrint('🔍 DEBUG: Calling sendBulkGroupInvitations med:');
      debugPrint('🔍 DEBUG:   - groupId: $groupId');
      debugPrint('🔍 DEBUG:   - users: $selectedUserIds');
      debugPrint('🔍 DEBUG:   - personalMessage: $personalMessage');
      debugPrint(
          '🔍 DEBUG:   - service: ${_groupInvitationService.runtimeType}');

      // ✅ NYTT: Använd bulk-funktionen från GroupInvitationService
      final results = await _groupInvitationService.sendBulkGroupInvitations(
        groupId: groupId,
        toUserIds: selectedUserIds,
        personalMessage: personalMessage,
      );

      // ✅ DEBUG: Kontrollera resultat från API-anrop
      debugPrint('🔍 DEBUG: sendBulkGroupInvitations results: $results');

      // Uppdatera status baserat på resultat
      int successCount = 0;
      int failureCount = 0;

      results.forEach((userId, success) {
        if (success) {
          _invitationStatus[userId] = 'sent';
          successCount++;
          debugPrint('🔍 DEBUG: SUCCESS för user $userId');
        } else {
          _invitationStatus[userId] = 'failed';
          failureCount++;
          debugPrint('🔍 DEBUG: FAILED för user $userId');
        }
      });

      // Rapportera resultat
      if (successCount > 0) {
        AppLogger.success(
            '✅ $successCount av ${selectedUserIds.length} gruppinbjudningar skickade');
        debugPrint('🔍 DEBUG: $successCount successful invitations sent');
      }

      if (failureCount > 0) {
        AppLogger.warning('⚠️ $failureCount gruppinbjudningar misslyckades');
        debugPrint('🔍 DEBUG: $failureCount invitations failed');

        // Visa specifikt fel från GroupInvitationService om det finns
        if (_groupInvitationService.hasError) {
          debugPrint(
              '🔍 DEBUG: GroupInvitationService error: ${_groupInvitationService.error}');
          _setInvitationError(_groupInvitationService.error!);
        }
      }

      // Rensa val efter framgångsrika inbjudningar
      if (successCount > 0) {
        debugPrint('🔍 DEBUG: Clearing selections and reloading friends');
        _selectedFriendIds.clear();

        // ✅ NYTT: Ladda om tillgängliga vänner för att ta bort de som nu har väntande inbjudningar
        await _loadAvailableFriends();
      }

      debugPrint('🔍 DEBUG: sendInvitations() returning: ${successCount > 0}');
      return successCount > 0;
    } catch (e) {
      AppLogger.error('❌ Kritiskt fel vid sändning av gruppinbjudningar', e);
      debugPrint('🔍 DEBUG: CRITICAL ERROR i sendInvitations(): $e');
      _setInvitationError('Fel vid sändning av gruppinbjudningar: $e');
      return false;
    } finally {
      _isSendingInvitations = false;
      debugPrint('🔍 DEBUG: sendInvitations() slutförd - isSending: false');
      notifyListeners();
    }
  }

  // ===== UTILITY METHODS =====

  /// Hämta status för en specifik inbjudan
  String? getInvitationStatusForUser(String userId) {
    return _invitationStatus[userId];
  }

  /// Kontrollera om en användare har väntande inbjudan
  bool hasInvitationStatus(String userId) {
    return _invitationStatus.containsKey(userId);
  }

  /// ✅ NYTT: Kontrollera om en användare redan har väntande gruppinbjudan
  bool hasExistingInvitation(String userId) {
    final hasInvitation = _groupInvitationService.sentInvitations
        .where((inv) =>
            inv.groupId == groupId && inv.toUserId == userId && inv.isPending)
        .isNotEmpty;
    debugPrint('🔍 DEBUG: hasExistingInvitation($userId): $hasInvitation');
    return hasInvitation;
  }

  /// ✅ NYTT: Hämta information om skickade inbjudningar för denna grupp
  List<dynamic> getSentInvitationsForGroup() {
    final invitations = _groupInvitationService.sentInvitations
        .where((inv) => inv.groupId == groupId)
        .toList();
    debugPrint(
        '🔍 DEBUG: getSentInvitationsForGroup() returning ${invitations.length} invitations');
    return invitations;
  }

  /// Refresh data
  Future<void> refresh() async {
    debugPrint('🔍 DEBUG: refresh() kallad');
    AppLogger.info('🔄 Refreshar AddMembersToGroupViewModel data');

    // ✅ NYTT: Refresha även GroupInvitationService
    await _groupInvitationService.refresh();
    debugPrint('🔍 DEBUG: GroupInvitationService refreshed');

    await _initializeData();
    debugPrint('🔍 DEBUG: refresh() komplett');
  }

  // ===== PRIVATE HELPERS =====

  void _setLoading(bool loading) {
    debugPrint('🔍 DEBUG: _setLoading($loading)');
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    debugPrint('🔍 DEBUG: _setError("$message")');
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    debugPrint('🔍 DEBUG: _clearError()');
    _error = null;
  }

  void _setInvitationError(String message) {
    debugPrint('🔍 DEBUG: _setInvitationError("$message")');
    _invitationError = message;
    notifyListeners();
  }

  void _clearInvitationError() {
    debugPrint('🔍 DEBUG: _clearInvitationError()');
    _invitationError = null;
  }

  /// Rensa fel
  void clearError() {
    debugPrint('🔍 DEBUG: clearError() - public method');
    _clearError();
    _clearInvitationError();
    notifyListeners();
  }

  @override
  void dispose() {
    debugPrint('🔍 DEBUG: AddMembersToGroupViewModel dispose() kallad');
    AppLogger.info('🗑️ Disposing AddMembersToGroupViewModel');
    super.dispose();
  }
}
