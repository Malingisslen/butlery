#!/bin/bash

echo "Fixing all warnings..."

# Fix 1: Remove unused import from firebase_sync_mixin.dart
sed -i '/import.*stream_management_mixin.dart/d' lib/core/mixins/firebase_sync_mixin.dart

# Fix 2: Add super.initState() calls to methods missing @mustCallSuper
files_need_super_initstate=(
    "lib/views/edit_recipe_view.dart:272"
    "lib/views/mina_recept_view.dart:763"
    "lib/views/recipe_detail_view.dart:420"
    "lib/views/skriv_sjalv_recept_view.dart:447"
    "lib/widgets/common/friends/friend_category_manager.dart:482"
)

for file_line in "${files_need_super_initstate[@]}"; do
    file="${file_line%:*}"
    echo "Adding super.initState() to $file"
    # Add super.initState() after the initState() { line
    sed -i '/void initState() {/a\    super.initState();' "$file"
done

# Fix 3: Remove incorrect @override annotations
files_remove_override=(
    "lib/views/fran_sociala_medier_view.dart"
    "lib/views/importera_fran_arkiv_view.dart"
    "lib/views/photo_import_view.dart"
    "lib/views/recipe_detail/recipe_detail_actions.dart"
    "lib/views/social/group_invitations_view.dart"
    "lib/views/social/shared_with_me/shared_menu_card.dart"
    "lib/widgets/common/dialogs/recipe_selection/friend_recipe_sharing_dialog.dart"
    "lib/widgets/common/dialogs/recipe_selection/menu_recipe_selection_dialog.dart"
    "lib/widgets/common/loading_state_builder.dart"
)

for file in "${files_remove_override[@]}"; do
    echo "Removing incorrect @override from $file"
    # Remove @override before dispose() methods that don't actually override
    sed -i '/^[[:space:]]*@override[[:space:]]*$/,/^[[:space:]]*void dispose() {/ { /^[[:space:]]*@override[[:space:]]*$/d }' "$file"
done

# Fix 4: Remove unused fields and methods
echo "Removing unused _messagingService fields..."
sed -i '/_messagingService;/d' lib/views/messaging/chat_view/chat_action_handler.dart
sed -i '/_messagingService;/d' lib/views/messaging/chat_view/chat_message_stream.dart

echo "Removing unused methods from chat_view.dart..."
# Remove _getAppBarTitle method
sed -i '/_getAppBarTitle/,/^  }/d' lib/views/messaging/chat_view.dart
# Remove _buildAppBarActions method  
sed -i '/_buildAppBarActions/,/^  }/d' lib/views/messaging/chat_view.dart

echo "Removing unused _handleAttachment from chat_input_section.dart..."
sed -i '/_handleAttachment/,/^  }/d' lib/views/messaging/chat_view/chat_input_section.dart

echo "All warnings fixed!"