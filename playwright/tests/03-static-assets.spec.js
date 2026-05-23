// @ts-check
const { test, expect } = require('@playwright/test');

/**
 * Smoke test #3: the sign-in page ships its CSS/JS bundle without server-side
 * errors. We deliberately *exclude* 4xx responses because the login page
 * legitimately probes auth-gated XHR endpoints (e.g. /notifications/unread_count)
 * that return 401 when the user is anonymous.
 *
 * Failure modes this guards against:
 *  - 5xx on static assets (Sprockets/propshaft/sass blew up)
 *  - 404 on static assets (asset pipeline misconfigured)
 *  - 500 on the page itself (controller error)
 */
test.describe('Static assets', () => {
  test('no server errors or missing assets on the login page', async ({ page }) => {
    /** @type {{url: string, status: number}[]} */
    const failed = [];

    // `page.on('response', ...)` is the standard hook to observe every HTTP
    // response the browser receives — assets, XHRs, navigation, etc.
    page.on('response', (res) => {
      const status = res.status();
      const url = res.url();
      const type = res.request().resourceType(); // 'document'|'stylesheet'|'script'|'image'|'font'|'xhr'|'fetch'|...

      const isAsset = ['stylesheet', 'script', 'image', 'font'].includes(type);
      const isDocument = type === 'document';

      // Any 5xx anywhere is a hard failure.
      if (status >= 500) {
        failed.push({ url, status });
        return;
      }
      // 404 on a static asset → asset pipeline regression.
      if (isAsset && status === 404) {
        failed.push({ url, status });
        return;
      }
      // 4xx on the document navigation itself → page is broken.
      if (isDocument && status >= 400) {
        failed.push({ url, status });
      }
    });

    await page.goto('/login', { waitUntil: 'networkidle' });

    expect(failed, `Bad responses: ${JSON.stringify(failed, null, 2)}`).toEqual([]);
  });
});
