// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get commonSave => 'Save';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonDelete => 'Delete';

  @override
  String get commonEdit => 'Edit';

  @override
  String get commonAdd => 'Add';

  @override
  String get commonCreate => 'Create';

  @override
  String get commonUpdate => 'Update';

  @override
  String get commonClose => 'Close';

  @override
  String get commonShare => 'Share';

  @override
  String get commonCopyLink => 'Copy link';

  @override
  String get commonLinkCopied => 'Link copied';

  @override
  String get commonPaste => 'Paste';

  @override
  String get commonRename => 'Rename';

  @override
  String get commonExport => 'Export';

  @override
  String get commonOk => 'OK';

  @override
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonLoading => 'Loading...';

  @override
  String get commonWorking => 'Working...';

  @override
  String get commonDeleting => 'Deleting...';

  @override
  String get commonYou => 'You';

  @override
  String get commonSend => 'Send';

  @override
  String get shoppingRenameList => 'Rename list';

  @override
  String get shoppingCreateList => 'New shopping list';

  @override
  String get shoppingNewName => 'New name';

  @override
  String get shoppingListName => 'List name';

  @override
  String get shoppingAddToList => 'Add to';

  @override
  String get shoppingItemName => 'Item name';

  @override
  String get shoppingAmount => 'Amount';

  @override
  String get shoppingUnit => 'Unit';

  @override
  String get shoppingCategory => 'Category';

  @override
  String get shoppingNote => 'Note';

  @override
  String get shoppingAddItem => 'Add item';

  @override
  String get shoppingEditItem => 'Edit item';

  @override
  String get shoppingList => 'Shopping list';

  @override
  String get authInvalidEmail => 'Enter a valid email address';

  @override
  String get authResetPassword => 'Reset password';

  @override
  String get authForgotPassword => 'Forgot password?';

  @override
  String get authEnterPassword => 'Enter your password';

  @override
  String get authPasswordMinLength => 'Min 6 characters';

  @override
  String get authResetPasswordInstructions =>
      'Enter your email address and we\'ll send you instructions to reset your password.';

  @override
  String get navExitApp => 'Exit Butlery?';

  @override
  String get navExitAppConfirmation => 'Are you sure you want to exit the app?';

  @override
  String get navExit => 'Exit';

  @override
  String get imageAddImage => 'Add image';

  @override
  String get commentDeletedUndoMessage => 'Comment deleted';

  @override
  String get imageRemovedUndoMessage => 'Photo removed';

  @override
  String pantryItemRemovedUndoMessage(String name) {
    return '$name removed from pantry';
  }

  @override
  String pantryItemsRemovedUndoMessage(int count) {
    return '$count removed from pantry';
  }

  @override
  String pantrySelectedCount(int count) {
    return '$count selected';
  }

  @override
  String a11yPantrySelectItem(String itemName) {
    return '$itemName, tap to select';
  }

  @override
  String get slotPickerDialogTitle => 'Pick a menu slot';

  @override
  String get slotPickerPreviousWeek => 'Previous week';

  @override
  String get slotPickerNextWeek => 'Next week';

  @override
  String slotPickerWeekLabel(int week) {
    return 'w.$week';
  }

  @override
  String slotPickerConfirmCount(int count) {
    return 'Add ($count)';
  }

  @override
  String a11ySlotPickerCell(String day, String slot) {
    return 'Pick $day $slot';
  }

  @override
  String recipeAddedToMenuSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recipe added to $count slots in the weekly menu',
      one: 'Recipe added to 1 slot in the weekly menu',
    );
    return '$_temp0';
  }

  @override
  String get menuPlaceAutoButton => 'Place automatically in the calendar';

  @override
  String get menuPlaceManualButton => 'I\'ll place them myself';

  @override
  String menuAutoPlacedToast(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes placed in the calendar',
      one: '1 recipe placed in the calendar',
    );
    return '$_temp0';
  }

  @override
  String get menuAutoPlacedChangeAction => 'Change';

  @override
  String get menuPlacementTitle => 'place in the week';

  @override
  String menuPlacementProgress(int placed, int total) {
    return '$placed of $total placed';
  }

  @override
  String menuPlacementTrayLabel(int count) {
    return 'Left to place ($count)';
  }

  @override
  String menuPlacementHint(String recipe) {
    return 'Tap a free cell to place $recipe.';
  }

  @override
  String get menuPlacementHintSelect => 'Select a recipe below to place it.';

  @override
  String get menuPlacementPlaceHere => 'place here';

  @override
  String get menuPlacementAutoRest => 'Place the rest automatically';

  @override
  String menuPlacementOverflow(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes didn\'t fit this week',
      one: '1 recipe didn\'t fit this week',
    );
    return '$_temp0';
  }

  @override
  String menuPlacementSaved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes placed in the weekly menu',
      one: '1 recipe placed in the weekly menu',
    );
    return '$_temp0';
  }

  @override
  String get weeklyMenuNewBadge => 'NEW';

  @override
  String a11yPlacementCell(String day, String slot) {
    return 'Place on $day $slot';
  }

  @override
  String a11yPlacementTrayCard(String recipe) {
    return 'Select $recipe';
  }

  @override
  String a11yPlacementRemoveEntry(String recipe) {
    return 'Remove $recipe from the cell';
  }

  @override
  String get bulkAddToMenu => 'Add to weekly menu';

  @override
  String bulkAddToMenuSuccess(int count, String slot, String day) {
    return '$count recipes added to $slot $day';
  }

  @override
  String bulkAddToMenuOverflowed(int added, int requested) {
    return '$added of $requested added — the rest don\'t fit this week';
  }

  @override
  String get bulkAddToMenuOverflowedAction => 'Put the rest in next week';

  @override
  String bulkAddToMenuSuccessNextWeek(int count) {
    return '$count recipes added to next week';
  }

  @override
  String bulkAddToMenuOverflowedTwoWeeks(int remaining) {
    return 'The rest doesn\'t fit next week either — $remaining recipes still without a slot';
  }

  @override
  String get bulkExport => 'Export selected';

  @override
  String get bulkExportCopyClipboard => 'Copy to clipboard';

  @override
  String get bulkExportShareFile => 'Share as file';

  @override
  String bulkExportCopied(int count) {
    return '$count recipes copied to clipboard';
  }

  @override
  String get imageTakePhoto => 'Take photo';

  @override
  String get imageUseCamera => 'Use camera';

  @override
  String get imageFromGallery => 'Choose from gallery';

  @override
  String get imageSelectFromGallery => 'Select from gallery';

  @override
  String imageSelectUpTo(int count) {
    return 'Select up to $count images';
  }

  @override
  String validationFieldRequired(String fieldName) {
    return '$fieldName is required';
  }

  @override
  String validationFieldTooShort(String fieldName, int minLength) {
    return '$fieldName must be at least $minLength characters';
  }

  @override
  String validationFieldTooLong(String fieldName, int maxLength) {
    return '$fieldName cannot exceed $maxLength characters';
  }

  @override
  String validationInvalidFormat(String fieldName) {
    return 'Invalid format for $fieldName';
  }

  @override
  String get validationNameRequired => 'Name required';

  @override
  String get validationEmailRequired => 'Email required';

  @override
  String get validationPasswordRequired => 'Password required';

  @override
  String get validationInvalidUrl => 'Invalid URL';

  @override
  String get validationInvalidAmount => 'Invalid amount';

  @override
  String get validationPasswordTooShort =>
      'Password must be at least 6 characters';

  @override
  String get validationGenericRequired => 'This field is required';

  @override
  String get validationEmailInvalid => 'Invalid email address';

  @override
  String get errorGeneric => 'An error occurred. Please try again.';

  @override
  String get errorNetwork => 'Network error. Check your internet connection.';

  @override
  String get errorServer => 'Server error. Please try again later.';

  @override
  String get errorAuthentication =>
      'Authentication error. Please sign in again.';

  @override
  String get errorPermissionDenied =>
      'You don\'t have permission to perform this action.';

  @override
  String get errorNotFound => 'Could not be found.';

  @override
  String errorCouldNotCreate(String itemType) {
    return 'Could not create $itemType';
  }

  @override
  String errorCouldNotUpdate(String itemType) {
    return 'Could not update $itemType';
  }

  @override
  String errorCouldNotDelete(String itemType) {
    return 'Could not delete $itemType';
  }

  @override
  String errorCouldNotLoad(String itemType) {
    return 'Could not load $itemType';
  }

  @override
  String get nounSettings => 'settings';

  @override
  String get nounGroupContent => 'group content';

  @override
  String get nounFriends => 'friends';

  @override
  String get nounFriendList => 'friend list';

  @override
  String groupInvitationMessage(String groupName) {
    return 'You have been invited to the group $groupName!';
  }

  @override
  String uploadTimeIn(String duration) {
    return ' in $duration';
  }

  @override
  String get autoSaveEnabled => 'Auto-save enabled';

  @override
  String selectionFriendSelectedWithName(String name) {
    return '$name selected';
  }

  @override
  String selectionFriendsSelectedWithNames(int count, String names) {
    return '$count selected: $names';
  }

  @override
  String selectionFriendsSelectedCount(int count) {
    return '$count friends selected';
  }

  @override
  String sharePartialSuccessSingular(int newCount) {
    return '1 person is already a member. Inviting $newCount new.';
  }

  @override
  String sharePartialSuccessPlural(int existingCount, int newCount) {
    return '$existingCount people are already members. Inviting $newCount new.';
  }

  @override
  String get nounShoppingList => 'shopping list';

  @override
  String get nounShareLink => 'share link';

  @override
  String get validationUrlRequired => 'URL is required';

  @override
  String get urlSuggestionKnownSite =>
      'Known recipe site — good chance of import!';

  @override
  String get urlSuggestionUnknownSite => 'Unknown site — import may be limited';

  @override
  String get urlSuggestionContainsRecipeKeyword =>
      'URL contains recipe keyword';

  @override
  String get urlSuggestionTooLong =>
      'URL is unusually long — verify it is correct';

  @override
  String get urlSuggestionSocialMedia =>
      'Social media — import may require extra steps';

  @override
  String get urlSuggestionOptimal => 'Perfect — ready to import!';

  @override
  String errorWithContext(String action, String error) {
    return 'Error during $action: $error';
  }

  @override
  String successItemCreated(String itemType) {
    return '$itemType created!';
  }

  @override
  String successItemUpdated(String itemType) {
    return '$itemType updated!';
  }

  @override
  String successItemDeleted(String itemType) {
    return '$itemType deleted!';
  }

  @override
  String successItemAdded(String itemName) {
    return '$itemName added!';
  }

  @override
  String confirmDeleteItem(String itemName) {
    return 'Confirmation required — remove \"$itemName\"?';
  }

  @override
  String get confirmUnsavedChanges =>
      'Unsaved changes remain. Depart without saving?';

  @override
  String get confirmIrreversibleAction => 'This cannot be reversed.';

  @override
  String get draftRecovery => 'Restore draft';

  @override
  String get draftRecoverySubtitle =>
      'You have unsaved recipe drafts. Would you like to continue where you left off?';

  @override
  String get photoDraftRecoverySubtitle =>
      'You have a photo with extracted text from earlier. Would you like to continue where you left off?';

  @override
  String get draftRestore => 'Restore';

  @override
  String get draftStartFresh => 'Start fresh';

  @override
  String get draftRestored => 'Draft restored!';

  @override
  String get draftCouldNotRestore =>
      'Couldn\'t restore draft. Starting with an empty form.';

  @override
  String get draftRestoring => 'Restoring draft...';

  @override
  String get draftUnnamedRecipe => 'Unnamed recipe';

  @override
  String draftFieldsFilledCount(int count) {
    return '$count fields filled';
  }

  @override
  String draftRestoredWithCount(int count) {
    return 'Draft restored! $count fields loaded';
  }

  @override
  String get emptyNoItems => 'No items found.';

  @override
  String get emptyNoResults => 'No results found.';

  @override
  String get emptyNoFriends => 'No friends yet';

  @override
  String get emptyNoRecipes => 'The collection awaits its first entry';

  @override
  String emptyNoRecipesSubtitle(String addButton) {
    return 'The first recipe is added via \"$addButton\".';
  }

  @override
  String get emptyNoSearchResultsSubtitle =>
      'Try searching for something else or clear the search';

  @override
  String get emptyNoFriendsSearchTitle => 'No friends matched your search';

  @override
  String get emptyNoGroupsSearchTitle => 'No groups matched your search';

  @override
  String get emptyNoMenuTitle => 'The menu has not yet been set';

  @override
  String get emptyNoMenuSubtitle =>
      'State a preference, or use the button below';

  @override
  String get emptyNoShoppingListTitle =>
      'There is no menu from which to derive a shopping list';

  @override
  String get emptyNoShoppingListSubtitle =>
      'A weekly menu must be established first';

  @override
  String get emptyNoFriendsTitle => 'No one has been introduced yet';

  @override
  String get emptyNoFriendsSubtitle =>
      'Friends may be invited to share recipes and menus';

  @override
  String get emptyNoCategoriesTitle => 'No categories created';

  @override
  String get emptyNoCategoriesSubtitle =>
      'Create your first category to organize your friends';

  @override
  String get emptyNoImagesTitle => 'No images added';

  @override
  String get emptyNoImagesSubtitle =>
      'Add images to make your recipe more attractive';

  @override
  String get emptyNoTargetsTitle => 'No destinations available';

  @override
  String get emptyNoTargetsSubtitle =>
      'Add friends or groups to be able to share content';

  @override
  String get emptyNoSavedMenusTitle => 'No saved menus';

  @override
  String get emptyNoSavedMenusSubtitle =>
      'Create and save menus to easily load them later';

  @override
  String get emptyNoSharedShoppingListsTitle => 'No shared shopping lists';

  @override
  String get emptyNoSharedShoppingListsSubtitle =>
      'When you collaborate on shopping lists with friends or family, they will appear here.';

  @override
  String get emptyNoTagsTitle => 'No tags have been arranged yet';

  @override
  String get emptyNoTagsSubtitle =>
      'Personal tags serve to arrange the collection as one prefers.';

  @override
  String get emptyNoGroupsTitle => 'Group cooking, simpler';

  @override
  String get emptyNoGroupsSubtitle =>
      'Create a group to share weekly menus and shopping lists with friends or family — everyone sees the same plan and can check off items as they go.';

  @override
  String get emptyNoConversationsTitle => 'No conversations yet';

  @override
  String get emptyNoConversationsSubtitle =>
      'A conversation with a friend may be commenced here.';

  @override
  String get emptyGenericTitle => 'No content to present';

  @override
  String get recipeName => 'Recipe name';

  @override
  String get recipeDescription => 'Description';

  @override
  String get recipeIngredients => 'Ingredients';

  @override
  String get recipeInstructions => 'Instructions';

  @override
  String get recipeCookingTime => 'Cooking time';

  @override
  String get recipePortions => 'Servings';

  @override
  String get recipeAdd => 'Add recipe';

  @override
  String get recipeEdit => 'Edit recipe';

  @override
  String get recipeDelete => 'Delete recipe';

  @override
  String get recipeDeleting => 'Deleting recipe...';

  @override
  String recipeFormatPortions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servings',
      one: '1 serving',
    );
    return '$_temp0';
  }

  @override
  String get socialGroupName => 'Group name';

  @override
  String get socialCreateGroup => 'Create group';

  @override
  String get socialEditGroup => 'Edit group';

  @override
  String get socialAddFriend => 'Add friend';

  @override
  String get socialRemoveFriend => 'Remove friend';

  @override
  String get socialSendFriendRequest => 'Send friend request';

  @override
  String get menuName => 'Menu name';

  @override
  String get menuSave => 'Save menu';

  @override
  String get menuLoad => 'Load menu';

  @override
  String get menuWeek => 'Weekly menu';

  @override
  String get messagingTitle => 'Messages';

  @override
  String get messagingNewConversation => 'New conversation';

  @override
  String get messagingSearchConversations => 'Search conversations...';

  @override
  String get messagingLoadingConversations => 'Loading conversations...';

  @override
  String get messagingNoConversationsFound => 'No conversations found';

  @override
  String get messagingTryAnotherSearch => 'Try a different search term';

  @override
  String get messagingNoConversationsYet => 'No conversations yet';

  @override
  String get messagingStartFirstConversation =>
      'Start your first conversation by tapping the message button';

  @override
  String get messagingMarkAsRead => 'Mark as read';

  @override
  String get messagingGroupInfo => 'Group information';

  @override
  String get messagingLeaveGroup => 'Leave group';

  @override
  String get messagingViewProfile => 'View profile';

  @override
  String get messagingDeleteConversation => 'Delete conversation';

  @override
  String get messagingLeftGroup => 'You have left the group';

  @override
  String messagingCouldNotLeaveGroup(String error) {
    return 'Couldn\'t leave the group: $error';
  }

  @override
  String get messagingLeave => 'Leave';

  @override
  String get messagingDeleteConversationConfirm =>
      'Are you sure you want to delete this conversation? All messages will be lost.';

  @override
  String messagingCouldNotShowProfile(String error) {
    return 'Couldn\'t open profile: $error';
  }

  @override
  String messagingConversationDeleted(String title) {
    return 'Conversation \"$title\" deleted';
  }

  @override
  String messagingCouldNotDeleteConversation(String error) {
    return 'Couldn\'t delete conversation: $error';
  }

  @override
  String messagingConfirmLeaveGroup(String groupName) {
    return 'Are you sure you want to leave \"$groupName\"?';
  }

  @override
  String get profileLogout => 'Log out';

  @override
  String get profileLogoutConfirm => 'Are you sure you want to log out?';

  @override
  String get profileDeleteAccount => 'Delete account permanently';

  @override
  String get profileDeleteWarningTitle => 'WARNING: This will:';

  @override
  String get profileDeleteWarningRecipes => 'Delete all your recipes';

  @override
  String get profileDeleteWarningMenus => 'Delete all your menus';

  @override
  String get profileDeleteWarningShoppingLists =>
      'Delete all your shopping lists';

  @override
  String get profileDeleteWarningFriends => 'Remove all friends and messages';

  @override
  String get profileDeleteWarningSharedContent => 'Delete all shared content';

  @override
  String get profileDeleteIrreversible => 'This action CANNOT be undone!';

  @override
  String get profileDeleteConfirmButton => 'I understand, delete my account';

  @override
  String get profileConfirmWithPassword => 'Confirm with password';

  @override
  String get profileEnterPasswordToConfirm =>
      'Enter your password to confirm deletion:';

  @override
  String get profilePassword => 'Password';

  @override
  String get profileConfirm => 'Confirm';

  @override
  String get profileError => 'Error';

  @override
  String profileCouldNotDeleteAccount(String error) {
    return 'Could not delete account: $error';
  }

  @override
  String get chatErrorOccurred => 'An error occurred';

  @override
  String get chatConversationInfo => 'Conversation info';

  @override
  String get chatTypeDirectMessage => 'Type: Direct message';

  @override
  String chatCreatedAt(String date) {
    return 'Created: $date';
  }

  @override
  String get chatNotificationSettingsUpdated => 'Notification settings updated';

  @override
  String get chatCouldNotChangeNotifications =>
      'Couldn\'t change notification settings';

  @override
  String get chatLeaveConversation => 'Leave conversation';

  @override
  String get chatLeaveConversationConfirm =>
      'Are you sure you want to leave this conversation?';

  @override
  String get chatCouldNotLeaveConversation =>
      'Couldn\'t leave the conversation';

  @override
  String get chatEditMessage => 'Edit message';

  @override
  String get chatWriteYourMessage => 'Write your message...';

  @override
  String get chatCouldNotEditMessage => 'Couldn\'t edit the message';

  @override
  String get chatCouldNotDeleteMessage => 'Couldn\'t delete the message';

  @override
  String get chatMessageCopied => 'Message copied';

  @override
  String get chatCouldNotCopyMessage => 'Couldn\'t copy the message';

  @override
  String get chatYourRecipes => 'Your recipes';

  @override
  String get chatSharedRecipe => 'Shared recipe';

  @override
  String get chatCheckOutRecipe => 'Check out this recipe!';

  @override
  String get chatCouldNotShareRecipe => 'Couldn\'t share recipe';

  @override
  String get chatMenuSharingComingSoon => 'Menu sharing coming soon';

  @override
  String get chatCouldNotShareMenu => 'Couldn\'t share menu';

  @override
  String get chatShoppingListSharingComingSoon =>
      'Shopping list sharing coming soon';

  @override
  String get chatCouldNotShareShoppingList => 'Couldn\'t share shopping list';

  @override
  String get chatSelectMenuWeek => 'Choose a week to share';

  @override
  String chatMenuWeekOption(int weekNum) {
    return 'Week $weekNum';
  }

  @override
  String get chatWeekCurrentSuffix => ' (this week)';

  @override
  String chatMenuShareTitle(int weekNum) {
    return 'Weekly menu wk $weekNum';
  }

  @override
  String get chatCheckOutMenu => 'Check out my weekly menu!';

  @override
  String get chatNoMenuForWeek => 'No menu for that week';

  @override
  String get chatSelectShoppingList => 'Choose a shopping list';

  @override
  String get chatCheckOutShoppingList => 'Check out my shopping list!';

  @override
  String get chatNoShoppingLists => 'You have no shopping lists yet';

  @override
  String get chatAttachmentRecipe => 'Recipe';

  @override
  String get chatAttachmentMenu => 'Menu';

  @override
  String get chatAttachmentShoppingList => 'Shopping list';

  @override
  String get chatAttachmentPhoto => 'Photo';

  @override
  String get chatMessagingDisabled => 'Messaging is temporarily disabled.';

  @override
  String get veckomenyHeaderTitle => 'weekly\nmenu';

  @override
  String get minaReceptHeaderTitle => 'your\nrecipes';

  @override
  String get cookingModeNoInstructions =>
      'This recipe has no steps to cook from.';

  @override
  String get feedRecipeUnavailable => 'This recipe isn\'t available';

  @override
  String get feedRequestRecipeTitle => 'Request recipe';

  @override
  String feedRequestRecipeBody(String name) {
    return '$name hasn\'t shared this recipe. Ask for it?';
  }

  @override
  String get feedRequestRecipeConfirm => 'Request recipe';

  @override
  String get feedRecipeRequestSent => 'Request sent';

  @override
  String get chatLoadingImage => 'Loading image...';

  @override
  String get chatImageSent => 'Image sent!';

  @override
  String get chatNoImageSelected => 'No image selected';

  @override
  String get chatCouldNotSharePhoto => 'Couldn\'t share photo';

  @override
  String get chatDeleteMessage => 'Delete';

  @override
  String get chatDeleteMessageConfirm =>
      'Are you sure you want to delete the message?';

  @override
  String get statusConnecting => 'Connecting...';

  @override
  String get statusSyncing => 'Syncing...';

  @override
  String get statusSaving => 'Saving...';

  @override
  String get statusCreating => 'Creating...';

  @override
  String get statusUpdating => 'Updating...';

  @override
  String get accessibilityBackButton => 'Back';

  @override
  String get unitMinutesShort => 'min';

  @override
  String get unitHoursShort => 'h';

  @override
  String get dialogErrorTitle => 'An error occurred';

  @override
  String get dialogLoading => 'Loading...';

  @override
  String get dialogConfirmDeleteTitle => 'Confirm deletion';

  @override
  String dialogConfirmDeleteMessage(String itemName, String itemType) {
    return 'Are you sure you want to remove $itemName from $itemType?';
  }

  @override
  String get recipePortionAbbreviation => 'srv';

  @override
  String get recipePortionSingular => 'serving';

  @override
  String get recipePortionsPlural => 'servings';

  @override
  String get recipeCookedToday => 'Cooked today';

  @override
  String get recipeCookedTodaySuccess => 'Recipe marked as cooked today!';

  @override
  String get recipeCookedTodayError => 'Could not mark as cooked';

  @override
  String get recipeNoInstructions => 'No instructions provided.';

  @override
  String get recipeTags => 'Tags';

  @override
  String get recipeImagesTitle => 'Images';

  @override
  String recipeImageCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '1 image',
    );
    return '$_temp0';
  }

  @override
  String get recipePersonalTags => 'Personal tags';

  @override
  String get recipeAnalysisFailed => 'Analysis failed';

  @override
  String get recipeAnalyzing => 'Analyzing...';

  @override
  String get recipeAnalysisFailedA11y => 'Ingredient analysis failed';

  @override
  String get recipeAnalyzingA11y => 'Ingredients being analyzed';

  @override
  String get recipeSearchHint => 'search recipes...';

  @override
  String get recipeShowMore => 'Show more recipes';

  @override
  String recipeCountBadge(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
      zero: 'No recipes',
    );
    return '$_temp0';
  }

  @override
  String get scalerPortionsLabel => 'Servings:';

  @override
  String get scalerUsingSwedishUnits => 'Using metric units';

  @override
  String get scalerConvertAmericanUnits => 'Convert American units';

  @override
  String scalerScaledFromTo(int from, int to) {
    return 'Scaled from $from to $to servings';
  }

  @override
  String get scalerAmericanConverted => 'American units converted to metric';

  @override
  String get portionDecrease => 'Decrease portions';

  @override
  String get portionIncrease => 'Increase portions';

  @override
  String get menuPromptQuestion => 'What kind of menu do you want?';

  @override
  String get menuPromptHint => 'E.g. 3 dinners, 2 lunches and 1 breakfast';

  @override
  String get menuGenerating => 'Generating...';

  @override
  String get menuGenerateNew => 'Generate new menu';

  @override
  String get menuGenerate => 'Generate menu';

  @override
  String get menuYourWeeklyMenu => 'Your weekly menu';

  @override
  String menuRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
      zero: 'No recipes',
    );
    return '$_temp0';
  }

  @override
  String get menuChooseManually => 'Choose recipes manually';

  @override
  String get menuNoMoreRecipes => 'No more recipes available for swap';

  @override
  String get menuGenerateError => 'Could not generate menu';

  @override
  String menuWeekBadgeWithCount(int week, int count) {
    return 'Week $week · $count dishes';
  }

  @override
  String menuWeekBadge(int week) {
    return 'Week $week';
  }

  @override
  String get menuToShoppingList => 'To shopping list';

  @override
  String menuGeneratedShoppingListName(int week) {
    return 'Shopping list w.$week';
  }

  @override
  String menuShoppingListGenerated(String listName, int count) {
    return '$listName updated – $count items';
  }

  @override
  String get menuShoppingListGenerationEmpty =>
      'This week\'s plan has no recipes with ingredients yet';

  @override
  String get menuShoppingListGenerationFailed =>
      'Could not create the shopping list – try again';

  @override
  String get menuLoadSaved => 'Load saved menu';

  @override
  String get menuClear => 'Clear menu';

  @override
  String get menuShared => 'Weekly menu shared!';

  @override
  String get menuGeneratingOverlay => 'Generating your weekly menu...';

  @override
  String get menuGeneratingSubtitle =>
      'Finding recipes that match your preferences';

  @override
  String shoppingCountBadge(int items, int done) {
    return '$items items · $done done';
  }

  @override
  String get commonSort => 'Sort';

  @override
  String get commonHide => 'Hide';

  @override
  String get commonShow => 'Show';

  @override
  String commonShowAllCount(int count) {
    return 'Show all ($count)';
  }

  @override
  String commonMoreCount(int count) {
    return '+$count more';
  }

  @override
  String get commonDismiss => 'Dismiss';

  @override
  String get errorUnexpected => 'An unexpected error occurred';

  @override
  String get searchClearSearch => 'Clear search';

  @override
  String get searchRecentSearches => 'Recent searches';

  @override
  String get searchClearFilters => 'Clear filters';

  @override
  String get syncComplete => 'Sync complete!';

  @override
  String syncFailed(String error) {
    return 'Sync failed: $error';
  }

  @override
  String get offlineShowingLocal => 'Offline mode - showing local recipes';

  @override
  String get recipeCreateCopy => 'Create copy';

  @override
  String recipeDuplicateTitle(String title) {
    return '$title (Copy)';
  }

  @override
  String get recipePrint => 'Print';

  @override
  String get recipeCreateShoppingList => 'Create shopping list';

  @override
  String get recipeUpdateTags => 'Update tags';

  @override
  String get recipeViewSource => 'View source';

  @override
  String get recipeViewCapturedSource => 'View captured source';

  @override
  String get recipeSourceSheetTitle => 'Source text';

  @override
  String recipeSourceCapturedAt(String time) {
    return 'Captured $time';
  }

  @override
  String get recipeSourceTypeUrl => 'Source URL';

  @override
  String get recipeSourceTypeYoutube => 'YouTube transcript';

  @override
  String get recipeSourceTypeTiktok => 'TikTok caption';

  @override
  String get recipeSourceTypeInstagram => 'Instagram caption';

  @override
  String get recipeSourceTypeTextPaste => 'Pasted text';

  @override
  String get recipeSourceTypePhotoOcr => 'Photo text';

  @override
  String get recipeSourceReextract => 'Re-extract from source';

  @override
  String get recipeSourceReextractConfirmTitle => 'Re-extract recipe?';

  @override
  String get recipeSourceReextractConfirmMessage =>
      'This overwrites the recipe\'s current content with a fresh extraction from the source. This cannot be undone.';

  @override
  String get recipeSourceReextractConfirmAction => 'Re-extract';

  @override
  String get recipeSourceReextractInProgress => 'Re-extracting from source …';

  @override
  String get recipeSourceReextractSuccess => 'Recipe re-extracted from source';

  @override
  String get recipeSourceReextractFailed =>
      'Could not re-extract from source. The recipe is unchanged.';

  @override
  String get recipeSourceStaleBanner =>
      'The source was saved a long time ago — a fresh extraction may differ from the original.';

  @override
  String get recipeShareWithFriends => 'Share with friends';

  @override
  String get recipeShareExternal => 'Share externally';

  @override
  String recipeSourceFrom(String host) {
    return 'From $host';
  }

  @override
  String get errorCouldNotOpenLink => 'Could not open link';

  @override
  String get errorInvalidLink => 'Invalid link';

  @override
  String shoppingItemRemoved(String name) {
    return '$name removed!';
  }

  @override
  String shoppingItemRemoveError(String name) {
    return 'Could not remove $name';
  }

  @override
  String get shoppingAllUnchecked => 'All items unchecked!';

  @override
  String get shoppingNoListForRename => 'No list selected for renaming';

  @override
  String get shoppingNoListForDelete => 'No list selected for deletion';

  @override
  String get commonBack => 'Back';

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonDisable => 'Disable';

  @override
  String get commonName => 'Name';

  @override
  String get commonShowDetails => 'Show details';

  @override
  String get commonEditName => 'Edit name';

  @override
  String get commonErrorOccurred => 'An error occurred';

  @override
  String get commonContinue => 'Continue';

  @override
  String get commonMore => 'More';

  @override
  String get a11yRecipeMoreActions => 'More recipe actions';

  @override
  String get commonNext => 'Next';

  @override
  String get commonPrevious => 'Previous';

  @override
  String get commonSkip => 'Skip';

  @override
  String get commonSkipAll => 'Skip all';

  @override
  String get commonSaveAndClose => 'Save and close';

  @override
  String get commonSaveAndNext => 'Save and next';

  @override
  String get commonSaveChanges => 'Save changes';

  @override
  String get commonSelectAll => 'Select all';

  @override
  String get commonDeselectAll => 'Deselect all';

  @override
  String get commonInvertSelection => 'Invert';

  @override
  String commonAddWithLabel(String label) {
    return 'Add $label';
  }

  @override
  String get commonClearAll => 'Clear all';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonImage => 'Image';

  @override
  String get commonSettings => 'Settings';

  @override
  String get settingsSubtitle => 'Allergens, tags, notifications and more';

  @override
  String get settingsSectionFood => 'Food preferences';

  @override
  String get settingsSectionNotifications => 'Notifications';

  @override
  String get settingsSectionAccount => 'Account & security';

  @override
  String get settingsSectionAbout => 'About';

  @override
  String get settingsSectionLanguage => 'Language';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get settingsLanguageDialogTitle => 'Choose language';

  @override
  String get commonLogout => 'Log out';

  @override
  String get commonLogoutNow => 'Log out now';

  @override
  String get commonTakePhoto => 'Take photo';

  @override
  String get commonSelectFromGallery => 'Select from gallery';

  @override
  String get commonSelectFriends => 'Select friends';

  @override
  String commonRemoveLabel(String label) {
    return 'Remove $label';
  }

  @override
  String get personalTagsViewTitle => 'Personal Tags';

  @override
  String get personalTagCreateTag => 'Create tag';

  @override
  String get personalTagCreateGroup => 'Create group';

  @override
  String get personalTagEmptyTitle => 'No personal tags';

  @override
  String get personalTagEmptySubtitle => 'Create tags to organize your recipes';

  @override
  String get personalTagSectionTags => 'Tags';

  @override
  String get personalTagDeleteGroup => 'Delete group';

  @override
  String get personalTagGroupEmpty => 'No tags in this group';

  @override
  String personalTagRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return '$_temp0';
  }

  @override
  String personalTagRuleCount(int count) {
    return '$count rules';
  }

  @override
  String personalTagRuleCountActive(int enabled, int total) {
    return '$enabled/$total rules active';
  }

  @override
  String get personalTagNoUsage => 'Not used';

  @override
  String get personalTagEnableAllRules => 'Enable all rules';

  @override
  String get personalTagDisableAllRules => 'Disable all rules';

  @override
  String personalTagRulesDisabled(int count) {
    return '$count rules disabled';
  }

  @override
  String personalTagRulesActive(int count) {
    return '$count rules active';
  }

  @override
  String get personalTagMoveToGroup => 'Move to group';

  @override
  String get personalTagDeleteTag => 'Delete tag';

  @override
  String get personalTagEnableAllRulesConfirm => 'Enable all rules?';

  @override
  String get personalTagDisableAllRulesConfirm => 'Disable all rules?';

  @override
  String personalTagEnableAllRulesMessage(int count, String name) {
    return 'All $count rules for \"$name\" will be enabled.';
  }

  @override
  String personalTagDisableAllRulesMessage(int count, String name) {
    return 'All $count rules for \"$name\" will be disabled.';
  }

  @override
  String get personalTagAllRulesEnabled => 'All rules enabled';

  @override
  String get personalTagAllRulesDisabled => 'All rules disabled';

  @override
  String get personalTagCouldNotChangeRules => 'Could not change rules';

  @override
  String get personalTagNameLabel => 'Tag name';

  @override
  String get personalTagNameHint => 'E.g. Favorites';

  @override
  String get personalTagCreated => 'Tag created';

  @override
  String get personalTagCouldNotCreate => 'Could not create tag';

  @override
  String get personalTagGroupNameLabel => 'Group name';

  @override
  String get personalTagGroupNameHint => 'E.g. Dinners';

  @override
  String get personalTagGroupCreated => 'Group created';

  @override
  String get personalTagCouldNotCreateGroup => 'Could not create group';

  @override
  String get personalTagEditTag => 'Edit tag';

  @override
  String get personalTagUpdated => 'Tag updated';

  @override
  String get personalTagDeleteTagConfirm => 'Delete tag?';

  @override
  String personalTagDeleteTagMessage(String name) {
    return 'Are you sure you want to delete \"$name\"? The tag will be removed from all recipes.';
  }

  @override
  String personalTagDeleteTagMessageWithCount(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'It will be untagged from $count recipes.',
      one: 'It will be untagged from 1 recipe.',
      zero: 'No recipes will be affected.',
    );
    return 'Are you sure you want to delete \"$name\"? $_temp0';
  }

  @override
  String get personalTagDeleted => 'Tag deleted';

  @override
  String personalTagSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get personalTagMergeAction => 'Merge';

  @override
  String get personalTagOptions => 'More options';

  @override
  String get personalTagMergeTitle => 'Merge tags';

  @override
  String personalTagMergeMessage(int count, String target) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count tags will be merged into «$target». The others are removed and their recipes are moved.',
      two:
          '2 tags will be merged into «$target». The other is removed and its recipes are moved.',
    );
    return '$_temp0';
  }

  @override
  String get personalTagMergeKeepLabel => 'Keep this tag:';

  @override
  String get personalTagMergeConfirm => 'Merge';

  @override
  String personalTagMergeSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Tags merged, $count recipes updated',
      one: 'Tags merged, 1 recipe updated',
      zero: 'Tags merged',
    );
    return '$_temp0';
  }

  @override
  String personalTagMergeSuccessCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags merged',
      one: '1 tag merged',
    );
    return '$_temp0';
  }

  @override
  String personalTagBulkDeleteTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count tags?',
      one: 'Delete 1 tag?',
    );
    return '$_temp0';
  }

  @override
  String personalTagBulkDeleteMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The tags will be removed from every recipe that uses them.',
      one: 'The tag will be removed from every recipe that uses it.',
    );
    return '$_temp0';
  }

  @override
  String personalTagBulkDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags deleted',
      one: '1 tag deleted',
    );
    return '$_temp0';
  }

  @override
  String get personalTagNoGroup => 'No group';

  @override
  String get personalTagCreateNewGroup => 'Create new group';

  @override
  String get personalTagMoved => 'Tag moved';

  @override
  String get personalTagGroupCreatedAndTagMoved =>
      'Group created and tag moved';

  @override
  String get personalTagRenameGroup => 'Rename group';

  @override
  String get personalTagGroupUpdated => 'Group updated';

  @override
  String get personalTagDeleteGroupConfirm => 'Delete group?';

  @override
  String personalTagDeleteGroupMessage(String name) {
    return 'Are you sure you want to delete \"$name\"? Tags in the group will be ungrouped.';
  }

  @override
  String get personalTagGroupDeleted => 'Group deleted';

  @override
  String get personalTagSortByName => 'Name';

  @override
  String get personalTagSortByUsage => 'Usage';

  @override
  String get personalTagSortByRuleCount => 'Rule count';

  @override
  String personalTagTileSemantics(
    String name,
    int count,
    int enabled,
    int total,
  ) {
    return '$name, $count recipes, $enabled of $total rules active';
  }

  @override
  String get tagDetailDefaultTitle => 'Tag';

  @override
  String get tagDetailNotFound => 'Tag could not be found';

  @override
  String get tagDetailEditTitle => 'Edit tag';

  @override
  String get tagDetailApplyRules => 'Apply rules';

  @override
  String get tagDetailApplyRulesSubtitle => 'Apply to existing recipes';

  @override
  String get tagDetailNameHint => 'Tag name';

  @override
  String get tagDetailNameRequired => 'Tag name required';

  @override
  String get tagDetailUpdated => 'Tag updated';

  @override
  String get tagDetailCouldNotUpdate => 'Could not update tag';

  @override
  String get tagDetailRuleCreated => 'Rule created';

  @override
  String get tagDetailCouldNotCreateRule => 'Could not create rule';

  @override
  String get tagDetailRuleUpdated => 'Rule updated';

  @override
  String get tagDetailCouldNotUpdateRule => 'Could not update rule';

  @override
  String get tagDetailCouldNotChangeRuleStatus =>
      'Could not change rule status';

  @override
  String get tagDetailDeleteRuleConfirm => 'Delete rule?';

  @override
  String tagDetailDeleteRuleMessage(String name) {
    return 'Are you sure you want to delete \"$name\"?';
  }

  @override
  String get tagDetailRuleDeleted => 'Rule deleted';

  @override
  String get tagDetailCouldNotDeleteRule => 'Could not delete rule';

  @override
  String get tagDetailApplyingRules => 'Applying rules to recipes...';

  @override
  String tagDetailRulesAppliedSuccess(int tagsApplied, int recipesModified) {
    return '$tagsApplied tags applied to $recipesModified recipes';
  }

  @override
  String get tagDetailNoRecipesMatched => 'No recipes matched the rules';

  @override
  String get tagDetailCouldNotApplyRules => 'Could not apply rules';

  @override
  String get tagDetailDeleteTagConfirm => 'Delete tag?';

  @override
  String tagDetailDeleteTagMessage(String name) {
    return 'Are you sure you want to delete \"$name\"? The tag will be removed from all recipes.';
  }

  @override
  String get tagDetailDeleted => 'Tag deleted';

  @override
  String get tagDetailCouldNotDelete => 'Could not delete tag';

  @override
  String tagDetailRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return '$_temp0';
  }

  @override
  String tagDetailRulesActive(int enabled, int total) {
    return '$enabled/$total rules active';
  }

  @override
  String get tagDetailRuleCalculating => 'Calculating...';

  @override
  String tagDetailRuleMatches(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes match',
      one: '1 recipe matches',
    );
    return '$_temp0';
  }

  @override
  String get tagDetailRuleNoConditions => 'No conditions';

  @override
  String get tagDetailRuleOperatorAnd => ' AND ';

  @override
  String get tagDetailRuleOperatorOr => ' OR ';

  @override
  String tagDetailRuleMoreConditions(int count) {
    return '(+$count more)';
  }

  @override
  String get tagDetailRulesDescription =>
      'Rules automatically apply the tag to recipes that match the conditions.';

  @override
  String get tagDetailRulesTitle => 'Automation Rules';

  @override
  String get tagDetailRulesEmptyTitle => 'No rules yet';

  @override
  String get tagDetailRulesEmptySubtitle =>
      'Create rules to automatically tag recipes';

  @override
  String get tagDetailRulesCreateFirst => 'Create first rule';

  @override
  String get tagAlreadyExists => 'Tag already exists';

  @override
  String get tagManageTags => 'Manage tags';

  @override
  String get tagActiveTags => 'Active tags';

  @override
  String get tagRemovedTags => 'Removed tags';

  @override
  String get tagAddNewTag => 'Add new tag';

  @override
  String get tagWriteTagHint => 'Write a tag...';

  @override
  String get tagEnterTag => 'Enter a tag';

  @override
  String get tagMinTwoChars => 'At least 2 characters';

  @override
  String get tagAddTag => 'Add tag';

  @override
  String get tagManuallyAdded => 'Manually added';

  @override
  String get tagAutoGenerated => 'Auto-generated';

  @override
  String get tagClickToRestore => 'Click to restore';

  @override
  String get allergenSettingsTitle => 'Allergens & dietary';

  @override
  String get allergenSettingsHubSubtitle =>
      'Update your allergens and dietary preferences anytime';

  @override
  String get settingsAutoAddPantryTitle => 'Add bought items to pantry';

  @override
  String get settingsAutoAddPantrySubtitle =>
      'When you check off a shopping item, it\'s added to your pantry automatically';

  @override
  String get pantryAutoAddPromptTitle => 'Add to pantry automatically?';

  @override
  String get pantryAutoAddPromptBody =>
      'Want bought items added to your pantry automatically when you check them off? You can change this later in Settings.';

  @override
  String get pantryAutoAddPromptEnable => 'Yes, add automatically';

  @override
  String get pantryAutoAddPromptDecline => 'Not now';

  @override
  String get allergenTrackAllergensTitle => 'Track Allergens';

  @override
  String get allergenTrackAllergensSubtitle =>
      'Select which allergens you want to see status for on recipes.';

  @override
  String get allergenTrackDietaryTitle => 'Track Dietary Preferences';

  @override
  String get allergenTrackDietarySubtitle =>
      'Select which dietary preferences you want to see status for.';

  @override
  String get allergenDisplayTitle => 'Display on';

  @override
  String get allergenDisplayOnCardsTitle => 'Recipe Cards';

  @override
  String get allergenDisplayOnCardsSubtitle =>
      'Show allergen status on recipe cards in lists';

  @override
  String get allergenDisplayOnDetailTitle => 'Recipe Details';

  @override
  String get allergenDisplayOnDetailSubtitle =>
      'Show complete allergen status on recipe page';

  @override
  String get allergenDisplayCoverageTitle => 'Coverage Indicator';

  @override
  String get allergenDisplayCoverageSubtitle =>
      'Show what proportion of ingredients are known';

  @override
  String get allergenSaveSettings => 'Save Settings';

  @override
  String get allergenResetToDefaults => 'Reset to Defaults';

  @override
  String get allergenSettingsSaved => 'Settings saved';

  @override
  String get allergenResetConfirm => 'Reset settings?';

  @override
  String get allergenResetMessage =>
      'This will reset all allergen and dietary preferences to default values.';

  @override
  String get allergenReset => 'Reset';

  @override
  String get personalTagWizardAddRule => 'Add a rule?';

  @override
  String personalTagWizardAddRuleMessage(String name) {
    return 'Do you want to create an automation rule for \"$name\"?\n\nRules can automatically add this tag to recipes based on ingredients, source, time, and more.';
  }

  @override
  String get personalTagWizardLater => 'Later';

  @override
  String get personalTagWizardYesCreateRule => 'Yes, create rule';

  @override
  String get personalTagPreview => 'Preview';

  @override
  String get personalTagCouldNotLoad => 'Could not load tags';

  @override
  String get personalTagManage => 'Manage';

  @override
  String personalTagChipSelectedA11y(String name) {
    return '$name, selected. Double tap to remove.';
  }

  @override
  String personalTagChipUnselectedA11y(String name) {
    return '$name. Double tap to select.';
  }

  @override
  String personalTagA11yLabel(String name) {
    return 'Tag: $name';
  }

  @override
  String get personalTagManagerTitle => 'My tags';

  @override
  String get personalTagManagerRulesTab => 'Rules';

  @override
  String get personalTagNewTag => 'New tag';

  @override
  String get personalTagCreateTagFirst => 'Create a tag first';

  @override
  String get personalTagNeedTagForRules =>
      'You need at least one tag to create automation rules.';

  @override
  String personalTagCreatedDate(String date) {
    return 'Created $date';
  }

  @override
  String get personalTagCreateRuleForTag => 'Create rule for tag';

  @override
  String get personalTagAddRule => 'Add rule';

  @override
  String get personalTagApplyRulesTitle => 'Apply rules to existing recipes';

  @override
  String get personalTagApplyRulesMessage =>
      'This will review all your recipes and add tags according to your enabled rules.\n\nTags already on recipes will not be affected.';

  @override
  String get personalTagApplyRulesRun => 'Run';

  @override
  String personalTagApplyRulesProgress(int progress, int total) {
    return 'Processing recipe $progress of $total...';
  }

  @override
  String get personalTagApplyRulesFetching => 'Fetching recipes...';

  @override
  String get personalTagSelectColor => 'Select color';

  @override
  String get ruleEditTitle => 'Edit rule';

  @override
  String get ruleCreateTitle => 'Create rule';

  @override
  String get ruleNewTitle => 'New rule';

  @override
  String get ruleNameLabel => 'Rule name';

  @override
  String get ruleNameHint => 'E.g. \"Fish recipes\"';

  @override
  String get ruleNameRequired => 'Enter a rule name';

  @override
  String get ruleApplyToTag => 'Apply to tag';

  @override
  String get ruleSelectTag => 'Select a tag';

  @override
  String get ruleMatchModeLabel => 'Match mode';

  @override
  String get ruleMatchModeAllConditions => 'All conditions (AND)';

  @override
  String get ruleMatchModeAnyCondition => 'Any condition (OR)';

  @override
  String get ruleMatchModeAllShort => 'All (AND)';

  @override
  String get ruleMatchModeAnyShort => 'Any (OR)';

  @override
  String get ruleMatchModeAll => 'all';

  @override
  String get ruleMatchModeAny => 'any';

  @override
  String get ruleConditionsLabel => 'Conditions';

  @override
  String get ruleConditionCountSingular => '1 condition';

  @override
  String ruleConditionCountWithMode(int count, String mode) {
    return '$count conditions, $mode must match';
  }

  @override
  String get ruleEnabledTitle => 'Rule enabled';

  @override
  String get ruleEnabledSubtitle => 'Rule is applied to recipes';

  @override
  String get ruleEnabledNewRecipes => 'Rule is applied to new recipes';

  @override
  String get rulePausedSubtitle => 'Rule is paused';

  @override
  String get ruleApplyToExisting => 'Apply to existing recipes';

  @override
  String get ruleTagMatchingImmediately => 'Tag matching recipes immediately';

  @override
  String get ruleRemoveCondition => 'Remove condition';

  @override
  String get ruleSelectProperty => 'Select property...';

  @override
  String get ruleAllConditionsNeedValue => 'All conditions must have a value';

  @override
  String get ruleHintIngredient => 'E.g. \"chicken\", \"salmon\"';

  @override
  String get ruleHintProperty => 'E.g. \"seafood\", \"meat\", \"dairy\"';

  @override
  String get ruleHintKeyword => 'E.g. \"quick\", \"vegetarian\"';

  @override
  String get ruleHintSourceUrl => 'E.g. \"bbc.com\", \"reddit.com\"';

  @override
  String get ruleHintCuisine => 'E.g. \"italian\", \"asian\"';

  @override
  String get ruleHintDietary => 'E.g. \"vegetarian\", \"vegan\"';

  @override
  String get ruleHintTime => 'Cooking time in minutes';

  @override
  String get ruleHintTimeShort => 'Time in minutes';

  @override
  String get ruleHintRating => 'Rating (1-5)';

  @override
  String get ruleHintRecency => 'Days since recipe was added';

  @override
  String get ruleHintRecencyShort => 'Number of days';

  @override
  String get ruleHintOwnership =>
      'E.g. \"personal\", \"shared\", \"collaborative\"';

  @override
  String get ruleHintHasImage => 'true or false';

  @override
  String get ruleHintCompleteness => 'E.g. \"description\", \"ingredients\"';

  @override
  String get ruleCategoryAllergens => 'Allergens';

  @override
  String get ruleCategoryLactose => 'Lactose';

  @override
  String get ruleCategoryMeat => 'Meat';

  @override
  String get ruleCategorySeafood => 'Fish & seafood';

  @override
  String get ruleCategoryAnimal => 'Animal';

  @override
  String get ruleCategoryDiet => 'Diet';

  @override
  String get ruleCategoryOther => 'Other';

  @override
  String get tagResultNoAllergens => 'No allergens to display';

  @override
  String get tagResultOutdated => 'Tags can be updated';

  @override
  String get tagResultCoverage => 'Coverage';

  @override
  String tagResultUnknownIngredients(int count) {
    return '$count unknown ingredients';
  }

  @override
  String tagResultUnknownIngredientsA11y(int count) {
    return '$count unknown ingredients';
  }

  @override
  String dietaryStatusFreeA11y(String name) {
    return 'Suitable for $name diet';
  }

  @override
  String dietaryStatusContainsA11y(String name) {
    return 'Not suitable for $name diet';
  }

  @override
  String dietaryStatusUnknownA11y(String name) {
    return '$name status unknown';
  }

  @override
  String dietaryStatusNotLabel(String name) {
    return 'Not $name';
  }

  @override
  String dietaryStatusUnknownLabel(String name) {
    return '$name: unknown';
  }

  @override
  String allergenStatusFreeA11y(String name) {
    return 'Free from $name';
  }

  @override
  String allergenStatusContainsA11y(String name) {
    return 'Contains $name';
  }

  @override
  String allergenStatusUnknownA11y(String name) {
    return '$name status unknown';
  }

  @override
  String allergenFreeLabel(String name) {
    return '$name-free';
  }

  @override
  String allergenContainsLabel(String name) {
    return 'contains $name';
  }

  @override
  String allergenUnknownLabel(String name) {
    return '$name unknown';
  }

  @override
  String friendMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get friendCategoryLabel => 'Category';

  @override
  String get friendCategoryStatistics => 'Category statistics';

  @override
  String get friendCategories => 'Categories';

  @override
  String get friendTotalMembers => 'Total members';

  @override
  String get friendAverage => 'Average';

  @override
  String friendLargestCategory(String name, int count) {
    return 'Largest category: $name ($count members)';
  }

  @override
  String friendCategoryCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0';
  }

  @override
  String friendTotalMembersCount(int count) {
    return '$count total members';
  }

  @override
  String get friendCreateFirstCategory => 'Create your first friend category';

  @override
  String get friendCreateCategory => 'Create category';

  @override
  String get friendSelectCategories => 'Select categories';

  @override
  String get friendCreateNewCategory => 'Create new category';

  @override
  String get friendSelectedCategories => 'Selected categories';

  @override
  String friendSelectedCategoriesSummary(int count, int friends) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories',
      one: '1 category',
    );
    return '$_temp0 ($friends friends)';
  }

  @override
  String friendCategoriesSelected(int count) {
    return '$count categories selected';
  }

  @override
  String friendFriendsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends',
      one: '1 friend',
      zero: 'No friends',
    );
    return '$_temp0';
  }

  @override
  String get friendFriendsLabel => 'friends';

  @override
  String get friendLoadingFriendsAndCategories =>
      'Loading friends and categories...';

  @override
  String get friendNoFriendsOrCategories => 'No friends or categories';

  @override
  String get friendAddFriendsAndCategoriesFirst =>
      'Add friends and create categories first';

  @override
  String get friendManageFriends => 'Manage friends';

  @override
  String get friendSelectCategoriesOrFriends =>
      'Select categories or individual friends';

  @override
  String get friendSelectCategoriesForQuickShare =>
      'Select entire categories for quick sharing';

  @override
  String get friendIndividualSelection => 'Individual selection';

  @override
  String get friendSelectSpecificFriends =>
      'Select specific friends from your friend list';

  @override
  String get friendNoFriendsToShow => 'No friends to show';

  @override
  String get friendAddFriendsFirst => 'Add friends first';

  @override
  String get friendSelectedFriends => 'Selected friends';

  @override
  String friendSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends selected',
      one: '1 friend selected',
    );
    return '$_temp0';
  }

  @override
  String shoppingItemsWillBeRemoved(int count) {
    return '$count items will be removed.';
  }

  @override
  String shoppingItemsFromMenuIn(int count, String name) {
    return '$count items from the menu in \"$name\"';
  }

  @override
  String get shoppingItemHint => 'E.g. Milk';

  @override
  String get shoppingItems => 'items';

  @override
  String get shoppingPersonal => 'Personal';

  @override
  String get shoppingShared => 'Shared';

  @override
  String get shoppingTemplate => 'Template';

  @override
  String get shoppingActive => 'Active';

  @override
  String get shoppingRecentItems => 'Recent items:';

  @override
  String shoppingAndMore(int count) {
    return '... and $count more';
  }

  @override
  String get shoppingOwner => 'Owner';

  @override
  String get shoppingCanView => 'Can view';

  @override
  String get shoppingCanEdit => 'Can edit';

  @override
  String get shoppingAdmin => 'Admin';

  @override
  String get shoppingCreateFirstList => 'Create your first shopping list...';

  @override
  String get shoppingPreviewAndEditItems => 'Preview and edit items';

  @override
  String get shoppingNoItemsSelected => 'No items selected';

  @override
  String get shoppingAllItemsRemovedFromMenu =>
      'You have removed all items from the menu';

  @override
  String get shoppingRemoveItem => 'Remove item';

  @override
  String get shoppingRemoveAll => 'Remove all';

  @override
  String shoppingToListWithCount(String name, int count) {
    return 'To \"$name\" ($count)';
  }

  @override
  String get shoppingLoadingLists => 'Loading lists...';

  @override
  String get shoppingLists => 'Shopping lists';

  @override
  String get shoppingNewList => 'New list';

  @override
  String shoppingNewListNameTemplate(String title) {
    return '$title - Ingredients';
  }

  @override
  String get shoppingAddFromMenu => 'Add from menu';

  @override
  String get shoppingNoItemsFromMenu => 'No items selected from menu';

  @override
  String get shoppingPreview => 'Preview';

  @override
  String get shoppingAdding => 'Adding...';

  @override
  String get shoppingNoItemsToAdd => 'No items to add';

  @override
  String shoppingListCreated(String name) {
    return 'List \"$name\" created';
  }

  @override
  String get profileSocialFeatures => 'Social features';

  @override
  String get profileEditProfile => 'Edit profile';

  @override
  String get profileEditProfileSubtitle =>
      'Update your name and profile picture';

  @override
  String get profileFriendsAndGroups => 'Friends and groups';

  @override
  String get profileFriendsAndGroupsSubtitle =>
      'Manage your friends and groups';

  @override
  String get profileSharedWithMe => 'Shared with me';

  @override
  String get profileSharedWithMeSubtitle => 'Recipes and menus shared with you';

  @override
  String get profileMessages => 'Messages';

  @override
  String get profileMessagesSubtitle => 'Your conversations and messages';

  @override
  String get profileAllergenSettings => 'Allergen settings';

  @override
  String get profileAllergenSettingsSubtitle =>
      'Select which allergens you want to track';

  @override
  String get profileMyTags => 'My tags';

  @override
  String get profileMyTagsSubtitle => 'Manage your personal tags';

  @override
  String get profileCloseMenu => 'Close profile menu';

  @override
  String get profileRecipes => 'Recipes';

  @override
  String get profileMenus => 'Menus';

  @override
  String get profileFriends => 'Friends';

  @override
  String get profileDownloadBackup => 'Download backup';

  @override
  String get profileDownloadBackupSubtitle => 'Save all recipes as JSON';

  @override
  String get profileRestoreFromBackup => 'Restore from backup';

  @override
  String get profileRestoreFromBackupSubtitle => 'Import recipes from JSON';

  @override
  String get profileAccountManagement => 'Account management';

  @override
  String get profilePrivacyPolicy => 'Privacy policy';

  @override
  String get profilePrivacyPolicySubtitle =>
      'Read about how we handle your personal data (GDPR)';

  @override
  String get profileDeleteAccountSubtitle =>
      'Delete your account and all data permanently';

  @override
  String profileLogoutFailed(String error) {
    return 'Logout failed: $error';
  }

  @override
  String get profileAccountDeletedPermanently =>
      'Your account has been permanently deleted';

  @override
  String get profileAccountCouldNotBeFullyDeleted =>
      'Account could not be fully deleted. Contact support.';

  @override
  String get profileAuthenticationFailed => 'Authentication failed';

  @override
  String profileBackupFailed(String error) {
    return 'Backup failed: $error';
  }

  @override
  String get profileRestoreCompleted => 'Restore completed!';

  @override
  String profileRestoreFailed(String error) {
    return 'Restore failed: $error';
  }

  @override
  String profileCouldNotOpenPrivacyPolicy(String error) {
    return 'Could not open privacy policy: $error';
  }

  @override
  String profileCouldNotOpenDataExport(String error) {
    return 'Could not open data export: $error';
  }

  @override
  String get shareRecipeTitle => 'Share recipe';

  @override
  String get shareMenuTitle => 'Share menu';

  @override
  String get shareShoppingListTitle => '🛒 SHOPPING LIST';

  @override
  String get shareCreateAndShare => 'Create & Share';

  @override
  String get shareRecipeWithFriends => 'Share recipe with friends';

  @override
  String get shareMenuWithFriends => 'Share weekly menu with friends';

  @override
  String get shareShoppingList => 'Share shopping list';

  @override
  String get shareRealtime => 'realtime sharing';

  @override
  String get shareSelectAtLeastOneFriend =>
      'Select at least one friend to share';

  @override
  String get shareSelected => 'selected';

  @override
  String shareRecipesInCategories(int recipes, int categories) {
    return '$recipes recipes in $categories categories';
  }

  @override
  String get shareNoFriendsToShareWith => 'No friends to share with';

  @override
  String get shareAddFriendsToShare =>
      'You need to add friends to be able to share content. Go to your profile and add friends.';

  @override
  String get shareAddFriends => 'Add friends';

  @override
  String get shareErrorOccurred => 'An error occurred';

  @override
  String get shareSucceeded => 'Sharing succeeded!';

  @override
  String get shareRecipes => 'recipes';

  @override
  String get shareMessageOptional => 'Message (optional)';

  @override
  String get shareWriteMessage => 'Write a message...';

  @override
  String get shareMethod => 'Sharing method';

  @override
  String get shareStaticCopy => 'Static copy';

  @override
  String get shareStaticCopyDescription =>
      'Send a copy that the recipient can modify freely';

  @override
  String get shareRealtimeSharing => 'Realtime sharing';

  @override
  String get shareRealtimeSharingDescription =>
      'Everyone can edit together in realtime';

  @override
  String get shareRealtimeShoppingDescription =>
      'Everyone can add and check off items in realtime';

  @override
  String get shareSelectRecipients => 'Select recipients';

  @override
  String get shareSearchFriends => 'Search friends...';

  @override
  String get shareSearchGroups => 'Search groups...';

  @override
  String get shareNoFriendsAvailable => 'No friends available';

  @override
  String get shareNoFriendsMatchedSearch => 'No friends matched your search';

  @override
  String get shareNoGroupsAvailable => 'No groups available';

  @override
  String get shareNoGroupsMatchedSearch => 'No groups matched your search';

  @override
  String get shareAlreadySharingList => 'Already sharing list';

  @override
  String get menuSavedMenus => 'Saved menus';

  @override
  String get menuNoSavedMenus => 'No saved menus';

  @override
  String get menuCommentHint => 'Description or notes about the menu';

  @override
  String get menuShareWithFriends => 'Share with friends';

  @override
  String get menuSelectFriendsToShare => 'Select friends to share with';

  @override
  String get menuNoFriendsAvailable => 'No friends available';

  @override
  String get menuShareMessageLabel => 'Share message';

  @override
  String get menuShareMessageHint => 'Message sent with the menu';

  @override
  String get socialShared => 'Shared';

  @override
  String get socialEditRecipe => 'Edit recipe';

  @override
  String get socialEditingTogether => 'You are editing together with others';

  @override
  String get socialChangesSyncAutomatically =>
      'Changes sync automatically with other participants';

  @override
  String get socialActive => 'Active';

  @override
  String get socialParticipants => 'Participants';

  @override
  String get socialViewAll => 'View all';

  @override
  String socialSharedRecipeMembers(int count) {
    return 'Shared recipe • $count members';
  }

  @override
  String socialSharedMenuMembers(int count) {
    return 'Shared menu • $count members';
  }

  @override
  String get socialActiveCollaboration => 'Active collaboration';

  @override
  String get socialInactive => 'Not active';

  @override
  String get socialCollaborationStatistics => 'Collaboration statistics';

  @override
  String get socialMembers => 'Members';

  @override
  String get socialActiveEditors => 'Active';

  @override
  String get socialChanges => 'Changes';

  @override
  String socialLastActive(String time) {
    return 'Last active: $time';
  }

  @override
  String get socialPermissionOwner => 'Owner';

  @override
  String get socialPermissionAdmin => 'Admin';

  @override
  String get socialPermissionEditor => 'Edit';

  @override
  String get socialPermissionViewer => 'View';

  @override
  String get socialPermissionUnknown => 'Unknown';

  @override
  String get socialAddCategory => 'Add category';

  @override
  String get socialNewCategory => 'New category';

  @override
  String get socialFilterCategories => 'Filter categories';

  @override
  String get socialSortCategories => 'Sort categories';

  @override
  String get socialAveragePerCategory => 'Average/category';

  @override
  String get socialLargestCategory => 'Largest category';

  @override
  String get socialCreateFirstCategory =>
      'Create your first friend category to get started';

  @override
  String get socialLoadingCategories => 'Loading categories...';

  @override
  String get socialInvertLabel => 'Invert';

  @override
  String get invitationNoTargetsAvailable => 'No targets available';

  @override
  String get invitationSearchTargets => 'Search targets...';

  @override
  String get invitationSelectedTargets => 'Selected targets';

  @override
  String invitationTargetsSelected(int count) {
    return '$count targets selected';
  }

  @override
  String get invitationSortLabel => 'Sort:';

  @override
  String get invitationSortByName => 'Name';

  @override
  String get invitationSortByType => 'Type';

  @override
  String get invitationSortByMembers => 'Members';

  @override
  String get invitationIndividuals => 'Individuals';

  @override
  String get invitationSendInvitations => 'Send invitations';

  @override
  String get invitationAffectedTargets => 'Affected targets:';

  @override
  String get invitationView => 'View';

  @override
  String get invitationSendInvitation => 'Send invitation';

  @override
  String get invitationInvite => 'Invite';

  @override
  String get invitationLoadingTargets => 'Loading targets...';

  @override
  String get invitationNetworkError => 'Network error';

  @override
  String get invitationCheckConnection => 'Check your internet connection.';

  @override
  String get invitationNoAccessTitle => 'No access';

  @override
  String get invitationNoAccessSubtitle =>
      'You don\'t have permission to view this information.';

  @override
  String get invitationTargetsLoaded => 'Targets loaded!';

  @override
  String get invitationNoSearchResults => 'No search results';

  @override
  String invitationNoResultsFor(String query) {
    return 'No results for \"$query\"';
  }

  @override
  String invitationTargetsSelectedCount(int count) {
    return '$count targets selected';
  }

  @override
  String get invitationNoSelectionsMade => 'No selections made';

  @override
  String get socialSharedRecipes => 'Shared recipes';

  @override
  String get socialSharedMenus => 'Shared menus';

  @override
  String get socialActiveCollaborations => 'Active collaborations';

  @override
  String get socialSent => 'Sent';

  @override
  String get socialReceived => 'Received';

  @override
  String get socialAccepted => 'Accepted';

  @override
  String get socialPending => 'Pending';

  @override
  String get commonUser => 'User';

  @override
  String get commonDone => 'Done';

  @override
  String get commonClearError => 'Clear error';

  @override
  String get commonClearSearch => 'Clear search';

  @override
  String get commonComingSoon => 'Coming soon...';

  @override
  String get commonDiscard => 'Discard';

  @override
  String get commonFailed => 'Failed';

  @override
  String get commonImporting => 'Importing...';

  @override
  String get commonLater => 'Later';

  @override
  String get commonMessage => 'Message:';

  @override
  String get commonPending => 'Pending';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonSaving => 'Saving...';

  @override
  String get commonSending => 'Sending...';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonUploading => 'Uploading...';

  @override
  String get authLogIn => 'Log in';

  @override
  String get collaborativeListNoAccess =>
      'The list may have been deleted or you no longer have access';

  @override
  String get collaborativeListNotFound => 'List not found';

  @override
  String get collaborativeLoadingSharedList => 'Loading shared list...';

  @override
  String get allergenCrustacean => 'Crustacean';

  @override
  String get allergenDairy => 'Dairy';

  @override
  String get allergenEgg => 'Egg';

  @override
  String get allergenFish => 'Fish';

  @override
  String get allergenGluten => 'Gluten';

  @override
  String get allergenPeanut => 'Peanut';

  @override
  String get allergenSoy => 'Soy';

  @override
  String get allergenTreeNut => 'Tree nut';

  @override
  String get commentCouldNotPost => 'Could not post comment';

  @override
  String get commentPosted => 'Comment posted';

  @override
  String recipeCommentVisibleTo(String audience) {
    return 'Visible to: $audience';
  }

  @override
  String recipeCommentVisiblePeople(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get recipeCommentAudienceTitle => 'Visible to';

  @override
  String recipeCommentAudienceOthers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'and $count more people',
      one: 'and 1 more person',
    );
    return '$_temp0';
  }

  @override
  String get commentReply => 'Reply';

  @override
  String get commentReplyingTo => 'Replying to';

  @override
  String get commentWriteComment => 'Write a comment';

  @override
  String get commentWriteReply => 'Write a reply';

  @override
  String get commentYou => 'You';

  @override
  String get commentAttachImage => 'Attach image';

  @override
  String get commentImageUploadError =>
      'Could not upload the image. Please try again.';

  @override
  String get commentRemoveImage => 'Remove image';

  @override
  String get a11yCommentImageThumbnail => 'View attached image full screen';

  @override
  String get a11yCommentRemoveSelectedImage => 'Remove selected image';

  @override
  String get a11yCloseImageViewer => 'Close image viewer';

  @override
  String dialogAddRecipesToCategory(String categoryName) {
    return 'Add recipes to $categoryName';
  }

  @override
  String get dialogAlreadyShared => 'Shared';

  @override
  String get dialogAlternatives => 'Alternatives:';

  @override
  String get dialogClearSelection => 'Clear selection';

  @override
  String get dialogContainsAllergens => 'Contains allergens:';

  @override
  String dialogCouldNotSave(String error) {
    return 'Could not save: $error';
  }

  @override
  String get dialogCreateList => 'Create list';

  @override
  String get dialogCreateNewListForIngredients =>
      'Create a new list for these ingredients';

  @override
  String get dialogDietaryProperties => 'Dietary properties:';

  @override
  String get dialogEnterListName => 'Enter a name for the list';

  @override
  String dialogFilteredRecipeCount(int filtered, int total) {
    return '$filtered of $total recipes';
  }

  @override
  String get dialogImportWithoutAi => 'Import without AI';

  @override
  String get dialogItems => 'items';

  @override
  String dialogItemsProgress(int completed, int total) {
    return '$completed/$total done';
  }

  @override
  String get dialogLoadingMenus => 'Loading menus...';

  @override
  String get dialogLoadingRecipes => 'Loading recipes...';

  @override
  String get dialogManualImport => 'Manual import';

  @override
  String get dialogMarkIngredientsYourself => 'Mark ingredients yourself';

  @override
  String get dialogMayTakeAWhile => 'This may take a while...';

  @override
  String get dialogNameMinTwoChars => 'Name must be at least 2 characters';

  @override
  String get dialogNoEditableShoppingLists =>
      'You have no editable shopping lists. Only lists you can edit are shown here. Create a new list above.';

  @override
  String get dialogNoMenus => 'No menus';

  @override
  String get dialogNoMenusToShare => 'You have no menus to share yet';

  @override
  String get dialogNoRecipes => 'No recipes';

  @override
  String get dialogNoRecipesToShare => 'You have no recipes to share yet';

  @override
  String get dialogNoShoppingLists => 'No shopping lists';

  @override
  String get dialogNoShoppingListsToShare =>
      'You have no shopping lists to share yet';

  @override
  String get dialogOrSelectExistingList => 'Or select an existing list:';

  @override
  String get dialogPrivate => 'Private';

  @override
  String dialogRetryInHours(int hours) {
    return 'Try again in $hours hour(s)';
  }

  @override
  String dialogRetryInMinutes(int minutes) {
    return 'Try again in $minutes minute(s)';
  }

  @override
  String dialogRetryInSeconds(int seconds) {
    return 'Try again in $seconds second(s)';
  }

  @override
  String get dialogRetryLater => 'Try later';

  @override
  String get dialogRetryTomorrow => 'Try again tomorrow';

  @override
  String get dialogSearchRecipes => 'Search recipes...';

  @override
  String get dialogSearchRecipesToAdd => 'Search recipes to add...';

  @override
  String dialogSelectedCount(int count) {
    return 'Selected ($count)';
  }

  @override
  String get dialogShared => 'Shared';

  @override
  String dialogShareMenuWith(String groupName) {
    return 'Share menu with $groupName';
  }

  @override
  String dialogShareRecipesWith(String name) {
    return 'Share recipes with $name';
  }

  @override
  String dialogShareShoppingListWith(String groupName) {
    return 'Share shopping list with $groupName';
  }

  @override
  String get dialogSharing => 'Sharing...';

  @override
  String get dialogShoppingListNameHint => 'E.g. \"Pancakes - Ingredients\"';

  @override
  String get dialogUnknownIngredientDescription =>
      'This ingredient is not in the database. You can define its properties for better tagging.';

  @override
  String dialogUnknownIngredientProgress(int current, int total) {
    return 'Unknown ingredient $current/$total';
  }

  @override
  String get dialogUsesSimpleExtraction => 'Uses simpler extraction';

  @override
  String get dietaryAlcohol => 'Alcohol';

  @override
  String get dietaryAnimalProduct => 'Animal product';

  @override
  String get dietaryBeef => 'Beef';

  @override
  String get dietaryMeat => 'Meat';

  @override
  String get dietaryPork => 'Pork';

  @override
  String get dietaryPoultry => 'Poultry';

  @override
  String get dietarySeafood => 'Seafood';

  @override
  String get dietarySpicy => 'Spicy';

  @override
  String get draftContinueEditing => 'Continue editing';

  @override
  String get draftDiscardAll => 'Discard all';

  @override
  String get draftUnsavedFound => 'Unsaved drafts found';

  @override
  String get groupContentTypeContent => 'Content';

  @override
  String get groupContentTypeMenu => 'Menu';

  @override
  String get groupContentTypeRecipe => 'Recipe';

  @override
  String get groupContentTypeShoppingList => 'Shopping list';

  @override
  String get groupCopiedToClipboard => 'Copied to clipboard';

  @override
  String groupCouldNotCopyList(String error) {
    return 'Could not copy list: $error';
  }

  @override
  String get groupCouldNotFetchMenu => 'Could not fetch menu from server';

  @override
  String get groupCouldNotFetchRecipe => 'Could not fetch recipe from server';

  @override
  String groupCouldNotImportList(String error) {
    return 'Could not import list: $error';
  }

  @override
  String get groupCreateNew => 'Create new group';

  @override
  String get groupDeleteConfirmPrefix =>
      'Are you sure you want to delete the group ';

  @override
  String get groupDeleteTheGroup => 'Delete the group';

  @override
  String get groupDeleteWarning => 'All members will leave the group.';

  @override
  String get groupDeleteWhenLeaving =>
      'Do you want to delete the group when you leave?';

  @override
  String get groupDescriptionHint => 'What is this group about?';

  @override
  String get groupDescriptionLabel => 'Description (optional)';

  @override
  String groupErrorOpeningMenu(String error) {
    return 'Error opening menu: $error';
  }

  @override
  String groupErrorOpeningRecipe(String error) {
    return 'Error opening recipe: $error';
  }

  @override
  String get groupImport => 'Import';

  @override
  String groupImportingMenuComingSoon(String title) {
    return 'Importing menu: $title (coming soon)';
  }

  @override
  String groupImportingRecipeComingSoon(String title) {
    return 'Importing recipe: $title (coming soon)';
  }

  @override
  String groupImportingShoppingListComingSoon(String title) {
    return 'Importing shopping list: $title (coming soon)';
  }

  @override
  String groupImportNotImplemented(String title) {
    return 'Import $title (not yet implemented)';
  }

  @override
  String get groupImportShoppingList => 'Import shopping list';

  @override
  String groupImportShoppingListConfirm(String name) {
    return 'Do you want to import \"$name\" to your shopping lists?';
  }

  @override
  String get groupInvitationNote =>
      'These friends will receive an invitation to the group.';

  @override
  String get groupIsEmpty => 'The group is empty';

  @override
  String get groupListCopiedToClipboard => 'List copied to clipboard';

  @override
  String groupListCopyName(String name) {
    return 'Copy of $name';
  }

  @override
  String groupListImported(String name) {
    return '\"$name\" has been imported';
  }

  @override
  String get groupNameHint => 'E.g. \"Family\", \"Work\", \"Book club\"';

  @override
  String get groupNoFriendsToAdd =>
      'You have no friends to add yet. Add friends first to create groups with them.';

  @override
  String get groupNoMenusShared => 'No menus shared';

  @override
  String get groupNoMenusSharedSubtitle =>
      'Share menus with the group to plan together';

  @override
  String get groupNoRecipesShared => 'No recipes shared';

  @override
  String get groupNoRecipesSharedSubtitle =>
      'Share recipes with the group to inspire each other';

  @override
  String get groupNoShoppingListsShared => 'No shopping lists shared';

  @override
  String get groupNoShoppingListsSharedSubtitle =>
      'Share shopping lists with the group to collaborate';

  @override
  String groupOnlyMember(String name) {
    return 'You are the only member in \"$name\".';
  }

  @override
  String get groupPasteInAnyApp => 'Paste in any app';

  @override
  String groupRecipeImportedSuccess(String title) {
    return 'Recipe \"$title\" imported successfully';
  }

  @override
  String groupRecipeImportFailed(String error) {
    return 'Could not import recipe: $error';
  }

  @override
  String groupRecipeViewComingSoon(String title) {
    return 'Recipe view: $title (coming soon)';
  }

  @override
  String get groupRemoveMemberConfirmPrefix =>
      'Are you sure you want to remove ';

  @override
  String get groupRemoveMemberFromGroup => ' from the group ';

  @override
  String get groupRemoveMemberWarning =>
      'The member will lose access to the group\'s content.';

  @override
  String groupSelectedMembers(int count) {
    return 'Selected members ($count)';
  }

  @override
  String get groupSelectFriendsToInvite =>
      'Select friends to invite to the group';

  @override
  String get groupSelectIcon => 'Select icon';

  @override
  String get groupSelectMembers => 'Select members';

  @override
  String get groupSelectNewOwner => 'Select new owner:';

  @override
  String get groupSelectShareTarget => 'Select who to share with';

  @override
  String get groupSendToFriends => 'Send to friends in Butlery';

  @override
  String groupSharedBy(String name) {
    return 'Shared by $name';
  }

  @override
  String get groupSharedContent => 'Shared content';

  @override
  String get groupShareShoppingList => 'Share shopping list';

  @override
  String get groupShareWithFriendsInButlery => 'Share with friends in Butlery';

  @override
  String groupShoppingListViewComingSoon(String title) {
    return 'Shopping list view: $title (coming soon)';
  }

  @override
  String get groupTabLists => 'Lists';

  @override
  String get groupTabMenus => 'Menus';

  @override
  String get groupTransferOwnership => 'Transfer group ownership';

  @override
  String groupTransferOwnershipMessage(String name) {
    return 'You are the owner of \"$name\". You must select a new owner before you can leave the group.';
  }

  @override
  String get groupView => 'View';

  @override
  String groupViewNotImplemented(String title) {
    return 'View $title (not yet implemented)';
  }

  @override
  String profileCouldNotOpenConsentManagement(String error) {
    return 'Could not open consent management: $error';
  }

  @override
  String get profileDataBackup => 'Data & Backup';

  @override
  String get profileExportData => 'Export my data';

  @override
  String get profileExportDataSubtitle =>
      'Download all your data in JSON format (GDPR)';

  @override
  String get profileManageConsent => 'Manage consents';

  @override
  String get profileManageConsentSubtitle =>
      'Choose how we may process your personal data (GDPR)';

  @override
  String get rateLimitAiBudget => 'AI budget exhausted';

  @override
  String get rateLimitAiLimit => 'AI limit reached';

  @override
  String get rateLimitDailyQuota => 'Daily quota reached';

  @override
  String get rateLimitSlowDown => 'Slow down a bit';

  @override
  String get sessionContinue => 'Continue session';

  @override
  String get sessionContinueOrLogout =>
      'Do you want to continue your session or log out now?';

  @override
  String get sessionExpiringMessage => 'Your session will expire in:';

  @override
  String get sessionExpiringTitle => 'Session expiring soon';

  @override
  String get shareContentTypeMenu => 'menus';

  @override
  String get shareContentTypeRecipe => 'recipes';

  @override
  String get shareContentTypeShoppingList => 'shopping lists';

  @override
  String shareDefaultMessageMenu(String name) {
    return 'Check out this weekly menu: $name';
  }

  @override
  String shareDefaultMessageRecipe(String name) {
    return 'Check out this recipe: $name';
  }

  @override
  String shareDefaultMessageShoppingList(String name) {
    return 'Check out this shopping list: $name';
  }

  @override
  String shareFriendsSelected(int count) {
    return '$count friend(s) selected';
  }

  @override
  String get shareMenu => 'Share menu';

  @override
  String get shareRecipe => 'Share recipe';

  @override
  String shareSelectAtLeastOne(String contentType) {
    return 'Select at least one friend to share $contentType';
  }

  @override
  String shareSuccessMessage(String name, String mode, int count) {
    return '$name has been shared as $mode with $count recipients.';
  }

  @override
  String get uploadFailed => 'Image upload failed';

  @override
  String uploadFailedCount(int count) {
    return '$count images could not be uploaded.\n\nWhat do you want to do?';
  }

  @override
  String get uploadInProgress => 'Image upload in progress';

  @override
  String uploadMixedStatus(int failedCount, int pendingCount) {
    return 'Some images could not be uploaded ($failedCount) and others are still uploading ($pendingCount).\n\nWhat do you want to do?';
  }

  @override
  String uploadPendingCount(int count) {
    return '$count images are still uploading.\n\nWhat do you want to do?';
  }

  @override
  String get uploadSaveWithoutFailed => 'Save without failed images';

  @override
  String get uploadSaveWithoutPending => 'Save without pending images';

  @override
  String get uploadWait => 'Wait for upload';

  @override
  String get uploadClearFailed => 'Clear failed';

  @override
  String uploadRetryAllCount(int count) {
    return 'Retry all ($count)';
  }

  @override
  String uploadStopAllCount(int count) {
    return 'Stop all ($count)';
  }

  @override
  String uploadTimeRemaining(String time) {
    return '$time remaining';
  }

  @override
  String get consentManageTitle => 'Manage consents';

  @override
  String get consentYourConsents => 'Your consents';

  @override
  String get consentGdprDescription =>
      'Under GDPR you have full control over how we process your personal data. You can change or revoke your consents at any time.';

  @override
  String get consentLastUpdated => 'Last updated';

  @override
  String get consentRequiredTitle => 'Required consents';

  @override
  String get consentRequiredDescription =>
      'These consents are required for the app to function and cannot be disabled.';

  @override
  String get consentBasicServices => 'Basic services';

  @override
  String get consentBasicServicesDescription =>
      'Authentication, security and basic functionality.';

  @override
  String get consentDataProcessing => 'Data processing';

  @override
  String get consentDataProcessingDescription =>
      'Storage and processing of recipes, menus and shopping lists.';

  @override
  String get consentOptionalTitle => 'Optional consents';

  @override
  String get consentOptionalDescription =>
      'You can enable or disable these consents at any time.';

  @override
  String get consentRejectAll => 'Reject all';

  @override
  String get consentAnalytics => 'Analytics';

  @override
  String get consentAnalyticsDescription =>
      'Help us improve the app by sharing usage statistics. We collect information about how you use the app to identify bugs and improve the user experience.';

  @override
  String get consentWhatWeLog => 'What we log';

  @override
  String get consentWhatWeLogIntro =>
      'Anonymous events we log to improve the app:';

  @override
  String get consentLogCategoryUsage => 'App usage';

  @override
  String get consentLogCategoryRecipes => 'Recipes';

  @override
  String get consentLogCategoryMenuShopping => 'Menu & shopping';

  @override
  String get consentLogCategoryImport => 'Import';

  @override
  String get consentLogCategorySocial => 'Social';

  @override
  String get consentLogCategoryOnboarding => 'Onboarding';

  @override
  String get consentMarketing => 'Marketing';

  @override
  String get consentMarketingDescription =>
      'Receive newsletters and offers about new features, recipes and updates via email.';

  @override
  String get consentSocialFeatures => 'Social features';

  @override
  String get consentSocialFeaturesDescription =>
      'Share your recipes with friends, see others\' creations and participate in the community.';

  @override
  String get consentPushNotifications => 'Push notifications';

  @override
  String get consentPushNotificationsDescription =>
      'Get notifications about comments on your recipes, when friends share with you and other activities.';

  @override
  String get consentGoodToKnow => 'Good to know';

  @override
  String get consentInfoImmediate => 'Your changes take effect immediately';

  @override
  String get consentInfoChangeAnytime =>
      'You can change your consents at any time';

  @override
  String get consentInfoHistory =>
      'We keep a history of your consents to comply with GDPR';

  @override
  String get consentInfoRevoke =>
      'Revoking consents does not affect previous processing';

  @override
  String get consentSaved => 'Consents have been saved';

  @override
  String get consentRevokeAllTitle => 'Revoke all optional consents?';

  @override
  String get consentRevokeAllMessage =>
      'This will disable all optional features such as analytics, social features and push notifications. You can enable them again at any time.';

  @override
  String get consentRevokeAll => 'Revoke all';

  @override
  String get consentAllRevoked => 'All optional consents have been revoked';

  @override
  String get consentRenewalTitle => 'We\'ve updated our terms';

  @override
  String get consentRenewalDescription =>
      'We\'ve made changes to how we process your data. Please review and confirm your consents to continue.';

  @override
  String get consentRenewalReview => 'Review consents';

  @override
  String get consentRenewalLater => 'Later';

  @override
  String get dataExportTitle => 'Export my data';

  @override
  String get dataExportDownloadTitle => 'Download your data';

  @override
  String get dataExportGdprDescription =>
      'Under GDPR Article 20 you have the right to obtain a copy of all your personal data stored in Butlery. Data is exported in JSON format that you can save or transfer to another service.';

  @override
  String get dataExportExporting => 'Exporting your data...';

  @override
  String get dataExportMayTakeSeconds => 'This may take a few seconds';

  @override
  String get dataExportFailed => 'Export failed';

  @override
  String get dataExportSuccess => 'Data exported';

  @override
  String get dataExportExportedAt => 'Exported';

  @override
  String get dataExportFileSize => 'File size';

  @override
  String get dataExportSaveFile => 'Save file';

  @override
  String get dataExportClear => 'Clear export';

  @override
  String get dataExportWhatsIncluded => 'What\'s included in the export?';

  @override
  String get dataExportIncludesProfile => 'Profile and settings';

  @override
  String get dataExportIncludesRecipes => 'All your recipes';

  @override
  String get dataExportIncludesFriends => 'Friends and social contacts';

  @override
  String get dataExportIncludesMessages => 'Messages and conversations';

  @override
  String get dataExportIncludesLists => 'Shopping lists and menus';

  @override
  String get dataExportIncludesComments => 'Comments and ratings';

  @override
  String get dataExportIncludesActivity => 'Activity history';

  @override
  String get dataExportIncludesAuditLogs =>
      'Security and access history (GDPR Article 15)';

  @override
  String get dataExportOnlyYourData =>
      'Note: The export only contains your own data. No data from other users is included.';

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String dateDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String dateWeeksAgo(int weeks) {
    return '$weeks weeks ago';
  }

  @override
  String dateMonthsAgo(int months) {
    return '$months months ago';
  }

  @override
  String get friendAccept => 'Accept';

  @override
  String get friendDecline => 'Decline';

  @override
  String get friendRequestTitle => 'Friend request';

  @override
  String get friendWantsToBeFriend => 'Wants to be your friend';

  @override
  String imageAddCount(int count) {
    return 'Add ($count)';
  }

  @override
  String get imageAddImages => 'Add images';

  @override
  String get imageAdding => 'Adding...';

  @override
  String get imageAddingImage => 'Adding image...';

  @override
  String imagePermissionMessage(String permission) {
    return 'Butlery needs access to your $permission to add images to recipes. Go to settings to grant permission.';
  }

  @override
  String get imagePermissionRequired => 'Permission required';

  @override
  String get imagePrimary => 'Primary';

  @override
  String get imageSelectExistingFromGallery =>
      'Select an existing image from your gallery';

  @override
  String get imageSelectSource => 'Select image source';

  @override
  String imageTapToAddUpTo(int count) {
    return 'Tap to add up to $count images';
  }

  @override
  String get imageTapToLoad => 'Tap to load';

  @override
  String get imageUploadingImages => 'Uploading images';

  @override
  String get imageUploadPreparing => 'Preparing...';

  @override
  String get imageUseCameraForNewPhoto => 'Use the camera to take a new photo';

  @override
  String get importAddIngredient => 'Add ingredient';

  @override
  String get importAddStep => 'Add step';

  @override
  String get importAllergenSetupBanner =>
      'This recipe contains allergens you haven\'t set up. Configure your allergens and we\'ll flag them for you automatically.';

  @override
  String get importAllergenSetupCta => 'Set up';

  @override
  String get importNotRecipeTitle => 'Doesn\'t look like a recipe';

  @override
  String get importNotRecipeBody =>
      'This text doesn\'t look like it contains a recipe. Importing it anyway may not give a useful result. Import anyway?';

  @override
  String get importNotRecipeConfirm => 'Import anyway';

  @override
  String get importCancelConfirm => 'Cancel import';

  @override
  String get importCancelMessage =>
      'Are you sure you want to cancel? All selections will be lost.';

  @override
  String get importCancelTitle => 'Cancel import?';

  @override
  String get importDescriptionHint => 'Short description (optional)';

  @override
  String get importManualTitle => 'Manual import';

  @override
  String get importMealBreakfast => 'Breakfast';

  @override
  String get importMealDessert => 'Dessert';

  @override
  String get importMealDinner => 'Dinner';

  @override
  String get importMealLunch => 'Lunch';

  @override
  String get importMealSnack => 'Snack';

  @override
  String get importMealType => 'Meal type';

  @override
  String get importRecipeNameHint => 'Enter recipe name';

  @override
  String get importRecipeNameRequired => 'Recipe name *';

  @override
  String get importSaveRecipe => 'Save recipe';

  @override
  String get importSelectIngredients => 'Select ingredients';

  @override
  String get importSelectInstructions => 'Select instructions';

  @override
  String get importStep1SelectIngredients => 'Step 1: Select ingredients';

  @override
  String get importStep2SelectInstructions => 'Step 2: Select instructions';

  @override
  String get importStep3ReviewEdit => 'Step 3: Review and edit';

  @override
  String importParseQualityWarning(int quality) {
    return 'Recipe parsed with $quality% confidence. Review the fields below.';
  }

  @override
  String importFieldsNeedReview(int count) {
    return '$count field(s) may need adjustment';
  }

  @override
  String get importFieldsNeedReviewPrefix => 'Review';

  @override
  String menuCardMoreRecipes(int count) {
    return '+ $count more recipes';
  }

  @override
  String get menuCardNoRecipes => 'No recipes in menu';

  @override
  String get menuCardGeneratedTitle => 'Generated menu';

  @override
  String get menuCardUntitled => 'Untitled menu';

  @override
  String menuCardRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
      zero: 'No recipes',
    );
    return '$_temp0';
  }

  @override
  String get menuCardRecipesInMenu => 'Recipes in menu:';

  @override
  String get menuCardSharedMenu => 'Shared menu';

  @override
  String menuCardSharedWithCount(int count) {
    return 'Shared with $count people';
  }

  @override
  String get searchHint => 'search...';

  @override
  String shareFriendsSelectedCount(int count) {
    return '$count friend(s) selected';
  }

  @override
  String shareGroupMembersCount(int count) {
    return '$count members';
  }

  @override
  String get shareTabFriends => 'Friends';

  @override
  String get shareTabGroups => 'Groups';

  @override
  String get shoppingCardComplete => 'Complete';

  @override
  String shoppingCardCompleted(int count) {
    return '$count completed';
  }

  @override
  String get shoppingCardItemsOnList => 'Items on list:';

  @override
  String shoppingCardMoreItems(int count) {
    return '+ $count more items';
  }

  @override
  String get shoppingCardNoItems => 'No items on list';

  @override
  String get shoppingCardSharedList => 'Shared list';

  @override
  String shoppingCardSharedWithCount(int count) {
    return 'Shared with $count people';
  }

  @override
  String get adminYouAreAdmin => 'You are an administrator';

  @override
  String chatCreatedDate(String date) {
    return 'Created: $date';
  }

  @override
  String chatMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'No members',
    );
    return '$_temp0';
  }

  @override
  String get chatMute => 'Mute';

  @override
  String chatParticipantCount(int count) {
    return '$count participants';
  }

  @override
  String get chatTitle => 'Chat';

  @override
  String get commonSearch => 'Search';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get dataExportClearConfirmMessage =>
      'Are you sure you want to clear the exported data? You can export again at any time.';

  @override
  String get dataExportClearConfirmTitle => 'Clear export?';

  @override
  String get dataExportCleared => 'Export cleared';

  @override
  String dataExportCouldNotSaveFile(String error) {
    return 'Could not save file: $error';
  }

  @override
  String dataExportCouldNotShare(String error) {
    return 'Could not share: $error';
  }

  @override
  String get dataExportExportedSuccessfully => 'Data exported successfully';

  @override
  String dataExportFileSaved(String fileName) {
    return 'File saved: $fileName';
  }

  @override
  String get dataExportShareSubject => 'Butlery Data Export';

  @override
  String get dataExportShareText => 'My exported data from the Butlery app';

  @override
  String get dialogAmountHint => 'Enter amount...';

  @override
  String get dialogAmountInvalid => 'Invalid amount';

  @override
  String get dialogAmountLabel => 'Amount';

  @override
  String dialogAmountMax(int max) {
    return 'Maximum $max allowed';
  }

  @override
  String dialogAmountMin(int min) {
    return 'Minimum $min required';
  }

  @override
  String get dialogAmountRequired => 'Amount is required';

  @override
  String get dialogDescriptionHint => 'Optional description...';

  @override
  String get dialogDescriptionLabel => 'Description';

  @override
  String dialogFieldRequired(String field) {
    return '$field is required';
  }

  @override
  String get dialogInvalidUrl => 'Invalid URL';

  @override
  String get dialogPhoneInvalid => 'Invalid phone number';

  @override
  String get dialogPhoneLabel => 'Phone number';

  @override
  String get dialogSearchHint => 'Type to search...';

  @override
  String get importLikely => 'Likely';

  @override
  String get importAiSuggested => 'Butlery\'s suggestion';

  @override
  String get importAiSuggestedA11y => 'Butlery\'s suggestion';

  @override
  String get importNoLinesToShow => 'No lines to show';

  @override
  String importSelectAllHighlighted(int count) {
    return 'Select all highlighted ($count)';
  }

  @override
  String importSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get importStep => 'Step';

  @override
  String get importStepAnalyzing => 'Analyzing';

  @override
  String get importStepCreating => 'Creating';

  @override
  String get importStepFetching => 'Fetching';

  @override
  String get invitationClearSearch => 'Clear search';

  @override
  String get invitationCouldNotLoadTargets => 'Could not load targets';

  @override
  String get menuCreateBeforeSave =>
      'Create a menu first before you can save it';

  @override
  String get menuCreateBeforeShare =>
      'Create a menu first before you can share it';

  @override
  String get menuCreateBeforeShoppingList =>
      'Create a menu first before you can create a shopping list';

  @override
  String menuDefaultName(int count) {
    return 'Weekly menu ($count recipes)';
  }

  @override
  String get menuExitConfirm => 'Exit';

  @override
  String get menuExitMessage => 'Do you really want to exit the app?';

  @override
  String get menuExitTitle => 'Exit Butlery?';

  @override
  String get menuNameBeforeShare => 'Name your menu before sharing it:';

  @override
  String get menuNameHint => 'E.g. \"My weekly menu w.45\"';

  @override
  String get menuNameYourMenu => 'Name your menu';

  @override
  String get menuShareDefaultMessage => 'Check out my weekly menu!';

  @override
  String get messagingEdited => 'edited';

  @override
  String get messagingImageLoadError => 'Image could not be loaded';

  @override
  String get messagingImageLoadFailed => 'Could not load image';

  @override
  String get messagingMenuShared => 'Menu shared';

  @override
  String get messagingRecipeShared => 'Recipe shared';

  @override
  String get messagingShoppingListShared => 'Shopping list shared';

  @override
  String get messagingUnknownMenu => 'Unknown menu';

  @override
  String get messagingUnknownRecipe => 'Unknown recipe';

  @override
  String get messagingUnknownShoppingList => 'Unknown shopping list';

  @override
  String get messagingVoiceMessage => 'Voice message';

  @override
  String get messagingAddFriendsToCreateGroups =>
      'Add friends to create group conversations';

  @override
  String get messagingAllFriendsAlreadyInGroup =>
      'All your friends are already in the group';

  @override
  String get messagingCouldNotAddMembers => 'Could not add members';

  @override
  String messagingCouldNotLoadFriends(String error) {
    return 'Could not load friends: $error';
  }

  @override
  String messagingCouldNotLoadGroupInfo(String error) {
    return 'Could not load group info: $error';
  }

  @override
  String get messagingCouldNotRemoveMember => 'Could not remove member';

  @override
  String get messagingCouldNotUpdateGroupName => 'Could not update group name';

  @override
  String get messagingCreateGroup => 'Create group conversation';

  @override
  String get messagingEditGroupName => 'Edit group name';

  @override
  String get messagingEnterNewGroupName => 'Enter new group name';

  @override
  String messagingFriendsCount(int count) {
    return 'Friends ($count)';
  }

  @override
  String get messagingFromGroup => 'from the group';

  @override
  String get messagingGroupCreated => 'Group conversation created!';

  @override
  String get messagingGroupName => 'Group name';

  @override
  String get messagingGroupNameHint => 'E.g. My family, Work, Best friends...';

  @override
  String get messagingGroupNameUpdated => 'Group name updated';

  @override
  String get messagingGroupNoLongerExists => 'This group no longer exists';

  @override
  String get messagingGroupNotFound => 'Group not found';

  @override
  String get messagingLeaveGroupConfirm =>
      'Are you sure you want to leave this group? You will no longer be able to see messages in the group.';

  @override
  String get messagingLoadingFriends => 'Loading friends...';

  @override
  String get messagingLoadingGroupInfo => 'Loading group info...';

  @override
  String messagingMembersAdded(int count) {
    return '$count member(s) added';
  }

  @override
  String messagingMembersCount(int count) {
    return 'Members ($count)';
  }

  @override
  String messagingMemberRemoved(String name) {
    return '$name removed from the group';
  }

  @override
  String get messagingNoFriendsAvailable => 'No friends available';

  @override
  String get messagingNoFriendsFound => 'No friends found';

  @override
  String get messagingSearchFriends => 'Search friends...';

  @override
  String get messagingSelectAtLeastTwoMembers =>
      'Select at least 2 members below';

  @override
  String messagingSelectedMembers(int count) {
    return 'Selected members ($count)';
  }

  @override
  String get messagingTryAnotherKeyword => 'Try another keyword';

  @override
  String mfaCodeSentTo(String phone) {
    return 'A verification code has been sent to $phone.';
  }

  @override
  String get mfaEnterCode => 'Enter the verification code';

  @override
  String get mfaInvalidCode => 'Invalid code. Try again.';

  @override
  String get mfaNoPhoneFactor => 'No phone verification configured.';

  @override
  String get mfaQuotaExceeded => 'Too many attempts. Try again later.';

  @override
  String get mfaResend => 'Resend';

  @override
  String get mfaSendingCode => 'Sending verification code...';

  @override
  String mfaSendingTo(String phone) {
    return 'To: $phone';
  }

  @override
  String get mfaSessionExpired => 'Session has expired. Try logging in again.';

  @override
  String get mfaSixDigitCode => '6-digit code';

  @override
  String get mfaTitle => 'Two-factor authentication';

  @override
  String get mfaVerificationFailed => 'Verification failed';

  @override
  String get mfaVerify => 'Verify';

  @override
  String get mfaYourPhone => 'your phone number';

  @override
  String get mfaAccountProtected =>
      'Your account is protected with two-factor authentication.';

  @override
  String get mfaActivated => 'MFA activated!';

  @override
  String get mfaAddPhoneNumber => 'Add phone number';

  @override
  String get mfaCouldNotRemove => 'Could not remove MFA';

  @override
  String get mfaDeactivated => 'MFA deactivated';

  @override
  String get mfaDisabled => 'MFA disabled';

  @override
  String get mfaEnabled => 'MFA enabled';

  @override
  String get mfaEnableForSecurity => 'Enable MFA for extra security.';

  @override
  String get mfaEnterPhoneNumber => 'Enter a phone number';

  @override
  String get mfaEnterVerificationCode => 'Enter verification code';

  @override
  String get mfaInvalidPhoneNumber =>
      'Invalid phone number. Enter with country code (+46).';

  @override
  String get mfaPhone => 'Phone';

  @override
  String get mfaPhoneNumber => 'Phone number';

  @override
  String mfaRegistered(String time) {
    return 'Registered: $time';
  }

  @override
  String get mfaRegisteredMethods => 'Registered methods';

  @override
  String get mfaRemoveConfirm =>
      'Are you sure you want to disable two-factor authentication? This makes your account less secure.';

  @override
  String get mfaRemoveTitle => 'Remove MFA?';

  @override
  String get mfaSendCode => 'Send code';

  @override
  String get mfaSmsDescription =>
      'We will send a verification code via SMS when you log in.';

  @override
  String get realtimeOffline => 'Offline';

  @override
  String get recipeMealType => 'Meal type';

  @override
  String get recipeTitle => 'Title';

  @override
  String get recipeUpdating => 'Updating recipe...';

  @override
  String chatAddCount(int count) {
    return 'Add ($count)';
  }

  @override
  String get chatAddMembers => 'Add members';

  @override
  String get chatSearchFriends => 'Search friends...';

  @override
  String get collaborativeContent => 'Content';

  @override
  String get collaborativeEditingTogether =>
      'You are editing together with others';

  @override
  String get collaborativeOffline => 'Offline';

  @override
  String get collaborativeOnline => 'Online';

  @override
  String get collaborativeShared => 'Shared';

  @override
  String get collaborativeSharedContent => 'Shared content';

  @override
  String collaborativeSharedWithCount(int count) {
    return 'Shared with $count people';
  }

  @override
  String get collaborativeSyncAutomatic =>
      'Changes sync automatically with other participants';

  @override
  String get conversationAddFriendsFirst =>
      'Add friends first to start conversations.';

  @override
  String conversationCreateError(String error) {
    return 'Could not create conversation: $error';
  }

  @override
  String get conversationCreateGroup => 'Create group conversation';

  @override
  String conversationGroupChatWith(String names) {
    return 'Group chat with $names';
  }

  @override
  String get conversationGroupCreated => 'Group created';

  @override
  String get conversationNew => 'New conversation';

  @override
  String get conversationNoFriendsMatch => 'No friends match your search';

  @override
  String get conversationNoFriendsYet => 'No friends yet';

  @override
  String get conversationSayHi => 'Say hi!';

  @override
  String get conversationSelectFriendForDM =>
      'Or select a friend for direct message:';

  @override
  String get conversationYouPrefix => 'You:';

  @override
  String errorDeletingWithDetails(String error) {
    return 'Error deleting: $error';
  }

  @override
  String get errorLoadingFailed => 'Loading failed';

  @override
  String errorLoadingWithDetails(String error) {
    return 'Error loading: $error';
  }

  @override
  String get errorUnknown => 'Unknown error';

  @override
  String get imageSelectImage => 'Select image';

  @override
  String get imageTitle => 'Image';

  @override
  String importAllCount(int count) {
    return 'Import all ($count)';
  }

  @override
  String get importColumnCategory => 'Category (category/kategori)';

  @override
  String get importColumnCookingTime => 'Cooking time (cookingtime/tid)';

  @override
  String get importColumnIngredients =>
      'Ingredients (ingredients/ingredienser)';

  @override
  String get importColumnInstructions =>
      'Instructions (instructions/instruktioner)';

  @override
  String get importColumnServings => 'Servings (servings/portioner)';

  @override
  String get importColumnTags => 'Tags (tags/taggar)';

  @override
  String get importColumnTitle => 'Title (title/namn)';

  @override
  String importComplete(int succeeded, int failed) {
    return 'Import complete: $succeeded succeeded, $failed failed';
  }

  @override
  String get importEditTextBeforeImport => 'Edit text before import';

  @override
  String get importEditTextHint => 'You can edit the extracted text here...';

  @override
  String get importExtractedText => 'Extracted text:';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String importFailedCount(int count) {
    return '$count failed';
  }

  @override
  String get importFetching => 'Fetching...';

  @override
  String get importFetchText => 'Fetch text';

  @override
  String get importFileColumnsOptional => 'Optional columns:';

  @override
  String get importFileColumnsRequired =>
      'Your file should contain columns for:';

  @override
  String get importFilterAll => 'All';

  @override
  String get importFilterAllTimes => 'All times';

  @override
  String get importFromArchive => 'Import from Butlery\'s archive';

  @override
  String get importFromFile => 'Import from file';

  @override
  String get importFromFileTitle => 'Import recipes from CSV or Excel';

  @override
  String get importFromSocialMedia => 'From social media';

  @override
  String get importImporting => 'Importing...';

  @override
  String importImportingRecipes(int count) {
    return 'Importing $count recipes...';
  }

  @override
  String get importImportingRecipesProgress => 'Importing recipes...';

  @override
  String get importWaitForCompletion =>
      'Please wait until the import is complete...';

  @override
  String get importNoFileOrNoRecipes =>
      'No file selected or the file contains no recipes';

  @override
  String get importNoRecipesMatchedFilters => 'No recipes matched the filters';

  @override
  String get importParsingText => 'Parsing text...';

  @override
  String get importPasteRecipeHint => 'Paste recipe text here...';

  @override
  String get importPasteRecipeUrl => 'Paste recipe URL';

  @override
  String get importPreviewAndEdit => 'Preview and edit';

  @override
  String get importProceedToPaste => 'Proceed to paste';

  @override
  String get importRecipesImported => 'Recipes imported!';

  @override
  String get importSearchArchive => 'Search archive...';

  @override
  String get importSelectFileAndImport => 'Select file and import';

  @override
  String get importSelectingFile => 'Selecting file...';

  @override
  String get importShowError => 'Show error';

  @override
  String importSucceededCount(int count) {
    return '$count succeeded';
  }

  @override
  String importTagsCount(int count) {
    return '$count tags';
  }

  @override
  String get importTipsContent =>
      'Paste the full recipe including ingredients. Make sure ingredients come before instructions. Text can come from Instagram, TikTok, Facebook etc.';

  @override
  String get importTipsTitle => 'Tips for best results';

  @override
  String get importTryAdjustFilters => 'Try adjusting search or filters';

  @override
  String get importViaUrl => 'Import via URL';

  @override
  String get indicatorOfflineMode => 'Offline mode - Changes saved locally';

  @override
  String get indicatorBackOnline => 'Back online';

  @override
  String get householdLabel => 'Household';

  @override
  String get householdToggle => 'Mark as household';

  @override
  String get householdToggleDescription =>
      'Household allergens are combined for menu planning';

  @override
  String get householdAlreadyExists =>
      'You already have a household. The current one will be removed first.';

  @override
  String get householdAllergenInfo =>
      'Menu planning filters based on all members\' allergens';

  @override
  String get menuUseHouseholdAllergens => 'Filter by household allergens';

  @override
  String get menuVoteTitle => 'Vote on recipe';

  @override
  String get menuVoteSuggestAlternative => 'Suggest alternative';

  @override
  String get menuVoteCastVote => 'Vote';

  @override
  String get menuVoteResolved => 'Vote resolved';

  @override
  String get menuVoteDeadline => 'Voting deadline';

  @override
  String menuVoteWinner(String recipeName) {
    return 'Winner: $recipeName';
  }

  @override
  String menuVoteCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
      zero: 'No votes',
    );
    return '$_temp0';
  }

  @override
  String get menuVoteExpired => 'Voting has expired';

  @override
  String get menuVoteNoAlternatives => 'No suggestions yet';

  @override
  String get invitationCheckConnectionAndRetry =>
      'Check your internet connection and try again.';

  @override
  String invitationCurrentItem(String item) {
    return 'Current: $item';
  }

  @override
  String get invitationDone => 'Done';

  @override
  String get invitationNoFriendsOrGroupsYet =>
      'You haven\'t added any friends or groups yet.';

  @override
  String get invitationNoSelectedTargets => 'No selected targets';

  @override
  String get invitationProcessing => 'Processing';

  @override
  String get invitationRequestAccess => 'Request access';

  @override
  String invitationSearchQuery(String query) {
    return 'Search: \"$query\"';
  }

  @override
  String get invitationSelectTargetsToContinue =>
      'Select targets from the list above to continue.';

  @override
  String get invitationSendingInvitations => 'Sending invitations...';

  @override
  String invitationsSentMessage(int count) {
    return 'Invitations have been sent to $count targets.';
  }

  @override
  String get invitationsSentTitle => 'Invitations sent';

  @override
  String invitationTargetsSelectedForInvitation(int count) {
    return 'You have selected $count targets for invitation.';
  }

  @override
  String get invitationTryDifferentSearch =>
      'Try searching with different words or check the spelling.';

  @override
  String get loadingNoContent => 'No content';

  @override
  String get menuCommentLabel => 'Comment (optional)';

  @override
  String get menuDeleteConfirmation =>
      'Are you sure you want to delete this menu?';

  @override
  String menuDeletedSuccess(String name) {
    return 'Menu \"$name\" deleted';
  }

  @override
  String get menuDeleteFailed => 'Could not delete menu';

  @override
  String get menuDeleteTitle => 'Delete menu';

  @override
  String menuLoadedSuccess(String name) {
    return 'Menu \"$name\" loaded!';
  }

  @override
  String get menuLoadFailed => 'Could not load menu';

  @override
  String get menuNameLabel => 'Menu name';

  @override
  String get menuNameRequired => 'Menu name is required';

  @override
  String get menuNoSavedMenusDescription =>
      'You have no saved menus yet. Generate and save a menu first!';

  @override
  String menuRecipesInCategories(int recipeCount, int categoryCount) {
    return '$recipeCount recipes in $categoryCount categories';
  }

  @override
  String get menuSavedEarlier => 'Saved earlier';

  @override
  String get menuSaveTitle => 'Save menu';

  @override
  String get menuShareWithFriendsDescription =>
      'Share this menu with selected friends';

  @override
  String get menuToSave => 'Menu to save';

  @override
  String get menuUnnamed => 'Unnamed menu';

  @override
  String get privacyCouldNotLoad =>
      'Could not load the privacy policy. Try again later.';

  @override
  String get privacyTitle => 'Privacy policy';

  @override
  String get recipeAddTags => 'Add tags';

  @override
  String get recipeChangesSaved => 'Changes saved!';

  @override
  String get recipeContinueEditing => 'Continue editing';

  @override
  String get recipeCopySaved => 'Your copy of the recipe was saved!';

  @override
  String get recipeCouldNotSaveChanges => 'Could not save changes';

  @override
  String get recipeCouldNotSaveCopy => 'Could not save your copy';

  @override
  String get recipeFromArchive => 'From archive';

  @override
  String get recipeFromImage => 'From image';

  @override
  String get recipeImportedFromShare => 'Imported from sharing';

  @override
  String get recipeImportLink => 'Import link';

  @override
  String get recipeIngredient => 'Ingredient';

  @override
  String get recipeInstruction => 'Instruction';

  @override
  String get recipeLeaveWithoutSaving => 'Leave without saving';

  @override
  String get recipeManageAllTags => 'Manage all tags';

  @override
  String get recipeRating => 'Rating (0–5)';

  @override
  String get recipeSourceUrl => 'Source (URL)';

  @override
  String get recipeSourceUrlHelper => 'Link to the original recipe';

  @override
  String get recipeSourceUrlHint => 'Optional: link to the original recipe';

  @override
  String get recipeSwipeHintText => 'Tip: swipe right to edit, left to delete';

  @override
  String get cookingStepHintText => 'Tip: long-press a step to start a timer';

  @override
  String get shoppingClaimHintText =>
      'Tip: swipe an item to mark that you\'ll buy it';

  @override
  String get recipeTagsUpdated => 'Tags updated';

  @override
  String get recipeTimeMinutes => 'Time (min)';

  @override
  String get recipeUnsavedChangesTitle => 'Unsaved changes';

  @override
  String get recipeWriteManually => 'Write manually';

  @override
  String get shoppingAddItems => 'Add';

  @override
  String shoppingAddItemsFromMenu(int count, String listName) {
    return 'Add $count items from menu to \"$listName\"';
  }

  @override
  String get shoppingCreateFirstListDescription =>
      'Create your first shopping list to get started';

  @override
  String shoppingItemsAdded(int count, String listName) {
    return '$count items added to \"$listName\"';
  }

  @override
  String shoppingItemsAddFailed(String error) {
    return 'Could not add items: $error';
  }

  @override
  String shoppingListCreateFailed(String error) {
    return 'Could not create list: $error';
  }

  @override
  String get socialTotalMembers => 'Total members';

  @override
  String get userNoUsers => 'No users';

  @override
  String get userNoUsersToShow => 'No users to show';

  @override
  String get chatAttachments => 'Attachments';

  @override
  String get chatAttachmentTypes =>
      'Attachments: Recipe, Menu, Shopping list, Photo';

  @override
  String get chatCannotMessageNonFriend =>
      'You cannot send messages to this person';

  @override
  String get chatCouldNotSendMessage =>
      'Could not send the message. Try again.';

  @override
  String get chatLoadingMessages => 'Loading messages...';

  @override
  String get chatNoMessages => 'No messages yet';

  @override
  String get chatSend => 'Send';

  @override
  String get chatSendImage => 'Send image';

  @override
  String get chatSendToStartConversation =>
      'Send a message to start the conversation';

  @override
  String get chatWriteMessage => 'Write a message...';

  @override
  String get commonOr => 'or';

  @override
  String get errorCouldNotLoadPage => 'Could not load the page';

  @override
  String get errorLoadingRetryOrGoBack =>
      'An error occurred while loading. Try again or go back.';

  @override
  String errorSavingWithDetails(String error) {
    return 'Could not save: $error';
  }

  @override
  String get errorTitle => 'Error';

  @override
  String errorOccurredWithDetails(String error) {
    return 'An error occurred: $error';
  }

  @override
  String get filterAllergenFree => 'Allergen free';

  @override
  String get filterClearAll => 'Clear all filters';

  @override
  String get filterCookingTime => 'Cooking time';

  @override
  String get filterCreatePersonalTags => 'Create personal tags';

  @override
  String get filterDietary => 'Dietary';

  @override
  String get filterExcludeTags => 'Exclude tags';

  @override
  String get filterHide => 'Hide filters';

  @override
  String get filterManageFoodPrefs => 'Manage allergens & diet';

  @override
  String get filterManageTags => 'Manage tags';

  @override
  String get filterMealType => 'Meal type';

  @override
  String get filterPersonalTags => 'Personal tags';

  @override
  String get filterRating => 'Rating';

  @override
  String get filterShow => 'Show filters';

  @override
  String get importAnalyzingContent => 'Analyzing content...';

  @override
  String get importChooseFromGallery => 'Choose from gallery';

  @override
  String get importChooseFromGallerySubtitle =>
      'Choose an existing image from your phone';

  @override
  String get importChooseImage => 'Choose image';

  @override
  String get importChooseImageSource => 'Choose image source';

  @override
  String get importChooseNewImage => 'Choose new image';

  @override
  String importConfidenceTooltip(String label, int percentage) {
    return '$label: $percentage% confidence';
  }

  @override
  String get importContinueWithImport => 'Continue with import';

  @override
  String get importContinueWithoutOcr => 'Continue without text recognition';

  @override
  String get importCopyManually => 'Copy manually';

  @override
  String get importCouldNotExtractText => 'Could not extract text';

  @override
  String get importExtraction => 'Extraction';

  @override
  String get importFetchAutomatically => 'Fetch recipe automatically';

  @override
  String get importFetchFromWebsite => 'Fetch recipe from website';

  @override
  String importFetchingFromPlatform(String platform) {
    return 'Fetching recipe from $platform...';
  }

  @override
  String get importFromPhoto => 'Import from photo';

  @override
  String get importGoodQuality => 'Good quality';

  @override
  String get importHighQuality => 'High quality';

  @override
  String importImageQualityLow(int percentage) {
    return 'Image quality is low ($percentage%)';
  }

  @override
  String get importImport => 'Import';

  @override
  String importImportedFrom(String source) {
    return 'Imported from $source';
  }

  @override
  String get importImprovementSuggestions => 'Improvement suggestions:';

  @override
  String get importInterpretedText => 'Interpreted text:';

  @override
  String get importLowQuality => 'Low quality';

  @override
  String get importManualCopy => 'Manual copy';

  @override
  String importManualCopyInstructions(String platform) {
    return '1. Go back to $platform\n2. Copy the recipe text from the post\n3. Come back here and choose \"Paste text\"';
  }

  @override
  String get importManually => 'Import manually';

  @override
  String get importNoImageSelected => 'No image selected';

  @override
  String get importNoRecipeInfoFound =>
      'No recipe information found in the text.';

  @override
  String get importOcrMayFail =>
      'Text recognition may fail or give poor results.';

  @override
  String get importOtherApp => 'another app';

  @override
  String get importPasteFromClipboard => 'Paste from clipboard';

  @override
  String get importClipboardUrlDetected => 'Recipe URL found in clipboard';

  @override
  String get importClipboardUseUrl => 'Use';

  @override
  String get importPasteLinkOrText => 'Paste link or text here...';

  @override
  String get importPasteText => 'Paste text';

  @override
  String get importAddManually => 'Add manually';

  @override
  String get importPhotoDescription =>
      'Take a picture of a recipe or choose from gallery to import text automatically';

  @override
  String get importPhotoImport => 'Photo import';

  @override
  String get importProceedToEdit => 'Proceed to edit';

  @override
  String importMultipleRecipesFound(int count) {
    return 'We found $count recipes';
  }

  @override
  String get importPhotoAddPage => 'Add page';

  @override
  String importPhotoPageLabel(int number) {
    return 'Page $number';
  }

  @override
  String importPhotoPagesCombined(int count) {
    return '$count pages combined into one recipe';
  }

  @override
  String importPhotoPagesMaxReached(int max) {
    return 'Max $max pages per recipe';
  }

  @override
  String get shareImportUnreadable => 'Could not read the shared photo(s)';

  @override
  String a11yRemovePhotoPage(int number) {
    return 'Remove page $number';
  }

  @override
  String get importProcessingImage => 'Processing image...';

  @override
  String get importRecipeLinkDetected => 'Recipe link detected';

  @override
  String get importRecipeTextCanImport =>
      'Recipe text detected! We can import this.';

  @override
  String get importRecipeTextDetected => 'Recipe text detected!';

  @override
  String get importRecipeTitle => 'Import recipe';

  @override
  String get importRemoveImage => 'Remove image';

  @override
  String get importHeirloomClearTitle => 'Remove the image?';

  @override
  String get importHeirloomClearMessage =>
      'You\'ve added heirloom details (writer, year, note). Removing the image discards them too. This can\'t be undone.';

  @override
  String get importSharedText => 'shared text';

  @override
  String get importTakePhoto => 'Take a photo';

  @override
  String get importTakePhotoSubtitle =>
      'Use the camera to photograph the recipe';

  @override
  String get importTapButtonToSelect => 'Tap the button above to select';

  @override
  String get importTextContent => 'Text content';

  @override
  String get importTryAnyway => 'Try anyway';

  @override
  String get importUnknownSource => 'Unknown source';

  @override
  String importUrlFromPlatform(String platform) {
    return 'URL from $platform';
  }

  @override
  String get importUrlBatchAllFailed =>
      'None of the URLs could be fetched. Check the links and try again.';

  @override
  String get importMultipleUrlsHint =>
      'Paste one or more recipe URLs (one per line)';

  @override
  String get importMultipleUrlsLabel => 'Recipe URLs';

  @override
  String importUrlBatchProgress(int success, int total) {
    return '$success of $total fetched';
  }

  @override
  String importUrlBatchImport(int count) {
    return 'Import $count recipes';
  }

  @override
  String get importIndexPageDetected => 'This looks like a recipe collection.';

  @override
  String importIndexPageExpand(int count) {
    return 'Import all $count recipes';
  }

  @override
  String get importUrlFetchPending => 'Waiting...';

  @override
  String get importUrlFetchSuccess => 'Fetched';

  @override
  String get importUrlFetchFailed => 'Failed';

  @override
  String get importVideoNoText => 'Video has no text';

  @override
  String get importVideoNoTextDescription =>
      'This video has no subtitles we can read.\n\nYou can take a screenshot of the recipe in the video and import it instead.';

  @override
  String get importWebRecipeLinkDetected =>
      'Recipe link from website detected!';

  @override
  String get importWebsite => 'Website';

  @override
  String get groupAddMembers => 'Add members';

  @override
  String get groupAllFriendsAlreadyMembers =>
      'All your friends are already members of this group, or you have already sent invitations to them.';

  @override
  String get groupCouldNotLoadMembers => 'Could not load group members';

  @override
  String get groupCouldNotTransferOwnership =>
      'Could not transfer ownership. Try again.';

  @override
  String groupDeleted(String name) {
    return 'Group \"$name\" has been deleted';
  }

  @override
  String get groupInvitationSent => 'Sent';

  @override
  String groupInvitationsSent(int count) {
    return '$count invitations sent';
  }

  @override
  String get groupInvitationsSentSuccess => 'Invitations have been sent!';

  @override
  String get groupLoadingInfo => 'Loading group information...';

  @override
  String get groupNoFriendsAvailable => 'No friends available';

  @override
  String get groupNoMembersToShare => 'The group has no members to share with';

  @override
  String get groupNotFound => 'Group not found';

  @override
  String get groupNotFoundDescription =>
      'This group may have been deleted or you do not have permission.';

  @override
  String get groupOwnershipTransferredAndLeft =>
      'Ownership transferred and you have left the group';

  @override
  String groupSelectedOfTotal(int selected, int total) {
    return '$selected of $total selected';
  }

  @override
  String groupSendInvitations(int count) {
    return 'Send $count invitations';
  }

  @override
  String groupSharedFromGroup(String name) {
    return 'Shared from group $name';
  }

  @override
  String get groupUpdated => 'Group updated!';

  @override
  String get groupYouLeftGroup => 'You have left the group';

  @override
  String get loadingGeneric => 'Loading...';

  @override
  String get loadingRecipes => 'Loading recipes...';

  @override
  String menuCategoryCount(int count) {
    return '$count categories';
  }

  @override
  String menuConnectingCollaborative(String title) {
    return 'Connecting to \"$title\" for collaborative editing...';
  }

  @override
  String get menuCouldNotHide => 'Could not hide menu';

  @override
  String menuHiddenFromList(String title) {
    return '\"$title\" hidden from your list';
  }

  @override
  String menuHideConfirm(String title, String sharedBy) {
    return 'Would you like to hide \"$title\" from your list?\n\nYou can still access the menu by asking $sharedBy to share it again.';
  }

  @override
  String get menuHideMenu => 'Hide menu';

  @override
  String get menuImportAll => 'Import entire menu';

  @override
  String menuImportDescription(int count) {
    return 'When you import the menu, all $count recipes will be added to your collection.';
  }

  @override
  String get menuImported => 'Menu imported';

  @override
  String menuImportedSuccess(String title) {
    return 'Menu \"$title\" imported!';
  }

  @override
  String get menuImportFailed => 'Import failed';

  @override
  String get menuNoRecipesInMenu => 'No recipes in the menu';

  @override
  String get menuSharedMenu => 'SHARED MENU';

  @override
  String get menuShareMenu => 'Share menu';

  @override
  String menuSharingComingSoon(String title) {
    return 'Sharing of \"$title\" coming soon!';
  }

  @override
  String menuSavedSuccess(String name) {
    return 'Menu \"$name\" saved!';
  }

  @override
  String get menuSaveFailed => 'Could not save the menu';

  @override
  String get navigationGoHome => 'Go home';

  @override
  String get navigationSubtitle => 'Your digital cookbook';

  @override
  String get permissionCopy => 'Copy';

  @override
  String get permissionCreatingCopy => 'Creating copy...';

  @override
  String get permissionNoAccess => 'No access';

  @override
  String get permissionSaveAsNew => 'Save as new';

  @override
  String get permissionSaveChanges => 'Save changes';

  @override
  String get permissionSaveMyCopy => 'Save my copy';

  @override
  String get permissionSaving => 'Saving...';

  @override
  String get privacyContactUs => 'Contact us';

  @override
  String get privacyCouldNotOpenEmail => 'Could not open email client';

  @override
  String get privacyGdprCompliant =>
      'This privacy policy complies with GDPR requirements';

  @override
  String get privacyLoading => 'Loading privacy policy...';

  @override
  String get privacyNotAvailable => 'Privacy policy is not available';

  @override
  String get privacyQuestionsTitle => 'Questions about privacy?';

  @override
  String get privacyReload => 'Reload';

  @override
  String get privacyShareActivityTitle => 'Show my activity in friends\' feed';

  @override
  String get privacyShareActivitySubtitle =>
      'When on, your friends see when you cook, share, and ping recipes.';

  @override
  String get privacyActivityTypesTitle => 'What\'s shared';

  @override
  String get privacyActivityTypeCooked => 'When I cook a recipe';

  @override
  String get privacyActivityTypeShared => 'When I share a recipe';

  @override
  String get privacyActivityTypeStartedCooking => 'When I start cooking';

  @override
  String get privacyActivityTypePinged => 'When I ping a friend';

  @override
  String get privacyActivityFeedHint =>
      'Klart! Dina vänner ser nu din aktivitet i sitt flöde. Du kan stänga av det här när som helst.';

  @override
  String get profileAddAvatar => 'Add avatar';

  @override
  String get profileAvatarRemoved => 'Avatar removed';

  @override
  String get profileAvatarUploaded => 'Avatar uploaded!';

  @override
  String get profileBio => 'Bio';

  @override
  String get profileBioHint =>
      'Describe yourself as a cook (max 160 characters)';

  @override
  String get profileNoBio => 'No bio yet';

  @override
  String get profileChangeAvatar => 'Change avatar';

  @override
  String get profileCouldNotSave => 'Could not save profile';

  @override
  String get profileCouldNotUploadAvatar => 'Could not upload avatar';

  @override
  String get profileCookingIdentity => 'Cooking identity';

  @override
  String get profileCookingSkill => 'Skill level';

  @override
  String get profileCookingSkillAdvanced => 'Advanced';

  @override
  String get profileCookingSkillBeginner => 'Beginner';

  @override
  String get profileCookingSkillIntermediate => 'Intermediate';

  @override
  String get profileCuisineAffinities => 'Favorite cuisines';

  @override
  String get profileCuisineAffinitiesHint => 'Choose up to 5 cuisines';

  @override
  String get profileCuisineAffinitiesMax => 'Maximum 5 cuisines selected';

  @override
  String get profileDisplayName => 'Display name';

  @override
  String get profileDisplayNameHint => 'Your name as others see it';

  @override
  String get profileFormReset => 'Form reset';

  @override
  String get profileLanguage => 'Language';

  @override
  String profileLanguageChangedTo(String language) {
    return 'Language changed to $language';
  }

  @override
  String get profileLoading => 'Loading profile...';

  @override
  String get profileNewUser => 'New user';

  @override
  String get profilePrivacySettings => 'Privacy settings';

  @override
  String get profileResetChanges => 'Reset changes';

  @override
  String get profileSaved => 'Profile saved!';

  @override
  String get profileSaveProfile => 'Save profile';

  @override
  String get profileSearchableByEmail => 'Searchable by email';

  @override
  String get profileSearchableByEmailDescription =>
      'Others can find you through your email address';

  @override
  String get profileShowOnlineStatus => 'Show online status';

  @override
  String get profileShowOnlineStatusDescription =>
      'Friends see a green dot and when you were last active. Turn off to stay invisible.';

  @override
  String get profileTheme => 'Theme';

  @override
  String profileThemeChangedTo(String theme) {
    return 'Theme changed to $theme';
  }

  @override
  String get profileThemeDark => 'Dark mode';

  @override
  String get profileThemeLight => 'Light mode';

  @override
  String get profileThemeSystem => 'System setting';

  @override
  String get profileUnsavedChanges => 'Unsaved changes';

  @override
  String get profileUnsavedChangesMessage =>
      'You have unsaved changes. Would you like to save before leaving?';

  @override
  String get profileUploadingAvatar => 'Uploading avatar...';

  @override
  String get profileVisibleInSearch => 'Visible in searches';

  @override
  String get profileVisibleInSearchDescription =>
      'Other users can find you when they search';

  @override
  String get profileYouHaveUnsavedChanges => 'You have unsaved changes';

  @override
  String get recipeCouldNotSave => 'Could not save recipe';

  @override
  String get recipeCouldNotDelete => 'Could not delete recipe';

  @override
  String get recipeCouldNotMarkAsCooked => 'Could not mark as cooked';

  @override
  String get recipeCouldNotOpenEditor => 'Could not open editor';

  @override
  String get recipeCouldNotShare => 'Could not share recipe';

  @override
  String get recipeDeleted => 'Recipe deleted';

  @override
  String get recipeMarkedAsCooked => 'Recipe marked as cooked today!';

  @override
  String get recipeAlreadyCookedToday => 'Already logged today';

  @override
  String get recipeShared => 'Recipe shared';

  @override
  String recipeImportedFrom(String sourceUrl) {
    return 'Imported from: $sourceUrl';
  }

  @override
  String get recipeSaved => 'Recipe saved!';

  @override
  String get recipeSavedTaggingFailed =>
      'Recipe saved, but tagging failed. Allergen information may be incomplete.';

  @override
  String recipeSavedWithTags(int tagCount, int coverage) {
    return 'Recipe saved! $tagCount tags ($coverage%)';
  }

  @override
  String get recipeSaveStartedDuringDialog =>
      'A save started during the dialog. Please wait while the recipe is saved...';

  @override
  String get recipeWaitWhileSaving =>
      'Please wait while the recipe is saved...';

  @override
  String get celebrationFirstRecipeTitle => 'Congratulations!';

  @override
  String celebrationFirstRecipeMessage(String recipeTitle) {
    return 'You saved your first recipe: $recipeTitle. Welcome to Butlery!';
  }

  @override
  String get celebrationFirstRecipeContinue => 'Continue';

  @override
  String get recipeWriteNew => 'Write new recipe';

  @override
  String recipeAddItem(String label) {
    return 'Add $label';
  }

  @override
  String get recipeSave => 'Save recipe';

  @override
  String get recipeSaving => 'Saving recipe...';

  @override
  String get recipeTag => 'Tag';

  @override
  String searchFiltersActive(int count) {
    return '$count filters active';
  }

  @override
  String get searchQuery => 'Search';

  @override
  String searchResults(int count) {
    return '$count results';
  }

  @override
  String shareFailed(String error) {
    return 'Sharing failed: $error';
  }

  @override
  String get socialCategories => 'Categories';

  @override
  String get socialCategoryStatistics => 'Category statistics';

  @override
  String get socialCreateCategory => 'Create category';

  @override
  String socialMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'No members',
    );
    return '$_temp0';
  }

  @override
  String get socialNoCategories => 'No categories';

  @override
  String get socialBeFirstToComment =>
      'Be the first to comment on this recipe!';

  @override
  String get socialCommentPosted => 'Comment posted';

  @override
  String get socialComments => 'Comments';

  @override
  String socialCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
      zero: 'No comments',
    );
    return '$_temp0';
  }

  @override
  String get socialCouldNotCreateProfile => 'Could not create user profile';

  @override
  String get socialCouldNotFetchUserData => 'Could not fetch user data';

  @override
  String get socialCouldNotPostComment => 'Could not post comment';

  @override
  String socialCouldNotStartConversation(String error) {
    return 'Could not start conversation: $error';
  }

  @override
  String get socialCouldNotUpdateLike => 'Could not update like';

  @override
  String get socialFriendFromList => 'friend from your friend list';

  @override
  String socialFriendRemoved(String name) {
    return '$name removed from friend list';
  }

  @override
  String get socialFriends => 'Friends';

  @override
  String get socialFeed => 'Feed';

  @override
  String get feedEmpty => 'Nothing to show yet';

  @override
  String get feedEmptyDescription =>
      'When your friends cook or share recipes, it will show up here.';

  @override
  String get feedEmptyNoFriendsTitle => 'Add friends to get started';

  @override
  String get feedEmptyNoFriendsSubtitle =>
      'When you follow friends, you\'ll see their cooking and shared recipes here.';

  @override
  String get feedEmptyNoFriendsCta => 'Find friends';

  @override
  String get feedInviteFriends => 'Invite friends';

  @override
  String get feedFilterAll => 'All';

  @override
  String get feedFilterCooked => 'Cooked';

  @override
  String get feedFilterShared => 'Shared';

  @override
  String get feedActionCooked => 'cooked';

  @override
  String get feedActionShared => 'shared';

  @override
  String get feedTimeJustNow => 'Just now';

  @override
  String get feedTimeToday => 'Today';

  @override
  String get feedTimeYesterday => 'Yesterday';

  @override
  String feedTimeMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String feedTimeHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours ago',
      one: '1 hour ago',
    );
    return '$_temp0';
  }

  @override
  String feedTimeDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String get socialLoadingComments => 'Loading comments...';

  @override
  String get socialMustBeLoggedInToComment =>
      'You must be logged in to comment';

  @override
  String get socialMustBeLoggedInToLike => 'You must be logged in to like';

  @override
  String get socialNoCommentsYet => 'No comments yet';

  @override
  String get socialRecipes => 'Recipes';

  @override
  String get socialSendMessage => 'Send message';

  @override
  String get socialShareRecipe => 'Share recipe';

  @override
  String get socialStartingConversation => 'Starting conversation...';

  @override
  String get socialStatistics => 'Statistics';

  @override
  String get socialUserProfileCreated => 'User profile created';

  @override
  String shoppingAddIngredientsFrom(String title) {
    return 'Add ingredients from \"$title\"';
  }

  @override
  String get shoppingAddToShoppingList => 'Add to shopping list';

  @override
  String get shoppingCouldNotAddIngredients =>
      'Could not add ingredients to the shopping list';

  @override
  String get shoppingCouldNotCreateOrSelectList =>
      'Could not create or select shopping list';

  @override
  String shoppingIngredientsAddedToList(int count, String listName) {
    return '$count ingredients have been added to \"$listName\".\n\nWould you like to go to the shopping list now?';
  }

  @override
  String shoppingIngredientsFromRecipe(int count, String title) {
    return '$count ingredients from \"$title\":';
  }

  @override
  String get shoppingNoEditPermission =>
      'You do not have permission to edit this shopping list';

  @override
  String get shoppingNoEditPermissionShared =>
      'You do not have permission to edit this shared shopping list';

  @override
  String get shoppingNoIngredientsToAdd =>
      'The recipe has no ingredients to add';

  @override
  String get shoppingSelectList => 'Select shopping list';

  @override
  String get shoppingViewList => 'View list';

  @override
  String get shoppingYourList => 'your shopping list';

  @override
  String get shoppingSharedLists => 'Shared shopping lists';

  @override
  String sharedByUser(String name) {
    return 'Shared by $name';
  }

  @override
  String get sharedContentWillAppearHere =>
      'When friends share recipes or menus with you, they will appear here.';

  @override
  String get sharedHideFromList => 'Hide from my list';

  @override
  String get sharedLoadingContent => 'Loading shared content...';

  @override
  String get sharedNoContentYet => 'No shared recipes yet';

  @override
  String get sharedEmptyStateExplanation =>
      'When you or your friends share recipes and menus, they\'ll appear here. Try sharing a recipe!';

  @override
  String get sharedShareFirstRecipe => 'Share a recipe';

  @override
  String get socialAddFriends => 'Add friends';

  @override
  String get taggingAnalyzingIngredients => 'Analyzing ingredients...';

  @override
  String get taggingCouldNotAnalyze => 'Could not analyze recipe';

  @override
  String get taggingCouldNotSaveTags => 'Could not save tags';

  @override
  String get taggingCreateTag => 'Create tag';

  @override
  String get taggingCreateTagsToOrganize =>
      'Create tags to organize your recipes';

  @override
  String taggingError(String error) {
    return 'Tagging error: $error';
  }

  @override
  String get taggingManageTags => 'Manage tags';

  @override
  String get tagSuggested => 'Suggested';

  @override
  String get tagAll => 'All tags';

  @override
  String get taggingNoPersonalTags => 'No personal tags';

  @override
  String get taggingPersonalTags => 'Personal tags';

  @override
  String get taggingPersonalTagsRemoved => 'Personal tags removed';

  @override
  String taggingPersonalTagsSaved(int count) {
    return '$count personal tags saved';
  }

  @override
  String taggingTagsGenerated(int count, int coverage) {
    return '$count tags generated ($coverage% coverage)';
  }

  @override
  String taggingTagsSelected(int count) {
    return '$count tags selected';
  }

  @override
  String taggingUpdateTagsMessage(String title) {
    return 'Analyzing ingredients and updating allergen and dietary tags for \"$title\".';
  }

  @override
  String get taggingUpdateTagsTitle => 'Update tags?';

  @override
  String get sortMealType => 'Meal type';

  @override
  String get sortRating => 'Rating';

  @override
  String get sortTime => 'Time';

  @override
  String get sortTitle => 'Title';

  @override
  String get sortLastCooked => 'Last cooked';

  @override
  String get sortCookCount => 'Times cooked';

  @override
  String get sortNewest => 'Newest';

  @override
  String get shuffleRecipes => 'Shuffle';

  @override
  String get importPreviewTitle => 'Preview import';

  @override
  String get importSelectAll => 'Select all';

  @override
  String get importDeselectAll => 'Deselect all';

  @override
  String importConfirmButton(int count) {
    return 'Import ($count)';
  }

  @override
  String importPreviewSubtitle(int ingredients, int steps) {
    return '$ingredients ingredients · $steps steps';
  }

  @override
  String get stateAddRecipes => 'Add recipes';

  @override
  String get stateCreateWeeklyMenu => 'Create weekly menu';

  @override
  String get stateGenerateMenu => 'Generate menu';

  @override
  String groupInvitationsCount(int count) {
    return 'Group invitations ($count)';
  }

  @override
  String get groupInvitationsDescription =>
      'You have received invitations to join groups';

  @override
  String get groupLoadingGroups => 'Loading groups...';

  @override
  String groupMyGroupsCount(int count) {
    return 'My groups ($count)';
  }

  @override
  String get groupNoGroupsDescription =>
      'Create your first group or wait for invitations from friends.';

  @override
  String get groupNoGroupsYet => 'No groups yet';

  @override
  String get groupSearchGroups => 'Search your groups';

  @override
  String get groupSearchGroupsDescription =>
      'Type a group name in the search field above to filter your groups.';

  @override
  String get groupCouldNotAcceptInvitation =>
      'Could not accept invitation. Please try again.';

  @override
  String get groupCreated => 'Created';

  @override
  String get groupDaysActive => 'Days active';

  @override
  String get groupDeleteGroup => 'Delete group';

  @override
  String get groupViewMembers => 'View members';

  @override
  String get groupEditGroup => 'Edit group';

  @override
  String get groupInformation => 'Group information';

  @override
  String get groupInvitationAccepted =>
      'Invitation accepted! Welcome to the group!';

  @override
  String get groupInvitationDeclined => 'Invitation declined';

  @override
  String groupInvitationFrom(String name) {
    return 'Invitation from $name';
  }

  @override
  String get groupLeaveGroup => 'Leave group';

  @override
  String groupMemberCount(int count) {
    return '$count people';
  }

  @override
  String get groupMembers => 'Members';

  @override
  String get groupMembersAndInvitations => 'Members & Invitations';

  @override
  String groupMembersCount(int count) {
    return 'Members ($count)';
  }

  @override
  String groupRemoveSelectedCount(int count) {
    return 'Remove selected ($count)';
  }

  @override
  String get groupNoDescription => 'No description';

  @override
  String get groupNoMembersDescription =>
      'Add friends to this group to get started.';

  @override
  String get groupNoMembersYet => 'No members yet';

  @override
  String groupPendingInvitationsCount(int count) {
    return 'Pending invitations ($count)';
  }

  @override
  String get groupSent => 'Sent';

  @override
  String get groupUpdatedDate => 'Updated';

  @override
  String get groupYesterday => 'Yesterday';

  @override
  String get commonAccept => 'Accept';

  @override
  String get commonDecline => 'Decline';

  @override
  String shoppingItemCount(int count) {
    return '$count items';
  }

  @override
  String get socialAddFriendsToGetStarted =>
      'Add friends to get started with social features.';

  @override
  String get socialLoadingFriends => 'Loading friends...';

  @override
  String get socialNoFriendsYet => 'No friends yet';

  @override
  String get socialSearchForNewFriends => 'Search for new friends';

  @override
  String get socialSearchForNewFriendsDescription =>
      'Type a name or username in the search field above to find new friends.';

  @override
  String get socialSearchingUsers => 'Searching users...';

  @override
  String get socialBlocked => 'Blocked';

  @override
  String get socialCouldNotAcceptFriendRequest =>
      'Could not accept friend request';

  @override
  String get socialCouldNotFindFriendRequest => 'Could not find friend request';

  @override
  String get socialCouldNotSendFriendRequest => 'Could not send friend request';

  @override
  String get socialDefaultFriendMessage => 'Hi! Would you like to be friends?';

  @override
  String get socialFindNewFriends => 'Find new friends';

  @override
  String get socialFindNewFriendsDescription =>
      'Use the search field above to find people you want to be friends with. Search by name or username.';

  @override
  String get socialInviteFriends => 'Invite friends';

  @override
  String get friendsEmptyHeadline => 'Cook together with friends';

  @override
  String get friendsEmptySubtitle =>
      'Share recipes, see what your friends are cooking, and plan menus together.';

  @override
  String get friendsEmptyFindByUsername => 'Find friends by username';

  @override
  String get socialInviteSubject => 'Join Butlery!';

  @override
  String get socialFriendRequestAccepted => 'Friend request accepted!';

  @override
  String socialFriendRequestAcceptedFrom(String name) {
    return 'Friend request from $name accepted!';
  }

  @override
  String get socialFriendRequestDeclined => 'Friend request declined';

  @override
  String socialFriendRequestSent(String name) {
    return 'Friend request sent to $name!';
  }

  @override
  String get socialIncomingRequests => 'Incoming requests';

  @override
  String get socialNoFriendRequests => 'No friend requests';

  @override
  String get socialNoFriendRequestsDescription =>
      'Start searching for friends above to expand your network!';

  @override
  String get socialRequestSent => 'Sent';

  @override
  String get socialSentRequests => 'Sent requests';

  @override
  String get socialWaitingForResponse => 'Waiting for response...';

  @override
  String get addRecipeTitle => 'Add recipe';

  @override
  String get authPassword => 'Password';

  @override
  String get authTagline => 'Your recipes. The rest sorts itself out.';

  @override
  String get collaborativeAdd => 'Add';

  @override
  String get collaborativeAddFirstItem => 'Add the first item';

  @override
  String get collaborativeAdding => 'Adding...';

  @override
  String get collaborativeAddItemHint => 'Type item name...';

  @override
  String get collaborativeClearAll => 'Clear all';

  @override
  String get collaborativeClearCompleted => 'Clear completed';

  @override
  String get collaborativeClearCompletedConfirm =>
      'Do you want to clear all completed items?';

  @override
  String collaborativeClearCompletedMessage(int count) {
    return 'Do you want to clear $count completed items?';
  }

  @override
  String get collaborativeCompleted => 'Completed';

  @override
  String collaborativeCompletedItemsCleared(int count) {
    return '$count completed items cleared';
  }

  @override
  String collaborativeCompletedOf(int completed, int total) {
    return '$completed of $total completed';
  }

  @override
  String get collaborativeCopyLink => 'Copy link';

  @override
  String get collaborativeCopyLinkDescription => 'Share via link';

  @override
  String get collaborativeCouldNotClearCompleted =>
      'Could not clear completed items';

  @override
  String get collaborativeEmailSharingComingSoon => 'Email sharing coming soon';

  @override
  String get collaborativeLinkCopied => 'Link copied!';

  @override
  String get collaborativeManageMembers => 'Manage members';

  @override
  String get collaborativeMembersComingSoon => 'Member management coming soon';

  @override
  String get collaborativeMessageSharingComingSoon =>
      'Message sharing coming soon';

  @override
  String get collaborativeMoreActions => 'More actions';

  @override
  String get collaborativeNoCompletedItems => 'No completed items';

  @override
  String get collaborativeNoItemsYet => 'No items yet';

  @override
  String get collaborativeSendEmail => 'Send email';

  @override
  String get collaborativeSendEmailDescription => 'Share via email';

  @override
  String get collaborativeSendMessage => 'Send message';

  @override
  String get collaborativeSendMessageDescription => 'Share via message';

  @override
  String get collaborativeSettings => 'Settings';

  @override
  String get collaborativeSettingsComingSoon => 'Settings coming soon';

  @override
  String get collaborativeShareList => 'Share list';

  @override
  String get collaborativeViewOnly => 'View only';

  @override
  String get collaborativeWaitingForOthers => 'Waiting for others...';

  @override
  String get commonActionCannotBeUndone => 'This action cannot be undone.';

  @override
  String get commonDescription => 'Description';

  @override
  String get commonShowMore => 'Show more';

  @override
  String get commonType => 'Type';

  @override
  String get commonUnknownError => 'An unknown error occurred';

  @override
  String get commonView => 'View';

  @override
  String get groupCancelInvitation => 'Cancel invitation';

  @override
  String get groupCancelInvitationConfirm =>
      'Are you sure you want to cancel this invitation?';

  @override
  String groupCancelInvitationMessage(String name) {
    return 'Do you want to cancel the invitation to $name?';
  }

  @override
  String groupCouldNotCreate(String error) {
    return 'Could not create group: $error';
  }

  @override
  String groupCouldNotDelete(String error) {
    return 'Could not delete group: $error';
  }

  @override
  String groupCouldNotLeave(String error) {
    return 'Could not leave group: $error';
  }

  @override
  String groupCouldNotRemoveMember(String error) {
    return 'Could not remove member: $error';
  }

  @override
  String groupCouldNotUpdate(String error) {
    return 'Could not update group: $error';
  }

  @override
  String get groupCreatedSuccess => 'Group created!';

  @override
  String get groupCreateGroup => 'Create group';

  @override
  String get groupCreator => 'Creator';

  @override
  String get groupEmoji => 'Emoji';

  @override
  String get groupGroupName => 'Group name';

  @override
  String get groupInvitationCancelled => 'Invitation cancelled';

  @override
  String get groupInvitationExpires => 'Invitation expires';

  @override
  String get groupInvitationSentDate => 'Sent';

  @override
  String get groupItemType => 'Type';

  @override
  String get groupLeave => 'Leave';

  @override
  String groupLeaveGroupConfirm(String name) {
    return 'Do you want to leave the group $name?';
  }

  @override
  String get groupLeftGroup => 'You have left the group';

  @override
  String get groupManageGroup => 'Manage group';

  @override
  String groupMemberRemoved(String name) {
    return '$name has been removed';
  }

  @override
  String groupRemoveMultipleConfirm(int count, String group) {
    return 'Remove $count members from $group?';
  }

  @override
  String groupMembersRemoved(int count) {
    return '$count members removed';
  }

  @override
  String groupMembersPartiallyRemoved(int removed, String failedNames) {
    return '$removed members removed — could not remove: $failedNames';
  }

  @override
  String get groupOwner => 'Owner';

  @override
  String get groupRemoveFromGroup => 'Remove from group';

  @override
  String get groupRemoveMember => 'Remove member';

  @override
  String groupRemoveMemberConfirm(String name, String groupName) {
    return 'Do you want to remove $name from $groupName?';
  }

  @override
  String get groupShareMenu => 'Share menu';

  @override
  String get groupShareRecipe => 'Share recipe';

  @override
  String get groupShareWithGroup => 'Share with group';

  @override
  String get groupYesCancel => 'Yes, cancel';

  @override
  String get sharedAlreadyMember => 'You are already a member';

  @override
  String get sharedContent => 'Shared content';

  @override
  String get sharedCopy => 'Copy';

  @override
  String get sharedCouldNotHideMenu => 'Could not hide menu';

  @override
  String get sharedCouldNotHideRecipe => 'Could not hide recipe';

  @override
  String get sharedCouldNotHideShoppingList => 'Could not hide shopping list';

  @override
  String get sharedCouldNotJoinList => 'Could not join the list';

  @override
  String get sharedCouldNotJoinListTryAgain =>
      'Could not join the list. Try again.';

  @override
  String get sharedHideImported => 'Hide imported';

  @override
  String get sharedHideMenu => 'Hide menu';

  @override
  String get sharedHideRecipe => 'Hide recipe';

  @override
  String get sharedHideShoppingList => 'Hide shopping list';

  @override
  String get sharedImport => 'Import';

  @override
  String get sharedImported => 'Imported';

  @override
  String get sharedReplyToSender => 'Reply';

  @override
  String get sharedImportFailed => 'Import failed';

  @override
  String get sharedJoin => 'Join';

  @override
  String get sharedJoinedButCouldNotNavigate =>
      'Joined but could not navigate to the list';

  @override
  String get sharedJoinList => 'Join list';

  @override
  String get sharedLive => 'Live';

  @override
  String get sharedMember => 'Member';

  @override
  String get sharedNoMenus => 'No shared menus';

  @override
  String get sharedNoMenusDescription =>
      'Menus shared with you will appear here';

  @override
  String get sharedNoRecipes => 'No shared recipes';

  @override
  String get sharedNoRecipesDescription =>
      'Recipes shared with you will appear here';

  @override
  String get sharedRecipesByFriendButton => 'Recipes shared with me';

  @override
  String sharedRecipesByFriendTitle(String name) {
    return 'Recipes from $name';
  }

  @override
  String sharedNoRecipesFromFriend(String name) {
    return '$name hasn\'t shared any recipes with you yet';
  }

  @override
  String get sharedNoShoppingLists => 'No shared shopping lists';

  @override
  String get sharedNoShoppingListsDescription =>
      'Shopping lists shared with you will appear here';

  @override
  String get sharedSearchHint => 'Search shared content...';

  @override
  String sharedTabRecipes(int count) {
    return 'Recipes ($count)';
  }

  @override
  String sharedTabMenus(int count) {
    return 'Menus ($count)';
  }

  @override
  String sharedTabShoppingLists(int count) {
    return 'Shopping lists ($count)';
  }

  @override
  String get sharedShowImported => 'Show imported';

  @override
  String get sharedShowingImported => 'Showing imported';

  @override
  String get sharedTapToSeeAllItems => 'Tap to see all items';

  @override
  String sharedByName(String name) {
    return 'Shared by $name';
  }

  @override
  String sharedCategoryCount(int count) {
    return '$count categories';
  }

  @override
  String sharedConnectingToCollaborativeMenu(String title) {
    return 'Connecting to collaborative menu: $title';
  }

  @override
  String sharedContentHidden(String title) {
    return '$title has been hidden';
  }

  @override
  String sharedHideMenuConfirm(String title, String sharedBy) {
    return 'Do you want to hide the menu \"$title\" shared by $sharedBy?';
  }

  @override
  String sharedHideRecipeConfirm(String title, String sharedBy) {
    return 'Do you want to hide the recipe \"$title\" shared by $sharedBy?';
  }

  @override
  String sharedHideShoppingListConfirm(String name, String sharedBy) {
    return 'Do you want to hide the shopping list \"$name\" shared by $sharedBy?';
  }

  @override
  String sharedJoinedList(String name) {
    return 'Joined the list \"$name\"';
  }

  @override
  String sharedJoinedListFindInShopping(String name) {
    return 'Joined \"$name\". Find it in Shopping Lists.';
  }

  @override
  String sharedMenuImported(String title) {
    return 'Menu \"$title\" has been imported';
  }

  @override
  String sharedRecipeImported(String title) {
    return 'Recipe \"$title\" has been imported';
  }

  @override
  String recipePortionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servings',
      one: '1 serving',
    );
    return '$_temp0';
  }

  @override
  String get shoppingAddedWithEditPermission => 'Added with edit permission';

  @override
  String get shoppingAddFriends => 'Add friends';

  @override
  String get shoppingAdminOwner => 'Admin/Owner';

  @override
  String get shoppingAdminOwnerDescription => 'Full access and management';

  @override
  String get shoppingAllFriendsAreMembers => 'All friends are already members';

  @override
  String get shoppingBy => 'By';

  @override
  String get shoppingCategoryHint => 'Select category...';

  @override
  String get shoppingClear => 'Clear';

  @override
  String get shoppingClearPurchasedTitle => 'Clear purchased items';

  @override
  String get shoppingCouldNotAddMembers => 'Could not add members';

  @override
  String get shoppingCouldNotDeleteList => 'Could not delete list';

  @override
  String get shoppingCouldNotLoadLists => 'Could not load shopping lists';

  @override
  String get shoppingCouldNotRemoveMember => 'Could not remove member';

  @override
  String get shoppingCouldNotRenameList => 'Could not rename list';

  @override
  String get shoppingCouldNotUpdatePermission => 'Could not update permission';

  @override
  String get shoppingCreateNewList => 'Create new list';

  @override
  String get shoppingCreateNewListHint => 'Name for new shopping list...';

  @override
  String get shoppingCreateSharedList => 'Create shared list';

  @override
  String get shoppingCreateSharedListDescription =>
      'Create a new shopping list to share with friends';

  @override
  String get shoppingCreator => 'Creator';

  @override
  String get shoppingDeleteList => 'Delete list';

  @override
  String get shoppingDescriptionHint => 'Add a description...';

  @override
  String get shoppingDescriptionOptional => 'Description (optional)';

  @override
  String get shoppingItemNameHint => 'Item name...';

  @override
  String get shoppingJustNow => 'Just now';

  @override
  String get shoppingListDetails => 'List details';

  @override
  String get shoppingListInfo => 'List information';

  @override
  String get shoppingListTitle => 'Shopping list';

  @override
  String get shoppingManageSharing => 'Manage sharing';

  @override
  String get shoppingNewNameHint => 'New name...';

  @override
  String get shoppingNoFriends => 'No friends';

  @override
  String get shoppingNoFriendsDescription =>
      'Add friends to share shopping lists';

  @override
  String get shoppingNoFriendsFound => 'No friends found';

  @override
  String get shoppingNoItemsToShare => 'No items to share';

  @override
  String get shoppingNoteHint => 'Add a note...';

  @override
  String get shoppingNoteOptional => 'Note (optional)';

  @override
  String get shoppingPermissionAdmin => 'Administrator';

  @override
  String get shoppingPermissionAdminDescription =>
      'Can add, remove, and manage members';

  @override
  String get shoppingPermissionAdministrator => 'Administrator';

  @override
  String get shoppingPermissionEdit => 'Edit';

  @override
  String get shoppingPermissionEditDescription => 'Can add and edit items';

  @override
  String get shoppingPermissionOwner => 'Owner';

  @override
  String get shoppingPermissionShared => 'Shared';

  @override
  String get shoppingPermissionTemplate => 'Template';

  @override
  String get shoppingPermissionUnspecified => 'Unspecified';

  @override
  String get shoppingPermissionUnspecifiedDescription =>
      'Permission not specified';

  @override
  String get shoppingPermissionView => 'View';

  @override
  String get shoppingPermissionViewDescription =>
      'Can view items but not modify';

  @override
  String get shoppingPermissionViewOnly => 'View only';

  @override
  String get shoppingPersonalList => 'Personal list';

  @override
  String get shoppingPurchased => 'Purchased';

  @override
  String get shoppingPurchasedCleared => 'Purchased items cleared';

  @override
  String get shoppingRecentActivity => 'Recent activity';

  @override
  String get shoppingRemoveMember => 'Remove member';

  @override
  String get shoppingSearchFriends => 'Search friends...';

  @override
  String get shoppingSelectFriendsToShare => 'Select friends to share with';

  @override
  String get shoppingSharedList => 'Shared list';

  @override
  String get shoppingSharedListTitle => 'Shared shopping list';

  @override
  String get shoppingSharedListTitleHint => 'Name for shared list...';

  @override
  String get shoppingShareExternally => 'Share externally';

  @override
  String get shoppingShareInfoBullets =>
      'Members can see and edit items in real time';

  @override
  String get shoppingShareWithFriends => 'Share with friends';

  @override
  String get shoppingTemplateList => 'Template';

  @override
  String get shoppingUncheckAll => 'Uncheck all';

  @override
  String get shoppingMoveToCategory => 'Move to category';

  @override
  String get shoppingSortCategories => 'Sort categories';

  @override
  String get shoppingCategoryOrderTitle => 'Category order';

  @override
  String get shoppingResetOrder => 'Reset';

  @override
  String get shoppingSaveOrder => 'Save order';

  @override
  String get shoppingOtherCategories => 'Other categories';

  @override
  String get shoppingDragToMove => 'Hold to move';

  @override
  String get shoppingCategorySaved => 'Category order saved';

  @override
  String shoppingItemMoved(String category) {
    return 'Moved to $category';
  }

  @override
  String get shoppingUnitHint => 'Unit...';

  @override
  String get shoppingUnknownUser => 'Unknown user';

  @override
  String get shoppingWhatHappensWhenSharing => 'What happens when you share?';

  @override
  String get shoppingWhen => 'When';

  @override
  String get shoppingYourPermission => 'Your permission';

  @override
  String shoppingAddFriendsCount(int count) {
    return 'Add $count friends';
  }

  @override
  String shoppingBoughtOfTotal(int bought, int total) {
    return '$bought of $total bought';
  }

  @override
  String shoppingClearCount(int count) {
    return 'Clear $count';
  }

  @override
  String shoppingClearPurchasedMessage(int count) {
    return 'Do you want to clear $count purchased items?';
  }

  @override
  String shoppingCouldNotAddItem(String name) {
    return 'Could not add $name';
  }

  @override
  String shoppingCouldNotLoadFriends(String error) {
    return 'Could not load friends: $error';
  }

  @override
  String shoppingCouldNotShowShareDialog(String error) {
    return 'Could not show share dialog: $error';
  }

  @override
  String shoppingCouldNotUpdateItem(String name) {
    return 'Could not update $name';
  }

  @override
  String shoppingCurrentMembers(int count) {
    return 'Current members ($count)';
  }

  @override
  String shoppingCurrentName(String name) {
    return 'Current name: $name';
  }

  @override
  String shoppingDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String shoppingDeleteListConfirm(String name) {
    return 'Do you want to delete the list \"$name\"?';
  }

  @override
  String shoppingDeleteListWithItemsConfirm(String name, int count) {
    return 'Do you want to delete the list \"$name\" with $count items?';
  }

  @override
  String shoppingErrorAdding(String error) {
    return 'Error adding: $error';
  }

  @override
  String shoppingErrorRemoving(String error) {
    return 'Error removing: $error';
  }

  @override
  String shoppingErrorUpdating(String error) {
    return 'Error updating: $error';
  }

  @override
  String shoppingHoursAgo(int hours) {
    return '$hours hours ago';
  }

  @override
  String shoppingItemAdded(String itemName) {
    return 'Added \"$itemName\"';
  }

  @override
  String shoppingItemCountText(int count) {
    return '$count items';
  }

  @override
  String shoppingItemUpdated(String name) {
    return '$name updated';
  }

  @override
  String shoppingListDeleted(String name) {
    return 'List \"$name\" deleted';
  }

  @override
  String shoppingListRenamed(String name) {
    return 'List renamed to \"$name\"';
  }

  @override
  String shoppingMemberRemoved(String name) {
    return '$name has been removed';
  }

  @override
  String shoppingMembersAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members added',
      one: '1 member added',
    );
    return '$_temp0';
  }

  @override
  String shoppingMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
      zero: 'No members',
    );
    return '$_temp0';
  }

  @override
  String shoppingMinutesAgo(int minutes) {
    return '$minutes minutes ago';
  }

  @override
  String shoppingPermissionUpdated(String name) {
    return 'Permission updated for $name';
  }

  @override
  String shoppingRemoveMemberConfirm(String name) {
    return 'Do you want to remove $name from the list?';
  }

  @override
  String shoppingSharedWithMembers(int count, String permission) {
    return 'Shared with $count ($permission)';
  }

  @override
  String get socialAcceptAll => 'Accept all';

  @override
  String get socialAcceptAllSelectedConfirm => 'Accept all selected requests?';

  @override
  String get socialAcceptSelected => 'Accept selected';

  @override
  String get socialBlock => 'Block';

  @override
  String get socialBlockUserConfirm => 'Do you want to block this user?';

  @override
  String get socialCancelAll => 'Cancel all';

  @override
  String get socialCancelFriendRequestConfirm =>
      'Do you want to cancel this friend request?';

  @override
  String get socialCancelRequest => 'Cancel request';

  @override
  String get socialCancelSelectedRequestsConfirm =>
      'Cancel all selected requests?';

  @override
  String get socialCouldNotAcceptAllRequests => 'Could not accept all requests';

  @override
  String get socialCouldNotBlockUser => 'Could not block user';

  @override
  String get socialCouldNotCancelAllRequests => 'Could not cancel all requests';

  @override
  String get socialCouldNotCancelFriendRequest =>
      'Could not cancel friend request';

  @override
  String get socialCouldNotRejectAllRequests => 'Could not reject all requests';

  @override
  String get socialCouldNotRejectFriendRequest =>
      'Could not reject friend request';

  @override
  String get socialCouldNotRemoveFriend => 'Could not remove friend';

  @override
  String get socialCouldNotSearchUsers => 'Could not search users';

  @override
  String get socialCouldNotUnblockUser => 'Could not unblock user';

  @override
  String get socialCouldNotUpdateRequests => 'Could not update requests';

  @override
  String get socialDecline => 'Decline';

  @override
  String get socialDeclined => 'Declined';

  @override
  String get socialEnterSearchTerm => 'Enter a search term';

  @override
  String get socialExpired => 'Expired';

  @override
  String get socialFindFriends => 'Find friends';

  @override
  String get socialFriendRequestsUpdated => 'Friend requests updated';

  @override
  String get socialFriendsAndGroups => 'Friends & groups';

  @override
  String get socialGroups => 'Groups';

  @override
  String get socialIncoming => 'Incoming';

  @override
  String get socialLoadingRequests => 'Loading requests...';

  @override
  String get socialLoadingSentRequests => 'Loading sent requests...';

  @override
  String get socialNoRequestsSelected => 'No requests selected';

  @override
  String get socialNoSentRequests => 'No sent requests';

  @override
  String get socialNoSentRequestsDescription =>
      'You have no sent friend requests';

  @override
  String get socialPendingResponse => 'Pending response';

  @override
  String get socialReject => 'Reject';

  @override
  String get socialRejectAll => 'Reject all';

  @override
  String get socialRejectAllSelectedConfirm => 'Reject all selected requests?';

  @override
  String get socialRejectFriendRequestConfirm =>
      'Do you want to reject this friend request?';

  @override
  String get socialRemoveFriendConfirm => 'Do you want to remove this friend?';

  @override
  String get socialRequestCancelled => 'Request cancelled';

  @override
  String get socialSearchGroups => 'Search groups...';

  @override
  String get socialSearchNewFriends => 'Search for new friends';

  @override
  String get socialUnknownStatus => 'Unknown status';

  @override
  String get socialWantsToBeFriend => 'wants to be your friend';

  @override
  String socialAcceptAllSelectedMessage(int count) {
    return 'Do you want to accept $count selected requests?';
  }

  @override
  String socialAcceptCount(int count) {
    return 'Accept ($count)';
  }

  @override
  String socialAcceptingRequests(int count) {
    return 'Accepting $count requests...';
  }

  @override
  String socialBlockUserMessage(String name) {
    return 'Do you want to block $name? They won\'t be able to see your profile or send requests.';
  }

  @override
  String socialCancelCount(int count) {
    return 'Cancel ($count)';
  }

  @override
  String socialCancelFriendRequestMessage(String name) {
    return 'Do you want to cancel the friend request to $name?';
  }

  @override
  String socialCancellingRequests(int count) {
    return 'Cancelling $count requests...';
  }

  @override
  String socialCancelSelectedRequestsMessage(int count) {
    return 'Do you want to cancel $count selected requests?';
  }

  @override
  String socialDeclineCount(int count) {
    return 'Decline ($count)';
  }

  @override
  String socialFriendRequestCancelled(String name) {
    return 'Friend request to $name cancelled';
  }

  @override
  String socialFriendRequestRejected(String name) {
    return 'Friend request from $name rejected';
  }

  @override
  String socialNotificationsCount(int count) {
    return 'Notifications ($count)';
  }

  @override
  String socialRejectAllSelectedMessage(int count) {
    return 'Do you want to reject $count selected requests?';
  }

  @override
  String socialRejectFriendRequestMessage(String name) {
    return 'Do you want to reject the friend request from $name?';
  }

  @override
  String socialRejectingRequests(int count) {
    return 'Rejecting $count requests...';
  }

  @override
  String socialRemoveFriendMessage(String name) {
    return 'Do you want to remove $name as a friend?';
  }

  @override
  String socialRequestsAccepted(int count) {
    return '$count requests accepted';
  }

  @override
  String socialRequestsCancelled(int count) {
    return '$count requests cancelled';
  }

  @override
  String socialRequestsRejected(int count) {
    return '$count requests rejected';
  }

  @override
  String socialRequestsSelected(int count) {
    return '$count selected';
  }

  @override
  String socialUserBlocked(String name) {
    return '$name has been blocked';
  }

  @override
  String socialUserUnblocked(String name) {
    return '$name has been unblocked';
  }

  @override
  String get authLogin => 'Log in';

  @override
  String get authCreateAccount => 'Create account';

  @override
  String get authYourName => 'Your name';

  @override
  String get authEnterYourName => 'Enter your name';

  @override
  String get authEmail => 'Email';

  @override
  String get authEmailHint => 'name@example.com';

  @override
  String get authTermsOfService => 'Terms';

  @override
  String get authResetEmailSent => 'Email sent! Check your inbox.';

  @override
  String get authResetEmailFailed => 'Could not send email';

  @override
  String get avatarUnknownUser => 'Unknown user';

  @override
  String get commonNow => 'now';

  @override
  String get commonJustNow => 'just now';

  @override
  String get imageNoImagesYet => 'No images yet';

  @override
  String get imageWillAppearHere => 'Images will appear here';

  @override
  String get imageNoImagesToDisplay => 'No images to display';

  @override
  String get imageRemoveImage => 'Remove image';

  @override
  String get imageSetAsPrimary => 'Set as primary';

  @override
  String get imageSelectedImages => 'Selected images';

  @override
  String get imageSelectImages => 'Select images';

  @override
  String get imageSelectingImages => 'Selecting images...';

  @override
  String get imageTapToSelectOne => 'Tap to select an image';

  @override
  String get messagingCancelReply => 'Cancel reply';

  @override
  String get messagingImagePreview => 'Image';

  @override
  String get navigationRecipes => 'recipes';

  @override
  String get navigationMenu => 'menu';

  @override
  String get navigationShopping => 'shopping';

  @override
  String get navigationAddNew => 'add new';

  @override
  String get recipeRecipe => 'Recipe';

  @override
  String get recipeSharedFromApp => 'Shared from another app';

  @override
  String get shoppingBought => 'bought';

  @override
  String get shoppingCollaborative => 'Collaborative';

  @override
  String get shoppingCopyLink => 'Copy link';

  @override
  String get shoppingCopyList => 'Copy list';

  @override
  String get shoppingRemaining => 'remaining';

  @override
  String get shoppingShareForward => 'Share forward';

  @override
  String get shoppingShareShoppingList => 'Share shopping list';

  @override
  String get shoppingShoppingList => 'Shopping list';

  @override
  String get shoppingTotal => 'total';

  @override
  String get socialCreateProfile => 'Create Profile';

  @override
  String get socialProfileCreatedRestart => 'Profile created! Restart the app.';

  @override
  String get socialReport => 'Report';

  @override
  String get socialReportContent => 'Report content';

  @override
  String get socialReportCopyright => 'Copyright infringement';

  @override
  String get socialReportInappropriate => 'Inappropriate content';

  @override
  String get socialReportIncorrectInfo => 'Incorrect information';

  @override
  String get socialReportOther => 'Other';

  @override
  String get socialReportSent => 'Report sent. Thank you for your feedback!';

  @override
  String get socialReportShoppingListReason =>
      'Why do you want to report this shopping list?';

  @override
  String get socialReportSpam => 'Spam or advertising';

  @override
  String commonDaysAgo(int days) {
    return '$days days ago';
  }

  @override
  String commonHoursAgo(int hours) {
    return '$hours hours ago';
  }

  @override
  String commonMinutesAgo(int minutes) {
    return '$minutes minutes ago';
  }

  @override
  String imageCountSelected(int count) {
    return '$count selected';
  }

  @override
  String imageFailedToSelect(String error) {
    return 'Failed to select images: $error';
  }

  @override
  String imageSelectedCount(int count, int max) {
    return '$count of $max images selected';
  }

  @override
  String imageTapToSelectUpTo(int count) {
    return 'Tap to select up to $count images';
  }

  @override
  String messagingRecipePreview(String title) {
    return '$title';
  }

  @override
  String messagingReplyingTo(String name) {
    return 'Replying to $name';
  }

  @override
  String shoppingCouldNotOpenShareMenu(String error) {
    return 'Could not open share menu: $error';
  }

  @override
  String shoppingCouldNotShareList(String error) {
    return 'Could not share the list: $error';
  }

  @override
  String shoppingSharedBy(String name) {
    return 'Shared by $name';
  }

  @override
  String shoppingShareListWith(String name) {
    return 'Share \"$name\" with:';
  }

  @override
  String shoppingSharingComingSoon(String option) {
    return 'Sharing via $option coming soon!';
  }

  @override
  String socialCouldNotSendReport(String error) {
    return 'Could not send report: $error';
  }

  @override
  String socialLikeCount(int count) {
    return '$count likes';
  }

  @override
  String socialLikesHeader(int count) {
    return 'Likes ($count)';
  }

  @override
  String get commonAdding => 'Adding...';

  @override
  String get a11yHidePassword => 'Hide password';

  @override
  String get a11yShowPassword => 'Show password';

  @override
  String get a11yLoading => 'Loading';

  @override
  String get a11yNavigationLandmark => 'Main navigation';

  @override
  String a11yAppBarHeaderHint(String title) {
    return 'Page title: $title';
  }

  @override
  String get a11yShareWithFriends => 'Share with friends';

  @override
  String get a11yNoItemsToShare => 'No items to share';

  @override
  String get a11yShareExternally => 'Share externally';

  @override
  String get a11yAddItem => 'Add item';

  @override
  String get a11yAddFriend => 'Add friend';

  @override
  String a11yTagStatusInfo(String status) {
    return 'More information about $status';
  }

  @override
  String a11yRateStars(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Rate $count stars',
      one: 'Rate 1 star',
    );
    return '$_temp0';
  }

  @override
  String a11yShoppingItemChecked(String itemText) {
    return '$itemText, checked, tap to uncheck';
  }

  @override
  String a11yShoppingItemUnchecked(String itemText) {
    return '$itemText, tap to check off';
  }

  @override
  String a11yShoppingSelectItem(String itemText) {
    return '$itemText, tap to select';
  }

  @override
  String a11yShoppingReorderHandle(String itemName) {
    return '$itemName, drag to move category';
  }

  @override
  String shoppingSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String shoppingItemsRemovedUndoMessage(int count) {
    return '$count removed';
  }

  @override
  String a11yTagSelected(String tagName) {
    return '$tagName, selected. Double tap to remove.';
  }

  @override
  String a11yTagUnselected(String tagName) {
    return '$tagName. Double tap to select.';
  }

  @override
  String a11ySharedShoppingList(String listName) {
    return 'Shared shopping list: $listName';
  }

  @override
  String get a11yPrimaryImageTap => 'Primary image, tap to view full size';

  @override
  String get a11ySelectAsPrimary => 'Select as primary image';

  @override
  String get a11yAddImage => 'Add image';

  @override
  String get a11yRemoveImage => 'Remove image';

  @override
  String get a11yViewFullSizeImage => 'View full size image';

  @override
  String a11yViewFullSizeImageOf(int current, int total) {
    return 'View full size image $current of $total';
  }

  @override
  String a11ySwitchToImageOf(int current, int total) {
    return 'Switch to image $current of $total';
  }

  @override
  String get a11yShrinkImage => 'Shrink image';

  @override
  String get a11yEnlargeImage => 'Enlarge image';

  @override
  String get a11yLoadImage => 'Load image';

  @override
  String get a11yMessageSwipeToReply => 'Message, swipe to reply';

  @override
  String get a11yMessageLongPressOptions =>
      'Message content, long press for options';

  @override
  String get a11yImageMessageTap => 'Image message, tap for full size';

  @override
  String get a11yReplyToComment => 'Reply to comment';

  @override
  String get a11yUnlikeComment => 'Remove like';

  @override
  String get a11yLikeComment => 'Like comment';

  @override
  String a11yProfileImage(String displayName) {
    return 'Profile image for $displayName';
  }

  @override
  String get a11yStatusOnline => 'Online';

  @override
  String get a11yStatusOffline => 'Offline';

  @override
  String get a11yChangeProfileImage => 'Change profile image';

  @override
  String a11yShoppingList(String name) {
    return 'Shopping list: $name';
  }

  @override
  String a11yFriend(String name) {
    return 'Friend: $name';
  }

  @override
  String get a11yFriendRequest => 'Friend request';

  @override
  String a11yFilterTag(String tagName, String status) {
    return 'Filter by $tagName, $status';
  }

  @override
  String get a11yActive => 'active';

  @override
  String get a11yInactive => 'inactive';

  @override
  String a11yExcludeTag(String tagName, String status) {
    return 'Exclude $tagName, $status';
  }

  @override
  String get a11yAllergenStatusRow => 'Allergen status';

  @override
  String get a11yDietaryStatusRow => 'Dietary status';

  @override
  String get a11yShowImage => 'Show image';

  @override
  String a11yShowMore(int count) {
    return 'Show $count more';
  }

  @override
  String a11yEditItem(String name) {
    return 'Edit $name';
  }

  @override
  String a11yDeleteItem(String name) {
    return 'Delete $name';
  }

  @override
  String a11ySharedRecipe(String title) {
    return 'Shared recipe: $title';
  }

  @override
  String a11ySharedMenu(String title) {
    return 'Shared menu: $title';
  }

  @override
  String get a11yRemoveProfileImage => 'Remove profile image';

  @override
  String a11yMenu(String title) {
    return 'Menu: $title';
  }

  @override
  String get filterBreakfast => 'Breakfast';

  @override
  String get filterLunch => 'Lunch';

  @override
  String get filterDinner => 'Dinner';

  @override
  String get filterSnack => 'Snack';

  @override
  String get filterDessert => 'Dessert';

  @override
  String get filterGlutenFree => 'Gluten-free';

  @override
  String get filterDairyFree => 'Dairy-free';

  @override
  String get filterLactoseFree => 'Lactose-free';

  @override
  String get filterNutFree => 'Nut-free';

  @override
  String get filterEggFree => 'Egg-free';

  @override
  String get filterSoyFree => 'Soy-free';

  @override
  String get filterFishFree => 'Fish-free';

  @override
  String get filterSesameFree => 'Sesame-free';

  @override
  String get filterCeleryFree => 'Celery-free';

  @override
  String get filterMustardFree => 'Mustard-free';

  @override
  String get filterShellfishFree => 'Shellfish-free';

  @override
  String get filterLupinFree => 'Lupin-free';

  @override
  String get filterSulfiteFree => 'Sulfite-free';

  @override
  String get filterPeanutFree => 'Peanut-free';

  @override
  String get filterTreeNutFree => 'Tree nut-free';

  @override
  String get filterAlcoholFree => 'Alcohol-free';

  @override
  String get filterMoreAllergens => 'More allergens';

  @override
  String get filterFewerAllergens => 'Fewer allergens';

  @override
  String get onboardingAllergenCelery => 'Celery';

  @override
  String get onboardingAllergenMustard => 'Mustard';

  @override
  String get onboardingAllergenLupin => 'Lupin';

  @override
  String get onboardingAllergenSulfite => 'Sulfites';

  @override
  String get onboardingAllergenLactose => 'Lactose';

  @override
  String get onboardingAllergenPeanut => 'Peanuts';

  @override
  String get onboardingAllergenTreeNut => 'Tree nuts';

  @override
  String get onboardingAllergenCrustacean => 'Crustaceans';

  @override
  String get onboardingAllergenMollusc => 'Molluscs';

  @override
  String get onboardingShowAllAllergens => 'Show all allergens';

  @override
  String get onboardingShowFewerAllergens => 'Show fewer';

  @override
  String get filterVegetarian => 'Vegetarian';

  @override
  String get filterVegan => 'Vegan';

  @override
  String get filterPescetarian => 'Pescetarian';

  @override
  String get filterHalal => 'Halal-friendly';

  @override
  String get filterKidFriendly => 'Kid-friendly';

  @override
  String get unitPieces => 'pcs';

  @override
  String get unitLiter => 'liter';

  @override
  String get unitTablespoon => 'tbsp';

  @override
  String get unitPinch => 'pinch';

  @override
  String get unitPackage => 'package';

  @override
  String get unitPackageShort => 'pkg';

  @override
  String get unitTeaspoon => 'tsp';

  @override
  String get unitBag => 'bag';

  @override
  String get unitCan => 'can';

  @override
  String get unitBottle => 'bottle';

  @override
  String get unitPiece => 'piece';

  @override
  String get unitClove => 'clove';

  @override
  String get categoryFruitVeg => 'Fruit & Vegetables';

  @override
  String get categoryDairy => 'Dairy';

  @override
  String get categoryMeatFish => 'Meat & Fish';

  @override
  String get categoryBread => 'Bread';

  @override
  String get categoryPantry => 'Pantry';

  @override
  String get categoryFrozen => 'Frozen';

  @override
  String get categoryBeverage => 'Beverages';

  @override
  String get categorySnacks => 'Snacks & Candy';

  @override
  String get categoryHygiene => 'Cleaning & Hygiene';

  @override
  String get categoryOther => 'Other';

  @override
  String get categorySpices => 'Spices';

  @override
  String get categoryCanned => 'Canned Goods';

  @override
  String get categoryDryGoods => 'Dry Goods';

  @override
  String get categoryMeat => 'Meat';

  @override
  String get categoryFish => 'Fish';

  @override
  String get categoryFruit => 'Fruit';

  @override
  String get categoryVeg => 'Vegetables';

  @override
  String get conflictBannerMessage =>
      'Sync conflict resolved — the latest edit was saved';

  @override
  String get conflictBannerDismiss => 'Dismiss';

  @override
  String get a11yConflictBannerDismiss => 'Dismiss conflict notification';

  @override
  String get conflictDiffTitle => 'What changed';

  @override
  String get conflictDiffLocalLabel => 'My version';

  @override
  String get conflictDiffRemoteLabel => 'Their version';

  @override
  String get conflictDiffKeepMine => 'Keep my version';

  @override
  String get conflictDiffKeptToast => 'Your version was saved';

  @override
  String get conflictDiffKeepFailed => 'Couldn\'t save your version';

  @override
  String get conflictDiffNoChanges =>
      'No field changes to show — the versions are identical.';

  @override
  String get conflictDiffEmptyValue => '(empty)';

  @override
  String get privacyEmailSubject => 'Privacy inquiry';

  @override
  String get unshareRecipeTitle => 'Stop sharing recipe?';

  @override
  String unshareRecipeConfirm(String title) {
    return 'The recipe \"$title\" will be removed from all groups it was shared with.';
  }

  @override
  String get unshareMenuTitle => 'Stop sharing menu?';

  @override
  String unshareMenuConfirm(String title) {
    return 'The menu \"$title\" will be removed from all groups it was shared with.';
  }

  @override
  String get unshareShoppingListTitle => 'Stop sharing shopping list?';

  @override
  String unshareShoppingListConfirm(String name) {
    return 'The shopping list \"$name\" will be removed from all groups it was shared with.';
  }

  @override
  String get unshareButton => 'Stop sharing';

  @override
  String unshareSuccess(String title) {
    return '\"$title\" is no longer shared';
  }

  @override
  String get unshareFailed => 'Could not stop sharing. Try again.';

  @override
  String get menuCommentsTitle => 'Comments';

  @override
  String menuCommentsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count comments',
      one: '1 comment',
      zero: 'No comments',
    );
    return '$_temp0';
  }

  @override
  String get menuNoCommentsYet => 'No comments yet';

  @override
  String get menuBeFirstToComment => 'Be the first to comment on this menu!';

  @override
  String get menuLoadingComments => 'Loading comments...';

  @override
  String get menuWriteComment => 'Write a comment about the menu...';

  @override
  String get menuCommentPostedSuccess => 'Comment posted!';

  @override
  String get menuCommentPostFailed => 'Could not post comment';

  @override
  String get menuCommentDeleteFailed => 'Could not delete comment';

  @override
  String get menuMustBeLoggedInToComment => 'You must be logged in to comment';

  @override
  String get menuRatingTitle => 'Rating';

  @override
  String menuAverageRating(String rating) {
    return 'Average rating: $rating';
  }

  @override
  String menuRatingCount(int count) {
    return '$count ratings';
  }

  @override
  String get menuTapToRate => 'Tap to rate';

  @override
  String get menuYourRating => 'Your rating';

  @override
  String get menuRatingSaved => 'Rating saved!';

  @override
  String get menuRatingFailed => 'Could not save rating';

  @override
  String get menuMustBeLoggedInToRate => 'You must be logged in to rate';

  @override
  String get favoritesAdd => 'Add to favorites';

  @override
  String get favoritesRemove => 'Remove from favorites';

  @override
  String get shoppingConvertToCollaborative => 'Make collaborative';

  @override
  String get shoppingConvertToPersonal => 'Make personal';

  @override
  String get shoppingConvertToCollaborativeTitle => 'Make collaborative list';

  @override
  String get shoppingConvertToCollaborativeDescription =>
      'Select friends to share this list with. They will be able to add and check off items in real time.';

  @override
  String get shoppingConvertToPersonalTitle => 'Make personal list';

  @override
  String get shoppingConvertToPersonalWarning =>
      'All collaborators will lose access to this list. Items will be kept.';

  @override
  String get shoppingConvertedToCollaborative =>
      'List converted to collaborative';

  @override
  String get shoppingConvertedToPersonal => 'List converted to personal';

  @override
  String get shoppingConvertError => 'Could not convert list';

  @override
  String get shoppingDescriptionLabel => 'Description (optional)';

  @override
  String get menuTemplateSaveAsTemplate => 'Save as template';

  @override
  String get menuTemplateSaveAsTemplateDescription =>
      'Saves the menu\'s category structure as a reusable template';

  @override
  String get menuTemplateName => 'Template name';

  @override
  String get menuTemplateNameHint => 'E.g. Weekday family menu';

  @override
  String get menuTemplateNameRequired => 'Template name required';

  @override
  String get menuTemplateDescription => 'Description (optional)';

  @override
  String get menuTemplateDescriptionHint =>
      'E.g. Perfect for weekdays with kids';

  @override
  String menuTemplateSavedSuccess(String name) {
    return 'Template \"$name\" saved!';
  }

  @override
  String get menuTemplateNoTemplates => 'No templates';

  @override
  String get menuTemplateNoTemplatesDescription =>
      'You have no saved menu templates. Save a menu as a template to reuse the category structure.';

  @override
  String menuTemplateRecipes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
      zero: 'No recipes',
    );
    return '$_temp0';
  }

  @override
  String menuTemplateUsedCount(int count) {
    return 'Used $count times';
  }

  @override
  String get menuTemplateUseTemplate => 'Use template';

  @override
  String get menuTemplateDeleteTitle => 'Delete template';

  @override
  String get menuTemplateDeleteConfirmation =>
      'Are you sure you want to delete this template?';

  @override
  String get menuTemplateDeletedSuccess => 'Template deleted';

  @override
  String get menuTemplateDeleteFailed => 'Could not delete template';

  @override
  String get menuTemplateSavedMenus => 'Saved menus';

  @override
  String get menuTemplateTemplates => 'Templates';

  @override
  String get personalTagApplyRulesToAll => 'Apply rules to all recipes';

  @override
  String get messagingPinned => 'PINNED';

  @override
  String get messagingUnpin => 'Unpin';

  @override
  String get messagingPin => 'Pin';

  @override
  String get messagingArchive => 'Archive';

  @override
  String get messagingUnarchive => 'Unarchive';

  @override
  String messagingArchivedCount(int count) {
    return 'Archived ($count)';
  }

  @override
  String get allergenRetagAllRecipesTitle => 'Retag all recipes';

  @override
  String get allergenAnalyzeAllRecipes =>
      'Analyze all recipes with updated settings';

  @override
  String get allergenUpdateAllRecipes => 'Update all recipes';

  @override
  String get notificationSaveError => 'Could not save settings';

  @override
  String get notificationTitle => 'Notifications';

  @override
  String get notificationEnableTitle => 'Enable notifications';

  @override
  String get notificationEnableSubtitle =>
      'Enable or disable all notifications';

  @override
  String get notificationCategoriesTitle => 'Notification categories';

  @override
  String get notificationQuietHoursTitle => 'Quiet hours';

  @override
  String get notificationQuietHoursEnable => 'Enable quiet hours';

  @override
  String get notificationQuietHoursSubtitle =>
      'No notifications during selected time period';

  @override
  String get commonFrom => 'From';

  @override
  String get commonTo => 'To';

  @override
  String get notificationSound => 'Sound';

  @override
  String get notificationVibration => 'Vibration';

  @override
  String get notificationCategoryFriends => 'Friends';

  @override
  String get notificationCategoryRecipes => 'Recipes';

  @override
  String get notificationCategoryCollaboration => 'Collaboration';

  @override
  String get notificationCategoryShopping => 'Shopping';

  @override
  String get notificationCategorySocial => 'Social activity';

  @override
  String get notificationCategorySystem => 'System';

  @override
  String get notificationCategoryMessaging => 'Messages';

  @override
  String get notificationDigestFrequencyTitle => 'Digest frequency';

  @override
  String get notificationDigestFrequencySubtitle =>
      'How often you want a summary of activity';

  @override
  String get notificationDigestFrequencyNever => 'Never';

  @override
  String get notificationDigestFrequencyWeekly => 'Weekly';

  @override
  String get notificationDigestFrequencyDaily => 'Daily';

  @override
  String get collaborationNoFriends =>
      'You have no friends to collaborate with';

  @override
  String get collaborationEnableTitle => 'Enable collaboration';

  @override
  String get collaborationEnabled => 'Collaboration enabled';

  @override
  String get collaborationCouldNotEnable => 'Could not enable collaboration';

  @override
  String get collaborationDeactivateTitle => 'Deactivate collaboration?';

  @override
  String get collaborationDeactivateMessage =>
      'All collaborators will lose access to the recipe.';

  @override
  String get commonDeactivate => 'Deactivate';

  @override
  String get collaborationDeactivated => 'Collaboration deactivated';

  @override
  String get collaborationCouldNotDeactivate =>
      'Could not deactivate collaboration';

  @override
  String get ratingRemoveTitle => 'Remove rating?';

  @override
  String get ratingRemoveMessage =>
      'Do you want to remove your rating for this recipe?';

  @override
  String get ratingRemoved => 'Rating removed';

  @override
  String get ratingRemoveError => 'Could not remove rating';

  @override
  String get ratingError => 'Could not set rating';

  @override
  String ratingStarLabel(int count) {
    return 'Rate $count stars';
  }

  @override
  String get messagingSending => 'Sending';

  @override
  String get messagingSent => 'Sent';

  @override
  String get messagingDelivered => 'Delivered';

  @override
  String get messagingRead => 'Read';

  @override
  String get messagingFailed => 'Failed';

  @override
  String get a11ySelected => 'selected';

  @override
  String get a11yNotSelected => 'not selected';

  @override
  String get blockedUsersUnblockTitle => 'Unblock user?';

  @override
  String blockedUsersUnblockMessage(String name) {
    return 'Do you want to unblock $name? The user will be able to see your content again.';
  }

  @override
  String get blockedUsersUnblock => 'Unblock';

  @override
  String get blockedUsersTitle => 'Blocked users';

  @override
  String get blockedUsersEmpty => 'No blocked users';

  @override
  String blockedUsersUnblockSelectedCount(int count) {
    return 'Unblock selected ($count)';
  }

  @override
  String get blockedUsersBulkUnblockTitle => 'Unblock selected?';

  @override
  String blockedUsersBulkUnblockMessage(int count) {
    return 'Do you want to unblock $count users?';
  }

  @override
  String blockedUsersBulkUnblockResult(int count) {
    return '$count users unblocked';
  }

  @override
  String blockedUsersBulkUnblockPartial(int succeeded, int total) {
    return '$succeeded of $total unblocked';
  }

  @override
  String a11yBlockedUserSelect(String name) {
    return 'Select blocked user $name';
  }

  @override
  String get retagFetchingRecipes => 'Fetching recipes...';

  @override
  String get retagRetaggingRecipes => 'Retagging recipes';

  @override
  String retagRetaggingProgress(int current, int total) {
    return 'Retagging $current of $total recipes...';
  }

  @override
  String retagRecipesRetagged(int count) {
    return '$count recipes retagged';
  }

  @override
  String get profileNotifications => 'Notifications';

  @override
  String get profileNotificationsSubtitle => 'Categories and quiet hours';

  @override
  String get filterFavorites => 'Favorites';

  @override
  String get filterUnder30Min => 'Under 30 min';

  @override
  String get filterVegetarianQuick => 'Vegetarian';

  @override
  String get filterAll => 'All';

  @override
  String instructionLabel(int number) {
    return 'Instruction $number';
  }

  @override
  String get onboardingSkipConfirmTitle => 'Skip the intro?';

  @override
  String get onboardingSkipConfirmMessage =>
      'You won\'t set up allergies and dietary preferences now. You can do it anytime in settings.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingComplete => 'Finish';

  @override
  String get onboardingAgeGateTitle => 'How old are you?';

  @override
  String get onboardingAgeGateSubtitle =>
      'We need your birth year to follow Swedish rules for social apps (GDPR Art 8).';

  @override
  String get onboardingAgeGateBirthYearLabel => 'Birth year';

  @override
  String get onboardingAgeGateBirthYearHint => 'Choose your birth year';

  @override
  String get onboardingAgeGatePrivacyNote =>
      'We only store the year, not the full date.';

  @override
  String get onboardingAgeGateContinue => 'Continue';

  @override
  String get onboardingAgeGateTooYoungTitle => 'Butlery is for ages 15 and up';

  @override
  String get onboardingAgeGateTooYoungBody =>
      'Swedish data-protection law (GDPR Art 8) requires parental consent for under-15s to use social features. You\'re welcome to come back when you turn 15.';

  @override
  String get onboardingAgeGateSignOut => 'Sign out';

  @override
  String get onboardingAgeGateParentOption => 'A grown-up can sign up for you';

  @override
  String get onboardingAgeGateParentInfoTitle => 'Ask a grown-up for help';

  @override
  String get onboardingAgeGateParentInfoBody =>
      'Ask a parent or guardian to create their own account and add you as a family member. You need to be at least 15 to have your own account.';

  @override
  String get onboardingWelcomeTitle => 'Welcome to Butlery!';

  @override
  String get onboardingWelcomeDescription =>
      'Let us set up your preferences so you get the best experience from the start.';

  @override
  String get onboardingWelcomeNote =>
      'You can always change these in settings later.';

  @override
  String get onboardingAllergenTitle => 'Allergies & intolerances';

  @override
  String get onboardingAllergenDescription =>
      'Choose the allergens you want to track and filter recipes by.';

  @override
  String get onboardingAllergenGluten => 'Gluten';

  @override
  String get onboardingAllergenMilk => 'Milk';

  @override
  String get onboardingAllergenNuts => 'Nuts';

  @override
  String get onboardingAllergenEgg => 'Egg';

  @override
  String get onboardingAllergenSoy => 'Soy';

  @override
  String get onboardingAllergenFish => 'Fish';

  @override
  String get onboardingAllergenShellfish => 'Shellfish';

  @override
  String get onboardingAllergenSesame => 'Sesame';

  @override
  String get onboardingDietaryTitle => 'Dietary preferences';

  @override
  String get onboardingDietaryDescription =>
      'Do you have any dietary preferences? We can filter recipes for you.';

  @override
  String get onboardingDietaryVegetarian => 'Vegetarian';

  @override
  String get onboardingDietaryVegan => 'Vegan';

  @override
  String get onboardingDietaryPescetarian => 'Pescetarian';

  @override
  String get onboardingDietaryVegetarianDesc => 'No meat or fish products';

  @override
  String get onboardingDietaryVeganDesc => 'No animal products';

  @override
  String get onboardingDietaryPescetarianDesc => 'Fish but no meat';

  @override
  String get onboardingDietaryGlutenFree => 'Gluten-free';

  @override
  String get onboardingDietaryLactoseFree => 'Lactose-free';

  @override
  String get onboardingDietaryHalal => 'Halal';

  @override
  String get onboardingDietaryKosher => 'Kosher';

  @override
  String get onboardingDietaryGlutenFreeDesc =>
      'No gluten-containing ingredients';

  @override
  String get onboardingDietaryLactoseFreeDesc =>
      'No dairy products with lactose';

  @override
  String get onboardingDietaryHalalDesc => 'Follows halal food guidelines';

  @override
  String get onboardingDietaryKosherDesc => 'Follows kosher food guidelines';

  @override
  String get onboardingSkippedBanner =>
      'You skipped the introduction. Want to set up allergens and dietary preferences?';

  @override
  String get onboardingSkippedBannerAction => 'Open settings';

  @override
  String get onboardingWelcomeBanner =>
      'Welcome to Butlery! You\'re all set — add your first recipe to get started.';

  @override
  String get onboardingWelcomeBannerAction => 'Add recipe';

  @override
  String get onboardingImportTitle => 'Import your first recipe';

  @override
  String get onboardingImportDescription =>
      'Get started quickly by importing a recipe from the web or a photo.';

  @override
  String get onboardingImportUrlTitle => 'From a web address';

  @override
  String get onboardingImportUrlDescription => 'Paste a link to a recipe';

  @override
  String get onboardingImportPhotoTitle => 'Import from photo';

  @override
  String get onboardingImportPhotoDescription =>
      'Take a photo or choose from gallery';

  @override
  String get onboardingImportSkipNote =>
      'You can skip this step and import later.';

  @override
  String get onboardingResumeTitle => 'Finish your profile';

  @override
  String get onboardingResumeBody => '30 seconds left';

  @override
  String get onboardingResumeCta => 'Continue';

  @override
  String get cookingModePortions => 'Portions';

  @override
  String get feedbackSendLabel => 'Send feedback';

  @override
  String get feedbackCategoryLabel => 'Category';

  @override
  String get feedbackCategoryBug => 'Bug';

  @override
  String get feedbackCategoryFeatureRequest => 'Feature request';

  @override
  String get feedbackCategoryGeneral => 'Other';

  @override
  String get feedbackDescriptionLabel => 'Description';

  @override
  String get feedbackDescriptionHint => 'Describe what you experienced...';

  @override
  String get feedbackEmailLabel => 'Email (optional)';

  @override
  String get feedbackScreenshotLabel => 'Screenshot';

  @override
  String get feedbackRemoveScreenshot => 'Remove screenshot';

  @override
  String get feedbackSendButton => 'Send';

  @override
  String get adminLoginButton => 'Log in';

  @override
  String get adminPasswordLabel => 'Password';

  @override
  String get adminLoginFailed => 'Login failed';

  @override
  String get adminNotAuthorized => 'You do not have access to the admin panel.';

  @override
  String get adminSignOut => 'Log out';

  @override
  String get adminFeedbackInboxTitle => 'Feedback';

  @override
  String get adminFeedbackEmpty => 'No feedback yet';

  @override
  String get adminFeedbackLoadMore => 'Load more';

  @override
  String get adminFeedbackInteractions => 'Interactions';

  @override
  String get adminFeedbackFilterAll => 'All';

  @override
  String get adminFeedbackStatusNew => 'New';

  @override
  String get adminFeedbackStatusTriaged => 'In progress';

  @override
  String get adminFeedbackStatusResolved => 'Resolved';

  @override
  String get adminScreenshotOpen => 'Open screenshot full size';

  @override
  String get adminScreenshotClose => 'Close';

  @override
  String get adminCopyForClaude => 'Copy for Claude';

  @override
  String get adminCopiedForClaude => 'Copied — paste into a new Claude session';

  @override
  String get adminCopyFailed => 'Could not copy to clipboard';

  @override
  String get adminRefresh => 'Refresh';

  @override
  String get adminNavFeedback => 'Feedback';

  @override
  String get adminNavImport => 'Import health';

  @override
  String get adminImportTitle => 'Import health';

  @override
  String get adminImportEmpty => 'No import data yet';

  @override
  String get adminImportColDomain => 'Domain';

  @override
  String get adminImportColSuccess => 'Success';

  @override
  String get adminImportColFailure => 'Failed';

  @override
  String get adminImportColRate => 'Rate';

  @override
  String get adminImportSummaryDomains => 'Domains';

  @override
  String get adminImportSummarySuccess => 'Successful';

  @override
  String get adminImportSummaryFailure => 'Failed';

  @override
  String get adminImportSummaryRate => 'Success rate';

  @override
  String get adminNavEngagement => 'Engagement';

  @override
  String get adminEngagementTitle => 'Engagement';

  @override
  String get adminEngagementUsers => 'Total users';

  @override
  String get adminEngagementActiveToday => 'Active today';

  @override
  String get adminEngagementActive7d => 'Active 7 days';

  @override
  String get adminEngagementActive28d => 'Active 28 days';

  @override
  String get adminEngagementEmpty => 'No activity data yet';

  @override
  String get adminEngagementColDate => 'Date';

  @override
  String get adminEngagementColCooked => 'Cooked';

  @override
  String get adminEngagementColImported => 'Imported';

  @override
  String get adminEngagementColShared => 'Shared';

  @override
  String get adminEngagementColPlanned => 'Planned';

  @override
  String get adminEngagementColShopped => 'Shopped';

  @override
  String get adminNavParsing => 'Parsing details';

  @override
  String get adminParsingTitle => 'Parsing details';

  @override
  String get adminParsingEmpty => 'No corrections yet';

  @override
  String get adminParsingTotal => 'Corrections';

  @override
  String get adminParsingDomains => 'Domains';

  @override
  String get adminParsingTopDomain => 'Most corrected';

  @override
  String get adminParsingHelp =>
      'Shows what the recipe parser most often gets wrong per site — a complement to Import health, which shows which sites fail.';

  @override
  String get adminOpsHelp =>
      'Recent runs of the nightly cleanup jobs. Sparse pre-launch; the analytics jobs don\'t log their runs here yet.';

  @override
  String get adminParsingColDomain => 'Domain';

  @override
  String get adminParsingColCount => 'Corrections';

  @override
  String get adminParsingColIssue => 'Top issue';

  @override
  String get adminParsingIssueTitle => 'Title';

  @override
  String get adminParsingIssuePortions => 'Portions';

  @override
  String get adminParsingIssueTime => 'Time';

  @override
  String get adminParsingIssueIngredients => 'Ingredients';

  @override
  String get adminParsingIssueInstructions => 'Instructions';

  @override
  String get adminNavRecipes => 'Recipes';

  @override
  String get adminRecipesTitle => 'Recipes';

  @override
  String get adminRecipesEmpty => 'No recipes yet';

  @override
  String get adminRecipesTotal => 'Total recipes';

  @override
  String get adminRecipesImported => 'Imported';

  @override
  String get adminRecipesManual => 'Manual/unknown';

  @override
  String get adminRecipesColMethod => 'Import method';

  @override
  String get adminRecipesColCount => 'Count';

  @override
  String get adminRecipesMethodUrl => 'Link (URL)';

  @override
  String get adminRecipesMethodPhoto => 'Photo / OCR';

  @override
  String get adminRecipesMethodText => 'Text paste';

  @override
  String get adminRecipesMethodSocial => 'Social media';

  @override
  String get adminRecipesMethodManual => 'Manual / unknown';

  @override
  String get adminNavOps => 'Ops';

  @override
  String get adminOpsTitle => 'Operations';

  @override
  String get adminOpsEmpty => 'No operations events yet';

  @override
  String get adminOpsLastRun => 'Last run';

  @override
  String get adminOpsEventCount => 'Events';

  @override
  String get adminOpsColType => 'Type';

  @override
  String get adminOpsColTime => 'Time';

  @override
  String get adminOpsColDeleted => 'Deleted';

  @override
  String get adminMetricNoData => 'No data yet';

  @override
  String get adminAnomalyTitle => 'Anomalies detected';

  @override
  String get adminAnomalyHigh => 'unusually high';

  @override
  String get adminAnomalyLow => 'unusually low';

  @override
  String get adminAnomalyMetricRecipes => 'Recipes';

  @override
  String get adminAnomalyMetricImportFailure => 'Import failures';

  @override
  String get adminAnomalyMetricParsing => 'Parsing corrections';

  @override
  String get adminAnomalyMetricOps => 'Ops events';

  @override
  String get adminAnomalyMetricFeedback => 'Feedback';

  @override
  String get adminMetricInfo => 'About this number';

  @override
  String get adminMetricExport => 'Export to Excel';

  @override
  String get adminMetricExportFailed => 'Could not export';

  @override
  String get adminMetricWhat => 'What it is';

  @override
  String get adminMetricHow => 'How it\'s calculated';

  @override
  String get adminMetricWhy => 'Why it matters';

  @override
  String adminDrillImportTitle(String domain) {
    return 'Import attempts: $domain';
  }

  @override
  String get adminDrillEmpty => 'No import attempts logged';

  @override
  String adminDrillTruncated(int count) {
    return 'Showing $count (there may be more)';
  }

  @override
  String get adminDrillSuccess => 'Succeeded';

  @override
  String get adminDrillFailure => 'Failed';

  @override
  String get metricRecipeTotalWhat =>
      'The total number of recipes in the app, across all users.';

  @override
  String get metricRecipeTotalHow =>
      'Counted by scanning every user\'s recipes and summing them (capped at 5,000 pre-launch).';

  @override
  String get metricRecipeTotalWhy =>
      'Shows how much content has actually been built up — a basic app-health number.';

  @override
  String get metricRecipeByMethodWhat =>
      'How recipes entered the app, split by method: link, photo, text paste, social media or manual.';

  @override
  String get metricRecipeByMethodHow =>
      'Each recipe is classified by its source field; recipes without it (older or manually created) count as manual/unknown.';

  @override
  String get metricRecipeByMethodWhy =>
      'Shows which import paths users actually use — guides where improving import is worth it.';

  @override
  String get metricImportDomainsWhat =>
      'Number of recipe sites at least one import has been attempted from.';

  @override
  String get metricImportDomainsHow =>
      'Counts domains in the import stats with at least one success or failure.';

  @override
  String get metricImportDomainsWhy =>
      'Shows the breadth of where users pull recipes from.';

  @override
  String get metricImportSuccessWhat =>
      'Total successful recipe imports, summed across all sites.';

  @override
  String get metricImportSuccessHow =>
      'The sum of every site\'s success counter.';

  @override
  String get metricImportSuccessWhy =>
      'The positive side of import health — how often it actually works.';

  @override
  String get metricImportFailureWhat =>
      'Total failed recipe imports, summed across all sites.';

  @override
  String get metricImportFailureHow =>
      'The sum of every site\'s failure counter.';

  @override
  String get metricImportFailureWhy =>
      'A high number means users hit \'it didn\'t work\' — direct friction.';

  @override
  String get metricImportRateWhat =>
      'The share of import attempts that succeed, overall.';

  @override
  String get metricImportRateHow =>
      'Successes divided by total attempts (successes + failures), as a percent.';

  @override
  String get metricImportRateWhy =>
      'The single most important import-health number; a low value is coloured as a warning.';

  @override
  String get metricImportTableWhat =>
      'Per site: successes, failures and success rate — worst first.';

  @override
  String get metricImportTableHow =>
      'Each row is a domain; the rate is its own successes divided by its total attempts.';

  @override
  String get metricImportTableWhy =>
      'Points out exactly which sites the parser needs to get better at.';

  @override
  String get metricEngagementUsersWhat =>
      'Total number of registered user accounts.';

  @override
  String get metricEngagementUsersHow =>
      'Counts all documents in the users collection.';

  @override
  String get metricEngagementUsersWhy =>
      'A basic growth number — how many exist in total.';

  @override
  String get metricEngagementActiveWhat =>
      'How many users were active in any feature during the window (today, 7 or 28 days).';

  @override
  String get metricEngagementActiveHow =>
      'Taken from the latest day\'s rollup; shows the most active in any single feature (a floor on distinct active users).';

  @override
  String get metricEngagementActiveWhy =>
      'Shows whether people actually use the app, not just sign up.';

  @override
  String get metricEngagementTableWhat =>
      'Per day: how many cooked, imported, shared, planned and shopped.';

  @override
  String get metricEngagementTableHow =>
      'One row per day from the nightly activity rollups.';

  @override
  String get metricEngagementTableWhy =>
      'Shows which features drive engagement over time.';

  @override
  String get substitutionEmptyState => 'No substitutions found';

  @override
  String get pollCreateTitle => 'Create poll';

  @override
  String get pollQuestionLabel => 'Question';

  @override
  String get pollQuestionHint => 'What do you want to ask?';

  @override
  String pollOptionLabel(int number) {
    return 'Option $number';
  }

  @override
  String get pollAddOption => 'Add option';

  @override
  String get pollAllowMultiple => 'Allow multiple choices';

  @override
  String get pollCancel => 'Cancel';

  @override
  String get pollCreate => 'Create poll';

  @override
  String get pollClose => 'Close poll';

  @override
  String get askWhatToEat => 'What should we eat?';

  @override
  String get pickRecipesToVote => 'Pick recipes to vote on';

  @override
  String winnerAddedToMenu(String recipe) {
    return '$recipe added to the weekly menu';
  }

  @override
  String get noRecipesToVote => 'No recipes to vote on';

  @override
  String get importFirstCta => 'Import your first recipe';

  @override
  String get messageTypeText => 'Text message';

  @override
  String get messageTypeRecipeShare => 'Recipe share';

  @override
  String get messageTypeMenuShare => 'Menu share';

  @override
  String get messageTypeShoppingListShare => 'Shopping list share';

  @override
  String get messageTypeSystem => 'System message';

  @override
  String get messageTypeImage => 'Image';

  @override
  String get messageTypeVoice => 'Voice message';

  @override
  String get messageTypePoll => 'Poll';

  @override
  String get messageStatusSending => 'Sending...';

  @override
  String get messageStatusSent => 'Sent';

  @override
  String get messageStatusDelivered => 'Delivered';

  @override
  String get messageStatusRead => 'Read';

  @override
  String get messageStatusFailed => 'Failed';

  @override
  String get errorDnsResolution =>
      'Connection issue detected. Attempting to reconnect...';

  @override
  String get errorServiceUnavailable =>
      'Service temporarily unavailable. Please try again later.';

  @override
  String get errorNoItemsFound => 'No items found.';

  @override
  String get errorNoUserLoggedIn => 'No user is logged in';

  @override
  String get errorReauthRequired =>
      'You must log in again to delete your account';

  @override
  String get errorCouldNotRemoveMfa => 'Could not remove MFA';

  @override
  String get errorEmailAlreadyInUse =>
      'This email address is already in use by another account.';

  @override
  String get errorInvalidEmailAddress => 'Invalid email address.';

  @override
  String get errorUserNotFoundByEmail => 'No user found with this email.';

  @override
  String get errorWrongPassword => 'Wrong password.';

  @override
  String get errorInvalidCredentials =>
      'Wrong email or password. Check your credentials.';

  @override
  String get errorAccountDisabled => 'This account has been disabled.';

  @override
  String get errorTooManyAttempts =>
      'Too many attempts. Wait a moment and try again.';

  @override
  String get errorInvalidVerificationCode =>
      'Invalid verification code. Try again.';

  @override
  String get errorSessionExpired => 'Session expired. Try again.';

  @override
  String get errorTooManySmsAttempts =>
      'Too many SMS attempts. Try again later.';

  @override
  String get errorPhoneNumberMissing => 'Phone number is missing.';

  @override
  String get errorMustBeLoggedIn => 'You must be logged in';

  @override
  String get errorMustBeLoggedInToImport =>
      'You must be logged in to import recipes';

  @override
  String get errorMustBeLoggedInToExport =>
      'You must be logged in to export data';

  @override
  String get errorMustBeLoggedInToManageConsent =>
      'You must be logged in to manage consents';

  @override
  String get errorRecipeNameEmpty => 'Recipe name cannot be empty';

  @override
  String get errorCanOnlyUpdatePersonalRecipes =>
      'Can only update personal recipes';

  @override
  String get errorRecipeNotFound => 'Recipe not found';

  @override
  String get errorNoPermissionToEdit =>
      'You do not have permission to edit this recipe';

  @override
  String get errorNotInRealtimeMode => 'Not in realtime editing mode';

  @override
  String get errorTitleCannotBeEmpty => 'Title cannot be empty';

  @override
  String get errorPortionsMustBePositive => 'Portions must be greater than 0';

  @override
  String get errorTimeMustBePositive => 'Time must be greater than 0 minutes';

  @override
  String get errorRecipeNeedsIngredient =>
      'Recipe must have at least one ingredient';

  @override
  String get errorRecipeNeedsInstruction =>
      'Recipe must have at least one instruction';

  @override
  String get errorNoPermissionToShare =>
      'You do not have permission to share this recipe';

  @override
  String get errorCouldNotSaveRecipe => 'Could not save recipe';

  @override
  String get errorSharedRecipeMayNotBeVisible =>
      'Recipe was shared, but the recipient may not see it. Try again if they can\'t find it.';

  @override
  String errorShareCapReached(int max) {
    return 'Recipe is already shared with the maximum number of users ($max)';
  }

  @override
  String get errorNoGroupMembersFound => 'No group members found';

  @override
  String get errorRecipeNotShared => 'The recipe is not shared';

  @override
  String get errorOnlyOwnerCanUnshare =>
      'Only the owner can stop sharing the recipe';

  @override
  String get errorCouldNotUnshareRecipe => 'Could not stop sharing recipe';

  @override
  String get errorCouldNotLoadTags => 'Could not load tags';

  @override
  String get errorTagUpdateFailed => 'Error updating tags';

  @override
  String get errorCouldNotCreateTag => 'Could not create tag';

  @override
  String get errorCouldNotUpdateTag => 'Could not update tag';

  @override
  String get errorTagNotFound => 'Tag not found';

  @override
  String get errorCouldNotDeleteTag => 'Could not delete tag';

  @override
  String get errorCouldNotCreateGroup => 'Could not create group';

  @override
  String get errorCouldNotUpdateGroup => 'Could not update group';

  @override
  String get errorGroupNotFound => 'Group not found';

  @override
  String get errorCouldNotDeleteGroup => 'Could not delete group';

  @override
  String get errorCouldNotCreateRule => 'Could not create rule';

  @override
  String get errorCouldNotUpdateRule => 'Could not update rule';

  @override
  String get errorCouldNotDeleteRule => 'Could not delete rule';

  @override
  String get errorNoImageToProcess => 'No image to process';

  @override
  String get errorPleaseEnterText => 'Please enter text to parse';

  @override
  String get errorPleaseEnterTextToImport => 'Please enter text to import';

  @override
  String get errorTextTooShort => 'Text is too short to contain a recipe';

  @override
  String get errorPleaseEnterValidUrl => 'Please enter a valid URL';

  @override
  String get errorNoRecipeToValidate => 'No recipe to validate';

  @override
  String get errorNoRecipeToSave => 'No recipe to save';

  @override
  String get importProvideText => 'Please provide text to import';

  @override
  String get importProvideUrl => 'Please provide a valid URL';

  @override
  String get importNoContent => 'No content could be extracted from the URL';

  @override
  String get errorRecipeTitleRequired => 'Recipe title is required';

  @override
  String get errorRecipeMustHaveIngredient =>
      'Recipe must have at least one ingredient';

  @override
  String get errorRecipeMustHaveInstruction =>
      'Recipe must have at least one instruction';

  @override
  String get errorImportConditionsNotMet => 'Import conditions not met';

  @override
  String get errorImportFailed => 'Import failed';

  @override
  String get errorImportPartialReSignIn =>
      'Recipe saved, but share status couldn\'t be updated. Sign in and refresh to clear the inbox entry.';

  @override
  String get errorImportTimeout =>
      'This is taking longer than usual. Try again, or import the text manually.';

  @override
  String get errorNoRecipesSelected => 'No recipes selected';

  @override
  String get errorEnterMenuDescription => 'Enter what kind of menu you want';

  @override
  String get errorNoMoreRecipesForSwap => 'No more recipes available for swap';

  @override
  String get errorNoMenuToSave => 'No menu to save';

  @override
  String get errorEnterMenuName => 'Enter a name for the menu';

  @override
  String get errorMenuNotFound => 'Menu not found';

  @override
  String get errorNoMenuToSaveAsTemplate => 'No menu to save as template';

  @override
  String get errorCouldNotSaveTemplate => 'Could not save template';

  @override
  String get errorNoMenuLoaded => 'No menu loaded';

  @override
  String get errorNoEditPermission => 'No edit permission';

  @override
  String get errorNoInternetConnection => 'No internet connection';

  @override
  String get errorNoRecipesAvailable =>
      'No recipes available. Add recipes first.';

  @override
  String get errorNoMenuToShare => 'No menu to share';

  @override
  String get errorCouldNotAddItem => 'Could not add item';

  @override
  String get errorCouldNotUpdateItem => 'Could not update item';

  @override
  String get errorListNotFound => 'List not found';

  @override
  String get errorCouldNotLoadGroupInfo => 'Could not load group information';

  @override
  String get errorCouldNotAddMembers => 'Could not add members';

  @override
  String get errorCouldNotLeaveGroup => 'Could not leave group';

  @override
  String get errorCouldNotLoadConversation => 'Could not load conversation';

  @override
  String get errorCouldNotLoadMessages => 'Could not load messages';

  @override
  String get errorCouldNotStartConversation => 'Could not start conversation';

  @override
  String get errorMessageCannotBeEmpty => 'Message cannot be empty';

  @override
  String get errorNoFriendsOrGroupsSelected => 'No friends or groups selected';

  @override
  String get errorNoRecipientsFound => 'No recipients found';

  @override
  String get errorFormIncomplete => 'The form is not complete';

  @override
  String get errorMustCreateProfileFirst => 'You must create a profile first';

  @override
  String get errorTitleRequiredNotEmpty =>
      'Title is required and cannot be empty';

  @override
  String get errorDescriptionTooLong => 'Description is too long';

  @override
  String get errorGroupNameRequired => 'Group name is required';

  @override
  String get errorGroupNameExists => 'This group name already exists';

  @override
  String get errorOnlyAdminCanAddMembers => 'Only an admin can add members';

  @override
  String get errorOnlyAdminCanRemoveMembers =>
      'Only an admin can remove members';

  @override
  String get errorUseLeaveGroupToLeave =>
      'Use \"Leave group\" to leave the conversation';

  @override
  String get errorOnlyAdminCanChangeGroupName =>
      'Only an admin can change the group name';

  @override
  String get errorGroupNameCannotBeEmpty => 'Group name cannot be empty';

  @override
  String get errorFillRequiredFields => 'Fill in all required fields';

  @override
  String get errorNoPermissionToSave =>
      'You do not have permission to save this recipe';

  @override
  String get errorNoRecipeToFork => 'No recipe to fork';

  @override
  String get errorCouldNotForkRecipe => 'Could not fork recipe';

  @override
  String get errorNoRecipeToDelete => 'No recipe to delete';

  @override
  String get errorNoPermissionToDelete =>
      'You do not have permission to delete this recipe';

  @override
  String get errorPasswordCannotBeEmpty => 'Password cannot be empty';

  @override
  String get errorPasswordMinSixChars =>
      'Password must be at least 6 characters';

  @override
  String get errorDisplayNameCannotBeEmpty => 'Display name cannot be empty';

  @override
  String get errorDisplayNameMinLength =>
      'Display name must be at least 2 characters';

  @override
  String get errorSomeSharesFailed => 'Some shares failed';

  @override
  String get errorNoFriendsToShareWith => 'You have no friends to share with';

  @override
  String get errorSelectAtLeastOneFriend =>
      'Select at least one friend to share with';

  @override
  String get errorFillRequiredFieldsCorrectly =>
      'Fill in all required fields correctly';

  @override
  String get errorNameAlreadyTaken => 'This name is already taken';

  @override
  String get errorNoPermissionToManageParticipants =>
      'No permission to manage participants';

  @override
  String get errorCannotRemoveSelf => 'Cannot remove yourself as participant';

  @override
  String get errorCannotChangeOwnPermissions =>
      'Cannot change your own permissions';

  @override
  String get errorNoUserIdAvailable => 'No user ID available';

  @override
  String get errorInvitationNotFound => 'Invitation not found';

  @override
  String get errorNoInternetCheckConnection =>
      'No internet connection. Check your connection and try again.';

  @override
  String get errorPermissionDeniedRetry =>
      'Permission denied. Try logging in again.';

  @override
  String get errorExportFailed =>
      'An error occurred while exporting data. Try again.';

  @override
  String errorTagNameExists(String name) {
    return 'A tag with the name \"$name\" already exists';
  }

  @override
  String get errorGroupDoesNotExist => 'Group does not exist';

  @override
  String get errorTagDoesNotExist => 'Tag does not exist';

  @override
  String get errorRuleDoesNotExist => 'Rule does not exist';

  @override
  String get errorSharedTagNotFound => 'Shared tag not found';

  @override
  String get errorOwnerMustKeepPermission => 'Owner must keep owner permission';

  @override
  String get errorCouldNotLoadRecipes => 'Could not load recipes';

  @override
  String get errorCouldNotDeleteRecipe => 'Could not delete recipe';

  @override
  String get errorCouldNotValidateImage => 'Could not validate image';

  @override
  String get actionRecipeSaving => 'saving recipe';

  @override
  String get actionRecipeUploading => 'uploading recipe';

  @override
  String get actionRecipeLoading => 'loading recipe';

  @override
  String get actionRecipeDeleting => 'deleting recipe';

  @override
  String get actionRecipeValidation => 'validating recipe';

  @override
  String get actionRecipeCollaborativeSync => 'syncing shared recipe';

  @override
  String get actionRecipeDraftRestore => 'restoring draft';

  @override
  String get actionRecipeImageUpload => 'uploading images';

  @override
  String get actionRecipeImageProcessing => 'processing images';

  @override
  String get actionRecipeImageDelete => 'deleting image';

  @override
  String get actionShoppingListCreate => 'creating shopping list';

  @override
  String get actionShoppingItemAdd => 'adding item';

  @override
  String get actionShoppingListSync => 'syncing shopping list';

  @override
  String get actionShoppingListShare => 'sharing shopping list';

  @override
  String get actionShoppingListDelete => 'deleting shopping list';

  @override
  String get actionFriendInvite => 'sending friend invitation';

  @override
  String get actionGroupCreate => 'creating group';

  @override
  String get actionMessagesSend => 'sending message';

  @override
  String get actionSocialSync => 'syncing social content';

  @override
  String get actionUserProfileUpdate => 'updating profile';

  @override
  String get actionPermissionRequest => 'requesting permission';

  @override
  String get actionAppStartup => 'starting app';

  @override
  String get actionDataSync => 'syncing data';

  @override
  String get actionBackgroundUpload => 'background upload';

  @override
  String get actionOffline => 'offline operation';

  @override
  String errorNetworkNoConnection(String action) {
    return 'No internet connection while $action. Changes are saved locally and will sync automatically when you\'re back online.';
  }

  @override
  String errorNetworkLimited(String action) {
    return 'Limited internet connection while $action. Some features may be unavailable.';
  }

  @override
  String errorNetworkDegraded(String action) {
    return 'Connection issue while $action. DNS problems detected, checking connection automatically.';
  }

  @override
  String errorNetworkTemporary(String action) {
    return 'Temporary network error while $action. Checking connection and retrying automatically.';
  }

  @override
  String errorNetworkUnknownStatus(String action) {
    return 'Unknown connection status while $action. Check your internet connection and try again.';
  }

  @override
  String errorAuthNoPermissionFor(String action) {
    return 'You don\'t have permission for $action';
  }

  @override
  String errorAuthNotLoggedInWhile(String base) {
    return '$base because you are not logged in.';
  }

  @override
  String errorAuthViewerOnly(String base) {
    return '$base. You only have read access to this content.';
  }

  @override
  String errorAuthEditorRequired(String base) {
    return '$base. Editor permissions are required for this action.';
  }

  @override
  String errorAuthNotShared(String base) {
    return '$base. This content has not been shared with you.';
  }

  @override
  String errorAuthOwnerOnly(String base, String owner) {
    return '$base. Only the owner ($owner) can perform this action.';
  }

  @override
  String errorAuthContactOwner(String base) {
    return '$base. Contact the content owner for extended permissions.';
  }

  @override
  String errorNotFoundRecipe(String action) {
    return 'Recipe could not be found while $action. It may have been deleted or moved by the owner.';
  }

  @override
  String errorNotFoundShoppingList(String action) {
    return 'Shopping list could not be found while $action. It may have been deleted or you no longer have access.';
  }

  @override
  String errorNotFoundImage(String action) {
    return 'Image could not be found while $action. It may have been deleted or moved.';
  }

  @override
  String errorNotFoundGeneric(String action) {
    return 'The requested content could not be found while $action. It may have been deleted or you no longer have access.';
  }

  @override
  String errorServiceMaintenance(String action) {
    return 'Service temporarily unavailable for maintenance while $action. Try again in a few minutes.';
  }

  @override
  String errorServiceSync(String action) {
    return 'Sync service temporarily unavailable while $action. Changes are saved locally and will sync automatically later.';
  }

  @override
  String errorServiceTemporary(String action) {
    return 'Service temporarily unavailable while $action. Try again in a couple of minutes.';
  }

  @override
  String errorDnsConnection(String action) {
    return 'Could not connect to the server while $action. Check your internet connection or try again later.';
  }

  @override
  String errorUnknownWhileAction(String action) {
    return 'An unexpected error occurred while $action. Try again or contact support if the problem persists.';
  }

  @override
  String errorUnknownWithTechnical(String action, String techInfo) {
    return 'An unexpected error occurred while $action. Try again or contact support if the problem persists. (Technical info: $techInfo)';
  }

  @override
  String errorFallbackWhileAction(String action) {
    return 'An error occurred while $action. Try again.';
  }

  @override
  String get suggestionLabel => 'Suggestion:';

  @override
  String get suggestionSavedLocally =>
      'Recipe is saved locally and will sync automatically';

  @override
  String get suggestionCheckLoggedIn => 'Check that you are logged in';

  @override
  String get suggestionRequestPermission =>
      'Request editing permissions from the recipe owner';

  @override
  String get suggestionImageSavedLocally =>
      'Images are saved locally and will upload automatically later';

  @override
  String get suggestionImageSizeLimit => 'Check that images are less than 10MB';

  @override
  String get suggestionImageFormat => 'Use JPG, PNG or HEIC format';

  @override
  String get suggestionSelectAnotherDraft =>
      'Select another draft from the list';

  @override
  String get suggestionCreateNewRecipe => 'Start creating a new recipe instead';

  @override
  String get suggestionUpdateAccountSettings => 'Update your account settings';

  @override
  String get suggestionCheckConnection => 'Check your internet connection';

  @override
  String get suggestionRetryWhenStable =>
      'Try again when the connection is stable';

  @override
  String get suggestionLoginAgain => 'Log in again';

  @override
  String get suggestionRetryInMinutes => 'Try again in a few minutes';

  @override
  String get suggestionRetryOrContactSupport => 'Try again or contact support';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusFirebaseUnavailable => 'Firebase unavailable';

  @override
  String get statusNoInternet => 'No internet connection';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get statusCheckingConnection => 'Checking connection...';

  @override
  String get statusReconnecting => 'Reconnecting...';

  @override
  String get statusDone => 'Done!';

  @override
  String get displayOnlyYou => 'Only you';

  @override
  String get displayUnknownUser => 'Unknown user';

  @override
  String get displayNoConsent => 'No consent';

  @override
  String get resourceTypeRecipe => 'Recipe';

  @override
  String get resourceTypeMenu => 'Menu';

  @override
  String get resourceTypeShoppingList => 'Shopping list';

  @override
  String get permissionOwner => 'Owner';

  @override
  String get permissionAdmin => 'Admin';

  @override
  String get permissionEditor => 'Editor';

  @override
  String get permissionWriter => 'Writer';

  @override
  String get permissionViewer => 'Viewer';

  @override
  String get permissionReader => 'Reader';

  @override
  String get permissionUnknown => 'Unknown permission';

  @override
  String get activityJustNow => 'Just now';

  @override
  String get activityActiveNow => 'Active now';

  @override
  String get activityActiveThisWeek => 'Active this week';

  @override
  String get activityInactive => 'Inactive';

  @override
  String get validationTitleCannotBeEmpty => 'Title cannot be empty';

  @override
  String get validationIngredientRequired =>
      'At least one ingredient is required';

  @override
  String get validationInstructionRequired =>
      'At least one instruction is required';

  @override
  String get validationPortionsMustBePositive => 'Portions must be positive';

  @override
  String get validationTimeMustBePositive => 'Time must be positive';

  @override
  String get validationRatingRange => 'Rating must be between 0 and 5';

  @override
  String validationInvalidIngredientIndex(int index) {
    return 'Invalid ingredient index: $index';
  }

  @override
  String validationInvalidInstructionIndex(int index) {
    return 'Invalid instruction index: $index';
  }

  @override
  String validationInvalidImageIndex(int index) {
    return 'Invalid image index: $index';
  }

  @override
  String get notificationTitleSuccess => 'Success!';

  @override
  String get notificationTitleError => 'Error occurred';

  @override
  String get notificationTitleNewRecipeActivity => 'New recipe activity';

  @override
  String get notificationTitleFriendActivity => 'Friend activity';

  @override
  String get notificationTitleCollaborationActivity => 'Collaboration activity';

  @override
  String get notificationTitleShoppingLists => 'Shopping lists';

  @override
  String get errorWeakPassword =>
      'Password is too weak. Use at least 6 characters.';

  @override
  String get errorLoginFailed => 'Login failed. Please try again.';

  @override
  String get errorCouldNotLogOut => 'Could not log out';

  @override
  String get errorCouldNotDeleteAccount => 'Could not delete account';

  @override
  String get errorCouldNotCompleteMfa => 'Could not complete MFA enrollment';

  @override
  String get errorMfaVerificationFailed => 'MFA verification failed';

  @override
  String get errorInvalidPhoneNumber =>
      'Invalid phone number. Enter with country code.';

  @override
  String get errorCouldNotSaveRecipeCheckConnection =>
      'Could not save recipe. Check your internet connection.';

  @override
  String get errorCouldNotUpdateRecipeCheckConnection =>
      'Could not update recipe. Check your internet connection.';

  @override
  String get errorCouldNotDeleteFromServer =>
      'Could not delete recipe from server';

  @override
  String errorRateLimitExceeded(int seconds) {
    return 'Too many requests. Try again in $seconds seconds.';
  }

  @override
  String get errorCouldNotImportRecipes => 'Could not import recipes';

  @override
  String get errorCouldNotAddRecipe => 'Could not add the recipe.';

  @override
  String get errorCouldNotUpdateRecipe => 'Could not update the recipe.';

  @override
  String get errorCouldNotExportRecipes => 'Could not export recipes';

  @override
  String get errorCouldNotMarkAsCooked => 'Could not mark recipe as cooked';

  @override
  String get errorCouldNotAddIngredient => 'Could not add ingredient';

  @override
  String get errorCouldNotUpdateIngredient => 'Could not update ingredient';

  @override
  String get errorCouldNotRemoveIngredient => 'Could not remove ingredient';

  @override
  String get errorCouldNotAddInstruction => 'Could not add instruction';

  @override
  String get errorCouldNotUpdateInstruction => 'Could not update instruction';

  @override
  String get errorCouldNotRemoveInstruction => 'Could not remove instruction';

  @override
  String get errorCouldNotStartRealtimeEditing =>
      'Could not start realtime editing';

  @override
  String get errorRealtimeSyncFailed => 'Realtime sync failed';

  @override
  String get errorCouldNotApplyRealtimeEdit => 'Could not apply realtime edit';

  @override
  String get errorCouldNotStartSync => 'Could not start synchronization';

  @override
  String errorSyncErrorFor(String syncType) {
    return 'Sync error for $syncType';
  }

  @override
  String get errorCouldNotUpdateNotificationToken =>
      'Could not update notification token';

  @override
  String get errorCouldNotUpdateNotificationSettings =>
      'Could not update notification settings';

  @override
  String get errorCouldNotUpdateAllergenSettings =>
      'Could not update allergen settings';

  @override
  String get errorCouldNotLoadProfile => 'Could not load profile';

  @override
  String get errorCouldNotUpdateRecipes => 'Could not update recipes';

  @override
  String get errorNetworkCheckInternet =>
      'Network error - check your internet connection';

  @override
  String get errorPermissionMissing => 'Permission denied';

  @override
  String get errorTimeout => 'Timeout exceeded';

  @override
  String get errorTechnical => 'Technical error';

  @override
  String get permissionCanViewRecipe => 'Can view recipe';

  @override
  String get permissionCanComment => 'Can write comments';

  @override
  String get permissionCanEditRecipe => 'Can edit recipe';

  @override
  String get permissionCanManageMembers => 'Can manage members';

  @override
  String get permissionOwnerOfRecipe => 'Owner of recipe';

  @override
  String errorGroupNameExistsWithName(String name) {
    return 'A group with the name \"$name\" already exists';
  }

  @override
  String get errorUserNotLoggedIn => 'User not logged in';

  @override
  String get errorResourceNotFound => 'Resource not found';

  @override
  String get errorNoDeletePermission => 'No permission to delete resource';

  @override
  String get errorCannotRemoveResourceOwner =>
      'Cannot remove the owner from the resource';

  @override
  String get validationRecipeTitleCannotBeEmpty =>
      'Recipe title cannot be empty';

  @override
  String get validationCookingTimeCannotBeNegative =>
      'Cooking time cannot be negative';

  @override
  String get validationIngredientCannotBeEmpty => 'Ingredient cannot be empty';

  @override
  String get validationInstructionCannotBeEmpty =>
      'Instruction cannot be empty';

  @override
  String get validationAtLeastOneIngredient =>
      'At least one ingredient is required';

  @override
  String get validationAtLeastOneInstruction =>
      'At least one instruction is required';

  @override
  String get validationImageUrlCannotBeEmpty => 'Image URL cannot be empty';

  @override
  String get validationInvalidImageUrlFormat => 'Invalid image URL format';

  @override
  String get validationMaxImagesReached => 'Maximum 5 images allowed';

  @override
  String get validationRecipeTitleMissing => 'Recipe title is missing';

  @override
  String get validationRecipeNoIngredients => 'Recipe has no ingredients';

  @override
  String get validationRecipeNoInstructions => 'Recipe has no instructions';

  @override
  String get validationRecipeDescriptionEmpty =>
      'Recipe description is missing';

  @override
  String get validationUserIdCannotBeEmpty => 'User ID cannot be empty';

  @override
  String get validationUsernameCannotBeEmpty => 'Username cannot be empty';

  @override
  String validationUserAlreadyParticipant(String name) {
    return 'User is already a participant: $name';
  }

  @override
  String get validationMaxParticipantsReached =>
      'Maximum participant limit reached (50)';

  @override
  String get validationCannotRemoveRecipeOwner =>
      'Cannot remove the recipe owner';

  @override
  String get validationCannotRemoveMenuOwner => 'Cannot remove the menu owner';

  @override
  String validationUserNotParticipant(String id) {
    return 'User is not a participant: $id';
  }

  @override
  String get validationCannotChangeOwnerPermission =>
      'Cannot change owner permission';

  @override
  String get validationCannotAssignOwnerPermission =>
      'Cannot assign owner permission to another user';

  @override
  String get validationRecipeMissingOwner => 'Recipe is missing an owner';

  @override
  String get validationRecipeOwnerMissingName =>
      'Recipe owner is missing a display name';

  @override
  String get validationParticipantEmptyUserId =>
      'Participant has an empty user ID';

  @override
  String get validationTagNameRequired => 'Tag name is required';

  @override
  String get validationTagNameTooLong =>
      'Tag name too long (max 50 characters)';

  @override
  String get validationTagNameNoCommas => 'Tag name cannot contain commas';

  @override
  String get validationTagNameReserved =>
      'This name is reserved for system tags';

  @override
  String get validationGroupNameRequired => 'Group name is required';

  @override
  String get validationGroupNameTooLong =>
      'Group name too long (max 50 characters)';

  @override
  String get validationRuleMustBeLinked => 'Rule must be linked to a tag';

  @override
  String get validationRuleNameRequired => 'Rule name is required';

  @override
  String get validationRuleMustHaveCondition =>
      'Rule must have at least one condition';

  @override
  String get validationAllConditionsMustHaveValue =>
      'All conditions must have a value';

  @override
  String get validationImageDoesNotExist => 'Image does not exist';

  @override
  String get validationCouldNotReadImageSize => 'Could not read image size';

  @override
  String validationImageTooLargeWithSize(int size) {
    return 'Image is too large (max $size MB)';
  }

  @override
  String get validationCouldNotValidateImage => 'Could not validate image';

  @override
  String get difficultyVeryEasy => 'Very easy';

  @override
  String get difficultyEasy => 'Easy';

  @override
  String get difficultyMedium => 'Medium';

  @override
  String get difficultyHard => 'Hard';

  @override
  String get difficultyVeryHard => 'Very hard';

  @override
  String get difficultyUnknown => 'Unknown';

  @override
  String contentSummaryIngredients(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ingredients',
      one: '1 ingredient',
    );
    return '$_temp0';
  }

  @override
  String contentSummarySteps(int count) {
    return '$count steps';
  }

  @override
  String contentSummaryMinutes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String contentSummaryPortions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count servings',
      one: '1 serving',
    );
    return '$_temp0';
  }

  @override
  String get collaborationPrivateRecipe => 'Private recipe';

  @override
  String collaborationCollaborativeEditorsViewers(int editors, int viewers) {
    return 'Collaborative ($editors editors, $viewers viewers)';
  }

  @override
  String collaborationCollaborativeEditors(int editors) {
    return 'Collaborative ($editors editors)';
  }

  @override
  String collaborationSharedViewers(int viewers) {
    return 'Shared ($viewers viewers)';
  }

  @override
  String get collaborationSharedRecipe => 'Shared recipe';

  @override
  String participantOwnerOnly(String name) {
    return 'Owner only: $name';
  }

  @override
  String participantSummary(String owner, int count) {
    return 'Owner: $owner, Participants: $count';
  }

  @override
  String activityMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String activityHoursAgo(int count) {
    return '$count hours ago';
  }

  @override
  String activityDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String activityWeeksAgo(int count) {
    return '$count weeks ago';
  }

  @override
  String resourceCreatedBy(String name) {
    return 'Created by $name';
  }

  @override
  String resourceLastEditedBy(String name, String timeAgo) {
    return 'Last edited by $name $timeAgo';
  }

  @override
  String get syncParsingNotImplemented =>
      'RealtimeShoppingList parsing not implemented yet';

  @override
  String get backupNoRecipesToExport => 'No recipes to export';

  @override
  String get backupPlatformNotSupported => 'Platform not supported';

  @override
  String get backupSavedAndroid => 'Backup saved in Android/data/.../Butlery';

  @override
  String get backupSavedIos => 'Backup saved in the Files app';

  @override
  String get backupCouldNotFindStorageDir => 'Could not find storage directory';

  @override
  String backupCouldNotSaveFile(String error) {
    return 'Could not save file: $error';
  }

  @override
  String get backupCouldNotReadFile => 'Could not read the file';

  @override
  String get backupInvalidFile => 'Invalid backup file - not from Butlery';

  @override
  String get backupUnknownRecipe => 'Unknown recipe';

  @override
  String get warningUrlImportNotARecipe =>
      'This page appears to be a news article. The extracted content may not be a recipe.';

  @override
  String backupImportedFromBackup(String date) {
    return 'Imported from backup $date';
  }

  @override
  String backupExportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String backupImportFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String get syncAlreadyInProgress => 'Sync already in progress';

  @override
  String get syncMustBeOnline => 'You must be online to sync';

  @override
  String get syncNoUserLoggedIn => 'No user logged in';

  @override
  String get syncNoPendingChanges => 'No pending changes';

  @override
  String syncAllSynced(int count) {
    return 'All $count changes synced!';
  }

  @override
  String syncPartialSuccess(int synced, int total, int remaining) {
    return '$synced of $total synced, $remaining remaining';
  }

  @override
  String get syncFailedRetryLater => 'Sync failed, will retry later';

  @override
  String get instagramCouldNotFindRecipe =>
      'Could not find a recipe in the post. Take a screenshot of the recipe.';

  @override
  String get uploadNotificationComplete => 'Upload complete';

  @override
  String get uploadNotificationCompleteBody =>
      'The image has been uploaded successfully';

  @override
  String get uploadNotificationFailed => 'Upload failed';

  @override
  String get uploadNotificationFailedBody =>
      'Could not upload the image after multiple attempts';

  @override
  String uploadStatusWaiting(int pending) {
    return 'Waiting to upload $pending images...';
  }

  @override
  String uploadStatusUploading(int active, int progress, int pending) {
    return 'Uploading $active images ($progress% done, $pending waiting)';
  }

  @override
  String get uploadStatusPreparing => 'Preparing upload...';

  @override
  String uploadStatusRetrying(int attempt, int max) {
    return 'Retrying ($attempt/$max)...';
  }

  @override
  String get uploadStatusComplete => 'Upload complete';

  @override
  String get uploadStatusCancelled => 'Upload cancelled';

  @override
  String get uploadFailureNetwork => 'Network error - check your connection';

  @override
  String get uploadFailureValidation => 'Image could not be validated';

  @override
  String get uploadFailureServer => 'Server error - try again';

  @override
  String get uploadFailureCancelled => 'Upload cancelled';

  @override
  String get uploadFailureQuotaExceeded =>
      'You\'ve hit your photo storage limit. Delete some recipe images to upload more.';

  @override
  String get uploadFailureGeneric => 'Upload failed';

  @override
  String get uploadRetryCheckInternet =>
      'Check your internet connection and tap to retry';

  @override
  String get uploadRetryCheckImage =>
      'Make sure the image is valid and not too large';

  @override
  String get uploadRetryTryLater => 'Try again in a moment';

  @override
  String get uploadRetryTapToRetry => 'Tap to retry';

  @override
  String llmUnexpectedError(String error) {
    return 'An unexpected error occurred: $error';
  }

  @override
  String get llmUnknownRecipe => 'Unknown recipe';

  @override
  String get llmMustBeLoggedIn => 'You must be logged in to use AI features.';

  @override
  String get llmServiceOverloaded =>
      'The AI service is temporarily overloaded. Try again in a moment.';

  @override
  String llmInvalidArgument(String error) {
    return 'Invalid argument: $error';
  }

  @override
  String llmGenericError(String error) {
    return 'An error occurred: $error';
  }

  @override
  String get llmTimeout => 'The request took too long. Please try again.';

  @override
  String get llmTemporarilyUnavailable =>
      'The AI service is temporarily unavailable. Try again in a moment.';

  @override
  String get tiktokCouldNotFetchDescription =>
      'Could not fetch the video description. Take a screenshot of the recipe.';

  @override
  String get tiktokAiQuotaExhausted =>
      'AI quota exhausted. Mark recipe parts manually.';

  @override
  String get tiktokCouldNotExtractRecipe =>
      'Could not extract the recipe automatically. Mark recipe parts manually.';

  @override
  String get tiktokNoRecipeInDescription =>
      'The video description does not contain a recipe. Take a screenshot of the recipe.';

  @override
  String rateLimitTooFast(int seconds) {
    return 'You are importing too fast. Wait $seconds seconds.';
  }

  @override
  String rateLimitHourly(int minutes) {
    return 'You have reached the hourly limit. Try again in $minutes minutes.';
  }

  @override
  String get rateLimitDaily =>
      'You have reached the daily import limit. Try again tomorrow.';

  @override
  String get rateLimitAiDaily =>
      'The AI quota for today is exhausted. Try again tomorrow.';

  @override
  String get rateLimitAiMonthly => 'The AI quota for the month is exhausted.';

  @override
  String get rateLimitBudgetDaily =>
      'Today\'s AI budget has been used up. Try again tomorrow.';

  @override
  String get rateLimitBudgetMonthly =>
      'This month\'s AI budget has been used up.';

  @override
  String get importErrorUnexpected => 'An unexpected error occurred';

  @override
  String get importErrorNoInternet => 'No internet connection';

  @override
  String get importErrorTooManyImports =>
      'Too many imports in a short time. Wait a moment.';

  @override
  String get importErrorAiQuotaExhausted => 'AI quota exhausted for today';

  @override
  String get importErrorInvalidUrl => 'Invalid URL';

  @override
  String get importErrorCouldNotReachPage => 'Could not reach the page';

  @override
  String get importErrorLoginRequired => 'The page requires login';

  @override
  String get importErrorNoRecipeFound => 'No recipe found';

  @override
  String get importErrorCouldNotReadImage =>
      'Could not read the text in the image';

  @override
  String get importErrorCouldNotParseRecipe => 'Could not parse the recipe';

  @override
  String get importErrorCouldNotSaveRecipe => 'Could not save the recipe';

  @override
  String get importErrorCancelled => 'Import was cancelled';

  @override
  String get messagingPoll => 'Poll';

  @override
  String get shoppingListEmpty => 'Empty shopping list';

  @override
  String get shoppingListEmptyHint => 'Add items to get started.';

  @override
  String shoppingListAllBought(int count) {
    return 'All $count items bought';
  }

  @override
  String shoppingListItemsRemaining(int remaining, int total) {
    return '$remaining of $total items remaining';
  }

  @override
  String get shoppingListNoActivity => 'No activity';

  @override
  String get shoppingListActivityNow => 'now';

  @override
  String shoppingListActivityMinAgo(int count) {
    return '$count min ago';
  }

  @override
  String shoppingListActivityHoursAgo(int count) {
    return '$count hours ago';
  }

  @override
  String shoppingListActivityDaysAgo(int count) {
    return '$count days ago';
  }

  @override
  String shoppingListLastActivityBy(String name, String time) {
    return 'Last activity by $name $time';
  }

  @override
  String unknownResourceType(String value) {
    return 'Unknown RealtimeResourceType: $value';
  }

  @override
  String get notificationTitleDailySummary => 'Daily summary';

  @override
  String get notificationBodyNoActivityToday => 'No new activity today';

  @override
  String get notificationBodyNoActivityToReport => 'No activity to report';

  @override
  String get notificationBodyProblemLoadingActivities =>
      'Problem loading activities';

  @override
  String get notificationBodyCouldNotCreateSummary =>
      'Could not create summary';

  @override
  String get notificationActionViewRecipes => 'View recipes';

  @override
  String get notificationActionViewFriends => 'View friends';

  @override
  String get notificationActionOpenApp => 'Open app';

  @override
  String get notificationDefaultTitle => 'New activity';

  @override
  String get notificationDefaultBody => 'You have new activity in Butlery';

  @override
  String get recipeShareRequestNotifTitle => 'Recipe request';

  @override
  String recipeShareRequestNotifBody(String name, String title) {
    return '$name wants to see your recipe \"$title\"';
  }

  @override
  String recipeShareRequestBanner(String name) {
    return '$name wants to see this recipe';
  }

  @override
  String recipeShareRequestShareAction(String name) {
    return 'Share with $name';
  }

  @override
  String recipeShareRequestShared(String name) {
    return 'Shared with $name';
  }

  @override
  String notificationDigestRecipes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return '$_temp0';
  }

  @override
  String notificationDigestFriendActivities(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friend activities',
      one: '1 friend activity',
    );
    return '$_temp0';
  }

  @override
  String notificationDigestShoppingLists(int count) {
    return '$count shopping lists';
  }

  @override
  String notificationDigestCollaborations(int count) {
    return '$count collaborations';
  }

  @override
  String get conditionTypeIngredient => 'Ingredient';

  @override
  String get conditionTypeProperty => 'Property';

  @override
  String get conditionTypeKeyword => 'Keyword';

  @override
  String get conditionTypeSource => 'Source';

  @override
  String get conditionTypeCuisine => 'Cuisine';

  @override
  String get conditionTypeDiet => 'Diet';

  @override
  String get conditionTypeTime => 'Time';

  @override
  String get conditionTypeRating => 'Rating';

  @override
  String get conditionTypeRecent => 'Recent';

  @override
  String get conditionTypeCookedRecency => 'Last cooked';

  @override
  String get conditionTypeOwnership => 'Ownership';

  @override
  String get conditionTypeHasImage => 'Has image';

  @override
  String get conditionTypeCompleteness => 'Completeness';

  @override
  String get operatorContains => 'contains';

  @override
  String get operatorExact => 'is exactly';

  @override
  String get operatorStartsWith => 'starts with';

  @override
  String get operatorNotContains => 'does not contain';

  @override
  String get operatorNotExact => 'is not';

  @override
  String get operatorHas => 'has';

  @override
  String get operatorNotHas => 'does not have';

  @override
  String get operatorLessThan => 'less than';

  @override
  String get operatorAtMost => 'at most';

  @override
  String get operatorGreaterThan => 'more than';

  @override
  String get operatorAtLeast => 'at least';

  @override
  String get operatorWithinDays => 'within days';

  @override
  String get errorAuthenticationPleaseLogin =>
      'Authentication error. Please log in again.';

  @override
  String get errorCouldNotShareRecipeWithGroups =>
      'Could not share recipe with groups';

  @override
  String get shoppingListNotFound => 'List not found';

  @override
  String get shoppingRemainingToBuy => 'Remaining to buy:';

  @override
  String get shoppingAlreadyBought => 'Already bought:';

  @override
  String get shoppingCreatedLabel => 'Created:';

  @override
  String get shoppingUpdatedLabel => 'Updated:';

  @override
  String shoppingPurchaseForRecipe(String recipeName) {
    return 'Shopping for $recipeName';
  }

  @override
  String get shoppingCategoryImported => 'Imported';

  @override
  String get shoppingCategoryRecipe => 'Recipe';

  @override
  String get labelChat => 'Chat';

  @override
  String labelParticipantCount(int count) {
    return '$count participants';
  }

  @override
  String errorCouldNotSend(String itemType) {
    return 'Could not send $itemType';
  }

  @override
  String errorCouldNotShare(String itemType) {
    return 'Could not share $itemType';
  }

  @override
  String notificationBatchBodyRecipes(int count) {
    return '$count new events on your recipes';
  }

  @override
  String notificationBatchBodyFriends(int count) {
    return '$count new activities from your friends';
  }

  @override
  String notificationBatchBodyShopping(int count) {
    return '$count updates to your shopping lists';
  }

  @override
  String notificationBatchBodyCollaboration(int count) {
    return '$count new collaboration activities';
  }

  @override
  String notificationBatchBodyDefault(int count) {
    return '$count new events in Butlery';
  }

  @override
  String notificationDigestBody(int totalCount, String summary) {
    return 'You have $totalCount new activities: $summary';
  }

  @override
  String uploadStatusUploadingNoPending(int active, int progress) {
    return 'Uploading $active images ($progress% done)';
  }

  @override
  String uploadStatusPartialFailure(int completed, int total, int failed) {
    return '$completed of $total images uploaded, $failed failed';
  }

  @override
  String uploadStatusAllFailed(int failed, int total) {
    return '$failed of $total images failed - tap to retry';
  }

  @override
  String uploadStatusAllSuccess(int total) {
    return 'All $total images uploaded successfully';
  }

  @override
  String uploadStatusAllCancelled(int cancelled) {
    return 'All $cancelled uploads cancelled';
  }

  @override
  String uploadProgressWithTime(int progress, String time) {
    return '$progress% done - $time remaining';
  }

  @override
  String uploadProgressPercent(int progress) {
    return '$progress% done';
  }

  @override
  String get uploadComplete => 'Upload complete';

  @override
  String uploadAllSuccessWithTime(String time) {
    return 'All images uploaded$time (100% success)';
  }

  @override
  String uploadCompletionOf(int completed, int total) {
    return '$completed of $total completed';
  }

  @override
  String uploadFailureCount(int failed) {
    return ', $failed failed';
  }

  @override
  String uploadSuccessRate(int rate) {
    return ' ($rate% success)';
  }

  @override
  String get uploadPreparing => 'Preparing upload...';

  @override
  String get errorNoImageSelected => 'No image selected';

  @override
  String get errorImageFormatUnsupported =>
      'Image format not supported. Use JPEG or PNG format.';

  @override
  String errorImageTooLarge(String size) {
    return 'Image is too large ($size MB). Use a smaller image or compress it.';
  }

  @override
  String errorImageQualityTooLow(int quality) {
    return 'Image quality is too low for text recognition ($quality%).';
  }

  @override
  String get errorOcrServicesUnavailable =>
      'Text recognition is temporarily unavailable. Try again in a few minutes.';

  @override
  String get errorOcrRateLimit =>
      'Too many requests right now. Please wait a minute and try again.';

  @override
  String get errorOcrTimeout =>
      'Couldn\'t reach the recipe parser. Check your connection and try again.';

  @override
  String get errorNoTextExtracted =>
      'No text could be extracted from the image.';

  @override
  String get labelImprovementSuggestions => 'Improvement suggestions:';

  @override
  String get ocrQualityTips =>
      'Tips for better results:\n• Make sure the image is well-lit and sharp\n• Avoid shadows and reflections\n• Hold the camera straight at the text';

  @override
  String get ocrRetryOrManual =>
      'You can try again with a new image or continue with manual input.';

  @override
  String get errorAiEnhancementFailed => 'AI enhancement failed.';

  @override
  String errorCouldNotCreateRealtimeRecipe(String error) {
    return 'Could not create realtime recipe: $error';
  }

  @override
  String errorCouldNotWatchRecipe(String error) {
    return 'Could not start watching recipe: $error';
  }

  @override
  String errorCouldNotPerformOperation(String operation, String error) {
    return 'Could not $operation: $error';
  }

  @override
  String errorCouldNotDeleteRealtimeRecipe(String error) {
    return 'Could not delete realtime recipe: $error';
  }

  @override
  String errorCouldNotCreateRealtimeMenu(String error) {
    return 'Could not create realtime menu: $error';
  }

  @override
  String errorCouldNotWatchMenu(String error) {
    return 'Could not start watching menu: $error';
  }

  @override
  String errorCouldNotDeleteRealtimeMenu(String error) {
    return 'Could not delete realtime menu: $error';
  }

  @override
  String get ocrImageTooLarge => 'Image is too large';

  @override
  String get ocrCompressImage => 'Compress the image';

  @override
  String get ocrImageTooSmall => 'Image is too small';

  @override
  String get ocrUseHigherResolution => 'Use higher resolution';

  @override
  String get ocrImageFormatNotOptimal => 'Image format not optimally supported';

  @override
  String get ocrUseJpegOrPng => 'Use JPEG or PNG';

  @override
  String get ocrImageResolutionTooLow => 'Image resolution is too low';

  @override
  String get ocrImageRejected =>
      'Image is too blurry or too small — try again in better lighting.';

  @override
  String get syncErrorParsingResource => 'Error parsing resource';

  @override
  String syncErrorWatchingResource(String resourceId) {
    return 'Error watching resource $resourceId';
  }

  @override
  String get notificationActionAccept => 'Accept';

  @override
  String get notificationActionDecline => 'Decline';

  @override
  String get notificationActionViewRecipe => 'View recipe';

  @override
  String get notificationActionJoin => 'Join';

  @override
  String get fcmChannelSocialTitle => 'Social notifications';

  @override
  String get fcmChannelSocialDescription =>
      'Friend requests, shares, and comments';

  @override
  String get fcmChannelMessagingTitle => 'Messages';

  @override
  String get fcmChannelMessagingDescription => 'Chat messages from friends';

  @override
  String get tagValidationEmpty => 'Tag name cannot be empty';

  @override
  String get tagValidationTooShort => 'Tag name must be at least 2 characters';

  @override
  String get tagValidationTooLong => 'Tag name can be max 50 characters';

  @override
  String get tagValidationReserved => 'This name is reserved for system tags';

  @override
  String menuAttributionText(String displayName) {
    return 'Inspired by menu from $displayName';
  }

  @override
  String get llmEnhancementNotEnoughData =>
      'Not enough data for AI enhancement.';

  @override
  String get realtimeIngredientEmptyError => 'Ingredient cannot be empty';

  @override
  String get realtimeIngredientInvalidIndex => 'Invalid ingredient index';

  @override
  String get realtimeInstructionEmptyError => 'Instruction cannot be empty';

  @override
  String get realtimeInstructionInvalidIndex => 'Invalid instruction index';

  @override
  String menuDefaultTitle(String displayName) {
    return 'Menu from $displayName';
  }

  @override
  String get menuShareGroupFallback => 'Group';

  @override
  String menuShareGroupTitle(String categoryName) {
    return 'Menu for $categoryName';
  }

  @override
  String get menuTitleEmpty => 'Empty menu';

  @override
  String menuTitleSingleCategory(String category, int count) {
    return '$category menu ($count recipes)';
  }

  @override
  String menuTitleMultiCategory(String categories, int count) {
    return 'Weekly menu with $categories ($count recipes)';
  }

  @override
  String recipeAttributionText(String displayName) {
    return 'Inspired by recipe from $displayName';
  }

  @override
  String get tiktokOriginalText => 'Original text from TikTok:';

  @override
  String get tiktokIdentifiedIngredients => 'Identified ingredients:';

  @override
  String groupShareWarningManyGroups(int count) {
    return 'Sharing to many groups ($count) may take a while';
  }

  @override
  String groupShareWarningManyItems(int count) {
    return 'Sharing a lot of content ($count items) may take a while';
  }

  @override
  String groupShareWarningLargeOperation(int count) {
    return 'Large operation ($count shares) - consider splitting it up';
  }

  @override
  String get textImportSourceUrl => 'Imported from text';

  @override
  String get assistedImportSelectInstructionsError =>
      'Select at least one instruction';

  @override
  String get assistedImportEnterRecipeName => 'Enter a recipe name';

  @override
  String get assistedImportAddIngredientError => 'Add at least one ingredient';

  @override
  String get assistedImportAddInstructionError =>
      'Add at least one instruction';

  @override
  String get formValidationIngredientRequired => 'Ingredient required';

  @override
  String get formValidationIngredientTooLong =>
      'Ingredient too long (max 200 characters)';

  @override
  String get formValidationInstructionRequired => 'Instruction required';

  @override
  String get formValidationInstructionTooLong =>
      'Instruction too long (max 500 characters)';

  @override
  String get formValidationTagTooLong => 'Tag too long (max 50 characters)';

  @override
  String get formValidationTagNoCommas => 'Tags cannot contain commas';

  @override
  String get shoppingItemMarkedComplete => 'Marked as complete';

  @override
  String get shoppingItemMarkedIncomplete => 'Marked as incomplete';

  @override
  String get menuSuggestionVegetarian => 'Vegetarian weekly menu for 2 people';

  @override
  String get menuSuggestionQuickDinners => 'Quick dinners for the whole week';

  @override
  String get menuSuggestionMeatFish => 'Varied meat and fish menu';

  @override
  String get menuSuggestionFamily => 'Family-friendly weekly menu';

  @override
  String get menuSuggestionHealthy => 'Healthy and nutritious menu';

  @override
  String get menuSuggestionBudget => 'Budget-friendly weekly menu';

  @override
  String get menuSuggestionItalian => 'Italian theme menu';

  @override
  String get menuSuggestionAsian => 'Asian-inspired weekly menu';

  @override
  String recipeAutoTitleWithIngredient(String ingredient) {
    return 'Recipe with $ingredient';
  }

  @override
  String get recipeAutoTitleUntitled => 'Untitled recipe';

  @override
  String get importPhaseFetching => 'Fetching content...';

  @override
  String get importPhaseAnalyzing => 'Analyzing recipe...';

  @override
  String get importPhaseCreating => 'Creating recipe...';

  @override
  String get importPhaseComplete => 'Done!';

  @override
  String get importPhaseNeedsHelp => 'Needs your help';

  @override
  String get importPhaseError => 'An error occurred';

  @override
  String importElapsedSeconds(int seconds) {
    return '${seconds}s';
  }

  @override
  String shoppingSharingSummary(String friendNames) {
    return 'Share with: $friendNames';
  }

  @override
  String imageUploadTooLarge(String maxSize) {
    return 'Image is too large (max ${maxSize}MB)';
  }

  @override
  String shareMessageRecipeWithTitle(String title) {
    return 'Check out this recipe: \"$title\"! 👩‍🍳';
  }

  @override
  String get shareMessageRecipeDefault =>
      'I found an amazing recipe I wanted to share with you! 👩‍🍳';

  @override
  String shareMessageMenuWithTitle(String title) {
    return 'Here\'s my weekly menu: \"$title\" 📋';
  }

  @override
  String get shareMessageMenuDefault =>
      'Here\'s my weekly menu that might inspire you! 📋';

  @override
  String shareMessageShoppingListWithTitle(String title) {
    return 'Want to help me with the shopping list: \"$title\"? 🛒';
  }

  @override
  String get shareMessageShoppingListDefault =>
      'Want to help me with shopping this week? 🛒';

  @override
  String get textImportSuggestionIngredients =>
      'Include ingredient list for better interpretation';

  @override
  String get textImportSuggestionInstructions =>
      'Include cooking instructions or steps';

  @override
  String get textImportSuggestionTime => 'Include cooking time if available';

  @override
  String get textImportSuggestionPortions =>
      'Include number of portions if known';

  @override
  String get textImportSuggestionLooksGood =>
      'Text looks good for recipe interpretation';

  @override
  String get recipeFormPermissionsError => 'Error loading permissions';

  @override
  String createSharedListError(String error) {
    return 'Error creating shared list: $error';
  }

  @override
  String get userStatusOnline => 'Online';

  @override
  String get userStatusJustActive => 'Active just now';

  @override
  String userStatusActiveMinutesAgo(int minutes) {
    return 'Active $minutes min ago';
  }

  @override
  String userStatusActiveHoursAgo(int hours) {
    return 'Active $hours hours ago';
  }

  @override
  String userStatusActiveDaysAgo(int days) {
    return 'Active $days days ago';
  }

  @override
  String userStatusActiveWeeksAgo(int weeks) {
    return 'Active $weeks weeks ago';
  }

  @override
  String recipeCookTimeMinutes(int minutes) {
    return '$minutes minutes';
  }

  @override
  String get recipeLastCookedToday => 'Cooked today';

  @override
  String get recipeLastCookedYesterday => 'Cooked yesterday';

  @override
  String recipeLastCookedDaysAgo(int days) {
    return 'Cooked $days days ago';
  }

  @override
  String messageSharedRecipe(String title) {
    return 'Shared a recipe: $title';
  }

  @override
  String messageSharedMenu(String title) {
    return 'Shared a menu: $title';
  }

  @override
  String messageSharedShoppingList(String title) {
    return 'Shared a shopping list: $title';
  }

  @override
  String get conversationNoMessagesYet => 'No messages yet';

  @override
  String sharedRecipeAttributionText(String displayName) {
    return 'Inspired by recipe from $displayName';
  }

  @override
  String realtimeRecipeCopyTitle(String title) {
    return 'Copy of $title';
  }

  @override
  String realtimeRecipeSharedFrom(String displayName) {
    return 'Shared from $displayName';
  }

  @override
  String get friendCategoryDefaultFriends => 'Friends';

  @override
  String get friendCategoryDefaultFriendsDesc => 'Close friends';

  @override
  String get friendCategoryDefaultNeighbors => 'Neighbors';

  @override
  String get friendCategoryDefaultNeighborsDesc => 'Neighbors and local area';

  @override
  String get friendCategoryDefaultWork => 'Work';

  @override
  String get friendCategoryDefaultWorkDesc => 'Colleagues and coworkers';

  @override
  String get friendCategoryDefaultFoodGroup => 'Food group';

  @override
  String get friendCategoryDefaultFoodGroupDesc => 'People who love cooking';

  @override
  String get friendCategoryDefaultFamily => 'Family';

  @override
  String get friendCategoryDefaultFamilyDesc => 'Family members';

  @override
  String get friendSummaryNoFriends => 'No friends';

  @override
  String get friendSummaryOneFriend => '1 friend';

  @override
  String friendSummaryCount(int count) {
    return '$count friends';
  }

  @override
  String shoppingListSharedBy(String displayName) {
    return 'Shared by $displayName';
  }

  @override
  String shoppingListOriginallySharedBy(String displayName) {
    return 'Originally shared by $displayName';
  }

  @override
  String get collaborationNotAllowed => 'No collaboration allowed';

  @override
  String get collaborationReady => 'Ready for collaboration';

  @override
  String get collaborationVersionCreated => 'Collaborative version created';

  @override
  String get collaborationOneActive => '1 active collaborator';

  @override
  String collaborationMultipleActive(int count) {
    return '$count active collaborators';
  }

  @override
  String recipeCopiedFrom(String title) {
    return 'Copied from: $title';
  }

  @override
  String get statusEmptyList => 'Empty list';

  @override
  String get statusCompleted => 'Done';

  @override
  String get statusInProgress => 'In progress';

  @override
  String get statusNoActivity => 'No activity';

  @override
  String get statusPurchased => 'Purchased';

  @override
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '${minutes}m ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '${hours}h ago';
  }

  @override
  String timeMinutesAgoLong(int minutes) {
    return '$minutes min ago';
  }

  @override
  String timeHoursAgoLong(int hours) {
    return '$hours hrs ago';
  }

  @override
  String timeDaysAgoLong(int days) {
    return '$days days ago';
  }

  @override
  String timeWeeksAgo(int weeks) {
    return '$weeks weeks ago';
  }

  @override
  String get timeNow => 'Now';

  @override
  String get dateTomorrow => 'Tomorrow';

  @override
  String get dateNoDate => 'No date';

  @override
  String dateDaysAhead(int days) {
    return '$days days ahead';
  }

  @override
  String labelMemberCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
  }

  @override
  String get labelParticipantFallback => 'Participant';

  @override
  String get labelRecipes => 'Recipes';

  @override
  String get labelMenus => 'Menus';

  @override
  String get labelShopping => 'Shopping';

  @override
  String get labelCollaborativeMenu => 'Collaborative menu';

  @override
  String get errorInvalidUrlFormat => 'Invalid URL format';

  @override
  String get errorUrlMissingScheme => 'URL must include http:// or https://';

  @override
  String get errorUrlUnsupportedScheme =>
      'Only HTTP and HTTPS URLs are supported';

  @override
  String get errorUrlMissingDomain => 'URL must include a domain name';

  @override
  String get errorUrlPrivateAddress =>
      'The URL points to a private or reserved address and cannot be used';

  @override
  String errorInvalidCategoryName(String name) {
    return 'Invalid category name: $name';
  }

  @override
  String get platformYouTube => 'YouTube video';

  @override
  String get platformTikTok => 'TikTok video';

  @override
  String get platformInstagram => 'Instagram post';

  @override
  String get platformWebsite => 'Website';

  @override
  String get platformPastedText => 'Pasted text';

  @override
  String get selectionNoFriendsSelected => 'No friends selected';

  @override
  String selectionFriendsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends selected',
      one: '1 friend selected',
    );
    return '$_temp0';
  }

  @override
  String get selectionNoRecipesSelected => 'No recipes selected';

  @override
  String selectionRecipesSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes selected',
      one: '1 recipe selected',
    );
    return '$_temp0';
  }

  @override
  String get buttonCreating => 'Creating...';

  @override
  String get buttonCreateAndShare => 'Create & Share';

  @override
  String get analysisNoContentExtracted => 'No content extracted';

  @override
  String get analysisContainsIngredients => 'Contains ingredients';

  @override
  String get analysisNoIngredientsFound => 'No ingredients section found';

  @override
  String get analysisContainsInstructions => 'Contains instructions';

  @override
  String get analysisNoInstructionsFound => 'No instructions found';

  @override
  String get labelNoCategories => 'No categories';

  @override
  String labelAndNMore(int count) {
    return 'and $count more';
  }

  @override
  String get labelGroup => 'Group';

  @override
  String get labelYou => 'You';

  @override
  String get validationSelectIngredient => 'Select at least one ingredient';

  @override
  String get statusListLoaded => 'List loaded';

  @override
  String errorCouldNotLoadListDetail(String detail) {
    return 'Could not load list: $detail';
  }

  @override
  String get labelUntitledMenu => 'Untitled menu';

  @override
  String get labelUntitledList => 'Untitled list';

  @override
  String get labelUntitledRecipe => 'Untitled recipe';

  @override
  String get labelUnknownContent => 'Unknown content';

  @override
  String get analysisContainsTimeInfo => 'Contains time information';

  @override
  String get analysisContainsPortionInfo => 'Contains portion information';

  @override
  String get analysisGoodContentLength => 'Good content length';

  @override
  String get analysisContentTooShort => 'Content seems too short';

  @override
  String get analysisContainsRecipeKeywords => 'Contains recipe keywords';

  @override
  String get hintPasteOrTypeRecipe =>
      'Paste or type recipe text to get started';

  @override
  String get errorFriendAlreadyHasAccess =>
      'The selected friend already has access to the list';

  @override
  String get errorAllFriendsAlreadyHaveAccess =>
      'All selected friends already have access to the list';

  @override
  String shareInvitationsSentWithSkipped(int invitedCount, int skippedCount) {
    return '$invitedCount invitations sent. $skippedCount friends skipped (already have access).';
  }

  @override
  String get errorCouldNotSendInvitations => 'Could not send invitations';

  @override
  String get shareDefaultShoppingListMessage =>
      'Want to share this shopping list with you!';

  @override
  String shoppingListAllDone(int count) {
    return 'All $count items done';
  }

  @override
  String shoppingListItemsToBuy(int count) {
    return '$count items to buy';
  }

  @override
  String get errorDailyQuotaReached => 'Daily quota reached';

  @override
  String get errorGenericOccurred => 'An error occurred';

  @override
  String get fcmChannelGeneralTitle => 'General notifications';

  @override
  String get fcmChannelGeneralDescription =>
      'General notifications from Butlery';

  @override
  String get timeAgoNow => 'Now';

  @override
  String timeAgoMinutesAbbr(int count) {
    return '$count min ago';
  }

  @override
  String timeAgoHoursAbbr(int count) {
    return '${count}h ago';
  }

  @override
  String timeAgoDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days ago',
      one: '1 day ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoWeeks(int count) {
    return '$count weeks ago';
  }

  @override
  String get timeAgoJustNow => 'Just now';

  @override
  String timeAgoMinutesFull(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes ago',
      one: '1 minute ago',
    );
    return '$_temp0';
  }

  @override
  String timeAgoHoursFull(int count) {
    return '$count hours ago';
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
  String get expiresExpired => 'Expired';

  @override
  String expiresDaysRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
    );
    return '$_temp0';
  }

  @override
  String expiresHoursRemaining(int count) {
    return '$count hours left';
  }

  @override
  String expiresMinutesRemaining(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count minutes left',
      one: '1 minute left',
    );
    return '$_temp0';
  }

  @override
  String get expiresSoon => 'Expires soon';

  @override
  String groupInvitationNotificationWithMessage(
    String sender,
    String emoji,
    String group,
    String message,
  ) {
    return '$sender invited you to group $emoji $group: \"$message\"';
  }

  @override
  String groupInvitationNotificationSimple(
    String sender,
    String emoji,
    String group,
  ) {
    return '$sender invited you to group $emoji $group';
  }

  @override
  String get invitationStatusPending => 'Pending';

  @override
  String get invitationStatusAccepted => 'Accepted';

  @override
  String get invitationStatusRejected => 'Rejected';

  @override
  String get invitationStatusCancelled => 'Cancelled';

  @override
  String get invitationStatusExpired => 'Expired';

  @override
  String get messageContentRecipe => 'Recipe';

  @override
  String get messageContentMenu => 'Menu';

  @override
  String get messageContentShoppingList => 'Shopping list';

  @override
  String get messageContentImage => 'Image';

  @override
  String get messageContentVoice => 'Voice message';

  @override
  String get conversationGroupChat => 'Group chat';

  @override
  String get editModeOwner => 'You own this recipe';

  @override
  String get editModeCollaborative => 'You are editing together with others';

  @override
  String get editModeReadOnlyWithFork =>
      'Read-only - you can save your own copy';

  @override
  String get editModeNoAccess => 'No access';

  @override
  String get editModeEdit => 'Edit mode';

  @override
  String get editModeView => 'View mode';

  @override
  String get changeTypeAdded => 'Added';

  @override
  String get changeTypeModified => 'Modified';

  @override
  String get changeTypeRemoved => 'Removed';

  @override
  String memberSinceDays(int count) {
    return 'Member for $count days';
  }

  @override
  String memberSinceMonths(int count) {
    return 'Member for $count months';
  }

  @override
  String memberSinceYears(int count) {
    return 'Member for $count years';
  }

  @override
  String get commentDeleted => '[Comment deleted]';

  @override
  String get deletedUser => 'Deleted user';

  @override
  String sharedMenuTitlePattern(String name) {
    return '$name\'s weekly menu';
  }

  @override
  String importedFromMenu(String name, String title) {
    return 'Imported from $name\'s menu \"$title\"';
  }

  @override
  String get importedRecipeLabel => 'Imported recipe';

  @override
  String get activityCreatedRecipe => 'created a recipe';

  @override
  String get activitySharedRecipe => 'shared a recipe';

  @override
  String activityRatedRecipe(int rating) {
    return 'rated a recipe ($rating⭐)';
  }

  @override
  String get activityCommentedRecipe => 'commented on a recipe';

  @override
  String activityReactedRecipe(String reaction) {
    return 'reacted to a recipe ($reaction)';
  }

  @override
  String get activityCreatedMenu => 'created a menu';

  @override
  String get activitySharedMenu => 'shared a menu';

  @override
  String get activityCreatedShoppingList => 'created a shopping list';

  @override
  String get activitySharedShoppingList => 'shared a shopping list';

  @override
  String get activityJoinedGroup => 'joined a group';

  @override
  String activityUnlockedAchievement(String achievement) {
    return 'unlocked an achievement: $achievement';
  }

  @override
  String get activityDidSomething => 'did something';

  @override
  String get labelEmptyMenu => 'Empty menu';

  @override
  String get labelMultipleChanges => 'Multiple changes';

  @override
  String get errorVideoNoSubtitles => 'Video has no subtitles';

  @override
  String get errorNetworkFallback => 'Network error';

  @override
  String get recipeCollaborationEnable => 'Enable collaboration';

  @override
  String get recipeCollaborationDisable => 'Disable collaboration';

  @override
  String get menuCommentDeletedSuccess => 'Comment deleted';

  @override
  String get recipeSharingStatus => 'Sharing status';

  @override
  String get recipeSharingStopAll => 'Stop sharing with all';

  @override
  String get recipeSharingStopAllConfirm =>
      'Are you sure you want to stop sharing with everyone?';

  @override
  String get recipeSharingStopAllSuccess => 'Sharing stopped with everyone';

  @override
  String get recipeSharingRevoke => 'Revoke sharing';

  @override
  String recipeSharingRevokeConfirm(String name) {
    return 'Stop sharing with $name?';
  }

  @override
  String recipeSharingRevokeSuccess(String name) {
    return 'Sharing with $name stopped';
  }

  @override
  String get recipeSharingFriends => 'Friends';

  @override
  String get recipeSharingGroups => 'Groups';

  @override
  String get menuRatingRemoveTitle => 'Remove rating?';

  @override
  String get menuRatingRemoveMessage => 'Do you want to remove your rating?';

  @override
  String get menuRatingRemoveConfirm => 'Remove';

  @override
  String get menuRatingRemoveButton => 'Remove rating';

  @override
  String get menuRatingRemoved => 'Rating removed';

  @override
  String get menuRatingRemoveError => 'Could not remove rating';

  @override
  String get shoppingTemplates => 'Shopping templates';

  @override
  String get shoppingTemplateBrowse => 'Browse templates';

  @override
  String get shoppingTemplateEmpty => 'No saved templates';

  @override
  String get shoppingTemplateEmptyDescription =>
      'Save a shopping list as a template for quick recreation';

  @override
  String get shoppingTemplateUse => 'Use template';

  @override
  String get shoppingTemplateDelete => 'Delete template';

  @override
  String get shoppingTemplateDeleted => 'Template deleted';

  @override
  String get shoppingTemplateCreated => 'List created from template';

  @override
  String shoppingTemplateItemCount(int count) {
    return '$count items';
  }

  @override
  String shoppingTemplateUsedCount(int count) {
    return 'Used $count times';
  }

  @override
  String get labelButleryUser => 'Butlery user';

  @override
  String get shoppingListSummaryEmpty => 'Empty shopping list';

  @override
  String shoppingListSummaryAllDone(int count) {
    return 'All $count items done';
  }

  @override
  String shoppingListSummaryToBuy(int count) {
    return '$count items to buy';
  }

  @override
  String shoppingListSummaryRemaining(int remaining, int total) {
    return '$remaining of $total items remaining';
  }

  @override
  String notificationBatchComments(int count) {
    return '$count new comments on your recipes';
  }

  @override
  String notificationCommentSingle(String author, String recipe) {
    return '$author commented on \"$recipe\"';
  }

  @override
  String notificationCommentMultipleSameAuthor(
    String author,
    int count,
    String recipe,
  ) {
    return '$author wrote $count comments on \"$recipe\"';
  }

  @override
  String notificationCommentMultipleAuthors(
    int authorCount,
    int commentCount,
    String recipe,
  ) {
    return '$authorCount people wrote $commentCount comments on \"$recipe\"';
  }

  @override
  String notificationRatingSingle(String recipe, int count, String period) {
    return 'Your recipe \"$recipe\" received $count new ratings this $period!';
  }

  @override
  String notificationRatingMultiple(
    int totalRatings,
    int recipeCount,
    String period,
  ) {
    return 'Your recipes received $totalRatings new ratings across $recipeCount recipes this $period!';
  }

  @override
  String timeCompactMonths(int count) {
    return '${count}mo';
  }

  @override
  String validationFieldCannotBeEmpty(String fieldName) {
    return '$fieldName cannot be empty';
  }

  @override
  String validationMustBeNumber(String fieldName) {
    return '$fieldName must be a number';
  }

  @override
  String validationMinValue(String fieldName, String min) {
    return '$fieldName must be at least $min';
  }

  @override
  String validationMaxValue(String fieldName, String max) {
    return '$fieldName must be at most $max';
  }

  @override
  String get validationDefaultValueLabel => 'The value';

  @override
  String get validationInvalidUrlHint =>
      'Enter a valid URL (starting with http:// or https://)';

  @override
  String get validationFieldRating => 'Rating';

  @override
  String get validationFieldPortions => 'Number of portions';

  @override
  String get validationFieldCookingTime => 'Cooking time';

  @override
  String get validationDisplayNameEmpty => 'Display name cannot be empty';

  @override
  String get validationDisplayNameTooShort =>
      'Display name must be at least 2 characters';

  @override
  String get validationDisplayNameTooLong =>
      'Display name must be at most 30 characters';

  @override
  String get validationDisplayNameInvalidChars =>
      'Display name can only contain letters, numbers, spaces and - _ .';

  @override
  String get validationDisplayNameNoLetters =>
      'Display name must contain at least one letter or number';

  @override
  String get validationDisplayNameNoSpaces =>
      'Display name cannot start or end with spaces';

  @override
  String get validationCommentEmpty => 'Comment cannot be empty';

  @override
  String get validationCommentTooShort =>
      'Comment must be at least 3 characters';

  @override
  String get validationCommentTooLong =>
      'Comment must be at most 500 characters';

  @override
  String validationMessageMaxLength(int max) {
    return 'Message must be at most $max characters';
  }

  @override
  String get validationNameTooShort => 'Name must be at least 2 characters';

  @override
  String get validationEmailInvalidHint => 'Enter a valid email address';

  @override
  String get validationShoppingItemRequired => 'Enter item name';

  @override
  String get validationAmountRequired => 'Enter amount';

  @override
  String get validationTagMinLength => 'Each tag must be at least 2 characters';

  @override
  String get validationTagMaxLength => 'Each tag must be at most 20 characters';

  @override
  String validationFieldNotEmpty(String fieldName) {
    return '$fieldName cannot be empty';
  }

  @override
  String get validationPasswordMinEight =>
      'Password must be at least 8 characters';

  @override
  String get validationPasswordNeedsUppercase =>
      'Password must contain at least one uppercase letter';

  @override
  String get validationPasswordNeedsLowercase =>
      'Password must contain at least one lowercase letter';

  @override
  String get validationPasswordNeedsDigit =>
      'Password must contain at least one digit';

  @override
  String get validationDisplayNameLabel => 'Display name';

  @override
  String get validationCommentLabel => 'Comment';

  @override
  String get validationAmountMustBePositive =>
      'Amount must be a positive number';

  @override
  String get validationUserIdRequired => 'User ID required for this operation';

  @override
  String get validationFieldRecipeName => 'Recipe name';

  @override
  String get validationFieldGroupName => 'Group name';

  @override
  String get validationFieldArticle => 'Item';

  @override
  String errorImageUploadFailed(String message) {
    return 'Image upload failed: $message';
  }

  @override
  String errorRecipeServiceFailed(String message) {
    return 'Recipe management failed: $message';
  }

  @override
  String errorPermissionFailed(String message) {
    return 'Permission error: $message';
  }

  @override
  String errorNetworkWithDetail(String message) {
    return 'Network error: $message';
  }

  @override
  String errorStorageFailed(String message) {
    return 'Storage error: $message';
  }

  @override
  String errorCollaborationFailed(String message) {
    return 'Collaboration error: $message';
  }

  @override
  String errorAutoSaveFailed(String message) {
    return 'Auto-save failed: $message';
  }

  @override
  String errorSystemFailed(String message) {
    return 'System error: $message';
  }

  @override
  String get actionRefresh => 'Refresh';

  @override
  String get actionGoBack => 'Go back';

  @override
  String get actionReport => 'Report';

  @override
  String get shareIngredientsLabel => 'Ingredients:';

  @override
  String get shareInstructionsLabel => 'Instructions:';

  @override
  String get shareSourceLabel => 'Source:';

  @override
  String get sharePortionsUnit => 'portions';

  @override
  String get shareMinutesUnit => 'minutes';

  @override
  String uploadNotificationTitle(int percentage) {
    return 'Upload $percentage% complete';
  }

  @override
  String uploadNotificationMessage(int percentage) {
    return 'Image upload progress - $percentage% complete';
  }

  @override
  String get feedbackDescriptionRequired => 'Enter a description';

  @override
  String get feedbackThanks => 'Thank you for your feedback!';

  @override
  String get feedbackSendFailed => 'Could not send feedback. Try again.';

  @override
  String get tooltipRemoveOption => 'Remove option';

  @override
  String get personalTagCouldNotShare => 'Could not share tag';

  @override
  String get reactionThumbsUp => 'Thumbs up';

  @override
  String get reactionHeart => 'Heart';

  @override
  String get reactionFire => 'Fire';

  @override
  String get reactionLaughing => 'Laughing';

  @override
  String get reactionYum => 'Yummy';

  @override
  String get reactionThinking => 'Thinking';

  @override
  String menuCompletionPercent(int percentage) {
    return '$percentage% complete';
  }

  @override
  String networkErrorNoConnection(String operation) {
    return 'No internet connection. $operation will be saved locally and synced when you\'re back online.';
  }

  @override
  String networkErrorNoConnectionShort(String operation) {
    return 'No internet connection for $operation.';
  }

  @override
  String networkErrorMobileData(String operation) {
    return 'Using mobile data for $operation. This may take longer or affect your data usage.';
  }

  @override
  String networkErrorMobileShort(String operation) {
    return 'Mobile connection for $operation.';
  }

  @override
  String networkErrorLimited(String operation) {
    return 'Limited connection detected. $operation may take longer or be saved locally.';
  }

  @override
  String networkErrorLimitedShort(String operation) {
    return 'Limited connection for $operation.';
  }

  @override
  String networkErrorDefault(String operation) {
    return 'The connection faltered during $operation. Kindly verify and retry.';
  }

  @override
  String permissionErrorAction(String action, String resource) {
    return 'You cannot $action this $resource';
  }

  @override
  String permissionErrorBecause(String reason) {
    return 'because $reason';
  }

  @override
  String permissionErrorSuggestion(String suggestion) {
    return 'Suggestion: $suggestion';
  }

  @override
  String errorDuringAction(String action, String issue) {
    return 'Problem while $action: $issue';
  }

  @override
  String errorDuringActionRecovery(
    String action,
    String issue,
    String recovery,
  ) {
    return 'Problem while $action: $issue\n\nSuggestion: $recovery';
  }

  @override
  String get formatPortionSingle => '1 portion';

  @override
  String formatPortionPlural(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count portions',
      one: '1 portion',
    );
    return '$_temp0';
  }

  @override
  String validationFailedWith(String error) {
    return 'Validation failed: $error';
  }

  @override
  String get snackbarNoInternet =>
      'No internet connection. Check your connection.';

  @override
  String get errorInvalidYoutubeUrl => 'Invalid YouTube URL';

  @override
  String get errorInvalidInstructionIndex => 'Invalid instruction indices';

  @override
  String get errorInvalidIngredientIndex => 'Invalid ingredient indices';

  @override
  String errorInvalidCategoryNamesFromTo(
    String fromCategory,
    String toCategory,
  ) {
    return 'Invalid category names: $fromCategory -> $toCategory';
  }

  @override
  String get validationTitleMissing => 'Title is missing';

  @override
  String get validationIngredientsMissing => 'Ingredients are missing';

  @override
  String get validationInstructionsMissing => 'Instructions are missing';

  @override
  String get validationMealTypeMissing => 'Meal type is missing';

  @override
  String get shareMinutesAbbrev => 'min';

  @override
  String get sharePortionsAbbrev => 'serv';

  @override
  String get shareTimeLabel => 'Time:';

  @override
  String get shareTimeLabelBold => '**Time:**';

  @override
  String get sharePortionsLabel => 'Portions:';

  @override
  String get sharePortionsLabelBold => '**Portions:**';

  @override
  String get shareRatingLabel => 'Rating:';

  @override
  String get shareRatingLabelBold => '**Rating:**';

  @override
  String get shareTypeLabel => 'Type:';

  @override
  String get shareTypeLabelBold => '**Type:**';

  @override
  String get shareTagsLabel => 'Tags';

  @override
  String get shareInstructionsLabelCompact => 'Instructions:';

  @override
  String get shareShoppingListTitleSimple => 'Shopping list';

  @override
  String get shareWeekMenuTitle => 'Week menu';

  @override
  String get shareWeekMenuTitleEmoji => '🍽 WEEK MENU';

  @override
  String get shareSummaryLabel => '📊 Summary:';

  @override
  String shareSummaryRecipesInCategories(int recipeCount, int categoryCount) {
    return '$recipeCount recipes in $categoryCount categories';
  }

  @override
  String get unsavedChangesTitle => 'Unsaved changes';

  @override
  String get unsavedChangesMessage =>
      'You have unsaved changes. Do you really want to cancel?';

  @override
  String get cancelWithoutSaving => 'Cancel without saving';

  @override
  String get deleteActionIrreversible => 'This action cannot be undone.';

  @override
  String get deleteConfirmMessage => 'Do you really want to delete';

  @override
  String get groupLeaveTitle => 'Leave group?';

  @override
  String groupLeaveMessage(String name) {
    return 'Do you really want to leave the group \"$name\"?';
  }

  @override
  String get groupLeaveAction => 'Leave group';

  @override
  String shareItemTitle(String type) {
    return 'Share $type?';
  }

  @override
  String shareItemMessage(String type, String recipients) {
    return 'Do you want to share $type with $recipients?';
  }

  @override
  String shareRecipientsMore(int count) {
    return 'and $count more';
  }

  @override
  String get recipeDeleteWarning => 'The recipe will be permanently deleted.';

  @override
  String get shoppingListDeleteWarning =>
      'All items on the list will be removed.';

  @override
  String itemDeletedSuccess(String type) {
    return '$type has been deleted';
  }

  @override
  String itemDeleteError(String type) {
    return 'Could not delete $type';
  }

  @override
  String get commentDeleteError => 'Could not delete the comment';

  @override
  String get commentEditHint => 'Edit your comment';

  @override
  String get commentLabel => 'Comment';

  @override
  String get commentEditError => 'Could not update the comment';

  @override
  String get commentEdited => 'Comment updated';

  @override
  String get commentReact => 'React';

  @override
  String get reactionUpdateError => 'Could not update reaction';

  @override
  String get activityRecipeCreated => '👨‍🍳 Recipe created';

  @override
  String get activityMenuCreated => '📋 Menu created';

  @override
  String get activityShoppingListCreated => '🛒 Shopping list created';

  @override
  String get activityRecipeShared => '📤 Recipe shared';

  @override
  String get activityMenuShared => '📤 Menu shared';

  @override
  String get activityShoppingListShared => '📤 Shopping list shared';

  @override
  String get activityCommentAdded => '💬 Comment';

  @override
  String get activityReactionAdded => '❤️ Reaction';

  @override
  String get activityRecipeRated => '⭐ Rating';

  @override
  String get activityGroupJoined => '👥 Joined group';

  @override
  String get activityInvitationSent => '📩 Invitation sent';

  @override
  String get activityInvitationAccepted => '✅ Invitation accepted';

  @override
  String get activityAchievementUnlocked => '🏆 Achievement';

  @override
  String get activityMilestoneReached => '🎯 Milestone';

  @override
  String get activityUnknown => '❓ Unknown activity';

  @override
  String get pollVoteSingular => 'vote';

  @override
  String get pollVotePlural => 'votes';

  @override
  String get pollClosed => 'Closed';

  @override
  String get pollCloseAction => 'Close poll';

  @override
  String get chatGroupChatDefault => 'Group chat';

  @override
  String chatGroupCreatedMessage(String name, String title) {
    return '$name created the group \"$title\"';
  }

  @override
  String chatParticipantAdded(String name) {
    return '$name was added to the group';
  }

  @override
  String chatParticipantLeft(String name) {
    return '$name left the group';
  }

  @override
  String get authRequiredError => 'You must be logged in';

  @override
  String get shoppingListEditPermissionDenied =>
      'You do not have permission to edit this shared shopping list';

  @override
  String get tagShareError => 'Could not share the tag';

  @override
  String get userStatusOffline => 'Offline';

  @override
  String get userStatusAway => 'Away';

  @override
  String get userStatusBusy => 'Busy';

  @override
  String participantsCount(int count) {
    return 'Participants ($count)';
  }

  @override
  String participantsOnlineCount(int count) {
    return '$count online';
  }

  @override
  String get restoreDraft => 'Restore';

  @override
  String fieldsFilledCount(int count) {
    return '$count fields filled';
  }

  @override
  String get noFriends => 'You have no friends yet.';

  @override
  String get noRecipes => 'You have no recipes yet.';

  @override
  String get addRecipe => 'Add recipe';

  @override
  String get editRecipe => 'Edit recipe';

  @override
  String get checkPermissions => 'Check permissions';

  @override
  String get ingredientParseError => 'Could not parse ingredient';

  @override
  String get portionsUnit => 'portions';

  @override
  String sharedRecipeFallback(int count) {
    return 'Shared recipe • $count members';
  }

  @override
  String sharedMenuFallback(int count) {
    return 'Shared menu • $count members';
  }

  @override
  String get sharedFallback => 'Shared';

  @override
  String get accountSecurityTitle => 'Account Security';

  @override
  String get accountSecurityChangePassword => 'Change Password';

  @override
  String get accountSecurityChangeEmail => 'Change Email';

  @override
  String get accountSecurityCurrentPassword => 'Current Password';

  @override
  String get accountSecurityNewPassword => 'New Password';

  @override
  String get accountSecurityConfirmPassword => 'Confirm Password';

  @override
  String get accountSecurityNewEmail => 'New Email';

  @override
  String get accountSecurityMfaSettings => 'Two-Factor Authentication';

  @override
  String get accountSecurityPasswordChanged => 'Password changed successfully';

  @override
  String get accountSecurityEmailVerificationSent =>
      'Verification link sent to new email address';

  @override
  String get accountSecurityPasswordMismatch => 'Passwords do not match';

  @override
  String get profileAccountSecurity => 'Account Security';

  @override
  String get profileAccountSecuritySubtitle =>
      'Password, email, and two-factor authentication';

  @override
  String bulkSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get bulkSelectAll => 'Select All';

  @override
  String get bulkCancelSelection => 'Cancel selection';

  @override
  String get bulkDelete => 'Delete Selected';

  @override
  String get bulkShare => 'Share Selected';

  @override
  String get bulkTag => 'Tag Selected';

  @override
  String bulkTagDialogTitle(int count) {
    return 'Add tag to $count recipes';
  }

  @override
  String get bulkTagNoTagsAvailable => 'No personal tags available';

  @override
  String bulkTagSuccess(int count) {
    return 'Tag added to $count recipes';
  }

  @override
  String get bulkTagAllAlreadyTagged =>
      'All selected recipes already have this tag';

  @override
  String get viewModeGrid => 'Grid View';

  @override
  String get viewModeList => 'List View';

  @override
  String get duplicateImportTitle => 'Recipe may already exist';

  @override
  String duplicateImportMessage(String recipeName) {
    return 'A recipe with the same source already exists: $recipeName';
  }

  @override
  String get duplicateImportViewExisting => 'View Existing';

  @override
  String get duplicateImportAnyway => 'Import Anyway';

  @override
  String get imageCropTitle => 'Crop image';

  @override
  String get bulkDeleteConfirmMessage =>
      'The selected recipes will be removed.';

  @override
  String bulkDeleteSuccess(int count) {
    return '$count recipes deleted';
  }

  @override
  String get profileFaq => 'FAQ';

  @override
  String get profileFaqSubtitle => 'Help and answers to common questions';

  @override
  String get faqQ1 => 'How do I import recipes?';

  @override
  String get faqA1 =>
      'You can import recipes in several ways: paste a URL from a recipe site, take a photo of a recipe, or paste recipe text directly. Tap \"Add\" on the home screen and choose a method.';

  @override
  String get faqQ2 => 'How do I share recipes with friends?';

  @override
  String get faqA2 =>
      'Open a recipe and tap the share icon. You can send the recipe to friends who use Butlery, or share a link. Your friends can then save the recipe to their own collection.';

  @override
  String get faqQ3 => 'How do I use the weekly menu?';

  @override
  String get faqA3 =>
      'Go to the weekly menu via the navigation. There you can plan the week\'s meals by adding recipes from your collection. Ingredients from the menu can be sent directly to the shopping list.';

  @override
  String get faqQ4 => 'How do I create personal tags?';

  @override
  String get faqA4 =>
      'Go to your profile and select \"My tags\". There you can create tags such as \"Everyday meals\" or \"Party food\" and assign them to your recipes for easy filtering.';

  @override
  String get faqQ5 => 'How do I report problems?';

  @override
  String get faqA5 =>
      'Tap the \"!\" button shown at the bottom right of every page. There you can describe the problem, choose a category and attach a screenshot. We read all feedback!';

  @override
  String get sharedWithYou => 'Shared with you';

  @override
  String get importTag => 'Import';

  @override
  String get tagImportedSuccess => 'Tag imported successfully';

  @override
  String get legalTermsOfService => 'Terms of Service';

  @override
  String get legalCommunityGuidelines => 'Community Guidelines';

  @override
  String get legalOpenSourceLicenses => 'Open Source Licenses';

  @override
  String get authAgeConfirmation => 'I confirm that I am at least 13 years old';

  @override
  String get authAgeConfirmationRequired =>
      'You must confirm your age to create an account';

  @override
  String get authTermsAcceptPrefix => 'I accept the ';

  @override
  String get authTermsAcceptMiddle => ' and ';

  @override
  String get authTermsAcceptRequired =>
      'You must accept the terms to create an account';

  @override
  String get reportContent => 'Report';

  @override
  String get reportReasonInappropriate => 'Inappropriate content';

  @override
  String get reportReasonSpam => 'Spam';

  @override
  String get reportReasonHarassment => 'Harassment';

  @override
  String get reportReasonCopyright => 'Copyright infringement';

  @override
  String get reportReasonOther => 'Other';

  @override
  String get reportDescriptionHint => 'Describe the issue (optional)';

  @override
  String get reportSubmitted => 'Report submitted';

  @override
  String get reportSubmitFailed => 'Could not submit report';

  @override
  String get reportDialogTitle => 'Report content';

  @override
  String get reportSubmit => 'Submit report';

  @override
  String get reportDialogGuidelinesNotePrefix =>
      'By reporting, you confirm the content violates';

  @override
  String get reportDialogGuidelinesLink => 'our community guidelines';

  @override
  String get settingsMyReports => 'My reports';

  @override
  String get myReportsTitle => 'My reports';

  @override
  String get myReportsEmpty => 'You haven\'t submitted any reports yet.';

  @override
  String get myReportsStatusPending => 'Submitted';

  @override
  String get myReportsStatusReviewed => 'Reviewed';

  @override
  String get myReportsStatusActioned => 'Actioned';

  @override
  String get myReportsStatusClosed => 'Closed';

  @override
  String get myReportsLoadFailed => 'Could not load reports';

  @override
  String get myReportsRetry => 'Retry';

  @override
  String get newAccountSocialBlocked => 'Verify your email to add friends';

  @override
  String get newAccountSocialBlockedAction => 'Send verification';

  @override
  String get duplicateContentRejected => 'You just sent the same message.';

  @override
  String get contentFilterWarning =>
      'The text contains inappropriate language. Please edit before submitting.';

  @override
  String get noResults => 'No results';

  @override
  String allergenCoverageLabel(int coverage) {
    return '$coverage% coverage';
  }

  @override
  String get ingredientDataUnverified => 'Some ingredient data is unverified';

  @override
  String get recipeStartCookingTooltip => 'Start cooking';

  @override
  String get taggingDegradedWarning =>
      'Allergen and dietary data may be unreliable';

  @override
  String get recipeEditTags => 'Edit tags';

  @override
  String get allergenDisclaimer =>
      'Allergen information is based on automated analysis and is for guidance only. Always check the original recipe and product packaging. Does not replace medical advice.';

  @override
  String allergenToggleSemantics(String allergen) {
    return 'Toggle $allergen allergen tracking';
  }

  @override
  String dietaryToggleSemantics(String dietary) {
    return 'Toggle $dietary dietary preference';
  }

  @override
  String get emailVerificationTitle => 'Verify your email';

  @override
  String emailVerificationMessage(String email) {
    return 'We\'ve sent a verification email to $email.';
  }

  @override
  String get emailVerificationResend => 'Send again';

  @override
  String get emailVerificationContinue => 'Continue anyway';

  @override
  String get emailVerificationSuccess => 'Email verified!';

  @override
  String get a11yCookingModeFontScale => 'Change text size';

  @override
  String get a11yCookingModeClose => 'Close cooking mode';

  @override
  String get a11yRecipeFavorited => 'Recipe added to favorites';

  @override
  String get a11yRecipeUnfavorited => 'Recipe removed from favorites';

  @override
  String get a11yCommentPosted => 'Comment posted';

  @override
  String get a11yItemBought => 'Marked as bought';

  @override
  String get a11yItemUnbought => 'Marked as not bought';

  @override
  String get a11yOcrComplete => 'Text extraction complete';

  @override
  String a11yCookingModeIngredient(String ingredient) {
    return '$ingredient';
  }

  @override
  String a11yCookingModeStep(int step, String instruction) {
    return 'Step $step: $instruction';
  }

  @override
  String get tooltipShowPassword => 'Show password';

  @override
  String get tooltipHidePassword => 'Hide password';

  @override
  String get tooltipSendMessage => 'Send message';

  @override
  String get tooltipAttachImage => 'Attach image';

  @override
  String get tooltipAttachFile => 'Attach file';

  @override
  String get tooltipCreatePoll => 'Create poll';

  @override
  String get tooltipSelectedImage => 'Selected image';

  @override
  String get statsMyStatistics => 'My Statistics';

  @override
  String get statsRecipeCollection => 'Recipe Collection';

  @override
  String get statsTotalRecipes => 'Total Recipes';

  @override
  String get statsFavorites => 'Favorites';

  @override
  String get statsRecentlyCooked => 'Recently Cooked';

  @override
  String get statsWithImages => 'With Images';

  @override
  String get statsPersonalRecipes => 'Personal Recipes';

  @override
  String get statsCollaborativeRecipes => 'Collaborative Recipes';

  @override
  String get statsHighRated => 'High Rated';

  @override
  String get statsMealTypes => 'Meal Types';

  @override
  String get statsPopularTags => 'Popular Tags';

  @override
  String get statsCookingActivity => 'Cooking Activity';

  @override
  String get statsTotalCooks => 'Total Cooks';

  @override
  String get statsNoMealTypes => 'No meal types recorded';

  @override
  String get statsNoTags => 'No tags used yet';

  @override
  String get statsDistinctMealTypes => 'Meal Types';

  @override
  String get statsDistinctTags => 'Tags';

  @override
  String get importPendingRetryPrompt =>
      'You have a pending import — retry now?';

  @override
  String get importPendingRetry => 'Retry';

  @override
  String get importPendingDismiss => 'Dismiss';

  @override
  String get importSavedForLater =>
      'URL saved — will import when you\'re back online';

  @override
  String get importOfflineMessage =>
      'You\'re offline — connect to the internet and try again.';

  @override
  String get seasonalForgottenFavorites => 'Forgotten Favorites';

  @override
  String seasonalHeroTitle(String month) {
    return 'in season now · $month';
  }

  @override
  String seasonalHeroRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return '$_temp0';
  }

  @override
  String get seasonalMonthJanuary => 'January';

  @override
  String get seasonalMonthFebruary => 'February';

  @override
  String get seasonalMonthMarch => 'March';

  @override
  String get seasonalMonthApril => 'April';

  @override
  String get seasonalMonthMay => 'May';

  @override
  String get seasonalMonthJune => 'June';

  @override
  String get seasonalMonthJuly => 'July';

  @override
  String get seasonalMonthAugust => 'August';

  @override
  String get seasonalMonthSeptember => 'September';

  @override
  String get seasonalMonthOctober => 'October';

  @override
  String get seasonalMonthNovember => 'November';

  @override
  String get seasonalMonthDecember => 'December';

  @override
  String get dormantRecipesTitle => 'Try something you saved';

  @override
  String get emptyStateNewUserTitle => 'Welcome. Butlery stands ready.';

  @override
  String get emptyStateNewUserDescription =>
      'The first recipe may be imported from a link, or entered by hand.';

  @override
  String get emptyStateNewUserWithPrefs =>
      'Your dietary preferences are ready. Import your first recipe and we\'ll filter for you!';

  @override
  String get emptyStateImportAction => 'Import by link';

  @override
  String get emptyStateOtherOptions => 'Further options';

  @override
  String get cookingModePreviousStep => 'Previous step';

  @override
  String get cookingModeNextStep => 'Next step';

  @override
  String cookingModeStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String cookingModeStepAnnounce(int step, String instruction) {
    return 'Step $step: $instruction';
  }

  @override
  String get quickCaptureTitle => 'Quick save recipe';

  @override
  String get quickCaptureSubtitle =>
      'Just name and meal type — add the rest later';

  @override
  String get quickCaptureSave => 'Save';

  @override
  String get quickCaptureSaved => 'Recipe saved!';

  @override
  String get quickCaptureEditAction => 'Edit';

  @override
  String get quickCaptureTitleHint => 'What\'s the recipe called?';

  @override
  String get a11ySwipeEditAction => 'Edit recipe';

  @override
  String get a11ySwipeDeleteAction => 'Delete recipe';

  @override
  String a11yRecipeSelected(String title) {
    return '$title, selected';
  }

  @override
  String a11yRecipeNotSelected(String title) {
    return '$title, not selected';
  }

  @override
  String get recipeImproveTitle => 'Improve this recipe';

  @override
  String get recipeImproveMissingTitle => 'Title';

  @override
  String get recipeImproveMissingIngredients => 'Ingredients';

  @override
  String get recipeImproveMissingInstructions => 'Instructions';

  @override
  String get recipeImproveMissingPortions => 'Servings';

  @override
  String get recipeImproveMissingTime => 'Cooking time';

  @override
  String get recipeImproveMissingImage => 'Photo';

  @override
  String recipeCompleteness(int score) {
    return '$score% complete';
  }

  @override
  String recipeCompletenessA11y(int score) {
    return 'Recipe is $score percent complete';
  }

  @override
  String get pwaInstallPrompt =>
      'Install Butlery on your home screen for quicker access';

  @override
  String get pwaInstallAction => 'Install';

  @override
  String duplicateMergeSimilarity(int percent) {
    return '$percent% similar';
  }

  @override
  String get duplicateMergeExisting => 'Existing';

  @override
  String get duplicateMergeNew => 'New';

  @override
  String get duplicateMergeTitle => 'Duplicate recipe found';

  @override
  String get duplicateMergeFieldTitle => 'Title';

  @override
  String get duplicateMergeFieldTime => 'Time';

  @override
  String get duplicateMergeFieldPortions => 'Portions';

  @override
  String get duplicateMergeFieldIngredients => 'Ingredients';

  @override
  String get duplicateMergeFieldSteps => 'Steps';

  @override
  String get duplicateMergeFieldSource => 'Source';

  @override
  String get duplicateMergeFieldImage => 'Image';

  @override
  String get duplicateMergeKeepExisting => 'Keep existing';

  @override
  String get duplicateMergeReplaceWithNew => 'Replace with new';

  @override
  String get duplicateMergeSaveAsNew => 'Save as new';

  @override
  String get duplicateMergeBestFields => 'Merge best fields';

  @override
  String get duplicateMergeSuccess => 'Recipe has been merged';

  @override
  String get duplicateMergeNoTime => 'No time';

  @override
  String duplicateMergeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String duplicateMergeItemCount(int count) {
    return '$count items';
  }

  @override
  String get duplicateMergeNoSource => 'No source';

  @override
  String get duplicateMergeNoImage => 'No image';

  @override
  String menuSwapAlternatives(int count) {
    return '$count alternatives left';
  }

  @override
  String get menuSwapExhausted =>
      'No more alternatives matching your preferences';

  @override
  String get menuSuggestionFavorites => 'Weekly menu from favorites';

  @override
  String get menuSuggestionRecent => 'Menu with recent recipes';

  @override
  String get publicProfileTitle => 'Profile';

  @override
  String get publicProfileEmpty => 'This user has no public recipes';

  @override
  String get publicProfileError => 'Profile not found';

  @override
  String get publicProfileShareButton => 'Share profile';

  @override
  String get publicProfilePublicRecipes => 'Public recipes';

  @override
  String get statsCompleteness => 'Recipe Quality';

  @override
  String get statsWithoutPhoto => 'No photo';

  @override
  String get statsWithoutTime => 'No time';

  @override
  String get statsIncomplete => 'Incomplete';

  @override
  String get statsAllComplete => 'All recipes are complete!';

  @override
  String get notificationsTitle => 'Notifications';

  @override
  String get notificationsEmpty => 'No notifications yet';

  @override
  String get notificationsErrorLoad => 'Could not load notifications';

  @override
  String notificationsSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get notificationsMarkAllRead => 'Mark all as read';

  @override
  String get allergenIncludeUnknownTitle => 'Show unknown allergen status';

  @override
  String get allergenIncludeUnknownSubtitle =>
      'Include recipes with unknown allergen status in menu suggestions';

  @override
  String get tagDecisionWhyTitle => 'Why this tag?';

  @override
  String get tagDecisionReason => 'Reason';

  @override
  String get tagDecisionIngredients => 'Ingredients';

  @override
  String get cookSnapSectionTitle => 'Cooked this';

  @override
  String cookSnapSectionTitleCount(int count) {
    return 'Cooked this ($count)';
  }

  @override
  String get cookSnapAddTooltip => 'Add cooking photo';

  @override
  String get cookSnapEmptyTitle => 'No one has cooked this yet';

  @override
  String get cookSnapEmptySubtitle => 'Be the first!';

  @override
  String get cookSnapFromCamera => 'Take photo';

  @override
  String get cookSnapFromGallery => 'Choose from gallery';

  @override
  String get cookSnapMe => 'Me';

  @override
  String get cookSnapVisibilityTitle => 'Who sees this photo?';

  @override
  String get cookSnapVisibilityPublic =>
      'This recipe is public – the photo will be visible to everyone.';

  @override
  String cookSnapVisibleTo(String audience) {
    return 'Visible to: $audience';
  }

  @override
  String get cookSnapVisibilityConfirm => 'Share photo';

  @override
  String get cookSnapVisibilityChoiceSame => 'Same as the recipe';

  @override
  String get cookSnapVisibilityChoiceOnlyMe => 'Only me';

  @override
  String get cookSnapVisibilityChoiceOnlyMeHint =>
      'The photo stays hidden from others who can see the recipe';

  @override
  String get cookSnapErrorLoad => 'Could not load photos';

  @override
  String get cookSnapErrorUpload => 'Could not upload photo';

  @override
  String get cookSnapErrorDelete => 'Could not delete photo';

  @override
  String get cookSnapDelete => 'Delete photo';

  @override
  String get cookSnapDeletedUndoMessage => 'Photo will be deleted — undo?';

  @override
  String get cookSnapReport => 'Report photo';

  @override
  String cookSnapPhotoCounter(int current, int total) {
    return '$current/$total';
  }

  @override
  String a11yCookSnapPhotoCarousel(int current, int total) {
    return 'Cooking photo $current of $total';
  }

  @override
  String get collectionInsightsTitle => 'My collection';

  @override
  String get collectionInsightsInsufficientData =>
      'Add more recipes to see patterns';

  @override
  String get collectionInsightsTopCuisines => 'Top cuisines';

  @override
  String get collectionInsightsDietaryVegetarian => 'vegetarian';

  @override
  String get collectionInsightsDietaryVegan => 'vegan';

  @override
  String get collectionInsightsDietaryPescetarian => 'pescetarian';

  @override
  String personalTagUnusedTags(int count) {
    return 'Unused tags ($count)';
  }

  @override
  String get personalTagDeleteAllUnused => 'Delete all unused';

  @override
  String get personalTagDeleteAllUnusedConfirm => 'Delete unused tags?';

  @override
  String personalTagDeleteAllUnusedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags with no recipes will be deleted.',
      one: '1 tag with no recipes will be deleted.',
    );
    return '$_temp0';
  }

  @override
  String personalTagUnusedDeleted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unused tags deleted',
      one: '1 unused tag deleted',
    );
    return '$_temp0';
  }

  @override
  String get weeklyMenuToggleList => 'List';

  @override
  String get weeklyMenuToggleCalendar => 'Calendar';

  @override
  String get weeklyMenuPrevWeek => 'Previous week';

  @override
  String get weeklyMenuNextWeek => 'Next week';

  @override
  String get weeklyMenuTodayBadge => 'Today';

  @override
  String get weeklyMenuEmptyTitle => 'No plan yet';

  @override
  String get weeklyMenuEmptyHint =>
      'Generate a weekly menu from the prompt above and we\'ll lay out the days for you.';

  @override
  String get weeklyMenuOverflowTitle => 'Recipes that didn\'t fit';

  @override
  String get weeklyMenuOvrigtAddMore => '+ add';

  @override
  String get weeklyMenuOverwriteConfirm =>
      'This will replace your current plan. Continue?';

  @override
  String get weeklyMenuLoadError => 'Couldn\'t load the weekly menu';

  @override
  String weeklyMenuWeekLabel(int weekNum, String start, String end) {
    return 'Week $weekNum · $start–$end';
  }

  @override
  String get mealSlotLunch => 'Lunch';

  @override
  String get mealSlotMiddag => 'Dinner';

  @override
  String get mealSlotOvrigt => 'Other';

  @override
  String get weeklyMenuChipsHeading => 'We understood:';

  @override
  String get weeklyMenuChipsNotUnderstood => 'We didn\'t understand:';

  @override
  String get weeklyMenuChipsRefinePrompt => 'Refine your prompt';

  @override
  String get weeklyMenuClearWeekAction => 'Clear week';

  @override
  String get weeklyMenuClearedUndo => 'Week cleared';

  @override
  String get weeklyMenuCopyToNextAction => 'Copy this week → next week';

  @override
  String get weeklyMenuCopyToNextConfirmTitle => 'Copy this week?';

  @override
  String get weeklyMenuCopyToNextConfirmBody =>
      'The recipes in this week will be copied to next week. Your current plan for next week is kept.';

  @override
  String weeklyMenuCopyToNextResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes copied to next week',
      one: '1 recipe copied to next week',
      zero: 'Nothing copied – it\'s all already on next week',
    );
    return '$_temp0';
  }

  @override
  String get weeklyMenuCopyToNextFailed => 'Couldn\'t copy the week';

  @override
  String get weeklyMenuSelectAction => 'Select several to move';

  @override
  String weeklyMenuSelectionCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected',
      one: '1 selected',
    );
    return '$_temp0';
  }

  @override
  String get weeklyMenuMoveSelectionAction => 'Move';

  @override
  String get weeklyMenuMoveSheetTitle => 'Move to';

  @override
  String weeklyMenuMovedResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes moved',
      one: '1 recipe moved',
      zero: 'Nothing moved',
    );
    return '$_temp0';
  }

  @override
  String get weeklyMenuMoveFailed => 'Couldn\'t move the recipes';

  @override
  String a11yWeeklyMenuSelectEntry(String recipe) {
    return 'Select $recipe to move';
  }

  @override
  String get pantrySectionExpiring => 'Expiring soon';

  @override
  String get pantrySectionFridge => 'Fridge';

  @override
  String get pantrySectionFreezer => 'Freezer';

  @override
  String get pantrySectionPantry => 'Pantry';

  @override
  String get pantrySectionSpiceRack => 'Spice rack';

  @override
  String get pantryLocationFridge => 'Fridge';

  @override
  String get pantryLocationFreezer => 'Freezer';

  @override
  String get pantryLocationPantry => 'Pantry';

  @override
  String get pantryLocationSpiceRack => 'Spice rack';

  @override
  String get pantryLocationLabel => 'Location';

  @override
  String get pantryExpiryExpired => 'Expired';

  @override
  String get pantryExpiryToday => 'Expires today';

  @override
  String pantryExpiryInDays(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: 'Expires in $days days',
      one: 'Expires in 1 day',
    );
    return '$_temp0';
  }

  @override
  String get pantryExpiryDate => 'Expiry date';

  @override
  String get pantryExpiryLabel => 'Expires';

  @override
  String get pantryExpiryNone => 'No expiry date';

  @override
  String get pantryEmptyTitle => 'Your pantry is empty';

  @override
  String get pantryEmptyDescription =>
      'Add ingredients to find recipes you can cook with what you have';

  @override
  String get pantryAddIngredient => 'Add ingredient';

  @override
  String get pantryAddSheetTitle => 'Add ingredient';

  @override
  String get pantryEditSheetTitle => 'Edit ingredient';

  @override
  String get pantryCouldNotSaveItem =>
      'Couldn\'t save to pantry. Please try again.';

  @override
  String get pantryIngredientLabel => 'Ingredient';

  @override
  String get pantryIngredientHint => 'Search ingredient...';

  @override
  String get pantryQuantityLabel => 'Quantity';

  @override
  String get pantryUnitLabel => 'Unit';

  @override
  String get pantryNoteLabel => 'Note (optional)';

  @override
  String get pantryAddAction => 'ADD';

  @override
  String get pantryDeleteConfirmTitle => 'Remove ingredient?';

  @override
  String get pantryDeleteConfirmMessage =>
      'The ingredient will be removed from the pantry';

  @override
  String get filterWithMyIngredients => 'With my ingredients';

  @override
  String get shoppingTabLists => 'Shopping lists';

  @override
  String get shoppingTabPantry => 'Pantry';

  @override
  String recipeCardPantryMatchA11y(int percent) {
    return 'Matches $percent% of your ingredients';
  }

  @override
  String get ingredientSearchTitle => 'Search by ingredients';

  @override
  String get ingredientSearchHint => 'Search ingredient...';

  @override
  String get ingredientSearchButton => 'Show recipes';

  @override
  String get ingredientSearchChip => 'By ingredients';

  @override
  String get ingredientSearchEmpty => 'Add ingredients to find recipes';

  @override
  String get ingredientSearchNoResults => 'No recipes match your ingredients';

  @override
  String get ingredientSearchError => 'Could not search recipes';

  @override
  String ingredientSearchResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes found',
      one: '1 recipe found',
    );
    return '$_temp0';
  }

  @override
  String ingredientMatchCount(int matched, int total) {
    return '$matched of $total ingredients';
  }

  @override
  String ingredientMissing(String list) {
    return 'Missing: $list';
  }

  @override
  String get ingredientSearchSharedBadge => 'Shared';

  @override
  String get tarJag => 'I\'ll get';

  @override
  String get lamnaTillbaka => 'Give back';

  @override
  String get minDel => 'My part';

  @override
  String annasDel(String name) {
    return '$name\'s part';
  }

  @override
  String get otilldelat => 'Unassigned';

  @override
  String handlarNu(String name) {
    return '$name is shopping now';
  }

  @override
  String get efterZon => 'By zone';

  @override
  String get alla => 'All';

  @override
  String nagonAnnanTogDen(String name) {
    return '$name grabbed that — pick another';
  }

  @override
  String shoppingItemClaimed(String itemName) {
    return 'Claimed \"$itemName\"';
  }

  @override
  String shoppingItemUnclaimed(String itemName) {
    return 'Released \"$itemName\"';
  }

  @override
  String outOfIngredientTitle(String ingredient) {
    return 'Out of $ingredient? Try…';
  }

  @override
  String get ratioSuffix => 'of original amount';

  @override
  String get replaceInRecipe => 'Replace in recipe';

  @override
  String get noSubstitutionSuggestions => 'No suggestions yet';

  @override
  String get substitutionsOfflineMessage =>
      'Substitution suggestions aren\'t available offline.';

  @override
  String get suggestAlternative => 'Suggest an alternative';

  @override
  String get startTimer => 'Start timer';

  @override
  String get timerExpired => 'Timer done!';

  @override
  String get timerNotificationTitle => 'Timer done!';

  @override
  String get timerNotificationBody => 'Your timer has finished.';

  @override
  String timerNotificationBodyLabeled(String label) {
    return 'Done: $label';
  }

  @override
  String get timerNotificationChannelTitle => 'Cooking timers';

  @override
  String get timerNotificationChannelDescription =>
      'Alerts when your cooking timers run out';

  @override
  String get cookingActiveTimersTitle => 'Active timers';

  @override
  String a11yActiveTimer(String label, String time) {
    return 'Timer $label: $time remaining';
  }

  @override
  String get pauseTimer => 'Pause';

  @override
  String get resumeTimer => 'Resume';

  @override
  String get resetTimer => 'Reset';

  @override
  String timerDurationHint(String source) {
    return 'From \"$source\"';
  }

  @override
  String get heirloomToggle => 'This is an heirloom recipe';

  @override
  String get heirloomWriterLabel => 'Who wrote the recipe?';

  @override
  String get heirloomYearLabel => 'Which year?';

  @override
  String get heirloomNoteLabel => 'Short note';

  @override
  String heirloomFrom(String name, int year) {
    return 'From $name, $year';
  }

  @override
  String get heirloomUploadOffline => 'Saving when you\'re back online';

  @override
  String get heirloomUploadError => 'Couldn\'t save the image — try again';

  @override
  String get cookingNowEyebrow => 'cooking right now';

  @override
  String cookingNowSingle(String name, String recipe) {
    return '$name is cooking $recipe';
  }

  @override
  String cookingNowMerge(String names, String recipe) {
    return '$names are cooking $recipe';
  }

  @override
  String get notificationPermissionTitle => 'Turn on notifications?';

  @override
  String get notificationPermissionBody =>
      'Butlery uses notifications for cooking timers, messages from friends, and activity on your shared recipes. You can change this any time in settings.';

  @override
  String get notificationPermissionGrant => 'Allow';

  @override
  String get notificationPermissionOpenSettings => 'Open settings';

  @override
  String get notificationPermissionPermanentlyDeniedMessage =>
      'Notifications are turned off. Open settings to enable them.';

  @override
  String get familyPresenceTitle => 'Online now';

  @override
  String get familyPresenceEmpty => 'Nobody online right now';

  @override
  String familyPresenceOverflow(int count) {
    return '+$count';
  }

  @override
  String cookingStepSuffix(int current, int total) {
    return ' · step $current of $total';
  }

  @override
  String get pingNudge => 'Nudge';

  @override
  String get pingTimerAlert => 'Timer alert';

  @override
  String get pingHelpMe => 'Help me';

  @override
  String get pingComposeTitle => 'Send a ping';

  @override
  String get pingComposeMessageHint => 'Message (optional)';

  @override
  String get pingComposeSend => 'Send';

  @override
  String get pingComposeSent => 'Sent';

  @override
  String get pingRateLimited => 'You\'ve sent too many pings in the last hour';

  @override
  String pingNudgeFrom(String name) {
    return '$name is nudging you';
  }

  @override
  String pingTimerAlertFrom(String name) {
    return '$name\'s timer is ringing';
  }

  @override
  String pingHelpMeFrom(String name) {
    return '$name needs help';
  }

  @override
  String activityAddedIngredient(String name, String ingredient) {
    return '$name added $ingredient';
  }

  @override
  String activityStartedCooking(String name, String recipe) {
    return '$name started cooking $recipe';
  }

  @override
  String get moderatorReviewTitle => 'Review reports';

  @override
  String get moderatorNotAuthorized =>
      'You are not authorised to view this page.';

  @override
  String get moderatorNoOpenReports => 'No open reports right now.';

  @override
  String get moderatorReasonLabel => 'Reason';

  @override
  String get moderatorReporterLabel => 'Reported by';

  @override
  String get moderatorActionAdvance => 'Advance';

  @override
  String get moderatorActionClose => 'Close report';

  @override
  String get moderatorActionDelete => 'Delete content';

  @override
  String get moderatorDeleteConfirmTitle => 'Delete this content?';

  @override
  String get moderatorDeleteConfirmBody =>
      'This permanently removes the reported content. The action cannot be undone from the app.';

  @override
  String get moderatorActionHide => 'Hide profile';

  @override
  String get moderatorHideConfirmTitle => 'Hide this profile?';

  @override
  String get moderatorHideConfirmBody =>
      'The profile will be removed from search and friend lists. The user can still log in but appears as a placeholder to others. You can reverse this later.';

  @override
  String get appealProcessTitle => 'Appeal a removal';

  @override
  String get appealProcessBody =>
      'If your content was removed and you believe the decision was incorrect, you can appeal by emailing appeals@butlery.app. Include your username, the content type (recipe, comment, message) and a brief description. We respond within 14 days.';

  @override
  String get appealEmailLinkLabel => 'Appeal a removal';

  @override
  String get appealEmailSubject => 'Appeal: removed content';

  @override
  String get appealEmailBodyTemplate =>
      'Hello Butlery,\n\nI would like to appeal the removal of the following content:\n- Content type (recipe/comment/message):\n- Approximate date:\n- My username:\n\nReason for the appeal:\n\nThank you.';

  @override
  String get appealEmailLaunchFailed =>
      'Could not open the email app. Please email appeals@butlery.app manually.';

  @override
  String get a11yProfileImageEdit => 'Profile picture, tap to change';

  @override
  String get a11yProfileImageReadonly => 'Profile picture';

  @override
  String get a11yReactToComment => 'React to comment';

  @override
  String a11yShowCommentLikes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Show $count likes',
      one: 'Show 1 like',
    );
    return '$_temp0';
  }

  @override
  String get a11yLongPressCommentForReactions => 'Comment, long press to react';

  @override
  String get a11yDismissReactionPicker => 'Close the reaction picker';

  @override
  String get a11yCommentLikeAction => 'Like comment';

  @override
  String get a11yCommentReplyAction => 'Reply to comment';

  @override
  String get a11yRetryUpload => 'Retry upload';

  @override
  String get a11yCancelUpload => 'Cancel upload';

  @override
  String a11yBulkUploadAction(String label) {
    return '$label';
  }

  @override
  String a11yEditImageAction(String label) {
    return '$label';
  }

  @override
  String get a11yEmptyImageStateAdd => 'Add image, tap to choose';

  @override
  String get a11yImagePickerOpen => 'Choose images';

  @override
  String a11yImagePickerRemove(int index) {
    return 'Remove selected image $index';
  }

  @override
  String get a11yGalleryAddImage => 'Add image to gallery';

  @override
  String recipeCardSemantics(String title) {
    return 'Recipe: $title, tap to open';
  }

  @override
  String recipeRatingSemantics(String rating) {
    return 'Rating: $rating';
  }

  @override
  String get recipeVisibilityPrivate => 'Private';

  @override
  String get recipeVisibilityCollaborative => 'Shared with collaborators';

  @override
  String get recipeVisibilityPublic => 'Public';

  @override
  String a11yMenuRecipeOpen(String title) {
    return '$title, tap to open the recipe';
  }

  @override
  String a11yMenuSectionRegenerate(String category) {
    return 'Generate a new suggestion for $category';
  }

  @override
  String a11yMenuSwapRecipe(String title) {
    return 'Swap out $title';
  }

  @override
  String a11yMenuSuggestAlternative(String title) {
    return 'Suggest an alternative for $title';
  }

  @override
  String a11yShelfRecipeOpen(String title) {
    return '$title, tap to open';
  }

  @override
  String a11yCookSnapOptions(String name) {
    return 'Cooking photo by $name, long press for options';
  }

  @override
  String a11yConversationOpen(String name) {
    return 'Conversation with $name, tap to open';
  }

  @override
  String a11yMenuVoteOption(String name) {
    return 'Vote for $name';
  }

  @override
  String a11yMenuVoteOptionSelected(String name) {
    return '$name, selected. Tap to change vote.';
  }

  @override
  String a11yPingAcknowledge(String name) {
    return 'Acknowledge notification from $name';
  }

  @override
  String a11yMenuPlanRecipeOpen(String title) {
    return '$title, tap to open the recipe';
  }

  @override
  String a11yMenuPlanOvrigtAddMore(String day) {
    return 'Add more to other for $day';
  }

  @override
  String get a11yRefineMenuPrompt => 'Refine the menu prompt';

  @override
  String get a11yHeadingIngredients => 'Ingredients';

  @override
  String get a11yHeadingInstructions => 'Instructions';

  @override
  String get a11yHeadingComments => 'Comments';

  @override
  String a11yAddIngredient(String name) {
    return 'Add $name';
  }

  @override
  String a11yQuickFilter(String label) {
    return 'Filter by $label';
  }

  @override
  String a11yQuickFilterSelected(String label) {
    return '$label, selected filter';
  }

  @override
  String get a11yHeirloomScanOpenFullscreen =>
      'Open original scan in fullscreen';

  @override
  String a11yReplaceWithSubstitute(String name) {
    return 'Replace with $name in recipe';
  }

  @override
  String a11yShareTabSwitch(String label) {
    return 'Show $label';
  }

  @override
  String get a11yPantryAddItem => 'Add new item';

  @override
  String a11yPantryEditItem(String itemName) {
    return '$itemName, press to edit';
  }

  @override
  String get a11yPantryPickExpiry => 'Pick expiry date';

  @override
  String a11yDraftRecoverTile(String title) {
    return '$title, press to restore';
  }

  @override
  String get a11yShareModeStaticCopy => 'Static copy, press to select';

  @override
  String get a11yShareModeRealtime => 'Realtime sharing, press to select';

  @override
  String a11yFriendRequestIncoming(String name) {
    return 'Friend request from $name, press to select';
  }

  @override
  String a11yFriendRequestSent(String name) {
    return 'Sent request to $name, press to select';
  }

  @override
  String a11yFeedFilter(String label) {
    return 'Filter feed by $label';
  }

  @override
  String a11yFeedRecipePreview(String title) {
    return 'Open recipe $title';
  }

  @override
  String a11yPublicProfileRecipeCard(String title) {
    return 'Open recipe $title';
  }

  @override
  String get a11yBlockedUsersToggle =>
      'Blocked users, press to expand or collapse the list';

  @override
  String a11yInvitationTargetCard(String name) {
    return 'Invite $name';
  }

  @override
  String a11yPermissionsBanner(String description) {
    return 'Permission: $description';
  }

  @override
  String a11yCollaborativeBanner(String title, String subtitle) {
    return '$title, $subtitle';
  }

  @override
  String a11yEmojiPicker(String emoji) {
    return 'Select $emoji as icon';
  }

  @override
  String a11yRemoveIngredientChip(String label) {
    return 'Remove $label';
  }

  @override
  String get a11yToggleFullscreenChrome => 'Show or hide controls';

  @override
  String get a11yCommentsToggle => 'Comments';

  @override
  String a11yShowSubstitutionsFor(String ingredient) {
    return 'Show substitutions for $ingredient';
  }

  @override
  String a11yToggleStepDone(int step) {
    return 'Mark step $step as done or undone';
  }

  @override
  String get a11yRemoveOwnRating => 'Remove my rating';

  @override
  String a11yPickTime(String label, String time) {
    return 'Pick $label: current time $time';
  }

  @override
  String a11yCookingStepLongPressTimer(int step) {
    return 'Step $step, long-press to start timer';
  }

  @override
  String a11yStartTimerForPhrase(String phrase) {
    return 'Start timer: $phrase';
  }

  @override
  String get a11yArchivedConversationsToggle => 'Archived conversations';

  @override
  String get a11yRecipeImageFullscreen => 'Show recipe image in fullscreen';

  @override
  String a11yHeroButton(String tooltip) {
    return '$tooltip';
  }

  @override
  String get a11yDismissParseQualityWarning => 'Dismiss import quality warning';

  @override
  String a11yToggleShoppingCategory(String category) {
    return 'Category $category';
  }

  @override
  String get a11yToggleEmptyCategories => 'Other categories';

  @override
  String a11yWeeklyMenuViewModeToggle(String label) {
    return '$label';
  }

  @override
  String a11yPollVoteOption(String label) {
    return 'Vote for $label';
  }

  @override
  String a11yPollRecipeThumbnail(String title) {
    return 'Open recipe $title';
  }

  @override
  String get a11yPingComposeSend => 'Send ping';

  @override
  String get cookingModeSubstitutionApplied => 'Ingredient swapped';

  @override
  String get cookingModeSubstitutionFailed =>
      'Couldn\'t swap ingredient. Please try again.';

  @override
  String get cookingModeOpenEditToSwap => 'Open edit mode to swap';

  @override
  String get feedbackEmailHint => 'you@email.com';

  @override
  String get mfaPhoneHint => '+46 70 123 45 67';

  @override
  String get dialogEmailLabel => 'Email';

  @override
  String get dialogEmailHint => 'you@email.com';

  @override
  String get dialogUrlLabel => 'URL';

  @override
  String get dialogUrlHint => 'https://example.com';

  @override
  String get itemTypeRecipe => 'recipe';

  @override
  String get itemTypeGroup => 'group';

  @override
  String get itemTypeShoppingList => 'shopping list';

  @override
  String get unnamedSharedList => '(Unnamed list)';

  @override
  String get parseConfidenceTitle => 'Parse quality per ingredient';

  @override
  String parseConfidenceReviewCountSubtitle(int count) {
    final intl.NumberFormat countNumberFormat =
        intl.NumberFormat.decimalPattern(localeName);
    final String countString = countNumberFormat.format(count);

    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$countString may need a check',
      one: '1 may need a check',
    );
    return '$_temp0';
  }

  @override
  String parseConfidenceOriginalPrefix(String line) {
    return 'Original: $line';
  }

  @override
  String get a11yToggleConfidenceSection => 'Show parse quality per ingredient';

  @override
  String a11yIngredientWithConfidence(String name, String confidence) {
    return '$name, $confidence';
  }

  @override
  String get a11yConfidenceHigh => 'high parse quality';

  @override
  String get a11yConfidenceMedium => 'medium parse quality';

  @override
  String get a11yConfidenceLow => 'low parse quality';

  @override
  String get a11yConfidenceFailed => 'unknown parse quality';

  @override
  String get recipeRelatedSectionTitle => 'Related recipes';

  @override
  String get recipeUsedInSectionTitle => 'Used in';

  @override
  String get recipeRelatedLinkButton => '+ Link related recipe';

  @override
  String get recipeRelatedPickerTitle => 'Select related recipes';

  @override
  String get recipeRelatedLinkSuccess => 'Recipe linked';

  @override
  String get recipeRelatedUnlinkSuccess => 'Link removed';

  @override
  String get recipeRelatedLinkError => 'Could not link recipe';

  @override
  String get recipeRelatedUnlinkError => 'Could not remove link';

  @override
  String a11yRelatedRecipeChip(String title) {
    return 'Linked recipe: $title';
  }

  @override
  String a11yRemoveRelatedRecipe(String title) {
    return 'Remove link to $title';
  }

  @override
  String a11yRelatedRecipeThumbnail(String title) {
    return 'Open related recipe: $title';
  }
}
