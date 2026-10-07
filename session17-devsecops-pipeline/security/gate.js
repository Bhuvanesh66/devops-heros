#!/usr/bin/env node
'use strict';

// Security gate for the Session 17 DevSecOps pipeline.
//
// Every scan job runs its scanner in "report only" mode (exit code 0) and uploads
// a JSON report. This script is the single decision point: it reads all reports,
// applies the policy below and exits 1 (FAIL) or 0 (PASS).
//
// Policy
//   SAST    Semgrep          any finding with severity ERROR          -> FAIL
//                            any Semgrep run/config error             -> FAIL
//   SCA     npm audit        any HIGH or CRITICAL advisory            -> FAIL
//   SCA     Trivy fs         any HIGH or CRITICAL vulnerability       -> FAIL
//   Secrets Gitleaks         any secret at all                        -> FAIL
//   Image   Trivy image      any HIGH or CRITICAL vulnerability       -> FAIL
//   Any     missing/broken report (scan did not run)                  -> FAIL
//
// Usage: node security/gate.js <reports-dir>
// Writes a Markdown table to $GITHUB_STEP_SUMMARY (when set), to stdout, and to
// <reports-dir>/gate-summary.md; writes <reports-dir>/gate-result.json.

const fs = require('node:fs');
const path = require('node:path');

const reportsDir = path.resolve(process.argv[2] || 'reports');
const BLOCKING_SEVERITIES = new Set(['HIGH', 'CRITICAL']);

function readJson(file) {
  const full = path.join(reportsDir, file);
  if (!fs.existsSync(full)) {
    throw new Error(`report ${file} not found`);
  }
  const text = fs.readFileSync(full, 'utf8').trim();
  if (text === '') {
    throw new Error(`report ${file} is empty`);
  }
  return JSON.parse(text);
}

function countBy(items, keyFn) {
  return items.reduce((acc, item) => {
    const key = keyFn(item);
    acc[key] = (acc[key] || 0) + 1;
    return acc;
  }, {});
}

function formatCounts(counts) {
  const parts = Object.entries(counts)
    .filter(([, n]) => n > 0)
    .map(([k, n]) => `${k}: ${n}`);
  return parts.length > 0 ? parts.join(', ') : 'none';
}

// --- one parser per tool. Each returns { blocking, details, findings[] } ---

function checkSemgrep() {
  const report = readJson('semgrep.json');
  const results = report.results || [];
  const runErrors = (report.errors || []).filter((e) => e.level === 'error');
  const bySeverity = countBy(results, (r) => (r.extra && r.extra.severity) || 'UNKNOWN');
  const blockingFindings = results.filter((r) => r.extra && r.extra.severity === 'ERROR');
  return {
    blocking: blockingFindings.length + runErrors.length,
    details: `${results.length} findings (${formatCounts(bySeverity)})${runErrors.length ? `, ${runErrors.length} run errors` : ''}`,
    findings: [
      ...blockingFindings.map((r) => `${r.check_id} at ${r.path}:${r.start.line}`),
      ...runErrors.map((e) => `semgrep error: ${e.message}`),
    ],
  };
}

function checkNpmAudit() {
  const report = readJson('npm-audit.json');
  if (report.error) {
    throw new Error(`npm audit failed: ${report.error.summary || JSON.stringify(report.error)}`);
  }
  const counts = (report.metadata && report.metadata.vulnerabilities) || {};
  const blocking = (counts.high || 0) + (counts.critical || 0);
  const vulns = Object.values(report.vulnerabilities || {});
  return {
    blocking,
    details: `${counts.total || 0} advisories (${formatCounts({
      critical: counts.critical || 0,
      high: counts.high || 0,
      moderate: counts.moderate || 0,
      low: counts.low || 0,
    })})`,
    findings: vulns
      .filter((v) => BLOCKING_SEVERITIES.has(String(v.severity).toUpperCase()))
      .map((v) => `${v.name} (${v.severity}) range ${v.range}`),
  };
}

function checkTrivy(file) {
  const report = readJson(file);
  const vulns = (report.Results || []).flatMap((r) =>
    (r.Vulnerabilities || []).map((v) => ({ ...v, Target: r.Target })),
  );
  const blockingVulns = vulns.filter((v) => BLOCKING_SEVERITIES.has(v.Severity));
  const secrets = (report.Results || []).flatMap((r) => r.Secrets || []);
  return {
    blocking: blockingVulns.length + secrets.length,
    details: `${vulns.length} vulnerabilities (${formatCounts(countBy(vulns, (v) => v.Severity))})${secrets.length ? `, ${secrets.length} embedded secrets` : ''}`,
    findings: [
      ...blockingVulns.map(
        (v) => `${v.VulnerabilityID} ${v.Severity} ${v.PkgName}@${v.InstalledVersion} -> ${v.FixedVersion || 'no fix'} (${v.Target})`,
      ),
      ...secrets.map((s) => `secret ${s.RuleID} (${s.Title}) at line ${s.StartLine}`),
    ],
  };
}

function checkGitleaks() {
  // The pipeline runs Gitleaks twice (current files + git history of the folder);
  // every gitleaks*.json report in the directory is counted.
  const files = fs.existsSync(reportsDir)
    ? fs.readdirSync(reportsDir).filter((f) => /^gitleaks.*\.json$/.test(f)).sort()
    : [];
  if (files.length === 0) {
    throw new Error('no gitleaks*.json report found');
  }
  const leaks = files.flatMap((f) => {
    const data = readJson(f);
    if (!Array.isArray(data)) throw new Error(`${f} is not a Gitleaks JSON array`);
    return data;
  });
  return {
    blocking: leaks.length,
    details: `${leaks.length} secrets in ${files.length} report(s)`,
    findings: leaks.map((l) => `${l.RuleID} in ${l.File}:${l.StartLine}${l.Commit ? ` (commit ${l.Commit.slice(0, 7)})` : ''}`),
  };
}

const checks = [
  { stage: 'SAST', tool: 'Semgrep', policy: 'severity ERROR', run: checkSemgrep },
  { stage: 'SCA', tool: 'npm audit', policy: 'HIGH / CRITICAL', run: checkNpmAudit },
  { stage: 'SCA', tool: 'Trivy fs', policy: 'HIGH / CRITICAL', run: () => checkTrivy('trivy-fs.json') },
  { stage: 'Secret scan', tool: 'Gitleaks', policy: 'any secret', run: checkGitleaks },
  { stage: 'Image scan', tool: 'Trivy image', policy: 'HIGH / CRITICAL', run: () => checkTrivy('trivy-image.json') },
];

const rows = checks.map((check) => {
  try {
    const result = check.run();
    return { ...check, ...result, status: result.blocking === 0 ? 'PASS' : 'FAIL' };
  } catch (err) {
    return { ...check, blocking: 1, details: `report problem: ${err.message}`, findings: [], status: 'FAIL' };
  }
});

const failed = rows.filter((r) => r.status === 'FAIL');
const verdict = failed.length === 0 ? 'PASS' : 'FAIL';

const lines = [
  `## Security gate: ${verdict}`,
  '',
  '| Stage | Tool | Blocks on | Result | Blocking | Details |',
  '|---|---|---|---|---:|---|',
  ...rows.map((r) => `| ${r.stage} | ${r.tool} | ${r.policy} | **${r.status}** | ${r.blocking} | ${r.details} |`),
  '',
];

if (failed.length > 0) {
  lines.push('### Blocking findings', '');
  for (const r of failed) {
    lines.push(`**${r.tool}**`, '');
    const shown = r.findings.slice(0, 25);
    if (shown.length === 0) lines.push(`- ${r.details}`);
    for (const f of shown) lines.push(`- \`${f}\``);
    if (r.findings.length > shown.length) lines.push(`- ... and ${r.findings.length - shown.length} more`);
    lines.push('');
  }
  lines.push('The image will **not** be pushed and nothing will be deployed.');
} else {
  lines.push('All security checks passed. The scanned image may be pushed and deployed.');
}

const markdown = `${lines.join('\n')}\n`;
process.stdout.write(markdown);

try {
  fs.mkdirSync(reportsDir, { recursive: true });
  fs.writeFileSync(path.join(reportsDir, 'gate-summary.md'), markdown);
  fs.writeFileSync(
    path.join(reportsDir, 'gate-result.json'),
    `${JSON.stringify({ verdict, checks: rows.map(({ run, ...rest }) => rest) }, null, 2)}\n`,
  );
} catch {
  console.error('warning: could not write gate summary files');
}

if (process.env.GITHUB_STEP_SUMMARY) {
  fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, markdown);
}

process.exit(verdict === 'PASS' ? 0 : 1);
