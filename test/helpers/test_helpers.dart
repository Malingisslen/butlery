// test/helpers/test_helpers.dart

import 'package:mockito/annotations.dart';
import 'package:butlery/services/multi_shopping_list_service.dart';
import 'package:butlery/services/friends_service.dart';
import 'package:butlery/services/share_service.dart';
import 'package:butlery/viewmodels/shopping_list_viewmodel.dart';
import 'package:shared_preferences/shared_preferences.dart';

// Generera mocks för alla services och dependencies
@GenerateMocks([
  MultiShoppingListService,
  FriendsService,
  ShareService,
  ShoppingListViewModel,
  SharedPreferences,
])
void main() {}

// Denna fil används för att generera alla mocks på ett ställe
