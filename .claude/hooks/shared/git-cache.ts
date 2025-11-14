/**
 * Git context caching system
 * Caches git operations (branch, modified files) to avoid redundant calls
 */

import { execSync } from 'child_process';
import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import type { GitContext } from './types.js';
import { debug } from './logger.js';

// Get project root (three levels up from this script: shared -> hooks -> .claude -> project)
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PROJECT_ROOT = join(__dirname, '../../..');
const CACHE_TTL_MS = 5 * 60 * 1000; // 5 minutes
const CACHE_DIR = join(PROJECT_ROOT, '.claude/cache');
const CACHE_FILE = join(CACHE_DIR, 'git-context.json');

/**
 * Get git context (branch, modified files) with caching
 */
export function getGitContext(): GitContext | null {
  try {
    // Check if cache exists and is fresh
    const cachedContext = readCache();
    if (cachedContext) {
      debug('Using cached git context');
      return cachedContext;
    }

    // Cache miss or stale - fetch from git
    debug('Fetching fresh git context');
    const context = fetchGitContext();

    if (context) {
      writeCache(context);
    }

    return context;
  } catch (err) {
    debug(`Git context error: ${err}`);
    return null;
  }
}

/**
 * Read cache if exists and not stale
 */
function readCache(): GitContext | null {
  try {
    if (!existsSync(CACHE_FILE)) {
      return null;
    }

    const content = readFileSync(CACHE_FILE, 'utf-8');
    const context: GitContext = JSON.parse(content);

    // Check if cache is still fresh
    const age = Date.now() - new Date(context.timestamp).getTime();
    if (age > CACHE_TTL_MS) {
      debug('Cache is stale');
      return null;
    }

    return context;
  } catch (err) {
    debug(`Cache read error: ${err}`);
    return null;
  }
}

/**
 * Write cache to disk
 */
function writeCache(context: GitContext): void {
  try {
    // Ensure cache directory exists
    if (!existsSync(CACHE_DIR)) {
      mkdirSync(CACHE_DIR, { recursive: true });
    }

    writeFileSync(CACHE_FILE, JSON.stringify(context, null, 2), 'utf-8');
    debug('Git context cached');
  } catch (err) {
    debug(`Cache write error: ${err}`);
  }
}

/**
 * Fetch fresh git context from repository
 */
function fetchGitContext(): GitContext | null {
  try {
    // Check if in a git repository
    execSync('git rev-parse --git-dir', { stdio: 'pipe' });

    // Get branch name
    const branch = execSync('git rev-parse --abbrev-ref HEAD', {
      encoding: 'utf-8',
      stdio: 'pipe'
    }).trim();

    // Get modified files
    const modifiedFilesOutput = execSync('git diff --name-only HEAD', {
      encoding: 'utf-8',
      stdio: 'pipe'
    }).trim();

    const modifiedFiles = modifiedFilesOutput
      ? modifiedFilesOutput.split('\n').filter(f => f.length > 0)
      : [];

    return {
      branch,
      modifiedFiles,
      timestamp: new Date().toISOString()
    };
  } catch (err) {
    debug(`Not a git repository or git command failed: ${err}`);
    return null;
  }
}

/**
 * Clear the git cache (for testing/debugging)
 */
export async function clearGitCache(): Promise<void> {
  try {
    if (existsSync(CACHE_FILE)) {
      // Just delete the file using Node's fs
      const fs = await import('fs/promises');
      await fs.unlink(CACHE_FILE);
      debug('Git cache cleared');
    }
  } catch (err) {
    debug(`Cache clear error: ${err}`);
  }
}
