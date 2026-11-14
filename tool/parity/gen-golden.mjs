// Generates test/fixtures/gear_golden.json from the original web game's gear math.
// The functions below are copied unchanged from the "Bút Chiến" HTML version so the
// Dart port can be checked against the source of truth. Run: node tool/parity/gen-golden.mjs
import { writeFileSync } from 'node:fs';

const DEG = Math.PI / 180;
const SH_RAISED = { x: 24, y: -58 }, SH_LOW = { x: 6, y: -40 };
const S_R = 5;
const TH_WIND = -50 * DEG, TH_END = 110 * DEG, SWING = TH_END - TH_WIND;
const clamp = (v, a, b) => v < a ? a : v > b ? b : v;
const HAND0 = { x: 4 + 26 * Math.cos(-10 * DEG), y: -72 + 26 * Math.sin(-10 * DEG) };
const LEN = { thigh: 26, shin: 26, upper: 22, fore: 21, torso: 40, head: 11 };
function ik(R, T, a, b, bend) {
  let dx = T[0] - R[0], dy = T[1] - R[1], d = Math.hypot(dx, dy) || 0.001;
  const max = a + b - 0.5, min = Math.abs(a - b) + 0.5;
  if (d > max) { dx *= max / d; dy *= max / d; d = max; } else if (d < min) { dx *= min / d; dy *= min / d; d = min; }
  const base = Math.atan2(dy, dx), A = Math.acos(clamp((a * a + d * d - b * b) / (2 * a * d), -1, 1)), j = base + bend * A;
  return { J: [R[0] + Math.cos(j) * a, R[1] + Math.sin(j) * a], E: [R[0] + dx, R[1] + dy] };
}
const ARC_R = 36, arcAngle = th => -105 * DEG + 0.8125 * (th - TH_WIND);
const REST = { hip: [0, -46], lean: 0.08, head: 0, fF: [15, 0], fB: [-13, 0], hW: [HAND0.x, HAND0.y], hS: [SH_LOW.x, SH_LOW.y], arc: 0, th: 0, dy: 0, rot: 0, sc: 1 };
const poseOf = d => { const o = {}; for (const k in REST) o[k] = d[k] !== undefined ? d[k] : REST[k]; return o; };
function mixP(p, q, u) {
  const o = {};
  for (const k in p) { const a = p[k], b = q[k]; o[k] = Array.isArray(a) ? [a[0] + (b[0] - a[0]) * u, a[1] + (b[1] - a[1]) * u] : a + (b - a) * u; }
  return o;
}
const WIND = poseOf({ hip: [-5, -44], lean: -0.16, fF: [12, -4], arc: 1, th: TH_WIND });
const END = poseOf({ hip: [11, -41], lean: 0.42, fF: [31, 0], fB: [-14, 0], arc: 1, th: TH_END });
function strikeBody(th) { const p = mixP(WIND, END, clamp((th - TH_WIND) / SWING, 0, 1)); p.th = th; return p; }
const shoulderOf = p => [p.hip[0] + Math.sin(p.lean) * LEN.torso * 0.88, p.hip[1] - Math.cos(p.lean) * LEN.torso * 0.88];
function strikeHand(th) { const sh = shoulderOf(strikeBody(th)), a = arcAngle(th); return [sh[0] + Math.cos(a) * ARC_R, sh[1] + Math.sin(a) * ARC_R]; }
function solveRig(p) {
  const dir = [Math.sin(p.lean), -Math.cos(p.lean)], hip = p.hip;
  const neck = [hip[0] + dir[0] * LEN.torso, hip[1] + dir[1] * LEN.torso];
  const sh = [hip[0] + dir[0] * LEN.torso * 0.88, hip[1] + dir[1] * LEN.torso * 0.88];
  const ha = p.lean + p.head, head = [neck[0] + Math.sin(ha) * (LEN.head + 2), neck[1] - Math.cos(ha) * (LEN.head + 2)];
  let hw = p.hW;
  if (p.arc > 0.001) { const a = arcAngle(p.th), t = [sh[0] + Math.cos(a) * ARC_R, sh[1] + Math.sin(a) * ARC_R]; hw = [hw[0] + (t[0] - hw[0]) * p.arc, hw[1] + (t[1] - hw[1]) * p.arc]; }
  const lF = ik(hip, p.fF, LEN.thigh, LEN.shin, -1), lB = ik(hip, p.fB, LEN.thigh, LEN.shin, -1);
  const aW = ik(sh, hw, LEN.upper, LEN.fore, 1), aS = ik(sh, p.hS, LEN.upper, LEN.fore, 1);
  return { hip, neck, sh, head, ha, lean: p.lean, kneeF: lF.J, footF: lF.E, kneeB: lB.J, footB: lB.E, elbW: aW.J, handW: aW.E, elbS: aS.J, handS: aS.E };
}
function strokeLen(s) { if (s.length < 2) return 3; let L = 0; for (let i = 1; i < s.length; i++) L += Math.hypot(s[i][0] - s[i - 1][0], s[i][1] - s[i - 1][1]); return L; }
function inkOf(st) { let L = 0; for (const s of st) L += strokeLen(s); return L; }
function resample(st, step = 5) {
  const out = [];
  for (const s of st) {
    if (!s.length) continue;
    out.push(s[0][0], s[0][1]);
    for (let i = 1; i < s.length; i++) {
      const ax = s[i - 1][0], ay = s[i - 1][1], bx = s[i][0], by = s[i][1];
      const n = Math.max(1, Math.ceil(Math.hypot(bx - ax, by - ay) / step));
      for (let k = 1; k <= n; k++) out.push(ax + (bx - ax) * k / n, ay + (by - ay) * k / n);
    }
  }
  return new Float32Array(out);
}
function effectiveReach(pts) {
  let best = 0;
  for (let k = 0; k <= 32; k++) {
    const th = TH_WIND + SWING * k / 32, h = strikeHand(th), c = Math.cos(th), s = Math.sin(th);
    for (let i = 0; i < pts.length; i += 2) {
      const x = h[0] + pts[i] * c - pts[i + 1] * s, y = h[1] + pts[i] * s + pts[i + 1] * c;
      if (y > -112 && y < -2 && x > best) best = x;
    }
  }
  return best;
}
function dimsOf(pts) {
  if (!pts.length) return { len: 0, wid: 0 };
  let tx = 0, ty = -1, best = -1;
  for (let i = 0; i < pts.length; i += 2) { const r = pts[i] * pts[i] + pts[i + 1] * pts[i + 1]; if (r > best) { best = r; tx = pts[i]; ty = pts[i + 1]; } }
  const n = Math.hypot(tx, ty) || 1, ux = tx / n, uy = ty / n;
  let a0 = 0, a1 = 0, b0 = 1e9, b1 = -1e9;
  for (let i = 0; i < pts.length; i += 2) {
    const a = pts[i] * ux + pts[i + 1] * uy, b = pts[i + 1] * ux - pts[i] * uy;
    if (a < a0) a0 = a; if (a > a1) a1 = a; if (b < b0) b0 = b; if (b > b1) b1 = b;
  }
  return { len: a1 - a0, wid: b1 - b0 };
}
function weaponStats(st) {
  const L = st.length ? inkOf(st) : 0;
  const pts = resample(st);
  let tip = 0, best = -1;
  for (let i = 0; i < pts.length; i += 2) { const r = pts[i] * pts[i] + pts[i + 1] * pts[i + 1]; if (r > best) { best = r; tip = i; } }
  const { len, wid } = dimsOf(pts), l2 = len * len;
  const windup = 0.05 + 0.0005 * len + 0.0000095 * l2 + 0.0008 * wid;
  const strike = 0.03 + 0.0005 * len + 0.0000025 * l2 + 0.0003 * wid;
  const recover = 0.08 + 0.0008 * len + 0.000006 * l2 + 0.0004 * wid;
  return { L, len, wid, strike, windup, recover, tip, n: pts.length, reach: effectiveReach(pts), P: 30 + 0.25 * L, D: 3 + L / 40 };
}
function shieldStats(st) {
  const L = st.length ? inkOf(st) : 0, ok = L >= 5;
  const pts = resample(st);
  const bins = new Uint8Array(27);
  let x0 = 1e9, x1 = -1e9, y0 = 1e9, y1 = -1e9;
  for (let i = 0; i < pts.length; i += 2) {
    const x = pts[i], y = pts[i + 1];
    if (x < x0) x0 = x; if (x > x1) x1 = x; if (y < y0) y0 = y; if (y > y1) y1 = y;
    const yy0 = SH_RAISED.y + y;
    for (let yy = yy0 - S_R; yy <= yy0 + S_R; yy += 2) { const b = Math.floor((yy + 108) / 4); if (b >= 0 && b < 27) bins[b] = 1; }
  }
  let cov = 0; for (let i = 0; i < 27; i++) cov += bins[i];
  const H = ok ? y1 - y0 : 0, W = ok ? x1 - x0 : 0;
  return { L, has: ok, H, W, cx: ok ? (x0 + x1) / 2 : 0, cy: ok ? (y0 + y1) / 2 : 0, coverage: ok ? cov / 27 : 0, n: pts.length,
    raise: 0.03 + 0.0012 * H + 0.000009 * H * H + 0.0004 * W, lower: 0.04 + 0.0007 * H + 0.0002 * W };
}
function circ(cx, cy, r, n) { const a = []; for (let i = 0; i <= n; i++) { const t = i / n * Math.PI * 2; a.push([cx + Math.cos(t) * r, cy + Math.sin(t) * r]); } return a; }
const W_TEMPL = {
  'kiem': [[[0, 14], [5, -130]], [[-18, -10], [21, -13]]],
  'giao': [[[-2, 18], [9, -182]], [[-2, -178], [10, -214], [22, -180], [-2, -178]]],
  'bua': [[[0, 22], [3, -118]], [[-28, -116], [34, -120], [36, -160], [-26, -156], [-28, -116]]],
  'riu': [[[0, 22], [2, -132]], [[2, -130], [40, -146], [52, -102], [2, -96]]],
  'chuy-gai': [[[0, 20], [1, -92]], circ(1, -114, 22, 18), [[1, -136], [1, -152]], [[23, -114], [39, -114]], [[17, -130], [28, -142]], [[17, -98], [28, -86]]],
  'dao-cong': [[[0, 16], [4, -30], [10, -80], [20, -124], [34, -160]], [[-12, -6], [15, -10]]],
  'dinh-ba': [[[0, 18], [0, -168]], [[-22, -160], [22, -160]], [[-22, -160], [-22, -198]], [[0, -168], [0, -208]], [[22, -160], [22, -198]]]
};
const S_TEMPL = {
  'khien-tron': [circ(10, -4, 42, 22)],
  'khien-thap': [[[-6, -72], [24, -72], [24, 62], [-6, 62], [-6, -72]]],
  'khien-dieu': [[[9, -58], [32, -30], [10, 62], [-12, -30], [9, -58]]],
  'khien-nho': [circ(12, -8, 24, 16)],
  'khien-gai': [circ(8, -4, 34, 20), [[42, -4], [58, -4]], [[32, -26], [44, -38]], [[32, 18], [44, 30]]]
};
// Deterministic scribbles so the parity test also covers free-hand drawings.
let seed = 20261114;
const rnd = () => (seed = (seed * 16807) % 2147483647) / 2147483647;
function scribble(nStrokes, nPts, spread) {
  const st = [];
  for (let s = 0; s < nStrokes; s++) {
    let x = (rnd() - 0.5) * 30, y = -rnd() * 40; const pts = [[x, y]];
    for (let i = 1; i < nPts; i++) { x += (rnd() - 0.4) * spread; y -= rnd() * spread; pts.push([Math.round(x * 10) / 10, Math.round(y * 10) / 10]); }
    st.push(pts);
  }
  return st;
}
const flat = st => st.map(s => s.flat());
const weapons = [], shields = [];
for (const [id, st] of Object.entries(W_TEMPL)) weapons.push({ id, strokes: flat(st), expect: weaponStats(st) });
for (let k = 0; k < 6; k++) { const st = scribble(1 + k % 3, 6 + k * 3, 18); weapons.push({ id: 'scribble-' + k, strokes: flat(st), expect: weaponStats(st) }); }
weapons.push({ id: 'dot', strokes: [[3, -40]], expect: weaponStats([[[3, -40]]]) });
weapons.push({ id: 'empty', strokes: [], expect: weaponStats([]) });
for (const [id, st] of Object.entries(S_TEMPL)) shields.push({ id, strokes: flat(st), expect: shieldStats(st) });
for (let k = 0; k < 4; k++) { const st = scribble(2, 8 + k * 2, 14); shields.push({ id: 'scribble-' + k, strokes: flat(st), expect: shieldStats(st) }); }
shields.push({ id: 'empty', strokes: [], expect: shieldStats([]) });
const hands = [];
for (let k = 0; k <= 8; k++) { const th = TH_WIND + SWING * k / 8; hands.push({ th, hand: strikeHand(th) }); }
const rigs = { rest: solveRig(REST), wind: solveRig(WIND), end: solveRig(END) };
const out = { hand0: [HAND0.x, HAND0.y], weapons, shields, hands, rigs };
writeFileSync(new URL('../../test/fixtures/gear_golden.json', import.meta.url), JSON.stringify(out, null, 1));
console.log(`wrote ${weapons.length} weapons, ${shields.length} shields`);
