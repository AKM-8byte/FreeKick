const {chromium} = require('playwright');
const fs = require('fs');
const path = require('path');
const http = require('http');
(async()=>{
  const mobile = process.argv.includes('--mobile');
  const tag = process.argv.find(a=>a.startsWith('--tag='))?.slice(6) || 'baseline';
  const base = path.resolve('build/web-qa');
  const out = path.resolve('test-output/performance'); fs.mkdirSync(out,{recursive:true});
  const types = {'.html':'text/html','.js':'application/javascript','.wasm':'application/wasm','.pck':'application/octet-stream','.png':'image/png'};
  const server=http.createServer((req,res)=>{
    const file=path.resolve(base,'.'+new URL(req.url,'http://localhost').pathname);
    if(!file.startsWith(base+path.sep)||!fs.existsSync(file)){res.writeHead(404);res.end();return;}
    res.setHeader('Content-Type',types[path.extname(file)]||'application/octet-stream');fs.createReadStream(file).pipe(res);
  });
  await new Promise(r=>server.listen(8070,'127.0.0.1',r));
  const browser=await chromium.launch({executablePath:'C:/Program Files/Google/Chrome/Application/chrome.exe',headless:true,args:['--enable-webgl','--ignore-gpu-blocklist','--disable-background-networking']});
  try {
    const page=await browser.newPage({viewport:mobile?{width:844,height:390}:{width:1440,height:900},isMobile:mobile,hasTouch:mobile});
    const logs=[];page.on('console',m=>logs.push({type:m.type(),text:m.text()}));page.on('pageerror',e=>logs.push({type:'pageerror',text:e.message}));
    const start=Date.now();await page.goto('http://127.0.0.1:8070/index.html');
    await page.waitForFunction(()=>!document.querySelector('#status')||getComputedStyle(document.querySelector('#status')).display==='none',null,{timeout:90000});
    const startupMs=Date.now()-start;
    const deadline=Date.now()+120000;
    while(!logs.some(m=>m.text.startsWith('PERFORMANCE_RESULT '))&&Date.now()<deadline)await page.waitForTimeout(500);
    const line=logs.find(m=>m.text.startsWith('PERFORMANCE_RESULT '));if(!line)throw Error('Performance probe timed out');
    const gpu=await page.evaluate(()=>{
      const gl=document.querySelector('canvas').getContext('webgl2');
      const ext=gl.getExtension('WEBGL_debug_renderer_info');
      return ext?gl.getParameter(ext.UNMASKED_RENDERER_WEBGL):gl.getParameter(gl.RENDERER);
    });
    const result={...JSON.parse(line.text.slice(19)),browser:await browser.version(),mobileEmulation:mobile,gpu,startupMs,consoleErrors:logs.filter(m=>['error','pageerror'].includes(m.type))};
    fs.writeFileSync(path.join(out,`web-${mobile?'mobile-emulated':'desktop'}-${tag}.json`),JSON.stringify(result,null,2));
    await page.screenshot({path:path.join(out,`web-${mobile?'mobile-emulated':'desktop'}-${tag}.png`)});
    console.log(JSON.stringify(result));if(result.consoleErrors.length)throw Error('Browser errors');
  } finally {await browser.close();server.closeAllConnections();await new Promise(r=>server.close(r));}
})().catch(e=>{console.error(e);process.exitCode=1});
