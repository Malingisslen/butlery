/**
 * Shared logging utilities for prompt logging system
 */

import { appendFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import type { DetectedPatterns } from './types.js';
import { debug } from './logger.js';

// Get project root
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PROJECT_ROOT = join(__dirname, '../../..');
const LOG_DIR = join(PROJECT_ROOT, '.claude/cache/prompt-logs');

/**
 * Ensure log directory exists
 */
export function ensureLogDirectory(): void {
  if (!existsSync(LOG_DIR)) {
    mkdirSync(LOG_DIR, { recursive: true });
    debug('Created log directory: ' + LOG_DIR);
  }
}

/**
 * Get the daily log file path (YYYY-MM-DD.jsonl)
 */
export function getDailyLogFile(): string {
  ensureLogDirectory();
  const today = new Date().toISOString().split('T')[0]; // YYYY-MM-DD
  return join(LOG_DIR, `${today}.jsonl`);
}

/**
 * Append a log entry to JSONL file
 */
export function appendToJSONL(filePath: string, data: any): void {
  try {
    const jsonLine = JSON.stringify(data) + '\n';
    appendFileSync(filePath, jsonLine, 'utf-8');
    debug(`Logged to ${filePath}`);
  } catch (err) {
    debug(`Failed to append to log: ${err}`);
  }
}

/**
 * Generate a simple UUID v4
 */
export function generateUUID(): string {
  return 'xxxxxxxx-xxxx-4xxx-yxxx-xxxxxxxxxxxx'.replace(/[xy]/g, (c) => {
    const r = (Math.random() * 16) | 0;
    const v = c === 'x' ? r : (r & 0x3) | 0x8;
    return v.toString(16);
  });
}

/**
 * Detect patterns in prompt text
 */
export function detectPromptPatterns(promptText: string): DetectedPatterns {
  const lower = promptText.toLowerCase();

  return {
    isQuestion: /\?|^(what|how|why|when|where|who|can|could|should|would|is|are|do|does)/i.test(promptText),
    isRefactoring: /refactor|improve|optimize|clean|simplify|reorganize/.test(lower),
    isCreation: /create|new|add|build|implement|generate|make/.test(lower),
    isDebugging: /fix|debug|error|issue|problem|bug|broken|not working/.test(lower),
    isExploration: /show|what|how|explain|tell|describe|list/.test(lower),
    mentionsArchitecture: /repository|service|viewmodel|architecture|pattern|mvvm|di|dependency/.test(lower),
    mentionsTesting: /test|testing|spec|unittest|integration|e2e/.test(lower),
  };
}

/**
 * Count words in text
 */
export function countWords(text: string): number {
  return text.trim().split(/\s+/).filter(w => w.length > 0).length;
}

/**
 * Check if text contains code blocks
 */
export function hasCodeBlocks(text: string): boolean {
  return /```/.test(text);
}

/**
 * Get log directory path (for external scripts)
 */
export function getLogDirectory(): string {
  return LOG_DIR;
}
