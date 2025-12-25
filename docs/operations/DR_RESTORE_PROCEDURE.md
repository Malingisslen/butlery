# Disaster Recovery Restore Procedure

**Last Updated**: YYYY-MM-DD
**Last Tested**: YYYY-MM-DD
**Test Result**: Pass/Fail

## Prerequisites

### Required Access

- [ ] Firebase Console admin access
- [ ] Google Cloud Console access
- [ ] Cloud Storage bucket access (butlery-app-1-backups)
- [ ] Firebase CLI installed and authenticated

### Required Tools

```bash
# Firebase CLI
npm install -g firebase-tools
firebase login

# Google Cloud SDK (optional)
gcloud auth login
```

## Scenario 1: Restore from Daily Backup

### Step 1: Locate Latest Backup

```bash
# List available backups
gsutil ls -l gs://butlery-app-1-backups/

# Or via Cloud Console:
# 1. Go to console.cloud.google.com
# 2. Navigate to Cloud Storage -> butlery-app-1-backups
# 3. Sort by date, select most recent
```

### Step 2: Download Backup

```bash
# Download to local machine
gsutil cp gs://butlery-app-1-backups/[BACKUP_FILE] ./restore/

# Extract if compressed
gunzip [BACKUP_FILE].gz
```

### Step 3: Validate Backup Integrity

```bash
# Check file is valid JSON
cat [BACKUP_FILE] | jq . > /dev/null && echo "Valid JSON"

# Check expected collections exist
cat [BACKUP_FILE] | jq 'keys'
```

### Step 4: Restore to Staging First

```bash
# NEVER restore directly to production without testing

# Set staging project
firebase use butlery-app-staging

# Import data
firebase firestore:import ./restore/[BACKUP_FOLDER]
```

### Step 5: Verify Staging Data

- [ ] User count matches expected
- [ ] Sample recipes load correctly
- [ ] Authentication works
- [ ] Critical features functional

### Step 6: Restore to Production

```bash
# Only after staging verification passes!

# Set production project
firebase use butlery-app-1

# Import data
firebase firestore:import ./restore/[BACKUP_FOLDER]
```

### Step 7: Post-Restore Verification

- [ ] Firebase Console shows restored collections
- [ ] App connects successfully
- [ ] Sample user can log in
- [ ] Recipes load correctly
- [ ] Shopping lists accessible

## Scenario 2: Firebase Storage Restore

### Note: Storage backup not currently automated

### Manual Steps

1. Locate any local copies of user images
2. Re-upload via Firebase Console or CLI
3. Update Firestore references if URLs changed

## Scenario 3: Complete Project Deletion

### Step 1: Contact Google Support

- Within 30 days, project may be recoverable
- Open support ticket immediately
- Provide project ID: butlery-app-1

### Step 2: If Unrecoverable

1. Create new Firebase project
2. Configure all services (Auth, Firestore, Storage, Functions)
3. Deploy security rules from git
4. Restore from backup (if available)
5. Update app configuration (google-services.json, etc.)
6. Release app update with new configuration

## Post-Incident

### Documentation Required

- [ ] Incident timeline created
- [ ] Root cause identified
- [ ] Data loss quantified
- [ ] User communication sent
- [ ] Postmortem scheduled

### Lessons Learned Template

```markdown
## Incident: [DATE] - [TITLE]

### Timeline
- HH:MM - Issue detected
- HH:MM - Response started
- HH:MM - Root cause identified
- HH:MM - Recovery complete

### Impact
- Users affected: X
- Data lost: [Description]
- Downtime: X hours

### Root Cause
[Description]

### Action Items
- [ ] [Preventive measure 1]
- [ ] [Preventive measure 2]
```
