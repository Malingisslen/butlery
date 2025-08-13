# Architecture Documentation

This directory contains architectural documentation for the Butlery project.

## Contents

- **`NOTIFICATION_SYSTEM.md`** - Complete push notification system architecture
  - FCM integration and token management
  - Notification types and templates
  - Localization support (Swedish/English)
  - Offline notification queuing
  - Development vs production configuration

## Architecture Overview

### 🏗️ Current Architecture
- **Pattern**: MVVM + Repository Pattern
- **Backend**: Firebase (Firestore, Auth, Storage, Cloud Functions)
- **State Management**: Provider with ChangeNotifier
- **Dependency Injection**: GetIt service locator

### 📊 Architecture Status (Updated January 30, 2025)
- **Repository Pattern Implemented** - Clean data access abstraction layer
- **MVVM Architecture** - Proper separation between UI and business logic
- **Firebase Abstraction** - Services use repository layer (some exceptions exist)
- **Code Quality Attention Needed** - 235 Flutter analysis issues to address

## System Components

### Core Layers
1. **Views** - Flutter UI components
2. **ViewModels** - Business logic and state management
3. **Services** - Business operations and coordination
4. **Repositories** - Data access abstraction
5. **Firebase** - Backend data storage and authentication

### Key Architectural Decisions
- **Repository Pattern**: All Firebase access abstracted through repositories
- **Permission Validation**: Comprehensive authorization on all operations
- **Service Layer**: Clean separation between business logic and data access
- **Dependency Injection**: Proper inversion of control throughout

## Related Documentation

- **Setup**: See `../setup/` for development environment
- **Security**: See `../security/` for security implementation
- **Testing**: See `../testing/` for test infrastructure documentation
- **Development Guide**: See `../development_guide.md` for coding standards