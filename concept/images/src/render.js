// Renders every concept image to PNG with the pre-installed Playwright Chromium.
//   node concept/images/src/render.js            # all images
//   node concept/images/src/render.js 02 05      # only names starting with these
const { chromium } = require('playwright');
const path = require('path');

const IMAGES = [
  ['01-key-art', 2400, 1350],
  ['02-iphone-gameplay', 1320, 2868],
  ['03-ipad-gameplay', 2064, 2752],
  ['04-world-map', 1320, 2868],
  ['05-results', 1320, 2868],
  ['06-worlds-moodboard', 2400, 1600],
  ['07-vehicle-lineup', 2400, 1350],
  ['08-twist-diagram', 2400, 1500],
];

(async () => {
  const only = process.argv.slice(2);
  const browser = await chromium.launch();
  for (const [name, width, height] of IMAGES) {
    if (only.length && !only.some(o => name.startsWith(o))) continue;
    const page = await browser.newPage({ viewport: { width, height } });
    const errors = [];
    page.on('pageerror', e => errors.push(e.message));
    await page.goto('file://' + path.join(__dirname, name + '.html'));
    await page.evaluate(() => document.fonts.ready);
    if (errors.length) throw new Error(name + ': ' + errors.join('; '));
    await page.screenshot({ path: path.join(__dirname, '..', name + '.png') });
    await page.close();
    console.log('rendered', name);
  }
  await browser.close();
})();
