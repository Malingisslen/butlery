// lib/models/messaging/message_type.dart

/// Enum defining different types of messages in the messaging system
enum MessageType {
  /// Regular text message
  text,
  
  /// Message containing recipe share
  recipeShare,
  
  /// Message containing menu share  
  menuShare,
  
  /// Message containing shopping list share
  shoppingListShare,
  
  /// System-generated message (user joined, left, etc.)
  system,
  
  /// Image message
  image,
  
  /// Voice message
  voice,
}

/// Enum defining message delivery status
enum MessageStatus {
  /// Message is being sent
  sending,
  
  /// Message has been sent to server
  sent,
  
  /// Message has been delivered to recipient's device
  delivered,
  
  /// Message has been read by recipient
  read,
  
  /// Message failed to send
  failed,
}

/// Extension to provide user-friendly Swedish descriptions
extension MessageTypeExtension on MessageType {
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

extension MessageStatusExtension on MessageStatus {
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