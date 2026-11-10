# 开发与构建

## 环境要求

- Flutter 3.47（stable，Dart 3.13）
- Android SDK 36、Java 17+
- iOS：macOS + Xcode
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

## 测试

```bash
cd app
flutter test
flutter analyze

node --test web/js/schedule.test.mjs
```

当前基线：`flutter test` 93 个测试通过，`flutter analyze` 无问题；网页课表规则 9 个测试通过。完整的检查顺序、模拟器冒烟和真机回归清单见 [测试与冒烟 SOP](testing.md)。

## CI

[`.github/workflows/ci.yml`](../.github/workflows/ci.yml) 在 push / PR 时运行：

- Flutter：Java 17、Flutter 3.47.9、`flutter pub get`、`flutter analyze`、`flutter test`、`flutter build apk --debug`，并上传 APK
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
docs/                产品说明、架构、开发与发布文档
```

## 常见问题

### 手机提示“网络连接失败，请检查网络后重试”

先确认手机能访问 `w.buct.edu.cn`；校外访问走网页版 VPN。校内直连需要校园网或 SSL VPN 能解析 `gmis.buct.edu.cn`。

### 提示“校外访问已过期，请重新登录统一身份认证”

WebVPN ticket 失效，应用会清 ticket 但保留 GMIS 会话和课表缓存。重新完成统一身份认证后，如果 GMIS Cookie 还有效会直接回到首页；否则只需再补一次 GMIS 验证码。

### 提示“登录已过期，请重新登录”

这是 GMIS 会话过期，WebVPN ticket 仍然有效；不要重新做统一身份认证，直接输入 GMIS 验证码即可。两种提示不要混为一谈。

### release APK 安装时提示签名不一致

旧包和新包使用不同签名。先卸载旧版本再安装；卸载会清除本机偏好和缓存。

### Gradle 构建时网络连接失败

项目已在 `app/android/build.gradle.kts` 和 `settings.gradle.kts` 配置阿里云镜像作为回退；如果本机 Java 走系统代理，可禁用 Java 系统代理后再构建：

```bash
JAVA_TOOL_OPTIONS='-Djava.net.useSystemProxies=false -Dhttp.proxyHost= -Dhttps.proxyHost=' \
  flutter build apk --debug
```
