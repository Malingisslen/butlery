# 🍽️ Butlery - Smart Recipe Management & Social Cooking Platform

A comprehensive Flutter application that transforms how you manage recipes, plan meals, and cook with friends. Built with modern architecture and best practices for production deployment.

## CI/CD Status

![Tests](https://github.com/Malingisslen/butlery/actions/workflows/test.yml/badge.svg)
![Build](https://github.com/Malingisslen/butlery/actions/workflows/build-validation.yml/badge.svg)
![Analysis](https://github.com/Malingisslen/butlery/actions/workflows/analyze.yml/badge.svg)
![Architecture](https://github.com/Malingisslen/butlery/actions/workflows/architecture-validation.yml/badge.svg)
![E2E Tests](https://github.com/Malingisslen/butlery/actions/workflows/e2e_tests.yml/badge.svg)
![Coverage](https://codecov.io/gh/Malingisslen/butlery/branch/main/graph/badge.svg)
![Flutter](https://img.shields.io/badge/Flutter-3.32.4-blue?logo=flutter)
![Production Ready](https://img.shields.io/badge/Production%20Ready-94%25-green)

## 🌟 Features

### 🥘 Core Recipe Management
- **Personal Recipe Collection** - Create, edit, and organize your recipes
- **Smart Import System** - Import from URLs, photos, and text with AI assistance  
- **Flexible Meal Planning** - Generate weekly menus and shopping lists
- **Multi-platform Sync** - Access your recipes on all devices

### 👥 Social Cooking Features  
- **Friends & Groups** - Connect with other cooking enthusiasts
- **Recipe Sharing** - Share recipes and get feedback from friends
- **Collaborative Menus** - Plan meals together with family and friends
- **Real-time Collaboration** - Cook together in real-time sessions
- **Social Comments & Ratings** - Engage with the cooking community

### 🛒 Smart Shopping
- **Auto-generated Shopping Lists** - From recipes and menus
- **Collaborative Shopping** - Share lists with family members
- **Ingredient Management** - Smart categorization and portion scaling
- **Cross-platform Sync** - Update lists from anywhere

## 🏗️ Architecture

### Technical Stack
- **Framework**: Flutter 3.x with Dart
- **Backend**: Firebase (Firestore, Auth, Storage, Cloud Functions)
- **Architecture**: MVVM + Repository Pattern
- **State Management**: Provider with ChangeNotifier
- **Dependency Injection**: GetIt service locator

### Architecture Status
- ✅ **Repository Pattern Implementation** - Clean data access abstraction
- ✅ **MVVM Architecture** - Proper separation between UI and business logic
- ✅ **Dependency Injection** - GetIt service locator with modular architecture
- ✅ **Firebase Integration** - Authentication, Firestore, Storage properly abstracted
- ✅ **Code Quality** - 0 warnings, 24 info-level issues (test helpers)
- ✅ **Security Foundation** - Permission validation system with audit logging
- ✅ **GDPR Compliance** - Articles 7, 15, 17, 20, 30 fully implemented and tested

## 🧪 Testing & Quality

### Test Coverage (Nov 2025)

| Layer | Coverage | Tests | Status |
|-------|----------|-------|--------|
| **ViewModels** | 100% | 60/60 | ✅ Perfect |
| **Services** | 96%+ | 125+ | ✅ Excellent |
| **Firebase Repositories** | 88% | 22/25 | ✅ Excellent |
| **GDPR Services** | 100% | 67/67 | ✅ Production Ready |

**Total Test Count**: 450+ test files
**GDPR Compliance**: ✅ All critical articles validated through testing

### Recent Achievements

**Phase 3: Repository Testing** (Nov 2025)
- 88% Firebase repository coverage (exceeded 70% goal)
- 102 test cases, 100% functional pass rate
- Friends, menu collaboration, and connectivity tested

**Phase 4: GDPR Services** (Nov 2025)
- 100% account services coverage
- 52 GDPR compliance tests, 100% passing
- Articles 7, 15, 17, 20, 30 fully validated
- **Production-ready for EU market** 🎉

**Documentation**: See `docs/testing/TESTING_DASHBOARD.md`

## 🚀 Getting Started

### Prerequisites
- Flutter SDK 3.0+ 
- Dart SDK 3.0+
- Firebase project with Firestore enabled
- Android Studio / VS Code with Flutter extensions

### WSL Development Setup
**CRITICAL for WSL users**: Always use Windows Flutter via cmd.exe due to line ending issues:

```bash
# Analysis
cmd.exe /c "flutter analyze"

# Run app
cmd.exe /c "flutter run"

# Build
cmd.exe /c "flutter build apk"
```

### Environment Setup
1. Clone the repository
2. Set up environment files (see `ENV_SETUP.md`)
3. Configure Firebase (see `FIREBASE_SECURITY_RULES.md`)
4. Install dependencies:
   ```bash
   flutter pub get
   ```

### Running the App
```bash
# Development
flutter run

# Production build
flutter build apk --release --dart-define=ENV=production
```

## 📊 Project Status (Updated January 31, 2025)

### Production Readiness: 94% Complete ✅

#### ✅ Completed Core Features
- **Recipe Management**: 100% complete - Create, edit, import from URLs/photos/text
- **Menu Planning**: 100% complete - Weekly menus, smart shopping lists
- **Firebase Backend**: 100% complete - Authentication, Firestore, real-time sync
- **Architecture Foundation**: MVVM + Repository pattern implemented
- **Social Infrastructure**: Friends, groups, sharing system implemented

#### 🔄 Current Implementation Status
- **Social Features**: 90% complete - Most social views and services implemented
  - ✅ Discovery Dashboard, Group Content Feed, Friends Management
  - ✅ Recipe/Menu sharing, Comments, Notifications infrastructure
  - ⚠️ Direct messaging status needs verification
  - ❌ Some collaborative features have placeholder implementations
- **Code Quality**: Good with improvement opportunities (235 analysis issues)
- **Testing Coverage**: ~76% - Major progress in Phase 5 + ViewModel expansion
  - ✅ Service layer: 96.2% coverage (125/130 services tested)
  - ✅ ViewModel layer: **100% coverage** (60/60 ViewModels tested) 🎯
  - ✅ Repository layer: 46.6% coverage (27/58 repositories tested)
  - ✅ Widget tests: 149 files
  - ✅ 0 analyze issues across test directory

#### 📋 Priority Areas for Production
- **Code Quality**: Address 235 Flutter analysis issues (mostly deprecated API usage)
- **Feature Completion**: Verify and complete social platform implementation
- **Repository Testing**: Expand repository test coverage (current: 46.6%, target: 70%)
- **Integration Testing**: Build critical user flow tests (current: 13 files, target: 30+)
- **Documentation**: Align documentation with actual implementation state

### Current Focus: Truth Reconciliation & Quality Improvement
**Immediate Priority**: Establish accurate project state and fix critical gaps
- Audit actual vs documented feature completeness
- Address code quality issues identified in analysis
- Complete any missing social platform components
- Build comprehensive testing infrastructure

## 📚 Documentation

### Essential Guides
- **`CLAUDE.md`** - Development workflow and standards
- **`docs/setup/ENV_SETUP.md`** - Environment configuration and security
- **`docs/security/FIREBASE_SECURITY_RULES.md`** - Security implementation details
- **`docs/architecture/NOTIFICATION_SYSTEM.md`** - Push notification architecture
- **`tasks/todo.md`** - Current roadmap and implementation plan

### Architecture Documentation
- **`docs/priority_2_completion_summary.md`** - Latest architectural improvements
- **`docs/architecture/`** - System architecture and design
- **`docs/security/`** - Security implementation and guidelines
- **`docs/setup/`** - Development environment setup
- **`docs/archived/`** - Historical reports and analysis
- **`reports/`** - Generated validation reports and metrics

## 🔐 Security

### Production-Ready Security Features
- ✅ **Environment-based Configuration** - API keys stored securely
- ✅ **Comprehensive Firebase Rules** - User-scoped data access
- ✅ **Repository-level Authorization** - Permission validation on all operations
- ✅ **Audit Logging** - Complete security event tracking
- ✅ **GDPR Compliance** - Data export, deletion, and privacy controls

## 🧪 Testing

### Current Status
- **Unit Tests**: ~76% coverage (451 test files)
  - Service layer: 96.2% coverage (125/130 services) ✅
  - ViewModel layer: **100% coverage** (60/60 ViewModels) 🎯
  - Repository layer: 46.6% coverage (27/58 repositories) ⚠️
- **Widget Tests**: 149 test files ✅
- **Integration Tests**: 13 test files ⚠️
- **Architecture Tests**: 100% passing ✅
- **Code Quality**: 0 analyze issues in test directory ✅

### Testing Expansion Targets
- **Repository Testing**: 70% coverage (add 14 more repositories)
- **Integration Testing**: 30+ critical user flows
- **E2E Testing**: Complete user journeys
- **Performance Testing**: Load and stress testing

## 🚀 Deployment

### Build Commands
```bash
# Android Production
flutter build apk --release --dart-define=ENV=production

# iOS Production  
flutter build ios --release --dart-define=ENV=production

# Web Production
flutter build web --release --dart-define=ENV=production
```

### Firebase Deployment
```bash
# Deploy security rules
firebase deploy --only firestore:rules

# Deploy cloud functions
firebase deploy --only functions
```

## 🤝 Contributing

### Development Workflow
1. Read `/CLAUDE.md` for development standards
2. Plan work in `/tasks/todo.md` with checkable items
3. Follow MVVM + Repository pattern
4. Maintain 500-line file size limit (use facade pattern)
5. Include comprehensive error handling and security validation

### Code Quality Standards
- **Single Responsibility Principle** enforced
- **Repository Pattern** for all data access
- **Comprehensive Permission Validation** required
- **Swedish Localization** throughout UI
- **Clean Architecture** with proper separation of concerns

## 📄 License

This project uses Firebase authentication and follows Flutter development best practices.

## 🎯 Roadmap

### Next Steps (Priority 3)
1. **Fix Critical TODOs** (2 weeks) - Unblock user workflows
2. **Complete Social Features** (2 weeks) - Direct messaging, group sharing
3. **Testing System** (4-6 weeks) - Comprehensive test coverage
4. **Production Launch** (1 week) - Final deployment and monitoring

### Success Criteria for Production
- ✅ Core recipe management system complete and functional
- ✅ Firebase backend integration stable and secure
- ✅ Social platform infrastructure implemented
- ⚠️ Code quality improvements needed (address 235 analysis issues)
- ✅ Testing coverage strong in critical areas (current: 45-50%, repository layer at 50%)
- ✅ Architecture foundation solid with room for optimization
- ⚠️ Documentation alignment with actual implementation

**Built with ❤️ using Flutter and Firebase**