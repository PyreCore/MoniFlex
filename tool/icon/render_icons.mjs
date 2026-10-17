// Génère toutes les icônes de l'app à partir du logo MoniFlex.
// Usage (depuis la racine du projet) : node tool/icon/render_icons.mjs
// Nécessite Google Chrome (rendu SVG → PNG via le mode headless).
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';

const logo = readFileSync('tool/icon/logo.svg', 'utf8');

// rounded : coins arrondis et fond transparent (icône « any », favicon).
// Sinon carré plein bord à bord (iOS arrondit lui-même ; Android « maskable »
// découpe un cercle : le symbole reste dans la zone sûre de 80 %).
const svg = (rounded) => rounded
  ? logo
  : logo.replace(/<rect[^>]*\/>/, '<rect width="32" height="32" fill="#00897B"/>');

const outputs = [
  ['web/favicon.png', 64, true],
  ['web/icons/Icon-192.png', 192, true],
  ['web/icons/Icon-512.png', 512, true],
  ['web/icons/Icon-maskable-192.png', 192, false],
  ['web/icons/Icon-maskable-512.png', 512, false],
  ['web/icons/apple-touch-icon.png', 180, false],
  ['android/app/src/main/res/mipmap-mdpi/ic_launcher.png', 48, true],
  ['android/app/src/main/res/mipmap-hdpi/ic_launcher.png', 72, true],
  ['android/app/src/main/res/mipmap-xhdpi/ic_launcher.png', 96, true],
  ['android/app/src/main/res/mipmap-xxhdpi/ic_launcher.png', 144, true],
  ['android/app/src/main/res/mipmap-xxxhdpi/ic_launcher.png', 192, true],
];

const port = 9334;
const chrome = spawn(
  process.env.CHROME || 'C:/Program Files/Google/Chrome/Application/chrome.exe',
  ['--headless=new', `--remote-debugging-port=${port}`,
   `--user-data-dir=${mkdtempSync(join(tmpdir(), 'icons-'))}`, 'about:blank'],
);
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
let target;
for (let i = 0; i < 50 && !target; i++) {
  await sleep(200);
  try {
    target = (await (await fetch(`http://127.0.0.1:${port}/json`)).json())
      .find((t) => t.type === 'page');
  } catch {}
}
const ws = new WebSocket(target.webSocketDebuggerUrl);
await new Promise((r) => ws.addEventListener('open', r));
let id = 0;
const pending = new Map();
ws.addEventListener('message', (e) => {
  const m = JSON.parse(e.data);
  if (m.id && pending.has(m.id)) { pending.get(m.id)(m.result); pending.delete(m.id); }
});
const send = (method, params = {}) => new Promise((r) => {
  pending.set(++id, r);
  ws.send(JSON.stringify({ id, method, params }));
});

await send('Emulation.setDefaultBackgroundColorOverride', { color: { r: 0, g: 0, b: 0, a: 0 } });
for (const [path, size, rounded] of outputs) {
  await send('Emulation.setDeviceMetricsOverride', { width: size, height: size, deviceScaleFactor: 1, mobile: false });
  const html = `<html><body style="margin:0;background:transparent">${
    svg(rounded).replace('<svg ', `<svg width="${size}" height="${size}" `)}</body></html>`;
  await send('Page.navigate', { url: 'data:text/html;base64,' + Buffer.from(html).toString('base64') });
  await sleep(300);
  const { data } = await send('Page.captureScreenshot', { format: 'png' });
  writeFileSync(path, Buffer.from(data, 'base64'));
  console.log(`${path} (${size}px)`);
}
ws.close();
chrome.kill();
process.exit(0);
