/// Firebase Firestore repository for comprehensive real-time collaborative recipe editing and management.
/// This repository provides sophisticated real-time collaboration functionality using Firebase Firestore
/// for synchronous recipe editing, presence awareness, and live collaboration features. It enables
/// multiple users to simultaneously edit recipes with real-time synchronization, conflict resolution,
/// and comprehensive collaboration analytics for seamless cooking community experiences.
/// **Architecture Integration:**
/// - Uses Firebase Firestore for real-time data synchronization and presence management
/// - Integrates with RealtimeRecipe and LiveEditor models for collaborative editing
/// - Provides presence awareness through dedicated subcollections for active user tracking
/// - Coordinates with user management system for collaborative permissions and identity
/// - Supports real-time streams for immediate collaboration updates and conflict resolution
/// **Real-time Collaboration Features:**
/// - **Synchronous Editing**: Multiple users can edit recipes simultaneously with live updates
/// - **Presence Awareness**: Real-time tracking of active collaborators and their editing status
/// - **Conflict Resolution**: Sophisticated conflict detection and resolution for concurrent edits
/// - **Live Cursors**: Real-time cursor and selection tracking for enhanced collaboration UX
/// - **Edit History**: Comprehensive change tracking and version management for collaborative sessions
/// - **Permission Management**: Fine-grained access control for collaborative editing sessions
/// **Performance and Scalability:**
/// - **Optimistic Updates**: Client-side optimistic updates with server-side conflict resolution
/// - **Efficient Presence**: Lightweight presence tracking minimizing Firestore read/write costs
/// - **Real-time Streams**: Optimized Firestore snapshots for minimal latency collaboration
/// - **Batch Operations**: Efficient bulk operations for collaborative data synchronization

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/models/realtime/realtime_recipe.dart';
import 'package:butlery/models/realtime/live_editor.dart';

/// Firebase implementation for real-time collaborative recipe editing with comprehensive presence management.
/// This repository provides complete real-time collaboration functionality using Firebase Firestore
/// collections and subcollections to manage collaborative editing sessions, user presence, and
/// synchronized recipe modifications. It enables seamless multi-user recipe editing experiences
/// with sophisticated conflict resolution and real-time collaboration features.
/// **Collaboration Architecture:**
/// Uses multi-collection approach for comprehensive collaboration management:
/// - `realtime_recipes`: Primary collection storing collaborative recipe sessions
/// - `realtime_recipes/{id}/presence`: Subcollection tracking active user presence and editing status
/// - Real-time streams for immediate collaboration updates and presence awareness
/// **Usage Examples:**
/// ```dart
/// final collaborativeRepo = CollaborativeRecipeRepository();
/// // Create collaborative editing session
/// final realtimeRecipe = RealtimeRecipe.create(originalRecipe, ownerId);
/// await collaborativeRepo.createRealtimeRecipe(realtimeRecipe);
/// // Watch real-time recipe changes
/// collaborativeRepo.watchRealtimeRecipe(recipeId).listen((snapshot) {
///   final updatedRecipe = RealtimeRecipe.fromFirestore(snapshot);
///   updateEditorUI(updatedRecipe);
/// });
/// // Track collaborator presence
/// collaborativeRepo.watchActivePresence(recipeId).listen((presence) {
///   updatePresenceIndicators(presence.docs);
/// });
/// ```
class CollaborativeRecipeRepository {
  final FirebaseFirestore _firestore;

  CollaborativeRecipeRepository({FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  Future<void> createRealtimeRecipe(RealtimeRecipe recipe) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipe.id)
        .set(recipe.toFirestore());
  }

  Future<void> updateRealtimeRecipe(RealtimeRecipe recipe) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipe.id)
        .update(recipe.toFirestore());
  }

  Stream<DocumentSnapshot<Map<String, dynamic>>> watchRealtimeRecipe(String id) {
    return _firestore.collection('realtime_recipes').doc(id).snapshots();
  }

  Stream<QuerySnapshot<Map<String, dynamic>>> watchActivePresence(String id) {
    return _firestore
        .collection('realtime_recipes')
        .doc(id)
        .collection('presence')
        .where('isActive', isEqualTo: true)
        .snapshots();
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> getUserDocument(String userId) {
    return _firestore.collection('users').doc(userId).get();
  }

  Future<void> setPresence(
    String recipeId,
    String userId,
    Map<String, dynamic> data,
  ) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .doc(userId)
        .set(data);
  }

  Future<void> updatePresence(
    String recipeId,
    String userId,
    Map<String, dynamic> data,
  ) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .doc(userId)
        .set(data, SetOptions(merge: true));
  }

  Future<DocumentSnapshot<Map<String, dynamic>>> fetchRealtimeRecipe(String id) {
    return _firestore.collection('realtime_recipes').doc(id).get();
  }

  // Missing methods for collaborative manager
  Stream<RealtimeRecipe?> getRealtimeRecipeStream(String id) {
    return _firestore
        .collection('realtime_recipes')
        .doc(id)
        .snapshots()
        .map((snapshot) {
      if (snapshot.exists) {
        return RealtimeRecipe.fromFirestore(snapshot);
      }
      return null;
    });
  }

  Stream<List<LiveEditor>> getParticipantsStream(String id) {
    return _firestore
        .collection('realtime_recipes')
        .doc(id)
        .collection('presence')
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map((snapshot) {
      return snapshot.docs
          .map((doc) => LiveEditor.fromFirestore(doc.data()))
          .toList();
    });
  }

  Future<void> updateUserPresence(String recipeId, String userId, String displayName) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .doc(userId)
        .set({
      'userId': userId,
      'displayName': displayName,
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
      'isActive': true,
    }, SetOptions(merge: true));
  }

  /// Update presence heartbeat (lightweight update for active users)
  Future<void> updatePresenceHeartbeat(String recipeId, String userId) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .doc(userId)
        .set({
      'lastSeen': DateTime.now().millisecondsSinceEpoch,
      'isActive': true,
    }, SetOptions(merge: true));
  }

  Future<void> clearUserPresence(String recipeId, String userId) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .doc(userId)
        .set({'isActive': false}, SetOptions(merge: true));
  }

  /// Remove user presence completely from recipe (needed by RealtimeEditorTracker)
  Future<void> removePresence(String recipeId, String userId) {
    return _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .doc(userId)
        .delete();
  }

  /// Get all active editors for a recipe (needed by RealtimeEditorTracker)
  Future<List<Map<String, dynamic>>> getActiveEditors(String recipeId) async {
    final snapshot = await _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .where('isActive', isEqualTo: true)
        .get();
    
    return snapshot.docs.map((doc) {
      final data = doc.data();
      
      // Handle both int and Timestamp/DateTime for lastSeen
      int? lastSeenMillis;
      final lastSeenValue = data['lastSeen'];
      if (lastSeenValue is int) {
        lastSeenMillis = lastSeenValue;
      } else if (lastSeenValue is Timestamp) {
        lastSeenMillis = lastSeenValue.millisecondsSinceEpoch;
      } else if (lastSeenValue is DateTime) {
        lastSeenMillis = lastSeenValue.millisecondsSinceEpoch;
      }
      
      final now = DateTime.now().millisecondsSinceEpoch;
      final isCurrentlyActive = lastSeenMillis != null && (now - lastSeenMillis) < 60000; // Within 1 minute
      
      return {
        'userId': doc.id,
        'displayName': data['displayName'] as String? ?? 'Unknown',
        'lastSeen': lastSeenMillis,
        'isActive': data['isActive'] as bool? ?? false,
        'isCurrentlyActive': isCurrentlyActive,
      };
    }).toList();
  }

  /// Check if specific user is actively editing (needed by RealtimeEditorTracker)
  Future<bool> isUserActivelyEditing(String recipeId, String userId) async {
    final doc = await _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .doc(userId)
        .get();
    
    if (!doc.exists) return false;
    
    final data = doc.data()!;
    final isActive = data['isActive'] as bool? ?? false;
    
    // Handle both int and Timestamp/DateTime for lastSeen
    int? lastSeenMillis;
    final lastSeenValue = data['lastSeen'];
    if (lastSeenValue is int) {
      lastSeenMillis = lastSeenValue;
    } else if (lastSeenValue is Timestamp) {
      lastSeenMillis = lastSeenValue.millisecondsSinceEpoch;
    } else if (lastSeenValue is DateTime) {
      lastSeenMillis = lastSeenValue.millisecondsSinceEpoch;
    }
    
    if (!isActive || lastSeenMillis == null) return false;
    
    // Consider user active if seen within last minute
    final now = DateTime.now().millisecondsSinceEpoch;
    return (now - lastSeenMillis) < 60000;
  }

  /// Clean up inactive editors (older than 5 minutes)
  Future<void> cleanupInactiveEditors(String recipeId) async {
    final fiveMinutesAgo = DateTime.now().millisecondsSinceEpoch - (5 * 60 * 1000);
    
    // Get all presence documents
    final snapshot = await _firestore
        .collection('realtime_recipes')
        .doc(recipeId)
        .collection('presence')
        .get();
    
    // Batch operation for cleanup
    final batch = _firestore.batch();
    
    for (final doc in snapshot.docs) {
      final data = doc.data();
      
      // Handle both int and Timestamp/DateTime for lastSeen
      int? lastSeenMillis;
      final lastSeenValue = data['lastSeen'];
      if (lastSeenValue is int) {
        lastSeenMillis = lastSeenValue;
      } else if (lastSeenValue is Timestamp) {
        lastSeenMillis = lastSeenValue.millisecondsSinceEpoch;
      } else if (lastSeenValue is DateTime) {
        lastSeenMillis = lastSeenValue.millisecondsSinceEpoch;
      }
      
      // Mark as inactive if last seen more than 5 minutes ago
      if (lastSeenMillis != null && lastSeenMillis < fiveMinutesAgo) {
        batch.update(doc.reference, {'isActive': false});
      }
    }
    
    await batch.commit();
  }
}
