'use strict';

// Writes a Markdown summary of the Jest run (from jest-junit + coverage-summary)
// to $GITHUB_STEP_SUMMARY, or to stdout when run locally.

const fs = require('node:fs');

const rows = [];

if (fs.existsSync('reports/junit.xml')) {
  const xml = fs.readFileSync('reports/junit.xml', 'utf8');
  const suite = xml.match(/<testsuites\b[^>]*>/);
  const attr = (name) => {
    const m = suite && suite[0].match(new RegExp(`\\b${name}="([^"]*)"`));
    return m ? m[1] : 'n/a';
  };
  rows.push(['Tests', attr('tests')], ['Failures', attr('failures')], ['Errors', attr('errors')], ['Time (s)', attr('time')]);
} else {
  rows.push(['Tests', 'no junit report found']);
}

if (fs.existsSync('coverage/coverage-summary.json')) {
  const total = JSON.parse(fs.readFileSync('coverage/coverage-summary.json', 'utf8')).total;
  for (const key of ['lines', 'statements', 'functions', 'branches']) {
    rows.push([`Coverage ${key}`, `${total[key].pct}%`]);
  }
}

const markdown = ['## Unit tests (Jest)', '', '| Metric | Value |', '|---|---|', ...rows.map(([k, v]) => `| ${k} | ${v} |`), ''].join('\n');

if (process.env.GITHUB_STEP_SUMMARY) {
  fs.appendFileSync(process.env.GITHUB_STEP_SUMMARY, `${markdown}\n`);
}
process.stdout.write(`${markdown}\n`);
