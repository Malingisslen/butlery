#!/bin/bash

# 🔧 User Counter Migration Runner Script
# 
# Convenience script for running the user counter migration
# Handles Flutter environment setup and provides easy access to migration options

set -e

echo "🔧 User Counter Migration Runner"
echo "================================"

# Check if Firebase is configured
if [ ! -f "lib/firebase_options.dart" ]; then
    echo "❌ Error: firebase_options.dart not found"
    echo "💡 Run 'flutterfire configure' first to set up Firebase"
    exit 1
fi

# Function to show available commands
show_help() {
    echo ""
    echo "USAGE:"
    echo "  ./migrate_counters.sh [COMMAND]"
    echo ""
    echo "COMMANDS:"
    echo "  dry-run       Preview changes without applying (recommended first step)"
    echo "  apply         Apply changes to production database"
    echo "  help          Show this help message"
    echo ""
    echo "EXAMPLES:"
    echo "  ./migrate_counters.sh dry-run       # Test migration safely"
    echo "  ./migrate_counters.sh apply         # Apply changes to production"
    echo ""
    echo "SAFETY:"
    echo "  - Always run 'dry-run' first to preview changes"
    echo "  - Script is idempotent (safe to run multiple times)"
    echo "  - Includes comprehensive error handling"
}

# Parse command
case "${1:-help}" in
    "dry-run")
        echo "🔍 Running migration in DRY RUN mode (no changes will be applied)"
        echo ""
        cmd.exe /c "dart tools/migrate_user_counters.dart --dry-run"
        ;;
    "apply")
        echo "⚠️  WARNING: This will modify user data in production!"
        echo "Make sure you've tested with 'dry-run' first."
        echo ""
        read -p "Continue? (y/N): " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            cmd.exe /c "dart tools/migrate_user_counters.dart --apply"
        else
            echo "Operation cancelled"
        fi
        ;;
    "help"|*)
        show_help
        ;;
esac

echo ""
echo "✅ Migration runner completed"