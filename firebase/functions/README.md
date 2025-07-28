# Firebase Cloud Functions

This directory contains Firebase Cloud Functions for the Butlery application.

## Contents

- **`notification_cloud_functions.js`** - Cloud functions for push notifications
- **`package.json`** - Node.js dependencies for cloud functions
- **`package-lock.json`** - Lock file for dependencies
- **`node_modules/`** - Installed Node.js packages

## Setup

1. Install Firebase CLI:
   ```bash
   npm install -g firebase-tools
   ```

2. Login to Firebase:
   ```bash
   firebase login
   ```

3. Initialize functions (if not already done):
   ```bash
   firebase init functions
   ```

4. Install dependencies:
   ```bash
   cd firebase/functions
   npm install
   ```

## Deployment

Deploy functions to Firebase:
```bash
firebase deploy --only functions
```

Deploy specific function:
```bash
firebase deploy --only functions:functionName
```

## Development

Run functions locally:
```bash
firebase emulators:start --only functions
```

## Functions Overview

### Notification Functions
- Handle push notification delivery
- Batch notification processing
- User preference management

## Environment Variables

Set environment variables for functions:
```bash
firebase functions:config:set someservice.key="THE API KEY"
```

## Logs

View function logs:
```bash
firebase functions:log
```

## Documentation

For more information, see:
- [Firebase Functions Documentation](https://firebase.google.com/docs/functions)
- `/NOTIFICATION_SYSTEM.md` - Notification system overview