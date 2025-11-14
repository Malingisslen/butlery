#!/usr/bin/env npx tsx

/**
 * Quality Checks Hook (Stop)
 *
 * Runs flutter analyze and dart format on changed files after Claude finishes.
 */

import { execSync } from 'child_process';
import { getGitContext } from './shared/git-cache.js';
import { debug, measureTime } from './shared/logger.js';

/**
 * Main entry point
 */
async function main() {
  try {
    await measureTime('Quality Checks Total', async () => {
      // Get changed files from git
      const gitContext = getGitContext();

      if (!gitContext || gitContext.modifiedFiles.length === 0) {
        debug('No modified files, skipping quality checks');
        return;
      }

      const dartFiles = gitContext.modifiedFiles.filter(f => f.endsWith('.dart'));

      if (dartFiles.length === 0) {
        debug('No Dart files modified, skipping quality checks');
        return;
      }

      console.log('');
      console.log('═'.repeat(80));
      console.log('🔍 Running Quality Checks');
      console.log('═'.repeat(80));
      console.log('');

      // Run flutter analyze
      await runFlutterAnalyze();

      // Run dart format on changed files
      await runDartFormat(dartFiles);

      console.log('═'.repeat(80));
      console.log('');
    });
  } catch (err) {
    debug(`Quality checks error: ${err}`);
    // Always exit 0 - don't break user workflow
  } finally {
    process.exit(0);
  }
}

/**
 * Run flutter analyze
 */
async function runFlutterAnalyze() {
  try {
    console.log('Running flutter analyze...');
    console.log('');

    const output = execSync('flutter analyze --no-pub', {
      encoding: 'utf-8',
      stdio: 'pipe',
      timeout: 10000 // 10 second timeout
    });

    // Check if there are issues
    if (output.includes('error') || output.includes('warning') || output.includes('info')) {
      console.log('⚠️  Analysis Issues Found:');
      console.log('');
      console.log(output);
      console.log('');
    } else {
      console.log('✓ No analysis issues found');
      console.log('');
    }
  } catch (err: any) {
    // flutter analyze exits with non-zero if issues found
    if (err.stdout) {
      console.log('⚠️  Analysis Issues Found:');
      console.log('');
      console.log(err.stdout);
      console.log('');
    } else {
      console.log(`⚠️  flutter analyze failed: ${err.message}`);
      console.log('');
    }
  }
}

/**
 * Run dart format on changed files
 */
async function runDartFormat(dartFiles: string[]) {
  if (dartFiles.length === 0) {
    return;
  }

  try {
    console.log(`Formatting ${dartFiles.length} Dart file(s)...`);
    console.log('');

    for (const file of dartFiles) {
      try {
        execSync(`dart format "${file}"`, {
          encoding: 'utf-8',
          stdio: 'pipe',
          timeout: 5000
        });
        console.log(`  ✓ Formatted: ${file}`);
      } catch (err) {
        console.log(`  ⚠️  Failed to format: ${file}`);
      }
    }

    console.log('');
    console.log('✓ Formatting complete');
    console.log('');
  } catch (err) {
    debug(`Dart format error: ${err}`);
    console.log('⚠️  Some files could not be formatted');
    console.log('');
  }
}

// Run main
main();
