// Génère toutes les icônes de l'app (web, Android, iOS, macOS, Windows) à
// partir du logo MoniFlex.
// Usage (depuis la racine du projet) : node tool/icon/render_icons.mjs
// Nécessite Google Chrome (rendu SVG → PNG via le mode headless).
import { spawn } from 'node:child_process';
import { readFileSync, writeFileSync, mkdtempSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { deflateSync, inflateSync, crc32 } from 'node:zlib';

const logo = readFileSync('tool/icon/logo.svg', 'utf8');
const inner = logo.replace(/^[\s\S]*?<svg[^>]*>/, '').replace(/<\/svg>\s*$/, '');

// Variantes :
// - rounded : coins arrondis, fond transparent (web « any », Android, Windows).
// - square  : carré plein bord à bord, sans transparence (iOS arrondit
//   lui-même et refuse la transparence ; Android « maskable » découpe un
//   cercle, le symbole reste dans la zone sûre de 80 %).
// - mac     : carré arrondi avec marge, comme les icônes macOS.
const variants = {
  rounded: logo,
  square: logo.replace(/<rect[^>]*\/>/, '<rect width="32" height="32" fill="#00897B"/>'),
  mac: `<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 32 32"><g transform="translate(3.2 3.2) scale(0.8)">${inner}</g></svg>`,
};

const ios = 'ios/Runner/Assets.xcassets/AppIcon.appiconset';
const mac = 'macos/Runner/Assets.xcassets/AppIcon.appiconset';
const android = 'android/app/src/main/res';

const outputs = [
  ['web/favicon.png', 64, 'rounded'],
  ['web/icons/Icon-192.png', 192, 'rounded'],
  ['web/icons/Icon-512.png', 512, 'rounded'],
  ['web/icons/Icon-maskable-192.png', 192, 'square'],
  ['web/icons/Icon-maskable-512.png', 512, 'square'],
  ['web/icons/apple-touch-icon.png', 180, 'square'],
  [`${android}/mipmap-mdpi/ic_launcher.png`, 48, 'rounded'],
  [`${android}/mipmap-hdpi/ic_launcher.png`, 72, 'rounded'],
  [`${android}/mipmap-xhdpi/ic_launcher.png`, 96, 'rounded'],
  [`${android}/mipmap-xxhdpi/ic_launcher.png`, 144, 'rounded'],
  [`${android}/mipmap-xxxhdpi/ic_launcher.png`, 192, 'rounded'],
  // iOS : toutes les tailles déclarées dans Contents.json.
  ...JSON.parse(readFileSync(`${ios}/Contents.json`, 'utf8')).images.map((img) => [
    `${ios}/${img.filename}`,
    Math.round(parseFloat(img.size) * parseInt(img.scale)),
    'square',
  ]),
  ...[16, 32, 64, 128, 256, 512, 1024].map((s) => [`${mac}/app_icon_${s}.png`, s, 'mac']),
];
const icoSizes = [16, 24, 32, 48, 64, 128, 256];

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
async function render(size, variant) {
  await send('Emulation.setDeviceMetricsOverride', { width: size, height: size, deviceScaleFactor: 1, mobile: false });
  const html = `<html><body style="margin:0;background:transparent">${
    variants[variant].replace('<svg ', `<svg width="${size}" height="${size}" `)}</body></html>`;
  await send('Page.navigate', { url: 'data:text/html;base64,' + Buffer.from(html).toString('base64') });
  await sleep(300);
  const { data } = await send('Page.captureScreenshot', { format: 'png' });
  return Buffer.from(data, 'base64');
}

for (const [path, size, variant] of outputs) {
  const png = await render(size, variant);
  writeFileSync(path, variant === 'square' ? stripAlpha(png) : png);
  console.log(`${path} (${size}px)`);
}

// Windows : un .ico contenant chaque taille au format PNG.
const pngs = [];
for (const s of icoSizes) pngs.push(await render(s, 'rounded'));
writeFileSync('windows/runner/resources/app_icon.ico', ico(icoSizes, pngs));
console.log(`windows/runner/resources/app_icon.ico (${icoSizes.join(', ')}px)`);

ws.close();
chrome.kill();
process.exit(0);

/// PNG RGBA 8 bits → PNG RGB (sans canal alpha, exigé par l'App Store).
function stripAlpha(buf) {
  let pos = 8, width, height, colorType;
  const idat = [];
  while (pos < buf.length) {
    const len = buf.readUInt32BE(pos);
    const type = buf.toString('ascii', pos + 4, pos + 8);
    const data = buf.subarray(pos + 8, pos + 8 + len);
    if (type === 'IHDR') {
      width = data.readUInt32BE(0);
      height = data.readUInt32BE(4);
      colorType = data[9];
    } else if (type === 'IDAT') idat.push(data);
    pos += 12 + len;
  }
  const bpp = colorType === 6 ? 4 : 3;
  if (bpp === 3) return buf;
  const raw = inflateSync(Buffer.concat(idat));
  const stride = width * bpp;
  const prev = Buffer.alloc(stride);
  const out = Buffer.alloc(height * (width * 3 + 1));
  for (let y = 0; y < height; y++) {
    const filter = raw[y * (stride + 1)];
    const line = Buffer.from(raw.subarray(y * (stride + 1) + 1, (y + 1) * (stride + 1)));
    for (let x = 0; x < stride; x++) {
      const a = x >= bpp ? line[x - bpp] : 0;
      const b = prev[x];
      const c = x >= bpp ? prev[x - bpp] : 0;
      let p = 0;
      if (filter === 1) p = a;
      else if (filter === 2) p = b;
      else if (filter === 3) p = (a + b) >> 1;
      else if (filter === 4) {
        const pa = Math.abs(b - c), pb = Math.abs(a - c), pc = Math.abs(a + b - 2 * c);
        p = pa <= pb && pa <= pc ? a : pb <= pc ? b : c;
      }
      line[x] = (line[x] + p) & 0xff;
    }
    line.copy(prev);
    const o = y * (width * 3 + 1);
    out[o] = 0;
    for (let x = 0; x < width; x++) {
      out[o + 1 + x * 3] = line[x * 4];
      out[o + 2 + x * 3] = line[x * 4 + 1];
      out[o + 3 + x * 3] = line[x * 4 + 2];
    }
  }
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(width, 0);
  ihdr.writeUInt32BE(height, 4);
  ihdr[8] = 8;
  ihdr[9] = 2; // RGB
  return Buffer.concat([
    buf.subarray(0, 8),
    chunk('IHDR', ihdr),
    chunk('IDAT', deflateSync(out)),
    chunk('IEND', Buffer.alloc(0)),
  ]);
}

function chunk(type, data) {
  const head = Buffer.alloc(8);
  head.writeUInt32BE(data.length, 0);
  head.write(type, 4, 'ascii');
  const crc = Buffer.alloc(4);
  crc.writeUInt32BE(crc32(Buffer.concat([head.subarray(4), data])) >>> 0, 0);
  return Buffer.concat([head, data, crc]);
}

function ico(sizes, images) {
  const header = Buffer.alloc(6 + 16 * sizes.length);
  header.writeUInt16LE(0, 0);
  header.writeUInt16LE(1, 2); // type : icône
  header.writeUInt16LE(sizes.length, 4);
  let offset = header.length;
  sizes.forEach((s, i) => {
    const e = 6 + 16 * i;
    header[e] = s >= 256 ? 0 : s;
    header[e + 1] = s >= 256 ? 0 : s;
    header.writeUInt16LE(1, e + 4); // plans
    header.writeUInt16LE(32, e + 6); // bits par pixel
    header.writeUInt32LE(images[i].length, e + 8);
    header.writeUInt32LE(offset, e + 12);
    offset += images[i].length;
  });
  return Buffer.concat([header, ...images]);
}
