// Shared drawing kit for the concept images. Everything is drawn by code,
// the same way the game would draw it: no image files, no fonts beyond Inter.
// Concept only — not final art.

const NS = 'http://www.w3.org/2000/svg';

// Colour-blind-safe echo palette (Okabe–Ito), one colour per lap.
const ECHO = ['#E69F00', '#56B4E9', '#009E73', '#F0E442', '#0072B2', '#D55E00', '#CC79A7', '#9AA0A6'];

function el(tag, attrs = {}, parent) {
  const n = document.createElementNS(NS, tag);
  for (const k in attrs) n.setAttribute(k, attrs[k]);
  if (parent) parent.appendChild(n);
  return n;
}

function svgRoot(w, h, bg) {
  document.body.style.margin = '0';
  document.body.style.background = bg || '#000';
  const s = el('svg', { width: w, height: h, viewBox: `0 0 ${w} ${h}` });
  document.body.appendChild(s);
  el('rect', { width: w, height: h, fill: bg || '#000' }, s);
  return s;
}

// Seeded random so every render is identical (like the game's daily track).
function rng(seed) {
  let s = seed >>> 0;
  return () => ((s = (s * 1664525 + 1013904223) >>> 0) / 4294967296);
}

// Closed Catmull–Rom spline through control points, sampled evenly-ish.
function spline(ctrl, perSeg = 40, closed = true) {
  const pts = [];
  const n = ctrl.length;
  const segs = closed ? n : n - 1;
  for (let i = 0; i < segs; i++) {
    const p0 = ctrl[(i - 1 + n) % n], p1 = ctrl[i], p2 = ctrl[(i + 1) % n], p3 = ctrl[(i + 2) % n];
    const a = closed || i > 0 ? p0 : p1, d = closed || i < n - 2 ? p3 : p2;
    for (let t = 0; t < 1; t += 1 / perSeg) {
      const t2 = t * t, t3 = t2 * t;
      pts.push([
        0.5 * (2 * p1[0] + (-a[0] + p2[0]) * t + (2 * a[0] - 5 * p1[0] + 4 * p2[0] - d[0]) * t2 + (-a[0] + 3 * p1[0] - 3 * p2[0] + d[0]) * t3),
        0.5 * (2 * p1[1] + (-a[1] + p2[1]) * t + (2 * a[1] - 5 * p1[1] + 4 * p2[1] - d[1]) * t2 + (-a[1] + 3 * p1[1] - 3 * p2[1] + d[1]) * t3),
      ]);
    }
  }
  if (!closed) pts.push(ctrl[n - 1]);
  return pts;
}

function pathD(pts, closed = true) {
  return 'M' + pts.map(p => p[0].toFixed(1) + ' ' + p[1].toFixed(1)).join(' L') + (closed ? ' Z' : '');
}

// Position + heading at fraction f (0..1) along a sampled path, with sideways offset.
function along(pts, f, offset = 0) {
  const n = pts.length;
  const i = Math.floor(((f % 1) + 1) % 1 * n);
  const a = pts[i], b = pts[(i + 1) % n];
  const ang = Math.atan2(b[1] - a[1], b[0] - a[0]);
  return { x: a[0] - Math.sin(ang) * offset, y: a[1] + Math.cos(ang) * offset, a: ang * 180 / Math.PI };
}

// Sub-path from f0 to f1 with a sideways offset (for echo trails and racing lines).
function slice(pts, f0, f1, offset = 0, wobble = 0, seed = 1) {
  const r = rng(seed);
  const out = [];
  const steps = 80;
  let w = 0;
  for (let k = 0; k <= steps; k++) {
    w += (r() - 0.5) * wobble * 0.35;
    w *= 0.97;
    const p = along(pts, f0 + (f1 - f0) * (k / steps), offset + w);
    out.push([p.x, p.y]);
  }
  return out;
}

// A road: shadow, kerb, asphalt, edge line, centre dashes.
function road(parent, pts, o = {}) {
  const w = o.width || 120;
  const g = el('g', {}, parent);
  const d = pathD(pts, o.closed !== false);
  const common = { d, fill: 'none', 'stroke-linejoin': 'round', 'stroke-linecap': 'round' };
  el('path', { ...common, stroke: 'rgba(0,0,0,.28)', 'stroke-width': w + 34, transform: 'translate(10 16)' }, g);
  el('path', { ...common, stroke: o.kerbA || '#E8E4DA', 'stroke-width': w + 22 }, g);
  el('path', { ...common, stroke: o.kerbB || '#D64545', 'stroke-width': w + 22, 'stroke-dasharray': '26 26' }, g);
  el('path', { ...common, stroke: o.asphalt || '#3B3F47', 'stroke-width': w }, g);
  el('path', { ...common, stroke: o.edge || 'rgba(255,255,255,.85)', 'stroke-width': w - 14 }, g);
  el('path', { ...common, stroke: o.asphalt || '#3B3F47', 'stroke-width': w - 22 }, g);
  el('path', { ...common, stroke: o.dash || 'rgba(255,255,255,.35)', 'stroke-width': 5, 'stroke-dasharray': '30 34' }, g);
  return g;
}

// Chequered start/finish strip across the road at fraction f.
function startLine(parent, pts, f, w) {
  const p = along(pts, f);
  const g = el('g', { transform: `translate(${p.x} ${p.y}) rotate(${p.a})` }, parent);
  const cells = 8, cw = (w - 22) / cells;
  for (let r = 0; r < 2; r++)
    for (let c = 0; c < cells; c++)
      el('rect', { x: -14 + r * 14, y: -(w - 22) / 2 + c * cw, width: 14, height: cw, fill: (r + c) % 2 ? '#111' : '#fff' }, g);
  return g;
}

// An original toy-like racer: rounded pod body, bubble canopy, fat wheels.
// Deliberately not modelled on any real car.
function car(parent, x, y, ang, color, o = {}) {
  const s = o.scale || 1;
  const g = el('g', { transform: `translate(${x} ${y}) rotate(${ang}) scale(${s})`, opacity: o.opacity ?? 1 }, parent);
  if (!o.noShadow) el('rect', { x: -34, y: -20, width: 72, height: 46, rx: 20, fill: 'rgba(0,0,0,.30)', transform: 'translate(5 9)' }, g);
  const wheel = '#1C1E22';
  [[-22, -24], [14, -24], [-22, 16], [14, 16]].forEach(([wx, wy]) => el('rect', { x: wx, y: wy, width: 18, height: 8, rx: 3, fill: wheel }, g));
  const shape = o.shape || 'pod';
  if (shape === 'pod') {
    el('path', { d: 'M-34 -12 Q-34 -20 -24 -20 L18 -18 Q38 -14 40 0 Q38 14 18 18 L-24 20 Q-34 20 -34 12 Z', fill: color }, g);
    el('path', { d: 'M-30 -6 L30 -4 L30 4 L-30 6 Z', fill: 'rgba(255,255,255,.22)' }, g);
    el('ellipse', { cx: 2, cy: 0, rx: 12, ry: 9, fill: o.canopy || '#1E2A3A' }, g);
    el('ellipse', { cx: 5, cy: -3, rx: 5, ry: 3, fill: 'rgba(255,255,255,.55)' }, g);
  } else if (shape === 'wedge') {
    el('path', { d: 'M-34 -18 L10 -18 L42 -4 L42 4 L10 18 L-34 18 Q-38 0 -34 -18 Z', fill: color }, g);
    el('path', { d: 'M-8 -10 L14 -8 L24 0 L14 8 L-8 10 Z', fill: o.canopy || '#1E2A3A' }, g);
    el('rect', { x: -38, y: -20, width: 8, height: 40, rx: 3, fill: 'rgba(0,0,0,.35)' }, g);
  } else if (shape === 'buggy') {
    el('rect', { x: -28, y: -14, width: 60, height: 28, rx: 14, fill: color }, g);
    el('rect', { x: -12, y: -18, width: 26, height: 36, rx: 6, fill: 'none', stroke: '#1C1E22', 'stroke-width': 4 }, g);
    el('circle', { cx: 2, cy: 0, r: 8, fill: o.canopy || '#1E2A3A' }, g);
  } else if (shape === 'brick') {
    el('rect', { x: -34, y: -20, width: 74, height: 40, rx: 9, fill: color }, g);
    el('rect', { x: -10, y: -15, width: 30, height: 30, rx: 5, fill: o.canopy || '#1E2A3A' }, g);
    el('rect', { x: 34, y: -16, width: 6, height: 32, rx: 2, fill: 'rgba(255,255,255,.7)' }, g);
  } else if (shape === 'needle') {
    el('path', { d: 'M-36 -10 Q-36 -14 -30 -14 L20 -8 Q46 -3 46 0 Q46 3 20 8 L-30 14 Q-36 14 -36 10 Z', fill: color }, g);
    el('rect', { x: -40, y: -22, width: 10, height: 44, rx: 3, fill: color, opacity: 0.85 }, g);
    el('ellipse', { cx: -2, cy: 0, rx: 10, ry: 6, fill: o.canopy || '#1E2A3A' }, g);
  } else if (shape === 'hover') {
    el('ellipse', { cx: 2, cy: 0, rx: 40, ry: 22, fill: color }, g);
    el('ellipse', { cx: 2, cy: 0, rx: 40, ry: 22, fill: 'none', stroke: 'rgba(255,255,255,.6)', 'stroke-width': 3, 'stroke-dasharray': '6 8' }, g);
    el('ellipse', { cx: 6, cy: 0, rx: 13, ry: 10, fill: o.canopy || '#1E2A3A' }, g);
  }
  // Headlights at the nose and a dark rear wing make the heading readable at a glance.
  if (shape !== 'hover') {
    el('rect', { x: shape === 'needle' ? 38 : 33, y: -12, width: 7, height: 7, rx: 3, fill: '#FFE9A8' }, g);
    el('rect', { x: shape === 'needle' ? 38 : 33, y: 5, width: 7, height: 7, rx: 3, fill: '#FFE9A8' }, g);
    el('rect', { x: -40, y: -18, width: 8, height: 36, rx: 3, fill: '#1C1E22', opacity: 0.85 }, g);
  }
  if (o.outline) el('rect', { x: -40, y: -26, width: 86, height: 52, rx: 24, fill: 'none', stroke: o.outline, 'stroke-width': 4 }, g);
  if (o.label) {
    el('circle', { cx: -16, cy: 0, r: 10, fill: 'rgba(0,0,0,.55)' }, g);
    const t = el('text', { x: -16, y: 5, 'text-anchor': 'middle', 'font-family': 'Inter', 'font-weight': 800, 'font-size': 14, fill: '#fff', transform: `rotate(${-ang} -16 0)` }, g);
    t.textContent = o.label;
  }
  return g;
}

// An echo: translucent car + fading ribbon of where it has been.
function echo(parent, pts, f, lap, o = {}) {
  const col = ECHO[(lap - 1) % ECHO.length];
  const off = o.offset || 0;
  const trail = slice(pts, f - (o.trail || 0.08), f, off, o.wobble || 3, lap * 7);
  const grad = 'eg' + lap + Math.round(f * 1000);
  const defs = el('defs', {}, parent);
  const a = trail[0], b = trail[trail.length - 1];
  const lg = el('linearGradient', { id: grad, gradientUnits: 'userSpaceOnUse', x1: a[0], y1: a[1], x2: b[0], y2: b[1] }, defs);
  el('stop', { offset: '0', 'stop-color': col, 'stop-opacity': 0 }, lg);
  el('stop', { offset: '1', 'stop-color': col, 'stop-opacity': 0.75 }, lg);
  el('path', { d: pathD(trail, false), fill: 'none', stroke: `url(#${grad})`, 'stroke-width': o.trailWidth || 22, 'stroke-linecap': 'round' }, parent);
  const p = along(pts, f, off);
  car(parent, p.x, p.y, p.a, col, { opacity: o.opacity ?? 0.82, label: String(lap), scale: o.scale || 1, noShadow: true });
  return p;
}

function text(parent, x, y, str, o = {}) {
  const t = el('text', {
    x, y, 'font-family': o.family || 'Inter', 'font-weight': o.weight || 700, 'font-size': o.size || 32,
    fill: o.fill || '#fff', 'text-anchor': o.anchor || 'start', 'letter-spacing': o.spacing || 0,
    ...(o.opacity != null ? { opacity: o.opacity } : {}),
  }, parent);
  t.textContent = str;
  return t;
}

function panel(parent, x, y, w, h, o = {}) {
  return el('rect', { x, y, width: w, height: h, rx: o.r ?? 28, fill: o.fill || 'rgba(12,14,20,.72)', stroke: o.stroke || 'rgba(255,255,255,.12)', 'stroke-width': o.sw || 2 }, parent);
}

function star(parent, cx, cy, r, fill, stroke) {
  const pts = [];
  for (let i = 0; i < 10; i++) {
    const a = -Math.PI / 2 + i * Math.PI / 5, rr = i % 2 ? r * 0.45 : r;
    pts.push((cx + Math.cos(a) * rr).toFixed(1) + ',' + (cy + Math.sin(a) * rr).toFixed(1));
  }
  return el('polygon', { points: pts.join(' '), fill, stroke: stroke || 'none', 'stroke-width': 3, 'stroke-linejoin': 'round' }, parent);
}

// "Concept — not final art" stamp, required on every image.
function stamp(parent, w, h, top) {
  const g = el('g', {}, parent);
  const y = top ? 64 : h - 20;
  el('rect', { x: w - 380, y: y - 44, width: 356, height: 44, rx: 22, fill: 'rgba(0,0,0,.55)' }, g);
  text(g, w - 202, y - 14, 'Concept — not final art', { size: 20, weight: 600, anchor: 'middle', fill: 'rgba(255,255,255,.9)' });
}

// Scatter decoration around (but not on) the road.
function scatter(parent, pts, w, h, count, seed, minDist, draw, avoid) {
  const r = rng(seed);
  let placed = 0, tries = 0;
  while (placed < count && tries < count * 40) {
    tries++;
    const x = r() * w, y = r() * h;
    let near = Infinity;
    for (let i = 0; i < pts.length; i += 3) near = Math.min(near, Math.hypot(pts[i][0] - x, pts[i][1] - y));
    if (near < minDist) continue;
    if (avoid && avoid(x, y)) continue;
    draw(parent, x, y, r);
    placed++;
  }
}

function tree(parent, x, y, r, s = 1) {
  el('circle', { cx: x + 10 * s, cy: y + 14 * s, r: 34 * s, fill: 'rgba(0,0,0,.18)' }, parent);
  el('circle', { cx: x, cy: y, r: 34 * s, fill: '#2F8F4E' }, parent);
  el('circle', { cx: x - 10 * s, cy: y - 10 * s, r: 20 * s, fill: '#46AE62' }, parent);
}
