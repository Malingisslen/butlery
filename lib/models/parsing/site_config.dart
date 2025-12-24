import 'package:cloud_firestore/cloud_firestore.dart';

/// Configuration for parsing a specific recipe website.
///
/// Stored in Firestore under `/site_configs/{domain}`.
/// This allows updating site selectors without app releases.
class SiteConfig {
  /// Domain name (e.g., "ica.se", "koket.se").
  final String domain;

  /// CSS selector for recipe title.
  final String? titleSelector;

  /// CSS selector for ingredients list items.
  final String? ingredientsSelector;

  /// CSS selector for instruction steps.
  final String? instructionsSelector;

  /// CSS selector for portions/servings.
  final String? portionsSelector;

  /// CSS selector for cooking time.
  final String? timeSelector;

  /// CSS selector for recipe image.
  final String? imageSelector;

  /// CSS selector for description.
  final String? descriptionSelector;

  /// Whether this site is actively supported.
  final bool isSupported;

  /// Quality score based on historical success rate (0.0-1.0).
  final double qualityScore;

  /// Number of recipes successfully parsed from this site.
  final int successCount;

  /// Number of failed parse attempts.
  final int failureCount;

  /// When this config was last updated.
  final DateTime? lastUpdated;

  /// Additional notes or quirks about this site.
  final String? notes;

  const SiteConfig({
    required this.domain,
    this.titleSelector,
    this.ingredientsSelector,
    this.instructionsSelector,
    this.portionsSelector,
    this.timeSelector,
    this.imageSelector,
    this.descriptionSelector,
    this.isSupported = true,
    this.qualityScore = 0.5,
    this.successCount = 0,
    this.failureCount = 0,
    this.lastUpdated,
    this.notes,
  });

  /// Whether this config has usable selectors.
  bool get hasSelectors =>
      titleSelector != null ||
      ingredientsSelector != null ||
      instructionsSelector != null;

  /// Whether this config is likely to produce good results.
  bool get isReliable => isSupported && qualityScore >= 0.7 && hasSelectors;

  /// Historical success rate.
  double get successRate {
    final total = successCount + failureCount;
    if (total == 0) return 0.5; // No data, assume 50%
    return successCount / total;
  }

  /// Creates a copy with updated fields.
  SiteConfig copyWith({
    String? domain,
    String? titleSelector,
    String? ingredientsSelector,
    String? instructionsSelector,
    String? portionsSelector,
    String? timeSelector,
    String? imageSelector,
    String? descriptionSelector,
    bool? isSupported,
    double? qualityScore,
    int? successCount,
    int? failureCount,
    DateTime? lastUpdated,
    String? notes,
  }) =>
      SiteConfig(
        domain: domain ?? this.domain,
        titleSelector: titleSelector ?? this.titleSelector,
        ingredientsSelector: ingredientsSelector ?? this.ingredientsSelector,
        instructionsSelector: instructionsSelector ?? this.instructionsSelector,
        portionsSelector: portionsSelector ?? this.portionsSelector,
        timeSelector: timeSelector ?? this.timeSelector,
        imageSelector: imageSelector ?? this.imageSelector,
        descriptionSelector: descriptionSelector ?? this.descriptionSelector,
        isSupported: isSupported ?? this.isSupported,
        qualityScore: qualityScore ?? this.qualityScore,
        successCount: successCount ?? this.successCount,
        failureCount: failureCount ?? this.failureCount,
        lastUpdated: lastUpdated ?? this.lastUpdated,
        notes: notes ?? this.notes,
      );

  /// Converts to Firestore document.
  Map<String, dynamic> toFirestore() => {
        'domain': domain,
        if (titleSelector != null) 'titleSelector': titleSelector,
        if (ingredientsSelector != null)
          'ingredientsSelector': ingredientsSelector,
        if (instructionsSelector != null)
          'instructionsSelector': instructionsSelector,
        if (portionsSelector != null) 'portionsSelector': portionsSelector,
        if (timeSelector != null) 'timeSelector': timeSelector,
        if (imageSelector != null) 'imageSelector': imageSelector,
        if (descriptionSelector != null)
          'descriptionSelector': descriptionSelector,
        'isSupported': isSupported,
        'qualityScore': qualityScore,
        'successCount': successCount,
        'failureCount': failureCount,
        'lastUpdated': FieldValue.serverTimestamp(),
        if (notes != null) 'notes': notes,
      };

  /// Creates from Firestore document.
  factory SiteConfig.fromFirestore(Map<String, dynamic> data) => SiteConfig(
        domain: data['domain'] as String? ?? '',
        titleSelector: data['titleSelector'] as String?,
        ingredientsSelector: data['ingredientsSelector'] as String?,
        instructionsSelector: data['instructionsSelector'] as String?,
        portionsSelector: data['portionsSelector'] as String?,
        timeSelector: data['timeSelector'] as String?,
        imageSelector: data['imageSelector'] as String?,
        descriptionSelector: data['descriptionSelector'] as String?,
        isSupported: data['isSupported'] as bool? ?? true,
        qualityScore: (data['qualityScore'] as num?)?.toDouble() ?? 0.5,
        successCount: data['successCount'] as int? ?? 0,
        failureCount: data['failureCount'] as int? ?? 0,
        lastUpdated: data['lastUpdated'] != null
            ? (data['lastUpdated'] as Timestamp).toDate()
            : null,
        notes: data['notes'] as String?,
      );

  /// Creates default config for a domain.
  factory SiteConfig.defaultFor(String domain) => SiteConfig(
        domain: domain,
        isSupported: false,
        qualityScore: 0.0,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is SiteConfig &&
          runtimeType == other.runtimeType &&
          domain == other.domain;

  @override
  int get hashCode => domain.hashCode;

  @override
  String toString() =>
      'SiteConfig($domain, supported: $isSupported, quality: ${(qualityScore * 100).toStringAsFixed(0)}%)';
}
