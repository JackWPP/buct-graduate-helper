# 化研助手 Android/iOS 客户端（项目主线）

`app/` 是项目主线，Android 优先，iOS 共用同一套 Flutter 代码。页面和交互与 `web/` 设计预览一致：引导、演示登录、首页、周课表、服务、我的。课表计算在 `lib/schedule.dart`，规则与 `web/js/schedule.mjs` 对齐。

数据是 `assets/snapshot.json`，已经是应用自己的普通文件副本，不再依赖 `web/`。演示登录不连接学校，验证码本地生成；密码不写入偏好、快照或日志。学校页面只做说明，浏览器另开，应用里没有网页会话。考试和通知保持空态，选课三屏在设计稿完成前不编数据。

以下命令都在 `app/` 目录执行：

```bash
flutter pub get
flutter test
flutter analyze
flutter build apk --debug
```

产物在 `build/app/outputs/flutter-apk/app-debug.apk`。`android/app/build.gradle.kts` 里的 release 构建仍使用 debug 签名，方便本机安装；正式上架前要换成自己的密钥。真实 GMIS 网络层尚未接入，下一步按 [`../AGENTS.md`](../AGENTS.md) 的 M0 做 Dart 适配层。
