<p align="center">
  <img src="design/brand/icon-256.png" width="96" alt="化研助手标志：蓝底圆角方块中的苯环，环内是三节不同颜色的课">
</p>

<h1 align="center">化研助手</h1>

<p align="center">
  北京化工大学研究生管理系统的移动增强层。<br>
  课表、成绩、培养进度和 49 项办事入口装进手机；密码只用于当次登录。
</p>

<p align="center">
  <b>Android 主线</b> · <b>Flutter</b> · <b>真实 GMIS 数据</b> · <b>49 项服务</b>
</p>

**Android 版在 `app/`，是项目主线。** `web/` 保留为 390px 可点击设计预览和回归参照，不再承担功能主线。Android 版已经接入真实 GMIS 登录和数据：验证码、课表、已选课、成绩、评教、通知、考场和服务菜单都从学校接口读取，登录会话存系统安全存储，快照缓存在本机。界面按 5 Tab（首页/课表/学业/服务/我的）重排，49 项服务在应用内扁平直达，不经过系统浏览器。默认通过学校网页版 VPN 访问：统一身份认证由原生表单直接完成（支持短信二次认证），再进入 GMIS 验证码登录；校内直连可用 `--dart-define=DIRECT_GMIS=true` 切回。选课可以在应用内直接提交（二次确认 + 选课验证码），后台提醒和深色模式仍未做。

## 当前状态

| 项目 | 状态 |
| --- | --- |
| 项目主线 | Android / Flutter；`web/` 只作设计参照 |
| 当前版本 | `1.6.0+7`（release APK versionCode 7） |
| 登录方式 | 网页版 VPN → 原生统一身份认证（含短信二次认证）→ GMIS 验证码登录 |
| 数据来源 | 真实 GMIS 接口；`SnapshotCache` 本机缓存，`flutter_secure_storage` 存会话 |
| 信息架构 | 5 Tab：首页 / 课表 / 学业 / 服务 / 我的 |
| 服务入口 | 49 项，扁平目录 + 搜索 + 分组筛选，全部应用内打开 |
| 选课 | 可提交/退课：二次确认 → 选课验证码 → 提交 → 刷新课表与学分 |
| 业务页面 | 全原生；WebView 仅保留为 WebVPN 认证页兜底，默认不进入 |
| 未完成 | 后台提醒、深色模式、正式 release 签名、iOS 打包 |

## 功能一览

- **首页**：问候、当前教学周、今日课程、快捷入口、评教提醒、培养进度学分。
- **课表**：周视图、左右滑/箭头换周、课程详情、单课提醒、ICS 分享；长课名按格子宽度折行。
- **学业**：培养进度、成绩、已修课程、评教、考试与调课、申请列表。
- **服务**：49 项 GMIS 服务扁平目录，覆盖个人管理、培养管理、研工管理、科研管理、毕业与学位、网上考试。
- **我的**：个人资料、培养进度、我的申请、成绩单、已修课程、我的评价、考试与调课、消息与提醒、设置。
- **登录与数据**：网页版 VPN + 原生统一身份认证（含短信 2FA）、GMIS 验证码登录、会话过期重登、离线缓存、刷新学校数据、退出登录。

## 界面

下面是 Android 版应用截图。首页、课表、学业、服务、我的使用 5 Tab；服务是 49 项扁平目录，全部应用内打开；长课名在课表格子里折行。

<table>
  <tr>
    <td align="center"><img src="docs/images/home.jpg" width="220" alt="Android 首页：今日课程、6 个快捷入口、评教提醒和培养进度"></td>
    <td align="center"><img src="docs/images/timetable.jpg" width="220" alt="Android 课表：第 10 周，分子探针与诊疗新技术折成两行"></td>
    <td align="center"><img src="docs/images/services.jpg" width="220" alt="Android 服务：49 项服务扁平目录、搜索与分组筛选"></td>
  </tr>
  <tr>
    <td align="center">首页</td>
    <td align="center">周课表</td>
    <td align="center">服务</td>
  </tr>
</table>

默认入口是网页版 VPN + 原生统一身份认证：

<p align="center">
  <img src="docs/images/webvpn.jpg" width="220" alt="Android 网页版 VPN 原生统一身份认证登录页">
  <br>
  <sub>网页版 VPN / 统一身份认证（原生表单，含短信二次认证）</sub>
</p>

选课已经是可提交的真实流程：确认、验证码、失败原因归一化、提交后刷新课表与学分。筛选三屏和考试倒计时还在按设计稿细化。

## 登录流程

1. 首次打开先看引导页；跳过或完成后进入网页版 VPN 登录。
2. 在原生统一身份认证页输入研究生学号和密码；学校要求时进入短信二次认证，验证码短信发送到已绑定手机。
3. 换取 `wengine_vpn_ticket` 后，进入 GMIS 验证码登录页。
4. 登录成功后，`GmisClient` 从学校接口拉取数据，`LiveSnapshotBuilder` 装配成 `Snapshot`（schemaVersion=2），写入本机缓存。
5. 下次启动优先恢复安全存储中的会话并展示缓存；过期或退出时回到登录页。

校外默认走 `w.buct.edu.cn`；如果手机在校园网内，可用 `--dart-define=DIRECT_GMIS=true` 改为直连 `gmis.buct.edu.cn`。学校账号只用于登录，仓库里没有可用账号。

## 三块怎么接在一起

<img src="docs/images/layers.png" alt="Android 主线、网页预览和学校接口的关系">

- **Android 主线**：`app/lib/gmis/` 是 Dart 适配层，负责登录、Cookie、302 会话过期、JSON 解析和业务接口；`live_snapshot_builder.dart` 把接口装配成快照；`AppController` 管理状态与缓存。
- **网页预览**：`web/` 仍读 `web/data/snapshot.json` 或忽略的 `web/data/live.json`，用于 390px 设计回归和旧演示路径。
- **Python 只读导出**：`gmis_cli.py` 可选地把只读课表导出到 `web/data/live.json`，不参与 Android 默认数据通路。

`app/assets/snapshot.json` 只用于组件测试、截图和旧演示路径（`HuayanApp(snapshot: ...)` / `skipGate`），不是默认启动数据；它和 `web/data/snapshot.json` 都只保留学业字段。

## 跑起来

### 环境要求

- Flutter 3.47（stable，Dart 3.13）
- Android SDK 36、Java 21（Android 构建）
- iOS 需要 macOS + Xcode

### Android（主线）

```bash
cd app
flutter pub get
flutter test
flutter analyze
flutter build apk --debug
```

debug 产物在 `app/build/app/outputs/flutter-apk/app-debug.apk`；打 release 包用：

```bash
flutter build apk --release
```

产物在 `app/build/app/outputs/flutter-apk/app-release.apk`。`app/android/app/build.gradle.kts` 会在 `app/android/key.properties` 存在时使用正式 release 签名，否则回退 debug 签名并打警告；正式上架前需要换成自己的密钥。当前源码版本是 `1.6.0+7`，release APK 的 versionCode 为 7；已发布的 [v1.0.0](https://github.com/JackWPP/buct-graduate-helper/releases/tag/v1.0.0) Android 包只用于侧载试装，`v1.1.0` 标签尚无独立 APK。

默认登录需要手机能访问 `w.buct.edu.cn`（学校网页版 VPN 门户）和统一身份认证；使用校内直连时需要能访问 `gmis.buct.edu.cn`（校园网/VPN）。

### 网页预览（设计参照）

```bash
cd web && python3 -m http.server 8899
```

打开 http://127.0.0.1:8899/ 。预览优先读 `web/data/live.json`，没有就继续用 `web/data/snapshot.json`；`live.json` 不提交。

### Python 只读导出

```bash
python3 -m pip install -r requirements.txt
python3 gmis_cli.py login --user 2026201060 --cookies cookies.json
python3 gmis_cli.py timetable --cookies cookies.json
```

登录会把学校返回的验证码图存进临时目录，终端输入验证码后图片即删。密码只从环境变量 `GMIS_PASSWORD` 或交互提示读取。`login` 成功后 Cookie 写入 `cookies.json`（已被忽略）。接口返回 302 时重新执行 `login`。`timetable` 写成 `web/data/live.json`，只供网页预览使用。

## 测试

```bash
cd app
flutter test
flutter analyze
```

当前 Android 测试覆盖课表规则、登录门禁、真实适配层（公钥解析/RSA 密文/会话恢复/短信挑战）、快照 v2 与缓存、选课流程、Demo 网关。当前 **55 个测试全部通过**；`flutter analyze` 无问题。

网页课表规则与 Python 客户端：

```bash
node --test web/js/schedule.test.mjs
python3 -m pytest -q
```

CI 在 [`.github/workflows/ci.yml`](.github/workflows/ci.yml)：push 和 PR 会跑 `flutter analyze`、`flutter test`、debug APK 构建，以及 Python 和网页课表规则测试。

## 仓库结构

```text
app/                 Android/iOS Flutter 客户端（项目主线）
  lib/               入口、5 Tab、GMIS 适配层、WebVPN、选课、缓存
  test/              单元与组件测试
  assets/            测试/截图用快照与品牌图形
web/                 390px 可点击网页预览（设计参照）
  js/                页面逻辑与课表规则
  data/              快照与忽略的 live.json
gmis_client.py       Python 客户端：RSA 登录、Cookie、主要接口、ICS
gmis_cli.py          命令行：登录、导出、课表 ICS、课程查询
GMIS_API.md          接口文档：登录、培养、选课、课表、成绩、研工、科研、毕业
API_INDEX.md         按 49 个页面分组的接口索引
PRD.md               产品需求
design/              设计说明、导出稿和标志
research/            竞品调研和功能-接口对照
```

## 对接学校时要注意

- 登录 RSA 公钥每次 GET `/home/stulogin` 都变，必须从当前页面 `#pubkey` 解析。
- 业务接口正文是 JSON，`Content-Type` 却是 `text/html`，按文本解析。
- `__SINDEXCOOKIE__` 和 `ASP.NET_SessionId` 一起保存；会话闲置后会 302 到 `/home/stulogin`。
- 网页版 VPN 统一身份认证的密码用页面 `croypto` 做 AES-128-ECB 加密；学校可能追加短信二次认证。
- 选课验证码是 `GET /home/verificationcode?codetype=xkyzm`，和登录验证码 `stucode` 不同。
- `py_kbcx_ew.week` 是当前星期的英文，不是教学周；教学周用 `py_kbcx_yw` 的 `ksz` / `jsz`。
- 密码、Cookie、验证码、证件号、电话、住址、邮箱不进代码、快照、文档或提交。

## 已知限制与下一阶段

- 后台提醒未接入系统通知；目前只有应用打开时的前台提示，22:00–07:00 不提示。
- 深色模式仍为浅色；设计稿写的是跟随系统。
- 部分复杂服务入口（如新生入学登记、录取复查、照片核对等）仍是只读/占位页，需要继续补表单与附件能力。
- release APK 仍使用模板 debug 签名；正式分发前必须换成自己的签名密钥。
- iOS 共用 Flutter 代码，但尚未在 macOS/Xcode 上打出可分发包。

## 文档

- [PRD.md](PRD.md)
- [design/02-handoff.md](design/02-handoff.md)
- [GMIS_API.md](GMIS_API.md)
- [API_INDEX.md](API_INDEX.md)
- [gmis_client.py](gmis_client.py)
- [gmis_cli.py](gmis_cli.py)
- [AGENTS.md](AGENTS.md)
