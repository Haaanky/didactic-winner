// @ts-check
const { defineConfig, devices } = require('@playwright/test');

/**
 * Playwright configuration for Dudes in Alaska web export tests.
 * By default targets the GitHub Pages deployment.
 * Set GAME_URL env var to override (e.g. for local testing: GAME_URL=http://localhost:8080).
 *
 * Run with:
 *   PLAYWRIGHT_BROWSERS_PATH=~/.cache/ms-playwright npx playwright test
 */

const GAME_URL = (process.env.GAME_URL || 'https://haaanky.github.io/didactic-winner').replace(/\/$/, '') + '/';

const isLocalURL = GAME_URL.startsWith('http://localhost') || GAME_URL.startsWith('http://127.');
const PROXY_SERVER = !isLocalURL ? (process.env.https_proxy || process.env.HTTPS_PROXY || '') : '';

module.exports = defineConfig({
  testDir: './tests/playwright',
  // Generous timeout: Godot WASM binary can be several MB to download + JIT
  timeout: 120_000,
  retries: 1,
  reporter: [['list'], ['html', { open: 'never' }]],
  use: {
    // Absolute URL so page.goto(GAME_URL) works unambiguously
    baseURL: GAME_URL,
    headless: true,
    viewport: { width: 1280, height: 720 },
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    ...(PROXY_SERVER ? { proxy: { server: PROXY_SERVER } } : {}),
  },
  projects: [
    {
      name: 'chromium',
      use: {
        ...devices['Desktop Chrome'],
        launchOptions: {
          args: ['--enable-features=SharedArrayBuffer'],
        },
      },
    },
  ],
});

// Export GAME_URL so tests can import it
module.exports.GAME_URL = GAME_URL;
