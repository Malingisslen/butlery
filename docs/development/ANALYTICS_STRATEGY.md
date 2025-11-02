# Analytics Strategy Guide

**Last Updated**: October 31, 2025
**Status**: Production Implementation
**Audience**: All Developers

---

## Overview

This guide establishes the analytics strategy for the Butlery Flutter application, including event naming conventions, required events catalog, parameter standardization, and implementation patterns for Firebase Analytics.

## Goals

1. **Business Intelligence**: Track user behavior, feature usage, and engagement metrics
2. **Product Optimization**: Identify friction points, popular features, and improvement opportunities
3. **User Journey Mapping**: Understand complete user flows from onboarding to retention
4. **Error Tracking**: Monitor and respond to errors and crashes in production
5. **A/B Testing Foundation**: Enable data-driven feature experimentation

## Event Naming Convention

### Standard Format

```
{category}_{action}_{object}
```

**Rules:**
- Use snake_case (lowercase with underscores)
- Maximum 40 characters
- No special characters except underscore
- Be specific but concise
- Use past tense for actions (viewed, created, deleted)

**Examples:**
```dart
// Good
recipe_viewed
recipe_created
menu_generated
shopping_list_shared
friend_request_sent

// Bad
RecipeViewed          // Wrong case
recipe-viewed         // Wrong separator
recipe_view           // Wrong tense
viewed_recipe         // Wrong order
recipe_was_viewed_by_user  // Too verbose
```

## Required Events Catalog

### 1. Authentication Events (Priority: HIGH)

| Event Name | Description | Required Parameters | Optional Parameters |
|------------|-------------|-------------------|-------------------|
| `user_signed_up` | New user registration | `method` (email/google/apple) | `user_id` |
| `user_signed_in` | Existing user login | `method` | `user_id` |
| `user_signed_out` | User logout | - | `session_duration` |
| `auth_failed` | Authentication failure | `method`, `error_code` | `error_message` |
| `password_reset_requested` | Password reset initiated | - | - |
| `password_reset_completed` | Password reset success | - | - |

### 2. Recipe Events (Priority: HIGH)

| Event Name | Description | Required Parameters | Optional Parameters |
|------------|-------------|-------------------|-------------------|
| `recipe_viewed` | User views recipe details | `recipe_id` | `source` (search/menu/friend) |
| `recipe_created` | New recipe created | `recipe_id`, `recipe_type` (personal/collaborative) | `has_image`, `ingredient_count` |
| `recipe_edited` | Recipe modified | `recipe_id` | `fields_changed` |
| `recipe_deleted` | Recipe removed | `recipe_id`, `recipe_type` | `reason` |
| `recipe_shared` | Recipe shared with friends | `recipe_id`, `recipient_count` | `share_method` |
| `recipe_imported` | Recipe imported from URL | `recipe_id`, `source_domain` | `import_method` |
| `recipe_copied` | User copies collaborative recipe to personal | `recipe_id` | - |
| `recipe_image_uploaded` | Image added to recipe | `recipe_id`, `image_count` | `upload_source` |
| `recipe_search_performed` | User searches recipes | `search_query`, `results_count` | `filters_applied` |
| `recipe_filtered` | Filters applied to recipe list | `filter_type` | `filter_value` |

### 3. Menu Events (Priority: HIGH)

| Event Name | Description | Required Parameters | Optional Parameters |
|------------|-------------|-------------------|-------------------|
| `menu_generation_started` | AI menu generation initiated | - | `prompt_length` |
| `menu_generated` | AI menu successfully created | `recipe_count`, `generation_time_ms` | `ai_model` |
| `menu_generation_failed` | Menu generation error | `error_code` | `error_message` |
| `menu_saved` | Menu saved to Firestore | `menu_id`, `recipe_count` | `is_shared` |
| `menu_loaded` | User loads saved menu | `menu_id` | `is_owned` |
| `menu_shared` | Menu shared with friends | `menu_id`, `recipient_count` | `share_method` |
| `menu_deleted` | Menu removed | `menu_id` | `reason` |
| `menu_recipe_added` | Recipe added to existing menu | `menu_id`, `recipe_id` | - |
| `menu_recipe_removed` | Recipe removed from menu | `menu_id`, `recipe_id` | - |

### 4. Shopping List Events (Priority: HIGH)

| Event Name | Description | Required Parameters | Optional Parameters |
|------------|-------------|-------------------|-------------------|
| `shopping_list_created` | New shopping list created | `list_id`, `list_type` (personal/shared) | `initial_item_count` |
| `shopping_list_viewed` | User views shopping list | `list_id` | `source` |
| `shopping_list_item_added` | Item added to list | `list_id` | `source` (manual/recipe) |
| `shopping_list_item_checked` | Item marked as purchased | `list_id`, `item_count` | - |
| `shopping_list_item_unchecked` | Item marked as unpurchased | `list_id` | - |
| `shopping_list_item_deleted` | Item removed from list | `list_id` | - |
| `shopping_list_shared` | List shared with friends | `list_id`, `recipient_count` | `share_method` |
| `shopping_list_completed` | All items checked off | `list_id`, `item_count`, `time_to_complete_minutes` | - |
| `shopping_list_deleted` | List removed | `list_id`, `list_type` | `reason` |

### 5. Social Events (Priority: MEDIUM)

| Event Name | Description | Required Parameters | Optional Parameters |
|------------|-------------|-------------------|-------------------|
| `friend_request_sent` | Friend request initiated | `recipient_id` | `source` |
| `friend_request_accepted` | Friend request approved | `sender_id` | - |
| `friend_request_rejected` | Friend request declined | `sender_id` | `reason` |
| `friend_removed` | User unfriends someone | `friend_id` | `reason` |
| `comment_created` | Comment added to recipe | `recipe_id`, `comment_length` | - |
| `comment_edited` | Comment modified | `comment_id` | - |
| `comment_deleted` | Comment removed | `comment_id` | `reason` |
| `recipe_rated` | User rates recipe | `recipe_id`, `rating` | `previous_rating` |
| `group_created` | New group/collaboration created | `group_id`, `member_count` | - |
| `group_member_added` | Member added to group | `group_id`, `member_id` | `added_by` |
| `group_member_removed` | Member removed from group | `group_id`, `member_id` | `reason` |

### 6. Discovery & Search Events (Priority: MEDIUM)

| Event Name | Description | Required Parameters | Optional Parameters |
|------------|-------------|-------------------|-------------------|
| `discovery_viewed` | User accesses discovery page | - | - |
| `discovery_recipe_viewed` | Recipe viewed from discovery | `recipe_id` | `discovery_source` |
| `search_performed` | Global search executed | `search_query`, `results_count` | `search_type` |
| `filter_applied` | Search/list filter used | `filter_type`, `filter_value` | `results_count` |
| `sort_applied` | List sort order changed | `sort_type` | `previous_sort` |

### 7. Import & OCR Events (Priority: MEDIUM)

| Event Name | Description | Required Parameters | Optional Parameters |
|------------|-------------|-------------------|-------------------|
| `ocr_scan_started` | OCR ingredient scan initiated | - | `source` (camera/gallery) |
| `ocr_scan_completed` | OCR scan successful | `ingredients_detected`, `scan_time_ms` | `confidence_score` |
| `ocr_scan_failed` | OCR scan error | `error_code` | `error_message` |
| `url_import_started` | Recipe URL import initiated | `source_domain` | - |
| `url_import_completed` | URL import successful | `recipe_id`, `import_time_ms` | `source_domain` |
| `url_import_failed` | URL import error | `error_code`, `source_domain` | `error_message` |

### 8. Settings & Preferences Events (Priority: LOW)

| Event Name | Description | Required Parameters | Optional Parameters |
|------------|-------------|-------------------|-------------------|
| `settings_opened` | User accesses settings | - | - |
| `profile_updated` | User profile edited | `fields_changed` | - |
| `avatar_updated` | Profile picture changed | - | `upload_source` |
| `preferences_updated` | App preferences modified | `preference_type` | `new_value` |
| `notification_settings_changed` | Notification preferences changed | `setting_type`, `new_value` | - |
| `theme_changed` | App theme toggled | `theme` (light/dark) | - |

### 9. Error & Performance Events (Priority: HIGH)

| Event Name | Description | Required Parameters | Optional Parameters |
|------------|-------------|-------------------|-------------------|
| `error_occurred` | Application error encountered | `error_code`, `error_type` | `stack_trace`, `user_action` |
| `network_error` | Network request failed | `endpoint`, `status_code` | `error_message` |
| `app_crashed` | Application crash | `crash_type` | `stack_trace` |
| `slow_operation` | Performance issue detected | `operation_name`, `duration_ms` | `threshold_ms` |
| `offline_mode_activated` | App switched to offline mode | - | `reason` |

### 10. User Journey Events (Priority: MEDIUM)

| Event Name | Description | Required Parameters | Optional Parameters |
|------------|-------------|-------------------|-------------------|
| `onboarding_started` | First app launch | - | - |
| `onboarding_completed` | Onboarding flow finished | `steps_completed` | `time_spent_seconds` |
| `onboarding_skipped` | User skips onboarding | `step_skipped` | - |
| `feature_discovered` | User first uses a feature | `feature_name` | `discovery_method` |
| `app_opened` | App launched/resumed | `session_count` | `time_since_last_open` |
| `app_backgrounded` | App sent to background | `session_duration_seconds` | - |
| `screen_viewed` | Screen/view displayed | `screen_name` | `previous_screen` |

## Parameter Standardization

### Common Parameters

Use consistent parameter names across all events:

| Parameter Name | Type | Description | Example Values |
|----------------|------|-------------|----------------|
| `user_id` | String | Current user Firebase UID | `abc123xyz` |
| `recipe_id` | String | Recipe document ID | `recipe_xyz789` |
| `recipe_type` | String | Personal or collaborative | `personal`, `collaborative` |
| `list_id` | String | Shopping list ID | `list_abc123` |
| `menu_id` | String | Menu document ID | `menu_xyz789` |
| `error_code` | String | Error identifier | `auth/invalid-email` |
| `error_message` | String | Human-readable error | `Invalid email format` |
| `source` | String | Origin of action | `search`, `discovery`, `friend` |
| `method` | String | Authentication method | `email`, `google`, `apple` |
| `duration_ms` | Int | Operation duration in milliseconds | `1250` |
| `count` | Int | Generic count value | `5` |
| `success` | Boolean | Operation success status | `true`, `false` |

### Parameter Value Guidelines

**DO:**
- Keep values short and descriptive
- Use snake_case for multi-word values
- Use consistent terminology across events
- Include units in parameter name (e.g., `duration_ms`, `time_minutes`)

**DON'T:**
- Include PII (personally identifiable information)
- Log sensitive data (passwords, tokens, emails)
- Use free-form text unless necessary
- Exceed 100 characters per parameter value

## Implementation Patterns

### 1. Service Layer Analytics

```dart
import 'package:butlery/services/analytics_service.dart';
import 'package:butlery/core/providers/application_provider.dart';

class RecipeService extends BaseService {
  final AnalyticsService _analyticsService = ServiceLocator.get<AnalyticsService>();

  Future<Recipe?> createRecipe({
    required String title,
    required List<String> ingredients,
  }) async {
    try {
      final recipe = await _repository.create(/* ... */);

      // Log analytics event
      await _analyticsService.logEvent(
        name: 'recipe_created',
        parameters: {
          'recipe_id': recipe.id,
          'recipe_type': 'personal',
          'has_image': recipe.imageUrls.isNotEmpty,
          'ingredient_count': ingredients.length,
        },
      );

      return recipe;
    } catch (e) {
      // Log error analytics
      await _analyticsService.logEvent(
        name: 'error_occurred',
        parameters: {
          'error_code': 'recipe_creation_failed',
          'error_type': e.runtimeType.toString(),
          'user_action': 'create_recipe',
        },
      );
      rethrow;
    }
  }
}
```

### 2. ViewModel Layer Analytics

```dart
class RecipeDetailViewModel extends ChangeNotifier {
  final AnalyticsService _analyticsService = ServiceLocator.get<AnalyticsService>();

  Future<void> loadRecipe(String recipeId, {String? source}) async {
    await executeAsync(() async {
      _recipe = await _recipeService.getRecipe(recipeId);

      // Log screen view
      await _analyticsService.logScreenView(
        screenName: 'recipe_detail',
        parameters: {
          'recipe_id': recipeId,
          'source': source ?? 'unknown',
        },
      );

      // Log recipe viewed event
      await _analyticsService.logEvent(
        name: 'recipe_viewed',
        parameters: {
          'recipe_id': recipeId,
          'recipe_type': _recipe.isPersonal ? 'personal' : 'collaborative',
          'source': source ?? 'direct',
        },
      );
    });
  }
}
```

### 3. User Journey Tracking

```dart
// In main.dart or navigation service
class NavigationObserver extends RouteObserver<PageRoute<dynamic>> {
  final AnalyticsService _analyticsService = ServiceLocator.get<AnalyticsService>();

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    super.didPush(route, previousRoute);

    if (route is PageRoute) {
      _analyticsService.logScreenView(
        screenName: route.settings.name ?? 'unknown',
        parameters: {
          'previous_screen': previousRoute?.settings.name ?? 'none',
        },
      );
    }
  }
}
```

### 4. Error Tracking Integration

```dart
// In AppLogger or error handling mixin
class AppLogger {
  static final AnalyticsService _analyticsService = ServiceLocator.get<AnalyticsService>();

  static void error(String message, [Object? error, StackTrace? stackTrace]) {
    developer.log(
      message,
      name: 'Butlery',
      level: Level.SEVERE.value,
      error: error,
      stackTrace: stackTrace,
    );

    // Log to analytics
    _analyticsService.logEvent(
      name: 'error_occurred',
      parameters: {
        'error_message': message,
        'error_type': error?.runtimeType.toString() ?? 'unknown',
        'error_code': _extractErrorCode(error),
      },
    );
  }
}
```

## Testing & Validation

### Debug Mode Verification

Use Firebase Analytics DebugView to validate events:

```bash
# Enable debug mode for Android
adb shell setprop debug.firebase.analytics.app com.butlery.app

# Enable debug mode for iOS
# Add -FIRDebugEnabled to Xcode scheme arguments
```

### Analytics Testing Checklist

- [ ] Event fires with correct name (snake_case, <40 chars)
- [ ] All required parameters present
- [ ] Parameter values match expected format
- [ ] No PII or sensitive data in parameters
- [ ] Event appears in Firebase DebugView within 1 minute
- [ ] Event parameters match documentation

### Common Issues

**Event not appearing:**
- Check Firebase configuration (google-services.json / GoogleService-Info.plist)
- Verify analytics enabled in Firebase console
- Ensure app is in foreground (some events buffered in background)
- Check network connectivity

**Parameter not recorded:**
- Max 25 parameters per event
- Parameter name max 40 characters
- Parameter value max 100 characters
- Some parameter names reserved by Firebase (e.g., `firebase_*`, `google_*`, `ga_*`)

## Implementation Checklist

### Phase 1: Core Events (Week 1)
- [ ] Create AnalyticsService wrapper for Firebase Analytics
- [ ] Implement authentication events (6 events)
- [ ] Implement core recipe events (10 events)
- [ ] Implement menu generation events (9 events)
- [ ] Implement shopping list events (9 events)
- [ ] Set up Firebase Analytics DebugView
- [ ] Verify events in Firebase console

### Phase 2: Social & Discovery (Week 2)
- [ ] Implement social interaction events (11 events)
- [ ] Implement discovery & search events (5 events)
- [ ] Implement import & OCR events (6 events)
- [ ] Create analytics dashboard in Firebase
- [ ] Document event tracking coverage

### Phase 3: Error & Journey (Week 3)
- [ ] Implement error tracking events (5 events)
- [ ] Implement user journey events (7 events)
- [ ] Implement settings events (6 events)
- [ ] Integrate with AppLogger for automatic error tracking
- [ ] Set up analytics alerts for critical errors

## Related Documentation

- **Firebase Analytics Setup**: `/docs/operations/FIREBASE_SETUP.md` (if exists)
- **Error Handling**: `/lib/core/utils/logger.dart`
- **Service Architecture**: `/docs/architecture/SERVICE_ARCHITECTURE.md` (if exists)

## Firebase Analytics Resources

- [Firebase Analytics Events Best Practices](https://firebase.google.com/docs/analytics/events)
- [Predefined Events Reference](https://firebase.google.com/docs/reference/android/com/google/firebase/analytics/FirebaseAnalytics.Event)
- [Debug Mode Documentation](https://firebase.google.com/docs/analytics/debugview)
- [BigQuery Export Setup](https://firebase.google.com/docs/analytics/bigquery-export)

---

**Questions?** Contact the Product Team or refer to Firebase Analytics documentation.
