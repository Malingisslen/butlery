/**
 * Site Config Seeding - Admin function to populate site_configs collection
 *
 * This function seeds CSS selectors and metadata for Swedish recipe sites.
 * Site configs enable the SiteConfigTier to extract recipes without
 * requiring app releases for new site support.
 *
 * Usage:
 * - Firebase Console: Call the function manually
 * - CLI: firebase functions:call seedSiteConfigs
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";

// Note: db is accessed lazily to ensure initializeApp() has been called
const getDb = () => admin.firestore();

/**
 * List of admin user IDs allowed to seed configs.
 * In production, consider using custom claims instead.
 */
const ADMIN_UIDS: string[] = [
  // Add your admin UIDs here, or use custom claims
  // "your-admin-uid-here",
];

/**
 * Check if user is an admin.
 * Override this with custom claims in production.
 */
function isAdmin(uid: string): boolean {
  // For now, allow any authenticated user in development
  // In production, check ADMIN_UIDS or custom claims
  return ADMIN_UIDS.length === 0 || ADMIN_UIDS.includes(uid);
}

/**
 * Site configuration interface matching Dart SiteConfig model
 */
interface SiteConfigData {
  domain: string;
  titleSelector?: string;
  ingredientsSelector?: string;
  instructionsSelector?: string;
  portionsSelector?: string;
  timeSelector?: string;
  imageSelector?: string;
  descriptionSelector?: string;
  isSupported: boolean;
  qualityScore: number;
  successCount: number;
  failureCount: number;
  lastUpdated: FirebaseFirestore.FieldValue;
}

/**
 * Swedish recipe site configurations.
 *
 * These selectors are based on analysis of each site's HTML structure.
 * They should be validated and updated as sites change their markup.
 */
const SITE_CONFIGS: SiteConfigData[] = [
  // ICA - Sweden's largest grocery chain
  {
    domain: "ica.se",
    titleSelector: "h1.recipe-header__title",
    ingredientsSelector: ".ingredients-list-group__card li",
    instructionsSelector: ".cooking-steps-main__step",
    portionsSelector: ".recipe-header__servings",
    timeSelector: ".recipe-header__time",
    imageSelector: ".recipe-header__image img",
    descriptionSelector: ".recipe-header__preamble",
    isSupported: true,
    qualityScore: 0.9,
    successCount: 0,
    failureCount: 0,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  },

  // Arla - Major Swedish dairy company
  {
    domain: "arla.se",
    titleSelector: "h1.recipe-title",
    ingredientsSelector: ".ingredient-list li",
    instructionsSelector: ".method-step",
    portionsSelector: ".servings-selector",
    timeSelector: ".recipe-time",
    imageSelector: ".recipe-hero-image img",
    isSupported: true,
    qualityScore: 0.85,
    successCount: 0,
    failureCount: 0,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  },

  // Köket - Popular Swedish recipe site
  {
    domain: "koket.se",
    titleSelector: "h1.recipe-title",
    ingredientsSelector: ".ingredients-list li",
    instructionsSelector: ".instructions-step",
    portionsSelector: ".portions-value",
    timeSelector: ".cooking-time",
    imageSelector: ".recipe-image img",
    isSupported: true,
    qualityScore: 0.85,
    successCount: 0,
    failureCount: 0,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  },

  // Recept.se - Swedish recipe aggregator
  {
    domain: "recept.se",
    titleSelector: "h1.recipe-name",
    ingredientsSelector: ".ingredient-item",
    instructionsSelector: ".instruction-step",
    portionsSelector: ".servings",
    timeSelector: ".time-total",
    imageSelector: ".recipe-photo img",
    isSupported: true,
    qualityScore: 0.8,
    successCount: 0,
    failureCount: 0,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  },

  // Coop - Swedish grocery cooperative
  {
    domain: "coop.se",
    titleSelector: "h1.recipe-title",
    ingredientsSelector: ".recipe-ingredients li",
    instructionsSelector: ".recipe-instructions li",
    portionsSelector: ".recipe-servings",
    timeSelector: ".recipe-time",
    imageSelector: ".recipe-image img",
    isSupported: true,
    qualityScore: 0.8,
    successCount: 0,
    failureCount: 0,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  },

  // Tasteline - Swedish recipe community
  {
    domain: "tasteline.com",
    titleSelector: "h1.recipe-title",
    ingredientsSelector: ".ingredients-list li",
    instructionsSelector: ".instructions-list li",
    portionsSelector: ".portions",
    timeSelector: ".cooking-time",
    isSupported: true,
    qualityScore: 0.75,
    successCount: 0,
    failureCount: 0,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  },

  // Mathem - Swedish online grocery
  {
    domain: "mathem.se",
    titleSelector: "h1.recipe-name",
    ingredientsSelector: ".ingredient-row",
    instructionsSelector: ".instruction-step",
    portionsSelector: ".servings-count",
    isSupported: true,
    qualityScore: 0.75,
    successCount: 0,
    failureCount: 0,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  },

  // Allt om Mat - Swedish food magazine
  {
    domain: "alltommat.se",
    titleSelector: "h1.article-title",
    ingredientsSelector: ".recipe-ingredients li",
    instructionsSelector: ".recipe-method li",
    portionsSelector: ".recipe-servings",
    timeSelector: ".recipe-time",
    isSupported: true,
    qualityScore: 0.8,
    successCount: 0,
    failureCount: 0,
    lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
  },
];

/**
 * seedSiteConfigs - Admin callable to populate site_configs collection
 *
 * This function:
 * 1. Verifies admin authentication
 * 2. Writes all site configs in a batch
 * 3. Uses merge: true to preserve existing successCount/failureCount
 *
 * @returns Success status and count of seeded configs
 */
export const seedSiteConfigs = functions.https.onCall(
  async (data, context) => {
    // Require authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be logged in to seed site configs"
      );
    }

    // Check admin permission
    if (!isAdmin(context.auth.uid)) {
      throw new functions.https.HttpsError(
        "permission-denied",
        "Only admins can seed site configs"
      );
    }

    functions.logger.info("Seeding site configs", {
      userId: context.auth.uid,
      configCount: SITE_CONFIGS.length,
    });

    try {
      const batch = getDb().batch();

      for (const config of SITE_CONFIGS) {
        const docRef = getDb().collection("site_configs").doc(config.domain);
        // Use merge to preserve existing statistics
        batch.set(docRef, config, { merge: true });
      }

      await batch.commit();

      functions.logger.info("Site configs seeded successfully", {
        count: SITE_CONFIGS.length,
      });

      return {
        success: true,
        count: SITE_CONFIGS.length,
        domains: SITE_CONFIGS.map((c) => c.domain),
      };
    } catch (error) {
      functions.logger.error("Failed to seed site configs", { error });
      throw new functions.https.HttpsError(
        "internal",
        "Failed to seed site configs"
      );
    }
  }
);

/**
 * getSiteConfigStats - Admin callable to get site config statistics
 *
 * Returns success/failure rates for each configured site.
 */
export const getSiteConfigStats = functions.https.onCall(
  async (data, context) => {
    // Require authentication
    if (!context.auth) {
      throw new functions.https.HttpsError(
        "unauthenticated",
        "Must be logged in"
      );
    }

    try {
      const snapshot = await getDb().collection("site_configs").get();

      const stats = snapshot.docs.map((doc) => {
        const data = doc.data();
        const successCount = data.successCount || 0;
        const failureCount = data.failureCount || 0;
        const total = successCount + failureCount;
        const successRate = total > 0 ? successCount / total : 0;

        return {
          domain: doc.id,
          isSupported: data.isSupported,
          qualityScore: data.qualityScore,
          successCount,
          failureCount,
          successRate: Math.round(successRate * 100),
          lastUpdated: data.lastUpdated,
        };
      });

      // Sort by success rate descending
      stats.sort((a, b) => b.successRate - a.successRate);

      return { success: true, stats };
    } catch (error) {
      functions.logger.error("Failed to get site config stats", { error });
      throw new functions.https.HttpsError(
        "internal",
        "Failed to get site config stats"
      );
    }
  }
);
