# Butlery

**A comprehensive recipe management and meal planning platform built with Flutter and Firebase**

[![Flutter](https://img.shields.io/badge/Flutter-3.24+-blue.svg)](https://flutter.dev/)
[![Firebase](https://img.shields.io/badge/Firebase-Powered-orange.svg)](https://firebase.google.com/)
[![Test Coverage](https://img.shields.io/badge/Coverage-67.4%25-green.svg)](docs/testing/TESTING_DASHBOARD.md)
[![Architecture](https://img.shields.io/badge/Architecture-A+-brightgreen.svg)](docs/architecture/ARCHITECTURE_OVERVIEW.md)

---

## 📋 Overview

Butlery is a feature-rich recipe management application that helps users organize recipes, plan meals, create shopping lists, and collaborate with friends and family. Built with industry-leading architectural practices, Butlery combines powerful features with a clean, maintainable codebase.

### ✨ Key Features

**Recipe Management**
- 📸 **OCR Import** - Extract recipes from photos using intelligent text recognition
- 🔍 **Smart Search** - Find recipes by ingredients, tags, or full-text search
- 📝 **Rich Editing** - Comprehensive recipe editor with images, ingredients, instructions
- 🌐 **URL Import** - Import recipes from popular cooking websites

**Meal Planning**
- 📅 **Weekly Menus** - Plan meals for the week with drag-and-drop interface
- 🛒 **Auto Shopping Lists** - Generate shopping lists from menu plans
- 👥 **Family Sharing** - Share menus with household members

**Social Features**
- 👫 **Friends System** - Connect with other users and share recipes
- 💬 **Messaging** - Real-time chat and recipe discussions
- 🎁 **Recipe Sharing** - Share your favorite recipes with friends and groups
- 🤝 **Collaborative Lists** - Work together on shopping lists in real-time
- ⭐ **Ratings & Reviews** - Rate and review shared recipes

**Smart Features**
- 📱 **Offline Support** - Access your recipes even without internet
- 🔔 **Push Notifications** - Stay updated on shared content and messages
- 🌍 **Multi-Platform** - Android, iOS, Web, macOS, Windows support
- 🇸🇪 **Localization** - Swedish language support

---

## 🚀 Quick Start

### Prerequisites

Before you begin, ensure you have the following installed:

- **Flutter SDK** 3.24 or higher ([Install Flutter](https://flutter.dev/docs/get-started/install))
- **Dart SDK** 3.5 or higher (included with Flutter)
- **Firebase Account** ([Create Firebase Project](https://console.firebase.google.com/))
- **Git** for version control
- **IDE**: VS Code or Android Studio with Flutter extensions

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/butlery.git
   cd butlery
   ```

2. **Set up environment variables**
   ```bash
   # Copy the example environment file
   cp .env.example .env.development

   # Edit .env.development with your Firebase credentials
   # See docs/security/SECRETS_MANAGEMENT.md for detailed setup
   ```

3. **Install dependencies**
   ```bash
   flutter pub get
   ```

4. **Run the application**
   ```bash
   # Development mode
   flutter run

   # Or specify a platform
   flutter run -d chrome    # Web
   flutter run -d macos     # macOS
   flutter run -d windows   # Windows
   ```

### First-Time Setup

After installation, you'll need to:

1. Create a Firebase project (if you haven't already)
2. Enable Firestore, Authentication, Storage, and Cloud Messaging in Firebase Console
3. Configure your `.env.development` file with Firebase credentials
4. Deploy Firestore security rules: `firebase deploy --only firestore:rules`

For detailed setup instructions, see [docs/security/SECRETS_MANAGEMENT.md](docs/security/SECRETS_MANAGEMENT.md).

---

## 🏗️ Architecture

Butlery follows **Clean Architecture** principles with a clear separation of concerns:

### Architecture Pattern: MVVM + Repository

```
Views → ViewModels → Services → Repositories → Firebase
  ↓         ↓            ↓            ↓            ↓
  UI    Presentation   Business    Data       Backend
        Logic          Logic       Access
```

### Key Architectural Highlights

- ✅ **Clean Architecture** - Proper separation of concerns across layers
- ✅ **MVVM Pattern** - Views → ViewModels → Services → Repositories → Firebase
- ✅ **Modular DI** - 7 domain-focused modules using GetIt service locator
- ✅ **Repository Pattern** - Abstracted data access with permission validation
- ✅ **State Management** - Provider for UI state, ChangeNotifier for business logic
- ✅ **Firebase Backend** - Firestore, Auth, Storage, FCM, Analytics
- ✅ **Security First** - Comprehensive permission validation and audit logging
- ✅ **GDPR Compliant** - Complete implementation of Articles 7, 15, 17, 30

### Dependency Injection Modules

The application uses a modular DI system with 7 specialized modules:

1. **Core Module** - Authentication, Storage, Analytics
2. **Content Module** - Recipes, Menus, Import Services
3. **Social Module** - Friends, Sharing, Comments, Ratings
4. **Messaging Module** - Chat, Notifications
5. **Collaboration Module** - Real-time Features, Shopping Lists
6. **Performance Module** - Caching, Startup Optimization, Monitoring
7. **UI Module** - ViewModels, Navigation, UI State

**📚 For detailed architecture documentation, see [docs/architecture/ARCHITECTURE_OVERVIEW.md](docs/architecture/ARCHITECTURE_OVERVIEW.md)**

---

## 📁 Project Structure

```
lib/
├── core/                  # Core infrastructure
│   ├── base/             # Base classes (BaseService, BaseViewModel)
│   ├── di/               # Dependency injection modules
│   ├── exceptions/       # Custom exception types
│   ├── mixins/           # Reusable mixins (ErrorHandling, AsyncOperation)
│   └── utils/            # Utilities (Logger, Validation, Serialization)
├── models/               # Data models
│   ├── recipe_unified.dart
│   ├── menu.dart
│   ├── shopping_list.dart
│   └── ...
├── repositories/         # Data access layer
│   ├── interfaces/       # Repository interfaces
│   └── firebase/         # Firebase implementations
├── services/             # Business logic layer
│   ├── unified/          # Unified services (Recipe, Shopping, Menu)
│   ├── account/          # Account management (GDPR compliance)
│   ├── notifications/    # FCM notification service
│   └── ...
├── viewmodels/          # Presentation logic
│   ├── recipe/          # Recipe-related ViewModels
│   ├── social/          # Social feature ViewModels
│   └── ...
├── views/               # UI screens
│   ├── recipe/          # Recipe views
│   ├── social/          # Social feature views
│   └── ...
├── widgets/             # Reusable UI components
│   ├── common/          # Common widgets
│   └── ...
└── main.dart            # Application entry point

test/
├── unit/                # Unit tests (243 tests)
├── widget/              # Widget tests (149 tests)
├── integration/         # Integration tests (13 tests)
└── helpers/             # Test utilities and mocks
```

---

## 🧪 Testing

Butlery has comprehensive test coverage with 451 tests across multiple categories:

| Test Type | Count | Coverage |
|-----------|-------|----------|
| **Total Tests** | 451 | 67.4% |
| Unit Tests | 243 | - |
| Widget Tests | 149 | - |
| View Tests | 29 | - |
| Integration Tests | 13 | - |

### Running Tests

```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/unit/services/unified/unified_recipe_service_test.dart

# Run tests with coverage
flutter test --coverage

# View coverage report
genhtml coverage/lcov.info -o coverage/html
open coverage/html/index.html
```

**📊 For detailed test metrics and patterns, see:**
- [docs/testing/TESTING_DASHBOARD.md](docs/testing/TESTING_DASHBOARD.md)
- [docs/testing/TESTING_COMPLETE_GUIDE.md](docs/testing/TESTING_COMPLETE_GUIDE.md)

---

## 📖 Documentation

### Essential Guides

- **[CLAUDE.md](CLAUDE.md)** - Developer workspace configuration and coding standards
- **[Architecture Overview](docs/architecture/ARCHITECTURE_OVERVIEW.md)** - Complete architectural reference
- **[MVVM Pattern](docs/architecture/MVVM_PATTERN.md)** - Layer responsibilities and patterns
- **[Dependency Injection](docs/architecture/DI_SYSTEM.md)** - DI module structure and service access
- **[Firebase Integration](docs/architecture/FIREBASE_INTEGRATION.md)** - Firebase setup and security
- **[Testing Guide](docs/testing/TESTING_DASHBOARD.md)** - Test coverage and patterns
- **[Secrets Management](docs/security/SECRETS_MANAGEMENT.md)** - Environment variable setup

### Quick References

- **[Best Practices](docs/architecture/BEST_PRACTICES.md)** - Coding patterns and troubleshooting
- **[Deduplication Patterns](docs/architecture/DEDUPLICATION_PATTERNS.md)** - Reusable mixins and utilities
- **[Project Metrics](docs/architecture/PROJECT_METRICS.md)** - Current status and health scores

---

## 🤝 Contributing

We welcome contributions to Butlery! Before contributing, please:

1. **Read [CLAUDE.md](CLAUDE.md)** - Essential coding standards and architectural patterns
2. **Review [docs/architecture/BEST_PRACTICES.md](docs/architecture/BEST_PRACTICES.md)** - Best practices and patterns
3. **Check [docs/testing/TESTING_COMPLETE_GUIDE.md](docs/testing/TESTING_COMPLETE_GUIDE.md)** - Test patterns and examples

### Development Standards

- **Architecture**: Follow MVVM + Repository pattern
- **File Size**: Keep files under 500 lines (use facade/module pattern for larger features)
- **Testing**: Write tests for new features (target 67%+ coverage)
- **DI**: Use ServiceLocator.get<T>() for service access
- **Error Handling**: Use ErrorHandlingMixin or BaseService
- **State Management**: Use Provider for UI, ChangeNotifier for business logic
- **Documentation**: Document public APIs with examples

### Coding Style

- Follow official [Dart Style Guide](https://dart.dev/guides/language/effective-dart/style)
- Use `flutter analyze` to check code quality
- Format code with `dart format .` before committing
- Avoid emojis in code unless explicitly documenting
- Use `if (kDebugMode)` for debug-only logging

---

## 🔒 Security

Butlery takes security seriously:

- **Permission Validation** - All repository operations validate permissions
- **Audit Logging** - GDPR-compliant audit trail for security events
- **Firestore Security Rules** - Server-side access control
- **Secrets Management** - Environment-based credential storage
- **GDPR Compliance** - Full implementation of key GDPR articles

For security concerns, please see [docs/security/SECRETS_MANAGEMENT.md](docs/security/SECRETS_MANAGEMENT.md).

---

## 📊 Project Status

| Metric | Value | Grade |
|--------|-------|-------|
| **Overall Health** | 87% | B+ |
| **Architecture** | 100% | A+ |
| **Test Coverage** | 67.4% (451 tests) | B |
| **Social Platform** | 95% Complete | Near Production |
| **Production Ready** | 85% | High Confidence |
| **Codebase Size** | 669 Dart files | Well-organized |

**Current Phase**: P0 Critical Issues (7/15 complete - 46.7%)

See [docs/ultimate/MASTERPLAN.md](docs/ultimate/MASTERPLAN.md) for detailed remediation plan.

---

## 📄 License

[Add your license information here]

---

## 💬 Support

- **Issues**: [GitHub Issues](https://github.com/yourusername/butlery/issues)
- **Documentation**: [docs/](docs/)
- **Architecture Questions**: See [docs/architecture/ARCHITECTURE_OVERVIEW.md](docs/architecture/ARCHITECTURE_OVERVIEW.md)

---

**Built with ❤️ using Flutter and Firebase**
