// SPELL-ANIM-07: exported files must deliver a real mouse-selected authored
// cast, not merely boot or show an injected native scene. Temporary kit is
// explicit; this does not establish earning, every browser clip or balance.
import {chromium} from 'playwright';
import fs from 'node:fs';
import http from 'node:http';
import path from 'node:path';
import {execFileSync} from 'node:child_process';
const target=process.argv[2],output=process.argv[3]||'/tmp/spell-animation-browser';
if(!target)throw Error('Pass an exported directory or hosted preview');
fs.mkdirSync(output,{recursive:true});
const live=target.startsWith('http'),directory=live?null:path.resolve(target);
const server=live?null:http.createServer((req,res)=>{
  const relative=new URL(req.url,'http://localhost').pathname;
  const file=path.resolve(directory,'.'+(relative==='/'?'/index.html':decodeURIComponent(relative)));
  if(!file.startsWith(directory+path.sep)||!fs.existsSync(file)){res.writeHead(404);return res.end();}
  res.setHeader('Content-Type',file.endsWith('.wasm')?'application/wasm':file.endsWith('.js')?'text/javascript':file.endsWith('.html')?'text/html':'application/octet-stream');
  fs.createReadStream(file).pipe(res);
});
if(server)await new Promise(resolve=>server.listen(0,'127.0.0.1',resolve));
const base=live?target:'http://127.0.0.1:'+server.address().port+'/';
const backend=process.env.BROWSER_GPU||(process.platform==='darwin'?'metal':'swiftshader');
const launch={args:['--use-gl=angle','--use-angle='+backend,'--ignore-gpu-blocklist']};
if(backend==='swiftshader')launch.args.push('--enable-unsafe-swiftshader');
if(process.env.BROWSER_CHANNEL)launch.channel=process.env.BROWSER_CHANNEL;
const browser=await chromium.launch(launch);
const context=await browser.newContext({viewport:{width:1280,height:720}});
const page=await context.newPage(),errors=[],observations=[];
let metadata=null,cast=false,failure=null;
page.on('pageerror',error=>errors.push(String(error)));
page.on('crash',()=>errors.push('Browser renderer crashed'));
page.on('console',message=>{if(message.type()==='error'||/SCRIPT ERROR:|^ERROR:/.test(message.text()))errors.push(message.text());});
const read=async name=>{
  const file=path.join(output,name+'.png');await page.screenshot({path:file});
  const rows=JSON.parse(execFileSync('/tmp/underwater-screen-ocr',[file],{encoding:'utf8'}));
  observations.push({name,text:rows.map(row=>row.text).join('\n')});
  console.log('SPELL WEB VIEW|'+name+'|'+rows.map(row=>row.text).join(' | '));return rows;
};
const click=async row=>{if(!row)throw Error('Missing visible review control');await page.mouse.click(row.x,row.y);await page.mouse.move(1270,710);await page.waitForTimeout(500);};
try{
  metadata=await(await fetch(new URL('build-info.json',base))).json();
  if(process.env.EXPECTED_SOURCE_SHA&&metadata.source_commit!==process.env.EXPECTED_SOURCE_SHA)throw Error('Unexpected source export');
  const url=new URL(base);url.searchParams.set('spell_playtest','1');
  await page.goto(url.href);await page.waitForTimeout(22000);
  let rows=await read('title');await click(rows.find(row=>/Play Spell Test/i.test(row.text)));
  rows=await read('world');if(rows.some(row=>/Encounters \(Off\)/i.test(row.text)))await page.keyboard.press('KeyR');
  await page.keyboard.down('KeyW');
  const deadline=Date.now()+60000;let count=0;
  do{await page.waitForTimeout(1500);rows=await read('approach-'+count++);if(errors.length)throw Error(errors.join('\n'));}while(!rows.some(row=>/^Attack$/i.test(row.text.trim()))&&Date.now()<deadline);
  await page.keyboard.up('KeyW');await click(rows.find(row=>/^Attack$/i.test(row.text.trim())));
  let selected=false;
  for(let index=0;index<8;index++){
    rows=await read('moves-'+index);const move=rows.find(row=>row.text.trim()==='Swift Strike'&&row.y>400);
    if(move){await click(move);selected=true;break;}
    await click(rows.find(row=>/Down/i.test(row.text)&&row.y>400));
  }
  if(!selected)throw Error('Delivered learned move inaccessible');
  rows=await read('targets');const enemy=rows.find(row=>row.y>400&&/^(Angler|Swordfish|Frilled Shark)/i.test(row.text));
  if(!enemy)throw Error('No real target');
  await page.mouse.click(enemy.x,enemy.y);await page.mouse.move(1270,710);
  for(const [name,delay]of [['cast-early',1100],['cast-impact',900],['cast-late',900]]){
    await page.waitForTimeout(delay);await page.screenshot({path:path.join(output,name+'.png')});
  }
  rows=await read('outcome');
  const impactRows=JSON.parse(execFileSync('/tmp/underwater-screen-ocr',[path.join(output,'cast-impact.png')],{encoding:'utf8'}));
  const resultText=[...rows,...impactRows].map(row=>row.text).join('\n');
  // A selected-move heading is already present BEFORE clicking its target.
  // It cannot establish resolution; require outcome plus actual O2 spend.
  cast=/burst of speed|enemies back off/i.test(resultText)&&/92\s*\/\s*100/.test(resultText);
  if(!cast||errors.length)throw Error('Real cast/result missing or browser errors: '+errors.join('\n'));
}catch(error){failure=String(error);console.error(failure);}
finally{
  await page.keyboard.up('KeyW').catch(()=>{});
  fs.writeFileSync(path.join(output,'receipt.json'),JSON.stringify({source_commit:metadata?.source_commit,cast,errors,failure,observations,scope:'actual exported kit, world encounter, mouse-selected Swift Strike and rendered early/impact/late frames; not all clips or earning'},null,2));
  await context.close();await browser.close();if(server)await new Promise(resolve=>server.close(resolve));
}
console.log('SPELL ANIMATION BROWSER: '+(failure?'failed':'clean'));process.exit(failure?1:0);
