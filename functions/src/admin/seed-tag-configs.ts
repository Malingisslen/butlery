/**
 * Seed Tag Configs to Firestore.
 *
 * Uploads the 5 tag config documents (allergens, dietary, cuisines, properties, display)
 * to the tag_configs collection in Firestore.
 *
 * Prerequisites:
 *   1. Run: dart scripts/migrate_tag_configs.dart (generates JSON files)
 *   2. Set GOOGLE_APPLICATION_CREDENTIALS to service account key
 *
 * Usage:
 *   cd functions
 *   npm run seed-tag-configs
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";

const PROJECT_ID = "butlery-app-1";

// Initialize Firebase Admin
if (!admin.apps.length) {
  admin.initializeApp({
    projectId: PROJECT_ID,
  });
}

const db = admin.firestore();

const CONFIG_TYPES = ["allergens", "dietary", "cuisines", "properties", "display"];

async function seedTagConfigs() {
  console.log("🔄 Tag Config Seeding Tool");
  console.log("==================================================\n");

  // Path to generated JSON files
  const jsonDir = path.resolve(__dirname, "../../../scripts/output/tagConfigs");

  // Check if JSON files exist
  if (!fs.existsSync(jsonDir)) {
    console.error(`❌ JSON directory not found: ${jsonDir}`);
    console.error("   Run 'dart scripts/migrate_tag_configs.dart' first.");
    process.exit(1);
  }

  console.log(`📂 Reading JSON files from: ${jsonDir}\n`);

  // Upload each config
  let successCount = 0;
  let errorCount = 0;

  for (const configType of CONFIG_TYPES) {
    const jsonPath = path.join(jsonDir, `${configType}.json`);

    if (!fs.existsSync(jsonPath)) {
      console.error(`❌ ${configType}.json not found`);
      errorCount++;
      continue;
    }

    try {
      const jsonContent = fs.readFileSync(jsonPath, "utf-8");
      const data = JSON.parse(jsonContent);

      // Add upload timestamp
      data.uploadedAt = admin.firestore.FieldValue.serverTimestamp();

      // Upload to Firestore
      await db.collection("tag_configs").doc(configType).set(data);

      const entryCount = data.entries?.length || data.validProperties?.length || "N/A";
      console.log(`✅ ${configType} - uploaded (${entryCount} entries)`);
      successCount++;
    } catch (error) {
      console.error(`❌ ${configType} - failed: ${error}`);
      errorCount++;
    }
  }

  console.log("\n==================================================");
  console.log(`📊 Results: ${successCount} succeeded, ${errorCount} failed`);

  if (errorCount > 0) {
    process.exit(1);
  }
}

// Run
seedTagConfigs()
  .then(() => {
    console.log("\n✅ Tag configs seeded successfully!");
    process.exit(0);
  })
  .catch((error) => {
    console.error("\n❌ Seeding failed:", error);
    process.exit(1);
  });
