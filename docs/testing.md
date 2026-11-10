# 测试与冒烟 SOP

这份文档规定化研助手从改代码到出包的检查顺序，以及没有真机时如何用 Android 模拟器做 UI 冒烟。目标是让每次迭代都能回答三个问题：**规则有没有坏、界面有没有崩、真实链路有没有被误伤**。

## 1. 测试分层

| 层级 | 检查什么 | 命令 | 是否必需 |
| --- | --- | --- | --- |
| L0 静态检查 | 类型、lint、未使用代码 | `cd app && flutter analyze` | 每次改动 |
| L1 单元/组件 | 课表规则、登录门禁、适配层、快照、活动、日计划/空闲/冲突、待办、选课 | `cd app && flutter test` | 每次改动 |
| L2 网页规则 | 课表几何/颜色与 `web/` 预览一致 | `node --test web/js/schedule.test.mjs` | 改课表规则时 |
| L3 构建 | Android 编译、资源、签名回退 | `cd app && flutter build apk --debug` | 合并前 |
| L4 模拟器冒烟 | 应用能启动、5 Tab 可渲染、无 FATAL、截图可查 | `scripts/android_smoke.sh smoke` | UI/启动链路改动 |
| L5 真机回归 | 真实账号、验证码、VPN、插件、通知 | 人工按第 6 节清单 | 发版前/接口改动 |

`flutter test` 当前基线是 142 个用例（2026-11-11）；`flutter analyze` 必须零问题。

## 2. 环境要求

- Flutter 3.47.9（stable，Dart 3.13.7）
- OpenJDK 17+（本机用 21）
- Android SDK：Platform 36、Build-Tools 36.0.0、Platform-Tools、NDK 28.2.13676358
- 可选：Android Emulator + `system-images;android-35;aosp_atd;x86_64`

本机工具链位置（不写进公开仓库的绝对路径，换机器时按自己的目录替换）：

```bash
export PATH="$HOME/development/flutter/bin:$PATH"
export JAVA_HOME=/usr/lib/jvm/java-21-openjdk-amd64
export ANDROID_HOME="$HOME/Android/Sdk"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
```

检查 Android 工具链：

```bash
flutter doctor -v
```

## 3. 日常迭代顺序

```bash
cd app
flutter analyze
flutter test
```

改课表计算时同时跑网页规则：

```bash
node --test web/js/schedule.test.mjs
cd app && flutter test
```

出包前两种构建都跑：

```bash
cd app
flutter build apk --debug
flutter build apk --release
```

产物在 `app/build/app/outputs/flutter-apk/`。release 包在没有 `android/key.properties` 时回退 Android Debug 签名，只能测试安装，不能正式分发。

## 4. 模拟器冒烟

### 4.1 首次准备

```bash
sdkmanager "emulator" "system-images;android-35;aosp_atd;x86_64"
scripts/android_smoke.sh create
```

脚本默认 AVD 是 `huayan_atd`，镜像 `android-35;aosp_atd;x86_64`，设备档位 `pixel_5`。需要换镜像时通过 `IMAGE=... scripts/android_smoke.sh create` 覆盖。

### 4.2 启动与等待

```bash
scripts/android_smoke.sh start
scripts/android_smoke.sh wait
```

- 有 `/dev/kvm` 时脚本自动用 KVM；没有时自动加 `-accel off`（TCG 软件模拟）。
- **KVM 被 BIOS 关闭时 TCG 启动很慢**（常见 5–15 分钟），启动后不要频繁重启。
- 启动完成后，应用首帧在 TCG 下还可能再花 1–4 分钟；`smoke`/`launch` 会等 ActivityManager 的 `Displayed` 日志，不用固定 sleep。超时可用 `FIRST_FRAME_TIMEOUT` 调整（默认 600 秒）。
- 无窗口启动，截图和输入都通过 adb。
- 启动日志在 `.artifacts/emulator.log`。

### 4.3 构建演示包（不需要真实账号）

模拟器冒烟使用 `UI_PREVIEW`，它读取 `app/assets/snapshot.json` 的演示身份和课程，不连接学校服务器：

```bash
cd app
flutter build apk --debug --dart-define=UI_PREVIEW=true
cd ..
```

### 4.4 一键冒烟

```bash
scripts/android_smoke.sh smoke
```

依次执行：启动（若未运行）→ 等 `sys.boot_completed=1` → 安装 → 启动 → 截图 → 导出 logcat → 检查 `FATAL EXCEPTION`。产物：

```text
.artifacts/screenshots/smoke.png
.artifacts/logcat.txt
.artifacts/emulator.log
```

`.artifacts/` 已加入 `.gitignore`，截图可能包含个人数据，不要提交。

### 4.5 页面巡检

逐项确认（截图留档）：

- [ ] 首页显示问候、当前周、今日课程/学分
- [ ] 课表可左右滑切换周次
- [ ] 学业页能进入成绩/考试/评教
- [ ] 服务页 49 项可搜索
- [ ] 我的页显示演示身份
- [ ] 选课页出现类型/学位/星期/院系/节次筛选
- [ ] 活动页可打开“学术报告/劳动实践”
- [ ] logcat 没有 `FATAL EXCEPTION` / `AndroidRuntime`

需要点击某个文字时：

```bash
scripts/android_smoke.sh dump           # 查看无障碍节点
scripts/android_smoke.sh tap "课表"      # 点第一个匹配节点
scripts/android_smoke.sh tap-tab "课表"  # 点底部导航（取最低匹配，避免误点内容区同名文字）
scripts/android_smoke.sh back           # 返回上一页
```

### 4.6 已知限制

- ATD 是面向测试的精简镜像，可能不带 Google 服务；依赖系统 WebView、推送或 Google 登录的页面不能代表真机。
- `UI_PREVIEW` 绕过了真实登录，不能验证验证码、Cookie、WebVPN、安全存储和通知权限。
- TCG 下渲染和启动都慢，动画类断言不适合放在这一层。

### 4.7 课表 / 日程 / 待办冒烟

- `UI_PREVIEW` 构建会在学术报告/劳动实践页注入演示活动（`app/lib/preview/demo_activity.dart`），用于界面截图；真实构建仍走 GMIS。
- 课表页顶部切“课表 / 日程”，确认两边的周次一致；日程里能同时看到课程、已报名活动、待办和空闲段。
- 点日头打开当天日程；点课程行的 `+` 添加待办，确认标题、日期、课程和上课时间已预填。
- 新增/编辑/勾选/删除待办后，切周或重启应用，确认待办仍在（按学号隔离）。
- 打开一个与课程冲突的活动，确认卡片/详情显示冲突课程和当天空闲；点“查看当天日程”能看到候选活动标“待报名”。
- 360px 宽和 390px 宽各截一次图，检查没有 overflow/FATAL。
- 测试结束清应用数据和含个人信息的截图。

## 5. WebVPN 回归

WebVPN 的问题不能只靠“能打开首页”判断。以下三层都要跑。

### 5.1 单测覆盖

```bash
cd app
flutter test test/webvpn_credential_test.dart
flutter test test/webvpn_url_test.dart
flutter test test/webvpn_validator_test.dart
flutter test test/webvpn_session_manager_test.dart
flutter test test/webvpn_auth_client_test.dart
flutter test test/app_controller_webvpn_test.dart
flutter test test/gmis_client_test.dart
```

必须覆盖：

- 无效 CAS 返回 200 但只下发匿名 ticket → 登录抛 `WebVpnAuthException`，不生成会话。
- 有效 ticket + 最终 404 → 校验为 valid，登录成功。
- 门户 `/login`、`/https/<sidportal-token>/login` → `WebVpnSessionExpired`。
- 目标 `/home/stulogin`、`/https/<gmis-token>/home/stulogin` → `GmisSessionExpired`。
- ticket 只在 ticket 存储；`GmisClient` 的 GMIS Cookie 不含 `wengine_vpn_ticket*`。
- 旧 AuthSession 混存 ticket → 启动迁移并清理。
- 启动矩阵：valid/expired/offline/unknown × 有无 GMIS/直连会话。
- 门户轮换 ticket → 后续请求使用新值。

### 5.2 无凭据的真实门户探测

只发公开请求，不登录、不提交 cookie：

```bash
# 无效 CAS ticket 会返回 200，并下发匿名 ticket；不能以最终状态码判断成功
curl -sD - -o /dev/null \
  'https://w.buct.edu.cn/login?cas_login=true&ticket=ST-invalid'

# 拿匿名 ticket 访问受保护页面，应当 302 回门户 /login
curl -sD - -o /dev/null \
  'https://w.buct.edu.cn/https/<gmis-token>/home/stulogin'
```

判断顺序：先看响应是否 302 到门户登录；再看目标页是否可达。**不要以“有 Set-Cookie”当作登录成功。**

### 5.3 2026-11-10 模拟器真实账号回归

在 KVM 加速的 API 35 ATD 模拟器上用真实账号完成了主路径回归（凭据只用于本次运行，未写入仓库/文档）：

- [x] 原生统一身份认证（未触发短信二次认证）→ GMIS 验证码 → 首页真实数据。
- [x] 杀进程重启：ticket + GMIS 会话恢复，直接回到首页，不再要求登录。
- [x] 切飞行模式/断开 WiFi 后重启：显示缓存数据和重试提示，ticket 未清；恢复网络后重启直接回首页。
- [x] 活动页拉取到 7 场可报名活动，监测状态与通知权限流程正常。
- [x] WebView 兜底页在 ATD 上只拿到匿名凭证；校验器拒绝后自动回统一身份认证，没有误入 GMIS 登录。
- [x] 退出登录后回到 SSO，安全存储/WebView Cookie 清理。
- [x] 清应用数据后重新用真实账号登录：新 ticket → GMIS 登录页（`#pubkey` 正常解析）→ 图形验证码 → 首页真实数据，重启后直接恢复。
- [x] 强制 GMIS 服务端会话失效（WebVPN ticket 保持有效）：应用只回到 GMIS 登录页，不回到 SSO；补密码 + 新验证码后回到首页真实数据，重启仍直接恢复。

本轮复现还确认了两件事：

- **ATD 上 WebView 不可用**：打开门户登录页后，一旦聚焦输入框/弹出键盘，WebView 渲染进程就崩溃（logcat 有 `crashpad_client_linux.cc` FATAL），并连带整个应用退出。这是镜像裁剪导致的 WebView 限制，不是应用逻辑；完整 WebView 登录只能在正式镜像或真机补测。
- **门户会替同一 ticket 缓存目标站会话**：只删除本机 GMIS 会话条目后重启，ticket 仍有效，`/home/stulogin` 直接 302 到 `/student/default/index` 并返回已登录首页，因此“GMIS 过期、SSO 不过期”没法用删本地 Cookie 的方式模拟。要复现 GMIS-only 过期，需要在保留 ticket 的同时真正结束 GMIS 服务端会话（本轮用一次性的本地登出探针完成，探针未提交）。
- **GMIS 会话失效时 JSON 接口不一定 302**：`/student/default/bindterm` 在会话失效后返回 HTTP 200 + `{}`，旧逻辑会当成“学校没有返回学期列表”而停在离线缓存。现在 `terms()` 把空对象视为会话过期，直接走 GMIS 登录；`gmis_client_test.dart` 覆盖了这个响应。

尚未强制触发的真实场景：GMIS 会话自然超时（本轮用强制登出复现，过期路径一致）、WebVPN ticket 自然过期、完整 WebView 登录成功。这些已由单测覆盖，仍需后续在可用 WebView 的模拟器或真机上补测。

### 5.4 统一身份认证静默续签与密码预填

原生 SSO 成功后会留存 `sidportal.buct.edu.cn` 的会话 Cookie（`SOURCEID_TGC` / `SESSION` 等）到安全存储。验证方法：

1. 正常登录一次，确认首页数据加载。
2. 破坏本机 ticket（本地调试可用一次性探针写入无效 ticket，或等 ticket 自然过期），保留 SSO 会话后重启。
3. 期望：日志/界面不再回统一身份认证；应用直接进入 GMIS 登录页或首页。
4. 清掉 SSO 会话后再破坏 ticket，期望：回到统一身份认证登录页，学号仍记住。
5. 退出登录后确认安全存储里的 ticket、SSO 会话、GMIS 会话都被清空。

2026-11-10 真实账号验证：写入无效 ticket 后启动，SSO 静默续签成功（SSO 会话 5 个 Cookie），直接进入 GMIS 登录页；清空 SSO 会话后再试，正确回到统一身份认证页。SSO 过期后用 `/login?service=...` 返回登录页而不是 ticket，应用应清除留存并提示重新认证。

密码预填验证：正常登录时保持“保持登录”勾选；用一次性探针同时写入无效 ticket 并强制结束 GMIS 服务端会话，重启后应看到 GMIS 登录页已预填学号、密码，只需输入验证码即可回首页。设置里“清除已保存的登录密码”后再次过期，密码框应为空。

### 5.5 真机人工回归

- [ ] 真实账号 + 短信二次认证完成 SSO，GMIS 验证码登录成功。
- [ ] 杀进程重启：ticket 有效时不再要求 SSO，直接恢复/刷新。
- [ ] 让 GMIS 会话失效：只出现 GMIS 登录，不出现 SSO。
- [ ] 让 ticket 失效：自动回 SSO，不出现“GMIS 登录反复失败”。
- [ ] 飞行模式启动：ticket 保留，显示缓存/离线提示，恢复网络后可刷新。
- [ ] WebView 兜底登录成功后重启仍复用 ticket。
- [ ] 退出登录后 WebView Cookie、secure storage、缓存均清理。
- [ ] 日志/截图/存储中不出现 ticket 值、密码、短信码、学号。

真实登录涉及密码和短信，只能由本人在设备上完成；自动化只做安装、截图和 logcat。

### 5.6 2026-11-11 真实账号联调（本次活动/日程/待办）

- 统一身份认证（未触发短信）→ GMIS 验证码 → 首页真实数据；杀进程重启会话恢复。
- 学术报告：可报名 3 / 待进行 5 / 我的报名 0；待进行包含未开始报名和已满场次，证明学校接口会返回未来场次。
- 劳动实践：可报名 0 / 待进行 16 / 我的报名 0，空态“查看待进行”正常。
- 活动详情：周几、与真实课表的冲突、当天空闲、候选当天日程均正确。
- 课表日程：真实课程 + 待办；新增/勾选/重启持久化/删除通过；课程行 `+` 预填真实课程时间通过。
- 未提交真实报名、未点“立即报名”，未验证系统通知和名额释放真实触发。
- 测试后清除应用数据和真实账号截图；不在测试记录里保存账号、姓名或活动个人信息。

## 6. 真机回归清单（M0）

准备：校园网或网页版 VPN、真实账号、能接收短信二次认证。

- [ ] 冷启动 → 引导 → 统一身份认证（含短信二次认证）
- [ ] GMIS 图形验证码 → 首页加载真实数据
- [ ] 课表周次、今日课程、下一节课正确
- [ ] 学业页成绩/评教/考试/培养进度
- [ ] 服务页 49 项能打开目标页
- [ ] 选课：筛选、二次确认、`xkyzm` 验证码、成功/失败提示
- [ ] 活动：报名、取消、独立验证码、监测提醒
- [ ] 下拉刷新、退出登录、杀进程后会话恢复
- [ ] 会话过期（302）后重新登录
- [ ] 深色系统设置、通知权限、返回键与后台切换

真机登录涉及密码和短信，自动化只做安装、截图和 logcat；登录动作由本人在设备上完成。

## 7. 发版检查单

完整流程、文案口径和图片规范见 [发版 SOP](release-sop.md)。这里只留最小检查项：

1. `pubspec.yaml` 升版本号，`appVersionLabel` 同步。
2. 新增 `docs/assets/banners/release-v<版本>.png` 和至少一张 Release 截图，更新 `docs/assets/README.md`。
3. 写 `docs/releases/v<版本>.md`：顶部 Banner、正文截图、只写用户能感知的内容，不写修复列表/验证情况/内部技术细节。
4. 更新 README 的版本 badge、当前版本、发布说明链接和文档表；README 不再保留 `## 安全边界`。
5. `flutter analyze`、`flutter test`、`node --test` 全绿。
6. `flutter build apk --debug` 与 `--release` 成功。
7. release 使用正式 keystore；确认 `android/key.properties` 只在本机。
8. 真机回归清单通过。
9. 提交、推 `main`，确认 GitHub Actions 的 `flutter` 与 `web` 都绿。
10. 写 SHA-256、建 tag、建 GitHub Release、上传 APK 与 `.sha256`；打开 Release 页面确认图片正常显示。
11. 清理模拟器真实会话和含个人信息的截图。

## 8. 常见问题

| 现象 | 处理 |
| --- | --- |
| `adb devices` 里 `emulator-5554 offline` | 还在启动，继续 `wait`；超过 15 分钟看 `.artifacts/emulator.log` |
| `x86_64 emulation may not work without hardware acceleration` | 只是警告；脚本已用 `-accel off`，速度慢属正常 |
| 启动直接退出 | 检查磁盘（`df -h`）、AVD 是否创建、镜像是否完整 |
| 安装报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 旧包签名不同，先 `adb uninstall edu.buct.graduate.huayan`（会清数据） |
| 截图全黑 | 设备还没完成启动，或 GPU 后端异常；等启动完成后重试 |
| `uiautomator dump` 找不到文字 | Flutter 语义节点可能未暴露；用截图+坐标点击兜底 |
| Gradle 首次构建卡住 | 依赖在下载；国内可给 Gradle/Flutter 配镜像或代理 |

## 9. 数据与凭据

- 不把密码、Cookie、验证码、证件号、电话、住址、邮箱写入代码、快照、文档、提交或截图。
- 自动化只用 `UI_PREVIEW` 演示数据；真实登录只在真机上人工完成。
- `cookies.json`、`web/data/live.json`、`android/key.properties`、keystore 保持在 `.gitignore` 之外的本机路径。
- logcat 和截图先落 `.artifacts/`，确认不含敏感信息后再决定是否对外提供。
