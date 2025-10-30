# Production Deployment Guide

**Last Updated**: January 30, 2025
**Status**: Production-Ready
**Audience**: DevOps, Release Engineers, Technical Leads

---

## Overview

This guide provides step-by-step procedures for deploying Butlery to production. It consolidates all deployment workflows for Firebase services, security configurations, and production setup.

**Related Technical Guides (Archived Reference Material):**
- **[SECURITY_RULES_DEPLOYMENT.md](../archived/operations/SECURITY_RULES_DEPLOYMENT.md)** - Detailed security rules reference
- **[FIRESTORE_INDICES_DEPLOYMENT.md](../archived/operations/FIRESTORE_INDICES_DEPLOYMENT.md)** - Complete index specifications
- **[FCM_PRODUCTION_DEPLOYMENT.md](../archived/operations/FCM_PRODUCTION_DEPLOYMENT.md)** - FCM configuration details

---

## Table of Contents

1. [Pre-Deployment Checklist](#pre-deployment-checklist)
2. [Firebase Security Rules Deployment](#firebase-security-rules-deployment)
3. [Firestore Indices Deployment](#firestore-indices-deployment)
4. [Firebase Cloud Messaging Setup](#firebase-cloud-messaging-setup)
5. [Environment Configuration](#environment-configuration)
6. [Production Monitoring](#production-monitoring)
7. [Rollback Procedures](#rollback-procedures)

---

## Pre-Deployment Checklist

### Prerequisites ✅

**Environment Setup:**
- [ ] Firebase CLI installed and authenticated (`firebase login`)
- [ ] Flutter SDK 3.0+ configured
- [ ] Production Firebase project selected (`firebase use production`)
- [ ] Environment variables configured (see [ENV_SETUP.md](../setup/ENV_SETUP.md))

**Code Quality:**
- [ ] All tests passing (`flutter test`)
- [ ] Zero critical analyzer issues (`flutter analyze`)
- [ ] Production readiness at 94%+ (see [REMEDIATION_ACTION_PLAN.md](../audit/REMEDIATION_ACTION_PLAN.md))

**Security:**
- [ ] Security rules reviewed and tested in emulator
- [ ] API keys restricted in Firebase Console
- [ ] Audit logging enabled
- [ ] GDPR compliance verified

**Documentation:**
- [ ] Deployment notes documented
- [ ] Rollback procedure reviewed
- [ ] Team notified of deployment window

---

## Firebase Security Rules Deployment

### Overview

Deploy Firestore Security Rules and Storage Rules to protect user data and enforce authorization.

**📖 Full Technical Reference:** [SECURITY_RULES_DEPLOYMENT.md](../archived/operations/SECURITY_RULES_DEPLOYMENT.md)

### Quick Deployment

```bash
# 1. Verify current project
firebase use production

# 2. Test rules locally first
firebase emulators:start --only firestore,storage

# 3. Deploy security rules
firebase deploy --only firestore:rules,storage:rules

# 4. Verify deployment
firebase firestore:rules get
```

### Collections Covered (30+ patterns)

**Core User Data:**
- `users/{userId}` - Private user data (self-access only)
- `public_profiles/{userId}` - Public profiles (read: all, write: owner)
- `users/{userId}/consent/{consentDoc}` - GDPR consent management

**Social Features:**
- `friend_requests/{requestId}` - Friend request management
- `conversations/{conversationId}` - Messaging (participant-only)
- `shared_recipes/{shareId}` - Recipe sharing

**Shopping & Collaboration:**
- `unified_shared_shopping_lists/{listId}` - Collaborative shopping lists
- `realtime_recipes/{recipeId}` - Real-time recipe editing

**Audit & Compliance:**
- `audit_logs/{logId}` - Immutable audit trail (GDPR Article 30)

### Verification Checklist

- [ ] Security rules deployed successfully
- [ ] Test user operations in production (read/write permissions)
- [ ] Verify audit logs are being created
- [ ] Check Firebase Console for rule violations

---

## Firestore Indices Deployment

### Overview

Deploy 19 composite indices required for efficient queries across collections.

**📖 Full Technical Reference:** [FIRESTORE_INDICES_DEPLOYMENT.md](../archived/operations/FIRESTORE_INDICES_DEPLOYMENT.md)

### Quick Deployment

```bash
# 1. Verify firestore.indexes.json exists and is up to date
cat firestore.indexes.json

# 2. Deploy indices
firebase deploy --only firestore:indexes

# 3. Monitor index creation in Firebase Console
# Note: Index creation can take 5-30 minutes depending on data size
```

### Critical Indices (19 total)

**Audit Logs (4 indices):**
- `userId + timestamp` - User audit trail
- `resourceId + timestamp` - Resource access logs
- `userId + granted=false` - Denied access attempts
- `userId + action + timestamp` - Action-based filtering

**User Profiles (2 indices):**
- `isSearchable + displayNameLower` - User search
- `isSearchable + friendsCount` - Discovery ranking

**Recipes (4 indices):**
- `userId + createdAt` - User recipes chronological
- `userId + lastModified` - Recently modified
- `userId + isArchived + title` - Archive management
- `userId + mealType + createdAt` - Filtered recipe lists

**Social Features (5 indices):**
- `recipeId + createdAt` - Recipe comments
- `userId + createdAt` - User comments
- `toUserId + status` - Friend requests
- And more...

### Verification Checklist

- [ ] All 19 indices deployed
- [ ] Firebase Console shows "Enabled" status (wait for completion)
- [ ] Test queries that use composite indices
- [ ] Monitor query performance in Firebase Console

---

## Firebase Cloud Messaging Setup

### Overview

Configure Firebase Cloud Messaging (FCM) for push notifications in production.

**📖 Full Technical Reference:** [FCM_PRODUCTION_DEPLOYMENT.md](../archived/operations/FCM_PRODUCTION_DEPLOYMENT.md)

### iOS Setup

```bash
# 1. Upload APNs certificate to Firebase Console
# - Navigate to: Project Settings → Cloud Messaging → iOS App Configuration
# - Upload production APNs certificate (.p8 or .p12)
# - Enter Key ID and Team ID

# 2. Configure iOS app
# - Ensure GoogleService-Info.plist is in ios/Runner/
# - Verify Bundle ID matches Firebase project
# - Enable Push Notifications capability in Xcode
```

### Android Setup

```bash
# 1. Verify google-services.json
# - Ensure production google-services.json in android/app/
# - Verify package name matches Firebase project

# 2. Test notification delivery
flutter run --release
# Send test notification from Firebase Console
```

### Production Configuration

**Update notification settings:**

```dart
// lib/services/notification_service.dart
const PRODUCTION_MODE = true; // Enable production logging
const NOTIFICATION_CHANNEL_ID = 'butlery_production';
```

### Verification Checklist

- [ ] FCM tokens successfully registered in production
- [ ] Test notifications delivered on iOS
- [ ] Test notifications delivered on Android
- [ ] Notification preferences persist correctly
- [ ] Deep links work from notifications

---

## Environment Configuration

### Production Environment File

Create `config/prod.env`:

```bash
# Firebase Configuration
FIREBASE_PROJECT_ID=butlery-production
FIREBASE_API_KEY=[production_api_key]
FIREBASE_APP_ID=[production_app_id]

# Feature Flags
ENABLE_ANALYTICS=true
ENABLE_CRASH_REPORTING=true
ENABLE_PERFORMANCE_MONITORING=true

# API Endpoints
API_BASE_URL=https://api.butlery.app
```

### Build Commands

```bash
# Android Production
flutter build apk --release --dart-define=ENV=production

# iOS Production
flutter build ios --release --dart-define=ENV=production

# Web Production
flutter build web --release --dart-define=ENV=production
```

### Verification Checklist

- [ ] Production environment variables loaded
- [ ] API keys restricted in Firebase Console
- [ ] Feature flags configured correctly
- [ ] Build completes without errors
- [ ] App connects to production Firebase project

---

## Production Monitoring

### Firebase Console Monitoring

**Key Metrics to Track:**

1. **Performance Monitoring**
   - Screen load times
   - Network request latency
   - Custom traces (recipe loading, search, image upload)
   - Target: < 2s for 90th percentile

2. **Crashlytics**
   - Crash-free users rate (target: > 99%)
   - Top crashes by occurrence
   - Error logs and stack traces

3. **Analytics**
   - Daily/Monthly Active Users (DAU/MAU)
   - User engagement (session duration, screens per session)
   - Feature adoption (recipe creation, social interactions)

4. **Security Rules Violations**
   - Monitor for unauthorized access attempts
   - Review audit logs regularly
   - Alert on failed permission checks

### Monitoring Setup

```bash
# Enable Firebase Performance Monitoring
# Already integrated in Phase 4.7 (see FIREBASE_PERFORMANCE_INTEGRATION.md)

# Configure alerts in Firebase Console:
# 1. Navigate to Alerts section
# 2. Set up alerts for:
#    - Crash-free users < 99%
#    - Error rate > 5%
#    - Response time > 3s
```

### Logging Strategy

**Production Log Levels:**
- `ERROR` - Critical errors requiring immediate attention
- `WARNING` - Potential issues to monitor
- `INFO` - Key user actions and system events
- `DEBUG` - Disabled in production

---

## Rollback Procedures

### Security Rules Rollback

**If rules cause issues in production:**

```bash
# Option 1: Firebase Console (Fastest)
# 1. Go to Firebase Console → Firestore → Rules
# 2. Click "Version History"
# 3. Select previous working version
# 4. Click "Publish"

# Option 2: Git Rollback
git log firestore.rules
git checkout <previous-commit-hash> firestore.rules
firebase deploy --only firestore:rules
```

### Application Rollback

**If deployment causes critical issues:**

```bash
# 1. Identify last stable release tag
git tag -l "v*" --sort=-version:refname | head -5

# 2. Checkout stable version
git checkout tags/v1.2.3

# 3. Rebuild and redeploy
flutter build apk --release --dart-define=ENV=production

# 4. Upload to app stores
```

### Database Rollback (Emergency Only)

**Firestore does NOT support automatic rollback. Instead:**

1. **Prevent further writes:**
   - Deploy restrictive security rules
   - Disable write operations in app

2. **Restore from backup:**
   - Use Cloud Firestore managed export/import
   - Or restore from scheduled backups

3. **Verify data integrity:**
   - Run data validation scripts
   - Check critical collections

---

## Deployment Workflow Summary

### Standard Deployment (Low-Risk Changes)

```bash
# 1. Pre-deployment checks
flutter test
flutter analyze
git status

# 2. Deploy Firebase infrastructure
firebase deploy --only firestore:rules,firestore:indexes,storage:rules

# 3. Build application
flutter build apk --release --dart-define=ENV=production

# 4. Deploy to app stores
# (Follow app store submission process)

# 5. Monitor for 24 hours
# Check Firebase Console, Crashlytics, Performance Monitoring
```

### High-Risk Deployment (Database Schema Changes)

```bash
# 1. Deploy in stages
# Stage 1: Deploy backward-compatible schema changes
# Stage 2: Deploy application with migration logic
# Stage 3: Clean up old schema (after verification)

# 2. Monitor closely
# Watch for errors, performance degradation

# 3. Have rollback ready
# Keep previous version deployable
```

---

## Support & Resources

### Deployment Issues

**For issues during deployment:**
1. Check Firebase Console logs
2. Review [REMEDIATION_ACTION_PLAN.md](../audit/REMEDIATION_ACTION_PLAN.md)
3. Check security rules in [SECURITY_RULES_DEPLOYMENT.md](../archived/operations/SECURITY_RULES_DEPLOYMENT.md)
4. Consult Firebase documentation

### Emergency Contacts

- **Firebase Support**: Firebase Console → Support
- **Team Lead**: [Contact information]
- **On-Call Engineer**: [Rotation schedule]

---

## Deployment History

### Recent Deployments

| Date | Version | Changes | Deployer | Status |
|------|---------|---------|----------|--------|
| 2025-01-30 | v1.0.0 | Phase 4 performance optimizations | Dev Team | ✅ Success |
| 2025-01-15 | v0.9.5 | Security rules Phase 1 | Dev Team | ✅ Success |

---

**Last Updated**: January 30, 2025
**Next Review**: February 2025
**Maintained By**: DevOps Team
