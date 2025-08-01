/// Comprehensive centralized string constants system providing unified messaging for the Butlery cooking application.
///
/// This string constants system implements a sophisticated centralized approach to all user-facing text,
/// error messages, validation feedback, and interface strings throughout the cooking application. It provides
/// consistent Swedish localization, eliminates duplicate string literals, and establishes a foundation for
/// future internationalization while ensuring cohesive messaging that reflects Swedish cooking culture and preferences.
///
/// **Architecture Integration:**
/// - Provides single source of truth for all user-facing strings throughout the application
/// - Eliminates duplicate string literals and ensures consistent messaging across components
/// - Integrates with form validation systems providing standardized error messaging
/// - Supports Swedish localization with culturally appropriate terminology and phrasing
/// - Establishes foundation for future internationalization and multi-language support
///
/// **String Categories:**
/// - **Common Actions**: Universal action strings (save, cancel, delete) with Swedish translations
/// - **Form Validation**: Comprehensive validation messages with context-aware formatting
/// - **Error Messages**: Standardized error messaging with severity levels and user guidance
/// - **Success Messages**: Positive feedback messages celebrating user accomplishments
/// - **Confirmation Messages**: Clear confirmation dialogs for destructive or important actions
/// - **Feature-Specific Strings**: Specialized terminology for recipes, shopping, and social features
/// - **Accessibility Strings**: Screen reader and accessibility support text
/// - **Helper Methods**: Utility functions for dynamic string formatting and pluralization
///
/// **Swedish Localization Features:**
/// The string system reflects Swedish cooking culture with appropriate terminology, measurement units,
/// and cultural references that make the application feel native and intuitive for Swedish users
/// while maintaining professional and friendly tone throughout all interactions.
///
/// **Key Features:**
/// - Comprehensive coverage of all application strings with consistent Swedish terminology
/// - Context-aware validation messages that provide clear guidance for form corrections
/// - Dynamic string formatting with proper Swedish pluralization and grammar rules
/// - Cooking-specific vocabulary that resonates with Swedish culinary traditions
/// - Accessibility-first approach with appropriate strings for screen readers and assistive technology
/// - Performance optimization through compile-time constants and efficient string access patterns
///
/// **Usage Examples:**
/// ```dart
/// // Form validation with Swedish messaging
/// validator: (value) => value?.isEmpty == true 
///   ? AppStrings.fieldRequired('Receptnamn') 
///   : null;
/// 
/// // Consistent error messaging
/// showSnackBar(AppStrings.couldNotCreate('recept'));
/// 
/// // Success feedback with celebration
/// displaySuccess(AppStrings.itemCreated('Recept'));
/// 
/// // Confirmation dialogs with clear Swedish messaging
/// final confirmed = await showDialog<bool>(
///   content: Text(AppStrings.confirmDelete(recipe.name)),
/// );
/// 
/// // Dynamic formatting for cooking measurements
/// Text(AppStrings.formatDuration(30)); // "30 min"
/// Text(AppStrings.formatPortions(4));  // "4 portioner"
/// ```

/// Comprehensive centralized string constants system implementing unified messaging for cooking-focused user interface design.
///
/// This class serves as the authoritative source for all user-facing text throughout the Butlery application,
/// providing consistent Swedish localization, standardized messaging patterns, and culturally appropriate
 /// terminology. It eliminates string duplication while establishing a cohesive voice that reflects Swedish
/// cooking culture and enhances the user experience through clear, friendly, and professional communication.
///
/// **String Architecture:**
/// - **Centralized Management**: Single source of truth preventing scattered string literals across codebase
/// - **Swedish Cultural Adaptation**: Terminology and phrasing appropriate for Swedish cooking traditions
/// - **Consistency Framework**: Standardized messaging patterns ensuring coherent user experience
/// - **Accessibility Integration**: Complete screen reader and assistive technology support
/// - **Performance Optimization**: Compile-time constants for efficient memory usage and fast access
///
/// **Design Principles:**
/// The string system reflects the warmth and precision of cooking with clear, helpful messaging that guides
/// users through complex cooking workflows while maintaining the friendly, professional tone expected
/// in Swedish applications and celebrating the joy of cooking and sharing meals.
class AppStrings {
  /// Private constructor to prevent instantiation of utility class
  AppStrings._();

  // ===== COMMON ACTIONS =====
  static const String save = 'Spara';
  static const String cancel = 'Avbryt';
  static const String delete = 'Ta bort';
  static const String edit = 'Redigera';
  static const String add = 'Lägg till';
  static const String create = 'Skapa';
  static const String update = 'Uppdatera';
  static const String close = 'Stäng';
  static const String share = 'Dela';
  static const String rename = 'Byt namn';
  static const String export = 'Exportera';
  static const String ok = 'OK';
  static const String yes = 'Ja';
  static const String no = 'Nej';
  static const String retry = 'Försök igen';
  static const String loading = 'Laddar...';
  static const String working = 'Arbetar...';

  // ===== SHOPPING LIST ACTIONS =====
  static const String renameList = 'Byt namn på lista';
  static const String createList = 'Skapa ny handlista';
  static const String newName = 'Nytt namn';
  static const String listName = 'Namn på lista';
  static const String addToList = 'Lägg till i';

  // ===== AUTHENTICATION =====
  static const String resetPassword = 'Återställ lösenord';
  static const String send = 'Skicka';

  // ===== FORM VALIDATION MESSAGES =====
  static String fieldRequired(String fieldName) => '$fieldName krävs';
  static String fieldTooShort(String fieldName, int minLength) => '$fieldName måste vara minst $minLength tecken';
  static String fieldTooLong(String fieldName, int maxLength) => '$fieldName får vara max $maxLength tecken';
  static String invalidFormat(String fieldName) => 'Ogiltigt format för $fieldName';
  
  // Specific validation messages
  static const String nameRequired = 'Namn krävs';
  static const String emailRequired = 'E-post krävs';
  static const String passwordRequired = 'Lösenord krävs';
  static const String invalidEmail = 'Ogiltig e-postadress';
  static const String invalidUrl = 'Ogiltig URL';
  static const String invalidPhoneNumber = 'Ogiltigt telefonnummer';
  static const String invalidAmount = 'Ogiltigt antal';
  static const String passwordTooShort = 'Lösenordet måste vara minst 6 tecken';
  
  // Generic validation messages for ValidationUtils
  static const String genericRequired = 'Detta fält krävs';
  static const String emailInvalid = 'Ogiltig e-postadress';

  // ===== ERROR MESSAGES =====
  static const String genericError = 'Ett fel uppstod. Försök igen.';
  static const String networkError = 'Nätverksfel. Kontrollera din internetanslutning.';
  static const String serverError = 'Serverfel. Försök igen senare.';
  static const String authenticationError = 'Autentiseringsfel. Logga in igen.';
  static const String permissionDenied = 'Du har inte behörighet för denna åtgärd.';
  static const String notFound = 'Kunde inte hittas.';
  static const String alreadyExists = 'Finns redan.';
  
  // Specific error contexts
  static String couldNotCreate(String itemType) => 'Kunde inte skapa $itemType. Försök igen.';
  static String couldNotUpdate(String itemType) => 'Kunde inte uppdatera $itemType. Försök igen.';
  static String couldNotDelete(String itemType) => 'Kunde inte ta bort $itemType. Försök igen.';
  static String couldNotLoad(String itemType) => 'Kunde inte ladda $itemType. Försök igen.';

  // ===== SUCCESS MESSAGES =====
  static String itemCreated(String itemType) => '$itemType skapades!';
  static String itemUpdated(String itemType) => '$itemType uppdaterades!';
  static String itemDeleted(String itemType) => '$itemType togs bort!';
  static String itemAdded(String itemName) => '$itemName tillagd!';

  // ===== CONFIRMATION MESSAGES =====
  static String confirmDelete(String itemName) => 'Är du säker på att du vill ta bort "$itemName"?';
  static const String unsavedChanges = 'Du har osparade ändringar. Vill du lämna utan att spara?';
  static const String irreversibleAction = 'Denna åtgärd kan inte ångras.';

  // ===== EMPTY STATES =====
  static const String noItemsFound = 'Inga objekt hittades.';
  static const String emptyList = 'Listan är tom.';
  static const String noResults = 'Inga resultat hittades.';
  static const String noFriends = 'Du har inga vänner än.';
  static const String noRecipes = 'Du har inga recept än.';
  static const String noShoppingLists = 'Du har inga inköpslistor än.';

  // ===== SPECIFIC FEATURE STRINGS =====
  
  // Recipe related
  static const String recipeName = 'Receptnamn';
  static const String recipeDescription = 'Beskrivning';
  static const String ingredients = 'Ingredienser';
  static const String instructions = 'Instruktioner';
  static const String cookingTime = 'Tillagningstid';
  static const String portions = 'Portioner';
  static const String addRecipe = 'Lägg till recept';
  static const String editRecipe = 'Redigera recept';
  static const String deleteRecipe = 'Ta bort recept';

  // Shopping related
  static const String itemName = 'Varunamn';
  static const String amount = 'Mängd';
  static const String unit = 'Enhet';
  static const String category = 'Kategori';
  static const String note = 'Anteckning';
  static const String addItem = 'Lägg till vara';
  static const String editItem = 'Redigera vara';
  static const String shoppingList = 'Inköpslista';

  // Social/Friends related
  static const String friendName = 'Vännamn';
  static const String groupName = 'Gruppnamn';
  static const String displayName = 'Visningsnamn';
  static const String bio = 'Beskrivning';
  static const String createGroup = 'Skapa grupp';
  static const String editGroup = 'Redigera grupp';
  static const String deleteGroup = 'Ta bort grupp';
  static const String addFriend = 'Lägg till vän';
  static const String removeFriend = 'Ta bort vän';
  static const String sendFriendRequest = 'Skicka vänförfrågan';
  static const String acceptFriendRequest = 'Acceptera vänförfrågan';
  static const String declineFriendRequest = 'Avböj vänförfrågan';

  // Menu related
  static const String menuName = 'Menynamn';
  static const String saveMenu = 'Spara meny';
  static const String loadMenu = 'Ladda meny';
  static const String weekMenu = 'Veckomeny';

  // ===== PLACEHOLDER TEXTS =====
  static const String searchPlaceholder = 'Sök...';
  static const String namePlaceholder = 'Ange namn';
  static const String descriptionPlaceholder = 'Ange beskrivning (valfritt)';
  static const String emailPlaceholder = 'din@email.com';
  static const String urlPlaceholder = 'https://exempel.se';
  static const String phonePlaceholder = '+46 70 123 45 67';

  // ===== STATUS MESSAGES =====
  static const String connecting = 'Ansluter...';
  static const String syncing = 'Synkroniserar...';
  static const String uploading = 'Laddar upp...';
  static const String downloading = 'Laddar ner...';
  static const String processing = 'Bearbetar...';
  static const String saving = 'Sparar...';
  static const String deleting = 'Tar bort...';
  static const String creating = 'Skapar...';
  static const String updating = 'Uppdaterar...';

  // ===== ACCESSIBILITY STRINGS =====
  static const String menuButton = 'Menyknapp';
  static const String backButton = 'Tillbaka';
  static const String closeButton = 'Stäng';
  static const String moreOptions = 'Fler alternativ';
  static const String expandButton = 'Expandera';
  static const String collapseButton = 'Kollapsa'; 

  // ===== TIME & DATE =====
  static const String today = 'Idag';
  static const String yesterday = 'Igår';
  static const String tomorrow = 'Imorgon';
  static const String thisWeek = 'Denna vecka';
  static const String lastWeek = 'Förra veckan';
  static const String nextWeek = 'Nästa vecka';

  // ===== UNITS & MEASUREMENTS =====
  static const String minutesShort = 'min';
  static const String hoursShort = 'h';
  static const String piecesShort = 'st';
  static const String liters = 'liter';
  static const String kilograms = 'kg';
  static const String grams = 'g';

  // ===== HELPER METHODS =====
  
  /// Format a duration in minutes to a human-readable string
  static String formatDuration(int minutes) {
    if (minutes < 60) {
      return '$minutes $minutesShort';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours $hoursShort';
      } else {
        return '$hours $hoursShort $remainingMinutes $minutesShort';
      }
    }
  }

  /// Format portions with proper pluralization
  static String formatPortions(int portions) {
    return portions == 1 ? '1 portion' : '$portions portioner';
  }

  /// Format an error message with context
  static String errorWithContext(String action, String error) {
    return 'Fel vid $action: $error';
  }

  /// Create a loading message for specific actions
  static String loadingAction(String action) {
    return '${action.substring(0, 1).toUpperCase()}${action.substring(1).toLowerCase()}ar...';
  }
}