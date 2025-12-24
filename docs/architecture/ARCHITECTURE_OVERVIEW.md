# Butlery Architecture Overview

**Complete architectural reference for the Butlery recipe management application**

**Last Updated**: January 2025
**Architecture Assessment**: ✅ EXCELLENT (A+ Grade)
**Current Health**: 87% (Production-Ready)

---

## Quick Navigation

This guide is split into focused documents for easy navigation:

### Core Architecture
- **[MVVM Pattern](MVVM_PATTERN.md)** - Views → ViewModels → Services → Repositories → Firebase
- **[Dependency Injection](DI_SYSTEM.md)** - 7 modular DI modules with GetIt service locator
- **[Firebase Integration](FIREBASE_INTEGRATION.md)** - Configuration, repositories, and security
- **[Drift Storage](DRIFT_STORAGE.md)** - Offline-first local storage with SQLite

### Systems & Features
- **[Notification System](NOTIFICATION_SYSTEM.md)** - Complete FCM integration
- **[Best Practices](BEST_PRACTICES.md)** - Patterns, troubleshooting, and guidelines
- **[Project Metrics](PROJECT_METRICS.md)** - Current status, test coverage, and health scores

---

## Executive Summary

The Butlery application is a **comprehensive recipe management and meal planning platform** built with Flutter and Firebase. The project demonstrates **industry-leading architectural practices** with:

- ✅ **Clean Architecture** - Proper separation of concerns across layers
- ✅ **MVVM + Repository Pattern** - Testable and maintainable structure
- ✅ **Modular Dependency Injection** - 7 domain-focused modules with GetIt
- ✅ **Firebase Integration** - Production-ready backend with security rules
- ✅ **95% Complete Social Platform** - Friends, messaging, collaboration
- ✅ **Comprehensive Test Coverage** - 445 tests (66.5% coverage)
- ✅ **Complete Notification System** - FCM integration with development logging

### Current Project Status

| Metric | Value | Status |
|--------|-------|--------|
| **Overall Health** | 87% | B+ Grade |
| **Architecture** | 100% | A+ Grade |
| **Test Coverage** | 66.5% (445 tests) | B Grade |
| **Social Platform** | 95% Complete | Near Production |
| **Production Ready** | 85% | High Confidence |
| **Codebase Size** | 669 Dart files | Well-organized |

> **📊 See [Project Metrics](PROJECT_METRICS.md) for detailed status and [testing/TESTING_DASHBOARD.md](../testing/TESTING_DASHBOARD.md) for test metrics**

---

## System Overview

### Clean Architecture Layers

The Butlery application follows Clean Architecture principles with clear separation of concerns:

```
┌─────────────────────────────────────────────────────────────────┐
│                        PRESENTATION LAYER                       │
│  Views (60 files), ViewModels (60 files), Widgets (150 files)  │
│  • User interface components                                    │
│  • State management with Provider                               │
│  • No direct business logic                                     │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                         SERVICE LAYER                           │
│          Services (150 files), Business Logic                   │
│  • Business logic orchestration                                 │
│  • State management with ChangeNotifier                         │
│  • Coordinates repository operations                            │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                       REPOSITORY LAYER                          │
│       Repositories (30 files), Data Access Objects              │
│  • Firebase Firestore access                                    │
│  • Permission validation                                        │
│  • Audit logging (GDPR compliance)                              │
└─────────────────────────┬───────────────────────────────────────┘
                          │
┌─────────────────────────▼───────────────────────────────────────┐
│                       FIREBASE BACKEND                          │
│     Firestore, Storage, Auth, FCM, Analytics                   │
│  • Cloud data storage                                           │
│  • Authentication & authorization                               │
│  • Push notifications                                           │
└─────────────────────────────────────────────────────────────────┘
```

### Core Architectural Principles

1. **Single Responsibility** - Each class has one clear purpose
2. **Dependency Inversion** - Depend on abstractions, not concrete implementations
3. **Separation of Concerns** - Clear boundaries between layers
4. **Testability First** - All layers designed for unit testing
5. **Progressive Disclosure** - Files <500 lines using facade/module patterns

### Technology Stack

**Frontend:**
- Flutter 3.x (Dart)
- Provider for state management
- ChangeNotifier for reactive state

**Backend:**
- Firebase Firestore (cloud database)
- Firebase Auth (authentication)
- Firebase Storage (file storage)
- Firebase Cloud Messaging (notifications)
- Firebase Analytics (metrics)
- Drift/SQLite (local offline storage)

**Development:**
- GetIt for dependency injection
- Mockito for testing
- Faker for test data generation
- FakeFirestore for repository tests

---

## Quick Links

### For Developers

**Getting Started:**
- Read [MVVM Pattern](MVVM_PATTERN.md) to understand the architecture
- Review [Dependency Injection](DI_SYSTEM.md) for service access patterns
- Check [Best Practices](BEST_PRACTICES.md) for development guidelines

**Implementing Features:**
- Follow patterns in [MVVM Pattern](MVVM_PATTERN.md)
- Use [Firebase Integration](FIREBASE_INTEGRATION.md) for backend access
- Reference [Best Practices](BEST_PRACTICES.md) for common scenarios

**Troubleshooting:**
- Check [Best Practices](BEST_PRACTICES.md) troubleshooting section
- Review [Project Metrics](PROJECT_METRICS.md) for known issues

### For Architects

**System Design:**
- [MVVM Pattern](MVVM_PATTERN.md) - Complete 4-layer architecture
- [Dependency Injection](DI_SYSTEM.md) - 7-module DI system
- [Firebase Integration](FIREBASE_INTEGRATION.md) - Backend architecture
- [Drift Storage](DRIFT_STORAGE.md) - Offline-first local storage

**Quality Metrics:**
- [Project Metrics](PROJECT_METRICS.md) - Health scores and coverage
- [../testing/TESTING_DASHBOARD.md](../testing/TESTING_DASHBOARD.md) - Detailed test metrics

---

## Documentation Updates

This architecture documentation was split into focused guides in **January 2025** for improved navigation and maintainability. Each guide is designed to be:

- **Focused**: Single topic, <500 lines
- **Actionable**: Code examples and patterns
- **Current**: Reflects actual codebase (verified Jan 2025)
- **Linked**: Cross-references to related topics

**Maintenance**: Review quarterly and update metrics/patterns as the codebase evolves.
