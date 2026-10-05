import { chromium } from 'playwright';
const browser = await chromium.launch({
  channel: 'msedge',
  headless: true,
  args: ['--enable-unsafe-webgpu'],
});
const page = await browser.newPage({
  viewport: { width: 1600, height: 1000 },
  deviceScaleFactor: 1,
});
page.on('pageerror', (e) => console.log('PAGE ERROR', e.message));
page.on('console', (m) => {
  if (m.type() === 'error') console.log('CONSOLE', m.text());
});
await page.goto('http://localhost:5198');
try {
  await page.waitForFunction(() => window.studio?.ready, {}, { timeout: 90000 });
  await page.evaluate(() => studio.setPlaying(false));
  await page.waitForFunction(() => !studio.busy);
  console.log(
    await page.evaluate(() => ({
      diagnostics: studio.diagnostics(),
      status: document.getElementById('compile-status').textContent,
    })),
  );
  await page.screenshot({ path: 'reports/first-studio.png' });
  console.log(
    await page.evaluate(async () => {
      const f = await studio.engine.field();
      let max = 0,
        mass = 0,
        count = 0;
      for (let i = 3; i < f.length; i += 4) {
        max = Math.max(max, f[i]);
        mass += f[i];
        if (f[i] > 0.02) count++;
      }
      return { max, mass, count };
    }),
  );
} catch (e) {
  console.log('FAIL', e.message);
  console.log(await page.locator('#compile-detail').textContent());
  await page.screenshot({ path: 'reports/first-error.png' });
}
await browser.close();
