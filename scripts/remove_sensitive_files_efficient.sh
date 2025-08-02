#!/bin/bash

# Efficient script to remove sensitive files from git history
# Uses a single pass to remove both files

echo "=========================================="
echo "REMOVING SENSITIVE FILES FROM GIT HISTORY"
echo "=========================================="
echo ""
echo "This script will remove:"
echo "- android/app/google-services.json"
echo "- ios/Runner/GoogleService-Info.plist"
echo ""

# Check for uncommitted changes
if ! git diff-index --quiet HEAD --; then
    echo "ERROR: You have uncommitted changes. Please commit or stash them first."
    exit 1
fi

# Create backup branch
echo "Creating backup branch..."
git branch -f backup-before-sensitive-removal HEAD

echo ""
echo "Starting removal process..."
echo "This may take a few minutes..."

# Remove both files in a single pass
git filter-branch --force --index-filter '
  git rm --cached --ignore-unmatch android/app/google-services.json
  git rm --cached --ignore-unmatch ios/Runner/GoogleService-Info.plist
' --prune-empty --tag-name-filter cat -- --all

# Cleanup
echo ""
echo "Cleaning up..."
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now

echo ""
echo "=========================================="
echo "REMOVAL COMPLETE"
echo "=========================================="
echo ""
echo "Verification:"
echo "- google-services.json: $(git log --all --full-history -- android/app/google-services.json | wc -l) commits"
echo "- GoogleService-Info.plist: $(git log --all --full-history -- ios/Runner/GoogleService-Info.plist | wc -l) commits"
echo ""
echo "Next steps:"
echo "1. Verify removal: git log --all --full-history -- android/app/google-services.json"
echo "2. Force push: git push origin --force --all"
echo "3. Force push tags: git push origin --force --tags"
echo "4. Regenerate Firebase API keys"
echo "5. Add new google-services.json locally (DO NOT COMMIT)"
echo ""
echo "Backup branch: backup-before-sensitive-removal"