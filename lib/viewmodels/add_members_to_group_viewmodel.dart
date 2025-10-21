/// Comprehensive group member management ViewModel providing advanced member addition and invitation coordination for Flutter applications.
///
/// This module implements sophisticated group member management functionality following Single Responsibility Principle,
/// specializing in friend invitation, member selection, search functionality, and invitation status tracking.
/// It provides complete group member addition infrastructure while maintaining clean separation from UI rendering,
/// group data persistence, and complex social relationship business logic implementation.
///
/// **Single Responsibility Focus:**
/// This module exclusively handles group member addition presentation layer concerns:
/// - **Member Selection Intelligence**: Advanced friend selection with search functionality and availability filtering
/// - **Invitation Management System**: Comprehensive invitation sending with status tracking and error handling
/// - **Search and Filter Coordination**: Intelligent friend search with real-time filtering and availability management
/// - **State Management Excellence**: Complete state coordination with loading states and comprehensive error handling
/// - **Swedish Localization Excellence**: Complete Swedish language support for member management operations and user feedback
///
/// **What This Module Does NOT Handle:**
/// - UI rendering and widget creation (handled by group member addition views and presentation components)
/// - Group data persistence and storage (handled by UnifiedFriendsService and underlying data repositories)
/// - Complex social relationship business logic (handled by friends service layer and social infrastructure)
/// - Email delivery infrastructure (handled by messaging services and communication systems)
///
/// **Group Member Management ViewModel Features:**
/// - **Advanced Friend Selection**: Dynamic member selection with search functionality and visual feedback
/// - **Intelligent Availability Filtering**: Smart filtering of available friends excluding existing members and pending invitations
/// - **Comprehensive Invitation System**: Email invitation sending with status tracking and delivery coordination
/// - **Real-Time Search Functionality**: Live search across friend names and profiles with instant results
/// - **Swedish Localization**: Complete Swedish language support for member management operations and error messages
///
/// **Usage Examples:**
/// ```dart
/// // Initialize group member addition ViewModel with group and service integration
/// final addMembersViewModel = AddMembersToGroupViewModel(
///   groupId: 'group_123',
///   friendsService: ServiceLocator.get<UnifiedFriendsService>(),
/// );
/// 
/// // Search and filter available friends
/// addMembersViewModel.updateSearch('Anna');
/// final searchResults = addMembersViewModel.filteredFriends;
/// addMembersViewModel.clearSearch(); // Clear search results
/// 
/// // Friend selection and management
/// addMembersViewModel.toggleFriendSelection('friend_456'); // Select Anna
/// addMembersViewModel.toggleFriendSelection('friend_789'); // Select Erik
/// addMembersViewModel.selectAllVisible(); // Select all visible friends
/// addMembersViewModel.clearAllSelections(); // Clear all selections
/// 
/// // Selection state monitoring
/// if (addMembersViewModel.hasSelectedFriends) {
///   final selectedCount = addMembersViewModel.selectedCount;
///   final selectedFriends = addMembersViewModel.selectedFriends;
///   // Enable invitation sending
/// }
/// 
/// // Send invitations with personalized message
/// final sent = await addMembersViewModel.sendInvitations(
///   personalMessage: 'Hej! Jag bjuder in dig till vår receptgrupp!',
/// );
/// if (sent) {
///   // Navigate back or show success message
/// } else if (addMembersViewModel.invitationError != null) {
///   // Handle invitation sending error
/// }
/// 
/// // Monitor invitation sending progress
/// if (addMembersViewModel.isSendingInvitations) {
///   // Show sending progress indicator
/// }
/// 
/// // Check individual invitation status
/// final status = addMembersViewModel.getInvitationStatusForUser('friend_456');
/// final hasInvitation = addMembersViewModel.hasExistingInvitation('friend_789');
/// 
/// // State monitoring and error handling
/// if (addMembersViewModel.isLoading) {
///   // Show loading indicator
/// } else if (addMembersViewModel.hasError) {
///   // Display error message
///   addMembersViewModel.clearError(); // Clear error state
/// } else if (addMembersViewModel.showEmptyState) {
///   // Show empty state when no friends available
/// }
/// 
/// // Access group and friend information
/// final groupName = addMembersViewModel.groupName;
/// final availableCount = addMembersViewModel.availableFriendsCount;
/// final canSend = addMembersViewModel.canSendInvitations;
/// 
/// // Refresh data for pull-to-refresh functionality
/// await addMembersViewModel.refresh();
/// ```

// lib/viewmodels/add_members_to_group_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/models/friend_category.dart';
import 'package:butlery/models/user_profile.dart';
import 'package:butlery/models/group_invitation.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/utils/logger.dart';

/// Comprehensive group member management ViewModel providing advanced member addition through service integration.
///
/// Manages group member addition state enabling social group expansion with friend invitation, member selection,
/// search functionality, and invitation status tracking while maintaining clean MVVM architecture
/// separation between group member management business logic and UI presentation concerns.
///
/// **Core Responsibilities:**
/// - Advanced friend selection with search functionality and availability filtering
/// - Comprehensive invitation management with email sending and status tracking
/// - Real-time search coordination with friend filtering and availability management
/// - Complete state management with loading states and comprehensive error handling
/// - Swedish localized error messages and user feedback coordination throughout member operations
class AddMembersToGroupViewModel extends ChangeNotifier {
  final UnifiedFriendsService _friendsService;

  // ===== GROUP INFORMATION STATE =====

  /// Target group identifier for member addition and invitation coordination.
  /// 
  /// Stores the group ID for all group member operations enabling
  /// group-specific functionality and invitation targeting.
  final String groupId;
  
  /// Current group data for display and member management operations.
  /// 
  /// Stores loaded group information enabling group name display,
  /// member validation, and group-specific functionality coordination.
  FriendCategory? _group;

  // ===== FRIEND AVAILABILITY STATE =====

  /// Complete list of available friends for invitation excluding existing members.
  /// 
  /// Stores all friends who can be invited to the group after filtering out
  /// current members and those with pending invitations.
  List<UserProfile> _availableFriends = [];
  
  /// Filtered friends list based on search criteria for display coordination.
  /// 
  /// Stores search-filtered friend results enabling responsive search functionality
  /// and friend discovery throughout member addition interface operations.
  List<UserProfile> _filteredFriends = [];
  
  /// Current search query for friend filtering and discovery functionality.
  /// 
  /// Stores user search input enabling friend search functionality
  /// and content discovery throughout member addition operations.
  String _searchQuery = '';

  // ===== MEMBER SELECTION STATE =====

  /// Selected friend IDs for invitation sending and member addition coordination.
  /// 
  /// Stores selected friends for invitation enabling selection management,
  /// invitation coordination, and member addition functionality.
  final Set<String> _selectedFriendIds = {};

  // ===== INVITATION MANAGEMENT STATE =====

  /// Invitation sending operation state for UI progress indication during sending operations.
  /// 
  /// Indicates active invitation sending for loading indicators and interaction
  /// control during invitation processing and delivery operations.
  bool _isSendingInvitations = false;
  
  /// Invitation error message for specific invitation error handling and user feedback.
  /// 
  /// Provides specialized error messages for invitation sending failures
  /// enabling targeted error display and invitation operation recovery.
  String? _invitationError;
  
  /// Individual invitation status tracking for detailed invitation management.
  /// 
  /// Maps user IDs to invitation status enabling individual invitation tracking,
  /// status display, and comprehensive invitation management coordination.
  final Map<String, String> _invitationStatus = {}; // userId -> status

  // ===== GENERAL STATE MANAGEMENT =====

  /// Loading state for UI progress indication during data operations.
  /// 
  /// Indicates active data loading for loading indicators and interaction
  /// control during initialization and data synchronization processes.
  bool _isLoading = false;
  
  /// Error message for user feedback and comprehensive error state management.
  /// 
  /// Provides localized error messages for user display and error recovery
  /// throughout group member management operations.
  String? _error;

  /// Initializes group member management ViewModel with comprehensive service integration and group targeting.
  /// 
  /// [groupId] Target group identifier for member addition and invitation operations
  /// [friendsService] UnifiedFriendsService instance for friend management and invitation coordination
  /// 
  /// Establishes group member addition infrastructure with friends service integration, enabling comprehensive
  /// member invitation functionality with friend selection, search capabilities, and invitation status tracking
  /// through unified state management and reactive coordination.
  /// 
  /// **Initialization Process:**
  /// - UnifiedFriendsService integration for friend management and invitation operations
  /// - Group targeting setup with group ID assignment and validation preparation
  /// - Automatic data initialization with friend loading and availability filtering
  /// - Search and selection state preparation for member addition functionality
  /// - Comprehensive error handling preparation with Swedish localized error message support
  AddMembersToGroupViewModel({
    required this.groupId,
    required UnifiedFriendsService friendsService,
  })  : _friendsService = friendsService {
    AppLogger.info(
        '🔄 Initialiserar AddMembersToGroupViewModel för grupp: $groupId');
    _initializeData();
  }

  // ===== GROUP INFORMATION ACCESSORS =====

  /// Current group data for display and member management operations.
  /// 
  /// Provides access to loaded group information enabling group display,
  /// member validation, and group-specific functionality coordination.
  FriendCategory? get group => _group;
  
  /// Group name for display with fallback handling and user-friendly presentation.
  /// 
  /// Provides group name with fallback to generic "Grupp" label ensuring
  /// consistent UI display and Swedish localized group identification.
  String get groupName => _group?.name ?? 'Grupp';

  // ===== FRIEND AVAILABILITY ACCESSORS =====

  /// Complete list of available friends for invitation coordination and display management.
  /// 
  /// Provides immutable access to available friends enabling UI display,
  /// invitation planning, and member addition functionality.
  List<UserProfile> get availableFriends =>
      List.unmodifiable(_availableFriends);
      
  /// Filtered friends list based on search criteria for display and interaction coordination.
  /// 
  /// Provides immutable access to search-filtered friends enabling UI rendering,
  /// search results display, and friend selection functionality.
  List<UserProfile> get filteredFriends => List.unmodifiable(_filteredFriends);
  
  /// Available friends count for UI display and empty state management.
  /// 
  /// Provides count of available friends enabling member count display,
  /// UI state management, and availability indication.
  int get availableFriendsCount => _availableFriends.length;

  // ===== SEARCH STATE ACCESSORS =====

  /// Current search query for search input display and query management.
  /// 
  /// Provides access to active search query enabling search input field
  /// synchronization and search state management throughout friend filtering.
  String get searchQuery => _searchQuery;
  
  /// Search query presence indicator for UI conditional rendering and search state management.
  /// 
  /// Indicates whether search is active for UI conditional display
  /// and search state management throughout friend filtering operations.
  bool get hasSearchQuery => _searchQuery.isNotEmpty;
  

  // ===== MEMBER SELECTION ACCESSORS =====

  /// Selected friend IDs for invitation coordination and selection management.
  /// 
  /// Provides immutable access to selected friend IDs enabling UI display,
  /// selection tracking, and invitation coordination.
  Set<String> get selectedFriendIds => Set.unmodifiable(_selectedFriendIds);
  
  /// Selected friends profiles for invitation display and member management.
  /// 
  /// Provides complete friend profiles for selected members enabling
  /// invitation display and comprehensive member information access.
  List<UserProfile> get selectedFriends => _filteredFriends
      .where((friend) => _selectedFriendIds.contains(friend.uid))
      .toList();
      
  /// Selected friends count for display and UI coordination.
  /// 
  /// Provides count of selected friends enabling selection count display,
  /// UI state management, and invitation planning throughout member operations.
  int get selectedCount => _selectedFriendIds.length;
  
  /// Selected friends availability indicator for UI conditional rendering and invitation enabling.
  /// 
  /// Indicates whether friends are selected for UI conditional display
  /// and invitation button enabling throughout member selection operations.
  bool get hasSelectedFriends => _selectedFriendIds.isNotEmpty;

  // ===== INVITATION STATUS ACCESSORS =====

  /// Invitation sending operation state for UI progress indication and interaction control.
  /// 
  /// Indicates whether invitation sending is in progress for loading indicators
  /// and user interaction management during invitation processing operations.
  bool get isSendingInvitations => _isSendingInvitations;
  
  /// Invitation error message for specific invitation error handling and user feedback.
  /// 
  /// Provides access to invitation sending specific errors enabling targeted
  /// error display and invitation operation recovery coordination.
  String? get invitationError => _invitationError;
  
  /// Individual invitation status tracking for detailed invitation management and display.
  /// 
  /// Provides immutable access to invitation status mapping enabling
  /// individual invitation tracking and status display coordination.
  Map<String, String> get invitationStatus =>
      Map.unmodifiable(_invitationStatus);

  // ===== GENERAL STATE ACCESSORS =====

  /// Loading state for UI progress indication and interaction control.
  /// 
  /// Indicates whether data loading is in progress for loading indicators
  /// and user interaction management during data synchronization.
  bool get isLoading => _isLoading;
  
  /// Error message for user feedback and comprehensive error state management.
  /// 
  /// Provides access to current error state enabling error display
  /// and recovery coordination throughout member management operations.
  String? get error => _error;
  
  /// Error state indicator for UI conditional rendering and error handling.
  /// 
  /// Indicates presence of errors for UI error display decisions
  /// and error state management throughout member operations.
  bool get hasError => _error != null;

  // ===== UI STATE HELPERS =====

  /// Invitation sending capability indicator for UI control and interaction management.
  /// 
  /// Indicates whether invitation sending is available based on selection state
  /// and sending status enabling invitation button state management.
  bool get canSendInvitations => hasSelectedFriends && !_isSendingInvitations;
  
  /// Empty state indicator for UI conditional rendering and empty state display.
  /// 
  /// Indicates whether empty state should be shown when no friends are available
  /// enabling empty state display and user guidance coordination.
  bool get showEmptyState => _filteredFriends.isEmpty && !_isLoading;

  // ===== INITIALIZATION =====

  Future<void> _initializeData() async {
    try {
      _setLoading(true);
      _clearError();

      // Hämta gruppinformation
      _group = _friendsService.categories.getCategoryById(groupId);
      if (_group == null) {
        _setError('Gruppen hittades inte');
        return;
      }

      // Hämta tillgängliga vänner (som inte redan är medlemmar)
      await _loadAvailableFriends();

      AppLogger.success(
          '✅ AddMembersToGroupViewModel initialiserad för "${_group!.name}"');
    } catch (e) {
      AppLogger.error(
          '❌ Fel vid initialisering av AddMembersToGroupViewModel', e);
      _setError('Kunde inte ladda data: $e');
    } finally {
      _setLoading(false);
    }
  }

  Future<void> _loadAvailableFriends() async {
    if (_group == null) {
      return;
    }

    // Hämta alla vänner
    final allFriends = _friendsService.management.getAllFriends();

    // Filtrera bort befintliga gruppmedlemmar och grupp-ägaren
    final currentMemberIds = _group!.friendUserIds.toSet();
    final currentUserId = _friendsService.currentUserId; // ✅ FIXED: Filter out group owner

    _availableFriends = allFriends
        .where((friend) =>
            !currentMemberIds.contains(friend.uid) &&
            friend.uid != currentUserId) // ✅ FIXED: Prevent owner from inviting themselves
        .toList();

    // ✅ NYTT: Filtrera även bort de som redan har väntande inbjudningar
    _availableFriends = _availableFriends.where((friend) {
      // Kontrollera om det redan finns en väntande inbjudan
      final existingInvitation = _friendsService.invitations.getSentInvitations()
          .where((inv) =>
              inv.toUserId == friend.uid &&
              inv.status == GroupInvitationStatus.pending)
          .isNotEmpty;

      return !existingInvitation;
    }).toList();

    // Sortera alfabetiskt
    _availableFriends.sort((a, b) => a.displayName.compareTo(b.displayName));

    // Uppdatera filtrerad lista
    _applySearchFilter();

    AppLogger.info(
        '👥 ${_availableFriends.length} tillgängliga vänner att bjuda in (efter filtrering av väntande inbjudningar)');
  }

  // ===== SEARCH ACTIONS =====

  /// Uppdatera sökfrågan och filtrera vänner
  void updateSearch(String query) {
    _searchQuery = query.trim().toLowerCase();
    _applySearchFilter();
    notifyListeners();
  }

  /// Rensa sökning
  void clearSearch() {
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
              friend.displayName.toLowerCase().contains(_searchQuery))
          .toList();
    }
  }

  // ===== SELECTION ACTIONS =====

  /// Växla val av vän
  void toggleFriendSelection(String friendId) {
    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
      AppLogger.info('❌ Avmarkerad vän: $friendId');
    } else {
      _selectedFriendIds.add(friendId);
      AppLogger.info('✅ Markerad vän: $friendId');
    }

    notifyListeners();
  }

  /// Kontrollera om en vän är vald
  bool isFriendSelected(String friendId) {
    return _selectedFriendIds.contains(friendId);
  }

  /// Välj alla synliga vänner
  void selectAllVisible() {
    _selectedFriendIds.clear();
    _selectedFriendIds.addAll(_filteredFriends.map((f) => f.uid));
    AppLogger.info(
        '✅ Markerade alla synliga vänner (${_selectedFriendIds.length})');
    notifyListeners();
  }

  /// Rensa alla val
  void clearAllSelections() {
    _selectedFriendIds.clear();
    AppLogger.info('❌ Rensade alla val');
    notifyListeners();
  }

  // ===== INVITATION ACTIONS =====

  /// ✅ UPPDATERAD: Skicka RIKTIGA gruppinbjudningar till valda vänner
  Future<bool> sendInvitations({String? personalMessage}) async {
    if (!canSendInvitations || _group == null) {
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

      // ✅ FIXED: Use proper group invitation method that saves to Firebase
      final results = <String, bool>{};
      for (final userId in selectedUserIds) {
        final success = await _friendsService.invitations.sendGroupInvitationToUser(
          userId: userId,
          groupId: groupId,
          customMessage: personalMessage,
        );
        results[userId] = success;
      }

      // Uppdatera status baserat på resultat
      int successCount = 0;
      int failureCount = 0;

      results.forEach((userId, success) {
        if (success) {
          _invitationStatus[userId] = 'sent';
          successCount++;
        } else {
          _invitationStatus[userId] = 'failed';
          failureCount++;
        }
      });

      // Rapportera resultat
      if (successCount > 0) {
        AppLogger.success(
            '✅ $successCount av ${selectedUserIds.length} gruppinbjudningar skickade');
      }

      if (failureCount > 0) {
        AppLogger.warning('⚠️ $failureCount gruppinbjudningar misslyckades');

        // Visa specifikt fel från UnifiedFriendsService om det finns
        if (_friendsService.hasError) {
          _setInvitationError(_friendsService.error!);
        } else if (successCount == 0 && failureCount > 0) {
          // All invitations failed
          _setInvitationError('Kunde inte skicka gruppinbjudningar. Försök igen senare.');
        }
      }

      // Rensa val efter framgångsrika inbjudningar
      if (successCount > 0) {
        _selectedFriendIds.clear();

        // ✅ NYTT: Ladda om tillgängliga vänner för att ta bort de som nu har väntande inbjudningar
        await _loadAvailableFriends();
      }

      return successCount > 0;
    } catch (e) {
      AppLogger.error('❌ Kritiskt fel vid sändning av gruppinbjudningar', e);
      _setInvitationError('Fel vid sändning av gruppinbjudningar: $e');
      return false;
    } finally {
      _isSendingInvitations = false;
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
    return hasInvitation;
  }

  /// ✅ NYTT: Hämta information om skickade inbjudningar för denna grupp
  List<dynamic> getSentInvitationsForGroup() {
    final invitations = _friendsService.invitations.getSentInvitations()
        .where((inv) => inv.groupId == groupId)
        .toList();
    return invitations;
  }

  /// Refresh data
  Future<void> refresh() async {
    AppLogger.info('🔄 Refreshar AddMembersToGroupViewModel data');

    // ✅ NYTT: Refresha även UnifiedFriendsService
    await _friendsService.refresh();

    await _initializeData();
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

  void _setInvitationError(String message) {
    _invitationError = message;
    notifyListeners();
  }

  void _clearInvitationError() {
    _invitationError = null;
  }

  /// Rensa fel
  void clearError() {
    _clearError();
    _clearInvitationError();
    notifyListeners();
  }

  @override
  void dispose() {
    AppLogger.info('🗑️ Disposing AddMembersToGroupViewModel');
    super.dispose();
  }
}
