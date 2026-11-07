# 抓取脚本与页面快照

早期用于分析 GMIS 登录页、页面 JS 和接口的浏览器脚本/HTML 快照。运行时代码不依赖这里。

文件包括 `pw_crawl.js`、`pw_key.js`、`pw_test.js`、`gmis.config.js`、`jsencrypt.min.js`、登录页 HTML 和 Playwright state 等。`pw_state.json`/`pw_stu_state.json` 可能包含浏览器本地状态，使用前请确认不含真实 Cookie 或账号信息。
