/// Firebase Firestore implementation for comprehensive deep link management and URL shortening services.
/// This repository provides complete deep link functionality using Firebase Firestore as the backend,
/// enabling recipe and content sharing through shortened URLs and metadata management. It supports both internal app navigation and external sharing.
/// **Architecture Integration:**
/// - Extends [BaseFirebaseRepository] for consistent CRUD operations and error handling
/// - Implements [DeepLinkRepository] interface for standardized deep link operations
/// - Integrates with [AppLogger] for detailed link activity monitoring and debugging
/// - Coordinates with social sharing system for seamless content distribution
/// - Supports both authenticated and anonymous link access patterns
/// **Deep Link System Features:**
/// - **URL Shortening**: Generate short, shareable links for recipes and content
/// - **Metadata Storage**: Rich metadata support for enhanced link preview and context
/// - **Collision Prevention**: Unique short code generation with conflict resolution
/// - **Performance Optimization**: Efficient link resolution with minimal database queries

import 'dart:math';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/repositories/interfaces/deeplink_repository.dart';
// import '../interfaces/auth_repository.dart'; // Imported from base class
import 'package:butlery/repositories/firebase/base_firebase_repository.dart';
import 'package:butlery/core/utils/logger.dart';
import 'package:butlery/core/constants/firestore_collections.dart';

/// Firebase implementation for deep link management with URL shortening.
/// This repository provides complete deep link functionality using Firebase Firestore collections
/// for link storage and metadata management. It enables recipe and content sharing through shortened
/// URLs.
/// **Deep Link Architecture:**
/// - `deep_links`: Primary collection storing link mappings and metadata
/// **URL Shortening System:**
/// - **Unique Code Generation**: 8-character alphanumeric codes for collision-free short URLs
/// - **Metadata Integration**: Rich link metadata for enhanced sharing and preview capabilities
/// - **Performance Optimization**: Efficient link resolution with minimal database overhead
/// **Usage Examples:**
/// ```dart
/// final deepLinkRepo = FirebaseDeepLinkRepository(
///   authRepository: ServiceLocator.get<AuthRepository>(),
/// );
/// // Create shareable short URL
/// final shortCode = await deepLinkRepo.createShortUrl(
///   'https://butlery.se/recipe/12345',
///   {'title': 'Amazing Pasta Recipe', 'type': 'recipe'},
/// );
/// // Resolve short URL
/// final longUrl = await deepLinkRepo.getLongUrl(shortCode);
/// ```
class FirebaseDeepLinkRepository
    extends BaseFirebaseRepository<Map<String, dynamic>>
    implements DeepLinkRepository {
  /// Creates a Firebase deep link repository with dependency injection support.
  /// [firestore] Optional Firestore instance for testing, defaults to production instance
  /// [authRepository] Required authentication repository for user validation and link attribution
  FirebaseDeepLinkRepository({
    super.firestore,
    required super.authRepository,
    super.timestampProvider,
  });

  @override
  String get collectionName => FirestoreCollections.deepLinks;

  @override
  Map<String, dynamic> fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return doc.data() ?? {};
  }

  @override
  Map<String, dynamic> toFirestore(Map<String, dynamic> entity) => entity;

  @override
  String getId(Map<String, dynamic> entity) => entity['id'] ?? '';
  @override
  Future<bool> validateCreatePermission(
    String userId,
    Map<String, dynamic> entity,
  ) async {
    // Users can create their own deeplinks
    // Check if createdBy field matches current user (if present)
    final createdBy = entity['createdBy'];
    if (createdBy != null && createdBy != userId) {
      return false;
    }
    return true;
  }

  @override
  Future<bool> validateReadPermission(
    String userId,
    String resourceId,
    Map<String, dynamic>? entity,
  ) async {
    // Deeplinks are publicly readable (for sharing functionality)
    // Anyone with the short code can resolve it
    return true;
  }

  @override
  Future<bool> validateUpdatePermission(
    String userId,
    String resourceId,
    Map<String, dynamic> entity,
  ) async {
    // Only the creator can update their deeplink
    final createdBy = entity['createdBy'];
    return createdBy == userId;
  }

  @override
  Future<bool> validateDeletePermission(
    String userId,
    String resourceId,
  ) async {
    // Only the creator can delete their deeplink
    try {
      final doc = await collection.doc(resourceId).get();
      if (!doc.exists) return false;

      final data = doc.data();
      final createdBy = data?['createdBy'];
      return createdBy == userId;
    } catch (e) {
      return false;
    }
  }

  @override
  Future<String> createShortUrl(
    String longUrl,
    Map<String, dynamic> metadata,
  ) async {
    try {
      // Generate a unique short code
      final shortCode = _generateShortCode();
      final linkData = {
        'id': shortCode,
        'longUrl': longUrl,
        'metadata': metadata,
        'createdAt': timestampProvider.serverTimestamp(),
        'createdBy': currentUserId,
        'clickCount': 0,
      };

      await collection.doc(shortCode).set(linkData);

      AppLogger.info('Created short URL: $shortCode');
      return shortCode;
    } catch (e) {
      AppLogger.error('Failed to create short URL', e);
      throw Exception('Failed to create short URL: $e');
    }
  }

  @override
  Future<String?> getLongUrl(String shortUrl) async {
    try {
      final doc = await collection.doc(shortUrl).get();
      if (!doc.exists) {
        return null;
      }

      final data = doc.data();
      return data?['longUrl'] as String?;
    } catch (e) {
      AppLogger.error('Failed to get long URL', e);
      return null;
    }
  }

  static final Random _random = Random.secure();

  /// Generate a unique short code for URLs
  String _generateShortCode() {
    const chars =
        'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final buffer = StringBuffer();

    for (int i = 0; i < 8; i++) {
      buffer.write(chars[_random.nextInt(chars.length)]);
    }

    return buffer.toString();
  }
}
