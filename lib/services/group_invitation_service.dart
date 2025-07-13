// lib/services/group_invitation_service.dart - MED FIXAD acceptGroupInvitation

import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/group_invitation.dart';
import '../models/friend_category.dart';
import '../services/friend_categories_service.dart';
import '../core/utils/logger.dart';
import '../core/error/error_handler.dart';
import '../core/events/group_events.dart';
import '../repositories/friends_repository.dart';
import '../repositories/user_repository.dart';


class GroupInvitationService extends ChangeNotifier {
  final FriendsRepository _friendsRepository;
  final UserRepository _userRepository;
  final FriendCategoriesService _categoriesService;

  // State
  List<GroupInvitation> _receivedInvitations = [];
  List<GroupInvitation> _sentInvitations = [];
  bool _isLoading = false;
  String? _error;

  // Real-time listeners
  StreamSubscription<List<GroupInvitation>>? _receivedInvitationsSubscription;
  StreamSubscription<List<GroupInvitation>>? _sentInvitationsSubscription;

  GroupInvitationService({
    required FriendCategoriesService categoriesService,
    required FriendsRepository friendsRepository,
    required UserRepository userRepository,
  })  : _categoriesService = categoriesService,
        _friendsRepository = friendsRepository,
        _userRepository = userRepository {
    debugPrint(
        '🔍 DEBUG: GroupInvitationService skapad med categoriesService: ${categoriesService.runtimeType}');
  }

  // ===== GETTERS =====

  List<GroupInvitation> get receivedInvitations =>
      List.unmodifiable(_receivedInvitations);
  List<GroupInvitation> get sentInvitations =>
      List.unmodifiable(_sentInvitations);
  bool get isLoading => _isLoading;
  String? get error => _error;
  bool get hasError => _error != null;
  String? get currentUserId => _userRepository.currentUserId;

  /// Väntande mottagna inbjudningar
  List<GroupInvitation> get pendingReceivedInvitations =>
      _receivedInvitations.where((inv) => inv.isPending).toList();

  /// Väntande skickade inbjudningar
  List<GroupInvitation> get pendingSentInvitations =>
      _sentInvitations.where((inv) => inv.isPending).toList();

  /// Antal väntande notifikationer
  int get pendingNotificationsCount => pendingReceivedInvitations.length;

  // ===== INITIALIZATION =====

  /// Initiera service med real-time listeners
  Future<void> initialize() async {
    debugPrint('🔍 DEBUG: GroupInvitationService.initialize() kallad');
    AppLogger.info('🔄 Initialiserar GroupInvitationService...');

    _userRepository.authStateChanges().listen((uid) {
      debugPrint('🔍 DEBUG: Auth state changed - user: $uid');
      if (uid != null) {
        _setupRealtimeListeners();
      } else {
        _clearAllData();
      }
    });

    final currentUserId = _userRepository.currentUserId;
    debugPrint('🔍 DEBUG: Current user at initialization: $currentUserId');

    if (currentUserId != null) {
      debugPrint('🔍 DEBUG: Current user exists, setting up listeners');
      _setupRealtimeListeners();
    } else {
      debugPrint('🔍 DEBUG: No current user, skipping listener setup');
    }
  }

  /// Sätt upp real-time listeners för inbjudningar
  void _setupRealtimeListeners() {
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('🔍 DEBUG: No userId för real-time listeners');
      return;
    }

    debugPrint('🔍 DEBUG: Setting up real-time listeners för userId: $userId');
    AppLogger.info(
        '🔄 Sätter upp real-time listeners för gruppinbjudningar...');

    try {
      // Lyssna på mottagna inbjudningar
      debugPrint('🔍 DEBUG: Setting up RECEIVED invitations listener');
      _receivedInvitationsSubscription = _friendsRepository
          .receivedInvitationsStream(userId)
          .listen(
        _handleReceivedInvitationsUpdate,
        onError: (error) {
          debugPrint('🔍 DEBUG: Real-time listener error (received): $error');
          AppLogger.error('Real-time listener fel (received)', error);
        },
      );

      // Lyssna på skickade inbjudningar
      debugPrint('🔍 DEBUG: Setting up SENT invitations listener');
      _sentInvitationsSubscription = _friendsRepository
          .sentInvitationsStream(userId)
          .listen(
        _handleSentInvitationsUpdate,
        onError: (error) {
          debugPrint('🔍 DEBUG: Real-time listener error (sent): $error');
          AppLogger.error('Real-time listener fel (sent)', error);
        },
      );

      debugPrint('🔍 DEBUG: Real-time listeners uppsatta framgångsrikt');
    } catch (e) {
      debugPrint('🔍 DEBUG: Exception setting up listeners: $e');
      AppLogger.error('Fel vid uppsättning av real-time listeners', e);
    }
  }

  /// Hantera uppdateringar för mottagna inbjudningar
  void _handleReceivedInvitationsUpdate(List<GroupInvitation> invitations) {
    try {
      debugPrint(
          '🔍 DEBUG: Received invitations update - ${invitations.length} items');

      _receivedInvitations = invitations;

      AppLogger.info(
          '📨 ${_receivedInvitations.length} mottagna inbjudningar uppdaterade');
      debugPrint(
          '🔍 DEBUG: Processed received invitations: ${_receivedInvitations.map((i) => i.id).toList()}');
      notifyListeners();
    } catch (e) {
      debugPrint('🔍 DEBUG: Error processing received invitations: $e');
      AppLogger.error('Fel vid hantering av mottagna inbjudningar', e);
    }
  }

  /// Hantera uppdateringar för skickade inbjudningar
  void _handleSentInvitationsUpdate(List<GroupInvitation> invitations) {
    try {
      debugPrint(
          '🔍 DEBUG: Sent invitations update - ${invitations.length} items');

      _sentInvitations = invitations;

      AppLogger.info(
          '📤 ${_sentInvitations.length} skickade inbjudningar uppdaterade');
      debugPrint(
          '🔍 DEBUG: Processed sent invitations: ${_sentInvitations.map((i) => i.id).toList()}');
      notifyListeners();
    } catch (e) {
      debugPrint('🔍 DEBUG: Error processing sent invitations: $e');
      AppLogger.error('Fel vid hantering av skickade inbjudningar', e);
    }
  }

  // ===== SKICKA INBJUDNINGAR =====

  /// Skicka gruppinbjudan till användare
  Future<bool> sendGroupInvitation({
    required String groupId,
    required String toUserId,
    String? personalMessage,
  }) async {
    debugPrint(
        '🔍 DEBUG: sendGroupInvitation kallad - groupId: $groupId, toUserId: $toUserId');

    final fromUserId = currentUserId;
    if (fromUserId == null) {
      debugPrint('🔍 DEBUG: No current user - aborting');
      _setError('Ingen användare inloggad');
      return false;
    }

    if (fromUserId == toUserId) {
      debugPrint('🔍 DEBUG: Cannot send invitation to self');
      _setError('Du kan inte skicka inbjudan till dig själv');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      debugPrint('🔍 DEBUG: Getting group info för groupId: $groupId');

      // Hämta gruppinformation
      final group = _categoriesService.getCategoryById(groupId);
      if (group == null) {
        debugPrint('🔍 DEBUG: Group not found: $groupId');
        _setError('Gruppen hittades inte');
        return false;
      }

      debugPrint(
          '🔍 DEBUG: Found group: ${group.name}, createdBy: ${group.createdBy}');

      // Kontrollera att användaren äger gruppen eller är medlem
      if (group.createdBy != fromUserId &&
          !group.friendUserIds.contains(fromUserId)) {
        debugPrint('🔍 DEBUG: Permission denied - user not owner or member');
        _setError(
            'Du har inte behörighet att skicka inbjudningar för denna grupp');
        return false;
      }

      // Kontrollera att målpersonen inte redan är medlem
      if (group.friendUserIds.contains(toUserId)) {
        debugPrint('🔍 DEBUG: Target user already member');
        _setError('Användaren är redan medlem i gruppen');
        return false;
      }

      // Kontrollera att det inte redan finns en väntande inbjudan
      if (await _hasPendingInvitation(groupId, toUserId)) {
        debugPrint('🔍 DEBUG: Pending invitation already exists');
        _setError('Det finns redan en väntande inbjudan för denna användare');
        return false;
      }

      // Hämta avsändarens namn (för UI-caching)
      final fromUserName =
          _userRepository.currentUserDisplayName ?? 'Okänd användare';

      debugPrint('🔍 DEBUG: Creating invitation object');

      // Skapa inbjudan
      final invitation = GroupInvitation.create(
        groupId: groupId,
        groupName: group.name,
        groupEmoji: group.emoji ?? '👥',
        fromUserId: fromUserId,
        fromUserName: fromUserName,
        toUserId: toUserId,
        personalMessage: personalMessage,
      );

      debugPrint('🔍 DEBUG: Saving invitation to Firestore: ${invitation.id}');

      await _friendsRepository.saveInvitation(invitation);

      // Trigga group event för att uppdatera UI
      GroupEventBus.groupUpdated();
      debugPrint('🔍 DEBUG: Group event triggered: groupUpdated');

      debugPrint('🔍 DEBUG: Invitation saved successfully');
      AppLogger.success(
          '✅ Gruppinbjudan skickad till $toUserId för grupp "${group.name}"');
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      debugPrint('🔍 DEBUG: Error sending invitation: $e');
      AppLogger.error('❌ Kunde inte skicka gruppinbjudan', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Skicka bulk-inbjudningar till flera användare
  Future<Map<String, bool>> sendBulkGroupInvitations({
    required String groupId,
    required List<String> toUserIds,
    String? personalMessage,
  }) async {
    debugPrint(
        '🔍 DEBUG: GroupInvitationService.sendBulkGroupInvitations kallad för grupp $groupId med ${toUserIds.length} användare');
    debugPrint('🔍 DEBUG: Target users: $toUserIds');
    debugPrint('🔍 DEBUG: Personal message: $personalMessage');

    final results = <String, bool>{};

    for (final userId in toUserIds) {
      debugPrint('🔍 DEBUG: Processing invitation för user: $userId');
      final success = await sendGroupInvitation(
        groupId: groupId,
        toUserId: userId,
        personalMessage: personalMessage,
      );
      results[userId] = success;
      debugPrint(
          '🔍 DEBUG: Invitation för $userId: ${success ? "SUCCESS" : "FAILED"}');
    }

    debugPrint('🔍 DEBUG: Bulk invitation results: $results');
    return results;
  }

  // ===== HANTERA INBJUDNINGAR =====

  /// ✅ FIXAD: Acceptera gruppinbjudan med korrekt medlemshantering
  Future<bool> acceptGroupInvitation(String invitationId) async {
    debugPrint('🔍 DEBUG: acceptGroupInvitation kallad för: $invitationId');
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('🔍 DEBUG: No current user for accept');
      _setError('Ingen användare inloggad');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      final invitation = await _friendsRepository.getInvitation(invitationId);
      if (invitation == null) {
        debugPrint('🔍 DEBUG: Invitation document not found');
        _setError('Inbjudan hittades inte');
        return false;
      }

      debugPrint('🔍 DEBUG: Found invitation: ${invitation.groupName}');

      // Validera behörighet
      if (invitation.toUserId != userId) {
        debugPrint('🔍 DEBUG: Permission denied - not invitation recipient');
        _setError('Du kan bara acceptera inbjudningar skickade till dig');
        return false;
      }

      if (!invitation.isPending) {
        debugPrint('🔍 DEBUG: Invitation not pending: ${invitation.status}');
        _setError('Inbjudan är inte längre aktiv');
        return false;
      }

      // ✅ FÖRBÄTTRAT: Hämta originalgruppen från skaparen
      debugPrint('🔍 DEBUG: Fetching original group from creator...');
      final originalGroup = await _friendsRepository.getCategory(
        invitation.fromUserId,
        invitation.groupId,
      );

      if (originalGroup == null) {
        debugPrint(
            '🔍 DEBUG: Original group not found in creator\'s categories');
        _setError('Gruppen hittades inte hos skaparen');
        return false;
      }

      final originalFriendIds = List<String>.from(originalGroup.friendUserIds);

      debugPrint('🔍 DEBUG: Original group members: $originalFriendIds');
      debugPrint('🔍 DEBUG: Adding new member: $userId');

      // ✅ KRITISK FIX: Lägg till ny medlem UTAN att ta bort befintliga
      final updatedFriendIds = List<String>.from(originalFriendIds);
      if (!updatedFriendIds.contains(userId)) {
        updatedFriendIds.add(userId);
      }

      debugPrint('🔍 DEBUG: Updated members list: $updatedFriendIds');

      // ✅ SUPER VIKTIG FIX: Behåll ORIGINAL ownerId!
      final originalOwnerId = originalGroup.ownerId;

      debugPrint('🔍 DEBUG: Preserving original ownership:');
      debugPrint('   - Original ownerId: $originalOwnerId');
      debugPrint('   - Current userId (new member): $userId');

      // ✅ FIXAT: Skapa grupp med ALLA medlemmar OCH korrekt ägare
      final newCategory = FriendCategory(
        ownerId: originalOwnerId,
        id: invitation.groupId,
        name: originalGroup.name,
        emoji: originalGroup.emoji ?? invitation.groupEmoji,
        description: originalGroup.description,
        friendUserIds: updatedFriendIds,
        createdAt: originalGroup.createdAt,
        updatedAt: DateTime.now(),
        sortOrder: originalGroup.sortOrder,
        isDefault: originalGroup.isDefault,
      );

      debugPrint('🔍 DEBUG: Creating local group with:');
      debugPrint('   - ${newCategory.friendUserIds.length} members');
      debugPrint('   - ownerId: ${newCategory.ownerId}');

      await _friendsRepository.createCategoryForUser(userId, newCategory);

      // ✅ NYTT: Uppdatera originalgruppen hos skaparen med ny medlem
      debugPrint('🔍 DEBUG: Updating original group with new member...');
      await _friendsRepository.updateCategoryMembers(
        invitation.fromUserId,
        invitation.groupId,
        updatedFriendIds,
      );

      // Trigga group event
      GroupEventBus.memberAdded();
      debugPrint('🔍 DEBUG: Group event triggered: memberAdded');

      // Acceptera inbjudan
      final acceptedInvitation = invitation.accept();
      await _friendsRepository.updateInvitation(
        invitationId,
        acceptedInvitation.toFirestore(),
      );
      debugPrint('🔍 DEBUG: Invitation status updated to accepted');

      // Refresh categories service
      await _categoriesService.refresh();

      // Ta bort inbjudan från pending-listan
      _receivedInvitations.removeWhere((inv) => inv.id == invitationId);
      notifyListeners();

      debugPrint('🔍 DEBUG: ✅ Group invitation accepted successfully:');
      debugPrint('   - Total members: ${updatedFriendIds.length}');
      debugPrint('   - Owner/Creator remains: $originalOwnerId');

      return true;
    } catch (e, stackTrace) {
      debugPrint('🔍 DEBUG: ❌ Error accepting invitation: $e');
      debugPrint('🔍 DEBUG: Stack trace: $stackTrace');
      _setError('Fel vid acceptering av inbjudan: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Avvisa gruppinbjudan
  Future<bool> rejectGroupInvitation(String invitationId) async {
    debugPrint('🔍 DEBUG: rejectGroupInvitation kallad för: $invitationId');
    final userId = currentUserId;
    if (userId == null) {
      debugPrint('🔍 DEBUG: No current user for reject');
      _setError('Ingen användare inloggad');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      final invitation = await _friendsRepository.getInvitation(invitationId);
      if (invitation == null) {
        debugPrint('🔍 DEBUG: Invitation document not found');
        _setError('Inbjudan hittades inte');
        return false;
      }
      debugPrint(
          '🔍 DEBUG: Found invitation to reject: ${invitation.groupName}');

      // Validera behörighet
      if (invitation.toUserId != userId) {
        debugPrint('🔍 DEBUG: Permission denied - not invitation recipient');
        _setError('Du kan bara avvisa inbjudningar skickade till dig');
        return false;
      }

      if (!invitation.isPending) {
        debugPrint('🔍 DEBUG: Invitation not pending: ${invitation.status}');
        _setError('Inbjudan är inte längre aktiv');
        return false;
      }

      // Avvisa inbjudan med korrekt status
      final rejectedInvitation = invitation.reject();
      await _friendsRepository.updateInvitation(
        invitationId,
        rejectedInvitation.toFirestore(),
      );
      debugPrint('🔍 DEBUG: Invitation status updated to rejected');

      // Trigga group event för UI-refresh
      GroupEventBus.groupUpdated();
      debugPrint('🔍 DEBUG: Group event triggered: groupUpdated');

      // Ta bort inbjudan från pending-listan direkt
      _receivedInvitations.removeWhere((inv) => inv.id == invitationId);
      notifyListeners();

      debugPrint('🔍 DEBUG: Group invitation rejected successfully');
      return true;
    } catch (e, stackTrace) {
      debugPrint('🔍 DEBUG: Error rejecting invitation: $e');
      debugPrint('🔍 DEBUG: Stack trace: $stackTrace');
      _setError('Fel vid avvisning av inbjudan: $e');
      return false;
    } finally {
      _setLoading(false);
    }
  }

  /// Avbryt skickad inbjudan
  Future<bool> cancelSentInvitation(String invitationId) async {
    debugPrint('🔍 DEBUG: cancelSentInvitation kallad för: $invitationId');

    final userId = currentUserId;
    if (userId == null) {
      debugPrint('🔍 DEBUG: No current user for cancel');
      _setError('Ingen användare inloggad');
      return false;
    }

    try {
      _setLoading(true);
      _clearError();

      final invitation = await _friendsRepository.getInvitation(invitationId);
      if (invitation == null) {
        debugPrint('🔍 DEBUG: Invitation document not found for cancel');
        _setError('Inbjudan hittades inte');
        return false;
      }
      debugPrint('🔍 DEBUG: Cancelling invitation: ${invitation.groupName}');

      // Validera behörighet
      if (invitation.fromUserId != userId) {
        debugPrint('🔍 DEBUG: Permission denied - not invitation sender');
        _setError('Du kan bara avbryta inbjudningar du har skickat');
        return false;
      }

      final cancelledInvitation = invitation.cancel();
      await _friendsRepository.updateInvitation(
        invitationId,
        cancelledInvitation.toFirestore(),
      );

      // Trigga group event för UI-refresh
      GroupEventBus.groupUpdated();
      debugPrint('🔍 DEBUG: Group event triggered: groupUpdated');

      debugPrint('🔍 DEBUG: Invitation successfully cancelled');
      AppLogger.info('🚫 Skickad gruppinbjudan avbruten');
      return true;
    } catch (e) {
      final failure = ErrorHandler.handleError(e);
      debugPrint('🔍 DEBUG: Error cancelling invitation: $e');
      AppLogger.error('❌ Kunde inte avbryta gruppinbjudan', e);
      _setError(failure.message);
      return false;
    } finally {
      _setLoading(false);
    }
  }

  // ===== CLEANUP METHODS =====

  /// Cleanup för gamla inbjudningar
  Future<void> cleanupOldInvitations() async {
    debugPrint('🔍 DEBUG: Cleaning up old invitations');
    final userId = currentUserId;
    if (userId == null) return;

    try {
      // Ta bort inbjudningar äldre än 30 dagar
      final cutoffDate = DateTime.now().subtract(const Duration(days: 30));
      final oldInvitations =
          await _friendsRepository.oldInvitations(userId, cutoffDate);

      if (oldInvitations.isNotEmpty) {
        await _friendsRepository
            .deleteDocuments(oldInvitations.map((d) => d.reference).toList());
        debugPrint(
            '🔍 DEBUG: Cleaned up ${oldInvitations.length} old invitations');
      }
    } catch (e) {
      debugPrint('🔍 DEBUG: Error cleaning up invitations: $e');
    }
  }

  /// Rensa utgångna inbjudningar (körs periodiskt)
  Future<void> cleanupExpiredInvitations() async {
    debugPrint('🔍 DEBUG: cleanupExpiredInvitations started');

    try {
      final now = Timestamp.now();

      final expiredDocs = await _friendsRepository.expiredInvitations(now);

      if (expiredDocs.isEmpty) {
        debugPrint('🔍 DEBUG: No expired invitations found');
        return;
      }

      debugPrint('🔍 DEBUG: Found ${expiredDocs.length} expired invitations');

      await _friendsRepository.updateDocuments(expiredDocs, {
        'status': GroupInvitationStatus.expired.name,
        'respondedAt': now,
      });

      debugPrint('🔍 DEBUG: Expired invitations cleanup completed');
      AppLogger.info('🧹 ${expiredDocs.length} utgångna inbjudningar rensade');
    } catch (e) {
      debugPrint('🔍 DEBUG: Error during cleanup: $e');
      AppLogger.error('Fel vid cleanup av utgångna inbjudningar', e);
    }
  }

  // ===== UTILITY METHODS =====

  /// Kontrollera om det finns en väntande inbjudan
  Future<bool> _hasPendingInvitation(String groupId, String toUserId) async {
    try {
      debugPrint(
          '🔍 DEBUG: Checking for pending invitation: $groupId -> $toUserId');

      final hasPending = await _friendsRepository.hasPendingInvitation(
        groupId,
        toUserId,
      );
      debugPrint('🔍 DEBUG: Has pending invitation: $hasPending');
      return hasPending;
    } catch (e) {
      debugPrint('🔍 DEBUG: Error checking pending invitation: $e');
      AppLogger.error('Fel vid kontroll av väntande inbjudan', e);
      return false;
    }
  }

  /// Få inbjudningsstatus för grupp och användare
  GroupInvitationStatus? getInvitationStatus(String groupId, String userId) {
    debugPrint('🔍 DEBUG: Getting invitation status för $groupId -> $userId');

    try {
      final invitation = _sentInvitations.firstWhere(
        (inv) => inv.groupId == groupId && inv.toUserId == userId,
        orElse: () => _receivedInvitations.firstWhere(
          (inv) => inv.groupId == groupId && inv.fromUserId == userId,
          orElse: () => throw StateError('No invitation found'),
        ),
      );

      debugPrint('🔍 DEBUG: Found invitation status: ${invitation.status}');
      return invitation.status;
    } catch (e) {
      debugPrint('🔍 DEBUG: No invitation found för $groupId -> $userId');
      return null;
    }
  }

  // ===== PRIVATE HELPERS =====

  void _setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }

  void _setError(String message) {
    _error = message;
    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  void _clearAllData() {
    debugPrint('🔍 DEBUG: Clearing all GroupInvitationService data');
    _receivedInvitations.clear();
    _sentInvitations.clear();
    _receivedInvitationsSubscription?.cancel();
    _sentInvitationsSubscription?.cancel();
    _isLoading = false;
    _error = null;
    notifyListeners();
  }

  /// Rensa fel
  void clearError() {
    _clearError();
    notifyListeners();
  }

  /// Refresh data (för pull-to-refresh)
  Future<void> refresh() async {
    debugPrint('🔍 DEBUG: GroupInvitationService refresh called');
    // Real-time listeners hanterar detta automatiskt
    await cleanupExpiredInvitations();
  }

  @override
  void dispose() {
    debugPrint('🔍 DEBUG: GroupInvitationService disposing');
    _receivedInvitationsSubscription?.cancel();
    _sentInvitationsSubscription?.cancel();
    super.dispose();
  }
}
