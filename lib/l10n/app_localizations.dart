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
  /// **'Från galleriet'**
  String get imageFromGallery;

  /// No description provided for @imageSelectFromGallery.
  ///
  /// In sv, this message translates to:
  /// **'Välj en bild från galleriet'**
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
  /// **'Konversationsinformation'**
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
  /// **'Är du säker på att du vill lämna konversationen?'**
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
  /// **'{recipes} recept i {categories} kategorier'**
  String menuRecipeCount(int recipes, int categories);

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
