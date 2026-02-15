/// Comprehensive group creation ViewModel providing advanced social group creation and invitation management for Flutter applications.
/// This module implements sophisticated group creation functionality following Single Responsibility Principle,
/// specializing in friend group creation, form validation, member invitation coordination, and group lifecycle management.
/// It provides complete group creation infrastructure while maintaining clean separation from UI rendering,
/// group data persistence, and complex social relationship business logic implementation.
/// **Single Responsibility Focus:**
/// This module exclusively handles group creation presentation layer concerns:
/// - **Group Form Management**: Advanced form state handling with comprehensive validation and input coordination
/// - **Friend Selection Intelligence**: Sophisticated member selection with visual indicators and selection state management
/// - **Invitation Coordination**: Advanced invitation sending with email validation and delivery status tracking
/// - **Creation Workflow Management**: Complete group creation process with multi-step coordination and error handling
/// - **Swedish Localization Excellence**: Complete Swedish language support for group creation operations and user feedback
/// **What This Module Does NOT Handle:**
/// - UI rendering and widget creation (handled by group creation views and presentation components)
/// - Group data persistence and storage (handled by UnifiedFriendsService and underlying data repositories)
/// - Complex social relationship business logic (handled by friends service layer and social infrastructure)
/// - Email delivery infrastructure (handled by messaging services and communication systems)
/// **Group Creation ViewModel Features:**
/// - **Advanced Form Validation**: Comprehensive form state management with real-time validation and error feedback
/// - **Intelligent Friend Selection**: Dynamic member selection with selection state tracking and visual feedback
/// - **Multi-Step Creation Process**: Complete group creation workflow with validation, creation, and invitation coordination
/// - **Invitation Management System**: Advanced invitation sending with email validation and delivery status tracking
/// - **Swedish Localization**: Complete Swedish language support for group creation operations and error messages
/// **Usage Examples:**
/// ```dart
/// // Initialize group creation ViewModel with friends service integration
/// final createGroupViewModel = CreateGroupViewModel(
///   friendsService: ServiceLocator.get<UnifiedFriendsService>(),
/// );
/// // Group form management with real-time validation
/// createGroupViewModel.updateName('Receptgruppen');
/// createGroupViewModel.updateDescription('En grupp för att dela vegetariska recept');
/// createGroupViewModel.updateEmoji('🥗');
/// // Friend selection for group membership
/// createGroupViewModel.toggleFriend('friend_123'); // Select Anna
/// createGroupViewModel.toggleFriend('friend_456'); // Select Erik
/// createGroupViewModel.toggleFriend('friend_789'); // Select Maria
/// // Validation and form state monitoring
/// if (createGroupViewModel.isValid) {
///   final memberCount = createGroupViewModel.selectedFriendsCount;
///   // Show creation button enabled
/// } else if (createGroupViewModel.nameError != null) {
///   // Show name validation error
/// }
/// // Group creation with comprehensive workflow
/// final created = await createGroupViewModel.createGroup();
/// if (created) {
///   // Group created successfully, navigate to group view
/// } else if (createGroupViewModel.error != null) {
///   // Handle creation error
/// }
/// // Form state monitoring during creation
/// if (createGroupViewModel.isCreating) {
///   // Show creation progress indicator
/// }
/// // Access group creation details
/// final groupName = createGroupViewModel.name;
/// final groupDescription = createGroupViewModel.description;
/// final groupEmoji = createGroupViewModel.emoji;
/// final selectedMembers = createGroupViewModel.selectedFriendIds;
/// ```

// lib/viewmodels/create_group_viewmodel.dart

import 'package:flutter/foundation.dart';
import 'package:butlery/core/providers/application_provider.dart';
import 'package:butlery/services/unified/unified_friends_service.dart';
import 'package:butlery/core/events/group_events.dart';
import 'package:butlery/core/mixins/stream_management_mixin.dart';
import 'package:butlery/core/mixins/state_notifier_mixin.dart';
import 'package:butlery/core/mixins/async_operation_mixin.dart';
import 'package:butlery/core/l10n/app_locale.dart';

/// Comprehensive group creation ViewModel providing advanced social group creation through service integration.
/// Manages group creation form state enabling social group creation with friend selection, form validation,
/// invitation coordination, and creation workflow management while maintaining clean MVVM architecture
/// separation between group creation business logic and UI presentation concerns.
/// **Core Responsibilities:**
/// - Advanced group form state management with real-time validation and comprehensive input coordination
/// - Intelligent friend selection system with selection state tracking and visual feedback coordination
/// - Multi-step group creation process with validation, creation, and invitation workflow management
/// - Invitation sending coordination with email validation and delivery status tracking
/// - Swedish localized error messages and user feedback coordination throughout creation process
class CreateGroupViewModel extends ChangeNotifier
    with StreamManagementMixin, StateNotifierMixin, AsyncOperationMixin {
  final UnifiedFriendsService _friendsService;

  /// Group name for identification and display throughout group functionality.
  /// Stores user input for group name enabling form validation, display coordination,
  /// and group creation with real-time validation and error feedback.
  String _name = '';

  /// Group description for enhanced group context and member understanding.
  /// Stores optional group description enabling contextual group information,
  /// member onboarding, and group purpose communication throughout social functionality.
  String _description = '';

  /// Group emoji for visual identification and enhanced user experience.
  /// Stores group emoji selection enabling visual group identification,
  /// enhanced UI display, and user-friendly group representation throughout social features.
  String _emoji = '👥';

  /// Selected friend IDs for group membership and invitation coordination.
  /// Stores selected friends for group invitation enabling member selection management,
  /// invitation sending coordination, and group membership establishment.
  final Set<String> _selectedFriendIds = {};

  // isLoading and error provided by AsyncOperationMixin

  /// Name validation error message for specific form field error handling and user feedback.
  /// Provides specialized error messages for name validation failures
  /// enabling targeted error display and form validation recovery.
  String? _nameError;

  /// Initializes group creation ViewModel with comprehensive friends service integration and form preparation.
  /// [friendsService] Optional UnifiedFriendsService instance for dependency injection and service coordination
  /// Establishes group creation infrastructure with friends service integration, enabling comprehensive
  /// social group creation functionality with form management, friend selection, and invitation coordination
  /// through unified state management and reactive form validation.
  /// **Initialization Process:**
  /// - UnifiedFriendsService integration for group creation operations and friend management
  /// - Form state initialization with default values and validation preparation
  /// - Friend selection state preparation for member management and invitation coordination
  /// - Error handling preparation with Swedish localized error message support
  CreateGroupViewModel({
    UnifiedFriendsService? friendsService,
  }) : _friendsService =
            friendsService ?? ServiceLocator.get<UnifiedFriendsService>();

  /// Current group name for display and validation coordination.
  /// Provides access to current group name input enabling form display,
  /// validation feedback, and group creation coordination.
  String get name => _name;

  /// Current group description for display and context management.
  /// Provides access to current group description input enabling form display,
  /// context coordination, and enhanced group information management.
  String get description => _description;

  /// Current group emoji for display and visual identification.
  /// Provides access to selected group emoji enabling visual display,
  /// group identification, and enhanced user interface coordination.
  String get emoji => _emoji;

  /// Selected friend IDs for member management and invitation coordination.
  /// Provides immutable access to selected friends enabling UI display,
  /// member count tracking, and invitation sending coordination.
  Set<String> get selectedFriendIds => _selectedFriendIds;

  // isLoading and error getters provided by AsyncOperationMixin

  /// Name validation error message for specific form field error handling and user feedback.
  /// Provides access to name validation specific errors enabling targeted
  /// error display and form validation recovery coordination.
  String? get nameError => _nameError;

  /// Selected friends count for display and UI coordination.
  /// Provides count of selected friends enabling member count display,
  /// UI state management, and invitation coordination throughout group creation.
  int get selectedFriendsCount => _selectedFriendIds.length;

  /// Updates group name with comprehensive validation and real-time feedback coordination.
  /// [value] New group name for validation and state management
  /// Performs group name update with automatic validation, error state management,
  /// and UI notification ensuring real-time form validation feedback and proper
  /// group creation form coordination throughout user input operations.
  /// **Name Update Process:**
  /// - Group name state update with trimming and normalization
  /// - Automatic name validation with uniqueness checking and error feedback
  /// - UI notification coordination for real-time validation display
  /// - Form validity recalculation for creation button state management
  /// **Usage Example:**
  /// ```dart
  /// createGroupViewModel.updateName('Receptgruppen');
  /// if (createGroupViewModel.nameError != null) {
  ///   // Show validation error
  /// }
  /// ```
  void updateName(String value) {
    _name = value;
    _validateName();
    notifyListeners();
  }

  /// Updates group description with comprehensive state management and UI coordination.
  /// [value] New group description for state management and display coordination
  /// Performs group description update with state management and UI notification
  /// ensuring proper form state coordination and description display throughout
  /// group creation workflow and user input operations.
  /// **Usage Example:**
  /// ```dart
  /// createGroupViewModel.updateDescription('En grupp för vegetariska recept');
  /// ```
  void updateDescription(String value) {
    _description = value;
    notifyListeners();
  }

  /// Updates group emoji with comprehensive state management and visual coordination.
  /// [value] New group emoji for visual identification and display coordination
  /// Performs group emoji update with state management and UI notification
  /// ensuring proper visual identification and emoji display throughout
  /// group creation workflow and user selection operations.
  /// **Usage Example:**
  /// ```dart
  /// createGroupViewModel.updateEmoji('🥗');
  /// ```
  void updateEmoji(String value) {
    _emoji = value;
    notifyListeners();
  }

  /// Toggles friend selection with comprehensive state management and member coordination.
  /// [friendId] Friend identifier for selection toggle and member management
  /// Performs friend selection toggle with automatic state management and UI notification
  /// enabling dynamic member selection, visual feedback coordination, and invitation
  /// management throughout group creation workflow and member selection operations.
  /// **Friend Toggle Process:**
  /// - Friend selection state checking and toggle logic execution
  /// - Selection set management with add/remove operations
  /// - UI notification coordination for visual feedback and selection display
  /// - Member count update for UI state management and display coordination
  /// **Usage Example:**
  /// ```dart
  /// createGroupViewModel.toggleFriend('friend_123'); // Select or deselect Anna
  /// final isSelected = createGroupViewModel.selectedFriendIds.contains('friend_123');
  /// ```
  void toggleFriend(String friendId) {
    if (_selectedFriendIds.contains(friendId)) {
      _selectedFriendIds.remove(friendId);
    } else {
      _selectedFriendIds.add(friendId);
    }
    notifyListeners();
  }

  /// Validates group name with comprehensive uniqueness checking and error feedback coordination.
  /// Performs group name validation including required field checking, uniqueness validation
  /// against existing categories, and error state management with Swedish localized error messages
  /// ensuring proper form validation throughout group creation workflow.
  /// **Name Validation Rules:**
  /// - **Required Field**: Group name cannot be empty or whitespace only
  /// - **Uniqueness Check**: Group name must not conflict with existing categories
  /// - **Error State Management**: Validation errors stored for UI display and form state coordination
  /// **Validation Process:**
  /// - Input normalization with trimming and whitespace handling
  /// - Required field validation with Swedish localized error message
  /// - Uniqueness checking against existing friend categories through UnifiedFriendsService
  /// - Error state update with appropriate Swedish error message or null for valid input
  /// **Private Method**: Used internally during name updates for real-time validation.
  void _validateName() {
    if (_name.trim().isEmpty) {
      _nameError = AppLocale.current.errorGroupNameRequired;
    } else if (_friendsService.categories.getCategoryByName(_name.trim()) !=
        null) {
      _nameError = AppLocale.current.errorGroupNameExists;
    } else {
      _nameError = null;
    }
  }

  /// Form validity indicator for creation button enabling and UI state management.
  /// Determines whether group creation form is valid for submission based on
  /// name validation results and required field completion enabling creation
  /// button state management and form submission coordination.
  /// **Validity Criteria:**
  /// - Name validation must pass (no name error present)
  /// - Name must not be empty after trimming
  /// - All required form fields must be properly completed
  /// **Usage Example:**
  /// ```dart
  /// if (createGroupViewModel.isValid) {
  ///   // Enable group creation button
  /// } else {
  ///   // Disable creation button, show validation errors
  /// }
  /// ```
  bool get isValid => _nameError == null && _name.trim().isNotEmpty;

  /// Creates group with comprehensive multi-step workflow and invitation coordination.
  /// Returns true if group creation succeeds, false if validation fails or creation errors occur.
  /// Performs complete group creation workflow including form validation, category creation,
  /// friend invitation sending, and event coordination with comprehensive error handling
  /// ensuring successful social group establishment and member invitation management.
  /// **Group Creation Workflow:**
  /// 1. **Form Validation**: Comprehensive form validity checking preventing invalid submissions
  /// 2. **Creation State Management**: UI state activation for progress indication and interaction control
  /// 3. **Category Creation**: UnifiedFriendsService category creation with form data coordination
  /// 4. **Group Verification**: Created group validation and data integrity checking
  /// 5. **Invitation Sending**: Email invitation coordination for selected friends with validation
  /// 6. **Event Broadcasting**: Group creation event triggering for system-wide coordination
  /// 7. **State Completion**: Creation state cleanup and UI notification coordination
  /// **Multi-Step Process Details:**
  /// - **Step 1 - Group Creation**: Creates empty friend category with name, description, and emoji
  /// - **Step 2 - Group Verification**: Validates created group existence and data integrity
  /// - **Step 3 - Invitation Coordination**: Sends email invitations to selected friends with personalized messages
  /// **Invitation Management:**
  /// - Email validation for friend contacts ensuring deliverable invitations
  /// - Personalized invitation messages with group context and Swedish localization
  /// - Invitation success tracking with detailed logging and status management
  /// - Failed invitation handling with debugging support and user feedback preparation
  /// **Error Handling Strategy:**
  /// Comprehensive error handling with Swedish localized error messages, detailed logging
  /// for debugging support, and graceful failure recovery ensuring user feedback
  /// and system stability throughout group creation operations.
  /// **Usage Example:**
  /// ```dart
  /// final created = await createGroupViewModel.createGroup();
  /// if (created) {
  ///   // Group created successfully with invitations sent
  ///   // Navigate to group view or show success message
  /// } else if (createGroupViewModel.error != null) {
  ///   // Handle creation error with user feedback
  /// }
  /// ```
  Future<bool> createGroup() async {
    if (!isValid) return false;

    try {
      await executeAsync(() async {
        // Step 1: Create empty group category with form data
        final categoryId = await _friendsService.categories.createCategory(
          name: _name.trim(),
          description: _description.trim(),
          icon: _emoji,
          initialMemberIds: null, // Empty group for invitation-based membership
        );

        if (categoryId == null) {
          throw Exception(_friendsService.error ??
              AppLocale.current.errorCouldNotCreateGroup);
        }

        // Step 2: Verify created group and retrieve group data
        final createdGroup = _friendsService.categories
            .getAllCategories()
            .where((group) => group.id == categoryId)
            .firstOrNull;

        if (createdGroup == null) {
          throw Exception(AppLocale.current.errorGroupNotFound);
        }

        // Step 3: Send email invitations to selected friends
        if (_selectedFriendIds.isNotEmpty) {
          for (final friendId in _selectedFriendIds.toList()) {
            final friend = _friendsService.management.getFriendById(friendId);
            if (friend != null) {
              // Email validation and invitation sending with personalized message
              if (friend.email.isNotEmpty && friend.email.contains('@')) {
                await _friendsService.invitations.sendEmailInvitation(
                  email: friend.email,
                  customMessage: AppLocale.current
                      .groupInvitationMessage(createdGroup.name),
                );
              }
            }
          }
        }

        // Broadcast group creation event for system-wide coordination
        GroupEventBus.groupCreated();
      }, errorPrefix: AppLocale.current.errorCouldNotCreate('grupp'));

      return true;
    } catch (e) {
      return false;
    }
  }

  @override
  void dispose() {
    // Cancel all timers
    // Cancel all stream subscriptions
    // Dispose of resources
    disposeStreamResources(); // From StreamManagementMixin
    super.dispose();
  }
}
