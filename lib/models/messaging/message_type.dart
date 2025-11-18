/// Comprehensive message type definitions providing content classification and Swedish localization for messaging infrastructure.
/// This module implements sophisticated message type management following Single Responsibility Principle,
/// handling all aspects of message classification including content types, delivery status tracking,
/// and comprehensive UI integration with Swedish localization. It provides complete type classification
/// while maintaining clean separation from message content and messaging transport concerns.
/// **Single Responsibility Focus:**
/// This module exclusively handles message type classification and display integration:
/// - **Content Type System**: Comprehensive classification for text, media, content sharing, and system messages
/// - **Delivery Status Management**: Complete status tracking from sending through read confirmation with visual indicators
/// - **Swedish Localization**: Complete Swedish language support for type names, status descriptions, and UI text
/// - **Visual Integration**: Rich icon and display name support for consistent UI presentation across message types
/// **What This Module Does NOT Handle:**
/// - Message content creation and management (handled by Message model and messaging services)
/// - Message delivery and transport logic (handled by messaging services and push notification systems)
/// - UI presentation and interaction handling (handled by ViewModels and UI components)
/// - Message persistence and synchronization (handled by messaging repositories)
/// **Message Type Features:**
/// - **Rich Content Classification**: Support for text, recipe sharing, menu sharing, shopping list sharing, images, voice, and system messages
/// - **Visual Consistency**: Comprehensive icon system with emoji-based visual indicators for all message types
/// - **Swedish Localization**: Complete Swedish language support for all type names and status descriptions
/// - **Delivery Intelligence**: Advanced status tracking with visual progression indicators and user-friendly descriptions
/// - **Extension Integration**: Powerful extension methods for seamless integration with messaging UI components
/// **Usage Examples:**
/// ```dart
/// // Get message type information for UI display
/// final messageType = MessageType.recipeShare;
/// final displayName = messageType.displayName; // "Receptdelning"
/// final icon = messageType.icon; // "🍽️"
/// // Display message status with localization
/// final status = MessageStatus.delivered;
/// final statusText = status.displayName; // "Levererat"
/// final statusIcon = status.icon; // "✓✓"
/// // Use in message UI components
/// MessageTypeIndicator(
///   type: message.type,
///   icon: message.type.icon,
///   label: message.type.displayName,
/// );
/// StatusIndicator(
///   status: message.status,
///   icon: message.status.icon,
///   description: message.status.displayName,
/// );
/// ```

// lib/models/messaging/message_type.dart

/// Enumeration defining comprehensive message content types for messaging infrastructure classification.
/// Provides complete content type classification for messaging system with support for text communication,
/// rich content sharing, media messages, and system notifications with appropriate UI handling and display.
enum MessageType {
  /// Standard text message for basic communication between users.
  /// Represents regular text-based communication including plain text, emojis,
  /// and formatted text content for standard conversational messaging.
  text,
  
  /// Recipe sharing message containing recipe reference and metadata.
  /// Specialized message type for sharing recipes between users with embedded
  /// recipe information, thumbnail, and direct navigation to recipe content.
  recipeShare,
  
  /// Menu sharing message containing menu reference and planning information.
  /// Specialized message type for sharing meal planning menus with embedded
  /// menu details and collaborative meal planning capabilities.
  menuShare,
  
  /// Shopping list sharing message containing list reference and collaborative features.
  /// Specialized message type for sharing shopping lists with embedded list
  /// information and real-time collaborative shopping functionality.
  shoppingListShare,
  
  /// System-generated message for conversation events and administrative notifications.
  /// Automated messages representing conversation events such as user joining,
  /// leaving, administrative actions, and system announcements with special formatting.
  system,
  
  /// Image message containing photo or visual content for rich communication.
  /// Media message type for sharing images, photos, and visual content with
  /// thumbnail preview and full-size viewing capabilities.
  image,
  
  /// Voice message containing audio content for personal communication.
  /// Audio message type for voice recordings with playback controls, duration
  /// display, and waveform visualization for enhanced audio messaging experience.
  voice,
}

/// Enumeration defining comprehensive message delivery status lifecycle for messaging infrastructure tracking.
/// Provides complete status classification for message delivery with clear progression
/// from sending through final delivery confirmation and read acknowledgment with UI indicators.
enum MessageStatus {
  /// Message is currently being sent to recipients through messaging infrastructure.
  /// Initial status when message is created and queued for delivery, indicating
  /// active transmission process with loading indicators and retry capabilities.
  sending,
  
  /// Message has been successfully sent to messaging server for distribution.
  /// Indicates message has left sender's device and is queued on server for delivery
  /// to recipients with single checkmark indicator and server acknowledgment.
  sent,
  
  /// Message has been delivered to recipient's device and messaging client.
  /// Confirms message reached the intended recipient's device with double checkmark
  /// indicator and delivery confirmation for transmission success tracking.
  delivered,
  
  /// Message has been read and viewed by the recipient user.
  /// Final status indicating recipient has opened and viewed the message content
  /// with read indicator and engagement confirmation for communication success.
  read,
  
  /// Message sending failed due to delivery error or network issues.
  /// Error status indicating message could not be delivered, requiring retry
  /// or manual intervention with error indicator and retry action availability.
  failed,
}

/// Extension providing Swedish localization and visual integration for MessageType enumeration.
/// This extension enhances MessageType with comprehensive UI integration including Swedish-localized
/// display names and emoji-based visual indicators for consistent messaging interface presentation
/// and optimal user experience throughout the Swedish-localized application.
extension MessageTypeExtension on MessageType {
  /// Gets Swedish-localized display name for the message type for UI presentation.
  /// Provides user-friendly Swedish names for all message types enabling proper localization
  /// in message lists, type indicators, and conversation interfaces with appropriate Swedish
  /// terminology for enhanced user experience and cultural adaptation.
  /// Returns Swedish display name appropriate for UI elements and user communication.
  String get displayName {
    switch (this) {
      case MessageType.text:
        return 'Textmeddelande';
      case MessageType.recipeShare:
        return 'Receptdelning';
      case MessageType.menuShare:
        return 'Menydelning';
      case MessageType.shoppingListShare:
        return 'Inköpslistedelning';
      case MessageType.system:
        return 'Systemmeddelande';
      case MessageType.image:
        return 'Bild';
      case MessageType.voice:
        return 'Röstmeddelande';
    }
  }
  
  /// Gets emoji icon representing the message type for visual identification and UI consistency.
  /// Provides distinctive emoji icons for each message type enabling quick visual identification
  /// in message lists, conversation bubbles, and type indicators with culturally appropriate
  /// and universally recognizable symbols for enhanced user interface experience.
  /// Returns emoji icon appropriate for visual message type representation.
  String get icon {
    switch (this) {
      case MessageType.text:
        return '💬';
      case MessageType.recipeShare:
        return '🍽️';
      case MessageType.menuShare:
        return '📋';
      case MessageType.shoppingListShare:
        return '🛒';
      case MessageType.system:
        return 'ℹ️';
      case MessageType.image:
        return '📷';
      case MessageType.voice:
        return '🎤';
    }
  }
}

/// Extension providing Swedish localization and delivery status indicators for MessageStatus enumeration.
/// This extension enhances MessageStatus with comprehensive delivery tracking including Swedish-localized
/// status descriptions and visual delivery indicators for messaging interface presentation and delivery
/// status communication with appropriate progression indicators and user feedback.
extension MessageStatusExtension on MessageStatus {
  /// Gets Swedish-localized display name for the delivery status for UI presentation.
  /// Provides user-friendly Swedish descriptions for all delivery statuses enabling proper localization
  /// in message status indicators, delivery confirmations, and messaging interfaces with appropriate
  /// Swedish terminology for enhanced user experience and delivery status communication.
  /// Returns Swedish display name appropriate for delivery status communication and UI elements.
  String get displayName {
    switch (this) {
      case MessageStatus.sending:
        return 'Skickar...';
      case MessageStatus.sent:
        return 'Skickat';
      case MessageStatus.delivered:
        return 'Levererat';
      case MessageStatus.read:
        return 'Läst';
      case MessageStatus.failed:
        return 'Misslyckades';
    }
  }
  
  /// Gets emoji icon representing the delivery status for visual delivery tracking and UI consistency.
  /// Provides distinctive delivery status indicators for each status stage enabling clear visual
  /// communication of message delivery progression with universally recognized symbols for delivery
  /// confirmation, read receipts, and error indication in messaging interfaces.
  /// Returns emoji icon appropriate for delivery status visualization and user feedback.
  String get icon {
    switch (this) {
      case MessageStatus.sending:
        return '⏳';
      case MessageStatus.sent:
        return '✓';
      case MessageStatus.delivered:
        return '✓✓';
      case MessageStatus.read:
        return '👁️';
      case MessageStatus.failed:
        return '❌';
    }
  }
}