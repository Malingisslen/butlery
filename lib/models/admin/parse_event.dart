import 'package:cloud_firestore/cloud_firestore.dart';

/// One recipe-parse attempt, read by the admin drill-down from import health to
/// the underlying imports. Written server-side by `logParseEvent`.
class ParseEvent {
  final String domain;
  final bool success;
  final DateTime? timestamp;
  final String? url;
  final String? successfulTier;

  const ParseEvent({
    required this.domain,
    required this.success,
    this.timestamp,
    this.url,
    this.successfulTier,
  });

  factory ParseEvent.fromFirestore(Map<String, dynamic> data) {
    final ts = data['timestamp'];
    return ParseEvent(
      domain: (data['domain'] as String?) ?? 'unknown',
      success: data['success'] == true,
      timestamp: ts is Timestamp ? ts.toDate() : null,
      url: data['url'] as String?,
      successfulTier: data['successfulTier'] as String?,
    );
  }
}
