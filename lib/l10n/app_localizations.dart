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

  /// No description provided for @validationInvalidUrl.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig URL'**
  String get validationInvalidUrl;

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

  /// No description provided for @errorCouldNotCreate.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa {itemType}'**
  String errorCouldNotCreate(String itemType);

  /// No description provided for @errorCouldNotUpdate.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera {itemType}'**
  String errorCouldNotUpdate(String itemType);

  /// No description provided for @errorCouldNotDelete.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort {itemType}'**
  String errorCouldNotDelete(String itemType);

  /// No description provided for @errorCouldNotLoad.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda {itemType}'**
  String errorCouldNotLoad(String itemType);

  /// No description provided for @nounSettings.
  ///
  /// In sv, this message translates to:
  /// **'inställningar'**
  String get nounSettings;

  /// No description provided for @nounGroupContent.
  ///
  /// In sv, this message translates to:
  /// **'gruppinnehåll'**
  String get nounGroupContent;

  /// No description provided for @nounFriends.
  ///
  /// In sv, this message translates to:
  /// **'vänner'**
  String get nounFriends;

  /// No description provided for @nounFriendList.
  ///
  /// In sv, this message translates to:
  /// **'vänlista'**
  String get nounFriendList;

  /// No description provided for @groupInvitationMessage.
  ///
  /// In sv, this message translates to:
  /// **'Du har blivit inbjuden till gruppen {groupName}!'**
  String groupInvitationMessage(String groupName);

  /// No description provided for @uploadTimeIn.
  ///
  /// In sv, this message translates to:
  /// **' på {duration}'**
  String uploadTimeIn(String duration);

  /// No description provided for @autoSaveEnabled.
  ///
  /// In sv, this message translates to:
  /// **'Autospar aktiverat'**
  String get autoSaveEnabled;

  /// No description provided for @selectionFriendSelectedWithName.
  ///
  /// In sv, this message translates to:
  /// **'{name} vald'**
  String selectionFriendSelectedWithName(String name);

  /// No description provided for @selectionFriendsSelectedWithNames.
  ///
  /// In sv, this message translates to:
  /// **'{count} valda: {names}'**
  String selectionFriendsSelectedWithNames(int count, String names);

  /// No description provided for @selectionFriendsSelectedCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} vänner valda'**
  String selectionFriendsSelectedCount(int count);

  /// No description provided for @sharePartialSuccessSingular.
  ///
  /// In sv, this message translates to:
  /// **'1 person är redan med. Bjuder in {newCount} nya.'**
  String sharePartialSuccessSingular(int newCount);

  /// No description provided for @sharePartialSuccessPlural.
  ///
  /// In sv, this message translates to:
  /// **'{existingCount} personer är redan med. Bjuder in {newCount} nya.'**
  String sharePartialSuccessPlural(int existingCount, int newCount);

  /// No description provided for @nounShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'inköpslista'**
  String get nounShoppingList;

  /// No description provided for @nounShareLink.
  ///
  /// In sv, this message translates to:
  /// **'delningslänk'**
  String get nounShareLink;

  /// No description provided for @validationUrlRequired.
  ///
  /// In sv, this message translates to:
  /// **'URL krävs'**
  String get validationUrlRequired;

  /// No description provided for @urlSuggestionKnownSite.
  ///
  /// In sv, this message translates to:
  /// **'Känd receptsida — bra chans att importera!'**
  String get urlSuggestionKnownSite;

  /// No description provided for @urlSuggestionUnknownSite.
  ///
  /// In sv, this message translates to:
  /// **'Okänd sida — import kan vara begränsad'**
  String get urlSuggestionUnknownSite;

  /// No description provided for @urlSuggestionContainsRecipeKeyword.
  ///
  /// In sv, this message translates to:
  /// **'URL:en innehåller receptnyckelord'**
  String get urlSuggestionContainsRecipeKeyword;

  /// No description provided for @urlSuggestionTooLong.
  ///
  /// In sv, this message translates to:
  /// **'URL:en är ovanligt lång — kontrollera att den är korrekt'**
  String get urlSuggestionTooLong;

  /// No description provided for @urlSuggestionSocialMedia.
  ///
  /// In sv, this message translates to:
  /// **'Sociala medier — import kräver ibland extra steg'**
  String get urlSuggestionSocialMedia;

  /// No description provided for @urlSuggestionOptimal.
  ///
  /// In sv, this message translates to:
  /// **'Perfekt — redo att importera!'**
  String get urlSuggestionOptimal;

  /// No description provided for @errorWithContext.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid {action}: {error}'**
  String errorWithContext(String action, String error);

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

  /// No description provided for @emptyNoItems.
  ///
  /// In sv, this message translates to:
  /// **'Inga objekt hittades.'**
  String get emptyNoItems;

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

  /// No description provided for @emptyNoSharedShoppingListsTitle.
  ///
  /// In sv, this message translates to:
  /// **'Inga delade inköpslistor'**
  String get emptyNoSharedShoppingListsTitle;

  /// No description provided for @emptyNoSharedShoppingListsSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'När du samarbetar på inköpslistor med vänner eller familj visas de här.'**
  String get emptyNoSharedShoppingListsSubtitle;

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

  /// No description provided for @socialGroupName.
  ///
  /// In sv, this message translates to:
  /// **'Gruppnamn'**
  String get socialGroupName;

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

  /// No description provided for @statusSaving.
  ///
  /// In sv, this message translates to:
  /// **'Sparar...'**
  String get statusSaving;

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

  /// No description provided for @accessibilityBackButton.
  ///
  /// In sv, this message translates to:
  /// **'Tillbaka'**
  String get accessibilityBackButton;

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

  /// No description provided for @portionDecrease.
  ///
  /// In sv, this message translates to:
  /// **'Minska portioner'**
  String get portionDecrease;

  /// No description provided for @portionIncrease.
  ///
  /// In sv, this message translates to:
  /// **'Öka portioner'**
  String get portionIncrease;

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
  /// **'🛒 INKÖPSLISTA'**
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

  /// No description provided for @shareRealtime.
  ///
  /// In sv, this message translates to:
  /// **'realtidsdelning'**
  String get shareRealtime;

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

  /// No description provided for @invitationIndividuals.
  ///
  /// In sv, this message translates to:
  /// **'Individer'**
  String get invitationIndividuals;

  /// No description provided for @invitationSendInvitations.
  ///
  /// In sv, this message translates to:
  /// **'Skicka inbjudningar'**
  String get invitationSendInvitations;

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

  /// No description provided for @groupCouldNotFetchRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte hämta recept från servern'**
  String get groupCouldNotFetchRecipe;

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
  /// **'Alla medlemmar kommer att lämna gruppen.'**
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

  /// No description provided for @groupErrorOpeningRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid öppning av recept: {error}'**
  String groupErrorOpeningRecipe(String error);

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

  /// No description provided for @groupRecipeImportedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Receptet \"{title}\" har importerats'**
  String groupRecipeImportedSuccess(String title);

  /// No description provided for @groupRecipeImportFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte importera recept: {error}'**
  String groupRecipeImportFailed(String error);

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

  /// No description provided for @importParseQualityWarning.
  ///
  /// In sv, this message translates to:
  /// **'Receptet tolkades med {quality}% konfidens. Granska fälten nedan.'**
  String importParseQualityWarning(int quality);

  /// No description provided for @importFieldsNeedReview.
  ///
  /// In sv, this message translates to:
  /// **'{count} fält kan behöva justeras'**
  String importFieldsNeedReview(int count);

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

  /// No description provided for @chatCannotMessageNonFriend.
  ///
  /// In sv, this message translates to:
  /// **'Du kan inte skicka meddelanden till denna person'**
  String get chatCannotMessageNonFriend;

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
  /// **'Dina recept. Resten löser sig.'**
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
  /// **'La till \"{itemName}\"'**
  String shoppingItemAdded(String itemName);

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
  /// **'namn@exempel.se'**
  String get authEmailHint;

  /// No description provided for @authTermsOfService.
  ///
  /// In sv, this message translates to:
  /// **'Villkor'**
  String get authTermsOfService;

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

  /// No description provided for @a11yAllergenStatusRow.
  ///
  /// In sv, this message translates to:
  /// **'Allergenstatus'**
  String get a11yAllergenStatusRow;

  /// No description provided for @a11yDietaryStatusRow.
  ///
  /// In sv, this message translates to:
  /// **'Koststatus'**
  String get a11yDietaryStatusRow;

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

  /// No description provided for @filterFishFree.
  ///
  /// In sv, this message translates to:
  /// **'Fiskfri'**
  String get filterFishFree;

  /// No description provided for @filterSesameFree.
  ///
  /// In sv, this message translates to:
  /// **'Sesamfri'**
  String get filterSesameFree;

  /// No description provided for @filterCeleryFree.
  ///
  /// In sv, this message translates to:
  /// **'Sellerifri'**
  String get filterCeleryFree;

  /// No description provided for @filterMustardFree.
  ///
  /// In sv, this message translates to:
  /// **'Senapfri'**
  String get filterMustardFree;

  /// No description provided for @filterShellfishFree.
  ///
  /// In sv, this message translates to:
  /// **'Skaldjursfri'**
  String get filterShellfishFree;

  /// No description provided for @filterLupinFree.
  ///
  /// In sv, this message translates to:
  /// **'Lupinfri'**
  String get filterLupinFree;

  /// No description provided for @filterSulfiteFree.
  ///
  /// In sv, this message translates to:
  /// **'Sulfitfri'**
  String get filterSulfiteFree;

  /// No description provided for @filterPeanutFree.
  ///
  /// In sv, this message translates to:
  /// **'Jordnötsfri'**
  String get filterPeanutFree;

  /// No description provided for @filterTreeNutFree.
  ///
  /// In sv, this message translates to:
  /// **'Trädnötsfri'**
  String get filterTreeNutFree;

  /// No description provided for @filterAlcoholFree.
  ///
  /// In sv, this message translates to:
  /// **'Alkoholfri'**
  String get filterAlcoholFree;

  /// No description provided for @filterMoreAllergens.
  ///
  /// In sv, this message translates to:
  /// **'Fler allergener'**
  String get filterMoreAllergens;

  /// No description provided for @filterFewerAllergens.
  ///
  /// In sv, this message translates to:
  /// **'Färre allergener'**
  String get filterFewerAllergens;

  /// No description provided for @onboardingAllergenCelery.
  ///
  /// In sv, this message translates to:
  /// **'Selleri'**
  String get onboardingAllergenCelery;

  /// No description provided for @onboardingAllergenMustard.
  ///
  /// In sv, this message translates to:
  /// **'Senap'**
  String get onboardingAllergenMustard;

  /// No description provided for @onboardingAllergenLupin.
  ///
  /// In sv, this message translates to:
  /// **'Lupin'**
  String get onboardingAllergenLupin;

  /// No description provided for @onboardingAllergenSulfite.
  ///
  /// In sv, this message translates to:
  /// **'Sulfiter'**
  String get onboardingAllergenSulfite;

  /// No description provided for @onboardingAllergenLactose.
  ///
  /// In sv, this message translates to:
  /// **'Laktos'**
  String get onboardingAllergenLactose;

  /// No description provided for @onboardingAllergenPeanut.
  ///
  /// In sv, this message translates to:
  /// **'Jordnötter'**
  String get onboardingAllergenPeanut;

  /// No description provided for @onboardingAllergenTreeNut.
  ///
  /// In sv, this message translates to:
  /// **'Trädnötter'**
  String get onboardingAllergenTreeNut;

  /// No description provided for @onboardingAllergenCrustacean.
  ///
  /// In sv, this message translates to:
  /// **'Kräftdjur'**
  String get onboardingAllergenCrustacean;

  /// No description provided for @onboardingAllergenMollusc.
  ///
  /// In sv, this message translates to:
  /// **'Blötdjur'**
  String get onboardingAllergenMollusc;

  /// No description provided for @onboardingShowAllAllergens.
  ///
  /// In sv, this message translates to:
  /// **'Visa alla allergener'**
  String get onboardingShowAllAllergens;

  /// No description provided for @onboardingShowFewerAllergens.
  ///
  /// In sv, this message translates to:
  /// **'Visa färre'**
  String get onboardingShowFewerAllergens;

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

  /// No description provided for @categorySpices.
  ///
  /// In sv, this message translates to:
  /// **'Kryddor'**
  String get categorySpices;

  /// No description provided for @categoryCanned.
  ///
  /// In sv, this message translates to:
  /// **'Konserver'**
  String get categoryCanned;

  /// No description provided for @categoryDryGoods.
  ///
  /// In sv, this message translates to:
  /// **'Torrvaror'**
  String get categoryDryGoods;

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

  /// No description provided for @onboardingSkip.
  ///
  /// In sv, this message translates to:
  /// **'Hoppa over'**
  String get onboardingSkip;

  /// No description provided for @onboardingBack.
  ///
  /// In sv, this message translates to:
  /// **'Tillbaka'**
  String get onboardingBack;

  /// No description provided for @onboardingNext.
  ///
  /// In sv, this message translates to:
  /// **'Nasta'**
  String get onboardingNext;

  /// No description provided for @onboardingComplete.
  ///
  /// In sv, this message translates to:
  /// **'Slutfor'**
  String get onboardingComplete;

  /// No description provided for @onboardingWelcomeTitle.
  ///
  /// In sv, this message translates to:
  /// **'Valkommen till Butlery!'**
  String get onboardingWelcomeTitle;

  /// No description provided for @onboardingWelcomeDescription.
  ///
  /// In sv, this message translates to:
  /// **'Lat oss stalla in dina preferenser sa att du far den basta upplevelsen fran borjan.'**
  String get onboardingWelcomeDescription;

  /// No description provided for @onboardingWelcomeNote.
  ///
  /// In sv, this message translates to:
  /// **'Du kan alltid andra dessa i installningarna senare.'**
  String get onboardingWelcomeNote;

  /// No description provided for @onboardingAllergenTitle.
  ///
  /// In sv, this message translates to:
  /// **'Allergier & intoleranser'**
  String get onboardingAllergenTitle;

  /// No description provided for @onboardingAllergenDescription.
  ///
  /// In sv, this message translates to:
  /// **'Valj de allergener du vill spara och filtrera recept efter.'**
  String get onboardingAllergenDescription;

  /// No description provided for @onboardingAllergenGluten.
  ///
  /// In sv, this message translates to:
  /// **'Gluten'**
  String get onboardingAllergenGluten;

  /// No description provided for @onboardingAllergenMilk.
  ///
  /// In sv, this message translates to:
  /// **'Mjolk'**
  String get onboardingAllergenMilk;

  /// No description provided for @onboardingAllergenNuts.
  ///
  /// In sv, this message translates to:
  /// **'Notter'**
  String get onboardingAllergenNuts;

  /// No description provided for @onboardingAllergenEgg.
  ///
  /// In sv, this message translates to:
  /// **'Agg'**
  String get onboardingAllergenEgg;

  /// No description provided for @onboardingAllergenSoy.
  ///
  /// In sv, this message translates to:
  /// **'Soja'**
  String get onboardingAllergenSoy;

  /// No description provided for @onboardingAllergenFish.
  ///
  /// In sv, this message translates to:
  /// **'Fisk'**
  String get onboardingAllergenFish;

  /// No description provided for @onboardingAllergenShellfish.
  ///
  /// In sv, this message translates to:
  /// **'Skaldjur'**
  String get onboardingAllergenShellfish;

  /// No description provided for @onboardingAllergenSesame.
  ///
  /// In sv, this message translates to:
  /// **'Sesam'**
  String get onboardingAllergenSesame;

  /// No description provided for @onboardingDietaryTitle.
  ///
  /// In sv, this message translates to:
  /// **'Kostreferenser'**
  String get onboardingDietaryTitle;

  /// No description provided for @onboardingDietaryDescription.
  ///
  /// In sv, this message translates to:
  /// **'Har du nagra kostreferenser? Vi kan filtrera recept at dig.'**
  String get onboardingDietaryDescription;

  /// No description provided for @onboardingDietaryVegetarian.
  ///
  /// In sv, this message translates to:
  /// **'Vegetarian'**
  String get onboardingDietaryVegetarian;

  /// No description provided for @onboardingDietaryVegan.
  ///
  /// In sv, this message translates to:
  /// **'Vegan'**
  String get onboardingDietaryVegan;

  /// No description provided for @onboardingDietaryPescetarian.
  ///
  /// In sv, this message translates to:
  /// **'Pescetarian'**
  String get onboardingDietaryPescetarian;

  /// No description provided for @onboardingDietaryVegetarianDesc.
  ///
  /// In sv, this message translates to:
  /// **'Inga kott- eller fiskprodukter'**
  String get onboardingDietaryVegetarianDesc;

  /// No description provided for @onboardingDietaryVeganDesc.
  ///
  /// In sv, this message translates to:
  /// **'Inga animaliska produkter'**
  String get onboardingDietaryVeganDesc;

  /// No description provided for @onboardingDietaryPescetarianDesc.
  ///
  /// In sv, this message translates to:
  /// **'Fisk men inget kott'**
  String get onboardingDietaryPescetarianDesc;

  /// No description provided for @onboardingImportTitle.
  ///
  /// In sv, this message translates to:
  /// **'Importera ditt forsta recept'**
  String get onboardingImportTitle;

  /// No description provided for @onboardingImportDescription.
  ///
  /// In sv, this message translates to:
  /// **'Kom igang snabbt genom att importera ett recept fran webben eller ett foto.'**
  String get onboardingImportDescription;

  /// No description provided for @onboardingImportUrlTitle.
  ///
  /// In sv, this message translates to:
  /// **'Fran en webbadress'**
  String get onboardingImportUrlTitle;

  /// No description provided for @onboardingImportUrlDescription.
  ///
  /// In sv, this message translates to:
  /// **'Klistra in en lank till ett recept'**
  String get onboardingImportUrlDescription;

  /// No description provided for @onboardingImportPhotoTitle.
  ///
  /// In sv, this message translates to:
  /// **'Importera fran foto'**
  String get onboardingImportPhotoTitle;

  /// No description provided for @onboardingImportPhotoDescription.
  ///
  /// In sv, this message translates to:
  /// **'Ta ett foto eller valj fran galleriet'**
  String get onboardingImportPhotoDescription;

  /// No description provided for @onboardingImportSkipNote.
  ///
  /// In sv, this message translates to:
  /// **'Du kan hoppa over detta steg och importera senare.'**
  String get onboardingImportSkipNote;

  /// No description provided for @cookingModePortions.
  ///
  /// In sv, this message translates to:
  /// **'Portioner'**
  String get cookingModePortions;

  /// No description provided for @feedbackSendLabel.
  ///
  /// In sv, this message translates to:
  /// **'Skicka feedback'**
  String get feedbackSendLabel;

  /// No description provided for @feedbackCategoryLabel.
  ///
  /// In sv, this message translates to:
  /// **'Kategori'**
  String get feedbackCategoryLabel;

  /// No description provided for @feedbackCategoryBug.
  ///
  /// In sv, this message translates to:
  /// **'Bugg'**
  String get feedbackCategoryBug;

  /// No description provided for @feedbackCategoryFeatureRequest.
  ///
  /// In sv, this message translates to:
  /// **'Önskemål'**
  String get feedbackCategoryFeatureRequest;

  /// No description provided for @feedbackCategoryGeneral.
  ///
  /// In sv, this message translates to:
  /// **'Övrigt'**
  String get feedbackCategoryGeneral;

  /// No description provided for @feedbackDescriptionLabel.
  ///
  /// In sv, this message translates to:
  /// **'Beskrivning'**
  String get feedbackDescriptionLabel;

  /// No description provided for @feedbackDescriptionHint.
  ///
  /// In sv, this message translates to:
  /// **'Beskriv vad du upplevde...'**
  String get feedbackDescriptionHint;

  /// No description provided for @feedbackEmailLabel.
  ///
  /// In sv, this message translates to:
  /// **'E-post (valfritt)'**
  String get feedbackEmailLabel;

  /// No description provided for @feedbackScreenshotLabel.
  ///
  /// In sv, this message translates to:
  /// **'Skarmavbild'**
  String get feedbackScreenshotLabel;

  /// No description provided for @feedbackRemoveScreenshot.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort skarmavbild'**
  String get feedbackRemoveScreenshot;

  /// No description provided for @feedbackSendButton.
  ///
  /// In sv, this message translates to:
  /// **'Skicka'**
  String get feedbackSendButton;

  /// No description provided for @substitutionEmptyState.
  ///
  /// In sv, this message translates to:
  /// **'Inga ersattningar hittades'**
  String get substitutionEmptyState;

  /// No description provided for @pollCreateTitle.
  ///
  /// In sv, this message translates to:
  /// **'Skapa omröstning'**
  String get pollCreateTitle;

  /// No description provided for @pollQuestionLabel.
  ///
  /// In sv, this message translates to:
  /// **'Fråga'**
  String get pollQuestionLabel;

  /// No description provided for @pollQuestionHint.
  ///
  /// In sv, this message translates to:
  /// **'Vad vill du fråga?'**
  String get pollQuestionHint;

  /// No description provided for @pollOptionLabel.
  ///
  /// In sv, this message translates to:
  /// **'Alternativ {number}'**
  String pollOptionLabel(int number);

  /// No description provided for @pollAddOption.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till alternativ'**
  String get pollAddOption;

  /// No description provided for @pollAllowMultiple.
  ///
  /// In sv, this message translates to:
  /// **'Tillåt flera val'**
  String get pollAllowMultiple;

  /// No description provided for @pollCancel.
  ///
  /// In sv, this message translates to:
  /// **'Avbryt'**
  String get pollCancel;

  /// No description provided for @pollCreate.
  ///
  /// In sv, this message translates to:
  /// **'Skapa omröstning'**
  String get pollCreate;

  /// No description provided for @pollClose.
  ///
  /// In sv, this message translates to:
  /// **'Stäng omröstning'**
  String get pollClose;

  /// No description provided for @messageTypeText.
  ///
  /// In sv, this message translates to:
  /// **'Textmeddelande'**
  String get messageTypeText;

  /// No description provided for @messageTypeRecipeShare.
  ///
  /// In sv, this message translates to:
  /// **'Receptdelning'**
  String get messageTypeRecipeShare;

  /// No description provided for @messageTypeMenuShare.
  ///
  /// In sv, this message translates to:
  /// **'Menydelning'**
  String get messageTypeMenuShare;

  /// No description provided for @messageTypeShoppingListShare.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslistedelning'**
  String get messageTypeShoppingListShare;

  /// No description provided for @messageTypeSystem.
  ///
  /// In sv, this message translates to:
  /// **'Systemmeddelande'**
  String get messageTypeSystem;

  /// No description provided for @messageTypeImage.
  ///
  /// In sv, this message translates to:
  /// **'Bild'**
  String get messageTypeImage;

  /// No description provided for @messageTypeVoice.
  ///
  /// In sv, this message translates to:
  /// **'Röstmeddelande'**
  String get messageTypeVoice;

  /// No description provided for @messageTypePoll.
  ///
  /// In sv, this message translates to:
  /// **'Omröstning'**
  String get messageTypePoll;

  /// No description provided for @messageStatusSending.
  ///
  /// In sv, this message translates to:
  /// **'Skickar...'**
  String get messageStatusSending;

  /// No description provided for @messageStatusSent.
  ///
  /// In sv, this message translates to:
  /// **'Skickat'**
  String get messageStatusSent;

  /// No description provided for @messageStatusDelivered.
  ///
  /// In sv, this message translates to:
  /// **'Levererat'**
  String get messageStatusDelivered;

  /// No description provided for @messageStatusRead.
  ///
  /// In sv, this message translates to:
  /// **'Läst'**
  String get messageStatusRead;

  /// No description provided for @messageStatusFailed.
  ///
  /// In sv, this message translates to:
  /// **'Misslyckades'**
  String get messageStatusFailed;

  /// No description provided for @errorDnsResolution.
  ///
  /// In sv, this message translates to:
  /// **'Anslutningsproblem upptäckts. Försöker återansluta...'**
  String get errorDnsResolution;

  /// No description provided for @errorServiceUnavailable.
  ///
  /// In sv, this message translates to:
  /// **'Tjänsten är tillfälligt otillgänglig. Försök igen senare.'**
  String get errorServiceUnavailable;

  /// No description provided for @errorNoItemsFound.
  ///
  /// In sv, this message translates to:
  /// **'Inga objekt hittades.'**
  String get errorNoItemsFound;

  /// No description provided for @errorNoUserLoggedIn.
  ///
  /// In sv, this message translates to:
  /// **'Ingen användare är inloggad'**
  String get errorNoUserLoggedIn;

  /// No description provided for @errorReauthRequired.
  ///
  /// In sv, this message translates to:
  /// **'Du måste logga in igen för att ta bort ditt konto'**
  String get errorReauthRequired;

  /// No description provided for @errorCouldNotRemoveMfa.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort MFA'**
  String get errorCouldNotRemoveMfa;

  /// No description provided for @errorEmailAlreadyInUse.
  ///
  /// In sv, this message translates to:
  /// **'Email-adressen används redan av ett annat konto.'**
  String get errorEmailAlreadyInUse;

  /// No description provided for @errorInvalidEmailAddress.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig email-adress.'**
  String get errorInvalidEmailAddress;

  /// No description provided for @errorUserNotFoundByEmail.
  ///
  /// In sv, this message translates to:
  /// **'Ingen användare hittades med denna email.'**
  String get errorUserNotFoundByEmail;

  /// No description provided for @errorWrongPassword.
  ///
  /// In sv, this message translates to:
  /// **'Fel lösenord.'**
  String get errorWrongPassword;

  /// No description provided for @errorInvalidCredentials.
  ///
  /// In sv, this message translates to:
  /// **'Fel email eller lösenord. Kontrollera dina uppgifter.'**
  String get errorInvalidCredentials;

  /// No description provided for @errorAccountDisabled.
  ///
  /// In sv, this message translates to:
  /// **'Detta konto har inaktiverats.'**
  String get errorAccountDisabled;

  /// No description provided for @errorTooManyAttempts.
  ///
  /// In sv, this message translates to:
  /// **'För många försök. Vänta en stund och försök igen.'**
  String get errorTooManyAttempts;

  /// No description provided for @errorInvalidVerificationCode.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig verifieringskod. Försök igen.'**
  String get errorInvalidVerificationCode;

  /// No description provided for @errorSessionExpired.
  ///
  /// In sv, this message translates to:
  /// **'Sessionen har gått ut. Försök igen.'**
  String get errorSessionExpired;

  /// No description provided for @errorTooManySmsAttempts.
  ///
  /// In sv, this message translates to:
  /// **'För många SMS-försök. Försök igen senare.'**
  String get errorTooManySmsAttempts;

  /// No description provided for @errorPhoneNumberMissing.
  ///
  /// In sv, this message translates to:
  /// **'Telefonnummer saknas.'**
  String get errorPhoneNumberMissing;

  /// No description provided for @errorMustBeLoggedIn.
  ///
  /// In sv, this message translates to:
  /// **'Du måste vara inloggad'**
  String get errorMustBeLoggedIn;

  /// No description provided for @errorMustBeLoggedInToImport.
  ///
  /// In sv, this message translates to:
  /// **'Du måste vara inloggad för att importera recept'**
  String get errorMustBeLoggedInToImport;

  /// No description provided for @errorMustBeLoggedInToExport.
  ///
  /// In sv, this message translates to:
  /// **'Du måste vara inloggad för att exportera data'**
  String get errorMustBeLoggedInToExport;

  /// No description provided for @errorMustBeLoggedInToManageConsent.
  ///
  /// In sv, this message translates to:
  /// **'Du måste vara inloggad för att hantera samtycken'**
  String get errorMustBeLoggedInToManageConsent;

  /// No description provided for @errorRecipeNameEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Receptnamn kan inte vara tomt'**
  String get errorRecipeNameEmpty;

  /// No description provided for @errorCanOnlyUpdatePersonalRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Kan bara uppdatera personliga recept'**
  String get errorCanOnlyUpdatePersonalRecipes;

  /// No description provided for @errorRecipeNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Recept hittades inte'**
  String get errorRecipeNotFound;

  /// No description provided for @errorNoPermissionToEdit.
  ///
  /// In sv, this message translates to:
  /// **'Du har inte behörighet att redigera detta recept'**
  String get errorNoPermissionToEdit;

  /// No description provided for @errorNotInRealtimeMode.
  ///
  /// In sv, this message translates to:
  /// **'Inte i realtidsredigeringsläge'**
  String get errorNotInRealtimeMode;

  /// No description provided for @errorTitleCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Titel kan inte vara tom'**
  String get errorTitleCannotBeEmpty;

  /// No description provided for @errorPortionsMustBePositive.
  ///
  /// In sv, this message translates to:
  /// **'Portioner måste vara större än 0'**
  String get errorPortionsMustBePositive;

  /// No description provided for @errorTimeMustBePositive.
  ///
  /// In sv, this message translates to:
  /// **'Tid måste vara större än 0 minuter'**
  String get errorTimeMustBePositive;

  /// No description provided for @errorRecipeNeedsIngredient.
  ///
  /// In sv, this message translates to:
  /// **'Recept måste ha minst en ingrediens'**
  String get errorRecipeNeedsIngredient;

  /// No description provided for @errorRecipeNeedsInstruction.
  ///
  /// In sv, this message translates to:
  /// **'Recept måste ha minst en instruktion'**
  String get errorRecipeNeedsInstruction;

  /// No description provided for @errorNoPermissionToShare.
  ///
  /// In sv, this message translates to:
  /// **'Du har inte behörighet att dela detta recept'**
  String get errorNoPermissionToShare;

  /// No description provided for @errorCouldNotSaveRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara recept'**
  String get errorCouldNotSaveRecipe;

  /// No description provided for @errorNoGroupMembersFound.
  ///
  /// In sv, this message translates to:
  /// **'Inga gruppmedlemmar hittades'**
  String get errorNoGroupMembersFound;

  /// No description provided for @errorRecipeNotShared.
  ///
  /// In sv, this message translates to:
  /// **'Receptet är inte delat'**
  String get errorRecipeNotShared;

  /// No description provided for @errorOnlyOwnerCanUnshare.
  ///
  /// In sv, this message translates to:
  /// **'Endast ägaren kan sluta dela receptet'**
  String get errorOnlyOwnerCanUnshare;

  /// No description provided for @errorCouldNotUnshareRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte sluta dela recept'**
  String get errorCouldNotUnshareRecipe;

  /// No description provided for @errorCouldNotLoadTags.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda taggar'**
  String get errorCouldNotLoadTags;

  /// No description provided for @errorTagUpdateFailed.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid uppdatering av taggar'**
  String get errorTagUpdateFailed;

  /// No description provided for @errorCouldNotCreateTag.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa taggen'**
  String get errorCouldNotCreateTag;

  /// No description provided for @errorCouldNotUpdateTag.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera taggen'**
  String get errorCouldNotUpdateTag;

  /// No description provided for @errorTagNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Taggen hittades inte'**
  String get errorTagNotFound;

  /// No description provided for @errorCouldNotDeleteTag.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort taggen'**
  String get errorCouldNotDeleteTag;

  /// No description provided for @errorCouldNotCreateGroup.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa gruppen'**
  String get errorCouldNotCreateGroup;

  /// No description provided for @errorCouldNotUpdateGroup.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera gruppen'**
  String get errorCouldNotUpdateGroup;

  /// No description provided for @errorGroupNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Gruppen hittades inte'**
  String get errorGroupNotFound;

  /// No description provided for @errorCouldNotDeleteGroup.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort gruppen'**
  String get errorCouldNotDeleteGroup;

  /// No description provided for @errorCouldNotCreateRule.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa regeln'**
  String get errorCouldNotCreateRule;

  /// No description provided for @errorCouldNotUpdateRule.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera regeln'**
  String get errorCouldNotUpdateRule;

  /// No description provided for @errorCouldNotDeleteRule.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort regeln'**
  String get errorCouldNotDeleteRule;

  /// No description provided for @errorNoImageToProcess.
  ///
  /// In sv, this message translates to:
  /// **'Ingen bild att behandla'**
  String get errorNoImageToProcess;

  /// No description provided for @errorPleaseEnterText.
  ///
  /// In sv, this message translates to:
  /// **'Vänligen ange text att tolka'**
  String get errorPleaseEnterText;

  /// No description provided for @errorPleaseEnterTextToImport.
  ///
  /// In sv, this message translates to:
  /// **'Vänligen ange text att importera'**
  String get errorPleaseEnterTextToImport;

  /// No description provided for @errorTextTooShort.
  ///
  /// In sv, this message translates to:
  /// **'Texten är för kort för att innehålla ett recept'**
  String get errorTextTooShort;

  /// No description provided for @errorPleaseEnterValidUrl.
  ///
  /// In sv, this message translates to:
  /// **'Vänligen ange en giltig URL'**
  String get errorPleaseEnterValidUrl;

  /// No description provided for @errorNoRecipeToValidate.
  ///
  /// In sv, this message translates to:
  /// **'Inget recept att validera'**
  String get errorNoRecipeToValidate;

  /// No description provided for @errorRecipeTitleRequired.
  ///
  /// In sv, this message translates to:
  /// **'Recepttitel krävs'**
  String get errorRecipeTitleRequired;

  /// No description provided for @errorRecipeMustHaveIngredient.
  ///
  /// In sv, this message translates to:
  /// **'Receptet måste ha minst en ingrediens'**
  String get errorRecipeMustHaveIngredient;

  /// No description provided for @errorRecipeMustHaveInstruction.
  ///
  /// In sv, this message translates to:
  /// **'Receptet måste ha minst en instruktion'**
  String get errorRecipeMustHaveInstruction;

  /// No description provided for @errorImportConditionsNotMet.
  ///
  /// In sv, this message translates to:
  /// **'Importvillkor inte uppfyllda'**
  String get errorImportConditionsNotMet;

  /// No description provided for @errorImportFailed.
  ///
  /// In sv, this message translates to:
  /// **'Import misslyckades'**
  String get errorImportFailed;

  /// No description provided for @errorNoRecipesSelected.
  ///
  /// In sv, this message translates to:
  /// **'Inga recept valda'**
  String get errorNoRecipesSelected;

  /// No description provided for @errorEnterMenuDescription.
  ///
  /// In sv, this message translates to:
  /// **'Ange vad du vill ha för meny'**
  String get errorEnterMenuDescription;

  /// No description provided for @errorNoMoreRecipesForSwap.
  ///
  /// In sv, this message translates to:
  /// **'Inga fler recept tillgängliga för byte'**
  String get errorNoMoreRecipesForSwap;

  /// No description provided for @errorNoMenuToSave.
  ///
  /// In sv, this message translates to:
  /// **'Ingen meny att spara'**
  String get errorNoMenuToSave;

  /// No description provided for @errorEnterMenuName.
  ///
  /// In sv, this message translates to:
  /// **'Ange ett namn för menyn'**
  String get errorEnterMenuName;

  /// No description provided for @errorMenuNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Menyn kunde inte hittas'**
  String get errorMenuNotFound;

  /// No description provided for @errorNoMenuToSaveAsTemplate.
  ///
  /// In sv, this message translates to:
  /// **'Ingen meny att spara som mall'**
  String get errorNoMenuToSaveAsTemplate;

  /// No description provided for @errorCouldNotSaveTemplate.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara mall'**
  String get errorCouldNotSaveTemplate;

  /// No description provided for @errorNoMenuLoaded.
  ///
  /// In sv, this message translates to:
  /// **'Ingen meny laddad'**
  String get errorNoMenuLoaded;

  /// No description provided for @errorNoEditPermission.
  ///
  /// In sv, this message translates to:
  /// **'Ingen redigeringsbehörighet'**
  String get errorNoEditPermission;

  /// No description provided for @errorNoInternetConnection.
  ///
  /// In sv, this message translates to:
  /// **'Ingen internetanslutning'**
  String get errorNoInternetConnection;

  /// No description provided for @errorNoRecipesAvailable.
  ///
  /// In sv, this message translates to:
  /// **'Inga recept tillgängliga. Lägg till recept först.'**
  String get errorNoRecipesAvailable;

  /// No description provided for @errorNoMenuToShare.
  ///
  /// In sv, this message translates to:
  /// **'Ingen meny att dela'**
  String get errorNoMenuToShare;

  /// No description provided for @errorCouldNotAddItem.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lägga till artikel'**
  String get errorCouldNotAddItem;

  /// No description provided for @errorCouldNotUpdateItem.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera artikel'**
  String get errorCouldNotUpdateItem;

  /// No description provided for @errorListNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Lista hittades inte'**
  String get errorListNotFound;

  /// No description provided for @errorCouldNotLoadGroupInfo.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda gruppinformation'**
  String get errorCouldNotLoadGroupInfo;

  /// No description provided for @errorCouldNotAddMembers.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lägga till medlemmar'**
  String get errorCouldNotAddMembers;

  /// No description provided for @errorCouldNotLeaveGroup.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lämna grupp'**
  String get errorCouldNotLeaveGroup;

  /// No description provided for @errorCouldNotLoadConversation.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda konversation'**
  String get errorCouldNotLoadConversation;

  /// No description provided for @errorCouldNotLoadMessages.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda meddelanden'**
  String get errorCouldNotLoadMessages;

  /// No description provided for @errorCouldNotStartConversation.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte starta konversation'**
  String get errorCouldNotStartConversation;

  /// No description provided for @errorMessageCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Meddelandet kan inte vara tomt'**
  String get errorMessageCannotBeEmpty;

  /// No description provided for @errorNoFriendsOrGroupsSelected.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner eller grupper valda'**
  String get errorNoFriendsOrGroupsSelected;

  /// No description provided for @errorNoRecipientsFound.
  ///
  /// In sv, this message translates to:
  /// **'Inga mottagare hittades'**
  String get errorNoRecipientsFound;

  /// No description provided for @errorFormIncomplete.
  ///
  /// In sv, this message translates to:
  /// **'Formuläret är inte komplett'**
  String get errorFormIncomplete;

  /// No description provided for @errorMustCreateProfileFirst.
  ///
  /// In sv, this message translates to:
  /// **'Du måste skapa en profil först'**
  String get errorMustCreateProfileFirst;

  /// No description provided for @errorTitleRequiredNotEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Titel krävs och får inte vara tom'**
  String get errorTitleRequiredNotEmpty;

  /// No description provided for @errorDescriptionTooLong.
  ///
  /// In sv, this message translates to:
  /// **'Beskrivning för lång'**
  String get errorDescriptionTooLong;

  /// No description provided for @errorGroupNameRequired.
  ///
  /// In sv, this message translates to:
  /// **'Gruppnamn krävs'**
  String get errorGroupNameRequired;

  /// No description provided for @errorGroupNameExists.
  ///
  /// In sv, this message translates to:
  /// **'Det här gruppnamnet finns redan'**
  String get errorGroupNameExists;

  /// No description provided for @errorOnlyAdminCanAddMembers.
  ///
  /// In sv, this message translates to:
  /// **'Endast administratör kan lägga till medlemmar'**
  String get errorOnlyAdminCanAddMembers;

  /// No description provided for @errorOnlyAdminCanRemoveMembers.
  ///
  /// In sv, this message translates to:
  /// **'Endast administratör kan ta bort medlemmar'**
  String get errorOnlyAdminCanRemoveMembers;

  /// No description provided for @errorUseLeaveGroupToLeave.
  ///
  /// In sv, this message translates to:
  /// **'Använd \"Lämna grupp\" för att lämna konversationen'**
  String get errorUseLeaveGroupToLeave;

  /// No description provided for @errorOnlyAdminCanChangeGroupName.
  ///
  /// In sv, this message translates to:
  /// **'Endast administratör kan ändra gruppnamn'**
  String get errorOnlyAdminCanChangeGroupName;

  /// No description provided for @errorGroupNameCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Gruppnamn kan inte vara tomt'**
  String get errorGroupNameCannotBeEmpty;

  /// No description provided for @errorFillRequiredFields.
  ///
  /// In sv, this message translates to:
  /// **'Fyll i alla obligatoriska fält'**
  String get errorFillRequiredFields;

  /// No description provided for @errorNoPermissionToSave.
  ///
  /// In sv, this message translates to:
  /// **'Du har inte behörighet att spara detta recept'**
  String get errorNoPermissionToSave;

  /// No description provided for @errorNoRecipeToFork.
  ///
  /// In sv, this message translates to:
  /// **'Inget recept att forka'**
  String get errorNoRecipeToFork;

  /// No description provided for @errorCouldNotForkRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte forka recept'**
  String get errorCouldNotForkRecipe;

  /// No description provided for @errorNoRecipeToDelete.
  ///
  /// In sv, this message translates to:
  /// **'Inget recept att ta bort'**
  String get errorNoRecipeToDelete;

  /// No description provided for @errorNoPermissionToDelete.
  ///
  /// In sv, this message translates to:
  /// **'Du har inte behörighet att ta bort detta recept'**
  String get errorNoPermissionToDelete;

  /// No description provided for @errorPasswordCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Lösenord kan inte vara tomt'**
  String get errorPasswordCannotBeEmpty;

  /// No description provided for @errorPasswordMinSixChars.
  ///
  /// In sv, this message translates to:
  /// **'Lösenord måste vara minst 6 tecken'**
  String get errorPasswordMinSixChars;

  /// No description provided for @errorDisplayNameCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Visningsnamn kan inte vara tomt'**
  String get errorDisplayNameCannotBeEmpty;

  /// No description provided for @errorDisplayNameMinLength.
  ///
  /// In sv, this message translates to:
  /// **'Visningsnamn måste vara minst 2 tecken'**
  String get errorDisplayNameMinLength;

  /// No description provided for @errorSomeSharesFailed.
  ///
  /// In sv, this message translates to:
  /// **'Vissa delningar misslyckades'**
  String get errorSomeSharesFailed;

  /// No description provided for @errorNoFriendsToShareWith.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga vänner att dela med'**
  String get errorNoFriendsToShareWith;

  /// No description provided for @errorSelectAtLeastOneFriend.
  ///
  /// In sv, this message translates to:
  /// **'Välj minst en vän att dela med'**
  String get errorSelectAtLeastOneFriend;

  /// No description provided for @errorFillRequiredFieldsCorrectly.
  ///
  /// In sv, this message translates to:
  /// **'Fyll i alla obligatoriska fält korrekt'**
  String get errorFillRequiredFieldsCorrectly;

  /// No description provided for @errorNameAlreadyTaken.
  ///
  /// In sv, this message translates to:
  /// **'Detta namn är redan taget'**
  String get errorNameAlreadyTaken;

  /// No description provided for @errorNoPermissionToManageParticipants.
  ///
  /// In sv, this message translates to:
  /// **'Ingen behörighet att hantera deltagare'**
  String get errorNoPermissionToManageParticipants;

  /// No description provided for @errorCannotRemoveSelf.
  ///
  /// In sv, this message translates to:
  /// **'Kan inte ta bort sig själv som deltagare'**
  String get errorCannotRemoveSelf;

  /// No description provided for @errorCannotChangeOwnPermissions.
  ///
  /// In sv, this message translates to:
  /// **'Kan inte ändra sina egna behörigheter'**
  String get errorCannotChangeOwnPermissions;

  /// No description provided for @errorNoUserIdAvailable.
  ///
  /// In sv, this message translates to:
  /// **'Ingen användar-ID tillgänglig'**
  String get errorNoUserIdAvailable;

  /// No description provided for @errorInvitationNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Inbjudan hittades inte'**
  String get errorInvitationNotFound;

  /// No description provided for @errorNoInternetCheckConnection.
  ///
  /// In sv, this message translates to:
  /// **'Ingen internetanslutning. Kontrollera din anslutning och försök igen.'**
  String get errorNoInternetCheckConnection;

  /// No description provided for @errorPermissionDeniedRetry.
  ///
  /// In sv, this message translates to:
  /// **'Behörighet nekad. Försök logga in igen.'**
  String get errorPermissionDeniedRetry;

  /// No description provided for @errorExportFailed.
  ///
  /// In sv, this message translates to:
  /// **'Ett fel uppstod vid export av data. Försök igen.'**
  String get errorExportFailed;

  /// No description provided for @errorTagNameExists.
  ///
  /// In sv, this message translates to:
  /// **'En tagg med namnet \"{name}\" finns redan'**
  String errorTagNameExists(String name);

  /// No description provided for @errorGroupDoesNotExist.
  ///
  /// In sv, this message translates to:
  /// **'Gruppen finns inte'**
  String get errorGroupDoesNotExist;

  /// No description provided for @errorTagDoesNotExist.
  ///
  /// In sv, this message translates to:
  /// **'Taggen finns inte'**
  String get errorTagDoesNotExist;

  /// No description provided for @errorRuleDoesNotExist.
  ///
  /// In sv, this message translates to:
  /// **'Regeln finns inte'**
  String get errorRuleDoesNotExist;

  /// No description provided for @errorSharedTagNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Delad tagg hittades inte'**
  String get errorSharedTagNotFound;

  /// No description provided for @errorOwnerMustKeepPermission.
  ///
  /// In sv, this message translates to:
  /// **'Ägaren måste behålla owner-behörighet'**
  String get errorOwnerMustKeepPermission;

  /// No description provided for @errorCouldNotLoadRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda recept'**
  String get errorCouldNotLoadRecipes;

  /// No description provided for @errorCouldNotDeleteRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort recept'**
  String get errorCouldNotDeleteRecipe;

  /// No description provided for @errorCouldNotValidateImage.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte validera bild'**
  String get errorCouldNotValidateImage;

  /// No description provided for @actionRecipeSaving.
  ///
  /// In sv, this message translates to:
  /// **'sparar recept'**
  String get actionRecipeSaving;

  /// No description provided for @actionRecipeUploading.
  ///
  /// In sv, this message translates to:
  /// **'laddar upp recept'**
  String get actionRecipeUploading;

  /// No description provided for @actionRecipeLoading.
  ///
  /// In sv, this message translates to:
  /// **'laddar recept'**
  String get actionRecipeLoading;

  /// No description provided for @actionRecipeDeleting.
  ///
  /// In sv, this message translates to:
  /// **'tar bort recept'**
  String get actionRecipeDeleting;

  /// No description provided for @actionRecipeValidation.
  ///
  /// In sv, this message translates to:
  /// **'validerar recept'**
  String get actionRecipeValidation;

  /// No description provided for @actionRecipeCollaborativeSync.
  ///
  /// In sv, this message translates to:
  /// **'synkroniserar delat recept'**
  String get actionRecipeCollaborativeSync;

  /// No description provided for @actionRecipeDraftRestore.
  ///
  /// In sv, this message translates to:
  /// **'återställer utkast'**
  String get actionRecipeDraftRestore;

  /// No description provided for @actionRecipeImageUpload.
  ///
  /// In sv, this message translates to:
  /// **'laddar upp bilder'**
  String get actionRecipeImageUpload;

  /// No description provided for @actionRecipeImageProcessing.
  ///
  /// In sv, this message translates to:
  /// **'bearbetar bilder'**
  String get actionRecipeImageProcessing;

  /// No description provided for @actionRecipeImageDelete.
  ///
  /// In sv, this message translates to:
  /// **'tar bort bild'**
  String get actionRecipeImageDelete;

  /// No description provided for @actionShoppingListCreate.
  ///
  /// In sv, this message translates to:
  /// **'skapar inköpslista'**
  String get actionShoppingListCreate;

  /// No description provided for @actionShoppingItemAdd.
  ///
  /// In sv, this message translates to:
  /// **'lägger till vara'**
  String get actionShoppingItemAdd;

  /// No description provided for @actionShoppingListSync.
  ///
  /// In sv, this message translates to:
  /// **'synkroniserar inköpslista'**
  String get actionShoppingListSync;

  /// No description provided for @actionShoppingListShare.
  ///
  /// In sv, this message translates to:
  /// **'delar inköpslista'**
  String get actionShoppingListShare;

  /// No description provided for @actionShoppingListDelete.
  ///
  /// In sv, this message translates to:
  /// **'tar bort inköpslista'**
  String get actionShoppingListDelete;

  /// No description provided for @actionFriendInvite.
  ///
  /// In sv, this message translates to:
  /// **'skickar väninvitation'**
  String get actionFriendInvite;

  /// No description provided for @actionGroupCreate.
  ///
  /// In sv, this message translates to:
  /// **'skapar grupp'**
  String get actionGroupCreate;

  /// No description provided for @actionMessagesSend.
  ///
  /// In sv, this message translates to:
  /// **'skickar meddelande'**
  String get actionMessagesSend;

  /// No description provided for @actionSocialSync.
  ///
  /// In sv, this message translates to:
  /// **'synkroniserar socialt innehåll'**
  String get actionSocialSync;

  /// No description provided for @actionUserProfileUpdate.
  ///
  /// In sv, this message translates to:
  /// **'uppdaterar profil'**
  String get actionUserProfileUpdate;

  /// No description provided for @actionPermissionRequest.
  ///
  /// In sv, this message translates to:
  /// **'begär behörighet'**
  String get actionPermissionRequest;

  /// No description provided for @actionAppStartup.
  ///
  /// In sv, this message translates to:
  /// **'startar app'**
  String get actionAppStartup;

  /// No description provided for @actionDataSync.
  ///
  /// In sv, this message translates to:
  /// **'synkroniserar data'**
  String get actionDataSync;

  /// No description provided for @actionBackgroundUpload.
  ///
  /// In sv, this message translates to:
  /// **'bakgrundsuppladdning'**
  String get actionBackgroundUpload;

  /// No description provided for @actionOffline.
  ///
  /// In sv, this message translates to:
  /// **'offline-operation'**
  String get actionOffline;

  /// No description provided for @errorNetworkNoConnection.
  ///
  /// In sv, this message translates to:
  /// **'Ingen internetanslutning medan {action}. Ändringar sparas lokalt och synkroniseras automatiskt när du är online igen.'**
  String errorNetworkNoConnection(String action);

  /// No description provided for @errorNetworkLimited.
  ///
  /// In sv, this message translates to:
  /// **'Begränsad internetanslutning medan {action}. Vissa funktioner kan vara otillgängliga.'**
  String errorNetworkLimited(String action);

  /// No description provided for @errorNetworkDegraded.
  ///
  /// In sv, this message translates to:
  /// **'Anslutningsproblem medan {action}. DNS-problem upptäckta, kontrollerar anslutningen automatiskt.'**
  String errorNetworkDegraded(String action);

  /// No description provided for @errorNetworkTemporary.
  ///
  /// In sv, this message translates to:
  /// **'Tillfälligt nätverksfel medan {action}. Kontrollerar anslutningen och försöker igen automatiskt.'**
  String errorNetworkTemporary(String action);

  /// No description provided for @errorNetworkUnknownStatus.
  ///
  /// In sv, this message translates to:
  /// **'Okänd anslutningsstatus medan {action}. Kontrollera internetanslutningen och försök igen.'**
  String errorNetworkUnknownStatus(String action);

  /// No description provided for @errorAuthNoPermissionFor.
  ///
  /// In sv, this message translates to:
  /// **'Du saknar behörighet för {action}'**
  String errorAuthNoPermissionFor(String action);

  /// No description provided for @errorAuthNotLoggedInWhile.
  ///
  /// In sv, this message translates to:
  /// **'{base} eftersom du inte är inloggad.'**
  String errorAuthNotLoggedInWhile(String base);

  /// No description provided for @errorAuthViewerOnly.
  ///
  /// In sv, this message translates to:
  /// **'{base}. Du har endast läsrättigheter för detta innehåll.'**
  String errorAuthViewerOnly(String base);

  /// No description provided for @errorAuthEditorRequired.
  ///
  /// In sv, this message translates to:
  /// **'{base}. Redigeringsrättigheter krävs för denna åtgärd.'**
  String errorAuthEditorRequired(String base);

  /// No description provided for @errorAuthNotShared.
  ///
  /// In sv, this message translates to:
  /// **'{base}. Du har inte delats detta innehåll.'**
  String errorAuthNotShared(String base);

  /// No description provided for @errorAuthOwnerOnly.
  ///
  /// In sv, this message translates to:
  /// **'{base}. Endast ägaren ({owner}) kan utföra denna åtgärd.'**
  String errorAuthOwnerOnly(String base, String owner);

  /// No description provided for @errorAuthContactOwner.
  ///
  /// In sv, this message translates to:
  /// **'{base}. Kontakta innehållsägaren för utökade rättigheter.'**
  String errorAuthContactOwner(String base);

  /// No description provided for @errorNotFoundRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Receptet kunde inte hittas medan {action}. Det kan ha blivit raderat eller flyttat av ägaren.'**
  String errorNotFoundRecipe(String action);

  /// No description provided for @errorNotFoundShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslistan kunde inte hittas medan {action}. Den kan ha blivit raderad eller du har inte längre åtkomst.'**
  String errorNotFoundShoppingList(String action);

  /// No description provided for @errorNotFoundImage.
  ///
  /// In sv, this message translates to:
  /// **'Bilden kunde inte hittas medan {action}. Den kan ha blivit raderad eller flyttad.'**
  String errorNotFoundImage(String action);

  /// No description provided for @errorNotFoundGeneric.
  ///
  /// In sv, this message translates to:
  /// **'Det begärda innehållet kunde inte hittas medan {action}. Det kan ha blivit raderat eller du har inte längre åtkomst.'**
  String errorNotFoundGeneric(String action);

  /// No description provided for @errorServiceMaintenance.
  ///
  /// In sv, this message translates to:
  /// **'Tjänsten är temporärt otillgänglig för underhåll medan {action}. Försök igen om några minuter.'**
  String errorServiceMaintenance(String action);

  /// No description provided for @errorServiceSync.
  ///
  /// In sv, this message translates to:
  /// **'Synkroniseringstjänsten är temporärt otillgänglig medan {action}. Ändringar sparas lokalt och synkroniseras automatiskt senare.'**
  String errorServiceSync(String action);

  /// No description provided for @errorServiceTemporary.
  ///
  /// In sv, this message translates to:
  /// **'Tjänsten är temporärt otillgänglig medan {action}. Försök igen om ett par minuter.'**
  String errorServiceTemporary(String action);

  /// No description provided for @errorDnsConnection.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ansluta till servern medan {action}. Kontrollera internetanslutningen eller försök igen senare.'**
  String errorDnsConnection(String action);

  /// No description provided for @errorUnknownWhileAction.
  ///
  /// In sv, this message translates to:
  /// **'Ett oväntat fel uppstod medan {action}. Försök igen eller kontakta support om problemet kvarstår.'**
  String errorUnknownWhileAction(String action);

  /// No description provided for @errorUnknownWithTechnical.
  ///
  /// In sv, this message translates to:
  /// **'Ett oväntat fel uppstod medan {action}. Försök igen eller kontakta support om problemet kvarstår. (Teknisk information: {techInfo})'**
  String errorUnknownWithTechnical(String action, String techInfo);

  /// No description provided for @errorFallbackWhileAction.
  ///
  /// In sv, this message translates to:
  /// **'Ett fel uppstod medan {action}. Försök igen.'**
  String errorFallbackWhileAction(String action);

  /// No description provided for @suggestionLabel.
  ///
  /// In sv, this message translates to:
  /// **'Förslag:'**
  String get suggestionLabel;

  /// No description provided for @suggestionSavedLocally.
  ///
  /// In sv, this message translates to:
  /// **'Receptet sparas lokalt och synkroniseras automatiskt'**
  String get suggestionSavedLocally;

  /// No description provided for @suggestionCheckLoggedIn.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollera att du är inloggad'**
  String get suggestionCheckLoggedIn;

  /// No description provided for @suggestionRequestPermission.
  ///
  /// In sv, this message translates to:
  /// **'Be om redigeringsrättigheter från receptägaren'**
  String get suggestionRequestPermission;

  /// No description provided for @suggestionImageSavedLocally.
  ///
  /// In sv, this message translates to:
  /// **'Bilderna sparas lokalt och laddas upp automatiskt senare'**
  String get suggestionImageSavedLocally;

  /// No description provided for @suggestionImageSizeLimit.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollera att bilderna är mindre än 10MB'**
  String get suggestionImageSizeLimit;

  /// No description provided for @suggestionImageFormat.
  ///
  /// In sv, this message translates to:
  /// **'Använd JPG, PNG eller HEIC format'**
  String get suggestionImageFormat;

  /// No description provided for @suggestionSelectAnotherDraft.
  ///
  /// In sv, this message translates to:
  /// **'Välj ett annat utkast från listan'**
  String get suggestionSelectAnotherDraft;

  /// No description provided for @suggestionCreateNewRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Börja skapa ett nytt recept istället'**
  String get suggestionCreateNewRecipe;

  /// No description provided for @suggestionUpdateAccountSettings.
  ///
  /// In sv, this message translates to:
  /// **'Uppdatera dina kontoinställningar'**
  String get suggestionUpdateAccountSettings;

  /// No description provided for @suggestionCheckConnection.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollera internetanslutningen'**
  String get suggestionCheckConnection;

  /// No description provided for @suggestionRetryWhenStable.
  ///
  /// In sv, this message translates to:
  /// **'Försök igen när anslutningen är stabil'**
  String get suggestionRetryWhenStable;

  /// No description provided for @suggestionLoginAgain.
  ///
  /// In sv, this message translates to:
  /// **'Logga in på nytt'**
  String get suggestionLoginAgain;

  /// No description provided for @suggestionRetryInMinutes.
  ///
  /// In sv, this message translates to:
  /// **'Försök igen om några minuter'**
  String get suggestionRetryInMinutes;

  /// No description provided for @suggestionRetryOrContactSupport.
  ///
  /// In sv, this message translates to:
  /// **'Försök igen eller kontakta support'**
  String get suggestionRetryOrContactSupport;

  /// No description provided for @statusConnected.
  ///
  /// In sv, this message translates to:
  /// **'Ansluten'**
  String get statusConnected;

  /// No description provided for @statusFirebaseUnavailable.
  ///
  /// In sv, this message translates to:
  /// **'Firebase otillgänglig'**
  String get statusFirebaseUnavailable;

  /// No description provided for @statusNoInternet.
  ///
  /// In sv, this message translates to:
  /// **'Ingen internetanslutning'**
  String get statusNoInternet;

  /// No description provided for @statusDisconnected.
  ///
  /// In sv, this message translates to:
  /// **'Frånkopplad'**
  String get statusDisconnected;

  /// No description provided for @statusCheckingConnection.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollerar anslutning...'**
  String get statusCheckingConnection;

  /// No description provided for @statusReconnecting.
  ///
  /// In sv, this message translates to:
  /// **'Återansluter...'**
  String get statusReconnecting;

  /// No description provided for @statusDone.
  ///
  /// In sv, this message translates to:
  /// **'Klar!'**
  String get statusDone;

  /// No description provided for @displayOnlyYou.
  ///
  /// In sv, this message translates to:
  /// **'Bara du'**
  String get displayOnlyYou;

  /// No description provided for @displayUnknownUser.
  ///
  /// In sv, this message translates to:
  /// **'Okänd användare'**
  String get displayUnknownUser;

  /// No description provided for @displayNoConsent.
  ///
  /// In sv, this message translates to:
  /// **'Inget samtycke'**
  String get displayNoConsent;

  /// No description provided for @resourceTypeRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Recept'**
  String get resourceTypeRecipe;

  /// No description provided for @resourceTypeMenu.
  ///
  /// In sv, this message translates to:
  /// **'Meny'**
  String get resourceTypeMenu;

  /// No description provided for @resourceTypeShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslista'**
  String get resourceTypeShoppingList;

  /// No description provided for @permissionOwner.
  ///
  /// In sv, this message translates to:
  /// **'Ägare'**
  String get permissionOwner;

  /// No description provided for @permissionAdmin.
  ///
  /// In sv, this message translates to:
  /// **'Administratör'**
  String get permissionAdmin;

  /// No description provided for @permissionEditor.
  ///
  /// In sv, this message translates to:
  /// **'Redigerare'**
  String get permissionEditor;

  /// No description provided for @permissionWriter.
  ///
  /// In sv, this message translates to:
  /// **'Skrivare'**
  String get permissionWriter;

  /// No description provided for @permissionViewer.
  ///
  /// In sv, this message translates to:
  /// **'Betraktare'**
  String get permissionViewer;

  /// No description provided for @permissionReader.
  ///
  /// In sv, this message translates to:
  /// **'Läsare'**
  String get permissionReader;

  /// No description provided for @permissionUnknown.
  ///
  /// In sv, this message translates to:
  /// **'Okänd behörighet'**
  String get permissionUnknown;

  /// No description provided for @activityJustNow.
  ///
  /// In sv, this message translates to:
  /// **'Just nu'**
  String get activityJustNow;

  /// No description provided for @activityActiveNow.
  ///
  /// In sv, this message translates to:
  /// **'Aktiv nu'**
  String get activityActiveNow;

  /// No description provided for @activityActiveThisWeek.
  ///
  /// In sv, this message translates to:
  /// **'Aktiv denna veckan'**
  String get activityActiveThisWeek;

  /// No description provided for @activityInactive.
  ///
  /// In sv, this message translates to:
  /// **'Inaktiv'**
  String get activityInactive;

  /// No description provided for @validationTitleCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Titel får inte vara tom'**
  String get validationTitleCannotBeEmpty;

  /// No description provided for @validationIngredientRequired.
  ///
  /// In sv, this message translates to:
  /// **'Minst en ingrediens krävs'**
  String get validationIngredientRequired;

  /// No description provided for @validationInstructionRequired.
  ///
  /// In sv, this message translates to:
  /// **'Minst en instruktion krävs'**
  String get validationInstructionRequired;

  /// No description provided for @validationPortionsMustBePositive.
  ///
  /// In sv, this message translates to:
  /// **'Portioner måste vara positiva'**
  String get validationPortionsMustBePositive;

  /// No description provided for @validationTimeMustBePositive.
  ///
  /// In sv, this message translates to:
  /// **'Tid måste vara positiv'**
  String get validationTimeMustBePositive;

  /// No description provided for @validationRatingRange.
  ///
  /// In sv, this message translates to:
  /// **'Betyg måste vara mellan 0 och 5'**
  String get validationRatingRange;

  /// No description provided for @validationInvalidIngredientIndex.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt ingrediensindex: {index}'**
  String validationInvalidIngredientIndex(int index);

  /// No description provided for @validationInvalidInstructionIndex.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt instruktionsindex: {index}'**
  String validationInvalidInstructionIndex(int index);

  /// No description provided for @validationInvalidImageIndex.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt bildindex: {index}'**
  String validationInvalidImageIndex(int index);

  /// No description provided for @notificationTitleSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Lyckades!'**
  String get notificationTitleSuccess;

  /// No description provided for @notificationTitleError.
  ///
  /// In sv, this message translates to:
  /// **'Fel uppstod'**
  String get notificationTitleError;

  /// No description provided for @notificationTitleNewRecipeActivity.
  ///
  /// In sv, this message translates to:
  /// **'Ny receptaktivitet'**
  String get notificationTitleNewRecipeActivity;

  /// No description provided for @notificationTitleFriendActivity.
  ///
  /// In sv, this message translates to:
  /// **'Vänaktivitet'**
  String get notificationTitleFriendActivity;

  /// No description provided for @notificationTitleCollaborationActivity.
  ///
  /// In sv, this message translates to:
  /// **'Samarbetsaktivitet'**
  String get notificationTitleCollaborationActivity;

  /// No description provided for @notificationTitleShoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslistor'**
  String get notificationTitleShoppingLists;

  /// No description provided for @errorWeakPassword.
  ///
  /// In sv, this message translates to:
  /// **'Lösenordet är för svagt. Använd minst 6 tecken.'**
  String get errorWeakPassword;

  /// No description provided for @errorLoginFailed.
  ///
  /// In sv, this message translates to:
  /// **'Inloggning misslyckades. Försök igen.'**
  String get errorLoginFailed;

  /// No description provided for @errorCouldNotLogOut.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte logga ut'**
  String get errorCouldNotLogOut;

  /// No description provided for @errorCouldNotDeleteAccount.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort konto'**
  String get errorCouldNotDeleteAccount;

  /// No description provided for @errorCouldNotCompleteMfa.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte slutföra MFA-registrering'**
  String get errorCouldNotCompleteMfa;

  /// No description provided for @errorMfaVerificationFailed.
  ///
  /// In sv, this message translates to:
  /// **'MFA-verifiering misslyckades'**
  String get errorMfaVerificationFailed;

  /// No description provided for @errorInvalidPhoneNumber.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt telefonnummer. Ange med landskod (+46).'**
  String get errorInvalidPhoneNumber;

  /// No description provided for @errorCouldNotSaveRecipeCheckConnection.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara receptet. Kontrollera din internetanslutning.'**
  String get errorCouldNotSaveRecipeCheckConnection;

  /// No description provided for @errorCouldNotUpdateRecipeCheckConnection.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera receptet. Kontrollera din internetanslutning.'**
  String get errorCouldNotUpdateRecipeCheckConnection;

  /// No description provided for @errorCouldNotDeleteFromServer.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort recept från servern'**
  String get errorCouldNotDeleteFromServer;

  /// No description provided for @errorRateLimitExceeded.
  ///
  /// In sv, this message translates to:
  /// **'För många förfrågningar. Försök igen om {seconds} sekunder.'**
  String errorRateLimitExceeded(int seconds);

  /// No description provided for @errorCouldNotImportRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte importera recept'**
  String get errorCouldNotImportRecipes;

  /// No description provided for @errorCouldNotExportRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte exportera recept'**
  String get errorCouldNotExportRecipes;

  /// No description provided for @errorCouldNotMarkAsCooked.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte markera recept som tillagat'**
  String get errorCouldNotMarkAsCooked;

  /// No description provided for @errorCouldNotAddIngredient.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lägga till ingrediens'**
  String get errorCouldNotAddIngredient;

  /// No description provided for @errorCouldNotUpdateIngredient.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera ingrediens'**
  String get errorCouldNotUpdateIngredient;

  /// No description provided for @errorCouldNotRemoveIngredient.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort ingrediens'**
  String get errorCouldNotRemoveIngredient;

  /// No description provided for @errorCouldNotAddInstruction.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte lägga till instruktion'**
  String get errorCouldNotAddInstruction;

  /// No description provided for @errorCouldNotUpdateInstruction.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera instruktion'**
  String get errorCouldNotUpdateInstruction;

  /// No description provided for @errorCouldNotRemoveInstruction.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort instruktion'**
  String get errorCouldNotRemoveInstruction;

  /// No description provided for @errorCouldNotStartRealtimeEditing.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte starta realtidsredigering'**
  String get errorCouldNotStartRealtimeEditing;

  /// No description provided for @errorRealtimeSyncFailed.
  ///
  /// In sv, this message translates to:
  /// **'Realtidssynkronisering misslyckades'**
  String get errorRealtimeSyncFailed;

  /// No description provided for @errorCouldNotApplyRealtimeEdit.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte genomföra realtidsändring'**
  String get errorCouldNotApplyRealtimeEdit;

  /// No description provided for @errorCouldNotStartSync.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte starta synkronisering'**
  String get errorCouldNotStartSync;

  /// No description provided for @errorSyncErrorFor.
  ///
  /// In sv, this message translates to:
  /// **'Synkroniseringsfel för {syncType}'**
  String errorSyncErrorFor(String syncType);

  /// No description provided for @errorCouldNotUpdateNotificationToken.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera notifikationstoken'**
  String get errorCouldNotUpdateNotificationToken;

  /// No description provided for @errorCouldNotUpdateNotificationSettings.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera notifikationsinställningar'**
  String get errorCouldNotUpdateNotificationSettings;

  /// No description provided for @errorCouldNotUpdateAllergenSettings.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera allergeninställningar'**
  String get errorCouldNotUpdateAllergenSettings;

  /// No description provided for @errorCouldNotLoadProfile.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda profil'**
  String get errorCouldNotLoadProfile;

  /// No description provided for @errorCouldNotUpdateRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera recept'**
  String get errorCouldNotUpdateRecipes;

  /// No description provided for @errorNetworkCheckInternet.
  ///
  /// In sv, this message translates to:
  /// **'Nätverksfel - kontrollera din internetanslutning'**
  String get errorNetworkCheckInternet;

  /// No description provided for @errorPermissionMissing.
  ///
  /// In sv, this message translates to:
  /// **'Behörighet saknas'**
  String get errorPermissionMissing;

  /// No description provided for @errorTimeout.
  ///
  /// In sv, this message translates to:
  /// **'Tidsgräns överskriden'**
  String get errorTimeout;

  /// No description provided for @errorTechnical.
  ///
  /// In sv, this message translates to:
  /// **'Tekniskt fel'**
  String get errorTechnical;

  /// No description provided for @permissionCanViewRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kan visa recept'**
  String get permissionCanViewRecipe;

  /// No description provided for @permissionCanComment.
  ///
  /// In sv, this message translates to:
  /// **'Kan skriva kommentarer'**
  String get permissionCanComment;

  /// No description provided for @permissionCanEditRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kan redigera recept'**
  String get permissionCanEditRecipe;

  /// No description provided for @permissionCanManageMembers.
  ///
  /// In sv, this message translates to:
  /// **'Kan hantera medlemmar'**
  String get permissionCanManageMembers;

  /// No description provided for @permissionOwnerOfRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Ägare av recept'**
  String get permissionOwnerOfRecipe;

  /// No description provided for @errorGroupNameExistsWithName.
  ///
  /// In sv, this message translates to:
  /// **'En grupp med namnet \"{name}\" finns redan'**
  String errorGroupNameExistsWithName(String name);

  /// No description provided for @errorUserNotLoggedIn.
  ///
  /// In sv, this message translates to:
  /// **'Användare inte inloggad'**
  String get errorUserNotLoggedIn;

  /// No description provided for @errorResourceNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Resursen hittades inte'**
  String get errorResourceNotFound;

  /// No description provided for @errorNoDeletePermission.
  ///
  /// In sv, this message translates to:
  /// **'Ingen behörighet att ta bort resursen'**
  String get errorNoDeletePermission;

  /// No description provided for @errorCannotRemoveResourceOwner.
  ///
  /// In sv, this message translates to:
  /// **'Kan inte ta bort ägaren från resursen'**
  String get errorCannotRemoveResourceOwner;

  /// No description provided for @validationRecipeTitleCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Recepttitel kan inte vara tom'**
  String get validationRecipeTitleCannotBeEmpty;

  /// No description provided for @validationCookingTimeCannotBeNegative.
  ///
  /// In sv, this message translates to:
  /// **'Tillagningstid kan inte vara negativ'**
  String get validationCookingTimeCannotBeNegative;

  /// No description provided for @validationIngredientCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Ingrediens kan inte vara tom'**
  String get validationIngredientCannotBeEmpty;

  /// No description provided for @validationInstructionCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Instruktion kan inte vara tom'**
  String get validationInstructionCannotBeEmpty;

  /// No description provided for @validationAtLeastOneIngredient.
  ///
  /// In sv, this message translates to:
  /// **'Minst en ingrediens krävs'**
  String get validationAtLeastOneIngredient;

  /// No description provided for @validationAtLeastOneInstruction.
  ///
  /// In sv, this message translates to:
  /// **'Minst en instruktion krävs'**
  String get validationAtLeastOneInstruction;

  /// No description provided for @validationImageUrlCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Bild-URL kan inte vara tom'**
  String get validationImageUrlCannotBeEmpty;

  /// No description provided for @validationInvalidImageUrlFormat.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig bild-URL format'**
  String get validationInvalidImageUrlFormat;

  /// No description provided for @validationMaxImagesReached.
  ///
  /// In sv, this message translates to:
  /// **'Maximalt 5 bilder tillåtna'**
  String get validationMaxImagesReached;

  /// No description provided for @validationRecipeTitleMissing.
  ///
  /// In sv, this message translates to:
  /// **'Recepttitel saknas'**
  String get validationRecipeTitleMissing;

  /// No description provided for @validationRecipeNoIngredients.
  ///
  /// In sv, this message translates to:
  /// **'Recept har inga ingredienser'**
  String get validationRecipeNoIngredients;

  /// No description provided for @validationRecipeNoInstructions.
  ///
  /// In sv, this message translates to:
  /// **'Recept har inga instruktioner'**
  String get validationRecipeNoInstructions;

  /// No description provided for @validationRecipeDescriptionEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Receptbeskrivning saknas'**
  String get validationRecipeDescriptionEmpty;

  /// No description provided for @validationUserIdCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Användar-ID kan inte vara tomt'**
  String get validationUserIdCannotBeEmpty;

  /// No description provided for @validationUsernameCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Användarnamn kan inte vara tomt'**
  String get validationUsernameCannotBeEmpty;

  /// No description provided for @validationUserAlreadyParticipant.
  ///
  /// In sv, this message translates to:
  /// **'Användaren är redan deltagare: {name}'**
  String validationUserAlreadyParticipant(String name);

  /// No description provided for @validationMaxParticipantsReached.
  ///
  /// In sv, this message translates to:
  /// **'Maxgräns för deltagare nådd (50)'**
  String get validationMaxParticipantsReached;

  /// No description provided for @validationCannotRemoveRecipeOwner.
  ///
  /// In sv, this message translates to:
  /// **'Kan inte ta bort receptägaren'**
  String get validationCannotRemoveRecipeOwner;

  /// No description provided for @validationCannotRemoveMenuOwner.
  ///
  /// In sv, this message translates to:
  /// **'Kan inte ta bort menyägaren'**
  String get validationCannotRemoveMenuOwner;

  /// No description provided for @validationUserNotParticipant.
  ///
  /// In sv, this message translates to:
  /// **'Användaren är inte deltagare: {id}'**
  String validationUserNotParticipant(String id);

  /// No description provided for @validationCannotChangeOwnerPermission.
  ///
  /// In sv, this message translates to:
  /// **'Kan inte ändra ägarens behörighet'**
  String get validationCannotChangeOwnerPermission;

  /// No description provided for @validationCannotAssignOwnerPermission.
  ///
  /// In sv, this message translates to:
  /// **'Kan inte tilldela ägarbehörighet till annan användare'**
  String get validationCannotAssignOwnerPermission;

  /// No description provided for @validationRecipeMissingOwner.
  ///
  /// In sv, this message translates to:
  /// **'Recept saknar ägare'**
  String get validationRecipeMissingOwner;

  /// No description provided for @validationRecipeOwnerMissingName.
  ///
  /// In sv, this message translates to:
  /// **'Receptägare saknar visningsnamn'**
  String get validationRecipeOwnerMissingName;

  /// No description provided for @validationParticipantEmptyUserId.
  ///
  /// In sv, this message translates to:
  /// **'Deltagare har tomt användar-ID'**
  String get validationParticipantEmptyUserId;

  /// No description provided for @validationTagNameRequired.
  ///
  /// In sv, this message translates to:
  /// **'Taggnamn krävs'**
  String get validationTagNameRequired;

  /// No description provided for @validationTagNameTooLong.
  ///
  /// In sv, this message translates to:
  /// **'Taggnamn för långt (max 50 tecken)'**
  String get validationTagNameTooLong;

  /// No description provided for @validationTagNameNoCommas.
  ///
  /// In sv, this message translates to:
  /// **'Taggnamn får inte innehålla kommatecken'**
  String get validationTagNameNoCommas;

  /// No description provided for @validationTagNameReserved.
  ///
  /// In sv, this message translates to:
  /// **'Detta namn är reserverat för systemtaggar'**
  String get validationTagNameReserved;

  /// No description provided for @validationGroupNameRequired.
  ///
  /// In sv, this message translates to:
  /// **'Gruppnamn krävs'**
  String get validationGroupNameRequired;

  /// No description provided for @validationGroupNameTooLong.
  ///
  /// In sv, this message translates to:
  /// **'Gruppnamn för långt (max 50 tecken)'**
  String get validationGroupNameTooLong;

  /// No description provided for @validationRuleMustBeLinked.
  ///
  /// In sv, this message translates to:
  /// **'Regel måste kopplas till en tagg'**
  String get validationRuleMustBeLinked;

  /// No description provided for @validationRuleNameRequired.
  ///
  /// In sv, this message translates to:
  /// **'Regelnamn krävs'**
  String get validationRuleNameRequired;

  /// No description provided for @validationRuleMustHaveCondition.
  ///
  /// In sv, this message translates to:
  /// **'Regel måste ha minst ett villkor'**
  String get validationRuleMustHaveCondition;

  /// No description provided for @validationAllConditionsMustHaveValue.
  ///
  /// In sv, this message translates to:
  /// **'Alla villkor måste ha ett värde'**
  String get validationAllConditionsMustHaveValue;

  /// No description provided for @validationImageDoesNotExist.
  ///
  /// In sv, this message translates to:
  /// **'Bilden finns inte'**
  String get validationImageDoesNotExist;

  /// No description provided for @validationCouldNotReadImageSize.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte läsa bildstorlek'**
  String get validationCouldNotReadImageSize;

  /// No description provided for @validationImageTooLargeWithSize.
  ///
  /// In sv, this message translates to:
  /// **'Bilden är för stor (max {size} MB)'**
  String validationImageTooLargeWithSize(int size);

  /// No description provided for @validationCouldNotValidateImage.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte validera bild'**
  String get validationCouldNotValidateImage;

  /// No description provided for @difficultyVeryEasy.
  ///
  /// In sv, this message translates to:
  /// **'Mycket lätt'**
  String get difficultyVeryEasy;

  /// No description provided for @difficultyEasy.
  ///
  /// In sv, this message translates to:
  /// **'Lätt'**
  String get difficultyEasy;

  /// No description provided for @difficultyMedium.
  ///
  /// In sv, this message translates to:
  /// **'Medel'**
  String get difficultyMedium;

  /// No description provided for @difficultyHard.
  ///
  /// In sv, this message translates to:
  /// **'Svår'**
  String get difficultyHard;

  /// No description provided for @difficultyVeryHard.
  ///
  /// In sv, this message translates to:
  /// **'Mycket svår'**
  String get difficultyVeryHard;

  /// No description provided for @difficultyUnknown.
  ///
  /// In sv, this message translates to:
  /// **'Okänd'**
  String get difficultyUnknown;

  /// No description provided for @contentSummaryIngredients.
  ///
  /// In sv, this message translates to:
  /// **'{count} ingredienser'**
  String contentSummaryIngredients(int count);

  /// No description provided for @contentSummarySteps.
  ///
  /// In sv, this message translates to:
  /// **'{count} steg'**
  String contentSummarySteps(int count);

  /// No description provided for @contentSummaryMinutes.
  ///
  /// In sv, this message translates to:
  /// **'{count} minuter'**
  String contentSummaryMinutes(int count);

  /// No description provided for @contentSummaryPortions.
  ///
  /// In sv, this message translates to:
  /// **'{count} portioner'**
  String contentSummaryPortions(int count);

  /// No description provided for @collaborationPrivateRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Privat recept'**
  String get collaborationPrivateRecipe;

  /// No description provided for @collaborationCollaborativeEditorsViewers.
  ///
  /// In sv, this message translates to:
  /// **'Kollaborativt ({editors} redigerare, {viewers} betraktare)'**
  String collaborationCollaborativeEditorsViewers(int editors, int viewers);

  /// No description provided for @collaborationCollaborativeEditors.
  ///
  /// In sv, this message translates to:
  /// **'Kollaborativt ({editors} redigerare)'**
  String collaborationCollaborativeEditors(int editors);

  /// No description provided for @collaborationSharedViewers.
  ///
  /// In sv, this message translates to:
  /// **'Delat ({viewers} betraktare)'**
  String collaborationSharedViewers(int viewers);

  /// No description provided for @collaborationSharedRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Delat recept'**
  String get collaborationSharedRecipe;

  /// No description provided for @participantOwnerOnly.
  ///
  /// In sv, this message translates to:
  /// **'Endast ägare: {name}'**
  String participantOwnerOnly(String name);

  /// No description provided for @participantSummary.
  ///
  /// In sv, this message translates to:
  /// **'Ägare: {owner}, Deltagare: {count}st'**
  String participantSummary(String owner, int count);

  /// No description provided for @activityMinutesAgo.
  ///
  /// In sv, this message translates to:
  /// **'{count} min sedan'**
  String activityMinutesAgo(int count);

  /// No description provided for @activityHoursAgo.
  ///
  /// In sv, this message translates to:
  /// **'{count} tim sedan'**
  String activityHoursAgo(int count);

  /// No description provided for @activityDaysAgo.
  ///
  /// In sv, this message translates to:
  /// **'{count} dagar sedan'**
  String activityDaysAgo(int count);

  /// No description provided for @activityWeeksAgo.
  ///
  /// In sv, this message translates to:
  /// **'{count} veckor sedan'**
  String activityWeeksAgo(int count);

  /// No description provided for @resourceCreatedBy.
  ///
  /// In sv, this message translates to:
  /// **'Skapades av {name}'**
  String resourceCreatedBy(String name);

  /// No description provided for @resourceLastEditedBy.
  ///
  /// In sv, this message translates to:
  /// **'Senast redigerad av {name} {timeAgo}'**
  String resourceLastEditedBy(String name, String timeAgo);

  /// No description provided for @syncParsingNotImplemented.
  ///
  /// In sv, this message translates to:
  /// **'RealtimeShoppingList parsing inte implementerad än'**
  String get syncParsingNotImplemented;

  /// No description provided for @backupNoRecipesToExport.
  ///
  /// In sv, this message translates to:
  /// **'Inga recept att exportera'**
  String get backupNoRecipesToExport;

  /// No description provided for @backupPlatformNotSupported.
  ///
  /// In sv, this message translates to:
  /// **'Plattformen stöds inte'**
  String get backupPlatformNotSupported;

  /// No description provided for @backupSavedAndroid.
  ///
  /// In sv, this message translates to:
  /// **'Backup sparad i Android/data/.../Butlery'**
  String get backupSavedAndroid;

  /// No description provided for @backupSavedIos.
  ///
  /// In sv, this message translates to:
  /// **'Backup sparad i Filer-appen'**
  String get backupSavedIos;

  /// No description provided for @backupCouldNotFindStorageDir.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte hitta lagringsmapp'**
  String get backupCouldNotFindStorageDir;

  /// No description provided for @backupCouldNotSaveFile.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara fil: {error}'**
  String backupCouldNotSaveFile(String error);

  /// No description provided for @backupCouldNotReadFile.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte läsa filen'**
  String get backupCouldNotReadFile;

  /// No description provided for @backupInvalidFile.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig backup-fil - inte från Butlery'**
  String get backupInvalidFile;

  /// No description provided for @backupUnknownRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Okänt recept'**
  String get backupUnknownRecipe;

  /// No description provided for @backupImportedFromBackup.
  ///
  /// In sv, this message translates to:
  /// **'Importerat från backup {date}'**
  String backupImportedFromBackup(String date);

  /// No description provided for @backupExportFailed.
  ///
  /// In sv, this message translates to:
  /// **'Export misslyckades: {error}'**
  String backupExportFailed(String error);

  /// No description provided for @backupImportFailed.
  ///
  /// In sv, this message translates to:
  /// **'Import misslyckades: {error}'**
  String backupImportFailed(String error);

  /// No description provided for @syncAlreadyInProgress.
  ///
  /// In sv, this message translates to:
  /// **'Synkronisering pågår redan'**
  String get syncAlreadyInProgress;

  /// No description provided for @syncMustBeOnline.
  ///
  /// In sv, this message translates to:
  /// **'Du måste vara online för att synkronisera'**
  String get syncMustBeOnline;

  /// No description provided for @syncNoUserLoggedIn.
  ///
  /// In sv, this message translates to:
  /// **'Ingen användare inloggad'**
  String get syncNoUserLoggedIn;

  /// No description provided for @syncNoPendingChanges.
  ///
  /// In sv, this message translates to:
  /// **'Inga väntande ändringar'**
  String get syncNoPendingChanges;

  /// No description provided for @syncAllSynced.
  ///
  /// In sv, this message translates to:
  /// **'Alla {count} ändringar synkade!'**
  String syncAllSynced(int count);

  /// No description provided for @syncPartialSuccess.
  ///
  /// In sv, this message translates to:
  /// **'{synced} av {total} synkade, {remaining} kvar'**
  String syncPartialSuccess(int synced, int total, int remaining);

  /// No description provided for @syncFailedRetryLater.
  ///
  /// In sv, this message translates to:
  /// **'Synkronisering misslyckades, försöker igen senare'**
  String get syncFailedRetryLater;

  /// No description provided for @instagramCouldNotFindRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte hitta recept i inlagget. Ta en skärmbild av receptet.'**
  String get instagramCouldNotFindRecipe;

  /// No description provided for @uploadNotificationComplete.
  ///
  /// In sv, this message translates to:
  /// **'Uppladdning slutförd'**
  String get uploadNotificationComplete;

  /// No description provided for @uploadNotificationCompleteBody.
  ///
  /// In sv, this message translates to:
  /// **'Bilden har laddats upp framgångsrikt'**
  String get uploadNotificationCompleteBody;

  /// No description provided for @uploadNotificationFailed.
  ///
  /// In sv, this message translates to:
  /// **'Uppladdning misslyckades'**
  String get uploadNotificationFailed;

  /// No description provided for @uploadNotificationFailedBody.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda upp bilden efter flera försök'**
  String get uploadNotificationFailedBody;

  /// No description provided for @uploadStatusWaiting.
  ///
  /// In sv, this message translates to:
  /// **'Väntar på att ladda upp {pending} bilder...'**
  String uploadStatusWaiting(int pending);

  /// No description provided for @uploadStatusUploading.
  ///
  /// In sv, this message translates to:
  /// **'Laddar upp {active} bilder ({progress}% klart, {pending} väntar)'**
  String uploadStatusUploading(int active, int progress, int pending);

  /// No description provided for @uploadStatusPreparing.
  ///
  /// In sv, this message translates to:
  /// **'Förbereder uppladdning...'**
  String get uploadStatusPreparing;

  /// No description provided for @uploadStatusRetrying.
  ///
  /// In sv, this message translates to:
  /// **'Försöker igen ({attempt}/{max})...'**
  String uploadStatusRetrying(int attempt, int max);

  /// No description provided for @uploadStatusComplete.
  ///
  /// In sv, this message translates to:
  /// **'Uppladdning slutförd'**
  String get uploadStatusComplete;

  /// No description provided for @uploadStatusCancelled.
  ///
  /// In sv, this message translates to:
  /// **'Uppladdning avbruten'**
  String get uploadStatusCancelled;

  /// No description provided for @uploadFailureNetwork.
  ///
  /// In sv, this message translates to:
  /// **'Nätverksfel - kontrollera anslutningen'**
  String get uploadFailureNetwork;

  /// No description provided for @uploadFailureValidation.
  ///
  /// In sv, this message translates to:
  /// **'Bilden kunde inte valideras'**
  String get uploadFailureValidation;

  /// No description provided for @uploadFailureServer.
  ///
  /// In sv, this message translates to:
  /// **'Serverfel - försök igen'**
  String get uploadFailureServer;

  /// No description provided for @uploadFailureCancelled.
  ///
  /// In sv, this message translates to:
  /// **'Uppladdning avbruten'**
  String get uploadFailureCancelled;

  /// No description provided for @uploadFailureGeneric.
  ///
  /// In sv, this message translates to:
  /// **'Uppladdning misslyckades'**
  String get uploadFailureGeneric;

  /// No description provided for @uploadRetryCheckInternet.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollera internetanslutningen och tryck för att försöka igen'**
  String get uploadRetryCheckInternet;

  /// No description provided for @uploadRetryCheckImage.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollera att bilden är giltig och inte för stor'**
  String get uploadRetryCheckImage;

  /// No description provided for @uploadRetryTryLater.
  ///
  /// In sv, this message translates to:
  /// **'Försök igen om en stund'**
  String get uploadRetryTryLater;

  /// No description provided for @uploadRetryTapToRetry.
  ///
  /// In sv, this message translates to:
  /// **'Tryck för att försöka igen'**
  String get uploadRetryTapToRetry;

  /// No description provided for @llmUnexpectedError.
  ///
  /// In sv, this message translates to:
  /// **'Ett oväntat fel uppstod: {error}'**
  String llmUnexpectedError(String error);

  /// No description provided for @llmUnknownRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Okänt recept'**
  String get llmUnknownRecipe;

  /// No description provided for @llmMustBeLoggedIn.
  ///
  /// In sv, this message translates to:
  /// **'Du måste vara inloggad för att använda AI-funktioner.'**
  String get llmMustBeLoggedIn;

  /// No description provided for @llmServiceOverloaded.
  ///
  /// In sv, this message translates to:
  /// **'AI-tjänsten är tillfälligt överbelastad. Försök igen om en stund.'**
  String get llmServiceOverloaded;

  /// No description provided for @llmInvalidArgument.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt argument: {error}'**
  String llmInvalidArgument(String error);

  /// No description provided for @llmGenericError.
  ///
  /// In sv, this message translates to:
  /// **'Ett fel uppstod: {error}'**
  String llmGenericError(String error);

  /// No description provided for @tiktokCouldNotFetchDescription.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte hämta videobeskrivningen. Ta en skärmbild av receptet.'**
  String get tiktokCouldNotFetchDescription;

  /// No description provided for @tiktokAiQuotaExhausted.
  ///
  /// In sv, this message translates to:
  /// **'AI-kvoten är slut. Markera receptdelar manuellt.'**
  String get tiktokAiQuotaExhausted;

  /// No description provided for @tiktokCouldNotExtractRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte extrahera receptet automatiskt. Markera receptdelar manuellt.'**
  String get tiktokCouldNotExtractRecipe;

  /// No description provided for @tiktokNoRecipeInDescription.
  ///
  /// In sv, this message translates to:
  /// **'Videobeskrivningen innehåller inget recept. Ta en skärmbild av receptet.'**
  String get tiktokNoRecipeInDescription;

  /// No description provided for @rateLimitTooFast.
  ///
  /// In sv, this message translates to:
  /// **'Du importerar för snabbt. Vänta {seconds} sekunder.'**
  String rateLimitTooFast(int seconds);

  /// No description provided for @rateLimitHourly.
  ///
  /// In sv, this message translates to:
  /// **'Du har nått timgränsen. Försök igen om {minutes} minuter.'**
  String rateLimitHourly(int minutes);

  /// No description provided for @rateLimitDaily.
  ///
  /// In sv, this message translates to:
  /// **'Du har nått dagens gräns för importer. Försök igen imorgon.'**
  String get rateLimitDaily;

  /// No description provided for @rateLimitAiDaily.
  ///
  /// In sv, this message translates to:
  /// **'AI-kvoten för idag är slut. Försök igen imorgon.'**
  String get rateLimitAiDaily;

  /// No description provided for @rateLimitAiMonthly.
  ///
  /// In sv, this message translates to:
  /// **'AI-kvoten för månaden är slut.'**
  String get rateLimitAiMonthly;

  /// No description provided for @rateLimitBudgetDaily.
  ///
  /// In sv, this message translates to:
  /// **'Dagens AI-budget är förbrukad. Försök igen imorgon.'**
  String get rateLimitBudgetDaily;

  /// No description provided for @rateLimitBudgetMonthly.
  ///
  /// In sv, this message translates to:
  /// **'Månadens AI-budget är förbrukad.'**
  String get rateLimitBudgetMonthly;

  /// No description provided for @importErrorUnexpected.
  ///
  /// In sv, this message translates to:
  /// **'Ett oväntat fel uppstod'**
  String get importErrorUnexpected;

  /// No description provided for @importErrorNoInternet.
  ///
  /// In sv, this message translates to:
  /// **'Ingen internetanslutning'**
  String get importErrorNoInternet;

  /// No description provided for @importErrorTooManyImports.
  ///
  /// In sv, this message translates to:
  /// **'För många importer på kort tid. Vänta en stund.'**
  String get importErrorTooManyImports;

  /// No description provided for @importErrorAiQuotaExhausted.
  ///
  /// In sv, this message translates to:
  /// **'AI-kvoten är slut för idag'**
  String get importErrorAiQuotaExhausted;

  /// No description provided for @importErrorInvalidUrl.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig URL'**
  String get importErrorInvalidUrl;

  /// No description provided for @importErrorCouldNotReachPage.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte nå sidan'**
  String get importErrorCouldNotReachPage;

  /// No description provided for @importErrorLoginRequired.
  ///
  /// In sv, this message translates to:
  /// **'Sidan kräver inloggning'**
  String get importErrorLoginRequired;

  /// No description provided for @importErrorNoRecipeFound.
  ///
  /// In sv, this message translates to:
  /// **'Inget recept hittades'**
  String get importErrorNoRecipeFound;

  /// No description provided for @importErrorCouldNotReadImage.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte läsa texten i bilden'**
  String get importErrorCouldNotReadImage;

  /// No description provided for @importErrorCouldNotParseRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte tolka receptet'**
  String get importErrorCouldNotParseRecipe;

  /// No description provided for @importErrorCouldNotSaveRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte spara receptet'**
  String get importErrorCouldNotSaveRecipe;

  /// No description provided for @importErrorCancelled.
  ///
  /// In sv, this message translates to:
  /// **'Importen avbröts'**
  String get importErrorCancelled;

  /// No description provided for @messagingPoll.
  ///
  /// In sv, this message translates to:
  /// **'Omröstning'**
  String get messagingPoll;

  /// No description provided for @shoppingListEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Tom handlingslista'**
  String get shoppingListEmpty;

  /// No description provided for @shoppingListAllBought.
  ///
  /// In sv, this message translates to:
  /// **'Alla {count} artiklar köpta'**
  String shoppingListAllBought(int count);

  /// No description provided for @shoppingListItemsRemaining.
  ///
  /// In sv, this message translates to:
  /// **'{remaining} av {total} artiklar kvar'**
  String shoppingListItemsRemaining(int remaining, int total);

  /// No description provided for @shoppingListNoActivity.
  ///
  /// In sv, this message translates to:
  /// **'Ingen aktivitet'**
  String get shoppingListNoActivity;

  /// No description provided for @shoppingListActivityNow.
  ///
  /// In sv, this message translates to:
  /// **'nu'**
  String get shoppingListActivityNow;

  /// No description provided for @shoppingListActivityMinAgo.
  ///
  /// In sv, this message translates to:
  /// **'{count} min sedan'**
  String shoppingListActivityMinAgo(int count);

  /// No description provided for @shoppingListActivityHoursAgo.
  ///
  /// In sv, this message translates to:
  /// **'{count} tim sedan'**
  String shoppingListActivityHoursAgo(int count);

  /// No description provided for @shoppingListActivityDaysAgo.
  ///
  /// In sv, this message translates to:
  /// **'{count} dagar sedan'**
  String shoppingListActivityDaysAgo(int count);

  /// No description provided for @shoppingListLastActivityBy.
  ///
  /// In sv, this message translates to:
  /// **'Senaste aktivitet av {name} {time}'**
  String shoppingListLastActivityBy(String name, String time);

  /// No description provided for @unknownResourceType.
  ///
  /// In sv, this message translates to:
  /// **'Okänd RealtimeResourceType: {value}'**
  String unknownResourceType(String value);

  /// No description provided for @notificationTitleDailySummary.
  ///
  /// In sv, this message translates to:
  /// **'Daglig sammanfattning'**
  String get notificationTitleDailySummary;

  /// No description provided for @notificationBodyNoActivityToday.
  ///
  /// In sv, this message translates to:
  /// **'Ingen ny aktivitet idag'**
  String get notificationBodyNoActivityToday;

  /// No description provided for @notificationBodyNoActivityToReport.
  ///
  /// In sv, this message translates to:
  /// **'Ingen aktivitet att rapportera'**
  String get notificationBodyNoActivityToReport;

  /// No description provided for @notificationBodyProblemLoadingActivities.
  ///
  /// In sv, this message translates to:
  /// **'Problem med att ladda aktiviteter'**
  String get notificationBodyProblemLoadingActivities;

  /// No description provided for @notificationBodyCouldNotCreateSummary.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa sammanfattning'**
  String get notificationBodyCouldNotCreateSummary;

  /// No description provided for @notificationActionViewRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Visa recept'**
  String get notificationActionViewRecipes;

  /// No description provided for @notificationActionViewFriends.
  ///
  /// In sv, this message translates to:
  /// **'Visa vänner'**
  String get notificationActionViewFriends;

  /// No description provided for @notificationActionOpenApp.
  ///
  /// In sv, this message translates to:
  /// **'Öppna app'**
  String get notificationActionOpenApp;

  /// No description provided for @notificationDefaultTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ny aktivitet'**
  String get notificationDefaultTitle;

  /// No description provided for @notificationDefaultBody.
  ///
  /// In sv, this message translates to:
  /// **'Du har ny aktivitet i Butlery'**
  String get notificationDefaultBody;

  /// No description provided for @notificationDigestRecipes.
  ///
  /// In sv, this message translates to:
  /// **'{count} recept'**
  String notificationDigestRecipes(int count);

  /// No description provided for @notificationDigestFriendActivities.
  ///
  /// In sv, this message translates to:
  /// **'{count} vänaktiviteter'**
  String notificationDigestFriendActivities(int count);

  /// No description provided for @notificationDigestShoppingLists.
  ///
  /// In sv, this message translates to:
  /// **'{count} inköpslistor'**
  String notificationDigestShoppingLists(int count);

  /// No description provided for @notificationDigestCollaborations.
  ///
  /// In sv, this message translates to:
  /// **'{count} samarbeten'**
  String notificationDigestCollaborations(int count);

  /// No description provided for @conditionTypeIngredient.
  ///
  /// In sv, this message translates to:
  /// **'Ingrediens'**
  String get conditionTypeIngredient;

  /// No description provided for @conditionTypeProperty.
  ///
  /// In sv, this message translates to:
  /// **'Egenskap'**
  String get conditionTypeProperty;

  /// No description provided for @conditionTypeKeyword.
  ///
  /// In sv, this message translates to:
  /// **'Nyckelord'**
  String get conditionTypeKeyword;

  /// No description provided for @conditionTypeSource.
  ///
  /// In sv, this message translates to:
  /// **'Källa'**
  String get conditionTypeSource;

  /// No description provided for @conditionTypeCuisine.
  ///
  /// In sv, this message translates to:
  /// **'Kök'**
  String get conditionTypeCuisine;

  /// No description provided for @conditionTypeDiet.
  ///
  /// In sv, this message translates to:
  /// **'Kost'**
  String get conditionTypeDiet;

  /// No description provided for @conditionTypeTime.
  ///
  /// In sv, this message translates to:
  /// **'Tid'**
  String get conditionTypeTime;

  /// No description provided for @conditionTypeRating.
  ///
  /// In sv, this message translates to:
  /// **'Betyg'**
  String get conditionTypeRating;

  /// No description provided for @conditionTypeRecent.
  ///
  /// In sv, this message translates to:
  /// **'Nyligen'**
  String get conditionTypeRecent;

  /// No description provided for @conditionTypeOwnership.
  ///
  /// In sv, this message translates to:
  /// **'Ägarskap'**
  String get conditionTypeOwnership;

  /// No description provided for @conditionTypeHasImage.
  ///
  /// In sv, this message translates to:
  /// **'Har bild'**
  String get conditionTypeHasImage;

  /// No description provided for @conditionTypeCompleteness.
  ///
  /// In sv, this message translates to:
  /// **'Fullständighet'**
  String get conditionTypeCompleteness;

  /// No description provided for @operatorContains.
  ///
  /// In sv, this message translates to:
  /// **'innehåller'**
  String get operatorContains;

  /// No description provided for @operatorExact.
  ///
  /// In sv, this message translates to:
  /// **'är exakt'**
  String get operatorExact;

  /// No description provided for @operatorStartsWith.
  ///
  /// In sv, this message translates to:
  /// **'börjar med'**
  String get operatorStartsWith;

  /// No description provided for @operatorNotContains.
  ///
  /// In sv, this message translates to:
  /// **'innehåller inte'**
  String get operatorNotContains;

  /// No description provided for @operatorNotExact.
  ///
  /// In sv, this message translates to:
  /// **'är inte'**
  String get operatorNotExact;

  /// No description provided for @operatorHas.
  ///
  /// In sv, this message translates to:
  /// **'har'**
  String get operatorHas;

  /// No description provided for @operatorNotHas.
  ///
  /// In sv, this message translates to:
  /// **'har inte'**
  String get operatorNotHas;

  /// No description provided for @operatorLessThan.
  ///
  /// In sv, this message translates to:
  /// **'mindre än'**
  String get operatorLessThan;

  /// No description provided for @operatorAtMost.
  ///
  /// In sv, this message translates to:
  /// **'högst'**
  String get operatorAtMost;

  /// No description provided for @operatorGreaterThan.
  ///
  /// In sv, this message translates to:
  /// **'mer än'**
  String get operatorGreaterThan;

  /// No description provided for @operatorAtLeast.
  ///
  /// In sv, this message translates to:
  /// **'minst'**
  String get operatorAtLeast;

  /// No description provided for @operatorWithinDays.
  ///
  /// In sv, this message translates to:
  /// **'inom dagar'**
  String get operatorWithinDays;

  /// No description provided for @errorAuthenticationPleaseLogin.
  ///
  /// In sv, this message translates to:
  /// **'Autentiseringsfel. Logga in igen.'**
  String get errorAuthenticationPleaseLogin;

  /// No description provided for @errorCouldNotShareRecipeWithGroups.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dela recept med grupper'**
  String get errorCouldNotShareRecipeWithGroups;

  /// No description provided for @shoppingListNotFound.
  ///
  /// In sv, this message translates to:
  /// **'Lista hittades inte'**
  String get shoppingListNotFound;

  /// No description provided for @shoppingRemainingToBuy.
  ///
  /// In sv, this message translates to:
  /// **'Kvar att handla:'**
  String get shoppingRemainingToBuy;

  /// No description provided for @shoppingAlreadyBought.
  ///
  /// In sv, this message translates to:
  /// **'Inhandlat:'**
  String get shoppingAlreadyBought;

  /// No description provided for @shoppingCreatedLabel.
  ///
  /// In sv, this message translates to:
  /// **'Skapad:'**
  String get shoppingCreatedLabel;

  /// No description provided for @shoppingUpdatedLabel.
  ///
  /// In sv, this message translates to:
  /// **'Uppdaterad:'**
  String get shoppingUpdatedLabel;

  /// No description provided for @shoppingPurchaseForRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Inköp för {recipeName}'**
  String shoppingPurchaseForRecipe(String recipeName);

  /// No description provided for @shoppingCategoryImported.
  ///
  /// In sv, this message translates to:
  /// **'Importerat'**
  String get shoppingCategoryImported;

  /// No description provided for @shoppingCategoryRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Recept'**
  String get shoppingCategoryRecipe;

  /// No description provided for @labelChat.
  ///
  /// In sv, this message translates to:
  /// **'Chatt'**
  String get labelChat;

  /// No description provided for @labelParticipantCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} deltagare'**
  String labelParticipantCount(int count);

  /// No description provided for @errorCouldNotSend.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skicka {itemType}'**
  String errorCouldNotSend(String itemType);

  /// No description provided for @errorCouldNotShare.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dela {itemType}'**
  String errorCouldNotShare(String itemType);

  /// No description provided for @notificationBatchBodyRecipes.
  ///
  /// In sv, this message translates to:
  /// **'{count} nya händelser på dina recept'**
  String notificationBatchBodyRecipes(int count);

  /// No description provided for @notificationBatchBodyFriends.
  ///
  /// In sv, this message translates to:
  /// **'{count} nya aktiviteter från dina vänner'**
  String notificationBatchBodyFriends(int count);

  /// No description provided for @notificationBatchBodyShopping.
  ///
  /// In sv, this message translates to:
  /// **'{count} uppdateringar av dina inköpslistor'**
  String notificationBatchBodyShopping(int count);

  /// No description provided for @notificationBatchBodyCollaboration.
  ///
  /// In sv, this message translates to:
  /// **'{count} nya samarbetsaktiviteter'**
  String notificationBatchBodyCollaboration(int count);

  /// No description provided for @notificationBatchBodyDefault.
  ///
  /// In sv, this message translates to:
  /// **'{count} nya händelser i Butlery'**
  String notificationBatchBodyDefault(int count);

  /// No description provided for @notificationDigestBody.
  ///
  /// In sv, this message translates to:
  /// **'Du har {totalCount} nya aktiviteter: {summary}'**
  String notificationDigestBody(int totalCount, String summary);

  /// No description provided for @uploadStatusUploadingNoPending.
  ///
  /// In sv, this message translates to:
  /// **'Laddar upp {active} bilder ({progress}% klart)'**
  String uploadStatusUploadingNoPending(int active, int progress);

  /// No description provided for @uploadStatusPartialFailure.
  ///
  /// In sv, this message translates to:
  /// **'{completed} av {total} bilder uppladdade, {failed} misslyckades'**
  String uploadStatusPartialFailure(int completed, int total, int failed);

  /// No description provided for @uploadStatusAllFailed.
  ///
  /// In sv, this message translates to:
  /// **'{failed} av {total} bilder misslyckades - tryck för att försöka igen'**
  String uploadStatusAllFailed(int failed, int total);

  /// No description provided for @uploadStatusAllSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Alla {total} bilder uppladdade framgångsrikt'**
  String uploadStatusAllSuccess(int total);

  /// No description provided for @uploadProgressWithTime.
  ///
  /// In sv, this message translates to:
  /// **'{progress}% klart - {time} kvar'**
  String uploadProgressWithTime(int progress, String time);

  /// No description provided for @uploadProgressPercent.
  ///
  /// In sv, this message translates to:
  /// **'{progress}% klart'**
  String uploadProgressPercent(int progress);

  /// No description provided for @uploadComplete.
  ///
  /// In sv, this message translates to:
  /// **'Uppladdning slutförd'**
  String get uploadComplete;

  /// No description provided for @uploadAllSuccessWithTime.
  ///
  /// In sv, this message translates to:
  /// **'Alla bilder uppladdade{time} (100% framgång)'**
  String uploadAllSuccessWithTime(String time);

  /// No description provided for @uploadCompletionOf.
  ///
  /// In sv, this message translates to:
  /// **'{completed} av {total} slutförda'**
  String uploadCompletionOf(int completed, int total);

  /// No description provided for @uploadFailureCount.
  ///
  /// In sv, this message translates to:
  /// **', {failed} misslyckades'**
  String uploadFailureCount(int failed);

  /// No description provided for @uploadSuccessRate.
  ///
  /// In sv, this message translates to:
  /// **' ({rate}% framgång)'**
  String uploadSuccessRate(int rate);

  /// No description provided for @uploadPreparing.
  ///
  /// In sv, this message translates to:
  /// **'Förbereder uppladdning...'**
  String get uploadPreparing;

  /// No description provided for @errorNoImageSelected.
  ///
  /// In sv, this message translates to:
  /// **'Ingen bild vald'**
  String get errorNoImageSelected;

  /// No description provided for @errorImageFormatUnsupported.
  ///
  /// In sv, this message translates to:
  /// **'Bildformatet stöds inte. Använd JPEG eller PNG-format.'**
  String get errorImageFormatUnsupported;

  /// No description provided for @errorImageTooLarge.
  ///
  /// In sv, this message translates to:
  /// **'Bilden är för stor ({size} MB). Använd en mindre bild eller komprimera den.'**
  String errorImageTooLarge(String size);

  /// No description provided for @errorImageQualityTooLow.
  ///
  /// In sv, this message translates to:
  /// **'Bildkvaliteten är för låg för OCR ({quality}%).'**
  String errorImageQualityTooLow(int quality);

  /// No description provided for @errorOcrServicesUnavailable.
  ///
  /// In sv, this message translates to:
  /// **'OCR-tjänsterna är tillfälligt otillgängliga. Försök igen om några minuter.'**
  String get errorOcrServicesUnavailable;

  /// No description provided for @errorNoTextExtracted.
  ///
  /// In sv, this message translates to:
  /// **'Ingen text kunde extraheras från bilden.'**
  String get errorNoTextExtracted;

  /// No description provided for @labelImprovementSuggestions.
  ///
  /// In sv, this message translates to:
  /// **'Förbättringsförslag:'**
  String get labelImprovementSuggestions;

  /// No description provided for @ocrQualityTips.
  ///
  /// In sv, this message translates to:
  /// **'Tips för bättre resultat:\n• Se till att bilden är välbelyst och skarp\n• Undvik skuggor och reflektioner\n• Håll kameran rakt mot texten'**
  String get ocrQualityTips;

  /// No description provided for @ocrRetryOrManual.
  ///
  /// In sv, this message translates to:
  /// **'Du kan försöka igen med en ny bild eller fortsätta med manuell inmatning.'**
  String get ocrRetryOrManual;

  /// No description provided for @errorAiEnhancementFailed.
  ///
  /// In sv, this message translates to:
  /// **'AI-förbättring misslyckades.'**
  String get errorAiEnhancementFailed;

  /// No description provided for @errorCouldNotCreateRealtimeRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa realtidsrecept: {error}'**
  String errorCouldNotCreateRealtimeRecipe(String error);

  /// No description provided for @errorCouldNotWatchRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte starta watching av recept: {error}'**
  String errorCouldNotWatchRecipe(String error);

  /// No description provided for @errorCouldNotPerformOperation.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte {operation}: {error}'**
  String errorCouldNotPerformOperation(String operation, String error);

  /// No description provided for @errorCouldNotDeleteRealtimeRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort realtidsrecept: {error}'**
  String errorCouldNotDeleteRealtimeRecipe(String error);

  /// No description provided for @errorCouldNotCreateRealtimeMenu.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skapa realtidsmeny: {error}'**
  String errorCouldNotCreateRealtimeMenu(String error);

  /// No description provided for @errorCouldNotWatchMenu.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte starta watching av meny: {error}'**
  String errorCouldNotWatchMenu(String error);

  /// No description provided for @errorCouldNotDeleteRealtimeMenu.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort realtidsmeny: {error}'**
  String errorCouldNotDeleteRealtimeMenu(String error);

  /// No description provided for @ocrImageTooLarge.
  ///
  /// In sv, this message translates to:
  /// **'Bilden är för stor'**
  String get ocrImageTooLarge;

  /// No description provided for @ocrCompressImage.
  ///
  /// In sv, this message translates to:
  /// **'Komprimera bilden'**
  String get ocrCompressImage;

  /// No description provided for @ocrImageTooSmall.
  ///
  /// In sv, this message translates to:
  /// **'Bilden är för liten'**
  String get ocrImageTooSmall;

  /// No description provided for @ocrUseHigherResolution.
  ///
  /// In sv, this message translates to:
  /// **'Använd högre upplösning'**
  String get ocrUseHigherResolution;

  /// No description provided for @ocrImageFormatNotOptimal.
  ///
  /// In sv, this message translates to:
  /// **'Bildformat stöds inte optimalt'**
  String get ocrImageFormatNotOptimal;

  /// No description provided for @ocrUseJpegOrPng.
  ///
  /// In sv, this message translates to:
  /// **'Använd JPEG eller PNG'**
  String get ocrUseJpegOrPng;

  /// No description provided for @syncErrorParsingResource.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid parsing av resurs'**
  String get syncErrorParsingResource;

  /// No description provided for @syncErrorWatchingResource.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid watching av resurs {resourceId}'**
  String syncErrorWatchingResource(String resourceId);

  /// No description provided for @notificationActionAccept.
  ///
  /// In sv, this message translates to:
  /// **'Acceptera'**
  String get notificationActionAccept;

  /// No description provided for @notificationActionDecline.
  ///
  /// In sv, this message translates to:
  /// **'Avvisa'**
  String get notificationActionDecline;

  /// No description provided for @notificationActionViewRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Visa recept'**
  String get notificationActionViewRecipe;

  /// No description provided for @notificationActionJoin.
  ///
  /// In sv, this message translates to:
  /// **'Gå med'**
  String get notificationActionJoin;

  /// No description provided for @fcmChannelSocialTitle.
  ///
  /// In sv, this message translates to:
  /// **'Sociala notiser'**
  String get fcmChannelSocialTitle;

  /// No description provided for @fcmChannelSocialDescription.
  ///
  /// In sv, this message translates to:
  /// **'Vänförfrågningar, delningar och kommentarer'**
  String get fcmChannelSocialDescription;

  /// No description provided for @fcmChannelMessagingTitle.
  ///
  /// In sv, this message translates to:
  /// **'Meddelanden'**
  String get fcmChannelMessagingTitle;

  /// No description provided for @fcmChannelMessagingDescription.
  ///
  /// In sv, this message translates to:
  /// **'Chattmeddelanden från vänner'**
  String get fcmChannelMessagingDescription;

  /// No description provided for @tagValidationEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Taggnamn kan inte vara tomt'**
  String get tagValidationEmpty;

  /// No description provided for @tagValidationTooShort.
  ///
  /// In sv, this message translates to:
  /// **'Taggnamn måste vara minst 2 tecken'**
  String get tagValidationTooShort;

  /// No description provided for @tagValidationTooLong.
  ///
  /// In sv, this message translates to:
  /// **'Taggnamn får vara max 50 tecken'**
  String get tagValidationTooLong;

  /// No description provided for @tagValidationReserved.
  ///
  /// In sv, this message translates to:
  /// **'Detta namn är reserverat för systemtaggar'**
  String get tagValidationReserved;

  /// No description provided for @menuAttributionText.
  ///
  /// In sv, this message translates to:
  /// **'Inspirerat av meny från {displayName}'**
  String menuAttributionText(String displayName);

  /// No description provided for @llmEnhancementNotEnoughData.
  ///
  /// In sv, this message translates to:
  /// **'Inte tillräckligt med data för AI-förbättring.'**
  String get llmEnhancementNotEnoughData;

  /// No description provided for @realtimeIngredientEmptyError.
  ///
  /// In sv, this message translates to:
  /// **'Ingrediens kan inte vara tom'**
  String get realtimeIngredientEmptyError;

  /// No description provided for @realtimeIngredientInvalidIndex.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt ingrediens-index'**
  String get realtimeIngredientInvalidIndex;

  /// No description provided for @realtimeInstructionEmptyError.
  ///
  /// In sv, this message translates to:
  /// **'Instruktion kan inte vara tom'**
  String get realtimeInstructionEmptyError;

  /// No description provided for @realtimeInstructionInvalidIndex.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt instruktions-index'**
  String get realtimeInstructionInvalidIndex;

  /// No description provided for @menuDefaultTitle.
  ///
  /// In sv, this message translates to:
  /// **'Meny från {displayName}'**
  String menuDefaultTitle(String displayName);

  /// No description provided for @menuShareGroupFallback.
  ///
  /// In sv, this message translates to:
  /// **'Grupp'**
  String get menuShareGroupFallback;

  /// No description provided for @menuShareGroupTitle.
  ///
  /// In sv, this message translates to:
  /// **'Meny för {categoryName}'**
  String menuShareGroupTitle(String categoryName);

  /// No description provided for @menuTitleEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Tom meny'**
  String get menuTitleEmpty;

  /// No description provided for @menuTitleSingleCategory.
  ///
  /// In sv, this message translates to:
  /// **'{category} meny ({count} recept)'**
  String menuTitleSingleCategory(String category, int count);

  /// No description provided for @menuTitleMultiCategory.
  ///
  /// In sv, this message translates to:
  /// **'Veckomeny med {categories} ({count} recept)'**
  String menuTitleMultiCategory(String categories, int count);

  /// No description provided for @recipeAttributionText.
  ///
  /// In sv, this message translates to:
  /// **'Inspirerat av recept från {displayName}'**
  String recipeAttributionText(String displayName);

  /// No description provided for @tiktokOriginalText.
  ///
  /// In sv, this message translates to:
  /// **'Originaltext från TikTok:'**
  String get tiktokOriginalText;

  /// No description provided for @tiktokIdentifiedIngredients.
  ///
  /// In sv, this message translates to:
  /// **'Identifierade ingredienser:'**
  String get tiktokIdentifiedIngredients;

  /// No description provided for @groupShareWarningManyGroups.
  ///
  /// In sv, this message translates to:
  /// **'Delning till många grupper ({count}) kan ta lång tid'**
  String groupShareWarningManyGroups(int count);

  /// No description provided for @groupShareWarningManyItems.
  ///
  /// In sv, this message translates to:
  /// **'Delning av mycket innehåll ({count} objekt) kan ta lång tid'**
  String groupShareWarningManyItems(int count);

  /// No description provided for @groupShareWarningLargeOperation.
  ///
  /// In sv, this message translates to:
  /// **'Stor operation ({count} delningar) - överväg att dela upp den'**
  String groupShareWarningLargeOperation(int count);

  /// No description provided for @textImportSourceUrl.
  ///
  /// In sv, this message translates to:
  /// **'Importerat från text'**
  String get textImportSourceUrl;

  /// No description provided for @assistedImportSelectInstructionsError.
  ///
  /// In sv, this message translates to:
  /// **'Välj minst en instruktion'**
  String get assistedImportSelectInstructionsError;

  /// No description provided for @assistedImportEnterRecipeName.
  ///
  /// In sv, this message translates to:
  /// **'Ange ett receptnamn'**
  String get assistedImportEnterRecipeName;

  /// No description provided for @assistedImportAddIngredientError.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till minst en ingrediens'**
  String get assistedImportAddIngredientError;

  /// No description provided for @assistedImportAddInstructionError.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till minst en instruktion'**
  String get assistedImportAddInstructionError;

  /// No description provided for @formValidationIngredientRequired.
  ///
  /// In sv, this message translates to:
  /// **'Ingrediens krävs'**
  String get formValidationIngredientRequired;

  /// No description provided for @formValidationIngredientTooLong.
  ///
  /// In sv, this message translates to:
  /// **'Ingrediens för lång (max 200 tecken)'**
  String get formValidationIngredientTooLong;

  /// No description provided for @formValidationInstructionRequired.
  ///
  /// In sv, this message translates to:
  /// **'Instruktion krävs'**
  String get formValidationInstructionRequired;

  /// No description provided for @formValidationInstructionTooLong.
  ///
  /// In sv, this message translates to:
  /// **'Instruktion för lång (max 500 tecken)'**
  String get formValidationInstructionTooLong;

  /// No description provided for @formValidationTagTooLong.
  ///
  /// In sv, this message translates to:
  /// **'Tagg för lång (max 50 tecken)'**
  String get formValidationTagTooLong;

  /// No description provided for @formValidationTagNoCommas.
  ///
  /// In sv, this message translates to:
  /// **'Taggar får inte innehålla kommatecken'**
  String get formValidationTagNoCommas;

  /// No description provided for @shoppingItemMarkedComplete.
  ///
  /// In sv, this message translates to:
  /// **'Markerade som klar'**
  String get shoppingItemMarkedComplete;

  /// No description provided for @shoppingItemMarkedIncomplete.
  ///
  /// In sv, this message translates to:
  /// **'Markerade som ej klar'**
  String get shoppingItemMarkedIncomplete;

  /// No description provided for @menuSuggestionVegetarian.
  ///
  /// In sv, this message translates to:
  /// **'Vegetarisk veckomeny för 2 personer'**
  String get menuSuggestionVegetarian;

  /// No description provided for @menuSuggestionQuickDinners.
  ///
  /// In sv, this message translates to:
  /// **'Snabba middagar för hela veckan'**
  String get menuSuggestionQuickDinners;

  /// No description provided for @menuSuggestionMeatFish.
  ///
  /// In sv, this message translates to:
  /// **'Kött och fisk varierad meny'**
  String get menuSuggestionMeatFish;

  /// No description provided for @menuSuggestionFamily.
  ///
  /// In sv, this message translates to:
  /// **'Familjevänlig veckomeny'**
  String get menuSuggestionFamily;

  /// No description provided for @menuSuggestionHealthy.
  ///
  /// In sv, this message translates to:
  /// **'Hälsosam och näringsrik meny'**
  String get menuSuggestionHealthy;

  /// No description provided for @menuSuggestionBudget.
  ///
  /// In sv, this message translates to:
  /// **'Budgetvänlig veckomeny'**
  String get menuSuggestionBudget;

  /// No description provided for @menuSuggestionItalian.
  ///
  /// In sv, this message translates to:
  /// **'Italiensk temameny'**
  String get menuSuggestionItalian;

  /// No description provided for @menuSuggestionAsian.
  ///
  /// In sv, this message translates to:
  /// **'Asiatisk inspirerad veckomeny'**
  String get menuSuggestionAsian;

  /// No description provided for @recipeAutoTitleWithIngredient.
  ///
  /// In sv, this message translates to:
  /// **'Recept med {ingredient}'**
  String recipeAutoTitleWithIngredient(String ingredient);

  /// No description provided for @recipeAutoTitleUntitled.
  ///
  /// In sv, this message translates to:
  /// **'Namnlöst recept'**
  String get recipeAutoTitleUntitled;

  /// No description provided for @importPhaseFetching.
  ///
  /// In sv, this message translates to:
  /// **'Hämtar innehåll...'**
  String get importPhaseFetching;

  /// No description provided for @importPhaseAnalyzing.
  ///
  /// In sv, this message translates to:
  /// **'Analyserar recept...'**
  String get importPhaseAnalyzing;

  /// No description provided for @importPhaseCreating.
  ///
  /// In sv, this message translates to:
  /// **'Skapar recept...'**
  String get importPhaseCreating;

  /// No description provided for @importPhaseComplete.
  ///
  /// In sv, this message translates to:
  /// **'Klar!'**
  String get importPhaseComplete;

  /// No description provided for @importPhaseNeedsHelp.
  ///
  /// In sv, this message translates to:
  /// **'Behöver din hjälp'**
  String get importPhaseNeedsHelp;

  /// No description provided for @importPhaseError.
  ///
  /// In sv, this message translates to:
  /// **'Ett fel uppstod'**
  String get importPhaseError;

  /// No description provided for @shoppingSharingSummary.
  ///
  /// In sv, this message translates to:
  /// **'Dela med: {friendNames}'**
  String shoppingSharingSummary(String friendNames);

  /// No description provided for @imageUploadTooLarge.
  ///
  /// In sv, this message translates to:
  /// **'Bilden är för stor (max {maxSize}MB)'**
  String imageUploadTooLarge(String maxSize);

  /// No description provided for @shareMessageRecipeWithTitle.
  ///
  /// In sv, this message translates to:
  /// **'Kolla in detta recept: \"{title}\"! 👩‍🍳'**
  String shareMessageRecipeWithTitle(String title);

  /// No description provided for @shareMessageRecipeDefault.
  ///
  /// In sv, this message translates to:
  /// **'Jag hittade ett fantastiskt recept som jag ville dela med dig! 👩‍🍳'**
  String get shareMessageRecipeDefault;

  /// No description provided for @shareMessageMenuWithTitle.
  ///
  /// In sv, this message translates to:
  /// **'Här är min veckomeny: \"{title}\" 📋'**
  String shareMessageMenuWithTitle(String title);

  /// No description provided for @shareMessageMenuDefault.
  ///
  /// In sv, this message translates to:
  /// **'Här är min veckomeny som kanske kan inspirera dig! 📋'**
  String get shareMessageMenuDefault;

  /// No description provided for @shareMessageShoppingListWithTitle.
  ///
  /// In sv, this message translates to:
  /// **'Vill du hjälpa mig med inköpslistan: \"{title}\"? 🛒'**
  String shareMessageShoppingListWithTitle(String title);

  /// No description provided for @shareMessageShoppingListDefault.
  ///
  /// In sv, this message translates to:
  /// **'Vill du hjälpa mig med inköpen denna vecka? 🛒'**
  String get shareMessageShoppingListDefault;

  /// No description provided for @textImportSuggestionIngredients.
  ///
  /// In sv, this message translates to:
  /// **'Inkludera ingredienslista för bättre tolkning'**
  String get textImportSuggestionIngredients;

  /// No description provided for @textImportSuggestionInstructions.
  ///
  /// In sv, this message translates to:
  /// **'Inkludera tillagningsinstruktioner eller steg'**
  String get textImportSuggestionInstructions;

  /// No description provided for @textImportSuggestionTime.
  ///
  /// In sv, this message translates to:
  /// **'Inkludera tillagningstid om tillgänglig'**
  String get textImportSuggestionTime;

  /// No description provided for @textImportSuggestionPortions.
  ///
  /// In sv, this message translates to:
  /// **'Inkludera antal portioner om känt'**
  String get textImportSuggestionPortions;

  /// No description provided for @textImportSuggestionLooksGood.
  ///
  /// In sv, this message translates to:
  /// **'Texten ser bra ut för recepttolkning'**
  String get textImportSuggestionLooksGood;

  /// No description provided for @recipeFormPermissionsError.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid laddning av permissions'**
  String get recipeFormPermissionsError;

  /// No description provided for @createSharedListError.
  ///
  /// In sv, this message translates to:
  /// **'Fel vid skapande av delad lista: {error}'**
  String createSharedListError(String error);

  /// No description provided for @userStatusOnline.
  ///
  /// In sv, this message translates to:
  /// **'Online'**
  String get userStatusOnline;

  /// No description provided for @userStatusJustActive.
  ///
  /// In sv, this message translates to:
  /// **'Aktiv nyss'**
  String get userStatusJustActive;

  /// No description provided for @userStatusActiveMinutesAgo.
  ///
  /// In sv, this message translates to:
  /// **'Aktiv för {minutes} min sedan'**
  String userStatusActiveMinutesAgo(int minutes);

  /// No description provided for @userStatusActiveHoursAgo.
  ///
  /// In sv, this message translates to:
  /// **'Aktiv för {hours} tim sedan'**
  String userStatusActiveHoursAgo(int hours);

  /// No description provided for @userStatusActiveDaysAgo.
  ///
  /// In sv, this message translates to:
  /// **'Aktiv för {days} dagar sedan'**
  String userStatusActiveDaysAgo(int days);

  /// No description provided for @userStatusActiveWeeksAgo.
  ///
  /// In sv, this message translates to:
  /// **'Aktiv för {weeks} veckor sedan'**
  String userStatusActiveWeeksAgo(int weeks);

  /// No description provided for @recipeCookTimeMinutes.
  ///
  /// In sv, this message translates to:
  /// **'{minutes} minuter'**
  String recipeCookTimeMinutes(int minutes);

  /// No description provided for @recipeLastCookedToday.
  ///
  /// In sv, this message translates to:
  /// **'Tillagad idag'**
  String get recipeLastCookedToday;

  /// No description provided for @recipeLastCookedYesterday.
  ///
  /// In sv, this message translates to:
  /// **'Tillagad igår'**
  String get recipeLastCookedYesterday;

  /// No description provided for @recipeLastCookedDaysAgo.
  ///
  /// In sv, this message translates to:
  /// **'Tillagad för {days} dagar sedan'**
  String recipeLastCookedDaysAgo(int days);

  /// No description provided for @messageSharedRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Delade ett recept: {title}'**
  String messageSharedRecipe(String title);

  /// No description provided for @messageSharedMenu.
  ///
  /// In sv, this message translates to:
  /// **'Delade en meny: {title}'**
  String messageSharedMenu(String title);

  /// No description provided for @messageSharedShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Delade en inköpslista: {title}'**
  String messageSharedShoppingList(String title);

  /// No description provided for @conversationNoMessagesYet.
  ///
  /// In sv, this message translates to:
  /// **'Inga meddelanden än'**
  String get conversationNoMessagesYet;

  /// No description provided for @sharedRecipeAttributionText.
  ///
  /// In sv, this message translates to:
  /// **'Inspirerat av recept från {displayName}'**
  String sharedRecipeAttributionText(String displayName);

  /// No description provided for @realtimeRecipeCopyTitle.
  ///
  /// In sv, this message translates to:
  /// **'Kopia av {title}'**
  String realtimeRecipeCopyTitle(String title);

  /// No description provided for @realtimeRecipeSharedFrom.
  ///
  /// In sv, this message translates to:
  /// **'Delat från {displayName}'**
  String realtimeRecipeSharedFrom(String displayName);

  /// No description provided for @friendCategoryDefaultFriends.
  ///
  /// In sv, this message translates to:
  /// **'Vänner'**
  String get friendCategoryDefaultFriends;

  /// No description provided for @friendCategoryDefaultFriendsDesc.
  ///
  /// In sv, this message translates to:
  /// **'Nära vänner'**
  String get friendCategoryDefaultFriendsDesc;

  /// No description provided for @friendCategoryDefaultNeighbors.
  ///
  /// In sv, this message translates to:
  /// **'Grannar'**
  String get friendCategoryDefaultNeighbors;

  /// No description provided for @friendCategoryDefaultNeighborsDesc.
  ///
  /// In sv, this message translates to:
  /// **'Grannar och lokalområdet'**
  String get friendCategoryDefaultNeighborsDesc;

  /// No description provided for @friendCategoryDefaultWork.
  ///
  /// In sv, this message translates to:
  /// **'Jobbet'**
  String get friendCategoryDefaultWork;

  /// No description provided for @friendCategoryDefaultWorkDesc.
  ///
  /// In sv, this message translates to:
  /// **'Kollegor och arbetskompisar'**
  String get friendCategoryDefaultWorkDesc;

  /// No description provided for @friendCategoryDefaultFoodGroup.
  ///
  /// In sv, this message translates to:
  /// **'Matgrupp'**
  String get friendCategoryDefaultFoodGroup;

  /// No description provided for @friendCategoryDefaultFoodGroupDesc.
  ///
  /// In sv, this message translates to:
  /// **'Personer som älskar att laga mat'**
  String get friendCategoryDefaultFoodGroupDesc;

  /// No description provided for @friendCategoryDefaultFamily.
  ///
  /// In sv, this message translates to:
  /// **'Familj'**
  String get friendCategoryDefaultFamily;

  /// No description provided for @friendCategoryDefaultFamilyDesc.
  ///
  /// In sv, this message translates to:
  /// **'Familjemedlemmar'**
  String get friendCategoryDefaultFamilyDesc;

  /// No description provided for @friendSummaryNoFriends.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner'**
  String get friendSummaryNoFriends;

  /// No description provided for @friendSummaryOneFriend.
  ///
  /// In sv, this message translates to:
  /// **'1 vän'**
  String get friendSummaryOneFriend;

  /// No description provided for @friendSummaryCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} vänner'**
  String friendSummaryCount(int count);

  /// No description provided for @shoppingListSharedBy.
  ///
  /// In sv, this message translates to:
  /// **'Delad av {displayName}'**
  String shoppingListSharedBy(String displayName);

  /// No description provided for @shoppingListOriginallySharedBy.
  ///
  /// In sv, this message translates to:
  /// **'Ursprungligen delad av {displayName}'**
  String shoppingListOriginallySharedBy(String displayName);

  /// No description provided for @collaborationNotAllowed.
  ///
  /// In sv, this message translates to:
  /// **'Ingen kollaboration tillåten'**
  String get collaborationNotAllowed;

  /// No description provided for @collaborationReady.
  ///
  /// In sv, this message translates to:
  /// **'Redo för kollaboration'**
  String get collaborationReady;

  /// No description provided for @collaborationVersionCreated.
  ///
  /// In sv, this message translates to:
  /// **'Kollaborativ version skapad'**
  String get collaborationVersionCreated;

  /// No description provided for @collaborationOneActive.
  ///
  /// In sv, this message translates to:
  /// **'1 aktiv kollaboratör'**
  String get collaborationOneActive;

  /// No description provided for @collaborationMultipleActive.
  ///
  /// In sv, this message translates to:
  /// **'{count} aktiva kollaboratörer'**
  String collaborationMultipleActive(int count);

  /// No description provided for @recipeCopiedFrom.
  ///
  /// In sv, this message translates to:
  /// **'Kopierat från: {title}'**
  String recipeCopiedFrom(String title);

  /// No description provided for @statusEmptyList.
  ///
  /// In sv, this message translates to:
  /// **'Tom lista'**
  String get statusEmptyList;

  /// No description provided for @statusCompleted.
  ///
  /// In sv, this message translates to:
  /// **'Klar'**
  String get statusCompleted;

  /// No description provided for @statusInProgress.
  ///
  /// In sv, this message translates to:
  /// **'Pågående'**
  String get statusInProgress;

  /// No description provided for @statusNoActivity.
  ///
  /// In sv, this message translates to:
  /// **'Ingen aktivitet'**
  String get statusNoActivity;

  /// No description provided for @statusPurchased.
  ///
  /// In sv, this message translates to:
  /// **'Inhandlad'**
  String get statusPurchased;

  /// No description provided for @timeJustNow.
  ///
  /// In sv, this message translates to:
  /// **'just nu'**
  String get timeJustNow;

  /// No description provided for @timeMinutesAgo.
  ///
  /// In sv, this message translates to:
  /// **'{minutes}m sedan'**
  String timeMinutesAgo(int minutes);

  /// No description provided for @timeHoursAgo.
  ///
  /// In sv, this message translates to:
  /// **'{hours}h sedan'**
  String timeHoursAgo(int hours);

  /// No description provided for @timeMinutesAgoLong.
  ///
  /// In sv, this message translates to:
  /// **'{minutes} min sedan'**
  String timeMinutesAgoLong(int minutes);

  /// No description provided for @timeHoursAgoLong.
  ///
  /// In sv, this message translates to:
  /// **'{hours} tim sedan'**
  String timeHoursAgoLong(int hours);

  /// No description provided for @timeDaysAgoLong.
  ///
  /// In sv, this message translates to:
  /// **'{days} dagar sedan'**
  String timeDaysAgoLong(int days);

  /// No description provided for @timeWeeksAgo.
  ///
  /// In sv, this message translates to:
  /// **'{weeks} veckor sedan'**
  String timeWeeksAgo(int weeks);

  /// No description provided for @timeNow.
  ///
  /// In sv, this message translates to:
  /// **'Nu'**
  String get timeNow;

  /// No description provided for @dateTomorrow.
  ///
  /// In sv, this message translates to:
  /// **'Imorgon'**
  String get dateTomorrow;

  /// No description provided for @dateNoDate.
  ///
  /// In sv, this message translates to:
  /// **'Inget datum'**
  String get dateNoDate;

  /// No description provided for @dateDaysAhead.
  ///
  /// In sv, this message translates to:
  /// **'{days} dagar framåt'**
  String dateDaysAhead(int days);

  /// No description provided for @labelMemberCount.
  ///
  /// In sv, this message translates to:
  /// **'{count, plural, =1{1 medlem} other{{count} medlemmar}}'**
  String labelMemberCount(int count);

  /// No description provided for @labelParticipantFallback.
  ///
  /// In sv, this message translates to:
  /// **'Deltagare'**
  String get labelParticipantFallback;

  /// No description provided for @labelRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Recept'**
  String get labelRecipes;

  /// No description provided for @labelMenus.
  ///
  /// In sv, this message translates to:
  /// **'Menyer'**
  String get labelMenus;

  /// No description provided for @labelShopping.
  ///
  /// In sv, this message translates to:
  /// **'Handla'**
  String get labelShopping;

  /// No description provided for @labelCollaborativeMenu.
  ///
  /// In sv, this message translates to:
  /// **'Kollaborativ meny'**
  String get labelCollaborativeMenu;

  /// No description provided for @errorInvalidUrlFormat.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt URL-format'**
  String get errorInvalidUrlFormat;

  /// No description provided for @errorUrlMissingScheme.
  ///
  /// In sv, this message translates to:
  /// **'URL måste inkludera http:// eller https://'**
  String get errorUrlMissingScheme;

  /// No description provided for @errorUrlUnsupportedScheme.
  ///
  /// In sv, this message translates to:
  /// **'Endast HTTP- och HTTPS-URL:er stöds'**
  String get errorUrlUnsupportedScheme;

  /// No description provided for @errorUrlMissingDomain.
  ///
  /// In sv, this message translates to:
  /// **'URL måste inkludera ett domännamn'**
  String get errorUrlMissingDomain;

  /// No description provided for @errorInvalidCategoryName.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltigt kategorinamn: {name}'**
  String errorInvalidCategoryName(String name);

  /// No description provided for @platformYouTube.
  ///
  /// In sv, this message translates to:
  /// **'YouTube-video'**
  String get platformYouTube;

  /// No description provided for @platformTikTok.
  ///
  /// In sv, this message translates to:
  /// **'TikTok-video'**
  String get platformTikTok;

  /// No description provided for @platformInstagram.
  ///
  /// In sv, this message translates to:
  /// **'Instagram-inlägg'**
  String get platformInstagram;

  /// No description provided for @platformWebsite.
  ///
  /// In sv, this message translates to:
  /// **'Webbsida'**
  String get platformWebsite;

  /// No description provided for @platformPastedText.
  ///
  /// In sv, this message translates to:
  /// **'Inklistrad text'**
  String get platformPastedText;

  /// No description provided for @selectionNoFriendsSelected.
  ///
  /// In sv, this message translates to:
  /// **'Inga vänner valda'**
  String get selectionNoFriendsSelected;

  /// No description provided for @selectionFriendsSelected.
  ///
  /// In sv, this message translates to:
  /// **'{count, plural, =1{1 vän vald} other{{count} vänner valda}}'**
  String selectionFriendsSelected(int count);

  /// No description provided for @selectionNoRecipesSelected.
  ///
  /// In sv, this message translates to:
  /// **'Inga recept valda'**
  String get selectionNoRecipesSelected;

  /// No description provided for @selectionRecipesSelected.
  ///
  /// In sv, this message translates to:
  /// **'{count, plural, =1{1 recept valt} other{{count} recept valda}}'**
  String selectionRecipesSelected(int count);

  /// No description provided for @buttonCreating.
  ///
  /// In sv, this message translates to:
  /// **'Skapar...'**
  String get buttonCreating;

  /// No description provided for @buttonCreateAndShare.
  ///
  /// In sv, this message translates to:
  /// **'Skapa & Dela'**
  String get buttonCreateAndShare;

  /// No description provided for @analysisNoContentExtracted.
  ///
  /// In sv, this message translates to:
  /// **'Inget innehåll extraherat'**
  String get analysisNoContentExtracted;

  /// No description provided for @analysisContainsIngredients.
  ///
  /// In sv, this message translates to:
  /// **'Innehåller ingredienser'**
  String get analysisContainsIngredients;

  /// No description provided for @analysisNoIngredientsFound.
  ///
  /// In sv, this message translates to:
  /// **'Ingen ingredienssektion hittades'**
  String get analysisNoIngredientsFound;

  /// No description provided for @analysisContainsInstructions.
  ///
  /// In sv, this message translates to:
  /// **'Innehåller instruktioner'**
  String get analysisContainsInstructions;

  /// No description provided for @analysisNoInstructionsFound.
  ///
  /// In sv, this message translates to:
  /// **'Inga instruktioner hittades'**
  String get analysisNoInstructionsFound;

  /// No description provided for @labelNoCategories.
  ///
  /// In sv, this message translates to:
  /// **'Inga kategorier'**
  String get labelNoCategories;

  /// No description provided for @labelGroup.
  ///
  /// In sv, this message translates to:
  /// **'Grupp'**
  String get labelGroup;

  /// No description provided for @labelYou.
  ///
  /// In sv, this message translates to:
  /// **'Du'**
  String get labelYou;

  /// No description provided for @validationSelectIngredient.
  ///
  /// In sv, this message translates to:
  /// **'Välj minst en ingrediens'**
  String get validationSelectIngredient;

  /// No description provided for @statusListLoaded.
  ///
  /// In sv, this message translates to:
  /// **'Lista laddad'**
  String get statusListLoaded;

  /// No description provided for @errorCouldNotLoadListDetail.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ladda lista: {detail}'**
  String errorCouldNotLoadListDetail(String detail);

  /// No description provided for @labelUntitledMenu.
  ///
  /// In sv, this message translates to:
  /// **'Namnlös meny'**
  String get labelUntitledMenu;

  /// No description provided for @labelUntitledList.
  ///
  /// In sv, this message translates to:
  /// **'Namnlös lista'**
  String get labelUntitledList;

  /// No description provided for @labelUntitledRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Namnlöst recept'**
  String get labelUntitledRecipe;

  /// No description provided for @labelUnknownContent.
  ///
  /// In sv, this message translates to:
  /// **'Okänt innehåll'**
  String get labelUnknownContent;

  /// No description provided for @analysisContainsTimeInfo.
  ///
  /// In sv, this message translates to:
  /// **'Innehåller tidsinformation'**
  String get analysisContainsTimeInfo;

  /// No description provided for @analysisContainsPortionInfo.
  ///
  /// In sv, this message translates to:
  /// **'Innehåller portionsinformation'**
  String get analysisContainsPortionInfo;

  /// No description provided for @analysisGoodContentLength.
  ///
  /// In sv, this message translates to:
  /// **'Bra innehållslängd'**
  String get analysisGoodContentLength;

  /// No description provided for @analysisContentTooShort.
  ///
  /// In sv, this message translates to:
  /// **'Innehållet verkar för kort'**
  String get analysisContentTooShort;

  /// No description provided for @analysisContainsRecipeKeywords.
  ///
  /// In sv, this message translates to:
  /// **'Innehåller receptnyckelord'**
  String get analysisContainsRecipeKeywords;

  /// No description provided for @hintPasteOrTypeRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Klistra in eller skriv recepttext för att komma igång'**
  String get hintPasteOrTypeRecipe;

  /// No description provided for @errorFriendAlreadyHasAccess.
  ///
  /// In sv, this message translates to:
  /// **'Den valda vännen har redan tillgång till listan'**
  String get errorFriendAlreadyHasAccess;

  /// No description provided for @errorAllFriendsAlreadyHaveAccess.
  ///
  /// In sv, this message translates to:
  /// **'Alla valda vänner har redan tillgång till listan'**
  String get errorAllFriendsAlreadyHaveAccess;

  /// No description provided for @shareInvitationsSentWithSkipped.
  ///
  /// In sv, this message translates to:
  /// **'{invitedCount} inbjudningar skickade. {skippedCount} vänner hoppades över (har redan tillgång).'**
  String shareInvitationsSentWithSkipped(int invitedCount, int skippedCount);

  /// No description provided for @errorCouldNotSendInvitations.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skicka inbjudningar'**
  String get errorCouldNotSendInvitations;

  /// No description provided for @shareDefaultShoppingListMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill dela denna inköpslista med dig!'**
  String get shareDefaultShoppingListMessage;

  /// No description provided for @shoppingListAllDone.
  ///
  /// In sv, this message translates to:
  /// **'Alla {count} artiklar klara'**
  String shoppingListAllDone(int count);

  /// No description provided for @shoppingListItemsToBuy.
  ///
  /// In sv, this message translates to:
  /// **'{count} artiklar att köpa'**
  String shoppingListItemsToBuy(int count);

  /// No description provided for @errorDailyQuotaReached.
  ///
  /// In sv, this message translates to:
  /// **'Dagskvot uppnådd'**
  String get errorDailyQuotaReached;

  /// No description provided for @errorGenericOccurred.
  ///
  /// In sv, this message translates to:
  /// **'Ett fel uppstod'**
  String get errorGenericOccurred;

  /// No description provided for @fcmChannelGeneralTitle.
  ///
  /// In sv, this message translates to:
  /// **'Allmänna notiser'**
  String get fcmChannelGeneralTitle;

  /// No description provided for @fcmChannelGeneralDescription.
  ///
  /// In sv, this message translates to:
  /// **'Generella notiser från Butlery'**
  String get fcmChannelGeneralDescription;

  /// No description provided for @timeAgoNow.
  ///
  /// In sv, this message translates to:
  /// **'Nu'**
  String get timeAgoNow;

  /// No description provided for @timeAgoMinutesAbbr.
  ///
  /// In sv, this message translates to:
  /// **'{count} min sedan'**
  String timeAgoMinutesAbbr(int count);

  /// No description provided for @timeAgoHoursAbbr.
  ///
  /// In sv, this message translates to:
  /// **'{count} tim sedan'**
  String timeAgoHoursAbbr(int count);

  /// No description provided for @timeAgoDays.
  ///
  /// In sv, this message translates to:
  /// **'{count} dagar sedan'**
  String timeAgoDays(int count);

  /// No description provided for @timeAgoWeeks.
  ///
  /// In sv, this message translates to:
  /// **'{count} veckor sedan'**
  String timeAgoWeeks(int count);

  /// No description provided for @timeAgoJustNow.
  ///
  /// In sv, this message translates to:
  /// **'Nyss'**
  String get timeAgoJustNow;

  /// No description provided for @timeAgoMinutesFull.
  ///
  /// In sv, this message translates to:
  /// **'{count} minuter sedan'**
  String timeAgoMinutesFull(int count);

  /// No description provided for @timeAgoHoursFull.
  ///
  /// In sv, this message translates to:
  /// **'{count} timmar sedan'**
  String timeAgoHoursFull(int count);

  /// No description provided for @timeCompactMinutes.
  ///
  /// In sv, this message translates to:
  /// **'{count}m'**
  String timeCompactMinutes(int count);

  /// No description provided for @timeCompactHours.
  ///
  /// In sv, this message translates to:
  /// **'{count}h'**
  String timeCompactHours(int count);

  /// No description provided for @timeCompactDays.
  ///
  /// In sv, this message translates to:
  /// **'{count}d'**
  String timeCompactDays(int count);

  /// No description provided for @expiresExpired.
  ///
  /// In sv, this message translates to:
  /// **'Utgången'**
  String get expiresExpired;

  /// No description provided for @expiresDaysRemaining.
  ///
  /// In sv, this message translates to:
  /// **'{count} dagar kvar'**
  String expiresDaysRemaining(int count);

  /// No description provided for @expiresHoursRemaining.
  ///
  /// In sv, this message translates to:
  /// **'{count} timmar kvar'**
  String expiresHoursRemaining(int count);

  /// No description provided for @expiresMinutesRemaining.
  ///
  /// In sv, this message translates to:
  /// **'{count} minuter kvar'**
  String expiresMinutesRemaining(int count);

  /// No description provided for @expiresSoon.
  ///
  /// In sv, this message translates to:
  /// **'Går ut snart'**
  String get expiresSoon;

  /// No description provided for @groupInvitationNotificationWithMessage.
  ///
  /// In sv, this message translates to:
  /// **'{sender} bjöd in dig till gruppen {emoji} {group}: \"{message}\"'**
  String groupInvitationNotificationWithMessage(
      String sender, String emoji, String group, String message);

  /// No description provided for @groupInvitationNotificationSimple.
  ///
  /// In sv, this message translates to:
  /// **'{sender} bjöd in dig till gruppen {emoji} {group}'**
  String groupInvitationNotificationSimple(
      String sender, String emoji, String group);

  /// No description provided for @invitationStatusPending.
  ///
  /// In sv, this message translates to:
  /// **'Väntande'**
  String get invitationStatusPending;

  /// No description provided for @invitationStatusAccepted.
  ///
  /// In sv, this message translates to:
  /// **'Accepterad'**
  String get invitationStatusAccepted;

  /// No description provided for @invitationStatusRejected.
  ///
  /// In sv, this message translates to:
  /// **'Avvisad'**
  String get invitationStatusRejected;

  /// No description provided for @invitationStatusCancelled.
  ///
  /// In sv, this message translates to:
  /// **'Avbruten'**
  String get invitationStatusCancelled;

  /// No description provided for @invitationStatusExpired.
  ///
  /// In sv, this message translates to:
  /// **'Utgången'**
  String get invitationStatusExpired;

  /// No description provided for @messageContentRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Recept'**
  String get messageContentRecipe;

  /// No description provided for @messageContentMenu.
  ///
  /// In sv, this message translates to:
  /// **'Meny'**
  String get messageContentMenu;

  /// No description provided for @messageContentShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslista'**
  String get messageContentShoppingList;

  /// No description provided for @messageContentImage.
  ///
  /// In sv, this message translates to:
  /// **'Bild'**
  String get messageContentImage;

  /// No description provided for @messageContentVoice.
  ///
  /// In sv, this message translates to:
  /// **'Röstmeddelande'**
  String get messageContentVoice;

  /// No description provided for @conversationGroupChat.
  ///
  /// In sv, this message translates to:
  /// **'Gruppchatt'**
  String get conversationGroupChat;

  /// No description provided for @editModeOwner.
  ///
  /// In sv, this message translates to:
  /// **'Du äger detta recept'**
  String get editModeOwner;

  /// No description provided for @editModeCollaborative.
  ///
  /// In sv, this message translates to:
  /// **'Du redigerar tillsammans med andra'**
  String get editModeCollaborative;

  /// No description provided for @editModeReadOnlyWithFork.
  ///
  /// In sv, this message translates to:
  /// **'Skrivskyddat - du kan spara din egen kopia'**
  String get editModeReadOnlyWithFork;

  /// No description provided for @editModeNoAccess.
  ///
  /// In sv, this message translates to:
  /// **'Ingen åtkomst'**
  String get editModeNoAccess;

  /// No description provided for @editModeEdit.
  ///
  /// In sv, this message translates to:
  /// **'Redigeringsläge'**
  String get editModeEdit;

  /// No description provided for @editModeView.
  ///
  /// In sv, this message translates to:
  /// **'Visningsläge'**
  String get editModeView;

  /// No description provided for @changeTypeAdded.
  ///
  /// In sv, this message translates to:
  /// **'Tillagd'**
  String get changeTypeAdded;

  /// No description provided for @changeTypeModified.
  ///
  /// In sv, this message translates to:
  /// **'Ändrad'**
  String get changeTypeModified;

  /// No description provided for @changeTypeRemoved.
  ///
  /// In sv, this message translates to:
  /// **'Borttagen'**
  String get changeTypeRemoved;

  /// No description provided for @memberSinceDays.
  ///
  /// In sv, this message translates to:
  /// **'Medlem i {count} dagar'**
  String memberSinceDays(int count);

  /// No description provided for @memberSinceMonths.
  ///
  /// In sv, this message translates to:
  /// **'Medlem i {count} månader'**
  String memberSinceMonths(int count);

  /// No description provided for @memberSinceYears.
  ///
  /// In sv, this message translates to:
  /// **'Medlem i {count} år'**
  String memberSinceYears(int count);

  /// No description provided for @commentDeleted.
  ///
  /// In sv, this message translates to:
  /// **'[Kommentar borttagen]'**
  String get commentDeleted;

  /// No description provided for @deletedUser.
  ///
  /// In sv, this message translates to:
  /// **'Borttagen användare'**
  String get deletedUser;

  /// No description provided for @sharedMenuTitlePattern.
  ///
  /// In sv, this message translates to:
  /// **'{name}s veckomeny'**
  String sharedMenuTitlePattern(String name);

  /// No description provided for @importedFromMenu.
  ///
  /// In sv, this message translates to:
  /// **'Importerat från {name}s meny \"{title}\"'**
  String importedFromMenu(String name, String title);

  /// No description provided for @importedRecipeLabel.
  ///
  /// In sv, this message translates to:
  /// **'Importerat recept'**
  String get importedRecipeLabel;

  /// No description provided for @activityCreatedRecipe.
  ///
  /// In sv, this message translates to:
  /// **'skapade ett recept'**
  String get activityCreatedRecipe;

  /// No description provided for @activitySharedRecipe.
  ///
  /// In sv, this message translates to:
  /// **'delade ett recept'**
  String get activitySharedRecipe;

  /// No description provided for @activityRatedRecipe.
  ///
  /// In sv, this message translates to:
  /// **'betygsatte ett recept ({rating}⭐)'**
  String activityRatedRecipe(int rating);

  /// No description provided for @activityCommentedRecipe.
  ///
  /// In sv, this message translates to:
  /// **'kommenterade ett recept'**
  String get activityCommentedRecipe;

  /// No description provided for @activityReactedRecipe.
  ///
  /// In sv, this message translates to:
  /// **'reagerade på ett recept ({reaction})'**
  String activityReactedRecipe(String reaction);

  /// No description provided for @activityCreatedMenu.
  ///
  /// In sv, this message translates to:
  /// **'skapade en meny'**
  String get activityCreatedMenu;

  /// No description provided for @activitySharedMenu.
  ///
  /// In sv, this message translates to:
  /// **'delade en meny'**
  String get activitySharedMenu;

  /// No description provided for @activityCreatedShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'skapade en inköpslista'**
  String get activityCreatedShoppingList;

  /// No description provided for @activitySharedShoppingList.
  ///
  /// In sv, this message translates to:
  /// **'delade en inköpslista'**
  String get activitySharedShoppingList;

  /// No description provided for @activityJoinedGroup.
  ///
  /// In sv, this message translates to:
  /// **'gick med i en grupp'**
  String get activityJoinedGroup;

  /// No description provided for @activityUnlockedAchievement.
  ///
  /// In sv, this message translates to:
  /// **'låste upp en bedrift: {achievement}'**
  String activityUnlockedAchievement(String achievement);

  /// No description provided for @activityDidSomething.
  ///
  /// In sv, this message translates to:
  /// **'gjorde något'**
  String get activityDidSomething;

  /// No description provided for @labelEmptyMenu.
  ///
  /// In sv, this message translates to:
  /// **'Tom meny'**
  String get labelEmptyMenu;

  /// No description provided for @labelMultipleChanges.
  ///
  /// In sv, this message translates to:
  /// **'Flera ändringar'**
  String get labelMultipleChanges;

  /// No description provided for @errorVideoNoSubtitles.
  ///
  /// In sv, this message translates to:
  /// **'Video saknar undertexter'**
  String get errorVideoNoSubtitles;

  /// No description provided for @errorNetworkFallback.
  ///
  /// In sv, this message translates to:
  /// **'Nätverksfel'**
  String get errorNetworkFallback;

  /// No description provided for @recipeCollaborationEnable.
  ///
  /// In sv, this message translates to:
  /// **'Aktivera samarbete'**
  String get recipeCollaborationEnable;

  /// No description provided for @recipeCollaborationDisable.
  ///
  /// In sv, this message translates to:
  /// **'Avaktivera samarbete'**
  String get recipeCollaborationDisable;

  /// No description provided for @menuCommentDeletedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Kommentaren borttagen'**
  String get menuCommentDeletedSuccess;

  /// No description provided for @recipeSharingStatus.
  ///
  /// In sv, this message translates to:
  /// **'Delningsstatus'**
  String get recipeSharingStatus;

  /// No description provided for @recipeSharingStopAll.
  ///
  /// In sv, this message translates to:
  /// **'Sluta dela med alla'**
  String get recipeSharingStopAll;

  /// No description provided for @recipeSharingStopAllConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Är du säker på att du vill sluta dela med alla?'**
  String get recipeSharingStopAllConfirm;

  /// No description provided for @recipeSharingStopAllSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Delning avslutad med alla'**
  String get recipeSharingStopAllSuccess;

  /// No description provided for @recipeSharingRevoke.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort delning'**
  String get recipeSharingRevoke;

  /// No description provided for @recipeSharingRevokeConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Sluta dela med {name}?'**
  String recipeSharingRevokeConfirm(String name);

  /// No description provided for @recipeSharingRevokeSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Delning med {name} avslutad'**
  String recipeSharingRevokeSuccess(String name);

  /// No description provided for @recipeSharingFriends.
  ///
  /// In sv, this message translates to:
  /// **'Vänner'**
  String get recipeSharingFriends;

  /// No description provided for @recipeSharingGroups.
  ///
  /// In sv, this message translates to:
  /// **'Grupper'**
  String get recipeSharingGroups;

  /// No description provided for @menuRatingRemoveTitle.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort betyg?'**
  String get menuRatingRemoveTitle;

  /// No description provided for @menuRatingRemoveMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du ta bort ditt betyg?'**
  String get menuRatingRemoveMessage;

  /// No description provided for @menuRatingRemoveConfirm.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort'**
  String get menuRatingRemoveConfirm;

  /// No description provided for @menuRatingRemoveButton.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort betyg'**
  String get menuRatingRemoveButton;

  /// No description provided for @menuRatingRemoved.
  ///
  /// In sv, this message translates to:
  /// **'Betyget borttaget'**
  String get menuRatingRemoved;

  /// No description provided for @menuRatingRemoveError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort betyg'**
  String get menuRatingRemoveError;

  /// No description provided for @shoppingTemplates.
  ///
  /// In sv, this message translates to:
  /// **'Inköpsmallar'**
  String get shoppingTemplates;

  /// No description provided for @shoppingTemplateBrowse.
  ///
  /// In sv, this message translates to:
  /// **'Visa mallar'**
  String get shoppingTemplateBrowse;

  /// No description provided for @shoppingTemplateEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Inga sparade mallar'**
  String get shoppingTemplateEmpty;

  /// No description provided for @shoppingTemplateEmptyDescription.
  ///
  /// In sv, this message translates to:
  /// **'Spara en inköpslista som mall för snabb återskapning'**
  String get shoppingTemplateEmptyDescription;

  /// No description provided for @shoppingTemplateUse.
  ///
  /// In sv, this message translates to:
  /// **'Använd mall'**
  String get shoppingTemplateUse;

  /// No description provided for @shoppingTemplateDelete.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort mall'**
  String get shoppingTemplateDelete;

  /// No description provided for @shoppingTemplateDeleted.
  ///
  /// In sv, this message translates to:
  /// **'Mall borttagen'**
  String get shoppingTemplateDeleted;

  /// No description provided for @shoppingTemplateCreated.
  ///
  /// In sv, this message translates to:
  /// **'Lista skapad från mall'**
  String get shoppingTemplateCreated;

  /// No description provided for @shoppingTemplateItemCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} varor'**
  String shoppingTemplateItemCount(int count);

  /// No description provided for @shoppingTemplateUsedCount.
  ///
  /// In sv, this message translates to:
  /// **'Använd {count} gånger'**
  String shoppingTemplateUsedCount(int count);

  /// No description provided for @labelButleryUser.
  ///
  /// In sv, this message translates to:
  /// **'Butlery-användare'**
  String get labelButleryUser;

  /// No description provided for @shoppingListSummaryEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Tom handlingslista'**
  String get shoppingListSummaryEmpty;

  /// No description provided for @shoppingListSummaryAllDone.
  ///
  /// In sv, this message translates to:
  /// **'Alla {count} artiklar klara'**
  String shoppingListSummaryAllDone(int count);

  /// No description provided for @shoppingListSummaryToBuy.
  ///
  /// In sv, this message translates to:
  /// **'{count} artiklar att köpa'**
  String shoppingListSummaryToBuy(int count);

  /// No description provided for @shoppingListSummaryRemaining.
  ///
  /// In sv, this message translates to:
  /// **'{remaining} av {total} artiklar kvar'**
  String shoppingListSummaryRemaining(int remaining, int total);

  /// No description provided for @notificationBatchComments.
  ///
  /// In sv, this message translates to:
  /// **'{count} nya kommentarer på dina recept'**
  String notificationBatchComments(int count);

  /// No description provided for @notificationCommentSingle.
  ///
  /// In sv, this message translates to:
  /// **'{author} kommenterade på \"{recipe}\"'**
  String notificationCommentSingle(String author, String recipe);

  /// No description provided for @notificationCommentMultipleSameAuthor.
  ///
  /// In sv, this message translates to:
  /// **'{author} skrev {count} kommentarer på \"{recipe}\"'**
  String notificationCommentMultipleSameAuthor(
      String author, int count, String recipe);

  /// No description provided for @notificationCommentMultipleAuthors.
  ///
  /// In sv, this message translates to:
  /// **'{authorCount} personer skrev {commentCount} kommentarer på \"{recipe}\"'**
  String notificationCommentMultipleAuthors(
      int authorCount, int commentCount, String recipe);

  /// No description provided for @notificationRatingSingle.
  ///
  /// In sv, this message translates to:
  /// **'Ditt recept \"{recipe}\" fick {count} nya betyg denna {period}!'**
  String notificationRatingSingle(String recipe, int count, String period);

  /// No description provided for @notificationRatingMultiple.
  ///
  /// In sv, this message translates to:
  /// **'Dina recept fick totalt {totalRatings} nya betyg på {recipeCount} recept denna {period}!'**
  String notificationRatingMultiple(
      int totalRatings, int recipeCount, String period);

  /// No description provided for @timeCompactMonths.
  ///
  /// In sv, this message translates to:
  /// **'{count}mån'**
  String timeCompactMonths(int count);

  /// No description provided for @validationFieldCannotBeEmpty.
  ///
  /// In sv, this message translates to:
  /// **'{fieldName} får inte vara tom'**
  String validationFieldCannotBeEmpty(String fieldName);

  /// No description provided for @validationMustBeNumber.
  ///
  /// In sv, this message translates to:
  /// **'{fieldName} måste vara ett nummer'**
  String validationMustBeNumber(String fieldName);

  /// No description provided for @validationMinValue.
  ///
  /// In sv, this message translates to:
  /// **'{fieldName} måste vara minst {min}'**
  String validationMinValue(String fieldName, String min);

  /// No description provided for @validationMaxValue.
  ///
  /// In sv, this message translates to:
  /// **'{fieldName} får vara max {max}'**
  String validationMaxValue(String fieldName, String max);

  /// No description provided for @validationDefaultValueLabel.
  ///
  /// In sv, this message translates to:
  /// **'Värdet'**
  String get validationDefaultValueLabel;

  /// No description provided for @validationInvalidUrlHint.
  ///
  /// In sv, this message translates to:
  /// **'Ange en giltig URL (börja med http:// eller https://)'**
  String get validationInvalidUrlHint;

  /// No description provided for @validationFieldRating.
  ///
  /// In sv, this message translates to:
  /// **'Betyg'**
  String get validationFieldRating;

  /// No description provided for @validationFieldPortions.
  ///
  /// In sv, this message translates to:
  /// **'Antal portioner'**
  String get validationFieldPortions;

  /// No description provided for @validationFieldCookingTime.
  ///
  /// In sv, this message translates to:
  /// **'Tillagningstid'**
  String get validationFieldCookingTime;

  /// No description provided for @validationDisplayNameEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Visningsnamn får inte vara tomt'**
  String get validationDisplayNameEmpty;

  /// No description provided for @validationDisplayNameTooShort.
  ///
  /// In sv, this message translates to:
  /// **'Visningsnamn måste vara minst 2 tecken'**
  String get validationDisplayNameTooShort;

  /// No description provided for @validationDisplayNameTooLong.
  ///
  /// In sv, this message translates to:
  /// **'Visningsnamn får vara max 30 tecken'**
  String get validationDisplayNameTooLong;

  /// No description provided for @validationDisplayNameInvalidChars.
  ///
  /// In sv, this message translates to:
  /// **'Visningsnamn får bara innehålla bokstäver, siffror, mellanslag och - _ .'**
  String get validationDisplayNameInvalidChars;

  /// No description provided for @validationDisplayNameNoLetters.
  ///
  /// In sv, this message translates to:
  /// **'Visningsnamn måste innehålla minst en bokstav eller siffra'**
  String get validationDisplayNameNoLetters;

  /// No description provided for @validationDisplayNameNoSpaces.
  ///
  /// In sv, this message translates to:
  /// **'Visningsnamn får inte börja eller sluta med mellanslag'**
  String get validationDisplayNameNoSpaces;

  /// No description provided for @validationCommentEmpty.
  ///
  /// In sv, this message translates to:
  /// **'Kommentar får inte vara tom'**
  String get validationCommentEmpty;

  /// No description provided for @validationCommentTooShort.
  ///
  /// In sv, this message translates to:
  /// **'Kommentar måste vara minst 3 tecken'**
  String get validationCommentTooShort;

  /// No description provided for @validationCommentTooLong.
  ///
  /// In sv, this message translates to:
  /// **'Kommentar får vara max 500 tecken'**
  String get validationCommentTooLong;

  /// No description provided for @validationMessageMaxLength.
  ///
  /// In sv, this message translates to:
  /// **'Meddelande får vara max {max} tecken'**
  String validationMessageMaxLength(int max);

  /// No description provided for @validationNameTooShort.
  ///
  /// In sv, this message translates to:
  /// **'Namnet måste vara minst 2 tecken'**
  String get validationNameTooShort;

  /// No description provided for @validationEmailInvalidHint.
  ///
  /// In sv, this message translates to:
  /// **'Ange en giltig e-postadress'**
  String get validationEmailInvalidHint;

  /// No description provided for @validationShoppingItemRequired.
  ///
  /// In sv, this message translates to:
  /// **'Ange artikelnamn'**
  String get validationShoppingItemRequired;

  /// No description provided for @validationAmountRequired.
  ///
  /// In sv, this message translates to:
  /// **'Ange antal'**
  String get validationAmountRequired;

  /// No description provided for @validationTagMinLength.
  ///
  /// In sv, this message translates to:
  /// **'Varje tagg måste vara minst 2 tecken'**
  String get validationTagMinLength;

  /// No description provided for @validationTagMaxLength.
  ///
  /// In sv, this message translates to:
  /// **'Varje tagg får vara max 20 tecken'**
  String get validationTagMaxLength;

  /// No description provided for @validationFieldNotEmpty.
  ///
  /// In sv, this message translates to:
  /// **'{fieldName} får inte vara tomt'**
  String validationFieldNotEmpty(String fieldName);

  /// No description provided for @validationPasswordMinEight.
  ///
  /// In sv, this message translates to:
  /// **'Lösenordet måste vara minst 8 tecken'**
  String get validationPasswordMinEight;

  /// No description provided for @validationPasswordNeedsUppercase.
  ///
  /// In sv, this message translates to:
  /// **'Lösenordet måste innehålla minst en stor bokstav'**
  String get validationPasswordNeedsUppercase;

  /// No description provided for @validationPasswordNeedsLowercase.
  ///
  /// In sv, this message translates to:
  /// **'Lösenordet måste innehålla minst en liten bokstav'**
  String get validationPasswordNeedsLowercase;

  /// No description provided for @validationPasswordNeedsDigit.
  ///
  /// In sv, this message translates to:
  /// **'Lösenordet måste innehålla minst en siffra'**
  String get validationPasswordNeedsDigit;

  /// No description provided for @validationDisplayNameLabel.
  ///
  /// In sv, this message translates to:
  /// **'Visningsnamn'**
  String get validationDisplayNameLabel;

  /// No description provided for @validationCommentLabel.
  ///
  /// In sv, this message translates to:
  /// **'Kommentar'**
  String get validationCommentLabel;

  /// No description provided for @validationAmountMustBePositive.
  ///
  /// In sv, this message translates to:
  /// **'Antal måste vara ett positivt nummer'**
  String get validationAmountMustBePositive;

  /// No description provided for @validationUserIdRequired.
  ///
  /// In sv, this message translates to:
  /// **'Användar-ID krävs för denna operation'**
  String get validationUserIdRequired;

  /// No description provided for @validationFieldRecipeName.
  ///
  /// In sv, this message translates to:
  /// **'Receptnamn'**
  String get validationFieldRecipeName;

  /// No description provided for @validationFieldGroupName.
  ///
  /// In sv, this message translates to:
  /// **'Gruppnamn'**
  String get validationFieldGroupName;

  /// No description provided for @validationFieldArticle.
  ///
  /// In sv, this message translates to:
  /// **'Artikel'**
  String get validationFieldArticle;

  /// No description provided for @errorImageUploadFailed.
  ///
  /// In sv, this message translates to:
  /// **'Bilduppladdning misslyckades: {message}'**
  String errorImageUploadFailed(String message);

  /// No description provided for @errorRecipeServiceFailed.
  ///
  /// In sv, this message translates to:
  /// **'Recepthantering misslyckades: {message}'**
  String errorRecipeServiceFailed(String message);

  /// No description provided for @errorPermissionFailed.
  ///
  /// In sv, this message translates to:
  /// **'Behörighetsfel: {message}'**
  String errorPermissionFailed(String message);

  /// No description provided for @errorNetworkWithDetail.
  ///
  /// In sv, this message translates to:
  /// **'Nätverksfel: {message}'**
  String errorNetworkWithDetail(String message);

  /// No description provided for @errorStorageFailed.
  ///
  /// In sv, this message translates to:
  /// **'Lagringsfel: {message}'**
  String errorStorageFailed(String message);

  /// No description provided for @errorCollaborationFailed.
  ///
  /// In sv, this message translates to:
  /// **'Samarbetsfel: {message}'**
  String errorCollaborationFailed(String message);

  /// No description provided for @errorAutoSaveFailed.
  ///
  /// In sv, this message translates to:
  /// **'Autosparning misslyckades: {message}'**
  String errorAutoSaveFailed(String message);

  /// No description provided for @errorSystemFailed.
  ///
  /// In sv, this message translates to:
  /// **'Systemfel: {message}'**
  String errorSystemFailed(String message);

  /// No description provided for @actionRefresh.
  ///
  /// In sv, this message translates to:
  /// **'Uppdatera'**
  String get actionRefresh;

  /// No description provided for @actionGoBack.
  ///
  /// In sv, this message translates to:
  /// **'Gå tillbaka'**
  String get actionGoBack;

  /// No description provided for @actionReport.
  ///
  /// In sv, this message translates to:
  /// **'Rapportera'**
  String get actionReport;

  /// No description provided for @shareIngredientsLabel.
  ///
  /// In sv, this message translates to:
  /// **'Ingredienser:'**
  String get shareIngredientsLabel;

  /// No description provided for @shareInstructionsLabel.
  ///
  /// In sv, this message translates to:
  /// **'Gör så här:'**
  String get shareInstructionsLabel;

  /// No description provided for @shareSourceLabel.
  ///
  /// In sv, this message translates to:
  /// **'Källa:'**
  String get shareSourceLabel;

  /// No description provided for @sharePortionsUnit.
  ///
  /// In sv, this message translates to:
  /// **'portioner'**
  String get sharePortionsUnit;

  /// No description provided for @shareMinutesUnit.
  ///
  /// In sv, this message translates to:
  /// **'minuter'**
  String get shareMinutesUnit;

  /// No description provided for @uploadNotificationTitle.
  ///
  /// In sv, this message translates to:
  /// **'Uppladdning {percentage}% klar'**
  String uploadNotificationTitle(int percentage);

  /// No description provided for @uploadNotificationMessage.
  ///
  /// In sv, this message translates to:
  /// **'Bilduppladdning gör framsteg - {percentage}% slutförd'**
  String uploadNotificationMessage(int percentage);

  /// No description provided for @feedbackDescriptionRequired.
  ///
  /// In sv, this message translates to:
  /// **'Ange en beskrivning'**
  String get feedbackDescriptionRequired;

  /// No description provided for @feedbackThanks.
  ///
  /// In sv, this message translates to:
  /// **'Tack för din feedback!'**
  String get feedbackThanks;

  /// No description provided for @feedbackSendFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skicka feedback. Försök igen.'**
  String get feedbackSendFailed;

  /// No description provided for @tooltipRemoveOption.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort alternativ'**
  String get tooltipRemoveOption;

  /// No description provided for @personalTagCouldNotShare.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dela taggen'**
  String get personalTagCouldNotShare;

  /// No description provided for @reactionThumbsUp.
  ///
  /// In sv, this message translates to:
  /// **'Tummen upp'**
  String get reactionThumbsUp;

  /// No description provided for @reactionHeart.
  ///
  /// In sv, this message translates to:
  /// **'Hjärta'**
  String get reactionHeart;

  /// No description provided for @reactionFire.
  ///
  /// In sv, this message translates to:
  /// **'Eld'**
  String get reactionFire;

  /// No description provided for @reactionLaughing.
  ///
  /// In sv, this message translates to:
  /// **'Skratt'**
  String get reactionLaughing;

  /// No description provided for @reactionYum.
  ///
  /// In sv, this message translates to:
  /// **'Gott'**
  String get reactionYum;

  /// No description provided for @reactionThinking.
  ///
  /// In sv, this message translates to:
  /// **'Funderar'**
  String get reactionThinking;

  /// No description provided for @menuCompletionPercent.
  ///
  /// In sv, this message translates to:
  /// **'{percentage}% färdig'**
  String menuCompletionPercent(int percentage);

  /// No description provided for @networkErrorNoConnection.
  ///
  /// In sv, this message translates to:
  /// **'Ingen internetanslutning. {operation} kommer att sparas lokalt och synkroniseras när du är online igen.'**
  String networkErrorNoConnection(String operation);

  /// No description provided for @networkErrorNoConnectionShort.
  ///
  /// In sv, this message translates to:
  /// **'Ingen internetanslutning för {operation}.'**
  String networkErrorNoConnectionShort(String operation);

  /// No description provided for @networkErrorMobileData.
  ///
  /// In sv, this message translates to:
  /// **'Använder mobildata för {operation}. Detta kan ta längre tid eller påverka din dataförbrukning.'**
  String networkErrorMobileData(String operation);

  /// No description provided for @networkErrorMobileShort.
  ///
  /// In sv, this message translates to:
  /// **'Mobilanslutning för {operation}.'**
  String networkErrorMobileShort(String operation);

  /// No description provided for @networkErrorLimited.
  ///
  /// In sv, this message translates to:
  /// **'Begränsad anslutning upptäckt. {operation} kan ta längre tid eller sparas lokalt.'**
  String networkErrorLimited(String operation);

  /// No description provided for @networkErrorLimitedShort.
  ///
  /// In sv, this message translates to:
  /// **'Begränsad anslutning för {operation}.'**
  String networkErrorLimitedShort(String operation);

  /// No description provided for @networkErrorDefault.
  ///
  /// In sv, this message translates to:
  /// **'Nätverksfel under {operation}. Kontrollera din anslutning och försök igen.'**
  String networkErrorDefault(String operation);

  /// No description provided for @permissionErrorAction.
  ///
  /// In sv, this message translates to:
  /// **'Du kan inte {action} detta {resource}'**
  String permissionErrorAction(String action, String resource);

  /// No description provided for @permissionErrorBecause.
  ///
  /// In sv, this message translates to:
  /// **'eftersom {reason}'**
  String permissionErrorBecause(String reason);

  /// No description provided for @permissionErrorSuggestion.
  ///
  /// In sv, this message translates to:
  /// **'Förslag: {suggestion}'**
  String permissionErrorSuggestion(String suggestion);

  /// No description provided for @errorDuringAction.
  ///
  /// In sv, this message translates to:
  /// **'Problem medan {action}: {issue}'**
  String errorDuringAction(String action, String issue);

  /// No description provided for @errorDuringActionRecovery.
  ///
  /// In sv, this message translates to:
  /// **'Problem medan {action}: {issue}\n\nFörslag: {recovery}'**
  String errorDuringActionRecovery(
      String action, String issue, String recovery);

  /// No description provided for @formatPortionSingle.
  ///
  /// In sv, this message translates to:
  /// **'1 portion'**
  String get formatPortionSingle;

  /// No description provided for @formatPortionPlural.
  ///
  /// In sv, this message translates to:
  /// **'{count} portioner'**
  String formatPortionPlural(int count);

  /// No description provided for @validationFailedWith.
  ///
  /// In sv, this message translates to:
  /// **'Validering misslyckades: {error}'**
  String validationFailedWith(String error);

  /// No description provided for @snackbarNoInternet.
  ///
  /// In sv, this message translates to:
  /// **'Ingen internetanslutning. Kontrollera din anslutning.'**
  String get snackbarNoInternet;

  /// No description provided for @errorInvalidYoutubeUrl.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltig YouTube-URL'**
  String get errorInvalidYoutubeUrl;

  /// No description provided for @errorInvalidInstructionIndex.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltiga instruktions-index'**
  String get errorInvalidInstructionIndex;

  /// No description provided for @errorInvalidIngredientIndex.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltiga ingrediens-index'**
  String get errorInvalidIngredientIndex;

  /// No description provided for @errorInvalidCategoryNamesFromTo.
  ///
  /// In sv, this message translates to:
  /// **'Ogiltiga kategorinamn: {fromCategory} -> {toCategory}'**
  String errorInvalidCategoryNamesFromTo(
      String fromCategory, String toCategory);

  /// No description provided for @validationTitleMissing.
  ///
  /// In sv, this message translates to:
  /// **'Titel saknas'**
  String get validationTitleMissing;

  /// No description provided for @validationIngredientsMissing.
  ///
  /// In sv, this message translates to:
  /// **'Ingredienser saknas'**
  String get validationIngredientsMissing;

  /// No description provided for @validationInstructionsMissing.
  ///
  /// In sv, this message translates to:
  /// **'Instruktioner saknas'**
  String get validationInstructionsMissing;

  /// No description provided for @validationMealTypeMissing.
  ///
  /// In sv, this message translates to:
  /// **'Måltidstyp saknas'**
  String get validationMealTypeMissing;

  /// No description provided for @shareMinutesAbbrev.
  ///
  /// In sv, this message translates to:
  /// **'min'**
  String get shareMinutesAbbrev;

  /// No description provided for @sharePortionsAbbrev.
  ///
  /// In sv, this message translates to:
  /// **'port'**
  String get sharePortionsAbbrev;

  /// No description provided for @shareTimeLabel.
  ///
  /// In sv, this message translates to:
  /// **'Tid:'**
  String get shareTimeLabel;

  /// No description provided for @shareTimeLabelBold.
  ///
  /// In sv, this message translates to:
  /// **'**Tid:**'**
  String get shareTimeLabelBold;

  /// No description provided for @sharePortionsLabel.
  ///
  /// In sv, this message translates to:
  /// **'Portioner:'**
  String get sharePortionsLabel;

  /// No description provided for @sharePortionsLabelBold.
  ///
  /// In sv, this message translates to:
  /// **'**Portioner:**'**
  String get sharePortionsLabelBold;

  /// No description provided for @shareRatingLabel.
  ///
  /// In sv, this message translates to:
  /// **'Betyg:'**
  String get shareRatingLabel;

  /// No description provided for @shareRatingLabelBold.
  ///
  /// In sv, this message translates to:
  /// **'**Betyg:**'**
  String get shareRatingLabelBold;

  /// No description provided for @shareTypeLabel.
  ///
  /// In sv, this message translates to:
  /// **'Typ:'**
  String get shareTypeLabel;

  /// No description provided for @shareTypeLabelBold.
  ///
  /// In sv, this message translates to:
  /// **'**Typ:**'**
  String get shareTypeLabelBold;

  /// No description provided for @shareTagsLabel.
  ///
  /// In sv, this message translates to:
  /// **'Tags'**
  String get shareTagsLabel;

  /// No description provided for @shareInstructionsLabelCompact.
  ///
  /// In sv, this message translates to:
  /// **'Instruktioner:'**
  String get shareInstructionsLabelCompact;

  /// No description provided for @shareShoppingListTitleSimple.
  ///
  /// In sv, this message translates to:
  /// **'Inköpslista'**
  String get shareShoppingListTitleSimple;

  /// No description provided for @shareWeekMenuTitle.
  ///
  /// In sv, this message translates to:
  /// **'Veckomeny'**
  String get shareWeekMenuTitle;

  /// No description provided for @shareWeekMenuTitleEmoji.
  ///
  /// In sv, this message translates to:
  /// **'🍽 VECKOMENY'**
  String get shareWeekMenuTitleEmoji;

  /// No description provided for @shareSummaryLabel.
  ///
  /// In sv, this message translates to:
  /// **'📊 Sammanfattning:'**
  String get shareSummaryLabel;

  /// No description provided for @shareSummaryRecipesInCategories.
  ///
  /// In sv, this message translates to:
  /// **'{recipeCount} recept i {categoryCount} kategorier'**
  String shareSummaryRecipesInCategories(int recipeCount, int categoryCount);

  /// No description provided for @unsavedChangesTitle.
  ///
  /// In sv, this message translates to:
  /// **'Osparade ändringar'**
  String get unsavedChangesTitle;

  /// No description provided for @unsavedChangesMessage.
  ///
  /// In sv, this message translates to:
  /// **'Du har osparade ändringar. Vill du verkligen avbryta?'**
  String get unsavedChangesMessage;

  /// No description provided for @cancelWithoutSaving.
  ///
  /// In sv, this message translates to:
  /// **'Avbryt utan att spara'**
  String get cancelWithoutSaving;

  /// No description provided for @deleteActionIrreversible.
  ///
  /// In sv, this message translates to:
  /// **'Denna åtgärd kan inte ångras.'**
  String get deleteActionIrreversible;

  /// No description provided for @deleteConfirmMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du verkligen ta bort'**
  String get deleteConfirmMessage;

  /// No description provided for @groupLeaveTitle.
  ///
  /// In sv, this message translates to:
  /// **'Lämna grupp?'**
  String get groupLeaveTitle;

  /// No description provided for @groupLeaveMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du verkligen lämna gruppen \"{name}\"?'**
  String groupLeaveMessage(String name);

  /// No description provided for @groupLeaveAction.
  ///
  /// In sv, this message translates to:
  /// **'Lämna grupp'**
  String get groupLeaveAction;

  /// No description provided for @shareItemTitle.
  ///
  /// In sv, this message translates to:
  /// **'Dela {type}?'**
  String shareItemTitle(String type);

  /// No description provided for @shareItemMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vill du dela {type} med {recipients}?'**
  String shareItemMessage(String type, String recipients);

  /// No description provided for @shareRecipientsMore.
  ///
  /// In sv, this message translates to:
  /// **'och {count} till'**
  String shareRecipientsMore(int count);

  /// No description provided for @recipeDeleteWarning.
  ///
  /// In sv, this message translates to:
  /// **'Receptet kommer att tas bort permanent.'**
  String get recipeDeleteWarning;

  /// No description provided for @shoppingListDeleteWarning.
  ///
  /// In sv, this message translates to:
  /// **'Alla varor på listan kommer att försvinna.'**
  String get shoppingListDeleteWarning;

  /// No description provided for @itemDeletedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'{type} har tagits bort'**
  String itemDeletedSuccess(String type);

  /// No description provided for @itemDeleteError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort {type}'**
  String itemDeleteError(String type);

  /// No description provided for @commentDeleteError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte ta bort kommentaren'**
  String get commentDeleteError;

  /// No description provided for @reactionUpdateError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte uppdatera reaktion'**
  String get reactionUpdateError;

  /// No description provided for @activityRecipeCreated.
  ///
  /// In sv, this message translates to:
  /// **'👨‍🍳 Recept skapat'**
  String get activityRecipeCreated;

  /// No description provided for @activityMenuCreated.
  ///
  /// In sv, this message translates to:
  /// **'📋 Meny skapad'**
  String get activityMenuCreated;

  /// No description provided for @activityShoppingListCreated.
  ///
  /// In sv, this message translates to:
  /// **'🛒 Inköpslista skapad'**
  String get activityShoppingListCreated;

  /// No description provided for @activityRecipeShared.
  ///
  /// In sv, this message translates to:
  /// **'📤 Recept delat'**
  String get activityRecipeShared;

  /// No description provided for @activityMenuShared.
  ///
  /// In sv, this message translates to:
  /// **'📤 Meny delad'**
  String get activityMenuShared;

  /// No description provided for @activityShoppingListShared.
  ///
  /// In sv, this message translates to:
  /// **'📤 Inköpslista delad'**
  String get activityShoppingListShared;

  /// No description provided for @activityCommentAdded.
  ///
  /// In sv, this message translates to:
  /// **'💬 Kommentar'**
  String get activityCommentAdded;

  /// No description provided for @activityReactionAdded.
  ///
  /// In sv, this message translates to:
  /// **'❤️ Reaktion'**
  String get activityReactionAdded;

  /// No description provided for @activityRecipeRated.
  ///
  /// In sv, this message translates to:
  /// **'⭐ Betyg'**
  String get activityRecipeRated;

  /// No description provided for @activityGroupJoined.
  ///
  /// In sv, this message translates to:
  /// **'👥 Gick med i grupp'**
  String get activityGroupJoined;

  /// No description provided for @activityInvitationSent.
  ///
  /// In sv, this message translates to:
  /// **'📩 Inbjudan skickad'**
  String get activityInvitationSent;

  /// No description provided for @activityInvitationAccepted.
  ///
  /// In sv, this message translates to:
  /// **'✅ Inbjudan accepterad'**
  String get activityInvitationAccepted;

  /// No description provided for @activityAchievementUnlocked.
  ///
  /// In sv, this message translates to:
  /// **'🏆 Bedrift'**
  String get activityAchievementUnlocked;

  /// No description provided for @activityMilestoneReached.
  ///
  /// In sv, this message translates to:
  /// **'🎯 Milstolpe'**
  String get activityMilestoneReached;

  /// No description provided for @activityUnknown.
  ///
  /// In sv, this message translates to:
  /// **'❓ Okänd aktivitet'**
  String get activityUnknown;

  /// No description provided for @pollVoteSingular.
  ///
  /// In sv, this message translates to:
  /// **'röst'**
  String get pollVoteSingular;

  /// No description provided for @pollVotePlural.
  ///
  /// In sv, this message translates to:
  /// **'röster'**
  String get pollVotePlural;

  /// No description provided for @pollClosed.
  ///
  /// In sv, this message translates to:
  /// **'Avslutad'**
  String get pollClosed;

  /// No description provided for @pollCloseAction.
  ///
  /// In sv, this message translates to:
  /// **'Stäng omröstning'**
  String get pollCloseAction;

  /// No description provided for @chatGroupChatDefault.
  ///
  /// In sv, this message translates to:
  /// **'Gruppchatt'**
  String get chatGroupChatDefault;

  /// No description provided for @chatGroupCreatedMessage.
  ///
  /// In sv, this message translates to:
  /// **'{name} skapade gruppen \"{title}\"'**
  String chatGroupCreatedMessage(String name, String title);

  /// No description provided for @chatParticipantAdded.
  ///
  /// In sv, this message translates to:
  /// **'{name} har lagts till i gruppen'**
  String chatParticipantAdded(String name);

  /// No description provided for @chatParticipantLeft.
  ///
  /// In sv, this message translates to:
  /// **'{name} har lämnat gruppen'**
  String chatParticipantLeft(String name);

  /// No description provided for @authRequiredError.
  ///
  /// In sv, this message translates to:
  /// **'Du måste vara inloggad'**
  String get authRequiredError;

  /// No description provided for @shoppingListEditPermissionDenied.
  ///
  /// In sv, this message translates to:
  /// **'Du har inte behörighet att redigera denna delade inköpslista'**
  String get shoppingListEditPermissionDenied;

  /// No description provided for @tagShareError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte dela taggen'**
  String get tagShareError;

  /// No description provided for @userStatusOffline.
  ///
  /// In sv, this message translates to:
  /// **'Offline'**
  String get userStatusOffline;

  /// No description provided for @userStatusAway.
  ///
  /// In sv, this message translates to:
  /// **'Away'**
  String get userStatusAway;

  /// No description provided for @userStatusBusy.
  ///
  /// In sv, this message translates to:
  /// **'Busy'**
  String get userStatusBusy;

  /// No description provided for @participantsCount.
  ///
  /// In sv, this message translates to:
  /// **'Deltagare ({count})'**
  String participantsCount(int count);

  /// No description provided for @participantsOnlineCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} online'**
  String participantsOnlineCount(int count);

  /// No description provided for @restoreDraft.
  ///
  /// In sv, this message translates to:
  /// **'Återställ'**
  String get restoreDraft;

  /// No description provided for @fieldsFilledCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} fält ifyllda'**
  String fieldsFilledCount(int count);

  /// No description provided for @noFriends.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga vänner än.'**
  String get noFriends;

  /// No description provided for @noRecipes.
  ///
  /// In sv, this message translates to:
  /// **'Du har inga recept än.'**
  String get noRecipes;

  /// No description provided for @addRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Lägg till recept'**
  String get addRecipe;

  /// No description provided for @editRecipe.
  ///
  /// In sv, this message translates to:
  /// **'Redigera recept'**
  String get editRecipe;

  /// No description provided for @checkPermissions.
  ///
  /// In sv, this message translates to:
  /// **'Kontrollera behörigheter'**
  String get checkPermissions;

  /// No description provided for @ingredientParseError.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte tolka ingrediens'**
  String get ingredientParseError;

  /// No description provided for @portionsUnit.
  ///
  /// In sv, this message translates to:
  /// **'portioner'**
  String get portionsUnit;

  /// No description provided for @sharedRecipeFallback.
  ///
  /// In sv, this message translates to:
  /// **'Delat recept • {count} medlemmar'**
  String sharedRecipeFallback(int count);

  /// No description provided for @sharedMenuFallback.
  ///
  /// In sv, this message translates to:
  /// **'Delad meny • {count} medlemmar'**
  String sharedMenuFallback(int count);

  /// No description provided for @sharedFallback.
  ///
  /// In sv, this message translates to:
  /// **'Delat'**
  String get sharedFallback;

  /// No description provided for @accountSecurityTitle.
  ///
  /// In sv, this message translates to:
  /// **'Kontosäkerhet'**
  String get accountSecurityTitle;

  /// No description provided for @accountSecurityChangePassword.
  ///
  /// In sv, this message translates to:
  /// **'Byt lösenord'**
  String get accountSecurityChangePassword;

  /// No description provided for @accountSecurityChangeEmail.
  ///
  /// In sv, this message translates to:
  /// **'Byt e-postadress'**
  String get accountSecurityChangeEmail;

  /// No description provided for @accountSecurityCurrentPassword.
  ///
  /// In sv, this message translates to:
  /// **'Nuvarande lösenord'**
  String get accountSecurityCurrentPassword;

  /// No description provided for @accountSecurityNewPassword.
  ///
  /// In sv, this message translates to:
  /// **'Nytt lösenord'**
  String get accountSecurityNewPassword;

  /// No description provided for @accountSecurityConfirmPassword.
  ///
  /// In sv, this message translates to:
  /// **'Bekräfta lösenord'**
  String get accountSecurityConfirmPassword;

  /// No description provided for @accountSecurityNewEmail.
  ///
  /// In sv, this message translates to:
  /// **'Ny e-postadress'**
  String get accountSecurityNewEmail;

  /// No description provided for @accountSecurityMfaSettings.
  ///
  /// In sv, this message translates to:
  /// **'Tvåfaktorsautentisering'**
  String get accountSecurityMfaSettings;

  /// No description provided for @accountSecurityPasswordChanged.
  ///
  /// In sv, this message translates to:
  /// **'Lösenordet har ändrats'**
  String get accountSecurityPasswordChanged;

  /// No description provided for @accountSecurityEmailVerificationSent.
  ///
  /// In sv, this message translates to:
  /// **'Verifieringslänk skickad till ny e-postadress'**
  String get accountSecurityEmailVerificationSent;

  /// No description provided for @accountSecurityPasswordMismatch.
  ///
  /// In sv, this message translates to:
  /// **'Lösenorden matchar inte'**
  String get accountSecurityPasswordMismatch;

  /// No description provided for @profileAccountSecurity.
  ///
  /// In sv, this message translates to:
  /// **'Kontosäkerhet'**
  String get profileAccountSecurity;

  /// No description provided for @profileAccountSecuritySubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Lösenord, e-post och tvåfaktorsautentisering'**
  String get profileAccountSecuritySubtitle;

  /// No description provided for @bulkSelectedCount.
  ///
  /// In sv, this message translates to:
  /// **'{count} valda'**
  String bulkSelectedCount(int count);

  /// No description provided for @bulkSelectAll.
  ///
  /// In sv, this message translates to:
  /// **'Välj alla'**
  String get bulkSelectAll;

  /// No description provided for @bulkDelete.
  ///
  /// In sv, this message translates to:
  /// **'Ta bort valda'**
  String get bulkDelete;

  /// No description provided for @bulkShare.
  ///
  /// In sv, this message translates to:
  /// **'Dela valda'**
  String get bulkShare;

  /// No description provided for @viewModeGrid.
  ///
  /// In sv, this message translates to:
  /// **'Rutnätsvy'**
  String get viewModeGrid;

  /// No description provided for @viewModeList.
  ///
  /// In sv, this message translates to:
  /// **'Listvy'**
  String get viewModeList;

  /// No description provided for @duplicateImportTitle.
  ///
  /// In sv, this message translates to:
  /// **'Receptet kan redan finnas'**
  String get duplicateImportTitle;

  /// No description provided for @duplicateImportMessage.
  ///
  /// In sv, this message translates to:
  /// **'Ett recept med samma källa finns redan: {recipeName}'**
  String duplicateImportMessage(String recipeName);

  /// No description provided for @duplicateImportViewExisting.
  ///
  /// In sv, this message translates to:
  /// **'Visa befintligt'**
  String get duplicateImportViewExisting;

  /// No description provided for @duplicateImportAnyway.
  ///
  /// In sv, this message translates to:
  /// **'Importera ändå'**
  String get duplicateImportAnyway;

  /// No description provided for @imageCropTitle.
  ///
  /// In sv, this message translates to:
  /// **'Beskär bild'**
  String get imageCropTitle;

  /// No description provided for @bulkDeleteConfirmMessage.
  ///
  /// In sv, this message translates to:
  /// **'De valda recepten kommer att tas bort.'**
  String get bulkDeleteConfirmMessage;

  /// No description provided for @bulkDeleteSuccess.
  ///
  /// In sv, this message translates to:
  /// **'{count} recept borttagna'**
  String bulkDeleteSuccess(int count);

  /// No description provided for @profileFaq.
  ///
  /// In sv, this message translates to:
  /// **'Vanliga frågor'**
  String get profileFaq;

  /// No description provided for @profileFaqSubtitle.
  ///
  /// In sv, this message translates to:
  /// **'Hjälp och svar på vanliga frågor'**
  String get profileFaqSubtitle;

  /// No description provided for @sharedWithYou.
  ///
  /// In sv, this message translates to:
  /// **'Delade med dig'**
  String get sharedWithYou;

  /// No description provided for @importTag.
  ///
  /// In sv, this message translates to:
  /// **'Importera'**
  String get importTag;

  /// No description provided for @tagImportedSuccess.
  ///
  /// In sv, this message translates to:
  /// **'Taggen importerades'**
  String get tagImportedSuccess;

  /// No description provided for @legalTermsOfService.
  ///
  /// In sv, this message translates to:
  /// **'Användarvillkor'**
  String get legalTermsOfService;

  /// No description provided for @legalCommunityGuidelines.
  ///
  /// In sv, this message translates to:
  /// **'Gemenskapsriktlinjer'**
  String get legalCommunityGuidelines;

  /// No description provided for @legalOpenSourceLicenses.
  ///
  /// In sv, this message translates to:
  /// **'Öppen källkod-licenser'**
  String get legalOpenSourceLicenses;

  /// No description provided for @authAgeConfirmation.
  ///
  /// In sv, this message translates to:
  /// **'Jag bekräftar att jag är minst 13 år'**
  String get authAgeConfirmation;

  /// No description provided for @authAgeConfirmationRequired.
  ///
  /// In sv, this message translates to:
  /// **'Du måste bekräfta din ålder för att skapa ett konto'**
  String get authAgeConfirmationRequired;

  /// No description provided for @reportContent.
  ///
  /// In sv, this message translates to:
  /// **'Rapportera'**
  String get reportContent;

  /// No description provided for @reportReasonInappropriate.
  ///
  /// In sv, this message translates to:
  /// **'Olämpligt innehåll'**
  String get reportReasonInappropriate;

  /// No description provided for @reportReasonSpam.
  ///
  /// In sv, this message translates to:
  /// **'Spam'**
  String get reportReasonSpam;

  /// No description provided for @reportReasonHarassment.
  ///
  /// In sv, this message translates to:
  /// **'Trakasseri'**
  String get reportReasonHarassment;

  /// No description provided for @reportReasonCopyright.
  ///
  /// In sv, this message translates to:
  /// **'Upphovsrättsintrång'**
  String get reportReasonCopyright;

  /// No description provided for @reportReasonOther.
  ///
  /// In sv, this message translates to:
  /// **'Annat'**
  String get reportReasonOther;

  /// No description provided for @reportDescriptionHint.
  ///
  /// In sv, this message translates to:
  /// **'Beskriv vad som är fel (valfritt)'**
  String get reportDescriptionHint;

  /// No description provided for @reportSubmitted.
  ///
  /// In sv, this message translates to:
  /// **'Rapporten har skickats'**
  String get reportSubmitted;

  /// No description provided for @reportSubmitFailed.
  ///
  /// In sv, this message translates to:
  /// **'Kunde inte skicka rapporten'**
  String get reportSubmitFailed;

  /// No description provided for @reportDialogTitle.
  ///
  /// In sv, this message translates to:
  /// **'Rapportera innehåll'**
  String get reportDialogTitle;

  /// No description provided for @reportSubmit.
  ///
  /// In sv, this message translates to:
  /// **'Skicka rapport'**
  String get reportSubmit;

  /// No description provided for @contentFilterWarning.
  ///
  /// In sv, this message translates to:
  /// **'Texten innehåller olämpligt språk. Vänligen redigera innan du skickar.'**
  String get contentFilterWarning;

  /// No description provided for @noResults.
  ///
  /// In sv, this message translates to:
  /// **'Inga resultat'**
  String get noResults;

  /// No description provided for @allergenCoverageLabel.
  ///
  /// In sv, this message translates to:
  /// **'{coverage}% täckning'**
  String allergenCoverageLabel(int coverage);

  /// No description provided for @ingredientDataUnverified.
  ///
  /// In sv, this message translates to:
  /// **'Viss ingrediensdata är overifierad'**
  String get ingredientDataUnverified;

  /// No description provided for @recipeStartCookingTooltip.
  ///
  /// In sv, this message translates to:
  /// **'Börja laga'**
  String get recipeStartCookingTooltip;

  /// No description provided for @taggingDegradedWarning.
  ///
  /// In sv, this message translates to:
  /// **'Allergen- och kostdata kan vara opålitlig'**
  String get taggingDegradedWarning;

  /// No description provided for @recipeEditTags.
  ///
  /// In sv, this message translates to:
  /// **'Redigera taggar'**
  String get recipeEditTags;

  /// No description provided for @allergenDisclaimer.
  ///
  /// In sv, this message translates to:
  /// **'Allergeninformation baseras på automatisk analys och är endast vägledande. Kontrollera alltid originalreceptet och produktförpackningar. Ersätter inte medicinsk rådgivning.'**
  String get allergenDisclaimer;

  /// No description provided for @allergenToggleSemantics.
  ///
  /// In sv, this message translates to:
  /// **'Växla spårning av {allergen}'**
  String allergenToggleSemantics(String allergen);

  /// No description provided for @dietaryToggleSemantics.
  ///
  /// In sv, this message translates to:
  /// **'Växla kostpreferens {dietary}'**
  String dietaryToggleSemantics(String dietary);

  /// No description provided for @emailVerificationTitle.
  ///
  /// In sv, this message translates to:
  /// **'Verifiera din e-post'**
  String get emailVerificationTitle;

  /// No description provided for @emailVerificationMessage.
  ///
  /// In sv, this message translates to:
  /// **'Vi har skickat ett verifieringsmail till {email}.'**
  String emailVerificationMessage(String email);

  /// No description provided for @emailVerificationResend.
  ///
  /// In sv, this message translates to:
  /// **'Skicka igen'**
  String get emailVerificationResend;

  /// No description provided for @emailVerificationContinue.
  ///
  /// In sv, this message translates to:
  /// **'Fortsätt ändå'**
  String get emailVerificationContinue;

  /// No description provided for @emailVerificationSuccess.
  ///
  /// In sv, this message translates to:
  /// **'E-post verifierad!'**
  String get emailVerificationSuccess;
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
