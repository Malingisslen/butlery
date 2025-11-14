#!/usr/bin/env npx tsx

/**
 * Architecture Validator Hook (PostToolUse)
 *
 * Validates architecture patterns and blocks critical violations before code is written.
 */

import { readFileSync, existsSync } from 'fs';
import type { HookInput, ValidationResult, Violation, Warning } from './shared/types.js';
import { debug } from './shared/logger.js';

/**
 * Main entry point
 */
async function main() {
  try {
    // Read input from stdin
    const input = await readStdin();
    const hookInput: HookInput = JSON.parse(input);

    // Only validate Edit/Write operations
    if (!['Edit', 'Write', 'MultiEdit'].includes(hookInput.tool_name || '')) {
      debug('Not an edit operation, skipping validation');
      process.exit(0);
    }

    const filePath = hookInput.tool_input?.file_path;
    if (!filePath) {
      debug('No file path provided');
      process.exit(0);
    }

    // Only validate Dart files
    if (!filePath.endsWith('.dart')) {
      debug('Not a Dart file, skipping validation');
      process.exit(0);
    }

    // Skip test files and certain patterns
    if (shouldSkipFile(filePath)) {
      debug(`Skipping validation for ${filePath}`);
      process.exit(0);
    }

    // Read file content
    if (!existsSync(filePath)) {
      debug(`File does not exist yet: ${filePath}`);
      process.exit(0);
    }

    const content = readFileSync(filePath, 'utf-8');

    // Validate architecture patterns
    const result = validateArchitecture(filePath, content);

    // Report violations
    if (result.violations.length > 0) {
      reportViolations(filePath, result.violations);
      process.exit(1); // Block on violations
    }

    // Report warnings (non-blocking)
    if (result.warnings.length > 0) {
      reportWarnings(filePath, result.warnings);
    }

    debug('Architecture validation passed');
    process.exit(0);
  } catch (err) {
    debug(`Architecture validator error: ${err}`);
    process.exit(0); // Don't break workflow on errors
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
 * Check if file should be skipped
 */
function shouldSkipFile(filePath: string): boolean {
  return (
    filePath.includes('/test/') ||
    filePath.includes('_test.dart') ||
    filePath.includes('/core/di/') || // DI setup files are exempt
    filePath.includes('firebase_options') ||
    filePath.includes('.g.dart')
  );
}

/**
 * Validate architecture patterns in file
 */
function validateArchitecture(filePath: string, content: string): ValidationResult {
  const violations: Violation[] = [];
  const warnings: Warning[] = [];

  // CRITICAL 1: Check for direct FirebaseFirestore.instance usage
  if (content.includes('FirebaseFirestore.instance')) {
    // Allow specific fallback patterns
    if (
      !content.includes('firestore ?? FirebaseFirestore.instance') &&
      !content.includes('_firestoreRepository.firestore')
    ) {
      const lines = content.split('\n');
      const lineNumbers = lines
        .map((line, idx) => (line.includes('FirebaseFirestore.instance') ? idx + 1 : -1))
        .filter(ln => ln > 0);

      violations.push({
        type: 'critical',
        pattern: 'FirebaseFirestore.instance',
        line: lineNumbers[0],
        message: 'Direct FirebaseFirestore.instance usage detected',
        fix: 'Inject FirestoreRepository via constructor instead:\n' +
             '  MyService({required FirestoreRepository repository})'
      });
    }
  }

  // CRITICAL 2: Check for legacy sl<T>() pattern
  if (content.match(/\bsl</)) {
    const lines = content.split('\n');
    const lineNumbers = lines
      .map((line, idx) => (line.match(/\bsl</) ? idx + 1 : -1))
      .filter(ln => ln > 0);

    violations.push({
      type: 'critical',
      pattern: 'sl<T>()',
      line: lineNumbers[0],
      message: 'Legacy sl<T>() pattern detected',
      fix: 'Use ServiceLocator.get<T>() instead:\n' +
           '  final service = ServiceLocator.get<MyService>();'
    });
  }

  // STYLE 1: Check file size (>500 LOC warning)
  const lines = content.split('\n');
  if (lines.length > 500) {
    // Check if it's using facade pattern (has extracted modules/managers)
    const hasFacadePattern = content.includes('Manager') ||
                            content.includes('Module') ||
                            content.includes('Operations');

    if (!hasFacadePattern) {
      warnings.push({
        type: 'file-size',
        message: `File exceeds 500 lines (${lines.length} lines)`,
        suggestion: 'Consider using facade pattern with extracted modules\n' +
                   '  Example: recipe_form_viewmodel.dart uses 6 focused managers'
      });
    }
  }

  // STYLE 2: Check for manual null coalescing instead of extensions
  if (content.match(/\?\? ['"]/)) {
    warnings.push({
      type: 'null-coalescing',
      message: 'Manual null coalescing detected',
      suggestion: 'Use default value extensions instead:\n' +
                 '  value.orEmpty() instead of value ?? \'\''
    });
  }

  return { passed: violations.length === 0, violations, warnings };
}

/**
 * Report violations to stderr (user) and stdout (Claude)
 */
function reportViolations(filePath: string, violations: Violation[]) {
  const output = [
    '',
    '❌ ARCHITECTURE VIOLATION DETECTED',
    '━'.repeat(80),
    '',
    `File: ${filePath}`,
    '',
    ...violations.map(v => [
      `${v.type === 'critical' ? '🔴 CRITICAL' : '⚠️  STYLE'}: ${v.message}`,
      v.line ? `  Line: ${v.line}` : '',
      `  Pattern: ${v.pattern}`,
      '',
      v.fix ? `💡 FIX:\n${v.fix.split('\n').map(l => `  ${l}`).join('\n')}` : '',
      ''
    ]).flat(),
    '━'.repeat(80),
    '',
    '❌ Edit blocked. Please fix the violation above.',
    ''
  ].join('\n');

  // Output to both stderr (user) and stdout (Claude)
  console.error(output);
  console.log(output);
}

/**
 * Report warnings to stderr (non-blocking)
 */
function reportWarnings(filePath: string, warnings: Warning[]) {
  const output = [
    '',
    '⚠️  Architecture Warnings',
    '─'.repeat(80),
    '',
    `File: ${filePath}`,
    '',
    ...warnings.map(w => [
      `⚠️  ${w.message}`,
      w.suggestion ? `💡 ${w.suggestion.split('\n').map(l => `  ${l}`).join('\n')}` : '',
      ''
    ]).flat(),
    '─'.repeat(80),
    ''
  ].join('\n');

  console.error(output);
}

// Run main
main();
