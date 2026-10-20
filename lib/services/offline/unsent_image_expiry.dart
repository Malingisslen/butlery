// lib/services/offline/unsent_image_expiry.dart
//
// BUT-2294: how long a photo that could not be sent waits for the user before
// the queue throws it away. Pure functions, so the card in "Väntar på synk"
// and the queue's cleanup read the same boundaries.
library;

/// Malin decided 2026-10-20 on 30 days; the privacy policy names the same
/// number, so a change here is a change there.
const Duration kUnsentImageKeep = Duration(days: 30);

/// Where the 30 days start: the first failed attempt, and the time the photo
/// was queued for a row that never recorded one (a refusal on the first try
/// is permanent at once and has no retry window).
DateTime unsentImageSince(DateTime? firstFailedAt, DateTime queuedAt) =>
    firstFailedAt ?? queuedAt;

/// Whole days left before the photo is thrown away, rounded up so the card
/// never says 0 days while the photo is still there. Zero means due now.
int unsentImageDaysLeft(DateTime since, DateTime now) {
  final left = since.add(kUnsentImageKeep).difference(now);
  if (left <= Duration.zero) return 0;
  return (left.inMicroseconds / Duration.microsecondsPerDay).ceil();
}

/// Whether the photo has waited out the whole period.
bool unsentImageExpired(DateTime since, DateTime now) =>
    unsentImageDaysLeft(since, now) == 0;
