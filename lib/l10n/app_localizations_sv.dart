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
  String get commonSend => 'Skicka';

  @override
  String get shoppingRenameList => 'Byt namn på lista';

  @override
  String get shoppingCreateList => 'Skapa ny handlista';

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
  String get imageFromGallery => 'Från galleriet';

  @override
  String get imageSelectFromGallery => 'Välj en bild från galleriet';

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
  String get chatConversationInfo => 'Konversationsinformation';

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
      'Är du säker på att du vill lämna konversationen?';

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
}
