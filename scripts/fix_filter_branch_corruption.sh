#!/bin/bash

echo "=========================================="
echo "FIXING GIT FILTER-BRANCH CORRUPTION"
echo "=========================================="
echo ""

# Fix 1: Remove duplicate with clauses
echo "Fixing multiple with clauses..."
# Firebase recipe repository
sed -i '63s/with StreamManagementMixin,/,/' lib/repositories/firebase/firebase_recipe_repository.dart

# Chat viewmodel - remove extra 'with'
sed -i '126s/with with/with/' lib/viewmodels/chat_viewmodel.dart

# Conversations viewmodel - remove extra 'with'
sed -i '115s/with with/with/' lib/viewmodels/conversations_viewmodel.dart

# Fix 2: Add missing StreamManagementMixin where disposeStreams is called
echo "Adding missing StreamManagementMixin..."

# Fix auth_service.dart
sed -i '/class AuthService extends BaseService with ErrorHandlingMixin/s/$/, StreamManagementMixin/' lib/services/auth_service.dart
if ! grep -q "stream_management_mixin" lib/services/auth_service.dart; then
    sed -i '/import.*error_handling_mixin/a import '\''package:butlery/core/mixins/stream_management_mixin.dart'\'';' lib/services/auth_service.dart
fi

# Fix realtime services
for file in lib/services/realtime/realtime_menu_service.dart lib/services/realtime/realtime_recipe_service.dart; do
    if ! grep -q "StreamManagementMixin" "$file"; then
        sed -i '/extends BaseService.*{/s/ErrorHandlingMixin/ErrorHandlingMixin, StreamManagementMixin/' "$file"
    fi
    if ! grep -q "stream_management_mixin" "$file"; then
        sed -i '/import.*error_handling_mixin/a import '\''package:butlery/core/mixins/stream_management_mixin.dart'\'';' "$file"
    fi
done

# Fix social_recipe_service.dart
if ! grep -q "StreamManagementMixin" lib/services/social_recipe_service.dart; then
    sed -i '/extends BaseService.*{/s/$/with StreamManagementMixin {/' lib/services/social_recipe_service.dart
    sed -i '/import.*base_service/a import '\''package:butlery/core/mixins/stream_management_mixin.dart'\'';' lib/services/social_recipe_service.dart
fi

# Fix viewmodels
for file in lib/viewmodels/archive_import_viewmodel.dart lib/viewmodels/create_group_viewmodel.dart lib/viewmodels/discovery_dashboard_viewmodel.dart lib/viewmodels/group_content_viewmodel.dart; do
    if [ -f "$file" ] && ! grep -q "StreamManagementMixin" "$file"; then
        # Add StreamManagementMixin to the class definition
        sed -i '/extends ChangeNotifier/s/$/ with StreamManagementMixin/' "$file"
        # Add import
        if ! grep -q "stream_management_mixin" "$file"; then
            sed -i '1a import '\''package:butlery/core/mixins/stream_management_mixin.dart'\'';' "$file"
        fi
    fi
done

# Fix 3: Fix the dispose override in realtime_recipe_operations.dart
echo "Fixing dispose override..."
# Make dispose async
sed -i 's/void dispose()/Future<void> dispose() async/' lib/services/unified/operations/realtime_recipe_operations.dart

# Fix 4: Fix performance_monitoring_mixin.dart
echo "Fixing performance monitoring mixin..."
# Remove incorrect @override
sed -i '431s/@override//' lib/core/mixins/performance_monitoring_mixin.dart

# Add StreamManagementMixin to CriticalServiceMonitoringMixin
sed -i '/mixin CriticalServiceMonitoringMixin/s/$/ on StreamManagementMixin/' lib/core/mixins/performance_monitoring_mixin.dart

# Fix 5: Fix menu_state_manager.dart
echo "Fixing menu state manager..."
# Remove incorrect @override
sed -i '152s/@override//' lib/viewmodels/menu/menu_state_manager.dart

# Add StreamManagementMixin to SavedMenuInfo
sed -i '/class SavedMenuInfo extends ChangeNotifier/s/$/ with StreamManagementMixin/' lib/viewmodels/menu/menu_state_manager.dart
if ! grep -q "stream_management_mixin" lib/viewmodels/menu/menu_state_manager.dart; then
    sed -i '1a import '\''package:butlery/core/mixins/stream_management_mixin.dart'\'';' lib/viewmodels/menu/menu_state_manager.dart
fi

echo ""
echo "All fixes applied!"
echo ""
echo "Running flutter analyze to check remaining issues..."