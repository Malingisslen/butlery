# 🔧 User Counter Migration Guide

## Problem Statement

**Issue**: Friend profiles display "0 vänner and 0 recipe" for all friends despite this not being correct.

**Root Cause**: Existing users have `friendsCount: 0` and `publicRecipeCount: 0` in their profiles because:
1. Friend operations were calling wrong methods (missing counter logic)
2. Recipe operations had no counter increment logic
3. Existing user profiles have missing/zero counter fields in Firestore

**ULTRATHINK Analysis**: The service integration was fixed, but existing user data still contains incorrect counters that need to be migrated.

## Solution Overview

This migration script:
1. **Counts actual data** from Firebase collections
2. **Updates user profiles** with correct friend and recipe counts
3. **Provides safety features** including dry-run mode and batch processing
4. **Handles errors gracefully** with comprehensive logging and validation

## Data Sources

The script counts actual data from these Firebase collections:

### Friends Count
- **Collection**: `users/{userId}/friends/`
- **Method**: Count documents in the user's friends subcollection
- **Updates**: `public_profiles/{userId}.friendsCount`

### Recipe Count  
- **Collection**: `recipes`
- **Method**: Count documents where `createdBy == userId`
- **Updates**: `public_profiles/{userId}.publicRecipeCount`

## Migration Features

### ✅ Safety Features
- **Dry-run mode**: Preview changes without applying them
- **Batch processing**: Process users in small batches (default: 50)
- **Validation**: Skip suspicious counts (>1000) for manual review
- **Idempotent**: Safe to run multiple times
- **Error handling**: Comprehensive error recovery and logging

### 📊 Progress Tracking
- Real-time progress updates
- Detailed error categorization  
- Summary statistics
- Problematic user identification

### 🔄 Retry Logic
- Automatic retry on Firebase timeouts
- Exponential backoff for rate limiting
- Maximum retry attempts (3x)

## Quick Start

### 1. Test Migration (Recommended First Step)
```bash
# Linux/macOS
./migrate_counters.sh dry-run

# Windows
migrate_counters.bat dry-run

# Direct Dart command
dart tools/migrate_user_counters.dart --dry-run
```

### 2. Apply Migration to Production
```bash
# Linux/macOS  
./migrate_counters.sh apply

# Windows
migrate_counters.bat apply

# Direct Dart command
dart tools/migrate_user_counters.dart --apply
```

## Advanced Usage

### Batch Processing
```bash
# Process first 10 users only
dart tools/migrate_user_counters.dart --dry-run --batch-size=10

# Resume from user 100, process 25 at a time
dart tools/migrate_user_counters.dart --apply --batch-start=100 --batch-size=25
```

### Command Line Options
```
--dry-run              Preview changes without applying them
--apply                Apply changes to the database  
--batch-size N         Process N users at a time (default: 50)
--batch-start N        Start from user N (for resuming)
--help, -h             Show help message
```

## Expected Output

### Dry Run Example
```
🚀 Starting User Counter Migration
Mode: DRY RUN (no changes)
Batch: Start 0, Size 50

📋 Fetching users from public_profiles...
✅ Retrieved 25 users

🔄 Processing 25 users...

[1/25] Processing user: abc123
  🔍 DRY RUN: Would update User abc123: Friends 0→3, Recipes 0→12

[2/25] Processing user: def456  
  ✅ Counters already correct, skipping

📊 MIGRATION SUMMARY:
Total Users: 25
Processed: 25
Updated: 18
Errors: 0
Skipped: 7
```

### Production Run Example
```
🚀 Starting User Counter Migration
Mode: APPLY CHANGES
Batch: Start 0, Size 50

[1/25] Processing user: abc123
  ✅ Updated: User abc123: Friends 0→3, Recipes 0→12

📊 MIGRATION SUMMARY:
Total Users: 25
Processed: 25
Updated: 18
Errors: 0
Skipped: 7
```

## Error Handling

### Common Error Types
- **processing_error**: Failed to process individual user
- **suspicious_counts**: Counts > 1000 (flagged for manual review)
- **critical_error**: Script-level failure

### Problematic Users
Users with errors are logged for manual investigation:
```
⚠️ Problematic Users:
  user123 (suspicious_counts)
  user456 (processing_error)
```

## Validation Logic

The script includes comprehensive validation:

### Skip Conditions
- Counters already correct (no update needed)
- Suspicious counts (> 1000 friends/recipes)
- Firebase access errors

### Update Conditions
- Current count != actual count
- Actual count <= 1000 (reasonable threshold)
- User profile exists and accessible

## Prerequisites

### Firebase Setup
```bash
# Ensure Firebase is configured
flutterfire configure
```

### Dependencies
Required packages (already in pubspec.yaml):
- `firebase_core: ^4.0.0`
- `cloud_firestore: ^6.0.0`

## Recovery and Rollback

### If Migration Fails
1. **Check logs** for specific error types
2. **Resume from specific batch** using `--batch-start`
3. **Reduce batch size** if hitting rate limits
4. **Manual review** of problematic users

### Rollback Strategy
The script adds metadata to track migrations:
```dart
{
  'countersUpdatedAt': timestamp,
  'countersMigratedBy': 'migrate_user_counters_script'
}
```

To identify migrated users:
```javascript
// Firebase Console Query
db.collection('public_profiles')
  .where('countersMigratedBy', '==', 'migrate_user_counters_script')
```

## Performance Considerations

### Rate Limiting
- **Batch size**: 50 users (adjustable)
- **Pause interval**: 500ms every 10 users
- **Retry delays**: 2 seconds between retries

### Firebase Limits
- **Query limits**: Uses count() queries for efficiency
- **Write limits**: Individual document updates (not batch writes)
- **Connection limits**: Single persistent connection

## Post-Migration Verification

### Manual Verification
1. **Check random user profiles** in Firebase Console
2. **Verify counter accuracy** against actual data
3. **Test friend operations** to ensure new logic works
4. **Monitor app logs** for counter update issues

### UI Verification
1. **Open friend profiles** in the app
2. **Verify statistics display** correctly
3. **Test friend addition/removal** updates counters
4. **Test recipe creation/deletion** updates counters

## Troubleshooting

### Common Issues

#### Firebase Not Initialized
```
❌ Failed to initialize Firebase
💡 Make sure you have firebase_options.dart configured
```
**Solution**: Run `flutterfire configure`

#### Permission Denied
```
❌ Error fetching users: Permission denied
```
**Solution**: Ensure Firebase rules allow admin access or run with service account

#### Rate Limiting
```
⚠️ Update attempt 1 failed: quota exceeded
```
**Solution**: Reduce batch size or add delays

## Best Practices

### Before Migration
1. ✅ **Test with dry-run** first
2. ✅ **Backup production data** 
3. ✅ **Run during low-traffic hours**
4. ✅ **Monitor Firebase quotas**

### During Migration
1. ✅ **Monitor progress logs**
2. ✅ **Watch for error patterns**
3. ✅ **Be ready to pause if needed**

### After Migration
1. ✅ **Verify sample users manually**
2. ✅ **Test app functionality**
3. ✅ **Monitor for new issues**
4. ✅ **Document results**

## Support

For issues or questions:
1. **Check logs** for specific error details
2. **Review Firebase Console** for data validation
3. **Test with smaller batches** if experiencing issues
4. **Use dry-run mode** to debug problems safely

---

**⚠️ Important**: Always test migration with `--dry-run` first to preview changes before applying to production data.