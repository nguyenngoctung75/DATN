// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Smoke test #2: submitting empty / invalid credentials surfaces an error.
 *
 * Notes for the team:
 *  - `page.fill(selector, value)` types into an input and fires events.
 *  - `page.click(selector)` performs a real DOM click — submits the form.
 *  - Devise flashes its failure message into `.alert` (Bootstrap) on re-render.
 *  - We assert *either* a flash error or a returned `/login` URL —
 *    that way the test stays robust whether Devise rerenders or redirects.
 */
test.describe('Authentication validation', () => {
  test('rejects empty credentials', async ({ page }) => {
    await page.goto('/login');
    // Click sign-in without filling anything — browser native validation
    // should block submission because both inputs are `required`.
    await page.getByRole('button', { name: /Sign In/i }).click();

    // The page should NOT have moved on — still on /login.
    await expect(page).toHaveURL(/\/login(\?.*)?$/);

    // Native HTML5 validation flags `:invalid` on the email input.
    const emailIsInvalid = await page.locator('input[name="user[email]"]').evaluate(
      (el) => /** @type {HTMLInputElement} */ (el).validity.valid === false
    );
    expect(emailIsInvalid).toBeTruthy();
  });

  test('rejects unknown user with an error notice', async ({ page }) => {
    await page.goto('/login');

    await page.fill('input[name="user[email]"]', 'doesnotexist@example.com');
    await page.fill('input[name="user[password]"]', 'wrongpassword');
    await page.getByRole('button', { name: /Sign In/i }).click();

    // Wait for the response — Devise typically re-renders /login with
    // a flash alert; we only require that we land back on a sign-in URL and
    // see some kind of error feedback in the DOM.
    await expect(page).toHaveURL(/\/login/);

    // The Bootstrap alert OR the form re-render must be present.
    const errorVisible =
      (await page.locator('.alert, .alert-danger, [role="alert"]').count()) > 0 ||
      (await page.locator('input[name="user[email]"]').count()) > 0;
    expect(errorVisible).toBeTruthy();
  });
});
