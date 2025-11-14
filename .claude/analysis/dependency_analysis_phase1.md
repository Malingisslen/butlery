# Dependency Analysis - Phase 1
**Generated**: 2025-11-13 19:28:39

## Executive Summary

### Overview
- **Total Files Analyzed**: 762
- **Total Lines of Code**: 220,590
- **Average File Size**: 289 LOC

### Distribution by Layer
- **Core**: 40 files (5.2%) - 10,446 LOC (avg 261 LOC/file)
- **Data**: 2 files (0.3%) - 239 LOC (avg 119 LOC/file)
- **Extension**: 1 files (0.1%) - 456 LOC (avg 456 LOC/file)
- **Mixin**: 8 files (1.0%) - 4,414 LOC (avg 551 LOC/file)
- **Model**: 49 files (6.4%) - 16,572 LOC (avg 338 LOC/file)
- **Other**: 29 files (3.8%) - 8,584 LOC (avg 296 LOC/file)
- **Repository**: 62 files (8.1%) - 16,438 LOC (avg 265 LOC/file)
- **Service**: 188 files (24.7%) - 60,016 LOC (avg 319 LOC/file)
- **Utility**: 8 files (1.0%) - 3,218 LOC (avg 402 LOC/file)
- **Viewmodel**: 88 files (11.5%) - 28,439 LOC (avg 323 LOC/file)
- **Widget**: 287 files (37.7%) - 71,768 LOC (avg 250 LOC/file)

### High-Level Findings
- **Zero Usage Files**: 30 files (3.9%) - potential dead code
- **Low Usage Files (1-3)**: 561 files (73.6%) - candidates for consolidation
- **High Usage Files (20+)**: 30 files - core infrastructure
- **Most Depended File**: lib/core/utils/logger.dart (285 dependents)

---

## Complete Dependency Matrix

**Sorted by Usage Count (Ascending)**

| File Path | LOC | Layer | Usage | Dependents |
|-----------|-----|-------|-------|------------|
| lib/core/config/feature_flags.dart | 161 | core | 0 | - |
| lib/core/config/firebase_config.dart | 160 | core | 0 | - |
| lib/core/error/failures.dart | 284 | core | 0 | - |
| lib/core/utils/service_optimizer.dart | 398 | utility | 0 | - |
| lib/main_e2e_emulator.dart | 271 | other | 0 | - |
| lib/main_e2e_mock.dart | 200 | other | 0 | - |
| lib/main_e2e_optimized.dart | 732 | other | 0 | - |
| lib/main_e2e_staging.dart | 284 | other | 0 | - |
| lib/models/recipe_unified.g.dart | 104 | model | 0 | - |
| lib/models/social/reactions.dart | 35 | model | 0 | - |
| lib/repositories/interfaces/reactions_repository.dart | 125 | repository | 0 | - |
| lib/repositories/mock/in_memory_repository.dart | 254 | repository | 0 | - |
| lib/services/dialog_service.dart | 231 | service | 0 | - |
| lib/services/social/activity_service.dart | 444 | service | 0 | - |
| lib/services/unified/friends_cache.dart | 5 | service | 0 | - |
| lib/services/unified/modules/shopping_operations.dart | 10 | service | 0 | - |
| lib/utils/performance_monitor.dart | 95 | other | 0 | - |
| lib/views/realtime/handlers/menu_action_handler.dart | 296 | widget | 0 | - |
| lib/views/social/group_content_feed/group_activity_timeline.dart | 346 | widget | 0 | - |
| lib/views/social/group_content_feed/group_content_app_bar.dart | 390 | widget | 0 | - |
| lib/views/social/group_content_feed/group_content_lists.dart | 229 | widget | 0 | - |
| lib/views/social/group_content_feed/group_content_search_bar.dart | 162 | widget | 0 | - |
| lib/views/social/group_content_feed/group_content_tab_bar.dart | 187 | widget | 0 | - |
| lib/views/social/group_invitations_view.dart | 354 | widget | 0 | - |
| lib/widgets/image/image_source_picker.dart | 119 | widget | 0 | - |
| lib/widgets/recipe/recipe_detail_comments.dart | 246 | widget | 0 | - |
| lib/widgets/recipe/recipe_detail_metadata.dart | 270 | widget | 0 | - |
| lib/widgets/social/activity_feed_item_widget.dart | 482 | widget | 0 | - |
| lib/widgets/social/groups/friend_category_widgets.dart | 39 | widget | 0 | - |
| lib/widgets/styled/styled_container.dart | 199 | widget | 0 | - |
| lib/constants/known_ingredients.dart | 569 | other | 1 | lib/utils/text/ingredient_normalizer.dart |
| lib/constants/preparation_words.dart | 246 | other | 1 | lib/utils/text/ingredient_normalizer.dart |
| lib/core/bootstrap/handlers/deep_link_handler.dart | 271 | core | 1 | lib/main.dart |
| lib/core/errors/contextual_error_engine.dart | 356 | core | 1 | lib/viewmodels/recipe_form/recipe_form_state.dart |
| lib/core/errors/unified_error_coordinator.dart | 448 | core | 1 | lib/viewmodels/recipe_form_viewmodel.dart |
| lib/core/form/form_fields_manager.dart | 492 | core | 1 | lib/viewmodels/recipe_form/recipe_form_state.dart |
| lib/core/mixins/firebase_sync_mixin.dart | 218 | mixin | 1 | lib/services/unified/unified_shopping_service.dart |
| lib/core/observers/performance_navigator_observer.dart | 215 | core | 1 | lib/main.dart |
| lib/core/observers/snackbar_route_observer.dart | 89 | core | 1 | lib/main.dart |
| lib/core/utils/retry_helper.dart | 435 | utility | 1 | lib/services/offline/offline_sync_manager.dart |
| lib/data/recipes/recipe_seeds.dart | 231 | data | 1 | lib/data/archived_recipes.dart |
| lib/models/audit_log.dart | 154 | model | 1 | lib/repositories/firebase/firebase_audit_repository.dart |
| lib/models/messaging/message_type.dart | 247 | model | 1 | lib/models/messaging/message.dart |
| lib/models/realtime/realtime_menu_analytics.dart | 255 | model | 1 | lib/models/realtime/realtime_menu.dart |
| lib/models/realtime/realtime_menu_factory.dart | 175 | model | 1 | lib/models/realtime/realtime_menu.dart |
| lib/models/realtime/realtime_menu_operations.dart | 291 | model | 1 | lib/models/realtime/realtime_menu.dart |
| lib/models/realtime/realtime_participants.dart | 381 | model | 1 | lib/models/realtime/realtime_recipe.dart |
| lib/models/realtime/recipe_operations.dart | 339 | model | 1 | lib/models/realtime/realtime_recipe.dart |
| lib/models/realtime/recipe_serialization.dart | 342 | model | 1 | lib/models/realtime/realtime_recipe.dart |
| lib/models/recipe/recipe_operations.dart | 418 | model | 1 | lib/models/recipe_unified.dart |
| lib/models/recipe/recipe_serialization.dart | 328 | model | 1 | lib/models/recipe_unified.dart |
| lib/models/social/activity_engagement.dart | 94 | model | 1 | lib/models/social/activity_feed_item.dart |
| lib/models/social/activity_type.dart | 71 | model | 1 | lib/models/social/activity_feed_item.dart |
| lib/models/social/content_reaction.dart | 193 | model | 1 | lib/repositories/interfaces/reactions_repository.dart |
| lib/models/social/reaction_statistics.dart | 266 | model | 1 | lib/repositories/interfaces/reactions_repository.dart |
| lib/repositories/firebase/firebase_comments_repository.dart | 407 | repository | 1 | lib/core/di/modules/social_module.dart |
| lib/repositories/firebase/firebase_connectivity_repository.dart | 229 | repository | 1 | lib/core/di/modules/social_module.dart |
| lib/repositories/firebase/firebase_deeplink_repository.dart | 271 | repository | 1 | lib/core/di/modules/social_module.dart |
| lib/repositories/firebase/firebase_menu_collaboration_repository.dart | 697 | repository | 1 | lib/core/di/modules/collaboration_module.dart |
| lib/repositories/firebase/firebase_messaging_repository.dart | 379 | repository | 1 | lib/core/di/modules/messaging_module.dart |
| lib/repositories/firebase/firebase_notifications_repository.dart | 412 | repository | 1 | lib/core/di/modules/messaging_module.dart |
| lib/repositories/firebase/firebase_recipe_repository.dart | 871 | repository | 1 | lib/core/di/modules/content_module.dart |
| lib/repositories/firebase/firebase_shopping_repository.dart | 424 | repository | 1 | lib/core/di/modules/collaboration_module.dart |
| lib/repositories/firebase/firebase_social_recipe_repository.dart | 518 | repository | 1 | lib/core/di/modules/social_module.dart |
| lib/repositories/firebase/firebase_social_sharing_repository.dart | 422 | repository | 1 | lib/core/di/modules/social_module.dart |
| lib/repositories/firebase/firebase_storage_repository.dart | 590 | repository | 1 | lib/core/di/modules/content_module.dart |
| lib/repositories/firebase/firebase_user_repository.dart | 509 | repository | 1 | lib/core/di/modules/social_module.dart |
| lib/repositories/firebase/friends/friend_request_repository.dart | 396 | repository | 1 | lib/repositories/firebase/firebase_friends_repository.dart |
| lib/repositories/firebase/friends/group_invitation_repository.dart | 471 | repository | 1 | lib/repositories/firebase/firebase_friends_repository.dart |
| lib/repositories/firebase/modules/conversation_auto_healer_module.dart | 96 | repository | 1 | lib/repositories/firebase/firebase_messaging_repository.dart |
| lib/repositories/firebase/modules/conversation_mutation_module.dart | 324 | repository | 1 | lib/repositories/firebase/firebase_messaging_repository.dart |
| lib/repositories/firebase/modules/conversation_query_module.dart | 108 | repository | 1 | lib/repositories/firebase/firebase_messaging_repository.dart |
| lib/repositories/firebase/modules/message_mutation_module.dart | 353 | repository | 1 | lib/repositories/firebase/firebase_messaging_repository.dart |
| lib/repositories/firebase/modules/message_query_module.dart | 113 | repository | 1 | lib/repositories/firebase/firebase_messaging_repository.dart |
| lib/repositories/firebase/modules/shopping_item_operations_module.dart | 256 | repository | 1 | lib/repositories/firebase/firebase_shopping_repository.dart |
| lib/repositories/firebase/modules/shopping_repository_query_module.dart | 143 | repository | 1 | lib/repositories/firebase/firebase_shopping_repository.dart |
| lib/repositories/firebase/modules/shopping_repository_routing_module.dart | 120 | repository | 1 | lib/repositories/firebase/firebase_shopping_repository.dart |
| lib/repositories/firebase/modules/shopping_template_operations_module.dart | 263 | repository | 1 | lib/repositories/firebase/firebase_shopping_repository.dart |
| lib/repositories/interfaces/activity_repository.dart | 178 | repository | 1 | lib/services/social/activity_service.dart |
| lib/services/account/account_deletion/content_deletion_operations.dart | 80 | service | 1 | lib/services/account/account_deletion_service.dart |
| lib/services/account/account_deletion/profile_deletion_operations.dart | 65 | service | 1 | lib/services/account/account_deletion_service.dart |
| lib/services/account/account_deletion/social_deletion_operations.dart | 198 | service | 1 | lib/services/account/account_deletion_service.dart |
| lib/services/account/account_deletion/storage_deletion_operations.dart | 89 | service | 1 | lib/services/account/account_deletion_service.dart |
| lib/services/deep_link_service.dart | 502 | service | 1 | lib/core/di/modules/social_module.dart |
| lib/services/extraction/extraction_manager.dart | 164 | service | 1 | lib/services/social_media_extractor.dart |
| lib/services/extraction/extractors/instagram_content_extractor.dart | 167 | service | 1 | lib/services/extraction/web_scraper.dart |
| lib/services/extraction/extractors/recipe_site_content_extractor.dart | 213 | service | 1 | lib/services/extraction/web_scraper.dart |
| lib/services/extraction/extractors/social_platform_content_extractor.dart | 108 | service | 1 | lib/services/extraction/web_scraper.dart |
| lib/services/extraction/site_parsers/arla_recipe_parser.dart | 345 | service | 1 | lib/core/di/modules/content_module.dart |
| lib/services/extraction/site_parsers/ica_recipe_parser.dart | 443 | service | 1 | lib/core/di/modules/content_module.dart |
| lib/services/extraction/site_parsers/koket_recipe_parser.dart | 351 | service | 1 | lib/core/di/modules/content_module.dart |
| lib/services/extraction/site_parsers/recept_recipe_parser.dart | 353 | service | 1 | lib/core/di/modules/content_module.dart |
| lib/services/extraction/site_parsers/recipe_quality_scorer.dart | 227 | service | 1 | lib/services/extraction/site_parsers/recipe_site_parser.dart |
| lib/services/image_picker_provider.dart | 106 | service | 1 | lib/services/image_picker_service.dart |
| lib/services/import/archive_import_strategy.dart | 271 | service | 1 | lib/services/import/import_manager.dart |
| lib/services/import/file_content_provider.dart | 81 | service | 1 | lib/services/import/file_import_strategy.dart |
| lib/services/import/photo_import_strategy.dart | 321 | service | 1 | lib/services/import/import_manager.dart |
| lib/services/import/url_import_strategy.dart | 479 | service | 1 | lib/services/import/import_manager.dart |
| lib/services/messaging/conversation_action_operations.dart | 203 | service | 1 | lib/services/messaging_service.dart |
| lib/services/messaging/message_management_operations.dart | 259 | service | 1 | lib/services/messaging_service.dart |
| lib/services/messaging/message_sending_operations.dart | 302 | service | 1 | lib/services/messaging_service.dart |
| lib/services/messaging_media_service.dart | 269 | service | 1 | lib/views/messaging/chat_view/chat_action_handler.dart |
| lib/services/notifications/fcm_service.dart | 430 | service | 1 | lib/services/notifications/notification_service.dart |
| lib/services/notifications/modules/fcm_token_manager.dart | 498 | service | 1 | lib/services/notifications/notification_service.dart |
| lib/services/notifications/modules/notification_analytics_manager.dart | 492 | service | 1 | lib/services/notifications/notification_service.dart |
| lib/services/notifications/modules/notification_batch_manager.dart | 472 | service | 1 | lib/services/notifications/notification_service.dart |
| lib/services/notifications/modules/notification_content_manager.dart | 406 | service | 1 | lib/services/notifications/notification_service.dart |
| lib/services/notifications/modules/notification_offline_manager.dart | 422 | service | 1 | lib/services/notifications/notification_service.dart |
| lib/services/notifications/modules/notification_preference_manager.dart | 425 | service | 1 | lib/services/notifications/notification_service.dart |
| lib/services/offline/offline_initialization.dart | 117 | service | 1 | lib/services/offline_service.dart |
| lib/services/offline/offline_sync_manager.dart | 210 | service | 1 | lib/services/offline_service.dart |
| lib/services/offline/offline_user_storage.dart | 131 | service | 1 | lib/services/offline_service.dart |
| lib/services/performance/intelligent_cache_manager.dart | 485 | service | 1 | lib/core/di/modules/performance_module.dart |
| lib/services/performance/optimized_image_loader.dart | 489 | service | 1 | lib/widgets/image/recipe_image_widget.dart |
| lib/services/performance/performance_monitoring_service.dart | 484 | service | 1 | lib/core/di/modules/performance_module.dart |
| lib/services/performance/startup_optimization_manager.dart | 447 | service | 1 | lib/core/di/modules/performance_module.dart |
| lib/services/permissions/group_permission_module.dart | 99 | service | 1 | lib/services/permission_service.dart |
| lib/services/permissions/recipe_permission_module.dart | 285 | service | 1 | lib/services/permission_service.dart |
| lib/services/permissions/shopping_permission_module.dart | 225 | service | 1 | lib/services/permission_service.dart |
| lib/services/persistence_service.dart | 315 | service | 1 | lib/core/di/modules/core_module.dart |
| lib/services/realtime/conflict_resolution_module.dart | 105 | service | 1 | lib/services/realtime_sync_service.dart |
| lib/services/realtime/connection_state_module.dart | 108 | service | 1 | lib/services/realtime_sync_service.dart |
| lib/services/realtime/modules/menu_participants.dart | 336 | service | 1 | lib/services/realtime/realtime_menu_service.dart |
| lib/services/realtime/modules/recipe_participants.dart | 401 | service | 1 | lib/services/realtime/realtime_recipe_service.dart |
| lib/services/realtime/realtime_recipe_service.dart | 500 | service | 1 | lib/core/di/modules/collaboration_module.dart |
| lib/services/realtime/resource_parser_module.dart | 73 | service | 1 | lib/services/realtime_sync_service.dart |
| lib/services/social/helpers/activity_cache_helper.dart | 62 | service | 1 | lib/services/social/activity_service.dart |
| lib/services/social/modules/social_participant_resolver_module.dart | 85 | service | 1 | lib/services/social_recipe_service.dart |
| lib/services/unified/friends/friends_firebase_sync.dart | 128 | service | 1 | lib/services/unified/unified_friends_service.dart |
| lib/services/unified/friends/friends_internal_operations.dart | 202 | service | 1 | lib/services/unified/unified_friends_service.dart |
| lib/services/unified/friends/friends_service_stubs.dart | 34 | service | 1 | lib/services/unified/unified_friends_service.dart |
| lib/services/unified/friends/friends_utility_operations.dart | 282 | service | 1 | lib/services/unified/unified_friends_service.dart |
| lib/services/unified/helpers/personal_recipe_crud.dart | 95 | service | 1 | lib/services/unified/unified_recipe_service.dart |
| lib/services/unified/helpers/recipe_auth_state_handler.dart | 87 | service | 1 | lib/services/unified/unified_recipe_service.dart |
| lib/services/unified/helpers/recipe_content_operations.dart | 70 | service | 1 | lib/services/unified/unified_recipe_service.dart |
| lib/services/unified/helpers/recipe_utility_operations.dart | 138 | service | 1 | lib/services/unified/unified_recipe_service.dart |
| lib/services/unified/helpers/social_operations_initializer.dart | 108 | service | 1 | lib/services/unified/unified_recipe_service.dart |
| lib/services/unified/modules/cache_operations.dart | 423 | service | 1 | lib/services/unified/modules/recipe_cache_module.dart |
| lib/services/unified/modules/cache_optimization.dart | 468 | service | 1 | lib/services/unified/modules/recipe_cache_module.dart |
| lib/services/unified/modules/debounced_sync_operations.dart | 366 | service | 1 | lib/services/unified/modules/recipe_cache_module.dart |
| lib/services/unified/modules/firebase_sync_manager.dart | 384 | service | 1 | lib/services/unified/modules/recipe_cache_module.dart |
| lib/services/unified/modules/realtime_cache_manager.dart | 423 | service | 1 | lib/services/unified/modules/realtime_recipe_module.dart |
| lib/services/unified/modules/realtime_conflict_resolver.dart | 464 | service | 1 | lib/services/unified/modules/realtime_recipe_module.dart |
| lib/services/unified/modules/realtime_content_operations.dart | 183 | service | 1 | lib/services/unified/modules/realtime_recipe_module.dart |
| lib/services/unified/modules/realtime_editor_tracker.dart | 185 | service | 1 | lib/services/unified/modules/realtime_recipe_module.dart |
| lib/services/unified/modules/realtime_event_handler.dart | 336 | service | 1 | lib/services/unified/modules/realtime_recipe_module.dart |
| lib/services/unified/modules/realtime_ingredient_operations.dart | 107 | service | 1 | lib/services/unified/modules/realtime_content_operations.dart |
| lib/services/unified/modules/realtime_instruction_operations.dart | 107 | service | 1 | lib/services/unified/modules/realtime_content_operations.dart |
| lib/services/unified/modules/realtime_session_manager.dart | 375 | service | 1 | lib/services/unified/modules/realtime_recipe_module.dart |
| lib/services/unified/modules/shopping_initialization_module.dart | 112 | service | 1 | lib/services/unified/unified_shopping_service.dart |
| lib/services/unified/modules/shopping_item_management_module.dart | 268 | service | 1 | lib/services/unified/unified_shopping_service.dart |
| lib/services/unified/modules/shopping_list_management_module.dart | 274 | service | 1 | lib/services/unified/unified_shopping_service.dart |
| lib/services/unified/modules/social_recipe/social_recipe_creation_service.dart | 179 | service | 1 | lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart |
| lib/services/unified/modules/social_recipe/social_recipe_membership_service.dart | 191 | service | 1 | lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart |
| lib/services/unified/modules/social_recipe/social_recipe_permission_service.dart | 205 | service | 1 | lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart |
| lib/services/unified/modules/social_recipe/social_recipe_query_service.dart | 285 | service | 1 | lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart |
| lib/services/unified/modules/social_recipe/social_recipe_sharing_service.dart | 335 | service | 1 | lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart |
| lib/services/unified/modules/social_recipe_module.dart | 248 | service | 1 | lib/services/unified/unified_recipe_service.dart |
| lib/services/unified/operations/collaborative_menu_operations.dart | 276 | service | 1 | lib/services/unified/unified_menu_service.dart |
| lib/services/unified/operations/collaborative_shopping/list_activity_operations.dart | 115 | service | 1 | lib/services/unified/operations/collaborative_shopping_operations.dart |
| lib/services/unified/operations/collaborative_shopping/list_item_operations.dart | 139 | service | 1 | lib/services/unified/operations/collaborative_shopping_operations.dart |
| lib/services/unified/operations/collaborative_shopping/list_member_operations.dart | 183 | service | 1 | lib/services/unified/operations/collaborative_shopping_operations.dart |
| lib/services/unified/operations/collaborative_shopping_operations.dart | 132 | service | 1 | lib/services/unified/unified_shopping_service.dart |
| lib/services/unified/operations/friend_categories_operations.dart | 527 | service | 1 | lib/services/unified/unified_friends_service.dart |
| lib/services/unified/operations/friends_invitations_operations.dart | 585 | service | 1 | lib/services/unified/unified_friends_service.dart |
| lib/services/unified/operations/friends_management_operations.dart | 518 | service | 1 | lib/services/unified/unified_friends_service.dart |
| lib/services/unified/operations/modules/comment_crud_operations.dart | 257 | service | 1 | lib/services/unified/operations/modules/recipe_comments_manager.dart |
| lib/services/unified/operations/modules/comment_likes_system.dart | 255 | service | 1 | lib/services/unified/operations/modules/recipe_comments_manager.dart |
| lib/services/unified/operations/modules/comment_notifications.dart | 340 | service | 1 | lib/services/unified/operations/modules/recipe_comments_manager.dart |
| lib/services/unified/operations/modules/comment_utilities.dart | 387 | service | 1 | lib/services/unified/operations/modules/recipe_comments_manager.dart |
| lib/services/unified/operations/modules/group_sharing_bulk_operations_module.dart | 229 | service | 1 | lib/services/unified/operations/social_group_sharing_operations.dart |
| lib/services/unified/operations/modules/group_sharing_validation_module.dart | 173 | service | 1 | lib/services/unified/operations/social_group_sharing_operations.dart |
| lib/services/unified/operations/modules/invitation_statistics_module.dart | 104 | service | 1 | lib/services/unified/operations/friends_invitations_operations.dart |
| lib/services/unified/operations/modules/invitation_validation_module.dart | 73 | service | 1 | lib/services/unified/operations/friends_invitations_operations.dart |
| lib/services/unified/operations/modules/legacy_recipe_ownership_resolver.dart | 112 | service | 1 | lib/services/unified/operations/modules/recipe_permission_helper.dart |
| lib/services/unified/operations/modules/rating_notifications.dart | 411 | service | 1 | lib/services/unified/operations/modules/recipe_social_stats.dart |
| lib/services/unified/operations/modules/rating_statistics.dart | 561 | service | 1 | lib/services/unified/operations/modules/recipe_social_stats.dart |
| lib/services/unified/operations/modules/recipe_comments_manager.dart | 318 | service | 1 | lib/services/unified/operations/social_recipe_operations.dart |
| lib/services/unified/operations/modules/recipe_member_manager.dart | 476 | service | 1 | lib/services/unified/operations/social_recipe_operations.dart |
| lib/services/unified/operations/modules/recipe_rating_system.dart | 410 | service | 1 | lib/services/unified/operations/modules/recipe_social_stats.dart |
| lib/services/unified/operations/modules/recipe_sharing_manager.dart | 493 | service | 1 | lib/services/unified/operations/social_recipe_operations.dart |
| lib/services/unified/operations/modules/recipe_social_stats.dart | 412 | service | 1 | lib/services/unified/operations/social_recipe_operations.dart |
| lib/services/unified/operations/modules/shopping_social_share_module.dart | 373 | service | 1 | lib/services/unified/operations/shopping_share_operations.dart |
| lib/services/unified/operations/modules/social_engagement_metrics.dart | 481 | service | 1 | lib/services/unified/operations/modules/recipe_social_stats.dart |
| lib/services/unified/operations/personal_shopping_operations.dart | 491 | service | 1 | lib/services/unified/unified_shopping_service.dart |
| lib/services/unified/operations/realtime_recipe/collaboration_management_module.dart | 491 | service | 1 | lib/services/unified/operations/realtime_recipe_operations.dart |
| lib/services/unified/operations/realtime_recipe/presence_tracking_module.dart | 470 | service | 1 | lib/services/unified/operations/realtime_recipe_operations.dart |
| lib/services/unified/operations/realtime_recipe/realtime_editing_module.dart | 410 | service | 1 | lib/services/unified/operations/realtime_recipe_operations.dart |
| lib/services/unified/operations/realtime_recipe/realtime_watching_module.dart | 388 | service | 1 | lib/services/unified/operations/realtime_recipe_operations.dart |
| lib/services/unified/operations/realtime_recipe/shared/realtime_diagnostics_helper.dart | 49 | service | 1 | lib/services/unified/operations/realtime_recipe_operations.dart |
| lib/services/unified/operations/realtime_recipe_operations.dart | 550 | service | 1 | lib/services/unified/unified_recipe_service.dart |
| lib/services/unified/operations/shopping_share_operations.dart | 292 | service | 1 | lib/services/unified/unified_shopping_service.dart |
| lib/services/unified/operations/social_group_sharing_operations.dart | 365 | service | 1 | lib/services/unified/unified_friends_service.dart |
| lib/services/upload/upload_progress_tracker.dart | 198 | service | 1 | lib/services/upload/image_upload_service.dart |
| lib/services/upload/upload_queue_manager.dart | 258 | service | 1 | lib/services/upload/image_upload_service.dart |
| lib/services/upload/upload_retry_manager.dart | 258 | service | 1 | lib/services/upload/image_upload_service.dart |
| lib/theme/components/button_themes.dart | 221 | other | 1 | lib/theme/component_themes.dart |
| lib/theme/components/feedback_themes.dart | 109 | other | 1 | lib/theme/component_themes.dart |
| lib/theme/components/input_themes.dart | 148 | other | 1 | lib/theme/component_themes.dart |
| lib/theme/components/navigation_themes.dart | 97 | other | 1 | lib/theme/component_themes.dart |
| lib/utils/social_content_features.dart | 322 | other | 1 | lib/viewmodels/universal_share_dialog_viewmodel.dart |
| lib/utils/text/ingredient_normalizer.dart | 315 | other | 1 | lib/utils/text/ingredient_processor.dart |
| lib/utils/text/ingredient_preprocessor.dart | 330 | other | 1 | lib/utils/text/ingredient_processor.dart |
| lib/utils/text/shopping_list_generator.dart | 357 | other | 1 | lib/views/recipe_detail/handlers/recipe_shopping_handler.dart |
| lib/viewmodels/add_members_to_group/member_search_manager.dart | 47 | viewmodel | 1 | lib/viewmodels/add_members_to_group_viewmodel.dart |
| lib/viewmodels/add_members_to_group/member_selection_manager.dart | 59 | viewmodel | 1 | lib/viewmodels/add_members_to_group_viewmodel.dart |
| lib/viewmodels/add_members_to_group_viewmodel.dart | 304 | viewmodel | 1 | lib/views/social/add_members_to_group_view.dart |
| lib/viewmodels/archive/archive_import_operations_manager.dart | 100 | viewmodel | 1 | lib/viewmodels/archive_import_viewmodel.dart |
| lib/viewmodels/archive/archive_search_manager.dart | 127 | viewmodel | 1 | lib/viewmodels/archive_import_viewmodel.dart |
| lib/viewmodels/archive/archive_selection_manager.dart | 57 | viewmodel | 1 | lib/viewmodels/archive_import_viewmodel.dart |
| lib/viewmodels/base_viewmodel.dart | 478 | viewmodel | 1 | lib/viewmodels/import_base_viewmodel.dart |
| lib/viewmodels/collaborative_shopping/shopping_display_manager.dart | 84 | viewmodel | 1 | lib/viewmodels/collaborative_shopping_viewmodel.dart |
| lib/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart | 112 | viewmodel | 1 | lib/viewmodels/collaborative_shopping_viewmodel.dart |
| lib/viewmodels/collaborative_shopping/shopping_permission_manager.dart | 32 | viewmodel | 1 | lib/viewmodels/collaborative_shopping_viewmodel.dart |
| lib/viewmodels/conversations_viewmodel.dart | 232 | viewmodel | 1 | lib/core/di/modules/ui_module.dart |
| lib/viewmodels/create_group_conversation_viewmodel.dart | 279 | viewmodel | 1 | lib/views/messaging/create_group_conversation_view.dart |
| lib/viewmodels/create_group_viewmodel.dart | 472 | viewmodel | 1 | lib/core/di/modules/ui_module.dart |
| lib/viewmodels/discovery_dashboard/discovery_content_manager.dart | 251 | viewmodel | 1 | lib/viewmodels/discovery_dashboard_viewmodel.dart |
| lib/viewmodels/discovery_dashboard/discovery_friend_activity_manager.dart | 167 | viewmodel | 1 | lib/viewmodels/discovery_dashboard_viewmodel.dart |
| lib/viewmodels/discovery_dashboard/discovery_recommendations_manager.dart | 274 | viewmodel | 1 | lib/viewmodels/discovery_dashboard_viewmodel.dart |
| lib/viewmodels/friends/friends_profile_cache_manager.dart | 126 | viewmodel | 1 | lib/viewmodels/friends_viewmodel.dart |
| lib/viewmodels/friends/friends_search_manager.dart | 143 | viewmodel | 1 | lib/viewmodels/friends_viewmodel.dart |
| lib/viewmodels/friends/friends_selection_manager.dart | 74 | viewmodel | 1 | lib/viewmodels/friends_viewmodel.dart |
| lib/viewmodels/group_detail_viewmodel.dart | 446 | viewmodel | 1 | lib/views/messaging/group_detail_view.dart |
| lib/viewmodels/group_recipe_selection_viewmodel.dart | 223 | viewmodel | 1 | lib/widgets/common/dialogs/recipe_selection/group_recipe_sharing_dialog.dart |
| lib/viewmodels/menu/menu_generator.dart | 166 | viewmodel | 1 | lib/viewmodels/menu_viewmodel.dart |
| lib/viewmodels/menu/menu_social_manager.dart | 259 | viewmodel | 1 | lib/viewmodels/menu_viewmodel.dart |
| lib/viewmodels/realtime/connection_monitor.dart | 194 | viewmodel | 1 | lib/viewmodels/realtime_menu_viewmodel.dart |
| lib/viewmodels/realtime_menu/realtime_menu_operations.dart | 380 | viewmodel | 1 | lib/viewmodels/realtime_menu_viewmodel.dart |
| lib/viewmodels/realtime_menu/realtime_menu_state.dart | 235 | viewmodel | 1 | lib/viewmodels/realtime_menu_viewmodel.dart |
| lib/viewmodels/realtime_menu/realtime_participant_manager.dart | 381 | viewmodel | 1 | lib/viewmodels/realtime_menu_viewmodel.dart |
| lib/viewmodels/realtime_menu/realtime_stream_manager.dart | 225 | viewmodel | 1 | lib/viewmodels/realtime_menu_viewmodel.dart |
| lib/viewmodels/recipe/personal_recipe_viewmodel.dart | 328 | viewmodel | 1 | lib/viewmodels/unified_recipe_viewmodel.dart |
| lib/viewmodels/recipe/realtime_recipe_viewmodel.dart | 439 | viewmodel | 1 | lib/viewmodels/unified_recipe_viewmodel.dart |
| lib/viewmodels/recipe/recipe_query_viewmodel.dart | 487 | viewmodel | 1 | lib/viewmodels/unified_recipe_viewmodel.dart |
| lib/viewmodels/recipe_form/image_management/image_upload_coordinator.dart | 448 | viewmodel | 1 | lib/viewmodels/recipe_form/recipe_image_manager.dart |
| lib/viewmodels/recipe_form/image_management/image_upload_notification_manager.dart | 185 | viewmodel | 1 | lib/viewmodels/recipe_form/recipe_image_manager.dart |
| lib/viewmodels/recipe_form/image_management/image_upload_validator.dart | 173 | viewmodel | 1 | lib/viewmodels/recipe_form/recipe_image_manager.dart |
| lib/viewmodels/recipe_form/image_management/upload_queue_summary_calculator.dart | 223 | viewmodel | 1 | lib/viewmodels/recipe_form/recipe_image_manager.dart |
| lib/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart | 283 | viewmodel | 1 | lib/viewmodels/recipe_form_viewmodel.dart |
| lib/viewmodels/recipe_selection_viewmodel.dart | 444 | viewmodel | 1 | lib/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart |
| lib/viewmodels/shared_content/shared_content_search_viewmodel.dart | 495 | viewmodel | 1 | lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart |
| lib/viewmodels/shared_content/social_sharing_viewmodel.dart | 467 | viewmodel | 1 | lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart |
| lib/viewmodels/shopping/shopping_analytics_manager.dart | 65 | viewmodel | 1 | lib/viewmodels/unified_shopping_viewmodel.dart |
| lib/viewmodels/shopping/shopping_item_operations_manager.dart | 78 | viewmodel | 1 | lib/viewmodels/unified_shopping_viewmodel.dart |
| lib/viewmodels/shopping_share_viewmodel.dart | 473 | viewmodel | 1 | lib/core/di/modules/ui_module.dart |
| lib/viewmodels/social_group_detail_viewmodel.dart | 395 | viewmodel | 1 | lib/views/social/group_detail_view.dart |
| lib/viewmodels/social_recipe/social_comments_manager.dart | 179 | viewmodel | 1 | lib/viewmodels/social_recipe_viewmodel.dart |
| lib/viewmodels/social_recipe/social_engagement_manager.dart | 35 | viewmodel | 1 | lib/viewmodels/social_recipe_viewmodel.dart |
| lib/viewmodels/social_recipe/social_profile_manager.dart | 58 | viewmodel | 1 | lib/viewmodels/social_recipe_viewmodel.dart |
| lib/viewmodels/unified_recipe_viewmodel.dart | 286 | viewmodel | 1 | lib/core/di/modules/ui_module.dart |
| lib/views/account/consent_management_view.dart | 494 | widget | 1 | lib/widgets/common/profile/profile_actions.dart |
| lib/views/account/data_export_view.dart | 447 | widget | 1 | lib/widgets/common/profile/profile_actions.dart |
| lib/views/edit_recipe/edit_recipe_actions.dart | 63 | widget | 1 | lib/views/edit_recipe_view.dart |
| lib/views/edit_recipe/edit_recipe_app_bar.dart | 49 | widget | 1 | lib/views/edit_recipe_view.dart |
| lib/views/edit_recipe/edit_recipe_banners.dart | 81 | widget | 1 | lib/views/edit_recipe_view.dart |
| lib/views/edit_recipe/edit_recipe_bottom_bar.dart | 52 | widget | 1 | lib/views/edit_recipe_view.dart |
| lib/views/edit_recipe/edit_recipe_dynamic_list.dart | 70 | widget | 1 | lib/views/edit_recipe/edit_recipe_form_fields.dart |
| lib/views/edit_recipe/edit_recipe_form_fields.dart | 188 | widget | 1 | lib/views/edit_recipe_view.dart |
| lib/views/edit_recipe/edit_recipe_image_picker.dart | 77 | widget | 1 | lib/views/edit_recipe/edit_recipe_form_fields.dart |
| lib/views/edit_recipe_view.dart | 354 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/file_import_view.dart | 286 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/fran_sociala_medier_view.dart | 408 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/import_via_url_view.dart | 157 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/importera_fran_arkiv_view.dart | 332 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/lagg_till_recept_view.dart | 178 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/legal/privacy_policy_view.dart | 286 | widget | 1 | lib/widgets/common/profile/profile_actions.dart |
| lib/views/messaging/chat_view/chat_action_handler.dart | 459 | widget | 1 | lib/views/messaging/chat_view/chat_view_facade.dart |
| lib/views/messaging/chat_view/chat_input_section.dart | 268 | widget | 1 | lib/views/messaging/chat_view/chat_view_facade.dart |
| lib/views/messaging/chat_view/chat_message_stream.dart | 246 | widget | 1 | lib/views/messaging/chat_view/chat_view_facade.dart |
| lib/views/messaging/conversations_list_view.dart | 459 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/messaging/create_group_conversation_view.dart | 371 | widget | 1 | lib/widgets/messaging/new_conversation_dialog.dart |
| lib/views/messaging/group_detail_view.dart | 580 | widget | 1 | lib/views/messaging/chat_view/chat_action_handler.dart |
| lib/views/photo_import_view.dart | 397 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/receive_share_view.dart | 495 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/recipe_detail/handlers/recipe_management_handler.dart | 104 | widget | 1 | lib/views/recipe_detail/recipe_detail_actions.dart |
| lib/views/recipe_detail/handlers/recipe_shopping_handler.dart | 176 | widget | 1 | lib/views/recipe_detail/recipe_detail_actions.dart |
| lib/views/recipe_detail/handlers/recipe_social_handler.dart | 122 | widget | 1 | lib/views/recipe_detail/recipe_detail_actions.dart |
| lib/views/recipe_detail/recipe_detail_actions.dart | 203 | widget | 1 | lib/views/recipe_detail_view.dart |
| lib/views/recipe_detail/recipe_detail_comments.dart | 758 | widget | 1 | lib/views/recipe_detail_view.dart |
| lib/views/recipe_detail/recipe_detail_content.dart | 311 | widget | 1 | lib/views/recipe_detail_view.dart |
| lib/views/recipe_detail/recipe_detail_metadata.dart | 419 | widget | 1 | lib/views/recipe_detail_view.dart |
| lib/views/recipe_detail_view.dart | 366 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/social/collaborative_shopping/collaborative_shopping_actions.dart | 386 | widget | 1 | lib/views/social/collaborative_shopping_view.dart |
| lib/views/social/collaborative_shopping/collaborative_shopping_header.dart | 247 | widget | 1 | lib/views/social/collaborative_shopping_view.dart |
| lib/views/social/collaborative_shopping/collaborative_shopping_items.dart | 248 | widget | 1 | lib/views/social/collaborative_shopping_view.dart |
| lib/views/social/collaborative_shopping_view.dart | 273 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/social/create_shared_shopping_list_view.dart | 345 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/social/discovery_dashboard/discovery_app_bar.dart | 395 | widget | 1 | lib/views/social/discovery_dashboard_view.dart |
| lib/views/social/discovery_dashboard/discovery_categories.dart | 118 | widget | 1 | lib/views/social/discovery_dashboard_view.dart |
| lib/views/social/discovery_dashboard/discovery_search_section.dart | 358 | widget | 1 | lib/views/social/discovery_dashboard_view.dart |
| lib/views/social/discovery_dashboard/friend_activity_section.dart | 415 | widget | 1 | lib/views/social/discovery_dashboard_view.dart |
| lib/views/social/discovery_dashboard/recommendations_section.dart | 453 | widget | 1 | lib/views/social/discovery_dashboard_view.dart |
| lib/views/social/discovery_dashboard/trending_content_section.dart | 364 | widget | 1 | lib/views/social/discovery_dashboard_view.dart |
| lib/views/social/discovery_dashboard_view.dart | 496 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/social/friend_profile_view.dart | 315 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/social/friend_requests/friend_request_actions_refactored.dart | 441 | widget | 1 | lib/views/social/friend_requests_view.dart |
| lib/views/social/friend_requests/friend_requests_header.dart | 131 | widget | 1 | lib/views/social/friend_requests_view.dart |
| lib/views/social/friend_requests/incoming_requests_tab.dart | 93 | widget | 1 | lib/views/social/friend_requests_view.dart |
| lib/views/social/friend_requests/sent_requests_tab.dart | 93 | widget | 1 | lib/views/social/friend_requests_view.dart |
| lib/views/social/friend_requests_view.dart | 177 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/social/friends_list/friend_card.dart | 40 | widget | 1 | lib/views/social/friends_list/friends_tab.dart |
| lib/views/social/friends_list/friend_request_card.dart | 45 | widget | 1 | lib/views/social/friends_list/requests_tab.dart |
| lib/views/social/friends_list/friends_tab.dart | 42 | widget | 1 | lib/views/social/friends_list_view.dart |
| lib/views/social/friends_list/group_invitation_card.dart | 185 | widget | 1 | lib/views/social/friends_list/groups_tab.dart |
| lib/views/social/friends_list/group_search_tab.dart | 46 | widget | 1 | lib/views/social/friends_list_view.dart |
| lib/views/social/friends_list/groups_tab.dart | 185 | widget | 1 | lib/views/social/friends_list_view.dart |
| lib/views/social/friends_list/requests_tab.dart | 291 | widget | 1 | lib/views/social/friends_list_view.dart |
| lib/views/social/friends_list/search_result_card.dart | 200 | widget | 1 | lib/views/social/friends_list/search_tab.dart |
| lib/views/social/friends_list/search_tab.dart | 47 | widget | 1 | lib/views/social/friends_list_view.dart |
| lib/views/social/friends_list_view.dart | 383 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/social/group_detail/group_detail_actions.dart | 267 | widget | 1 | lib/views/social/group_detail/group_member_card.dart |
| lib/views/social/group_detail/group_detail_app_bar.dart | 122 | widget | 1 | lib/views/social/group_detail_view.dart |
| lib/views/social/group_detail/group_detail_header.dart | 164 | widget | 1 | lib/views/social/group_detail_view.dart |
| lib/views/social/group_detail/group_detail_stats.dart | 78 | widget | 1 | lib/views/social/group_detail_view.dart |
| lib/views/social/group_detail/group_invitation_card.dart | 179 | widget | 1 | lib/views/social/group_detail/group_members_list.dart |
| lib/views/social/group_detail/group_member_card.dart | 158 | widget | 1 | lib/views/social/group_detail/group_members_list.dart |
| lib/views/social/group_detail/group_members_list.dart | 123 | widget | 1 | lib/views/social/group_detail_view.dart |
| lib/views/social/group_detail_view.dart | 684 | widget | 1 | lib/views/social/friends_list/group_card.dart |
| lib/views/social/shared_shopping_lists_view.dart | 46 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/social/shared_with_me/shared_content_app_bar.dart | 67 | widget | 1 | lib/views/social/shared_with_me_view.dart |
| lib/views/social/shared_with_me/shared_content_lists.dart | 190 | widget | 1 | lib/views/social/shared_with_me_view.dart |
| lib/views/social/shared_with_me/shared_content_search_bar.dart | 45 | widget | 1 | lib/views/social/shared_with_me_view.dart |
| lib/views/social/shared_with_me/shared_content_tab_bar.dart | 112 | widget | 1 | lib/views/social/shared_with_me_view.dart |
| lib/views/social/shared_with_me/shared_shopping_list_card.dart | 438 | widget | 1 | lib/views/social/shared_with_me/shared_content_lists.dart |
| lib/views/social/shared_with_me_view.dart | 250 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/social/user_profile_edit_view.dart | 479 | widget | 1 | lib/core/router/app_router.dart |
| lib/views/unified_shopping/widgets/dialogs/shopping_item_dialogs.dart | 331 | widget | 1 | lib/views/unified_shopping/widgets/shopping_dialogs.dart |
| lib/views/unified_shopping/widgets/dialogs/shopping_list_operations.dart | 157 | widget | 1 | lib/views/unified_shopping/widgets/shopping_dialogs.dart |
| lib/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart | 491 | widget | 1 | lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart |
| lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart | 466 | widget | 1 | lib/views/unified_shopping/widgets/shopping_dialogs.dart |
| lib/views/unified_shopping/widgets/shopping_app_bar.dart | 189 | widget | 1 | lib/views/unified_shopping_view.dart |
| lib/views/unified_shopping/widgets/shopping_dialogs.dart | 213 | widget | 1 | lib/views/unified_shopping_view.dart |
| lib/views/unified_shopping/widgets/shopping_item_tiles.dart | 200 | widget | 1 | lib/views/unified_shopping/widgets/shopping_list_content.dart |
| lib/views/unified_shopping/widgets/shopping_list_content.dart | 295 | widget | 1 | lib/views/unified_shopping_view.dart |
| lib/views/unified_shopping/widgets/shopping_list_header.dart | 305 | widget | 1 | lib/views/unified_shopping_view.dart |
| lib/views/unified_shopping_view.dart | 432 | widget | 1 | lib/core/router/app_router.dart |
| lib/widgets/branding/app_logo.dart | 158 | widget | 1 | lib/views/auth_view.dart |
| lib/widgets/common/bottom_action_bar.dart | 30 | widget | 1 | lib/views/importera_fran_arkiv_view.dart |
| lib/widgets/common/buttons/overlay_button.dart | 46 | widget | 1 | lib/views/photo_import_view.dart |
| lib/widgets/common/content_cards/friend_card.dart | 359 | widget | 1 | lib/widgets/common/content_card.dart |
| lib/widgets/common/content_cards/image_preview_card.dart | 82 | widget | 1 | lib/views/photo_import_view.dart |
| lib/widgets/common/content_cards/menu_card.dart | 428 | widget | 1 | lib/widgets/common/content_card.dart |
| lib/widgets/common/content_cards/shopping_list_card.dart | 451 | widget | 1 | lib/widgets/common/content_card.dart |
| lib/widgets/common/dialogs/confirmation_dialogs.dart | 211 | widget | 1 | lib/widgets/common/navigation_components.dart |
| lib/widgets/common/dialogs/dialog_form_fields.dart | 384 | widget | 1 | lib/widgets/social/groups/create_group_dialog.dart |
| lib/widgets/common/dialogs/draft_recovery_dialog.dart | 180 | widget | 1 | lib/views/skriv_sjalv_recept_view.dart |
| lib/widgets/common/dialogs/group_shopping_list_selection_dialog.dart | 125 | widget | 1 | lib/views/social/group_detail_view.dart |
| lib/widgets/common/dialogs/menu_selection_dialog.dart | 236 | widget | 1 | lib/views/social/group_detail_view.dart |
| lib/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart | 409 | widget | 1 | lib/widgets/common/dialogs/recipe_selection_dialogs.dart |
| lib/widgets/common/dialogs/recipe_selection/group_recipe_sharing_dialog.dart | 408 | widget | 1 | lib/views/social/group_detail_view.dart |
| lib/widgets/common/dialogs/recipe_selection_dialogs.dart | 48 | widget | 1 | lib/widgets/common/navigation_components.dart |
| lib/widgets/common/dialogs/shopping_list_selection_dialog.dart | 251 | widget | 1 | lib/views/recipe_detail/handlers/recipe_shopping_handler.dart |
| lib/widgets/common/feedback/snackbar_widgets.dart | 83 | widget | 1 | lib/widgets/common/utility_components.dart |
| lib/widgets/common/filter_status_chip.dart | 64 | widget | 1 | lib/views/importera_fran_arkiv_view.dart |
| lib/widgets/common/friends/category_display_widgets.dart | 398 | widget | 1 | lib/widgets/common/friends/friend_category_widgets.dart |
| lib/widgets/common/friends/category_selection_widgets.dart | 325 | widget | 1 | lib/widgets/common/friends/friend_category_widgets.dart |
| lib/widgets/common/friends/friend_category_manager.dart | 496 | widget | 1 | lib/widgets/common/friends/friend_category_widgets.dart |
| lib/widgets/common/indicators/circular_icon_badge.dart | 50 | widget | 1 | lib/views/social/friends_list_view.dart |
| lib/widgets/common/indicators/edit_indicator_widget.dart | 135 | widget | 1 | lib/widgets/common/indicators/realtime_indicators.dart |
| lib/widgets/common/indicators/emoji_avatar.dart | 52 | widget | 1 | lib/views/social/group_invitations_view.dart |
| lib/widgets/common/indicators/loading_indicator.dart | 47 | widget | 1 | lib/views/social/group_invitations_view.dart |
| lib/widgets/common/indicators/member_count_badge.dart | 46 | widget | 1 | lib/views/social/group_invitations_view.dart |
| lib/widgets/common/indicators/participant_list_widget.dart | 217 | widget | 1 | lib/widgets/common/indicators/realtime_indicators.dart |
| lib/widgets/common/indicators/progress_overlay.dart | 74 | widget | 1 | lib/views/social/user_profile_edit_view.dart |
| lib/widgets/common/indicators/realtime_indicators.dart | 86 | widget | 1 | lib/widgets/common/navigation_components.dart |
| lib/widgets/common/indicators/realtime_status_widgets.dart | 117 | widget | 1 | lib/widgets/common/indicators/realtime_indicators.dart |
| lib/widgets/common/indicators/status_badge.dart | 49 | widget | 1 | lib/views/social/menu_preview_view.dart |
| lib/widgets/common/indicators/status_indicator.dart | 38 | widget | 1 | lib/views/receive_share_view.dart |
| lib/widgets/common/input/debounced_checkbox.dart | 79 | widget | 1 | lib/widgets/common/input_components.dart |
| lib/widgets/common/input/editable_menu_items_preview_dialog.dart | 146 | widget | 1 | lib/widgets/common/input/shopping_list_selector.dart |
| lib/widgets/common/input/instruction_editor.dart | 107 | widget | 1 | lib/widgets/common/input_components.dart |
| lib/widgets/common/input/portion_scaler.dart | 122 | widget | 1 | lib/widgets/common/input_components.dart |
| lib/widgets/common/input/portion_scaler_logic.dart | 155 | widget | 1 | lib/widgets/common/input/portion_scaler.dart |
| lib/widgets/common/input/portion_scaler_ui.dart | 430 | widget | 1 | lib/widgets/common/input/portion_scaler.dart |
| lib/widgets/common/input/shopping_item_dialog.dart | 270 | widget | 1 | lib/widgets/common/input_components.dart |
| lib/widgets/common/input/shopping_list_card.dart | 399 | widget | 1 | lib/widgets/common/input/shopping_list_selector.dart |
| lib/widgets/common/input/shopping_list_selector.dart | 402 | widget | 1 | lib/widgets/common/input_components.dart |
| lib/widgets/common/layout/auth_form_card.dart | 33 | widget | 1 | lib/views/auth_view.dart |
| lib/widgets/common/layout/category_header.dart | 77 | widget | 1 | lib/views/social/menu_preview_view.dart |
| lib/widgets/common/layout/layout_scaffolds.dart | 231 | widget | 1 | lib/widgets/common/layout_components.dart |
| lib/widgets/common/layout/status_indicators.dart | 107 | widget | 1 | lib/widgets/common/layout_components.dart |
| lib/widgets/common/menu_persistence/menu_load_dialog.dart | 321 | widget | 1 | lib/widgets/common/layout_components.dart |
| lib/widgets/common/menu_persistence/menu_save_dialog.dart | 302 | widget | 1 | lib/widgets/common/layout_components.dart |
| lib/widgets/common/navigation_components.dart | 283 | widget | 1 | lib/views/social/friend_profile_view.dart |
| lib/widgets/common/permissions/permission_widgets.dart | 206 | widget | 1 | lib/widgets/common/utility_components.dart |
| lib/widgets/common/profile/profile_actions.dart | 832 | widget | 1 | lib/widgets/common/profile/profile_menu.dart |
| lib/widgets/common/profile/profile_menu.dart | 365 | widget | 1 | lib/widgets/common/layout_components.dart |
| lib/widgets/common/search_filter/filter_chips_widget.dart | 64 | widget | 1 | lib/widgets/common/search_filter/filters_panel_widget.dart |
| lib/widgets/common/search_filter/filter_toggle_button.dart | 63 | widget | 1 | lib/widgets/common/search_filter_widget.dart |
| lib/widgets/common/search_filter/filters_panel_widget.dart | 106 | widget | 1 | lib/widgets/common/search_filter_widget.dart |
| lib/widgets/common/search_filter/search_stats_widget.dart | 91 | widget | 1 | lib/widgets/common/search_filter_widget.dart |
| lib/widgets/common/service/service_widgets.dart | 145 | widget | 1 | lib/widgets/common/utility_components.dart |
| lib/widgets/common/share_dialog/share_dialog_actions.dart | 157 | widget | 1 | lib/widgets/common/universal_share_dialog.dart |
| lib/widgets/common/share_dialog/share_dialog_header.dart | 101 | widget | 1 | lib/widgets/common/universal_share_dialog.dart |
| lib/widgets/common/share_dialog/share_dialog_helpers.dart | 89 | widget | 1 | lib/widgets/common/universal_share_dialog.dart |
| lib/widgets/common/share_dialog/share_dialog_states.dart | 201 | widget | 1 | lib/widgets/common/universal_share_dialog.dart |
| lib/widgets/common/share_dialog/share_message_input.dart | 38 | widget | 1 | lib/widgets/common/universal_share_dialog.dart |
| lib/widgets/common/share_dialog/share_mode_selection.dart | 143 | widget | 1 | lib/widgets/common/universal_share_dialog.dart |
| lib/widgets/common/share_dialog/share_target_selection.dart | 144 | widget | 1 | lib/widgets/common/universal_share_dialog.dart |
| lib/widgets/common/share_dialog/share_target_selection_enhanced.dart | 376 | widget | 1 | lib/widgets/common/universal_share_dialog.dart |
| lib/widgets/common/social/invitation_target_states.dart | 220 | widget | 1 | lib/widgets/common/social/social_invitation_api.dart |
| lib/widgets/common/social/invitation_target_widgets.dart | 224 | widget | 1 | lib/widgets/common/social/social_invitation_api.dart |
| lib/widgets/common/social/social_avatar_api.dart | 93 | widget | 1 | lib/widgets/common/social/social_facade.dart |
| lib/widgets/common/social/social_builders.dart | 111 | widget | 1 | lib/widgets/common/social/social_facade.dart |
| lib/widgets/common/social/social_collaborative_api.dart | 129 | widget | 1 | lib/widgets/common/social/social_facade.dart |
| lib/widgets/common/social/social_group_api.dart | 108 | widget | 1 | lib/widgets/common/social/social_facade.dart |
| lib/widgets/common/social/social_invitation_api.dart | 314 | widget | 1 | lib/widgets/common/social/social_facade.dart |
| lib/widgets/common/social_components/invitation_actions.dart | 421 | widget | 1 | lib/widgets/common/social_components/social_invitation_components.dart |
| lib/widgets/common/social_components/invitation_lists.dart | 282 | widget | 1 | lib/widgets/common/social_components/social_invitation_components.dart |
| lib/widgets/common/social_components/invitation_states.dart | 375 | widget | 1 | lib/widgets/common/social_components/social_invitation_components.dart |
| lib/widgets/common/social_components/social_avatar_components.dart | 396 | widget | 1 | lib/widgets/common/social_components.dart |
| lib/widgets/common/social_components/social_builder_components.dart | 494 | widget | 1 | lib/widgets/common/social_components.dart |
| lib/widgets/common/social_components/social_collaborative_components.dart | 499 | widget | 1 | lib/widgets/common/social_components.dart |
| lib/widgets/common/social_components/social_formatters.dart | 71 | widget | 1 | lib/widgets/common/social_components/social_builder_components.dart |
| lib/widgets/common/social_components/social_group_components.dart | 472 | widget | 1 | lib/widgets/common/social_components.dart |
| lib/widgets/common/social_components/social_invitation_components.dart | 428 | widget | 1 | lib/widgets/common/social_components.dart |
| lib/widgets/common/source_url_display.dart | 48 | widget | 1 | lib/views/fran_sociala_medier_view.dart |
| lib/widgets/common/state/message_states.dart | 257 | widget | 1 | lib/widgets/common/state_widget.dart |
| lib/widgets/common/state/skeleton_components.dart | 95 | widget | 1 | lib/widgets/common/state/loading_states.dart |
| lib/widgets/image/image_factory.dart | 393 | widget | 1 | lib/widgets/image/universal_image_manager.dart |
| lib/widgets/image/image_picker_dialogs.dart | 193 | widget | 1 | lib/viewmodels/recipe_form/recipe_image_manager.dart |
| lib/widgets/messaging/chat_app_bar.dart | 116 | widget | 1 | lib/views/messaging/chat_view/chat_view_facade.dart |
| lib/widgets/messaging/conversation_list_item.dart | 251 | widget | 1 | lib/views/messaging/conversations_list_view.dart |
| lib/widgets/messaging/error_list_tile.dart | 27 | widget | 1 | lib/views/messaging/conversations_list_view.dart |
| lib/widgets/messaging/fullscreen_image_viewer.dart | 117 | widget | 1 | lib/widgets/messaging/message_bubble.dart |
| lib/widgets/messaging/image_picker_dialog.dart | 166 | widget | 1 | lib/views/messaging/chat_view/chat_input_section.dart |
| lib/widgets/messaging/message_bubble.dart | 807 | widget | 1 | lib/views/messaging/chat_view/chat_message_stream.dart |
| lib/widgets/messaging/message_input_field.dart | 32 | widget | 1 | lib/views/messaging/chat_view/chat_input_section.dart |
| lib/widgets/messaging/modal_content_container.dart | 24 | widget | 1 | lib/views/messaging/conversations_list_view.dart |
| lib/widgets/messaging/modal_header_text.dart | 29 | widget | 1 | lib/views/messaging/conversations_list_view.dart |
| lib/widgets/messaging/new_conversation_dialog.dart | 334 | widget | 1 | lib/views/messaging/conversations_list_view.dart |
| lib/widgets/messaging/reply_banner.dart | 124 | widget | 1 | lib/views/messaging/chat_view/chat_input_section.dart |
| lib/widgets/messaging/search_bar_container.dart | 23 | widget | 1 | lib/views/messaging/conversations_list_view.dart |
| lib/widgets/messaging/styled_modal_bottom_sheet.dart | 22 | widget | 1 | lib/views/messaging/conversations_list_view.dart |
| lib/widgets/messaging/typing_indicator.dart | 190 | widget | 1 | lib/views/messaging/chat_view/chat_view_facade.dart |
| lib/widgets/permissions/edit_mode_ui_helper.dart | 59 | widget | 1 | lib/widgets/social/collaborative/components/collaborative_permissions_widgets.dart |
| lib/widgets/recipe/comment_debug_panel.dart | 66 | widget | 1 | lib/widgets/recipe/recipe_detail_comments.dart |
| lib/widgets/recipe/comment_form_widget.dart | 135 | widget | 1 | lib/widgets/recipe/recipe_detail_comments.dart |
| lib/widgets/recipe/comment_item_widget.dart | 143 | widget | 1 | lib/widgets/recipe/recipe_detail_comments.dart |
| lib/widgets/recipe/comment_time_formatter.dart | 31 | widget | 1 | lib/widgets/recipe/comment_item_widget.dart |
| lib/widgets/recipe/recipe_card.dart | 403 | widget | 1 | lib/widgets/common/content_card.dart |
| lib/widgets/recipe/upload_choice_dialog.dart | 78 | widget | 1 | lib/viewmodels/recipe_form/recipe_image_manager.dart |
| lib/widgets/social/avatar/avatar_widgets.dart | 334 | widget | 1 | lib/widgets/common/social/social_avatar_api.dart |
| lib/widgets/social/collaborative/collaborative_indicators.dart | 218 | widget | 1 | lib/widgets/common/social/social_collaborative_api.dart |
| lib/widgets/social/collaborative/components/collaborative_connection_widgets.dart | 122 | widget | 1 | lib/widgets/social/collaborative/collaborative_indicators.dart |
| lib/widgets/social/collaborative/components/collaborative_live_widgets.dart | 119 | widget | 1 | lib/widgets/social/collaborative/collaborative_indicators.dart |
| lib/widgets/social/collaborative/components/collaborative_permissions_widgets.dart | 69 | widget | 1 | lib/widgets/social/collaborative/collaborative_indicators.dart |
| lib/widgets/social/collaborative/components/collaborative_status_widgets.dart | 289 | widget | 1 | lib/widgets/social/collaborative/collaborative_indicators.dart |
| lib/widgets/social/group_shared_shopping_list_card.dart | 688 | widget | 1 | lib/views/social/group_content_feed/group_content_lists.dart |
| lib/widgets/social/groups/create_group_dialog.dart | 299 | widget | 1 | lib/widgets/social/groups/group_dialogs.dart |
| lib/widgets/social/groups/delete_group_dialog.dart | 103 | widget | 1 | lib/widgets/social/groups/group_dialogs.dart |
| lib/widgets/social/groups/edit_group_dialog.dart | 194 | widget | 1 | lib/widgets/social/groups/group_dialogs.dart |
| lib/widgets/social/groups/empty_group_delete_dialog.dart | 55 | widget | 1 | lib/views/social/group_detail_view.dart |
| lib/widgets/social/groups/group_dialogs.dart | 116 | widget | 1 | lib/widgets/common/social/social_group_api.dart |
| lib/widgets/social/groups/group_shared_content_section.dart | 345 | widget | 1 | lib/views/social/group_detail_view.dart |
| lib/widgets/social/groups/ownership_transfer_dialog.dart | 79 | widget | 1 | lib/views/social/group_detail_view.dart |
| lib/widgets/social/groups/remove_member_dialog.dart | 111 | widget | 1 | lib/widgets/social/groups/group_dialogs.dart |
| lib/widgets/social/groups/shared_content_card.dart | 192 | widget | 1 | lib/widgets/social/groups/group_shared_content_section.dart |
| lib/widgets/styled/styled_card.dart | 319 | widget | 1 | lib/widgets/messaging/message_bubble.dart |
| lib/widgets/user/user_collection_widgets.dart | 148 | widget | 1 | lib/widgets/user/user_display_widgets.dart |
| lib/core/base/base_action_handler.dart | 383 | core | 2 | lib/views/social/collaborative_shopping/collaborative_shopping_actions.dart<br>lib/views/social/frie... |
| lib/core/rate_limiting/rate_limiter.dart | 408 | core | 2 | lib/repositories/firebase/firebase_auth_repository.dart<br>lib/services/unified/modules/personal_rec... |
| lib/data/archived_recipes.dart | 8 | data | 2 | lib/services/import/archive_import_strategy.dart<br>lib/viewmodels/archive/archive_search_manager.da... |
| lib/models/realtime/live_editor.dart | 264 | model | 2 | lib/repositories/collaborative_recipe_repository.dart<br>lib/viewmodels/recipe_form/recipe_collabora... |
| lib/models/recipe/recipe_factory.dart | 441 | model | 2 | lib/models/recipe_unified.dart<br>lib/services/unified/modules/social_recipe/social_recipe_creation_... |
| lib/models/shared_content/copy_on_write_mixin.dart | 274 | model | 2 | lib/models/shared_menu.dart<br>lib/models/shared_recipe.dart |
| lib/repositories/firebase/firebase_analytics_repository.dart | 368 | repository | 2 | lib/core/di/modules/core_module.dart<br>lib/services/analytics_service.dart |
| lib/repositories/firebase/firebase_consent_repository.dart | 248 | repository | 2 | lib/core/di/modules/core_module.dart<br>lib/services/account/consent_service.dart |
| lib/repositories/firebase/firebase_ratings_repository.dart | 414 | repository | 2 | lib/core/di/modules/social_module.dart<br>lib/services/unified/helpers/social_operations_initializer... |
| lib/repositories/firebase/friends/friend_relationship_repository.dart | 293 | repository | 2 | lib/repositories/firebase/firebase_friends_repository.dart<br>lib/services/unified/unified_friends_s... |
| lib/repositories/interfaces/friends_repository.dart | 161 | repository | 2 | lib/core/di/modules/social_module.dart<br>lib/repositories/firebase/firebase_friends_repository.dart |
| lib/services/account/account_deletion_service.dart | 173 | service | 2 | lib/core/di/modules/core_module.dart<br>lib/widgets/common/profile/profile_actions.dart |
| lib/services/backup_service.dart | 347 | service | 2 | lib/core/di/modules/content_module.dart<br>lib/widgets/common/profile/profile_actions.dart |
| lib/services/connectivity_monitoring_service.dart | 267 | service | 2 | lib/core/di/modules/social_module.dart<br>lib/viewmodels/recipe_form/recipe_collaborative_manager.da... |
| lib/services/content_detector_service.dart | 413 | service | 2 | lib/services/analytics_service.dart<br>lib/views/receive_share_view.dart |
| lib/services/extraction/site_parsers/site_parser_registry.dart | 87 | service | 2 | lib/core/di/modules/content_module.dart<br>lib/services/import/url_import_strategy.dart |
| lib/services/extraction/web_scraper.dart | 346 | service | 2 | lib/services/import/url_import_strategy.dart<br>lib/viewmodels/url_import_viewmodel.dart |
| lib/services/import/file_import_strategy.dart | 486 | service | 2 | lib/services/import/import_manager.dart<br>lib/views/file_import_view.dart |
| lib/services/ocr_extraction_service.dart | 791 | service | 2 | lib/services/import/photo_import_strategy.dart<br>lib/viewmodels/photo_import_viewmodel.dart |
| lib/services/offline/sync_result.dart | 48 | service | 2 | lib/services/offline/offline_sync_manager.dart<br>lib/services/offline_service.dart |
| lib/services/realtime/modules/menu_operations.dart | 373 | service | 2 | lib/services/realtime/modules/menu_participants.dart<br>lib/services/realtime/realtime_menu_service.... |
| lib/services/realtime/modules/recipe_content_operations.dart | 494 | service | 2 | lib/services/realtime/modules/recipe_participants.dart<br>lib/services/realtime/realtime_recipe_serv... |
| lib/services/unified/friends/friends_state_manager.dart | 442 | service | 2 | lib/services/unified/friends/friends_internal_operations.dart<br>lib/services/unified/unified_friend... |
| lib/services/unified/modules/realtime_recipe_module.dart | 455 | service | 2 | lib/services/unified/helpers/recipe_content_operations.dart<br>lib/services/unified/unified_recipe_s... |
| lib/services/unified/modules/social_coordination/base_social_coordinator.dart | 462 | service | 2 | lib/services/unified/modules/social_menu/social_menu_coordinator.dart<br>lib/services/unified/module... |
| lib/services/unified/operations/personal_recipe_operations.dart | 227 | service | 2 | lib/services/import/import_manager.dart<br>lib/services/unified/unified_recipe_service.dart |
| lib/services/unified/operations/social_recipe_operations.dart | 482 | service | 2 | lib/services/unified/helpers/social_operations_initializer.dart<br>lib/services/unified/unified_reci... |
| lib/theme/app_theme.dart | 85 | other | 2 | lib/main.dart<br>lib/main_e2e_optimized.dart |
| lib/utils/recipe_scraper.dart | 194 | other | 2 | lib/services/extraction/site_parsers/recipe_site_parser.dart<br>lib/services/import/url_import_strat... |
| lib/viewmodels/account/consent_viewmodel.dart | 268 | viewmodel | 2 | lib/views/account/consent_management_view.dart<br>lib/widgets/common/profile/profile_actions.dart |
| lib/viewmodels/account/data_export_viewmodel.dart | 158 | viewmodel | 2 | lib/views/account/data_export_view.dart<br>lib/widgets/common/profile/profile_actions.dart |
| lib/viewmodels/archive_import_viewmodel.dart | 125 | viewmodel | 2 | lib/core/di/modules/ui_module.dart<br>lib/views/importera_fran_arkiv_view.dart |
| lib/viewmodels/chat_viewmodel.dart | 463 | viewmodel | 2 | lib/views/messaging/chat_view/chat_message_stream.dart<br>lib/views/messaging/chat_view/chat_view_fa... |
| lib/viewmodels/create_shared_list_viewmodel.dart | 260 | viewmodel | 2 | lib/core/di/modules/ui_module.dart<br>lib/views/social/create_shared_shopping_list_view.dart |
| lib/viewmodels/group_invitations_viewmodel.dart | 445 | viewmodel | 2 | lib/core/di/modules/ui_module.dart<br>lib/views/social/group_invitations_view.dart |
| lib/viewmodels/menu/menu_storage.dart | 373 | viewmodel | 2 | lib/viewmodels/menu/menu_social_manager.dart<br>lib/viewmodels/menu_viewmodel.dart |
| lib/viewmodels/photo_import_viewmodel.dart | 467 | viewmodel | 2 | lib/core/di/modules/ui_module.dart<br>lib/views/photo_import_view.dart |
| lib/viewmodels/realtime/optimistic_update_manager.dart | 96 | viewmodel | 2 | lib/viewmodels/realtime_menu/realtime_menu_operations.dart<br>lib/viewmodels/realtime_menu_viewmodel... |
| lib/viewmodels/realtime_menu_viewmodel.dart | 424 | viewmodel | 2 | lib/core/di/modules/ui_module.dart<br>lib/views/realtime/handlers/menu_action_handler.dart |
| lib/viewmodels/recipe_form/recipe_form_coordinator.dart | 192 | viewmodel | 2 | lib/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart<br>lib/viewmodels/recipe_form_vi... |
| lib/viewmodels/recipe_form/recipe_persistence_manager.dart | 431 | viewmodel | 2 | lib/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart<br>lib/viewmodels/recipe_form_vi... |
| lib/viewmodels/shared_content/shared_menu_viewmodel.dart | 446 | viewmodel | 2 | lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart<br>lib/viewmodels/shared_con... |
| lib/viewmodels/shared_content/shared_recipe_viewmodel.dart | 392 | viewmodel | 2 | lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart<br>lib/viewmodels/shared_con... |
| lib/viewmodels/shared_content/shared_shopping_viewmodel.dart | 484 | viewmodel | 2 | lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart<br>lib/viewmodels/shared_con... |
| lib/viewmodels/text_import_viewmodel.dart | 461 | viewmodel | 2 | lib/core/di/modules/ui_module.dart<br>lib/views/fran_sociala_medier_view.dart |
| lib/viewmodels/url_import_viewmodel.dart | 497 | viewmodel | 2 | lib/core/di/modules/ui_module.dart<br>lib/views/import_via_url_view.dart |
| lib/viewmodels/user_profile_viewmodel.dart | 441 | viewmodel | 2 | lib/core/di/modules/ui_module.dart<br>lib/views/social/user_profile_edit_view.dart |
| lib/views/recipe_detail/fullscreen_image_viewer.dart | 139 | widget | 2 | lib/views/recipe_detail/recipe_detail_actions.dart<br>lib/views/recipe_detail_view.dart |
| lib/views/skriv_sjalv_recept_view.dart | 747 | widget | 2 | lib/core/router/app_router.dart<br>lib/views/fran_sociala_medier_view.dart |
| lib/views/social/add_members_to_group_view.dart | 400 | widget | 2 | lib/views/social/group_detail/group_detail_actions.dart<br>lib/views/social/group_detail_view.dart |
| lib/views/social/friend_requests/friend_request_card.dart | 372 | widget | 2 | lib/views/social/friend_requests/incoming_requests_tab.dart<br>lib/views/social/friend_requests/sent... |
| lib/views/social/friends_list/group_card.dart | 66 | widget | 2 | lib/views/social/friends_list/groups_tab.dart<br>lib/views/social/friends_list/group_search_tab.dart |
| lib/views/social/menu_preview_view.dart | 445 | widget | 2 | lib/core/router/app_router.dart<br>lib/views/social/shared_with_me/shared_menu_card.dart |
| lib/views/social/shared_with_me/shared_menu_card.dart | 301 | widget | 2 | lib/views/social/group_content_feed/group_content_lists.dart<br>lib/views/social/shared_with_me/shar... |
| lib/views/social/shared_with_me/shared_recipe_card.dart | 320 | widget | 2 | lib/views/social/group_content_feed/group_content_lists.dart<br>lib/views/social/shared_with_me/shar... |
| lib/views/veckomeny_view.dart | 859 | widget | 2 | lib/core/router/app_router.dart<br>lib/widgets/social/groups/group_shared_content_section.dart |
| lib/widgets/common/cards/selection_card.dart | 50 | widget | 2 | lib/views/messaging/create_group_conversation_view.dart<br>lib/views/social/add_members_to_group_vie... |
| lib/widgets/common/content_cards/text_display_card.dart | 48 | widget | 2 | lib/views/photo_import_view.dart<br>lib/views/receive_share_view.dart |
| lib/widgets/common/dialogs/recipe_selection/menu_recipe_selection_dialog.dart | 338 | widget | 2 | lib/views/messaging/chat_view/chat_action_handler.dart<br>lib/widgets/common/dialogs/recipe_selectio... |
| lib/widgets/common/friends/friend_category_widgets.dart | 271 | widget | 2 | lib/widgets/common/social/social_group_api.dart<br>lib/widgets/common/utility_components.dart |
| lib/widgets/common/indicators/notification_badge.dart | 51 | widget | 2 | lib/views/mina_recept_view.dart<br>lib/widgets/common/layout/layout_scaffolds.dart |
| lib/widgets/common/input/shopping_list_actions.dart | 256 | widget | 2 | lib/widgets/common/input/shopping_list_card.dart<br>lib/widgets/common/input/shopping_list_selector.... |
| lib/widgets/common/input_components.dart | 310 | widget | 2 | lib/views/recipe_detail/recipe_detail_content.dart<br>lib/views/veckomeny_view.dart |
| lib/widgets/common/layout/bordered_container.dart | 40 | widget | 2 | lib/views/social/create_shared_shopping_list_view.dart<br>lib/views/social/user_profile_edit_view.da... |
| lib/widgets/common/loading/loading_widgets.dart | 121 | widget | 2 | lib/views/messaging/conversations_list_view.dart<br>lib/widgets/common/utility_components.dart |
| lib/widgets/common/loading_state_builder.dart | 451 | widget | 2 | lib/views/social/collaborative_shopping_view.dart<br>lib/views/social/friends_list/friends_tab.dart |
| lib/widgets/common/scaffolds/base_scaffold.dart | 500 | widget | 2 | lib/views/receive_share_view.dart<br>lib/views/social/user_profile_edit_view.dart |
| lib/widgets/common/search_filter/filter_models.dart | 87 | widget | 2 | lib/widgets/common/search_filter/filters_panel_widget.dart<br>lib/widgets/common/search_filter/filte... |
| lib/widgets/common/search_filter/search_input_widget.dart | 64 | widget | 2 | lib/views/messaging/conversations_list_view.dart<br>lib/widgets/common/search_filter_widget.dart |
| lib/widgets/common/social/social_helpers.dart | 95 | widget | 2 | lib/widgets/common/social/invitation_target_widgets.dart<br>lib/widgets/common/social/social_facade.... |
| lib/widgets/common/social_components/invitation_displays.dart | 282 | widget | 2 | lib/widgets/common/social/social_invitation_api.dart<br>lib/widgets/common/social_components/social_... |
| lib/widgets/common/social_components/invitation_selectors.dart | 460 | widget | 2 | lib/widgets/common/social/social_invitation_api.dart<br>lib/widgets/common/social_components/social_... |
| lib/widgets/image/avatar_image_widget.dart | 381 | widget | 2 | lib/widgets/image/image_factory.dart<br>lib/widgets/image/universal_image_manager.dart |
| lib/widgets/image/editable_image_widget.dart | 1329 | widget | 2 | lib/widgets/image/image_factory.dart<br>lib/widgets/image/universal_image_manager.dart |
| lib/widgets/image/image_gallery_widget.dart | 492 | widget | 2 | lib/widgets/image/image_factory.dart<br>lib/widgets/image/universal_image_manager.dart |
| lib/widgets/image/image_picker_widget.dart | 389 | widget | 2 | lib/widgets/image/image_factory.dart<br>lib/widgets/image/universal_image_manager.dart |
| lib/widgets/image/recipe_image_widget.dart | 423 | widget | 2 | lib/widgets/image/image_factory.dart<br>lib/widgets/image/universal_image_manager.dart |
| lib/widgets/messaging/error_text.dart | 21 | widget | 2 | lib/views/messaging/conversations_list_view.dart<br>lib/widgets/messaging/error_list_tile.dart |
| lib/widgets/social/collaborative/components/collaborative_participants_widgets.dart | 188 | widget | 2 | lib/widgets/social/collaborative/collaborative_indicators.dart<br>lib/widgets/social/collaborative/c... |
| lib/widgets/styled/styled_button.dart | 311 | widget | 2 | lib/views/messaging/conversations_list_view.dart<br>lib/widgets/messaging/new_conversation_dialog.da... |
| lib/widgets/user/user_layout_widgets.dart | 172 | widget | 2 | lib/widgets/user/user_collection_widgets.dart<br>lib/widgets/user/user_display_widgets.dart |
| lib/core/di/di_container.dart | 425 | core | 3 | lib/core/bootstrap/application_bootstrap.dart<br>lib/core/providers/application_provider.dart<br>lib... |
| lib/core/router/app_router.dart | 416 | core | 3 | lib/main.dart<br>lib/main_e2e_optimized.dart<br>lib/views/social/shared_with_me/shared_content_actio... |
| lib/core/utils/connectivity_check.dart | 494 | utility | 3 | lib/core/errors/contextual_error_engine.dart<br>lib/services/connectivity_monitoring_service.dart<br... |
| lib/firebase_options.dart | 89 | other | 3 | lib/main.dart<br>lib/main_e2e_emulator.dart<br>lib/main_e2e_staging.dart |
| lib/main.dart | 612 | other | 3 | lib/main_e2e_emulator.dart<br>lib/main_e2e_mock.dart<br>lib/main_e2e_staging.dart |
| lib/models/account/user_consent.dart | 184 | model | 3 | lib/repositories/firebase/firebase_consent_repository.dart<br>lib/services/account/consent_service.d... |
| lib/models/recipe_change.dart | 175 | model | 3 | lib/repositories/firebase/firebase_recipe_repository.dart<br>lib/repositories/interfaces/recipe_repo... |
| lib/models/shared_content/shared_content_status_mixin.dart | 211 | model | 3 | lib/models/shared_menu.dart<br>lib/models/shared_recipe.dart<br>lib/models/shared_shopping_list.dart |
| lib/models/social/reaction_type.dart | 76 | model | 3 | lib/models/social/content_reaction.dart<br>lib/models/social/reaction_statistics.dart<br>lib/reposit... |
| lib/models/social/social_comment.dart | 288 | model | 3 | lib/viewmodels/social_recipe/social_comments_manager.dart<br>lib/viewmodels/social_recipe/social_eng... |
| lib/repositories/collaborative_recipe_repository.dart | 310 | repository | 3 | lib/core/di/modules/content_module.dart<br>lib/services/unified/modules/realtime_editor_tracker.dart... |
| lib/repositories/firebase/dtos/conversation_dto.dart | 124 | repository | 3 | lib/repositories/firebase/firebase_messaging_repository.dart<br>lib/repositories/firebase/modules/co... |
| lib/repositories/firebase/firebase_recipe_presence_repository.dart | 214 | repository | 3 | lib/core/di/modules/collaboration_module.dart<br>lib/services/unified/operations/realtime_recipe/pre... |
| lib/repositories/firebase/firebase_shared_recipe_repository.dart | 301 | repository | 3 | lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart<br>lib/services/unified/mo... |
| lib/repositories/interfaces/analytics_repository.dart | 114 | repository | 3 | lib/core/di/modules/core_module.dart<br>lib/repositories/firebase/firebase_analytics_repository.dart... |
| lib/repositories/interfaces/deeplink_repository.dart | 21 | repository | 3 | lib/core/di/modules/social_module.dart<br>lib/repositories/firebase/firebase_deeplink_repository.dar... |
| lib/repositories/interfaces/social_recipe_repository.dart | 31 | repository | 3 | lib/core/di/modules/social_module.dart<br>lib/repositories/firebase/firebase_social_recipe_repositor... |
| lib/repositories/interfaces/storage_repository.dart | 136 | repository | 3 | lib/core/di/modules/content_module.dart<br>lib/repositories/firebase/firebase_storage_repository.dar... |
| lib/services/account/data_export_service.dart | 743 | service | 3 | lib/core/di/modules/core_module.dart<br>lib/viewmodels/account/data_export_viewmodel.dart<br>lib/wid... |
| lib/services/group_shared_content_service.dart | 274 | service | 3 | lib/core/di/modules/social_module.dart<br>lib/widgets/social/groups/group_shared_content_section.dar... |
| lib/services/import/import_manager.dart | 475 | service | 3 | lib/core/di/modules/content_module.dart<br>lib/core/di/modules/ui_module.dart<br>lib/viewmodels/impo... |
| lib/services/import/text_import_strategy.dart | 665 | service | 3 | lib/services/import/import_manager.dart<br>lib/services/import/photo_import_strategy.dart<br>lib/ser... |
| lib/services/presence_service.dart | 396 | service | 3 | lib/core/di/modules/messaging_module.dart<br>lib/viewmodels/chat_viewmodel.dart<br>lib/views/messagi... |
| lib/services/realtime/realtime_types.dart | 35 | service | 3 | lib/services/realtime/connection_state_module.dart<br>lib/services/realtime/resource_parser_module.d... |
| lib/services/unified/modules/personal_recipe_module.dart | 531 | service | 3 | lib/services/unified/helpers/personal_recipe_crud.dart<br>lib/services/unified/helpers/recipe_conten... |
| lib/services/unified/modules/realtime_field_operations.dart | 173 | service | 3 | lib/services/unified/modules/realtime_content_operations.dart<br>lib/services/unified/modules/realti... |
| lib/services/unified/modules/social_menu/social_menu_coordinator.dart | 449 | service | 3 | lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart<br>lib/viewmodels/shared_con... |
| lib/services/unified/modules/social_shopping/social_shopping_coordinator.dart | 417 | service | 3 | lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart<br>lib/viewmodels/shared_con... |
| lib/services/unified/operations/modules/recipe_permission_helper.dart | 404 | service | 3 | lib/services/permissions/recipe_permission_module.dart<br>lib/services/permission_service.dart<br>li... |
| lib/services/unified/operations/realtime_recipe/realtime_notification_module.dart | 594 | service | 3 | lib/services/unified/modules/realtime_recipe_module.dart<br>lib/services/unified/operations/realtime... |
| lib/services/unified/operations/social_menu_operations.dart | 447 | service | 3 | lib/core/di/modules/social_module.dart<br>lib/viewmodels/menu/menu_social_manager.dart<br>lib/viewmo... |
| lib/services/upload/image_upload_service.dart | 439 | service | 3 | lib/services/messaging_media_service.dart<br>lib/viewmodels/recipe_form/recipe_image_manager.dart<br... |
| lib/theme/theme_constants.dart | 173 | other | 3 | lib/theme/components/navigation_themes.dart<br>lib/widgets/styled/styled_card.dart<br>lib/widgets/st... |
| lib/utils/text/ingredient_parser.dart | 792 | other | 3 | lib/utils/text/ingredient_processor.dart<br>lib/utils/text/shopping_list_generator.dart<br>lib/widge... |
| lib/utils/text/unit_converter.dart | 283 | other | 3 | lib/utils/text/ingredient_parser.dart<br>lib/utils/text/shopping_list_generator.dart<br>lib/widgets/... |
| lib/viewmodels/auth_viewmodel.dart | 423 | viewmodel | 3 | lib/core/di/modules/ui_module.dart<br>lib/main_e2e_optimized.dart<br>lib/views/auth_view.dart |
| lib/viewmodels/import_base_viewmodel.dart | 331 | viewmodel | 3 | lib/viewmodels/photo_import_viewmodel.dart<br>lib/viewmodels/text_import_viewmodel.dart<br>lib/viewm... |
| lib/viewmodels/menu/menu_state_manager.dart | 151 | viewmodel | 3 | lib/viewmodels/menu/menu_social_manager.dart<br>lib/viewmodels/menu/menu_storage.dart<br>lib/viewmod... |
| lib/viewmodels/recipe_form/recipe_auto_save_manager.dart | 431 | viewmodel | 3 | lib/viewmodels/recipe_form/recipe_form_state.dart<br>lib/viewmodels/recipe_form_viewmodel.dart<br>li... |
| lib/viewmodels/recipe_form/recipe_collaborative_manager.dart | 365 | viewmodel | 3 | lib/viewmodels/recipe_form/recipe_form_coordinator.dart<br>lib/viewmodels/recipe_form/recipe_persist... |
| lib/viewmodels/shared_content/base_shared_content_viewmodel.dart | 364 | viewmodel | 3 | lib/viewmodels/shared_content/shared_menu_viewmodel.dart<br>lib/viewmodels/shared_content/shared_rec... |
| lib/views/auth_view.dart | 441 | widget | 3 | lib/core/router/app_router.dart<br>lib/main.dart<br>lib/main_e2e_optimized.dart |
| lib/views/social/shared_with_me/shared_content_actions.dart | 322 | widget | 3 | lib/views/social/shared_with_me/shared_menu_card.dart<br>lib/views/social/shared_with_me/shared_reci... |
| lib/widgets/common/layout/card_content.dart | 34 | widget | 3 | lib/views/messaging/group_detail_view.dart<br>lib/views/social/friend_profile_view.dart<br>lib/views... |
| lib/widgets/common/state/empty_states.dart | 194 | widget | 3 | lib/views/messaging/chat_view/chat_message_stream.dart<br>lib/views/messaging/conversations_list_vie... |
| lib/widgets/common/state/loading_states.dart | 155 | widget | 3 | lib/views/messaging/chat_view/chat_message_stream.dart<br>lib/views/social/discovery_dashboard_view.... |
| lib/widgets/common/user_avatar.dart | 48 | widget | 3 | lib/views/social/group_content_feed/group_activity_timeline.dart<br>lib/widgets/social/activity_feed... |
| lib/widgets/image/universal_image_manager.dart | 681 | widget | 3 | lib/views/edit_recipe/edit_recipe_form_fields.dart<br>lib/views/recipe_detail/recipe_detail_content.... |
| lib/widgets/user/user_avatar_widgets.dart | 229 | widget | 3 | lib/widgets/common/user_avatar.dart<br>lib/widgets/user/user_display_widgets.dart<br>lib/widgets/use... |
| lib/core/bootstrap/stages/content_stage.dart | 73 | core | 4 | lib/main.dart<br>lib/main_e2e_emulator.dart<br>lib/main_e2e_mock.dart<br>lib/main_e2e_staging.dart |
| lib/core/bootstrap/stages/core_stage.dart | 72 | core | 4 | lib/main.dart<br>lib/main_e2e_emulator.dart<br>lib/main_e2e_mock.dart<br>lib/main_e2e_staging.dart |
| lib/core/bootstrap/stages/platform_stage.dart | 77 | core | 4 | lib/main.dart<br>lib/main_e2e_emulator.dart<br>lib/main_e2e_mock.dart<br>lib/main_e2e_staging.dart |
| lib/core/bootstrap/stages/social_stage.dart | 91 | core | 4 | lib/main.dart<br>lib/main_e2e_emulator.dart<br>lib/main_e2e_mock.dart<br>lib/main_e2e_staging.dart |
| lib/core/bootstrap/stages/ui_stage.dart | 119 | core | 4 | lib/main.dart<br>lib/main_e2e_emulator.dart<br>lib/main_e2e_mock.dart<br>lib/main_e2e_staging.dart |
| lib/core/di/modules/performance_module.dart | 160 | core | 4 | lib/main.dart<br>lib/main_e2e_emulator.dart<br>lib/main_e2e_mock.dart<br>lib/main_e2e_staging.dart |
| lib/core/di/modules/ui_module.dart | 376 | core | 4 | lib/main.dart<br>lib/main_e2e_emulator.dart<br>lib/main_e2e_mock.dart<br>lib/main_e2e_staging.dart |
| lib/core/exceptions/repository_exception.dart | 14 | core | 4 | lib/repositories/firebase/base_shared_content_repository.dart<br>lib/repositories/firebase/firebase_... |
| lib/core/mixins/firebase_service_mixin.dart | 888 | mixin | 4 | lib/services/storage_service.dart<br>lib/services/unified/unified_menu_service.dart<br>lib/services/... |
| lib/core/mixins/json_serializable_mixin.dart | 654 | mixin | 4 | lib/models/friend_request.dart<br>lib/models/group_invitation.dart<br>lib/models/recipe_unified.dart... |
| lib/models/realtime/realtime_menu_data.dart | 265 | model | 4 | lib/models/realtime/realtime_menu.dart<br>lib/models/realtime/realtime_menu_analytics.dart<br>lib/mo... |
| lib/models/recommendation.dart | 129 | model | 4 | lib/services/recommendation_service.dart<br>lib/viewmodels/discovery_dashboard/discovery_recommendat... |
| lib/models/social/activity_feed.dart | 37 | model | 4 | lib/repositories/interfaces/activity_repository.dart<br>lib/services/social/activity_service.dart<br... |
| lib/models/social/activity_feed_item.dart | 346 | model | 4 | lib/repositories/interfaces/activity_repository.dart<br>lib/services/social/activity_service.dart<br... |
| lib/repositories/firebase/dtos/message_dto.dart | 161 | repository | 4 | lib/repositories/firebase/dtos/conversation_dto.dart<br>lib/repositories/firebase/modules/conversati... |
| lib/repositories/firebase/firebase_friends_repository.dart | 437 | repository | 4 | lib/core/di/modules/social_module.dart<br>lib/services/unified/friends/friends_internal_operations.d... |
| lib/repositories/firebase/firebase_shared_menu_repository.dart | 260 | repository | 4 | lib/services/unified/modules/social_menu/social_menu_coordinator.dart<br>lib/services/unified/unifie... |
| lib/repositories/firebase/firebase_shared_shopping_repository.dart | 261 | repository | 4 | lib/core/di/modules/collaboration_module.dart<br>lib/services/unified/modules/social_shopping/social... |
| lib/repositories/firebase/friends/friend_category_repository.dart | 398 | repository | 4 | lib/repositories/firebase/firebase_friends_repository.dart<br>lib/services/unified/friends/friends_i... |
| lib/repositories/interfaces/connectivity_repository.dart | 27 | repository | 4 | lib/core/di/modules/social_module.dart<br>lib/core/utils/connectivity_check.dart<br>lib/repositories... |
| lib/repositories/interfaces/menu_collaboration_repository.dart | 212 | repository | 4 | lib/core/di/modules/collaboration_module.dart<br>lib/repositories/firebase/firebase_menu_collaborati... |
| lib/repositories/mixins/permission_validation_mixin.dart | 487 | repository | 4 | lib/repositories/firebase/base_firebase_repository.dart<br>lib/repositories/firebase/firebase_consen... |
| lib/services/account/consent_service.dart | 182 | service | 4 | lib/core/di/modules/core_module.dart<br>lib/services/analytics_service.dart<br>lib/viewmodels/accoun... |
| lib/services/extraction/platform_detector.dart | 98 | service | 4 | lib/services/extraction/extractors/social_platform_content_extractor.dart<br>lib/services/extraction... |
| lib/services/menu_service.dart | 259 | service | 4 | lib/core/di/modules/content_module.dart<br>lib/services/unified/unified_menu_service.dart<br>lib/vie... |
| lib/services/notifications/notification_repository.dart | 810 | service | 4 | lib/services/notifications/modules/fcm_token_manager.dart<br>lib/services/notifications/modules/noti... |
| lib/services/performance/firebase_performance_service.dart | 333 | service | 4 | lib/core/di/modules/performance_module.dart<br>lib/core/observers/performance_navigator_observer.dar... |
| lib/services/recommendation_service.dart | 450 | service | 4 | lib/core/di/modules/content_module.dart<br>lib/viewmodels/discovery_dashboard/discovery_recommendati... |
| lib/services/share_service.dart | 488 | service | 4 | lib/core/di/modules/content_module.dart<br>lib/views/recipe_detail/handlers/recipe_management_handle... |
| lib/services/social_media_extractor.dart | 225 | service | 4 | lib/services/extraction/extraction_manager.dart<br>lib/services/extraction/web_scraper.dart<br>lib/v... |
| lib/services/unified/modules/realtime_edit_context.dart | 112 | service | 4 | lib/services/unified/modules/realtime_content_operations.dart<br>lib/services/unified/modules/realti... |
| lib/services/unified/modules/recipe_cache_module.dart | 351 | service | 4 | lib/services/unified/helpers/personal_recipe_crud.dart<br>lib/services/unified/helpers/recipe_auth_s... |
| lib/services/unified/operations/collaborative_shopping/list_lifecycle_operations.dart | 123 | service | 4 | lib/services/unified/operations/collaborative_shopping/list_activity_operations.dart<br>lib/services... |
| lib/utils/text/ingredient_processor.dart | 427 | other | 4 | lib/repositories/firebase/firebase_recipe_repository.dart<br>lib/services/import/text_import_strateg... |
| lib/utils/text/swedish_pluralization.dart | 484 | other | 4 | lib/utils/text/ingredient_normalizer.dart<br>lib/utils/text/ingredient_parser.dart<br>lib/utils/text... |
| lib/utils/text/text_formatting.dart | 318 | other | 4 | lib/utils/text/ingredient_parser.dart<br>lib/utils/text/swedish_pluralization.dart<br>lib/utils/text... |
| lib/viewmodels/collaborative_shopping_viewmodel.dart | 162 | viewmodel | 4 | lib/views/social/collaborative_shopping/collaborative_shopping_actions.dart<br>lib/views/social/coll... |
| lib/viewmodels/recipe_form/recipe_form_state.dart | 699 | viewmodel | 4 | lib/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart<br>lib/viewmodels/recipe_form/re... |
| lib/viewmodels/recipe_form/recipe_image_manager.dart | 1389 | viewmodel | 4 | lib/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart<br>lib/viewmodels/recipe_form/re... |
| lib/viewmodels/recipe_form/recipe_permission_manager.dart | 193 | viewmodel | 4 | lib/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart<br>lib/viewmodels/recipe_form/re... |
| lib/viewmodels/recipe_list_viewmodel.dart | 492 | viewmodel | 4 | lib/core/di/modules/ui_module.dart<br>lib/main_e2e_optimized.dart<br>lib/views/mina_recept_view.dart... |
| lib/views/messaging/chat_view/chat_view_facade.dart | 117 | widget | 4 | lib/core/router/app_router.dart<br>lib/views/messaging/conversations_list_view.dart<br>lib/views/mes... |
| lib/views/mina_recept_view.dart | 567 | widget | 4 | lib/core/router/app_router.dart<br>lib/main.dart<br>lib/main_e2e_optimized.dart<br>lib/views/auth_vi... |
| lib/widgets/common/dialogs/base_dialog.dart | 499 | widget | 4 | lib/core/utils/common_dialog_actions.dart<br>lib/widgets/common/dialogs/confirmation_dialogs.dart<br... |
| lib/widgets/social/groups/shared/group_dialog_components.dart | 314 | widget | 4 | lib/widgets/social/groups/create_group_dialog.dart<br>lib/widgets/social/groups/delete_group_dialog.... |
| lib/core/bootstrap/application_bootstrap.dart | 489 | core | 5 | lib/core/providers/application_provider.dart<br>lib/main.dart<br>lib/main_e2e_emulator.dart<br>lib/m... |
| lib/core/events/group_events.dart | 30 | core | 5 | lib/services/unified/operations/friends_invitations_operations.dart<br>lib/services/unified/operatio... |
| lib/models/shared_content/base_shared_content_model.dart | 313 | model | 5 | lib/models/shared_content/copy_on_write_mixin.dart<br>lib/models/shared_content/shared_content_statu... |
| lib/repositories/interfaces/social_sharing_repository.dart | 36 | repository | 5 | lib/core/di/modules/social_module.dart<br>lib/core/di/modules/ui_module.dart<br>lib/repositories/fir... |
| lib/repositories/interfaces/user_repository.dart | 94 | repository | 5 | lib/core/di/modules/social_module.dart<br>lib/repositories/firebase/firebase_user_repository.dart<br... |
| lib/services/extraction/site_parsers/recipe_site_parser.dart | 161 | service | 5 | lib/services/extraction/site_parsers/arla_recipe_parser.dart<br>lib/services/extraction/site_parsers... |
| lib/services/search_service.dart | 484 | service | 5 | lib/core/di/modules/content_module.dart<br>lib/viewmodels/archive/archive_search_manager.dart<br>lib... |
| lib/services/storage_service.dart | 241 | service | 5 | lib/core/di/modules/content_module.dart<br>lib/services/image_picker_service.dart<br>lib/services/up... |
| lib/services/unified/modules/social_recipe/social_recipe_coordinator.dart | 549 | service | 5 | lib/services/unified/modules/social_recipe_module.dart<br>lib/utils/social_content_features.dart<br>... |
| lib/services/unified/operations/modules/recipe_discovery_service.dart | 618 | service | 5 | lib/services/unified/operations/social_recipe_operations.dart<br>lib/services/unified/unified_recipe... |
| lib/services/unified/operations/realtime_recipe/shared/realtime_recipe_utils.dart | 269 | service | 5 | lib/services/unified/operations/realtime_recipe/collaboration_management_module.dart<br>lib/services... |
| lib/viewmodels/menu_viewmodel.dart | 512 | viewmodel | 5 | lib/core/di/modules/ui_module.dart<br>lib/views/veckomeny_view.dart<br>lib/widgets/common/layout_com... |
| lib/viewmodels/realtime/participant_tracker.dart | 188 | viewmodel | 5 | lib/viewmodels/realtime_menu/realtime_participant_manager.dart<br>lib/viewmodels/realtime_menu_viewm... |
| lib/widgets/common/layout/bottom_action_container.dart | 40 | widget | 5 | lib/views/edit_recipe/edit_recipe_bottom_bar.dart<br>lib/views/messaging/create_group_conversation_v... |
| lib/widgets/common/state/state_enums.dart | 36 | widget | 5 | lib/views/messaging/chat_view/chat_message_stream.dart<br>lib/views/messaging/conversations_list_vie... |
| lib/widgets/image/simple_image_widget.dart | 476 | widget | 5 | lib/widgets/image/image_factory.dart<br>lib/widgets/image/universal_image_manager.dart<br>lib/widget... |
| lib/core/bootstrap/stages/bootstrap_stage.dart | 156 | core | 6 | lib/core/bootstrap/application_bootstrap.dart<br>lib/core/bootstrap/stages/content_stage.dart<br>lib... |
| lib/core/di/interfaces/service_health.dart | 198 | core | 6 | lib/core/di/di_container.dart<br>lib/core/di/modules/collaboration_module.dart<br>lib/core/di/module... |
| lib/core/di/modules/collaboration_module.dart | 306 | core | 6 | lib/core/bootstrap/stages/social_stage.dart<br>lib/core/di/modules/ui_module.dart<br>lib/main.dart<b... |
| lib/core/di/modules/messaging_module.dart | 219 | core | 6 | lib/core/bootstrap/stages/social_stage.dart<br>lib/core/di/modules/ui_module.dart<br>lib/main.dart<b... |
| lib/core/dialogs/dialog_factory.dart | 200 | core | 6 | lib/views/messaging/group_detail_view.dart<br>lib/views/receive_share_view.dart<br>lib/views/social/... |
| lib/core/utils/common_dialog_actions.dart | 367 | utility | 6 | lib/core/base/base_action_handler.dart<br>lib/views/realtime/handlers/menu_action_handler.dart<br>li... |
| lib/core/validators/form_validators.dart | 445 | core | 6 | lib/views/auth_view.dart<br>lib/views/edit_recipe/edit_recipe_form_fields.dart<br>lib/views/skriv_sj... |
| lib/repositories/firebase/base_shared_content_repository.dart | 459 | repository | 6 | lib/repositories/firebase/firebase_shared_menu_repository.dart<br>lib/repositories/firebase/firebase... |
| lib/repositories/interfaces/messaging_repository.dart | 204 | repository | 6 | lib/core/di/modules/messaging_module.dart<br>lib/repositories/firebase/firebase_messaging_repository... |
| lib/repositories/interfaces/notifications_repository.dart | 214 | repository | 6 | lib/core/di/modules/messaging_module.dart<br>lib/repositories/firebase/firebase_notifications_reposi... |
| lib/repositories/interfaces/shopping_repository.dart | 54 | repository | 6 | lib/core/di/modules/collaboration_module.dart<br>lib/repositories/firebase/firebase_shopping_reposit... |
| lib/services/import/import_strategy.dart | 117 | service | 6 | lib/services/import/archive_import_strategy.dart<br>lib/services/import/file_import_strategy.dart<br... |
| lib/services/realtime/realtime_menu_service.dart | 500 | service | 6 | lib/core/di/modules/collaboration_module.dart<br>lib/core/di/modules/ui_module.dart<br>lib/viewmodel... |
| lib/services/unified/modules/service_adapters/recipe_service_adapter.dart | 261 | service | 6 | lib/services/unified/helpers/recipe_utility_operations.dart<br>lib/services/unified/modules/personal... |
| lib/theme/component_themes.dart | 71 | other | 6 | lib/theme/app_theme.dart<br>lib/views/receive_share_view.dart<br>lib/views/social/discovery_dashboar... |
| lib/viewmodels/collaborative_status_viewmodel.dart | 454 | viewmodel | 6 | lib/core/di/modules/ui_module.dart<br>lib/views/edit_recipe/edit_recipe_actions.dart<br>lib/views/ed... |
| lib/widgets/common/search_filter_widget.dart | 292 | widget | 6 | lib/views/importera_fran_arkiv_view.dart<br>lib/views/mina_recept_view.dart<br>lib/views/social/frie... |
| lib/widgets/image/image_components.dart | 386 | widget | 6 | lib/services/performance/optimized_image_loader.dart<br>lib/widgets/image/avatar_image_widget.dart<b... |
| lib/models/shared_shopping_list.dart | 456 | model | 7 | lib/repositories/firebase/firebase_shared_shopping_repository.dart<br>lib/services/unified/modules/s... |
| lib/repositories/firebase/firebase_audit_repository.dart | 323 | repository | 7 | lib/core/di/modules/content_module.dart<br>lib/core/di/modules/core_module.dart<br>lib/repositories/... |
| lib/repositories/interfaces/comments_repository.dart | 54 | repository | 7 | lib/core/di/modules/social_module.dart<br>lib/repositories/firebase/firebase_comments_repository.dar... |
| lib/services/image_picker_service.dart | 395 | service | 7 | lib/core/di/modules/content_module.dart<br>lib/core/di/modules/ui_module.dart<br>lib/viewmodels/reci... |
| lib/services/offline_service.dart | 306 | service | 7 | lib/core/di/modules/content_module.dart<br>lib/main_e2e_optimized.dart<br>lib/services/account/accou... |
| lib/viewmodels/group_content_viewmodel.dart | 493 | viewmodel | 7 | lib/core/di/modules/ui_module.dart<br>lib/views/social/group_content_feed/group_activity_timeline.da... |
| lib/viewmodels/universal_share_dialog_viewmodel.dart | 464 | viewmodel | 7 | lib/core/di/modules/ui_module.dart<br>lib/views/recipe_detail/handlers/recipe_social_handler.dart<br... |
| lib/core/di/modules/social_module.dart | 292 | core | 8 | lib/core/bootstrap/stages/social_stage.dart<br>lib/core/di/modules/collaboration_module.dart<br>lib/... |
| lib/core/mixins/singleton_service_mixin.dart | 340 | mixin | 8 | lib/core/utils/service_optimizer.dart<br>lib/services/analytics_service.dart<br>lib/services/content... |
| lib/services/unified/unified_menu_service.dart | 523 | service | 8 | lib/core/di/modules/content_module.dart<br>lib/services/unified/modules/social_menu/social_menu_coor... |
| lib/viewmodels/discovery_dashboard_viewmodel.dart | 541 | viewmodel | 8 | lib/core/di/modules/ui_module.dart<br>lib/views/social/discovery_dashboard/discovery_app_bar.dart<br... |
| lib/viewmodels/recipe_detail_viewmodel.dart | 339 | viewmodel | 8 | lib/views/recipe_detail/handlers/recipe_management_handler.dart<br>lib/views/recipe_detail/handlers/... |
| lib/widgets/common/content_card.dart | 491 | widget | 8 | lib/views/importera_fran_arkiv_view.dart<br>lib/views/mina_recept_view.dart<br>lib/views/photo_impor... |
| lib/widgets/common/social/social_facade.dart | 477 | widget | 8 | lib/widgets/common/social_components/invitation_actions.dart<br>lib/widgets/common/social_components... |
| lib/widgets/styled/styled_widgets.dart | 31 | widget | 8 | lib/views/auth_view.dart<br>lib/views/social/create_shared_shopping_list_view.dart<br>lib/views/soci... |
| lib/widgets/user/user_display_models.dart | 120 | widget | 8 | lib/views/social/group_content_feed/group_activity_timeline.dart<br>lib/widgets/common/user_avatar.d... |
| lib/core/di/interfaces/di_module.dart | 120 | core | 9 | lib/core/bootstrap/application_bootstrap.dart<br>lib/core/di/di_container.dart<br>lib/core/di/module... |
| lib/core/di/modules/content_module.dart | 340 | core | 9 | lib/core/bootstrap/stages/content_stage.dart<br>lib/core/bootstrap/stages/social_stage.dart<br>lib/c... |
| lib/core/types/app_timestamp.dart | 240 | core | 9 | lib/models/friend_category.dart<br>lib/models/friend_request.dart<br>lib/models/group_invitation.dar... |
| lib/models/realtime/realtime_recipe.dart | 397 | model | 9 | lib/repositories/collaborative_recipe_repository.dart<br>lib/services/realtime/modules/recipe_conten... |
| lib/models/realtime/realtime_resource.dart | 499 | model | 9 | lib/models/realtime/realtime_menu.dart<br>lib/models/realtime/realtime_recipe.dart<br>lib/models/rea... |
| lib/repositories/interfaces/ratings_repository.dart | 126 | repository | 9 | lib/core/di/modules/content_module.dart<br>lib/core/di/modules/social_module.dart<br>lib/repositorie... |
| lib/services/social_recipe_service.dart | 488 | service | 9 | lib/core/di/modules/social_module.dart<br>lib/core/di/modules/ui_module.dart<br>lib/utils/social_con... |
| lib/viewmodels/social_recipe_viewmodel.dart | 204 | viewmodel | 9 | lib/core/di/modules/ui_module.dart<br>lib/viewmodels/unified_recipe_viewmodel.dart<br>lib/views/reci... |
| lib/core/constants/routes.dart | 274 | core | 10 | lib/core/bootstrap/handlers/deep_link_handler.dart<br>lib/core/router/app_router.dart<br>lib/views/m... |
| lib/core/utils/serialization_utils.dart | 370 | utility | 10 | lib/models/account/user_consent.dart<br>lib/models/friend_request.dart<br>lib/models/group_invitatio... |
| lib/models/permissions/edit_mode.dart | 146 | model | 10 | lib/models/shared_recipe.dart<br>lib/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart... |
| lib/models/recipe_comment.dart | 436 | model | 10 | lib/repositories/firebase/firebase_comments_repository.dart<br>lib/repositories/interfaces/comments_... |
| lib/repositories/interfaces/recipe_repository.dart | 33 | repository | 10 | lib/core/di/modules/collaboration_module.dart<br>lib/core/di/modules/content_module.dart<br>lib/repo... |
| lib/repositories/interfaces/repository.dart | 17 | repository | 10 | lib/repositories/firebase/base_firebase_repository.dart<br>lib/repositories/interfaces/comments_repo... |
| lib/services/unified/types/recipe_types.dart | 214 | service | 10 | lib/services/unified/modules/personal_recipe_module.dart<br>lib/services/unified/modules/social_reci... |
| lib/widgets/common/layout_components.dart | 437 | widget | 10 | lib/views/import_via_url_view.dart<br>lib/views/lagg_till_recept_view.dart<br>lib/views/messaging/co... |
| lib/widgets/styled/styled_input.dart | 383 | widget | 10 | lib/core/dialogs/dialog_factory.dart<br>lib/views/import_via_url_view.dart<br>lib/views/messaging/cr... |
| lib/models/shared_content.dart | 289 | model | 11 | lib/models/shared_content/copy_on_write_mixin.dart<br>lib/models/shared_content/shared_content_statu... |
| lib/services/auth_service.dart | 359 | service | 11 | lib/core/di/modules/collaboration_module.dart<br>lib/core/di/modules/core_module.dart<br>lib/core/di... |
| lib/services/notifications/notification_service.dart | 499 | service | 11 | lib/services/messaging/message_sending_operations.dart<br>lib/services/unified/modules/social_recipe... |
| lib/services/realtime_sync_service.dart | 423 | service | 11 | lib/core/di/modules/collaboration_module.dart<br>lib/core/di/modules/ui_module.dart<br>lib/services/... |
| lib/viewmodels/unified_shopping_viewmodel.dart | 483 | viewmodel | 11 | lib/core/di/modules/ui_module.dart<br>lib/views/unified_shopping/widgets/dialogs/shopping_item_dialo... |
| lib/widgets/common/universal_share_dialog.dart | 425 | widget | 11 | lib/viewmodels/universal_share_dialog_viewmodel.dart<br>lib/views/recipe_detail/handlers/recipe_soci... |
| lib/core/utils/validation_utils.dart | 383 | utility | 12 | lib/services/unified/modules/social_recipe/social_recipe_membership_service.dart<br>lib/services/uni... |
| lib/core/utils/snackbar_utils.dart | 342 | utility | 13 | lib/views/messaging/group_detail_view.dart<br>lib/views/mina_recept_view.dart<br>lib/views/recipe_de... |
| lib/models/realtime/realtime_menu.dart | 696 | model | 13 | lib/models/realtime/realtime_menu_analytics.dart<br>lib/models/realtime/realtime_menu_factory.dart<b... |
| lib/models/shared_recipe.dart | 487 | model | 13 | lib/main_e2e_optimized.dart<br>lib/repositories/firebase/firebase_shared_recipe_repository.dart<br>l... |
| lib/services/analytics_service.dart | 733 | service | 13 | lib/core/di/modules/core_module.dart<br>lib/main.dart<br>lib/main_e2e_optimized.dart<br>lib/services... |
| lib/widgets/common/utility_components.dart | 403 | widget | 13 | lib/viewmodels/recipe_form/recipe_auto_save_manager.dart<br>lib/views/edit_recipe/edit_recipe_action... |
| lib/core/di/modules/core_module.dart | 290 | core | 14 | lib/core/bootstrap/stages/content_stage.dart<br>lib/core/bootstrap/stages/core_stage.dart<br>lib/cor... |
| lib/models/invitations/invitation_target.dart | 746 | model | 14 | lib/widgets/common/social/invitation_target_widgets.dart<br>lib/widgets/common/social/social_facade.... |
| lib/services/messaging_service.dart | 474 | service | 14 | lib/core/di/modules/messaging_module.dart<br>lib/core/di/modules/ui_module.dart<br>lib/services/mess... |
| lib/services/upload/upload_models.dart | 322 | service | 14 | lib/services/upload/image_upload_service.dart<br>lib/services/upload/upload_progress_tracker.dart<br... |
| lib/viewmodels/recipe_form_viewmodel.dart | 905 | viewmodel | 14 | lib/core/di/modules/ui_module.dart<br>lib/views/edit_recipe/edit_recipe_actions.dart<br>lib/views/ed... |
| lib/viewmodels/shared_content/shared_content_coordinator_viewmodel.dart | 468 | viewmodel | 14 | lib/core/di/modules/ui_module.dart<br>lib/main_e2e_optimized.dart<br>lib/views/mina_recept_view.dart... |
| lib/widgets/image/image_config.dart | 364 | widget | 14 | lib/services/performance/optimized_image_loader.dart<br>lib/views/recipe_detail/recipe_detail_conten... |
| lib/widgets/user/user_display_widgets.dart | 240 | widget | 14 | lib/views/messaging/create_group_conversation_view.dart<br>lib/views/messaging/group_detail_view.dar... |
| lib/core/cache/json_cache_helper.dart | 314 | core | 15 | lib/services/performance/intelligent_cache_manager.dart<br>lib/services/unified/modules/cache_operat... |
| lib/models/messaging/message.dart | 449 | model | 15 | lib/models/messaging/conversation.dart<br>lib/repositories/firebase/dtos/message_dto.dart<br>lib/rep... |
| lib/models/friend_request.dart | 262 | model | 16 | lib/main_e2e_optimized.dart<br>lib/repositories/firebase/firebase_friends_repository.dart<br>lib/rep... |
| lib/models/group_invitation.dart | 443 | model | 16 | lib/repositories/firebase/firebase_friends_repository.dart<br>lib/repositories/firebase/friends/grou... |
| lib/repositories/firebase/base_firebase_repository.dart | 525 | repository | 16 | lib/repositories/firebase/base_shared_content_repository.dart<br>lib/repositories/firebase/firebase_... |
| lib/core/constants/app_strings.dart | 311 | core | 17 | lib/core/base/base_service.dart<br>lib/core/dialogs/dialog_factory.dart<br>lib/core/errors/contextua... |
| lib/models/messaging/conversation.dart | 490 | model | 17 | lib/repositories/firebase/dtos/conversation_dto.dart<br>lib/repositories/firebase/firebase_messaging... |
| lib/viewmodels/friends_viewmodel.dart | 497 | viewmodel | 18 | lib/core/di/modules/ui_module.dart<br>lib/main_e2e_optimized.dart<br>lib/views/mina_recept_view.dart... |
| lib/services/notifications/notification_types.dart | 371 | service | 19 | lib/repositories/firebase/firebase_notifications_repository.dart<br>lib/repositories/interfaces/noti... |
| lib/core/mixins/async_operation_mixin.dart | 457 | mixin | 21 | lib/services/auth_service.dart<br>lib/viewmodels/account/consent_viewmodel.dart<br>lib/viewmodels/ac... |
| lib/core/mixins/state_notifier_mixin.dart | 440 | mixin | 22 | lib/core/mixins/async_operation_mixin.dart<br>lib/services/auth_service.dart<br>lib/viewmodels/accou... |
| lib/models/shared_menu.dart | 667 | model | 23 | lib/core/router/app_router.dart<br>lib/main_e2e_optimized.dart<br>lib/repositories/firebase/firebase... |
| lib/widgets/common/social_components.dart | 835 | widget | 23 | lib/views/edit_recipe/edit_recipe_app_bar.dart<br>lib/views/edit_recipe/edit_recipe_banners.dart<br>... |
| lib/core/extensions/default_value_extensions.dart | 456 | extension | 24 | lib/models/recipe/recipe_serialization.dart<br>lib/models/recipe_unified.dart<br>lib/models/shared_c... |
| lib/core/exceptions/permission_exceptions.dart | 225 | core | 26 | lib/repositories/firebase/base_firebase_repository.dart<br>lib/repositories/firebase/base_shared_con... |
| lib/repositories/firebase/firebase_auth_repository.dart | 218 | repository | 27 | lib/core/di/modules/content_module.dart<br>lib/core/di/modules/core_module.dart<br>lib/core/router/a... |
| lib/services/user_service.dart | 510 | service | 27 | lib/core/di/modules/social_module.dart<br>lib/core/di/modules/ui_module.dart<br>lib/main_e2e_optimiz... |
| lib/repositories/firestore_repository.dart | 131 | repository | 29 | lib/core/di/modules/collaboration_module.dart<br>lib/core/di/modules/content_module.dart<br>lib/core... |
| lib/core/mixins/stream_management_mixin.dart | 749 | mixin | 30 | lib/repositories/firebase/firebase_recipe_repository.dart<br>lib/repositories/interfaces/recipe_repo... |
| lib/models/unified/unified_shopping_item.dart | 705 | model | 31 | lib/models/shared_shopping_list.dart<br>lib/models/unified/unified_shopping_list.dart<br>lib/reposit... |
| lib/services/unified/unified_shopping_service.dart | 387 | service | 31 | lib/core/di/modules/collaboration_module.dart<br>lib/core/di/modules/social_module.dart<br>lib/core/... |
| lib/core/mixins/error_handling_mixin.dart | 668 | mixin | 33 | lib/core/base/base_service.dart<br>lib/core/errors/contextual_error_engine.dart<br>lib/core/mixins/f... |
| lib/models/permissions/resource_permission.dart | 270 | model | 35 | lib/models/realtime/realtime_menu.dart<br>lib/models/realtime/realtime_menu_factory.dart<br>lib/mode... |
| lib/widgets/common/buttons/action_buttons.dart | 372 | widget | 36 | lib/views/auth_view.dart<br>lib/views/edit_recipe_view.dart<br>lib/views/import_via_url_view.dart<br... |
| lib/core/base/base_service.dart | 494 | core | 37 | lib/services/account/account_deletion_service.dart<br>lib/services/account/consent_service.dart<br>l... |
| lib/widgets/common/state_widget.dart | 444 | widget | 40 | lib/views/auth_view.dart<br>lib/views/edit_recipe_view.dart<br>lib/views/fran_sociala_medier_view.da... |
| lib/models/friend_category.dart | 399 | model | 45 | lib/models/invitations/invitation_target.dart<br>lib/repositories/firebase/firebase_friends_reposito... |
| lib/models/unified/unified_shopping_list.dart | 819 | model | 45 | lib/repositories/firebase/firebase_shopping_repository.dart<br>lib/repositories/firebase/modules/sho... |
| lib/services/unified/unified_recipe_service.dart | 659 | service | 45 | lib/core/di/modules/content_module.dart<br>lib/core/di/modules/social_module.dart<br>lib/core/di/mod... |
| lib/services/unified/unified_friends_service.dart | 485 | service | 47 | lib/core/di/modules/social_module.dart<br>lib/core/di/modules/ui_module.dart<br>lib/services/perform... |
| lib/services/permission_service.dart | 292 | service | 54 | lib/core/di/modules/collaboration_module.dart<br>lib/core/di/modules/social_module.dart<br>lib/servi... |
| lib/repositories/interfaces/auth_repository.dart | 43 | repository | 57 | lib/core/base/base_service.dart<br>lib/core/di/modules/collaboration_module.dart<br>lib/core/di/modu... |
| lib/models/user_profile.dart | 310 | model | 83 | lib/core/router/app_router.dart<br>lib/main_e2e_optimized.dart<br>lib/models/invitations/invitation_... |
| lib/core/providers/application_provider.dart | 413 | core | 150 | lib/core/base/base_service.dart<br>lib/core/bootstrap/application_bootstrap.dart<br>lib/core/utils/c... |
| lib/models/recipe_unified.dart | 910 | model | 150 | lib/core/router/app_router.dart<br>lib/data/recipes/recipe_seeds.dart<br>lib/models/realtime/realtim... |
| lib/theme/app_text_styles.dart | 203 | other | 171 | lib/core/router/app_router.dart<br>lib/core/utils/common_dialog_actions.dart<br>lib/theme/app_theme.... |
| lib/theme/app_colors.dart | 166 | other | 196 | lib/core/base/base_action_handler.dart<br>lib/core/dialogs/dialog_factory.dart<br>lib/core/router/ap... |
| lib/theme/app_dimensions.dart | 391 | other | 243 | lib/core/base/base_action_handler.dart<br>lib/core/dialogs/dialog_factory.dart<br>lib/core/router/ap... |
| lib/core/utils/logger.dart | 429 | utility | 285 | lib/core/base/base_action_handler.dart<br>lib/core/base/base_service.dart<br>lib/core/bootstrap/appl... |

---

## Layer-Specific Breakdowns

### Core Layer (40 files)

| File Path | LOC | Usage | Dependents |
|-----------|-----|-------|------------|
| lib/core/config/feature_flags.dart ⚠️ UNUSED | 161 | 0 | 0 files |
| lib/core/config/firebase_config.dart ⚠️ UNUSED | 160 | 0 | 0 files |
| lib/core/error/failures.dart ⚠️ UNUSED | 284 | 0 | 0 files |
| lib/core/bootstrap/handlers/deep_link_handler.dart 🔍 LOW | 271 | 1 | 1 files |
| lib/core/errors/contextual_error_engine.dart 🔍 LOW | 356 | 1 | 1 files |
| lib/core/errors/unified_error_coordinator.dart 🔍 LOW | 448 | 1 | 1 files |
| lib/core/form/form_fields_manager.dart 🔍 LOW | 492 | 1 | 1 files |
| lib/core/observers/performance_navigator_observer.dart 🔍 LOW | 215 | 1 | 1 files |
| lib/core/observers/snackbar_route_observer.dart 🔍 LOW | 89 | 1 | 1 files |
| lib/core/base/base_action_handler.dart 🔍 LOW | 383 | 2 | 2 files |
| lib/core/rate_limiting/rate_limiter.dart 🔍 LOW | 408 | 2 | 2 files |
| lib/core/di/di_container.dart 🔍 LOW | 425 | 3 | 3 files |
| lib/core/router/app_router.dart 🔍 LOW | 416 | 3 | 3 files |
| lib/core/bootstrap/stages/content_stage.dart | 73 | 4 | 4 files |
| lib/core/bootstrap/stages/core_stage.dart | 72 | 4 | 4 files |
| lib/core/bootstrap/stages/platform_stage.dart | 77 | 4 | 4 files |
| lib/core/bootstrap/stages/social_stage.dart | 91 | 4 | 4 files |
| lib/core/bootstrap/stages/ui_stage.dart | 119 | 4 | 4 files |
| lib/core/di/modules/performance_module.dart | 160 | 4 | 4 files |
| lib/core/di/modules/ui_module.dart | 376 | 4 | 4 files |
| lib/core/exceptions/repository_exception.dart | 14 | 4 | 4 files |
| lib/core/bootstrap/application_bootstrap.dart | 489 | 5 | 5 files |
| lib/core/events/group_events.dart | 30 | 5 | 5 files |
| lib/core/bootstrap/stages/bootstrap_stage.dart | 156 | 6 | 6 files |
| lib/core/di/interfaces/service_health.dart | 198 | 6 | 6 files |
| lib/core/di/modules/collaboration_module.dart | 306 | 6 | 6 files |
| lib/core/di/modules/messaging_module.dart | 219 | 6 | 6 files |
| lib/core/dialogs/dialog_factory.dart | 200 | 6 | 6 files |
| lib/core/validators/form_validators.dart | 445 | 6 | 6 files |
| lib/core/di/modules/social_module.dart | 292 | 8 | 8 files |
| lib/core/di/interfaces/di_module.dart | 120 | 9 | 9 files |
| lib/core/di/modules/content_module.dart | 340 | 9 | 9 files |
| lib/core/types/app_timestamp.dart | 240 | 9 | 9 files |
| lib/core/constants/routes.dart | 274 | 10 | 10 files |
| lib/core/di/modules/core_module.dart | 290 | 14 | 14 files |
| lib/core/cache/json_cache_helper.dart | 314 | 15 | 15 files |
| lib/core/constants/app_strings.dart | 311 | 17 | 17 files |
| lib/core/exceptions/permission_exceptions.dart | 225 | 26 | 26 files |
| lib/core/base/base_service.dart | 494 | 37 | 37 files |
| lib/core/providers/application_provider.dart | 413 | 150 | 150 files |

### Data Layer (2 files)

| File Path | LOC | Usage | Dependents |
|-----------|-----|-------|------------|
| lib/data/recipes/recipe_seeds.dart 🔍 LOW | 231 | 1 | 1 files |
| lib/data/archived_recipes.dart 🔍 LOW | 8 | 2 | 2 files |

### Extension Layer (1 files)

| File Path | LOC | Usage | Dependents |
|-----------|-----|-------|------------|
| lib/core/extensions/default_value_extensions.dart | 456 | 24 | 24 files |

### Mixin Layer (8 files)

| File Path | LOC | Usage | Dependents |
|-----------|-----|-------|------------|
| lib/core/mixins/firebase_sync_mixin.dart 🔍 LOW | 218 | 1 | 1 files |
| lib/core/mixins/firebase_service_mixin.dart | 888 | 4 | 4 files |
| lib/core/mixins/json_serializable_mixin.dart | 654 | 4 | 4 files |
| lib/core/mixins/singleton_service_mixin.dart | 340 | 8 | 8 files |
| lib/core/mixins/async_operation_mixin.dart | 457 | 21 | 21 files |
| lib/core/mixins/state_notifier_mixin.dart | 440 | 22 | 22 files |
| lib/core/mixins/stream_management_mixin.dart | 749 | 30 | 30 files |
| lib/core/mixins/error_handling_mixin.dart | 668 | 33 | 33 files |

### Model Layer (49 files)

| File Path | LOC | Usage | Dependents |
|-----------|-----|-------|------------|
| lib/models/recipe_unified.g.dart ⚠️ UNUSED | 104 | 0 | 0 files |
| lib/models/social/reactions.dart ⚠️ UNUSED | 35 | 0 | 0 files |
| lib/models/audit_log.dart 🔍 LOW | 154 | 1 | 1 files |
| lib/models/messaging/message_type.dart 🔍 LOW | 247 | 1 | 1 files |
| lib/models/realtime/realtime_menu_analytics.dart 🔍 LOW | 255 | 1 | 1 files |
| lib/models/realtime/realtime_menu_factory.dart 🔍 LOW | 175 | 1 | 1 files |
| lib/models/realtime/realtime_menu_operations.dart 🔍 LOW | 291 | 1 | 1 files |
| lib/models/realtime/realtime_participants.dart 🔍 LOW | 381 | 1 | 1 files |
| lib/models/realtime/recipe_operations.dart 🔍 LOW | 339 | 1 | 1 files |
| lib/models/realtime/recipe_serialization.dart 🔍 LOW | 342 | 1 | 1 files |
| lib/models/recipe/recipe_operations.dart 🔍 LOW | 418 | 1 | 1 files |
| lib/models/recipe/recipe_serialization.dart 🔍 LOW | 328 | 1 | 1 files |
| lib/models/social/activity_engagement.dart 🔍 LOW | 94 | 1 | 1 files |
| lib/models/social/activity_type.dart 🔍 LOW | 71 | 1 | 1 files |
| lib/models/social/content_reaction.dart 🔍 LOW | 193 | 1 | 1 files |
| lib/models/social/reaction_statistics.dart 🔍 LOW | 266 | 1 | 1 files |
| lib/models/realtime/live_editor.dart 🔍 LOW | 264 | 2 | 2 files |
| lib/models/recipe/recipe_factory.dart 🔍 LOW | 441 | 2 | 2 files |
| lib/models/shared_content/copy_on_write_mixin.dart 🔍 LOW | 274 | 2 | 2 files |
| lib/models/account/user_consent.dart 🔍 LOW | 184 | 3 | 3 files |
| lib/models/recipe_change.dart 🔍 LOW | 175 | 3 | 3 files |
| lib/models/shared_content/shared_content_status_mixin.dart 🔍 LOW | 211 | 3 | 3 files |
| lib/models/social/reaction_type.dart 🔍 LOW | 76 | 3 | 3 files |
| lib/models/social/social_comment.dart 🔍 LOW | 288 | 3 | 3 files |
| lib/models/realtime/realtime_menu_data.dart | 265 | 4 | 4 files |
| lib/models/recommendation.dart | 129 | 4 | 4 files |
| lib/models/social/activity_feed.dart | 37 | 4 | 4 files |
| lib/models/social/activity_feed_item.dart | 346 | 4 | 4 files |
| lib/models/shared_content/base_shared_content_model.dart | 313 | 5 | 5 files |
| lib/models/shared_shopping_list.dart | 456 | 7 | 7 files |
| lib/models/realtime/realtime_recipe.dart | 397 | 9 | 9 files |
| lib/models/realtime/realtime_resource.dart | 499 | 9 | 9 files |
| lib/models/permissions/edit_mode.dart | 146 | 10 | 10 files |
| lib/models/recipe_comment.dart | 436 | 10 | 10 files |
| lib/models/shared_content.dart | 289 | 11 | 11 files |
| lib/models/realtime/realtime_menu.dart | 696 | 13 | 13 files |
| lib/models/shared_recipe.dart | 487 | 13 | 13 files |
| lib/models/invitations/invitation_target.dart | 746 | 14 | 14 files |
| lib/models/messaging/message.dart | 449 | 15 | 15 files |
| lib/models/friend_request.dart | 262 | 16 | 16 files |
| lib/models/group_invitation.dart | 443 | 16 | 16 files |
| lib/models/messaging/conversation.dart | 490 | 17 | 17 files |
| lib/models/shared_menu.dart | 667 | 23 | 23 files |
| lib/models/unified/unified_shopping_item.dart | 705 | 31 | 31 files |
| lib/models/permissions/resource_permission.dart | 270 | 35 | 35 files |
| lib/models/friend_category.dart | 399 | 45 | 45 files |
| lib/models/unified/unified_shopping_list.dart | 819 | 45 | 45 files |
| lib/models/user_profile.dart | 310 | 83 | 83 files |
| lib/models/recipe_unified.dart | 910 | 150 | 150 files |

### Other Layer (29 files)

| File Path | LOC | Usage | Dependents |
|-----------|-----|-------|------------|
| lib/main_e2e_emulator.dart ⚠️ UNUSED | 271 | 0 | 0 files |
| lib/main_e2e_mock.dart ⚠️ UNUSED | 200 | 0 | 0 files |
| lib/main_e2e_optimized.dart ⚠️ UNUSED | 732 | 0 | 0 files |
| lib/main_e2e_staging.dart ⚠️ UNUSED | 284 | 0 | 0 files |
| lib/utils/performance_monitor.dart ⚠️ UNUSED | 95 | 0 | 0 files |
| lib/constants/known_ingredients.dart 🔍 LOW | 569 | 1 | 1 files |
| lib/constants/preparation_words.dart 🔍 LOW | 246 | 1 | 1 files |
| lib/theme/components/button_themes.dart 🔍 LOW | 221 | 1 | 1 files |
| lib/theme/components/feedback_themes.dart 🔍 LOW | 109 | 1 | 1 files |
| lib/theme/components/input_themes.dart 🔍 LOW | 148 | 1 | 1 files |
| lib/theme/components/navigation_themes.dart 🔍 LOW | 97 | 1 | 1 files |
| lib/utils/social_content_features.dart 🔍 LOW | 322 | 1 | 1 files |
| lib/utils/text/ingredient_normalizer.dart 🔍 LOW | 315 | 1 | 1 files |
| lib/utils/text/ingredient_preprocessor.dart 🔍 LOW | 330 | 1 | 1 files |
| lib/utils/text/shopping_list_generator.dart 🔍 LOW | 357 | 1 | 1 files |
| lib/theme/app_theme.dart 🔍 LOW | 85 | 2 | 2 files |
| lib/utils/recipe_scraper.dart 🔍 LOW | 194 | 2 | 2 files |
| lib/firebase_options.dart 🔍 LOW | 89 | 3 | 3 files |
| lib/main.dart 🔍 LOW | 612 | 3 | 3 files |
| lib/theme/theme_constants.dart 🔍 LOW | 173 | 3 | 3 files |
| lib/utils/text/ingredient_parser.dart 🔍 LOW | 792 | 3 | 3 files |
| lib/utils/text/unit_converter.dart 🔍 LOW | 283 | 3 | 3 files |
| lib/utils/text/ingredient_processor.dart | 427 | 4 | 4 files |
| lib/utils/text/swedish_pluralization.dart | 484 | 4 | 4 files |
| lib/utils/text/text_formatting.dart | 318 | 4 | 4 files |
| lib/theme/component_themes.dart | 71 | 6 | 6 files |
| lib/theme/app_text_styles.dart | 203 | 171 | 171 files |
| lib/theme/app_colors.dart | 166 | 196 | 196 files |
| lib/theme/app_dimensions.dart | 391 | 243 | 243 files |

### Repository Layer (62 files)

| File Path | LOC | Usage | Dependents |
|-----------|-----|-------|------------|
| lib/repositories/interfaces/reactions_repository.dart ⚠️ UNUSED | 125 | 0 | 0 files |
| lib/repositories/mock/in_memory_repository.dart ⚠️ UNUSED | 254 | 0 | 0 files |
| lib/repositories/firebase/firebase_comments_repository.dart 🔍 LOW | 407 | 1 | 1 files |
| lib/repositories/firebase/firebase_connectivity_repository.dart 🔍 LOW | 229 | 1 | 1 files |
| lib/repositories/firebase/firebase_deeplink_repository.dart 🔍 LOW | 271 | 1 | 1 files |
| lib/repositories/firebase/firebase_menu_collaboration_repository.dart 🔍 LOW | 697 | 1 | 1 files |
| lib/repositories/firebase/firebase_messaging_repository.dart 🔍 LOW | 379 | 1 | 1 files |
| lib/repositories/firebase/firebase_notifications_repository.dart 🔍 LOW | 412 | 1 | 1 files |
| lib/repositories/firebase/firebase_recipe_repository.dart 🔍 LOW | 871 | 1 | 1 files |
| lib/repositories/firebase/firebase_shopping_repository.dart 🔍 LOW | 424 | 1 | 1 files |
| lib/repositories/firebase/firebase_social_recipe_repository.dart 🔍 LOW | 518 | 1 | 1 files |
| lib/repositories/firebase/firebase_social_sharing_repository.dart 🔍 LOW | 422 | 1 | 1 files |
| lib/repositories/firebase/firebase_storage_repository.dart 🔍 LOW | 590 | 1 | 1 files |
| lib/repositories/firebase/firebase_user_repository.dart 🔍 LOW | 509 | 1 | 1 files |
| lib/repositories/firebase/friends/friend_request_repository.dart 🔍 LOW | 396 | 1 | 1 files |
| lib/repositories/firebase/friends/group_invitation_repository.dart 🔍 LOW | 471 | 1 | 1 files |
| lib/repositories/firebase/modules/conversation_auto_healer_module.dart 🔍 LOW | 96 | 1 | 1 files |
| lib/repositories/firebase/modules/conversation_mutation_module.dart 🔍 LOW | 324 | 1 | 1 files |
| lib/repositories/firebase/modules/conversation_query_module.dart 🔍 LOW | 108 | 1 | 1 files |
| lib/repositories/firebase/modules/message_mutation_module.dart 🔍 LOW | 353 | 1 | 1 files |
| lib/repositories/firebase/modules/message_query_module.dart 🔍 LOW | 113 | 1 | 1 files |
| lib/repositories/firebase/modules/shopping_item_operations_module.dart 🔍 LOW | 256 | 1 | 1 files |
| lib/repositories/firebase/modules/shopping_repository_query_module.dart 🔍 LOW | 143 | 1 | 1 files |
| lib/repositories/firebase/modules/shopping_repository_routing_module.dart 🔍 LOW | 120 | 1 | 1 files |
| lib/repositories/firebase/modules/shopping_template_operations_module.dart 🔍 LOW | 263 | 1 | 1 files |
| lib/repositories/interfaces/activity_repository.dart 🔍 LOW | 178 | 1 | 1 files |
| lib/repositories/firebase/firebase_analytics_repository.dart 🔍 LOW | 368 | 2 | 2 files |
| lib/repositories/firebase/firebase_consent_repository.dart 🔍 LOW | 248 | 2 | 2 files |
| lib/repositories/firebase/firebase_ratings_repository.dart 🔍 LOW | 414 | 2 | 2 files |
| lib/repositories/firebase/friends/friend_relationship_repository.dart 🔍 LOW | 293 | 2 | 2 files |
| lib/repositories/interfaces/friends_repository.dart 🔍 LOW | 161 | 2 | 2 files |
| lib/repositories/collaborative_recipe_repository.dart 🔍 LOW | 310 | 3 | 3 files |
| lib/repositories/firebase/dtos/conversation_dto.dart 🔍 LOW | 124 | 3 | 3 files |
| lib/repositories/firebase/firebase_recipe_presence_repository.dart 🔍 LOW | 214 | 3 | 3 files |
| lib/repositories/firebase/firebase_shared_recipe_repository.dart 🔍 LOW | 301 | 3 | 3 files |
| lib/repositories/interfaces/analytics_repository.dart 🔍 LOW | 114 | 3 | 3 files |
| lib/repositories/interfaces/deeplink_repository.dart 🔍 LOW | 21 | 3 | 3 files |
| lib/repositories/interfaces/social_recipe_repository.dart 🔍 LOW | 31 | 3 | 3 files |
| lib/repositories/interfaces/storage_repository.dart 🔍 LOW | 136 | 3 | 3 files |
| lib/repositories/firebase/dtos/message_dto.dart | 161 | 4 | 4 files |
| lib/repositories/firebase/firebase_friends_repository.dart | 437 | 4 | 4 files |
| lib/repositories/firebase/firebase_shared_menu_repository.dart | 260 | 4 | 4 files |
| lib/repositories/firebase/firebase_shared_shopping_repository.dart | 261 | 4 | 4 files |
| lib/repositories/firebase/friends/friend_category_repository.dart | 398 | 4 | 4 files |
| lib/repositories/interfaces/connectivity_repository.dart | 27 | 4 | 4 files |
| lib/repositories/interfaces/menu_collaboration_repository.dart | 212 | 4 | 4 files |
| lib/repositories/mixins/permission_validation_mixin.dart | 487 | 4 | 4 files |
| lib/repositories/interfaces/social_sharing_repository.dart | 36 | 5 | 5 files |
| lib/repositories/interfaces/user_repository.dart | 94 | 5 | 5 files |
| lib/repositories/firebase/base_shared_content_repository.dart | 459 | 6 | 6 files |

*...and 12 more files*

### Service Layer (188 files)

| File Path | LOC | Usage | Dependents |
|-----------|-----|-------|------------|
| lib/services/dialog_service.dart ⚠️ UNUSED | 231 | 0 | 0 files |
| lib/services/social/activity_service.dart ⚠️ UNUSED | 444 | 0 | 0 files |
| lib/services/unified/friends_cache.dart ⚠️ UNUSED | 5 | 0 | 0 files |
| lib/services/unified/modules/shopping_operations.dart ⚠️ UNUSED | 10 | 0 | 0 files |
| lib/services/account/account_deletion/content_deletion_operations.dart 🔍 LOW | 80 | 1 | 1 files |
| lib/services/account/account_deletion/profile_deletion_operations.dart 🔍 LOW | 65 | 1 | 1 files |
| lib/services/account/account_deletion/social_deletion_operations.dart 🔍 LOW | 198 | 1 | 1 files |
| lib/services/account/account_deletion/storage_deletion_operations.dart 🔍 LOW | 89 | 1 | 1 files |
| lib/services/deep_link_service.dart 🔍 LOW | 502 | 1 | 1 files |
| lib/services/extraction/extraction_manager.dart 🔍 LOW | 164 | 1 | 1 files |
| lib/services/extraction/extractors/instagram_content_extractor.dart 🔍 LOW | 167 | 1 | 1 files |
| lib/services/extraction/extractors/recipe_site_content_extractor.dart 🔍 LOW | 213 | 1 | 1 files |
| lib/services/extraction/extractors/social_platform_content_extractor.dart 🔍 LOW | 108 | 1 | 1 files |
| lib/services/extraction/site_parsers/arla_recipe_parser.dart 🔍 LOW | 345 | 1 | 1 files |
| lib/services/extraction/site_parsers/ica_recipe_parser.dart 🔍 LOW | 443 | 1 | 1 files |
| lib/services/extraction/site_parsers/koket_recipe_parser.dart 🔍 LOW | 351 | 1 | 1 files |
| lib/services/extraction/site_parsers/recept_recipe_parser.dart 🔍 LOW | 353 | 1 | 1 files |
| lib/services/extraction/site_parsers/recipe_quality_scorer.dart 🔍 LOW | 227 | 1 | 1 files |
| lib/services/image_picker_provider.dart 🔍 LOW | 106 | 1 | 1 files |
| lib/services/import/archive_import_strategy.dart 🔍 LOW | 271 | 1 | 1 files |
| lib/services/import/file_content_provider.dart 🔍 LOW | 81 | 1 | 1 files |
| lib/services/import/photo_import_strategy.dart 🔍 LOW | 321 | 1 | 1 files |
| lib/services/import/url_import_strategy.dart 🔍 LOW | 479 | 1 | 1 files |
| lib/services/messaging/conversation_action_operations.dart 🔍 LOW | 203 | 1 | 1 files |
| lib/services/messaging/message_management_operations.dart 🔍 LOW | 259 | 1 | 1 files |
| lib/services/messaging/message_sending_operations.dart 🔍 LOW | 302 | 1 | 1 files |
| lib/services/messaging_media_service.dart 🔍 LOW | 269 | 1 | 1 files |
| lib/services/notifications/fcm_service.dart 🔍 LOW | 430 | 1 | 1 files |
| lib/services/notifications/modules/fcm_token_manager.dart 🔍 LOW | 498 | 1 | 1 files |
| lib/services/notifications/modules/notification_analytics_manager.dart 🔍 LOW | 492 | 1 | 1 files |
| lib/services/notifications/modules/notification_batch_manager.dart 🔍 LOW | 472 | 1 | 1 files |
| lib/services/notifications/modules/notification_content_manager.dart 🔍 LOW | 406 | 1 | 1 files |
| lib/services/notifications/modules/notification_offline_manager.dart 🔍 LOW | 422 | 1 | 1 files |
| lib/services/notifications/modules/notification_preference_manager.dart 🔍 LOW | 425 | 1 | 1 files |
| lib/services/offline/offline_initialization.dart 🔍 LOW | 117 | 1 | 1 files |
| lib/services/offline/offline_sync_manager.dart 🔍 LOW | 210 | 1 | 1 files |
| lib/services/offline/offline_user_storage.dart 🔍 LOW | 131 | 1 | 1 files |
| lib/services/performance/intelligent_cache_manager.dart 🔍 LOW | 485 | 1 | 1 files |
| lib/services/performance/optimized_image_loader.dart 🔍 LOW | 489 | 1 | 1 files |
| lib/services/performance/performance_monitoring_service.dart 🔍 LOW | 484 | 1 | 1 files |
| lib/services/performance/startup_optimization_manager.dart 🔍 LOW | 447 | 1 | 1 files |
| lib/services/permissions/group_permission_module.dart 🔍 LOW | 99 | 1 | 1 files |
| lib/services/permissions/recipe_permission_module.dart 🔍 LOW | 285 | 1 | 1 files |
| lib/services/permissions/shopping_permission_module.dart 🔍 LOW | 225 | 1 | 1 files |
| lib/services/persistence_service.dart 🔍 LOW | 315 | 1 | 1 files |
| lib/services/realtime/conflict_resolution_module.dart 🔍 LOW | 105 | 1 | 1 files |
| lib/services/realtime/connection_state_module.dart 🔍 LOW | 108 | 1 | 1 files |
| lib/services/realtime/modules/menu_participants.dart 🔍 LOW | 336 | 1 | 1 files |
| lib/services/realtime/modules/recipe_participants.dart 🔍 LOW | 401 | 1 | 1 files |
| lib/services/realtime/realtime_recipe_service.dart 🔍 LOW | 500 | 1 | 1 files |

*...and 138 more files*

### Utility Layer (8 files)

| File Path | LOC | Usage | Dependents |
|-----------|-----|-------|------------|
| lib/core/utils/service_optimizer.dart ⚠️ UNUSED | 398 | 0 | 0 files |
| lib/core/utils/retry_helper.dart 🔍 LOW | 435 | 1 | 1 files |
| lib/core/utils/connectivity_check.dart 🔍 LOW | 494 | 3 | 3 files |
| lib/core/utils/common_dialog_actions.dart | 367 | 6 | 6 files |
| lib/core/utils/serialization_utils.dart | 370 | 10 | 10 files |
| lib/core/utils/validation_utils.dart | 383 | 12 | 12 files |
| lib/core/utils/snackbar_utils.dart | 342 | 13 | 13 files |
| lib/core/utils/logger.dart | 429 | 285 | 285 files |

### Viewmodel Layer (88 files)

| File Path | LOC | Usage | Dependents |
|-----------|-----|-------|------------|
| lib/viewmodels/add_members_to_group/member_search_manager.dart 🔍 LOW | 47 | 1 | 1 files |
| lib/viewmodels/add_members_to_group/member_selection_manager.dart 🔍 LOW | 59 | 1 | 1 files |
| lib/viewmodels/add_members_to_group_viewmodel.dart 🔍 LOW | 304 | 1 | 1 files |
| lib/viewmodels/archive/archive_import_operations_manager.dart 🔍 LOW | 100 | 1 | 1 files |
| lib/viewmodels/archive/archive_search_manager.dart 🔍 LOW | 127 | 1 | 1 files |
| lib/viewmodels/archive/archive_selection_manager.dart 🔍 LOW | 57 | 1 | 1 files |
| lib/viewmodels/base_viewmodel.dart 🔍 LOW | 478 | 1 | 1 files |
| lib/viewmodels/collaborative_shopping/shopping_display_manager.dart 🔍 LOW | 84 | 1 | 1 files |
| lib/viewmodels/collaborative_shopping/shopping_item_operations_manager.dart 🔍 LOW | 112 | 1 | 1 files |
| lib/viewmodels/collaborative_shopping/shopping_permission_manager.dart 🔍 LOW | 32 | 1 | 1 files |
| lib/viewmodels/conversations_viewmodel.dart 🔍 LOW | 232 | 1 | 1 files |
| lib/viewmodels/create_group_conversation_viewmodel.dart 🔍 LOW | 279 | 1 | 1 files |
| lib/viewmodels/create_group_viewmodel.dart 🔍 LOW | 472 | 1 | 1 files |
| lib/viewmodels/discovery_dashboard/discovery_content_manager.dart 🔍 LOW | 251 | 1 | 1 files |
| lib/viewmodels/discovery_dashboard/discovery_friend_activity_manager.dart 🔍 LOW | 167 | 1 | 1 files |
| lib/viewmodels/discovery_dashboard/discovery_recommendations_manager.dart 🔍 LOW | 274 | 1 | 1 files |
| lib/viewmodels/friends/friends_profile_cache_manager.dart 🔍 LOW | 126 | 1 | 1 files |
| lib/viewmodels/friends/friends_search_manager.dart 🔍 LOW | 143 | 1 | 1 files |
| lib/viewmodels/friends/friends_selection_manager.dart 🔍 LOW | 74 | 1 | 1 files |
| lib/viewmodels/group_detail_viewmodel.dart 🔍 LOW | 446 | 1 | 1 files |
| lib/viewmodels/group_recipe_selection_viewmodel.dart 🔍 LOW | 223 | 1 | 1 files |
| lib/viewmodels/menu/menu_generator.dart 🔍 LOW | 166 | 1 | 1 files |
| lib/viewmodels/menu/menu_social_manager.dart 🔍 LOW | 259 | 1 | 1 files |
| lib/viewmodels/realtime/connection_monitor.dart 🔍 LOW | 194 | 1 | 1 files |
| lib/viewmodels/realtime_menu/realtime_menu_operations.dart 🔍 LOW | 380 | 1 | 1 files |
| lib/viewmodels/realtime_menu/realtime_menu_state.dart 🔍 LOW | 235 | 1 | 1 files |
| lib/viewmodels/realtime_menu/realtime_participant_manager.dart 🔍 LOW | 381 | 1 | 1 files |
| lib/viewmodels/realtime_menu/realtime_stream_manager.dart 🔍 LOW | 225 | 1 | 1 files |
| lib/viewmodels/recipe/personal_recipe_viewmodel.dart 🔍 LOW | 328 | 1 | 1 files |
| lib/viewmodels/recipe/realtime_recipe_viewmodel.dart 🔍 LOW | 439 | 1 | 1 files |
| lib/viewmodels/recipe/recipe_query_viewmodel.dart 🔍 LOW | 487 | 1 | 1 files |
| lib/viewmodels/recipe_form/image_management/image_upload_coordinator.dart 🔍 LOW | 448 | 1 | 1 files |
| lib/viewmodels/recipe_form/image_management/image_upload_notification_manager.dart 🔍 LOW | 185 | 1 | 1 files |
| lib/viewmodels/recipe_form/image_management/image_upload_validator.dart 🔍 LOW | 173 | 1 | 1 files |
| lib/viewmodels/recipe_form/image_management/upload_queue_summary_calculator.dart 🔍 LOW | 223 | 1 | 1 files |
| lib/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart 🔍 LOW | 283 | 1 | 1 files |
| lib/viewmodels/recipe_selection_viewmodel.dart 🔍 LOW | 444 | 1 | 1 files |
| lib/viewmodels/shared_content/shared_content_search_viewmodel.dart 🔍 LOW | 495 | 1 | 1 files |
| lib/viewmodels/shared_content/social_sharing_viewmodel.dart 🔍 LOW | 467 | 1 | 1 files |
| lib/viewmodels/shopping/shopping_analytics_manager.dart 🔍 LOW | 65 | 1 | 1 files |
| lib/viewmodels/shopping/shopping_item_operations_manager.dart 🔍 LOW | 78 | 1 | 1 files |
| lib/viewmodels/shopping_share_viewmodel.dart 🔍 LOW | 473 | 1 | 1 files |
| lib/viewmodels/social_group_detail_viewmodel.dart 🔍 LOW | 395 | 1 | 1 files |
| lib/viewmodels/social_recipe/social_comments_manager.dart 🔍 LOW | 179 | 1 | 1 files |
| lib/viewmodels/social_recipe/social_engagement_manager.dart 🔍 LOW | 35 | 1 | 1 files |
| lib/viewmodels/social_recipe/social_profile_manager.dart 🔍 LOW | 58 | 1 | 1 files |
| lib/viewmodels/unified_recipe_viewmodel.dart 🔍 LOW | 286 | 1 | 1 files |
| lib/viewmodels/account/consent_viewmodel.dart 🔍 LOW | 268 | 2 | 2 files |
| lib/viewmodels/account/data_export_viewmodel.dart 🔍 LOW | 158 | 2 | 2 files |
| lib/viewmodels/archive_import_viewmodel.dart 🔍 LOW | 125 | 2 | 2 files |

*...and 38 more files*

### Widget Layer (287 files)

| File Path | LOC | Usage | Dependents |
|-----------|-----|-------|------------|
| lib/views/realtime/handlers/menu_action_handler.dart ⚠️ UNUSED | 296 | 0 | 0 files |
| lib/views/social/group_content_feed/group_activity_timeline.dart ⚠️ UNUSED | 346 | 0 | 0 files |
| lib/views/social/group_content_feed/group_content_app_bar.dart ⚠️ UNUSED | 390 | 0 | 0 files |
| lib/views/social/group_content_feed/group_content_lists.dart ⚠️ UNUSED | 229 | 0 | 0 files |
| lib/views/social/group_content_feed/group_content_search_bar.dart ⚠️ UNUSED | 162 | 0 | 0 files |
| lib/views/social/group_content_feed/group_content_tab_bar.dart ⚠️ UNUSED | 187 | 0 | 0 files |
| lib/views/social/group_invitations_view.dart ⚠️ UNUSED | 354 | 0 | 0 files |
| lib/widgets/image/image_source_picker.dart ⚠️ UNUSED | 119 | 0 | 0 files |
| lib/widgets/recipe/recipe_detail_comments.dart ⚠️ UNUSED | 246 | 0 | 0 files |
| lib/widgets/recipe/recipe_detail_metadata.dart ⚠️ UNUSED | 270 | 0 | 0 files |
| lib/widgets/social/activity_feed_item_widget.dart ⚠️ UNUSED | 482 | 0 | 0 files |
| lib/widgets/social/groups/friend_category_widgets.dart ⚠️ UNUSED | 39 | 0 | 0 files |
| lib/widgets/styled/styled_container.dart ⚠️ UNUSED | 199 | 0 | 0 files |
| lib/views/account/consent_management_view.dart 🔍 LOW | 494 | 1 | 1 files |
| lib/views/account/data_export_view.dart 🔍 LOW | 447 | 1 | 1 files |
| lib/views/edit_recipe/edit_recipe_actions.dart 🔍 LOW | 63 | 1 | 1 files |
| lib/views/edit_recipe/edit_recipe_app_bar.dart 🔍 LOW | 49 | 1 | 1 files |
| lib/views/edit_recipe/edit_recipe_banners.dart 🔍 LOW | 81 | 1 | 1 files |
| lib/views/edit_recipe/edit_recipe_bottom_bar.dart 🔍 LOW | 52 | 1 | 1 files |
| lib/views/edit_recipe/edit_recipe_dynamic_list.dart 🔍 LOW | 70 | 1 | 1 files |
| lib/views/edit_recipe/edit_recipe_form_fields.dart 🔍 LOW | 188 | 1 | 1 files |
| lib/views/edit_recipe/edit_recipe_image_picker.dart 🔍 LOW | 77 | 1 | 1 files |
| lib/views/edit_recipe_view.dart 🔍 LOW | 354 | 1 | 1 files |
| lib/views/file_import_view.dart 🔍 LOW | 286 | 1 | 1 files |
| lib/views/fran_sociala_medier_view.dart 🔍 LOW | 408 | 1 | 1 files |
| lib/views/import_via_url_view.dart 🔍 LOW | 157 | 1 | 1 files |
| lib/views/importera_fran_arkiv_view.dart 🔍 LOW | 332 | 1 | 1 files |
| lib/views/lagg_till_recept_view.dart 🔍 LOW | 178 | 1 | 1 files |
| lib/views/legal/privacy_policy_view.dart 🔍 LOW | 286 | 1 | 1 files |
| lib/views/messaging/chat_view/chat_action_handler.dart 🔍 LOW | 459 | 1 | 1 files |
| lib/views/messaging/chat_view/chat_input_section.dart 🔍 LOW | 268 | 1 | 1 files |
| lib/views/messaging/chat_view/chat_message_stream.dart 🔍 LOW | 246 | 1 | 1 files |
| lib/views/messaging/conversations_list_view.dart 🔍 LOW | 459 | 1 | 1 files |
| lib/views/messaging/create_group_conversation_view.dart 🔍 LOW | 371 | 1 | 1 files |
| lib/views/messaging/group_detail_view.dart 🔍 LOW | 580 | 1 | 1 files |
| lib/views/photo_import_view.dart 🔍 LOW | 397 | 1 | 1 files |
| lib/views/receive_share_view.dart 🔍 LOW | 495 | 1 | 1 files |
| lib/views/recipe_detail/handlers/recipe_management_handler.dart 🔍 LOW | 104 | 1 | 1 files |
| lib/views/recipe_detail/handlers/recipe_shopping_handler.dart 🔍 LOW | 176 | 1 | 1 files |
| lib/views/recipe_detail/handlers/recipe_social_handler.dart 🔍 LOW | 122 | 1 | 1 files |
| lib/views/recipe_detail/recipe_detail_actions.dart 🔍 LOW | 203 | 1 | 1 files |
| lib/views/recipe_detail/recipe_detail_comments.dart 🔍 LOW | 758 | 1 | 1 files |
| lib/views/recipe_detail/recipe_detail_content.dart 🔍 LOW | 311 | 1 | 1 files |
| lib/views/recipe_detail/recipe_detail_metadata.dart 🔍 LOW | 419 | 1 | 1 files |
| lib/views/recipe_detail_view.dart 🔍 LOW | 366 | 1 | 1 files |
| lib/views/social/collaborative_shopping/collaborative_shopping_actions.dart 🔍 LOW | 386 | 1 | 1 files |
| lib/views/social/collaborative_shopping/collaborative_shopping_header.dart 🔍 LOW | 247 | 1 | 1 files |
| lib/views/social/collaborative_shopping/collaborative_shopping_items.dart 🔍 LOW | 248 | 1 | 1 files |
| lib/views/social/collaborative_shopping_view.dart 🔍 LOW | 273 | 1 | 1 files |
| lib/views/social/create_shared_shopping_list_view.dart 🔍 LOW | 345 | 1 | 1 files |

*...and 237 more files*

---

## Top 30 Most-Used Files (Core Infrastructure)

| Rank | File Path | LOC | Layer | Usage Count |
|------|-----------|-----|-------|-------------|
| 1 | lib/core/utils/logger.dart | 429 | utility | 285 |
| 2 | lib/theme/app_dimensions.dart | 391 | other | 243 |
| 3 | lib/theme/app_colors.dart | 166 | other | 196 |
| 4 | lib/theme/app_text_styles.dart | 203 | other | 171 |
| 5 | lib/core/providers/application_provider.dart | 413 | core | 150 |
| 6 | lib/models/recipe_unified.dart | 910 | model | 150 |
| 7 | lib/models/user_profile.dart | 310 | model | 83 |
| 8 | lib/repositories/interfaces/auth_repository.dart | 43 | repository | 57 |
| 9 | lib/services/permission_service.dart | 292 | service | 54 |
| 10 | lib/services/unified/unified_friends_service.dart | 485 | service | 47 |
| 11 | lib/models/friend_category.dart | 399 | model | 45 |
| 12 | lib/models/unified/unified_shopping_list.dart | 819 | model | 45 |
| 13 | lib/services/unified/unified_recipe_service.dart | 659 | service | 45 |
| 14 | lib/widgets/common/state_widget.dart | 444 | widget | 40 |
| 15 | lib/core/base/base_service.dart | 494 | core | 37 |
| 16 | lib/widgets/common/buttons/action_buttons.dart | 372 | widget | 36 |
| 17 | lib/models/permissions/resource_permission.dart | 270 | model | 35 |
| 18 | lib/core/mixins/error_handling_mixin.dart | 668 | mixin | 33 |
| 19 | lib/models/unified/unified_shopping_item.dart | 705 | model | 31 |
| 20 | lib/services/unified/unified_shopping_service.dart | 387 | service | 31 |
| 21 | lib/core/mixins/stream_management_mixin.dart | 749 | mixin | 30 |
| 22 | lib/repositories/firestore_repository.dart | 131 | repository | 29 |
| 23 | lib/repositories/firebase/firebase_auth_repository.dart | 218 | repository | 27 |
| 24 | lib/services/user_service.dart | 510 | service | 27 |
| 25 | lib/core/exceptions/permission_exceptions.dart | 225 | core | 26 |
| 26 | lib/core/extensions/default_value_extensions.dart | 456 | extension | 24 |
| 27 | lib/models/shared_menu.dart | 667 | model | 23 |
| 28 | lib/widgets/common/social_components.dart | 835 | widget | 23 |
| 29 | lib/core/mixins/state_notifier_mixin.dart | 440 | mixin | 22 |
| 30 | lib/core/mixins/async_operation_mixin.dart | 457 | mixin | 21 |

---

## Zero-Usage Files (30 files)

**These files have NO imports - potential dead code candidates**

### Core (3 files)

- `lib/core/error/failures.dart` - 284 LOC
- `lib/core/config/feature_flags.dart` - 161 LOC
- `lib/core/config/firebase_config.dart` - 160 LOC

### Model (2 files)

- `lib/models/recipe_unified.g.dart` - 104 LOC
- `lib/models/social/reactions.dart` - 35 LOC

### Other (5 files)

- `lib/main_e2e_optimized.dart` - 732 LOC
- `lib/main_e2e_staging.dart` - 284 LOC
- `lib/main_e2e_emulator.dart` - 271 LOC
- `lib/main_e2e_mock.dart` - 200 LOC
- `lib/utils/performance_monitor.dart` - 95 LOC

### Repository (2 files)

- `lib/repositories/mock/in_memory_repository.dart` - 254 LOC
- `lib/repositories/interfaces/reactions_repository.dart` - 125 LOC

### Service (4 files)

- `lib/services/social/activity_service.dart` - 444 LOC
- `lib/services/dialog_service.dart` - 231 LOC
- `lib/services/unified/modules/shopping_operations.dart` - 10 LOC
- `lib/services/unified/friends_cache.dart` - 5 LOC

### Utility (1 files)

- `lib/core/utils/service_optimizer.dart` - 398 LOC

### Widget (13 files)

- `lib/widgets/social/activity_feed_item_widget.dart` - 482 LOC
- `lib/views/social/group_content_feed/group_content_app_bar.dart` - 390 LOC
- `lib/views/social/group_invitations_view.dart` - 354 LOC
- `lib/views/social/group_content_feed/group_activity_timeline.dart` - 346 LOC
- `lib/views/realtime/handlers/menu_action_handler.dart` - 296 LOC
- `lib/widgets/recipe/recipe_detail_metadata.dart` - 270 LOC
- `lib/widgets/recipe/recipe_detail_comments.dart` - 246 LOC
- `lib/views/social/group_content_feed/group_content_lists.dart` - 229 LOC
- `lib/widgets/styled/styled_container.dart` - 199 LOC
- `lib/views/social/group_content_feed/group_content_tab_bar.dart` - 187 LOC
- `lib/views/social/group_content_feed/group_content_search_bar.dart` - 162 LOC
- `lib/widgets/image/image_source_picker.dart` - 119 LOC
- `lib/widgets/social/groups/friend_category_widgets.dart` - 39 LOC

---

## Low-Usage Files (1-3 imports) - 561 files

**Prime candidates for Phase 2 consolidation analysis**

### Used by 1 file(s) - 431 files

**Core**:
- `lib/core/form/form_fields_manager.dart` (492 LOC)
- `lib/core/errors/unified_error_coordinator.dart` (448 LOC)
- `lib/core/errors/contextual_error_engine.dart` (356 LOC)
- `lib/core/bootstrap/handlers/deep_link_handler.dart` (271 LOC)
- `lib/core/observers/performance_navigator_observer.dart` (215 LOC)
- `lib/core/observers/snackbar_route_observer.dart` (89 LOC)

**Data**:
- `lib/data/recipes/recipe_seeds.dart` (231 LOC)

**Mixin**:
- `lib/core/mixins/firebase_sync_mixin.dart` (218 LOC)

**Model**:
- `lib/models/recipe/recipe_operations.dart` (418 LOC)
- `lib/models/realtime/realtime_participants.dart` (381 LOC)
- `lib/models/realtime/recipe_serialization.dart` (342 LOC)
- `lib/models/realtime/recipe_operations.dart` (339 LOC)
- `lib/models/recipe/recipe_serialization.dart` (328 LOC)
- `lib/models/realtime/realtime_menu_operations.dart` (291 LOC)
- `lib/models/social/reaction_statistics.dart` (266 LOC)
- `lib/models/realtime/realtime_menu_analytics.dart` (255 LOC)
- `lib/models/messaging/message_type.dart` (247 LOC)
- `lib/models/social/content_reaction.dart` (193 LOC)
- `lib/models/realtime/realtime_menu_factory.dart` (175 LOC)
- `lib/models/audit_log.dart` (154 LOC)
- `lib/models/social/activity_engagement.dart` (94 LOC)
- `lib/models/social/activity_type.dart` (71 LOC)

**Other**:
- `lib/constants/known_ingredients.dart` (569 LOC)
- `lib/utils/text/shopping_list_generator.dart` (357 LOC)
- `lib/utils/text/ingredient_preprocessor.dart` (330 LOC)
- `lib/utils/social_content_features.dart` (322 LOC)
- `lib/utils/text/ingredient_normalizer.dart` (315 LOC)
- `lib/constants/preparation_words.dart` (246 LOC)
- `lib/theme/components/button_themes.dart` (221 LOC)
- `lib/theme/components/input_themes.dart` (148 LOC)
- `lib/theme/components/feedback_themes.dart` (109 LOC)
- `lib/theme/components/navigation_themes.dart` (97 LOC)

**Repository**:
- `lib/repositories/firebase/firebase_recipe_repository.dart` (871 LOC)
- `lib/repositories/firebase/firebase_menu_collaboration_repository.dart` (697 LOC)
- `lib/repositories/firebase/firebase_storage_repository.dart` (590 LOC)
- `lib/repositories/firebase/firebase_social_recipe_repository.dart` (518 LOC)
- `lib/repositories/firebase/firebase_user_repository.dart` (509 LOC)
- `lib/repositories/firebase/friends/group_invitation_repository.dart` (471 LOC)
- `lib/repositories/firebase/firebase_shopping_repository.dart` (424 LOC)
- `lib/repositories/firebase/firebase_social_sharing_repository.dart` (422 LOC)
- `lib/repositories/firebase/firebase_notifications_repository.dart` (412 LOC)
- `lib/repositories/firebase/firebase_comments_repository.dart` (407 LOC)
- `lib/repositories/firebase/friends/friend_request_repository.dart` (396 LOC)
- `lib/repositories/firebase/firebase_messaging_repository.dart` (379 LOC)
- `lib/repositories/firebase/modules/message_mutation_module.dart` (353 LOC)
- `lib/repositories/firebase/modules/conversation_mutation_module.dart` (324 LOC)
- `lib/repositories/firebase/firebase_deeplink_repository.dart` (271 LOC)
- `lib/repositories/firebase/modules/shopping_template_operations_module.dart` (263 LOC)
- `lib/repositories/firebase/modules/shopping_item_operations_module.dart` (256 LOC)
- `lib/repositories/firebase/firebase_connectivity_repository.dart` (229 LOC)
- `lib/repositories/interfaces/activity_repository.dart` (178 LOC)
- `lib/repositories/firebase/modules/shopping_repository_query_module.dart` (143 LOC)
  *...and 4 more*

**Service**:
- `lib/services/unified/operations/friends_invitations_operations.dart` (585 LOC)
- `lib/services/unified/operations/modules/rating_statistics.dart` (561 LOC)
- `lib/services/unified/operations/realtime_recipe_operations.dart` (550 LOC)
- `lib/services/unified/operations/friend_categories_operations.dart` (527 LOC)
- `lib/services/unified/operations/friends_management_operations.dart` (518 LOC)
- `lib/services/deep_link_service.dart` (502 LOC)
- `lib/services/realtime/realtime_recipe_service.dart` (500 LOC)
- `lib/services/notifications/modules/fcm_token_manager.dart` (498 LOC)
- `lib/services/unified/operations/modules/recipe_sharing_manager.dart` (493 LOC)
- `lib/services/notifications/modules/notification_analytics_manager.dart` (492 LOC)
- `lib/services/unified/operations/personal_shopping_operations.dart` (491 LOC)
- `lib/services/unified/operations/realtime_recipe/collaboration_management_module.dart` (491 LOC)
- `lib/services/performance/optimized_image_loader.dart` (489 LOC)
- `lib/services/performance/intelligent_cache_manager.dart` (485 LOC)
- `lib/services/performance/performance_monitoring_service.dart` (484 LOC)
- `lib/services/unified/operations/modules/social_engagement_metrics.dart` (481 LOC)
- `lib/services/import/url_import_strategy.dart` (479 LOC)
- `lib/services/unified/operations/modules/recipe_member_manager.dart` (476 LOC)
- `lib/services/notifications/modules/notification_batch_manager.dart` (472 LOC)
- `lib/services/unified/operations/realtime_recipe/presence_tracking_module.dart` (470 LOC)
  *...and 97 more*

**Utility**:
- `lib/core/utils/retry_helper.dart` (435 LOC)

**Viewmodel**:
- `lib/viewmodels/shared_content/shared_content_search_viewmodel.dart` (495 LOC)
- `lib/viewmodels/recipe/recipe_query_viewmodel.dart` (487 LOC)
- `lib/viewmodels/base_viewmodel.dart` (478 LOC)
- `lib/viewmodels/shopping_share_viewmodel.dart` (473 LOC)
- `lib/viewmodels/create_group_viewmodel.dart` (472 LOC)
- `lib/viewmodels/shared_content/social_sharing_viewmodel.dart` (467 LOC)
- `lib/viewmodels/recipe_form/image_management/image_upload_coordinator.dart` (448 LOC)
- `lib/viewmodels/group_detail_viewmodel.dart` (446 LOC)
- `lib/viewmodels/recipe_selection_viewmodel.dart` (444 LOC)
- `lib/viewmodels/recipe/realtime_recipe_viewmodel.dart` (439 LOC)
- `lib/viewmodels/social_group_detail_viewmodel.dart` (395 LOC)
- `lib/viewmodels/realtime_menu/realtime_participant_manager.dart` (381 LOC)
- `lib/viewmodels/realtime_menu/realtime_menu_operations.dart` (380 LOC)
- `lib/viewmodels/recipe/personal_recipe_viewmodel.dart` (328 LOC)
- `lib/viewmodels/add_members_to_group_viewmodel.dart` (304 LOC)
- `lib/viewmodels/unified_recipe_viewmodel.dart` (286 LOC)
- `lib/viewmodels/recipe_form/recipe_backward_compatibility_mixin.dart` (283 LOC)
- `lib/viewmodels/create_group_conversation_viewmodel.dart` (279 LOC)
- `lib/viewmodels/discovery_dashboard/discovery_recommendations_manager.dart` (274 LOC)
- `lib/viewmodels/menu/menu_social_manager.dart` (259 LOC)
  *...and 27 more*

**Widget**:
- `lib/widgets/common/profile/profile_actions.dart` (832 LOC)
- `lib/widgets/messaging/message_bubble.dart` (807 LOC)
- `lib/views/recipe_detail/recipe_detail_comments.dart` (758 LOC)
- `lib/widgets/social/group_shared_shopping_list_card.dart` (688 LOC)
- `lib/views/social/group_detail_view.dart` (684 LOC)
- `lib/views/messaging/group_detail_view.dart` (580 LOC)
- `lib/widgets/common/social_components/social_collaborative_components.dart` (499 LOC)
- `lib/views/social/discovery_dashboard_view.dart` (496 LOC)
- `lib/widgets/common/friends/friend_category_manager.dart` (496 LOC)
- `lib/views/receive_share_view.dart` (495 LOC)
- `lib/views/account/consent_management_view.dart` (494 LOC)
- `lib/widgets/common/social_components/social_builder_components.dart` (494 LOC)
- `lib/views/unified_shopping/widgets/dialogs/shopping_member_management_dialog.dart` (491 LOC)
- `lib/views/social/user_profile_edit_view.dart` (479 LOC)
- `lib/widgets/common/social_components/social_group_components.dart` (472 LOC)
- `lib/views/unified_shopping/widgets/dialogs/shopping_sharing_status_dialog.dart` (466 LOC)
- `lib/views/messaging/chat_view/chat_action_handler.dart` (459 LOC)
- `lib/views/messaging/conversations_list_view.dart` (459 LOC)
- `lib/views/social/discovery_dashboard/recommendations_section.dart` (453 LOC)
- `lib/widgets/common/content_cards/shopping_list_card.dart` (451 LOC)
  *...and 190 more*

### Used by 2 file(s) - 81 files

**Core**:
- `lib/core/rate_limiting/rate_limiter.dart` (408 LOC)
- `lib/core/base/base_action_handler.dart` (383 LOC)

**Data**:
- `lib/data/archived_recipes.dart` (8 LOC)

**Model**:
- `lib/models/recipe/recipe_factory.dart` (441 LOC)
- `lib/models/shared_content/copy_on_write_mixin.dart` (274 LOC)
- `lib/models/realtime/live_editor.dart` (264 LOC)

**Other**:
- `lib/utils/recipe_scraper.dart` (194 LOC)
- `lib/theme/app_theme.dart` (85 LOC)

**Repository**:
- `lib/repositories/firebase/firebase_ratings_repository.dart` (414 LOC)
- `lib/repositories/firebase/firebase_analytics_repository.dart` (368 LOC)
- `lib/repositories/firebase/friends/friend_relationship_repository.dart` (293 LOC)
- `lib/repositories/firebase/firebase_consent_repository.dart` (248 LOC)
- `lib/repositories/interfaces/friends_repository.dart` (161 LOC)

**Service**:
- `lib/services/ocr_extraction_service.dart` (791 LOC)
- `lib/services/realtime/modules/recipe_content_operations.dart` (494 LOC)
- `lib/services/import/file_import_strategy.dart` (486 LOC)
- `lib/services/unified/operations/social_recipe_operations.dart` (482 LOC)
- `lib/services/unified/modules/social_coordination/base_social_coordinator.dart` (462 LOC)
- `lib/services/unified/modules/realtime_recipe_module.dart` (455 LOC)
- `lib/services/unified/friends/friends_state_manager.dart` (442 LOC)
- `lib/services/content_detector_service.dart` (413 LOC)
- `lib/services/realtime/modules/menu_operations.dart` (373 LOC)
- `lib/services/backup_service.dart` (347 LOC)
- `lib/services/extraction/web_scraper.dart` (346 LOC)
- `lib/services/connectivity_monitoring_service.dart` (267 LOC)
- `lib/services/unified/operations/personal_recipe_operations.dart` (227 LOC)
- `lib/services/account/account_deletion_service.dart` (173 LOC)
- `lib/services/extraction/site_parsers/site_parser_registry.dart` (87 LOC)
- `lib/services/offline/sync_result.dart` (48 LOC)

**Viewmodel**:
- `lib/viewmodels/url_import_viewmodel.dart` (497 LOC)
- `lib/viewmodels/shared_content/shared_shopping_viewmodel.dart` (484 LOC)
- `lib/viewmodels/photo_import_viewmodel.dart` (467 LOC)
- `lib/viewmodels/chat_viewmodel.dart` (463 LOC)
- `lib/viewmodels/text_import_viewmodel.dart` (461 LOC)
- `lib/viewmodels/shared_content/shared_menu_viewmodel.dart` (446 LOC)
- `lib/viewmodels/group_invitations_viewmodel.dart` (445 LOC)
- `lib/viewmodels/user_profile_viewmodel.dart` (441 LOC)
- `lib/viewmodels/recipe_form/recipe_persistence_manager.dart` (431 LOC)
- `lib/viewmodels/realtime_menu_viewmodel.dart` (424 LOC)
- `lib/viewmodels/shared_content/shared_recipe_viewmodel.dart` (392 LOC)
- `lib/viewmodels/menu/menu_storage.dart` (373 LOC)
- `lib/viewmodels/account/consent_viewmodel.dart` (268 LOC)
- `lib/viewmodels/create_shared_list_viewmodel.dart` (260 LOC)
- `lib/viewmodels/recipe_form/recipe_form_coordinator.dart` (192 LOC)
- `lib/viewmodels/account/data_export_viewmodel.dart` (158 LOC)
- `lib/viewmodels/archive_import_viewmodel.dart` (125 LOC)
- `lib/viewmodels/realtime/optimistic_update_manager.dart` (96 LOC)

**Widget**:
- `lib/widgets/image/editable_image_widget.dart` (1329 LOC)
- `lib/views/veckomeny_view.dart` (859 LOC)
- `lib/views/skriv_sjalv_recept_view.dart` (747 LOC)
- `lib/widgets/common/scaffolds/base_scaffold.dart` (500 LOC)
- `lib/widgets/image/image_gallery_widget.dart` (492 LOC)
- `lib/widgets/common/social_components/invitation_selectors.dart` (460 LOC)
- `lib/widgets/common/loading_state_builder.dart` (451 LOC)
- `lib/views/social/menu_preview_view.dart` (445 LOC)
- `lib/widgets/image/recipe_image_widget.dart` (423 LOC)
- `lib/views/social/add_members_to_group_view.dart` (400 LOC)
- `lib/widgets/image/image_picker_widget.dart` (389 LOC)
- `lib/widgets/image/avatar_image_widget.dart` (381 LOC)
- `lib/views/social/friend_requests/friend_request_card.dart` (372 LOC)
- `lib/widgets/common/dialogs/recipe_selection/menu_recipe_selection_dialog.dart` (338 LOC)
- `lib/views/social/shared_with_me/shared_recipe_card.dart` (320 LOC)
- `lib/widgets/styled/styled_button.dart` (311 LOC)
- `lib/widgets/common/input_components.dart` (310 LOC)
- `lib/views/social/shared_with_me/shared_menu_card.dart` (301 LOC)
- `lib/widgets/common/social_components/invitation_displays.dart` (282 LOC)
- `lib/widgets/common/friends/friend_category_widgets.dart` (271 LOC)
  *...and 14 more*

### Used by 3 file(s) - 49 files

**Core**:
- `lib/core/di/di_container.dart` (425 LOC)
- `lib/core/router/app_router.dart` (416 LOC)

**Model**:
- `lib/models/social/social_comment.dart` (288 LOC)
- `lib/models/shared_content/shared_content_status_mixin.dart` (211 LOC)
- `lib/models/account/user_consent.dart` (184 LOC)
- `lib/models/recipe_change.dart` (175 LOC)
- `lib/models/social/reaction_type.dart` (76 LOC)

**Other**:
- `lib/utils/text/ingredient_parser.dart` (792 LOC)
- `lib/main.dart` (612 LOC)
- `lib/utils/text/unit_converter.dart` (283 LOC)
- `lib/theme/theme_constants.dart` (173 LOC)
- `lib/firebase_options.dart` (89 LOC)

**Repository**:
- `lib/repositories/collaborative_recipe_repository.dart` (310 LOC)
- `lib/repositories/firebase/firebase_shared_recipe_repository.dart` (301 LOC)
- `lib/repositories/firebase/firebase_recipe_presence_repository.dart` (214 LOC)
- `lib/repositories/interfaces/storage_repository.dart` (136 LOC)
- `lib/repositories/firebase/dtos/conversation_dto.dart` (124 LOC)
- `lib/repositories/interfaces/analytics_repository.dart` (114 LOC)
- `lib/repositories/interfaces/social_recipe_repository.dart` (31 LOC)
- `lib/repositories/interfaces/deeplink_repository.dart` (21 LOC)

**Service**:
- `lib/services/account/data_export_service.dart` (743 LOC)
- `lib/services/import/text_import_strategy.dart` (665 LOC)
- `lib/services/unified/operations/realtime_recipe/realtime_notification_module.dart` (594 LOC)
- `lib/services/unified/modules/personal_recipe_module.dart` (531 LOC)
- `lib/services/import/import_manager.dart` (475 LOC)
- `lib/services/unified/modules/social_menu/social_menu_coordinator.dart` (449 LOC)
- `lib/services/unified/operations/social_menu_operations.dart` (447 LOC)
- `lib/services/upload/image_upload_service.dart` (439 LOC)
- `lib/services/unified/modules/social_shopping/social_shopping_coordinator.dart` (417 LOC)
- `lib/services/unified/operations/modules/recipe_permission_helper.dart` (404 LOC)
- `lib/services/presence_service.dart` (396 LOC)
- `lib/services/group_shared_content_service.dart` (274 LOC)
- `lib/services/unified/modules/realtime_field_operations.dart` (173 LOC)
- `lib/services/realtime/realtime_types.dart` (35 LOC)

**Utility**:
- `lib/core/utils/connectivity_check.dart` (494 LOC)

**Viewmodel**:
- `lib/viewmodels/recipe_form/recipe_auto_save_manager.dart` (431 LOC)
- `lib/viewmodels/auth_viewmodel.dart` (423 LOC)
- `lib/viewmodels/recipe_form/recipe_collaborative_manager.dart` (365 LOC)
- `lib/viewmodels/shared_content/base_shared_content_viewmodel.dart` (364 LOC)
- `lib/viewmodels/import_base_viewmodel.dart` (331 LOC)
- `lib/viewmodels/menu/menu_state_manager.dart` (151 LOC)

**Widget**:
- `lib/widgets/image/universal_image_manager.dart` (681 LOC)
- `lib/views/auth_view.dart` (441 LOC)
- `lib/views/social/shared_with_me/shared_content_actions.dart` (322 LOC)
- `lib/widgets/user/user_avatar_widgets.dart` (229 LOC)
- `lib/widgets/common/state/empty_states.dart` (194 LOC)
- `lib/widgets/common/state/loading_states.dart` (155 LOC)
- `lib/widgets/common/user_avatar.dart` (48 LOC)
- `lib/widgets/common/layout/card_content.dart` (34 LOC)

---

## Analysis Complete

**Next Steps**: Phase 2 will analyze the low-usage and zero-usage files for consolidation opportunities.

**Key Insights**:
1. Files with 0 usage are prime candidates for removal
2. Files with 1-3 usage should be reviewed for possible consolidation
3. High-usage files (20+) are core infrastructure - be careful with changes
4. Layer distribution shows architectural patterns

