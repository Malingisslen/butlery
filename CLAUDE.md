# Claude Code Project Configuration

## Flutter Command Setup for WSL Environment

This project runs in a WSL (Windows Subsystem for Linux) environment with a hybrid Flutter setup.

### How to run Flutter commands:

**Method 1 (Recommended):** Use Windows Flutter via cmd.exe
```bash
cmd.exe /c "flutter COMMAND"
```

**Method 2:** Use the smart selector script
```bash
~/flutter-smart.sh COMMAND
```

### Examples:
- Analysis: `cmd.exe /c "flutter analyze"`
- Build: `cmd.exe /c "flutter build apk"`
- Run: `cmd.exe /c "flutter run"`
- Doctor: `cmd.exe /c "flutter doctor"`
- Test: `cmd.exe /c "flutter test"`

### Why this setup?
- Project is in Windows filesystem (`/mnt/c/Butlery/butlery`)
- WSL has line ending issues with bash scripts
- Windows Flutter works perfectly for this Windows-based project
- Linux Flutter is available at `~/flutter-linux/bin/flutter` but requires unzip installation

### Environment Details:
- Working Directory: `/mnt/c/Butlery/butlery`
- Windows Flutter: `/mnt/c/tools/flutter/bin/flutter`
- Linux Flutter: `~/flutter-linux/bin/flutter`
- Smart Script: `~/flutter-smart.sh`

## Project Status - COMPREHENSIVE UPDATE (2025-07-23)

### 🎉 MAJOR ACHIEVEMENTS COMPLETE:
- ✅ **Phase 7 Widget Restructuring COMPLETE** - 85% average file reduction with facade patterns
- ✅ **Social Platform 75% COMPLETE** - Core features (missing messaging, group sharing)
- ✅ **Push Notification System 100% COMPLETE** - FCM integration, all notification types
- ✅ **Repository Pattern COMPLETE** - Clean Firebase abstraction implemented
- ✅ **369 Dart files** in production-ready MVVM + Repository architecture
- ✅ All compilation errors fixed and Flutter analyze passes

### 🏗️ CURRENT ARCHITECTURE:
- **Pattern**: MVVM + Repository Pattern (Complete)
- **Services**: 60+ services with unified patterns and dependency injection
- **Notifications**: Complete FCM system with development logging approach
- **Widgets**: Facade patterns established (Phase 7 standard)
- **Social Features**: 75% complete (missing direct messaging, group content sharing)
- **Code Quality**: Single Responsibility Principle enforced

### 🎯 NEXT PRIORITY - Phase 9: Large File SRP Refactoring
- **Target**: 16 files over 500 lines need facade pattern treatment
- **Start with**: `realtime_menu.dart` (963 lines) - highest priority
- **Method**: Use proven facade patterns from Phase 7 success
- **Goal**: 70% file size reduction with 100% backward compatibility
- **Files identified**: realtime_menu.dart, unified_recipe_service.dart, realtime_recipe.dart, etc.

### 📋 DEVELOPMENT STANDARDS:
- **File Size Limit**: 500 lines max (use facade pattern for larger files)
- **Architecture**: Clean separation - Views → ViewModels → Services → Repositories → Firebase
- **Widget Pattern**: Facade pattern for large components (Phase 7 established)
- **Notification Integration**: Automatic via friends_management_operations, social_recipe_operations
- **Testing**: Development logging approach for notifications (production upgrade ready)

### 🚀 PRODUCTION READINESS:
- Social platform with notifications: **75% complete** (missing direct messaging, group content sharing)
- Architecture optimization: **Phase 7 complete, Phase 9 next**
- Social completion: **Phase 18.6** (6-8 hours) - Direct messaging + group sharing
- Deployment ready: **Yes** (with 1-hour notification upgrade to production)

### 📋 REMAINING SOCIAL FEATURES FOR 100%:
- **Direct messaging** - User-to-user chat functionality
- **Group content sharing** - Share all content types to groups  
- **Enhanced discovery** - Friend suggestions, better search

Last Updated: 2025-07-23 (Major documentation overhaul complete)