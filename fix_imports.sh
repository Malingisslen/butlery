#!/bin/bash

# Function to add import if not already present
add_import() {
    local file="$1"
    local import_line="$2"
    local pattern="$3"
    
    # Check if file uses the pattern and doesn't already have the import
    if grep -q "$pattern" "$file" && ! grep -q "$import_line" "$file"; then
        # Find the line with app_theme.dart import and add after it
        if grep -q "import.*app_theme.dart" "$file"; then
            sed -i "/import.*app_theme.dart/a $import_line" "$file"
        else
            # If no app_theme import, add after flutter/material.dart
            sed -i "/import 'package:flutter\/material.dart';/a $import_line" "$file"
        fi
    fi
}

# Find all dart files
find /mnt/c/Butlery/butlery/lib -name "*.dart" | while read file; do
    echo "Processing: $file"
    
    # Add AppColors import
    add_import "$file" "import '../../../theme/app_colors.dart';" "AppColors"
    
    # Add AppTextStyles import  
    add_import "$file" "import '../../../theme/app_text_styles.dart';" "AppTextStyles"
    
    # Add AppDimensions import
    add_import "$file" "import '../../../theme/app_dimensions.dart';" "AppDimensions"
done