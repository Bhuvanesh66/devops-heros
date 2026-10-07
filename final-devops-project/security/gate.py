#!/usr/bin/env python3
"""Security gate for the TaskFlow final project pipeline.

Every scanner job runs its tool in "report only" mode (exit code 0) and uploads a
JSON report. This script is the single decision point: it reads all reports,
applies the policy below and exits 1 (FAIL) or 0 (PASS).

Policy
  SAST     Semgrep        any finding with severity ERROR                 -> FAIL
                          any Semgrep run/config error                    -> FAIL
  SAST     Bandit         any HIGH severity issue (confidence >= MEDIUM)  -> FAIL
  SCA      pip-audit      any known vulnerability in a pinned dependency  -> FAIL
  SCA      npm audit      any HIGH or CRITICAL advisory                   -> FAIL
  SCA      Trivy fs       any HIGH or CRITICAL vulnerability              -> FAIL
  Secrets  Gitleaks       any secret at all                               -> FAIL
  Image    Trivy image    any HIGH/CRITICAL vulnerability or embedded
                          secret, backend and frontend image              -> FAIL
  Any      missing or unreadable report (the scan did not run)            -> FAIL

Usage:  python security/gate.py <reports-dir>
Writes a Markdown table to stdout, to $GITHUB_STEP_SUMMARY (when set) and to
<reports-dir>/gate-summary.md, plus <reports-dir>/gate-result.json.
Standard library only, so it runs on any runner without pip install.
"""

from __future__ import annotations

import json
import os
import sys
from collections import Counter
from collections.abc import Callable
from pathlib import Path

REPORTS = Path(sys.argv[1] if len(sys.argv) > 1 else "reports").resolve()
BLOCKING = {"HIGH", "CRITICAL"}
MAX_LISTED = 25


class ReportError(Exception):
    pass


def read_json(name: str):
    path = REPORTS / name
    if not path.is_file():
        raise ReportError(f"report {name} not found")
    text = path.read_text(encoding="utf-8").strip()
    if not text:
        raise ReportError(f"report {name} is empty")
    try:
        return json.loads(text)
    except json.JSONDecodeError as exc:
        raise ReportError(f"report {name} is not valid JSON ({exc})") from exc


def fmt_counts(counts: dict) -> str:
    parts = [f"{k}: {v}" for k, v in counts.items() if v]
    return ", ".join(parts) if parts else "none"


# ---- one parser per tool; each returns (blocking_count, details, findings) ----


def check_semgrep():
    report = read_json("semgrep.json")
    results = report.get("results", [])
    errors = [e for e in report.get("errors", []) if e.get("level") == "error"]
    by_sev = Counter(r.get("extra", {}).get("severity", "UNKNOWN") for r in results)
    blocking = [r for r in results if r.get("extra", {}).get("severity") == "ERROR"]
    findings = [f"{r['check_id']} at {r['path']}:{r['start']['line']}" for r in blocking]
    findings += [f"semgrep error: {e.get('message', '')[:160]}" for e in errors]
    details = f"{len(results)} findings ({fmt_counts(by_sev)})"
    if errors:
        details += f", {len(errors)} run errors"
    return len(blocking) + len(errors), details, findings


def check_bandit():
    report = read_json("bandit.json")
    results = report.get("results", [])
    by_sev = Counter(r.get("issue_severity", "UNDEFINED") for r in results)
    blocking = [
        r
        for r in results
        if r.get("issue_severity") == "HIGH" and r.get("issue_confidence") in {"MEDIUM", "HIGH"}
    ]
    findings = [
        f"{r['test_id']} {r['test_name']} at {r['filename']}:{r['line_number']}" for r in blocking
    ]
    return len(blocking), f"{len(results)} issues ({fmt_counts(by_sev)})", findings


def check_pip_audit():
    report = read_json("pip-audit.json")
    if not isinstance(report, dict) or "dependencies" not in report:
        raise ReportError("pip-audit.json has no 'dependencies' list")
    deps = report["dependencies"]
    vulns = [(d["name"], d.get("version"), v) for d in deps for v in d.get("vulns", [])]
    findings = [
        f"{v['id']} {name}=={ver} -> fix {', '.join(v.get('fix_versions') or ['none'])}"
        for name, ver, v in vulns
    ]
    return len(vulns), f"{len(deps)} packages, {len(vulns)} known vulnerabilities", findings


def check_npm_audit():
    report = read_json("npm-audit.json")
    if "error" in report:
        raise ReportError(f"npm audit failed: {report['error'].get('summary', report['error'])}")
    counts = report.get("metadata", {}).get("vulnerabilities", {})
    blocking = counts.get("high", 0) + counts.get("critical", 0)
    findings = [
        f"{v['name']} ({v['severity']}) range {v.get('range')}"
        for v in report.get("vulnerabilities", {}).values()
        if str(v.get("severity")).upper() in BLOCKING
    ]
    shown = {k: counts.get(k, 0) for k in ("critical", "high", "moderate", "low")}
    return blocking, f"{counts.get('total', 0)} advisories ({fmt_counts(shown)})", findings


def check_trivy(name: str):
    def _check():
        report = read_json(name)
        results = report.get("Results") or []
        vulns = [dict(v, Target=r.get("Target")) for r in results for v in r.get("Vulnerabilities") or []]
        secrets = [s for r in results for s in r.get("Secrets") or []]
        blocking = [v for v in vulns if v.get("Severity") in BLOCKING]
        findings = [
            f"{v['VulnerabilityID']} {v['Severity']} {v['PkgName']}@{v.get('InstalledVersion')}"
            f" -> {v.get('FixedVersion') or 'no fix'} ({v['Target']})"
            for v in blocking
        ]
        findings += [f"secret {s.get('RuleID')} ({s.get('Title')}) line {s.get('StartLine')}" for s in secrets]
        details = f"{len(vulns)} vulnerabilities ({fmt_counts(Counter(v.get('Severity') for v in vulns))})"
        if secrets:
            details += f", {len(secrets)} embedded secrets"
        return len(blocking) + len(secrets), details, findings

    return _check


def check_gitleaks():
    files = sorted(REPORTS.glob("gitleaks*.json")) if REPORTS.is_dir() else []
    if not files:
        raise ReportError("no gitleaks*.json report found")
    leaks = []
    for f in files:
        data = read_json(f.name)
        if not isinstance(data, list):
            raise ReportError(f"{f.name} is not a Gitleaks JSON array")
        leaks.extend(data)
    findings = [
        f"{x.get('RuleID')} in {x.get('File')}:{x.get('StartLine')}"
        + (f" (commit {x['Commit'][:7]})" if x.get("Commit") else "")
        for x in leaks
    ]
    return len(leaks), f"{len(leaks)} secrets in {len(files)} report(s)", findings


CHECKS: list[tuple[str, str, str, Callable]] = [
    ("SAST", "Semgrep", "severity ERROR", check_semgrep),
    ("SAST", "Bandit", "HIGH severity", check_bandit),
    ("SCA", "pip-audit", "any known vuln", check_pip_audit),
    ("SCA", "npm audit", "HIGH / CRITICAL", check_npm_audit),
    ("SCA", "Trivy fs", "HIGH / CRITICAL", check_trivy("trivy-fs.json")),
    ("Secret scan", "Gitleaks", "any secret", check_gitleaks),
    ("Image scan", "Trivy backend image", "HIGH / CRITICAL", check_trivy("trivy-image-backend.json")),
    ("Image scan", "Trivy frontend image", "HIGH / CRITICAL", check_trivy("trivy-image-frontend.json")),
]


def main() -> int:
    rows = []
    for stage, tool, policy, fn in CHECKS:
        try:
            blocking, details, findings = fn()
        except (ReportError, KeyError, TypeError, AttributeError) as exc:
            blocking, details, findings = 1, f"report problem: {exc}", []
        rows.append(
            {
                "stage": stage,
                "tool": tool,
                "policy": policy,
                "status": "PASS" if blocking == 0 else "FAIL",
                "blocking": blocking,
                "details": details,
                "findings": findings,
            }
        )

    failed = [r for r in rows if r["status"] == "FAIL"]
    verdict = "FAIL" if failed else "PASS"

    lines = [
        f"## Security gate: {verdict}",
        "",
        "| Stage | Tool | Blocks on | Result | Blocking | Details |",
        "|---|---|---|---|---:|---|",
    ]
    lines += [
        f"| {r['stage']} | {r['tool']} | {r['policy']} | **{r['status']}** | {r['blocking']} | {r['details']} |"
        for r in rows
    ]
    lines.append("")
    if failed:
        lines += ["### Blocking findings", ""]
        for r in failed:
            lines += [f"**{r['tool']}**", ""]
            shown = r["findings"][:MAX_LISTED]
            lines += [f"- `{f}`" for f in shown] or [f"- {r['details']}"]
            if len(r["findings"]) > len(shown):
                lines.append(f"- ... and {len(r['findings']) - len(shown)} more")
            lines.append("")
        lines.append("The images will **not** be pushed and nothing will be deployed.")
    else:
        lines.append("All security checks passed. The scanned images may be pushed and deployed.")
    markdown = "\n".join(lines) + "\n"

    print(markdown)
    try:
        REPORTS.mkdir(parents=True, exist_ok=True)
        (REPORTS / "gate-summary.md").write_text(markdown, encoding="utf-8")
        (REPORTS / "gate-result.json").write_text(
            json.dumps({"verdict": verdict, "checks": rows}, indent=2) + "\n", encoding="utf-8"
        )
    except OSError:
        print("warning: could not write gate summary files", file=sys.stderr)
    summary = os.environ.get("GITHUB_STEP_SUMMARY")
    if summary:
        with open(summary, "a", encoding="utf-8") as fh:
            fh.write(markdown)
    return 0 if verdict == "PASS" else 1


if __name__ == "__main__":
    sys.exit(main())
