// BL-01 elementindex. Kor: node tools/bl01-elementindex.mjs <rot> <utfil utanfor repot>
// Renderar varje skarmfil och skriver ett index over alla produktelement. Skriver aldrig i repot.
// BL-01: index every product element in a tree by (frame, ordProd). Read-only, output outside repo.
import { spawn } from 'node:child_process';
import { readdirSync, writeFileSync, mkdtempSync, rmSync } from 'node:fs';
import { resolve, join } from 'node:path';
import { tmpdir } from 'node:os';
import { pathToFileURL } from 'node:url';
const [,, ROT, UT] = process.argv;
const { SCOPE_KOD, KEDJA_KOD } = await import(pathToFileURL(ROT + '/tools/conformance-scope.mjs').href);
const filer = readdirSync(ROT).filter(f => /^Butlery Skarmar.*\.dc\.html$/.test(f)).sort();
const port = 20100 + (process.pid % 300);
const profil = mkdtempSync(join(tmpdir(), 'bl01-'));
const chrome = spawn('C:/Program Files/Google/Chrome/Application/chrome.exe',
  ['--headless=new','--remote-debugging-port='+port,'--disable-gpu','--no-first-run',
   '--allow-file-access-from-files','--force-device-scale-factor=1','--user-data-dir='+profil,'about:blank'], { stdio:'ignore' });
const sleep = ms => new Promise(r => setTimeout(r, ms));
try {
  let ws; for (let i=0;i<80&&!ws;i++){ await sleep(250);
    try { ws = (await (await fetch('http://127.0.0.1:'+port+'/json/list')).json()).find(t=>t.type==='page').webSocketDebuggerUrl; } catch {} }
  if (!ws) throw new Error('chrome');
  const sock = new WebSocket(ws); await new Promise(r=>sock.addEventListener('open', r));
  let id=0; const pend=new Map();
  sock.addEventListener('message', e => { const m=JSON.parse(e.data); if(m.id&&pend.has(m.id)){pend.get(m.id)(m);pend.delete(m.id);} });
  const send=(method,params={})=>new Promise(r=>{const i=++id;pend.set(i,r);sock.send(JSON.stringify({id:i,method,params}));});
  await send('Page.enable'); await send('Runtime.enable');
  await send('Emulation.setDeviceMetricsOverride',{width:1400,height:1000,deviceScaleFactor:1,mobile:false});
  const ut=[];
  for (const f of filer) {
    await send('Page.navigate',{url:pathToFileURL(resolve(ROT,f)).href});
    await send('Runtime.evaluate',{expression:`(async()=>{ if(document.readyState!=='complete') await new Promise(r=>addEventListener('load',r,{once:true})); await document.fonts.ready; return 1 })()`,awaitPromise:true});
    await sleep(140);
    const r = await send('Runtime.evaluate',{returnByValue:true,expression:`(() => {
${SCOPE_KOD}
${KEDJA_KOD}
      const ut=[];
      for (const it of document.querySelectorAll('.sc-item')) {
        const produkt=[...it.querySelectorAll('*')].filter(el=>losScope(kedjaFor(el,it)).scope==='product');
        const ord=new Map(produkt.map((e,i)=>[e,i]));
        produkt.forEach((el,i)=>{
          const cs2=getComputedStyle(el);
          let own=''; for (const n of el.childNodes) if(n.nodeType===3) own+=n.textContent;
          const anc=[]; let p=el.parentElement; while(p&&p!==it){ if(ord.has(p)) anc.push(ord.get(p)); p=p.parentElement; }
          ut.push({art:it.id,ordProd:i,tag:el.tagName.toLowerCase(),
            occ:el.getAttribute('data-occurrence'), tpl:el.getAttribute('data-dc-tpl'),
            elId:el.id||null, style:el.getAttribute("style"), bgC:cs2.backgroundColor, fgC:cs2.color, bw:cs2.borderTopWidth, bc:cs2.borderTopColor, mh:cs2.minHeight, hh:cs2.height, fsz:cs2.fontSize, fwt:cs2.fontWeight, brad:cs2.borderTopLeftRadius, pad:cs2.padding, disp:cs2.display, cls:el.getAttribute("class"), role:el.getAttribute('data-a11y-role'), name:el.getAttribute('data-a11y-name'),
            comp:el.getAttribute('data-component'), hit:el.getAttribute('data-hit'),
            icon:el.getAttribute('data-icon'), graphic:el.getAttribute('data-graphic-role'),
            text:(el.textContent||'').replace(/[ \\t\\n\\r]+/g,' ').trim().slice(0,120),
            parentStyle:(el.parentElement&&el.parentElement.getAttribute)?el.parentElement.getAttribute("style"):null, inDecl:!!(el.parentElement&&el.parentElement.closest("[data-a11y-role]")&&it.contains(el.parentElement.closest("[data-a11y-role]"))), nDeclInside:el.querySelectorAll("[data-a11y-role]").length, own:own.replace(/[ \\t\\n\\r]+/g,' ').trim().slice(0,120), anc});
        });
      }
      return ut; })()`});
    const v=r.result&&r.result.result&&r.result.result.value;
    if(!Array.isArray(v)) throw new Error('harvest failed '+f);
    for(const x of v) ut.push({...x, fil:f});
  }
  sock.close(); writeFileSync(UT, JSON.stringify(ut));
  console.log('elements', ut.length, 'files', filer.length, 'anchored', ut.filter(x=>x.occ).length);
} finally { try{chrome.kill();}catch{} await sleep(300); try{rmSync(profil,{recursive:true,force:true});}catch{} }
