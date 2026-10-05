import { chromium } from 'playwright';
import assert from 'node:assert/strict';
import { mkdir, writeFile, readFile } from 'node:fs/promises';
await mkdir('reports', { recursive: true });
const report = { checks: [], errors: [], url: process.env.STUDIO_URL || 'http://localhost:5198' },
  check = (name, data = {}) => {
    report.checks.push({ name, ...data });
    console.log('PASS', name, JSON.stringify(data));
  };
const browser = await chromium.launch({
  channel: 'msedge',
  headless: true,
  args: ['--enable-unsafe-webgpu'],
});
const page = await browser.newPage({
  viewport: { width: 1600, height: 1000 },
  deviceScaleFactor: 1,
});
page.on('pageerror', (e) => report.errors.push(e.message));
page.on('console', (m) => {
  if (m.type() === 'error' && !m.text().includes('connect the')) report.errors.push(m.text());
});
page.on('response', (r) => {
  if (r.status() >= 400) report.errors.push(`${r.status()} ${r.url()}`);
});
async function idle() {
  await page.waitForFunction(() => studio.ready && !studio.busy, {}, { timeout: 90000 });
}
async function seek(frame) {
  await idle();
  await page.evaluate((frame) => studio.seek(frame), frame);
  await page.waitForFunction((frame) => studio.engine.frame === frame && !studio.busy, frame, {
    timeout: 60000,
  });
}
async function fieldHash() {
  return page.evaluate(async () =>
    Array.from(
      new Uint8Array(await crypto.subtle.digest('SHA-256', (await studio.engine.field()).buffer)),
    ).join(','),
  );
}
async function pixelStats() {
  return page.evaluate(async () => {
    const p = await studio.engine.pixelsRGBA();
    let lit = 0,
      max = 0,
      sum = 0;
    for (let i = 0; i < p.length; i += 4) {
      max = Math.max(max, p[i]);
      sum += p[i];
      if (p[i] > 24) lit++;
    }
    return { lit, max, sum };
  });
}
try {
  await page.goto(report.url);
  await page.waitForFunction(() => studio.ready, {}, { timeout: 90000 });
  await page.evaluate(() => studio.setPlaying(false));
  await idle();
  await seek(90);
  assert.equal((await page.evaluate(() => studio.diagnostics())).kernels.length, 8);
  check('All eight generated CUDA kernels execute on WebGPU');
  const field = await page.evaluate(async () => {
    const f = await studio.engine.field();
    let mass = 0,
      nonzero = 0,
      maxVelocity = 0;
    for (let i = 0; i < f.length; i += 4) {
      if (![f[i], f[i + 1], f[i + 2], f[i + 3]].every(Number.isFinite))
        throw Error('Nonfinite state');
      mass += f[i + 3];
      if (f[i + 3] > 0.02) nonzero++;
      maxVelocity = Math.max(maxVelocity, Math.abs(f[i]), Math.abs(f[i + 1]), Math.abs(f[i + 2]));
    }
    return { mass, nonzero, maxVelocity };
  });
  assert.ok(field.mass > 100 && field.nonzero > 1000 && field.maxVelocity > 1);
  check('Real smoke density and velocity occupy the 64³ field', field);
  const pixels = await pixelStats();
  assert.ok(pixels.lit > 3000 && pixels.max > 100);
  check('CUDA volume renderer produces a lit visible plume', pixels);
  await page.screenshot({ path: 'reports/studio.png' });
  const hash90 = await fieldHash();
  await seek(50);
  const hash50 = await fieldHash();
  assert.notEqual(hash90, hash50);
  await seek(90);
  assert.equal(await fieldHash(), hash90);
  check('Timeline rewind and replay recover bit-identical GPU state');
  const projection = await page.evaluate(async () => {
    const e = studio.engine,
      r = e.runtime,
      n = e.n,
      count = n ** 3,
      field = r.createBuffer(count * 16),
      out = r.createBuffer(count * 16),
      div = r.createBuffer(count * 4),
      p = r.createBuffer(count * 4),
      q = r.createBuffer(count * 4);
    const fixture = new Float32Array(count * 4);
    for (let z = 0; z < n; z++)
      for (let y = 0; y < n; y++)
        for (let x = 0; x < n; x++) {
          const i = ((z * n + y) * n + x) * 4;
          fixture[i] = Math.sin(x * 0.25);
          fixture[i + 1] = Math.sin(y * 0.21);
          fixture[i + 2] = Math.sin(z * 0.23);
        }
    r.write(field, fixture);
    let b = r.batch();
    e.dispatch(b, 'divergence', { field, div, pressure: p }, { n });
    b.submit();
    const before = await r.read(div, Float32Array);
    b = r.batch();
    let a = p,
      c = q;
    for (let j = 0; j < 40; j++) {
      e.dispatch(b, 'pressure_solve', { pressure: a, div, output: c }, { n });
      [a, c] = [c, a];
    }
    e.dispatch(b, 'project', { field, pressure: a, output: out }, { n });
    e.dispatch(b, 'divergence', { field: out, div, pressure: c }, { n });
    b.submit();
    const after = await r.read(div, Float32Array);
    let pre = 0,
      post = 0;
    for (let z = 3; z < n - 3; z++)
      for (let y = 3; y < n - 3; y++)
        for (let x = 3; x < n - 3; x++) {
          const i = (z * n + y) * n + x;
          pre += before[i] ** 2;
          post += after[i] ** 2;
        }
    for (const buffer of [field, out, div, p, q]) r.destroyBuffer(buffer);
    return { before: Math.sqrt(pre), after: Math.sqrt(post), ratio: Math.sqrt(post / pre) };
  });
  assert.ok(projection.ratio < 0.8);
  check('Pressure projection reduces divergence on an independent velocity fixture', projection);
  await page.locator('[data-tab="cuda"]').click();
  assert.ok(
    (await page.locator('#source-code').textContent()).includes('__global__ void pressure_solve'),
  );
  await page.screenshot({ path: 'reports/live-cuda.png' });
  await page.locator('[data-tab="wgsl"]').click();
  assert.ok((await page.locator('#source-code').textContent()).includes('@compute'));
  check('CUDA and WGSL tabs display real source and installed artifacts');
  await page.locator('[data-tab="graph"]').click();
  await page.locator('.node[data-id="volume"] .node-head').click();
  const oldRevision = await page.evaluate(() => studio.engine.revision),
    oldPixel = (await pixelStats()).sum;
  await page.locator('#range-absorption').fill('0.5');
  await page.locator('#range-absorption').dispatchEvent('input');
  await page.waitForFunction((r) => studio.engine.revision > r && !studio.busy, oldRevision, {
    timeout: 60000,
  });
  assert.match(
    await page.evaluate(() => studio.activeSource),
    /p_volume_absorption[^\n]+0.500000f/,
  );
  assert.notEqual((await pixelStats()).sum, oldPixel);
  assert.equal(await fieldHash(), hash90);
  check('A real inspector edit regenerates CUDA and changes pixels without resetting smoke');
  await page.locator('#undo').click();
  await page.waitForFunction(
    () => studio.activeSource.includes('return 2.400000f;') && !studio.busy,
  );
  check('Undo restores the previous shader parameters');
  await page.locator('.node[data-id="noise"] .node-head').click();
  await page.locator('[aria-label="Keyframe Strength"]').click();
  await idle();
  assert.equal(
    await page.evaluate(
      () => studio.graph.nodes.find((n) => n.id === 'noise').keys.strength.length,
    ),
    1,
  );
  assert.ok(await page.locator('.diamond[data-node="noise"]').count());
  check('Property diamonds create compiled animation curves and timeline keys');
  await page
    .locator('.socket[data-node="volume"][data-input="simulation"]')
    .click({ button: 'right' });
  await page.waitForFunction(
    () => document.getElementById('compile-status').textContent === 'Could not apply changes',
  );
  assert.equal(await page.evaluate(() => studio.ready), true);
  const retained = await page.evaluate(() => studio.activeSource);
  assert.ok(retained.includes('mist_render'));
  await page.locator('.socket[data-node="simulation"][data-output="simulation"]').click();
  await page.locator('.socket[data-node="volume"][data-input="simulation"]').click();
  await page.waitForFunction(() =>
    document.getElementById('compile-status').textContent.includes('Live'),
  );
  check(
    'Disconnecting a required socket reports an error and preserves the last shader; rewiring restores it',
  );
  await page.locator('#add-node').click();
  await page.locator('#node-library [data-type="blend"]').click();
  assert.equal(await page.locator('.node').count(), 9);
  await page.locator('#delete-node').click();
  assert.equal(await page.locator('.node').count(), 8);
  check('Node library adds editable nodes and deletion updates the graph');
  const [download] = await Promise.all([
    page.waitForEvent('download'),
    page.locator('#save-project').click(),
  ]);
  await download.saveAs('reports/test-project.json');
  const saved = JSON.parse(await readFile('reports/test-project.json', 'utf8'));
  assert.equal(saved.nodes.length, 8);
  await page.locator('[data-preset="wispy"]').click();
  await idle();
  await page.locator('#project-file').setInputFiles('reports/test-project.json');
  await page.waitForFunction(() => studio.graph.name === 'Rising Mist' && !studio.busy);
  assert.deepEqual(await page.evaluate(() => JSON.parse(JSON.stringify(studio.graph))), saved);
  check('Project save/open round-trips graph, layout, values and keyframes');
  await page.locator('#quality').selectOption('96');
  await page.waitForFunction(() => studio.engine.n === 96 && !studio.busy, {}, { timeout: 60000 });
  assert.ok((await pixelStats()).lit > 2000);
  check('High detail 96³ simulation replays and renders');
  await page.locator('#quality').selectOption('128');
  await page.waitForFunction(() => studio.engine.n === 128 && !studio.busy, {}, { timeout: 60000 });
  assert.ok((await pixelStats()).lit > 2000);
  check('Ultra 128³ simulation replays and renders');
  await page.locator('#quality').selectOption('64');
  await page.waitForFunction(() => studio.engine.n === 64 && !studio.busy, {}, { timeout: 60000 });
  await page.evaluate(() => studio.setPlaying(true));
  const start = await page.evaluate(() => studio.engine.frame);
  await page.waitForFunction((start) => studio.engine.frame >= start + 20, start, {
    timeout: 10000,
  });
  await page.evaluate(() => studio.setPlaying(false));
  await idle();
  check('Playback advances the actual simulation');
  report.fps = await page.locator('#fps').textContent();
  await page.setViewportSize({ width: 1280, height: 800 });
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  await page.screenshot({ path: 'reports/studio-1280.png' });
  check('Desktop panels fit 1280 × 800');
  await page.setViewportSize({ width: 390, height: 844 });
  assert.ok(await page.evaluate(() => document.documentElement.scrollWidth <= innerWidth));
  await page.screenshot({ path: 'reports/studio-mobile.png', fullPage: true });
  check('Narrow layout remains usable without horizontal overflow');
  assert.deepEqual(report.errors, []);
  check('No browser, network or GPU validation errors');
  report.diagnostics = await page.evaluate(() => studio.diagnostics());
} catch (e) {
  report.failure = e.stack;
  console.error(e);
  await page.screenshot({ path: 'reports/test-failure.png', fullPage: true });
  process.exitCode = 1;
} finally {
  await writeFile('reports/browser-validation.json', JSON.stringify(report, null, 2));
  await browser.close();
}
