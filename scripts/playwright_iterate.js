#!/usr/bin/env node
/**
 * scripts/playwright_iterate.js
 *
 * Runs the Playwright suite, parses results, and prints an SRS coverage report.
 * Intended to be called by the `playwright-iterate` GitHub Actions workflow
 * and also by a local `/loop` session via:
 *
 *   GAME_URL=http://localhost:8080 node scripts/playwright_iterate.js
 *
 * Exit code: 0 = all tests pass, 1 = one or more tests fail.
 */

'use strict';

const { execSync, spawnSync } = require('child_process');
const fs = require('fs');
const path = require('path');

// ── SRS requirement → test-title mapping ──────────────────────────────────────
//
// Each entry maps a short SRS id + description to an array of substrings that
// must appear in passing test titles for that requirement to be considered met.
// If the array is empty the requirement has no automated coverage yet (gap).
//
const SRS_REQUIREMENTS = [
  // Core loading
  { id: 'FR-WL-01', desc: 'Game page loads with correct title',      covered: ['page title contains game name'] },
  { id: 'FR-WL-02', desc: 'Canvas element renders in browser',        covered: ['canvas element is present in DOM'] },
  { id: 'FR-WL-03', desc: 'No fatal JS errors on load',              covered: ['page has no fatal JS errors on load'] },
  { id: 'FR-WL-04', desc: 'Canvas has non-trivial size',             covered: ['canvas has non-trivial dimensions'] },
  { id: 'FR-WL-05', desc: 'Engine renders non-blank frames',         covered: ['canvas renders non-blank content'] },

  // Main menu
  { id: 'FR-MM-01', desc: 'Main menu is interactive (Enter key)',    covered: ['pressing Enter does not cause JS errors'] },
  { id: 'FR-MM-02', desc: 'Main menu responds to mouse click',       covered: ['click on page centre does not crash'] },
  { id: 'FR-MM-03', desc: 'Play button transitions to game',         covered: ['clicking play button changes canvas'] },

  // Player movement (SRS §4.1)
  { id: 'FR-PC-01', desc: 'WASD movement works without crash',       covered: ['WASD movement does not crash'] },
  { id: 'FR-PC-01b', desc: 'WASD movement visibly moves player',     covered: ['WASD input changes canvas'] },
  { id: 'FR-PC-03', desc: 'Sprint key does not crash game',          covered: ['sprint [Shift] while moving does not crash'] },

  // Interaction (SRS §4.9)
  { id: 'FR-PC-04', desc: 'Interact key (E) does not crash',         covered: ['interact key [E] does not crash'] },

  // Needs system (FR-PC-02)
  { id: 'FR-PC-02', desc: 'Check-needs key (T) works',               covered: ['check needs [T] does not crash'] },

  // Inventory (FR-PC-06)
  { id: 'FR-PC-06', desc: 'Inventory opens and closes without crash', covered: ['inventory key [I] opens and closes'] },

  // Consume / food (FR-PC-06)
  { id: 'FR-PC-06b', desc: 'Consume key (F) works',                  covered: ['consume key [F] does not crash'] },

  // Journal (FR-UI-06)
  { id: 'FR-UI-06', desc: 'Journal opens and closes without crash',  covered: ['journal key [J] opens and closes'] },

  // Map (FR-WE-01)
  { id: 'FR-WE-01', desc: 'Map key (M) works without crash',        covered: ['map key [M] does not crash'] },

  // Pause / UI (FR-UI-07)
  { id: 'FR-UI-07a', desc: 'Pause menu opens on Escape',             covered: ['pause [Escape] opens pause menu'] },
  { id: 'FR-UI-07b', desc: 'Pause → resume cycle works',             covered: ['pause then resume restores canvas'] },
  { id: 'FR-UI-07c', desc: 'Pause → main menu navigates back',       covered: ['pause menu \u2192 main menu navigates back'] },

  // Rapid/stress input
  { id: 'FR-QA-01', desc: 'Rapid key sequence does not crash',       covered: ['rapid key sequence does not crash'] },

  // Mobile / touch (FR-UI-03)
  { id: 'FR-UI-03a', desc: 'Touch tap does not crash (mobile)',      covered: ['touch tap on game does not crash'] },
  { id: 'FR-UI-03b', desc: 'Touch tap changes canvas (mobile)',      covered: ['touch tap changes canvas on mobile'] },

  // ── Gaps: SRS requirements not yet covered by any Playwright test ────────
  { id: 'FR-PC-07',  desc: 'Appearance customisation (AppearanceComponent)', covered: [] },
  { id: 'FR-WE-04',  desc: 'Day/night cycle visible (TimeManager)',          covered: [] },
  { id: 'FR-WE-05',  desc: 'Season changes affect visual environment',       covered: [] },
  { id: 'FR-WE-06',  desc: 'Weather system (snow/rain/wind)',                covered: [] },
  { id: 'SRS-4.4',   desc: 'Building / construction system',                 covered: [] },
  { id: 'SRS-4.5',   desc: 'Vehicles (bicycle, car, canoe)',                 covered: [] },
  { id: 'SRS-4.6',   desc: 'Fishing system',                                 covered: [] },
  { id: 'SRS-4.7',   desc: 'Hunting and trapping',                           covered: [] },
  { id: 'SRS-4.8',   desc: 'Crafting system (craft menu opens)',              covered: ['crafting screen opens from inventory', 'crafting screen closes without crash'] },
  { id: 'SRS-4.9',   desc: 'Town and NPC interactions',                      covered: [] },
  { id: 'SRS-4.10',  desc: 'Pets system',                                    covered: [] },
  { id: 'SRS-4.11',  desc: 'Death and generational continuity',              covered: [] },
  { id: 'SRS-4.15',  desc: 'Difficulty modes selectable',                    covered: [] },
  { id: 'SRS-4.16',  desc: 'Save / load system',                             covered: ['Save/Load screen opens from pause menu', 'saving to slot 1 does not crash'] },
];

// ── Run Playwright ─────────────────────────────────────────────────────────────

const GAME_URL = process.env.GAME_URL || 'https://haaanky.github.io/didactic-winner';
const JSON_REPORT = path.join(__dirname, '..', 'playwright-results.json');

console.log(`\n🎭  Playwright iterate — targeting ${GAME_URL}\n`);

// Run with JSON reporter so we can parse results
const result = spawnSync(
  'npx',
  [
    'playwright', 'test',
    '--reporter=json',
  ],
  {
    env: { ...process.env, GAME_URL, PLAYWRIGHT_BROWSERS_PATH: process.env.PLAYWRIGHT_BROWSERS_PATH || `${process.env.HOME}/.cache/ms-playwright` },
    stdio: ['ignore', 'pipe', 'pipe'],
    cwd: path.join(__dirname, '..'),
  },
);

// Also print list output to stdout for human readability
const listResult = spawnSync(
  'npx',
  ['playwright', 'test', '--reporter=list'],
  {
    env: { ...process.env, GAME_URL, PLAYWRIGHT_BROWSERS_PATH: process.env.PLAYWRIGHT_BROWSERS_PATH || `${process.env.HOME}/.cache/ms-playwright` },
    stdio: ['ignore', 'inherit', 'inherit'],
    cwd: path.join(__dirname, '..'),
  },
);

// ── Parse results ──────────────────────────────────────────────────────────────

let passingTitles = [];
let failingTitles = [];

try {
  // JSON is written to stdout by Playwright's json reporter
  const raw = result.stdout.toString();
  const report = JSON.parse(raw);
  for (const suite of report.suites || []) {
    for (const spec of suite.specs || []) {
      const title = spec.title || '';
      const passed = spec.tests && spec.tests.every((t) => t.status === 'expected');
      if (passed) {
        passingTitles.push(title);
      } else {
        failingTitles.push(title);
      }
    }
    // Also handle nested suites
    for (const inner of suite.suites || []) {
      for (const spec of inner.specs || []) {
        const title = spec.title || '';
        const passed = spec.tests && spec.tests.every((t) => t.status === 'expected');
        if (passed) {
          passingTitles.push(title);
        } else {
          failingTitles.push(title);
        }
      }
    }
  }
  fs.writeFileSync(JSON_REPORT, raw);
} catch (e) {
  console.error('⚠️  Could not parse JSON reporter output:', e.message);
}

// ── SRS coverage report ────────────────────────────────────────────────────────

console.log('\n' + '─'.repeat(72));
console.log('SRS COVERAGE REPORT');
console.log('─'.repeat(72));

let covered = 0;
let uncovered = 0;
let failing = 0;
const gaps = [];

for (const req of SRS_REQUIREMENTS) {
  if (req.covered.length === 0) {
    // No test written yet
    gaps.push(req);
    uncovered++;
    continue;
  }

  // Check if all mapped test titles are in the passing list
  const allPass = req.covered.every((substring) =>
    passingTitles.some((t) => t.includes(substring)),
  );
  const anyFail = req.covered.some((substring) =>
    failingTitles.some((t) => t.includes(substring)),
  );

  if (anyFail) {
    console.log(`  ✘ ${req.id.padEnd(14)} ${req.desc}`);
    failing++;
  } else if (allPass) {
    console.log(`  ✓ ${req.id.padEnd(14)} ${req.desc}`);
    covered++;
  } else {
    // Titles not found in either list — test may not have run
    console.log(`  ? ${req.id.padEnd(14)} ${req.desc}  (title not matched)`);
    uncovered++;
  }
}

console.log('─'.repeat(72));
console.log(`\n  Covered & passing : ${covered}`);
console.log(`  Failing           : ${failing}`);
console.log(`  No test yet (gap) : ${gaps.length}`);
console.log('');

if (gaps.length > 0) {
  console.log('OPEN GAPS (SRS requirements without Playwright coverage):');
  for (const g of gaps) {
    console.log(`  • ${g.id.padEnd(14)} ${g.desc}`);
  }
  console.log('');
}

const exitCode = listResult.status !== 0 ? 1 : 0;
console.log(exitCode === 0 ? '✅  All tests passed.\n' : '❌  One or more tests failed.\n');
process.exit(exitCode);
