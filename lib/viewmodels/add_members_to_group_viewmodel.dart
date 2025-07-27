// lib/viewmodels/add_members_to_group_viewmodel.dart - KOMPLETT med debug-prints

import 'package:flutter/foundation.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/utils/logger.dart';


class AddMembersToGroupViewModel extends ChangeNotifier {
  final UnifiedFriendsService _friendsService;

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
    required UnifiedFriendsService friendsService,
  })  : _friendsService = friendsService {

    // ✅ DEBUG: Konstruktor debug - FÖRSTA RADEN
    debugPrint(
        '🔍 DEBUG: AddMembersToGroupViewModel konstruktor - groupId: $groupId');
    debugPrint(
        '🔍 DEBUG: Services injected - UnifiedFriendsService: ${friendsService.runtimeType}');

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
      _group = _friendsService.categories.getCategoryById(groupId);
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
    final allFriends = _friendsService.management.getAllFriends();
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
      final existingInvitation = _friendsService.invitations.getSentInvitations()
          .where((inv) =>
              inv.toUserId == friend.uid &&
              inv.status == GroupInvitationStatus.pending)
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
        '🔍 DEBUG: sendInvitations kallad - använder UnifiedFriendsService: ${_friendsService.runtimeType}');
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
          '🔍 DEBUG:   - service: ${_friendsService.runtimeType}');

      // ✅ NYTT: Använd bulk-funktionen från UnifiedFriendsService
      final results = <String, bool>{};
      for (final userId in selectedUserIds) {
        // Get friend info
        final friend = _friendsService.management.getFriendById(userId);
        if (friend != null) {
          // Use actual email if available, otherwise skip invitation
          if (friend.email.isNotEmpty && friend.email.contains('@')) {
            final success = await _friendsService.invitations.sendEmailInvitation(
              email: friend.email,
              customMessage: personalMessage,
            );
            results[userId] = success;
          } else {
            AppLogger.warning('⚠️ Cannot send invitation to ${friend.displayName}: No valid email available');
            results[userId] = false;
          }
        } else {
          results[userId] = false;
        }
      }

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

        // Visa specifikt fel från UnifiedFriendsService om det finns
        if (_friendsService.hasError) {
          debugPrint(
              '🔍 DEBUG: UnifiedFriendsService error: ${_friendsService.error}');
          _setInvitationError(_friendsService.error!);
        } else if (successCount == 0 && failureCount > 0) {
          // All invitations failed, likely due to email service not being implemented
          _setInvitationError('Email invitation system is not yet implemented. Please try again later.');
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
    final hasInvitation = _friendsService.invitations.getSentInvitations()
        .where((inv) => inv.toUserId == userId && inv.status == GroupInvitationStatus.pending)
        .isNotEmpty;
    debugPrint('🔍 DEBUG: hasExistingInvitation($userId): $hasInvitation');
    return hasInvitation;
  }

  /// ✅ NYTT: Hämta information om skickade inbjudningar för denna grupp
  List<dynamic> getSentInvitationsForGroup() {
    final invitations = _friendsService.invitations.getSentInvitations()
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

    // ✅ NYTT: Refresha även UnifiedFriendsService
    await _friendsService.refresh();
    debugPrint('🔍 DEBUG: UnifiedFriendsService refreshed');

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
