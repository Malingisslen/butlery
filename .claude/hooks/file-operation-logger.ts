#!/usr/bin/env npx tsx

/**
 * File Operation Logger Hook (PostToolUse)
 *
 * Logs file operations (Edit, Write, Read) and links them to the current prompt.
 * Runs alongside architecture-validator.ts.
 */

import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import type { HookInput } from './shared/types.js';
import { debug, measureTime } from './shared/logger.js';
import { appendToJSONL, getDailyLogFile } from './shared/log-utils.js';

// Get project root
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PROJECT_ROOT = join(__dirname, '../..');
const CACHE_DIR = join(PROJECT_ROOT, '.claude/cache');
const CURRENT_PROMPT_FILE = join(CACHE_DIR, 'current-prompt.json');

/**
 * Main entry point
 */
async function main() {
  try {
    // Check if logging is disabled
    if (process.env.DISABLE_PROMPT_LOGGING === '1') {
      debug('File operation logging disabled via env var');
      return;
    }

    await measureTime('File Operation Logging Total', async () => {
      // Read input from stdin
      const input = await readStdin();
      const hookInput: HookInput = JSON.parse(input);

      const toolName = hookInput.tool_name;
      const filePath = hookInput.tool_input?.file_path;

      // Only log file operations
      if (!toolName || !filePath) {
        debug('No tool name or file path, skipping');
        return;
      }

      // Only log file-modifying tools
      const fileTools = ['Edit', 'Write', 'MultiEdit', 'Read'];
      if (!fileTools.includes(toolName)) {
        debug(`Tool ${toolName} is not a file operation, skipping`);
        return;
      }

      // Get current prompt ID
      const currentPrompt = loadCurrentPromptId();
      if (!currentPrompt) {
        debug('No current prompt ID found, skipping file operation log');
        return;
      }

      debug(`Logging ${toolName} operation on ${filePath}`);

      // Build file operation log entry
      const fileOpLogEntry = {
        type: 'file-operation',
        promptId: currentPrompt.promptId,
        timestamp: new Date().toISOString(),
        tool: toolName,
        filePath: filePath,
        success: true, // Assume success (hook runs after tool use)
        violationsDetected: [], // Could be populated by reading validation results
        warningsIssued: [],
      };

      // Append to daily log
      const logFile = getDailyLogFile();
      appendToJSONL(logFile, fileOpLogEntry);

      debug(`Logged ${toolName} operation for prompt ${currentPrompt.promptId}`);
    });
  } catch (err) {
    debug(`File operation logger error: ${err}`);
    // Exit 0 - don't break user workflow on errors
  } finally {
    process.exit(0);
  }
}

/**
 * Read input from stdin
 */
function readStdin(): Promise<string> {
  return new Promise((resolve) => {
    const chunks: Buffer[] = [];
    process.stdin.on('data', (chunk) => chunks.push(chunk));
    process.stdin.on('end', () => resolve(Buffer.concat(chunks).toString('utf-8')));
  });
}

/**
 * Load current prompt ID (saved by prompt-logger.ts)
 */
function loadCurrentPromptId(): { promptId: string; timestamp: number } | null {
  try {
    if (!existsSync(CURRENT_PROMPT_FILE)) {
      debug('No current prompt file found');
      return null;
    }

    const content = readFileSync(CURRENT_PROMPT_FILE, 'utf-8');
    const data = JSON.parse(content);

    // Check if prompt is stale (older than 5 minutes)
    const age = Date.now() - data.timestamp;
    if (age > 5 * 60 * 1000) {
      debug('Current prompt is stale (older than 5 minutes)');
      return null;
    }

    return data;
  } catch (err) {
    debug(`Failed to load current prompt ID: ${err}`);
    return null;
  }
}

// Run main
main();
