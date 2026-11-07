# 云端继续：化研助手

这是北京化工大学研究生管理系统的移动增强层。产品定义在 `PRD.md`，设计在 `design/`。**Android 版在 `app/`，是项目主线**；`web/` 是 390px 可点击的设计预览和回归参照，不再是功能主线。学校接口客户端是 `gmis_client.py` 和 `gmis_cli.py`。

云端代理从这里接着做，不要重开一套产品。

## 现在到哪了

Android 版（Flutter）已经接入真实 GMIS 数据通路：

- 默认启动走 `app/lib/live_shell.dart`：引导 → 真实登录 → 首页/课表/学业/服务/我的（5 Tab）。服务页是扁平目录，48 项服务全部在应用内直达，不经过分组页，也不打开系统浏览器。
- 登录页 `app/lib/live_login_page.dart` 从学校接口取验证码图，密码只在本次登录内存里使用；登录成功后 Cookie 写系统安全存储（`flutter_secure_storage`），密码不落盘。
- 校外访问走 `app/lib/webvpn/`：登录页的「使用网页版 VPN 登录」打开 `w.buct.edu.cn` 统一身份认证 WebView，读取 `wengine_vpn_ticket` Cookie 后，把 GMIS 请求改走 `https://w.buct.edu.cn/https/<token>/`；WebVPN 会话单独存储在 `huayan_gmis_webvpn_session`。
- `app/lib/gmis/` 是 Dart 版适配层：`GmisClient` 负责登录、Cookie、302 会话过期、JSON 解析；`GmisApi` 封装学期、学生卡、已选课、培养计划、选课列表、成绩、评教、申请、通知、考场、调课和服务菜单。
- `app/lib/gmis/live_snapshot_builder.dart` 把多个接口装配成 `Snapshot`（schemaVersion=2）；`AppController` 管理 `booting/signedOut/restoring/ready/offline/sessionExpired` 状态和缓存。课表来自 `py_kbcx_yw`，已选课列表也来自这里；成绩、通知、考试、选课列表分别进详情页。
- 缓存：`SnapshotCache` 写 `app` 支持目录；`SecureSessionStore` 存会话。没有登录会话时不展示缓存，避免泄露课表。
- 学期第 1 周：`TermCalendar` 内置 55 学期 = 2026-08-31；未知学期会提示周次可能不准，用户本机补充过的值优先。
- 选课提交/退选没有实现，页面明确是只读；等设计稿和真机联调后再做。通知没有后台调度，只有前台 SnackBar；深色模式仍是浅色。
- 全原生改造进行中：`app/lib/academics_page.dart`、`app/lib/services_page.dart`、`app/lib/native_service_page.dart`、`app/lib/remote_pages.dart` 已加入；已接入 5 Tab、48 项服务扁平目录和一批只读远程页。
- `app/assets/snapshot.json` 只用于组件测试、截图和旧演示路径（`HuayanApp(snapshot: ...)` / `skipGate`），不是默认启动数据。

网页预览仍是设计参照：`web/data/snapshot.json` 来自 2026-10-30 课表导出；`gmis_cli.py login` 用学校验证码图，密码只从 `GMIS_PASSWORD` 或交互输入读取，Cookie 写进被忽略的 `cookies.json`。`gmis_cli.py timetable` 把只读课表写到被忽略的 `web/data/live.json`，预览优先读它。Python 只读导出不再服务 Android 默认数据通路。

验证记录（2026-11-07）：`M531DA`（Android 17）已安装 1.2.0 release 包，真实登录后首页、课表、服务可用；1.3.0 的 5 Tab 与原生服务目录已在 Android 16 模拟器（`emulator-5554`）用 `UI_PREVIEW=true` 预览验证，真机还需装 1.3.0 复核。`gmis.buct.edu.cn` 在校外可能无法解析，此时用登录页的「使用网页版 VPN 登录」。真机联调时仍需确认验证码、刷新、退出和会话过期重登。

## 下一轮按这个顺序

1. 真机联调 M0：在校园网或网页版 VPN 下登录真实账号，确认验证码、课表、成绩、通知、考试列表、刷新、退出和会话过期重登；修复接口字段与真实返回不一致的地方。
2. 选课三屏、提交/退选、考试倒计时、真实通知详情页；设计稿没画完之前不要编数据。选课提交必须保留二次确认和验证码。
3. 后台提醒：现在只有前台提示；接 `flutter_local_notifications` 前先做权限申请与通知设置页。
4. Android release 换正式签名密钥；iOS 包要在 macOS 上用 Xcode 打。
5. 深色模式设计写了跟随系统，网页预览和 Android 版都还没做。

## 不能碰的数据

不要把密码、Cookie、验证码、证件号、电话、住址、邮箱写进代码、快照、文档或提交。这些原始文件留在本机，被 `.gitignore` 排除。`app/assets/snapshot.json` 和 `web/data/snapshot.json` 只保留课表和培养进度需要的学业字段。真实登录产生的 Cookie 只进系统安全存储，`cookies.json` 和 `web/data/live.json` 不提交。

## 验证命令

Android（主线）：

```bash
cd app
flutter test
flutter analyze
flutter build apk --debug
flutter build apk --release
```

`flutter test` 目前包含课表规则、登录门禁、真实适配层的公钥解析/RSA 密文/会话恢复、快照 v2 与缓存、Demo 网关测试。改课表计算后同时跑两边规则：

```bash
node --test web/js/schedule.test.mjs
cd app && flutter test
```

预览：

```bash
cd web && python3 -m http.server 8899
```

云端环境会在启动时执行 `.cursor/environment.json` 的 `start`，页面在 8899 端口。GitHub Actions 在 `.github/workflows/ci.yml` 跑 Flutter、Python 和网页课表测试。
