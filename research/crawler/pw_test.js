const { chromium } = require('/Users/jackwang/node_modules/playwright-core');
const fs=require('fs');
(async()=>{
 const cookies=JSON.parse(fs.readFileSync('pw_stu_cookies.json','utf8'));
 const browser=await chromium.launch({headless:true, executablePath:'/Users/jackwang/Library/Caches/ms-playwright/chromium-1248/chrome-mac-arm64/Google Chrome for Testing.app/Contents/MacOS/Google Chrome for Testing', args:['--no-sandbox']});
 const ctx=await browser.newContext({viewport:{width:1440,height:900}});
 await ctx.addCookies(cookies);
 const page=await ctx.newPage();
 await page.goto('https://gmis.buct.edu.cn/student/default/index',{waitUntil:'networkidle',timeout:30000});
 console.log('URL',page.url()); console.log('TITLE',await page.title());
 console.log((await page.textContent('body')).slice(0,300));
 await browser.close();
})().catch(e=>{console.error(e);process.exit(1)});
