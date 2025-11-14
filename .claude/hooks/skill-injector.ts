#!/usr/bin/env npx tsx

/**
 * Skill Injector Hook (UserPromptSubmit)
 *
 * Automatically detects relevant skills based on user prompt keywords and intent patterns,
 * then injects the full skill content into Claude's conversation context.
 *
 * Note: File-based triggers removed - only prompt-based matching is used.
 */

import { readFileSync, writeFileSync, existsSync, mkdirSync } from 'fs';
import { join, dirname } from 'path';
import { fileURLToPath } from 'url';
import type { HookInput, SkillRules, Skill } from './shared/types.js';
import { debug, measureTime } from './shared/logger.js';

// Get project root (two levels up from this script: .claude/hooks -> .claude -> project)
const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);
const PROJECT_ROOT = join(__dirname, '../..');
const CLAUDE_DIR = join(PROJECT_ROOT, '.claude');
const SKILLS_DIR = join(CLAUDE_DIR, 'skills');
const SKILL_RULES_FILE = join(CLAUDE_DIR, 'skill-rules.json');
const CACHE_DIR = join(CLAUDE_DIR, 'cache');
const SKILL_ACTIVATION_CACHE = join(CACHE_DIR, 'last-skill-activation.json');
const SESSION_CACHE_FILE = join(CACHE_DIR, 'session-skills.json');

/**
 * Main entry point
 */
async function main() {
  try {
    await measureTime('Skill Injection Total', async () => {
      // Read input from stdin
      const input = await readStdin();
      const hookInput: HookInput = JSON.parse(input);

      const prompt = hookInput.prompt || '';
      debug(`Processing prompt: ${prompt.substring(0, 100)}...`);

      // Load skill rules
      const skillRules = loadSkillRules();

      // Match skills (prompt-based only, no file triggers)
      const matchedSkills = matchSkills(prompt, skillRules);

      // Save activation results for prompt-logger
      saveSkillActivationResults(matchedSkills);

      if (matchedSkills.length === 0) {
        debug('No skills matched');
        return;
      }

      // Load session cache and filter new skills
      const cachedSkillNames = loadSessionCache();
      const { newSkills, cachedSkills } = filterNewSkills(matchedSkills, cachedSkillNames);

      debug(`Session cache: ${cachedSkills.length} cached, ${newSkills.length} new`);

      // Inject only new skill content
      injectSkills(newSkills, cachedSkills);

      // Update session cache with all skill names
      const allSkillNames = matchedSkills.map(s => s.name);
      saveSessionCache(allSkillNames);
    });
  } catch (err) {
    debug(`Skill injector error: ${err}`);
    // Exit 0 - don't break user workflow on errors
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
 * Load skill rules from JSON file
 */
function loadSkillRules(): SkillRules {
  try {
    const content = readFileSync(SKILL_RULES_FILE, 'utf-8');
    return JSON.parse(content);
  } catch (err) {
    debug(`Failed to load skill rules: ${err}`);
    return {};
  }
}

/**
 * Match skills based on prompt only (no file triggers)
 */
function matchSkills(
  prompt: string,
  skillRules: SkillRules
): Skill[] {
  const promptLower = prompt.toLowerCase();
  const matched: Skill[] = [];

  for (const [skillName, rules] of Object.entries(skillRules)) {
    const reasons: string[] = [];
    let skillMatched = false;

    // Check prompt triggers
    if (rules.promptTriggers) {
      // Check keywords
      if (rules.promptTriggers.keywords) {
        for (const keyword of rules.promptTriggers.keywords) {
          if (promptLower.includes(keyword.toLowerCase())) {
            skillMatched = true;
            reasons.push(`keyword:${keyword}`);
            break;
          }
        }
      }

      // Check intent patterns
      if (!skillMatched && rules.promptTriggers.intentPatterns) {
        for (const pattern of rules.promptTriggers.intentPatterns) {
          try {
            const regex = new RegExp(pattern, 'i');
            if (regex.test(promptLower)) {
              skillMatched = true;
              reasons.push(`intent:${pattern}`);
              break;
            }
          } catch (err) {
            debug(`Invalid regex pattern: ${pattern}`);
          }
        }
      }
    }

    if (skillMatched) {
      matched.push({
        name: skillName,
        priority: rules.priority,
        enforcement: rules.enforcement,
        reasons: reasons.slice(0, 2), // Show max 2 reasons
        location: join(SKILLS_DIR, skillName, 'SKILL.md')
      });
    }
  }

  // Sort by priority
  const priorityWeight = { critical: 3, high: 2, medium: 1 };
  matched.sort((a, b) => {
    const diff = priorityWeight[b.priority] - priorityWeight[a.priority];
    return diff !== 0 ? diff : a.name.localeCompare(b.name);
  });

  debug(`Matched ${matched.length} skills: ${matched.map(s => s.name).join(', ')}`);
  return matched;
}

/**
 * Load session skill cache
 */
function loadSessionCache(): string[] {
  try {
    if (!existsSync(SESSION_CACHE_FILE)) {
      return [];
    }

    const content = readFileSync(SESSION_CACHE_FILE, 'utf-8');
    const data = JSON.parse(content);
    return data.cachedSkills || [];
  } catch (err) {
    debug(`Failed to load session cache: ${err}`);
    return [];
  }
}

/**
 * Save session skill cache
 */
function saveSessionCache(skillNames: string[]) {
  try {
    // Ensure cache directory exists
    if (!existsSync(CACHE_DIR)) {
      mkdirSync(CACHE_DIR, { recursive: true });
    }

    const data = {
      timestamp: new Date().toISOString(),
      cachedSkills: skillNames,
    };

    writeFileSync(SESSION_CACHE_FILE, JSON.stringify(data, null, 2), 'utf-8');
    debug(`Saved ${skillNames.length} skills to session cache`);
  } catch (err) {
    debug(`Failed to save session cache: ${err}`);
  }
}

/**
 * Filter out skills that are already cached this session
 */
function filterNewSkills(skills: Skill[], cachedSkillNames: string[]): {
  newSkills: Skill[],
  cachedSkills: Skill[]
} {
  const newSkills: Skill[] = [];
  const cachedSkills: Skill[] = [];

  for (const skill of skills) {
    if (cachedSkillNames.includes(skill.name)) {
      cachedSkills.push(skill);
    } else {
      newSkills.push(skill);
    }
  }

  return { newSkills, cachedSkills };
}

/**
 * Inject skill content into stdout (Claude's context)
 */
function injectSkills(newSkills: Skill[], cachedSkills: Skill[]) {
  const totalSkills = newSkills.length + cachedSkills.length;

  // Output header
  console.log('');
  console.log('━'.repeat(80));
  console.log('🎯 BUTLERY ARCHITECTURE SKILLS - Auto-Injected');
  console.log('━'.repeat(80));
  console.log('');
  console.log(`${totalSkills} relevant skill(s) detected:`);
  console.log(`  • ${newSkills.length} new skill(s) injected into context`);
  console.log(`  • ${cachedSkills.length} skill(s) already in context (cached)`);
  console.log('');

  // List new skills
  if (newSkills.length > 0) {
    console.log('📝 NEW SKILLS (injecting content):');
    console.log('');
    newSkills.forEach((skill, index) => {
      const marker = skill.priority === 'critical' ? '[!]' : skill.priority === 'high' ? '[*]' : '[-]';
      const enforcement = skill.enforcement === 'enforce' ? 'REQUIRED' : 'RECOMMENDED';

      console.log(`${index + 1}. ${marker} **${skill.name}** [${skill.priority.toUpperCase()} - ${enforcement}]`);
      console.log(`   Location: ${skill.location}`);

      if (skill.reasons.length > 0) {
        console.log(`   Matched: ${skill.reasons.join(', ')}`);
      }

      console.log('');
    });
  }

  // List cached skills
  if (cachedSkills.length > 0) {
    console.log('♻️  CACHED SKILLS (already in your context):');
    console.log('');
    cachedSkills.forEach((skill, index) => {
      const marker = skill.priority === 'critical' ? '[!]' : skill.priority === 'high' ? '[*]' : '[-]';
      console.log(`${index + 1}. ${marker} **${skill.name}** [${skill.priority.toUpperCase()}]`);
    });
    console.log('');
  }

  console.log('━'.repeat(80));
  console.log('');

  // Only inject content for NEW skills
  if (newSkills.length > 0) {
    console.log('📖 SKILL CONTENT:');
    console.log('');

    for (const [index, skill] of newSkills.entries()) {
      try {
        const content = readFileSync(skill.location, 'utf-8');

        console.log('='.repeat(80));
        console.log(`Skill ${index + 1}/${newSkills.length}: ${skill.name} (${skill.priority.toUpperCase()})`);
        console.log('='.repeat(80));
        console.log('');
        console.log(content);
        console.log('');
      } catch (err) {
        console.log(`⚠️  Warning: Could not read skill file at ${skill.location}`);
        console.log(`   Error: ${err}`);
        console.log('');
      }
    }

    console.log('='.repeat(80));
    console.log('');
    console.log('✓ All new skills have been injected into your context.');
    console.log('  Use these patterns, examples, and guidelines in your response.');
    console.log('');
  } else {
    console.log('✓ All matched skills are already in your context from this session.');
    console.log('  No new content injected (saving ~15-20K tokens).');
    console.log('');
  }

  console.log('━'.repeat(80));
}

/**
 * Save skill activation results for prompt-logger to read
 */
function saveSkillActivationResults(skills: Skill[]) {
  try {
    // Ensure cache directory exists
    if (!existsSync(CACHE_DIR)) {
      mkdirSync(CACHE_DIR, { recursive: true });
    }

    // Convert skills to activation log format
    const activatedSkills = skills.map(skill => ({
      skillName: skill.name,
      priority: skill.priority,
      enforcement: skill.enforcement,
      matchReason: skill.reasons.map(reason => {
        const parts = reason.split(':');
        return {
          type: parts[0] as 'keyword' | 'intent' | 'file',
          pattern: parts[1] || reason,
          matchedText: parts[1] || undefined,
        };
      }),
    }));

    const data = {
      timestamp: new Date().toISOString(),
      activatedSkills,
    };

    writeFileSync(SKILL_ACTIVATION_CACHE, JSON.stringify(data, null, 2), 'utf-8');
    debug(`Saved ${skills.length} skill activations to cache`);
  } catch (err) {
    debug(`Failed to save skill activation results: ${err}`);
  }
}

// Run main
main().then(() => process.exit(0));
