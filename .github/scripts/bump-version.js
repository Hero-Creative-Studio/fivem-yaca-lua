#!/usr/bin/env node
const fs = require('fs');
const { execFileSync } = require('child_process');

const manifestPath = process.env.FXMANIFEST_PATH || 'fxmanifest.lua';

function getHeadCommitMessage() {
  try {
    return execFileSync('git', ['log', '-1', '--pretty=%B'], { encoding: 'utf8' });
  } catch {
    return '';
  }
}

function bump(major, minor, patch, message) {
  if (/\[[\s]*major[\s]*\]/i.test(message)) return [major + 1, 0, 0];
  if (/\[[\s]*minor[\s]*\]/i.test(message)) return [major, minor + 1, 0];
  return [major, minor, patch + 1];
}

if (!fs.existsSync(manifestPath)) {
  console.error(`fxmanifest nicht gefunden: ${manifestPath}`);
  process.exit(1);
}

const content = fs.readFileSync(manifestPath, 'utf8');
const match = content.match(/version\s+['"](\d+)\.(\d+)\.(\d+)['"]/);

if (!match) {
  console.error(`Kein version 'x.y.z' Feld in ${manifestPath} gefunden.`);
  process.exit(1);
}

const major = parseInt(match[1], 10);
const minor = parseInt(match[2], 10);
const patch = parseInt(match[3], 10);
const [newMajor, newMinor, newPatch] = bump(major, minor, patch, getHeadCommitMessage());
const newVersion = `${newMajor}.${newMinor}.${newPatch}`;

fs.writeFileSync(
  manifestPath,
  content.replace(/version\s+['"]\d+\.\d+\.\d+['"]/, `version '${newVersion}'`),
  'utf8'
);

console.log(`Version: ${major}.${minor}.${patch} -> ${newVersion}`);

if (process.env.GITHUB_OUTPUT) {
  fs.appendFileSync(process.env.GITHUB_OUTPUT, `version=${newVersion}\n`);
}
