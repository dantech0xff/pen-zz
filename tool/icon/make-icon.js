// Draws the app icon (sword over a round shield, ballpoint style on grid paper) and
// writes assets/icon/icon.png and the transparent adaptive foreground.
// Run: node tool/icon/make-icon.js   (uses the preinstalled Playwright Chromium)
const { chromium } = require('playwright');
const path = require('path');

const html = (withPaper) => `<!doctype html><html><body style="margin:0;background:transparent">
<canvas id="c" width="1024" height="1024"></canvas><script>
const c = document.getElementById('c').getContext('2d');
const INK = '#1d3aa8';
if (${withPaper}) {
  c.fillStyle = '#fbfaf3'; c.fillRect(0, 0, 1024, 1024);
  c.strokeStyle = 'rgba(211,219,241,.5)'; c.lineWidth = 3;
  for (let y = 0; y < 1024; y += 24) { c.beginPath(); c.moveTo(0, y); c.lineTo(1024, y); c.stroke(); }
  c.strokeStyle = '#d3dbf1'; c.lineWidth = 5;
  for (let p = 0; p < 1024; p += 96) { c.beginPath(); c.moveTo(p, 0); c.lineTo(p, 1024); c.stroke(); c.beginPath(); c.moveTo(0, p); c.lineTo(1024, p); c.stroke(); }
  c.fillStyle = '#ea8f97'; c.fillRect(104, 0, 10, 1024);
}
const k = ${withPaper} ? 1 : 0.72;
c.translate(512, 512); c.scale(k, k); c.translate(-512, -512);
function ink(draw, color, w) {
  c.lineCap = 'round'; c.lineJoin = 'round';
  c.save(); c.translate(14, 20); c.strokeStyle = 'rgba(35,38,70,.18)'; c.lineWidth = w + 8; draw(); c.stroke(); c.restore();
  c.strokeStyle = color; c.lineWidth = w; draw(); c.stroke();
  c.save(); c.translate(-6, -8); c.strokeStyle = 'rgba(255,255,255,.45)'; c.lineWidth = w * 0.26; draw(); c.stroke(); c.restore();
}
// shield
c.fillStyle = 'rgba(29,58,168,.12)'; c.beginPath(); c.arc(470, 560, 250, 0, Math.PI * 2); c.fill();
ink(() => { c.beginPath(); c.arc(470, 560, 250, 0, Math.PI * 2); }, INK, 46);
ink(() => { c.beginPath(); c.arc(470, 560, 120, 0, Math.PI * 2); }, INK, 30);
// sword
const blade = () => { c.beginPath(); c.moveTo(250, 860); c.lineTo(820, 190); };
ink(blade, '#d3303c', 56);
ink(() => { c.beginPath(); c.moveTo(250, 640); c.lineTo(470, 830); }, '#d3303c', 50);
ink(() => { c.beginPath(); c.moveTo(150, 980); c.lineTo(260, 850); }, '#474b55', 60);
// highlighter swash
c.globalAlpha = 0.85; c.fillStyle = '#ffe14a';
c.beginPath(); c.ellipse(700, 820, 150, 34, -0.12, 0, Math.PI * 2); c.fill();
</script></body></html>`;

(async () => {
  const out = path.join(__dirname, '..', '..', 'assets', 'icon');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
  for (const [file, paper] of [['icon.png', true], ['icon-foreground.png', false]]) {
    await page.setContent(html(paper));
    await page.locator('#c').screenshot({ path: path.join(out, file), omitBackground: !paper });
  }
  await browser.close();
})();
