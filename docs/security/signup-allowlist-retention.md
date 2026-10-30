# `signup_allowlist/{email}` — Art. 30 Record

GDPR Article 30 record for the guest list (BUT-2452, ADR-0034). Companion to
`account-subcollections-retention.md` and `audit-logs-retention.md`.

| | |
|---|---|
| **Purpose** | Let a person Malin has invited create an account while sign-up is closed to everyone else during the test launch. |
| **Lawful basis** | Legitimate interest, Art. 6(1)(f): the person asked to join the closed test. **Malin's decision, 2026-10-24.** The address is typed in by an admin, not by the person, so Art. 14 applies; the privacy policy (§3.3, §4, §8, from 1.22.0) says where it comes from and how to have it removed. |
| **Data** | The document id is the email address, trimmed and lower-cased. Fields: `invitedAt` (server time), `invitedBy` (the inviting admin's uid, not a name), `expireAt`. Nothing else; `firestore.rules` refuses any other key. |
| **Access** | Admins only (`isAdmin()` in `firestore.rules`) for read, list, create and delete; no one may update. The blocking functions `beforeCreateAllowlist` and `beforeSignInAllowlist` read and delete through the Admin SDK. |
| **Written by** | `lib/repositories/firebase/firebase_signup_allowlist_repository.dart` (the admin site's Gästlista tab). |
| **Deleted** | When the account is created through Google or Apple (address proven by the provider), or at the first sign-in after a password account's address is verified. An unused entry stops counting at `expireAt` (30 days) and is removed by the TTL policy on `signup_allowlist.expireAt`, which can lag by a day or more; the function checks `expireAt` itself. An admin can delete an entry at any time (Ta bort). |
| **Not audited** | No `audit_logs` row is written for an invite or a removal, so the address is not copied into the 365-day audit log. Log lines from the functions carry a hashed uid and an outcome, never the address. |
| **Art. 15 / 17 before sign-up** | The person has no account and no in-app export. A request to integritet@butlery.se is answered by looking the address up in the Gästlista tab; an erasure request is met by Ta bort. |
| **`invitedBy` after an admin's own erasure** | The uid stays on entries that admin created until they are consumed or expire, at most 30 days. Accepted. |
