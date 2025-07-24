// lib/models/realtime/realtime_metadata.dart

/// Focused module for realtime metadata management
/// 
/// This module handles ONLY realtime tracking metadata:
/// - Edit tracking (timestamps, edit counts, last editor)
/// - Activity status management
/// - Metadata updates and validation
/// - Edit session management
/// 
/// ❌ DOES NOT CONTAIN: Recipe content, serialization, participant management
class RealtimeMetadata {
  
  // ===== EDIT TRACKING =====

  /// Create edit tracking data for a new edit
  static Map<String, dynamic> createEditTracking({
    required String editedBy,
    required String editedByDisplayName,
    DateTime? editTime,
    int? currentEditCount,
  }) {
    return {
      'lastEditedBy': editedBy,
      'lastEditedByDisplayName': editedByDisplayName,
      'lastEditedAt': editTime ?? DateTime.now(),
      'editCount': (currentEditCount ?? 0) + 1,
    };
  }

  /// Update edit metadata
  static Map<String, dynamic> updateEditMetadata({
    required Map<String, dynamic> currentMetadata,
    required String editedBy,
    required String editedByDisplayName,
    DateTime? editTime,
  }) {
    final updatedMetadata = Map<String, dynamic>.from(currentMetadata);
    final editTracking = createEditTracking(
      editedBy: editedBy,
      editedByDisplayName: editedByDisplayName,
      editTime: editTime,
      currentEditCount: currentMetadata['editCount'] as int? ?? 0,
    );
    
    updatedMetadata.addAll(editTracking);
    return updatedMetadata;
  }

  /// Check if edit is recent (within threshold)
  static bool isRecentEdit(DateTime? lastEditedAt, {Duration threshold = const Duration(minutes: 5)}) {
    if (lastEditedAt == null) return false;
    return DateTime.now().difference(lastEditedAt) < threshold;
  }

  /// Get edit frequency (edits per hour)
  static double getEditFrequency(int editCount, DateTime createdAt) {
    final duration = DateTime.now().difference(createdAt);
    final hours = duration.inHours.toDouble();
    return hours > 0 ? editCount / hours : editCount.toDouble();
  }

  // ===== ACTIVITY STATUS =====

  /// Update activity status based on recent edits
  static bool calculateActiveStatus({
    DateTime? lastEditedAt,
    bool? currentStatus,
    Duration inactivityThreshold = const Duration(hours: 24),
  }) {
    if (lastEditedAt == null) return false;
    
    final timeSinceLastEdit = DateTime.now().difference(lastEditedAt);
    return timeSinceLastEdit < inactivityThreshold;
  }

  /// Check if resource should be considered stale
  static bool isStaleResource(DateTime? lastEditedAt, {Duration staleThreshold = const Duration(days: 7)}) {
    if (lastEditedAt == null) return true;
    return DateTime.now().difference(lastEditedAt) > staleThreshold;
  }

  /// Get activity level (1-5)
  static int getActivityLevel({
    required int editCount,
    required DateTime createdAt,
    DateTime? lastEditedAt,
  }) {
    if (lastEditedAt == null) return 1;
    
    final frequency = getEditFrequency(editCount, createdAt);
    final recency = DateTime.now().difference(lastEditedAt).inHours;
    
    int level = 1;
    
    // Frequency score
    if (frequency > 0.5) level++; // More than 0.5 edits per hour
    if (frequency > 2.0) level++; // More than 2 edits per hour
    
    // Recency score
    if (recency < 24) level++; // Edited within 24 hours
    if (recency < 6) level++;  // Edited within 6 hours
    
    return level.clamp(1, 5);
  }

  // ===== SESSION MANAGEMENT =====

  /// Check if edit is part of same session
  static bool isSameEditSession({
    required String currentEditor,
    required String newEditor,
    DateTime? lastEditTime,
    Duration sessionTimeout = const Duration(minutes: 30),
  }) {
    if (currentEditor != newEditor) return false;
    if (lastEditTime == null) return true;
    
    return DateTime.now().difference(lastEditTime) < sessionTimeout;
  }

  /// Create session metadata
  static Map<String, dynamic> createSessionMetadata({
    required String editorId,
    required String editorDisplayName,
    DateTime? sessionStart,
    int? sessionEditCount,
  }) {
    return {
      'sessionEditorId': editorId,
      'sessionEditorDisplayName': editorDisplayName,
      'sessionStartedAt': sessionStart ?? DateTime.now(),
      'sessionEditCount': sessionEditCount ?? 1,
    };
  }

  /// Update session metadata
  static Map<String, dynamic> updateSessionMetadata({
    required Map<String, dynamic> currentSession,
    required String editorId,
    required String editorDisplayName,
  }) {
    final updatedSession = Map<String, dynamic>.from(currentSession);
    
    if (currentSession['sessionEditorId'] == editorId) {
      // Same editor, increment count
      updatedSession['sessionEditCount'] = (currentSession['sessionEditCount'] as int? ?? 0) + 1;
    } else {
      // New editor, start new session
      updatedSession.addAll(createSessionMetadata(
        editorId: editorId,
        editorDisplayName: editorDisplayName,
      ));
    }
    
    return updatedSession;
  }

  // ===== METADATA VALIDATION =====

  /// Validate metadata structure
  static bool isValidMetadata(Map<String, dynamic> metadata) {
    final requiredFields = ['lastEditedBy', 'lastEditedByDisplayName', 'lastEditedAt', 'editCount'];
    
    for (final field in requiredFields) {
      if (!metadata.containsKey(field)) return false;
    }
    
    // Type validation
    if (metadata['editCount'] is! int) return false;
    if (metadata['lastEditedAt'] is! DateTime) return false;
    
    return true;
  }

  /// Sanitize metadata
  static Map<String, dynamic> sanitizeMetadata(Map<String, dynamic> metadata) {
    final sanitized = <String, dynamic>{};
    
    sanitized['lastEditedBy'] = metadata['lastEditedBy']?.toString() ?? '';
    sanitized['lastEditedByDisplayName'] = metadata['lastEditedByDisplayName']?.toString() ?? '';
    sanitized['lastEditedAt'] = metadata['lastEditedAt'] as DateTime? ?? DateTime.now();
    sanitized['editCount'] = metadata['editCount'] as int? ?? 0;
    sanitized['isActive'] = metadata['isActive'] as bool? ?? true;
    
    // Copy additional metadata
    for (final entry in metadata.entries) {
      if (!sanitized.containsKey(entry.key)) {
        sanitized[entry.key] = entry.value;
      }
    }
    
    return sanitized;
  }

  // ===== ANALYTICS =====

  /// Calculate edit velocity (recent edits per hour)
  static double calculateEditVelocity({
    required List<DateTime> recentEdits,
    Duration window = const Duration(hours: 24),
  }) {
    final cutoff = DateTime.now().subtract(window);
    final relevantEdits = recentEdits.where((edit) => edit.isAfter(cutoff)).length;
    
    return relevantEdits / window.inHours;
  }

  /// Get collaboration score (0-100)
  static int getCollaborationScore({
    required int uniqueEditors,
    required int totalEdits,
    required Duration resourceAge,
  }) {
    if (totalEdits == 0) return 0;
    
    final editorsRatio = uniqueEditors / (uniqueEditors + 1); // Normalize
    final editFrequency = totalEdits / resourceAge.inDays.clamp(1, double.infinity);
    
    final score = (editorsRatio * 50 + editFrequency * 10).clamp(0, 100);
    return score.round();
  }

  /// Generate edit summary
  static Map<String, dynamic> generateEditSummary({
    required int totalEdits,
    required DateTime createdAt,
    DateTime? lastEditedAt,
    required String lastEditor,
    required int uniqueEditors,
  }) {
    return {
      'totalEdits': totalEdits,
      'uniqueEditors': uniqueEditors,
      'editFrequency': getEditFrequency(totalEdits, createdAt),
      'activityLevel': getActivityLevel(
        editCount: totalEdits,
        createdAt: createdAt,
        lastEditedAt: lastEditedAt,
      ),
      'collaborationScore': getCollaborationScore(
        uniqueEditors: uniqueEditors,
        totalEdits: totalEdits,
        resourceAge: DateTime.now().difference(createdAt),
      ),
      'isRecent': isRecentEdit(lastEditedAt),
      'isStale': isStaleResource(lastEditedAt),
      'lastEditor': lastEditor,
      'daysSinceCreated': DateTime.now().difference(createdAt).inDays,
      'daysSinceLastEdit': lastEditedAt != null 
          ? DateTime.now().difference(lastEditedAt).inDays 
          : null,
    };
  }
}