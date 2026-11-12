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
 *   npm run seed-tag-configs -- --project <id> [--only properties] [--dry-run]
 *
 * `--only` limits the upload to the named documents, so a vocabulary change
 * does not overwrite documents that were not regenerated. `--dry-run` writes
 * nothing and prints which properties the live `properties` document would
 * gain or lose.
 */

import * as admin from "firebase-admin";
import * as fs from "fs";
import * as path from "path";
import { initializeAdminApp } from "./admin-init";

initializeAdminApp();

const db = admin.firestore();

const ALL_CONFIG_TYPES = ["allergens", "dietary", "cuisines", "properties", "display"];

function optionValue(name: string): string | undefined {
  const argv = process.argv;
  const at = argv.indexOf(name);
  if (at >= 0) return argv[at + 1];
  const joined = argv.find((arg) => arg.startsWith(`${name}=`));
  return joined?.slice(name.length + 1);
}

const DRY_RUN = process.argv.includes("--dry-run");
const ONLY = optionValue("--only");
// A cleared workflow input reaches the script as an empty string, so a present
// flag must name something; only a missing flag means "all documents".
const ONLY_GIVEN = process.argv.some((a) => a === "--only" || a.startsWith("--only="));
const CONFIG_TYPES = ONLY_GIVEN
  ? (ONLY ?? "").split(",").map((t) => t.trim())
  : ALL_CONFIG_TYPES;
const unknownTypes = CONFIG_TYPES.filter((t) => !ALL_CONFIG_TYPES.includes(t));
if (unknownTypes.length > 0) {
  console.error(`❌ Unknown or empty config type: [${unknownTypes.join(", ")}]`);
  process.exit(1);
}

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

      if (DRY_RUN) {
        const live = (await db.collection("tag_configs").doc(configType).get()).data();
        if (configType !== "properties") {
          console.log(`🔎 ${configType} (dry run) - diff not supported, would overwrite`);
          successCount++;
          continue;
        }
        const liveList: string[] = live?.validProperties ?? [];
        const nextList: string[] = data.validProperties ?? [];
        console.log(
          `🔎 ${configType} (dry run) - gained: [${nextList.filter((x) => !liveList.includes(x)).join(", ")}], ` +
            `lost: [${liveList.filter((x) => !nextList.includes(x)).join(", ")}]`,
        );
        successCount++;
        continue;
      }

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
