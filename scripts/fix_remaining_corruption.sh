#!/bin/bash

echo "Fixing remaining corruption issues..."

# Fix auth_service.dart - check current state first
if ! grep -q "StreamManagementMixin" lib/services/auth_service.dart; then
    echo "Fixing auth_service.dart..."
    # Find the class definition and add StreamManagementMixin
    sed -i '/class AuthService extends BaseService/s/with ErrorHandlingMixin/with ErrorHandlingMixin, StreamManagementMixin/' lib/services/auth_service.dart
    # Add import if not present
    if ! grep -q "stream_management_mixin" lib/services/auth_service.dart; then
        sed -i '/import.*error_handling_mixin/a import '\''package:butlery/core/mixins/stream_management_mixin.dart'\'';' lib/services/auth_service.dart
    fi
fi

# Fix realtime services
echo "Fixing realtime services..."
for file in lib/services/realtime/realtime_menu_service.dart lib/services/realtime/realtime_recipe_service.dart; do
    if [ -f "$file" ] && ! grep -q "StreamManagementMixin" "$file"; then
        # Find the extends BaseService line and add StreamManagementMixin
        sed -i '/extends BaseService/s/with ErrorHandlingMixin, FirebaseServiceMixin/with ErrorHandlingMixin, FirebaseServiceMixin, StreamManagementMixin/' "$file"
        # Add import
        if ! grep -q "stream_management_mixin" "$file"; then
            sed -i '/^import.*mixin/a import '\''package:butlery/core/mixins/stream_management_mixin.dart'\'';' "$file"
        fi
    fi
done

# Fix social_recipe_service.dart
echo "Fixing social_recipe_service.dart..."
if [ -f lib/services/social_recipe_service.dart ] && ! grep -q "StreamManagementMixin" lib/services/social_recipe_service.dart; then
    # Check the actual class definition
    if grep -q "extends BaseService {" lib/services/social_recipe_service.dart; then
        sed -i '/extends BaseService {/s/{/ with StreamManagementMixin {/' lib/services/social_recipe_service.dart
    else
        sed -i '/extends BaseService/s/$/with StreamManagementMixin/' lib/services/social_recipe_service.dart
    fi
    # Add import
    if ! grep -q "stream_management_mixin" lib/services/social_recipe_service.dart; then
        sed -i '/^import.*base_service/a import '\''package:butlery/core/mixins/stream_management_mixin.dart'\'';' lib/services/social_recipe_service.dart
    fi
fi

# Fix realtime_recipe_operations.dart
echo "Fixing realtime_recipe_operations.dart..."
# First check if there's a duplicate dispose method
if grep -q "void dispose()" lib/services/unified/operations/realtime_recipe_operations.dart && grep -q "Future<void> dispose()" lib/services/unified/operations/realtime_recipe_operations.dart; then
    # Remove the void dispose() version
    sed -i '/void dispose()/,/^  }/d' lib/services/unified/operations/realtime_recipe_operations.dart
fi

# Add StreamManagementMixin if not present
if ! grep -q "StreamManagementMixin" lib/services/unified/operations/realtime_recipe_operations.dart; then
    sed -i '/extends BaseService/s/$/with StreamManagementMixin/' lib/services/unified/operations/realtime_recipe_operations.dart
    # Add import
    if ! grep -q "stream_management_mixin" lib/services/unified/operations/realtime_recipe_operations.dart; then
        sed -i '/^import.*base_service/a import '\''package:butlery/core/mixins/stream_management_mixin.dart'\'';' lib/services/unified/operations/realtime_recipe_operations.dart
    fi
fi

# Fix viewmodels
echo "Fixing viewmodels..."
for file in lib/viewmodels/archive_import_viewmodel.dart lib/viewmodels/create_group_viewmodel.dart lib/viewmodels/discovery_dashboard_viewmodel.dart lib/viewmodels/group_content_viewmodel.dart lib/viewmodels/realtime_menu/realtime_menu_state.dart; do
    if [ -f "$file" ] && ! grep -q "StreamManagementMixin" "$file"; then
        echo "  Fixing $file..."
        # Add StreamManagementMixin to the class
        sed -i '/extends ChangeNotifier/s/$/ with StreamManagementMixin/' "$file"
        # Add import
        if ! grep -q "stream_management_mixin" "$file"; then
            sed -i '1 i\import '\''package:butlery/core/mixins/stream_management_mixin.dart'\'';' "$file"
        fi
    fi
done

# Fix chat viewmodels with duplicate 'with'
echo "Fixing chat viewmodels..."
sed -i 's/with with/with/g' lib/viewmodels/chat_viewmodel.dart
sed -i 's/with with/with/g' lib/viewmodels/conversations_viewmodel.dart

# Fix SavedMenuInfo - needs special handling as it's an inner class
echo "Fixing SavedMenuInfo..."
if ! grep -q "StreamManagementMixin" lib/viewmodels/menu/menu_state_manager.dart; then
    # Find SavedMenuInfo class and add mixin
    sed -i '/class SavedMenuInfo/s/extends ChangeNotifier/extends ChangeNotifier with StreamManagementMixin/' lib/viewmodels/menu/menu_state_manager.dart
    # Add import at top of file
    if ! grep -q "stream_management_mixin" lib/viewmodels/menu/menu_state_manager.dart; then
        sed -i '1 i\import '\''package:butlery/core/mixins/stream_management_mixin.dart'\'';' lib/viewmodels/menu/menu_state_manager.dart
    fi
fi

echo "All fixes applied!"