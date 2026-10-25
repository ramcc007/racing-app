// The eight worlds: palette, decoration and the mechanic each one introduces.
const WORLDS = [
  { n: 1, name: 'Harbour', mech: 'Echoes + slipstream', note: 'Echoes are soft here: you pass through them.',
    ground: '#C9C2B4', asphalt: '#3B3F47', kerbB: '#D64545', deco: 'containers', accent: '#2F7FB5' },
  { n: 2, name: 'Red Canyon', mech: 'Echoes turn solid', note: 'Sand patches slow you; bumps cost time.',
    ground: '#D9925B', asphalt: '#4A3A33', kerbB: '#F2E2C4', deco: 'mesas', accent: '#A8532E' },
  { n: 3, name: 'Neon City', mech: 'Switch pads & gates', note: 'Park an echo on a pad to hold a shortcut open.',
    ground: '#1D1B33', asphalt: '#2A2A40', kerbB: '#E84DD1', deco: 'neon', accent: '#43E0FF' },
  { n: 4, name: 'Glacier', mech: 'Thin ice', note: 'Every pass cracks the ice: three and it breaks.',
    ground: '#DDEFF7', asphalt: '#7FA9C2', kerbB: '#2C6E9B', deco: 'ice', accent: '#2C6E9B' },
  { n: 5, name: 'Jungle Ruins', mech: 'Relay swap', note: 'Once a lap, swap places with the echo ahead.',
    ground: '#3E7D45', asphalt: '#5B4B3A', kerbB: '#E3C16F', deco: 'jungle', accent: '#E3C16F' },
  { n: 6, name: 'Foundry', mech: 'Sensor bridges', note: 'Bridges turn when any car crosses a sensor.',
    ground: '#2B2523', asphalt: '#3A3433', kerbB: '#FF7A1A', deco: 'lava', accent: '#FF7A1A' },
  { n: 7, name: 'Sky Port', mech: 'Crosswinds', note: 'Wind shoves you; slipstream doubles as cover.',
    ground: '#9FD3F0', asphalt: '#5E6B7A', kerbB: '#FFFFFF', deco: 'clouds', accent: '#FFFFFF' },
  { n: 8, name: 'Orbit Ring', mech: 'Everything, at once', note: 'Low gravity jumps and 8-lap echo storms.',
    ground: '#0C1022', asphalt: '#2C3150', kerbB: '#B49BFF', deco: 'space', accent: '#B49BFF' },
];

function decorate(g, w, x, y, W, H, r) {
  const R = () => r();
  const inBox = n => [x + R() * W, y + R() * H];
  if (w.deco === 'containers') {
    const c = ['#E07A3F', '#3F8FD2', '#E3B341', '#4CB28B'];
    for (let i = 0; i < 9; i++) { const [px, py] = inBox(); el('rect', { x: px, y: py, width: 90, height: 34, rx: 3, fill: c[i % 4] }, g); }
    el('path', { d: `M${x} ${y + H * 0.75} Q${x + W * 0.3} ${y + H * 0.65} ${x + W * 0.5} ${y + H} L${x} ${y + H} Z`, fill: '#2F7FB5' }, g);
  } else if (w.deco === 'mesas') {
    for (let i = 0; i < 6; i++) { const [px, py] = inBox(); el('ellipse', { cx: px, cy: py, rx: 60 + R() * 40, ry: 34 + R() * 20, fill: '#B5653B' }, g); el('ellipse', { cx: px - 8, cy: py - 8, rx: 40, ry: 20, fill: '#C97A4A' }, g); }
    for (let i = 0; i < 8; i++) { const [px, py] = inBox(); el('rect', { x: px, y: py, width: 10, height: 34, rx: 5, fill: '#4F7A3A' }, g); el('rect', { x: px - 10, y: py + 10, width: 30, height: 8, rx: 4, fill: '#4F7A3A' }, g); }
  } else if (w.deco === 'neon') {
    for (let i = 0; i < 10; i++) {
      const [px, py] = inBox();
      el('rect', { x: px, y: py, width: 70, height: 70, rx: 6, fill: '#2C2950' }, g);
      el('rect', { x: px + 6, y: py + 6, width: 58, height: 58, rx: 4, fill: 'none', stroke: ['#43E0FF', '#E84DD1', '#F7E14B'][i % 3], 'stroke-width': 3 }, g);
    }
  } else if (w.deco === 'ice') {
    for (let i = 0; i < 7; i++) { const [px, py] = inBox(); el('polygon', { points: `${px},${py} ${px + 50},${py - 20} ${px + 80},${py + 30} ${px + 30},${py + 50}`, fill: '#FFFFFF', stroke: '#B9DCEB', 'stroke-width': 3 }, g); }
    for (let i = 0; i < 6; i++) { const [px, py] = inBox(); el('path', { d: `M${px} ${py} l20 14 l-6 20 l24 8`, fill: 'none', stroke: '#7FB3CF', 'stroke-width': 3 }, g); }
  } else if (w.deco === 'jungle') {
    for (let i = 0; i < 12; i++) { const [px, py] = inBox(); tree(g, px, py, null, 0.6 + R() * 0.6); }
    for (let i = 0; i < 3; i++) { const [px, py] = inBox(); el('rect', { x: px, y: py, width: 80, height: 50, rx: 4, fill: '#9C9A86' }, g); el('rect', { x: px + 10, y: py + 10, width: 60, height: 8, fill: '#7E7C6A' }, g); }
  } else if (w.deco === 'lava') {
    for (let i = 0; i < 5; i++) { const [px, py] = inBox(); el('path', { d: `M${px} ${py} q40 -30 80 0 t80 10 q-30 40 -90 30 t-70 -40 Z`, fill: '#FF7A1A' }, g); el('path', { d: `M${px + 20} ${py + 4} q30 -16 60 0`, fill: 'none', stroke: '#FFD166', 'stroke-width': 5 }, g); }
    for (let i = 0; i < 6; i++) { const [px, py] = inBox(); el('rect', { x: px, y: py, width: 60, height: 60, fill: '#46403C' }, g); el('circle', { cx: px + 30, cy: py + 30, r: 14, fill: '#2B2523' }, g); }
  } else if (w.deco === 'clouds') {
    for (let i = 0; i < 8; i++) { const [px, py] = inBox(); [0, 30, 60].forEach((d, k) => el('circle', { cx: px + d, cy: py + (k === 1 ? -14 : 0), r: 26 + (k === 1) * 10, fill: '#FFFFFF', opacity: 0.9 }, g)); }
    for (let i = 0; i < 6; i++) { const [px, py] = inBox(); el('path', { d: `M${px} ${py} h70 m-20 -10 l20 10 l-20 10`, fill: 'none', stroke: 'rgba(255,255,255,.8)', 'stroke-width': 4, 'stroke-linecap': 'round' }, g); }
  } else if (w.deco === 'space') {
    for (let i = 0; i < 60; i++) { const [px, py] = inBox(); el('circle', { cx: px, cy: py, r: R() * 2.5 + 0.5, fill: '#FFFFFF', opacity: 0.4 + R() * 0.6 }, g); }
    const [px, py] = inBox(); el('circle', { cx: px, cy: py, r: 50, fill: '#6B5BD6' }, g); el('ellipse', { cx: px, cy: py, rx: 80, ry: 14, fill: 'none', stroke: '#B49BFF', 'stroke-width': 4 }, g);
  }
}
