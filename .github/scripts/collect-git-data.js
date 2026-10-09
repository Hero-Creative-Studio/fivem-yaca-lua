#!/usr/bin/env node
const fs = require('fs');
const { execFileSync } = require('child_process');

function parseMultilineEnv(name) {
  return (process.env[name] || '')
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter(Boolean);
}

const includePaths = parseMultilineEnv('INCLUDE_PATHS');

function git(args, allowFail = false) {
  try {
    return execFileSync('git', args, {
      encoding: 'utf8',
      stdio: ['pipe', 'pipe', 'pipe'],
    }).trim();
  } catch {
    if (allowFail) return '';
    throw new Error(`git ${args.join(' ')} fehlgeschlagen`);
  }
}

function isIncludedInZip(filePath) {
  return includePaths.some((p) => filePath === p || filePath.startsWith(`${p}/`));
}

function getLastReleaseTag() {
  const tags = git(['tag', '--sort=-v:refname'], true)
    .split(/\r?\n/)
    .map((t) => t.trim())
    .filter(Boolean);
  return tags.length > 0 ? tags[0] : null;
}

function shouldExcludeCommit(title) {
  const t = title.trim();
  if (!t) return true;
  if (/\[skip\s*ci\]/i.test(t)) return true;
  if (/^wip\b/i.test(t)) return true;
  if (/^fix typo\b/i.test(t)) return true;
  if (/^merge\b/i.test(t)) return true;
  return false;
}

function collectCommits(lastTag) {
  const raw = lastTag
    ? git(['log', `${lastTag}..HEAD`, '--pretty=format:%s'], true)
    : git(['log', '--pretty=format:%s'], true);

  return raw
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter((s) => s && !shouldExcludeCommit(s));
}

function collectChangedFiles(lastTag) {
  const raw = lastTag
    ? git(['diff', '--name-only', `${lastTag}..HEAD`], true)
    : git(['ls-files'], true);

  return raw
    .split(/\r?\n/)
    .map((s) => s.trim())
    .filter((s) => s && isIncludedInZip(s))
    .sort();
}

function toBulletMarkdown(items, emptyText) {
  if (!items || items.length === 0) return emptyText;
  return items.map((i) => `- ${i}`).join('\n');
}

const lastTag = getLastReleaseTag();
console.log(lastTag ? `Git-Daten seit Tag: ${lastTag}` : 'Erstes Release');

const commits = collectCommits(lastTag);
const changedFiles = collectChangedFiles(lastTag);

fs.writeFileSync(
  'release-body.md',
  [
    '## Commits',
    '',
    toBulletMarkdown(commits, '_Keine relevanten Commits_'),
    '',
    '## Changed files',
    '',
    toBulletMarkdown(changedFiles, '_Keine Dateiänderungen_'),
    '',
  ].join('\n'),
  'utf8'
);

console.log(fs.readFileSync('release-body.md', 'utf8'));
