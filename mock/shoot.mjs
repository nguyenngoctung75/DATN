// =============================================================
// mock/shoot.mjs — Chụp ảnh mockup UI cho ĐATN (§4.3.3)
//
// Dùng Playwright + Chrome hệ thống (channel: 'chrome', không tải chromium).
//   npm i -D playwright            (hoặc: npx playwright@latest)
//   node mock/shoot.mjs
//
// Ảnh ghi đè trực tiếp vào datn/figures/screenshots/.
// =============================================================

import { chromium } from 'playwright';
import { fileURLToPath, pathToFileURL } from 'url';
import path from 'path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const MOCK_DIR = __dirname;
const OUT_DIR = path.resolve(__dirname, '../datn/figures/screenshots');

// mode: 'page' = full-page; 'clip' = chụp riêng 1 element theo selector
const targets = [
  { out: 'dang-nhap.png',             html: 'login.html',             mode: 'page' },
  { out: 'dashboard.png',             html: 'user-dashboard.html',    mode: 'page' },
  { out: 'danh-sach-project.png',     html: 'projects.html',          mode: 'page' },
  { out: 'dashboard-project.png',     html: 'dashboard.html',         mode: 'page' },
  { out: 'cay-task.png',              html: 'task-tree.html',         mode: 'page' },
  { out: 'spreadsheet-test-case.png', html: 'test-cases.html',        mode: 'page' },
  { out: 'modal-lich-su-cell.png',    html: 'modal-cell-history.html', mode: 'clip', selector: '#modal' },
  { out: 'bug-tracking.png',          html: 'bugs.html',              mode: 'page' },
  { out: 'import-gsheet-progress.png', html: 'modal-import.html',      mode: 'clip', selector: '#modal' },
  { out: 'lich-su-daily-import.png',  html: 'daily-import.html',      mode: 'page' },
  { out: 'header-notification.png',   html: 'notifications.html',     mode: 'clip', selector: '#notif-dropdown' },
  { out: 'toast-cicd-success.png',    html: 'notifications.html',     mode: 'clip', selector: '#ci-toasts' },
  { out: 'ci-cd-history.png',         html: 'ci-history.html',        mode: 'page' },
  { out: 'admin-activity-log.png',    html: 'activity-log.html',      mode: 'page' },
];

// Ẩn banner mock-crumb + reset offset header để ảnh sạch
const CLEANUP_CSS = `
  .mock-crumb { display: none !important; }
  .has-crumb { padding-top: 0 !important; }
  .app-header { margin-top: 0 !important; }
  * { scrollbar-width: none !important; }
  ::-webkit-scrollbar { display: none !important; }
`;

const browser = await chromium.launch({ channel: 'chrome' });
const ctx = await browser.newContext({
  viewport: { width: 1440, height: 900 },
  deviceScaleFactor: 2,
});
const page = await ctx.newPage();

let ok = 0;
for (const t of targets) {
  const url = pathToFileURL(path.join(MOCK_DIR, t.html)).href;
  await page.goto(url, { waitUntil: 'networkidle' });
  await page.addStyleTag({ content: CLEANUP_CSS });
  await page.evaluate(() => document.fonts && document.fonts.ready);
  await page.waitForTimeout(350); // chờ icon webfont vẽ xong
  const outPath = path.join(OUT_DIR, t.out);

  if (t.mode === 'clip') {
    const el = page.locator(t.selector).first();
    await el.screenshot({ path: outPath });
  } else {
    await page.screenshot({ path: outPath, fullPage: true });
  }
  console.log(`✓ ${t.out}  ←  ${t.html}${t.selector ? ' (' + t.selector + ')' : ''}`);
  ok++;
}

await browser.close();
console.log(`\nXong: ${ok}/${targets.length} ảnh → ${OUT_DIR}`);
