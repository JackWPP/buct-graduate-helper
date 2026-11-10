# 测试与冒烟 SOP

这份文档规定化研助手从改代码到出包的检查顺序，以及没有真机时如何用 Android 模拟器做 UI 冒烟。目标是让每次迭代都能回答三个问题：**规则有没有坏、界面有没有崩、真实链路有没有被误伤**。

## 1. 测试分层

| 层级 | 检查什么 | 命令 | 是否必需 |
| --- | --- | --- | --- |
| L0 静态检查 | 类型、lint、未使用代码 | `cd app && flutter analyze` | 每次改动 |
| L1 单元/组件 | 课表规则、登录门禁、适配层、快照、活动、选课 | `cd app && flutter test` | 每次改动 |
| L2 网页规则 | 课表几何/颜色与 `web/` 预览一致 | `node --test web/js/schedule.test.mjs` | 改课表规则时 |
| L3 构建 | Android 编译、资源、签名回退 | `cd app && flutter build apk --debug` | 合并前 |
| L4 模拟器冒烟 | 应用能启动、5 Tab 可渲染、无 FATAL、截图可查 | `scripts/android_smoke.sh smoke` | UI/启动链路改动 |
| L5 真机回归 | 真实账号、验证码、VPN、插件、通知 | 人工按第 5 节清单 | 发版前/接口改动 |

`flutter test` 当前基线是 63 个用例；`flutter analyze` 必须零问题。

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

## 5. 真机回归清单（M0）

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

## 6. 发版检查单

1. `pubspec.yaml` 升版本号，`appVersionLabel` 同步。
2. 更新 `docs/releases/` 与 `docs/roadmap.md`。
3. `flutter analyze`、`flutter test`、`node --test` 全绿。
4. `flutter build apk --debug` 与 `--release` 成功。
5. release 使用正式 keystore；确认 `android/key.properties` 只在本机。
6. 真机回归清单通过。
7. 提交、推 `main`，确认 GitHub Actions 的 `flutter` 与 `web` 都绿。
8. 打 tag、写 Release 说明、上传 APK（不提交 keystore/密码）。

## 7. 常见问题

| 现象 | 处理 |
| --- | --- |
| `adb devices` 里 `emulator-5554 offline` | 还在启动，继续 `wait`；超过 15 分钟看 `.artifacts/emulator.log` |
| `x86_64 emulation may not work without hardware acceleration` | 只是警告；脚本已用 `-accel off`，速度慢属正常 |
| 启动直接退出 | 检查磁盘（`df -h`）、AVD 是否创建、镜像是否完整 |
| 安装报 `INSTALL_FAILED_UPDATE_INCOMPATIBLE` | 旧包签名不同，先 `adb uninstall edu.buct.graduate.huayan`（会清数据） |
| 截图全黑 | 设备还没完成启动，或 GPU 后端异常；等启动完成后重试 |
| `uiautomator dump` 找不到文字 | Flutter 语义节点可能未暴露；用截图+坐标点击兜底 |
| Gradle 首次构建卡住 | 依赖在下载；国内可给 Gradle/Flutter 配镜像或代理 |

## 8. 数据与凭据

- 不把密码、Cookie、验证码、证件号、电话、住址、邮箱写入代码、快照、文档、提交或截图。
- 自动化只用 `UI_PREVIEW` 演示数据；真实登录只在真机上人工完成。
- `cookies.json`、`web/data/live.json`、`android/key.properties`、keystore 保持在 `.gitignore` 之外的本机路径。
- logcat 和截图先落 `.artifacts/`，确认不含敏感信息后再决定是否对外提供。
