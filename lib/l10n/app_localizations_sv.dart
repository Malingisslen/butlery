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
  String get commonCopyLink => 'Kopiera länk';

  @override
  String get commonLinkCopied => 'Länk kopierad';

  @override
  String get commonPaste => 'Klistra in';

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
  String get commentDeletedUndoMessage => 'Kommentar borttagen';

  @override
  String get imageRemovedUndoMessage => 'Foto borttaget';

  @override
  String get slotPickerDialogTitle => 'Välj plats i veckomenyn';

  @override
  String get slotPickerPreviousWeek => 'Föregående vecka';

  @override
  String get slotPickerNextWeek => 'Nästa vecka';

  @override
  String slotPickerWeekLabel(int week) {
    return 'v.$week';
  }

  @override
  String get bulkAddToMenu => 'Lägg till i veckomeny';

  @override
  String bulkAddToMenuSuccess(int count, String slot, String day) {
    return '$count recept tillagda i $slot $day';
  }

  @override
  String bulkAddToMenuOverflowed(int added, int requested) {
    return '$added av $requested lades till — resten ryms inte i veckan';
  }

  @override
  String get bulkAddToMenuOverflowedAction => 'Lägg de resterande nästa vecka';

  @override
  String bulkAddToMenuSuccessNextWeek(int count) {
    return '$count recept lades till nästa vecka';
  }

  @override
  String bulkAddToMenuOverflowedTwoWeeks(int remaining) {
    return 'Resten ryms inte i nästa vecka heller — $remaining recept utan plats';
  }

  @override
  String get bulkExport => 'Exportera valda';

  @override
  String get bulkExportCopyClipboard => 'Kopiera till urklipp';

  @override
  String get bulkExportShareFile => 'Dela som fil';

  @override
  String bulkExportCopied(int count) {
    return '$count recept kopierade till urklipp';
  }

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
  String get validationInvalidUrl => 'Ogiltig URL';

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
  String errorCouldNotCreate(String itemType) {
    return 'Kunde inte skapa $itemType';
  }

  @override
  String errorCouldNotUpdate(String itemType) {
    return 'Kunde inte uppdatera $itemType';
  }

  @override
  String errorCouldNotDelete(String itemType) {
    return 'Kunde inte ta bort $itemType';
  }

  @override
  String errorCouldNotLoad(String itemType) {
    return 'Kunde inte ladda $itemType';
  }

  @override
  String get nounSettings => 'inställningar';

  @override
  String get nounGroupContent => 'gruppinnehåll';

  @override
  String get nounFriends => 'vänner';

  @override
  String get nounFriendList => 'vänlista';

  @override
  String groupInvitationMessage(String groupName) {
    return 'Du har blivit inbjuden till gruppen $groupName!';
  }

  @override
  String uploadTimeIn(String duration) {
    return ' på $duration';
  }

  @override
  String get autoSaveEnabled => 'Autospar aktiverat';

  @override
  String selectionFriendSelectedWithName(String name) {
    return '$name vald';
  }

  @override
  String selectionFriendsSelectedWithNames(int count, String names) {
    return '$count valda: $names';
  }

  @override
  String selectionFriendsSelectedCount(int count) {
    return '$count vänner valda';
  }

  @override
  String sharePartialSuccessSingular(int newCount) {
    return '1 person är redan med. Bjuder in $newCount nya.';
  }

  @override
  String sharePartialSuccessPlural(int existingCount, int newCount) {
    return '$existingCount personer är redan med. Bjuder in $newCount nya.';
  }

  @override
  String get nounShoppingList => 'inköpslista';

  @override
  String get nounShareLink => 'delningslänk';

  @override
  String get validationUrlRequired => 'URL krävs';

  @override
  String get urlSuggestionKnownSite =>
      'Känd receptsida — bra chans att importera!';

  @override
  String get urlSuggestionUnknownSite =>
      'Okänd sida — import kan vara begränsad';

  @override
  String get urlSuggestionContainsRecipeKeyword =>
      'URL:en innehåller receptnyckelord';

  @override
  String get urlSuggestionTooLong =>
      'URL:en är ovanligt lång — kontrollera att den är korrekt';

  @override
  String get urlSuggestionSocialMedia =>
      'Sociala medier — import kräver ibland extra steg';

  @override
  String get urlSuggestionOptimal => 'Perfekt — redo att importera!';

  @override
  String errorWithContext(String action, String error) {
    return 'Fel vid $action: $error';
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
    return 'Bekräftelse krävs — ta bort \"$itemName\"?';
  }

  @override
  String get confirmUnsavedChanges =>
      'Osparade ändringar föreligger. Lämna utan att spara?';

  @override
  String get confirmIrreversibleAction => 'Åtgärden är slutgiltig.';

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
  String get emptyNoItems => 'Inga objekt hittades.';

  @override
  String get emptyNoResults => 'Inga resultat hittades.';

  @override
  String get emptyNoFriends => 'Du har inga vänner än.';

  @override
  String get emptyNoRecipes => 'Receptsamlingen är ännu tom.';

  @override
  String emptyNoRecipesSubtitle(String addButton) {
    return 'Första receptet läggs till via \"$addButton\".';
  }

  @override
  String get emptyNoSearchResultsSubtitle =>
      'Prova att söka på något annat eller rensa sökningen';

  @override
  String get emptyNoFriendsSearchTitle => 'Inga vänner matchade din sökning';

  @override
  String get emptyNoGroupsSearchTitle => 'Inga grupper matchade din sökning';

  @override
  String get emptyNoMenuTitle => 'Ingen meny är ännu uppdukad';

  @override
  String get emptyNoMenuSubtitle => 'Ange önskemål, eller använd knappen nedan';

  @override
  String get emptyNoShoppingListTitle =>
      'Ingen meny finns att avleda en inköpslista från';

  @override
  String get emptyNoShoppingListSubtitle => 'En veckomeny behövs först';

  @override
  String get emptyNoFriendsTitle => 'Ingen är bjuden ännu';

  @override
  String get emptyNoFriendsSubtitle =>
      'Vänner inbjuds för att dela recept och menyer';

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
  String get emptyNoSharedShoppingListsTitle => 'Inga delade inköpslistor';

  @override
  String get emptyNoSharedShoppingListsSubtitle =>
      'När du samarbetar på inköpslistor med vänner eller familj visas de här.';

  @override
  String get emptyNoTagsTitle => 'Inga taggar är ännu ordnade';

  @override
  String get emptyNoTagsSubtitle =>
      'Personliga taggar används för att ordna receptsamlingen.';

  @override
  String get emptyNoGroupsTitle => 'Matlagning tillsammans, enklare';

  @override
  String get emptyNoGroupsSubtitle =>
      'Skapa en grupp för att dela veckomenyer och inköpslistor med vänner eller familj — alla ser samma plan och kan checka av varor under tiden.';

  @override
  String get emptyNoConversationsTitle => 'Inga konversationer ännu';

  @override
  String get emptyNoConversationsSubtitle =>
      'Ett samtal med en vän kan inledas härifrån.';

  @override
  String get emptyGenericTitle => 'Inget innehåll finns att visa';

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
  String get socialGroupName => 'Gruppnamn';

  @override
  String get socialCreateGroup => 'Skapa grupp';

  @override
  String get socialEditGroup => 'Redigera grupp';

  @override
  String get socialAddFriend => 'Lägg till vän';

  @override
  String get socialRemoveFriend => 'Ta bort vän';

  @override
  String get socialSendFriendRequest => 'Skicka vänförfrågan';

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
  String get statusConnecting => 'Ansluter...';

  @override
  String get statusSyncing => 'Synkroniserar...';

  @override
  String get statusSaving => 'Sparar...';

  @override
  String get statusCreating => 'Skapar...';

  @override
  String get statusUpdating => 'Uppdaterar...';

  @override
  String get accessibilityBackButton => 'Tillbaka';

  @override
  String get unitMinutesShort => 'min';

  @override
  String get unitHoursShort => 'h';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept',
      one: '1 recept',
      zero: 'Inga recept',
    );
    return '$_temp0';
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
  String get portionDecrease => 'Minska portioner';

  @override
  String get portionIncrease => 'Öka portioner';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept',
      one: '1 recept',
      zero: 'Inga recept',
    );
    return '$_temp0';
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
  String get searchRecentSearches => 'Senaste sökningar';

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
  String recipeDuplicateTitle(String title) {
    return '$title (Kopia)';
  }

  @override
  String get recipePrint => 'Skriv ut';

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
  String get commonSelectAll => 'Välj alla';

  @override
  String get commonDeselectAll => 'Avmarkera alla';

  @override
  String get commonInvertSelection => 'Invertera';

  @override
  String commonAddWithLabel(String label) {
    return 'Lägg till $label';
  }

  @override
  String get commonClearAll => 'Rensa alla';

  @override
  String get commonClear => 'Rensa';

  @override
  String get commonImage => 'Bild';

  @override
  String get commonSettings => 'Inställningar';

  @override
  String get settingsSubtitle => 'Allergener, taggar, aviseringar och mer';

  @override
  String get settingsSectionFood => 'Matpreferenser';

  @override
  String get settingsSectionNotifications => 'Aviseringar';

  @override
  String get settingsSectionAccount => 'Konto & säkerhet';

  @override
  String get settingsSectionAbout => 'Om';

  @override
  String get settingsSectionLanguage => 'Språk';

  @override
  String get settingsLanguageTitle => 'Språk';

  @override
  String get settingsLanguageDialogTitle => 'Välj språk';

  @override
  String get commonLogout => 'Logga ut';

  @override
  String get commonLogoutNow => 'Logga ut nu';

  @override
  String get commonTakePhoto => 'Ta foto';

  @override
  String get commonSelectFromGallery => 'Välj från galleri';

  @override
  String get commonSelectFriends => 'Välj vänner';

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
  String personalTagDeleteTagMessageWithCount(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Den tas bort från $count recept.',
      one: 'Den tas bort från 1 recept.',
      zero: 'Inga recept påverkas.',
    );
    return 'Är du säker på att du vill ta bort \"$name\"? $_temp0';
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
  String dietaryStatusUnknownLabel(String name) {
    return '$name: okänd';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vänner',
      one: '1 vän',
      zero: 'Inga vänner',
    );
    return '$_temp0';
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
  String get shoppingLists => 'Inköpslistor';

  @override
  String get shoppingNewList => 'Ny lista';

  @override
  String get shoppingAddFromMenu => 'Lägg till från meny';

  @override
  String get shoppingNoItemsFromMenu => 'Inga artiklar valda från menyn';

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
  String profileCouldNotOpenDataExport(String error) {
    return 'Kunde inte öppna dataexport: $error';
  }

  @override
  String get shareRecipeTitle => 'Dela recept';

  @override
  String get shareMenuTitle => 'Dela meny';

  @override
  String get shareShoppingListTitle => '🛒 INKÖPSLISTA';

  @override
  String get shareCreateAndShare => 'Skapa & Dela';

  @override
  String get shareRecipeWithFriends => 'Dela recept med vänner';

  @override
  String get shareMenuWithFriends => 'Dela veckomeny med vänner';

  @override
  String get shareShoppingList => 'Dela inköpslista';

  @override
  String get shareRealtime => 'realtidsdelning';

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
  String get menuCommentHint => 'Beskrivning eller noteringar om menyn';

  @override
  String get menuShareWithFriends => 'Dela med vänner';

  @override
  String get menuSelectFriendsToShare => 'Välj vänner att dela med';

  @override
  String get menuNoFriendsAvailable => 'Inga vänner tillgängliga';

  @override
  String get menuShareMessageLabel => 'Delningsmeddelande';

  @override
  String get menuShareMessageHint => 'Meddelande som skickas med menyn';

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
  String get invitationIndividuals => 'Individer';

  @override
  String get invitationSendInvitations => 'Skicka inbjudningar';

  @override
  String get invitationAffectedTargets => 'Berörda målgrupper:';

  @override
  String get invitationView => 'Visa';

  @override
  String get invitationSendInvitation => 'Skicka inbjudan';

  @override
  String get invitationInvite => 'Inbjud';

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
  String get groupCouldNotFetchRecipe => 'Kunde inte hämta recept från servern';

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
  String get groupDeleteWarning => 'Alla medlemmar kommer att lämna gruppen.';

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
  String groupErrorOpeningRecipe(String error) {
    return 'Fel vid öppning av recept: $error';
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
  String groupRecipeImportedSuccess(String title) {
    return 'Receptet \"$title\" har importerats';
  }

  @override
  String groupRecipeImportFailed(String error) {
    return 'Kunde inte importera recept: $error';
  }

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
  String get profileDataBackup => 'Data & säkerhetskopior';

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
  String get consentRenewalTitle => 'Vi har uppdaterat våra användarvillkor';

  @override
  String get consentRenewalDescription =>
      'Vi har gjort ändringar i hur vi behandlar dina uppgifter. Granska och bekräfta dina samtycken för att fortsätta.';

  @override
  String get consentRenewalReview => 'Granska samtycken';

  @override
  String get consentRenewalLater => 'Senare';

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
  String get dataExportIncludesAuditLogs =>
      'Säkerhets- och åtkomsthistorik (GDPR Artikel 15)';

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
  String importParseQualityWarning(int quality) {
    return 'Receptet tolkades med $quality% konfidens. Granska fälten nedan.';
  }

  @override
  String importFieldsNeedReview(int count) {
    return '$count fält kan behöva justeras';
  }

  @override
  String get importFieldsNeedReviewPrefix => 'Kontrollera';

  @override
  String menuCardMoreRecipes(int count) {
    return '+ $count fler recept';
  }

  @override
  String get menuCardNoRecipes => 'Inga recept i menyn';

  @override
  String menuCardRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept',
      one: '1 recept',
      zero: 'Inga recept',
    );
    return '$_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
      zero: 'Inga medlemmar',
    );
    return '$_temp0';
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
  String get dataExportShareSubject => 'Butlery dataexport';

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
  String get importWaitForCompletion => 'Vänta tills importen är klar...';

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
  String get importViaUrl => 'Importera via URL';

  @override
  String get indicatorOfflineMode => 'Offline-läge - Ändringar sparas lokalt';

  @override
  String get indicatorBackOnline => 'Ansluten igen';

  @override
  String get householdLabel => 'Hushåll';

  @override
  String get householdToggle => 'Markera som hushåll';

  @override
  String get householdToggleDescription =>
      'Hushållets allergier sammanställs för menyplanering';

  @override
  String get householdAlreadyExists =>
      'Du har redan ett hushåll. Det nuvarande tas bort först.';

  @override
  String get householdAllergenInfo =>
      'Menyplanering filtrerar baserat på alla medlemmars allergier';

  @override
  String get menuUseHouseholdAllergens => 'Filtrera efter hushållets allergier';

  @override
  String get menuVoteTitle => 'Rösta om recept';

  @override
  String get menuVoteSuggestAlternative => 'Föreslå alternativ';

  @override
  String get menuVoteCastVote => 'Rösta';

  @override
  String get menuVoteResolved => 'Omröstning avgjord';

  @override
  String get menuVoteDeadline => 'Sista dag att rösta';

  @override
  String menuVoteWinner(String recipeName) {
    return 'Vinnare: $recipeName';
  }

  @override
  String menuVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count röster',
      one: '1 röst',
      zero: 'Inga röster',
    );
    return '$_temp0';
  }

  @override
  String get menuVoteExpired => 'Omröstningen har gått ut';

  @override
  String get menuVoteNoAlternatives => 'Inga förslag ännu';

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
  String get chatCannotMessageNonFriend =>
      'Du kan inte skicka meddelanden till denna person';

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
  String get importClipboardUrlDetected => 'Receptlänk hittad i urklipp';

  @override
  String get importClipboardUseUrl => 'Använd';

  @override
  String get importPasteLinkOrText => 'Klistra in länk eller text här...';

  @override
  String get importPasteText => 'Klistra in text';

  @override
  String get importAddManually => 'Lägg till manuellt';

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
  String get profileBio => 'Beskrivning';

  @override
  String get profileBioHint => 'Beskriv dig som matlagare (max 160 tecken)';

  @override
  String get profileNoBio => 'Ingen beskrivning ännu';

  @override
  String get profileChangeAvatar => 'Ändra avatar';

  @override
  String get profileCouldNotSave => 'Kunde inte spara profil';

  @override
  String get profileCouldNotUploadAvatar => 'Kunde inte ladda upp avatar';

  @override
  String get profileCookingIdentity => 'Matlagningsidentitet';

  @override
  String get profileCookingSkill => 'Kunskapsnivå';

  @override
  String get profileCookingSkillAdvanced => 'Avancerad';

  @override
  String get profileCookingSkillBeginner => 'Nybörjare';

  @override
  String get profileCookingSkillIntermediate => 'Erfaren';

  @override
  String get profileCuisineAffinities => 'Favoritkök';

  @override
  String get profileCuisineAffinitiesHint => 'Välj upp till 5 kök';

  @override
  String get profileCuisineAffinitiesMax => 'Max 5 kök valda';

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
  String get celebrationFirstRecipeTitle => 'Grattis!';

  @override
  String celebrationFirstRecipeMessage(String recipeTitle) {
    return 'Du har sparat ditt första recept: $recipeTitle. Välkommen till Butlery!';
  }

  @override
  String get celebrationFirstRecipeContinue => 'Fortsätt';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
      zero: 'Inga medlemmar',
    );
    return '$_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kommentarer',
      one: '1 kommentar',
      zero: 'Inga kommentarer',
    );
    return '$_temp0';
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
  String get socialFeed => 'Flöde';

  @override
  String get feedEmpty => 'Inget att visa ännu';

  @override
  String get feedEmptyDescription =>
      'När dina vänner lagar mat eller delar recept dyker det upp här.';

  @override
  String get feedEmptyNoFriendsTitle => 'Lägg till vänner för att komma igång';

  @override
  String get feedEmptyNoFriendsSubtitle =>
      'När du följer vänner ser du deras matlagning och delade recept här.';

  @override
  String get feedEmptyNoFriendsCta => 'Hitta vänner';

  @override
  String get feedInviteFriends => 'Bjud in vänner';

  @override
  String get feedFilterAll => 'Allt';

  @override
  String get feedFilterCooked => 'Lagat';

  @override
  String get feedFilterShared => 'Delat';

  @override
  String get feedActionCooked => 'lagade';

  @override
  String get feedActionShared => 'delade';

  @override
  String get feedTimeJustNow => 'Nyss';

  @override
  String get feedTimeToday => 'Idag';

  @override
  String get feedTimeYesterday => 'Igår';

  @override
  String feedTimeMinutesAgo(int count) {
    return '$count min sedan';
  }

  @override
  String feedTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count timmar sedan',
      one: '1 timme sedan',
    );
    return '$_temp0';
  }

  @override
  String feedTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagar sedan',
      one: '1 dag sedan',
    );
    return '$_temp0';
  }

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
  String get sharedEmptyStateExplanation =>
      'När du eller dina vänner delar recept och menyer visas de här. Prova att dela ett recept!';

  @override
  String get sharedShareFirstRecipe => 'Dela ett recept';

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
  String get tagSuggested => 'Föreslagna';

  @override
  String get tagAll => 'Alla taggar';

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
  String get sortLastCooked => 'Senast lagad';

  @override
  String get sortCookCount => 'Antal tillagningar';

  @override
  String get sortNewest => 'Nyaste';

  @override
  String get shuffleRecipes => 'Slumpa';

  @override
  String get importPreviewTitle => 'Förhandsgranska import';

  @override
  String get importSelectAll => 'Markera alla';

  @override
  String get importDeselectAll => 'Avmarkera alla';

  @override
  String importConfirmButton(int count) {
    return 'Importera ($count)';
  }

  @override
  String importPreviewSubtitle(int ingredients, int steps) {
    return '$ingredients ingredienser · $steps steg';
  }

  @override
  String get stateAddRecipes => 'Lägg till recept';

  @override
  String get stateCreateWeeklyMenu => 'Skapa veckomeny';

  @override
  String get stateGenerateMenu => 'Generera meny';

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
  String get socialInviteFriends => 'Bjud in vänner';

  @override
  String get socialInviteSubject => 'Gå med i Butlery!';

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
  String get authTagline => 'Dina recept. Resten löser sig.';

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
  String groupRemoveMultipleConfirm(int count, String group) {
    return 'Ta bort $count medlemmar från $group?';
  }

  @override
  String groupMembersRemoved(int count) {
    return '$count medlemmar har tagits bort';
  }

  @override
  String groupMembersPartiallyRemoved(int removed, String failedNames) {
    return '$removed medlemmar borttagna — kunde inte ta bort: $failedNames';
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
  String get sharedReplyToSender => 'Svara';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portioner',
      one: '1 portion',
    );
    return '$_temp0';
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
  String get shoppingMoveToCategory => 'Flytta till kategori';

  @override
  String get shoppingSortCategories => 'Sortera kategorier';

  @override
  String get shoppingCategoryOrderTitle => 'Kategoriordning';

  @override
  String get shoppingResetOrder => 'Återställ';

  @override
  String get shoppingSaveOrder => 'Spara ordning';

  @override
  String get shoppingOtherCategories => 'Övriga kategorier';

  @override
  String get shoppingDragToMove => 'Håll för att flytta';

  @override
  String get shoppingCategorySaved => 'Kategoriordning sparad';

  @override
  String shoppingItemMoved(String category) {
    return 'Flyttade till $category';
  }

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
  String shoppingItemAdded(String itemName) {
    return 'La till \"$itemName\"';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar tillagda',
      one: '1 medlem tillagd',
    );
    return '$_temp0';
  }

  @override
  String shoppingMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
      zero: 'Inga medlemmar',
    );
    return '$_temp0';
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
  String get authEmailHint => 'namn@exempel.se';

  @override
  String get authTermsOfService => 'Villkor';

  @override
  String get authResetEmailSent => 'Email skickad! Kontrollera din inkorg.';

  @override
  String get authResetEmailFailed => 'Kunde inte skicka email';

  @override
  String get avatarUnknownUser => 'Okänd användare';

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
  String get a11yNavigationLandmark => 'Huvudnavigering';

  @override
  String a11yAppBarHeaderHint(String title) {
    return 'Skärmrubrik: $title';
  }

  @override
  String get a11yShareWithFriends => 'Dela med vänner';

  @override
  String get a11yNoItemsToShare => 'Inga artiklar att dela';

  @override
  String get a11yShareExternally => 'Dela externt';

  @override
  String get a11yAddItem => 'Lägg till vara';

  @override
  String a11yTagStatusInfo(String status) {
    return 'Mer information om $status';
  }

  @override
  String a11yRateStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Sätt $count stjärnor',
      one: 'Sätt 1 stjärna',
    );
    return '$_temp0';
  }

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
  String get a11yStatusOnline => 'Online';

  @override
  String get a11yStatusOffline => 'Offline';

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
  String get a11yAllergenStatusRow => 'Allergenstatus';

  @override
  String get a11yDietaryStatusRow => 'Koststatus';

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
  String get filterFishFree => 'Fiskfri';

  @override
  String get filterSesameFree => 'Sesamfri';

  @override
  String get filterCeleryFree => 'Sellerifri';

  @override
  String get filterMustardFree => 'Senapfri';

  @override
  String get filterShellfishFree => 'Skaldjursfri';

  @override
  String get filterLupinFree => 'Lupinfri';

  @override
  String get filterSulfiteFree => 'Sulfitfri';

  @override
  String get filterPeanutFree => 'Jordnötsfri';

  @override
  String get filterTreeNutFree => 'Trädnötsfri';

  @override
  String get filterAlcoholFree => 'Alkoholfri';

  @override
  String get filterMoreAllergens => 'Fler allergener';

  @override
  String get filterFewerAllergens => 'Färre allergener';

  @override
  String get onboardingAllergenCelery => 'Selleri';

  @override
  String get onboardingAllergenMustard => 'Senap';

  @override
  String get onboardingAllergenLupin => 'Lupin';

  @override
  String get onboardingAllergenSulfite => 'Sulfiter';

  @override
  String get onboardingAllergenLactose => 'Laktos';

  @override
  String get onboardingAllergenPeanut => 'Jordnötter';

  @override
  String get onboardingAllergenTreeNut => 'Trädnötter';

  @override
  String get onboardingAllergenCrustacean => 'Kräftdjur';

  @override
  String get onboardingAllergenMollusc => 'Blötdjur';

  @override
  String get onboardingShowAllAllergens => 'Visa alla allergener';

  @override
  String get onboardingShowFewerAllergens => 'Visa färre';

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
  String get categorySpices => 'Kryddor';

  @override
  String get categoryCanned => 'Konserver';

  @override
  String get categoryDryGoods => 'Torrvaror';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kommentarer',
      one: '1 kommentar',
      zero: 'Inga kommentarer',
    );
    return '$_temp0';
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
  String get menuTapToRate => 'Tryck för att betygsätta';

  @override
  String get menuYourRating => 'Ditt betyg';

  @override
  String get menuRatingSaved => 'Betyg sparat!';

  @override
  String get menuRatingFailed => 'Kunde inte spara betyg';

  @override
  String get menuMustBeLoggedInToRate =>
      'Du måste vara inloggad för att betygsätta';

  @override
  String get favoritesAdd => 'Lägg till favorit';

  @override
  String get favoritesRemove => 'Ta bort favorit';

  @override
  String get shoppingConvertToCollaborative => 'Gör samarbetslista';

  @override
  String get shoppingConvertToPersonal => 'Gör personlig lista';

  @override
  String get shoppingConvertToCollaborativeTitle => 'Gör till samarbetslista';

  @override
  String get shoppingConvertToCollaborativeDescription =>
      'Välj vänner att dela listan med. De kan lägga till och bocka av varor i realtid.';

  @override
  String get shoppingConvertToPersonalTitle => 'Gör till personlig lista';

  @override
  String get shoppingConvertToPersonalWarning =>
      'Alla samarbetspartners förlorar åtkomst till listan. Varor behålls.';

  @override
  String get shoppingConvertedToCollaborative =>
      'Listan omvandlad till samarbetslista';

  @override
  String get shoppingConvertedToPersonal => 'Listan omvandlad till personlig';

  @override
  String get shoppingConvertError => 'Kunde inte omvandla listan';

  @override
  String get shoppingDescriptionLabel => 'Beskrivning (valfritt)';

  @override
  String get menuTemplateSaveAsTemplate => 'Spara som mall';

  @override
  String get menuTemplateSaveAsTemplateDescription =>
      'Sparar menyns kategoristruktur som en återanvändbar mall';

  @override
  String get menuTemplateName => 'Mallnamn';

  @override
  String get menuTemplateNameHint => 'T.ex. Vardagsmeny familj';

  @override
  String get menuTemplateNameRequired => 'Mallnamn krävs';

  @override
  String get menuTemplateDescription => 'Beskrivning (valfritt)';

  @override
  String get menuTemplateDescriptionHint =>
      'T.ex. Perfekt för vardagar med barn';

  @override
  String menuTemplateSavedSuccess(String name) {
    return 'Mall \"$name\" sparad!';
  }

  @override
  String get menuTemplateNoTemplates => 'Inga mallar';

  @override
  String get menuTemplateNoTemplatesDescription =>
      'Du har inga sparade menymmallar. Spara en meny som mall för att återanvända kategoristrukturen.';

  @override
  String menuTemplateRecipes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept',
      one: '1 recept',
      zero: 'Inga recept',
    );
    return '$_temp0';
  }

  @override
  String menuTemplateUsedCount(int count) {
    return 'Använd $count gånger';
  }

  @override
  String get menuTemplateUseTemplate => 'Använd mall';

  @override
  String get menuTemplateDeleteTitle => 'Ta bort mall';

  @override
  String get menuTemplateDeleteConfirmation =>
      'Är du säker på att du vill ta bort denna mall?';

  @override
  String get menuTemplateDeletedSuccess => 'Mall borttagen';

  @override
  String get menuTemplateDeleteFailed => 'Kunde inte ta bort mall';

  @override
  String get menuTemplateSavedMenus => 'Sparade menyer';

  @override
  String get menuTemplateTemplates => 'Mallar';

  @override
  String get personalTagApplyRulesToAll => 'Tillämpa regler på alla recept';

  @override
  String get messagingPinned => 'FÄSTA';

  @override
  String get messagingUnpin => 'Ta bort fäst';

  @override
  String get messagingPin => 'Fäst';

  @override
  String get messagingArchive => 'Arkivera';

  @override
  String get messagingUnarchive => 'Avarkivera';

  @override
  String messagingArchivedCount(int count) {
    return 'Arkiverade ($count)';
  }

  @override
  String get allergenRetagAllRecipesTitle => 'Omtagga alla recept';

  @override
  String get allergenAnalyzeAllRecipes =>
      'Analysera alla recept med uppdaterade inställningar';

  @override
  String get allergenUpdateAllRecipes => 'Uppdatera alla recept';

  @override
  String get notificationSaveError => 'Kunde inte spara inställningar';

  @override
  String get notificationTitle => 'Aviseringar';

  @override
  String get notificationEnableTitle => 'Aktivera aviseringar';

  @override
  String get notificationEnableSubtitle =>
      'Aktivera eller inaktivera alla aviseringar';

  @override
  String get notificationCategoriesTitle => 'Aviseringskategorier';

  @override
  String get notificationQuietHoursTitle => 'Tysta timmar';

  @override
  String get notificationQuietHoursEnable => 'Aktivera tysta timmar';

  @override
  String get notificationQuietHoursSubtitle =>
      'Inga aviseringar under vald tidsperiod';

  @override
  String get commonFrom => 'Från';

  @override
  String get commonTo => 'Till';

  @override
  String get notificationSound => 'Ljud';

  @override
  String get notificationVibration => 'Vibration';

  @override
  String get notificationCategoryFriends => 'Vänner';

  @override
  String get notificationCategoryRecipes => 'Recept';

  @override
  String get notificationCategoryCollaboration => 'Samarbete';

  @override
  String get notificationCategoryShopping => 'Inköp';

  @override
  String get notificationCategorySocial => 'Social aktivitet';

  @override
  String get notificationCategorySystem => 'System';

  @override
  String get notificationCategoryMessaging => 'Meddelanden';

  @override
  String get notificationDigestFrequencyTitle => 'Sammanfattningsfrekvens';

  @override
  String get notificationDigestFrequencySubtitle =>
      'Hur ofta vill du få en sammanfattning av aktivitet';

  @override
  String get notificationDigestFrequencyNever => 'Aldrig';

  @override
  String get notificationDigestFrequencyWeekly => 'Veckovis';

  @override
  String get notificationDigestFrequencyDaily => 'Dagligen';

  @override
  String get collaborationNoFriends => 'Du har inga vänner att samarbeta med';

  @override
  String get collaborationEnableTitle => 'Aktivera samarbete';

  @override
  String get collaborationEnabled => 'Samarbete aktiverat';

  @override
  String get collaborationCouldNotEnable => 'Kunde inte aktivera samarbete';

  @override
  String get collaborationDeactivateTitle => 'Avaktivera samarbete?';

  @override
  String get collaborationDeactivateMessage =>
      'Alla samarbetspartners förlorar åtkomst till receptet.';

  @override
  String get commonDeactivate => 'Avaktivera';

  @override
  String get collaborationDeactivated => 'Samarbete avaktiverat';

  @override
  String get collaborationCouldNotDeactivate =>
      'Kunde inte avaktivera samarbete';

  @override
  String get ratingRemoveTitle => 'Ta bort betyg?';

  @override
  String get ratingRemoveMessage =>
      'Vill du ta bort ditt betyg för detta recept?';

  @override
  String get ratingRemoved => 'Betyg borttaget';

  @override
  String get ratingRemoveError => 'Kunde inte ta bort betyg';

  @override
  String get ratingError => 'Kunde inte sätta betyg';

  @override
  String ratingStarLabel(int count) {
    return 'Ge $count stjärnor';
  }

  @override
  String get messagingSending => 'Skickar';

  @override
  String get messagingSent => 'Skickat';

  @override
  String get messagingDelivered => 'Levererat';

  @override
  String get messagingRead => 'Läst';

  @override
  String get messagingFailed => 'Misslyckades';

  @override
  String get a11ySelected => 'vald';

  @override
  String get a11yNotSelected => 'ej vald';

  @override
  String get blockedUsersUnblockTitle => 'Avblockera användare?';

  @override
  String blockedUsersUnblockMessage(String name) {
    return 'Vill du avblockera $name? Användaren kommer kunna se ditt innehåll igen.';
  }

  @override
  String get blockedUsersUnblock => 'Avblockera';

  @override
  String get blockedUsersTitle => 'Blockerade användare';

  @override
  String get blockedUsersEmpty => 'Inga blockerade användare';

  @override
  String get retagFetchingRecipes => 'Hämtar recept...';

  @override
  String get retagRetaggingRecipes => 'Omtaggar recept';

  @override
  String retagRetaggingProgress(int current, int total) {
    return 'Omtaggar $current av $total recept...';
  }

  @override
  String retagRecipesRetagged(int count) {
    return '$count recept omtaggade';
  }

  @override
  String get profileNotifications => 'Aviseringar';

  @override
  String get profileNotificationsSubtitle => 'Kategorier och tysta timmar';

  @override
  String get filterFavorites => 'Favoriter';

  @override
  String get filterUnder30Min => 'Under 30 min';

  @override
  String get filterVegetarianQuick => 'Vegetariskt';

  @override
  String get filterAll => 'Alla';

  @override
  String instructionLabel(int number) {
    return 'Instruktion $number';
  }

  @override
  String get onboardingSkip => 'Hoppa over';

  @override
  String get onboardingBack => 'Tillbaka';

  @override
  String get onboardingNext => 'Nasta';

  @override
  String get onboardingComplete => 'Slutfor';

  @override
  String get onboardingAgeGateTitle => 'Hur gammal ar du?';

  @override
  String get onboardingAgeGateSubtitle =>
      'Vi behover veta ditt fodelsear for att folja svenska regler for sociala appar (GDPR Art 8).';

  @override
  String get onboardingAgeGateBirthYearLabel => 'Fodelsear';

  @override
  String get onboardingAgeGatePrivacyNote =>
      'Vi lagrar bara aret, inte hela datumet.';

  @override
  String get onboardingAgeGateContinue => 'Fortsatt';

  @override
  String get onboardingAgeGateTooYoungTitle => 'Butlery ar for 15 ar och uppat';

  @override
  String get onboardingAgeGateTooYoungBody =>
      'Enligt svensk dataskyddslagstiftning (GDPR Art 8) kravs foraldrasamtycke for att anvanda sociala funktioner under 15 ar. Kom garna tillbaka nar du fyllt 15.';

  @override
  String get onboardingAgeGateSignOut => 'Logga ut';

  @override
  String get onboardingWelcomeTitle => 'Valkommen till Butlery!';

  @override
  String get onboardingWelcomeDescription =>
      'Lat oss stalla in dina preferenser sa att du far den basta upplevelsen fran borjan.';

  @override
  String get onboardingWelcomeNote =>
      'Du kan alltid andra dessa i installningarna senare.';

  @override
  String get onboardingAllergenTitle => 'Allergier & intoleranser';

  @override
  String get onboardingAllergenDescription =>
      'Valj de allergener du vill spara och filtrera recept efter.';

  @override
  String get onboardingAllergenGluten => 'Gluten';

  @override
  String get onboardingAllergenMilk => 'Mjolk';

  @override
  String get onboardingAllergenNuts => 'Notter';

  @override
  String get onboardingAllergenEgg => 'Agg';

  @override
  String get onboardingAllergenSoy => 'Soja';

  @override
  String get onboardingAllergenFish => 'Fisk';

  @override
  String get onboardingAllergenShellfish => 'Skaldjur';

  @override
  String get onboardingAllergenSesame => 'Sesam';

  @override
  String get onboardingDietaryTitle => 'Kostreferenser';

  @override
  String get onboardingDietaryDescription =>
      'Har du nagra kostreferenser? Vi kan filtrera recept at dig.';

  @override
  String get onboardingDietaryVegetarian => 'Vegetarian';

  @override
  String get onboardingDietaryVegan => 'Vegan';

  @override
  String get onboardingDietaryPescetarian => 'Pescetarian';

  @override
  String get onboardingDietaryVegetarianDesc =>
      'Inga kott- eller fiskprodukter';

  @override
  String get onboardingDietaryVeganDesc => 'Inga animaliska produkter';

  @override
  String get onboardingDietaryPescetarianDesc => 'Fisk men inget kott';

  @override
  String get onboardingDietaryGlutenFree => 'Glutenfri';

  @override
  String get onboardingDietaryLactoseFree => 'Laktosfri';

  @override
  String get onboardingDietaryHalal => 'Halalanpassad';

  @override
  String get onboardingDietaryKosher => 'Kosheranpassad';

  @override
  String get onboardingDietaryGlutenFreeDesc =>
      'Inga gluteninnehållande ingredienser';

  @override
  String get onboardingDietaryLactoseFreeDesc =>
      'Inga mejeriprodukter med laktos';

  @override
  String get onboardingDietaryHalalDesc => 'Följer halalregler för mat';

  @override
  String get onboardingDietaryKosherDesc => 'Följer kosherregler för mat';

  @override
  String get onboardingSkippedBanner =>
      'Du hoppade över introduktionen. Vill du ställa in allergener och kostpreferenser?';

  @override
  String get onboardingSkippedBannerAction => 'Öppna inställningar';

  @override
  String get onboardingImportTitle => 'Importera ditt forsta recept';

  @override
  String get onboardingImportDescription =>
      'Kom igang snabbt genom att importera ett recept fran webben eller ett foto.';

  @override
  String get onboardingImportUrlTitle => 'Fran en webbadress';

  @override
  String get onboardingImportUrlDescription =>
      'Klistra in en lank till ett recept';

  @override
  String get onboardingImportPhotoTitle => 'Importera fran foto';

  @override
  String get onboardingImportPhotoDescription =>
      'Ta ett foto eller valj fran galleriet';

  @override
  String get onboardingImportSkipNote =>
      'Du kan hoppa over detta steg och importera senare.';

  @override
  String get onboardingResumeTitle => 'Avsluta din profil';

  @override
  String get onboardingResumeBody => '30 sekunder kvar';

  @override
  String get onboardingResumeCta => 'Fortsatt';

  @override
  String get cookingModePortions => 'Portioner';

  @override
  String get feedbackSendLabel => 'Skicka feedback';

  @override
  String get feedbackCategoryLabel => 'Kategori';

  @override
  String get feedbackCategoryBug => 'Bugg';

  @override
  String get feedbackCategoryFeatureRequest => 'Önskemål';

  @override
  String get feedbackCategoryGeneral => 'Övrigt';

  @override
  String get feedbackDescriptionLabel => 'Beskrivning';

  @override
  String get feedbackDescriptionHint => 'Beskriv vad du upplevde...';

  @override
  String get feedbackEmailLabel => 'E-post (valfritt)';

  @override
  String get feedbackScreenshotLabel => 'Skarmavbild';

  @override
  String get feedbackRemoveScreenshot => 'Ta bort skarmavbild';

  @override
  String get feedbackSendButton => 'Skicka';

  @override
  String get substitutionEmptyState => 'Inga ersattningar hittades';

  @override
  String get pollCreateTitle => 'Skapa omröstning';

  @override
  String get pollQuestionLabel => 'Fråga';

  @override
  String get pollQuestionHint => 'Vad vill du fråga?';

  @override
  String pollOptionLabel(int number) {
    return 'Alternativ $number';
  }

  @override
  String get pollAddOption => 'Lägg till alternativ';

  @override
  String get pollAllowMultiple => 'Tillåt flera val';

  @override
  String get pollCancel => 'Avbryt';

  @override
  String get pollCreate => 'Skapa omröstning';

  @override
  String get pollClose => 'Stäng omröstning';

  @override
  String get askWhatToEat => 'Vad ska vi äta?';

  @override
  String get pickRecipesToVote => 'Välj recept att rösta på';

  @override
  String winnerAddedToMenu(String recipe) {
    return '$recipe lades till i veckomenyn';
  }

  @override
  String get noRecipesToVote => 'Inga recept att rösta om';

  @override
  String get importFirstCta => 'Importera ditt första recept';

  @override
  String get messageTypeText => 'Textmeddelande';

  @override
  String get messageTypeRecipeShare => 'Receptdelning';

  @override
  String get messageTypeMenuShare => 'Menydelning';

  @override
  String get messageTypeShoppingListShare => 'Inköpslistedelning';

  @override
  String get messageTypeSystem => 'Systemmeddelande';

  @override
  String get messageTypeImage => 'Bild';

  @override
  String get messageTypeVoice => 'Röstmeddelande';

  @override
  String get messageTypePoll => 'Omröstning';

  @override
  String get messageStatusSending => 'Skickar...';

  @override
  String get messageStatusSent => 'Skickat';

  @override
  String get messageStatusDelivered => 'Levererat';

  @override
  String get messageStatusRead => 'Läst';

  @override
  String get messageStatusFailed => 'Misslyckades';

  @override
  String get errorDnsResolution =>
      'Anslutningsproblem upptäckts. Försöker återansluta...';

  @override
  String get errorServiceUnavailable =>
      'Tjänsten är tillfälligt otillgänglig. Försök igen senare.';

  @override
  String get errorNoItemsFound => 'Inga objekt hittades.';

  @override
  String get errorNoUserLoggedIn => 'Ingen användare är inloggad';

  @override
  String get errorReauthRequired =>
      'Du måste logga in igen för att ta bort ditt konto';

  @override
  String get errorCouldNotRemoveMfa => 'Kunde inte ta bort MFA';

  @override
  String get errorEmailAlreadyInUse =>
      'Email-adressen används redan av ett annat konto.';

  @override
  String get errorInvalidEmailAddress => 'Ogiltig email-adress.';

  @override
  String get errorUserNotFoundByEmail =>
      'Ingen användare hittades med denna email.';

  @override
  String get errorWrongPassword => 'Fel lösenord.';

  @override
  String get errorInvalidCredentials =>
      'Fel email eller lösenord. Kontrollera dina uppgifter.';

  @override
  String get errorAccountDisabled => 'Detta konto har inaktiverats.';

  @override
  String get errorTooManyAttempts =>
      'För många försök. Vänta en stund och försök igen.';

  @override
  String get errorInvalidVerificationCode =>
      'Ogiltig verifieringskod. Försök igen.';

  @override
  String get errorSessionExpired => 'Sessionen har gått ut. Försök igen.';

  @override
  String get errorTooManySmsAttempts =>
      'För många SMS-försök. Försök igen senare.';

  @override
  String get errorPhoneNumberMissing => 'Telefonnummer saknas.';

  @override
  String get errorMustBeLoggedIn => 'Du måste vara inloggad';

  @override
  String get errorMustBeLoggedInToImport =>
      'Du måste vara inloggad för att importera recept';

  @override
  String get errorMustBeLoggedInToExport =>
      'Du måste vara inloggad för att exportera data';

  @override
  String get errorMustBeLoggedInToManageConsent =>
      'Du måste vara inloggad för att hantera samtycken';

  @override
  String get errorRecipeNameEmpty => 'Receptnamn kan inte vara tomt';

  @override
  String get errorCanOnlyUpdatePersonalRecipes =>
      'Kan bara uppdatera personliga recept';

  @override
  String get errorRecipeNotFound => 'Recept hittades inte';

  @override
  String get errorNoPermissionToEdit =>
      'Du har inte behörighet att redigera detta recept';

  @override
  String get errorNotInRealtimeMode => 'Inte i realtidsredigeringsläge';

  @override
  String get errorTitleCannotBeEmpty => 'Titel kan inte vara tom';

  @override
  String get errorPortionsMustBePositive => 'Portioner måste vara större än 0';

  @override
  String get errorTimeMustBePositive => 'Tid måste vara större än 0 minuter';

  @override
  String get errorRecipeNeedsIngredient =>
      'Recept måste ha minst en ingrediens';

  @override
  String get errorRecipeNeedsInstruction =>
      'Recept måste ha minst en instruktion';

  @override
  String get errorNoPermissionToShare =>
      'Du har inte behörighet att dela detta recept';

  @override
  String get errorCouldNotSaveRecipe => 'Kunde inte spara recept';

  @override
  String errorShareCapReached(int max) {
    return 'Receptet har redan delats med max antal användare ($max)';
  }

  @override
  String get errorNoGroupMembersFound => 'Inga gruppmedlemmar hittades';

  @override
  String get errorRecipeNotShared => 'Receptet är inte delat';

  @override
  String get errorOnlyOwnerCanUnshare =>
      'Endast ägaren kan sluta dela receptet';

  @override
  String get errorCouldNotUnshareRecipe => 'Kunde inte sluta dela recept';

  @override
  String get errorCouldNotLoadTags => 'Kunde inte ladda taggar';

  @override
  String get errorTagUpdateFailed => 'Fel vid uppdatering av taggar';

  @override
  String get errorCouldNotCreateTag => 'Kunde inte skapa taggen';

  @override
  String get errorCouldNotUpdateTag => 'Kunde inte uppdatera taggen';

  @override
  String get errorTagNotFound => 'Taggen hittades inte';

  @override
  String get errorCouldNotDeleteTag => 'Kunde inte ta bort taggen';

  @override
  String get errorCouldNotCreateGroup => 'Kunde inte skapa gruppen';

  @override
  String get errorCouldNotUpdateGroup => 'Kunde inte uppdatera gruppen';

  @override
  String get errorGroupNotFound => 'Gruppen hittades inte';

  @override
  String get errorCouldNotDeleteGroup => 'Kunde inte ta bort gruppen';

  @override
  String get errorCouldNotCreateRule => 'Kunde inte skapa regeln';

  @override
  String get errorCouldNotUpdateRule => 'Kunde inte uppdatera regeln';

  @override
  String get errorCouldNotDeleteRule => 'Kunde inte ta bort regeln';

  @override
  String get errorNoImageToProcess => 'Ingen bild att behandla';

  @override
  String get errorPleaseEnterText => 'Vänligen ange text att tolka';

  @override
  String get errorPleaseEnterTextToImport => 'Vänligen ange text att importera';

  @override
  String get errorTextTooShort =>
      'Texten är för kort för att innehålla ett recept';

  @override
  String get errorPleaseEnterValidUrl => 'Vänligen ange en giltig URL';

  @override
  String get errorNoRecipeToValidate => 'Inget recept att validera';

  @override
  String get errorNoRecipeToSave => 'Inget recept att spara';

  @override
  String get importProvideText => 'Ange text att importera';

  @override
  String get importProvideUrl => 'Ange en giltig URL';

  @override
  String get importNoContent => 'Inget innehåll kunde hämtas från URL:en';

  @override
  String get errorRecipeTitleRequired => 'Recepttitel krävs';

  @override
  String get errorRecipeMustHaveIngredient =>
      'Receptet måste ha minst en ingrediens';

  @override
  String get errorRecipeMustHaveInstruction =>
      'Receptet måste ha minst en instruktion';

  @override
  String get errorImportConditionsNotMet => 'Importvillkor inte uppfyllda';

  @override
  String get errorImportFailed => 'Import misslyckades';

  @override
  String get errorImportTimeout =>
      'Det här tar längre tid än vanligt. Försök igen, eller importera texten manuellt.';

  @override
  String get errorNoRecipesSelected => 'Inga recept valda';

  @override
  String get errorEnterMenuDescription => 'Ange vad du vill ha för meny';

  @override
  String get errorNoMoreRecipesForSwap =>
      'Inga fler recept tillgängliga för byte';

  @override
  String get errorNoMenuToSave => 'Ingen meny att spara';

  @override
  String get errorEnterMenuName => 'Ange ett namn för menyn';

  @override
  String get errorMenuNotFound => 'Menyn kunde inte hittas';

  @override
  String get errorNoMenuToSaveAsTemplate => 'Ingen meny att spara som mall';

  @override
  String get errorCouldNotSaveTemplate => 'Kunde inte spara mall';

  @override
  String get errorNoMenuLoaded => 'Ingen meny laddad';

  @override
  String get errorNoEditPermission => 'Ingen redigeringsbehörighet';

  @override
  String get errorNoInternetConnection => 'Ingen internetanslutning';

  @override
  String get errorNoRecipesAvailable =>
      'Inga recept tillgängliga. Lägg till recept först.';

  @override
  String get errorNoMenuToShare => 'Ingen meny att dela';

  @override
  String get errorCouldNotAddItem => 'Kunde inte lägga till artikel';

  @override
  String get errorCouldNotUpdateItem => 'Kunde inte uppdatera artikel';

  @override
  String get errorListNotFound => 'Lista hittades inte';

  @override
  String get errorCouldNotLoadGroupInfo => 'Kunde inte ladda gruppinformation';

  @override
  String get errorCouldNotAddMembers => 'Kunde inte lägga till medlemmar';

  @override
  String get errorCouldNotLeaveGroup => 'Kunde inte lämna grupp';

  @override
  String get errorCouldNotLoadConversation => 'Kunde inte ladda konversation';

  @override
  String get errorCouldNotLoadMessages => 'Kunde inte ladda meddelanden';

  @override
  String get errorCouldNotStartConversation => 'Kunde inte starta konversation';

  @override
  String get errorMessageCannotBeEmpty => 'Meddelandet kan inte vara tomt';

  @override
  String get errorNoFriendsOrGroupsSelected =>
      'Inga vänner eller grupper valda';

  @override
  String get errorNoRecipientsFound => 'Inga mottagare hittades';

  @override
  String get errorFormIncomplete => 'Formuläret är inte komplett';

  @override
  String get errorMustCreateProfileFirst => 'Du måste skapa en profil först';

  @override
  String get errorTitleRequiredNotEmpty => 'Titel krävs och får inte vara tom';

  @override
  String get errorDescriptionTooLong => 'Beskrivning för lång';

  @override
  String get errorGroupNameRequired => 'Gruppnamn krävs';

  @override
  String get errorGroupNameExists => 'Det här gruppnamnet finns redan';

  @override
  String get errorOnlyAdminCanAddMembers =>
      'Endast administratör kan lägga till medlemmar';

  @override
  String get errorOnlyAdminCanRemoveMembers =>
      'Endast administratör kan ta bort medlemmar';

  @override
  String get errorUseLeaveGroupToLeave =>
      'Använd \"Lämna grupp\" för att lämna konversationen';

  @override
  String get errorOnlyAdminCanChangeGroupName =>
      'Endast administratör kan ändra gruppnamn';

  @override
  String get errorGroupNameCannotBeEmpty => 'Gruppnamn kan inte vara tomt';

  @override
  String get errorFillRequiredFields => 'Fyll i alla obligatoriska fält';

  @override
  String get errorNoPermissionToSave =>
      'Du har inte behörighet att spara detta recept';

  @override
  String get errorNoRecipeToFork => 'Inget recept att forka';

  @override
  String get errorCouldNotForkRecipe => 'Kunde inte forka recept';

  @override
  String get errorNoRecipeToDelete => 'Inget recept att ta bort';

  @override
  String get errorNoPermissionToDelete =>
      'Du har inte behörighet att ta bort detta recept';

  @override
  String get errorPasswordCannotBeEmpty => 'Lösenord kan inte vara tomt';

  @override
  String get errorPasswordMinSixChars => 'Lösenord måste vara minst 6 tecken';

  @override
  String get errorDisplayNameCannotBeEmpty => 'Visningsnamn kan inte vara tomt';

  @override
  String get errorDisplayNameMinLength =>
      'Visningsnamn måste vara minst 2 tecken';

  @override
  String get errorSomeSharesFailed => 'Vissa delningar misslyckades';

  @override
  String get errorNoFriendsToShareWith => 'Du har inga vänner att dela med';

  @override
  String get errorSelectAtLeastOneFriend => 'Välj minst en vän att dela med';

  @override
  String get errorFillRequiredFieldsCorrectly =>
      'Fyll i alla obligatoriska fält korrekt';

  @override
  String get errorNameAlreadyTaken => 'Detta namn är redan taget';

  @override
  String get errorNoPermissionToManageParticipants =>
      'Ingen behörighet att hantera deltagare';

  @override
  String get errorCannotRemoveSelf =>
      'Kan inte ta bort sig själv som deltagare';

  @override
  String get errorCannotChangeOwnPermissions =>
      'Kan inte ändra sina egna behörigheter';

  @override
  String get errorNoUserIdAvailable => 'Ingen användar-ID tillgänglig';

  @override
  String get errorInvitationNotFound => 'Inbjudan hittades inte';

  @override
  String get errorNoInternetCheckConnection =>
      'Ingen internetanslutning. Kontrollera din anslutning och försök igen.';

  @override
  String get errorPermissionDeniedRetry =>
      'Behörighet nekad. Försök logga in igen.';

  @override
  String get errorExportFailed =>
      'Ett fel uppstod vid export av data. Försök igen.';

  @override
  String errorTagNameExists(String name) {
    return 'En tagg med namnet \"$name\" finns redan';
  }

  @override
  String get errorGroupDoesNotExist => 'Gruppen finns inte';

  @override
  String get errorTagDoesNotExist => 'Taggen finns inte';

  @override
  String get errorRuleDoesNotExist => 'Regeln finns inte';

  @override
  String get errorSharedTagNotFound => 'Delad tagg hittades inte';

  @override
  String get errorOwnerMustKeepPermission =>
      'Ägaren måste behålla owner-behörighet';

  @override
  String get errorCouldNotLoadRecipes => 'Kunde inte ladda recept';

  @override
  String get errorCouldNotDeleteRecipe => 'Kunde inte ta bort recept';

  @override
  String get errorCouldNotValidateImage => 'Kunde inte validera bild';

  @override
  String get actionRecipeSaving => 'sparar recept';

  @override
  String get actionRecipeUploading => 'laddar upp recept';

  @override
  String get actionRecipeLoading => 'laddar recept';

  @override
  String get actionRecipeDeleting => 'tar bort recept';

  @override
  String get actionRecipeValidation => 'validerar recept';

  @override
  String get actionRecipeCollaborativeSync => 'synkroniserar delat recept';

  @override
  String get actionRecipeDraftRestore => 'återställer utkast';

  @override
  String get actionRecipeImageUpload => 'laddar upp bilder';

  @override
  String get actionRecipeImageProcessing => 'bearbetar bilder';

  @override
  String get actionRecipeImageDelete => 'tar bort bild';

  @override
  String get actionShoppingListCreate => 'skapar inköpslista';

  @override
  String get actionShoppingItemAdd => 'lägger till vara';

  @override
  String get actionShoppingListSync => 'synkroniserar inköpslista';

  @override
  String get actionShoppingListShare => 'delar inköpslista';

  @override
  String get actionShoppingListDelete => 'tar bort inköpslista';

  @override
  String get actionFriendInvite => 'skickar väninvitation';

  @override
  String get actionGroupCreate => 'skapar grupp';

  @override
  String get actionMessagesSend => 'skickar meddelande';

  @override
  String get actionSocialSync => 'synkroniserar socialt innehåll';

  @override
  String get actionUserProfileUpdate => 'uppdaterar profil';

  @override
  String get actionPermissionRequest => 'begär behörighet';

  @override
  String get actionAppStartup => 'startar app';

  @override
  String get actionDataSync => 'synkroniserar data';

  @override
  String get actionBackgroundUpload => 'bakgrundsuppladdning';

  @override
  String get actionOffline => 'offline-operation';

  @override
  String errorNetworkNoConnection(String action) {
    return 'Ingen internetanslutning medan $action. Ändringar sparas lokalt och synkroniseras automatiskt när du är online igen.';
  }

  @override
  String errorNetworkLimited(String action) {
    return 'Begränsad internetanslutning medan $action. Vissa funktioner kan vara otillgängliga.';
  }

  @override
  String errorNetworkDegraded(String action) {
    return 'Anslutningsproblem medan $action. DNS-problem upptäckta, kontrollerar anslutningen automatiskt.';
  }

  @override
  String errorNetworkTemporary(String action) {
    return 'Tillfälligt nätverksfel medan $action. Kontrollerar anslutningen och försöker igen automatiskt.';
  }

  @override
  String errorNetworkUnknownStatus(String action) {
    return 'Okänd anslutningsstatus medan $action. Kontrollera internetanslutningen och försök igen.';
  }

  @override
  String errorAuthNoPermissionFor(String action) {
    return 'Du saknar behörighet för $action';
  }

  @override
  String errorAuthNotLoggedInWhile(String base) {
    return '$base eftersom du inte är inloggad.';
  }

  @override
  String errorAuthViewerOnly(String base) {
    return '$base. Du har endast läsrättigheter för detta innehåll.';
  }

  @override
  String errorAuthEditorRequired(String base) {
    return '$base. Redigeringsrättigheter krävs för denna åtgärd.';
  }

  @override
  String errorAuthNotShared(String base) {
    return '$base. Du har inte delats detta innehåll.';
  }

  @override
  String errorAuthOwnerOnly(String base, String owner) {
    return '$base. Endast ägaren ($owner) kan utföra denna åtgärd.';
  }

  @override
  String errorAuthContactOwner(String base) {
    return '$base. Kontakta innehållsägaren för utökade rättigheter.';
  }

  @override
  String errorNotFoundRecipe(String action) {
    return 'Receptet kunde inte hittas medan $action. Det kan ha blivit raderat eller flyttat av ägaren.';
  }

  @override
  String errorNotFoundShoppingList(String action) {
    return 'Inköpslistan kunde inte hittas medan $action. Den kan ha blivit raderad eller du har inte längre åtkomst.';
  }

  @override
  String errorNotFoundImage(String action) {
    return 'Bilden kunde inte hittas medan $action. Den kan ha blivit raderad eller flyttad.';
  }

  @override
  String errorNotFoundGeneric(String action) {
    return 'Det begärda innehållet kunde inte hittas medan $action. Det kan ha blivit raderat eller du har inte längre åtkomst.';
  }

  @override
  String errorServiceMaintenance(String action) {
    return 'Tjänsten är temporärt otillgänglig för underhåll medan $action. Försök igen om några minuter.';
  }

  @override
  String errorServiceSync(String action) {
    return 'Synkroniseringstjänsten är temporärt otillgänglig medan $action. Ändringar sparas lokalt och synkroniseras automatiskt senare.';
  }

  @override
  String errorServiceTemporary(String action) {
    return 'Tjänsten är temporärt otillgänglig medan $action. Försök igen om ett par minuter.';
  }

  @override
  String errorDnsConnection(String action) {
    return 'Kunde inte ansluta till servern medan $action. Kontrollera internetanslutningen eller försök igen senare.';
  }

  @override
  String errorUnknownWhileAction(String action) {
    return 'Ett oväntat fel uppstod medan $action. Försök igen eller kontakta support om problemet kvarstår.';
  }

  @override
  String errorUnknownWithTechnical(String action, String techInfo) {
    return 'Ett oväntat fel uppstod medan $action. Försök igen eller kontakta support om problemet kvarstår. (Teknisk information: $techInfo)';
  }

  @override
  String errorFallbackWhileAction(String action) {
    return 'Ett fel uppstod medan $action. Försök igen.';
  }

  @override
  String get suggestionLabel => 'Förslag:';

  @override
  String get suggestionSavedLocally =>
      'Receptet sparas lokalt och synkroniseras automatiskt';

  @override
  String get suggestionCheckLoggedIn => 'Kontrollera att du är inloggad';

  @override
  String get suggestionRequestPermission =>
      'Be om redigeringsrättigheter från receptägaren';

  @override
  String get suggestionImageSavedLocally =>
      'Bilderna sparas lokalt och laddas upp automatiskt senare';

  @override
  String get suggestionImageSizeLimit =>
      'Kontrollera att bilderna är mindre än 10MB';

  @override
  String get suggestionImageFormat => 'Använd JPG, PNG eller HEIC format';

  @override
  String get suggestionSelectAnotherDraft =>
      'Välj ett annat utkast från listan';

  @override
  String get suggestionCreateNewRecipe =>
      'Börja skapa ett nytt recept istället';

  @override
  String get suggestionUpdateAccountSettings =>
      'Uppdatera dina kontoinställningar';

  @override
  String get suggestionCheckConnection => 'Kontrollera internetanslutningen';

  @override
  String get suggestionRetryWhenStable =>
      'Försök igen när anslutningen är stabil';

  @override
  String get suggestionLoginAgain => 'Logga in på nytt';

  @override
  String get suggestionRetryInMinutes => 'Försök igen om några minuter';

  @override
  String get suggestionRetryOrContactSupport =>
      'Försök igen eller kontakta support';

  @override
  String get statusConnected => 'Ansluten';

  @override
  String get statusFirebaseUnavailable => 'Firebase otillgänglig';

  @override
  String get statusNoInternet => 'Ingen internetanslutning';

  @override
  String get statusDisconnected => 'Frånkopplad';

  @override
  String get statusCheckingConnection => 'Kontrollerar anslutning...';

  @override
  String get statusReconnecting => 'Återansluter...';

  @override
  String get statusDone => 'Klar!';

  @override
  String get displayOnlyYou => 'Bara du';

  @override
  String get displayUnknownUser => 'Okänd användare';

  @override
  String get displayNoConsent => 'Inget samtycke';

  @override
  String get resourceTypeRecipe => 'Recept';

  @override
  String get resourceTypeMenu => 'Meny';

  @override
  String get resourceTypeShoppingList => 'Inköpslista';

  @override
  String get permissionOwner => 'Ägare';

  @override
  String get permissionAdmin => 'Administratör';

  @override
  String get permissionEditor => 'Redigerare';

  @override
  String get permissionWriter => 'Skrivare';

  @override
  String get permissionViewer => 'Betraktare';

  @override
  String get permissionReader => 'Läsare';

  @override
  String get permissionUnknown => 'Okänd behörighet';

  @override
  String get activityJustNow => 'Just nu';

  @override
  String get activityActiveNow => 'Aktiv nu';

  @override
  String get activityActiveThisWeek => 'Aktiv denna veckan';

  @override
  String get activityInactive => 'Inaktiv';

  @override
  String get validationTitleCannotBeEmpty => 'Titel får inte vara tom';

  @override
  String get validationIngredientRequired => 'Minst en ingrediens krävs';

  @override
  String get validationInstructionRequired => 'Minst en instruktion krävs';

  @override
  String get validationPortionsMustBePositive =>
      'Portioner måste vara positiva';

  @override
  String get validationTimeMustBePositive => 'Tid måste vara positiv';

  @override
  String get validationRatingRange => 'Betyg måste vara mellan 0 och 5';

  @override
  String validationInvalidIngredientIndex(int index) {
    return 'Ogiltigt ingrediensindex: $index';
  }

  @override
  String validationInvalidInstructionIndex(int index) {
    return 'Ogiltigt instruktionsindex: $index';
  }

  @override
  String validationInvalidImageIndex(int index) {
    return 'Ogiltigt bildindex: $index';
  }

  @override
  String get notificationTitleSuccess => 'Lyckades!';

  @override
  String get notificationTitleError => 'Fel uppstod';

  @override
  String get notificationTitleNewRecipeActivity => 'Ny receptaktivitet';

  @override
  String get notificationTitleFriendActivity => 'Vänaktivitet';

  @override
  String get notificationTitleCollaborationActivity => 'Samarbetsaktivitet';

  @override
  String get notificationTitleShoppingLists => 'Inköpslistor';

  @override
  String get errorWeakPassword =>
      'Lösenordet är för svagt. Använd minst 6 tecken.';

  @override
  String get errorLoginFailed => 'Inloggning misslyckades. Försök igen.';

  @override
  String get errorCouldNotLogOut => 'Kunde inte logga ut';

  @override
  String get errorCouldNotDeleteAccount => 'Kunde inte ta bort konto';

  @override
  String get errorCouldNotCompleteMfa => 'Kunde inte slutföra MFA-registrering';

  @override
  String get errorMfaVerificationFailed => 'MFA-verifiering misslyckades';

  @override
  String get errorInvalidPhoneNumber =>
      'Ogiltigt telefonnummer. Ange med landskod (+46).';

  @override
  String get errorCouldNotSaveRecipeCheckConnection =>
      'Kunde inte spara receptet. Kontrollera din internetanslutning.';

  @override
  String get errorCouldNotUpdateRecipeCheckConnection =>
      'Kunde inte uppdatera receptet. Kontrollera din internetanslutning.';

  @override
  String get errorCouldNotDeleteFromServer =>
      'Kunde inte ta bort recept från servern';

  @override
  String errorRateLimitExceeded(int seconds) {
    return 'För många förfrågningar. Försök igen om $seconds sekunder.';
  }

  @override
  String get errorCouldNotImportRecipes => 'Kunde inte importera recept';

  @override
  String get errorCouldNotAddRecipe => 'Receptet kunde inte läggas till.';

  @override
  String get errorCouldNotUpdateRecipe => 'Receptet kunde inte uppdateras.';

  @override
  String get errorCouldNotExportRecipes => 'Kunde inte exportera recept';

  @override
  String get errorCouldNotMarkAsCooked =>
      'Kunde inte markera recept som tillagat';

  @override
  String get errorCouldNotAddIngredient => 'Kunde inte lägga till ingrediens';

  @override
  String get errorCouldNotUpdateIngredient => 'Kunde inte uppdatera ingrediens';

  @override
  String get errorCouldNotRemoveIngredient => 'Kunde inte ta bort ingrediens';

  @override
  String get errorCouldNotAddInstruction => 'Kunde inte lägga till instruktion';

  @override
  String get errorCouldNotUpdateInstruction =>
      'Kunde inte uppdatera instruktion';

  @override
  String get errorCouldNotRemoveInstruction => 'Kunde inte ta bort instruktion';

  @override
  String get errorCouldNotStartRealtimeEditing =>
      'Kunde inte starta realtidsredigering';

  @override
  String get errorRealtimeSyncFailed => 'Realtidssynkronisering misslyckades';

  @override
  String get errorCouldNotApplyRealtimeEdit =>
      'Kunde inte genomföra realtidsändring';

  @override
  String get errorCouldNotStartSync => 'Kunde inte starta synkronisering';

  @override
  String errorSyncErrorFor(String syncType) {
    return 'Synkroniseringsfel för $syncType';
  }

  @override
  String get errorCouldNotUpdateNotificationToken =>
      'Kunde inte uppdatera notifikationstoken';

  @override
  String get errorCouldNotUpdateNotificationSettings =>
      'Kunde inte uppdatera notifikationsinställningar';

  @override
  String get errorCouldNotUpdateAllergenSettings =>
      'Kunde inte uppdatera allergeninställningar';

  @override
  String get errorCouldNotLoadProfile => 'Kunde inte ladda profil';

  @override
  String get errorCouldNotUpdateRecipes => 'Kunde inte uppdatera recept';

  @override
  String get errorNetworkCheckInternet =>
      'Nätverksfel - kontrollera din internetanslutning';

  @override
  String get errorPermissionMissing => 'Behörighet saknas';

  @override
  String get errorTimeout => 'Tidsgräns överskriden';

  @override
  String get errorTechnical => 'Tekniskt fel';

  @override
  String get permissionCanViewRecipe => 'Kan visa recept';

  @override
  String get permissionCanComment => 'Kan skriva kommentarer';

  @override
  String get permissionCanEditRecipe => 'Kan redigera recept';

  @override
  String get permissionCanManageMembers => 'Kan hantera medlemmar';

  @override
  String get permissionOwnerOfRecipe => 'Ägare av recept';

  @override
  String errorGroupNameExistsWithName(String name) {
    return 'En grupp med namnet \"$name\" finns redan';
  }

  @override
  String get errorUserNotLoggedIn => 'Användare inte inloggad';

  @override
  String get errorResourceNotFound => 'Resursen hittades inte';

  @override
  String get errorNoDeletePermission => 'Ingen behörighet att ta bort resursen';

  @override
  String get errorCannotRemoveResourceOwner =>
      'Kan inte ta bort ägaren från resursen';

  @override
  String get validationRecipeTitleCannotBeEmpty =>
      'Recepttitel kan inte vara tom';

  @override
  String get validationCookingTimeCannotBeNegative =>
      'Tillagningstid kan inte vara negativ';

  @override
  String get validationIngredientCannotBeEmpty =>
      'Ingrediens kan inte vara tom';

  @override
  String get validationInstructionCannotBeEmpty =>
      'Instruktion kan inte vara tom';

  @override
  String get validationAtLeastOneIngredient => 'Minst en ingrediens krävs';

  @override
  String get validationAtLeastOneInstruction => 'Minst en instruktion krävs';

  @override
  String get validationImageUrlCannotBeEmpty => 'Bild-URL kan inte vara tom';

  @override
  String get validationInvalidImageUrlFormat => 'Ogiltig bild-URL format';

  @override
  String get validationMaxImagesReached => 'Maximalt 5 bilder tillåtna';

  @override
  String get validationRecipeTitleMissing => 'Recepttitel saknas';

  @override
  String get validationRecipeNoIngredients => 'Recept har inga ingredienser';

  @override
  String get validationRecipeNoInstructions => 'Recept har inga instruktioner';

  @override
  String get validationRecipeDescriptionEmpty => 'Receptbeskrivning saknas';

  @override
  String get validationUserIdCannotBeEmpty => 'Användar-ID kan inte vara tomt';

  @override
  String get validationUsernameCannotBeEmpty =>
      'Användarnamn kan inte vara tomt';

  @override
  String validationUserAlreadyParticipant(String name) {
    return 'Användaren är redan deltagare: $name';
  }

  @override
  String get validationMaxParticipantsReached =>
      'Maxgräns för deltagare nådd (50)';

  @override
  String get validationCannotRemoveRecipeOwner =>
      'Kan inte ta bort receptägaren';

  @override
  String get validationCannotRemoveMenuOwner => 'Kan inte ta bort menyägaren';

  @override
  String validationUserNotParticipant(String id) {
    return 'Användaren är inte deltagare: $id';
  }

  @override
  String get validationCannotChangeOwnerPermission =>
      'Kan inte ändra ägarens behörighet';

  @override
  String get validationCannotAssignOwnerPermission =>
      'Kan inte tilldela ägarbehörighet till annan användare';

  @override
  String get validationRecipeMissingOwner => 'Recept saknar ägare';

  @override
  String get validationRecipeOwnerMissingName =>
      'Receptägare saknar visningsnamn';

  @override
  String get validationParticipantEmptyUserId =>
      'Deltagare har tomt användar-ID';

  @override
  String get validationTagNameRequired => 'Taggnamn krävs';

  @override
  String get validationTagNameTooLong => 'Taggnamn för långt (max 50 tecken)';

  @override
  String get validationTagNameNoCommas =>
      'Taggnamn får inte innehålla kommatecken';

  @override
  String get validationTagNameReserved =>
      'Detta namn är reserverat för systemtaggar';

  @override
  String get validationGroupNameRequired => 'Gruppnamn krävs';

  @override
  String get validationGroupNameTooLong =>
      'Gruppnamn för långt (max 50 tecken)';

  @override
  String get validationRuleMustBeLinked => 'Regel måste kopplas till en tagg';

  @override
  String get validationRuleNameRequired => 'Regelnamn krävs';

  @override
  String get validationRuleMustHaveCondition =>
      'Regel måste ha minst ett villkor';

  @override
  String get validationAllConditionsMustHaveValue =>
      'Alla villkor måste ha ett värde';

  @override
  String get validationImageDoesNotExist => 'Bilden finns inte';

  @override
  String get validationCouldNotReadImageSize => 'Kunde inte läsa bildstorlek';

  @override
  String validationImageTooLargeWithSize(int size) {
    return 'Bilden är för stor (max $size MB)';
  }

  @override
  String get validationCouldNotValidateImage => 'Kunde inte validera bild';

  @override
  String get difficultyVeryEasy => 'Mycket lätt';

  @override
  String get difficultyEasy => 'Lätt';

  @override
  String get difficultyMedium => 'Medel';

  @override
  String get difficultyHard => 'Svår';

  @override
  String get difficultyVeryHard => 'Mycket svår';

  @override
  String get difficultyUnknown => 'Okänd';

  @override
  String contentSummaryIngredients(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ingredienser',
      one: '1 ingrediens',
    );
    return '$_temp0';
  }

  @override
  String contentSummarySteps(int count) {
    return '$count steg';
  }

  @override
  String contentSummaryMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuter',
      one: '1 minut',
    );
    return '$_temp0';
  }

  @override
  String contentSummaryPortions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portioner',
      one: '1 portion',
    );
    return '$_temp0';
  }

  @override
  String get collaborationPrivateRecipe => 'Privat recept';

  @override
  String collaborationCollaborativeEditorsViewers(int editors, int viewers) {
    return 'Kollaborativt ($editors redigerare, $viewers betraktare)';
  }

  @override
  String collaborationCollaborativeEditors(int editors) {
    return 'Kollaborativt ($editors redigerare)';
  }

  @override
  String collaborationSharedViewers(int viewers) {
    return 'Delat ($viewers betraktare)';
  }

  @override
  String get collaborationSharedRecipe => 'Delat recept';

  @override
  String participantOwnerOnly(String name) {
    return 'Endast ägare: $name';
  }

  @override
  String participantSummary(String owner, int count) {
    return 'Ägare: $owner, Deltagare: ${count}st';
  }

  @override
  String activityMinutesAgo(int count) {
    return '$count min sedan';
  }

  @override
  String activityHoursAgo(int count) {
    return '$count tim sedan';
  }

  @override
  String activityDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagar sedan',
      one: '1 dag sedan',
    );
    return '$_temp0';
  }

  @override
  String activityWeeksAgo(int count) {
    return '$count veckor sedan';
  }

  @override
  String resourceCreatedBy(String name) {
    return 'Skapades av $name';
  }

  @override
  String resourceLastEditedBy(String name, String timeAgo) {
    return 'Senast redigerad av $name $timeAgo';
  }

  @override
  String get syncParsingNotImplemented =>
      'RealtimeShoppingList parsing inte implementerad än';

  @override
  String get backupNoRecipesToExport => 'Inga recept att exportera';

  @override
  String get backupPlatformNotSupported => 'Plattformen stöds inte';

  @override
  String get backupSavedAndroid => 'Backup sparad i Android/data/.../Butlery';

  @override
  String get backupSavedIos => 'Backup sparad i Filer-appen';

  @override
  String get backupCouldNotFindStorageDir => 'Kunde inte hitta lagringsmapp';

  @override
  String backupCouldNotSaveFile(String error) {
    return 'Kunde inte spara fil: $error';
  }

  @override
  String get backupCouldNotReadFile => 'Kunde inte läsa filen';

  @override
  String get backupInvalidFile => 'Ogiltig backup-fil - inte från Butlery';

  @override
  String get backupUnknownRecipe => 'Okänt recept';

  @override
  String backupImportedFromBackup(String date) {
    return 'Importerat från backup $date';
  }

  @override
  String backupExportFailed(String error) {
    return 'Export misslyckades: $error';
  }

  @override
  String backupImportFailed(String error) {
    return 'Import misslyckades: $error';
  }

  @override
  String get syncAlreadyInProgress => 'Synkronisering pågår redan';

  @override
  String get syncMustBeOnline => 'Du måste vara online för att synkronisera';

  @override
  String get syncNoUserLoggedIn => 'Ingen användare inloggad';

  @override
  String get syncNoPendingChanges => 'Inga väntande ändringar';

  @override
  String syncAllSynced(int count) {
    return 'Alla $count ändringar synkade!';
  }

  @override
  String syncPartialSuccess(int synced, int total, int remaining) {
    return '$synced av $total synkade, $remaining kvar';
  }

  @override
  String get syncFailedRetryLater =>
      'Synkronisering misslyckades, försöker igen senare';

  @override
  String get instagramCouldNotFindRecipe =>
      'Kunde inte hitta recept i inlagget. Ta en skärmbild av receptet.';

  @override
  String get uploadNotificationComplete => 'Uppladdning slutförd';

  @override
  String get uploadNotificationCompleteBody =>
      'Bilden har laddats upp framgångsrikt';

  @override
  String get uploadNotificationFailed => 'Uppladdning misslyckades';

  @override
  String get uploadNotificationFailedBody =>
      'Kunde inte ladda upp bilden efter flera försök';

  @override
  String uploadStatusWaiting(int pending) {
    return 'Väntar på att ladda upp $pending bilder...';
  }

  @override
  String uploadStatusUploading(int active, int progress, int pending) {
    return 'Laddar upp $active bilder ($progress% klart, $pending väntar)';
  }

  @override
  String get uploadStatusPreparing => 'Förbereder uppladdning...';

  @override
  String uploadStatusRetrying(int attempt, int max) {
    return 'Försöker igen ($attempt/$max)...';
  }

  @override
  String get uploadStatusComplete => 'Uppladdning slutförd';

  @override
  String get uploadStatusCancelled => 'Uppladdning avbruten';

  @override
  String get uploadFailureNetwork => 'Nätverksfel - kontrollera anslutningen';

  @override
  String get uploadFailureValidation => 'Bilden kunde inte valideras';

  @override
  String get uploadFailureServer => 'Serverfel - försök igen';

  @override
  String get uploadFailureCancelled => 'Uppladdning avbruten';

  @override
  String get uploadFailureQuotaExceeded =>
      'Lagringsutrymmet för bilder är fullt. Radera några receptbilder för att ladda upp fler.';

  @override
  String get uploadFailureGeneric => 'Uppladdning misslyckades';

  @override
  String get uploadRetryCheckInternet =>
      'Kontrollera internetanslutningen och tryck för att försöka igen';

  @override
  String get uploadRetryCheckImage =>
      'Kontrollera att bilden är giltig och inte för stor';

  @override
  String get uploadRetryTryLater => 'Försök igen om en stund';

  @override
  String get uploadRetryTapToRetry => 'Tryck för att försöka igen';

  @override
  String llmUnexpectedError(String error) {
    return 'Ett oväntat fel uppstod: $error';
  }

  @override
  String get llmUnknownRecipe => 'Okänt recept';

  @override
  String get llmMustBeLoggedIn =>
      'Du måste vara inloggad för att använda AI-funktioner.';

  @override
  String get llmServiceOverloaded =>
      'AI-tjänsten är tillfälligt överbelastad. Försök igen om en stund.';

  @override
  String llmInvalidArgument(String error) {
    return 'Ogiltigt argument: $error';
  }

  @override
  String llmGenericError(String error) {
    return 'Ett fel uppstod: $error';
  }

  @override
  String get llmTimeout => 'Förfrågan tog för lång tid. Försök igen.';

  @override
  String get llmTemporarilyUnavailable =>
      'AI-tjänsten är tillfälligt otillgänglig. Försök igen om en stund.';

  @override
  String get tiktokCouldNotFetchDescription =>
      'Kunde inte hämta videobeskrivningen. Ta en skärmbild av receptet.';

  @override
  String get tiktokAiQuotaExhausted =>
      'AI-kvoten är slut. Markera receptdelar manuellt.';

  @override
  String get tiktokCouldNotExtractRecipe =>
      'Kunde inte extrahera receptet automatiskt. Markera receptdelar manuellt.';

  @override
  String get tiktokNoRecipeInDescription =>
      'Videobeskrivningen innehåller inget recept. Ta en skärmbild av receptet.';

  @override
  String rateLimitTooFast(int seconds) {
    return 'Du importerar för snabbt. Vänta $seconds sekunder.';
  }

  @override
  String rateLimitHourly(int minutes) {
    return 'Du har nått timgränsen. Försök igen om $minutes minuter.';
  }

  @override
  String get rateLimitDaily =>
      'Du har nått dagens gräns för importer. Försök igen imorgon.';

  @override
  String get rateLimitAiDaily =>
      'AI-kvoten för idag är slut. Försök igen imorgon.';

  @override
  String get rateLimitAiMonthly => 'AI-kvoten för månaden är slut.';

  @override
  String get rateLimitBudgetDaily =>
      'Dagens AI-budget är förbrukad. Försök igen imorgon.';

  @override
  String get rateLimitBudgetMonthly => 'Månadens AI-budget är förbrukad.';

  @override
  String get importErrorUnexpected => 'Ett oväntat fel uppstod';

  @override
  String get importErrorNoInternet => 'Ingen internetanslutning';

  @override
  String get importErrorTooManyImports =>
      'För många importer på kort tid. Vänta en stund.';

  @override
  String get importErrorAiQuotaExhausted => 'AI-kvoten är slut för idag';

  @override
  String get importErrorInvalidUrl => 'Ogiltig URL';

  @override
  String get importErrorCouldNotReachPage => 'Kunde inte nå sidan';

  @override
  String get importErrorLoginRequired => 'Sidan kräver inloggning';

  @override
  String get importErrorNoRecipeFound => 'Inget recept hittades';

  @override
  String get importErrorCouldNotReadImage => 'Kunde inte läsa texten i bilden';

  @override
  String get importErrorCouldNotParseRecipe => 'Kunde inte tolka receptet';

  @override
  String get importErrorCouldNotSaveRecipe => 'Kunde inte spara receptet';

  @override
  String get importErrorCancelled => 'Importen avbröts';

  @override
  String get messagingPoll => 'Omröstning';

  @override
  String get shoppingListEmpty => 'Tom handlingslista';

  @override
  String shoppingListAllBought(int count) {
    return 'Alla $count artiklar köpta';
  }

  @override
  String shoppingListItemsRemaining(int remaining, int total) {
    return '$remaining av $total artiklar kvar';
  }

  @override
  String get shoppingListNoActivity => 'Ingen aktivitet';

  @override
  String get shoppingListActivityNow => 'nu';

  @override
  String shoppingListActivityMinAgo(int count) {
    return '$count min sedan';
  }

  @override
  String shoppingListActivityHoursAgo(int count) {
    return '$count tim sedan';
  }

  @override
  String shoppingListActivityDaysAgo(int count) {
    return '$count dagar sedan';
  }

  @override
  String shoppingListLastActivityBy(String name, String time) {
    return 'Senaste aktivitet av $name $time';
  }

  @override
  String unknownResourceType(String value) {
    return 'Okänd RealtimeResourceType: $value';
  }

  @override
  String get notificationTitleDailySummary => 'Daglig sammanfattning';

  @override
  String get notificationBodyNoActivityToday => 'Ingen ny aktivitet idag';

  @override
  String get notificationBodyNoActivityToReport =>
      'Ingen aktivitet att rapportera';

  @override
  String get notificationBodyProblemLoadingActivities =>
      'Problem med att ladda aktiviteter';

  @override
  String get notificationBodyCouldNotCreateSummary =>
      'Kunde inte skapa sammanfattning';

  @override
  String get notificationActionViewRecipes => 'Visa recept';

  @override
  String get notificationActionViewFriends => 'Visa vänner';

  @override
  String get notificationActionOpenApp => 'Öppna app';

  @override
  String get notificationDefaultTitle => 'Ny aktivitet';

  @override
  String get notificationDefaultBody => 'Du har ny aktivitet i Butlery';

  @override
  String notificationDigestRecipes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept',
      one: '1 recept',
    );
    return '$_temp0';
  }

  @override
  String notificationDigestFriendActivities(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vänaktiviteter',
      one: '1 vänaktivitet',
    );
    return '$_temp0';
  }

  @override
  String notificationDigestShoppingLists(int count) {
    return '$count inköpslistor';
  }

  @override
  String notificationDigestCollaborations(int count) {
    return '$count samarbeten';
  }

  @override
  String get conditionTypeIngredient => 'Ingrediens';

  @override
  String get conditionTypeProperty => 'Egenskap';

  @override
  String get conditionTypeKeyword => 'Nyckelord';

  @override
  String get conditionTypeSource => 'Källa';

  @override
  String get conditionTypeCuisine => 'Kök';

  @override
  String get conditionTypeDiet => 'Kost';

  @override
  String get conditionTypeTime => 'Tid';

  @override
  String get conditionTypeRating => 'Betyg';

  @override
  String get conditionTypeRecent => 'Nyligen';

  @override
  String get conditionTypeCookedRecency => 'Senast lagad';

  @override
  String get conditionTypeOwnership => 'Ägarskap';

  @override
  String get conditionTypeHasImage => 'Har bild';

  @override
  String get conditionTypeCompleteness => 'Fullständighet';

  @override
  String get operatorContains => 'innehåller';

  @override
  String get operatorExact => 'är exakt';

  @override
  String get operatorStartsWith => 'börjar med';

  @override
  String get operatorNotContains => 'innehåller inte';

  @override
  String get operatorNotExact => 'är inte';

  @override
  String get operatorHas => 'har';

  @override
  String get operatorNotHas => 'har inte';

  @override
  String get operatorLessThan => 'mindre än';

  @override
  String get operatorAtMost => 'högst';

  @override
  String get operatorGreaterThan => 'mer än';

  @override
  String get operatorAtLeast => 'minst';

  @override
  String get operatorWithinDays => 'inom dagar';

  @override
  String get errorAuthenticationPleaseLogin =>
      'Autentiseringsfel. Logga in igen.';

  @override
  String get errorCouldNotShareRecipeWithGroups =>
      'Kunde inte dela recept med grupper';

  @override
  String get shoppingListNotFound => 'Lista hittades inte';

  @override
  String get shoppingRemainingToBuy => 'Kvar att handla:';

  @override
  String get shoppingAlreadyBought => 'Inhandlat:';

  @override
  String get shoppingCreatedLabel => 'Skapad:';

  @override
  String get shoppingUpdatedLabel => 'Uppdaterad:';

  @override
  String shoppingPurchaseForRecipe(String recipeName) {
    return 'Inköp för $recipeName';
  }

  @override
  String get shoppingCategoryImported => 'Importerat';

  @override
  String get shoppingCategoryRecipe => 'Recept';

  @override
  String get labelChat => 'Chatt';

  @override
  String labelParticipantCount(int count) {
    return '$count deltagare';
  }

  @override
  String errorCouldNotSend(String itemType) {
    return 'Kunde inte skicka $itemType';
  }

  @override
  String errorCouldNotShare(String itemType) {
    return 'Kunde inte dela $itemType';
  }

  @override
  String notificationBatchBodyRecipes(int count) {
    return '$count nya händelser på dina recept';
  }

  @override
  String notificationBatchBodyFriends(int count) {
    return '$count nya aktiviteter från dina vänner';
  }

  @override
  String notificationBatchBodyShopping(int count) {
    return '$count uppdateringar av dina inköpslistor';
  }

  @override
  String notificationBatchBodyCollaboration(int count) {
    return '$count nya samarbetsaktiviteter';
  }

  @override
  String notificationBatchBodyDefault(int count) {
    return '$count nya händelser i Butlery';
  }

  @override
  String notificationDigestBody(int totalCount, String summary) {
    return 'Du har $totalCount nya aktiviteter: $summary';
  }

  @override
  String uploadStatusUploadingNoPending(int active, int progress) {
    return 'Laddar upp $active bilder ($progress% klart)';
  }

  @override
  String uploadStatusPartialFailure(int completed, int total, int failed) {
    return '$completed av $total bilder uppladdade, $failed misslyckades';
  }

  @override
  String uploadStatusAllFailed(int failed, int total) {
    return '$failed av $total bilder misslyckades - tryck för att försöka igen';
  }

  @override
  String uploadStatusAllSuccess(int total) {
    return 'Alla $total bilder uppladdade framgångsrikt';
  }

  @override
  String uploadProgressWithTime(int progress, String time) {
    return '$progress% klart - $time kvar';
  }

  @override
  String uploadProgressPercent(int progress) {
    return '$progress% klart';
  }

  @override
  String get uploadComplete => 'Uppladdning slutförd';

  @override
  String uploadAllSuccessWithTime(String time) {
    return 'Alla bilder uppladdade$time (100% framgång)';
  }

  @override
  String uploadCompletionOf(int completed, int total) {
    return '$completed av $total slutförda';
  }

  @override
  String uploadFailureCount(int failed) {
    return ', $failed misslyckades';
  }

  @override
  String uploadSuccessRate(int rate) {
    return ' ($rate% framgång)';
  }

  @override
  String get uploadPreparing => 'Förbereder uppladdning...';

  @override
  String get errorNoImageSelected => 'Ingen bild vald';

  @override
  String get errorImageFormatUnsupported =>
      'Bildformatet stöds inte. Använd JPEG eller PNG-format.';

  @override
  String errorImageTooLarge(String size) {
    return 'Bilden är för stor ($size MB). Använd en mindre bild eller komprimera den.';
  }

  @override
  String errorImageQualityTooLow(int quality) {
    return 'Bildkvaliteten är för låg för OCR ($quality%).';
  }

  @override
  String get errorOcrServicesUnavailable =>
      'OCR-tjänsterna är tillfälligt otillgängliga. Försök igen om några minuter.';

  @override
  String get errorOcrRateLimit =>
      'För många förfrågningar just nu. Vänta en minut och försök igen.';

  @override
  String get errorOcrTimeout =>
      'Receptläsaren kunde inte nås. Kontrollera anslutningen och försök igen.';

  @override
  String get errorNoTextExtracted => 'Ingen text kunde extraheras från bilden.';

  @override
  String get labelImprovementSuggestions => 'Förbättringsförslag:';

  @override
  String get ocrQualityTips =>
      'Tips för bättre resultat:\n• Se till att bilden är välbelyst och skarp\n• Undvik skuggor och reflektioner\n• Håll kameran rakt mot texten';

  @override
  String get ocrRetryOrManual =>
      'Du kan försöka igen med en ny bild eller fortsätta med manuell inmatning.';

  @override
  String get errorAiEnhancementFailed => 'AI-förbättring misslyckades.';

  @override
  String errorCouldNotCreateRealtimeRecipe(String error) {
    return 'Kunde inte skapa realtidsrecept: $error';
  }

  @override
  String errorCouldNotWatchRecipe(String error) {
    return 'Kunde inte starta watching av recept: $error';
  }

  @override
  String errorCouldNotPerformOperation(String operation, String error) {
    return 'Kunde inte $operation: $error';
  }

  @override
  String errorCouldNotDeleteRealtimeRecipe(String error) {
    return 'Kunde inte ta bort realtidsrecept: $error';
  }

  @override
  String errorCouldNotCreateRealtimeMenu(String error) {
    return 'Kunde inte skapa realtidsmeny: $error';
  }

  @override
  String errorCouldNotWatchMenu(String error) {
    return 'Kunde inte starta watching av meny: $error';
  }

  @override
  String errorCouldNotDeleteRealtimeMenu(String error) {
    return 'Kunde inte ta bort realtidsmeny: $error';
  }

  @override
  String get ocrImageTooLarge => 'Bilden är för stor';

  @override
  String get ocrCompressImage => 'Komprimera bilden';

  @override
  String get ocrImageTooSmall => 'Bilden är för liten';

  @override
  String get ocrUseHigherResolution => 'Använd högre upplösning';

  @override
  String get ocrImageFormatNotOptimal => 'Bildformat stöds inte optimalt';

  @override
  String get ocrUseJpegOrPng => 'Använd JPEG eller PNG';

  @override
  String get ocrImageResolutionTooLow => 'Bildens upplösning är för låg';

  @override
  String get ocrImageRejected =>
      'Bilden är för suddig eller för liten — försök igen i bättre ljus.';

  @override
  String get syncErrorParsingResource => 'Fel vid parsing av resurs';

  @override
  String syncErrorWatchingResource(String resourceId) {
    return 'Fel vid watching av resurs $resourceId';
  }

  @override
  String get notificationActionAccept => 'Acceptera';

  @override
  String get notificationActionDecline => 'Avvisa';

  @override
  String get notificationActionViewRecipe => 'Visa recept';

  @override
  String get notificationActionJoin => 'Gå med';

  @override
  String get fcmChannelSocialTitle => 'Sociala notiser';

  @override
  String get fcmChannelSocialDescription =>
      'Vänförfrågningar, delningar och kommentarer';

  @override
  String get fcmChannelMessagingTitle => 'Meddelanden';

  @override
  String get fcmChannelMessagingDescription => 'Chattmeddelanden från vänner';

  @override
  String get tagValidationEmpty => 'Taggnamn kan inte vara tomt';

  @override
  String get tagValidationTooShort => 'Taggnamn måste vara minst 2 tecken';

  @override
  String get tagValidationTooLong => 'Taggnamn får vara max 50 tecken';

  @override
  String get tagValidationReserved =>
      'Detta namn är reserverat för systemtaggar';

  @override
  String menuAttributionText(String displayName) {
    return 'Inspirerat av meny från $displayName';
  }

  @override
  String get llmEnhancementNotEnoughData =>
      'Inte tillräckligt med data för AI-förbättring.';

  @override
  String get realtimeIngredientEmptyError => 'Ingrediens kan inte vara tom';

  @override
  String get realtimeIngredientInvalidIndex => 'Ogiltigt ingrediens-index';

  @override
  String get realtimeInstructionEmptyError => 'Instruktion kan inte vara tom';

  @override
  String get realtimeInstructionInvalidIndex => 'Ogiltigt instruktions-index';

  @override
  String menuDefaultTitle(String displayName) {
    return 'Meny från $displayName';
  }

  @override
  String get menuShareGroupFallback => 'Grupp';

  @override
  String menuShareGroupTitle(String categoryName) {
    return 'Meny för $categoryName';
  }

  @override
  String get menuTitleEmpty => 'Tom meny';

  @override
  String menuTitleSingleCategory(String category, int count) {
    return '$category meny ($count recept)';
  }

  @override
  String menuTitleMultiCategory(String categories, int count) {
    return 'Veckomeny med $categories ($count recept)';
  }

  @override
  String recipeAttributionText(String displayName) {
    return 'Inspirerat av recept från $displayName';
  }

  @override
  String get tiktokOriginalText => 'Originaltext från TikTok:';

  @override
  String get tiktokIdentifiedIngredients => 'Identifierade ingredienser:';

  @override
  String groupShareWarningManyGroups(int count) {
    return 'Delning till många grupper ($count) kan ta lång tid';
  }

  @override
  String groupShareWarningManyItems(int count) {
    return 'Delning av mycket innehåll ($count objekt) kan ta lång tid';
  }

  @override
  String groupShareWarningLargeOperation(int count) {
    return 'Stor operation ($count delningar) - överväg att dela upp den';
  }

  @override
  String get textImportSourceUrl => 'Importerat från text';

  @override
  String get assistedImportSelectInstructionsError =>
      'Välj minst en instruktion';

  @override
  String get assistedImportEnterRecipeName => 'Ange ett receptnamn';

  @override
  String get assistedImportAddIngredientError =>
      'Lägg till minst en ingrediens';

  @override
  String get assistedImportAddInstructionError =>
      'Lägg till minst en instruktion';

  @override
  String get formValidationIngredientRequired => 'Ingrediens krävs';

  @override
  String get formValidationIngredientTooLong =>
      'Ingrediens för lång (max 200 tecken)';

  @override
  String get formValidationInstructionRequired => 'Instruktion krävs';

  @override
  String get formValidationInstructionTooLong =>
      'Instruktion för lång (max 500 tecken)';

  @override
  String get formValidationTagTooLong => 'Tagg för lång (max 50 tecken)';

  @override
  String get formValidationTagNoCommas =>
      'Taggar får inte innehålla kommatecken';

  @override
  String get shoppingItemMarkedComplete => 'Markerade som klar';

  @override
  String get shoppingItemMarkedIncomplete => 'Markerade som ej klar';

  @override
  String get menuSuggestionVegetarian => 'Vegetarisk veckomeny för 2 personer';

  @override
  String get menuSuggestionQuickDinners => 'Snabba middagar för hela veckan';

  @override
  String get menuSuggestionMeatFish => 'Kött och fisk varierad meny';

  @override
  String get menuSuggestionFamily => 'Familjevänlig veckomeny';

  @override
  String get menuSuggestionHealthy => 'Hälsosam och näringsrik meny';

  @override
  String get menuSuggestionBudget => 'Budgetvänlig veckomeny';

  @override
  String get menuSuggestionItalian => 'Italiensk temameny';

  @override
  String get menuSuggestionAsian => 'Asiatisk inspirerad veckomeny';

  @override
  String recipeAutoTitleWithIngredient(String ingredient) {
    return 'Recept med $ingredient';
  }

  @override
  String get recipeAutoTitleUntitled => 'Namnlöst recept';

  @override
  String get importPhaseFetching => 'Hämtar innehåll...';

  @override
  String get importPhaseAnalyzing => 'Analyserar recept...';

  @override
  String get importPhaseCreating => 'Skapar recept...';

  @override
  String get importPhaseComplete => 'Klar!';

  @override
  String get importPhaseNeedsHelp => 'Behöver din hjälp';

  @override
  String get importPhaseError => 'Ett fel uppstod';

  @override
  String importElapsedSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String shoppingSharingSummary(String friendNames) {
    return 'Dela med: $friendNames';
  }

  @override
  String imageUploadTooLarge(String maxSize) {
    return 'Bilden är för stor (max ${maxSize}MB)';
  }

  @override
  String shareMessageRecipeWithTitle(String title) {
    return 'Kolla in detta recept: \"$title\"! 👩‍🍳';
  }

  @override
  String get shareMessageRecipeDefault =>
      'Jag hittade ett fantastiskt recept som jag ville dela med dig! 👩‍🍳';

  @override
  String shareMessageMenuWithTitle(String title) {
    return 'Här är min veckomeny: \"$title\" 📋';
  }

  @override
  String get shareMessageMenuDefault =>
      'Här är min veckomeny som kanske kan inspirera dig! 📋';

  @override
  String shareMessageShoppingListWithTitle(String title) {
    return 'Vill du hjälpa mig med inköpslistan: \"$title\"? 🛒';
  }

  @override
  String get shareMessageShoppingListDefault =>
      'Vill du hjälpa mig med inköpen denna vecka? 🛒';

  @override
  String get textImportSuggestionIngredients =>
      'Inkludera ingredienslista för bättre tolkning';

  @override
  String get textImportSuggestionInstructions =>
      'Inkludera tillagningsinstruktioner eller steg';

  @override
  String get textImportSuggestionTime =>
      'Inkludera tillagningstid om tillgänglig';

  @override
  String get textImportSuggestionPortions =>
      'Inkludera antal portioner om känt';

  @override
  String get textImportSuggestionLooksGood =>
      'Texten ser bra ut för recepttolkning';

  @override
  String get recipeFormPermissionsError => 'Fel vid laddning av permissions';

  @override
  String createSharedListError(String error) {
    return 'Fel vid skapande av delad lista: $error';
  }

  @override
  String get userStatusOnline => 'Online';

  @override
  String get userStatusJustActive => 'Aktiv nyss';

  @override
  String userStatusActiveMinutesAgo(int minutes) {
    return 'Aktiv för $minutes min sedan';
  }

  @override
  String userStatusActiveHoursAgo(int hours) {
    return 'Aktiv för $hours tim sedan';
  }

  @override
  String userStatusActiveDaysAgo(int days) {
    return 'Aktiv för $days dagar sedan';
  }

  @override
  String userStatusActiveWeeksAgo(int weeks) {
    return 'Aktiv för $weeks veckor sedan';
  }

  @override
  String recipeCookTimeMinutes(int minutes) {
    return '$minutes minuter';
  }

  @override
  String get recipeLastCookedToday => 'Tillagad idag';

  @override
  String get recipeLastCookedYesterday => 'Tillagad igår';

  @override
  String recipeLastCookedDaysAgo(int days) {
    return 'Tillagad för $days dagar sedan';
  }

  @override
  String messageSharedRecipe(String title) {
    return 'Delade ett recept: $title';
  }

  @override
  String messageSharedMenu(String title) {
    return 'Delade en meny: $title';
  }

  @override
  String messageSharedShoppingList(String title) {
    return 'Delade en inköpslista: $title';
  }

  @override
  String get conversationNoMessagesYet => 'Inga meddelanden än';

  @override
  String sharedRecipeAttributionText(String displayName) {
    return 'Inspirerat av recept från $displayName';
  }

  @override
  String realtimeRecipeCopyTitle(String title) {
    return 'Kopia av $title';
  }

  @override
  String realtimeRecipeSharedFrom(String displayName) {
    return 'Delat från $displayName';
  }

  @override
  String get friendCategoryDefaultFriends => 'Vänner';

  @override
  String get friendCategoryDefaultFriendsDesc => 'Nära vänner';

  @override
  String get friendCategoryDefaultNeighbors => 'Grannar';

  @override
  String get friendCategoryDefaultNeighborsDesc => 'Grannar och lokalområdet';

  @override
  String get friendCategoryDefaultWork => 'Jobbet';

  @override
  String get friendCategoryDefaultWorkDesc => 'Kollegor och arbetskompisar';

  @override
  String get friendCategoryDefaultFoodGroup => 'Matgrupp';

  @override
  String get friendCategoryDefaultFoodGroupDesc =>
      'Personer som älskar att laga mat';

  @override
  String get friendCategoryDefaultFamily => 'Familj';

  @override
  String get friendCategoryDefaultFamilyDesc => 'Familjemedlemmar';

  @override
  String get friendSummaryNoFriends => 'Inga vänner';

  @override
  String get friendSummaryOneFriend => '1 vän';

  @override
  String friendSummaryCount(int count) {
    return '$count vänner';
  }

  @override
  String shoppingListSharedBy(String displayName) {
    return 'Delad av $displayName';
  }

  @override
  String shoppingListOriginallySharedBy(String displayName) {
    return 'Ursprungligen delad av $displayName';
  }

  @override
  String get collaborationNotAllowed => 'Ingen kollaboration tillåten';

  @override
  String get collaborationReady => 'Redo för kollaboration';

  @override
  String get collaborationVersionCreated => 'Kollaborativ version skapad';

  @override
  String get collaborationOneActive => '1 aktiv kollaboratör';

  @override
  String collaborationMultipleActive(int count) {
    return '$count aktiva kollaboratörer';
  }

  @override
  String recipeCopiedFrom(String title) {
    return 'Kopierat från: $title';
  }

  @override
  String get statusEmptyList => 'Tom lista';

  @override
  String get statusCompleted => 'Klar';

  @override
  String get statusInProgress => 'Pågående';

  @override
  String get statusNoActivity => 'Ingen aktivitet';

  @override
  String get statusPurchased => 'Inhandlad';

  @override
  String get timeJustNow => 'just nu';

  @override
  String timeMinutesAgo(int minutes) {
    return '${minutes}m sedan';
  }

  @override
  String timeHoursAgo(int hours) {
    return '${hours}h sedan';
  }

  @override
  String timeMinutesAgoLong(int minutes) {
    return '$minutes min sedan';
  }

  @override
  String timeHoursAgoLong(int hours) {
    return '$hours tim sedan';
  }

  @override
  String timeDaysAgoLong(int days) {
    return '$days dagar sedan';
  }

  @override
  String timeWeeksAgo(int weeks) {
    return '$weeks veckor sedan';
  }

  @override
  String get timeNow => 'Nu';

  @override
  String get dateTomorrow => 'Imorgon';

  @override
  String get dateNoDate => 'Inget datum';

  @override
  String dateDaysAhead(int days) {
    return '$days dagar framåt';
  }

  @override
  String labelMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
    );
    return '$_temp0';
  }

  @override
  String get labelParticipantFallback => 'Deltagare';

  @override
  String get labelRecipes => 'Recept';

  @override
  String get labelMenus => 'Menyer';

  @override
  String get labelShopping => 'Handla';

  @override
  String get labelCollaborativeMenu => 'Kollaborativ meny';

  @override
  String get errorInvalidUrlFormat => 'Ogiltigt URL-format';

  @override
  String get errorUrlMissingScheme =>
      'URL måste inkludera http:// eller https://';

  @override
  String get errorUrlUnsupportedScheme => 'Endast HTTP- och HTTPS-URL:er stöds';

  @override
  String get errorUrlMissingDomain => 'URL måste inkludera ett domännamn';

  @override
  String get errorUrlPrivateAddress =>
      'URL:en pekar på en privat eller reserverad adress och kan inte användas';

  @override
  String errorInvalidCategoryName(String name) {
    return 'Ogiltigt kategorinamn: $name';
  }

  @override
  String get platformYouTube => 'YouTube-video';

  @override
  String get platformTikTok => 'TikTok-video';

  @override
  String get platformInstagram => 'Instagram-inlägg';

  @override
  String get platformWebsite => 'Webbsida';

  @override
  String get platformPastedText => 'Inklistrad text';

  @override
  String get selectionNoFriendsSelected => 'Inga vänner valda';

  @override
  String selectionFriendsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vänner valda',
      one: '1 vän vald',
    );
    return '$_temp0';
  }

  @override
  String get selectionNoRecipesSelected => 'Inga recept valda';

  @override
  String selectionRecipesSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept valda',
      one: '1 recept valt',
    );
    return '$_temp0';
  }

  @override
  String get buttonCreating => 'Skapar...';

  @override
  String get buttonCreateAndShare => 'Skapa & Dela';

  @override
  String get analysisNoContentExtracted => 'Inget innehåll extraherat';

  @override
  String get analysisContainsIngredients => 'Innehåller ingredienser';

  @override
  String get analysisNoIngredientsFound => 'Ingen ingredienssektion hittades';

  @override
  String get analysisContainsInstructions => 'Innehåller instruktioner';

  @override
  String get analysisNoInstructionsFound => 'Inga instruktioner hittades';

  @override
  String get labelNoCategories => 'Inga kategorier';

  @override
  String get labelGroup => 'Grupp';

  @override
  String get labelYou => 'Du';

  @override
  String get validationSelectIngredient => 'Välj minst en ingrediens';

  @override
  String get statusListLoaded => 'Lista laddad';

  @override
  String errorCouldNotLoadListDetail(String detail) {
    return 'Kunde inte ladda lista: $detail';
  }

  @override
  String get labelUntitledMenu => 'Namnlös meny';

  @override
  String get labelUntitledList => 'Namnlös lista';

  @override
  String get labelUntitledRecipe => 'Namnlöst recept';

  @override
  String get labelUnknownContent => 'Okänt innehåll';

  @override
  String get analysisContainsTimeInfo => 'Innehåller tidsinformation';

  @override
  String get analysisContainsPortionInfo => 'Innehåller portionsinformation';

  @override
  String get analysisGoodContentLength => 'Bra innehållslängd';

  @override
  String get analysisContentTooShort => 'Innehållet verkar för kort';

  @override
  String get analysisContainsRecipeKeywords => 'Innehåller receptnyckelord';

  @override
  String get hintPasteOrTypeRecipe =>
      'Klistra in eller skriv recepttext för att komma igång';

  @override
  String get errorFriendAlreadyHasAccess =>
      'Den valda vännen har redan tillgång till listan';

  @override
  String get errorAllFriendsAlreadyHaveAccess =>
      'Alla valda vänner har redan tillgång till listan';

  @override
  String shareInvitationsSentWithSkipped(int invitedCount, int skippedCount) {
    return '$invitedCount inbjudningar skickade. $skippedCount vänner hoppades över (har redan tillgång).';
  }

  @override
  String get errorCouldNotSendInvitations => 'Kunde inte skicka inbjudningar';

  @override
  String get shareDefaultShoppingListMessage =>
      'Vill dela denna inköpslista med dig!';

  @override
  String shoppingListAllDone(int count) {
    return 'Alla $count artiklar klara';
  }

  @override
  String shoppingListItemsToBuy(int count) {
    return '$count artiklar att köpa';
  }

  @override
  String get errorDailyQuotaReached => 'Dagskvot uppnådd';

  @override
  String get errorGenericOccurred => 'Ett fel uppstod';

  @override
  String get fcmChannelGeneralTitle => 'Allmänna notiser';

  @override
  String get fcmChannelGeneralDescription => 'Generella notiser från Butlery';

  @override
  String get timeAgoNow => 'Nu';

  @override
  String timeAgoMinutesAbbr(int count) {
    return '$count min sedan';
  }

  @override
  String timeAgoHoursAbbr(int count) {
    return '$count tim sedan';
  }

  @override
  String timeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagar sedan',
      one: '1 dag sedan',
    );
    return '$_temp0';
  }

  @override
  String timeAgoWeeks(int count) {
    return '$count veckor sedan';
  }

  @override
  String get timeAgoJustNow => 'Nyss';

  @override
  String timeAgoMinutesFull(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuter sedan',
      one: '1 minut sedan',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHoursFull(int count) {
    return '$count timmar sedan';
  }

  @override
  String timeCompactMinutes(int count) {
    return '${count}m';
  }

  @override
  String timeCompactHours(int count) {
    return '${count}h';
  }

  @override
  String timeCompactDays(int count) {
    return '${count}d';
  }

  @override
  String get expiresExpired => 'Utgången';

  @override
  String expiresDaysRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagar kvar',
      one: '1 dag kvar',
    );
    return '$_temp0';
  }

  @override
  String expiresHoursRemaining(int count) {
    return '$count timmar kvar';
  }

  @override
  String expiresMinutesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minuter kvar',
      one: '1 minut kvar',
    );
    return '$_temp0';
  }

  @override
  String get expiresSoon => 'Går ut snart';

  @override
  String groupInvitationNotificationWithMessage(
      String sender, String emoji, String group, String message) {
    return '$sender bjöd in dig till gruppen $emoji $group: \"$message\"';
  }

  @override
  String groupInvitationNotificationSimple(
      String sender, String emoji, String group) {
    return '$sender bjöd in dig till gruppen $emoji $group';
  }

  @override
  String get invitationStatusPending => 'Väntande';

  @override
  String get invitationStatusAccepted => 'Accepterad';

  @override
  String get invitationStatusRejected => 'Avvisad';

  @override
  String get invitationStatusCancelled => 'Avbruten';

  @override
  String get invitationStatusExpired => 'Utgången';

  @override
  String get messageContentRecipe => 'Recept';

  @override
  String get messageContentMenu => 'Meny';

  @override
  String get messageContentShoppingList => 'Inköpslista';

  @override
  String get messageContentImage => 'Bild';

  @override
  String get messageContentVoice => 'Röstmeddelande';

  @override
  String get conversationGroupChat => 'Gruppchatt';

  @override
  String get editModeOwner => 'Du äger detta recept';

  @override
  String get editModeCollaborative => 'Du redigerar tillsammans med andra';

  @override
  String get editModeReadOnlyWithFork =>
      'Skrivskyddat - du kan spara din egen kopia';

  @override
  String get editModeNoAccess => 'Ingen åtkomst';

  @override
  String get editModeEdit => 'Redigeringsläge';

  @override
  String get editModeView => 'Visningsläge';

  @override
  String get changeTypeAdded => 'Tillagd';

  @override
  String get changeTypeModified => 'Ändrad';

  @override
  String get changeTypeRemoved => 'Borttagen';

  @override
  String memberSinceDays(int count) {
    return 'Medlem i $count dagar';
  }

  @override
  String memberSinceMonths(int count) {
    return 'Medlem i $count månader';
  }

  @override
  String memberSinceYears(int count) {
    return 'Medlem i $count år';
  }

  @override
  String get commentDeleted => '[Kommentar borttagen]';

  @override
  String get deletedUser => 'Borttagen användare';

  @override
  String sharedMenuTitlePattern(String name) {
    return '${name}s veckomeny';
  }

  @override
  String importedFromMenu(String name, String title) {
    return 'Importerat från ${name}s meny \"$title\"';
  }

  @override
  String get importedRecipeLabel => 'Importerat recept';

  @override
  String get activityCreatedRecipe => 'skapade ett recept';

  @override
  String get activitySharedRecipe => 'delade ett recept';

  @override
  String activityRatedRecipe(int rating) {
    return 'betygsatte ett recept ($rating⭐)';
  }

  @override
  String get activityCommentedRecipe => 'kommenterade ett recept';

  @override
  String activityReactedRecipe(String reaction) {
    return 'reagerade på ett recept ($reaction)';
  }

  @override
  String get activityCreatedMenu => 'skapade en meny';

  @override
  String get activitySharedMenu => 'delade en meny';

  @override
  String get activityCreatedShoppingList => 'skapade en inköpslista';

  @override
  String get activitySharedShoppingList => 'delade en inköpslista';

  @override
  String get activityJoinedGroup => 'gick med i en grupp';

  @override
  String activityUnlockedAchievement(String achievement) {
    return 'låste upp en bedrift: $achievement';
  }

  @override
  String get activityDidSomething => 'gjorde något';

  @override
  String get labelEmptyMenu => 'Tom meny';

  @override
  String get labelMultipleChanges => 'Flera ändringar';

  @override
  String get errorVideoNoSubtitles => 'Video saknar undertexter';

  @override
  String get errorNetworkFallback => 'Nätverksfel';

  @override
  String get recipeCollaborationEnable => 'Aktivera samarbete';

  @override
  String get recipeCollaborationDisable => 'Avaktivera samarbete';

  @override
  String get menuCommentDeletedSuccess => 'Kommentaren borttagen';

  @override
  String get recipeSharingStatus => 'Delningsstatus';

  @override
  String get recipeSharingStopAll => 'Sluta dela med alla';

  @override
  String get recipeSharingStopAllConfirm =>
      'Är du säker på att du vill sluta dela med alla?';

  @override
  String get recipeSharingStopAllSuccess => 'Delning avslutad med alla';

  @override
  String get recipeSharingRevoke => 'Ta bort delning';

  @override
  String recipeSharingRevokeConfirm(String name) {
    return 'Sluta dela med $name?';
  }

  @override
  String recipeSharingRevokeSuccess(String name) {
    return 'Delning med $name avslutad';
  }

  @override
  String get recipeSharingFriends => 'Vänner';

  @override
  String get recipeSharingGroups => 'Grupper';

  @override
  String get menuRatingRemoveTitle => 'Ta bort betyg?';

  @override
  String get menuRatingRemoveMessage => 'Vill du ta bort ditt betyg?';

  @override
  String get menuRatingRemoveConfirm => 'Ta bort';

  @override
  String get menuRatingRemoveButton => 'Ta bort betyg';

  @override
  String get menuRatingRemoved => 'Betyget borttaget';

  @override
  String get menuRatingRemoveError => 'Kunde inte ta bort betyg';

  @override
  String get shoppingTemplates => 'Inköpsmallar';

  @override
  String get shoppingTemplateBrowse => 'Visa mallar';

  @override
  String get shoppingTemplateEmpty => 'Inga sparade mallar';

  @override
  String get shoppingTemplateEmptyDescription =>
      'Spara en inköpslista som mall för snabb återskapning';

  @override
  String get shoppingTemplateUse => 'Använd mall';

  @override
  String get shoppingTemplateDelete => 'Ta bort mall';

  @override
  String get shoppingTemplateDeleted => 'Mall borttagen';

  @override
  String get shoppingTemplateCreated => 'Lista skapad från mall';

  @override
  String shoppingTemplateItemCount(int count) {
    return '$count varor';
  }

  @override
  String shoppingTemplateUsedCount(int count) {
    return 'Använd $count gånger';
  }

  @override
  String get labelButleryUser => 'Butlery-användare';

  @override
  String get shoppingListSummaryEmpty => 'Tom handlingslista';

  @override
  String shoppingListSummaryAllDone(int count) {
    return 'Alla $count artiklar klara';
  }

  @override
  String shoppingListSummaryToBuy(int count) {
    return '$count artiklar att köpa';
  }

  @override
  String shoppingListSummaryRemaining(int remaining, int total) {
    return '$remaining av $total artiklar kvar';
  }

  @override
  String notificationBatchComments(int count) {
    return '$count nya kommentarer på dina recept';
  }

  @override
  String notificationCommentSingle(String author, String recipe) {
    return '$author kommenterade på \"$recipe\"';
  }

  @override
  String notificationCommentMultipleSameAuthor(
      String author, int count, String recipe) {
    return '$author skrev $count kommentarer på \"$recipe\"';
  }

  @override
  String notificationCommentMultipleAuthors(
      int authorCount, int commentCount, String recipe) {
    return '$authorCount personer skrev $commentCount kommentarer på \"$recipe\"';
  }

  @override
  String notificationRatingSingle(String recipe, int count, String period) {
    return 'Ditt recept \"$recipe\" fick $count nya betyg denna $period!';
  }

  @override
  String notificationRatingMultiple(
      int totalRatings, int recipeCount, String period) {
    return 'Dina recept fick totalt $totalRatings nya betyg på $recipeCount recept denna $period!';
  }

  @override
  String timeCompactMonths(int count) {
    return '${count}mån';
  }

  @override
  String validationFieldCannotBeEmpty(String fieldName) {
    return '$fieldName får inte vara tom';
  }

  @override
  String validationMustBeNumber(String fieldName) {
    return '$fieldName måste vara ett nummer';
  }

  @override
  String validationMinValue(String fieldName, String min) {
    return '$fieldName måste vara minst $min';
  }

  @override
  String validationMaxValue(String fieldName, String max) {
    return '$fieldName får vara max $max';
  }

  @override
  String get validationDefaultValueLabel => 'Värdet';

  @override
  String get validationInvalidUrlHint =>
      'Ange en giltig URL (börja med http:// eller https://)';

  @override
  String get validationFieldRating => 'Betyg';

  @override
  String get validationFieldPortions => 'Antal portioner';

  @override
  String get validationFieldCookingTime => 'Tillagningstid';

  @override
  String get validationDisplayNameEmpty => 'Visningsnamn får inte vara tomt';

  @override
  String get validationDisplayNameTooShort =>
      'Visningsnamn måste vara minst 2 tecken';

  @override
  String get validationDisplayNameTooLong =>
      'Visningsnamn får vara max 30 tecken';

  @override
  String get validationDisplayNameInvalidChars =>
      'Visningsnamn får bara innehålla bokstäver, siffror, mellanslag och - _ .';

  @override
  String get validationDisplayNameNoLetters =>
      'Visningsnamn måste innehålla minst en bokstav eller siffra';

  @override
  String get validationDisplayNameNoSpaces =>
      'Visningsnamn får inte börja eller sluta med mellanslag';

  @override
  String get validationCommentEmpty => 'Kommentar får inte vara tom';

  @override
  String get validationCommentTooShort => 'Kommentar måste vara minst 3 tecken';

  @override
  String get validationCommentTooLong => 'Kommentar får vara max 500 tecken';

  @override
  String validationMessageMaxLength(int max) {
    return 'Meddelande får vara max $max tecken';
  }

  @override
  String get validationNameTooShort => 'Namnet måste vara minst 2 tecken';

  @override
  String get validationEmailInvalidHint => 'Ange en giltig e-postadress';

  @override
  String get validationShoppingItemRequired => 'Ange artikelnamn';

  @override
  String get validationAmountRequired => 'Ange antal';

  @override
  String get validationTagMinLength => 'Varje tagg måste vara minst 2 tecken';

  @override
  String get validationTagMaxLength => 'Varje tagg får vara max 20 tecken';

  @override
  String validationFieldNotEmpty(String fieldName) {
    return '$fieldName får inte vara tomt';
  }

  @override
  String get validationPasswordMinEight =>
      'Lösenordet måste vara minst 8 tecken';

  @override
  String get validationPasswordNeedsUppercase =>
      'Lösenordet måste innehålla minst en stor bokstav';

  @override
  String get validationPasswordNeedsLowercase =>
      'Lösenordet måste innehålla minst en liten bokstav';

  @override
  String get validationPasswordNeedsDigit =>
      'Lösenordet måste innehålla minst en siffra';

  @override
  String get validationDisplayNameLabel => 'Visningsnamn';

  @override
  String get validationCommentLabel => 'Kommentar';

  @override
  String get validationAmountMustBePositive =>
      'Antal måste vara ett positivt nummer';

  @override
  String get validationUserIdRequired =>
      'Användar-ID krävs för denna operation';

  @override
  String get validationFieldRecipeName => 'Receptnamn';

  @override
  String get validationFieldGroupName => 'Gruppnamn';

  @override
  String get validationFieldArticle => 'Artikel';

  @override
  String errorImageUploadFailed(String message) {
    return 'Bilduppladdning misslyckades: $message';
  }

  @override
  String errorRecipeServiceFailed(String message) {
    return 'Recepthantering misslyckades: $message';
  }

  @override
  String errorPermissionFailed(String message) {
    return 'Behörighetsfel: $message';
  }

  @override
  String errorNetworkWithDetail(String message) {
    return 'Nätverksfel: $message';
  }

  @override
  String errorStorageFailed(String message) {
    return 'Lagringsfel: $message';
  }

  @override
  String errorCollaborationFailed(String message) {
    return 'Samarbetsfel: $message';
  }

  @override
  String errorAutoSaveFailed(String message) {
    return 'Autosparning misslyckades: $message';
  }

  @override
  String errorSystemFailed(String message) {
    return 'Systemfel: $message';
  }

  @override
  String get actionRefresh => 'Uppdatera';

  @override
  String get actionGoBack => 'Gå tillbaka';

  @override
  String get actionReport => 'Rapportera';

  @override
  String get shareIngredientsLabel => 'Ingredienser:';

  @override
  String get shareInstructionsLabel => 'Gör så här:';

  @override
  String get shareSourceLabel => 'Källa:';

  @override
  String get sharePortionsUnit => 'portioner';

  @override
  String get shareMinutesUnit => 'minuter';

  @override
  String uploadNotificationTitle(int percentage) {
    return 'Uppladdning $percentage% klar';
  }

  @override
  String uploadNotificationMessage(int percentage) {
    return 'Bilduppladdning gör framsteg - $percentage% slutförd';
  }

  @override
  String get feedbackDescriptionRequired => 'Ange en beskrivning';

  @override
  String get feedbackThanks => 'Tack för din feedback!';

  @override
  String get feedbackSendFailed => 'Kunde inte skicka feedback. Försök igen.';

  @override
  String get tooltipRemoveOption => 'Ta bort alternativ';

  @override
  String get personalTagCouldNotShare => 'Kunde inte dela taggen';

  @override
  String get reactionThumbsUp => 'Tummen upp';

  @override
  String get reactionHeart => 'Hjärta';

  @override
  String get reactionFire => 'Eld';

  @override
  String get reactionLaughing => 'Skratt';

  @override
  String get reactionYum => 'Gott';

  @override
  String get reactionThinking => 'Funderar';

  @override
  String menuCompletionPercent(int percentage) {
    return '$percentage% färdig';
  }

  @override
  String networkErrorNoConnection(String operation) {
    return 'Ingen internetanslutning. $operation kommer att sparas lokalt och synkroniseras när du är online igen.';
  }

  @override
  String networkErrorNoConnectionShort(String operation) {
    return 'Ingen internetanslutning för $operation.';
  }

  @override
  String networkErrorMobileData(String operation) {
    return 'Använder mobildata för $operation. Detta kan ta längre tid eller påverka din dataförbrukning.';
  }

  @override
  String networkErrorMobileShort(String operation) {
    return 'Mobilanslutning för $operation.';
  }

  @override
  String networkErrorLimited(String operation) {
    return 'Begränsad anslutning upptäckt. $operation kan ta längre tid eller sparas lokalt.';
  }

  @override
  String networkErrorLimitedShort(String operation) {
    return 'Begränsad anslutning för $operation.';
  }

  @override
  String networkErrorDefault(String operation) {
    return 'Nätverket svek under $operation. Kontrollera anslutningen och försök åter.';
  }

  @override
  String permissionErrorAction(String action, String resource) {
    return 'Du kan inte $action detta $resource';
  }

  @override
  String permissionErrorBecause(String reason) {
    return 'eftersom $reason';
  }

  @override
  String permissionErrorSuggestion(String suggestion) {
    return 'Förslag: $suggestion';
  }

  @override
  String errorDuringAction(String action, String issue) {
    return 'Problem medan $action: $issue';
  }

  @override
  String errorDuringActionRecovery(
      String action, String issue, String recovery) {
    return 'Problem medan $action: $issue\n\nFörslag: $recovery';
  }

  @override
  String get formatPortionSingle => '1 portion';

  @override
  String formatPortionPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portioner',
      one: '1 portion',
    );
    return '$_temp0';
  }

  @override
  String validationFailedWith(String error) {
    return 'Validering misslyckades: $error';
  }

  @override
  String get snackbarNoInternet =>
      'Ingen internetanslutning. Kontrollera din anslutning.';

  @override
  String get errorInvalidYoutubeUrl => 'Ogiltig YouTube-URL';

  @override
  String get errorInvalidInstructionIndex => 'Ogiltiga instruktions-index';

  @override
  String get errorInvalidIngredientIndex => 'Ogiltiga ingrediens-index';

  @override
  String errorInvalidCategoryNamesFromTo(
      String fromCategory, String toCategory) {
    return 'Ogiltiga kategorinamn: $fromCategory -> $toCategory';
  }

  @override
  String get validationTitleMissing => 'Titel saknas';

  @override
  String get validationIngredientsMissing => 'Ingredienser saknas';

  @override
  String get validationInstructionsMissing => 'Instruktioner saknas';

  @override
  String get validationMealTypeMissing => 'Måltidstyp saknas';

  @override
  String get shareMinutesAbbrev => 'min';

  @override
  String get sharePortionsAbbrev => 'port';

  @override
  String get shareTimeLabel => 'Tid:';

  @override
  String get shareTimeLabelBold => '**Tid:**';

  @override
  String get sharePortionsLabel => 'Portioner:';

  @override
  String get sharePortionsLabelBold => '**Portioner:**';

  @override
  String get shareRatingLabel => 'Betyg:';

  @override
  String get shareRatingLabelBold => '**Betyg:**';

  @override
  String get shareTypeLabel => 'Typ:';

  @override
  String get shareTypeLabelBold => '**Typ:**';

  @override
  String get shareTagsLabel => 'Tags';

  @override
  String get shareInstructionsLabelCompact => 'Instruktioner:';

  @override
  String get shareShoppingListTitleSimple => 'Inköpslista';

  @override
  String get shareWeekMenuTitle => 'Veckomeny';

  @override
  String get shareWeekMenuTitleEmoji => '🍽 VECKOMENY';

  @override
  String get shareSummaryLabel => '📊 Sammanfattning:';

  @override
  String shareSummaryRecipesInCategories(int recipeCount, int categoryCount) {
    return '$recipeCount recept i $categoryCount kategorier';
  }

  @override
  String get unsavedChangesTitle => 'Osparade ändringar';

  @override
  String get unsavedChangesMessage =>
      'Du har osparade ändringar. Vill du verkligen avbryta?';

  @override
  String get cancelWithoutSaving => 'Avbryt utan att spara';

  @override
  String get deleteActionIrreversible => 'Denna åtgärd kan inte ångras.';

  @override
  String get deleteConfirmMessage => 'Vill du verkligen ta bort';

  @override
  String get groupLeaveTitle => 'Lämna grupp?';

  @override
  String groupLeaveMessage(String name) {
    return 'Vill du verkligen lämna gruppen \"$name\"?';
  }

  @override
  String get groupLeaveAction => 'Lämna grupp';

  @override
  String shareItemTitle(String type) {
    return 'Dela $type?';
  }

  @override
  String shareItemMessage(String type, String recipients) {
    return 'Vill du dela $type med $recipients?';
  }

  @override
  String shareRecipientsMore(int count) {
    return 'och $count till';
  }

  @override
  String get recipeDeleteWarning => 'Receptet kommer att tas bort permanent.';

  @override
  String get shoppingListDeleteWarning =>
      'Alla varor på listan kommer att försvinna.';

  @override
  String itemDeletedSuccess(String type) {
    return '$type har tagits bort';
  }

  @override
  String itemDeleteError(String type) {
    return 'Kunde inte ta bort $type';
  }

  @override
  String get commentDeleteError => 'Kunde inte ta bort kommentaren';

  @override
  String get commentEditHint => 'Redigera din kommentar';

  @override
  String get commentEditError => 'Kunde inte uppdatera kommentaren';

  @override
  String get commentEdited => 'Kommentar uppdaterad';

  @override
  String get commentReact => 'Reagera';

  @override
  String get reactionUpdateError => 'Kunde inte uppdatera reaktion';

  @override
  String get activityRecipeCreated => '👨‍🍳 Recept skapat';

  @override
  String get activityMenuCreated => '📋 Meny skapad';

  @override
  String get activityShoppingListCreated => '🛒 Inköpslista skapad';

  @override
  String get activityRecipeShared => '📤 Recept delat';

  @override
  String get activityMenuShared => '📤 Meny delad';

  @override
  String get activityShoppingListShared => '📤 Inköpslista delad';

  @override
  String get activityCommentAdded => '💬 Kommentar';

  @override
  String get activityReactionAdded => '❤️ Reaktion';

  @override
  String get activityRecipeRated => '⭐ Betyg';

  @override
  String get activityGroupJoined => '👥 Gick med i grupp';

  @override
  String get activityInvitationSent => '📩 Inbjudan skickad';

  @override
  String get activityInvitationAccepted => '✅ Inbjudan accepterad';

  @override
  String get activityAchievementUnlocked => '🏆 Bedrift';

  @override
  String get activityMilestoneReached => '🎯 Milstolpe';

  @override
  String get activityUnknown => '❓ Okänd aktivitet';

  @override
  String get pollVoteSingular => 'röst';

  @override
  String get pollVotePlural => 'röster';

  @override
  String get pollClosed => 'Avslutad';

  @override
  String get pollCloseAction => 'Stäng omröstning';

  @override
  String get chatGroupChatDefault => 'Gruppchatt';

  @override
  String chatGroupCreatedMessage(String name, String title) {
    return '$name skapade gruppen \"$title\"';
  }

  @override
  String chatParticipantAdded(String name) {
    return '$name har lagts till i gruppen';
  }

  @override
  String chatParticipantLeft(String name) {
    return '$name har lämnat gruppen';
  }

  @override
  String get authRequiredError => 'Du måste vara inloggad';

  @override
  String get shoppingListEditPermissionDenied =>
      'Du har inte behörighet att redigera denna delade inköpslista';

  @override
  String get tagShareError => 'Kunde inte dela taggen';

  @override
  String get userStatusOffline => 'Offline';

  @override
  String get userStatusAway => 'Borta';

  @override
  String get userStatusBusy => 'Upptagen';

  @override
  String participantsCount(int count) {
    return 'Deltagare ($count)';
  }

  @override
  String participantsOnlineCount(int count) {
    return '$count online';
  }

  @override
  String get restoreDraft => 'Återställ';

  @override
  String fieldsFilledCount(int count) {
    return '$count fält ifyllda';
  }

  @override
  String get noFriends => 'Du har inga vänner än.';

  @override
  String get noRecipes => 'Du har inga recept än.';

  @override
  String get addRecipe => 'Lägg till recept';

  @override
  String get editRecipe => 'Redigera recept';

  @override
  String get checkPermissions => 'Kontrollera behörigheter';

  @override
  String get ingredientParseError => 'Kunde inte tolka ingrediens';

  @override
  String get portionsUnit => 'portioner';

  @override
  String sharedRecipeFallback(int count) {
    return 'Delat recept • $count medlemmar';
  }

  @override
  String sharedMenuFallback(int count) {
    return 'Delad meny • $count medlemmar';
  }

  @override
  String get sharedFallback => 'Delat';

  @override
  String get accountSecurityTitle => 'Kontosäkerhet';

  @override
  String get accountSecurityChangePassword => 'Byt lösenord';

  @override
  String get accountSecurityChangeEmail => 'Byt e-postadress';

  @override
  String get accountSecurityCurrentPassword => 'Nuvarande lösenord';

  @override
  String get accountSecurityNewPassword => 'Nytt lösenord';

  @override
  String get accountSecurityConfirmPassword => 'Bekräfta lösenord';

  @override
  String get accountSecurityNewEmail => 'Ny e-postadress';

  @override
  String get accountSecurityMfaSettings => 'Tvåfaktorsautentisering';

  @override
  String get accountSecurityPasswordChanged => 'Lösenordet har ändrats';

  @override
  String get accountSecurityEmailVerificationSent =>
      'Verifieringslänk skickad till ny e-postadress';

  @override
  String get accountSecurityPasswordMismatch => 'Lösenorden matchar inte';

  @override
  String get profileAccountSecurity => 'Kontosäkerhet';

  @override
  String get profileAccountSecuritySubtitle =>
      'Lösenord, e-post och tvåfaktorsautentisering';

  @override
  String bulkSelectedCount(int count) {
    return '$count valda';
  }

  @override
  String get bulkSelectAll => 'Välj alla';

  @override
  String get bulkCancelSelection => 'Avbryt val';

  @override
  String get bulkDelete => 'Ta bort valda';

  @override
  String get bulkShare => 'Dela valda';

  @override
  String get bulkTag => 'Tagga valda';

  @override
  String bulkTagDialogTitle(int count) {
    return 'Lägg till tagg på $count recept';
  }

  @override
  String get bulkTagNoTagsAvailable => 'Inga personliga taggar att välja';

  @override
  String bulkTagSuccess(int count) {
    return 'Taggen lades till på $count recept';
  }

  @override
  String get bulkTagAllAlreadyTagged =>
      'Alla valda recept har redan denna tagg';

  @override
  String get viewModeGrid => 'Rutnätsvy';

  @override
  String get viewModeList => 'Listvy';

  @override
  String get duplicateImportTitle => 'Receptet kan redan finnas';

  @override
  String duplicateImportMessage(String recipeName) {
    return 'Ett recept med samma källa finns redan: $recipeName';
  }

  @override
  String get duplicateImportViewExisting => 'Visa befintligt';

  @override
  String get duplicateImportAnyway => 'Importera ändå';

  @override
  String get imageCropTitle => 'Beskär bild';

  @override
  String get bulkDeleteConfirmMessage =>
      'De valda recepten kommer att tas bort.';

  @override
  String bulkDeleteSuccess(int count) {
    return '$count recept borttagna';
  }

  @override
  String get profileFaq => 'Vanliga frågor';

  @override
  String get profileFaqSubtitle => 'Hjälp och svar på vanliga frågor';

  @override
  String get sharedWithYou => 'Delade med dig';

  @override
  String get importTag => 'Importera';

  @override
  String get tagImportedSuccess => 'Taggen importerades';

  @override
  String get legalTermsOfService => 'Användarvillkor';

  @override
  String get legalCommunityGuidelines => 'Gemenskapsriktlinjer';

  @override
  String get legalOpenSourceLicenses => 'Öppen källkod-licenser';

  @override
  String get authAgeConfirmation => 'Jag bekräftar att jag är minst 13 år';

  @override
  String get authAgeConfirmationRequired =>
      'Du måste bekräfta din ålder för att skapa ett konto';

  @override
  String get authTermsAcceptPrefix => 'Jag accepterar ';

  @override
  String get authTermsAcceptMiddle => ' och ';

  @override
  String get authTermsAcceptRequired =>
      'Du måste acceptera villkoren för att skapa ett konto';

  @override
  String get reportContent => 'Rapportera';

  @override
  String get reportReasonInappropriate => 'Olämpligt innehåll';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonHarassment => 'Trakasseri';

  @override
  String get reportReasonCopyright => 'Upphovsrättsintrång';

  @override
  String get reportReasonOther => 'Annat';

  @override
  String get reportDescriptionHint => 'Beskriv vad som är fel (valfritt)';

  @override
  String get reportSubmitted => 'Rapporten har skickats';

  @override
  String get reportSubmitFailed => 'Kunde inte skicka rapporten';

  @override
  String get reportDialogTitle => 'Rapportera innehåll';

  @override
  String get reportSubmit => 'Skicka rapport';

  @override
  String get reportDialogGuidelinesNotePrefix =>
      'Genom att rapportera bekräftar du att innehållet bryter mot';

  @override
  String get reportDialogGuidelinesLink => 'våra riktlinjer för communityn';

  @override
  String get settingsMyReports => 'Mina rapporter';

  @override
  String get myReportsTitle => 'Mina rapporter';

  @override
  String get myReportsEmpty => 'Du har inte skickat in några rapporter än.';

  @override
  String get myReportsStatusPending => 'Inkommen';

  @override
  String get myReportsStatusReviewed => 'Granskad';

  @override
  String get myReportsStatusActioned => 'Åtgärdad';

  @override
  String get myReportsStatusClosed => 'Avslutad';

  @override
  String get myReportsLoadFailed => 'Kunde inte hämta rapporter';

  @override
  String get myReportsRetry => 'Försök igen';

  @override
  String get newAccountSocialBlocked =>
      'Bekräfta din e-post för att lägga till vänner';

  @override
  String get newAccountSocialBlockedAction => 'Skicka bekräftelse';

  @override
  String get duplicateContentRejected =>
      'Du har precis skickat samma meddelande.';

  @override
  String get contentFilterWarning =>
      'Texten innehåller olämpligt språk. Vänligen redigera innan du skickar.';

  @override
  String get noResults => 'Inga resultat';

  @override
  String allergenCoverageLabel(int coverage) {
    return '$coverage% täckning';
  }

  @override
  String get ingredientDataUnverified => 'Viss ingrediensdata är ej verifierad';

  @override
  String get recipeStartCookingTooltip => 'Börja laga';

  @override
  String get taggingDegradedWarning =>
      'Allergen- och kostdata kan vara opålitlig';

  @override
  String get recipeEditTags => 'Redigera taggar';

  @override
  String get allergenDisclaimer =>
      'Allergeninformation baseras på automatisk analys och är endast vägledande. Kontrollera alltid originalreceptet och produktförpackningar. Ersätter inte medicinsk rådgivning.';

  @override
  String allergenToggleSemantics(String allergen) {
    return 'Växla spårning av $allergen';
  }

  @override
  String dietaryToggleSemantics(String dietary) {
    return 'Växla kostpreferens $dietary';
  }

  @override
  String get emailVerificationTitle => 'Verifiera din e-post';

  @override
  String emailVerificationMessage(String email) {
    return 'Vi har skickat ett verifieringsmail till $email.';
  }

  @override
  String get emailVerificationResend => 'Skicka igen';

  @override
  String get emailVerificationContinue => 'Fortsätt ändå';

  @override
  String get emailVerificationSuccess => 'E-post verifierad!';

  @override
  String get a11yCookingModeFontScale => 'Ändra textstorlek';

  @override
  String get a11yCookingModeClose => 'Stäng tillagningsläge';

  @override
  String a11yCookingModeIngredient(String ingredient) {
    return '$ingredient';
  }

  @override
  String a11yCookingModeStep(int step, String instruction) {
    return 'Steg $step: $instruction';
  }

  @override
  String get tooltipShowPassword => 'Visa lösenord';

  @override
  String get tooltipHidePassword => 'Dölj lösenord';

  @override
  String get tooltipSendMessage => 'Skicka meddelande';

  @override
  String get tooltipAttachImage => 'Bifoga bild';

  @override
  String get tooltipAttachFile => 'Bifoga fil';

  @override
  String get tooltipCreatePoll => 'Skapa omröstning';

  @override
  String get tooltipSelectedImage => 'Vald bild';

  @override
  String get statsMyStatistics => 'Min statistik';

  @override
  String get statsRecipeCollection => 'Receptsamling';

  @override
  String get statsTotalRecipes => 'Totalt recept';

  @override
  String get statsFavorites => 'Favoriter';

  @override
  String get statsRecentlyCooked => 'Nyligen lagat';

  @override
  String get statsWithImages => 'Med bilder';

  @override
  String get statsPersonalRecipes => 'Egna recept';

  @override
  String get statsCollaborativeRecipes => 'Delade recept';

  @override
  String get statsHighRated => 'Högt betyg';

  @override
  String get statsMealTypes => 'Måltidstyper';

  @override
  String get statsPopularTags => 'Populära taggar';

  @override
  String get statsCookingActivity => 'Matlagningsaktivitet';

  @override
  String get statsTotalCooks => 'Totalt antal tillagningar';

  @override
  String get statsNoMealTypes => 'Inga måltidstyper registrerade';

  @override
  String get statsNoTags => 'Inga taggar använda än';

  @override
  String get statsDistinctMealTypes => 'Måltidstyper';

  @override
  String get statsDistinctTags => 'Taggar';

  @override
  String get importPendingRetryPrompt =>
      'Du har en väntande import — försök igen?';

  @override
  String get importPendingRetry => 'Försök igen';

  @override
  String get importPendingDismiss => 'Avfärda';

  @override
  String get importSavedForLater =>
      'URL sparad — importeras när du är online igen';

  @override
  String get seasonalForgottenFavorites => 'Glömda favoriter';

  @override
  String seasonalHeroTitle(String month) {
    return 'just nu i säsong · $month';
  }

  @override
  String seasonalHeroRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept',
      one: '1 recept',
    );
    return '$_temp0';
  }

  @override
  String get seasonalMonthJanuary => 'januari';

  @override
  String get seasonalMonthFebruary => 'februari';

  @override
  String get seasonalMonthMarch => 'mars';

  @override
  String get seasonalMonthApril => 'april';

  @override
  String get seasonalMonthMay => 'maj';

  @override
  String get seasonalMonthJune => 'juni';

  @override
  String get seasonalMonthJuly => 'juli';

  @override
  String get seasonalMonthAugust => 'augusti';

  @override
  String get seasonalMonthSeptember => 'september';

  @override
  String get seasonalMonthOctober => 'oktober';

  @override
  String get seasonalMonthNovember => 'november';

  @override
  String get seasonalMonthDecember => 'december';

  @override
  String get dormantRecipesTitle => 'Prova något du sparat';

  @override
  String get emptyStateNewUserTitle => 'Välkommen. Butlery står redo.';

  @override
  String get emptyStateNewUserDescription =>
      'Första receptet kan importeras från en webbadress, eller föras in manuellt.';

  @override
  String get emptyStateNewUserWithPrefs =>
      'Vi har dina kostpreferenser redo. Importera ditt första recept så filtrerar vi åt dig!';

  @override
  String get emptyStateImportAction => 'Importera via länk';

  @override
  String get emptyStateOtherOptions => 'Övriga alternativ';

  @override
  String get cookingModePreviousStep => 'Föregående steg';

  @override
  String get cookingModeNextStep => 'Nästa steg';

  @override
  String cookingModeStepOf(int current, int total) {
    return 'Steg $current av $total';
  }

  @override
  String cookingModeStepAnnounce(int step, String instruction) {
    return 'Steg $step: $instruction';
  }

  @override
  String get quickCaptureTitle => 'Snabbspara recept';

  @override
  String get quickCaptureSubtitle =>
      'Bara namn och måltid — fyll i resten senare';

  @override
  String get quickCaptureSave => 'Spara';

  @override
  String get quickCaptureSaved => 'Recept sparat!';

  @override
  String get quickCaptureEditAction => 'Redigera';

  @override
  String get quickCaptureTitleHint => 'Vad heter receptet?';

  @override
  String get a11ySwipeEditAction => 'Redigera recept';

  @override
  String get a11ySwipeDeleteAction => 'Ta bort recept';

  @override
  String a11yRecipeSelected(String title) {
    return '$title, markerad';
  }

  @override
  String a11yRecipeNotSelected(String title) {
    return '$title, ej markerad';
  }

  @override
  String get recipeImproveTitle => 'Förbättra detta recept';

  @override
  String get recipeImproveMissingTitle => 'Titel';

  @override
  String get recipeImproveMissingIngredients => 'Ingredienser';

  @override
  String get recipeImproveMissingInstructions => 'Instruktioner';

  @override
  String get recipeImproveMissingPortions => 'Portioner';

  @override
  String get recipeImproveMissingTime => 'Tillagningstid';

  @override
  String get recipeImproveMissingImage => 'Bild';

  @override
  String recipeCompleteness(int score) {
    return '$score% komplett';
  }

  @override
  String recipeCompletenessA11y(int score) {
    return 'Receptet är $score procent komplett';
  }

  @override
  String get pwaInstallPrompt =>
      'Installera Butlery på din hemskärm för snabbare åtkomst';

  @override
  String get pwaInstallAction => 'Installera';

  @override
  String duplicateMergeSimilarity(int percent) {
    return '$percent% likhet';
  }

  @override
  String get duplicateMergeExisting => 'Befintligt';

  @override
  String get duplicateMergeNew => 'Nytt';

  @override
  String get duplicateMergeTitle => 'Dubblettrecept hittat';

  @override
  String get duplicateMergeFieldTitle => 'Titel';

  @override
  String get duplicateMergeFieldTime => 'Tid';

  @override
  String get duplicateMergeFieldPortions => 'Portioner';

  @override
  String get duplicateMergeFieldIngredients => 'Ingredienser';

  @override
  String get duplicateMergeFieldSteps => 'Steg';

  @override
  String get duplicateMergeFieldSource => 'Källa';

  @override
  String get duplicateMergeFieldImage => 'Bild';

  @override
  String get duplicateMergeKeepExisting => 'Behåll befintligt';

  @override
  String get duplicateMergeReplaceWithNew => 'Ersätt med nytt';

  @override
  String get duplicateMergeSaveAsNew => 'Spara som nytt';

  @override
  String get duplicateMergeBestFields => 'Slå ihop bästa fält';

  @override
  String get duplicateMergeSuccess => 'Receptet har sammanfogats';

  @override
  String get duplicateMergeNoTime => 'Ingen tid';

  @override
  String duplicateMergeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String duplicateMergeItemCount(int count) {
    return '$count st';
  }

  @override
  String get duplicateMergeNoSource => 'Ingen källa';

  @override
  String get duplicateMergeNoImage => 'Ingen bild';

  @override
  String menuSwapAlternatives(int count) {
    return '$count alternativ kvar';
  }

  @override
  String get menuSwapExhausted =>
      'Inga fler alternativ som matchar dina preferenser';

  @override
  String get menuSuggestionFavorites => 'Veckomeny från favoriter';

  @override
  String get menuSuggestionRecent => 'Meny med senaste recept';

  @override
  String get publicProfileTitle => 'Profil';

  @override
  String get publicProfileEmpty => 'Denna användare har inga publika recept';

  @override
  String get publicProfileError => 'Profilen hittades inte';

  @override
  String get publicProfileShareButton => 'Dela profil';

  @override
  String get publicProfilePublicRecipes => 'Publika recept';

  @override
  String get statsCompleteness => 'Receptkvalitet';

  @override
  String get statsWithoutPhoto => 'Utan foto';

  @override
  String get statsWithoutTime => 'Utan tid';

  @override
  String get statsIncomplete => 'Ofullständiga';

  @override
  String get statsAllComplete => 'Alla recept är kompletta!';

  @override
  String get notificationsTitle => 'Aviseringar';

  @override
  String get notificationsEmpty => 'Inga aviseringar än';

  @override
  String get notificationsErrorLoad => 'Kunde inte ladda aviseringar';

  @override
  String get allergenIncludeUnknownTitle => 'Visa okänd allergenstatus';

  @override
  String get allergenIncludeUnknownSubtitle =>
      'Inkludera recept med okänd allergenstatus i menyförslag';

  @override
  String get tagDecisionWhyTitle => 'Varför denna tagg?';

  @override
  String get tagDecisionReason => 'Orsak';

  @override
  String get tagDecisionIngredients => 'Ingredienser';

  @override
  String get cookSnapSectionTitle => 'Lagade detta';

  @override
  String cookSnapSectionTitleCount(int count) {
    return 'Lagade detta ($count)';
  }

  @override
  String get cookSnapAddTooltip => 'Lägg till matfoto';

  @override
  String get cookSnapEmptyTitle => 'Ingen har lagat detta än';

  @override
  String get cookSnapEmptySubtitle => 'Bli först!';

  @override
  String get cookSnapFromCamera => 'Ta foto';

  @override
  String get cookSnapFromGallery => 'Välj från galleri';

  @override
  String get cookSnapMe => 'Mig';

  @override
  String get cookSnapErrorLoad => 'Kunde inte ladda foton';

  @override
  String get cookSnapErrorUpload => 'Kunde inte ladda upp foto';

  @override
  String get cookSnapErrorDelete => 'Kunde inte ta bort foto';

  @override
  String get cookSnapDelete => 'Ta bort foto';

  @override
  String get cookSnapReport => 'Rapportera foto';

  @override
  String get collectionInsightsTitle => 'Min samling';

  @override
  String get collectionInsightsInsufficientData =>
      'Lägg till fler recept för att se mönster';

  @override
  String get collectionInsightsTopCuisines => 'Topkök';

  @override
  String get collectionInsightsDietaryVegetarian => 'vegetariskt';

  @override
  String get collectionInsightsDietaryVegan => 'veganskt';

  @override
  String get collectionInsightsDietaryPescetarian => 'pescetarianskt';

  @override
  String personalTagUnusedTags(int count) {
    return 'Oanvända taggar ($count)';
  }

  @override
  String get personalTagDeleteAllUnused => 'Radera alla oanvända';

  @override
  String get personalTagDeleteAllUnusedConfirm => 'Radera oanvända taggar?';

  @override
  String personalTagDeleteAllUnusedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taggar utan recept kommer att tas bort.',
      one: '1 tagg utan recept kommer att tas bort.',
    );
    return '$_temp0';
  }

  @override
  String personalTagUnusedDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count oanvända taggar borttagna',
      one: '1 oanvänd tagg borttagen',
    );
    return '$_temp0';
  }

  @override
  String get weeklyMenuToggleList => 'Lista';

  @override
  String get weeklyMenuToggleCalendar => 'Kalender';

  @override
  String get weeklyMenuPrevWeek => 'Föregående vecka';

  @override
  String get weeklyMenuNextWeek => 'Nästa vecka';

  @override
  String get weeklyMenuTodayBadge => 'Idag';

  @override
  String get weeklyMenuEmptyTitle => 'Ingen planering än';

  @override
  String get weeklyMenuEmptyHint =>
      'Skapa en veckomeny från prompten ovan så fyller vi i dagarna åt dig.';

  @override
  String get weeklyMenuOverflowTitle => 'Recept som inte fick plats';

  @override
  String get weeklyMenuOvrigtAddMore => '+ lägg till';

  @override
  String get weeklyMenuOverwriteConfirm =>
      'Detta ersätter din nuvarande planering. Fortsätt?';

  @override
  String get weeklyMenuLoadError => 'Kunde inte ladda veckomenyn';

  @override
  String weeklyMenuWeekLabel(int weekNum, String start, String end) {
    return 'Vecka $weekNum · $start–$end';
  }

  @override
  String get mealSlotLunch => 'Lunch';

  @override
  String get mealSlotMiddag => 'Middag';

  @override
  String get mealSlotOvrigt => 'Övrigt';

  @override
  String get weeklyMenuChipsHeading => 'Vi förstod:';

  @override
  String get weeklyMenuChipsNotUnderstood => 'Vi förstod inte:';

  @override
  String get weeklyMenuChipsRefinePrompt => 'Förfina prompten';

  @override
  String get pantrySectionExpiring => 'Går ut snart';

  @override
  String get pantrySectionFridge => 'Kylskåp';

  @override
  String get pantrySectionFreezer => 'Frys';

  @override
  String get pantrySectionPantry => 'Skafferi';

  @override
  String get pantrySectionSpiceRack => 'Kryddhylla';

  @override
  String get pantryLocationFridge => 'Kylskåp';

  @override
  String get pantryLocationFreezer => 'Frys';

  @override
  String get pantryLocationPantry => 'Skafferi';

  @override
  String get pantryLocationSpiceRack => 'Kryddhylla';

  @override
  String get pantryLocationLabel => 'Plats';

  @override
  String get pantryExpiryExpired => 'Utgånget';

  @override
  String get pantryExpiryToday => 'Utgår idag';

  @override
  String pantryExpiryInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Utgår om $days dagar',
      one: 'Utgår om 1 dag',
    );
    return '$_temp0';
  }

  @override
  String get pantryExpiryDate => 'Utgångsdatum';

  @override
  String get pantryExpiryLabel => 'Utgår';

  @override
  String get pantryExpiryNone => 'Inget utgångsdatum';

  @override
  String get pantryEmptyTitle => 'Ditt skafferi är tomt';

  @override
  String get pantryEmptyDescription =>
      'Lägg till ingredienser för att hitta recept du kan laga med det du har';

  @override
  String get pantryAddIngredient => 'Lägg till ingrediens';

  @override
  String get pantryAddSheetTitle => 'Lägg till ingrediens';

  @override
  String get pantryEditSheetTitle => 'Redigera ingrediens';

  @override
  String get pantryIngredientLabel => 'Ingrediens';

  @override
  String get pantryIngredientHint => 'Sök ingrediens...';

  @override
  String get pantryQuantityLabel => 'Mängd';

  @override
  String get pantryUnitLabel => 'Enhet';

  @override
  String get pantryNoteLabel => 'Anteckning (valfritt)';

  @override
  String get pantryAddAction => 'LÄGG TILL';

  @override
  String get pantryDeleteConfirmTitle => 'Ta bort ingrediens?';

  @override
  String get pantryDeleteConfirmMessage =>
      'Ingrediensen tas bort från skafferiet';

  @override
  String get filterWithMyIngredients => 'Med mina ingredienser';

  @override
  String get shoppingTabLists => 'Inköpslistor';

  @override
  String get shoppingTabPantry => 'Skafferiet';

  @override
  String recipeCardPantryMatchA11y(int percent) {
    return 'Matchar $percent% av dina ingredienser';
  }

  @override
  String get ingredientSearchTitle => 'Sök med ingredienser';

  @override
  String get ingredientSearchHint => 'Sök ingrediens...';

  @override
  String get ingredientSearchButton => 'Visa recept';

  @override
  String get ingredientSearchChip => 'Med ingredienser';

  @override
  String get ingredientSearchEmpty =>
      'Lägg till ingredienser för att hitta recept';

  @override
  String get ingredientSearchNoResults =>
      'Inga recept matchar dina ingredienser';

  @override
  String get ingredientSearchError => 'Kunde inte söka recept';

  @override
  String ingredientSearchResultCount(int count) {
    return '$count recept hittade';
  }

  @override
  String ingredientMatchCount(int matched, int total) {
    return '$matched av $total ingredienser';
  }

  @override
  String ingredientMissing(String list) {
    return 'Saknas: $list';
  }

  @override
  String get ingredientSearchSharedBadge => 'Delat';

  @override
  String get tarJag => 'Tar jag';

  @override
  String get lamnaTillbaka => 'Lämna tillbaka';

  @override
  String get minDel => 'Min del';

  @override
  String annasDel(String name) {
    return '${name}s del';
  }

  @override
  String get otilldelat => 'Otilldelat';

  @override
  String handlarNu(String name) {
    return '$name handlar nu';
  }

  @override
  String get efterZon => 'Efter zon';

  @override
  String get alla => 'Alla';

  @override
  String nagonAnnanTogDen(String name) {
    return '$name tog den — välj en annan';
  }

  @override
  String shoppingItemClaimed(String itemName) {
    return 'Tar hand om \"$itemName\"';
  }

  @override
  String shoppingItemUnclaimed(String itemName) {
    return 'Släppte \"$itemName\"';
  }

  @override
  String outOfIngredientTitle(String ingredient) {
    return 'Slut på $ingredient? Prova…';
  }

  @override
  String get ratioSuffix => 'av originalmängden';

  @override
  String get replaceInRecipe => 'Byt i receptet';

  @override
  String get noSubstitutionSuggestions => 'Inga förslag just nu';

  @override
  String get suggestAlternative => 'Föreslå ett alternativ';

  @override
  String get startTimer => 'Starta timer';

  @override
  String get timerExpired => 'Timer klar!';

  @override
  String get pauseTimer => 'Pausa';

  @override
  String get resumeTimer => 'Återuppta';

  @override
  String get resetTimer => 'Återställ';

  @override
  String timerDurationHint(String source) {
    return 'Från \"$source\"';
  }

  @override
  String get heirloomToggle => 'Detta är ett arvegods';

  @override
  String get heirloomWriterLabel => 'Vem skrev receptet?';

  @override
  String get heirloomYearLabel => 'Vilket år?';

  @override
  String get heirloomNoteLabel => 'Kort notering';

  @override
  String heirloomFrom(String name, int year) {
    return 'Från $name, $year';
  }

  @override
  String get heirloomUploadOffline => 'Sparas när du är online igen';

  @override
  String get heirloomUploadError => 'Kunde inte spara bilden — försök igen';

  @override
  String get cookingNowEyebrow => 'lagar just nu';

  @override
  String cookingNowSingle(String name, String recipe) {
    return '$name lagar $recipe';
  }

  @override
  String cookingNowMerge(String names, String recipe) {
    return '$names lagar $recipe';
  }

  @override
  String get notificationPermissionTitle => 'Aktivera aviseringar?';

  @override
  String get notificationPermissionBody =>
      'Butlery använder aviseringar för att påminna om timers, meddelanden från vänner och aktivitet i dina delade recept. Du kan ändra detta när som helst i inställningarna.';

  @override
  String get notificationPermissionGrant => 'Tillåt';

  @override
  String get notificationPermissionOpenSettings => 'Öppna inställningar';

  @override
  String get notificationPermissionPermanentlyDeniedMessage =>
      'Aviseringar är avstängda. Öppna inställningarna för att aktivera dem.';

  @override
  String get familyPresenceTitle => 'Online just nu';

  @override
  String get familyPresenceEmpty => 'Ingen är online just nu';

  @override
  String familyPresenceOverflow(int count) {
    return '+$count';
  }

  @override
  String cookingStepSuffix(int current, int total) {
    return ' · steg $current av $total';
  }

  @override
  String get pingNudge => 'Knuffa';

  @override
  String get pingTimerAlert => 'Timer-alarm';

  @override
  String get pingHelpMe => 'Hjälp mig';

  @override
  String get pingComposeTitle => 'Skicka en putt';

  @override
  String get pingComposeMessageHint => 'Meddelande (frivilligt)';

  @override
  String get pingComposeSend => 'Skicka';

  @override
  String get pingComposeSent => 'Skickat';

  @override
  String get pingRateLimited =>
      'Du har skickat för många puttar den senaste timmen';

  @override
  String pingNudgeFrom(String name) {
    return '$name puttar på dig';
  }

  @override
  String pingTimerAlertFrom(String name) {
    return '$name har en timer som ringer';
  }

  @override
  String pingHelpMeFrom(String name) {
    return '$name behöver hjälp';
  }

  @override
  String activityAddedIngredient(String name, String ingredient) {
    return '$name lade till $ingredient';
  }

  @override
  String activityStartedCooking(String name, String recipe) {
    return '$name började laga $recipe';
  }

  @override
  String get moderatorReviewTitle => 'Granska rapporter';

  @override
  String get moderatorNotAuthorized =>
      'Du har inte behörighet att se den här sidan.';

  @override
  String get moderatorNoOpenReports => 'Inga öppna rapporter just nu.';

  @override
  String get moderatorReasonLabel => 'Anledning';

  @override
  String get moderatorReporterLabel => 'Rapporterat av';

  @override
  String get moderatorActionAdvance => 'Nästa steg';

  @override
  String get moderatorActionClose => 'Stäng rapport';

  @override
  String get moderatorActionDelete => 'Ta bort innehåll';

  @override
  String get moderatorDeleteConfirmTitle => 'Ta bort innehållet?';

  @override
  String get moderatorDeleteConfirmBody =>
      'Detta tar bort det rapporterade innehållet permanent. Åtgärden kan inte ångras från appen.';

  @override
  String get moderatorActionHide => 'Dölj profil';

  @override
  String get moderatorHideConfirmTitle => 'Dölj den här profilen?';

  @override
  String get moderatorHideConfirmBody =>
      'Profilen tas bort från sök och vänlistor. Användaren kan fortfarande logga in men visas som en platshållare för andra. Du kan ångra det senare.';

  @override
  String get appealProcessTitle => 'Överklaga en borttagning';

  @override
  String get appealProcessBody =>
      'Om ditt innehåll har tagits bort och du anser att beslutet är felaktigt kan du överklaga genom att skicka ett mejl till appeals@butlery.app. Inkludera användarnamn, innehållstyp (recept, kommentar, meddelande) och en kort beskrivning. Vi svarar inom 14 dagar.';

  @override
  String get appealEmailLinkLabel => 'Överklaga en borttagning';

  @override
  String get appealEmailSubject => 'Överklagan: borttaget innehåll';

  @override
  String get appealEmailBodyTemplate =>
      'Hej Butlery,\n\nJag vill överklaga borttagningen av följande innehåll:\n- Innehållstyp (recept/kommentar/meddelande):\n- Ungefärligt datum:\n- Mitt användarnamn:\n\nAnledning till överklagan:\n\nTack.';

  @override
  String get appealEmailLaunchFailed =>
      'Kunde inte öppna e-postappen. Skicka manuellt till appeals@butlery.app.';

  @override
  String get a11yProfileImageEdit => 'Profilbild, tryck för att ändra';

  @override
  String get a11yProfileImageReadonly => 'Profilbild';

  @override
  String get a11yReactToComment => 'Reagera på kommentar';

  @override
  String a11yShowCommentLikes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Visa $count gilla-markeringar',
      one: 'Visa 1 gilla-markering',
    );
    return '$_temp0';
  }

  @override
  String get a11yLongPressCommentForReactions =>
      'Kommentar, långtryck för att reagera';

  @override
  String get a11yDismissReactionPicker => 'Stäng reaktionsväljaren';

  @override
  String get a11yCommentLikeAction => 'Gilla kommentar';

  @override
  String get a11yCommentReplyAction => 'Svara på kommentar';

  @override
  String get a11yRetryUpload => 'Försök ladda upp igen';

  @override
  String get a11yCancelUpload => 'Avbryt uppladdning';

  @override
  String a11yBulkUploadAction(String label) {
    return '$label';
  }

  @override
  String a11yEditImageAction(String label) {
    return '$label';
  }

  @override
  String get a11yEmptyImageStateAdd => 'Lägg till bild, tryck för att välja';

  @override
  String get a11yImagePickerOpen => 'Välj bilder';

  @override
  String a11yImagePickerRemove(int index) {
    return 'Ta bort vald bild $index';
  }

  @override
  String get a11yGalleryAddImage => 'Lägg till bild i galleriet';

  @override
  String recipeCardSemantics(String title) {
    return 'Recept: $title, tryck för att öppna';
  }

  @override
  String recipeRatingSemantics(String rating) {
    return 'Betyg: $rating';
  }

  @override
  String get recipeVisibilityPrivate => 'Privat';

  @override
  String get recipeVisibilityCollaborative => 'Delas med samarbetspartners';

  @override
  String get recipeVisibilityPublic => 'Offentligt';

  @override
  String a11yMenuRecipeOpen(String title) {
    return '$title, tryck för att öppna receptet';
  }

  @override
  String a11yMenuSectionRegenerate(String category) {
    return 'Skapa nytt förslag för $category';
  }

  @override
  String a11yMenuSwapRecipe(String title) {
    return 'Byt ut $title';
  }

  @override
  String a11yMenuSuggestAlternative(String title) {
    return 'Föreslå alternativ för $title';
  }

  @override
  String a11yShelfRecipeOpen(String title) {
    return '$title, tryck för att öppna';
  }

  @override
  String a11yCookSnapOptions(String name) {
    return 'Matlagningsbild av $name, långtryck för alternativ';
  }

  @override
  String a11yConversationOpen(String name) {
    return 'Konversation med $name, tryck för att öppna';
  }

  @override
  String a11yMenuVoteOption(String name) {
    return 'Rösta på $name';
  }

  @override
  String a11yMenuVoteOptionSelected(String name) {
    return '$name, vald. Tryck för att ändra röst.';
  }

  @override
  String a11yPingAcknowledge(String name) {
    return 'Bekräfta notis från $name';
  }

  @override
  String a11yMenuPlanRecipeOpen(String title) {
    return '$title, tryck för att öppna receptet';
  }

  @override
  String a11yMenuPlanOvrigtAddMore(String day) {
    return 'Lägg till mer i övrigt för $day';
  }

  @override
  String get a11yRefineMenuPrompt => 'Förbättra menyprompten';

  @override
  String get a11yHeadingIngredients => 'Ingredienser';

  @override
  String get a11yHeadingInstructions => 'Instruktioner';

  @override
  String get a11yHeadingComments => 'Kommentarer';

  @override
  String a11yAddIngredient(String name) {
    return 'Lägg till $name';
  }

  @override
  String a11yQuickFilter(String label) {
    return 'Filtrera på $label';
  }

  @override
  String a11yQuickFilterSelected(String label) {
    return '$label, valt filter';
  }

  @override
  String get a11yHeirloomScanOpenFullscreen =>
      'Öppna originalskanning i fullskärm';

  @override
  String a11yReplaceWithSubstitute(String name) {
    return 'Byt ut mot $name i receptet';
  }

  @override
  String a11yShareTabSwitch(String label) {
    return 'Visa $label';
  }

  @override
  String get a11yPantryAddItem => 'Lägg till ny vara';

  @override
  String a11yPantryEditItem(String itemName) {
    return '$itemName, tryck för att redigera';
  }

  @override
  String get a11yPantryPickExpiry => 'Välj utgångsdatum';

  @override
  String a11yDraftRecoverTile(String title) {
    return '$title, tryck för att återställa';
  }

  @override
  String get a11yShareModeStaticCopy => 'Statisk kopia, tryck för att välja';

  @override
  String get a11yShareModeRealtime => 'Realtidsdelning, tryck för att välja';

  @override
  String a11yFriendRequestIncoming(String name) {
    return 'Vänförfrågan från $name, tryck för att markera';
  }

  @override
  String a11yFriendRequestSent(String name) {
    return 'Skickad förfrågan till $name, tryck för att markera';
  }

  @override
  String a11yFeedFilter(String label) {
    return 'Filtrera flödet på $label';
  }

  @override
  String a11yFeedRecipePreview(String title) {
    return 'Visa receptet $title';
  }

  @override
  String a11yPublicProfileRecipeCard(String title) {
    return 'Öppna receptet $title';
  }

  @override
  String get a11yBlockedUsersToggle =>
      'Blockerade användare, tryck för att visa eller dölja listan';

  @override
  String a11yInvitationTargetCard(String name) {
    return 'Bjud in $name';
  }

  @override
  String a11yPermissionsBanner(String description) {
    return 'Behörighet: $description';
  }

  @override
  String a11yCollaborativeBanner(String title, String subtitle) {
    return '$title, $subtitle';
  }

  @override
  String a11yEmojiPicker(String emoji) {
    return 'Välj $emoji som ikon';
  }

  @override
  String a11yRemoveIngredientChip(String label) {
    return 'Ta bort $label';
  }

  @override
  String get a11yToggleFullscreenChrome => 'Visa eller dölj kontroller';

  @override
  String get a11yCommentsToggle => 'Kommentarer';

  @override
  String a11yShowSubstitutionsFor(String ingredient) {
    return 'Visa substitut för $ingredient';
  }

  @override
  String a11yToggleStepDone(int step) {
    return 'Markera steg $step som klart eller oavslutat';
  }

  @override
  String get a11yRemoveOwnRating => 'Ta bort mitt betyg';

  @override
  String a11yPickTime(String label, String time) {
    return 'Välj $label: nuvarande tid $time';
  }

  @override
  String a11yCookingStepLongPressTimer(int step) {
    return 'Steg $step, långtryck för att starta timer';
  }

  @override
  String get a11yArchivedConversationsToggle => 'Arkiverade konversationer';

  @override
  String get a11yRecipeImageFullscreen => 'Visa receptbild i fullskärm';

  @override
  String a11yHeroButton(String tooltip) {
    return '$tooltip';
  }

  @override
  String get a11yDismissParseQualityWarning =>
      'Avfärda varning om importkvalitet';

  @override
  String a11yToggleShoppingCategory(String category) {
    return 'Kategori $category';
  }

  @override
  String get a11yToggleEmptyCategories => 'Övriga kategorier';

  @override
  String a11yWeeklyMenuViewModeToggle(String label) {
    return '$label';
  }

  @override
  String a11yPollVoteOption(String label) {
    return 'Rösta på $label';
  }

  @override
  String a11yPollRecipeThumbnail(String title) {
    return 'Visa receptet $title';
  }

  @override
  String get a11yPingComposeSend => 'Skicka notis';

  @override
  String get cookingModeOpenEditToSwap => 'Öppna redigering för att byta';

  @override
  String get feedbackEmailHint => 'din@email.se';

  @override
  String get mfaPhoneHint => '+46 70 123 45 67';

  @override
  String get dialogEmailLabel => 'E-post';

  @override
  String get dialogEmailHint => 'din@email.se';

  @override
  String get dialogUrlLabel => 'URL';

  @override
  String get dialogUrlHint => 'https://exempel.se';
}
