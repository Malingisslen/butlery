// BUT-1508: the services the menu-to-shopping-list generator reaches for. Each
// is a lookup because the services are user-scoped and replaced at sign-in.
library;

import 'package:butlery/repositories/interfaces/auth_repository.dart';
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/services/menu/weekly_menu_plan_service.dart';
import 'package:butlery/services/pantry/pantry_service.dart';
import 'package:butlery/services/unified/unified_recipe_service.dart';
import 'package:butlery/services/unified/unified_shopping_service.dart';

class MenuShoppingLinks {
  const MenuShoppingLinks({
    required this.menuPlans,
    required this.recipes,
    required this.auth,
    required this.pantry,
    required this.shopping,
    required this.analytics,
  });

  final WeeklyMenuPlanService Function() menuPlans;
  final UnifiedRecipeService Function() recipes;
  final AuthRepository Function() auth;
  final PantryService Function() pantry;
  final UnifiedShoppingService Function() shopping;

  /// Null when analytics is not available: the list is made all the same.
  final AnalyticsService? Function() analytics;
}
