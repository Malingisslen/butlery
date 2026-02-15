/// Circular buffer logger that tracks the last 20 user interactions
/// for inclusion in beta feedback submissions.

/// Single interaction entry capturing screen context and action type.
class InteractionEntry {
  final String screenName;
  final String actionType;
  final DateTime timestamp;

  InteractionEntry({
    required this.screenName,
    required this.actionType,
    required this.timestamp,
  });

  Map<String, dynamic> toJson() => {
        'screenName': screenName,
        'actionType': actionType,
        'timestamp': timestamp.toIso8601String(),
      };
}

/// Tracks recent user interactions in a fixed-size circular buffer.
/// Used by the feedback system to provide context about what the user
/// was doing before submitting feedback.
class InteractionLogger {
  static const int _bufferSize = 20;

  final List<InteractionEntry?> _buffer =
      List<InteractionEntry?>.filled(_bufferSize, null);
  int _head = 0;
  int _count = 0;

  /// Record an interaction with screen name and action type.
  void logInteraction(String screenName, String actionType) {
    _buffer[_head] = InteractionEntry(
      screenName: screenName,
      actionType: actionType,
      timestamp: DateTime.now(),
    );
    _head = (_head + 1) % _bufferSize;
    if (_count < _bufferSize) _count++;
  }

  /// Returns the last N interactions in chronological order.
  List<InteractionEntry> getRecentInteractions() {
    if (_count == 0) return [];

    final result = <InteractionEntry>[];
    // Start index is the oldest entry in the buffer
    final start = _count < _bufferSize ? 0 : _head;

    for (int i = 0; i < _count; i++) {
      final index = (start + i) % _bufferSize;
      final entry = _buffer[index];
      if (entry != null) result.add(entry);
    }

    return result;
  }

  /// Serializes recent interactions to a JSON-compatible list.
  List<Map<String, dynamic>> toJsonList() {
    return getRecentInteractions().map((e) => e.toJson()).toList();
  }
}
