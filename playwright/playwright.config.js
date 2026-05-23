// @ts-check
const { defineConfig, devices } = require('@playwright/test');

/**
 * Playwright config for the tool_test Rails app.
 *
 * BASE_URL is provided by the Docker overlay (docker-compose.playwright.yml)
 * and points at the Rails web container's internal hostname (http://web:4000).
 * When running outside Docker, fall back to http://localhost:4000.
 */
module.exports = defineConfig({
  testDir: './tests',
  timeout: 30_000,
  expect: { timeout: 5_000 },

  // Show progress lines + a HTML report for artifact upload in CI.
  reporter: [
    ['list'],
    ['html', { outputFolder: 'playwright-report', open: 'never' }]
  ],

  // Retry once in CI to absorb flaky waits; never retry on a dev machine.
  retries: process.env.CI ? 1 : 0,

  // Fail the build on accidental .only() left in code.
  forbidOnly: !!process.env.CI,

  use: {
    baseURL: process.env.BASE_URL || 'http://localhost:4000',
    trace: 'retain-on-failure',
    screenshot: 'only-on-failure',
    video: 'retain-on-failure',
    // Devise CSRF + cookies behave well with a real user-agent.
    ignoreHTTPSErrors: true
  },

  projects: [
    {
      name: 'chromium',
      use: { ...devices['Desktop Chrome'] }
    }
    // Add { name: 'firefox', use: { ...devices['Desktop Firefox'] } } here
    // once the team wants cross-browser coverage.
  ]
});
