import * as admin from "firebase-admin";
import { logger } from "firebase-functions/logger";
import { RETENTION_ANALYTICS_PARENTS } from "./own-account-data";

export async function probeNotificationEffectiveness(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-1956: `analytics/notifications/effectiveness`, a subcollection under a
  // FIXED `analytics/` document — neither the top-level loop nor the
  // `users/{uid}` enumeration above can reach it, so it needs its own leg.
  //
  // This leg is not a mirror of `deleteNotificationEffectiveness`. The writer,
  // `correlateNotificationEffectiveness`, runs daily inside `dailyAnalytics`
  // and writes these rows from pages it is already holding in memory, so a
  // cascade that lands mid-run can have a row written back AFTER the deleter
  // swept. That resurrection is exactly what this leg exists to report.
  try {
    const snap = await db
      .collection("analytics")
      .doc("notifications")
      .collection("effectiveness")
      .where("userId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual notification effectiveness", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error(
      "[deletion-cascade] residual probe failed: notification effectiveness",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
  }
  return residual;
}

export async function probeFeatureRetention(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-1789: the feature-retention rows. A SUBCOLLECTION under an analytics
  // document, so neither the top-level `userId` loop at the head of this
  // function nor the `users/{uid}/...` loop above can reach it — both are
  // structurally blind to `analytics/feature_retention/users`. Same handle the
  // deleter uses, keeping the deleter a strict superset of the probe. Appended
  // rather than folded into an existing `try`, for the reason the block above
  // states: a leg sharing another leg's catch shortens every leg after it.
  try {
    const snap = await db
      .collection("analytics")
      .doc("feature_retention")
      .collection("users")
      .where("userId", "==", uid)
      .count()
      .get();
    const count = snap.data().count ?? 0;
    if (count > 0) {
      residual += count;
      logger.warn("[deletion-cascade] residual feature-retention rows", {
        uid_prefix: uid.slice(0, 6),
        count,
      });
    }
  } catch (err) {
    residual += 1;
    logger.error(
      "[deletion-cascade] residual probe failed: feature_retention",
      {
        uid_prefix: uid.slice(0, 6),
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      },
    );
  }
  return residual;
}

export async function probeRetentionAnalytics(
  db: admin.firestore.Firestore,
  uid: string,
): Promise<number> {
  let residual = 0;
  // BUT-1800: probed on the same handle the deleter uses, and over the SAME
  // list, so the deleter stays a strict superset of the probe. Each
  // parent gets its OWN `try` for the reason the blocks above state — a leg
  // sharing another leg's catch shortens every leg after it, and here that
  // would let a failure on `retention` hide whatever `lapsed_users` holds.
  for (const parent of RETENTION_ANALYTICS_PARENTS) {
    try {
      const snap = await db
        .collection("analytics")
        .doc(parent)
        .collection("events")
        .where("userId", "==", uid)
        .count()
        .get();
      const count = snap.data().count ?? 0;
      if (count > 0) {
        residual += count;
        logger.warn("[deletion-cascade] residual analytics rows", {
          uid_prefix: uid.slice(0, 6),
          parent,
          count,
        });
      }
    } catch (err) {
      residual += 1;
      logger.error("[deletion-cascade] residual probe failed: analytics", {
        uid_prefix: uid.slice(0, 6),
        parent,
        errCode: (err as { code?: number | string }).code ?? null,
        errName: err instanceof Error ? err.name : typeof err,
      });
    }
  }
  return residual;
}
