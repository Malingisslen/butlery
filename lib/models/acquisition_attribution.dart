/// Acquisition attribution captured from the first UTM-tagged deep link
/// click for a user. Persisted at `users/{uid}/acquisition/current`.
///
/// First-write-wins: once written, never overwritten — preserves
/// original-source attribution even if the user clicks later UTM links.
library;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';

class AcquisitionAttribution {
  /// utm_source — the channel ad / referrer host (e.g. "instagram", "google").
  final String source;

  /// utm_medium — broad category (e.g. "cpc", "social", "email").
  final String medium;

  /// utm_campaign — campaign identifier set by marketing.
  final String campaign;

  /// Server-assigned timestamp of the first UTM click. May be null in-flight
  /// before the server resolves [FieldValue.serverTimestamp].
  final DateTime? firstSeenAt;

  const AcquisitionAttribution({
    required this.source,
    required this.medium,
    required this.campaign,
    this.firstSeenAt,
  });

  /// Build the Firestore payload for first-write. `firstSeenAt` is written
  /// as `serverTimestamp()` so dedupe logic doesn't depend on client clocks.
  Map<String, dynamic> toFirestore() => <String, dynamic>{
        'source': source,
        'medium': medium,
        'campaign': campaign,
        'firstSeenAt': FieldValue.serverTimestamp(),
      };

  factory AcquisitionAttribution.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const <String, dynamic>{};
    final ts = data['firstSeenAt'];
    return AcquisitionAttribution(
      source: (data['source'] as String?).orEmpty(),
      medium: (data['medium'] as String?).orEmpty(),
      campaign: (data['campaign'] as String?).orEmpty(),
      firstSeenAt: ts is Timestamp ? ts.toDate() : null,
    );
  }
}
