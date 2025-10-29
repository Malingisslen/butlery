// lib/widgets/recipe/comment_time_formatter.dart

/// Utility for formatting comment timestamps into human-readable relative time strings.
class CommentTimeFormatter {
  CommentTimeFormatter._();

  /// Formats a DateTime into a human-readable relative time string.
  ///
  /// Returns Swedish-formatted relative times:
  /// - "nu" for < 1 minute ago
  /// - "Xm" for X minutes ago
  /// - "Xh" for X hours ago
  /// - "Xd" for X days ago (< 7 days)
  /// - "DD/MM" for dates 7+ days ago
  static String format(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inMinutes < 1) {
      return 'nu';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes}m';
    } else if (difference.inDays < 1) {
      return '${difference.inHours}h';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d';
    } else {
      return '${dateTime.day}/${dateTime.month}';
    }
  }
}
