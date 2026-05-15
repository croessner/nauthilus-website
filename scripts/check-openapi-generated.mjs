#!/usr/bin/env node

import { spawnSync } from 'node:child_process';
import fs from 'node:fs';
import path from 'node:path';
import process from 'node:process';

const repoRoot = process.cwd();
const watchedDirs = [
  path.join(repoRoot, 'static', 'openapi'),
  path.join(repoRoot, 'docs', 'api-reference'),
];

function main() {
  const before = snapshotFiles(watchedDirs);

  try {
    runGeneration();
  } catch (error) {
    restoreSnapshot(before, watchedDirs);
    console.error(error.message);
    process.exitCode = 1;

    return;
  }

  const after = snapshotFiles(watchedDirs);
  const changes = compareSnapshots(before, after);

  restoreSnapshot(before, watchedDirs);

  if (changes.length > 0) {
    console.error('Generated OpenAPI docs are not up to date:');
    for (const change of changes) {
      console.error(`- ${change}`);
    }
    console.error('Run: npm run openapi:generate');
    process.exitCode = 1;

    return;
  }

  console.log('OpenAPI static specs and generated API docs are in sync.');
}

function runGeneration() {
  run('node', ['scripts/sync-openapi.mjs']);
  run(docusaurusBinary(), ['clean-api-docs', 'all']);
  run('node', ['scripts/sync-openapi.mjs']);
  run(docusaurusBinary(), ['gen-api-docs', 'all']);
  run('node', ['scripts/sync-openapi.mjs', '--clean-generated']);
}

function run(command, args) {
  const result = spawnSync(command, args, {
    cwd: repoRoot,
    encoding: 'utf8',
    env: process.env,
  });

  if (result.error) {
    throw result.error;
  }

  if (result.status !== 0) {
    process.stdout.write(result.stdout || '');
    process.stderr.write(result.stderr || '');

    throw new Error(`Command failed: ${[command, ...args].join(' ')}`);
  }
}

function docusaurusBinary() {
  const binary = process.platform === 'win32' ? 'docusaurus.cmd' : 'docusaurus';
  const localBinary = path.join(repoRoot, 'node_modules', '.bin', binary);

  if (fs.existsSync(localBinary)) {
    return localBinary;
  }

  return binary;
}

function snapshotFiles(directories) {
  const files = new Map();

  for (const directory of directories) {
    for (const filePath of listFiles(directory)) {
      files.set(relative(filePath), fs.readFileSync(filePath));
    }
  }

  return files;
}

function listFiles(directory) {
  if (!fs.existsSync(directory)) {
    return [];
  }

  return fs.readdirSync(directory, { withFileTypes: true })
    .flatMap((entry) => {
      const entryPath = path.join(directory, entry.name);

      if (entry.isDirectory()) {
        return listFiles(entryPath);
      }

      return [entryPath];
    });
}

function compareSnapshots(before, after) {
  const changes = [];
  const names = new Set([...before.keys(), ...after.keys()]);

  for (const name of [...names].sort()) {
    if (!before.has(name)) {
      changes.push(`${name} was generated`);

      continue;
    }

    if (!after.has(name)) {
      changes.push(`${name} should be removed`);

      continue;
    }

    if (!before.get(name).equals(after.get(name))) {
      changes.push(`${name} is stale`);
    }
  }

  return changes;
}

function restoreSnapshot(snapshot, directories) {
  const current = snapshotFiles(directories);

  for (const name of current.keys()) {
    if (!snapshot.has(name)) {
      fs.rmSync(path.join(repoRoot, name), { force: true });
    }
  }

  for (const [name, content] of snapshot) {
    const filePath = path.join(repoRoot, name);
    fs.mkdirSync(path.dirname(filePath), { recursive: true });
    fs.writeFileSync(filePath, content);
  }
}

function relative(filePath) {
  return path.relative(repoRoot, filePath);
}

main();
