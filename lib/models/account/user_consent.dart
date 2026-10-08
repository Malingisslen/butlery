import 'package:clock/clock.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:butlery/core/utils/serialization_utils.dart';

/// Model representing user consent for GDPR compliance (Article 7)
/// Tracks user consent for different data processing purposes with
/// timestamps and version tracking as required by GDPR.
class UserConsent {
  final String userId;
  final ConsentPurposes purposes;
  final DateTime grantedAt;
  final DateTime? updatedAt;
  final String consentVersion;
  final String? ipAddress;
  final String deviceInfo;

  const UserConsent({
    required this.userId,
    required this.purposes,
    required this.grantedAt,
    this.updatedAt,
    required this.consentVersion,
    this.ipAddress,
    required this.deviceInfo,
  });

  /// Create UserConsent from Firestore document
  factory UserConsent.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>;
    return UserConsent(
      userId: SerializationUtils.safeString(
        data,
        'userId',
      ), // Read from document data for data integrity
      purposes: ConsentPurposes.fromMap(
        SerializationUtils.safeMap(data, 'purposes'),
      ),
      grantedAt:
          SerializationUtils.safeDateTime(data, 'grantedAt') ?? clock.now(),
      updatedAt: SerializationUtils.safeDateTime(data, 'updatedAt'),
      consentVersion: SerializationUtils.safeString(data, 'consentVersion'),
      ipAddress: SerializationUtils.safeNullableString(data, 'ipAddress'),
      deviceInfo: SerializationUtils.safeString(data, 'deviceInfo'),
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId, // Store userId for data integrity and GDPR compliance
      'purposes': purposes.toMap(),
      'grantedAt': Timestamp.fromDate(grantedAt),
      'updatedAt': updatedAt != null ? Timestamp.fromDate(updatedAt!) : null,
      'consentVersion': consentVersion,
      'ipAddress': ipAddress,
      'deviceInfo': deviceInfo,
    };
  }

  /// Create copy with updated fields
  UserConsent copyWith({
    String? userId,
    ConsentPurposes? purposes,
    DateTime? grantedAt,
    DateTime? updatedAt,
    String? consentVersion,
    String? ipAddress,
    String? deviceInfo,
  }) {
    return UserConsent(
      userId: userId ?? this.userId,
      purposes: purposes ?? this.purposes,
      grantedAt: grantedAt ?? this.grantedAt,
      updatedAt: updatedAt ?? this.updatedAt,
      consentVersion: consentVersion ?? this.consentVersion,
      ipAddress: ipAddress ?? this.ipAddress,
      deviceInfo: deviceInfo ?? this.deviceInfo,
    );
  }

  /// Check if consent needs renewal (e.g., version changed)
  bool needsRenewal(String currentVersion) {
    return consentVersion != currentVersion;
  }

  /// Check if all required consents are granted
  bool get hasRequiredConsents {
    return purposes.essentialServices && purposes.dataProcessing;
  }
}

/// Consent purpose identifiers for compile-safe hasConsent() calls.
/// Enum `.name` matches the Firestore document keys (camelCase).
enum ConsentPurpose {
  essentialServices,
  dataProcessing,
  analytics,
  marketing,
  socialFeatures,
  pushNotifications,
  aiProcessing,
}

/// Tracks consent for different data processing purposes
/// GDPR requires explicit consent for each purpose separately.
class ConsentPurposes {
  final bool essentialServices;
  final bool dataProcessing;
  final bool analytics;
  final bool marketing;
  final bool socialFeatures;
  final bool pushNotifications;
  final bool aiProcessing;

  const ConsentPurposes({
    required this.essentialServices,
    required this.dataProcessing,
    this.analytics = false,
    this.marketing = false,
    this.socialFeatures = false,
    this.pushNotifications = false,
    this.aiProcessing = false,
  });

  /// Create from Firestore map
  factory ConsentPurposes.fromMap(Map<String, dynamic> map) {
    return ConsentPurposes(
      essentialServices: SerializationUtils.safeBool(
        map,
        ConsentPurpose.essentialServices.name,
        defaultValue: true,
      ),
      dataProcessing: SerializationUtils.safeBool(
        map,
        ConsentPurpose.dataProcessing.name,
        defaultValue: true,
      ),
      analytics: SerializationUtils.safeBool(
        map,
        ConsentPurpose.analytics.name,
        defaultValue: false,
      ),
      marketing: SerializationUtils.safeBool(
        map,
        ConsentPurpose.marketing.name,
        defaultValue: false,
      ),
      socialFeatures: SerializationUtils.safeBool(
        map,
        ConsentPurpose.socialFeatures.name,
        defaultValue: false,
      ),
      pushNotifications: SerializationUtils.safeBool(
        map,
        ConsentPurpose.pushNotifications.name,
        defaultValue: false,
      ),
      aiProcessing: SerializationUtils.safeBool(
        map,
        ConsentPurpose.aiProcessing.name,
        defaultValue: false,
      ),
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      ConsentPurpose.essentialServices.name: essentialServices,
      ConsentPurpose.dataProcessing.name: dataProcessing,
      ConsentPurpose.analytics.name: analytics,
      ConsentPurpose.marketing.name: marketing,
      ConsentPurpose.socialFeatures.name: socialFeatures,
      ConsentPurpose.pushNotifications.name: pushNotifications,
      ConsentPurpose.aiProcessing.name: aiProcessing,
    };
  }

  /// Type-safe accessor — exhaustive switch ensures compile error when new purposes are added.
  bool operator [](ConsentPurpose purpose) => switch (purpose) {
    ConsentPurpose.essentialServices => essentialServices,
    ConsentPurpose.dataProcessing => dataProcessing,
    ConsentPurpose.analytics => analytics,
    ConsentPurpose.marketing => marketing,
    ConsentPurpose.socialFeatures => socialFeatures,
    ConsentPurpose.pushNotifications => pushNotifications,
    ConsentPurpose.aiProcessing => aiProcessing,
  };

  /// Create default consents (only essential services)
  factory ConsentPurposes.defaults() {
    return const ConsentPurposes(
      essentialServices: true,
      dataProcessing: true,
      analytics: false,
      marketing: false,
      socialFeatures: false,
      pushNotifications: false,
      aiProcessing: false,
    );
  }

  /// Create copy with updated fields
  ConsentPurposes copyWith({
    bool? essentialServices,
    bool? dataProcessing,
    bool? analytics,
    bool? marketing,
    bool? socialFeatures,
    bool? pushNotifications,
    bool? aiProcessing,
  }) {
    return ConsentPurposes(
      essentialServices: essentialServices ?? this.essentialServices,
      dataProcessing: dataProcessing ?? this.dataProcessing,
      analytics: analytics ?? this.analytics,
      marketing: marketing ?? this.marketing,
      socialFeatures: socialFeatures ?? this.socialFeatures,
      pushNotifications: pushNotifications ?? this.pushNotifications,
      aiProcessing: aiProcessing ?? this.aiProcessing,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ConsentPurposes &&
        other.essentialServices == essentialServices &&
        other.dataProcessing == dataProcessing &&
        other.analytics == analytics &&
        other.marketing == marketing &&
        other.socialFeatures == socialFeatures &&
        other.pushNotifications == pushNotifications &&
        other.aiProcessing == aiProcessing;
  }

  @override
  int get hashCode {
    return Object.hash(
      essentialServices,
      dataProcessing,
      analytics,
      marketing,
      socialFeatures,
      pushNotifications,
      aiProcessing,
    );
  }
}

/// How a purpose changed in a consent version.
enum ConsentChangeKind {
  /// The purpose did not exist before this version.
  added,

  /// The purpose exists but what it covers changed.
  changed,
}

/// One line of "what changed" in a consent version.
///
/// "Förnyelse visar vad som ändrats. `needsRenewal` är enbart en
/// versionsjämförelse, så gränssnittet får inte påstå att något viktigt
/// hänt utan att säga vad" (produktregler.md:731). Whoever bumps the consent
/// version adds its lines to `ConsentService.changelog` in the same change
/// (Q-P6-A18); the sentence shown for each line lives in the l10n files.
class ConsentChange {
  const ConsentChange({
    required this.version,
    required this.purpose,
    required this.kind,
  });

  /// The consent version that made the change.
  final String version;

  final ConsentPurpose purpose;
  final ConsentChangeKind kind;
}

/// Compares two dotted version strings numerically ("1.10.0" > "1.9.0").
/// A missing or non-numeric part counts as 0.
int compareConsentVersions(String a, String b) {
  List<int> parts(String v) =>
      v.split('.').map((p) => int.tryParse(p.trim()) ?? 0).toList();
  final pa = parts(a);
  final pb = parts(b);
  final length = pa.length > pb.length ? pa.length : pb.length;
  for (var i = 0; i < length; i++) {
    final x = i < pa.length ? pa[i] : 0;
    final y = i < pb.length ? pb[i] : 0;
    if (x != y) return x.compareTo(y);
  }
  return 0;
}
