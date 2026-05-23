// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Smoke test #1: the app responds and the home route gates anonymous users
 * through Devise.
 *
 * Test anatomy in Playwright:
 *   - `test.describe(name, fn)` groups related tests.
 *   - `test(title, fn)` defines a single test, receiving the `{ page }` fixture.
 *   - `await page.goto(...)` drives the browser.
 *   - `expect(locator).toHaveX(...)` is the auto-retrying assertion API.
 */
test.describe('Application smoke', () => {
  test('homepage redirects anonymous user to the sign-in form', async ({ page }) => {
    // baseURL is set in playwright.config.js, so '/' resolves to http://web:4000/
    const response = await page.goto('/');
    // 200 after redirect chain — the final page is the Devise login.
    expect(response?.ok()).toBeTruthy();
    await expect(page).toHaveURL(/\/login(\?.*)?$/);
  });

  test('sign-in page renders the expected form fields', async ({ page }) => {
    await page.goto('/login');

    // The login form (see app/views/devise/sessions/new.html.slim) exposes
    // input[name="user[email]"] and input[name="user[password]"].
    await expect(page.getByRole('heading', { name: /Tool Test/i })).toBeVisible();
    await expect(page.locator('input[name="user[email]"]')).toBeVisible();
    await expect(page.locator('input[name="user[password]"]')).toBeVisible();
    await expect(page.getByRole('button', { name: /Sign In/i })).toBeVisible();
  });
});
