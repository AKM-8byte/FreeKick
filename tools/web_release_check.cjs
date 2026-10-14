// Optional: npm install --no-save playwright
// Serve the release export locally and capture the real browser startup.
const { chromium } = require('playwright');
const fs = require('fs');
const http = require('http');
const path = require('path');

(async () => {
  const base = path.resolve(__dirname, '../build/web');
  const output = path.resolve(__dirname, '../test-output/web-release');
  fs.mkdirSync(output, { recursive: true });
  const types = {'.html':'text/html', '.js':'application/javascript', '.wasm':'application/wasm', '.pck':'application/octet-stream', '.png':'image/png', '.svg':'image/svg+xml'};
  const server = http.createServer((request, response) => {
    const requested = new URL(request.url, 'http://localhost').pathname;
    const file = path.resolve(base, '.' + (requested === '/' ? '/index.html' : requested));
    if (!file.startsWith(base + path.sep) || !fs.existsSync(file)) {
      response.writeHead(404); response.end(); return;
    }
    response.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    fs.createReadStream(file).pipe(response);
  });
  let browser;
  const logs = [];
  try {
    await new Promise(resolve => server.listen(8072, '127.0.0.1', resolve));
    const chrome = process.env.CHROME_PATH || path.join(process.env.ProgramFiles || 'C:/Program Files', 'Google/Chrome/Application/chrome.exe');
    browser = await chromium.launch({executablePath: chrome, headless: true, args: ['--enable-webgl', '--ignore-gpu-blocklist', '--disable-background-networking']});
    const page = await browser.newPage({viewport: {width:1440, height:900}, locale:'en-US'});
    page.on('console', message => logs.push({type:message.type(), text:message.text()}));
    page.on('pageerror', error => logs.push({type:'pageerror', text:error.message}));
    page.on('response', response => {if (response.status() >= 400) logs.push({type:'http_error', text:response.status() + ' ' + response.url()});});
    // Hold the WASM download briefly so the engine-independent opening can
    // be captured even on a very fast local server; this is not an FPS test.
    await page.route('**/*.wasm', async route => {
      await new Promise(resolve => setTimeout(resolve, 1800));
      await route.continue();
    });
    await page.goto('http://127.0.0.1:8072/', {waitUntil:'domcontentloaded'});
    await page.locator('#status h1').waitFor();
    if (await page.locator('#status h1').innerText() !== 'Created by Ahmet Kayra') throw Error('Missing custom opening credit');
    if (await page.locator('.opening').evaluate(element => getComputedStyle(element).animationName) !== 'appear') throw Error('Missing opening animation');
    await page.waitForTimeout(700);
    await page.screenshot({path:path.join(output, 'engine-loading.png')});
    await page.waitForFunction(() => {
      const status = document.querySelector('#status');
      return !status || getComputedStyle(status).display === 'none';
    }, null, {timeout:90000});
    await page.waitForTimeout(900);
    await page.screenshot({path:path.join(output, 'startup.png')});
    await page.waitForTimeout(9000);
    await page.screenshot({path:path.join(output, 'loaded.png')});
    const errors = logs.filter(message => ['error', 'pageerror', 'http_error'].includes(message.type) || /SCRIPT ERROR:|^ERROR:/.test(message.text));
    fs.writeFileSync(path.join(output, 'browser.json'), JSON.stringify({browser:await browser.version(), errors, logs}, null, 2));
    if (errors.length) throw Error('Browser errors: ' + JSON.stringify(errors));
    console.log('WEB RELEASE STARTUP: PASS; screenshots and console log saved to test-output/web-release.');
  } finally {
    if (browser) await browser.close();
    await new Promise(resolve => server.close(resolve));
  }
})().catch(error => {console.error(error); process.exitCode = 1;});
