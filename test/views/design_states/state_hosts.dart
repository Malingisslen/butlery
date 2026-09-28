/// P8-U01: every row's host, keyed by the row's identity (view::state).
library;

import 'package:mocktail/mocktail.dart';

import 'package:butlery/models/pantry/pantry_item.dart';
import 'package:butlery/models/realtime/realtime_resource.dart';
import 'package:butlery/models/recipe_unified.dart';
import 'package:butlery/services/menu/menu_scoring.dart';

import '../../infrastructure/factories/recipe_factory.dart';
import 'hosts/chat_hosts.dart';
import 'hosts/hem_hosts.dart';
import 'hosts/menu_hosts.dart';
import 'hosts/recipe_hosts.dart';
import 'hosts/shell_hosts.dart';
import 'hosts/shopping_hosts.dart';
import 'hosts/social_hosts.dart';
import 'hosts/task_hosts.dart';
import 'state_host.dart';

/// The host for each of the 53 rows.
final Map<String, StateHost> stateHosts = {
  ...hemHosts,
  ...shellHosts,
  ...chatHosts,
  ...taskHosts,
  ...recipeHosts,
  ...shoppingHosts,
  ...socialHosts,
  ...menuHosts,
};

/// The mocktail fallbacks the hosts' `any()` matchers need.
void registerHostFallbacks() {
  registerFallbackValue(ConflictEntity.recipeOwn);
  registerFallbackValue(RecipeFactory.build(id: 'fallback'));
  registerFallbackValue(PantryLocation.pantry);
  registerFallbackValue(DateTime(2026));
  registerFallbackValue(<Recipe>[]);
  registerFallbackValue(<String>{});
  registerFallbackValue(MenuScoringContext.empty);
}
