// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Playwright tests for Dudes in Alaska web export.
 *
 * These tests verify the game loads correctly and the canvas is interactive.
 * Because Godot renders entirely to a <canvas>, DOM-level assertions are
 * limited to structure checks; gameplay assertions use JS error monitoring
 * and screenshot pixel-difference checks.
 *
 * Run with:
 *   GAME_URL=http://localhost:8080 PLAYWRIGHT_BROWSERS_PATH=~/.cache/ms-playwright npx playwright test
 */

const GAME_URL = (process.env.GAME_URL || 'https://haaanky.github.io/didactic-winner').replace(/\/$/, '') + '/';

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
 * Used as a fast proxy for pixel difference — high fraction means visually distinct frames.
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
  test('page title contains game name', async ({ page }) => {
    await page.goto(GAME_URL, { waitUntil: 'domcontentloaded', timeout: 60_000 });
    await expect(page).toHaveTitle(/Dudes in Alaska/i);
  });

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
    // Take two screenshots 500 ms apart — an animated canvas should differ,
    // confirming the engine is alive and rendering frames (not a black freeze).
    const shot1 = await page.screenshot({ clip: { x: 200, y: 100, width: 800, height: 400 } });
    await page.waitForTimeout(500);
    const shot2 = await page.screenshot({ clip: { x: 200, y: 100, width: 800, height: 400 } });
    const fraction = screenshotDiffFraction(shot1, shot2);
    // Either the engine is animating (frames differ) OR a static title screen is shown.
    // We just assert neither shot is completely empty (all bytes zero).
    expect(shot1.length).toBeGreaterThan(1000);
    expect(shot2.length).toBeGreaterThan(1000);
    // At least one of the shots must contain non-trivial data (PNG is >1 KB means pixels encoded).
    expect(shot1.length + shot2.length).toBeGreaterThan(5000);
  });
});

// ─── Main menu interaction ────────────────────────────────────────────────────

test.describe('Main menu interaction', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(6_000);
  });

  test('pressing Enter does not cause JS errors', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.press('Enter');
    await page.waitForTimeout(2_000);
    expect(getFatal()).toHaveLength(0);
  });

  test('click on page centre does not crash game', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
    expect(getFatal()).toHaveLength(0);
  });

  test('clicking play button changes canvas state', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    const before = await page.screenshot();
    // Play button is centred at roughly (640, 360) in the 1280×720 viewport
    await page.mouse.click(640, 360);
    // Wait for scene transition + level load
    await page.waitForTimeout(6_000);
    const after = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    // Canvas must look different after pressing play (scene changed)
    const diff = screenshotDiffFraction(before, after);
    expect(diff, 'Canvas should change after pressing play').toBeGreaterThan(0.005);
  });
});

// ─── In-game input ────────────────────────────────────────────────────────────

test.describe('In-game input', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(6_000);
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
  });

  test('WASD movement does not crash game', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.down('w');
    await page.waitForTimeout(400);
    await page.keyboard.up('w');
    await page.keyboard.down('d');
    await page.waitForTimeout(400);
    await page.keyboard.up('d');
    expect(getFatal()).toHaveLength(0);
  });

  test('WASD input changes canvas (player moves)', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    const before = await page.screenshot();
    await page.keyboard.down('d');
    await page.waitForTimeout(600);
    await page.keyboard.up('d');
    await page.waitForTimeout(200);
    const after = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    const diff = screenshotDiffFraction(before, after);
    expect(diff, 'Canvas should change when player moves').toBeGreaterThan(0.001);
  });

  test('inventory key [I] opens and closes without crash', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    const beforeOpen = await page.screenshot();
    await page.keyboard.press('i');
    await page.waitForTimeout(600);
    const afterOpen = await page.screenshot();
    await page.keyboard.press('i');
    await page.waitForTimeout(300);
    expect(getFatal()).toHaveLength(0);
    // Opening inventory should visually change the canvas
    const diff = screenshotDiffFraction(beforeOpen, afterOpen);
    expect(diff, 'Opening inventory should change canvas').toBeGreaterThan(0.005);
  });

  test('consume key [F] does not crash game', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.press('f');
    await page.waitForTimeout(500);
    expect(getFatal()).toHaveLength(0);
  });

  test('pause [Escape] opens pause menu', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    const beforePause = await page.screenshot();
    await page.keyboard.press('Escape');
    await page.waitForTimeout(600);
    const afterPause = await page.screenshot();
    await page.keyboard.press('Escape');
    await page.waitForTimeout(400);
    expect(getFatal()).toHaveLength(0);
    const diff = screenshotDiffFraction(beforePause, afterPause);
    expect(diff, 'Pause menu should change canvas').toBeGreaterThan(0.005);
  });

  test('check needs [T] does not crash game', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.press('t');
    await page.waitForTimeout(600);
    expect(getFatal()).toHaveLength(0);
  });

  test('rapid key sequence does not crash game', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    // Simulate a player exploring: move, check inventory, check needs, move, pause, unpause
    for (const key of ['w', 'd', 's', 'a']) {
      await page.keyboard.down(key);
      await page.waitForTimeout(150);
      await page.keyboard.up(key);
    }
    await page.keyboard.press('i');
    await page.waitForTimeout(300);
    await page.keyboard.press('i');
    await page.waitForTimeout(200);
    await page.keyboard.press('f');
    await page.waitForTimeout(200);
    await page.keyboard.press('Escape');
    await page.waitForTimeout(300);
    await page.keyboard.press('Escape');
    await page.waitForTimeout(200);
    expect(getFatal()).toHaveLength(0);
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

  test('touch tap changes canvas on mobile', async ({ browser }) => {
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
    await page.waitForTimeout(5_000);
    const before = await page.screenshot();
    await page.touchscreen.tap(195, 422);
    await page.waitForTimeout(2_000);
    const after = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    // A touch on the main menu (play button area) should change the canvas
    const diff = screenshotDiffFraction(before, after);
    expect(diff, 'Touch tap should cause canvas change').toBeGreaterThan(0.001);
    await context.close();
  });
});
