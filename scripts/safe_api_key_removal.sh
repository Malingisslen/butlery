#!/bin/bash

# Safe API key removal using modern approach
# This script removes sensitive files without corrupting the repository

echo "=========================================="
echo "SAFE API KEY REMOVAL"
echo "=========================================="
echo ""

# First, let's check if we need to restore from remote
echo "Fetching latest from remote..."
git fetch origin

# Get the latest commit from remote
REMOTE_HEAD=$(git rev-parse origin/consolidation/phase1-deduplication)
LOCAL_HEAD=$(git rev-parse HEAD)

echo "Remote HEAD: $REMOTE_HEAD"
echo "Local HEAD: $LOCAL_HEAD"

if [ "$REMOTE_HEAD" != "$LOCAL_HEAD" ]; then
    echo ""
    echo "Local and remote differ. Would you like to:"
    echo "1) Reset to remote state (recommended if local is corrupted)"
    echo "2) Continue with local state"
    echo "3) Abort"
    read -p "Choice (1/2/3): " choice
    
    if [ "$choice" = "1" ]; then
        echo "Resetting to remote state..."
        git reset --hard origin/consolidation/phase1-deduplication
    elif [ "$choice" = "3" ]; then
        echo "Aborted."
        exit 0
    fi
fi

# Check current state
echo ""
echo "Checking for sensitive files in current working directory..."
if [ -f "android/app/google-services.json" ]; then
    echo "Found google-services.json in working directory"
    rm -f android/app/google-services.json
    echo "Removed from working directory"
fi

if [ -f "ios/Runner/GoogleService-Info.plist" ]; then
    echo "Found GoogleService-Info.plist in working directory"
    rm -f ios/Runner/GoogleService-Info.plist
    echo "Removed from working directory"
fi

# Add to .gitignore if not already there
echo ""
echo "Updating .gitignore..."
if ! grep -q "google-services.json" .gitignore; then
    echo "android/app/google-services.json" >> .gitignore
fi

if ! grep -q "GoogleService-Info.plist" .gitignore; then
    echo "ios/Runner/GoogleService-Info.plist" >> .gitignore
fi

# Commit .gitignore changes if any
if ! git diff --quiet .gitignore; then
    git add .gitignore
    git commit -m "chore: add Firebase config files to .gitignore

- Added google-services.json to .gitignore
- Added GoogleService-Info.plist to .gitignore
- Prevents accidental commits of sensitive API keys

🤖 Generated with [Claude Code](https://claude.ai/code)

Co-Authored-By: Claude <noreply@anthropic.com>"
fi

echo ""
echo "=========================================="
echo "MANUAL REMOVAL INSTRUCTIONS"
echo "=========================================="
echo ""
echo "Since git filter-branch can corrupt the repository, here's a safer approach:"
echo ""
echo "1. Create a new branch without the sensitive files:"
echo "   git checkout -b clean-history"
echo ""
echo "2. Use git filter-repo (install with: pip install git-filter-repo):"
echo "   git filter-repo --path android/app/google-services.json --invert-paths"
echo "   git filter-repo --path ios/Runner/GoogleService-Info.plist --invert-paths"
echo ""
echo "3. OR use BFG Repo-Cleaner (download from https://rtyley.github.io/bfg-repo-cleaner/):"
echo "   java -jar bfg.jar --delete-files google-services.json"
echo "   java -jar bfg.jar --delete-files GoogleService-Info.plist"
echo "   git reflog expire --expire=now --all && git gc --prune=now --aggressive"
echo ""
echo "4. Force push the cleaned history:"
echo "   git push origin --force --all"
echo "   git push origin --force --tags"
echo ""
echo "5. All team members must delete and re-clone the repository"
echo ""
echo "Current status:"
echo "- Sensitive files removed from working directory: ✓"
echo "- Added to .gitignore: ✓"
echo "- History cleaning: Manual action required"