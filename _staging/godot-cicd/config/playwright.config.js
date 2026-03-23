// @ts-check
const { defineConfig, devices } = require('@playwright/test');

/**
 * Playwright configuration template for Godot 4 web export tests.
 * Copy this file to your project root and adjust GAME_URL and testDir.
 *
 * Set GAME_URL env var to override the target URL:
 *   GAME_URL=http://localhost:8080 npx playwright test
 */

// CONFIGURE: replace with your GitHub Pages URL
const DEFAULT_GAME_URL = process.env.GAME_URL || 'https://your-username.github.io/your-repo/';
const GAME_URL = DEFAULT_GAME_URL.replace(/\/$/, '') + '/';

const isLocalURL = GAME_URL.startsWith('http://localhost') || GAME_URL.startsWith('http://127.');
const PROXY_SERVER = !isLocalURL ? (process.env.https_proxy || process.env.HTTPS_PROXY || '') : '';

const webServer = isLocalURL
  ? {
      command: 'npx serve build/web -p 8080 --cors',
      url: 'http://localhost:8080',
      reuseExistingServer: true,
      timeout: 30_000,
    }
  : undefined;

module.exports = defineConfig({
  // CONFIGURE: path to your test files
  testDir: './tests/playwright',
  timeout: 120_000,
  retries: 1,
  reporter: [['list'], ['html', { open: 'never' }]],
  ...(webServer ? { webServer } : {}),
  use: {
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

module.exports.GAME_URL = GAME_URL;
