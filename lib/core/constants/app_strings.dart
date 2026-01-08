/// Centralized string constants system for the Butlery cooking application.
///
/// MIGRATION NOTE: This class is being migrated to use Flutter's l10n system.
/// New code should use `context.l10n.stringKey` instead of `AppStrings.constant`.
/// The context-aware methods below delegate to l10n for gradual migration.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';

/// Central repository for all user-facing text in the Butlery application.
///
/// ## Migration to l10n
/// This class now supports two access patterns:
/// 1. **Legacy (deprecated)**: `AppStrings.save` - static constants
/// 2. **New (preferred)**: `AppStrings.save(context)` - context-aware methods using l10n
///
/// New code should prefer `context.l10n.stringKey` directly.
class AppStrings {
  /// Private constructor
  AppStrings._();

  // ==========================================================================
  // CONTEXT-AWARE METHODS (preferred - delegate to l10n)
  // ==========================================================================

  // Common actions - context-aware
  static String saveL10n(BuildContext context) => context.l10n.commonSave;
  static String cancelL10n(BuildContext context) => context.l10n.commonCancel;
  static String deleteL10n(BuildContext context) => context.l10n.commonDelete;
  static String editL10n(BuildContext context) => context.l10n.commonEdit;
  static String addL10n(BuildContext context) => context.l10n.commonAdd;
  static String createL10n(BuildContext context) => context.l10n.commonCreate;
  static String updateL10n(BuildContext context) => context.l10n.commonUpdate;
  static String closeL10n(BuildContext context) => context.l10n.commonClose;
  static String shareL10n(BuildContext context) => context.l10n.commonShare;
  static String okL10n(BuildContext context) => context.l10n.commonOk;
  static String yesL10n(BuildContext context) => context.l10n.commonYes;
  static String noL10n(BuildContext context) => context.l10n.commonNo;
  static String retryL10n(BuildContext context) => context.l10n.commonRetry;
  static String loadingL10n(BuildContext context) => context.l10n.commonLoading;
  static String sendL10n(BuildContext context) => context.l10n.commonSend;

  // Error messages - context-aware
  static String genericErrorL10n(BuildContext context) =>
      context.l10n.errorGeneric;
  static String networkErrorL10n(BuildContext context) =>
      context.l10n.errorNetwork;
  static String serverErrorL10n(BuildContext context) =>
      context.l10n.errorServer;

  // Validation - context-aware
  static String nameRequiredL10n(BuildContext context) =>
      context.l10n.validationNameRequired;
  static String emailRequiredL10n(BuildContext context) =>
      context.l10n.validationEmailRequired;
  static String invalidEmailL10n(BuildContext context) =>
      context.l10n.validationEmailInvalid;

  // ==========================================================================
  // LEGACY CONSTANTS (deprecated - migrate to l10n)
  // ==========================================================================

  // Common actions
  @Deprecated(
      'Use context.l10n.commonSave or AppStrings.saveL10n(context) instead')
  static const String save = 'Spara';
  @Deprecated(
      'Use context.l10n.commonCancel or AppStrings.cancelL10n(context) instead')
  static const String cancel = 'Avbryt';
  @Deprecated(
      'Use context.l10n.commonDelete or AppStrings.deleteL10n(context) instead')
  static const String delete = 'Ta bort';
  @Deprecated(
      'Use context.l10n.commonEdit or AppStrings.editL10n(context) instead')
  static const String edit = 'Redigera';
  @Deprecated(
      'Use context.l10n.commonAdd or AppStrings.addL10n(context) instead')
  static const String add = 'Lägg till';
  @Deprecated(
      'Use context.l10n.commonCreate or AppStrings.createL10n(context) instead')
  static const String create = 'Skapa';
  @Deprecated(
      'Use context.l10n.commonUpdate or AppStrings.updateL10n(context) instead')
  static const String update = 'Uppdatera';
  @Deprecated(
      'Use context.l10n.commonClose or AppStrings.closeL10n(context) instead')
  static const String close = 'Stäng';
  @Deprecated(
      'Use context.l10n.commonShare or AppStrings.shareL10n(context) instead')
  static const String share = 'Dela';
  static const String rename = 'Byt namn';
  static const String export = 'Exportera';
  @Deprecated('Use context.l10n.commonOk or AppStrings.okL10n(context) instead')
  static const String ok = 'OK';
  @Deprecated(
      'Use context.l10n.commonYes or AppStrings.yesL10n(context) instead')
  static const String yes = 'Ja';
  @Deprecated('Use context.l10n.commonNo or AppStrings.noL10n(context) instead')
  static const String no = 'Nej';
  @Deprecated(
      'Use context.l10n.commonRetry or AppStrings.retryL10n(context) instead')
  static const String retry = 'Försök igen';
  @Deprecated(
      'Use context.l10n.commonLoading or AppStrings.loadingL10n(context) instead')
  static const String loading = 'Laddar...';
  static const String working = 'Arbetar...';

  // Shopping list actions
  static const String renameList = 'Byt namn på lista';
  static const String createList = 'Skapa ny inköpslista';
  static const String newName = 'Nytt namn';
  static const String listName = 'Namn på lista';
  static const String addToList = 'Lägg till i';

  // Authentication
  static const String resetPassword = 'Återställ lösenord';
  static const String forgotPassword = 'Glömt lösenord?';
  static const String enterPassword = 'Ange ditt lösenord';
  static const String passwordMinLength =
      'Minst 8 tecken, stor/liten bokstav och siffra';
  static const String resetPasswordInstructions =
      'Ange din email-adress så skickar vi instruktioner för att återställa ditt lösenord.';
  @Deprecated(
      'Use context.l10n.commonSend or AppStrings.sendL10n(context) instead')
  static const String send = 'Skicka';

  // App navigation
  static const String exitApp = 'Avsluta Butlery?';
  static const String exitAppConfirmation = 'Vill du verkligen avsluta appen?';
  static const String exit = 'Avsluta';

  // Image picker
  static const String addImage = 'Lägg till bild';
  static const String takePhoto = 'Ta foto';
  static const String useCamera = 'Använd kameran';
  static const String fromGallery = 'Från galleriet';
  static const String selectFromGallery = 'Välj en bild från galleriet';
  static String selectUpToImages(int count) => 'Välj upp till $count bilder';

  // Form validation messages
  static String fieldRequired(String fieldName) => '$fieldName krävs';
  static String fieldTooShort(String fieldName, int minLength) =>
      '$fieldName måste vara minst $minLength tecken';
  static String fieldTooLong(String fieldName, int maxLength) =>
      '$fieldName får vara max $maxLength tecken';
  static String invalidFormat(String fieldName) =>
      'Ogiltigt format för $fieldName';

  // Specific validation messages
  @Deprecated('Use context.l10n.validationNameRequired instead')
  static const String nameRequired = 'Namn krävs';
  @Deprecated('Use context.l10n.validationEmailRequired instead')
  static const String emailRequired = 'E-post krävs';
  static const String passwordRequired = 'Lösenord krävs';
  @Deprecated('Use context.l10n.validationEmailInvalid instead')
  static const String invalidEmail = 'Ogiltig e-postadress';
  static const String invalidUrl = 'Ogiltig URL';
  static const String invalidPhoneNumber = 'Ogiltigt telefonnummer';
  static const String invalidAmount = 'Ogiltigt antal';
  static const String passwordTooShort = 'Lösenordet måste vara minst 6 tecken';

  // Generic validation messages for ValidationUtils
  static const String genericRequired = 'Detta fält krävs';
  static const String emailInvalid = 'Ogiltig e-postadress';

  // Error messages
  @Deprecated('Use context.l10n.errorGeneric instead')
  static const String genericError = 'Ett fel uppstod. Försök igen.';
  @Deprecated('Use context.l10n.errorNetwork instead')
  static const String networkError =
      'Nätverksfel. Kontrollera din internetanslutning.';
  @Deprecated('Use context.l10n.errorServer instead')
  static const String serverError = 'Serverfel. Försök igen senare.';
  static const String authenticationError = 'Autentiseringsfel. Logga in igen.';
  static const String permissionDenied =
      'Du har inte behörighet för denna åtgärd.';
  static const String notFound = 'Kunde inte hittas.';
  static const String alreadyExists = 'Finns redan.';

  // Specific error contexts
  static String couldNotCreate(String itemType) =>
      'Kunde inte skapa $itemType. Försök igen.';
  static String couldNotUpdate(String itemType) =>
      'Kunde inte uppdatera $itemType. Försök igen.';
  static String couldNotDelete(String itemType) =>
      'Kunde inte ta bort $itemType. Försök igen.';
  static String couldNotLoad(String itemType) =>
      'Kunde inte ladda $itemType. Försök igen.';

  // Success messages
  static String itemCreated(String itemType) => '$itemType skapades!';
  static String itemUpdated(String itemType) => '$itemType uppdaterades!';
  static String itemDeleted(String itemType) => '$itemType togs bort!';
  static String itemAdded(String itemName) => '$itemName tillagd!';

  // Confirmation messages
  static String confirmDelete(String itemName) =>
      'Är du säker på att du vill ta bort "$itemName"?';
  static const String unsavedChanges =
      'Du har osparade ändringar. Vill du lämna utan att spara?';
  static const String irreversibleAction = 'Denna åtgärd kan inte ångras.';

  // Draft recovery messages
  static const String draftRecovery = 'Återställ utkast';
  static const String draftRecoverySubtitle =
      'Du har osparade receptutkast. Vill du fortsätta där du slutade?';
  static const String restoreDraft = 'Återställ';
  static const String startFresh = 'Börja om';
  static const String draftRestored = 'Utkast återställt!';
  static const String draftRestoredDetails = 'fält laddades';
  static const String couldNotRestoreDraft =
      'Kunde inte återställa utkast. Börjar med tomt formulär.';
  static const String restoringDraft = 'Återställer utkast...';
  static const String unnamedRecipe = 'Namnlöst recept';
  static String fieldsFilledCount(int count) => '$count fält ifyllda';
  static String draftRestoredWithCount(int count) =>
      'Utkast återställt! $count $draftRestoredDetails';

  // Enhanced contextual error messages
  static String networkAwareError({
    required String baseOperation,
    required String connectivityType,
    bool includeRecoveryAction = true,
  }) {
    switch (connectivityType.toLowerCase()) {
      case 'none':
        return includeRecoveryAction
            ? 'Ingen internetanslutning. $baseOperation kommer att sparas lokalt och synkroniseras när du är online igen.'
            : 'Ingen internetanslutning för $baseOperation.';

      case 'mobile':
        return includeRecoveryAction
            ? 'Använder mobildata för $baseOperation. Detta kan ta längre tid eller påverka din dataförbrukning.'
            : 'Mobilanslutning för $baseOperation.';

      case 'limited':
        return includeRecoveryAction
            ? 'Begränsad anslutning upptäckt. $baseOperation kan ta längre tid eller sparas lokalt.'
            : 'Begränsad anslutning för $baseOperation.';

      default:
        return 'Nätverksfel under $baseOperation. Kontrollera din anslutning och försök igen.';
    }
  }

  // Permission-aware error messages
  static String permissionContextualError({
    required String resource,
    required String action,
    String? reason,
    String? suggestedAction,
  }) {
    final baseMessage = 'Du kan inte $action detta $resource';
    final reasonText = reason != null ? ' eftersom $reason' : '';
    final actionText =
        suggestedAction != null ? '\n\nFörslag: $suggestedAction' : '';
    return '$baseMessage$reasonText.$actionText';
  }

  // Action-specific error contexts
  static String actionSpecificError(String action, String issue) =>
      'Problem medan $action: $issue';
  static String actionWithRecovery(
          String action, String issue, String recovery) =>
      'Problem medan $action: $issue\n\nFörslag: $recovery';

  // Progressive error disclosure
  static const String showTechnicalDetails = 'Visa tekniska detaljer';
  static const String hideTechnicalDetails = 'Dölj tekniska detaljer';
  static const String technicalInformation = 'Teknisk information';
  static const String contactSupport = 'Kontakta support';
  static const String tryAgainLater = 'Försök igen senare';

  // Connectivity-specific messages
  static const String offlineMode = 'Offline-läge aktiverat';
  static const String connectivityRestored = 'Anslutning återställd';
  static const String syncingPendingChanges =
      'Synkroniserar väntande ändringar...';
  static const String localChangesSaved = 'Ändringar sparade lokalt';
  static const String willSyncWhenOnline =
      'Synkroniseras när du är online igen';

  // Permission-specific messages
  static const String insufficientPermissions = 'Otillräckliga behörigheter';
  static const String readOnlyAccess = 'Endast läsrättigheter';
  static const String ownerOnlyAction = 'Endast ägaren kan utföra denna åtgärd';
  static const String requestEditAccess = 'Be om redigeringsrättigheter';
  static const String makePersonalCopy = 'Skapa personlig kopia';

  // Recovery action suggestions
  static const String checkConnection = 'Kontrollera internetanslutningen';
  static const String tryAgain = 'Försök igen';
  static const String loginAgain = 'Logga in på nytt';
  static const String contactOwner = 'Kontakta ägaren';
  static const String waitAndRetry = 'Vänta och försök igen';
  static const String checkPermissions = 'Kontrollera behörigheter';

  // Empty states
  static const String noItemsFound = 'Inga objekt hittades.';
  static const String emptyList = 'Listan är tom.';
  static const String noResults = 'Inga resultat hittades.';
  static const String noFriends = 'Du har inga vänner än.';
  static const String noRecipes = 'Du har inga recept än.';
  static const String noShoppingLists = 'Du har inga inköpslistor än.';

  // Feature-specific strings

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

  // Placeholder texts
  static const String searchPlaceholder = 'Sök...';
  static const String namePlaceholder = 'Ange namn';
  static const String descriptionPlaceholder = 'Ange beskrivning (valfritt)';
  static const String emailPlaceholder = 'din@email.com';
  static const String urlPlaceholder = 'https://exempel.se';
  static const String phonePlaceholder = '+46 70 123 45 67';

  // Status messages
  static const String connecting = 'Ansluter...';
  static const String syncing = 'Synkroniserar...';
  static const String uploading = 'Laddar upp...';
  static const String downloading = 'Laddar ner...';
  static const String processing = 'Bearbetar...';
  static const String saving = 'Sparar...';
  static const String deleting = 'Tar bort...';
  static const String creating = 'Skapar...';
  static const String updating = 'Uppdaterar...';

  // Accessibility strings
  static const String menuButton = 'Menyknapp';
  static const String backButton = 'Tillbaka';
  static const String closeButton = 'Stäng';
  static const String moreOptions = 'Fler alternativ';
  static const String expandButton = 'Expandera';
  static const String collapseButton = 'Kollapsa';

  // Time & date
  static const String today = 'Idag';
  static const String yesterday = 'Igår';
  static const String tomorrow = 'Imorgon';
  static const String thisWeek = 'Denna vecka';
  static const String lastWeek = 'Förra veckan';
  static const String nextWeek = 'Nästa vecka';

  // Units & measurements
  static const String minutesShort = 'min';
  static const String hoursShort = 'h';
  static const String piecesShort = 'st';
  static const String liters = 'liter';
  static const String kilograms = 'kg';
  static const String grams = 'g';

  // Helper methods

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
