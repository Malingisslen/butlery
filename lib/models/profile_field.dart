/// A field of the own profile that a save can write.
///
/// A save names the fields it changes and writes only their keys (BUT-2513).
/// A profile this device read earlier, or one whose settings read failed and
/// holds empty values, then cannot put old values back over newer ones, such
/// as "Om mig" changed on another device or stored allergens.
///
/// Every key of [UserProfile.toFirestoreEditable] and
/// [UserProfile.toPrivateSettings] belongs to exactly one field, except
/// [alwaysWrittenPublicKeys] and [lastActiveAtKey]. `profile_field_test.dart` fails when a new key
/// is not listed.
enum ProfileField {
  displayName(publicKeys: ['displayName', 'displayNameLower']),
  avatarUrl(publicKeys: ['avatarUrl']),
  isSearchable(publicKeys: ['isSearchable']),
  allowEmailSearch(publicKeys: ['allowEmailSearch']),
  // Turning the status off also clears the live dot (BUT-912).
  showOnlineStatus(publicKeys: ['showOnlineStatus', 'isOnline']),
  shareActivityToFeed(publicKeys: ['shareActivityToFeed']),
  activityFeedEventTypes(publicKeys: ['activityFeedEventTypes']),
  cookingSkillLevel(publicKeys: ['cookingSkillLevel']),
  cuisineAffinities(publicKeys: ['cuisineAffinities']),
  bio(publicKeys: ['bio']),
  joinedAt(publicKeys: ['joinedAt']),
  fcmToken(settingsKeys: ['fcmToken', 'fcmTokenUpdatedAt']),
  notificationsEnabled(settingsKeys: ['notificationsEnabled']),
  preferredLocale(settingsKeys: ['preferredLocale']),
  allergenPreferences(settingsKeys: ['allergenPreferences']),
  hasCompletedOnboarding(settingsKeys: ['hasCompletedOnboarding']),
  onboardingSkippedAt(settingsKeys: ['onboardingSkippedAt']),
  hasSeenActivityFeedHint(settingsKeys: ['hasSeenActivityFeedHint']),
  autoAddBoughtToPantry(settingsKeys: ['autoAddBoughtToPantry']),
  useHouseholdAllergens(settingsKeys: ['useHouseholdAllergens']),
  useMealAllergenScope(settingsKeys: ['useMealAllergenScope']),
  showNutritionStrip(settingsKeys: ['showNutritionStrip']),
  pantryAutoAddPrompted(settingsKeys: ['pantryAutoAddPrompted']),
  householdSize(settingsKeys: ['householdSize']);

  const ProfileField({
    this.publicKeys = const [],
    this.settingsKeys = const [],
  });

  /// Keys on the profile document `public_profiles/{uid}`.
  final List<String> publicKeys;

  /// Keys on the private settings document `users/{uid}/settings/preferences`.
  final List<String> settingsKeys;

  /// Written by every save: the shape. [lastActiveAtKey] is written too, but
  /// only while the owner shows their online status (BUT-2516).
  static const List<String> alwaysWrittenPublicKeys = ['schemaVersion'];

  static const String lastActiveAtKey = 'lastActiveAt';

  /// Every field, for the first save of a profile that does not exist yet.
  static Set<ProfileField> get all => values.toSet();

  /// Every field on the public profile, for re-creating a missing public
  /// profile beside a settings document that already exists: the settings
  /// are the user's, and a first-save default would overwrite them.
  static Set<ProfileField> get publicOnly =>
      values.where((field) => field.settingsKeys.isEmpty).toSet();

  /// The part of [doc] (the profile document's map) that a save of [fields]
  /// writes.
  static Map<String, dynamic> publicPart(
    Map<String, dynamic> doc,
    Set<ProfileField> fields,
  ) => _pick(doc, [
    ...alwaysWrittenPublicKeys,
    // A hidden status must not leak through when the owner was last active.
    if (doc['showOnlineStatus'] != false) lastActiveAtKey,
    for (final field in fields) ...field.publicKeys,
  ]);

  /// The part of [settings] (the settings document's map) that a save of
  /// [fields] writes.
  static Map<String, dynamic> settingsPart(
    Map<String, dynamic> settings,
    Set<ProfileField> fields,
  ) => _pick(settings, [for (final field in fields) ...field.settingsKeys]);

  static Map<String, dynamic> _pick(
    Map<String, dynamic> source,
    List<String> keys,
  ) => {
    for (final key in keys)
      if (source.containsKey(key)) key: source[key],
  };
}
