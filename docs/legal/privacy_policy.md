# Privacy Policy

**Status:** Draft. To be reviewed by legal counsel and published at a stable URL (planned: `butlery.se/privacy` once BUT-680 lands).
**Last updated:** 2026-05-21
**Effective:** TBD upon publication.

## 1. Who we are

Butlery is a recipe management application operated by Malin Gisslén ("we", "us"). This Policy explains how we collect, use, store, and share your personal data, and the rights you have under the EU General Data Protection Regulation (GDPR).

If you have questions, contact: malin.kallen1@gmail.com.

## 2. What data we collect

| Category | Examples | Source |
|----------|----------|--------|
| Account data | Email, display name, password hash, MFA enrollment | You |
| Profile data | Avatar image, bio, language preference | You |
| Allergen & dietary preferences | Lactose intolerance, vegetarian, etc. | You |
| Recipes | Recipe content you create, import, or photograph | You |
| Social graph | Friend connections, group memberships, shared content, messages | You |
| Usage analytics | Feature usage events, session metadata, anonymous device identifier | App |
| Crash diagnostics | Stack traces, device model, OS version | App |
| Cooking activity | Recipes cooked, timestamps (used to surface "recent cooks" UI) | App |

We do NOT collect: precise geolocation, payment data (no monetization yet), microphone, contacts, or photo library beyond what you explicitly import.

## 3. Allergens and dietary preferences

Allergen and dietary preference data may be treated as health-adjacent data under Apple's iOS Privacy Manifest framework (declared as `NSPrivacyCollectedDataTypeHealthAndFitness`). We use this data solely to (a) filter recipes you should avoid and (b) personalize menu suggestions. We do not share allergen data with third parties beyond the processors listed in Section 7.

## 4. Legal basis (GDPR Article 6)

| Processing | Legal basis |
|-----------|-------------|
| Account creation + authentication | Contract (Art. 6(1)(b)) |
| Recipe & social data storage | Contract |
| Crash reporting | Legitimate interest (Art. 6(1)(f)) — service stability |
| Analytics (anonymized) | Legitimate interest |
| Allergen filtering | Consent (Art. 9(2)(a)) given on first onboarding |

## 5. On-device AI processing

We use on-device ONNX machine learning models for:

- **Ingredient recognition (NER):** identifying ingredient names in free-text recipes.
- **Recipe line classification:** distinguishing ingredient lines from instruction lines during import.

These models run locally on your device. The input text and images processed by these models are **not transmitted to our servers** as part of model inference. The models themselves are downloaded from our content delivery network (Firebase Storage) once per version and verified by SHA-256 hash before use.

Cloud-based AI processing (Mistral via Vertex AI) is used for recipe parsing from URLs, OCR enhancement, and menu generation. When you trigger these features, the input is sent to Google Cloud's Vertex AI in the `europe-west1` region. We do not retain the model inputs beyond the call.

## 6. Data retention

- **Active account data:** retained for as long as your account exists.
- **Deleted account data:** processed within **30 days** of your deletion request, except:
  - **Audit logs:** retained for **365 days** under the GDPR Article 17(3)(b) derogation (legal compliance with our cascade-delete logging obligations).
  - **Backups:** containing deleted data expire within **30 days** of the deletion request.
- **Crash reports:** 90 days.
- **Analytics events:** 14 months (Firebase Analytics default).

## 7. Sub-processors

We share necessary data with the following sub-processors. All are GDPR-compliant and bound by data processing agreements.

| Sub-processor | Purpose | Data category | Region |
|---------------|---------|---------------|--------|
| Google Cloud — Firestore | Primary database | All user data | europe-west1 |
| Google Cloud — Authentication | Account auth + MFA | Email, password hash, MFA token | Global (EU-routed) |
| Google Cloud — Storage | Recipe images, exports | User-uploaded images | europe-west1 |
| Google Cloud — Cloud Functions | Server-side logic | Account deletion, content moderation | europe-west1 |
| Google Cloud — Vertex AI (Mistral) | Recipe parsing, OCR, menu generation | Inputs you submit to AI features | europe-west1 |
| Google Cloud — Vision API | Image moderation (SafeSearch) | Uploaded images | europe-west1 |
| Google Cloud — reCAPTCHA Enterprise | App Check (anti-abuse) | Device attestation token | Global |
| Firebase Crashlytics | Crash reports | Stack traces, device metadata | Global |
| Firebase Analytics + GA4 | Anonymous usage metrics | Event names, session IDs | Global |

**Deferred (not yet active):**

| Sub-processor | When | Status |
|---------------|------|--------|
| Algolia | Recipe full-text search | Feature-flagged off; pending evaluation |
| RevenueCat | Subscription management | Not yet — monetization not implemented |

This list will be updated when we add or remove processors.

## 8. International transfers

Primary data is stored in the EU (`europe-west1`, Belgium). Some Google services (Authentication, Crashlytics, Analytics) are global by architecture. Where data leaves the EEA, Google uses Standard Contractual Clauses (SCCs) approved by the European Commission as the transfer mechanism.

## 9. Your rights (GDPR Articles 15–22)

You have the right to:

- **Access** your data (Article 15) — in-app data export under Account → Privacy & Data.
- **Rectify** inaccuracies (Article 16) — edit any field in-app, or contact us.
- **Erase** your data (Article 17) — in-app account deletion under Account Security.
- **Restrict** processing (Article 18) — contact us.
- **Data portability** (Article 20) — JSON export available in-app.
- **Object** to processing (Article 21) — contact us.
- **Withdraw consent** (Article 7(3)) — manage allergen disclosure in Profile settings, or delete your account.
- **Lodge a complaint** with the Swedish Authority for Privacy Protection (IMY): https://www.imy.se

## 10. Children's privacy

Butlery is not directed at children under 16. We do not knowingly collect data from children. If you believe a child has created an account, contact us and we will delete the account.

## 11. Security

We use Transport Layer Security (TLS 1.2+) for all network traffic, certificate pinning on mobile clients, App Check attestation, and Firestore security rules to enforce per-user data isolation. Passwords are never stored in plaintext.

## 12. Changes to this policy

We will notify you of material changes via in-app notification and update the "Last updated" date above. Continued use after the change constitutes acceptance.

## 13. Contact

Data controller: Malin Gisslén
Email: malin.kallen1@gmail.com
