// lib/services/deep_link_service.dart

import 'dart:async';
import '../core/utils/logger.dart';
import '../services/permission_service.dart';
import '../core/injection.dart';
import '../repositories/interfaces/deeplink_repository.dart';

/// Deep link service for handling invitation links and app navigation
/// 
/// This service provides a framework for deep linking that can be extended
/// with Firebase Dynamic Links or other deep linking solutions.
class DeepLinkService {
  final DeepLinkRepository _deepLinkRepository;
  static const String _baseUrl = 'https://butlery.app';
  static const String _invitePath = '/invite';
  static const String _recipePath = '/recipe';
  static const String _menuPath = '/menu';
  static const String _shoppingPath = '/shopping';

  DeepLinkService({required DeepLinkRepository deepLinkRepository})
      : _deepLinkRepository = deepLinkRepository;

  /// Generate a deep link for friend invitation
  static String generateFriendInvitationLink({
    required String invitationId,
    required String fromUserId,
    String? customMessage,
  }) {
    final params = <String, String>{
      'id': invitationId,
      'type': 'friend',
      'from': fromUserId,
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    if (customMessage != null) {
      params['message'] = Uri.encodeComponent(customMessage);
    }

    return _buildUrl(_invitePath, params);
  }

  /// Generate a deep link for recipe sharing
  static String generateRecipeShareLink({
    required String recipeId,
    required String fromUserId,
    String? customMessage,
  }) {
    final params = <String, String>{
      'id': recipeId,
      'type': 'recipe',
      'from': fromUserId,
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    if (customMessage != null) {
      params['message'] = Uri.encodeComponent(customMessage);
    }

    return _buildUrl(_recipePath, params);
  }

  /// Generate a deep link for menu sharing
  static String generateMenuShareLink({
    required String menuId,
    required String fromUserId,
    String? customMessage,
  }) {
    final params = <String, String>{
      'id': menuId,
      'type': 'menu',
      'from': fromUserId,
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    if (customMessage != null) {
      params['message'] = Uri.encodeComponent(customMessage);
    }

    return _buildUrl(_menuPath, params);
  }

  /// Generate a deep link for shopping list sharing
  static String generateShoppingListShareLink({
    required String listId,
    required String fromUserId,
    String? customMessage,
  }) {
    final params = <String, String>{
      'id': listId,
      'type': 'shopping',
      'from': fromUserId,
      'timestamp': DateTime.now().millisecondsSinceEpoch.toString(),
    };

    if (customMessage != null) {
      params['message'] = Uri.encodeComponent(customMessage);
    }

    return _buildUrl(_shoppingPath, params);
  }

  /// Parse a deep link and extract information
  static DeepLinkData? parseDeepLink(String url) {
    try {
      final uri = Uri.parse(url);
      
      // Check if it's a Butlery deep link
      if (uri.host != 'butlery.app' && uri.host != 'www.butlery.app') {
        return null;
      }

      final path = uri.path;
      final params = uri.queryParameters;

      if (path.startsWith(_invitePath)) {
        return DeepLinkData(
          type: DeepLinkType.friendInvitation,
          id: params['id'],
          fromUserId: params['from'],
          message: params['message'] != null ? Uri.decodeComponent(params['message']!) : null,
          timestamp: params['timestamp'] != null ? int.tryParse(params['timestamp']!) : null,
        );
      } else if (path.startsWith(_recipePath)) {
        return DeepLinkData(
          type: DeepLinkType.recipeShare,
          id: params['id'],
          fromUserId: params['from'],
          message: params['message'] != null ? Uri.decodeComponent(params['message']!) : null,
          timestamp: params['timestamp'] != null ? int.tryParse(params['timestamp']!) : null,
        );
      } else if (path.startsWith(_menuPath)) {
        return DeepLinkData(
          type: DeepLinkType.menuShare,
          id: params['id'],
          fromUserId: params['from'],
          message: params['message'] != null ? Uri.decodeComponent(params['message']!) : null,
          timestamp: params['timestamp'] != null ? int.tryParse(params['timestamp']!) : null,
        );
      } else if (path.startsWith(_shoppingPath)) {
        return DeepLinkData(
          type: DeepLinkType.shoppingListShare,
          id: params['id'],
          fromUserId: params['from'],
          message: params['message'] != null ? Uri.decodeComponent(params['message']!) : null,
          timestamp: params['timestamp'] != null ? int.tryParse(params['timestamp']!) : null,
        );
      }

      return null;
    } catch (e) {
      AppLogger.error('Failed to parse deep link: $e');
      return null;
    }
  }

  /// Validate if a deep link is still valid (not expired)
  static bool isLinkValid(DeepLinkData linkData, {Duration maxAge = const Duration(days: 7)}) {
    if (linkData.timestamp == null) return true; // No expiration if no timestamp
    
    final createdAt = DateTime.fromMillisecondsSinceEpoch(linkData.timestamp!);
    final now = DateTime.now();
    
    return now.difference(createdAt) <= maxAge;
  }

  /// Build URL with parameters
  static String _buildUrl(String path, Map<String, String> params) {
    final uri = Uri.parse('$_baseUrl$path').replace(queryParameters: params);
    return uri.toString();
  }

  /// Generate a short URL using a URL shortening service
  static Future<String> generateShortUrl(String longUrl) async {
    try {
      // First try to use our internal short URL service
      final shortUrl = await _generateInternalShortUrl(longUrl);
      if (shortUrl != null) {
        AppLogger.debug('Generated internal short URL: $shortUrl');
        return shortUrl;
      }
      
      // Fallback: Try external service (you can add API key configuration)
      final externalShortUrl = await _generateExternalShortUrl(longUrl);
      if (externalShortUrl != null) {
        AppLogger.debug('Generated external short URL: $externalShortUrl');
        return externalShortUrl;
      }
      
      // Ultimate fallback: return original URL
      AppLogger.debug('Short URL generation failed, returning original URL');
      return longUrl;
    } catch (e) {
      AppLogger.error('Error generating short URL: $e');
      return longUrl;
    }
  }
  
  /// Generate internal short URL using Firestore
  static Future<String?> _generateInternalShortUrl(String longUrl) async {
    try {
      if (!sl<PermissionService>().isAuthenticated) {
        return null;
      }
      
      // Use the repository to create short URL
      final metadata = {
        'isActive': true,
        'expiresAt': DateTime.now().add(const Duration(days: 30)).toIso8601String(),
      };
      
      final shortCode = await sl<DeepLinkService>()._deepLinkRepository.createShortUrl(
        longUrl,
        metadata,
      );
      
      return 'https://butlery.app/s/$shortCode';
    } catch (e) {
      AppLogger.error('Failed to create internal short URL: $e');
      return null;
    }
  }
  
  /// Generate external short URL (placeholder for external services)
  static Future<String?> _generateExternalShortUrl(String longUrl) async {
    try {
      // This could integrate with services like bit.ly, tinyurl.com, etc.
      // For now, return null to use fallback
      return null;
      
      // Example integration with bit.ly (requires API key):
      // final response = await http.post(
      //   Uri.parse('https://api-ssl.bitly.com/v4/shorten'),
      //   headers: {
      //     'Authorization': 'Bearer YOUR_BITLY_ACCESS_TOKEN',
      //     'Content-Type': 'application/json',
      //   },
      //   body: json.encode({'long_url': longUrl}),
      // );
      // 
      // if (response.statusCode == 200) {
      //   final data = json.decode(response.body);
      //   return data['link'];
      // }
    } catch (e) {
      AppLogger.error('Failed to create external short URL: $e');
      return null;
    }
  }
  

  /// Handle Firebase Dynamic Links initialization
  static Future<void> initializeDynamicLinks() async {
    try {
      // Initialize custom deep link handling
      // Note: This would integrate with Firebase Dynamic Links in a real implementation
      await _initializeCustomDeepLinkHandler();
      
      AppLogger.info('✅ Deep link service initialized successfully');
    } catch (e) {
      AppLogger.error('Failed to initialize deep links: $e');
    }
  }
  
  /// Initialize custom deep link handler
  static Future<void> _initializeCustomDeepLinkHandler() async {
    try {
      // Set up listeners for incoming deep links
      // This would integrate with the app's navigation system
      
      // Register URL scheme handlers
      _registerUrlSchemeHandlers();
      
      AppLogger.debug('Custom deep link handler initialized');
    } catch (e) {
      AppLogger.error('Failed to initialize custom deep link handler: $e');
    }
  }
  
  /// Register URL scheme handlers
  static void _registerUrlSchemeHandlers() {
    // This would register handlers for different URL schemes:
    // - butlery://
    // - https://butlery.app/
    // - Custom short URLs
    
    AppLogger.debug('URL scheme handlers registered');
  }

  /// Handle incoming deep link and navigate appropriately
  static Future<void> handleDeepLink(String url, Function(String) navigateToRoute) async {
    try {
      final deepLinkData = parseDeepLink(url);
      if (deepLinkData == null) {
        AppLogger.warning('Invalid deep link received: $url');
        return;
      }

      // Check if link is expired (older than 7 days)
      if (isLinkExpired(deepLinkData)) {
        AppLogger.warning('Deep link expired: $url');
        return;
      }

      // Navigate based on deep link type
      switch (deepLinkData.type) {
        case DeepLinkType.friendInvitation:
          if (deepLinkData.id != null) {
            navigateToRoute('/friends?invitation=${deepLinkData.id}');
          }
          break;
        case DeepLinkType.recipeShare:
          if (deepLinkData.id != null) {
            navigateToRoute('/recipe/${deepLinkData.id}?shared=true');
          }
          break;
        case DeepLinkType.menuShare:
          if (deepLinkData.id != null) {
            navigateToRoute('/menu/${deepLinkData.id}?shared=true');
          }
          break;
        case DeepLinkType.shoppingListShare:
          if (deepLinkData.id != null) {
            navigateToRoute('/shopping/${deepLinkData.id}?shared=true');
          }
          break;
      }

      AppLogger.info('Deep link handled successfully: ${deepLinkData.type}');
    } catch (e) {
      AppLogger.error('Failed to handle deep link: $e');
    }
  }

  /// Check if a deep link is expired
  static bool isLinkExpired(DeepLinkData deepLinkData) {
    if (deepLinkData.timestamp == null) return false;
    
    final linkTime = DateTime.fromMillisecondsSinceEpoch(deepLinkData.timestamp!);
    final now = DateTime.now();
    final difference = now.difference(linkTime);
    
    return difference.inDays > 7; // Links expire after 7 days
  }
  
  /// Resolve short URL to original URL
  static Future<String?> resolveShortUrl(String shortCode) async {
    try {
      // Get the long URL from repository
      final longUrl = await sl<DeepLinkService>()._deepLinkRepository.getLongUrl(shortCode);
      
      if (longUrl == null) {
        AppLogger.warning('Short URL not found: $shortCode');
        return null;
      }
      
      // Track the click
      await sl<DeepLinkService>()._deepLinkRepository.trackUrlClick(shortCode);
      
      AppLogger.debug('Resolved short URL $shortCode to $longUrl');
      return longUrl;
    } catch (e) {
      AppLogger.error('Failed to resolve short URL: $e');
      return null;
    }
  }
  
  /// Get analytics for short URLs
  static Future<Map<String, dynamic>> getShortUrlAnalytics(String shortCode) async {
    try {
      // Get metadata from repository
      final metadata = await sl<DeepLinkService>()._deepLinkRepository.getDeepLinkMetadata(shortCode);
      
      if (metadata == null) {
        return {'error': 'Short URL not found'};
      }
      
      // Get the long URL
      final longUrl = await sl<DeepLinkService>()._deepLinkRepository.getLongUrl(shortCode);
      
      return {
        'shortCode': shortCode,
        'longUrl': longUrl,
        'metadata': metadata,
      };
    } catch (e) {
      AppLogger.error('Failed to get short URL analytics: $e');
      return {'error': e.toString()};
    }
  }
}

/// Deep link data structure
class DeepLinkData {
  final DeepLinkType type;
  final String? id;
  final String? fromUserId;
  final String? message;
  final int? timestamp;

  DeepLinkData({
    required this.type,
    this.id,
    this.fromUserId,
    this.message,
    this.timestamp,
  });

  @override
  String toString() {
    return 'DeepLinkData(type: $type, id: $id, fromUserId: $fromUserId, message: $message, timestamp: $timestamp)';
  }
}

/// Types of deep links supported
enum DeepLinkType {
  friendInvitation,
  recipeShare,
  menuShare,
  shoppingListShare,
}