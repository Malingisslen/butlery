# Butlery Architecture Guide

**This documentation has been split into focused guides for easier navigation.**

**Last Updated**: January 2025

---

## 📚 Architecture Documentation

The architecture documentation is now organized into focused guides:

### Start Here
- **[Architecture Overview](ARCHITECTURE_OVERVIEW.md)** - System overview, quick navigation, and executive summary

### Core Architecture
- **[MVVM Pattern](MVVM_PATTERN.md)** - Complete 4-layer architecture (Views → ViewModels → Services → Repositories → Firebase)
- **[Dependency Injection System](DI_SYSTEM.md)** - 7 modular DI modules with GetIt service locator
- **[Firebase Integration](FIREBASE_INTEGRATION.md)** - Configuration, repositories, and security

### Systems & Features
- **[Notification System](NOTIFICATION_SYSTEM.md)** - Complete FCM integration with development logging
- **[Best Practices](BEST_PRACTICES.md)** - Development guidelines, patterns, and troubleshooting
- **[Project Metrics](PROJECT_METRICS.md)** - Current status, test coverage, and health scores

---

## Why the Split?

The original ARCHITECTURE_GUIDE.md was **2,688 lines** - too large for easy navigation and quick reference. The new structure provides:

- ✅ **Focused Content**: Each guide covers one topic (<500 lines)
- ✅ **Easy Navigation**: Find what you need quickly
- ✅ **Progressive Disclosure**: Start with overview, drill into details
- ✅ **Better Maintainability**: Update specific topics independently

---

## Quick Links

**For Developers:**
- New to Butlery? → Start with [Architecture Overview](ARCHITECTURE_OVERVIEW.md)
- Adding a feature? → Follow [MVVM Pattern](MVVM_PATTERN.md) workflow
- Need a service? → See [DI System](DI_SYSTEM.md) for service access
- Troubleshooting? → Check [Best Practices](BEST_PRACTICES.md) guide

**For Architects:**
- System design → [MVVM Pattern](MVVM_PATTERN.md) + [DI System](DI_SYSTEM.md)
- Backend architecture → [Firebase Integration](FIREBASE_INTEGRATION.md)
- Quality metrics → [Project Metrics](PROJECT_METRICS.md)

---

## Original Documentation

The original 2,688-line guide has been backed up to `ARCHITECTURE_GUIDE.md.backup` and remains available for reference.

**Split Date**: January 2025
**Reason**: Improve navigation and maintainability
**Benefit**: Each guide is now <500 lines and focused on a single topic

---

**Start your journey**: [Architecture Overview](ARCHITECTURE_OVERVIEW.md)
