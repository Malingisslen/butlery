# `deep_links/{code}` — Art. 30 Record

GDPR Article 30 record for short links (BUT-2463). Companion to
`account-subcollections-retention.md`.

| | |
|---|---|
| **Purpose** | Give a shared recipe, a shared shopping list or a friend invitation a short link the recipient can open. |
| **Lawful basis** | Performance of contract, Art. 6(1)(b), as the privacy policy's §8 row says from 1.23.0. Malin chose it on 2026-10-28, and approved the policy wording the same day. |
| **Data** | The document id is the short code. Fields from `createShortUrl` (`lib/repositories/firebase/firebase_deeplink_repository.dart`): `id`, `longUrl` (carries the sharer's uid as `from=` and the shared item's id), `createdAt` (server time), `createdBy` (the sharer's uid), `metadata` (`isActive`, `expiresAt`), `clickCount`. A `clicks` subcollection may still hold rows written before BUT-2463. |
| **Access** | Any signed-in account may `get` a link by its code; `list` and `update` are refused, the creator may delete, and `clicks` is closed to clients (`firestore.rules`). |
| **Deleted** | 14 days after `createdAt`, by `cleanupExpiredDeepLinks` (daily, 03:30 UTC), and on the creator's account deletion by the cascade step `deep_links` (`createdBy == uid`), each with the link's `clicks`. A document whose `createdAt` is not a Timestamp is reached by the cascade only. |
| **Art. 15** | Section `deep_links`: id, `longUrl`, `createdAt`, `metadata.isActive`, `metadata.expiresAt`. |
| **Not reachable** | A link already sent stays with its recipient. |
