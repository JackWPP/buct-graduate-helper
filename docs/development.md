# 开发与构建

## 环境要求

- Flutter 3.47（stable，Dart 3.13）
- Android SDK 36、Java 21
- iOS：macOS + Xcode
- Python 3.12（仅 Python 客户端/测试）
- Node.js 20（仅网页课表规则测试）

## Android（主线）

```bash
cd app
flutter pub get
flutter test
flutter analyze
flutter build apk --debug
flutter build apk --release
```

产物：

- `app/build/app/outputs/flutter-apk/app-debug.apk`
- `app/build/app/outputs/flutter-apk/app-release.apk`

### 构建变体

```bash
# 默认：网页版 VPN + 原生统一身份认证
flutter build apk --release

# 校内直连（跳过网页版 VPN）
flutter build apk --release --dart-define=DIRECT_GMIS=true

# UI 预览包：用 app/assets/snapshot.json 的演示数据，方便截图/走查
flutter build apk --debug --dart-define=UI_PREVIEW=true
```

### 签名

`app/android/app/build.gradle.kts` 会读取 `app/android/key.properties`：

- 有 `key.properties`：使用正式 release 签名
- 没有：release 回退 debug 签名并打警告

生成 keystore 的示例见 `app/android/key.properties.example`。正式分发前必须换成自己的密钥。

## 网页预览

```bash
cd web && python3 -m http.server 8899
```

打开 http://127.0.0.1:8899/ 。预览优先读 `web/data/live.json`，没有则读 `web/data/snapshot.json`；`live.json` 不提交。

## Python 客户端

```bash
python3 -m pip install -r tools/requirements.txt
python3 tools/gmis_cli.py login --user 2026201060 --cookies cookies.json
python3 tools/gmis_cli.py timetable --cookies cookies.json
```

密码只从 `GMIS_PASSWORD` 或交互提示读取，不进入命令行。`cookies.json` 和 `web/data/live.json` 已被 `.gitignore` 忽略。

## 测试

```bash
cd app
flutter test
flutter analyze

node --test web/js/schedule.test.mjs
python3 -m pytest -q
```

当前基线：`flutter test` 55 个测试通过，`flutter analyze` 无问题；网页课表规则 9 个测试、Python 3 个测试通过。

## CI

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) 在 push / PR 时运行：

- Flutter：Java 21、Flutter 3.47.9、`flutter pub get`、`flutter analyze`、`flutter test`、`flutter build apk --debug`，并上传 APK
- Python：3.12、`pip install -r tools/requirements.txt pytest`、`pytest -q`
- Web：Node 20、`node --test web/js/schedule.test.mjs`

## 目录结构

```text
app/                 Flutter 客户端（项目主线）
  lib/
    live_shell.dart  5 Tab、引导、登录和路由
    app_controller.dart
    gmis/            GMIS 适配层与数据装配
    webvpn/          网页版 VPN / 统一身份认证
    storage/         安全会话与快照缓存
    *.dart           首页、课表、学业、服务、我的、选课等页面
  test/              单元与组件测试
  assets/            测试/截图用快照与品牌图形
web/                 390px 网页预览（设计参照）
data/                测试/构建用的学业数据样本
  demo_output/       课表、培养计划、已选课、成绩等
  samples/           各接口响应样例
tools/               Python 客户端和命令行
  gmis_client.py
  gmis_cli.py
  requirements.txt
docs/                产品、架构、开发、发布文档
  api/GMIS_API.md    接口字段说明
  api/API_INDEX.md   按页面的接口索引
PRD.md               产品需求
design/              设计说明、导出稿和标志
research/            竞品调研、功能-接口矩阵、抓取快照
```

## 常见问题

### 手机提示“网络连接失败，请检查网络后重试”

先确认手机能访问 `w.buct.edu.cn`；校外访问走网页版 VPN。校内直连需要校园网或 SSL VPN 能解析 `gmis.buct.edu.cn`。

### release APK 安装时提示签名不一致

旧包和新包使用不同签名。先卸载旧版本再安装；卸载会清除本机偏好和缓存。

### Gradle 构建时网络连接失败

项目已在 `app/android/build.gradle.kts` 和 `settings.gradle.kts` 配置阿里云镜像作为回退；如果本机 Java 走系统代理，可禁用 Java 系统代理后再构建：

```bash
JAVA_TOOL_OPTIONS='-Djava.net.useSystemProxies=false -Dhttp.proxyHost= -Dhttps.proxyHost=' \
  flutter build apk --debug
```
