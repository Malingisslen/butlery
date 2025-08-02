#!/bin/bash

# Fix references to UnifiedFriendsServiceEnhanced -> UnifiedFriendsService

echo "Fixing UnifiedFriendsServiceEnhanced references..."

# Replace in social_module.dart
sed -i 's/UnifiedFriendsServiceEnhanced/UnifiedFriendsService/g' lib/core/di/modules/social_module.dart

# Replace in intelligent_cache_manager.dart  
sed -i 's/UnifiedFriendsServiceEnhanced/UnifiedFriendsService/g' lib/services/performance/intelligent_cache_manager.dart

# Fix the import in social_module.dart
sed -i 's|unified_friends_service_enhanced\.dart|unified_friends_service.dart|g' lib/core/di/modules/social_module.dart

# Fix the import in intelligent_cache_manager.dart
sed -i 's|unified_friends_service_enhanced\.dart|unified_friends_service.dart|g' lib/services/performance/intelligent_cache_manager.dart

echo "Fixed all references."