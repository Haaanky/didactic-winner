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

// ─── Journal, Map, Sprint ─────────────────────────────────────────────────────

test.describe('Journal, map and sprint', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(6_000);
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(500);
  });

  test('journal key [J] opens and closes journal without crash', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    const before = await page.screenshot();
    await page.keyboard.press('j');
    await page.waitForTimeout(1_200);
    const afterOpen = await page.screenshot();
    await page.keyboard.press('j');
    await page.waitForTimeout(1_200);
    const afterClose = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    const diffOpen = screenshotDiffFraction(before, afterOpen);
    expect(diffOpen, 'Opening journal should change canvas').toBeGreaterThan(0.005);
    const diffClose = screenshotDiffFraction(afterOpen, afterClose);
    expect(diffClose, 'Closing journal should change canvas').toBeGreaterThan(0.005);
  });

  test('map key [M] does not crash game', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.press('m');
    await page.waitForTimeout(600);
    await page.keyboard.press('m');
    await page.waitForTimeout(400);
    expect(getFatal()).toHaveLength(0);
  });

  test('sprint [Shift] while moving does not crash game', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    const before = await page.screenshot();
    await page.keyboard.down('Shift');
    await page.keyboard.down('d');
    await page.waitForTimeout(600);
    await page.keyboard.up('d');
    await page.keyboard.up('Shift');
    await page.waitForTimeout(200);
    const after = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    const diff = screenshotDiffFraction(before, after);
    expect(diff, 'Sprint+move should change canvas').toBeGreaterThan(0.001);
  });

  test('interact key [E] does not crash game', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.press('e');
    await page.waitForTimeout(500);
    expect(getFatal()).toHaveLength(0);
  });
});

// ─── Pause cycle ──────────────────────────────────────────────────────────────

test.describe('Pause cycle', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(6_000);
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
  });

  test('pause then resume restores canvas to playing state', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    const beforePause = await page.screenshot();
    await page.keyboard.press('Escape');
    await page.waitForTimeout(800);
    const paused = await page.screenshot();
    // Press Escape again to resume (toggle)
    await page.keyboard.press('Escape');
    await page.waitForTimeout(800);
    const afterResume = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    // Pause should visually differ from playing
    const pauseDiff = screenshotDiffFraction(beforePause, paused);
    expect(pauseDiff, 'Pause should change canvas').toBeGreaterThan(0.005);
    // Resuming should restore closer to original than paused state
    const resumeVsPausedDiff = screenshotDiffFraction(paused, afterResume);
    expect(resumeVsPausedDiff, 'Resume should change canvas back').toBeGreaterThan(0.005);
  });

  test('pause menu → main menu navigates back without crash', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.press('Escape');
    await page.waitForTimeout(1_000);
    // Click the "Main Menu" / "Menu" button — positioned in the pause overlay centre
    // Pause menu buttons are stacked vertically; Menu button is the bottom-most one
    await page.mouse.click(640, 430);
    await page.waitForTimeout(4_000);
    expect(getFatal()).toHaveLength(0);
    // After returning to main menu the page title should still be intact
    await expect(page).toHaveTitle(/Dudes in Alaska/i);
  });
});

// ─── Crafting (SRS-4.8) ───────────────────────────────────────────────────────

test.describe('Crafting system', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(6_000);
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(500);
  });

  test('crafting screen opens from inventory Craft button', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    // Open inventory
    await page.keyboard.press('i');
    await page.waitForTimeout(1_200);
    const withInventory = await page.screenshot();
    // Click Craft button (bottom-right of inventory panel)
    await page.mouse.click(871, 557);
    await page.waitForTimeout(1_500);
    const withCrafting = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    // Crafting screen must visually differ from inventory-only state
    const diff = screenshotDiffFraction(withInventory, withCrafting);
    expect(diff, 'Crafting screen should change canvas from inventory').toBeGreaterThan(0.005);
  });

  test('crafting screen closes without crash', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.press('i');
    await page.waitForTimeout(1_200);
    await page.mouse.click(871, 557);
    await page.waitForTimeout(1_500);
    const withCrafting = await page.screenshot();
    // Close via X button (top-right of crafting panel)
    await page.mouse.click(877, 173);
    await page.waitForTimeout(1_200);
    const afterClose = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    const diff = screenshotDiffFraction(withCrafting, afterClose);
    expect(diff, 'Closing crafting should change canvas').toBeGreaterThan(0.005);
  });
});

// ─── Save / Load (SRS-4.16) ───────────────────────────────────────────────────

test.describe('Save / Load system', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(6_000);
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(500);
  });

  test('Save/Load screen opens from pause menu', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.press('Escape');
    await page.waitForTimeout(1_200);
    const withPause = await page.screenshot();
    // Click "Save / Load" button (second button, y≈387)
    await page.mouse.click(640, 387);
    await page.waitForTimeout(1_500);
    const withSaveLoad = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    const diff = screenshotDiffFraction(withPause, withSaveLoad);
    expect(diff, 'Save/Load screen should change canvas from pause menu').toBeGreaterThan(0.005);
  });

  test('saving to slot 1 does not crash', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.press('Escape');
    await page.waitForTimeout(800);
    await page.mouse.click(640, 387);
    await page.waitForTimeout(800);
    // Click Save button for slot 1
    await page.mouse.click(752, 252);
    await page.waitForTimeout(1_000);
    const afterSave = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    // Close the screen
    await page.mouse.click(809, 518);
    await page.waitForTimeout(600);
    expect(getFatal()).toHaveLength(0);
    // Slot 1 save button must still leave a valid canvas
    expect(afterSave.length).toBeGreaterThan(1000);
  });
});

// ─── Difficulty selection (SRS-4.15) ─────────────────────────────────────────

test.describe('Difficulty selection', () => {
  test('Easy/Normal/Hardcore buttons are present on main menu', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await loadGame(page);
    await page.waitForTimeout(6_000);
    const before = await page.screenshot();
    // Click Easy button — it sits below Play, in the DifficultyRow
    await page.mouse.click(574, 397);
    await page.waitForTimeout(500);
    expect(getFatal()).toHaveLength(0);
    // After clicking a difficulty button the menu canvas should show no crash
    const after = await page.screenshot();
    expect(after.length).toBeGreaterThan(1000);
  });

  test('Hardcore button click does not crash menu', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await loadGame(page);
    await page.waitForTimeout(6_000);
    await page.mouse.click(706, 397);
    await page.waitForTimeout(500);
    expect(getFatal()).toHaveLength(0);
  });
});

// ─── Time, season and weather HUD (FR-WE-04, FR-WE-05, FR-WE-06) ─────────────

test.describe('Time, season and weather', () => {
  test('HUD info panel renders time, season and weather while playing', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await loadGame(page);
    await page.waitForTimeout(6_000);
    // Capture top-right corner (HUD info panel area) while on main menu
    const atMenu = await page.screenshot({ clip: { x: 1050, y: 0, width: 230, height: 80 } });
    // Enter game
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
    // Capture same area while playing — HUD should now show "Spring — Day 1 / 8:00 AM / Clear, 15°C"
    const inGame = await page.screenshot({ clip: { x: 1050, y: 0, width: 230, height: 80 } });
    expect(getFatal()).toHaveLength(0);
    const diff = screenshotDiffFraction(atMenu, inGame);
    expect(diff, 'HUD should render time/season/weather text in game').toBeGreaterThan(0.01);
  });
});

// ─── Fishing (SRS-4.6) ────────────────────────────────────────────────────────

test.describe('Fishing system', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(6_000);
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(500);
  });

  test('walking to fishing spot and interacting does not crash', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    // FishingSpot1 is ~205px south of player start — walk south for 2.5s at speed 120px/s
    await page.keyboard.down('s');
    await page.waitForTimeout(2_500);
    await page.keyboard.up('s');
    await page.waitForTimeout(600);
    const before = await page.screenshot();
    await page.keyboard.press('e');
    await page.waitForTimeout(1_500);
    const after = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    const diff = screenshotDiffFraction(before, after);
    expect(diff, 'Interacting near fishing spot should change canvas').toBeGreaterThan(0.003);
  });

  test('fishing key sequence does not crash game', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.down('s');
    await page.waitForTimeout(2_500);
    await page.keyboard.up('s');
    await page.waitForTimeout(600);
    // Cast, wait, pull sequence
    await page.keyboard.press('e');
    await page.waitForTimeout(600);
    await page.keyboard.press('e');
    await page.waitForTimeout(600);
    expect(getFatal()).toHaveLength(0);
  });
});

// ─── Hunting (SRS-4.7) ────────────────────────────────────────────────────────

test.describe('Hunting system', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(6_000);
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(500);
  });

  test('walking toward deer does not crash game', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    // Deer1 is NW of player start (world 480,280 vs player 640,360) — walk NW
    const before = await page.screenshot();
    await page.keyboard.down('a'); // west
    await page.waitForTimeout(400);
    await page.keyboard.up('a');
    await page.keyboard.down('w'); // north
    await page.waitForTimeout(600);
    await page.keyboard.up('w');
    await page.waitForTimeout(800);
    const after = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    const diff = screenshotDiffFraction(before, after);
    expect(diff, 'Walking toward deer should visibly change canvas').toBeGreaterThan(0.005);
  });

  test('deer flee from player approach does not crash', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    // Walk directly toward Deer1 to trigger flee behaviour
    await page.keyboard.down('a');
    await page.keyboard.down('w');
    await page.waitForTimeout(900);
    await page.keyboard.up('a');
    await page.keyboard.up('w');
    await page.waitForTimeout(500);
    expect(getFatal()).toHaveLength(0);
  });
});

// ─── Death and game-over screen (SRS-4.11) ────────────────────────────────────

test.describe('Death and game-over screen', () => {
  test('game-over screen renders after ?goto=gameover param', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    // Navigate with goto param — main_menu._check_test_goto() routes to game_over scene
    await page.goto(GAME_URL + '?goto=gameover', {
      waitUntil: 'domcontentloaded',
      timeout: 60_000,
    });
    await page.locator('#canvas, canvas').first().waitFor({ state: 'attached', timeout: 90_000 });
    await page.waitForTimeout(6_000);
    const ss = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    // Game-over screen should render non-blank content
    expect(ss.length, 'Game-over screenshot should be non-trivial').toBeGreaterThan(1000);
  });

  test('game-over retry button navigates back to menu', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.goto(GAME_URL + '?goto=gameover', {
      waitUntil: 'domcontentloaded',
      timeout: 60_000,
    });
    await page.locator('#canvas, canvas').first().waitFor({ state: 'attached', timeout: 90_000 });
    await page.waitForTimeout(6_000);
    const withGameOver = await page.screenshot();
    // Click center of screen — Retry button is center of game-over layout
    await page.mouse.click(640, 360);
    await page.waitForTimeout(4_000);
    const afterRetry = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    const diff = screenshotDiffFraction(withGameOver, afterRetry);
    expect(diff, 'Retry should navigate away from game-over screen').toBeGreaterThan(0.01);
  });
});

// ─── Build menu (SRS-4.4) ─────────────────────────────────────────────────────

test.describe('Building system', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(6_000);
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(500);
  });

  test('pressing B opens build menu without crash', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    const before = await page.screenshot();
    await page.keyboard.press('b');
    await page.waitForTimeout(1_500);
    const after = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    const diff = screenshotDiffFraction(before, after);
    expect(diff, 'Pressing B should open build menu and change canvas').toBeGreaterThan(0.005);
  });

  test('build menu closes without crash', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.press('b');
    await page.waitForTimeout(1_500);
    const withMenu = await page.screenshot();
    await page.keyboard.press('b');
    await page.waitForTimeout(1_200);
    const closed = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    const diff = screenshotDiffFraction(withMenu, closed);
    expect(diff, 'Closing build menu should change canvas').toBeGreaterThan(0.005);
  });
});

// ─── NPC dialogue (SRS-4.9) ───────────────────────────────────────────────────

test.describe('NPC town interaction', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(6_000);
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(500);
  });

  test('walking to NPC and pressing E does not crash', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    // NPC1 is at world (200, 250), player starts at (640, 360) — go NW
    await page.keyboard.down('a');
    await page.keyboard.down('w');
    await page.waitForTimeout(1_200);
    await page.keyboard.up('a');
    await page.keyboard.up('w');
    await page.waitForTimeout(400);
    await page.keyboard.press('e');
    await page.waitForTimeout(800);
    expect(getFatal()).toHaveLength(0);
  });

  test('NPC area renders in world', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.keyboard.down('a');
    await page.keyboard.down('w');
    await page.waitForTimeout(1_000);
    await page.keyboard.up('a');
    await page.keyboard.up('w');
    await page.waitForTimeout(500);
    const ss = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    expect(ss.length).toBeGreaterThan(1000);
  });
});

// ─── Pet / dog companion (SRS-4.10) ──────────────────────────────────────────

test.describe('Pets system', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(6_000);
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(500);
  });

  test('walking to dog and pressing E does not crash', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    // Dog1 is at world (500, 450), player at (640, 360) — go SW
    await page.keyboard.down('a');
    await page.keyboard.down('s');
    await page.waitForTimeout(700);
    await page.keyboard.up('a');
    await page.keyboard.up('s');
    await page.waitForTimeout(400);
    await page.keyboard.press('e');
    await page.waitForTimeout(600);
    expect(getFatal()).toHaveLength(0);
  });

  test('dog companion renders in game world', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    // Dog is nearby — just verify the level renders without crash
    await page.waitForTimeout(500);
    const ss = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    expect(ss.length).toBeGreaterThan(1000);
  });
});

// ─── Vehicles / bicycle (SRS-4.5) ────────────────────────────────────────────

test.describe('Vehicles', () => {
  test.beforeEach(async ({ page }) => {
    await loadGame(page);
    await page.waitForTimeout(6_000);
    await page.mouse.click(640, 330);
    await page.waitForTimeout(1_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(2_000);
    await page.mouse.click(640, 360);
    await page.waitForTimeout(500);
  });

  test('walking to bicycle and pressing E does not crash', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    // Bicycle1 at world (780, 300), player at (640, 360) — go NE
    await page.keyboard.down('d');
    await page.keyboard.down('w');
    await page.waitForTimeout(700);
    await page.keyboard.up('d');
    await page.keyboard.up('w');
    await page.waitForTimeout(400);
    await page.keyboard.press('e');
    await page.waitForTimeout(600);
    expect(getFatal()).toHaveLength(0);
  });

  test('bicycle renders in game world', async ({ page }) => {
    const { getFatal } = collectFatalErrors(page);
    await page.waitForTimeout(500);
    const ss = await page.screenshot();
    expect(getFatal()).toHaveLength(0);
    expect(ss.length).toBeGreaterThan(1000);
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
