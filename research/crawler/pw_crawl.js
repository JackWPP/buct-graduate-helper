const { chromium } = require('/Users/jackwang/node_modules/playwright-core');
const fs=require('fs');
const PAGES = [
'/student/default/index','/student/default/home',
'/student/grgl/xsxx','/student/grgl/xyjc','/student/grgl/xsxqzc','/student/grgl/xsrxdj','/student/grgl/xslqfc','/student/grgl/grxxxg','/student/grgl/ccqjwh','/student/grgl/xjydsq','/student/grgl/djksbm','/student/grgl/djkscj','/student/grgl/zpxxhd','/student/wsks/wskscp',
'/student/pygl/pyfacx','/student/pygl/pyjhtj','/student/pygl/pyjhcx','/student/pygl/kcmxsq','/student/pygl/xswsxk','/student/pygl/xswsxk_kb','/student/pygl/xkjgcx','/student/pygl/xskbcx','/student/pygl/ttkcx','/student/pygl/kckccx','/student/pygl/xscjcx','/student/pygl/qxkczml','/student/pygl/cxhkbksq','/student/pygl/wsjxpj','/student/pygl/gjxsjlhd','/student/pygl/py_zysjwc',
'/student/yggl/xnjddj','/student/yggl/pypgsq','/student/yggl/knzzsq','/student/yggl/szgwsq','/student/yggl/xshdbm','/student/yggl/xwsxsq','/student/yggl/zyzfwbm','/student/yggl/tyydbm','/student/yggl/tyyd_mxsq',
'/student/bygl/xsfblwdj','/student/bygl/xskyxmdj','/student/bygl/xszlcgdj','/student/bygl/xshjcgdj','/student/pygl/lwktsq_edit','/student/pygl/xsktsq_edit','/student/pygl/zqkhsq','/student/pygl/xszqkhdj','/student/bygl/xsdbsq_edit','/student/bygl/lwpygl','/student/bygl/xsxwsq_edit','/student/grgl/zixun','/student/grgl/xssqxx'
];
(async()=>{
 const cookies=JSON.parse(fs.readFileSync('pw_stu_cookies.json','utf8'));
 const browser=await chromium.launch({headless:true, executablePath:'/Users/jackwang/Library/Caches/ms-playwright/chromium-1248/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing', args:['--no-sandbox']});
 const ctx=await browser.newContext({viewport:{width:1440,height:900}});
 await ctx.addCookies(cookies);
 const page=await ctx.newPage();
 const out=[];
 for (const path of PAGES){
   const reqs=[]; const respMap=new Map();
   const onReq = r=>{ const t=r.resourceType(); if(t==='xhr'||t==='fetch'){ reqs.push({method:r.method(),url:r.url(),postData:r.postData()||'',resourceType:t}); } };
   const onResp = async r=>{ const t=r.request().resourceType(); if(t==='xhr'||t==='fetch'){ let body=''; try{ body=(await r.text()).slice(0,800);}catch(e){body='<'+e.message+'>';} respMap.set(r.url()+'|'+(r.request().postData()||''), {status:r.status(), body}); } };
   page.on('request',onReq); page.on('response',onResp);
   let title='', status=0, err='';
   try{
     const resp=await page.goto('https://gmis.buct.edu.cn'+path,{waitUntil:'domcontentloaded',timeout:30000});
     status=resp?resp.status():0;
     await page.waitForTimeout(3500);
     title=await page.title();
   }catch(e){err=e.message.split('\n')[0];}
   page.off('request',onReq); page.off('response',onResp);
   const items=reqs.map(q=>({...q, response: respMap.get(q.url+'|'+q.postData)||null}));
   out.push({path,url:page.url(),status,title,error:err,requests:items});
   console.log('CRAWLED',path,status,title,items.length);
   fs.writeFileSync('crawl_log.json',JSON.stringify(out,null,2));
 }
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
