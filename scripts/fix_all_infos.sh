#!/bin/bash

echo "Fixing all info level issues..."

# Fix 1: HTML in doc comment in serialization_utils.dart
echo "Fixing HTML in doc comment..."
sed -i 's/Map<String, dynamic>/Map\&lt;String, dynamic\&gt;/g' lib/core/utils/serialization_utils.dart

# Fix 2: Add const constructors in auth_view.dart
echo "Adding const constructors in auth_view.dart..."
sed -i 's/SizedBox(height: AppDimensions.spacingXxl)/const SizedBox(height: AppDimensions.spacingXxl)/g' lib/views/auth_view.dart
sed -i 's/SizedBox(height: AppDimensions.spacingM)/const SizedBox(height: AppDimensions.spacingM)/g' lib/views/auth_view.dart

# Fix 3: Add @override annotations to build methods
echo "Adding @override annotations..."
files_need_override=(
    "lib/views/fran_sociala_medier_view.dart"
    "lib/views/importera_fran_arkiv_view.dart"
)

for file in "${files_need_override[@]}"; do
    # Add @override before Widget build methods
    sed -i '/^[[:space:]]*Widget build(BuildContext context)/i\  @override' "$file"
done

# Fix 4: Add curly braces to if statements
echo "Adding curly braces to if statements..."

# Create a Python script to properly fix if statements
cat > fix_if_statements.py << 'EOF'
import re
import sys

def fix_if_statements(filename):
    with open(filename, 'r', encoding='utf-8') as f:
        content = f.read()
    
    # Pattern to match single-line if statements without braces
    # This pattern looks for if statements followed by a single statement on the next line
    pattern = r'(\s*if\s*\([^)]+\))\s*\n(\s+)([^{].*?)(?=\n)'
    
    def replace_if(match):
        if_part = match.group(1)
        indent = match.group(2)
        statement = match.group(3).rstrip()
        
        # Don't add braces if it's already a block or ends with {
        if statement.strip().endswith('{') or statement.strip().startswith('{'):
            return match.group(0)
            
        return f'{if_part} {{\n{indent}{statement}\n{indent[:-2]}}}'
    
    fixed_content = re.sub(pattern, replace_if, content)
    
    with open(filename, 'w', encoding='utf-8') as f:
        f.write(fixed_content)

if __name__ == '__main__':
    for filename in sys.argv[1:]:
        print(f"Processing {filename}")
        fix_if_statements(filename)
EOF

# Run the Python script on files with if statement issues
python3 fix_if_statements.py \
    lib/views/messaging/chat_view.dart \
    lib/views/messaging/chat_view/chat_input_section.dart \
    lib/views/messaging/chat_view/chat_message_stream.dart \
    lib/views/messaging/conversations_list_view.dart \
    lib/views/mina_recept_view.dart \
    lib/views/realtime/components/category_section.dart \
    lib/views/receive_share_view.dart \
    lib/views/recipe_detail/fullscreen_image_viewer.dart \
    lib/views/recipe_detail/recipe_detail_comments.dart

# Clean up
rm -f fix_if_statements.py

echo "All info issues fixed!"