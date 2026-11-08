# 学校接口笔记

这份文档记录化研助手对接 GMIS / 网页版 VPN 时的关键事实。字段级细节见 [GMIS_API.md](api/GMIS_API.md) 和 [API_INDEX.md](api/API_INDEX.md)。

## 登录

- 登录页：`GET https://gmis.buct.edu.cn/home/stulogin`
- 从当前页面 `#pubkey` 解析 RSA 公钥；每次 GET 都可能换公钥
- 验证码：`GET /home/verificationcode?codetype=stucode`（GIF）
- 提交：`POST /home/stulogin_do`，表单字段 `json`
- 密码用 RSA PKCS#1 v1.5 加密后 Base64
- 成功返回 `{"jg":"1","url":"student/default/index"}`；失败返回 `{"jg":"0","msg":"..."}`
- 旧公钥可能返回 500 `InvalidCipherTextException: block incorrect`，需要重新取登录页和公钥

## 网页版 VPN / 统一身份认证

- `w.buct.edu.cn` 是学校网页版 VPN 门户
- `https://w.buct.edu.cn/login` 会跳到 `sidportal.buct.edu.cn` 的统一身份认证
- 统一身份认证页可直接访问，适合做原生表单
- 密码用页面 `#login-croypto` 做 AES-128-ECB + PKCS7 加密
- 学校可能要求短信二次认证：`sendSmsCode` → `checkToken` → 再提交 `/login`
- 认证成功拿到 CAS ticket，再换取 `wengine_vpn_ticket...` Cookie
- WebVPN 后的 GMIS URL 形如 `https://w.buct.edu.cn/https/<token>/...`；token 由 target host 经 AES-128-CFB 生成

## 课表

- `POST /student/pygl/py_kbcx_ew` body `{kblx:"xs",termcode}`
- 返回 `rows`，单元格 HTML 片段形如 `<br/>课程班名[10-16周] 教师[科303]`
- `week` 是当前星期英文，不是教学周
- 教学周从 `py_kbcx_yw` 的 `ksz` / `jsz` 读取；`sjms` 解析多时间段
- 节次时间从 `xswsxk_kb_load.jc` 读取，不写死

## 选课

- `POST /student/pygl/xswsxk_kb_list`：课程列表，`{kc,total}`
- `POST /student/pygl/xswsxk_kb_loadkb`：已选课网格，13 行
- `POST /student/pygl/xswsxk_kb_xk`：提交选课/退课，表单 `{lb:'1'|'0', bjid, xkyzm}`
- `bjid` 是主键，不是 `kcbh`
- 选课验证码 `GET /home/verificationcode?codetype=xkyzm`，与登录验证码 `stucode` 不同
- `yxkc`：0 可选 / 1 已选 / 2 可退选；`xkfs=2` 才显示退选
- 失败原因归一化：余量满、时间冲突、不在选课时间、门数超限、已选过

## 成绩

- `POST /student/pygl/xscjcx_list` 返回 `xwklist / fxwklist / hjcjlist / xftj / hjzxf`
- `cj` 可能是数字或等级；展示时优先 `cjdjmc`
- 学分统计直接用后端 `xftj` 口径，不自行换算

## 考试与通知

- 考场：`POST /student/pygl/kckccx_list`，空列表时显示“暂未发布考场”
- 调课：`POST /student/pygl/ttkcx_list`
- 通知列表：`GET /student/grgl/tzgg_list`，参数 `page, rows, bt, ksrq, jsrq`
- 通知详情可由系统浏览器或原生页承载；化研助手优先原生列表，详情页按接口能力扩展

## 学术报告 / 劳动实践

- 学术报告可报名列表：`POST /student/yggl/xshdbm_sqlist`；我的报名：`POST /student/yggl/xshdbm_cklist`
- 学术报告报名前预检：`GET /student/yggl/xshdbm_sfkysq?id=`，`sign=0` 表示不在报名时间
- 劳动实践可报名列表：`POST /student/yggl/zyzfwbm_sqlist`；我的报名：`POST /student/yggl/zyzfwbm_cklist`
- 劳动实践累计小时：`POST /student/yggl/getldsjzsc`，返回 `{zt:'1', hdzsc}`
- 报名：`POST /student/yggl/xshdbm_bm`，表单 `{id, VeriCode}`；学术报告和劳动实践共用
- 取消：学术报告 `POST /student/yggl/xshdbm_del` `{hdid}`；劳动实践 `POST /student/yggl/ldsjbm_del` `{hdid}`
- 活动验证码是独立的 `VeriCode` 图片；优先 `/student/yggl/VerificationCode`，兼容 `/Home/VerificationCode`
- 列表字段：`rs` 容量、`bmrs` 已报名、`bmkssj/bmjzsj` 报名时间、`kssj/jzsj` 活动时间、`hdsc` 时长、`shbj` 审核状态

## 其他约定

- 业务接口正文是 JSON，`Content-Type` 常是 `text/html`，按文本解析
- 会话过期通常 302 到 `/home/stulogin`；客户端统一转成“登录态已失效，请重新登录”
- `__SINDEXCOOKIE__` 和 `ASP.NET_SessionId` 一起保存
- 密码、Cookie、验证码、证件号、电话、住址、邮箱不写进代码、快照、文档或提交
