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
  String get commonYes => 'Yes';

  @override
  String get commonNo => 'No';

  @override
  String get commonRetry => 'Retry';

  @override
  String get stateSuccessDefault => 'Done';

  @override
  String get a11yBlockGroupMember => 'Block';

  @override
  String get a11yRequiredFieldSuffix => 'Required';

  @override
  String get maintenanceModeTitle => 'Maintenance mode';

  @override
  String get maintenanceModeDefaultMessage =>
      'We\'re making a quick update. Please try again shortly.';

  @override
  String get commonLoading => 'Loading …';

  @override
  String get commonDeleting => 'Deleting …';

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
  String get shoppingItemName => 'Item name';

  @override
  String get shoppingAmount => 'Amount';

  @override
  String get shoppingUnit => 'Unit';

  @override
  String get shoppingCategory => 'Category';

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
  String get authPasswordChoose => 'Choose a strong password';

  @override
  String get passwordRuleHint =>
      'At least twelve characters, or three words you remember. The rule stands here, not as an error after you have typed.';

  @override
  String get guestUpgradeNameHint => 'What should we call you?';

  @override
  String get authResetPasswordInstructions =>
      'Enter your email address and we\'ll send you instructions to reset your password.';

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
  String get a11yPantrySelectItem => 'Select';

  @override
  String slotSpillHeading(int placed, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      placed,
      locale: localeName,
      other: '$placed places',
      one: 'One place',
      zero: 'No free places',
    );
    String _temp1 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return '$_temp0, $_temp1';
  }

  @override
  String slotSpillBody(int rest, int week, String names) {
    String _temp0 = intl.Intl.pluralLogic(
      rest,
      locale: localeName,
      other:
          '$rest recipes do not fit in week $week: $names. Choose what happens to them, then we will write.',
      one:
          'One recipe does not fit in week $week: $names. Choose what happens to it, then we will write.',
    );
    return '$_temp0';
  }

  @override
  String slotSpillNextWeek(int placed, int rest, int week) {
    return 'Add $placed now, $rest in week $week';
  }

  @override
  String slotSpillAllNextWeek(int week) {
    return 'Add all in week $week';
  }

  @override
  String get slotSpillChooseMore => 'Choose more places';

  @override
  String slotSpillPlaceOnly(int placed) {
    String _temp0 = intl.Intl.pluralLogic(
      placed,
      locale: localeName,
      other: 'Add only those $placed',
      one: 'Add only the first',
    );
    return '$_temp0';
  }

  @override
  String bulkAddToMenuSuccessTwoWeeks(int added, int next, int week) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added recipes',
      one: '1 recipe',
    );
    return '$_temp0 this week, $next in week $week';
  }

  @override
  String bulkAddToMenuNextWeekFailed(int added, int week) {
    String _temp0 = intl.Intl.pluralLogic(
      added,
      locale: localeName,
      other: '$added recipes added',
      one: '1 recipe added',
    );
    return '$_temp0 this week. The rest could not be added to week $week.';
  }

  @override
  String get slotPickerDialogTitle => 'Pick a place in the menu';

  @override
  String get slotPickerPreviousWeek => 'Previous week';

  @override
  String get slotPickerNextWeek => 'Next week';

  @override
  String slotPickerWeekLabel(int week) {
    return 'week $week';
  }

  @override
  String slotPickerConfirmCount(int count) {
    return 'Add ($count)';
  }

  @override
  String a11ySlotPickerCell(String slot) {
    return 'Pick $slot';
  }

  @override
  String recipeAddedToMenuSlots(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recipe added to $count places in the weekly menu',
      one: 'Recipe added to 1 place in the weekly menu',
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
  String get menuPlacementTitle => 'Place in the week';

  @override
  String menuPlacementProgress(int placed, int total) {
    return '$placed of $total placed';
  }

  @override
  String menuPlacementTrayLabel(int count) {
    return '$count left to place';
  }

  @override
  String menuPlacementHint(String recipe) {
    return 'Tap a free place for $recipe. Lunch and dinner take one dish, other takes several.';
  }

  @override
  String get menuPlacementHintSelect =>
      'Select a dish below to place it. Lunch and dinner take one dish, other takes several.';

  @override
  String get menuPlacementAutoRest => 'Randomise the rest';

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
  String get a11yPlacementTrayCard => 'Select';

  @override
  String get a11yPlacementRemoveEntry => 'Remove from the cell';

  @override
  String get bulkAddToMenu => 'Add to weekly menu';

  @override
  String bulkAddToMenuSuccess(int count, String slot, String day) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes added',
      one: '1 recipe added',
    );
    return '$_temp0 to $slot $day';
  }

  @override
  String bulkAddToMenuOverflowed(int added, int requested) {
    return '$added of $requested added – the rest don\'t fit this week';
  }

  @override
  String bulkAddToMenuSuccessNextWeek(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes added',
      one: '1 recipe added',
    );
    return '$_temp0 to next week';
  }

  @override
  String bulkAddToMenuOverflowedTwoWeeks(int remaining) {
    String _temp0 = intl.Intl.pluralLogic(
      remaining,
      locale: localeName,
      other: '$remaining recipes',
      one: '1 recipe',
    );
    return 'The rest does not fit next week either – $_temp0 still without a place';
  }

  @override
  String get bulkExport => 'Export selected';

  @override
  String get bulkExportCopyClipboard => 'Copy to clipboard';

  @override
  String get bulkExportShareFile => 'Share as file';

  @override
  String bulkExportCopied(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return '$_temp0 copied to clipboard';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '1 image',
    );
    return 'Select up to $_temp0';
  }

  @override
  String validationFieldRequired(String fieldName) {
    return '$fieldName is required';
  }

  @override
  String validationFieldTooShort(String fieldName, int minLength) {
    String _temp0 = intl.Intl.pluralLogic(
      minLength,
      locale: localeName,
      other: '$minLength characters',
      one: '1 character',
    );
    return '$fieldName must be at least $_temp0';
  }

  @override
  String validationFieldTooLong(String fieldName, int maxLength) {
    String _temp0 = intl.Intl.pluralLogic(
      maxLength,
      locale: localeName,
      other: '$maxLength characters',
      one: '1 character',
    );
    return '$fieldName cannot exceed $_temp0';
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
  String get validationInvalidAmount => 'Invalid amount';

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
  String get errorPageNotFound => 'The page could not be found';

  @override
  String get errorBackToStart => 'Back to start';

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
  String get errorCouldNotUpdateSearchability =>
      'Search visibility could not be updated. Please try again.';

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
  String get nounFriends => 'friends';

  @override
  String get nounFriendList => 'friend list';

  @override
  String groupInvitationMessage(String groupName) {
    return 'An invitation to the group $groupName has arrived.';
  }

  @override
  String uploadTimeIn(String duration) {
    return ' in $duration';
  }

  @override
  String get autoSaveEnabled => 'Auto-save enabled';

  @override
  String get autoSaveFailed => 'The draft could not be saved.';

  @override
  String get autoSaveFailedPreserved =>
      'What you wrote is still here. Tap Save to save the recipe.';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends selected',
      one: '1 friend selected',
    );
    return '$_temp0';
  }

  @override
  String sharePartialSuccessSingular(int newCount) {
    return '1 person is already a member. Inviting $newCount new.';
  }

  @override
  String sharePartialSuccessPlural(int existingCount, int newCount) {
    String _temp0 = intl.Intl.pluralLogic(
      existingCount,
      locale: localeName,
      other: '$existingCount people are already members',
      one: '1 person is already a member',
    );
    String _temp1 = intl.Intl.pluralLogic(
      newCount,
      locale: localeName,
      other: '$newCount new',
      one: '1 new',
    );
    return '$_temp0. Inviting $_temp1.';
  }

  @override
  String get nounShoppingList => 'shopping list';

  @override
  String errorWithContext(String action, String error) {
    return 'Problem while $action. Try again.';
  }

  @override
  String successItemCreated(String itemType) {
    return '$itemType has been added.';
  }

  @override
  String successItemUpdated(String itemType) {
    return '$itemType has been updated.';
  }

  @override
  String successItemDeleted(String itemType) {
    return '$itemType has been deleted.';
  }

  @override
  String successItemAdded(String itemName) {
    return '$itemName has been added.';
  }

  @override
  String confirmDeleteItem(String itemName) {
    return 'Confirmation required: delete “$itemName”?';
  }

  @override
  String get confirmUnsavedChanges =>
      'Unsaved changes remain. Depart without saving?';

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
  String get draftCouldNotRestore =>
      'Couldn\'t restore draft. Starting with an empty form.';

  @override
  String get draftRestoring => 'Restoring draft …';

  @override
  String get draftUnnamedRecipe => 'Unnamed recipe';

  @override
  String draftFieldsFilledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields',
      one: '1 field',
    );
    return '$_temp0 filled';
  }

  @override
  String draftRestoredWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields',
      one: '1 field',
    );
    return 'Draft restored – $_temp0 loaded.';
  }

  @override
  String get emptyNoResults => 'No results found.';

  @override
  String emptyNoRecipesSubtitle(String addButton) {
    return 'The first recipe is added via “$addButton”.';
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
      'Create your first category to organise your friends';

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
      'Create a group to share weekly menus and shopping lists with friends or the household. Everyone sees the same plan and can tick off items as they go.';

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
  String get recipeEdit => 'Edit recipe';

  @override
  String get recipeDelete => 'Delete recipe';

  @override
  String get recipeDeleting => 'Deleting the recipe …';

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
  String get messagingLoadingConversations => 'Loading conversations …';

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
  String get messagingLeave => 'Leave';

  @override
  String get messagingDeleteConversationConfirm =>
      'All messages in the conversation will be lost.';

  @override
  String messagingConversationDeleted(String title) {
    return 'Conversation “$title” deleted';
  }

  @override
  String messagingConfirmLeaveGroup(String groupName) {
    return 'Are you sure you want to leave “$groupName”?';
  }

  @override
  String get profileLogout => 'Sign out';

  @override
  String get profileLogoutConfirm => 'Are you sure you want to sign out?';

  @override
  String get profileDeleteAccount => 'Delete account permanently';

  @override
  String get profileDeleteWarningTitle => 'This will happen:';

  @override
  String get profileDeleteWarningRecipes => 'Delete all your recipes';

  @override
  String get profileDeleteWarningMenus => 'Delete all your menus';

  @override
  String get profileDeleteWarningShoppingLists =>
      'Delete all your shopping lists';

  @override
  String get profileDeleteWarningFriends => 'Delete all friends and messages';

  @override
  String get profileDeleteWarningSharedContent => 'Delete all shared content';

  @override
  String get profileDeleteIrreversible =>
      'The deletion becomes final after 7 days.';

  @override
  String get profileDeleteConfirmButton => 'I understand, delete my account';

  @override
  String get profileConfirmWithPassword => 'Confirm with password';

  @override
  String get profileEnterPasswordToConfirm =>
      'Enter your password to continue.';

  @override
  String get profilePassword => 'Password';

  @override
  String get profileConfirm => 'Confirm';

  @override
  String get profileError => 'Error';

  @override
  String get chatBlockGroupMemberEmpty => 'There is no one else to block here';

  @override
  String get chatBlockGroupMemberTitle => 'Who do you want to block?';

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
  String get chatWriteYourMessage => 'Write your message …';

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
  String get chatCheckOutRecipe => 'Do take a look at this recipe.';

  @override
  String get chatCouldNotShareRecipe => 'Couldn\'t share recipe';

  @override
  String get chatCouldNotShareMenu => 'Couldn\'t share menu';

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
    return 'Weekly menu week $weekNum';
  }

  @override
  String get chatCheckOutMenu => 'Do take a look at my weekly menu.';

  @override
  String get chatNoMenuForWeek => 'No menu for that week';

  @override
  String get chatSelectShoppingList => 'Choose a shopping list';

  @override
  String get chatCheckOutShoppingList => 'Do take a look at my shopping list.';

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
  String get chatLoadingImage => 'Loading image …';

  @override
  String get chatImageSent => 'Image sent.';

  @override
  String get chatNoImageSelected => 'No image selected';

  @override
  String get chatCouldNotSharePhoto => 'Couldn\'t share photo';

  @override
  String get chatDeleteMessage => 'Delete message';

  @override
  String get statusConnecting => 'Connecting …';

  @override
  String get statusSyncing => 'Syncing …';

  @override
  String get statusSaving => 'Saving …';

  @override
  String get statusCreating => 'Creating …';

  @override
  String get accessibilityBackButton => 'Back';

  @override
  String get unitMinutesShort => 'min';

  @override
  String get unitHoursShort => 'h';

  @override
  String get dialogErrorTitle => 'An error occurred';

  @override
  String get dialogLoading => 'Loading …';

  @override
  String get recipePortionAbbreviation => 'srv';

  @override
  String get recipePortionSingular => 'serving';

  @override
  String get recipePortionsPlural => 'servings';

  @override
  String get recipeCookedToday => 'Cooked today';

  @override
  String recipeCookedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Cooked $count times',
      one: 'Cooked once',
    );
    return '$_temp0';
  }

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
  String get recipeAnalyzing => 'Analysing …';

  @override
  String get recipeAnalysisFailedA11y => 'Ingredient analysis failed';

  @override
  String get recipeAnalyzingA11y => 'Ingredients being analysed';

  @override
  String get recipeAllergensUnassessed => 'Allergens not assessed';

  @override
  String get recipeAllergensUnassessedA11y =>
      'Allergens have not been assessed for this recipe';

  @override
  String get recipeSearchHint => 'Search recipes …';

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
    String _temp0 = intl.Intl.pluralLogic(
      to,
      locale: localeName,
      other: '$to servings',
      one: '1 serving',
    );
    return 'Scaled from $from to $_temp0';
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
  String get voicePromptStart => 'Speak your weekly menu';

  @override
  String get voicePromptStop => 'Done, interpret what you said';

  @override
  String get voicePromptTranscribing => 'Interpreting what you said';

  @override
  String get voicePromptPreparing =>
      'Preparing the voice feature, fetching the Swedish speech model';

  @override
  String get voicePromptFailed =>
      'Your voice couldn\'t be interpreted this time. Typing works just as well';

  @override
  String get voiceUnavailable =>
      'The voice feature isn\'t available right now. Typing works just as well';

  @override
  String get voiceSearchStart => 'Speak your search';

  @override
  String get voiceCommentStart => 'Speak a comment';

  @override
  String get voiceSearchMicRationaleTitle => 'Microphone for search';

  @override
  String get voiceCommentMicRationaleTitle => 'Microphone for comments';

  @override
  String get voiceMicRationaleBody =>
      'Butlery uses the microphone so you can speak instead of typing. The audio is interpreted directly on your phone and never sent anywhere.';

  @override
  String get voiceAssistUnavailable =>
      'The voice feature isn\'t available right now';

  @override
  String get voicePromptMicRationaleTitle => 'Microphone for the weekly menu';

  @override
  String get voicePromptMicRationaleBody =>
      'Butlery uses the microphone so you can speak your weekly menu. The audio is interpreted directly on your phone and never sent anywhere.';

  @override
  String get voicePromptMicGrant => 'Allow';

  @override
  String get voicePromptMicPermanentlyDenied =>
      'The microphone is turned off for Butlery. It can be enabled in settings';

  @override
  String get voicePromptOpenSettings => 'Open settings';

  @override
  String get voiceImportTitle => 'Speak in a recipe';

  @override
  String get voiceImportIntro =>
      'Dictate the recipe in three parts, in any order. The text can always be edited before the recipe is imported';

  @override
  String get voiceImportSectionTitle => 'Dish name';

  @override
  String get voiceImportSectionIngredients => 'Ingredients';

  @override
  String get voiceImportSectionSteps => 'Instructions';

  @override
  String get voiceImportPromptTitle => 'What is the dish called?';

  @override
  String get voiceImportPromptIngredients =>
      'Read out the ingredients, one at a time';

  @override
  String get voiceImportPromptSteps => 'Describe how it\'s made';

  @override
  String get voiceImportTypeHint => 'Or type here';

  @override
  String get voiceImportSubmit => 'Import the recipe';

  @override
  String get voiceImportImporting => 'Importing …';

  @override
  String get voiceImportSubmitHint =>
      'The button unlocks when all three parts have text';

  @override
  String get voiceImportFailed =>
      'The recipe couldn\'t be interpreted this time. The text can be adjusted and tried again';

  @override
  String get voiceImportMicRationaleTitle => 'Microphone for recipe dictation';

  @override
  String get recipeVoiceImport => 'Speak in a recipe';

  @override
  String voiceAssistStepPrefix(int step, int total) {
    return 'Step $step of $total. ';
  }

  @override
  String get voiceAssistNoNextStep =>
      'There is no next step. The recipe is done';

  @override
  String get voiceAssistNoPreviousStep => 'This is the first step';

  @override
  String get voiceAssistNoIngredients => 'The ingredient list is empty';

  @override
  String voiceAssistTimerStarted(String duration) {
    return 'Timer $duration started';
  }

  @override
  String get voiceAssistNoTimers => 'No timer is running';

  @override
  String voiceAssistSubstitutions(String ingredient, String suggestions) {
    return '$ingredient can be replaced with: $suggestions';
  }

  @override
  String voiceAssistNoSubstitutions(String ingredient) {
    return 'We found no substitutes for $ingredient';
  }

  @override
  String voiceAssistQuantityNotFound(String ingredient) {
    return 'We could not find $ingredient among the ingredients';
  }

  @override
  String voiceAssistStepOutOfRange(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count steps',
      one: '1 step',
    );
    return 'The recipe has $_temp0';
  }

  @override
  String get voiceAssistRatioHalf => 'half the amount';

  @override
  String get voiceAssistRatioDouble => 'double the amount';

  @override
  String get voiceAssistRatioOneAndHalf => 'one and a half times the amount';

  @override
  String voiceAssistRatioTimes(String ratio) {
    return '$ratio times the amount';
  }

  @override
  String voiceAssistTimeLeft(String duration) {
    return '$duration left';
  }

  @override
  String get voiceAssistMissed =>
      'We did not catch that. Try saying next, or read it again';

  @override
  String get voiceAssistMissedTwice =>
      'We did not catch that this time either. The buttons work as usual';

  @override
  String voiceAssistHours(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n hours',
      one: '1 hour',
    );
    return '$_temp0';
  }

  @override
  String voiceAssistMinutes(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String voiceAssistSeconds(int n) {
    String _temp0 = intl.Intl.pluralLogic(
      n,
      locale: localeName,
      other: '$n seconds',
      one: '1 second',
    );
    return '$_temp0';
  }

  @override
  String get voiceAssistAnd => 'and';

  @override
  String get voiceAssistWindowHint => 'Say a command …';

  @override
  String voiceAssistHeard(String text) {
    return 'Heard: $text';
  }

  @override
  String get voiceAssistMicTooltip => 'Talk to the kitchen butler';

  @override
  String get voiceAssistMuteTooltip => 'Mute readouts';

  @override
  String get voiceAssistUnmuteTooltip => 'Unmute readouts';

  @override
  String get voiceAssistMicRationaleTitle =>
      'Microphone for the kitchen butler';

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
  String menuHiddenByFamilyAllergies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes hidden due to household allergies',
      one: '1 recipe hidden due to household allergies',
    );
    return '$_temp0';
  }

  @override
  String menuHiddenByOwnAllergies(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes hidden due to your allergen choices',
      one: '1 recipe hidden due to your allergen choices',
    );
    return '$_temp0';
  }

  @override
  String get menuAllergenUnknownChip => 'Allergens not checked';

  @override
  String get menuNoMoreRecipes => 'No more recipes available for swap';

  @override
  String get menuGenerateError => 'Could not generate menu';

  @override
  String menuWeekBadgeWithCount(int week, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dishes',
      one: '1 dish',
    );
    return 'Week $week · $_temp0';
  }

  @override
  String get menuToShoppingList => 'To shopping list';

  @override
  String menuGeneratedShoppingListName(int week) {
    return 'Shopping list week $week';
  }

  @override
  String get menuShoppingListGenerationEmpty =>
      'This week\'s plan has no recipes with ingredients yet';

  @override
  String get menuShoppingListGenerationFailed =>
      'The shopping list could not be created.';

  @override
  String get menuShoppingScaledToPresence => 'Amounts follow who\'s home';

  @override
  String get menuLoadSaved => 'Load saved menu';

  @override
  String get menuClear => 'Clear menu';

  @override
  String get menuShared => 'Weekly menu shared.';

  @override
  String get menuGeneratingOverlay => 'Generating your weekly menu …';

  @override
  String get menuGeneratingSubtitle =>
      'Finding recipes that match your preferences';

  @override
  String get commonSort => 'Sort';

  @override
  String get commonHide => 'Hide';

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
  String get syncComplete => 'Sync complete.';

  @override
  String syncFailed(String error) {
    return 'Syncing failed. Your changes are still on the phone. Try again.';
  }

  @override
  String get offlineShowingLocal => 'Offline mode – showing local recipes';

  @override
  String get recipeCreateCopy => 'Create copy';

  @override
  String recipeDuplicateTitle(String title) {
    return '$title (copy)';
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
  String get recipeSourceTypeVoiceDictation => 'Spoken recipe';

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
      'The source was saved a long time ago – a fresh extraction may differ from the original.';

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
    return '$name removed.';
  }

  @override
  String shoppingItemRemoveError(String name) {
    return 'Could not remove $name';
  }

  @override
  String get shoppingAllUnchecked => 'All items unchecked.';

  @override
  String get shoppingNoListForRename => 'No list selected for renaming';

  @override
  String get shoppingNoListForDelete => 'No list selected for deletion';

  @override
  String get commonBack => 'Back';

  @override
  String commonBackTo(String destination) {
    return 'Back to $destination';
  }

  @override
  String get commonEnable => 'Enable';

  @override
  String get commonDisable => 'Disable';

  @override
  String get commonName => 'Name';

  @override
  String get commonErrorOccurred => 'An error occurred';

  @override
  String get commonContinue => 'Continue';

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
  String get settingsHouseholdSizeTitle => 'Household size';

  @override
  String get settingsHouseholdSizeHint =>
      'Recipes open pre-set to this many portions. Portion choices on a recipe always take precedence.';

  @override
  String get householdSizeRecipeDefault => 'Recipe default';

  @override
  String get householdSizeUseRecipeDefault => 'Use recipe default';

  @override
  String get householdAllergenFilterTitle =>
      'Filter the menu for the whole household';

  @override
  String get householdAllergenFilterSubtitleOn =>
      'The weekly menu accounts for everyone in the household\'s allergies and diet.';

  @override
  String get householdAllergenFilterSubtitleOff =>
      'The menu currently accounts for only your own allergies.';

  @override
  String get householdAllergenOffTitle => 'Turn off the household filter?';

  @override
  String householdAllergenOffBody(String allergens) {
    return 'Then the weekly menu is planned from your own allergies only. A recipe with $allergens – which someone in the household, including a child, needs to avoid – can then be planned into the menu. The filter can be turned back on at any time.';
  }

  @override
  String get householdAllergenOffBodyGeneric =>
      'Then the weekly menu is planned from your own allergies only. A recipe that someone else in the household – including a child – needs to avoid can then be planned into the menu. The filter can be turned back on at any time.';

  @override
  String get householdAllergenRosterIncomplete =>
      'We could not read everyone in the household just now, so the list of allergies may be incomplete.';

  @override
  String get householdAllergenShareTitle =>
      'Share my allergies with the household';

  @override
  String get householdAllergenShareSubtitleOff =>
      'The household is guessing on your behalf';

  @override
  String get householdAllergenShareSubtitleOn =>
      'The household\'s menu accounts for your allergies';

  @override
  String get householdAllergenShareConfirmTitle => 'Share your allergy list';

  @override
  String get householdAllergenShareConfirmBody =>
      'Your household can see the allergies and dietary choices you have entered, so the weekly menu can be planned around them. Today Butlery guesses on your behalf – it assumes four common allergies and misses the rest.\n\nEveryone in the household sees the list, including anyone who joins later.\n\nIt is shown as one combined list for the whole household. Nobody sees which allergy belongs to whom.\n\nDietary choices count as a requirement when the menu is planned: if you share “vegan”, the whole household\'s menu is planned vegan.\n\nYou can stop sharing at any time. The list is removed immediately and the menu goes back to being cautious on your behalf.';

  @override
  String get householdAllergenShareConfirmAction => 'Share';

  @override
  String get householdAllergenShareStopped =>
      'Your allergy list is no longer shared. The menu is cautious on your behalf again.';

  @override
  String get householdAllergenShareSettingsUnread =>
      'We could not read your own allergy settings. Check your connection and try again.';

  @override
  String get householdAllergenShareFailed =>
      'Could not change sharing just now. Please try again.';

  @override
  String get commonTurnOff => 'Turn off';

  @override
  String get commonListAnd => 'and';

  @override
  String get settingsSaveFailed => 'Couldn\'t save. Please try again.';

  @override
  String get a11yDecreaseHouseholdSize => 'Decrease household size';

  @override
  String get a11yIncreaseHouseholdSize => 'Increase household size';

  @override
  String get settingsSectionNotifications => 'Notifications';

  @override
  String get settingsLanguageTitle => 'Language';

  @override
  String get commonLogoutNow => 'Sign out now';

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
  String get personalTagsViewTitle => 'Personal tags';

  @override
  String get personalTagCreateTag => 'Create tag';

  @override
  String get personalTagCreateGroup => 'Create group';

  @override
  String get personalTagEmptyTitle => 'No personal tags';

  @override
  String get personalTagEmptySubtitle => 'Create tags to organise your recipes';

  @override
  String get personalTagSectionTags => 'Tags';

  @override
  String get personalTagDeleteGroup => 'Delete group';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rules',
      one: '1 rule',
    );
    return '$_temp0';
  }

  @override
  String personalTagRuleCountActive(int enabled, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'rules',
      one: 'rule',
    );
    return '$enabled of $total $_temp0 on';
  }

  @override
  String get personalTagNoUsage => 'Not used';

  @override
  String get personalTagEnableAllRules => 'Enable all rules';

  @override
  String get personalTagDisableAllRules => 'Disable all rules';

  @override
  String get personalTagMoveToGroup => 'Move to group';

  @override
  String get personalTagEnableAllRulesConfirm => 'Enable all rules?';

  @override
  String get personalTagDisableAllRulesConfirm => 'Disable all rules?';

  @override
  String personalTagEnableAllRulesMessage(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count rules for “$name” will be enabled.',
      one: 'The rule for “$name” will be enabled.',
    );
    return '$_temp0';
  }

  @override
  String personalTagDisableAllRulesMessage(int count, String name) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count rules for “$name” will be disabled.',
      one: 'The rule for “$name” will be disabled.',
    );
    return '$_temp0';
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
  String get personalTagNameHint => 'E.g. Favourites';

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
  String personalTagDeleteTagMessageWithCount(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'It will be untagged from $count recipes.',
      one: 'It will be untagged from 1 recipe.',
      zero: 'No recipes will be affected.',
    );
    return 'Are you sure you want to delete “$name”? $_temp0';
  }

  @override
  String get personalTagMergeAction => 'Merge';

  @override
  String get personalTagMergeTitle => 'Merge tags';

  @override
  String personalTagMergeMessage(int count, String target) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count tags will be merged into “$target”. The others are removed and their recipes are moved.',
      two:
          '2 tags will be merged into “$target”. The other is removed and its recipes are moved.',
    );
    return '$_temp0';
  }

  @override
  String get personalTagMergeKeepLabel => 'Keep this tag:';

  @override
  String get personalTagMergeConfirm => 'Merge';

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
  String get personalTagDeleteGroupConfirm => 'Delete the group?';

  @override
  String personalTagDeleteGroupMessage(String name) {
    return 'Are you sure you want to delete “$name”? Tags in the group will be ungrouped.';
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
  String get tagDetailDefaultTitle => 'Tag';

  @override
  String get tagDetailNotFound => 'Tag could not be found';

  @override
  String get tagDetailEditTitle => 'Edit tag';

  @override
  String get tagDetailNameHint => 'Tag name';

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
  String get tagDetailDeleteRuleConfirm => 'Delete the rule?';

  @override
  String tagDetailDeleteRuleMessage(String name) {
    return 'Do you want to delete “$name”?';
  }

  @override
  String get tagDetailRuleDeleted => 'Rule deleted';

  @override
  String get tagDetailCouldNotDeleteRule => 'Could not delete rule';

  @override
  String get tagDetailApplyingRules => 'Applying rules to recipes …';

  @override
  String tagDetailRulesAppliedSuccess(int tagsApplied, int recipesModified) {
    String _temp0 = intl.Intl.pluralLogic(
      tagsApplied,
      locale: localeName,
      other: '$tagsApplied tags',
      one: '1 tag',
    );
    String _temp1 = intl.Intl.pluralLogic(
      recipesModified,
      locale: localeName,
      other: '$recipesModified recipes',
      one: '1 recipe',
    );
    return '$_temp0 applied to $_temp1';
  }

  @override
  String get tagDetailNoRecipesMatched => 'No recipes matched the rules';

  @override
  String get tagDetailCouldNotApplyRules => 'Could not apply rules';

  @override
  String get tagDetailDeleteTagConfirm => 'Delete the tag?';

  @override
  String get tagDetailDeleted => 'Tag deleted';

  @override
  String get tagDetailCouldNotDelete => 'Could not delete tag';

  @override
  String get tagDetailRuleCalculating => 'Calculating …';

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
  String get tagDetailRuleOperatorAnd => ' and ';

  @override
  String get tagDetailRuleOperatorOr => ' or ';

  @override
  String tagDetailRuleMoreConditions(int count) {
    return '(+$count more)';
  }

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
  String get tagWriteTagHint => 'Write a tag …';

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
      'Want bought items added to your pantry automatically when you check them off? You can change this later in App settings.';

  @override
  String get pantryAutoAddPromptEnable => 'Yes, add automatically';

  @override
  String get pantryAutoAddPromptDecline => 'Not now';

  @override
  String get allergenDisplayTitle => 'Display on';

  @override
  String get allergenDisplayOnCardsTitle => 'Recipe cards';

  @override
  String get allergenDisplayOnCardsSubtitle =>
      'Show allergen status on recipe cards in lists';

  @override
  String get allergenDisplayOnDetailTitle => 'Recipe details';

  @override
  String get allergenDisplayOnDetailSubtitle =>
      'Show complete allergen status on recipe page';

  @override
  String get allergenDisplayCoverageSubtitle =>
      'Show what proportion of ingredients are known';

  @override
  String get allergenSaveSettings => 'Save settings';

  @override
  String get allergenResetToDefaults => 'Reset to defaults';

  @override
  String get allergenSettingsSaved => 'Settings saved';

  @override
  String get allergenReset => 'Reset';

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
  String get ruleEditTitle => 'Edit rule';

  @override
  String get ruleCreateTitle => 'Create rule';

  @override
  String get ruleNewTitle => 'New rule';

  @override
  String get ruleNameLabel => 'Rule name';

  @override
  String get ruleNameHint => 'E.g. “Fish recipes”';

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
  String get ruleConditionsLabel => 'Conditions';

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
  String get ruleSelectProperty => 'Select property …';

  @override
  String get ruleAllConditionsNeedValue => 'All conditions must have a value';

  @override
  String get ruleHintIngredient => 'E.g. “chicken”, “salmon”';

  @override
  String get ruleHintProperty => 'E.g. “seafood”, “meat”, “dairy”';

  @override
  String get ruleHintKeyword => 'E.g. “quick”, “vegetarian”';

  @override
  String get ruleHintSourceUrl => 'E.g. “bbc.com”, “reddit.com”';

  @override
  String get ruleHintCuisine => 'E.g. “italian”, “asian”';

  @override
  String get ruleHintDietary => 'E.g. “vegetarian”, “vegan”';

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
  String get ruleHintOwnership => 'E.g. “personal”, “shared”, “collaborative”';

  @override
  String get ruleHintHasImage => 'true or false';

  @override
  String get ruleHintCompleteness => 'E.g. “description”, “ingredients”';

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
  String rulePropertyRetired(String property) {
    return '$property – no longer valid';
  }

  @override
  String get tagResultNoAllergens => 'No allergens to display';

  @override
  String get tagResultOutdated => 'Tags can be updated';

  @override
  String get tagResultCoverage => 'Coverage';

  @override
  String tagResultUnknownIngredients(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unknown ingredients',
      one: '1 unknown ingredient',
    );
    return '$_temp0';
  }

  @override
  String tagResultUnknownIngredientsA11y(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unknown ingredients',
      one: '1 unknown ingredient',
    );
    return '$_temp0';
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
    return '$name: not checked';
  }

  @override
  String dietaryStatusNotLabel(String name) {
    return 'Not $name';
  }

  @override
  String dietaryStatusUnknownLabel(String name) {
    return '$name: not checked';
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
    return '$name: not checked';
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
    return '$name: not checked';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return 'Largest category: $name ($_temp0)';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count total members',
      one: '1 total member',
    );
    return '$_temp0';
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
    String _temp1 = intl.Intl.pluralLogic(
      friends,
      locale: localeName,
      other: '$friends friends',
      one: '1 friend',
    );
    return '$_temp0 ($_temp1)';
  }

  @override
  String friendCategoriesSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count categories selected',
      one: '1 category selected',
    );
    return '$_temp0';
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
      'Loading friends and categories …';

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
  String get shoppingItems => 'items';

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
    return 'To “$name” ($count)';
  }

  @override
  String get shoppingLists => 'Shopping lists';

  @override
  String get shoppingNewList => 'New list';

  @override
  String shoppingNewListNameTemplate(String title) {
    return '$title – Ingredients';
  }

  @override
  String shoppingListCreated(String name) {
    return 'List “$name” created';
  }

  @override
  String get profileEditProfile => 'Edit profile';

  @override
  String get profileSharedWithMe => 'Shared with me';

  @override
  String get profileDownloadBackup => 'Download backup';

  @override
  String get profileRestoreFromBackup => 'Restore from backup';

  @override
  String get profilePrivacyPolicy => 'Privacy policy';

  @override
  String profileBackupFailed(String error) {
    return 'The backup could not be created. Your recipes are untouched. Try again.';
  }

  @override
  String get profileBackupNotSaved => 'The backup could not be saved.';

  @override
  String get profileBackupRecipesKept => 'Your recipes are still in the app.';

  @override
  String get profileRestoreNotRead => 'The backup could not be read.';

  @override
  String get profileRestoreNothingRemoved => 'No recipes were deleted.';

  @override
  String get profileRestoreCompleted => 'Restore completed.';

  @override
  String profileRestoreFailed(String error) {
    return 'The restore failed. Nothing has changed. Try again.';
  }

  @override
  String get shareRecipeTitle => 'Share recipe';

  @override
  String get shareMenuTitle => 'Share menu';

  @override
  String get shareShoppingListTitle => 'SHOPPING LIST';

  @override
  String get shareCreateAndShare => 'Create and share';

  @override
  String get shareRecipeWithFriends => 'Share recipe with friends';

  @override
  String get shareMenuWithFriends => 'Share weekly menu with friends';

  @override
  String get shareShoppingList => 'Share shopping list';

  @override
  String get shareTagWithFriends => 'Share tag with friends';

  @override
  String get shareTag => 'Share tag';

  @override
  String get shareSelectAtLeastOneFriend => 'Choose who to share with.';

  @override
  String shareRecipesInCategories(int recipes, int categories) {
    String _temp0 = intl.Intl.pluralLogic(
      recipes,
      locale: localeName,
      other: '$recipes recipes',
      one: '1 recipe',
    );
    String _temp1 = intl.Intl.pluralLogic(
      categories,
      locale: localeName,
      other: '$categories categories',
      one: '1 category',
    );
    return '$_temp0 in $_temp1';
  }

  @override
  String get shareNoFriendsToShareWith => 'No friends to share with';

  @override
  String get shareAddFriendsToShare =>
      'You need to add friends to be able to share content. Go to your profile and add friends.';

  @override
  String get shareAddFriends => 'Add friends';

  @override
  String get shareSucceeded => 'Sharing complete.';

  @override
  String get shareMessageOptional => 'Message (optional)';

  @override
  String get shareWriteMessage => 'Write a message …';

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
  String get shareSearchFriends => 'Search friends …';

  @override
  String get shareSearchGroups => 'Search groups …';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return 'Shared recipe · $_temp0';
  }

  @override
  String socialSharedMenuMembers(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return 'Shared menu · $_temp0';
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
  String get socialLoadingCategories => 'Loading categories …';

  @override
  String get socialInvertLabel => 'Invert';

  @override
  String get invitationNoTargetsAvailable => 'No targets available';

  @override
  String get invitationSearchTargets => 'Search targets …';

  @override
  String get invitationSelectedTargets => 'Selected targets';

  @override
  String invitationTargetsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count targets selected',
      one: '1 target selected',
    );
    return '$_temp0';
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
  String get invitationView => 'View';

  @override
  String get invitationSendInvitation => 'Send invitation';

  @override
  String get invitationInvite => 'Invite';

  @override
  String get invitationLoadingTargets => 'Loading targets …';

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
  String get invitationTargetsLoaded => 'Targets loaded.';

  @override
  String get invitationNoSearchResults => 'No search results';

  @override
  String invitationNoResultsFor(String query) {
    return 'No results for “$query”';
  }

  @override
  String invitationTargetsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count targets selected',
      one: '1 target selected',
    );
    return '$_temp0';
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
  String get commonDiscard => 'Discard';

  @override
  String get commonFailed => 'Failed';

  @override
  String get commonImporting => 'Importing …';

  @override
  String get commonPending => 'Pending';

  @override
  String get commonRefresh => 'Refresh';

  @override
  String get commonRemove => 'Remove';

  @override
  String get commonSending => 'Sending …';

  @override
  String get commonUndo => 'Undo';

  @override
  String get commonUploading => 'Uploading …';

  @override
  String get authLogIn => 'Sign in';

  @override
  String get collaborativeListNoAccess =>
      'The list may have been deleted or you no longer have access';

  @override
  String get collaborativeListNotFound => 'List not found';

  @override
  String get collaborativeLoadingSharedList => 'Loading shared list …';

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
  String get a11yCommentImageThumbnail => 'View attached image full screen';

  @override
  String get a11yCommentRemoveSelectedImage => 'Remove selected image';

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
    return 'We could not save. Try again.';
  }

  @override
  String get dialogCreateNewListForIngredients =>
      'Create a new list for these ingredients';

  @override
  String get dialogDietaryProperties => 'Dietary properties:';

  @override
  String get dialogEnterListName => 'Enter a name for the list';

  @override
  String dialogFilteredRecipeCount(int filtered, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total recipes',
      one: '1 recipe',
    );
    return '$filtered of $_temp0';
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
  String get dialogLoadingRecipes => 'Loading recipes …';

  @override
  String get dialogManualImport => 'Manual import';

  @override
  String get dialogMarkIngredientsYourself => 'Mark ingredients yourself';

  @override
  String get dialogMayTakeAWhile => 'This may take a while …';

  @override
  String get dialogNameMinTwoChars => 'Name must be at least 2 characters';

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
  String get dialogPrivate => 'Private';

  @override
  String dialogRetryInHours(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return 'Try again in $_temp0';
  }

  @override
  String dialogRetryInMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'Try again in $_temp0';
  }

  @override
  String dialogRetryInSeconds(int seconds) {
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'Try again in $_temp0';
  }

  @override
  String get dialogRetryLater => 'Try later';

  @override
  String get dialogRetryTomorrow => 'Try again tomorrow';

  @override
  String get dialogSearchRecipes => 'Search recipes …';

  @override
  String get dialogSearchRecipesToAdd => 'Search recipes to add …';

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
  String get dialogSharing => 'Sharing …';

  @override
  String get dialogShoppingListNameHint => 'E.g. “Pancakes – Ingredients”';

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
  String get draftDiscardAll => 'Discard all';

  @override
  String get groupContentTypeContent => 'Content';

  @override
  String get groupContentTypeMenu => 'Menu';

  @override
  String get groupContentTypeRecipe => 'Recipe';

  @override
  String get groupContentTypeShoppingList => 'Shopping list';

  @override
  String get groupCouldNotFetchMenu => 'Could not fetch menu from server';

  @override
  String get groupCouldNotFetchRecipe => 'Could not fetch recipe from server';

  @override
  String get groupCreateNew => 'Create new group';

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
  String get groupImport => 'Import';

  @override
  String groupImportingMenuComingSoon(String title) {
    return 'Importing menu: $title (coming soon)';
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
  String get groupInvitationNote =>
      'These friends will receive an invitation to the group.';

  @override
  String get groupIsEmpty => 'The group is empty';

  @override
  String get groupNameHint => 'E.g. “Family”, “Work”, “Book club”';

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
    return 'You are the only member in “$name”.';
  }

  @override
  String groupRecipeImportedSuccess(String title) {
    return 'Recipe “$title” imported successfully';
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
  String groupSharedBy(String name) {
    return 'Shared by $name';
  }

  @override
  String get groupSharedContent => 'Shared in the group';

  @override
  String groupShoppingListViewComingSoon(String title) {
    return 'Shopping list view: $title (coming soon)';
  }

  @override
  String get groupTransferOwnership => 'Transfer group ownership';

  @override
  String groupTransferOwnershipMessage(String name) {
    return 'You are the owner of “$name”. You must select a new owner before you can leave the group.';
  }

  @override
  String get groupView => 'View';

  @override
  String groupViewNotImplemented(String title) {
    return 'View $title (not yet implemented)';
  }

  @override
  String get profileExportData => 'Export my data';

  @override
  String get profileExportDataSubtitle =>
      'Download all your data in JSON format (GDPR)';

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
      'Do you want to continue your session or sign out now?';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends selected',
      one: '1 friend selected',
    );
    return '$_temp0';
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
  String shareSuccessMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return 'Shared with $_temp0.';
  }

  @override
  String shareSuccessMessageGroups(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipients',
      one: '1 recipient',
    );
    return 'Shared with $_temp0.';
  }

  @override
  String get shareSuccessLiveNote => 'Changes are visible to everyone.';

  @override
  String get uploadFailed => 'Image upload failed';

  @override
  String uploadFailedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images could not be uploaded.',
      one: '1 image could not be uploaded.',
    );
    return '$_temp0\n\nWhat do you want to do?';
  }

  @override
  String get uploadInProgress => 'Image upload in progress';

  @override
  String uploadMixedStatus(int failedCount, int pendingCount) {
    return 'Some images could not be uploaded ($failedCount) and others are still uploading ($pendingCount).\n\nWhat do you want to do?';
  }

  @override
  String uploadPendingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images are still uploading.',
      one: '1 image is still uploading.',
    );
    return '$_temp0\n\nWhat do you want to do?';
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
  String get consentDataProcessing => 'Data processing';

  @override
  String get consentAnalytics => 'Analytics';

  @override
  String get consentAnalyticsDescription =>
      'How the app is used, never what you cook.';

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
  String get consentPushNotifications => 'Push notifications';

  @override
  String get consentPushNotificationsDescription =>
      'The system\'s permission is set separately, in the settings.';

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
  String get dataExportGdprDescription =>
      'You have the right to get your data in a format that can be read and moved. The file is JSON.';

  @override
  String get dataExportExporting => 'Exporting your data …';

  @override
  String get dataExportMayTakeSeconds => 'This may take a few seconds';

  @override
  String get dataExportFailed => 'Export failed';

  @override
  String get dataExportSaveFile => 'Save file';

  @override
  String get dataExportClear => 'Clear export';

  @override
  String get dataExportWhatsIncluded => 'What comes with it';

  @override
  String get dataExportIncludesProfile => 'Profile and settings';

  @override
  String get dataExportIncludesLists => 'Shopping lists and menus';

  @override
  String get dataExportIncludesAuditLogs =>
      'Security and access history (GDPR Article 15)';

  @override
  String get dataExportSharedDataNote =>
      'Note: The export contains your own data. For what you share with others, such as shared shopping lists, conversations and notifications, it also includes some details about them, such as names or user IDs.';

  @override
  String get dateToday => 'Today';

  @override
  String get dateYesterday => 'Yesterday';

  @override
  String dateDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0 ago';
  }

  @override
  String dateWeeksAgo(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks',
      one: '1 week',
    );
    return '$_temp0 ago';
  }

  @override
  String dateMonthsAgo(int months) {
    String _temp0 = intl.Intl.pluralLogic(
      months,
      locale: localeName,
      other: '$months months',
      one: '1 month',
    );
    return '$_temp0 ago';
  }

  @override
  String get friendDecline => 'Decline';

  @override
  String get friendRequestTitle => 'Friend request';

  @override
  String imageAddCount(int count) {
    return 'Add ($count)';
  }

  @override
  String get imageAddImages => 'Add images';

  @override
  String get imageAdding => 'Adding …';

  @override
  String get imageAddingImage => 'Adding image …';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '1 image',
    );
    return 'Tap to add up to $_temp0';
  }

  @override
  String get imageTapToLoad => 'Tap to load';

  @override
  String get imageUploadingImages => 'Uploading images';

  @override
  String get imageUploadPreparing => 'Preparing …';

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
  String get importFieldsNeedReviewPrefix => 'Review';

  @override
  String menuCardMoreRecipes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more recipes',
      one: '1 more recipe',
    );
    return '+ $_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return 'Shared with $_temp0';
  }

  @override
  String get searchHint => 'Search …';

  @override
  String get searchNothingYet => 'Nothing to search yet';

  @override
  String shareFriendsSelectedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends selected',
      one: '1 friend selected',
    );
    return '$_temp0';
  }

  @override
  String shareGroupMembersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return '$_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more items',
      one: '1 more item',
    );
    return '+ $_temp0';
  }

  @override
  String get shoppingCardNoItems => 'No items on list';

  @override
  String get shoppingCardSharedList => 'Shared list';

  @override
  String shoppingCardSharedWithCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return 'Shared with $_temp0';
  }

  @override
  String get adminYouAreAdmin => 'You are an administrator';

  @override
  String get chatMute => 'Mute';

  @override
  String chatParticipantCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0';
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
    return 'The file could not be saved. Try again.';
  }

  @override
  String dataExportCouldNotShare(String error) {
    return 'The file could not be shared. Try again.';
  }

  @override
  String get dataExportExportedSuccessfully => 'Data exported successfully';

  @override
  String dataExportFileSaved(String fileName) {
    return 'File saved: $fileName';
  }

  @override
  String get dataExportShareSubject => 'Butlery data export';

  @override
  String get dataExportShareText => 'My exported data from the Butlery app';

  @override
  String get dialogAmountHint => 'Enter amount …';

  @override
  String get dialogAmountInvalid => 'Invalid amount';

  @override
  String get dialogAmountLabel => 'Amount';

  @override
  String dialogAmountMax(String max) {
    return 'Maximum $max allowed';
  }

  @override
  String dialogAmountMin(String min) {
    return 'Minimum $min required';
  }

  @override
  String get dialogAmountRequired => 'Amount is required';

  @override
  String get dialogDescriptionHint => 'Optional description …';

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
  String get importLikely => 'Likely';

  @override
  String get importAiSuggested => 'Butlery\'s suggestion';

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
  String get importStepAnalyzing => 'Analysing …';

  @override
  String get importStepCreating => 'Creating …';

  @override
  String get importStepFetching => 'Fetching …';

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
  String menuDefaultName(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return 'Weekly menu ($_temp0)';
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
  String get menuNameHint => 'E.g. “My weekly menu week 45”';

  @override
  String get menuNameYourMenu => 'Name your menu';

  @override
  String get menuShareDefaultMessage => 'Do take a look at my weekly menu.';

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
  String messagingCouldNotLoadFriends(String error) {
    return 'Your friends could not be loaded. Try again.';
  }

  @override
  String messagingCouldNotLoadGroupInfo(String error) {
    return 'The group information could not be loaded. Try again.';
  }

  @override
  String get messagingCouldNotRemoveMember => 'Could not remove member';

  @override
  String get messagingCouldNotUpdateGroupName => 'Could not update group name';

  @override
  String get messagingEditGroupName => 'Edit group name';

  @override
  String get messagingEnterNewGroupName => 'Enter new group name';

  @override
  String get messagingGroupCreated => 'Group conversation created.';

  @override
  String get messagingGroupName => 'Group name';

  @override
  String get messagingGroupNameHint => 'E.g. My family, Work, Best friends …';

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
  String get messagingLoadingFriends => 'Loading friends …';

  @override
  String get messagingLoadingGroupInfo => 'Loading group info …';

  @override
  String messagingMemberRemoved(String name) {
    return '$name removed from the group';
  }

  @override
  String get messagingNoFriendsAvailable => 'No friends available';

  @override
  String get messagingNoFriendsFound => 'No friends found';

  @override
  String get messagingSearchFriends => 'Search friends …';

  @override
  String get messagingSelectAtLeastTwoMembers =>
      'Select at least 2 members below';

  @override
  String messagingSelectedMembers(int count) {
    return 'Participants · $count selected';
  }

  @override
  String get messagingTryAnotherKeyword => 'Try another keyword';

  @override
  String get mfaEnterCode => 'Enter the verification code';

  @override
  String get mfaInvalidCode => 'Invalid code. Try again.';

  @override
  String get mfaSixDigitCode => '6-digit code';

  @override
  String get mfaTitle => 'Two-step verification';

  @override
  String get mfaVerificationFailed => 'Verification failed';

  @override
  String get mfaVerify => 'Verify';

  @override
  String get mfaAccountProtected =>
      'Your account is protected with two-step verification.';

  @override
  String get mfaActivated => 'Two-step verification is on.';

  @override
  String get mfaCouldNotRemove => 'Could not turn off two-step verification';

  @override
  String get mfaDeactivated => 'Two-step verification is off';

  @override
  String get mfaEnableForSecurity =>
      'Turn on two-step verification for extra security.';

  @override
  String mfaRegistered(String time) {
    return 'Registered $time';
  }

  @override
  String get mfaRegisteredMethods => 'Registered methods';

  @override
  String get mfaRemoveConfirm =>
      'Are you sure you want to switch off two-step verification? This makes your account less secure.';

  @override
  String get mfaRemoveTitle => 'Turn off two-step verification?';

  @override
  String get mfaRemoveAction => 'Remove two-step verification';

  @override
  String get realtimeOffline => 'Offline';

  @override
  String get recipeMealType => 'Meal type';

  @override
  String get recipeTitle => 'Title';

  @override
  String get recipeUpdating => 'Updating recipe …';

  @override
  String chatAddCount(int count) {
    return 'Add ($count)';
  }

  @override
  String get chatAddMembers => 'Add members';

  @override
  String get chatSearchFriends => 'Search friends …';

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
  String get collaborativeSyncAutomatic =>
      'Changes sync automatically with other participants';

  @override
  String get conversationAddFriendsFirst =>
      'Add friends first to start conversations.';

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
  String get conversationSayHi => 'Say hello.';

  @override
  String get conversationSelectFriendForDM =>
      'Or select a friend for direct message:';

  @override
  String get conversationYouPrefix => 'You:';

  @override
  String errorLoadingWithDetails(String error) {
    return 'We could not load this. Try again.';
  }

  @override
  String get errorUnknown => 'Unknown error';

  @override
  String get imageSelectImage => 'Select image';

  @override
  String get imageTitle => 'Image';

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
  String get importAllAlreadyHeld =>
      'You already have every recipe in the file';

  @override
  String importSkippedDuplicates(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes were already there and were skipped',
      one: '1 recipe was already there and was skipped',
    );
    return '$_temp0';
  }

  @override
  String importSkippedOverLimit(int count, int limit) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count more recipes',
      one: '1 more recipe',
    );
    return 'The file held $_temp0. At most $limit are imported at a time.';
  }

  @override
  String importComplete(int succeeded, int failed) {
    return 'Import complete: $succeeded succeeded, $failed failed';
  }

  @override
  String importFailedCount(int count) {
    return '$count failed';
  }

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
  String get importFromArchive => 'Import from Butlery\'s archive';

  @override
  String get importFromFile => 'Import from file';

  @override
  String get importFromFileTitle => 'Import recipes from CSV or Excel';

  @override
  String get importFromSocialMedia => 'From social media';

  @override
  String get importImporting => 'Importing …';

  @override
  String importImportingRecipes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return 'Importing $_temp0 …';
  }

  @override
  String get importImportingRecipesProgress => 'Importing recipes …';

  @override
  String get importWaitForCompletion =>
      'Please wait until the import is complete …';

  @override
  String get importNoFileOrNoRecipes =>
      'No file selected or the file contains no recipes';

  @override
  String get importNoRecipesMatchedFilters => 'No recipes matched the filters';

  @override
  String get importParsingText => 'Parsing text …';

  @override
  String get importPasteRecipeHint => 'Paste recipe text here …';

  @override
  String get importRecipesImported => 'Recipes imported.';

  @override
  String get importSearchArchive => 'Search archive …';

  @override
  String get importSelectFileAndImport => 'Select file and import';

  @override
  String get importSelectingFile => 'Selecting file …';

  @override
  String get importShowError => 'Show error';

  @override
  String importSucceededCount(int count) {
    return '$count succeeded';
  }

  @override
  String get importTryAdjustFilters => 'Try adjusting search or filters';

  @override
  String get indicatorOfflineMode => 'No connection';

  @override
  String offlineBannerPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting',
      one: '1 change waiting',
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
  String get indicatorBackOnline => 'Back online';

  @override
  String get householdToggle => 'This is the household';

  @override
  String get householdToggleDescription =>
      'The household\'s allergens count in the menu';

  @override
  String get householdJoinTitle => 'Join the household';

  @override
  String get householdJoinSubtitle =>
      'Then you can choose to share your allergies, so the menu accounts for them.';

  @override
  String get householdJoinAction => 'Join';

  @override
  String get householdJoinConfirmBody =>
      'You become a member of the household. Your allergies are not shared until you choose to in My household. You leave the household by leaving the group.';

  @override
  String get householdJoinFailed =>
      'Could not join the household just now. Please try again.';

  @override
  String get householdJoinedTitle => 'You are in the household';

  @override
  String get householdJoinedSubtitle =>
      'Share your allergies in My household, so the menu accounts for them.';

  @override
  String get householdOpenSettings => 'Show household';

  @override
  String get menuVoteSuggestAlternative => 'Suggest alternative';

  @override
  String get menuVoteResolved => 'Vote resolved';

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
  String get menuVoteQuestion => 'What will it be?';

  @override
  String menuVoteClosesInHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Closes in $count hours',
      one: 'Closes in 1 hour',
    );
    return '$_temp0';
  }

  @override
  String get menuVoteClosesSoon => 'Closes within an hour';

  @override
  String menuVoteLateOption(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Added late: $count had already voted',
      one: 'Added late: 1 had already voted',
    );
    return '$_temp0';
  }

  @override
  String get menuVoteProposeOther => 'Suggest something else';

  @override
  String get menuVoteDecide => 'Decide';

  @override
  String menuVoteDecideFor(String recipeName) {
    return 'Choose $recipeName';
  }

  @override
  String get menuVoteTieTitle => 'A tie, needs a decision';

  @override
  String get menuVoteTieStarterBody =>
      'The app does not pick a winner on a tie. You started the vote, so you choose.';

  @override
  String get menuVoteWaitingOnStarter =>
      'Waiting for the person who started the vote.';

  @override
  String get menuVoteGiveADay => 'Give it a day';

  @override
  String get menuVoteDecideAnyway => 'Decide anyway';

  @override
  String get menuVoteReopen => 'Open again';

  @override
  String get menuVoteRelease => 'Let the place go';

  @override
  String get menuVoteNobodyVoted => 'Nobody voted';

  @override
  String get menuVoteNobodyVotedBody =>
      'This is not a tie but a suggestion nobody took up. No dish is put in the place because of it.';

  @override
  String get menuVoteApplyFailed => 'The winner could not be added to the menu';

  @override
  String get menuVoteSaveFailed => 'The vote could not be saved';

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
    return 'Search: “$query”';
  }

  @override
  String get invitationSelectTargetsToContinue =>
      'Select targets from the list above to continue.';

  @override
  String get invitationSendingInvitations => 'Sending invitations …';

  @override
  String invitationsSentMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count targets',
      one: '1 target',
    );
    return 'Invitations have been sent to $_temp0.';
  }

  @override
  String get invitationsSentTitle => 'Invitations sent';

  @override
  String invitationTargetsSelectedForInvitation(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count targets',
      one: '1 target',
    );
    return 'You have selected $_temp0 for invitation.';
  }

  @override
  String get invitationTryDifferentSearch =>
      'Try searching with different words or check the spelling.';

  @override
  String get loadingNoContent => 'No content';

  @override
  String get menuCommentLabel => 'Comment (optional)';

  @override
  String menuDeletedSuccess(String name) {
    return 'Menu “$name” deleted';
  }

  @override
  String get menuDeleteFailed => 'Could not delete menu';

  @override
  String menuLoadedSuccess(String name) {
    return 'Menu “$name” loaded.';
  }

  @override
  String get menuLoadFailed => 'Could not load menu';

  @override
  String get menuNameLabel => 'Menu name';

  @override
  String get menuNameRequired => 'Menu name is required';

  @override
  String get menuNoSavedMenusDescription =>
      'No saved menus yet. A menu is generated and saved first.';

  @override
  String menuRecipesInCategories(int recipeCount, int categoryCount) {
    String _temp0 = intl.Intl.pluralLogic(
      recipeCount,
      locale: localeName,
      other: '$recipeCount recipes',
      one: '1 recipe',
    );
    String _temp1 = intl.Intl.pluralLogic(
      categoryCount,
      locale: localeName,
      other: '$categoryCount categories',
      one: '1 category',
    );
    return '$_temp0 in $_temp1';
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
  String get privacyCouldNotLoad => 'The privacy policy could not be loaded.';

  @override
  String get privacyTitle => 'Privacy policy';

  @override
  String get recipeAddTags => 'Add tags';

  @override
  String get recipeChangesSaved => 'Changes saved.';

  @override
  String get recipeContinueEditing => 'Continue editing';

  @override
  String get recipeCopySaved => 'The copy of the recipe has been saved.';

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
  String get recipeAddIngredientHeading => 'Add heading';

  @override
  String get recipeIngredientHeadingHint => 'Heading, e.g. Dough';

  @override
  String get a11yRemoveIngredientHeading => 'Remove heading';

  @override
  String get recipeMoveToSection => 'Move to heading';

  @override
  String get recipeMoveToSectionNone => 'No heading';

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
  String get socialTotalMembers => 'Total members';

  @override
  String get userNoUsers => 'No users';

  @override
  String get userNoUsersToShow => 'No users to show';

  @override
  String get chatCannotMessageNonFriend =>
      'You cannot send messages to this person';

  @override
  String get chatCouldNotSendMessage => 'Could not send the message.';

  @override
  String get chatSendFailedDeviceClockAhead =>
      'Could not send. Your phone\'s clock is too far ahead – check the date and time in settings.';

  @override
  String get chatLoadingMessages => 'Loading messages …';

  @override
  String get chatNoMessages => 'No messages yet';

  @override
  String get chatSendToStartConversation =>
      'Send a message to start the conversation';

  @override
  String get chatWriteMessage => 'Write a message …';

  @override
  String chatTypingOne(String name) {
    return '$name is typing';
  }

  @override
  String chatTypingTwo(String first, String second) {
    return '$first and $second are typing';
  }

  @override
  String chatTypingMany(String first, String second, int others) {
    String _temp0 = intl.Intl.pluralLogic(
      others,
      locale: localeName,
      other: '$others others',
      one: '1 other',
    );
    return '$first, $second and $_temp0 are typing';
  }

  @override
  String get commonOr => 'or';

  @override
  String get errorCouldNotLoadPage => 'Could not load the page';

  @override
  String get errorLoadingRetryOrGoBack =>
      'An error occurred while loading. Try again or go back.';

  @override
  String errorSavingWithDetails(String error) {
    return 'We could not save. Try again.';
  }

  @override
  String get errorTitle => 'Error';

  @override
  String errorOccurredWithDetails(String error) {
    return 'We could not complete this. Try again.';
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
  String get importChooseFromGallery => 'Choose from gallery';

  @override
  String importConfidenceTooltip(String label, int percentage) {
    return '$label: $percentage% confidence';
  }

  @override
  String get importContinueWithoutOcr => 'Continue without text recognition';

  @override
  String get importFromPhoto => 'Import from photo';

  @override
  String get importGoodQuality => 'Good quality';

  @override
  String get importHandwrittenToggle => 'This is a handwritten recipe';

  @override
  String get importHandwrittenToggleSubtitle =>
      'Uses AI to read handwriting. A little slower, and worth double-checking the result.';

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
  String get importManually => 'Import manually';

  @override
  String get importOcrMayFail =>
      'Text recognition may fail or give poor results.';

  @override
  String get importPasteFromClipboard => 'Paste from clipboard';

  @override
  String get importClipboardUrlDetected => 'Recipe URL found in clipboard';

  @override
  String get importClipboardUseUrl => 'Use';

  @override
  String get importPasteLinkOrText => 'Paste link or text here …';

  @override
  String get importAddManually => 'Write it yourself';

  @override
  String get importPhotoImport => 'Photo import';

  @override
  String get importProceedToEdit => 'Proceed to edit';

  @override
  String importMultipleRecipesFound(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return 'We found $_temp0';
  }

  @override
  String get importPhotoAddPage => 'Add page';

  @override
  String importPhotoPageLabel(int number) {
    return 'Page $number';
  }

  @override
  String importPhotoPagesCombined(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pages',
      one: '1 page',
    );
    return '$_temp0 combined into one recipe';
  }

  @override
  String importPhotoPagesMaxReached(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max pages',
      one: '1 page',
    );
    return 'Max $_temp0 per recipe';
  }

  @override
  String get shareImportUnreadable => 'Could not read the shared photo';

  @override
  String a11yRemovePhotoPage(int number) {
    return 'Remove page $number';
  }

  @override
  String get importProcessingImage => 'Processing image …';

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
  String get importTakePhoto => 'Take a photo';

  @override
  String get importUrlBatchAllFailed =>
      'None of the URLs could be fetched. Check the links and try again.';

  @override
  String get importMultipleUrlsLabel => 'Recipe URLs';

  @override
  String importUrlBatchProgress(int success, int total) {
    return '$success of $total fetched';
  }

  @override
  String get importVideoNoText => 'Video has no text';

  @override
  String get importVideoNoTextDescription =>
      'This video has no subtitles we can read.\n\nYou can take a screenshot of the recipe in the video and import it instead.';

  @override
  String get groupAddMembers => 'Add members';

  @override
  String groupAddToGroup(String group) {
    return 'Add to $group';
  }

  @override
  String get groupAlreadyMember => 'Already a member';

  @override
  String get groupAllFriendsAlreadyMembers =>
      'All your friends are already members of this group, or you have already sent invitations to them.';

  @override
  String get groupSharedContentLoadFailed =>
      'The shared content could not be loaded.';

  @override
  String get groupCouldNotLoadMembers => 'Could not load group members';

  @override
  String get groupRosterIncomplete =>
      'We could not load all group members. Please try again.';

  @override
  String get groupCouldNotTransferOwnership =>
      'Could not transfer ownership. Try again.';

  @override
  String groupHandOverNotInHousehold(String name) {
    return '$name is not in the group\'s household, so they cannot take over the group.';
  }

  @override
  String get groupHandOverUnavailable =>
      'The group cannot be handed over right now.';

  @override
  String groupDeleted(String name) {
    return 'Group “$name” has been deleted';
  }

  @override
  String get groupInvitationSent => 'Sent';

  @override
  String groupInvitationsSent(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations sent',
      one: '1 invitation sent',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitationsSentSuccess => 'Invitations have been sent.';

  @override
  String get groupLoadingInfo => 'Loading group information …';

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
  String groupSendInvitations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Invite $count selected',
      one: 'Invite 1 selected',
    );
    return '$_temp0';
  }

  @override
  String groupSharedFromGroup(String name) {
    return 'Shared from group $name';
  }

  @override
  String get groupUpdated => 'Group updated.';

  @override
  String get groupYouLeftGroup => 'You have left the group';

  @override
  String get loadingGeneric => 'Loading …';

  @override
  String get loadingRecipes => 'Loading recipes …';

  @override
  String get loadingAdminAccess => 'Checking your access …';

  @override
  String get loadingConsents => 'Loading your consents …';

  @override
  String get loadingFeedbackEntries => 'Loading feedback …';

  @override
  String get loadingImage => 'Loading the image …';

  @override
  String get loadingMetrics => 'Loading the metrics …';

  @override
  String get loadingReports => 'Loading the reports …';

  @override
  String get loadingOpsLog => 'Loading the operations log …';

  @override
  String get loadingParsingStats => 'Loading the parsing statistics …';

  @override
  String get loadingFamily => 'Loading your household …';

  @override
  String get loadingIngredientSearch => 'Searching ingredients …';

  @override
  String get loadingCommunityGuidelines => 'Loading the guidelines …';

  @override
  String get loadingTerms => 'Loading the terms of service …';

  @override
  String get loadingWeeklyMenu => 'Loading the weekly menu …';

  @override
  String get loadingNotifications => 'Loading your notifications …';

  @override
  String get loadingPersonalTags => 'Loading your tags …';

  @override
  String get loadingAllergenPreferences => 'Loading your allergy settings …';

  @override
  String get loadingMfaSettings => 'Loading two-step verification …';

  @override
  String get loadingMyReports => 'Loading your reports …';

  @override
  String get loadingNotificationPreferences =>
      'Loading your notification settings …';

  @override
  String get loadingTag => 'Loading the tag …';

  @override
  String get loadingShoppingList => 'Loading the shopping list …';

  @override
  String get loadingShoppingLists => 'Loading your shopping lists …';

  @override
  String get loadingGroupMembers => 'Loading the group\'s members …';

  @override
  String get loadingProfile => 'Loading the profile …';

  @override
  String get loadingPantry => 'Loading the pantry …';

  @override
  String get loadingSharedShoppingLists => 'Loading shared shopping lists …';

  @override
  String get loadingFeed => 'Loading the feed …';

  @override
  String menuConnectingCollaborative(String title) {
    return 'Connecting to “$title” for collaborative editing …';
  }

  @override
  String get menuCouldNotHide => 'Could not hide menu';

  @override
  String menuHiddenFromList(String title) {
    return '“$title” hidden from your list';
  }

  @override
  String menuHideConfirm(String title, String sharedBy) {
    return 'Would you like to hide “$title” from your list?\n\nYou can still access the menu by asking $sharedBy to share it again.';
  }

  @override
  String get menuHideMenu => 'Hide menu';

  @override
  String get menuImportAll => 'Save to my menus';

  @override
  String menuImportDescription(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'When you import the menu, all $count recipes will be added to your collection.',
      one:
          'When you import the menu, the recipe will be added to your collection.',
    );
    return '$_temp0';
  }

  @override
  String get menuImported => 'Menu imported';

  @override
  String menuImportedSuccess(String title) {
    return 'Menu “$title” imported.';
  }

  @override
  String get menuImportFailed => 'Import failed';

  @override
  String get menuNoRecipesInMenu => 'No recipes in the menu';

  @override
  String get menuShareMenu => 'Share menu';

  @override
  String menuSavedSuccess(String name) {
    return 'Menu “$name” saved.';
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
  String get permissionNoAccess => 'No access';

  @override
  String get permissionSaveAsNew => 'Save as new';

  @override
  String get permissionSaveChanges => 'Save changes';

  @override
  String get permissionSaveMyCopy => 'Save my copy';

  @override
  String get privacyCouldNotOpenEmail => 'Could not open email client';

  @override
  String get privacyGdprCompliant =>
      'This privacy policy complies with GDPR requirements';

  @override
  String get privacyLoading => 'Loading the privacy policy …';

  @override
  String get privacyNotAvailable => 'Privacy policy is not available';

  @override
  String get privacyReload => 'Reload';

  @override
  String get privacyShareActivityTitle => 'Show my activity in friends\' feed';

  @override
  String get privacyShareActivitySubtitle =>
      'When on, your friends see when you cook and share recipes, and when you nudge them.';

  @override
  String get privacyActivityTypesTitle => 'What\'s shared';

  @override
  String get privacyActivityTypeCooked => 'When I cook a recipe';

  @override
  String get privacyActivityTypeShared => 'When I share a recipe';

  @override
  String get privacyActivityTypeStartedCooking => 'When I start cooking';

  @override
  String get privacyActivityTypePinged => 'When I nudge a friend';

  @override
  String get profileAvatarRemoved => 'Avatar removed';

  @override
  String get profileAvatarUploaded => 'Avatar uploaded.';

  @override
  String get profileBio => 'About me';

  @override
  String get profileBioHint =>
      'Describe yourself as a cook (max 160 characters)';

  @override
  String get profileCouldNotSave => 'Could not save profile';

  @override
  String get profileCouldNotUploadAvatar => 'Could not upload avatar';

  @override
  String get profileCookingSkill => 'Skill level';

  @override
  String get profileCookingSkillAdvanced => 'Advanced';

  @override
  String get profileCookingSkillBeginner => 'Beginner';

  @override
  String get profileCookingSkillIntermediate => 'Intermediate';

  @override
  String get profileCuisineAffinities => 'Favourite cuisines';

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
  String profileLanguageChangedTo(String language) {
    return 'Language changed to $language';
  }

  @override
  String get profileLoading => 'Loading profile …';

  @override
  String get profileNewUser => 'New user';

  @override
  String get profilePrivacySettings => 'Privacy';

  @override
  String get profileResetChanges => 'Reset changes';

  @override
  String get profileSaved => 'Profile saved.';

  @override
  String get profileSaveProfile => 'Save changes';

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
  String get profileUploadingAvatar => 'Uploading avatar …';

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
  String get recipeCouldNotMarkAsCooked => 'Could not mark as cooked';

  @override
  String get recipeCouldNotOpenEditor => 'Could not open editor';

  @override
  String get recipeCouldNotShare => 'Could not share recipe';

  @override
  String get recipeDeleted => 'Recipe moved to the trash for 30 days';

  @override
  String get recipeMarkedAsCooked => 'Recipe marked as cooked today.';

  @override
  String get recipeAlreadyCookedToday => 'Already logged today';

  @override
  String get recipeShared => 'Recipe shared';

  @override
  String recipeImportedFrom(String sourceUrl) {
    return 'Imported from: $sourceUrl';
  }

  @override
  String get recipeSaved => 'Recipe saved.';

  @override
  String get recipeSavedTaggingFailed =>
      'Recipe saved, but tagging failed. Allergen information may be incomplete.';

  @override
  String recipeSavedWithTags(int tagCount, int coverage) {
    String _temp0 = intl.Intl.pluralLogic(
      tagCount,
      locale: localeName,
      other: '$tagCount tags',
      one: '1 tag',
    );
    return 'Recipe saved – $_temp0 ($coverage%).';
  }

  @override
  String get recipeSaveStartedDuringDialog =>
      'A save started during the dialog. Please wait while the recipe is saved …';

  @override
  String get recipeWaitWhileSaving => 'Please wait while the recipe is saved …';

  @override
  String get celebrationFirstRecipeTitle => 'The first recipe has been added.';

  @override
  String celebrationFirstRecipeMessage(String recipeTitle) {
    return '$recipeTitle has been saved. Butlery stands ready.';
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
  String get recipeSaving => 'Saving recipe …';

  @override
  String searchFiltersActive(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count filters active',
      one: '1 filter active',
    );
    return '$_temp0';
  }

  @override
  String get searchQuery => 'Search';

  @override
  String searchResults(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
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
      'Be the first to comment on this recipe.';

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
  String get socialCouldNotUpdateLike => 'Could not update like';

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
  String get socialLoadingComments => 'Loading comments …';

  @override
  String get socialMustBeLoggedInToComment =>
      'You must be signed in to comment';

  @override
  String get socialMustBeLoggedInToLike => 'You must be signed in to like';

  @override
  String get socialNoCommentsYet => 'No comments yet';

  @override
  String get socialSendMessage => 'Send message';

  @override
  String get socialUserProfileCreated => 'User profile created';

  @override
  String get shoppingAddToShoppingList => 'Add to shopping list';

  @override
  String get shoppingCouldNotAddIngredients =>
      'Could not add ingredients to the shopping list';

  @override
  String get shoppingCouldNotCreateOrSelectList =>
      'Could not create or select shopping list';

  @override
  String shoppingIngredientsFromRecipe(int count, String title) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ingredients',
      one: '1 ingredient',
    );
    return '$_temp0 from “$title”:';
  }

  @override
  String get shoppingNoEditPermission =>
      'You do not have permission to edit this shopping list';

  @override
  String get shoppingListChangedElsewhere =>
      'This list changed on another device – reload it and try again';

  @override
  String get shoppingNoEditPermissionShared =>
      'You do not have permission to edit this shared shopping list';

  @override
  String get shoppingNoIngredientsToAdd =>
      'The recipe has no ingredients to add';

  @override
  String get shoppingSelectList => 'Select shopping list';

  @override
  String get shoppingYourList => 'your shopping list';

  @override
  String get shoppingSharedLists => 'Shared shopping lists';

  @override
  String get sharedLoadingContent => 'Loading shared content …';

  @override
  String get sharedNoContentYet => 'No shared recipes yet';

  @override
  String get sharedEmptyStateExplanation =>
      'When you or your friends share recipes and menus, they\'ll appear here. A recipe can be shared to begin.';

  @override
  String get taggingAnalyzingIngredients => 'Analysing ingredients …';

  @override
  String get taggingCouldNotAnalyze => 'Could not analyse recipe';

  @override
  String get taggingCouldNotSaveTags => 'Could not save tags';

  @override
  String get taggingCreateTag => 'Create tag';

  @override
  String get taggingCreateTagsToOrganize =>
      'Create tags to organise your recipes';

  @override
  String taggingError(String error) {
    return 'Tagging failed. Try again.';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count personal tags saved',
      one: '1 personal tag saved',
    );
    return '$_temp0';
  }

  @override
  String taggingTagsGenerated(int count, int coverage) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags',
      one: '1 tag',
    );
    return '$_temp0 generated ($coverage% coverage)';
  }

  @override
  String taggingTagsSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tags selected',
      one: '1 tag selected',
    );
    return '$_temp0';
  }

  @override
  String taggingUpdateTagsMessage(String title) {
    return 'Analysing ingredients and updating allergen and dietary tags for “$title”.';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return 'Save $_temp0';
  }

  @override
  String importPreviewSubtitle(int ingredients, int steps) {
    String _temp0 = intl.Intl.pluralLogic(
      ingredients,
      locale: localeName,
      other: '$ingredients ingredients',
      one: '1 ingredient',
    );
    String _temp1 = intl.Intl.pluralLogic(
      steps,
      locale: localeName,
      other: '$steps steps',
      one: '1 step',
    );
    return '$_temp0 · $_temp1';
  }

  @override
  String importMergeSelected(int count) {
    return 'Merge selected ($count)';
  }

  @override
  String importMergedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return '$_temp0 merged into one';
  }

  @override
  String importPreviewUnreadLines(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lines could not be read. Tap to review the recipe.',
      one: '1 line could not be read. Tap to review the recipe.',
    );
    return '$_temp0';
  }

  @override
  String get importPreviewOpenedForReview => 'Opened for review';

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
  String get groupLoadingGroups => 'Loading groups …';

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
  String get groupCouldNotAcceptInvitation =>
      'Could not accept invitation. Please try again.';

  @override
  String get groupCreated => 'Created';

  @override
  String get groupViewMembers => 'View members';

  @override
  String get groupEditGroup => 'Edit group';

  @override
  String get groupInvitationAccepted =>
      'Invitation accepted. Welcome to the group.';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count people',
      one: '1 person',
    );
    return '$_temp0';
  }

  @override
  String get groupMembers => 'Members';

  @override
  String groupRemoveSelectedCount(int count) {
    return 'Remove selected ($count)';
  }

  @override
  String get groupNoMembersDescription =>
      'Add friends to this group to get started.';

  @override
  String get groupNoMembersYet => 'No members yet';

  @override
  String get groupSent => 'Sent';

  @override
  String get commonAccept => 'Accept';

  @override
  String get commonDecline => 'Decline';

  @override
  String shoppingItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get socialLoadingFriends => 'Loading friends …';

  @override
  String get socialNoFriendsYet => 'No friends yet';

  @override
  String get socialSearchForNewFriends => 'Search for new friends';

  @override
  String get socialSearchForNewFriendsDescription =>
      'Type a name or username in the search field above to find new friends.';

  @override
  String get socialSearchingUsers => 'Searching users …';

  @override
  String get socialSearchUnavailable =>
      'Search is unavailable right now. Please try again in a moment.';

  @override
  String get socialCouldNotAcceptFriendRequest =>
      'Could not accept friend request';

  @override
  String get socialCouldNotFindFriendRequest => 'Could not find friend request';

  @override
  String get socialCouldNotSendFriendRequest => 'Could not send friend request';

  @override
  String get socialDefaultFriendMessage =>
      'Hello. Would you like to be friends?';

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
  String get socialInviteSubject => 'An invitation to Butlery.';

  @override
  String get socialFriendRequestAccepted => 'Friend request accepted.';

  @override
  String socialFriendRequestAcceptedFrom(String name) {
    return 'Friend request from $name accepted.';
  }

  @override
  String get socialFriendRequestDeclined => 'Friend request declined';

  @override
  String socialFriendRequestSent(String name) {
    return 'Friend request sent to $name.';
  }

  @override
  String get socialNoFriendRequests => 'No friend requests';

  @override
  String get socialNoFriendRequestsDescription =>
      'Search for friends above to expand your network.';

  @override
  String get socialRequestSent => 'Sent';

  @override
  String get addRecipeTitle => 'Add recipe';

  @override
  String get authPassword => 'Password';

  @override
  String get authTagline => 'Recipes, menu and shopping in one place.';

  @override
  String get collaborativeAdd => 'Add';

  @override
  String get collaborativeAddFirstItem => 'Add the first item';

  @override
  String get collaborativeAdding => 'Adding …';

  @override
  String get collaborativeAddItemHint => 'Add item …';

  @override
  String get collaborativeClearAll => 'Clear all';

  @override
  String get collaborativeClearCompleted => 'Clear completed';

  @override
  String get collaborativeClearCompletedConfirm =>
      'Do you want to clear all completed items?';

  @override
  String collaborativeClearCompletedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completed items',
      one: '1 completed item',
    );
    return 'Do you want to clear $_temp0?';
  }

  @override
  String collaborativeCompletedItemsCleared(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count completed items cleared',
      one: '1 completed item cleared',
    );
    return '$_temp0';
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
  String get collaborativeLinkCopied => 'Link copied.';

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
  String get collaborativeShareList => 'Share list';

  @override
  String get collaborativeViewOnly => 'View only';

  @override
  String get collaborativeWaitingForOthers => 'Waiting for others …';

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
  String groupCancelInvitationMessage(String name) {
    return 'Do you want to cancel the invitation to $name?';
  }

  @override
  String get groupCreatedSuccess => 'Group created.';

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
  String get groupLeave => 'Leave';

  @override
  String groupLeaveGroupConfirm(String name) {
    return 'Do you want to leave the group $name?';
  }

  @override
  String get groupLeftGroup => 'You have left the group';

  @override
  String groupMemberRemoved(String name) {
    return '$name has been removed';
  }

  @override
  String groupRemoveMultipleConfirm(int count, String group) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return 'Remove $_temp0 from $group?';
  }

  @override
  String groupMembersRemoved(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members removed',
      one: '1 member removed',
    );
    return '$_temp0';
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
  String get sharedAlreadyMember => 'You are already a member';

  @override
  String get sharedContent => 'Shared content';

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
  String sharedNoRecipesFromFriend(String name) {
    return '$name hasn\'t shared any recipes with you yet';
  }

  @override
  String get sharedNoShoppingLists => 'No shared shopping lists';

  @override
  String get sharedNoShoppingListsDescription =>
      'Shopping lists shared with you will appear here';

  @override
  String get sharedSearchHint => 'Search shared content …';

  @override
  String sharedTabRecipes(int count) {
    return 'Recipes · $count';
  }

  @override
  String sharedTabMenus(int count) {
    return 'Menus · $count';
  }

  @override
  String sharedTabShoppingLists(int count) {
    return 'Lists · $count';
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
  String sharedConnectingToCollaborativeMenu(String title) {
    return 'Connecting to collaborative menu: $title';
  }

  @override
  String sharedContentHidden(String title) {
    return '$title has been hidden';
  }

  @override
  String sharedHideMenuConfirm(String title, String sharedBy) {
    return 'Do you want to hide the menu “$title” shared by $sharedBy?';
  }

  @override
  String sharedHideRecipeConfirm(String title, String sharedBy) {
    return 'Do you want to hide the recipe “$title” shared by $sharedBy?';
  }

  @override
  String sharedHideShoppingListConfirm(String name, String sharedBy) {
    return 'Do you want to hide the shopping list “$name” shared by $sharedBy?';
  }

  @override
  String sharedJoinedList(String name) {
    return 'Joined the list “$name”';
  }

  @override
  String sharedJoinedListFindInShopping(String name) {
    return 'Joined “$name”. Find it in Shopping Lists.';
  }

  @override
  String sharedMenuImported(String title) {
    return 'Menu “$title” has been imported';
  }

  @override
  String sharedRecipeImported(String title) {
    return 'Recipe “$title” has been imported';
  }

  @override
  String get shoppingAdminOwner => 'Admin/Owner';

  @override
  String get shoppingAdminOwnerDescription => 'Full access and management';

  @override
  String get shoppingAllFriendsAreMembers => 'All friends are already members';

  @override
  String get shoppingBy => 'By';

  @override
  String get shoppingCategoryHint => 'Select category …';

  @override
  String get shoppingClear => 'Clear';

  @override
  String get shoppingClearPurchasedTitle => 'Clear purchased items';

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
  String get shoppingCreateNewListHint => 'Name for new shopping list …';

  @override
  String get shoppingCreator => 'Creator';

  @override
  String get shoppingDeleteList => 'Delete list';

  @override
  String get shoppingDescriptionHint => 'Add a description …';

  @override
  String get shoppingDescriptionOptional => 'Description (optional)';

  @override
  String get shoppingItemNameHint => 'Item name …';

  @override
  String get shoppingJustNow => 'Just now';

  @override
  String get shoppingListInfo => 'List information';

  @override
  String get shoppingManageSharing => 'Manage sharing';

  @override
  String get shoppingNewNameHint => 'New name …';

  @override
  String get shoppingNoFriends => 'No friends';

  @override
  String get shoppingNoFriendsDescription =>
      'Add friends to share shopping lists';

  @override
  String get shoppingNoFriendsFound => 'No friends found';

  @override
  String get shoppingNoteHint => 'Add a note …';

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
  String get shoppingPurchasedCleared => 'Purchased items cleared';

  @override
  String get shoppingRecentActivity => 'Recent activity';

  @override
  String get shoppingRemoveMember => 'Remove member';

  @override
  String get shoppingSearchFriends => 'Search friends …';

  @override
  String get shoppingSharedList => 'Shared list';

  @override
  String get shoppingSharedListTitleHint => 'Name for shared list …';

  @override
  String get shoppingShareExternally => 'Share externally';

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
  String shoppingItemMoved(String category) {
    return 'Moved to $category';
  }

  @override
  String get shoppingUnitHint => 'Unit …';

  @override
  String get shoppingUnknownUser => 'Unknown user';

  @override
  String get shoppingWhen => 'When';

  @override
  String get shoppingYourPermission => 'Your permission';

  @override
  String shoppingBoughtCount(int count) {
    return 'Bought ($count)';
  }

  @override
  String get shoppingClearBought => 'Clear bought';

  @override
  String shoppingClearPurchasedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count purchased items',
      one: '1 purchased item',
    );
    return 'Do you want to clear $_temp0?';
  }

  @override
  String shoppingCouldNotAddItem(String name) {
    return 'Could not add $name';
  }

  @override
  String shoppingCouldNotLoadFriends(String error) {
    return 'Your friends could not be loaded. Try again.';
  }

  @override
  String shoppingCouldNotShowShareDialog(String error) {
    return 'Sharing could not be opened. Try again.';
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
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0 ago';
  }

  @override
  String shoppingDeleteListConfirm(String name) {
    return 'Do you want to delete the list “$name”?';
  }

  @override
  String shoppingDeleteListWithItemsConfirm(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return 'Do you want to delete the list “$name” with $_temp0?';
  }

  @override
  String shoppingErrorAdding(String error) {
    return 'The item could not be added. Try again.';
  }

  @override
  String shoppingErrorUpdating(String error) {
    return 'The item could not be updated. Try again.';
  }

  @override
  String shoppingHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$_temp0 ago';
  }

  @override
  String shoppingItemAdded(String itemName) {
    return 'Added “$itemName”';
  }

  @override
  String shoppingItemCountText(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String shoppingListDeleted(String name) {
    return 'List “$name” deleted';
  }

  @override
  String shoppingListRenamed(String name) {
    return 'List renamed to “$name”';
  }

  @override
  String shoppingMemberRemoved(String name) {
    return '$name has been removed';
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
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0 ago';
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
  String get socialBlock => 'Block';

  @override
  String get socialBlockUserConfirm => 'Do you want to block this user?';

  @override
  String get socialCancelAll => 'Cancel all';

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
  String socialUserBlockedCleanupIncomplete(String name) {
    return '$name is blocked. We did not finish clearing the friendship or a pending request.';
  }

  @override
  String get socialCouldNotCancelAllRequests => 'Could not cancel all requests';

  @override
  String get socialCouldNotRejectAllRequests => 'Could not reject all requests';

  @override
  String get socialCouldNotRemoveFriend => 'Could not remove friend';

  @override
  String get socialCouldNotUnblockUser => 'Could not unblock user';

  @override
  String get socialDecline => 'Decline';

  @override
  String get socialDeclined => 'Declined';

  @override
  String get socialExpired => 'Expired';

  @override
  String get socialFindFriends => 'Find friends';

  @override
  String get socialFriendsAndGroups => 'Friends & groups';

  @override
  String get socialGroups => 'Groups';

  @override
  String get socialLoadingRequests => 'Loading requests …';

  @override
  String get socialNoRequestsSelected => 'No requests selected';

  @override
  String get socialPendingResponse => 'Pending response';

  @override
  String get socialRejectAll => 'Reject all';

  @override
  String get socialRejectAllSelectedConfirm => 'Reject all selected requests?';

  @override
  String get socialRequestCancelled => 'Request cancelled';

  @override
  String get socialUnknownStatus => 'Unknown status';

  @override
  String get socialWantsToBeFriend => 'wants to be your friend';

  @override
  String socialAcceptAllSelectedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected requests',
      one: '1 selected request',
    );
    return 'Do you want to accept $_temp0?';
  }

  @override
  String socialAcceptCount(int count) {
    return 'Accept ($count)';
  }

  @override
  String get socialBlockUserStaysInGroup =>
      'They stay in the group, but you no longer see what they write.';

  @override
  String socialBlockUserMessage(String name) {
    return 'Do you want to block $name? They won\'t be able to see your profile or send requests, and they can no longer influence what you plan together. A friendship is removed and is not restored if you unblock them.';
  }

  @override
  String socialCancelCount(int count) {
    return 'Cancel ($count)';
  }

  @override
  String socialCancelSelectedRequestsMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected requests',
      one: '1 selected request',
    );
    return 'Do you want to cancel $_temp0?';
  }

  @override
  String socialDeclineCount(int count) {
    return 'Decline ($count)';
  }

  @override
  String socialRejectAllSelectedMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count selected requests',
      one: '1 selected request',
    );
    return 'Do you want to reject $_temp0?';
  }

  @override
  String socialRequestsAccepted(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests accepted',
      one: '1 request accepted',
    );
    return '$_temp0';
  }

  @override
  String socialRequestsCancelled(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests cancelled',
      one: '1 request cancelled',
    );
    return '$_temp0';
  }

  @override
  String socialRequestsRejected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count requests rejected',
      one: '1 request rejected',
    );
    return '$_temp0';
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
  String get authLogin => 'Sign in';

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
  String get authResetEmailSent => 'Email sent. Check your inbox.';

  @override
  String get authResetEmailFailed => 'Could not send email';

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
  String get imageSelectingImages => 'Selecting images …';

  @override
  String get imageTapToSelectOne => 'Tap to select an image';

  @override
  String get messagingCancelReply => 'Cancel reply';

  @override
  String get messagingImagePreview => 'Image';

  @override
  String get navigationMenu => 'Menu';

  @override
  String get navigationShopping => 'Shopping';

  @override
  String get recipeRecipe => 'Recipe';

  @override
  String get recipeSharedFromApp => 'Shared from another app';

  @override
  String commonDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0 ago';
  }

  @override
  String commonHoursAgo(int hours) {
    String _temp0 = intl.Intl.pluralLogic(
      hours,
      locale: localeName,
      other: '$hours hours',
      one: '1 hour',
    );
    return '$_temp0 ago';
  }

  @override
  String commonMinutesAgo(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0 ago';
  }

  @override
  String imageCountSelected(int count) {
    return '$count selected';
  }

  @override
  String imageSelectedCount(int count, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max images selected',
      one: '1 image selected',
    );
    return '$count of $_temp0';
  }

  @override
  String imageTapToSelectUpTo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count images',
      one: '1 image',
    );
    return 'Tap to select up to $_temp0';
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
  String socialLikeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count likes',
      one: '1 like',
    );
    return '$_temp0';
  }

  @override
  String socialLikesHeader(int count) {
    return 'Likes ($count)';
  }

  @override
  String get commonAdding => 'Adding …';

  @override
  String get a11yHidePassword => 'Hide password';

  @override
  String get a11yShowPassword => 'Show password';

  @override
  String get a11yLoading => 'Loading';

  @override
  String get a11yNavigationLandmark => 'Main navigation';

  @override
  String get a11yAddFriend => 'Add friend';

  @override
  String get a11yTagStatusInfo => 'More information';

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
  String get a11yShoppingItemChecked => 'Remove check';

  @override
  String get a11yShoppingItemUnchecked => 'Check off';

  @override
  String get a11yShoppingSelectItem => 'Select';

  @override
  String shoppingItemsRemovedUndoMessage(int count) {
    return '$count removed';
  }

  @override
  String get a11yPrimaryImageTap => 'Tap to view full size';

  @override
  String get a11ySelectAsPrimary => 'Select as primary image';

  @override
  String get a11yAddImage => 'Add image';

  @override
  String get a11yAddImageSlot => 'Image';

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
  String a11yImageOf(int current, int total) {
    return 'Image $current of $total';
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
  String get a11yEditComment => 'Edit comment';

  @override
  String get a11yDeleteComment => 'Delete comment';

  @override
  String get a11yReportComment => 'Report comment';

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
  String get a11yShoppingList => 'Shopping list';

  @override
  String get a11yFriend => 'Friend';

  @override
  String a11yFilterTag(String tagName) {
    return 'Filter by $tagName';
  }

  @override
  String a11yExcludeTag(String tagName) {
    return 'Exclude $tagName';
  }

  @override
  String get a11yAllergenStatusRow => 'Allergen status';

  @override
  String get a11yDietaryStatusRow => 'Dietary status';

  @override
  String get a11yShowImage => 'Show image';

  @override
  String get a11yShowMore => 'Show more';

  @override
  String a11yShoppingItemMoreOptions(String name) {
    return 'More options for $name';
  }

  @override
  String get a11yRemoveProfileImage => 'Remove profile image';

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
  String get filterSulfiteFree => 'Sulphite-free';

  @override
  String get filterPeanutFree => 'Peanut-free';

  @override
  String get filterTreeNutFree => 'Tree nut-free';

  @override
  String get filterAlcoholFree => 'Alcohol-free';

  @override
  String get onboardingAllergenCelery => 'Celery';

  @override
  String get onboardingAllergenMustard => 'Mustard';

  @override
  String get onboardingAllergenLupin => 'Lupin';

  @override
  String get onboardingAllergenSulfite => 'Sulphites';

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
  String get a11yConflictBannerDismiss => 'Dismiss conflict notification';

  @override
  String get a11yShoppingListUpdatedByDismiss => 'Dismiss notice';

  @override
  String get conflictBannerTitleRecipe => 'Two versions of the recipe';

  @override
  String get conflictBannerTitleWeek => 'Two versions of the week';

  @override
  String conflictBannerBody(String name) {
    return '$name changed it at the same time. Your version is still here – choose which one applies.';
  }

  @override
  String get conflictBannerBodyUnnamed =>
      'Someone else changed it at the same time. Your version is still here – choose which one applies.';

  @override
  String get conflictBannerBodyOtherDevice =>
      'You changed the recipe on another device. Your version is still here – choose which one applies.';

  @override
  String conflictWeekSaved(String name) {
    return '$name saved the week';
  }

  @override
  String get conflictWeekSavedUnnamed => 'Someone else saved the week';

  @override
  String get conflictWeekSavedElsewhere =>
      'The week was saved on another device';

  @override
  String get conflictDiffTitle => 'What changed';

  @override
  String get conflictDiffKeepMine => 'Keep my version';

  @override
  String get conflictDiffKeptToast => 'Your version was saved';

  @override
  String get conflictDiffKeepFailed => 'Couldn\'t save your version';

  @override
  String get conflictDiffNoChanges =>
      'No field changes to show – the versions are identical.';

  @override
  String get conflictDiffEmptyValue => '(empty)';

  @override
  String get privacyEmailSubject => 'Privacy inquiry';

  @override
  String get unshareRecipeTitle => 'Stop sharing recipe?';

  @override
  String unshareRecipeConfirm(String title) {
    return 'The recipe “$title” will be removed from all groups it was shared with.';
  }

  @override
  String get unshareMenuTitle => 'Stop sharing menu?';

  @override
  String unshareMenuConfirm(String title) {
    return 'The menu “$title” will be removed from all groups it was shared with.';
  }

  @override
  String get unshareShoppingListTitle => 'Stop sharing shopping list?';

  @override
  String unshareShoppingListConfirm(String name) {
    return 'The shopping list “$name” will be removed from all groups it was shared with.';
  }

  @override
  String get unshareButton => 'Stop sharing';

  @override
  String unshareSuccess(String title) {
    return '“$title” is no longer shared';
  }

  @override
  String get unshareFailed => 'Could not stop sharing. Try again.';

  @override
  String get favoritesAdd => 'Add to favourites';

  @override
  String get favoritesRemove => 'Remove from favourites';

  @override
  String get shoppingConvertToCollaborative => 'Make collaborative';

  @override
  String get shoppingConvertToPersonal => 'Make personal';

  @override
  String get shoppingConvertToCollaborativeTitle => 'Make collaborative list';

  @override
  String get shoppingConvertToCollaborativeDescription =>
      'Select friends to invite to this list. They join once they accept, and can then add and check off items in real time.';

  @override
  String get shoppingConvertToPersonalTitle => 'Make personal list';

  @override
  String get shoppingConvertToPersonalWarning =>
      'All collaborators will lose access to this list. Items will be kept.';

  @override
  String get shoppingConvertedToPersonal => 'List converted to personal';

  @override
  String get shoppingConvertError => 'Could not convert list';

  @override
  String get shoppingConvertIncompleteTitle =>
      'The conversion did not complete';

  @override
  String get shoppingConvertedOriginalKept =>
      'The list was copied, but the original is still there – check the new list and delete the original manually.';

  @override
  String get shoppingConvertedToPersonalOriginalKept =>
      'The list was copied to a personal list, but the shared list is still there – every member still has access to it. Delete the shared list manually if no one else should be able to reach it.';

  @override
  String get shoppingDescriptionLabel => 'Description (optional)';

  @override
  String get personalTagApplyRulesToAll => 'Apply rules to all recipes';

  @override
  String get messagingPinned => 'Pinned';

  @override
  String get messagingUnpin => 'Unpin';

  @override
  String get messagingPin => 'Pin';

  @override
  String get messagingArchive => 'Archive';

  @override
  String get messagingUnarchive => 'Unarchive';

  @override
  String get notificationSaveError => 'Could not save settings';

  @override
  String get notificationTitle => 'Notifications';

  @override
  String get notificationEnableTitle => 'Enable notifications';

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
  String get notificationDigestFrequencyNever => 'Never';

  @override
  String get notificationDigestFrequencyWeekly => 'Weekly';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars',
      one: '1 star',
    );
    return 'Rate $_temp0';
  }

  @override
  String get messagingSending => 'Sending …';

  @override
  String get messagingSent => 'Sent';

  @override
  String get messagingDelivered => 'Delivered';

  @override
  String get messagingRead => 'Read';

  @override
  String get messagingFailed => 'Failed';

  @override
  String get blockedUsersUnblockTitle => 'Unblock user?';

  @override
  String blockedUsersUnblockMessage(String name) {
    return 'Do you want to unblock $name?';
  }

  @override
  String get blockedUsersUnblock => 'Unblock';

  @override
  String get blockedUsersTitle => 'Blocked users';

  @override
  String get blockedUsersEmpty => 'No blocked users';

  @override
  String get blockedUsersSharesHiddenNote =>
      'Recipes, menus and shopping lists you have sent each other are hidden from both of you while the block lasts. Nothing is deleted.';

  @override
  String blockedUsersUnblockSelectedCount(int count) {
    return 'Unblock selected ($count)';
  }

  @override
  String get blockedUsersBulkUnblockTitle => 'Unblock selected?';

  @override
  String blockedUsersBulkUnblockMessage(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count users',
      one: '1 user',
    );
    return 'Do you want to unblock $_temp0?';
  }

  @override
  String blockedUsersBulkUnblockResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count users unblocked',
      one: '1 user unblocked',
    );
    return '$_temp0';
  }

  @override
  String blockedUsersBulkUnblockPartial(int succeeded, int total) {
    return '$succeeded of $total unblocked';
  }

  @override
  String get retagFetchingRecipes => 'Fetching recipes …';

  @override
  String get retagRetaggingRecipes => 'Retagging recipes …';

  @override
  String retagRetaggingProgress(int current, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total recipes',
      one: '1 recipe',
    );
    return 'Retagging $current of $_temp0 …';
  }

  @override
  String retagRecipesRetagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes retagged',
      one: '1 recipe retagged',
    );
    return '$_temp0';
  }

  @override
  String get filterFavorites => 'Favourites';

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
      'You won\'t set up allergies now. You can do it anytime in settings.';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingComplete => 'Done';

  @override
  String get onboardingAgeGateTitle => 'What year were you born?';

  @override
  String get onboardingAgeGateSubtitle =>
      'Butlery is for people aged 15 and over. We only ask for the year, not the date.';

  @override
  String get onboardingAgeGateBirthYearLabel => 'Birth year';

  @override
  String get onboardingAgeGateBirthYearHint => 'Choose a year';

  @override
  String get onboardingAgeGatePrivacyNote =>
      'The year is saved on your account. It is used for the age limit and is not visible to anyone else.';

  @override
  String get onboardingAgeGateTooYoungTitle => 'Butlery is for ages 15 and up';

  @override
  String get onboardingAgeGateTooYoungBody =>
      'We didn\'t choose this ourselves. Swedish law sets the limit for services with a social side, and Butlery has one.';

  @override
  String get onboardingAgeGateSignOut => 'Sign out';

  @override
  String get onboardingAgeGateParentOption => 'A grown-up can sign up for you';

  @override
  String get onboardingAgeGateParentInfoTitle => 'Ask a grown-up for help';

  @override
  String get onboardingAgeGateParentInfoBody =>
      'Ask a parent or guardian to create their own account and add you as a guest in the household. You need to be at least 15 to have your own account.';

  @override
  String get onboardingAgeRejectedTitle => 'We couldn\'t create your account';

  @override
  String get onboardingAgeRejectedBody =>
      'Butlery is available to those aged 15 and over. We\'re unable to create your account at this time.';

  @override
  String get onboardingWelcomeTitle => 'Welcome. We will run the week.';

  @override
  String get onboardingWelcomeDescription =>
      'Gather the recipes you already cook, and we will build the weekly menu and the shopping list from them.';

  @override
  String get onboardingWelcomeNote => 'Two questions left. Then you\'re in.';

  @override
  String get onboardingAllergenTitle => 'Anything you avoid?';

  @override
  String get onboardingAllergenDescription =>
      'Then we will filter it out of recipes, the menu and the shopping list. Always check the packaging as well.';

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
  String get onboardingSkippedBanner =>
      'You skipped the introduction. Want to set up allergens and dietary preferences?';

  @override
  String get onboardingSkippedBannerAction => 'Open settings';

  @override
  String get onboardingWelcomeBanner =>
      'Welcome to Butlery. You\'re all set – add your first recipe to get started.';

  @override
  String get onboardingWelcomeBannerAction => 'Add recipe';

  @override
  String get onboardingImportTitle => 'Bring a recipe you already cook';

  @override
  String get onboardingImportDescription =>
      'Paste a link. We will read it and you review it before anything is saved.';

  @override
  String get onboardingImportUrlTitle => 'Link to the recipe';

  @override
  String get onboardingImportPhotoTitle => 'Photograph a page';

  @override
  String get onboardingImportPhotoDescription =>
      'From a cookbook or a handwritten note';

  @override
  String get onboardingResumeTitle => 'Finish your profile';

  @override
  String get onboardingResumeBody => '30 seconds left';

  @override
  String get onboardingResumeCta => 'Continue';

  @override
  String get onboardingAgeGateParentTitle => 'An adult can create the account';

  @override
  String get onboardingAgeGateParentBody =>
      'A parent creates their own account and adds you as a guest in the household. Then meals are planned with you in mind.';

  @override
  String get onboardingAgeGateNothingSaved =>
      'The account you started creating is deleted. Nothing is saved.';

  @override
  String get onboardingWelcomeQuestionAllergens =>
      'What the household can\'t eat';

  @override
  String get onboardingWelcomeQuestionRecipe => 'A recipe you already cook';

  @override
  String get onboardingAllergenNote =>
      'This applies to you. You can add allergies for others in the household later. If you choose any, recipes with unknown allergen content are never planned automatically.';

  @override
  String onboardingShowAllAllergens(String kind, int count) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'other': 'Show $count more',
      },
    );
    return '$_temp0';
  }

  @override
  String get onboardingImportFromClipboard =>
      'Taken from your clipboard. Change it if it was the wrong link.';

  @override
  String onboardingImportSkipNote(String kind, int count) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'one':
            'If you skip, you get one starter recipe and a ready-made example week. You never start in an empty app.',
        'other':
            'If you skip, you get $count starter recipes and a ready-made example week. You never start in an empty app.',
      },
    );
    return '$_temp0';
  }

  @override
  String onboardingStepOf(int current, int total) {
    return 'Step $current of $total';
  }

  @override
  String get onboardingSetupTitle => 'We are setting the table';

  @override
  String get onboardingSetupBody =>
      'A few seconds. Then you have an app with something in it.';

  @override
  String get onboardingSetupSaving => 'Saving your allergens';

  @override
  String get onboardingSetupSaved => 'Allergens saved';

  @override
  String get onboardingSetupSavedNone => 'No allergens chosen';

  @override
  String get onboardingSetupRecipes => 'Adding starter recipes to My recipes';

  @override
  String onboardingSetupRecipesDone(String kind, int count) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'one': 'One starter recipe added to My recipes',
        'other': '$count starter recipes added to My recipes',
      },
    );
    return '$_temp0';
  }

  @override
  String get onboardingSetupRecipesFailed =>
      'The starter recipes couldn\'t be added';

  @override
  String get onboardingSetupWeek =>
      'Laying out an example week and its shopping list';

  @override
  String get onboardingSetupWeekDone => 'Example week and shopping list ready';

  @override
  String get onboardingSetupWeekFailed => 'No example week was added';

  @override
  String onboardingSetupProgress(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Three of three done',
      two: 'Two of three done',
      one: 'One of three done',
      zero: 'None of three done',
    );
    return '$_temp0';
  }

  @override
  String get onboardingDoneTitle => 'There you are. It\'s served.';

  @override
  String onboardingDoneBody(String kind, int count) {
    String _temp0 = intl.Intl.selectLogic(
      kind,
      {
        'zero': 'Everything can be changed whenever you like.',
        'one':
            'One recipe and an example week are waiting for you. Everything can be changed whenever you like.',
        'other':
            '$count recipes and an example week are waiting for you. Everything can be changed whenever you like.',
      },
    );
    return '$_temp0';
  }

  @override
  String get onboardingDoneRedirect => 'Taking you to your recipes …';

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
  String get feedbackDescriptionHint => 'Describe what you experienced …';

  @override
  String get feedbackEmailLabel => 'Email (optional)';

  @override
  String get feedbackScreenshotLabel => 'Screenshot';

  @override
  String get feedbackRemoveScreenshot => 'Remove screenshot';

  @override
  String get feedbackSendButton => 'Send';

  @override
  String get adminLoginButton => 'Sign in';

  @override
  String get adminPasswordLabel => 'Password';

  @override
  String get adminLoginFailed => 'Sign-in failed';

  @override
  String get adminNotAuthorized => 'You do not have access to the admin panel.';

  @override
  String get adminBarTitle => 'Butlery admin';

  @override
  String adminBarSignedIn(String email) {
    return 'Signed in as $email';
  }

  @override
  String get adminSignOut => 'Sign out';

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
  String get adminCopiedForClaude => 'Copied – paste into a new Claude session';

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
  String get adminParsingColDomain => 'Domain';

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
  String get adminRecipesTotal => 'Total recipes';

  @override
  String get adminRecipesColMethod => 'Import method';

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
      'Shows how much content has actually been built up – a basic app-health number.';

  @override
  String get metricRecipeByMethodWhat =>
      'How recipes entered the app, split by method: link, photo, text paste, social media or manual.';

  @override
  String get metricRecipeByMethodHow =>
      'Each recipe is classified by its source field; recipes without it (older or manually created) count as manual/unknown.';

  @override
  String get metricRecipeByMethodWhy =>
      'Shows which import paths users actually use – guides where improving import is worth it.';

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
      'The positive side of import health – how often it actually works.';

  @override
  String get metricImportFailureWhat =>
      'Total failed recipe imports, summed across all sites.';

  @override
  String get metricImportFailureHow =>
      'The sum of every site\'s failure counter.';

  @override
  String get metricImportFailureWhy =>
      'A high number means users hit \'it didn\'t work\' – direct friction.';

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
      'Per site: successes, failures and success rate – worst first.';

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
      'A basic growth number – how many exist in total.';

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
  String get askWhatToEat => 'What should we eat?';

  @override
  String get pickRecipesToVote => 'Pick recipes to vote on';

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
  String get messageStatusSending => 'Sending …';

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
      'Connection issue detected. Attempting to reconnect …';

  @override
  String get errorServiceUnavailable =>
      'Service temporarily unavailable. Please try again later.';

  @override
  String get errorNoItemsFound => 'No items found.';

  @override
  String get errorNoUserLoggedIn => 'No user is signed in';

  @override
  String get errorReauthRequired =>
      'You must sign in again to delete your account';

  @override
  String get errorCouldNotRemoveMfa =>
      'Could not turn off two-step verification';

  @override
  String get errorEmailAlreadyInUse =>
      'This email address is already in use by another account.';

  @override
  String get errorInvalidEmailAddress => 'Invalid email address.';

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
  String get errorMustBeLoggedIn => 'You must be signed in';

  @override
  String get errorMustBeLoggedInToImport =>
      'You must be signed in to import recipes';

  @override
  String get errorMustBeLoggedInToExport =>
      'You must be signed in to export data';

  @override
  String get errorMustBeLoggedInToManageConsent =>
      'You must be signed in to manage consents';

  @override
  String get errorRecipeNameEmpty => 'Recipe name cannot be empty';

  @override
  String get errorCanOnlyUpdatePersonalRecipes =>
      'Can only update personal recipes';

  @override
  String get errorRecipeNotFound => 'Recipe not found';

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
  String get errorNoRecipeToSave => 'No recipe to save';

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
      'Use “Leave group” to leave the conversation';

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
  String get errorNoRecipeToFork => 'No recipe to copy to your own recipes';

  @override
  String get errorCouldNotForkRecipe =>
      'Could not copy the recipe to your own recipes';

  @override
  String get errorNoRecipeToDelete => 'No recipe to delete';

  @override
  String get errorNoPermissionToDelete =>
      'You do not have permission to delete this recipe';

  @override
  String get errorPasswordCannotBeEmpty => 'Password cannot be empty';

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
    return 'A tag with the name “$name” already exists';
  }

  @override
  String get errorGroupDoesNotExist => 'Group does not exist';

  @override
  String get errorTagDoesNotExist => 'Tag does not exist';

  @override
  String get errorRuleDoesNotExist => 'Rule does not exist';

  @override
  String get errorOwnerMustKeepPermission =>
      'The owner must keep owner permissions';

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
  String get actionAppStartup => 'starting the app';

  @override
  String get actionDataSync => 'syncing data';

  @override
  String get actionBackgroundUpload => 'uploading in the background';

  @override
  String get actionOffline => 'working offline';

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
    return '$base because you are not signed in.';
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
    return 'An unexpected error occurred while $action. Try again or contact support if the problem persists.';
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
  String get suggestionCheckLoggedIn => 'Check that you are signed in';

  @override
  String get suggestionRequestPermission =>
      'Request editing permissions from the recipe owner';

  @override
  String get suggestionImageSavedLocally =>
      'Images are saved locally and will upload automatically later';

  @override
  String get suggestionImageSizeLimit =>
      'Check that images are less than 10 MB';

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
  String get suggestionLoginAgain => 'Sign in again';

  @override
  String get suggestionRetryInMinutes => 'Try again in a few minutes';

  @override
  String get suggestionRetryOrContactSupport => 'Try again or contact support';

  @override
  String get statusConnected => 'Connected';

  @override
  String get statusFirebaseUnavailable => 'The server cannot be reached';

  @override
  String get statusNoInternet => 'No internet connection';

  @override
  String get statusDisconnected => 'Disconnected';

  @override
  String get statusCheckingConnection => 'Checking connection …';

  @override
  String get statusReconnecting => 'Reconnecting …';

  @override
  String get statusDone => 'Done.';

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
  String get notificationTitleSuccess => 'Done.';

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
      'The password is too weak. Use at least twelve characters, or three words you remember.';

  @override
  String get errorLoginFailed => 'Sign-in failed. Please try again.';

  @override
  String get errorCouldNotLogOut => 'Could not sign out';

  @override
  String get errorCouldNotDeleteAccount => 'Could not delete the account';

  @override
  String get errorCouldNotCompleteMfa =>
      'Could not complete the two-step verification setup';

  @override
  String get errorMfaVerificationFailed => 'Two-step verification failed';

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
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'Too many requests. Try again in $_temp0.';
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
  String get errorCouldNotStartSync => 'Could not start synchronisation';

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
  String get errorTimeout => 'Timeout exceeded';

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
    return 'A group with the name “$name” already exists';
  }

  @override
  String get errorUserNotLoggedIn => 'User not signed in';

  @override
  String get errorResourceNotFound => 'Resource not found';

  @override
  String get errorNoDeletePermission => 'No permission to delete resource';

  @override
  String get errorCannotRemoveResourceOwner =>
      'Cannot remove the owner from the resource';

  @override
  String get validationUserIdCannotBeEmpty => 'User ID cannot be empty';

  @override
  String get validationUsernameCannotBeEmpty => 'Username cannot be empty';

  @override
  String validationUserAlreadyParticipant(String name) {
    return 'User is already a participant: $name';
  }

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
  String participantOwnerOnly(String name) {
    return 'Owner only: $name';
  }

  @override
  String participantSummary(String owner, int count) {
    return 'Owner: $owner, participants: $count';
  }

  @override
  String activityMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String activityHoursAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0 ago';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0 ago';
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
  String get backupCouldNotReadFile => 'Could not read the file';

  @override
  String get backupInvalidFile => 'Invalid backup file – not from Butlery';

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
  String get syncAlreadyInProgress => 'Sync already in progress';

  @override
  String get syncMustBeOnline => 'You must be online to sync';

  @override
  String get syncNoUserLoggedIn => 'No user signed in';

  @override
  String get syncNoPendingChanges => 'No pending changes';

  @override
  String syncAllSynced(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count changes are synced.',
      one: 'The change is synced.',
    );
    return '$_temp0';
  }

  @override
  String syncPartialSuccess(int synced, int total, int remaining) {
    return '$synced of $total synced, $remaining remaining';
  }

  @override
  String get syncFailedRetryLater => 'Sync failed, will retry later';

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
    String _temp0 = intl.Intl.pluralLogic(
      pending,
      locale: localeName,
      other: '$pending images',
      one: '1 image',
    );
    return 'Waiting to upload $_temp0 …';
  }

  @override
  String uploadStatusUploading(int active, int progress, int pending) {
    String _temp0 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$active images',
      one: '1 image',
    );
    return 'Uploading $_temp0 ($progress% done, $pending waiting)';
  }

  @override
  String get uploadStatusPreparing => 'Preparing upload …';

  @override
  String uploadStatusRetrying(int attempt, int max) {
    return 'Retrying ($attempt/$max) …';
  }

  @override
  String get uploadStatusComplete => 'Upload complete';

  @override
  String get uploadStatusCancelled => 'Upload cancelled';

  @override
  String get uploadFailureNetwork => 'Network error – check your connection';

  @override
  String get uploadFailureValidation => 'Image could not be validated';

  @override
  String get uploadFailureServer => 'Server error – try again';

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
    return 'An unexpected error occurred. Try again.';
  }

  @override
  String get llmUnknownRecipe => 'Unknown recipe';

  @override
  String get llmMustBeLoggedIn => 'You must be signed in to use AI features.';

  @override
  String get llmServiceOverloaded =>
      'The AI service is temporarily overloaded. Try again in a moment.';

  @override
  String get llmCostCeilingDay =>
      'You have used today\'s AI help. Try again tomorrow.';

  @override
  String get llmCostCeilingMonth =>
      'You have used this month\'s AI help. Try again next month.';

  @override
  String llmInvalidArgument(String error) {
    return 'The request could not be processed. Try again.';
  }

  @override
  String llmGenericError(String error) {
    return 'We could not complete this. Try again.';
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
    String _temp0 = intl.Intl.pluralLogic(
      seconds,
      locale: localeName,
      other: '$seconds seconds',
      one: '1 second',
    );
    return 'You are importing too fast. Wait $_temp0.';
  }

  @override
  String rateLimitHourly(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return 'You have reached the hourly limit. Try again in $_temp0.';
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
  String get importErrorCouldNotReachPage => 'The link could not be read';

  @override
  String get importErrorLoginRequired => 'The page requires sign-in';

  @override
  String get importErrorNoRecipeFound => 'We found no recipe on the page';

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
  String shoppingListAllBought(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count items bought',
      one: '1 item bought',
    );
    return '$_temp0';
  }

  @override
  String shoppingListItemsRemaining(int remaining, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total items remaining',
      one: '1 item remaining',
    );
    return '$remaining of $_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0 ago';
  }

  @override
  String shoppingListActivityDaysAgo(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return '$_temp0 ago';
  }

  @override
  String shoppingListLastActivityBy(String name, String time) {
    return 'Last activity by $name $time';
  }

  @override
  String shoppingListUpdatedByNotice(String name) {
    return 'The list was updated by $name';
  }

  @override
  String get shoppingListUpdatedByUnknown =>
      'The list was updated by someone else';

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
    return '$name wants to see your recipe “$title”';
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
  String recipeShareRequestShareFailed(String name) {
    return 'The recipe could not be shared with $name.';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count shopping lists',
      one: '1 shopping list',
    );
    return '$_temp0';
  }

  @override
  String notificationDigestCollaborations(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count collaborations',
      one: '1 collaboration',
    );
    return '$_temp0';
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
      'Authentication error. Please sign in again.';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count participants',
      one: '1 participant',
    );
    return '$_temp0';
  }

  @override
  String notificationBatchBodyRecipes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new events',
      one: '1 new event',
    );
    return '$_temp0 on your recipes';
  }

  @override
  String notificationBatchBodyFriends(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new activities',
      one: '1 new activity',
    );
    return '$_temp0 from your friends';
  }

  @override
  String notificationBatchBodyShopping(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count updates',
      one: '1 update',
    );
    return '$_temp0 to your shopping lists';
  }

  @override
  String notificationBatchBodyCollaboration(int count) {
    return '$count new collaboration activities';
  }

  @override
  String notificationBatchBodyDefault(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new events',
      one: '1 new event',
    );
    return '$_temp0 in Butlery';
  }

  @override
  String notificationDigestBody(int totalCount, String summary) {
    String _temp0 = intl.Intl.pluralLogic(
      totalCount,
      locale: localeName,
      other: '$totalCount new activities',
      one: '1 new activity',
    );
    return 'You have $_temp0: $summary';
  }

  @override
  String uploadStatusUploadingNoPending(int active, int progress) {
    String _temp0 = intl.Intl.pluralLogic(
      active,
      locale: localeName,
      other: '$active images',
      one: '1 image',
    );
    return 'Uploading $_temp0 ($progress% done)';
  }

  @override
  String uploadStatusPartialFailure(int completed, int total, int failed) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total images uploaded',
      one: '1 image uploaded',
    );
    return '$completed of $_temp0, $failed failed';
  }

  @override
  String uploadStatusAllFailed(int failed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total images failed',
      one: '1 image failed',
    );
    return '$failed of $_temp0 – tap to retry';
  }

  @override
  String uploadStatusAllSuccess(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'All $total images are uploaded',
      one: 'The image is uploaded',
    );
    return '$_temp0';
  }

  @override
  String uploadStatusAllCancelled(int cancelled) {
    String _temp0 = intl.Intl.pluralLogic(
      cancelled,
      locale: localeName,
      other: 'All $cancelled uploads were cancelled',
      one: 'The upload was cancelled',
    );
    return '$_temp0';
  }

  @override
  String uploadProgressWithTime(int progress, String time) {
    return '$progress% done – $time remaining';
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
  String get uploadPreparing => 'Preparing upload …';

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
  String errorCouldNotPerformOperation(String operation, String error) {
    return 'Could not $operation. Try again.';
  }

  @override
  String errorCouldNotCreateRealtimeMenu(String error) {
    return 'The menu could not be created. Try again.';
  }

  @override
  String errorCouldNotWatchMenu(String error) {
    return 'The menu could not be followed. Try again.';
  }

  @override
  String errorCouldNotDeleteRealtimeMenu(String error) {
    return 'The menu could not be deleted. Try again.';
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
      'Image is too blurry or too small – try again in better lighting.';

  @override
  String get syncErrorParsingResource => 'Could not read the content';

  @override
  String syncErrorWatchingResource(String resourceId) {
    return 'Could not follow changes to $resourceId';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return '$category menu ($_temp0)';
  }

  @override
  String menuTitleMultiCategory(String categories, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return 'Weekly menu with $categories ($_temp0)';
  }

  @override
  String get tiktokOriginalText => 'Original text from TikTok:';

  @override
  String get tiktokIdentifiedIngredients => 'Identified ingredients:';

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
  String get importPhaseFetching => 'Fetching content …';

  @override
  String get importPhaseAnalyzing => 'Analysing recipe …';

  @override
  String get importPhaseCreating => 'Creating recipe …';

  @override
  String get importPhaseComplete => 'Done.';

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
    return 'Do take a look at this recipe: “$title”.';
  }

  @override
  String get shareMessageRecipeDefault =>
      'I found a recipe I wanted to share with you.';

  @override
  String shareMessageMenuWithTitle(String title) {
    return 'Here\'s my weekly menu: “$title”';
  }

  @override
  String get shareMessageMenuDefault =>
      'Here\'s my weekly menu, perhaps for inspiration.';

  @override
  String shareMessageShoppingListWithTitle(String title) {
    return 'Want to help me with the shopping list: “$title”?';
  }

  @override
  String get shareMessageShoppingListDefault =>
      'Want to help me with shopping this week?';

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
  String get recipeFormPermissionsError => 'Could not read the permissions';

  @override
  String createSharedListError(String error) {
    return 'The shared list could not be created. Try again.';
  }

  @override
  String get userStatusOnline => 'Online';

  @override
  String recipeCookTimeMinutes(int minutes) {
    String _temp0 = intl.Intl.pluralLogic(
      minutes,
      locale: localeName,
      other: '$minutes minutes',
      one: '1 minute',
    );
    return '$_temp0';
  }

  @override
  String get recipeLastCookedToday => 'Cooked today';

  @override
  String get recipeLastCookedYesterday => 'Cooked yesterday';

  @override
  String recipeLastCookedDaysAgo(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Cooked $_temp0 ago';
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
    return '$title (copy)';
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
  String get friendCategoryDefaultNeighbors => 'Neighbours';

  @override
  String get friendCategoryDefaultNeighborsDesc => 'Neighbours and local area';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends',
      one: '1 friend',
    );
    return '$_temp0';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count active collaborators',
      one: '1 active collaborator',
    );
    return '$_temp0';
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
  String get timeJustNow => 'just now';

  @override
  String timeMinutesAgo(int minutes) {
    return '$minutes min ago';
  }

  @override
  String timeHoursAgo(int hours) {
    return '$hours h ago';
  }

  @override
  String timeMinutesAgoLong(int minutes) {
    return '$minutes min ago';
  }

  @override
  String timeHoursAgoLong(int hours) {
    return '$hours h ago';
  }

  @override
  String timeDaysAgoLong(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0 ago';
  }

  @override
  String timeWeeksAgo(int weeks) {
    String _temp0 = intl.Intl.pluralLogic(
      weeks,
      locale: localeName,
      other: '$weeks weeks',
      one: '1 week',
    );
    return '$_temp0 ago';
  }

  @override
  String get timeNow => 'Now';

  @override
  String get dateTomorrow => 'Tomorrow';

  @override
  String get dateNoDate => 'No date';

  @override
  String dateDaysAhead(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0 ahead';
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
  String get buttonCreating => 'Creating …';

  @override
  String get buttonCreateAndShare => 'Create and share';

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
  String get labelUntitledMenu => 'Untitled menu';

  @override
  String get labelUntitledList => 'Untitled list';

  @override
  String get labelUntitledRecipe => 'Untitled recipe';

  @override
  String get labelUnknownContent => 'Unknown content';

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
    String _temp0 = intl.Intl.pluralLogic(
      invitedCount,
      locale: localeName,
      other: '$invitedCount invitations',
      one: '1 invitation',
    );
    String _temp1 = intl.Intl.pluralLogic(
      skippedCount,
      locale: localeName,
      other: '$skippedCount friends',
      one: '1 friend',
    );
    return '$_temp0 sent. $_temp1 skipped (already have access).';
  }

  @override
  String get errorCouldNotSendInvitations => 'Could not send invitations';

  @override
  String get shareDefaultShoppingListMessage =>
      'Sharing this shopping list with you.';

  @override
  String shoppingListAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count items done',
      one: '1 item done',
    );
    return '$_temp0';
  }

  @override
  String shoppingListItemsToBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0 to buy';
  }

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
    return '$count h ago';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count weeks',
      one: '1 week',
    );
    return '$_temp0 ago';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0 ago';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count hours',
      one: '1 hour',
    );
    return '$_temp0 left';
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
    return '$sender invited you to group $emoji $group: “$message”';
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
  String get invitationStatusRejected => 'Declined';

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
      'Read-only – you can save your own copy';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days',
      one: '1 day',
    );
    return 'Member for $_temp0';
  }

  @override
  String memberSinceMonths(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count months',
      one: '1 month',
    );
    return 'Member for $_temp0';
  }

  @override
  String memberSinceYears(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count years',
      one: '1 year',
    );
    return 'Member for $_temp0';
  }

  @override
  String get commentDeleted => '[Comment deleted]';

  @override
  String sharedMenuTitlePattern(String name) {
    return '$name\'s weekly menu';
  }

  @override
  String importedFromMenu(String name, String title) {
    return 'Imported from $name\'s menu “$title”';
  }

  @override
  String get importedRecipeLabel => 'Imported recipe';

  @override
  String get labelEmptyMenu => 'Empty menu';

  @override
  String get errorVideoNoSubtitles => 'Video has no subtitles';

  @override
  String get errorNetworkFallback => 'Network error';

  @override
  String get recipeCollaborationEnable => 'Enable collaboration';

  @override
  String get recipeCollaborationDisable => 'Disable collaboration';

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
  String get recipeSharingRemoveGroup => 'Remove the group\'s access';

  @override
  String recipeSharingRevokeConfirm(String name) {
    return 'Stop sharing with $name?';
  }

  @override
  String recipeSharingRevokeSuccess(String name) {
    return 'Sharing with $name stopped';
  }

  @override
  String recipeSharingRevokeGroupConfirm(String name) {
    return 'Revoke access to this recipe for the group $name? Anyone you also shared with individually, or through another group, keeps theirs.';
  }

  @override
  String recipeSharingRevokeGroupSuccess(String name) {
    return 'The group $name no longer has access to this recipe. Anyone you also shared with individually, or through another group, keeps theirs.';
  }

  @override
  String get recipeSharingFriends => 'Friends';

  @override
  String get recipeSharingGroups => 'Groups';

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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String shoppingTemplateUsedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count times',
      one: '1 time',
    );
    return 'Used $_temp0';
  }

  @override
  String get labelButleryUser => 'Butlery user';

  @override
  String get shoppingListSummaryEmpty => 'Empty shopping list';

  @override
  String shoppingListSummaryAllDone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'All $count items done',
      one: '1 item done',
    );
    return '$_temp0';
  }

  @override
  String shoppingListSummaryToBuy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0 to buy';
  }

  @override
  String shoppingListSummaryRemaining(int remaining, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total items remaining',
      one: '1 item remaining',
    );
    return '$remaining of $_temp0';
  }

  @override
  String notificationBatchComments(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new comments',
      one: '1 new comment',
    );
    return '$_temp0 on your recipes';
  }

  @override
  String notificationCommentSingle(String author, String recipe) {
    return '$author commented on “$recipe”';
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
      other: '$count comments',
      one: '1 comment',
    );
    return '$author wrote $_temp0 on “$recipe”';
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
      other: '$authorCount people',
      one: '1 person',
    );
    String _temp1 = intl.Intl.pluralLogic(
      commentCount,
      locale: localeName,
      other: '$commentCount comments',
      one: '1 comment',
    );
    return '$_temp0 wrote $_temp1 on “$recipe”';
  }

  @override
  String notificationRatingSingle(String recipe, int count, String period) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count new ratings',
      one: '1 new rating',
    );
    return 'Your recipe “$recipe” received $_temp0 this $period.';
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
      other: '$totalRatings new ratings',
      one: '1 new rating',
    );
    String _temp1 = intl.Intl.pluralLogic(
      recipeCount,
      locale: localeName,
      other: '$recipeCount recipes',
      one: '1 recipe',
    );
    return 'Your recipes received $_temp0 across $_temp1 this $period.';
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
      'Display name can only contain letters, numbers, spaces, hyphens, underscores and full stops';

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
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '1 character',
    );
    return 'Message must be at most $_temp0';
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
  String get validationPasswordRule =>
      'The password needs at least twelve characters, or three words you remember.';

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
    return 'The image could not be uploaded. Try again.';
  }

  @override
  String errorRecipeServiceFailed(String message) {
    return 'The recipe could not be processed. Try again.';
  }

  @override
  String errorPermissionFailed(String message) {
    return 'You do not have permission for this. Ask the owner for access.';
  }

  @override
  String errorNetworkWithDetail(String message) {
    return 'Network error. Check your connection and try again.';
  }

  @override
  String errorStorageFailed(String message) {
    return 'Storage failed. Check the space on your phone and try again.';
  }

  @override
  String errorCollaborationFailed(String message) {
    return 'The collaboration could not be updated. Try again.';
  }

  @override
  String errorAutoSaveFailed(String message) {
    return 'Auto-save failed. Save manually so that your changes are not lost.';
  }

  @override
  String errorSystemFailed(String message) {
    return 'A system error occurred. Try again.';
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
    return 'Image upload progress – $percentage% complete';
  }

  @override
  String get feedbackDescriptionRequired => 'Enter a description';

  @override
  String get feedbackThanks => 'Thank you for your feedback.';

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
    return 'Validation failed. Check the details and try again.';
  }

  @override
  String get snackbarNoInternet =>
      'No internet connection. Check your connection.';

  @override
  String get errorInvalidYoutubeUrl => 'Invalid YouTube URL';

  @override
  String errorInvalidCategoryNamesFromTo(
    String fromCategory,
    String toCategory,
  ) {
    return 'Invalid category names: $fromCategory -> $toCategory';
  }

  @override
  String get errorPreservedLink => 'The link is still in the field.';

  @override
  String get errorPreservedPhoto => 'The photo is still here.';

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
  String get shareTimeLabelBold => '**Time:**';

  @override
  String get sharePortionsLabelBold => '**Portions:**';

  @override
  String get shareRatingLabelBold => '**Rating:**';

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
  String get shareWeekMenuTitleEmoji => 'WEEK MENU';

  @override
  String get shareSummaryLabel => 'Summary:';

  @override
  String shareSummaryRecipesInCategories(int recipeCount, int categoryCount) {
    String _temp0 = intl.Intl.pluralLogic(
      recipeCount,
      locale: localeName,
      other: '$recipeCount recipes',
      one: '1 recipe',
    );
    String _temp1 = intl.Intl.pluralLogic(
      categoryCount,
      locale: localeName,
      other: '$categoryCount categories',
      one: '1 category',
    );
    return '$_temp0 in $_temp1';
  }

  @override
  String get unsavedChangesTitle => 'Unsaved changes';

  @override
  String get unsavedChangesMessage =>
      'You have unsaved changes. Do you really want to cancel?';

  @override
  String get cancelWithoutSaving => 'Cancel without saving';

  @override
  String get deleteActionIrreversible => 'This can\'t be undone.';

  @override
  String get groupLeaveTitle => 'Leave group?';

  @override
  String groupLeaveMessage(String name) {
    return 'Do you really want to leave the group “$name”?';
  }

  @override
  String get groupLeaveAction => 'Leave group';

  @override
  String get recipeDeleteWarning =>
      'The recipe moves to the trash and stays there for 30 days.';

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
  String get pollVoteSingular => 'vote';

  @override
  String get pollVotePlural => 'votes';

  @override
  String get pollClosed => 'Closed';

  @override
  String get pollVotesNotLoadedShort => 'Votes not loaded';

  @override
  String get pollVotesFailedShort => 'Votes could not be read';

  @override
  String get pollVotesNotLoadedHint => 'Reopen the chat to fetch them.';

  @override
  String get pollVotesFailedHint => 'Try again in a moment.';

  @override
  String get pollCloseRefusedVotesUnread =>
      'The poll was not closed – its votes were never loaded, and it must not be closed on numbers nobody read. Reopen the chat and try again.';

  @override
  String get pollClosedWithoutPlan =>
      'The poll is closed, but the dish could not be added to the menu. Add it yourself.';

  @override
  String get pollCloseRefusedBlockList =>
      'The poll was not closed – your block list could not be read, so blocked votes cannot be excluded. Try again.';

  @override
  String get pollCloseRefusedBlockListOffline =>
      'The poll was not closed – the app is offline and cannot check your block list. Try again once you have a connection.';

  @override
  String get pollCloseFailed => 'The poll could not be closed. Try again.';

  @override
  String get pollCloseAction => 'Close poll';

  @override
  String chatGroupCreatedMessage(String name, String title) {
    return '$name created the group “$title”';
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
  String get authRequiredError => 'You must be signed in';

  @override
  String get shoppingListEditPermissionDenied =>
      'You do not have permission to edit this shared shopping list';

  @override
  String get userStatusOffline => 'Offline';

  @override
  String get userStatusAway => 'Away';

  @override
  String get userStatusBusy => 'Busy';

  @override
  String get restoreDraft => 'Restore';

  @override
  String fieldsFilledCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count fields',
      one: '1 field',
    );
    return '$_temp0 filled';
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
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return 'Shared recipe · $_temp0';
  }

  @override
  String sharedMenuFallback(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members',
      one: '1 member',
    );
    return 'Shared menu · $_temp0';
  }

  @override
  String get sharedFallback => 'Shared';

  @override
  String get accountSecurityChangePassword => 'Change password';

  @override
  String get accountSecurityChangeEmail => 'Change email';

  @override
  String get accountSecurityCurrentPassword => 'Current password';

  @override
  String get accountSecurityNewPassword => 'New password';

  @override
  String get accountSecurityConfirmPassword => 'Confirm password';

  @override
  String get accountSecurityNewEmail => 'New email';

  @override
  String get accountSecurityPasswordChanged => 'Password changed successfully';

  @override
  String get accountSecurityEmailVerificationSent =>
      'Verification link sent to new email address';

  @override
  String get accountSecurityEmailChangeHow =>
      'We send a link to the new address. The change applies only once you have opened it, and your current address then gets an email where the change can be undone.';

  @override
  String get accountSecurityPasswordMismatch => 'Passwords do not match';

  @override
  String get passwordsMatch => 'Passwords match';

  @override
  String get selectionEnter => 'Select';

  @override
  String get selectionEnterRecipes => 'Select recipes';

  @override
  String get selectionEnterShoppingItems => 'Select items';

  @override
  String get selectionEnterPantryItems => 'Select pantry items';

  @override
  String get selectionEnterTags => 'Select tags';

  @override
  String get selectionEnterMembers => 'Select members';

  @override
  String get selectionEnterBlockedUsers => 'Select blocked people';

  @override
  String selectionSelectAllCount(int count) {
    return 'Select all $count';
  }

  @override
  String bulkSelectedCount(int count) {
    return '$count selected';
  }

  @override
  String get bulkMoreActions => 'More actions';

  @override
  String get bulkDelete => 'Delete selected';

  @override
  String get bulkShare => 'Share selected';

  @override
  String get bulkShareFriendsLoadFailed => 'Could not load your friends';

  @override
  String get bulkShareSelectionKept => 'The recipes are still selected.';

  @override
  String get bulkTag => 'Tag selected';

  @override
  String bulkTagDialogTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return 'Add tag to $_temp0';
  }

  @override
  String get bulkTagNoTagsAvailable => 'No personal tags available';

  @override
  String bulkTagSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return 'Tag added to $_temp0';
  }

  @override
  String get bulkTagAllAlreadyTagged =>
      'All selected recipes already have this tag';

  @override
  String get viewModeGrid => 'Grid view';

  @override
  String get viewModeList => 'List view';

  @override
  String get imageCropTitle => 'Crop image';

  @override
  String get bulkDeleteConfirmMessage =>
      'The selected recipes move to the trash and stay there for 30 days.';

  @override
  String bulkDeleteSuccess(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes moved to the trash for 30 days',
      one: '1 recipe moved to the trash for 30 days',
    );
    return '$_temp0';
  }

  @override
  String get profileFaq => 'FAQ';

  @override
  String get faqQ1 => 'How do I import recipes?';

  @override
  String get faqA1 =>
      'You can import recipes in several ways: paste a URL from a recipe site, take a photo of a recipe, or paste recipe text directly. Tap “Add” on the home screen and choose a method.';

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
      'Go to More and select “Personal tags”. There you can create tags such as “Everyday meals” or “Party food” and assign them to your recipes for easy filtering.';

  @override
  String get faqQ5 => 'How do I report problems?';

  @override
  String get faqA5 =>
      'Tap the “!” button shown at the bottom right of every page. There you can describe the problem, choose a category and attach a screenshot. We read all feedback.';

  @override
  String get legalTermsOfService => 'Terms of service';

  @override
  String get legalCommunityGuidelines => 'Community guidelines';

  @override
  String get legalOpenSourceLicenses => 'Open source licences';

  @override
  String get authTermsAcceptPrefix => 'I accept the ';

  @override
  String get authTermsConsentPrefix => 'I accept the ';

  @override
  String get authTermsConsentTermsLink => 'terms';

  @override
  String get authTermsConsentPrivacyLink => 'privacy policy';

  @override
  String get authTermsAcceptMiddle => ' and ';

  @override
  String get authTermsAcceptRequired =>
      'You must accept the terms to create an account';

  @override
  String get a11yTermsOfServiceLink => 'Terms of service';

  @override
  String get a11yPrivacyPolicyLink => 'Privacy policy';

  @override
  String a11yLinkTo(String url) {
    return 'Link to $url';
  }

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
  String get reportDescriptionHint => 'Tell us what is wrong …';

  @override
  String get reportSubmitted => 'Report sent';

  @override
  String get reportSubmitFailed => 'The report could not be sent';

  @override
  String get reportDialogTitle => 'Report content';

  @override
  String get reportSubmit => 'Send report';

  @override
  String get reportDialogGuidelinesNotePrefix => 'We judge against';

  @override
  String get reportDialogGuidelinesLink => 'our guidelines';

  @override
  String get myReportsTitle => 'My reports';

  @override
  String get myReportsEmpty => 'You haven\'t submitted any reports yet.';

  @override
  String get myReportsStatusPending => 'Submitted';

  @override
  String get myReportsStatusReviewed => 'In review';

  @override
  String get myReportsStatusClosed => 'Closed';

  @override
  String get myReportsLoadFailed => 'Could not load reports';

  @override
  String get myReportsRetry => 'Retry';

  @override
  String get newAccountSocialBlocked => 'Verify your email to add friends';

  @override
  String get newAccountSocialBlockedDm => 'Verify your email to send messages';

  @override
  String get newAccountSocialBlockedGroup =>
      'Verify your email to invite members to a group';

  @override
  String get newAccountSocialBlockedComment => 'Verify your email to comment';

  @override
  String get newAccountSocialResendEmail => 'Send email again';

  @override
  String get socialAccepting => 'Accepting …';

  @override
  String get newAccountSocialEmailResent => 'Verification sent again';

  @override
  String get newAccountSocialEmailResendFailed =>
      'Could not send the verification email';

  @override
  String get contentFilterWarning =>
      'The text contains inappropriate language. Please edit before submitting.';

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
  String get emailVerificationTitle => 'Confirm your email';

  @override
  String emailVerificationMessage(String email) {
    return 'We\'ve sent a link to $email. The screen moves on by itself once you\'ve clicked it.';
  }

  @override
  String get emailVerificationResend => 'Send again';

  @override
  String emailVerificationResendCountdown(int seconds) {
    return 'Send again ($seconds s)';
  }

  @override
  String get emailVerificationContinue => 'Continue without confirming';

  @override
  String get emailVerificationSuccess => 'Email verified.';

  @override
  String get a11yCookingModeFontScale => 'Change text size';

  @override
  String get a11yCookingModeRotate => 'Rotate screen';

  @override
  String get a11yCookingModeClose => 'Close cooking mode';

  @override
  String get a11yRecipeFavorited => 'Recipe added to favourites';

  @override
  String get a11yRecipeUnfavorited => 'Recipe removed from favourites';

  @override
  String get a11yCommentPosted => 'Comment posted';

  @override
  String get a11yItemBought => 'Marked as bought';

  @override
  String get a11yItemUnbought => 'Marked as not bought';

  @override
  String get a11yOcrComplete => 'Text extraction complete';

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
  String get statsRecipeCollection => 'Recipe collection';

  @override
  String get statsTotalRecipes => 'Total recipes';

  @override
  String get statsFavorites => 'Favourites';

  @override
  String get statsRecentlyCooked => 'Recently cooked';

  @override
  String get statsWithImages => 'With images';

  @override
  String get statsPersonalRecipes => 'Personal recipes';

  @override
  String get statsCollaborativeRecipes => 'Collaborative recipes';

  @override
  String get statsHighRated => 'Highly rated';

  @override
  String get statsMealTypes => 'Meal types';

  @override
  String get statsPopularTags => 'Popular tags';

  @override
  String get statsCookingActivity => 'Cooking activity';

  @override
  String get statsTotalCooks => 'Total cooks';

  @override
  String get statsNoMealTypes => 'No meal types recorded';

  @override
  String get statsNoTags => 'No tags used yet';

  @override
  String statsCountedNote(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return 'Counted over $_temp0 on this phone. The figures cover your collection as it has been fetched here – not a calculation on the server.';
  }

  @override
  String get statsDistinctMealTypes => 'Meal types';

  @override
  String get statsDistinctTags => 'Tags';

  @override
  String get importPendingRetryPrompt =>
      'You have a pending import – retry now?';

  @override
  String get importPendingRetry => 'Retry';

  @override
  String get importPendingDismiss => 'Dismiss';

  @override
  String get importSavedForLater =>
      'URL saved – will import when you\'re back online';

  @override
  String get importOfflineMessage =>
      'You\'re offline – connect to the internet and try again.';

  @override
  String get seasonalForgottenFavorites => 'Forgotten favourites';

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
  String get quickCaptureSave => 'Save';

  @override
  String get quickCaptureSaved => 'Recipe saved.';

  @override
  String get quickCaptureEditAction => 'Edit';

  @override
  String get quickCaptureTitleHint => 'What\'s the dish called?';

  @override
  String get quickCaptureHelp =>
      'The recipe is saved as a card without details – you can import ingredients and steps whenever you like.';

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
  String get duplicateMergeFailed => 'Could not merge the recipe';

  @override
  String get duplicateMergeNoTime => 'No time';

  @override
  String duplicateMergeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String duplicateMergeItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String get duplicateMergeNoSource => 'No source';

  @override
  String get duplicateMergeNoImage => 'No image';

  @override
  String menuSwapAlternatives(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count alternatives',
      one: '1 alternative',
    );
    return '$_temp0 left';
  }

  @override
  String get menuSwapExhausted =>
      'No more alternatives matching your preferences';

  @override
  String get menuSuggestionFavorites => 'Weekly menu from favourites';

  @override
  String get menuSuggestionRecent => 'Menu with recent recipes';

  @override
  String get publicProfileEmpty => 'This user has no public recipes';

  @override
  String get publicProfileError => 'Profile not found';

  @override
  String get publicProfileShareButton => 'Share profile';

  @override
  String get statsCompleteness => 'Recipe quality';

  @override
  String get statsWithoutPhoto => 'No photo';

  @override
  String get statsWithoutTime => 'No time';

  @override
  String get statsIncomplete => 'Incomplete';

  @override
  String get statsAllComplete => 'All recipes are complete.';

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
  String get notificationsMarkAllReadShort => 'Mark all as read';

  @override
  String notificationsUnreadCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count unread',
      one: '1 unread',
    );
    return '$_temp0';
  }

  @override
  String get notificationsNote =>
      'Twenty at a time, older ones load as you scroll. Long-press to select several.';

  @override
  String notificationsDismissed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count notifications removed',
      one: 'Notification removed',
    );
    return '$_temp0';
  }

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
  String get cookSnapEmptySubtitle => 'Be the first.';

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
  String get cookSnapDeletedUndoMessage => 'Photo will be deleted – undo?';

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
  String get weeklyMenuNewMark => 'new';

  @override
  String get weeklyMenuLegendNew => 'new';

  @override
  String get weeklyMenuLegendAllergen => 'can\'t eat';

  @override
  String get weeklyMenuLegendPresence => 'home, if not everyone';

  @override
  String a11yWeeklyMenuAddDish(String slot, String day) {
    return 'Add a dish for $slot on $day';
  }

  @override
  String a11yWeeklyMenuOpenOvrigt(String day) {
    return 'Show other dishes on $day';
  }

  @override
  String get weeklyMenuEmptyTitle => 'No plan yet';

  @override
  String get weeklyMenuEmptyHint =>
      'Generate a weekly menu from the prompt above and we\'ll lay out the days for you.';

  @override
  String weeklyMenuOvrigtSheetTitle(String day) {
    return 'Other dishes on $day';
  }

  @override
  String get weeklyMenuOvrigtSheetAdd => 'Add a dish';

  @override
  String get weeklyMenuOverwriteConfirm =>
      'This will replace your current plan. Continue?';

  @override
  String get weeklyMenuLoadError => 'Couldn\'t load the weekly menu';

  @override
  String weeklyMenuWeekTitle(int weekNum) {
    return 'Week $weekNum';
  }

  @override
  String weeklyMenuWeekRange(String start, String end) {
    return '$start–$end';
  }

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
  String get weeklyPlanReadFailed =>
      'Couldn\'t load the week – please try again';

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
  String get a11yWeeklyMenuSelectEntry => 'Select to move';

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
  String get pantryItemChangedNow => 'changed just now';

  @override
  String pantryItemChangedMinutesAgo(int count) {
    return 'changed $count min ago';
  }

  @override
  String pantryItemChangedToday(String time) {
    return 'changed today at $time';
  }

  @override
  String get pantryItemChangedYesterday => 'changed yesterday';

  @override
  String pantryItemChangedOn(String date) {
    return 'changed $date';
  }

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
      'The item could not be saved to the pantry.';

  @override
  String get pantryIngredientLabel => 'Ingredient';

  @override
  String get pantryIngredientHint => 'Search ingredient …';

  @override
  String get pantryQuantityLabel => 'Quantity';

  @override
  String get pantryUnitLabel => 'Unit';

  @override
  String get pantryNoteLabel => 'Note (optional)';

  @override
  String get pantryAddAction => 'Add';

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
  String get ingredientSearchHint => 'add …';

  @override
  String get ingredientSearchButton => 'Search recipes';

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
      other: '$count recipes match',
      one: '1 recipe matches',
    );
    return '$_temp0';
  }

  @override
  String ingredientMatchCount(int matched, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total ingredients',
      one: '1 ingredient',
    );
    return '$matched of $_temp0';
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
    return '$name grabbed that – pick another';
  }

  @override
  String shoppingItemClaimed(String itemName) {
    return 'Claimed “$itemName”';
  }

  @override
  String shoppingItemUnclaimed(String itemName) {
    return 'Released “$itemName”';
  }

  @override
  String outOfIngredientTitle(String ingredient) {
    return 'Out of $ingredient? Try …';
  }

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
  String get timerExpired => 'Timer done.';

  @override
  String get timerNotificationTitle => 'Timer done.';

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
  String a11yActiveTimer(String label) {
    return 'Timer $label: time left';
  }

  @override
  String get a11yActiveTimerUnnamed => 'Timer: time left';

  @override
  String get pauseTimer => 'Pause';

  @override
  String get resumeTimer => 'Resume';

  @override
  String get resetTimer => 'Reset';

  @override
  String timerDurationHint(String source) {
    return 'From “$source”';
  }

  @override
  String get heirloomToggle => 'This is an heirloom recipe';

  @override
  String get heirloomWriterLabel => 'Whose handwriting?';

  @override
  String get heirloomYearLabel => 'Year';

  @override
  String get heirloomNoteLabel => 'Note';

  @override
  String heirloomFrom(String name, int year) {
    return 'From $name, $year';
  }

  @override
  String get heirloomUploadOffline => 'Saving when you\'re back online';

  @override
  String get pendingSyncOffline =>
      'Saved. It\'ll sync when you\'re back online.';

  @override
  String get commentWaitingForNetwork =>
      'Your last comment is waiting for a connection. Send this one once it has gone.';

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
  String get pingComposeTitle => 'Send a nudge';

  @override
  String get pingComposeMessageHint => 'Message (optional)';

  @override
  String get pingComposeSend => 'Send';

  @override
  String get pingComposeSent => 'Sent';

  @override
  String get pingRateLimited => 'You have sent too many pings in the last hour';

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
  String get moderatorReporterErased =>
      'The reporter\'s account has been deleted';

  @override
  String get moderatorEvidenceHeading => 'Saved copy';

  @override
  String moderatorEvidenceHeadingAt(String time) {
    return 'Saved copy · $time';
  }

  @override
  String get moderatorEvidenceTruncated => 'The text is shortened';

  @override
  String get moderatorEvidenceTextOnly => 'Only text is saved, not images';

  @override
  String get moderatorEvidenceMissing =>
      'The content was already gone when the report came in';

  @override
  String get moderatorEvidenceNotVisible =>
      'No copy: the reporter could not see the content';

  @override
  String get moderatorEvidenceOwnerMismatch =>
      'No copy: the content does not belong to the reported person';

  @override
  String get moderatorEvidenceUnsupported => 'No copy for this kind of report';

  @override
  String get moderatorEvidenceFailed => 'The copy could not be saved';

  @override
  String get moderatorEvidenceNone => 'No copy saved';

  @override
  String get moderatorMinorAccountBadge => 'Minor account';

  @override
  String get moderatorActionAdvance => 'Advance';

  @override
  String get moderatorActionDelete => 'Delete content';

  @override
  String get moderatorDeleteConfirmTitle => 'Delete this content?';

  @override
  String get moderatorDeleteConfirmBody =>
      'This permanently deletes the reported content. The action cannot be undone from the app.';

  @override
  String get moderatorActionHide => 'Hide profile';

  @override
  String get moderatorHideConfirmTitle => 'Hide this profile?';

  @override
  String get moderatorHideConfirmBody =>
      'The profile will be removed from search and friend lists. The user can still sign in but appears as a placeholder to others. You can reverse this later.';

  @override
  String get appealEmailLinkLabel => 'Appeal a decision';

  @override
  String get appealEmailSubject => 'Appeal of a decision';

  @override
  String get appealEmailBodyTemplate =>
      'Hi Butlery,\n\nI want to appeal a decision about my content or my profile:\n- What the decision was about (for example a recipe, comment, image or profile):\n- Approximate date:\n- My username:\n\nWhy I think the decision is wrong:\n\nThanks.';

  @override
  String get appealEmailLaunchFailed =>
      'Could not open the email app. Please email overklagande@butlery.se manually.';

  @override
  String get myReportsOutcomeReceived => 'We have received your report.';

  @override
  String get myReportsOutcomeInReview => 'A moderator is reviewing the report.';

  @override
  String get myReportsOutcomeContentRemoved =>
      'The content was removed because it broke the community guidelines.';

  @override
  String get myReportsOutcomeProfileHidden =>
      'The profile was hidden from others because it broke the community guidelines.';

  @override
  String get myReportsOutcomeNoAction =>
      'We found that the content does not break the community guidelines. It stays up.';

  @override
  String get myReportsOutcomeClosed => 'The case is closed.';

  @override
  String get myReportsAppealButton => 'Appeal the decision';

  @override
  String myReportsAppealBody(
    String reportId,
    String date,
    String reason,
    String outcome,
  ) {
    return 'Hi Butlery,\n\nI want to appeal the decision on my report.\n- Case: $reportId\n- Reported: $date\n- Reason: $reason\n- Decision: $outcome\n\nWhy I think the decision is wrong:\n\nThanks.';
  }

  @override
  String get a11yProfileImageEdit => 'Profile picture, tap to change';

  @override
  String get a11yProfileImageReadonly => 'Profile picture';

  @override
  String get a11yReactToComment => 'React to comment';

  @override
  String get a11yShowCommentLikes => 'Show who liked';

  @override
  String get a11yLongPressCommentForReactions => 'Comment, long press to react';

  @override
  String get a11yCommentLikeAction => 'Like comment';

  @override
  String get a11yCommentReplyAction => 'Reply to comment';

  @override
  String a11yEditImageAction(String label) {
    return '$label';
  }

  @override
  String a11yImagePickerRemove(int index) {
    return 'Remove selected image $index';
  }

  @override
  String get a11yGalleryAddImage => 'Add image to gallery';

  @override
  String recipeRatingSemantics(String rating) {
    return 'Rating: $rating';
  }

  @override
  String get a11yMenuRecipeOpen => 'Open the recipe';

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
  String get a11yShelfRecipeOpen => 'Open recipe';

  @override
  String get a11yCookSnapOptions => 'Cooking photo, long press for options';

  @override
  String get a11yConversationOpen => 'Open conversation';

  @override
  String get a11yMenuVoteOption => 'Vote';

  @override
  String get a11yMenuVoteOptionSelected => 'Your vote';

  @override
  String get a11yPingAcknowledge => 'Acknowledge notification';

  @override
  String get a11yMenuPlanRecipeOpen => 'Open the recipe';

  @override
  String get a11yRefineMenuPrompt => 'Refine the menu prompt';

  @override
  String get a11yAddIngredient => 'Add';

  @override
  String get a11yQuickFilter => 'Filter';

  @override
  String get a11yHeirloomScanOpenFullscreen =>
      'Open original scan in fullscreen';

  @override
  String a11yReplaceWithSubstitute(String name) {
    return 'Substitute: $name';
  }

  @override
  String get a11yShareTabSwitch => 'Show';

  @override
  String get a11yPantryAddItem => 'Add new item';

  @override
  String get a11yPantryEditItem => 'Edit';

  @override
  String get a11yPantryPickExpiry => 'Open the calendar';

  @override
  String get a11yDraftRecoverTile => 'Restore';

  @override
  String get a11yShareModeOption => 'Press to select';

  @override
  String get a11yFriendRequestIncoming => 'Friend request, press to select';

  @override
  String a11yAcceptFriendRequestFrom(String name) {
    return 'Accept $name';
  }

  @override
  String a11yDeclineFriendRequestFrom(String name) {
    return 'Decline $name';
  }

  @override
  String get a11yFriendRequestSent => 'Sent request, press to select';

  @override
  String get a11yFeedFilter => 'Filter the feed';

  @override
  String get a11yFeedRecipePreview => 'Open recipe';

  @override
  String get a11yPublicProfileRecipeCard => 'Open recipe';

  @override
  String get a11yInvitationTargetCard => 'Invite';

  @override
  String get a11yPermissionsBanner => 'Permission';

  @override
  String get a11yEmojiPicker => 'Select as icon';

  @override
  String a11yRemoveIngredientChip(String label) {
    return 'Remove $label';
  }

  @override
  String a11yRemoveMember(String name) {
    return 'Remove $name';
  }

  @override
  String get a11yToggleFullscreenChrome => 'Show or hide controls';

  @override
  String get a11yCommentsToggle => 'Show or hide';

  @override
  String get a11yShowSubstitutionsFor => 'Show substitutions';

  @override
  String get a11yToggleStepDone => 'Mark as done or undone';

  @override
  String get a11yRemoveOwnRating => 'Remove my rating';

  @override
  String get a11yCookingStepLongPressTimer => 'Long-press to start timer';

  @override
  String get a11yStartTimerForPhrase => 'Start timer';

  @override
  String get a11yRecipeImageFullscreen => 'Show recipe image in fullscreen';

  @override
  String a11yHeroButton(String tooltip) {
    return '$tooltip';
  }

  @override
  String get a11yDismissParseQualityWarning => 'Dismiss import quality warning';

  @override
  String get a11yToggleShoppingCategory => 'Category';

  @override
  String shoppingCategoryProgress(int completed, int total) {
    return '$completed of $total';
  }

  @override
  String get a11yPollVoteOption => 'Vote';

  @override
  String a11yPollRecipeThumbnail(String title) {
    return 'Open recipe $title';
  }

  @override
  String get cookingModeSubstitutionApplied => 'Ingredient swapped';

  @override
  String get cookingModeSubstitutionFailed =>
      'The ingredient could not be swapped.';

  @override
  String get cookingModeOpenEditToSwap => 'Open edit mode to swap';

  @override
  String get feedbackEmailHint => 'you@email.com';

  @override
  String get dialogEmailLabel => 'Email';

  @override
  String get dialogEmailHint => 'you@email.com';

  @override
  String get dialogUrlLabel => 'URL';

  @override
  String get dialogUrlHint => 'https://example.com';

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
  String get a11yToggleConfidenceSection => 'Show or hide';

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
  String get a11yRelatedRecipeChip => 'Linked recipe';

  @override
  String get a11yRemoveRelatedRecipe => 'Remove link';

  @override
  String get a11yRelatedRecipeThumbnail => 'Open related recipe';

  @override
  String get familyTitle => 'My household';

  @override
  String get familyIntro =>
      'The household shares recipes, menus and shopping lists. Guests without an account can still rate the food.';

  @override
  String get familyRoleAdmin => 'admin';

  @override
  String get ageBandToddler => 'baby';

  @override
  String get ageBandChild => 'child';

  @override
  String get ageBandTeen => 'teen';

  @override
  String get ageBandAdult => 'adult';

  @override
  String get familyAddTitle => 'Add guest';

  @override
  String get familyEditTitle => 'Edit guest';

  @override
  String get familyNameLabel => 'name';

  @override
  String get familyNameHint =>
      'A nickname or initial is enough – we don\'t need a full name.';

  @override
  String get familyColorLabel => 'colour';

  @override
  String get familyAgeBandLabel => 'age group';

  @override
  String get familyAgeBandHint =>
      'Coarse age group only – no birth date is stored.';

  @override
  String get familyConsentSectionTitle => 'consent';

  @override
  String get familyConsentRequiredBadge => 'required';

  @override
  String familyGuardianConsentText(String name) {
    return 'I am the guardian and consent to $name\'s name and age group being stored to plan the household\'s meals. Meal ratings contribute anonymously to recipes\' public average ratings.';
  }

  @override
  String get familyAllergenSectionTitle => 'allergies & diet';

  @override
  String get familyOptionalBadge => 'optional';

  @override
  String get familyAllergenHealthNote =>
      'Allergy data counts as sensitive health data. You can save the profile without it and add it later.';

  @override
  String familyAllergenConsentText(String name) {
    return 'I explicitly consent to $name\'s allergy and dietary data (health data) being stored.';
  }

  @override
  String get familyConsentGivenPrefix => 'Consent given';

  @override
  String get familyWithdrawAllergenConsent =>
      'Withdraw consent & erase allergy data';

  @override
  String get familyDeleteMember => 'Delete guest';

  @override
  String get familyDeleteConfirmTitle => 'Delete this guest?';

  @override
  String get familyDeleteConfirmBody =>
      'The guest and all their ratings will be deleted. This cannot be undone.';

  @override
  String get a11yEditFamilyMember => 'Edit guest';

  @override
  String get familyConsentChildWord => 'the child';

  @override
  String get familyConsentPersonWord => 'the person';

  @override
  String a11yColorSwatch(int index) {
    return 'Avatar colour $index';
  }

  @override
  String get whoAteTitle => 'Who ate?';

  @override
  String whoAteConfirm(int count) {
    return 'done – $count ate';
  }

  @override
  String get whoAteSkip => 'Skip';

  @override
  String get a11yToggleDiner => 'Mark as eating';

  @override
  String get menuPresenceSheetTitle => 'Who\'s home?';

  @override
  String get menuPresenceThisMeal => 'This meal';

  @override
  String get menuPresenceWholeDay => 'Whole day';

  @override
  String get menuPresenceHome => 'home';

  @override
  String get menuPresenceAway => 'away';

  @override
  String menuPresenceHomeSummary(int home, int portions) {
    String _temp0 = intl.Intl.pluralLogic(
      portions,
      locale: localeName,
      other: '$portions servings',
      one: '1 serving',
    );
    return '$home home · $_temp0';
  }

  @override
  String get menuPresenceOpenRecipe => 'Open the recipe';

  @override
  String menuPresencePortions(int count) {
    return '$count serv';
  }

  @override
  String menuPresenceSlotSubtitle(String slot, String day) {
    return '$slot on $day';
  }

  @override
  String get menuPresenceAfterGenerateNotice =>
      'presence updated – planned meals stay put';

  @override
  String get menuPresenceSummaryTitle => 'Who’s home?';

  @override
  String get menuPresenceSummaryAllHome => 'Everyone home all week';

  @override
  String menuPresenceSummaryAway(String names) {
    return '$names away part of the week';
  }

  @override
  String a11yMenuSlotPresence(String slot, String day) {
    return 'Choose who\'s home for $slot $day';
  }

  @override
  String get familyRatingTitle => 'What did you think?';

  @override
  String get familyRatingYou => 'you';

  @override
  String get familyRatingSave => 'Save';

  @override
  String get familyRatingManualButton => 'Rate as a household';

  @override
  String familyRatingProxyNote(String name) {
    return 'entered by $name · doesn\'t change their own rating';
  }

  @override
  String a11yRateStarsForMember(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count stars',
      one: '1 star',
    );
    return 'Give $name $_temp0';
  }

  @override
  String get familyRatingSectionTitle => 'Household ratings';

  @override
  String get familyRatingAverageLabel => 'Household average';

  @override
  String familyRatingCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ratings',
      one: '1 rating',
    );
    return '$_temp0';
  }

  @override
  String familyRatingUpdated(String date) {
    return 'Updated $date';
  }

  @override
  String get familyRatingCommunityLabel => 'Everyone who cooked it';

  @override
  String get familyRatingYourOwnLabel => 'Your own rating';

  @override
  String get familyRatingLegend =>
      'Household ratings are private. Ink = household, grey = everyone, saffron = yours.';

  @override
  String a11yFamilyRatingPill(String rating) {
    return 'Household rating $rating';
  }

  @override
  String a11yAllaRatingPill(String rating) {
    return 'Everyone\'s rating $rating';
  }

  @override
  String butleryBetygCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count ratings',
      one: '1 rating',
    );
    return '$_temp0';
  }

  @override
  String a11yButleryBetygPill(String rating, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count votes',
      one: '1 vote',
    );
    return 'Butlery rating $rating, $_temp0';
  }

  @override
  String get pooledCommunityLabel => 'butlery rating';

  @override
  String get pooledHouseholdLabel => 'everyone in your kitchen';

  @override
  String get a11yPooledHouseholdPill => 'Your kitchen\'s rating';

  @override
  String familyRatingProxyEntered(String name) {
    return 'Entered by $name';
  }

  @override
  String get a11yToggleRatingBreakdown => 'Show or hide the overview';

  @override
  String get a11yEditMemberRating => 'Edit rating';

  @override
  String get deepLinkExpired =>
      'This link is no longer valid. Ask the person who shared it for a new one.';

  @override
  String get deepLinkUnavailable => 'This content is no longer available.';

  @override
  String get familyDislikesSectionTitle => 'disliked ingredients';

  @override
  String get familyDislikesNote =>
      'Dishes with these are avoided when possible. A taste preference, not a safety limit like allergies.';

  @override
  String get chatJoinedHereDivider => 'You joined here';

  @override
  String chatGroupMembersAddedCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count members added',
      one: '1 member added',
    );
    return '$_temp0';
  }

  @override
  String get chatGroupAddMembersBlocked =>
      'Some people could not be added to the group.';

  @override
  String get chatGroupAddMembersFailed =>
      'Could not add members. Please try again.';

  @override
  String get chatGroupNeedsAnotherMember =>
      'The group needs at least one more member before you can vote on a meal.';

  @override
  String get mealVotePollFailed =>
      'Could not start the vote. Please try again.';

  @override
  String get chatGroupCreateFailed =>
      'Could not create the group. Please try again.';

  @override
  String chatGroupTooManyMembers(int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max members',
      one: '1 member',
    );
    return 'A group can have at most $_temp0.';
  }

  @override
  String get chatDuplicateBlocked => 'You have already sent this';

  @override
  String get messageTypeDuplicateBlocked => 'Blocked';

  @override
  String get a11yDismissDuplicateNotice => 'Dismiss the notice';

  @override
  String get groupMenuNoDish => 'No dish chosen';

  @override
  String get groupMenuEmptyTitle => 'No dish has been voted in yet';

  @override
  String get groupMenuEmptyBody =>
      'Start a poll in the chat and the winner lands here.';

  @override
  String get groupMenuEmptyAction => 'Start a poll';

  @override
  String get groupMenuNotAMember =>
      'You do not have access to this week\'s menu.';

  @override
  String get groupMenuLoadFailed => 'Could not load the week.';

  @override
  String get groupMenuViewerNotice =>
      'You can see the group\'s menu but not change it.';

  @override
  String groupMenuWeekRange(int week, String range) {
    return 'Week $week · $range';
  }

  @override
  String get groupMenuChatAction => 'This week\'s menu';

  @override
  String get groupMenuPickGroupTitle => 'Choose group';

  @override
  String get groupMenuNoGroups => 'You are not in any group yet.';

  @override
  String get groupMenuDishRemoved => 'Dish removed';

  @override
  String get groupMenuSaveFailed => 'Could not save the change. Try again.';

  @override
  String get groupMenuUndoUnavailable => 'This can no longer be undone.';

  @override
  String groupMenuProposedBy(String name) {
    return 'Suggested by $name';
  }

  @override
  String groupMenuVotedInBy(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'voted in by $count',
      one: 'voted in by 1',
    );
    return '$_temp0';
  }

  @override
  String get groupMenuVotersTitle => 'Voted for this dish';

  @override
  String get a11yShowVoters => 'Show who voted';

  @override
  String get a11yGroupMenuDishDetails => 'Show proposal and votes';

  @override
  String get groupMenuUnknownVoter => 'Unknown member';

  @override
  String get groupMenuUndoFailed => 'Could not undo the removal.';

  @override
  String groupMenuWeekShort(int week) {
    return 'Week $week';
  }

  @override
  String get groupMenuGroupsLoadFailed => 'Could not fetch your groups.';

  @override
  String get groupMenuUntitledGroup => 'Untitled group';

  @override
  String get pollVoteFailed => 'Your vote could not be registered.';

  @override
  String socialRequestsAcceptedPartial(int succeeded, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total requests accepted',
      one: '1 request accepted',
    );
    return '$succeeded of $_temp0';
  }

  @override
  String socialRequestsRejectedPartial(int succeeded, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total requests rejected',
      one: '1 request rejected',
    );
    return '$succeeded of $_temp0';
  }

  @override
  String socialRequestsCancelledPartial(int succeeded, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total requests cancelled',
      one: '1 request cancelled',
    );
    return '$succeeded of $_temp0';
  }

  @override
  String get profileDeletionNoticeTitle => 'Your account has been deleted';

  @override
  String get profileDeletionNoticeWhat =>
      'One thing has been kept: an ongoing review of content that was reported.';

  @override
  String get profileDeletionNoticeWhy =>
      'Why: we have to be able to finish handling the report.';

  @override
  String profileDeletionNoticeHowLong(String date) {
    return 'How long: until the review is finished, at most $date.';
  }

  @override
  String get profileDeletionNoticeRights =>
      'You can complain to IMY or go to court if you disagree.';

  @override
  String get profileDeletionNoticeHowLongUnknown =>
      'How long: until the review is finished.';

  @override
  String get profileDeletionNoticeWhatUnclear =>
      'One thing may have been kept: we could not finish checking whether there is an ongoing review of content that was reported.';

  @override
  String get profileDeletionNoticeWhatOwnReport =>
      'One or more reports you made that have not finished being handled have been kept. Your name has been removed from them, but what you wrote is still there.';

  @override
  String get profileDeletionNoticeWhatBoth =>
      'The following has been kept: an ongoing review of content that was reported, and one or more reports you made that have not finished being handled. Your name has been removed from the reports, but what you wrote is still there.';

  @override
  String get profileDeletionNoticeWhatBothUnclear =>
      'One or more reports you made that have not finished being handled have been kept without your name but with what you wrote. One more thing may have been kept: we could not finish checking whether there is an ongoing review of content that was reported.';

  @override
  String get profileDeletionNoticeWhyHandling =>
      'Why: we have to be able to finish the handling.';

  @override
  String profileDeletionNoticeHowLongHandling(String date) {
    return 'How long: until the handling is finished, at most $date.';
  }

  @override
  String get profileDeletionNoticeHowLongHandlingUnknown =>
      'How long: until the handling is finished.';

  @override
  String get profileDeletionNoticeCollapsed =>
      'A message about a deleted account on this device.';

  @override
  String get profileDeleteAccountMayHaveReview =>
      'If there is an ongoing review of content you were reported for, we may need to keep that review even after the account is deleted. If so, it is kept until the case is closed, at most 180 days. If you want to be told right away when the account is deleted, sign in during the 7 days and choose Delete now.';

  @override
  String get shoppingLeaveList => 'Leave list';

  @override
  String shoppingLeaveListConfirm(String name) {
    return 'Leave “$name”? You will lose access to the list. This cannot be undone – the owner has to invite you again.';
  }

  @override
  String get shoppingLeave => 'Leave';

  @override
  String shoppingLeftList(String name) {
    return 'You have left “$name”';
  }

  @override
  String get shoppingCouldNotLeaveList => 'Could not leave the list';

  @override
  String get settingsAboutTitle => 'About Butlery';

  @override
  String settingsAboutVersion(String version) {
    return 'Version $version';
  }

  @override
  String get settingsLicensesTitle => 'Licences';

  @override
  String get settingsLicensesSubtitle => 'Typefaces and open source';

  @override
  String get licensesNoticesHeading => 'Butlery Sans – copyright and sources';

  @override
  String get licensesOflHeading => 'SIL Open Font License 1.1';

  @override
  String get licensesCouldNotLoad => 'The licence texts could not be loaded.';

  @override
  String get loadingProfileBusy => 'Loading your profile …';

  @override
  String get loadingOnboardingResume => 'Finding where you left off …';

  @override
  String get startSplashTagline => 'Your butler in the kitchen';

  @override
  String get startSplashBusy => 'Setting up your kitchen …';

  @override
  String get loadingOpeningPage => 'Opening the page …';

  @override
  String get loadingStartingApp => 'Starting Butlery …';

  @override
  String get recipeSaveToMyKitchen => 'Save to my kitchen';

  @override
  String get recipeAddToShoppingList => 'Add to shopping list';

  @override
  String get loadingCookSnaps => 'Loading the photos …';

  @override
  String get loadingSubstitutions => 'Loading substitutes …';

  @override
  String get uploadingCookSnap => 'Uploading the photo …';

  @override
  String get sendingComment => 'Sending the comment …';

  @override
  String get recipeEditorClose => 'Close the editor';

  @override
  String menuWeekBadgeEmpty(int week) {
    return 'Week $week · nothing planned';
  }

  @override
  String menuWeekBadgeOnly(int week) {
    return 'Week $week';
  }

  @override
  String get rootBarMoreActions => 'More actions';

  @override
  String get weekMenuPlanningSlow => 'This is taking longer than usual';

  @override
  String get importBatchSaveFailed =>
      'The recipes could not be saved. Try again.';

  @override
  String get weekMenuPlanningTitle => 'Planning the week …';

  @override
  String get menuLoadingSaved => 'Fetching saved menus …';

  @override
  String get shoppingRootTitle => 'Shopping';

  @override
  String shoppingRootLine(String listName, int done, int total) {
    return '$listName · $done of $total done';
  }

  @override
  String shoppingRootLineEmpty(String listName) {
    return '$listName · no items';
  }

  @override
  String get shoppingEmptyTitle => 'Nothing to buy';

  @override
  String get shoppingEmptyBody =>
      'Send the week\'s dishes here and the ingredients are gathered by category. What you already have in the pantry is left out.';

  @override
  String get shoppingFromWeekMenu => 'From the week menu';

  @override
  String get shoppingLoadingTemplates => 'Fetching the templates …';

  @override
  String get importFetchingRecipe => 'Fetching the recipe …';

  @override
  String get importReadingFile => 'Reading the file …';

  @override
  String get loadingLicenses => 'Loading the licences …';

  @override
  String get consentSaveMyChoices => 'Save my choices';

  @override
  String get loadingBlockedUsers => 'Loading blocked users …';

  @override
  String get accountDeletingProgress => 'Deleting the account …';

  @override
  String get loadingParseEvents => 'Loading the parse events …';

  @override
  String get loadingMoreActivity => 'Loading more activity …';

  @override
  String get menuPreviewTitle => 'Shared menu';

  @override
  String menuPreviewSharedLine(String name, String menu) {
    return '$name shared the menu $menu with you · read only';
  }

  @override
  String get menuPreviewDecline => 'Decline';

  @override
  String get emailVerificationResendFailed =>
      'The verification email could not be sent.';

  @override
  String emailVerificationResendFailedBecause(String cause) {
    return 'The verification email could not be sent. $cause';
  }

  @override
  String get emailVerificationAddressUnchanged =>
      'Your email address is unchanged.';

  @override
  String get chatPollCouldNotBeCreated => 'The poll could not be created.';

  @override
  String get chatEditCouldNotBeSaved => 'Your edit could not be saved.';

  @override
  String get chatEditOriginalKept => 'The message is unchanged.';

  @override
  String get chatCouldNotSendReply => 'The reply could not be sent.';

  @override
  String get errorPreservedText => 'Your text is still in the field.';

  @override
  String get errorPreservedForm => 'What you filled in is still here.';

  @override
  String get dialogActionFailed => 'The action could not be completed.';

  @override
  String get minaReceptRefreshFailed => 'Your recipes could not be refreshed.';

  @override
  String get minaReceptRefreshPreserved =>
      'Your saved recipes are shown below.';

  @override
  String get shoppingLeaveListStillMember =>
      'You are still a member of the list.';

  @override
  String get cookingModeRecipeUnchanged => 'The recipe is unchanged.';

  @override
  String get accountSecurityPasswordChangeFailed =>
      'The password could not be changed.';

  @override
  String accountSecurityPasswordChangeFailedBecause(String cause) {
    return 'The password could not be changed. $cause';
  }

  @override
  String get accountSecurityEmailChangeFailed =>
      'The email address could not be changed.';

  @override
  String accountSecurityEmailChangeFailedBecause(String cause) {
    return 'The email address could not be changed. $cause';
  }

  @override
  String get recipeSaveFailed => 'The recipe could not be saved.';

  @override
  String get recipeCopySaveFailed => 'The copy could not be saved.';

  @override
  String get recipeSaveIncomplete =>
      'The recipe could not be saved. It needs a title, at least one ingredient and at least one step.';

  @override
  String get recipeSaveNoPermission =>
      'The recipe could not be saved. You do not have permission to edit it.';

  @override
  String get errorPreservedRecipeEdits => 'Your changes are still in the form.';

  @override
  String get groupAddMembersLoadFailed => 'Your friends could not be loaded.';

  @override
  String get adminFeedbackLoadFailed => 'The feedback could not be fetched.';

  @override
  String get moderatorReportsLoadFailed => 'The reports could not be fetched.';

  @override
  String get legalGuidelinesCouldNotLoad =>
      'The guidelines could not be loaded.';

  @override
  String get legalTermsCouldNotLoad =>
      'The terms of service could not be loaded.';

  @override
  String get legalLinksNeedConnection =>
      'The web links open when you are connected again.';

  @override
  String get imageCouldNotBeShown => 'The image could not be shown';

  @override
  String get errorPartNotShown => 'This part could not be shown.';

  @override
  String get recipeAddPhoto => 'Add photo';

  @override
  String get imageRetriesWhenOnline =>
      'Tries again when the connection is back';

  @override
  String get ingredientSearchAgain => 'Search again';

  @override
  String get ingredientSearchSelectionKept =>
      'Your ingredients are still selected.';

  @override
  String weeklyMenuOverflowPlacedCount(int placed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total dishes placed',
      one: '1 dish placed',
    );
    return '$placed of $_temp0';
  }

  @override
  String weeklyMenuOverflowReason(int week) {
    return 'Week $week had no more free places for these.';
  }

  @override
  String get weeklyMenuOverflowPastDays =>
      'Days that have already passed are never filled.';

  @override
  String weeklyMenuOverflowKeepOrNextWeek(int week) {
    return 'They stay here until you place them or put them in week $week.';
  }

  @override
  String get weeklyMenuOverflowKeep => 'They stay here until you place them.';

  @override
  String weeklyMenuOverflowNextWeekAction(int week) {
    return 'Put in week $week';
  }

  @override
  String weeklyMenuOverflowNextWeekA11y(int count, int week) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Put the $count in week $week',
      one: 'Put it in week $week',
    );
    return '$_temp0';
  }

  @override
  String weeklyMenuOverflowMovedToNextWeek(int count, int week) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dishes added to week $week',
      one: '1 dish added to week $week',
    );
    return '$_temp0';
  }

  @override
  String a11yWeeklyMenuPlacementOrder(int order) {
    return 'Placed as number $order';
  }

  @override
  String menuPartialTitle(int found, int requested) {
    String _temp0 = intl.Intl.pluralLogic(
      requested,
      locale: localeName,
      other: '$requested dishes',
      one: '1 dish',
    );
    return 'We found $found of $_temp0';
  }

  @override
  String get menuPartialBody => 'There were no more recipes that match.';

  @override
  String menuPartialMissing(int found, int requested, int missing) {
    return '$found of $requested, $missing missing';
  }

  @override
  String get weeklyMenuSaveFailed => 'The week could not be saved.';

  @override
  String get pantryItemUpdateFailed => 'The item could not be updated.';

  @override
  String get moderatorAdvanceFailed =>
      'The report could not be moved to the next step.';

  @override
  String get moderatorCloseFailed => 'The report could not be closed.';

  @override
  String get moderatorReportUnchanged => 'The report is unchanged.';

  @override
  String get moderatorHideFailed => 'The profile could not be hidden.';

  @override
  String get moderatorHidePreserved => 'The profile is still visible.';

  @override
  String get moderatorDeleteFailed => 'The content could not be removed.';

  @override
  String get moderatorDeletePreserved => 'The content is still there.';

  @override
  String get adminFeedbackStatusFailed => 'The status could not be changed.';

  @override
  String get adminFeedbackStatusPreserved =>
      'The feedback keeps its earlier status.';

  @override
  String get weekPlacementFailedWeekUnchanged =>
      'The week is unchanged and the menu you made is still here.';

  @override
  String get weekPlacementFailedMenuKept => 'The menu you made is still here.';

  @override
  String get menuShoppingListGenerationPreserved => 'The week is unchanged.';

  @override
  String get importErrorNotImported => 'The recipe could not be imported.';

  @override
  String get importFailurePreservedLink => 'The link is still in the field.';

  @override
  String get importFailurePreservedText => 'The text is still in the field.';

  @override
  String get importFailureOtherRoutes => 'Other ways to the same recipe';

  @override
  String get importRoutePhoto => 'Photograph the screen';

  @override
  String get importRoutePasteText => 'Paste the text yourself';

  @override
  String get duplicateMergeFailedPreserved =>
      'The existing recipe is unchanged.';

  @override
  String get conflictDiffUseTheirs => 'Use their version';

  @override
  String get conflictDiffCloseWithoutOverwrite => 'Close without overwriting';

  @override
  String get conflictDiffUsedTheirs => 'Their version applies now';

  @override
  String get conflictDiffUseTheirsFailed => 'Their version could not be saved.';

  @override
  String get conflictDiffUseTheirsKept => 'Your version still applies.';

  @override
  String get conflictWeekKeepMine => 'Keep mine';

  @override
  String get partialOutcomeDone => 'Done';

  @override
  String groupMembersPartialTitle(int removed, int total) {
    return '$removed of $total were removed';
  }

  @override
  String get groupMembersPartialMessage =>
      'The ones that could not be removed stay selected above.';

  @override
  String groupMembersPartialRemoved(String names, String group) {
    return 'No longer in $group: $names.';
  }

  @override
  String get partialOutcomeListAnd => ' and ';

  @override
  String get groupMemberRemoveNotSaved =>
      'Could not be removed – the change was not saved';

  @override
  String get groupMemberRemoveFailedNoPermission =>
      'You can no longer change the group';

  @override
  String get groupMemberRemoveFailedNotSaved => 'The change was not saved';

  @override
  String get groupMemberRemoveFailedGroupMissing =>
      'The group no longer exists';

  @override
  String a11yMemberRemoveFailed(String name) {
    return '$name, selected, could not be removed';
  }

  @override
  String get groupMembersRemoveNone =>
      'None of the selected members could be removed.';

  @override
  String get selectionFailedKept => 'They stay selected.';

  @override
  String personalTagBulkDeletePartialTitle(int deleted, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total tags',
      one: '1 tag',
    );
    return '$deleted of $_temp0 were deleted';
  }

  @override
  String get personalTagBulkDeletePartialMessage =>
      'The ones that could not be deleted stay selected.';

  @override
  String personalTagBulkDeletePartialDeleted(String names) {
    return 'Deleted: $names.';
  }

  @override
  String get personalTagBulkDeleteNotSaved =>
      'Could not be deleted – the deletion was not saved';

  @override
  String get personalTagBulkDeleteNone => 'The tags could not be deleted.';

  @override
  String get overwrittenRestoreAction => 'Restore my version';

  @override
  String get overwrittenPickTitle => 'Which version do you want to restore?';

  @override
  String overwrittenVersionFrom(String when) {
    return 'Your version from $when';
  }

  @override
  String overwrittenVersionBy(String name, String until) {
    return '$name saved over it · kept until $until';
  }

  @override
  String overwrittenVersionByUnnamed(String until) {
    return 'Someone else saved over it · kept until $until';
  }

  @override
  String overwrittenWhenToday(String time) {
    return 'today $time';
  }

  @override
  String get overwrittenWhenYesterday => 'yesterday';

  @override
  String get overwrittenConfirmTitleWeek => 'Restore your week?';

  @override
  String get overwrittenConfirmTitleRecipe => 'Restore your recipe?';

  @override
  String overwrittenConfirmBodyWeek(String when) {
    return 'Your version from $when replaces the week as it is now. You can undo right after.';
  }

  @override
  String overwrittenConfirmBodyRecipe(String when) {
    return 'Your version from $when replaces the recipe as it is now. You can undo right after.';
  }

  @override
  String get overwrittenRestored => 'Your version is restored';

  @override
  String get overwrittenRestoreFailed => 'Your version couldn\'t be restored';

  @override
  String get overwrittenRestoreGoneWeek =>
      'The week no longer exists, so your version could not be restored';

  @override
  String get overwrittenRestoreGoneRecipe =>
      'The recipe no longer exists, so your version could not be restored';

  @override
  String overwrittenKeptUntil(String until) {
    return 'It\'s kept until $until.';
  }

  @override
  String get overwrittenUndoFailed => 'Undo couldn\'t finish';

  @override
  String get overwrittenUndoFailedKept =>
      'Your restored version still applies.';

  @override
  String get messagingCreateConversation => 'Create conversation';

  @override
  String get reportDialogTitleRecipe => 'Report this recipe';

  @override
  String get reportDialogGuidelinesNoteSuffix =>
      '– the version you see now is the one we judge by.';

  @override
  String get reportDialogIntro =>
      'Tell us what is wrong. A person on the team reads your report.';

  @override
  String get reportDescriptionRequiredHelper =>
      'Required when you choose Other.';

  @override
  String get menuNoMatchTitle => 'No recipes match';

  @override
  String menuNoMatchBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The description gives no matches among your $count recipes.',
      one: 'The description gives no match for your only recipe.',
    );
    return '$_temp0 Change or drop a requirement and we will find suggestions.';
  }

  @override
  String menuNoMatchConstraints(String constraints) {
    return 'Requirements: $constraints';
  }

  @override
  String get menuNoMatchEditPrompt => 'Change the description';

  @override
  String get menuNoMatchPlanYourself => 'Plan the days yourself';

  @override
  String get menuGenerateOfflineReason =>
      'No connection, so the week cannot be planned now. You can still change the calendar.';

  @override
  String get menuGenerateOfflineStopped =>
      'The connection dropped, so the suggestion was not placed. The week is unchanged.';

  @override
  String get shoppingMergeTitle => 'To the shopping list';

  @override
  String shoppingMergeItemCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$_temp0';
  }

  @override
  String shoppingMergeSummary(int recipes, int rows, String items) {
    String _temp0 = intl.Intl.pluralLogic(
      recipes,
      locale: localeName,
      other: '$recipes dishes give',
      one: '1 dish gives',
    );
    String _temp1 = intl.Intl.pluralLogic(
      rows,
      locale: localeName,
      other: '$rows lines',
      one: '1 line',
    );
    return '$_temp0 $_temp1. After merging that is $items.';
  }

  @override
  String get shoppingMergeStatMerged => 'merged';

  @override
  String get shoppingMergeStatConverted => 'converted';

  @override
  String get shoppingMergeStatAtHome => 'at home';

  @override
  String get shoppingMergeShowDetails => 'Show details';

  @override
  String get shoppingMergeHideDetails => 'Hide details';

  @override
  String get shoppingMergeShowDetailsA11y => 'Show details about the merge';

  @override
  String get shoppingMergeHideDetailsA11y => 'Hide details about the merge';

  @override
  String get shoppingMergeDuplicatesTitle => 'Merge duplicates';

  @override
  String get shoppingMergeDuplicatesBody =>
      'Yellow onion from three recipes becomes one line with the amounts added up. The line says “3 recipes”.';

  @override
  String get shoppingMergeConvertTitle => 'Convert units';

  @override
  String get shoppingMergeConvertBody =>
      '2 dl + 100 ml becomes 3 dl. Volume and weight are never converted into each other – they stay two lines.';

  @override
  String get shoppingMergePantryTitle => 'Subtract pantry items';

  @override
  String shoppingMergePantryBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items are at home.',
      one: '1 item is at home.',
      zero: 'None of the items are at home.',
    );
    return '$_temp0 An unknown amount gives no deduction – the item is added marked “Maybe at home”.';
  }

  @override
  String shoppingMergePantryCovered(String names) {
    return 'At home in full: $names';
  }

  @override
  String get shoppingMergePantryUnavailable =>
      'The pantry could not be read, so the list is made without pantry deduction.';

  @override
  String get shoppingMergeReplaceTitle => 'Replace the list instead of adding';

  @override
  String get shoppingMergeReplaceBody =>
      'Items you added yourself are always kept.';

  @override
  String get shoppingMergeReplaceUnavailable =>
      'This list was made before the app kept the week\'s items apart from your own, so it cannot be replaced. The week\'s items are added.';

  @override
  String shoppingMergeAdd(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count items',
      one: 'Add 1 item',
    );
    return '$_temp0';
  }

  @override
  String shoppingMergeReplaceAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Replace with $count items',
      one: 'Replace with 1 item',
    );
    return '$_temp0';
  }

  @override
  String shoppingMergeAdded(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items were added to $list.',
      one: '1 item was added to $list.',
    );
    return '$_temp0';
  }

  @override
  String shoppingMergeReplaced(int count, String list) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items',
      one: '1 item',
    );
    return '$list now has $_temp0 from the week. Your own items are still there.';
  }

  @override
  String shoppingMergeConcurrentChange(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'The list had been changed on another device. Your $count items were added and nothing was overwritten.',
      one:
          'The list had been changed on another device. Your item was added and nothing was overwritten.',
    );
    return '$_temp0';
  }

  @override
  String get shoppingMergeUndoFailed => 'The undo could not be completed';

  @override
  String get shoppingMergeUndoFailedKept => 'The items are still on the list.';

  @override
  String shoppingMergeRowRecipes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return '$_temp0';
  }

  @override
  String get shoppingMergeMarkMaybeHome => 'Maybe at home';

  @override
  String get shoppingMergeMarkCheckDate => 'Check the date';

  @override
  String signOutPendingTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes have not been saved',
      one: '1 change has not been saved',
    );
    return '$_temp0';
  }

  @override
  String get signOutPendingBody =>
      'If you sign out now, they are lost. Butlery is happy to wait until you are online again.';

  @override
  String signOutPendingRecipes(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Recipes · $count changes',
      one: 'Recipes · 1 change',
    );
    return '$_temp0';
  }

  @override
  String signOutPendingImages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Images · $count waiting to upload',
      one: 'Images · 1 waiting to upload',
    );
    return '$_temp0';
  }

  @override
  String get signOutPendingWait => 'Wait for sync';

  @override
  String get signOutPendingDiscard => 'Sign out and discard the changes';

  @override
  String sessionPendingChangesIntro(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes have not been saved yet:',
      one: '1 change has not been saved yet:',
    );
    return '$_temp0';
  }

  @override
  String get sessionEndedBackgroundTitle =>
      'You were signed out while the app lay still.';

  @override
  String get sessionEndedBackgroundReason =>
      'That happens after 45 minutes without activity, and it is meant to.';

  @override
  String sessionEndedBackgroundPending(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          '$count changes are still on the phone and are sent as soon as you are back in – nothing you did is lost.',
      one:
          '1 change is still on the phone and is sent as soon as you are back in – nothing you did is lost.',
      zero: 'No changes are waiting.',
    );
    return '$_temp0';
  }

  @override
  String draftTimeLeftDays(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'kept for $count more days',
      one: 'kept for 1 more day',
    );
    return '$_temp0';
  }

  @override
  String weekMenuDraftResumeTitle(String when) {
    return 'Week menu started $when';
  }

  @override
  String weekMenuDraftDaysDone(int count) {
    return '$count of 7 days done';
  }

  @override
  String get weekMenuDraftDayEmpty => 'no dish';

  @override
  String weekMenuDraftDropped(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dishes no longer fit and were removed',
      one: '1 dish no longer fits and was removed',
    );
    return '$_temp0';
  }

  @override
  String get weekMenuDraftRestoreFailed =>
      'The week menu could not be restored';

  @override
  String get weekMenuDraftRestoreFailedKept => 'The draft is still here.';

  @override
  String draftTimeLeftHours(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'kept for $count more hours',
      one: 'kept for 1 more hour',
    );
    return '$_temp0';
  }

  @override
  String get profileDeleteNoRecallWindow =>
      'The account is deleted after 7 days. If you sign in before then, you can undo the deletion.';

  @override
  String get profileDeleteReasonLabel => 'Why are you deleting your account?';

  @override
  String get profileDeleteReasonHint => 'For example: no longer using the app';

  @override
  String get profileDeleteReasonHelp =>
      'The reason goes into the audit record. It is the only trace left afterwards, which is why we ask before.';

  @override
  String get accountDeletionWaitNotice =>
      'This can take up to nine minutes. Do not close the app – the deletion continues on the server, but you get no receipt if you leave.';

  @override
  String get accountDeletionReauthTitle => 'Confirm it is you';

  @override
  String get accountDeletionReauthBody =>
      'For security, deleting an account needs a sign-in that is at most five minutes old. Sign in again and the deletion continues where it was.';

  @override
  String get accountDeletionReauthCancel => 'Cancel the deletion';

  @override
  String get accountDeletionReauthConfirm => 'Sign in again';

  @override
  String get accountDeletionPartialTitle => 'The account is partly deleted';

  @override
  String accountDeletionPartialHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The account is gone – $count parts remain',
      one: 'The account is gone – one part remains',
    );
    return '$_temp0';
  }

  @override
  String accountDeletionPartialBody(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other:
          'Your sign-in is deleted. $count parts of your data could not be deleted and remain with us.',
      one:
          'Your sign-in is deleted. One part of your data could not be deleted and remains with us.',
    );
    return '$_temp0';
  }

  @override
  String get accountDeletionPartialAuditIdLabel => 'Audit id';

  @override
  String get accountDeletionPartialNoAuditId =>
      'There is no audit id. Mention the date and time of the deletion when you contact support.';

  @override
  String get accountDeletionPartialContact => 'Contact support with the id';

  @override
  String accountDeletionPartialEmailSubject(String auditId) {
    return 'Partly deleted account $auditId';
  }

  @override
  String get accountDeletionPartialNoEmail =>
      'The email app could not be opened. Write to integritet@butlery.se and include the audit id.';

  @override
  String get dataExportMemoryNotice =>
      'Save the file before you leave this page. It only lives in the phone\'s memory – if you go back, you have to export again.';

  @override
  String get dataExportNetworkTitle => 'The export was interrupted';

  @override
  String get dataExportNetworkBody =>
      'The connection dropped while we gathered your data. Nothing on your account has changed.';

  @override
  String get dataExportNoPartialFile =>
      'We do not offer a partial file. Whoever receives your data cannot tell what is missing from it.';

  @override
  String get dataExportSignedOutTitle => 'Your sign-in has expired';

  @override
  String get dataExportSignedOutBody =>
      'Sign in again to get your data. Nothing on your account has changed.';

  @override
  String get dataExportSignIn => 'Sign in again';

  @override
  String get dataExportDeniedTitle => 'The export was refused';

  @override
  String get dataExportDeniedBody =>
      'The fault is ours, not yours, and trying again will not help right now. Nothing on your account has changed.';

  @override
  String get dataExportNotNow => 'Not now';

  @override
  String get consentAiProcessing => 'AI interpretation';

  @override
  String get consentAiProcessingDescription =>
      'Reads recipes from links, text and photos. Without it, imports are rougher.';

  @override
  String consentRenewalChangedTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'We have changed $count things',
      one: 'We have changed one thing',
    );
    return '$_temp0';
  }

  @override
  String consentRenewalSinceVersion(String version, String date) {
    return 'You agreed to version $version on $date. This is new since then.';
  }

  @override
  String consentRenewalUnchanged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'The other $count purposes are unchanged and your choices stand.',
      one: 'The other purpose is unchanged and your choice stands.',
    );
    return '$_temp0';
  }

  @override
  String get consentRenewalAccept => 'I agree';

  @override
  String get consentRenewalChooseMyself => 'Let me choose';

  @override
  String get consentRenewalNotNow => 'Not now';

  @override
  String get consentRenewalNotNowNote =>
      'If you choose Not now, everything continues as before. Nothing is switched off because you have not answered.';

  @override
  String get consentChangeAiProcessingAddedTitle =>
      'AI interpretation is a new purpose';

  @override
  String get consentChangeAiProcessingAddedBody =>
      'Reads recipes from links, text and photos. It stays off until you switch it on yourself under Let me choose.';

  @override
  String get consentRenewalSaveFailed =>
      'Your consent could not be saved. Your earlier choices stand.';

  @override
  String get signOutDiscardFailed =>
      'The changes could not be discarded, so you are still signed in.';

  @override
  String get mfaChallengeTitle => 'Two-step verification';

  @override
  String get mfaChallengeHeading => 'Enter the code';

  @override
  String get mfaChallengeWrongCode =>
      'The code does not match. Take the latest code for Butlery in your authenticator app and try again.';

  @override
  String get mfaChallengeFailed =>
      'The sign-in could not be completed. Go back and sign in again.';

  @override
  String get mfaBackupCodeUse => 'Use a backup code';

  @override
  String get mfaBackupCodeHeading => 'Sign in with a backup code';

  @override
  String get mfaBackupCodeExplanation =>
      'A backup code lets you in without your authenticator app. It works only once, and two-step verification is switched off until you switch it on again.';

  @override
  String get mfaBackupCodeLabel => 'Backup code';

  @override
  String get mfaBackupCodeEnter => 'Enter one of your ten backup codes.';

  @override
  String get mfaBackupCodeSubmit => 'Sign in with the backup code';

  @override
  String get mfaBackupCodeBack => 'Back to the code from the app';

  @override
  String get mfaBackupCodeRejected =>
      'The password or the backup code does not match. A used code cannot be used again.';

  @override
  String get mfaBackupCodeLocked =>
      'Too many backup code attempts. Try again later; it can take up to an hour.';

  @override
  String get mfaBackupCodeUnavailable =>
      'The backup code could not be checked right now. Nothing on your account has changed.';

  @override
  String get mfaBackupCodeRecovered =>
      'Two-step verification is off. Switch it on again under Account security.';

  @override
  String get mfaBackupCodesTitle => 'Ten backup codes';

  @override
  String get mfaBackupCodesBody =>
      'Write them down or keep them somewhere safe before the protection is switched on. Without your authenticator app, you get in with a backup code, and each code works once. They are only shown now.';

  @override
  String get mfaBackupCodesCopy => 'Copy the codes';

  @override
  String get mfaBackupCodesCopied =>
      'The codes are copied. The clipboard is cleared in a minute.';

  @override
  String get mfaBackupCodesSaved => 'I have saved the codes';

  @override
  String get mfaBackupCodesContinue => 'Continue to the authenticator app';

  @override
  String get mfaBackupCodesFailed =>
      'The backup codes could not be created, so two-step verification was not switched on. Nothing has changed.';

  @override
  String get mfaErrorUnverifiedEmail =>
      'Two-step verification was not switched on, because your email address is not verified. Open the email we sent you, tap the verification link and try again.';

  @override
  String get mfaErrorRequiresRecentLogin =>
      'Two-step verification was not switched on, because your sign-in is too old. Sign out, sign in again and try once more.';

  @override
  String get mfaAppTitle => 'Authenticator app';

  @override
  String get mfaAppIntro =>
      'With two-step verification on, we ask for a six-digit code from an authenticator app when you sign in, for example Google Authenticator or Microsoft Authenticator. First you get ten backup codes.';

  @override
  String get mfaTurnOn => 'Switch on two-step verification';

  @override
  String get mfaSetupTitle => 'Add Butlery to your authenticator app';

  @override
  String get mfaSetupOpenApp => 'Open in authenticator app';

  @override
  String get mfaSetupKeyIntro =>
      'Add an account in the app and type in this key:';

  @override
  String get mfaSetupKeyIntroAlternative =>
      'Or add an account by hand in the app and type in this key:';

  @override
  String get mfaSetupCopyKey => 'Copy the key';

  @override
  String get mfaSetupKeyCopied =>
      'The key is copied. The clipboard is cleared in a minute.';

  @override
  String get mfaSetupOpenFailed =>
      'No authenticator app opened. Install one, or type the key in by hand.';

  @override
  String get mfaSetupCodeIntro =>
      'Then type the six-digit code the app shows for Butlery.';

  @override
  String get mfaSetupConfirm => 'Confirm';

  @override
  String get mfaSetupFailed =>
      'Two-step verification could not be prepared, so it was not switched on. Nothing has changed.';

  @override
  String get mfaChallengeAppPrompt =>
      'Open your authenticator app and type the six-digit code for Butlery.';

  @override
  String get permAllow => 'Allow';

  @override
  String get permNotNow => 'Not now';

  @override
  String get permAskAgain => 'Ask again';

  @override
  String get permOpenSettings => 'Open settings';

  @override
  String get permImportCameraTitle => 'Photograph the recipe';

  @override
  String get permImportCameraBody =>
      'We read the text in the photo and fill in the recipe for you. The photo is sent only to read the text.';

  @override
  String get permImportPhotosTitle => 'Choose photos of the recipe';

  @override
  String get permImportPhotosBody =>
      'We read the text in the photos you choose and fill in the recipe for you.';

  @override
  String get permImportConsequence =>
      'If you say no, you can still type the recipe or paste a link.';

  @override
  String get permCameraTitle => 'Take a photo with the camera';

  @override
  String get permCameraBody =>
      'The camera is only used when you take a photo yourself.';

  @override
  String get permPhotosTitle => 'Choose photos from your library';

  @override
  String get permPhotosBody => 'Butlery only reads the photos you choose.';

  @override
  String get permCameraDenied =>
      'The camera is not allowed, so the recipe cannot be photographed.';

  @override
  String get permPhotosDenied =>
      'The photo library is not allowed, so the recipe cannot be read from a photo.';

  @override
  String get permCameraDeniedImage =>
      'The camera is not allowed, so the photo cannot be taken.';

  @override
  String get permPhotosDeniedImage =>
      'The photo library is not allowed, so the photo cannot be chosen.';

  @override
  String get permCameraPermanentlyDenied =>
      'The camera is switched off for Butlery in the phone\'s settings.';

  @override
  String get permPhotosPermanentlyDenied =>
      'The photo library is switched off for Butlery in the phone\'s settings.';

  @override
  String get permCameraRestricted =>
      'This device blocks the camera. It cannot be changed here.';

  @override
  String get permPhotosRestricted =>
      'This device blocks the photo library. It cannot be changed here.';

  @override
  String get permFallbackGallery => 'Choose from the library';

  @override
  String get permFallbackWriteYourself => 'Write it yourself';

  @override
  String get permPhotosLimited =>
      'You have shared some photos with Butlery. We only see those.';

  @override
  String get permPhotosLimitedHint =>
      'If you cannot find the photo, it is missing from your selection, not from the library. You can add more without giving us the whole library.';

  @override
  String get permPhotosChooseMore => 'Choose more photos';

  @override
  String get timerNotifDeniedTitle => 'The timer only shows in the app';

  @override
  String get timerNotifDeniedBody =>
      'Notifications are off for Butlery, so the timer cannot alert you while the app is in the background or the phone is locked.';

  @override
  String get timerNotifDeniedStart => 'Start the timer';

  @override
  String get timerInAppOnly => 'The timer only shows in the app.';

  @override
  String get notifSystemOffRow =>
      'Notifications are off for Butlery in the system settings. Nothing below can be switched on until you change that there.';

  @override
  String get a11yOpenSystemSettings => 'Open the system settings';

  @override
  String get cookingExitConfirmTitle => 'Stop cooking?';

  @override
  String cookingExitConfirmBody(int step, int total) {
    return 'You are on step $step of $total. The recipe does not count as cooked until you tap Done.';
  }

  @override
  String get cookingExitConfirmStay => 'Keep cooking';

  @override
  String get cookingExitConfirmLeave => 'Stop cooking';

  @override
  String get cookingDone => 'Done';

  @override
  String get cookingNoStepsTitle => 'The recipe has no steps yet';

  @override
  String get cookingNoStepsBody =>
      'The ingredients are there, but nobody has written how to make it. Write the steps, or take the ingredients to the shopping list.';

  @override
  String get cookingNoStepsBodyNoIngredients =>
      'Nobody has written how to make it yet. Write the steps and you can cook from here.';

  @override
  String get cookingNoStepsWrite => 'Write the steps';

  @override
  String get cookingNoStepsShopping => 'To the shopping list';

  @override
  String get parseConfidenceConfirm => 'Correct';

  @override
  String get parseConfidenceConfirmed => 'Confirmed';

  @override
  String a11yParseConfidenceConfirm(String line) {
    return 'Confirm the line $line';
  }

  @override
  String parseConfidencePendingSave(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Confirm $count lines before you save',
      one: 'Confirm 1 line before you save',
    );
    return '$_temp0';
  }

  @override
  String get parseConfidenceUnreadLine => 'The line could not be read';

  @override
  String get a11yParseConfidenceUnreadLine => 'A line that could not be read';

  @override
  String importReadPages(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Read $count pages',
      one: 'Read 1 page',
    );
    return '$_temp0';
  }

  @override
  String get roleLoweredRecipeTitle => 'You can no longer edit the recipe';

  @override
  String get roleLoweredRecipeBody =>
      'You can now only read the recipe, so the changes are not saved to it. You can save them as your own copy.';

  @override
  String get roleLoweredSaveCopy => 'Save as your own copy';

  @override
  String get roleLoweredDiscard => 'Discard the changes';

  @override
  String get roleLoweredRecipeClosed =>
      'You can no longer edit the recipe, only read it.';

  @override
  String get roleLoweredShoppingList =>
      'You can no longer change the list, only read it.';

  @override
  String get roleLoweredShoppingUnsaved =>
      'What you typed was not added to the list:';

  @override
  String get roleLoweredCopyText => 'Copy the text';

  @override
  String get roleLoweredTextCopied => 'The text is copied.';

  @override
  String get roleLoweredGroupMenu =>
      'You can no longer change the group\'s menu, only read it.';

  @override
  String get conflictBannerTitleSuggestion => 'The owner\'s version stays';

  @override
  String conflictBannerBodySuggestion(String name) {
    return '$name changed it at the same time. Your change is kept as a suggestion for 7 days.';
  }

  @override
  String get conflictBannerBodySuggestionUnnamed =>
      'Someone else changed it at the same time. Your change is kept as a suggestion for 7 days.';

  @override
  String conflictBannerBodyMemberNotSent(String name) {
    return '$name changed it at the same time. Your change was not saved to the recipe and was not sent as a suggestion.';
  }

  @override
  String get conflictBannerBodyMemberNotSentUnnamed =>
      'Someone else changed it at the same time. Your change was not saved to the recipe and was not sent as a suggestion.';

  @override
  String get recipeSuggestionSeeMine => 'See your suggestion';

  @override
  String get recipeSuggestionSee => 'See the suggestion';

  @override
  String recipeSuggestionFromOne(String name) {
    return '$name suggests a change to the recipe.';
  }

  @override
  String get recipeSuggestionFromOneUnnamed =>
      'A member suggests a change to the recipe.';

  @override
  String recipeSuggestionFromMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suggested changes are',
      one: '1 suggested change is',
    );
    return '$_temp0 waiting for you.';
  }

  @override
  String recipeSuggestionMinePending(String date) {
    return 'Your suggestion is waiting for the owner. It is kept until $date.';
  }

  @override
  String get recipeSuggestionMineAccepted =>
      'The owner took your suggestion into the recipe.';

  @override
  String recipeSuggestionMineDismissed(String date) {
    return 'The owner dismissed your suggestion. It is kept until $date.';
  }

  @override
  String get recipeSuggestionTitle => 'Suggested change';

  @override
  String recipeSuggestionIntroOwner(String name, String title) {
    return '$name suggests a change to $title. Your recipe only changes if you use the suggestion.';
  }

  @override
  String recipeSuggestionIntroMine(String title) {
    return 'You suggested a change to $title. The recipe only changes if the owner uses the suggestion.';
  }

  @override
  String get recipeSuggestionSuggestedLabel => 'Suggestion';

  @override
  String get recipeSuggestionCurrentLabel => 'Now';

  @override
  String get recipeSuggestionAccept => 'Use the suggestion';

  @override
  String get recipeSuggestionDismiss => 'Dismiss the suggestion';

  @override
  String get recipeSuggestionAccepted =>
      'The suggestion is now part of the recipe.';

  @override
  String get recipeSuggestionDismissed =>
      'The suggestion is dismissed. The recipe is unchanged.';

  @override
  String get recipeSuggestionAcceptFailed =>
      'The suggestion could not be taken into the recipe.';

  @override
  String get recipeSuggestionDismissFailed =>
      'The suggestion could not be dismissed.';

  @override
  String recipeSuggestionKeptUntil(String date) {
    return 'The suggestion is kept until $date.';
  }

  @override
  String get recipeSuggestionRecipeGone =>
      'The recipe no longer exists, so the suggestion cannot be taken in.';

  @override
  String get recipeSuggestionLoadFailed =>
      'The suggestion could not be compared with the recipe. Check the connection.';

  @override
  String get recipeSuggestionNoChanges =>
      'The suggestion is the same as the recipe now.';

  @override
  String get recipeSuggestionLoading => 'Loading the suggestion …';

  @override
  String recipeAddCountToShoppingList(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Add $count items to the shopping list',
      one: 'Add 1 item to the shopping list',
    );
    return '$_temp0';
  }

  @override
  String get weeklyMenuOverflowDiscardAction => 'Discard the rest';

  @override
  String weeklyMenuOverflowDiscarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count dishes discarded from the tray',
      one: '1 dish discarded from the tray',
    );
    return '$_temp0';
  }

  @override
  String get pantryItemAmountUnknown => 'at home';

  @override
  String recipePantryAllAtHome(String names) {
    return 'Everything is at home in full, so nothing is added to the shopping list: $names';
  }

  @override
  String get recipeAllAtHome => 'Everything is at home';

  @override
  String recipePantryLessened(String names) {
    return 'Less than the recipe, since some is at home: $names';
  }

  @override
  String get navigationHome => 'Home';

  @override
  String get navigationMore => 'More';

  @override
  String get navigationAddAction => 'Add';

  @override
  String get moreTitle => 'More';

  @override
  String get moreSectionTogether => 'Together';

  @override
  String get moreSectionKitchen => 'Your kitchen';

  @override
  String get moreSectionAppAccount => 'Account & app';

  @override
  String get moreFamily => 'My household';

  @override
  String get morePersonalTags => 'Personal tags';

  @override
  String get moreCollectionStats => 'Statistics';

  @override
  String get moreNotifications => 'Notifications';

  @override
  String get addSheetQuickSaveTitle => 'Quick save';

  @override
  String get addSheetQuickSaveSubtitle =>
      'Just name and meal – import the details later';

  @override
  String get syncQueueTitle => 'Waiting to sync';

  @override
  String syncQueueNeedsYouHeader(int count) {
    return 'Waiting for you · $count';
  }

  @override
  String get syncQueueNeedsYouHint =>
      'These are not retried by themselves. The cause is written out, and each one has an action.';

  @override
  String syncQueueQueuedHeader(int count) {
    return 'Queued · $count';
  }

  @override
  String get syncQueueOrderNote =>
      'Changes to one item go in order, and different items sync side by side.';

  @override
  String get syncQueueSyncNow => 'Try to sync now';

  @override
  String get syncQueueSyncing => 'Syncing …';

  @override
  String get syncQueueRetry => 'Try again';

  @override
  String syncQueueRetryA11y(String what) {
    return 'Try again – $what';
  }

  @override
  String get syncQueueDiscard => 'Discard the change';

  @override
  String syncQueueDiscardA11y(String what) {
    return 'Discard the change $what';
  }

  @override
  String get syncQueueDiscarded => 'Change discarded.';

  @override
  String get syncQueueRecipeDiscarded => 'The recipe was discarded.';

  @override
  String get syncQueueDiscardPhoneOnlyTitle => 'Discard the recipe?';

  @override
  String syncQueueDiscardPhoneOnlyBody(String title) {
    return '$title exists only on this phone. It never reached the server, so if you discard it, it is gone everywhere.';
  }

  @override
  String get syncQueueDiscardPhoneOnlyConfirm => 'Discard the recipe';

  @override
  String get syncQueueDiscardFailed => 'The change could not be discarded.';

  @override
  String get syncQueueRetryFailed =>
      'The change could not be put back in the queue.';

  @override
  String get syncQueueSyncFailed => 'The queue could not be sent right now.';

  @override
  String get syncQueueChangeKept => 'It stays under Waiting for you.';

  @override
  String get syncQueueChangesKept => 'The changes stay on the phone.';

  @override
  String get syncQueueEmpty =>
      'Everything is saved. Nothing is waiting to sync.';

  @override
  String get syncQueueWaitsOnEarlier => 'waiting for an earlier change';

  @override
  String get syncQueueUnnamedRecipe => 'A recipe';

  @override
  String syncQueueRecipeCreated(String title) {
    return '$title · new recipe';
  }

  @override
  String syncQueueRecipeUpdated(String title) {
    return '$title · changed';
  }

  @override
  String syncQueueRecipeDeleted(String title) {
    return '$title · deleted';
  }

  @override
  String syncQueueRecipeTagged(String title) {
    return '$title · being tagged';
  }

  @override
  String syncQueueImageFor(String title) {
    return 'Photo for $title';
  }

  @override
  String get syncQueueImage => 'A photo';

  @override
  String get syncQueueReasonNotFound => 'The recipe no longer exists';

  @override
  String get syncQueueReasonPermission => 'You no longer have permission';

  @override
  String get syncQueueReasonTooLarge => 'The photo is too large';

  @override
  String get syncQueueReasonDependency =>
      'It depends on a change that could not be saved';

  @override
  String get syncQueueReasonUnknown => 'The server did not accept the change';

  @override
  String get syncQueueReasonExpired => 'Could not be saved for 24 h';

  @override
  String get syncQueueSaveAsCopy => 'Save as a copy';

  @override
  String syncQueueCopyTitle(String title) {
    return '$title (copy)';
  }

  @override
  String syncQueueSaveAsCopyA11y(String what) {
    return 'Save as a copy – $what';
  }

  @override
  String get syncQueueTrySmaller => 'Try smaller';

  @override
  String syncQueueTrySmallerA11y(String what) {
    return 'Try smaller – $what';
  }

  @override
  String get syncQueueCopyFailed => 'The copy could not be saved.';

  @override
  String get syncQueueTrySmallerFailed =>
      'The image could not be made smaller.';

  @override
  String syncQueueNextAttemptSeconds(int seconds) {
    return 'next attempt in $seconds s';
  }

  @override
  String syncQueueNextAttemptMinutes(int minutes) {
    return 'next attempt in $minutes min';
  }

  @override
  String get syncQueueAgeNow => 'now';

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
      other: '$days days',
      one: '1 day',
    );
    return '$_temp0';
  }

  @override
  String syncQueueIndicatorA11y(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes are waiting for you. Open Waiting to sync',
      one: '1 change is waiting for you. Open Waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get recipeSuggestChange => 'Suggest a change';

  @override
  String get recipeSuggestionSend => 'Send the suggestion';

  @override
  String get recipeSuggestionSending => 'Sending the suggestion …';

  @override
  String get recipeSuggestionSent => 'The suggestion is sent to the owner.';

  @override
  String get recipeSuggestionSendFailed => 'The suggestion could not be sent.';

  @override
  String get recipeSuggestionCoversText =>
      'A suggestion covers the recipe\'s text: title, description, meal, portions, time, ingredients and steps.';

  @override
  String get recipeSuggestionReplaced =>
      'The suggestion is sent and replaced your earlier one.';

  @override
  String conflictBannerBodySuggestionReplaced(String name) {
    return '$name changed it at the same time. Your change replaced your earlier suggestion and is kept for 7 days.';
  }

  @override
  String get conflictBannerBodySuggestionReplacedUnnamed =>
      'Someone else changed it at the same time. Your change replaced your earlier suggestion and is kept for 7 days.';

  @override
  String recipeSuggestionFromOneUpdated(String name) {
    return '$name has updated their suggestion to the recipe.';
  }

  @override
  String get recipeSuggestionFromOneUpdatedUnnamed =>
      'A member has updated their suggestion to the recipe.';

  @override
  String recipeSuggestionFromManyUpdated(int count, int updated) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count suggested changes are',
      one: '1 suggested change is',
    );
    String _temp1 = intl.Intl.pluralLogic(
      updated,
      locale: localeName,
      other: '$updated of them have been updated.',
      one: 'One of them has been updated.',
    );
    return '$_temp0 waiting for you. $_temp1';
  }

  @override
  String recipeSuggestionIntroOwnerUpdated(String name, String title) {
    return '$name has updated their suggestion for $title. Your recipe only changes if you use the suggestion.';
  }

  @override
  String recipeSuggestionIntroMineUpdated(String title) {
    return 'You suggested a change to $title, and it replaced your earlier suggestion. The recipe only changes if the owner uses the suggestion.';
  }

  @override
  String get recipeSuggestionChangedSinceOpened =>
      'The suggestion has changed since you opened it. Open it again to see the new one.';

  @override
  String get cookingNoStepsSaveCopy => 'Save my copy';

  @override
  String get cookingNoStepsBodyOthers =>
      'The ingredients are there, but nobody has written how to make it. Save your own copy and write the steps there, or take the ingredients to the shopping list.';

  @override
  String get cookingNoStepsBodyOthersNoIngredients =>
      'Nobody has written how to make it yet. Save your own copy and write the steps there.';

  @override
  String get hemGreetingMorning => 'Good morning';

  @override
  String get hemGreetingDay => 'Hi';

  @override
  String get hemGreetingEvening => 'Good evening';

  @override
  String get hemGreetingNight => 'Good night';

  @override
  String get hemGreetingWelcome => 'Welcome';

  @override
  String hemGreetingWithName(String greeting, String name) {
    return '$greeting, $name';
  }

  @override
  String get hemTonight => 'Tonight';

  @override
  String hemLibraryHeading(int count) {
    return 'Your recipes · $count';
  }

  @override
  String hemMetaMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String hemMetaPortions(int count) {
    return '$count serv.';
  }

  @override
  String get hemStartCooking => 'Start cooking';

  @override
  String get hemSuggestion => 'Suggestion';

  @override
  String get hemSwapSuggestion => 'Change suggestion';

  @override
  String get hemSwapDish => 'Change dish';

  @override
  String get hemAllInPantry => 'all in the pantry';

  @override
  String get hemLoadingPlan => 'Fetching this week\'s plan …';

  @override
  String get hemPlanErrorWhat => 'This week\'s plan could not be fetched.';

  @override
  String get hemShowSavedPlan => 'Open the week menu';

  @override
  String hemPlanFetchedAt(String time) {
    return 'The plan was fetched at $time – someone else may have changed it since.';
  }

  @override
  String get hemEmptyTitle => 'Butlery becomes useful with one recipe';

  @override
  String get hemEmptyBody =>
      'Add something you already cook often. Then Butlery can plan the week, scale portions and write the shopping list for you.';

  @override
  String get hemEmptyShortcuts => 'Quickest ways';

  @override
  String get hemEmptyLinkTitle => 'Paste a link';

  @override
  String get hemEmptyLinkBody => 'from a recipe page, YouTube or Instagram';

  @override
  String get hemEmptyPhotoTitle => 'Photograph a recipe page';

  @override
  String get hemEmptyPhotoBody => 'from a cookbook or a clipping';

  @override
  String get hemEmptyWriteTitle => 'Write it yourself';

  @override
  String get hemEmptyWriteBody => 'for what you cook without a recipe';

  @override
  String get hemEmptyAllergyNote =>
      'Does the household have allergies? Set them first, and Butlery will filter them out of the weekly menu. Always check the packaging as well.';

  @override
  String get hemEmptyAllergyLink => 'Set allergens';

  @override
  String get bulkAddToMenuFailed =>
      'The recipes could not be added to the week menu.';

  @override
  String get bulkExportFailed => 'The recipes could not be exported.';

  @override
  String get profilePrivacyPolicyOpenFailed =>
      'The privacy policy could not be opened.';

  @override
  String get profileConsentManagementOpenFailed =>
      'Consent management could not be opened.';

  @override
  String get profileDataExportOpenFailed => 'Data export could not be opened.';

  @override
  String get shareCouldNotComplete => 'Sharing could not be completed.';

  @override
  String shareRecipesNotShared(int count, String titles) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes could not be shared: $titles.',
      one: 'One recipe could not be shared: $titles.',
    );
    return '$_temp0';
  }

  @override
  String get shareRecipesRetryOnlyFailed =>
      'What you filled in is still here. Share tries again with only those.';

  @override
  String get imageSelectFailed => 'The images could not be selected.';

  @override
  String get groupMenuOpenFailed => 'The menu could not be opened.';

  @override
  String get groupRecipeOpenFailed => 'The recipe could not be opened.';

  @override
  String get retagFailed => 'Re-tagging could not be completed.';

  @override
  String get profileAccountDeleteFailed => 'The account could not be deleted.';

  @override
  String get adminMetricsLoadFailed => 'Couldn\'t load the metrics';

  @override
  String get adminOpsLogLoadFailed => 'Couldn\'t load the operations log';

  @override
  String get adminParsingStatsLoadFailed =>
      'Couldn\'t load the parsing statistics';

  @override
  String get familyRatingsLoadFailed => 'Couldn\'t load the ratings';

  @override
  String get familyRatingEntryLoadFailed => 'Couldn\'t load the rating';

  @override
  String get familyRatingSaveFailed => 'Couldn\'t save the rating';

  @override
  String get familyLoadFailed => 'Could not load the household';

  @override
  String get familyMemberSaveFailed =>
      'The guest could not be saved. Try again.';

  @override
  String get familyConsentRevokeFailed => 'Couldn\'t withdraw the consent';

  @override
  String get familyMemberRemoveFailed =>
      'The guest could not be deleted. Try again.';

  @override
  String get householdLoadFailed => 'Couldn\'t load the household';

  @override
  String get weeklyMenuSaveError => 'Couldn\'t save the weekly menu';

  @override
  String get weeklyMenuWhoIsHomeSaveFailed => 'Couldn\'t save who is home';

  @override
  String get weeklyMenuAddRecipeFailed => 'Couldn\'t add the recipe';

  @override
  String get weeklyMenuMoveRecipeFailed => 'Couldn\'t move the recipe';

  @override
  String get weeklyMenuRemoveRecipeFailed => 'Couldn\'t remove the recipe';

  @override
  String get weeklyMenuClearFailed => 'Couldn\'t clear the week';

  @override
  String get weeklyMenuUndoClearFailed => 'Couldn\'t undo the clearing';

  @override
  String get pantryLoadFailed => 'Couldn\'t load the pantry';

  @override
  String get pantryAddFailed => 'Couldn\'t add to the pantry';

  @override
  String get pantryRemoveItemFailed => 'Couldn\'t remove the item';

  @override
  String get pantryRestoreItemFailed => 'Couldn\'t restore the item';

  @override
  String get pantryRemoveItemsFailed => 'Couldn\'t remove the items';

  @override
  String get pantryRestoreItemsFailed => 'Couldn\'t restore the items';

  @override
  String get sharedShoppingListsLoadFailed =>
      'Couldn\'t load shared shopping lists';

  @override
  String get activityFeedLoadFailed => 'Couldn\'t load the feed';

  @override
  String get activityFeedLoadMoreFailed => 'Couldn\'t load more activity';

  @override
  String get groupCreateFailed => 'The group could not be created.';

  @override
  String get groupRemoveMemberFailed => 'The member could not be removed.';

  @override
  String get groupUpdateFailed => 'The group could not be updated.';

  @override
  String get groupLeaveFailed => 'Couldn\'t leave the group.';

  @override
  String get groupInvitationCancelFailed =>
      'The invitation could not be cancelled.';

  @override
  String groupInvitationsPartlyFailed(int failed, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total invitations',
      one: '1 invitation',
    );
    return '$failed of $_temp0 could not be sent.';
  }

  @override
  String get conversationStartFailed =>
      'The conversation could not be started.';

  @override
  String get conversationDeleteFailed =>
      'The conversation could not be deleted.';

  @override
  String get profileOpenFailed => 'The profile could not be opened.';

  @override
  String get feedRecipeRequestFailed => 'The request could not be sent.';

  @override
  String get groupInvitationDeclineFailed =>
      'The invitation could not be declined.';

  @override
  String get socialInviteLinkShareFailed =>
      'The invitation link could not be shared.';

  @override
  String get socialInviteLinkCopyFailed =>
      'The invitation link could not be copied.';

  @override
  String get chatMessagesLoadFailed => 'The messages could not be loaded.';

  @override
  String get draftDiscard => 'Discard';

  @override
  String draftsDiscarded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count drafts were discarded',
      one: 'The draft was discarded',
    );
    return '$_temp0';
  }

  @override
  String get shoppingRestoreItems => 'Restore items';

  @override
  String get shoppingRestoreGroupRemoved => 'Removed';

  @override
  String get shoppingRestoreGroupChanged => 'Changed';

  @override
  String get shoppingRestoreButton => 'Restore';

  @override
  String shoppingRestoreButtonFor(String name) {
    return 'Restore $name';
  }

  @override
  String shoppingRestoreChangedLine(String label, String current) {
    return '$label (now: $current)';
  }

  @override
  String get shoppingRestoreEmpty => 'Nothing to restore.';

  @override
  String shoppingRestoredRemoved(String name) {
    return '$name is back on the list.';
  }

  @override
  String shoppingRestoredChanged(String name) {
    return '$name is back to its earlier version.';
  }

  @override
  String pantryPreviousVersion(String when) {
    return 'Previous version · $when';
  }

  @override
  String get pantryRestorePreviousAction => 'Restore';

  @override
  String get pantryPreviousRestored => 'Previous version restored';

  @override
  String get pantryRestorePreviousFailed =>
      'Couldn\'t restore the previous version';

  @override
  String get whatsNewTitle => 'What\'s new';

  @override
  String get whatsNewDone => 'Got it';

  @override
  String get whatsNewAboutTitle => 'What\'s new';

  @override
  String whatsNewVersionRange(String from, String to) {
    return 'Version $from–$to';
  }

  @override
  String get setNewPasswordTitle => 'Choose a new password';

  @override
  String get setNewPasswordChecking => 'Checking the link …';

  @override
  String setNewPasswordForAccount(String email) {
    return 'Choose a new password for $email';
  }

  @override
  String get setNewPasswordRepeat => 'Repeat new password';

  @override
  String get setNewPasswordSave => 'Save password';

  @override
  String get setNewPasswordWeak =>
      'The password is too simple. Use at least twelve characters, or three words you remember.';

  @override
  String get setNewPasswordSaveFailed => 'The password couldn\'t be saved.';

  @override
  String setNewPasswordSaveFailedBecause(String cause) {
    return 'The password couldn\'t be saved. $cause';
  }

  @override
  String get setNewPasswordNothingChanged => 'Your old password still works.';

  @override
  String get setNewPasswordCheckFailed => 'The link couldn\'t be checked.';

  @override
  String get setNewPasswordLinkInvalidTitle => 'This link no longer works';

  @override
  String get setNewPasswordLinkInvalidBody =>
      'It has already been used or is too old. Ask for a new link and it will come to your email.';

  @override
  String get setNewPasswordRequestNew => 'Send a new link';

  @override
  String get setNewPasswordClose => 'Close';

  @override
  String setNewPasswordSavedOther(String email) {
    return 'The password for $email has been changed.';
  }

  @override
  String get passwordResetDoneNotice =>
      'Your password has been changed. Sign in with the new one.';

  @override
  String shoppingItemsAddedToListSnack(int count, String listName) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count items added to “$listName”',
      one: '1 item added to “$listName”',
    );
    return '$_temp0';
  }

  @override
  String get shoppingAddToListHeading => 'Add to list';

  @override
  String get recipeImportNoIngredientsNotice =>
      'We found no ingredients. Add them yourself below.';

  @override
  String get trashTitle => 'Trash';

  @override
  String get trashLoading => 'Loading the trash …';

  @override
  String get trashLoadFailed => 'The trash could not be loaded.';

  @override
  String get trashEmptyTitle => 'The trash is empty';

  @override
  String get trashEmptyBody => 'Deleted recipes stay here for 30 days.';

  @override
  String trashDaysLeft(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count days left',
      one: '1 day left',
      zero: 'Expires today',
    );
    return '$_temp0';
  }

  @override
  String trashRestoreSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Restore $count recipes',
      one: 'Restore 1 recipe',
    );
    return '$_temp0';
  }

  @override
  String trashDeleteSelected(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count recipes',
      one: 'Delete 1 recipe',
    );
    return '$_temp0';
  }

  @override
  String get trashEmptyAction => 'Empty the trash';

  @override
  String get trashDeleteConfirmAction => 'Delete for good';

  @override
  String get trashEmptyConfirmTitle => 'Empty the trash?';

  @override
  String get trashEmptyConfirmBody =>
      'Every recipe in the trash is deleted for good. This cannot be undone.';

  @override
  String trashRestoredAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes restored as private',
      one: 'Restored as private',
    );
    return '$_temp0';
  }

  @override
  String trashDeletedAll(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes were deleted for good',
      one: 'The recipe was deleted for good',
    );
    return '$_temp0';
  }

  @override
  String get trashEmptied => 'The trash is empty now';

  @override
  String get trashOfflineNothingChanged =>
      'You are offline. Nothing was changed.';

  @override
  String get trashFailedNothingChanged =>
      'The trash could not be updated. Nothing was changed.';

  @override
  String trashPartialSummary(int done, int total) {
    return '$done of $total done.';
  }

  @override
  String get trashPartialNoneDone => 'Nothing was changed.';

  @override
  String trashFailOffline(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes were not done because you are offline.',
      one: '1 recipe was not done because you are offline.',
    );
    return '$_temp0';
  }

  @override
  String trashFailExpired(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes had already expired.',
      one: '1 recipe had already expired.',
    );
    return '$_temp0';
  }

  @override
  String trashFailGone(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes were no longer in the trash.',
      one: '1 recipe was no longer in the trash.',
    );
    return '$_temp0';
  }

  @override
  String trashFailFailed(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes could not be done. Try again.',
      one: '1 recipe could not be done. Try again.',
    );
    return '$_temp0';
  }

  @override
  String get weekMenuPlanningCancel => 'Cancel planning';

  @override
  String get weekMenuPlanningCancelNote =>
      'Cancelling keeps your latest suggestion. Nothing is overwritten until you save.';

  @override
  String get privacyShowNameOnDishesTitle =>
      'Show my name on my dishes in shared menus';

  @override
  String get privacyShowNameOnDishesSubtitle =>
      'Anyone who opens a shared menu sees your name under the dishes you have made and can go to your profile. This applies to every shared menu that contains your dishes, older ones and ones others have forwarded too. If you turn it off, your name disappears within 30 minutes.';

  @override
  String get privacyShowNameOnDishesMinor =>
      'Not available for accounts under 18.';

  @override
  String menuDishCreatorCredit(String name) {
    return 'Recipe by $name';
  }

  @override
  String get a11yOpenCreatorProfile => 'Open profile';

  @override
  String get errorCouldNotSaveDishCredit =>
      'Your choice about showing your name on dishes could not be saved. Please try again.';

  @override
  String get reportReasonMisattribution => 'This is not my dish';

  @override
  String get menuDishReportTooltip => 'Report this dish';

  @override
  String get menuDishNotMine => 'This is not my dish';

  @override
  String get notMyDishTitle => 'This is not my dish';

  @override
  String get notMyDishBody =>
      'Your name is removed from the dish, and a moderator will see the report. If you do not want your name shown on any dishes, you can turn it off under Privacy.';

  @override
  String get notMyDishConfirm => 'Remove my name';

  @override
  String get notMyDishSubmitted =>
      'Your name is being removed from the dish. A moderator will look at the report.';

  @override
  String get moderatorContentTypeMenuDish => 'Dish in a shared menu';

  @override
  String get moderatorActionRemoveDish => 'Remove the dish from the menu';

  @override
  String get moderatorRemoveDishConfirmTitle =>
      'Remove the dish from the menu?';

  @override
  String get moderatorRemoveDishConfirmBody =>
      'Only this dish is removed from the shared menu. The rest of the menu stays.';

  @override
  String get moderatorMenuDishSharerNote =>
      'The person who shared the menu did not necessarily write the dish.';

  @override
  String get moderatorMenuDishClaimedReporter =>
      'The dish named the reporter as its creator when the report came in.';

  @override
  String get moderatorMenuDishNotClaimedReporter =>
      'The dish did not name the reporter as its creator when the report came in.';

  @override
  String get mealAllergenScopeTitle =>
      'Match the allergy filter to who is home';

  @override
  String get mealAllergenScopeSubtitle =>
      'Lunch and dinner only count the people who are home. Other meals, like snacks and baking, always count everyone.';

  @override
  String get mealAllergenScopeOnTitle => 'Match who is home?';

  @override
  String get mealAllergenScopeOnBody =>
      'A dish someone in the household can\'t eat, even a child, can then be planned for a lunch or dinner when that person is marked as away. This includes your own allergies. Make sure who is home is right in the weekly menu. You can turn this off at any time.';

  @override
  String get mealAllergenScopeOnAction => 'Turn on';

  @override
  String get menuAllergenUnsafeAtMeal =>
      'Contains something someone at home can\'t eat';

  @override
  String get menuAllergenUnsafeForHousehold =>
      'not for everyone in the household';

  @override
  String get menuMealAllergenScopeHint =>
      'The allergy filter follows who is home. Dishes not everyone in the household can eat only go on a lunch or dinner when the person who can\'t eat them is away.';

  @override
  String get weeklyMenuOverflowAllergen =>
      'Some of them don\'t suit someone who is home on the free days.';

  @override
  String get accountDeletionScheduling => 'Preparing the deletion …';

  @override
  String get accountDeletionScheduledTitle => 'The deletion is scheduled';

  @override
  String accountDeletionScheduledBody(String date) {
    return 'The account will be deleted on $date. If you sign in before then, you can undo the deletion.';
  }

  @override
  String get accountDeletionScheduledBodyNoDate =>
      'The account will be deleted when the grace period ends. If you sign in before then, you can undo the deletion.';

  @override
  String get pendingDeletionTitle => 'Your account is going to be deleted';

  @override
  String get pendingDeletionUndo => 'Undo the deletion';

  @override
  String get pendingDeletionDeleteNow => 'Delete now';

  @override
  String get pendingDeletionDeleteNowConfirmTitle => 'Delete the account now?';

  @override
  String get pendingDeletionDeleteNowConfirmBody =>
      'Everything is deleted immediately and this cannot be undone.';

  @override
  String get pendingDeletionUndoFailed => 'The deletion could not be undone';

  @override
  String get pendingDeletionAlreadyStarted =>
      'The deletion has already started and can no longer be undone.';

  @override
  String get moreProfileSubtitle => 'Profile and visibility';

  @override
  String get moreProfileFallbackName => 'Your profile';

  @override
  String moreSyncBand(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count changes waiting to sync',
      one: '1 change waiting to sync',
    );
    return '$_temp0';
  }

  @override
  String get moreSectionHousehold => 'Household & food';

  @override
  String get moreAllergens => 'Allergens & diet';

  @override
  String get settingsAccountAreaTitle => 'Account & security';

  @override
  String get settingsAccountAreaSubtitle =>
      'Sign-in, two-step verification, sign out';

  @override
  String get settingsPrivacyAreaTitle => 'Privacy and data';

  @override
  String get settingsPrivacyAreaSubtitle => 'Consents, export, backup';

  @override
  String get settingsAppTitle => 'App settings';

  @override
  String get settingsAppSubtitle => 'Language, theme, notifications';

  @override
  String get settingsHelpTitle => 'Help & about';

  @override
  String get settingsHelpSubtitle => 'Questions, terms, reports';

  @override
  String get settingsSignInSection => 'Sign-in';

  @override
  String get settingsAccountEmail => 'Email address';

  @override
  String get settingsAccountPassword => 'Password';

  @override
  String get settingsAccountTwoStep => 'Two-step verification';

  @override
  String get settingsYourChoicesSection => 'Your choices';

  @override
  String get settingsYourDataSection => 'Your data';

  @override
  String get settingsDocumentsSection => 'Documents';

  @override
  String get settingsConsents => 'Consents';

  @override
  String get settingsBackupTitle => 'Recipe backup';

  @override
  String get settingsBackupSubtitle => 'Download or restore';

  @override
  String get settingsAppearanceSection => 'Appearance';

  @override
  String get settingsShoppingSection => 'Shopping';

  @override
  String get settingsNotificationSettings => 'Notification settings';

  @override
  String get settingsHelpSection => 'Help';

  @override
  String get settingsRulesSection => 'Rules and reports';

  @override
  String get settingsMyReportsSubtitle => 'What you reported and how it went';

  @override
  String get settingsVersionLabel => 'Version';

  @override
  String get settingsAdminOnly => 'Admin';

  @override
  String get socialFriendRequestsTitle => 'Friend requests';

  @override
  String socialPendingRequestsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count pending requests',
      one: '1 pending request',
    );
    return '$_temp0';
  }

  @override
  String get socialSearchNameOrEmailHint => 'Name or email address';

  @override
  String get socialShareProfileLink => 'Share your profile link';

  @override
  String get messagesNewMessage => 'New message';

  @override
  String get messagesToFriend => 'To a friend';

  @override
  String get messagesNewGroup => 'New group conversation';

  @override
  String get messagesSearchHint => 'Search messages';

  @override
  String get messagesArchivedRow => 'Archived conversations';

  @override
  String messagesMoreOptionsFor(String name) {
    return 'More options for $name';
  }

  @override
  String get socialMoreOptions => 'More options';

  @override
  String get groupShareWithGroupSection => 'Share with the group';

  @override
  String get groupShareRecipeRow => 'Share a recipe';

  @override
  String get groupShareMenuRow => 'Share the weekly menu';

  @override
  String get groupShareShoppingListRow => 'Share a shopping list';

  @override
  String get groupLeaveTheGroup => 'Leave the group';

  @override
  String get friendProfileShareRecipe => 'Share a recipe';

  @override
  String friendProfilePublicRecipesRow(String owner) {
    return '$owner public recipes';
  }

  @override
  String friendProfileSharedWithYouRow(String name) {
    return 'Shared with you by $name';
  }

  @override
  String get friendProfileRemoveFriend => 'Remove as friend';

  @override
  String get familyAccountsSection => 'Accounts in the household';

  @override
  String get familyProfilesSection => 'Guests';

  @override
  String familyAccountsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count accounts',
      one: '1 account',
    );
    return '$_temp0';
  }

  @override
  String familyProfilesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count profiles',
      one: '1 profile',
    );
    return '$_temp0';
  }

  @override
  String get familyAddMemberRow => 'Add guest';

  @override
  String get familyYou => 'You';

  @override
  String get familyMealsSection => 'Meals';

  @override
  String get householdPortionsTitle => 'Default portions';

  @override
  String get householdPortionsSaved => 'Portions saved';

  @override
  String get familyAllergiesSection => 'Allergies in the household';

  @override
  String get allergenIntro =>
      'Choose what you want to see the status of on recipes.';

  @override
  String get allergenSectionAllergens => 'Allergens';

  @override
  String get allergenSectionDietary => 'Special diets';

  @override
  String get allergenDisplayCoverageLabel => 'How certain the labelling is';

  @override
  String get allergenDisplayUnknownLabel => 'Unknown allergen status';

  @override
  String get allergenLabelNote =>
      'The labelling is based on the ingredient list. Always check the packaging if the allergy is serious.';

  @override
  String get allergenSectionMaintenance => 'Maintenance';

  @override
  String get allergenRetagRow => 'Update the labelling on all recipes';

  @override
  String get allergenResetTitle => 'Reset to default?';

  @override
  String get allergenResetBody =>
      'Your allergen and diet choices go back to the defaults.';

  @override
  String get notifAllowRow => 'Allow notifications';

  @override
  String get notifCategoriesSection => 'What you get notifications about';

  @override
  String get notifCategoriesFootnote =>
      'Muted categories still show in the notification inbox – they are only not sent as push.';

  @override
  String get notifDigestSection => 'Summary';

  @override
  String get notifDigestRow => 'Send summary';

  @override
  String get settingsBlockedPeople => 'Blocked people';

  @override
  String trashIntro(int days) {
    String _temp0 = intl.Intl.pluralLogic(
      days,
      locale: localeName,
      other: '$days days',
      one: '1 day',
    );
    return 'Recipes are deleted for good after $_temp0.';
  }

  @override
  String get trashRestoreRecipe => 'Restore the recipe';

  @override
  String get trashRestoreAll => 'Restore all';

  @override
  String trashDeleteOneTitle(String name) {
    return 'Delete $name for good?';
  }

  @override
  String get trashDeleteOneBody => 'This cannot be undone.';

  @override
  String get personalTagUngroupedSection => 'No group';

  @override
  String get personalTagDeleteUnusedAction => 'Delete unused tags';

  @override
  String get personalTagNewTag => 'New tag';

  @override
  String get personalTagNewGroup => 'New group';

  @override
  String get personalTagManageGroup => 'Manage group';

  @override
  String get tagDetailGroupLabel => 'Group';

  @override
  String get tagDetailRunRulesAll => 'Run the rules now';

  @override
  String get tagDetailShareTag => 'Share tag';

  @override
  String get tagDetailDeleteTagAction => 'Delete tag';

  @override
  String get tagDetailRuleEdit => 'Edit rule';

  @override
  String get tagDetailRuleDeleteAction => 'Delete rule';

  @override
  String get libraryTabAllRecipes => 'All recipes';

  @override
  String get libraryTabCookbooks => 'Cookbooks';

  @override
  String cookbookShelfCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count cookbooks',
      one: '1 cookbook',
    );
    return '$_temp0';
  }

  @override
  String cookbookRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return '$_temp0';
  }

  @override
  String get cookbookMakeFromTag => 'Make a tag a cookbook';

  @override
  String get cookbookShelfEmpty =>
      'You have no cookbooks yet. Pick one of your tags and it becomes a cookbook with a cover and its own order.';

  @override
  String get cookbookNoTags =>
      'Cookbooks are made from your own tags. Create a tag first.';

  @override
  String get cookbookManageTags => 'Your tags';

  @override
  String get cookbookChooseTagTitle => 'Choose a tag';

  @override
  String get cookbookAllTagsAreCookbooks =>
      'All your tags are already cookbooks.';

  @override
  String get cookbookMakeTitle => 'Make a cookbook';

  @override
  String get cookbookEditTitle => 'Edit cookbook';

  @override
  String cookbookMakeIntro(String name) {
    return 'The tag “$name” becomes a cookbook.';
  }

  @override
  String get cookbookDescriptionLabel => 'Description (optional)';

  @override
  String get cookbookCoverLabel => 'Cover';

  @override
  String get cookbookCoverOwnPhoto => 'Own photo';

  @override
  String get cookbookCoverRecipePhoto => 'Recipe photo';

  @override
  String get cookbookCoverColor => 'Colour';

  @override
  String get cookbookChoosePhoto => 'Choose photo';

  @override
  String get cookbookChooseRecipePhoto => 'Choose recipe photo';

  @override
  String get cookbookNoRecipePhotos =>
      'No recipe in the cookbook has a photo yet.';

  @override
  String get cookbookCreate => 'Create cookbook';

  @override
  String get cookbookSave => 'Save';

  @override
  String get cookbookRemove => 'Stop being a cookbook';

  @override
  String get cookbookRemoveBody =>
      'The tag and the recipes stay. The cover, description, order and notes are removed.';

  @override
  String get cookbookEdit => 'Edit';

  @override
  String get cookbookAddRecipes => 'Add recipes';

  @override
  String get cookbookSortAlphabetical => 'Sort A–Z';

  @override
  String get cookbookReorder => 'Reorder';

  @override
  String get cookbookReorderDone => 'Done';

  @override
  String get cookbookOrderHintAlphabetical =>
      'Sorted A–Z. New recipes land at their letter.';

  @override
  String get cookbookOrderHintCustom => 'Your own order. New recipes go last.';

  @override
  String get cookbookEmpty => 'No recipes in the cookbook yet.';

  @override
  String get cookbookPickerEmpty =>
      'All your recipes are already in the cookbook.';

  @override
  String cookbookPickerAdd(int count) {
    return 'Add $count';
  }

  @override
  String cookbookAdded(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes added',
      one: '1 recipe added',
    );
    return '$_temp0';
  }

  @override
  String get cookbookWriteNote => 'Write a note';

  @override
  String get cookbookEditNote => 'Edit note';

  @override
  String get cookbookNoteLabel => 'Note in the cookbook';

  @override
  String get cookbookNoteHelper =>
      'Shown only in this cookbook, not in the recipe.';

  @override
  String cookbookNoteFrom(String name) {
    return 'From the cookbook “$name”';
  }

  @override
  String get cookbookLoadFailed => 'The cookbooks could not be loaded.';

  @override
  String get cookbookSaveFailed =>
      'The cookbook could not be saved. Try again.';

  @override
  String get cookbookCoverUploadFailed =>
      'The photo could not be uploaded. Check the connection and try again.';

  @override
  String get cookbookTooManyRecipes =>
      'A cookbook can hold at most 1000 recipes.';

  @override
  String get cookbookAddRecipesFailed =>
      'Not every recipe could be added. Try again.';

  @override
  String get cookbookDeleteTagWarning =>
      'The tag is a cookbook, so its cover, description, order and notes are removed too.';

  @override
  String get cookbookColorSage => 'Sage';

  @override
  String get cookbookColorGold => 'Gold';

  @override
  String get cookbookColorBrown => 'Brown';

  @override
  String get cookbookColorBrick => 'Brick red';

  @override
  String get cookbookColorMoss => 'Moss green';

  @override
  String get cookbookColorSand => 'Sand';

  @override
  String a11yMoveRecipeUp(String title) {
    return 'Move $title up';
  }

  @override
  String a11yMoveRecipeDown(String title) {
    return 'Move $title down';
  }

  @override
  String a11yRecipeMoved(String title, int position, int count) {
    return '$title moved to position $position of $count';
  }

  @override
  String a11yCookbookCover(String name) {
    return 'Cover of $name';
  }

  @override
  String get a11yOpenCookbook => 'Open cookbook';

  @override
  String get cookbookLoading => 'Loading cookbooks …';

  @override
  String get recipeDeleteConfirmTitle => 'Delete the recipe?';

  @override
  String bulkDeleteConfirmTitle(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count recipes?',
      one: 'Delete 1 recipe?',
    );
    return '$_temp0';
  }

  @override
  String bulkDeleteConfirmAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count recipes',
      one: 'Delete the recipe',
    );
    return '$_temp0';
  }

  @override
  String get commentDeleteConfirmTitle => 'Delete the comment?';

  @override
  String get commentDeleteConfirmAction => 'Delete comment';

  @override
  String get cookSnapDeleteConfirmTitle => 'Delete the photo?';

  @override
  String get groupDeleteConfirmTitle => 'Delete the group?';

  @override
  String friendRemoveConfirmTitle(String name) {
    return 'Remove $name as a friend?';
  }

  @override
  String get messagingRemoveMemberAction => 'Remove from group';

  @override
  String get messagingLeaveGroupTitle => 'Leave the group?';

  @override
  String get messagingDeleteConversationTitle => 'Delete the conversation?';

  @override
  String get messagingDeleteConversationAction => 'Delete conversation';

  @override
  String get chatDeleteMessageTitle => 'Delete the message?';

  @override
  String personalTagBulkDeleteAction(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count tags',
      one: 'Delete the tag',
    );
    return '$_temp0';
  }

  @override
  String get groupCancelInvitationTitle => 'Cancel the invitation?';

  @override
  String get groupCancelInvitationAction => 'Cancel invitation';

  @override
  String get groupKeepInvitation => 'Keep invitation';

  @override
  String get importHeirloomClearAction => 'Remove image';

  @override
  String get dataExportClearAction => 'Clear export';

  @override
  String get shoppingDeleteListTitle => 'Delete the list?';

  @override
  String get ratingRemoveAction => 'Remove rating';

  @override
  String get detailPaneExpand => 'Fullscreen';

  @override
  String get detailPaneCollapse => 'Show the list';

  @override
  String get a11yDetailPaneList => 'List';

  @override
  String get a11yDetailPaneDetail => 'Selected page';

  @override
  String get nutritionButton => 'Nutrition values';

  @override
  String get nutritionSheetTitle => 'Nutrition values';

  @override
  String get a11yNutritionClose => 'Close nutrition values';

  @override
  String get nutritionBasisPerPortion => 'Per serving';

  @override
  String get nutritionBasisWhole => 'Whole recipe';

  @override
  String get nutritionBasisPhrasePerPortion => 'per serving';

  @override
  String get nutritionBasisPhraseWhole => 'for the whole recipe';

  @override
  String get a11yNutritionBasisPerPortion => 'Showing values per serving';

  @override
  String a11yNutritionBasisWhole(int portions) {
    String _temp0 = intl.Intl.pluralLogic(
      portions,
      locale: localeName,
      other: '$portions servings',
      one: '1 serving',
    );
    return 'Showing values for the whole recipe, $_temp0';
  }

  @override
  String get a11yNutritionBasisWholeNoPortions =>
      'Showing values for the whole recipe';

  @override
  String get nutritionNoPortions =>
      'The recipe states no servings, so the values are for the whole recipe.';

  @override
  String get nutritionEnergy => 'Energy';

  @override
  String get nutritionFat => 'Fat';

  @override
  String get nutritionSaturatedFat => 'of which saturated fat';

  @override
  String get nutritionCarbs => 'Carbohydrates';

  @override
  String get nutritionSugars => 'of which sugars';

  @override
  String get nutritionFiber => 'Fibre';

  @override
  String get nutritionProtein => 'Protein';

  @override
  String get nutritionSalt => 'Salt';

  @override
  String get nutritionStripKcal => 'kcal';

  @override
  String get nutritionStripProtein => 'protein';

  @override
  String get nutritionStripCarbs => 'carbs';

  @override
  String get nutritionStripFat => 'fat';

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
    return '$value kilocalories';
  }

  @override
  String a11yNutritionSpokenGrams(String value) {
    return '$value grams';
  }

  @override
  String a11yNutritionStripKcal(String value, String basis) {
    return 'Energy $value kilocalories $basis';
  }

  @override
  String a11yNutritionStripGrams(String name, String value, String basis) {
    return '$name $value grams $basis';
  }

  @override
  String nutritionCoverage(int counted, int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total ingredients',
      one: '1 ingredient',
    );
    return 'Calculated from $counted of $_temp0';
  }

  @override
  String get nutritionMissingHeading => 'Ingredients not counted';

  @override
  String get nutritionReasonNoMatch =>
      'is not in the Swedish Food Agency\'s table';

  @override
  String get nutritionReasonNoAmount =>
      'the amount cannot be converted to grams';

  @override
  String nutritionMissingLine(String name, String reason) {
    return '$name: $reason';
  }

  @override
  String get nutritionPickFood => 'Choose food';

  @override
  String a11yNutritionPickFoodFor(String name) {
    return 'Choose food for $name';
  }

  @override
  String get nutritionIngredientsHeading => 'Ingredients';

  @override
  String nutritionCountedAs(String food) {
    return 'Counted as $food';
  }

  @override
  String get nutritionChange => 'Change';

  @override
  String a11yNutritionChangeFoodFor(String name) {
    return 'Change food for $name';
  }

  @override
  String nutritionSource(String version) {
    return 'Source: the Swedish Food Agency\'s food database, version $version (CC BY 4.0). The values are estimates.';
  }

  @override
  String get nutritionLoadFailed =>
      'The nutrition values could not be calculated.';

  @override
  String nutritionPickerTitle(String name) {
    return 'Choose food for $name';
  }

  @override
  String get nutritionPickerSearchLabel => 'Search foods';

  @override
  String get nutritionPickerHint =>
      'The choice applies to every recipe, for the whole household.';

  @override
  String nutritionPickerResultCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count results',
      one: '1 result',
    );
    return '$_temp0';
  }

  @override
  String get nutritionPickerNoResults => 'No foods found';

  @override
  String get nutritionPickerSaved => 'Saved for the whole household';

  @override
  String get nutritionPickerSaveFailed =>
      'The choice could not be saved. Try again.';

  @override
  String get nutritionEstimatedBadge => 'Estimated';

  @override
  String get a11yNutritionEstimatedBadge => 'Estimated amount';

  @override
  String nutritionCoverageWithEstimates(int counted, int total, int estimated) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: '$total ingredients',
      one: '1 ingredient',
    );
    return 'Calculated from $counted of $_temp0, $estimated with an estimated amount';
  }

  @override
  String get nutritionEnterAmount => 'Enter amount';

  @override
  String a11yNutritionEnterAmountFor(String name) {
    return 'Enter an amount for $name';
  }

  @override
  String a11yNutritionChangeAmountFor(String name) {
    return 'Change the amount for $name';
  }

  @override
  String nutritionAmountSheetTitle(String name) {
    return 'Amount for $name';
  }

  @override
  String get nutritionAmountFieldLabel => 'Amount';

  @override
  String get nutritionAmountUnitLabel => 'Unit';

  @override
  String get nutritionAmountInvalid => 'Enter a number above 0.';

  @override
  String get nutritionAmountRemove => 'Remove amount';

  @override
  String nutritionAmountScopeTitle(String amount, String name) {
    return 'Is $amount $name for this recipe only?';
  }

  @override
  String nutritionAmountScopeBody(String name) {
    return 'You can also use the amount in every recipe where $name has no amount.';
  }

  @override
  String get nutritionAmountScopeRecipe => 'This recipe only';

  @override
  String get nutritionAmountScopeAll => 'All recipes';

  @override
  String get nutritionAmountSaved => 'The amount was saved';

  @override
  String get nutritionAmountRemoved => 'The amount was removed';

  @override
  String get nutritionAmountSaveFailed =>
      'The amount could not be saved. Try again.';

  @override
  String get nutritionAmountFull =>
      'The household\'s saved amounts are full. Remove one to save a new one.';

  @override
  String nutritionCountedAsOwn(String food) {
    return 'Counted as $food, your amount';
  }

  @override
  String get nutritionPickerClear => 'Remove the household\'s choice';

  @override
  String get a11yNutritionPickerClose => 'Close the food picker';

  @override
  String get settingsNutritionStripTitle => 'Show nutrition strip on recipes';

  @override
  String get settingsNutritionStripSubtitle =>
      'Shows calories, protein, carbohydrates and fat under the recipe\'s name. The full table is always under Nutrition values.';

  @override
  String get licensesLivsmedelsverketHeading =>
      'The Swedish Food Agency\'s food database';

  @override
  String get licensesLivsmedelsverketBody =>
      'Nutrition values in Butlery are calculated from the Swedish Food Agency\'s (Livsmedelsverket) food database, licensed under Creative Commons Attribution 4.0 (CC BY 4.0, creativecommons.org/licences/by/4.0). The figures have been recalculated to the amounts the recipe states. Source: Livsmedelsverket, livsmedelsverket.se.';

  @override
  String get nutritionLoading => 'Calculating nutrition values …';

  @override
  String get settingsRecipesSection => 'Recipes';

  @override
  String shoppingListsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lists',
      one: '1 list',
    );
    return '$_temp0';
  }

  @override
  String get shoppingNewShoppingList => 'New shopping list';

  @override
  String get a11yShoppingPickList => 'Choose list';

  @override
  String get guestBandLabel => 'You\'re trying it as a guest';

  @override
  String get guestCreateAccount => 'Create account';

  @override
  String get guestNotNow => 'Not now';

  @override
  String get guestAllergyTitle =>
      'Does anyone in the household have allergies?';

  @override
  String get guestAllergyBody =>
      'Set them up and Butlery will filter them out of recipes and the weekly menu. Always check the packaging as well.';

  @override
  String get guestAllergyAction => 'Set up';

  @override
  String get guestAllergyDismiss => 'Close';

  @override
  String get guestSheetShareTitle => 'Create an account to share';

  @override
  String get guestSheetShareBody =>
      'Sharing needs an account, so the person you share with can see who you are. Everything you did as a guest comes with you.';

  @override
  String get guestSheetTogetherTitle =>
      'Create an account to do things together';

  @override
  String get guestSheetTogetherBody =>
      'Friends, groups, messages and the household need an account, so others can see who you are. Everything you did as a guest comes with you.';

  @override
  String get guestSheetImportLimitTitle => 'You have used your three imports';

  @override
  String get guestSheetImportLimitBody =>
      'Create a free account to import more recipes from links and photos. The recipes you have already imported come with you.';

  @override
  String get guestRequiresAccount => 'Requires account';

  @override
  String get guestAccountValue => 'Guest';

  @override
  String guestImportsLeft(int count) {
    return '$count of 3 imports left as a guest';
  }

  @override
  String get guestCountsAsImport => 'Counts as an import';

  @override
  String get llmGuestImportLimit => 'You have used your three imports';

  @override
  String get llmGuestCapacity =>
      'Guest imports are temporarily unavailable. Create a free account to import.';

  @override
  String get guestTryWithoutAccount => 'Try without an account';

  @override
  String get guestStartBody =>
      'The same questions as for a new account. What you save as a guest comes with you if you create an account later.';

  @override
  String get guestStartYearNote => 'We only save the year, not the full date.';

  @override
  String get guestStartBackToSignIn => 'Back to sign in';

  @override
  String get guestStartPreparing => 'Getting your guest account ready';

  @override
  String get guestStartFailed => 'The guest account could not be created';

  @override
  String get guestUpgradeBody =>
      'Everything you did as a guest comes with you to the account.';

  @override
  String get guestUpgradeDone =>
      'The account is created. An email with a link to confirm the address has been sent.';

  @override
  String get guestUpgradeDoneProvider =>
      'The account is created. Everything you did as a guest is kept.';

  @override
  String get guestUpgradeFinishFailed =>
      'The account is created but could not be finished. Try again.';

  @override
  String get guestSignInInstead => 'Sign in instead';

  @override
  String get guestSignInInsteadTitle => 'Sign in instead?';

  @override
  String get guestSignInInsteadBody =>
      'Your guest account and everything you saved will be deleted. What you did as a guest does not come with you to the account you sign in to.';

  @override
  String get guestSignInInsteadConfirm => 'Delete and sign in';

  @override
  String get guestLogoutTitle => 'Sign out as a guest?';

  @override
  String get guestLogoutBody =>
      'Your guest account and everything you saved will be deleted.';

  @override
  String get guestLogoutConfirm => 'Sign out and delete';

  @override
  String get guestErasing => 'Deleting the guest account';

  @override
  String get guestEraseFailed =>
      'The guest account could not be deleted. You are still signed in.';

  @override
  String get guestDeleteTitle => 'Delete the guest account?';

  @override
  String get guestDeleteConfirm => 'Delete';

  @override
  String get motivationRemovedCopyright =>
      'The content was copied from someone else without permission or a source, which breaks the copyright rules.';

  @override
  String get motivationRemovedSpam =>
      'The content was advertising or spam, which is not allowed in Butlery.';

  @override
  String get motivationRemovedAbuse =>
      'The content was offensive or inappropriate, which breaks the community guidelines.';

  @override
  String get motivationRemovedHarassment =>
      'The content harassed another person, which breaks the community guidelines.';

  @override
  String get motivationRemovedOther =>
      'The content broke the community guidelines.';

  @override
  String get motivationHiddenRules =>
      'The profile broke the community guidelines and is no longer shown to others.';

  @override
  String get motivationHiddenSpam =>
      'The profile was used for advertising or spam and is no longer shown to others.';

  @override
  String get motivationKeptNoBreach =>
      'We found no breach of the community guidelines, so the content stays.';

  @override
  String get motivationKeptAlreadyGone =>
      'The content was already removed when we reviewed the report.';

  @override
  String get motivationKeptUnclear =>
      'We could not assess the report with what we had, so the content stays.';

  @override
  String get motivationMisattributionNameRemoved =>
      'Your name has been removed from the dish.';

  @override
  String get myContentDecisionsTitle => 'Decisions about my content';

  @override
  String get settingsMyContentDecisionsSubtitle =>
      'Decisions about what you have shared';

  @override
  String get myContentDecisionsEmpty =>
      'There are no decisions about your content.';

  @override
  String get myContentDecisionsLoadFailed => 'Could not load the decisions';

  @override
  String get decisionDetailReporterTitle => 'Your report';

  @override
  String get decisionDetailOwnerTitle => 'Decision about your content';

  @override
  String get decisionDetailLoadFailed => 'Could not load the decision';

  @override
  String get decisionDetailNotFound => 'We cannot find this decision.';

  @override
  String decisionSubjectRecipe(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Your recipe',
        'other': 'A recipe',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionSubjectComment(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Your comment',
        'other': 'A comment',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionSubjectMessage(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Your message',
        'other': 'A message',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionSubjectProfile(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Your profile',
        'other': 'A profile',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionSubjectCookSnap(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Your photo',
        'other': 'A photo',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionSubjectGroup(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Your group',
        'other': 'A group',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionSubjectMenuDish(String who) {
    String _temp0 = intl.Intl.selectLogic(
      who,
      {
        'owner': 'Your dish',
        'other': 'A dish',
      },
    );
    return '$_temp0';
  }

  @override
  String decisionReporterLine(String subject, String reason) {
    return '$subject for $reason';
  }

  @override
  String decisionOwnerReportedFor(String reason) {
    return 'Reported for $reason';
  }

  @override
  String get decisionYouReportedLabel => 'You reported';

  @override
  String get decisionConcernsLabel => 'This concerns';

  @override
  String decisionReportedOnLabel(String date) {
    return 'Reported $date';
  }

  @override
  String get decisionHeadlineContentRemoved => 'The content has been removed';

  @override
  String get decisionHeadlineProfileHidden =>
      'The profile has been hidden from others';

  @override
  String get decisionHeadlineNoAction => 'The content stays';

  @override
  String get decisionStatusAppealed => 'Appealed';

  @override
  String get decisionStatusDecided => 'Decided';

  @override
  String get appealPromptTitle => 'Do you disagree?';

  @override
  String appealPromptBody(String date) {
    return 'You can appeal once, no later than $date.';
  }

  @override
  String get appealWindowClosedInfo => 'The time to appeal has run out.';

  @override
  String appealYourLabel(String date) {
    return 'Your appeal · $date';
  }

  @override
  String get appealUnderReview =>
      'The decision is being reviewed again. You will get a new answer here and a notification.';

  @override
  String appealAnswerLabel(String date) {
    return 'Answer to your appeal · $date';
  }

  @override
  String get appealAnswerUpheldHeadline => 'The decision stands';

  @override
  String get appealAnswerUpheldBody =>
      'We have reviewed the decision again and it stands.';

  @override
  String get appealAnswerReversedHeadline => 'The decision is changed';

  @override
  String get appealAnswerReversedBody =>
      'We have reviewed the decision again and are changing it.';

  @override
  String get appealAnswerReversedOwnerRemoved =>
      'The content could not be restored, but you are welcome to post it again.';

  @override
  String get appealAnswerFinal => 'The answer is final in the app.';

  @override
  String get appealFormTitle => 'Appeal the decision';

  @override
  String get appealFormIntro =>
      'The decision is reviewed again and you get a new answer in the app.';

  @override
  String get appealFormHint => 'Write your reasons here';

  @override
  String get appealFormOnceReporter =>
      'You can only appeal once. The owner of the content does not see what you write.';

  @override
  String get appealFormOnceOwner =>
      'You can only appeal once. The person who reported does not see what you write.';

  @override
  String get appealSubmit => 'Send appeal';

  @override
  String get appealSent => 'Appeal sent';

  @override
  String appealCounter(int count, int max) {
    return '$count / $max';
  }

  @override
  String get appealErrorWindowClosed => 'The time to appeal has run out.';

  @override
  String get appealErrorExists => 'You have already appealed this decision.';

  @override
  String get appealErrorNotAllowed => 'You cannot appeal this decision.';

  @override
  String get appealErrorNotFound => 'We cannot find a decision to appeal.';

  @override
  String appealErrorInvalidText(int min, int max) {
    String _temp0 = intl.Intl.pluralLogic(
      max,
      locale: localeName,
      other: '$max characters',
      one: '1 character',
    );
    return 'Write at least $min and at most $_temp0.';
  }

  @override
  String get appealErrorGeneric => 'The appeal could not be sent. Try again.';

  @override
  String moderatorTabReports(int count) {
    return 'Reports ($count)';
  }

  @override
  String moderatorTabAppeals(int count) {
    return 'Appeals ($count)';
  }

  @override
  String get moderatorCloseSheetTitle => 'Close and notify';

  @override
  String moderatorCloseSheetDecision(String decision) {
    return 'Decision: $decision';
  }

  @override
  String get moderatorCloseChoose => 'Choose a reason';

  @override
  String get moderatorClosePreviewTitle => 'What they will see';

  @override
  String moderatorClosePreviewReporter(String headline) {
    return 'The reporter: “$headline” and the reason.';
  }

  @override
  String moderatorClosePreviewOwner(String headline) {
    return 'The owner: “$headline” and the reason. Neither sees the other’s name.';
  }

  @override
  String get moderatorClosePreviewOwnerNone =>
      'The owner gets no notice when the content stays.';

  @override
  String get moderatorAppealsEmpty => 'No open appeals right now.';

  @override
  String get moderatorAppealsLoadFailed => 'Could not load appeals';

  @override
  String get moderatorAppealFromReporter => 'Appeal · from the reporter';

  @override
  String get moderatorAppealFromOwner => 'Appeal · from the owner';

  @override
  String moderatorAppealDecisionLine(String date, String decision) {
    return 'Your decision $date: $decision';
  }

  @override
  String moderatorAppealReceived(String date) {
    return 'Received $date';
  }

  @override
  String get moderatorAppealAnswerButton => 'Answer';

  @override
  String get moderatorAnswerTitle => 'Answer the appeal';

  @override
  String get moderatorAnswerNoteTitle => 'This cannot be undone';

  @override
  String get moderatorAnswerNoteBody =>
      'It was deleted when you removed it. The owner is told the decision has changed and that they can post it again.';

  @override
  String get moderatorAnswerSubmit => 'Send answer';

  @override
  String get moderatorAnswerSent =>
      'The answer is sent. The person has been notified.';

  @override
  String get moderatorAnswerFailed => 'The answer could not be sent.';

  @override
  String get moderatorAnswerUnchanged => 'The appeal is still in the list.';

  @override
  String get moderatorAppealAlreadyAnswered =>
      'This appeal has already been answered.';

  @override
  String get loadingMyContentDecisions => 'Loading the decisions …';

  @override
  String get listInvitationsSection => 'Invitations';

  @override
  String listInvitationMetaEdit(String name) {
    return '$name invites you to their shared list. You can edit it.';
  }

  @override
  String listInvitationMetaView(String name) {
    return '$name invites you to their shared list. You can view it.';
  }

  @override
  String get listInvitationUnknownSender => 'Someone';

  @override
  String get listInvitationDecline => 'Decline';

  @override
  String get listInvitationJoin => 'Join';

  @override
  String get listInvitationMoreActions => 'More options for the invitation';

  @override
  String listInvitationBlockSender(String name) {
    return 'Block $name';
  }

  @override
  String listInvitationJoined(String listName) {
    return 'You joined $listName';
  }

  @override
  String get listInvitationDeclinedNotice => 'Invitation declined';

  @override
  String get listInvitationNoLongerValid => 'The invitation is no longer valid';

  @override
  String get listInvitationActionFailed =>
      'Could not respond to the invitation';

  @override
  String get listInviteHeading => 'Invite friends';

  @override
  String listInviteButtonCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count friends',
      one: '1 friend',
    );
    return 'Invite $_temp0';
  }

  @override
  String listInviteSentOne(String name) {
    return 'Invitation sent. $name joins once they accept.';
  }

  @override
  String listInviteSentMany(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count invitations',
      one: '1 invitation',
    );
    return '$_temp0 sent. They join once they accept.';
  }

  @override
  String listInviteNotInvited(String names) {
    return '$names could not be invited right now.';
  }

  @override
  String get listInviteFailed => 'The invitation could not be sent';

  @override
  String get listInvitePendingHeading => 'Invited';

  @override
  String get listInviteNotAnsweredYet => 'Has not answered yet';

  @override
  String get listInviteStatusPending => 'Waiting';

  @override
  String get listInviteRevoke => 'Take back invitation';

  @override
  String get listInviteRevoked => 'Invitation taken back';

  @override
  String get listInviteRevokeFailed => 'The invitation could not be taken back';

  @override
  String get listInviteAlreadyInvited => 'Already invited';

  @override
  String get listInviteConvertedInvited =>
      'The list is shared. Your friends join once they accept.';

  @override
  String listInviteConvertedSomeNotInvited(String names) {
    return 'The list is shared, but $names could not be invited right now.';
  }

  @override
  String get listInviteShareSent =>
      'Invitation sent. Recipients join once they accept.';

  @override
  String get authContinueWithGoogle => 'Continue with Google';

  @override
  String get authContinueWithApple => 'Continue with Apple';

  @override
  String authProviderFailed(String provider) {
    return 'Signing in with $provider did not work. Try again.';
  }

  @override
  String get authProviderAccountExists =>
      'There is already an account with that email address. Sign in with email and password.';

  @override
  String authProviderWrongAccount(String provider) {
    return 'That was a different $provider account from the one this account uses. Choose the same account again.';
  }

  @override
  String get providerTermsTitle => 'Welcome to Butlery';

  @override
  String get providerTermsSubtitle =>
      'One step left before the account is created.';

  @override
  String get providerTermsNameHelp =>
      'Others in your groups and shared lists see your name. You can change it later.';

  @override
  String get providerTermsCancelAndDelete => 'Cancel and remove the account';

  @override
  String get providerTermsSaveFailed =>
      'The account could not be created. Try again.';

  @override
  String get providerTermsNoEmail =>
      'The account could not be created because no email address came from Google or Apple. Try again.';

  @override
  String get providerLinkTitle => 'Link accounts';

  @override
  String providerLinkBody(String email, String provider) {
    return 'There is already a Butlery account for $email. Enter your Butlery password once and $provider is linked to the account.';
  }

  @override
  String get providerLinkSubmit => 'Link';

  @override
  String providerLinkFailed(String provider) {
    return '$provider could not be linked to the account. Try again with Continue with $provider.';
  }

  @override
  String get mfaBackupCodeProviderRejected =>
      'The backup code is not right. A used code cannot be used again.';

  @override
  String mfaBackupCodeProviderSupport(String provider) {
    return 'With $provider on this device the backup code cannot be checked here. Write to us and we will help you into the account.';
  }

  @override
  String get mfaBackupCodeContactSupport => 'Write to support';

  @override
  String get mfaBackupCodeSupportSubject => 'Signing in with a backup code';

  @override
  String accountSecurityEmailProviderReauth(String provider) {
    return 'You confirm it is you with $provider before the address is changed.';
  }

  @override
  String mfaBackupCodeRecoveredSignInAgain(String provider) {
    return 'The backup code worked, so two-step verification is off. The sign-in did not finish: sign in with $provider again to get in.';
  }

  @override
  String get mfaBackupCodeRecoveredSignInAgainPassword =>
      'The backup code worked, so two-step verification is off. The sign-in did not finish: sign in again to get in.';

  @override
  String mfaBackupCodeSignInAgainWith(String provider) {
    return 'Sign in with $provider';
  }

  @override
  String get mfaBackupCodeSignInAgain => 'Sign in again';

  @override
  String mfaBackupCodeNoEmail(String address) {
    return 'The email app could not be opened. Write to $address.';
  }

  @override
  String get accountSecurityEmailCannotConfirmHere =>
      'The change can\'t be confirmed on this device, because the account\'s sign-in isn\'t available here. Change the address on a device where you can sign in to the account.';

  @override
  String get settingsSignInMethodsTitle => 'Sign-in methods';

  @override
  String get signInMethodsEmailName => 'Email';

  @override
  String get signInMethodsPassword => 'Email and password';

  @override
  String get signInMethodsOn => 'On';

  @override
  String get signInMethodsNotLinked => 'Not linked';

  @override
  String get signInMethodsLink => 'Link';

  @override
  String get signInMethodsUnlink => 'Unlink';

  @override
  String get signInMethodsSetPassword => 'Set password';

  @override
  String signInMethodsSetPasswordBody(String email) {
    return 'The password is for $email. You can then also sign in with email and password.';
  }

  @override
  String get signInMethodsLastOne =>
      'The last sign-in method can\'t be removed. You always need at least one way to sign in.';

  @override
  String signInMethodsOnlyProvider(String provider) {
    return '$provider is the way you sign in right now and can\'t be unlinked. Set a password or link another method first.';
  }

  @override
  String get signInMethodsNoAddress =>
      'A password can\'t be set, because the account has no email address.';

  @override
  String signInMethodsUnlinkTitle(String provider) {
    return 'Unlink $provider?';
  }

  @override
  String signInMethodsUnlinkBody(String provider) {
    return 'You can no longer sign in with $provider.';
  }

  @override
  String get signInMethodsInsteadPassword =>
      'You sign in with email and password instead.';

  @override
  String signInMethodsInsteadProvider(String provider) {
    return 'You sign in with $provider instead.';
  }

  @override
  String get signInMethodsUnlinkAppleAsks =>
      'Apple shows its sheet once more, so that we can ask Apple to remove the link.';

  @override
  String get signInMethodsUnlinkAppleYourself =>
      'Butlery stays under Sign in with Apple in your Apple account until you remove it there.';

  @override
  String signInMethodsLinked(String provider) {
    return '$provider is linked to the account.';
  }

  @override
  String signInMethodsUnlinked(String provider) {
    return '$provider is unlinked.';
  }

  @override
  String get signInMethodsPasswordSet =>
      'The password is set. You can now sign in with email and password.';

  @override
  String signInMethodsAlreadyUsed(String provider) {
    return 'That $provider account is already used by another Butlery account.';
  }

  @override
  String signInMethodsAlreadyLinked(String provider) {
    return '$provider is already linked to the account.';
  }

  @override
  String signInMethodsLinkFailed(String provider) {
    return '$provider couldn\'t be linked to the account. Try again.';
  }

  @override
  String signInMethodsUnlinkFailed(String provider) {
    return '$provider couldn\'t be unlinked. The sign-in method is still there.';
  }

  @override
  String get signInMethodsPasswordFailed =>
      'The password couldn\'t be set. Try again.';

  @override
  String familyRatingHouseholdPill(String value) {
    return 'Household $value';
  }

  @override
  String get ingredientSearchHeading => 'What can I cook?';

  @override
  String cookingModeIngredientRows(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count rows',
      one: '1 row',
    );
    return '$_temp0';
  }

  @override
  String get cookingModeSwapHint =>
      'Press and hold a row to swap an ingredient';

  @override
  String cookingModeNextStepPreview(String step) {
    return 'Next: $step';
  }

  @override
  String get consentTermsHeading => 'Conditions for the app to exist';

  @override
  String get consentEssentialTitle => 'Essential operation';

  @override
  String get consentEssentialBody =>
      'Sign-in, your recipes, sync between your devices.';

  @override
  String get consentDataProcessingBody =>
      'Saving what you write, so it is still there tomorrow.';

  @override
  String get consentRequiredNoteBefore =>
      'These cannot be switched off – without them there is no service to say yes or no to. To leave altogether, the way is to ';

  @override
  String get consentRequiredNoteBold => 'delete the account';

  @override
  String get consentRequiredNoteAfter => ', not a switch here.';

  @override
  String get consentYourChoices => 'Your choices';

  @override
  String get consentMarketing => 'Mailings';

  @override
  String get consentMarketingDescription =>
      'News about the app. Never anyone else\'s offers.';

  @override
  String get consentSocial => 'Social';

  @override
  String get consentSocialDescription => 'Friends, shared lists, comments.';

  @override
  String consentSavedVersion(String version, String date, String device) {
    return 'Saved version $version · $date$device. We keep the version to be able to show what you said yes to, not just that you did.';
  }

  @override
  String get consentHistory => 'History';

  @override
  String get consentHistorySubtitle => 'What you said yes and no to, and when';

  @override
  String get consentHistoryEmpty => 'No saved choices yet.';

  @override
  String get consentRevokeAllOptional => 'Revoke everything optional';

  @override
  String get consentHistoryNoneOn => 'No optional consents';

  @override
  String get dataExportPageTitle => 'Get your data';

  @override
  String get dataExportHeadline => 'Everything you put in, in one file';

  @override
  String get dataExportIncludesRecipesComments =>
      'Your recipes, comments and ratings';

  @override
  String get dataExportIncludesSocial =>
      'Friends, messages and activity history';

  @override
  String get dataExportFileTitle => 'Your export (JSON)';

  @override
  String pendingDeletionNoticeTitle(String date) {
    return 'The account is deleted on $date';
  }

  @override
  String get pendingDeletionNoticeBody =>
      'Until then everything is kept, and you can undo the deletion. After that nothing can be restored.';

  @override
  String pendingDeletionListHeading(String date) {
    return 'This is deleted on $date';
  }

  @override
  String get pendingDeletionItemRecipes => 'Recipes, menus and lists';

  @override
  String get pendingDeletionItemRecipesNote => 'everything you created';

  @override
  String get pendingDeletionItemRatings => 'Ratings, comments and cook snaps';

  @override
  String get pendingDeletionItemRatingsNote =>
      'also on other people\'s recipes';

  @override
  String get pendingDeletionItemHousehold => 'Household and shares';

  @override
  String get pendingDeletionItemHouseholdNote =>
      'you are removed, the lists stay with the others';

  @override
  String get pendingDeletionItemCache => 'Search index and local cache';

  @override
  String get pendingDeletionItemCacheNote => 'cleared first of all';

  @override
  String get legalLinkTerms => 'Terms';

  @override
  String get legalLinkPrivacy => 'Privacy';

  @override
  String get legalLinkGuidelines => 'Guidelines';

  @override
  String get legalLinkContact => 'Contact';

  @override
  String get legalCommunityGuidelinesTitle => 'How we treat each other';

  @override
  String get accountSecurityEmailNow => 'Now: ';

  @override
  String get accountSecurityRepeatNewPassword => 'Repeat new password';

  @override
  String get decisionOutcomeLabel => 'Outcome:';

  @override
  String get decisionAppealLink => 'I want to appeal';

  @override
  String get myReportsStatusActioned => 'Actioned';

  @override
  String get myContentDecisionsIntro =>
      'Decisions about things you have posted. Each decision can be appealed once.';

  @override
  String get myReportsIntro =>
      'What you have reported and what has happened since. We tell you the outcome, also when it went against you.';

  @override
  String get appealFormQuestion => 'Why do you think the decision is wrong?';

  @override
  String trashRowDeleted(String when, String left) {
    return 'Deleted $when · $left';
  }

  @override
  String get trashDeletedToday => 'today';

  @override
  String trashUrgentLeft(String left, String day) {
    return '$left – gone for good on $day';
  }

  @override
  String trashUrgentToday(String left) {
    return '$left – gone for good today';
  }

  @override
  String get licensesIntro =>
      'What Butlery is built on, and the terms it comes with.';

  @override
  String get mfaOnTitle => 'On';

  @override
  String get mfaOffTitle => 'Not on';

  @override
  String get mfaLostPhoneTitle => 'If the phone is gone';

  @override
  String get mfaLostPhoneBody =>
      'When you turned the protection on you got ten one-time codes to write down. With one of them you get in even without the phone.';

  @override
  String get mfaRemoveLink => 'Remove';

  @override
  String groupSharedRecipesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'recipes',
      one: 'recipe',
    );
    return '$_temp0';
  }

  @override
  String groupSharedMenusLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'menus',
      one: 'menu',
    );
    return '$_temp0';
  }

  @override
  String groupSharedListsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'shopping lists',
      one: 'shopping list',
    );
    return '$_temp0';
  }

  @override
  String get groupInvitedLabel => 'Invited';

  @override
  String get groupInviteLink => '+ Invite';

  @override
  String get groupMembersHeading => 'Members';

  @override
  String get groupShareSheetButton => 'Share a recipe, menu or list';

  @override
  String get messagingNewGroupChat => 'New group chat';

  @override
  String get profileChangePhoto => 'Change picture';

  @override
  String get profileDisplayNameAvailable => 'Available';

  @override
  String get sharedSaveAction => 'Save';

  @override
  String get sharedSavedState => 'Saved';

  @override
  String sharedFromNameAgo(String name, String time) {
    return 'from $name · $time';
  }

  @override
  String sharedSharedAgo(String time) {
    return 'shared $time';
  }

  @override
  String get sharedNewMark => 'new';

  @override
  String sharedFromHeading(String name) {
    return 'From $name';
  }

  @override
  String sharedFromSummary(int count, String time) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '$count recipe',
    );
    return '$_temp0 · latest $time';
  }

  @override
  String socialFriendsSection(int count) {
    return 'Friends · $count';
  }

  @override
  String get socialRequestsSelect => 'Select';

  @override
  String socialRequestsIncomingSection(int count) {
    return 'Incoming · $count';
  }

  @override
  String socialRequestsSentSection(int count) {
    return 'Sent · $count';
  }

  @override
  String get messagingAboutConversation => 'About the conversation';

  @override
  String messagingConversationSubline(String name, int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count in the conversation',
      one: '1 in the conversation',
    );
    return '$name · $_temp0';
  }

  @override
  String get messagingConversationNameRow => 'Conversation name';

  @override
  String get messagingAddSomeoneRow => 'Add someone';

  @override
  String get messagingInConversationSection => 'In the conversation';

  @override
  String get messagingMemberYou => 'you';

  @override
  String messagingRemoveFromConversationTitle(String name) {
    return 'Remove $name from the conversation?';
  }

  @override
  String messagingRemoveFromConversationBody(String name) {
    return '$name stops seeing new messages. What has already been written stays, and the account is not affected. You can invite them again.';
  }

  @override
  String get messagingLeaveConversationRow => 'Leave the conversation';

  @override
  String get messagingLeaveConversationSub =>
      'You stop seeing new messages. What you wrote stays.';

  @override
  String recipeRowMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String publicProfileRecipeCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count public recipes',
      one: '1 public recipe',
    );
    return '$_temp0';
  }

  @override
  String get friendProfileBetweenYou => 'Between you';

  @override
  String get friendProfileSharedWithYouSub => 'Found under Shared with me';

  @override
  String get friendProfilePublicRecipesSub =>
      'Visible to everyone, not only you';

  @override
  String friendProfileShareLinkRow(String owner) {
    return 'Share a link to $owner profile';
  }

  @override
  String get friendProfileShareLinkSub =>
      'Shows the public page, nothing you have shared';

  @override
  String profileFriendsLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'friends',
      one: 'friend',
    );
    return '$_temp0';
  }

  @override
  String profilePublicRecipesLabel(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'public recipes',
      one: 'public recipe',
    );
    return '$_temp0';
  }

  @override
  String get adminOpsSectionTitle => 'Operations · recent events';

  @override
  String get adminOpsSparseTitle => 'Sparse on purpose.';

  @override
  String get adminOpsSparseBody =>
      'The log fills once the app has users. A short log does not mean anything is missing.';

  @override
  String get adminOpsEventNotificationCleanup => 'Notifications cleaned';

  @override
  String get adminOpsEventIngredientCleanup => 'Ingredients cleaned';

  @override
  String get adminOpsEventSystemEventsCleanup => 'Ops log cleaned';

  @override
  String get adminOpsEventSocialRequestsCleanup => 'Old requests cleaned';

  @override
  String get adminOpsEventAuditLogCleanup => 'Audit log cleaned';

  @override
  String get adminOpsEventDeletionAuditLogCleanup => 'Deletion log cleaned';

  @override
  String get adminParsingSectionTitle => 'Parsing by domain';

  @override
  String get adminParsingColSuccess => 'Succeeded';

  @override
  String get adminParsingColStuck => 'Stuck on';

  @override
  String get adminParsingTableNote =>
      'Tap a row to see its imports. The field in the last column is the one corrected most often for the domain.';

  @override
  String get moderatorContentTypeRecipe => 'Recipe';

  @override
  String get moderatorContentTypeComment => 'Comment';

  @override
  String get moderatorContentTypeMessage => 'Message';

  @override
  String get moderatorContentTypeProfile => 'Profile';

  @override
  String get moderatorContentTypeCookSnap => 'Cook snap';

  @override
  String get moderatorContentTypeGroup => 'Group';

  @override
  String get moderatorStatusNew => 'New';

  @override
  String get moderatorStatusInReview => 'In review';

  @override
  String get moderatorStatusActioned => 'Actioned';

  @override
  String get moderatorStatusClosed => 'Closed';

  @override
  String get moderatorCloseTooltip => 'Close the report';

  @override
  String get familyRatingNotSet => 'not set';

  @override
  String get familyRatingNoteSkip =>
      'Anyone you skip gets no row and is left out of the average. A rating can always be changed, and the latest replaces the earlier one.';

  @override
  String get familyRatingNoteCounts =>
      'The rating counts toward the recipe\'s public average';

  @override
  String get familyRatingNoteAnonymous =>
      ', anonymously and without showing anyone\'s identity.';

  @override
  String get cookbookStatRecipes => 'recipes';

  @override
  String get cookbookStatSort => 'order';

  @override
  String get cookbookStatSortAlphabetical => 'A–Z';

  @override
  String get cookbookStatSortCustom => 'Own';

  @override
  String get cookbookStatUpdated => 'last changed';

  @override
  String get tagDetailNewRule => '+ New rule';

  @override
  String get tagDetailRulesHeading => 'Automatic rules';

  @override
  String get tagDetailStatChanged => 'last changed';

  @override
  String tagDetailRuleTagged(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'tagged $count recipes',
      one: 'tagged 1 recipe',
    );
    return '$_temp0';
  }

  @override
  String tagDetailRecipesHeading(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes with the tag',
      one: '1 recipe with the tag',
    );
    return '$_temp0';
  }

  @override
  String tagDetailRuleSummaryNumber(
    String type,
    String operator,
    String value,
  ) {
    return '$type $operator $value';
  }

  @override
  String get tagEditSheetTitle => 'Edit the tag';

  @override
  String tagDetailStatRulesValue(int enabled, int total) {
    return '$enabled of $total';
  }

  @override
  String tagDetailStatRules(int total) {
    String _temp0 = intl.Intl.pluralLogic(
      total,
      locale: localeName,
      other: 'rules on',
      one: 'rule on',
    );
    return '$_temp0';
  }

  @override
  String personalTagUnusedHeading(int count) {
    return 'Unused ($count)';
  }

  @override
  String get personalTagDeleteAllShort => 'Delete all';

  @override
  String get conflictDiffMineName => 'Yours';

  @override
  String get conflictDiffTheirsName => 'Theirs';

  @override
  String get conflictDiffApplies => 'Applies';

  @override
  String conflictDiffIntro(String name, String title) {
    return 'You and $name edited $title at the same time. Only one of the versions applies – here is how they differ.';
  }

  @override
  String get conflictDiffIntroPlain =>
      'You edited at the same time. Only one of the versions applies – here is how they differ.';

  @override
  String recipeSuggestionKeptNote(String date) {
    return 'The suggestion is kept until $date. Then it is removed.';
  }

  @override
  String get importLinkOrCaptionLabel => 'Link or caption';

  @override
  String get importPasteHelp =>
      'Paste the link to the post, or the whole caption if you have already copied it.';

  @override
  String get importCaptionWarningLead =>
      'A post has no recipe structure – only the caption. I remove emoji and tidy the amounts, but ';

  @override
  String get importCaptionWarningEmphasis =>
      'you will often need to fix something';

  @override
  String get importVideoNotRead =>
      'The video itself is never read. What is not written in text does not exist for the import – and that should be said up front, not found out afterwards.';

  @override
  String get importFetchRecipe => 'Get the recipe';

  @override
  String get shoppingNewSharedListTitle => 'New shared list';

  @override
  String get shoppingSharedListNameLabel => 'List name';

  @override
  String get shoppingShareWithHeading => 'Share with';

  @override
  String get shoppingPermissionHeading => 'Permission';

  @override
  String get shoppingPermissionCanEdit => 'Can edit';

  @override
  String get shoppingPermissionReadOnlyTab => 'Read only';

  @override
  String get shoppingPermissionCanEditHelp =>
      'Everyone can add and tick off items in real time.';

  @override
  String get shoppingPermissionViewOnlyHelp =>
      'The people you share with can see the list but not change it.';

  @override
  String get shoppingNoFriendsToShareWith =>
      'You have no friends to share with yet.';

  @override
  String get importMoreFilters => 'More';

  @override
  String importArchivedHeading(int count) {
    return 'Archived recipes · $count';
  }

  @override
  String importRestoreCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return 'Restore $_temp0';
  }

  @override
  String get importFiltersTitle => 'Filters';

  @override
  String get importTimeHeading => 'Time';

  @override
  String get importTagsHeading => 'Tags';

  @override
  String importRecipeMinutes(int minutes) {
    return '$minutes min';
  }

  @override
  String importUpToMinutes(int minutes) {
    return 'At most $minutes min';
  }

  @override
  String get importArchiveTitle => 'From the archive';

  @override
  String importPreviewFoundCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count recipes',
      one: '1 recipe',
    );
    return '$_temp0 found';
  }

  @override
  String importPreviewParsedCount(int count) {
    return '$count read';
  }

  @override
  String importPreviewProgress(int selected, int total) {
    return '$selected of $total';
  }

  @override
  String get importPreviewUnreadHeading => 'Could not be read';

  @override
  String get importPreviewReadyHeading => 'Ready to save';

  @override
  String get voiceListeningWord => 'listening …';

  @override
  String get importPhotoCameraButton => 'Take photo';

  @override
  String get importPhotoLibraryButton => 'From the library';

  @override
  String importPhotoPagesHeading(int count) {
    return 'Pages · $count';
  }

  @override
  String get heirloomToggleSubtitle =>
      'The photo is saved with the recipe, as its source';

  @override
  String get importPhotoHeirloomHint =>
      'Handwritten heirloom recipes? The original photo is saved on the recipe card.';

  @override
  String get recipeDescriptionOptional => 'Description (optional)';

  @override
  String get recipeMethodHeading => 'Method';

  @override
  String get importPhotoRestartTitle => 'Start over?';

  @override
  String get importPhotoRestartMessage =>
      'The pages you already took are removed if you choose a new picture.';

  @override
  String get importPhotoRestartAction => 'Start over';

  @override
  String get allergenUncheckedLabel => 'Not checked';

  @override
  String get allergenUncheckedDetail =>
      'The allergens have not been checked for this recipe. Read the ingredients yourself.';

  @override
  String get allergenUncheckedA11y => 'Allergens not checked';

  @override
  String get friendsSocialDisabled =>
      'Social features are temporarily switched off.';

  @override
  String get imagePrimaryBadge => 'Main image';

  @override
  String shareTagMessage(String contentName) {
    return 'Take a look at my tag “$contentName”';
  }

  @override
  String chatSharedRecipeLine(String recipeTitle) {
    return 'Shared the recipe “$recipeTitle”';
  }

  @override
  String get shoppingCreateFromTemplate => 'Create list from template';

  @override
  String get errorCouldNotLoadNotificationSettings =>
      'The notification settings could not be loaded. Try again.';

  @override
  String friendProfilePublicRecipesRowOf(String name) {
    return 'Public recipes from $name';
  }

  @override
  String friendProfileShareLinkRowOf(String name) {
    return 'Share a link to the profile of $name';
  }
}
