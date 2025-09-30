#!/bin/bash

# Files with print statements to clean (excluding core utilities that need them)
files=(
  "lib/services/unified/operations/friend_categories_operations.dart"
  "lib/widgets/social/groups/create_group_dialog.dart"
  "lib/views/social/group_detail/group_detail_actions.dart"
  "lib/views/social/friends_list/groups_tab.dart"
)

for file in "${files[@]}"; do
  echo "Cleaning $file..."
  # Remove lines that contain print statements (but keep AppLogger)
  sed -i '/print(/d' "$file"
done

echo "Print statements removed from debug files"