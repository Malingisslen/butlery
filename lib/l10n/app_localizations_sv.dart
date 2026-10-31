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
  String get commonYes => 'Ja';

  @override
  String get commonNo => 'Nej';

  @override
  String get commonRetry => 'Försök igen';

  @override
  String recipesSharedWith(int count, String title, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept delades med $name',
      one: '$title delades med $name',
    );
    return '$_temp0';
  }

  @override
  String get stateSuccessDefault => 'Klart';

  @override
  String get a11yBlockGroupMember => 'Blockera';

  @override
  String get a11yRequiredFieldSuffix => 'Obligatoriskt';

  @override
  String get maintenanceModeTitle => 'Underhållsläge';

  @override
  String get maintenanceModeDefaultMessage =>
      'Vi gör en kort uppdatering. Försök igen om en stund.';

  @override
  String get commonLoading => 'Laddar …';

  @override
  String get commonDeleting => 'Tar bort …';

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
  String get shoppingItemName => 'Varunamn';

  @override
  String get shoppingAmount => 'Mängd';

  @override
  String get shoppingUnit => 'Enhet';

  @override
  String get shoppingCategory => 'Kategori';

  @override
  String get shoppingAddItem => 'Lägg till vara';

  @override
  String get shoppingEditItem => 'Redigera vara';

  @override
  String get shoppingList => 'Inköpslista';

  @override
  String get authInvalidEmail => 'Ange en giltig e-postadress';

  @override
  String get authResetPassword => 'Återställ lösenord';

  @override
  String get authForgotPassword => 'Glömt lösenord?';

  @override
  String get authEnterPassword => 'Ange ditt lösenord';

  @override
  String get authPasswordChoose => 'Välj ett starkt lösenord';

  @override
  String get passwordRuleHint =>
      'Tolv eller fler tecken, eller tre ord du minns. Kravet står här – inte som ett fel efter att du skrivit.';

  @override
  String get guestUpgradeNameHint => 'Vad ska vi kalla dig?';

  @override
  String get authResetPasswordInstructions =>
      'Ange din e-postadress så skickar vi instruktioner för att återställa ditt lösenord.';

  @override
  String get imageAddImage => 'Lägg till bild';

  @override
  String get commentDeletedUndoMessage => 'Kommentaren raderad';

  @override
  String get imageRemovedUndoMessage => 'Foto borttaget';

  @override
  String pantryItemRemovedUndoMessage(String name) {
    return '$name borttagen ur skafferiet';
  }

  @override
  String pantryItemsRemovedUndoMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count borttagna',
      one: '1 borttagen',
    );
    return '$_temp0 ur skafferiet';
  }

  @override
  String get a11yPantrySelectItem => 'Markera';

  @override
  String slotSpillHeading(int placed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      placed,
      locale: localeName,
      other: '$placed platser',
      one: 'En plats',
      zero: 'Inga lediga platser',
    );
    return '$_temp0, $count recept';
  }

  @override
  String slotSpillBody(int rest, int week, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      rest,
      locale: localeName,
      other:
          '$rest recept får inte plats i vecka $week: $names. Välj vad som ska hända med dem, sedan skriver vi.',
      one:
          'Ett recept får inte plats i vecka $week: $names. Välj vad som ska hända med det, sedan skriver vi.',
    );
    return '$_temp0';
  }

  @override
  String slotSpillNextWeek(int placed, int rest, int week) {
    return 'Lägg $placed nu, $rest i vecka $week';
  }

  @override
  String slotSpillAllNextWeek(int week) {
    return 'Lägg alla i vecka $week';
  }

  @override
  String get slotSpillChooseMore => 'Välj fler platser';

  @override
  String slotSpillPlaceOnly(int placed) {
    String _temp0 = intl.Intl.pluralLogic(
      placed,
      locale: localeName,
      other: 'Lägg bara de $placed',
      one: 'Lägg bara det första',
    );
    return '$_temp0';
  }

  @override
  String bulkAddToMenuSuccessTwoWeeks(int added, int next, int week) {
    return '$added recept i veckan, $next i vecka $week';
  }

  @override
  String bulkAddToMenuNextWeekFailed(int added, int week) {
    return '$added recept lades i veckan. Resten kunde inte läggas i vecka $week.';
  }

  @override
  String get slotPickerDialogTitle => 'Välj plats i veckomenyn';

  @override
  String get slotPickerPreviousWeek => 'Föregående vecka';

  @override
  String get slotPickerNextWeek => 'Nästa vecka';

  @override
  String slotPickerWeekLabel(int week) {
    return 'vecka $week';
  }

  @override
  String slotPickerConfirmCount(int count) {
    return 'Lägg till ($count)';
  }

  @override
  String a11ySlotPickerCell(String slot) {
    return 'Välj $slot';
  }

  @override
  String recipeAddedToMenuSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Receptet lades till på $count platser i veckomenyn',
      one: 'Receptet lades till på 1 plats i veckomenyn',
    );
    return '$_temp0';
  }

  @override
  String get menuPlaceAutoButton => 'Placera automatiskt i kalendern';

  @override
  String get menuPlaceManualButton => 'Jag placerar själv';

  @override
  String menuAutoPlacedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept placerade i kalendern',
      one: '1 recept placerat i kalendern',
    );
    return '$_temp0';
  }

  @override
  String get menuAutoPlacedChangeAction => 'Ändra';

  @override
  String get menuPlacementTitle => 'Placera i veckan';

  @override
  String menuPlacementProgress(int placed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total placerade',
      one: '1 placerad',
    );
    return '$placed av $_temp0';
  }

  @override
  String menuPlacementTrayLabel(int count) {
    return '$count kvar att placera';
  }

  @override
  String menuPlacementHint(String recipe) {
    return 'Tryck på en ledig plats för $recipe. Lunch och middag tar en rätt, övrigt tar flera.';
  }

  @override
  String get menuPlacementHintSelect =>
      'Välj en rätt nedan för att placera den. Lunch och middag tar en rätt, övrigt tar flera.';

  @override
  String get menuPlacementAutoRest => 'Slumpa resten';

  @override
  String menuPlacementOverflow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept fick inte plats den här veckan',
      one: '1 recept fick inte plats den här veckan',
    );
    return '$_temp0';
  }

  @override
  String menuPlacementSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept placerade i veckomenyn',
      one: '1 recept placerat i veckomenyn',
    );
    return '$_temp0';
  }

  @override
  String get weeklyMenuNewBadge => 'NY';

  @override
  String a11yPlacementCell(String day, String slot) {
    return 'Placera på $day $slot';
  }

  @override
  String get a11yPlacementTrayCard => 'Välj';

  @override
  String get a11yPlacementRemoveEntry => 'Ta bort från rutan';

  @override
  String get bulkAddToMenu => 'Lägg till i veckomeny';

  @override
  String bulkAddToMenuSuccess(int count, String slot, String day) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept tillagda',
      one: '1 recept tillagt',
    );
    return '$_temp0 i $slot $day';
  }

  @override
  String bulkAddToMenuOverflowed(int added, int requested) {
    return '$added av $requested lades till – resten ryms inte i veckan';
  }

  @override
  String bulkAddToMenuSuccessNextWeek(int count) {
    return '$count recept lades till nästa vecka';
  }

  @override
  String bulkAddToMenuOverflowedTwoWeeks(int remaining) {
    return 'Resten ryms inte i nästa vecka heller – $remaining recept utan plats';
  }

  @override
  String get bulkExport => 'Exportera valda';

  @override
  String get bulkExportCopyClipboard => 'Kopiera till urklipp';

  @override
  String get bulkExportShareFile => 'Dela som fil';

  @override
  String bulkExportCopied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept kopierade',
      one: '1 recept kopierat',
    );
    return '$_temp0 till urklipp';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bilder',
      one: '1 bild',
    );
    return 'Välj upp till $_temp0';
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
  String get validationInvalidAmount => 'Ogiltigt antal';

  @override
  String get validationGenericRequired => 'Detta fält krävs';

  @override
  String get validationEmailInvalid => 'Ogiltig e-postadress';

  @override
  String get errorGeneric => 'Det gick inte att slutföra. Försök igen.';

  @override
  String get errorNetwork => 'Nätverksfel. Kontrollera din internetanslutning.';

  @override
  String get errorServer => 'Serverfel. Försök igen senare.';

  @override
  String get errorAuthentication => 'Autentiseringsfel. Logga in igen.';

  @override
  String get errorSignupNotInvited =>
      'Butlery är bara öppet för inbjudna just nu.';

  @override
  String get errorSignupGateUnavailable =>
      'Det gick inte att skapa kontot just nu. Försök igen om en stund.';

  @override
  String get errorSignInEmailUnverified =>
      'Bekräfta din e-post via länken vi skickade. Hittar du den inte? Välj Glömt lösenord.';

  @override
  String get errorPermissionDenied =>
      'Du har inte behörighet för denna åtgärd.';

  @override
  String get errorPageNotFound => 'Sidan kunde inte hittas';

  @override
  String get errorBackToStart => 'Tillbaka till start';

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
  String get errorCouldNotUpdateSearchability =>
      'Synligheten i sökningar kunde inte uppdateras. Försök igen.';

  @override
  String errorCouldNotDelete(String itemType) {
    return 'Kunde inte radera $itemType';
  }

  @override
  String errorCouldNotLoad(String itemType) {
    return 'Kunde inte ladda $itemType';
  }

  @override
  String get nounSettings => 'inställningar';

  @override
  String get nounFriends => 'vänner';

  @override
  String get nounFriendList => 'vänlista';

  @override
  String groupInvitationMessage(String groupName) {
    return 'En inbjudan till gruppen $groupName har anlänt.';
  }

  @override
  String uploadTimeIn(String duration) {
    return ' på $duration';
  }

  @override
  String get autoSaveEnabled => 'Autospar aktiverat';

  @override
  String get autoSaveFailed => 'Utkastet kunde inte sparas.';

  @override
  String get autoSaveFailedPreserved =>
      'Det du skrivit finns kvar här. Tryck Spara för att spara receptet.';

  @override
  String selectionFriendSelectedWithName(String name) {
    return '$name vald';
  }

  @override
  String selectionFriendsSelectedWithNames(int count, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valda',
      one: '1 vald',
    );
    return '$_temp0: $names';
  }

  @override
  String selectionFriendsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vänner valda',
      one: '1 vän vald',
    );
    return '$_temp0';
  }

  @override
  String sharePartialSuccessSingular(int newCount) {
    String _temp0 = intl.Intl.pluralLogic(
      newCount,
      locale: localeName,
      other: '$newCount nya',
      one: '1 ny',
    );
    return '1 person är redan med. Bjuder in $_temp0.';
  }

  @override
  String sharePartialSuccessPlural(int existingCount, int newCount) {
    String _temp0 = intl.Intl.pluralLogic(
      existingCount,
      locale: localeName,
      other: '$existingCount personer',
      one: '1 person',
    );
    String _temp1 = intl.Intl.pluralLogic(
      newCount,
      locale: localeName,
      other: '$newCount nya',
      one: '1 ny',
    );
    return '$_temp0 är redan med. Bjuder in $_temp1.';
  }

  @override
  String get nounShoppingList => 'inköpslista';

  @override
  String errorWithContext(String action, String error) {
    return 'Det gick inte att slutföra när du $action. Försök igen.';
  }

  @override
  String successItemCreated(String itemType) {
    return '$itemType har lagts till.';
  }

  @override
  String successItemUpdated(String itemType) {
    return '$itemType har uppdaterats.';
  }

  @override
  String successItemDeleted(String itemType) {
    return '$itemType har raderats.';
  }

  @override
  String successItemAdded(String itemName) {
    return '$itemName har lagts till.';
  }

  @override
  String confirmDeleteItem(String itemName) {
    return 'Bekräftelse krävs: radera ”$itemName”?';
  }

  @override
  String get confirmUnsavedChanges =>
      'Osparade ändringar föreligger. Lämna utan att spara?';

  @override
  String get draftRecovery => 'Återställ utkast';

  @override
  String get draftRecoverySubtitle =>
      'Du har osparade receptutkast. Vill du fortsätta där du slutade?';

  @override
  String get photoDraftRecoverySubtitle =>
      'Du har ett foto med tolkad text sedan tidigare. Vill du fortsätta där du slutade?';

  @override
  String get draftRestore => 'Återställ';

  @override
  String get draftStartFresh => 'Börja om';

  @override
  String get draftCouldNotRestore =>
      'Kunde inte återställa utkast. Börjar med tomt formulär.';

  @override
  String get draftRestoring => 'Återställer utkast …';

  @override
  String get draftUnnamedRecipe => 'Namnlöst recept';

  @override
  String draftFieldsFilledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fält ifyllda',
      one: '1 fält ifyllt',
    );
    return '$_temp0';
  }

  @override
  String draftRestoredWithCount(int count) {
    return 'Utkastet är återställt – $count fält laddades.';
  }

  @override
  String get emptyNoResults => 'Inga resultat hittades.';

  @override
  String emptyNoRecipesSubtitle(String addButton) {
    return 'Första receptet läggs till via ”$addButton”.';
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
      'Egna taggar används för att ordna receptsamlingen.';

  @override
  String get emptyNoGroupsTitle => 'Matlagning tillsammans, enklare';

  @override
  String get emptyNoGroupsSubtitle =>
      'Skapa en grupp för att dela veckomenyer och inköpslistor med vänner eller hushållet. Alla ser samma plan och kan bocka av varor under tiden.';

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
  String get recipeCookingTime => 'Tid att laga';

  @override
  String get recipePortions => 'Portioner';

  @override
  String get recipeEdit => 'Redigera recept';

  @override
  String get recipeDelete => 'Radera receptet';

  @override
  String get recipeDeleteAction => 'Radera';

  @override
  String get recipeOwnerCopyLabel => 'Min kopia';

  @override
  String get recipeDeleting => 'Raderar receptet …';

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
  String get messagingLoadingConversations => 'Laddar konversationer …';

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
  String get messagingLeave => 'Lämna';

  @override
  String get messagingDeleteConversationConfirm =>
      'Alla meddelanden i konversationen försvinner.';

  @override
  String messagingConversationDeleted(String title) {
    return 'Konversationen ”$title” raderad';
  }

  @override
  String messagingConfirmLeaveGroup(String groupName) {
    return 'Är du säker på att du vill lämna ”$groupName”?';
  }

  @override
  String get profileLogout => 'Logga ut';

  @override
  String get profileLogoutConfirm => 'Är du säker på att du vill logga ut?';

  @override
  String get profileDeleteAccount => 'Radera konto permanent';

  @override
  String get profileDeleteWarningTitle => 'Det här händer:';

  @override
  String get profileDeleteWarningRecipes => 'Radera alla dina recept';

  @override
  String get profileDeleteWarningMenus => 'Radera alla dina menyer';

  @override
  String get profileDeleteWarningShoppingLists =>
      'Radera alla dina inköpslistor';

  @override
  String get profileDeleteWarningFriends =>
      'Radera alla vänner och meddelanden';

  @override
  String get profileDeleteWarningSharedContent => 'Radera allt delat innehåll';

  @override
  String get profileDeleteIrreversible =>
      'Raderingen blir slutgiltig efter 7 dagar.';

  @override
  String get profileDeleteConfirmButton => 'Jag förstår, radera mitt konto';

  @override
  String get profileConfirmWithPassword => 'Bekräfta med lösenord';

  @override
  String get profileEnterPasswordToConfirm =>
      'Ange ditt lösenord för att fortsätta.';

  @override
  String get profilePassword => 'Lösenord';

  @override
  String get profileConfirm => 'Bekräfta';

  @override
  String get profileError => 'Fel';

  @override
  String get chatBlockGroupMemberEmpty =>
      'Det finns ingen annan att blockera här';

  @override
  String get chatBlockGroupMemberTitle => 'Vem vill du blockera?';

  @override
  String get chatConversationInfo => 'Konversationsinfo';

  @override
  String get chatTypeDirectMessage => 'Typ: Direktmeddelande';

  @override
  String chatCreatedAt(String date) {
    return 'Skapad: $date';
  }

  @override
  String get chatCouldNotChangeNotifications =>
      'Kunde inte ändra notisinställningar';

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
  String get chatWriteYourMessage => 'Skriv ditt meddelande …';

  @override
  String get chatCouldNotDeleteMessage => 'Kunde inte radera meddelandet';

  @override
  String get chatMessageCopied => 'Meddelande kopierat';

  @override
  String get chatCouldNotCopyMessage => 'Kunde inte kopiera meddelandet';

  @override
  String get chatYourRecipes => 'Dina recept';

  @override
  String get chatSharedRecipe => 'Delat recept';

  @override
  String get chatCheckOutRecipe => 'Ta gärna en titt på det här receptet.';

  @override
  String get chatCouldNotShareRecipe => 'Kunde inte dela recept';

  @override
  String get chatCouldNotShareMenu => 'Kunde inte dela meny';

  @override
  String get chatCouldNotShareShoppingList => 'Kunde inte dela inköpslista';

  @override
  String get chatSelectMenuWeek => 'Välj vecka att dela';

  @override
  String chatMenuWeekOption(int weekNum) {
    return 'Vecka $weekNum';
  }

  @override
  String get chatWeekCurrentSuffix => ' (denna vecka)';

  @override
  String chatMenuShareTitle(int weekNum) {
    return 'Veckomeny vecka $weekNum';
  }

  @override
  String get chatCheckOutMenu => 'Ta gärna en titt på min veckomeny.';

  @override
  String get chatNoMenuForWeek => 'Ingen meny för den veckan';

  @override
  String get chatSelectShoppingList => 'Välj inköpslista';

  @override
  String get chatCheckOutShoppingList => 'Ta gärna en titt på min inköpslista.';

  @override
  String get chatNoShoppingLists => 'Du har inga inköpslistor än';

  @override
  String get chatAttachmentRecipe => 'Recept';

  @override
  String get chatAttachmentMenu => 'Meny';

  @override
  String get chatAttachmentShoppingList => 'Inköpslista';

  @override
  String get chatAttachmentPhoto => 'Foto';

  @override
  String get chatMessagingDisabled =>
      'Meddelandefunktionen är tillfälligt inaktiverad.';

  @override
  String get feedRequestRecipeTitle => 'Be om receptet';

  @override
  String feedRequestRecipeBody(String name) {
    return '$name har inte delat det här receptet. Vill du be om det?';
  }

  @override
  String get feedRequestRecipeConfirm => 'Be om receptet';

  @override
  String get feedRecipeRequestSent => 'Förfrågan skickad';

  @override
  String get chatLoadingImage => 'Laddar bild …';

  @override
  String get chatImageSent => 'Bilden är skickad.';

  @override
  String get chatNoImageSelected => 'Ingen bild vald';

  @override
  String get chatImageQueuedOffline => 'Bilden skickas när du är online igen.';

  @override
  String get chatCouldNotSharePhoto => 'Kunde inte dela foto';

  @override
  String get chatDeleteMessage => 'Radera meddelandet';

  @override
  String get statusConnecting => 'Ansluter …';

  @override
  String get statusSaving => 'Sparar …';

  @override
  String get statusCreating => 'Skapar …';

  @override
  String get accessibilityBackButton => 'Tillbaka';

  @override
  String get unitMinutesShort => 'min';

  @override
  String get unitHoursShort => 'h';

  @override
  String get dialogErrorTitle => 'Det gick inte att slutföra';

  @override
  String get dialogLoading => 'Laddar …';

  @override
  String get recipePortionAbbreviation => 'port';

  @override
  String get recipePortionSingular => 'portion';

  @override
  String get recipePortionsPlural => 'portioner';

  @override
  String get recipeCookedToday => 'Markera som lagat';

  @override
  String recipeCookedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lagat $count gånger',
      one: 'Lagat 1 gång',
    );
    return '$_temp0';
  }

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
  String get recipePersonalTags => 'Egna taggar';

  @override
  String get recipeAnalysisFailed => 'Analys misslyckades';

  @override
  String get recipeAnalyzing => 'Analyseras …';

  @override
  String get recipeAnalysisFailedA11y => 'Ingrediensanalys misslyckades';

  @override
  String get recipeAnalyzingA11y => 'Ingredienser analyseras';

  @override
  String get recipeSearchHint => 'Sök bland recepten …';

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
    String _temp0 = intl.Intl.pluralLogic(
      to,
      locale: localeName,
      other: '$to portioner',
      one: '1 portion',
    );
    return 'Skalat från $from till $_temp0';
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
  String get menuPromptHint =>
      'Till exempel 3 middagar, 2 luncher och 1 frukost';

  @override
  String get voicePromptStart => 'Tala in veckomenyn';

  @override
  String get voicePromptStop => 'Klar, tolka det du sa';

  @override
  String get voicePromptTranscribing => 'Tolkar det du sa';

  @override
  String get voicePromptPreparing =>
      'Förbereder röstfunktionen, hämtar den svenska talmodellen';

  @override
  String get voicePromptFailed =>
      'Rösten kunde inte tolkas den här gången. Det går bra att skriva i stället';

  @override
  String get voiceUnavailable =>
      'Röstfunktionen är inte tillgänglig just nu. Det går bra att skriva i stället';

  @override
  String get voiceSearchStart => 'Tala in din sökning';

  @override
  String get voiceCommentStart => 'Tala in en kommentar';

  @override
  String get voiceSearchMicRationaleTitle => 'Mikrofon för sökning';

  @override
  String get voiceCommentMicRationaleTitle => 'Mikrofon för kommentarer';

  @override
  String get voiceMicRationaleBody =>
      'Butlery använder mikrofonen för att du ska kunna tala i stället för att skriva. Ljudet tolkas direkt i telefonen och skickas aldrig vidare.';

  @override
  String get voiceAssistUnavailable =>
      'Röstfunktionen är inte tillgänglig just nu';

  @override
  String get voicePromptMicRationaleTitle => 'Mikrofon för veckomenyn';

  @override
  String get voicePromptMicRationaleBody =>
      'Butlery använder mikrofonen för att du ska kunna tala in din veckomeny. Ljudet tolkas direkt i telefonen och skickas aldrig vidare.';

  @override
  String get voicePromptMicGrant => 'Tillåt';

  @override
  String get voicePromptMicPermanentlyDenied =>
      'Mikrofonen är avstängd för Butlery. Den kan slås på i inställningarna';

  @override
  String get voicePromptOpenSettings => 'Öppna inställningar';

  @override
  String get voiceImportTitle => 'Tala in recept';

  @override
  String get voiceImportIntro =>
      'Tala in receptet i tre delar, i valfri ordning. Texten går alltid att ändra innan receptet importeras';

  @override
  String get voiceImportSectionTitle => 'Rättens namn';

  @override
  String get voiceImportSectionIngredients => 'Ingredienser';

  @override
  String get voiceImportSectionSteps => 'Gör så här';

  @override
  String get voiceImportPromptTitle => 'Vad heter rätten?';

  @override
  String get voiceImportPromptIngredients =>
      'Läs upp ingredienserna, en i taget';

  @override
  String get voiceImportPromptSteps => 'Berätta hur du gör';

  @override
  String get voiceImportTypeHint => 'Eller skriv här';

  @override
  String get voiceImportSubmit => 'Importera receptet';

  @override
  String get voiceImportImporting => 'Importerar …';

  @override
  String get voiceImportSubmitHint =>
      'Knappen låses upp när alla tre delar har text';

  @override
  String get voiceImportFailed =>
      'Receptet kunde inte tolkas den här gången. Texten går att justera och prova igen';

  @override
  String get voiceImportMicRationaleTitle => 'Mikrofon för receptinläsning';

  @override
  String get recipeVoiceImport => 'Tala in recept';

  @override
  String voiceAssistStepPrefix(int step, int total) {
    return 'Steg $step av $total. ';
  }

  @override
  String get voiceAssistNoNextStep =>
      'Det finns inget nästa steg. Receptet är klart';

  @override
  String get voiceAssistNoPreviousStep => 'Det här är första steget';

  @override
  String get voiceAssistNoIngredients => 'Ingredienslistan är tom';

  @override
  String voiceAssistTimerStarted(String duration) {
    return 'Timer $duration startad';
  }

  @override
  String get voiceAssistNoTimers => 'Ingen timer är igång';

  @override
  String voiceAssistSubstitutions(String ingredient, String suggestions) {
    return '$ingredient kan ersättas med: $suggestions';
  }

  @override
  String voiceAssistNoSubstitutions(String ingredient) {
    return 'Vi hittade inga ersättningar för $ingredient';
  }

  @override
  String voiceAssistQuantityNotFound(String ingredient) {
    return 'Vi hittade inte $ingredient bland ingredienserna';
  }

  @override
  String voiceAssistStepOutOfRange(int count) {
    return 'Receptet har $count steg';
  }

  @override
  String get voiceAssistRatioHalf => 'halva mängden';

  @override
  String get voiceAssistRatioDouble => 'dubbla mängden';

  @override
  String get voiceAssistRatioOneAndHalf => 'en och en halv gånger mängden';

  @override
  String voiceAssistRatioTimes(String ratio) {
    return '$ratio gånger mängden';
  }

  @override
  String voiceAssistTimeLeft(String duration) {
    return '$duration kvar';
  }

  @override
  String get voiceAssistMissed =>
      'Vi uppfattade inte det. Säg till exempel nästa, eller läs igen';

  @override
  String get voiceAssistMissedTwice =>
      'Vi uppfattade inte det den här gången heller. Knapparna fungerar som vanligt';

  @override
  String voiceAssistHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n timmar',
      one: '1 timme',
    );
    return '$_temp0';
  }

  @override
  String voiceAssistMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minuter',
      one: '1 minut',
    );
    return '$_temp0';
  }

  @override
  String voiceAssistSeconds(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n sekunder',
      one: '1 sekund',
    );
    return '$_temp0';
  }

  @override
  String get voiceAssistAnd => 'och';

  @override
  String get voiceAssistWindowHint => 'Säg ett kommando …';

  @override
  String voiceAssistHeard(String text) {
    return 'Hörde: $text';
  }

  @override
  String get voiceAssistMicTooltip => 'Tala med köksbutlern';

  @override
  String get voiceAssistMuteTooltip => 'Tysta uppläsningen';

  @override
  String get voiceAssistUnmuteTooltip => 'Slå på uppläsningen';

  @override
  String get voiceAssistMicRationaleTitle => 'Mikrofon för köksbutlern';

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
  String menuHiddenByFamilyAllergies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept dolda på grund av hushållets allergier',
      one: '1 recept dolt på grund av hushållets allergier',
    );
    return '$_temp0';
  }

  @override
  String menuHiddenByOwnAllergies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept dolda på grund av dina allergival',
      one: '1 recept dolt på grund av dina allergival',
    );
    return '$_temp0';
  }

  @override
  String get menuAllergenUnknownChip => 'Allergener ej kontrollerade';

  @override
  String get menuNoMoreRecipes => 'Inga fler recept tillgängliga för byte';

  @override
  String get menuGenerateError => 'Kunde inte generera meny';

  @override
  String menuWeekBadgeWithCount(int week, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rätter',
      one: '1 rätt',
    );
    return 'Vecka $week · $_temp0';
  }

  @override
  String get menuToShoppingList => 'Till inköpslista';

  @override
  String menuGeneratedShoppingListName(int week) {
    return 'Inköpslista vecka $week';
  }

  @override
  String get menuShoppingListGenerationEmpty =>
      'Veckomenyn har inga recept med ingredienser ännu';

  @override
  String get menuShoppingListGenerationFailed =>
      'Inköpslistan kunde inte skapas.';

  @override
  String get menuShoppingScaledToPresence =>
      'Mängderna följer vilka som är hemma';

  @override
  String get menuLoadSaved => 'Ladda sparad meny';

  @override
  String get menuClear => 'Rensa meny';

  @override
  String get menuShared => 'Veckomenyn är delad.';

  @override
  String get menuGeneratingOverlay => 'Genererar din veckomeny …';

  @override
  String get menuGeneratingSubtitle =>
      'Hittar recept som passar dina preferenser';

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
  String get syncComplete => 'Synkroniseringen är klar.';

  @override
  String syncFailed(String error) {
    return 'Synkroniseringen misslyckades. Dina ändringar finns kvar på telefonen. Försök igen.';
  }

  @override
  String get offlineShowingLocal => 'Offline-läge – visar lokala recept';

  @override
  String get recipeCreateCopy => 'Skapa kopia';

  @override
  String recipeDuplicateTitle(String title) {
    return '$title (kopia)';
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
  String get recipeViewCapturedSource => 'Visa källtext';

  @override
  String get recipeSourceSheetTitle => 'Källtext';

  @override
  String recipeSourceCapturedAt(String time) {
    return 'Sparad $time';
  }

  @override
  String get recipeSourceTypeUrl => 'Käll-URL';

  @override
  String get recipeSourceTypeYoutube => 'YouTube-transkript';

  @override
  String get recipeSourceTypeTiktok => 'TikTok-text';

  @override
  String get recipeSourceTypeInstagram => 'Instagram-text';

  @override
  String get recipeSourceTypeTextPaste => 'Inklistrad text';

  @override
  String get recipeSourceTypePhotoOcr => 'Text från foto';

  @override
  String get recipeSourceTypeVoiceDictation => 'Intalat recept';

  @override
  String get recipeSourceReextract => 'Återhämta från källa';

  @override
  String get recipeSourceReextractConfirmTitle => 'Återhämta receptet?';

  @override
  String get recipeSourceReextractConfirmMessage =>
      'Det här skriver över receptets nuvarande innehåll med en ny extrahering från källan. Det går inte att ångra.';

  @override
  String get recipeSourceReextractConfirmAction => 'Återhämta';

  @override
  String get recipeSourceReextractInProgress => 'Återhämtar från källan …';

  @override
  String get recipeSourceReextractSuccess =>
      'Receptet återhämtades från källan';

  @override
  String get recipeSourceReextractFailed =>
      'Kunde inte återhämta från källan. Receptet är oförändrat.';

  @override
  String get recipeSourceStaleBanner =>
      'Källan sparades för länge sedan – en ny extrahering kan skilja sig från originalet.';

  @override
  String get recipeShareWithFriends => 'Dela med vänner';

  @override
  String get recipeShareExternal => 'Dela externt';

  @override
  String recipeSourceFrom(String host) {
    return 'Från $host';
  }

  @override
  String recipeSourceCardTitle(String site) {
    return 'Hämtat från $site';
  }

  @override
  String recipeSourceAuthor(String author) {
    return 'Av $author';
  }

  @override
  String get recipeSourceOpenOriginal => 'Öppna originalet';

  @override
  String recipeBorrowedImageCredit(String site) {
    return 'Bild: $site';
  }

  @override
  String a11yRecipeSourceCard(String site) {
    return 'Receptet är hämtat från $site';
  }

  @override
  String a11yRecipeSourceCardWithAuthor(String site, String author) {
    return 'Receptet är hämtat från $site, av $author';
  }

  @override
  String a11yRecipeBorrowedImageCredit(String site) {
    return 'Bilden visas från $site';
  }

  @override
  String get errorCouldNotOpenLink => 'Kunde inte öppna länk';

  @override
  String get errorInvalidLink => 'Ogiltig länk';

  @override
  String shoppingItemRemoved(String name) {
    return '$name är borttagen.';
  }

  @override
  String shoppingItemRemoveError(String name) {
    return 'Kunde inte ta bort $name';
  }

  @override
  String get shoppingAllUnchecked => 'Alla varor är avbockade.';

  @override
  String get shoppingNoListForRename => 'Ingen lista vald för att byta namn';

  @override
  String get shoppingNoListForDelete => 'Ingen lista vald för borttagning';

  @override
  String get commonBack => 'Tillbaka';

  @override
  String commonBackTo(String destination) {
    return 'Tillbaka till $destination';
  }

  @override
  String get commonEnable => 'Aktivera';

  @override
  String get commonDisable => 'Inaktivera';

  @override
  String get commonName => 'Namn';

  @override
  String get commonErrorOccurred => 'Det gick inte att slutföra';

  @override
  String get commonContinue => 'Fortsätt';

  @override
  String get a11yRecipeMoreActions => 'Fler receptåtgärder';

  @override
  String get commonNext => 'Nästa';

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
  String get settingsHouseholdSizeHint =>
      'Recept öppnas förinställda på så här många portioner. Portionsval på ett recept gäller alltid före.';

  @override
  String get householdSizeRecipeDefault => 'Receptets standard';

  @override
  String get householdSizeUseRecipeDefault => 'Använd receptets standard';

  @override
  String get householdAllergenFilterTitle => 'Filtrera menyn på hela hushållet';

  @override
  String get householdAllergenFilterSubtitleOn =>
      'Veckomenyn tar hänsyn till allergier och kost för alla i hushållet.';

  @override
  String get householdAllergenFilterSubtitleOff =>
      'Menyn tar just nu bara hänsyn till dina egna allergier.';

  @override
  String get householdAllergenOffTitle => 'Stänga av hushållsfiltret?';

  @override
  String householdAllergenOffBody(String allergens) {
    return 'Då planeras veckomenyn bara utifrån dina egna allergier. Recept med $allergens – som någon i hushållet, även ett barn, behöver undvika – kan då planeras in i veckomenyn. Filtret kan slås på igen när som helst.';
  }

  @override
  String get householdAllergenOffBodyGeneric =>
      'Då planeras veckomenyn bara utifrån dina egna allergier. Recept som någon annan i hushållet – även ett barn – behöver undvika kan då planeras in i veckomenyn. Filtret kan slås på igen när som helst.';

  @override
  String get householdAllergenRosterIncomplete =>
      'Vi kunde inte läsa alla i hushållet just nu, så listan över allergier kan vara ofullständig.';

  @override
  String get householdAllergenShareTitle => 'Dela mina allergier med hushållet';

  @override
  String get householdAllergenShareSubtitleOff =>
      'Hushållet gissar just nu åt dig';

  @override
  String get householdAllergenShareSubtitleOn =>
      'Hushållets meny räknar med dina allergier';

  @override
  String get householdAllergenShareConfirmTitle => 'Dela din allergilista';

  @override
  String get householdAllergenShareConfirmBody =>
      'Hushållet får se vilka allergier och kostval du har angett, så att veckomenyn kan planeras runt dem. I dag gissar Butlery åt dig – den räknar med fyra vanliga allergier och missar resten.\n\nAlla som är med i hushållet ser listan, även den som går med senare.\n\nListan visas som en gemensam lista för hela hushållet. Ingen ser vilken allergi som är vems.\n\nKostval räknas som ett krav när menyn planeras: delar du ”vegansk” planeras hela hushållets meny vegansk.\n\nDu kan sluta dela när som helst. Då tas listan bort direkt, och menyn går tillbaka till att vara försiktig åt dig.';

  @override
  String get householdAllergenShareConfirmAction => 'Dela';

  @override
  String get householdAllergenShareStopped =>
      'Din allergilista delas inte längre. Menyn är försiktig åt dig igen.';

  @override
  String get householdAllergenShareSettingsUnread =>
      'Vi kunde inte läsa dina egna allergiinställningar. Kontrollera nätet och försök igen.';

  @override
  String get householdAllergenShareFailed =>
      'Det gick inte att ändra delningen just nu. Försök igen.';

  @override
  String get commonTurnOff => 'Stäng av';

  @override
  String get commonListAnd => 'och';

  @override
  String get settingsSaveFailed => 'Det gick inte att spara. Försök igen.';

  @override
  String get a11yDecreaseHouseholdSize => 'Minska hushållets storlek';

  @override
  String get a11yIncreaseHouseholdSize => 'Öka hushållets storlek';

  @override
  String get settingsLanguageTitle => 'Språk';

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
  String get personalTagCreateTag => 'Skapa tagg';

  @override
  String get personalTagCreateGroup => 'Skapa grupp';

  @override
  String get personalTagEmptyTitle => 'Inga egna taggar';

  @override
  String get personalTagEmptySubtitle =>
      'Skapa taggar för att organisera dina recept';

  @override
  String get personalTagSectionTags => 'Taggar';

  @override
  String get personalTagDeleteGroup => 'Radera gruppen';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count regler',
      one: '1 regel',
    );
    return '$_temp0';
  }

  @override
  String personalTagRuleCountActive(int enabled, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'regler',
      one: 'regel',
    );
    return '$enabled av $total $_temp0 på';
  }

  @override
  String get personalTagNoUsage => 'Ingen användning';

  @override
  String get personalTagEnableAllRules => 'Aktivera alla regler';

  @override
  String get personalTagDisableAllRules => 'Inaktivera alla regler';

  @override
  String get personalTagMoveToGroup => 'Flytta till grupp';

  @override
  String get personalTagEnableAllRulesConfirm => 'Aktivera alla regler?';

  @override
  String get personalTagDisableAllRulesConfirm => 'Inaktivera alla regler?';

  @override
  String personalTagEnableAllRulesMessage(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alla $count regler för ”$name” kommer att aktiveras.',
      one: 'Regeln för ”$name” kommer att aktiveras.',
    );
    return '$_temp0';
  }

  @override
  String personalTagDisableAllRulesMessage(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alla $count regler för ”$name” kommer att inaktiveras.',
      one: 'Regeln för ”$name” kommer att inaktiveras.',
    );
    return '$_temp0';
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
  String get personalTagNameHint => 'Till exempel Favoriter';

  @override
  String get personalTagCreated => 'Tagg skapad';

  @override
  String get personalTagCouldNotCreate => 'Kunde inte skapa taggen';

  @override
  String get personalTagGroupNameLabel => 'Gruppnamn';

  @override
  String get personalTagGroupNameHint => 'Till exempel Middagar';

  @override
  String get personalTagGroupCreated => 'Grupp skapad';

  @override
  String get personalTagCouldNotCreateGroup => 'Kunde inte skapa gruppen';

  @override
  String personalTagDeleteTagMessageWithCount(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Den tas bort från $count recept.',
      one: 'Den tas bort från 1 recept.',
      zero: 'Inga recept påverkas.',
    );
    return 'Vill du radera ”$name”? $_temp0';
  }

  @override
  String get personalTagMergeAction => 'Slå ihop';

  @override
  String get personalTagMergeTitle => 'Slå ihop taggar';

  @override
  String personalTagMergeMessage(int count, String target) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count taggar slås ihop till «$target». Övriga tas bort och recepten flyttas.',
      two:
          '2 taggar slås ihop till «$target». Den andra tas bort och recepten flyttas.',
    );
    return '$_temp0';
  }

  @override
  String get personalTagMergeKeepLabel => 'Behåll denna tagg:';

  @override
  String get personalTagMergeConfirm => 'Slå ihop';

  @override
  String personalTagMergeSuccessCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taggar sammanslagna',
      one: '1 tagg sammanslagen',
    );
    return '$_temp0';
  }

  @override
  String personalTagBulkDeleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Radera $count taggar?',
      one: 'Radera 1 tagg?',
    );
    return '$_temp0';
  }

  @override
  String personalTagBulkDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Taggarna tas bort från alla recept som använder dem.',
      one: 'Taggen tas bort från alla recept som använder den.',
    );
    return '$_temp0';
  }

  @override
  String personalTagBulkDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taggar raderade',
      one: '1 tagg raderad',
    );
    return '$_temp0';
  }

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
  String get personalTagDeleteGroupConfirm => 'Radera gruppen?';

  @override
  String personalTagDeleteGroupMessage(String name) {
    return 'Vill du radera ”$name”? Taggar i gruppen blir ogrupperade.';
  }

  @override
  String get personalTagGroupDeleted => 'Gruppen raderad';

  @override
  String get personalTagSortByName => 'Namn';

  @override
  String get personalTagSortByUsage => 'Användning';

  @override
  String get personalTagSortByRuleCount => 'Antal regler';

  @override
  String get tagDetailDefaultTitle => 'Tagg';

  @override
  String get tagDetailNotFound => 'Taggen kunde inte hittas';

  @override
  String get tagDetailNameHint => 'Taggnamn';

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
  String get tagDetailDeleteRuleConfirm => 'Radera regeln?';

  @override
  String tagDetailDeleteRuleMessage(String name) {
    return 'Vill du radera ”$name”?';
  }

  @override
  String get tagDetailRuleDeleted => 'Regeln raderad';

  @override
  String get tagDetailCouldNotDeleteRule => 'Kunde inte radera regeln';

  @override
  String get tagDetailApplyingRules => 'Kör regler på recept …';

  @override
  String tagDetailRulesAppliedSuccess(int tagsApplied, int recipesModified) {
    String _temp0 = intl.Intl.pluralLogic(
      tagsApplied,
      locale: localeName,
      other: '$tagsApplied taggar tillämpade',
      one: '1 tagg tillämpad',
    );
    return '$_temp0 på $recipesModified recept';
  }

  @override
  String get tagDetailNoRecipesMatched => 'Inga recept matchade reglerna';

  @override
  String get tagDetailCouldNotApplyRules => 'Kunde inte köra regler';

  @override
  String get tagDetailDeleteTagConfirm => 'Radera taggen?';

  @override
  String get tagDetailDeleted => 'Taggen raderad';

  @override
  String get tagDetailCouldNotDelete => 'Kunde inte radera taggen';

  @override
  String get tagDetailRuleCalculating => 'Beräknar …';

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
  String get tagDetailRuleOperatorAnd => ' och ';

  @override
  String get tagDetailRuleOperatorOr => ' eller ';

  @override
  String tagDetailRuleMoreConditions(int count) {
    return '(+$count till)';
  }

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
  String get tagWriteTagHint => 'Skriv en tagg …';

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
  String get settingsAutoAddPantryTitle => 'Lägg köpta varor i skafferiet';

  @override
  String get settingsAutoAddPantrySubtitle =>
      'När du bockar av en vara läggs den automatiskt i ditt skafferi';

  @override
  String get pantryAutoAddPromptTitle => 'Lägg till i skafferiet automatiskt?';

  @override
  String get pantryAutoAddPromptBody =>
      'Vill du att köpta varor läggs till i skafferiet automatiskt när du bockar av dem? Du kan ändra detta senare under Appinställningar.';

  @override
  String get pantryAutoAddPromptEnable => 'Ja, lägg till automatiskt';

  @override
  String get pantryAutoAddPromptDecline => 'Inte nu';

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
  String get allergenDisplayCoverageSubtitle =>
      'Visa hur stor andel ingredienser som är kända';

  @override
  String get allergenSaveSettings => 'Spara inställningar';

  @override
  String get allergenResetToDefaults => 'Återställ till standard';

  @override
  String get allergenSettingsSaved => 'Inställningarna sparades';

  @override
  String get notificationSettingsSaved => 'Inställningarna sparades';

  @override
  String get tierFailureRateLimited =>
      'Daglig gräns nådd. Försök igen i morgon.';

  @override
  String get tierFailureNoData => 'Kunde inte hitta receptinformation.';

  @override
  String get tierFailureInvalidResponse => 'AI-svaret kunde inte tolkas.';

  @override
  String get tierFailureSchemaValidation => 'Receptet hade ogiltiga värden.';

  @override
  String get tierFailureParseError => 'Ett tekniskt fel uppstod.';

  @override
  String get tierFailureTimeout => 'Tidsgränsen överskreds. Försök igen.';

  @override
  String get tierFailureNetworkError =>
      'Nätverksfel. Kontrollera din anslutning.';

  @override
  String get tierFailureSecurityBlocked =>
      'Innehållet blockerades av säkerhetsskäl.';

  @override
  String get tierFailureInputTooLarge => 'Texten är för lång för bearbetning.';

  @override
  String get tierFailureDeadlineExceeded => 'Bearbetningen tog för lång tid.';

  @override
  String get allergenReset => 'Återställ';

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
  String get ruleEditTitle => 'Redigera regel';

  @override
  String get ruleCreateTitle => 'Skapa regel';

  @override
  String get ruleNewTitle => 'Ny regel';

  @override
  String get ruleNameLabel => 'Regelnamn';

  @override
  String get ruleNameHint => 'Till exempel ”Fiskrecept”';

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
  String get ruleConditionsLabel => 'Villkor';

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
  String get ruleSelectProperty => 'Välj egenskap …';

  @override
  String get ruleAllConditionsNeedValue => 'Alla villkor måste ha ett värde';

  @override
  String get ruleHintIngredient => 'Till exempel ”kyckling”, ”lax”';

  @override
  String get ruleHintProperty => 'Till exempel ”seafood”, ”meat”, ”dairy”';

  @override
  String get ruleHintKeyword => 'Till exempel ”snabb”, ”vegetarisk”';

  @override
  String get ruleHintSourceUrl => 'Till exempel ”bbc.com”, ”reddit.com”';

  @override
  String get ruleHintCuisine => 'Till exempel ”italian”, ”asian”';

  @override
  String get ruleHintDietary => 'Till exempel ”vegetarian”, ”vegan”';

  @override
  String get ruleHintTime => 'Tid att laga, i minuter';

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
      'Till exempel ”personal”, ”shared”, ”collaborative”';

  @override
  String get ruleHintHasImage => 'true eller false';

  @override
  String get ruleHintCompleteness =>
      'Till exempel ”description”, ”ingredients”';

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
  String rulePropertyRetired(String property) {
    return '$property – inte längre giltig';
  }

  @override
  String get tagResultNoAllergens => 'Inga av dina allergener hittades';

  @override
  String get tagResultOutdated => 'Taggarna kan uppdateras';

  @override
  String get tagResultCoverage => 'Täckning';

  @override
  String tagResultUnknownIngredients(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count okända ingredienser',
      one: '1 okänd ingrediens',
    );
    return '$_temp0';
  }

  @override
  String tagResultUncertainTags(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ingredienser okända',
      one: '1 ingrediens okänd',
    );
    return 'Osäkra taggar, $_temp0';
  }

  @override
  String tagResultUnknownIngredientsA11y(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count okända ingredienser',
      one: '1 okänd ingrediens',
    );
    return '$_temp0';
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
    return '$name: ej kontrollerat';
  }

  @override
  String dietaryStatusNotLabel(String name) {
    return 'Ej $name';
  }

  @override
  String dietaryStatusUnknownLabel(String name) {
    return '$name: ej kontrollerat';
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
    return '$name: ej kontrollerat';
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
    return '$name: ej kontrollerat';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
    );
    return 'Största kategori: $name ($_temp0)';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar totalt',
      one: '1 medlem totalt',
    );
    return '$_temp0';
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
    String _temp1 = intl.Intl.pluralLogic(
      friends,
      locale: localeName,
      other: '$friends vänner',
      one: '1 vän',
    );
    return '$_temp0 ($_temp1)';
  }

  @override
  String friendCategoriesSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kategorier valda',
      one: '1 kategori vald',
    );
    return '$_temp0';
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
      'Laddar vänner och kategorier …';

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
  String get shoppingLists => 'Inköpslistor';

  @override
  String get shoppingNewList => 'Ny lista';

  @override
  String shoppingNewListNameTemplate(String title) {
    return '$title – Ingredienser';
  }

  @override
  String shoppingListCreated(String name) {
    return 'Lista ”$name” skapad';
  }

  @override
  String get profileEditProfile => 'Redigera profil';

  @override
  String get profileSharedWithMe => 'Delat med mig';

  @override
  String get profileDownloadBackup => 'Ladda ner säkerhetskopia';

  @override
  String get profileRestoreFromBackup => 'Återställ från säkerhetskopia';

  @override
  String get profilePrivacyPolicy => 'Integritetspolicy';

  @override
  String profileBackupFailed(String error) {
    return 'Säkerhetskopian kunde inte skapas. Dina recept finns kvar. Försök igen.';
  }

  @override
  String get profileBackupNotSaved => 'Säkerhetskopian kunde inte sparas.';

  @override
  String get profileBackupRecipesKept => 'Dina recept finns kvar i appen.';

  @override
  String get profileRestoreNotRead => 'Säkerhetskopian kunde inte läsas in.';

  @override
  String get profileRestoreNothingRemoved => 'Inga recept har raderats.';

  @override
  String get profileRestoreCompleted => 'Återställningen är genomförd.';

  @override
  String profileRestoreFailed(String error) {
    return 'Återställningen misslyckades. Inget har ändrats. Försök igen.';
  }

  @override
  String get shareRecipeTitle => 'Dela recept';

  @override
  String get shareMenuTitle => 'Dela meny';

  @override
  String get shareShoppingListTitle => 'INKÖPSLISTA';

  @override
  String get shareCreateAndShare => 'Skapa och dela';

  @override
  String get shareRecipeWithFriends => 'Dela recept med vänner';

  @override
  String get shareMenuWithFriends => 'Dela veckomeny med vänner';

  @override
  String get shareShoppingList => 'Dela inköpslista';

  @override
  String get shareTagWithFriends => 'Dela tagg med vänner';

  @override
  String get shareTag => 'Dela tagg';

  @override
  String get shareSelectAtLeastOneFriend => 'Välj vem du vill dela med.';

  @override
  String shareRecipesInCategories(int recipes, int categories) {
    String _temp0 = intl.Intl.pluralLogic(
      categories,
      locale: localeName,
      other: '$categories kategorier',
      one: '1 kategori',
    );
    return '$recipes recept i $_temp0';
  }

  @override
  String get shareNoFriendsToShareWith => 'Inga vänner att dela med';

  @override
  String get shareAddFriendsToShare =>
      'Du behöver lägga till vänner för att kunna dela innehåll. Gå till din profil och lägg till vänner.';

  @override
  String get shareAddFriends => 'Lägg till vänner';

  @override
  String get shareSucceeded => 'Delningen är klar.';

  @override
  String get shareMessageOptional => 'Meddelande (valfritt)';

  @override
  String get shareWriteMessage => 'Skriv ett meddelande …';

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
      'Alla kan lägga till och bocka av varor i realtid';

  @override
  String get shareSelectRecipients => 'Välj mottagare';

  @override
  String get shareSearchFriends => 'Sök bland vänner …';

  @override
  String get shareSearchGroups => 'Sök bland grupper …';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
    );
    return 'Delat recept · $_temp0';
  }

  @override
  String socialSharedMenuMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
    );
    return 'Delad meny · $_temp0';
  }

  @override
  String get socialActiveCollaboration => 'Aktivt samarbete';

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
  String get socialPermissionEditor => 'Redigerare';

  @override
  String get socialPermissionViewer => 'Läsare';

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
  String get socialLoadingCategories => 'Laddar kategorier …';

  @override
  String get socialInvertLabel => 'Invertera';

  @override
  String get invitationNoTargetsAvailable => 'Inga målgrupper tillgängliga';

  @override
  String get invitationSearchTargets => 'Sök målgrupper …';

  @override
  String get invitationSelectedTargets => 'Valda målgrupper';

  @override
  String invitationTargetsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count målgrupper valda',
      one: '1 målgrupp vald',
    );
    return '$_temp0';
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
  String get invitationView => 'Visa';

  @override
  String get invitationSendInvitation => 'Skicka inbjudan';

  @override
  String get invitationInvite => 'Inbjud';

  @override
  String get invitationLoadingTargets => 'Laddar målgrupper …';

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
  String get invitationTargetsLoaded => 'Målgrupperna är laddade.';

  @override
  String get invitationNoSearchResults => 'Inga sökresultat';

  @override
  String invitationNoResultsFor(String query) {
    return 'Inga resultat för ”$query”';
  }

  @override
  String invitationTargetsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count mål valda',
      one: '1 mål valt',
    );
    return '$_temp0';
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
  String get commonFailed => 'Misslyckades';

  @override
  String get commonImporting => 'Importerar …';

  @override
  String get commonPending => 'Väntar';

  @override
  String get commonRefresh => 'Uppdatera';

  @override
  String get commonRemove => 'Ta bort';

  @override
  String get commonSending => 'Skickar …';

  @override
  String get commonUndo => 'Ångra';

  @override
  String get commonUploading => 'Laddar upp …';

  @override
  String get authLogIn => 'Logga in';

  @override
  String get collaborativeListNoAccess =>
      'Listan kanske har tagits bort eller så har du inte tillgång längre';

  @override
  String get collaborativeListNotFound => 'Lista hittades inte';

  @override
  String get collaborativeLoadingSharedList => 'Laddar gemensam lista …';

  @override
  String get commentCouldNotPost => 'Kunde inte posta kommentaren';

  @override
  String get commentPosted => 'Kommentar postad';

  @override
  String recipeCommentVisibleTo(String audience) {
    return 'Synlig för: $audience';
  }

  @override
  String recipeCommentVisiblePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personer',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get recipeCommentAudienceTitle => 'Synlig för';

  @override
  String recipeCommentAudienceOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'och $count personer till',
      one: 'och 1 person till',
    );
    return '$_temp0';
  }

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
  String get commentAttachImage => 'Bifoga bild';

  @override
  String get commentImageUploadError =>
      'Kunde inte ladda upp bilden. Försök igen.';

  @override
  String get a11yCommentImageThumbnail => 'Visa bifogad bild i helskärm';

  @override
  String get a11yCommentRemoveSelectedImage => 'Ta bort vald bild';

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
  String get dialogCreateNewListForIngredients =>
      'Skapa en ny lista för dessa ingredienser';

  @override
  String get dialogEnterListName => 'Ange ett namn för listan';

  @override
  String dialogFilteredRecipeCount(int filtered, int total) {
    return '$filtered av $total recept';
  }

  @override
  String get dialogImportWithoutAi => 'Importera utan AI';

  @override
  String dialogItemsProgress(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total klara',
      one: '1 klar',
    );
    return '$completed/$_temp0';
  }

  @override
  String get dialogLoadingRecipes => 'Laddar recept …';

  @override
  String get dialogManualImport => 'Manuell import';

  @override
  String get dialogMarkIngredientsYourself => 'Markera ingredienser själv';

  @override
  String get dialogMayTakeAWhile => 'Detta kan ta en stund …';

  @override
  String get dialogNameMinTwoChars => 'Namnet måste vara minst 2 tecken';

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
  String get dialogPrivate => 'Privat';

  @override
  String dialogRetryInHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours timmar',
      one: '1 timme',
    );
    return 'Försök igen om $_temp0';
  }

  @override
  String dialogRetryInMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuter',
      one: '1 minut',
    );
    return 'Försök igen om $_temp0';
  }

  @override
  String dialogRetryInSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds sekunder',
      one: '1 sekund',
    );
    return 'Försök igen om $_temp0';
  }

  @override
  String get dialogRetryLater => 'Försök senare';

  @override
  String get dialogRetryTomorrow => 'Försök igen i morgon';

  @override
  String get dialogSearchRecipes => 'Sök recept …';

  @override
  String get dialogSearchRecipesToAdd => 'Sök recept att lägga till …';

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
  String get dialogSharing => 'Delar …';

  @override
  String get dialogShoppingListNameHint =>
      'Till exempel ”Pannkakor – Ingredienser”';

  @override
  String get dialogUsesSimpleExtraction => 'Använder enklare extrahering';

  @override
  String get draftDiscardAll => 'Släng alla';

  @override
  String get groupContentTypeContent => 'Innehåll';

  @override
  String get groupContentTypeMenu => 'Meny';

  @override
  String get groupContentTypeRecipe => 'Recept';

  @override
  String get groupContentTypeShoppingList => 'Inköpslista';

  @override
  String get groupCouldNotFetchMenu => 'Kunde inte hämta meny från servern';

  @override
  String get groupCouldNotFetchRecipe => 'Kunde inte hämta recept från servern';

  @override
  String get groupCreateNew => 'Skapa ny grupp';

  @override
  String get groupDeleteTheGroup => 'Radera gruppen';

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
  String get groupImport => 'Importera';

  @override
  String get groupInvitationNote =>
      'Dessa vänner kommer att få en inbjudan till gruppen.';

  @override
  String get groupIsEmpty => 'Gruppen är tom';

  @override
  String get groupNameHint => 'Till exempel ”Familjen”, ”Jobbet”, ”Bokklubben”';

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
    return 'Du är ensam kvar i ”$name”.';
  }

  @override
  String groupRecipeImportedSuccess(String title) {
    return 'Receptet ”$title” har importerats';
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
  String groupSharedBy(String name) {
    return 'Delad av $name';
  }

  @override
  String get groupSharedContent => 'Delat i gruppen';

  @override
  String get groupTransferOwnership => 'Överför gruppägande';

  @override
  String groupTransferOwnershipMessage(String name) {
    return 'Du är ägare av ”$name”. Du måste välja en ny ägare innan du kan lämna gruppen.';
  }

  @override
  String get groupView => 'Visa';

  @override
  String get profileExportData => 'Exportera mina data';

  @override
  String get profileExportDataSubtitle =>
      'Ladda ner all din data i JSON-format (GDPR)';

  @override
  String get rateLimitAiBudget => 'AI-budget förbrukad';

  @override
  String get rateLimitAiLimit => 'AI-gräns nådd';

  @override
  String get rateLimitDailyQuota => 'Dagskvot uppnådd';

  @override
  String get rateLimitSlowDown => 'Sakta ner lite';

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
  String shareTagMessage(String contentName) {
    return 'Kolla in min tagg ”$contentName”';
  }

  @override
  String shareFriendsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vänner valda',
      one: '1 vän vald',
    );
    return '$_temp0';
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
  String shareSuccessMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personer',
      one: '1 person',
    );
    return 'Delat med $_temp0.';
  }

  @override
  String shareSuccessMessageGroups(int count) {
    return 'Delat med $count mottagare.';
  }

  @override
  String get shareSuccessLiveNote => 'Ändringar syns för alla.';

  @override
  String get uploadFailed => 'Bilduppladdning misslyckades';

  @override
  String uploadFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bilder',
      one: '1 bild',
    );
    return '$_temp0 kunde inte laddas upp.\n\nVad vill du göra?';
  }

  @override
  String get uploadInProgress => 'Bilduppladdning pågår';

  @override
  String uploadMixedStatus(int failedCount, int pendingCount) {
    return 'Några bilder kunde inte laddas upp ($failedCount) och andra laddas fortfarande upp ($pendingCount).\n\nVad vill du göra?';
  }

  @override
  String uploadPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bilder',
      one: '1 bild',
    );
    return '$_temp0 laddas fortfarande upp.\n\nVad vill du göra?';
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
  String get consentDataProcessing => 'Databehandling';

  @override
  String get consentAnalytics => 'Analys';

  @override
  String get consentAnalyticsDescription =>
      'Hur appen används, aldrig vad du lagar.';

  @override
  String get consentWhatWeLog => 'Vad vi loggar';

  @override
  String get consentWhatWeLogIntro =>
      'Anonyma händelser vi loggar för att förbättra appen:';

  @override
  String get consentLogCategoryUsage => 'Appanvändning';

  @override
  String get consentLogCategoryRecipes => 'Recept';

  @override
  String get consentLogCategoryMenuShopping => 'Veckomeny & inköp';

  @override
  String get consentLogCategoryImport => 'Import';

  @override
  String get consentLogCategorySocial => 'Socialt';

  @override
  String get consentLogCategoryOnboarding => 'Introduktion';

  @override
  String get consentPushNotifications => 'Push-notiser';

  @override
  String get consentPushNotificationsDescription =>
      'Systemets tillåtelse styrs separat, i inställningarna.';

  @override
  String get consentSaved => 'Samtycken har sparats';

  @override
  String get consentRevokeAllTitle => 'Återkalla alla valfria samtycken?';

  @override
  String get consentRevokeAllMessage =>
      'Detta kommer att inaktivera alla valfria funktioner som analysdata, sociala funktioner och push-notiser. Du kan aktivera dem igen när som helst.';

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
  String get dataExportGdprDescription =>
      'Du har rätt att få ut dina uppgifter i ett format som går att läsa och flytta. Filen är JSON.';

  @override
  String get dataExportExporting => 'Exporterar dina data …';

  @override
  String get dataExportMayTakeSeconds => 'Detta kan ta några sekunder';

  @override
  String get dataExportFailed => 'Export misslyckades';

  @override
  String get dataExportSaveFile => 'Spara fil';

  @override
  String get dataExportClear => 'Rensa export';

  @override
  String get dataExportWhatsIncluded => 'Det här följer med';

  @override
  String get dataExportIncludesProfile => 'Profil och inställningar';

  @override
  String get dataExportIncludesLists => 'Inköpslistor och menyer';

  @override
  String get dataExportIncludesAuditLogs =>
      'Säkerhets- och åtkomsthistorik (GDPR Artikel 15)';

  @override
  String get dataExportSharedDataNote =>
      'OBS: Exporten innehåller din egen data. För det du har gemensamt med andra, som delade inköpslistor, konversationer och notiser, ingår även vissa uppgifter om dem, till exempel namn eller användar-id.';

  @override
  String get dateToday => 'I dag';

  @override
  String get dateYesterday => 'I går';

  @override
  String dateDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagar',
      one: '1 dag',
    );
    return '$_temp0 sedan';
  }

  @override
  String get friendDecline => 'Avböj';

  @override
  String get friendRequestTitle => 'Vänförfrågan';

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
  String get imageTapToLoad => 'Tryck för att ladda';

  @override
  String get imageUploadingImages => 'Laddar upp bilder';

  @override
  String get imageUploadPreparing => 'Förbereder …';

  @override
  String get imageUseCameraForNewPhoto =>
      'Använd kameran för att ta en ny bild';

  @override
  String get importAddIngredient => 'Lägg till ingrediens';

  @override
  String get importAddStep => 'Lägg till steg';

  @override
  String get importAllergenSetupBanner =>
      'Det här receptet innehåller allergener du inte ställt in. Ställ in dina allergener så flaggar vi dem åt dig automatiskt.';

  @override
  String get importAllergenSetupCta => 'Ställ in';

  @override
  String get importNotRecipeTitle => 'Ser inte ut som ett recept';

  @override
  String get importNotRecipeBody =>
      'Den här texten verkar inte innehålla ett recept. Att importera ändå ger kanske inget användbart resultat. Importera ändå?';

  @override
  String get importNotRecipeConfirm => 'Importera ändå';

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
  String get importFieldsNeedReviewPrefix => 'Kontrollera';

  @override
  String menuCardMoreRecipes(int count) {
    return '+ $count recept till';
  }

  @override
  String get menuCardNoRecipes => 'Inga recept i menyn';

  @override
  String get menuCardGeneratedTitle => 'Genererad meny';

  @override
  String get menuCardUntitled => 'Namnlös meny';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personer',
      one: '1 person',
    );
    return 'Delad med $_temp0';
  }

  @override
  String get searchHint => 'Sök …';

  @override
  String get searchNothingYet => 'Inget att söka i ännu';

  @override
  String shareFriendsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vänner valda',
      one: '1 vän vald',
    );
    return '$_temp0';
  }

  @override
  String shareGroupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
    );
    return '$_temp0';
  }

  @override
  String get shareTabFriends => 'Vänner';

  @override
  String get shareTabGroups => 'Grupper';

  @override
  String get shoppingCardComplete => 'Klar';

  @override
  String shoppingCardCompleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count slutförda',
      one: '1 slutförd',
    );
    return '$_temp0';
  }

  @override
  String get shoppingCardItemsOnList => 'Föremål på listan:';

  @override
  String shoppingCardMoreItems(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count varor till',
      one: '1 vara till',
    );
    return '+ $_temp0';
  }

  @override
  String get shoppingCardNoItems => 'Inga föremål i listan';

  @override
  String get shoppingCardSharedList => 'Delad lista';

  @override
  String shoppingCardSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personer',
      one: '1 person',
    );
    return 'Delad med $_temp0';
  }

  @override
  String get adminYouAreAdmin => 'Du är administratör';

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
    return 'Filen kunde inte sparas. Försök igen.';
  }

  @override
  String dataExportCouldNotShare(String error) {
    return 'Filen kunde inte delas. Försök igen.';
  }

  @override
  String get dataExportExportedSuccessfully => 'Data exporterad';

  @override
  String dataExportFileSaved(String fileName) {
    return 'Fil sparad: $fileName';
  }

  @override
  String get dataExportShareSubject => 'Butlery dataexport';

  @override
  String get dataExportShareText => 'Min exporterade data från Butlery app';

  @override
  String get dialogAmountHint => 'Ange antal …';

  @override
  String get dialogAmountInvalid => 'Ogiltigt antal';

  @override
  String get dialogAmountLabel => 'Antal';

  @override
  String dialogAmountMax(String max) {
    return 'Max $max tillåtet';
  }

  @override
  String dialogAmountMin(String min) {
    return 'Minst $min krävs';
  }

  @override
  String get dialogAmountRequired => 'Antal krävs';

  @override
  String get dialogDescriptionHint => 'Valfri beskrivning …';

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
  String get importLikely => 'Trolig';

  @override
  String get importAiSuggested => 'Butlerys förslag';

  @override
  String get importNoLinesToShow => 'Inga rader att visa';

  @override
  String importSelectAllHighlighted(int count) {
    return 'Välj alla markerade ($count)';
  }

  @override
  String importSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valda',
      one: '1 vald',
    );
    return '$_temp0';
  }

  @override
  String get importStep => 'Steg';

  @override
  String get importStepAnalyzing => 'Analyserar …';

  @override
  String get importStepCreating => 'Skapar …';

  @override
  String get importStepFetching => 'Hämtar …';

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
  String get menuNameHint => 'Till exempel ”Min veckomeny vecka 45”';

  @override
  String get menuNameYourMenu => 'Namnge din meny';

  @override
  String get menuShareDefaultMessage => 'Ta gärna en titt på min veckomeny.';

  @override
  String get messagingEdited => 'redigerad';

  @override
  String get messagingImageLoadError => 'Bild kunde inte laddas';

  @override
  String get messagingImageLoadFailed => 'Kunde inte ladda bild';

  @override
  String get syncQueueChatImage => 'En bild i en chatt';

  @override
  String get syncQueueReasonChatImageFailed => 'Bilden kunde inte skickas.';

  @override
  String get syncQueueAvatar => 'Ny profilbild';

  @override
  String get syncQueueReasonAvatarFailed => 'Profilbilden kunde inte bytas.';

  @override
  String get profileAvatarWaitsForConnection => 'Sparas när du är online';

  @override
  String get profileAvatarQueuedOffline =>
      'Profilbilden byts när du är online igen.';

  @override
  String get profileAvatarQueueFailed =>
      'Profilen sparades, men den nya bilden kunde inte sparas till senare. Välj den igen.';

  @override
  String get messagingImagePending => 'Bild på väg …';

  @override
  String get messagingImageWaitingToSend => 'Skickas när du är online';

  @override
  String get messagingImageNeverArrived => 'Bilden kom aldrig fram';

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
  String messagingCouldNotLoadFriends(String error) {
    return 'Vännerna kunde inte laddas. Försök igen.';
  }

  @override
  String get friendsLoadFailed => 'Vännerna kunde inte laddas. Försök igen.';

  @override
  String get friendsRefreshFailed =>
      'Vännerna kunde inte uppdateras. Försök igen.';

  @override
  String messagingCouldNotLoadGroupInfo(String error) {
    return 'Gruppens information kunde inte laddas. Försök igen.';
  }

  @override
  String get messagingCouldNotRemoveMember => 'Kunde inte ta bort medlem';

  @override
  String get messagingCouldNotUpdateGroupName =>
      'Kunde inte uppdatera gruppnamn';

  @override
  String get messagingEditGroupName => 'Redigera gruppnamn';

  @override
  String get messagingEnterNewGroupName => 'Ange nytt gruppnamn';

  @override
  String get messagingGroupCreated => 'Gruppkonversationen är skapad.';

  @override
  String get messagingGroupName => 'Gruppnamn';

  @override
  String get messagingGroupNameHint =>
      'Till exempel Min familj, Jobbet, Bästa vännerna …';

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
  String get messagingLoadingFriends => 'Laddar vänner …';

  @override
  String get messagingLoadingGroupInfo => 'Laddar gruppinformation …';

  @override
  String messagingMemberRemoved(String name) {
    return '$name borttagen från gruppen';
  }

  @override
  String get messagingNoFriendsAvailable => 'Inga vänner tillgängliga';

  @override
  String get messagingNoFriendsFound => 'Inga vänner hittades';

  @override
  String get messagingSearchFriends => 'Sök vänner …';

  @override
  String get messagingSelectAtLeastTwoMembers => 'Välj minst 2 medlemmar nedan';

  @override
  String messagingSelectedMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valda',
      one: '1 vald',
    );
    return 'Deltagare · $_temp0';
  }

  @override
  String get messagingTryAnotherKeyword => 'Försök med ett annat sökord';

  @override
  String get mfaEnterCode => 'Ange verifieringskoden';

  @override
  String get mfaInvalidCode => 'Ogiltig kod. Försök igen.';

  @override
  String get mfaSixDigitCode => '6-siffrig kod';

  @override
  String get mfaTitle => 'Tvåstegsverifiering';

  @override
  String get mfaVerificationFailed => 'Verifiering misslyckades';

  @override
  String get mfaVerify => 'Verifiera';

  @override
  String get mfaAccountProtected =>
      'Ditt konto är skyddat med tvåstegsverifiering.';

  @override
  String get mfaActivated => 'Tvåstegsverifiering är på.';

  @override
  String get mfaCouldNotRemove => 'Kunde inte stänga av tvåstegsverifiering';

  @override
  String get mfaDeactivated => 'Tvåstegsverifiering är av';

  @override
  String get mfaEnableForSecurity =>
      'Slå på tvåstegsverifiering för extra säkerhet.';

  @override
  String mfaRegistered(String time) {
    return 'Registrerad $time';
  }

  @override
  String get mfaRegisteredMethods => 'Registrerade metoder';

  @override
  String get mfaRemoveConfirm =>
      'Är du säker på att du vill stänga av tvåstegsverifieringen? Det gör ditt konto mindre säkert.';

  @override
  String get mfaRemoveTitle => 'Stäng av tvåstegsverifiering?';

  @override
  String get mfaRemoveAction => 'Ta bort tvåstegsverifiering';

  @override
  String get realtimeOffline => 'Offline';

  @override
  String get recipeMealType => 'Måltidstyp';

  @override
  String get recipeTitle => 'Titel';

  @override
  String get recipeUpdating => 'Uppdaterar recept …';

  @override
  String chatAddCount(int count) {
    return 'Lägg till ($count)';
  }

  @override
  String get chatAddMembers => 'Lägg till medlemmar';

  @override
  String get chatSearchFriends => 'Sök vänner …';

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
  String get collaborativeSyncAutomatic =>
      'Ändringar synkas automatiskt med andra deltagare';

  @override
  String get conversationAddFriendsFirst =>
      'Lägg till vänner först för att starta konversationer.';

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
  String get conversationSayHi => 'Säg hej.';

  @override
  String get conversationSelectFriendForDM =>
      'Eller välj en vän för direktmeddelande:';

  @override
  String get conversationYouPrefix => 'Du:';

  @override
  String errorLoadingWithDetails(String error) {
    return 'Det gick inte att ladda. Försök igen.';
  }

  @override
  String get errorUnknown => 'Okänt fel';

  @override
  String get imageSelectImage => 'Välj bild';

  @override
  String get imageTitle => 'Bild';

  @override
  String get importColumnCategory => 'Kategori';

  @override
  String get importColumnCookingTime => 'Tid att laga';

  @override
  String get importColumnIngredients => 'Ingredienser';

  @override
  String get importColumnInstructions => 'Instruktioner';

  @override
  String get importColumnServings => 'Portioner';

  @override
  String get importColumnTags => 'Taggar';

  @override
  String get importColumnTitle => 'Titel';

  @override
  String get importAllAlreadyHeld => 'Alla recept i filen finns redan hos dig';

  @override
  String importSkippedDuplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept fanns redan och hoppades över',
      one: '1 recept fanns redan och hoppades över',
    );
    return '$_temp0';
  }

  @override
  String importSkippedOverLimit(int count, int limit) {
    return '$count recept till fanns i filen. Högst $limit importeras åt gången.';
  }

  @override
  String importComplete(int succeeded, int failed) {
    return 'Import klar: $succeeded lyckades, $failed misslyckades';
  }

  @override
  String importFailedCount(int count) {
    return '$count misslyckades';
  }

  @override
  String get importFileColumnsOptional => 'Valfria kolumner:';

  @override
  String get importFileColumnsRequired => 'Din fil bör innehålla kolumner för:';

  @override
  String get importFileColumnsEitherLanguage =>
      'Kolumnrubrikerna kan vara på svenska eller engelska.';

  @override
  String get importFilterAll => 'Alla';

  @override
  String get importFromArchive => 'Importera från Butlerys arkiv';

  @override
  String get importFromFile => 'Importera från fil';

  @override
  String get importFromFileTitle => 'Importera recept från CSV eller Excel';

  @override
  String get importFromSocialMedia => 'Från sociala medier';

  @override
  String get importImporting => 'Importerar …';

  @override
  String importImportingRecipes(int count) {
    return 'Importerar $count recept …';
  }

  @override
  String get importImportingRecipesProgress => 'Importerar recept …';

  @override
  String get importWaitForCompletion => 'Vänta tills importen är klar …';

  @override
  String get importNoFileOrNoRecipes =>
      'Ingen fil vald eller filen innehåller inga recept';

  @override
  String get importNoRecipesMatchedFilters => 'Inga recept matchade filtren';

  @override
  String get importParsingText => 'Tolkar text …';

  @override
  String get importPasteRecipeHint => 'Klistra in recepttext här …';

  @override
  String get importRecipesImported => 'Recepten är importerade.';

  @override
  String get importSearchArchive => 'Sök i arkiv …';

  @override
  String get importSelectFileAndImport => 'Välj fil och importera';

  @override
  String get importSelectingFile => 'Väljer fil …';

  @override
  String importSucceededCount(int count) {
    return '$count lyckades';
  }

  @override
  String get importTryAdjustFilters => 'Prova att justera sökning eller filter';

  @override
  String get indicatorOfflineMode => 'Ingen anslutning';

  @override
  String offlineBannerPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ändringar väntar',
      one: '1 ändring väntar',
    );
    return '$_temp0';
  }

  @override
  String offlineBannerWithPending(String title, String pending) {
    return '$title · $pending';
  }

  @override
  String offlineBannerWithPendingA11y(String title, String pending) {
    return '$title, $pending';
  }

  @override
  String get indicatorBackOnline => 'Ansluten igen';

  @override
  String get householdToggle => 'Det här är hushållet';

  @override
  String get householdToggleDescription =>
      'Hushållets allergier räknas med i menyn';

  @override
  String get householdJoinTitle => 'Gå med i hushållet';

  @override
  String get householdJoinSubtitle =>
      'Sedan kan du välja att dela dina allergier, så att menyn räknar med dem.';

  @override
  String get householdJoinAction => 'Gå med';

  @override
  String get householdJoinConfirmBody =>
      'Du blir medlem i hushållet. Dina allergier delas inte förrän du själv väljer det under Mitt hushåll. Du lämnar hushållet genom att lämna gruppen.';

  @override
  String get householdJoinFailed =>
      'Det gick inte att gå med i hushållet just nu. Försök igen.';

  @override
  String get householdJoinedTitle => 'Du är med i hushållet';

  @override
  String get householdJoinedSubtitle =>
      'Dela dina allergier under Mitt hushåll, så räknar menyn med dem.';

  @override
  String get householdOpenSettings => 'Visa hushållet';

  @override
  String get menuVoteSuggestAlternative => 'Föreslå alternativ';

  @override
  String get menuVoteResolved => 'Omröstning avgjord';

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
  String get menuVoteQuestion => 'Vad blir det?';

  @override
  String menuVoteClosesInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Stänger om $count timmar',
      one: 'Stänger om 1 timme',
    );
    return '$_temp0';
  }

  @override
  String get menuVoteClosesSoon => 'Stänger inom en timme';

  @override
  String menuVoteLateOption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tillagd sent: $count hade redan röstat',
      one: 'Tillagd sent: 1 hade redan röstat',
    );
    return '$_temp0';
  }

  @override
  String get menuVoteProposeOther => 'Föreslå något annat';

  @override
  String get menuVoteDecide => 'Avgör';

  @override
  String menuVoteDecideFor(String recipeName) {
    return 'Välj $recipeName';
  }

  @override
  String get menuVoteTieTitle => 'Oavgjort, kräver ett beslut';

  @override
  String get menuVoteTieStarterBody =>
      'Appen utser ingen vinnare på ett lika resultat. Du startade rösten, så du väljer.';

  @override
  String get menuVoteWaitingOnStarter => 'Väntar på den som startade rösten.';

  @override
  String get menuVoteGiveADay => 'Ge det ett dygn';

  @override
  String get menuVoteDecideAnyway => 'Avgör ändå';

  @override
  String get menuVoteReopen => 'Öppna igen';

  @override
  String get menuVoteRelease => 'Släpp platsen';

  @override
  String get menuVoteNobodyVoted => 'Ingen röstade';

  @override
  String get menuVoteNobodyVotedBody =>
      'Det här är inget oavgjort resultat, utan ett förslag ingen tog i. Ingen rätt läggs på platsen av det.';

  @override
  String get menuVoteApplyFailed => 'Vinnaren kunde inte läggas in i menyn';

  @override
  String get menuVoteSaveFailed => 'Rösten kunde inte sparas';

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
    return 'Sökning: ”$query”';
  }

  @override
  String get invitationSelectTargetsToContinue =>
      'Välj målgrupper från listan ovan för att fortsätta.';

  @override
  String get invitationSendingInvitations => 'Skickar inbjudningar …';

  @override
  String invitationsSentMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count målgrupper',
      one: '1 målgrupp',
    );
    return 'Inbjudningar har skickats till $_temp0.';
  }

  @override
  String get invitationsSentTitle => 'Inbjudningar skickade';

  @override
  String invitationTargetsSelectedForInvitation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count målgrupper',
      one: '1 målgrupp',
    );
    return 'Du har valt $_temp0 för inbjudan.';
  }

  @override
  String get invitationTryDifferentSearch =>
      'Prova att söka med andra ord eller kontrollera stavningen.';

  @override
  String get loadingNoContent => 'Inget innehåll';

  @override
  String get menuCommentLabel => 'Kommentar (valfritt)';

  @override
  String menuDeletedSuccess(String name) {
    return 'Menyn ”$name” raderad';
  }

  @override
  String get menuDeleteFailed => 'Kunde inte radera menyn';

  @override
  String menuLoadedSuccess(String name) {
    return 'Menyn ”$name” är laddad.';
  }

  @override
  String get menuLoadFailed => 'Kunde inte ladda meny';

  @override
  String get menuNameLabel => 'Menynamn';

  @override
  String get menuNameRequired => 'Menynamn krävs';

  @override
  String get menuNoSavedMenusDescription =>
      'Inga sparade menyer ännu. En meny genereras och sparas först.';

  @override
  String menuRecipesInCategories(int recipeCount, int categoryCount) {
    String _temp0 = intl.Intl.pluralLogic(
      categoryCount,
      locale: localeName,
      other: '$categoryCount kategorier',
      one: '1 kategori',
    );
    return '$recipeCount recept i $_temp0';
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
  String get privacyCouldNotLoad => 'Integritetspolicyn kunde inte hämtas.';

  @override
  String get privacyTitle => 'Integritetspolicy';

  @override
  String get recipeAddTags => 'Lägg till taggar';

  @override
  String get recipeChangesSaved => 'Ändringarna är sparade.';

  @override
  String get recipeContinueEditing => 'Fortsätt redigera';

  @override
  String get recipeCopySaved => 'Kopian av receptet är sparad.';

  @override
  String get recipeFromArchive => 'Från arkiv';

  @override
  String get recipeFromFile => 'Från fil';

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
  String get recipeAddIngredientHeading => 'Lägg till rubrik';

  @override
  String get recipeIngredientHeadingHint => 'Rubrik, till exempel Deg';

  @override
  String get a11yRemoveIngredientHeading => 'Ta bort rubrik';

  @override
  String get recipeMoveToSection => 'Flytta till rubrik';

  @override
  String get recipeMoveToSectionNone => 'Ingen rubrik';

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
  String get recipeSwipeHintText =>
      'Tips: svep åt höger för att redigera, åt vänster för att radera';

  @override
  String get cookingStepHintText =>
      'Tips: håll inne ett steg för att starta en timer';

  @override
  String get shoppingClaimHintText =>
      'Tips: svep en vara för att markera att du köper den';

  @override
  String get recipeTagsUpdated => 'Taggar uppdaterade';

  @override
  String get recipeTimeMinutes => 'Tid (min)';

  @override
  String get recipeUnsavedChangesTitle => 'Osparade ändringar';

  @override
  String get recipeWriteManually => 'Skriv manuellt';

  @override
  String get socialTotalMembers => 'Totalt medlemmar';

  @override
  String get chatCannotMessageNonFriend =>
      'Du kan inte skicka meddelanden till denna person';

  @override
  String get chatCouldNotSendMessage => 'Kunde inte skicka meddelandet.';

  @override
  String get chatSendFailedDeviceClockAhead =>
      'Kunde inte skicka. Telefonens klocka ligger för långt fram – kontrollera datum och tid i inställningarna.';

  @override
  String get chatLoadingMessages => 'Laddar meddelanden …';

  @override
  String get chatNoMessages => 'Inga meddelanden än';

  @override
  String get chatSendToStartConversation =>
      'Skicka ett meddelande för att starta konversationen';

  @override
  String get chatWriteMessage => 'Skriv ett meddelande …';

  @override
  String chatTypingOne(String name) {
    return '$name skriver';
  }

  @override
  String chatTypingTwo(String first, String second) {
    return '$first och $second skriver';
  }

  @override
  String chatTypingMany(String first, String second, int others) {
    String _temp0 = intl.Intl.pluralLogic(
      others,
      locale: localeName,
      other: '$others andra',
      one: '1 annan',
    );
    return '$first, $second och $_temp0 skriver';
  }

  @override
  String get commonOr => 'eller';

  @override
  String get errorCouldNotLoadPage => 'Kunde inte ladda sidan';

  @override
  String get errorLoadingRetryOrGoBack =>
      'Ett fel uppstod vid laddning. Försök igen eller gå tillbaka.';

  @override
  String errorSavingWithDetails(String error) {
    return 'Det gick inte att spara. Försök igen.';
  }

  @override
  String get errorTitle => 'Fel';

  @override
  String errorOccurredWithDetails(String error) {
    return 'Det gick inte att slutföra. Försök igen.';
  }

  @override
  String get filterAllergenFree => 'Allergenfri';

  @override
  String get filterClearAll => 'Rensa alla filter';

  @override
  String get filterCookingTime => 'Tid att laga';

  @override
  String get filterCreatePersonalTags => 'Skapa egna taggar';

  @override
  String get filterDietary => 'Specialkost';

  @override
  String get filterExcludeTags => 'Exkludera taggar';

  @override
  String get filterHide => 'Dölj filter';

  @override
  String get filterManageFoodPrefs => 'Hantera allergener & kost';

  @override
  String get filterManageTags => 'Hantera taggar';

  @override
  String get filterMealType => 'Måltidstyp';

  @override
  String get filterPersonalTags => 'Egna taggar';

  @override
  String get filterRating => 'Betyg';

  @override
  String get filterShow => 'Visa filter';

  @override
  String get importChooseFromGallery => 'Välj från galleri';

  @override
  String importConfidenceTooltip(String label, int percentage) {
    return '$label: $percentage% säkerhet';
  }

  @override
  String get importContinueWithoutOcr => 'Fortsätt utan textavläsning';

  @override
  String get importFromPhoto => 'Importera från foto';

  @override
  String get importGoodQuality => 'God kvalitet';

  @override
  String get importHandwrittenToggle => 'Det här är ett handskrivet recept';

  @override
  String get importHandwrittenToggleSubtitle =>
      'Använder AI för att tyda handstilen. Det tar lite längre tid, och resultatet är värt att dubbelkolla.';

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
  String get importManually => 'Importera manuellt';

  @override
  String get importOcrMayFail =>
      'Textavläsningen kan misslyckas eller ge dåliga resultat.';

  @override
  String get importPasteFromClipboard => 'Klistra in från urklipp';

  @override
  String get importClipboardUrlDetected => 'Receptlänk hittad i urklipp';

  @override
  String get importClipboardUseUrl => 'Använd';

  @override
  String get importPasteLinkOrText => 'Klistra in länk eller text här …';

  @override
  String get importAddManually => 'Skriv själv';

  @override
  String get importPhotoImport => 'Fotoimport';

  @override
  String get importProceedToEdit => 'Gå vidare till redigera';

  @override
  String importMultipleRecipesFound(int count) {
    return 'Vi hittade $count recept';
  }

  @override
  String get importPhotoAddPage => 'Lägg till sida';

  @override
  String importPhotoPageLabel(int number) {
    return 'Sida $number';
  }

  @override
  String importPhotoPagesMaxReached(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max sidor',
      one: '1 sida',
    );
    return 'Max $_temp0 per recept';
  }

  @override
  String get shareImportUnreadable => 'Kunde inte läsa det delade fotot';

  @override
  String a11yRemovePhotoPage(int number) {
    return 'Ta bort sida $number';
  }

  @override
  String get importProcessingImage => 'Bearbetar bild …';

  @override
  String get importRecipeTitle => 'Importera recept';

  @override
  String get importRemoveImage => 'Ta bort bild';

  @override
  String get importHeirloomClearTitle => 'Ta bort bilden?';

  @override
  String get importHeirloomClearMessage =>
      'Du har fyllt i uppgifter om receptets ursprung (skribent, år, anteckning). Tas bilden bort försvinner även de. Detta går inte att ångra.';

  @override
  String get importTakePhoto => 'Ta ett foto';

  @override
  String get importVideoNoText => 'Videon saknar text';

  @override
  String get importVideoNoTextDescription =>
      'Den här videon har inga undertexter som vi kan läsa.\n\nDu kan ta en skärmbild av receptet i videon och importera den i stället.';

  @override
  String get groupAddMembers => 'Lägg till medlemmar';

  @override
  String groupAddToGroup(String group) {
    return 'Lägg till i $group';
  }

  @override
  String get groupAlreadyMember => 'Redan medlem';

  @override
  String get groupAllFriendsAlreadyMembers =>
      'Alla dina vänner är redan medlemmar i denna grupp, eller så har du redan skickat inbjudningar till dem.';

  @override
  String get groupSharedContentLoadFailed =>
      'Det delade innehållet kunde inte hämtas.';

  @override
  String get groupCouldNotLoadMembers => 'Kunde inte ladda gruppmedlemmar';

  @override
  String get groupRosterIncomplete =>
      'Vi kunde inte läsa alla medlemmar. Försök igen.';

  @override
  String get groupCouldNotTransferOwnership =>
      'Kunde inte överföra ägande. Försök igen.';

  @override
  String groupHandOverNotInHousehold(String name) {
    return '$name är inte med i gruppens hushåll och kan därför inte ta över gruppen.';
  }

  @override
  String get groupHandOverUnavailable =>
      'Gruppen kan inte lämnas över just nu.';

  @override
  String groupDeleted(String name) {
    return 'Gruppen ”$name” är raderad';
  }

  @override
  String get groupInvitationSent => 'Skickad';

  @override
  String groupInvitationsSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inbjudningar skickade',
      one: '1 inbjudan skickad',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationsSentSuccess => 'Inbjudningarna har skickats.';

  @override
  String get groupLoadingInfo => 'Laddar gruppinformation …';

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
  String groupSendInvitations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bjud in $count valda',
      one: 'Bjud in 1 vald',
    );
    return '$_temp0';
  }

  @override
  String groupSharedFromGroup(String name) {
    return 'Delad från gruppen $name';
  }

  @override
  String get groupUpdated => 'Gruppen är uppdaterad.';

  @override
  String get groupYouLeftGroup => 'Du har lämnat gruppen';

  @override
  String get loadingGeneric => 'Laddar …';

  @override
  String get loadingRecipes => 'Laddar recept …';

  @override
  String get loadingAdminAccess => 'Hämtar din behörighet …';

  @override
  String get loadingConsents => 'Hämtar dina samtycken …';

  @override
  String get loadingFeedbackEntries => 'Hämtar återkopplingen …';

  @override
  String get loadingImage => 'Hämtar bilden …';

  @override
  String get loadingMetrics => 'Hämtar mätvärdena …';

  @override
  String get loadingReports => 'Hämtar anmälningarna …';

  @override
  String get loadingOpsLog => 'Hämtar driftloggen …';

  @override
  String get loadingParsingStats => 'Hämtar tolkningsstatistiken …';

  @override
  String get loadingFamily => 'Hämtar hushållet …';

  @override
  String get loadingIngredientSearch => 'Söker ingredienser …';

  @override
  String get loadingCommunityGuidelines => 'Hämtar riktlinjerna …';

  @override
  String get loadingTerms => 'Hämtar användarvillkoren …';

  @override
  String get loadingWeeklyMenu => 'Hämtar veckomenyn …';

  @override
  String get loadingNotifications => 'Hämtar dina notiser …';

  @override
  String get loadingPersonalTags => 'Hämtar dina taggar …';

  @override
  String get loadingAllergenPreferences => 'Hämtar dina allergival …';

  @override
  String get loadingMfaSettings => 'Hämtar tvåstegsverifieringen …';

  @override
  String get loadingMyReports => 'Hämtar dina anmälningar …';

  @override
  String get loadingNotificationPreferences => 'Hämtar dina notisval …';

  @override
  String get loadingTag => 'Hämtar taggen …';

  @override
  String get loadingShoppingList => 'Hämtar inköpslistan …';

  @override
  String get loadingShoppingLists => 'Hämtar dina inköpslistor …';

  @override
  String get loadingGroupMembers => 'Hämtar gruppens medlemmar …';

  @override
  String get loadingProfile => 'Hämtar profilen …';

  @override
  String get loadingPantry => 'Hämtar skafferiet …';

  @override
  String get loadingSharedShoppingLists => 'Hämtar delade inköpslistor …';

  @override
  String get loadingFeed => 'Hämtar flödet …';

  @override
  String menuConnectingCollaborative(String title) {
    return 'Ansluter till ”$title” för samarbetsredigering …';
  }

  @override
  String get menuCouldNotHide => 'Kunde inte dölja meny';

  @override
  String menuHiddenFromList(String title) {
    return '”$title” dold från din lista';
  }

  @override
  String menuHideConfirm(String title, String sharedBy) {
    return 'Vill du dölja ”$title” från din lista?\n\nDu kan fortfarande komma åt menyn genom att be $sharedBy att dela den igen.';
  }

  @override
  String get menuHideMenu => 'Dölj meny';

  @override
  String get menuImportAll => 'Spara till mina menyer';

  @override
  String menuImportDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'När du importerar menyn läggs alla $count recept till i din samling.',
      one: 'När du importerar menyn läggs receptet till i din samling.',
    );
    return '$_temp0';
  }

  @override
  String get menuImported => 'Meny importerad';

  @override
  String menuImportedSuccess(String title) {
    return 'Menyn ”$title” är importerad.';
  }

  @override
  String get menuImportFailed => 'Import misslyckades';

  @override
  String get menuNoRecipesInMenu => 'Inga recept i menyn';

  @override
  String get menuShareMenu => 'Dela meny';

  @override
  String menuSavedSuccess(String name) {
    return 'Menyn ”$name” är sparad.';
  }

  @override
  String get menuSaveFailed => 'Kunde inte spara menyn';

  @override
  String get navigationGoHome => 'Till start';

  @override
  String get navigationSubtitle => 'Din receptsamling';

  @override
  String get permissionCopy => 'Kopia';

  @override
  String get permissionNoAccess => 'Ingen åtkomst';

  @override
  String get permissionSaveAsNew => 'Spara som ny';

  @override
  String get permissionSaveChanges => 'Spara ändringar';

  @override
  String get permissionSaveMyCopy => 'Spara min kopia';

  @override
  String get privacyCouldNotOpenEmail => 'Kunde inte öppna e-postklienten';

  @override
  String get privacyGdprCompliant =>
      'Denna integritetspolicy uppfyller kraven i GDPR';

  @override
  String get privacyLoading => 'Hämtar integritetspolicyn …';

  @override
  String get privacyNotAvailable => 'Integritetspolicyn är inte tillgänglig';

  @override
  String get privacyReload => 'Ladda om';

  @override
  String get privacyShareActivityTitle => 'Visa min aktivitet i vänners flöde';

  @override
  String get privacyShareActivitySubtitle =>
      'När detta är på ser dina vänner när du lagar och delar recept, och när du knuffar dem.';

  @override
  String get privacyActivityTypesTitle => 'Vad som delas';

  @override
  String get privacyActivityTypeCooked => 'När jag lagar ett recept';

  @override
  String get privacyActivityTypeShared => 'När jag delar ett recept';

  @override
  String get privacyActivityTypeStartedCooking => 'När jag börjar laga';

  @override
  String get privacyActivityTypePinged => 'När jag knuffar en vän';

  @override
  String get profileAvatarRemoved => 'Avatar borttagen';

  @override
  String get profileAvatarUploaded => 'Avataren är uppladdad.';

  @override
  String get profileBio => 'Om mig';

  @override
  String get profileBioHint => 'Beskriv dig som matlagare (max 160 tecken)';

  @override
  String get profileCouldNotSave => 'Kunde inte spara profil';

  @override
  String get profileCouldNotUploadAvatar => 'Kunde inte ladda upp avatar';

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
  String profileLanguageChangedTo(String language) {
    return 'Språk ändrat till $language';
  }

  @override
  String get profileLoading => 'Laddar profil …';

  @override
  String get profileNewUser => 'Ny användare';

  @override
  String get profilePrivacySettings => 'Integritet';

  @override
  String get profileResetChanges => 'Återställ ändringar';

  @override
  String get profileSaved => 'Profilen är sparad.';

  @override
  String get profileSaveProfile => 'Spara ändringar';

  @override
  String get profileSearchableByEmail => 'Sökbar via e-post';

  @override
  String get profileSearchableByEmailDescription =>
      'Andra kan hitta dig genom din e-postadress';

  @override
  String get profileShowOnlineStatus => 'Visa onlinestatus';

  @override
  String get profileShowOnlineStatusDescription =>
      'Vänner ser en grön prick och när du senast var aktiv. Stäng av för att vara osynlig.';

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
  String get profileUploadingAvatar => 'Laddar upp avatar …';

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
  String get recipeCouldNotMarkAsCooked => 'Kunde inte markera som lagat';

  @override
  String get recipeCouldNotOpenEditor => 'Kunde inte öppna redigeringsvy';

  @override
  String get recipeCouldNotShare => 'Kunde inte dela recept';

  @override
  String get recipeDeleted => 'Receptet ligger i papperskorgen i 30 dagar';

  @override
  String get recipeMarkedAsCooked => 'Receptet är markerat som lagat i dag.';

  @override
  String get recipeAlreadyCookedToday => 'Redan loggad i dag';

  @override
  String get recipeShared => 'Recept delat';

  @override
  String recipeImportedFrom(String sourceUrl) {
    return 'Importerat från: $sourceUrl';
  }

  @override
  String get recipeSaved => 'Receptet är sparat.';

  @override
  String get recipeSavedTaggingFailed =>
      'Recept sparat, men taggning misslyckades. Allergeninformation kan vara ofullständig.';

  @override
  String recipeSavedWithTags(int tagCount, int coverage) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: '$tagCount taggar',
      one: '1 tagg',
    );
    return 'Receptet är sparat – $_temp0 ($coverage%).';
  }

  @override
  String get recipeSaveStartedDuringDialog =>
      'En sparning påbörjades under valet. Vänta medan receptet sparas …';

  @override
  String get recipeWaitWhileSaving => 'Vänta medan receptet sparas …';

  @override
  String get celebrationFirstRecipeTitle => 'Första receptet är inlagt.';

  @override
  String celebrationFirstRecipeMessage(String recipeTitle) {
    return 'Receptet $recipeTitle är sparat. Butlery står redo.';
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
  String get recipeSaving => 'Sparar recept …';

  @override
  String searchFiltersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filter aktiva',
      one: '1 filter aktivt',
    );
    return '$_temp0';
  }

  @override
  String get searchQuery => 'Sökning';

  @override
  String searchResults(int count) {
    return '$count resultat';
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
      'Var först med att kommentera det här receptet.';

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
  String get socialCouldNotUpdateLike => 'Kunde inte uppdatera gilla-markering';

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
  String get feedTimeToday => 'I dag';

  @override
  String get feedTimeYesterday => 'I går';

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
  String get socialLoadingComments => 'Laddar kommentarer …';

  @override
  String get socialMustBeLoggedInToComment =>
      'Du måste vara inloggad för att kommentera';

  @override
  String get socialMustBeLoggedInToLike =>
      'Du måste vara inloggad för att gilla';

  @override
  String get socialNoCommentsYet => 'Inga kommentarer än';

  @override
  String get socialSendMessage => 'Skicka meddelande';

  @override
  String get socialUserProfileCreated => 'Användarprofil skapad';

  @override
  String get shoppingAddToShoppingList => 'Lägg till i inköpslista';

  @override
  String get shoppingCouldNotAddIngredients =>
      'Kunde inte lägga till ingredienser i inköpslistan';

  @override
  String get shoppingCouldNotCreateOrSelectList =>
      'Kunde inte skapa eller välja inköpslista';

  @override
  String shoppingIngredientsFromRecipe(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ingredienser',
      one: '1 ingrediens',
    );
    return '$_temp0 från ”$title”:';
  }

  @override
  String get shoppingNoEditPermission =>
      'Du har inte behörighet att redigera denna inköpslista';

  @override
  String get shoppingListChangedElsewhere =>
      'Listan har ändrats på en annan enhet – läs in den igen och försök på nytt';

  @override
  String get shoppingNoEditPermissionShared =>
      'Du har inte behörighet att redigera denna delade inköpslista';

  @override
  String get shoppingNoIngredientsToAdd =>
      'Receptet har inga ingredienser att lägga till';

  @override
  String get shoppingSelectList => 'Välj inköpslista';

  @override
  String get shoppingYourList => 'din inköpslista';

  @override
  String get shoppingSharedLists => 'Delade inköpslistor';

  @override
  String get sharedLoadingContent => 'Laddar delat innehåll …';

  @override
  String get sharedNoContentYet => 'Inga delade recept än';

  @override
  String get sharedEmptyStateExplanation =>
      'När du eller dina vänner delar recept och menyer visas de här. Dela ett recept för att komma igång.';

  @override
  String get taggingAnalyzingIngredients => 'Analyserar ingredienser …';

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
    return 'Taggningen misslyckades. Försök igen.';
  }

  @override
  String get taggingManageTags => 'Hantera taggar';

  @override
  String get tagSuggested => 'Föreslagna';

  @override
  String get tagAll => 'Alla taggar';

  @override
  String get taggingNoPersonalTags => 'Inga egna taggar';

  @override
  String get taggingPersonalTags => 'Egna taggar';

  @override
  String get taggingPersonalTagsRemoved => 'Egna taggar borttagna';

  @override
  String taggingPersonalTagsSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count egna taggar sparade',
      one: '1 egen tagg sparad',
    );
    return '$_temp0';
  }

  @override
  String taggingTagsGenerated(int count, int coverage) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taggar genererade',
      one: '1 tagg genererad',
    );
    return '$_temp0 ($coverage% täckning)';
  }

  @override
  String taggingTagsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count taggar valda',
      one: '1 tagg vald',
    );
    return '$_temp0';
  }

  @override
  String taggingUpdateTagsMessage(String title) {
    return 'Analyserar ingredienser och uppdaterar allergen- och kosttaggar för ”$title”.';
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
  String get sortCookCount => 'Antal gånger lagad';

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
    return 'Spara $count recept';
  }

  @override
  String importPreviewSubtitle(int ingredients, int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      ingredients,
      locale: localeName,
      other: '$ingredients ingredienser',
      one: '1 ingrediens',
    );
    return '$_temp0 · $steps steg';
  }

  @override
  String importMergeSelected(int count) {
    return 'Slå ihop valda ($count)';
  }

  @override
  String importMergedMessage(int count) {
    return '$count recept slogs ihop till ett';
  }

  @override
  String importPreviewUnreadLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rader kunde inte läsas. Tryck för att granska receptet.',
      one: '1 rad kunde inte läsas. Tryck för att granska receptet.',
    );
    return '$_temp0';
  }

  @override
  String get importPreviewOpenedForReview => 'Öppnat för granskning';

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
  String get groupLoadingGroups => 'Laddar grupper …';

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
  String get groupCouldNotAcceptInvitation =>
      'Kunde inte acceptera inbjudan. Försök igen.';

  @override
  String get groupCreated => 'Skapad';

  @override
  String get groupViewMembers => 'Visa medlemmar';

  @override
  String get groupEditGroup => 'Redigera grupp';

  @override
  String get groupInvitationAccepted =>
      'Inbjudan är accepterad. Välkommen till gruppen.';

  @override
  String get groupInvitationDeclined => 'Inbjudan avböjd';

  @override
  String groupInvitationFrom(String name) {
    return 'Inbjudan från $name';
  }

  @override
  String get groupLeaveGroup => 'Lämna grupp';

  @override
  String groupMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personer',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get groupMembers => 'Medlemmar';

  @override
  String groupRemoveSelectedCount(int count) {
    return 'Ta bort markerade ($count)';
  }

  @override
  String get groupNoMembersDescription =>
      'Lägg till vänner i den här gruppen för att komma igång.';

  @override
  String get groupNoMembersYet => 'Inga medlemmar än';

  @override
  String get groupSent => 'Skickat';

  @override
  String get commonAccept => 'Acceptera';

  @override
  String get commonDecline => 'Avböj';

  @override
  String shoppingItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count varor',
      one: '1 vara',
    );
    return '$_temp0';
  }

  @override
  String get socialLoadingFriends => 'Laddar vänner …';

  @override
  String get socialNoFriendsYet => 'Inga vänner än';

  @override
  String get socialSearchForNewFriends => 'Sök efter nya vänner';

  @override
  String get socialSearchForNewFriendsDescription =>
      'Skriv ett namn eller användarnamn i sökfältet ovan för att hitta nya vänner.';

  @override
  String get socialSearchingUsers => 'Söker användare …';

  @override
  String get socialSearchUnavailable =>
      'Sökningen är inte tillgänglig just nu. Försök igen om en stund.';

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
  String get socialDefaultFriendMessage => 'Hej. Skulle vi kunna bli vänner?';

  @override
  String get socialInviteFriends => 'Bjud in vänner';

  @override
  String get friendsEmptyHeadline => 'Laga tillsammans med vänner';

  @override
  String get friendsEmptySubtitle =>
      'Dela recept, se vad dina vänner lagar och planera menyer ihop.';

  @override
  String get friendsEmptyFindByUsername => 'Hitta vänner med användarnamn';

  @override
  String get socialInviteSubject => 'En inbjudan till Butlery.';

  @override
  String get socialFriendRequestAccepted => 'Vänskapsförfrågan är accepterad.';

  @override
  String socialFriendRequestAcceptedFrom(String name) {
    return 'Vänskapsförfrågan från $name är accepterad.';
  }

  @override
  String get socialFriendRequestDeclined => 'Vänskapsförfrågan avböjd';

  @override
  String socialFriendRequestSent(String name) {
    return 'Vänförfrågan är skickad till $name.';
  }

  @override
  String get socialNoFriendRequests => 'Inga vänskapsförfrågningar';

  @override
  String get socialNoFriendRequestsDescription =>
      'Sök efter vänner ovan för att utvidga nätverket.';

  @override
  String get socialRequestSent => 'Skickad';

  @override
  String get addRecipeTitle => 'Lägg till recept';

  @override
  String get authPassword => 'Lösenord';

  @override
  String get authTagline => 'Recept, meny och inköp på ett ställe.';

  @override
  String get collaborativeAdd => 'Lägg till';

  @override
  String get collaborativeAddFirstItem => 'Lägg till den första varan';

  @override
  String get collaborativeAdding => 'Lägger till …';

  @override
  String get collaborativeAddItemHint => 'Lägg till vara …';

  @override
  String get collaborativeClearAll => 'Rensa alla';

  @override
  String get collaborativeClearCompleted => 'Rensa avbockade';

  @override
  String get collaborativeClearCompletedConfirm =>
      'Vill du rensa alla avbockade varor?';

  @override
  String collaborativeClearCompletedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avbockade varor',
      one: '1 avbockad vara',
    );
    return 'Vill du rensa $_temp0?';
  }

  @override
  String collaborativeCompletedItemsCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count avbockade varor rensade',
      one: '1 avbockad vara rensad',
    );
    return '$_temp0';
  }

  @override
  String collaborativeCompletedOf(int completed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total avbockade',
      one: '1 avbockad',
    );
    return '$completed av $_temp0';
  }

  @override
  String get collaborativeCopyLink => 'Kopiera länk';

  @override
  String get collaborativeCopyLinkDescription => 'Dela via länk';

  @override
  String get collaborativeCouldNotClearCompleted =>
      'Kunde inte rensa avbockade varor';

  @override
  String get collaborativeLinkCopied => 'Länken är kopierad.';

  @override
  String get collaborativeMoreActions => 'Fler åtgärder';

  @override
  String get collaborativeNoCompletedItems => 'Inga avbockade varor';

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
  String get collaborativeShareList => 'Dela listan';

  @override
  String get collaborativeViewOnly => 'Kan bara se';

  @override
  String get collaborativeWaitingForOthers => 'Väntar på andra …';

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
  String groupCancelInvitationMessage(String name) {
    return 'Vill du avbryta inbjudan till $name?';
  }

  @override
  String get groupCreatedSuccess => 'Gruppen är skapad.';

  @override
  String get groupCreateGroup => 'Skapa grupp';

  @override
  String get groupCreator => 'Skapare';

  @override
  String get groupEmoji => 'Emoji';

  @override
  String get groupInvitationCancelled => 'Inbjudan avbruten';

  @override
  String get groupInvitationExpires => 'Inbjudan går ut';

  @override
  String get groupLeave => 'Lämna';

  @override
  String groupLeaveGroupConfirm(String name) {
    return 'Vill du lämna gruppen $name?';
  }

  @override
  String get groupLeftGroup => 'Du har lämnat gruppen';

  @override
  String groupMemberRemoved(String name) {
    return '$name har tagits bort';
  }

  @override
  String groupRemoveMultipleConfirm(int count, String group) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
    );
    return 'Ta bort $_temp0 från $group?';
  }

  @override
  String groupMembersRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
    );
    return '$_temp0 har tagits bort';
  }

  @override
  String get groupOwner => 'Ägare';

  @override
  String get groupRemoveFromGroup => 'Ta bort ur gruppen';

  @override
  String get groupRemoveMember => 'Ta bort medlem';

  @override
  String groupRemoveMemberConfirm(String name, String groupName) {
    return 'Vill du ta bort $name från $groupName?';
  }

  @override
  String get sharedAlreadyMember => 'Du är redan medlem';

  @override
  String get sharedContent => 'Delat innehåll';

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
  String sharedNoRecipesFromFriend(String name) {
    return '$name har inte delat några recept med dig än';
  }

  @override
  String get sharedNoShoppingLists => 'Inga delade inköpslistor';

  @override
  String get sharedNoShoppingListsDescription =>
      'Inköpslistor som delas med dig visas här';

  @override
  String get sharedSearchHint => 'Sök delat innehåll …';

  @override
  String sharedTabRecipes(int count) {
    return 'Recept · $count';
  }

  @override
  String sharedTabMenus(int count) {
    return 'Menyer · $count';
  }

  @override
  String sharedTabShoppingLists(int count) {
    return 'Listor · $count';
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
  String sharedConnectingToCollaborativeMenu(String title) {
    return 'Ansluter till samarbetsmeny: $title';
  }

  @override
  String sharedContentHidden(String title) {
    return '$title har dolts';
  }

  @override
  String sharedHideMenuConfirm(String title, String sharedBy) {
    return 'Vill du dölja menyn ”$title” delad av $sharedBy?';
  }

  @override
  String sharedHideRecipeConfirm(String title, String sharedBy) {
    return 'Vill du dölja receptet ”$title” delat av $sharedBy?';
  }

  @override
  String sharedHideShoppingListConfirm(String name, String sharedBy) {
    return 'Vill du dölja inköpslistan ”$name” delad av $sharedBy?';
  }

  @override
  String sharedJoinedList(String name) {
    return 'Gick med i listan ”$name”';
  }

  @override
  String sharedJoinedListFindInShopping(String name) {
    return 'Gick med i ”$name”. Hitta den under Inköpslistor.';
  }

  @override
  String sharedMenuImported(String title) {
    return 'Menyn ”$title” har importerats';
  }

  @override
  String sharedRecipeImported(String title) {
    return 'Receptet ”$title” har importerats';
  }

  @override
  String get shoppingAdminOwner => 'Admin/Ägare';

  @override
  String get shoppingAdminOwnerDescription => 'Full åtkomst och hantering';

  @override
  String get shoppingAllFriendsAreMembers => 'Alla vänner är redan medlemmar';

  @override
  String get shoppingBy => 'Av';

  @override
  String get shoppingCategoryHint => 'Välj kategori …';

  @override
  String get shoppingClear => 'Rensa';

  @override
  String get shoppingClearPurchasedTitle => 'Rensa köpta varor';

  @override
  String get shoppingCouldNotDeleteList => 'Kunde inte radera listan';

  @override
  String get shoppingCouldNotLoadLists => 'Kunde inte ladda inköpslistor';

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
  String get shoppingCreateNewListHint => 'Namn på ny inköpslista …';

  @override
  String get shoppingCreator => 'Skapare';

  @override
  String get shoppingDeleteList => 'Radera listan';

  @override
  String get shoppingDescriptionHint => 'Lägg till en beskrivning …';

  @override
  String get shoppingDescriptionOptional => 'Beskrivning (valfritt)';

  @override
  String get shoppingItemNameHint => 'Varunamn …';

  @override
  String get shoppingJustNow => 'Just nu';

  @override
  String get shoppingListInfo => 'Listinformation';

  @override
  String get shoppingManageSharing => 'Hantera delning';

  @override
  String get shoppingNewNameHint => 'Nytt namn …';

  @override
  String get shoppingNoFriends => 'Inga vänner';

  @override
  String get shoppingNoFriendsDescription =>
      'Lägg till vänner för att dela inköpslistor';

  @override
  String get shoppingNoFriendsFound => 'Inga vänner hittades';

  @override
  String get shoppingNoteHint => 'Lägg till anteckning …';

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
  String get shoppingPermissionEdit => 'Redigerare';

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
  String get shoppingPermissionView => 'Läsare';

  @override
  String get shoppingPermissionViewDescription => 'Kan se varor men inte ändra';

  @override
  String get shoppingPermissionViewOnly => 'Läsare';

  @override
  String get shoppingPersonalList => 'Personlig lista';

  @override
  String get shoppingPurchasedCleared => 'Köpta varor rensade';

  @override
  String get shoppingRecentActivity => 'Senaste aktivitet';

  @override
  String get shoppingRemoveMember => 'Ta bort medlem';

  @override
  String get shoppingSearchFriends => 'Sök vänner …';

  @override
  String get shoppingSharedList => 'Delad lista';

  @override
  String get shoppingSharedListTitleHint => 'Namn på delad lista …';

  @override
  String get shoppingShareExternally => 'Dela externt';

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
  String shoppingItemMoved(String category) {
    return 'Flyttade till $category';
  }

  @override
  String get shoppingUnitHint => 'Enhet …';

  @override
  String get shoppingUnknownUser => 'Okänd användare';

  @override
  String get shoppingWhen => 'När';

  @override
  String get shoppingYourPermission => 'Din behörighet';

  @override
  String shoppingBoughtCount(int count) {
    return 'Köpt ($count)';
  }

  @override
  String get shoppingClearBought => 'Rensa köpta';

  @override
  String shoppingClearPurchasedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count köpta varor',
      one: '1 köpt vara',
    );
    return 'Vill du rensa $_temp0?';
  }

  @override
  String shoppingCouldNotAddItem(String name) {
    return 'Kunde inte lägga till $name';
  }

  @override
  String shoppingCouldNotLoadFriends(String error) {
    return 'Vännerna kunde inte laddas. Försök igen.';
  }

  @override
  String shoppingCouldNotShowShareDialog(String error) {
    return 'Delningen kunde inte öppnas. Försök igen.';
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
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagar',
      one: '1 dag',
    );
    return '$_temp0 sedan';
  }

  @override
  String shoppingDeleteListConfirm(String name) {
    return 'Vill du radera listan ”$name”?';
  }

  @override
  String shoppingDeleteListWithItemsConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count varor',
      one: '1 vara',
    );
    return 'Vill du radera listan ”$name” med $_temp0?';
  }

  @override
  String shoppingErrorAdding(String error) {
    return 'Varan kunde inte läggas till. Försök igen.';
  }

  @override
  String shoppingErrorUpdating(String error) {
    return 'Varan kunde inte uppdateras. Försök igen.';
  }

  @override
  String shoppingHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours timmar',
      one: '1 timme',
    );
    return '$_temp0 sedan';
  }

  @override
  String shoppingItemAdded(String itemName) {
    return 'La till ”$itemName”';
  }

  @override
  String shoppingItemCountText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count varor',
      one: '1 vara',
    );
    return '$_temp0';
  }

  @override
  String shoppingListDeleted(String name) {
    return 'Listan ”$name” raderad';
  }

  @override
  String shoppingListRenamed(String name) {
    return 'Listan omdöpt till ”$name”';
  }

  @override
  String shoppingMemberRemoved(String name) {
    return '$name har tagits bort';
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
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuter',
      one: '1 minut',
    );
    return '$_temp0 sedan';
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
  String get socialBlock => 'Blockera';

  @override
  String get socialBlockUserConfirm => 'Vill du blockera denna användare?';

  @override
  String get socialCancelAll => 'Avbryt alla';

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
  String socialUserBlockedCleanupIncomplete(String name) {
    return '$name är blockerad. Vi hann inte rensa bort vänskapen eller en förfrågan.';
  }

  @override
  String get socialCouldNotCancelAllRequests =>
      'Kunde inte avbryta alla förfrågningar';

  @override
  String get socialCouldNotRejectAllRequests =>
      'Kunde inte avböja alla förfrågningar';

  @override
  String get socialCouldNotRemoveFriend => 'Kunde inte ta bort vän';

  @override
  String get socialCouldNotUnblockUser => 'Kunde inte avblockera användare';

  @override
  String get socialDecline => 'Avböj';

  @override
  String get socialDeclined => 'Avböjd';

  @override
  String get socialExpired => 'Utgången';

  @override
  String get socialFindFriends => 'Hitta vänner';

  @override
  String get socialFriendsAndGroups => 'Vänner & grupper';

  @override
  String get socialGroups => 'Grupper';

  @override
  String get socialLoadingRequests => 'Laddar förfrågningar …';

  @override
  String get socialNoRequestsSelected => 'Inga förfrågningar valda';

  @override
  String get socialPendingResponse => 'Väntar på svar';

  @override
  String get socialRejectAll => 'Avböj alla';

  @override
  String get socialRejectAllSelectedConfirm =>
      'Avböj alla valda förfrågningar?';

  @override
  String get socialRequestCancelled => 'Förfrågan avbruten';

  @override
  String get socialUnknownStatus => 'Okänd status';

  @override
  String get socialWantsToBeFriend => 'vill bli din vän';

  @override
  String socialAcceptAllSelectedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valda förfrågningar',
      one: '1 vald förfrågan',
    );
    return 'Vill du acceptera $_temp0?';
  }

  @override
  String socialAcceptCount(int count) {
    return 'Acceptera ($count)';
  }

  @override
  String get socialBlockUserStaysInGroup =>
      'De står kvar i gruppen, men du ser inte längre vad de skriver.';

  @override
  String socialBlockUserMessage(String name) {
    return 'Vill du blockera $name? De kommer inte kunna se din profil eller skicka förfrågningar, och de kan inte längre påverka det ni planerar tillsammans. En vänskap tas bort och återställs inte om du avblockerar.';
  }

  @override
  String socialCancelCount(int count) {
    return 'Avbryt ($count)';
  }

  @override
  String socialCancelSelectedRequestsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valda förfrågningar',
      one: '1 vald förfrågan',
    );
    return 'Vill du avbryta $_temp0?';
  }

  @override
  String socialDeclineCount(int count) {
    return 'Avböj ($count)';
  }

  @override
  String socialRejectAllSelectedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valda förfrågningar',
      one: '1 vald förfrågan',
    );
    return 'Vill du avböja $_temp0?';
  }

  @override
  String socialRequestsAccepted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count förfrågningar accepterade',
      one: '1 förfrågan accepterad',
    );
    return '$_temp0';
  }

  @override
  String socialRequestsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count förfrågningar avbrutna',
      one: '1 förfrågan avbruten',
    );
    return '$_temp0';
  }

  @override
  String socialRequestsRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count förfrågningar avböjda',
      one: '1 förfrågan avböjd',
    );
    return '$_temp0';
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
  String get authResetEmailSent =>
      'E-posten är skickad. Kontrollera din inkorg.';

  @override
  String get authResetEmailFailed => 'Kunde inte skicka e-post';

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
  String get imageSelectedImages => 'Valda bilder';

  @override
  String get imageSelectImages => 'Välj bilder';

  @override
  String get imageSelectingImages => 'Väljer bilder …';

  @override
  String get imageTapToSelectOne => 'Tryck för att välja en bild';

  @override
  String get messagingCancelReply => 'Avbryt svar';

  @override
  String get messagingImagePreview => 'Bild';

  @override
  String get navigationMenu => 'Meny';

  @override
  String get navigationShopping => 'Inköp';

  @override
  String get recipeRecipe => 'Recept';

  @override
  String get recipeSharedFromApp => 'Delad från annan app';

  @override
  String commonDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagar',
      one: '1 dag',
    );
    return '$_temp0 sedan';
  }

  @override
  String commonHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours timmar',
      one: '1 timme',
    );
    return '$_temp0 sedan';
  }

  @override
  String commonMinutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuter',
      one: '1 minut',
    );
    return '$_temp0 sedan';
  }

  @override
  String imageCountSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valda',
      one: '1 vald',
    );
    return '$_temp0';
  }

  @override
  String imageSelectedCount(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max bilder valda',
      one: '1 bild vald',
    );
    return '$count av $_temp0';
  }

  @override
  String imageTapToSelectUpTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count bilder',
      one: '1 bild',
    );
    return 'Tryck för att välja upp till $_temp0';
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
  String socialLikeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gilla-markeringar',
      one: '1 gilla-markering',
    );
    return '$_temp0';
  }

  @override
  String socialLikesHeader(int count) {
    return 'Gilla-markeringar ($count)';
  }

  @override
  String get commonAdding => 'Lägger till …';

  @override
  String get a11yHidePassword => 'Dölj lösenord';

  @override
  String get a11yShowPassword => 'Visa lösenord';

  @override
  String get a11yLoading => 'Laddar';

  @override
  String get a11yNavigationLandmark => 'Huvudnavigering';

  @override
  String get a11yTagStatusInfo => 'Mer information';

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
  String get a11yShoppingItemChecked => 'Ta bort bocken';

  @override
  String get a11yShoppingItemUnchecked => 'Bocka av';

  @override
  String get a11yShoppingSelectItem => 'Markera';

  @override
  String shoppingItemsRemovedUndoMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count borttagna',
      one: '1 borttagen',
    );
    return '$_temp0';
  }

  @override
  String get a11yPrimaryImageTap => 'Tryck för att visa fullstorlek';

  @override
  String get a11ySelectAsPrimary => 'Välj som primär bild';

  @override
  String get a11yAddImage => 'Lägg till bild';

  @override
  String get a11yAddImageSlot => 'Bild';

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
  String a11yImageOf(int current, int total) {
    return 'Bild $current av $total';
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
  String get a11yEditComment => 'Redigera kommentar';

  @override
  String get a11yDeleteComment => 'Radera kommentaren';

  @override
  String get a11yReportComment => 'Anmäl kommentar';

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
  String get a11yShoppingList => 'Inköpslista';

  @override
  String get a11yFriend => 'Vän';

  @override
  String a11yFilterTag(String tagName) {
    return 'Filtrera på $tagName';
  }

  @override
  String a11yExcludeTag(String tagName) {
    return 'Exkludera $tagName';
  }

  @override
  String get a11yAllergenStatusRow => 'Allergenstatus';

  @override
  String get a11yDietaryStatusRow => 'Koststatus';

  @override
  String get a11yShowImage => 'Visa bild';

  @override
  String get a11yShowMore => 'Visa fler';

  @override
  String a11yShoppingItemMoreOptions(String name) {
    return 'Fler val för $name';
  }

  @override
  String get a11yRemoveProfileImage => 'Ta bort profilbild';

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
  String get categoryFruitVeg => 'Frukt & grönt';

  @override
  String get categoryDairy => 'Mejeri';

  @override
  String get categoryMeatFish => 'Kött & fisk';

  @override
  String get categoryBread => 'Bröd';

  @override
  String get categoryPantry => 'Skafferi';

  @override
  String get categoryFrozen => 'Fryst';

  @override
  String get categoryBeverage => 'Dryck';

  @override
  String get categorySnacks => 'Snacks & godis';

  @override
  String get categoryHygiene => 'Städ & hygien';

  @override
  String get categoryOther => 'Övrigt';

  @override
  String get categorySpices => 'Kryddor';

  @override
  String get categoryCanned => 'Konserver';

  @override
  String get categoryDryGoods => 'Torrvaror';

  @override
  String get categoryMeat => 'Kött';

  @override
  String get categoryFish => 'Fisk';

  @override
  String get categoryFruit => 'Frukt';

  @override
  String get categoryVeg => 'Grönsaker';

  @override
  String get a11yConflictBannerDismiss => 'Stäng konfliktnotis';

  @override
  String get a11yShoppingListUpdatedByDismiss => 'Stäng meddelandet';

  @override
  String get conflictBannerTitleRecipe => 'Två versioner av receptet';

  @override
  String get conflictBannerTitleWeek => 'Två versioner av veckan';

  @override
  String conflictBannerBody(String name) {
    return '$name ändrade samtidigt. Din version finns kvar – välj vilken som gäller.';
  }

  @override
  String get conflictBannerBodyUnnamed =>
      'Någon annan ändrade samtidigt. Din version finns kvar – välj vilken som gäller.';

  @override
  String get conflictBannerBodyOtherDevice =>
      'Du ändrade receptet på en annan enhet. Din version finns kvar – välj vilken som gäller.';

  @override
  String conflictWeekSaved(String name) {
    return '$name sparade veckan';
  }

  @override
  String get conflictWeekSavedUnnamed => 'Någon annan sparade veckan';

  @override
  String get conflictWeekSavedElsewhere => 'Veckan sparades på en annan enhet';

  @override
  String get conflictDiffTitle => 'Vad ändrades';

  @override
  String get conflictDiffKeepMine => 'Behåll min version';

  @override
  String get conflictDiffKeptToast => 'Din version sparades';

  @override
  String get conflictDiffKeepFailed => 'Kunde inte spara din version';

  @override
  String get conflictDiffNoChanges =>
      'Inga fältändringar att visa – versionerna är identiska.';

  @override
  String get conflictDiffEmptyValue => '(tomt)';

  @override
  String get privacyEmailSubject => 'Integritetsfråga';

  @override
  String get unshareRecipeTitle => 'Sluta dela recept?';

  @override
  String unshareRecipeConfirm(String title) {
    return 'Receptet ”$title” tas bort från alla grupper det delats med.';
  }

  @override
  String get unshareMenuTitle => 'Sluta dela meny?';

  @override
  String unshareMenuConfirm(String title) {
    return 'Menyn ”$title” tas bort från alla grupper den delats med.';
  }

  @override
  String get unshareShoppingListTitle => 'Sluta dela inköpslista?';

  @override
  String unshareShoppingListConfirm(String name) {
    return 'Inköpslistan ”$name” tas bort från alla grupper den delats med.';
  }

  @override
  String get unshareButton => 'Sluta dela';

  @override
  String unshareSuccess(String title) {
    return '”$title” delas inte längre';
  }

  @override
  String get unshareFailed => 'Kunde inte sluta dela. Försök igen.';

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
      'Välj vänner att bjuda in till listan. De kommer med när de har tackat ja och kan sedan lägga till och bocka av varor i realtid.';

  @override
  String get shoppingConvertToPersonalTitle => 'Gör till personlig lista';

  @override
  String get shoppingConvertToPersonalWarning =>
      'Alla samarbetspartners förlorar åtkomst till listan. Varor behålls.';

  @override
  String get shoppingConvertedToPersonal => 'Listan omvandlad till personlig';

  @override
  String get shoppingConvertError => 'Kunde inte omvandla listan';

  @override
  String get shoppingConvertIncompleteTitle => 'Omvandlingen slutfördes inte';

  @override
  String get shoppingConvertedOriginalKept =>
      'Listan kopierades, men originalet finns kvar – kontrollera den nya listan och ta bort originalet manuellt.';

  @override
  String get shoppingConvertedToPersonalOriginalKept =>
      'Listan kopierades till en personlig lista, men den delade listan finns kvar – alla medlemmar har fortfarande tillgång till den. Ta bort den delade listan manuellt om ingen annan ska komma åt den.';

  @override
  String get shoppingDescriptionLabel => 'Beskrivning (valfritt)';

  @override
  String get personalTagApplyRulesToAll => 'Tillämpa regler på alla recept';

  @override
  String get messagingPinned => 'Fästa';

  @override
  String get messagingUnpin => 'Ta bort fäst';

  @override
  String get messagingPin => 'Fäst';

  @override
  String get messagingArchive => 'Arkivera';

  @override
  String get messagingUnarchive => 'Avarkivera';

  @override
  String get notificationSaveError => 'Kunde inte spara inställningar';

  @override
  String get notificationQuietHoursTitle => 'Tysta timmar';

  @override
  String get notificationQuietHoursEnable => 'Aktivera tysta timmar';

  @override
  String get notificationQuietHoursSubtitle =>
      'Inga notiser under vald tidsperiod';

  @override
  String get commonFrom => 'Från';

  @override
  String get commonTo => 'Till';

  @override
  String get notificationCategoryFriends => 'Vänner & förfrågningar';

  @override
  String get notificationCategoryRecipes => 'Recept';

  @override
  String get notificationCategoryCollaboration => 'Samarbete i realtid';

  @override
  String get notificationCategoryShopping => 'Inköpslistor';

  @override
  String get notificationCategorySocial => 'Socialt flöde';

  @override
  String get notificationCategorySystem => 'System';

  @override
  String get notificationCategoryMessaging => 'Meddelanden';

  @override
  String get notificationDigestFrequencyTitle => 'Sammanfattningsfrekvens';

  @override
  String get notificationDigestFrequencyNever => 'Aldrig';

  @override
  String get notificationDigestFrequencyWeekly => 'Veckovis';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stjärnor',
      one: '1 stjärna',
    );
    return 'Ge $_temp0';
  }

  @override
  String get recipeRatingSheetTitle => 'Betygsätt receptet';

  @override
  String get recipeRatingUnrated => 'Betygsätt';

  @override
  String get messagingSending => 'Skickar …';

  @override
  String get messagingSent => 'Skickat';

  @override
  String get messagingDelivered => 'Levererat';

  @override
  String get messagingRead => 'Läst';

  @override
  String get messagingFailed => 'Misslyckades';

  @override
  String get blockedUsersUnblockTitle => 'Avblockera användare?';

  @override
  String blockedUsersUnblockMessage(String name) {
    return 'Vill du avblockera $name?';
  }

  @override
  String get blockedUsersUnblock => 'Avblockera';

  @override
  String get blockedUsersTitle => 'Blockerade användare';

  @override
  String get blockedUsersEmpty => 'Inga blockerade användare';

  @override
  String get blockedUsersSharesHiddenNote =>
      'Recept, menyer och inköpslistor ni har skickat till varandra är dolda för er båda så länge blockeringen gäller. Inget raderas.';

  @override
  String blockedUsersUnblockSelectedCount(int count) {
    return 'Avblockera valda ($count)';
  }

  @override
  String get blockedUsersBulkUnblockTitle => 'Avblockera valda?';

  @override
  String blockedUsersBulkUnblockMessage(int count) {
    return 'Vill du avblockera $count användare?';
  }

  @override
  String blockedUsersBulkUnblockResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count användare avblockerade',
      one: '1 användare avblockerad',
    );
    return '$_temp0';
  }

  @override
  String blockedUsersBulkUnblockPartial(int succeeded, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total avblockerade',
      one: '1 avblockerad',
    );
    return '$succeeded av $_temp0';
  }

  @override
  String get retagFetchingRecipes => 'Hämtar recept …';

  @override
  String get retagRetaggingRecipes => 'Omtaggar recept …';

  @override
  String retagRetaggingProgress(int current, int total) {
    return 'Omtaggar $current av $total recept …';
  }

  @override
  String retagRecipesRetagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept omtaggade',
      one: '1 recept omtaggat',
    );
    return '$_temp0';
  }

  @override
  String get filterFavorites => 'Favoriter';

  @override
  String get filterUnder30Min => 'Under 30 min';

  @override
  String get filter30To60Min => '30–60 min';

  @override
  String get filterOver60Min => 'Över 60 min';

  @override
  String get filterVegetarianQuick => 'Vegetariskt';

  @override
  String get filterAll => 'Alla';

  @override
  String instructionLabel(int number) {
    return 'Instruktion $number';
  }

  @override
  String get onboardingSkipConfirmTitle => 'Hoppa över introduktionen?';

  @override
  String get onboardingSkipConfirmMessage =>
      'Du hinner inte ställa in allergier nu. Du kan göra det när som helst i inställningarna.';

  @override
  String get onboardingSkip => 'Hoppa över';

  @override
  String get onboardingBack => 'Tillbaka';

  @override
  String get onboardingNext => 'Nästa';

  @override
  String get onboardingComplete => 'Klar';

  @override
  String get onboardingAgeGateTitle => 'Vilket år är du född?';

  @override
  String get onboardingAgeGateSubtitle =>
      'Butlery är för dig som är 15 år eller äldre. Vi frågar bara efter året, inte datum.';

  @override
  String get onboardingAgeGateBirthYearLabel => 'Födelseår';

  @override
  String get onboardingAgeGateBirthYearHint => 'Välj ett år';

  @override
  String get onboardingAgeGatePrivacyNote =>
      'Året sparas på ditt konto. Det används för åldersgränsen och syns inte för någon annan.';

  @override
  String get onboardingAgeGateTooYoungTitle => 'Butlery är för 15 år och uppåt';

  @override
  String get onboardingAgeGateTooYoungBody =>
      'Det är inget vi valt själva. Svensk lag sätter gränsen för tjänster med ett socialt inslag, och Butlery har det.';

  @override
  String get onboardingAgeGateSignOut => 'Logga ut';

  @override
  String get onboardingAgeGateParentOption =>
      'En vuxen kan skapa ett konto åt dig';

  @override
  String get onboardingAgeGateParentInfoTitle => 'Be en vuxen om hjälp';

  @override
  String get onboardingAgeGateParentInfoBody =>
      'Be en förälder eller vårdnadshavare att skapa ett eget konto och lägga till dig som matgäst i hushållet. Du behöver vara minst 15 år för att ha ett eget konto.';

  @override
  String get onboardingAgeRejectedTitle => 'Kontot kunde inte skapas';

  @override
  String get onboardingAgeRejectedBody =>
      'Butlery är tillgängligt för dig som fyllt 15 år. Vi kan inte skapa ditt konto just nu.';

  @override
  String get onboardingWelcomeTitle => 'Välkommen. Vi sköter veckan.';

  @override
  String get onboardingWelcomeDescription =>
      'Samla recepten du redan lagar, så lägger vi veckomenyn och inköpslistan utifrån dem.';

  @override
  String get onboardingWelcomeNote => 'Två frågor kvar. Sedan är du inne.';

  @override
  String get onboardingAllergenTitle => 'Något ni undviker?';

  @override
  String get onboardingAllergenDescription =>
      'Då filtrerar vi bort det ur recept, meny och inköpslista. Kontrollera ändå alltid förpackningen.';

  @override
  String get onboardingAllergenGluten => 'Gluten';

  @override
  String get onboardingAllergenMilk => 'Mjölk';

  @override
  String get onboardingAllergenNuts => 'Nötter';

  @override
  String get onboardingAllergenEgg => 'Ägg';

  @override
  String get onboardingAllergenSoy => 'Soja';

  @override
  String get onboardingAllergenFish => 'Fisk';

  @override
  String get onboardingAllergenShellfish => 'Skaldjur';

  @override
  String get onboardingAllergenSesame => 'Sesam';

  @override
  String get onboardingSkippedBanner =>
      'Du hoppade över introduktionen. Vill du ställa in allergener och kostpreferenser?';

  @override
  String get onboardingSkippedBannerAction => 'Öppna inställningar';

  @override
  String get onboardingWelcomeBanner =>
      'Välkommen till Butlery. Allt är klart – lägg till ditt första recept så kommer du igång.';

  @override
  String get onboardingWelcomeBannerAction => 'Lägg till recept';

  @override
  String get onboardingImportTitle => 'Ta med ett recept du redan lagar';

  @override
  String get onboardingImportDescription =>
      'Klistra in en länk. Vi läser den och du får granska innan något sparas.';

  @override
  String get onboardingImportUrlTitle => 'Länk till receptet';

  @override
  String get onboardingImportPhotoTitle => 'Fotografera en sida';

  @override
  String get onboardingImportPhotoDescription =>
      'Ur en kokbok eller en handskriven lapp';

  @override
  String get onboardingResumeTitle => 'Avsluta din profil';

  @override
  String get onboardingResumeBody => '30 sekunder kvar';

  @override
  String get onboardingResumeCta => 'Fortsätt';

  @override
  String get onboardingAgeGateParentTitle => 'En vuxen kan skapa kontot';

  @override
  String get onboardingAgeGateParentBody =>
      'En förälder skapar ett eget konto och lägger till dig som matgäst i hushållet. Då planeras maten med dig i räkningen.';

  @override
  String get onboardingAgeGateNothingSaved =>
      'Kontot du började skapa tas bort. Inget sparas.';

  @override
  String get onboardingWelcomeQuestionAllergens => 'Vad hushållet inte tål';

  @override
  String get onboardingWelcomeQuestionRecipe => 'Ett recept du redan lagar';

  @override
  String get onboardingAllergenNote =>
      'Det här gäller dig. Allergier för fler i hushållet lägger du till senare. Har du valt något planeras recept med okänt allergeninnehåll aldrig automatiskt.';

  @override
  String onboardingShowAllAllergens(String kind, int count) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'nine': 'Visa alla nio till',
        'other': 'Visa alla $count till',
      },
    );
    return '$_temp0';
  }

  @override
  String get onboardingImportFromClipboard =>
      'Hämtad ur ditt urklipp. Byt om det var fel länk.';

  @override
  String onboardingImportSkipNote(String kind, int count) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'one':
            'Hoppar du över får du ett startrecept och en färdig exempelvecka. Du börjar aldrig i en tom app.',
        'two':
            'Hoppar du över får du två startrecept och en färdig exempelvecka. Du börjar aldrig i en tom app.',
        'three':
            'Hoppar du över får du tre startrecept och en färdig exempelvecka. Du börjar aldrig i en tom app.',
        'four':
            'Hoppar du över får du fyra startrecept och en färdig exempelvecka. Du börjar aldrig i en tom app.',
        'five':
            'Hoppar du över får du fem startrecept och en färdig exempelvecka. Du börjar aldrig i en tom app.',
        'six':
            'Hoppar du över får du sex startrecept och en färdig exempelvecka. Du börjar aldrig i en tom app.',
        'seven':
            'Hoppar du över får du sju startrecept och en färdig exempelvecka. Du börjar aldrig i en tom app.',
        'eight':
            'Hoppar du över får du åtta startrecept och en färdig exempelvecka. Du börjar aldrig i en tom app.',
        'nine':
            'Hoppar du över får du nio startrecept och en färdig exempelvecka. Du börjar aldrig i en tom app.',
        'ten':
            'Hoppar du över får du tio startrecept och en färdig exempelvecka. Du börjar aldrig i en tom app.',
        'other':
            'Hoppar du över får du $count startrecept och en färdig exempelvecka. Du börjar aldrig i en tom app.',
      },
    );
    return '$_temp0';
  }

  @override
  String onboardingStepOf(int current, int total) {
    return 'Steg $current av $total';
  }

  @override
  String get onboardingSetupTitle => 'Vi dukar upp';

  @override
  String get onboardingSetupBody =>
      'Ett par sekunder. Sedan har du en app med innehåll i.';

  @override
  String get onboardingSetupSaving => 'Sparar allergenerna';

  @override
  String get onboardingSetupSaved => 'Allergenerna sparade';

  @override
  String get onboardingSetupSavedNone => 'Inga allergener angivna';

  @override
  String get onboardingSetupRecipes => 'Lägger startrecept i Mina recept';

  @override
  String onboardingSetupRecipesDone(String kind, int count) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'one': 'Ett startrecept lagt i Mina recept',
        'two': 'Två startrecept lagda i Mina recept',
        'three': 'Tre startrecept lagda i Mina recept',
        'four': 'Fyra startrecept lagda i Mina recept',
        'five': 'Fem startrecept lagda i Mina recept',
        'six': 'Sex startrecept lagda i Mina recept',
        'seven': 'Sju startrecept lagda i Mina recept',
        'eight': 'Åtta startrecept lagda i Mina recept',
        'nine': 'Nio startrecept lagda i Mina recept',
        'ten': 'Tio startrecept lagda i Mina recept',
        'other': '$count startrecept lagda i Mina recept',
      },
    );
    return '$_temp0';
  }

  @override
  String get onboardingSetupRecipesFailed =>
      'Startrecepten kunde inte läggas till';

  @override
  String get onboardingSetupWeek =>
      'Lägger en exempelvecka och dess inköpslista';

  @override
  String get onboardingSetupWeekDone => 'Exempelvecka och inköpslista klara';

  @override
  String get onboardingSetupWeekFailed => 'Ingen exempelvecka lades till';

  @override
  String onboardingSetupProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tre av tre klara',
      two: 'Två av tre klara',
      one: 'En av tre klara',
      zero: 'Noll av tre klara',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDoneTitle => 'Varsågod. Det är dukat.';

  @override
  String onboardingDoneBody(String kind, int count) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'zero': 'Allt går att ändra när du vill.',
        'one':
            'Ett recept och en exempelvecka väntar på dig. Allt går att ändra när du vill.',
        'two':
            'Två recept och en exempelvecka väntar på dig. Allt går att ändra när du vill.',
        'three':
            'Tre recept och en exempelvecka väntar på dig. Allt går att ändra när du vill.',
        'four':
            'Fyra recept och en exempelvecka väntar på dig. Allt går att ändra när du vill.',
        'five':
            'Fem recept och en exempelvecka väntar på dig. Allt går att ändra när du vill.',
        'six':
            'Sex recept och en exempelvecka väntar på dig. Allt går att ändra när du vill.',
        'seven':
            'Sju recept och en exempelvecka väntar på dig. Allt går att ändra när du vill.',
        'eight':
            'Åtta recept och en exempelvecka väntar på dig. Allt går att ändra när du vill.',
        'nine':
            'Nio recept och en exempelvecka väntar på dig. Allt går att ändra när du vill.',
        'ten':
            'Tio recept och en exempelvecka väntar på dig. Allt går att ändra när du vill.',
        'other':
            '$count recept och en exempelvecka väntar på dig. Allt går att ändra när du vill.',
      },
    );
    return '$_temp0';
  }

  @override
  String get onboardingDoneRedirect => 'Tar dig till dina recept …';

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
  String get feedbackDescriptionHint => 'Beskriv vad du upplevde …';

  @override
  String get feedbackEmailLabel => 'E-post (valfritt)';

  @override
  String get feedbackScreenshotLabel => 'Skärmavbild';

  @override
  String get feedbackRemoveScreenshot => 'Ta bort skärmbild';

  @override
  String get feedbackSendButton => 'Skicka';

  @override
  String get adminLoginFailed => 'Inloggning misslyckades';

  @override
  String get adminNotAuthorized => 'Du har inte behörighet till adminpanelen.';

  @override
  String get adminBarTitle => 'Butlery Admin';

  @override
  String adminBarSignedIn(String email) {
    return 'Inloggad som $email';
  }

  @override
  String get adminSignOut => 'Logga ut';

  @override
  String get adminFeedbackInboxTitle => 'Feedback';

  @override
  String get adminFeedbackEmpty => 'Ingen feedback än';

  @override
  String get adminFeedbackLoadMore => 'Ladda fler';

  @override
  String get adminFeedbackInteractions => 'Interaktioner';

  @override
  String get adminFeedbackFilterAll => 'Alla';

  @override
  String get adminFeedbackStatusNew => 'Ny';

  @override
  String get adminFeedbackStatusTriaged => 'Pågår';

  @override
  String get adminFeedbackStatusResolved => 'Klar';

  @override
  String get adminScreenshotOpen => 'Visa skärmbild i full storlek';

  @override
  String get adminScreenshotClose => 'Stäng';

  @override
  String get adminCopyForClaude => 'Kopiera för Claude';

  @override
  String get adminCopiedForClaude =>
      'Kopierat – klistra in i en ny Claude-session';

  @override
  String get adminCopyFailed => 'Kunde inte kopiera till urklipp';

  @override
  String get adminRefresh => 'Uppdatera';

  @override
  String get adminNavFeedback => 'Feedback';

  @override
  String get adminNavImport => 'Importhälsa';

  @override
  String get adminImportTitle => 'Importhälsa';

  @override
  String get adminImportColDomain => 'Domän';

  @override
  String get adminImportColSuccess => 'Lyckade';

  @override
  String get adminImportColFailure => 'Misslyckade';

  @override
  String get adminImportColRate => 'Andel';

  @override
  String get adminImportSummaryDomains => 'Domäner';

  @override
  String get adminImportSummarySuccess => 'Lyckade';

  @override
  String get adminImportSummaryFailure => 'Misslyckade';

  @override
  String get adminImportSummaryRate => 'Andel lyckade';

  @override
  String get adminNavEngagement => 'Engagemang';

  @override
  String get adminEngagementTitle => 'Engagemang';

  @override
  String get adminEngagementUsers => 'Användare totalt';

  @override
  String get adminEngagementActiveToday => 'Aktiva i dag';

  @override
  String get adminEngagementActive7d => 'Aktiva 7 dagar';

  @override
  String get adminEngagementActive28d => 'Aktiva 28 dagar';

  @override
  String get adminEngagementColDate => 'Datum';

  @override
  String get adminEngagementColCooked => 'Lagat';

  @override
  String get adminEngagementColImported => 'Importerat';

  @override
  String get adminEngagementColShared => 'Delat';

  @override
  String get adminEngagementColPlanned => 'Planerat';

  @override
  String get adminEngagementColShopped => 'Handlat';

  @override
  String get adminNavParsing => 'Parsing-detaljer';

  @override
  String get adminParsingTitle => 'Parsing-detaljer';

  @override
  String get adminParsingEmpty => 'Inga korrigeringar än';

  @override
  String get adminParsingColDomain => 'Domän';

  @override
  String get adminParsingIssueTitle => 'Titel';

  @override
  String get adminParsingIssuePortions => 'Portioner';

  @override
  String get adminParsingIssueTime => 'Tid';

  @override
  String get adminParsingIssueIngredients => 'Ingredienser';

  @override
  String get adminParsingIssueInstructions => 'Instruktioner';

  @override
  String get adminNavRecipes => 'Recept';

  @override
  String get adminRecipesTitle => 'Recept';

  @override
  String get adminRecipesTotal => 'Recept totalt';

  @override
  String get adminRecipesColMethod => 'Importmetod';

  @override
  String get adminRecipesMethodUrl => 'Länk (URL)';

  @override
  String get adminRecipesMethodPhoto => 'Foto / OCR';

  @override
  String get adminRecipesMethodText => 'Textinklistring';

  @override
  String get adminRecipesMethodSocial => 'Sociala medier';

  @override
  String get adminRecipesMethodManual => 'Manuellt / okänt';

  @override
  String get adminNavOps => 'Drift';

  @override
  String get adminNavGuestList => 'Gästlista';

  @override
  String get adminGuestListTitle => 'Gästlista';

  @override
  String get adminGuestListLoading => 'Laddar gästlistan …';

  @override
  String get adminGuestListLoadFailed => 'Kunde inte ladda gästlistan';

  @override
  String get adminGuestListEmpty => 'Ingen är inbjuden än';

  @override
  String get adminGuestListColEmail => 'E-post';

  @override
  String get adminGuestListColInvited => 'Inbjuden';

  @override
  String get adminGuestListExpired => 'utgången';

  @override
  String get adminGuestListRemove => 'Ta bort';

  @override
  String get adminGuestListRemoveTitle => 'Ta bort inbjudan?';

  @override
  String adminGuestListRemoveMessage(String email) {
    return '$email kan då inte skapa ett konto.';
  }

  @override
  String get adminGuestListEmailLabel => 'Exakt e-postadress';

  @override
  String get adminGuestListInvite => 'Bjud in';

  @override
  String get adminGuestListHelp =>
      'Inbjudan gäller i 30 dagar och tas bort när kontot skapas och e-posten är bekräftad.';

  @override
  String get adminGuestListInvalidEmail =>
      'Skriv en hel e-postadress, till exempel namn@exempel.se.';

  @override
  String get adminGuestListDuplicate => 'Den adressen är redan inbjuden.';

  @override
  String get adminGuestListSaveFailed =>
      'Det gick inte att spara. Försök igen.';

  @override
  String get adminOpsTitle => 'Drift';

  @override
  String get adminOpsEmpty => 'Inga driftshändelser än';

  @override
  String get adminOpsColType => 'Typ';

  @override
  String get adminOpsColTime => 'Tidpunkt';

  @override
  String get adminOpsColDeleted => 'Borttaget';

  @override
  String get adminMetricNoData => 'Ingen data än';

  @override
  String get adminAnomalyTitle => 'Avvikelser upptäckta';

  @override
  String get adminAnomalyHigh => 'ovanligt högt';

  @override
  String get adminAnomalyLow => 'ovanligt lågt';

  @override
  String get adminAnomalyMetricRecipes => 'Recept';

  @override
  String get adminAnomalyMetricImportFailure => 'Importfel';

  @override
  String get adminAnomalyMetricParsing => 'Parsing-korrigeringar';

  @override
  String get adminAnomalyMetricOps => 'Drifthändelser';

  @override
  String get adminAnomalyMetricFeedback => 'Feedback';

  @override
  String get adminMetricInfo => 'Om den här siffran';

  @override
  String get adminMetricExport => 'Exportera till Excel';

  @override
  String get adminMetricExportFailed => 'Kunde inte exportera';

  @override
  String get adminMetricWhat => 'Vad är det';

  @override
  String get adminMetricHow => 'Hur räknas det';

  @override
  String get adminMetricWhy => 'Varför viktigt';

  @override
  String adminDrillImportTitle(String domain) {
    return 'Importförsök: $domain';
  }

  @override
  String get adminDrillEmpty => 'Inga importförsök loggade';

  @override
  String adminDrillTruncated(int count) {
    return 'Visar $count (det kan finnas fler)';
  }

  @override
  String get adminDrillSuccess => 'Lyckades';

  @override
  String get adminDrillFailure => 'Misslyckades';

  @override
  String get metricRecipeTotalWhat =>
      'Det totala antalet recept som finns i appen, över alla användare.';

  @override
  String get metricRecipeTotalHow =>
      'Räknas genom att gå igenom alla användares recept och summera dem (taket är 5 000 i förlanseringsläget).';

  @override
  String get metricRecipeTotalWhy =>
      'Visar hur mycket innehåll som faktiskt byggts upp – en grundläggande hälsosiffra för appen.';

  @override
  String get metricRecipeByMethodWhat =>
      'Hur recepten kom in i appen, uppdelat på metod: länk, foto, textinklistring, sociala medier eller manuellt.';

  @override
  String get metricRecipeByMethodHow =>
      'Varje recept klassas efter sitt ursprungsfält; recept som saknar fältet (äldre eller manuellt skapade) räknas som manuellt/okänt.';

  @override
  String get metricRecipeByMethodWhy =>
      'Visar vilka importvägar användarna faktiskt använder – styr var det är värt att förbättra importen.';

  @override
  String get metricImportDomainsWhat =>
      'Antal receptsajter som det gjorts minst ett importförsök från.';

  @override
  String get metricImportDomainsHow =>
      'Räknar domäner i importstatistiken som har minst ett lyckat eller misslyckat försök.';

  @override
  String get metricImportDomainsWhy =>
      'Visar bredden på var användarna hämtar recept ifrån.';

  @override
  String get metricImportSuccessWhat =>
      'Totalt antal lyckade receptimporter, summerat över alla sajter.';

  @override
  String get metricImportSuccessHow => 'Summan av varje sajts lyckade-räknare.';

  @override
  String get metricImportSuccessWhy =>
      'Den positiva sidan av importhälsan – hur ofta det faktiskt fungerar.';

  @override
  String get metricImportFailureWhat =>
      'Totalt antal misslyckade receptimporter, summerat över alla sajter.';

  @override
  String get metricImportFailureHow =>
      'Summan av varje sajts misslyckade-räknare.';

  @override
  String get metricImportFailureWhy =>
      'Hög siffra betyder att användare stöter på \'det gick inte\' – direkt friktion.';

  @override
  String get metricImportRateWhat => 'Andelen importförsök som lyckas, totalt.';

  @override
  String get metricImportRateHow =>
      'Lyckade delat med totala försök (lyckade + misslyckade), i procent.';

  @override
  String get metricImportRateWhy =>
      'Den enskilt viktigaste hälsosiffran för importen; lågt värde färgas varnande.';

  @override
  String get metricImportTableWhat =>
      'Per sajt: lyckade, misslyckade och andel lyckade – sämst överst.';

  @override
  String get metricImportTableHow =>
      'Varje rad är en domän; andelen är dess egna lyckade delat med dess totala försök.';

  @override
  String get metricImportTableWhy =>
      'Pekar ut exakt vilka sajter avläsaren behöver bli bättre på.';

  @override
  String get metricEngagementUsersWhat =>
      'Totalt antal registrerade användarkonton.';

  @override
  String get metricEngagementUsersHow =>
      'Räknar alla dokument i användarsamlingen.';

  @override
  String get metricEngagementUsersWhy =>
      'Grundläggande tillväxtsiffra – hur många som finns totalt.';

  @override
  String get metricEngagementActiveWhat =>
      'Hur många användare som var aktiva i någon funktion under perioden (i dag, 7 eller 28 dagar).';

  @override
  String get metricEngagementActiveHow =>
      'Tas från senaste dygnets sammanställning; visar flest aktiva i någon enskild funktion (en undre gräns för unika aktiva).';

  @override
  String get metricEngagementActiveWhy =>
      'Visar om folk faktiskt använder appen, inte bara registrerar sig.';

  @override
  String get metricEngagementTableWhat =>
      'Per dag: hur många som lagade, importerade, delade, planerade och handlade.';

  @override
  String get metricEngagementTableHow =>
      'En rad per dag från de nattliga aktivitetssammanställningarna.';

  @override
  String get metricEngagementTableWhy =>
      'Visar vilka funktioner som driver engagemang över tid.';

  @override
  String get substitutionEmptyState => 'Inga ersättningar hittades';

  @override
  String get substitutionLoadFailed => 'Kunde inte hämta ersättningar';

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
  String get askWhatToEat => 'Vad ska vi äta?';

  @override
  String get pickRecipesToVote => 'Välj recept att rösta på';

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
  String get messageStatusSending => 'Skickar …';

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
      'Anslutningsproblem upptäckts. Försöker återansluta …';

  @override
  String get errorServiceUnavailable =>
      'Tjänsten är tillfälligt otillgänglig. Försök igen senare.';

  @override
  String get errorNoUserLoggedIn => 'Ingen användare är inloggad';

  @override
  String get errorReauthRequired =>
      'Du måste logga in igen för att ta bort ditt konto';

  @override
  String get errorCouldNotRemoveMfa =>
      'Kunde inte stänga av tvåstegsverifiering';

  @override
  String get errorEmailAlreadyInUse =>
      'Email-adressen används redan av ett annat konto.';

  @override
  String get errorInvalidEmailAddress => 'Ogiltig e-postadress.';

  @override
  String get errorInvalidCredentials =>
      'Fel e-postadress eller lösenord. Kontrollera dina uppgifter.';

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
  String get errorSharedRecipeMayNotBeVisible =>
      'Receptet delades, men mottagaren kanske inte ser det. Försök igen om de inte hittar det.';

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
  String get errorCouldNotDeleteTag => 'Kunde inte radera taggen';

  @override
  String get errorCouldNotCreateGroup => 'Kunde inte skapa gruppen';

  @override
  String get errorCouldNotUpdateGroup => 'Kunde inte uppdatera gruppen';

  @override
  String get errorGroupNotFound => 'Gruppen hittades inte';

  @override
  String get errorCouldNotDeleteGroup => 'Kunde inte radera gruppen';

  @override
  String get errorCouldNotCreateRule => 'Kunde inte skapa regeln';

  @override
  String get errorCouldNotUpdateRule => 'Kunde inte uppdatera regeln';

  @override
  String get errorCouldNotDeleteRule => 'Kunde inte radera regeln';

  @override
  String get errorNoImageToProcess => 'Ingen bild att behandla';

  @override
  String get errorPleaseEnterText => 'Ange text att tolka';

  @override
  String get errorPleaseEnterTextToImport => 'Ange text att importera';

  @override
  String get errorTextTooShort =>
      'Texten är för kort för att innehålla ett recept';

  @override
  String get errorNoRecipeToSave => 'Inget recept att spara';

  @override
  String get errorImportConditionsNotMet => 'Importvillkor inte uppfyllda';

  @override
  String get errorImportFailed => 'Import misslyckades';

  @override
  String get errorImportPartialReSignIn =>
      'Receptet sparades, men delningsstatus uppdaterades inte. Logga in igen och uppdatera för att rensa inkorgsposten.';

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
  String get errorCouldNotAddItem => 'Kunde inte lägga till varan';

  @override
  String get errorCouldNotUpdateItem => 'Kunde inte uppdatera varan';

  @override
  String get errorListNotFound => 'Lista hittades inte';

  @override
  String get errorCouldNotLoadGroupInfo => 'Kunde inte ladda gruppinformation';

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
      'Använd ”Lämna grupp” för att lämna konversationen';

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
  String get errorNoRecipeToFork => 'Inget recept att kopiera till egna recept';

  @override
  String get errorCouldNotForkRecipe =>
      'Kunde inte kopiera receptet till egna recept';

  @override
  String get errorNoRecipeToDelete => 'Inget recept att radera';

  @override
  String get errorNoPermissionToDelete =>
      'Du har inte behörighet att radera det här receptet';

  @override
  String get errorPasswordCannotBeEmpty => 'Lösenord kan inte vara tomt';

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
    return 'En tagg med namnet ”$name” finns redan';
  }

  @override
  String get errorGroupDoesNotExist => 'Gruppen finns inte';

  @override
  String get errorTagDoesNotExist => 'Taggen finns inte';

  @override
  String get errorRuleDoesNotExist => 'Regeln finns inte';

  @override
  String get errorOwnerMustKeepPermission =>
      'Ägaren måste behålla ägarbehörigheten';

  @override
  String get errorCouldNotLoadRecipes => 'Kunde inte ladda recept';

  @override
  String get errorCouldNotDeleteRecipe => 'Kunde inte radera receptet';

  @override
  String get errorCouldNotValidateImage => 'Kunde inte validera bild';

  @override
  String get actionRecipeSaving => 'sparar recept';

  @override
  String get actionRecipeUploading => 'laddar upp recept';

  @override
  String get actionRecipeLoading => 'laddar recept';

  @override
  String get actionRecipeDeleting => 'raderar recept';

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
  String get actionRecipeImageDelete => 'raderar bild';

  @override
  String get actionShoppingListCreate => 'skapar inköpslista';

  @override
  String get actionShoppingItemAdd => 'lägger till vara';

  @override
  String get actionShoppingListSync => 'synkroniserar inköpslista';

  @override
  String get actionShoppingListShare => 'delar inköpslista';

  @override
  String get actionShoppingListDelete => 'raderar inköpslista';

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
  String get actionAppStartup => 'startar appen';

  @override
  String get actionDataSync => 'synkroniserar data';

  @override
  String get actionBackgroundUpload => 'laddar upp i bakgrunden';

  @override
  String get actionOffline => 'arbetar offline';

  @override
  String errorNetworkNoConnection(String action) {
    return 'Ingen internetanslutning när du $action. Ändringar sparas lokalt och synkroniseras automatiskt när du är online igen.';
  }

  @override
  String errorNetworkLimited(String action) {
    return 'Begränsad internetanslutning när du $action. Vissa funktioner kan vara otillgängliga.';
  }

  @override
  String errorNetworkDegraded(String action) {
    return 'Anslutningsproblem när du $action. Vi kontrollerar anslutningen automatiskt.';
  }

  @override
  String errorNetworkTemporary(String action) {
    return 'Tillfälligt nätverksfel när du $action. Vi kontrollerar anslutningen och försöker igen automatiskt.';
  }

  @override
  String errorNetworkUnknownStatus(String action) {
    return 'Vi vet inte hur anslutningen är när du $action. Kontrollera internetanslutningen och försök igen.';
  }

  @override
  String errorAuthNoPermissionFor(String action) {
    return 'Du saknar behörighet när du $action';
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
    return '$base. Det här innehållet är inte delat med dig.';
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
    return 'Receptet kunde inte hittas när du $action. Det kan ha raderats eller flyttats av ägaren.';
  }

  @override
  String errorNotFoundShoppingList(String action) {
    return 'Inköpslistan kunde inte hittas när du $action. Den kan ha raderats, eller så har du inte längre åtkomst.';
  }

  @override
  String errorNotFoundImage(String action) {
    return 'Bilden kunde inte hittas när du $action. Den kan ha raderats eller flyttats.';
  }

  @override
  String errorNotFoundGeneric(String action) {
    return 'Innehållet kunde inte hittas när du $action. Det kan ha raderats, eller så har du inte längre åtkomst.';
  }

  @override
  String errorServiceMaintenance(String action) {
    return 'Tjänsten är tillfälligt otillgänglig för underhåll när du $action. Försök igen om några minuter.';
  }

  @override
  String errorServiceSync(String action) {
    return 'Synkroniseringen är tillfälligt otillgänglig när du $action. Ändringar sparas lokalt och synkroniseras automatiskt senare.';
  }

  @override
  String errorServiceTemporary(String action) {
    return 'Tjänsten är tillfälligt otillgänglig när du $action. Försök igen om ett par minuter.';
  }

  @override
  String errorDnsConnection(String action) {
    return 'Vi kunde inte ansluta till servern när du $action. Kontrollera internetanslutningen eller försök igen senare.';
  }

  @override
  String errorUnknownWhileAction(String action) {
    return 'Ett oväntat fel uppstod när du $action. Försök igen eller kontakta support om problemet kvarstår.';
  }

  @override
  String errorUnknownWithTechnical(String action, String techInfo) {
    return 'Ett oväntat fel uppstod när du $action. Försök igen eller kontakta support om problemet kvarstår.';
  }

  @override
  String errorFallbackWhileAction(String action) {
    return 'Ett fel uppstod när du $action. Försök igen.';
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
      'Kontrollera att bilderna är mindre än 10 MB';

  @override
  String get suggestionImageFormat => 'Använd JPG, PNG eller HEIC format';

  @override
  String get suggestionSelectAnotherDraft =>
      'Välj ett annat utkast från listan';

  @override
  String get suggestionCreateNewRecipe =>
      'Börja skapa ett nytt recept i stället';

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
  String get statusFirebaseUnavailable => 'Servern går inte att nå';

  @override
  String get statusNoInternet => 'Ingen internetanslutning';

  @override
  String get statusDisconnected => 'Frånkopplad';

  @override
  String get statusCheckingConnection => 'Kontrollerar anslutning …';

  @override
  String get statusReconnecting => 'Återansluter …';

  @override
  String get statusDone => 'Klar.';

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
  String get permissionWriter => 'Redigerare';

  @override
  String get permissionViewer => 'Läsare';

  @override
  String get permissionReader => 'Läsare';

  @override
  String get permissionUnknown => 'Okänd behörighet';

  @override
  String get activityJustNow => 'Just nu';

  @override
  String get activityActiveNow => 'Aktiv nu';

  @override
  String get activityActiveThisWeek => 'Aktiv den här veckan';

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
  String get notificationTitleSuccess => 'Klart.';

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
      'Lösenordet är för svagt. Använd tolv eller fler tecken, eller tre ord du minns.';

  @override
  String get errorLoginFailed => 'Inloggning misslyckades. Försök igen.';

  @override
  String get errorCouldNotLogOut => 'Kunde inte logga ut';

  @override
  String get errorCouldNotDeleteAccount => 'Kunde inte radera kontot';

  @override
  String get errorCouldNotCompleteMfa =>
      'Kunde inte slutföra inställningen av tvåstegsverifiering';

  @override
  String get errorMfaVerificationFailed => 'Tvåstegsverifieringen misslyckades';

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
      'Kunde inte radera receptet från servern';

  @override
  String errorRateLimitExceeded(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds sekunder',
      one: '1 sekund',
    );
    return 'För många förfrågningar. Försök igen om $_temp0.';
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
  String get errorCouldNotStartSync => 'Kunde inte starta synkronisering';

  @override
  String errorSyncErrorFor(String syncType) {
    return 'Synkroniseringsfel för $syncType';
  }

  @override
  String get errorCouldNotUpdateNotificationToken =>
      'Kunde inte uppdatera notistoken';

  @override
  String get errorCouldNotUpdateNotificationSettings =>
      'Kunde inte uppdatera notisinställningar';

  @override
  String get errorCouldNotUpdateAllergenSettings =>
      'Kunde inte uppdatera allergeninställningar';

  @override
  String get errorCouldNotLoadProfile => 'Kunde inte ladda profil';

  @override
  String get errorCouldNotUpdateRecipes => 'Kunde inte uppdatera recept';

  @override
  String get errorTimeout => 'Tidsgräns överskriden';

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
    return 'En grupp med namnet ”$name” finns redan';
  }

  @override
  String get errorUserNotLoggedIn => 'Användare inte inloggad';

  @override
  String get errorResourceNotFound => 'Resursen hittades inte';

  @override
  String get errorNoDeletePermission => 'Ingen behörighet att radera resursen';

  @override
  String get errorCannotRemoveResourceOwner =>
      'Kan inte ta bort ägaren från resursen';

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
  String participantOwnerOnly(String name) {
    return 'Endast ägare: $name';
  }

  @override
  String participantSummary(String owner, int count) {
    return 'Ägare: $owner, deltagare: $count';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veckor',
      one: '1 vecka',
    );
    return '$_temp0 sedan';
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
  String get backupSavedAndroid =>
      'Säkerhetskopian sparades i Android/data/…/Butlery';

  @override
  String get backupSavedIos => 'Säkerhetskopian sparades i Filer-appen';

  @override
  String get backupCouldNotFindStorageDir => 'Kunde inte hitta lagringsmapp';

  @override
  String get backupCouldNotReadFile => 'Kunde inte läsa filen';

  @override
  String get backupInvalidFile => 'Filen är ingen säkerhetskopia från Butlery';

  @override
  String get backupUnknownRecipe => 'Okänt recept';

  @override
  String get warningUrlImportNotARecipe =>
      'Denna sida verkar vara en nyhetsartikel. Det extraherade innehållet kanske inte är ett riktigt recept.';

  @override
  String backupImportedFromBackup(String date) {
    return 'Importerat från säkerhetskopia $date';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alla $count ändringar är synkade.',
      one: 'Ändringen är synkad.',
    );
    return '$_temp0';
  }

  @override
  String syncPartialSuccess(int synced, int total, int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total synkade',
      one: '1 synkad',
    );
    return '$synced av $_temp0, $remaining kvar';
  }

  @override
  String get syncFailedRetryLater =>
      'Synkronisering misslyckades, försöker igen senare';

  @override
  String get uploadNotificationComplete => 'Uppladdning slutförd';

  @override
  String get uploadNotificationCompleteBody => 'Bilden har laddats upp';

  @override
  String get uploadNotificationFailed => 'Uppladdning misslyckades';

  @override
  String get uploadNotificationFailedBody =>
      'Kunde inte ladda upp bilden efter flera försök';

  @override
  String uploadStatusWaiting(int pending) {
    String _temp0 = intl.Intl.pluralLogic(
      pending,
      locale: localeName,
      other: '$pending bilder',
      one: '1 bild',
    );
    return 'Väntar på att ladda upp $_temp0 …';
  }

  @override
  String uploadStatusUploading(int active, int progress, int pending) {
    String _temp0 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$active bilder',
      one: '1 bild',
    );
    return 'Laddar upp $_temp0 ($progress% klart, $pending väntar)';
  }

  @override
  String get uploadStatusPreparing => 'Förbereder uppladdning …';

  @override
  String uploadStatusRetrying(int attempt, int max) {
    return 'Försöker igen ($attempt/$max) …';
  }

  @override
  String get uploadStatusComplete => 'Uppladdning slutförd';

  @override
  String get uploadStatusCancelled => 'Uppladdning avbruten';

  @override
  String get uploadFailureNetwork => 'Nätverksfel – kontrollera anslutningen';

  @override
  String get uploadFailureValidation => 'Bilden kunde inte valideras';

  @override
  String get uploadFailureServer => 'Serverfel – försök igen';

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
    return 'Ett oväntat fel uppstod. Försök igen.';
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
  String get llmCostCeilingDay =>
      'Du har använt dagens AI-hjälp. Försök igen i morgon.';

  @override
  String get llmCostCeilingMonth =>
      'Du har använt månadens AI-hjälp. Försök igen nästa månad.';

  @override
  String llmInvalidArgument(String error) {
    return 'Begäran kunde inte behandlas. Försök igen.';
  }

  @override
  String llmGenericError(String error) {
    return 'Det gick inte att slutföra. Försök igen.';
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
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds sekunder',
      one: '1 sekund',
    );
    return 'Du importerar för snabbt. Vänta $_temp0.';
  }

  @override
  String rateLimitHourly(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuter',
      one: '1 minut',
    );
    return 'Du har nått timgränsen. Försök igen om $_temp0.';
  }

  @override
  String get rateLimitDaily =>
      'Du har nått dagens gräns för importer. Försök igen i morgon.';

  @override
  String get rateLimitAiDaily =>
      'AI-kvoten för i dag är slut. Försök igen i morgon.';

  @override
  String get rateLimitAiMonthly => 'AI-kvoten för månaden är slut.';

  @override
  String get rateLimitBudgetDaily =>
      'Dagens AI-budget är förbrukad. Försök igen i morgon.';

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
  String get importErrorAiQuotaExhausted => 'AI-kvoten är slut för i dag';

  @override
  String get importErrorInvalidUrl => 'Ogiltig URL';

  @override
  String get importErrorCouldNotReachPage => 'Länken kunde inte läsas';

  @override
  String get importErrorLoginRequired => 'Sidan kräver inloggning';

  @override
  String get importErrorNoRecipeFound => 'Vi hittade inget recept på sidan';

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
  String get shoppingListEmpty => 'Inköpslistan är tom';

  @override
  String shoppingListAllBought(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alla $count varor köpta',
      one: '1 vara köpt',
    );
    return '$_temp0';
  }

  @override
  String shoppingListItemsRemaining(int remaining, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$remaining av $total varor kvar',
      one: '$remaining av 1 vara kvar',
    );
    return '$_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagar',
      one: '1 dag',
    );
    return '$_temp0 sedan';
  }

  @override
  String shoppingListLastActivityBy(String name, String time) {
    return 'Senaste aktivitet av $name $time';
  }

  @override
  String shoppingListUpdatedByNotice(String name) {
    return 'Listan uppdaterades av $name';
  }

  @override
  String get shoppingListUpdatedByUnknown =>
      'Listan uppdaterades av någon annan';

  @override
  String shoppingListChangedQuantity(
    String name,
    String item,
    String before,
    String after,
  ) {
    return '$name ändrade $item: $before → $after';
  }

  @override
  String shoppingListChangedItem(String name, String before, String after) {
    return '$name ändrade $before → $after';
  }

  @override
  String shoppingListAddedItem(String name, String item) {
    return '$name lade till $item';
  }

  @override
  String shoppingListRemovedItem(String name, String item) {
    return '$name tog bort $item';
  }

  @override
  String shoppingListBoughtItem(String name, String item) {
    return '$name bockade av $item';
  }

  @override
  String shoppingListUnboughtItem(String name, String item) {
    return '$name bockade ur $item';
  }

  @override
  String shoppingListMoreChanges(String summary, int count) {
    return '$summary och $count till';
  }

  @override
  String unknownResourceType(String value) {
    return 'Okänd RealtimeResourceType: $value';
  }

  @override
  String get notificationTitleDailySummary => 'Daglig sammanfattning';

  @override
  String get notificationBodyNoActivityToday => 'Ingen ny aktivitet i dag';

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
  String get recipeShareRequestNotifTitle => 'Receptförfrågan';

  @override
  String recipeShareRequestNotifBody(String name, String title) {
    return '$name vill se ditt recept ”$title”';
  }

  @override
  String recipeShareRequestBanner(String name) {
    return '$name vill se det här receptet';
  }

  @override
  String recipeShareRequestShareAction(String name) {
    return 'Dela med $name';
  }

  @override
  String recipeShareRequestShared(String name) {
    return 'Delat med $name';
  }

  @override
  String recipeShareRequestShareFailed(String name) {
    return 'Receptet kunde inte delas med $name.';
  }

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inköpslistor',
      one: '1 inköpslista',
    );
    return '$_temp0';
  }

  @override
  String notificationDigestCollaborations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count samarbeten',
      one: '1 samarbete',
    );
    return '$_temp0';
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
  String notificationBatchBodyRecipes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nya händelser',
      one: '1 ny händelse',
    );
    return '$_temp0 på dina recept';
  }

  @override
  String notificationBatchBodyFriends(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nya aktiviteter',
      one: '1 ny aktivitet',
    );
    return '$_temp0 från dina vänner';
  }

  @override
  String notificationBatchBodyShopping(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count uppdateringar',
      one: '1 uppdatering',
    );
    return '$_temp0 av dina inköpslistor';
  }

  @override
  String notificationBatchBodyCollaboration(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nya samarbetsaktiviteter',
      one: '1 ny samarbetsaktivitet',
    );
    return '$_temp0';
  }

  @override
  String notificationBatchBodyDefault(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nya händelser',
      one: '1 ny händelse',
    );
    return '$_temp0 i Butlery';
  }

  @override
  String notificationDigestBody(int totalCount, String summary) {
    String _temp0 = intl.Intl.pluralLogic(
      totalCount,
      locale: localeName,
      other: '$totalCount nya aktiviteter',
      one: '1 ny aktivitet',
    );
    return 'Du har $_temp0: $summary';
  }

  @override
  String uploadStatusUploadingNoPending(int active, int progress) {
    String _temp0 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$active bilder',
      one: '1 bild',
    );
    return 'Laddar upp $_temp0 ($progress% klart)';
  }

  @override
  String uploadStatusPartialFailure(int completed, int total, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total bilder uppladdade',
      one: '1 bild uppladdad',
    );
    return '$completed av $_temp0, $failed misslyckades';
  }

  @override
  String uploadStatusAllFailed(int failed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total bilder',
      one: '1 bild',
    );
    return '$failed av $_temp0 misslyckades – tryck för att försöka igen';
  }

  @override
  String uploadStatusAllSuccess(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'Alla $total bilder uppladdade',
      one: 'Bilden är uppladdad',
    );
    return '$_temp0';
  }

  @override
  String uploadStatusAllCancelled(int cancelled) {
    String _temp0 = intl.Intl.pluralLogic(
      cancelled,
      locale: localeName,
      other: 'Alla $cancelled uppladdningar avbrutna',
      one: 'Uppladdningen avbröts',
    );
    return '$_temp0';
  }

  @override
  String uploadProgressWithTime(int progress, String time) {
    return '$progress% klart – $time kvar';
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
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total slutförda',
      one: '1 slutförd',
    );
    return '$completed av $_temp0';
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
  String get uploadPreparing => 'Förbereder uppladdning …';

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
    return 'Bildkvaliteten är för låg för textavläsning ($quality%).';
  }

  @override
  String get errorOcrServicesUnavailable =>
      'Textavläsningen är tillfälligt otillgänglig. Försök igen om några minuter.';

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
  String errorCouldNotPerformOperation(String operation, String error) {
    return 'Kunde inte $operation. Försök igen.';
  }

  @override
  String errorCouldNotCreateRealtimeMenu(String error) {
    return 'Menyn kunde inte skapas. Försök igen.';
  }

  @override
  String errorCouldNotWatchMenu(String error) {
    return 'Menyn kunde inte följas. Försök igen.';
  }

  @override
  String errorCouldNotDeleteRealtimeMenu(String error) {
    return 'Menyn kunde inte raderas. Försök igen.';
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
      'Bilden är för suddig eller för liten – försök igen i bättre ljus.';

  @override
  String get syncErrorParsingResource => 'Kunde inte läsa innehållet';

  @override
  String syncErrorWatchingResource(String resourceId) {
    return 'Kunde inte följa ändringar i $resourceId';
  }

  @override
  String get notificationActionAccept => 'Acceptera';

  @override
  String get notificationActionDecline => 'Avböj';

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
  String get tiktokOriginalText => 'Originaltext från TikTok:';

  @override
  String get tiktokIdentifiedIngredients => 'Identifierade ingredienser:';

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
  String get importPhaseFetching => 'Hämtar innehåll …';

  @override
  String get importPhaseAnalyzing => 'Analyserar recept …';

  @override
  String get importPhaseCreating => 'Skapar recept …';

  @override
  String get importPhaseComplete => 'Klar.';

  @override
  String get importPhaseNeedsHelp => 'Behöver din hjälp';

  @override
  String get importPhaseError => 'Importen kunde inte slutföras';

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
    return 'Ta gärna en titt på det här receptet: ”$title”.';
  }

  @override
  String get shareMessageRecipeDefault =>
      'Jag hittade ett recept jag ville dela med dig.';

  @override
  String shareMessageMenuWithTitle(String title) {
    return 'Här är min veckomeny: ”$title”';
  }

  @override
  String get shareMessageMenuDefault =>
      'Här är min veckomeny, kanske till inspiration.';

  @override
  String shareMessageShoppingListWithTitle(String title) {
    return 'Vill du hjälpa mig med inköpslistan: ”$title”?';
  }

  @override
  String get shareMessageShoppingListDefault =>
      'Vill du hjälpa mig med inköpen denna vecka?';

  @override
  String get textImportSuggestionIngredients =>
      'Inkludera ingredienslista för bättre tolkning';

  @override
  String get textImportSuggestionInstructions =>
      'Inkludera instruktioner eller steg';

  @override
  String get textImportSuggestionTime =>
      'Inkludera tid att laga om tillgänglig';

  @override
  String get textImportSuggestionPortions =>
      'Inkludera antal portioner om känt';

  @override
  String get textImportSuggestionLooksGood =>
      'Texten ser bra ut för recepttolkning';

  @override
  String get recipeFormPermissionsError => 'Kunde inte läsa behörigheterna';

  @override
  String createSharedListError(String error) {
    return 'Den delade listan kunde inte skapas. Försök igen.';
  }

  @override
  String get userStatusOnline => 'Online';

  @override
  String recipeCookTimeMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minuter',
      one: '1 minut',
    );
    return '$_temp0';
  }

  @override
  String get recipeLastCookedToday => 'Lagad i dag';

  @override
  String get recipeLastCookedYesterday => 'Lagad i går';

  @override
  String recipeLastCookedDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagar',
      one: '1 dag',
    );
    return 'Lagad för $_temp0 sedan';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vänner',
      one: '1 vän',
    );
    return '$_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count aktiva kollaboratörer',
      one: '1 aktiv kollaboratör',
    );
    return '$_temp0';
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
  String get timeJustNow => 'just nu';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes min sedan';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours tim sedan';
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
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagar',
      one: '1 dag',
    );
    return '$_temp0 sedan';
  }

  @override
  String timeWeeksAgo(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks veckor',
      one: '1 vecka',
    );
    return '$_temp0 sedan';
  }

  @override
  String get timeNow => 'Nu';

  @override
  String get dateTomorrow => 'I morgon';

  @override
  String get dateNoDate => 'Inget datum';

  @override
  String dateDaysAhead(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagar',
      one: '1 dag',
    );
    return '$_temp0 framåt';
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
  String get labelShopping => 'Inköp';

  @override
  String get labelCollaborativeMenu => 'Kollaborativ meny';

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
  String get buttonCreating => 'Skapar …';

  @override
  String get buttonCreateAndShare => 'Skapa och dela';

  @override
  String get labelNoCategories => 'Inga kategorier';

  @override
  String labelAndNMore(int count) {
    return 'och $count till';
  }

  @override
  String get labelGroup => 'Grupp';

  @override
  String get labelYou => 'Du';

  @override
  String get validationSelectIngredient => 'Välj minst en ingrediens';

  @override
  String get statusListLoaded => 'Lista laddad';

  @override
  String get labelUntitledMenu => 'Namnlös meny';

  @override
  String get labelUntitledList => 'Namnlös lista';

  @override
  String get labelUntitledRecipe => 'Namnlöst recept';

  @override
  String get labelUnknownContent => 'Okänt innehåll';

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
    String _temp0 = intl.Intl.pluralLogic(
      invitedCount,
      locale: localeName,
      other: '$invitedCount inbjudningar skickade',
      one: '1 inbjudan skickad',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skippedCount,
      locale: localeName,
      other: '$skippedCount vänner',
      one: '1 vän',
    );
    return '$_temp0. $_temp1 hoppades över (har redan tillgång).';
  }

  @override
  String get errorCouldNotSendInvitations => 'Kunde inte skicka inbjudningar';

  @override
  String get shareDefaultShoppingListMessage =>
      'Delar gärna den här inköpslistan med dig.';

  @override
  String shoppingListAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alla $count varor klara',
      one: '1 vara klar',
    );
    return '$_temp0';
  }

  @override
  String shoppingListItemsToBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count varor att köpa',
      one: '1 vara att köpa',
    );
    return '$_temp0';
  }

  @override
  String get errorGenericOccurred => 'Det gick inte att slutföra';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count veckor',
      one: '1 vecka',
    );
    return '$_temp0 sedan';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count timmar',
      one: '1 timme',
    );
    return '$_temp0 sedan';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count timmar',
      one: '1 timme',
    );
    return '$_temp0 kvar';
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
    String sender,
    String emoji,
    String group,
    String message,
  ) {
    return '$sender bjöd in dig till gruppen $emoji $group: ”$message”';
  }

  @override
  String groupInvitationNotificationSimple(
    String sender,
    String emoji,
    String group,
  ) {
    return '$sender bjöd in dig till gruppen $emoji $group';
  }

  @override
  String get invitationStatusPending => 'Väntande';

  @override
  String get invitationStatusAccepted => 'Accepterad';

  @override
  String get invitationStatusRejected => 'Avböjd';

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
      'Skrivskyddat – du kan spara din egen kopia';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagar',
      one: '1 dag',
    );
    return 'Medlem i $_temp0';
  }

  @override
  String memberSinceMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count månader',
      one: '1 månad',
    );
    return 'Medlem i $_temp0';
  }

  @override
  String memberSinceYears(int count) {
    return 'Medlem i $count år';
  }

  @override
  String get commentDeleted => '[Kommentar borttagen]';

  @override
  String sharedMenuTitlePattern(String name) {
    return '${name}s veckomeny';
  }

  @override
  String importedFromMenu(String name, String title) {
    return 'Importerat från ${name}s meny ”$title”';
  }

  @override
  String get importedRecipeLabel => 'Importerat recept';

  @override
  String get labelEmptyMenu => 'Tom meny';

  @override
  String get errorNetworkFallback => 'Nätverksfel';

  @override
  String get recipeCollaborationEnable => 'Aktivera samarbete';

  @override
  String get recipeCollaborationDisable => 'Avaktivera samarbete';

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
  String get recipeSharingRemoveGroup => 'Ta bort gruppens åtkomst';

  @override
  String recipeSharingRevokeConfirm(String name) {
    return 'Sluta dela med $name?';
  }

  @override
  String recipeSharingRevokeSuccess(String name) {
    return 'Delning med $name avslutad';
  }

  @override
  String recipeSharingRevokeGroupConfirm(String name) {
    return 'Ta bort åtkomsten till receptet för gruppen $name? De du även delat med enskilt eller via en annan grupp har kvar sin åtkomst.';
  }

  @override
  String recipeSharingRevokeGroupSuccess(String name) {
    return 'Gruppen $name har inte längre åtkomst till receptet. De du även delat med enskilt eller via en annan grupp har kvar sin åtkomst.';
  }

  @override
  String get recipeSharingFriends => 'Vänner';

  @override
  String get recipeSharingGroups => 'Grupper';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count varor',
      one: '1 vara',
    );
    return '$_temp0';
  }

  @override
  String shoppingTemplateUsedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count gånger',
      one: '1 gång',
    );
    return 'Använd $_temp0';
  }

  @override
  String get labelButleryUser => 'Butlery-användare';

  @override
  String get shoppingListSummaryEmpty => 'Inköpslistan är tom';

  @override
  String shoppingListSummaryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Alla $count varor klara',
      one: '1 vara klar',
    );
    return '$_temp0';
  }

  @override
  String shoppingListSummaryToBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count varor att köpa',
      one: '1 vara att köpa',
    );
    return '$_temp0';
  }

  @override
  String shoppingListSummaryRemaining(int remaining, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$remaining av $total varor kvar',
      one: '$remaining av 1 vara kvar',
    );
    return '$_temp0';
  }

  @override
  String notificationBatchComments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nya kommentarer',
      one: '1 ny kommentar',
    );
    return '$_temp0 på dina recept';
  }

  @override
  String notificationCommentSingle(String author, String recipe) {
    return '$author kommenterade på ”$recipe”';
  }

  @override
  String notificationCommentMultipleSameAuthor(
    String author,
    int count,
    String recipe,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kommentarer',
      one: '1 kommentar',
    );
    return '$author skrev $_temp0 på ”$recipe”';
  }

  @override
  String notificationCommentMultipleAuthors(
    int authorCount,
    int commentCount,
    String recipe,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      authorCount,
      locale: localeName,
      other: '$authorCount personer',
      one: '1 person',
    );
    String _temp1 = intl.Intl.pluralLogic(
      commentCount,
      locale: localeName,
      other: '$commentCount kommentarer',
      one: '1 kommentar',
    );
    return '$_temp0 skrev $_temp1 på ”$recipe”';
  }

  @override
  String notificationRatingSingle(String recipe, int count, String period) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nya betyg',
      one: '1 nytt betyg',
    );
    return 'Ditt recept ”$recipe” fick $_temp0 denna $period.';
  }

  @override
  String notificationRatingMultiple(
    int totalRatings,
    int recipeCount,
    String period,
  ) {
    String _temp0 = intl.Intl.pluralLogic(
      totalRatings,
      locale: localeName,
      other: '$totalRatings nya betyg',
      one: '1 nytt betyg',
    );
    return 'Dina recept fick totalt $_temp0 på $recipeCount recept denna $period.';
  }

  @override
  String notificationRatingReceived(String rater, String stars) {
    return '$rater betygsatte ditt recept $stars';
  }

  @override
  String notificationRatingFirstReview(String rater, String review) {
    return '$rater skrev din första recension: $review';
  }

  @override
  String notificationRatingFirstRating(String rater, String stars) {
    return '$rater gav ditt recept dess första betyg: $stars';
  }

  @override
  String notificationRatingMilestoneCount(int count) {
    return 'Ditt recept har fått $count betyg.';
  }

  @override
  String notificationRatingMilestoneAverage(String average) {
    return 'Ditt recept har $average i genomsnittsbetyg.';
  }

  @override
  String notificationRatingBatch(int count, String average) {
    return 'Ditt recept fick $count nya betyg. Genomsnitt: $average';
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
  String get validationFieldCookingTime => 'Tid att laga';

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
      'Visningsnamn får bara innehålla bokstäver, siffror, mellanslag, bindestreck, understreck och punkt';

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
  String get validationShoppingItemRequired => 'Ange varans namn';

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
  String get validationPasswordRule =>
      'Lösenordet behöver tolv eller fler tecken, eller tre ord du minns.';

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
  String get validationFieldArticle => 'Vara';

  @override
  String errorImageUploadFailed(String message) {
    return 'Bilden kunde inte laddas upp. Försök igen.';
  }

  @override
  String errorRecipeServiceFailed(String message) {
    return 'Receptet kunde inte behandlas. Försök igen.';
  }

  @override
  String errorPermissionFailed(String message) {
    return 'Du saknar behörighet för det här. Be ägaren om åtkomst.';
  }

  @override
  String errorNetworkWithDetail(String message) {
    return 'Nätverksfel. Kontrollera anslutningen och försök igen.';
  }

  @override
  String errorStorageFailed(String message) {
    return 'Lagringen misslyckades. Kontrollera utrymmet på telefonen och försök igen.';
  }

  @override
  String errorCollaborationFailed(String message) {
    return 'Samarbetet kunde inte uppdateras. Försök igen.';
  }

  @override
  String errorAutoSaveFailed(String message) {
    return 'Autosparningen misslyckades. Spara själv så att ändringarna inte går förlorade.';
  }

  @override
  String errorSystemFailed(String message) {
    return 'Ett systemfel uppstod. Försök igen.';
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
    return 'Bilduppladdning gör framsteg – $percentage% slutförd';
  }

  @override
  String get feedbackDescriptionRequired => 'Ange en beskrivning';

  @override
  String get feedbackThanks => 'Tack för din återkoppling.';

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
    return 'Problem när du $action: $issue';
  }

  @override
  String errorDuringActionRecovery(
    String action,
    String issue,
    String recovery,
  ) {
    return 'Problem när du $action: $issue\n\nFörslag: $recovery';
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
    return 'Valideringen misslyckades. Kontrollera uppgifterna och försök igen.';
  }

  @override
  String get snackbarNoInternet =>
      'Ingen internetanslutning. Kontrollera din anslutning.';

  @override
  String get errorInvalidYoutubeUrl => 'Ogiltig YouTube-URL';

  @override
  String errorInvalidCategoryNamesFromTo(
    String fromCategory,
    String toCategory,
  ) {
    return 'Ogiltiga kategorinamn: $fromCategory -> $toCategory';
  }

  @override
  String get errorPreservedLink => 'Länken ligger kvar i fältet.';

  @override
  String get errorPreservedPhoto => 'Bilden ligger kvar.';

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
  String get shareTimeLabelBold => '**Tid:**';

  @override
  String get sharePortionsLabelBold => '**Portioner:**';

  @override
  String get shareRatingLabelBold => '**Betyg:**';

  @override
  String get shareTypeLabelBold => '**Typ:**';

  @override
  String get shareTagsLabel => 'Taggar';

  @override
  String get shareInstructionsLabelCompact => 'Instruktioner:';

  @override
  String get shareShoppingListTitleSimple => 'Inköpslista';

  @override
  String get shareWeekMenuTitle => 'Veckomeny';

  @override
  String get shareWeekMenuTitleEmoji => 'VECKOMENY';

  @override
  String get shareSummaryLabel => 'Sammanfattning:';

  @override
  String shareSummaryRecipesInCategories(int recipeCount, int categoryCount) {
    String _temp0 = intl.Intl.pluralLogic(
      categoryCount,
      locale: localeName,
      other: '$categoryCount kategorier',
      one: '1 kategori',
    );
    return '$recipeCount recept i $_temp0';
  }

  @override
  String get unsavedChangesTitle => 'Osparade ändringar';

  @override
  String get unsavedChangesMessage =>
      'Du har osparade ändringar. Vill du verkligen avbryta?';

  @override
  String get cancelWithoutSaving => 'Avbryt utan att spara';

  @override
  String get deleteActionIrreversible => 'Det går inte att ångra.';

  @override
  String get groupLeaveTitle => 'Lämna grupp?';

  @override
  String groupLeaveMessage(String name) {
    return 'Vill du verkligen lämna gruppen ”$name”?';
  }

  @override
  String get groupLeaveAction => 'Lämna grupp';

  @override
  String get recipeDeleteWarning =>
      'Receptet flyttas till papperskorgen och ligger kvar där i 30 dagar.';

  @override
  String get commentEditHint => 'Redigera din kommentar';

  @override
  String get commentLabel => 'Kommentar';

  @override
  String get commentEditError => 'Kunde inte uppdatera kommentaren';

  @override
  String get commentEdited => 'Kommentar uppdaterad';

  @override
  String get commentReact => 'Reagera';

  @override
  String get reactionUpdateError => 'Kunde inte uppdatera reaktion';

  @override
  String get pollVoteSingular => 'röst';

  @override
  String get pollVotePlural => 'röster';

  @override
  String get pollClosed => 'Avslutad';

  @override
  String get pollVotesNotLoadedShort => 'Rösterna har inte hämtats';

  @override
  String get pollVotesFailedShort => 'Rösterna kunde inte läsas';

  @override
  String get pollVotesNotLoadedHint => 'Öppna chatten igen för att hämta dem.';

  @override
  String get pollVotesFailedHint => 'Försök igen om en stund.';

  @override
  String get pollCloseRefusedVotesUnread =>
      'Omröstningen avslutades inte – rösterna har inte hämtats, och den får inte stängas på siffror som inte är lästa. Öppna chatten igen och försök på nytt.';

  @override
  String get pollClosedWithoutPlan =>
      'Omröstningen är avslutad, men rätten kunde inte läggas in i menyn. Lägg in den själv.';

  @override
  String get pollCloseRefusedBlockList =>
      'Omröstningen avslutades inte – din blockeringslista kunde inte läsas, så blockerade röster går inte att räkna bort. Försök igen.';

  @override
  String get pollCloseRefusedBlockListOffline =>
      'Omröstningen avslutades inte – appen är offline och kan inte kontrollera din blockeringslista. Försök igen när du har nätverk.';

  @override
  String get pollCloseFailed =>
      'Omröstningen kunde inte avslutas. Försök igen.';

  @override
  String get pollCloseAction => 'Stäng omröstning';

  @override
  String get pollCloseConfirmTitle => 'Avsluta omröstningen?';

  @override
  String pollCloseConfirmLeader(String name, int votes) {
    String _temp0 = intl.Intl.pluralLogic(
      votes,
      locale: localeName,
      other: '$votes röster',
      one: '1 röst',
    );
    return 'Just nu leder $name med $_temp0. Det går inte att ångra när omröstningen är avslutad.';
  }

  @override
  String pollCloseConfirmTie(String names, String name) {
    return 'Just nu är det lika mellan $names. $name kom först och vinner om du avslutar nu. Det går inte att ångra.';
  }

  @override
  String get pollCloseConfirmNoVotes =>
      'Ingen har röstat än, så ingen vinner. Det går inte att ångra när omröstningen är avslutad.';

  @override
  String get pollCloseConfirmAction => 'Avsluta';

  @override
  String get pollCloseConfirmKeepOpen => 'Behåll öppen';

  @override
  String get authRequiredError => 'Du måste vara inloggad';

  @override
  String get shoppingListEditPermissionDenied =>
      'Du har inte behörighet att redigera denna delade inköpslista';

  @override
  String get userStatusOffline => 'Offline';

  @override
  String get userStatusAway => 'Borta';

  @override
  String get userStatusBusy => 'Upptagen';

  @override
  String get restoreDraft => 'Återställ';

  @override
  String fieldsFilledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fält ifyllda',
      one: '1 fält ifyllt',
    );
    return '$_temp0';
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
  String get portionsUnit => 'portioner';

  @override
  String sharedRecipeFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
    );
    return 'Delat recept · $_temp0';
  }

  @override
  String sharedMenuFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar',
      one: '1 medlem',
    );
    return 'Delad meny · $_temp0';
  }

  @override
  String get sharedFallback => 'Delat';

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
  String get accountSecurityPasswordChanged => 'Lösenordet har ändrats';

  @override
  String get accountSecurityEmailVerificationSent =>
      'Verifieringslänk skickad till ny e-postadress';

  @override
  String get accountSecurityEmailChangeHow =>
      'Vi skickar en länk till den nya adressen. Bytet gäller först när du har öppnat den, och då får din nuvarande adress ett e-postmeddelande där bytet kan ångras.';

  @override
  String get accountSecurityPasswordMismatch => 'Lösenorden matchar inte';

  @override
  String get passwordsMatch => 'Lösenorden matchar';

  @override
  String get selectionEnter => 'Välj';

  @override
  String get selectionEnterRecipes => 'Välj recept';

  @override
  String get selectionEnterShoppingItems => 'Välj varor';

  @override
  String get selectionEnterPantryItems => 'Välj varor i skafferiet';

  @override
  String get selectionEnterTags => 'Välj taggar';

  @override
  String get selectionEnterMembers => 'Välj medlemmar';

  @override
  String get selectionEnterBlockedUsers => 'Välj blockerade personer';

  @override
  String selectionSelectAllCount(int count) {
    return 'Markera alla $count';
  }

  @override
  String bulkSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valda',
      one: '1 vald',
    );
    return '$_temp0';
  }

  @override
  String get bulkMoreActions => 'Fler åtgärder';

  @override
  String get bulkDelete => 'Radera valda';

  @override
  String get bulkShare => 'Dela valda';

  @override
  String get bulkShareFriendsLoadFailed => 'Kunde inte läsa dina vänner';

  @override
  String get bulkShareSelectionKept => 'Recepten är fortfarande valda.';

  @override
  String get bulkTag => 'Tagga valda';

  @override
  String bulkTagDialogTitle(int count) {
    return 'Lägg till tagg på $count recept';
  }

  @override
  String get bulkTagNoTagsAvailable => 'Inga egna taggar att välja';

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
  String get imageCropTitle => 'Beskär bild';

  @override
  String get bulkDeleteConfirmMessage =>
      'De valda recepten flyttas till papperskorgen och ligger kvar där i 30 dagar.';

  @override
  String bulkDeleteSuccess(int count) {
    return '$count recept ligger i papperskorgen i 30 dagar';
  }

  @override
  String get profileFaq => 'Vanliga frågor';

  @override
  String get faqQ1 => 'Hur importerar jag recept?';

  @override
  String get faqA1 =>
      'Du kan importera recept på flera sätt: klistra in en URL från en receptsida, ta ett foto av ett recept, eller klistra in recepttext direkt. Tryck på ”Lägg till” på startsidan och välj metod.';

  @override
  String get faqQ2 => 'Hur delar jag recept med vänner?';

  @override
  String get faqA2 =>
      'Öppna ett recept och tryck på dela-ikonen. Du kan skicka receptet till vänner som använder Butlery, eller dela en länk. Dina vänner kan sedan spara receptet till sin egen samling.';

  @override
  String get faqQ3 => 'Hur använder jag veckomeny?';

  @override
  String get faqA3 =>
      'Gå till veckomeny via navigeringen. Där kan du planera veckans måltider genom att lägga till recept från din samling. Ingredienser från menyn kan skickas direkt till inköpslistan.';

  @override
  String get faqQ4 => 'Hur skapar jag egna taggar?';

  @override
  String get faqA4 =>
      'Gå till Mer och välj ”Egna taggar”. Där kan du skapa taggar som ”Vardagsmat” eller ”Festmat” och tilldela dem till dina recept för enkel filtrering.';

  @override
  String get faqQ5 => 'Hur rapporterar jag problem?';

  @override
  String get faqA5 =>
      'Tryck på ”!”-knappen som syns längst ner till höger på varje sida. Där kan du beskriva problemet, välja kategori och bifoga en skärmbild. Vi läser all återkoppling.';

  @override
  String get legalTermsOfService => 'Användarvillkor';

  @override
  String get legalCommunityGuidelines => 'Communityriktlinjer';

  @override
  String get legalOpenSourceLicenses => 'Licenser för öppen källkod';

  @override
  String get authTermsAcceptPrefix => 'Jag accepterar ';

  @override
  String get authTermsConsentPrefix => 'Jag godkänner ';

  @override
  String get authTermsConsentTermsLink => 'användarvillkoren';

  @override
  String get authTermsConsentPrivacyLink => 'integritetspolicyn';

  @override
  String get authTermsAcceptMiddle => ' och ';

  @override
  String get authTermsAcceptRequired =>
      'Du måste acceptera villkoren för att skapa ett konto';

  @override
  String get a11yTermsOfServiceLink => 'Användarvillkor';

  @override
  String get a11yPrivacyPolicyLink => 'Integritetspolicy';

  @override
  String a11yLinkTo(String url) {
    return 'Länk till $url';
  }

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
  String get reportDescriptionHint => 'Berätta vad som är fel …';

  @override
  String get reportSubmitted => 'Anmälan har skickats';

  @override
  String get reportSubmitFailed => 'Anmälan kunde inte skickas';

  @override
  String get reportDialogTitle => 'Anmäl innehåll';

  @override
  String get reportSubmit => 'Skicka anmälan';

  @override
  String get reportDialogGuidelinesNotePrefix => 'Vi bedömer mot';

  @override
  String get reportDialogGuidelinesLink => 'våra riktlinjer';

  @override
  String get myReportsTitle => 'Mina rapporter';

  @override
  String get myReportsEmpty => 'Du har inte skickat in några rapporter än.';

  @override
  String get myReportsStatusPending => 'Inkommen';

  @override
  String get myReportsStatusReviewed => 'Granskas';

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
  String get newAccountSocialBlockedDm =>
      'Bekräfta din e-post för att skicka meddelanden';

  @override
  String get newAccountSocialBlockedGroup =>
      'Bekräfta din e-post för att bjuda in till grupp';

  @override
  String get newAccountSocialBlockedComment =>
      'Bekräfta din e-post för att kommentera';

  @override
  String get newAccountSocialResendEmail => 'Skicka e-post igen';

  @override
  String get socialAccepting => 'Accepterar …';

  @override
  String get newAccountSocialEmailResent => 'Ny bekräftelse skickad';

  @override
  String get newAccountSocialEmailResendFailed =>
      'Kunde inte skicka bekräftelsen';

  @override
  String get contentFilterWarning =>
      'Texten innehåller olämpligt språk. Redigera innan du skickar.';

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
  String get emailVerificationTitle => 'Bekräfta din e-post';

  @override
  String emailVerificationMessage(String email) {
    return 'Vi har skickat en länk till $email. Skärmen går vidare av sig själv när du klickat.';
  }

  @override
  String get emailVerificationResend => 'Skicka igen';

  @override
  String emailVerificationResendCountdown(int seconds) {
    return 'Skicka igen ($seconds s)';
  }

  @override
  String get emailVerificationContinue => 'Fortsätt utan att bekräfta';

  @override
  String get emailVerificationSuccess => 'E-posten är verifierad.';

  @override
  String get a11yCookingModeFontScale => 'Ändra textstorlek';

  @override
  String get a11yCookingModeRotate => 'Vrid skärmen';

  @override
  String get a11yCookingModeClose => 'Stäng matlagningsläge';

  @override
  String get a11yRecipeFavorited => 'Recept tillagt i favoriter';

  @override
  String get a11yRecipeUnfavorited => 'Recept borttaget från favoriter';

  @override
  String get a11yCommentPosted => 'Kommentar publicerad';

  @override
  String get a11yItemBought => 'Markerad som köpt';

  @override
  String get a11yItemUnbought => 'Markerad som ej köpt';

  @override
  String get a11yOcrComplete => 'Textavläsning klar';

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
  String get statsRecipeCollection => 'Samlingen';

  @override
  String get statsTotalRecipes => 'recept';

  @override
  String get statsFavorites => 'favoriter';

  @override
  String get statsRecentlyCooked => 'lagade senaste veckan';

  @override
  String get statsWithImages => 'med bild';

  @override
  String get statsPersonalRecipes => 'Egna recept';

  @override
  String get statsCollaborativeRecipes => 'Delade recept';

  @override
  String get statsHighRated => 'Högt betygsatta';

  @override
  String get statsMealTypes => 'Vad du lagar';

  @override
  String get statsPopularTags => 'Vanligaste taggarna';

  @override
  String get statsCookingActivity => 'Matlagningsaktivitet';

  @override
  String get statsTotalCooks => 'Totalt antal gånger lagat';

  @override
  String get statsNoMealTypes => 'Inga måltidstyper registrerade';

  @override
  String get statsNoTags => 'Inga taggar använda än';

  @override
  String statsCountedNote(int count) {
    return 'Räknat på $count recept i telefonen. Siffrorna gäller din samling som den är hämtad hit – inte en beräkning på servern.';
  }

  @override
  String get statsDistinctMealTypes => 'Måltidstyper';

  @override
  String get statsDistinctTags => 'Taggar';

  @override
  String get importPendingRetryPrompt =>
      'Du har en väntande import – försök igen?';

  @override
  String get importPendingRetry => 'Försök igen';

  @override
  String get importPendingDismiss => 'Släng';

  @override
  String get importSavedForLater =>
      'URL sparad – importeras när du är online igen';

  @override
  String get importOfflineMessage =>
      'Du är offline – anslut till internet och försök igen.';

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
  String get quickCaptureSave => 'Spara';

  @override
  String get quickCaptureSaved => 'Receptet är sparat.';

  @override
  String get quickCaptureEditAction => 'Redigera';

  @override
  String get quickCaptureTitleHint => 'Vad heter rätten?';

  @override
  String get quickCaptureHelp =>
      'Receptet sparas som ett kort utan detaljer – du kan importera ingredienser och steg när du vill.';

  @override
  String get a11ySwipeEditAction => 'Redigera recept';

  @override
  String get a11ySwipeDeleteAction => 'Radera receptet';

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
  String get recipeImproveMissingTime => 'Tid att laga';

  @override
  String get recipeImproveMissingImage => 'Bild';

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
  String get duplicateMergeFailed => 'Kunde inte sammanfoga receptet';

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
  String get publicProfileEmpty => 'Denna användare har inga publika recept';

  @override
  String get publicProfileError => 'Profilen hittades inte';

  @override
  String get publicProfileShareButton => 'Dela profil';

  @override
  String get statsCompleteness => 'Receptkvalitet';

  @override
  String get statsWithoutPhoto => 'Utan foto';

  @override
  String get statsWithoutTime => 'Utan tid';

  @override
  String get statsIncomplete => 'Ofullständiga';

  @override
  String get statsAllComplete => 'Alla recept är kompletta.';

  @override
  String get notificationsTitle => 'Notiser';

  @override
  String get notificationsEmpty => 'Inga notiser än';

  @override
  String get notificationsErrorLoad => 'Kunde inte ladda notiser';

  @override
  String notificationsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count markerade',
      one: '1 markerad',
    );
    return '$_temp0';
  }

  @override
  String get notificationsMarkAllReadShort => 'Markera alla lästa';

  @override
  String notificationsUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count olästa',
      one: '1 oläst',
    );
    return '$_temp0';
  }

  @override
  String get notificationsNote =>
      'Tjugo i taget, äldre hämtas när du rullar. Långtryck för att välja flera.';

  @override
  String notificationsDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notiser togs bort',
      one: 'Notisen togs bort',
    );
    return '$_temp0';
  }

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
  String get cookSnapEmptySubtitle => 'Var först.';

  @override
  String get cookSnapMe => 'Mig';

  @override
  String get cookSnapVisibilityTitle => 'Vem ser fotot?';

  @override
  String get cookSnapVisibilityPublic =>
      'Receptet är offentligt – fotot blir synligt för alla.';

  @override
  String cookSnapVisibleTo(String audience) {
    return 'Synligt för: $audience';
  }

  @override
  String get cookSnapVisibilityConfirm => 'Dela foto';

  @override
  String get cookSnapVisibilityChoiceSame => 'Samma som receptet';

  @override
  String get cookSnapVisibilityChoiceOnlyMe => 'Bara jag';

  @override
  String get cookSnapVisibilityChoiceOnlyMeHint =>
      'Fotot syns inte för andra som ser receptet';

  @override
  String get cookSnapErrorLoad => 'Kunde inte ladda foton';

  @override
  String get cookSnapErrorUpload => 'Kunde inte ladda upp foto';

  @override
  String get cookSnapQueuedOffline =>
      'Dina bilder skickas när du är online igen';

  @override
  String get cookSnapErrorDelete => 'Kunde inte radera bilden';

  @override
  String get cookSnapDelete => 'Radera bilden';

  @override
  String get cookSnapDeletedUndoMessage => 'Bilden raderas – ångra?';

  @override
  String get cookSnapReport => 'Rapportera foto';

  @override
  String cookSnapPhotoCounter(int current, int total) {
    return '$current/$total';
  }

  @override
  String a11yCookSnapPhotoCarousel(int current, int total) {
    return 'Matbild $current av $total';
  }

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
  String get weeklyMenuTodayBadge => 'I dag';

  @override
  String get weeklyMenuNewMark => 'ny';

  @override
  String get weeklyMenuLegendNew => 'ny';

  @override
  String get weeklyMenuLegendAllergen => 'tål inte';

  @override
  String get weeklyMenuLegendPresence => 'hemma, om inte alla';

  @override
  String a11yWeeklyMenuAddDish(String slot, String day) {
    return 'Lägg till rätt på $slot $day';
  }

  @override
  String a11yWeeklyMenuOpenOvrigt(String day) {
    return 'Visa övrigt på $day';
  }

  @override
  String get weeklyMenuEmptyTitle => 'Ingen planering än';

  @override
  String get weeklyMenuEmptyHint =>
      'Skapa en veckomeny från prompten ovan så fyller vi i dagarna åt dig.';

  @override
  String weeklyMenuOvrigtSheetTitle(String day) {
    return 'Övrigt på $day';
  }

  @override
  String get weeklyMenuOvrigtSheetAdd => 'Lägg till rätt';

  @override
  String get weeklyMenuOverwriteConfirm =>
      'Detta ersätter din nuvarande planering. Fortsätt?';

  @override
  String get weeklyMenuLoadError => 'Kunde inte ladda veckomenyn';

  @override
  String weeklyMenuWeekTitle(int weekNum) {
    return 'Vecka $weekNum';
  }

  @override
  String weeklyMenuWeekRange(String start, String end) {
    return '$start–$end';
  }

  @override
  String get weeklyMenuChipsHeading => 'Vi förstod:';

  @override
  String get weeklyMenuChipsNotUnderstood => 'Vi förstod inte:';

  @override
  String get weeklyMenuChipsRefinePrompt => 'Förfina prompten';

  @override
  String get weeklyMenuClearWeekAction => 'Rensa veckan';

  @override
  String get weeklyMenuClearedUndo => 'Veckan rensad';

  @override
  String get weeklyMenuCopyToNextAction => 'Kopiera denna vecka → nästa vecka';

  @override
  String get weeklyMenuCopyToNextConfirmTitle => 'Kopiera veckan?';

  @override
  String get weeklyMenuCopyToNextConfirmBody =>
      'Recepten i den här veckan kopieras till nästa vecka. Din nuvarande planering för nästa vecka behålls.';

  @override
  String weeklyMenuCopyToNextResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept kopierade till nästa vecka',
      one: '1 recept kopierat till nästa vecka',
      zero: 'Inget kopierades – allt finns redan nästa vecka',
    );
    return '$_temp0';
  }

  @override
  String get weeklyMenuCopyToNextFailed => 'Kunde inte kopiera veckan';

  @override
  String get weeklyPlanReadFailed => 'Kunde inte läsa in veckan – försök igen';

  @override
  String get weeklyMenuSelectAction => 'Välj flera att flytta';

  @override
  String weeklyMenuSelectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count valda',
      one: '1 vald',
    );
    return '$_temp0';
  }

  @override
  String get weeklyMenuMoveSelectionAction => 'Flytta';

  @override
  String get weeklyMenuMoveSheetTitle => 'Flytta till';

  @override
  String weeklyMenuMovedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept flyttade',
      one: '1 recept flyttat',
      zero: 'Inget flyttades',
    );
    return '$_temp0';
  }

  @override
  String get weeklyMenuMoveFailed => 'Kunde inte flytta recepten';

  @override
  String get a11yWeeklyMenuSelectEntry => 'Välj för att flytta';

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
  String get pantryItemChangedNow => 'ändrad nu';

  @override
  String pantryItemChangedMinutesAgo(int count) {
    return 'ändrad $count min sedan';
  }

  @override
  String pantryItemChangedToday(String time) {
    return 'ändrad i dag $time';
  }

  @override
  String get pantryItemChangedYesterday => 'ändrad i går';

  @override
  String pantryItemChangedOn(String date) {
    return 'ändrad $date';
  }

  @override
  String get pantryExpiryExpired => 'Utgånget';

  @override
  String get pantryExpiryToday => 'Utgår i dag';

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
  String get pantryCouldNotSaveItem => 'Varan kunde inte sparas i skafferiet.';

  @override
  String get pantryIngredientLabel => 'Ingrediens';

  @override
  String get pantryIngredientHint => 'Sök ingrediens …';

  @override
  String get pantryQuantityLabel => 'Mängd';

  @override
  String get pantryUnitLabel => 'Enhet';

  @override
  String get pantryNoteLabel => 'Anteckning (valfritt)';

  @override
  String get pantryAddAction => 'Lägg till';

  @override
  String get filterWithMyIngredients => 'Med mina ingredienser';

  @override
  String get shoppingTabLists => 'Inköpslistor';

  @override
  String get shoppingTabPantry => 'Skafferiet';

  @override
  String recipeCardPantryMatchA11y(int percent) {
    return 'Du har $percent % av receptets ingredienser';
  }

  @override
  String get ingredientSearchTitle => 'Sök med ingredienser';

  @override
  String get ingredientSearchHint => 'lägg till …';

  @override
  String get ingredientSearchButton => 'Sök recept';

  @override
  String get ingredientSearchChip => 'Med ingredienser';

  @override
  String get ingredientSearchEmpty =>
      'Lägg till ingredienser för att hitta recept';

  @override
  String get ingredientSearchNoResults =>
      'Inga recept matchar dina ingredienser';

  @override
  String get ingredientSearchNoResultsHint =>
      'Ta bort en ingrediens eller prova färre.';

  @override
  String get ingredientSearchError => 'Kunde inte söka recept';

  @override
  String ingredientSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept matchar',
      one: '1 recept matchar',
    );
    return '$_temp0';
  }

  @override
  String ingredientMatchCount(int matched, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total ingredienser',
      one: '1 ingrediens',
    );
    return '$matched av $_temp0';
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
    return '$name tog den – välj en annan';
  }

  @override
  String shoppingItemClaimed(String itemName) {
    return 'Tar hand om ”$itemName”';
  }

  @override
  String shoppingItemUnclaimed(String itemName) {
    return 'Släppte ”$itemName”';
  }

  @override
  String outOfIngredientTitle(String ingredient) {
    return 'Slut på $ingredient? Prova …';
  }

  @override
  String get replaceInRecipe => 'Byt i receptet';

  @override
  String get noSubstitutionSuggestions => 'Inga förslag just nu';

  @override
  String get substitutionsOfflineMessage =>
      'Förslag på alternativ är inte tillgängliga offline.';

  @override
  String get suggestAlternative => 'Föreslå ett alternativ';

  @override
  String get startTimer => 'Starta timer';

  @override
  String get timerExpired => 'Timern är klar.';

  @override
  String get timerNotificationTitle => 'Timern är klar.';

  @override
  String get timerNotificationBody => 'Din timer har gått ut.';

  @override
  String timerNotificationBodyLabeled(String label) {
    return 'Klart: $label';
  }

  @override
  String get timerNotificationChannelTitle => 'Mat-timers';

  @override
  String get timerNotificationChannelDescription =>
      'Notiser när dina mat-timers går ut';

  @override
  String get cookingActiveTimersTitle => 'Aktiva timers';

  @override
  String a11yActiveTimer(String label) {
    return 'Timer $label: tid kvar';
  }

  @override
  String get a11yActiveTimerUnnamed => 'Timer: tid kvar';

  @override
  String get pauseTimer => 'Pausa';

  @override
  String get resumeTimer => 'Återuppta';

  @override
  String get resetTimer => 'Återställ';

  @override
  String timerDurationHint(String source) {
    return 'Från ”$source”';
  }

  @override
  String get heirloomToggle => 'Det här är ett arvegods';

  @override
  String get heirloomWriterLabel => 'Vems handskrift?';

  @override
  String get heirloomYearLabel => 'År';

  @override
  String get heirloomNoteLabel => 'Notis';

  @override
  String heirloomFrom(String name, int year) {
    return 'Från $name, $year';
  }

  @override
  String get heirloomUploadOffline => 'Sparas när du är online igen';

  @override
  String get pendingSyncOffline => 'Sparat. Synkas när du är online igen.';

  @override
  String get commentWaitingForNetwork =>
      'Din förra kommentar väntar på nät. Skicka den här när den har gått iväg.';

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
  String get notificationPermissionTitle => 'Aktivera notiser?';

  @override
  String get notificationPermissionBody =>
      'Butlery använder aviseringar för att påminna om timers, meddelanden från vänner och aktivitet i dina delade recept. Du kan ändra detta när som helst i inställningarna.';

  @override
  String get notificationPermissionGrant => 'Tillåt';

  @override
  String get notificationPermissionOpenSettings => 'Öppna inställningar';

  @override
  String get notificationPermissionPermanentlyDeniedMessage =>
      'Notiser är avstängda. Öppna inställningarna för att aktivera dem.';

  @override
  String get familyPresenceTitle => 'Online just nu';

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
  String get pingComposeTitle => 'Skicka en knuff';

  @override
  String get pingComposeMessageHint => 'Meddelande (frivilligt)';

  @override
  String get pingComposeSend => 'Skicka';

  @override
  String get pingComposeSent => 'Skickat';

  @override
  String get pingRateLimited =>
      'Du har skickat för många knuffar den senaste timmen';

  @override
  String pingNudgeFrom(String name) {
    return '$name knuffar till dig';
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
  String get moderatorReporterLabel => 'Anmäld av';

  @override
  String get moderatorReporterErased => 'Anmälarens konto är raderat';

  @override
  String get moderatorEvidenceHeading => 'Sparad kopia';

  @override
  String moderatorEvidenceHeadingAt(String time) {
    return 'Sparad kopia · $time';
  }

  @override
  String get moderatorEvidenceTruncated => 'Texten är förkortad';

  @override
  String get moderatorEvidenceTextOnly => 'Bara text sparas, inte bilder';

  @override
  String get moderatorEvidenceMissing =>
      'Innehållet fanns inte kvar när anmälan kom in';

  @override
  String get moderatorEvidenceNotVisible =>
      'Ingen kopia: anmälaren kunde inte se innehållet';

  @override
  String get moderatorEvidenceOwnerMismatch =>
      'Ingen kopia: innehållet tillhör inte den anmälda';

  @override
  String get moderatorEvidenceUnsupported =>
      'Ingen kopia för den här typen av anmälan';

  @override
  String get moderatorEvidenceFailed => 'Kopian kunde inte sparas';

  @override
  String get moderatorEvidenceNone => 'Ingen kopia sparad';

  @override
  String get moderatorMinorAccountBadge => 'Minderårigt konto';

  @override
  String get moderatorActionAdvance => 'Nästa steg';

  @override
  String get moderatorActionDelete => 'Radera innehåll';

  @override
  String get moderatorDeleteConfirmTitle => 'Radera innehållet?';

  @override
  String get moderatorDeleteConfirmBody =>
      'Det här raderar det rapporterade innehållet permanent. Åtgärden kan inte ångras från appen.';

  @override
  String get moderatorActionHide => 'Dölj profil';

  @override
  String get moderatorHideConfirmTitle => 'Dölj den här profilen?';

  @override
  String get moderatorHideConfirmBody =>
      'Profilen tas bort från sök och vänlistor. Användaren kan fortfarande logga in men visas som en platshållare för andra. Du kan ångra det senare.';

  @override
  String get appealEmailLinkLabel => 'Överklaga ett beslut';

  @override
  String get appealEmailSubject => 'Överklagan av ett beslut';

  @override
  String get appealEmailBodyTemplate =>
      'Hej Butlery,\n\nJag vill överklaga ett beslut om mitt innehåll eller min profil:\n- Vad beslutet gällde (till exempel recept, kommentar, bild eller profil):\n- Ungefärligt datum:\n- Mitt användarnamn:\n\nVarför jag tycker att beslutet är fel:\n\nTack.';

  @override
  String get appealEmailLaunchFailed =>
      'Kunde inte öppna e-postappen. Skicka manuellt till overklagande@butlery.se.';

  @override
  String get myReportsOutcomeReceived => 'Vi har tagit emot din anmälan.';

  @override
  String get myReportsOutcomeInReview => 'En moderator granskar anmälan.';

  @override
  String get myReportsOutcomeContentRemoved =>
      'Innehållet har tagits bort eftersom det bröt mot gemenskapsreglerna.';

  @override
  String get myReportsOutcomeProfileHidden =>
      'Profilen har dolts för andra eftersom den bröt mot gemenskapsreglerna.';

  @override
  String get myReportsOutcomeNoAction =>
      'Vi bedömde att innehållet inte bryter mot gemenskapsreglerna. Det ligger kvar.';

  @override
  String get myReportsOutcomeClosed => 'Ärendet är avslutat.';

  @override
  String get myReportsAppealButton => 'Överklaga beslutet';

  @override
  String myReportsAppealBody(
    String reportId,
    String date,
    String reason,
    String outcome,
  ) {
    return 'Hej Butlery,\n\nJag vill överklaga beslutet om min anmälan.\n- Ärende: $reportId\n- Anmäld: $date\n- Anledning: $reason\n- Beslut: $outcome\n\nVarför jag tycker att beslutet är fel:\n\nTack.';
  }

  @override
  String get a11yProfileImageEdit => 'Profilbild, tryck för att ändra';

  @override
  String get a11yProfileImageReadonly => 'Profilbild';

  @override
  String get a11yReactToComment => 'Reagera på kommentar';

  @override
  String get a11yShowCommentLikes => 'Visa vem som gillat';

  @override
  String get a11yLongPressCommentForReactions =>
      'Kommentar, långtryck för att reagera';

  @override
  String a11yImagePickerRemove(int index) {
    return 'Ta bort vald bild $index';
  }

  @override
  String get a11yGalleryAddImage => 'Lägg till bild i galleriet';

  @override
  String recipeRatingSemantics(String rating) {
    return 'Betyg: $rating';
  }

  @override
  String get a11yMenuRecipeOpen => 'Öppna receptet';

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
  String get a11yShelfRecipeOpen => 'Öppna recept';

  @override
  String get a11yCookSnapOptions => 'Matlagningsbild, långtryck för alternativ';

  @override
  String get a11yConversationOpen => 'Öppna konversationen';

  @override
  String get a11yMenuVoteOption => 'Rösta';

  @override
  String get a11yMenuVoteOptionSelected => 'Din röst';

  @override
  String get a11yPingAcknowledge => 'Bekräfta notis';

  @override
  String get a11yMenuPlanRecipeOpen => 'Öppna receptet';

  @override
  String get a11yRefineMenuPrompt => 'Förbättra menyprompten';

  @override
  String get a11yAddIngredient => 'Lägg till';

  @override
  String get a11yQuickFilter => 'Filtrera';

  @override
  String get a11yHeirloomScanOpenFullscreen =>
      'Öppna originalskanning i fullskärm';

  @override
  String a11yReplaceWithSubstitute(String name) {
    return 'Ersättare: $name';
  }

  @override
  String get a11yShareTabSwitch => 'Visa';

  @override
  String get a11yPantryAddItem => 'Lägg till ny vara';

  @override
  String get a11yPantryEditItem => 'Redigera';

  @override
  String get a11yPantryPickExpiry => 'Öppna kalendern';

  @override
  String get a11yDraftRecoverTile => 'Återställ';

  @override
  String get a11yShareModeOption => 'Tryck för att välja';

  @override
  String get a11yFriendRequestIncoming => 'Vänförfrågan, tryck för att markera';

  @override
  String a11yAcceptFriendRequestFrom(String name) {
    return 'Acceptera $name';
  }

  @override
  String a11yDeclineFriendRequestFrom(String name) {
    return 'Avböj $name';
  }

  @override
  String get a11yFriendRequestSent =>
      'Skickad förfrågan, tryck för att markera';

  @override
  String get a11yFeedFilter => 'Filtrera flödet';

  @override
  String get a11yFeedRecipePreview => 'Visa receptet';

  @override
  String get a11yPublicProfileRecipeCard => 'Öppna receptet';

  @override
  String get a11yInvitationTargetCard => 'Bjud in';

  @override
  String get a11yPermissionsBanner => 'Behörighet';

  @override
  String get a11yEmojiPicker => 'Välj som ikon';

  @override
  String a11yRemoveIngredientChip(String label) {
    return 'Ta bort $label';
  }

  @override
  String a11yRemoveMember(String name) {
    return 'Ta bort $name';
  }

  @override
  String get a11yToggleFullscreenChrome => 'Visa eller dölj kontroller';

  @override
  String get a11yCommentsToggle => 'Visa eller dölj';

  @override
  String get a11yShowSubstitutionsFor => 'Visa substitut';

  @override
  String get a11yToggleStepDone => 'Markera som klart eller oavslutat';

  @override
  String get a11yRemoveOwnRating => 'Ta bort mitt betyg';

  @override
  String get a11yCookingStepLongPressTimer => 'Långtryck för att starta timer';

  @override
  String get a11yStartTimerForPhrase => 'Starta timer';

  @override
  String get a11yRecipeImageFullscreen => 'Visa receptbild i fullskärm';

  @override
  String a11yHeroButton(String tooltip) {
    return '$tooltip';
  }

  @override
  String get a11yDismissParseQualityWarning =>
      'Stäng varning om importkvalitet';

  @override
  String get a11yFiltersActive => 'Filter aktiva';

  @override
  String shoppingCategoryProgress(int completed, int total) {
    return '$completed av $total';
  }

  @override
  String get a11yPollVoteOption => 'Rösta';

  @override
  String a11yPollRecipeThumbnail(String title) {
    return 'Visa receptet $title';
  }

  @override
  String get cookingModeSubstitutionApplied => 'Ingrediens utbytt';

  @override
  String get cookingModeSubstitutionFailed => 'Ingrediensen kunde inte bytas.';

  @override
  String get cookingModeOpenEditToSwap => 'Öppna redigering för att byta';

  @override
  String get feedbackEmailHint => 'namn@exempel.se';

  @override
  String get dialogEmailLabel => 'E-post';

  @override
  String get dialogEmailHint => 'namn@exempel.se';

  @override
  String get dialogUrlLabel => 'URL';

  @override
  String get dialogUrlHint => 'https://exempel.se';

  @override
  String get unnamedSharedList => '(Namnlös lista)';

  @override
  String get parseConfidenceTitle => 'Tolkningskvalitet per ingrediens';

  @override
  String parseConfidenceReviewCountSubtitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString kan behöva en koll',
      one: '1 kan behöva en koll',
    );
    return '$_temp0';
  }

  @override
  String parseConfidenceOriginalPrefix(String line) {
    return 'Original: $line';
  }

  @override
  String get a11yToggleConfidenceSection => 'Visa eller dölj';

  @override
  String get a11yConfidenceHigh => 'hög tolkningskvalitet';

  @override
  String get a11yConfidenceMedium => 'medel tolkningskvalitet';

  @override
  String get a11yConfidenceLow => 'låg tolkningskvalitet';

  @override
  String get a11yConfidenceFailed => 'okänd tolkningskvalitet';

  @override
  String get recipeRelatedSectionTitle => 'Relaterade recept';

  @override
  String get recipeUsedInSectionTitle => 'Används i';

  @override
  String get recipeRelatedLinkButton => '+ Länka relaterat recept';

  @override
  String get recipeRelatedPickerTitle => 'Välj relaterade recept';

  @override
  String get recipeRelatedLinkSuccess => 'Recept länkat';

  @override
  String get recipeRelatedUnlinkSuccess => 'Länk borttagen';

  @override
  String get recipeRelatedLinkError => 'Kunde inte länka receptet';

  @override
  String get recipeRelatedUnlinkError => 'Kunde inte ta bort länken';

  @override
  String get a11yRemoveRelatedRecipe => 'Ta bort länk';

  @override
  String get a11yRelatedRecipeThumbnail => 'Öppna relaterat recept';

  @override
  String get familyTitle => 'Mitt hushåll';

  @override
  String get familyIntro =>
      'Hushållet delar recept, meny och inköpslistor. Matgäster utan konto kan ändå betygsätta maten.';

  @override
  String get familyRoleAdmin => 'admin';

  @override
  String get ageBandToddler => 'bebis';

  @override
  String get ageBandChild => 'barn';

  @override
  String get ageBandTeen => 'tonåring';

  @override
  String get ageBandAdult => 'vuxen';

  @override
  String get familyAddTitle => 'Lägg till matgäst';

  @override
  String get familyEditTitle => 'Redigera matgäst';

  @override
  String get familyNameLabel => 'Namn';

  @override
  String get familyNameHint =>
      'Smeknamn eller initial räcker – vi behöver inte fullständigt namn.';

  @override
  String get familyColorLabel => 'Färg';

  @override
  String get familyAgeBandLabel => 'Åldersband';

  @override
  String get familyAgeBandHint =>
      'Vi lagrar aldrig födelsedatum – bara ett ungefärligt band.';

  @override
  String get familyConsentSectionTitle => 'Vårdnadshavarsamtycke';

  @override
  String get familyConsentRequiredBadge => 'Krävs';

  @override
  String familyGuardianConsentText(String name) {
    return 'Jag är vårdnadshavare och samtycker till att ${name}s namn och åldersgrupp sparas för att planera måltider åt hushållet. Betyg som sätts på måltider bidrar anonymt till receptens allmänna snittbetyg.';
  }

  @override
  String get familyAllergenSectionTitle => 'Allergener';

  @override
  String get familyOptionalBadge => 'Valfritt';

  @override
  String get familyAllergenHealthNote =>
      'Allergiuppgifter räknas som känsliga hälsouppgifter. Du kan spara profilen utan dem och lägga till senare.';

  @override
  String familyAllergenConsentText(String name) {
    return 'Jag samtycker uttryckligen till att ${name}s allergi- och kostuppgifter (hälsouppgifter) sparas.';
  }

  @override
  String get familyConsentGivenPrefix => 'Samtycke givet';

  @override
  String get familyWithdrawAllergenConsent =>
      'Ta tillbaka samtycke och radera allergener';

  @override
  String get familyDeleteMember => 'Radera matgäst';

  @override
  String get familyDeleteConfirmTitle => 'Radera matgästen?';

  @override
  String get familyDeleteConfirmBody =>
      'Matgästen och alla betyg för matgästen raderas. Det går inte att ångra.';

  @override
  String get a11yEditFamilyMember => 'Redigera matgäst';

  @override
  String get familyConsentChildWord => 'barnet';

  @override
  String get familyConsentPersonWord => 'personen';

  @override
  String a11yColorSwatch(int index) {
    return 'Avatarfärg $index';
  }

  @override
  String get whoAteTitle => 'Vem åt?';

  @override
  String whoAteConfirm(int count) {
    return 'klar – $count åt';
  }

  @override
  String get whoAteSkip => 'Hoppa över';

  @override
  String get a11yToggleDiner => 'Markera som äter';

  @override
  String get menuPresenceSheetTitle => 'Vem är hemma?';

  @override
  String get menuPresenceThisMeal => 'Den här måltiden';

  @override
  String get menuPresenceWholeDay => 'Hela dagen';

  @override
  String get menuPresenceHome => 'hemma';

  @override
  String get menuPresenceAway => 'borta';

  @override
  String menuPresenceHomeSummary(int home, int portions) {
    return '$home hemma · $portions port.';
  }

  @override
  String get menuPresenceOpenRecipe => 'Öppna receptet';

  @override
  String menuPresencePortions(int count) {
    return '$count port';
  }

  @override
  String menuPresenceSlotSubtitle(String slot, String day) {
    return '$slot på $day';
  }

  @override
  String get menuPresenceAfterGenerateNotice =>
      'närvaron uppdaterad – planerade rätter ligger kvar';

  @override
  String get menuPresenceSummaryTitle => 'Vem är hemma?';

  @override
  String get menuPresenceSummaryAllHome => 'Alla hemma hela veckan';

  @override
  String commonListJoinAnd(String head, String last) {
    return '$head och $last';
  }

  @override
  String menuPresenceSummaryAway(String names) {
    return '$names borta delar av veckan';
  }

  @override
  String a11yMenuSlotPresence(String slot, String day) {
    return 'Välj vilka som är hemma på $slot $day';
  }

  @override
  String get familyRatingTitle => 'Vad tyckte ni?';

  @override
  String get familyRatingYou => 'du';

  @override
  String get familyRatingSave => 'Spara';

  @override
  String get familyRatingManualButton => 'Betygsätt som hushåll';

  @override
  String familyRatingProxyNote(String name) {
    return 'inmatat av $name · ändrar inte personens eget betyg';
  }

  @override
  String a11yRateStarsForMember(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stjärnor',
      one: '1 stjärna',
    );
    return 'Ge $name $_temp0';
  }

  @override
  String get familyRatingSectionTitle => 'Hushållets betyg';

  @override
  String get familyRatingAverageLabel => 'Hushållets snitt';

  @override
  String familyRatingCount(int count) {
    return '$count betyg';
  }

  @override
  String familyRatingUpdated(String date) {
    return 'Uppdaterad $date';
  }

  @override
  String get familyRatingCommunityLabel => 'Alla som lagat';

  @override
  String get familyRatingYourOwnLabel => 'Ditt eget betyg';

  @override
  String get familyRatingLegend =>
      'Hushållets betyg är privata. Bläck = hushållet, grått = alla, saffran = ditt.';

  @override
  String a11yFamilyRatingPill(String rating) {
    return 'Hushållsbetyg $rating';
  }

  @override
  String a11yAllaRatingPill(String rating) {
    return 'Allas betyg $rating';
  }

  @override
  String butleryBetygCount(int count) {
    return '$count betyg';
  }

  @override
  String a11yButleryBetygPill(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count röster',
      one: '1 röst',
    );
    return 'Butlery-betyget $rating, $_temp0';
  }

  @override
  String get pooledCommunityLabel => 'butlery-betyget';

  @override
  String get pooledHouseholdLabel => 'alla i ditt kök';

  @override
  String get a11yPooledHouseholdPill => 'Ditt köks betyg';

  @override
  String familyRatingProxyEntered(String name) {
    return 'Ifylld av $name';
  }

  @override
  String get a11yToggleRatingBreakdown => 'Visa eller dölj översikten';

  @override
  String get a11yEditMemberRating => 'Ändra betyg';

  @override
  String get deepLinkExpired =>
      'Länken gäller inte längre. Be den som delade om en ny.';

  @override
  String get deepLinkUnavailable => 'Innehållet är inte längre tillgängligt.';

  @override
  String get familyDislikesSectionTitle => 'Ogillade ingredienser';

  @override
  String get familyDislikesNote =>
      'Rätter med dessa undviks när det går. En smakpreferens, inte en säkerhetsgräns som allergier.';

  @override
  String get chatJoinedHereDivider => 'Du gick med här';

  @override
  String chatGroupMembersAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count medlemmar tillagda',
      one: '1 medlem tillagd',
    );
    return '$_temp0';
  }

  @override
  String get chatGroupAddMembersBlocked =>
      'Några personer kunde inte läggas till i gruppen.';

  @override
  String get chatGroupAddMembersFailed =>
      'Det gick inte att lägga till medlemmar. Försök igen.';

  @override
  String get chatGroupNeedsAnotherMember =>
      'Gruppen behöver minst en medlem till innan ni kan rösta om mat.';

  @override
  String get mealVotePollFailed =>
      'Det gick inte att starta omröstningen. Försök igen.';

  @override
  String get chatGroupCreateFailed =>
      'Det gick inte att skapa gruppen. Försök igen.';

  @override
  String chatGroupTooManyMembers(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max medlemmar',
      one: '1 medlem',
    );
    return 'En grupp kan ha högst $_temp0.';
  }

  @override
  String get chatDuplicateBlocked => 'Du har redan skickat det här';

  @override
  String get messageTypeDuplicateBlocked => 'Stoppat';

  @override
  String get a11yDismissDuplicateNotice => 'Ta bort notisen';

  @override
  String get groupMenuEmptyTitle => 'Ingen rätt är framröstad än';

  @override
  String get groupMenuEmptyBody =>
      'Starta en omröstning i chatten, så hamnar vinnaren här.';

  @override
  String get groupMenuEmptyAction => 'Starta en omröstning';

  @override
  String get groupMenuNotAMember =>
      'Du har inte åtkomst till den här veckans meny.';

  @override
  String get groupMenuLoadFailed => 'Kunde inte läsa in veckan.';

  @override
  String get groupMenuViewerNotice =>
      'Du kan se gruppens meny men inte ändra i den.';

  @override
  String get groupMenuChatAction => 'Veckans meny';

  @override
  String get groupMenuPickGroupTitle => 'Välj grupp';

  @override
  String get groupMenuNoGroups => 'Du är inte med i någon grupp än.';

  @override
  String get groupMenuDishRemoved => 'Rätten togs bort';

  @override
  String get groupMenuSaveFailed => 'Kunde inte spara ändringen. Försök igen.';

  @override
  String get groupMenuUndoUnavailable =>
      'Det går inte att ångra det här längre.';

  @override
  String groupMenuProposedBy(String name) {
    return 'Föreslagen av $name';
  }

  @override
  String get groupMenuVotersTitle => 'Röstade på den här rätten';

  @override
  String get a11yGroupMenuDishDetails => 'Visa förslag och röster';

  @override
  String get groupMenuUnknownVoter => 'Okänd medlem';

  @override
  String get groupMenuUndoFailed => 'Kunde inte ångra borttagningen.';

  @override
  String get groupMenuGroupsLoadFailed => 'Kunde inte hämta dina grupper.';

  @override
  String get groupMenuUntitledGroup => 'Namnlös grupp';

  @override
  String get pollVoteFailed => 'Din röst kunde inte registreras.';

  @override
  String socialRequestsAcceptedPartial(int succeeded, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total förfrågningar accepterade',
      one: '1 förfrågan accepterad',
    );
    return '$succeeded av $_temp0';
  }

  @override
  String socialRequestsRejectedPartial(int succeeded, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total förfrågningar avböjda',
      one: '1 förfrågan avböjd',
    );
    return '$succeeded av $_temp0';
  }

  @override
  String socialRequestsCancelledPartial(int succeeded, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total förfrågningar avbrutna',
      one: '1 förfrågan avbruten',
    );
    return '$succeeded av $_temp0';
  }

  @override
  String get profileDeletionNoticeTitle => 'Ditt konto är raderat';

  @override
  String get profileDeletionNoticeWhat =>
      'En sak har sparats: en pågående granskning av innehåll som anmälts.';

  @override
  String get profileDeletionNoticeWhy =>
      'Varför: vi måste kunna hantera anmälningen färdigt.';

  @override
  String profileDeletionNoticeHowLong(String date) {
    return 'Hur länge: tills granskningen är klar, senast $date.';
  }

  @override
  String get profileDeletionNoticeRights =>
      'Du kan klaga till IMY eller vända dig till domstol om du inte håller med.';

  @override
  String get profileDeletionNoticeHowLongUnknown =>
      'Hur länge: tills granskningen är klar.';

  @override
  String get profileDeletionNoticeWhatUnclear =>
      'En sak kan ha sparats: vi kunde inte slutföra kontrollen av om det finns en pågående granskning av innehåll som anmälts.';

  @override
  String get profileDeletionNoticeWhatOwnReport =>
      'En eller flera anmälningar du har gjort som ännu inte är färdigbehandlade har sparats. Ditt namn är borttaget från dem, men det du skrev finns kvar.';

  @override
  String get profileDeletionNoticeWhatBoth =>
      'Det här har sparats: en pågående granskning av innehåll som anmälts, och en eller flera anmälningar du har gjort som ännu inte är färdigbehandlade. Ditt namn är borttaget från anmälningarna, men det du skrev finns kvar.';

  @override
  String get profileDeletionNoticeWhatBothUnclear =>
      'En eller flera anmälningar du har gjort som ännu inte är färdigbehandlade har sparats utan ditt namn men med det du skrev. En sak till kan ha sparats: vi kunde inte slutföra kontrollen av om det finns en pågående granskning av innehåll som anmälts.';

  @override
  String get profileDeletionNoticeWhyHandling =>
      'Varför: vi måste kunna slutföra handläggningen.';

  @override
  String profileDeletionNoticeHowLongHandling(String date) {
    return 'Hur länge: tills handläggningen är klar, senast $date.';
  }

  @override
  String get profileDeletionNoticeHowLongHandlingUnknown =>
      'Hur länge: tills handläggningen är klar.';

  @override
  String get profileDeletionNoticeCollapsed =>
      'Ett meddelande om ett raderat konto på den här enheten.';

  @override
  String get profileDeleteAccountMayHaveReview =>
      'Om det finns en pågående granskning av innehåll du anmälts för kan vi behöva spara den granskningen även efter att kontot raderats. I så fall sparas den tills ärendet stängs, högst 180 dagar. Vill du få besked direkt när kontot raderas kan du logga in under de 7 dagarna och välja Radera nu.';

  @override
  String get shoppingLeaveList => 'Lämna listan';

  @override
  String shoppingLeaveListConfirm(String name) {
    return 'Vill du lämna ”$name”? Du förlorar åtkomst till listan. Detta går inte att ångra – ägaren måste bjuda in dig igen.';
  }

  @override
  String get shoppingLeave => 'Lämna';

  @override
  String shoppingLeftList(String name) {
    return 'Du har lämnat ”$name”';
  }

  @override
  String get shoppingCouldNotLeaveList => 'Kunde inte lämna listan';

  @override
  String get settingsAboutTitle => 'Om Butlery';

  @override
  String settingsAboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsLicensesTitle => 'Licenser';

  @override
  String get settingsLicensesSubtitle => 'Typsnitt och öppen källkod';

  @override
  String get licensesNoticesHeading => 'Butlery Sans – upphovsrätt och källor';

  @override
  String get licensesOflHeading => 'SIL Open Font License 1.1';

  @override
  String get licensesCouldNotLoad => 'Licenstexterna kunde inte läsas in.';

  @override
  String get loadingProfileBusy => 'Hämtar din profil …';

  @override
  String get loadingOnboardingResume => 'Hämtar var du slutade …';

  @override
  String get startSplashTagline => 'Din butler i köket';

  @override
  String get startSplashBusy => 'Dukar upp ditt kök …';

  @override
  String get loadingOpeningPage => 'Öppnar sidan …';

  @override
  String get loadingStartingApp => 'Startar Butlery …';

  @override
  String get recipeSaveToMyKitchen => 'Spara till mitt kök';

  @override
  String get recipeAddToShoppingList => 'Lägg i inköpslistan';

  @override
  String get loadingCookSnaps => 'Hämtar fotona …';

  @override
  String get loadingSubstitutions => 'Hämtar ersättningar …';

  @override
  String get uploadingCookSnap => 'Laddar upp fotot …';

  @override
  String get recipeEditorClose => 'Stäng editorn';

  @override
  String menuWeekBadgeEmpty(int week) {
    return 'Vecka $week · inget planerat';
  }

  @override
  String menuWeekBadgeOnly(int week) {
    return 'Vecka $week';
  }

  @override
  String get rootBarMoreActions => 'Fler åtgärder';

  @override
  String get weekMenuPlanningSlow => 'Det tar längre tid än vanligt';

  @override
  String get importBatchSaveFailed =>
      'Recepten kunde inte sparas. Försök igen.';

  @override
  String get weekMenuPlanningTitle => 'Planerar veckan …';

  @override
  String get menuLoadingSaved => 'Hämtar sparade menyer …';

  @override
  String get shoppingRootTitle => 'Inköp';

  @override
  String shoppingRootLine(String listName, int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total klara',
      one: '1 klar',
    );
    return '$listName · $done av $_temp0';
  }

  @override
  String shoppingRootLineEmpty(String listName) {
    return '$listName · inga varor';
  }

  @override
  String get shoppingEmptyTitle => 'Inget att handla';

  @override
  String get shoppingEmptyBody =>
      'Skicka veckans rätter hit så samlas ingredienserna per kategori. Det du redan har i skafferiet dras bort.';

  @override
  String get shoppingFromWeekMenu => 'Från veckomenyn';

  @override
  String get shoppingLoadingTemplates => 'Hämtar mallarna …';

  @override
  String get importFetchingRecipe => 'Hämtar receptet …';

  @override
  String get importReadingFile => 'Läser filen …';

  @override
  String get loadingLicenses => 'Hämtar licenserna …';

  @override
  String get consentSaveMyChoices => 'Spara mina val';

  @override
  String get loadingBlockedUsers => 'Hämtar blockerade användare …';

  @override
  String get accountDeletingProgress => 'Raderar kontot …';

  @override
  String get loadingParseEvents => 'Hämtar tolkningshändelserna …';

  @override
  String get loadingMoreActivity => 'Hämtar fler händelser …';

  @override
  String get menuPreviewTitle => 'Delad meny';

  @override
  String menuPreviewSharedLine(String name, String menu) {
    return '$name delade menyn $menu med dig · bara läsning';
  }

  @override
  String get menuPreviewDecline => 'Avböj';

  @override
  String get emailVerificationResendFailed =>
      'Verifieringsmailet kunde inte skickas.';

  @override
  String emailVerificationResendFailedBecause(String cause) {
    return 'Verifieringsmailet kunde inte skickas. $cause';
  }

  @override
  String get emailVerificationAddressUnchanged =>
      'Din e-postadress är oförändrad.';

  @override
  String get chatPollCouldNotBeCreated => 'Omröstningen kunde inte skapas.';

  @override
  String get chatEditCouldNotBeSaved => 'Ändringen kunde inte sparas.';

  @override
  String get chatEditOriginalKept => 'Meddelandet är oförändrat.';

  @override
  String get chatCouldNotSendReply => 'Svaret kunde inte skickas.';

  @override
  String get errorPreservedText => 'Texten ligger kvar i fältet.';

  @override
  String get errorPreservedForm => 'Det du fyllt i ligger kvar.';

  @override
  String get dialogActionFailed => 'Åtgärden kunde inte slutföras.';

  @override
  String get minaReceptRefreshFailed => 'Recepten kunde inte uppdateras.';

  @override
  String get minaReceptRefreshPreserved => 'Dina sparade recept visas nedan.';

  @override
  String get shoppingLeaveListStillMember => 'Du är fortfarande med i listan.';

  @override
  String get cookingModeRecipeUnchanged => 'Receptet är oförändrat.';

  @override
  String get accountSecurityPasswordChangeFailed =>
      'Lösenordet kunde inte ändras.';

  @override
  String accountSecurityPasswordChangeFailedBecause(String cause) {
    return 'Lösenordet kunde inte ändras. $cause';
  }

  @override
  String get accountSecurityEmailChangeFailed =>
      'E-postadressen kunde inte ändras.';

  @override
  String accountSecurityEmailChangeFailedBecause(String cause) {
    return 'E-postadressen kunde inte ändras. $cause';
  }

  @override
  String get recipeSaveFailed => 'Receptet kunde inte sparas.';

  @override
  String get recipeCopySaveFailed => 'Kopian kunde inte sparas.';

  @override
  String get recipeSaveIncomplete =>
      'Receptet kunde inte sparas. Det behöver en titel, minst en ingrediens och minst ett steg.';

  @override
  String get recipeSaveNoPermission =>
      'Receptet kunde inte sparas. Du har inte behörighet att ändra det.';

  @override
  String get errorPreservedRecipeEdits =>
      'Dina ändringar ligger kvar i formuläret.';

  @override
  String get groupAddMembersLoadFailed => 'Dina vänner kunde inte hämtas.';

  @override
  String get adminFeedbackLoadFailed => 'Återkopplingen kunde inte hämtas.';

  @override
  String get moderatorReportsLoadFailed => 'Anmälningarna kunde inte hämtas.';

  @override
  String get legalGuidelinesCouldNotLoad => 'Riktlinjerna kunde inte hämtas.';

  @override
  String get legalTermsCouldNotLoad => 'Användarvillkoren kunde inte hämtas.';

  @override
  String get legalLinksNeedConnection =>
      'Webblänkarna öppnas när du är ansluten igen.';

  @override
  String get imageCouldNotBeShown => 'Bilden kunde inte visas';

  @override
  String get errorPartNotShown => 'Den här delen kunde inte visas.';

  @override
  String get recipeAddPhoto => 'Lägg till foto';

  @override
  String get imageRetriesWhenOnline => 'Försöker igen när nätet är tillbaka';

  @override
  String get ingredientSearchAgain => 'Sök igen';

  @override
  String get ingredientSearchSelectionKept => 'Dina ingredienser ligger kvar.';

  @override
  String weeklyMenuOverflowPlacedCount(int placed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total rätter placerade',
      one: '1 rätt placerad',
    );
    return '$placed av $_temp0';
  }

  @override
  String weeklyMenuOverflowReason(int week) {
    return 'Vecka $week hade inga fler lediga platser för de här.';
  }

  @override
  String get weeklyMenuOverflowPastDays =>
      'Dagar som redan har passerat fylls aldrig.';

  @override
  String weeklyMenuOverflowKeepOrNextWeek(int week) {
    return 'De ligger kvar här tills du placerar dem eller lägger dem i vecka $week.';
  }

  @override
  String get weeklyMenuOverflowKeep =>
      'De ligger kvar här tills du placerar dem.';

  @override
  String weeklyMenuOverflowNextWeekAction(int week) {
    return 'Lägg i vecka $week';
  }

  @override
  String weeklyMenuOverflowNextWeekA11y(int count, int week) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lägg de $count i vecka $week',
      one: 'Lägg den i vecka $week',
    );
    return '$_temp0';
  }

  @override
  String weeklyMenuOverflowMovedToNextWeek(int count, int week) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rätter lades i vecka $week',
      one: '1 rätt lades i vecka $week',
    );
    return '$_temp0';
  }

  @override
  String a11yWeeklyMenuPlacementOrder(int order) {
    return 'Placerad som nummer $order';
  }

  @override
  String menuPartialTitle(int found, int requested) {
    String _temp0 = intl.Intl.pluralLogic(
      requested,
      locale: localeName,
      other: '$requested rätter',
      one: '1 rätt',
    );
    return 'Vi hittade $found av $_temp0';
  }

  @override
  String get menuPartialBody => 'Det fanns inte fler recept som passar.';

  @override
  String menuPartialMissing(int found, int requested, int missing) {
    return '$found av $requested, $missing saknas';
  }

  @override
  String get weeklyMenuSaveFailed => 'Veckan kunde inte sparas.';

  @override
  String get pantryItemUpdateFailed => 'Varan kunde inte uppdateras.';

  @override
  String get moderatorAdvanceFailed =>
      'Anmälan kunde inte flyttas till nästa steg.';

  @override
  String get moderatorCloseFailed => 'Anmälan kunde inte stängas.';

  @override
  String get moderatorReportUnchanged => 'Anmälan är oförändrad.';

  @override
  String get moderatorHideFailed => 'Profilen kunde inte döljas.';

  @override
  String get moderatorHidePreserved => 'Profilen syns som förut.';

  @override
  String get moderatorDeleteFailed => 'Innehållet kunde inte tas bort.';

  @override
  String get moderatorDeletePreserved => 'Innehållet ligger kvar.';

  @override
  String get adminFeedbackStatusFailed => 'Statusen kunde inte ändras.';

  @override
  String get adminFeedbackStatusPreserved =>
      'Återkopplingen har kvar sin tidigare status.';

  @override
  String get weekPlacementFailedWeekUnchanged =>
      'Veckan är oförändrad och den skapade menyn ligger kvar.';

  @override
  String get weekPlacementFailedMenuKept => 'Den skapade menyn ligger kvar.';

  @override
  String get menuShoppingListGenerationPreserved => 'Veckan är oförändrad.';

  @override
  String get importErrorNotImported => 'Receptet kunde inte importeras.';

  @override
  String get importFailurePreservedLink => 'Länken står kvar i fältet.';

  @override
  String get importFailurePreservedText => 'Texten står kvar i fältet.';

  @override
  String get importFailureOtherRoutes => 'Andra vägar till samma recept';

  @override
  String get importRoutePhoto => 'Fotografera skärmen';

  @override
  String get importRoutePasteText => 'Klistra in texten själv';

  @override
  String get duplicateMergeFailedPreserved =>
      'Det befintliga receptet är oförändrat.';

  @override
  String get conflictDiffUseTheirs => 'Använd deras version';

  @override
  String get conflictDiffCloseWithoutOverwrite => 'Stäng utan att skriva över';

  @override
  String get conflictDiffUsedTheirs => 'Deras version gäller nu';

  @override
  String get conflictDiffUseTheirsFailed => 'Deras version kunde inte sparas.';

  @override
  String get conflictDiffUseTheirsKept => 'Din version gäller fortfarande.';

  @override
  String get conflictWeekKeepMine => 'Behåll min';

  @override
  String get partialOutcomeDone => 'Klart';

  @override
  String groupMembersPartialTitle(int removed, int total) {
    return '$removed av $total togs bort';
  }

  @override
  String get groupMembersPartialMessage =>
      'De som inte kunde tas bort ligger kvar valda ovan.';

  @override
  String groupMembersPartialRemoved(String names, String group) {
    return '$names är inte längre med i $group.';
  }

  @override
  String get partialOutcomeListAnd => ' och ';

  @override
  String get groupMemberRemoveNotSaved =>
      'Kunde inte tas bort – ändringen sparades inte';

  @override
  String get groupMemberRemoveFailedNoPermission =>
      'Du får inte längre ändra gruppen';

  @override
  String get groupMemberRemoveFailedNotSaved => 'Ändringen sparades inte';

  @override
  String get groupMemberRemoveFailedGroupMissing => 'Gruppen finns inte längre';

  @override
  String a11yMemberRemoveFailed(String name) {
    return '$name, vald, kunde inte tas bort';
  }

  @override
  String get groupMembersRemoveNone => 'Ingen av de valda kunde tas bort.';

  @override
  String get selectionFailedKept => 'De ligger kvar valda.';

  @override
  String personalTagBulkDeletePartialTitle(int deleted, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total taggar',
      one: '1 tagg',
    );
    return '$deleted av $_temp0 togs bort';
  }

  @override
  String get personalTagBulkDeletePartialMessage =>
      'De som inte kunde tas bort ligger kvar valda.';

  @override
  String personalTagBulkDeletePartialDeleted(String names) {
    return '$names togs bort.';
  }

  @override
  String get personalTagBulkDeleteNotSaved =>
      'Kunde inte tas bort – borttagningen sparades inte';

  @override
  String get personalTagBulkDeleteNone => 'Taggarna kunde inte tas bort.';

  @override
  String get overwrittenRestoreAction => 'Återställ min version';

  @override
  String get overwrittenPickTitle => 'Vilken version vill du återställa?';

  @override
  String overwrittenVersionFrom(String when) {
    return 'Din version från $when';
  }

  @override
  String overwrittenVersionBy(String name, String until) {
    return '$name sparade över den · kvar till $until';
  }

  @override
  String overwrittenVersionByUnnamed(String until) {
    return 'Någon annan sparade över den · kvar till $until';
  }

  @override
  String overwrittenWhenToday(String time) {
    return 'i dag $time';
  }

  @override
  String get overwrittenWhenYesterday => 'i går';

  @override
  String get overwrittenConfirmTitleWeek => 'Återställa din vecka?';

  @override
  String get overwrittenConfirmTitleRecipe => 'Återställa ditt recept?';

  @override
  String overwrittenConfirmBodyWeek(String when) {
    return 'Din version från $when ersätter veckan som gäller nu. Du kan ångra direkt efteråt.';
  }

  @override
  String overwrittenConfirmBodyRecipe(String when) {
    return 'Din version från $when ersätter receptet som det ser ut nu. Du kan ångra direkt efteråt.';
  }

  @override
  String get overwrittenRestored => 'Din version är återställd';

  @override
  String get overwrittenRestoreFailed => 'Din version kunde inte återställas';

  @override
  String get overwrittenRestoreGoneWeek =>
      'Veckan finns inte längre, så din version kunde inte återställas';

  @override
  String get overwrittenRestoreGoneRecipe =>
      'Receptet finns inte längre, så din version kunde inte återställas';

  @override
  String overwrittenKeptUntil(String until) {
    return 'Den finns kvar till $until.';
  }

  @override
  String get overwrittenUndoFailed => 'Kunde inte ångra';

  @override
  String get overwrittenUndoFailedKept =>
      'Din återställda version gäller fortfarande.';

  @override
  String get messagingCreateConversation => 'Skapa konversation';

  @override
  String get reportDialogTitleRecipe => 'Anmäl det här receptet';

  @override
  String get reportDialogGuidelinesNoteSuffix =>
      '– den version du ser nu är den vi dömer efter.';

  @override
  String get reportDialogIntro =>
      'Berätta vad som är fel. En människa i teamet läser din anmälan.';

  @override
  String get reportDescriptionRequiredHelper => 'Krävs när du väljer Annat.';

  @override
  String get menuNoMatchTitle => 'Inga recept matchar';

  @override
  String menuNoMatchBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Beskrivningen ger noll träffar bland dina $count recept.',
      one: 'Beskrivningen ger ingen träff på ditt enda recept.',
    );
    return '$_temp0 Ändra eller släpp ett krav så hittar vi förslag.';
  }

  @override
  String menuNoMatchConstraints(String constraints) {
    return 'Kraven: $constraints';
  }

  @override
  String get menuNoMatchEditPrompt => 'Ändra beskrivningen';

  @override
  String get menuNoMatchPlanYourself => 'Lägg dagarna själv';

  @override
  String get menuGenerateOfflineReason =>
      'Ingen anslutning, så veckan kan inte planeras nu. Kalendern går att ändra som vanligt.';

  @override
  String get menuGenerateOfflineStopped =>
      'Anslutningen bröts, så förslaget placerades inte. Veckan är oförändrad.';

  @override
  String get shoppingMergeTitle => 'Till inköpslistan';

  @override
  String shoppingMergeItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count varor',
      one: '1 vara',
    );
    return '$_temp0';
  }

  @override
  String shoppingMergeSummary(int recipes, int rows, String items) {
    String _temp0 = intl.Intl.pluralLogic(
      recipes,
      locale: localeName,
      other: '$recipes rätter ger',
      one: '1 rätt ger',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rows,
      locale: localeName,
      other: '$rows rader',
      one: '1 rad',
    );
    return '$_temp0 $_temp1. Efter sammanslagning blir det $items.';
  }

  @override
  String get shoppingMergeStatMerged => 'slås samman';

  @override
  String get shoppingMergeStatConverted => 'konverteras';

  @override
  String get shoppingMergeStatAtHome => 'finns hemma';

  @override
  String get shoppingMergeShowDetails => 'Visa detaljer';

  @override
  String get shoppingMergeHideDetails => 'Dölj detaljer';

  @override
  String get shoppingMergeShowDetailsA11y =>
      'Visa detaljer om sammanslagningen';

  @override
  String get shoppingMergeHideDetailsA11y =>
      'Dölj detaljer om sammanslagningen';

  @override
  String get shoppingMergeDuplicatesTitle => 'Slå samman dubbletter';

  @override
  String get shoppingMergeDuplicatesBody =>
      'Gul lök från tre recept blir en rad med summerad mängd. Raden visar ”3 recept”.';

  @override
  String get shoppingMergeConvertTitle => 'Konvertera enheter';

  @override
  String get shoppingMergeConvertBody =>
      '2 dl + 100 ml blir 3 dl. Volym och vikt konverteras aldrig mot varandra – de blir två rader.';

  @override
  String get shoppingMergePantryTitle => 'Dra bort skafferivaror';

  @override
  String shoppingMergePantryBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count varor finns hemma.',
      one: '1 vara finns hemma.',
      zero: 'Ingen av varorna finns hemma.',
    );
    return '$_temp0';
  }

  @override
  String shoppingMergePantryCovered(String names) {
    return 'Finns hemma i tillräcklig mängd: $names';
  }

  @override
  String get shoppingMergePantryUnavailable =>
      'Skafferiet gick inte att läsa, så listan görs utan skafferiavdrag.';

  @override
  String shoppingMergeAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lägg till $count varor',
      one: 'Lägg till 1 vara',
    );
    return '$_temp0';
  }

  @override
  String get shoppingMergeUpdate => 'Uppdatera listan';

  @override
  String get shoppingMergeUpdateBody =>
      'Listan har redan varor från veckan. De uppdateras, men det du har ändrat eller bockat av rörs inte och dina egna varor finns kvar. Listan följer sedan med när du ändrar veckan.';

  @override
  String shoppingMergeSynced(String list) {
    return '$list är uppdaterad med veckan. Det du har ändrat själv finns kvar.';
  }

  @override
  String shoppingMergeAdded(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count varor lades till i $list.',
      one: '1 vara lades till i $list.',
    );
    return '$_temp0';
  }

  @override
  String shoppingMergeConcurrentChange(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Listan hade ändrats på en annan enhet. Dina $count varor lades till och inget skrevs över.',
      one:
          'Listan hade ändrats på en annan enhet. Din vara lades till och inget skrevs över.',
    );
    return '$_temp0';
  }

  @override
  String shoppingFollowNotice(String changes) {
    return 'Uppdaterad från veckomenyn: $changes';
  }

  @override
  String shoppingFollowAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count nya',
      one: '1 ny',
    );
    return '$_temp0';
  }

  @override
  String shoppingFollowChanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ändrade',
      one: '1 ändrad',
    );
    return '$_temp0';
  }

  @override
  String shoppingFollowRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count borttagna',
      one: '1 borttagen',
    );
    return '$_temp0';
  }

  @override
  String get shoppingFollowNoticeDismiss => 'Stäng meddelandet';

  @override
  String get shoppingFollowNoticeUndoFailed => 'Kunde inte ångra uppdateringen';

  @override
  String get shoppingMergeUndoFailed => 'Kunde inte ångra sammanslagningen';

  @override
  String get shoppingMergeUndoFailedKept => 'Varorna finns kvar i listan.';

  @override
  String shoppingMergeRowRecipes(int count) {
    return '$count recept';
  }

  @override
  String get shoppingMergeMarkMaybeHome => 'Kanske hemma';

  @override
  String get shoppingMergeMarkCheckDate => 'Kolla datum';

  @override
  String signOutPendingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ändringar har inte sparats',
      one: '1 ändring har inte sparats',
    );
    return '$_temp0';
  }

  @override
  String get signOutPendingBody =>
      'Om du loggar ut nu försvinner de. Butlery väntar gärna tills du har nät igen.';

  @override
  String signOutPendingRecipes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recept · $count ändringar',
      one: 'Recept · 1 ändring',
    );
    return '$_temp0';
  }

  @override
  String signOutPendingImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bilder · $count väntar på uppladdning',
      one: 'Bilder · 1 väntar på uppladdning',
    );
    return '$_temp0';
  }

  @override
  String get signOutPendingWait => 'Vänta på synk';

  @override
  String get signOutPendingDiscard => 'Logga ut och släng ändringarna';

  @override
  String draftTimeLeftDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'finns kvar i $count dagar',
      one: 'finns kvar i 1 dag',
    );
    return '$_temp0';
  }

  @override
  String weekMenuDraftResumeTitle(String when) {
    return 'Påbörjad veckomeny från $when';
  }

  @override
  String weekMenuDraftDaysDone(int count) {
    return '$count av 7 dagar har förslag';
  }

  @override
  String get weekMenuDraftDayEmpty => 'ingen rätt';

  @override
  String weekMenuDraftDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rätter passar inte längre och togs bort',
      one: '1 rätt passar inte längre och togs bort',
    );
    return '$_temp0';
  }

  @override
  String get weekMenuDraftRestoreFailed => 'Veckomenyn kunde inte återställas';

  @override
  String get weekMenuDraftRestoreFailedKept => 'Utkastet finns kvar.';

  @override
  String draftTimeLeftHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'finns kvar i $count timmar',
      one: 'finns kvar i 1 timme',
    );
    return '$_temp0';
  }

  @override
  String get profileDeleteNoRecallWindow =>
      'Kontot raderas efter 7 dagar. Loggar du in innan dess kan du ångra raderingen.';

  @override
  String get profileDeleteReasonLabel => 'Varför raderar du kontot?';

  @override
  String get profileDeleteReasonHint =>
      'Till exempel: använder appen inte längre';

  @override
  String get profileDeleteReasonHelp =>
      'Skälet följer med till revisionsraden. Det är det enda spåret som finns efteråt, därför frågar vi före.';

  @override
  String get accountDeletionWaitNotice =>
      'Detta kan ta upp till nio minuter. Stäng inte appen – raderingen fortsätter på servern, men du får inget kvitto om du går.';

  @override
  String get accountDeletionReauthTitle => 'Bekräfta att det är du';

  @override
  String get accountDeletionReauthBody =>
      'Av säkerhetsskäl krävs en inloggning som är högst fem minuter gammal för att radera ett konto. Logga in igen, så fortsätter raderingen där den var.';

  @override
  String get accountDeletionReauthCancel => 'Avbryt raderingen';

  @override
  String get accountDeletionReauthConfirm => 'Logga in igen';

  @override
  String get accountDeletionPartialTitle => 'Kontot är raderat delvis';

  @override
  String accountDeletionPartialHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Kontot är borta – $count delar kvarstår',
      one: 'Kontot är borta – en del kvarstår',
    );
    return '$_temp0';
  }

  @override
  String accountDeletionPartialBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Inloggningen är raderad. $count delar av din data gick inte att radera och ligger kvar hos oss.',
      one:
          'Inloggningen är raderad. En del av din data gick inte att radera och ligger kvar hos oss.',
    );
    return '$_temp0';
  }

  @override
  String get accountDeletionPartialAuditIdLabel => 'Revisions-id';

  @override
  String get accountDeletionPartialNoAuditId =>
      'Revisions-id saknas. Nämn datum och tid för raderingen när du kontaktar support.';

  @override
  String get accountDeletionPartialContact => 'Kontakta support med id';

  @override
  String accountDeletionPartialEmailSubject(String auditId) {
    return 'Delvis raderat konto $auditId';
  }

  @override
  String get accountDeletionPartialNoEmail =>
      'E-postappen gick inte att öppna. Skriv till integritet@butlery.se och ange revisions-id.';

  @override
  String get dataExportMemoryNotice =>
      'Spara filen innan du lämnar sidan. Den ligger bara i telefonens minne – går du tillbaka får du göra om exporten.';

  @override
  String get dataExportNetworkTitle => 'Exporten avbröts';

  @override
  String get dataExportNetworkBody =>
      'Anslutningen bröts medan vi samlade ihop uppgifterna. Ingenting är ändrat på ditt konto.';

  @override
  String get dataExportNoPartialFile =>
      'Vi erbjuder ingen halv fil. Den som tar emot dina uppgifter kan inte se vad som saknas i den.';

  @override
  String get dataExportSignedOutTitle => 'Inloggningen har gått ut';

  @override
  String get dataExportSignedOutBody =>
      'Logga in igen för att hämta ut dina uppgifter. Ingenting är ändrat på ditt konto.';

  @override
  String get dataExportSignIn => 'Logga in igen';

  @override
  String get dataExportDeniedTitle => 'Exporten nekades';

  @override
  String get dataExportDeniedBody =>
      'Felet ligger hos oss, inte hos dig, och ett nytt försök hjälper inte just nu. Ingenting är ändrat på ditt konto.';

  @override
  String get dataExportNotNow => 'Inte nu';

  @override
  String get consentAiProcessing => 'AI-tolkning';

  @override
  String get consentAiProcessingDescription =>
      'Läser recept ur länkar, text och foto. Utan detta blir importen grövre.';

  @override
  String consentRenewalChangedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Vi har ändrat $count saker',
      one: 'Vi har ändrat en sak',
    );
    return '$_temp0';
  }

  @override
  String consentRenewalSinceVersion(String version, String date) {
    return 'Du sa ja till version $version den $date. Det här är nytt sedan dess.';
  }

  @override
  String consentRenewalUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Övriga $count ändamål är oförändrade och dina val står kvar.',
      one: 'Övriga ändamål är oförändrade och dina val står kvar.',
    );
    return '$_temp0';
  }

  @override
  String get consentRenewalAccept => 'Jag godkänner';

  @override
  String get consentRenewalChooseMyself => 'Låt mig välja själv';

  @override
  String get consentRenewalNotNow => 'Inte nu';

  @override
  String get consentRenewalNotNowNote =>
      'Väljer du Inte nu fortsätter allt som förut. Ingenting slås av för att du inte svarat.';

  @override
  String get consentChangeAiProcessingAddedTitle =>
      'AI-tolkning är ett nytt ändamål';

  @override
  String get consentChangeAiProcessingAddedBody =>
      'Läser recept ur länkar, text och foto. Den står av tills du själv slår på den under Låt mig välja själv.';

  @override
  String get consentRenewalSaveFailed =>
      'Samtycket kunde inte sparas. Dina tidigare val står kvar.';

  @override
  String get signOutDiscardFailed =>
      'Ändringarna kunde inte slängas, så du är fortfarande inloggad.';

  @override
  String get mfaChallengeTitle => 'Tvåstegsverifiering';

  @override
  String get mfaChallengeHeading => 'Skriv koden';

  @override
  String get mfaChallengeWrongCode =>
      'Koden stämmer inte. Ta den senaste koden för Butlery i autentiseringsappen och försök igen.';

  @override
  String get mfaChallengeFailed =>
      'Inloggningen kunde inte slutföras. Gå tillbaka och logga in igen.';

  @override
  String get mfaBackupCodeUse => 'Använd en reservkod';

  @override
  String get mfaBackupCodeHeading => 'Logga in med en reservkod';

  @override
  String get mfaBackupCodeExplanation =>
      'En reservkod släpper in dig utan autentiseringsappen. Den går bara att använda en gång, och tvåstegsverifieringen stängs av tills du slår på den igen.';

  @override
  String get mfaBackupCodeLabel => 'Reservkod';

  @override
  String get mfaBackupCodeEnter => 'Skriv en av dina tio reservkoder.';

  @override
  String get mfaBackupCodeSubmit => 'Logga in med reservkoden';

  @override
  String get mfaBackupCodeBack => 'Tillbaka till koden från appen';

  @override
  String get mfaBackupCodeRejected =>
      'Lösenordet eller reservkoden stämmer inte. En använd kod går inte att använda igen.';

  @override
  String get mfaBackupCodeLocked =>
      'För många försök med reservkod. Försök igen senare, det kan dröja upp till en timme.';

  @override
  String get mfaBackupCodeUnavailable =>
      'Reservkoden kunde inte kontrolleras just nu. Ingenting är ändrat på ditt konto.';

  @override
  String get mfaBackupCodeRecovered =>
      'Tvåstegsverifieringen är avstängd. Slå på den igen under Kontosäkerhet.';

  @override
  String get mfaBackupCodesTitle => 'Tio reservkoder';

  @override
  String get mfaBackupCodesBody =>
      'Skriv ner dem eller spara dem på ett säkert ställe innan skyddet slås på. Utan autentiseringsappen kommer du in med en reservkod, och varje kod fungerar en gång. De visas bara nu.';

  @override
  String get mfaBackupCodesCopy => 'Kopiera koderna';

  @override
  String get mfaBackupCodesCopied =>
      'Koderna är kopierade. Urklippet töms om en minut.';

  @override
  String get mfaBackupCodesSaved => 'Jag har sparat koderna';

  @override
  String get mfaBackupCodesContinue => 'Fortsätt till autentiseringsappen';

  @override
  String get mfaBackupCodesFailed =>
      'Reservkoderna kunde inte skapas, så tvåstegsverifieringen slogs inte på. Ingenting är ändrat.';

  @override
  String get mfaErrorUnverifiedEmail =>
      'Tvåstegsverifieringen slogs inte på, eftersom din e-postadress inte är verifierad. Öppna e-postmeddelandet vi skickade till dig, tryck på verifieringslänken och försök sedan igen.';

  @override
  String get mfaErrorRequiresRecentLogin =>
      'Tvåstegsverifieringen slogs inte på, eftersom din inloggning är för gammal. Logga ut, logga in igen och försök sedan på nytt.';

  @override
  String get mfaAppTitle => 'Autentiseringsapp';

  @override
  String get mfaAppIntro =>
      'När tvåstegsverifiering är på ber vi om en sexsiffrig kod från en autentiseringsapp när du loggar in, till exempel Google Authenticator eller Microsoft Authenticator. Först får du tio reservkoder.';

  @override
  String get mfaTurnOn => 'Slå på tvåstegsverifiering';

  @override
  String get mfaSetupTitle => 'Lägg till Butlery i din autentiseringsapp';

  @override
  String get mfaSetupOpenApp => 'Öppna i autentiseringsapp';

  @override
  String get mfaSetupKeyIntro =>
      'Lägg till ett konto i appen och skriv in den här nyckeln:';

  @override
  String get mfaSetupKeyIntroAlternative =>
      'Eller lägg till ett konto för hand i appen och skriv in den här nyckeln:';

  @override
  String get mfaSetupCopyKey => 'Kopiera nyckeln';

  @override
  String get mfaSetupKeyCopied =>
      'Nyckeln är kopierad. Urklippet töms om en minut.';

  @override
  String get mfaSetupOpenFailed =>
      'Ingen autentiseringsapp öppnades. Installera en, eller skriv in nyckeln för hand.';

  @override
  String get mfaSetupCodeIntro =>
      'Skriv sedan den sexsiffriga kod som appen visar för Butlery.';

  @override
  String get mfaSetupConfirm => 'Bekräfta';

  @override
  String get mfaSetupFailed =>
      'Tvåstegsverifieringen kunde inte förberedas, så den slogs inte på. Ingenting är ändrat.';

  @override
  String get mfaChallengeAppPrompt =>
      'Öppna din autentiseringsapp och skriv den sexsiffriga koden för Butlery.';

  @override
  String get permAllow => 'Tillåt';

  @override
  String get permNotNow => 'Inte nu';

  @override
  String get permAskAgain => 'Fråga igen';

  @override
  String get permOpenSettings => 'Öppna inställningar';

  @override
  String get permImportCameraTitle => 'Fotografera receptet';

  @override
  String get permImportCameraBody =>
      'Vi läser texten ur bilden och fyller i receptet åt dig. Bilden skickas bara för att läsa av texten.';

  @override
  String get permImportPhotosTitle => 'Välj bilder av receptet';

  @override
  String get permImportPhotosBody =>
      'Vi läser texten ur bilderna du väljer och fyller i receptet åt dig.';

  @override
  String get permImportConsequence =>
      'Säger du nej går det fortfarande att skriva in receptet eller klistra in en länk.';

  @override
  String get permCameraTitle => 'Ta en bild med kameran';

  @override
  String get permCameraBody => 'Kameran används bara när du själv tar en bild.';

  @override
  String get permPhotosTitle => 'Välj bilder ur bildbiblioteket';

  @override
  String get permPhotosBody => 'Butlery läser bara de bilder du själv väljer.';

  @override
  String get permCameraDenied =>
      'Kameran är inte tillåten, så receptet går inte att fotografera.';

  @override
  String get permPhotosDenied =>
      'Bildbiblioteket är inte tillåtet, så receptet går inte att läsa ur en bild.';

  @override
  String get permCameraDeniedImage =>
      'Kameran är inte tillåten, så bilden går inte att ta.';

  @override
  String get permPhotosDeniedImage =>
      'Bildbiblioteket är inte tillåtet, så bilden går inte att välja.';

  @override
  String get permCameraPermanentlyDenied =>
      'Kameran är avstängd för Butlery i telefonens inställningar.';

  @override
  String get permPhotosPermanentlyDenied =>
      'Bildbiblioteket är avstängt för Butlery i telefonens inställningar.';

  @override
  String get permCameraRestricted =>
      'Enheten har spärrat kameran. Det går inte att ändra här.';

  @override
  String get permPhotosRestricted =>
      'Enheten har spärrat bildbiblioteket. Det går inte att ändra här.';

  @override
  String get permFallbackGallery => 'Välj ur bildbiblioteket';

  @override
  String get permFallbackWriteYourself => 'Skriv själv';

  @override
  String get permPhotosLimited =>
      'Du har delat några bilder med Butlery. Vi ser bara dem.';

  @override
  String get permPhotosLimitedHint =>
      'Hittar du inte bilden är det urvalet som saknar den, inte biblioteket. Du kan lägga till fler utan att ge oss hela biblioteket.';

  @override
  String get permPhotosChooseMore => 'Välj fler bilder';

  @override
  String get timerNotifDeniedTitle => 'Timern syns bara i appen';

  @override
  String get timerNotifDeniedBody =>
      'Notiser är avstängda för Butlery, så timern kan inte säga till när appen ligger i bakgrunden eller telefonen är låst.';

  @override
  String get timerNotifDeniedStart => 'Starta timern';

  @override
  String get timerInAppOnly => 'Timern syns bara i appen.';

  @override
  String get timerExactAlarmTitle => 'Ska timern ringa på sekunden?';

  @override
  String get timerExactAlarmBody =>
      'När appen ligger i bakgrunden kan telefonen skjuta upp timerns larm några minuter. Slå på Alarm och påminnelser för Butlery så ringer den exakt i tid.';

  @override
  String get notifSystemOffRow =>
      'Notiser är avstängda för Butlery i systemets inställningar. Inget nedan kan slås på förrän du ändrar det där.';

  @override
  String get a11yOpenSystemSettings => 'Öppna systeminställningarna';

  @override
  String get cookingExitConfirmTitle => 'Avsluta matlagningen?';

  @override
  String cookingExitConfirmBody(int step, int total) {
    return 'Du är på steg $step av $total. Receptet räknas inte som lagat förrän du trycker Klart.';
  }

  @override
  String get cookingExitConfirmStay => 'Fortsätt laga';

  @override
  String get cookingExitConfirmLeave => 'Avsluta matlagningen';

  @override
  String get cookingDone => 'Klart';

  @override
  String get cookingNoStepsTitle => 'Receptet har inga steg än';

  @override
  String get cookingNoStepsBody =>
      'Ingredienserna finns – men ingen har skrivit hur det görs. Skriv stegen, eller ta ingredienserna till inköpslistan.';

  @override
  String get cookingNoStepsBodyNoIngredients =>
      'Ingen har skrivit hur det görs än. Skriv stegen, så kan du laga härifrån.';

  @override
  String get cookingNoStepsWrite => 'Skriv stegen';

  @override
  String get cookingNoStepsShopping => 'Till inköpslistan';

  @override
  String get parseConfidenceConfirm => 'Stämmer';

  @override
  String get parseConfidenceConfirmed => 'Bekräftad';

  @override
  String a11yParseConfidenceConfirm(String line) {
    return 'Bekräfta raden $line';
  }

  @override
  String parseConfidencePendingSave(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Bekräfta $count rader innan du sparar',
      one: 'Bekräfta 1 rad innan du sparar',
    );
    return '$_temp0';
  }

  @override
  String get parseConfidenceUnreadLine => 'Raden kunde inte läsas';

  @override
  String get a11yParseConfidenceUnreadLine => 'Rad som inte kunde läsas';

  @override
  String importReadPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Läs av $count sidor',
      one: 'Läs av 1 sida',
    );
    return '$_temp0';
  }

  @override
  String get roleLoweredRecipeTitle => 'Du kan inte längre redigera receptet';

  @override
  String get roleLoweredRecipeBody =>
      'Du kan nu bara läsa receptet, så ändringarna sparas inte i det. Du kan spara dem som en egen kopia.';

  @override
  String get roleLoweredSaveCopy => 'Spara som egen kopia';

  @override
  String get roleLoweredDiscard => 'Släng ändringarna';

  @override
  String get roleLoweredRecipeClosed =>
      'Du kan inte längre redigera receptet, bara läsa det.';

  @override
  String get roleLoweredShoppingList =>
      'Du kan inte längre ändra i listan, bara läsa den.';

  @override
  String get roleLoweredShoppingUnsaved =>
      'Det du skrev lades inte till i listan:';

  @override
  String get roleLoweredCopyText => 'Kopiera texten';

  @override
  String get roleLoweredTextCopied => 'Texten är kopierad.';

  @override
  String get roleLoweredGroupMenu =>
      'Du kan inte längre ändra gruppens meny, bara läsa den.';

  @override
  String get conflictBannerTitleSuggestion => 'Ägarens version gäller';

  @override
  String conflictBannerBodySuggestion(String name) {
    return '$name ändrade samtidigt. Din ändring är sparad som ett förslag i 7 dagar.';
  }

  @override
  String get conflictBannerBodySuggestionUnnamed =>
      'Någon annan ändrade samtidigt. Din ändring är sparad som ett förslag i 7 dagar.';

  @override
  String conflictBannerBodyMemberNotSent(String name) {
    return '$name ändrade samtidigt. Din ändring sparades inte i receptet och skickades inte som förslag.';
  }

  @override
  String get conflictBannerBodyMemberNotSentUnnamed =>
      'Någon annan ändrade samtidigt. Din ändring sparades inte i receptet och skickades inte som förslag.';

  @override
  String get recipeSuggestionSeeMine => 'Se ditt förslag';

  @override
  String get recipeSuggestionSee => 'Se förslaget';

  @override
  String recipeSuggestionFromOne(String name) {
    return '$name föreslår en ändring i receptet.';
  }

  @override
  String get recipeSuggestionFromOneUnnamed =>
      'En medlem föreslår en ändring i receptet.';

  @override
  String recipeSuggestionFromMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count förslag på ändringar väntar',
      one: '1 förslag på ändring väntar',
    );
    return '$_temp0 på dig.';
  }

  @override
  String recipeSuggestionMinePending(String date) {
    return 'Ditt förslag väntar på ägaren. Det sparas till $date.';
  }

  @override
  String get recipeSuggestionMineAccepted =>
      'Ägaren tog in ditt förslag i receptet.';

  @override
  String recipeSuggestionMineDismissed(String date) {
    return 'Ägaren avvisade ditt förslag. Det sparas till $date.';
  }

  @override
  String get recipeSuggestionTitle => 'Förslag till ändring';

  @override
  String recipeSuggestionIntroOwner(String name, String title) {
    return '$name föreslår en ändring i $title. Ditt recept ändras bara om du använder förslaget.';
  }

  @override
  String recipeSuggestionIntroMine(String title) {
    return 'Du föreslog en ändring i $title. Receptet ändras bara om ägaren använder förslaget.';
  }

  @override
  String get recipeSuggestionSuggestedLabel => 'Förslaget';

  @override
  String get recipeSuggestionCurrentLabel => 'Nu';

  @override
  String get recipeSuggestionAccept => 'Använd förslaget';

  @override
  String get recipeSuggestionDismiss => 'Avvisa förslaget';

  @override
  String get recipeSuggestionAccepted => 'Förslaget är nu en del av receptet.';

  @override
  String get recipeSuggestionDismissed =>
      'Förslaget är avvisat. Receptet är oförändrat.';

  @override
  String get recipeSuggestionAcceptFailed =>
      'Förslaget kunde inte tas in i receptet.';

  @override
  String get recipeSuggestionDismissFailed => 'Förslaget kunde inte avvisas.';

  @override
  String recipeSuggestionKeptUntil(String date) {
    return 'Förslaget finns kvar till $date.';
  }

  @override
  String get recipeSuggestionRecipeGone =>
      'Receptet finns inte längre, så förslaget kan inte tas in.';

  @override
  String get recipeSuggestionLoadFailed =>
      'Förslaget kunde inte jämföras med receptet. Kontrollera anslutningen.';

  @override
  String get recipeSuggestionNoChanges =>
      'Förslaget är likadant som receptet nu.';

  @override
  String get recipeSuggestionLoading => 'Hämtar förslaget …';

  @override
  String recipeAddCountToShoppingList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Lägg $count varor i inköpslistan',
      one: 'Lägg 1 vara i inköpslistan',
    );
    return '$_temp0';
  }

  @override
  String get weeklyMenuOverflowDiscardAction => 'Släng resten';

  @override
  String weeklyMenuOverflowDiscarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rätter slängdes ur brickan',
      one: '1 rätt slängdes ur brickan',
    );
    return '$_temp0';
  }

  @override
  String get pantryItemAmountUnknown => 'har hemma';

  @override
  String recipePantryAllAtHome(String names) {
    return 'Allt finns hemma i tillräcklig mängd, så inget läggs i inköpslistan: $names';
  }

  @override
  String get recipeAllAtHome => 'Allt finns hemma';

  @override
  String recipePantryLessened(String names) {
    return 'Mindre än i receptet, eftersom en del finns hemma: $names';
  }

  @override
  String get navigationHome => 'Hem';

  @override
  String get navigationMore => 'Mer';

  @override
  String get navigationAddAction => 'Lägg till';

  @override
  String get moreTitle => 'Mer';

  @override
  String get moreSectionTogether => 'Tillsammans';

  @override
  String get moreSectionKitchen => 'Ditt kök';

  @override
  String get moreSectionAppAccount => 'Konto & app';

  @override
  String get moreFamily => 'Mitt hushåll';

  @override
  String get morePersonalTags => 'Egna taggar';

  @override
  String get moreCollectionStats => 'Min samling';

  @override
  String get moreNotifications => 'Notiser';

  @override
  String get addSheetQuickSaveTitle => 'Snabbspara';

  @override
  String get addSheetQuickSaveSubtitle =>
      'Bara namn och måltid – importera detaljer senare';

  @override
  String get syncQueueTitle => 'Väntar på synk';

  @override
  String syncQueueNeedsYouHeader(int count) {
    return 'Väntar på dig · $count';
  }

  @override
  String get syncQueueNeedsYouHint =>
      'Dessa försöker inte igen av sig själva. Orsaken står i ord, och varje post har en handling.';

  @override
  String syncQueueQueuedHeader(int count) {
    return 'I kö · $count';
  }

  @override
  String get syncQueueOrderNote =>
      'Ordningen är först in, först ut per objekt, men parallellt mellan objekt.';

  @override
  String get syncQueueSyncNow => 'Försök synka nu';

  @override
  String get syncQueueSyncing => 'Synkar …';

  @override
  String get syncQueueRetry => 'Försök igen';

  @override
  String syncQueueRetryA11y(String what) {
    return 'Försök igen – $what';
  }

  @override
  String get syncQueueDiscard => 'Släng ändringen';

  @override
  String syncQueueDiscardA11y(String what) {
    return 'Släng ändringen $what';
  }

  @override
  String get syncQueueDiscarded => 'Ändringen slängdes.';

  @override
  String get syncQueueRecipeDiscarded => 'Receptet slängdes.';

  @override
  String get syncQueueDiscardPhoneOnlyTitle => 'Släng receptet?';

  @override
  String syncQueueDiscardPhoneOnlyBody(String title) {
    return '$title finns bara på den här telefonen. Det har aldrig nått servern, så om du slänger det finns det inte kvar någonstans.';
  }

  @override
  String get syncQueueDiscardPhoneOnlyConfirm => 'Släng receptet';

  @override
  String get syncQueueDiscardFailed => 'Ändringen kunde inte slängas.';

  @override
  String get syncQueueRetryFailed =>
      'Ändringen kunde inte läggas tillbaka i kön.';

  @override
  String get syncQueueSyncFailed => 'Kön kunde inte skickas nu.';

  @override
  String get syncQueueLoadFailed => 'Kön gick inte att läsa just nu.';

  @override
  String get syncQueueChangeKept => 'Den ligger kvar under Väntar på dig.';

  @override
  String get syncQueueChangesKept => 'Ändringarna ligger kvar på telefonen.';

  @override
  String get syncQueueEmpty => 'Allt är sparat. Inget väntar på att synkas.';

  @override
  String get syncQueueWaitsOnEarlier => 'väntar på en tidigare ändring';

  @override
  String get syncQueueUnnamedRecipe => 'Ett recept';

  @override
  String syncQueueRecipeCreated(String title) {
    return '$title · nytt recept';
  }

  @override
  String syncQueueRecipeUpdated(String title) {
    return '$title · ändrat';
  }

  @override
  String syncQueueRecipeDeleted(String title) {
    return '$title · borttaget';
  }

  @override
  String syncQueueRecipeTagged(String title) {
    return '$title · taggas';
  }

  @override
  String syncQueueImageFor(String title) {
    return 'Bild till $title';
  }

  @override
  String get syncQueueImage => 'En bild';

  @override
  String syncQueueCookSnap(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Matlagningsfoton ($count bilder)',
      one: 'Matlagningsfoton (1 bild)',
    );
    return '$_temp0';
  }

  @override
  String syncQueueComment(String recipe) {
    return 'Kommentar på $recipe';
  }

  @override
  String get syncQueueCommentUnnamed => 'Kommentar';

  @override
  String get syncQueueReasonCommentFailed => 'Kommentaren kunde inte skickas.';

  @override
  String get commentQueuedOffline =>
      'Kommentaren skickas när du är online igen.';

  @override
  String get syncQueueReasonNotFound => 'Receptet finns inte längre';

  @override
  String get syncQueueReasonPermission => 'Du har inte längre behörighet';

  @override
  String get syncQueueReasonTooLarge => 'Bilden är för stor';

  @override
  String get syncQueueReasonDependency =>
      'Den hänger på en ändring som inte gick att spara';

  @override
  String get syncQueueReasonUnknown => 'Servern tog inte emot ändringen';

  @override
  String get syncQueueReasonExpired => 'Gick inte att spara på 24 h';

  @override
  String get syncQueueSaveAsCopy => 'Spara som kopia';

  @override
  String syncQueueCopyTitle(String title) {
    return '$title (kopia)';
  }

  @override
  String syncQueueSaveAsCopyA11y(String what) {
    return 'Spara som kopia – $what';
  }

  @override
  String get syncQueueTrySmaller => 'Försök mindre';

  @override
  String syncQueueTrySmallerA11y(String what) {
    return 'Försök mindre – $what';
  }

  @override
  String get syncQueueCopyFailed => 'Kopian kunde inte sparas.';

  @override
  String get syncQueueTrySmallerFailed => 'Bilden kunde inte göras mindre.';

  @override
  String syncQueueNextAttemptSeconds(int seconds) {
    return 'nästa försök om $seconds s';
  }

  @override
  String syncQueueNextAttemptMinutes(int minutes) {
    return 'nästa försök om $minutes min';
  }

  @override
  String get syncQueueAgeNow => 'nu';

  @override
  String syncQueueAgeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String syncQueueAgeHours(int hours) {
    return '$hours h';
  }

  @override
  String syncQueueAgeHoursMinutes(int hours, int minutes) {
    return '$hours h $minutes min';
  }

  @override
  String syncQueueAgeDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dygn',
      one: '1 dygn',
    );
    return '$_temp0';
  }

  @override
  String syncQueueAutoDiscard(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Slängs automatiskt om $days dagar',
      one: 'Slängs automatiskt om 1 dag',
      zero: 'Slängs automatiskt i dag',
    );
    return '$_temp0';
  }

  @override
  String syncQueueIndicatorA11y(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ändringar väntar på dig. Öppna Väntar på synk',
      one: '1 ändring väntar på dig. Öppna Väntar på synk',
    );
    return '$_temp0';
  }

  @override
  String get recipeSuggestChange => 'Föreslå ändring';

  @override
  String get recipeSuggestionSend => 'Skicka förslaget';

  @override
  String get recipeSuggestionSending => 'Skickar förslaget …';

  @override
  String get recipeSuggestionSent => 'Förslaget är skickat till ägaren.';

  @override
  String get recipeSuggestionSendFailed => 'Förslaget kunde inte skickas.';

  @override
  String get recipeSuggestionCoversText =>
      'Ett förslag gäller receptets text: titel, beskrivning, måltid, portioner, tid, ingredienser och steg.';

  @override
  String get recipeSuggestionReplaced =>
      'Förslaget är skickat och ersatte ditt förra förslag.';

  @override
  String conflictBannerBodySuggestionReplaced(String name) {
    return '$name ändrade samtidigt. Din ändring ersatte ditt förra förslag och sparas i 7 dagar.';
  }

  @override
  String get conflictBannerBodySuggestionReplacedUnnamed =>
      'Någon annan ändrade samtidigt. Din ändring ersatte ditt förra förslag och sparas i 7 dagar.';

  @override
  String recipeSuggestionFromOneUpdated(String name) {
    return '$name har uppdaterat sitt förslag till receptet.';
  }

  @override
  String get recipeSuggestionFromOneUpdatedUnnamed =>
      'En medlem har uppdaterat sitt förslag till receptet.';

  @override
  String recipeSuggestionFromManyUpdated(int count, int updated) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count förslag på ändringar väntar',
      one: '1 förslag på ändring väntar',
    );
    String _temp1 = intl.Intl.pluralLogic(
      updated,
      locale: localeName,
      other: '$updated av dem är uppdaterade.',
      one: 'Ett av dem är uppdaterat.',
    );
    return '$_temp0 på dig. $_temp1';
  }

  @override
  String recipeSuggestionIntroOwnerUpdated(String name, String title) {
    return '$name har uppdaterat sitt förslag till $title. Ditt recept ändras bara om du använder förslaget.';
  }

  @override
  String recipeSuggestionIntroMineUpdated(String title) {
    return 'Du föreslog en ändring i $title, och den ersatte ditt förra förslag. Receptet ändras bara om ägaren använder förslaget.';
  }

  @override
  String get recipeSuggestionChangedSinceOpened =>
      'Förslaget har ändrats sedan du öppnade det. Öppna det igen för att se det nya.';

  @override
  String get cookingNoStepsSaveCopy => 'Spara min kopia';

  @override
  String get cookingNoStepsBodyOthers =>
      'Ingredienserna finns – men ingen har skrivit hur det görs. Spara en egen kopia och skriv stegen där, eller ta ingredienserna till inköpslistan.';

  @override
  String get cookingNoStepsBodyOthersNoIngredients =>
      'Ingen har skrivit hur det görs än. Spara en egen kopia och skriv stegen där.';

  @override
  String get hemGreetingMorning => 'God morgon';

  @override
  String get hemGreetingDay => 'Hej';

  @override
  String get hemGreetingEvening => 'God kväll';

  @override
  String get hemGreetingNight => 'God natt';

  @override
  String get hemGreetingWelcome => 'Välkommen';

  @override
  String hemGreetingWithName(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String get hemTonight => 'Ikväll';

  @override
  String hemLibraryHeading(int count) {
    return 'Dina recept · $count';
  }

  @override
  String hemMetaMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String hemMetaPortions(int count) {
    return '$count port.';
  }

  @override
  String get hemStartCooking => 'Börja laga';

  @override
  String get hemSuggestion => 'Förslag';

  @override
  String get hemSwapSuggestion => 'Byt förslag';

  @override
  String get hemSwapDish => 'Byt rätt';

  @override
  String get hemAllInPantry => 'allt i skafferiet';

  @override
  String get hemLoadingPlan => 'Hämtar veckomenyn …';

  @override
  String get hemPlanErrorWhat => 'Veckomenyn kunde inte hämtas.';

  @override
  String get hemShowSavedPlan => 'Öppna veckomenyn';

  @override
  String hemPlanFetchedAt(String time) {
    return 'Planen hämtades $time – kan ha ändrats av någon annan sedan dess.';
  }

  @override
  String get hemEmptyTitle => 'Butlery blir användbar med ett recept';

  @override
  String get hemEmptyBody =>
      'Lägg in något du redan lagar ofta. Sedan kan Butlery planera veckan, räkna om portioner och skriva inköpslistan åt dig.';

  @override
  String get hemEmptyShortcuts => 'Snabbaste vägarna';

  @override
  String get hemEmptyLinkTitle => 'Klistra in en länk';

  @override
  String get hemEmptyLinkBody => 'från en receptsida, YouTube eller Instagram';

  @override
  String get hemEmptyPhotoTitle => 'Fota en receptsida';

  @override
  String get hemEmptyPhotoBody => 'ur en kokbok eller ett urklipp';

  @override
  String get hemEmptyWriteTitle => 'Skriv själv';

  @override
  String get hemEmptyWriteBody => 'för det du lagar utan recept';

  @override
  String get hemEmptyAllergyNote =>
      'Har hushållet allergier? Ställ in dem först, så filtrerar Butlery bort dem ur veckomenyn. Kontrollera ändå alltid förpackningen.';

  @override
  String get hemEmptyAllergyLink => 'Ställ in allergener';

  @override
  String get bulkAddToMenuFailed =>
      'Recepten kunde inte läggas till i veckomenyn.';

  @override
  String get bulkExportFailed => 'Recepten kunde inte exporteras.';

  @override
  String get profilePrivacyPolicyOpenFailed =>
      'Integritetspolicyn kunde inte öppnas.';

  @override
  String get profileConsentManagementOpenFailed =>
      'Samtyckeshanteringen kunde inte öppnas.';

  @override
  String get profileDataExportOpenFailed => 'Dataexporten kunde inte öppnas.';

  @override
  String get shareCouldNotComplete => 'Delningen kunde inte genomföras.';

  @override
  String shareRecipesNotShared(int count, String titles) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept kunde inte delas: $titles.',
      one: 'Ett recept kunde inte delas: $titles.',
    );
    return '$_temp0';
  }

  @override
  String get shareRecipesRetryOnlyFailed =>
      'Det du fyllt i ligger kvar. Dela försöker igen med bara dem.';

  @override
  String get imageSelectFailed => 'Bilderna kunde inte väljas.';

  @override
  String get groupMenuOpenFailed => 'Menyn kunde inte öppnas.';

  @override
  String get groupRecipeOpenFailed => 'Receptet kunde inte öppnas.';

  @override
  String get retagFailed => 'Omtaggningen kunde inte slutföras.';

  @override
  String get profileAccountDeleteFailed => 'Kontot kunde inte raderas.';

  @override
  String get adminMetricsLoadFailed => 'Kunde inte ladda mätvärden';

  @override
  String get adminOpsLogLoadFailed => 'Kunde inte ladda driftloggen';

  @override
  String get adminParsingStatsLoadFailed =>
      'Kunde inte ladda parsing-statistik';

  @override
  String get familyRatingsLoadFailed => 'Kunde inte ladda betygen';

  @override
  String get familyRatingEntryLoadFailed => 'Kunde inte ladda betygssättningen';

  @override
  String get familyRatingSaveFailed => 'Kunde inte spara betyget';

  @override
  String get familyLoadFailed => 'Kunde inte ladda hushållet';

  @override
  String get familyMemberSaveFailed =>
      'Matgästen kunde inte sparas. Försök igen.';

  @override
  String get familyConsentRevokeFailed => 'Kunde inte återkalla samtycket';

  @override
  String get familyMemberRemoveFailed =>
      'Matgästen kunde inte raderas. Försök igen.';

  @override
  String get householdLoadFailed => 'Kunde inte ladda hushållet';

  @override
  String get weeklyMenuSaveError => 'Kunde inte spara veckomenyn';

  @override
  String get weeklyMenuWhoIsHomeSaveFailed =>
      'Kunde inte spara vilka som är hemma';

  @override
  String get weeklyMenuAddRecipeFailed => 'Kunde inte lägga till receptet';

  @override
  String get weeklyMenuMoveRecipeFailed => 'Kunde inte flytta receptet';

  @override
  String get weeklyMenuRemoveRecipeFailed => 'Kunde inte ta bort receptet';

  @override
  String get weeklyMenuClearFailed => 'Kunde inte rensa veckan';

  @override
  String get weeklyMenuUndoClearFailed => 'Kunde inte ångra rensningen';

  @override
  String get pantryLoadFailed => 'Kunde inte ladda skafferiet';

  @override
  String get pantryAddFailed => 'Kunde inte lägga till i skafferiet';

  @override
  String get pantryRemoveItemFailed => 'Kunde inte ta bort varan';

  @override
  String get pantryRestoreItemFailed => 'Kunde inte återställa varan';

  @override
  String get pantryRemoveItemsFailed => 'Kunde inte ta bort varorna';

  @override
  String get pantryRestoreItemsFailed => 'Kunde inte återställa varorna';

  @override
  String get sharedShoppingListsLoadFailed =>
      'Kunde inte ladda delade inköpslistor';

  @override
  String get activityFeedLoadFailed => 'Kunde inte ladda flödet';

  @override
  String get activityFeedLoadMoreFailed => 'Kunde inte ladda fler händelser';

  @override
  String get groupCreateFailed => 'Gruppen kunde inte skapas.';

  @override
  String get groupRemoveMemberFailed => 'Medlemmen kunde inte tas bort.';

  @override
  String get groupLeaveFailed => 'Det gick inte att lämna gruppen.';

  @override
  String get groupInvitationCancelFailed => 'Inbjudan kunde inte avbrytas.';

  @override
  String groupInvitationsPartlyFailed(int failed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total inbjudningar',
      one: '1 inbjudan',
    );
    return '$failed av $_temp0 kunde inte skickas.';
  }

  @override
  String get conversationStartFailed => 'Konversationen kunde inte startas.';

  @override
  String get conversationDeleteFailed => 'Konversationen kunde inte raderas.';

  @override
  String get profileOpenFailed => 'Profilen kunde inte öppnas.';

  @override
  String get feedRecipeRequestFailed => 'Förfrågan kunde inte skickas.';

  @override
  String get groupInvitationDeclineFailed => 'Inbjudan kunde inte avböjas.';

  @override
  String get socialInviteLinkShareFailed =>
      'Inbjudningslänken kunde inte delas.';

  @override
  String get socialInviteLinkCopyFailed =>
      'Inbjudningslänken kunde inte kopieras.';

  @override
  String get chatMessagesLoadFailed => 'Meddelandena kunde inte laddas.';

  @override
  String get draftDiscard => 'Släng';

  @override
  String draftsDiscarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utkast slängdes',
      one: 'Utkastet slängdes',
    );
    return '$_temp0';
  }

  @override
  String get shoppingRestoreItems => 'Återställ varor';

  @override
  String get shoppingRestoreGroupRemoved => 'Borttagna';

  @override
  String get shoppingRestoreGroupChanged => 'Ändrade';

  @override
  String get shoppingRestoreButton => 'Återställ';

  @override
  String shoppingRestoreButtonFor(String name) {
    return 'Återställ $name';
  }

  @override
  String shoppingRestoreChangedLine(String label, String current) {
    return '$label (nu: $current)';
  }

  @override
  String get shoppingRestoreEmpty => 'Inget att återställa.';

  @override
  String shoppingRestoredRemoved(String name) {
    return '$name är tillbaka på listan.';
  }

  @override
  String shoppingRestoredChanged(String name) {
    return '$name har fått sin förra version tillbaka.';
  }

  @override
  String pantryPreviousVersion(String when) {
    return 'Förra versionen · $when';
  }

  @override
  String get pantryRestorePreviousAction => 'Återställ';

  @override
  String get pantryPreviousRestored => 'Förra versionen är återställd';

  @override
  String get pantryRestorePreviousFailed =>
      'Kunde inte återställa förra versionen';

  @override
  String get whatsNewTitle => 'Det här är nytt';

  @override
  String get whatsNewDone => 'Toppen';

  @override
  String get whatsNewAboutTitle => 'Nyheter';

  @override
  String whatsNewVersionRange(String from, String to) {
    return 'Version $from–$to';
  }

  @override
  String get setNewPasswordTitle => 'Välj nytt lösenord';

  @override
  String get setNewPasswordChecking => 'Kontrollerar länken …';

  @override
  String setNewPasswordForAccount(String email) {
    return 'Välj ett nytt lösenord för $email';
  }

  @override
  String get setNewPasswordRepeat => 'Upprepa nytt lösenord';

  @override
  String get setNewPasswordSave => 'Spara lösenordet';

  @override
  String get setNewPasswordWeak =>
      'Lösenordet är för enkelt. Använd tolv eller fler tecken, eller tre ord du minns.';

  @override
  String get setNewPasswordSaveFailed => 'Lösenordet kunde inte sparas.';

  @override
  String setNewPasswordSaveFailedBecause(String cause) {
    return 'Lösenordet kunde inte sparas. $cause';
  }

  @override
  String get setNewPasswordNothingChanged =>
      'Ditt gamla lösenord gäller fortfarande.';

  @override
  String get setNewPasswordCheckFailed => 'Länken kunde inte kontrolleras.';

  @override
  String get setNewPasswordLinkInvalidTitle => 'Länken gäller inte längre';

  @override
  String get setNewPasswordLinkInvalidBody =>
      'Den har redan använts eller blivit för gammal. Be om en ny länk, så kommer den till din e-post.';

  @override
  String get setNewPasswordRequestNew => 'Skicka ny länk';

  @override
  String get setNewPasswordClose => 'Stäng';

  @override
  String setNewPasswordSavedOther(String email) {
    return 'Lösenordet för $email är bytt.';
  }

  @override
  String get passwordResetDoneNotice =>
      'Lösenordet är bytt. Logga in med det nya.';

  @override
  String shoppingItemsAddedToListSnack(int count, String listName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count varor tillagda i ”$listName”',
      one: '1 vara tillagd i ”$listName”',
    );
    return '$_temp0';
  }

  @override
  String get shoppingAddToListHeading => 'Lägg i lista';

  @override
  String get recipeImportNoIngredientsNotice =>
      'Vi hittade inga ingredienser. Lägg till dem själv nedan.';

  @override
  String get trashTitle => 'Papperskorgen';

  @override
  String get trashLoading => 'Laddar papperskorgen …';

  @override
  String get trashLoadFailed => 'Papperskorgen kunde inte laddas.';

  @override
  String get trashEmptyTitle => 'Papperskorgen är tom';

  @override
  String get trashEmptyBody => 'Raderade recept ligger kvar här i 30 dagar.';

  @override
  String trashDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dagar kvar',
      one: '1 dag kvar',
      zero: 'Går ut i dag',
    );
    return '$_temp0';
  }

  @override
  String get trashEmptyAction => 'Töm papperskorgen';

  @override
  String get trashDeleteConfirmAction => 'Radera för gott';

  @override
  String get trashEmptyConfirmTitle => 'Tömma papperskorgen?';

  @override
  String get trashEmptyConfirmBody =>
      'Alla recept i papperskorgen raderas för alltid. Det går inte att ångra.';

  @override
  String trashRestoredAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept återställda som privat',
      one: 'Återställt som privat',
    );
    return '$_temp0';
  }

  @override
  String trashDeletedAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept raderades för alltid',
      one: 'Receptet raderades för alltid',
    );
    return '$_temp0';
  }

  @override
  String get trashEmptied => 'Papperskorgen är tömd';

  @override
  String get trashOfflineNothingChanged => 'Du är offline. Inget ändrades.';

  @override
  String get trashFailedNothingChanged =>
      'Papperskorgen kunde inte uppdateras. Inget ändrades.';

  @override
  String trashPartialSummary(int done, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total klara',
      one: '1 klar',
    );
    return '$done av $_temp0.';
  }

  @override
  String get trashPartialNoneDone => 'Inget ändrades.';

  @override
  String trashFailOffline(int count) {
    return '$count recept gjordes inte eftersom du är offline.';
  }

  @override
  String trashFailExpired(int count) {
    return '$count recept hade redan gått ut.';
  }

  @override
  String trashFailGone(int count) {
    return '$count recept fanns inte kvar i papperskorgen.';
  }

  @override
  String trashFailFailed(int count) {
    return '$count recept gick inte att klara. Försök igen.';
  }

  @override
  String get weekMenuPlanningCancel => 'Avbryt planeringen';

  @override
  String get weekMenuPlanningCancelNote =>
      'Avbryt behåller ditt senaste förslag. Inget skrivs över förrän du sparar.';

  @override
  String get privacyShowNameOnDishesTitle =>
      'Visa mitt namn på mina rätter i delade menyer';

  @override
  String get privacyShowNameOnDishesSubtitle =>
      'Den som öppnar en delad meny ser ditt namn under de rätter du har gjort och kan gå till din profil. Det gäller alla delade menyer där dina rätter finns, även äldre och sådana som andra har delat vidare. Stänger du av försvinner namnet inom 30 minuter.';

  @override
  String get privacyShowNameOnDishesMinor =>
      'Inte tillgängligt för konton under 18 år.';

  @override
  String menuDishCreatorCredit(String name) {
    return 'Recept av $name';
  }

  @override
  String get a11yOpenCreatorProfile => 'Öppna profilen';

  @override
  String get errorCouldNotSaveDishCredit =>
      'Valet om ditt namn på rätter kunde inte sparas. Försök igen.';

  @override
  String get reportReasonMisattribution => 'Det här är inte min rätt';

  @override
  String get menuDishReportTooltip => 'Anmäl rätten';

  @override
  String get menuDishNotMine => 'Det här är inte min rätt';

  @override
  String get notMyDishTitle => 'Det här är inte min rätt';

  @override
  String get notMyDishBody =>
      'Ditt namn tas bort från rätten, och en moderator får se anmälan. Vill du inte att ditt namn visas på några rätter kan du stänga av det under Integritet.';

  @override
  String get notMyDishConfirm => 'Ta bort mitt namn';

  @override
  String get notMyDishSubmitted =>
      'Ditt namn tas bort från rätten. En moderator tittar på anmälan.';

  @override
  String get moderatorContentTypeMenuDish => 'Rätt i delad meny';

  @override
  String get moderatorActionRemoveDish => 'Ta bort rätten ur menyn';

  @override
  String get moderatorRemoveDishConfirmTitle => 'Ta bort rätten ur menyn?';

  @override
  String get moderatorRemoveDishConfirmBody =>
      'Bara den här rätten tas bort ur den delade menyn. Resten av menyn ligger kvar.';

  @override
  String get moderatorMenuDishSharerNote =>
      'Den som delade menyn har inte nödvändigtvis skrivit rätten.';

  @override
  String get moderatorMenuDishClaimedReporter =>
      'Rätten angav anmälaren som skapare när anmälan kom in.';

  @override
  String get moderatorMenuDishNotClaimedReporter =>
      'Rätten angav inte anmälaren som skapare när anmälan kom in.';

  @override
  String get mealAllergenScopeTitle =>
      'Anpassa allergifiltret efter vem som är hemma';

  @override
  String get mealAllergenScopeSubtitle =>
      'Lunch och middag räknar bara med dem som är hemma. Övrigt, som mellanmål och bakning, räknar alltid med alla.';

  @override
  String get mealAllergenScopeOnTitle => 'Anpassa efter vem som är hemma?';

  @override
  String get mealAllergenScopeOnBody =>
      'Då kan en rätt som någon i hushållet inte tål, även ett barn, planeras in på en lunch eller middag när den personen är markerad som borta. Det gäller dina egna allergier också. Se till att det stämmer vem som är hemma i veckomenyn. Valet kan stängas av när som helst.';

  @override
  String get mealAllergenScopeOnAction => 'Slå på';

  @override
  String get menuAllergenUnsafeAtMeal =>
      'Innehåller något som någon hemma inte tål';

  @override
  String get menuAllergenUnsafeForHousehold => 'passar inte alla i hushållet';

  @override
  String get menuMealAllergenScopeHint =>
      'Allergifiltret följer vem som är hemma. Rätter som inte passar alla i hushållet läggs bara på en lunch eller middag när den som inte tål dem är borta.';

  @override
  String get weeklyMenuOverflowAllergen =>
      'Några av dem passar inte någon som är hemma de dagar som var lediga.';

  @override
  String get accountDeletionScheduling => 'Förbereder raderingen …';

  @override
  String get accountDeletionScheduledTitle => 'Raderingen är schemalagd';

  @override
  String accountDeletionScheduledBody(String date) {
    return 'Kontot raderas $date. Loggar du in före dess kan du ångra raderingen.';
  }

  @override
  String get accountDeletionScheduledBodyNoDate =>
      'Kontot raderas när ångerperioden har gått ut. Loggar du in före dess kan du ångra raderingen.';

  @override
  String get pendingDeletionTitle => 'Ditt konto ska raderas';

  @override
  String get pendingDeletionUndo => 'Ångra raderingen';

  @override
  String get pendingDeletionDeleteNow => 'Radera nu';

  @override
  String get pendingDeletionDeleteNowConfirmTitle => 'Radera kontot nu?';

  @override
  String get pendingDeletionDeleteNowConfirmBody =>
      'Allt raderas direkt och det går inte att ångra.';

  @override
  String get pendingDeletionUndoFailed => 'Raderingen kunde inte ångras';

  @override
  String get pendingDeletionAlreadyStarted =>
      'Raderingen har redan startat och kan inte ångras längre.';

  @override
  String get moreProfileSubtitle => 'Profil och synlighet';

  @override
  String get moreProfileFallbackName => 'Din profil';

  @override
  String moreSyncBand(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ändringar väntar på synk',
      one: '1 ändring väntar på synk',
    );
    return '$_temp0';
  }

  @override
  String get moreSectionHousehold => 'Hushåll & mat';

  @override
  String get moreAllergens => 'Allergener & kost';

  @override
  String get settingsAccountAreaTitle => 'Konto & säkerhet';

  @override
  String get settingsAccountAreaSubtitle =>
      'Inloggning, tvåstegsverifiering, logga ut';

  @override
  String get settingsPrivacyAreaTitle => 'Integritet och data';

  @override
  String get settingsPrivacyAreaSubtitle => 'Samtycken, export, säkerhetskopia';

  @override
  String get settingsAppTitle => 'Appinställningar';

  @override
  String get settingsAppSubtitle => 'Språk, tema, notiser';

  @override
  String get settingsHelpTitle => 'Hjälp & om';

  @override
  String get settingsHelpSubtitle => 'Frågor, villkor, rapporter';

  @override
  String get settingsSignInSection => 'Inloggning';

  @override
  String get settingsAccountEmail => 'E-postadress';

  @override
  String get settingsAccountPassword => 'Lösenord';

  @override
  String get settingsAccountTwoStep => 'Tvåstegsverifiering';

  @override
  String get settingsYourChoicesSection => 'Dina val';

  @override
  String get settingsYourDataSection => 'Din data';

  @override
  String get settingsDocumentsSection => 'Dokument';

  @override
  String get settingsConsents => 'Samtycken';

  @override
  String get settingsBackupTitle => 'Säkerhetskopia av recept';

  @override
  String get settingsBackupSubtitle => 'Ladda ner eller återställ';

  @override
  String get settingsAppearanceSection => 'Utseende';

  @override
  String get settingsShoppingSection => 'Inköp';

  @override
  String get settingsNotificationSettings => 'Notisinställningar';

  @override
  String get settingsHelpSection => 'Hjälp';

  @override
  String get settingsRulesSection => 'Regler och rapporter';

  @override
  String get settingsMyReportsSubtitle =>
      'Det du har rapporterat och hur det gick';

  @override
  String get settingsVersionLabel => 'Version';

  @override
  String get settingsAdminOnly => 'Admin';

  @override
  String get socialFriendRequestsTitle => 'Vänförfrågningar';

  @override
  String socialPendingRequestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count väntande förfrågningar',
      one: '1 väntande förfrågan',
    );
    return '$_temp0';
  }

  @override
  String get socialSearchNameOrEmailHint => 'Namn eller e-postadress';

  @override
  String get socialShareProfileLink => 'Dela din profillänk';

  @override
  String get messagesNewMessage => 'Nytt meddelande';

  @override
  String get messagesToFriend => 'Till en vän';

  @override
  String get messagesNewGroup => 'Ny gruppkonversation';

  @override
  String get messagesSearchHint => 'Sök i meddelanden';

  @override
  String get messagesArchivedRow => 'Arkiverade samtal';

  @override
  String messagesMoreOptionsFor(String name) {
    return 'Fler val för $name';
  }

  @override
  String get socialMoreOptions => 'Fler val';

  @override
  String get groupShareWithGroupSection => 'Dela med gruppen';

  @override
  String get groupShareRecipeRow => 'Dela ett recept';

  @override
  String get groupShareMenuRow => 'Dela veckomenyn';

  @override
  String get groupShareShoppingListRow => 'Dela en inköpslista';

  @override
  String get groupLeaveTheGroup => 'Lämna gruppen';

  @override
  String get friendProfileShareRecipe => 'Dela ett recept';

  @override
  String friendProfileSharedWithYouRow(String name) {
    return 'Delat med dig av $name';
  }

  @override
  String get friendProfileRemoveFriend => 'Ta bort som vän';

  @override
  String get familyAccountsSection => 'Hushållets konton';

  @override
  String get familyProfilesSection => 'Matgäster';

  @override
  String familyAccountsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count konton',
      one: '1 konto',
    );
    return '$_temp0';
  }

  @override
  String familyProfilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profiler',
      one: '1 profil',
    );
    return '$_temp0';
  }

  @override
  String get familyAddMemberRow => 'Lägg till matgäst';

  @override
  String get familyYou => 'Du';

  @override
  String get familyMealsSection => 'Måltider';

  @override
  String get householdPortionsTitle => 'Portioner som standard';

  @override
  String get householdPortionsSaved => 'Portionerna är sparade';

  @override
  String get familyAllergiesSection => 'Allergier i hushållet';

  @override
  String get allergenIntro => 'Välj vad du vill se status för på recepten.';

  @override
  String get allergenSectionAllergens => 'Allergener';

  @override
  String get allergenSectionDietary => 'Specialkost';

  @override
  String get allergenDisplayCoverageLabel => 'Hur säker märkningen är';

  @override
  String get allergenDisplayUnknownLabel => 'Okänd allergenstatus';

  @override
  String get allergenLabelNote =>
      'Märkningen bygger på ingredienslistan. Kontrollera alltid förpackningen om allergin är allvarlig.';

  @override
  String get allergenSectionMaintenance => 'Underhåll';

  @override
  String get allergenRetagRow => 'Uppdatera märkningen på alla recept';

  @override
  String get allergenResetTitle => 'Återställ till standard?';

  @override
  String get allergenResetBody =>
      'Dina val av allergener och specialkost återställs till standardvalen.';

  @override
  String get notifAllowRow => 'Tillåt notiser';

  @override
  String get notifCategoriesSection => 'Vad du får notiser om';

  @override
  String get notifCategoriesFootnote =>
      'Avstängda kategorier syns fortfarande i notisinkorgen – de skickas bara inte som push.';

  @override
  String get notifDigestSection => 'Sammanfattning';

  @override
  String get notifDigestRow => 'Skicka sammanfattning';

  @override
  String get settingsBlockedPeople => 'Blockerade personer';

  @override
  String trashIntro(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days dagar',
      one: '1 dag',
    );
    return 'Recept raderas för gott efter $_temp0.';
  }

  @override
  String get trashRestoreRecipe => 'Återställ receptet';

  @override
  String get trashRestoreAll => 'Återställ alla';

  @override
  String trashDeleteOneTitle(String name) {
    return 'Radera $name för gott?';
  }

  @override
  String get trashDeleteOneBody => 'Det går inte att ångra.';

  @override
  String get personalTagUngroupedSection => 'Utan grupp';

  @override
  String get personalTagDeleteUnusedAction => 'Radera oanvända taggar';

  @override
  String get personalTagNewTag => 'Ny tagg';

  @override
  String get personalTagNewGroup => 'Ny grupp';

  @override
  String get personalTagManageGroup => 'Hantera gruppen';

  @override
  String get tagDetailGroupLabel => 'Grupp';

  @override
  String get tagDetailRunRulesAll => 'Kör reglerna nu';

  @override
  String get tagDetailShareTag => 'Dela taggen';

  @override
  String get tagDetailDeleteTagAction => 'Radera taggen';

  @override
  String get tagDetailRuleEdit => 'Redigera regeln';

  @override
  String get tagDetailRuleDeleteAction => 'Radera regeln';

  @override
  String get libraryTabAllRecipes => 'Alla recept';

  @override
  String get libraryTabCookbooks => 'Kokböcker';

  @override
  String cookbookShelfCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count kokböcker',
      one: '1 kokbok',
    );
    return '$_temp0';
  }

  @override
  String cookbookRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept',
      one: '1 recept',
    );
    return '$_temp0';
  }

  @override
  String get cookbookMakeFromTag => 'Gör en tagg till kokbok';

  @override
  String get cookbookShelfEmpty =>
      'Du har inga kokböcker än. Välj en av dina taggar, så blir den en kokbok med omslag och egen ordning.';

  @override
  String get cookbookNoTags =>
      'Kokböcker byggs av dina egna taggar. Skapa en tagg först.';

  @override
  String get cookbookManageTags => 'Egna taggar';

  @override
  String get cookbookChooseTagTitle => 'Välj tagg';

  @override
  String get cookbookAllTagsAreCookbooks =>
      'Alla dina taggar är redan kokböcker.';

  @override
  String get cookbookMakeTitle => 'Gör till kokbok';

  @override
  String get cookbookEditTitle => 'Redigera kokbok';

  @override
  String cookbookMakeIntro(String name) {
    return 'Taggen ”$name” blir en kokbok.';
  }

  @override
  String get cookbookDescriptionLabel => 'Beskrivning (valfri)';

  @override
  String get cookbookCoverLabel => 'Omslag';

  @override
  String get cookbookCoverOwnPhoto => 'Eget foto';

  @override
  String get cookbookCoverRecipePhoto => 'Receptfoto';

  @override
  String get cookbookCoverColor => 'Färg';

  @override
  String get cookbookChoosePhoto => 'Välj foto';

  @override
  String get cookbookChooseRecipePhoto => 'Välj receptfoto';

  @override
  String get cookbookNoRecipePhotos => 'Inga recept i kokboken har foto än.';

  @override
  String get cookbookCreate => 'Skapa kokbok';

  @override
  String get cookbookSave => 'Spara';

  @override
  String get cookbookRemove => 'Sluta vara kokbok';

  @override
  String get cookbookRemoveBody =>
      'Taggen och recepten finns kvar. Omslaget, beskrivningen, ordningen och texterna försvinner.';

  @override
  String get cookbookEdit => 'Redigera';

  @override
  String get cookbookAddRecipes => 'Lägg till recept';

  @override
  String get cookbookSortAlphabetical => 'Sortera A–Ö';

  @override
  String get cookbookReorder => 'Ändra ordning';

  @override
  String get cookbookReorderDone => 'Klar';

  @override
  String get cookbookOrderHintAlphabetical =>
      'Sorterad A–Ö. Nya recept hamnar på rätt bokstav.';

  @override
  String get cookbookOrderHintCustom =>
      'Din egen ordning. Nya recept läggs sist.';

  @override
  String get cookbookEmpty => 'Inga recept i kokboken än.';

  @override
  String get cookbookPickerEmpty => 'Alla dina recept finns redan i kokboken.';

  @override
  String cookbookPickerAdd(int count) {
    return 'Lägg till $count';
  }

  @override
  String cookbookAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept tillagda',
      one: '1 recept tillagt',
    );
    return '$_temp0';
  }

  @override
  String get cookbookWriteNote => 'Skriv text';

  @override
  String get cookbookEditNote => 'Ändra text';

  @override
  String get cookbookNoteLabel => 'Text i kokboken';

  @override
  String get cookbookNoteHelper =>
      'Syns bara i den här kokboken, inte i receptet.';

  @override
  String cookbookNoteFrom(String name) {
    return 'Från kokboken ”$name”';
  }

  @override
  String get cookbookLoadFailed => 'Kokböckerna kunde inte laddas.';

  @override
  String get cookbookSaveFailed => 'Kokboken kunde inte sparas. Försök igen.';

  @override
  String get cookbookCoverUploadFailed =>
      'Fotot kunde inte laddas upp. Kontrollera anslutningen och försök igen.';

  @override
  String get cookbookTooManyRecipes => 'En kokbok kan ha högst 1000 recept.';

  @override
  String get cookbookAddRecipesFailed =>
      'Alla recept kunde inte läggas till. Försök igen.';

  @override
  String get cookbookDeleteTagWarning =>
      'Taggen är en kokbok, så kokbokens omslag, beskrivning, ordning och texter försvinner också.';

  @override
  String get cookbookColorSage => 'Salvia';

  @override
  String get cookbookColorGold => 'Guld';

  @override
  String get cookbookColorBrown => 'Brun';

  @override
  String get cookbookColorBrick => 'Tegelröd';

  @override
  String get cookbookColorMoss => 'Mossgrön';

  @override
  String get cookbookColorSand => 'Sand';

  @override
  String a11yMoveRecipeUp(String title) {
    return 'Flytta upp $title';
  }

  @override
  String a11yMoveRecipeDown(String title) {
    return 'Flytta ner $title';
  }

  @override
  String a11yRecipeMoved(String title, int position, int count) {
    return '$title flyttad till plats $position av $count';
  }

  @override
  String a11yCookbookCover(String name) {
    return 'Omslag till $name';
  }

  @override
  String get a11yOpenCookbook => 'Öppna kokbok';

  @override
  String get cookbookLoading => 'Hämtar kokböcker …';

  @override
  String get recipeDeleteConfirmTitle => 'Radera receptet?';

  @override
  String bulkDeleteConfirmTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Radera $count recept?',
      one: 'Radera 1 recept?',
    );
    return '$_temp0';
  }

  @override
  String bulkDeleteConfirmAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Radera $count recept',
      one: 'Radera receptet',
    );
    return '$_temp0';
  }

  @override
  String get commentDeleteConfirmAction => 'Radera kommentaren';

  @override
  String get cookSnapDeleteConfirmTitle => 'Radera bilden?';

  @override
  String get groupDeleteConfirmTitle => 'Radera gruppen?';

  @override
  String friendRemoveConfirmTitle(String name) {
    return 'Ta bort $name som vän?';
  }

  @override
  String get messagingRemoveMemberAction => 'Ta bort ur gruppen';

  @override
  String get messagingLeaveGroupTitle => 'Lämna gruppen?';

  @override
  String get messagingDeleteConversationTitle => 'Radera konversationen?';

  @override
  String get messagingDeleteConversationAction => 'Radera konversationen';

  @override
  String get chatDeleteMessageTitle => 'Radera meddelandet?';

  @override
  String personalTagBulkDeleteAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Radera $count taggar',
      one: 'Radera taggen',
    );
    return '$_temp0';
  }

  @override
  String get groupCancelInvitationTitle => 'Avbryta inbjudan?';

  @override
  String get groupCancelInvitationAction => 'Avbryt inbjudan';

  @override
  String get groupKeepInvitation => 'Behåll inbjudan';

  @override
  String get importHeirloomClearAction => 'Ta bort bilden';

  @override
  String get dataExportClearAction => 'Rensa exporten';

  @override
  String get shoppingDeleteListTitle => 'Radera listan?';

  @override
  String get ratingRemoveAction => 'Ta bort betyget';

  @override
  String get detailPaneExpand => 'Helskärm';

  @override
  String get detailPaneCollapse => 'Visa listan';

  @override
  String get a11yDetailPaneList => 'Lista';

  @override
  String get a11yDetailPaneDetail => 'Vald sida';

  @override
  String get nutritionButton => 'Näringsvärden';

  @override
  String get nutritionSheetTitle => 'Näringsvärden';

  @override
  String get a11yNutritionClose => 'Stäng näringsvärden';

  @override
  String get nutritionBasisPerPortion => 'Per portion';

  @override
  String get nutritionBasisWhole => 'Hela receptet';

  @override
  String get nutritionBasisPhrasePerPortion => 'per portion';

  @override
  String get nutritionBasisPhraseWhole => 'för hela receptet';

  @override
  String get a11yNutritionBasisPerPortion => 'Visar värden per portion';

  @override
  String a11yNutritionBasisWhole(int portions) {
    String _temp0 = intl.Intl.pluralLogic(
      portions,
      locale: localeName,
      other: '$portions portioner',
      one: '1 portion',
    );
    return 'Visar värden för hela receptet, $_temp0';
  }

  @override
  String get a11yNutritionBasisWholeNoPortions =>
      'Visar värden för hela receptet';

  @override
  String get nutritionNoPortions =>
      'Receptet anger inga portioner, så värdena gäller hela receptet.';

  @override
  String get nutritionEnergy => 'Energi';

  @override
  String get nutritionFat => 'Fett';

  @override
  String get nutritionSaturatedFat => 'varav mättat fett';

  @override
  String get nutritionCarbs => 'Kolhydrater';

  @override
  String get nutritionSugars => 'varav sockerarter';

  @override
  String get nutritionFiber => 'Fiber';

  @override
  String get nutritionProtein => 'Protein';

  @override
  String get nutritionSalt => 'Salt';

  @override
  String get nutritionStripKcal => 'kcal';

  @override
  String get nutritionStripProtein => 'protein';

  @override
  String get nutritionStripCarbs => 'kolhydr.';

  @override
  String get nutritionStripFat => 'fett';

  @override
  String nutritionValueKcal(String value) {
    return '$value kcal';
  }

  @override
  String nutritionValueGrams(String value) {
    return '$value g';
  }

  @override
  String a11yNutritionSpokenKcal(String value) {
    return '$value kilokalorier';
  }

  @override
  String a11yNutritionSpokenGrams(String value) {
    return '$value gram';
  }

  @override
  String a11yNutritionStripKcal(String value, String basis) {
    return 'Energi $value kilokalorier $basis';
  }

  @override
  String a11yNutritionStripGrams(String name, String value, String basis) {
    return '$name $value gram $basis';
  }

  @override
  String nutritionCoverage(int counted, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total ingredienser',
      one: '1 ingrediens',
    );
    return 'Beräknat på $counted av $_temp0';
  }

  @override
  String get nutritionMissingHeading => 'Ingredienser som inte räknats med';

  @override
  String get nutritionReasonNoMatch => 'finns inte i Livsmedelsverkets tabell';

  @override
  String get nutritionReasonNoAmount =>
      'mängden går inte att räkna om till gram';

  @override
  String nutritionMissingLine(String name, String reason) {
    return '$name: $reason';
  }

  @override
  String get nutritionPickFood => 'Välj livsmedel';

  @override
  String a11yNutritionPickFoodFor(String name) {
    return 'Välj livsmedel för $name';
  }

  @override
  String get nutritionIngredientsHeading => 'Ingredienser';

  @override
  String nutritionCountedAs(String food) {
    return 'Räknat som $food';
  }

  @override
  String get nutritionChange => 'Ändra';

  @override
  String a11yNutritionChangeFoodFor(String name) {
    return 'Ändra livsmedel för $name';
  }

  @override
  String nutritionSource(String version) {
    return 'Källa: Livsmedelsverkets livsmedelsdatabas, version $version (CC BY 4.0). Värdena är uppskattningar.';
  }

  @override
  String get nutritionLoadFailed => 'Näringsvärdena kunde inte räknas ut.';

  @override
  String nutritionPickerTitle(String name) {
    return 'Välj livsmedel för $name';
  }

  @override
  String get nutritionPickerSearchLabel => 'Sök livsmedel';

  @override
  String get nutritionPickerHint =>
      'Valet gäller alla recept, för hela hushållet.';

  @override
  String nutritionPickerResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count träffar',
      one: '1 träff',
    );
    return '$_temp0';
  }

  @override
  String get nutritionPickerNoResults => 'Inga livsmedel hittades';

  @override
  String get nutritionPickerSaved => 'Sparat för hela hushållet';

  @override
  String get nutritionPickerSaveFailed =>
      'Det gick inte att spara valet. Försök igen.';

  @override
  String get nutritionEstimatedBadge => 'Uppskattad';

  @override
  String get a11yNutritionEstimatedBadge => 'Uppskattad mängd';

  @override
  String nutritionCoverageWithEstimates(int counted, int total, int estimated) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total ingredienser',
      one: '1 ingrediens',
    );
    return 'Beräknat på $counted av $_temp0, varav $estimated med uppskattad mängd';
  }

  @override
  String get nutritionEnterAmount => 'Ange mängd';

  @override
  String a11yNutritionEnterAmountFor(String name) {
    return 'Ange mängd för $name';
  }

  @override
  String a11yNutritionChangeAmountFor(String name) {
    return 'Ändra mängd för $name';
  }

  @override
  String nutritionAmountSheetTitle(String name) {
    return 'Mängd för $name';
  }

  @override
  String get nutritionAmountFieldLabel => 'Mängd';

  @override
  String get nutritionAmountUnitLabel => 'Enhet';

  @override
  String get nutritionAmountInvalid => 'Ange ett tal större än 0.';

  @override
  String get nutritionAmountRemove => 'Ta bort mängd';

  @override
  String nutritionAmountScopeTitle(String amount, String name) {
    return 'Gäller $amount $name bara det här receptet?';
  }

  @override
  String nutritionAmountScopeBody(String name) {
    return 'Du kan också använda mängden i alla recept där $name saknar mängd.';
  }

  @override
  String get nutritionAmountScopeRecipe => 'Bara det här receptet';

  @override
  String get nutritionAmountScopeAll => 'Alla recept';

  @override
  String get nutritionAmountSaved => 'Mängden sparades';

  @override
  String get nutritionAmountRemoved => 'Mängden togs bort';

  @override
  String get nutritionAmountSaveFailed =>
      'Mängden kunde inte sparas. Försök igen.';

  @override
  String get nutritionAmountFull =>
      'Hushållets sparade mängder är fulla. Ta bort någon för att spara en ny.';

  @override
  String nutritionCountedAsOwn(String food) {
    return 'Räknat som $food, din mängd';
  }

  @override
  String get nutritionPickerClear => 'Ta bort hushållets val';

  @override
  String get a11yNutritionPickerClose => 'Stäng livsmedelsväljaren';

  @override
  String get settingsNutritionStripTitle => 'Visa näringsremsa på recept';

  @override
  String get settingsNutritionStripSubtitle =>
      'Visar kalorier, protein, kolhydrater och fett under receptets namn. Hela tabellen finns alltid under Näringsvärden.';

  @override
  String get licensesLivsmedelsverketHeading =>
      'Livsmedelsverkets livsmedelsdatabas';

  @override
  String get licensesLivsmedelsverketBody =>
      'Näringsvärdena i Butlery räknas ur Livsmedelsverkets livsmedelsdatabas, som är licensierad under Creative Commons Attribution 4.0 (CC BY 4.0, creativecommons.org/licenses/by/4.0). Uppgifterna har räknats om till de mängder som receptet anger. Källa: Livsmedelsverket, livsmedelsverket.se.';

  @override
  String get nutritionLoading => 'Räknar ut näringsvärden …';

  @override
  String get settingsRecipesSection => 'Recept';

  @override
  String shoppingListsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count listor',
      one: '1 lista',
    );
    return '$_temp0';
  }

  @override
  String get shoppingNewShoppingList => 'Ny inköpslista';

  @override
  String get a11yShoppingPickList => 'Välj lista';

  @override
  String get guestBandLabel => 'Du provar som gäst';

  @override
  String get guestCreateAccount => 'Skapa konto';

  @override
  String get guestNotNow => 'Inte nu';

  @override
  String get guestAllergyTitle => 'Har någon i hushållet allergier?';

  @override
  String get guestAllergyBody =>
      'Ställ in dem så filtrerar Butlery bort dem ur recept och veckomeny. Kontrollera ändå alltid förpackningen.';

  @override
  String get guestAllergyAction => 'Ställ in';

  @override
  String get guestAllergyDismiss => 'Stäng';

  @override
  String get guestSheetShareTitle => 'Skapa konto för att dela';

  @override
  String get guestSheetShareBody =>
      'Delning kräver ett konto, så att den du delar med ser vem du är. Allt du gjort som gäst följer med.';

  @override
  String get guestSheetTogetherTitle =>
      'Skapa konto för att göra saker tillsammans';

  @override
  String get guestSheetTogetherBody =>
      'Vänner, grupper, meddelanden och hushåll kräver ett konto, så att andra ser vem du är. Allt du gjort som gäst följer med.';

  @override
  String get guestSheetImportLimitTitle => 'Du har använt dina tre importer';

  @override
  String get guestSheetImportLimitBody =>
      'Skapa ett gratis konto för att importera fler recept från länkar och foton. Recepten du redan importerat följer med.';

  @override
  String get guestRequiresAccount => 'Kräver konto';

  @override
  String get guestAccountValue => 'Gäst';

  @override
  String guestImportsLeft(int count) {
    return '$count av 3 importer kvar som gäst';
  }

  @override
  String get guestCountsAsImport => 'Räknas som en import';

  @override
  String get llmGuestImportLimit => 'Du har använt dina tre importer';

  @override
  String get llmGuestCapacity =>
      'Gästimporter är tillfälligt slut. Skapa ett gratis konto för att importera.';

  @override
  String get guestTryWithoutAccount => 'Prova utan konto';

  @override
  String get guestStartBody =>
      'Samma frågor som för ett nytt konto. Det du sparar som gäst följer med om du skapar ett konto senare.';

  @override
  String get guestStartYearNote => 'Vi sparar bara året, inte hela datumet.';

  @override
  String get guestStartBackToSignIn => 'Tillbaka till inloggningen';

  @override
  String get guestStartPreparing => 'Gör i ordning ditt gästkonto';

  @override
  String get guestStartFailed => 'Gästkontot kunde inte skapas';

  @override
  String get guestUpgradeBody =>
      'Allt du gjort som gäst följer med till kontot.';

  @override
  String get guestUpgradeDone =>
      'Kontot är skapat. Ett e-postmeddelande med en länk för att bekräfta adressen är skickat.';

  @override
  String get guestUpgradeDoneProvider =>
      'Kontot är skapat. Allt du gjort som gäst finns kvar.';

  @override
  String get guestUpgradeFinishFailed =>
      'Kontot är skapat men kunde inte göras klart. Försök igen.';

  @override
  String get guestSignInInstead => 'Logga in i stället';

  @override
  String get guestSignInInsteadTitle => 'Logga in i stället?';

  @override
  String get guestSignInInsteadBody =>
      'Ditt gästkonto och allt du sparat raderas. Det du gjort som gäst följer inte med till kontot du loggar in på.';

  @override
  String get guestSignInInsteadConfirm => 'Radera och logga in';

  @override
  String get guestLogoutTitle => 'Logga ut som gäst?';

  @override
  String get guestLogoutBody => 'Ditt gästkonto och allt du sparat raderas.';

  @override
  String get guestLogoutConfirm => 'Logga ut och radera';

  @override
  String get guestErasing => 'Raderar gästkontot';

  @override
  String get guestEraseFailed =>
      'Gästkontot kunde inte raderas. Du är fortfarande inloggad.';

  @override
  String get guestDeleteTitle => 'Radera gästkontot?';

  @override
  String get guestDeleteConfirm => 'Radera';

  @override
  String get motivationRemovedCopyright =>
      'Innehållet var kopierat från någon annan utan tillstånd eller källa, vilket bryter mot reglerna om upphovsrätt.';

  @override
  String get motivationRemovedSpam =>
      'Innehållet var reklam eller spam, vilket inte är tillåtet i Butlery.';

  @override
  String get motivationRemovedAbuse =>
      'Innehållet var kränkande eller olämpligt, vilket bryter mot gemenskapsreglerna.';

  @override
  String get motivationRemovedHarassment =>
      'Innehållet trakasserade en annan person, vilket bryter mot gemenskapsreglerna.';

  @override
  String get motivationRemovedOther =>
      'Innehållet bröt mot gemenskapsreglerna.';

  @override
  String get motivationHiddenRules =>
      'Profilen bröt mot gemenskapsreglerna och visas inte längre för andra.';

  @override
  String get motivationHiddenSpam =>
      'Profilen användes för reklam eller spam och visas inte längre för andra.';

  @override
  String get motivationKeptNoBreach =>
      'Vi hittade inget brott mot gemenskapsreglerna, så innehållet ligger kvar.';

  @override
  String get motivationKeptAlreadyGone =>
      'Innehållet var redan borttaget när vi granskade anmälan.';

  @override
  String get motivationKeptUnclear =>
      'Vi kunde inte bedöma anmälan med det underlag vi hade, så innehållet ligger kvar.';

  @override
  String get motivationMisattributionNameRemoved =>
      'Ditt namn har tagits bort från rätten.';

  @override
  String get myContentDecisionsTitle => 'Beslut om mitt innehåll';

  @override
  String get settingsMyContentDecisionsSubtitle => 'Beslut om det du har delat';

  @override
  String get myContentDecisionsEmpty =>
      'Det finns inga beslut om ditt innehåll.';

  @override
  String get myContentDecisionsLoadFailed => 'Kunde inte hämta besluten';

  @override
  String get decisionDetailReporterTitle => 'Din anmälan';

  @override
  String get decisionDetailOwnerTitle => 'Beslut om ditt innehåll';

  @override
  String get decisionDetailLoadFailed => 'Kunde inte hämta beslutet';

  @override
  String get decisionDetailNotFound => 'Vi hittar inte det här beslutet.';

  @override
  String decisionSubjectRecipe(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Ditt recept',
        'other': 'Ett recept',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionSubjectComment(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Din kommentar',
        'other': 'En kommentar',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionSubjectMessage(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Ditt meddelande',
        'other': 'Ett meddelande',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionSubjectProfile(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Din profil',
        'other': 'En profil',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionSubjectCookSnap(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Din bild',
        'other': 'En bild',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionSubjectGroup(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Din grupp',
        'other': 'En grupp',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionSubjectMenuDish(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Din maträtt',
        'other': 'En maträtt',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionReporterLine(String subject, String reason) {
    return '$subject för $reason';
  }

  @override
  String decisionOwnerReportedFor(String reason) {
    return 'Anmält för $reason';
  }

  @override
  String get decisionYouReportedLabel => 'Du anmälde';

  @override
  String get decisionConcernsLabel => 'Det gäller';

  @override
  String decisionReportedOnLabel(String date) {
    return 'Anmäld $date';
  }

  @override
  String get decisionHeadlineContentRemoved => 'Innehållet har tagits bort';

  @override
  String get decisionHeadlineProfileHidden => 'Profilen har dolts för andra';

  @override
  String get decisionHeadlineNoAction => 'Innehållet ligger kvar';

  @override
  String decisionOutcomeSentence(String headline) {
    return '$headline.';
  }

  @override
  String get decisionStatusAppealed => 'Överklagad';

  @override
  String get decisionStatusDecided => 'Avgjord';

  @override
  String get appealPromptTitle => 'Håller du inte med?';

  @override
  String appealPromptBody(String date) {
    return 'Du kan överklaga en gång, senast $date.';
  }

  @override
  String get appealWindowClosedInfo => 'Tiden för att överklaga har gått ut.';

  @override
  String appealYourLabel(String date) {
    return 'Din överklagan · $date';
  }

  @override
  String get appealUnderReview =>
      'Beslutet granskas igen. Du får ett nytt besked här och en notis.';

  @override
  String appealAnswerLabel(String date) {
    return 'Svar på överklagan · $date';
  }

  @override
  String get appealAnswerUpheldHeadline => 'Beslutet står kvar';

  @override
  String get appealAnswerUpheldBody =>
      'Vi har granskat beslutet igen och det står kvar.';

  @override
  String get appealAnswerReversedHeadline => 'Beslutet ändras';

  @override
  String get appealAnswerReversedBody =>
      'Vi har granskat beslutet igen och ändrar det.';

  @override
  String get appealAnswerReversedOwnerRemoved =>
      'Innehållet kunde inte återställas, men du får lägga upp det igen.';

  @override
  String get appealAnswerFinal => 'Svaret är slutgiltigt i appen.';

  @override
  String get appealFormTitle => 'Överklaga beslutet';

  @override
  String get appealFormIntro =>
      'Beslutet granskas igen och du får ett nytt besked i appen.';

  @override
  String get appealFormHint => 'Skriv din motivering här';

  @override
  String get appealFormOnceReporter =>
      'Du kan bara överklaga en gång. Den som äger innehållet får inte se det du skriver.';

  @override
  String get appealFormOnceOwner =>
      'Du kan bara överklaga en gång. Den som anmälde får inte se det du skriver.';

  @override
  String get appealSubmit => 'Skicka överklagan';

  @override
  String get appealSent => 'Överklagan skickad';

  @override
  String appealCounter(int count, int max) {
    return '$count / $max';
  }

  @override
  String get appealErrorWindowClosed => 'Tiden för att överklaga har gått ut.';

  @override
  String get appealErrorExists => 'Du har redan överklagat det här beslutet.';

  @override
  String get appealErrorNotAllowed => 'Du kan inte överklaga det här beslutet.';

  @override
  String get appealErrorNotFound => 'Vi hittar inget beslut att överklaga.';

  @override
  String appealErrorInvalidText(int min, int max) {
    return 'Skriv minst $min och högst $max tecken.';
  }

  @override
  String get appealErrorGeneric =>
      'Överklagan kunde inte skickas. Försök igen.';

  @override
  String moderatorTabReports(int count) {
    return 'Rapporter ($count)';
  }

  @override
  String moderatorTabAppeals(int count) {
    return 'Överklaganden ($count)';
  }

  @override
  String get moderatorCloseSheetTitle => 'Stäng och meddela';

  @override
  String moderatorCloseSheetDecision(String decision) {
    return 'Beslut: $decision';
  }

  @override
  String get moderatorCloseChoose => 'Välj motivering';

  @override
  String get moderatorClosePreviewTitle => 'Så ser de det';

  @override
  String moderatorClosePreviewReporter(String headline) {
    return 'Anmälaren: ”$headline” och motiveringen.';
  }

  @override
  String moderatorClosePreviewOwner(String headline) {
    return 'Ägaren: ”$headline” och motiveringen. Ingen av dem ser den andras namn.';
  }

  @override
  String get moderatorClosePreviewOwnerNone =>
      'Ägaren får inget besked när innehållet ligger kvar.';

  @override
  String get moderatorAppealsEmpty => 'Inga öppna överklaganden just nu.';

  @override
  String get moderatorAppealsLoadFailed => 'Kunde inte hämta överklaganden';

  @override
  String get moderatorAppealFromReporter => 'Överklagan · från anmälaren';

  @override
  String get moderatorAppealFromOwner => 'Överklagan · från ägaren';

  @override
  String moderatorAppealDecisionLine(String date, String decision) {
    return 'Ditt beslut $date: $decision';
  }

  @override
  String moderatorAppealReceived(String date) {
    return 'Inkom $date';
  }

  @override
  String get moderatorAppealAnswerButton => 'Svara';

  @override
  String get moderatorAnswerTitle => 'Svara på överklagan';

  @override
  String get moderatorAnswerNoteTitle => 'Det går inte att ta tillbaka';

  @override
  String get moderatorAnswerNoteBody =>
      'Det raderades när du tog bort det. Ägaren får veta att beslutet ändrats och att hen kan lägga upp det igen.';

  @override
  String get moderatorAnswerSubmit => 'Skicka svar';

  @override
  String get moderatorAnswerSent =>
      'Svaret är skickat. Personen har fått en notis.';

  @override
  String get moderatorAnswerFailed => 'Svaret kunde inte skickas.';

  @override
  String get moderatorAnswerUnchanged => 'Överklagan är kvar i listan.';

  @override
  String get moderatorAppealAlreadyAnswered => 'Överklagan är redan besvarad.';

  @override
  String get loadingMyContentDecisions => 'Hämtar besluten …';

  @override
  String get listInvitationsSection => 'Inbjudningar';

  @override
  String listInvitationMetaEdit(String name) {
    return '$name bjuder in dig till sin delade lista. Du kan redigera den.';
  }

  @override
  String listInvitationMetaView(String name) {
    return '$name bjuder in dig till sin delade lista. Du kan se den.';
  }

  @override
  String get listInvitationUnknownSender => 'Någon';

  @override
  String get listInvitationDecline => 'Avböj';

  @override
  String get listInvitationJoin => 'Gå med';

  @override
  String get listInvitationMoreActions => 'Fler val för inbjudan';

  @override
  String listInvitationBlockSender(String name) {
    return 'Blockera $name';
  }

  @override
  String listInvitationJoined(String listName) {
    return 'Du är med i $listName';
  }

  @override
  String get listInvitationDeclinedNotice => 'Inbjudan avböjd';

  @override
  String get listInvitationNoLongerValid => 'Inbjudan gäller inte längre';

  @override
  String get listInvitationActionFailed =>
      'Det gick inte att svara på inbjudan';

  @override
  String get listInviteHeading => 'Bjud in vänner';

  @override
  String listInviteButtonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count vänner',
      one: '1 vän',
    );
    return 'Bjud in $_temp0';
  }

  @override
  String listInviteSentOne(String name) {
    return 'Inbjudan skickad. $name kommer med när hen har tackat ja.';
  }

  @override
  String listInviteSentMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count inbjudningar skickade',
      one: '1 inbjudan skickad',
    );
    return '$_temp0. De kommer med när de har tackat ja.';
  }

  @override
  String listInviteNotInvited(String names) {
    return '$names kunde inte bjudas in just nu.';
  }

  @override
  String get listInviteFailed => 'Det gick inte att skicka inbjudan';

  @override
  String get listInvitePendingHeading => 'Inbjudna';

  @override
  String get listInviteNotAnsweredYet => 'Har inte svarat än';

  @override
  String get listInviteStatusPending => 'Väntar';

  @override
  String get listInviteRevoke => 'Ta tillbaka inbjudan';

  @override
  String get listInviteRevoked => 'Inbjudan tillbakatagen';

  @override
  String get listInviteRevokeFailed => 'Det gick inte att ta tillbaka inbjudan';

  @override
  String get listInviteAlreadyInvited => 'Redan inbjuden';

  @override
  String get listInviteConvertedInvited =>
      'Listan är delad. Vännerna kommer med när de har tackat ja.';

  @override
  String listInviteConvertedSomeNotInvited(String names) {
    return 'Listan är delad, men $names kunde inte bjudas in just nu.';
  }

  @override
  String get listInviteShareSent =>
      'Inbjudan skickad. Mottagarna kommer med när de har tackat ja.';

  @override
  String get authContinueWithGoogle => 'Fortsätt med Google';

  @override
  String get authContinueWithApple => 'Fortsätt med Apple';

  @override
  String authProviderFailed(String provider) {
    return 'Inloggningen med $provider gick inte. Försök igen.';
  }

  @override
  String get authProviderAccountExists =>
      'Det finns redan ett konto med den e-postadressen. Logga in med e-post och lösenord.';

  @override
  String authProviderWrongAccount(String provider) {
    return 'Det var ett annat $provider-konto än det här kontot använder. Välj samma konto igen.';
  }

  @override
  String get providerTermsTitle => 'Välkommen till Butlery';

  @override
  String get providerTermsSubtitle => 'Ett steg kvar innan kontot skapas.';

  @override
  String get providerTermsNameHelp =>
      'Andra i dina grupper och delade listor ser ditt namn. Du kan ändra det senare.';

  @override
  String get providerTermsCancelAndDelete => 'Avbryt och ta bort kontot';

  @override
  String get providerTermsSaveFailed =>
      'Kontot kunde inte skapas. Försök igen.';

  @override
  String get providerTermsNoEmail =>
      'Kontot kunde inte skapas, för ingen e-postadress kom med från Google eller Apple. Försök igen.';

  @override
  String get providerLinkTitle => 'Koppla ihop';

  @override
  String providerLinkBody(String email, String provider) {
    return 'Det finns redan ett Butlery-konto för $email. Ange ditt Butlery-lösenord en gång så kopplas $provider till kontot.';
  }

  @override
  String get providerLinkSubmit => 'Koppla ihop';

  @override
  String providerLinkFailed(String provider) {
    return '$provider kunde inte kopplas till kontot. Försök igen med Fortsätt med $provider.';
  }

  @override
  String get mfaBackupCodeProviderRejected =>
      'Reservkoden stämmer inte. En använd kod går inte att använda igen.';

  @override
  String mfaBackupCodeProviderSupport(String provider) {
    return 'Med $provider på den här enheten kan reservkoden inte kontrolleras här. Skriv till oss så hjälper vi dig in på kontot.';
  }

  @override
  String get mfaBackupCodeContactSupport => 'Skriv till support';

  @override
  String get mfaBackupCodeSupportSubject => 'Inloggning med reservkod';

  @override
  String accountSecurityEmailProviderReauth(String provider) {
    return 'Du bekräftar att det är du med $provider innan adressen byts.';
  }

  @override
  String mfaBackupCodeRecoveredSignInAgain(String provider) {
    return 'Reservkoden fungerade, så tvåstegsverifieringen är avstängd. Inloggningen blev inte klar: logga in med $provider igen för att komma in.';
  }

  @override
  String get mfaBackupCodeRecoveredSignInAgainPassword =>
      'Reservkoden fungerade, så tvåstegsverifieringen är avstängd. Inloggningen blev inte klar: logga in igen för att komma in.';

  @override
  String mfaBackupCodeSignInAgainWith(String provider) {
    return 'Logga in med $provider';
  }

  @override
  String get mfaBackupCodeSignInAgain => 'Logga in igen';

  @override
  String mfaBackupCodeNoEmail(String address) {
    return 'E-postappen gick inte att öppna. Skriv till $address.';
  }

  @override
  String get accountSecurityEmailCannotConfirmHere =>
      'Bytet går inte att bekräfta på den här enheten, eftersom kontots inloggning inte finns här. Byt adressen på en enhet där du kan logga in på kontot.';

  @override
  String get settingsSignInMethodsTitle => 'Inloggningssätt';

  @override
  String get signInMethodsEmailName => 'E-post';

  @override
  String get signInMethodsPassword => 'E-post och lösenord';

  @override
  String get signInMethodsOn => 'Påslaget';

  @override
  String get signInMethodsNotLinked => 'Inte kopplat';

  @override
  String get signInMethodsLink => 'Koppla';

  @override
  String get signInMethodsUnlink => 'Koppla från';

  @override
  String get signInMethodsSetPassword => 'Sätt lösenord';

  @override
  String signInMethodsSetPasswordBody(String email) {
    return 'Lösenordet gäller för $email. Du kan då också logga in med e-post och lösenord.';
  }

  @override
  String get signInMethodsLastOne =>
      'Det sista inloggningssättet kan inte tas bort. Du behöver alltid minst ett sätt att logga in.';

  @override
  String signInMethodsOnlyProvider(String provider) {
    return '$provider är det sätt du loggar in med just nu och kan inte kopplas från. Sätt ett lösenord eller koppla ett annat sätt först.';
  }

  @override
  String get signInMethodsNoAddress =>
      'Ett lösenord går inte att sätta, eftersom kontot saknar e-postadress.';

  @override
  String signInMethodsUnlinkTitle(String provider) {
    return 'Koppla från $provider?';
  }

  @override
  String signInMethodsUnlinkBody(String provider) {
    return 'Du kan inte längre logga in med $provider.';
  }

  @override
  String get signInMethodsInsteadPassword =>
      'Du loggar in med e-post och lösenord i stället.';

  @override
  String signInMethodsInsteadProvider(String provider) {
    return 'Du loggar in med $provider i stället.';
  }

  @override
  String get signInMethodsUnlinkAppleAsks =>
      'Apple visar sin ruta en gång till, så att vi kan be Apple ta bort kopplingen.';

  @override
  String get signInMethodsUnlinkAppleYourself =>
      'Butlery finns kvar under Logga in med Apple i ditt Apple-konto tills du tar bort det där.';

  @override
  String signInMethodsLinked(String provider) {
    return '$provider är kopplat till kontot.';
  }

  @override
  String signInMethodsUnlinked(String provider) {
    return '$provider är frånkopplat.';
  }

  @override
  String get signInMethodsPasswordSet =>
      'Lösenordet är satt. Du kan nu logga in med e-post och lösenord.';

  @override
  String signInMethodsAlreadyUsed(String provider) {
    return 'Det $provider-kontot används redan av ett annat Butlery-konto.';
  }

  @override
  String signInMethodsAlreadyLinked(String provider) {
    return '$provider är redan kopplat till kontot.';
  }

  @override
  String signInMethodsLinkFailed(String provider) {
    return '$provider kunde inte kopplas till kontot. Försök igen.';
  }

  @override
  String signInMethodsUnlinkFailed(String provider) {
    return '$provider kunde inte kopplas från. Inloggningssättet är kvar.';
  }

  @override
  String get signInMethodsPasswordFailed =>
      'Lösenordet kunde inte sättas. Försök igen.';

  @override
  String familyRatingHouseholdPill(String value) {
    return 'Hushåll $value';
  }

  @override
  String get ingredientSearchHeading => 'Vad kan jag laga?';

  @override
  String cookingModeIngredientRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rader',
      one: '1 rad',
    );
    return '$_temp0';
  }

  @override
  String get cookingModeSwapHint => 'Håll på en rad för att byta ingrediens';

  @override
  String cookingModeNextStepPreview(String step) {
    return 'Nästa: $step';
  }

  @override
  String get consentTermsHeading => 'Villkor för att appen finns';

  @override
  String get consentEssentialTitle => 'Nödvändig drift';

  @override
  String get consentEssentialBody =>
      'Inloggning, dina recept, synk mellan dina enheter.';

  @override
  String get consentDataProcessingBody =>
      'Att spara det du skriver in, så att det finns kvar i morgon.';

  @override
  String get consentRequiredNoteBefore =>
      'De här går inte att stänga av – utan dem finns ingen tjänst att säga ja eller nej till. Vill du bort helt är vägen ';

  @override
  String get consentRequiredNoteBold => 'radera kontot';

  @override
  String get consentRequiredNoteAfter => ', inte ett reglage här.';

  @override
  String get consentYourChoices => 'Dina val';

  @override
  String get consentMarketing => 'Utskick';

  @override
  String get consentMarketingDescription =>
      'Nyheter om appen. Aldrig andras erbjudanden.';

  @override
  String get consentSocial => 'Socialt';

  @override
  String get consentSocialDescription => 'Vänner, delade listor, kommentarer.';

  @override
  String consentSavedVersion(String version, String date, String device) {
    return 'Sparat version $version · $date$device. Vi behåller versionen för att kunna visa vad du sa ja till, inte bara att du gjorde det.';
  }

  @override
  String get consentHistory => 'Historik';

  @override
  String get consentHistorySubtitle => 'Vad du sagt ja och nej till, och när';

  @override
  String get consentHistoryEmpty => 'Inga sparade val ännu.';

  @override
  String get consentRevokeAllOptional => 'Återkalla allt valfritt';

  @override
  String get consentHistoryNoneOn => 'Inga valfria samtycken';

  @override
  String get dataExportPageTitle => 'Hämta ut dina uppgifter';

  @override
  String get dataExportHeadline => 'Allt du lagt in, i en fil';

  @override
  String get dataExportIncludesRecipesComments =>
      'Dina recept, kommentarer och betyg';

  @override
  String get dataExportIncludesSocial =>
      'Vänner, meddelanden och aktivitetshistorik';

  @override
  String get dataExportFileTitle => 'Din export (JSON)';

  @override
  String pendingDeletionNoticeTitle(String date) {
    return 'Kontot raderas $date';
  }

  @override
  String get pendingDeletionNoticeBody =>
      'Tills dess finns allt kvar, och du kan ångra raderingen. Efter det går inget att återskapa.';

  @override
  String pendingDeletionListHeading(String date) {
    return 'Det här raderas den $date';
  }

  @override
  String get pendingDeletionItemRecipes => 'Recept, menyer och listor';

  @override
  String get pendingDeletionItemRecipesNote => 'allt du skapat';

  @override
  String get pendingDeletionItemRatings => 'Betyg, kommentarer och cook snaps';

  @override
  String get pendingDeletionItemRatingsNote => 'även i andras recept';

  @override
  String get pendingDeletionItemHousehold => 'Hushåll och delningar';

  @override
  String get pendingDeletionItemHouseholdNote =>
      'du lyfts ur, listorna finns kvar hos de andra';

  @override
  String get pendingDeletionItemCache => 'Lokal cache';

  @override
  String get pendingDeletionItemCacheNote => 'rensas först av allt';

  @override
  String get legalLinkTerms => 'Villkoren';

  @override
  String get legalLinkPrivacy => 'Integritet';

  @override
  String get legalLinkGuidelines => 'Riktlinjer';

  @override
  String get legalLinkContact => 'Kontakt';

  @override
  String get legalCommunityGuidelinesTitle => 'Så gör vi mot varandra';

  @override
  String get accountSecurityEmailNow => 'Nu: ';

  @override
  String get accountSecurityRepeatNewPassword => 'Upprepa nytt lösenord';

  @override
  String get decisionOutcomeLabel => 'Utfall:';

  @override
  String get decisionAppealLink => 'Jag vill överklaga';

  @override
  String get myReportsStatusActioned => 'Åtgärdad';

  @override
  String get myContentDecisionsIntro =>
      'Beslut om sådant du lagt upp. Varje beslut kan överklagas en gång.';

  @override
  String get myReportsIntro =>
      'Det du anmält och vad som hänt sedan. Vi berättar utfallet, också när det gick emot dig.';

  @override
  String get appealFormQuestion => 'Varför tycker du att beslutet är fel?';

  @override
  String trashRowDeleted(String when, String left) {
    return 'Raderad $when · $left';
  }

  @override
  String get trashDeletedToday => 'i dag';

  @override
  String trashUrgentLeft(String left, String day) {
    return '$left – raderas för gott på $day';
  }

  @override
  String trashUrgentToday(String left) {
    return '$left – raderas för gott i dag';
  }

  @override
  String get licensesIntro =>
      'Det Butlery bygger på, och villkoren det följer med.';

  @override
  String get mfaOnTitle => 'Påslagen';

  @override
  String get mfaOffTitle => 'Inte påslagen';

  @override
  String get mfaLostPhoneTitle => 'Om telefonen är borta';

  @override
  String get mfaLostPhoneBody =>
      'När du slog på skyddet fick du tio engångskoder att skriva ned. Med en av dem kommer du in även utan telefonen.';

  @override
  String get mfaRemoveLink => 'Ta bort';

  @override
  String groupSharedRecipesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'recept',
      one: 'recept',
    );
    return '$_temp0';
  }

  @override
  String groupSharedMenusLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'menyer',
      one: 'meny',
    );
    return '$_temp0';
  }

  @override
  String groupSharedListsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'inköpslistor',
      one: 'inköpslista',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitedLabel => 'Inbjuden';

  @override
  String get groupInviteLink => '+ Bjud in';

  @override
  String get groupMembersHeading => 'Medlemmar';

  @override
  String get groupShareSheetButton => 'Dela recept, meny eller lista';

  @override
  String get messagingNewGroupChat => 'Ny gruppchatt';

  @override
  String get profileChangePhoto => 'Ändra bild';

  @override
  String get profileDisplayNameAvailable => 'Ledigt';

  @override
  String get sharedSaveAction => 'Spara';

  @override
  String get sharedSavedState => 'Sparad';

  @override
  String get sharedReceiveCanRead => 'Kan läsa';

  @override
  String get sharedReceiveCanEdit => 'Kan redigera';

  @override
  String get sharedReceiveAccept => 'Acceptera';

  @override
  String get sharedReceiveView => 'Visa receptet';

  @override
  String sharedFromNameAgo(String name, String time) {
    return 'från $name · $time';
  }

  @override
  String sharedSharedAgo(String time) {
    return 'delad $time';
  }

  @override
  String get sharedNewMark => 'ny';

  @override
  String sharedFromHeading(String name) {
    return 'Från $name';
  }

  @override
  String sharedFromSummary(int count, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept',
      one: '$count recept',
    );
    return '$_temp0 · senast $time';
  }

  @override
  String socialFriendsSection(int count) {
    return 'Vänner · $count';
  }

  @override
  String get socialRequestsSelect => 'Välj';

  @override
  String socialRequestsIncomingSection(int count) {
    return 'Inkommande · $count';
  }

  @override
  String socialRequestsSentSection(int count) {
    return 'Skickade · $count';
  }

  @override
  String get messagingAboutConversation => 'Om samtalet';

  @override
  String messagingConversationSubline(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count med i samtalet',
      one: '1 med i samtalet',
    );
    return '$name · $_temp0';
  }

  @override
  String get messagingConversationNameRow => 'Samtalets namn';

  @override
  String get messagingAddSomeoneRow => 'Lägg till någon';

  @override
  String get messagingInConversationSection => 'Med i samtalet';

  @override
  String get messagingMemberYou => 'du';

  @override
  String messagingRemoveFromConversationTitle(String name) {
    return 'Ta bort $name ur samtalet?';
  }

  @override
  String messagingRemoveFromConversationBody(String name) {
    return '$name slutar se nya meddelanden. Det som redan skrivits ligger kvar, och kontot påverkas inte. Du kan bjuda in personen igen.';
  }

  @override
  String get messagingLeaveConversationRow => 'Lämna samtalet';

  @override
  String get messagingLeaveConversationSub =>
      'Du slutar se nya meddelanden. Det du skrivit ligger kvar.';

  @override
  String recipeRowMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String publicProfileRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count publika recept',
      one: '1 publikt recept',
    );
    return '$_temp0';
  }

  @override
  String get friendProfileBetweenYou => 'Mellan er';

  @override
  String get friendProfileSharedWithYouSub => 'Ligger under Delat med mig';

  @override
  String get friendProfilePublicRecipesSub =>
      'Synliga för alla, inte bara för dig';

  @override
  String get friendProfileShareLinkSub =>
      'Visar den publika sidan, inget ni delat';

  @override
  String profileFriendsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'vänner',
      one: 'vän',
    );
    return '$_temp0';
  }

  @override
  String profilePublicRecipesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'publika recept',
      one: 'publikt recept',
    );
    return '$_temp0';
  }

  @override
  String get adminOpsSectionTitle => 'Drift · senaste händelser';

  @override
  String get adminOpsSparseTitle => 'Glest med flit.';

  @override
  String get adminOpsSparseBody =>
      'Loggen fylls när appen har användare. Att den är kort betyder inte att något saknas.';

  @override
  String get adminOpsEventNotificationCleanup => 'Notiser städade';

  @override
  String get adminOpsEventIngredientCleanup => 'Ingredienser städade';

  @override
  String get adminOpsEventSystemEventsCleanup => 'Driftloggen städad';

  @override
  String get adminOpsEventSocialRequestsCleanup =>
      'Gamla förfrågningar städade';

  @override
  String get adminOpsEventAuditLogCleanup => 'Granskningslogg städad';

  @override
  String get adminOpsEventDeletionAuditLogCleanup => 'Raderingslogg städad';

  @override
  String get adminOpsEventRateLimitAbuse =>
      'Konto upprepat stoppat av spärren samma dygn';

  @override
  String get adminParsingSectionTitle => 'Parsning per domän';

  @override
  String get adminParsingColSuccess => 'Lyckat';

  @override
  String get adminParsingColStuck => 'Fastnar på';

  @override
  String get adminParsingTableNote =>
      'Tryck på en rad för att se importerna. Fältet i sista kolumnen är det som oftast rättas för domänen.';

  @override
  String get moderatorContentTypeRecipe => 'Recept';

  @override
  String get moderatorContentTypeComment => 'Kommentar';

  @override
  String get moderatorContentTypeMessage => 'Meddelande';

  @override
  String get moderatorContentTypeProfile => 'Profil';

  @override
  String get moderatorContentTypeCookSnap => 'Matbild';

  @override
  String get moderatorContentTypeGroup => 'Grupp';

  @override
  String get moderatorStatusNew => 'Ny';

  @override
  String get moderatorStatusInReview => 'Granskas';

  @override
  String get moderatorStatusActioned => 'Åtgärdad';

  @override
  String get moderatorStatusClosed => 'Stängd';

  @override
  String get moderatorCloseTooltip => 'Stäng rapporten';

  @override
  String get familyRatingNotSet => 'inte satt';

  @override
  String get familyRatingNoteSkip =>
      'Den som hoppar över får ingen rad och räknas inte in i snittet. Betyget går alltid att ändra, och det senaste ersätter det tidigare.';

  @override
  String get familyRatingNoteCounts =>
      'Betyget räknas in i receptets publika snitt';

  @override
  String get familyRatingNoteAnonymous =>
      ', anonymt och utan att någon identitet visas.';

  @override
  String get cookbookStatRecipes => 'recept';

  @override
  String get cookbookStatSort => 'sortering';

  @override
  String get cookbookStatSortAlphabetical => 'A–Ö';

  @override
  String get cookbookStatSortCustom => 'Egen';

  @override
  String get cookbookStatUpdated => 'senast ändrad';

  @override
  String get tagDetailNewRule => '+ Ny regel';

  @override
  String get tagDetailRulesHeading => 'Automatiska regler';

  @override
  String get tagDetailStatChanged => 'senast ändrad';

  @override
  String tagDetailRuleTagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'taggade $count recept',
      one: 'taggade 1 recept',
    );
    return '$_temp0';
  }

  @override
  String tagDetailRecipesHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recept med taggen',
      one: '1 recept med taggen',
    );
    return '$_temp0';
  }

  @override
  String get tagDetailRecipesLoadFailed =>
      'Recepten med taggen gick inte att hämta.';

  @override
  String tagDetailRuleSummaryNumber(
    String type,
    String operator,
    String value,
  ) {
    return '$type $operator $value';
  }

  @override
  String get tagEditSheetTitle => 'Redigera taggen';

  @override
  String tagDetailStatRulesValue(int enabled, int total) {
    return '$enabled av $total';
  }

  @override
  String tagDetailStatRules(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'regler på',
      one: 'regel på',
    );
    return '$_temp0';
  }

  @override
  String personalTagUnusedHeading(int count) {
    return 'Oanvända ($count)';
  }

  @override
  String get personalTagDeleteAllShort => 'Radera alla';

  @override
  String get conflictDiffMineName => 'Din';

  @override
  String get conflictDiffTheirsName => 'Deras';

  @override
  String get conflictDiffApplies => 'Gäller';

  @override
  String conflictDiffIntro(String name, String title) {
    return 'Du och $name ändrade samtidigt i $title. Bara en av versionerna gäller – så här skiljer de sig.';
  }

  @override
  String get conflictDiffIntroPlain =>
      'Ni ändrade samtidigt. Bara en av versionerna gäller – så här skiljer de sig.';

  @override
  String recipeSuggestionKeptNote(String date) {
    return 'Förslaget sparas till $date. Sedan tas det bort.';
  }

  @override
  String get importLinkOrCaptionLabel => 'Länk eller bildtext';

  @override
  String get importPasteHelp =>
      'Klistra in länken till inlägget, eller hela bildtexten om du redan kopierat den.';

  @override
  String get importCaptionWarningLead =>
      'Ett inlägg har ingen receptstruktur – bara bildtexten. Jag tar bort emoji och städar mängderna, men ';

  @override
  String get importCaptionWarningEmphasis => 'du får ofta rätta något';

  @override
  String get importVideoNotRead =>
      'Videons innehåll läses aldrig. Det som inte står i text finns inte för importen – och det ska sägas innan, inte upptäckas efter.';

  @override
  String get importFetchRecipe => 'Hämta receptet';

  @override
  String get shoppingNewSharedListTitle => 'Ny delad lista';

  @override
  String get shoppingSharedListNameLabel => 'Listans namn';

  @override
  String get shoppingShareWithHeading => 'Dela med';

  @override
  String get shoppingPermissionHeading => 'Behörighet';

  @override
  String get shoppingPermissionCanEdit => 'Kan redigera';

  @override
  String get shoppingPermissionReadOnlyTab => 'Bara läsning';

  @override
  String get shoppingPermissionCanEditHelp =>
      'Alla kan lägga till och bocka av varor i realtid.';

  @override
  String get shoppingPermissionViewOnlyHelp =>
      'De du delar med kan se listan men inte ändra den.';

  @override
  String get shoppingNoFriendsToShareWith =>
      'Du har inga vänner att dela med än.';

  @override
  String get importMoreFilters => 'Fler';

  @override
  String importArchivedHeading(int count) {
    return 'Arkiverade recept · $count';
  }

  @override
  String importRestoreCount(int count) {
    return 'Återställ $count recept';
  }

  @override
  String get importFiltersTitle => 'Filter';

  @override
  String get importTimeHeading => 'Tid';

  @override
  String get importTagsHeading => 'Taggar';

  @override
  String importRecipeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String importUpToMinutes(int minutes) {
    return 'Högst $minutes min';
  }

  @override
  String get importArchiveTitle => 'Ur arkivet';

  @override
  String importPreviewFoundCount(int count) {
    return '$count recept hittades';
  }

  @override
  String importPreviewParsedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tolkade',
      one: '1 tolkad',
    );
    return '$_temp0';
  }

  @override
  String importPreviewProgress(int selected, int total) {
    return '$selected av $total';
  }

  @override
  String get importPreviewUnreadHeading => 'Kunde inte tolkas';

  @override
  String get importPreviewReadyHeading => 'Klara att spara';

  @override
  String get voiceListeningWord => 'hör dig …';

  @override
  String get importPhotoCameraButton => 'Fota nu';

  @override
  String get importPhotoLibraryButton => 'Ur bildbiblioteket';

  @override
  String importPhotoPagesHeading(int count) {
    return 'Sidor · $count';
  }

  @override
  String get heirloomToggleSubtitle => 'Fotot sparas med receptet, som källa';

  @override
  String get importPhotoHeirloomHint =>
      'Handskrivna arvsrecept? Originalbilden sparas på receptkortet.';

  @override
  String get recipeDescriptionOptional => 'Beskrivning (valfritt)';

  @override
  String get recipeMethodHeading => 'Gör så här';

  @override
  String get importPhotoRestartTitle => 'Börja om?';

  @override
  String get importPhotoRestartMessage =>
      'Sidorna du redan tagit tas bort om du väljer en ny bild.';

  @override
  String get importPhotoRestartAction => 'Börja om';

  @override
  String get allergenUncheckedLabel => 'Ej kontrollerat';

  @override
  String get allergenUncheckedDetail =>
      'Allergenerna är inte kontrollerade för det här receptet. Läs ingredienserna själv.';

  @override
  String get allergenUncheckedA11y => 'Allergener ej kontrollerade';

  @override
  String shareAllergensContains(String names) {
    return 'Innehåller allergener: $names';
  }

  @override
  String allergenOverrideOk(String allergen) {
    return 'Du har markerat $allergen som ok. Appen hittade $allergen.';
  }

  @override
  String allergenOverrideContains(String allergen) {
    return 'Du har markerat att receptet innehåller $allergen.';
  }

  @override
  String get allergenOverrideReset => 'Återställ';

  @override
  String shareAllergensOverridden(String names) {
    return 'Appen hittade $names, men ägaren har markerat det som ok.';
  }

  @override
  String get menuManualAddTitle => 'Lägg till ändå?';

  @override
  String menuManualAddContains(String recipe, String names) {
    return '$recipe innehåller $names.';
  }

  @override
  String menuManualAddDislikes(String recipe) {
    return 'Någon i hushållet ogillar något i $recipe.';
  }

  @override
  String menuManualAddUnchecked(String recipe) {
    return 'Allergenerna är inte kontrollerade för $recipe.';
  }

  @override
  String get menuManualAddConfirm => 'Lägg till ändå';

  @override
  String get recipeSaveNeedsTitle => 'Skriv en titel för att kunna spara.';

  @override
  String get recipeSaveNeedsIngredient =>
      'Lägg till minst en ingrediens för att kunna spara.';

  @override
  String get recipeSaveNeedsInstruction =>
      'Lägg till minst ett steg för att kunna spara.';

  @override
  String get friendsSocialDisabled =>
      'Sociala funktioner är tillfälligt avstängda.';

  @override
  String chatSharedRecipeLine(String recipeTitle) {
    return 'Delade receptet ”$recipeTitle”';
  }

  @override
  String get shoppingCreateFromTemplate => 'Skapa lista från mall';

  @override
  String get errorCouldNotLoadNotificationSettings =>
      'Notisinställningarna kunde inte laddas. Försök igen.';

  @override
  String friendProfilePublicRecipesRowOf(String name) {
    return 'Publika recept från $name';
  }

  @override
  String friendProfileShareLinkRowOf(String name) {
    return 'Dela en länk till profilen för $name';
  }

  @override
  String get chatMessageMenuTitle => 'Meddelande';

  @override
  String get chatMessageReply => 'Svara';

  @override
  String get chatMessageCopy => 'Kopiera';

  @override
  String get chatMuted => 'Notiserna från chatten är tystade';

  @override
  String get chatUnmuted => 'Notiserna från chatten är på igen';

  @override
  String get chatUnmute => 'Slå på notiser';

  @override
  String get chatReactionFailed => 'Reaktionen kunde inte sparas.';

  @override
  String get feedFilterNoMatch => 'Inga händelser av det här slaget än';

  @override
  String get chatAddMembersEmptyTitle => 'Inga vänner att lägga till';

  @override
  String get chatAddMembersEmptyBody =>
      'Alla dina vänner är redan med, eller så har du inga vänner än. Hitta vänner under Vänner.';

  @override
  String get mfaStatusLoadFailed =>
      'Vi kunde inte läsa om tvåstegsverifiering är på. Försök igen.';

  @override
  String get consentLoadFailed =>
      'Vi kunde inte läsa dina samtycken. Försök igen.';

  @override
  String get menuListLoadFailed => 'Vi kunde inte hämta dina sparade menyer.';

  @override
  String get shoppingBulkRemoveFailed =>
      'Vi kunde inte ta bort alla markerade varor.';

  @override
  String get shoppingBulkRemoveFailedKept =>
      'Markeringen finns kvar, så du kan försöka igen.';

  @override
  String get personalTagCouldNotMove => 'Vi kunde inte flytta taggen.';

  @override
  String get moderatorTabClosed => 'Stängda';

  @override
  String get loadingClosedReports => 'Hämtar stängda anmälningar …';

  @override
  String get moderatorClosedLoadFailed =>
      'Kunde inte hämta stängda anmälningar';

  @override
  String get moderatorClosedEmpty => 'Inga stängda anmälningar än.';

  @override
  String get moderatorClosedThisWeek => 'Den här veckan';

  @override
  String get moderatorClosedEarlier => 'Tidigare';

  @override
  String get moderatorClosedShowMore => 'Visa fler';

  @override
  String get moderatorClosedMoreFailed => 'Kunde inte hämta fler anmälningar.';

  @override
  String get moderatorClosedListUnchanged => 'Listan du ser är oförändrad.';

  @override
  String get moderatorDecisionContentRemoved => 'Innehållet borttaget';

  @override
  String get moderatorDecisionProfileHidden => 'Profilen dold';

  @override
  String get moderatorDecisionNoAction => 'Ingen åtgärd';

  @override
  String get moderatorByYou => 'Du';

  @override
  String get moderatorByOther => 'Annan moderator';

  @override
  String get moderatorByAuto => 'Automatiskt';

  @override
  String get moderatorPillAppealed => 'Överklagad';

  @override
  String get decisionStatusRevised => 'Omprövat';

  @override
  String get moderatorClosedSheetTitle => 'Beslut';

  @override
  String get moderatorClosedRowDecision => 'Beslut';

  @override
  String get moderatorClosedRowRule => 'Regel';

  @override
  String get moderatorClosedRowAbout => 'Gäller';

  @override
  String get moderatorClosedRowDecided => 'Beslutat';

  @override
  String get moderatorClosedRowModerator => 'Moderator';

  @override
  String get moderatorClosedHistoryTitle => 'Tidigare beslut';

  @override
  String get moderatorClosedNote =>
      'Ingen text från anmälan sparas efter beslutet. Öppnar du ärendet igen läggs det i kön, och beslutet står kvar tills du fattar ett nytt.';

  @override
  String get moderatorClosedReopen => 'Öppna igen';

  @override
  String get moderatorClosedRemovedBand =>
      'Borttaget innehåll kan inte återställas. Ändrar du beslutet tas varningen bort och personen får besked.';

  @override
  String get moderatorReopenBlockAppealed =>
      'Beslutet har överklagats. Omprövningen sker genom överklagan, så ärendet kan inte öppnas igen.';

  @override
  String get moderatorReopenBlockGone =>
      'Anmälan finns inte längre, så ärendet kan inte öppnas igen.';

  @override
  String get moderatorReopenBlockNotClosed => 'Ärendet ligger redan i kön.';

  @override
  String get moderatorReopenBlockReporterErased =>
      'Den som anmälde har raderat sitt konto, så ärendet kan inte öppnas igen.';

  @override
  String get moderatorReopenBlockOwnerErased =>
      'Personen anmälan gäller har raderat sitt konto, så det finns ingen att fatta ett nytt beslut om.';

  @override
  String get moderatorReopenBlockNoDecision =>
      'Beslutet är inte sparat än, så ärendet kan inte öppnas igen.';

  @override
  String get moderatorReopenConfirmTitle => 'Öppna ärendet igen?';

  @override
  String get moderatorReopenConfirmBody =>
      'Det läggs först i Rapporter. Inget ändras och ingen får besked förrän du fattar ett nytt beslut.';

  @override
  String get moderatorReopened => 'Ärendet ligger nu i Rapporter.';

  @override
  String get moderatorReopenFailed => 'Ärendet kunde inte öppnas igen.';

  @override
  String get moderatorReopenFailedKept => 'Beslutet är oförändrat.';

  @override
  String get moderatorReopenedPill => 'Öppnad igen';

  @override
  String moderatorPreviousDecision(String decision) {
    return 'Tidigare beslut: $decision';
  }

  @override
  String moderatorEvidenceNowHeadingAt(String time) {
    return 'Innehållet nu · $time';
  }

  @override
  String get moderatorEvidenceNowHeading => 'Innehållet nu';

  @override
  String get moderatorKeepDecision => 'Behåll beslutet';

  @override
  String get moderatorChangeToNoAction => 'Ändra till Ingen åtgärd';

  @override
  String get moderatorChangeConfirmTitle => 'Ändra till Ingen åtgärd?';

  @override
  String get moderatorChangeConfirmBodyProfile =>
      'Profilen visas igen, varningen tas bort och båda får besked om det nya beslutet.';

  @override
  String get moderatorChangeConfirmBodyRemoved =>
      'Varningen tas bort och båda får besked om det nya beslutet. Innehållet går inte att återställa.';

  @override
  String get moderatorChangeConfirm => 'Ändra';

  @override
  String get moderatorDecisionKept => 'Beslutet står kvar. Ingen fick besked.';

  @override
  String get moderatorDecisionChanged =>
      'Beslutet ändrades. Varningen togs bort.';

  @override
  String get decisionRevisedNoActionOutcome =>
      'Ingen åtgärd. Beslutet ändrades efter omprövning och varningen är borttagen.';

  @override
  String get mergeWithNextStep => 'Slå ihop med nästa';

  @override
  String get stepsMerged => 'Stegen slogs ihop';

  @override
  String get stepsTooLongToMerge => 'Stegen blir för långa för att slås ihop';

  @override
  String a11yMergeSteps(int first, int second) {
    return 'Slå ihop steg $first med steg $second';
  }

  @override
  String get tagAllergenSection => 'Allergener';

  @override
  String get tagAllergenHint =>
      'Ändra bara om appen har fel för det här receptet. Appen avgör följer ingredienserna.';

  @override
  String get tagAllergenChoiceAuto => 'Appen avgör';

  @override
  String get tagAllergenChoiceContains => 'Innehåller';

  @override
  String get tagAllergenChoiceFree => 'Innehåller inte';

  @override
  String get tagAllergenAutoContains => 'Appen: innehåller';

  @override
  String get tagAllergenAutoFree => 'Appen: innehåller inte';

  @override
  String get tagAllergenAutoUnknown => 'Appen: ej kontrollerat';

  @override
  String shoppingMergeUnresolvedRecipes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rätter kunde inte räknas med',
      one: '1 rätt kunde inte räknas med',
    );
    return '$_temp0, eftersom receptet inte finns kvar.';
  }

  @override
  String shoppingPantryAddFailed(String name) {
    return 'Kunde inte lägga $name i skafferiet.';
  }
}
