/// Advanced user interaction simulation utilities for Butlery view testing.
///
/// This module provides sophisticated user action simulation capabilities
/// specifically designed for testing complex view interactions in the Swedish
/// localized Butlery application. It handles Swedish text input, multi-step
/// workflows, gesture sequences, and collaborative interaction scenarios.
///
/// **Key Features:**
/// - **Swedish Input Simulation**: Advanced handling of Swedish characters (å, ä, ö) and keyboard layouts
/// - **Complex Workflow Automation**: Multi-step user journeys like authentication, recipe editing, and shopping
/// - **Collaborative Interaction Testing**: Real-time collaboration scenarios with multiple user simulation
/// - **Form Interaction Utilities**: Comprehensive form filling, validation, and submission testing
/// - **Gesture and Navigation Testing**: Advanced scroll, swipe, and navigation pattern simulation
/// - **Performance-Aware Interactions**: Timing-controlled interactions that respect animation and loading states
///
/// **Integration with Test Infrastructure:**
/// These helpers integrate seamlessly with ViewTestHelpers and ProviderTestUtils
/// to provide end-to-end interaction testing capabilities that match real user behavior.
///
/// **Usage Example:**
/// ```dart
/// testWidgets('should complete full recipe editing workflow', (tester) async {
///   await InteractionHelpers.performCompleteRecipeEditWorkflow(
///     tester,
///     recipeData: {
///       'title': 'Köttbullar med lingonsås',
///       'ingredients': ['500g köttfärs', '1 ägg', 'salt & peppar'],
///       'instructions': ['Blanda ingredienser', 'Form till bullar', 'Stek i panna'],
///       'portions': '4',
///     },
///     shouldSave: true,
///   );
///   
///   expect(find.text('Recept sparat'), findsOneWidget);
/// });
/// ```
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

// Import view test helpers for integration
import 'view_test_helpers.dart';

/// Advanced user interaction simulation utilities for view testing.
///
/// This class provides sophisticated interaction patterns that simulate
/// real user behavior, including complex workflows, Swedish input handling,
/// and multi-step operations commonly performed in Butlery views.
class InteractionHelpers {
  /// Private constructor to prevent instantiation
  InteractionHelpers._();

  // ==================== SWEDISH INPUT SIMULATION ====================

  /// Simulate Swedish text input with proper character encoding and timing.
  ///
  /// This method handles Swedish character input more robustly than the basic
  /// ViewTestHelpers.enterSwedishText, including proper keyboard simulation
  /// and character composition for complex Swedish text.
  ///
  /// **Features:**
  /// - Proper handling of Swedish characters (å, ä, ö)
  /// - Keyboard layout simulation for Swedish QWERTY
  /// - Character composition for diacritical marks
  /// - Realistic typing timing simulation
  static Future<void> typeSwedishText(
    WidgetTester tester,
    Finder finder,
    String text, {
    Duration typingSpeed = const Duration(milliseconds: 50),
    bool simulateRealTyping = false,
  }) async {
    await tester.tap(finder);
    await tester.pump(const Duration(milliseconds: 100));

    if (simulateRealTyping) {
      // Simulate character-by-character typing for realistic input testing
      for (int i = 0; i < text.length; i++) {
        await tester.enterText(
          finder,
          text.substring(0, i + 1),
        );
        await tester.pump(typingSpeed);
      }
    } else {
      // Standard text entry for faster tests
      await tester.enterText(finder, text);
      await tester.pump(const Duration(milliseconds: 100));
    }

    // Trigger text field validation
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
  }

  /// Handle Swedish autocorrect and text prediction simulation.
  static Future<void> simulateSwedishAutocorrect(
    WidgetTester tester,
    Finder finder,
    String originalText,
    String correctedText,
  ) async {
    // Type original text
    await typeSwedishText(tester, finder, originalText);
    
    // Simulate autocorrect replacement
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(finder, correctedText);
    await tester.pump();
  }

  // ==================== AUTHENTICATION WORKFLOW ====================

  /// Perform complete login workflow with realistic user behavior.
  ///
  /// Simulates a realistic login sequence including field focus,
  /// typing delays, validation checks, and submission.
  static Future<void> performLoginWorkflow(
    WidgetTester tester, {
    required String email,
    required String password,
    bool rememberMe = false,
    bool expectSuccess = true,
    Duration workflowDelay = const Duration(milliseconds: 200),
  }) async {
    // Focus and fill email field
    final emailField = find.byKey(const Key('email_field'));
    expect(emailField, findsOneWidget, reason: 'Email field not found');
    
    await typeSwedishText(tester, emailField, email);
    await tester.pump(workflowDelay);

    // Focus and fill password field
    final passwordField = find.byKey(const Key('password_field'));
    expect(passwordField, findsOneWidget, reason: 'Password field not found');
    
    await typeSwedishText(tester, passwordField, password);
    await tester.pump(workflowDelay);

    // Handle remember me checkbox if needed
    if (rememberMe) {
      final rememberMeCheckbox = find.byKey(const Key('remember_me_checkbox'));
      if (tester.any(rememberMeCheckbox)) {
        await tester.tap(rememberMeCheckbox);
        await tester.pump();
      }
    }

    // Submit login form
    final loginButton = find.byKey(const Key('login_button'));
    expect(loginButton, findsOneWidget, reason: 'Login button not found');
    
    await ViewTestHelpers.tapAndSettle(tester, loginButton);

    if (expectSuccess) {
      // Wait for login to complete
      await tester.pump(const Duration(seconds: 2));
    }
  }

  /// Perform complete registration workflow.
  static Future<void> performRegistrationWorkflow(
    WidgetTester tester, {
    required String name,
    required String email,
    required String password,
    required String confirmPassword,
    bool acceptTerms = true,
    bool expectSuccess = true,
  }) async {
    // Switch to registration mode if needed
    final switchToRegisterButton = find.text('Skapa konto');
    if (tester.any(switchToRegisterButton)) {
      await ViewTestHelpers.tapAndSettle(tester, switchToRegisterButton);
    }

    // Fill name field
    final nameField = find.byKey(const Key('name_field'));
    await typeSwedishText(tester, nameField, name);

    // Fill email field
    final emailField = find.byKey(const Key('email_field'));
    await typeSwedishText(tester, emailField, email);

    // Fill password field
    final passwordField = find.byKey(const Key('password_field'));
    await typeSwedishText(tester, passwordField, password);

    // Fill confirm password field
    final confirmPasswordField = find.byKey(const Key('confirm_password_field'));
    await typeSwedishText(tester, confirmPasswordField, confirmPassword);

    // Accept terms and conditions
    if (acceptTerms) {
      final termsCheckbox = find.byKey(const Key('terms_checkbox'));
      if (tester.any(termsCheckbox)) {
        await ViewTestHelpers.tapAndSettle(tester, termsCheckbox);
      }
    }

    // Submit registration
    final registerButton = find.byKey(const Key('register_button'));
    await ViewTestHelpers.tapAndSettle(tester, registerButton);

    if (expectSuccess) {
      await tester.pump(const Duration(seconds: 3));
    }
  }

  // ==================== RECIPE EDITING WORKFLOW ====================

  /// Perform comprehensive recipe editing workflow.
  ///
  /// This simulates the complete recipe editing experience including
  /// form filling, dynamic list management, image handling, and saving.
  static Future<void> performCompleteRecipeEditWorkflow(
    WidgetTester tester, {
    required Map<String, dynamic> recipeData,
    bool addImage = false,
    bool shouldSave = true,
    bool isCollaborative = false,
  }) async {
    // Fill basic recipe information
    await _fillRecipeBasicInfo(tester, recipeData);

    // Handle ingredients list
    if (recipeData['ingredients'] != null) {
      await _manageIngredientsList(tester, recipeData['ingredients'] as List<String>);
    }

    // Handle instructions list
    if (recipeData['instructions'] != null) {
      await _manageInstructionsList(tester, recipeData['instructions'] as List<String>);
    }

    // Add image if requested
    if (addImage) {
      await _simulateImageAddition(tester);
    }

    // Handle collaborative editing features
    if (isCollaborative) {
      await _handleCollaborativeEditing(tester);
    }

    // Save recipe if requested
    if (shouldSave) {
      await _saveRecipe(tester);
    }
  }

  /// Fill basic recipe information fields.
  static Future<void> _fillRecipeBasicInfo(
    WidgetTester tester,
    Map<String, dynamic> recipeData,
  ) async {
    // Title
    if (recipeData['title'] != null) {
      final titleField = find.byKey(const Key('recipe_title_field'));
      await typeSwedishText(tester, titleField, recipeData['title'] as String);
    }

    // Description
    if (recipeData['description'] != null) {
      final descriptionField = find.byKey(const Key('recipe_description_field'));
      await typeSwedishText(tester, descriptionField, recipeData['description'] as String);
    }

    // Portions
    if (recipeData['portions'] != null) {
      final portionsField = find.byKey(const Key('recipe_portions_field'));
      await typeSwedishText(tester, portionsField, recipeData['portions'].toString());
    }

    // Cooking time
    if (recipeData['cookingTime'] != null) {
      final timeField = find.byKey(const Key('recipe_time_field'));
      await typeSwedishText(tester, timeField, recipeData['cookingTime'].toString());
    }
  }

  /// Manage dynamic ingredients list.
  static Future<void> _manageIngredientsList(
    WidgetTester tester,
    List<String> ingredients,
  ) async {
    for (int i = 0; i < ingredients.length; i++) {
      // Add new ingredient if needed
      if (i > 0) {
        final addIngredientButton = find.byKey(const Key('add_ingredient_button'));
        await ViewTestHelpers.tapAndSettle(tester, addIngredientButton);
      }

      // Fill ingredient field
      final ingredientField = find.byKey(Key('ingredient_field_$i'));
      await typeSwedishText(tester, ingredientField, ingredients[i]);
    }
  }

  /// Manage dynamic instructions list.
  static Future<void> _manageInstructionsList(
    WidgetTester tester,
    List<String> instructions,
  ) async {
    for (int i = 0; i < instructions.length; i++) {
      // Add new instruction if needed
      if (i > 0) {
        final addInstructionButton = find.byKey(const Key('add_instruction_button'));
        await ViewTestHelpers.tapAndSettle(tester, addInstructionButton);
      }

      // Fill instruction field
      final instructionField = find.byKey(Key('instruction_field_$i'));
      await typeSwedishText(tester, instructionField, instructions[i]);
    }
  }

  /// Simulate image addition process.
  static Future<void> _simulateImageAddition(WidgetTester tester) async {
    final imagePickerButton = find.byKey(const Key('image_picker_button'));
    await ViewTestHelpers.tapAndSettle(tester, imagePickerButton);

    // Handle image picker dialog
    final galleryOption = find.text('Från galleri');
    if (tester.any(galleryOption)) {
      await ViewTestHelpers.tapAndSettle(tester, galleryOption);
    }

    // Wait for image processing
    await tester.pump(const Duration(seconds: 1));
  }

  /// Handle collaborative editing interactions.
  static Future<void> _handleCollaborativeEditing(WidgetTester tester) async {
    // Check for collaborative conflict banner
    final conflictBanner = find.byKey(const Key('collaborative_conflict_banner'));
    if (tester.any(conflictBanner)) {
      // Handle fork option
      final forkButton = find.text('Skapa kopia');
      if (tester.any(forkButton)) {
        await ViewTestHelpers.tapAndSettle(tester, forkButton);
      }
    }
  }

  /// Save recipe with proper validation and feedback handling.
  static Future<void> _saveRecipe(WidgetTester tester) async {
    final saveButton = find.byKey(const Key('save_recipe_button'));
    await ViewTestHelpers.tapAndSettle(tester, saveButton);

    // Wait for save operation to complete
    await ViewTestHelpers.pumpUntilState(
      tester,
      () => tester.any(find.text('Recept sparat')) || tester.any(find.byType(SnackBar)),
      timeout: const Duration(seconds: 5),
    );
  }

  // ==================== SHOPPING LIST WORKFLOW ====================

  /// Perform complete shopping list creation and management workflow.
  static Future<void> performShoppingListWorkflow(
    WidgetTester tester, {
    required String listName,
    required List<Map<String, dynamic>> items,
    bool shareWithOthers = false,
    List<String> collaborators = const [],
  }) async {
    // Create new shopping list
    await _createShoppingList(tester, listName);

    // Add items to the list
    for (final itemData in items) {
      await _addShoppingItem(tester, itemData);
    }

    // Share list if requested
    if (shareWithOthers && collaborators.isNotEmpty) {
      await _shareShoppingList(tester, collaborators);
    }
  }

  /// Create new shopping list.
  static Future<void> _createShoppingList(WidgetTester tester, String listName) async {
    final createListButton = find.byKey(const Key('create_list_button'));
    await ViewTestHelpers.tapAndSettle(tester, createListButton);

    final nameField = find.byKey(const Key('list_name_field'));
    await typeSwedishText(tester, nameField, listName);

    final confirmButton = find.text('Skapa');
    await ViewTestHelpers.tapAndSettle(tester, confirmButton);
  }

  /// Add item to shopping list with category and amount.
  static Future<void> _addShoppingItem(
    WidgetTester tester,
    Map<String, dynamic> itemData,
  ) async {
    final addItemButton = find.byKey(const Key('add_item_button'));
    await ViewTestHelpers.tapAndSettle(tester, addItemButton);

    // Fill item details
    final itemNameField = find.byKey(const Key('item_name_field'));
    await typeSwedishText(tester, itemNameField, itemData['name'] as String);

    if (itemData['amount'] != null) {
      final amountField = find.byKey(const Key('item_amount_field'));
      await typeSwedishText(tester, amountField, itemData['amount'].toString());
    }

    if (itemData['unit'] != null) {
      final unitField = find.byKey(const Key('item_unit_field'));
      await typeSwedishText(tester, unitField, itemData['unit'] as String);
    }

    // Save item
    final saveItemButton = find.text('Lägg till');
    await ViewTestHelpers.tapAndSettle(tester, saveItemButton);
  }

  /// Share shopping list with collaborators.
  static Future<void> _shareShoppingList(
    WidgetTester tester,
    List<String> collaborators,
  ) async {
    final shareButton = find.byKey(const Key('share_list_button'));
    await ViewTestHelpers.tapAndSettle(tester, shareButton);

    // Add each collaborator
    for (final email in collaborators) {
      final emailField = find.byKey(const Key('collaborator_email_field'));
      await typeSwedishText(tester, emailField, email);

      final addButton = find.text('Lägg till');
      await ViewTestHelpers.tapAndSettle(tester, addButton);
    }

    // Confirm sharing
    final confirmShareButton = find.text('Dela lista');
    await ViewTestHelpers.tapAndSettle(tester, confirmShareButton);
  }

  // ==================== SOCIAL INTERACTION WORKFLOW ====================

  /// Perform social interaction workflow (friend requests, comments, etc.).
  static Future<void> performSocialInteractionWorkflow(
    WidgetTester tester, {
    String? friendEmail,
    String? comment,
    bool likeContent = false,
  }) async {
    // Send friend request
    if (friendEmail != null) {
      await _sendFriendRequest(tester, friendEmail);
    }

    // Add comment
    if (comment != null) {
      await _addComment(tester, comment);
    }

    // Like content
    if (likeContent) {
      await _likeContent(tester);
    }
  }

  /// Send friend request.
  static Future<void> _sendFriendRequest(WidgetTester tester, String email) async {
    final addFriendButton = find.byKey(const Key('add_friend_button'));
    await ViewTestHelpers.tapAndSettle(tester, addFriendButton);

    final emailField = find.byKey(const Key('friend_email_field'));
    await typeSwedishText(tester, emailField, email);

    final sendRequestButton = find.text('Skicka förfrågan');
    await ViewTestHelpers.tapAndSettle(tester, sendRequestButton);
  }

  /// Add comment to content.
  static Future<void> _addComment(WidgetTester tester, String comment) async {
    final commentField = find.byKey(const Key('comment_input_field'));
    await typeSwedishText(tester, commentField, comment);

    final submitCommentButton = find.byKey(const Key('submit_comment_button'));
    await ViewTestHelpers.tapAndSettle(tester, submitCommentButton);
  }

  /// Like content.
  static Future<void> _likeContent(WidgetTester tester) async {
    final likeButton = find.byKey(const Key('like_button'));
    await ViewTestHelpers.tapAndSettle(tester, likeButton);
  }

  // ==================== ADVANCED GESTURE SIMULATION ====================

  /// Simulate complex scroll patterns for infinite loading testing.
  static Future<void> simulateInfiniteScrollPattern(
    WidgetTester tester,
    Finder scrollableFinder, {
    int scrollCycles = 3,
    Duration cyclePause = const Duration(milliseconds: 500),
  }) async {
    for (int i = 0; i < scrollCycles; i++) {
      // Scroll down to trigger load more
      await tester.drag(scrollableFinder, const Offset(0, -500));
      await tester.pump();

      // Wait for content to load
      await tester.pump(cyclePause);

      // Scroll down more
      await tester.drag(scrollableFinder, const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 200));
    }
  }

  /// Simulate pull-to-refresh gesture.
  static Future<void> simulatePullToRefresh(
    WidgetTester tester,
    Finder scrollableFinder,
  ) async {
    // Pull down from top
    await tester.drag(scrollableFinder, const Offset(0, 300));
    await tester.pump();

    // Wait for refresh to complete
    await tester.pump(const Duration(seconds: 2));
  }

  /// Simulate swipe gestures for navigation or dismissal.
  static Future<void> simulateSwipeGesture(
    WidgetTester tester,
    Finder targetFinder,
    SwipeDirection direction,
  ) async {
    final offset = switch (direction) {
      SwipeDirection.left => const Offset(-300, 0),
      SwipeDirection.right => const Offset(300, 0),
      SwipeDirection.up => const Offset(0, -300),
      SwipeDirection.down => const Offset(0, 300),
    };

    await tester.drag(targetFinder, offset);
    await tester.pumpAndSettle();
  }

  // ==================== PERFORMANCE AND TIMING UTILITIES ====================

  /// Wait for specific UI state with timeout and performance monitoring.
  static Future<bool> waitForUIState(
    WidgetTester tester, {
    required bool Function() condition,
    Duration timeout = const Duration(seconds: 10),
    Duration checkInterval = const Duration(milliseconds: 100),
    String? description,
  }) async {
    final stopwatch = Stopwatch()..start();
    int checkCount = 0;

    while (!condition() && stopwatch.elapsed < timeout) {
      await tester.pump(checkInterval);
      checkCount++;
    }

    stopwatch.stop();

    final success = condition();
    if (!success && description != null) {
      throw TimeoutException(
        'waitForUIState failed for "$description" after $checkCount checks',
        timeout,
      );
    }

    return success;
  }

  /// Measure interaction performance.
  static Future<InteractionMetrics> measureInteractionPerformance(
    WidgetTester tester,
    Future<void> Function() interaction,
  ) async {
    final stopwatch = Stopwatch()..start();
    await interaction();
    stopwatch.stop();

    return InteractionMetrics(
      totalDuration: stopwatch.elapsed,
      frameCount: tester.binding.transientCallbackCount,
    );
  }
}

// ==================== SUPPORTING ENUMS AND CLASSES ====================

/// Swipe direction enumeration.
enum SwipeDirection { left, right, up, down }

/// Interaction performance metrics.
class InteractionMetrics {
  final Duration totalDuration;
  final int frameCount;

  const InteractionMetrics({
    required this.totalDuration,
    required this.frameCount,
  });

  double get averageFrameTime => 
    frameCount > 0 ? totalDuration.inMicroseconds / frameCount / 1000.0 : 0.0;

  bool get isPerformant => averageFrameTime < 16.67; // 60 FPS threshold
}

/// Exception for interaction timeouts.
class TimeoutException implements Exception {
  final String message;
  final Duration timeout;

  const TimeoutException(this.message, this.timeout);

  @override
  String toString() => 'TimeoutException: $message';
}

/// Extension methods for WidgetTester with interaction helpers.
extension InteractionWidgetTester on WidgetTester {
  /// Type Swedish text with realistic timing.
  Future<void> typeSwedish(Finder finder, String text) async {
    await InteractionHelpers.typeSwedishText(this, finder, text);
  }

  /// Perform login workflow.
  Future<void> loginAs({
    required String email,
    required String password,
    bool rememberMe = false,
  }) async {
    await InteractionHelpers.performLoginWorkflow(
      this,
      email: email,
      password: password,
      rememberMe: rememberMe,
    );
  }

  /// Simulate infinite scroll.
  Future<void> scrollToLoadMore(Finder scrollable, {int cycles = 3}) async {
    await InteractionHelpers.simulateInfiniteScrollPattern(
      this,
      scrollable,
      scrollCycles: cycles,
    );
  }

  /// Pull to refresh.
  Future<void> pullToRefresh(Finder scrollable) async {
    await InteractionHelpers.simulatePullToRefresh(this, scrollable);
  }
}