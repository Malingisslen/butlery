# File Inventory - Butlery Codebase

> Generated: 2025-12-27
> Total Files: ~837 dart files
> Total Lines: ~194,000 (estimated)

---

## Summary by Category

| Category | Files | Lines (est.) | Location |
|----------|-------|--------------|----------|
| Widgets | 227 | ~47,800 | `lib/widgets/` |
| Views | 107 | ~35,000 | `lib/views/` |
| ViewModels | 82 | ~28,000 | `lib/viewmodels/` |
| Services | 241 | ~45,000 | `lib/services/` |
| Models | 67 | ~12,000 | `lib/models/` |
| Repositories | 82 | ~18,000 | `lib/repositories/` |
| Core/Utils | ~31 dirs | ~8,200 | `lib/core/` |

---

## 1. Widgets (`lib/widgets/`)

### 1.1 Branding
| File | Purpose | Key Exports |
|------|---------|-------------|
| `branding/app_logo.dart` | App logo display | `AppLogo` |

### 1.2 Common Widgets (159 files across 28 subdirectories)

#### Buttons (`common/buttons/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `action_buttons.dart` | Main button utility class | `ActionButtons` static methods |
| `adaptive_button.dart` | Platform-adaptive button | `AdaptiveButton` |
| `animated_pressable.dart` | Animated press effect | `AnimatedPressable` |
| `overlay_button.dart` | Overlay button | `OverlayButton` |

#### Content Cards (`common/content_cards/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `recipe_card.dart` | Recipe display card | `RecipeCard` |
| `menu_card.dart` | Menu display card | `MenuCard` |
| `shopping_list_card.dart` | Shopping list card | `ShoppingListCard` |
| `friend_card.dart` | Friend display card | `FriendCard` |
| `image_preview_card.dart` | Image preview | `ImagePreviewCard` |
| `text_display_card.dart` | Text content card | `TextDisplayCard` |

#### Dialogs (`common/dialogs/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `base_dialog.dart` | Dialog framework base | `BaseDialog<T>` |
| `confirmation_dialogs.dart` | Confirmation utility | `ConfirmationDialogs` |
| `dialog_form_fields.dart` | Form field utilities | `DialogFormFields` |
| `recipe_selection_dialogs.dart` | Recipe selection | `RecipeSelectionDialogs` |
| `menu_selection_dialog.dart` | Menu selection | `MenuSelectionDialog` |
| `shopping_list_selection_dialog.dart` | List selection | `ShoppingListSelectionDialog` |
| `session_timeout_warning_dialog.dart` | Session warning | `SessionTimeoutWarningDialog` |
| `draft_recovery_dialog.dart` | Draft recovery | `DraftRecoveryDialog` |
| `rate_limit_dialog.dart` | Rate limiting | `RateLimitDialog` |
| `group_shopping_list_selection_dialog.dart` | Group list selection | `GroupShoppingListSelectionDialog` |

#### Recipe Selection Dialogs (`common/dialogs/recipe_selection/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `friend_recipe_sharing_dialog.dart` | Share with friend | `FriendRecipeSharingDialog` |
| `group_recipe_sharing_dialog.dart` | Share with group | `GroupRecipeSharingDialog` |
| `menu_recipe_selection_dialog.dart` | Menu recipe pick | `MenuRecipeSelectionDialog` |

#### Friends/Categories (`common/friends/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `category_display_widgets.dart` | Category display | Category widgets |
| `category_selection_widgets.dart` | Category selection | Selection widgets |
| `category_widgets.dart` | Category utilities | Category utilities |
| `friend_category_manager.dart` | Category management (499 lines) | `FriendCategoryManager` |
| `friend_category_widgets.dart` | Friend category UI | Friend category widgets |

#### Icons (`common/icons/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `adaptive_icon.dart` | Platform-adaptive icons (631 lines) | `AdaptiveIcon` |

#### Indicators (`common/indicators/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `admin_badge.dart` | Admin status badge | `AdminBadge` |
| `circular_icon_badge.dart` | Icon with badge | `CircularIconBadge` |
| `member_count_badge.dart` | Member count | `MemberCountBadge` |
| `notification_badge.dart` | Notification badge | `NotificationBadge` |
| `status_badge.dart` | Status indicator | `StatusBadge` |
| `loading_indicator.dart` | Loading spinner | `LoadingIndicator` |
| `adaptive_activity_indicator.dart` | Platform activity | `AdaptiveActivityIndicator` |
| `progress_overlay.dart` | Progress overlay | `ProgressOverlay` |
| `status_indicator.dart` | Generic status | `StatusIndicator` |
| `realtime_indicators.dart` | Realtime status | Realtime indicators |
| `realtime_status_widgets.dart` | Realtime widgets | Realtime status widgets |
| `edit_indicator_widget.dart` | Edit indicator | `EditIndicatorWidget` |
| `emoji_avatar.dart` | Emoji avatar | `EmojiAvatar` |
| `participant_list_widget.dart` | Participant list | `ParticipantListWidget` |

#### Input (`common/input/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `adaptive_date_picker.dart` | Date picker | `AdaptiveDatePicker` |
| `adaptive_switch.dart` | Platform switch | `AdaptiveSwitch` |
| `adaptive_text_field.dart` | Text input | `AdaptiveTextField` |
| `debounced_checkbox.dart` | Debounced checkbox | `DebouncedCheckbox` |
| `debounced_button.dart` | Debounced button | `DebouncedButton` |
| `instruction_editor.dart` | Instruction editing | `InstructionEditor` |
| `portion_scaler.dart` | Portion scaling | `PortionScaler` |
| `portion_scaler_logic.dart` | Scaling logic | Portion logic |
| `portion_scaler_ui.dart` | Scaling UI | Portion UI |
| `shopping_item_dialog.dart` | Shopping item input | `ShoppingItemDialog` |
| `shopping_list_actions.dart` | Shopping actions | `ShoppingListActions` |
| `shopping_list_card.dart` | Shopping card | `ShoppingListCard` |
| `shopping_list_selector.dart` | List selector | `ShoppingListSelector` |
| `editable_menu_items_preview_dialog.dart` | Menu preview | `EditableMenuItemsPreviewDialog` |

#### Layout (`common/layout/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `layout_containers.dart` | Layout containers | Container widgets |
| `layout_scaffolds.dart` | Layout scaffolds | Scaffold utilities |
| `status_indicators.dart` | Status display | Status indicators |

#### Menu Persistence (`common/menu_persistence/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `menu_load_dialog.dart` | Menu loading | `MenuLoadDialog` |
| `menu_save_dialog.dart` | Menu saving | `MenuSaveDialog` |

#### Navigation (`common/navigation/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `adaptive_navigation.dart` | Platform nav | `AdaptiveNavigation` |
| `bottom_navigation_items.dart` | Nav items | Navigation items |

#### Profile (`common/profile/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `profile_menu.dart` | Profile menu | `ProfileMenu` |
| `profile_actions.dart` | Profile actions | `ProfileActions` |
| `builders/menu_item_builders.dart` | Menu builders | Menu item builders |
| `builders/profile_section_builders.dart` | Section builders | Section builders |
| `handlers/auth_action_handler.dart` | Auth actions | Auth handler |
| `handlers/backup_restore_handler.dart` | Backup actions | Backup handler |
| `handlers/gdpr_consent_handler.dart` | GDPR actions | GDPR handler |
| `dialogs/profile_dialogs.dart` | Profile dialogs | Profile dialogs |
| `result_displayer.dart` | Result display | `ResultDisplayer` |

#### Responsive (`common/responsive/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `responsive_grid.dart` | Responsive grid (444 lines) | `ResponsiveGrid` |
| `responsive_builder.dart` | Responsive builder | `ResponsiveBuilder` |

#### Scaffolds (`common/scaffolds/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `base_scaffold.dart` | Base scaffold | `BaseScaffold` |
| `loading_scaffold.dart` | Loading state | `LoadingScaffold` |
| `error_scaffold.dart` | Error state | `ErrorScaffold` |
| `empty_state_scaffold.dart` | Empty state | `EmptyStateScaffold` |
| `form_scaffold.dart` | Form layout | `FormScaffold` |
| `list_scaffold.dart` | List layout | `ListScaffold` |
| `tabbed_scaffold.dart` | Tabbed layout | `TabbedScaffold` |
| `responsive_scaffold_builder.dart` | Responsive scaffold | `ResponsiveScaffoldBuilder` |

#### Search/Filter (`common/search_filter/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `search_input_widget.dart` | Search input | `SearchInputWidget` |
| `filter_chips_widget.dart` | Filter chips | `FilterChipsWidget` |
| `filter_toggle_button.dart` | Filter toggle | `FilterToggleButton` |
| `search_stats_widget.dart` | Search stats | `SearchStatsWidget` |
| `filters_panel_widget.dart` | Filters panel | `FiltersPanelWidget` |
| `filter_models.dart` | Filter models | Filter model classes |

#### Service (`common/service/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `service_widgets.dart` | Service utilities | Service widget helpers |

#### Share Dialog (`common/share_dialog/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `share_dialog_states.dart` | State handling | Share states |
| `share_dialog_header.dart` | Header component | `ShareDialogHeader` |
| `share_dialog_actions.dart` | Action buttons | `ShareDialogActions` |
| `share_dialog_helpers.dart` | Helper utilities | Share helpers |
| `share_message_input.dart` | Message input | `ShareMessageInput` |
| `share_mode_selection.dart` | Mode selection | `ShareModeSelection` |
| `share_target_selection.dart` | Target selection | `ShareTargetSelection` |
| `share_target_selection_enhanced.dart` | Enhanced selection | `ShareTargetSelectionEnhanced` |

#### Social (`common/social/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `social_facade.dart` | Master social facade (515 lines) | `SocialFacade` |
| `social_builders.dart` | Social builders | Social builder widgets |
| `api/social_avatar_api.dart` | Avatar API | Avatar API |
| `api/social_group_api.dart` | Group API | Group API |
| `api/social_invitation_api.dart` | Invitation API | Invitation API |
| `api/social_helpers.dart` | Helpers | Social helpers |

#### Social Components (`common/social_components/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `invitation_displays.dart` | Invitation display | Invitation displays |
| `invitation_selectors.dart` | Invitation selection | Invitation selectors |
| `invitation_lists.dart` | Invitation lists | Invitation lists |
| `invitation_states.dart` | Invitation states | Invitation states |
| `invitation_actions.dart` | Invitation actions | Invitation actions |
| `social_avatar_components.dart` | Avatar components (377 lines) | Avatar components |
| `social_group_components.dart` | Group components (460 lines) | Group components |
| `social_collaborative_components.dart` | Collab components (489 lines) | Collaborative components |
| `social_formatters.dart` | Formatters | Social formatters |
| `social_builder_components.dart` | Builders | Builder components |
| `social_invitation_components.dart` | Invitation facade (517 lines) | Invitation components |
| `recipe_list_avatar_badge.dart` | Avatar badge | `RecipeListAvatarBadge` |

#### State (`common/state/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `empty_states.dart` | Empty state variants | `EmptyStateBuilder` |
| `loading_states.dart` | Loading variants | `LoadingStateBuilder` |
| `message_states.dart` | Message states | Message state widgets |
| `skeleton_components.dart` | Skeleton loaders | Skeleton components |
| `state_enums.dart` | State enums | `EmptyStateVariant`, `LoadingVariant` |

#### Top-level Common Files
| File | Purpose | Key Exports |
|------|---------|-------------|
| `content_card.dart` | Content card facade (470 lines) | `ContentCard` |
| `layout_components.dart` | Layout utilities (491 lines) | Layout helpers |
| `loading_state_builder.dart` | Loading builder (450 lines) | `LoadingStateBuilder` |
| `universal_share_dialog.dart` | Share dialog facade (442 lines) | `UniversalShareDialog` |
| `social_components.dart` | Social barrel export | Social exports |
| `utility_components.dart` | Generic utilities | Utility widgets |
| `user_avatar.dart` | User avatar wrapper | `UserAvatar` |
| `state_widget.dart` | State widget base | `StateWidget` |
| `source_url_display.dart` | URL display | `SourceUrlDisplay` |
| `filter_status_chip.dart` | Filter chip | `FilterStatusChip` |
| `bottom_action_bar.dart` | Action bar | `BottomActionBar` |
| `navigation_components.dart` | Navigation | Navigation components |
| `input_components.dart` | Input | Input components |
| `search_filter_widget.dart` | Search/filter facade | `SearchFilterWidget` |

### 1.3 Image Widgets (`widgets/image/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `image_factory.dart` | Image widget factory | `ImageFactory` |
| `avatar_image_widget.dart` | Avatar display | `AvatarImageWidget` |
| `recipe_image_widget.dart` | Recipe image | `RecipeImageWidget` |
| `editable_image_widget.dart` | Editable image | `EditableImageWidget` |
| `simple_image_widget.dart` | Simple image | `SimpleImageWidget` |
| `image_gallery_widget.dart` | Gallery (496 lines) | `ImageGalleryWidget` |
| `image_picker_widget.dart` | Image picker | `ImagePickerWidget` |
| `image_config.dart` | Image config | Image configuration |
| `image_components.dart` | Image helpers | Image components |
| `universal_image_manager.dart` | Image manager (580 lines) | `UniversalImageManager` |
| `components/` (5 files) | Image components | Various image components |

### 1.4 Import Widgets (`widgets/import/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `assisted_import_dialog.dart` | Assisted import | `AssistedImportDialog` |
| `import_progress_widget.dart` | Import progress | `ImportProgressWidget` |
| `ingredient_line_detector.dart` | Line detection | `IngredientLineDetector` |
| `platform_badge_widget.dart` | Platform badge | `PlatformBadgeWidget` |
| `text_line_selector.dart` | Line selection | `TextLineSelector` |
| `components/` (5 files) | Import components | Import step components |

### 1.5 Menu Widgets (`widgets/menu/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `meal_slot_widget.dart` | Meal slot | `MealSlotWidget` |
| `menu_day_widget.dart` | Menu day | `MenuDayWidget` |
| `menu_card_widget.dart` | Menu card | `MenuCardWidget` |

### 1.6 Messaging Widgets (`widgets/messaging/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `message_bubble.dart` | Message display | `MessageBubble` |
| `message_input_field.dart` | Message input | `MessageInputField` |
| `typing_indicator.dart` | Typing status | `TypingIndicator` |
| `reply_banner.dart` | Reply banner | `ReplyBanner` |
| `chat_app_bar.dart` | Chat app bar | `ChatAppBar` |
| `conversation_list_item.dart` | Conversation item | `ConversationListItem` |
| `new_conversation_dialog.dart` | New conversation | `NewConversationDialog` |
| `image_picker_dialog.dart` | Image picker | `ImagePickerDialog` |
| `add_group_members_dialog.dart` | Add members | `AddGroupMembersDialog` |
| `fullscreen_image_viewer.dart` | Image viewer | `FullscreenImageViewer` |
| `components/` (6 files) | Message components | Message helper components |
| `builders/` (1 file) | Message builders | Message builders |

### 1.7 Permissions (`widgets/permissions/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `permission_request_widget.dart` | Permission request | `PermissionRequestWidget` |

### 1.8 Recipe Widgets (`widgets/recipe/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `recipe_card.dart` | Recipe card | `RecipeCard` |
| `comment_item_widget.dart` | Comment item | `CommentItemWidget` |
| `comment_item_widgets.dart` | Comment widgets | Comment widget helpers |
| `comment_form_widget.dart` | Comment form | `CommentFormWidget` |
| `recipe_image_picker.dart` | Recipe image picker | `RecipeImagePicker` |
| `upload_choice_dialog.dart` | Upload choice | `UploadChoiceDialog` |
| `draft_recovery_dialog.dart` | Draft recovery | `DraftRecoveryDialog` |
| `comment_debug_panel.dart` | Debug panel | `CommentDebugPanel` |
| `comment_time_formatter.dart` | Time formatter | `CommentTimeFormatter` |
| `recipe_draft_recovery_handler.dart` | Recovery handler | `RecipeDraftRecoveryHandler` |
| `recipe_form/` (1 file) | Form components | Recipe form components |

### 1.9 Social Widgets (`widgets/social/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `avatar_widgets.dart` | Avatar wrapper | Avatar widgets |
| `collaborative_indicators.dart` | Collab indicators | Collaborative indicators |
| `collaborative/components/` (4 files) | Collab components | Collaborative components |
| `groups/create_group_dialog.dart` | Create group | `CreateGroupDialog` |
| `groups/delete_group_dialog.dart` | Delete group | `DeleteGroupDialog` |
| `groups/edit_group_dialog.dart` | Edit group | `EditGroupDialog` |
| `groups/empty_group_delete_dialog.dart` | Empty delete | `EmptyGroupDeleteDialog` |
| `groups/group_dialogs.dart` | Group dialogs | Group dialog helpers |
| `groups/group_shared_content_section.dart` | Shared content | `GroupSharedContentSection` |
| `groups/ownership_transfer_dialog.dart` | Transfer owner | `OwnershipTransferDialog` |
| `groups/remove_member_dialog.dart` | Remove member | `RemoveMemberDialog` |
| `groups/shared_content_card.dart` | Shared card | `SharedContentCard` |
| `groups/shared/group_dialog_components.dart` | Dialog components | Group dialog components |

### 1.10 Styled Widgets (`widgets/styled/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `styled_button.dart` | Styled button | `StyledButton` |
| `styled_card.dart` | Styled card | `StyledCard` |
| `styled_input.dart` | Styled input | `StyledInput` |
| `styled_widgets.dart` | Styled utilities | Styled widget helpers |

### 1.11 User Widgets (`widgets/user/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `user_avatar_widgets.dart` | User avatars | User avatar widgets |
| `user_display_widgets.dart` | User display | `ImageSize` enum, display widgets |
| `user_display_models.dart` | Display models | User display models |
| `user_collection_widgets.dart` | User collections | Collection widgets |

---

## 2. Views (`lib/views/`)

### 2.1 Main Recipe Views
| File | Purpose | Key Exports |
|------|---------|-------------|
| `mina_recept_view.dart` | Personal recipe list | `MinaReceptView` |
| `edit_recipe_view.dart` | Recipe editing | `EditRecipeView` |
| `recipe_detail_view.dart` | Recipe details | `RecipeDetailView` |
| `lagg_till_recept_view.dart` | Create recipe | `LaggTillReceptView` |
| `skriv_sjalv_recept_view.dart` | Manual entry | `SkrivSjalvReceptView` |

### 2.2 Menu Views
| File | Purpose | Key Exports |
|------|---------|-------------|
| `veckomeny_view.dart` | Weekly menu | `VeckomenyView` |

### 2.3 Shopping Views
| File | Purpose | Key Exports |
|------|---------|-------------|
| `unified_shopping_view.dart` | Shopping lists | `UnifiedShoppingView` |
| `shared_shopping_lists_view.dart` | Shared lists | `SharedShoppingListsView` |

### 2.4 Import Views
| File | Purpose | Key Exports |
|------|---------|-------------|
| `smart_import_view.dart` | Unified import entry | `SmartImportView` |
| `photo_import_view.dart` | Camera/OCR import | `PhotoImportView` |
| `file_import_view.dart` | File import | `FileImportView` |
| `import_via_url_view.dart` | URL import | `ImportViaUrlView` |
| `importera_fran_arkiv_view.dart` | Archive import | `ImporteraFranArkivView` |
| `receive_share_view.dart` | Receive shared | `ReceiveShareView` |
| `fran_sociala_medier_view.dart` | Social media import | `FranSocialaMedierView` |

### 2.5 Social Views - Friends & Groups
| File | Purpose | Key Exports |
|------|---------|-------------|
| `friends_list_view.dart` | Friends/groups | `FriendsListView` |
| `friend_profile_view.dart` | Friend profile | `FriendProfileView` |
| `friend_requests_view.dart` | Friend requests | `FriendRequestsView` |
| `social/group_detail_view.dart` | Group details | `GroupDetailView` |
| `social/add_members_to_group_view.dart` | Add members | `AddMembersToGroupView` |
| `social/user_profile_edit_view.dart` | Profile edit | `UserProfileEditView` |

### 2.6 Social Views - Content Discovery
| File | Purpose | Key Exports |
|------|---------|-------------|
| `social/discovery_dashboard_view.dart` | Discovery | `DiscoveryDashboardView` |
| `social/shared_with_me_view.dart` | Shared content | `SharedWithMeView` |
| `menu_preview_view.dart` | Menu preview | `MenuPreviewView` |

### 2.7 Collaborative Features
| File | Purpose | Key Exports |
|------|---------|-------------|
| `social/collaborative_shopping_view.dart` | Realtime shopping | `CollaborativeShoppingView` |
| `social/create_shared_shopping_list_view.dart` | Create shared list | `CreateSharedShoppingListView` |

### 2.8 Messaging Views
| File | Purpose | Key Exports |
|------|---------|-------------|
| `messaging/conversations_list_view.dart` | Conversations | `ConversationsListView` |
| `messaging/group_detail_view.dart` | Group messaging | `GroupDetailView` |
| `messaging/create_group_conversation_view.dart` | Create group | `CreateGroupConversationView` |
| `messaging/chat_view/` (4 files) | Chat components | Chat handler/facade files |

### 2.9 Account & Legal Views
| File | Purpose | Key Exports |
|------|---------|-------------|
| `account/data_export_view.dart` | GDPR export | `DataExportView` |
| `account/consent_management_view.dart` | Consent | `ConsentManagementView` |
| `legal/privacy_policy_view.dart` | Privacy policy | `PrivacyPolicyView` |
| `auth_view.dart` | Authentication | `AuthView` |

### 2.10 Recipe Detail Components (`views/recipe_detail/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `recipe_detail_content.dart` | Content section | `RecipeDetailContent` |
| `recipe_detail_actions.dart` | Action buttons | `RecipeDetailActions` |
| `recipe_detail_metadata.dart` | Metadata display | `RecipeDetailMetadata` |
| `recipe_detail_comments.dart` | Comments section | `RecipeDetailComments` |
| `fullscreen_image_viewer.dart` | Image viewer | `FullscreenImageViewer` |
| `handlers/` (3 files) | Detail handlers | Recipe detail handlers |

### 2.11 Shopping Components (`views/unified_shopping/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `widgets/shopping_app_bar.dart` | App bar | `ShoppingAppBar` |
| `widgets/shopping_list_header.dart` | List header | `ShoppingListHeader` |
| `widgets/shopping_list_content.dart` | List content | `ShoppingListContent` |
| `widgets/shopping_item_tiles.dart` | Item tiles | `ShoppingItemTiles` |
| `dialogs/` (6 files) | Shopping dialogs | Various shopping dialogs |

### 2.12 Social Components (Extensive subdirectories)
| Directory | Files | Purpose |
|-----------|-------|---------|
| `social/friends_list/` | 7 | Friends list components |
| `social/group_detail/` | 8 | Group detail components |
| `social/shared_with_me/` | 7 | Shared content components |
| `social/discovery_dashboard/` | 8 | Discovery components |
| `social/collaborative_shopping/` | 4 | Collaborative components |

---

## 3. ViewModels (`lib/viewmodels/`)

### 3.1 Core
| File | Purpose | Key Exports |
|------|---------|-------------|
| `base_viewmodel.dart` | Base class | `BaseViewModel` |

### 3.2 Recipe Management (11 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `recipe_list_viewmodel.dart` | List with search/filter | `RecipeListViewModel` |
| `recipe_detail_viewmodel.dart` | Detail state | `RecipeDetailViewModel` |
| `recipe_form_viewmodel.dart` | Edit/create coordinator | `RecipeFormViewModel` |
| `unified_recipe_viewmodel.dart` | Unified operations | `UnifiedRecipeViewModel` |
| `recipe_selection_viewmodel.dart` | Selection logic | `RecipeSelectionViewModel` |
| `recipe/personal_recipe_viewmodel.dart` | Personal recipes | `PersonalRecipeViewModel` |
| `recipe/realtime_recipe_viewmodel.dart` | Realtime updates | `RealtimeRecipeViewModel` |
| `recipe/recipe_query_viewmodel.dart` | Query building | `RecipeQueryViewModel` |

### 3.3 Recipe Form Managers (10 files in `recipe_form/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `recipe_form_state.dart` | Form state machine | `RecipeFormState` |
| `recipe_form_coordinator.dart` | Orchestrator | `RecipeFormCoordinator` |
| `recipe_image_manager.dart` | Image handling | `RecipeImageManager` |
| `recipe_collaborative_manager.dart` | Realtime collab | `RecipeCollaborativeManager` |
| `recipe_permission_manager.dart` | Access control | `RecipePermissionManager` |
| `recipe_persistence_manager.dart` | Save/load | `RecipePersistenceManager` |
| `recipe_auto_save_manager.dart` | Autosave | `RecipeAutoSaveManager` |
| `image_management/` (5 files) | Image managers | Image-specific managers |
| `contextual_error_handler.dart` | Error handling | `ContextualErrorHandler` |
| `recipe_backward_compatibility_mixin.dart` | Compatibility | Backward compat mixin |

### 3.4 Menu Management (8 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `menu_viewmodel.dart` | Main coordinator | `MenuViewModel` |
| `menu/menu_state_manager.dart` | State management | `MenuStateManager` |
| `menu/menu_generator.dart` | AI generation | `MenuGenerator` |
| `menu/menu_storage.dart` | Persistence | `MenuStorage` |
| `menu/menu_social_manager.dart` | Social sharing | `MenuSocialManager` |
| `realtime_menu_viewmodel.dart` | Live collaboration | `RealtimeMenuViewModel` |
| `realtime_menu/` (4 files) | Realtime managers | Realtime menu managers |

### 3.5 Shopping Management (5 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `unified_shopping_viewmodel.dart` | Main coordinator | `UnifiedShoppingViewModel` |
| `shopping/shopping_analytics_manager.dart` | Analytics | `ShoppingAnalyticsManager` |
| `shopping/shopping_item_operations_manager.dart` | Item ops | `ShoppingItemOperationsManager` |
| `collaborative_shopping_viewmodel.dart` | Sharing | `CollaborativeShoppingViewModel` |
| `shopping_share_viewmodel.dart` | Share ops | `ShoppingShareViewModel` |

### 3.6 Friends & Social (9 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `friends_viewmodel.dart` | Main coordinator | `FriendsViewModel` |
| `friends/friends_search_manager.dart` | Search | `FriendsSearchManager` |
| `friends/friends_profile_cache_manager.dart` | Cache | `FriendsProfileCacheManager` |
| `friends/friends_selection_manager.dart` | Selection | `FriendsSelectionManager` |
| `social_recipe_viewmodel.dart` | Social recipe ops | `SocialRecipeViewModel` |
| `social_group_detail_viewmodel.dart` | Group details | `SocialGroupDetailViewModel` |
| `group_invitations_viewmodel.dart` | Invitations | `GroupInvitationsViewModel` |
| `create_group_viewmodel.dart` | Group creation | `CreateGroupViewModel` |
| `group_detail_viewmodel.dart` | Group detail | `GroupDetailViewModel` |

### 3.7 Shared Content (6 files in `shared_content/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `base_shared_content_viewmodel.dart` | Abstract base | `BaseSharedContentViewModel` |
| `shared_recipe_viewmodel.dart` | Recipe sharing | `SharedRecipeViewModel` |
| `shared_menu_viewmodel.dart` | Menu sharing | `SharedMenuViewModel` |
| `shared_shopping_viewmodel.dart` | List sharing | `SharedShoppingViewModel` |
| `shared_content_coordinator_viewmodel.dart` | Coordinator | `SharedContentCoordinatorViewModel` |
| `shared_content_search_viewmodel.dart` | Search | `SharedContentSearchViewModel` |

### 3.8 Import Management (7 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `smart_import_viewmodel.dart` | Unified entry | `SmartImportViewModel` |
| `photo_import_viewmodel.dart` | Camera/OCR | `PhotoImportViewModel` |
| `archive_import_viewmodel.dart` | Archive restore | `ArchiveImportViewModel` |
| `url_import_viewmodel.dart` | URL parsing | `UrlImportViewModel` |
| `text_import_viewmodel.dart` | Manual text | `TextImportViewModel` |
| `import_base_viewmodel.dart` | Base class | `ImportBaseViewModel` |
| `assisted_import_viewmodel.dart` | Fallback | `AssistedImportViewModel` |

### 3.9 Discovery Dashboard (3 files in `discovery_dashboard/`)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `discovery_dashboard_viewmodel.dart` | Main | `DiscoveryDashboardViewModel` |
| `discovery_content_manager.dart` | Content | `DiscoveryContentManager` |
| `discovery_friend_activity_manager.dart` | Friend activity | `DiscoveryFriendActivityManager` |

### 3.10 Account & Messaging (6 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `account/data_export_viewmodel.dart` | GDPR export | `DataExportViewModel` |
| `account/consent_viewmodel.dart` | Consent | `ConsentViewModel` |
| `account/profile_viewmodel.dart` | Profile | `ProfileViewModel` |
| `chat_viewmodel.dart` | Chat state | `ChatViewModel` |
| `conversations_viewmodel.dart` | Conversations | `ConversationsViewModel` |
| `create_group_conversation_viewmodel.dart` | Create group | `CreateGroupConversationViewModel` |

---

## 4. Services (`lib/services/`)

### 4.1 Unified Services (Core Facades)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `unified/unified_recipe_service.dart` | Recipe facade | `UnifiedRecipeService` |
| `unified/unified_shopping_service.dart` | Shopping facade | `UnifiedShoppingService` |

### 4.2 Core Services (29 standalone files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `social_recipe_service.dart` | Social sharing | `SocialRecipeService` |
| `menu_service.dart` | Menu generation | `MenuService` |
| `search_service.dart` | Recipe search | `SearchService` |
| `user_service.dart` | User profiles | `UserService` |
| `auth_service.dart` | Authentication | `AuthService` |
| `analytics_service.dart` | Analytics | `AnalyticsService` |
| `ocr_extraction_service.dart` | OCR | `OcrExtractionService` |
| `content_detector_service.dart` | Content detection | `ContentDetectorService` |
| `offline_service.dart` | Offline sync | `OfflineService` |
| `backup_service.dart` | Backup | `BackupService` |
| `messaging_service.dart` | Messaging | `MessagingService` |
| `share_service.dart` | Sharing | `ShareService` |
| `permission_service.dart` | Permissions | `PermissionService` |
| `presence_service.dart` | Presence | `PresenceService` |
| `session_timeout_service.dart` | Session | `SessionTimeoutService` |
| `connectivity_monitoring_service.dart` | Connectivity | `ConnectivityMonitoringService` |
| `image_picker_service.dart` | Image picker | `ImagePickerService` |
| `storage_service.dart` | Cloud storage | `StorageService` |
| `deep_link_service.dart` | Deep links | `DeepLinkService` |
| `recommendation_service.dart` | Recommendations | `RecommendationService` |
| `theme_service.dart` | Theme | `ThemeService` |
| `persistence_service.dart` | Persistence | `PersistenceService` |

### 4.3 Service Subdirectories (21 directories)
| Directory | Files | Purpose |
|-----------|-------|---------|
| `account/` | 9 | Account deletion/export |
| `analytics/` | 7 | Event trackers |
| `extraction/` | 10+ | Content extraction |
| `import/` | 30+ | Import strategies/pipelines |
| `messaging/` | 3 | Message operations |
| `notifications/` | 3 | FCM/notifications |
| `offline/` | 3 | Offline sync |
| `parsing/` | 15+ | Recipe parsing tiers |
| `permissions/` | 3 | Permission modules |
| `performance/` | 2 | Performance optimization |
| `realtime/` | 7 | Realtime sync |
| `social/` | 1 | Social modules |
| `unified/` | 30+ | Unified service modules |
| `auth/` | 2 | Auth helpers |
| `encryption/` | 2 | Encryption |
| `feature_flags/` | 2 | Feature flags |
| `llm/` | 2 | LLM integration |
| `ocr/` | 2 | OCR utilities |

---

## 5. Models (`lib/models/`)

### 5.1 Core Content Models (4 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `recipe_unified.dart` | Main recipe | `RecipeUnified` |
| `shared_recipe.dart` | Shared recipe | `SharedRecipe` |
| `shared_menu.dart` | Shared menu | `SharedMenu` |
| `shared_content.dart` | Generic shared | `SharedContent` |

### 5.2 User & Social (5 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `user_profile.dart` | User profile | `UserProfile` |
| `friend_request.dart` | Friend request | `FriendRequest` |
| `friend_category.dart` | Friend grouping | `FriendCategory` |
| `group_invitation.dart` | Group invite | `GroupInvitation` |
| `user_counters.dart` | User stats | `UserCounters` |

### 5.3 Shared Content Models (3 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `shared_recipe.dart` | Recipe sharing | `SharedRecipe` |
| `shared_menu.dart` | Menu sharing | `SharedMenu` |
| `shared_shopping_list.dart` | List sharing | `SharedShoppingList` |

### 5.4 Model Subdirectories (13 directories)
| Directory | Files | Purpose |
|-----------|-------|---------|
| `shared_content/` | 3 | Base models + mixins |
| `messaging/` | 5 | Message/conversation |
| `realtime/` | 10+ | Realtime models |
| `permissions/` | 2 | Permission models |
| `parsing/` | 9 | Parsing models |
| `social/` | 6 | Social/activity models |
| `metadata/` | 4 | Metadata models |
| `recipe/` | 3 | Recipe helpers |
| `account/` | 1 | Consent model |

---

## 6. Repositories (`lib/repositories/`)

### 6.1 Base Repositories (6 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `firebase/base_firebase_repository.dart` | CRUD + permissions | `BaseFirebaseRepository<T>` |
| `firebase/base_metadata_repository.dart` | Metadata ops | `BaseMetadataRepository` |
| `firebase/base_dismissal_repository.dart` | Dismissal tracking | `BaseDismissalRepository` |
| `firebase/base_engagement_repository.dart` | Engagement | `BaseEngagementRepository` |
| `firebase/base_view_repository.dart` | View tracking | `BaseViewRepository` |
| `firebase/base_social_interaction_repository.dart` | Social ops | `BaseSocialInteractionRepository` |

### 6.2 Core Repositories (8 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `firebase/firebase_recipe_repository.dart` | Recipes | `FirebaseRecipeRepository` |
| `firebase/firebase_shopping_repository.dart` | Shopping | `FirebaseShoppingRepository` |
| `firebase/firebase_menu_collaboration_repository.dart` | Menu collab | `FirebaseMenuCollaborationRepository` |
| `firebase/firebase_auth_repository.dart` | Auth | `FirebaseAuthRepository` |
| `firebase/firebase_comments_repository.dart` | Comments | `FirebaseCommentsRepository` |
| `firebase/firebase_user_repository.dart` | Users | `FirebaseUserRepository` |
| `firebase/firebase_notifications_repository.dart` | Notifications | `FirebaseNotificationsRepository` |
| `firebase/firebase_ratings_repository.dart` | Ratings | `FirebaseRatingsRepository` |

### 6.3 Repository Modules (Multiple)
| Directory | Files | Purpose |
|-----------|-------|---------|
| `firebase/modules/` | 10+ | Specialized modules |
| `firebase/dtos/` | 2 | Data transfer objects |
| `firebase/friends/` | 4 | Friend repositories |
| `firebase/shared_content/` | 9 | Shared content repos |
| `interfaces/` | 13 | Repository interfaces |
| `algolia/` | 1 | Algolia search |

---

## 7. Core (`lib/core/`)

### 7.1 Base Classes (2 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `base/base_service.dart` | Service foundation (459 lines) | `BaseService` |
| `base/base_action_handler.dart` | Action handling (386 lines) | `BaseActionHandler` |

### 7.2 Mixins (8 files, ~4,771 lines)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `mixins/error_handling_mixin.dart` | Error patterns (609 lines) | `ErrorHandlingMixin` |
| `mixins/state_notifier_mixin.dart` | State management (414 lines) | `StateNotifierMixin` |
| `mixins/async_operation_mixin.dart` | Async operations (453 lines) | `AsyncOperationMixin` |
| `mixins/firebase_service_mixin.dart` | Firebase ops (817 lines) | `FirebaseServiceMixin` |
| `mixins/stream_management_mixin.dart` | Stream handling (710 lines) | `StreamManagementMixin` |
| `mixins/json_serializable_mixin.dart` | JSON ops (636 lines) | `JsonSerializableMixin` |
| `mixins/permission_validation_mixin.dart` | Permission checks | `PermissionValidationMixin` |
| `mixins/service_validation_mixin.dart` | Service validation | `ServiceValidationMixin` |

### 7.3 Utils (11 files, ~3,325 lines)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `utils/serialization_utils.dart` | Data parsing (397 lines) | `SerializationUtils` |
| `utils/validation_utils.dart` | Validation (343 lines) | `ValidationUtils` |
| `utils/snackbar_utils.dart` | Notifications (341 lines) | `SnackBarUtils` |
| `utils/app_logger.dart` | Logging (423 lines) | `AppLogger` |
| `utils/retry_helper.dart` | Retry logic (393 lines) | `RetryHelper` |
| `utils/common_dialog_actions.dart` | Dialog actions | `CommonDialogActions` |
| `utils/animation_utils.dart` | Animation | `AnimationUtils` |
| `utils/connectivity_check.dart` | Connectivity | `ConnectivityCheck` |
| `utils/permission_helper.dart` | Permissions | `PermissionHelper` |
| `utils/default_value_extensions.dart` | Extensions (119 lines) | Default extensions |
| `utils/localization_extension.dart` | Localization | Localization extensions |

### 7.4 DI System (8 files)
| File | Purpose | Key Exports |
|------|---------|-------------|
| `di/di_container.dart` | Container (397 lines) | `DIContainer` |
| `di/modules/core_module.dart` | Core services | `CoreModule` |
| `di/modules/ui_module.dart` | UI services | `UIModule` |
| `di/modules/messaging_module.dart` | Messaging | `MessagingModule` |
| `di/modules/performance_module.dart` | Performance | `PerformanceModule` |
| `di/modules/search_module.dart` | Search | `SearchModule` |
| `di/interfaces/di_module.dart` | Module interface | `DIModule` |

### 7.5 Other Core Components
| Directory | Files | Purpose |
|-----------|-------|---------|
| `bootstrap/` | 6 | App initialization |
| `config/` | 1 | Firebase config |
| `constants/` | 2 | App strings, routes |
| `dialogs/` | 1 | Dialog factory |
| `errors/` | 1 | Error engine |
| `events/` | 1 | Event system |
| `exceptions/` | 1 | Custom exceptions |
| `extensions/` | 2 | Core extensions |
| `form/` | 1 | Form management |
| `helpers/` | 2 | Helpers |
| `network/` | 1 | SSL pinning |
| `observers/` | 2 | Route/session observers |
| `providers/` | 2 | Locale/app providers |
| `rate_limiting/` | 1 | Rate limiter |
| `responsive/` | 1 | Responsive utilities |
| `router/` | 2 | App routing |
| `storage/` | 5 | Drift database |
| `types/` | 1 | Custom types |
| `validators/` | 1 | Form validators |

---

## Internal Dependencies Summary

### Most Imported Files (High Fan-In)
1. `core/utils/serialization_utils.dart` - Used by all models
2. `core/mixins/error_handling_mixin.dart` - Used by all services
3. `core/utils/validation_utils.dart` - Used by services and ViewModels
4. `core/base/base_service.dart` - Extended by services
5. `models/recipe_unified.dart` - Core content model
6. `services/user_service.dart` - User context provider
7. `repositories/firebase/base_firebase_repository.dart` - Repository base

### Cross-Layer Dependencies
- Views → ViewModels → Services → Repositories → Firebase
- All layers use Core/Utils
- Models used across all layers
