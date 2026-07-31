# Presence TTL Runbook (BUT-477)

**Status:** ACTIVE — one-time gcloud setup required to activate the
server-side TTL sweeper. Client-side TTL filter is already live (no
operator action needed for that half).

## Problem statement

Three presence surfaces formerly grew unbounded if a client crashed
mid-session:

| Surface | Backend | Path | Auto-clear today |
|---|---|---|---|
| Recipe presence | Firestore | `recipePresence/{recipeId}/activeUsers/{userId}` | TTL field + sweeper (after this runbook) |
| Shopping presence | Firestore | `shoppingPresence/{listId}/activeUsers/{userId}` | TTL field + sweeper (after this runbook) |
| Cooking session | RTDB | `cooking_sessions/{groupId}/{userId}` | `onDisconnect().remove()` (already self-clears) |

Only the two Firestore surfaces need server-side TTL. Cooking sessions
self-clear via the RTDB `onDisconnect` handler within seconds of the
device dropping (see `firebase_cooking_session_repository.dart`).

## Design

- Each presence document carries an `expiresAt: Timestamp` field.
- Repositories (`firebase_recipe_presence_repository.dart` and
  `firebase_shopping_presence_repository.dart`) set `expiresAt = now + 60s`
  on every write (create / heartbeat / show / hide).
- Clients refresh at a 30 s heartbeat cadence — twice within the TTL
  window so a single missed tick does not flicker the indicator.
- On `markUserInactive`, repositories overwrite `expiresAt = now` to force
  immediate eviction.
- Client read paths filter rows where `expiresAt < now` to mask stale
  rows during the gap before the server sweeper runs.
- **GDPR cascade (`functions/src/cleanup/on-user-deleted.ts`):** account
  deletion sweeps `collectionGroup('activeUsers')` and deletes every row
  with the deleted user's `userId`. We do not wait for the 60 s TTL —
  Right-to-Erasure must take effect immediately on request.

## One-time activation

> **Corrected 2026-07-31 (BUT-1699).** This section used to state that TTL
> policies "are not configured via `firestore.indexes.json`". That is wrong, and
> has been for a while: 15 policies are declared there today as `fieldOverrides`
> carrying `"ttl": true`, and `firebase deploy --only firestore:indexes` is what
> applies them. Prefer declaring a policy in that file — it is reviewable, it is
> version-controlled, and `functions/src/__tests__/firestore-ttl-policies.test.ts`
> can then pin it.
>
> The gcloud route below still works and is still the way to inspect state.
> **Declaring is not activating:** Firestore offers no round-trip, so nothing in
> the repo can prove a policy is live. After any deploy, confirm with
> `gcloud firestore fields ttls list --project=butlery-app-1`.
>
> Note this runbook's own field is spelled `expiresAt`, not `expireAt` — a TTL
> policy names one exact field, so do not copy an `expireAt` command here.

Either declare the policy in `firestore.indexes.json` and deploy indexes, or run
the Admin API (gcloud CLI) commands below once per environment (dev + prod)
under an account with `roles/datastore.owner`:

```bash
# Activate TTL on activeUsers.expiresAt across both presence surfaces.
# `--collection-group=activeUsers` covers both
# `recipePresence/.../activeUsers` and `shoppingPresence/.../activeUsers`
# in a single sweeper config.

gcloud firestore fields ttls update expiresAt \
  --collection-group=activeUsers \
  --enable-ttl \
  --project=<PROJECT_ID>

# Verify
gcloud firestore fields ttls list \
  --collection-group=activeUsers \
  --project=<PROJECT_ID>
```

Alternatively in the Firebase Console:

1. Firebase Console → Firestore → **TTL** tab → **Add policy**.
2. Collection group: `activeUsers`. Field: `expiresAt`.
3. Confirm. Activation takes up to 24 h to start sweeping the first time.

The sweeper deletes documents with `expiresAt` in the past on a best-effort
schedule (typically within 24 h of expiry; not real-time). The client-side
filter is what makes the UI feel real-time.

## Verification after activation

```bash
# Spot-check that TTL is enabled
gcloud firestore fields ttls list \
  --collection-group=activeUsers \
  --project=<PROJECT_ID>

# Expected output: state=ACTIVE, ttlConfig.state=ACTIVE
```

In the Firebase Console under **Firestore → Usage**, the TTL deletes
appear as a separate metric (no read or write cost — TTL deletes are free
of Firestore quota charges, but they DO count against deletes for billing
purposes).

## Cost expectation

Pre-fix: presence rows accumulated forever per (user × recipe / list)
collaboration session. A user who collaborated on 100 recipes over a year
would carry 100 stale presence rows.

Post-fix:

- TTL sweeper deletes are free of read quota; deletes count against
  delete quota at standard pricing.
- Heartbeat writes are unchanged (~1 write per 30 s while a presence
  stream is active — same as before; we just added one more field).
- Client-side filter adds zero additional reads (filter happens on data
  already returned by the existing snapshot listener).

Net cost impact: ~0. Net storage savings: cap presence-row footprint at
roughly (current concurrent users × N collaborations) instead of
(historical sessions ever).

## What if TTL activation is delayed?

Client-side filter still hides stale rows from end users. The only impact
of a delayed gcloud command is: stale rows remain in storage until
manually purged or the gcloud command runs. Because documents are tiny
(~100 bytes), this is not a cost crisis — but it IS a GDPR
data-minimization concern. Run the command before the next release.

## Related

- `lib/repositories/firebase/firebase_recipe_presence_repository.dart` —
  presence-write path, `expiresAt` value, client filter.
- `lib/repositories/firebase/firebase_shopping_presence_repository.dart` —
  shopping presence equivalent.
- `functions/src/cleanup/on-user-deleted.ts` —
  `cleanupPresenceRows()` GDPR cascade.
- `firestore.indexes.json` — collection-group index on `activeUsers.userId`
  (required for the cascade `where('userId', '==', deletedUserId)` query).
- `BUT-477` — Linear ticket.
