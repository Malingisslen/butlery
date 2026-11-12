/// The campaign channel the app has learned about but may not yet record.
///
/// Held in memory only: writing it to the device before the user has agreed
/// to statistics would need that consent itself, so a process that dies
/// before consent simply loses it.
library;

import 'package:butlery/core/extensions/default_value_extensions.dart';

/// Mirrors the allowlists in `functions/src/analytics/acquisition-counter.ts`.
/// Anything else is kept as [AcquisitionChannel.other], so no free text from a
/// link reaches the account.
const Set<String> _knownSources = {
  'instagram',
  'facebook',
  'tiktok',
  'google',
  'newsletter',
  'email',
  'friend_invite',
  'google-play',
};

const Set<String> _knownMediums = {
  'social',
  'paid_social',
  'cpc',
  'email',
  'referral',
  'organic',
};

class AcquisitionChannel {
  static const String other = 'other';
  static const String playSource = 'google-play';

  final String source;
  final String medium;

  const AcquisitionChannel._(this.source, this.medium);

  /// Null when [rawSource] is missing or empty: a link without a source says
  /// nothing about where the person came from.
  static AcquisitionChannel? from(String? rawSource, String? rawMedium) {
    final source = rawSource.orEmpty().trim().toLowerCase();
    if (source.isEmpty) return null;
    final medium = rawMedium.orEmpty().trim().toLowerCase();
    return AcquisitionChannel._(
      _knownSources.contains(source) ? source : other,
      _knownMediums.contains(medium) ? medium : (medium.isEmpty ? '' : other),
    );
  }

  /// Reads source and medium out of a Google Play install referrer such as
  /// `utm_source=instagram&utm_medium=social&gclid=...`. Everything else in
  /// the string is dropped unread.
  static AcquisitionChannel? fromInstallReferrer(String? referrer) {
    if (referrer == null || referrer.isEmpty) return null;
    try {
      final params = Uri.splitQueryString(referrer);
      return from(params['utm_source'], params['utm_medium']);
    } on ArgumentError {
      return null;
    }
  }

  bool get isPlayOrganic => source == playSource;
}

class PendingAcquisition {
  PendingAcquisition._();

  static AcquisitionChannel? _channel;

  static AcquisitionChannel? get current => _channel;

  /// The first link seen wins, matching the first-write-wins row.
  static void rememberIfAbsent(AcquisitionChannel? channel) {
    if (channel != null) _channel ??= channel;
  }

  /// An install referrer is the earliest touch, so it replaces a later link,
  /// except an organic Play install, which carries no campaign to prefer.
  static void rememberInstallReferrer(AcquisitionChannel? channel) {
    if (channel == null) return;
    if (channel.isPlayOrganic && _channel != null) return;
    _channel = channel;
  }

  static void clear() => _channel = null;
}
