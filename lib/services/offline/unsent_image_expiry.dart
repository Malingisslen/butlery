// lib/services/offline/unsent_image_expiry.dart
//
// BUT-2294: how long an unsent photo waits before the queue throws it away.
// Pure functions, so the card in "Väntar på synk" and the queue's cleanup read
// the same boundaries.
library;

/// Malin decided 2026-10-20 on 30 days; the privacy policy names the same
/// number, so a change here is a change there.
const Duration kUnsentImageKeep = Duration(days: 30);

/// Where the 30 days start: the user's last retry, else the first failed
/// attempt, else the time the photo was queued. A retry clears
/// [firstFailedAt] and so does an upload, so on their own they would send an
/// old photo back to [queuedAt] and expire it at once.
DateTime unsentImageSince(
  DateTime? firstFailedAt,
  DateTime queuedAt, {
  DateTime? retriedAt,
}) => retriedAt ?? firstFailedAt ?? queuedAt;

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
