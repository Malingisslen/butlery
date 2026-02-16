/// Centralized string constants system for the Butlery cooking application.
///
/// MIGRATION NOTE: This class is being migrated to use Flutter's l10n system.
/// New code should use `context.l10n.stringKey` instead of `AppStrings.constant`.
/// The context-aware methods below delegate to l10n for gradual migration.

import 'package:flutter/material.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/core/l10n/app_locale.dart';

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
  @Deprecated(
      'Use context.l10n.commonRename or AppLocale.current.commonRename instead')
  static const String rename = 'Byt namn';
  @Deprecated(
      'Use context.l10n.commonExport or AppLocale.current.commonExport instead')
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
  @Deprecated(
      'Use context.l10n.commonWorking or AppLocale.current.commonWorking instead')
  static const String working = 'Arbetar...';

  // Shopping list actions
  @Deprecated(
      'Use context.l10n.shoppingRenameList or AppLocale.current.shoppingRenameList instead')
  static const String renameList = 'Byt namn på lista';
  @Deprecated(
      'Use context.l10n.shoppingCreateList or AppLocale.current.shoppingCreateList instead')
  static const String createList = 'Skapa ny inköpslista';
  @Deprecated(
      'Use context.l10n.shoppingNewName or AppLocale.current.shoppingNewName instead')
  static const String newName = 'Nytt namn';
  @Deprecated(
      'Use context.l10n.shoppingListName or AppLocale.current.shoppingListName instead')
  static const String listName = 'Namn på lista';
  @Deprecated(
      'Use context.l10n.shoppingAddToList or AppLocale.current.shoppingAddToList instead')
  static const String addToList = 'Lägg till i';

  // Authentication
  @Deprecated(
      'Use context.l10n.authResetPassword or AppLocale.current.authResetPassword instead')
  static const String resetPassword = 'Återställ lösenord';
  @Deprecated(
      'Use context.l10n.authForgotPassword or AppLocale.current.authForgotPassword instead')
  static const String forgotPassword = 'Glömt lösenord?';
  @Deprecated(
      'Use context.l10n.authEnterPassword or AppLocale.current.authEnterPassword instead')
  static const String enterPassword = 'Ange ditt lösenord';
  @Deprecated(
      'Use context.l10n.authPasswordMinLength or AppLocale.current.authPasswordMinLength instead')
  static const String passwordMinLength =
      'Minst 8 tecken, stor/liten bokstav och siffra';
  @Deprecated(
      'Use context.l10n.authResetPasswordInstructions or AppLocale.current.authResetPasswordInstructions instead')
  static const String resetPasswordInstructions =
      'Ange din email-adress så skickar vi instruktioner för att återställa ditt lösenord.';
  @Deprecated(
      'Use context.l10n.commonSend or AppStrings.sendL10n(context) instead')
  static const String send = 'Skicka';

  // App navigation
  @Deprecated(
      'Use context.l10n.navExitApp or AppLocale.current.navExitApp instead')
  static const String exitApp = 'Avsluta Butlery?';
  @Deprecated(
      'Use context.l10n.navExitAppConfirmation or AppLocale.current.navExitAppConfirmation instead')
  static const String exitAppConfirmation = 'Vill du verkligen avsluta appen?';
  @Deprecated('Use context.l10n.navExit or AppLocale.current.navExit instead')
  static const String exit = 'Avsluta';

  // Image picker
  @Deprecated(
      'Use context.l10n.imageAddImage or AppLocale.current.imageAddImage instead')
  static const String addImage = 'Lägg till bild';
  @Deprecated(
      'Use context.l10n.imageTakePhoto or AppLocale.current.imageTakePhoto instead')
  static const String takePhoto = 'Ta foto';
  @Deprecated(
      'Use context.l10n.imageUseCamera or AppLocale.current.imageUseCamera instead')
  static const String useCamera = 'Använd kameran';
  @Deprecated(
      'Use context.l10n.imageFromGallery or AppLocale.current.imageFromGallery instead')
  static const String fromGallery = 'Från galleriet';
  @Deprecated(
      'Use context.l10n.imageSelectFromGallery or AppLocale.current.imageSelectFromGallery instead')
  static const String selectFromGallery = 'Välj en bild från galleriet';
  static String selectUpToImages(int count) =>
      AppLocale.current.imageSelectUpTo(count);

  // Form validation messages
  static String fieldRequired(String fieldName) =>
      AppLocale.current.validationFieldRequired(fieldName);
  static String fieldTooShort(String fieldName, int minLength) =>
      AppLocale.current.validationFieldTooShort(fieldName, minLength);
  static String fieldTooLong(String fieldName, int maxLength) =>
      AppLocale.current.validationFieldTooLong(fieldName, maxLength);
  static String invalidFormat(String fieldName) =>
      AppLocale.current.validationInvalidFormat(fieldName);

  // Specific validation messages
  @Deprecated('Use context.l10n.validationNameRequired instead')
  static const String nameRequired = 'Namn krävs';
  @Deprecated('Use context.l10n.validationEmailRequired instead')
  static const String emailRequired = 'E-post krävs';
  @Deprecated(
      'Use context.l10n.validationPasswordRequired or AppLocale.current.validationPasswordRequired instead')
  static const String passwordRequired = 'Lösenord krävs';
  @Deprecated('Use context.l10n.validationEmailInvalid instead')
  static const String invalidEmail = 'Ogiltig e-postadress';
  @Deprecated(
      'Use context.l10n.validationInvalidUrl or AppLocale.current.validationInvalidUrl instead')
  static const String invalidUrl = 'Ogiltig URL';
  @Deprecated(
      'Use context.l10n.validationInvalidPhone or AppLocale.current.validationInvalidPhone instead')
  static const String invalidPhoneNumber = 'Ogiltigt telefonnummer';
  @Deprecated(
      'Use context.l10n.validationInvalidAmount or AppLocale.current.validationInvalidAmount instead')
  static const String invalidAmount = 'Ogiltigt antal';
  @Deprecated(
      'Use context.l10n.validationPasswordTooShort or AppLocale.current.validationPasswordTooShort instead')
  static const String passwordTooShort = 'Lösenordet måste vara minst 6 tecken';

  // Generic validation messages for ValidationUtils
  @Deprecated(
      'Use context.l10n.validationGenericRequired or AppLocale.current.validationGenericRequired instead')
  static const String genericRequired = 'Detta fält krävs';
  @Deprecated(
      'Use context.l10n.validationEmailInvalid or AppLocale.current.validationEmailInvalid instead')
  static const String emailInvalid = 'Ogiltig e-postadress';

  // Error messages
  @Deprecated('Use context.l10n.errorGeneric instead')
  static const String genericError = 'Ett fel uppstod. Försök igen.';
  @Deprecated('Use context.l10n.errorNetwork instead')
  static const String networkError =
      'Nätverksfel. Kontrollera din internetanslutning.';
  @Deprecated('Use context.l10n.errorServer instead')
  static const String serverError = 'Serverfel. Försök igen senare.';
  @Deprecated(
      'Use context.l10n.errorAuthentication or AppLocale.current.errorAuthentication instead')
  static const String authenticationError = 'Autentiseringsfel. Logga in igen.';
  @Deprecated(
      'Use context.l10n.errorPermissionDenied or AppLocale.current.errorPermissionDenied instead')
  static const String permissionDenied =
      'Du har inte behörighet för denna åtgärd.';
  @Deprecated(
      'Use context.l10n.errorNotFound or AppLocale.current.errorNotFound instead')
  static const String notFound = 'Kunde inte hittas.';
  @Deprecated(
      'Use context.l10n.errorAlreadyExists or AppLocale.current.errorAlreadyExists instead')
  static const String alreadyExists = 'Finns redan.';

  // Specific error contexts
  static String couldNotCreate(String itemType) =>
      AppLocale.current.errorCouldNotCreate(itemType);
  static String couldNotUpdate(String itemType) =>
      AppLocale.current.errorCouldNotUpdate(itemType);
  static String couldNotDelete(String itemType) =>
      AppLocale.current.errorCouldNotDelete(itemType);
  static String couldNotLoad(String itemType) =>
      AppLocale.current.errorCouldNotLoad(itemType);

  // Success messages
  static String itemCreated(String itemType) =>
      AppLocale.current.successItemCreated(itemType);
  static String itemUpdated(String itemType) =>
      AppLocale.current.successItemUpdated(itemType);
  static String itemDeleted(String itemType) =>
      AppLocale.current.successItemDeleted(itemType);
  static String itemAdded(String itemName) =>
      AppLocale.current.successItemAdded(itemName);

  // Confirmation messages
  static String confirmDelete(String itemName) =>
      AppLocale.current.confirmDeleteItem(itemName);
  @Deprecated(
      'Use context.l10n.confirmUnsavedChanges or AppLocale.current.confirmUnsavedChanges instead')
  static const String unsavedChanges =
      'Du har osparade ändringar. Vill du lämna utan att spara?';
  @Deprecated(
      'Use context.l10n.confirmIrreversibleAction or AppLocale.current.confirmIrreversibleAction instead')
  static const String irreversibleAction = 'Denna åtgärd kan inte ångras.';

  // Draft recovery messages
  @Deprecated(
      'Use context.l10n.draftRecovery or AppLocale.current.draftRecovery instead')
  static const String draftRecovery = 'Återställ utkast';
  @Deprecated(
      'Use context.l10n.draftRecoverySubtitle or AppLocale.current.draftRecoverySubtitle instead')
  static const String draftRecoverySubtitle =
      'Du har osparade receptutkast. Vill du fortsätta där du slutade?';
  @Deprecated('Use AppLocale.current.restoreDraft instead')
  static const String restoreDraft = 'Återställ';
  @Deprecated('Use AppLocale.current.startFresh instead')
  static const String startFresh = 'Börja om';
  @Deprecated(
      'Use context.l10n.draftRestored or AppLocale.current.draftRestored instead')
  static const String draftRestored = 'Utkast återställt!';
  @Deprecated(
      'Use context.l10n.draftRestoredDetails or AppLocale.current.draftRestoredDetails instead')
  static const String draftRestoredDetails = 'fält laddades';
  @Deprecated('Use AppLocale.current.couldNotRestoreDraft instead')
  static const String couldNotRestoreDraft =
      'Kunde inte återställa utkast. Börjar med tomt formulär.';
  @Deprecated('Use AppLocale.current.restoringDraft instead')
  static const String restoringDraft = 'Återställer utkast...';
  @Deprecated('Use AppLocale.current.unnamedRecipe instead')
  static const String unnamedRecipe = 'Namnlöst recept';
  static String fieldsFilledCount(int count) =>
      AppLocale.current.fieldsFilledCount(count);
  static String draftRestoredWithCount(int count) =>
      AppLocale.current.draftRestoredWithCount(count);

  // Enhanced contextual error messages
  static String networkAwareError({
    required String baseOperation,
    required String connectivityType,
    bool includeRecoveryAction = true,
  }) {
    switch (connectivityType.toLowerCase()) {
      case 'none':
        return includeRecoveryAction
            ? AppLocale.current.networkErrorNoConnection(baseOperation)
            : AppLocale.current.networkErrorNoConnectionShort(baseOperation);

      case 'mobile':
        return includeRecoveryAction
            ? AppLocale.current.networkErrorMobileData(baseOperation)
            : AppLocale.current.networkErrorMobileShort(baseOperation);

      case 'limited':
        return includeRecoveryAction
            ? AppLocale.current.networkErrorLimited(baseOperation)
            : AppLocale.current.networkErrorLimitedShort(baseOperation);

      default:
        return AppLocale.current.networkErrorDefault(baseOperation);
    }
  }

  // Permission-aware error messages
  static String permissionContextualError({
    required String resource,
    required String action,
    String? reason,
    String? suggestedAction,
  }) {
    final baseMessage =
        AppLocale.current.permissionErrorAction(action, resource);
    final reasonText = reason != null
        ? ' ${AppLocale.current.permissionErrorBecause(reason)}'
        : '';
    final actionText = suggestedAction != null
        ? '\n\n${AppLocale.current.permissionErrorSuggestion(suggestedAction)}'
        : '';
    return '$baseMessage$reasonText.$actionText';
  }

  // Action-specific error contexts
  static String actionSpecificError(String action, String issue) =>
      AppLocale.current.errorDuringAction(action, issue);
  static String actionWithRecovery(
          String action, String issue, String recovery) =>
      AppLocale.current.errorDuringActionRecovery(action, issue, recovery);

  // Progressive error disclosure
  @Deprecated('Use AppLocale.current.showTechnicalDetails instead')
  static const String showTechnicalDetails = 'Visa tekniska detaljer';
  @Deprecated('Use AppLocale.current.hideTechnicalDetails instead')
  static const String hideTechnicalDetails = 'Dölj tekniska detaljer';
  @Deprecated(
      'Use context.l10n.technicalInformation or AppLocale.current.technicalInformation instead')
  static const String technicalInformation = 'Teknisk information';
  @Deprecated('Use AppLocale.current.contactSupport instead')
  static const String contactSupport = 'Kontakta support';
  @Deprecated('Use AppLocale.current.tryAgainLater instead')
  static const String tryAgainLater = 'Försök igen senare';

  // Connectivity-specific messages
  @Deprecated('Use AppLocale.current.offlineMode instead')
  static const String offlineMode = 'Offline-läge aktiverat';
  @Deprecated(
      'Use context.l10n.connectivityRestored or AppLocale.current.connectivityRestored instead')
  static const String connectivityRestored = 'Anslutning återställd';
  @Deprecated('Use AppLocale.current.syncingPendingChanges instead')
  static const String syncingPendingChanges =
      'Synkroniserar väntande ändringar...';
  @Deprecated('Use AppLocale.current.localChangesSaved instead')
  static const String localChangesSaved = 'Ändringar sparade lokalt';
  @Deprecated('Use AppLocale.current.willSyncWhenOnline instead')
  static const String willSyncWhenOnline =
      'Synkroniseras när du är online igen';

  // Permission-specific messages
  @Deprecated('Use AppLocale.current.insufficientPermissions instead')
  static const String insufficientPermissions = 'Otillräckliga behörigheter';
  @Deprecated('Use AppLocale.current.readOnlyAccess instead')
  static const String readOnlyAccess = 'Endast läsrättigheter';
  @Deprecated('Use AppLocale.current.ownerOnlyAction instead')
  static const String ownerOnlyAction = 'Endast ägaren kan utföra denna åtgärd';
  @Deprecated('Use AppLocale.current.requestEditAccess instead')
  static const String requestEditAccess = 'Be om redigeringsrättigheter';
  @Deprecated('Use AppLocale.current.makePersonalCopy instead')
  static const String makePersonalCopy = 'Skapa personlig kopia';

  // Recovery action suggestions
  @Deprecated('Use AppLocale.current.checkConnection instead')
  static const String checkConnection = 'Kontrollera internetanslutningen';
  @Deprecated('Use context.l10n.commonRetry instead')
  static const String tryAgain = 'Försök igen';
  @Deprecated('Use AppLocale.current.loginAgain instead')
  static const String loginAgain = 'Logga in på nytt';
  @Deprecated('Use AppLocale.current.contactOwner instead')
  static const String contactOwner = 'Kontakta ägaren';
  @Deprecated('Use AppLocale.current.waitAndRetry instead')
  static const String waitAndRetry = 'Vänta och försök igen';
  @Deprecated('Use AppLocale.current.checkPermissions instead')
  static const String checkPermissions = 'Kontrollera behörigheter';

  // Empty states
  @Deprecated('Use AppLocale.current.noItemsFound instead')
  static const String noItemsFound = 'Inga objekt hittades.';
  @Deprecated(
      'Use context.l10n.emptyList or AppLocale.current.emptyList instead')
  static const String emptyList = 'Listan är tom.';
  @Deprecated('Use AppLocale.current.noResults instead')
  static const String noResults = 'Inga resultat hittades.';
  @Deprecated('Use AppLocale.current.noFriends instead')
  static const String noFriends = 'Du har inga vänner än.';
  @Deprecated('Use AppLocale.current.noRecipes instead')
  static const String noRecipes = 'Du har inga recept än.';
  @Deprecated('Use AppLocale.current.noShoppingLists instead')
  static const String noShoppingLists = 'Du har inga inköpslistor än.';

  // Feature-specific strings

  // Recipe related
  @Deprecated(
      'Use context.l10n.recipeName or AppLocale.current.recipeName instead')
  static const String recipeName = 'Receptnamn';
  @Deprecated(
      'Use context.l10n.recipeDescription or AppLocale.current.recipeDescription instead')
  static const String recipeDescription = 'Beskrivning';
  @Deprecated(
      'Use context.l10n.recipeIngredients or AppLocale.current.recipeIngredients instead')
  static const String ingredients = 'Ingredienser';
  @Deprecated(
      'Use context.l10n.recipeInstructions or AppLocale.current.recipeInstructions instead')
  static const String instructions = 'Instruktioner';
  @Deprecated(
      'Use context.l10n.recipeCookingTime or AppLocale.current.recipeCookingTime instead')
  static const String cookingTime = 'Tillagningstid';
  @Deprecated(
      'Use context.l10n.recipePortions or AppLocale.current.recipePortions instead')
  static const String portions = 'Portioner';
  @Deprecated('Use AppLocale.current.addRecipe instead')
  static const String addRecipe = 'Lägg till recept';
  @Deprecated('Use AppLocale.current.editRecipe instead')
  static const String editRecipe = 'Redigera recept';
  @Deprecated('Use AppLocale.current.deleteRecipeAction instead')
  static const String deleteRecipe = 'Ta bort recept';

  // Shopping related
  @Deprecated(
      'Use context.l10n.shoppingItemName or AppLocale.current.shoppingItemName instead')
  static const String itemName = 'Varunamn';
  @Deprecated(
      'Use context.l10n.shoppingAmount or AppLocale.current.shoppingAmount instead')
  static const String amount = 'Mängd';
  @Deprecated(
      'Use context.l10n.shoppingUnit or AppLocale.current.shoppingUnit instead')
  static const String unit = 'Enhet';
  @Deprecated(
      'Use context.l10n.shoppingCategory or AppLocale.current.shoppingCategory instead')
  static const String category = 'Kategori';
  @Deprecated(
      'Use context.l10n.shoppingNote or AppLocale.current.shoppingNote instead')
  static const String note = 'Anteckning';
  @Deprecated(
      'Use context.l10n.shoppingAddItem or AppLocale.current.shoppingAddItem instead')
  static const String addItem = 'Lägg till vara';
  @Deprecated(
      'Use context.l10n.shoppingEditItem or AppLocale.current.shoppingEditItem instead')
  static const String editItem = 'Redigera vara';
  @Deprecated(
      'Use context.l10n.shoppingList or AppLocale.current.shoppingList instead')
  static const String shoppingList = 'Inköpslista';

  // Social/Friends related
  @Deprecated(
      'Use context.l10n.socialFriendName or AppLocale.current.socialFriendName instead')
  static const String friendName = 'Vännamn';
  @Deprecated(
      'Use context.l10n.socialGroupName or AppLocale.current.socialGroupName instead')
  static const String groupName = 'Gruppnamn';
  @Deprecated(
      'Use context.l10n.socialDisplayName or AppLocale.current.socialDisplayName instead')
  static const String displayName = 'Visningsnamn';
  @Deprecated(
      'Use context.l10n.socialCreateGroup or AppLocale.current.socialCreateGroup instead')
  static const String createGroup = 'Skapa grupp';
  @Deprecated(
      'Use context.l10n.socialEditGroup or AppLocale.current.socialEditGroup instead')
  static const String editGroup = 'Redigera grupp';
  @Deprecated(
      'Use context.l10n.socialDeleteGroup or AppLocale.current.socialDeleteGroup instead')
  static const String deleteGroup = 'Ta bort grupp';
  @Deprecated(
      'Use context.l10n.socialAddFriend or AppLocale.current.socialAddFriend instead')
  static const String addFriend = 'Lägg till vän';
  @Deprecated(
      'Use context.l10n.socialRemoveFriend or AppLocale.current.socialRemoveFriend instead')
  static const String removeFriend = 'Ta bort vän';
  @Deprecated(
      'Use context.l10n.socialSendFriendRequest or AppLocale.current.socialSendFriendRequest instead')
  static const String sendFriendRequest = 'Skicka vänförfrågan';
  @Deprecated(
      'Use context.l10n.socialAcceptFriendRequest or AppLocale.current.socialAcceptFriendRequest instead')
  static const String acceptFriendRequest = 'Acceptera vänförfrågan';
  @Deprecated(
      'Use context.l10n.socialDeclineFriendRequest or AppLocale.current.socialDeclineFriendRequest instead')
  static const String declineFriendRequest = 'Avböj vänförfrågan';

  // Menu related
  @Deprecated('Use context.l10n.menuName or AppLocale.current.menuName instead')
  static const String menuName = 'Menynamn';
  @Deprecated('Use context.l10n.menuSave or AppLocale.current.menuSave instead')
  static const String saveMenu = 'Spara meny';
  @Deprecated('Use context.l10n.menuLoad or AppLocale.current.menuLoad instead')
  static const String loadMenu = 'Ladda meny';
  @Deprecated('Use context.l10n.menuWeek or AppLocale.current.menuWeek instead')
  static const String weekMenu = 'Veckomeny';

  // Placeholder texts
  @Deprecated('Use AppLocale.current.searchPlaceholder instead')
  static const String searchPlaceholder = 'Sök...';
  @Deprecated('Use AppLocale.current.namePlaceholder instead')
  static const String namePlaceholder = 'Ange namn';
  @Deprecated('Use AppLocale.current.descriptionPlaceholder instead')
  static const String descriptionPlaceholder = 'Ange beskrivning (valfritt)';
  @Deprecated('Use AppLocale.current.emailPlaceholder instead')
  static const String emailPlaceholder = 'din@email.com';
  @Deprecated('Use AppLocale.current.urlPlaceholder instead')
  static const String urlPlaceholder = 'https://exempel.se';
  @Deprecated('Use AppLocale.current.phonePlaceholder instead')
  static const String phonePlaceholder = '+46 70 123 45 67';

  // Status messages
  @Deprecated(
      'Use context.l10n.statusConnecting or AppLocale.current.statusConnecting instead')
  static const String connecting = 'Ansluter...';
  @Deprecated(
      'Use context.l10n.statusSyncing or AppLocale.current.statusSyncing instead')
  static const String syncing = 'Synkroniserar...';
  @Deprecated(
      'Use context.l10n.statusUploading or AppLocale.current.statusUploading instead')
  static const String uploading = 'Laddar upp...';
  @Deprecated(
      'Use context.l10n.statusDownloading or AppLocale.current.statusDownloading instead')
  static const String downloading = 'Laddar ner...';
  @Deprecated(
      'Use context.l10n.statusProcessing or AppLocale.current.statusProcessing instead')
  static const String processing = 'Bearbetar...';
  @Deprecated(
      'Use context.l10n.statusSaving or AppLocale.current.statusSaving instead')
  static const String saving = 'Sparar...';
  @Deprecated(
      'Use context.l10n.statusDeleting or AppLocale.current.statusDeleting instead')
  static const String deleting = 'Tar bort...';
  @Deprecated(
      'Use context.l10n.statusCreating or AppLocale.current.statusCreating instead')
  static const String creating = 'Skapar...';
  @Deprecated(
      'Use context.l10n.statusUpdating or AppLocale.current.statusUpdating instead')
  static const String updating = 'Uppdaterar...';

  // Accessibility strings
  @Deprecated('Use AppLocale.current.accessibilityMenuButton instead')
  static const String menuButton = 'Menyknapp';
  @Deprecated('Use AppLocale.current.accessibilityBackButton instead')
  static const String backButton = 'Tillbaka';
  @Deprecated('Use AppLocale.current.accessibilityCloseButton instead')
  static const String closeButton = 'Stäng';
  @Deprecated('Use AppLocale.current.accessibilityMoreOptions instead')
  static const String moreOptions = 'Fler alternativ';
  @Deprecated('Use AppLocale.current.accessibilityExpandButton instead')
  static const String expandButton = 'Expandera';
  @Deprecated('Use AppLocale.current.accessibilityCollapseButton instead')
  static const String collapseButton = 'Kollapsa';

  // Time & date
  @Deprecated(
      'Use context.l10n.timeToday or AppLocale.current.timeToday instead')
  static const String today = 'Idag';
  @Deprecated(
      'Use context.l10n.timeYesterday or AppLocale.current.timeYesterday instead')
  static const String yesterday = 'Igår';
  @Deprecated(
      'Use context.l10n.timeTomorrow or AppLocale.current.timeTomorrow instead')
  static const String tomorrow = 'Imorgon';
  @Deprecated(
      'Use context.l10n.timeThisWeek or AppLocale.current.timeThisWeek instead')
  static const String thisWeek = 'Denna vecka';
  @Deprecated(
      'Use context.l10n.timeLastWeek or AppLocale.current.timeLastWeek instead')
  static const String lastWeek = 'Förra veckan';
  @Deprecated(
      'Use context.l10n.timeNextWeek or AppLocale.current.timeNextWeek instead')
  static const String nextWeek = 'Nästa vecka';

  // Units & measurements
  @Deprecated(
      'Use context.l10n.unitMinutesShort or AppLocale.current.unitMinutesShort instead')
  static const String minutesShort = 'min';
  @Deprecated(
      'Use context.l10n.unitHoursShort or AppLocale.current.unitHoursShort instead')
  static const String hoursShort = 'h';
  @Deprecated(
      'Use context.l10n.unitPiecesShort or AppLocale.current.unitPiecesShort instead')
  static const String piecesShort = 'st';
  @Deprecated(
      'Use context.l10n.unitLiters or AppLocale.current.unitLiters instead')
  static const String liters = 'liter';
  @Deprecated(
      'Use context.l10n.unitKilograms or AppLocale.current.unitKilograms instead')
  static const String kilograms = 'kg';
  @Deprecated(
      'Use context.l10n.unitGrams or AppLocale.current.unitGrams instead')
  static const String grams = 'g';

  // Helper methods

  /// Format a duration in minutes to a human-readable string
  static String formatDuration(int minutes) {
    final min = AppLocale.current.unitMinutesShort;
    final h = AppLocale.current.unitHoursShort;
    if (minutes < 60) {
      return '$minutes $min';
    } else {
      final hours = minutes ~/ 60;
      final remainingMinutes = minutes % 60;
      if (remainingMinutes == 0) {
        return '$hours $h';
      } else {
        return '$hours $h $remainingMinutes $min';
      }
    }
  }

  /// Format portions with proper pluralization
  static String formatPortions(int portions) {
    return portions == 1
        ? AppLocale.current.formatPortionSingle
        : AppLocale.current.formatPortionPlural(portions);
  }

  /// Format an error message with context
  static String errorWithContext(String action, String error) {
    return AppLocale.current.errorWithContext(action, error);
  }

  /// Create a loading message for specific actions.
  // NOTE(l10n): This is the ONE method that can't be cleanly l10n'd due to
  // Swedish verb conjugation ("${action}ar..."). Each locale would need its own
  // conjugation logic. Keep as-is until a proper loadingAction(action) l10n key
  // with per-locale formatting is implemented.
  static String loadingAction(String action) {
    return '${action.substring(0, 1).toUpperCase()}${action.substring(1).toLowerCase()}ar...';
  }
}
