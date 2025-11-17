# ADR-003: Use Firebase as Backend Platform

**Status**: Accepted
**Date**: 2024-Q2 (Retroactive documentation 2025-11-17)
**Deciders**: Core development team
**Technical Story**: Need scalable backend for recipes, social features, real-time collaboration

---

## Context

Butlery requires a comprehensive backend platform to support:

### Core Features
- **User Authentication** - Email/password, Google Sign-In, password reset
- **Recipe Storage** - CRUD operations for 1000s of recipes per user
- **Image Storage** - Recipe photos (upload, download, compression)
- **Social Features** - Friends, sharing, comments, ratings, messaging
- **Real-Time Collaboration** - Live co-editing of recipes and shopping lists
- **Push Notifications** - Friend requests, messages, shared content alerts
- **Analytics** - User behavior, feature adoption, crash reporting
- **Offline Support** - Local caching, sync when online

### Requirements
- **Scalability**: Support 10K+ users without infrastructure management
- **Security**: Row-level security, authentication, authorization
- **Development Speed**: Rapid prototyping and iteration
- **Cost Efficiency**: Pay-per-use, no fixed server costs
- **GDPR Compliance**: EU data residency, audit logging, data export/deletion
- **Real-Time**: Sub-second updates for collaborative features
- **Mobile-First**: Excellent Flutter SDK support

### Constraints
- Small team (limited backend expertise)
- Budget constraints (early-stage product)
- Need production deployment in 3-6 months
- EU market focus (GDPR critical)

---

## Decision

**We will use Firebase as the backend platform, leveraging:**

1. **Firebase Authentication** - User sign-in and session management
2. **Cloud Firestore** - NoSQL document database for all app data
3. **Firebase Storage** - Image hosting for recipe photos
4. **Cloud Messaging (FCM)** - Push notifications
5. **Firebase Analytics** - User behavior tracking
6. **Crashlytics** - Crash reporting and error monitoring
7. **Performance Monitoring** - App performance metrics
8. **App Check** - Bot protection and abuse prevention

**Architecture**:
```
┌──────────────┐
│ Flutter App  │
└──────┬───────┘
       │ (Repository Layer - see ADR-001)
       ▼
┌──────────────────────────────────────────┐
│          FIREBASE SERVICES               │
├──────────────────────────────────────────┤
│  Auth  │ Firestore │ Storage │ FCM │ ... │
└──────────────────────────────────────────┘
       │
       ▼
┌──────────────┐
│  User Data   │
│  (EU Region) │
└──────────────┘
```

---

## Alternatives Considered

### 1. **Custom REST API (Node.js + PostgreSQL)**
- ❌ **Rejected**: Requires infrastructure management
- ❌ Need DevOps expertise (Docker, Kubernetes, load balancing)
- ❌ Higher initial and ongoing costs (server hosting)
- ❌ Slower development (must build auth, storage, notifications from scratch)
- ⚠️ Better control and flexibility, but not worth the overhead
- **Verdict**: Too much overhead for early-stage product

### 2. **Supabase (Open-source Firebase alternative)**
- ❌ **Rejected**: Smaller community and ecosystem
- ❌ Less mature Flutter SDK (launched 2021 vs Firebase 2011)
- ❌ Fewer integrated services (no native crash reporting, performance monitoring)
- ✅ PostgreSQL (relational) might be better for some queries
- ✅ Open-source (no vendor lock-in)
- ⚠️ Promising, but too risky for production
- **Verdict**: Reconsider in 2-3 years when ecosystem matures

### 3. **AWS Amplify**
- ❌ **Rejected**: Steeper learning curve (AWS complexity)
- ❌ More configuration required (Cognito, AppSync, S3, DynamoDB, etc.)
- ❌ Less Flutter-specific documentation
- ❌ Higher complexity for small team
- ✅ More powerful and flexible for enterprise
- **Verdict**: Overkill for current needs

### 4. **Parse Server (Open-source BaaS)**
- ❌ **Rejected**: Requires self-hosting
- ❌ Smaller community since Facebook shutdown (2017)
- ❌ Fewer integrated services
- ❌ Less active development
- **Verdict**: Too risky and outdated

### 5. **Appwrite (Open-source BaaS)**
- ❌ **Rejected**: Very new (launched 2019)
- ❌ Smaller ecosystem
- ❌ Requires self-hosting
- ❌ Less mature Flutter SDK
- ⚠️ Interesting project, but too immature
- **Verdict**: Monitor for future consideration

---

## Consequences

### Positive

✅ **Development Speed**:
- Built-in authentication (no custom auth system needed)
- Firestore SDK handles offline sync automatically
- FCM push notifications ready out-of-the-box
- Firebase Console for data visualization and debugging

✅ **Scalability**:
- Auto-scaling (0 to millions of users)
- No infrastructure management
- Global CDN for Storage
- Firestore handles 10M+ documents per collection

✅ **Security**:
- Firebase Security Rules (1,164 lines, 30+ rules in production)
- Row-level security with user-based rules
- Built-in authentication and authorization
- GDPR-compliant data residency (EU region)

✅ **Real-Time Support**:
- Firestore real-time listeners (critical for collaboration features)
- Sub-second updates for live co-editing
- Optimistic updates with automatic conflict resolution

✅ **Offline Support**:
- Firestore offline persistence built-in
- Automatic sync when online
- Local cache reduces data usage

✅ **Integrated Services**:
- Analytics, Crashlytics, Performance Monitoring in one platform
- Single authentication system across all services
- Unified Firebase Console

✅ **Cost Efficiency (Early Stage)**:
- Generous free tier (Spark plan)
- Pay-per-use (no fixed server costs)
- Predictable scaling costs

✅ **Flutter Support**:
- Official Flutter plugins (`firebase_core`, `cloud_firestore`, etc.)
- Excellent documentation
- Active community support

✅ **GDPR Compliance**:
- EU data residency option
- Built-in audit logging (Firestore audit logs)
- Data export/deletion APIs (see AccountDeletionService, DataExportService)

### Negative

⚠️ **Vendor Lock-In**:
- Firestore query syntax is proprietary
- Difficult to migrate to another backend (would require rewriting 30 repositories)
- **Mitigation**: Repository pattern (ADR-001) provides abstraction layer
- **Mitigation**: Risk acceptable for early-stage product

⚠️ **Cost Scaling (Large Scale)**:
- Firestore reads/writes can get expensive at 100K+ active users
- Example: 1M reads/day = ~$0.06/day = ~$18/month (manageable)
- Example: 10M reads/day = ~$180/month (still reasonable)
- **Mitigation**: Caching strategy (Service layer handles caching)
- **Mitigation**: Denormalization to reduce reads (e.g., recipe rating counts)

⚠️ **Query Limitations**:
- No JOINs (NoSQL)
- Limited full-text search (requires third-party like Algolia)
- Composite index required for complex queries
- **Mitigation**: Denormalize data (acceptable for our use case)
- **Mitigation**: Client-side filtering for simple searches

⚠️ **NoSQL Learning Curve**:
- Team must learn Firestore data modeling
- Different mindset from SQL (denormalization, subcollections)
- **Mitigation**: Comprehensive documentation in [FIREBASE_INTEGRATION.md](../architecture/FIREBASE_INTEGRATION.md)

⚠️ **Security Rules Complexity**:
- Firestore Security Rules are custom language (not SQL/JavaScript)
- 1,164 lines of rules for production app (complex to maintain)
- **Mitigation**: Well-documented in firestore.rules
- **Mitigation**: Integration tests for security rules

⚠️ **Cold Start Latency**:
- Cloud Functions can have 1-3s cold start
- **Mitigation**: Use Firestore triggers sparingly
- **Mitigation**: Keep logic in client-side (Flutter app)

⚠️ **Limited Regional Control**:
- Firestore multi-region limited to US, EU (not per-country)
- EU region includes all of EU (can't restrict to specific countries)
- **Mitigation**: Acceptable for GDPR (EU region sufficient)

---

## Implementation Guidelines

### 1. Repository Pattern (Critical)
```dart
// ✅ CORRECT: Use repository abstraction
class RecipeRepository {
  final FirebaseFirestore _firestore;

  Future<Recipe> getRecipe(String id) async {
    final doc = await _firestore.collection('recipes').doc(id).get();
    return Recipe.fromFirestore(doc);
  }
}

// ❌ WRONG: Direct Firebase access in service/view
final doc = await FirebaseFirestore.instance.collection('recipes').doc(id).get();
```
- **Rule**: NEVER use `FirebaseFirestore.instance` outside repositories
- **Benefit**: Easy to mock for tests, potential to migrate backend

### 2. Security Rules (Essential)
- Every Firestore collection MUST have security rules
- Validate ownership, permissions, required fields
- See [firestore.rules](../../firestore.rules) for production rules

### 3. Denormalization for Performance
```dart
// Store rating count and average on recipe document
// Instead of querying ratings collection every time
{
  "recipeId": "123",
  "title": "Pasta",
  "ratingCount": 42,          // Denormalized from ratings collection
  "averageRating": 4.5,       // Denormalized from ratings collection
  "ratingDistribution": {...} // Denormalized from ratings collection
}
```
- Reduces reads from 10,000 → 1 (10,000x cost reduction)
- See [Issue #007 implementation](../../docs/ultimate/MASTERPLAN.md#007)

### 4. Caching Strategy
- Service layer handles caching (in-memory, local storage)
- Reduces Firebase reads by 60-80%
- Firestore offline persistence for additional caching

### 5. GDPR Compliance
- Store data in EU region: `europe-west1`
- Implement data export (DataExportService)
- Implement account deletion (AccountDeletionService)
- Audit logging (FirebaseAuditRepository)

---

## Migration Path (If Needed)

If Firebase becomes too expensive or limiting:

1. **Phase 1**: Add caching layer (reduce Firestore reads by 80%)
2. **Phase 2**: Move read-heavy data to CDN/cache (e.g., recipe images already in Storage CDN)
3. **Phase 3**: Hybrid approach (keep auth on Firebase, move data to PostgreSQL)
4. **Phase 4**: Full migration (rewrite 30 repositories)

**Current Assessment**: Firebase is cost-effective for current scale (0-100K users). No migration needed.

---

## Performance Metrics

**Current Production Metrics**:
- Average Firestore read latency: **50-150ms**
- Average Firestore write latency: **100-300ms**
- Storage image download: **200-500ms** (with caching)
- Auth sign-in latency: **500-1000ms**
- Real-time listener latency: **<100ms**

**Cost Estimates** (as of 2025):
- **0-1K users**: $0-10/month (free tier)
- **1K-10K users**: $10-50/month
- **10K-100K users**: $50-500/month
- **100K-1M users**: $500-5000/month

---

## References

- **Implementation Guide**: [docs/architecture/FIREBASE_INTEGRATION.md](../architecture/FIREBASE_INTEGRATION.md)
- **Security Rules**: [firestore.rules](../../firestore.rules) (1,164 lines)
- **GDPR Services**: ConsentService, DataExportService, AccountDeletionService, FirebaseAuditRepository
- **Firebase Docs**: [firebase.google.com/docs](https://firebase.google.com/docs)
- **Firestore Best Practices**: [firebase.google.com/docs/firestore/best-practices](https://firebase.google.com/docs/firestore/best-practices)
- **Pricing**: [firebase.google.com/pricing](https://firebase.google.com/pricing)

---

## Related ADRs

- [ADR-001: Use MVVM + Repository Pattern](ADR-001-mvvm-repository-pattern.md) - Abstracts Firebase behind repositories
- [ADR-004: Organize DI into 7 Domain Modules](ADR-004-seven-domain-modules.md) - Firebase services registered in Core Module
