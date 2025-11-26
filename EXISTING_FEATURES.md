# BUTLERY - FEATURE INDEX

**Last Updated:** 2025-11-25
**Status:** Production-Ready

---

## Codebase Statistics

| Category | Count |
|----------|-------|
| Views/Screens | 85 |
| Services | 183 |
| ViewModels | 90 |
| Models | 48 |
| **Total Files** | **406** |

---

## Feature Summary

**60+ features** across **15 categories**

---

## Features by Category

### 1. Recipe Management (12 features)
Personal library, detail view, search/filtering, URL import, social media import, photo/OCR import, archive import, file import, manual creation, sharing, real-time editing, comments/ratings

### 2. Menu Planning (4 features)
AI menu generation, menu management, collaborative planning, menu sharing

### 3. Shopping Lists (6 features)
Personal lists, item management, bulk operations, recipe integration, collaborative shopping, list export

### 4. Social Networking (10 features)
Friend management, user search, friend groups, discovery dashboard, user profiles, shared content browser, group management, group invitations, friend profiles, recent collaborators

### 5. Messaging (8 features)
Conversations list, direct messaging, group conversations, conversation management, message operations, content sharing, real-time features, push notifications

### 6. Notifications (6 features)
Notification types, Swedish localization, user preferences, offline queueing, FCM management, analytics

### 7. GDPR Compliance (4 features)
Consent management (Art. 7), data export (Art. 15/20), account deletion (Art. 17), audit logging (Art. 30)

### 8. Authentication & Security (6 features)
Email/password auth, password reset, permission system, role-based access, ownership validation, session management

### 9. Performance & Caching (8 features)
Intelligent caching, recipe caching, user profile caching, image optimization, startup optimization, Firebase performance monitoring, analytics integration, connection monitoring

### 10. Offline Support (4 features)
Offline mode, sync queue, conflict resolution, local storage

### 11. Storage & Media (5 features)
Firebase Storage, thumbnail generation, multi-image support, upload queue, upload speed tracking

### 12. Content Extraction (5 features)
Web scraping, platform detection, platform-specific parsing, OCR extraction, recipe detection

### 13. Deep Linking & Sharing (3 features)
Deep link handling, native share, receive share

### 14. Real-time Collaboration (5 features)
Real-time recipe editing, real-time menu planning, real-time shopping, presence tracking, conflict resolution

### 15. Architecture & Infrastructure (6 features)
Unified services (facade pattern), modular DI system (7 modules), MVVM architecture, Firebase backend, responsive design, code quality utilities

---

## Technical Foundation

- **Architecture:** MVVM + Repository Pattern + Modular DI
- **Backend:** Firebase (Auth, Firestore, Storage, FCM, Analytics, Performance)
- **Platform:** Flutter (mobile + web)
- **Target:** Swedish-speaking home cooks

---

## Routes (26 primary)

`/` Home | `/auth` Auth | `/laggTill` Add | `/importViaUrl` URL | `/photoImport` Photo | `/skrivSjalv` Manual | `/franSocialaMedier` Social | `/importFranArkiv` Archive | `/fileImport` File | `/receptDetalj` Detail | `/redigeraRecept` Edit | `/receiveShare` Receive | `/veckomeny` Menu | `/inkopslista` Shopping | `/discovery` Discovery | `/profile/edit` Profile | `/friends` Friends | `/friends/requests` Requests | `/shared` Shared | `/collaborative-shopping` Collab | `/menu-preview` Preview | `/create-shared-shopping` Create | `/friend-profile` Friend | `/shared-shopping-lists` Lists | `/messages` Messages | `/chat` Chat

---

**See CLAUDE.md for detailed architecture patterns, code standards, and development guidelines.**
