# GMIS 功能-API 矩阵与移动端可行性评估

> 版本：v1.0（2026-10-30） · 作者：api-mapper（共享 task-2）
> 数据来源：`GMIS_API.md`、`API_INDEX.md`、`api_catalog.json`、`endpoint_catalog.json`、`crawl_log.json`、`pages_all/*.html`（49 页）、`demo_output/*.json`
> 统计口径：
> - **49 个页面** = 菜单中的 48 个业务页 + 通知公告页 `/student/grgl/tzgglist`（该页不在左侧菜单但存在独立页面）；登录页、首页 `/student/default/index|home`、咨询页、我的申请页属于**运行期入口页**，单列在 §1.1，不占用 49 页名额。
> - “核心 API”为页面 JS 实际调用 + 实测 XHR 去重后的主接口；完整 165 条见 `API_INDEX.md` / `api_catalog.json`。
> - **复杂度**：S（低，纯展示/1–2 个接口，0.5–1 天）/ M（中，多接口、筛选、分页或轻表单，1–3 天）/ L（高，验证码、上传、多步动态表单、富文本、Word/打印，3–8 天）。
> - **MVP 优先级**描述“是否值得投入独立原生体验”：P0 = MVP 必须深度适配；P1 = 上线后 4–6 周增强；P2 = 不单独做原生，WebView 兜底即可。按 PRD 4.2，所有 49 页在 MVP 都应有 WebView 入口，P2 不等于不可达。
> - **实现方式**：原生 / WebView 兜底（内嵌 GMIS 页面，桌面 UA + Cookie 注入 + 文件下载桥）/ 混合（原生列表/壳 + WebView 表单）/ 暂不做（仅保留链接或占位）。

---

## 1. 总览

### 1.1 模块分布与优先级汇总

| 产品模块 | 页面数 | 页面清单（简称） | P0 | P1 | P2 | 原生建议 | WebView 兜底 |
| --- | ---: | --- | ---: | ---: | ---: | --- | --- |
| 登录 / 首页（入口页，不计 49） | 4+ | 登录、退出、首页工作台、首页欢迎 | 3 | 1 | 0 | 登录、首页、退出 | 首页欢迎（可并入首页） |
| 个人管理 | 9 | xsxx、xyjc、xsxqzc、xsrxdj、xslqfc、grxxxg、ccqjwh、xjydsq、zpxxhd | 1 | 3 | 5 | xsxx、xyjc、xsxqzc | 其余 5 页 |
| 培养管理 | 8 | pyfacx、pyjhtj、pyjhcx、kcmxsq、qxkczml、wsjxpj、gjxsjlhd、py_zysjwc | 1 | 4 | 3 | pyjhcx | 其余 7 页 |
| 选课 | 3 | xswsxk、xswsxk_kb、xkjgcx | 1 | 1 | 1 | xswsxk_kb、xkjgcx | xswsxk（旧页） |
| 课表 | 2 | xskbcx、ttkcx | 2 | 0 | 0 | 两页均原生 | — |
| 成绩 | 1 | xscjcx | 1 | 0 | 0 | 原生 | — |
| 考试 | 4 | kckccx、cxhkbksq、djksbm、djkscj | 1 | 0 | 3 | kckccx | 其余 3 页 |
| 研工管理 | 9 | xnjddj、pypgsq、knzzsq、szgwsq、xshdbm、xwsxsq、zyzfwbm、tyydbm、tyyd_mxsq | 0 | 0 | 9 | — | 全部 9 页 |
| 科研管理 | 4 | xsfblwdj、xskyxmdj、xszlcgdj、xshjcgdj | 0 | 0 | 4 | — | 全部 4 页 |
| 毕业与学位 | 7 | lwktsq_edit、xsktsq_edit、zqkhsq、xszqkhdj、xsdbsq_edit、lwpygl、xsxwsq_edit | 0 | 0 | 7 | — | 全部 7 页 |
| 通知 | 1 | tzgglist | 1 | 0 | 0 | 原生列表 | 详情页 |
| 网上考试 | 1 | wskscp | 0 | 0 | 1 | — | 列表页 + 答题页系统浏览器 |
| **合计** | **49** | — | **8** | **8** | **33** | 约 15 页可原生/混合 | 约 34 页 WebView 兜底 |

### 1.2 关键结论（先看这里）

1. **“高频 20% 原生 + 低频 WebView 兜底”成立**：登录、首页、课表、选课、成绩、考试、通知、培养进度 8 个 P0 页面覆盖研究生 80% 日常使用频次；其余 33 页建议只做 WebView 入口，不投入原生表单。
2. **最复杂的不是页面数量，而是 4 类“协议型坑”**：RSA 动态公钥 + 两套验证码、会话 302、`text/html` 包裹 JSON、文件上传/Word 下载。建议把 GMIS 适配层做成独立 SDK（见 §17），否则每个页面都会重复踩坑。
3. **选课和课表是技术风险最高的 P0 功能**：选课有独立验证码、课程容量并发、选课时间窗口；课表依赖 HTML 片段解析和“学期首周”人工映射，接口不直接返回教学周。
4. **49 页中有 40+ 条接口未写入 `GMIS_API.md`**，且 7 个业务页面是独立弹窗/编辑页（未抓取）：`wsjxpj_pj`、`wskscp_ks`、`wskscp_wj`、`pypgsq_edit`、`szgwsq_edit`、`tyyd_mxsq_edit`、`xwsxsq_edit`。这些是后续 WebView/原生化的隐藏工作量。
5. **P2 页面中已有接口异常**：`xnjddj_load` 实测返回 HTML 错误页 `<title>列名 'zlsqh' 无效。</title>`；`kcmxsq_list` 抓取时出现 Protocol error。上线前需要与学校确认接口可用性，不能按“存在即稳定”排期。

---

## 2. 登录与首页（运行期入口页，不计入 49）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| E1 | 登录 | `/home/stulogin` | `GET /home/stulogin`（HTML，解析 `#pubkey`）<br>`GET /home/verificationcode?codetype=stucode`<br>`POST /home/stulogin_do` | 表单字段 `json`：`{UserId,Password(base64 RSA),VeriCode,url,city}` | 成功 `{"jg":"1","url":"student/default/index"}`；失败 `{"jg":"0","msg":"验证码错误"}` | L | 验证码：是（GIF 102×46）<br>上传：否<br>复杂表单：否<br>Word/打印：否 | P0 | 原生 | 每次 GET 登录页重新解析 RSA 公钥；硬编码旧公钥会 500 `InvalidCipherTextException: block incorrect`；验证码错误要整页重载换公钥。 |
| E2 | 退出 | `/home/logout?js=xs` | `GET /home/logout?js=xs` | `js=xs` | 302 到登录页 | S | — | P0 | 原生 | 退出后清本地 Cookie/缓存；不能只跳登录页。 |
| E3 | 首页工作台 | `/student/default/index`（兼容 `/student/default/home`） | `GET getxscardinfo`<br>`GET getxfwcqk?type=xfqk`<br>`GET getxsxyyj`<br>`POST index_position`<br>`POST gethomepagesw`<br>`POST getUnReadTzxx`<br>`POST getUnRemindTzxx`<br>`GET MenuleftInfo`<br>`GET bindterm` | `getUnReadTzxx`：`{"wdtz":"0","wdzx":0}`；其余 `{}` | `getxscardinfo:[{xh,xm,xsmc,zymc,xslb,dsxm,dsxm1-3,nj,dsinfo}]`；`getxfwcqk:[{title,wc,total,bfb}]`；`getxsxyyj:[{xyyjdm,xyyjmc,sfyj,yjjb,tsxx,jg,url}]`；`gethomepagesw` 流程卡片含 `data.sql1/sql2/shl` | M | — | P0 | 原生 | 首页信息聚合至少 9 个接口，建议并行请求 + 5 分钟本地缓存；`index_position` 决定宫格顺序；`MenuleftInfo` 同时作为服务页菜单源。 |
| E4 | 首页欢迎/引导 | `/student/default/home` | `POST getwelcomdata`<br>`GET checkIsFisrtLogin` | `{}` | `getwelcomdata={info,sys}` | S | — | P1 | 原生/WebView | 首次登录引导、系统公告；可并入首页弹层。 |

---

## 3. 个人管理（9 页）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | 个人基本信息 | `/student/grgl/xsxx` | `GET xsxx_jbxx`<br>`GET xsxx_byxw`<br>`POST xsxx_jcjl`<br>`GET xsxx_ktzq`<br>`POST xsxx_kylw`<br>`POST pyjhcxlist`<br>`GET xscjcx_list` | 均无业务参数（`{}`） | `xsxx_jbxx={jbxx:{xh,xm,passwd,zydm,xslb,nj,yxsh,rxrq,bdrq,xmpy,xbm,csrq,zjlx,sfzh},gzjl,jtcy,rxcj,xjyd}`；`xsxx_jcjl={pypg,jxj,cfxx}`；`xsxx_kylw={fblw,kycg,zlqk,zzjc,hjqk}`；`xsxx_ktzq={ktbg,zqkh}`；`pyjhcxlist={pyjh,info}`；成绩结构见 §7 | M | 复杂表单：否<br>导出：否 | P0 | 原生 | 7 个 Tab 聚合；`passwd` 是 MD5、`sfzh` 是身份证，展示必须脱敏；各 Tab 懒加载，失败只局部降级。 |
| 2 | 学业进程查看 | `/student/grgl/xyjc` | `GET getwelcomdata`<br>`GET getxyjcinfo` | `{}` | `getwelcomdata={info,sys}`；`getxyjcinfo={data:[{lcdm,mc,tqts,yjtqts,ywsm,ywqz,rw,sjsm,url,wcrq,bz}]}` | S | — | P1 | 原生 | 流程时间轴 + 待办任务；`url` 可深链到 GMIS 页面；`tqts/yjtqts` 是提前提醒天数，可接本地通知。 |
| 3 | 学期报到注册 | `/student/grgl/xsxqzc` | `POST bindXsZcXx`<br>`POST getzcxx`<br>`POST xszcaction` | `{}`（`xszcaction` 可能带状态） | `bindXsZcXx=[{termname,zcrq,zclxmc,shzt,shrq,shr}]`；`getzcxx={termname,zcsj,xdxq,dqzt,zcsm,ipdata}`；`xszcaction={sign,msg}` | S | — | P1 | 原生 | 一键报到；`dqzt` 为“已注册/未注册”；`ipdata` 是 IP 校验数据，说明不能代理换 IP；报到窗口外按钮禁用并提示。 |
| 4 | 新生入学登记 | `/student/grgl/xsrxdj` | `GET Dmwh_getZyByyxbh[xsbh]`<br>`GET getxxlrkz`<br>`POST getxxgzjl`<br>`POST getjtzcxx`<br>`POST savejtcy`<br>`POST savexxgzjl`<br>`POST deletejtzcry`<br>`POST deletexxgzjl`<br>`POST updatexjinfo`<br>`POST xsrxdjdy_new` | `xjson`/`json` 字符串、行主键、`editfield` | 字段控制 `[{zdmc,zddm,kjlx,yxxg,sfbt,...}]`；`getxxgzjl/getjtzcxx={rows}`；保存返回 `{zt}`/`true`；打印为二进制 | L | 复杂表单：是（35 个 input + 家庭/教育两张动态表）<br>打印：是 | P2 | WebView 兜底 | 仅新生入学季使用；原生复刻动态表格成本极高，WebView 最划算。 |
| 5 | 新生录取复查 | `/student/grgl/xslqfc` | `POST init_xslqfc`<br>`POST submit_xslqfc`<br>`POST xlrz_upload[json]`<br>`POST xwzs_upload[]` | 上传文件 + `json` 业务数据 | `init_xslqfc={shl,shjl}`；保存 `{sign/msg}` | M | 上传：是（录取/学位证书 2 个附件）<br>复杂表单：是 | P2 | WebView 兜底 | 附件必须走 multipart；WebView 需原生文件选择器/拍照桥接。 |
| 6 | 个人信息维护 | `/student/grgl/grxxxg` | `GET Dmwh_getZyByyxbh[xsbh]`<br>`POST ccqj_getzmdrop`<br>`GET getxxlrkz`<br>`POST xgxx[xjjsonstr,editfield]`<br>`POST grxxxg_uploadzp` | `xjjsonstr`（整表 JSON 字符串）、`editfield`；照片 multipart | `getxxlrkz=[{zdmc,zddm,kjlx,yxxg,sfbt,...}]`（字段级权限）；`xgxx` 成功返回文本 `true`；上传返回文件名/路径 | L | 上传：是（证件照）<br>复杂表单：是（157 个 input） | P2 | WebView 兜底 | 字段可编辑性完全由 `getxxlrkz` 的 `kjlx/yxxg/sfbt` 决定；原生复刻等于重写动态表单引擎，不建议。 |
| 7 | 乘车区间维护 | `/student/grgl/ccqjwh` | `POST ccqjwh_load`<br>`POST ccqjwh_save[ccqj]` | `ccqj` 为区间代码/文本 | `ccqjwh_load={info:[...],ccqj}`；保存 `{sign/msg}` | S | — | P2 | WebView 兜底 | 单下拉 + 保存；可后续低成本原生。 |
| 8 | 学籍异动申请 | `/student/grgl/xjydsq` | `GET xjydsqsjkz`<br>`POST getxjydlistbyxssq`<br>`POST deletexjyd[ids]`<br>JS：`addxjyd`、`editxjyd`、`xjydprint` | `ids` 支持批量；申请表单字段由 `xjydsqsjkz` 控制 | 控件列表 + `{rows}`；`xjydprint` 为打印页 | M | 打印：是<br>复杂表单：中 | P1 | 混合（原生列表 + WebView 编辑/打印） | `addxjyd/editxjyd` 是独立页面（未抓取），原生无法完整覆盖；列表原生、表单 WebView。 |
| 9 | 照片信息核对 | `/student/grgl/zpxxhd` | `POST grxxxg_uploadzp`<br>JS：`PotoImageShow`、`PotoImageShowjm` | 照片文件 + 学号 | 上传结果/`true` | M | 上传：是（拍照/相册）<br>复杂表单：否 | P2 | WebView 兜底 | 涉及人像采集，注意隐私授权；WebView 内 `<input type=file>` 需原生桥接。 |

---

## 4. 培养管理（8 页）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 10 | 培养方案查看 | `/student/pygl/pyfacx` | `GET bindpyfacx`<br>`POST pyfacxlist[xslbm,yxsh,zydm]`<br>JS：`pyfady_show?id=` | `xslbm` 学历、`yxsh` 院系、`zydm` 专业 | 绑定 `{xslbs,yxshs,zydms}`；列表 `{total,rows:[{xsmc,zydm,zymc,yjfxm,jwzydm,lylb,...}]}` | S | — | P1 | 原生 | 三筛选 + 表格；详情 `pyfady_show?id=` 是独立页，建议 WebView。 |
| 11 | 培养计划提交 | `/student/pygl/pyjhtj` | `GET pyjhtj_drop`<br>`POST pyjhtjlist[pyfx]`<br>`POST py_kclist[yxsh,kcbh]`<br>`POST py_pyjh_addkc[kcbh,pyfx]`<br>`POST py_pyjh_delkc[kcbh]`<br>`POST pyjhtj_save[json,dotype,pyfx,yjfx]` | `pyfx` 研究方向、`yxsh` 院系、`kcbh` 课程编号、`dotype=1` 提交（0 存草稿） | `pyjhtj_drop={yxlist,yjfxlist}`；`pyjhtjlist={pyfakc,info,pyhj}`；`py_kclist={total,rows:[{Row,kcbh,kcmc,kcywmc,...}]}`（实测 1822 门）；`py_pyjh_addkc={zt:"1"}`；`py_pyjh_delkc={sign:"1"}` | L | 复杂表单：是（动态加/删课程、方向选择）<br>打印：课程大纲下载 `jxdggl_down?kcbh=` | P1 | 混合（原生外壳 + WebView 编辑） | 核心难点：先选 `pyfx` 研究方向，再按培养方案加课；课程池 1822 门需分页/远程搜索；提交前校验学分（`info` 里 `xwxf/zxf/zgxf`）。 |
| 12 | 培养计划查询 | `/student/pygl/pyjhcx` | `POST pyjhcxlist`<br>JS 打印：`pyjhdy`、`pyjhdy_lzlg`、`pyjhdy_tjcj` | `{}`；打印前先 `POST {sfcheck:"1"}` 校验 | `{pyjh:[19 门],info:{xwk_count,fxwk_count,xwk_xf,fxwk_xf,xwxf:15,zxf:35,zgxf:44,shzt}}`；课程字段 `id,xh,kcbh,xwk,kclx,kcxf,xxxq,kcmc,kclbmc,kczxs,sfwc,cj` | S | Word/打印：是（3 类打印模板）<br>复杂表单：否 | P0 | 原生 | MVP“我的-培养进度”只读页；直接展示学分统计 + 已修/未修列表；打印跳 WebView。 |
| 13 | 课程免修申请 | `/student/pygl/kcmxsq` | `GET kcmxsq_list`<br>`POST kcmxsq_add[kcbh]`<br>`POST kcmxsq_edit[id,sqly,pycc,bh,mxcj,yycj]`<br>`POST kcmxsq_cancel`<br>`POST kcmxsq_qxsq[id]`<br>`POST kcmxsq_bindtj`<br>`POST kcmxsq_addimg`<br>`POST kcmxsq_delimg[filename]` | 课程编号、申请理由 `sqly`、培养层次 `pycc`、编号 `bh`、免修成绩 `mxcj`、英语成绩 `yycj`、附件名 | `kcmxsq_list={wsq,ysq,wjlj,dqxq,sqsj}`；保存 `{sign/msg}` | M | 上传：是（证明材料图片）<br>复杂表单：是（2 个 textarea + 附件列表） | P1 | 混合（列表原生 + 申请 WebView） | 附件目录 `wjlj` 由后端返回；上传/删除接口分离，原生实现要维护临时附件列表。 |
| 14 | 全校课程总目录 | `/student/pygl/qxkczml` | `GET qxkczml_down?type=bs`（博士）/ `type=ss`（硕士） | `type=bs` 博士 / `type=ss` 硕士 | Word 二进制流（`Content-Disposition`） | S | Word 下载：是 | P2 | WebView 兜底（下载桥） | 纯下载页；App 可改为“分享/用其他应用打开”，不占原生页面。 |
| 15 | 课程教学评价 | `/student/pygl/wsjxpj` | `POST wsjxpjlist`<br>JS：`wsjxpj_pj?bjid=&jsbh=` | `{}`；评价页参数 `bjid` 班级 id、`jsbh` 教师编号 | `[{termname,bjid,kcbh,bjmc,kcxf,kcmc,jsbh,jsxm,kssj,jssj,pjckcj,sfpj,yxpj}]`（实测 14 条） | M | 复杂表单：评价页未抓取，预计多题打分 | P1 | 混合（列表原生 + 评价 WebView） | `wsjxpj_pj` 是独立页（未进入 pages_all）；`sfpj` 是否已评、`pjckcj` 评价参考成绩；未评课程要在首页提醒。 |
| 16 | 国际学术交流申请 | `/student/pygl/gjxsjlhd` | `GET gjxsjlhd_load`<br>`POST gjxsjlhd_save[json,zt]`<br>`POST gjxsjlhdcltj_save[json,zt]`<br>JS：`getpy_gjxsjlhdinfo`、`getpy_gjxsjlhdcltjinfo` | `json` 申请 JSON、`zt` 状态（草稿/提交） | `{shl:{dqzt_shlxx...},...}`；保存 `{sign/msg}` | L | 上传：是（附件）<br>复杂表单：是（15 个 input） | P2 | WebView 兜底 | 含会议/活动信息、经费预算、附件；低频，原生收益低。 |
| 17 | 专业实践（科研/学习）外出审核 | `/student/pygl/py_zysjwc` | `GET zysjwc_load`<br>`POST zysjwc_save[json,zt]`<br>JS：`getpy_zysjwcinfo` | `json` 表单、`zt` 状态 | `{shl:{dqzt_shlxx...},...}`；保存 `{sign/msg}` | L | 上传：是（附件）<br>复杂表单：是（21 个 input） | P2 | WebView 兜底 | 含外出地点、起止时间、安全承诺、交通/住宿等；低频。 |

---

## 5. 选课（3 页）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 18 | 课程开课一览（旧版） | `/student/pygl/xswsxk` | `POST bindyxsh`<br>`POST xswsxk_all[yxsh,kcbh,page,rows]`<br>`POST xswsxk_dx`<br>`POST xswsxk_jhnxk`/`jhn_tx`/`jhw xk`/`jhw_tx` | `yxsh` 院系、`kcbh` 课程编号、`page/rows` | `{total:772,rows:[{RowNumber,kcbh,kcmc,xsmc,bjid,bjmc,dz,rkjsxm,kczxs,kcxf,ksz,jsz,sjms,rnrs,xkrs}]}`；`bindyxsh=[{xsbh,xsmc,selected}]` | M | — | P2 | WebView 兜底（不原生） | 旧版选课页仍有选/退按钮但无验证码，可能与现行 `xswsxk_kb` 冲突；仅作开课一览参考，不投入原生。 |
| 19 | 学生网上选课（现行） | `/student/pygl/xswsxk_kb` | `POST xswsxk_kb_load`<br>`POST xswsxk_kb_loadkb`<br>`POST xswsxk_kb_list[lb,xwk,zh,jc1,jc2,yxsh,kcbh,page,rows,type]`<br>`POST xswsxk_kb_xk[lb,bjid,xkyzm]`<br>`GET /home/verificationcode?codetype=xkyzm` | `lb`：1 公共/2 专业/3 全部；`xwk`：1 学位/0 非学位；`zh` 1–7；`jc1/jc2` 节次；`type` 1 全部/2 当前选课时间段；`lb`（提交）：1 选/0 退；`bjid` 班级 id；`xkyzm` 验证码 | `load={yx:[26 院系],jc:[12 节次]}`；`loadkb={rows:[{jcid,sjbz,mc,z1..z7}],zxf,xwxf,fxwxf}`（13 行，首行 jcid=40 无节次）；`list={kc:[...],total}`，字段 `kcbh,kcmc,xsmc,bjid,bjmc,dz,sfkx,rkjsxm,kczxs,kcxf,xwk,ksz,jsz,sjms,rnrs,xkrs,kkfs,xkfs,yxkc,cjs,selected`；提交 `{sign/msg}` | L | 验证码：是（`xkyzm`）<br>复杂表单：否<br>导出：否 | P0 | 原生（验证码手动输入） | 见 §16.1 关键字段与坑；`type=2` 在非选课时间返回空 `{kc:[]}`；`yxkc` 0 可选/1 已选/2 可退选；`xkfs=2` 才显示退选。 |
| 20 | 选课结果查询 | `/student/pygl/xkjgcx` | `POST bindterm`<br>`POST py_kbcx_yw[termcode]`<br>`POST dcexcel_yw` | `termcode` 学期（54 个，55=2026-2027 秋） | `bindterm=[{termcode,termname,...}]`；`py_kbcx_yw=[{Row,bjid,kcbh,bjmc,jdid,kcxf,kcmc,lxfs,ksz,jsz,sjms,skdz_zdy,dz,rkjsxm,xkrs,selected}]`（14 门）；`dcexcel_yw` Excel 二进制 | S | Excel 导出：是 | P1 | 原生 | 与课表共用 `py_kbcx_yw`；按学期切换，默认当前学期；导出走 WebView/系统分享。 |

---

## 6. 课表（2 页）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 21 | 学生课表查询 | `/student/pygl/xskbcx` | `POST py_kbcx_ew[kblx,termcode]`<br>Word：`POST dcword_kb`<br>打印：`GET doprint_kb?kblx=xs&termcode=` | `kblx="xs"`、`termcode` 学期 | `{rows:[{jcid,sjbz,mc,z1..z7}],week:"Friday"}`；单元格是 HTML 片段，如 `<br/>数值分析C1班东区[10-16周] 常延贞[科303]` | M | Word/打印：是 | P0 | 原生（解析 HTML 单元格） | `week` 是当前星期英文（Friday），不是教学周；需与 `py_kbcx_yw` 合并拿课程详情/周次；打印用 WebView iframe。 |
| 22 | 调课信息查询 | `/student/pygl/ttkcx` | `POST ttkcx_list` | `{}` | `[{Row,id,bjid,sqr,yksz,yjsz,yksxq,yjsxq,yksjc,yjsjc}]`（实测 1 条） | S | — | P0 | 原生 | 与“考试安排”一起放在“考试”Tab；空列表时显示“暂无调课”。 |

---

## 7. 成绩（1 页）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 23 | 课程成绩查询 | `/student/pygl/xscjcx` | `GET xscjcx_list`<br>`POST xscjcx_cjzylist`<br>`GET xscjcx_cjzydo[id,type]`<br>`POST dcword_cj` | `id` 成绩 id、`type` 1 转入/0 撤回；`xscjcx_cjzylist` 无参 | `xscjcx_list={xwklist,fxwklist,hjcjlist,xftj:[{xh,xwxf,fxwxf,zxf,yxxwxf,yxfxwxf,yxzxf,faxwxf,fazxf}],hjzxf}`；`xscjcx_cjzylist` 字段 `xh,kcbh,kcmc,kcxf,xwk,cj,cjdjmc,lrsj,sfzy,cjid`；`dcword_cj` Word 二进制 | M | Word/打印：是<br>学分转移：是 | P0 | 原生 | 见 §16.3 关键字段与坑；成绩可能为空（demo_output 即空），空态要友好；`sfzy` 表示是否已转学分。 |

---

## 8. 考试（4 页）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 24 | 课程考场查询 | `/student/pygl/kckccx` | `POST kckccx_list` | `{}` | `[{termname,kcbh,kcmc,dz,ksrs,ksrq,kssj,zwh}]`；实测空数组 | S | — | P0 | 原生 | 与调课一起做；`dz` 地点、`zwh` 座位号；空数据提示“暂未发布考场”。 |
| 25 | 重缓补考申请 | `/student/pygl/cxhkbksq` | `GET cxhkbksq_list`<br>`GET cxhkbksq_sqjl`<br>`POST cxbkbksq_bindkkbj`<br>`POST cxhkbksq_edit_save[json]`<br>`POST cxhkbksq_del[id]` | `json` 申请（课程、类型、原因）；`id` 记录 | `cxhkbksq_list={cxinfo:{gndm:"kccx",gnmc:"课程重修",kssj:"2026-08-31",jzsj:"2027-01-17",...},bkinfo,hkinfo,hk,bk,kyhk,kybk,kycx,cxshow,bkshow,hkshow}`；`cxhkbksq_sqjl={rows}` | L | 复杂表单：是（重修/缓考/缓考选课 3 类，8 个 input） | P2 | WebView 兜底 | 申请类型由 `cxinfo` 时间窗口控制；`sqlx` 1 重修/2 缓考/3 缓考选课；不同类型显示不同字段。 |
| 26 | 等级考试管理 | `/student/grgl/djksbm` | `GET djksbm_list`<br>`POST djksxxbm`<br>`GET getbmrecorder`<br>`POST canCelbmks`（参数 `bmid`）<br>`POST uploadkszp` | `bmid` 报名 id；报名表单 `txtdjdm/txtkmdm/txtkhh/txtyhkh`；照片文件 | `djksbm_list=[{bmid,id,djdm,djmc,bmksrq,bmjzrq,ksrq,kssj,kmdm,kmmc}]`（实测 2 项）；`getbmrecorder=[]`；报名/取消 `{sign,msg}` | M | 上传：是（照片）<br>复杂表单：是（报名信息弹窗） | P2 | WebView 兜底 | 仅等级考试季使用；注意 `canCelbmks` 参数是 `bmid`，不是 catalog 中的 `id`。 |
| 27 | 等级考试成绩 | `/student/grgl/djkscj` | `POST djkscjcx` | `{}` | `[{termname,kmdm,kmmc,djdm,djmc,bmrq,cj}]`；实测空数组 | S | — | P2 | WebView 兜底 | 纯列表；可与等级考试管理合并一个 WebView 入口。 |

---

## 9. 研工管理（9 页，全部 P2 / WebView）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 28 | 学年鉴定登记 | `/student/yggl/xnjddj` | `GET xnjddj_load`<br>`POST xnjddj_dcword` | `{}` | 实测返回 HTML 错误页 `<title>列名 'zlsqh' 无效。</title>`；正常应为学年鉴定表结构 | M | Word/打印：是 | P2 | WebView 兜底（先报障） | 接口当前异常，需学校修复；先放 WebView 入口并监控。 |
| 29 | 评优评干申请 | `/student/yggl/pypgsq` | `GET pypgsq_list`<br>`GET pypgsq_sqlist`<br>JS：`pypgsq_edit?id=` | `id` 申请 id | `pypgsq_list={total:11,rows:[{Row,xmdm,xmmc,kssj,...}]}`；`pypgsq_sqlist={rows}` | M | 复杂表单：申请编辑页未抓取 | P2 | WebView 兜底 | `pypgsq_edit?id=` 是独立页，未逆向；勿承诺原生。 |
| 30 | 困难资助申请 | `/student/yggl/knzzsq` | `JS：knzzsq_xsjbxx`<br>`POST knzzsq_jtcy_list[sqid]`<br>`POST knzzsq_plxzrdcy_list[sqid]`<br>JS：`knzzsq_addjtcy`、`knzzsq_addplxzrdcy`、`knzzsq_deletejtcy`、`kbzz_sq_objadd` | `sqid` 申请 id；家庭成员/评议小组动态行 | `knzzsq_xsjbxx={xj:[{xh,xm,xmpy,nj,xb,...}]}`；两张表 `[]`；保存 `{sign/msg}` | L | 复杂表单：是（家庭成员 + 评议小组动态表，9 个 input） | P2 | WebView 兜底 | 动态行增删是主要复杂度；原生复刻性价比低。 |
| 31 | 三助岗位申请 | `/student/yggl/szgwsq` | `POST szgwsq_bindszlb`<br>`GET szgwsq_list[gwlb]`<br>`POST szgwsq_save[json,zt]`<br>`GET szgwsq_sqlist`<br>JS：`szgwsq_delete`、`szgwsq_repeal`、`szgwsq_edit?id=` | `gwlb` 岗位类别；`json` 申请；`zt` 状态 | `bindszlb=[{dm,dmmc,selected}]`（4 类）；`szgwsq_list/sql list={rows}` | M | 复杂表单：中（6 个 input） | P2 | WebView 兜底 | 有撤回/删除操作；编辑页独立未抓取。 |
| 32 | 学术报告申请 | `/student/yggl/xshdbm` | `GET xshdbm_cklist`<br>`POST xshdbm_sqlist`<br>`GET xshdbm_sfkysq[id]`<br>`POST xshdbm_bm[id,VeriCode]`<br>`POST xshdbm_del[hdid]`<br>`POST printword` | `id` 活动/报名 id、`VeriCode` 验证码、`hdid` 活动 id | `{rows:[...]}`；报名 `{sign,msg}`；`printword` 为打印页 | M | 验证码：是<br>Word/打印：是 | P2 | WebView 兜底 | 验证码是页面内 `VeriCode`，不是 `stucode/xkyzm`；先查 `sfkysq` 再报名。 |
| 33 | 校外实习申请 | `/student/yggl/xwsxsq` | `POST xwsxsq_list`<br>`POST xwsxsq_del[id,ids]`<br>JS：`xwsxsq_edit?id=` | `id/ids` 记录 | `[]`（实测空）；正常 `{rows}` | M | 复杂表单：编辑页未抓取 | P2 | WebView 兜底 | 列表字段 `xh,xm,xsmc,zymc,wcsy,dwmc,dwlxr,dwlxfs,shlmc,xg`；申请编辑页独立。 |
| 34 | 劳动实践申请 | `/student/yggl/zyzfwbm` | `POST getldsjzsc`<br>`POST zyzfwbm_cklist`<br>`POST zyzfwbm_sqlist`<br>`POST xshdbm_bm[id,VeriCode]`<br>`POST ldsjbm_del[hdid]`<br>`POST ldsjhz_print`<br>JS：`show_ewm_yl`、`zyzfwbmck?id=`、`zyzfyjytj?id=` | `id` 活动、`VeriCode` 验证码、`hdid` | `getldsjzsc={zt,hdzsc}`；列表 `{rows}`；报名 `{sign,msg}`；打印/二维码页面 | M | 验证码：是<br>打印/二维码：是 | P2 | WebView 兜底 | 先取活动时间窗 `getldsjzsc`；报名后二维码签到/打印，WebView 内需下载桥。 |
| 35 | 体育活动申请 | `/student/yggl/tyydbm` | `POST gettyydzsc_tyyd`<br>`POST tyydbm_cklist`<br>`POST tyydbm_sqlist`<br>`POST xshdbm_bm[id,VeriCode]`<br>`POST tyydbm_del[hdid]`<br>`POST tyydhz_print`<br>JS：`show_ewm_yl_tyyd`、`tyydbmck?id=`、`tyydfyjytj?id=` | `id` 活动、`VeriCode`、`hdid` | `gettyydzsc_tyyd={zt,hdzsc}`；`{rows}`；报名 `{sign,msg}`；二维码/打印 | M | 验证码：是<br>打印/二维码：是 | P2 | WebView 兜底 | 与劳动实践同构；可抽公共“活动报名 WebView 模板”。 |
| 36 | 体育运动免修申请 | `/student/yggl/tyyd_mxsq` | `POST tyyd_mxsq_list`<br>`POST tyyd_mxsq_del[id,ids]`<br>JS：`tyyd_mxsq_edit?id=` | `id/ids` | `[]`（实测空）；正常 `{rows}` | M | 复杂表单：编辑页未抓取 | P2 | WebView 兜底 | 列表字段 `termname,xh,xm,xsmc,zymc,sfty,shlmc,xg`；编辑页独立。 |

---

## 10. 科研管理（4 页，全部 P2 / WebView）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 37 | 发表论文登记 | `/student/bygl/xsfblwdj` | `POST xwlwdjlist`<br>`POST worddy`<br>`POST xs_dclwcg`<br>`POST zqkh_cxtj[json]`<br>JS：`checkwordmb`、`delxsfblwdjByid`、`biaoji` | `json` 论文信息；导出条件 | 列表字段 `ck,lwmc,zlwlx,kwmc,cn,dyzz,dspm,fblbmc,slqkmc,shlmc`；`worddy` Word、`xs_dclwcg` Excel | M | Word/Excel：是<br>复杂表单：弹窗表单 | P2 | WebView 兜底 | 论文题录 + 导出模板；`checkwordmb` 查重模板、`biaoji` 标记为未文档化接口。 |
| 38 | 其他创新性成果登记 | `/student/bygl/xskyxmdj` | `POST xskyxmdj_list`<br>`POST xskyxmdj_save[datajson]`<br>`POST xs_dckyxm`<br>JS：`xskyxmdj_model`、`deletekyxmbyid` | `datajson` 成果 JSON | 列表 `[{ck,xmmc,hprq,pm,ktjb,wcr,bz,shlmc}]`；保存 `{sign/msg}` | M | Excel：是<br>复杂表单：弹窗（8 input） | P2 | WebView 兜底 | 项目/竞赛类成果；`datajson` 是整对象字符串。 |
| 39 | 专利情况登记 | `/student/bygl/xszlcgdj` | `POST zlcglist`<br>`POST savezlcgdjinfo[datajson]`<br>`POST xs_dczlcg`<br>JS：`getzlcgmodel`、`deletezlcgbyid` | `datajson` 专利 JSON | 列表 `[{ck,zlmc,zlztmc,zllxmc,qsfmr,dspm,pm,zlh,zsh,zlsqr,sqny,shzt}]`；保存 `{sign/msg}` | M | Excel：是<br>复杂表单：弹窗（12 input） | P2 | WebView 兜底 | 专利号/授权号/申请年月等字段多，校验规则未知。 |
| 40 | 科研成果奖励登记 | `/student/bygl/xshjcgdj` | `POST hjqklist`<br>`POST savehjcgdjinfo[datajson]`<br>`POST xs_hjcgdj`<br>JS：`gethjcgmodel`、`deletehjcgbyid` | `datajson` 奖励 JSON | 列表 `[{ck,jlmc,jljbmc,jldjmc,jllbmc,hjjs,dspm,zsh,hjrq,bjdw,shlmc}]`；保存 `{sign/msg}` | M | Excel：是<br>复杂表单：弹窗（10 input） | P2 | WebView 兜底 | 与上两页同构，可共用“科研登记 WebView 模板”。 |

---

## 11. 毕业与学位（7 页，全部 P2 / WebView）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 41 | 开题报告申请 | `/student/pygl/lwktsq_edit` | `GET lwktsq_edit_load[id]`<br>`POST lwktsq_edit_save[json,zt]` | `id` 申请 id；`zt` 草稿/提交 | `{shl:{dqzt_shlxx...},...}`；保存 `{sign/msg}` | M | 复杂表单：中（3 个 input）<br>Word/打印：否 | P2 | WebView 兜底 | 开题题目/类型/来源/时间/地点/专家组；提交后进入审核流。 |
| 42 | 提交开题报告 | `/student/pygl/xsktsq_edit` | `GET xsktsq_edit_load[id]`<br>`GET xsktsq_edit_checkwj[wjmc]`<br>`POST xsktsq_edit_save[json,zt]`<br>`GET/POST xsktsq_edit_jdlist/jdsave/jddel`<br>`GET/POST xsktsq_edit_zjlist/zjsave/zjdel`<br>`POST xsktsq_print`<br>JS：`xsktsq_ecsq` | `id` 申请；`wjmc` 文件名；`json` 开题记录/专家/附件 | `{shl,ktjl,ktcj,sftkktsq,info}`；三层动态表格 `id,zjxm,zjzc,zjxk,zjyj` / `qzsj,jdmc,jdnr` | L | 上传：是（附件 `hjfj`）<br>Word/打印：是<br>复杂表单：是（23 个 input + 3 层动态表） | P2 | WebView 兜底 | 最复杂的毕业页；原生复刻成本 > 3 周，不建议。 |
| 43 | 中期报告申请 | `/student/pygl/zqkhsq` | 无（纯前端占位） | — | `alert('开题未满5个月，无法申请中期！')` | S | — | P2 | 暂不做（保留入口） | 前端占位页，后端条件判断；实际申请可能在“提交中期报告”页。 |
| 44 | 提交中期报告 | `/student/pygl/xszqkhdj` | `GET zqkhdj_load`<br>`POST zqkhdj_save[json,zt]`<br>`POST dcword_zq`<br>JS：UEditor `ue1.getContent()` | `json` 中期报告（富文本 HTML）、`zt` | `{shl:{dqzt_shlxx...},...}`；保存 `{sign/msg}`；`dcword_zq` Word | L | 上传：是（附件）<br>Word：是<br>复杂表单：是（10 input + UEditor 富文本） | P2 | WebView 兜底 | 富文本编辑器 UEditor 无法在原生简单复刻；必须 WebView。 |
| 45 | 硕士查重盲审申请 | `/student/bygl/xsdbsq_edit` | 无（纯前端占位） | — | `alert('中期未满5个月，无法申请答辩！')` | S | — | P2 | 暂不做（保留入口） | 占位页；实际申请入口在 `lwpygl`。 |
| 46 | 查重盲审论文提交 | `/student/bygl/lwpygl` | `GET xsdbsq_edit_load`<br>`POST getlwccsqbyxh`<br>`POST lwcsdatalist`<br>`POST lwpygl_bs_getmsmdxx[pcdm]`<br>`POST lwpygl_savelwxx[json,sfcc,zt]`<br>`POST lwpygl_savemslw[json,sfcc,zt]`<br>`POST lwpygl_sslwsc`<br>`POST sslwsh_list`<br>`POST zjpsjglist`<br>`POST zpb_down`<br>JS：`CreatePdf`、`downlwccbg?id=`、`sslwjgck?id=`、`sclwxz` | `pcdm` 批次、`json` 论文信息、`sfcc` 是否查重、`zt` 状态、附件 | 列表字段 `pcmc,lwtm,lwlx,bcsj,lwccjg,shzt...`；`sclwxz={cclw,mslw,sslw}`（查重/盲审/送审材料）；下载为 PDF/ZIP | L | 上传：是（论文 Word/PDF、附件）<br>PDF/ZIP：是<br>复杂表单：是（26 个 input） | P2 | WebView 兜底 | 论文批次 + 查重/盲审/送审全流程；文件大，WebView 需下载/上传桥 + 断点续传提示。 |
| 47 | 学生学位申请 | `/student/bygl/xsxwsq_edit` | `GET bindbypc`<br>`GET xsxwsq_edit_load`<br>`POST xsxwsq_edit_save[json,zt,yxlwshtl,dbid,yjfx,zwzy,cxd1..cxd5]`<br>`POST xsxwsq_edit_sqtj`<br>`POST xsxwsq_edit_dy`<br>`POST scxwlw_down` | `json` 学位申请、`zt`、`yxlwshtl`（已修论文数）、`dbid`、`yjfx`、`zwzy`、`cxd1..cxd5` | 39 字段申请表；`file_doc`/`file_pdf` 附件；`xsxwsq_edit_dy` 打印版 | L | 上传：是（Word/PDF）<br>打印：是<br>复杂表单：是 | P2 | WebView 兜底 | 学位申请是毕业季核心，但只在最后 1 个月用；WebView + 打印桥足够。 |

---

## 12. 通知（1 页）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 48 | 通知公告 | `/student/grgl/tzgglist` | `POST tzgg_list[ksrq,jsrq,bt,page,rows]`<br>`POST getUnReadTzxx`<br>`POST getUnRemindTzxx`<br>JS：`/default/updateTzstate`、`/student/grgl/tzggview` | `ksrq` 开始日期、`jsrq` 结束日期、`bt` 标题、`page/rows` | `{total,rows:[{id,zbt,fbrq,fbr,fbdw,isReaded}]}`；实测 `total:0`；详情页 `tzggview` 未抓取 | S | — | P0 | 原生列表 + WebView 详情 | 列表原生成本低；详情页是独立 ASP.NET 页，建议 WebView；`updateTzstate` 标记已读。 |

---

## 13. 网上考试（1 页）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 49 | 网上考试测评 | `/student/wsks/wskscp` | `GET wskscp_load`<br>`GET wskscp_list`<br>JS：`wskscp_ks?sjid=`、`wskscp_wj?sjid=` | `sjid` 试卷 id；`tkjindex` 0/1 机考、2/3 文考 | `wskscp_load={sj1..sj4}`，字段 `sjid,tkjid,tikuid,tkmc,sjmc,sjms,sjlx,kssj,jssj,dtsj,sjzf,tgfs,xsw,dcks,ckdj,sfyx`；`wskscp_list=[{sjmc,recid,sjid,tkmc,tkjmc,ksys,kksj,kscj,kstg,selected}]`（实测 1 条） | M | — | P2 | WebView（列表）+ 系统浏览器（答题） | 真正答题页 `wskscp_ks`/`wskscp_wj` 未抓取，无法评估；考试环境可能有防切屏/摄像头要求，原生壳不应接管，直接系统浏览器打开。 |

---

## 14. 其他运行期页面（不计入 49，但 App 信息架构需要）

| # | 页面/功能 | 页面路径 | 核心 API（方法） | 关键参数 | 返回数据形态 | 复杂度 | 验证码/上传/复杂表单/导出打印 | MVP | 实现方式 | 备注 |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| X1 | 咨询/导师消息 | `/student/grgl/zixun` | `GET zixun_load`<br>`GET zixun_loadnr` | `{}` | `zixun_load={ds,yxms,yjsy}`；`zixun_loadnr={rows,xh}` | M | — | P1 | 原生 | 咨询/消息类功能；若只是单机留言，原生价值高；需确认是否有新消息轮询。 |
| X2 | 我的申请 | `/student/grgl/xssqxx` | `GET getxssqshowinfo`<br>`GET getxssqinfo` | `{}` | `getxssqshowinfo=[{xm,xh,xslb,dsxm,...,xsmc,zymc,nj,rxrq,bdrq,ybyrq}]`；`getxssqinfo=[{dm,mc,url,shlbz:[{shljb,shlmc,shlzt,shsj}],bz,shlcount}]` | M | — | P1 | 原生 | 我的申请聚合了 `zc/pyjh/xyjxj/gjjxj/knzz` 等流程；用 `url` 深链各业务页；`shlbz` 显示审核进度。 |
| X3 | 通知详情 | `/student/grgl/tzggview?id=` | 页面直出 HTML | `id` 通知 id | HTML | S | — | P0 | WebView | 未纳入 `pages_all`，按通知列表 `id` 打开；WebView 需保留登录 Cookie。 |

---

## 15. 原生 / WebView 选择清单

### 15.1 建议原生实现（P0/P1）

| 页面 | 理由 | 备注 |
| --- | --- | --- |
| 登录 / 退出 | 安全与体验入口，必须自己控制 RSA 与 Cookie | 验证码 GIF 可直接渲染 |
| 首页工作台 | 高频聚合、多接口并行、可缓存 | 9 个接口并行 + 缓存 |
| 个人基本信息（xsxx） | 7 Tab 只读，适合原生 | 隐私字段脱敏 |
| 学业进程（xyjc） | 时间轴 + 待办，原生体验明显优于 WebView | `url` 深链 |
| 学期报到（xsxqzc） | 单一动作，原生按钮体验好 | IP 校验 |
| 培养方案（pyfacx） | 三筛选 + 列表 | 详情 `pyfady_show` WebView |
| 培养计划查询（pyjhcx） | 学分统计卡片 + 课程列表 | 只读 |
| 选课（xswsxk_kb） | 核心高频，验证码可手动输入 | 见 §16.1 |
| 选课结果（xkjgcx） | 与课表共用数据 | Excel 导出走 WebView |
| 课表（xskbcx） | 核心高频，周/日视图 + ICS | 见 §16.2 |
| 调课 / 考场（ttkcx、kckccx） | 简单列表，合并为“考试”Tab | — |
| 成绩（xscjcx） | 学分统计 + 成绩列表 | 见 §16.3 |
| 通知列表（tzgglist） | 高频，列表原生 + 详情 WebView | 未读数 |
| 我的申请（xssqxx） | 状态聚合，适合卡片列表 | P1 |
| 咨询（zixun） | 消息类，原生体验好 | P1 |

### 15.2 只能用 WebView（或原生壳 + WebView）

| 页面/页面组 | 原因 |
| --- | --- |
| 个人信息维护 `grxxxg`、新生入学登记 `xsrxdj`、录取复查 `xslqfc`、照片核对 `zpxxhd` | 字段级权限、动态表单、照片/附件上传；原生复刻成本高 |
| 学籍异动 `xjydsq`、培养计划提交 `pyjhtj`、课程免修 `kcmxsq`、教学评价 `wsjxpj` | 列表可原生，编辑/申请表单必须 WebView（`addxjyd`/`editxjyd`、`pyjhtj` 动态课程、`kcmxsq_addimg`、`wsjxpj_pj` 均未抓取） |
| 旧选课 `xswsxk` | 旧版逻辑与现行选课冲突，仅保留 WebView 入口 |
| 课程总目录 `qxkczml` | Word 下载页 |
| 重缓补考 `cxhkbksq` | 三类申请、时间窗、动态字段 |
| 国际交流 `gjxsjlhd`、专业实践 `py_zysjwc` | 15/21 字段 + 附件 |
| 研工 9 页 | 低频、动态家庭成员/评议小组、报名验证码、打印/二维码 |
| 科研 4 页 | easyui 弹窗表单 + Excel 导出，原生收益低 |
| 毕业与学位 7 页 | 附件、UEditor 富文本、PDF/ZIP、打印，原生不可行 |
| 网上考试 `wskscp` 及答题页 | 答题页未逆向，可能要求摄像头/防切屏；系统浏览器最稳 |

### 15.3 暂不做（仅保留入口/占位）

- `zqkhsq`（中期报告申请）：当前是前端 `alert` 占位页，无接口。
- `xsdbsq_edit`（硕士查重盲审申请）：当前是前端 `alert` 占位页，无接口。
- `wskscp_ks`/`wskscp_wj` 实际答题页：未抓取、无法评估，建议直接系统浏览器打开。

---

## 16. 关键字段与坑（选课 / 课表 / 成绩 / 培养计划）

### 16.1 选课（`xswsxk_kb`）

| 接口 | 方法 | 关键字段/参数 | 说明 |
| --- | --- | --- | --- |
| `xswsxk_kb_load` | POST | `yx:[{xsbh,xsmc,selected}]`、`jc:[{id,mc,btime,etime}]` | 26 个院系、12 个节次；`selected` 可用于默认院系 |
| `xswsxk_kb_loadkb` | POST | `rows:[{jcid,sjbz,mc,z1..z7}]`、`zxf,xwxf,fxwxf` | 13 行周课表格；首行 `jcid=40` 无节次，需跳过；单元格格式为双竖线前缀 + `##课程班名[周次] 教师[地点]` |
| `xswsxk_kb_list` | POST | `lb`（1 公共/2 专业/3 全部）、`xwk`（1 学位/0 非学位）、`zh`（1–7）、`jc1/jc2`、`yxsh`、`kcbh`、`page/rows`、`type`（1 全部/2 当前选课时间段） | 实测 `total=265`；`type=2` 仅当前窗口 12 门；`{kc:[...],total}` 而不是 `{rows:...}` |
| `xswsxk_kb_xk` | POST | `lb`（1 选/0 退）、`bjid`、`xkyzm` | 退选也走同一接口；`xkyzm` 必须与图片一致 |
| `GET /home/verificationcode?codetype=xkyzm` | GET | `codetype=xkyzm` | GIF 验证码；每次点击选课刷新；与登录验证码 `stucode` 完全独立 |

**坑**：验证码区域 `#spxkyzm` 默认隐藏，只有点击“选课”才显示，App 要在选课动作前调用验证码接口并弹窗；`type=2` 在非选课时间返回 `{kc:[]}`，不要当接口失败；`yxkc=0` 可选、`1` 已选、`2` 可退选；`xkfs=2` 才显示退选；课程容量 `xkrs/rnrs` 只在刷新时更新；课程列表 `bjid` 是选课主键，不是 `kcbh`；旧版 `xswsxk_all` 有 772 条课程且无验证码，**不要用旧页提交**。

### 16.2 课表（`xskbcx`）

| 接口 | 方法 | 关键字段 | 说明 |
| --- | --- | --- | --- |
| `py_kbcx_ew` | POST | `kblx="xs"`、`termcode`；返回 `rows:[{jcid,sjbz,mc,z1..z7}]`、`week` | `week` 是当前星期英文（如 `Friday`），不是教学周；`z1..z7` 是 HTML 片段 |
| `py_kbcx_yw` | POST | `termcode`；返回已选课程 `[{Row,bjid,kcbh,bjmc,jdid,kcxf,kcmc,lxfs,ksz,jsz,sjms,skdz_zdy,dz,rkjsxm,xkrs,selected}]` | 课程详情、周次、节次的权威来源 |
| `dcword_kb` | POST | `termcode`/`kblx` | Word 导出（二进制） |
| `doprint_kb` | GET | `kblx=xs&termcode=` | 打印页（iframe） |

**坑**：`week` 不是教学周，用 `py_kbcx_yw.ksz/jsz` 计算第几周；`term_start` 接口不返回，需按学期配置（55=2026-08-31，20 周）；单元格 HTML 内可能有多门课、多个地点/教师、单双周标记，建议正则拆 `<br/>` 再按 `[周次]` 提取 `ksz-jsz`，解析失败保留原文；`sjms` 是中文自然语言（如“星期一 下午6-下午9”“星期二 上午1-上午2,星期四 下午6-下午7”），按逗号分段解析星期与节次；`lxfs` 连续周/单周/双周分别生成 ICS RRULE；每门课每个时间段一个 VEVENT，`DTSTART = term_start + weekday + (ksz-1)*7 + 节次开始时间`；打印/Word 导出需要 Cookie，WebView 里用 form action 提交可能被拦截，建议下载桥 + 系统分享。

### 16.3 成绩（`xscjcx`）

| 接口 | 方法 | 关键字段 | 说明 |
| --- | --- | --- | --- |
| `xscjcx_list` | GET | `xwklist`（学位课）、`fxwklist`（非学位课）、`hjcjlist`（合级）、`xftj:[{xh,xwxf,fxwxf,zxf,yxxwxf,yxfxwxf,yxzxf,faxwxf,fazxf}]`、`hjzxf` | 成绩可能为空（demo 即空），需空态；`cjdjmc` 是等级成绩，优先于 `cj` |
| `xscjcx_cjzylist` | POST | `xh,kcbh,kcmc,kcxf,xwk,cj,cjdjmc,lrsj,sfzy,cjid` | 学分转移候选（其他学号课程） |
| `xscjcx_cjzydo` | GET | `id`（成绩 id）、`type`（1 转入/0 撤回） | 返回 `{sign,msg}`；会影响学分统计，操作需二次确认 |
| `dcword_cj` | POST | 无参 | Word 成绩单（二进制） |

**坑**：`xscjcx_list` 无参一次返回全部学期，按 `termname` 分组不要假设分页；`cj` 可能是数字或等级，展示 `cjdjmc || cj`；`xftj` 字段多，直接显示后端口径不要自己重算；成绩转移会改变学籍成绩归属，必须提示并可撤回；`dcword_cj` 是 Word 二进制，移动端只下载/分享。

### 16.4 培养计划（`pyjhtj` / `pyjhcx`）

| 接口 | 方法 | 关键字段 | 说明 |
| --- | --- | --- | --- |
| `pyjhtj_drop` | GET | `yxlist`、`yjfxlist` | 院系 + 研究方向下拉 |
| `pyjhtjlist` | POST | `pyfx` 研究方向；返回 `{pyfakc,info,pyhj}` | `pyfakc` 方案课程、`pyhj` 已选课程 |
| `py_kclist` | POST | `yxsh,kcbh`；返回 `{total:1822,rows:[{Row,kcbh,kcmc,kcywmc,...}]}` | 课程池 1822 门，必须远程搜索/分页 |
| `py_pyjh_addkc` | POST | `kcbh,pyfx` | 成功 `{zt:"1"}` |
| `py_pyjh_delkc` | POST | `kcbh` | 成功 `{sign:"1"}` |
| `pyjhtj_save` | POST | `json`（计划课程 JSON 字符串）、`dotype`（1 提交/0 草稿）、`pyfx`、`yjfx` | 提交前校验学分/课程类别 |
| `pyjhcxlist` | POST | `{}`；返回 `{pyjh:[19 门],info:{xwk_count,fxwk_count,xwk_xf,fxwk_xf,xwxf:15,zxf:35,zgxf:44,shzt}}` | 查询页直接展示学分统计与课程列表 |

**坑**：必须先选研究方向 `pyfx`，否则 `pyjhtjlist` 返回空/报错；`pyjhtj_drop` 的 `yjfxlist` 是方向字典；课程池 1822 门一次拉取过大，按 `yxsh/kcbh` 远程过滤；`py_pyjh_addkc` 只返回 `{zt:"1"}` 不代表最终提交成功，提交 `pyjhtj_save` 前重新拉 `pyjhtjlist` 校验；`pyjhcxlist` 的 `info.shzt` 不为 `0` 时才允许打印培养计划；`pyjhtj_save` 的 `json` 是字符串不是对象，原生拼 JSON 要避免重复转义；培养计划查询有 `pyjhdy`、`pyjhdy_lzlg`、`pyjhdy_tjcj` 三个打印模板，MVP 只做 WebView 打印。

---

## 17. 技术风险与缺口

### 17.1 会话与登录

| 风险 | 具体表现（证据） | 影响 | 对策 |
| --- | --- | --- | --- |
| **会话过期 302** | 任意业务接口闲置后返回 302 到 `/home/stulogin`；也有接口 200 返回登录页 HTML | 页面空白/数据错乱 | 全局 HTTP 拦截器：检查 3xx `Location` + 响应体是否含登录页标题；清 Cookie、跳登录页、登录成功后回跳原页面；并发请求只触发一次重登 |
| **RSA 动态公钥** | 每次 `GET /home/stulogin` 的 `input#pubkey` 都变；硬编码旧公钥会 500 `InvalidCipherTextException: block incorrect` | 登录必失败 | 每次登录重新 GET 登录页解析 `#pubkey`；密码用 RSA PKCS#1 v1.5 加密后 base64；失败重载页面换公钥 |
| **Cookie 组合** | `ASP.NET_SessionId` + `__SINDEXCOOKIE__` 两个 Cookie；302 过程中可能 Set-Cookie | 会话丢失 | 使用 CookieJar 持久化，两个都保存；WebView 与原生共享同一 CookieStore；退出时全部清除 |
| **验证码错误换会话** | 登录验证码错误后公钥/会话可能变化 | 连续登录失败 | 验证码错误时重新加载登录页 + 新验证码，不重用旧公钥 |
| **UA/IP 绑定** | `getzcxx.ipdata`、学校可能有 IP 限制 | 换网络/代理后失败 | 固定同一 UA；避免后台高频轮询；提示用户使用校园网/VPN |

### 17.2 两套/三套验证码

| 验证码 | 接口 | 用途 | 注意 |
| --- | --- | --- | --- |
| 登录验证码 | `GET /home/verificationcode?codetype=stucode`（GIF 102×46） | 登录 | 4 位数字；与 RSA 公钥同页面刷新 |
| 选课验证码 | `GET /home/verificationcode?codetype=xkyzm` | 选课/退选 | 独立 `codetype`；每次选课动作前刷新；不能复用登录验证码 |
| 活动报名验证码 | 页面字段 `VeriCode`（`xshdbm_bm` 等） | 研工活动报名 | 不是 `codetype` 参数，需从活动页面/接口获取；扫码报名流程可能另有验证码 |

**风险**：识别/自动填验证码会触发风控；MVP 必须人工输入，不做 OCR。

### 17.3 接口协议与解析

| 风险 | 具体表现 | 对策 |
| --- | --- | --- |
| **返回 `text/html` 但内容是 JSON** | 所有业务接口 `Content-Type: text/html; charset=utf-8`，body 是 JSON；按 MIME 解析会失败 | 统一 `response.text` + `json.loads`；失败再尝试 HTML 清洗；不要用 `response.json()` |
| **响应形态不统一** | 裸数组、`{rows,total}`、`{kc,total}`、`{data:[...]}`、`{zt:"1"}`、`{sign:"1"}`、文本 `true`、空字符串 | 每个接口写 adapter（`to_list`/`to_rows`/`to_bool`）；不要假设字段名 |
| **GET/POST 标注冲突** | `xshdbm_cklist`、`xshdbm_sqlist`、`tyydbm_cklist`、`zyzfwbm_cklist`、`getldsjzsc` 在 `GMIS_API.md` 与 `api_catalog.json` 中方法不一致 | 以页面 JS 实际调用为准；适配层允许 GET/POST 回退（同一路径先 GET，失败再 POST） |
| **HTML 错误页伪装成功** | `xnjddj_load` 返回 `<title>列名 'zlsqh' 无效。</title>`；部分接口异常时返回 HTML 错误页 | 响应体以 `<` 开头时按 HTML 错误处理，提取 `<title>` 文案，上报监控 |
| **空数据** | `kckccx_list`、`wsjxpjlist`（部分）、`notices`、`pypgsq_sqlist` 等实测空数组 | 空态与错误态分离；不要用 `if not data` 统一报错 |
| **分页不统一** | `xswsxk_all`/`xswsxk_kb_list` 服务端 `page/rows`；`py_kclist` 返回 total 1822；`tzgg_list` 有 page/rows；很多列表返回全量数组无分页 | 适配层定义 `PagedResult`；全量接口前端分页/虚拟列表；服务端接口透传 page/rows |
| **编码** | 中文 UTF-8；部分接口 `charset=utf-8` 但头部缺失 | 固定 `response.encoding = "utf-8"`；非法字符用 `errors="replace"` |

### 17.4 文件上传

| 端点 | 用途 | 方式/字段 |
| --- | --- | --- |
| `grxxxg_uploadzp` | 个人信息照片 | multipart，字段名 `file`/`zp`（按页面实现）；返回文件名 |
| `uploadkszp` | 等级考试报名照片 | multipart，可能带 `xh` |
| `xlrz_upload`、`xwzs_upload` | 录取复查附件 | multipart + `json` 业务字段 |
| `kcmxsq_addimg`、`kcmxsq_delimg` | 课程免修证明材料 | 多文件上传/按文件名删除 |
| `lwpygl_sslwsc` | 论文送审材料 | multipart；大文件 |
| `xsxwsq_edit_save` 内嵌 `file_doc`/`file_pdf` | 学位申请 Word/PDF | easyui-filebox 随表单提交，可能是 multipart 而非 JSON |
| `xsktsq_edit_save` 内嵌 `hjfj` | 开题报告附件 | 同上 |
| `xszqkhdj` 文件框 | 中期报告附件 | 同上 |
| `gjxsjlhd`、`py_zysjwc` 的 filebox | 交流/实践附件 | 同上 |

**风险**：Android/iOS 文件选择器、拍照、PDF 预览、上传进度、大小限制（未知）、文件名中文、Cookie 鉴权；WebView 内 `<input type=file>` 在 Android 需 `onShowFileChooser`，iOS 需 `UIDocumentPicker`。**建议**：原生实现一个上传桥，统一处理 `multipart/form-data`，不要依赖 WebView 默认。

### 17.5 Word/导出/打印

| 页面/功能 | 端点 | 形态 | 处理 |
| --- | --- | --- | --- |
| 成绩单 | `POST dcword_cj` | Word 二进制 | 下载到本地 → 系统分享/Office 打开 |
| 课表 | `POST dcword_kb` / `GET doprint_kb?kblx=xs&termcode=` | Word / 打印页 | 下载桥 + `window.print` 或系统浏览器 |
| 选课结果 | `POST dcexcel_yw` | Excel | 下载/分享 |
| 培养计划 | `pyjhdy`、`pyjhdy_lzlg`、`pyjhdy_tjcj` | 打印页/Word | WebView 打开展示/打印 |
| 学籍异动 | `xjydprint` | 打印页 | WebView |
| 开题/中期/学位 | `xsktsq_print`、`dcword_zq`、`xsxwsq_edit_dy` | 打印页/Word | WebView |
| 研工 | `xnjddj_dcword`、`printword`、`ldsjhz_print`、`tyydhz_print` | Word/打印 | WebView + 下载桥 |
| 科研 | `worddy`、`xs_dclwcg`、`xs_dckyxm`、`xs_dczlcg`、`xs_hjcgdj` | Word/Excel | 下载/分享 |
| 课程总目录 | `qxkczml_down?type=bs`（博士）/ `type=ss`（硕士） | Word | 下载/分享 |

**风险**：返回文件名可能带中文/特殊字符；`Content-Disposition` 不标准；打印页依赖 iframe/浏览器；iOS 无法直接保存到文件系统。**建议**：原生实现 `DownloadManager`，统一保存到 App 沙盒 + 分享面板；WebView 拦截 `blob:`/`data:`/下载链接。

### 17.6 未文档化接口与页面缺口

| 类型 | 清单 | 影响 |
| --- | --- | --- |
| 页面 JS 中发现但 `GMIS_API.md` 未收录的接口（40+） | `lwpygl`: `getlwxxinfo`、`sclwxz`、`lwpygl_bs_lwzsrlr`、`lwpygl_sfshowsslw`、`lwpys_xsyl`、`isExitsCcbg`、`CreatePdf`、`downlwccbg`、`sslwjgck`；`xsfblwdj`: `checkwordmb`、`delxsfblwdjByid`、`biaoji`；`xshjcgdj`: `deletehjcgbyid`、`gethjcgmodel`；`xskyxmdj`: `deletekyxmbyid`、`xskyxmdj_model`；`xszlcgdj`: `deletezlcgbyid`、`getzlcgmodel`；`xjydsq`: `addxjyd`、`editxjyd`、`xjydprint`；`tzgglist`: `/default/updateTzstate`；`pyjhcx`: `pyjhdy`、`pyjhdy_lzlg`、`pyjhdy_tjcj`；`pyfacx`: `pyfady_show?id=`；`pyjhtj`: `jxdggl_down?kcbh=`；`py_zysjwc`: `getpy_zysjwcinfo`；`gjxsjlhd`: `getpy_gjxsjlhdinfo`、`getpy_gjxsjlhdcltjinfo`；`xsktsq_edit`: `xsktsq_ecsq`；`wsjxpj`: `wsjxpj_pj?bjid=&jsbh=`；`wskscp`: `wskscp_ks?sjid=`、`wskscp_wj?sjid=`；`knzzsq`: `kbzz_sq_objadd`、`knzzsq_addjtcy`、`knzzsq_addplxzrdcy`、`knzzsq_deletejtcy`、`knzzsq_xsjbxx`；`szgwsq`: `szgwsq_delete`、`szgwsq_repeal`、`szgwsq_edit?id=`；`pypgsq`: `pypgsq_edit?id=`；`tyyd_mxsq`: `tyyd_mxsq_edit?id=`；`xwsxsq`: `xwsxsq_edit?id=`；`tyydbm`: `show_ewm_yl_tyyd`、`tyydbmck?id=`、`tyydfyjytj?id=`；`xshdbm`: `xshdbmck?id=`、`xshdxdtj?id=`；`zyzfwbm`: `show_ewm_yl`、`zyzfwbmck?id=`、`zyzfyjytj?id=` | 原生/WebView 都可能遇到 404 或参数不符；需要按页面 JS 重放验证；P2 页面不要承诺“完全覆盖” |
| 未抓取的独立页面（7 个） | `wsjxpj_pj?bjid=&jsbh=`、`wskscp_ks?sjid=`、`wskscp_wj?sjid=`、`pypgsq_edit?id=`、`szgwsq_edit?id=`、`tyyd_mxsq_edit?id=`、`xwsxsq_edit?id=`；另有 `addxjyd`/`editxjyd` 页面 | 这是“49 页”之外的真实工作量；WebView 可用但无法做原生；上线前需补抓 |
| 前端占位页 | `zqkhsq`、`xsdbsq_edit` 只有 `alert()`，无实际接口 | 列入“暂不做”，不要当功能缺口 |
| 接口异常 | `xnjddj_load` 报 `列名 'zlsqh' 无效`；`kcmxsq_list` 抓取 Protocol error | 需向学校反馈/等待修复；上线前做健康检查 |
| 文档与实测不一致 | `canCelbmks` 参数 `bmid` vs `id`；`xswsxk_kb_list` 返回 `{kc,total}` vs 文档 `{rows,total}`；多接口 GET/POST 不一致 | 以页面 JS + 实测为准，适配层保留双实现 |

### 17.7 其他风险

| 风险 | 说明 | 对策 |
| --- | --- | --- |
| **课程时间解析** | `sjms` 为中文自然语言，可能有多段、单双周、地点变更；`term_start` 不在接口中 | 维护学期-首周配置表；解析失败保留原文；ICS 生成单测覆盖 15 个 VEVENT |
| **接口限流/IP** | 学校可能按 IP/账号限流，App 用户量大时风险高 | 请求节流、缓存优先、避免后台轮询；错误提示“请稍后再试” |
| **WebView 兼容** | GMIS 是 PC 页面（大量 easyui/iframe/固定宽度） | 强制桌面 UA、viewport 缩放、允许 mixedContent；准备“在浏览器打开”降级 |
| **第三方依赖** | jQuery/easyui/UEditor | WebView 内置浏览器需支持 ES5/jQuery；UEditor 上传依赖 `/ueditor/controller.ashx` |
| **安全合规** | 学号/身份证/成绩/照片等敏感数据 | 本地加密存储、日志脱敏、隐私政策、等保/学校授权；禁止把 Cookie 上传第三方 |
| **应用商店审核** | 非官方校园工具可能被要求授权/下架 | 提前准备学校授权函、隐私政策；TestFlight/企业分发过渡 |
| **GMIS 改版** | 页面/接口可能随学校升级变化 | 适配层远程配置 + 接口监控 + WebView 兜底；版本号/健康检查 |

---

## 18. 建议的 MVP 功能集（P0）及依赖接口清单

### 18.1 P0 功能与接口

| 模块 | P0 功能 | 依赖接口（方法） | 说明 |
| --- | --- | --- | --- |
| 登录 | 学号/密码/验证码登录、退出、会话续期 | `GET /home/stulogin`（解析 `#pubkey`）<br>`GET /home/verificationcode?codetype=stucode`<br>`POST /home/stulogin_do`<br>`GET /home/logout?js=xs` | RSA 动态公钥 + Cookie 持久化；302 统一重登 |
| 首页 | 工作台：学生卡片、学费、流程、待办、未读通知 | `GET getxscardinfo`<br>`GET getxfwcqk?type=xfqk`<br>`GET getxsxyyj`<br>`POST index_position`<br>`POST gethomepagesw`<br>`POST getUnReadTzxx`<br>`POST getUnRemindTzxx`<br>`GET MenuleftInfo`<br>`GET bindterm` | 并行请求 + 5 分钟缓存；`MenuleftInfo` 驱动服务宫格 |
| 课表 | 周/日课表、课程详情、周次切换、ICS 导出、提醒 | `POST bindterm`<br>`POST py_kbcx_ew`<br>`POST py_kbcx_yw`<br>`POST xswsxk_kb_load`（节次时间） | 解析 HTML 单元格；`term_start` 按学期配置；ICS 15 VEVENT 已验证 |
| 选课 | 选课首页（公告/筛选/列表）、课程详情、已选/退选、验证码 | `POST xswsxk_kb_load`<br>`POST xswsxk_kb_loadkb`<br>`POST xswsxk_kb_list`<br>`POST xswsxk_kb_xk`<br>`GET /home/verificationcode?codetype=xkyzm` | 验证码手动输入；`type=2` 时间窗；`bjid` 为提交主键 |
| 成绩 | 成绩列表、学分统计、成绩转移 | `GET xscjcx_list`<br>`POST xscjcx_cjzylist`<br>`GET xscjcx_cjzydo` | 空态；`cjdjmc` 优先；`xftj` 直接展示 |
| 考试 | 考场安排、调课信息 | `POST kckccx_list`<br>`POST ttkcx_list` | 合并为“考试”Tab；空态提示 |
| 通知 | 通知列表、详情、未读数 | `POST tzgg_list`<br>`POST getUnReadTzxx`<br>`POST getUnRemindTzxx`<br>`GET /student/grgl/tzggview?id=` | 列表原生；详情 WebView；`updateTzstate` 已读 |
| 我的 | 个人资料、培养进度、设置 | `GET xsxx_jbxx`<br>`POST pyjhcxlist`<br>`GET getxyjcinfo`<br>`GET getxssqinfo` | 只读；敏感字段脱敏；`pyjhcxlist` 学分统计 |
| 服务 | 全部服务宫格 + 搜索 + 49 页 WebView 兜底 | `GET MenuleftInfo` + 全部页面 URL | 桌面 UA + Cookie 注入 + 文件下载桥；每个页面都可打开 |
| 基础设施 | GMIS 适配层、Cookie/重登、错误监控、远程配置 | 全部 | 见 §17；建议独立 SDK，页面只调用领域方法 |

### 18.2 P0 明确不做（防止范围膨胀）

- 不做验证码 OCR/自动识别。
- 不做 49 页的原生复刻；P2 页面只做 WebView 入口。
- 不做 Word/Excel 的原生解析/编辑，只做下载/分享。
- 不做离线写入/本地选课缓存提交；写操作必须实时校验。
- 不做账号密码云同步/多设备共享（仅本地加密存储）。

### 18.3 P1 建议范围（上线后 4–6 周）

| 页面/功能 | 依赖接口 | 实现方式 |
| --- | --- | --- |
| 我的申请 | `getxssqshowinfo`、`getxssqinfo` | 原生卡片列表；`url` 深链 |
| 培养计划查看/提交 | `pyjhtj_drop`、`pyjhtjlist`、`py_kclist`、`py_pyjh_addkc`、`py_pyjh_delkc`、`pyjhtj_save`、`pyjhcxlist` | 原生壳 + WebView 编辑 |
| 培养方案查看 | `bindpyfacx`、`pyfacxlist`、`pyfady_show` | 原生列表 + WebView 详情 |
| 教学评价 | `wsjxpjlist`、`wsjxpj_pj` | 原生列表 + WebView 评价 |
| 课程免修 | `kcmxsq_list`、`kcmxsq_add`、`kcmxsq_edit`、`kcmxsq_cancel`、`kcmxsq_qxsq`、`kcmxsq_addimg`、`kcmxsq_delimg` | 原生列表 + WebView 申请 |
| 学籍异动 | `xjydsqsjkz`、`getxjydlistbyxssq`、`deletexjyd`、`addxjyd`、`editxjyd`、`xjydprint` | 原生列表 + WebView 编辑/打印 |
| 学期报到 | `bindXsZcXx`、`getzcxx`、`xszcaction` | 原生 |
| 选课结果 | `bindterm`、`py_kbcx_yw`、`dcexcel_yw` | 原生 |
| 咨询 | `zixun_load`、`zixun_loadnr` | 原生（若为消息类） |

### 18.4 P2 建议范围（后续版本 / 纯 WebView）

- **研工管理 9 页**：`xnjddj`、`pypgsq`、`knzzsq`、`szgwsq`、`xshdbm`、`xwsxsq`、`zyzfwbm`、`tyydbm`、`tyyd_mxsq`。全部 WebView，优先修复 `xnjddj_load` 错误。
- **科研管理 4 页**：`xsfblwdj`、`xskyxmdj`、`xszlcgdj`、`xshjcgdj`。全部 WebView，共用弹窗模板。
- **毕业与学位 7 页**：`lwktsq_edit`、`xsktsq_edit`、`zqkhsq`（暂不做）、`xszqkhdj`、`xsdbsq_edit`（暂不做）、`lwpygl`、`xsxwsq_edit`。全部 WebView；毕业季前验证。
- **网上考试**：`wskscp` 列表 WebView，答题页系统浏览器。
- **其他低频**：`xsrxdj`、`xslqfc`、`grxxxg`、`ccqjwh`、`zpxxhd`、`djksbm`、`djkscj`、`cxhkbksq`、`xswsxk`、`qxkczml`、`gjxsjlhd`、`py_zysjwc`。全部 WebView 兜底。

---

## 19. 49 页核对清单（防漏）

| 模块 | 页面数 | 页面路径 |
| --- | ---: | --- |
| 个人管理 | 9 | `/student/grgl/xsxx`、`/student/grgl/xyjc`、`/student/grgl/xsxqzc`、`/student/grgl/xsrxdj`、`/student/grgl/xslqfc`、`/student/grgl/grxxxg`、`/student/grgl/ccqjwh`、`/student/grgl/xjydsq`、`/student/grgl/zpxxhd` |
| 考试（原个人管理） | 4 | `/student/grgl/djksbm`、`/student/grgl/djkscj`、`/student/pygl/kckccx`、`/student/pygl/cxhkbksq` |
| 培养管理 | 8 | `/student/pygl/pyfacx`、`/student/pygl/pyjhtj`、`/student/pygl/pyjhcx`、`/student/pygl/kcmxsq`、`/student/pygl/qxkczml`、`/student/pygl/wsjxpj`、`/student/pygl/gjxsjlhd`、`/student/pygl/py_zysjwc` |
| 选课 | 3 | `/student/pygl/xswsxk`、`/student/pygl/xswsxk_kb`、`/student/pygl/xkjgcx` |
| 课表 | 2 | `/student/pygl/xskbcx`、`/student/pygl/ttkcx` |
| 成绩 | 1 | `/student/pygl/xscjcx` |
| 研工管理 | 9 | `/student/yggl/xnjddj`、`/student/yggl/pypgsq`、`/student/yggl/knzzsq`、`/student/yggl/szgwsq`、`/student/yggl/xshdbm`、`/student/yggl/xwsxsq`、`/student/yggl/zyzfwbm`、`/student/yggl/tyydbm`、`/student/yggl/tyyd_mxsq` |
| 科研管理 | 4 | `/student/bygl/xsfblwdj`、`/student/bygl/xskyxmdj`、`/student/bygl/xszlcgdj`、`/student/bygl/xshjcgdj` |
| 毕业与学位 | 7 | `/student/pygl/lwktsq_edit`、`/student/pygl/xsktsq_edit`、`/student/pygl/zqkhsq`、`/student/pygl/xszqkhdj`、`/student/bygl/xsdbsq_edit`、`/student/bygl/lwpygl`、`/student/bygl/xsxwsq_edit` |
| 通知 | 1 | `/student/grgl/tzgglist` |
| 网上考试 | 1 | `/student/wsks/wskscp` |
| **合计** | **49** | — |

> 另：运行期入口页 `/home/stulogin`、`/student/default/index`、`/student/default/home`、`/student/grgl/zixun`、`/student/grgl/xssqxx` 见 §2/§14；`/student/grgl/tzggview` 为通知详情；`wsjxpj_pj`、`wskscp_ks`、`wskscp_wj`、`pypgsq_edit`、`szgwsq_edit`、`tyyd_mxsq_edit`、`xwsxsq_edit` 为未抓取的独立页，见 §17.6。

---

## 20. 附：页面-方法速查（供 PRD 直接引用）

| 页面 | GET 接口 | POST 接口 |
| --- | --- | --- |
| 登录 | `stulogin`（HTML）、`verificationcode?codetype=stucode` | `stulogin_do` |
| 首页 | `getxscardinfo`、`getxfwcqk`、`getxsxyyj`、`MenuleftInfo`、`bindterm` | `index_position`、`gethomepagesw`、`getUnReadTzxx`、`getUnRemindTzxx` |
| 个人基本信息 | `xsxx_jbxx`、`xsxx_byxw`、`xsxx_ktzq`、`xscjcx_list` | `xsxx_jcjl`、`xsxx_kylw`、`pyjhcxlist` |
| 学业进程 | `getwelcomdata`、`getxyjcinfo` | — |
| 学期报到 | — | `bindXsZcXx`、`getzcxx`、`xszcaction` |
| 个人信息维护 | `Dmwh_getZyByyxbh`、`getxxlrkz` | `ccqj_getzmdrop`、`xgxx`、`grxxxg_uploadzp` |
| 培养方案 | `bindpyfacx` | `pyfacxlist` |
| 培养计划提交 | `pyjhtj_drop` | `pyjhtjlist`、`py_kclist`、`py_pyjh_addkc`、`py_pyjh_delkc`、`pyjhtj_save` |
| 培养计划查询 | — | `pyjhcxlist`；打印 `pyjhdy`/`pyjhdy_lzlg`/`pyjhdy_tjcj` |
| 选课 | `verificationcode?codetype=xkyzm` | `xswsxk_kb_load`、`xswsxk_kb_loadkb`、`xswsxk_kb_list`、`xswsxk_kb_xk` |
| 选课结果 | — | `bindterm`、`py_kbcx_yw`、`dcexcel_yw` |
| 课表 | — | `py_kbcx_ew`、`dcword_kb`；打印 `doprint_kb` |
| 调课 | — | `ttkcx_list` |
| 考场 | — | `kckccx_list` |
| 成绩 | `xscjcx_list`、`xscjcx_cjzydo` | `xscjcx_cjzylist`、`dcword_cj` |
| 通知 | — | `tzgg_list`、`getUnReadTzxx`、`getUnRemindTzxx` |
| 网上考试 | `wskscp_load`、`wskscp_list` | — |

> 注：`xswsxk_kb_load`/`loadkb`/`list` 在页面 JS 中为 POST；`GMIS_API.md` 个别处标注不一致，以实测为准。`doprint_kb` 实际为 GET 打开打印页。
