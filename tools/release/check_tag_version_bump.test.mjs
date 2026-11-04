// Self-test for check_tag_version_bump.mjs against throwaway git histories.
// Run: node --test tools/release/check_tag_version_bump.test.mjs

import { test } from 'node:test';
import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, mkdirSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { checkTagVersionBump, VERSION_FILE, WORD_LISTS } from './check_tag_version_bump.mjs';

function repo() {
  const dir = mkdtempSync(join(tmpdir(), 'tag-bump-'));
  const git = (...args) => execFileSync('git', args, { cwd: dir, stdio: 'pipe' });
  git('init', '-q');
  git('config', 'user.email', 't@example.com');
  git('config', 'user.name', 't');
  git('config', 'commit.gpgsign', 'false');
  const write = (path, text) => {
    mkdirSync(dirname(join(dir, path)), { recursive: true });
    writeFileSync(join(dir, path), text);
  };
  const commit = (message) => {
    git('add', '-A');
    git('commit', '-q', '-m', message);
  };
  const version = (v) => write(VERSION_FILE, `const String kTagGeneratorVersion = '${v}';\n`);
  return { dir, write, commit, version, done: () => rmSync(dir, { recursive: true, force: true }) };
}

test('unchanged word lists since the last version change pass', () => {
  const r = repo();
  try {
    r.version('1.0.0');
    r.write(WORD_LISTS, '{"a": ["x"]}\n');
    r.commit('start');
    r.write('other.txt', 'x');
    r.commit('unrelated');
    assert.equal(checkTagVersionBump('HEAD', r.dir).code, 0);
  } finally {
    r.done();
  }
});

test('a word-list change after the last version change is refused', () => {
  const r = repo();
  try {
    r.version('1.0.0');
    r.write(WORD_LISTS, '{"a": ["x"]}\n');
    r.commit('start');
    r.write(WORD_LISTS, '{"a": ["x", "y"]}\n');
    r.commit('words');
    const result = checkTagVersionBump('HEAD', r.dir);
    assert.equal(result.code, 1);
    assert.match(result.message, /Raise kTagGeneratorVersion/);
  } finally {
    r.done();
  }
});

test('raising the version after the word-list change, or in the same commit, passes', () => {
  const r = repo();
  try {
    r.version('1.0.0');
    r.write(WORD_LISTS, '{"a": ["x"]}\n');
    r.commit('start');
    r.write(WORD_LISTS, '{"a": ["x", "y"]}\n');
    r.commit('words');
    r.version('1.0.1');
    r.commit('bump');
    assert.equal(checkTagVersionBump('HEAD', r.dir).code, 0);
    r.write(WORD_LISTS, '{"a": ["z"]}\n');
    r.version('1.0.2');
    r.commit('words and bump together');
    assert.equal(checkTagVersionBump('HEAD', r.dir).code, 0);
  } finally {
    r.done();
  }
});

test('a comment or other line in the version file does not count as a version change', () => {
  const r = repo();
  try {
    r.version('1.0.0');
    r.write(WORD_LISTS, '{"a": ["x"]}\n');
    r.commit('start');
    r.write(WORD_LISTS, '{"a": ["y"]}\n');
    r.commit('words');
    r.write(VERSION_FILE, `// note\nconst String kTagGeneratorVersion = '1.0.0';\n`);
    r.commit('comment only');
    assert.equal(checkTagVersionBump('HEAD', r.dir).code, 1);
  } finally {
    r.done();
  }
});

test('an unknown ref or a history without a version line cannot be checked', () => {
  const r = repo();
  try {
    r.write(WORD_LISTS, '{}\n');
    r.commit('no version file');
    assert.equal(checkTagVersionBump('HEAD', r.dir).code, 2);
    assert.equal(checkTagVersionBump('nope', r.dir).code, 2);
  } finally {
    r.done();
  }
});
