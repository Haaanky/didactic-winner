// @ts-check
/**
 * Playwright E2E test template for Godot 4 web exports.
 *
 * Copy this file to your project's tests/playwright/ directory and adapt
 * the game-specific tests (button positions, title text, key bindings) to
 * match your game.
 *
 * The GAME_URL is read from the environment — no hardcoded URLs.
 * Set GAME_URL when running:
 *   GAME_URL=http://localhost:8080 npx playwright test
 *   GAME_URL=https://your-username.github.io/your-repo/ npx playwright test
 */

const { test, expect } = require('@playwright/test');

const GAME_URL = (process.env.GAME_URL || '').replace(/\/$/, '') + '/';

if (!process.env.GAME_URL) {
  console.warn('WARNING: GAME_URL not set — tests will target an empty URL and fail.');
}

/** Navigate to the game and wait until the Godot canvas is in the DOM. */
async function loadGame(page) {
  await page.goto(GAME_URL, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  await page.locator('#canvas, canvas').first().waitFor({ state: 'attached', timeout: 90_000 });
}

/** Collect fatal JS errors on a page, ignoring known benign browser warnings. */
function collectFatalErrors(page) {
  const errors = [];
  page.on('pageerror', (err) => errors.push(err.message));
  return {
    getFatal: () =>
      errors.filter(
        (e) =>
          !e.includes('SharedArrayBuffer') &&
          !e.includes('AudioContext') &&
          !e.includes('coi-serviceworker') &&
          !e.includes('autoplay'),
      ),
  };
}

/**
 * Return the fraction of bytes that differ between two screenshot Buffers.
 */
function screenshotDiffFraction(buf1, buf2) {
  if (!buf1 || !buf2) return 1;
  const len = Math.min(buf1.length, buf2.length);
  let diff = 0;
  for (let i = 0; i < len; i++) {
    if (buf1[i] !== buf2[i]) diff++;
  }
  return diff / len;
}

// ─── Game loads ──────────────────────────────────────────────────────────────

test.describe('Game loads', () => {
  test('canvas element is present in DOM', async ({ page }) => {
    await loadGame(page);
    const canvas = page.locator('#canvas, canvas').first();
    await expect(canvas).toBeAttached({ timeout: 90_000 });
  });

  test('page has no fatal JS errors on load', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await loadGame(page);
    await page.waitForTimeout(5_000);
    expect(getFatal(), `Unexpected JS errors: ${getFatal().join('\n')}`).toHaveLength(0);
  });

  test('canvas has non-trivial dimensions after engine start', async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(3_000);
    const canvas = page.locator('#canvas, canvas').first();
    const box = await canvas.boundingBox();
    if (box !== null) {
      expect(box.width).toBeGreaterThan(100);
      expect(box.height).toBeGreaterThan(100);
    }
  });

  test('canvas renders non-blank content after engine start', async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(5_000);
    const shot1 = await page.screenshot({ clip: { x: 200, y: 100, width: 800, height: 400 } });
    await page.waitForTimeout(500);
    const shot2 = await page.screenshot({ clip: { x: 200, y: 100, width: 800, height: 400 } });
    expect(shot1.length).toBeGreaterThan(1000);
    expect(shot2.length).toBeGreaterThan(1000);
    expect(shot1.length + shot2.length).toBeGreaterThan(5000);
  });
});

// ─── Mobile touch ─────────────────────────────────────────────────────────────

test.describe('Mobile touch', () => {
  test('touch tap on game does not crash', async ({ browser }) => {
    const context = await browser.newContext({
      viewport: { width: 390, height: 844 },
      userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
      hasTouch: true,
    });
    const page = await context.newPage();
    const { getFatal } = collectFatalErrors(page);
    await page.goto(GAME_URL, { waitUntil: 'domcontentloaded', timeout: 60_000 });
    await page.locator('#canvas, canvas').first().waitFor({ state: 'attached', timeout: 90_000 });
    await page.waitForTimeout(4_000);
    await page.touchscreen.tap(195, 422);
    await page.waitForTimeout(1_000);
    expect(getFatal()).toHaveLength(0);
    await context.close();
  });
});

// ─── Add your game-specific tests below ──────────────────────────────────────
//
// Example: test that pressing a key does not crash
//
// test('pressing Enter does not cause JS errors', async ({ page }) => {
//   const { getFatal } = collectFatalErrors(page);
//   await loadGame(page);
//   await page.waitForTimeout(6_000);
//   await page.keyboard.press('Enter');
//   await page.waitForTimeout(2_000);
//   expect(getFatal()).toHaveLength(0);
// });
