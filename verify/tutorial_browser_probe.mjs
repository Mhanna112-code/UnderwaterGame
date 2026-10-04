// Disposable profile: actual recovered checkpoint, normal Load, swim to training.
import { chromium } from 'playwright';
import fs from 'node:fs';
import readline from 'node:readline';
import {execFileSync} from 'node:child_process';
const output = process.env.TUTORIAL_OUTPUT || '/tmp/tutorial-browser-probe';
fs.mkdirSync(output, { recursive: true });
const browser = await chromium.launch({args:['--use-gl=angle','--use-angle=metal','--ignore-gpu-blocklist']});
const page = await browser.newPage({viewport:{width:1004,height:847}});
const errors=[];
page.on('console', msg => {console.log('BROWSER|'+msg.text()); if(msg.type()==='error'||/SCRIPT ERROR:|Infinite loop detected/.test(msg.text())) errors.push(msg.text());});
page.on('pageerror', err => {errors.push(String(err));console.log('PAGEERROR|'+err);});
await page.goto(process.argv[2] || 'https://underwatergame-opening-prologue-review.vercel.app/');
await page.waitForTimeout(25000);
await page.mouse.click(502,455);
await page.waitForTimeout(3000); // New Game creates the real save directories.
// Seed only this disposable profile from a captured real completed opening.
const stored = JSON.parse(fs.readFileSync('docs/evidence/opening-prologue-real-combat/browser-axe-result.json')).saveRecheck.beforeReload[0];
await page.evaluate(async stored => {
  const db = await new Promise((resolve,reject) => {
    const req=indexedDB.open(stored.database); req.onsuccess=()=>resolve(req.result);req.onerror=()=>reject(req.error);
  });
  await new Promise((resolve,reject)=>{
    const tx=db.transaction('FILE_DATA','readwrite');
    tx.objectStore('FILE_DATA').put({timestamp:new Date(),mode:33206,contents:new TextEncoder().encode(JSON.stringify(stored.data))},stored.key);
    tx.oncomplete=resolve;tx.onerror=()=>reject(tx.error);
  });db.close();
},stored);
await page.reload(); await page.waitForTimeout(20000);
await page.screenshot({path:output+'/title.png'});
console.log('READY|'+output);
if(process.env.TUTORIAL_AUTOMATIC === '1') {
  await page.mouse.click(502,490);await page.waitForTimeout(700);
  await page.mouse.click(502,396);await page.waitForTimeout(2000);
  await page.keyboard.down('w');await page.waitForTimeout(2000);await page.keyboard.up('w');
  const sequence=['Electric Touch','Precise Tap','Crushing Haymaker','Weaken','Flash Blast'];
  let guided=0,victorySeen=false,victoryContinued=false,worldSeen=false;
  const steps=[];
  const deadline=Date.now()+240000;
  try {
    while(Date.now()<deadline&&!worldSeen) {
      const file=output+'/current.png';
      await page.screenshot({path:file,timeout:8000});
      const rows=JSON.parse(execFileSync('/tmp/underwater-screen-ocr',[file],{encoding:'utf8'}));
      const text=rows.map(r=>r.text).join('\n');
      const find=(label,minY=340)=>rows.find(r=>r.text===label&&r.y>minY);
      const click=async(row,kind)=>{steps.push({kind,label:row.text,x:row.x,y:row.y});console.log('INPUT|'+kind+'|'+row.text);await page.mouse.click(row.x,row.y);};
      if(text.includes('The enemies back off')) victorySeen=true;
      if(victoryContinued&&/WASD swim|SHIFT down/.test(text)) {worldSeen=true;break;}
      const continuation=find('Continue');
      if(continuation) {
        if(victorySeen){await page.screenshot({path:output+'/victory-continue.png'});victoryContinued=true;}
        await click(continuation,'continue');
      } else if(text.includes('Hover over')) {
        const target=find('Angler',550)||find('All enemies',550);
        if(target) {await page.mouse.move(900,400);await page.mouse.move(target.x,target.y);}
      } else if(text.includes('Click the highlighted')) {
        const target=find('All enemies',550)||find('Angler',550);
        if(target){await click(target,'guided-target');guided++;}
      } else if(text.includes('Choose the')&&text.includes('highlighted')) {
        const move=find(sequence[guided],500);
        if(move) await click(move,'guided-move');
      } else if(find('Attack')) {
        await click(find('Attack'),'attack');
      } else if(find('Guard Bash',500)||find('Precise Tap',500)||find('Electric Touch',500)) {
        await click(find('Guard Bash',500)||find('Precise Tap',500)||find('Electric Touch',500),'normal-move');
      } else if(find('Angler',550)||find('All enemies',550)) {
        await click(find('Angler',550)||find('All enemies',550),'normal-target');
      } else if(find('Next')||find('×')||find('x')) {
        await click(find('×')||find('x')||find('Next'),'onboarding');
      } else if(/Press Enter to continue|Press Space, Enter/.test(text)) {
        steps.push({kind:'keyboard-caption'});await page.keyboard.press('Enter');
      }
      await page.waitForTimeout(900);
    }
    if(!victorySeen||!victoryContinued||!worldSeen) throw new Error('OPEN-039 tutorial victory/Continue/world handoff timed out');
    await page.waitForTimeout(1500);
    await page.screenshot({path:output+'/returned-world.png'});
    const checkpoint=await page.evaluate(async stored=>{
      const db=await new Promise(resolve=>{const req=indexedDB.open(stored.database);req.onsuccess=()=>resolve(req.result);});
      const record=await new Promise(resolve=>{const req=db.transaction('FILE_DATA').objectStore('FILE_DATA').get(stored.key);req.onsuccess=()=>resolve(req.result);});
      db.close();return JSON.parse(new TextDecoder().decode(record.contents));
    },stored);
    if(!checkpoint.route_state.tutorial_complete||!checkpoint.route_state.prologue_complete) throw new Error('OPEN-039 real victory lost persisted milestones');
    if(errors.length) throw new Error('Browser runtime errors: '+errors.join('\n'));
    fs.writeFileSync(output+'/result.json',JSON.stringify({guided,victorySeen,victoryContinued,worldSeen,checkpoint,steps,errors},null,2));
    console.log('BROWSER TUTORIAL WIN: clean');
  } catch(error) {
    fs.writeFileSync(output+'/failure.json',JSON.stringify({guided,victorySeen,victoryContinued,worldSeen,steps,errors,failure:String(error)},null,2));
    throw error;
  } finally {await browser.close();}
  process.exit(0);
}
const lines=readline.createInterface({input:process.stdin});
for await (const line of lines) {
  const cmd=JSON.parse(line);
  if(cmd.click) await page.mouse.click(...cmd.click);
  if(cmd.move) await page.mouse.move(...cmd.move);
  if(cmd.key) await page.keyboard.press(cmd.key);
  if(cmd.hold){await page.keyboard.down(cmd.hold[0]);await page.waitForTimeout(cmd.hold[1]);await page.keyboard.up(cmd.hold[0]);}
  if(cmd.wait) await page.waitForTimeout(cmd.wait);
  if(cmd.shot) await page.screenshot({path:output+'/'+cmd.shot+'.png'});
  if(cmd.quit) break;
  console.log('DONE|'+line);
}
await browser.close();
