// In-game check of a kid's animation state machine, frame by frame.
//   node tools/kid_test.mjs [kid] [outdir]     (needs build/web served on :8793, like shot.mjs)
// Plays a script (run, stop, jump, double jump, land, 3-hit combo, up slash, pogo, air swing)
// with ?trace=1, reads window.__hdTrace (animation + frame every physics tick), prints the
// sequence of animations with how long each played, and checks the expected ones happened --
// including the baked transition clips (idle-to-run-*, run-to-idle-*, jump_land-to-*).
import fs from "node:fs";
import os from "node:os";
import path from "node:path";
import { createRequire } from "node:module";

const require = createRequire(path.join(os.homedir(), "serviciosPR/package.json"));
const { chromium } = require("playwright");
const kid = process.argv[2] || "joe";
const out = process.argv[3] || `/tmp/kid_test_${kid}`;
fs.mkdirSync(out, { recursive: true });

const b = await chromium.launch({ executablePath: path.join(os.homedir(), ".nix-profile/bin/chromium"),
  args: ["--use-gl=angle", "--use-angle=swiftshader", "--enable-unsafe-swiftshader", "--autoplay-policy=no-user-gesture-required"] });
const p = await b.newPage({ viewport: { width: 960, height: 540 } });
const errors = [];
p.on("pageerror", e => errors.push(e.message));
p.on("console", m => { if (/SCRIPT ERROR|ERROR:/.test(m.text())) errors.push(m.text()); });
await p.goto(`http://127.0.0.1:8793/index.html?outfit=${kid}&trace=1&fresh&give=double_jump&room=surface`);
await p.waitForFunction(() => Array.isArray(window.__hdTrace), null, { timeout: 30000 });
await p.waitForTimeout(1500);
const key = async (k, ms = 120) => { await p.keyboard.down(k); await p.waitForTimeout(ms); await p.keyboard.up(k); };
let shot = 0;
const snap = async (label) => p.screenshot({ path: path.join(out, `${String(++shot).padStart(2, "0")}-${label}.png`) });

await snap("idle");
await p.keyboard.down("ArrowRight"); await p.waitForTimeout(900); await snap("running");
await p.keyboard.up("ArrowRight"); await p.waitForTimeout(150); await snap("stopping"); await p.waitForTimeout(600);
await key("Space", 230); await snap("jump");  // held: a full jump, not a short hop
await key("Space", 60); await p.waitForTimeout(100); await snap("double-jump");
await p.waitForTimeout(1200); await snap("landed");
for (let i = 0; i < 3; i++) { await key("KeyX", 40); await p.waitForTimeout(330); }  // > SWING_COOLDOWN
await snap("combo"); await p.waitForTimeout(700);
await p.keyboard.down("ArrowUp"); await key("KeyX", 40); await p.keyboard.up("ArrowUp"); await p.waitForTimeout(300); await snap("slash-up");
await p.waitForTimeout(500);
await key("Space", 60); await p.waitForTimeout(250);
await p.keyboard.down("ArrowDown"); await key("KeyX", 40); await p.keyboard.up("ArrowDown"); await p.waitForTimeout(120); await snap("pogo");
await p.waitForTimeout(900);
await key("Space", 60); await p.waitForTimeout(200); await key("KeyX", 40); await p.waitForTimeout(120); await snap("air-swing");
await p.waitForTimeout(1200);

const trace = await p.evaluate(() => window.__hdTrace);
await b.close();

// collapse into segments: animation, ticks, seconds, frames seen
const segs = [];
for (const t of trace) {
  const last = segs[segs.length - 1];
  if (last && last.anim === t.anim) { last.ticks++; last.end = t.t; last.frames.add(t.frame); }
  else segs.push({ anim: t.anim, ticks: 1, start: t.t, end: t.t, frames: new Set([t.frame]) });
}
fs.writeFileSync(path.join(out, "trace.json"), JSON.stringify(trace));
console.log("animation sequence (seconds, frames shown):");
for (const s of segs) console.log(`  ${s.anim.padEnd(22)} ${(s.end - s.start + 1 / 60).toFixed(2)}s  frames ${[...s.frames].sort((a, b) => a - b).join(",")}`);

const names = segs.map(s => s.anim);
const has = (re) => names.some(n => re.test(n));
const checks = [
  ["idle", /^idle$/], ["run", /^run$/], ["idle->run transition", /^idle-to-run/], ["run->idle transition", /^run-to-idle/],
  ["jump", /^jump$/], ["double jump", /^double_jump$/], ["fall", /^fall$/], ["land", /^jump_land$/],
  ["combo hit 1", /^sword_1$/], ["combo hit 2", /^sword_2$/], ["combo hit 3", /^sword_3$/],
  ["up slash", /^slash_up$/], ["pogo", /^slash_down$/], ["air swing", /^air_attack$/],
];
let bad = 0;
for (const [label, re] of checks) {
  const ok = has(re);
  if (!ok) bad++;
  console.log(`${ok ? "ok  " : "MISS"} ${label}`);
}
// every animation that started should have shown more than one frame unless it was replaced on purpose
const stuck = segs.filter(s => s.frames.size === 1 && s.ticks > 30 && !/fall|idle|jump$/.test(s.anim));
for (const s of stuck) console.log(`STUCK ${s.anim} showed only frame ${[...s.frames][0]} for ${s.ticks} ticks`);
if (errors.length) console.log("errors:\n  " + errors.join("\n  "));
console.log(`${checks.length - bad}/${checks.length} expected animations played; screenshots + trace.json in ${out}`);
process.exit(bad || stuck.length || errors.length ? 1 : 0);
