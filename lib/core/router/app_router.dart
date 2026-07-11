import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/core/extensions/default_value_extensions.dart';
import 'package:butlery/core/extensions/localization_extension.dart';
import 'package:butlery/widgets/common/adaptive_app_bar.dart';
import 'package:butlery/core/utils/animation_utils.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

// Deferred loading infrastructure
import 'package:butlery/core/router/deferred_module_loader.dart';
import 'package:butlery/core/router/async_route_builder.dart';
import 'package:butlery/core/router/modules/extraction_deferred_module.dart';
import 'package:butlery/core/router/modules/social_deferred_module.dart';
import 'package:butlery/core/router/modules/messaging_deferred_module.dart';

// Auth view (eager - always needed)
import 'package:butlery/views/auth_view.dart';

// Onboarding (eager - needed before home screen for new users)
import 'package:butlery/views/onboarding/onboarding_view.dart';

// Core recipe views (eager - needed on home screen)
import 'package:butlery/views/skriv_sjalv_recept_view.dart';
import 'package:butlery/views/fran_sociala_medier_view.dart';
import 'package:butlery/views/recipe_detail_view.dart';
import 'package:butlery/views/edit_recipe_view.dart';
import 'package:butlery/views/veckomeny_view.dart' as vecko;
import 'package:butlery/views/receive_share_view.dart';

// Shell layout (IndexedStack for tab state preservation)
import 'package:butlery/widgets/common/layout/layout_scaffolds.dart';

// Settings views
import 'package:butlery/views/settings/settings_hub_view.dart';
import 'package:butlery/views/admin/moderator_review_view.dart';
import 'package:butlery/views/settings/allergen_preferences_view.dart';
import 'package:butlery/views/settings/household_size_view.dart';
import 'package:butlery/views/family/min_familj_view.dart';
import 'package:butlery/views/settings/notification_preferences_view.dart';
import 'package:butlery/views/settings/account_security_view.dart';
import 'package:butlery/views/settings/collection_stats_view.dart';
import 'package:butlery/views/lagg_till_recept_view.dart';
import 'package:butlery/views/quick_capture_view.dart';
import 'package:butlery/views/personal_tags_view.dart';

// Cooking mode
import 'package:butlery/views/cooking_mode_view.dart';
import 'package:butlery/views/ingredient_search/ingredient_search_view.dart';

// Notifications
import 'package:butlery/views/notifications/notifications_view.dart';

// Legal
import 'package:butlery/views/legal/terms_of_service_view.dart';
import 'package:butlery/views/legal/privacy_policy_view.dart';
import 'package:butlery/views/legal/community_guidelines_view.dart';

// Settings — moderation
import 'package:butlery/views/settings/my_reports_view.dart';

// Help
import 'package:butlery/views/faq_view.dart';

// Models (needed for route arguments)
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/social_request.dart';

/// Centralized application router managing navigation and route generation for Butlery.
/// This class implements a comprehensive routing system that handles all navigation
/// throughout the application, including authentication checks, route animations,
/// error handling, and argument passing. It provides a single point of control
/// for all navigation logic and ensures consistent behavior across the app.
/// **Key Features:**
/// - Centralized route management with named routes
/// - Authentication-protected routes with automatic redirect
/// - Custom route animations based on navigation context
/// - Type-safe argument passing with validation
/// - Comprehensive error handling with user-friendly fallbacks
/// - Programmatic navigation utilities
/// - Route resolution and preprocessing
/// **Architecture Integration:**
/// - Works with Routes constants for route definitions
/// - Integrates with FirebaseAuthRepository for authentication
/// - Supports all major app sections (recipes, social, messaging, shopping)
/// - Provides consistent UI transitions and animations
/// **Route Categories:**
/// - **Base Routes**: Authentication, home screen
/// - **Recipe Routes**: Creation, editing, import, detail views
/// - **Menu & Shopping Routes**: Weekly planning, shopping lists
/// - **Social Routes**: Friends, profiles, sharing, collaboration
/// - **Messaging Routes**: Conversations, chat interfaces
/// **Usage Examples:**
/// ```dart
/// // Navigate to a route
/// AppRouter.navigateTo(context, Routes.addRecipe);
/// // Navigate with arguments
/// AppRouter.navigateTo(
///   context,
///   Routes.recipeDetail,
///   arguments: recipe
/// );
/// // Navigate and replace current route
/// AppRouter.navigateAndReplace(context, Routes.auth);
/// // Navigate and clear stack
/// AppRouter.navigateAndClearStack(context, Routes.home);
/// ```
/// **Error Handling:**
/// - Missing arguments result in user-friendly error screens
/// - Unknown routes show appropriate error messages
/// - Authentication failures redirect to login
/// - All errors provide navigation back to home screen
class AppRouter {
  static final FirebaseAuthRepository _authRepository =
      FirebaseAuthRepository();

  static bool _modulesInitialized = false;

  /// Initialize deferred modules for lazy loading
  /// Call this once at app startup (e.g., in main.dart)
  static void initializeDeferredModules() {
    if (_modulesInitialized) return;

    DeferredModuleLoader.register('extraction', ExtractionDeferredModule());
    DeferredModuleLoader.register('social', SocialDeferredModule());
    DeferredModuleLoader.register('messaging', MessagingDeferredModule());

    _modulesInitialized = true;
  }

  /// Main route generator that handles all app navigation
  static Route<dynamic> generateRoute(RouteSettings settings) {
    try {
      final routeName = Routes.resolveRoute(settings.name ?? '/');

      // Ensure deferred modules are initialized
      initializeDeferredModules();

      // Check authentication for protected routes
      if (Routes.requiresAuth(routeName)) {
        if (!_isUserAuthenticated()) {
          return _buildRoute(
            const AuthView(),
            settings,
            RouteAnimationType.fade,
          );
        }
      }

      // Check if route is handled by a deferred module
      final moduleName = DeferredModuleLoader.findModuleForRoute(routeName);
      if (moduleName != null) {
        return AsyncRouteBuilder.buildDeferredRoute(
          routeName: routeName,
          settings: settings,
          moduleName: moduleName,
          animationType: Routes.getAnimationType(routeName),
        );
      }

      // Eager routes (core app functionality)
      switch (routeName) {
        case Routes.home:
          return _buildRoute(
            LayoutScaffolds.mainMenu(initialIndex: 0),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.auth:
          return _buildRoute(
            const AuthView(),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.onboarding:
          return _buildRoute(
            const OnboardingView(),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.addRecipe:
          return _buildRoute(
            const LaggTillReceptView(),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.quickCapture:
          return _buildRoute(
            const QuickCaptureView(),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.manualEntry:
          // Handle arguments for template or initial recipe
          final arguments = settings.arguments;
          if (arguments is Map<String, dynamic>) {
            final initialRecipe = arguments['initialRecipe'];
            final isTemplate = arguments['isTemplate'] as bool? ?? false;
            // Onboarding opens the form mid-wizard and passes false so save pops
            // back into its flow instead of flinging the user to a recipe detail.
            final navigateToDetailOnSave =
                arguments['navigateToDetailOnSave'] as bool? ?? true;
            return _buildRoute(
              SkrivSjalvReceptView(
                initialRecipe: initialRecipe,
                isTemplate: isTemplate,
                navigateToDetailOnSave: navigateToDetailOnSave,
              ),
              settings,
              Routes.getAnimationType(routeName),
            );
          }
          return _buildRoute(
            const SkrivSjalvReceptView(),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.fromSocialMedia:
          // Handle different argument types
          final arguments = settings.arguments;
          String? initialText;
          String? sourceUrl;
          double? ocrConfidence;

          if (arguments is String) {
            // Legacy plain-text argument (pre-BUT-928 callers)
            initialText = arguments;
          } else if (arguments is Map<String, dynamic>) {
            // Map arguments from URL import / photo-OCR handoff
            initialText = arguments['text'] as String?;
            sourceUrl = arguments['sourceUrl'] as String?;
            // BUT-928: overall OCR confidence from the photo-import preview.
            ocrConfidence = arguments['ocrConfidence'] as double?;
          }

          return _buildRoute(
            FranSocialaMedierView(
              initialText: initialText,
              sourceUrl: sourceUrl,
              ocrConfidence: ocrConfidence,
            ),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.recipeDetail:
          final arguments = settings.arguments;
          Recipe? recipe;
          bool scrollToComments = false;
          bool readOnly = false;
          SocialRequest? shareRequest;
          if (arguments is Recipe) {
            recipe = arguments;
          } else if (arguments is Map<String, dynamic>) {
            recipe = arguments['recipe'] as Recipe?;
            scrollToComments = arguments['scrollToComments'] as bool? ?? false;
            readOnly = arguments['readOnly'] as bool? ?? false;
            shareRequest = arguments['shareRequest'] as SocialRequest?;
          }
          if (recipe == null) {
            return _errorRoute('Recipe argument missing for detail view');
          }
          return _buildRoute(
            RecipeDetailView(
              recipe: recipe,
              scrollToComments: scrollToComments,
              readOnly: readOnly,
              shareRequest: shareRequest,
            ),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.editRecipe:
          final recipe = settings.arguments as Recipe?;
          if (recipe == null) {
            return _errorRoute('Recipe argument missing for edit view');
          }
          return _buildRoute(
            EditRecipeView(recipe: recipe),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.receiveShare:
          final shareData = settings.arguments as Map<String, dynamic>?;
          if (shareData == null) {
            return _errorRoute('Share data missing');
          }
          return _buildRoute(
            ReceiveShareView(
              content: (shareData['content'] as String?).orEmpty(),
              type: shareData['type'] as String? ?? 'text',
            ),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.weeklyMenu:
          final menu = settings.arguments as SharedMenu?;
          if (menu != null) {
            return _buildRoute(
              vecko.VeckomenyView(sharedMenu: menu),
              settings,
              Routes.getAnimationType(routeName),
            );
          }
          return _buildRoute(
            LayoutScaffolds.mainMenu(initialIndex: 1),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.realtimeMenu:
          // Navigate to VeckomenyView for collaborative menu
          // The realtime menu ID is passed in arguments for future enhancement
          // Deferred: VeckomenyView does not yet sync with realtime menus.
          // Current implementation uses separate realtime menu views.
          return _buildRoute(
            const vecko.VeckomenyView(),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.shoppingList:
          return _buildRoute(
            LayoutScaffolds.mainMenu(initialIndex: 2),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.cookingMode:
          final recipe = settings.arguments as Recipe?;
          if (recipe == null) {
            return _errorRoute('Recipe argument missing for cooking mode');
          }
          return _buildRoute(
            CookingModeView(recipe: recipe),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.ingredientSearch:
          return _buildRoute(
            const IngredientSearchView(),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.notifications:
          return _buildRoute(
            const NotificationsView(),
            settings,
            Routes.getAnimationType(routeName),
          );

        case Routes.settings:
          return _buildRoute(
            const SettingsHubView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.settingsFamily:
          return _buildRoute(
            const MinFamiljView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.settingsHousehold:
          return _buildRoute(
            const HouseholdSizeView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.settingsAllergens:
          return _buildRoute(
            const AllergenPreferencesView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.settingsPersonalTags:
          return _buildRoute(
            const PersonalTagsView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.settingsNotifications:
          return _buildRoute(
            const NotificationPreferencesView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.settingsAccountSecurity:
          return _buildRoute(
            const AccountSecurityView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.collectionStats:
          return _buildRoute(
            const CollectionStatsView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.moderatorReview:
          return _buildRoute(
            const ModeratorReviewView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.termsOfService:
          return _buildRoute(
            const TermsOfServiceView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.privacyPolicy:
          return _buildRoute(
            const PrivacyPolicyView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.communityGuidelines:
          return _buildRoute(
            const CommunityGuidelinesView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.myReports:
          return _buildRoute(
            const MyReportsView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        case Routes.faq:
          return _buildRoute(
            const FaqView(),
            settings,
            RouteAnimationType.slideFromRight,
          );

        default:
          // Deep link paths are handled by DeepLinkHandler before router —
          // gracefully fall back to home if they reach here
          const deepLinkPaths = [
            '/recipe',
            '/invite',
            '/menu',
            '/shopping',
            '/profile',
          ];
          if (deepLinkPaths.any((p) => routeName.startsWith(p))) {
            // Gate the fallback on auth: rendering the authenticated main menu
            // for a signed-out user (e.g. cold-start deep link before sign-in)
            // would leak the protected home shell. Route them to login instead.
            if (!_isUserAuthenticated()) {
              return _buildRoute(
                const AuthView(),
                settings,
                RouteAnimationType.fade,
              );
            }
            return _buildRoute(
              LayoutScaffolds.mainMenu(),
              settings,
              RouteAnimationType.fade,
            );
          }
          return _errorRoute('Unknown route: ${settings.name}');
      }
    } catch (e) {
      return _errorRoute('Error navigating to ${settings.name}: $e');
    }
  }

  /// Handle unknown routes
  static Route<dynamic> handleUnknownRoute(RouteSettings settings) {
    return _errorRoute('Unknown route: ${settings.name}');
  }

  /// Build route with appropriate animation based on route type
  static Route<dynamic> _buildRoute(
    Widget page,
    RouteSettings settings,
    RouteAnimationType animationType,
  ) {
    switch (animationType) {
      case RouteAnimationType.fade:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            // Skip animation when reduced motion is enabled (WCAG 2.3.3)
            if (!AnimationUtils.shouldAnimate(context)) return child;
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        );

      case RouteAnimationType.slideFromBottom:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (!AnimationUtils.shouldAnimate(context)) return child;
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            final tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            final offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 400),
        );

      case RouteAnimationType.slideFromRight:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (!AnimationUtils.shouldAnimate(context)) return child;
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            final tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            final offsetAnimation = animation.drive(tween);
            return SlideTransition(position: offsetAnimation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        );

      case RouteAnimationType.scale:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            if (!AnimationUtils.shouldAnimate(context)) return child;
            const begin = 0.0;
            const end = 1.0;
            const curve = Curves.elasticOut;
            final tween = Tween(
              begin: begin,
              end: end,
            ).chain(CurveTween(curve: curve));
            final scaleAnimation = animation.drive(tween);
            return ScaleTransition(scale: scaleAnimation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 600),
        );
    }
  }

  /// Create error route with scale animation
  static Route<dynamic> _errorRoute([String? message]) {
    return PageRouteBuilder(
      pageBuilder: (context, animation, secondaryAnimation) => Scaffold(
        appBar: AdaptiveAppBar(title: context.l10n.errorTitle),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: AppDimensions.iconSizeXl,
                color: Theme.of(context).colorScheme.error,
              ),
              const SizedBox(height: AppDimensions.spacingXl),
              Text(
                message ?? 'Sidan kunde inte hittas',
                style: AppTextStyles.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton(
                onPressed: () =>
                    Navigator.of(context).pushReplacementNamed(Routes.home),
                child: const Text('Tillbaka till start'),
              ),
            ],
          ),
        ),
      ),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = 0.0;
        const end = 1.0;
        const curve = Curves.elasticOut;
        final tween = Tween(
          begin: begin,
          end: end,
        ).chain(CurveTween(curve: curve));
        final scaleAnimation = animation.drive(tween);
        return ScaleTransition(scale: scaleAnimation, child: child);
      },
      transitionDuration: const Duration(milliseconds: 600),
    );
  }

  /// Check if user is authenticated
  static bool _isUserAuthenticated() {
    return _authRepository.getCurrentUser() != null;
  }

  /// Navigate to a route programmatically
  static Future<dynamic> navigateTo(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamed(routeName, arguments: arguments);
  }

  /// Navigate and replace current route
  static Future<dynamic> navigateAndReplace(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(
      context,
    ).pushReplacementNamed(routeName, arguments: arguments);
  }

  /// Navigate and clear stack
  static Future<dynamic> navigateAndClearStack(
    BuildContext context,
    String routeName, {
    Object? arguments,
  }) {
    return Navigator.of(context).pushNamedAndRemoveUntil(
      routeName,
      (route) => false,
      arguments: arguments,
    );
  }

  /// Go back
  static void goBack(BuildContext context, [dynamic result]) {
    Navigator.of(context).pop(result);
  }

  /// Check if can go back
  static bool canGoBack(BuildContext context) {
    return Navigator.of(context).canPop();
  }
}
