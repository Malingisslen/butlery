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
  String get validationInvalidEmail => 'Invalid email address';

  @override
  String get validationInvalidUrl => 'Invalid URL';

  @override
  String get validationInvalidPhone => 'Invalid phone number';

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
  String get errorAlreadyExists => 'Already exists.';

  @override
  String errorCouldNotCreate(String itemType) {
    return 'Could not create $itemType. Please try again.';
  }

  @override
  String errorCouldNotUpdate(String itemType) {
    return 'Could not update $itemType. Please try again.';
  }

  @override
  String errorCouldNotDelete(String itemType) {
    return 'Could not delete $itemType. Please try again.';
  }

  @override
  String errorCouldNotLoad(String itemType) {
    return 'Could not load $itemType. Please try again.';
  }

  @override
  String errorWithContext(String action, String error) {
    return 'Error during $action: $error';
  }

  @override
  String errorActionSpecific(String action, String issue) {
    return 'Problem while $action: $issue';
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
    return 'Are you sure you want to delete \"$itemName\"?';
  }

  @override
  String get confirmUnsavedChanges =>
      'You have unsaved changes. Do you want to leave without saving?';

  @override
  String get confirmIrreversibleAction => 'This action cannot be undone.';

  @override
  String get draftRecovery => 'Restore draft';

  @override
  String get draftRecoverySubtitle =>
      'You have unsaved recipe drafts. Would you like to continue where you left off?';

  @override
  String get draftRestore => 'Restore';

  @override
  String get draftStartFresh => 'Start fresh';

  @override
  String get draftRestored => 'Draft restored!';

  @override
  String get draftRestoredDetails => 'fields loaded';

  @override
  String get draftCouldNotRestore =>
      'Could not restore draft. Starting with empty form.';

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
  String get connectivityOfflineMode => 'Offline mode enabled';

  @override
  String get connectivityRestored => 'Connection restored';

  @override
  String get connectivitySyncingPending => 'Syncing pending changes...';

  @override
  String get connectivityLocalSaved => 'Changes saved locally';

  @override
  String get connectivityWillSync => 'Will sync when you\'re back online';

  @override
  String get permissionInsufficient => 'Insufficient permissions';

  @override
  String get permissionReadOnly => 'Read-only access';

  @override
  String get permissionOwnerOnly => 'Only the owner can perform this action';

  @override
  String get permissionRequestEdit => 'Request edit permissions';

  @override
  String get permissionMakePersonalCopy => 'Make a personal copy';

  @override
  String get recoveryCheckConnection => 'Check your internet connection';

  @override
  String get recoveryTryAgain => 'Try again';

  @override
  String get recoveryLoginAgain => 'Sign in again';

  @override
  String get recoveryContactOwner => 'Contact the owner';

  @override
  String get recoveryWaitAndRetry => 'Wait and try again';

  @override
  String get recoveryCheckPermissions => 'Check permissions';

  @override
  String get emptyNoItems => 'No items found.';

  @override
  String get emptyList => 'The list is empty.';

  @override
  String get emptyNoResults => 'No results found.';

  @override
  String get emptyNoFriends => 'No friends yet';

  @override
  String get emptyNoRecipes => 'No recipes yet';

  @override
  String get emptyNoShoppingLists => 'No shopping lists yet';

  @override
  String emptyNoRecipesSubtitle(String addButton) {
    return 'Add your first recipe by tapping \"$addButton\"';
  }

  @override
  String get emptyNoSearchResultsSubtitle =>
      'Try searching for something else or clear the search';

  @override
  String get emptyNoFriendsSearchTitle => 'No friends matched your search';

  @override
  String get emptyNoGroupsSearchTitle => 'No groups matched your search';

  @override
  String get emptyNoMenuTitle => 'No menu generated yet';

  @override
  String get emptyNoMenuSubtitle =>
      'Type what you want or tap the button below';

  @override
  String get emptyNoShoppingListTitle => 'No menu to create shopping list from';

  @override
  String get emptyNoShoppingListSubtitle =>
      'Go back and create a weekly menu first';

  @override
  String get emptyNoFriendsTitle => 'No friends yet';

  @override
  String get emptyNoFriendsSubtitle => 'Add friends to share recipes and menus';

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
  String get emptyGenericTitle => 'No content to display';

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
  String get socialFriendName => 'Friend name';

  @override
  String get socialGroupName => 'Group name';

  @override
  String get socialDisplayName => 'Display name';

  @override
  String get socialCreateGroup => 'Create group';

  @override
  String get socialEditGroup => 'Edit group';

  @override
  String get socialDeleteGroup => 'Delete group';

  @override
  String get socialAddFriend => 'Add friend';

  @override
  String get socialRemoveFriend => 'Remove friend';

  @override
  String get socialSendFriendRequest => 'Send friend request';

  @override
  String get socialAcceptFriendRequest => 'Accept friend request';

  @override
  String get socialDeclineFriendRequest => 'Decline friend request';

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
    return 'Could not leave the group: $error';
  }

  @override
  String get messagingLeave => 'Leave';

  @override
  String get messagingDeleteConversationConfirm =>
      'Are you sure you want to delete this conversation? All messages will be lost.';

  @override
  String messagingCouldNotShowProfile(String error) {
    return 'Could not show profile: $error';
  }

  @override
  String messagingConversationDeleted(String title) {
    return 'Conversation \"$title\" deleted';
  }

  @override
  String messagingCouldNotDeleteConversation(String error) {
    return 'Could not delete conversation: $error';
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
      'Could not change notification settings';

  @override
  String get chatLeaveConversation => 'Leave conversation';

  @override
  String get chatLeaveConversationConfirm =>
      'Are you sure you want to leave this conversation?';

  @override
  String get chatCouldNotLeaveConversation =>
      'Could not leave the conversation';

  @override
  String get chatEditMessage => 'Edit message';

  @override
  String get chatWriteYourMessage => 'Write your message...';

  @override
  String get chatCouldNotEditMessage => 'Could not edit the message';

  @override
  String get chatCouldNotDeleteMessage => 'Could not delete the message';

  @override
  String get chatMessageCopied => 'Message copied';

  @override
  String get chatCouldNotCopyMessage => 'Could not copy the message';

  @override
  String get chatYourRecipes => 'Your recipes';

  @override
  String get chatSharedRecipe => 'Shared recipe';

  @override
  String get chatCheckOutRecipe => 'Check out this recipe!';

  @override
  String get chatCouldNotShareRecipe => 'Could not share recipe';

  @override
  String get chatMenuSharingComingSoon => 'Menu sharing coming soon';

  @override
  String get chatCouldNotShareMenu => 'Could not share menu';

  @override
  String get chatShoppingListSharingComingSoon =>
      'Shopping list sharing coming soon';

  @override
  String get chatCouldNotShareShoppingList => 'Could not share shopping list';

  @override
  String get chatLoadingImage => 'Loading image...';

  @override
  String get chatImageSent => 'Image sent!';

  @override
  String get chatNoImageSelected => 'No image selected';

  @override
  String get chatCouldNotSharePhoto => 'Could not share photo';

  @override
  String get chatDeleteMessage => 'Delete';

  @override
  String get chatDeleteMessageConfirm =>
      'Are you sure you want to delete the message?';

  @override
  String get placeholderSearch => 'Search...';

  @override
  String get placeholderName => 'Enter name';

  @override
  String get placeholderDescription => 'Enter description (optional)';

  @override
  String get placeholderEmail => 'your@email.com';

  @override
  String get placeholderUrl => 'https://example.com';

  @override
  String get placeholderPhone => '+1 555 123 4567';

  @override
  String get statusConnecting => 'Connecting...';

  @override
  String get statusSyncing => 'Syncing...';

  @override
  String get statusUploading => 'Uploading...';

  @override
  String get statusDownloading => 'Downloading...';

  @override
  String get statusProcessing => 'Processing...';

  @override
  String get statusSaving => 'Saving...';

  @override
  String get statusDeleting => 'Deleting...';

  @override
  String get statusCreating => 'Creating...';

  @override
  String get statusUpdating => 'Updating...';

  @override
  String get accessibilityMenuButton => 'Menu button';

  @override
  String get accessibilityBackButton => 'Back';

  @override
  String get accessibilityCloseButton => 'Close';

  @override
  String get accessibilityMoreOptions => 'More options';

  @override
  String get accessibilityExpandButton => 'Expand';

  @override
  String get accessibilityCollapseButton => 'Collapse';

  @override
  String get timeToday => 'Today';

  @override
  String get timeYesterday => 'Yesterday';

  @override
  String get timeTomorrow => 'Tomorrow';

  @override
  String get timeThisWeek => 'This week';

  @override
  String get timeLastWeek => 'Last week';

  @override
  String get timeNextWeek => 'Next week';

  @override
  String get unitMinutesShort => 'min';

  @override
  String get unitHoursShort => 'h';

  @override
  String get unitPiecesShort => 'pcs';

  @override
  String get unitLiters => 'liters';

  @override
  String get unitKilograms => 'kg';

  @override
  String get unitGrams => 'g';

  @override
  String get technicalShowDetails => 'Show technical details';

  @override
  String get technicalHideDetails => 'Hide technical details';

  @override
  String get technicalInformation => 'Technical information';

  @override
  String get technicalContactSupport => 'Contact support';

  @override
  String get technicalTryAgainLater => 'Try again later';

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
  String recipeIngredientsForPortions(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'servings',
      one: 'serving',
    );
    return 'Ingredients for $count $_temp0:';
  }

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
    return '$count recipes';
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
    return '$count recipes';
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
  String get recipeCreateShoppingList => 'Create shopping list';

  @override
  String get recipeUpdateTags => 'Update tags';

  @override
  String get recipeViewSource => 'View source';

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
  String get commonSaveMyCopy => 'Save my copy';

  @override
  String get commonSaveAsNew => 'Save as new';

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
  String get commonLogout => 'Log out';

  @override
  String get commonLogoutNow => 'Log out now';

  @override
  String get commonNoAccess => 'No access';

  @override
  String get commonCreatingCopy => 'Creating copy...';

  @override
  String get commonToHome => 'To home';

  @override
  String get commonTakePhoto => 'Take photo';

  @override
  String get commonSelectFromGallery => 'Select from gallery';

  @override
  String get commonSelectFriends => 'Select friends';

  @override
  String get commonNoContent => 'No content';

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
  String get personalTagDeleted => 'Tag deleted';

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
      String name, int count, int enabled, int total) {
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
  String get allergenSettingsTitle => 'Allergen Settings';

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
    return '$count friends';
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
  String get shoppingCreateListButton => 'Create list';

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
  String get shoppingErrorLoading => 'Error loading';

  @override
  String get shoppingLists => 'Shopping lists';

  @override
  String get shoppingNewList => 'New list';

  @override
  String get shoppingAddFromMenu => 'Add from menu';

  @override
  String get shoppingNoItemsFromMenu => 'No items selected from menu';

  @override
  String shoppingAddItemsCount(int count) {
    return 'Add $count items...';
  }

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
  String shoppingCouldNotCreateList(String error) {
    return 'Could not create list: $error';
  }

  @override
  String shoppingItemsAddedToList(int count, String name) {
    return '$count items added to \"$name\"';
  }

  @override
  String shoppingCouldNotAddItems(String error) {
    return 'Could not add items: $error';
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
  String get profileDataAndBackup => 'Data & Backup';

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
  String get profileManageConsents => 'Manage consents';

  @override
  String get profileManageConsentsSubtitle =>
      'Choose how we may process your personal data (GDPR)';

  @override
  String get profileExportMyData => 'Export my data';

  @override
  String get profileExportMyDataSubtitle =>
      'Download all your data in JSON format (GDPR)';

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
  String profileCouldNotOpenConsentManager(String error) {
    return 'Could not open consent manager: $error';
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
  String get shareShoppingListTitle => 'Share shopping list';

  @override
  String get shareCreateAndShare => 'Create & Share';

  @override
  String get shareRecipeWithFriends => 'Share recipe with friends';

  @override
  String get shareMenuWithFriends => 'Share weekly menu with friends';

  @override
  String get shareShoppingList => 'Share shopping list';

  @override
  String get shareCheckOutRecipe => 'Check out this recipe:';

  @override
  String get shareCheckOutMenu => 'Check out this weekly menu:';

  @override
  String get shareCheckOutShoppingList => 'Check out this shopping list:';

  @override
  String get shareRealtime => 'realtime sharing';

  @override
  String get shareCopy => 'copy';

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
  String get shareMenus => 'menus';

  @override
  String get shareShoppingLists => 'shopping lists';

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
  String get menuSavedMenusSavedEarlier => 'Saved earlier';

  @override
  String get menuLoadMenu => 'Load';

  @override
  String get menuRemoveMenu => 'Remove';

  @override
  String get menuRemoveMenuTitle => 'Remove menu';

  @override
  String get menuMenuNameRequired => 'Menu name required';

  @override
  String get menuMenuToSave => 'Menu to save';

  @override
  String get menuCommentOptional => 'Comment (optional)';

  @override
  String get menuCommentHint => 'Description or notes about the menu';

  @override
  String get menuShareWithFriends => 'Share with friends';

  @override
  String get menuShareThisMenu => 'Share this menu with selected friends';

  @override
  String get menuSelectFriendsToShare => 'Select friends to share with';

  @override
  String get menuNoFriendsAvailable => 'No friends available';

  @override
  String get menuDefaultShareMessage => 'Check out my new weekly menu!';

  @override
  String get menuShareMessageLabel => 'Share message';

  @override
  String get menuShareMessageHint => 'Message sent with the menu';

  @override
  String get menuMenuNameHint => 'E.g. Week 45 or Weekend menu';

  @override
  String get menuUnnamedMenu => 'Unnamed menu';

  @override
  String get socialUnknownUser => 'Unknown user';

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
  String get socialJustNow => 'just now';

  @override
  String socialMinutesAgo(int count) {
    return '$count min ago';
  }

  @override
  String socialHoursAgo(int count) {
    return '$count hours ago';
  }

  @override
  String socialDaysAgo(int count) {
    return '$count days ago';
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
  String get socialSelectAllLabel => 'Select all';

  @override
  String get socialDeselectAllLabel => 'Deselect all';

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
  String get invitationAll => 'All';

  @override
  String get invitationNone => 'None';

  @override
  String get invitationGroups => 'Groups';

  @override
  String get invitationIndividuals => 'Individuals';

  @override
  String get invitationAddTarget => 'Add target';

  @override
  String get invitationSendInvitations => 'Send invitations';

  @override
  String get invitationCreateGroup => 'Create group';

  @override
  String get invitationAffectedTargets => 'Affected targets:';

  @override
  String get invitationView => 'View';

  @override
  String get invitationSendInvitation => 'Send invitation';

  @override
  String get invitationInvite => 'Invite';

  @override
  String get invitationViewMembers => 'View members';

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
  String get discoveryActivity => 'Activity';

  @override
  String discoveryByAuthor(String name) {
    return 'By $name';
  }

  @override
  String get discoveryCategories => 'Categories';

  @override
  String get discoveryContentType => 'Content type';

  @override
  String get discoveryCustomizeExperience =>
      'Customize your discovery experience';

  @override
  String get discoveryDiscover => 'Discover';

  @override
  String get discoveryDiscoverNewContent => 'Discover new content';

  @override
  String get discoveryFeedbackHint =>
      'Help us improve Butlery! Describe your feedback here...';

  @override
  String get discoveryFeedbackThanks =>
      'Thank you for your feedback! We will review it.';

  @override
  String get discoveryFilterContent => 'Filter content';

  @override
  String get discoveryFindPopularContent =>
      'Find popular recipes, menus and lists';

  @override
  String get discoveryForYou => 'For you';

  @override
  String get discoveryGiveFeedback => 'Give feedback';

  @override
  String discoveryItemCount(int count) {
    return '$count items';
  }

  @override
  String get discoveryLoading => 'Loading discovery content...';

  @override
  String get discoveryMenus => 'Menus';

  @override
  String get discoveryNotifications => 'Notifications';

  @override
  String get discoveryPopularNow => 'Popular right now';

  @override
  String get discoveryPushNotifications => 'Push notifications';

  @override
  String get discoveryPushNotificationsDescription =>
      'Get notifications about new content';

  @override
  String get discoveryRecipes => 'Recipes';

  @override
  String get discoverySeeAll => 'See all';

  @override
  String get discoverySendFeedback => 'Send feedback';

  @override
  String get discoverySettings => 'Discovery settings';

  @override
  String get discoverySettingsSaved => 'Settings saved!';

  @override
  String get discoveryShoppingLists => 'Shopping lists';

  @override
  String get discoveryShowFriendActivity => 'Show friend activity';

  @override
  String get discoveryShowFriendActivityDescription =>
      'Show what your friends are doing';

  @override
  String get discoveryShowMenuResults => 'Show menu results';

  @override
  String get discoveryShowRecipeResults => 'Show recipe results';

  @override
  String get discoveryShowRecommendations => 'Show recommendations';

  @override
  String get discoveryShowRecommendationsDescription =>
      'Show personal recommendations';

  @override
  String get discoveryShowShoppingLists => 'Show shopping lists';

  @override
  String get discoveryShowTrends => 'Show trends';

  @override
  String get discoveryShowTrendsDescription =>
      'Show popular content from the community';

  @override
  String get discoveryToDiscover => 'to discover';

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
  String get groupDeleteWarning =>
      'This cannot be undone. All members will be removed from the group.';

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
      'This will disable all optional features such as analytics, marketing, social features and push notifications. You can enable them again at any time.';

  @override
  String get consentRevokeAll => 'Revoke all';

  @override
  String get consentAllRevoked => 'All optional consents have been revoked';

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
  String menuCardMoreRecipes(int count) {
    return '+ $count more recipes';
  }

  @override
  String get menuCardNoRecipes => 'No recipes in menu';

  @override
  String menuCardRecipeCount(int count) {
    return '$count recipes';
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
    return '$count members';
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
  String get recipeTagsUpdated => 'Tags updated';

  @override
  String get recipeTimeMinutes => 'Time (min)';

  @override
  String get recipeUnsavedChangesTitle => 'Unsaved changes';

  @override
  String get recipeWriteManually => 'Write manually';

  @override
  String get searchRecipesHint => 'search recipes...';

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
  String get importContinueWithoutOcr => 'Continue without OCR';

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
  String get importOcrMayFail => 'OCR may fail or give poor results.';

  @override
  String get importOtherApp => 'another app';

  @override
  String get importPasteFromClipboard => 'Paste from clipboard';

  @override
  String get importPasteLinkOrText => 'Paste link or text here...';

  @override
  String get importPasteText => 'Paste text';

  @override
  String get importPhotoDescription =>
      'Take a picture of a recipe or choose from gallery to import text automatically';

  @override
  String get importPhotoImport => 'Photo import';

  @override
  String get importProceedToEdit => 'Proceed to edit';

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
  String get profileAddAvatar => 'Add avatar';

  @override
  String get profileAvatarRemoved => 'Avatar removed';

  @override
  String get profileAvatarUploaded => 'Avatar uploaded!';

  @override
  String get profileChangeAvatar => 'Change avatar';

  @override
  String get profileCouldNotSave => 'Could not save profile';

  @override
  String get profileCouldNotUploadAvatar => 'Could not upload avatar';

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
    return '$count members';
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
    return '$count comments';
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
  String get stateAddRecipes => 'Add recipes';

  @override
  String get stateCreateWeeklyMenu => 'Create weekly menu';

  @override
  String get stateGenerateMenu => 'Generate menu';

  @override
  String get commonStart => 'Start';

  @override
  String get discoveryAllRecommendationsComingSoon =>
      'Show all recommendations coming soon!';

  @override
  String get discoveryBuildingRecommendations => 'Building recommendations';

  @override
  String get discoveryCouldNotHideRecommendation =>
      'Could not hide recommendation right now.';

  @override
  String get discoveryCouldNotRestoreRecommendation =>
      'Could not restore recommendation.';

  @override
  String get discoveryCouldNotSendFeedback =>
      'Could not send feedback right now.';

  @override
  String get discoveryFeedbackThanksImproving =>
      'Thanks for your feedback! We are improving recommendations.';

  @override
  String get discoveryFriendActivity => 'Friend activity';

  @override
  String get discoveryFriendActivityDescription =>
      'When your friends share recipes, menus or shopping lists they will appear here.';

  @override
  String get discoveryFriendActivityWillAppearHere =>
      'Activity from your friends will appear here';

  @override
  String get discoveryFriendsChoice => 'Friends\' choice';

  @override
  String get discoveryLearningPreferences =>
      'We are learning your preferences to give better recommendations.';

  @override
  String get discoveryLike => 'Like';

  @override
  String get discoveryListening => 'Listening...';

  @override
  String get discoveryLists => 'Lists';

  @override
  String get discoveryLoadingPopularContent => 'Loading popular content...';

  @override
  String get discoveryNoFriendActivityYet => 'No friend activity yet';

  @override
  String get discoveryNoPopularRecipesYet => 'No popular recipes yet';

  @override
  String get discoveryPerformedAction => 'Performed an action';

  @override
  String get discoveryPopular => 'Popular';

  @override
  String get discoveryPopularContent => 'Popular content';

  @override
  String get discoveryPopularMenus => 'Popular menus';

  @override
  String get discoveryPopularRecipes => 'Popular recipes';

  @override
  String get discoveryPopularShoppingLists => 'Popular shopping lists';

  @override
  String get discoveryPopularWithFriends => 'Popular with friends';

  @override
  String get discoveryPopularWithFriendsDescription =>
      'Content that your friends like and share';

  @override
  String discoveryPortions(int count) {
    return '$count portions';
  }

  @override
  String get discoveryRecently => 'Recently';

  @override
  String get discoveryRecentlyShared => 'Recently shared';

  @override
  String get discoveryRecentlySharedDescription =>
      'Latest shared content in your network';

  @override
  String get discoveryRecommendationHidden =>
      'Recommendation hidden. We won\'t show similar content.';

  @override
  String get discoveryRecommendationRestored => 'Recommendation restored.';

  @override
  String get discoveryRecommended => 'Recommended';

  @override
  String get discoveryRecommendedForYou => 'Recommended for you';

  @override
  String get discoverySearchFilters => 'Search filters';

  @override
  String get discoverySearchHint => 'Search recipes, menus, shopping lists...';

  @override
  String discoverySearchResultsFor(int count, String query) {
    return '$count results for \"$query\"';
  }

  @override
  String get discoverySeasonal => 'Seasonal';

  @override
  String discoverySharedBy(String name) {
    return 'Shared by $name';
  }

  @override
  String get discoverySharing => 'sharing';

  @override
  String get discoverySimilarToShared => 'Similar to shared';

  @override
  String discoveryTimeAgoDays(int count) {
    return '${count}d ago';
  }

  @override
  String discoveryTimeAgoHours(int count) {
    return '${count}h ago';
  }

  @override
  String discoveryTimeAgoMinutes(int count) {
    return '${count}m ago';
  }

  @override
  String get discoveryTimeAgoNow => 'Now';

  @override
  String get discoveryUnknownContent => 'Unknown content';

  @override
  String get discoveryUnknownUser => 'Unknown user';

  @override
  String discoveryUserSharedType(String user, String type) {
    return '$user shared $type';
  }

  @override
  String get discoveryVoiceSearch => 'Voice search';

  @override
  String get discoveryVoiceSearchInstruction =>
      'Press the microphone and start speaking';

  @override
  String get discoveryVoiceSearchPreview =>
      'Search started! (Voice search is a preview)';

  @override
  String get discoveryVoiceSearchPrompt => 'Say what you want to search for...';

  @override
  String get discoveryVoiceSearchResult => 'Voice search: \"pasta recipe\"';

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
  String get authTagline => 'Smart recipe management for your everyday';

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
  String get discoveryClearSearch => 'Clear search';

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
    return '$count servings';
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
  String get shoppingCategoryOther => 'Other';

  @override
  String get shoppingClear => 'Clear';

  @override
  String get shoppingClearPurchasedTitle => 'Clear purchased items';

  @override
  String get shoppingCouldNotAddMembers => 'Could not add members';

  @override
  String get shoppingCouldNotDeleteList => 'Could not delete list';

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
  String shoppingItemAdded(String name) {
    return '$name added';
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
    return '$count members added';
  }

  @override
  String shoppingMembersCount(int count) {
    return '$count members';
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
  String get authEmailHint => 'your.email@example.com';

  @override
  String get authNoAccountSignUp => 'Don\'t have an account? Create account';

  @override
  String get authHasAccountLogin => 'Already have an account? Log in';

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
  String sharedMenusCount(int count) {
    return 'Menus ($count)';
  }

  @override
  String sharedRecipesCount(int count) {
    return 'Recipes ($count)';
  }

  @override
  String sharedShoppingListsCount(int count) {
    return 'Shopping lists ($count)';
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
  String get a11yShareWithFriends => 'Share with friends';

  @override
  String get a11yNoItemsToShare => 'No items to share';

  @override
  String get a11yShareExternally => 'Share externally';

  @override
  String get a11yAddItem => 'Add item';

  @override
  String a11yShoppingItemChecked(String itemText) {
    return '$itemText, checked, tap to uncheck';
  }

  @override
  String a11yShoppingItemUnchecked(String itemText) {
    return '$itemText, tap to check off';
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
  String get a11yDismissSharedRecipe => 'Dismiss shared recipe';

  @override
  String get a11yDismissSharedMenu => 'Dismiss shared menu';

  @override
  String get a11yDeclineSharedShoppingList => 'Decline shared shopping list';

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
    return '$count comments';
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
  String get menuNoRatingsYet => 'No ratings yet';

  @override
  String get menuTapToRate => 'Tap to rate';

  @override
  String get menuYourRating => 'Your rating';

  @override
  String get menuRatingSaved => 'Rating saved!';

  @override
  String get menuRatingFailed => 'Could not save rating';

  @override
  String get menuRemoveRating => 'Remove rating';

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
  String get shoppingConvertSelectFriends => 'Select at least one friend';

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
  String get menuTemplateSaveFailed => 'Could not save template';

  @override
  String get menuTemplateLoadTemplate => 'Load template';

  @override
  String get menuTemplateNoTemplates => 'No templates';

  @override
  String get menuTemplateNoTemplatesDescription =>
      'You have no saved menu templates. Save a menu as a template to reuse the category structure.';

  @override
  String get menuTemplateBrowseTitle => 'Menu templates';

  @override
  String menuTemplateCategories(int count) {
    return '$count categories';
  }

  @override
  String menuTemplateRecipes(int count) {
    return '$count recipes';
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
}
