#!/bin/bash

# Script to remove sensitive files from git history
# WARNING: This will rewrite git history!

echo "=========================================="
echo "REMOVING SENSITIVE FILES FROM GIT HISTORY"
echo "=========================================="
echo ""
echo "This script will:"
echo "1. Remove google-services.json from all git history"
echo "2. Remove GoogleService-Info.plist from all git history"
echo "3. Force update all branches and tags"
echo ""
echo "WARNING: This will rewrite git history!"
echo "Make sure you have:"
echo "- Backed up your repository"
echo "- No uncommitted changes"
echo ""
read -p "Are you sure you want to continue? (yes/no): " confirm

if [ "$confirm" != "yes" ]; then
    echo "Operation cancelled."
    exit 1
fi

echo ""
echo "Creating backup branch..."
git branch backup-before-sensitive-removal

echo ""
echo "Removing google-services.json from history..."
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch android/app/google-services.json' \
  --prune-empty --tag-name-filter cat -- --all

echo ""
echo "Removing GoogleService-Info.plist from history..."
git filter-branch --force --index-filter \
  'git rm --cached --ignore-unmatch ios/Runner/GoogleService-Info.plist' \
  --prune-empty --tag-name-filter cat -- --all

echo ""
echo "Cleaning up..."
rm -rf .git/refs/original/
git reflog expire --expire=now --all
git gc --prune=now --aggressive

echo ""
echo "=========================================="
echo "REMOVAL COMPLETE"
echo "=========================================="
echo ""
echo "Next steps:"
echo "1. Verify the files are removed: git log --all --full-history -- android/app/google-services.json"
echo "2. Force push to remote: git push origin --force --all"
echo "3. Force push tags: git push origin --force --tags"
echo "4. Delete local repo and re-clone if needed"
echo "5. Regenerate Firebase API keys in Firebase Console"
echo "6. Add new google-services.json locally (DO NOT COMMIT)"
echo ""
echo "Backup branch created: backup-before-sensitive-removal"