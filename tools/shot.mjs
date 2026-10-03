// Screenshots the web build. Usage:
//   node tools/shot.mjs "<query>" out.png [waitMs] '[{"down":"ArrowRight","wait":600},{"up":"ArrowRight"},{"key":"z"}]'
// Needs a static server serving build/web (BASE, default http://127.0.0.1:8793)
// and playwright (run from a folder that has it, e.g. copy this to /tmp).
import { chromium } from 'playwright';
const [, , query = '', out = 'shot.png', wait = '5000', steps = '[]'] = process.argv;
const b = await chromium.launch({ executablePath: process.env.CHROMIUM || '/home/sami/.nix-profile/bin/chromium',
  args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader', '--autoplay-policy=no-user-gesture-required'] });
const p = await b.newPage({ viewport: { width: +(process.env.W || 960), height: +(process.env.H || 540) }, deviceScaleFactor: 1 });
p.on('console', m => { if (/error|ERROR|SCRIPT/.test(m.text())) console.log('console:', m.text()); });
p.on('pageerror', e => console.log('pageerror:', e.message));
await p.goto((process.env.BASE || 'http://127.0.0.1:8793') + '/index.html' + query);
await p.waitForTimeout(Number(wait));
let n = 0;
for (const s of JSON.parse(steps)) {
  if (s.key) await p.keyboard.press(s.key);
  if (s.down) await p.keyboard.down(s.down);
  if (s.up) await p.keyboard.up(s.up);
  if (s.click) await p.mouse.click(s.click[0], s.click[1]);
  await p.waitForTimeout(s.wait ?? 300);
  if (s.shot) await p.screenshot({ path: out.replace('.png', `-${++n}.png`) });
}
await p.screenshot({ path: out });
await b.close();
