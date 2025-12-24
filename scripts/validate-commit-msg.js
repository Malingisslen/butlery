#!/usr/bin/env node
// Validates conventional commit message format
// Usage: node scripts/validate-commit-msg.js <commit-msg-file>

const fs = require('fs');

const commitMsgFile = process.argv[2];
if (!commitMsgFile) {
  console.error('Usage: node validate-commit-msg.js <commit-msg-file>');
  process.exit(1);
}

const message = fs.readFileSync(commitMsgFile, 'utf8').trim();

// Skip merge commits and fixup commits
if (message.startsWith('Merge ') || message.startsWith('fixup!') || message.startsWith('squash!')) {
  process.exit(0);
}

// Conventional commit pattern: type(scope)?: description
const pattern = /^(feat|fix|docs|style|refactor|perf|test|chore|ci)(\(.+\))?: .+/;

if (!pattern.test(message)) {
  console.log('');
  console.log('ERROR: Commit message does not follow conventional commits format');
  console.log('');
  console.log('Expected format: type(scope): description');
  console.log('');
  console.log('Types:');
  console.log('  feat     - New feature');
  console.log('  fix      - Bug fix');
  console.log('  docs     - Documentation changes');
  console.log('  style    - Code style changes (formatting, etc)');
  console.log('  refactor - Code refactoring');
  console.log('  perf     - Performance improvements');
  console.log('  test     - Test additions or changes');
  console.log('  chore    - Maintenance tasks');
  console.log('  ci       - CI/CD changes');
  console.log('');
  console.log('Examples:');
  console.log('  feat: add user authentication');
  console.log('  fix(auth): resolve login timeout issue');
  console.log('  docs: update README with setup instructions');
  console.log('');
  console.log('Your message was:');
  console.log('  ' + message.split('\n')[0]);
  console.log('');
  process.exit(1);
}

process.exit(0);
