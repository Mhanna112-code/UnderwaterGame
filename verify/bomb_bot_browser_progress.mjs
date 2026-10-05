// BB-WEB-01/02/03: real rendered menus and input, no runtime state injection.
// Requires the native OCR helper also used by the maze feedback gate.
import { chromium } from 'playwright';
import fs from 'node:fs';
import path from 'node:path';
import http from 'node:http';
import { execFileSync } from 'node:child_process';

const target = process.argv[2];
if (!target) throw new Error('Pass a hosted build URL or exported build directory');
const live = target.startsWith('http');
const exportRoot = live ? null : path.resolve(target);
const mime = {'.html':'text/html','.js':'text/javascript','.wasm':'application/wasm','.json':'application/json'};
const server = live ? null : http.createServer((request,response)=>{
  const pathname = decodeURIComponent(new URL(request.url,'http://localhost').pathname);
  const file = path.resolve(exportRoot,'.'+(pathname==='/'?'/index.html':pathname));
  if (!file.startsWith(exportRoot+path.sep) || !fs.existsSync(file) || !fs.statSync(file).isFile()) {
    response.writeHead(404);response.end();return;
  }
  response.writeHead(200,{'Content-Type':mime[path.extname(file)]||'application/octet-stream'});
  fs.createReadStream(file).pipe(response);
});
if (server) await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const base = live ? target : `http://127.0.0.1:${server.address().port}/`;
const output = process.argv[3] || '/tmp/bomb-bot-browser-progress';
fs.mkdirSync(output, {recursive:true});
const backend = process.env.BROWSER_GPU || 'metal';
const options = {args:['--use-gl=angle', '--use-angle='+backend, '--ignore-gpu-blocklist']};
if (backend === 'swiftshader') options.args.push('--enable-unsafe-swiftshader');
if (process.env.BROWSER_CHANNEL) options.channel = process.env.BROWSER_CHANNEL;
const browser = await chromium.launch(options);
const context = await browser.newContext({viewport:{width:1280,height:720}});
const page = await context.newPage();
const errors=[], observations=[], actions=[];
let metadata=null, failure=null, won=false, returned=false;
page.on('pageerror', error=>errors.push(String(error)));
page.on('crash', ()=>errors.push('Browser page/renderer crashed'));
page.on('console', message=>{
  if(message.type()==='error'||/SCRIPT ERROR:|^ERROR:|Aborted\(|out of memory/i.test(message.text()))errors.push(message.text());
});
const observe = async name=>{
  const file=path.join(output,name+'.png');
  await page.screenshot({path:file,timeout:10000});
  const rows=JSON.parse(execFileSync(process.env.OCR_HELPER||'/tmp/underwater-screen-ocr',[file],{encoding:'utf8'}));
  const text=rows.map(row=>row.text).join('\n');
  observations.push({name,text});
  console.log('VIEW|'+name+'|'+text.replaceAll('\n',' | '));
  return {rows,text};
};
const click = async row=>{
  actions.push({text:row.text,x:row.x,y:row.y});
  await page.mouse.click(row.x,row.y);
  await page.mouse.move(1270,710);
};
const waitFor = async (predicate,name,seconds=35)=>{
  const start=Date.now();let current;
  do{
    current=await observe(name+'-'+Math.floor((Date.now()-start)/1000));
    if(predicate(current))return current;
    if(errors.length)throw new Error(errors.join('\n'));
    await page.waitForTimeout(1500);
  }while(Date.now()-start<seconds*1000);
  throw new Error('Timed out waiting for '+name);
};
try{
  try{const response=await fetch(new URL('build-info.json',base));if(response.ok)metadata=await response.json();}catch{}
  if(process.env.EXPECTED_SOURCE_SHA && metadata?.source_commit!==process.env.EXPECTED_SOURCE_SHA)throw new Error('Unexpected deployed source');
  const url=new URL(base);url.searchParams.set('blocker','bomb_bot');
  await page.goto(url.href,{waitUntil:'load',timeout:90000});
  await page.waitForTimeout(20000);
  const title=await waitFor(view=>view.rows.some(row=>/Bomb Bot/i.test(row.text)),'title');
  const entry=title.rows.find(row=>/Bomb Bot/i.test(row.text));
  await click(entry);
  await page.waitForTimeout(2000);
  let view=await waitFor(view=>/Bomb Bot/.test(view.text)&&/Attack/.test(view.text),'battle');
  if(process.env.NO_INPUT_CONTROL==='1'){
    await page.waitForTimeout(12000);
    await observe('no-input');
    throw new Error('BB-WEB-01: no-input control did not complete any actions or outcome');
  }
  const started=Date.now();
  while(Date.now()-started<180000){
    if(errors.length)throw new Error(errors.join('\n'));
    if(/powers down|path to Sword Slayer|WASD swim/.test(view.text)){
      returned=/TAB diver/.test(view.text)&&/Encounters/.test(view.text);won=true;break;
    }
    if(/enemies back off, beaten/i.test(view.text))won=true;
    if(/Game Over|party.*defeated|Restart from/i.test(view.text))throw new Error('Actual party loss; not a victory');
    const menuRows=view.rows.filter(row=>row.y>400);
    let chosen=menuRows.find(row=>/^Attack$/i.test(row.text.trim()));
    if(!chosen){
      const moves=['Electric Touch','Precise Tap','Guard Bash'];
      // Selected-move headings include a numeric result and are not buttons.
      chosen=menuRows.find(row=>moves.some(move=>row.text.trim()===move));
    }
    if(!chosen && /Back/.test(view.text)){
      // A move menu is handled above. The target menu has Back plus the
      // enemy button; the lower-panel cutoff excludes the enemy status card.
      chosen=menuRows.find(row=>/^Bomb Bot(?:\s|$)/i.test(row.text));
    }
    if(chosen)await click(chosen);
    await page.waitForTimeout(1200);
    view=await observe('action-'+String(actions.length).padStart(3,'0')+'-'+Math.floor((Date.now()-started)/1000));
  }
  if(!won||!returned)throw new Error('BB-WEB-01: real fight did not complete victory and World return');
  if(actions.length<5)throw new Error('Too few real menu actions to establish combat progress');
  // OCR/capture work can outlast the short attack log. An observed enemy
  // turn followed by actual loss from this full-health party is independent
  // outcome evidence; ambient animation alone satisfies neither condition.
  const namedAttack=observations.some(view=>/Bomb Bot uses/.test(view.text));
  const enemyTurn=observations.some(view=>/NOW\s*\nBomb Bot/.test(view.text));
  const partyHurt=observations.some(view=>!/^Victory/m.test(view.text)&&
    [...view.text.matchAll(/(\d+)\s*\/\s*10\b/g)].some(match=>Number(match[1])<10));
  if(!namedAttack&&!(enemyTurn&&partyHurt))throw new Error('No actual enemy attack or enemy-turn/party-damage outcome was observed');
  await page.keyboard.press('KeyR');await page.waitForTimeout(600);
  const world=await observe('world-input');
  if(!/TAB diver/.test(world.text)||!/Encounters/.test(world.text))throw new Error('Return did not restore exploration controls');
  if(errors.length)throw new Error(errors.join('\n'));
  console.log('BOMB BOT BROWSER PROGRESS: clean');
}catch(error){failure=String(error);console.error(failure);}
finally{
  fs.writeFileSync(path.join(output,'receipt.json'),JSON.stringify({target,metadata,browser:browser.version(),backend,channel:process.env.BROWSER_CHANNEL||'bundled-chromium',actions,observations,errors,won,returned,failure,scope:'diagnostic lab trigger; actual rendered menus/mouse input and fight outcome; not normal travel or maze second wave'},null,2));
  await context.close();await browser.close();
  if (server) await new Promise(resolve=>server.close(resolve));
}
if(failure)process.exit(1);
