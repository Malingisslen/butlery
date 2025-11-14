#!/usr/bin/env npx tsx

/**
 * Prompt Logger Hook (UserPromptSubmit)
 *
 * Logs user prompts, activated skills, and context for later analysis.
 * Runs alongside skill-injector.ts to capture skill activation data.
 */

import { readFileSync, existsSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import type { HookInput, PromptLogEntry, SkillActivationLog } from './shared/types.js';
import { getGitContext } from './shared/git-cache.js';
import { debug, measureTime } from './shared/logger.js';
import {
  appendToJSONL,
  getDailyLogFile,
  generateUUID,
  detectPromptPatterns,
  countWords,
  hasCodeBlocks,
} from './shared/log-utils.js';

// Get project root
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PROJECT_ROOT = join(__dirname, '../..');
const CACHE_DIR = join(PROJECT_ROOT, '.claude/cache');
const SKILL_ACTIVATION_CACHE = join(CACHE_DIR, 'last-skill-activation.json');
const SESSION_STATE_FILE = join(CACHE_DIR, 'session-state.json');

/**
 * Main entry point
 */
async function main() {
  try {
    // Check if logging is disabled
    if (process.env.DISABLE_PROMPT_LOGGING === '1') {
      debug('Prompt logging disabled via env var');
      return;
    }

    await measureTime('Prompt Logging Total', async () => {
      // Read input from stdin
      const input = await readStdin();
      const hookInput: HookInput = JSON.parse(input);

      const prompt = hookInput.prompt || '';
      if (!prompt || prompt.trim().length === 0) {
        debug('Empty prompt, skipping logging');
        return;
      }

      debug(`Logging prompt: ${prompt.substring(0, 50)}...`);

      // Get session state
      const sessionState = loadSessionState();
      sessionState.totalPrompts += 1;
      sessionState.lastPromptTime = Date.now();
      saveSessionState(sessionState);

      // Get skill activation results (written by skill-injector.ts)
      // Wait for skill-injector to finish writing the cache file
      const activatedSkills = await loadSkillActivationResults();

      // Get git context
      const gitContext = getGitContext();

      // Detect patterns
      const patterns = detectPromptPatterns(prompt);

      // Build log entry
      const logEntry: PromptLogEntry = {
        sessionId: hookInput.session_id || 'unknown',
        promptId: generateUUID(),
        timestamp: new Date().toISOString(),
        prompt: {
          text: prompt,
          length: prompt.length,
          wordCount: countWords(prompt),
          hasCodeBlocks: hasCodeBlocks(prompt),
        },
        activatedSkills: activatedSkills,
        gitContext: gitContext,
        fileOperations: [], // Will be populated by file-operation-logger.ts
        sessionMetadata: {
          conversationTurn: sessionState.totalPrompts,
          timeSinceLastPrompt: sessionState.lastPromptTime
            ? Math.round((Date.now() - sessionState.lastPromptTime) / 1000)
            : undefined,
          totalPromptsInSession: sessionState.totalPrompts,
        },
        detectedPatterns: patterns,
      };

      // Save prompt ID for file-operation-logger to reference
      saveCurrentPromptId(logEntry.promptId);

      // Append to daily log
      const logFile = getDailyLogFile();
      appendToJSONL(logFile, logEntry);

      debug(`Logged prompt ${logEntry.promptId} with ${activatedSkills.length} activated skills`);
    });
  } catch (err) {
    debug(`Prompt logger error: ${err}`);
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
 * Load skill activation results from cache (written by skill-injector.ts)
 * Waits briefly to allow skill-injector to finish writing the cache file
 */
async function loadSkillActivationResults(): Promise<SkillActivationLog[]> {
  try {
    // Wait 150ms for skill-injector to finish (runs in parallel with this hook)
    // This resolves the race condition where prompt-logger reads before skill-injector writes
    await new Promise(resolve => setTimeout(resolve, 150));

    if (!existsSync(SKILL_ACTIVATION_CACHE)) {
      debug('No skill activation cache found');
      return [];
    }

    const content = readFileSync(SKILL_ACTIVATION_CACHE, 'utf-8');
    const data = JSON.parse(content);
    return data.activatedSkills || [];
  } catch (err) {
    debug(`Failed to load skill activation results: ${err}`);
    return [];
  }
}

/**
 * Session state for tracking conversation context
 */
interface SessionState {
  totalPrompts: number;
  lastPromptTime: number | null;
  currentSessionId: string | null;
}

/**
 * Load session state
 */
function loadSessionState(): SessionState {
  try {
    if (!existsSync(SESSION_STATE_FILE)) {
      return {
        totalPrompts: 0,
        lastPromptTime: null,
        currentSessionId: null,
      };
    }

    const content = readFileSync(SESSION_STATE_FILE, 'utf-8');
    return JSON.parse(content);
  } catch (err) {
    debug(`Failed to load session state: ${err}`);
    return {
      totalPrompts: 0,
      lastPromptTime: null,
      currentSessionId: null,
    };
  }
}

/**
 * Save session state
 */
function saveSessionState(state: SessionState): void {
  try {
    const fs = require('fs');
    fs.writeFileSync(SESSION_STATE_FILE, JSON.stringify(state, null, 2), 'utf-8');
  } catch (err) {
    debug(`Failed to save session state: ${err}`);
  }
}

/**
 * Save current prompt ID for file-operation-logger to reference
 */
function saveCurrentPromptId(promptId: string): void {
  try {
    const fs = require('fs');
    const data = { promptId, timestamp: Date.now() };
    fs.writeFileSync(join(CACHE_DIR, 'current-prompt.json'), JSON.stringify(data), 'utf-8');
  } catch (err) {
    debug(`Failed to save current prompt ID: ${err}`);
  }
}

// Run main
main();
