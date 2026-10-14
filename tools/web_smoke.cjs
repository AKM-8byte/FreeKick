const { chromium } = require('playwright');
const fs = require('fs');
const path = require('path');
const http = require('http');

(async () => {
  const parity = process.argv.includes('--parity');
  const embedded = process.argv.includes('--iframe');
  const output = path.resolve(parity ? 'test-output/web-parity' : (embedded ? 'test-output/web-iframe' : 'test-output/web'));
  fs.mkdirSync(output, {recursive: true});
  const base = path.resolve(parity ? 'build/web-qa' : 'build/web');
  const types = {'.html':'text/html', '.js':'application/javascript', '.wasm':'application/wasm', '.pck':'application/octet-stream', '.png':'image/png'};
  const server = http.createServer((req,res) => {
    const file = path.resolve(base, '.' + new URL(req.url, 'http://localhost').pathname);
    if(!file.startsWith(base + path.sep) || !fs.existsSync(file)) {res.writeHead(404);res.end();return;}
    res.setHeader('Content-Type', types[path.extname(file)] || 'application/octet-stream');
    fs.createReadStream(file).pipe(res);
  });
  await new Promise(resolve => server.listen(8060,'127.0.0.1',resolve));
  const frameServer = embedded ? http.createServer((req,res) => {
    res.setHeader('Content-Type','text/html');
    res.end('<!doctype html><html><body style="margin:0"><iframe title="FreeKick" src="http://127.0.0.1:8060/index.html" allow="autoplay; fullscreen; gamepad" allowfullscreen style="border:0;width:100vw;height:100vh"></iframe></body></html>');
  }) : null;
  if(frameServer) await new Promise(resolve => frameServer.listen(8061,'127.0.0.1',resolve));
  const browser = await chromium.launch({
    executablePath: 'C:/Program Files/Google/Chrome/Application/chrome.exe',
    headless: true,
    args: ['--enable-webgl', '--ignore-gpu-blocklist', '--disable-background-networking'],
  });
  const page = await browser.newPage({viewport: {width: 1440, height: 900}, locale: 'en-US'});
  const logs = [];
  const results = {};
  try {
  await page.addInitScript(() => {
    window.audioEvidence = {starts:0, maxRms:0, contexts:[]};
    const NativeContext = window.AudioContext;
    window.AudioContext = class extends NativeContext {
      constructor(...args) {super(...args);window.audioEvidence.contexts.push(this);}
      createBufferSource() {
        const source = super.createBufferSource();
        const start = source.start.bind(source);
        source.start = (...args) => {window.audioEvidence.starts++;return start(...args);};
        return source;
      }
    };
    const connect = AudioNode.prototype.connect;
    AudioNode.prototype.connect = function(destination, ...args) {
      if(destination === this.context.destination) {
        if(!this.context.monitor) {
          this.context.monitor = this.context.createAnalyser();
          connect.call(this.context.monitor, destination);
        }
        return connect.call(this,this.context.monitor,...args);
      }
      return connect.call(this,destination,...args);
    };
    setInterval(() => {
      for(const context of window.audioEvidence.contexts) {
        if(!context.monitor) continue;
        const data = new Float32Array(context.monitor.fftSize);
        context.monitor.getFloatTimeDomainData(data);
        const rms = Math.sqrt(data.reduce((sum,v)=>sum+v*v,0)/data.length);
        window.audioEvidence.maxRms = Math.max(window.audioEvidence.maxRms,rms);
      }
    },50);
  });
  page.on('console', msg => logs.push({type: msg.type(), text: msg.text()}));
  page.on('pageerror', err => logs.push({type: 'pageerror', text: err.message}));
  page.on('response', r => {if(r.status() >= 400) logs.push({type:'http_error', text:r.status()+' '+r.url()});});
  await page.goto(embedded ? 'http://127.0.0.1:8061/' : 'http://127.0.0.1:8060/index.html');
  const runtime = embedded ? page.frames().find(f=>f.url().startsWith('http://127.0.0.1:8060/')) : page;
  await runtime.waitForFunction(() => {
    const status = document.querySelector('#status');
    return !status || getComputedStyle(status).display === 'none';
  }, null, {timeout:60000});
  await page.waitForTimeout(1000);
  if(parity) {
    const end = Date.now() + 90000;
    while(!logs.some(l=>l.text.startsWith('WEB_PARITY_RESULT ')) && Date.now() < end) await page.waitForTimeout(1000);
    const line = logs.find(l=>l.text.startsWith('WEB_PARITY_RESULT '));
    if(!line) throw Error('Web physics probe timed out');
    const web = JSON.parse(line.text.slice('WEB_PARITY_RESULT '.length));
    const nativeText = fs.readFileSync('test-output/web/native-parity.log', 'utf8').split(/\r?\n/).find(l=>l.startsWith('WEB_PARITY_RESULT '));
    const native = JSON.parse(nativeText.slice('WEB_PARITY_RESULT '.length));
    const delta = (a,b) => Math.sqrt(a.reduce((sum,v,i)=>sum+(v-b[i])**2,0));
    results.native = native;
    results.web = web;
    results.consoleErrors = logs.filter(l=>['error','pageerror','http_error'].includes(l.type));
    if(results.consoleErrors.length) throw Error('Web QA console validation failed');
    results.comparison = web.shots.map((shot,i)=>({name:shot.name, speedDelta:Math.abs(shot.speed-native.shots[i].speed), spinDelta:delta(shot.spin,native.shots[i].spin), crossingDelta:delta(shot.crossing,native.shots[i].crossing)}));
    if(!web.goal || !web.net_contact || web.replay_angles !== 7) throw Error('Web goal, net or cinematic validation failed');
    if(web.ticks !== 120 || web.shots.some(s=>!s.stationary||!s.finite||s.crossing.length!==3) || results.comparison.some(s=>s.crossingDelta > 0.02 || s.speedDelta > 0.02 || s.spinDelta > 0.02)) throw Error('Web physics parity failed');
    return;
  }
  results.startup = true;
  results.browser = await browser.version();
  results.iframe = embedded;
  results.isolated = await runtime.evaluate(() => crossOriginIsolated);
  await page.screenshot({path:path.join(output, 'menu.png')});
  await page.mouse.click(720, 570);
  await page.waitForFunction(() => document.fullscreenElement !== null, null, {timeout:5000});
  results.fullscreen = true;
  await page.evaluate(() => document.exitFullscreen());
  await page.waitForTimeout(250);
  await page.mouse.click(720, 402);
  await page.waitForTimeout(3500);
  await page.screenshot({path:path.join(output, 'guide.png')});
  await page.keyboard.press('Enter');
  await page.waitForTimeout(250);
  await page.mouse.click(900,300);
  await page.waitForTimeout(250);
  await page.screenshot({path:path.join(output, 'aim.png')});
  await page.keyboard.down('Space');
  await page.waitForTimeout(800);
  await page.screenshot({path:path.join(output, 'power.png')});
  await page.keyboard.up('Space');
  await page.waitForTimeout(500);
  await page.screenshot({path:path.join(output, 'timing-approach.png')});
  await page.waitForTimeout(2000);
  await page.screenshot({path:path.join(output, 'shot.png')});
  await page.waitForTimeout(2000);
  await page.keyboard.press('r');
  await page.waitForTimeout(400);
  await page.screenshot({path:path.join(output, 'reset.png')});
  // Exercise the optional second keyboard press in the actual production build.
  await page.keyboard.down('Space');
  await page.waitForTimeout(700);
  await page.keyboard.up('Space');
  await page.waitForTimeout(400);
  await page.keyboard.press('Space');
  await page.waitForTimeout(150);
  await page.screenshot({path:path.join(output, 'timing-selected.png')});
  await page.waitForTimeout(1800);
  await page.keyboard.press('r');
  await page.waitForTimeout(400);
  await page.keyboard.press('Tab');
  await page.waitForTimeout(200);
  await page.screenshot({path:path.join(output, 'training.png')});
  results.audio = await runtime.evaluate(() => ({starts:audioEvidence.starts, maxRms:audioEvidence.maxRms, states:audioEvidence.contexts.map(c=>c.state)}));
  results.resources = await runtime.evaluate(() => performance.getEntriesByType('resource').filter(r=>r.name.startsWith(location.origin+'/index.')).map(r=>({name:r.name.split('/').pop(),durationMs:r.duration,bytes:r.transferSize})));
  results.consoleErrors = logs.filter(l=>['error','pageerror','http_error'].includes(l.type));
  if(!results.audio.starts || !results.audio.maxRms || results.consoleErrors.length) throw Error('Web audio or console validation failed');
  } finally {
    fs.writeFileSync(path.join(output,'console.json'), JSON.stringify(logs,null,2));
    fs.writeFileSync(path.join(output,'results.json'), JSON.stringify(results,null,2));
    console.log(JSON.stringify({results,logs}));
    await page.screenshot({path:path.join(output, 'last.png')});
    await browser.close();
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    if(frameServer) {
      frameServer.closeAllConnections();
      await new Promise(resolve => frameServer.close(resolve));
    }
  }
})().catch(e => {console.error(e); process.exitCode=1;});
