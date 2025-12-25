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
  String get imageFromGallery => 'From gallery';

  @override
  String get imageSelectFromGallery => 'Select an image from gallery';

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
  String get chatConversationInfo => 'Conversation information';

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
      'Are you sure you want to leave the conversation?';

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
}
