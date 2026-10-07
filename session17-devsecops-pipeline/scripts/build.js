'use strict';

// Build step for the CI "build" job.
// Node.js has no compile step, so "build" means:
//   1. syntax-check every source file with `node --check`
//   2. assemble a deployable dist/ folder (src + package manifests)
//   3. write dist/build-info.json so the artifact is traceable to a commit

const { execFileSync } = require('node:child_process');
const fs = require('node:fs');
const path = require('node:path');

const root = path.resolve(__dirname, '..');
const srcDir = path.join(root, 'src');
const distDir = path.join(root, 'dist');

function listJsFiles(dir) {
  return fs.readdirSync(dir, { withFileTypes: true }).flatMap((entry) => {
    const full = path.join(dir, entry.name);
    if (entry.isDirectory()) return listJsFiles(full);
    return entry.name.endsWith('.js') ? [full] : [];
  });
}

const files = listJsFiles(srcDir);
for (const file of files) {
  // Fixed binary + argument array (no shell), so no command injection is possible.
  execFileSync(process.execPath, ['--check', file], { stdio: 'inherit' });
  console.log(`syntax ok  ${path.relative(root, file)}`);
}

fs.rmSync(distDir, { recursive: true, force: true });
fs.mkdirSync(distDir, { recursive: true });
fs.cpSync(srcDir, path.join(distDir, 'src'), { recursive: true });
for (const manifest of ['package.json', 'package-lock.json']) {
  fs.copyFileSync(path.join(root, manifest), path.join(distDir, manifest));
}

const pkg = require(path.join(root, 'package.json'));
const buildInfo = {
  name: pkg.name,
  version: pkg.version,
  commit: process.env.GITHUB_SHA || 'local',
  runId: process.env.GITHUB_RUN_ID || 'local',
  node: process.version,
  builtAt: new Date().toISOString(),
  files: files.length,
};
fs.writeFileSync(path.join(distDir, 'build-info.json'), `${JSON.stringify(buildInfo, null, 2)}\n`);

console.log(`build complete: ${files.length} source files -> ${path.relative(root, distDir)}/`);
console.log(JSON.stringify(buildInfo, null, 2));
