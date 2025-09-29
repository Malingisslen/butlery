// lib/core/router/app_router.dart

import 'package:flutter/material.dart';
import 'package:butlery/core/constants/routes.dart';
import 'package:butlery/repositories/firebase/firebase_auth_repository.dart';
import 'package:butlery/theme/app_colors.dart';
import 'package:butlery/theme/app_dimensions.dart';
import 'package:butlery/theme/app_text_styles.dart';

// Auth view
import 'package:butlery/views/auth_view.dart';

// Recipe views
import 'package:butlery/views/mina_recept_view.dart';
import 'package:butlery/views/lagg_till_recept_view.dart';
import 'package:butlery/views/skriv_sjalv_recept_view.dart';
import 'package:butlery/views/fran_sociala_medier_view.dart';
import 'package:butlery/views/recipe_detail_view.dart';
import 'package:butlery/views/edit_recipe_view.dart';
import 'package:butlery/views/veckomeny_view.dart' as vecko;
import 'package:butlery/views/importera_fran_arkiv_view.dart';
import 'package:butlery/views/photo_import_view.dart';
import 'package:butlery/views/file_import_view.dart';
import 'package:butlery/views/import_via_url_view.dart';
import 'package:butlery/views/receive_share_view.dart';

// Unified shopping system
import 'package:butlery/views/unified_shopping_view.dart';

// Social views
import 'package:butlery/views/social/discovery_dashboard_view.dart';
import 'package:butlery/views/social/user_profile_edit_view.dart';
import 'package:butlery/views/social/friends_list_view.dart';
import 'package:butlery/views/social/friend_requests_view.dart';
import 'package:butlery/views/social/shared_with_me_view.dart';
import 'package:butlery/views/social/collaborative_shopping_view.dart';
import 'package:butlery/views/social/menu_preview_view.dart';
import 'package:butlery/views/social/create_shared_shopping_list_view.dart';
import 'package:butlery/views/social/friend_profile_view.dart';
import 'package:butlery/views/social/shared_shopping_lists_view.dart';

// Messaging views
import 'package:butlery/views/messaging/conversations_list_view.dart';
import 'package:butlery/views/messaging/chat_view/chat_view_facade.dart';

// Models
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/models/shared_menu.dart';
import 'package:butlery/models/user_profile.dart';

/// Centralized application router managing navigation and route generation for Butlery.
///
/// This class implements a comprehensive routing system that handles all navigation
/// throughout the application, including authentication checks, route animations,
/// error handling, and argument passing. It provides a single point of control
/// for all navigation logic and ensures consistent behavior across the app.
///
/// **Key Features:**
/// - Centralized route management with named routes
/// - Authentication-protected routes with automatic redirect
/// - Custom route animations based on navigation context
/// - Type-safe argument passing with validation
/// - Comprehensive error handling with user-friendly fallbacks
/// - Programmatic navigation utilities
/// - Route resolution and preprocessing
///
/// **Architecture Integration:**
/// - Works with Routes constants for route definitions
/// - Integrates with FirebaseAuthRepository for authentication
/// - Supports all major app sections (recipes, social, messaging, shopping)
/// - Provides consistent UI transitions and animations
///
/// **Route Categories:**
/// - **Base Routes**: Authentication, home screen
/// - **Recipe Routes**: Creation, editing, import, detail views
/// - **Menu & Shopping Routes**: Weekly planning, shopping lists
/// - **Social Routes**: Friends, profiles, sharing, collaboration
/// - **Messaging Routes**: Conversations, chat interfaces
///
/// **Usage Examples:**
/// ```dart
/// // Navigate to a route
/// AppRouter.navigateTo(context, Routes.laggTill);
/// 
/// // Navigate with arguments
/// AppRouter.navigateTo(
///   context, 
///   Routes.receptDetalj, 
///   arguments: recipe
/// );
/// 
/// // Navigate and replace current route
/// AppRouter.navigateAndReplace(context, Routes.auth);
/// 
/// // Navigate and clear stack
/// AppRouter.navigateAndClearStack(context, Routes.home);
/// ```
///
/// **Error Handling:**
/// - Missing arguments result in user-friendly error screens
/// - Unknown routes show appropriate error messages
/// - Authentication failures redirect to login
/// - All errors provide navigation back to home screen
class AppRouter {
  static final FirebaseAuthRepository _authRepository = FirebaseAuthRepository();

  /// Main route generator that handles all app navigation
  static Route<dynamic> generateRoute(RouteSettings settings) {
    try {
      final routeName = Routes.resolveRoute(settings.name ?? '/');
      
      // Check authentication for protected routes
      if (Routes.requiresAuth(routeName)) {
        if (!_isUserAuthenticated()) {
          return _buildRoute(const AuthView(), settings, RouteAnimationType.fade);
        }
      }

      switch (routeName) {
        // ===== BASE ROUTES =====
        case Routes.home:
          return _buildRoute(const MinaReceptView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.auth:
          return _buildRoute(const AuthView(), settings, Routes.getAnimationType(routeName));

        // ===== RECIPE ROUTES =====
        case Routes.laggTill:
          return _buildRoute(const LaggTillReceptView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.importViaUrl:
          return _buildRoute(const ImportViaUrlView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.photoImport:
          return _buildRoute(const PhotoImportView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.fileImport:
          return _buildRoute(const FileImportView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.skrivSjalv:
          // Handle arguments for template or initial recipe
          final arguments = settings.arguments;
          if (arguments is Map<String, dynamic>) {
            final initialRecipe = arguments['initialRecipe'];
            final isTemplate = arguments['isTemplate'] as bool? ?? false;
            return _buildRoute(
              SkrivSjalvReceptView(
                initialRecipe: initialRecipe,
                isTemplate: isTemplate,
              ), 
              settings, 
              Routes.getAnimationType(routeName)
            );
          }
          return _buildRoute(const SkrivSjalvReceptView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.franSocialaMedier:
          // Handle different argument types
          final arguments = settings.arguments;
          String? initialText;
          String? sourceUrl;
          
          if (arguments is String) {
            // Simple text argument from photo import
            initialText = arguments;
          } else if (arguments is Map<String, dynamic>) {
            // Complex arguments from URL import
            initialText = arguments['text'] as String?;
            sourceUrl = arguments['sourceUrl'] as String?;
          }
          
          return _buildRoute(
            FranSocialaMedierView(
              initialText: initialText,
              sourceUrl: sourceUrl,
            ), 
            settings, 
            Routes.getAnimationType(routeName)
          );
        
        case Routes.importFranArkiv:
          return _buildRoute(const ImporteraFranArkivView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.receptDetalj:
          final recipe = settings.arguments as Recipe?;
          if (recipe == null) {
            return _errorRoute('Recipe argument missing for detail view');
          }
          return _buildRoute(RecipeDetailView(recipe: recipe), settings, Routes.getAnimationType(routeName));
        
        case Routes.redigeraRecept:
          final recipe = settings.arguments as Recipe?;
          if (recipe == null) {
            return _errorRoute('Recipe argument missing for edit view');
          }
          return _buildRoute(EditRecipeView(recipe: recipe), settings, Routes.getAnimationType(routeName));
        
        case Routes.receiveShare:
          final shareData = settings.arguments as Map<String, dynamic>?;
          if (shareData == null) {
            return _errorRoute('Share data missing');
          }
          return _buildRoute(
            ReceiveShareView(
              content: shareData['content'] as String? ?? '',
              type: shareData['type'] as String? ?? 'text',
            ),
            settings,
            Routes.getAnimationType(routeName)
          );

        // ===== MENU & SHOPPING ROUTES =====
        case Routes.veckomeny:
          final menu = settings.arguments as SharedMenu?;
          return _buildRoute(
            menu != null ? vecko.VeckomenyView(sharedMenu: menu) : const vecko.VeckomenyView(),
            settings,
            Routes.getAnimationType(routeName)
          );
        
        case Routes.inkopslista:
          return _buildRoute(const UnifiedShoppingView(), settings, Routes.getAnimationType(routeName));

        // ===== SOCIAL ROUTES =====
        case Routes.profileEdit:
          return _buildRoute(const UserProfileEditView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.friends:
          return _buildRoute(const FriendsListView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.discovery:
          return _buildRoute(const DiscoveryDashboardView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.friendRequests:
          return _buildRoute(const FriendRequestsView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.shared:
          return _buildRoute(const SharedWithMeView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.collaborativeShopping:
          final listId = settings.arguments as String?;
          if (listId == null) {
            return _errorRoute('List ID argument missing for collaborative shopping');
          }
          return _buildRoute(CollaborativeShoppingView(listId: listId), settings, Routes.getAnimationType(routeName));
        
        case Routes.menuPreview:
          final menu = settings.arguments as SharedMenu?;
          if (menu == null) {
            return _errorRoute('Menu argument missing for preview');
          }
          return _buildRoute(MenuPreviewView(sharedMenu: menu), settings, Routes.getAnimationType(routeName));
        
        case Routes.createSharedShopping:
          return _buildRoute(const CreateSharedShoppingListView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.friendProfile:
          final userProfile = settings.arguments as UserProfile?;
          if (userProfile == null) {
            return _errorRoute('User profile argument missing');
          }
          return _buildRoute(FriendProfileView(friend: userProfile), settings, Routes.getAnimationType(routeName));

        case Routes.sharedShoppingLists:
          return _buildRoute(const SharedShoppingListsView(), settings, Routes.getAnimationType(routeName));

        // ===== MESSAGING ROUTES =====
        case Routes.messages:
          return _buildRoute(const ConversationsListView(), settings, Routes.getAnimationType(routeName));
        
        case Routes.chat:
          final conversationId = settings.arguments as String?;
          if (conversationId == null) {
            return _errorRoute('Conversation ID argument missing for chat');
          }
          return _buildRoute(ChatViewFacade(conversationId: conversationId), settings, Routes.getAnimationType(routeName));

        default:
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
  static Route<dynamic> _buildRoute(Widget page, RouteSettings settings, RouteAnimationType animationType) {
    switch (animationType) {
      case RouteAnimationType.fade:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        );

      case RouteAnimationType.slideFromBottom:
        return PageRouteBuilder(
          settings: settings,
          pageBuilder: (context, animation, secondaryAnimation) => page,
          transitionsBuilder: (context, animation, secondaryAnimation, child) {
            const begin = Offset(0.0, 1.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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
            const begin = Offset(1.0, 0.0);
            const end = Offset.zero;
            const curve = Curves.easeInOut;
            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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
            const begin = 0.0;
            const end = 1.0;
            const curve = Curves.elasticOut;
            final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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
        appBar: AppBar(title: const Text('Fel')),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: AppDimensions.iconSizeXl, color: AppColors.error),
              const SizedBox(height: AppDimensions.spacingXl),
              Text(
                message ?? 'Sidan kunde inte hittas',
                style: AppTextStyles.headlineSmall,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: AppDimensions.spacingMd),
              ElevatedButton(
                onPressed: () => Navigator.of(context).pushReplacementNamed(Routes.home),
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
        final tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
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
  static Future<dynamic> navigateTo(BuildContext context, String routeName, {Object? arguments}) {
    return Navigator.of(context).pushNamed(routeName, arguments: arguments);
  }

  /// Navigate and replace current route
  static Future<dynamic> navigateAndReplace(BuildContext context, String routeName, {Object? arguments}) {
    return Navigator.of(context).pushReplacementNamed(routeName, arguments: arguments);
  }

  /// Navigate and clear stack
  static Future<dynamic> navigateAndClearStack(BuildContext context, String routeName, {Object? arguments}) {
    return Navigator.of(context).pushNamedAndRemoveUntil(routeName, (route) => false, arguments: arguments);
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