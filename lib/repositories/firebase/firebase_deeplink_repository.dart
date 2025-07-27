// lib/repositories/firebase/firebase_deeplink_repository.dart

import 'package:cloud_firestore/cloud_firestore.dart';
import '../interfaces/deeplink_repository.dart';
// import '../interfaces/auth_repository.dart'; // Imported from base class
import 'base_firebase_repository.dart';
import '../../core/utils/logger.dart';

/// Firebase implementation of DeepLinkRepository
/// 
/// Handles storage and retrieval of deep link mappings and metadata
class FirebaseDeepLinkRepository extends BaseFirebaseRepository<Map<String, dynamic>>
    implements DeepLinkRepository {
  
  FirebaseDeepLinkRepository({
    super.firestore,
    required super.authRepository,
  });

  @override
  String get collectionName => 'deep_links';

  @override
  Map<String, dynamic> fromFirestore(DocumentSnapshot<Map<String, dynamic>> doc) {
    return doc.data() ?? {};
  }

  @override
  Map<String, dynamic> toFirestore(Map<String, dynamic> entity) => entity;

  @override
  String getId(Map<String, dynamic> entity) => entity['id'] ?? '';

  @override
  Future<String> createShortUrl(String longUrl, Map<String, dynamic> metadata) async {
    try {
      // Generate a unique short code
      final shortCode = _generateShortCode();
      final linkData = {
        'id': shortCode,
        'longUrl': longUrl,
        'metadata': metadata,
        'createdAt': FieldValue.serverTimestamp(),
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

  @override
  Future<void> trackUrlClick(String shortUrl) async {
    try {
      await collection.doc(shortUrl).update({
        'clickCount': FieldValue.increment(1),
        'lastClickedAt': FieldValue.serverTimestamp(),
      });
      
      // Also track click history
      await collection
          .doc(shortUrl)
          .collection('clicks')
          .add({
            'timestamp': FieldValue.serverTimestamp(),
            'userId': currentUserId,
          });
    } catch (e) {
      AppLogger.error('Failed to track URL click', e);
    }
  }

  @override
  Future<void> storeDeepLinkMetadata(String linkId, Map<String, dynamic> metadata) async {
    try {
      await collection.doc(linkId).set({
        'id': linkId,
        'metadata': metadata,
        'updatedAt': FieldValue.serverTimestamp(),
        'updatedBy': currentUserId,
      }, SetOptions(merge: true));
      
      AppLogger.info('Stored deep link metadata for: $linkId');
    } catch (e) {
      AppLogger.error('Failed to store deep link metadata', e);
      throw Exception('Failed to store deep link metadata: $e');
    }
  }

  @override
  Future<Map<String, dynamic>?> getDeepLinkMetadata(String linkId) async {
    try {
      final doc = await collection.doc(linkId).get();
      if (!doc.exists) {
        return null;
      }
      
      final data = doc.data();
      return data?['metadata'] as Map<String, dynamic>?;
    } catch (e) {
      AppLogger.error('Failed to get deep link metadata', e);
      return null;
    }
  }

  @override
  Future<void> deleteExpiredLinks(DateTime before) async {
    try {
      final query = await collection
          .where('createdAt', isLessThan: Timestamp.fromDate(before))
          .get();
      
      if (query.docs.isEmpty) return;
      
      final batch = firestore.batch();
      for (final doc in query.docs) {
        batch.delete(doc.reference);
      }
      
      await batch.commit();
      AppLogger.info('Deleted ${query.docs.length} expired deep links');
    } catch (e) {
      AppLogger.error('Failed to delete expired links', e);
      throw Exception('Failed to delete expired links: $e');
    }
  }

  /// Generate a unique short code for URLs
  String _generateShortCode() {
    const chars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
    final random = DateTime.now().millisecondsSinceEpoch;
    final buffer = StringBuffer();
    
    for (int i = 0; i < 8; i++) {
      final index = (random + i) % chars.length;
      buffer.write(chars[index]);
    }
    
    return buffer.toString();
  }
}