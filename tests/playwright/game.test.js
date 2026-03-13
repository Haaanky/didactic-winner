// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Playwright tests for Dudes in Alaska web export.
 *
 * These tests verify the game loads correctly and the canvas is interactive.
 * Because Godot renders entirely to a <canvas>, DOM-level assertions are
 * limited to structure checks; gameplay assertions use JS error monitoring.
 *
 * Run with:
 *   PLAYWRIGHT_BROWSERS_PATH=~/.cache/ms-playwright npx playwright test
 */

const GAME_URL = (process.env.GAME_URL || 'https://haaanky.github.io/didactic-winner').replace(/\/$/, '') + '/';

/** Navigate to the game and wait until the Godot canvas is in the DOM. */
async function loadGame(page) {
  await page.goto(GAME_URL, { waitUntil: 'domcontentloaded', timeout: 60_000 });
  await page.locator('#canvas, canvas').first().waitFor({ state: 'attached', timeout: 90_000 });
}

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
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));
    await loadGame(page);
    await page.waitForTimeout(5_000);
    const fatal = errors.filter(
      (e) =>
        !e.includes('SharedArrayBuffer') &&
        !e.includes('AudioContext') &&
        !e.includes('coi-serviceworker') &&
        !e.includes('autoplay'),
    );
    expect(fatal, `Unexpected JS errors: ${fatal.join('\n')}`).toHaveLength(0);
  });

  test('canvas has non-trivial dimensions after engine start', async ({ page }) => {
    await loadGame(page);
    // Give Godot time to resize canvas to viewport
    await page.waitForTimeout(3_000);
    const canvas = page.locator('#canvas, canvas').first();
    const box = await canvas.boundingBox();
    if (box !== null) {
      expect(box.width).toBeGreaterThan(100);
      expect(box.height).toBeGreaterThan(100);
    }
  });
});

test.describe('Main menu interaction', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    // Allow Godot to fully initialise the main menu scene
    await page.waitForTimeout(6_000);
  });

  test('pressing Enter does not cause JS errors', async ({ page }) => {
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));
    await page.keyboard.press('Enter');
    await page.waitForTimeout(2_000);
    const fatal = errors.filter(
      (e) => !e.includes('AudioContext') && !e.includes('SharedArrayBuffer'),
    );
    expect(fatal).toHaveLength(0);
  });

  test('click on page centre does not crash game', async ({ page }) => {
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
    const fatal = errors.filter(
      (e) => !e.includes('AudioContext') && !e.includes('SharedArrayBuffer'),
    );
    expect(fatal).toHaveLength(0);
  });
});

test.describe('In-game input', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    // Boot + main menu wait
    await page.waitForTimeout(6_000);
    // Attempt to start game: click play button area
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    // Dismiss controls overlay
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
  });

  test('WASD movement does not crash game', async ({ page }) => {
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));
    await page.keyboard.down('w');
    await page.waitForTimeout(400);
    await page.keyboard.up('w');
    await page.keyboard.down('d');
    await page.waitForTimeout(400);
    await page.keyboard.up('d');
    const fatal = errors.filter(
      (e) => !e.includes('AudioContext') && !e.includes('SharedArrayBuffer'),
    );
    expect(fatal).toHaveLength(0);
  });

  test('inventory key [I] does not crash game', async ({ page }) => {
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));
    await page.keyboard.press('i');
    await page.waitForTimeout(600);
    await page.keyboard.press('i');
    await page.waitForTimeout(300);
    const fatal = errors.filter(
      (e) => !e.includes('AudioContext') && !e.includes('SharedArrayBuffer'),
    );
    expect(fatal).toHaveLength(0);
  });

  test('consume key [F] does not crash game', async ({ page }) => {
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));
    await page.keyboard.press('f');
    await page.waitForTimeout(500);
    const fatal = errors.filter(
      (e) => !e.includes('AudioContext') && !e.includes('SharedArrayBuffer'),
    );
    expect(fatal).toHaveLength(0);
  });

  test('pause [Escape] toggles without crash', async ({ page }) => {
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));
    await page.keyboard.press('Escape');
    await page.waitForTimeout(600);
    await page.keyboard.press('Escape');
    await page.waitForTimeout(400);
    const fatal = errors.filter(
      (e) => !e.includes('AudioContext') && !e.includes('SharedArrayBuffer'),
    );
    expect(fatal).toHaveLength(0);
  });

  test('check needs [T] does not crash game', async ({ page }) => {
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));
    await page.keyboard.press('t');
    await page.waitForTimeout(600);
    const fatal = errors.filter(
      (e) => !e.includes('AudioContext') && !e.includes('SharedArrayBuffer'),
    );
    expect(fatal).toHaveLength(0);
  });
});

test.describe('Mobile touch', () => {
  test('touch tap on game does not crash', async ({ browser }) => {
    const context = await browser.newContext({
      viewport: { width: 390, height: 844 },
      userAgent:
        'Mozilla/5.0 (iPhone; CPU iPhone OS 16_0 like Mac OS X) AppleWebKit/605.1.15',
      hasTouch: true,
    });
    const page = await context.newPage();
    const errors = [];
    page.on('pageerror', (err) => errors.push(err.message));
    await page.goto(GAME_URL, { waitUntil: 'domcontentloaded', timeout: 60_000 });
    await page.locator('#canvas, canvas').first().waitFor({ state: 'attached', timeout: 90_000 });
    await page.waitForTimeout(4_000);
    await page.touchscreen.tap(195, 422);
    await page.waitForTimeout(1_000);
    const fatal = errors.filter(
      (e) => !e.includes('AudioContext') && !e.includes('SharedArrayBuffer'),
    );
    expect(fatal).toHaveLength(0);
    await context.close();
  });
});
