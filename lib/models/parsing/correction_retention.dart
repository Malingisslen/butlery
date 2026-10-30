import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:butlery/services/llm/pii_scrubber.dart';

/// How long a user's correction log row is kept before the TTL policy on
/// `expireAt` deletes it. The same value is the basis of the 372-day ceiling in
/// `firestore.rules`, which leaves room for a device clock that runs ahead.
const Duration kCorrectionRetention = Duration(days: 365);

Timestamp correctionExpireAt() =>
    Timestamp.fromDate(clock.now().add(kCorrectionRetention));

/// Free text a user typed lands in these rows, so every string value is run
/// through the same scrubber the LLM sample capture uses. `type` is an enum
/// name, not user text.
Map<String, dynamic> scrubCorrectionStrings(Map<String, dynamic> json) => {
  for (final e in json.entries)
    e.key: e.key != 'type' && e.value is String
        ? scrubPii(e.value as String)
        : e.value,
};
