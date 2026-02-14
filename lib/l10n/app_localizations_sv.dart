// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Swedish (`sv`).
class AppLocalizationsSv extends AppLocalizations {
  AppLocalizationsSv([String locale = 'sv']) : super(locale);

  @override
  String get commonSave => 'Spara';

  @override
  String get commonCancel => 'Avbryt';

  @override
  String get commonDelete => 'Ta bort';

  @override
  String get commonEdit => 'Redigera';

  @override
  String get commonAdd => 'Lägg till';

  @override
  String get commonCreate => 'Skapa';

  @override
  String get commonUpdate => 'Uppdatera';

  @override
  String get commonClose => 'Stäng';

  @override
  String get commonShare => 'Dela';

  @override
  String get commonRename => 'Byt namn';

  @override
  String get commonExport => 'Exportera';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Ja';

  @override
  String get commonNo => 'Nej';

  @override
  String get commonRetry => 'Försök igen';

  @override
  String get commonLoading => 'Laddar...';

  @override
  String get commonWorking => 'Arbetar...';

  @override
  String get commonDeleting => 'Tar bort...';

  @override
  String get commonYou => 'Du';

  @override
  String get commonSend => 'Skicka';

  @override
  String get shoppingRenameList => 'Byt namn på lista';

  @override
  String get shoppingCreateList => 'Skapa ny inköpslista';

  @override
  String get shoppingNewName => 'Nytt namn';

  @override
  String get shoppingListName => 'Namn på lista';

  @override
  String get shoppingAddToList => 'Lägg till i';

  @override
  String get shoppingItemName => 'Varunamn';

  @override
  String get shoppingAmount => 'Mängd';

  @override
  String get shoppingUnit => 'Enhet';

  @override
  String get shoppingCategory => 'Kategori';

  @override
  String get shoppingNote => 'Anteckning';

  @override
  String get shoppingAddItem => 'Lägg till vara';

  @override
  String get shoppingEditItem => 'Redigera vara';

  @override
  String get shoppingList => 'Inköpslista';

  @override
  String get authResetPassword => 'Återställ lösenord';

  @override
  String get authForgotPassword => 'Glömt lösenord?';

  @override
  String get authEnterPassword => 'Ange ditt lösenord';

  @override
  String get authPasswordMinLength => 'Minst 6 tecken';

  @override
  String get authResetPasswordInstructions =>
      'Ange din email-adress så skickar vi instruktioner för att återställa ditt lösenord.';

  @override
  String get navExitApp => 'Avsluta Butlery?';

  @override
  String get navExitAppConfirmation => 'Vill du verkligen avsluta appen?';

  @override
  String get navExit => 'Avsluta';

  @override
  String get imageAddImage => 'Lägg till bild';

  @override
  String get imageTakePhoto => 'Ta foto';

  @override
  String get imageUseCamera => 'Använd kameran';

  @override
  String get imageFromGallery => 'Välj från galleri';

  @override
  String get imageSelectFromGallery => 'Välj från galleri';

  @override
  String imageSelectUpTo(int count) {
    return 'Välj upp till $count bilder';
  }

  @override
  String validationFieldRequired(String fieldName) {
    return '$fieldName krävs';
  }

  @override
  String validationFieldTooShort(String fieldName, int minLength) {
    return '$fieldName måste vara minst $minLength tecken';
  }

  @override
  String validationFieldTooLong(String fieldName, int maxLength) {
    return '$fieldName får vara max $maxLength tecken';
  }

  @override
  String validationInvalidFormat(String fieldName) {
    return 'Ogiltigt format för $fieldName';
  }

  @override
  String get validationNameRequired => 'Namn krävs';

  @override
  String get validationEmailRequired => 'E-post krävs';

  @override
  String get validationPasswordRequired => 'Lösenord krävs';

  @override
  String get validationInvalidEmail => 'Ogiltig e-postadress';

  @override
  String get validationInvalidUrl => 'Ogiltig URL';

  @override
  String get validationInvalidPhone => 'Ogiltigt telefonnummer';

  @override
  String get validationInvalidAmount => 'Ogiltigt antal';

  @override
  String get validationPasswordTooShort =>
      'Lösenordet måste vara minst 6 tecken';

  @override
  String get validationGenericRequired => 'Detta fält krävs';

  @override
  String get validationEmailInvalid => 'Ogiltig e-postadress';

  @override
  String get errorGeneric => 'Ett fel uppstod. Försök igen.';

  @override
  String get errorNetwork => 'Nätverksfel. Kontrollera din internetanslutning.';

  @override
  String get errorServer => 'Serverfel. Försök igen senare.';

  @override
  String get errorAuthentication => 'Autentiseringsfel. Logga in igen.';

  @override
  String get errorPermissionDenied =>
      'Du har inte behörighet för denna åtgärd.';

  @override
  String get errorNotFound => 'Kunde inte hittas.';

  @override
  String get errorAlreadyExists => 'Finns redan.';

  @override
  String errorCouldNotCreate(String itemType) {
    return 'Kunde inte skapa $itemType. Försök igen.';
  }

  @override
  String errorCouldNotUpdate(String itemType) {
    return 'Kunde inte uppdatera $itemType. Försök igen.';
  }

  @override
  String errorCouldNotDelete(String itemType) {
    return 'Kunde inte ta bort $itemType. Försök igen.';
  }

  @override
  String errorCouldNotLoad(String itemType) {
    return 'Kunde inte ladda $itemType. Försök igen.';
  }

  @override
  String errorWithContext(String action, String error) {
    return 'Fel vid $action: $error';
  }

  @override
  String errorActionSpecific(String action, String issue) {
    return 'Problem medan $action: $issue';
  }

  @override
  String successItemCreated(String itemType) {
    return '$itemType skapades!';
  }

  @override
  String successItemUpdated(String itemType) {
    return '$itemType uppdaterades!';
  }

  @override
  String successItemDeleted(String itemType) {
    return '$itemType togs bort!';
  }

  @override
  String successItemAdded(String itemName) {
    return '$itemName tillagd!';
  }

  @override
  String confirmDeleteItem(String itemName) {
    return 'Är du säker på att du vill ta bort \"$itemName\"?';
  }

  @override
  String get confirmUnsavedChanges =>
      'Du har osparade ändringar. Vill du lämna utan att spara?';

  @override
  String get confirmIrreversibleAction => 'Denna åtgärd kan inte ångras.';

  @override
  String get draftRecovery => 'Återställ utkast';

  @override
  String get draftRecoverySubtitle =>
      'Du har osparade receptutkast. Vill du fortsätta där du slutade?';

  @override
  String get draftRestore => 'Återställ';

  @override
  String get draftStartFresh => 'Börja om';

  @override
  String get draftRestored => 'Utkast återställt!';

  @override
  String get draftRestoredDetails => 'fält laddades';

  @override
  String get draftCouldNotRestore =>
      'Kunde inte återställa utkast. Börjar med tomt formulär.';

  @override
  String get draftRestoring => 'Återställer utkast...';

  @override
  String get draftUnnamedRecipe => 'Namnlöst recept';

  @override
  String draftFieldsFilledCount(int count) {
    return '$count fält ifyllda';
  }

  @override
  String draftRestoredWithCount(int count) {
    return 'Utkast återställt! $count fält laddades';
  }

  @override
  String get connectivityOfflineMode => 'Offline-läge aktiverat';

  @override
  String get connectivityRestored => 'Anslutning återställd';

  @override
  String get connectivitySyncingPending =>
      'Synkroniserar väntande ändringar...';

  @override
  String get connectivityLocalSaved => 'Ändringar sparade lokalt';

  @override
  String get connectivityWillSync => 'Synkroniseras när du är online igen';

  @override
  String get permissionInsufficient => 'Otillräckliga behörigheter';

  @override
  String get permissionReadOnly => 'Endast läsrättigheter';

  @override
  String get permissionOwnerOnly => 'Endast ägaren kan utföra denna åtgärd';

  @override
  String get permissionRequestEdit => 'Be om redigeringsrättigheter';

  @override
  String get permissionMakePersonalCopy => 'Skapa personlig kopia';

  @override
  String get recoveryCheckConnection => 'Kontrollera internetanslutningen';

  @override
  String get recoveryTryAgain => 'Försök igen';

  @override
  String get recoveryLoginAgain => 'Logga in på nytt';

  @override
  String get recoveryContactOwner => 'Kontakta ägaren';

  @override
  String get recoveryWaitAndRetry => 'Vänta och försök igen';

  @override
  String get recoveryCheckPermissions => 'Kontrollera behörigheter';

  @override
  String get emptyNoItems => 'Inga objekt hittades.';

  @override
  String get emptyList => 'Listan är tom.';

  @override
  String get emptyNoResults => 'Inga resultat hittades.';

  @override
  String get emptyNoFriends => 'Du har inga vänner än.';

  @override
  String get emptyNoRecipes => 'Du har inga recept än.';

  @override
  String get emptyNoShoppingLists => 'Du har inga inköpslistor än.';

  @override
  String emptyNoRecipesSubtitle(String addButton) {
    return 'Lägg till ditt första recept genom att trycka på \"$addButton\"';
  }

  @override
  String get emptyNoSearchResultsSubtitle =>
      'Prova att söka på något annat eller rensa sökningen';

  @override
  String get emptyNoFriendsSearchTitle => 'Inga vänner matchade din sökning';

  @override
  String get emptyNoGroupsSearchTitle => 'Inga grupper matchade din sökning';

  @override
  String get emptyNoMenuTitle => 'Ingen meny genererad ännu';

  @override
  String get emptyNoMenuSubtitle =>
      'Skriv vad du vill ha eller tryck på knappen nedan';

  @override
  String get emptyNoShoppingListTitle =>
      'Ingen meny att skapa inköpslista från';

  @override
  String get emptyNoShoppingListSubtitle =>
      'Gå tillbaka och skapa en veckomeny först';

  @override
  String get emptyNoFriendsTitle => 'Inga vänner ännu';

  @override
  String get emptyNoFriendsSubtitle =>
      'Lägg till vänner för att dela recept och menyer';

  @override
  String get emptyNoCategoriesTitle => 'Inga kategorier skapade';

  @override
  String get emptyNoCategoriesSubtitle =>
      'Skapa din första kategori för att organisera dina vänner';

  @override
  String get emptyNoImagesTitle => 'Inga bilder tillagda';

  @override
  String get emptyNoImagesSubtitle =>
      'Lägg till bilder för att göra ditt recept mer attraktivt';

  @override
  String get emptyNoTargetsTitle => 'Inga destinationer tillgängliga';

  @override
  String get emptyNoTargetsSubtitle =>
      'Lägg till vänner eller grupper för att kunna dela innehåll';

  @override
  String get emptyNoSavedMenusTitle => 'Inga sparade menyer';

  @override
  String get emptyNoSavedMenusSubtitle =>
      'Skapa och spara menyer för att enkelt ladda dem senare';

  @override
  String get emptyGenericTitle => 'Inget innehåll att visa';

  @override
  String get recipeName => 'Receptnamn';

  @override
  String get recipeDescription => 'Beskrivning';

  @override
  String get recipeIngredients => 'Ingredienser';

  @override
  String get recipeInstructions => 'Instruktioner';

  @override
  String get recipeCookingTime => 'Tillagningstid';

  @override
  String get recipePortions => 'Portioner';

  @override
  String get recipeAdd => 'Lägg till recept';

  @override
  String get recipeEdit => 'Redigera recept';

  @override
  String get recipeDelete => 'Ta bort recept';

  @override
  String get recipeDeleting => 'Tar bort recept...';

  @override
  String recipeFormatPortions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portioner',
      one: '1 portion',
    );
    return '$_temp0';
  }

  @override
  String get socialFriendName => 'Vännamn';

  @override
  String get socialGroupName => 'Gruppnamn';

  @override
  String get socialDisplayName => 'Visningsnamn';

  @override
  String get socialCreateGroup => 'Skapa grupp';

  @override
  String get socialEditGroup => 'Redigera grupp';

  @override
  String get socialDeleteGroup => 'Ta bort grupp';

  @override
  String get socialAddFriend => 'Lägg till vän';

  @override
  String get socialRemoveFriend => 'Ta bort vän';

  @override
  String get socialSendFriendRequest => 'Skicka vänförfrågan';

  @override
  String get socialAcceptFriendRequest => 'Acceptera vänförfrågan';

  @override
  String get socialDeclineFriendRequest => 'Avböj vänförfrågan';

  @override
  String get menuName => 'Menynamn';

  @override
  String get menuSave => 'Spara meny';

  @override
  String get menuLoad => 'Ladda meny';

  @override
  String get menuWeek => 'Veckomeny';

  @override
  String get messagingTitle => 'Meddelanden';

  @override
  String get messagingNewConversation => 'Ny konversation';

  @override
  String get messagingSearchConversations => 'Sök konversationer...';

  @override
  String get messagingLoadingConversations => 'Laddar konversationer...';

  @override
  String get messagingNoConversationsFound => 'Inga konversationer hittades';

  @override
  String get messagingTryAnotherSearch => 'Försök med ett annat sökord';

  @override
  String get messagingNoConversationsYet => 'Inga konversationer än';

  @override
  String get messagingStartFirstConversation =>
      'Starta din första konversation genom att trycka på meddelande-knappen';

  @override
  String get messagingMarkAsRead => 'Markera som läst';

  @override
  String get messagingGroupInfo => 'Gruppinformation';

  @override
  String get messagingLeaveGroup => 'Lämna grupp';

  @override
  String get messagingViewProfile => 'Visa profil';

  @override
  String get messagingDeleteConversation => 'Radera konversation';

  @override
  String get messagingLeftGroup => 'Du har lämnat gruppen';

  @override
  String messagingCouldNotLeaveGroup(String error) {
    return 'Kunde inte lämna gruppen: $error';
  }

  @override
  String get messagingLeave => 'Lämna';

  @override
  String get messagingDeleteConversationConfirm =>
      'Är du säker på att du vill radera denna konversation? Alla meddelanden kommer att försvinna.';

  @override
  String messagingCouldNotShowProfile(String error) {
    return 'Kunde inte visa profil: $error';
  }

  @override
  String messagingConversationDeleted(String title) {
    return 'Konversation \"$title\" raderad';
  }

  @override
  String messagingCouldNotDeleteConversation(String error) {
    return 'Kunde inte radera konversation: $error';
  }

  @override
  String messagingConfirmLeaveGroup(String groupName) {
    return 'Är du säker på att du vill lämna \"$groupName\"?';
  }

  @override
  String get profileLogout => 'Logga ut';

  @override
  String get profileLogoutConfirm => 'Är du säker på att du vill logga ut?';

  @override
  String get profileDeleteAccount => 'Radera konto permanent';

  @override
  String get profileDeleteWarningTitle => 'VARNING: Detta kommer att:';

  @override
  String get profileDeleteWarningRecipes => 'Ta bort alla dina recept';

  @override
  String get profileDeleteWarningMenus => 'Ta bort alla dina menyer';

  @override
  String get profileDeleteWarningShoppingLists =>
      'Ta bort alla dina shoppinglistor';

  @override
  String get profileDeleteWarningFriends =>
      'Ta bort alla vänner och meddelanden';

  @override
  String get profileDeleteWarningSharedContent => 'Ta bort all delad innehåll';

  @override
  String get profileDeleteIrreversible => 'Denna åtgärd kan INTE ångras!';

  @override
  String get profileDeleteConfirmButton => 'Jag förstår, radera mitt konto';

  @override
  String get profileConfirmWithPassword => 'Bekräfta med lösenord';

  @override
  String get profileEnterPasswordToConfirm =>
      'Ange ditt lösenord för att bekräfta raderingen:';

  @override
  String get profilePassword => 'Lösenord';

  @override
  String get profileConfirm => 'Bekräfta';

  @override
  String get profileError => 'Fel';

  @override
  String profileCouldNotDeleteAccount(String error) {
    return 'Kunde inte radera konto: $error';
  }

  @override
  String get chatErrorOccurred => 'Ett fel uppstod';

  @override
  String get chatConversationInfo => 'Konversationsinfo';

  @override
  String get chatTypeDirectMessage => 'Typ: Direktmeddelande';

  @override
  String chatCreatedAt(String date) {
    return 'Skapad: $date';
  }

  @override
  String get chatNotificationSettingsUpdated =>
      'Notifikationsinställningar uppdaterade';

  @override
  String get chatCouldNotChangeNotifications =>
      'Kunde inte ändra notifikationsinställningar';

  @override
  String get chatLeaveConversation => 'Lämna konversation';

  @override
  String get chatLeaveConversationConfirm =>
      'Är du säker på att du vill lämna denna konversation?';

  @override
  String get chatCouldNotLeaveConversation => 'Kunde inte lämna konversationen';

  @override
  String get chatEditMessage => 'Redigera meddelande';

  @override
  String get chatWriteYourMessage => 'Skriv ditt meddelande...';

  @override
  String get chatCouldNotEditMessage => 'Kunde inte redigera meddelandet';

  @override
  String get chatCouldNotDeleteMessage => 'Kunde inte ta bort meddelandet';

  @override
  String get chatMessageCopied => 'Meddelande kopierat';

  @override
  String get chatCouldNotCopyMessage => 'Kunde inte kopiera meddelandet';

  @override
  String get chatYourRecipes => 'Dina recept';

  @override
  String get chatSharedRecipe => 'Delat recept';

  @override
  String get chatCheckOutRecipe => 'Kolla in detta recept!';

  @override
  String get chatCouldNotShareRecipe => 'Kunde inte dela recept';

  @override
  String get chatMenuSharingComingSoon => 'Menydelning kommer snart';

  @override
  String get chatCouldNotShareMenu => 'Kunde inte dela meny';

  @override
  String get chatShoppingListSharingComingSoon =>
      'Inköpslistedelning kommer snart';

  @override
  String get chatCouldNotShareShoppingList => 'Kunde inte dela inköpslista';

  @override
  String get chatLoadingImage => 'Laddar bild...';

  @override
  String get chatImageSent => 'Bild skickad!';

  @override
  String get chatNoImageSelected => 'Ingen bild vald';

  @override
  String get chatCouldNotSharePhoto => 'Kunde inte dela foto';

  @override
  String get chatDeleteMessage => 'Ta bort';

  @override
  String get chatDeleteMessageConfirm =>
      'Är du säker på att du vill ta bort meddelandet?';

  @override
  String get placeholderSearch => 'Sök...';

  @override
  String get placeholderName => 'Ange namn';

  @override
  String get placeholderDescription => 'Ange beskrivning (valfritt)';

  @override
  String get placeholderEmail => 'din@email.com';

  @override
  String get placeholderUrl => 'https://exempel.se';

  @override
  String get placeholderPhone => '+46 70 123 45 67';

  @override
  String get statusConnecting => 'Ansluter...';

  @override
  String get statusSyncing => 'Synkroniserar...';

  @override
  String get statusUploading => 'Laddar upp...';

  @override
  String get statusDownloading => 'Laddar ner...';

  @override
  String get statusProcessing => 'Bearbetar...';

  @override
  String get statusSaving => 'Sparar...';

  @override
  String get statusDeleting => 'Tar bort...';

  @override
  String get statusCreating => 'Skapar...';

  @override
  String get statusUpdating => 'Uppdaterar...';

  @override
  String get accessibilityMenuButton => 'Menyknapp';

  @override
  String get accessibilityBackButton => 'Tillbaka';

  @override
  String get accessibilityCloseButton => 'Stäng';

  @override
  String get accessibilityMoreOptions => 'Fler alternativ';

  @override
  String get accessibilityExpandButton => 'Expandera';

  @override
  String get accessibilityCollapseButton => 'Kollapsa';

  @override
  String get timeToday => 'Idag';

  @override
  String get timeYesterday => 'Igår';

  @override
  String get timeTomorrow => 'Imorgon';

  @override
  String get timeThisWeek => 'Denna vecka';

  @override
  String get timeLastWeek => 'Förra veckan';

  @override
  String get timeNextWeek => 'Nästa vecka';

  @override
  String get unitMinutesShort => 'min';

  @override
  String get unitHoursShort => 'h';

  @override
  String get unitPiecesShort => 'st';

  @override
  String get unitLiters => 'liter';

  @override
  String get unitKilograms => 'kg';

  @override
  String get unitGrams => 'g';

  @override
  String get technicalShowDetails => 'Visa tekniska detaljer';

  @override
  String get technicalHideDetails => 'Dölj tekniska detaljer';

  @override
  String get technicalInformation => 'Teknisk information';

  @override
  String get technicalContactSupport => 'Kontakta support';

  @override
  String get technicalTryAgainLater => 'Försök igen senare';

  @override
  String get dialogErrorTitle => 'Ett fel uppstod';

  @override
  String get dialogLoading => 'Laddar...';

  @override
  String get dialogConfirmDeleteTitle => 'Bekräfta borttagning';

  @override
  String dialogConfirmDeleteMessage(String itemName, String itemType) {
    return 'Är du säker på att du vill ta bort $itemName från $itemType?';
  }

  @override
  String get recipePortionAbbreviation => 'port';

  @override
  String get recipePortionSingular => 'portion';

  @override
  String get recipePortionsPlural => 'portioner';

  @override
  String get recipeCookedToday => 'Lagat idag';

  @override
  String get recipeCookedTodaySuccess => 'Recept markerat som lagat idag!';

  @override
  String get recipeCookedTodayError => 'Kunde inte markera som lagat';

  @override
  String get recipeNoInstructions => 'Inga instruktioner angivna.';

  @override
  String get recipeTags => 'Taggar';

  @override
  String get recipeImagesTitle => 'Bilder';

  @override
  String recipeImageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bilder',
      one: '1 bild',
    );
    return '$_temp0';
  }

  @override
  String get recipePersonalTags => 'Personliga taggar';

  @override
  String recipeIngredientsForPortions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'portioner',
      one: 'portion',
    );
    return 'Ingredienser för $count $_temp0:';
  }

  @override
  String get recipeAnalysisFailed => 'Analys misslyckades';

  @override
  String get recipeAnalyzing => 'Analyseras...';

  @override
  String get recipeAnalysisFailedA11y => 'Ingrediensanalys misslyckades';

  @override
  String get recipeAnalyzingA11y => 'Ingredienser analyseras';

  @override
  String get recipeSearchHint => 'sök bland recepten...';

  @override
  String get recipeShowMore => 'Visa fler recept';

  @override
  String recipeCountBadge(int count) {
    return '$count recept';
  }

  @override
  String get scalerPortionsLabel => 'Portioner:';

  @override
  String get scalerUsingSwedishUnits => 'Använder svenska enheter';

  @override
  String get scalerConvertAmericanUnits => 'Konvertera amerikanska enheter';

  @override
  String scalerScaledFromTo(int from, int to) {
    return 'Skalat från $from till $to portioner';
  }

  @override
  String get scalerAmericanConverted =>
      'Amerikanska enheter konverterade till svenska';

  @override
  String get menuPromptQuestion => 'Vad vill du ha för meny?';

  @override
  String get menuPromptHint => 'Ex: 3 middagar, 2 luncher och 1 frukost';

  @override
  String get menuGenerating => 'Genererar...';

  @override
  String get menuGenerateNew => 'Generera ny meny';

  @override
  String get menuGenerate => 'Generera meny';

  @override
  String get menuYourWeeklyMenu => 'Din veckomeny';

  @override
  String menuRecipeCount(int count) {
    return '$count recept';
  }

  @override
  String get menuChooseManually => 'Välj recept manuellt';

  @override
  String get menuNoMoreRecipes => 'Inga fler recept tillgängliga för byte';

  @override
  String get menuGenerateError => 'Kunde inte generera meny';

  @override
  String menuWeekBadgeWithCount(int week, int count) {
    return 'Vecka $week · $count rätter';
  }

  @override
  String menuWeekBadge(int week) {
    return 'Vecka $week';
  }

  @override
  String get menuToShoppingList => 'Till inköpslista';

  @override
  String get menuLoadSaved => 'Ladda sparad meny';

  @override
  String get menuClear => 'Rensa meny';

  @override
  String get menuShared => 'Veckomeny delad!';

  @override
  String get menuGeneratingOverlay => 'Genererar din veckomeny...';

  @override
  String get menuGeneratingSubtitle =>
      'Hittar recept som passar dina preferenser';

  @override
  String shoppingCountBadge(int items, int done) {
    return '$items varor · $done klara';
  }

  @override
  String get commonSort => 'Sortera';

  @override
  String get commonHide => 'Dölj';

  @override
  String commonShowAllCount(int count) {
    return 'Visa alla ($count)';
  }

  @override
  String commonMoreCount(int count) {
    return '+$count till';
  }

  @override
  String get commonDismiss => 'Avfärda';

  @override
  String get errorUnexpected => 'Ett oväntat fel uppstod';

  @override
  String get searchClearSearch => 'Rensa sökning';

  @override
  String get searchClearFilters => 'Rensa filter';

  @override
  String get syncComplete => 'Synkronisering klar!';

  @override
  String syncFailed(String error) {
    return 'Synkronisering misslyckades: $error';
  }

  @override
  String get offlineShowingLocal => 'Offline-läge - visar lokala recept';

  @override
  String get recipeCreateCopy => 'Skapa kopia';

  @override
  String get recipeCreateShoppingList => 'Skapa inköpslista';

  @override
  String get recipeUpdateTags => 'Uppdatera taggar';

  @override
  String get recipeViewSource => 'Visa källa';

  @override
  String get recipeShareWithFriends => 'Dela med vänner';

  @override
  String get recipeShareExternal => 'Dela externt';

  @override
  String recipeSourceFrom(String host) {
    return 'Från $host';
  }

  @override
  String get errorCouldNotOpenLink => 'Kunde inte öppna länk';

  @override
  String get errorInvalidLink => 'Ogiltig länk';

  @override
  String shoppingItemRemoved(String name) {
    return '$name borttagen!';
  }

  @override
  String shoppingItemRemoveError(String name) {
    return 'Kunde inte ta bort $name';
  }

  @override
  String get shoppingAllUnchecked => 'Alla artiklar avbockade!';

  @override
  String get shoppingNoListForRename => 'Ingen lista vald för att byta namn';

  @override
  String get shoppingNoListForDelete => 'Ingen lista vald för borttagning';

  @override
  String get commonBack => 'Tillbaka';

  @override
  String get commonEnable => 'Aktivera';

  @override
  String get commonDisable => 'Inaktivera';

  @override
  String get commonName => 'Namn';

  @override
  String get commonShowDetails => 'Visa detaljer';

  @override
  String get commonEditName => 'Redigera namn';

  @override
  String get commonErrorOccurred => 'Ett fel uppstod';

  @override
  String get commonContinue => 'Fortsätt';

  @override
  String get commonNext => 'Nästa';

  @override
  String get commonPrevious => 'Föregående';

  @override
  String get commonSkip => 'Hoppa över';

  @override
  String get commonSkipAll => 'Hoppa över alla';

  @override
  String get commonSaveAndClose => 'Spara och stäng';

  @override
  String get commonSaveAndNext => 'Spara och nästa';

  @override
  String get commonSaveChanges => 'Spara ändringar';

  @override
  String get commonSaveMyCopy => 'Spara min kopia';

  @override
  String get commonSaveAsNew => 'Spara som ny';

  @override
  String get commonSelectAll => 'Välj alla';

  @override
  String get commonDeselectAll => 'Avmarkera alla';

  @override
  String get commonClearAll => 'Rensa alla';

  @override
  String get commonClear => 'Rensa';

  @override
  String get commonImage => 'Bild';

  @override
  String get commonSettings => 'Inställningar';

  @override
  String get commonLogout => 'Logga ut';

  @override
  String get commonLogoutNow => 'Logga ut nu';

  @override
  String get commonNoAccess => 'Ingen åtkomst';

  @override
  String get commonCreatingCopy => 'Skapar kopia...';

  @override
  String get commonToHome => 'Till start';

  @override
  String get commonTakePhoto => 'Ta foto';

  @override
  String get commonSelectFromGallery => 'Välj från galleri';

  @override
  String get commonSelectFriends => 'Välj vänner';

  @override
  String get commonNoContent => 'Inget innehåll';

  @override
  String commonRemoveLabel(String label) {
    return 'Ta bort $label';
  }

  @override
  String get personalTagsViewTitle => 'Personliga taggar';

  @override
  String get personalTagCreateTag => 'Skapa tagg';

  @override
  String get personalTagCreateGroup => 'Skapa grupp';

  @override
  String get personalTagEmptyTitle => 'Inga personliga taggar';

  @override
  String get personalTagEmptySubtitle =>
      'Skapa taggar för att organisera dina recept';

  @override
  String get personalTagSectionTags => 'Taggar';

  @override
  String get personalTagDeleteGroup => 'Ta bort grupp';

  @override
  String get personalTagGroupEmpty => 'Inga taggar i denna grupp';

  @override
  String personalTagRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept',
      one: '1 recept',
    );
    return '$_temp0';
  }

  @override
  String personalTagRuleCount(int count) {
    return '$count regler';
  }

  @override
  String personalTagRuleCountActive(int enabled, int total) {
    return '$enabled/$total regler aktiva';
  }

  @override
  String get personalTagNoUsage => 'Ingen användning';

  @override
  String get personalTagEnableAllRules => 'Aktivera alla regler';

  @override
  String get personalTagDisableAllRules => 'Inaktivera alla regler';

  @override
  String personalTagRulesDisabled(int count) {
    return '$count regler inaktiverade';
  }

  @override
  String personalTagRulesActive(int count) {
    return '$count regler aktiva';
  }

  @override
  String get personalTagMoveToGroup => 'Flytta till grupp';

  @override
  String get personalTagDeleteTag => 'Ta bort tagg';

  @override
  String get personalTagEnableAllRulesConfirm => 'Aktivera alla regler?';

  @override
  String get personalTagDisableAllRulesConfirm => 'Inaktivera alla regler?';

  @override
  String personalTagEnableAllRulesMessage(int count, String name) {
    return 'Alla $count regler för \"$name\" kommer att aktiveras.';
  }

  @override
  String personalTagDisableAllRulesMessage(int count, String name) {
    return 'Alla $count regler för \"$name\" kommer att inaktiveras.';
  }

  @override
  String get personalTagAllRulesEnabled => 'Alla regler aktiverade';

  @override
  String get personalTagAllRulesDisabled => 'Alla regler inaktiverade';

  @override
  String get personalTagCouldNotChangeRules => 'Kunde inte ändra reglerna';

  @override
  String get personalTagNameLabel => 'Taggnamn';

  @override
  String get personalTagNameHint => 'T.ex. Favoriter';

  @override
  String get personalTagCreated => 'Tagg skapad';

  @override
  String get personalTagCouldNotCreate => 'Kunde inte skapa taggen';

  @override
  String get personalTagGroupNameLabel => 'Gruppnamn';

  @override
  String get personalTagGroupNameHint => 'T.ex. Middagar';

  @override
  String get personalTagGroupCreated => 'Grupp skapad';

  @override
  String get personalTagCouldNotCreateGroup => 'Kunde inte skapa gruppen';

  @override
  String get personalTagEditTag => 'Redigera tagg';

  @override
  String get personalTagUpdated => 'Tagg uppdaterad';

  @override
  String get personalTagDeleteTagConfirm => 'Ta bort tagg?';

  @override
  String personalTagDeleteTagMessage(String name) {
    return 'Är du säker på att du vill ta bort \"$name\"? Taggen tas bort från alla recept.';
  }

  @override
  String get personalTagDeleted => 'Tagg borttagen';

  @override
  String get personalTagNoGroup => 'Ingen grupp';

  @override
  String get personalTagCreateNewGroup => 'Skapa ny grupp';

  @override
  String get personalTagMoved => 'Tagg flyttad';

  @override
  String get personalTagGroupCreatedAndTagMoved =>
      'Grupp skapad och tagg flyttad';

  @override
  String get personalTagRenameGroup => 'Byt namn på grupp';

  @override
  String get personalTagGroupUpdated => 'Grupp uppdaterad';

  @override
  String get personalTagDeleteGroupConfirm => 'Ta bort grupp?';

  @override
  String personalTagDeleteGroupMessage(String name) {
    return 'Är du säker på att du vill ta bort \"$name\"? Taggar i gruppen blir ogrupperade.';
  }

  @override
  String get personalTagGroupDeleted => 'Grupp borttagen';

  @override
  String get personalTagSortByName => 'Namn';

  @override
  String get personalTagSortByUsage => 'Användning';

  @override
  String get personalTagSortByRuleCount => 'Antal regler';

  @override
  String personalTagTileSemantics(
      String name, int count, int enabled, int total) {
    return '$name, $count recept, $enabled av $total regler aktiva';
  }

  @override
  String get tagDetailDefaultTitle => 'Tagg';

  @override
  String get tagDetailNotFound => 'Taggen kunde inte hittas';

  @override
  String get tagDetailEditTitle => 'Redigera tagg';

  @override
  String get tagDetailApplyRules => 'Kör regler';

  @override
  String get tagDetailApplyRulesSubtitle => 'Tillämpa på befintliga recept';

  @override
  String get tagDetailNameHint => 'Taggnamn';

  @override
  String get tagDetailNameRequired => 'Taggnamn krävs';

  @override
  String get tagDetailUpdated => 'Tagg uppdaterad';

  @override
  String get tagDetailCouldNotUpdate => 'Kunde inte uppdatera taggen';

  @override
  String get tagDetailRuleCreated => 'Regel skapad';

  @override
  String get tagDetailCouldNotCreateRule => 'Kunde inte skapa regeln';

  @override
  String get tagDetailRuleUpdated => 'Regel uppdaterad';

  @override
  String get tagDetailCouldNotUpdateRule => 'Kunde inte uppdatera regeln';

  @override
  String get tagDetailCouldNotChangeRuleStatus =>
      'Kunde inte ändra regelstatus';

  @override
  String get tagDetailDeleteRuleConfirm => 'Ta bort regel?';

  @override
  String tagDetailDeleteRuleMessage(String name) {
    return 'Är du säker på att du vill ta bort \"$name\"?';
  }

  @override
  String get tagDetailRuleDeleted => 'Regel borttagen';

  @override
  String get tagDetailCouldNotDeleteRule => 'Kunde inte ta bort regeln';

  @override
  String get tagDetailApplyingRules => 'Kör regler på recept...';

  @override
  String tagDetailRulesAppliedSuccess(int tagsApplied, int recipesModified) {
    return '$tagsApplied taggar tillämpade på $recipesModified recept';
  }

  @override
  String get tagDetailNoRecipesMatched => 'Inga recept matchade reglerna';

  @override
  String get tagDetailCouldNotApplyRules => 'Kunde inte köra regler';

  @override
  String get tagDetailDeleteTagConfirm => 'Ta bort tagg?';

  @override
  String tagDetailDeleteTagMessage(String name) {
    return 'Är du säker på att du vill ta bort \"$name\"? Taggen tas bort från alla recept.';
  }

  @override
  String get tagDetailDeleted => 'Tagg borttagen';

  @override
  String get tagDetailCouldNotDelete => 'Kunde inte ta bort taggen';

  @override
  String tagDetailRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept',
      one: '1 recept',
    );
    return '$_temp0';
  }

  @override
  String tagDetailRulesActive(int enabled, int total) {
    return '$enabled/$total regler aktiva';
  }

  @override
  String get tagDetailRuleCalculating => 'Beräknar...';

  @override
  String tagDetailRuleMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept matchar',
      one: '1 recept matchar',
    );
    return '$_temp0';
  }

  @override
  String get tagDetailRuleNoConditions => 'Inga villkor';

  @override
  String get tagDetailRuleOperatorAnd => ' OCH ';

  @override
  String get tagDetailRuleOperatorOr => ' ELLER ';

  @override
  String tagDetailRuleMoreConditions(int count) {
    return '(+$count till)';
  }

  @override
  String get tagDetailRulesDescription =>
      'Regler tillämpar taggen automatiskt på recept som matchar villkoren.';

  @override
  String get tagDetailRulesTitle => 'Automatiseringsregler';

  @override
  String get tagDetailRulesEmptyTitle => 'Inga regler ännu';

  @override
  String get tagDetailRulesEmptySubtitle =>
      'Skapa regler för att automatiskt tagga recept';

  @override
  String get tagDetailRulesCreateFirst => 'Skapa första regeln';

  @override
  String get tagAlreadyExists => 'Taggen finns redan';

  @override
  String get tagManageTags => 'Hantera taggar';

  @override
  String get tagActiveTags => 'Aktiva taggar';

  @override
  String get tagRemovedTags => 'Borttagna taggar';

  @override
  String get tagAddNewTag => 'Lägg till ny tagg';

  @override
  String get tagWriteTagHint => 'Skriv en tagg...';

  @override
  String get tagEnterTag => 'Ange en tagg';

  @override
  String get tagMinTwoChars => 'Minst 2 tecken';

  @override
  String get tagAddTag => 'Lägg till tagg';

  @override
  String get tagManuallyAdded => 'Manuellt tillagd';

  @override
  String get tagAutoGenerated => 'Automatiskt genererad';

  @override
  String get tagClickToRestore => 'Klicka för att återställa';

  @override
  String get allergenSettingsTitle => 'Allergeninställningar';

  @override
  String get allergenTrackAllergensTitle => 'Spåra allergener';

  @override
  String get allergenTrackAllergensSubtitle =>
      'Välj vilka allergener du vill se status för på recept.';

  @override
  String get allergenTrackDietaryTitle => 'Spåra specialkost';

  @override
  String get allergenTrackDietarySubtitle =>
      'Välj vilka kostpreferenser du vill se status för.';

  @override
  String get allergenDisplayTitle => 'Visa på';

  @override
  String get allergenDisplayOnCardsTitle => 'Receptkort';

  @override
  String get allergenDisplayOnCardsSubtitle =>
      'Visa allergenstatus på receptkort i listor';

  @override
  String get allergenDisplayOnDetailTitle => 'Receptdetaljer';

  @override
  String get allergenDisplayOnDetailSubtitle =>
      'Visa fullständig allergenstatus på receptsidan';

  @override
  String get allergenDisplayCoverageTitle => 'Täckningsindikator';

  @override
  String get allergenDisplayCoverageSubtitle =>
      'Visa hur stor andel ingredienser som är kända';

  @override
  String get allergenSaveSettings => 'Spara inställningar';

  @override
  String get allergenResetToDefaults => 'Återställ till standard';

  @override
  String get allergenSettingsSaved => 'Inställningar sparade';

  @override
  String get allergenResetConfirm => 'Återställ inställningar?';

  @override
  String get allergenResetMessage =>
      'Detta återställer alla allergen- och kostpreferenser till standardvärden.';

  @override
  String get allergenReset => 'Återställ';

  @override
  String get personalTagWizardAddRule => 'Lägg till regel?';

  @override
  String personalTagWizardAddRuleMessage(String name) {
    return 'Vill du skapa en automatiseringsregel för \"$name\"?\n\nRegler kan automatiskt lägga till denna tagg på recept baserat på ingredienser, källa, tid, med mera.';
  }

  @override
  String get personalTagWizardLater => 'Senare';

  @override
  String get personalTagWizardYesCreateRule => 'Ja, skapa regel';

  @override
  String get personalTagPreview => 'Förhandsgranskning';

  @override
  String get personalTagCouldNotLoad => 'Kunde inte ladda taggar';

  @override
  String get personalTagManage => 'Hantera';

  @override
  String personalTagChipSelectedA11y(String name) {
    return '$name, vald. Dubbeltryck för att ta bort.';
  }

  @override
  String personalTagChipUnselectedA11y(String name) {
    return '$name. Dubbeltryck för att välja.';
  }

  @override
  String personalTagA11yLabel(String name) {
    return 'Tagg: $name';
  }

  @override
  String get personalTagManagerTitle => 'Mina taggar';

  @override
  String get personalTagManagerRulesTab => 'Regler';

  @override
  String get personalTagNewTag => 'Ny tagg';

  @override
  String get personalTagCreateTagFirst => 'Skapa en tagg först';

  @override
  String get personalTagNeedTagForRules =>
      'Du behöver minst en tagg för att kunna skapa automationsregler.';

  @override
  String personalTagCreatedDate(String date) {
    return 'Skapad $date';
  }

  @override
  String get personalTagCreateRuleForTag => 'Skapa regel för tagg';

  @override
  String get personalTagAddRule => 'Lägg till regel';

  @override
  String get personalTagApplyRulesTitle => 'Kör regler på befintliga recept';

  @override
  String get personalTagApplyRulesMessage =>
      'Detta kommer att granska alla dina recept och lägga till taggar enligt dina aktiverade regler.\n\nTaggar som redan finns på recept påverkas inte.';

  @override
  String get personalTagApplyRulesRun => 'Kör';

  @override
  String personalTagApplyRulesProgress(int progress, int total) {
    return 'Bearbetar recept $progress av $total...';
  }

  @override
  String get personalTagApplyRulesFetching => 'Hämtar recept...';

  @override
  String get personalTagSelectColor => 'Välj färg';

  @override
  String get ruleEditTitle => 'Redigera regel';

  @override
  String get ruleCreateTitle => 'Skapa regel';

  @override
  String get ruleNewTitle => 'Ny regel';

  @override
  String get ruleNameLabel => 'Regelnamn';

  @override
  String get ruleNameHint => 'T.ex. \"Fiskrecept\"';

  @override
  String get ruleNameRequired => 'Ange ett regelnamn';

  @override
  String get ruleApplyToTag => 'Tillämpa på tagg';

  @override
  String get ruleSelectTag => 'Välj en tagg';

  @override
  String get ruleMatchModeLabel => 'Matchningsläge';

  @override
  String get ruleMatchModeAllConditions => 'Alla villkor (AND)';

  @override
  String get ruleMatchModeAnyCondition => 'Något villkor (OR)';

  @override
  String get ruleMatchModeAllShort => 'Alla (AND)';

  @override
  String get ruleMatchModeAnyShort => 'Något (OR)';

  @override
  String get ruleMatchModeAll => 'alla';

  @override
  String get ruleMatchModeAny => 'något';

  @override
  String get ruleConditionsLabel => 'Villkor';

  @override
  String get ruleConditionCountSingular => '1 villkor';

  @override
  String ruleConditionCountWithMode(int count, String mode) {
    return '$count villkor, $mode måste matcha';
  }

  @override
  String get ruleEnabledTitle => 'Regel aktiverad';

  @override
  String get ruleEnabledSubtitle => 'Regeln tillämpas på recept';

  @override
  String get ruleEnabledNewRecipes => 'Regeln tillämpas på nya recept';

  @override
  String get rulePausedSubtitle => 'Regeln är pausad';

  @override
  String get ruleApplyToExisting => 'Applicera på befintliga recept';

  @override
  String get ruleTagMatchingImmediately => 'Tagga matchande recept omedelbart';

  @override
  String get ruleRemoveCondition => 'Ta bort villkor';

  @override
  String get ruleSelectProperty => 'Välj egenskap...';

  @override
  String get ruleAllConditionsNeedValue => 'Alla villkor måste ha ett värde';

  @override
  String get ruleHintIngredient => 'T.ex. \"kyckling\", \"lax\"';

  @override
  String get ruleHintProperty => 'T.ex. \"seafood\", \"meat\", \"dairy\"';

  @override
  String get ruleHintKeyword => 'T.ex. \"snabb\", \"vegetarisk\"';

  @override
  String get ruleHintSourceUrl => 'T.ex. \"bbc.com\", \"reddit.com\"';

  @override
  String get ruleHintCuisine => 'T.ex. \"italian\", \"asian\"';

  @override
  String get ruleHintDietary => 'T.ex. \"vegetarian\", \"vegan\"';

  @override
  String get ruleHintTime => 'Tillagningstid i minuter';

  @override
  String get ruleHintTimeShort => 'Tid i minuter';

  @override
  String get ruleHintRating => 'Betyg (1-5)';

  @override
  String get ruleHintRecency => 'Antal dagar sedan receptet lades till';

  @override
  String get ruleHintRecencyShort => 'Antal dagar';

  @override
  String get ruleHintOwnership =>
      'T.ex. \"personal\", \"shared\", \"collaborative\"';

  @override
  String get ruleHintHasImage => 'true eller false';

  @override
  String get ruleHintCompleteness => 'T.ex. \"description\", \"ingredients\"';

  @override
  String get ruleCategoryAllergens => 'Allergener';

  @override
  String get ruleCategoryLactose => 'Laktos';

  @override
  String get ruleCategoryMeat => 'Kött';

  @override
  String get ruleCategorySeafood => 'Fisk & skaldjur';

  @override
  String get ruleCategoryAnimal => 'Animaliskt';

  @override
  String get ruleCategoryDiet => 'Kost';

  @override
  String get ruleCategoryOther => 'Övrigt';

  @override
  String get tagResultNoAllergens => 'Inga allergener att visa';

  @override
  String get tagResultOutdated => 'Taggarna kan uppdateras';

  @override
  String get tagResultCoverage => 'Täckning';

  @override
  String tagResultUnknownIngredients(int count) {
    return '$count okända ingredienser';
  }

  @override
  String tagResultUnknownIngredientsA11y(int count) {
    return '$count okända ingredienser';
  }

  @override
  String dietaryStatusFreeA11y(String name) {
    return 'Passar för $name kost';
  }

  @override
  String dietaryStatusContainsA11y(String name) {
    return 'Passar ej för $name kost';
  }

  @override
  String dietaryStatusUnknownA11y(String name) {
    return '$name status okänd';
  }

  @override
  String dietaryStatusNotLabel(String name) {
    return 'Ej $name';
  }

  @override
  String allergenStatusFreeA11y(String name) {
    return 'Fri från $name';
  }

  @override
  String allergenStatusContainsA11y(String name) {
    return 'Innehåller $name';
  }

  @override
  String allergenStatusUnknownA11y(String name) {
    return '$name status okänd';
  }

  @override
  String allergenFreeLabel(String name) {
    return '${name}fri';
  }

  @override
  String allergenContainsLabel(String name) {
    return 'innehåller $name';
  }

  @override
  String allergenUnknownLabel(String name) {
    return '$name okänd';
  }

  @override
  String friendMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
    );
    return '$_temp0';
  }

  @override
  String get friendCategoryLabel => 'Kategori';

  @override
  String get friendCategoryStatistics => 'Kategoristatistik';

  @override
  String get friendCategories => 'Kategorier';

  @override
  String get friendTotalMembers => 'Totalt medlemmar';

  @override
  String get friendAverage => 'Genomsnitt';

  @override
  String friendLargestCategory(String name, int count) {
    return 'Största kategori: $name ($count medlemmar)';
  }

  @override
  String friendCategoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kategorier',
      one: '1 kategori',
    );
    return '$_temp0';
  }

  @override
  String friendTotalMembersCount(int count) {
    return '$count totalt medlemmar';
  }

  @override
  String get friendCreateFirstCategory => 'Skapa din första vänkategori';

  @override
  String get friendCreateCategory => 'Skapa kategori';

  @override
  String get friendSelectCategories => 'Välj kategorier';

  @override
  String get friendCreateNewCategory => 'Skapa ny kategori';

  @override
  String get friendSelectedCategories => 'Valda kategorier';

  @override
  String friendSelectedCategoriesSummary(int count, int friends) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kategorier',
      one: '1 kategori',
    );
    return '$_temp0 ($friends vänner)';
  }

  @override
  String friendCategoriesSelected(int count) {
    return '$count kategorier valda';
  }

  @override
  String friendFriendsCount(int count) {
    return '$count vänner';
  }

  @override
  String get friendFriendsLabel => 'vänner';

  @override
  String get friendLoadingFriendsAndCategories =>
      'Laddar vänner och kategorier...';

  @override
  String get friendNoFriendsOrCategories => 'Inga vänner eller kategorier';

  @override
  String get friendAddFriendsAndCategoriesFirst =>
      'Lägg till vänner och skapa kategorier först';

  @override
  String get friendManageFriends => 'Hantera vänner';

  @override
  String get friendSelectCategoriesOrFriends =>
      'Välj kategorier eller individuella vänner';

  @override
  String get friendSelectCategoriesForQuickShare =>
      'Välj hela kategorier för snabb delning';

  @override
  String get friendIndividualSelection => 'Individuellt val';

  @override
  String get friendSelectSpecificFriends =>
      'Välj specifika vänner från din vänlista';

  @override
  String get friendNoFriendsToShow => 'Inga vänner att visa';

  @override
  String get friendAddFriendsFirst => 'Lägg till vänner först';

  @override
  String get friendSelectedFriends => 'Valda vänner';

  @override
  String friendSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vänner valda',
      one: '1 vän vald',
    );
    return '$_temp0';
  }

  @override
  String shoppingItemsWillBeRemoved(int count) {
    return '$count artiklar försvinner.';
  }

  @override
  String shoppingItemsFromMenuIn(int count, String name) {
    return '$count artiklar från menyn i \"$name\"';
  }

  @override
  String get shoppingItemHint => 'T.ex. Mjölk';

  @override
  String get shoppingItems => 'artiklar';

  @override
  String get shoppingPersonal => 'Personlig';

  @override
  String get shoppingShared => 'Delad';

  @override
  String get shoppingTemplate => 'Mall';

  @override
  String get shoppingActive => 'Aktiv';

  @override
  String get shoppingRecentItems => 'Senaste artiklar:';

  @override
  String shoppingAndMore(int count) {
    return '... och $count till';
  }

  @override
  String get shoppingOwner => 'Ägare';

  @override
  String get shoppingCanView => 'Kan se';

  @override
  String get shoppingCanEdit => 'Kan redigera';

  @override
  String get shoppingAdmin => 'Admin';

  @override
  String get shoppingCreateFirstList => 'Skapa din första inköpslista...';

  @override
  String get shoppingCreateListButton => 'Skapa lista';

  @override
  String get shoppingPreviewAndEditItems =>
      'Förhandsgranska och redigera artiklar';

  @override
  String get shoppingNoItemsSelected => 'Inga artiklar valda';

  @override
  String get shoppingAllItemsRemovedFromMenu =>
      'Du har tagit bort alla artiklar från menyn';

  @override
  String get shoppingRemoveItem => 'Ta bort artikel';

  @override
  String get shoppingRemoveAll => 'Ta bort alla';

  @override
  String shoppingToListWithCount(String name, int count) {
    return 'Till \"$name\" ($count)';
  }

  @override
  String get shoppingLoadingLists => 'Laddar listor...';

  @override
  String get shoppingErrorLoading => 'Fel vid laddning';

  @override
  String get shoppingLists => 'Inköpslistor';

  @override
  String get shoppingNewList => 'Ny lista';

  @override
  String get shoppingAddFromMenu => 'Lägg till från meny';

  @override
  String get shoppingNoItemsFromMenu => 'Inga artiklar valda från menyn';

  @override
  String shoppingAddItemsCount(int count) {
    return 'Lägg till $count artiklar...';
  }

  @override
  String get shoppingPreview => 'Förhandsgranska';

  @override
  String get shoppingAdding => 'Lägger till...';

  @override
  String get shoppingNoItemsToAdd => 'Inga artiklar att lägga till';

  @override
  String shoppingListCreated(String name) {
    return 'Lista \"$name\" skapad';
  }

  @override
  String shoppingCouldNotCreateList(String error) {
    return 'Kunde inte skapa lista: $error';
  }

  @override
  String shoppingItemsAddedToList(int count, String name) {
    return '$count artiklar tillagda i \"$name\"';
  }

  @override
  String shoppingCouldNotAddItems(String error) {
    return 'Kunde inte lägga till artiklar: $error';
  }

  @override
  String get profileSocialFeatures => 'Sociala funktioner';

  @override
  String get profileEditProfile => 'Redigera profil';

  @override
  String get profileEditProfileSubtitle => 'Uppdatera ditt namn och profilbild';

  @override
  String get profileFriendsAndGroups => 'Vänner och grupper';

  @override
  String get profileFriendsAndGroupsSubtitle =>
      'Hantera dina vänner och grupper';

  @override
  String get profileSharedWithMe => 'Delat med mig';

  @override
  String get profileSharedWithMeSubtitle =>
      'Recept och menyer som delats med dig';

  @override
  String get profileMessages => 'Meddelanden';

  @override
  String get profileMessagesSubtitle => 'Dina konversationer och meddelanden';

  @override
  String get profileAllergenSettings => 'Allergeninställningar';

  @override
  String get profileAllergenSettingsSubtitle =>
      'Välj vilka allergener du vill spåra';

  @override
  String get profileMyTags => 'Mina taggar';

  @override
  String get profileMyTagsSubtitle => 'Hantera dina personliga taggar';

  @override
  String get profileCloseMenu => 'Stäng profilmeny';

  @override
  String get profileRecipes => 'Recept';

  @override
  String get profileMenus => 'Menyer';

  @override
  String get profileFriends => 'Vänner';

  @override
  String get profileDataAndBackup => 'Data & Backup';

  @override
  String get profileDownloadBackup => 'Ladda ner backup';

  @override
  String get profileDownloadBackupSubtitle => 'Spara alla recept som JSON';

  @override
  String get profileRestoreFromBackup => 'Återställ från backup';

  @override
  String get profileRestoreFromBackupSubtitle => 'Importera recept från JSON';

  @override
  String get profileAccountManagement => 'Kontohantering';

  @override
  String get profilePrivacyPolicy => 'Integritetspolicy';

  @override
  String get profilePrivacyPolicySubtitle =>
      'Läs om hur vi hanterar dina personuppgifter (GDPR)';

  @override
  String get profileManageConsents => 'Hantera samtycken';

  @override
  String get profileManageConsentsSubtitle =>
      'Välj hur vi får behandla dina personuppgifter (GDPR)';

  @override
  String get profileExportMyData => 'Exportera mina data';

  @override
  String get profileExportMyDataSubtitle =>
      'Ladda ner all din data i JSON-format (GDPR)';

  @override
  String get profileDeleteAccountSubtitle =>
      'Ta bort ditt konto och all data permanent';

  @override
  String profileLogoutFailed(String error) {
    return 'Utloggning misslyckades: $error';
  }

  @override
  String get profileAccountDeletedPermanently =>
      'Ditt konto har raderats permanent';

  @override
  String get profileAccountCouldNotBeFullyDeleted =>
      'Kontot kunde inte raderas helt. Kontakta support.';

  @override
  String get profileAuthenticationFailed => 'Autentisering misslyckades';

  @override
  String profileBackupFailed(String error) {
    return 'Backup misslyckades: $error';
  }

  @override
  String get profileRestoreCompleted => 'Återställning genomförd!';

  @override
  String profileRestoreFailed(String error) {
    return 'Återställning misslyckades: $error';
  }

  @override
  String profileCouldNotOpenPrivacyPolicy(String error) {
    return 'Kunde inte öppna integritetspolicy: $error';
  }

  @override
  String profileCouldNotOpenConsentManager(String error) {
    return 'Kunde inte öppna samtyckeshantering: $error';
  }

  @override
  String profileCouldNotOpenDataExport(String error) {
    return 'Kunde inte öppna dataexport: $error';
  }

  @override
  String get shareRecipeTitle => 'Dela recept';

  @override
  String get shareMenuTitle => 'Dela meny';

  @override
  String get shareShoppingListTitle => 'Dela inköpslista';

  @override
  String get shareCreateAndShare => 'Skapa & Dela';

  @override
  String get shareRecipeWithFriends => 'Dela recept med vänner';

  @override
  String get shareMenuWithFriends => 'Dela veckomeny med vänner';

  @override
  String get shareShoppingList => 'Dela inköpslista';

  @override
  String get shareCheckOutRecipe => 'Kolla in detta recept:';

  @override
  String get shareCheckOutMenu => 'Kolla in denna veckomeny:';

  @override
  String get shareCheckOutShoppingList => 'Kolla in denna inköpslista:';

  @override
  String get shareRealtime => 'realtidsdelning';

  @override
  String get shareCopy => 'kopia';

  @override
  String get shareSelectAtLeastOneFriend => 'Välj minst en vän för att dela';

  @override
  String get shareSelected => 'valda';

  @override
  String shareRecipesInCategories(int recipes, int categories) {
    return '$recipes recept i $categories kategorier';
  }

  @override
  String get shareNoFriendsToShareWith => 'Inga vänner att dela med';

  @override
  String get shareAddFriendsToShare =>
      'Du behöver lägga till vänner för att kunna dela innehåll. Gå till din profil och lägg till vänner.';

  @override
  String get shareAddFriends => 'Lägg till vänner';

  @override
  String get shareErrorOccurred => 'Ett fel uppstod';

  @override
  String get shareSucceeded => 'Delning lyckades!';

  @override
  String get shareRecipes => 'recept';

  @override
  String get shareMenus => 'menyer';

  @override
  String get shareShoppingLists => 'inköpslistor';

  @override
  String get shareMessageOptional => 'Meddelande (valfritt)';

  @override
  String get shareWriteMessage => 'Skriv ett meddelande...';

  @override
  String get shareMethod => 'Delningssätt';

  @override
  String get shareStaticCopy => 'Statisk kopia';

  @override
  String get shareStaticCopyDescription =>
      'Skicka en kopia som mottagaren kan ändra fritt';

  @override
  String get shareRealtimeSharing => 'Realtidsdelning';

  @override
  String get shareRealtimeSharingDescription =>
      'Alla kan redigera tillsammans i realtid';

  @override
  String get shareRealtimeShoppingDescription =>
      'Alla kan lägga till och checka av varor i realtid';

  @override
  String get shareSelectRecipients => 'Välj mottagare';

  @override
  String get shareSearchFriends => 'Sök bland vänner...';

  @override
  String get shareSearchGroups => 'Sök bland grupper...';

  @override
  String get shareNoFriendsAvailable => 'Inga vänner tillgängliga';

  @override
  String get shareNoFriendsMatchedSearch => 'Inga vänner matchade din sökning';

  @override
  String get shareNoGroupsAvailable => 'Inga grupper tillgängliga';

  @override
  String get shareNoGroupsMatchedSearch => 'Inga grupper matchade din sökning';

  @override
  String get shareAlreadySharingList => 'Delar redan listan';

  @override
  String get menuSavedMenus => 'Sparade menyer';

  @override
  String get menuNoSavedMenus => 'Inga sparade menyer';

  @override
  String get menuSavedMenusSavedEarlier => 'Sparad tidigare';

  @override
  String get menuLoadMenu => 'Ladda';

  @override
  String get menuRemoveMenu => 'Ta bort';

  @override
  String get menuRemoveMenuTitle => 'Ta bort meny';

  @override
  String get menuMenuNameRequired => 'Menynamn krävs';

  @override
  String get menuMenuToSave => 'Meny att spara';

  @override
  String get menuCommentOptional => 'Kommentar (valfritt)';

  @override
  String get menuCommentHint => 'Beskrivning eller noteringar om menyn';

  @override
  String get menuShareWithFriends => 'Dela med vänner';

  @override
  String get menuShareThisMenu => 'Dela denna meny med valda vänner';

  @override
  String get menuSelectFriendsToShare => 'Välj vänner att dela med';

  @override
  String get menuNoFriendsAvailable => 'Inga vänner tillgängliga';

  @override
  String get menuDefaultShareMessage => 'Kolla min nya veckomeny!';

  @override
  String get menuShareMessageLabel => 'Delningsmeddelande';

  @override
  String get menuShareMessageHint => 'Meddelande som skickas med menyn';

  @override
  String get menuMenuNameHint => 'T.ex. Vecka 45 eller Helgmeny';

  @override
  String get menuUnnamedMenu => 'Namnlös meny';

  @override
  String get socialUnknownUser => 'Okänd användare';

  @override
  String get socialShared => 'Delat';

  @override
  String get socialEditRecipe => 'Redigera recept';

  @override
  String get socialEditingTogether => 'Du redigerar tillsammans med andra';

  @override
  String get socialChangesSyncAutomatically =>
      'Ändringar synkas automatiskt med andra deltagare';

  @override
  String get socialActive => 'Aktiv';

  @override
  String get socialParticipants => 'Deltagare';

  @override
  String get socialViewAll => 'Visa alla';

  @override
  String socialSharedRecipeMembers(int count) {
    return 'Delat recept • $count medlemmar';
  }

  @override
  String socialSharedMenuMembers(int count) {
    return 'Delad meny • $count medlemmar';
  }

  @override
  String get socialActiveCollaboration => 'Aktiv samarbete';

  @override
  String get socialInactive => 'Inte aktivt';

  @override
  String get socialCollaborationStatistics => 'Samarbetsstatistik';

  @override
  String get socialMembers => 'Medlemmar';

  @override
  String get socialActiveEditors => 'Aktiva';

  @override
  String get socialChanges => 'Ändringar';

  @override
  String socialLastActive(String time) {
    return 'Senast aktiv: $time';
  }

  @override
  String get socialJustNow => 'just nu';

  @override
  String socialMinutesAgo(int count) {
    return '$count min sedan';
  }

  @override
  String socialHoursAgo(int count) {
    return '$count timmar sedan';
  }

  @override
  String socialDaysAgo(int count) {
    return '$count dagar sedan';
  }

  @override
  String get socialPermissionOwner => 'Ägare';

  @override
  String get socialPermissionAdmin => 'Admin';

  @override
  String get socialPermissionEditor => 'Redigera';

  @override
  String get socialPermissionViewer => 'Läsa';

  @override
  String get socialPermissionUnknown => 'Okänd';

  @override
  String get socialAddCategory => 'Lägg till kategori';

  @override
  String get socialNewCategory => 'Ny kategori';

  @override
  String get socialFilterCategories => 'Filtrera kategorier';

  @override
  String get socialSortCategories => 'Sortera kategorier';

  @override
  String get socialAveragePerCategory => 'Genomsnitt/kategori';

  @override
  String get socialLargestCategory => 'Största kategorin';

  @override
  String get socialCreateFirstCategory =>
      'Skapa din första vänkategori för att komma igång';

  @override
  String get socialLoadingCategories => 'Laddar kategorier...';

  @override
  String get socialSelectAllLabel => 'Markera alla';

  @override
  String get socialDeselectAllLabel => 'Avmarkera alla';

  @override
  String get socialInvertLabel => 'Invertera';

  @override
  String get invitationNoTargetsAvailable => 'Inga målgrupper tillgängliga';

  @override
  String get invitationSearchTargets => 'Sök målgrupper...';

  @override
  String get invitationSelectedTargets => 'Valda målgrupper';

  @override
  String invitationTargetsSelected(int count) {
    return '$count målgrupper valda';
  }

  @override
  String get invitationSortLabel => 'Sortera:';

  @override
  String get invitationSortByName => 'Namn';

  @override
  String get invitationSortByType => 'Typ';

  @override
  String get invitationSortByMembers => 'Medlemmar';

  @override
  String get invitationAll => 'Alla';

  @override
  String get invitationNone => 'Inga';

  @override
  String get invitationGroups => 'Grupper';

  @override
  String get invitationIndividuals => 'Individer';

  @override
  String get invitationAddTarget => 'Lägg till målgrupp';

  @override
  String get invitationSendInvitations => 'Skicka inbjudningar';

  @override
  String get invitationCreateGroup => 'Skapa grupp';

  @override
  String get invitationAffectedTargets => 'Berörda målgrupper:';

  @override
  String get invitationView => 'Visa';

  @override
  String get invitationSendInvitation => 'Skicka inbjudan';

  @override
  String get invitationInvite => 'Inbjud';

  @override
  String get invitationViewMembers => 'Visa medlemmar';

  @override
  String get invitationLoadingTargets => 'Laddar målgrupper...';

  @override
  String get invitationNetworkError => 'Nätverksfel';

  @override
  String get invitationCheckConnection => 'Kontrollera din internetanslutning.';

  @override
  String get invitationNoAccessTitle => 'Ingen åtkomst';

  @override
  String get invitationNoAccessSubtitle =>
      'Du har inte behörighet att se denna information.';

  @override
  String get invitationTargetsLoaded => 'Målgrupper laddade!';

  @override
  String get invitationNoSearchResults => 'Inga sökresultat';

  @override
  String invitationNoResultsFor(String query) {
    return 'Inga resultat för \"$query\"';
  }

  @override
  String invitationTargetsSelectedCount(int count) {
    return '$count mål valda';
  }

  @override
  String get invitationNoSelectionsMade => 'Inga val gjorda';

  @override
  String get socialSharedRecipes => 'Delade recept';

  @override
  String get socialSharedMenus => 'Delade menyer';

  @override
  String get socialActiveCollaborations => 'Aktiva samarbeten';

  @override
  String get socialSent => 'Skickade';

  @override
  String get socialReceived => 'Mottagna';

  @override
  String get socialAccepted => 'Accepterade';

  @override
  String get socialPending => 'Väntande';

  @override
  String get commonUser => 'Användare';

  @override
  String get commonDone => 'Klar';

  @override
  String get commonClearError => 'Rensa fel';

  @override
  String get commonClearSearch => 'Rensa sökning';

  @override
  String get commonComingSoon => 'Kommer snart...';

  @override
  String get commonDiscard => 'Kasta bort';

  @override
  String get commonFailed => 'Misslyckades';

  @override
  String get commonImporting => 'Importerar...';

  @override
  String get commonLater => 'Senare';

  @override
  String get commonMessage => 'Meddelande:';

  @override
  String get commonPending => 'Väntar';

  @override
  String get commonRefresh => 'Uppdatera';

  @override
  String get commonRemove => 'Ta bort';

  @override
  String get commonSaving => 'Sparar...';

  @override
  String get commonSending => 'Skickar...';

  @override
  String get commonUndo => 'Ångra';

  @override
  String get commonUploading => 'Laddar upp...';

  @override
  String get authLogIn => 'Logga in';

  @override
  String get collaborativeListNoAccess =>
      'Listan kanske har tagits bort eller så har du inte tillgång längre';

  @override
  String get collaborativeListNotFound => 'Lista hittades inte';

  @override
  String get collaborativeLoadingSharedList => 'Laddar gemensam lista...';

  @override
  String get discoveryActivity => 'Aktivitet';

  @override
  String discoveryByAuthor(String name) {
    return 'Av $name';
  }

  @override
  String get discoveryCategories => 'Kategorier';

  @override
  String get discoveryContentType => 'Innehållstyp';

  @override
  String get discoveryCustomizeExperience => 'Anpassa din upptäcktsupplevelse';

  @override
  String get discoveryDiscover => 'Upptäck';

  @override
  String get discoveryDiscoverNewContent => 'Upptäck nytt innehåll';

  @override
  String get discoveryFeedbackHint =>
      'Hjälp oss att förbättra Butlery! Beskriv din feedback här...';

  @override
  String get discoveryFeedbackThanks =>
      'Tack för din feedback! Vi kommer att granska den.';

  @override
  String get discoveryFilterContent => 'Filtrera innehåll';

  @override
  String get discoveryFindPopularContent =>
      'Hitta populära recept, menyer och listor';

  @override
  String get discoveryForYou => 'För dig';

  @override
  String get discoveryGiveFeedback => 'Ge feedback';

  @override
  String discoveryItemCount(int count) {
    return '$count objekt';
  }

  @override
  String get discoveryLoading => 'Laddar upptäcktsinnehåll...';

  @override
  String get discoveryMenus => 'Menyer';

  @override
  String get discoveryNotifications => 'Aviseringar';

  @override
  String get discoveryPopularNow => 'Populärt just nu';

  @override
  String get discoveryPushNotifications => 'Push-aviseringar';

  @override
  String get discoveryPushNotificationsDescription =>
      'Få aviseringar om nytt innehåll';

  @override
  String get discoveryRecipes => 'Recept';

  @override
  String get discoverySeeAll => 'Se allt';

  @override
  String get discoverySendFeedback => 'Skicka feedback';

  @override
  String get discoverySettings => 'Upptäcktsinställningar';

  @override
  String get discoverySettingsSaved => 'Inställningar sparade!';

  @override
  String get discoveryShoppingLists => 'Inköpslistor';

  @override
  String get discoveryShowFriendActivity => 'Visa vänaktivitet';

  @override
  String get discoveryShowFriendActivityDescription =>
      'Visa vad dina vänner gör';

  @override
  String get discoveryShowMenuResults => 'Visa menyresultat';

  @override
  String get discoveryShowRecipeResults => 'Visa receptresultat';

  @override
  String get discoveryShowRecommendations => 'Visa rekommendationer';

  @override
  String get discoveryShowRecommendationsDescription =>
      'Visa personliga rekommendationer';

  @override
  String get discoveryShowShoppingLists => 'Visa inköpslistor';

  @override
  String get discoveryShowTrends => 'Visa trender';

  @override
  String get discoveryShowTrendsDescription =>
      'Visa populärt innehåll från communityn';

  @override
  String get discoveryToDiscover => 'att upptäcka';

  @override
  String get allergenCrustacean => 'Kräftdjur';

  @override
  String get allergenDairy => 'Mjölk';

  @override
  String get allergenEgg => 'Ägg';

  @override
  String get allergenFish => 'Fisk';

  @override
  String get allergenGluten => 'Gluten';

  @override
  String get allergenPeanut => 'Jordnötter';

  @override
  String get allergenSoy => 'Soja';

  @override
  String get allergenTreeNut => 'Trädnötter';

  @override
  String get commentCouldNotPost => 'Kunde inte posta kommentaren';

  @override
  String get commentPosted => 'Kommentar postad';

  @override
  String get commentReply => 'Svara';

  @override
  String get commentReplyingTo => 'Svarar på';

  @override
  String get commentWriteComment => 'Skriv en kommentar';

  @override
  String get commentWriteReply => 'Skriv ett svar';

  @override
  String get commentYou => 'Du';

  @override
  String dialogAddRecipesToCategory(String categoryName) {
    return 'Lägg till recept i $categoryName';
  }

  @override
  String get dialogAlreadyShared => 'Delad';

  @override
  String get dialogAlternatives => 'Alternativ:';

  @override
  String get dialogClearSelection => 'Rensa val';

  @override
  String get dialogContainsAllergens => 'Innehåller allergener:';

  @override
  String dialogCouldNotSave(String error) {
    return 'Kunde inte spara: $error';
  }

  @override
  String get dialogCreateList => 'Skapa lista';

  @override
  String get dialogCreateNewListForIngredients =>
      'Skapa en ny lista för dessa ingredienser';

  @override
  String get dialogDietaryProperties => 'Dietegenskaper:';

  @override
  String get dialogEnterListName => 'Ange ett namn för listan';

  @override
  String dialogFilteredRecipeCount(int filtered, int total) {
    return '$filtered av $total recept';
  }

  @override
  String get dialogImportWithoutAi => 'Importera utan AI';

  @override
  String get dialogItems => 'objekt';

  @override
  String dialogItemsProgress(int completed, int total) {
    return '$completed/$total klara';
  }

  @override
  String get dialogLoadingMenus => 'Laddar menyer...';

  @override
  String get dialogLoadingRecipes => 'Laddar recept...';

  @override
  String get dialogManualImport => 'Manuell import';

  @override
  String get dialogMarkIngredientsYourself => 'Markera ingredienser själv';

  @override
  String get dialogMayTakeAWhile => 'Detta kan ta en stund...';

  @override
  String get dialogNameMinTwoChars => 'Namnet måste vara minst 2 tecken';

  @override
  String get dialogNoEditableShoppingLists =>
      'Du har inga redigerbara inköpslistor. Endast listor du kan redigera visas här. Skapa en ny lista ovan.';

  @override
  String get dialogNoMenus => 'Inga menyer';

  @override
  String get dialogNoMenusToShare => 'Du har inga menyer att dela än';

  @override
  String get dialogNoRecipes => 'Inga recept';

  @override
  String get dialogNoRecipesToShare => 'Du har inga recept att dela än';

  @override
  String get dialogNoShoppingLists => 'Inga inköpslistor';

  @override
  String get dialogNoShoppingListsToShare =>
      'Du har inga inköpslistor att dela än';

  @override
  String get dialogOrSelectExistingList => 'Eller välj befintlig lista:';

  @override
  String get dialogPrivate => 'Privat';

  @override
  String dialogRetryInHours(int hours) {
    return 'Försök igen om $hours timme(ar)';
  }

  @override
  String dialogRetryInMinutes(int minutes) {
    return 'Försök igen om $minutes minut(er)';
  }

  @override
  String dialogRetryInSeconds(int seconds) {
    return 'Försök igen om $seconds sekund(er)';
  }

  @override
  String get dialogRetryLater => 'Försök senare';

  @override
  String get dialogRetryTomorrow => 'Försök igen imorgon';

  @override
  String get dialogSearchRecipes => 'Sök recept...';

  @override
  String get dialogSearchRecipesToAdd => 'Sök recept att lägga till...';

  @override
  String dialogSelectedCount(int count) {
    return 'Valda ($count)';
  }

  @override
  String get dialogShared => 'Delad';

  @override
  String dialogShareMenuWith(String groupName) {
    return 'Dela meny med $groupName';
  }

  @override
  String dialogShareRecipesWith(String name) {
    return 'Dela recept med $name';
  }

  @override
  String dialogShareShoppingListWith(String groupName) {
    return 'Dela inköpslista med $groupName';
  }

  @override
  String get dialogSharing => 'Delar...';

  @override
  String get dialogShoppingListNameHint => 'T.ex. \"Pannkakor - Ingredienser\"';

  @override
  String get dialogUnknownIngredientDescription =>
      'Denna ingrediens finns inte i databasen. Du kan definiera dess egenskaper för bättre taggning.';

  @override
  String dialogUnknownIngredientProgress(int current, int total) {
    return 'Okänd ingrediens $current/$total';
  }

  @override
  String get dialogUsesSimpleExtraction => 'Använder enklare extrahering';

  @override
  String get dietaryAlcohol => 'Alkohol';

  @override
  String get dietaryAnimalProduct => 'Animalisk produkt';

  @override
  String get dietaryBeef => 'Nötkött';

  @override
  String get dietaryMeat => 'Kött';

  @override
  String get dietaryPork => 'Fläsk';

  @override
  String get dietaryPoultry => 'Fågel';

  @override
  String get dietarySeafood => 'Fisk/skaldjur';

  @override
  String get dietarySpicy => 'Starkt';

  @override
  String get draftContinueEditing => 'Fortsätt redigera';

  @override
  String get draftDiscardAll => 'Släng alla';

  @override
  String get draftUnsavedFound => 'Osparade utkast hittade';

  @override
  String get groupContentTypeContent => 'Innehåll';

  @override
  String get groupContentTypeMenu => 'Meny';

  @override
  String get groupContentTypeRecipe => 'Recept';

  @override
  String get groupContentTypeShoppingList => 'Inköpslista';

  @override
  String get groupCopiedToClipboard => 'Kopierat till urklipp';

  @override
  String groupCouldNotCopyList(String error) {
    return 'Kunde inte kopiera lista: $error';
  }

  @override
  String get groupCouldNotFetchMenu => 'Kunde inte hämta meny från servern';

  @override
  String groupCouldNotImportList(String error) {
    return 'Kunde inte importera lista: $error';
  }

  @override
  String get groupCreateNew => 'Skapa ny grupp';

  @override
  String get groupDeleteConfirmPrefix =>
      'Är du säker på att du vill ta bort gruppen ';

  @override
  String get groupDeleteTheGroup => 'Ta bort gruppen';

  @override
  String get groupDeleteWarning =>
      'Detta kan inte ångras. Alla medlemmar kommer att tas bort från gruppen.';

  @override
  String get groupDeleteWhenLeaving =>
      'Vill du ta bort gruppen när du lämnar den?';

  @override
  String get groupDescriptionHint => 'Vad handlar den här gruppen om?';

  @override
  String get groupDescriptionLabel => 'Beskrivning (valfritt)';

  @override
  String groupErrorOpeningMenu(String error) {
    return 'Fel vid öppning av meny: $error';
  }

  @override
  String get groupImport => 'Importera';

  @override
  String groupImportingMenuComingSoon(String title) {
    return 'Importerar meny: $title (kommer snart)';
  }

  @override
  String groupImportingRecipeComingSoon(String title) {
    return 'Importerar recept: $title (kommer snart)';
  }

  @override
  String groupImportingShoppingListComingSoon(String title) {
    return 'Importerar inköpslista: $title (kommer snart)';
  }

  @override
  String groupImportNotImplemented(String title) {
    return 'Importera $title (funktionalitet ej implementerad än)';
  }

  @override
  String get groupImportShoppingList => 'Importera inköpslista';

  @override
  String groupImportShoppingListConfirm(String name) {
    return 'Vill du importera \"$name\" till dina inköpslistor?';
  }

  @override
  String get groupInvitationNote =>
      'Dessa vänner kommer att få en inbjudan till gruppen.';

  @override
  String get groupIsEmpty => 'Gruppen är tom';

  @override
  String get groupListCopiedToClipboard => 'Lista kopierad till urklipp';

  @override
  String groupListCopyName(String name) {
    return 'Kopia av $name';
  }

  @override
  String groupListImported(String name) {
    return '\"$name\" har importerats';
  }

  @override
  String get groupNameHint => 'T.ex. \"Familjen\", \"Jobbet\", \"Bokklubben\"';

  @override
  String get groupNoFriendsToAdd =>
      'Du har inga vänner att lägga till än. Lägg till vänner först för att skapa grupper med dem.';

  @override
  String get groupNoMenusShared => 'Inga menyer delade';

  @override
  String get groupNoMenusSharedSubtitle =>
      'Dela menyer med gruppen för att planera tillsammans';

  @override
  String get groupNoRecipesShared => 'Inga recept delade';

  @override
  String get groupNoRecipesSharedSubtitle =>
      'Dela recept med gruppen för att inspirera varandra';

  @override
  String get groupNoShoppingListsShared => 'Inga inköpslistor delade';

  @override
  String get groupNoShoppingListsSharedSubtitle =>
      'Dela inköpslistor med gruppen för att samarbeta';

  @override
  String groupOnlyMember(String name) {
    return 'Du är den enda medlemmen i \"$name\".';
  }

  @override
  String get groupPasteInAnyApp => 'Klistra in i valfri app';

  @override
  String groupRecipeViewComingSoon(String title) {
    return 'Receptvisning: $title (kommer snart)';
  }

  @override
  String get groupRemoveMemberConfirmPrefix =>
      'Är du säker på att du vill ta bort ';

  @override
  String get groupRemoveMemberFromGroup => ' från gruppen ';

  @override
  String get groupRemoveMemberWarning =>
      'Medlemmen kommer att förlora åtkomst till gruppens innehåll.';

  @override
  String groupSelectedMembers(int count) {
    return 'Valda medlemmar ($count)';
  }

  @override
  String get groupSelectFriendsToInvite =>
      'Välj vänner att bjuda in till gruppen';

  @override
  String get groupSelectIcon => 'Välj ikon';

  @override
  String get groupSelectMembers => 'Välj medlemmar';

  @override
  String get groupSelectNewOwner => 'Välj ny ägare:';

  @override
  String get groupSelectShareTarget => 'Välj vem du vill dela med';

  @override
  String get groupSendToFriends => 'Skicka till vänner i Butlery';

  @override
  String groupSharedBy(String name) {
    return 'Delad av $name';
  }

  @override
  String get groupSharedContent => 'Delat innehåll';

  @override
  String get groupShareShoppingList => 'Dela inköpslista';

  @override
  String get groupShareWithFriendsInButlery => 'Dela med vänner i Butlery';

  @override
  String groupShoppingListViewComingSoon(String title) {
    return 'Inköpslistevisning: $title (kommer snart)';
  }

  @override
  String get groupTabLists => 'Listor';

  @override
  String get groupTabMenus => 'Menyer';

  @override
  String get groupTransferOwnership => 'Överför gruppägande';

  @override
  String groupTransferOwnershipMessage(String name) {
    return 'Du är ägare av \"$name\". Du måste välja en ny ägare innan du kan lämna gruppen.';
  }

  @override
  String get groupView => 'Visa';

  @override
  String groupViewNotImplemented(String title) {
    return 'Visa $title (funktionalitet ej implementerad än)';
  }

  @override
  String profileCouldNotOpenConsentManagement(String error) {
    return 'Kunde inte öppna samtyckeshantering: $error';
  }

  @override
  String get profileDataBackup => 'Data & Backup';

  @override
  String get profileExportData => 'Exportera mina data';

  @override
  String get profileExportDataSubtitle =>
      'Ladda ner all din data i JSON-format (GDPR)';

  @override
  String get profileManageConsent => 'Hantera samtycken';

  @override
  String get profileManageConsentSubtitle =>
      'Välj hur vi får behandla dina personuppgifter (GDPR)';

  @override
  String get rateLimitAiBudget => 'AI-budget förbrukad';

  @override
  String get rateLimitAiLimit => 'AI-gräns nådd';

  @override
  String get rateLimitDailyQuota => 'Dagskvot uppnådd';

  @override
  String get rateLimitSlowDown => 'Sakta ner lite';

  @override
  String get sessionContinue => 'Fortsätt session';

  @override
  String get sessionContinueOrLogout =>
      'Vill du fortsätta din session eller logga ut nu?';

  @override
  String get sessionExpiringMessage => 'Din session kommer att avslutas om:';

  @override
  String get sessionExpiringTitle => 'Session utgår snart';

  @override
  String get shareContentTypeMenu => 'menyer';

  @override
  String get shareContentTypeRecipe => 'recept';

  @override
  String get shareContentTypeShoppingList => 'inköpslistor';

  @override
  String shareDefaultMessageMenu(String name) {
    return 'Kolla in denna veckomeny: $name';
  }

  @override
  String shareDefaultMessageRecipe(String name) {
    return 'Kolla in detta recept: $name';
  }

  @override
  String shareDefaultMessageShoppingList(String name) {
    return 'Kolla in denna inköpslista: $name';
  }

  @override
  String shareFriendsSelected(int count) {
    return '$count vän(ner) valda';
  }

  @override
  String get shareMenu => 'Dela meny';

  @override
  String get shareRecipe => 'Dela recept';

  @override
  String shareSelectAtLeastOne(String contentType) {
    return 'Välj minst en vän för att dela $contentType';
  }

  @override
  String shareSuccessMessage(String name, String mode, int count) {
    return '$name har delats som $mode med $count mottagare.';
  }

  @override
  String get uploadFailed => 'Bilduppladdning misslyckades';

  @override
  String uploadFailedCount(int count) {
    return '$count bilder kunde inte laddas upp.\n\nVad vill du göra?';
  }

  @override
  String get uploadInProgress => 'Bilduppladdning pågår';

  @override
  String uploadMixedStatus(int failedCount, int pendingCount) {
    return 'Några bilder kunde inte laddas upp ($failedCount) och andra laddas fortfarande upp ($pendingCount).\n\nVad vill du göra?';
  }

  @override
  String uploadPendingCount(int count) {
    return '$count bilder laddas fortfarande upp.\n\nVad vill du göra?';
  }

  @override
  String get uploadSaveWithoutFailed => 'Spara utan misslyckade bilder';

  @override
  String get uploadSaveWithoutPending => 'Spara utan väntande bilder';

  @override
  String get uploadWait => 'Vänta på uppladdning';

  @override
  String get uploadClearFailed => 'Rensa misslyckade';

  @override
  String uploadRetryAllCount(int count) {
    return 'Försök alla ($count)';
  }

  @override
  String uploadStopAllCount(int count) {
    return 'Stoppa alla ($count)';
  }

  @override
  String uploadTimeRemaining(String time) {
    return '$time kvar';
  }

  @override
  String get consentManageTitle => 'Hantera samtycken';

  @override
  String get consentYourConsents => 'Dina samtycken';

  @override
  String get consentGdprDescription =>
      'Enligt GDPR har du full kontroll över hur vi behandlar dina personuppgifter. Du kan när som helst ändra eller återkalla dina samtycken.';

  @override
  String get consentLastUpdated => 'Senast uppdaterad';

  @override
  String get consentRequiredTitle => 'Nödvändiga samtycken';

  @override
  String get consentRequiredDescription =>
      'Dessa samtycken krävs för att appen ska fungera och kan inte inaktiveras.';

  @override
  String get consentBasicServices => 'Grundläggande tjänster';

  @override
  String get consentBasicServicesDescription =>
      'Autentisering, säkerhet och grundläggande funktioner.';

  @override
  String get consentDataProcessing => 'Databehandling';

  @override
  String get consentDataProcessingDescription =>
      'Lagring och behandling av recept, menyer och inköpslistor.';

  @override
  String get consentOptionalTitle => 'Valfria samtycken';

  @override
  String get consentOptionalDescription =>
      'Du kan när som helst aktivera eller inaktivera dessa samtycken.';

  @override
  String get consentRejectAll => 'Avvisa alla';

  @override
  String get consentAnalytics => 'Analysdata';

  @override
  String get consentAnalyticsDescription =>
      'Hjälp oss förbättra appen genom att dela användningsstatistik. Vi samlar in information om hur du använder appen för att identifiera buggar och förbättra användarupplevelsen.';

  @override
  String get consentMarketing => 'Marknadsföring';

  @override
  String get consentMarketingDescription =>
      'Ta emot nyhetsbrev och erbjudanden om nya funktioner, recept och uppdateringar via e-post.';

  @override
  String get consentSocialFeatures => 'Sociala funktioner';

  @override
  String get consentSocialFeaturesDescription =>
      'Dela dina recept med vänner, se andras skapelser och delta i communityn.';

  @override
  String get consentPushNotifications => 'Push-notiser';

  @override
  String get consentPushNotificationsDescription =>
      'Få meddelanden om kommentarer på dina recept, när vänner delar med dig och andra aktiviteter.';

  @override
  String get consentGoodToKnow => 'Bra att veta';

  @override
  String get consentInfoImmediate => 'Dina ändringar träder i kraft omedelbart';

  @override
  String get consentInfoChangeAnytime =>
      'Du kan ändra dina samtycken när som helst';

  @override
  String get consentInfoHistory =>
      'Vi sparar en historik av dina samtycken för att följa GDPR';

  @override
  String get consentInfoRevoke =>
      'Att återkalla samtycken påverkar inte tidigare behandling';

  @override
  String get consentSaved => 'Samtycken har sparats';

  @override
  String get consentRevokeAllTitle => 'Återkalla alla valfria samtycken?';

  @override
  String get consentRevokeAllMessage =>
      'Detta kommer att inaktivera alla valfria funktioner som analysdata, marknadsföring, sociala funktioner och push-notiser. Du kan aktivera dem igen när som helst.';

  @override
  String get consentRevokeAll => 'Återkalla alla';

  @override
  String get consentAllRevoked => 'Alla valfria samtycken har återkallats';

  @override
  String get dataExportTitle => 'Exportera mina data';

  @override
  String get dataExportDownloadTitle => 'Ladda ner dina data';

  @override
  String get dataExportGdprDescription =>
      'Enligt GDPR Artikel 20 har du rätt att få en kopia av all din personliga data som lagras i Butlery. Data exporteras i JSON-format som du kan spara eller överföra till en annan tjänst.';

  @override
  String get dataExportExporting => 'Exporterar dina data...';

  @override
  String get dataExportMayTakeSeconds => 'Detta kan ta några sekunder';

  @override
  String get dataExportFailed => 'Export misslyckades';

  @override
  String get dataExportSuccess => 'Data exporterad';

  @override
  String get dataExportExportedAt => 'Exporterad';

  @override
  String get dataExportFileSize => 'Filstorlek';

  @override
  String get dataExportSaveFile => 'Spara fil';

  @override
  String get dataExportClear => 'Rensa export';

  @override
  String get dataExportWhatsIncluded => 'Vad ingår i exporten?';

  @override
  String get dataExportIncludesProfile => 'Profil och inställningar';

  @override
  String get dataExportIncludesRecipes => 'Alla dina recept';

  @override
  String get dataExportIncludesFriends => 'Vänner och sociala kontakter';

  @override
  String get dataExportIncludesMessages => 'Meddelanden och konversationer';

  @override
  String get dataExportIncludesLists => 'Inköpslistor och menyer';

  @override
  String get dataExportIncludesComments => 'Kommentarer och betyg';

  @override
  String get dataExportIncludesActivity => 'Aktivitetshistorik';

  @override
  String get dataExportOnlyYourData =>
      'OBS: Exporten innehåller endast din egen data. Ingen data från andra användare inkluderas.';

  @override
  String get dateToday => 'Idag';

  @override
  String get dateYesterday => 'Igår';

  @override
  String dateDaysAgo(int days) {
    return '$days dagar sedan';
  }

  @override
  String dateWeeksAgo(int weeks) {
    return '$weeks veckor sedan';
  }

  @override
  String dateMonthsAgo(int months) {
    return '$months månader sedan';
  }

  @override
  String get friendAccept => 'Acceptera';

  @override
  String get friendDecline => 'Avvisa';

  @override
  String get friendRequestTitle => 'Vänförfrågan';

  @override
  String get friendWantsToBeFriend => 'Vill bli din vän';

  @override
  String imageAddCount(int count) {
    return 'Lägg till ($count)';
  }

  @override
  String get imageAddImages => 'Lägg till bilder';

  @override
  String get imageAdding => 'Lägger till...';

  @override
  String get imageAddingImage => 'Lägger till bild...';

  @override
  String imagePermissionMessage(String permission) {
    return 'Butlery behöver tillgång till din $permission för att kunna lägga till bilder till recept. Gå till inställningar för att ge behörighet.';
  }

  @override
  String get imagePermissionRequired => 'Behörighet krävs';

  @override
  String get imagePrimary => 'Primär';

  @override
  String get imageSelectExistingFromGallery =>
      'Välj en befintlig bild från ditt galleri';

  @override
  String get imageSelectSource => 'Välj bildkälla';

  @override
  String imageTapToAddUpTo(int count) {
    return 'Tryck för att lägga till upp till $count bilder';
  }

  @override
  String get imageTapToLoad => 'Tryck för att ladda';

  @override
  String get imageUploadingImages => 'Laddar upp bilder';

  @override
  String get imageUploadPreparing => 'Förbereder...';

  @override
  String get imageUseCameraForNewPhoto =>
      'Använd kameran för att ta en ny bild';

  @override
  String get importAddIngredient => 'Lägg till ingrediens';

  @override
  String get importAddStep => 'Lägg till steg';

  @override
  String get importCancelConfirm => 'Avbryt import';

  @override
  String get importCancelMessage =>
      'Är du säker på att du vill avbryta? Alla val kommer att förloras.';

  @override
  String get importCancelTitle => 'Avbryt import?';

  @override
  String get importDescriptionHint => 'Kort beskrivning (valfritt)';

  @override
  String get importManualTitle => 'Manuell import';

  @override
  String get importMealBreakfast => 'Frukost';

  @override
  String get importMealDessert => 'Dessert';

  @override
  String get importMealDinner => 'Middag';

  @override
  String get importMealLunch => 'Lunch';

  @override
  String get importMealSnack => 'Mellanmål';

  @override
  String get importMealType => 'Måltid';

  @override
  String get importRecipeNameHint => 'Ange receptets namn';

  @override
  String get importRecipeNameRequired => 'Receptnamn *';

  @override
  String get importSaveRecipe => 'Spara recept';

  @override
  String get importSelectIngredients => 'Välj ingredienser';

  @override
  String get importSelectInstructions => 'Välj instruktioner';

  @override
  String get importStep1SelectIngredients => 'Steg 1: Välj ingredienser';

  @override
  String get importStep2SelectInstructions => 'Steg 2: Välj instruktioner';

  @override
  String get importStep3ReviewEdit => 'Steg 3: Granska och redigera';

  @override
  String menuCardMoreRecipes(int count) {
    return '+ $count fler recept';
  }

  @override
  String get menuCardNoRecipes => 'Inga recept i menyn';

  @override
  String menuCardRecipeCount(int count) {
    return '$count recept';
  }

  @override
  String get menuCardRecipesInMenu => 'Recept i menyn:';

  @override
  String get menuCardSharedMenu => 'Delad meny';

  @override
  String menuCardSharedWithCount(int count) {
    return 'Delad med $count personer';
  }

  @override
  String get searchHint => 'sök...';

  @override
  String shareFriendsSelectedCount(int count) {
    return '$count vän(ner) valda';
  }

  @override
  String shareGroupMembersCount(int count) {
    return '$count medlemmar';
  }

  @override
  String get shareTabFriends => 'Vänner';

  @override
  String get shareTabGroups => 'Grupper';

  @override
  String get shoppingCardComplete => 'Klar';

  @override
  String shoppingCardCompleted(int count) {
    return '$count slutförda';
  }

  @override
  String get shoppingCardItemsOnList => 'Föremål på listan:';

  @override
  String shoppingCardMoreItems(int count) {
    return '+ $count fler föremål';
  }

  @override
  String get shoppingCardNoItems => 'Inga föremål i listan';

  @override
  String get shoppingCardSharedList => 'Delad lista';

  @override
  String shoppingCardSharedWithCount(int count) {
    return 'Delad med $count personer';
  }

  @override
  String get adminYouAreAdmin => 'Du är administratör';

  @override
  String chatCreatedDate(String date) {
    return 'Skapad: $date';
  }

  @override
  String chatMemberCount(int count) {
    return '$count medlemmar';
  }

  @override
  String get chatMute => 'Tysta';

  @override
  String chatParticipantCount(int count) {
    return '$count deltagare';
  }

  @override
  String get chatTitle => 'Chatt';

  @override
  String get commonSearch => 'Sök';

  @override
  String get commonUnknown => 'Okänd';

  @override
  String get dataExportClearConfirmMessage =>
      'Är du säker på att du vill rensa den exporterade datan? Du kan när som helst exportera igen.';

  @override
  String get dataExportClearConfirmTitle => 'Rensa export?';

  @override
  String get dataExportCleared => 'Export rensad';

  @override
  String dataExportCouldNotSaveFile(String error) {
    return 'Kunde inte spara fil: $error';
  }

  @override
  String dataExportCouldNotShare(String error) {
    return 'Kunde inte dela: $error';
  }

  @override
  String get dataExportExportedSuccessfully => 'Data exporterad framgångsrikt';

  @override
  String dataExportFileSaved(String fileName) {
    return 'Fil sparad: $fileName';
  }

  @override
  String get dataExportShareSubject => 'Butlery Data Export';

  @override
  String get dataExportShareText => 'Min exporterade data från Butlery app';

  @override
  String get dialogAmountHint => 'Ange antal...';

  @override
  String get dialogAmountInvalid => 'Ogiltigt antal';

  @override
  String get dialogAmountLabel => 'Antal';

  @override
  String dialogAmountMax(int max) {
    return 'Max $max tillåtet';
  }

  @override
  String dialogAmountMin(int min) {
    return 'Minst $min krävs';
  }

  @override
  String get dialogAmountRequired => 'Antal krävs';

  @override
  String get dialogDescriptionHint => 'Valfri beskrivning...';

  @override
  String get dialogDescriptionLabel => 'Beskrivning';

  @override
  String dialogFieldRequired(String field) {
    return '$field krävs';
  }

  @override
  String get dialogInvalidUrl => 'Ogiltig URL';

  @override
  String get dialogPhoneInvalid => 'Ogiltigt telefonnummer';

  @override
  String get dialogPhoneLabel => 'Telefonnummer';

  @override
  String get dialogSearchHint => 'Skriv för att söka...';

  @override
  String get importLikely => 'Trolig';

  @override
  String get importNoLinesToShow => 'Inga rader att visa';

  @override
  String importSelectAllHighlighted(int count) {
    return 'Välj alla markerade ($count)';
  }

  @override
  String importSelectedCount(int count) {
    return '$count valda';
  }

  @override
  String get importStep => 'Steg';

  @override
  String get importStepAnalyzing => 'Analyserar';

  @override
  String get importStepCreating => 'Skapar';

  @override
  String get importStepFetching => 'Hämtar';

  @override
  String get invitationClearSearch => 'Rensa sökning';

  @override
  String get invitationCouldNotLoadTargets => 'Kunde inte ladda mål';

  @override
  String get menuCreateBeforeSave =>
      'Skapa en meny först innan du kan spara den';

  @override
  String get menuCreateBeforeShare =>
      'Skapa en meny först innan du kan dela den';

  @override
  String get menuCreateBeforeShoppingList =>
      'Skapa en meny först innan du kan skapa inköpslista';

  @override
  String menuDefaultName(int count) {
    return 'Veckomeny ($count recept)';
  }

  @override
  String get menuExitConfirm => 'Avsluta';

  @override
  String get menuExitMessage => 'Vill du verkligen avsluta appen?';

  @override
  String get menuExitTitle => 'Avsluta Butlery?';

  @override
  String get menuNameBeforeShare => 'Ge din meny ett namn innan du delar den:';

  @override
  String get menuNameHint => 'T.ex. \"Min veckomeny v.45\"';

  @override
  String get menuNameYourMenu => 'Namnge din meny';

  @override
  String get menuShareDefaultMessage => 'Kolla min veckomeny!';

  @override
  String get messagingEdited => 'redigerad';

  @override
  String get messagingImageLoadError => 'Bild kunde inte laddas';

  @override
  String get messagingImageLoadFailed => 'Kunde inte ladda bild';

  @override
  String get messagingMenuShared => 'Meny delad';

  @override
  String get messagingRecipeShared => 'Recept delat';

  @override
  String get messagingShoppingListShared => 'Inköpslista delad';

  @override
  String get messagingUnknownMenu => 'Okänd meny';

  @override
  String get messagingUnknownRecipe => 'Okänt recept';

  @override
  String get messagingUnknownShoppingList => 'Okänd inköpslista';

  @override
  String get messagingVoiceMessage => 'Röstmeddelande';

  @override
  String get messagingAddFriendsToCreateGroups =>
      'Lägg till vänner för att skapa gruppkonversationer';

  @override
  String get messagingAllFriendsAlreadyInGroup =>
      'Alla dina vänner är redan med i gruppen';

  @override
  String get messagingCouldNotAddMembers => 'Kunde inte lägga till medlemmar';

  @override
  String messagingCouldNotLoadFriends(String error) {
    return 'Kunde inte ladda vänner: $error';
  }

  @override
  String messagingCouldNotLoadGroupInfo(String error) {
    return 'Kunde inte ladda gruppinformation: $error';
  }

  @override
  String get messagingCouldNotRemoveMember => 'Kunde inte ta bort medlem';

  @override
  String get messagingCouldNotUpdateGroupName =>
      'Kunde inte uppdatera gruppnamn';

  @override
  String get messagingCreateGroup => 'Skapa gruppkonversation';

  @override
  String get messagingEditGroupName => 'Redigera gruppnamn';

  @override
  String get messagingEnterNewGroupName => 'Ange nytt gruppnamn';

  @override
  String messagingFriendsCount(int count) {
    return 'Vänner ($count)';
  }

  @override
  String get messagingFromGroup => 'från gruppen';

  @override
  String get messagingGroupCreated => 'Gruppkonversation skapad!';

  @override
  String get messagingGroupName => 'Gruppnamn';

  @override
  String get messagingGroupNameHint =>
      'T.ex. Min familj, Jobbet, Bästa vännerna...';

  @override
  String get messagingGroupNameUpdated => 'Gruppnamn uppdaterat';

  @override
  String get messagingGroupNoLongerExists => 'Denna grupp finns inte längre';

  @override
  String get messagingGroupNotFound => 'Grupp hittades inte';

  @override
  String get messagingLeaveGroupConfirm =>
      'Är du säker på att du vill lämna denna grupp? Du kommer inte längre kunna se meddelanden i gruppen.';

  @override
  String get messagingLoadingFriends => 'Laddar vänner...';

  @override
  String get messagingLoadingGroupInfo => 'Laddar gruppinformation...';

  @override
  String messagingMembersAdded(int count) {
    return '$count medlem(mar) tillagda';
  }

  @override
  String messagingMembersCount(int count) {
    return 'Medlemmar ($count)';
  }

  @override
  String messagingMemberRemoved(String name) {
    return '$name borttagen från gruppen';
  }

  @override
  String get messagingNoFriendsAvailable => 'Inga vänner tillgängliga';

  @override
  String get messagingNoFriendsFound => 'Inga vänner hittades';

  @override
  String get messagingSearchFriends => 'Sök vänner...';

  @override
  String get messagingSelectAtLeastTwoMembers => 'Välj minst 2 medlemmar nedan';

  @override
  String messagingSelectedMembers(int count) {
    return 'Valda medlemmar ($count)';
  }

  @override
  String get messagingTryAnotherKeyword => 'Försök med ett annat sökord';

  @override
  String mfaCodeSentTo(String phone) {
    return 'En verifieringskod har skickats till $phone.';
  }

  @override
  String get mfaEnterCode => 'Ange verifieringskoden';

  @override
  String get mfaInvalidCode => 'Ogiltig kod. Försök igen.';

  @override
  String get mfaNoPhoneFactor => 'Ingen telefonverifiering konfigurerad.';

  @override
  String get mfaQuotaExceeded => 'För många försök. Försök igen senare.';

  @override
  String get mfaResend => 'Skicka igen';

  @override
  String get mfaSendingCode => 'Skickar verifieringskod...';

  @override
  String mfaSendingTo(String phone) {
    return 'Till: $phone';
  }

  @override
  String get mfaSessionExpired =>
      'Sessionen har gått ut. Försök logga in igen.';

  @override
  String get mfaSixDigitCode => '6-siffrig kod';

  @override
  String get mfaTitle => 'Tvåfaktorsverifiering';

  @override
  String get mfaVerificationFailed => 'Verifiering misslyckades';

  @override
  String get mfaVerify => 'Verifiera';

  @override
  String get mfaYourPhone => 'ditt telefonnummer';

  @override
  String get mfaAccountProtected =>
      'Ditt konto är skyddat med tvåfaktorsautentisering.';

  @override
  String get mfaActivated => 'MFA aktiverat!';

  @override
  String get mfaAddPhoneNumber => 'Lägg till telefonnummer';

  @override
  String get mfaCouldNotRemove => 'Kunde inte ta bort MFA';

  @override
  String get mfaDeactivated => 'MFA inaktiverat';

  @override
  String get mfaDisabled => 'MFA inaktiverat';

  @override
  String get mfaEnabled => 'MFA aktiverat';

  @override
  String get mfaEnableForSecurity => 'Aktivera MFA för extra säkerhet.';

  @override
  String get mfaEnterPhoneNumber => 'Ange ett telefonnummer';

  @override
  String get mfaEnterVerificationCode => 'Ange verifieringskod';

  @override
  String get mfaInvalidPhoneNumber =>
      'Ogiltigt telefonnummer. Ange med landskod (+46).';

  @override
  String get mfaPhone => 'Telefon';

  @override
  String get mfaPhoneNumber => 'Telefonnummer';

  @override
  String mfaRegistered(String time) {
    return 'Registrerad: $time';
  }

  @override
  String get mfaRegisteredMethods => 'Registrerade metoder';

  @override
  String get mfaRemoveConfirm =>
      'Är du säker på att du vill inaktivera tvåfaktorsautentisering? Detta gör ditt konto mindre säkert.';

  @override
  String get mfaRemoveTitle => 'Ta bort MFA?';

  @override
  String get mfaSendCode => 'Skicka kod';

  @override
  String get mfaSmsDescription =>
      'Vi skickar en verifieringskod via SMS när du loggar in.';

  @override
  String get realtimeOffline => 'Offline';

  @override
  String get recipeMealType => 'Måltidstyp';

  @override
  String get recipeTitle => 'Titel';

  @override
  String get recipeUpdating => 'Uppdaterar recept...';

  @override
  String chatAddCount(int count) {
    return 'Lägg till ($count)';
  }

  @override
  String get chatAddMembers => 'Lägg till medlemmar';

  @override
  String get chatSearchFriends => 'Sök vänner...';

  @override
  String get collaborativeContent => 'Innehåll';

  @override
  String get collaborativeEditingTogether =>
      'Du redigerar tillsammans med andra';

  @override
  String get collaborativeOffline => 'Offline';

  @override
  String get collaborativeOnline => 'Online';

  @override
  String get collaborativeShared => 'Delat';

  @override
  String get collaborativeSharedContent => 'Delat innehåll';

  @override
  String collaborativeSharedWithCount(int count) {
    return 'Delat med $count personer';
  }

  @override
  String get collaborativeSyncAutomatic =>
      'Ändringar synkas automatiskt med andra deltagare';

  @override
  String get conversationAddFriendsFirst =>
      'Lägg till vänner först för att starta konversationer.';

  @override
  String conversationCreateError(String error) {
    return 'Kunde inte skapa konversation: $error';
  }

  @override
  String get conversationCreateGroup => 'Skapa gruppkonversation';

  @override
  String conversationGroupChatWith(String names) {
    return 'Gruppchatt med $names';
  }

  @override
  String get conversationGroupCreated => 'Grupp skapad';

  @override
  String get conversationNew => 'Ny konversation';

  @override
  String get conversationNoFriendsMatch => 'Inga vänner matchar din sökning';

  @override
  String get conversationNoFriendsYet => 'Inga vänner ännu';

  @override
  String get conversationSayHi => 'Säg hej!';

  @override
  String get conversationSelectFriendForDM =>
      'Eller välj en vän för direktmeddelande:';

  @override
  String get conversationYouPrefix => 'Du:';

  @override
  String errorDeletingWithDetails(String error) {
    return 'Fel vid borttagning: $error';
  }

  @override
  String get errorLoadingFailed => 'Fel vid laddning';

  @override
  String errorLoadingWithDetails(String error) {
    return 'Fel vid laddning: $error';
  }

  @override
  String get errorUnknown => 'Okänt fel';

  @override
  String get imageSelectImage => 'Välj bild';

  @override
  String get imageTitle => 'Bild';

  @override
  String importAllCount(int count) {
    return 'Importera alla ($count)';
  }

  @override
  String get importColumnCategory => 'Kategori (category/kategori)';

  @override
  String get importColumnCookingTime => 'Tillagningstid (cookingtime/tid)';

  @override
  String get importColumnIngredients =>
      'Ingredienser (ingredients/ingredienser)';

  @override
  String get importColumnInstructions =>
      'Instruktioner (instructions/instruktioner)';

  @override
  String get importColumnServings => 'Portioner (servings/portioner)';

  @override
  String get importColumnTags => 'Taggar (tags/taggar)';

  @override
  String get importColumnTitle => 'Titel (title/namn)';

  @override
  String importComplete(int succeeded, int failed) {
    return 'Import klar: $succeeded lyckades, $failed misslyckades';
  }

  @override
  String get importEditTextBeforeImport => 'Redigera text innan import';

  @override
  String get importEditTextHint =>
      'Du kan redigera den extraherade texten här...';

  @override
  String get importExtractedText => 'Extraherad text:';

  @override
  String importFailed(String error) {
    return 'Import misslyckades: $error';
  }

  @override
  String importFailedCount(int count) {
    return '$count misslyckades';
  }

  @override
  String get importFetching => 'Hämtar...';

  @override
  String get importFetchText => 'Hämta text';

  @override
  String get importFileColumnsOptional => 'Valfria kolumner:';

  @override
  String get importFileColumnsRequired => 'Din fil bör innehålla kolumner för:';

  @override
  String get importFilterAll => 'Alla';

  @override
  String get importFilterAllTimes => 'Alla tider';

  @override
  String get importFromArchive => 'Importera från Butlerys arkiv';

  @override
  String get importFromFile => 'Importera från fil';

  @override
  String get importFromFileTitle => 'Importera recept från CSV eller Excel';

  @override
  String get importFromSocialMedia => 'Från sociala medier';

  @override
  String get importImporting => 'Importerar...';

  @override
  String importImportingRecipes(int count) {
    return 'Importerar $count recept...';
  }

  @override
  String get importImportingRecipesProgress => 'Importerar recept...';

  @override
  String get importNoFileOrNoRecipes =>
      'Ingen fil vald eller filen innehåller inga recept';

  @override
  String get importNoRecipesMatchedFilters => 'Inga recept matchade filtren';

  @override
  String get importParsingText => 'Tolkar text...';

  @override
  String get importPasteRecipeHint => 'Klistra in recepttext här...';

  @override
  String get importPasteRecipeUrl => 'Klistra in recept-URL';

  @override
  String get importPreviewAndEdit => 'Förhandsgranska och redigera';

  @override
  String get importProceedToPaste => 'Gå vidare till klistra-in';

  @override
  String get importRecipesImported => 'Recept importerade!';

  @override
  String get importSearchArchive => 'Sök i arkiv...';

  @override
  String get importSelectFileAndImport => 'Välj fil och importera';

  @override
  String get importSelectingFile => 'Väljer fil...';

  @override
  String get importShowError => 'Visa fel';

  @override
  String importSucceededCount(int count) {
    return '$count lyckades';
  }

  @override
  String importTagsCount(int count) {
    return '$count taggar';
  }

  @override
  String get importTipsContent =>
      'Klistra in hela receptet inklusive ingredienser. Se till att ingredienser kommer före instruktioner. Texten kan komma från Instagram, TikTok, Facebook etc.';

  @override
  String get importTipsTitle => 'Tips för bästa resultat';

  @override
  String get importTryAdjustFilters => 'Prova att justera sökning eller filter';

  @override
  String get importViaUrl => 'Import via URL';

  @override
  String get indicatorOfflineMode => 'Offline-läge - Ändringar sparas lokalt';

  @override
  String get invitationCheckConnectionAndRetry =>
      'Kontrollera din internetanslutning och försök igen.';

  @override
  String invitationCurrentItem(String item) {
    return 'Aktuell: $item';
  }

  @override
  String get invitationDone => 'Klar';

  @override
  String get invitationNoFriendsOrGroupsYet =>
      'Du har inte lagt till några vänner eller grupper än.';

  @override
  String get invitationNoSelectedTargets => 'Inga valda målgrupper';

  @override
  String get invitationProcessing => 'Bearbetar';

  @override
  String get invitationRequestAccess => 'Begär åtkomst';

  @override
  String invitationSearchQuery(String query) {
    return 'Sökning: \"$query\"';
  }

  @override
  String get invitationSelectTargetsToContinue =>
      'Välj målgrupper från listan ovan för att fortsätta.';

  @override
  String get invitationSendingInvitations => 'Skickar inbjudningar...';

  @override
  String invitationsSentMessage(int count) {
    return 'Inbjudningar har skickats till $count målgrupper.';
  }

  @override
  String get invitationsSentTitle => 'Inbjudningar skickade';

  @override
  String invitationTargetsSelectedForInvitation(int count) {
    return 'Du har valt $count målgrupper för inbjudan.';
  }

  @override
  String get invitationTryDifferentSearch =>
      'Prova att söka med andra ord eller kontrollera stavningen.';

  @override
  String get loadingNoContent => 'Inget innehåll';

  @override
  String get menuCommentLabel => 'Kommentar (valfritt)';

  @override
  String get menuDeleteConfirmation =>
      'Är du säker på att du vill ta bort denna meny?';

  @override
  String menuDeletedSuccess(String name) {
    return 'Meny \"$name\" borttagen';
  }

  @override
  String get menuDeleteFailed => 'Kunde inte ta bort meny';

  @override
  String get menuDeleteTitle => 'Ta bort meny';

  @override
  String menuLoadedSuccess(String name) {
    return 'Meny \"$name\" laddad!';
  }

  @override
  String get menuLoadFailed => 'Kunde inte ladda meny';

  @override
  String get menuNameLabel => 'Menynamn';

  @override
  String get menuNameRequired => 'Menynamn krävs';

  @override
  String get menuNoSavedMenusDescription =>
      'Du har inga sparade menyer än. Generera och spara en meny först!';

  @override
  String menuRecipesInCategories(int recipeCount, int categoryCount) {
    return '$recipeCount recept i $categoryCount kategorier';
  }

  @override
  String get menuSavedEarlier => 'Sparad tidigare';

  @override
  String get menuSaveTitle => 'Spara meny';

  @override
  String get menuShareWithFriendsDescription =>
      'Dela denna meny med valda vänner';

  @override
  String get menuToSave => 'Meny att spara';

  @override
  String get menuUnnamed => 'Namnlös meny';

  @override
  String get privacyCouldNotLoad =>
      'Kunde inte ladda integritetspolicyn. Försök igen senare.';

  @override
  String get privacyTitle => 'Integritetspolicy';

  @override
  String get recipeAddTags => 'Lägg till taggar';

  @override
  String get recipeChangesSaved => 'Ändringar sparade!';

  @override
  String get recipeContinueEditing => 'Fortsätt redigera';

  @override
  String get recipeCopySaved => 'Din kopia av receptet sparades!';

  @override
  String get recipeCouldNotSaveChanges => 'Kunde inte spara ändringar';

  @override
  String get recipeCouldNotSaveCopy => 'Kunde inte spara din kopia';

  @override
  String get recipeFromArchive => 'Från arkiv';

  @override
  String get recipeFromImage => 'Från bild';

  @override
  String get recipeImportedFromShare => 'Importerat från delning';

  @override
  String get recipeImportLink => 'Importera länk';

  @override
  String get recipeIngredient => 'Ingrediens';

  @override
  String get recipeInstruction => 'Instruktion';

  @override
  String get recipeLeaveWithoutSaving => 'Lämna utan att spara';

  @override
  String get recipeManageAllTags => 'Hantera alla taggar';

  @override
  String get recipeRating => 'Betyg (0–5)';

  @override
  String get recipeSourceUrl => 'Källa (URL)';

  @override
  String get recipeSourceUrlHelper => 'Länk till originalreceptet';

  @override
  String get recipeSourceUrlHint => 'Valfritt: länk till originalreceptet';

  @override
  String get recipeTagsUpdated => 'Taggar uppdaterade';

  @override
  String get recipeTimeMinutes => 'Tid (min)';

  @override
  String get recipeUnsavedChangesTitle => 'Osparade ändringar';

  @override
  String get recipeWriteManually => 'Skriv manuellt';

  @override
  String get searchRecipesHint => 'sök bland recepten...';

  @override
  String get shoppingAddItems => 'Lägg till';

  @override
  String shoppingAddItemsFromMenu(int count, String listName) {
    return 'Lägg till $count artiklar från menyn i \"$listName\"';
  }

  @override
  String get shoppingCreateFirstListDescription =>
      'Skapa din första inköpslista för att komma igång';

  @override
  String shoppingItemsAdded(int count, String listName) {
    return '$count artiklar tillagda i \"$listName\"';
  }

  @override
  String shoppingItemsAddFailed(String error) {
    return 'Kunde inte lägga till artiklar: $error';
  }

  @override
  String shoppingListCreateFailed(String error) {
    return 'Kunde inte skapa lista: $error';
  }

  @override
  String get socialTotalMembers => 'Totalt medlemmar';

  @override
  String get userNoUsers => 'Inga användare';

  @override
  String get userNoUsersToShow => 'Inga användare att visa';

  @override
  String get chatAttachments => 'Bilagor';

  @override
  String get chatAttachmentTypes =>
      'Bilagor: Recept, Meny, Handlingslista, Foto';

  @override
  String get chatCouldNotSendMessage =>
      'Kunde inte skicka meddelandet. Försök igen.';

  @override
  String get chatLoadingMessages => 'Laddar meddelanden...';

  @override
  String get chatNoMessages => 'Inga meddelanden än';

  @override
  String get chatSend => 'Skicka';

  @override
  String get chatSendImage => 'Skicka bild';

  @override
  String get chatSendToStartConversation =>
      'Skicka ett meddelande för att starta konversationen';

  @override
  String get chatWriteMessage => 'Skriv ett meddelande...';

  @override
  String get commonOr => 'eller';

  @override
  String get errorCouldNotLoadPage => 'Kunde inte ladda sidan';

  @override
  String get errorLoadingRetryOrGoBack =>
      'Ett fel uppstod vid laddning. Försök igen eller gå tillbaka.';

  @override
  String errorSavingWithDetails(String error) {
    return 'Kunde inte spara: $error';
  }

  @override
  String get errorTitle => 'Fel';

  @override
  String errorOccurredWithDetails(String error) {
    return 'Ett fel uppstod: $error';
  }

  @override
  String get filterAllergenFree => 'Allergenfri';

  @override
  String get filterClearAll => 'Rensa alla filter';

  @override
  String get filterCookingTime => 'Tillagningstid';

  @override
  String get filterCreatePersonalTags => 'Skapa personliga taggar';

  @override
  String get filterDietary => 'Specialkost';

  @override
  String get filterExcludeTags => 'Exkludera taggar';

  @override
  String get filterHide => 'Dölj filter';

  @override
  String get filterManageTags => 'Hantera taggar';

  @override
  String get filterMealType => 'Måltidstyp';

  @override
  String get filterPersonalTags => 'Personliga taggar';

  @override
  String get filterRating => 'Betyg';

  @override
  String get filterShow => 'Visa filter';

  @override
  String get importAnalyzingContent => 'Analyserar innehåll...';

  @override
  String get importChooseFromGallery => 'Välj från galleri';

  @override
  String get importChooseFromGallerySubtitle =>
      'Välj en befintlig bild från telefonen';

  @override
  String get importChooseImage => 'Välj bild';

  @override
  String get importChooseImageSource => 'Välj bildkälla';

  @override
  String get importChooseNewImage => 'Välj ny bild';

  @override
  String importConfidenceTooltip(String label, int percentage) {
    return '$label: $percentage% säkerhet';
  }

  @override
  String get importContinueWithImport => 'Fortsätt med import';

  @override
  String get importContinueWithoutOcr => 'Fortsätt utan OCR';

  @override
  String get importCopyManually => 'Kopiera manuellt';

  @override
  String get importCouldNotExtractText => 'Kunde inte extrahera text';

  @override
  String get importExtraction => 'Extraktion';

  @override
  String get importFetchAutomatically => 'Hämta recept automatiskt';

  @override
  String get importFetchFromWebsite => 'Hämta recept från webbsida';

  @override
  String importFetchingFromPlatform(String platform) {
    return 'Hämtar recept från $platform...';
  }

  @override
  String get importFromPhoto => 'Importera från foto';

  @override
  String get importGoodQuality => 'God kvalitet';

  @override
  String get importHighQuality => 'Hög kvalitet';

  @override
  String importImageQualityLow(int percentage) {
    return 'Bildkvaliteten är låg ($percentage%)';
  }

  @override
  String get importImport => 'Importera';

  @override
  String importImportedFrom(String source) {
    return 'Importerad från $source';
  }

  @override
  String get importImprovementSuggestions => 'Förbättringsförslag:';

  @override
  String get importInterpretedText => 'Tolkad text:';

  @override
  String get importLowQuality => 'Låg kvalitet';

  @override
  String get importManualCopy => 'Manuell kopiering';

  @override
  String importManualCopyInstructions(String platform) {
    return '1. Gå tillbaka till $platform\n2. Kopiera recepttexten från inlägget\n3. Kom tillbaka hit och välj \"Klistra in text\"';
  }

  @override
  String get importManually => 'Importera manuellt';

  @override
  String get importNoImageSelected => 'Ingen bild vald';

  @override
  String get importNoRecipeInfoFound =>
      'Ingen receptinformation hittades i texten.';

  @override
  String get importOcrMayFail => 'OCR kan misslyckas eller ge dåliga resultat.';

  @override
  String get importOtherApp => 'annan app';

  @override
  String get importPasteFromClipboard => 'Klistra in från urklipp';

  @override
  String get importPasteLinkOrText => 'Klistra in länk eller text här...';

  @override
  String get importPasteText => 'Klistra in text';

  @override
  String get importPhotoDescription =>
      'Ta bild av ett recept eller välj från galleriet för att importera text automatiskt';

  @override
  String get importPhotoImport => 'Fotoimport';

  @override
  String get importProceedToEdit => 'Gå vidare till redigera';

  @override
  String get importProcessingImage => 'Bearbetar bild...';

  @override
  String get importRecipeLinkDetected => 'Receptlänk detekterad';

  @override
  String get importRecipeTextCanImport =>
      'Recepttext detekterad! Vi kan importera detta.';

  @override
  String get importRecipeTextDetected => 'Recepttext detekterad!';

  @override
  String get importRecipeTitle => 'Importera recept';

  @override
  String get importRemoveImage => 'Ta bort bild';

  @override
  String get importSharedText => 'delad text';

  @override
  String get importTakePhoto => 'Ta ett foto';

  @override
  String get importTakePhotoSubtitle => 'Använd kameran för att fota receptet';

  @override
  String get importTapButtonToSelect => 'Tryck på knappen ovan för att välja';

  @override
  String get importTextContent => 'Textinnehåll';

  @override
  String get importTryAnyway => 'Försök ändå';

  @override
  String get importUnknownSource => 'Okänd källa';

  @override
  String importUrlFromPlatform(String platform) {
    return 'URL från $platform';
  }

  @override
  String get importVideoNoText => 'Videon saknar text';

  @override
  String get importVideoNoTextDescription =>
      'Den här videon har inga undertexter som vi kan läsa.\n\nDu kan ta en skärmbild av receptet i videon och importera den istället.';

  @override
  String get importWebRecipeLinkDetected =>
      'Receptlänk från webbsida detekterad!';

  @override
  String get importWebsite => 'Webbsida';

  @override
  String get groupAddMembers => 'Lägg till medlemmar';

  @override
  String get groupAllFriendsAlreadyMembers =>
      'Alla dina vänner är redan medlemmar i denna grupp, eller så har du redan skickat inbjudningar till dem.';

  @override
  String get groupCouldNotLoadMembers => 'Kunde inte ladda gruppmedlemmar';

  @override
  String get groupCouldNotTransferOwnership =>
      'Kunde inte överföra ägande. Försök igen.';

  @override
  String groupDeleted(String name) {
    return 'Gruppen \"$name\" har tagits bort';
  }

  @override
  String get groupInvitationSent => 'Skickad';

  @override
  String groupInvitationsSent(int count) {
    return '$count inbjudningar skickade';
  }

  @override
  String get groupInvitationsSentSuccess => 'Inbjudningar har skickats!';

  @override
  String get groupLoadingInfo => 'Laddar gruppinformation...';

  @override
  String get groupNoFriendsAvailable => 'Inga vänner tillgängliga';

  @override
  String get groupNoMembersToShare => 'Gruppen har inga medlemmar att dela med';

  @override
  String get groupNotFound => 'Grupp hittades inte';

  @override
  String get groupNotFoundDescription =>
      'Den här gruppen kanske har tagits bort eller så saknar du behörighet.';

  @override
  String get groupOwnershipTransferredAndLeft =>
      'Ägande överfört och du har lämnat gruppen';

  @override
  String groupSelectedOfTotal(int selected, int total) {
    return '$selected av $total vald(a)';
  }

  @override
  String groupSendInvitations(int count) {
    return 'Skicka $count inbjudningar';
  }

  @override
  String groupSharedFromGroup(String name) {
    return 'Delad från gruppen $name';
  }

  @override
  String get groupUpdated => 'Gruppen uppdaterades!';

  @override
  String get groupYouLeftGroup => 'Du har lämnat gruppen';

  @override
  String get loadingGeneric => 'Laddar...';

  @override
  String get loadingRecipes => 'Laddar recept...';

  @override
  String menuCategoryCount(int count) {
    return '$count kategorier';
  }

  @override
  String menuConnectingCollaborative(String title) {
    return 'Ansluter till \"$title\" för samarbetsredigering...';
  }

  @override
  String get menuCouldNotHide => 'Kunde inte dölja meny';

  @override
  String menuHiddenFromList(String title) {
    return '\"$title\" dold från din lista';
  }

  @override
  String menuHideConfirm(String title, String sharedBy) {
    return 'Vill du dölja \"$title\" från din lista?\n\nDu kan fortfarande komma åt menyn genom att be $sharedBy att dela den igen.';
  }

  @override
  String get menuHideMenu => 'Dölj meny';

  @override
  String get menuImportAll => 'Importera hela menyn';

  @override
  String menuImportDescription(int count) {
    return 'När du importerar menyn läggs alla $count recept till i din samling.';
  }

  @override
  String get menuImported => 'Meny importerad';

  @override
  String menuImportedSuccess(String title) {
    return 'Meny \"$title\" importerad!';
  }

  @override
  String get menuImportFailed => 'Import misslyckades';

  @override
  String get menuNoRecipesInMenu => 'Inga recept i menyn';

  @override
  String get menuSharedMenu => 'DELAD MENY';

  @override
  String get menuShareMenu => 'Dela meny';

  @override
  String menuSharingComingSoon(String title) {
    return 'Delning av \"$title\" kommer snart!';
  }

  @override
  String menuSavedSuccess(String name) {
    return 'Menyn \"$name\" sparades!';
  }

  @override
  String get menuSaveFailed => 'Kunde inte spara menyn';

  @override
  String get navigationGoHome => 'Till start';

  @override
  String get navigationSubtitle => 'Din digitala kokbok';

  @override
  String get permissionCopy => 'Kopia';

  @override
  String get permissionCreatingCopy => 'Skapar kopia...';

  @override
  String get permissionNoAccess => 'Ingen åtkomst';

  @override
  String get permissionSaveAsNew => 'Spara som ny';

  @override
  String get permissionSaveChanges => 'Spara ändringar';

  @override
  String get permissionSaveMyCopy => 'Spara min kopia';

  @override
  String get permissionSaving => 'Sparar...';

  @override
  String get privacyContactUs => 'Kontakta oss';

  @override
  String get privacyCouldNotOpenEmail => 'Kunde inte öppna e-postklienten';

  @override
  String get privacyGdprCompliant =>
      'Denna integritetspolicy uppfyller kraven i GDPR';

  @override
  String get privacyLoading => 'Laddar integritetspolicy...';

  @override
  String get privacyNotAvailable => 'Integritetspolicyn är inte tillgänglig';

  @override
  String get privacyQuestionsTitle => 'Frågor om integritet?';

  @override
  String get privacyReload => 'Ladda om';

  @override
  String get profileAddAvatar => 'Lägg till avatar';

  @override
  String get profileAvatarRemoved => 'Avatar borttagen';

  @override
  String get profileAvatarUploaded => 'Avatar uppladdad!';

  @override
  String get profileChangeAvatar => 'Ändra avatar';

  @override
  String get profileCouldNotSave => 'Kunde inte spara profil';

  @override
  String get profileCouldNotUploadAvatar => 'Kunde inte ladda upp avatar';

  @override
  String get profileDisplayName => 'Visningsnamn';

  @override
  String get profileDisplayNameHint => 'Ditt namn som andra ser';

  @override
  String get profileFormReset => 'Formulär återställt';

  @override
  String get profileLanguage => 'Språk';

  @override
  String profileLanguageChangedTo(String language) {
    return 'Språk ändrat till $language';
  }

  @override
  String get profileLoading => 'Laddar profil...';

  @override
  String get profileNewUser => 'Ny användare';

  @override
  String get profilePrivacySettings => 'Integritetsinställningar';

  @override
  String get profileResetChanges => 'Återställ ändringar';

  @override
  String get profileSaved => 'Profil sparad!';

  @override
  String get profileSaveProfile => 'Spara profil';

  @override
  String get profileSearchableByEmail => 'Sökbar via e-post';

  @override
  String get profileSearchableByEmailDescription =>
      'Andra kan hitta dig genom din e-postadress';

  @override
  String get profileTheme => 'Tema';

  @override
  String profileThemeChangedTo(String theme) {
    return 'Tema ändrat till $theme';
  }

  @override
  String get profileThemeDark => 'Mörkt läge';

  @override
  String get profileThemeLight => 'Ljust läge';

  @override
  String get profileThemeSystem => 'Systemets inställning';

  @override
  String get profileUnsavedChanges => 'Osparade ändringar';

  @override
  String get profileUnsavedChangesMessage =>
      'Du har osparade ändringar. Vill du spara innan du lämnar?';

  @override
  String get profileUploadingAvatar => 'Laddar upp avatar...';

  @override
  String get profileVisibleInSearch => 'Synlig i sökningar';

  @override
  String get profileVisibleInSearchDescription =>
      'Andra användare kan hitta dig när de söker';

  @override
  String get profileYouHaveUnsavedChanges => 'Du har osparade ändringar';

  @override
  String get recipeCouldNotSave => 'Kunde inte spara recept';

  @override
  String get recipeCouldNotDelete => 'Kunde inte ta bort recept';

  @override
  String get recipeCouldNotMarkAsCooked => 'Kunde inte markera som lagat';

  @override
  String get recipeCouldNotOpenEditor => 'Kunde inte öppna redigeringsvy';

  @override
  String get recipeCouldNotShare => 'Kunde inte dela recept';

  @override
  String get recipeDeleted => 'Recept borttaget';

  @override
  String get recipeMarkedAsCooked => 'Recept markerat som lagat idag!';

  @override
  String get recipeShared => 'Recept delat';

  @override
  String recipeImportedFrom(String sourceUrl) {
    return 'Importerat från: $sourceUrl';
  }

  @override
  String get recipeSaved => 'Recept sparat!';

  @override
  String get recipeSavedTaggingFailed =>
      'Recept sparat, men taggning misslyckades. Allergeninformation kan vara ofullständig.';

  @override
  String recipeSavedWithTags(int tagCount, int coverage) {
    return 'Recept sparat! $tagCount taggar ($coverage%)';
  }

  @override
  String get recipeSaveStartedDuringDialog =>
      'En sparning påbörjades under valet. Vänta medan receptet sparas...';

  @override
  String get recipeWaitWhileSaving => 'Vänta medan receptet sparas...';

  @override
  String get recipeWriteNew => 'Skriv nytt recept';

  @override
  String recipeAddItem(String label) {
    return 'Lägg till $label';
  }

  @override
  String get recipeSave => 'Spara recept';

  @override
  String get recipeSaving => 'Sparar recept...';

  @override
  String get recipeTag => 'Tagg';

  @override
  String searchFiltersActive(int count) {
    return '$count filter aktiva';
  }

  @override
  String get searchQuery => 'Sökning';

  @override
  String searchResults(int count) {
    return '$count resultat';
  }

  @override
  String shareFailed(String error) {
    return 'Delning misslyckades: $error';
  }

  @override
  String get socialCategories => 'Kategorier';

  @override
  String get socialCategoryStatistics => 'Kategoristatistik';

  @override
  String get socialCreateCategory => 'Skapa kategori';

  @override
  String socialMembersCount(int count) {
    return '$count medlemmar';
  }

  @override
  String get socialNoCategories => 'Inga kategorier';

  @override
  String get socialBeFirstToComment =>
      'Var först med att kommentera detta recept!';

  @override
  String get socialCommentPosted => 'Kommentar postad';

  @override
  String get socialComments => 'Kommentarer';

  @override
  String socialCommentsCount(int count) {
    return '$count kommentarer';
  }

  @override
  String get socialCouldNotCreateProfile => 'Kunde inte skapa användarprofil';

  @override
  String get socialCouldNotFetchUserData => 'Kunde inte hämta användardata';

  @override
  String get socialCouldNotPostComment => 'Kunde inte posta kommentar';

  @override
  String socialCouldNotStartConversation(String error) {
    return 'Kunde inte starta konversation: $error';
  }

  @override
  String get socialCouldNotUpdateLike => 'Kunde inte uppdatera gilla-markering';

  @override
  String get socialFriendFromList => 'vän från din vänlista';

  @override
  String socialFriendRemoved(String name) {
    return '$name borttagen från vänlista';
  }

  @override
  String get socialFriends => 'Vänner';

  @override
  String get socialLoadingComments => 'Laddar kommentarer...';

  @override
  String get socialMustBeLoggedInToComment =>
      'Du måste vara inloggad för att kommentera';

  @override
  String get socialMustBeLoggedInToLike =>
      'Du måste vara inloggad för att gilla';

  @override
  String get socialNoCommentsYet => 'Inga kommentarer än';

  @override
  String get socialRecipes => 'Recept';

  @override
  String get socialSendMessage => 'Skicka meddelande';

  @override
  String get socialShareRecipe => 'Dela recept';

  @override
  String get socialStartingConversation => 'Startar konversation...';

  @override
  String get socialStatistics => 'Statistik';

  @override
  String get socialUserProfileCreated => 'Användarprofil skapad';

  @override
  String shoppingAddIngredientsFrom(String title) {
    return 'Lägg till ingredienser från \"$title\"';
  }

  @override
  String get shoppingAddToShoppingList => 'Lägg till i inköpslista';

  @override
  String get shoppingCouldNotAddIngredients =>
      'Kunde inte lägga till ingredienser i inköpslistan';

  @override
  String get shoppingCouldNotCreateOrSelectList =>
      'Kunde inte skapa eller välja inköpslista';

  @override
  String shoppingIngredientsAddedToList(int count, String listName) {
    return '$count ingredienser har lagts till i \"$listName\".\n\nVill du gå till inköpslistan nu?';
  }

  @override
  String shoppingIngredientsFromRecipe(int count, String title) {
    return '$count ingredienser från \"$title\":';
  }

  @override
  String get shoppingNoEditPermission =>
      'Du har inte behörighet att redigera denna inköpslista';

  @override
  String get shoppingNoEditPermissionShared =>
      'Du har inte behörighet att redigera denna delade inköpslista';

  @override
  String get shoppingNoIngredientsToAdd =>
      'Receptet har inga ingredienser att lägga till';

  @override
  String get shoppingSelectList => 'Välj inköpslista';

  @override
  String get shoppingViewList => 'Visa lista';

  @override
  String get shoppingYourList => 'din inköpslista';

  @override
  String get shoppingSharedLists => 'Delade inköpslistor';

  @override
  String sharedByUser(String name) {
    return 'Delat av $name';
  }

  @override
  String get sharedContentWillAppearHere =>
      'När vänner delar recept eller menyer med dig kommer de att visas här.';

  @override
  String get sharedHideFromList => 'Dölj från min lista';

  @override
  String get sharedLoadingContent => 'Laddar delat innehåll...';

  @override
  String get sharedNoContentYet => 'Inga delade recept än';

  @override
  String get socialAddFriends => 'Lägg till vänner';

  @override
  String get taggingAnalyzingIngredients => 'Analyserar ingredienser...';

  @override
  String get taggingCouldNotAnalyze => 'Kunde inte analysera recept';

  @override
  String get taggingCouldNotSaveTags => 'Kunde inte spara taggar';

  @override
  String get taggingCreateTag => 'Skapa tagg';

  @override
  String get taggingCreateTagsToOrganize =>
      'Skapa taggar för att organisera dina recept';

  @override
  String taggingError(String error) {
    return 'Fel vid taggning: $error';
  }

  @override
  String get taggingManageTags => 'Hantera taggar';

  @override
  String get taggingNoPersonalTags => 'Inga personliga taggar';

  @override
  String get taggingPersonalTags => 'Personliga taggar';

  @override
  String get taggingPersonalTagsRemoved => 'Personliga taggar borttagna';

  @override
  String taggingPersonalTagsSaved(int count) {
    return '$count personliga taggar sparade';
  }

  @override
  String taggingTagsGenerated(int count, int coverage) {
    return '$count taggar genererade ($coverage% täckning)';
  }

  @override
  String taggingTagsSelected(int count) {
    return '$count taggar valda';
  }

  @override
  String taggingUpdateTagsMessage(String title) {
    return 'Analyserar ingredienser och uppdaterar allergen- och kosttaggar för \"$title\".';
  }

  @override
  String get taggingUpdateTagsTitle => 'Uppdatera taggar?';

  @override
  String get sortMealType => 'Måltidstyp';

  @override
  String get sortRating => 'Betyg';

  @override
  String get sortTime => 'Tid';

  @override
  String get sortTitle => 'Titel';

  @override
  String get stateAddRecipes => 'Lägg till recept';

  @override
  String get stateCreateWeeklyMenu => 'Skapa veckomeny';

  @override
  String get stateGenerateMenu => 'Generera meny';

  @override
  String get commonStart => 'Starta';

  @override
  String get discoveryAllRecommendationsComingSoon =>
      'Visa alla rekommendationer kommer snart!';

  @override
  String get discoveryBuildingRecommendations => 'Bygger rekommendationer';

  @override
  String get discoveryCouldNotHideRecommendation =>
      'Kunde inte dölja rekommendation just nu.';

  @override
  String get discoveryCouldNotRestoreRecommendation =>
      'Kunde inte återställa rekommendation.';

  @override
  String get discoveryCouldNotSendFeedback =>
      'Kunde inte skicka feedback just nu.';

  @override
  String get discoveryFeedbackThanksImproving =>
      'Tack för din feedback! Vi förbättrar rekommendationerna.';

  @override
  String get discoveryFriendActivity => 'Vänners aktivitet';

  @override
  String get discoveryFriendActivityDescription =>
      'När dina vänner delar recept, menyer eller inköpslistor visas de här.';

  @override
  String get discoveryFriendActivityWillAppearHere =>
      'Aktivitet från dina vänner visas här';

  @override
  String get discoveryFriendsChoice => 'Vänners val';

  @override
  String get discoveryLearningPreferences =>
      'Vi lär oss dina preferenser för att ge bättre rekommendationer.';

  @override
  String get discoveryLike => 'Gilla';

  @override
  String get discoveryListening => 'Lyssnar...';

  @override
  String get discoveryLists => 'Listor';

  @override
  String get discoveryLoadingPopularContent => 'Laddar populärt innehåll...';

  @override
  String get discoveryNoFriendActivityYet => 'Ingen vänaktivitet än';

  @override
  String get discoveryNoPopularRecipesYet => 'Inga populära recept än';

  @override
  String get discoveryPerformedAction => 'Utförde en aktivitet';

  @override
  String get discoveryPopular => 'Populärt';

  @override
  String get discoveryPopularContent => 'Populärt innehåll';

  @override
  String get discoveryPopularMenus => 'Populära menyer';

  @override
  String get discoveryPopularRecipes => 'Populära recept';

  @override
  String get discoveryPopularShoppingLists => 'Populära inköpslistor';

  @override
  String get discoveryPopularWithFriends => 'Populärt bland vänner';

  @override
  String get discoveryPopularWithFriendsDescription =>
      'Innehåll som dina vänner gillar och delar';

  @override
  String discoveryPortions(int count) {
    return '$count portioner';
  }

  @override
  String get discoveryRecently => 'Nyligen';

  @override
  String get discoveryRecentlyShared => 'Nyligen delat';

  @override
  String get discoveryRecentlySharedDescription =>
      'Senast delade innehåll i ditt nätverk';

  @override
  String get discoveryRecommendationHidden =>
      'Rekommendation dold. Vi visar inte liknande innehåll.';

  @override
  String get discoveryRecommendationRestored => 'Rekommendation återställd.';

  @override
  String get discoveryRecommended => 'Rekommenderat';

  @override
  String get discoveryRecommendedForYou => 'Rekommenderat för dig';

  @override
  String get discoverySearchFilters => 'Sökfilter';

  @override
  String get discoverySearchHint => 'Sök recept, menyer, inköpslistor...';

  @override
  String discoverySearchResultsFor(int count, String query) {
    return '$count resultat för \"$query\"';
  }

  @override
  String get discoverySeasonal => 'Säsong';

  @override
  String discoverySharedBy(String name) {
    return 'Delad av $name';
  }

  @override
  String get discoverySharing => 'delning';

  @override
  String get discoverySimilarToShared => 'Liknar delat';

  @override
  String discoveryTimeAgoDays(int count) {
    return '${count}d sedan';
  }

  @override
  String discoveryTimeAgoHours(int count) {
    return '${count}h sedan';
  }

  @override
  String discoveryTimeAgoMinutes(int count) {
    return '${count}m sedan';
  }

  @override
  String get discoveryTimeAgoNow => 'Nu';

  @override
  String get discoveryUnknownContent => 'Okänt innehåll';

  @override
  String get discoveryUnknownUser => 'Okänd användare';

  @override
  String discoveryUserSharedType(String user, String type) {
    return '$user delade $type';
  }

  @override
  String get discoveryVoiceSearch => 'Röstsökning';

  @override
  String get discoveryVoiceSearchInstruction =>
      'Tryck på mikrofonen och börja prata';

  @override
  String get discoveryVoiceSearchPreview =>
      'Sökning startad! (Röstsökning är en förhandsversion)';

  @override
  String get discoveryVoiceSearchPrompt => 'Säg vad du vill söka efter...';

  @override
  String get discoveryVoiceSearchResult => 'Röstsökning: \"pasta recept\"';

  @override
  String groupInvitationsCount(int count) {
    return 'Gruppinbjudningar ($count)';
  }

  @override
  String get groupInvitationsDescription =>
      'Du har fått inbjudningar att gå med i grupper';

  @override
  String get groupLoadingGroups => 'Laddar grupper...';

  @override
  String groupMyGroupsCount(int count) {
    return 'Mina grupper ($count)';
  }

  @override
  String get groupNoGroupsDescription =>
      'Skapa din första grupp eller vänta på inbjudningar från vänner.';

  @override
  String get groupNoGroupsYet => 'Inga grupper än';

  @override
  String get groupSearchGroups => 'Sök bland dina grupper';

  @override
  String get groupSearchGroupsDescription =>
      'Skriv ett gruppnamn i sökfältet ovan för att filtrera dina grupper.';

  @override
  String get groupCouldNotAcceptInvitation =>
      'Kunde inte acceptera inbjudan. Försök igen.';

  @override
  String get groupCreated => 'Skapad';

  @override
  String get groupDaysActive => 'Dagar aktiv';

  @override
  String get groupDeleteGroup => 'Ta bort grupp';

  @override
  String get groupViewMembers => 'Visa medlemmar';

  @override
  String get groupEditGroup => 'Redigera grupp';

  @override
  String get groupInformation => 'Gruppinformation';

  @override
  String get groupInvitationAccepted =>
      'Inbjudan accepterad! Välkommen till gruppen!';

  @override
  String get groupInvitationDeclined => 'Inbjudan avvisad';

  @override
  String groupInvitationFrom(String name) {
    return 'Inbjudan från $name';
  }

  @override
  String get groupLeaveGroup => 'Lämna grupp';

  @override
  String groupMemberCount(int count) {
    return '$count personer';
  }

  @override
  String get groupMembers => 'Medlemmar';

  @override
  String get groupMembersAndInvitations => 'Medlemmar & Inbjudningar';

  @override
  String groupMembersCount(int count) {
    return 'Medlemmar ($count)';
  }

  @override
  String get groupNoDescription => 'Ingen beskrivning';

  @override
  String get groupNoMembersDescription =>
      'Lägg till vänner i den här gruppen för att komma igång.';

  @override
  String get groupNoMembersYet => 'Inga medlemmar än';

  @override
  String groupPendingInvitationsCount(int count) {
    return 'Väntande inbjudningar ($count)';
  }

  @override
  String get groupSent => 'Skickat';

  @override
  String get groupUpdatedDate => 'Uppdaterad';

  @override
  String get groupYesterday => 'Igår';

  @override
  String get commonAccept => 'Acceptera';

  @override
  String get commonDecline => 'Avvisa';

  @override
  String shoppingItemCount(int count) {
    return '$count varor';
  }

  @override
  String get socialAddFriendsToGetStarted =>
      'Lägg till vänner för att komma igång med social funktionalitet.';

  @override
  String get socialLoadingFriends => 'Laddar vänner...';

  @override
  String get socialNoFriendsYet => 'Inga vänner än';

  @override
  String get socialSearchForNewFriends => 'Sök efter nya vänner';

  @override
  String get socialSearchForNewFriendsDescription =>
      'Skriv ett namn eller användarnamn i sökfältet ovan för att hitta nya vänner.';

  @override
  String get socialSearchingUsers => 'Söker användare...';

  @override
  String get socialBlocked => 'Blockerad';

  @override
  String get socialCouldNotAcceptFriendRequest =>
      'Kunde inte acceptera vänskapsförfrågan';

  @override
  String get socialCouldNotFindFriendRequest =>
      'Kunde inte hitta vänskapsförfrågan';

  @override
  String get socialCouldNotSendFriendRequest =>
      'Kunde inte skicka vänförfrågan';

  @override
  String get socialDefaultFriendMessage => 'Hej! Skulle vi kunna bli vänner?';

  @override
  String get socialFindNewFriends => 'Hitta nya vänner';

  @override
  String get socialFindNewFriendsDescription =>
      'Använd sökfältet ovan för att hitta personer du vill bli vän med. Sök på namn eller användarnamn.';

  @override
  String get socialFriendRequestAccepted => 'Vänskapsförfrågan accepterad!';

  @override
  String socialFriendRequestAcceptedFrom(String name) {
    return 'Vänskapsförfrågan från $name accepterad!';
  }

  @override
  String get socialFriendRequestDeclined => 'Vänskapsförfrågan avböjd';

  @override
  String socialFriendRequestSent(String name) {
    return 'Vänförfrågan skickad till $name!';
  }

  @override
  String get socialIncomingRequests => 'Inkommande förfrågningar';

  @override
  String get socialNoFriendRequests => 'Inga vänskapsförfrågningar';

  @override
  String get socialNoFriendRequestsDescription =>
      'Börja söka efter vänner ovan för att utvidga ditt nätverk!';

  @override
  String get socialRequestSent => 'Skickad';

  @override
  String get socialSentRequests => 'Skickade förfrågningar';

  @override
  String get socialWaitingForResponse => 'Väntar på svar...';

  @override
  String get addRecipeTitle => 'Lägg till recept';

  @override
  String get authPassword => 'Lösenord';

  @override
  String get authTagline => 'Smart recepthantering för din vardag';

  @override
  String get collaborativeAdd => 'Lägg till';

  @override
  String get collaborativeAddFirstItem => 'Lägg till den första varan';

  @override
  String get collaborativeAdding => 'Lägger till...';

  @override
  String get collaborativeAddItemHint => 'Skriv varunamn...';

  @override
  String get collaborativeClearAll => 'Rensa alla';

  @override
  String get collaborativeClearCompleted => 'Rensa avprickade';

  @override
  String get collaborativeClearCompletedConfirm =>
      'Vill du rensa alla avprickade varor?';

  @override
  String collaborativeClearCompletedMessage(int count) {
    return 'Vill du rensa $count avprickade varor?';
  }

  @override
  String get collaborativeCompleted => 'Avprickade';

  @override
  String collaborativeCompletedItemsCleared(int count) {
    return '$count avprickade varor rensade';
  }

  @override
  String collaborativeCompletedOf(int completed, int total) {
    return '$completed av $total avprickade';
  }

  @override
  String get collaborativeCopyLink => 'Kopiera länk';

  @override
  String get collaborativeCopyLinkDescription => 'Dela via länk';

  @override
  String get collaborativeCouldNotClearCompleted =>
      'Kunde inte rensa avprickade varor';

  @override
  String get collaborativeEmailSharingComingSoon =>
      'E-postdelning kommer snart';

  @override
  String get collaborativeLinkCopied => 'Länk kopierad!';

  @override
  String get collaborativeManageMembers => 'Hantera medlemmar';

  @override
  String get collaborativeMembersComingSoon => 'Medlemshantering kommer snart';

  @override
  String get collaborativeMessageSharingComingSoon =>
      'Meddelandedelning kommer snart';

  @override
  String get collaborativeMoreActions => 'Fler åtgärder';

  @override
  String get collaborativeNoCompletedItems => 'Inga avprickade varor';

  @override
  String get collaborativeNoItemsYet => 'Inga varor ännu';

  @override
  String get collaborativeSendEmail => 'Skicka e-post';

  @override
  String get collaborativeSendEmailDescription => 'Dela via e-post';

  @override
  String get collaborativeSendMessage => 'Skicka meddelande';

  @override
  String get collaborativeSendMessageDescription => 'Dela via meddelande';

  @override
  String get collaborativeSettings => 'Inställningar';

  @override
  String get collaborativeSettingsComingSoon => 'Inställningar kommer snart';

  @override
  String get collaborativeShareList => 'Dela listan';

  @override
  String get collaborativeViewOnly => 'Kan bara se';

  @override
  String get collaborativeWaitingForOthers => 'Väntar på andra...';

  @override
  String get commonActionCannotBeUndone => 'Denna åtgärd kan inte ångras.';

  @override
  String get commonDescription => 'Beskrivning';

  @override
  String get commonShowMore => 'Visa mer';

  @override
  String get commonType => 'Typ';

  @override
  String get commonUnknownError => 'Ett okänt fel inträffade';

  @override
  String get commonView => 'Visa';

  @override
  String get discoveryClearSearch => 'Rensa sökning';

  @override
  String get groupCancelInvitation => 'Avbryt inbjudan';

  @override
  String get groupCancelInvitationConfirm =>
      'Är du säker på att du vill avbryta denna inbjudan?';

  @override
  String groupCancelInvitationMessage(String name) {
    return 'Vill du avbryta inbjudan till $name?';
  }

  @override
  String groupCouldNotCreate(String error) {
    return 'Kunde inte skapa grupp: $error';
  }

  @override
  String groupCouldNotDelete(String error) {
    return 'Kunde inte ta bort grupp: $error';
  }

  @override
  String groupCouldNotLeave(String error) {
    return 'Kunde inte lämna grupp: $error';
  }

  @override
  String groupCouldNotRemoveMember(String error) {
    return 'Kunde inte ta bort medlem: $error';
  }

  @override
  String groupCouldNotUpdate(String error) {
    return 'Kunde inte uppdatera grupp: $error';
  }

  @override
  String get groupCreatedSuccess => 'Grupp skapad!';

  @override
  String get groupCreateGroup => 'Skapa grupp';

  @override
  String get groupCreator => 'Skapare';

  @override
  String get groupEmoji => 'Emoji';

  @override
  String get groupGroupName => 'Gruppnamn';

  @override
  String get groupInvitationCancelled => 'Inbjudan avbruten';

  @override
  String get groupInvitationExpires => 'Inbjudan går ut';

  @override
  String get groupInvitationSentDate => 'Skickad';

  @override
  String get groupItemType => 'Typ';

  @override
  String get groupLeave => 'Lämna';

  @override
  String groupLeaveGroupConfirm(String name) {
    return 'Vill du lämna gruppen $name?';
  }

  @override
  String get groupLeftGroup => 'Du har lämnat gruppen';

  @override
  String get groupManageGroup => 'Hantera grupp';

  @override
  String groupMemberRemoved(String name) {
    return '$name har tagits bort';
  }

  @override
  String get groupOwner => 'Ägare';

  @override
  String get groupRemoveFromGroup => 'Ta bort från grupp';

  @override
  String get groupRemoveMember => 'Ta bort medlem';

  @override
  String groupRemoveMemberConfirm(String name, String groupName) {
    return 'Vill du ta bort $name från $groupName?';
  }

  @override
  String get groupShareMenu => 'Dela meny';

  @override
  String get groupShareRecipe => 'Dela recept';

  @override
  String get groupShareWithGroup => 'Dela med grupp';

  @override
  String get groupYesCancel => 'Ja, avbryt';

  @override
  String get sharedAlreadyMember => 'Du är redan medlem';

  @override
  String get sharedContent => 'Delat innehåll';

  @override
  String get sharedCopy => 'Kopiera';

  @override
  String get sharedCouldNotHideMenu => 'Kunde inte dölja meny';

  @override
  String get sharedCouldNotHideRecipe => 'Kunde inte dölja recept';

  @override
  String get sharedCouldNotHideShoppingList => 'Kunde inte dölja inköpslista';

  @override
  String get sharedCouldNotJoinList => 'Kunde inte gå med i listan';

  @override
  String get sharedCouldNotJoinListTryAgain =>
      'Kunde inte gå med i listan. Försök igen.';

  @override
  String get sharedHideImported => 'Dölj importerade';

  @override
  String get sharedHideMenu => 'Dölj meny';

  @override
  String get sharedHideRecipe => 'Dölj recept';

  @override
  String get sharedHideShoppingList => 'Dölj inköpslista';

  @override
  String get sharedImport => 'Importera';

  @override
  String get sharedImported => 'Importerad';

  @override
  String get sharedImportFailed => 'Import misslyckades';

  @override
  String get sharedJoin => 'Gå med';

  @override
  String get sharedJoinedButCouldNotNavigate =>
      'Gick med men kunde inte navigera till listan';

  @override
  String get sharedJoinList => 'Gå med i lista';

  @override
  String get sharedLive => 'Live';

  @override
  String get sharedMember => 'Medlem';

  @override
  String get sharedNoMenus => 'Inga delade menyer';

  @override
  String get sharedNoMenusDescription => 'Menyer som delas med dig visas här';

  @override
  String get sharedNoRecipes => 'Inga delade recept';

  @override
  String get sharedNoRecipesDescription => 'Recept som delas med dig visas här';

  @override
  String get sharedNoShoppingLists => 'Inga delade inköpslistor';

  @override
  String get sharedNoShoppingListsDescription =>
      'Inköpslistor som delas med dig visas här';

  @override
  String get sharedSearchHint => 'Sök delat innehåll...';

  @override
  String sharedTabRecipes(int count) {
    return 'Recept ($count)';
  }

  @override
  String sharedTabMenus(int count) {
    return 'Menyer ($count)';
  }

  @override
  String sharedTabShoppingLists(int count) {
    return 'Inköpslistor ($count)';
  }

  @override
  String get sharedShowImported => 'Visa importerade';

  @override
  String get sharedShowingImported => 'Visar importerade';

  @override
  String get sharedTapToSeeAllItems => 'Tryck för att se alla varor';

  @override
  String sharedByName(String name) {
    return 'Delad av $name';
  }

  @override
  String sharedCategoryCount(int count) {
    return '$count kategorier';
  }

  @override
  String sharedConnectingToCollaborativeMenu(String title) {
    return 'Ansluter till samarbetsmeny: $title';
  }

  @override
  String sharedContentHidden(String title) {
    return '$title har dolts';
  }

  @override
  String sharedHideMenuConfirm(String title, String sharedBy) {
    return 'Vill du dölja menyn \"$title\" delad av $sharedBy?';
  }

  @override
  String sharedHideRecipeConfirm(String title, String sharedBy) {
    return 'Vill du dölja receptet \"$title\" delat av $sharedBy?';
  }

  @override
  String sharedHideShoppingListConfirm(String name, String sharedBy) {
    return 'Vill du dölja inköpslistan \"$name\" delad av $sharedBy?';
  }

  @override
  String sharedJoinedList(String name) {
    return 'Gick med i listan \"$name\"';
  }

  @override
  String sharedJoinedListFindInShopping(String name) {
    return 'Gick med i \"$name\". Hitta den under Inköpslistor.';
  }

  @override
  String sharedMenuImported(String title) {
    return 'Menyn \"$title\" har importerats';
  }

  @override
  String sharedRecipeImported(String title) {
    return 'Receptet \"$title\" har importerats';
  }

  @override
  String recipePortionsCount(int count) {
    return '$count portioner';
  }

  @override
  String get shoppingAddedWithEditPermission =>
      'Tillagd med redigeringsbehörighet';

  @override
  String get shoppingAddFriends => 'Lägg till vänner';

  @override
  String get shoppingAdminOwner => 'Admin/Ägare';

  @override
  String get shoppingAdminOwnerDescription => 'Full åtkomst och hantering';

  @override
  String get shoppingAllFriendsAreMembers => 'Alla vänner är redan medlemmar';

  @override
  String get shoppingBy => 'Av';

  @override
  String get shoppingCategoryHint => 'Välj kategori...';

  @override
  String get shoppingCategoryOther => 'Övrigt';

  @override
  String get shoppingClear => 'Rensa';

  @override
  String get shoppingClearPurchasedTitle => 'Rensa köpta varor';

  @override
  String get shoppingCouldNotAddMembers => 'Kunde inte lägga till medlemmar';

  @override
  String get shoppingCouldNotDeleteList => 'Kunde inte ta bort lista';

  @override
  String get shoppingCouldNotRemoveMember => 'Kunde inte ta bort medlem';

  @override
  String get shoppingCouldNotRenameList => 'Kunde inte byta namn på lista';

  @override
  String get shoppingCouldNotUpdatePermission =>
      'Kunde inte uppdatera behörighet';

  @override
  String get shoppingCreateNewList => 'Skapa ny lista';

  @override
  String get shoppingCreateNewListHint => 'Namn på ny inköpslista...';

  @override
  String get shoppingCreateSharedList => 'Skapa delad lista';

  @override
  String get shoppingCreateSharedListDescription =>
      'Skapa en ny inköpslista att dela med vänner';

  @override
  String get shoppingCreator => 'Skapare';

  @override
  String get shoppingDeleteList => 'Ta bort lista';

  @override
  String get shoppingDescriptionHint => 'Lägg till en beskrivning...';

  @override
  String get shoppingDescriptionOptional => 'Beskrivning (valfritt)';

  @override
  String get shoppingItemNameHint => 'Varunamn...';

  @override
  String get shoppingJustNow => 'Just nu';

  @override
  String get shoppingListDetails => 'Listdetaljer';

  @override
  String get shoppingListInfo => 'Listinformation';

  @override
  String get shoppingListTitle => 'Inköpslista';

  @override
  String get shoppingManageSharing => 'Hantera delning';

  @override
  String get shoppingNewNameHint => 'Nytt namn...';

  @override
  String get shoppingNoFriends => 'Inga vänner';

  @override
  String get shoppingNoFriendsDescription =>
      'Lägg till vänner för att dela inköpslistor';

  @override
  String get shoppingNoFriendsFound => 'Inga vänner hittades';

  @override
  String get shoppingNoItemsToShare => 'Inga varor att dela';

  @override
  String get shoppingNoteHint => 'Lägg till anteckning...';

  @override
  String get shoppingNoteOptional => 'Anteckning (valfritt)';

  @override
  String get shoppingPermissionAdmin => 'Administratör';

  @override
  String get shoppingPermissionAdminDescription =>
      'Kan lägga till, ta bort och hantera medlemmar';

  @override
  String get shoppingPermissionAdministrator => 'Administratör';

  @override
  String get shoppingPermissionEdit => 'Redigera';

  @override
  String get shoppingPermissionEditDescription =>
      'Kan lägga till och redigera varor';

  @override
  String get shoppingPermissionOwner => 'Ägare';

  @override
  String get shoppingPermissionShared => 'Delad';

  @override
  String get shoppingPermissionTemplate => 'Mall';

  @override
  String get shoppingPermissionUnspecified => 'Ospecificerad';

  @override
  String get shoppingPermissionUnspecifiedDescription =>
      'Behörighet ej specificerad';

  @override
  String get shoppingPermissionView => 'Visa';

  @override
  String get shoppingPermissionViewDescription => 'Kan se varor men inte ändra';

  @override
  String get shoppingPermissionViewOnly => 'Visa';

  @override
  String get shoppingPersonalList => 'Personlig lista';

  @override
  String get shoppingPurchased => 'Köpta';

  @override
  String get shoppingPurchasedCleared => 'Köpta varor rensade';

  @override
  String get shoppingRecentActivity => 'Senaste aktivitet';

  @override
  String get shoppingRemoveMember => 'Ta bort medlem';

  @override
  String get shoppingSearchFriends => 'Sök vänner...';

  @override
  String get shoppingSelectFriendsToShare => 'Välj vänner att dela med';

  @override
  String get shoppingSharedList => 'Delad lista';

  @override
  String get shoppingSharedListTitle => 'Delad inköpslista';

  @override
  String get shoppingSharedListTitleHint => 'Namn på delad lista...';

  @override
  String get shoppingShareExternally => 'Dela externt';

  @override
  String get shoppingShareInfoBullets =>
      'Medlemmar kan se och redigera varor i realtid';

  @override
  String get shoppingShareWithFriends => 'Dela med vänner';

  @override
  String get shoppingTemplateList => 'Mall';

  @override
  String get shoppingUncheckAll => 'Avmarkera alla';

  @override
  String get shoppingUnitHint => 'Enhet...';

  @override
  String get shoppingUnknownUser => 'Okänd användare';

  @override
  String get shoppingWhatHappensWhenSharing => 'Vad händer när du delar?';

  @override
  String get shoppingWhen => 'När';

  @override
  String get shoppingYourPermission => 'Din behörighet';

  @override
  String shoppingAddFriendsCount(int count) {
    return 'Lägg till $count vänner';
  }

  @override
  String shoppingBoughtOfTotal(int bought, int total) {
    return '$bought av $total köpta';
  }

  @override
  String shoppingClearCount(int count) {
    return 'Rensa $count';
  }

  @override
  String shoppingClearPurchasedMessage(int count) {
    return 'Vill du rensa $count köpta varor?';
  }

  @override
  String shoppingCouldNotAddItem(String name) {
    return 'Kunde inte lägga till $name';
  }

  @override
  String shoppingCouldNotLoadFriends(String error) {
    return 'Kunde inte ladda vänner: $error';
  }

  @override
  String shoppingCouldNotShowShareDialog(String error) {
    return 'Kunde inte visa delningsdialog: $error';
  }

  @override
  String shoppingCouldNotUpdateItem(String name) {
    return 'Kunde inte uppdatera $name';
  }

  @override
  String shoppingCurrentMembers(int count) {
    return 'Nuvarande medlemmar ($count)';
  }

  @override
  String shoppingCurrentName(String name) {
    return 'Nuvarande namn: $name';
  }

  @override
  String shoppingDaysAgo(int days) {
    return '$days dagar sedan';
  }

  @override
  String shoppingDeleteListConfirm(String name) {
    return 'Vill du ta bort listan \"$name\"?';
  }

  @override
  String shoppingDeleteListWithItemsConfirm(String name, int count) {
    return 'Vill du ta bort listan \"$name\" med $count varor?';
  }

  @override
  String shoppingErrorAdding(String error) {
    return 'Fel vid tillägg: $error';
  }

  @override
  String shoppingErrorRemoving(String error) {
    return 'Fel vid borttagning: $error';
  }

  @override
  String shoppingErrorUpdating(String error) {
    return 'Fel vid uppdatering: $error';
  }

  @override
  String shoppingHoursAgo(int hours) {
    return '$hours timmar sedan';
  }

  @override
  String shoppingItemAdded(String name) {
    return '$name tillagd';
  }

  @override
  String shoppingItemCountText(int count) {
    return '$count varor';
  }

  @override
  String shoppingItemUpdated(String name) {
    return '$name uppdaterad';
  }

  @override
  String shoppingListDeleted(String name) {
    return 'Listan \"$name\" borttagen';
  }

  @override
  String shoppingListRenamed(String name) {
    return 'Listan omdöpt till \"$name\"';
  }

  @override
  String shoppingMemberRemoved(String name) {
    return '$name har tagits bort';
  }

  @override
  String shoppingMembersAdded(int count) {
    return '$count medlemmar tillagda';
  }

  @override
  String shoppingMembersCount(int count) {
    return '$count medlemmar';
  }

  @override
  String shoppingMinutesAgo(int minutes) {
    return '$minutes minuter sedan';
  }

  @override
  String shoppingPermissionUpdated(String name) {
    return 'Behörighet uppdaterad för $name';
  }

  @override
  String shoppingRemoveMemberConfirm(String name) {
    return 'Vill du ta bort $name från listan?';
  }

  @override
  String shoppingSharedWithMembers(int count, String permission) {
    return 'Delad med $count ($permission)';
  }

  @override
  String get socialAcceptAll => 'Acceptera alla';

  @override
  String get socialAcceptAllSelectedConfirm =>
      'Acceptera alla valda förfrågningar?';

  @override
  String get socialAcceptSelected => 'Acceptera valda';

  @override
  String get socialBlock => 'Blockera';

  @override
  String get socialBlockUserConfirm => 'Vill du blockera denna användare?';

  @override
  String get socialCancelAll => 'Avbryt alla';

  @override
  String get socialCancelFriendRequestConfirm =>
      'Vill du avbryta denna vänskapsförfrågan?';

  @override
  String get socialCancelRequest => 'Avbryt förfrågan';

  @override
  String get socialCancelSelectedRequestsConfirm =>
      'Avbryt alla valda förfrågningar?';

  @override
  String get socialCouldNotAcceptAllRequests =>
      'Kunde inte acceptera alla förfrågningar';

  @override
  String get socialCouldNotBlockUser => 'Kunde inte blockera användare';

  @override
  String get socialCouldNotCancelAllRequests =>
      'Kunde inte avbryta alla förfrågningar';

  @override
  String get socialCouldNotCancelFriendRequest =>
      'Kunde inte avbryta vänskapsförfrågan';

  @override
  String get socialCouldNotRejectAllRequests =>
      'Kunde inte avvisa alla förfrågningar';

  @override
  String get socialCouldNotRejectFriendRequest =>
      'Kunde inte avvisa vänskapsförfrågan';

  @override
  String get socialCouldNotRemoveFriend => 'Kunde inte ta bort vän';

  @override
  String get socialCouldNotSearchUsers => 'Kunde inte söka användare';

  @override
  String get socialCouldNotUnblockUser => 'Kunde inte avblockera användare';

  @override
  String get socialCouldNotUpdateRequests =>
      'Kunde inte uppdatera förfrågningar';

  @override
  String get socialDecline => 'Avvisa';

  @override
  String get socialDeclined => 'Avvisad';

  @override
  String get socialEnterSearchTerm => 'Ange ett sökord';

  @override
  String get socialExpired => 'Utgången';

  @override
  String get socialFindFriends => 'Hitta vänner';

  @override
  String get socialFriendRequestsUpdated => 'Vänskapsförfrågningar uppdaterade';

  @override
  String get socialFriendsAndGroups => 'Vänner & grupper';

  @override
  String get socialGroups => 'Grupper';

  @override
  String get socialIncoming => 'Inkommande';

  @override
  String get socialLoadingRequests => 'Laddar förfrågningar...';

  @override
  String get socialLoadingSentRequests => 'Laddar skickade förfrågningar...';

  @override
  String get socialNoRequestsSelected => 'Inga förfrågningar valda';

  @override
  String get socialNoSentRequests => 'Inga skickade förfrågningar';

  @override
  String get socialNoSentRequestsDescription =>
      'Du har inga skickade vänskapsförfrågningar';

  @override
  String get socialPendingResponse => 'Väntar på svar';

  @override
  String get socialReject => 'Avvisa';

  @override
  String get socialRejectAll => 'Avvisa alla';

  @override
  String get socialRejectAllSelectedConfirm =>
      'Avvisa alla valda förfrågningar?';

  @override
  String get socialRejectFriendRequestConfirm =>
      'Vill du avvisa denna vänskapsförfrågan?';

  @override
  String get socialRemoveFriendConfirm => 'Vill du ta bort denna vän?';

  @override
  String get socialRequestCancelled => 'Förfrågan avbruten';

  @override
  String get socialSearchGroups => 'Sök grupper...';

  @override
  String get socialSearchNewFriends => 'Sök nya vänner';

  @override
  String get socialUnknownStatus => 'Okänd status';

  @override
  String get socialWantsToBeFriend => 'vill bli din vän';

  @override
  String socialAcceptAllSelectedMessage(int count) {
    return 'Vill du acceptera $count valda förfrågningar?';
  }

  @override
  String socialAcceptCount(int count) {
    return 'Acceptera ($count)';
  }

  @override
  String socialAcceptingRequests(int count) {
    return 'Accepterar $count förfrågningar...';
  }

  @override
  String socialBlockUserMessage(String name) {
    return 'Vill du blockera $name? De kommer inte kunna se din profil eller skicka förfrågningar.';
  }

  @override
  String socialCancelCount(int count) {
    return 'Avbryt ($count)';
  }

  @override
  String socialCancelFriendRequestMessage(String name) {
    return 'Vill du avbryta vänskapsförfrågan till $name?';
  }

  @override
  String socialCancellingRequests(int count) {
    return 'Avbryter $count förfrågningar...';
  }

  @override
  String socialCancelSelectedRequestsMessage(int count) {
    return 'Vill du avbryta $count valda förfrågningar?';
  }

  @override
  String socialDeclineCount(int count) {
    return 'Avvisa ($count)';
  }

  @override
  String socialFriendRequestCancelled(String name) {
    return 'Vänskapsförfrågan till $name avbruten';
  }

  @override
  String socialFriendRequestRejected(String name) {
    return 'Vänskapsförfrågan från $name avvisad';
  }

  @override
  String socialNotificationsCount(int count) {
    return 'Aviseringar ($count)';
  }

  @override
  String socialRejectAllSelectedMessage(int count) {
    return 'Vill du avvisa $count valda förfrågningar?';
  }

  @override
  String socialRejectFriendRequestMessage(String name) {
    return 'Vill du avvisa vänskapsförfrågan från $name?';
  }

  @override
  String socialRejectingRequests(int count) {
    return 'Avvisar $count förfrågningar...';
  }

  @override
  String socialRemoveFriendMessage(String name) {
    return 'Vill du ta bort $name som vän?';
  }

  @override
  String socialRequestsAccepted(int count) {
    return '$count förfrågningar accepterade';
  }

  @override
  String socialRequestsCancelled(int count) {
    return '$count förfrågningar avbrutna';
  }

  @override
  String socialRequestsRejected(int count) {
    return '$count förfrågningar avvisade';
  }

  @override
  String socialRequestsSelected(int count) {
    return '$count valda';
  }

  @override
  String socialUserBlocked(String name) {
    return '$name har blockerats';
  }

  @override
  String socialUserUnblocked(String name) {
    return '$name har avblockerats';
  }

  @override
  String get authLogin => 'Logga in';

  @override
  String get authCreateAccount => 'Skapa konto';

  @override
  String get authYourName => 'Ditt namn';

  @override
  String get authEnterYourName => 'Ange ditt namn';

  @override
  String get authEmail => 'E-post';

  @override
  String get authEmailHint => 'din.email@exempel.se';

  @override
  String get authNoAccountSignUp => 'Har du inget konto? Skapa konto';

  @override
  String get authHasAccountLogin => 'Har du redan ett konto? Logga in';

  @override
  String get authResetEmailSent => 'Email skickad! Kontrollera din inkorg.';

  @override
  String get authResetEmailFailed => 'Kunde inte skicka email';

  @override
  String get avatarUnknownUser => 'Okand användare';

  @override
  String get commonNow => 'nu';

  @override
  String get commonJustNow => 'just nu';

  @override
  String get imageNoImagesYet => 'Inga bilder ännu';

  @override
  String get imageWillAppearHere => 'Bilder visas här';

  @override
  String get imageNoImagesToDisplay => 'Inga bilder att visa';

  @override
  String get imageRemoveImage => 'Ta bort bild';

  @override
  String get imageSetAsPrimary => 'Ange som primär';

  @override
  String get imageSelectedImages => 'Valda bilder';

  @override
  String get imageSelectImages => 'Välj bilder';

  @override
  String get imageSelectingImages => 'Väljer bilder...';

  @override
  String get imageTapToSelectOne => 'Tryck för att välja en bild';

  @override
  String get messagingCancelReply => 'Avbryt svar';

  @override
  String get messagingImagePreview => 'Bild';

  @override
  String get navigationRecipes => 'recept';

  @override
  String get navigationMenu => 'meny';

  @override
  String get navigationShopping => 'inköp';

  @override
  String get navigationAddNew => 'lägg till';

  @override
  String get recipeRecipe => 'Recept';

  @override
  String get recipeSharedFromApp => 'Delad från annan app';

  @override
  String get shoppingBought => 'köpta';

  @override
  String get shoppingCollaborative => 'Kollaborativ';

  @override
  String get shoppingCopyLink => 'Kopiera länk';

  @override
  String get shoppingCopyList => 'Kopiera lista';

  @override
  String get shoppingRemaining => 'kvar';

  @override
  String get shoppingShareForward => 'Dela vidare';

  @override
  String get shoppingShareShoppingList => 'Dela inköpslista';

  @override
  String get shoppingShoppingList => 'Inköpslista';

  @override
  String get shoppingTotal => 'totalt';

  @override
  String get socialCreateProfile => 'Skapa Profil';

  @override
  String get socialProfileCreatedRestart => 'Profil skapad! Starta om appen.';

  @override
  String get socialReport => 'Rapportera';

  @override
  String get socialReportContent => 'Rapportera innehåll';

  @override
  String get socialReportCopyright => 'Upphovsrättsintrång';

  @override
  String get socialReportInappropriate => 'Olämpligt innehåll';

  @override
  String get socialReportIncorrectInfo => 'Felaktig information';

  @override
  String get socialReportOther => 'Annat';

  @override
  String get socialReportSent => 'Rapport skickad. Tack för din feedback!';

  @override
  String get socialReportShoppingListReason =>
      'Varför vill du rapportera denna inköpslista?';

  @override
  String get socialReportSpam => 'Spam eller reklam';

  @override
  String commonDaysAgo(int days) {
    return '$days dagar sedan';
  }

  @override
  String commonHoursAgo(int hours) {
    return '$hours timmar sedan';
  }

  @override
  String commonMinutesAgo(int minutes) {
    return '$minutes minuter sedan';
  }

  @override
  String imageCountSelected(int count) {
    return '$count valda';
  }

  @override
  String imageFailedToSelect(String error) {
    return 'Kunde inte välja bilder: $error';
  }

  @override
  String imageSelectedCount(int count, int max) {
    return '$count av $max bilder valda';
  }

  @override
  String imageTapToSelectUpTo(int count) {
    return 'Tryck för att välja upp till $count bilder';
  }

  @override
  String messagingRecipePreview(String title) {
    return '$title';
  }

  @override
  String messagingReplyingTo(String name) {
    return 'Svarar till $name';
  }

  @override
  String sharedMenusCount(int count) {
    return 'Menyer ($count)';
  }

  @override
  String sharedRecipesCount(int count) {
    return 'Recept ($count)';
  }

  @override
  String sharedShoppingListsCount(int count) {
    return 'Inköpslistor ($count)';
  }

  @override
  String shoppingCouldNotOpenShareMenu(String error) {
    return 'Kunde inte öppna delningsmenyn: $error';
  }

  @override
  String shoppingCouldNotShareList(String error) {
    return 'Kunde inte dela listan: $error';
  }

  @override
  String shoppingSharedBy(String name) {
    return 'Delad av $name';
  }

  @override
  String shoppingShareListWith(String name) {
    return 'Dela \"$name\" med:';
  }

  @override
  String shoppingSharingComingSoon(String option) {
    return 'Delning via $option kommer snart!';
  }

  @override
  String socialCouldNotSendReport(String error) {
    return 'Kunde inte skicka rapport: $error';
  }

  @override
  String socialLikeCount(int count) {
    return '$count gilla-markeringar';
  }

  @override
  String socialLikesHeader(int count) {
    return 'Gilla-markeringar ($count)';
  }

  @override
  String get commonAdding => 'Lägger till...';

  @override
  String get a11yHidePassword => 'Dölj lösenord';

  @override
  String get a11yShowPassword => 'Visa lösenord';

  @override
  String get a11yShareWithFriends => 'Dela med vänner';

  @override
  String get a11yNoItemsToShare => 'Inga artiklar att dela';

  @override
  String get a11yShareExternally => 'Dela externt';

  @override
  String get a11yAddItem => 'Lägg till vara';

  @override
  String a11yShoppingItemChecked(String itemText) {
    return '$itemText, avbockad, tryck för att bocka av';
  }

  @override
  String a11yShoppingItemUnchecked(String itemText) {
    return '$itemText, tryck för att bocka av';
  }

  @override
  String a11yTagSelected(String tagName) {
    return '$tagName, vald. Dubbeltryck för att ta bort.';
  }

  @override
  String a11yTagUnselected(String tagName) {
    return '$tagName. Dubbeltryck för att välja.';
  }

  @override
  String a11ySharedShoppingList(String listName) {
    return 'Delad inköpslista: $listName';
  }

  @override
  String get a11yDismissSharedRecipe => 'Avvisa delat recept';

  @override
  String get a11yDismissSharedMenu => 'Avvisa delad meny';

  @override
  String get a11yDeclineSharedShoppingList => 'Avvisa delad inköpslista';

  @override
  String get a11yPrimaryImageTap =>
      'Primär bild, tryck för att visa fullstorlek';

  @override
  String get a11ySelectAsPrimary => 'Välj som primär bild';

  @override
  String get a11yAddImage => 'Lägg till bild';

  @override
  String get a11yRemoveImage => 'Ta bort bild';

  @override
  String get a11yViewFullSizeImage => 'Visa fullstorlek av bild';

  @override
  String a11yViewFullSizeImageOf(int current, int total) {
    return 'Visa fullstorlek av bild $current av $total';
  }

  @override
  String a11ySwitchToImageOf(int current, int total) {
    return 'Byt till bild $current av $total';
  }

  @override
  String get a11yShrinkImage => 'Förminska bild';

  @override
  String get a11yEnlargeImage => 'Förstora bild';

  @override
  String get a11yLoadImage => 'Ladda bild';

  @override
  String get a11yMessageSwipeToReply => 'Meddelande, svep för att svara';

  @override
  String get a11yMessageLongPressOptions =>
      'Meddelandeinnehåll, långtryck för alternativ';

  @override
  String get a11yImageMessageTap => 'Bildmeddelande, tryck för fullstorlek';

  @override
  String get a11yReplyToComment => 'Svara på kommentar';

  @override
  String get a11yUnlikeComment => 'Ta bort gilla-markering';

  @override
  String get a11yLikeComment => 'Gilla kommentar';

  @override
  String a11yProfileImage(String displayName) {
    return 'Profilbild för $displayName';
  }

  @override
  String get a11yChangeProfileImage => 'Ändra profilbild';

  @override
  String a11yShoppingList(String name) {
    return 'Inköpslista: $name';
  }

  @override
  String a11yFriend(String name) {
    return 'Vän: $name';
  }

  @override
  String get a11yFriendRequest => 'Vänförfrågan';

  @override
  String a11yFilterTag(String tagName, String status) {
    return 'Filtrera på $tagName, $status';
  }

  @override
  String get a11yActive => 'aktiv';

  @override
  String get a11yInactive => 'inaktiv';

  @override
  String a11yExcludeTag(String tagName, String status) {
    return 'Exkludera $tagName, $status';
  }

  @override
  String get a11yShowImage => 'Visa bild';

  @override
  String a11yShowMore(int count) {
    return 'Visa $count till';
  }

  @override
  String a11yEditItem(String name) {
    return 'Redigera $name';
  }

  @override
  String a11yDeleteItem(String name) {
    return 'Ta bort $name';
  }

  @override
  String a11ySharedRecipe(String title) {
    return 'Delat recept: $title';
  }

  @override
  String a11ySharedMenu(String title) {
    return 'Delad meny: $title';
  }

  @override
  String get a11yRemoveProfileImage => 'Ta bort profilbild';

  @override
  String a11yMenu(String title) {
    return 'Meny: $title';
  }

  @override
  String get filterBreakfast => 'Frukost';

  @override
  String get filterLunch => 'Lunch';

  @override
  String get filterDinner => 'Middag';

  @override
  String get filterSnack => 'Mellanmål';

  @override
  String get filterDessert => 'Efterrätt';

  @override
  String get filterGlutenFree => 'Glutenfri';

  @override
  String get filterDairyFree => 'Mjölkfri';

  @override
  String get filterLactoseFree => 'Laktosfri';

  @override
  String get filterNutFree => 'Nötfri';

  @override
  String get filterEggFree => 'Äggfri';

  @override
  String get filterSoyFree => 'Sojafri';

  @override
  String get filterVegetarian => 'Vegetarisk';

  @override
  String get filterVegan => 'Vegansk';

  @override
  String get filterPescetarian => 'Pescetarian';

  @override
  String get filterHalal => 'Halalanpassad';

  @override
  String get filterKidFriendly => 'Barnvänlig';

  @override
  String get unitPieces => 'st';

  @override
  String get unitLiter => 'liter';

  @override
  String get unitTablespoon => 'msk';

  @override
  String get unitPinch => 'krm';

  @override
  String get unitPackage => 'förpackning';

  @override
  String get unitPackageShort => 'förp';

  @override
  String get unitTeaspoon => 'tsk';

  @override
  String get unitBag => 'påse';

  @override
  String get unitCan => 'burk';

  @override
  String get unitBottle => 'flaska';

  @override
  String get unitPiece => 'bit';

  @override
  String get unitClove => 'klyfta';

  @override
  String get categoryFruitVeg => 'Frukt & Grönt';

  @override
  String get categoryDairy => 'Mejeri';

  @override
  String get categoryMeatFish => 'Kött & Fisk';

  @override
  String get categoryBread => 'Bröd';

  @override
  String get categoryPantry => 'Skafferi';

  @override
  String get categoryFrozen => 'Fryst';

  @override
  String get categoryBeverage => 'Dryck';

  @override
  String get categorySnacks => 'Snacks & Godis';

  @override
  String get categoryHygiene => 'Städ & Hygien';

  @override
  String get categoryOther => 'Övrigt';

  @override
  String get privacyEmailSubject => 'Integritetsfråga';

  @override
  String get unshareRecipeTitle => 'Sluta dela recept?';

  @override
  String unshareRecipeConfirm(String title) {
    return 'Receptet \"$title\" tas bort från alla grupper det delats med.';
  }

  @override
  String get unshareMenuTitle => 'Sluta dela meny?';

  @override
  String unshareMenuConfirm(String title) {
    return 'Menyn \"$title\" tas bort från alla grupper den delats med.';
  }

  @override
  String get unshareShoppingListTitle => 'Sluta dela inköpslista?';

  @override
  String unshareShoppingListConfirm(String name) {
    return 'Inköpslistan \"$name\" tas bort från alla grupper den delats med.';
  }

  @override
  String get unshareButton => 'Sluta dela';

  @override
  String unshareSuccess(String title) {
    return '\"$title\" delas inte längre';
  }

  @override
  String get unshareFailed => 'Kunde inte sluta dela. Försök igen.';

  @override
  String get menuCommentsTitle => 'Kommentarer';

  @override
  String menuCommentsCount(int count) {
    return '$count kommentarer';
  }

  @override
  String get menuNoCommentsYet => 'Inga kommentarer än';

  @override
  String get menuBeFirstToComment => 'Var först med att kommentera denna meny!';

  @override
  String get menuLoadingComments => 'Laddar kommentarer...';

  @override
  String get menuWriteComment => 'Skriv en kommentar om menyn...';

  @override
  String get menuCommentPostedSuccess => 'Kommentar postad!';

  @override
  String get menuCommentPostFailed => 'Kunde inte posta kommentaren';

  @override
  String get menuCommentDeleteFailed => 'Kunde inte ta bort kommentaren';

  @override
  String get menuMustBeLoggedInToComment =>
      'Du måste vara inloggad för att kommentera';

  @override
  String get menuRatingTitle => 'Betyg';

  @override
  String menuAverageRating(String rating) {
    return 'Medelbetyg: $rating';
  }

  @override
  String menuRatingCount(int count) {
    return '$count betyg';
  }

  @override
  String get menuNoRatingsYet => 'Inga betyg än';

  @override
  String get menuTapToRate => 'Tryck för att betygsätta';

  @override
  String get menuYourRating => 'Ditt betyg';

  @override
  String get menuRatingSaved => 'Betyg sparat!';

  @override
  String get menuRatingFailed => 'Kunde inte spara betyg';

  @override
  String get menuRemoveRating => 'Ta bort betyg';

  @override
  String get menuMustBeLoggedInToRate =>
      'Du måste vara inloggad för att betygsätta';

  @override
  String get favoritesAdd => 'Lägg till favorit';

  @override
  String get favoritesRemove => 'Ta bort favorit';
}
