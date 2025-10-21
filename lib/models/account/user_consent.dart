import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing user consent for GDPR compliance (Article 7)
///
/// Tracks user consent for different data processing purposes with
/// timestamps and version tracking as required by GDPR.
class UserConsent {
  final String userId;
  final ConsentPurposes purposes;
  final DateTime grantedAt;
  final DateTime? updatedAt;
  final String consentVersion; // Track consent policy version
  final String? ipAddress; // Optional: IP address when consent was given
  final String deviceInfo; // Device/platform where consent was given

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
      userId: doc.id,
      purposes: ConsentPurposes.fromMap(data['purposes'] as Map<String, dynamic>),
      grantedAt: (data['grantedAt'] as Timestamp).toDate(),
      updatedAt: data['updatedAt'] != null
          ? (data['updatedAt'] as Timestamp).toDate()
          : null,
      consentVersion: data['consentVersion'] as String,
      ipAddress: data['ipAddress'] as String?,
      deviceInfo: data['deviceInfo'] as String,
    );
  }

  /// Convert to Firestore document
  Map<String, dynamic> toFirestore() {
    return {
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

/// Tracks consent for different data processing purposes
///
/// GDPR requires explicit consent for each purpose separately.
class ConsentPurposes {
  final bool essentialServices; // Required for app functionality
  final bool dataProcessing; // Required for core features (recipes, etc.)
  final bool analytics; // Optional: Usage analytics
  final bool marketing; // Optional: Marketing communications
  final bool socialFeatures; // Optional: Social features (sharing, friends)
  final bool pushNotifications; // Optional: Push notifications

  const ConsentPurposes({
    required this.essentialServices,
    required this.dataProcessing,
    this.analytics = false,
    this.marketing = false,
    this.socialFeatures = false,
    this.pushNotifications = false,
  });

  /// Create from Firestore map
  factory ConsentPurposes.fromMap(Map<String, dynamic> map) {
    return ConsentPurposes(
      essentialServices: map['essentialServices'] as bool? ?? true,
      dataProcessing: map['dataProcessing'] as bool? ?? true,
      analytics: map['analytics'] as bool? ?? false,
      marketing: map['marketing'] as bool? ?? false,
      socialFeatures: map['socialFeatures'] as bool? ?? false,
      pushNotifications: map['pushNotifications'] as bool? ?? false,
    );
  }

  /// Convert to Firestore map
  Map<String, dynamic> toMap() {
    return {
      'essentialServices': essentialServices,
      'dataProcessing': dataProcessing,
      'analytics': analytics,
      'marketing': marketing,
      'socialFeatures': socialFeatures,
      'pushNotifications': pushNotifications,
    };
  }

  /// Create default consents (only essential services)
  factory ConsentPurposes.defaults() {
    return const ConsentPurposes(
      essentialServices: true,
      dataProcessing: true,
      analytics: false,
      marketing: false,
      socialFeatures: false,
      pushNotifications: false,
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
  }) {
    return ConsentPurposes(
      essentialServices: essentialServices ?? this.essentialServices,
      dataProcessing: dataProcessing ?? this.dataProcessing,
      analytics: analytics ?? this.analytics,
      marketing: marketing ?? this.marketing,
      socialFeatures: socialFeatures ?? this.socialFeatures,
      pushNotifications: pushNotifications ?? this.pushNotifications,
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
        other.pushNotifications == pushNotifications;
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
    );
  }
}
