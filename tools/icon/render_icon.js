// Renders design/icon/icon.html to the 1024 px app icon PNG (then flatten it: python3 tools/icon/flatten.py).
//   node tools/icon/render_icon.js
const { chromium } = require('playwright');
const path = require('path');
(async () => {
  const root = path.join(__dirname, '..', '..');
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1024, height: 1024 } });
  await page.goto('file://' + path.join(root, 'design/icon/icon.html'));
  await page.screenshot({ path: path.join(root, 'ios/EchoLap/Resources/Assets.xcassets/AppIcon.appiconset/AppIcon-1024.png'), omitBackground: false });
  await browser.close();
  console.log('icon rendered');
})();
