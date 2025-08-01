/// Comprehensive realtime invitation model providing advanced invitation management for collaborative resource sharing.
///
/// This model implements sophisticated invitation lifecycle management following Single Responsibility Principle,
/// handling all aspects of realtime resource invitations including status tracking, temporal management, notification
/// generation, and comprehensive UI support. It provides complete invitation management capabilities while maintaining
/// clean separation from UI concerns and resource-specific business logic.
///
/// **Single Responsibility Focus:**  
/// This model exclusively handles realtime invitation representation and lifecycle management:
/// - **Invitation Lifecycle**: Complete status management from creation through acceptance, rejection, or expiration
/// - **Temporal Management**: Advanced time-based operations including expiration tracking and user-friendly time displays
/// - **Notification Integration**: Rich notification content generation with Swedish localization for optimal user experience
/// - **State Transitions**: Immutable state transition methods for accepting, rejecting, cancelling, and expiring invitations
///
/// **What This Model Does NOT Handle:**
/// - Invitation delivery and notification services (handled by messaging and notification services)
/// - Resource access control and permission enforcement (handled by permission services and resource managers)
/// - UI presentation and interaction handling (handled by ViewModels and UI components)
/// - Firebase persistence operations (handled by invitation repositories and database services)
///
/// **Realtime Invitation Features:**
/// - **Comprehensive Status Tracking**: Full invitation lifecycle with pending, accepted, rejected, expired, and cancelled states
/// - **Temporal Intelligence**: Advanced time management with expiration tracking, urgency detection, and user-friendly displays
/// - **Multi-Target Support**: Integration with InvitationTarget for both individual and group invitation capabilities
/// - **Swedish Localization**: Complete Swedish language support for notifications, status messages, and time displays
/// - **Rich UI Integration**: Comprehensive UI helper methods for icons, descriptions, and status presentations
///
/// **Usage Examples:**
/// ```dart
/// // Create a new realtime invitation
/// final invitation = RealtimeInvitation.create(
///   resourceType: RealtimeResourceType.recipe,
///   resourceId: 'recipe_123',
///   resourceTitle: 'Mormors köttbullar',
///   fromUserId: currentUserId,
///   fromUserDisplayName: 'Anna Andersson',
///   target: InvitationTarget.individual(friend),
///   message: 'Vill du laga denna tillsammans?',
///   permissionLevel: 'editor',
///   expiresIn: Duration(days: 3),
/// );
/// 
/// // Check invitation status and respond
/// if (invitation.canRespond) {
///   final acceptedInvitation = invitation.accept();
///   await invitationService.updateInvitation(acceptedInvitation);
/// }
/// 
/// // Generate notification content
/// showNotification(
///   title: invitation.notificationTitle,
///   message: invitation.notificationDescription,
///   icon: invitation.resourceIcon,
/// );
/// 
/// // Display invitation in UI
/// InvitationCard(
///   title: invitation.shortDescription,
///   status: invitation.statusText,
///   statusIcon: invitation.statusIcon,
///   timeInfo: invitation.expiresSoon ? invitation.expiresInText : invitation.timeAgoText,
///   message: invitation.message,
/// );
/// ```

// lib/models/invitations/realtime_invitation.dart

// ✅ FIXED: Abstracted Firebase dependencies to repository layer
import 'package:uuid/uuid.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/invitations/invitation_target.dart';


/// Enumeration defining comprehensive invitation status lifecycle for realtime resource collaboration.
///
/// Provides complete status classification for invitation lifecycle management with temporal
/// awareness and clear status progression from creation through resolution or expiration.
enum RealtimeInvitationStatus {
  /// Pending response status indicating the invitation awaits recipient action.
  ///
  /// Initial status for new invitations, remains active until recipient responds
  /// or invitation expires. Enables response actions and UI prompt displays.
  pending,

  /// Accepted status indicating successful invitation acceptance and resource access granted.
  ///
  /// Terminal status achieved when recipient accepts the invitation, enabling
  /// resource access and collaborative participation initiation.
  accepted,

  /// Rejected status indicating invitation was declined by the recipient.
  ///
  /// Terminal status when recipient explicitly declines participation, preventing
  /// further response actions while maintaining invitation history for analytics.
  rejected,

  /// Expired status indicating automatic expiration due to time limit exceeded.
  ///
  /// Terminal status achieved when invitation passes expiration time without response,
  /// preventing delayed responses while preserving invitation audit trail.
  expired,

  /// Cancelled status indicating sender revoked the invitation before response.
  ///
  /// Terminal status when invitation sender cancels the invitation, preventing
  /// recipient responses and indicating resource access is no longer available.
  cancelled,
}

/// Comprehensive realtime invitation with lifecycle management and collaborative resource integration.
///
/// Represents a complete invitation to participate in realtime collaborative resources with comprehensive
/// status tracking, temporal management, and rich UI integration. Supports both individual and group
/// invitations with expiration handling and immutable state transitions for reliable invitation workflow.
class RealtimeInvitation {
  /// Unique identifier for this invitation instance.
  ///
  /// Auto-generated UUID ensuring unique identification across all invitation systems
  /// and enabling reliable tracking throughout the invitation lifecycle.
  final String id;

  /// Type classification of the collaborative resource being shared.
  ///
  /// Determines the resource category (recipe, menu, shopping list) for appropriate
  /// invitation handling, UI presentation, and notification generation.
  final RealtimeResourceType resourceType;

  /// Unique identifier of the specific resource being shared.
  ///
  /// References the exact resource instance that recipients will gain access to
  /// upon invitation acceptance, enabling direct resource navigation and access.
  final String resourceId;

  /// Cached display title of the resource for UI performance optimization.
  ///
  /// Stored locally to avoid additional resource lookups during invitation display,
  /// notification generation, and user interface presentation operations.
  final String resourceTitle;

  /// User identifier of the invitation sender for attribution and permissions.
  ///
  /// References the user who created and sent the invitation, used for permission
  /// validation, sender attribution, and invitation management operations.
  final String fromUserId;

  /// Cached display name of the invitation sender for UI performance optimization.
  ///
  /// Stored locally to avoid additional user profile lookups during invitation display,
  /// notification generation, and sender attribution in user interfaces.
  final String fromUserDisplayName;

  /// Invitation target supporting both individual users and group recipients.
  ///
  /// Unified target system enabling flexible invitation delivery to individual users
  /// or groups with automatic member expansion and comprehensive metadata support.
  final InvitationTarget target;

  /// Current status of the invitation in its lifecycle progression.
  ///
  /// Tracks invitation state from pending through terminal states (accepted, rejected,
  /// expired, cancelled) enabling appropriate UI state and action availability.
  final RealtimeInvitationStatus status;

  /// Timestamp when the invitation was originally sent to recipients.
  ///
  /// Used for chronological tracking, time-based displays, and invitation aging
  /// calculations for user interface presentation and analytics.
  final DateTime sentAt;

  /// Optional timestamp when the invitation received a response from recipients.
  ///
  /// Set when invitation transitions to terminal state (accepted, rejected, expired,
  /// cancelled) for response time tracking and invitation lifecycle analytics.
  final DateTime? respondedAt;

  /// Timestamp when the invitation will automatically expire and become invalid.
  ///
  /// Defines invitation validity period with automatic expiration handling,
  /// urgency detection, and time-remaining calculations for user interface displays.
  final DateTime expiresAt;

  /// Optional personal message from the sender to recipients.
  ///
  /// Allows invitation customization with personal context, collaboration intent,
  /// or specific instructions for enhanced invitation communication and user experience.
  final String? message;

  /// Permission level that recipients will receive upon invitation acceptance.
  ///
  /// Defines collaboration capabilities ('editor' or 'viewer') that recipients will have
  /// in the shared resource, enabling appropriate access control and feature availability.
  final String permissionLevel; // 'editor' eller 'viewer'

  /// Flexible metadata container for invitation-specific information and future extensions.
  ///
  /// Extensible storage for additional invitation data, analytics information,
  /// or feature-specific metadata without requiring schema modifications.
  final Map<String, dynamic> metadata;

  /// Creates a new realtime invitation with comprehensive configuration and automatic defaults.
  ///
  /// This constructor provides complete invitation initialization with support for all invitation
  /// features including custom expiration, permission levels, and metadata. Automatic ID generation
  /// and timestamp handling ensure consistent invitation creation with proper defaults.
  ///
  /// [id] Optional custom identifier, auto-generated UUID if not provided
  /// [resourceType] Required resource type classification for invitation targeting
  /// [resourceId] Required unique identifier of the resource being shared
  /// [resourceTitle] Required display title of the resource for UI presentation
  /// [fromUserId] Required sender user ID for attribution and permission validation
  /// [fromUserDisplayName] Required sender display name for UI presentation
  /// [target] Required invitation target supporting individual users and groups
  /// [status] Initial invitation status, defaults to pending for new invitations
  /// [sentAt] Optional send timestamp, defaults to current time for new invitations
  /// [respondedAt] Optional response timestamp for invitation lifecycle tracking
  /// [expiresAt] Optional expiration timestamp, defaults to 7 days from creation
  /// [message] Optional personal message from sender for enhanced communication
  /// [permissionLevel] Permission level for recipients, defaults to 'editor' for full collaboration
  /// [metadata] Optional metadata container for additional invitation information
  RealtimeInvitation({
    String? id,
    required this.resourceType,
    required this.resourceId,
    required this.resourceTitle,
    required this.fromUserId,
    required this.fromUserDisplayName,
    required this.target,
    this.status = RealtimeInvitationStatus.pending,
    DateTime? sentAt,
    this.respondedAt,
    DateTime? expiresAt,
    this.message,
    this.permissionLevel = 'editor',
    this.metadata = const {},
  })  : id = id ?? const Uuid().v4(),
        sentAt = sentAt ?? DateTime.now(),
        expiresAt = expiresAt ?? DateTime.now().add(const Duration(days: 7));

  /// Creates a new realtime invitation with streamlined parameters and intelligent defaults.
  ///
  /// This factory provides simplified invitation creation with intuitive parameter naming
  /// and automatic configuration for common invitation scenarios. Handles timestamp generation
  /// and expiration calculation with flexible duration specification for various invitation types.
  ///
  /// [resourceType] Required resource type classification for invitation targeting
  /// [resourceId] Required unique identifier of the resource being shared
  /// [resourceTitle] Required display title of the resource for UI presentation
  /// [fromUserId] Required sender user ID for attribution and permission validation
  /// [fromUserDisplayName] Required sender display name for UI presentation
  /// [target] Required invitation target supporting individual users and groups
  /// [message] Optional personal message from sender for enhanced communication
  /// [permissionLevel] Permission level for recipients, defaults to 'editor' for full collaboration
  /// [expiresIn] Optional custom expiration duration, defaults to 7 days for standard invitations
  ///
  /// Returns a new [RealtimeInvitation] instance with current timestamps and calculated expiration.
  factory RealtimeInvitation.create({
    required RealtimeResourceType resourceType,
    required String resourceId,
    required String resourceTitle,
    required String fromUserId,
    required String fromUserDisplayName,
    required InvitationTarget target,
    String? message,
    String permissionLevel = 'editor',
    Duration? expiresIn,
  }) {
    return RealtimeInvitation(
      resourceType: resourceType,
      resourceId: resourceId,
      resourceTitle: resourceTitle,
      fromUserId: fromUserId,
      fromUserDisplayName: fromUserDisplayName,
      target: target,
      message: message,
      permissionLevel: permissionLevel,
      expiresAt: DateTime.now().add(expiresIn ?? const Duration(days: 7)),
    );
  }

  /// Status validation methods for invitation lifecycle management and UI state control.

  /// Checks if the invitation is currently pending and awaiting recipient response.
  ///
  /// Returns true only when invitation has pending status and has not expired,
  /// indicating the invitation is actively awaiting response and can still be acted upon.
  bool get isPending =>
      status == RealtimeInvitationStatus.pending && !isExpired;

  /// Checks if the invitation has been accepted by the recipient.
  ///
  /// Returns true when invitation status is accepted, indicating successful
  /// invitation acceptance and resource access should be granted to recipient.
  bool get isAccepted => status == RealtimeInvitationStatus.accepted;

  /// Checks if the invitation has been rejected by the recipient.
  ///
  /// Returns true when invitation status is rejected, indicating recipient
  /// declined participation and no resource access should be granted.
  bool get isRejected => status == RealtimeInvitationStatus.rejected;

  /// Checks if the invitation has been cancelled by the sender.
  ///
  /// Returns true when invitation status is cancelled, indicating sender
  /// revoked the invitation and recipient can no longer respond or access resource.
  bool get isCancelled => status == RealtimeInvitationStatus.cancelled;

  /// Checks if the invitation has expired due to time limit exceeded.
  ///
  /// Returns true when current time exceeds expiration time or status is explicitly
  /// expired, indicating invitation is no longer valid for response or resource access.
  bool get isExpired {
    return DateTime.now().isAfter(expiresAt) ||
        status == RealtimeInvitationStatus.expired;
  }

  /// Checks if the invitation has received any form of response from recipient.
  ///
  /// Returns true when respondedAt timestamp is set, indicating invitation has
  /// transitioned from pending to a terminal state through user or system action.
  bool get isResponded => respondedAt != null;

  /// Checks if the invitation can still be responded to by the recipient.
  ///
  /// Returns true only when invitation is pending and not expired, enabling
  /// response UI elements and preventing responses to invalid invitations.
  bool get canRespond => isPending;

  /// Temporal utility methods for user-friendly time displays and urgency detection.

  /// Gets Swedish-localized text describing how long ago the invitation was sent.
  ///
  /// Provides human-readable time descriptions for invitation age display in UI,
  /// using Swedish language with appropriate time unit selection based on elapsed duration.
  /// Used for invitation list displays and activity timeline presentations.
  ///
  /// Returns Swedish time description from "Nu" for immediate to "X veckor sedan" for old invitations.
  String get timeAgoText {
    final duration = DateTime.now().difference(sentAt);

    if (duration.inMinutes < 1) {
      return 'Nu';
    } else if (duration.inHours < 1) {
      return '${duration.inMinutes} min sedan';
    } else if (duration.inDays < 1) {
      return '${duration.inHours} tim sedan';
    } else if (duration.inDays < 7) {
      return '${duration.inDays} dagar sedan';
    } else {
      return '${(duration.inDays / 7).floor()} veckor sedan';
    }
  }

  /// Gets Swedish-localized text describing time remaining until invitation expires.
  ///
  /// Provides human-readable countdown descriptions for invitation expiration display,
  /// using Swedish language with appropriate urgency indication. Returns "Utgången" for
  /// expired invitations and scaled time units for active invitation time remaining.
  ///
  /// Returns Swedish time remaining description or "Utgången" for expired invitations.
  String get expiresInText {
    if (isExpired) return 'Utgången';

    final duration = expiresAt.difference(DateTime.now());

    if (duration.inDays > 1) {
      return '${duration.inDays} dagar kvar';
    } else if (duration.inHours > 1) {
      return '${duration.inHours} timmar kvar';
    } else if (duration.inMinutes > 1) {
      return '${duration.inMinutes} minuter kvar';
    } else {
      return 'Går ut snart';
    }
  }

  /// Checks if the invitation expires soon requiring urgent attention.
  ///
  /// Determines if invitation will expire within 24 hours, enabling urgent UI styling,
  /// priority notifications, and user attention highlighting for time-sensitive invitations.
  ///
  /// Returns true if invitation expires within 24 hours, false if more time remains.
  bool get expiresSoon {
    final timeLeft = expiresAt.difference(DateTime.now());
    return timeLeft.inHours < 24;
  }

  /// UI integration methods for notification generation and user interface presentation.

  /// Gets Swedish-localized notification title based on resource type for system notifications.
  ///
  /// Provides appropriate notification titles for different resource types enabling
  /// consistent notification presentation across the application with proper Swedish localization.
  ///
  /// Returns Swedish notification title appropriate for the invitation resource type.
  String get notificationTitle {
    switch (resourceType) {
      case RealtimeResourceType.recipe:
        return 'Inbjudan till recept';
      case RealtimeResourceType.menu:
        return 'Inbjudan till meny';
      case RealtimeResourceType.shoppingList:
        return 'Inbjudan till inköpslista';
    }
  }

  /// Gets Swedish-localized notification description with sender and target information.
  ///
  /// Provides comprehensive notification content including sender attribution, target
  /// identification (individual or group), and resource details for rich notification
  /// presentation with proper Swedish grammar and context.
  ///
  /// Returns Swedish notification description with complete invitation context.
  String get notificationDescription {
    final prefix = target.isGroup
        ? '$fromUserDisplayName bjöd in gruppen "${target.displayName}"'
        : '$fromUserDisplayName bjöd in dig';

    final suffix = 'till gemensam ${_getResourceTypeName()}: "$resourceTitle"';

    return '$prefix $suffix';
  }

  /// Gets concise Swedish-localized description for invitation list displays.
  ///
  /// Provides compact invitation description combining resource type and title
  /// for efficient space usage in invitation lists and summary displays.
  ///
  /// Returns Swedish short description with resource type and title.
  String get shortDescription {
    return '${_getResourceTypeName().capitalizeFirst()}: $resourceTitle';
  }

  /// Gets Swedish resource type name for localized text generation.
  String _getResourceTypeName() {
    switch (resourceType) {
      case RealtimeResourceType.recipe:
        return 'recept';
      case RealtimeResourceType.menu:
        return 'meny';
      case RealtimeResourceType.shoppingList:
        return 'inköpslista';
    }
  }

  /// Gets emoji icon representing the resource type for visual UI elements.
  ///
  /// Provides consistent emoji representation for different resource types
  /// enabling visual resource identification in invitation displays and notifications.
  String get resourceIcon {
    switch (resourceType) {
      case RealtimeResourceType.recipe:
        return '🍳';
      case RealtimeResourceType.menu:
        return '📋';
      case RealtimeResourceType.shoppingList:
        return '🛒';
    }
  }

  /// Gets emoji icon representing the current invitation status for visual feedback.
  ///
  /// Provides status-specific emoji icons with expiration awareness for clear
  /// visual status communication in invitation UI elements and status displays.
  String get statusIcon {
    switch (status) {
      case RealtimeInvitationStatus.pending:
        return isExpired ? '⏰' : '⏳';
      case RealtimeInvitationStatus.accepted:
        return '✅';
      case RealtimeInvitationStatus.rejected:
        return '❌';
      case RealtimeInvitationStatus.expired:
        return '⏰';
      case RealtimeInvitationStatus.cancelled:
        return '🚫';
    }
  }

  /// Gets Swedish-localized status text for invitation status display.
  ///
  /// Provides human-readable Swedish status descriptions with expiration awareness
  /// for clear status communication in invitation UI elements and status summaries.
  String get statusText {
    switch (status) {
      case RealtimeInvitationStatus.pending:
        return isExpired ? 'Utgången' : 'Väntande';
      case RealtimeInvitationStatus.accepted:
        return 'Accepterad';
      case RealtimeInvitationStatus.rejected:
        return 'Avvisad';
      case RealtimeInvitationStatus.expired:
        return 'Utgången';
      case RealtimeInvitationStatus.cancelled:
        return 'Avbruten';
    }
  }

  /// Immutable state transition methods for invitation lifecycle management.

  /// Accepts the invitation transitioning to accepted status with response timestamp.
  ///
  /// Creates new invitation instance with accepted status and current response timestamp
  /// for immutable state management and invitation lifecycle tracking.
  RealtimeInvitation accept() {
    return copyWith(
      status: RealtimeInvitationStatus.accepted,
      respondedAt: DateTime.now(),
    );
  }

  /// Rejects the invitation transitioning to rejected status with response timestamp.
  ///
  /// Creates new invitation instance with rejected status and current response timestamp
  /// for immutable state management and invitation lifecycle tracking.
  RealtimeInvitation reject() {
    return copyWith(
      status: RealtimeInvitationStatus.rejected,
      respondedAt: DateTime.now(),
    );
  }

  /// Cancels the invitation transitioning to cancelled status with response timestamp.
  ///
  /// Creates new invitation instance with cancelled status for sender-initiated cancellation,
  /// preventing recipient responses and maintaining invitation audit trail.
  RealtimeInvitation cancel() {
    return copyWith(
      status: RealtimeInvitationStatus.cancelled,
      respondedAt: DateTime.now(),
    );
  }

  /// Expires the invitation transitioning to expired status with response timestamp.
  ///
  /// Creates new invitation instance with expired status for system-initiated expiration,
  /// preventing delayed responses and maintaining invitation lifecycle completeness.
  RealtimeInvitation expire() {
    return copyWith(
      status: RealtimeInvitationStatus.expired,
      respondedAt: DateTime.now(),
    );
  }

  /// Utility methods for invitation manipulation and immutable updates.

  /// Creates a copy of this invitation with updated values while preserving immutability.
  ///
  /// Used for all invitation modifications while maintaining immutable data patterns and ensuring
  /// consistent state management for invitation lifecycle operations and status transitions.
  RealtimeInvitation copyWith({
    String? resourceTitle,
    RealtimeInvitationStatus? status,
    DateTime? respondedAt,
    DateTime? expiresAt,
    String? message,
    String? permissionLevel,
    Map<String, dynamic>? metadata,
  }) {
    return RealtimeInvitation(
      id: id,
      resourceType: resourceType,
      resourceId: resourceId,
      resourceTitle: resourceTitle ?? this.resourceTitle,
      fromUserId: fromUserId,
      fromUserDisplayName: fromUserDisplayName,
      target: target,
      status: status ?? this.status,
      sentAt: sentAt,
      respondedAt: respondedAt ?? this.respondedAt,
      expiresAt: expiresAt ?? this.expiresAt,
      message: message ?? this.message,
      permissionLevel: permissionLevel ?? this.permissionLevel,
      metadata: metadata ?? this.metadata,
    );
  }

  /// Data persistence and serialization methods for Firestore and caching integration.

  /// Converts the invitation to Firestore-compatible format for persistence.
  ///
  /// Transforms all invitation data including target, timestamps, and metadata into Firestore format
  /// with proper field mapping and type preservation for efficient database storage and querying.
  Map<String, dynamic> toFirestore() {
    return {
      'resourceType': resourceType.value,
      'resourceId': resourceId,
      'resourceTitle': resourceTitle,
      'fromUserId': fromUserId,
      'fromUserDisplayName': fromUserDisplayName,
      'target': target.toFirestore(),
      'status': status.name,
      'sentAt': sentAt,
      'respondedAt': respondedAt,
      'expiresAt': expiresAt,
      'message': message,
      'permissionLevel': permissionLevel,
      'metadata': metadata,
    };
  }

  /// Creates an invitation instance from repository data with robust parsing.
  ///
  /// Transforms repository data into a complete RealtimeInvitation instance with proper
  /// type conversion, enum parsing, and fallback handling for missing or invalid data.
  factory RealtimeInvitation.fromMap(String id, Map<String, dynamic> data) {
    return RealtimeInvitation(
      id: id,
      resourceType: RealtimeResourceType.fromString(
        data['resourceType'] as String? ?? 'recipe',
      ),
      resourceId: data['resourceId'] as String,
      resourceTitle: data['resourceTitle'] as String? ?? '',
      fromUserId: data['fromUserId'] as String,
      fromUserDisplayName: data['fromUserDisplayName'] as String? ?? '',
      target: InvitationTarget.fromFirestore(
        data['target'] as Map<String, dynamic>,
      ),
      status: RealtimeInvitationStatus.values.firstWhere(
        (s) => s.name == data['status'],
        orElse: () => RealtimeInvitationStatus.pending,
      ),
      sentAt: _parseDateTime(data['sentAt']) ?? DateTime.now(),
      respondedAt: _parseDateTime(data['respondedAt']),
      expiresAt: _parseDateTime(data['expiresAt']) ??
          DateTime.now().add(const Duration(days: 7)),
      message: data['message'] as String?,
      permissionLevel: data['permissionLevel'] as String? ?? 'editor',
      metadata: Map<String, dynamic>.from(data['metadata'] ?? {}),
    );
  }

  /// Converts the invitation to JSON format for caching and client-side storage.
  ///
  /// Provides JSON serialization for client-side caching, local storage, and data transfer
  /// with complete metadata preservation and ISO timestamp formatting.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'resourceType': resourceType.value,
      'resourceId': resourceId,
      'resourceTitle': resourceTitle,
      'fromUserId': fromUserId,
      'fromUserDisplayName': fromUserDisplayName,
      'target': target.toJson(),
      'status': status.name,
      'sentAt': sentAt.toIso8601String(),
      'respondedAt': respondedAt?.toIso8601String(),
      'expiresAt': expiresAt.toIso8601String(),
      'message': message,
      'permissionLevel': permissionLevel,
      'metadata': metadata,
    };
  }

  /// Creates an invitation instance from JSON data for caching and deserialization.
  ///
  /// Transforms JSON cache data into a complete RealtimeInvitation instance with proper
  /// type conversion and enum parsing for client-side caching support.
  factory RealtimeInvitation.fromJson(Map<String, dynamic> json) {
    return RealtimeInvitation(
      id: json['id'] as String,
      resourceType: RealtimeResourceType.fromString(
        json['resourceType'] as String? ?? 'recipe',
      ),
      resourceId: json['resourceId'] as String,
      resourceTitle: json['resourceTitle'] as String? ?? '',
      fromUserId: json['fromUserId'] as String,
      fromUserDisplayName: json['fromUserDisplayName'] as String? ?? '',
      target: InvitationTarget.fromJson(
        json['target'] as Map<String, dynamic>,
      ),
      status: RealtimeInvitationStatus.values.firstWhere(
        (s) => s.name == json['status'],
        orElse: () => RealtimeInvitationStatus.pending,
      ),
      sentAt: DateTime.parse(json['sentAt'] as String),
      respondedAt: json['respondedAt'] != null
          ? DateTime.parse(json['respondedAt'] as String)
          : null,
      expiresAt: DateTime.parse(json['expiresAt'] as String),
      message: json['message'] as String?,
      permissionLevel: json['permissionLevel'] as String? ?? 'editor',
      metadata: Map<String, dynamic>.from(json['metadata'] ?? {}),
    );
  }

  /// Standard object methods for debugging, comparison, and identity management.

  /// Returns a string representation of the invitation for debugging and logging.
  ///
  /// Provides essential invitation information in a readable format for development
  /// and debugging purposes with resource details, sender, target, and status.
  @override
  String toString() {
    return 'RealtimeInvitation('
        'id: $id, '
        'resource: $resourceType/$resourceId, '
        'from: $fromUserDisplayName, '
        'to: ${target.displayName}, '
        'status: $status'
        ')';
  }

  /// Compares two invitations for equality based on unique identifier.
  ///
  /// Uses invitation ID for equality comparison ensuring consistent object identity
  /// across different instances of the same invitation data.
  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is RealtimeInvitation && other.id == id;
  }

  /// Generates hash code based on unique invitation identifier.
  ///
  /// Provides consistent hash code generation for use in collections and
  /// data structures requiring hash-based operations and invitation identification.
  @override
  int get hashCode => id.hashCode;
  
  /// Helper method to parse DateTime from various formats without Firebase dependencies.
  ///
  /// Handles DateTime parsing from different data sources including:
  /// - DateTime objects (pass-through)
  /// - ISO strings (JSON format)
  /// - Timestamp-like maps (Firebase format handled by repository)
  /// - Milliseconds since epoch (int format)
  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;
    
    if (value is DateTime) {
      return value;
    } else if (value is String) {
      try {
        return DateTime.parse(value);
      } catch (e) {
        return null;
      }
    } else if (value is Map && value.containsKey('seconds')) {
      // Handle Firestore Timestamp-like objects passed from repository
      final seconds = value['seconds'] as int?;
      final nanoseconds = value['nanoseconds'] as int? ?? 0;
      if (seconds != null) {
        return DateTime.fromMillisecondsSinceEpoch(
          seconds * 1000 + nanoseconds ~/ 1000000,
        );
      }
    } else if (value is int) {
      // Handle milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(value);
    }
    
    return null;
  }
}

/// String extension providing text capitalization utilities for Swedish localization.
///
/// Extends String with capitalization methods supporting proper Swedish text formatting
/// for UI display and localized text presentation throughout the invitation system.
extension StringExtension on String {
  /// Capitalizes the first character of the string for proper Swedish text formatting.
  ///
  /// Provides first-letter capitalization for Swedish text display with empty string handling
  /// ensuring robust text formatting throughout the Swedish-localized invitation interface.
  String capitalizeFirst() {
    if (isEmpty) return this;
    return this[0].toUpperCase() + substring(1);
  }
}
