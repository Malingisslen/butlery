// lib/services/deep_link_service.dart

import 'dart:async';
import '../core/utils/logger.dart';

/// Deep link service for handling invitation links and app navigation
/// 
/// This service provides a framework for deep linking that can be extended
/// with Firebase Dynamic Links or other deep linking solutions.
class DeepLinkService {
  static const String _baseUrl = 'https://butlery.app';
  static const String _invitePath = '/invite';
  static const String _recipePath = '/recipe';
  static const String _menuPath = '/menu';
  static const String _shoppingPath = '/shopping';

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

  /// Generate a short URL (placeholder for future implementation)
  static Future<String> generateShortUrl(String longUrl) async {
    // TODO: Implement URL shortening service integration
    // For now, return the original URL
    AppLogger.debug('Short URL generation not implemented, returning original URL');
    return longUrl;
  }

  /// Handle Firebase Dynamic Links initialization (for future use)
  static Future<void> initializeDynamicLinks() async {
    try {
      // TODO: Initialize Firebase Dynamic Links when available
      // FirebaseDynamicLinks.instance.onLink.listen((dynamicLink) {
      //   // Handle dynamic link
      // });
      
      AppLogger.info('Dynamic links framework ready for Firebase integration');
    } catch (e) {
      AppLogger.error('Failed to initialize dynamic links: $e');
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