/**
 * One-time migration: backfill thumbnailUrl on recipes.
 *
 * For each recipe with imageUrls but no thumbnailUrl, derives the thumbnail
 * Storage path from the original image path, checks if it exists, gets
 * the download URL, and writes it to Firestore.
 *
 * Usage: npx ts-node src/admin/backfill-thumbnail-urls.ts [--dry-run]
 */

import { initializeAdminApp } from "./admin-init";

const BATCH_SIZE = 500;

async function backfillThumbnailUrls(dryRun: boolean): Promise<void> {
  const app = initializeAdminApp();
  const db = app.firestore();
  const storage = app.storage().bucket();

  console.log(`Starting thumbnail URL backfill${dryRun ? " (DRY RUN)" : ""}...`);

  // Query all users
  const usersSnapshot = await db.collection("users").get();
  let totalProcessed = 0;
  let totalUpdated = 0;
  let totalSkipped = 0;
  let totalMissing = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const recipesRef = db
      .collection("users")
      .doc(userId)
      .collection("recipes");

    let lastDoc: FirebaseFirestore.QueryDocumentSnapshot | undefined;

    // Cursor-based pagination
    while (true) {
      let query = recipesRef.orderBy("__name__").limit(BATCH_SIZE);
      if (lastDoc) {
        query = query.startAfter(lastDoc);
      }

      const snapshot = await query.get();
      if (snapshot.empty) break;

      const batch = db.batch();
      let batchCount = 0;

      for (const doc of snapshot.docs) {
        totalProcessed++;
        const data = doc.data();
        const core = data.core ?? data;

        // Skip if already has thumbnailUrl
        if (core.thumbnailUrl) {
          totalSkipped++;
          continue;
        }

        // Skip if no images
        const imageUrls: string[] = core.imageUrls ?? [];
        if (imageUrls.length === 0) {
          totalSkipped++;
          continue;
        }

        // Derive thumbnail path from first image URL
        const primaryUrl = imageUrls[0];
        const thumbUrl = await findThumbnailUrl(storage, primaryUrl, userId);

        if (thumbUrl) {
          if (!dryRun) {
            // Write to nested core or flat structure
            const field = data.core ? "core.thumbnailUrl" : "thumbnailUrl";
            batch.update(doc.ref, { [field]: thumbUrl });
            batchCount++;
          }
          totalUpdated++;
          console.log(`  [${userId}/${doc.id}] -> ${thumbUrl.substring(0, 80)}...`);
        } else {
          totalMissing++;
        }

        // Commit batch if at limit
        if (batchCount >= BATCH_SIZE) {
          if (!dryRun) await batch.commit();
          batchCount = 0;
        }
      }

      // Commit remaining
      if (batchCount > 0 && !dryRun) {
        await batch.commit();
      }

      lastDoc = snapshot.docs[snapshot.docs.length - 1];
      if (snapshot.docs.length < BATCH_SIZE) break;
    }
  }

  console.log("\n=== Backfill Summary ===");
  console.log(`Total recipes processed: ${totalProcessed}`);
  console.log(`Thumbnails linked: ${totalUpdated}`);
  console.log(`Already had thumbnail / no images: ${totalSkipped}`);
  console.log(`Thumbnail not found in storage: ${totalMissing}`);
  if (dryRun) console.log("(DRY RUN — no writes performed)");
}

/**
 * Derives thumbnail Storage path from image URL and checks if it exists.
 * Thumbnail naming convention: thumb_300x300_<original-filename>
 */
async function findThumbnailUrl(
  bucket: ReturnType<ReturnType<typeof import("firebase-admin").storage>["bucket"]>,
  imageUrl: string,
  userId: string
): Promise<string | null> {
  try {
    // Extract storage path from Firebase Storage URL
    const storagePath = extractStoragePath(imageUrl);
    if (!storagePath) return null;

    // Derive thumbnail path
    const parts = storagePath.split("/");
    const fileName = parts[parts.length - 1];
    const dir = parts.slice(0, -1).join("/");
    const thumbFileName = `thumb_300x300_${fileName}`;
    const thumbPath = `${dir}/thumbnails/${thumbFileName}`;

    // Check if thumbnail exists
    const file = bucket.file(thumbPath);
    const [exists] = await file.exists();

    if (!exists) return null;

    // Get signed URL (long-lived)
    const [url] = await file.getSignedUrl({
      action: "read",
      expires: "2099-12-31",
    });

    return url;
  } catch (e) {
    console.error(`  Error checking thumbnail for ${imageUrl}: ${e}`);
    return null;
  }
}

/**
 * Extracts the Storage path from a Firebase Storage download URL.
 */
function extractStoragePath(url: string): string | null {
  try {
    // Handle firebasestorage.googleapis.com URLs
    const match = url.match(
      /firebasestorage\.googleapis\.com\/v0\/b\/[^/]+\/o\/(.+?)(\?|$)/
    );
    if (match) {
      return decodeURIComponent(match[1]);
    }
    return null;
  } catch {
    return null;
  }
}

// Run
const dryRun = process.argv.includes("--dry-run");
backfillThumbnailUrls(dryRun)
  .then(() => {
    console.log("Done.");
    process.exit(0);
  })
  .catch((err) => {
    console.error("Fatal error:", err);
    process.exit(1);
  });
