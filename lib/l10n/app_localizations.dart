import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_en.dart';
import 'app_localizations_sv.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('sv')
  ];

  /// No description provided for @commonSave.
  ///
  /// In sv, this message translates to:
  /// **'Spara'**
  String get commonSave;

  /// No description provided for @commonCancel.
  ///
  /// In sv, this message translates to:
  /// **'Avbryt'**
  String get commonCancel;

  /// No description provided for @commonDelete.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort'**
  String get commonDelete;

  /// No description provided for @commonEdit.
  ///
  /// In sv, this message translates to:
  /// **'Redigera'**
  String get commonEdit;

  /// No description provided for @commonAdd.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till'**
  String get commonAdd;

  /// No description provided for @commonCreate.
  ///
  /// In sv, this message translates to:
  /// **'Skapa'**
  String get commonCreate;

  /// No description provided for @commonUpdate.
  ///
  /// In sv, this message translates to:
  /// **'Uppdatera'**
  String get commonUpdate;

  /// No description provided for @commonClose.
  ///
  /// In sv, this message translates to:
  /// **'Stäng'**
  String get commonClose;

  /// No description provided for @commonShare.
  ///
  /// In sv, this message translates to:
  /// **'Dela'**
  String get commonShare;

  /// No description provided for @commonRename.
  ///
  /// In sv, this message translates to:
  /// **'Byt namn'**
  String get commonRename;

  /// No description provided for @commonExport.
  ///
  /// In sv, this message translates to:
  /// **'Exportera'**
  String get commonExport;

  /// No description provided for @commonOk.
  ///
  /// In sv, this message translates to:
  /// **'OK'**
  String get commonOk;

  /// No description provided for @commonYes.
  ///
  /// In sv, this message translates to:
  /// **'Ja'**
  String get commonYes;

  /// No description provided for @commonNo.
  ///
  /// In sv, this message translates to:
  /// **'Nej'**
  String get commonNo;

  /// No description provided for @commonRetry.
  ///
  /// In sv, this message translates to:
  /// **'Försök igen'**
  String get commonRetry;

  /// No description provided for @commonLoading.
  ///
  /// In sv, this message translates to:
  /// **'Laddar...'**
  String get commonLoading;

  /// No description provided for @commonWorking.
  ///
  /// In sv, this message translates to:
  /// **'Arbetar...'**
  String get commonWorking;

  /// No description provided for @commonDeleting.
  ///
  /// In sv, this message translates to:
  /// **'Tar bort...'**
  String get commonDeleting;

  /// No description provided for @commonYou.
  ///
  /// In sv, this message translates to:
  /// **'Du'**
  String get commonYou;

  /// No description provided for @commonSend.
  ///
  /// In sv, this message translates to:
  /// **'Skicka'**
  String get commonSend;

  /// No description provided for @shoppingRenameList.
  ///
  /// In sv, this message translates to:
  /// **'Byt namn på lista'**
  String get shoppingRenameList;

  /// No description provided for @shoppingCreateList.
  ///
  /// In sv, this message translates to:
  /// **'Skapa ny inköpslista'**
  String get shoppingCreateList;

  /// No description provided for @shoppingNewName.
  ///
  /// In sv, this message translates to:
  /// **'Nytt namn'**
  String get shoppingNewName;

  /// No description provided for @shoppingListName.
  ///
  /// In sv, this message translates to:
  /// **'Namn på lista'**
  String get shoppingListName;

  /// No description provided for @shoppingAddToList.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till i'**
  String get shoppingAddToList;

  /// No description provided for @shoppingItemName.
  ///
  /// In sv, this message translates to:
  /// **'Varunamn'**
  String get shoppingItemName;

  /// No description provided for @shoppingAmount.
  ///
  /// In sv, this message translates to:
  /// **'Mängd'**
  String get shoppingAmount;

  /// No description provided for @shoppingUnit.
  ///
  /// In sv, this message translates to:
  /// **'Enhet'**
  String get shoppingUnit;

  /// No description provided for @shoppingCategory.
  ///
  /// In sv, this message translates to:
  /// **'Kategori'**
  String get shoppingCategory;

  /// No description provided for @shoppingNote.
  ///
  /// In sv, this message translates to:
  /// **'Anteckning'**
  String get shoppingNote;

  /// No description provided for @shoppingAddItem.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vara'**
  String get shoppingAddItem;

  /// No description provided for @shoppingEditItem.
  ///
  /// In sv, this message translates to:
  /// **'Redigera vara'**
  String get shoppingEditItem;

  /// No description provided for @shoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslista'**
  String get shoppingList;

  /// No description provided for @authResetPassword.
  ///
  /// In sv, this message translates to:
  /// **'Återställ lösenord'**
  String get authResetPassword;

  /// No description provided for @authForgotPassword.
  ///
  /// In sv, this message translates to:
  /// **'Glömt lösenord?'**
  String get authForgotPassword;

  /// No description provided for @authEnterPassword.
  ///
  /// In sv, this message translates to:
  /// **'Ange ditt lösenord'**
  String get authEnterPassword;

  /// No description provided for @authPasswordMinLength.
  ///
  /// In sv, this message translates to:
  /// **'Minst 6 tecken'**
  String get authPasswordMinLength;

  /// No description provided for @authResetPasswordInstructions.
  ///
  /// In sv, this message translates to:
  /// **'Ange din email-adress så skickar vi instruktioner för att återställa ditt lösenord.'**
  String get authResetPasswordInstructions;

  /// No description provided for @navExitApp.
  ///
  /// In sv, this message translates to:
  /// **'Avsluta Butlery?'**
  String get navExitApp;

  /// No description provided for @navExitAppConfirmation.
  ///
  /// In sv, this message translates to:
  /// **'Vill du verkligen avsluta appen?'**
  String get navExitAppConfirmation;

  /// No description provided for @navExit.
  ///
  /// In sv, this message translates to:
  /// **'Avsluta'**
  String get navExit;

  /// No description provided for @imageAddImage.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till bild'**
  String get imageAddImage;

  /// No description provided for @imageTakePhoto.
  ///
  /// In sv, this message translates to:
  /// **'Ta foto'**
  String get imageTakePhoto;

  /// No description provided for @imageUseCamera.
  ///
  /// In sv, this message translates to:
  /// **'Använd kameran'**
  String get imageUseCamera;

  /// No description provided for @imageFromGallery.
  ///
  /// In sv, this message translates to:
  /// **'Välj från galleri'**
  String get imageFromGallery;

  /// No description provided for @imageSelectFromGallery.
  ///
  /// In sv, this message translates to:
  /// **'Välj från galleri'**
  String get imageSelectFromGallery;

  /// No description provided for @imageSelectUpTo.
  ///
  /// In sv, this message translates to:
  /// **'Välj upp till {count} bilder'**
  String imageSelectUpTo(int count);

  /// No description provided for @validationFieldRequired.
  ///
  /// In sv, this message translates to:
  /// **'{fieldName} krävs'**
  String validationFieldRequired(String fieldName);

  /// No description provided for @validationFieldTooShort.
  ///
  /// In sv, this message translates to:
  /// **'{fieldName} måste vara minst {minLength} tecken'**
  String validationFieldTooShort(String fieldName, int minLength);

  /// No description provided for @validationFieldTooLong.
  ///
  /// In sv, this message translates to:
  /// **'{fieldName} får vara max {maxLength} tecken'**
  String validationFieldTooLong(String fieldName, int maxLength);

  /// No description provided for @validationInvalidFormat.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt format för {fieldName}'**
  String validationInvalidFormat(String fieldName);

  /// No description provided for @validationNameRequired.
  ///
  /// In sv, this message translates to:
  /// **'Namn krävs'**
  String get validationNameRequired;

  /// No description provided for @validationEmailRequired.
  ///
  /// In sv, this message translates to:
  /// **'E-post krävs'**
  String get validationEmailRequired;

  /// No description provided for @validationPasswordRequired.
  ///
  /// In sv, this message translates to:
  /// **'Lösenord krävs'**
  String get validationPasswordRequired;

  /// No description provided for @validationInvalidEmail.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig e-postadress'**
  String get validationInvalidEmail;

  /// No description provided for @validationInvalidUrl.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig URL'**
  String get validationInvalidUrl;

  /// No description provided for @validationInvalidPhone.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt telefonnummer'**
  String get validationInvalidPhone;

  /// No description provided for @validationInvalidAmount.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt antal'**
  String get validationInvalidAmount;

  /// No description provided for @validationPasswordTooShort.
  ///
  /// In sv, this message translates to:
  /// **'Lösenordet måste vara minst 6 tecken'**
  String get validationPasswordTooShort;

  /// No description provided for @validationGenericRequired.
  ///
  /// In sv, this message translates to:
  /// **'Detta fält krävs'**
  String get validationGenericRequired;

  /// No description provided for @validationEmailInvalid.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig e-postadress'**
  String get validationEmailInvalid;

  /// No description provided for @errorGeneric.
  ///
  /// In sv, this message translates to:
  /// **'Ett fel uppstod. Försök igen.'**
  String get errorGeneric;

  /// No description provided for @errorNetwork.
  ///
  /// In sv, this message translates to:
  /// **'Nätverksfel. Kontrollera din internetanslutning.'**
  String get errorNetwork;

  /// No description provided for @errorServer.
  ///
  /// In sv, this message translates to:
  /// **'Serverfel. Försök igen senare.'**
  String get errorServer;

  /// No description provided for @errorAuthentication.
  ///
  /// In sv, this message translates to:
  /// **'Autentiseringsfel. Logga in igen.'**
  String get errorAuthentication;

  /// No description provided for @errorPermissionDenied.
  ///
  /// In sv, this message translates to:
  /// **'Du har inte behörighet för denna åtgärd.'**
  String get errorPermissionDenied;

  /// No description provided for @errorNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte hittas.'**
  String get errorNotFound;

  /// No description provided for @errorAlreadyExists.
  ///
  /// In sv, this message translates to:
  /// **'Finns redan.'**
  String get errorAlreadyExists;

  /// No description provided for @errorCouldNotCreate.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa {itemType}. Försök igen.'**
  String errorCouldNotCreate(String itemType);

  /// No description provided for @errorCouldNotUpdate.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera {itemType}. Försök igen.'**
  String errorCouldNotUpdate(String itemType);

  /// No description provided for @errorCouldNotDelete.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort {itemType}. Försök igen.'**
  String errorCouldNotDelete(String itemType);

  /// No description provided for @errorCouldNotLoad.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda {itemType}. Försök igen.'**
  String errorCouldNotLoad(String itemType);

  /// No description provided for @errorWithContext.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid {action}: {error}'**
  String errorWithContext(String action, String error);

  /// No description provided for @errorActionSpecific.
  ///
  /// In sv, this message translates to:
  /// **'Problem medan {action}: {issue}'**
  String errorActionSpecific(String action, String issue);

  /// No description provided for @successItemCreated.
  ///
  /// In sv, this message translates to:
  /// **'{itemType} skapades!'**
  String successItemCreated(String itemType);

  /// No description provided for @successItemUpdated.
  ///
  /// In sv, this message translates to:
  /// **'{itemType} uppdaterades!'**
  String successItemUpdated(String itemType);

  /// No description provided for @successItemDeleted.
  ///
  /// In sv, this message translates to:
  /// **'{itemType} togs bort!'**
  String successItemDeleted(String itemType);

  /// No description provided for @successItemAdded.
  ///
  /// In sv, this message translates to:
  /// **'{itemName} tillagd!'**
  String successItemAdded(String itemName);

  /// No description provided for @confirmDeleteItem.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill ta bort \"{itemName}\"?'**
  String confirmDeleteItem(String itemName);

  /// No description provided for @confirmUnsavedChanges.
  ///
  /// In sv, this message translates to:
  /// **'Du har osparade ändringar. Vill du lämna utan att spara?'**
  String get confirmUnsavedChanges;

  /// No description provided for @confirmIrreversibleAction.
  ///
  /// In sv, this message translates to:
  /// **'Denna åtgärd kan inte ångras.'**
  String get confirmIrreversibleAction;

  /// No description provided for @draftRecovery.
  ///
  /// In sv, this message translates to:
  /// **'Återställ utkast'**
  String get draftRecovery;

  /// No description provided for @draftRecoverySubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Du har osparade receptutkast. Vill du fortsätta där du slutade?'**
  String get draftRecoverySubtitle;

  /// No description provided for @draftRestore.
  ///
  /// In sv, this message translates to:
  /// **'Återställ'**
  String get draftRestore;

  /// No description provided for @draftStartFresh.
  ///
  /// In sv, this message translates to:
  /// **'Börja om'**
  String get draftStartFresh;

  /// No description provided for @draftRestored.
  ///
  /// In sv, this message translates to:
  /// **'Utkast återställt!'**
  String get draftRestored;

  /// No description provided for @draftRestoredDetails.
  ///
  /// In sv, this message translates to:
  /// **'fält laddades'**
  String get draftRestoredDetails;

  /// No description provided for @draftCouldNotRestore.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte återställa utkast. Börjar med tomt formulär.'**
  String get draftCouldNotRestore;

  /// No description provided for @draftRestoring.
  ///
  /// In sv, this message translates to:
  /// **'Återställer utkast...'**
  String get draftRestoring;

  /// No description provided for @draftUnnamedRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Namnlöst recept'**
  String get draftUnnamedRecipe;

  /// No description provided for @draftFieldsFilledCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} fält ifyllda'**
  String draftFieldsFilledCount(int count);

  /// No description provided for @draftRestoredWithCount.
  ///
  /// In sv, this message translates to:
  /// **'Utkast återställt! {count} fält laddades'**
  String draftRestoredWithCount(int count);

  /// No description provided for @connectivityOfflineMode.
  ///
  /// In sv, this message translates to:
  /// **'Offline-läge aktiverat'**
  String get connectivityOfflineMode;

  /// No description provided for @connectivityRestored.
  ///
  /// In sv, this message translates to:
  /// **'Anslutning återställd'**
  String get connectivityRestored;

  /// No description provided for @connectivitySyncingPending.
  ///
  /// In sv, this message translates to:
  /// **'Synkroniserar väntande ändringar...'**
  String get connectivitySyncingPending;

  /// No description provided for @connectivityLocalSaved.
  ///
  /// In sv, this message translates to:
  /// **'Ändringar sparade lokalt'**
  String get connectivityLocalSaved;

  /// No description provided for @connectivityWillSync.
  ///
  /// In sv, this message translates to:
  /// **'Synkroniseras när du är online igen'**
  String get connectivityWillSync;

  /// No description provided for @permissionInsufficient.
  ///
  /// In sv, this message translates to:
  /// **'Otillräckliga behörigheter'**
  String get permissionInsufficient;

  /// No description provided for @permissionReadOnly.
  ///
  /// In sv, this message translates to:
  /// **'Endast läsrättigheter'**
  String get permissionReadOnly;

  /// No description provided for @permissionOwnerOnly.
  ///
  /// In sv, this message translates to:
  /// **'Endast ägaren kan utföra denna åtgärd'**
  String get permissionOwnerOnly;

  /// No description provided for @permissionRequestEdit.
  ///
  /// In sv, this message translates to:
  /// **'Be om redigeringsrättigheter'**
  String get permissionRequestEdit;

  /// No description provided for @permissionMakePersonalCopy.
  ///
  /// In sv, this message translates to:
  /// **'Skapa personlig kopia'**
  String get permissionMakePersonalCopy;

  /// No description provided for @recoveryCheckConnection.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollera internetanslutningen'**
  String get recoveryCheckConnection;

  /// No description provided for @recoveryTryAgain.
  ///
  /// In sv, this message translates to:
  /// **'Försök igen'**
  String get recoveryTryAgain;

  /// No description provided for @recoveryLoginAgain.
  ///
  /// In sv, this message translates to:
  /// **'Logga in på nytt'**
  String get recoveryLoginAgain;

  /// No description provided for @recoveryContactOwner.
  ///
  /// In sv, this message translates to:
  /// **'Kontakta ägaren'**
  String get recoveryContactOwner;

  /// No description provided for @recoveryWaitAndRetry.
  ///
  /// In sv, this message translates to:
  /// **'Vänta och försök igen'**
  String get recoveryWaitAndRetry;

  /// No description provided for @recoveryCheckPermissions.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollera behörigheter'**
  String get recoveryCheckPermissions;

  /// No description provided for @emptyNoItems.
  ///
  /// In sv, this message translates to:
  /// **'Inga objekt hittades.'**
  String get emptyNoItems;

  /// No description provided for @emptyList.
  ///
  /// In sv, this message translates to:
  /// **'Listan är tom.'**
  String get emptyList;

  /// No description provided for @emptyNoResults.
  ///
  /// In sv, this message translates to:
  /// **'Inga resultat hittades.'**
  String get emptyNoResults;

  /// No description provided for @emptyNoFriends.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga vänner än.'**
  String get emptyNoFriends;

  /// No description provided for @emptyNoRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga recept än.'**
  String get emptyNoRecipes;

  /// No description provided for @emptyNoShoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga inköpslistor än.'**
  String get emptyNoShoppingLists;

  /// No description provided for @emptyNoRecipesSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till ditt första recept genom att trycka på \"{addButton}\"'**
  String emptyNoRecipesSubtitle(String addButton);

  /// No description provided for @emptyNoSearchResultsSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Prova att söka på något annat eller rensa sökningen'**
  String get emptyNoSearchResultsSubtitle;

  /// No description provided for @emptyNoFriendsSearchTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner matchade din sökning'**
  String get emptyNoFriendsSearchTitle;

  /// No description provided for @emptyNoGroupsSearchTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inga grupper matchade din sökning'**
  String get emptyNoGroupsSearchTitle;

  /// No description provided for @emptyNoMenuTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ingen meny genererad ännu'**
  String get emptyNoMenuTitle;

  /// No description provided for @emptyNoMenuSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Skriv vad du vill ha eller tryck på knappen nedan'**
  String get emptyNoMenuSubtitle;

  /// No description provided for @emptyNoShoppingListTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ingen meny att skapa inköpslista från'**
  String get emptyNoShoppingListTitle;

  /// No description provided for @emptyNoShoppingListSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Gå tillbaka och skapa en veckomeny först'**
  String get emptyNoShoppingListSubtitle;

  /// No description provided for @emptyNoFriendsTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner ännu'**
  String get emptyNoFriendsTitle;

  /// No description provided for @emptyNoFriendsSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vänner för att dela recept och menyer'**
  String get emptyNoFriendsSubtitle;

  /// No description provided for @emptyNoCategoriesTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inga kategorier skapade'**
  String get emptyNoCategoriesTitle;

  /// No description provided for @emptyNoCategoriesSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Skapa din första kategori för att organisera dina vänner'**
  String get emptyNoCategoriesSubtitle;

  /// No description provided for @emptyNoImagesTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inga bilder tillagda'**
  String get emptyNoImagesTitle;

  /// No description provided for @emptyNoImagesSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till bilder för att göra ditt recept mer attraktivt'**
  String get emptyNoImagesSubtitle;

  /// No description provided for @emptyNoTargetsTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inga destinationer tillgängliga'**
  String get emptyNoTargetsTitle;

  /// No description provided for @emptyNoTargetsSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vänner eller grupper för att kunna dela innehåll'**
  String get emptyNoTargetsSubtitle;

  /// No description provided for @emptyNoSavedMenusTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inga sparade menyer'**
  String get emptyNoSavedMenusTitle;

  /// No description provided for @emptyNoSavedMenusSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Skapa och spara menyer för att enkelt ladda dem senare'**
  String get emptyNoSavedMenusSubtitle;

  /// No description provided for @emptyGenericTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inget innehåll att visa'**
  String get emptyGenericTitle;

  /// No description provided for @recipeName.
  ///
  /// In sv, this message translates to:
  /// **'Receptnamn'**
  String get recipeName;

  /// No description provided for @recipeDescription.
  ///
  /// In sv, this message translates to:
  /// **'Beskrivning'**
  String get recipeDescription;

  /// No description provided for @recipeIngredients.
  ///
  /// In sv, this message translates to:
  /// **'Ingredienser'**
  String get recipeIngredients;

  /// No description provided for @recipeInstructions.
  ///
  /// In sv, this message translates to:
  /// **'Instruktioner'**
  String get recipeInstructions;

  /// No description provided for @recipeCookingTime.
  ///
  /// In sv, this message translates to:
  /// **'Tillagningstid'**
  String get recipeCookingTime;

  /// No description provided for @recipePortions.
  ///
  /// In sv, this message translates to:
  /// **'Portioner'**
  String get recipePortions;

  /// No description provided for @recipeAdd.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till recept'**
  String get recipeAdd;

  /// No description provided for @recipeEdit.
  ///
  /// In sv, this message translates to:
  /// **'Redigera recept'**
  String get recipeEdit;

  /// No description provided for @recipeDelete.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort recept'**
  String get recipeDelete;

  /// No description provided for @recipeDeleting.
  ///
  /// In sv, this message translates to:
  /// **'Tar bort recept...'**
  String get recipeDeleting;

  /// No description provided for @recipeFormatPortions.
  ///
  /// In sv, this message translates to:
  /// **'{count, plural, =1{1 portion} other{{count} portioner}}'**
  String recipeFormatPortions(int count);

  /// No description provided for @socialFriendName.
  ///
  /// In sv, this message translates to:
  /// **'Vännamn'**
  String get socialFriendName;

  /// No description provided for @socialGroupName.
  ///
  /// In sv, this message translates to:
  /// **'Gruppnamn'**
  String get socialGroupName;

  /// No description provided for @socialDisplayName.
  ///
  /// In sv, this message translates to:
  /// **'Visningsnamn'**
  String get socialDisplayName;

  /// No description provided for @socialCreateGroup.
  ///
  /// In sv, this message translates to:
  /// **'Skapa grupp'**
  String get socialCreateGroup;

  /// No description provided for @socialEditGroup.
  ///
  /// In sv, this message translates to:
  /// **'Redigera grupp'**
  String get socialEditGroup;

  /// No description provided for @socialDeleteGroup.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort grupp'**
  String get socialDeleteGroup;

  /// No description provided for @socialAddFriend.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vän'**
  String get socialAddFriend;

  /// No description provided for @socialRemoveFriend.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort vän'**
  String get socialRemoveFriend;

  /// No description provided for @socialSendFriendRequest.
  ///
  /// In sv, this message translates to:
  /// **'Skicka vänförfrågan'**
  String get socialSendFriendRequest;

  /// No description provided for @socialAcceptFriendRequest.
  ///
  /// In sv, this message translates to:
  /// **'Acceptera vänförfrågan'**
  String get socialAcceptFriendRequest;

  /// No description provided for @socialDeclineFriendRequest.
  ///
  /// In sv, this message translates to:
  /// **'Avböj vänförfrågan'**
  String get socialDeclineFriendRequest;

  /// No description provided for @menuName.
  ///
  /// In sv, this message translates to:
  /// **'Menynamn'**
  String get menuName;

  /// No description provided for @menuSave.
  ///
  /// In sv, this message translates to:
  /// **'Spara meny'**
  String get menuSave;

  /// No description provided for @menuLoad.
  ///
  /// In sv, this message translates to:
  /// **'Ladda meny'**
  String get menuLoad;

  /// No description provided for @menuWeek.
  ///
  /// In sv, this message translates to:
  /// **'Veckomeny'**
  String get menuWeek;

  /// No description provided for @messagingTitle.
  ///
  /// In sv, this message translates to:
  /// **'Meddelanden'**
  String get messagingTitle;

  /// No description provided for @messagingNewConversation.
  ///
  /// In sv, this message translates to:
  /// **'Ny konversation'**
  String get messagingNewConversation;

  /// No description provided for @messagingSearchConversations.
  ///
  /// In sv, this message translates to:
  /// **'Sök konversationer...'**
  String get messagingSearchConversations;

  /// No description provided for @messagingLoadingConversations.
  ///
  /// In sv, this message translates to:
  /// **'Laddar konversationer...'**
  String get messagingLoadingConversations;

  /// No description provided for @messagingNoConversationsFound.
  ///
  /// In sv, this message translates to:
  /// **'Inga konversationer hittades'**
  String get messagingNoConversationsFound;

  /// No description provided for @messagingTryAnotherSearch.
  ///
  /// In sv, this message translates to:
  /// **'Försök med ett annat sökord'**
  String get messagingTryAnotherSearch;

  /// No description provided for @messagingNoConversationsYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga konversationer än'**
  String get messagingNoConversationsYet;

  /// No description provided for @messagingStartFirstConversation.
  ///
  /// In sv, this message translates to:
  /// **'Starta din första konversation genom att trycka på meddelande-knappen'**
  String get messagingStartFirstConversation;

  /// No description provided for @messagingMarkAsRead.
  ///
  /// In sv, this message translates to:
  /// **'Markera som läst'**
  String get messagingMarkAsRead;

  /// No description provided for @messagingGroupInfo.
  ///
  /// In sv, this message translates to:
  /// **'Gruppinformation'**
  String get messagingGroupInfo;

  /// No description provided for @messagingLeaveGroup.
  ///
  /// In sv, this message translates to:
  /// **'Lämna grupp'**
  String get messagingLeaveGroup;

  /// No description provided for @messagingViewProfile.
  ///
  /// In sv, this message translates to:
  /// **'Visa profil'**
  String get messagingViewProfile;

  /// No description provided for @messagingDeleteConversation.
  ///
  /// In sv, this message translates to:
  /// **'Radera konversation'**
  String get messagingDeleteConversation;

  /// No description provided for @messagingLeftGroup.
  ///
  /// In sv, this message translates to:
  /// **'Du har lämnat gruppen'**
  String get messagingLeftGroup;

  /// No description provided for @messagingCouldNotLeaveGroup.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lämna gruppen: {error}'**
  String messagingCouldNotLeaveGroup(String error);

  /// No description provided for @messagingLeave.
  ///
  /// In sv, this message translates to:
  /// **'Lämna'**
  String get messagingLeave;

  /// No description provided for @messagingDeleteConversationConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill radera denna konversation? Alla meddelanden kommer att försvinna.'**
  String get messagingDeleteConversationConfirm;

  /// No description provided for @messagingCouldNotShowProfile.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte visa profil: {error}'**
  String messagingCouldNotShowProfile(String error);

  /// No description provided for @messagingConversationDeleted.
  ///
  /// In sv, this message translates to:
  /// **'Konversation \"{title}\" raderad'**
  String messagingConversationDeleted(String title);

  /// No description provided for @messagingCouldNotDeleteConversation.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte radera konversation: {error}'**
  String messagingCouldNotDeleteConversation(String error);

  /// No description provided for @messagingConfirmLeaveGroup.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill lämna \"{groupName}\"?'**
  String messagingConfirmLeaveGroup(String groupName);

  /// No description provided for @profileLogout.
  ///
  /// In sv, this message translates to:
  /// **'Logga ut'**
  String get profileLogout;

  /// No description provided for @profileLogoutConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill logga ut?'**
  String get profileLogoutConfirm;

  /// No description provided for @profileDeleteAccount.
  ///
  /// In sv, this message translates to:
  /// **'Radera konto permanent'**
  String get profileDeleteAccount;

  /// No description provided for @profileDeleteWarningTitle.
  ///
  /// In sv, this message translates to:
  /// **'VARNING: Detta kommer att:'**
  String get profileDeleteWarningTitle;

  /// No description provided for @profileDeleteWarningRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort alla dina recept'**
  String get profileDeleteWarningRecipes;

  /// No description provided for @profileDeleteWarningMenus.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort alla dina menyer'**
  String get profileDeleteWarningMenus;

  /// No description provided for @profileDeleteWarningShoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort alla dina shoppinglistor'**
  String get profileDeleteWarningShoppingLists;

  /// No description provided for @profileDeleteWarningFriends.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort alla vänner och meddelanden'**
  String get profileDeleteWarningFriends;

  /// No description provided for @profileDeleteWarningSharedContent.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort all delad innehåll'**
  String get profileDeleteWarningSharedContent;

  /// No description provided for @profileDeleteIrreversible.
  ///
  /// In sv, this message translates to:
  /// **'Denna åtgärd kan INTE ångras!'**
  String get profileDeleteIrreversible;

  /// No description provided for @profileDeleteConfirmButton.
  ///
  /// In sv, this message translates to:
  /// **'Jag förstår, radera mitt konto'**
  String get profileDeleteConfirmButton;

  /// No description provided for @profileConfirmWithPassword.
  ///
  /// In sv, this message translates to:
  /// **'Bekräfta med lösenord'**
  String get profileConfirmWithPassword;

  /// No description provided for @profileEnterPasswordToConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Ange ditt lösenord för att bekräfta raderingen:'**
  String get profileEnterPasswordToConfirm;

  /// No description provided for @profilePassword.
  ///
  /// In sv, this message translates to:
  /// **'Lösenord'**
  String get profilePassword;

  /// No description provided for @profileConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Bekräfta'**
  String get profileConfirm;

  /// No description provided for @profileError.
  ///
  /// In sv, this message translates to:
  /// **'Fel'**
  String get profileError;

  /// No description provided for @profileCouldNotDeleteAccount.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte radera konto: {error}'**
  String profileCouldNotDeleteAccount(String error);

  /// No description provided for @chatErrorOccurred.
  ///
  /// In sv, this message translates to:
  /// **'Ett fel uppstod'**
  String get chatErrorOccurred;

  /// No description provided for @chatConversationInfo.
  ///
  /// In sv, this message translates to:
  /// **'Konversationsinfo'**
  String get chatConversationInfo;

  /// No description provided for @chatTypeDirectMessage.
  ///
  /// In sv, this message translates to:
  /// **'Typ: Direktmeddelande'**
  String get chatTypeDirectMessage;

  /// No description provided for @chatCreatedAt.
  ///
  /// In sv, this message translates to:
  /// **'Skapad: {date}'**
  String chatCreatedAt(String date);

  /// No description provided for @chatNotificationSettingsUpdated.
  ///
  /// In sv, this message translates to:
  /// **'Notifikationsinställningar uppdaterade'**
  String get chatNotificationSettingsUpdated;

  /// No description provided for @chatCouldNotChangeNotifications.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ändra notifikationsinställningar'**
  String get chatCouldNotChangeNotifications;

  /// No description provided for @chatLeaveConversation.
  ///
  /// In sv, this message translates to:
  /// **'Lämna konversation'**
  String get chatLeaveConversation;

  /// No description provided for @chatLeaveConversationConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill lämna denna konversation?'**
  String get chatLeaveConversationConfirm;

  /// No description provided for @chatCouldNotLeaveConversation.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lämna konversationen'**
  String get chatCouldNotLeaveConversation;

  /// No description provided for @chatEditMessage.
  ///
  /// In sv, this message translates to:
  /// **'Redigera meddelande'**
  String get chatEditMessage;

  /// No description provided for @chatWriteYourMessage.
  ///
  /// In sv, this message translates to:
  /// **'Skriv ditt meddelande...'**
  String get chatWriteYourMessage;

  /// No description provided for @chatCouldNotEditMessage.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte redigera meddelandet'**
  String get chatCouldNotEditMessage;

  /// No description provided for @chatCouldNotDeleteMessage.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort meddelandet'**
  String get chatCouldNotDeleteMessage;

  /// No description provided for @chatMessageCopied.
  ///
  /// In sv, this message translates to:
  /// **'Meddelande kopierat'**
  String get chatMessageCopied;

  /// No description provided for @chatCouldNotCopyMessage.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte kopiera meddelandet'**
  String get chatCouldNotCopyMessage;

  /// No description provided for @chatYourRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Dina recept'**
  String get chatYourRecipes;

  /// No description provided for @chatSharedRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Delat recept'**
  String get chatSharedRecipe;

  /// No description provided for @chatCheckOutRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kolla in detta recept!'**
  String get chatCheckOutRecipe;

  /// No description provided for @chatCouldNotShareRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dela recept'**
  String get chatCouldNotShareRecipe;

  /// No description provided for @chatMenuSharingComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Menydelning kommer snart'**
  String get chatMenuSharingComingSoon;

  /// No description provided for @chatCouldNotShareMenu.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dela meny'**
  String get chatCouldNotShareMenu;

  /// No description provided for @chatShoppingListSharingComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslistedelning kommer snart'**
  String get chatShoppingListSharingComingSoon;

  /// No description provided for @chatCouldNotShareShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dela inköpslista'**
  String get chatCouldNotShareShoppingList;

  /// No description provided for @chatLoadingImage.
  ///
  /// In sv, this message translates to:
  /// **'Laddar bild...'**
  String get chatLoadingImage;

  /// No description provided for @chatImageSent.
  ///
  /// In sv, this message translates to:
  /// **'Bild skickad!'**
  String get chatImageSent;

  /// No description provided for @chatNoImageSelected.
  ///
  /// In sv, this message translates to:
  /// **'Ingen bild vald'**
  String get chatNoImageSelected;

  /// No description provided for @chatCouldNotSharePhoto.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dela foto'**
  String get chatCouldNotSharePhoto;

  /// No description provided for @chatDeleteMessage.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort'**
  String get chatDeleteMessage;

  /// No description provided for @chatDeleteMessageConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill ta bort meddelandet?'**
  String get chatDeleteMessageConfirm;

  /// No description provided for @placeholderSearch.
  ///
  /// In sv, this message translates to:
  /// **'Sök...'**
  String get placeholderSearch;

  /// No description provided for @placeholderName.
  ///
  /// In sv, this message translates to:
  /// **'Ange namn'**
  String get placeholderName;

  /// No description provided for @placeholderDescription.
  ///
  /// In sv, this message translates to:
  /// **'Ange beskrivning (valfritt)'**
  String get placeholderDescription;

  /// No description provided for @placeholderEmail.
  ///
  /// In sv, this message translates to:
  /// **'din@email.com'**
  String get placeholderEmail;

  /// No description provided for @placeholderUrl.
  ///
  /// In sv, this message translates to:
  /// **'https://exempel.se'**
  String get placeholderUrl;

  /// No description provided for @placeholderPhone.
  ///
  /// In sv, this message translates to:
  /// **'+46 70 123 45 67'**
  String get placeholderPhone;

  /// No description provided for @statusConnecting.
  ///
  /// In sv, this message translates to:
  /// **'Ansluter...'**
  String get statusConnecting;

  /// No description provided for @statusSyncing.
  ///
  /// In sv, this message translates to:
  /// **'Synkroniserar...'**
  String get statusSyncing;

  /// No description provided for @statusUploading.
  ///
  /// In sv, this message translates to:
  /// **'Laddar upp...'**
  String get statusUploading;

  /// No description provided for @statusDownloading.
  ///
  /// In sv, this message translates to:
  /// **'Laddar ner...'**
  String get statusDownloading;

  /// No description provided for @statusProcessing.
  ///
  /// In sv, this message translates to:
  /// **'Bearbetar...'**
  String get statusProcessing;

  /// No description provided for @statusSaving.
  ///
  /// In sv, this message translates to:
  /// **'Sparar...'**
  String get statusSaving;

  /// No description provided for @statusDeleting.
  ///
  /// In sv, this message translates to:
  /// **'Tar bort...'**
  String get statusDeleting;

  /// No description provided for @statusCreating.
  ///
  /// In sv, this message translates to:
  /// **'Skapar...'**
  String get statusCreating;

  /// No description provided for @statusUpdating.
  ///
  /// In sv, this message translates to:
  /// **'Uppdaterar...'**
  String get statusUpdating;

  /// No description provided for @accessibilityMenuButton.
  ///
  /// In sv, this message translates to:
  /// **'Menyknapp'**
  String get accessibilityMenuButton;

  /// No description provided for @accessibilityBackButton.
  ///
  /// In sv, this message translates to:
  /// **'Tillbaka'**
  String get accessibilityBackButton;

  /// No description provided for @accessibilityCloseButton.
  ///
  /// In sv, this message translates to:
  /// **'Stäng'**
  String get accessibilityCloseButton;

  /// No description provided for @accessibilityMoreOptions.
  ///
  /// In sv, this message translates to:
  /// **'Fler alternativ'**
  String get accessibilityMoreOptions;

  /// No description provided for @accessibilityExpandButton.
  ///
  /// In sv, this message translates to:
  /// **'Expandera'**
  String get accessibilityExpandButton;

  /// No description provided for @accessibilityCollapseButton.
  ///
  /// In sv, this message translates to:
  /// **'Kollapsa'**
  String get accessibilityCollapseButton;

  /// No description provided for @timeToday.
  ///
  /// In sv, this message translates to:
  /// **'Idag'**
  String get timeToday;

  /// No description provided for @timeYesterday.
  ///
  /// In sv, this message translates to:
  /// **'Igår'**
  String get timeYesterday;

  /// No description provided for @timeTomorrow.
  ///
  /// In sv, this message translates to:
  /// **'Imorgon'**
  String get timeTomorrow;

  /// No description provided for @timeThisWeek.
  ///
  /// In sv, this message translates to:
  /// **'Denna vecka'**
  String get timeThisWeek;

  /// No description provided for @timeLastWeek.
  ///
  /// In sv, this message translates to:
  /// **'Förra veckan'**
  String get timeLastWeek;

  /// No description provided for @timeNextWeek.
  ///
  /// In sv, this message translates to:
  /// **'Nästa vecka'**
  String get timeNextWeek;

  /// No description provided for @unitMinutesShort.
  ///
  /// In sv, this message translates to:
  /// **'min'**
  String get unitMinutesShort;

  /// No description provided for @unitHoursShort.
  ///
  /// In sv, this message translates to:
  /// **'h'**
  String get unitHoursShort;

  /// No description provided for @unitPiecesShort.
  ///
  /// In sv, this message translates to:
  /// **'st'**
  String get unitPiecesShort;

  /// No description provided for @unitLiters.
  ///
  /// In sv, this message translates to:
  /// **'liter'**
  String get unitLiters;

  /// No description provided for @unitKilograms.
  ///
  /// In sv, this message translates to:
  /// **'kg'**
  String get unitKilograms;

  /// No description provided for @unitGrams.
  ///
  /// In sv, this message translates to:
  /// **'g'**
  String get unitGrams;

  /// No description provided for @technicalShowDetails.
  ///
  /// In sv, this message translates to:
  /// **'Visa tekniska detaljer'**
  String get technicalShowDetails;

  /// No description provided for @technicalHideDetails.
  ///
  /// In sv, this message translates to:
  /// **'Dölj tekniska detaljer'**
  String get technicalHideDetails;

  /// No description provided for @technicalInformation.
  ///
  /// In sv, this message translates to:
  /// **'Teknisk information'**
  String get technicalInformation;

  /// No description provided for @technicalContactSupport.
  ///
  /// In sv, this message translates to:
  /// **'Kontakta support'**
  String get technicalContactSupport;

  /// No description provided for @technicalTryAgainLater.
  ///
  /// In sv, this message translates to:
  /// **'Försök igen senare'**
  String get technicalTryAgainLater;

  /// No description provided for @dialogErrorTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ett fel uppstod'**
  String get dialogErrorTitle;

  /// No description provided for @dialogLoading.
  ///
  /// In sv, this message translates to:
  /// **'Laddar...'**
  String get dialogLoading;

  /// No description provided for @dialogConfirmDeleteTitle.
  ///
  /// In sv, this message translates to:
  /// **'Bekräfta borttagning'**
  String get dialogConfirmDeleteTitle;

  /// No description provided for @dialogConfirmDeleteMessage.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill ta bort {itemName} från {itemType}?'**
  String dialogConfirmDeleteMessage(String itemName, String itemType);

  /// No description provided for @recipePortionAbbreviation.
  ///
  /// In sv, this message translates to:
  /// **'port'**
  String get recipePortionAbbreviation;

  /// No description provided for @recipePortionSingular.
  ///
  /// In sv, this message translates to:
  /// **'portion'**
  String get recipePortionSingular;

  /// No description provided for @recipePortionsPlural.
  ///
  /// In sv, this message translates to:
  /// **'portioner'**
  String get recipePortionsPlural;

  /// No description provided for @recipeCookedToday.
  ///
  /// In sv, this message translates to:
  /// **'Lagat idag'**
  String get recipeCookedToday;

  /// No description provided for @recipeCookedTodaySuccess.
  ///
  /// In sv, this message translates to:
  /// **'Recept markerat som lagat idag!'**
  String get recipeCookedTodaySuccess;

  /// No description provided for @recipeCookedTodayError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte markera som lagat'**
  String get recipeCookedTodayError;

  /// No description provided for @recipeNoInstructions.
  ///
  /// In sv, this message translates to:
  /// **'Inga instruktioner angivna.'**
  String get recipeNoInstructions;

  /// No description provided for @recipeTags.
  ///
  /// In sv, this message translates to:
  /// **'Taggar'**
  String get recipeTags;

  /// No description provided for @recipeImagesTitle.
  ///
  /// In sv, this message translates to:
  /// **'Bilder'**
  String get recipeImagesTitle;

  /// No description provided for @recipeImageCount.
  ///
  /// In sv, this message translates to:
  /// **'{count, plural, =1{1 bild} other{{count} bilder}}'**
  String recipeImageCount(int count);

  /// No description provided for @recipePersonalTags.
  ///
  /// In sv, this message translates to:
  /// **'Personliga taggar'**
  String get recipePersonalTags;

  /// No description provided for @recipeIngredientsForPortions.
  ///
  /// In sv, this message translates to:
  /// **'Ingredienser för {count} {count, plural, =1{portion} other{portioner}}:'**
  String recipeIngredientsForPortions(int count);

  /// No description provided for @recipeAnalysisFailed.
  ///
  /// In sv, this message translates to:
  /// **'Analys misslyckades'**
  String get recipeAnalysisFailed;

  /// No description provided for @recipeAnalyzing.
  ///
  /// In sv, this message translates to:
  /// **'Analyseras...'**
  String get recipeAnalyzing;

  /// No description provided for @recipeAnalysisFailedA11y.
  ///
  /// In sv, this message translates to:
  /// **'Ingrediensanalys misslyckades'**
  String get recipeAnalysisFailedA11y;

  /// No description provided for @recipeAnalyzingA11y.
  ///
  /// In sv, this message translates to:
  /// **'Ingredienser analyseras'**
  String get recipeAnalyzingA11y;

  /// No description provided for @recipeSearchHint.
  ///
  /// In sv, this message translates to:
  /// **'sök bland recepten...'**
  String get recipeSearchHint;

  /// No description provided for @recipeShowMore.
  ///
  /// In sv, this message translates to:
  /// **'Visa fler recept'**
  String get recipeShowMore;

  /// No description provided for @recipeCountBadge.
  ///
  /// In sv, this message translates to:
  /// **'{count} recept'**
  String recipeCountBadge(int count);

  /// No description provided for @scalerPortionsLabel.
  ///
  /// In sv, this message translates to:
  /// **'Portioner:'**
  String get scalerPortionsLabel;

  /// No description provided for @scalerUsingSwedishUnits.
  ///
  /// In sv, this message translates to:
  /// **'Använder svenska enheter'**
  String get scalerUsingSwedishUnits;

  /// No description provided for @scalerConvertAmericanUnits.
  ///
  /// In sv, this message translates to:
  /// **'Konvertera amerikanska enheter'**
  String get scalerConvertAmericanUnits;

  /// No description provided for @scalerScaledFromTo.
  ///
  /// In sv, this message translates to:
  /// **'Skalat från {from} till {to} portioner'**
  String scalerScaledFromTo(int from, int to);

  /// No description provided for @scalerAmericanConverted.
  ///
  /// In sv, this message translates to:
  /// **'Amerikanska enheter konverterade till svenska'**
  String get scalerAmericanConverted;

  /// No description provided for @menuPromptQuestion.
  ///
  /// In sv, this message translates to:
  /// **'Vad vill du ha för meny?'**
  String get menuPromptQuestion;

  /// No description provided for @menuPromptHint.
  ///
  /// In sv, this message translates to:
  /// **'Ex: 3 middagar, 2 luncher och 1 frukost'**
  String get menuPromptHint;

  /// No description provided for @menuGenerating.
  ///
  /// In sv, this message translates to:
  /// **'Genererar...'**
  String get menuGenerating;

  /// No description provided for @menuGenerateNew.
  ///
  /// In sv, this message translates to:
  /// **'Generera ny meny'**
  String get menuGenerateNew;

  /// No description provided for @menuGenerate.
  ///
  /// In sv, this message translates to:
  /// **'Generera meny'**
  String get menuGenerate;

  /// No description provided for @menuYourWeeklyMenu.
  ///
  /// In sv, this message translates to:
  /// **'Din veckomeny'**
  String get menuYourWeeklyMenu;

  /// No description provided for @menuRecipeCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} recept'**
  String menuRecipeCount(int count);

  /// No description provided for @menuChooseManually.
  ///
  /// In sv, this message translates to:
  /// **'Välj recept manuellt'**
  String get menuChooseManually;

  /// No description provided for @menuNoMoreRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Inga fler recept tillgängliga för byte'**
  String get menuNoMoreRecipes;

  /// No description provided for @menuGenerateError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte generera meny'**
  String get menuGenerateError;

  /// No description provided for @menuWeekBadgeWithCount.
  ///
  /// In sv, this message translates to:
  /// **'Vecka {week} · {count} rätter'**
  String menuWeekBadgeWithCount(int week, int count);

  /// No description provided for @menuWeekBadge.
  ///
  /// In sv, this message translates to:
  /// **'Vecka {week}'**
  String menuWeekBadge(int week);

  /// No description provided for @menuToShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Till inköpslista'**
  String get menuToShoppingList;

  /// No description provided for @menuLoadSaved.
  ///
  /// In sv, this message translates to:
  /// **'Ladda sparad meny'**
  String get menuLoadSaved;

  /// No description provided for @menuClear.
  ///
  /// In sv, this message translates to:
  /// **'Rensa meny'**
  String get menuClear;

  /// No description provided for @menuShared.
  ///
  /// In sv, this message translates to:
  /// **'Veckomeny delad!'**
  String get menuShared;

  /// No description provided for @menuGeneratingOverlay.
  ///
  /// In sv, this message translates to:
  /// **'Genererar din veckomeny...'**
  String get menuGeneratingOverlay;

  /// No description provided for @menuGeneratingSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Hittar recept som passar dina preferenser'**
  String get menuGeneratingSubtitle;

  /// No description provided for @shoppingCountBadge.
  ///
  /// In sv, this message translates to:
  /// **'{items} varor · {done} klara'**
  String shoppingCountBadge(int items, int done);

  /// No description provided for @commonSort.
  ///
  /// In sv, this message translates to:
  /// **'Sortera'**
  String get commonSort;

  /// No description provided for @commonHide.
  ///
  /// In sv, this message translates to:
  /// **'Dölj'**
  String get commonHide;

  /// No description provided for @commonShowAllCount.
  ///
  /// In sv, this message translates to:
  /// **'Visa alla ({count})'**
  String commonShowAllCount(int count);

  /// No description provided for @commonMoreCount.
  ///
  /// In sv, this message translates to:
  /// **'+{count} till'**
  String commonMoreCount(int count);

  /// No description provided for @commonDismiss.
  ///
  /// In sv, this message translates to:
  /// **'Avfärda'**
  String get commonDismiss;

  /// No description provided for @errorUnexpected.
  ///
  /// In sv, this message translates to:
  /// **'Ett oväntat fel uppstod'**
  String get errorUnexpected;

  /// No description provided for @searchClearSearch.
  ///
  /// In sv, this message translates to:
  /// **'Rensa sökning'**
  String get searchClearSearch;

  /// No description provided for @searchClearFilters.
  ///
  /// In sv, this message translates to:
  /// **'Rensa filter'**
  String get searchClearFilters;

  /// No description provided for @syncComplete.
  ///
  /// In sv, this message translates to:
  /// **'Synkronisering klar!'**
  String get syncComplete;

  /// No description provided for @syncFailed.
  ///
  /// In sv, this message translates to:
  /// **'Synkronisering misslyckades: {error}'**
  String syncFailed(String error);

  /// No description provided for @offlineShowingLocal.
  ///
  /// In sv, this message translates to:
  /// **'Offline-läge - visar lokala recept'**
  String get offlineShowingLocal;

  /// No description provided for @recipeCreateCopy.
  ///
  /// In sv, this message translates to:
  /// **'Skapa kopia'**
  String get recipeCreateCopy;

  /// No description provided for @recipeCreateShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Skapa inköpslista'**
  String get recipeCreateShoppingList;

  /// No description provided for @recipeUpdateTags.
  ///
  /// In sv, this message translates to:
  /// **'Uppdatera taggar'**
  String get recipeUpdateTags;

  /// No description provided for @recipeViewSource.
  ///
  /// In sv, this message translates to:
  /// **'Visa källa'**
  String get recipeViewSource;

  /// No description provided for @recipeShareWithFriends.
  ///
  /// In sv, this message translates to:
  /// **'Dela med vänner'**
  String get recipeShareWithFriends;

  /// No description provided for @recipeShareExternal.
  ///
  /// In sv, this message translates to:
  /// **'Dela externt'**
  String get recipeShareExternal;

  /// No description provided for @recipeSourceFrom.
  ///
  /// In sv, this message translates to:
  /// **'Från {host}'**
  String recipeSourceFrom(String host);

  /// No description provided for @errorCouldNotOpenLink.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte öppna länk'**
  String get errorCouldNotOpenLink;

  /// No description provided for @errorInvalidLink.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig länk'**
  String get errorInvalidLink;

  /// No description provided for @shoppingItemRemoved.
  ///
  /// In sv, this message translates to:
  /// **'{name} borttagen!'**
  String shoppingItemRemoved(String name);

  /// No description provided for @shoppingItemRemoveError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort {name}'**
  String shoppingItemRemoveError(String name);

  /// No description provided for @shoppingAllUnchecked.
  ///
  /// In sv, this message translates to:
  /// **'Alla artiklar avbockade!'**
  String get shoppingAllUnchecked;

  /// No description provided for @shoppingNoListForRename.
  ///
  /// In sv, this message translates to:
  /// **'Ingen lista vald för att byta namn'**
  String get shoppingNoListForRename;

  /// No description provided for @shoppingNoListForDelete.
  ///
  /// In sv, this message translates to:
  /// **'Ingen lista vald för borttagning'**
  String get shoppingNoListForDelete;

  /// No description provided for @commonBack.
  ///
  /// In sv, this message translates to:
  /// **'Tillbaka'**
  String get commonBack;

  /// No description provided for @commonEnable.
  ///
  /// In sv, this message translates to:
  /// **'Aktivera'**
  String get commonEnable;

  /// No description provided for @commonDisable.
  ///
  /// In sv, this message translates to:
  /// **'Inaktivera'**
  String get commonDisable;

  /// No description provided for @commonName.
  ///
  /// In sv, this message translates to:
  /// **'Namn'**
  String get commonName;

  /// No description provided for @commonShowDetails.
  ///
  /// In sv, this message translates to:
  /// **'Visa detaljer'**
  String get commonShowDetails;

  /// No description provided for @commonEditName.
  ///
  /// In sv, this message translates to:
  /// **'Redigera namn'**
  String get commonEditName;

  /// No description provided for @commonErrorOccurred.
  ///
  /// In sv, this message translates to:
  /// **'Ett fel uppstod'**
  String get commonErrorOccurred;

  /// No description provided for @commonContinue.
  ///
  /// In sv, this message translates to:
  /// **'Fortsätt'**
  String get commonContinue;

  /// No description provided for @commonNext.
  ///
  /// In sv, this message translates to:
  /// **'Nästa'**
  String get commonNext;

  /// No description provided for @commonPrevious.
  ///
  /// In sv, this message translates to:
  /// **'Föregående'**
  String get commonPrevious;

  /// No description provided for @commonSkip.
  ///
  /// In sv, this message translates to:
  /// **'Hoppa över'**
  String get commonSkip;

  /// No description provided for @commonSkipAll.
  ///
  /// In sv, this message translates to:
  /// **'Hoppa över alla'**
  String get commonSkipAll;

  /// No description provided for @commonSaveAndClose.
  ///
  /// In sv, this message translates to:
  /// **'Spara och stäng'**
  String get commonSaveAndClose;

  /// No description provided for @commonSaveAndNext.
  ///
  /// In sv, this message translates to:
  /// **'Spara och nästa'**
  String get commonSaveAndNext;

  /// No description provided for @commonSaveChanges.
  ///
  /// In sv, this message translates to:
  /// **'Spara ändringar'**
  String get commonSaveChanges;

  /// No description provided for @commonSaveMyCopy.
  ///
  /// In sv, this message translates to:
  /// **'Spara min kopia'**
  String get commonSaveMyCopy;

  /// No description provided for @commonSaveAsNew.
  ///
  /// In sv, this message translates to:
  /// **'Spara som ny'**
  String get commonSaveAsNew;

  /// No description provided for @commonSelectAll.
  ///
  /// In sv, this message translates to:
  /// **'Välj alla'**
  String get commonSelectAll;

  /// No description provided for @commonDeselectAll.
  ///
  /// In sv, this message translates to:
  /// **'Avmarkera alla'**
  String get commonDeselectAll;

  /// No description provided for @commonInvertSelection.
  ///
  /// In sv, this message translates to:
  /// **'Invertera'**
  String get commonInvertSelection;

  /// No description provided for @commonAddWithLabel.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till {label}'**
  String commonAddWithLabel(String label);

  /// No description provided for @commonClearAll.
  ///
  /// In sv, this message translates to:
  /// **'Rensa alla'**
  String get commonClearAll;

  /// No description provided for @commonClear.
  ///
  /// In sv, this message translates to:
  /// **'Rensa'**
  String get commonClear;

  /// No description provided for @commonImage.
  ///
  /// In sv, this message translates to:
  /// **'Bild'**
  String get commonImage;

  /// No description provided for @commonSettings.
  ///
  /// In sv, this message translates to:
  /// **'Inställningar'**
  String get commonSettings;

  /// No description provided for @commonLogout.
  ///
  /// In sv, this message translates to:
  /// **'Logga ut'**
  String get commonLogout;

  /// No description provided for @commonLogoutNow.
  ///
  /// In sv, this message translates to:
  /// **'Logga ut nu'**
  String get commonLogoutNow;

  /// No description provided for @commonNoAccess.
  ///
  /// In sv, this message translates to:
  /// **'Ingen åtkomst'**
  String get commonNoAccess;

  /// No description provided for @commonCreatingCopy.
  ///
  /// In sv, this message translates to:
  /// **'Skapar kopia...'**
  String get commonCreatingCopy;

  /// No description provided for @commonToHome.
  ///
  /// In sv, this message translates to:
  /// **'Till start'**
  String get commonToHome;

  /// No description provided for @commonTakePhoto.
  ///
  /// In sv, this message translates to:
  /// **'Ta foto'**
  String get commonTakePhoto;

  /// No description provided for @commonSelectFromGallery.
  ///
  /// In sv, this message translates to:
  /// **'Välj från galleri'**
  String get commonSelectFromGallery;

  /// No description provided for @commonSelectFriends.
  ///
  /// In sv, this message translates to:
  /// **'Välj vänner'**
  String get commonSelectFriends;

  /// No description provided for @commonNoContent.
  ///
  /// In sv, this message translates to:
  /// **'Inget innehåll'**
  String get commonNoContent;

  /// No description provided for @commonRemoveLabel.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort {label}'**
  String commonRemoveLabel(String label);

  /// No description provided for @personalTagsViewTitle.
  ///
  /// In sv, this message translates to:
  /// **'Personliga taggar'**
  String get personalTagsViewTitle;

  /// No description provided for @personalTagCreateTag.
  ///
  /// In sv, this message translates to:
  /// **'Skapa tagg'**
  String get personalTagCreateTag;

  /// No description provided for @personalTagCreateGroup.
  ///
  /// In sv, this message translates to:
  /// **'Skapa grupp'**
  String get personalTagCreateGroup;

  /// No description provided for @personalTagEmptyTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inga personliga taggar'**
  String get personalTagEmptyTitle;

  /// No description provided for @personalTagEmptySubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Skapa taggar för att organisera dina recept'**
  String get personalTagEmptySubtitle;

  /// No description provided for @personalTagSectionTags.
  ///
  /// In sv, this message translates to:
  /// **'Taggar'**
  String get personalTagSectionTags;

  /// No description provided for @personalTagDeleteGroup.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort grupp'**
  String get personalTagDeleteGroup;

  /// No description provided for @personalTagGroupEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Inga taggar i denna grupp'**
  String get personalTagGroupEmpty;

  /// No description provided for @personalTagRecipeCount.
  ///
  /// In sv, this message translates to:
  /// **'{count, plural, =1{1 recept} other{{count} recept}}'**
  String personalTagRecipeCount(int count);

  /// No description provided for @personalTagRuleCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} regler'**
  String personalTagRuleCount(int count);

  /// No description provided for @personalTagRuleCountActive.
  ///
  /// In sv, this message translates to:
  /// **'{enabled}/{total} regler aktiva'**
  String personalTagRuleCountActive(int enabled, int total);

  /// No description provided for @personalTagNoUsage.
  ///
  /// In sv, this message translates to:
  /// **'Ingen användning'**
  String get personalTagNoUsage;

  /// No description provided for @personalTagEnableAllRules.
  ///
  /// In sv, this message translates to:
  /// **'Aktivera alla regler'**
  String get personalTagEnableAllRules;

  /// No description provided for @personalTagDisableAllRules.
  ///
  /// In sv, this message translates to:
  /// **'Inaktivera alla regler'**
  String get personalTagDisableAllRules;

  /// No description provided for @personalTagRulesDisabled.
  ///
  /// In sv, this message translates to:
  /// **'{count} regler inaktiverade'**
  String personalTagRulesDisabled(int count);

  /// No description provided for @personalTagRulesActive.
  ///
  /// In sv, this message translates to:
  /// **'{count} regler aktiva'**
  String personalTagRulesActive(int count);

  /// No description provided for @personalTagMoveToGroup.
  ///
  /// In sv, this message translates to:
  /// **'Flytta till grupp'**
  String get personalTagMoveToGroup;

  /// No description provided for @personalTagDeleteTag.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort tagg'**
  String get personalTagDeleteTag;

  /// No description provided for @personalTagEnableAllRulesConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Aktivera alla regler?'**
  String get personalTagEnableAllRulesConfirm;

  /// No description provided for @personalTagDisableAllRulesConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Inaktivera alla regler?'**
  String get personalTagDisableAllRulesConfirm;

  /// No description provided for @personalTagEnableAllRulesMessage.
  ///
  /// In sv, this message translates to:
  /// **'Alla {count} regler för \"{name}\" kommer att aktiveras.'**
  String personalTagEnableAllRulesMessage(int count, String name);

  /// No description provided for @personalTagDisableAllRulesMessage.
  ///
  /// In sv, this message translates to:
  /// **'Alla {count} regler för \"{name}\" kommer att inaktiveras.'**
  String personalTagDisableAllRulesMessage(int count, String name);

  /// No description provided for @personalTagAllRulesEnabled.
  ///
  /// In sv, this message translates to:
  /// **'Alla regler aktiverade'**
  String get personalTagAllRulesEnabled;

  /// No description provided for @personalTagAllRulesDisabled.
  ///
  /// In sv, this message translates to:
  /// **'Alla regler inaktiverade'**
  String get personalTagAllRulesDisabled;

  /// No description provided for @personalTagCouldNotChangeRules.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ändra reglerna'**
  String get personalTagCouldNotChangeRules;

  /// No description provided for @personalTagNameLabel.
  ///
  /// In sv, this message translates to:
  /// **'Taggnamn'**
  String get personalTagNameLabel;

  /// No description provided for @personalTagNameHint.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. Favoriter'**
  String get personalTagNameHint;

  /// No description provided for @personalTagCreated.
  ///
  /// In sv, this message translates to:
  /// **'Tagg skapad'**
  String get personalTagCreated;

  /// No description provided for @personalTagCouldNotCreate.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa taggen'**
  String get personalTagCouldNotCreate;

  /// No description provided for @personalTagGroupNameLabel.
  ///
  /// In sv, this message translates to:
  /// **'Gruppnamn'**
  String get personalTagGroupNameLabel;

  /// No description provided for @personalTagGroupNameHint.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. Middagar'**
  String get personalTagGroupNameHint;

  /// No description provided for @personalTagGroupCreated.
  ///
  /// In sv, this message translates to:
  /// **'Grupp skapad'**
  String get personalTagGroupCreated;

  /// No description provided for @personalTagCouldNotCreateGroup.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa gruppen'**
  String get personalTagCouldNotCreateGroup;

  /// No description provided for @personalTagEditTag.
  ///
  /// In sv, this message translates to:
  /// **'Redigera tagg'**
  String get personalTagEditTag;

  /// No description provided for @personalTagUpdated.
  ///
  /// In sv, this message translates to:
  /// **'Tagg uppdaterad'**
  String get personalTagUpdated;

  /// No description provided for @personalTagDeleteTagConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort tagg?'**
  String get personalTagDeleteTagConfirm;

  /// No description provided for @personalTagDeleteTagMessage.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill ta bort \"{name}\"? Taggen tas bort från alla recept.'**
  String personalTagDeleteTagMessage(String name);

  /// No description provided for @personalTagDeleted.
  ///
  /// In sv, this message translates to:
  /// **'Tagg borttagen'**
  String get personalTagDeleted;

  /// No description provided for @personalTagNoGroup.
  ///
  /// In sv, this message translates to:
  /// **'Ingen grupp'**
  String get personalTagNoGroup;

  /// No description provided for @personalTagCreateNewGroup.
  ///
  /// In sv, this message translates to:
  /// **'Skapa ny grupp'**
  String get personalTagCreateNewGroup;

  /// No description provided for @personalTagMoved.
  ///
  /// In sv, this message translates to:
  /// **'Tagg flyttad'**
  String get personalTagMoved;

  /// No description provided for @personalTagGroupCreatedAndTagMoved.
  ///
  /// In sv, this message translates to:
  /// **'Grupp skapad och tagg flyttad'**
  String get personalTagGroupCreatedAndTagMoved;

  /// No description provided for @personalTagRenameGroup.
  ///
  /// In sv, this message translates to:
  /// **'Byt namn på grupp'**
  String get personalTagRenameGroup;

  /// No description provided for @personalTagGroupUpdated.
  ///
  /// In sv, this message translates to:
  /// **'Grupp uppdaterad'**
  String get personalTagGroupUpdated;

  /// No description provided for @personalTagDeleteGroupConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort grupp?'**
  String get personalTagDeleteGroupConfirm;

  /// No description provided for @personalTagDeleteGroupMessage.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill ta bort \"{name}\"? Taggar i gruppen blir ogrupperade.'**
  String personalTagDeleteGroupMessage(String name);

  /// No description provided for @personalTagGroupDeleted.
  ///
  /// In sv, this message translates to:
  /// **'Grupp borttagen'**
  String get personalTagGroupDeleted;

  /// No description provided for @personalTagSortByName.
  ///
  /// In sv, this message translates to:
  /// **'Namn'**
  String get personalTagSortByName;

  /// No description provided for @personalTagSortByUsage.
  ///
  /// In sv, this message translates to:
  /// **'Användning'**
  String get personalTagSortByUsage;

  /// No description provided for @personalTagSortByRuleCount.
  ///
  /// In sv, this message translates to:
  /// **'Antal regler'**
  String get personalTagSortByRuleCount;

  /// No description provided for @personalTagTileSemantics.
  ///
  /// In sv, this message translates to:
  /// **'{name}, {count} recept, {enabled} av {total} regler aktiva'**
  String personalTagTileSemantics(
      String name, int count, int enabled, int total);

  /// No description provided for @tagDetailDefaultTitle.
  ///
  /// In sv, this message translates to:
  /// **'Tagg'**
  String get tagDetailDefaultTitle;

  /// No description provided for @tagDetailNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Taggen kunde inte hittas'**
  String get tagDetailNotFound;

  /// No description provided for @tagDetailEditTitle.
  ///
  /// In sv, this message translates to:
  /// **'Redigera tagg'**
  String get tagDetailEditTitle;

  /// No description provided for @tagDetailApplyRules.
  ///
  /// In sv, this message translates to:
  /// **'Kör regler'**
  String get tagDetailApplyRules;

  /// No description provided for @tagDetailApplyRulesSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Tillämpa på befintliga recept'**
  String get tagDetailApplyRulesSubtitle;

  /// No description provided for @tagDetailNameHint.
  ///
  /// In sv, this message translates to:
  /// **'Taggnamn'**
  String get tagDetailNameHint;

  /// No description provided for @tagDetailNameRequired.
  ///
  /// In sv, this message translates to:
  /// **'Taggnamn krävs'**
  String get tagDetailNameRequired;

  /// No description provided for @tagDetailUpdated.
  ///
  /// In sv, this message translates to:
  /// **'Tagg uppdaterad'**
  String get tagDetailUpdated;

  /// No description provided for @tagDetailCouldNotUpdate.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera taggen'**
  String get tagDetailCouldNotUpdate;

  /// No description provided for @tagDetailRuleCreated.
  ///
  /// In sv, this message translates to:
  /// **'Regel skapad'**
  String get tagDetailRuleCreated;

  /// No description provided for @tagDetailCouldNotCreateRule.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa regeln'**
  String get tagDetailCouldNotCreateRule;

  /// No description provided for @tagDetailRuleUpdated.
  ///
  /// In sv, this message translates to:
  /// **'Regel uppdaterad'**
  String get tagDetailRuleUpdated;

  /// No description provided for @tagDetailCouldNotUpdateRule.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera regeln'**
  String get tagDetailCouldNotUpdateRule;

  /// No description provided for @tagDetailCouldNotChangeRuleStatus.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ändra regelstatus'**
  String get tagDetailCouldNotChangeRuleStatus;

  /// No description provided for @tagDetailDeleteRuleConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort regel?'**
  String get tagDetailDeleteRuleConfirm;

  /// No description provided for @tagDetailDeleteRuleMessage.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill ta bort \"{name}\"?'**
  String tagDetailDeleteRuleMessage(String name);

  /// No description provided for @tagDetailRuleDeleted.
  ///
  /// In sv, this message translates to:
  /// **'Regel borttagen'**
  String get tagDetailRuleDeleted;

  /// No description provided for @tagDetailCouldNotDeleteRule.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort regeln'**
  String get tagDetailCouldNotDeleteRule;

  /// No description provided for @tagDetailApplyingRules.
  ///
  /// In sv, this message translates to:
  /// **'Kör regler på recept...'**
  String get tagDetailApplyingRules;

  /// No description provided for @tagDetailRulesAppliedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'{tagsApplied} taggar tillämpade på {recipesModified} recept'**
  String tagDetailRulesAppliedSuccess(int tagsApplied, int recipesModified);

  /// No description provided for @tagDetailNoRecipesMatched.
  ///
  /// In sv, this message translates to:
  /// **'Inga recept matchade reglerna'**
  String get tagDetailNoRecipesMatched;

  /// No description provided for @tagDetailCouldNotApplyRules.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte köra regler'**
  String get tagDetailCouldNotApplyRules;

  /// No description provided for @tagDetailDeleteTagConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort tagg?'**
  String get tagDetailDeleteTagConfirm;

  /// No description provided for @tagDetailDeleteTagMessage.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill ta bort \"{name}\"? Taggen tas bort från alla recept.'**
  String tagDetailDeleteTagMessage(String name);

  /// No description provided for @tagDetailDeleted.
  ///
  /// In sv, this message translates to:
  /// **'Tagg borttagen'**
  String get tagDetailDeleted;

  /// No description provided for @tagDetailCouldNotDelete.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort taggen'**
  String get tagDetailCouldNotDelete;

  /// No description provided for @tagDetailRecipeCount.
  ///
  /// In sv, this message translates to:
  /// **'{count, plural, =1{1 recept} other{{count} recept}}'**
  String tagDetailRecipeCount(int count);

  /// No description provided for @tagDetailRulesActive.
  ///
  /// In sv, this message translates to:
  /// **'{enabled}/{total} regler aktiva'**
  String tagDetailRulesActive(int enabled, int total);

  /// No description provided for @tagDetailRuleCalculating.
  ///
  /// In sv, this message translates to:
  /// **'Beräknar...'**
  String get tagDetailRuleCalculating;

  /// No description provided for @tagDetailRuleMatches.
  ///
  /// In sv, this message translates to:
  /// **'{count, plural, =1{1 recept matchar} other{{count} recept matchar}}'**
  String tagDetailRuleMatches(int count);

  /// No description provided for @tagDetailRuleNoConditions.
  ///
  /// In sv, this message translates to:
  /// **'Inga villkor'**
  String get tagDetailRuleNoConditions;

  /// No description provided for @tagDetailRuleOperatorAnd.
  ///
  /// In sv, this message translates to:
  /// **' OCH '**
  String get tagDetailRuleOperatorAnd;

  /// No description provided for @tagDetailRuleOperatorOr.
  ///
  /// In sv, this message translates to:
  /// **' ELLER '**
  String get tagDetailRuleOperatorOr;

  /// No description provided for @tagDetailRuleMoreConditions.
  ///
  /// In sv, this message translates to:
  /// **'(+{count} till)'**
  String tagDetailRuleMoreConditions(int count);

  /// No description provided for @tagDetailRulesDescription.
  ///
  /// In sv, this message translates to:
  /// **'Regler tillämpar taggen automatiskt på recept som matchar villkoren.'**
  String get tagDetailRulesDescription;

  /// No description provided for @tagDetailRulesTitle.
  ///
  /// In sv, this message translates to:
  /// **'Automatiseringsregler'**
  String get tagDetailRulesTitle;

  /// No description provided for @tagDetailRulesEmptyTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inga regler ännu'**
  String get tagDetailRulesEmptyTitle;

  /// No description provided for @tagDetailRulesEmptySubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Skapa regler för att automatiskt tagga recept'**
  String get tagDetailRulesEmptySubtitle;

  /// No description provided for @tagDetailRulesCreateFirst.
  ///
  /// In sv, this message translates to:
  /// **'Skapa första regeln'**
  String get tagDetailRulesCreateFirst;

  /// No description provided for @tagAlreadyExists.
  ///
  /// In sv, this message translates to:
  /// **'Taggen finns redan'**
  String get tagAlreadyExists;

  /// No description provided for @tagManageTags.
  ///
  /// In sv, this message translates to:
  /// **'Hantera taggar'**
  String get tagManageTags;

  /// No description provided for @tagActiveTags.
  ///
  /// In sv, this message translates to:
  /// **'Aktiva taggar'**
  String get tagActiveTags;

  /// No description provided for @tagRemovedTags.
  ///
  /// In sv, this message translates to:
  /// **'Borttagna taggar'**
  String get tagRemovedTags;

  /// No description provided for @tagAddNewTag.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till ny tagg'**
  String get tagAddNewTag;

  /// No description provided for @tagWriteTagHint.
  ///
  /// In sv, this message translates to:
  /// **'Skriv en tagg...'**
  String get tagWriteTagHint;

  /// No description provided for @tagEnterTag.
  ///
  /// In sv, this message translates to:
  /// **'Ange en tagg'**
  String get tagEnterTag;

  /// No description provided for @tagMinTwoChars.
  ///
  /// In sv, this message translates to:
  /// **'Minst 2 tecken'**
  String get tagMinTwoChars;

  /// No description provided for @tagAddTag.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till tagg'**
  String get tagAddTag;

  /// No description provided for @tagManuallyAdded.
  ///
  /// In sv, this message translates to:
  /// **'Manuellt tillagd'**
  String get tagManuallyAdded;

  /// No description provided for @tagAutoGenerated.
  ///
  /// In sv, this message translates to:
  /// **'Automatiskt genererad'**
  String get tagAutoGenerated;

  /// No description provided for @tagClickToRestore.
  ///
  /// In sv, this message translates to:
  /// **'Klicka för att återställa'**
  String get tagClickToRestore;

  /// No description provided for @allergenSettingsTitle.
  ///
  /// In sv, this message translates to:
  /// **'Allergeninställningar'**
  String get allergenSettingsTitle;

  /// No description provided for @allergenTrackAllergensTitle.
  ///
  /// In sv, this message translates to:
  /// **'Spåra allergener'**
  String get allergenTrackAllergensTitle;

  /// No description provided for @allergenTrackAllergensSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Välj vilka allergener du vill se status för på recept.'**
  String get allergenTrackAllergensSubtitle;

  /// No description provided for @allergenTrackDietaryTitle.
  ///
  /// In sv, this message translates to:
  /// **'Spåra specialkost'**
  String get allergenTrackDietaryTitle;

  /// No description provided for @allergenTrackDietarySubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Välj vilka kostpreferenser du vill se status för.'**
  String get allergenTrackDietarySubtitle;

  /// No description provided for @allergenDisplayTitle.
  ///
  /// In sv, this message translates to:
  /// **'Visa på'**
  String get allergenDisplayTitle;

  /// No description provided for @allergenDisplayOnCardsTitle.
  ///
  /// In sv, this message translates to:
  /// **'Receptkort'**
  String get allergenDisplayOnCardsTitle;

  /// No description provided for @allergenDisplayOnCardsSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Visa allergenstatus på receptkort i listor'**
  String get allergenDisplayOnCardsSubtitle;

  /// No description provided for @allergenDisplayOnDetailTitle.
  ///
  /// In sv, this message translates to:
  /// **'Receptdetaljer'**
  String get allergenDisplayOnDetailTitle;

  /// No description provided for @allergenDisplayOnDetailSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Visa fullständig allergenstatus på receptsidan'**
  String get allergenDisplayOnDetailSubtitle;

  /// No description provided for @allergenDisplayCoverageTitle.
  ///
  /// In sv, this message translates to:
  /// **'Täckningsindikator'**
  String get allergenDisplayCoverageTitle;

  /// No description provided for @allergenDisplayCoverageSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Visa hur stor andel ingredienser som är kända'**
  String get allergenDisplayCoverageSubtitle;

  /// No description provided for @allergenSaveSettings.
  ///
  /// In sv, this message translates to:
  /// **'Spara inställningar'**
  String get allergenSaveSettings;

  /// No description provided for @allergenResetToDefaults.
  ///
  /// In sv, this message translates to:
  /// **'Återställ till standard'**
  String get allergenResetToDefaults;

  /// No description provided for @allergenSettingsSaved.
  ///
  /// In sv, this message translates to:
  /// **'Inställningar sparade'**
  String get allergenSettingsSaved;

  /// No description provided for @allergenResetConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Återställ inställningar?'**
  String get allergenResetConfirm;

  /// No description provided for @allergenResetMessage.
  ///
  /// In sv, this message translates to:
  /// **'Detta återställer alla allergen- och kostpreferenser till standardvärden.'**
  String get allergenResetMessage;

  /// No description provided for @allergenReset.
  ///
  /// In sv, this message translates to:
  /// **'Återställ'**
  String get allergenReset;

  /// No description provided for @personalTagWizardAddRule.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till regel?'**
  String get personalTagWizardAddRule;

  /// No description provided for @personalTagWizardAddRuleMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du skapa en automatiseringsregel för \"{name}\"?\n\nRegler kan automatiskt lägga till denna tagg på recept baserat på ingredienser, källa, tid, med mera.'**
  String personalTagWizardAddRuleMessage(String name);

  /// No description provided for @personalTagWizardLater.
  ///
  /// In sv, this message translates to:
  /// **'Senare'**
  String get personalTagWizardLater;

  /// No description provided for @personalTagWizardYesCreateRule.
  ///
  /// In sv, this message translates to:
  /// **'Ja, skapa regel'**
  String get personalTagWizardYesCreateRule;

  /// No description provided for @personalTagPreview.
  ///
  /// In sv, this message translates to:
  /// **'Förhandsgranskning'**
  String get personalTagPreview;

  /// No description provided for @personalTagCouldNotLoad.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda taggar'**
  String get personalTagCouldNotLoad;

  /// No description provided for @personalTagManage.
  ///
  /// In sv, this message translates to:
  /// **'Hantera'**
  String get personalTagManage;

  /// No description provided for @personalTagChipSelectedA11y.
  ///
  /// In sv, this message translates to:
  /// **'{name}, vald. Dubbeltryck för att ta bort.'**
  String personalTagChipSelectedA11y(String name);

  /// No description provided for @personalTagChipUnselectedA11y.
  ///
  /// In sv, this message translates to:
  /// **'{name}. Dubbeltryck för att välja.'**
  String personalTagChipUnselectedA11y(String name);

  /// No description provided for @personalTagA11yLabel.
  ///
  /// In sv, this message translates to:
  /// **'Tagg: {name}'**
  String personalTagA11yLabel(String name);

  /// No description provided for @personalTagManagerTitle.
  ///
  /// In sv, this message translates to:
  /// **'Mina taggar'**
  String get personalTagManagerTitle;

  /// No description provided for @personalTagManagerRulesTab.
  ///
  /// In sv, this message translates to:
  /// **'Regler'**
  String get personalTagManagerRulesTab;

  /// No description provided for @personalTagNewTag.
  ///
  /// In sv, this message translates to:
  /// **'Ny tagg'**
  String get personalTagNewTag;

  /// No description provided for @personalTagCreateTagFirst.
  ///
  /// In sv, this message translates to:
  /// **'Skapa en tagg först'**
  String get personalTagCreateTagFirst;

  /// No description provided for @personalTagNeedTagForRules.
  ///
  /// In sv, this message translates to:
  /// **'Du behöver minst en tagg för att kunna skapa automationsregler.'**
  String get personalTagNeedTagForRules;

  /// No description provided for @personalTagCreatedDate.
  ///
  /// In sv, this message translates to:
  /// **'Skapad {date}'**
  String personalTagCreatedDate(String date);

  /// No description provided for @personalTagCreateRuleForTag.
  ///
  /// In sv, this message translates to:
  /// **'Skapa regel för tagg'**
  String get personalTagCreateRuleForTag;

  /// No description provided for @personalTagAddRule.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till regel'**
  String get personalTagAddRule;

  /// No description provided for @personalTagApplyRulesTitle.
  ///
  /// In sv, this message translates to:
  /// **'Kör regler på befintliga recept'**
  String get personalTagApplyRulesTitle;

  /// No description provided for @personalTagApplyRulesMessage.
  ///
  /// In sv, this message translates to:
  /// **'Detta kommer att granska alla dina recept och lägga till taggar enligt dina aktiverade regler.\n\nTaggar som redan finns på recept påverkas inte.'**
  String get personalTagApplyRulesMessage;

  /// No description provided for @personalTagApplyRulesRun.
  ///
  /// In sv, this message translates to:
  /// **'Kör'**
  String get personalTagApplyRulesRun;

  /// No description provided for @personalTagApplyRulesProgress.
  ///
  /// In sv, this message translates to:
  /// **'Bearbetar recept {progress} av {total}...'**
  String personalTagApplyRulesProgress(int progress, int total);

  /// No description provided for @personalTagApplyRulesFetching.
  ///
  /// In sv, this message translates to:
  /// **'Hämtar recept...'**
  String get personalTagApplyRulesFetching;

  /// No description provided for @personalTagSelectColor.
  ///
  /// In sv, this message translates to:
  /// **'Välj färg'**
  String get personalTagSelectColor;

  /// No description provided for @ruleEditTitle.
  ///
  /// In sv, this message translates to:
  /// **'Redigera regel'**
  String get ruleEditTitle;

  /// No description provided for @ruleCreateTitle.
  ///
  /// In sv, this message translates to:
  /// **'Skapa regel'**
  String get ruleCreateTitle;

  /// No description provided for @ruleNewTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ny regel'**
  String get ruleNewTitle;

  /// No description provided for @ruleNameLabel.
  ///
  /// In sv, this message translates to:
  /// **'Regelnamn'**
  String get ruleNameLabel;

  /// No description provided for @ruleNameHint.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. \"Fiskrecept\"'**
  String get ruleNameHint;

  /// No description provided for @ruleNameRequired.
  ///
  /// In sv, this message translates to:
  /// **'Ange ett regelnamn'**
  String get ruleNameRequired;

  /// No description provided for @ruleApplyToTag.
  ///
  /// In sv, this message translates to:
  /// **'Tillämpa på tagg'**
  String get ruleApplyToTag;

  /// No description provided for @ruleSelectTag.
  ///
  /// In sv, this message translates to:
  /// **'Välj en tagg'**
  String get ruleSelectTag;

  /// No description provided for @ruleMatchModeLabel.
  ///
  /// In sv, this message translates to:
  /// **'Matchningsläge'**
  String get ruleMatchModeLabel;

  /// No description provided for @ruleMatchModeAllConditions.
  ///
  /// In sv, this message translates to:
  /// **'Alla villkor (AND)'**
  String get ruleMatchModeAllConditions;

  /// No description provided for @ruleMatchModeAnyCondition.
  ///
  /// In sv, this message translates to:
  /// **'Något villkor (OR)'**
  String get ruleMatchModeAnyCondition;

  /// No description provided for @ruleMatchModeAllShort.
  ///
  /// In sv, this message translates to:
  /// **'Alla (AND)'**
  String get ruleMatchModeAllShort;

  /// No description provided for @ruleMatchModeAnyShort.
  ///
  /// In sv, this message translates to:
  /// **'Något (OR)'**
  String get ruleMatchModeAnyShort;

  /// No description provided for @ruleMatchModeAll.
  ///
  /// In sv, this message translates to:
  /// **'alla'**
  String get ruleMatchModeAll;

  /// No description provided for @ruleMatchModeAny.
  ///
  /// In sv, this message translates to:
  /// **'något'**
  String get ruleMatchModeAny;

  /// No description provided for @ruleConditionsLabel.
  ///
  /// In sv, this message translates to:
  /// **'Villkor'**
  String get ruleConditionsLabel;

  /// No description provided for @ruleConditionCountSingular.
  ///
  /// In sv, this message translates to:
  /// **'1 villkor'**
  String get ruleConditionCountSingular;

  /// No description provided for @ruleConditionCountWithMode.
  ///
  /// In sv, this message translates to:
  /// **'{count} villkor, {mode} måste matcha'**
  String ruleConditionCountWithMode(int count, String mode);

  /// No description provided for @ruleEnabledTitle.
  ///
  /// In sv, this message translates to:
  /// **'Regel aktiverad'**
  String get ruleEnabledTitle;

  /// No description provided for @ruleEnabledSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Regeln tillämpas på recept'**
  String get ruleEnabledSubtitle;

  /// No description provided for @ruleEnabledNewRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Regeln tillämpas på nya recept'**
  String get ruleEnabledNewRecipes;

  /// No description provided for @rulePausedSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Regeln är pausad'**
  String get rulePausedSubtitle;

  /// No description provided for @ruleApplyToExisting.
  ///
  /// In sv, this message translates to:
  /// **'Applicera på befintliga recept'**
  String get ruleApplyToExisting;

  /// No description provided for @ruleTagMatchingImmediately.
  ///
  /// In sv, this message translates to:
  /// **'Tagga matchande recept omedelbart'**
  String get ruleTagMatchingImmediately;

  /// No description provided for @ruleRemoveCondition.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort villkor'**
  String get ruleRemoveCondition;

  /// No description provided for @ruleSelectProperty.
  ///
  /// In sv, this message translates to:
  /// **'Välj egenskap...'**
  String get ruleSelectProperty;

  /// No description provided for @ruleAllConditionsNeedValue.
  ///
  /// In sv, this message translates to:
  /// **'Alla villkor måste ha ett värde'**
  String get ruleAllConditionsNeedValue;

  /// No description provided for @ruleHintIngredient.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. \"kyckling\", \"lax\"'**
  String get ruleHintIngredient;

  /// No description provided for @ruleHintProperty.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. \"seafood\", \"meat\", \"dairy\"'**
  String get ruleHintProperty;

  /// No description provided for @ruleHintKeyword.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. \"snabb\", \"vegetarisk\"'**
  String get ruleHintKeyword;

  /// No description provided for @ruleHintSourceUrl.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. \"bbc.com\", \"reddit.com\"'**
  String get ruleHintSourceUrl;

  /// No description provided for @ruleHintCuisine.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. \"italian\", \"asian\"'**
  String get ruleHintCuisine;

  /// No description provided for @ruleHintDietary.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. \"vegetarian\", \"vegan\"'**
  String get ruleHintDietary;

  /// No description provided for @ruleHintTime.
  ///
  /// In sv, this message translates to:
  /// **'Tillagningstid i minuter'**
  String get ruleHintTime;

  /// No description provided for @ruleHintTimeShort.
  ///
  /// In sv, this message translates to:
  /// **'Tid i minuter'**
  String get ruleHintTimeShort;

  /// No description provided for @ruleHintRating.
  ///
  /// In sv, this message translates to:
  /// **'Betyg (1-5)'**
  String get ruleHintRating;

  /// No description provided for @ruleHintRecency.
  ///
  /// In sv, this message translates to:
  /// **'Antal dagar sedan receptet lades till'**
  String get ruleHintRecency;

  /// No description provided for @ruleHintRecencyShort.
  ///
  /// In sv, this message translates to:
  /// **'Antal dagar'**
  String get ruleHintRecencyShort;

  /// No description provided for @ruleHintOwnership.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. \"personal\", \"shared\", \"collaborative\"'**
  String get ruleHintOwnership;

  /// No description provided for @ruleHintHasImage.
  ///
  /// In sv, this message translates to:
  /// **'true eller false'**
  String get ruleHintHasImage;

  /// No description provided for @ruleHintCompleteness.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. \"description\", \"ingredients\"'**
  String get ruleHintCompleteness;

  /// No description provided for @ruleCategoryAllergens.
  ///
  /// In sv, this message translates to:
  /// **'Allergener'**
  String get ruleCategoryAllergens;

  /// No description provided for @ruleCategoryLactose.
  ///
  /// In sv, this message translates to:
  /// **'Laktos'**
  String get ruleCategoryLactose;

  /// No description provided for @ruleCategoryMeat.
  ///
  /// In sv, this message translates to:
  /// **'Kött'**
  String get ruleCategoryMeat;

  /// No description provided for @ruleCategorySeafood.
  ///
  /// In sv, this message translates to:
  /// **'Fisk & skaldjur'**
  String get ruleCategorySeafood;

  /// No description provided for @ruleCategoryAnimal.
  ///
  /// In sv, this message translates to:
  /// **'Animaliskt'**
  String get ruleCategoryAnimal;

  /// No description provided for @ruleCategoryDiet.
  ///
  /// In sv, this message translates to:
  /// **'Kost'**
  String get ruleCategoryDiet;

  /// No description provided for @ruleCategoryOther.
  ///
  /// In sv, this message translates to:
  /// **'Övrigt'**
  String get ruleCategoryOther;

  /// No description provided for @tagResultNoAllergens.
  ///
  /// In sv, this message translates to:
  /// **'Inga allergener att visa'**
  String get tagResultNoAllergens;

  /// No description provided for @tagResultOutdated.
  ///
  /// In sv, this message translates to:
  /// **'Taggarna kan uppdateras'**
  String get tagResultOutdated;

  /// No description provided for @tagResultCoverage.
  ///
  /// In sv, this message translates to:
  /// **'Täckning'**
  String get tagResultCoverage;

  /// No description provided for @tagResultUnknownIngredients.
  ///
  /// In sv, this message translates to:
  /// **'{count} okända ingredienser'**
  String tagResultUnknownIngredients(int count);

  /// No description provided for @tagResultUnknownIngredientsA11y.
  ///
  /// In sv, this message translates to:
  /// **'{count} okända ingredienser'**
  String tagResultUnknownIngredientsA11y(int count);

  /// No description provided for @dietaryStatusFreeA11y.
  ///
  /// In sv, this message translates to:
  /// **'Passar för {name} kost'**
  String dietaryStatusFreeA11y(String name);

  /// No description provided for @dietaryStatusContainsA11y.
  ///
  /// In sv, this message translates to:
  /// **'Passar ej för {name} kost'**
  String dietaryStatusContainsA11y(String name);

  /// No description provided for @dietaryStatusUnknownA11y.
  ///
  /// In sv, this message translates to:
  /// **'{name} status okänd'**
  String dietaryStatusUnknownA11y(String name);

  /// No description provided for @dietaryStatusNotLabel.
  ///
  /// In sv, this message translates to:
  /// **'Ej {name}'**
  String dietaryStatusNotLabel(String name);

  /// No description provided for @allergenStatusFreeA11y.
  ///
  /// In sv, this message translates to:
  /// **'Fri från {name}'**
  String allergenStatusFreeA11y(String name);

  /// No description provided for @allergenStatusContainsA11y.
  ///
  /// In sv, this message translates to:
  /// **'Innehåller {name}'**
  String allergenStatusContainsA11y(String name);

  /// No description provided for @allergenStatusUnknownA11y.
  ///
  /// In sv, this message translates to:
  /// **'{name} status okänd'**
  String allergenStatusUnknownA11y(String name);

  /// No description provided for @allergenFreeLabel.
  ///
  /// In sv, this message translates to:
  /// **'{name}fri'**
  String allergenFreeLabel(String name);

  /// No description provided for @allergenContainsLabel.
  ///
  /// In sv, this message translates to:
  /// **'innehåller {name}'**
  String allergenContainsLabel(String name);

  /// No description provided for @allergenUnknownLabel.
  ///
  /// In sv, this message translates to:
  /// **'{name} okänd'**
  String allergenUnknownLabel(String name);

  /// No description provided for @friendMemberCount.
  ///
  /// In sv, this message translates to:
  /// **'{count, plural, =1{1 medlem} other{{count} medlemmar}}'**
  String friendMemberCount(int count);

  /// No description provided for @friendCategoryLabel.
  ///
  /// In sv, this message translates to:
  /// **'Kategori'**
  String get friendCategoryLabel;

  /// No description provided for @friendCategoryStatistics.
  ///
  /// In sv, this message translates to:
  /// **'Kategoristatistik'**
  String get friendCategoryStatistics;

  /// No description provided for @friendCategories.
  ///
  /// In sv, this message translates to:
  /// **'Kategorier'**
  String get friendCategories;

  /// No description provided for @friendTotalMembers.
  ///
  /// In sv, this message translates to:
  /// **'Totalt medlemmar'**
  String get friendTotalMembers;

  /// No description provided for @friendAverage.
  ///
  /// In sv, this message translates to:
  /// **'Genomsnitt'**
  String get friendAverage;

  /// No description provided for @friendLargestCategory.
  ///
  /// In sv, this message translates to:
  /// **'Största kategori: {name} ({count} medlemmar)'**
  String friendLargestCategory(String name, int count);

  /// No description provided for @friendCategoryCount.
  ///
  /// In sv, this message translates to:
  /// **'{count, plural, =1{1 kategori} other{{count} kategorier}}'**
  String friendCategoryCount(int count);

  /// No description provided for @friendTotalMembersCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} totalt medlemmar'**
  String friendTotalMembersCount(int count);

  /// No description provided for @friendCreateFirstCategory.
  ///
  /// In sv, this message translates to:
  /// **'Skapa din första vänkategori'**
  String get friendCreateFirstCategory;

  /// No description provided for @friendCreateCategory.
  ///
  /// In sv, this message translates to:
  /// **'Skapa kategori'**
  String get friendCreateCategory;

  /// No description provided for @friendSelectCategories.
  ///
  /// In sv, this message translates to:
  /// **'Välj kategorier'**
  String get friendSelectCategories;

  /// No description provided for @friendCreateNewCategory.
  ///
  /// In sv, this message translates to:
  /// **'Skapa ny kategori'**
  String get friendCreateNewCategory;

  /// No description provided for @friendSelectedCategories.
  ///
  /// In sv, this message translates to:
  /// **'Valda kategorier'**
  String get friendSelectedCategories;

  /// No description provided for @friendSelectedCategoriesSummary.
  ///
  /// In sv, this message translates to:
  /// **'{count, plural, =1{1 kategori} other{{count} kategorier}} ({friends} vänner)'**
  String friendSelectedCategoriesSummary(int count, int friends);

  /// No description provided for @friendCategoriesSelected.
  ///
  /// In sv, this message translates to:
  /// **'{count} kategorier valda'**
  String friendCategoriesSelected(int count);

  /// No description provided for @friendFriendsCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} vänner'**
  String friendFriendsCount(int count);

  /// No description provided for @friendFriendsLabel.
  ///
  /// In sv, this message translates to:
  /// **'vänner'**
  String get friendFriendsLabel;

  /// No description provided for @friendLoadingFriendsAndCategories.
  ///
  /// In sv, this message translates to:
  /// **'Laddar vänner och kategorier...'**
  String get friendLoadingFriendsAndCategories;

  /// No description provided for @friendNoFriendsOrCategories.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner eller kategorier'**
  String get friendNoFriendsOrCategories;

  /// No description provided for @friendAddFriendsAndCategoriesFirst.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vänner och skapa kategorier först'**
  String get friendAddFriendsAndCategoriesFirst;

  /// No description provided for @friendManageFriends.
  ///
  /// In sv, this message translates to:
  /// **'Hantera vänner'**
  String get friendManageFriends;

  /// No description provided for @friendSelectCategoriesOrFriends.
  ///
  /// In sv, this message translates to:
  /// **'Välj kategorier eller individuella vänner'**
  String get friendSelectCategoriesOrFriends;

  /// No description provided for @friendSelectCategoriesForQuickShare.
  ///
  /// In sv, this message translates to:
  /// **'Välj hela kategorier för snabb delning'**
  String get friendSelectCategoriesForQuickShare;

  /// No description provided for @friendIndividualSelection.
  ///
  /// In sv, this message translates to:
  /// **'Individuellt val'**
  String get friendIndividualSelection;

  /// No description provided for @friendSelectSpecificFriends.
  ///
  /// In sv, this message translates to:
  /// **'Välj specifika vänner från din vänlista'**
  String get friendSelectSpecificFriends;

  /// No description provided for @friendNoFriendsToShow.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner att visa'**
  String get friendNoFriendsToShow;

  /// No description provided for @friendAddFriendsFirst.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vänner först'**
  String get friendAddFriendsFirst;

  /// No description provided for @friendSelectedFriends.
  ///
  /// In sv, this message translates to:
  /// **'Valda vänner'**
  String get friendSelectedFriends;

  /// No description provided for @friendSelectedCount.
  ///
  /// In sv, this message translates to:
  /// **'{count, plural, =1{1 vän vald} other{{count} vänner valda}}'**
  String friendSelectedCount(int count);

  /// No description provided for @shoppingItemsWillBeRemoved.
  ///
  /// In sv, this message translates to:
  /// **'{count} artiklar försvinner.'**
  String shoppingItemsWillBeRemoved(int count);

  /// No description provided for @shoppingItemsFromMenuIn.
  ///
  /// In sv, this message translates to:
  /// **'{count} artiklar från menyn i \"{name}\"'**
  String shoppingItemsFromMenuIn(int count, String name);

  /// No description provided for @shoppingItemHint.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. Mjölk'**
  String get shoppingItemHint;

  /// No description provided for @shoppingItems.
  ///
  /// In sv, this message translates to:
  /// **'artiklar'**
  String get shoppingItems;

  /// No description provided for @shoppingPersonal.
  ///
  /// In sv, this message translates to:
  /// **'Personlig'**
  String get shoppingPersonal;

  /// No description provided for @shoppingShared.
  ///
  /// In sv, this message translates to:
  /// **'Delad'**
  String get shoppingShared;

  /// No description provided for @shoppingTemplate.
  ///
  /// In sv, this message translates to:
  /// **'Mall'**
  String get shoppingTemplate;

  /// No description provided for @shoppingActive.
  ///
  /// In sv, this message translates to:
  /// **'Aktiv'**
  String get shoppingActive;

  /// No description provided for @shoppingRecentItems.
  ///
  /// In sv, this message translates to:
  /// **'Senaste artiklar:'**
  String get shoppingRecentItems;

  /// No description provided for @shoppingAndMore.
  ///
  /// In sv, this message translates to:
  /// **'... och {count} till'**
  String shoppingAndMore(int count);

  /// No description provided for @shoppingOwner.
  ///
  /// In sv, this message translates to:
  /// **'Ägare'**
  String get shoppingOwner;

  /// No description provided for @shoppingCanView.
  ///
  /// In sv, this message translates to:
  /// **'Kan se'**
  String get shoppingCanView;

  /// No description provided for @shoppingCanEdit.
  ///
  /// In sv, this message translates to:
  /// **'Kan redigera'**
  String get shoppingCanEdit;

  /// No description provided for @shoppingAdmin.
  ///
  /// In sv, this message translates to:
  /// **'Admin'**
  String get shoppingAdmin;

  /// No description provided for @shoppingCreateFirstList.
  ///
  /// In sv, this message translates to:
  /// **'Skapa din första inköpslista...'**
  String get shoppingCreateFirstList;

  /// No description provided for @shoppingCreateListButton.
  ///
  /// In sv, this message translates to:
  /// **'Skapa lista'**
  String get shoppingCreateListButton;

  /// No description provided for @shoppingPreviewAndEditItems.
  ///
  /// In sv, this message translates to:
  /// **'Förhandsgranska och redigera artiklar'**
  String get shoppingPreviewAndEditItems;

  /// No description provided for @shoppingNoItemsSelected.
  ///
  /// In sv, this message translates to:
  /// **'Inga artiklar valda'**
  String get shoppingNoItemsSelected;

  /// No description provided for @shoppingAllItemsRemovedFromMenu.
  ///
  /// In sv, this message translates to:
  /// **'Du har tagit bort alla artiklar från menyn'**
  String get shoppingAllItemsRemovedFromMenu;

  /// No description provided for @shoppingRemoveItem.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort artikel'**
  String get shoppingRemoveItem;

  /// No description provided for @shoppingRemoveAll.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort alla'**
  String get shoppingRemoveAll;

  /// No description provided for @shoppingToListWithCount.
  ///
  /// In sv, this message translates to:
  /// **'Till \"{name}\" ({count})'**
  String shoppingToListWithCount(String name, int count);

  /// No description provided for @shoppingLoadingLists.
  ///
  /// In sv, this message translates to:
  /// **'Laddar listor...'**
  String get shoppingLoadingLists;

  /// No description provided for @shoppingErrorLoading.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid laddning'**
  String get shoppingErrorLoading;

  /// No description provided for @shoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslistor'**
  String get shoppingLists;

  /// No description provided for @shoppingNewList.
  ///
  /// In sv, this message translates to:
  /// **'Ny lista'**
  String get shoppingNewList;

  /// No description provided for @shoppingAddFromMenu.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till från meny'**
  String get shoppingAddFromMenu;

  /// No description provided for @shoppingNoItemsFromMenu.
  ///
  /// In sv, this message translates to:
  /// **'Inga artiklar valda från menyn'**
  String get shoppingNoItemsFromMenu;

  /// No description provided for @shoppingAddItemsCount.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till {count} artiklar...'**
  String shoppingAddItemsCount(int count);

  /// No description provided for @shoppingPreview.
  ///
  /// In sv, this message translates to:
  /// **'Förhandsgranska'**
  String get shoppingPreview;

  /// No description provided for @shoppingAdding.
  ///
  /// In sv, this message translates to:
  /// **'Lägger till...'**
  String get shoppingAdding;

  /// No description provided for @shoppingNoItemsToAdd.
  ///
  /// In sv, this message translates to:
  /// **'Inga artiklar att lägga till'**
  String get shoppingNoItemsToAdd;

  /// No description provided for @shoppingListCreated.
  ///
  /// In sv, this message translates to:
  /// **'Lista \"{name}\" skapad'**
  String shoppingListCreated(String name);

  /// No description provided for @shoppingCouldNotCreateList.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa lista: {error}'**
  String shoppingCouldNotCreateList(String error);

  /// No description provided for @shoppingItemsAddedToList.
  ///
  /// In sv, this message translates to:
  /// **'{count} artiklar tillagda i \"{name}\"'**
  String shoppingItemsAddedToList(int count, String name);

  /// No description provided for @shoppingCouldNotAddItems.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lägga till artiklar: {error}'**
  String shoppingCouldNotAddItems(String error);

  /// No description provided for @profileSocialFeatures.
  ///
  /// In sv, this message translates to:
  /// **'Sociala funktioner'**
  String get profileSocialFeatures;

  /// No description provided for @profileEditProfile.
  ///
  /// In sv, this message translates to:
  /// **'Redigera profil'**
  String get profileEditProfile;

  /// No description provided for @profileEditProfileSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Uppdatera ditt namn och profilbild'**
  String get profileEditProfileSubtitle;

  /// No description provided for @profileFriendsAndGroups.
  ///
  /// In sv, this message translates to:
  /// **'Vänner och grupper'**
  String get profileFriendsAndGroups;

  /// No description provided for @profileFriendsAndGroupsSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Hantera dina vänner och grupper'**
  String get profileFriendsAndGroupsSubtitle;

  /// No description provided for @profileSharedWithMe.
  ///
  /// In sv, this message translates to:
  /// **'Delat med mig'**
  String get profileSharedWithMe;

  /// No description provided for @profileSharedWithMeSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Recept och menyer som delats med dig'**
  String get profileSharedWithMeSubtitle;

  /// No description provided for @profileMessages.
  ///
  /// In sv, this message translates to:
  /// **'Meddelanden'**
  String get profileMessages;

  /// No description provided for @profileMessagesSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Dina konversationer och meddelanden'**
  String get profileMessagesSubtitle;

  /// No description provided for @profileAllergenSettings.
  ///
  /// In sv, this message translates to:
  /// **'Allergeninställningar'**
  String get profileAllergenSettings;

  /// No description provided for @profileAllergenSettingsSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Välj vilka allergener du vill spåra'**
  String get profileAllergenSettingsSubtitle;

  /// No description provided for @profileMyTags.
  ///
  /// In sv, this message translates to:
  /// **'Mina taggar'**
  String get profileMyTags;

  /// No description provided for @profileMyTagsSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Hantera dina personliga taggar'**
  String get profileMyTagsSubtitle;

  /// No description provided for @profileCloseMenu.
  ///
  /// In sv, this message translates to:
  /// **'Stäng profilmeny'**
  String get profileCloseMenu;

  /// No description provided for @profileRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Recept'**
  String get profileRecipes;

  /// No description provided for @profileMenus.
  ///
  /// In sv, this message translates to:
  /// **'Menyer'**
  String get profileMenus;

  /// No description provided for @profileFriends.
  ///
  /// In sv, this message translates to:
  /// **'Vänner'**
  String get profileFriends;

  /// No description provided for @profileDataAndBackup.
  ///
  /// In sv, this message translates to:
  /// **'Data & Backup'**
  String get profileDataAndBackup;

  /// No description provided for @profileDownloadBackup.
  ///
  /// In sv, this message translates to:
  /// **'Ladda ner backup'**
  String get profileDownloadBackup;

  /// No description provided for @profileDownloadBackupSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Spara alla recept som JSON'**
  String get profileDownloadBackupSubtitle;

  /// No description provided for @profileRestoreFromBackup.
  ///
  /// In sv, this message translates to:
  /// **'Återställ från backup'**
  String get profileRestoreFromBackup;

  /// No description provided for @profileRestoreFromBackupSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Importera recept från JSON'**
  String get profileRestoreFromBackupSubtitle;

  /// No description provided for @profileAccountManagement.
  ///
  /// In sv, this message translates to:
  /// **'Kontohantering'**
  String get profileAccountManagement;

  /// No description provided for @profilePrivacyPolicy.
  ///
  /// In sv, this message translates to:
  /// **'Integritetspolicy'**
  String get profilePrivacyPolicy;

  /// No description provided for @profilePrivacyPolicySubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Läs om hur vi hanterar dina personuppgifter (GDPR)'**
  String get profilePrivacyPolicySubtitle;

  /// No description provided for @profileManageConsents.
  ///
  /// In sv, this message translates to:
  /// **'Hantera samtycken'**
  String get profileManageConsents;

  /// No description provided for @profileManageConsentsSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Välj hur vi får behandla dina personuppgifter (GDPR)'**
  String get profileManageConsentsSubtitle;

  /// No description provided for @profileExportMyData.
  ///
  /// In sv, this message translates to:
  /// **'Exportera mina data'**
  String get profileExportMyData;

  /// No description provided for @profileExportMyDataSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Ladda ner all din data i JSON-format (GDPR)'**
  String get profileExportMyDataSubtitle;

  /// No description provided for @profileDeleteAccountSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort ditt konto och all data permanent'**
  String get profileDeleteAccountSubtitle;

  /// No description provided for @profileLogoutFailed.
  ///
  /// In sv, this message translates to:
  /// **'Utloggning misslyckades: {error}'**
  String profileLogoutFailed(String error);

  /// No description provided for @profileAccountDeletedPermanently.
  ///
  /// In sv, this message translates to:
  /// **'Ditt konto har raderats permanent'**
  String get profileAccountDeletedPermanently;

  /// No description provided for @profileAccountCouldNotBeFullyDeleted.
  ///
  /// In sv, this message translates to:
  /// **'Kontot kunde inte raderas helt. Kontakta support.'**
  String get profileAccountCouldNotBeFullyDeleted;

  /// No description provided for @profileAuthenticationFailed.
  ///
  /// In sv, this message translates to:
  /// **'Autentisering misslyckades'**
  String get profileAuthenticationFailed;

  /// No description provided for @profileBackupFailed.
  ///
  /// In sv, this message translates to:
  /// **'Backup misslyckades: {error}'**
  String profileBackupFailed(String error);

  /// No description provided for @profileRestoreCompleted.
  ///
  /// In sv, this message translates to:
  /// **'Återställning genomförd!'**
  String get profileRestoreCompleted;

  /// No description provided for @profileRestoreFailed.
  ///
  /// In sv, this message translates to:
  /// **'Återställning misslyckades: {error}'**
  String profileRestoreFailed(String error);

  /// No description provided for @profileCouldNotOpenPrivacyPolicy.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte öppna integritetspolicy: {error}'**
  String profileCouldNotOpenPrivacyPolicy(String error);

  /// No description provided for @profileCouldNotOpenConsentManager.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte öppna samtyckeshantering: {error}'**
  String profileCouldNotOpenConsentManager(String error);

  /// No description provided for @profileCouldNotOpenDataExport.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte öppna dataexport: {error}'**
  String profileCouldNotOpenDataExport(String error);

  /// No description provided for @shareRecipeTitle.
  ///
  /// In sv, this message translates to:
  /// **'Dela recept'**
  String get shareRecipeTitle;

  /// No description provided for @shareMenuTitle.
  ///
  /// In sv, this message translates to:
  /// **'Dela meny'**
  String get shareMenuTitle;

  /// No description provided for @shareShoppingListTitle.
  ///
  /// In sv, this message translates to:
  /// **'Dela inköpslista'**
  String get shareShoppingListTitle;

  /// No description provided for @shareCreateAndShare.
  ///
  /// In sv, this message translates to:
  /// **'Skapa & Dela'**
  String get shareCreateAndShare;

  /// No description provided for @shareRecipeWithFriends.
  ///
  /// In sv, this message translates to:
  /// **'Dela recept med vänner'**
  String get shareRecipeWithFriends;

  /// No description provided for @shareMenuWithFriends.
  ///
  /// In sv, this message translates to:
  /// **'Dela veckomeny med vänner'**
  String get shareMenuWithFriends;

  /// No description provided for @shareShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Dela inköpslista'**
  String get shareShoppingList;

  /// No description provided for @shareCheckOutRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kolla in detta recept:'**
  String get shareCheckOutRecipe;

  /// No description provided for @shareCheckOutMenu.
  ///
  /// In sv, this message translates to:
  /// **'Kolla in denna veckomeny:'**
  String get shareCheckOutMenu;

  /// No description provided for @shareCheckOutShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Kolla in denna inköpslista:'**
  String get shareCheckOutShoppingList;

  /// No description provided for @shareRealtime.
  ///
  /// In sv, this message translates to:
  /// **'realtidsdelning'**
  String get shareRealtime;

  /// No description provided for @shareCopy.
  ///
  /// In sv, this message translates to:
  /// **'kopia'**
  String get shareCopy;

  /// No description provided for @shareSelectAtLeastOneFriend.
  ///
  /// In sv, this message translates to:
  /// **'Välj minst en vän för att dela'**
  String get shareSelectAtLeastOneFriend;

  /// No description provided for @shareSelected.
  ///
  /// In sv, this message translates to:
  /// **'valda'**
  String get shareSelected;

  /// No description provided for @shareRecipesInCategories.
  ///
  /// In sv, this message translates to:
  /// **'{recipes} recept i {categories} kategorier'**
  String shareRecipesInCategories(int recipes, int categories);

  /// No description provided for @shareNoFriendsToShareWith.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner att dela med'**
  String get shareNoFriendsToShareWith;

  /// No description provided for @shareAddFriendsToShare.
  ///
  /// In sv, this message translates to:
  /// **'Du behöver lägga till vänner för att kunna dela innehåll. Gå till din profil och lägg till vänner.'**
  String get shareAddFriendsToShare;

  /// No description provided for @shareAddFriends.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vänner'**
  String get shareAddFriends;

  /// No description provided for @shareErrorOccurred.
  ///
  /// In sv, this message translates to:
  /// **'Ett fel uppstod'**
  String get shareErrorOccurred;

  /// No description provided for @shareSucceeded.
  ///
  /// In sv, this message translates to:
  /// **'Delning lyckades!'**
  String get shareSucceeded;

  /// No description provided for @shareRecipes.
  ///
  /// In sv, this message translates to:
  /// **'recept'**
  String get shareRecipes;

  /// No description provided for @shareMenus.
  ///
  /// In sv, this message translates to:
  /// **'menyer'**
  String get shareMenus;

  /// No description provided for @shareShoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'inköpslistor'**
  String get shareShoppingLists;

  /// No description provided for @shareMessageOptional.
  ///
  /// In sv, this message translates to:
  /// **'Meddelande (valfritt)'**
  String get shareMessageOptional;

  /// No description provided for @shareWriteMessage.
  ///
  /// In sv, this message translates to:
  /// **'Skriv ett meddelande...'**
  String get shareWriteMessage;

  /// No description provided for @shareMethod.
  ///
  /// In sv, this message translates to:
  /// **'Delningssätt'**
  String get shareMethod;

  /// No description provided for @shareStaticCopy.
  ///
  /// In sv, this message translates to:
  /// **'Statisk kopia'**
  String get shareStaticCopy;

  /// No description provided for @shareStaticCopyDescription.
  ///
  /// In sv, this message translates to:
  /// **'Skicka en kopia som mottagaren kan ändra fritt'**
  String get shareStaticCopyDescription;

  /// No description provided for @shareRealtimeSharing.
  ///
  /// In sv, this message translates to:
  /// **'Realtidsdelning'**
  String get shareRealtimeSharing;

  /// No description provided for @shareRealtimeSharingDescription.
  ///
  /// In sv, this message translates to:
  /// **'Alla kan redigera tillsammans i realtid'**
  String get shareRealtimeSharingDescription;

  /// No description provided for @shareRealtimeShoppingDescription.
  ///
  /// In sv, this message translates to:
  /// **'Alla kan lägga till och checka av varor i realtid'**
  String get shareRealtimeShoppingDescription;

  /// No description provided for @shareSelectRecipients.
  ///
  /// In sv, this message translates to:
  /// **'Välj mottagare'**
  String get shareSelectRecipients;

  /// No description provided for @shareSearchFriends.
  ///
  /// In sv, this message translates to:
  /// **'Sök bland vänner...'**
  String get shareSearchFriends;

  /// No description provided for @shareSearchGroups.
  ///
  /// In sv, this message translates to:
  /// **'Sök bland grupper...'**
  String get shareSearchGroups;

  /// No description provided for @shareNoFriendsAvailable.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner tillgängliga'**
  String get shareNoFriendsAvailable;

  /// No description provided for @shareNoFriendsMatchedSearch.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner matchade din sökning'**
  String get shareNoFriendsMatchedSearch;

  /// No description provided for @shareNoGroupsAvailable.
  ///
  /// In sv, this message translates to:
  /// **'Inga grupper tillgängliga'**
  String get shareNoGroupsAvailable;

  /// No description provided for @shareNoGroupsMatchedSearch.
  ///
  /// In sv, this message translates to:
  /// **'Inga grupper matchade din sökning'**
  String get shareNoGroupsMatchedSearch;

  /// No description provided for @shareAlreadySharingList.
  ///
  /// In sv, this message translates to:
  /// **'Delar redan listan'**
  String get shareAlreadySharingList;

  /// No description provided for @menuSavedMenus.
  ///
  /// In sv, this message translates to:
  /// **'Sparade menyer'**
  String get menuSavedMenus;

  /// No description provided for @menuNoSavedMenus.
  ///
  /// In sv, this message translates to:
  /// **'Inga sparade menyer'**
  String get menuNoSavedMenus;

  /// No description provided for @menuSavedMenusSavedEarlier.
  ///
  /// In sv, this message translates to:
  /// **'Sparad tidigare'**
  String get menuSavedMenusSavedEarlier;

  /// No description provided for @menuLoadMenu.
  ///
  /// In sv, this message translates to:
  /// **'Ladda'**
  String get menuLoadMenu;

  /// No description provided for @menuRemoveMenu.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort'**
  String get menuRemoveMenu;

  /// No description provided for @menuRemoveMenuTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort meny'**
  String get menuRemoveMenuTitle;

  /// No description provided for @menuMenuNameRequired.
  ///
  /// In sv, this message translates to:
  /// **'Menynamn krävs'**
  String get menuMenuNameRequired;

  /// No description provided for @menuMenuToSave.
  ///
  /// In sv, this message translates to:
  /// **'Meny att spara'**
  String get menuMenuToSave;

  /// No description provided for @menuCommentOptional.
  ///
  /// In sv, this message translates to:
  /// **'Kommentar (valfritt)'**
  String get menuCommentOptional;

  /// No description provided for @menuCommentHint.
  ///
  /// In sv, this message translates to:
  /// **'Beskrivning eller noteringar om menyn'**
  String get menuCommentHint;

  /// No description provided for @menuShareWithFriends.
  ///
  /// In sv, this message translates to:
  /// **'Dela med vänner'**
  String get menuShareWithFriends;

  /// No description provided for @menuShareThisMenu.
  ///
  /// In sv, this message translates to:
  /// **'Dela denna meny med valda vänner'**
  String get menuShareThisMenu;

  /// No description provided for @menuSelectFriendsToShare.
  ///
  /// In sv, this message translates to:
  /// **'Välj vänner att dela med'**
  String get menuSelectFriendsToShare;

  /// No description provided for @menuNoFriendsAvailable.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner tillgängliga'**
  String get menuNoFriendsAvailable;

  /// No description provided for @menuDefaultShareMessage.
  ///
  /// In sv, this message translates to:
  /// **'Kolla min nya veckomeny!'**
  String get menuDefaultShareMessage;

  /// No description provided for @menuShareMessageLabel.
  ///
  /// In sv, this message translates to:
  /// **'Delningsmeddelande'**
  String get menuShareMessageLabel;

  /// No description provided for @menuShareMessageHint.
  ///
  /// In sv, this message translates to:
  /// **'Meddelande som skickas med menyn'**
  String get menuShareMessageHint;

  /// No description provided for @menuMenuNameHint.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. Vecka 45 eller Helgmeny'**
  String get menuMenuNameHint;

  /// No description provided for @menuUnnamedMenu.
  ///
  /// In sv, this message translates to:
  /// **'Namnlös meny'**
  String get menuUnnamedMenu;

  /// No description provided for @socialUnknownUser.
  ///
  /// In sv, this message translates to:
  /// **'Okänd användare'**
  String get socialUnknownUser;

  /// No description provided for @socialShared.
  ///
  /// In sv, this message translates to:
  /// **'Delat'**
  String get socialShared;

  /// No description provided for @socialEditRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Redigera recept'**
  String get socialEditRecipe;

  /// No description provided for @socialEditingTogether.
  ///
  /// In sv, this message translates to:
  /// **'Du redigerar tillsammans med andra'**
  String get socialEditingTogether;

  /// No description provided for @socialChangesSyncAutomatically.
  ///
  /// In sv, this message translates to:
  /// **'Ändringar synkas automatiskt med andra deltagare'**
  String get socialChangesSyncAutomatically;

  /// No description provided for @socialActive.
  ///
  /// In sv, this message translates to:
  /// **'Aktiv'**
  String get socialActive;

  /// No description provided for @socialParticipants.
  ///
  /// In sv, this message translates to:
  /// **'Deltagare'**
  String get socialParticipants;

  /// No description provided for @socialViewAll.
  ///
  /// In sv, this message translates to:
  /// **'Visa alla'**
  String get socialViewAll;

  /// No description provided for @socialSharedRecipeMembers.
  ///
  /// In sv, this message translates to:
  /// **'Delat recept • {count} medlemmar'**
  String socialSharedRecipeMembers(int count);

  /// No description provided for @socialSharedMenuMembers.
  ///
  /// In sv, this message translates to:
  /// **'Delad meny • {count} medlemmar'**
  String socialSharedMenuMembers(int count);

  /// No description provided for @socialActiveCollaboration.
  ///
  /// In sv, this message translates to:
  /// **'Aktiv samarbete'**
  String get socialActiveCollaboration;

  /// No description provided for @socialInactive.
  ///
  /// In sv, this message translates to:
  /// **'Inte aktivt'**
  String get socialInactive;

  /// No description provided for @socialCollaborationStatistics.
  ///
  /// In sv, this message translates to:
  /// **'Samarbetsstatistik'**
  String get socialCollaborationStatistics;

  /// No description provided for @socialMembers.
  ///
  /// In sv, this message translates to:
  /// **'Medlemmar'**
  String get socialMembers;

  /// No description provided for @socialActiveEditors.
  ///
  /// In sv, this message translates to:
  /// **'Aktiva'**
  String get socialActiveEditors;

  /// No description provided for @socialChanges.
  ///
  /// In sv, this message translates to:
  /// **'Ändringar'**
  String get socialChanges;

  /// No description provided for @socialLastActive.
  ///
  /// In sv, this message translates to:
  /// **'Senast aktiv: {time}'**
  String socialLastActive(String time);

  /// No description provided for @socialJustNow.
  ///
  /// In sv, this message translates to:
  /// **'just nu'**
  String get socialJustNow;

  /// No description provided for @socialMinutesAgo.
  ///
  /// In sv, this message translates to:
  /// **'{count} min sedan'**
  String socialMinutesAgo(int count);

  /// No description provided for @socialHoursAgo.
  ///
  /// In sv, this message translates to:
  /// **'{count} timmar sedan'**
  String socialHoursAgo(int count);

  /// No description provided for @socialDaysAgo.
  ///
  /// In sv, this message translates to:
  /// **'{count} dagar sedan'**
  String socialDaysAgo(int count);

  /// No description provided for @socialPermissionOwner.
  ///
  /// In sv, this message translates to:
  /// **'Ägare'**
  String get socialPermissionOwner;

  /// No description provided for @socialPermissionAdmin.
  ///
  /// In sv, this message translates to:
  /// **'Admin'**
  String get socialPermissionAdmin;

  /// No description provided for @socialPermissionEditor.
  ///
  /// In sv, this message translates to:
  /// **'Redigera'**
  String get socialPermissionEditor;

  /// No description provided for @socialPermissionViewer.
  ///
  /// In sv, this message translates to:
  /// **'Läsa'**
  String get socialPermissionViewer;

  /// No description provided for @socialPermissionUnknown.
  ///
  /// In sv, this message translates to:
  /// **'Okänd'**
  String get socialPermissionUnknown;

  /// No description provided for @socialAddCategory.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till kategori'**
  String get socialAddCategory;

  /// No description provided for @socialNewCategory.
  ///
  /// In sv, this message translates to:
  /// **'Ny kategori'**
  String get socialNewCategory;

  /// No description provided for @socialFilterCategories.
  ///
  /// In sv, this message translates to:
  /// **'Filtrera kategorier'**
  String get socialFilterCategories;

  /// No description provided for @socialSortCategories.
  ///
  /// In sv, this message translates to:
  /// **'Sortera kategorier'**
  String get socialSortCategories;

  /// No description provided for @socialAveragePerCategory.
  ///
  /// In sv, this message translates to:
  /// **'Genomsnitt/kategori'**
  String get socialAveragePerCategory;

  /// No description provided for @socialLargestCategory.
  ///
  /// In sv, this message translates to:
  /// **'Största kategorin'**
  String get socialLargestCategory;

  /// No description provided for @socialCreateFirstCategory.
  ///
  /// In sv, this message translates to:
  /// **'Skapa din första vänkategori för att komma igång'**
  String get socialCreateFirstCategory;

  /// No description provided for @socialLoadingCategories.
  ///
  /// In sv, this message translates to:
  /// **'Laddar kategorier...'**
  String get socialLoadingCategories;

  /// No description provided for @socialSelectAllLabel.
  ///
  /// In sv, this message translates to:
  /// **'Markera alla'**
  String get socialSelectAllLabel;

  /// No description provided for @socialDeselectAllLabel.
  ///
  /// In sv, this message translates to:
  /// **'Avmarkera alla'**
  String get socialDeselectAllLabel;

  /// No description provided for @socialInvertLabel.
  ///
  /// In sv, this message translates to:
  /// **'Invertera'**
  String get socialInvertLabel;

  /// No description provided for @invitationNoTargetsAvailable.
  ///
  /// In sv, this message translates to:
  /// **'Inga målgrupper tillgängliga'**
  String get invitationNoTargetsAvailable;

  /// No description provided for @invitationSearchTargets.
  ///
  /// In sv, this message translates to:
  /// **'Sök målgrupper...'**
  String get invitationSearchTargets;

  /// No description provided for @invitationSelectedTargets.
  ///
  /// In sv, this message translates to:
  /// **'Valda målgrupper'**
  String get invitationSelectedTargets;

  /// No description provided for @invitationTargetsSelected.
  ///
  /// In sv, this message translates to:
  /// **'{count} målgrupper valda'**
  String invitationTargetsSelected(int count);

  /// No description provided for @invitationSortLabel.
  ///
  /// In sv, this message translates to:
  /// **'Sortera:'**
  String get invitationSortLabel;

  /// No description provided for @invitationSortByName.
  ///
  /// In sv, this message translates to:
  /// **'Namn'**
  String get invitationSortByName;

  /// No description provided for @invitationSortByType.
  ///
  /// In sv, this message translates to:
  /// **'Typ'**
  String get invitationSortByType;

  /// No description provided for @invitationSortByMembers.
  ///
  /// In sv, this message translates to:
  /// **'Medlemmar'**
  String get invitationSortByMembers;

  /// No description provided for @invitationAll.
  ///
  /// In sv, this message translates to:
  /// **'Alla'**
  String get invitationAll;

  /// No description provided for @invitationNone.
  ///
  /// In sv, this message translates to:
  /// **'Inga'**
  String get invitationNone;

  /// No description provided for @invitationGroups.
  ///
  /// In sv, this message translates to:
  /// **'Grupper'**
  String get invitationGroups;

  /// No description provided for @invitationIndividuals.
  ///
  /// In sv, this message translates to:
  /// **'Individer'**
  String get invitationIndividuals;

  /// No description provided for @invitationAddTarget.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till målgrupp'**
  String get invitationAddTarget;

  /// No description provided for @invitationSendInvitations.
  ///
  /// In sv, this message translates to:
  /// **'Skicka inbjudningar'**
  String get invitationSendInvitations;

  /// No description provided for @invitationCreateGroup.
  ///
  /// In sv, this message translates to:
  /// **'Skapa grupp'**
  String get invitationCreateGroup;

  /// No description provided for @invitationAffectedTargets.
  ///
  /// In sv, this message translates to:
  /// **'Berörda målgrupper:'**
  String get invitationAffectedTargets;

  /// No description provided for @invitationView.
  ///
  /// In sv, this message translates to:
  /// **'Visa'**
  String get invitationView;

  /// No description provided for @invitationSendInvitation.
  ///
  /// In sv, this message translates to:
  /// **'Skicka inbjudan'**
  String get invitationSendInvitation;

  /// No description provided for @invitationInvite.
  ///
  /// In sv, this message translates to:
  /// **'Inbjud'**
  String get invitationInvite;

  /// No description provided for @invitationViewMembers.
  ///
  /// In sv, this message translates to:
  /// **'Visa medlemmar'**
  String get invitationViewMembers;

  /// No description provided for @invitationLoadingTargets.
  ///
  /// In sv, this message translates to:
  /// **'Laddar målgrupper...'**
  String get invitationLoadingTargets;

  /// No description provided for @invitationNetworkError.
  ///
  /// In sv, this message translates to:
  /// **'Nätverksfel'**
  String get invitationNetworkError;

  /// No description provided for @invitationCheckConnection.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollera din internetanslutning.'**
  String get invitationCheckConnection;

  /// No description provided for @invitationNoAccessTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ingen åtkomst'**
  String get invitationNoAccessTitle;

  /// No description provided for @invitationNoAccessSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Du har inte behörighet att se denna information.'**
  String get invitationNoAccessSubtitle;

  /// No description provided for @invitationTargetsLoaded.
  ///
  /// In sv, this message translates to:
  /// **'Målgrupper laddade!'**
  String get invitationTargetsLoaded;

  /// No description provided for @invitationNoSearchResults.
  ///
  /// In sv, this message translates to:
  /// **'Inga sökresultat'**
  String get invitationNoSearchResults;

  /// No description provided for @invitationNoResultsFor.
  ///
  /// In sv, this message translates to:
  /// **'Inga resultat för \"{query}\"'**
  String invitationNoResultsFor(String query);

  /// No description provided for @invitationTargetsSelectedCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} mål valda'**
  String invitationTargetsSelectedCount(int count);

  /// No description provided for @invitationNoSelectionsMade.
  ///
  /// In sv, this message translates to:
  /// **'Inga val gjorda'**
  String get invitationNoSelectionsMade;

  /// No description provided for @socialSharedRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Delade recept'**
  String get socialSharedRecipes;

  /// No description provided for @socialSharedMenus.
  ///
  /// In sv, this message translates to:
  /// **'Delade menyer'**
  String get socialSharedMenus;

  /// No description provided for @socialActiveCollaborations.
  ///
  /// In sv, this message translates to:
  /// **'Aktiva samarbeten'**
  String get socialActiveCollaborations;

  /// No description provided for @socialSent.
  ///
  /// In sv, this message translates to:
  /// **'Skickade'**
  String get socialSent;

  /// No description provided for @socialReceived.
  ///
  /// In sv, this message translates to:
  /// **'Mottagna'**
  String get socialReceived;

  /// No description provided for @socialAccepted.
  ///
  /// In sv, this message translates to:
  /// **'Accepterade'**
  String get socialAccepted;

  /// No description provided for @socialPending.
  ///
  /// In sv, this message translates to:
  /// **'Väntande'**
  String get socialPending;

  /// No description provided for @commonUser.
  ///
  /// In sv, this message translates to:
  /// **'Användare'**
  String get commonUser;

  /// No description provided for @commonDone.
  ///
  /// In sv, this message translates to:
  /// **'Klar'**
  String get commonDone;

  /// No description provided for @commonClearError.
  ///
  /// In sv, this message translates to:
  /// **'Rensa fel'**
  String get commonClearError;

  /// No description provided for @commonClearSearch.
  ///
  /// In sv, this message translates to:
  /// **'Rensa sökning'**
  String get commonClearSearch;

  /// No description provided for @commonComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Kommer snart...'**
  String get commonComingSoon;

  /// No description provided for @commonDiscard.
  ///
  /// In sv, this message translates to:
  /// **'Kasta bort'**
  String get commonDiscard;

  /// No description provided for @commonFailed.
  ///
  /// In sv, this message translates to:
  /// **'Misslyckades'**
  String get commonFailed;

  /// No description provided for @commonImporting.
  ///
  /// In sv, this message translates to:
  /// **'Importerar...'**
  String get commonImporting;

  /// No description provided for @commonLater.
  ///
  /// In sv, this message translates to:
  /// **'Senare'**
  String get commonLater;

  /// No description provided for @commonMessage.
  ///
  /// In sv, this message translates to:
  /// **'Meddelande:'**
  String get commonMessage;

  /// No description provided for @commonPending.
  ///
  /// In sv, this message translates to:
  /// **'Väntar'**
  String get commonPending;

  /// No description provided for @commonRefresh.
  ///
  /// In sv, this message translates to:
  /// **'Uppdatera'**
  String get commonRefresh;

  /// No description provided for @commonRemove.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort'**
  String get commonRemove;

  /// No description provided for @commonSaving.
  ///
  /// In sv, this message translates to:
  /// **'Sparar...'**
  String get commonSaving;

  /// No description provided for @commonSending.
  ///
  /// In sv, this message translates to:
  /// **'Skickar...'**
  String get commonSending;

  /// No description provided for @commonUndo.
  ///
  /// In sv, this message translates to:
  /// **'Ångra'**
  String get commonUndo;

  /// No description provided for @commonUploading.
  ///
  /// In sv, this message translates to:
  /// **'Laddar upp...'**
  String get commonUploading;

  /// No description provided for @authLogIn.
  ///
  /// In sv, this message translates to:
  /// **'Logga in'**
  String get authLogIn;

  /// No description provided for @collaborativeListNoAccess.
  ///
  /// In sv, this message translates to:
  /// **'Listan kanske har tagits bort eller så har du inte tillgång längre'**
  String get collaborativeListNoAccess;

  /// No description provided for @collaborativeListNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Lista hittades inte'**
  String get collaborativeListNotFound;

  /// No description provided for @collaborativeLoadingSharedList.
  ///
  /// In sv, this message translates to:
  /// **'Laddar gemensam lista...'**
  String get collaborativeLoadingSharedList;

  /// No description provided for @discoveryActivity.
  ///
  /// In sv, this message translates to:
  /// **'Aktivitet'**
  String get discoveryActivity;

  /// No description provided for @discoveryByAuthor.
  ///
  /// In sv, this message translates to:
  /// **'Av {name}'**
  String discoveryByAuthor(String name);

  /// No description provided for @discoveryCategories.
  ///
  /// In sv, this message translates to:
  /// **'Kategorier'**
  String get discoveryCategories;

  /// No description provided for @discoveryContentType.
  ///
  /// In sv, this message translates to:
  /// **'Innehållstyp'**
  String get discoveryContentType;

  /// No description provided for @discoveryCustomizeExperience.
  ///
  /// In sv, this message translates to:
  /// **'Anpassa din upptäcktsupplevelse'**
  String get discoveryCustomizeExperience;

  /// No description provided for @discoveryDiscover.
  ///
  /// In sv, this message translates to:
  /// **'Upptäck'**
  String get discoveryDiscover;

  /// No description provided for @discoveryDiscoverNewContent.
  ///
  /// In sv, this message translates to:
  /// **'Upptäck nytt innehåll'**
  String get discoveryDiscoverNewContent;

  /// No description provided for @discoveryFeedbackHint.
  ///
  /// In sv, this message translates to:
  /// **'Hjälp oss att förbättra Butlery! Beskriv din feedback här...'**
  String get discoveryFeedbackHint;

  /// No description provided for @discoveryFeedbackThanks.
  ///
  /// In sv, this message translates to:
  /// **'Tack för din feedback! Vi kommer att granska den.'**
  String get discoveryFeedbackThanks;

  /// No description provided for @discoveryFilterContent.
  ///
  /// In sv, this message translates to:
  /// **'Filtrera innehåll'**
  String get discoveryFilterContent;

  /// No description provided for @discoveryFindPopularContent.
  ///
  /// In sv, this message translates to:
  /// **'Hitta populära recept, menyer och listor'**
  String get discoveryFindPopularContent;

  /// No description provided for @discoveryForYou.
  ///
  /// In sv, this message translates to:
  /// **'För dig'**
  String get discoveryForYou;

  /// No description provided for @discoveryGiveFeedback.
  ///
  /// In sv, this message translates to:
  /// **'Ge feedback'**
  String get discoveryGiveFeedback;

  /// No description provided for @discoveryItemCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} objekt'**
  String discoveryItemCount(int count);

  /// No description provided for @discoveryLoading.
  ///
  /// In sv, this message translates to:
  /// **'Laddar upptäcktsinnehåll...'**
  String get discoveryLoading;

  /// No description provided for @discoveryMenus.
  ///
  /// In sv, this message translates to:
  /// **'Menyer'**
  String get discoveryMenus;

  /// No description provided for @discoveryNotifications.
  ///
  /// In sv, this message translates to:
  /// **'Aviseringar'**
  String get discoveryNotifications;

  /// No description provided for @discoveryPopularNow.
  ///
  /// In sv, this message translates to:
  /// **'Populärt just nu'**
  String get discoveryPopularNow;

  /// No description provided for @discoveryPushNotifications.
  ///
  /// In sv, this message translates to:
  /// **'Push-aviseringar'**
  String get discoveryPushNotifications;

  /// No description provided for @discoveryPushNotificationsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Få aviseringar om nytt innehåll'**
  String get discoveryPushNotificationsDescription;

  /// No description provided for @discoveryRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Recept'**
  String get discoveryRecipes;

  /// No description provided for @discoverySeeAll.
  ///
  /// In sv, this message translates to:
  /// **'Se allt'**
  String get discoverySeeAll;

  /// No description provided for @discoverySendFeedback.
  ///
  /// In sv, this message translates to:
  /// **'Skicka feedback'**
  String get discoverySendFeedback;

  /// No description provided for @discoverySettings.
  ///
  /// In sv, this message translates to:
  /// **'Upptäcktsinställningar'**
  String get discoverySettings;

  /// No description provided for @discoverySettingsSaved.
  ///
  /// In sv, this message translates to:
  /// **'Inställningar sparade!'**
  String get discoverySettingsSaved;

  /// No description provided for @discoveryShoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslistor'**
  String get discoveryShoppingLists;

  /// No description provided for @discoveryShowFriendActivity.
  ///
  /// In sv, this message translates to:
  /// **'Visa vänaktivitet'**
  String get discoveryShowFriendActivity;

  /// No description provided for @discoveryShowFriendActivityDescription.
  ///
  /// In sv, this message translates to:
  /// **'Visa vad dina vänner gör'**
  String get discoveryShowFriendActivityDescription;

  /// No description provided for @discoveryShowMenuResults.
  ///
  /// In sv, this message translates to:
  /// **'Visa menyresultat'**
  String get discoveryShowMenuResults;

  /// No description provided for @discoveryShowRecipeResults.
  ///
  /// In sv, this message translates to:
  /// **'Visa receptresultat'**
  String get discoveryShowRecipeResults;

  /// No description provided for @discoveryShowRecommendations.
  ///
  /// In sv, this message translates to:
  /// **'Visa rekommendationer'**
  String get discoveryShowRecommendations;

  /// No description provided for @discoveryShowRecommendationsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Visa personliga rekommendationer'**
  String get discoveryShowRecommendationsDescription;

  /// No description provided for @discoveryShowShoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'Visa inköpslistor'**
  String get discoveryShowShoppingLists;

  /// No description provided for @discoveryShowTrends.
  ///
  /// In sv, this message translates to:
  /// **'Visa trender'**
  String get discoveryShowTrends;

  /// No description provided for @discoveryShowTrendsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Visa populärt innehåll från communityn'**
  String get discoveryShowTrendsDescription;

  /// No description provided for @discoveryToDiscover.
  ///
  /// In sv, this message translates to:
  /// **'att upptäcka'**
  String get discoveryToDiscover;

  /// No description provided for @allergenCrustacean.
  ///
  /// In sv, this message translates to:
  /// **'Kräftdjur'**
  String get allergenCrustacean;

  /// No description provided for @allergenDairy.
  ///
  /// In sv, this message translates to:
  /// **'Mjölk'**
  String get allergenDairy;

  /// No description provided for @allergenEgg.
  ///
  /// In sv, this message translates to:
  /// **'Ägg'**
  String get allergenEgg;

  /// No description provided for @allergenFish.
  ///
  /// In sv, this message translates to:
  /// **'Fisk'**
  String get allergenFish;

  /// No description provided for @allergenGluten.
  ///
  /// In sv, this message translates to:
  /// **'Gluten'**
  String get allergenGluten;

  /// No description provided for @allergenPeanut.
  ///
  /// In sv, this message translates to:
  /// **'Jordnötter'**
  String get allergenPeanut;

  /// No description provided for @allergenSoy.
  ///
  /// In sv, this message translates to:
  /// **'Soja'**
  String get allergenSoy;

  /// No description provided for @allergenTreeNut.
  ///
  /// In sv, this message translates to:
  /// **'Trädnötter'**
  String get allergenTreeNut;

  /// No description provided for @commentCouldNotPost.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte posta kommentaren'**
  String get commentCouldNotPost;

  /// No description provided for @commentPosted.
  ///
  /// In sv, this message translates to:
  /// **'Kommentar postad'**
  String get commentPosted;

  /// No description provided for @commentReply.
  ///
  /// In sv, this message translates to:
  /// **'Svara'**
  String get commentReply;

  /// No description provided for @commentReplyingTo.
  ///
  /// In sv, this message translates to:
  /// **'Svarar på'**
  String get commentReplyingTo;

  /// No description provided for @commentWriteComment.
  ///
  /// In sv, this message translates to:
  /// **'Skriv en kommentar'**
  String get commentWriteComment;

  /// No description provided for @commentWriteReply.
  ///
  /// In sv, this message translates to:
  /// **'Skriv ett svar'**
  String get commentWriteReply;

  /// No description provided for @commentYou.
  ///
  /// In sv, this message translates to:
  /// **'Du'**
  String get commentYou;

  /// No description provided for @dialogAddRecipesToCategory.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till recept i {categoryName}'**
  String dialogAddRecipesToCategory(String categoryName);

  /// No description provided for @dialogAlreadyShared.
  ///
  /// In sv, this message translates to:
  /// **'Delad'**
  String get dialogAlreadyShared;

  /// No description provided for @dialogAlternatives.
  ///
  /// In sv, this message translates to:
  /// **'Alternativ:'**
  String get dialogAlternatives;

  /// No description provided for @dialogClearSelection.
  ///
  /// In sv, this message translates to:
  /// **'Rensa val'**
  String get dialogClearSelection;

  /// No description provided for @dialogContainsAllergens.
  ///
  /// In sv, this message translates to:
  /// **'Innehåller allergener:'**
  String get dialogContainsAllergens;

  /// No description provided for @dialogCouldNotSave.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara: {error}'**
  String dialogCouldNotSave(String error);

  /// No description provided for @dialogCreateList.
  ///
  /// In sv, this message translates to:
  /// **'Skapa lista'**
  String get dialogCreateList;

  /// No description provided for @dialogCreateNewListForIngredients.
  ///
  /// In sv, this message translates to:
  /// **'Skapa en ny lista för dessa ingredienser'**
  String get dialogCreateNewListForIngredients;

  /// No description provided for @dialogDietaryProperties.
  ///
  /// In sv, this message translates to:
  /// **'Dietegenskaper:'**
  String get dialogDietaryProperties;

  /// No description provided for @dialogEnterListName.
  ///
  /// In sv, this message translates to:
  /// **'Ange ett namn för listan'**
  String get dialogEnterListName;

  /// No description provided for @dialogFilteredRecipeCount.
  ///
  /// In sv, this message translates to:
  /// **'{filtered} av {total} recept'**
  String dialogFilteredRecipeCount(int filtered, int total);

  /// No description provided for @dialogImportWithoutAi.
  ///
  /// In sv, this message translates to:
  /// **'Importera utan AI'**
  String get dialogImportWithoutAi;

  /// No description provided for @dialogItems.
  ///
  /// In sv, this message translates to:
  /// **'objekt'**
  String get dialogItems;

  /// No description provided for @dialogItemsProgress.
  ///
  /// In sv, this message translates to:
  /// **'{completed}/{total} klara'**
  String dialogItemsProgress(int completed, int total);

  /// No description provided for @dialogLoadingMenus.
  ///
  /// In sv, this message translates to:
  /// **'Laddar menyer...'**
  String get dialogLoadingMenus;

  /// No description provided for @dialogLoadingRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Laddar recept...'**
  String get dialogLoadingRecipes;

  /// No description provided for @dialogManualImport.
  ///
  /// In sv, this message translates to:
  /// **'Manuell import'**
  String get dialogManualImport;

  /// No description provided for @dialogMarkIngredientsYourself.
  ///
  /// In sv, this message translates to:
  /// **'Markera ingredienser själv'**
  String get dialogMarkIngredientsYourself;

  /// No description provided for @dialogMayTakeAWhile.
  ///
  /// In sv, this message translates to:
  /// **'Detta kan ta en stund...'**
  String get dialogMayTakeAWhile;

  /// No description provided for @dialogNameMinTwoChars.
  ///
  /// In sv, this message translates to:
  /// **'Namnet måste vara minst 2 tecken'**
  String get dialogNameMinTwoChars;

  /// No description provided for @dialogNoEditableShoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga redigerbara inköpslistor. Endast listor du kan redigera visas här. Skapa en ny lista ovan.'**
  String get dialogNoEditableShoppingLists;

  /// No description provided for @dialogNoMenus.
  ///
  /// In sv, this message translates to:
  /// **'Inga menyer'**
  String get dialogNoMenus;

  /// No description provided for @dialogNoMenusToShare.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga menyer att dela än'**
  String get dialogNoMenusToShare;

  /// No description provided for @dialogNoRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Inga recept'**
  String get dialogNoRecipes;

  /// No description provided for @dialogNoRecipesToShare.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga recept att dela än'**
  String get dialogNoRecipesToShare;

  /// No description provided for @dialogNoShoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'Inga inköpslistor'**
  String get dialogNoShoppingLists;

  /// No description provided for @dialogNoShoppingListsToShare.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga inköpslistor att dela än'**
  String get dialogNoShoppingListsToShare;

  /// No description provided for @dialogOrSelectExistingList.
  ///
  /// In sv, this message translates to:
  /// **'Eller välj befintlig lista:'**
  String get dialogOrSelectExistingList;

  /// No description provided for @dialogPrivate.
  ///
  /// In sv, this message translates to:
  /// **'Privat'**
  String get dialogPrivate;

  /// No description provided for @dialogRetryInHours.
  ///
  /// In sv, this message translates to:
  /// **'Försök igen om {hours} timme(ar)'**
  String dialogRetryInHours(int hours);

  /// No description provided for @dialogRetryInMinutes.
  ///
  /// In sv, this message translates to:
  /// **'Försök igen om {minutes} minut(er)'**
  String dialogRetryInMinutes(int minutes);

  /// No description provided for @dialogRetryInSeconds.
  ///
  /// In sv, this message translates to:
  /// **'Försök igen om {seconds} sekund(er)'**
  String dialogRetryInSeconds(int seconds);

  /// No description provided for @dialogRetryLater.
  ///
  /// In sv, this message translates to:
  /// **'Försök senare'**
  String get dialogRetryLater;

  /// No description provided for @dialogRetryTomorrow.
  ///
  /// In sv, this message translates to:
  /// **'Försök igen imorgon'**
  String get dialogRetryTomorrow;

  /// No description provided for @dialogSearchRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Sök recept...'**
  String get dialogSearchRecipes;

  /// No description provided for @dialogSearchRecipesToAdd.
  ///
  /// In sv, this message translates to:
  /// **'Sök recept att lägga till...'**
  String get dialogSearchRecipesToAdd;

  /// No description provided for @dialogSelectedCount.
  ///
  /// In sv, this message translates to:
  /// **'Valda ({count})'**
  String dialogSelectedCount(int count);

  /// No description provided for @dialogShared.
  ///
  /// In sv, this message translates to:
  /// **'Delad'**
  String get dialogShared;

  /// No description provided for @dialogShareMenuWith.
  ///
  /// In sv, this message translates to:
  /// **'Dela meny med {groupName}'**
  String dialogShareMenuWith(String groupName);

  /// No description provided for @dialogShareRecipesWith.
  ///
  /// In sv, this message translates to:
  /// **'Dela recept med {name}'**
  String dialogShareRecipesWith(String name);

  /// No description provided for @dialogShareShoppingListWith.
  ///
  /// In sv, this message translates to:
  /// **'Dela inköpslista med {groupName}'**
  String dialogShareShoppingListWith(String groupName);

  /// No description provided for @dialogSharing.
  ///
  /// In sv, this message translates to:
  /// **'Delar...'**
  String get dialogSharing;

  /// No description provided for @dialogShoppingListNameHint.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. \"Pannkakor - Ingredienser\"'**
  String get dialogShoppingListNameHint;

  /// No description provided for @dialogUnknownIngredientDescription.
  ///
  /// In sv, this message translates to:
  /// **'Denna ingrediens finns inte i databasen. Du kan definiera dess egenskaper för bättre taggning.'**
  String get dialogUnknownIngredientDescription;

  /// No description provided for @dialogUnknownIngredientProgress.
  ///
  /// In sv, this message translates to:
  /// **'Okänd ingrediens {current}/{total}'**
  String dialogUnknownIngredientProgress(int current, int total);

  /// No description provided for @dialogUsesSimpleExtraction.
  ///
  /// In sv, this message translates to:
  /// **'Använder enklare extrahering'**
  String get dialogUsesSimpleExtraction;

  /// No description provided for @dietaryAlcohol.
  ///
  /// In sv, this message translates to:
  /// **'Alkohol'**
  String get dietaryAlcohol;

  /// No description provided for @dietaryAnimalProduct.
  ///
  /// In sv, this message translates to:
  /// **'Animalisk produkt'**
  String get dietaryAnimalProduct;

  /// No description provided for @dietaryBeef.
  ///
  /// In sv, this message translates to:
  /// **'Nötkött'**
  String get dietaryBeef;

  /// No description provided for @dietaryMeat.
  ///
  /// In sv, this message translates to:
  /// **'Kött'**
  String get dietaryMeat;

  /// No description provided for @dietaryPork.
  ///
  /// In sv, this message translates to:
  /// **'Fläsk'**
  String get dietaryPork;

  /// No description provided for @dietaryPoultry.
  ///
  /// In sv, this message translates to:
  /// **'Fågel'**
  String get dietaryPoultry;

  /// No description provided for @dietarySeafood.
  ///
  /// In sv, this message translates to:
  /// **'Fisk/skaldjur'**
  String get dietarySeafood;

  /// No description provided for @dietarySpicy.
  ///
  /// In sv, this message translates to:
  /// **'Starkt'**
  String get dietarySpicy;

  /// No description provided for @draftContinueEditing.
  ///
  /// In sv, this message translates to:
  /// **'Fortsätt redigera'**
  String get draftContinueEditing;

  /// No description provided for @draftDiscardAll.
  ///
  /// In sv, this message translates to:
  /// **'Släng alla'**
  String get draftDiscardAll;

  /// No description provided for @draftUnsavedFound.
  ///
  /// In sv, this message translates to:
  /// **'Osparade utkast hittade'**
  String get draftUnsavedFound;

  /// No description provided for @groupContentTypeContent.
  ///
  /// In sv, this message translates to:
  /// **'Innehåll'**
  String get groupContentTypeContent;

  /// No description provided for @groupContentTypeMenu.
  ///
  /// In sv, this message translates to:
  /// **'Meny'**
  String get groupContentTypeMenu;

  /// No description provided for @groupContentTypeRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Recept'**
  String get groupContentTypeRecipe;

  /// No description provided for @groupContentTypeShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslista'**
  String get groupContentTypeShoppingList;

  /// No description provided for @groupCopiedToClipboard.
  ///
  /// In sv, this message translates to:
  /// **'Kopierat till urklipp'**
  String get groupCopiedToClipboard;

  /// No description provided for @groupCouldNotCopyList.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte kopiera lista: {error}'**
  String groupCouldNotCopyList(String error);

  /// No description provided for @groupCouldNotFetchMenu.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte hämta meny från servern'**
  String get groupCouldNotFetchMenu;

  /// No description provided for @groupCouldNotImportList.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte importera lista: {error}'**
  String groupCouldNotImportList(String error);

  /// No description provided for @groupCreateNew.
  ///
  /// In sv, this message translates to:
  /// **'Skapa ny grupp'**
  String get groupCreateNew;

  /// No description provided for @groupDeleteConfirmPrefix.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill ta bort gruppen '**
  String get groupDeleteConfirmPrefix;

  /// No description provided for @groupDeleteTheGroup.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort gruppen'**
  String get groupDeleteTheGroup;

  /// No description provided for @groupDeleteWarning.
  ///
  /// In sv, this message translates to:
  /// **'Detta kan inte ångras. Alla medlemmar kommer att tas bort från gruppen.'**
  String get groupDeleteWarning;

  /// No description provided for @groupDeleteWhenLeaving.
  ///
  /// In sv, this message translates to:
  /// **'Vill du ta bort gruppen när du lämnar den?'**
  String get groupDeleteWhenLeaving;

  /// No description provided for @groupDescriptionHint.
  ///
  /// In sv, this message translates to:
  /// **'Vad handlar den här gruppen om?'**
  String get groupDescriptionHint;

  /// No description provided for @groupDescriptionLabel.
  ///
  /// In sv, this message translates to:
  /// **'Beskrivning (valfritt)'**
  String get groupDescriptionLabel;

  /// No description provided for @groupErrorOpeningMenu.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid öppning av meny: {error}'**
  String groupErrorOpeningMenu(String error);

  /// No description provided for @groupImport.
  ///
  /// In sv, this message translates to:
  /// **'Importera'**
  String get groupImport;

  /// No description provided for @groupImportingMenuComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Importerar meny: {title} (kommer snart)'**
  String groupImportingMenuComingSoon(String title);

  /// No description provided for @groupImportingRecipeComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Importerar recept: {title} (kommer snart)'**
  String groupImportingRecipeComingSoon(String title);

  /// No description provided for @groupImportingShoppingListComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Importerar inköpslista: {title} (kommer snart)'**
  String groupImportingShoppingListComingSoon(String title);

  /// No description provided for @groupImportNotImplemented.
  ///
  /// In sv, this message translates to:
  /// **'Importera {title} (funktionalitet ej implementerad än)'**
  String groupImportNotImplemented(String title);

  /// No description provided for @groupImportShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Importera inköpslista'**
  String get groupImportShoppingList;

  /// No description provided for @groupImportShoppingListConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du importera \"{name}\" till dina inköpslistor?'**
  String groupImportShoppingListConfirm(String name);

  /// No description provided for @groupInvitationNote.
  ///
  /// In sv, this message translates to:
  /// **'Dessa vänner kommer att få en inbjudan till gruppen.'**
  String get groupInvitationNote;

  /// No description provided for @groupIsEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Gruppen är tom'**
  String get groupIsEmpty;

  /// No description provided for @groupListCopiedToClipboard.
  ///
  /// In sv, this message translates to:
  /// **'Lista kopierad till urklipp'**
  String get groupListCopiedToClipboard;

  /// No description provided for @groupListCopyName.
  ///
  /// In sv, this message translates to:
  /// **'Kopia av {name}'**
  String groupListCopyName(String name);

  /// No description provided for @groupListImported.
  ///
  /// In sv, this message translates to:
  /// **'\"{name}\" har importerats'**
  String groupListImported(String name);

  /// No description provided for @groupNameHint.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. \"Familjen\", \"Jobbet\", \"Bokklubben\"'**
  String get groupNameHint;

  /// No description provided for @groupNoFriendsToAdd.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga vänner att lägga till än. Lägg till vänner först för att skapa grupper med dem.'**
  String get groupNoFriendsToAdd;

  /// No description provided for @groupNoMenusShared.
  ///
  /// In sv, this message translates to:
  /// **'Inga menyer delade'**
  String get groupNoMenusShared;

  /// No description provided for @groupNoMenusSharedSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Dela menyer med gruppen för att planera tillsammans'**
  String get groupNoMenusSharedSubtitle;

  /// No description provided for @groupNoRecipesShared.
  ///
  /// In sv, this message translates to:
  /// **'Inga recept delade'**
  String get groupNoRecipesShared;

  /// No description provided for @groupNoRecipesSharedSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Dela recept med gruppen för att inspirera varandra'**
  String get groupNoRecipesSharedSubtitle;

  /// No description provided for @groupNoShoppingListsShared.
  ///
  /// In sv, this message translates to:
  /// **'Inga inköpslistor delade'**
  String get groupNoShoppingListsShared;

  /// No description provided for @groupNoShoppingListsSharedSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Dela inköpslistor med gruppen för att samarbeta'**
  String get groupNoShoppingListsSharedSubtitle;

  /// No description provided for @groupOnlyMember.
  ///
  /// In sv, this message translates to:
  /// **'Du är den enda medlemmen i \"{name}\".'**
  String groupOnlyMember(String name);

  /// No description provided for @groupPasteInAnyApp.
  ///
  /// In sv, this message translates to:
  /// **'Klistra in i valfri app'**
  String get groupPasteInAnyApp;

  /// No description provided for @groupRecipeViewComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Receptvisning: {title} (kommer snart)'**
  String groupRecipeViewComingSoon(String title);

  /// No description provided for @groupRemoveMemberConfirmPrefix.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill ta bort '**
  String get groupRemoveMemberConfirmPrefix;

  /// No description provided for @groupRemoveMemberFromGroup.
  ///
  /// In sv, this message translates to:
  /// **' från gruppen '**
  String get groupRemoveMemberFromGroup;

  /// No description provided for @groupRemoveMemberWarning.
  ///
  /// In sv, this message translates to:
  /// **'Medlemmen kommer att förlora åtkomst till gruppens innehåll.'**
  String get groupRemoveMemberWarning;

  /// No description provided for @groupSelectedMembers.
  ///
  /// In sv, this message translates to:
  /// **'Valda medlemmar ({count})'**
  String groupSelectedMembers(int count);

  /// No description provided for @groupSelectFriendsToInvite.
  ///
  /// In sv, this message translates to:
  /// **'Välj vänner att bjuda in till gruppen'**
  String get groupSelectFriendsToInvite;

  /// No description provided for @groupSelectIcon.
  ///
  /// In sv, this message translates to:
  /// **'Välj ikon'**
  String get groupSelectIcon;

  /// No description provided for @groupSelectMembers.
  ///
  /// In sv, this message translates to:
  /// **'Välj medlemmar'**
  String get groupSelectMembers;

  /// No description provided for @groupSelectNewOwner.
  ///
  /// In sv, this message translates to:
  /// **'Välj ny ägare:'**
  String get groupSelectNewOwner;

  /// No description provided for @groupSelectShareTarget.
  ///
  /// In sv, this message translates to:
  /// **'Välj vem du vill dela med'**
  String get groupSelectShareTarget;

  /// No description provided for @groupSendToFriends.
  ///
  /// In sv, this message translates to:
  /// **'Skicka till vänner i Butlery'**
  String get groupSendToFriends;

  /// No description provided for @groupSharedBy.
  ///
  /// In sv, this message translates to:
  /// **'Delad av {name}'**
  String groupSharedBy(String name);

  /// No description provided for @groupSharedContent.
  ///
  /// In sv, this message translates to:
  /// **'Delat innehåll'**
  String get groupSharedContent;

  /// No description provided for @groupShareShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Dela inköpslista'**
  String get groupShareShoppingList;

  /// No description provided for @groupShareWithFriendsInButlery.
  ///
  /// In sv, this message translates to:
  /// **'Dela med vänner i Butlery'**
  String get groupShareWithFriendsInButlery;

  /// No description provided for @groupShoppingListViewComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslistevisning: {title} (kommer snart)'**
  String groupShoppingListViewComingSoon(String title);

  /// No description provided for @groupTabLists.
  ///
  /// In sv, this message translates to:
  /// **'Listor'**
  String get groupTabLists;

  /// No description provided for @groupTabMenus.
  ///
  /// In sv, this message translates to:
  /// **'Menyer'**
  String get groupTabMenus;

  /// No description provided for @groupTransferOwnership.
  ///
  /// In sv, this message translates to:
  /// **'Överför gruppägande'**
  String get groupTransferOwnership;

  /// No description provided for @groupTransferOwnershipMessage.
  ///
  /// In sv, this message translates to:
  /// **'Du är ägare av \"{name}\". Du måste välja en ny ägare innan du kan lämna gruppen.'**
  String groupTransferOwnershipMessage(String name);

  /// No description provided for @groupView.
  ///
  /// In sv, this message translates to:
  /// **'Visa'**
  String get groupView;

  /// No description provided for @groupViewNotImplemented.
  ///
  /// In sv, this message translates to:
  /// **'Visa {title} (funktionalitet ej implementerad än)'**
  String groupViewNotImplemented(String title);

  /// No description provided for @profileCouldNotOpenConsentManagement.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte öppna samtyckeshantering: {error}'**
  String profileCouldNotOpenConsentManagement(String error);

  /// No description provided for @profileDataBackup.
  ///
  /// In sv, this message translates to:
  /// **'Data & Backup'**
  String get profileDataBackup;

  /// No description provided for @profileExportData.
  ///
  /// In sv, this message translates to:
  /// **'Exportera mina data'**
  String get profileExportData;

  /// No description provided for @profileExportDataSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Ladda ner all din data i JSON-format (GDPR)'**
  String get profileExportDataSubtitle;

  /// No description provided for @profileManageConsent.
  ///
  /// In sv, this message translates to:
  /// **'Hantera samtycken'**
  String get profileManageConsent;

  /// No description provided for @profileManageConsentSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Välj hur vi får behandla dina personuppgifter (GDPR)'**
  String get profileManageConsentSubtitle;

  /// No description provided for @rateLimitAiBudget.
  ///
  /// In sv, this message translates to:
  /// **'AI-budget förbrukad'**
  String get rateLimitAiBudget;

  /// No description provided for @rateLimitAiLimit.
  ///
  /// In sv, this message translates to:
  /// **'AI-gräns nådd'**
  String get rateLimitAiLimit;

  /// No description provided for @rateLimitDailyQuota.
  ///
  /// In sv, this message translates to:
  /// **'Dagskvot uppnådd'**
  String get rateLimitDailyQuota;

  /// No description provided for @rateLimitSlowDown.
  ///
  /// In sv, this message translates to:
  /// **'Sakta ner lite'**
  String get rateLimitSlowDown;

  /// No description provided for @sessionContinue.
  ///
  /// In sv, this message translates to:
  /// **'Fortsätt session'**
  String get sessionContinue;

  /// No description provided for @sessionContinueOrLogout.
  ///
  /// In sv, this message translates to:
  /// **'Vill du fortsätta din session eller logga ut nu?'**
  String get sessionContinueOrLogout;

  /// No description provided for @sessionExpiringMessage.
  ///
  /// In sv, this message translates to:
  /// **'Din session kommer att avslutas om:'**
  String get sessionExpiringMessage;

  /// No description provided for @sessionExpiringTitle.
  ///
  /// In sv, this message translates to:
  /// **'Session utgår snart'**
  String get sessionExpiringTitle;

  /// No description provided for @shareContentTypeMenu.
  ///
  /// In sv, this message translates to:
  /// **'menyer'**
  String get shareContentTypeMenu;

  /// No description provided for @shareContentTypeRecipe.
  ///
  /// In sv, this message translates to:
  /// **'recept'**
  String get shareContentTypeRecipe;

  /// No description provided for @shareContentTypeShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'inköpslistor'**
  String get shareContentTypeShoppingList;

  /// No description provided for @shareDefaultMessageMenu.
  ///
  /// In sv, this message translates to:
  /// **'Kolla in denna veckomeny: {name}'**
  String shareDefaultMessageMenu(String name);

  /// No description provided for @shareDefaultMessageRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kolla in detta recept: {name}'**
  String shareDefaultMessageRecipe(String name);

  /// No description provided for @shareDefaultMessageShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Kolla in denna inköpslista: {name}'**
  String shareDefaultMessageShoppingList(String name);

  /// No description provided for @shareFriendsSelected.
  ///
  /// In sv, this message translates to:
  /// **'{count} vän(ner) valda'**
  String shareFriendsSelected(int count);

  /// No description provided for @shareMenu.
  ///
  /// In sv, this message translates to:
  /// **'Dela meny'**
  String get shareMenu;

  /// No description provided for @shareRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Dela recept'**
  String get shareRecipe;

  /// No description provided for @shareSelectAtLeastOne.
  ///
  /// In sv, this message translates to:
  /// **'Välj minst en vän för att dela {contentType}'**
  String shareSelectAtLeastOne(String contentType);

  /// No description provided for @shareSuccessMessage.
  ///
  /// In sv, this message translates to:
  /// **'{name} har delats som {mode} med {count} mottagare.'**
  String shareSuccessMessage(String name, String mode, int count);

  /// No description provided for @uploadFailed.
  ///
  /// In sv, this message translates to:
  /// **'Bilduppladdning misslyckades'**
  String get uploadFailed;

  /// No description provided for @uploadFailedCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} bilder kunde inte laddas upp.\n\nVad vill du göra?'**
  String uploadFailedCount(int count);

  /// No description provided for @uploadInProgress.
  ///
  /// In sv, this message translates to:
  /// **'Bilduppladdning pågår'**
  String get uploadInProgress;

  /// No description provided for @uploadMixedStatus.
  ///
  /// In sv, this message translates to:
  /// **'Några bilder kunde inte laddas upp ({failedCount}) och andra laddas fortfarande upp ({pendingCount}).\n\nVad vill du göra?'**
  String uploadMixedStatus(int failedCount, int pendingCount);

  /// No description provided for @uploadPendingCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} bilder laddas fortfarande upp.\n\nVad vill du göra?'**
  String uploadPendingCount(int count);

  /// No description provided for @uploadSaveWithoutFailed.
  ///
  /// In sv, this message translates to:
  /// **'Spara utan misslyckade bilder'**
  String get uploadSaveWithoutFailed;

  /// No description provided for @uploadSaveWithoutPending.
  ///
  /// In sv, this message translates to:
  /// **'Spara utan väntande bilder'**
  String get uploadSaveWithoutPending;

  /// No description provided for @uploadWait.
  ///
  /// In sv, this message translates to:
  /// **'Vänta på uppladdning'**
  String get uploadWait;

  /// No description provided for @uploadClearFailed.
  ///
  /// In sv, this message translates to:
  /// **'Rensa misslyckade'**
  String get uploadClearFailed;

  /// No description provided for @uploadRetryAllCount.
  ///
  /// In sv, this message translates to:
  /// **'Försök alla ({count})'**
  String uploadRetryAllCount(int count);

  /// No description provided for @uploadStopAllCount.
  ///
  /// In sv, this message translates to:
  /// **'Stoppa alla ({count})'**
  String uploadStopAllCount(int count);

  /// No description provided for @uploadTimeRemaining.
  ///
  /// In sv, this message translates to:
  /// **'{time} kvar'**
  String uploadTimeRemaining(String time);

  /// No description provided for @consentManageTitle.
  ///
  /// In sv, this message translates to:
  /// **'Hantera samtycken'**
  String get consentManageTitle;

  /// No description provided for @consentYourConsents.
  ///
  /// In sv, this message translates to:
  /// **'Dina samtycken'**
  String get consentYourConsents;

  /// No description provided for @consentGdprDescription.
  ///
  /// In sv, this message translates to:
  /// **'Enligt GDPR har du full kontroll över hur vi behandlar dina personuppgifter. Du kan när som helst ändra eller återkalla dina samtycken.'**
  String get consentGdprDescription;

  /// No description provided for @consentLastUpdated.
  ///
  /// In sv, this message translates to:
  /// **'Senast uppdaterad'**
  String get consentLastUpdated;

  /// No description provided for @consentRequiredTitle.
  ///
  /// In sv, this message translates to:
  /// **'Nödvändiga samtycken'**
  String get consentRequiredTitle;

  /// No description provided for @consentRequiredDescription.
  ///
  /// In sv, this message translates to:
  /// **'Dessa samtycken krävs för att appen ska fungera och kan inte inaktiveras.'**
  String get consentRequiredDescription;

  /// No description provided for @consentBasicServices.
  ///
  /// In sv, this message translates to:
  /// **'Grundläggande tjänster'**
  String get consentBasicServices;

  /// No description provided for @consentBasicServicesDescription.
  ///
  /// In sv, this message translates to:
  /// **'Autentisering, säkerhet och grundläggande funktioner.'**
  String get consentBasicServicesDescription;

  /// No description provided for @consentDataProcessing.
  ///
  /// In sv, this message translates to:
  /// **'Databehandling'**
  String get consentDataProcessing;

  /// No description provided for @consentDataProcessingDescription.
  ///
  /// In sv, this message translates to:
  /// **'Lagring och behandling av recept, menyer och inköpslistor.'**
  String get consentDataProcessingDescription;

  /// No description provided for @consentOptionalTitle.
  ///
  /// In sv, this message translates to:
  /// **'Valfria samtycken'**
  String get consentOptionalTitle;

  /// No description provided for @consentOptionalDescription.
  ///
  /// In sv, this message translates to:
  /// **'Du kan när som helst aktivera eller inaktivera dessa samtycken.'**
  String get consentOptionalDescription;

  /// No description provided for @consentRejectAll.
  ///
  /// In sv, this message translates to:
  /// **'Avvisa alla'**
  String get consentRejectAll;

  /// No description provided for @consentAnalytics.
  ///
  /// In sv, this message translates to:
  /// **'Analysdata'**
  String get consentAnalytics;

  /// No description provided for @consentAnalyticsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Hjälp oss förbättra appen genom att dela användningsstatistik. Vi samlar in information om hur du använder appen för att identifiera buggar och förbättra användarupplevelsen.'**
  String get consentAnalyticsDescription;

  /// No description provided for @consentMarketing.
  ///
  /// In sv, this message translates to:
  /// **'Marknadsföring'**
  String get consentMarketing;

  /// No description provided for @consentMarketingDescription.
  ///
  /// In sv, this message translates to:
  /// **'Ta emot nyhetsbrev och erbjudanden om nya funktioner, recept och uppdateringar via e-post.'**
  String get consentMarketingDescription;

  /// No description provided for @consentSocialFeatures.
  ///
  /// In sv, this message translates to:
  /// **'Sociala funktioner'**
  String get consentSocialFeatures;

  /// No description provided for @consentSocialFeaturesDescription.
  ///
  /// In sv, this message translates to:
  /// **'Dela dina recept med vänner, se andras skapelser och delta i communityn.'**
  String get consentSocialFeaturesDescription;

  /// No description provided for @consentPushNotifications.
  ///
  /// In sv, this message translates to:
  /// **'Push-notiser'**
  String get consentPushNotifications;

  /// No description provided for @consentPushNotificationsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Få meddelanden om kommentarer på dina recept, när vänner delar med dig och andra aktiviteter.'**
  String get consentPushNotificationsDescription;

  /// No description provided for @consentGoodToKnow.
  ///
  /// In sv, this message translates to:
  /// **'Bra att veta'**
  String get consentGoodToKnow;

  /// No description provided for @consentInfoImmediate.
  ///
  /// In sv, this message translates to:
  /// **'Dina ändringar träder i kraft omedelbart'**
  String get consentInfoImmediate;

  /// No description provided for @consentInfoChangeAnytime.
  ///
  /// In sv, this message translates to:
  /// **'Du kan ändra dina samtycken när som helst'**
  String get consentInfoChangeAnytime;

  /// No description provided for @consentInfoHistory.
  ///
  /// In sv, this message translates to:
  /// **'Vi sparar en historik av dina samtycken för att följa GDPR'**
  String get consentInfoHistory;

  /// No description provided for @consentInfoRevoke.
  ///
  /// In sv, this message translates to:
  /// **'Att återkalla samtycken påverkar inte tidigare behandling'**
  String get consentInfoRevoke;

  /// No description provided for @consentSaved.
  ///
  /// In sv, this message translates to:
  /// **'Samtycken har sparats'**
  String get consentSaved;

  /// No description provided for @consentRevokeAllTitle.
  ///
  /// In sv, this message translates to:
  /// **'Återkalla alla valfria samtycken?'**
  String get consentRevokeAllTitle;

  /// No description provided for @consentRevokeAllMessage.
  ///
  /// In sv, this message translates to:
  /// **'Detta kommer att inaktivera alla valfria funktioner som analysdata, marknadsföring, sociala funktioner och push-notiser. Du kan aktivera dem igen när som helst.'**
  String get consentRevokeAllMessage;

  /// No description provided for @consentRevokeAll.
  ///
  /// In sv, this message translates to:
  /// **'Återkalla alla'**
  String get consentRevokeAll;

  /// No description provided for @consentAllRevoked.
  ///
  /// In sv, this message translates to:
  /// **'Alla valfria samtycken har återkallats'**
  String get consentAllRevoked;

  /// No description provided for @dataExportTitle.
  ///
  /// In sv, this message translates to:
  /// **'Exportera mina data'**
  String get dataExportTitle;

  /// No description provided for @dataExportDownloadTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ladda ner dina data'**
  String get dataExportDownloadTitle;

  /// No description provided for @dataExportGdprDescription.
  ///
  /// In sv, this message translates to:
  /// **'Enligt GDPR Artikel 20 har du rätt att få en kopia av all din personliga data som lagras i Butlery. Data exporteras i JSON-format som du kan spara eller överföra till en annan tjänst.'**
  String get dataExportGdprDescription;

  /// No description provided for @dataExportExporting.
  ///
  /// In sv, this message translates to:
  /// **'Exporterar dina data...'**
  String get dataExportExporting;

  /// No description provided for @dataExportMayTakeSeconds.
  ///
  /// In sv, this message translates to:
  /// **'Detta kan ta några sekunder'**
  String get dataExportMayTakeSeconds;

  /// No description provided for @dataExportFailed.
  ///
  /// In sv, this message translates to:
  /// **'Export misslyckades'**
  String get dataExportFailed;

  /// No description provided for @dataExportSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Data exporterad'**
  String get dataExportSuccess;

  /// No description provided for @dataExportExportedAt.
  ///
  /// In sv, this message translates to:
  /// **'Exporterad'**
  String get dataExportExportedAt;

  /// No description provided for @dataExportFileSize.
  ///
  /// In sv, this message translates to:
  /// **'Filstorlek'**
  String get dataExportFileSize;

  /// No description provided for @dataExportSaveFile.
  ///
  /// In sv, this message translates to:
  /// **'Spara fil'**
  String get dataExportSaveFile;

  /// No description provided for @dataExportClear.
  ///
  /// In sv, this message translates to:
  /// **'Rensa export'**
  String get dataExportClear;

  /// No description provided for @dataExportWhatsIncluded.
  ///
  /// In sv, this message translates to:
  /// **'Vad ingår i exporten?'**
  String get dataExportWhatsIncluded;

  /// No description provided for @dataExportIncludesProfile.
  ///
  /// In sv, this message translates to:
  /// **'Profil och inställningar'**
  String get dataExportIncludesProfile;

  /// No description provided for @dataExportIncludesRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Alla dina recept'**
  String get dataExportIncludesRecipes;

  /// No description provided for @dataExportIncludesFriends.
  ///
  /// In sv, this message translates to:
  /// **'Vänner och sociala kontakter'**
  String get dataExportIncludesFriends;

  /// No description provided for @dataExportIncludesMessages.
  ///
  /// In sv, this message translates to:
  /// **'Meddelanden och konversationer'**
  String get dataExportIncludesMessages;

  /// No description provided for @dataExportIncludesLists.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslistor och menyer'**
  String get dataExportIncludesLists;

  /// No description provided for @dataExportIncludesComments.
  ///
  /// In sv, this message translates to:
  /// **'Kommentarer och betyg'**
  String get dataExportIncludesComments;

  /// No description provided for @dataExportIncludesActivity.
  ///
  /// In sv, this message translates to:
  /// **'Aktivitetshistorik'**
  String get dataExportIncludesActivity;

  /// No description provided for @dataExportOnlyYourData.
  ///
  /// In sv, this message translates to:
  /// **'OBS: Exporten innehåller endast din egen data. Ingen data från andra användare inkluderas.'**
  String get dataExportOnlyYourData;

  /// No description provided for @dateToday.
  ///
  /// In sv, this message translates to:
  /// **'Idag'**
  String get dateToday;

  /// No description provided for @dateYesterday.
  ///
  /// In sv, this message translates to:
  /// **'Igår'**
  String get dateYesterday;

  /// No description provided for @dateDaysAgo.
  ///
  /// In sv, this message translates to:
  /// **'{days} dagar sedan'**
  String dateDaysAgo(int days);

  /// No description provided for @dateWeeksAgo.
  ///
  /// In sv, this message translates to:
  /// **'{weeks} veckor sedan'**
  String dateWeeksAgo(int weeks);

  /// No description provided for @dateMonthsAgo.
  ///
  /// In sv, this message translates to:
  /// **'{months} månader sedan'**
  String dateMonthsAgo(int months);

  /// No description provided for @friendAccept.
  ///
  /// In sv, this message translates to:
  /// **'Acceptera'**
  String get friendAccept;

  /// No description provided for @friendDecline.
  ///
  /// In sv, this message translates to:
  /// **'Avvisa'**
  String get friendDecline;

  /// No description provided for @friendRequestTitle.
  ///
  /// In sv, this message translates to:
  /// **'Vänförfrågan'**
  String get friendRequestTitle;

  /// No description provided for @friendWantsToBeFriend.
  ///
  /// In sv, this message translates to:
  /// **'Vill bli din vän'**
  String get friendWantsToBeFriend;

  /// No description provided for @imageAddCount.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till ({count})'**
  String imageAddCount(int count);

  /// No description provided for @imageAddImages.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till bilder'**
  String get imageAddImages;

  /// No description provided for @imageAdding.
  ///
  /// In sv, this message translates to:
  /// **'Lägger till...'**
  String get imageAdding;

  /// No description provided for @imageAddingImage.
  ///
  /// In sv, this message translates to:
  /// **'Lägger till bild...'**
  String get imageAddingImage;

  /// No description provided for @imagePermissionMessage.
  ///
  /// In sv, this message translates to:
  /// **'Butlery behöver tillgång till din {permission} för att kunna lägga till bilder till recept. Gå till inställningar för att ge behörighet.'**
  String imagePermissionMessage(String permission);

  /// No description provided for @imagePermissionRequired.
  ///
  /// In sv, this message translates to:
  /// **'Behörighet krävs'**
  String get imagePermissionRequired;

  /// No description provided for @imagePrimary.
  ///
  /// In sv, this message translates to:
  /// **'Primär'**
  String get imagePrimary;

  /// No description provided for @imageSelectExistingFromGallery.
  ///
  /// In sv, this message translates to:
  /// **'Välj en befintlig bild från ditt galleri'**
  String get imageSelectExistingFromGallery;

  /// No description provided for @imageSelectSource.
  ///
  /// In sv, this message translates to:
  /// **'Välj bildkälla'**
  String get imageSelectSource;

  /// No description provided for @imageTapToAddUpTo.
  ///
  /// In sv, this message translates to:
  /// **'Tryck för att lägga till upp till {count} bilder'**
  String imageTapToAddUpTo(int count);

  /// No description provided for @imageTapToLoad.
  ///
  /// In sv, this message translates to:
  /// **'Tryck för att ladda'**
  String get imageTapToLoad;

  /// No description provided for @imageUploadingImages.
  ///
  /// In sv, this message translates to:
  /// **'Laddar upp bilder'**
  String get imageUploadingImages;

  /// No description provided for @imageUploadPreparing.
  ///
  /// In sv, this message translates to:
  /// **'Förbereder...'**
  String get imageUploadPreparing;

  /// No description provided for @imageUseCameraForNewPhoto.
  ///
  /// In sv, this message translates to:
  /// **'Använd kameran för att ta en ny bild'**
  String get imageUseCameraForNewPhoto;

  /// No description provided for @importAddIngredient.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till ingrediens'**
  String get importAddIngredient;

  /// No description provided for @importAddStep.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till steg'**
  String get importAddStep;

  /// No description provided for @importCancelConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Avbryt import'**
  String get importCancelConfirm;

  /// No description provided for @importCancelMessage.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill avbryta? Alla val kommer att förloras.'**
  String get importCancelMessage;

  /// No description provided for @importCancelTitle.
  ///
  /// In sv, this message translates to:
  /// **'Avbryt import?'**
  String get importCancelTitle;

  /// No description provided for @importDescriptionHint.
  ///
  /// In sv, this message translates to:
  /// **'Kort beskrivning (valfritt)'**
  String get importDescriptionHint;

  /// No description provided for @importManualTitle.
  ///
  /// In sv, this message translates to:
  /// **'Manuell import'**
  String get importManualTitle;

  /// No description provided for @importMealBreakfast.
  ///
  /// In sv, this message translates to:
  /// **'Frukost'**
  String get importMealBreakfast;

  /// No description provided for @importMealDessert.
  ///
  /// In sv, this message translates to:
  /// **'Dessert'**
  String get importMealDessert;

  /// No description provided for @importMealDinner.
  ///
  /// In sv, this message translates to:
  /// **'Middag'**
  String get importMealDinner;

  /// No description provided for @importMealLunch.
  ///
  /// In sv, this message translates to:
  /// **'Lunch'**
  String get importMealLunch;

  /// No description provided for @importMealSnack.
  ///
  /// In sv, this message translates to:
  /// **'Mellanmål'**
  String get importMealSnack;

  /// No description provided for @importMealType.
  ///
  /// In sv, this message translates to:
  /// **'Måltid'**
  String get importMealType;

  /// No description provided for @importRecipeNameHint.
  ///
  /// In sv, this message translates to:
  /// **'Ange receptets namn'**
  String get importRecipeNameHint;

  /// No description provided for @importRecipeNameRequired.
  ///
  /// In sv, this message translates to:
  /// **'Receptnamn *'**
  String get importRecipeNameRequired;

  /// No description provided for @importSaveRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Spara recept'**
  String get importSaveRecipe;

  /// No description provided for @importSelectIngredients.
  ///
  /// In sv, this message translates to:
  /// **'Välj ingredienser'**
  String get importSelectIngredients;

  /// No description provided for @importSelectInstructions.
  ///
  /// In sv, this message translates to:
  /// **'Välj instruktioner'**
  String get importSelectInstructions;

  /// No description provided for @importStep1SelectIngredients.
  ///
  /// In sv, this message translates to:
  /// **'Steg 1: Välj ingredienser'**
  String get importStep1SelectIngredients;

  /// No description provided for @importStep2SelectInstructions.
  ///
  /// In sv, this message translates to:
  /// **'Steg 2: Välj instruktioner'**
  String get importStep2SelectInstructions;

  /// No description provided for @importStep3ReviewEdit.
  ///
  /// In sv, this message translates to:
  /// **'Steg 3: Granska och redigera'**
  String get importStep3ReviewEdit;

  /// No description provided for @menuCardMoreRecipes.
  ///
  /// In sv, this message translates to:
  /// **'+ {count} fler recept'**
  String menuCardMoreRecipes(int count);

  /// No description provided for @menuCardNoRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Inga recept i menyn'**
  String get menuCardNoRecipes;

  /// No description provided for @menuCardRecipeCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} recept'**
  String menuCardRecipeCount(int count);

  /// No description provided for @menuCardRecipesInMenu.
  ///
  /// In sv, this message translates to:
  /// **'Recept i menyn:'**
  String get menuCardRecipesInMenu;

  /// No description provided for @menuCardSharedMenu.
  ///
  /// In sv, this message translates to:
  /// **'Delad meny'**
  String get menuCardSharedMenu;

  /// No description provided for @menuCardSharedWithCount.
  ///
  /// In sv, this message translates to:
  /// **'Delad med {count} personer'**
  String menuCardSharedWithCount(int count);

  /// No description provided for @searchHint.
  ///
  /// In sv, this message translates to:
  /// **'sök...'**
  String get searchHint;

  /// No description provided for @shareFriendsSelectedCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} vän(ner) valda'**
  String shareFriendsSelectedCount(int count);

  /// No description provided for @shareGroupMembersCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} medlemmar'**
  String shareGroupMembersCount(int count);

  /// No description provided for @shareTabFriends.
  ///
  /// In sv, this message translates to:
  /// **'Vänner'**
  String get shareTabFriends;

  /// No description provided for @shareTabGroups.
  ///
  /// In sv, this message translates to:
  /// **'Grupper'**
  String get shareTabGroups;

  /// No description provided for @shoppingCardComplete.
  ///
  /// In sv, this message translates to:
  /// **'Klar'**
  String get shoppingCardComplete;

  /// No description provided for @shoppingCardCompleted.
  ///
  /// In sv, this message translates to:
  /// **'{count} slutförda'**
  String shoppingCardCompleted(int count);

  /// No description provided for @shoppingCardItemsOnList.
  ///
  /// In sv, this message translates to:
  /// **'Föremål på listan:'**
  String get shoppingCardItemsOnList;

  /// No description provided for @shoppingCardMoreItems.
  ///
  /// In sv, this message translates to:
  /// **'+ {count} fler föremål'**
  String shoppingCardMoreItems(int count);

  /// No description provided for @shoppingCardNoItems.
  ///
  /// In sv, this message translates to:
  /// **'Inga föremål i listan'**
  String get shoppingCardNoItems;

  /// No description provided for @shoppingCardSharedList.
  ///
  /// In sv, this message translates to:
  /// **'Delad lista'**
  String get shoppingCardSharedList;

  /// No description provided for @shoppingCardSharedWithCount.
  ///
  /// In sv, this message translates to:
  /// **'Delad med {count} personer'**
  String shoppingCardSharedWithCount(int count);

  /// No description provided for @adminYouAreAdmin.
  ///
  /// In sv, this message translates to:
  /// **'Du är administratör'**
  String get adminYouAreAdmin;

  /// No description provided for @chatCreatedDate.
  ///
  /// In sv, this message translates to:
  /// **'Skapad: {date}'**
  String chatCreatedDate(String date);

  /// No description provided for @chatMemberCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} medlemmar'**
  String chatMemberCount(int count);

  /// No description provided for @chatMute.
  ///
  /// In sv, this message translates to:
  /// **'Tysta'**
  String get chatMute;

  /// No description provided for @chatParticipantCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} deltagare'**
  String chatParticipantCount(int count);

  /// No description provided for @chatTitle.
  ///
  /// In sv, this message translates to:
  /// **'Chatt'**
  String get chatTitle;

  /// No description provided for @commonSearch.
  ///
  /// In sv, this message translates to:
  /// **'Sök'**
  String get commonSearch;

  /// No description provided for @commonUnknown.
  ///
  /// In sv, this message translates to:
  /// **'Okänd'**
  String get commonUnknown;

  /// No description provided for @dataExportClearConfirmMessage.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill rensa den exporterade datan? Du kan när som helst exportera igen.'**
  String get dataExportClearConfirmMessage;

  /// No description provided for @dataExportClearConfirmTitle.
  ///
  /// In sv, this message translates to:
  /// **'Rensa export?'**
  String get dataExportClearConfirmTitle;

  /// No description provided for @dataExportCleared.
  ///
  /// In sv, this message translates to:
  /// **'Export rensad'**
  String get dataExportCleared;

  /// No description provided for @dataExportCouldNotSaveFile.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara fil: {error}'**
  String dataExportCouldNotSaveFile(String error);

  /// No description provided for @dataExportCouldNotShare.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dela: {error}'**
  String dataExportCouldNotShare(String error);

  /// No description provided for @dataExportExportedSuccessfully.
  ///
  /// In sv, this message translates to:
  /// **'Data exporterad framgångsrikt'**
  String get dataExportExportedSuccessfully;

  /// No description provided for @dataExportFileSaved.
  ///
  /// In sv, this message translates to:
  /// **'Fil sparad: {fileName}'**
  String dataExportFileSaved(String fileName);

  /// No description provided for @dataExportShareSubject.
  ///
  /// In sv, this message translates to:
  /// **'Butlery Data Export'**
  String get dataExportShareSubject;

  /// No description provided for @dataExportShareText.
  ///
  /// In sv, this message translates to:
  /// **'Min exporterade data från Butlery app'**
  String get dataExportShareText;

  /// No description provided for @dialogAmountHint.
  ///
  /// In sv, this message translates to:
  /// **'Ange antal...'**
  String get dialogAmountHint;

  /// No description provided for @dialogAmountInvalid.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt antal'**
  String get dialogAmountInvalid;

  /// No description provided for @dialogAmountLabel.
  ///
  /// In sv, this message translates to:
  /// **'Antal'**
  String get dialogAmountLabel;

  /// No description provided for @dialogAmountMax.
  ///
  /// In sv, this message translates to:
  /// **'Max {max} tillåtet'**
  String dialogAmountMax(int max);

  /// No description provided for @dialogAmountMin.
  ///
  /// In sv, this message translates to:
  /// **'Minst {min} krävs'**
  String dialogAmountMin(int min);

  /// No description provided for @dialogAmountRequired.
  ///
  /// In sv, this message translates to:
  /// **'Antal krävs'**
  String get dialogAmountRequired;

  /// No description provided for @dialogDescriptionHint.
  ///
  /// In sv, this message translates to:
  /// **'Valfri beskrivning...'**
  String get dialogDescriptionHint;

  /// No description provided for @dialogDescriptionLabel.
  ///
  /// In sv, this message translates to:
  /// **'Beskrivning'**
  String get dialogDescriptionLabel;

  /// No description provided for @dialogFieldRequired.
  ///
  /// In sv, this message translates to:
  /// **'{field} krävs'**
  String dialogFieldRequired(String field);

  /// No description provided for @dialogInvalidUrl.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig URL'**
  String get dialogInvalidUrl;

  /// No description provided for @dialogPhoneInvalid.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt telefonnummer'**
  String get dialogPhoneInvalid;

  /// No description provided for @dialogPhoneLabel.
  ///
  /// In sv, this message translates to:
  /// **'Telefonnummer'**
  String get dialogPhoneLabel;

  /// No description provided for @dialogSearchHint.
  ///
  /// In sv, this message translates to:
  /// **'Skriv för att söka...'**
  String get dialogSearchHint;

  /// No description provided for @importLikely.
  ///
  /// In sv, this message translates to:
  /// **'Trolig'**
  String get importLikely;

  /// No description provided for @importNoLinesToShow.
  ///
  /// In sv, this message translates to:
  /// **'Inga rader att visa'**
  String get importNoLinesToShow;

  /// No description provided for @importSelectAllHighlighted.
  ///
  /// In sv, this message translates to:
  /// **'Välj alla markerade ({count})'**
  String importSelectAllHighlighted(int count);

  /// No description provided for @importSelectedCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} valda'**
  String importSelectedCount(int count);

  /// No description provided for @importStep.
  ///
  /// In sv, this message translates to:
  /// **'Steg'**
  String get importStep;

  /// No description provided for @importStepAnalyzing.
  ///
  /// In sv, this message translates to:
  /// **'Analyserar'**
  String get importStepAnalyzing;

  /// No description provided for @importStepCreating.
  ///
  /// In sv, this message translates to:
  /// **'Skapar'**
  String get importStepCreating;

  /// No description provided for @importStepFetching.
  ///
  /// In sv, this message translates to:
  /// **'Hämtar'**
  String get importStepFetching;

  /// No description provided for @invitationClearSearch.
  ///
  /// In sv, this message translates to:
  /// **'Rensa sökning'**
  String get invitationClearSearch;

  /// No description provided for @invitationCouldNotLoadTargets.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda mål'**
  String get invitationCouldNotLoadTargets;

  /// No description provided for @menuCreateBeforeSave.
  ///
  /// In sv, this message translates to:
  /// **'Skapa en meny först innan du kan spara den'**
  String get menuCreateBeforeSave;

  /// No description provided for @menuCreateBeforeShare.
  ///
  /// In sv, this message translates to:
  /// **'Skapa en meny först innan du kan dela den'**
  String get menuCreateBeforeShare;

  /// No description provided for @menuCreateBeforeShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Skapa en meny först innan du kan skapa inköpslista'**
  String get menuCreateBeforeShoppingList;

  /// No description provided for @menuDefaultName.
  ///
  /// In sv, this message translates to:
  /// **'Veckomeny ({count} recept)'**
  String menuDefaultName(int count);

  /// No description provided for @menuExitConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Avsluta'**
  String get menuExitConfirm;

  /// No description provided for @menuExitMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du verkligen avsluta appen?'**
  String get menuExitMessage;

  /// No description provided for @menuExitTitle.
  ///
  /// In sv, this message translates to:
  /// **'Avsluta Butlery?'**
  String get menuExitTitle;

  /// No description provided for @menuNameBeforeShare.
  ///
  /// In sv, this message translates to:
  /// **'Ge din meny ett namn innan du delar den:'**
  String get menuNameBeforeShare;

  /// No description provided for @menuNameHint.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. \"Min veckomeny v.45\"'**
  String get menuNameHint;

  /// No description provided for @menuNameYourMenu.
  ///
  /// In sv, this message translates to:
  /// **'Namnge din meny'**
  String get menuNameYourMenu;

  /// No description provided for @menuShareDefaultMessage.
  ///
  /// In sv, this message translates to:
  /// **'Kolla min veckomeny!'**
  String get menuShareDefaultMessage;

  /// No description provided for @messagingEdited.
  ///
  /// In sv, this message translates to:
  /// **'redigerad'**
  String get messagingEdited;

  /// No description provided for @messagingImageLoadError.
  ///
  /// In sv, this message translates to:
  /// **'Bild kunde inte laddas'**
  String get messagingImageLoadError;

  /// No description provided for @messagingImageLoadFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda bild'**
  String get messagingImageLoadFailed;

  /// No description provided for @messagingMenuShared.
  ///
  /// In sv, this message translates to:
  /// **'Meny delad'**
  String get messagingMenuShared;

  /// No description provided for @messagingRecipeShared.
  ///
  /// In sv, this message translates to:
  /// **'Recept delat'**
  String get messagingRecipeShared;

  /// No description provided for @messagingShoppingListShared.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslista delad'**
  String get messagingShoppingListShared;

  /// No description provided for @messagingUnknownMenu.
  ///
  /// In sv, this message translates to:
  /// **'Okänd meny'**
  String get messagingUnknownMenu;

  /// No description provided for @messagingUnknownRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Okänt recept'**
  String get messagingUnknownRecipe;

  /// No description provided for @messagingUnknownShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Okänd inköpslista'**
  String get messagingUnknownShoppingList;

  /// No description provided for @messagingVoiceMessage.
  ///
  /// In sv, this message translates to:
  /// **'Röstmeddelande'**
  String get messagingVoiceMessage;

  /// No description provided for @messagingAddFriendsToCreateGroups.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vänner för att skapa gruppkonversationer'**
  String get messagingAddFriendsToCreateGroups;

  /// No description provided for @messagingAllFriendsAlreadyInGroup.
  ///
  /// In sv, this message translates to:
  /// **'Alla dina vänner är redan med i gruppen'**
  String get messagingAllFriendsAlreadyInGroup;

  /// No description provided for @messagingCouldNotAddMembers.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lägga till medlemmar'**
  String get messagingCouldNotAddMembers;

  /// No description provided for @messagingCouldNotLoadFriends.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda vänner: {error}'**
  String messagingCouldNotLoadFriends(String error);

  /// No description provided for @messagingCouldNotLoadGroupInfo.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda gruppinformation: {error}'**
  String messagingCouldNotLoadGroupInfo(String error);

  /// No description provided for @messagingCouldNotRemoveMember.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort medlem'**
  String get messagingCouldNotRemoveMember;

  /// No description provided for @messagingCouldNotUpdateGroupName.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera gruppnamn'**
  String get messagingCouldNotUpdateGroupName;

  /// No description provided for @messagingCreateGroup.
  ///
  /// In sv, this message translates to:
  /// **'Skapa gruppkonversation'**
  String get messagingCreateGroup;

  /// No description provided for @messagingEditGroupName.
  ///
  /// In sv, this message translates to:
  /// **'Redigera gruppnamn'**
  String get messagingEditGroupName;

  /// No description provided for @messagingEnterNewGroupName.
  ///
  /// In sv, this message translates to:
  /// **'Ange nytt gruppnamn'**
  String get messagingEnterNewGroupName;

  /// No description provided for @messagingFriendsCount.
  ///
  /// In sv, this message translates to:
  /// **'Vänner ({count})'**
  String messagingFriendsCount(int count);

  /// No description provided for @messagingFromGroup.
  ///
  /// In sv, this message translates to:
  /// **'från gruppen'**
  String get messagingFromGroup;

  /// No description provided for @messagingGroupCreated.
  ///
  /// In sv, this message translates to:
  /// **'Gruppkonversation skapad!'**
  String get messagingGroupCreated;

  /// No description provided for @messagingGroupName.
  ///
  /// In sv, this message translates to:
  /// **'Gruppnamn'**
  String get messagingGroupName;

  /// No description provided for @messagingGroupNameHint.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. Min familj, Jobbet, Bästa vännerna...'**
  String get messagingGroupNameHint;

  /// No description provided for @messagingGroupNameUpdated.
  ///
  /// In sv, this message translates to:
  /// **'Gruppnamn uppdaterat'**
  String get messagingGroupNameUpdated;

  /// No description provided for @messagingGroupNoLongerExists.
  ///
  /// In sv, this message translates to:
  /// **'Denna grupp finns inte längre'**
  String get messagingGroupNoLongerExists;

  /// No description provided for @messagingGroupNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Grupp hittades inte'**
  String get messagingGroupNotFound;

  /// No description provided for @messagingLeaveGroupConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill lämna denna grupp? Du kommer inte längre kunna se meddelanden i gruppen.'**
  String get messagingLeaveGroupConfirm;

  /// No description provided for @messagingLoadingFriends.
  ///
  /// In sv, this message translates to:
  /// **'Laddar vänner...'**
  String get messagingLoadingFriends;

  /// No description provided for @messagingLoadingGroupInfo.
  ///
  /// In sv, this message translates to:
  /// **'Laddar gruppinformation...'**
  String get messagingLoadingGroupInfo;

  /// No description provided for @messagingMembersAdded.
  ///
  /// In sv, this message translates to:
  /// **'{count} medlem(mar) tillagda'**
  String messagingMembersAdded(int count);

  /// No description provided for @messagingMembersCount.
  ///
  /// In sv, this message translates to:
  /// **'Medlemmar ({count})'**
  String messagingMembersCount(int count);

  /// No description provided for @messagingMemberRemoved.
  ///
  /// In sv, this message translates to:
  /// **'{name} borttagen från gruppen'**
  String messagingMemberRemoved(String name);

  /// No description provided for @messagingNoFriendsAvailable.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner tillgängliga'**
  String get messagingNoFriendsAvailable;

  /// No description provided for @messagingNoFriendsFound.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner hittades'**
  String get messagingNoFriendsFound;

  /// No description provided for @messagingSearchFriends.
  ///
  /// In sv, this message translates to:
  /// **'Sök vänner...'**
  String get messagingSearchFriends;

  /// No description provided for @messagingSelectAtLeastTwoMembers.
  ///
  /// In sv, this message translates to:
  /// **'Välj minst 2 medlemmar nedan'**
  String get messagingSelectAtLeastTwoMembers;

  /// No description provided for @messagingSelectedMembers.
  ///
  /// In sv, this message translates to:
  /// **'Valda medlemmar ({count})'**
  String messagingSelectedMembers(int count);

  /// No description provided for @messagingTryAnotherKeyword.
  ///
  /// In sv, this message translates to:
  /// **'Försök med ett annat sökord'**
  String get messagingTryAnotherKeyword;

  /// No description provided for @mfaCodeSentTo.
  ///
  /// In sv, this message translates to:
  /// **'En verifieringskod har skickats till {phone}.'**
  String mfaCodeSentTo(String phone);

  /// No description provided for @mfaEnterCode.
  ///
  /// In sv, this message translates to:
  /// **'Ange verifieringskoden'**
  String get mfaEnterCode;

  /// No description provided for @mfaInvalidCode.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig kod. Försök igen.'**
  String get mfaInvalidCode;

  /// No description provided for @mfaNoPhoneFactor.
  ///
  /// In sv, this message translates to:
  /// **'Ingen telefonverifiering konfigurerad.'**
  String get mfaNoPhoneFactor;

  /// No description provided for @mfaQuotaExceeded.
  ///
  /// In sv, this message translates to:
  /// **'För många försök. Försök igen senare.'**
  String get mfaQuotaExceeded;

  /// No description provided for @mfaResend.
  ///
  /// In sv, this message translates to:
  /// **'Skicka igen'**
  String get mfaResend;

  /// No description provided for @mfaSendingCode.
  ///
  /// In sv, this message translates to:
  /// **'Skickar verifieringskod...'**
  String get mfaSendingCode;

  /// No description provided for @mfaSendingTo.
  ///
  /// In sv, this message translates to:
  /// **'Till: {phone}'**
  String mfaSendingTo(String phone);

  /// No description provided for @mfaSessionExpired.
  ///
  /// In sv, this message translates to:
  /// **'Sessionen har gått ut. Försök logga in igen.'**
  String get mfaSessionExpired;

  /// No description provided for @mfaSixDigitCode.
  ///
  /// In sv, this message translates to:
  /// **'6-siffrig kod'**
  String get mfaSixDigitCode;

  /// No description provided for @mfaTitle.
  ///
  /// In sv, this message translates to:
  /// **'Tvåfaktorsverifiering'**
  String get mfaTitle;

  /// No description provided for @mfaVerificationFailed.
  ///
  /// In sv, this message translates to:
  /// **'Verifiering misslyckades'**
  String get mfaVerificationFailed;

  /// No description provided for @mfaVerify.
  ///
  /// In sv, this message translates to:
  /// **'Verifiera'**
  String get mfaVerify;

  /// No description provided for @mfaYourPhone.
  ///
  /// In sv, this message translates to:
  /// **'ditt telefonnummer'**
  String get mfaYourPhone;

  /// No description provided for @mfaAccountProtected.
  ///
  /// In sv, this message translates to:
  /// **'Ditt konto är skyddat med tvåfaktorsautentisering.'**
  String get mfaAccountProtected;

  /// No description provided for @mfaActivated.
  ///
  /// In sv, this message translates to:
  /// **'MFA aktiverat!'**
  String get mfaActivated;

  /// No description provided for @mfaAddPhoneNumber.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till telefonnummer'**
  String get mfaAddPhoneNumber;

  /// No description provided for @mfaCouldNotRemove.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort MFA'**
  String get mfaCouldNotRemove;

  /// No description provided for @mfaDeactivated.
  ///
  /// In sv, this message translates to:
  /// **'MFA inaktiverat'**
  String get mfaDeactivated;

  /// No description provided for @mfaDisabled.
  ///
  /// In sv, this message translates to:
  /// **'MFA inaktiverat'**
  String get mfaDisabled;

  /// No description provided for @mfaEnabled.
  ///
  /// In sv, this message translates to:
  /// **'MFA aktiverat'**
  String get mfaEnabled;

  /// No description provided for @mfaEnableForSecurity.
  ///
  /// In sv, this message translates to:
  /// **'Aktivera MFA för extra säkerhet.'**
  String get mfaEnableForSecurity;

  /// No description provided for @mfaEnterPhoneNumber.
  ///
  /// In sv, this message translates to:
  /// **'Ange ett telefonnummer'**
  String get mfaEnterPhoneNumber;

  /// No description provided for @mfaEnterVerificationCode.
  ///
  /// In sv, this message translates to:
  /// **'Ange verifieringskod'**
  String get mfaEnterVerificationCode;

  /// No description provided for @mfaInvalidPhoneNumber.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt telefonnummer. Ange med landskod (+46).'**
  String get mfaInvalidPhoneNumber;

  /// No description provided for @mfaPhone.
  ///
  /// In sv, this message translates to:
  /// **'Telefon'**
  String get mfaPhone;

  /// No description provided for @mfaPhoneNumber.
  ///
  /// In sv, this message translates to:
  /// **'Telefonnummer'**
  String get mfaPhoneNumber;

  /// No description provided for @mfaRegistered.
  ///
  /// In sv, this message translates to:
  /// **'Registrerad: {time}'**
  String mfaRegistered(String time);

  /// No description provided for @mfaRegisteredMethods.
  ///
  /// In sv, this message translates to:
  /// **'Registrerade metoder'**
  String get mfaRegisteredMethods;

  /// No description provided for @mfaRemoveConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill inaktivera tvåfaktorsautentisering? Detta gör ditt konto mindre säkert.'**
  String get mfaRemoveConfirm;

  /// No description provided for @mfaRemoveTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort MFA?'**
  String get mfaRemoveTitle;

  /// No description provided for @mfaSendCode.
  ///
  /// In sv, this message translates to:
  /// **'Skicka kod'**
  String get mfaSendCode;

  /// No description provided for @mfaSmsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Vi skickar en verifieringskod via SMS när du loggar in.'**
  String get mfaSmsDescription;

  /// No description provided for @realtimeOffline.
  ///
  /// In sv, this message translates to:
  /// **'Offline'**
  String get realtimeOffline;

  /// No description provided for @recipeMealType.
  ///
  /// In sv, this message translates to:
  /// **'Måltidstyp'**
  String get recipeMealType;

  /// No description provided for @recipeTitle.
  ///
  /// In sv, this message translates to:
  /// **'Titel'**
  String get recipeTitle;

  /// No description provided for @recipeUpdating.
  ///
  /// In sv, this message translates to:
  /// **'Uppdaterar recept...'**
  String get recipeUpdating;

  /// No description provided for @chatAddCount.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till ({count})'**
  String chatAddCount(int count);

  /// No description provided for @chatAddMembers.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till medlemmar'**
  String get chatAddMembers;

  /// No description provided for @chatSearchFriends.
  ///
  /// In sv, this message translates to:
  /// **'Sök vänner...'**
  String get chatSearchFriends;

  /// No description provided for @collaborativeContent.
  ///
  /// In sv, this message translates to:
  /// **'Innehåll'**
  String get collaborativeContent;

  /// No description provided for @collaborativeEditingTogether.
  ///
  /// In sv, this message translates to:
  /// **'Du redigerar tillsammans med andra'**
  String get collaborativeEditingTogether;

  /// No description provided for @collaborativeOffline.
  ///
  /// In sv, this message translates to:
  /// **'Offline'**
  String get collaborativeOffline;

  /// No description provided for @collaborativeOnline.
  ///
  /// In sv, this message translates to:
  /// **'Online'**
  String get collaborativeOnline;

  /// No description provided for @collaborativeShared.
  ///
  /// In sv, this message translates to:
  /// **'Delat'**
  String get collaborativeShared;

  /// No description provided for @collaborativeSharedContent.
  ///
  /// In sv, this message translates to:
  /// **'Delat innehåll'**
  String get collaborativeSharedContent;

  /// No description provided for @collaborativeSharedWithCount.
  ///
  /// In sv, this message translates to:
  /// **'Delat med {count} personer'**
  String collaborativeSharedWithCount(int count);

  /// No description provided for @collaborativeSyncAutomatic.
  ///
  /// In sv, this message translates to:
  /// **'Ändringar synkas automatiskt med andra deltagare'**
  String get collaborativeSyncAutomatic;

  /// No description provided for @conversationAddFriendsFirst.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vänner först för att starta konversationer.'**
  String get conversationAddFriendsFirst;

  /// No description provided for @conversationCreateError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa konversation: {error}'**
  String conversationCreateError(String error);

  /// No description provided for @conversationCreateGroup.
  ///
  /// In sv, this message translates to:
  /// **'Skapa gruppkonversation'**
  String get conversationCreateGroup;

  /// No description provided for @conversationGroupChatWith.
  ///
  /// In sv, this message translates to:
  /// **'Gruppchatt med {names}'**
  String conversationGroupChatWith(String names);

  /// No description provided for @conversationGroupCreated.
  ///
  /// In sv, this message translates to:
  /// **'Grupp skapad'**
  String get conversationGroupCreated;

  /// No description provided for @conversationNew.
  ///
  /// In sv, this message translates to:
  /// **'Ny konversation'**
  String get conversationNew;

  /// No description provided for @conversationNoFriendsMatch.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner matchar din sökning'**
  String get conversationNoFriendsMatch;

  /// No description provided for @conversationNoFriendsYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner ännu'**
  String get conversationNoFriendsYet;

  /// No description provided for @conversationSayHi.
  ///
  /// In sv, this message translates to:
  /// **'Säg hej!'**
  String get conversationSayHi;

  /// No description provided for @conversationSelectFriendForDM.
  ///
  /// In sv, this message translates to:
  /// **'Eller välj en vän för direktmeddelande:'**
  String get conversationSelectFriendForDM;

  /// No description provided for @conversationYouPrefix.
  ///
  /// In sv, this message translates to:
  /// **'Du:'**
  String get conversationYouPrefix;

  /// No description provided for @errorDeletingWithDetails.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid borttagning: {error}'**
  String errorDeletingWithDetails(String error);

  /// No description provided for @errorLoadingFailed.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid laddning'**
  String get errorLoadingFailed;

  /// No description provided for @errorLoadingWithDetails.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid laddning: {error}'**
  String errorLoadingWithDetails(String error);

  /// No description provided for @errorUnknown.
  ///
  /// In sv, this message translates to:
  /// **'Okänt fel'**
  String get errorUnknown;

  /// No description provided for @imageSelectImage.
  ///
  /// In sv, this message translates to:
  /// **'Välj bild'**
  String get imageSelectImage;

  /// No description provided for @imageTitle.
  ///
  /// In sv, this message translates to:
  /// **'Bild'**
  String get imageTitle;

  /// No description provided for @importAllCount.
  ///
  /// In sv, this message translates to:
  /// **'Importera alla ({count})'**
  String importAllCount(int count);

  /// No description provided for @importColumnCategory.
  ///
  /// In sv, this message translates to:
  /// **'Kategori (category/kategori)'**
  String get importColumnCategory;

  /// No description provided for @importColumnCookingTime.
  ///
  /// In sv, this message translates to:
  /// **'Tillagningstid (cookingtime/tid)'**
  String get importColumnCookingTime;

  /// No description provided for @importColumnIngredients.
  ///
  /// In sv, this message translates to:
  /// **'Ingredienser (ingredients/ingredienser)'**
  String get importColumnIngredients;

  /// No description provided for @importColumnInstructions.
  ///
  /// In sv, this message translates to:
  /// **'Instruktioner (instructions/instruktioner)'**
  String get importColumnInstructions;

  /// No description provided for @importColumnServings.
  ///
  /// In sv, this message translates to:
  /// **'Portioner (servings/portioner)'**
  String get importColumnServings;

  /// No description provided for @importColumnTags.
  ///
  /// In sv, this message translates to:
  /// **'Taggar (tags/taggar)'**
  String get importColumnTags;

  /// No description provided for @importColumnTitle.
  ///
  /// In sv, this message translates to:
  /// **'Titel (title/namn)'**
  String get importColumnTitle;

  /// No description provided for @importComplete.
  ///
  /// In sv, this message translates to:
  /// **'Import klar: {succeeded} lyckades, {failed} misslyckades'**
  String importComplete(int succeeded, int failed);

  /// No description provided for @importEditTextBeforeImport.
  ///
  /// In sv, this message translates to:
  /// **'Redigera text innan import'**
  String get importEditTextBeforeImport;

  /// No description provided for @importEditTextHint.
  ///
  /// In sv, this message translates to:
  /// **'Du kan redigera den extraherade texten här...'**
  String get importEditTextHint;

  /// No description provided for @importExtractedText.
  ///
  /// In sv, this message translates to:
  /// **'Extraherad text:'**
  String get importExtractedText;

  /// No description provided for @importFailed.
  ///
  /// In sv, this message translates to:
  /// **'Import misslyckades: {error}'**
  String importFailed(String error);

  /// No description provided for @importFailedCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} misslyckades'**
  String importFailedCount(int count);

  /// No description provided for @importFetching.
  ///
  /// In sv, this message translates to:
  /// **'Hämtar...'**
  String get importFetching;

  /// No description provided for @importFetchText.
  ///
  /// In sv, this message translates to:
  /// **'Hämta text'**
  String get importFetchText;

  /// No description provided for @importFileColumnsOptional.
  ///
  /// In sv, this message translates to:
  /// **'Valfria kolumner:'**
  String get importFileColumnsOptional;

  /// No description provided for @importFileColumnsRequired.
  ///
  /// In sv, this message translates to:
  /// **'Din fil bör innehålla kolumner för:'**
  String get importFileColumnsRequired;

  /// No description provided for @importFilterAll.
  ///
  /// In sv, this message translates to:
  /// **'Alla'**
  String get importFilterAll;

  /// No description provided for @importFilterAllTimes.
  ///
  /// In sv, this message translates to:
  /// **'Alla tider'**
  String get importFilterAllTimes;

  /// No description provided for @importFromArchive.
  ///
  /// In sv, this message translates to:
  /// **'Importera från Butlerys arkiv'**
  String get importFromArchive;

  /// No description provided for @importFromFile.
  ///
  /// In sv, this message translates to:
  /// **'Importera från fil'**
  String get importFromFile;

  /// No description provided for @importFromFileTitle.
  ///
  /// In sv, this message translates to:
  /// **'Importera recept från CSV eller Excel'**
  String get importFromFileTitle;

  /// No description provided for @importFromSocialMedia.
  ///
  /// In sv, this message translates to:
  /// **'Från sociala medier'**
  String get importFromSocialMedia;

  /// No description provided for @importImporting.
  ///
  /// In sv, this message translates to:
  /// **'Importerar...'**
  String get importImporting;

  /// No description provided for @importImportingRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Importerar {count} recept...'**
  String importImportingRecipes(int count);

  /// No description provided for @importImportingRecipesProgress.
  ///
  /// In sv, this message translates to:
  /// **'Importerar recept...'**
  String get importImportingRecipesProgress;

  /// No description provided for @importNoFileOrNoRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Ingen fil vald eller filen innehåller inga recept'**
  String get importNoFileOrNoRecipes;

  /// No description provided for @importNoRecipesMatchedFilters.
  ///
  /// In sv, this message translates to:
  /// **'Inga recept matchade filtren'**
  String get importNoRecipesMatchedFilters;

  /// No description provided for @importParsingText.
  ///
  /// In sv, this message translates to:
  /// **'Tolkar text...'**
  String get importParsingText;

  /// No description provided for @importPasteRecipeHint.
  ///
  /// In sv, this message translates to:
  /// **'Klistra in recepttext här...'**
  String get importPasteRecipeHint;

  /// No description provided for @importPasteRecipeUrl.
  ///
  /// In sv, this message translates to:
  /// **'Klistra in recept-URL'**
  String get importPasteRecipeUrl;

  /// No description provided for @importPreviewAndEdit.
  ///
  /// In sv, this message translates to:
  /// **'Förhandsgranska och redigera'**
  String get importPreviewAndEdit;

  /// No description provided for @importProceedToPaste.
  ///
  /// In sv, this message translates to:
  /// **'Gå vidare till klistra-in'**
  String get importProceedToPaste;

  /// No description provided for @importRecipesImported.
  ///
  /// In sv, this message translates to:
  /// **'Recept importerade!'**
  String get importRecipesImported;

  /// No description provided for @importSearchArchive.
  ///
  /// In sv, this message translates to:
  /// **'Sök i arkiv...'**
  String get importSearchArchive;

  /// No description provided for @importSelectFileAndImport.
  ///
  /// In sv, this message translates to:
  /// **'Välj fil och importera'**
  String get importSelectFileAndImport;

  /// No description provided for @importSelectingFile.
  ///
  /// In sv, this message translates to:
  /// **'Väljer fil...'**
  String get importSelectingFile;

  /// No description provided for @importShowError.
  ///
  /// In sv, this message translates to:
  /// **'Visa fel'**
  String get importShowError;

  /// No description provided for @importSucceededCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} lyckades'**
  String importSucceededCount(int count);

  /// No description provided for @importTagsCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} taggar'**
  String importTagsCount(int count);

  /// No description provided for @importTipsContent.
  ///
  /// In sv, this message translates to:
  /// **'Klistra in hela receptet inklusive ingredienser. Se till att ingredienser kommer före instruktioner. Texten kan komma från Instagram, TikTok, Facebook etc.'**
  String get importTipsContent;

  /// No description provided for @importTipsTitle.
  ///
  /// In sv, this message translates to:
  /// **'Tips för bästa resultat'**
  String get importTipsTitle;

  /// No description provided for @importTryAdjustFilters.
  ///
  /// In sv, this message translates to:
  /// **'Prova att justera sökning eller filter'**
  String get importTryAdjustFilters;

  /// No description provided for @importViaUrl.
  ///
  /// In sv, this message translates to:
  /// **'Import via URL'**
  String get importViaUrl;

  /// No description provided for @indicatorOfflineMode.
  ///
  /// In sv, this message translates to:
  /// **'Offline-läge - Ändringar sparas lokalt'**
  String get indicatorOfflineMode;

  /// No description provided for @invitationCheckConnectionAndRetry.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollera din internetanslutning och försök igen.'**
  String get invitationCheckConnectionAndRetry;

  /// No description provided for @invitationCurrentItem.
  ///
  /// In sv, this message translates to:
  /// **'Aktuell: {item}'**
  String invitationCurrentItem(String item);

  /// No description provided for @invitationDone.
  ///
  /// In sv, this message translates to:
  /// **'Klar'**
  String get invitationDone;

  /// No description provided for @invitationNoFriendsOrGroupsYet.
  ///
  /// In sv, this message translates to:
  /// **'Du har inte lagt till några vänner eller grupper än.'**
  String get invitationNoFriendsOrGroupsYet;

  /// No description provided for @invitationNoSelectedTargets.
  ///
  /// In sv, this message translates to:
  /// **'Inga valda målgrupper'**
  String get invitationNoSelectedTargets;

  /// No description provided for @invitationProcessing.
  ///
  /// In sv, this message translates to:
  /// **'Bearbetar'**
  String get invitationProcessing;

  /// No description provided for @invitationRequestAccess.
  ///
  /// In sv, this message translates to:
  /// **'Begär åtkomst'**
  String get invitationRequestAccess;

  /// No description provided for @invitationSearchQuery.
  ///
  /// In sv, this message translates to:
  /// **'Sökning: \"{query}\"'**
  String invitationSearchQuery(String query);

  /// No description provided for @invitationSelectTargetsToContinue.
  ///
  /// In sv, this message translates to:
  /// **'Välj målgrupper från listan ovan för att fortsätta.'**
  String get invitationSelectTargetsToContinue;

  /// No description provided for @invitationSendingInvitations.
  ///
  /// In sv, this message translates to:
  /// **'Skickar inbjudningar...'**
  String get invitationSendingInvitations;

  /// No description provided for @invitationsSentMessage.
  ///
  /// In sv, this message translates to:
  /// **'Inbjudningar har skickats till {count} målgrupper.'**
  String invitationsSentMessage(int count);

  /// No description provided for @invitationsSentTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inbjudningar skickade'**
  String get invitationsSentTitle;

  /// No description provided for @invitationTargetsSelectedForInvitation.
  ///
  /// In sv, this message translates to:
  /// **'Du har valt {count} målgrupper för inbjudan.'**
  String invitationTargetsSelectedForInvitation(int count);

  /// No description provided for @invitationTryDifferentSearch.
  ///
  /// In sv, this message translates to:
  /// **'Prova att söka med andra ord eller kontrollera stavningen.'**
  String get invitationTryDifferentSearch;

  /// No description provided for @loadingNoContent.
  ///
  /// In sv, this message translates to:
  /// **'Inget innehåll'**
  String get loadingNoContent;

  /// No description provided for @menuCommentLabel.
  ///
  /// In sv, this message translates to:
  /// **'Kommentar (valfritt)'**
  String get menuCommentLabel;

  /// No description provided for @menuDeleteConfirmation.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill ta bort denna meny?'**
  String get menuDeleteConfirmation;

  /// No description provided for @menuDeletedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Meny \"{name}\" borttagen'**
  String menuDeletedSuccess(String name);

  /// No description provided for @menuDeleteFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort meny'**
  String get menuDeleteFailed;

  /// No description provided for @menuDeleteTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort meny'**
  String get menuDeleteTitle;

  /// No description provided for @menuLoadedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Meny \"{name}\" laddad!'**
  String menuLoadedSuccess(String name);

  /// No description provided for @menuLoadFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda meny'**
  String get menuLoadFailed;

  /// No description provided for @menuNameLabel.
  ///
  /// In sv, this message translates to:
  /// **'Menynamn'**
  String get menuNameLabel;

  /// No description provided for @menuNameRequired.
  ///
  /// In sv, this message translates to:
  /// **'Menynamn krävs'**
  String get menuNameRequired;

  /// No description provided for @menuNoSavedMenusDescription.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga sparade menyer än. Generera och spara en meny först!'**
  String get menuNoSavedMenusDescription;

  /// No description provided for @menuRecipesInCategories.
  ///
  /// In sv, this message translates to:
  /// **'{recipeCount} recept i {categoryCount} kategorier'**
  String menuRecipesInCategories(int recipeCount, int categoryCount);

  /// No description provided for @menuSavedEarlier.
  ///
  /// In sv, this message translates to:
  /// **'Sparad tidigare'**
  String get menuSavedEarlier;

  /// No description provided for @menuSaveTitle.
  ///
  /// In sv, this message translates to:
  /// **'Spara meny'**
  String get menuSaveTitle;

  /// No description provided for @menuShareWithFriendsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Dela denna meny med valda vänner'**
  String get menuShareWithFriendsDescription;

  /// No description provided for @menuToSave.
  ///
  /// In sv, this message translates to:
  /// **'Meny att spara'**
  String get menuToSave;

  /// No description provided for @menuUnnamed.
  ///
  /// In sv, this message translates to:
  /// **'Namnlös meny'**
  String get menuUnnamed;

  /// No description provided for @privacyCouldNotLoad.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda integritetspolicyn. Försök igen senare.'**
  String get privacyCouldNotLoad;

  /// No description provided for @privacyTitle.
  ///
  /// In sv, this message translates to:
  /// **'Integritetspolicy'**
  String get privacyTitle;

  /// No description provided for @recipeAddTags.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till taggar'**
  String get recipeAddTags;

  /// No description provided for @recipeChangesSaved.
  ///
  /// In sv, this message translates to:
  /// **'Ändringar sparade!'**
  String get recipeChangesSaved;

  /// No description provided for @recipeContinueEditing.
  ///
  /// In sv, this message translates to:
  /// **'Fortsätt redigera'**
  String get recipeContinueEditing;

  /// No description provided for @recipeCopySaved.
  ///
  /// In sv, this message translates to:
  /// **'Din kopia av receptet sparades!'**
  String get recipeCopySaved;

  /// No description provided for @recipeCouldNotSaveChanges.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara ändringar'**
  String get recipeCouldNotSaveChanges;

  /// No description provided for @recipeCouldNotSaveCopy.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara din kopia'**
  String get recipeCouldNotSaveCopy;

  /// No description provided for @recipeFromArchive.
  ///
  /// In sv, this message translates to:
  /// **'Från arkiv'**
  String get recipeFromArchive;

  /// No description provided for @recipeFromImage.
  ///
  /// In sv, this message translates to:
  /// **'Från bild'**
  String get recipeFromImage;

  /// No description provided for @recipeImportedFromShare.
  ///
  /// In sv, this message translates to:
  /// **'Importerat från delning'**
  String get recipeImportedFromShare;

  /// No description provided for @recipeImportLink.
  ///
  /// In sv, this message translates to:
  /// **'Importera länk'**
  String get recipeImportLink;

  /// No description provided for @recipeIngredient.
  ///
  /// In sv, this message translates to:
  /// **'Ingrediens'**
  String get recipeIngredient;

  /// No description provided for @recipeInstruction.
  ///
  /// In sv, this message translates to:
  /// **'Instruktion'**
  String get recipeInstruction;

  /// No description provided for @recipeLeaveWithoutSaving.
  ///
  /// In sv, this message translates to:
  /// **'Lämna utan att spara'**
  String get recipeLeaveWithoutSaving;

  /// No description provided for @recipeManageAllTags.
  ///
  /// In sv, this message translates to:
  /// **'Hantera alla taggar'**
  String get recipeManageAllTags;

  /// No description provided for @recipeRating.
  ///
  /// In sv, this message translates to:
  /// **'Betyg (0–5)'**
  String get recipeRating;

  /// No description provided for @recipeSourceUrl.
  ///
  /// In sv, this message translates to:
  /// **'Källa (URL)'**
  String get recipeSourceUrl;

  /// No description provided for @recipeSourceUrlHelper.
  ///
  /// In sv, this message translates to:
  /// **'Länk till originalreceptet'**
  String get recipeSourceUrlHelper;

  /// No description provided for @recipeSourceUrlHint.
  ///
  /// In sv, this message translates to:
  /// **'Valfritt: länk till originalreceptet'**
  String get recipeSourceUrlHint;

  /// No description provided for @recipeTagsUpdated.
  ///
  /// In sv, this message translates to:
  /// **'Taggar uppdaterade'**
  String get recipeTagsUpdated;

  /// No description provided for @recipeTimeMinutes.
  ///
  /// In sv, this message translates to:
  /// **'Tid (min)'**
  String get recipeTimeMinutes;

  /// No description provided for @recipeUnsavedChangesTitle.
  ///
  /// In sv, this message translates to:
  /// **'Osparade ändringar'**
  String get recipeUnsavedChangesTitle;

  /// No description provided for @recipeWriteManually.
  ///
  /// In sv, this message translates to:
  /// **'Skriv manuellt'**
  String get recipeWriteManually;

  /// No description provided for @searchRecipesHint.
  ///
  /// In sv, this message translates to:
  /// **'sök bland recepten...'**
  String get searchRecipesHint;

  /// No description provided for @shoppingAddItems.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till'**
  String get shoppingAddItems;

  /// No description provided for @shoppingAddItemsFromMenu.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till {count} artiklar från menyn i \"{listName}\"'**
  String shoppingAddItemsFromMenu(int count, String listName);

  /// No description provided for @shoppingCreateFirstListDescription.
  ///
  /// In sv, this message translates to:
  /// **'Skapa din första inköpslista för att komma igång'**
  String get shoppingCreateFirstListDescription;

  /// No description provided for @shoppingItemsAdded.
  ///
  /// In sv, this message translates to:
  /// **'{count} artiklar tillagda i \"{listName}\"'**
  String shoppingItemsAdded(int count, String listName);

  /// No description provided for @shoppingItemsAddFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lägga till artiklar: {error}'**
  String shoppingItemsAddFailed(String error);

  /// No description provided for @shoppingListCreateFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa lista: {error}'**
  String shoppingListCreateFailed(String error);

  /// No description provided for @socialTotalMembers.
  ///
  /// In sv, this message translates to:
  /// **'Totalt medlemmar'**
  String get socialTotalMembers;

  /// No description provided for @userNoUsers.
  ///
  /// In sv, this message translates to:
  /// **'Inga användare'**
  String get userNoUsers;

  /// No description provided for @userNoUsersToShow.
  ///
  /// In sv, this message translates to:
  /// **'Inga användare att visa'**
  String get userNoUsersToShow;

  /// No description provided for @chatAttachments.
  ///
  /// In sv, this message translates to:
  /// **'Bilagor'**
  String get chatAttachments;

  /// No description provided for @chatAttachmentTypes.
  ///
  /// In sv, this message translates to:
  /// **'Bilagor: Recept, Meny, Handlingslista, Foto'**
  String get chatAttachmentTypes;

  /// No description provided for @chatCouldNotSendMessage.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skicka meddelandet. Försök igen.'**
  String get chatCouldNotSendMessage;

  /// No description provided for @chatLoadingMessages.
  ///
  /// In sv, this message translates to:
  /// **'Laddar meddelanden...'**
  String get chatLoadingMessages;

  /// No description provided for @chatNoMessages.
  ///
  /// In sv, this message translates to:
  /// **'Inga meddelanden än'**
  String get chatNoMessages;

  /// No description provided for @chatSend.
  ///
  /// In sv, this message translates to:
  /// **'Skicka'**
  String get chatSend;

  /// No description provided for @chatSendImage.
  ///
  /// In sv, this message translates to:
  /// **'Skicka bild'**
  String get chatSendImage;

  /// No description provided for @chatSendToStartConversation.
  ///
  /// In sv, this message translates to:
  /// **'Skicka ett meddelande för att starta konversationen'**
  String get chatSendToStartConversation;

  /// No description provided for @chatWriteMessage.
  ///
  /// In sv, this message translates to:
  /// **'Skriv ett meddelande...'**
  String get chatWriteMessage;

  /// No description provided for @commonOr.
  ///
  /// In sv, this message translates to:
  /// **'eller'**
  String get commonOr;

  /// No description provided for @errorCouldNotLoadPage.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda sidan'**
  String get errorCouldNotLoadPage;

  /// No description provided for @errorLoadingRetryOrGoBack.
  ///
  /// In sv, this message translates to:
  /// **'Ett fel uppstod vid laddning. Försök igen eller gå tillbaka.'**
  String get errorLoadingRetryOrGoBack;

  /// No description provided for @errorSavingWithDetails.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara: {error}'**
  String errorSavingWithDetails(String error);

  /// No description provided for @errorTitle.
  ///
  /// In sv, this message translates to:
  /// **'Fel'**
  String get errorTitle;

  /// No description provided for @errorOccurredWithDetails.
  ///
  /// In sv, this message translates to:
  /// **'Ett fel uppstod: {error}'**
  String errorOccurredWithDetails(String error);

  /// No description provided for @filterAllergenFree.
  ///
  /// In sv, this message translates to:
  /// **'Allergenfri'**
  String get filterAllergenFree;

  /// No description provided for @filterClearAll.
  ///
  /// In sv, this message translates to:
  /// **'Rensa alla filter'**
  String get filterClearAll;

  /// No description provided for @filterCookingTime.
  ///
  /// In sv, this message translates to:
  /// **'Tillagningstid'**
  String get filterCookingTime;

  /// No description provided for @filterCreatePersonalTags.
  ///
  /// In sv, this message translates to:
  /// **'Skapa personliga taggar'**
  String get filterCreatePersonalTags;

  /// No description provided for @filterDietary.
  ///
  /// In sv, this message translates to:
  /// **'Specialkost'**
  String get filterDietary;

  /// No description provided for @filterExcludeTags.
  ///
  /// In sv, this message translates to:
  /// **'Exkludera taggar'**
  String get filterExcludeTags;

  /// No description provided for @filterHide.
  ///
  /// In sv, this message translates to:
  /// **'Dölj filter'**
  String get filterHide;

  /// No description provided for @filterManageTags.
  ///
  /// In sv, this message translates to:
  /// **'Hantera taggar'**
  String get filterManageTags;

  /// No description provided for @filterMealType.
  ///
  /// In sv, this message translates to:
  /// **'Måltidstyp'**
  String get filterMealType;

  /// No description provided for @filterPersonalTags.
  ///
  /// In sv, this message translates to:
  /// **'Personliga taggar'**
  String get filterPersonalTags;

  /// No description provided for @filterRating.
  ///
  /// In sv, this message translates to:
  /// **'Betyg'**
  String get filterRating;

  /// No description provided for @filterShow.
  ///
  /// In sv, this message translates to:
  /// **'Visa filter'**
  String get filterShow;

  /// No description provided for @importAnalyzingContent.
  ///
  /// In sv, this message translates to:
  /// **'Analyserar innehåll...'**
  String get importAnalyzingContent;

  /// No description provided for @importChooseFromGallery.
  ///
  /// In sv, this message translates to:
  /// **'Välj från galleri'**
  String get importChooseFromGallery;

  /// No description provided for @importChooseFromGallerySubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Välj en befintlig bild från telefonen'**
  String get importChooseFromGallerySubtitle;

  /// No description provided for @importChooseImage.
  ///
  /// In sv, this message translates to:
  /// **'Välj bild'**
  String get importChooseImage;

  /// No description provided for @importChooseImageSource.
  ///
  /// In sv, this message translates to:
  /// **'Välj bildkälla'**
  String get importChooseImageSource;

  /// No description provided for @importChooseNewImage.
  ///
  /// In sv, this message translates to:
  /// **'Välj ny bild'**
  String get importChooseNewImage;

  /// No description provided for @importConfidenceTooltip.
  ///
  /// In sv, this message translates to:
  /// **'{label}: {percentage}% säkerhet'**
  String importConfidenceTooltip(String label, int percentage);

  /// No description provided for @importContinueWithImport.
  ///
  /// In sv, this message translates to:
  /// **'Fortsätt med import'**
  String get importContinueWithImport;

  /// No description provided for @importContinueWithoutOcr.
  ///
  /// In sv, this message translates to:
  /// **'Fortsätt utan OCR'**
  String get importContinueWithoutOcr;

  /// No description provided for @importCopyManually.
  ///
  /// In sv, this message translates to:
  /// **'Kopiera manuellt'**
  String get importCopyManually;

  /// No description provided for @importCouldNotExtractText.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte extrahera text'**
  String get importCouldNotExtractText;

  /// No description provided for @importExtraction.
  ///
  /// In sv, this message translates to:
  /// **'Extraktion'**
  String get importExtraction;

  /// No description provided for @importFetchAutomatically.
  ///
  /// In sv, this message translates to:
  /// **'Hämta recept automatiskt'**
  String get importFetchAutomatically;

  /// No description provided for @importFetchFromWebsite.
  ///
  /// In sv, this message translates to:
  /// **'Hämta recept från webbsida'**
  String get importFetchFromWebsite;

  /// No description provided for @importFetchingFromPlatform.
  ///
  /// In sv, this message translates to:
  /// **'Hämtar recept från {platform}...'**
  String importFetchingFromPlatform(String platform);

  /// No description provided for @importFromPhoto.
  ///
  /// In sv, this message translates to:
  /// **'Importera från foto'**
  String get importFromPhoto;

  /// No description provided for @importGoodQuality.
  ///
  /// In sv, this message translates to:
  /// **'God kvalitet'**
  String get importGoodQuality;

  /// No description provided for @importHighQuality.
  ///
  /// In sv, this message translates to:
  /// **'Hög kvalitet'**
  String get importHighQuality;

  /// No description provided for @importImageQualityLow.
  ///
  /// In sv, this message translates to:
  /// **'Bildkvaliteten är låg ({percentage}%)'**
  String importImageQualityLow(int percentage);

  /// No description provided for @importImport.
  ///
  /// In sv, this message translates to:
  /// **'Importera'**
  String get importImport;

  /// No description provided for @importImportedFrom.
  ///
  /// In sv, this message translates to:
  /// **'Importerad från {source}'**
  String importImportedFrom(String source);

  /// No description provided for @importImprovementSuggestions.
  ///
  /// In sv, this message translates to:
  /// **'Förbättringsförslag:'**
  String get importImprovementSuggestions;

  /// No description provided for @importInterpretedText.
  ///
  /// In sv, this message translates to:
  /// **'Tolkad text:'**
  String get importInterpretedText;

  /// No description provided for @importLowQuality.
  ///
  /// In sv, this message translates to:
  /// **'Låg kvalitet'**
  String get importLowQuality;

  /// No description provided for @importManualCopy.
  ///
  /// In sv, this message translates to:
  /// **'Manuell kopiering'**
  String get importManualCopy;

  /// No description provided for @importManualCopyInstructions.
  ///
  /// In sv, this message translates to:
  /// **'1. Gå tillbaka till {platform}\n2. Kopiera recepttexten från inlägget\n3. Kom tillbaka hit och välj \"Klistra in text\"'**
  String importManualCopyInstructions(String platform);

  /// No description provided for @importManually.
  ///
  /// In sv, this message translates to:
  /// **'Importera manuellt'**
  String get importManually;

  /// No description provided for @importNoImageSelected.
  ///
  /// In sv, this message translates to:
  /// **'Ingen bild vald'**
  String get importNoImageSelected;

  /// No description provided for @importNoRecipeInfoFound.
  ///
  /// In sv, this message translates to:
  /// **'Ingen receptinformation hittades i texten.'**
  String get importNoRecipeInfoFound;

  /// No description provided for @importOcrMayFail.
  ///
  /// In sv, this message translates to:
  /// **'OCR kan misslyckas eller ge dåliga resultat.'**
  String get importOcrMayFail;

  /// No description provided for @importOtherApp.
  ///
  /// In sv, this message translates to:
  /// **'annan app'**
  String get importOtherApp;

  /// No description provided for @importPasteFromClipboard.
  ///
  /// In sv, this message translates to:
  /// **'Klistra in från urklipp'**
  String get importPasteFromClipboard;

  /// No description provided for @importPasteLinkOrText.
  ///
  /// In sv, this message translates to:
  /// **'Klistra in länk eller text här...'**
  String get importPasteLinkOrText;

  /// No description provided for @importPasteText.
  ///
  /// In sv, this message translates to:
  /// **'Klistra in text'**
  String get importPasteText;

  /// No description provided for @importPhotoDescription.
  ///
  /// In sv, this message translates to:
  /// **'Ta bild av ett recept eller välj från galleriet för att importera text automatiskt'**
  String get importPhotoDescription;

  /// No description provided for @importPhotoImport.
  ///
  /// In sv, this message translates to:
  /// **'Fotoimport'**
  String get importPhotoImport;

  /// No description provided for @importProceedToEdit.
  ///
  /// In sv, this message translates to:
  /// **'Gå vidare till redigera'**
  String get importProceedToEdit;

  /// No description provided for @importProcessingImage.
  ///
  /// In sv, this message translates to:
  /// **'Bearbetar bild...'**
  String get importProcessingImage;

  /// No description provided for @importRecipeLinkDetected.
  ///
  /// In sv, this message translates to:
  /// **'Receptlänk detekterad'**
  String get importRecipeLinkDetected;

  /// No description provided for @importRecipeTextCanImport.
  ///
  /// In sv, this message translates to:
  /// **'Recepttext detekterad! Vi kan importera detta.'**
  String get importRecipeTextCanImport;

  /// No description provided for @importRecipeTextDetected.
  ///
  /// In sv, this message translates to:
  /// **'Recepttext detekterad!'**
  String get importRecipeTextDetected;

  /// No description provided for @importRecipeTitle.
  ///
  /// In sv, this message translates to:
  /// **'Importera recept'**
  String get importRecipeTitle;

  /// No description provided for @importRemoveImage.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort bild'**
  String get importRemoveImage;

  /// No description provided for @importSharedText.
  ///
  /// In sv, this message translates to:
  /// **'delad text'**
  String get importSharedText;

  /// No description provided for @importTakePhoto.
  ///
  /// In sv, this message translates to:
  /// **'Ta ett foto'**
  String get importTakePhoto;

  /// No description provided for @importTakePhotoSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Använd kameran för att fota receptet'**
  String get importTakePhotoSubtitle;

  /// No description provided for @importTapButtonToSelect.
  ///
  /// In sv, this message translates to:
  /// **'Tryck på knappen ovan för att välja'**
  String get importTapButtonToSelect;

  /// No description provided for @importTextContent.
  ///
  /// In sv, this message translates to:
  /// **'Textinnehåll'**
  String get importTextContent;

  /// No description provided for @importTryAnyway.
  ///
  /// In sv, this message translates to:
  /// **'Försök ändå'**
  String get importTryAnyway;

  /// No description provided for @importUnknownSource.
  ///
  /// In sv, this message translates to:
  /// **'Okänd källa'**
  String get importUnknownSource;

  /// No description provided for @importUrlFromPlatform.
  ///
  /// In sv, this message translates to:
  /// **'URL från {platform}'**
  String importUrlFromPlatform(String platform);

  /// No description provided for @importVideoNoText.
  ///
  /// In sv, this message translates to:
  /// **'Videon saknar text'**
  String get importVideoNoText;

  /// No description provided for @importVideoNoTextDescription.
  ///
  /// In sv, this message translates to:
  /// **'Den här videon har inga undertexter som vi kan läsa.\n\nDu kan ta en skärmbild av receptet i videon och importera den istället.'**
  String get importVideoNoTextDescription;

  /// No description provided for @importWebRecipeLinkDetected.
  ///
  /// In sv, this message translates to:
  /// **'Receptlänk från webbsida detekterad!'**
  String get importWebRecipeLinkDetected;

  /// No description provided for @importWebsite.
  ///
  /// In sv, this message translates to:
  /// **'Webbsida'**
  String get importWebsite;

  /// No description provided for @groupAddMembers.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till medlemmar'**
  String get groupAddMembers;

  /// No description provided for @groupAllFriendsAlreadyMembers.
  ///
  /// In sv, this message translates to:
  /// **'Alla dina vänner är redan medlemmar i denna grupp, eller så har du redan skickat inbjudningar till dem.'**
  String get groupAllFriendsAlreadyMembers;

  /// No description provided for @groupCouldNotLoadMembers.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda gruppmedlemmar'**
  String get groupCouldNotLoadMembers;

  /// No description provided for @groupCouldNotTransferOwnership.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte överföra ägande. Försök igen.'**
  String get groupCouldNotTransferOwnership;

  /// No description provided for @groupDeleted.
  ///
  /// In sv, this message translates to:
  /// **'Gruppen \"{name}\" har tagits bort'**
  String groupDeleted(String name);

  /// No description provided for @groupInvitationSent.
  ///
  /// In sv, this message translates to:
  /// **'Skickad'**
  String get groupInvitationSent;

  /// No description provided for @groupInvitationsSent.
  ///
  /// In sv, this message translates to:
  /// **'{count} inbjudningar skickade'**
  String groupInvitationsSent(int count);

  /// No description provided for @groupInvitationsSentSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Inbjudningar har skickats!'**
  String get groupInvitationsSentSuccess;

  /// No description provided for @groupLoadingInfo.
  ///
  /// In sv, this message translates to:
  /// **'Laddar gruppinformation...'**
  String get groupLoadingInfo;

  /// No description provided for @groupNoFriendsAvailable.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner tillgängliga'**
  String get groupNoFriendsAvailable;

  /// No description provided for @groupNoMembersToShare.
  ///
  /// In sv, this message translates to:
  /// **'Gruppen har inga medlemmar att dela med'**
  String get groupNoMembersToShare;

  /// No description provided for @groupNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Grupp hittades inte'**
  String get groupNotFound;

  /// No description provided for @groupNotFoundDescription.
  ///
  /// In sv, this message translates to:
  /// **'Den här gruppen kanske har tagits bort eller så saknar du behörighet.'**
  String get groupNotFoundDescription;

  /// No description provided for @groupOwnershipTransferredAndLeft.
  ///
  /// In sv, this message translates to:
  /// **'Ägande överfört och du har lämnat gruppen'**
  String get groupOwnershipTransferredAndLeft;

  /// No description provided for @groupSelectedOfTotal.
  ///
  /// In sv, this message translates to:
  /// **'{selected} av {total} vald(a)'**
  String groupSelectedOfTotal(int selected, int total);

  /// No description provided for @groupSendInvitations.
  ///
  /// In sv, this message translates to:
  /// **'Skicka {count} inbjudningar'**
  String groupSendInvitations(int count);

  /// No description provided for @groupSharedFromGroup.
  ///
  /// In sv, this message translates to:
  /// **'Delad från gruppen {name}'**
  String groupSharedFromGroup(String name);

  /// No description provided for @groupUpdated.
  ///
  /// In sv, this message translates to:
  /// **'Gruppen uppdaterades!'**
  String get groupUpdated;

  /// No description provided for @groupYouLeftGroup.
  ///
  /// In sv, this message translates to:
  /// **'Du har lämnat gruppen'**
  String get groupYouLeftGroup;

  /// No description provided for @loadingGeneric.
  ///
  /// In sv, this message translates to:
  /// **'Laddar...'**
  String get loadingGeneric;

  /// No description provided for @loadingRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Laddar recept...'**
  String get loadingRecipes;

  /// No description provided for @menuCategoryCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} kategorier'**
  String menuCategoryCount(int count);

  /// No description provided for @menuConnectingCollaborative.
  ///
  /// In sv, this message translates to:
  /// **'Ansluter till \"{title}\" för samarbetsredigering...'**
  String menuConnectingCollaborative(String title);

  /// No description provided for @menuCouldNotHide.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dölja meny'**
  String get menuCouldNotHide;

  /// No description provided for @menuHiddenFromList.
  ///
  /// In sv, this message translates to:
  /// **'\"{title}\" dold från din lista'**
  String menuHiddenFromList(String title);

  /// No description provided for @menuHideConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du dölja \"{title}\" från din lista?\n\nDu kan fortfarande komma åt menyn genom att be {sharedBy} att dela den igen.'**
  String menuHideConfirm(String title, String sharedBy);

  /// No description provided for @menuHideMenu.
  ///
  /// In sv, this message translates to:
  /// **'Dölj meny'**
  String get menuHideMenu;

  /// No description provided for @menuImportAll.
  ///
  /// In sv, this message translates to:
  /// **'Importera hela menyn'**
  String get menuImportAll;

  /// No description provided for @menuImportDescription.
  ///
  /// In sv, this message translates to:
  /// **'När du importerar menyn läggs alla {count} recept till i din samling.'**
  String menuImportDescription(int count);

  /// No description provided for @menuImported.
  ///
  /// In sv, this message translates to:
  /// **'Meny importerad'**
  String get menuImported;

  /// No description provided for @menuImportedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Meny \"{title}\" importerad!'**
  String menuImportedSuccess(String title);

  /// No description provided for @menuImportFailed.
  ///
  /// In sv, this message translates to:
  /// **'Import misslyckades'**
  String get menuImportFailed;

  /// No description provided for @menuNoRecipesInMenu.
  ///
  /// In sv, this message translates to:
  /// **'Inga recept i menyn'**
  String get menuNoRecipesInMenu;

  /// No description provided for @menuSharedMenu.
  ///
  /// In sv, this message translates to:
  /// **'DELAD MENY'**
  String get menuSharedMenu;

  /// No description provided for @menuShareMenu.
  ///
  /// In sv, this message translates to:
  /// **'Dela meny'**
  String get menuShareMenu;

  /// No description provided for @menuSharingComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Delning av \"{title}\" kommer snart!'**
  String menuSharingComingSoon(String title);

  /// No description provided for @menuSavedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Menyn \"{name}\" sparades!'**
  String menuSavedSuccess(String name);

  /// No description provided for @menuSaveFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara menyn'**
  String get menuSaveFailed;

  /// No description provided for @navigationGoHome.
  ///
  /// In sv, this message translates to:
  /// **'Till start'**
  String get navigationGoHome;

  /// No description provided for @navigationSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Din digitala kokbok'**
  String get navigationSubtitle;

  /// No description provided for @permissionCopy.
  ///
  /// In sv, this message translates to:
  /// **'Kopia'**
  String get permissionCopy;

  /// No description provided for @permissionCreatingCopy.
  ///
  /// In sv, this message translates to:
  /// **'Skapar kopia...'**
  String get permissionCreatingCopy;

  /// No description provided for @permissionNoAccess.
  ///
  /// In sv, this message translates to:
  /// **'Ingen åtkomst'**
  String get permissionNoAccess;

  /// No description provided for @permissionSaveAsNew.
  ///
  /// In sv, this message translates to:
  /// **'Spara som ny'**
  String get permissionSaveAsNew;

  /// No description provided for @permissionSaveChanges.
  ///
  /// In sv, this message translates to:
  /// **'Spara ändringar'**
  String get permissionSaveChanges;

  /// No description provided for @permissionSaveMyCopy.
  ///
  /// In sv, this message translates to:
  /// **'Spara min kopia'**
  String get permissionSaveMyCopy;

  /// No description provided for @permissionSaving.
  ///
  /// In sv, this message translates to:
  /// **'Sparar...'**
  String get permissionSaving;

  /// No description provided for @privacyContactUs.
  ///
  /// In sv, this message translates to:
  /// **'Kontakta oss'**
  String get privacyContactUs;

  /// No description provided for @privacyCouldNotOpenEmail.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte öppna e-postklienten'**
  String get privacyCouldNotOpenEmail;

  /// No description provided for @privacyGdprCompliant.
  ///
  /// In sv, this message translates to:
  /// **'Denna integritetspolicy uppfyller kraven i GDPR'**
  String get privacyGdprCompliant;

  /// No description provided for @privacyLoading.
  ///
  /// In sv, this message translates to:
  /// **'Laddar integritetspolicy...'**
  String get privacyLoading;

  /// No description provided for @privacyNotAvailable.
  ///
  /// In sv, this message translates to:
  /// **'Integritetspolicyn är inte tillgänglig'**
  String get privacyNotAvailable;

  /// No description provided for @privacyQuestionsTitle.
  ///
  /// In sv, this message translates to:
  /// **'Frågor om integritet?'**
  String get privacyQuestionsTitle;

  /// No description provided for @privacyReload.
  ///
  /// In sv, this message translates to:
  /// **'Ladda om'**
  String get privacyReload;

  /// No description provided for @profileAddAvatar.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till avatar'**
  String get profileAddAvatar;

  /// No description provided for @profileAvatarRemoved.
  ///
  /// In sv, this message translates to:
  /// **'Avatar borttagen'**
  String get profileAvatarRemoved;

  /// No description provided for @profileAvatarUploaded.
  ///
  /// In sv, this message translates to:
  /// **'Avatar uppladdad!'**
  String get profileAvatarUploaded;

  /// No description provided for @profileChangeAvatar.
  ///
  /// In sv, this message translates to:
  /// **'Ändra avatar'**
  String get profileChangeAvatar;

  /// No description provided for @profileCouldNotSave.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara profil'**
  String get profileCouldNotSave;

  /// No description provided for @profileCouldNotUploadAvatar.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda upp avatar'**
  String get profileCouldNotUploadAvatar;

  /// No description provided for @profileDisplayName.
  ///
  /// In sv, this message translates to:
  /// **'Visningsnamn'**
  String get profileDisplayName;

  /// No description provided for @profileDisplayNameHint.
  ///
  /// In sv, this message translates to:
  /// **'Ditt namn som andra ser'**
  String get profileDisplayNameHint;

  /// No description provided for @profileFormReset.
  ///
  /// In sv, this message translates to:
  /// **'Formulär återställt'**
  String get profileFormReset;

  /// No description provided for @profileLanguage.
  ///
  /// In sv, this message translates to:
  /// **'Språk'**
  String get profileLanguage;

  /// No description provided for @profileLanguageChangedTo.
  ///
  /// In sv, this message translates to:
  /// **'Språk ändrat till {language}'**
  String profileLanguageChangedTo(String language);

  /// No description provided for @profileLoading.
  ///
  /// In sv, this message translates to:
  /// **'Laddar profil...'**
  String get profileLoading;

  /// No description provided for @profileNewUser.
  ///
  /// In sv, this message translates to:
  /// **'Ny användare'**
  String get profileNewUser;

  /// No description provided for @profilePrivacySettings.
  ///
  /// In sv, this message translates to:
  /// **'Integritetsinställningar'**
  String get profilePrivacySettings;

  /// No description provided for @profileResetChanges.
  ///
  /// In sv, this message translates to:
  /// **'Återställ ändringar'**
  String get profileResetChanges;

  /// No description provided for @profileSaved.
  ///
  /// In sv, this message translates to:
  /// **'Profil sparad!'**
  String get profileSaved;

  /// No description provided for @profileSaveProfile.
  ///
  /// In sv, this message translates to:
  /// **'Spara profil'**
  String get profileSaveProfile;

  /// No description provided for @profileSearchableByEmail.
  ///
  /// In sv, this message translates to:
  /// **'Sökbar via e-post'**
  String get profileSearchableByEmail;

  /// No description provided for @profileSearchableByEmailDescription.
  ///
  /// In sv, this message translates to:
  /// **'Andra kan hitta dig genom din e-postadress'**
  String get profileSearchableByEmailDescription;

  /// No description provided for @profileTheme.
  ///
  /// In sv, this message translates to:
  /// **'Tema'**
  String get profileTheme;

  /// No description provided for @profileThemeChangedTo.
  ///
  /// In sv, this message translates to:
  /// **'Tema ändrat till {theme}'**
  String profileThemeChangedTo(String theme);

  /// No description provided for @profileThemeDark.
  ///
  /// In sv, this message translates to:
  /// **'Mörkt läge'**
  String get profileThemeDark;

  /// No description provided for @profileThemeLight.
  ///
  /// In sv, this message translates to:
  /// **'Ljust läge'**
  String get profileThemeLight;

  /// No description provided for @profileThemeSystem.
  ///
  /// In sv, this message translates to:
  /// **'Systemets inställning'**
  String get profileThemeSystem;

  /// No description provided for @profileUnsavedChanges.
  ///
  /// In sv, this message translates to:
  /// **'Osparade ändringar'**
  String get profileUnsavedChanges;

  /// No description provided for @profileUnsavedChangesMessage.
  ///
  /// In sv, this message translates to:
  /// **'Du har osparade ändringar. Vill du spara innan du lämnar?'**
  String get profileUnsavedChangesMessage;

  /// No description provided for @profileUploadingAvatar.
  ///
  /// In sv, this message translates to:
  /// **'Laddar upp avatar...'**
  String get profileUploadingAvatar;

  /// No description provided for @profileVisibleInSearch.
  ///
  /// In sv, this message translates to:
  /// **'Synlig i sökningar'**
  String get profileVisibleInSearch;

  /// No description provided for @profileVisibleInSearchDescription.
  ///
  /// In sv, this message translates to:
  /// **'Andra användare kan hitta dig när de söker'**
  String get profileVisibleInSearchDescription;

  /// No description provided for @profileYouHaveUnsavedChanges.
  ///
  /// In sv, this message translates to:
  /// **'Du har osparade ändringar'**
  String get profileYouHaveUnsavedChanges;

  /// No description provided for @recipeCouldNotSave.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara recept'**
  String get recipeCouldNotSave;

  /// No description provided for @recipeCouldNotDelete.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort recept'**
  String get recipeCouldNotDelete;

  /// No description provided for @recipeCouldNotMarkAsCooked.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte markera som lagat'**
  String get recipeCouldNotMarkAsCooked;

  /// No description provided for @recipeCouldNotOpenEditor.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte öppna redigeringsvy'**
  String get recipeCouldNotOpenEditor;

  /// No description provided for @recipeCouldNotShare.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dela recept'**
  String get recipeCouldNotShare;

  /// No description provided for @recipeDeleted.
  ///
  /// In sv, this message translates to:
  /// **'Recept borttaget'**
  String get recipeDeleted;

  /// No description provided for @recipeMarkedAsCooked.
  ///
  /// In sv, this message translates to:
  /// **'Recept markerat som lagat idag!'**
  String get recipeMarkedAsCooked;

  /// No description provided for @recipeShared.
  ///
  /// In sv, this message translates to:
  /// **'Recept delat'**
  String get recipeShared;

  /// No description provided for @recipeImportedFrom.
  ///
  /// In sv, this message translates to:
  /// **'Importerat från: {sourceUrl}'**
  String recipeImportedFrom(String sourceUrl);

  /// No description provided for @recipeSaved.
  ///
  /// In sv, this message translates to:
  /// **'Recept sparat!'**
  String get recipeSaved;

  /// No description provided for @recipeSavedTaggingFailed.
  ///
  /// In sv, this message translates to:
  /// **'Recept sparat, men taggning misslyckades. Allergeninformation kan vara ofullständig.'**
  String get recipeSavedTaggingFailed;

  /// No description provided for @recipeSavedWithTags.
  ///
  /// In sv, this message translates to:
  /// **'Recept sparat! {tagCount} taggar ({coverage}%)'**
  String recipeSavedWithTags(int tagCount, int coverage);

  /// No description provided for @recipeSaveStartedDuringDialog.
  ///
  /// In sv, this message translates to:
  /// **'En sparning påbörjades under valet. Vänta medan receptet sparas...'**
  String get recipeSaveStartedDuringDialog;

  /// No description provided for @recipeWaitWhileSaving.
  ///
  /// In sv, this message translates to:
  /// **'Vänta medan receptet sparas...'**
  String get recipeWaitWhileSaving;

  /// No description provided for @recipeWriteNew.
  ///
  /// In sv, this message translates to:
  /// **'Skriv nytt recept'**
  String get recipeWriteNew;

  /// No description provided for @recipeAddItem.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till {label}'**
  String recipeAddItem(String label);

  /// No description provided for @recipeSave.
  ///
  /// In sv, this message translates to:
  /// **'Spara recept'**
  String get recipeSave;

  /// No description provided for @recipeSaving.
  ///
  /// In sv, this message translates to:
  /// **'Sparar recept...'**
  String get recipeSaving;

  /// No description provided for @recipeTag.
  ///
  /// In sv, this message translates to:
  /// **'Tagg'**
  String get recipeTag;

  /// No description provided for @searchFiltersActive.
  ///
  /// In sv, this message translates to:
  /// **'{count} filter aktiva'**
  String searchFiltersActive(int count);

  /// No description provided for @searchQuery.
  ///
  /// In sv, this message translates to:
  /// **'Sökning'**
  String get searchQuery;

  /// No description provided for @searchResults.
  ///
  /// In sv, this message translates to:
  /// **'{count} resultat'**
  String searchResults(int count);

  /// No description provided for @shareFailed.
  ///
  /// In sv, this message translates to:
  /// **'Delning misslyckades: {error}'**
  String shareFailed(String error);

  /// No description provided for @socialCategories.
  ///
  /// In sv, this message translates to:
  /// **'Kategorier'**
  String get socialCategories;

  /// No description provided for @socialCategoryStatistics.
  ///
  /// In sv, this message translates to:
  /// **'Kategoristatistik'**
  String get socialCategoryStatistics;

  /// No description provided for @socialCreateCategory.
  ///
  /// In sv, this message translates to:
  /// **'Skapa kategori'**
  String get socialCreateCategory;

  /// No description provided for @socialMembersCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} medlemmar'**
  String socialMembersCount(int count);

  /// No description provided for @socialNoCategories.
  ///
  /// In sv, this message translates to:
  /// **'Inga kategorier'**
  String get socialNoCategories;

  /// No description provided for @socialBeFirstToComment.
  ///
  /// In sv, this message translates to:
  /// **'Var först med att kommentera detta recept!'**
  String get socialBeFirstToComment;

  /// No description provided for @socialCommentPosted.
  ///
  /// In sv, this message translates to:
  /// **'Kommentar postad'**
  String get socialCommentPosted;

  /// No description provided for @socialComments.
  ///
  /// In sv, this message translates to:
  /// **'Kommentarer'**
  String get socialComments;

  /// No description provided for @socialCommentsCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} kommentarer'**
  String socialCommentsCount(int count);

  /// No description provided for @socialCouldNotCreateProfile.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa användarprofil'**
  String get socialCouldNotCreateProfile;

  /// No description provided for @socialCouldNotFetchUserData.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte hämta användardata'**
  String get socialCouldNotFetchUserData;

  /// No description provided for @socialCouldNotPostComment.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte posta kommentar'**
  String get socialCouldNotPostComment;

  /// No description provided for @socialCouldNotStartConversation.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte starta konversation: {error}'**
  String socialCouldNotStartConversation(String error);

  /// No description provided for @socialCouldNotUpdateLike.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera gilla-markering'**
  String get socialCouldNotUpdateLike;

  /// No description provided for @socialFriendFromList.
  ///
  /// In sv, this message translates to:
  /// **'vän från din vänlista'**
  String get socialFriendFromList;

  /// No description provided for @socialFriendRemoved.
  ///
  /// In sv, this message translates to:
  /// **'{name} borttagen från vänlista'**
  String socialFriendRemoved(String name);

  /// No description provided for @socialFriends.
  ///
  /// In sv, this message translates to:
  /// **'Vänner'**
  String get socialFriends;

  /// No description provided for @socialLoadingComments.
  ///
  /// In sv, this message translates to:
  /// **'Laddar kommentarer...'**
  String get socialLoadingComments;

  /// No description provided for @socialMustBeLoggedInToComment.
  ///
  /// In sv, this message translates to:
  /// **'Du måste vara inloggad för att kommentera'**
  String get socialMustBeLoggedInToComment;

  /// No description provided for @socialMustBeLoggedInToLike.
  ///
  /// In sv, this message translates to:
  /// **'Du måste vara inloggad för att gilla'**
  String get socialMustBeLoggedInToLike;

  /// No description provided for @socialNoCommentsYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga kommentarer än'**
  String get socialNoCommentsYet;

  /// No description provided for @socialRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Recept'**
  String get socialRecipes;

  /// No description provided for @socialSendMessage.
  ///
  /// In sv, this message translates to:
  /// **'Skicka meddelande'**
  String get socialSendMessage;

  /// No description provided for @socialShareRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Dela recept'**
  String get socialShareRecipe;

  /// No description provided for @socialStartingConversation.
  ///
  /// In sv, this message translates to:
  /// **'Startar konversation...'**
  String get socialStartingConversation;

  /// No description provided for @socialStatistics.
  ///
  /// In sv, this message translates to:
  /// **'Statistik'**
  String get socialStatistics;

  /// No description provided for @socialUserProfileCreated.
  ///
  /// In sv, this message translates to:
  /// **'Användarprofil skapad'**
  String get socialUserProfileCreated;

  /// No description provided for @shoppingAddIngredientsFrom.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till ingredienser från \"{title}\"'**
  String shoppingAddIngredientsFrom(String title);

  /// No description provided for @shoppingAddToShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till i inköpslista'**
  String get shoppingAddToShoppingList;

  /// No description provided for @shoppingCouldNotAddIngredients.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lägga till ingredienser i inköpslistan'**
  String get shoppingCouldNotAddIngredients;

  /// No description provided for @shoppingCouldNotCreateOrSelectList.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa eller välja inköpslista'**
  String get shoppingCouldNotCreateOrSelectList;

  /// No description provided for @shoppingIngredientsAddedToList.
  ///
  /// In sv, this message translates to:
  /// **'{count} ingredienser har lagts till i \"{listName}\".\n\nVill du gå till inköpslistan nu?'**
  String shoppingIngredientsAddedToList(int count, String listName);

  /// No description provided for @shoppingIngredientsFromRecipe.
  ///
  /// In sv, this message translates to:
  /// **'{count} ingredienser från \"{title}\":'**
  String shoppingIngredientsFromRecipe(int count, String title);

  /// No description provided for @shoppingNoEditPermission.
  ///
  /// In sv, this message translates to:
  /// **'Du har inte behörighet att redigera denna inköpslista'**
  String get shoppingNoEditPermission;

  /// No description provided for @shoppingNoEditPermissionShared.
  ///
  /// In sv, this message translates to:
  /// **'Du har inte behörighet att redigera denna delade inköpslista'**
  String get shoppingNoEditPermissionShared;

  /// No description provided for @shoppingNoIngredientsToAdd.
  ///
  /// In sv, this message translates to:
  /// **'Receptet har inga ingredienser att lägga till'**
  String get shoppingNoIngredientsToAdd;

  /// No description provided for @shoppingSelectList.
  ///
  /// In sv, this message translates to:
  /// **'Välj inköpslista'**
  String get shoppingSelectList;

  /// No description provided for @shoppingViewList.
  ///
  /// In sv, this message translates to:
  /// **'Visa lista'**
  String get shoppingViewList;

  /// No description provided for @shoppingYourList.
  ///
  /// In sv, this message translates to:
  /// **'din inköpslista'**
  String get shoppingYourList;

  /// No description provided for @shoppingSharedLists.
  ///
  /// In sv, this message translates to:
  /// **'Delade inköpslistor'**
  String get shoppingSharedLists;

  /// No description provided for @sharedByUser.
  ///
  /// In sv, this message translates to:
  /// **'Delat av {name}'**
  String sharedByUser(String name);

  /// No description provided for @sharedContentWillAppearHere.
  ///
  /// In sv, this message translates to:
  /// **'När vänner delar recept eller menyer med dig kommer de att visas här.'**
  String get sharedContentWillAppearHere;

  /// No description provided for @sharedHideFromList.
  ///
  /// In sv, this message translates to:
  /// **'Dölj från min lista'**
  String get sharedHideFromList;

  /// No description provided for @sharedLoadingContent.
  ///
  /// In sv, this message translates to:
  /// **'Laddar delat innehåll...'**
  String get sharedLoadingContent;

  /// No description provided for @sharedNoContentYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga delade recept än'**
  String get sharedNoContentYet;

  /// No description provided for @socialAddFriends.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vänner'**
  String get socialAddFriends;

  /// No description provided for @taggingAnalyzingIngredients.
  ///
  /// In sv, this message translates to:
  /// **'Analyserar ingredienser...'**
  String get taggingAnalyzingIngredients;

  /// No description provided for @taggingCouldNotAnalyze.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte analysera recept'**
  String get taggingCouldNotAnalyze;

  /// No description provided for @taggingCouldNotSaveTags.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara taggar'**
  String get taggingCouldNotSaveTags;

  /// No description provided for @taggingCreateTag.
  ///
  /// In sv, this message translates to:
  /// **'Skapa tagg'**
  String get taggingCreateTag;

  /// No description provided for @taggingCreateTagsToOrganize.
  ///
  /// In sv, this message translates to:
  /// **'Skapa taggar för att organisera dina recept'**
  String get taggingCreateTagsToOrganize;

  /// No description provided for @taggingError.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid taggning: {error}'**
  String taggingError(String error);

  /// No description provided for @taggingManageTags.
  ///
  /// In sv, this message translates to:
  /// **'Hantera taggar'**
  String get taggingManageTags;

  /// No description provided for @taggingNoPersonalTags.
  ///
  /// In sv, this message translates to:
  /// **'Inga personliga taggar'**
  String get taggingNoPersonalTags;

  /// No description provided for @taggingPersonalTags.
  ///
  /// In sv, this message translates to:
  /// **'Personliga taggar'**
  String get taggingPersonalTags;

  /// No description provided for @taggingPersonalTagsRemoved.
  ///
  /// In sv, this message translates to:
  /// **'Personliga taggar borttagna'**
  String get taggingPersonalTagsRemoved;

  /// No description provided for @taggingPersonalTagsSaved.
  ///
  /// In sv, this message translates to:
  /// **'{count} personliga taggar sparade'**
  String taggingPersonalTagsSaved(int count);

  /// No description provided for @taggingTagsGenerated.
  ///
  /// In sv, this message translates to:
  /// **'{count} taggar genererade ({coverage}% täckning)'**
  String taggingTagsGenerated(int count, int coverage);

  /// No description provided for @taggingTagsSelected.
  ///
  /// In sv, this message translates to:
  /// **'{count} taggar valda'**
  String taggingTagsSelected(int count);

  /// No description provided for @taggingUpdateTagsMessage.
  ///
  /// In sv, this message translates to:
  /// **'Analyserar ingredienser och uppdaterar allergen- och kosttaggar för \"{title}\".'**
  String taggingUpdateTagsMessage(String title);

  /// No description provided for @taggingUpdateTagsTitle.
  ///
  /// In sv, this message translates to:
  /// **'Uppdatera taggar?'**
  String get taggingUpdateTagsTitle;

  /// No description provided for @sortMealType.
  ///
  /// In sv, this message translates to:
  /// **'Måltidstyp'**
  String get sortMealType;

  /// No description provided for @sortRating.
  ///
  /// In sv, this message translates to:
  /// **'Betyg'**
  String get sortRating;

  /// No description provided for @sortTime.
  ///
  /// In sv, this message translates to:
  /// **'Tid'**
  String get sortTime;

  /// No description provided for @sortTitle.
  ///
  /// In sv, this message translates to:
  /// **'Titel'**
  String get sortTitle;

  /// No description provided for @stateAddRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till recept'**
  String get stateAddRecipes;

  /// No description provided for @stateCreateWeeklyMenu.
  ///
  /// In sv, this message translates to:
  /// **'Skapa veckomeny'**
  String get stateCreateWeeklyMenu;

  /// No description provided for @stateGenerateMenu.
  ///
  /// In sv, this message translates to:
  /// **'Generera meny'**
  String get stateGenerateMenu;

  /// No description provided for @commonStart.
  ///
  /// In sv, this message translates to:
  /// **'Starta'**
  String get commonStart;

  /// No description provided for @discoveryAllRecommendationsComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Visa alla rekommendationer kommer snart!'**
  String get discoveryAllRecommendationsComingSoon;

  /// No description provided for @discoveryBuildingRecommendations.
  ///
  /// In sv, this message translates to:
  /// **'Bygger rekommendationer'**
  String get discoveryBuildingRecommendations;

  /// No description provided for @discoveryCouldNotHideRecommendation.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dölja rekommendation just nu.'**
  String get discoveryCouldNotHideRecommendation;

  /// No description provided for @discoveryCouldNotRestoreRecommendation.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte återställa rekommendation.'**
  String get discoveryCouldNotRestoreRecommendation;

  /// No description provided for @discoveryCouldNotSendFeedback.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skicka feedback just nu.'**
  String get discoveryCouldNotSendFeedback;

  /// No description provided for @discoveryFeedbackThanksImproving.
  ///
  /// In sv, this message translates to:
  /// **'Tack för din feedback! Vi förbättrar rekommendationerna.'**
  String get discoveryFeedbackThanksImproving;

  /// No description provided for @discoveryFriendActivity.
  ///
  /// In sv, this message translates to:
  /// **'Vänners aktivitet'**
  String get discoveryFriendActivity;

  /// No description provided for @discoveryFriendActivityDescription.
  ///
  /// In sv, this message translates to:
  /// **'När dina vänner delar recept, menyer eller inköpslistor visas de här.'**
  String get discoveryFriendActivityDescription;

  /// No description provided for @discoveryFriendActivityWillAppearHere.
  ///
  /// In sv, this message translates to:
  /// **'Aktivitet från dina vänner visas här'**
  String get discoveryFriendActivityWillAppearHere;

  /// No description provided for @discoveryFriendsChoice.
  ///
  /// In sv, this message translates to:
  /// **'Vänners val'**
  String get discoveryFriendsChoice;

  /// No description provided for @discoveryLearningPreferences.
  ///
  /// In sv, this message translates to:
  /// **'Vi lär oss dina preferenser för att ge bättre rekommendationer.'**
  String get discoveryLearningPreferences;

  /// No description provided for @discoveryLike.
  ///
  /// In sv, this message translates to:
  /// **'Gilla'**
  String get discoveryLike;

  /// No description provided for @discoveryListening.
  ///
  /// In sv, this message translates to:
  /// **'Lyssnar...'**
  String get discoveryListening;

  /// No description provided for @discoveryLists.
  ///
  /// In sv, this message translates to:
  /// **'Listor'**
  String get discoveryLists;

  /// No description provided for @discoveryLoadingPopularContent.
  ///
  /// In sv, this message translates to:
  /// **'Laddar populärt innehåll...'**
  String get discoveryLoadingPopularContent;

  /// No description provided for @discoveryNoFriendActivityYet.
  ///
  /// In sv, this message translates to:
  /// **'Ingen vänaktivitet än'**
  String get discoveryNoFriendActivityYet;

  /// No description provided for @discoveryNoPopularRecipesYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga populära recept än'**
  String get discoveryNoPopularRecipesYet;

  /// No description provided for @discoveryPerformedAction.
  ///
  /// In sv, this message translates to:
  /// **'Utförde en aktivitet'**
  String get discoveryPerformedAction;

  /// No description provided for @discoveryPopular.
  ///
  /// In sv, this message translates to:
  /// **'Populärt'**
  String get discoveryPopular;

  /// No description provided for @discoveryPopularContent.
  ///
  /// In sv, this message translates to:
  /// **'Populärt innehåll'**
  String get discoveryPopularContent;

  /// No description provided for @discoveryPopularMenus.
  ///
  /// In sv, this message translates to:
  /// **'Populära menyer'**
  String get discoveryPopularMenus;

  /// No description provided for @discoveryPopularRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Populära recept'**
  String get discoveryPopularRecipes;

  /// No description provided for @discoveryPopularShoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'Populära inköpslistor'**
  String get discoveryPopularShoppingLists;

  /// No description provided for @discoveryPopularWithFriends.
  ///
  /// In sv, this message translates to:
  /// **'Populärt bland vänner'**
  String get discoveryPopularWithFriends;

  /// No description provided for @discoveryPopularWithFriendsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Innehåll som dina vänner gillar och delar'**
  String get discoveryPopularWithFriendsDescription;

  /// No description provided for @discoveryPortions.
  ///
  /// In sv, this message translates to:
  /// **'{count} portioner'**
  String discoveryPortions(int count);

  /// No description provided for @discoveryRecently.
  ///
  /// In sv, this message translates to:
  /// **'Nyligen'**
  String get discoveryRecently;

  /// No description provided for @discoveryRecentlyShared.
  ///
  /// In sv, this message translates to:
  /// **'Nyligen delat'**
  String get discoveryRecentlyShared;

  /// No description provided for @discoveryRecentlySharedDescription.
  ///
  /// In sv, this message translates to:
  /// **'Senast delade innehåll i ditt nätverk'**
  String get discoveryRecentlySharedDescription;

  /// No description provided for @discoveryRecommendationHidden.
  ///
  /// In sv, this message translates to:
  /// **'Rekommendation dold. Vi visar inte liknande innehåll.'**
  String get discoveryRecommendationHidden;

  /// No description provided for @discoveryRecommendationRestored.
  ///
  /// In sv, this message translates to:
  /// **'Rekommendation återställd.'**
  String get discoveryRecommendationRestored;

  /// No description provided for @discoveryRecommended.
  ///
  /// In sv, this message translates to:
  /// **'Rekommenderat'**
  String get discoveryRecommended;

  /// No description provided for @discoveryRecommendedForYou.
  ///
  /// In sv, this message translates to:
  /// **'Rekommenderat för dig'**
  String get discoveryRecommendedForYou;

  /// No description provided for @discoverySearchFilters.
  ///
  /// In sv, this message translates to:
  /// **'Sökfilter'**
  String get discoverySearchFilters;

  /// No description provided for @discoverySearchHint.
  ///
  /// In sv, this message translates to:
  /// **'Sök recept, menyer, inköpslistor...'**
  String get discoverySearchHint;

  /// No description provided for @discoverySearchResultsFor.
  ///
  /// In sv, this message translates to:
  /// **'{count} resultat för \"{query}\"'**
  String discoverySearchResultsFor(int count, String query);

  /// No description provided for @discoverySeasonal.
  ///
  /// In sv, this message translates to:
  /// **'Säsong'**
  String get discoverySeasonal;

  /// No description provided for @discoverySharedBy.
  ///
  /// In sv, this message translates to:
  /// **'Delad av {name}'**
  String discoverySharedBy(String name);

  /// No description provided for @discoverySharing.
  ///
  /// In sv, this message translates to:
  /// **'delning'**
  String get discoverySharing;

  /// No description provided for @discoverySimilarToShared.
  ///
  /// In sv, this message translates to:
  /// **'Liknar delat'**
  String get discoverySimilarToShared;

  /// No description provided for @discoveryTimeAgoDays.
  ///
  /// In sv, this message translates to:
  /// **'{count}d sedan'**
  String discoveryTimeAgoDays(int count);

  /// No description provided for @discoveryTimeAgoHours.
  ///
  /// In sv, this message translates to:
  /// **'{count}h sedan'**
  String discoveryTimeAgoHours(int count);

  /// No description provided for @discoveryTimeAgoMinutes.
  ///
  /// In sv, this message translates to:
  /// **'{count}m sedan'**
  String discoveryTimeAgoMinutes(int count);

  /// No description provided for @discoveryTimeAgoNow.
  ///
  /// In sv, this message translates to:
  /// **'Nu'**
  String get discoveryTimeAgoNow;

  /// No description provided for @discoveryUnknownContent.
  ///
  /// In sv, this message translates to:
  /// **'Okänt innehåll'**
  String get discoveryUnknownContent;

  /// No description provided for @discoveryUnknownUser.
  ///
  /// In sv, this message translates to:
  /// **'Okänd användare'**
  String get discoveryUnknownUser;

  /// No description provided for @discoveryUserSharedType.
  ///
  /// In sv, this message translates to:
  /// **'{user} delade {type}'**
  String discoveryUserSharedType(String user, String type);

  /// No description provided for @discoveryVoiceSearch.
  ///
  /// In sv, this message translates to:
  /// **'Röstsökning'**
  String get discoveryVoiceSearch;

  /// No description provided for @discoveryVoiceSearchInstruction.
  ///
  /// In sv, this message translates to:
  /// **'Tryck på mikrofonen och börja prata'**
  String get discoveryVoiceSearchInstruction;

  /// No description provided for @discoveryVoiceSearchPreview.
  ///
  /// In sv, this message translates to:
  /// **'Sökning startad! (Röstsökning är en förhandsversion)'**
  String get discoveryVoiceSearchPreview;

  /// No description provided for @discoveryVoiceSearchPrompt.
  ///
  /// In sv, this message translates to:
  /// **'Säg vad du vill söka efter...'**
  String get discoveryVoiceSearchPrompt;

  /// No description provided for @discoveryVoiceSearchResult.
  ///
  /// In sv, this message translates to:
  /// **'Röstsökning: \"pasta recept\"'**
  String get discoveryVoiceSearchResult;

  /// No description provided for @groupInvitationsCount.
  ///
  /// In sv, this message translates to:
  /// **'Gruppinbjudningar ({count})'**
  String groupInvitationsCount(int count);

  /// No description provided for @groupInvitationsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Du har fått inbjudningar att gå med i grupper'**
  String get groupInvitationsDescription;

  /// No description provided for @groupLoadingGroups.
  ///
  /// In sv, this message translates to:
  /// **'Laddar grupper...'**
  String get groupLoadingGroups;

  /// No description provided for @groupMyGroupsCount.
  ///
  /// In sv, this message translates to:
  /// **'Mina grupper ({count})'**
  String groupMyGroupsCount(int count);

  /// No description provided for @groupNoGroupsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Skapa din första grupp eller vänta på inbjudningar från vänner.'**
  String get groupNoGroupsDescription;

  /// No description provided for @groupNoGroupsYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga grupper än'**
  String get groupNoGroupsYet;

  /// No description provided for @groupSearchGroups.
  ///
  /// In sv, this message translates to:
  /// **'Sök bland dina grupper'**
  String get groupSearchGroups;

  /// No description provided for @groupSearchGroupsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Skriv ett gruppnamn i sökfältet ovan för att filtrera dina grupper.'**
  String get groupSearchGroupsDescription;

  /// No description provided for @groupCouldNotAcceptInvitation.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte acceptera inbjudan. Försök igen.'**
  String get groupCouldNotAcceptInvitation;

  /// No description provided for @groupCreated.
  ///
  /// In sv, this message translates to:
  /// **'Skapad'**
  String get groupCreated;

  /// No description provided for @groupDaysActive.
  ///
  /// In sv, this message translates to:
  /// **'Dagar aktiv'**
  String get groupDaysActive;

  /// No description provided for @groupDeleteGroup.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort grupp'**
  String get groupDeleteGroup;

  /// No description provided for @groupViewMembers.
  ///
  /// In sv, this message translates to:
  /// **'Visa medlemmar'**
  String get groupViewMembers;

  /// No description provided for @groupEditGroup.
  ///
  /// In sv, this message translates to:
  /// **'Redigera grupp'**
  String get groupEditGroup;

  /// No description provided for @groupInformation.
  ///
  /// In sv, this message translates to:
  /// **'Gruppinformation'**
  String get groupInformation;

  /// No description provided for @groupInvitationAccepted.
  ///
  /// In sv, this message translates to:
  /// **'Inbjudan accepterad! Välkommen till gruppen!'**
  String get groupInvitationAccepted;

  /// No description provided for @groupInvitationDeclined.
  ///
  /// In sv, this message translates to:
  /// **'Inbjudan avvisad'**
  String get groupInvitationDeclined;

  /// No description provided for @groupInvitationFrom.
  ///
  /// In sv, this message translates to:
  /// **'Inbjudan från {name}'**
  String groupInvitationFrom(String name);

  /// No description provided for @groupLeaveGroup.
  ///
  /// In sv, this message translates to:
  /// **'Lämna grupp'**
  String get groupLeaveGroup;

  /// No description provided for @groupMemberCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} personer'**
  String groupMemberCount(int count);

  /// No description provided for @groupMembers.
  ///
  /// In sv, this message translates to:
  /// **'Medlemmar'**
  String get groupMembers;

  /// No description provided for @groupMembersAndInvitations.
  ///
  /// In sv, this message translates to:
  /// **'Medlemmar & Inbjudningar'**
  String get groupMembersAndInvitations;

  /// No description provided for @groupMembersCount.
  ///
  /// In sv, this message translates to:
  /// **'Medlemmar ({count})'**
  String groupMembersCount(int count);

  /// No description provided for @groupNoDescription.
  ///
  /// In sv, this message translates to:
  /// **'Ingen beskrivning'**
  String get groupNoDescription;

  /// No description provided for @groupNoMembersDescription.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vänner i den här gruppen för att komma igång.'**
  String get groupNoMembersDescription;

  /// No description provided for @groupNoMembersYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga medlemmar än'**
  String get groupNoMembersYet;

  /// No description provided for @groupPendingInvitationsCount.
  ///
  /// In sv, this message translates to:
  /// **'Väntande inbjudningar ({count})'**
  String groupPendingInvitationsCount(int count);

  /// No description provided for @groupSent.
  ///
  /// In sv, this message translates to:
  /// **'Skickat'**
  String get groupSent;

  /// No description provided for @groupUpdatedDate.
  ///
  /// In sv, this message translates to:
  /// **'Uppdaterad'**
  String get groupUpdatedDate;

  /// No description provided for @groupYesterday.
  ///
  /// In sv, this message translates to:
  /// **'Igår'**
  String get groupYesterday;

  /// No description provided for @commonAccept.
  ///
  /// In sv, this message translates to:
  /// **'Acceptera'**
  String get commonAccept;

  /// No description provided for @commonDecline.
  ///
  /// In sv, this message translates to:
  /// **'Avvisa'**
  String get commonDecline;

  /// No description provided for @shoppingItemCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} varor'**
  String shoppingItemCount(int count);

  /// No description provided for @socialAddFriendsToGetStarted.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vänner för att komma igång med social funktionalitet.'**
  String get socialAddFriendsToGetStarted;

  /// No description provided for @socialLoadingFriends.
  ///
  /// In sv, this message translates to:
  /// **'Laddar vänner...'**
  String get socialLoadingFriends;

  /// No description provided for @socialNoFriendsYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner än'**
  String get socialNoFriendsYet;

  /// No description provided for @socialSearchForNewFriends.
  ///
  /// In sv, this message translates to:
  /// **'Sök efter nya vänner'**
  String get socialSearchForNewFriends;

  /// No description provided for @socialSearchForNewFriendsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Skriv ett namn eller användarnamn i sökfältet ovan för att hitta nya vänner.'**
  String get socialSearchForNewFriendsDescription;

  /// No description provided for @socialSearchingUsers.
  ///
  /// In sv, this message translates to:
  /// **'Söker användare...'**
  String get socialSearchingUsers;

  /// No description provided for @socialBlocked.
  ///
  /// In sv, this message translates to:
  /// **'Blockerad'**
  String get socialBlocked;

  /// No description provided for @socialCouldNotAcceptFriendRequest.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte acceptera vänskapsförfrågan'**
  String get socialCouldNotAcceptFriendRequest;

  /// No description provided for @socialCouldNotFindFriendRequest.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte hitta vänskapsförfrågan'**
  String get socialCouldNotFindFriendRequest;

  /// No description provided for @socialCouldNotSendFriendRequest.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skicka vänförfrågan'**
  String get socialCouldNotSendFriendRequest;

  /// No description provided for @socialDefaultFriendMessage.
  ///
  /// In sv, this message translates to:
  /// **'Hej! Skulle vi kunna bli vänner?'**
  String get socialDefaultFriendMessage;

  /// No description provided for @socialFindNewFriends.
  ///
  /// In sv, this message translates to:
  /// **'Hitta nya vänner'**
  String get socialFindNewFriends;

  /// No description provided for @socialFindNewFriendsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Använd sökfältet ovan för att hitta personer du vill bli vän med. Sök på namn eller användarnamn.'**
  String get socialFindNewFriendsDescription;

  /// No description provided for @socialFriendRequestAccepted.
  ///
  /// In sv, this message translates to:
  /// **'Vänskapsförfrågan accepterad!'**
  String get socialFriendRequestAccepted;

  /// No description provided for @socialFriendRequestAcceptedFrom.
  ///
  /// In sv, this message translates to:
  /// **'Vänskapsförfrågan från {name} accepterad!'**
  String socialFriendRequestAcceptedFrom(String name);

  /// No description provided for @socialFriendRequestDeclined.
  ///
  /// In sv, this message translates to:
  /// **'Vänskapsförfrågan avböjd'**
  String get socialFriendRequestDeclined;

  /// No description provided for @socialFriendRequestSent.
  ///
  /// In sv, this message translates to:
  /// **'Vänförfrågan skickad till {name}!'**
  String socialFriendRequestSent(String name);

  /// No description provided for @socialIncomingRequests.
  ///
  /// In sv, this message translates to:
  /// **'Inkommande förfrågningar'**
  String get socialIncomingRequests;

  /// No description provided for @socialNoFriendRequests.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänskapsförfrågningar'**
  String get socialNoFriendRequests;

  /// No description provided for @socialNoFriendRequestsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Börja söka efter vänner ovan för att utvidga ditt nätverk!'**
  String get socialNoFriendRequestsDescription;

  /// No description provided for @socialRequestSent.
  ///
  /// In sv, this message translates to:
  /// **'Skickad'**
  String get socialRequestSent;

  /// No description provided for @socialSentRequests.
  ///
  /// In sv, this message translates to:
  /// **'Skickade förfrågningar'**
  String get socialSentRequests;

  /// No description provided for @socialWaitingForResponse.
  ///
  /// In sv, this message translates to:
  /// **'Väntar på svar...'**
  String get socialWaitingForResponse;

  /// No description provided for @addRecipeTitle.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till recept'**
  String get addRecipeTitle;

  /// No description provided for @authPassword.
  ///
  /// In sv, this message translates to:
  /// **'Lösenord'**
  String get authPassword;

  /// No description provided for @authTagline.
  ///
  /// In sv, this message translates to:
  /// **'Smart recepthantering för din vardag'**
  String get authTagline;

  /// No description provided for @collaborativeAdd.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till'**
  String get collaborativeAdd;

  /// No description provided for @collaborativeAddFirstItem.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till den första varan'**
  String get collaborativeAddFirstItem;

  /// No description provided for @collaborativeAdding.
  ///
  /// In sv, this message translates to:
  /// **'Lägger till...'**
  String get collaborativeAdding;

  /// No description provided for @collaborativeAddItemHint.
  ///
  /// In sv, this message translates to:
  /// **'Skriv varunamn...'**
  String get collaborativeAddItemHint;

  /// No description provided for @collaborativeClearAll.
  ///
  /// In sv, this message translates to:
  /// **'Rensa alla'**
  String get collaborativeClearAll;

  /// No description provided for @collaborativeClearCompleted.
  ///
  /// In sv, this message translates to:
  /// **'Rensa avprickade'**
  String get collaborativeClearCompleted;

  /// No description provided for @collaborativeClearCompletedConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du rensa alla avprickade varor?'**
  String get collaborativeClearCompletedConfirm;

  /// No description provided for @collaborativeClearCompletedMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du rensa {count} avprickade varor?'**
  String collaborativeClearCompletedMessage(int count);

  /// No description provided for @collaborativeCompleted.
  ///
  /// In sv, this message translates to:
  /// **'Avprickade'**
  String get collaborativeCompleted;

  /// No description provided for @collaborativeCompletedItemsCleared.
  ///
  /// In sv, this message translates to:
  /// **'{count} avprickade varor rensade'**
  String collaborativeCompletedItemsCleared(int count);

  /// No description provided for @collaborativeCompletedOf.
  ///
  /// In sv, this message translates to:
  /// **'{completed} av {total} avprickade'**
  String collaborativeCompletedOf(int completed, int total);

  /// No description provided for @collaborativeCopyLink.
  ///
  /// In sv, this message translates to:
  /// **'Kopiera länk'**
  String get collaborativeCopyLink;

  /// No description provided for @collaborativeCopyLinkDescription.
  ///
  /// In sv, this message translates to:
  /// **'Dela via länk'**
  String get collaborativeCopyLinkDescription;

  /// No description provided for @collaborativeCouldNotClearCompleted.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte rensa avprickade varor'**
  String get collaborativeCouldNotClearCompleted;

  /// No description provided for @collaborativeEmailSharingComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'E-postdelning kommer snart'**
  String get collaborativeEmailSharingComingSoon;

  /// No description provided for @collaborativeLinkCopied.
  ///
  /// In sv, this message translates to:
  /// **'Länk kopierad!'**
  String get collaborativeLinkCopied;

  /// No description provided for @collaborativeManageMembers.
  ///
  /// In sv, this message translates to:
  /// **'Hantera medlemmar'**
  String get collaborativeManageMembers;

  /// No description provided for @collaborativeMembersComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Medlemshantering kommer snart'**
  String get collaborativeMembersComingSoon;

  /// No description provided for @collaborativeMessageSharingComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Meddelandedelning kommer snart'**
  String get collaborativeMessageSharingComingSoon;

  /// No description provided for @collaborativeMoreActions.
  ///
  /// In sv, this message translates to:
  /// **'Fler åtgärder'**
  String get collaborativeMoreActions;

  /// No description provided for @collaborativeNoCompletedItems.
  ///
  /// In sv, this message translates to:
  /// **'Inga avprickade varor'**
  String get collaborativeNoCompletedItems;

  /// No description provided for @collaborativeNoItemsYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga varor ännu'**
  String get collaborativeNoItemsYet;

  /// No description provided for @collaborativeSendEmail.
  ///
  /// In sv, this message translates to:
  /// **'Skicka e-post'**
  String get collaborativeSendEmail;

  /// No description provided for @collaborativeSendEmailDescription.
  ///
  /// In sv, this message translates to:
  /// **'Dela via e-post'**
  String get collaborativeSendEmailDescription;

  /// No description provided for @collaborativeSendMessage.
  ///
  /// In sv, this message translates to:
  /// **'Skicka meddelande'**
  String get collaborativeSendMessage;

  /// No description provided for @collaborativeSendMessageDescription.
  ///
  /// In sv, this message translates to:
  /// **'Dela via meddelande'**
  String get collaborativeSendMessageDescription;

  /// No description provided for @collaborativeSettings.
  ///
  /// In sv, this message translates to:
  /// **'Inställningar'**
  String get collaborativeSettings;

  /// No description provided for @collaborativeSettingsComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Inställningar kommer snart'**
  String get collaborativeSettingsComingSoon;

  /// No description provided for @collaborativeShareList.
  ///
  /// In sv, this message translates to:
  /// **'Dela listan'**
  String get collaborativeShareList;

  /// No description provided for @collaborativeViewOnly.
  ///
  /// In sv, this message translates to:
  /// **'Kan bara se'**
  String get collaborativeViewOnly;

  /// No description provided for @collaborativeWaitingForOthers.
  ///
  /// In sv, this message translates to:
  /// **'Väntar på andra...'**
  String get collaborativeWaitingForOthers;

  /// No description provided for @commonActionCannotBeUndone.
  ///
  /// In sv, this message translates to:
  /// **'Denna åtgärd kan inte ångras.'**
  String get commonActionCannotBeUndone;

  /// No description provided for @commonDescription.
  ///
  /// In sv, this message translates to:
  /// **'Beskrivning'**
  String get commonDescription;

  /// No description provided for @commonShowMore.
  ///
  /// In sv, this message translates to:
  /// **'Visa mer'**
  String get commonShowMore;

  /// No description provided for @commonType.
  ///
  /// In sv, this message translates to:
  /// **'Typ'**
  String get commonType;

  /// No description provided for @commonUnknownError.
  ///
  /// In sv, this message translates to:
  /// **'Ett okänt fel inträffade'**
  String get commonUnknownError;

  /// No description provided for @commonView.
  ///
  /// In sv, this message translates to:
  /// **'Visa'**
  String get commonView;

  /// No description provided for @discoveryClearSearch.
  ///
  /// In sv, this message translates to:
  /// **'Rensa sökning'**
  String get discoveryClearSearch;

  /// No description provided for @groupCancelInvitation.
  ///
  /// In sv, this message translates to:
  /// **'Avbryt inbjudan'**
  String get groupCancelInvitation;

  /// No description provided for @groupCancelInvitationConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill avbryta denna inbjudan?'**
  String get groupCancelInvitationConfirm;

  /// No description provided for @groupCancelInvitationMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du avbryta inbjudan till {name}?'**
  String groupCancelInvitationMessage(String name);

  /// No description provided for @groupCouldNotCreate.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa grupp: {error}'**
  String groupCouldNotCreate(String error);

  /// No description provided for @groupCouldNotDelete.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort grupp: {error}'**
  String groupCouldNotDelete(String error);

  /// No description provided for @groupCouldNotLeave.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lämna grupp: {error}'**
  String groupCouldNotLeave(String error);

  /// No description provided for @groupCouldNotRemoveMember.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort medlem: {error}'**
  String groupCouldNotRemoveMember(String error);

  /// No description provided for @groupCouldNotUpdate.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera grupp: {error}'**
  String groupCouldNotUpdate(String error);

  /// No description provided for @groupCreatedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Grupp skapad!'**
  String get groupCreatedSuccess;

  /// No description provided for @groupCreateGroup.
  ///
  /// In sv, this message translates to:
  /// **'Skapa grupp'**
  String get groupCreateGroup;

  /// No description provided for @groupCreator.
  ///
  /// In sv, this message translates to:
  /// **'Skapare'**
  String get groupCreator;

  /// No description provided for @groupEmoji.
  ///
  /// In sv, this message translates to:
  /// **'Emoji'**
  String get groupEmoji;

  /// No description provided for @groupGroupName.
  ///
  /// In sv, this message translates to:
  /// **'Gruppnamn'**
  String get groupGroupName;

  /// No description provided for @groupInvitationCancelled.
  ///
  /// In sv, this message translates to:
  /// **'Inbjudan avbruten'**
  String get groupInvitationCancelled;

  /// No description provided for @groupInvitationExpires.
  ///
  /// In sv, this message translates to:
  /// **'Inbjudan går ut'**
  String get groupInvitationExpires;

  /// No description provided for @groupInvitationSentDate.
  ///
  /// In sv, this message translates to:
  /// **'Skickad'**
  String get groupInvitationSentDate;

  /// No description provided for @groupItemType.
  ///
  /// In sv, this message translates to:
  /// **'Typ'**
  String get groupItemType;

  /// No description provided for @groupLeave.
  ///
  /// In sv, this message translates to:
  /// **'Lämna'**
  String get groupLeave;

  /// No description provided for @groupLeaveGroupConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du lämna gruppen {name}?'**
  String groupLeaveGroupConfirm(String name);

  /// No description provided for @groupLeftGroup.
  ///
  /// In sv, this message translates to:
  /// **'Du har lämnat gruppen'**
  String get groupLeftGroup;

  /// No description provided for @groupManageGroup.
  ///
  /// In sv, this message translates to:
  /// **'Hantera grupp'**
  String get groupManageGroup;

  /// No description provided for @groupMemberRemoved.
  ///
  /// In sv, this message translates to:
  /// **'{name} har tagits bort'**
  String groupMemberRemoved(String name);

  /// No description provided for @groupOwner.
  ///
  /// In sv, this message translates to:
  /// **'Ägare'**
  String get groupOwner;

  /// No description provided for @groupRemoveFromGroup.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort från grupp'**
  String get groupRemoveFromGroup;

  /// No description provided for @groupRemoveMember.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort medlem'**
  String get groupRemoveMember;

  /// No description provided for @groupRemoveMemberConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du ta bort {name} från {groupName}?'**
  String groupRemoveMemberConfirm(String name, String groupName);

  /// No description provided for @groupShareMenu.
  ///
  /// In sv, this message translates to:
  /// **'Dela meny'**
  String get groupShareMenu;

  /// No description provided for @groupShareRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Dela recept'**
  String get groupShareRecipe;

  /// No description provided for @groupShareWithGroup.
  ///
  /// In sv, this message translates to:
  /// **'Dela med grupp'**
  String get groupShareWithGroup;

  /// No description provided for @groupYesCancel.
  ///
  /// In sv, this message translates to:
  /// **'Ja, avbryt'**
  String get groupYesCancel;

  /// No description provided for @sharedAlreadyMember.
  ///
  /// In sv, this message translates to:
  /// **'Du är redan medlem'**
  String get sharedAlreadyMember;

  /// No description provided for @sharedContent.
  ///
  /// In sv, this message translates to:
  /// **'Delat innehåll'**
  String get sharedContent;

  /// No description provided for @sharedCopy.
  ///
  /// In sv, this message translates to:
  /// **'Kopiera'**
  String get sharedCopy;

  /// No description provided for @sharedCouldNotHideMenu.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dölja meny'**
  String get sharedCouldNotHideMenu;

  /// No description provided for @sharedCouldNotHideRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dölja recept'**
  String get sharedCouldNotHideRecipe;

  /// No description provided for @sharedCouldNotHideShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dölja inköpslista'**
  String get sharedCouldNotHideShoppingList;

  /// No description provided for @sharedCouldNotJoinList.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte gå med i listan'**
  String get sharedCouldNotJoinList;

  /// No description provided for @sharedCouldNotJoinListTryAgain.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte gå med i listan. Försök igen.'**
  String get sharedCouldNotJoinListTryAgain;

  /// No description provided for @sharedHideImported.
  ///
  /// In sv, this message translates to:
  /// **'Dölj importerade'**
  String get sharedHideImported;

  /// No description provided for @sharedHideMenu.
  ///
  /// In sv, this message translates to:
  /// **'Dölj meny'**
  String get sharedHideMenu;

  /// No description provided for @sharedHideRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Dölj recept'**
  String get sharedHideRecipe;

  /// No description provided for @sharedHideShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Dölj inköpslista'**
  String get sharedHideShoppingList;

  /// No description provided for @sharedImport.
  ///
  /// In sv, this message translates to:
  /// **'Importera'**
  String get sharedImport;

  /// No description provided for @sharedImported.
  ///
  /// In sv, this message translates to:
  /// **'Importerad'**
  String get sharedImported;

  /// No description provided for @sharedImportFailed.
  ///
  /// In sv, this message translates to:
  /// **'Import misslyckades'**
  String get sharedImportFailed;

  /// No description provided for @sharedJoin.
  ///
  /// In sv, this message translates to:
  /// **'Gå med'**
  String get sharedJoin;

  /// No description provided for @sharedJoinedButCouldNotNavigate.
  ///
  /// In sv, this message translates to:
  /// **'Gick med men kunde inte navigera till listan'**
  String get sharedJoinedButCouldNotNavigate;

  /// No description provided for @sharedJoinList.
  ///
  /// In sv, this message translates to:
  /// **'Gå med i lista'**
  String get sharedJoinList;

  /// No description provided for @sharedLive.
  ///
  /// In sv, this message translates to:
  /// **'Live'**
  String get sharedLive;

  /// No description provided for @sharedMember.
  ///
  /// In sv, this message translates to:
  /// **'Medlem'**
  String get sharedMember;

  /// No description provided for @sharedNoMenus.
  ///
  /// In sv, this message translates to:
  /// **'Inga delade menyer'**
  String get sharedNoMenus;

  /// No description provided for @sharedNoMenusDescription.
  ///
  /// In sv, this message translates to:
  /// **'Menyer som delas med dig visas här'**
  String get sharedNoMenusDescription;

  /// No description provided for @sharedNoRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Inga delade recept'**
  String get sharedNoRecipes;

  /// No description provided for @sharedNoRecipesDescription.
  ///
  /// In sv, this message translates to:
  /// **'Recept som delas med dig visas här'**
  String get sharedNoRecipesDescription;

  /// No description provided for @sharedNoShoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'Inga delade inköpslistor'**
  String get sharedNoShoppingLists;

  /// No description provided for @sharedNoShoppingListsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslistor som delas med dig visas här'**
  String get sharedNoShoppingListsDescription;

  /// No description provided for @sharedSearchHint.
  ///
  /// In sv, this message translates to:
  /// **'Sök delat innehåll...'**
  String get sharedSearchHint;

  /// No description provided for @sharedTabRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Recept ({count})'**
  String sharedTabRecipes(int count);

  /// No description provided for @sharedTabMenus.
  ///
  /// In sv, this message translates to:
  /// **'Menyer ({count})'**
  String sharedTabMenus(int count);

  /// No description provided for @sharedTabShoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslistor ({count})'**
  String sharedTabShoppingLists(int count);

  /// No description provided for @sharedShowImported.
  ///
  /// In sv, this message translates to:
  /// **'Visa importerade'**
  String get sharedShowImported;

  /// No description provided for @sharedShowingImported.
  ///
  /// In sv, this message translates to:
  /// **'Visar importerade'**
  String get sharedShowingImported;

  /// No description provided for @sharedTapToSeeAllItems.
  ///
  /// In sv, this message translates to:
  /// **'Tryck för att se alla varor'**
  String get sharedTapToSeeAllItems;

  /// No description provided for @sharedByName.
  ///
  /// In sv, this message translates to:
  /// **'Delad av {name}'**
  String sharedByName(String name);

  /// No description provided for @sharedCategoryCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} kategorier'**
  String sharedCategoryCount(int count);

  /// No description provided for @sharedConnectingToCollaborativeMenu.
  ///
  /// In sv, this message translates to:
  /// **'Ansluter till samarbetsmeny: {title}'**
  String sharedConnectingToCollaborativeMenu(String title);

  /// No description provided for @sharedContentHidden.
  ///
  /// In sv, this message translates to:
  /// **'{title} har dolts'**
  String sharedContentHidden(String title);

  /// No description provided for @sharedHideMenuConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du dölja menyn \"{title}\" delad av {sharedBy}?'**
  String sharedHideMenuConfirm(String title, String sharedBy);

  /// No description provided for @sharedHideRecipeConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du dölja receptet \"{title}\" delat av {sharedBy}?'**
  String sharedHideRecipeConfirm(String title, String sharedBy);

  /// No description provided for @sharedHideShoppingListConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du dölja inköpslistan \"{name}\" delad av {sharedBy}?'**
  String sharedHideShoppingListConfirm(String name, String sharedBy);

  /// No description provided for @sharedJoinedList.
  ///
  /// In sv, this message translates to:
  /// **'Gick med i listan \"{name}\"'**
  String sharedJoinedList(String name);

  /// No description provided for @sharedJoinedListFindInShopping.
  ///
  /// In sv, this message translates to:
  /// **'Gick med i \"{name}\". Hitta den under Inköpslistor.'**
  String sharedJoinedListFindInShopping(String name);

  /// No description provided for @sharedMenuImported.
  ///
  /// In sv, this message translates to:
  /// **'Menyn \"{title}\" har importerats'**
  String sharedMenuImported(String title);

  /// No description provided for @sharedRecipeImported.
  ///
  /// In sv, this message translates to:
  /// **'Receptet \"{title}\" har importerats'**
  String sharedRecipeImported(String title);

  /// No description provided for @recipePortionsCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} portioner'**
  String recipePortionsCount(int count);

  /// No description provided for @shoppingAddedWithEditPermission.
  ///
  /// In sv, this message translates to:
  /// **'Tillagd med redigeringsbehörighet'**
  String get shoppingAddedWithEditPermission;

  /// No description provided for @shoppingAddFriends.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vänner'**
  String get shoppingAddFriends;

  /// No description provided for @shoppingAdminOwner.
  ///
  /// In sv, this message translates to:
  /// **'Admin/Ägare'**
  String get shoppingAdminOwner;

  /// No description provided for @shoppingAdminOwnerDescription.
  ///
  /// In sv, this message translates to:
  /// **'Full åtkomst och hantering'**
  String get shoppingAdminOwnerDescription;

  /// No description provided for @shoppingAllFriendsAreMembers.
  ///
  /// In sv, this message translates to:
  /// **'Alla vänner är redan medlemmar'**
  String get shoppingAllFriendsAreMembers;

  /// No description provided for @shoppingBy.
  ///
  /// In sv, this message translates to:
  /// **'Av'**
  String get shoppingBy;

  /// No description provided for @shoppingCategoryHint.
  ///
  /// In sv, this message translates to:
  /// **'Välj kategori...'**
  String get shoppingCategoryHint;

  /// No description provided for @shoppingCategoryOther.
  ///
  /// In sv, this message translates to:
  /// **'Övrigt'**
  String get shoppingCategoryOther;

  /// No description provided for @shoppingClear.
  ///
  /// In sv, this message translates to:
  /// **'Rensa'**
  String get shoppingClear;

  /// No description provided for @shoppingClearPurchasedTitle.
  ///
  /// In sv, this message translates to:
  /// **'Rensa köpta varor'**
  String get shoppingClearPurchasedTitle;

  /// No description provided for @shoppingCouldNotAddMembers.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lägga till medlemmar'**
  String get shoppingCouldNotAddMembers;

  /// No description provided for @shoppingCouldNotDeleteList.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort lista'**
  String get shoppingCouldNotDeleteList;

  /// No description provided for @shoppingCouldNotRemoveMember.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort medlem'**
  String get shoppingCouldNotRemoveMember;

  /// No description provided for @shoppingCouldNotRenameList.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte byta namn på lista'**
  String get shoppingCouldNotRenameList;

  /// No description provided for @shoppingCouldNotUpdatePermission.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera behörighet'**
  String get shoppingCouldNotUpdatePermission;

  /// No description provided for @shoppingCreateNewList.
  ///
  /// In sv, this message translates to:
  /// **'Skapa ny lista'**
  String get shoppingCreateNewList;

  /// No description provided for @shoppingCreateNewListHint.
  ///
  /// In sv, this message translates to:
  /// **'Namn på ny inköpslista...'**
  String get shoppingCreateNewListHint;

  /// No description provided for @shoppingCreateSharedList.
  ///
  /// In sv, this message translates to:
  /// **'Skapa delad lista'**
  String get shoppingCreateSharedList;

  /// No description provided for @shoppingCreateSharedListDescription.
  ///
  /// In sv, this message translates to:
  /// **'Skapa en ny inköpslista att dela med vänner'**
  String get shoppingCreateSharedListDescription;

  /// No description provided for @shoppingCreator.
  ///
  /// In sv, this message translates to:
  /// **'Skapare'**
  String get shoppingCreator;

  /// No description provided for @shoppingDeleteList.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort lista'**
  String get shoppingDeleteList;

  /// No description provided for @shoppingDescriptionHint.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till en beskrivning...'**
  String get shoppingDescriptionHint;

  /// No description provided for @shoppingDescriptionOptional.
  ///
  /// In sv, this message translates to:
  /// **'Beskrivning (valfritt)'**
  String get shoppingDescriptionOptional;

  /// No description provided for @shoppingItemNameHint.
  ///
  /// In sv, this message translates to:
  /// **'Varunamn...'**
  String get shoppingItemNameHint;

  /// No description provided for @shoppingJustNow.
  ///
  /// In sv, this message translates to:
  /// **'Just nu'**
  String get shoppingJustNow;

  /// No description provided for @shoppingListDetails.
  ///
  /// In sv, this message translates to:
  /// **'Listdetaljer'**
  String get shoppingListDetails;

  /// No description provided for @shoppingListInfo.
  ///
  /// In sv, this message translates to:
  /// **'Listinformation'**
  String get shoppingListInfo;

  /// No description provided for @shoppingListTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslista'**
  String get shoppingListTitle;

  /// No description provided for @shoppingManageSharing.
  ///
  /// In sv, this message translates to:
  /// **'Hantera delning'**
  String get shoppingManageSharing;

  /// No description provided for @shoppingNewNameHint.
  ///
  /// In sv, this message translates to:
  /// **'Nytt namn...'**
  String get shoppingNewNameHint;

  /// No description provided for @shoppingNoFriends.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner'**
  String get shoppingNoFriends;

  /// No description provided for @shoppingNoFriendsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vänner för att dela inköpslistor'**
  String get shoppingNoFriendsDescription;

  /// No description provided for @shoppingNoFriendsFound.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner hittades'**
  String get shoppingNoFriendsFound;

  /// No description provided for @shoppingNoItemsToShare.
  ///
  /// In sv, this message translates to:
  /// **'Inga varor att dela'**
  String get shoppingNoItemsToShare;

  /// No description provided for @shoppingNoteHint.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till anteckning...'**
  String get shoppingNoteHint;

  /// No description provided for @shoppingNoteOptional.
  ///
  /// In sv, this message translates to:
  /// **'Anteckning (valfritt)'**
  String get shoppingNoteOptional;

  /// No description provided for @shoppingPermissionAdmin.
  ///
  /// In sv, this message translates to:
  /// **'Administratör'**
  String get shoppingPermissionAdmin;

  /// No description provided for @shoppingPermissionAdminDescription.
  ///
  /// In sv, this message translates to:
  /// **'Kan lägga till, ta bort och hantera medlemmar'**
  String get shoppingPermissionAdminDescription;

  /// No description provided for @shoppingPermissionAdministrator.
  ///
  /// In sv, this message translates to:
  /// **'Administratör'**
  String get shoppingPermissionAdministrator;

  /// No description provided for @shoppingPermissionEdit.
  ///
  /// In sv, this message translates to:
  /// **'Redigera'**
  String get shoppingPermissionEdit;

  /// No description provided for @shoppingPermissionEditDescription.
  ///
  /// In sv, this message translates to:
  /// **'Kan lägga till och redigera varor'**
  String get shoppingPermissionEditDescription;

  /// No description provided for @shoppingPermissionOwner.
  ///
  /// In sv, this message translates to:
  /// **'Ägare'**
  String get shoppingPermissionOwner;

  /// No description provided for @shoppingPermissionShared.
  ///
  /// In sv, this message translates to:
  /// **'Delad'**
  String get shoppingPermissionShared;

  /// No description provided for @shoppingPermissionTemplate.
  ///
  /// In sv, this message translates to:
  /// **'Mall'**
  String get shoppingPermissionTemplate;

  /// No description provided for @shoppingPermissionUnspecified.
  ///
  /// In sv, this message translates to:
  /// **'Ospecificerad'**
  String get shoppingPermissionUnspecified;

  /// No description provided for @shoppingPermissionUnspecifiedDescription.
  ///
  /// In sv, this message translates to:
  /// **'Behörighet ej specificerad'**
  String get shoppingPermissionUnspecifiedDescription;

  /// No description provided for @shoppingPermissionView.
  ///
  /// In sv, this message translates to:
  /// **'Visa'**
  String get shoppingPermissionView;

  /// No description provided for @shoppingPermissionViewDescription.
  ///
  /// In sv, this message translates to:
  /// **'Kan se varor men inte ändra'**
  String get shoppingPermissionViewDescription;

  /// No description provided for @shoppingPermissionViewOnly.
  ///
  /// In sv, this message translates to:
  /// **'Visa'**
  String get shoppingPermissionViewOnly;

  /// No description provided for @shoppingPersonalList.
  ///
  /// In sv, this message translates to:
  /// **'Personlig lista'**
  String get shoppingPersonalList;

  /// No description provided for @shoppingPurchased.
  ///
  /// In sv, this message translates to:
  /// **'Köpta'**
  String get shoppingPurchased;

  /// No description provided for @shoppingPurchasedCleared.
  ///
  /// In sv, this message translates to:
  /// **'Köpta varor rensade'**
  String get shoppingPurchasedCleared;

  /// No description provided for @shoppingRecentActivity.
  ///
  /// In sv, this message translates to:
  /// **'Senaste aktivitet'**
  String get shoppingRecentActivity;

  /// No description provided for @shoppingRemoveMember.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort medlem'**
  String get shoppingRemoveMember;

  /// No description provided for @shoppingSearchFriends.
  ///
  /// In sv, this message translates to:
  /// **'Sök vänner...'**
  String get shoppingSearchFriends;

  /// No description provided for @shoppingSelectFriendsToShare.
  ///
  /// In sv, this message translates to:
  /// **'Välj vänner att dela med'**
  String get shoppingSelectFriendsToShare;

  /// No description provided for @shoppingSharedList.
  ///
  /// In sv, this message translates to:
  /// **'Delad lista'**
  String get shoppingSharedList;

  /// No description provided for @shoppingSharedListTitle.
  ///
  /// In sv, this message translates to:
  /// **'Delad inköpslista'**
  String get shoppingSharedListTitle;

  /// No description provided for @shoppingSharedListTitleHint.
  ///
  /// In sv, this message translates to:
  /// **'Namn på delad lista...'**
  String get shoppingSharedListTitleHint;

  /// No description provided for @shoppingShareExternally.
  ///
  /// In sv, this message translates to:
  /// **'Dela externt'**
  String get shoppingShareExternally;

  /// No description provided for @shoppingShareInfoBullets.
  ///
  /// In sv, this message translates to:
  /// **'Medlemmar kan se och redigera varor i realtid'**
  String get shoppingShareInfoBullets;

  /// No description provided for @shoppingShareWithFriends.
  ///
  /// In sv, this message translates to:
  /// **'Dela med vänner'**
  String get shoppingShareWithFriends;

  /// No description provided for @shoppingTemplateList.
  ///
  /// In sv, this message translates to:
  /// **'Mall'**
  String get shoppingTemplateList;

  /// No description provided for @shoppingUncheckAll.
  ///
  /// In sv, this message translates to:
  /// **'Avmarkera alla'**
  String get shoppingUncheckAll;

  /// No description provided for @shoppingUnitHint.
  ///
  /// In sv, this message translates to:
  /// **'Enhet...'**
  String get shoppingUnitHint;

  /// No description provided for @shoppingUnknownUser.
  ///
  /// In sv, this message translates to:
  /// **'Okänd användare'**
  String get shoppingUnknownUser;

  /// No description provided for @shoppingWhatHappensWhenSharing.
  ///
  /// In sv, this message translates to:
  /// **'Vad händer när du delar?'**
  String get shoppingWhatHappensWhenSharing;

  /// No description provided for @shoppingWhen.
  ///
  /// In sv, this message translates to:
  /// **'När'**
  String get shoppingWhen;

  /// No description provided for @shoppingYourPermission.
  ///
  /// In sv, this message translates to:
  /// **'Din behörighet'**
  String get shoppingYourPermission;

  /// No description provided for @shoppingAddFriendsCount.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till {count} vänner'**
  String shoppingAddFriendsCount(int count);

  /// No description provided for @shoppingBoughtOfTotal.
  ///
  /// In sv, this message translates to:
  /// **'{bought} av {total} köpta'**
  String shoppingBoughtOfTotal(int bought, int total);

  /// No description provided for @shoppingClearCount.
  ///
  /// In sv, this message translates to:
  /// **'Rensa {count}'**
  String shoppingClearCount(int count);

  /// No description provided for @shoppingClearPurchasedMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du rensa {count} köpta varor?'**
  String shoppingClearPurchasedMessage(int count);

  /// No description provided for @shoppingCouldNotAddItem.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lägga till {name}'**
  String shoppingCouldNotAddItem(String name);

  /// No description provided for @shoppingCouldNotLoadFriends.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda vänner: {error}'**
  String shoppingCouldNotLoadFriends(String error);

  /// No description provided for @shoppingCouldNotShowShareDialog.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte visa delningsdialog: {error}'**
  String shoppingCouldNotShowShareDialog(String error);

  /// No description provided for @shoppingCouldNotUpdateItem.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera {name}'**
  String shoppingCouldNotUpdateItem(String name);

  /// No description provided for @shoppingCurrentMembers.
  ///
  /// In sv, this message translates to:
  /// **'Nuvarande medlemmar ({count})'**
  String shoppingCurrentMembers(int count);

  /// No description provided for @shoppingCurrentName.
  ///
  /// In sv, this message translates to:
  /// **'Nuvarande namn: {name}'**
  String shoppingCurrentName(String name);

  /// No description provided for @shoppingDaysAgo.
  ///
  /// In sv, this message translates to:
  /// **'{days} dagar sedan'**
  String shoppingDaysAgo(int days);

  /// No description provided for @shoppingDeleteListConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du ta bort listan \"{name}\"?'**
  String shoppingDeleteListConfirm(String name);

  /// No description provided for @shoppingDeleteListWithItemsConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du ta bort listan \"{name}\" med {count} varor?'**
  String shoppingDeleteListWithItemsConfirm(String name, int count);

  /// No description provided for @shoppingErrorAdding.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid tillägg: {error}'**
  String shoppingErrorAdding(String error);

  /// No description provided for @shoppingErrorRemoving.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid borttagning: {error}'**
  String shoppingErrorRemoving(String error);

  /// No description provided for @shoppingErrorUpdating.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid uppdatering: {error}'**
  String shoppingErrorUpdating(String error);

  /// No description provided for @shoppingHoursAgo.
  ///
  /// In sv, this message translates to:
  /// **'{hours} timmar sedan'**
  String shoppingHoursAgo(int hours);

  /// No description provided for @shoppingItemAdded.
  ///
  /// In sv, this message translates to:
  /// **'{name} tillagd'**
  String shoppingItemAdded(String name);

  /// No description provided for @shoppingItemCountText.
  ///
  /// In sv, this message translates to:
  /// **'{count} varor'**
  String shoppingItemCountText(int count);

  /// No description provided for @shoppingItemUpdated.
  ///
  /// In sv, this message translates to:
  /// **'{name} uppdaterad'**
  String shoppingItemUpdated(String name);

  /// No description provided for @shoppingListDeleted.
  ///
  /// In sv, this message translates to:
  /// **'Listan \"{name}\" borttagen'**
  String shoppingListDeleted(String name);

  /// No description provided for @shoppingListRenamed.
  ///
  /// In sv, this message translates to:
  /// **'Listan omdöpt till \"{name}\"'**
  String shoppingListRenamed(String name);

  /// No description provided for @shoppingMemberRemoved.
  ///
  /// In sv, this message translates to:
  /// **'{name} har tagits bort'**
  String shoppingMemberRemoved(String name);

  /// No description provided for @shoppingMembersAdded.
  ///
  /// In sv, this message translates to:
  /// **'{count} medlemmar tillagda'**
  String shoppingMembersAdded(int count);

  /// No description provided for @shoppingMembersCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} medlemmar'**
  String shoppingMembersCount(int count);

  /// No description provided for @shoppingMinutesAgo.
  ///
  /// In sv, this message translates to:
  /// **'{minutes} minuter sedan'**
  String shoppingMinutesAgo(int minutes);

  /// No description provided for @shoppingPermissionUpdated.
  ///
  /// In sv, this message translates to:
  /// **'Behörighet uppdaterad för {name}'**
  String shoppingPermissionUpdated(String name);

  /// No description provided for @shoppingRemoveMemberConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du ta bort {name} från listan?'**
  String shoppingRemoveMemberConfirm(String name);

  /// No description provided for @shoppingSharedWithMembers.
  ///
  /// In sv, this message translates to:
  /// **'Delad med {count} ({permission})'**
  String shoppingSharedWithMembers(int count, String permission);

  /// No description provided for @socialAcceptAll.
  ///
  /// In sv, this message translates to:
  /// **'Acceptera alla'**
  String get socialAcceptAll;

  /// No description provided for @socialAcceptAllSelectedConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Acceptera alla valda förfrågningar?'**
  String get socialAcceptAllSelectedConfirm;

  /// No description provided for @socialAcceptSelected.
  ///
  /// In sv, this message translates to:
  /// **'Acceptera valda'**
  String get socialAcceptSelected;

  /// No description provided for @socialBlock.
  ///
  /// In sv, this message translates to:
  /// **'Blockera'**
  String get socialBlock;

  /// No description provided for @socialBlockUserConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du blockera denna användare?'**
  String get socialBlockUserConfirm;

  /// No description provided for @socialCancelAll.
  ///
  /// In sv, this message translates to:
  /// **'Avbryt alla'**
  String get socialCancelAll;

  /// No description provided for @socialCancelFriendRequestConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du avbryta denna vänskapsförfrågan?'**
  String get socialCancelFriendRequestConfirm;

  /// No description provided for @socialCancelRequest.
  ///
  /// In sv, this message translates to:
  /// **'Avbryt förfrågan'**
  String get socialCancelRequest;

  /// No description provided for @socialCancelSelectedRequestsConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Avbryt alla valda förfrågningar?'**
  String get socialCancelSelectedRequestsConfirm;

  /// No description provided for @socialCouldNotAcceptAllRequests.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte acceptera alla förfrågningar'**
  String get socialCouldNotAcceptAllRequests;

  /// No description provided for @socialCouldNotBlockUser.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte blockera användare'**
  String get socialCouldNotBlockUser;

  /// No description provided for @socialCouldNotCancelAllRequests.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte avbryta alla förfrågningar'**
  String get socialCouldNotCancelAllRequests;

  /// No description provided for @socialCouldNotCancelFriendRequest.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte avbryta vänskapsförfrågan'**
  String get socialCouldNotCancelFriendRequest;

  /// No description provided for @socialCouldNotRejectAllRequests.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte avvisa alla förfrågningar'**
  String get socialCouldNotRejectAllRequests;

  /// No description provided for @socialCouldNotRejectFriendRequest.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte avvisa vänskapsförfrågan'**
  String get socialCouldNotRejectFriendRequest;

  /// No description provided for @socialCouldNotRemoveFriend.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort vän'**
  String get socialCouldNotRemoveFriend;

  /// No description provided for @socialCouldNotSearchUsers.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte söka användare'**
  String get socialCouldNotSearchUsers;

  /// No description provided for @socialCouldNotUnblockUser.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte avblockera användare'**
  String get socialCouldNotUnblockUser;

  /// No description provided for @socialCouldNotUpdateRequests.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera förfrågningar'**
  String get socialCouldNotUpdateRequests;

  /// No description provided for @socialDecline.
  ///
  /// In sv, this message translates to:
  /// **'Avvisa'**
  String get socialDecline;

  /// No description provided for @socialDeclined.
  ///
  /// In sv, this message translates to:
  /// **'Avvisad'**
  String get socialDeclined;

  /// No description provided for @socialEnterSearchTerm.
  ///
  /// In sv, this message translates to:
  /// **'Ange ett sökord'**
  String get socialEnterSearchTerm;

  /// No description provided for @socialExpired.
  ///
  /// In sv, this message translates to:
  /// **'Utgången'**
  String get socialExpired;

  /// No description provided for @socialFindFriends.
  ///
  /// In sv, this message translates to:
  /// **'Hitta vänner'**
  String get socialFindFriends;

  /// No description provided for @socialFriendRequestsUpdated.
  ///
  /// In sv, this message translates to:
  /// **'Vänskapsförfrågningar uppdaterade'**
  String get socialFriendRequestsUpdated;

  /// No description provided for @socialFriendsAndGroups.
  ///
  /// In sv, this message translates to:
  /// **'Vänner & grupper'**
  String get socialFriendsAndGroups;

  /// No description provided for @socialGroups.
  ///
  /// In sv, this message translates to:
  /// **'Grupper'**
  String get socialGroups;

  /// No description provided for @socialIncoming.
  ///
  /// In sv, this message translates to:
  /// **'Inkommande'**
  String get socialIncoming;

  /// No description provided for @socialLoadingRequests.
  ///
  /// In sv, this message translates to:
  /// **'Laddar förfrågningar...'**
  String get socialLoadingRequests;

  /// No description provided for @socialLoadingSentRequests.
  ///
  /// In sv, this message translates to:
  /// **'Laddar skickade förfrågningar...'**
  String get socialLoadingSentRequests;

  /// No description provided for @socialNoRequestsSelected.
  ///
  /// In sv, this message translates to:
  /// **'Inga förfrågningar valda'**
  String get socialNoRequestsSelected;

  /// No description provided for @socialNoSentRequests.
  ///
  /// In sv, this message translates to:
  /// **'Inga skickade förfrågningar'**
  String get socialNoSentRequests;

  /// No description provided for @socialNoSentRequestsDescription.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga skickade vänskapsförfrågningar'**
  String get socialNoSentRequestsDescription;

  /// No description provided for @socialPendingResponse.
  ///
  /// In sv, this message translates to:
  /// **'Väntar på svar'**
  String get socialPendingResponse;

  /// No description provided for @socialReject.
  ///
  /// In sv, this message translates to:
  /// **'Avvisa'**
  String get socialReject;

  /// No description provided for @socialRejectAll.
  ///
  /// In sv, this message translates to:
  /// **'Avvisa alla'**
  String get socialRejectAll;

  /// No description provided for @socialRejectAllSelectedConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Avvisa alla valda förfrågningar?'**
  String get socialRejectAllSelectedConfirm;

  /// No description provided for @socialRejectFriendRequestConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du avvisa denna vänskapsförfrågan?'**
  String get socialRejectFriendRequestConfirm;

  /// No description provided for @socialRemoveFriendConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Vill du ta bort denna vän?'**
  String get socialRemoveFriendConfirm;

  /// No description provided for @socialRequestCancelled.
  ///
  /// In sv, this message translates to:
  /// **'Förfrågan avbruten'**
  String get socialRequestCancelled;

  /// No description provided for @socialSearchGroups.
  ///
  /// In sv, this message translates to:
  /// **'Sök grupper...'**
  String get socialSearchGroups;

  /// No description provided for @socialSearchNewFriends.
  ///
  /// In sv, this message translates to:
  /// **'Sök nya vänner'**
  String get socialSearchNewFriends;

  /// No description provided for @socialUnknownStatus.
  ///
  /// In sv, this message translates to:
  /// **'Okänd status'**
  String get socialUnknownStatus;

  /// No description provided for @socialWantsToBeFriend.
  ///
  /// In sv, this message translates to:
  /// **'vill bli din vän'**
  String get socialWantsToBeFriend;

  /// No description provided for @socialAcceptAllSelectedMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du acceptera {count} valda förfrågningar?'**
  String socialAcceptAllSelectedMessage(int count);

  /// No description provided for @socialAcceptCount.
  ///
  /// In sv, this message translates to:
  /// **'Acceptera ({count})'**
  String socialAcceptCount(int count);

  /// No description provided for @socialAcceptingRequests.
  ///
  /// In sv, this message translates to:
  /// **'Accepterar {count} förfrågningar...'**
  String socialAcceptingRequests(int count);

  /// No description provided for @socialBlockUserMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du blockera {name}? De kommer inte kunna se din profil eller skicka förfrågningar.'**
  String socialBlockUserMessage(String name);

  /// No description provided for @socialCancelCount.
  ///
  /// In sv, this message translates to:
  /// **'Avbryt ({count})'**
  String socialCancelCount(int count);

  /// No description provided for @socialCancelFriendRequestMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du avbryta vänskapsförfrågan till {name}?'**
  String socialCancelFriendRequestMessage(String name);

  /// No description provided for @socialCancellingRequests.
  ///
  /// In sv, this message translates to:
  /// **'Avbryter {count} förfrågningar...'**
  String socialCancellingRequests(int count);

  /// No description provided for @socialCancelSelectedRequestsMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du avbryta {count} valda förfrågningar?'**
  String socialCancelSelectedRequestsMessage(int count);

  /// No description provided for @socialDeclineCount.
  ///
  /// In sv, this message translates to:
  /// **'Avvisa ({count})'**
  String socialDeclineCount(int count);

  /// No description provided for @socialFriendRequestCancelled.
  ///
  /// In sv, this message translates to:
  /// **'Vänskapsförfrågan till {name} avbruten'**
  String socialFriendRequestCancelled(String name);

  /// No description provided for @socialFriendRequestRejected.
  ///
  /// In sv, this message translates to:
  /// **'Vänskapsförfrågan från {name} avvisad'**
  String socialFriendRequestRejected(String name);

  /// No description provided for @socialNotificationsCount.
  ///
  /// In sv, this message translates to:
  /// **'Aviseringar ({count})'**
  String socialNotificationsCount(int count);

  /// No description provided for @socialRejectAllSelectedMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du avvisa {count} valda förfrågningar?'**
  String socialRejectAllSelectedMessage(int count);

  /// No description provided for @socialRejectFriendRequestMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du avvisa vänskapsförfrågan från {name}?'**
  String socialRejectFriendRequestMessage(String name);

  /// No description provided for @socialRejectingRequests.
  ///
  /// In sv, this message translates to:
  /// **'Avvisar {count} förfrågningar...'**
  String socialRejectingRequests(int count);

  /// No description provided for @socialRemoveFriendMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du ta bort {name} som vän?'**
  String socialRemoveFriendMessage(String name);

  /// No description provided for @socialRequestsAccepted.
  ///
  /// In sv, this message translates to:
  /// **'{count} förfrågningar accepterade'**
  String socialRequestsAccepted(int count);

  /// No description provided for @socialRequestsCancelled.
  ///
  /// In sv, this message translates to:
  /// **'{count} förfrågningar avbrutna'**
  String socialRequestsCancelled(int count);

  /// No description provided for @socialRequestsRejected.
  ///
  /// In sv, this message translates to:
  /// **'{count} förfrågningar avvisade'**
  String socialRequestsRejected(int count);

  /// No description provided for @socialRequestsSelected.
  ///
  /// In sv, this message translates to:
  /// **'{count} valda'**
  String socialRequestsSelected(int count);

  /// No description provided for @socialUserBlocked.
  ///
  /// In sv, this message translates to:
  /// **'{name} har blockerats'**
  String socialUserBlocked(String name);

  /// No description provided for @socialUserUnblocked.
  ///
  /// In sv, this message translates to:
  /// **'{name} har avblockerats'**
  String socialUserUnblocked(String name);

  /// No description provided for @authLogin.
  ///
  /// In sv, this message translates to:
  /// **'Logga in'**
  String get authLogin;

  /// No description provided for @authCreateAccount.
  ///
  /// In sv, this message translates to:
  /// **'Skapa konto'**
  String get authCreateAccount;

  /// No description provided for @authYourName.
  ///
  /// In sv, this message translates to:
  /// **'Ditt namn'**
  String get authYourName;

  /// No description provided for @authEnterYourName.
  ///
  /// In sv, this message translates to:
  /// **'Ange ditt namn'**
  String get authEnterYourName;

  /// No description provided for @authEmail.
  ///
  /// In sv, this message translates to:
  /// **'E-post'**
  String get authEmail;

  /// No description provided for @authEmailHint.
  ///
  /// In sv, this message translates to:
  /// **'din.email@exempel.se'**
  String get authEmailHint;

  /// No description provided for @authNoAccountSignUp.
  ///
  /// In sv, this message translates to:
  /// **'Har du inget konto? Skapa konto'**
  String get authNoAccountSignUp;

  /// No description provided for @authHasAccountLogin.
  ///
  /// In sv, this message translates to:
  /// **'Har du redan ett konto? Logga in'**
  String get authHasAccountLogin;

  /// No description provided for @authResetEmailSent.
  ///
  /// In sv, this message translates to:
  /// **'Email skickad! Kontrollera din inkorg.'**
  String get authResetEmailSent;

  /// No description provided for @authResetEmailFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skicka email'**
  String get authResetEmailFailed;

  /// No description provided for @avatarUnknownUser.
  ///
  /// In sv, this message translates to:
  /// **'Okand användare'**
  String get avatarUnknownUser;

  /// No description provided for @commonNow.
  ///
  /// In sv, this message translates to:
  /// **'nu'**
  String get commonNow;

  /// No description provided for @commonJustNow.
  ///
  /// In sv, this message translates to:
  /// **'just nu'**
  String get commonJustNow;

  /// No description provided for @imageNoImagesYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga bilder ännu'**
  String get imageNoImagesYet;

  /// No description provided for @imageWillAppearHere.
  ///
  /// In sv, this message translates to:
  /// **'Bilder visas här'**
  String get imageWillAppearHere;

  /// No description provided for @imageNoImagesToDisplay.
  ///
  /// In sv, this message translates to:
  /// **'Inga bilder att visa'**
  String get imageNoImagesToDisplay;

  /// No description provided for @imageRemoveImage.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort bild'**
  String get imageRemoveImage;

  /// No description provided for @imageSetAsPrimary.
  ///
  /// In sv, this message translates to:
  /// **'Ange som primär'**
  String get imageSetAsPrimary;

  /// No description provided for @imageSelectedImages.
  ///
  /// In sv, this message translates to:
  /// **'Valda bilder'**
  String get imageSelectedImages;

  /// No description provided for @imageSelectImages.
  ///
  /// In sv, this message translates to:
  /// **'Välj bilder'**
  String get imageSelectImages;

  /// No description provided for @imageSelectingImages.
  ///
  /// In sv, this message translates to:
  /// **'Väljer bilder...'**
  String get imageSelectingImages;

  /// No description provided for @imageTapToSelectOne.
  ///
  /// In sv, this message translates to:
  /// **'Tryck för att välja en bild'**
  String get imageTapToSelectOne;

  /// No description provided for @messagingCancelReply.
  ///
  /// In sv, this message translates to:
  /// **'Avbryt svar'**
  String get messagingCancelReply;

  /// No description provided for @messagingImagePreview.
  ///
  /// In sv, this message translates to:
  /// **'Bild'**
  String get messagingImagePreview;

  /// No description provided for @navigationRecipes.
  ///
  /// In sv, this message translates to:
  /// **'recept'**
  String get navigationRecipes;

  /// No description provided for @navigationMenu.
  ///
  /// In sv, this message translates to:
  /// **'meny'**
  String get navigationMenu;

  /// No description provided for @navigationShopping.
  ///
  /// In sv, this message translates to:
  /// **'inköp'**
  String get navigationShopping;

  /// No description provided for @navigationAddNew.
  ///
  /// In sv, this message translates to:
  /// **'lägg till'**
  String get navigationAddNew;

  /// No description provided for @recipeRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Recept'**
  String get recipeRecipe;

  /// No description provided for @recipeSharedFromApp.
  ///
  /// In sv, this message translates to:
  /// **'Delad från annan app'**
  String get recipeSharedFromApp;

  /// No description provided for @shoppingBought.
  ///
  /// In sv, this message translates to:
  /// **'köpta'**
  String get shoppingBought;

  /// No description provided for @shoppingCollaborative.
  ///
  /// In sv, this message translates to:
  /// **'Kollaborativ'**
  String get shoppingCollaborative;

  /// No description provided for @shoppingCopyLink.
  ///
  /// In sv, this message translates to:
  /// **'Kopiera länk'**
  String get shoppingCopyLink;

  /// No description provided for @shoppingCopyList.
  ///
  /// In sv, this message translates to:
  /// **'Kopiera lista'**
  String get shoppingCopyList;

  /// No description provided for @shoppingRemaining.
  ///
  /// In sv, this message translates to:
  /// **'kvar'**
  String get shoppingRemaining;

  /// No description provided for @shoppingShareForward.
  ///
  /// In sv, this message translates to:
  /// **'Dela vidare'**
  String get shoppingShareForward;

  /// No description provided for @shoppingShareShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Dela inköpslista'**
  String get shoppingShareShoppingList;

  /// No description provided for @shoppingShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslista'**
  String get shoppingShoppingList;

  /// No description provided for @shoppingTotal.
  ///
  /// In sv, this message translates to:
  /// **'totalt'**
  String get shoppingTotal;

  /// No description provided for @socialCreateProfile.
  ///
  /// In sv, this message translates to:
  /// **'Skapa Profil'**
  String get socialCreateProfile;

  /// No description provided for @socialProfileCreatedRestart.
  ///
  /// In sv, this message translates to:
  /// **'Profil skapad! Starta om appen.'**
  String get socialProfileCreatedRestart;

  /// No description provided for @socialReport.
  ///
  /// In sv, this message translates to:
  /// **'Rapportera'**
  String get socialReport;

  /// No description provided for @socialReportContent.
  ///
  /// In sv, this message translates to:
  /// **'Rapportera innehåll'**
  String get socialReportContent;

  /// No description provided for @socialReportCopyright.
  ///
  /// In sv, this message translates to:
  /// **'Upphovsrättsintrång'**
  String get socialReportCopyright;

  /// No description provided for @socialReportInappropriate.
  ///
  /// In sv, this message translates to:
  /// **'Olämpligt innehåll'**
  String get socialReportInappropriate;

  /// No description provided for @socialReportIncorrectInfo.
  ///
  /// In sv, this message translates to:
  /// **'Felaktig information'**
  String get socialReportIncorrectInfo;

  /// No description provided for @socialReportOther.
  ///
  /// In sv, this message translates to:
  /// **'Annat'**
  String get socialReportOther;

  /// No description provided for @socialReportSent.
  ///
  /// In sv, this message translates to:
  /// **'Rapport skickad. Tack för din feedback!'**
  String get socialReportSent;

  /// No description provided for @socialReportShoppingListReason.
  ///
  /// In sv, this message translates to:
  /// **'Varför vill du rapportera denna inköpslista?'**
  String get socialReportShoppingListReason;

  /// No description provided for @socialReportSpam.
  ///
  /// In sv, this message translates to:
  /// **'Spam eller reklam'**
  String get socialReportSpam;

  /// No description provided for @commonDaysAgo.
  ///
  /// In sv, this message translates to:
  /// **'{days} dagar sedan'**
  String commonDaysAgo(int days);

  /// No description provided for @commonHoursAgo.
  ///
  /// In sv, this message translates to:
  /// **'{hours} timmar sedan'**
  String commonHoursAgo(int hours);

  /// No description provided for @commonMinutesAgo.
  ///
  /// In sv, this message translates to:
  /// **'{minutes} minuter sedan'**
  String commonMinutesAgo(int minutes);

  /// No description provided for @imageCountSelected.
  ///
  /// In sv, this message translates to:
  /// **'{count} valda'**
  String imageCountSelected(int count);

  /// No description provided for @imageFailedToSelect.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte välja bilder: {error}'**
  String imageFailedToSelect(String error);

  /// No description provided for @imageSelectedCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} av {max} bilder valda'**
  String imageSelectedCount(int count, int max);

  /// No description provided for @imageTapToSelectUpTo.
  ///
  /// In sv, this message translates to:
  /// **'Tryck för att välja upp till {count} bilder'**
  String imageTapToSelectUpTo(int count);

  /// No description provided for @messagingRecipePreview.
  ///
  /// In sv, this message translates to:
  /// **'{title}'**
  String messagingRecipePreview(String title);

  /// No description provided for @messagingReplyingTo.
  ///
  /// In sv, this message translates to:
  /// **'Svarar till {name}'**
  String messagingReplyingTo(String name);

  /// No description provided for @sharedMenusCount.
  ///
  /// In sv, this message translates to:
  /// **'Menyer ({count})'**
  String sharedMenusCount(int count);

  /// No description provided for @sharedRecipesCount.
  ///
  /// In sv, this message translates to:
  /// **'Recept ({count})'**
  String sharedRecipesCount(int count);

  /// No description provided for @sharedShoppingListsCount.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslistor ({count})'**
  String sharedShoppingListsCount(int count);

  /// No description provided for @shoppingCouldNotOpenShareMenu.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte öppna delningsmenyn: {error}'**
  String shoppingCouldNotOpenShareMenu(String error);

  /// No description provided for @shoppingCouldNotShareList.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dela listan: {error}'**
  String shoppingCouldNotShareList(String error);

  /// No description provided for @shoppingSharedBy.
  ///
  /// In sv, this message translates to:
  /// **'Delad av {name}'**
  String shoppingSharedBy(String name);

  /// No description provided for @shoppingShareListWith.
  ///
  /// In sv, this message translates to:
  /// **'Dela \"{name}\" med:'**
  String shoppingShareListWith(String name);

  /// No description provided for @shoppingSharingComingSoon.
  ///
  /// In sv, this message translates to:
  /// **'Delning via {option} kommer snart!'**
  String shoppingSharingComingSoon(String option);

  /// No description provided for @socialCouldNotSendReport.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skicka rapport: {error}'**
  String socialCouldNotSendReport(String error);

  /// No description provided for @socialLikeCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} gilla-markeringar'**
  String socialLikeCount(int count);

  /// No description provided for @socialLikesHeader.
  ///
  /// In sv, this message translates to:
  /// **'Gilla-markeringar ({count})'**
  String socialLikesHeader(int count);

  /// No description provided for @commonAdding.
  ///
  /// In sv, this message translates to:
  /// **'Lägger till...'**
  String get commonAdding;

  /// No description provided for @a11yHidePassword.
  ///
  /// In sv, this message translates to:
  /// **'Dölj lösenord'**
  String get a11yHidePassword;

  /// No description provided for @a11yShowPassword.
  ///
  /// In sv, this message translates to:
  /// **'Visa lösenord'**
  String get a11yShowPassword;

  /// No description provided for @a11yShareWithFriends.
  ///
  /// In sv, this message translates to:
  /// **'Dela med vänner'**
  String get a11yShareWithFriends;

  /// No description provided for @a11yNoItemsToShare.
  ///
  /// In sv, this message translates to:
  /// **'Inga artiklar att dela'**
  String get a11yNoItemsToShare;

  /// No description provided for @a11yShareExternally.
  ///
  /// In sv, this message translates to:
  /// **'Dela externt'**
  String get a11yShareExternally;

  /// No description provided for @a11yAddItem.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till vara'**
  String get a11yAddItem;

  /// No description provided for @a11yShoppingItemChecked.
  ///
  /// In sv, this message translates to:
  /// **'{itemText}, avbockad, tryck för att bocka av'**
  String a11yShoppingItemChecked(String itemText);

  /// No description provided for @a11yShoppingItemUnchecked.
  ///
  /// In sv, this message translates to:
  /// **'{itemText}, tryck för att bocka av'**
  String a11yShoppingItemUnchecked(String itemText);

  /// No description provided for @a11yTagSelected.
  ///
  /// In sv, this message translates to:
  /// **'{tagName}, vald. Dubbeltryck för att ta bort.'**
  String a11yTagSelected(String tagName);

  /// No description provided for @a11yTagUnselected.
  ///
  /// In sv, this message translates to:
  /// **'{tagName}. Dubbeltryck för att välja.'**
  String a11yTagUnselected(String tagName);

  /// No description provided for @a11ySharedShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Delad inköpslista: {listName}'**
  String a11ySharedShoppingList(String listName);

  /// No description provided for @a11yDismissSharedRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Avvisa delat recept'**
  String get a11yDismissSharedRecipe;

  /// No description provided for @a11yDismissSharedMenu.
  ///
  /// In sv, this message translates to:
  /// **'Avvisa delad meny'**
  String get a11yDismissSharedMenu;

  /// No description provided for @a11yDeclineSharedShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Avvisa delad inköpslista'**
  String get a11yDeclineSharedShoppingList;

  /// No description provided for @a11yPrimaryImageTap.
  ///
  /// In sv, this message translates to:
  /// **'Primär bild, tryck för att visa fullstorlek'**
  String get a11yPrimaryImageTap;

  /// No description provided for @a11ySelectAsPrimary.
  ///
  /// In sv, this message translates to:
  /// **'Välj som primär bild'**
  String get a11ySelectAsPrimary;

  /// No description provided for @a11yAddImage.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till bild'**
  String get a11yAddImage;

  /// No description provided for @a11yRemoveImage.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort bild'**
  String get a11yRemoveImage;

  /// No description provided for @a11yViewFullSizeImage.
  ///
  /// In sv, this message translates to:
  /// **'Visa fullstorlek av bild'**
  String get a11yViewFullSizeImage;

  /// No description provided for @a11yViewFullSizeImageOf.
  ///
  /// In sv, this message translates to:
  /// **'Visa fullstorlek av bild {current} av {total}'**
  String a11yViewFullSizeImageOf(int current, int total);

  /// No description provided for @a11ySwitchToImageOf.
  ///
  /// In sv, this message translates to:
  /// **'Byt till bild {current} av {total}'**
  String a11ySwitchToImageOf(int current, int total);

  /// No description provided for @a11yShrinkImage.
  ///
  /// In sv, this message translates to:
  /// **'Förminska bild'**
  String get a11yShrinkImage;

  /// No description provided for @a11yEnlargeImage.
  ///
  /// In sv, this message translates to:
  /// **'Förstora bild'**
  String get a11yEnlargeImage;

  /// No description provided for @a11yLoadImage.
  ///
  /// In sv, this message translates to:
  /// **'Ladda bild'**
  String get a11yLoadImage;

  /// No description provided for @a11yMessageSwipeToReply.
  ///
  /// In sv, this message translates to:
  /// **'Meddelande, svep för att svara'**
  String get a11yMessageSwipeToReply;

  /// No description provided for @a11yMessageLongPressOptions.
  ///
  /// In sv, this message translates to:
  /// **'Meddelandeinnehåll, långtryck för alternativ'**
  String get a11yMessageLongPressOptions;

  /// No description provided for @a11yImageMessageTap.
  ///
  /// In sv, this message translates to:
  /// **'Bildmeddelande, tryck för fullstorlek'**
  String get a11yImageMessageTap;

  /// No description provided for @a11yReplyToComment.
  ///
  /// In sv, this message translates to:
  /// **'Svara på kommentar'**
  String get a11yReplyToComment;

  /// No description provided for @a11yUnlikeComment.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort gilla-markering'**
  String get a11yUnlikeComment;

  /// No description provided for @a11yLikeComment.
  ///
  /// In sv, this message translates to:
  /// **'Gilla kommentar'**
  String get a11yLikeComment;

  /// No description provided for @a11yProfileImage.
  ///
  /// In sv, this message translates to:
  /// **'Profilbild för {displayName}'**
  String a11yProfileImage(String displayName);

  /// No description provided for @a11yChangeProfileImage.
  ///
  /// In sv, this message translates to:
  /// **'Ändra profilbild'**
  String get a11yChangeProfileImage;

  /// No description provided for @a11yShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslista: {name}'**
  String a11yShoppingList(String name);

  /// No description provided for @a11yFriend.
  ///
  /// In sv, this message translates to:
  /// **'Vän: {name}'**
  String a11yFriend(String name);

  /// No description provided for @a11yFriendRequest.
  ///
  /// In sv, this message translates to:
  /// **'Vänförfrågan'**
  String get a11yFriendRequest;

  /// No description provided for @a11yFilterTag.
  ///
  /// In sv, this message translates to:
  /// **'Filtrera på {tagName}, {status}'**
  String a11yFilterTag(String tagName, String status);

  /// No description provided for @a11yActive.
  ///
  /// In sv, this message translates to:
  /// **'aktiv'**
  String get a11yActive;

  /// No description provided for @a11yInactive.
  ///
  /// In sv, this message translates to:
  /// **'inaktiv'**
  String get a11yInactive;

  /// No description provided for @a11yExcludeTag.
  ///
  /// In sv, this message translates to:
  /// **'Exkludera {tagName}, {status}'**
  String a11yExcludeTag(String tagName, String status);

  /// No description provided for @a11yShowImage.
  ///
  /// In sv, this message translates to:
  /// **'Visa bild'**
  String get a11yShowImage;

  /// No description provided for @a11yShowMore.
  ///
  /// In sv, this message translates to:
  /// **'Visa {count} till'**
  String a11yShowMore(int count);

  /// No description provided for @a11yEditItem.
  ///
  /// In sv, this message translates to:
  /// **'Redigera {name}'**
  String a11yEditItem(String name);

  /// No description provided for @a11yDeleteItem.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort {name}'**
  String a11yDeleteItem(String name);

  /// No description provided for @a11ySharedRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Delat recept: {title}'**
  String a11ySharedRecipe(String title);

  /// No description provided for @a11ySharedMenu.
  ///
  /// In sv, this message translates to:
  /// **'Delad meny: {title}'**
  String a11ySharedMenu(String title);

  /// No description provided for @a11yRemoveProfileImage.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort profilbild'**
  String get a11yRemoveProfileImage;

  /// No description provided for @a11yMenu.
  ///
  /// In sv, this message translates to:
  /// **'Meny: {title}'**
  String a11yMenu(String title);

  /// No description provided for @filterBreakfast.
  ///
  /// In sv, this message translates to:
  /// **'Frukost'**
  String get filterBreakfast;

  /// No description provided for @filterLunch.
  ///
  /// In sv, this message translates to:
  /// **'Lunch'**
  String get filterLunch;

  /// No description provided for @filterDinner.
  ///
  /// In sv, this message translates to:
  /// **'Middag'**
  String get filterDinner;

  /// No description provided for @filterSnack.
  ///
  /// In sv, this message translates to:
  /// **'Mellanmål'**
  String get filterSnack;

  /// No description provided for @filterDessert.
  ///
  /// In sv, this message translates to:
  /// **'Efterrätt'**
  String get filterDessert;

  /// No description provided for @filterGlutenFree.
  ///
  /// In sv, this message translates to:
  /// **'Glutenfri'**
  String get filterGlutenFree;

  /// No description provided for @filterDairyFree.
  ///
  /// In sv, this message translates to:
  /// **'Mjölkfri'**
  String get filterDairyFree;

  /// No description provided for @filterLactoseFree.
  ///
  /// In sv, this message translates to:
  /// **'Laktosfri'**
  String get filterLactoseFree;

  /// No description provided for @filterNutFree.
  ///
  /// In sv, this message translates to:
  /// **'Nötfri'**
  String get filterNutFree;

  /// No description provided for @filterEggFree.
  ///
  /// In sv, this message translates to:
  /// **'Äggfri'**
  String get filterEggFree;

  /// No description provided for @filterSoyFree.
  ///
  /// In sv, this message translates to:
  /// **'Sojafri'**
  String get filterSoyFree;

  /// No description provided for @filterVegetarian.
  ///
  /// In sv, this message translates to:
  /// **'Vegetarisk'**
  String get filterVegetarian;

  /// No description provided for @filterVegan.
  ///
  /// In sv, this message translates to:
  /// **'Vegansk'**
  String get filterVegan;

  /// No description provided for @filterPescetarian.
  ///
  /// In sv, this message translates to:
  /// **'Pescetarian'**
  String get filterPescetarian;

  /// No description provided for @filterHalal.
  ///
  /// In sv, this message translates to:
  /// **'Halalanpassad'**
  String get filterHalal;

  /// No description provided for @filterKidFriendly.
  ///
  /// In sv, this message translates to:
  /// **'Barnvänlig'**
  String get filterKidFriendly;

  /// No description provided for @unitPieces.
  ///
  /// In sv, this message translates to:
  /// **'st'**
  String get unitPieces;

  /// No description provided for @unitLiter.
  ///
  /// In sv, this message translates to:
  /// **'liter'**
  String get unitLiter;

  /// No description provided for @unitTablespoon.
  ///
  /// In sv, this message translates to:
  /// **'msk'**
  String get unitTablespoon;

  /// No description provided for @unitPinch.
  ///
  /// In sv, this message translates to:
  /// **'krm'**
  String get unitPinch;

  /// No description provided for @unitPackage.
  ///
  /// In sv, this message translates to:
  /// **'förpackning'**
  String get unitPackage;

  /// No description provided for @unitPackageShort.
  ///
  /// In sv, this message translates to:
  /// **'förp'**
  String get unitPackageShort;

  /// No description provided for @unitTeaspoon.
  ///
  /// In sv, this message translates to:
  /// **'tsk'**
  String get unitTeaspoon;

  /// No description provided for @unitBag.
  ///
  /// In sv, this message translates to:
  /// **'påse'**
  String get unitBag;

  /// No description provided for @unitCan.
  ///
  /// In sv, this message translates to:
  /// **'burk'**
  String get unitCan;

  /// No description provided for @unitBottle.
  ///
  /// In sv, this message translates to:
  /// **'flaska'**
  String get unitBottle;

  /// No description provided for @unitPiece.
  ///
  /// In sv, this message translates to:
  /// **'bit'**
  String get unitPiece;

  /// No description provided for @unitClove.
  ///
  /// In sv, this message translates to:
  /// **'klyfta'**
  String get unitClove;

  /// No description provided for @categoryFruitVeg.
  ///
  /// In sv, this message translates to:
  /// **'Frukt & Grönt'**
  String get categoryFruitVeg;

  /// No description provided for @categoryDairy.
  ///
  /// In sv, this message translates to:
  /// **'Mejeri'**
  String get categoryDairy;

  /// No description provided for @categoryMeatFish.
  ///
  /// In sv, this message translates to:
  /// **'Kött & Fisk'**
  String get categoryMeatFish;

  /// No description provided for @categoryBread.
  ///
  /// In sv, this message translates to:
  /// **'Bröd'**
  String get categoryBread;

  /// No description provided for @categoryPantry.
  ///
  /// In sv, this message translates to:
  /// **'Skafferi'**
  String get categoryPantry;

  /// No description provided for @categoryFrozen.
  ///
  /// In sv, this message translates to:
  /// **'Fryst'**
  String get categoryFrozen;

  /// No description provided for @categoryBeverage.
  ///
  /// In sv, this message translates to:
  /// **'Dryck'**
  String get categoryBeverage;

  /// No description provided for @categorySnacks.
  ///
  /// In sv, this message translates to:
  /// **'Snacks & Godis'**
  String get categorySnacks;

  /// No description provided for @categoryHygiene.
  ///
  /// In sv, this message translates to:
  /// **'Städ & Hygien'**
  String get categoryHygiene;

  /// No description provided for @categoryOther.
  ///
  /// In sv, this message translates to:
  /// **'Övrigt'**
  String get categoryOther;

  /// No description provided for @privacyEmailSubject.
  ///
  /// In sv, this message translates to:
  /// **'Integritetsfråga'**
  String get privacyEmailSubject;

  /// No description provided for @unshareRecipeTitle.
  ///
  /// In sv, this message translates to:
  /// **'Sluta dela recept?'**
  String get unshareRecipeTitle;

  /// No description provided for @unshareRecipeConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Receptet \"{title}\" tas bort från alla grupper det delats med.'**
  String unshareRecipeConfirm(String title);

  /// No description provided for @unshareMenuTitle.
  ///
  /// In sv, this message translates to:
  /// **'Sluta dela meny?'**
  String get unshareMenuTitle;

  /// No description provided for @unshareMenuConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Menyn \"{title}\" tas bort från alla grupper den delats med.'**
  String unshareMenuConfirm(String title);

  /// No description provided for @unshareShoppingListTitle.
  ///
  /// In sv, this message translates to:
  /// **'Sluta dela inköpslista?'**
  String get unshareShoppingListTitle;

  /// No description provided for @unshareShoppingListConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslistan \"{name}\" tas bort från alla grupper den delats med.'**
  String unshareShoppingListConfirm(String name);

  /// No description provided for @unshareButton.
  ///
  /// In sv, this message translates to:
  /// **'Sluta dela'**
  String get unshareButton;

  /// No description provided for @unshareSuccess.
  ///
  /// In sv, this message translates to:
  /// **'\"{title}\" delas inte längre'**
  String unshareSuccess(String title);

  /// No description provided for @unshareFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte sluta dela. Försök igen.'**
  String get unshareFailed;

  /// No description provided for @menuCommentsTitle.
  ///
  /// In sv, this message translates to:
  /// **'Kommentarer'**
  String get menuCommentsTitle;

  /// No description provided for @menuCommentsCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} kommentarer'**
  String menuCommentsCount(int count);

  /// No description provided for @menuNoCommentsYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga kommentarer än'**
  String get menuNoCommentsYet;

  /// No description provided for @menuBeFirstToComment.
  ///
  /// In sv, this message translates to:
  /// **'Var först med att kommentera denna meny!'**
  String get menuBeFirstToComment;

  /// No description provided for @menuLoadingComments.
  ///
  /// In sv, this message translates to:
  /// **'Laddar kommentarer...'**
  String get menuLoadingComments;

  /// No description provided for @menuWriteComment.
  ///
  /// In sv, this message translates to:
  /// **'Skriv en kommentar om menyn...'**
  String get menuWriteComment;

  /// No description provided for @menuCommentPostedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Kommentar postad!'**
  String get menuCommentPostedSuccess;

  /// No description provided for @menuCommentPostFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte posta kommentaren'**
  String get menuCommentPostFailed;

  /// No description provided for @menuCommentDeleteFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort kommentaren'**
  String get menuCommentDeleteFailed;

  /// No description provided for @menuMustBeLoggedInToComment.
  ///
  /// In sv, this message translates to:
  /// **'Du måste vara inloggad för att kommentera'**
  String get menuMustBeLoggedInToComment;

  /// No description provided for @menuRatingTitle.
  ///
  /// In sv, this message translates to:
  /// **'Betyg'**
  String get menuRatingTitle;

  /// No description provided for @menuAverageRating.
  ///
  /// In sv, this message translates to:
  /// **'Medelbetyg: {rating}'**
  String menuAverageRating(String rating);

  /// No description provided for @menuRatingCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} betyg'**
  String menuRatingCount(int count);

  /// No description provided for @menuNoRatingsYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga betyg än'**
  String get menuNoRatingsYet;

  /// No description provided for @menuTapToRate.
  ///
  /// In sv, this message translates to:
  /// **'Tryck för att betygsätta'**
  String get menuTapToRate;

  /// No description provided for @menuYourRating.
  ///
  /// In sv, this message translates to:
  /// **'Ditt betyg'**
  String get menuYourRating;

  /// No description provided for @menuRatingSaved.
  ///
  /// In sv, this message translates to:
  /// **'Betyg sparat!'**
  String get menuRatingSaved;

  /// No description provided for @menuRatingFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara betyg'**
  String get menuRatingFailed;

  /// No description provided for @menuRemoveRating.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort betyg'**
  String get menuRemoveRating;

  /// No description provided for @menuMustBeLoggedInToRate.
  ///
  /// In sv, this message translates to:
  /// **'Du måste vara inloggad för att betygsätta'**
  String get menuMustBeLoggedInToRate;

  /// No description provided for @favoritesAdd.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till favorit'**
  String get favoritesAdd;

  /// No description provided for @favoritesRemove.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort favorit'**
  String get favoritesRemove;

  /// No description provided for @shoppingConvertToCollaborative.
  ///
  /// In sv, this message translates to:
  /// **'Gör samarbetslista'**
  String get shoppingConvertToCollaborative;

  /// No description provided for @shoppingConvertToPersonal.
  ///
  /// In sv, this message translates to:
  /// **'Gör personlig lista'**
  String get shoppingConvertToPersonal;

  /// No description provided for @shoppingConvertToCollaborativeTitle.
  ///
  /// In sv, this message translates to:
  /// **'Gör till samarbetslista'**
  String get shoppingConvertToCollaborativeTitle;

  /// No description provided for @shoppingConvertToCollaborativeDescription.
  ///
  /// In sv, this message translates to:
  /// **'Välj vänner att dela listan med. De kan lägga till och bocka av varor i realtid.'**
  String get shoppingConvertToCollaborativeDescription;

  /// No description provided for @shoppingConvertToPersonalTitle.
  ///
  /// In sv, this message translates to:
  /// **'Gör till personlig lista'**
  String get shoppingConvertToPersonalTitle;

  /// No description provided for @shoppingConvertToPersonalWarning.
  ///
  /// In sv, this message translates to:
  /// **'Alla samarbetspartners förlorar åtkomst till listan. Varor behålls.'**
  String get shoppingConvertToPersonalWarning;

  /// No description provided for @shoppingConvertedToCollaborative.
  ///
  /// In sv, this message translates to:
  /// **'Listan omvandlad till samarbetslista'**
  String get shoppingConvertedToCollaborative;

  /// No description provided for @shoppingConvertedToPersonal.
  ///
  /// In sv, this message translates to:
  /// **'Listan omvandlad till personlig'**
  String get shoppingConvertedToPersonal;

  /// No description provided for @shoppingConvertError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte omvandla listan'**
  String get shoppingConvertError;

  /// No description provided for @shoppingConvertSelectFriends.
  ///
  /// In sv, this message translates to:
  /// **'Välj minst en vän'**
  String get shoppingConvertSelectFriends;

  /// No description provided for @shoppingDescriptionLabel.
  ///
  /// In sv, this message translates to:
  /// **'Beskrivning (valfritt)'**
  String get shoppingDescriptionLabel;

  /// No description provided for @menuTemplateSaveAsTemplate.
  ///
  /// In sv, this message translates to:
  /// **'Spara som mall'**
  String get menuTemplateSaveAsTemplate;

  /// No description provided for @menuTemplateSaveAsTemplateDescription.
  ///
  /// In sv, this message translates to:
  /// **'Sparar menyns kategoristruktur som en återanvändbar mall'**
  String get menuTemplateSaveAsTemplateDescription;

  /// No description provided for @menuTemplateName.
  ///
  /// In sv, this message translates to:
  /// **'Mallnamn'**
  String get menuTemplateName;

  /// No description provided for @menuTemplateNameHint.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. Vardagsmeny familj'**
  String get menuTemplateNameHint;

  /// No description provided for @menuTemplateNameRequired.
  ///
  /// In sv, this message translates to:
  /// **'Mallnamn krävs'**
  String get menuTemplateNameRequired;

  /// No description provided for @menuTemplateDescription.
  ///
  /// In sv, this message translates to:
  /// **'Beskrivning (valfritt)'**
  String get menuTemplateDescription;

  /// No description provided for @menuTemplateDescriptionHint.
  ///
  /// In sv, this message translates to:
  /// **'T.ex. Perfekt för vardagar med barn'**
  String get menuTemplateDescriptionHint;

  /// No description provided for @menuTemplateSavedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Mall \"{name}\" sparad!'**
  String menuTemplateSavedSuccess(String name);

  /// No description provided for @menuTemplateSaveFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara mall'**
  String get menuTemplateSaveFailed;

  /// No description provided for @menuTemplateLoadTemplate.
  ///
  /// In sv, this message translates to:
  /// **'Ladda mall'**
  String get menuTemplateLoadTemplate;

  /// No description provided for @menuTemplateNoTemplates.
  ///
  /// In sv, this message translates to:
  /// **'Inga mallar'**
  String get menuTemplateNoTemplates;

  /// No description provided for @menuTemplateNoTemplatesDescription.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga sparade menymmallar. Spara en meny som mall för att återanvända kategoristrukturen.'**
  String get menuTemplateNoTemplatesDescription;

  /// No description provided for @menuTemplateBrowseTitle.
  ///
  /// In sv, this message translates to:
  /// **'Menymmallar'**
  String get menuTemplateBrowseTitle;

  /// No description provided for @menuTemplateCategories.
  ///
  /// In sv, this message translates to:
  /// **'{count} kategorier'**
  String menuTemplateCategories(int count);

  /// No description provided for @menuTemplateRecipes.
  ///
  /// In sv, this message translates to:
  /// **'{count} recept'**
  String menuTemplateRecipes(int count);

  /// No description provided for @menuTemplateUsedCount.
  ///
  /// In sv, this message translates to:
  /// **'Använd {count} gånger'**
  String menuTemplateUsedCount(int count);

  /// No description provided for @menuTemplateUseTemplate.
  ///
  /// In sv, this message translates to:
  /// **'Använd mall'**
  String get menuTemplateUseTemplate;

  /// No description provided for @menuTemplateDeleteTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort mall'**
  String get menuTemplateDeleteTitle;

  /// No description provided for @menuTemplateDeleteConfirmation.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill ta bort denna mall?'**
  String get menuTemplateDeleteConfirmation;

  /// No description provided for @menuTemplateDeletedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Mall borttagen'**
  String get menuTemplateDeletedSuccess;

  /// No description provided for @menuTemplateDeleteFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort mall'**
  String get menuTemplateDeleteFailed;

  /// No description provided for @menuTemplateSavedMenus.
  ///
  /// In sv, this message translates to:
  /// **'Sparade menyer'**
  String get menuTemplateSavedMenus;

  /// No description provided for @menuTemplateTemplates.
  ///
  /// In sv, this message translates to:
  /// **'Mallar'**
  String get menuTemplateTemplates;

  /// No description provided for @personalTagApplyRulesToAll.
  ///
  /// In sv, this message translates to:
  /// **'Tillämpa regler på alla recept'**
  String get personalTagApplyRulesToAll;

  /// No description provided for @messagingPinned.
  ///
  /// In sv, this message translates to:
  /// **'FÄSTA'**
  String get messagingPinned;

  /// No description provided for @messagingUnpin.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort fäst'**
  String get messagingUnpin;

  /// No description provided for @messagingPin.
  ///
  /// In sv, this message translates to:
  /// **'Fäst'**
  String get messagingPin;

  /// No description provided for @messagingArchive.
  ///
  /// In sv, this message translates to:
  /// **'Arkivera'**
  String get messagingArchive;

  /// No description provided for @messagingUnarchive.
  ///
  /// In sv, this message translates to:
  /// **'Avarkivera'**
  String get messagingUnarchive;

  /// No description provided for @messagingArchivedCount.
  ///
  /// In sv, this message translates to:
  /// **'Arkiverade ({count})'**
  String messagingArchivedCount(int count);

  /// No description provided for @allergenRetagAllRecipesTitle.
  ///
  /// In sv, this message translates to:
  /// **'Omtagga alla recept'**
  String get allergenRetagAllRecipesTitle;

  /// No description provided for @allergenAnalyzeAllRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Analysera alla recept med uppdaterade inställningar'**
  String get allergenAnalyzeAllRecipes;

  /// No description provided for @allergenUpdateAllRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Uppdatera alla recept'**
  String get allergenUpdateAllRecipes;

  /// No description provided for @notificationSaveError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara inställningar'**
  String get notificationSaveError;

  /// No description provided for @notificationTitle.
  ///
  /// In sv, this message translates to:
  /// **'Aviseringar'**
  String get notificationTitle;

  /// No description provided for @notificationEnableTitle.
  ///
  /// In sv, this message translates to:
  /// **'Aktivera aviseringar'**
  String get notificationEnableTitle;

  /// No description provided for @notificationEnableSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Aktivera eller inaktivera alla aviseringar'**
  String get notificationEnableSubtitle;

  /// No description provided for @notificationCategoriesTitle.
  ///
  /// In sv, this message translates to:
  /// **'Aviseringskategorier'**
  String get notificationCategoriesTitle;

  /// No description provided for @notificationQuietHoursTitle.
  ///
  /// In sv, this message translates to:
  /// **'Tysta timmar'**
  String get notificationQuietHoursTitle;

  /// No description provided for @notificationQuietHoursEnable.
  ///
  /// In sv, this message translates to:
  /// **'Aktivera tysta timmar'**
  String get notificationQuietHoursEnable;

  /// No description provided for @notificationQuietHoursSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Inga aviseringar under vald tidsperiod'**
  String get notificationQuietHoursSubtitle;

  /// No description provided for @commonFrom.
  ///
  /// In sv, this message translates to:
  /// **'Från'**
  String get commonFrom;

  /// No description provided for @commonTo.
  ///
  /// In sv, this message translates to:
  /// **'Till'**
  String get commonTo;

  /// No description provided for @notificationSound.
  ///
  /// In sv, this message translates to:
  /// **'Ljud'**
  String get notificationSound;

  /// No description provided for @notificationVibration.
  ///
  /// In sv, this message translates to:
  /// **'Vibration'**
  String get notificationVibration;

  /// No description provided for @notificationCategoryFriends.
  ///
  /// In sv, this message translates to:
  /// **'Vänner'**
  String get notificationCategoryFriends;

  /// No description provided for @notificationCategoryRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Recept'**
  String get notificationCategoryRecipes;

  /// No description provided for @notificationCategoryCollaboration.
  ///
  /// In sv, this message translates to:
  /// **'Samarbete'**
  String get notificationCategoryCollaboration;

  /// No description provided for @notificationCategoryShopping.
  ///
  /// In sv, this message translates to:
  /// **'Inköp'**
  String get notificationCategoryShopping;

  /// No description provided for @notificationCategorySocial.
  ///
  /// In sv, this message translates to:
  /// **'Social aktivitet'**
  String get notificationCategorySocial;

  /// No description provided for @notificationCategorySystem.
  ///
  /// In sv, this message translates to:
  /// **'System'**
  String get notificationCategorySystem;

  /// No description provided for @collaborationNoFriends.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga vänner att samarbeta med'**
  String get collaborationNoFriends;

  /// No description provided for @collaborationEnableTitle.
  ///
  /// In sv, this message translates to:
  /// **'Aktivera samarbete'**
  String get collaborationEnableTitle;

  /// No description provided for @collaborationEnabled.
  ///
  /// In sv, this message translates to:
  /// **'Samarbete aktiverat'**
  String get collaborationEnabled;

  /// No description provided for @collaborationCouldNotEnable.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte aktivera samarbete'**
  String get collaborationCouldNotEnable;

  /// No description provided for @collaborationDeactivateTitle.
  ///
  /// In sv, this message translates to:
  /// **'Avaktivera samarbete?'**
  String get collaborationDeactivateTitle;

  /// No description provided for @collaborationDeactivateMessage.
  ///
  /// In sv, this message translates to:
  /// **'Alla samarbetspartners förlorar åtkomst till receptet.'**
  String get collaborationDeactivateMessage;

  /// No description provided for @commonDeactivate.
  ///
  /// In sv, this message translates to:
  /// **'Avaktivera'**
  String get commonDeactivate;

  /// No description provided for @collaborationDeactivated.
  ///
  /// In sv, this message translates to:
  /// **'Samarbete avaktiverat'**
  String get collaborationDeactivated;

  /// No description provided for @collaborationCouldNotDeactivate.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte avaktivera samarbete'**
  String get collaborationCouldNotDeactivate;

  /// No description provided for @ratingRemoveTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort betyg?'**
  String get ratingRemoveTitle;

  /// No description provided for @ratingRemoveMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du ta bort ditt betyg för detta recept?'**
  String get ratingRemoveMessage;

  /// No description provided for @ratingRemoved.
  ///
  /// In sv, this message translates to:
  /// **'Betyg borttaget'**
  String get ratingRemoved;

  /// No description provided for @ratingRemoveError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort betyg'**
  String get ratingRemoveError;

  /// No description provided for @messagingSending.
  ///
  /// In sv, this message translates to:
  /// **'Skickar'**
  String get messagingSending;

  /// No description provided for @messagingSent.
  ///
  /// In sv, this message translates to:
  /// **'Skickat'**
  String get messagingSent;

  /// No description provided for @messagingDelivered.
  ///
  /// In sv, this message translates to:
  /// **'Levererat'**
  String get messagingDelivered;

  /// No description provided for @messagingRead.
  ///
  /// In sv, this message translates to:
  /// **'Läst'**
  String get messagingRead;

  /// No description provided for @messagingFailed.
  ///
  /// In sv, this message translates to:
  /// **'Misslyckades'**
  String get messagingFailed;

  /// No description provided for @a11ySelected.
  ///
  /// In sv, this message translates to:
  /// **'vald'**
  String get a11ySelected;

  /// No description provided for @a11yNotSelected.
  ///
  /// In sv, this message translates to:
  /// **'ej vald'**
  String get a11yNotSelected;

  /// No description provided for @blockedUsersUnblockTitle.
  ///
  /// In sv, this message translates to:
  /// **'Avblockera användare?'**
  String get blockedUsersUnblockTitle;

  /// No description provided for @blockedUsersUnblockMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du avblockera {name}? Användaren kommer kunna se ditt innehåll igen.'**
  String blockedUsersUnblockMessage(String name);

  /// No description provided for @blockedUsersUnblock.
  ///
  /// In sv, this message translates to:
  /// **'Avblockera'**
  String get blockedUsersUnblock;

  /// No description provided for @blockedUsersTitle.
  ///
  /// In sv, this message translates to:
  /// **'Blockerade användare'**
  String get blockedUsersTitle;

  /// No description provided for @blockedUsersEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Inga blockerade användare'**
  String get blockedUsersEmpty;

  /// No description provided for @retagFetchingRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Hämtar recept...'**
  String get retagFetchingRecipes;

  /// No description provided for @retagRetaggingRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Omtaggar recept'**
  String get retagRetaggingRecipes;

  /// No description provided for @retagRetaggingProgress.
  ///
  /// In sv, this message translates to:
  /// **'Omtaggar {current} av {total} recept...'**
  String retagRetaggingProgress(int current, int total);

  /// No description provided for @retagRecipesRetagged.
  ///
  /// In sv, this message translates to:
  /// **'{count} recept omtaggade'**
  String retagRecipesRetagged(int count);

  /// No description provided for @profileNotifications.
  ///
  /// In sv, this message translates to:
  /// **'Aviseringar'**
  String get profileNotifications;

  /// No description provided for @profileNotificationsSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Kategorier och tysta timmar'**
  String get profileNotificationsSubtitle;

  /// No description provided for @filterFavorites.
  ///
  /// In sv, this message translates to:
  /// **'Favoriter'**
  String get filterFavorites;

  /// No description provided for @filterUnder30Min.
  ///
  /// In sv, this message translates to:
  /// **'Under 30 min'**
  String get filterUnder30Min;

  /// No description provided for @filterVegetarianQuick.
  ///
  /// In sv, this message translates to:
  /// **'Vegetariskt'**
  String get filterVegetarianQuick;

  /// No description provided for @filterAll.
  ///
  /// In sv, this message translates to:
  /// **'Alla'**
  String get filterAll;

  /// No description provided for @instructionLabel.
  ///
  /// In sv, this message translates to:
  /// **'Instruktion {number}'**
  String instructionLabel(int number);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'sv'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'sv':
      return AppLocalizationsSv();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
