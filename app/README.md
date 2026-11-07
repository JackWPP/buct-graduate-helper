# 化研助手 Android/iOS 客户端（项目主线）

`app/` 是项目主线，Android 优先，iOS 共用同一套 Flutter 代码。默认入口是 `lib/live_shell.dart`：引导 → 真实 GMIS 登录 → 首页、课表、学业、服务、我的（5 Tab）。服务页是扁平目录，48 项入口全部应用内直达，不再经过分组页或系统浏览器。课表计算在 `lib/schedule.dart`，规则与 `web/js/schedule.mjs` 对齐。

## 数据与登录

- 默认访问模式是网页版 VPN：启动后先进入 `lib/webvpn/sso_login_page.dart` 的原生统一身份认证（`lib/webvpn/webvpn_auth_client.dart` 直接提交 SSO 表单），拿到 `wengine_vpn_ticket` 后再进入 `lib/live_login_page.dart` 的 GMIS 验证码登录。
- 真实模式通过 `lib/gmis/` 访问学校接口：验证码图、RSA 登录、Cookie、课表、已选课、成绩、评教、通知、考场、选课列表和服务菜单。
- 登录成功后 Cookie 写系统安全存储（`flutter_secure_storage`），密码只在本次登录内存里使用，不写偏好、快照或日志。
- `lib/webvpn/webvpn_login_page.dart` 保留为 WebView 兜底；`--dart-define=DIRECT_GMIS=true` 可切回校内直连。
- 离线/启动时读本机 `SnapshotCache`；没有登录会话时不展示缓存。
- `assets/snapshot.json` 只用于组件测试、截图和旧演示路径（`HuayanApp(snapshot: ...)` / `skipGate`），不是默认启动数据。
- 选课可以提交/退课：二次确认 → 选课验证码（`xkyzm`）→ 提交，成功刷新课表与学分；后台提醒和深色模式还没做。

默认登录需要手机能访问 `w.buct.edu.cn` 的统一身份认证；校内直连需要 `gmis.buct.edu.cn`（校园网/VPN）。两种方式都需要自己的研究生账号，仓库里没有可用账号，也不保存任何账号。

## 跑起来

以下命令都在 `app/` 目录执行：

```bash
flutter pub get
flutter test
flutter analyze
flutter build apk --debug
flutter build apk --release
```

产物在 `build/app/outputs/flutter-apk/`。`android/app/build.gradle.kts` 会在 `android/key.properties` 存在时使用正式 release 签名，否则回退 debug 签名并打警告；正式上架前要换自己的密钥。iOS 包需要 macOS + Xcode。

测试覆盖课表规则、登录门禁、真实适配层的公钥解析/RSA 密文/会话恢复、快照 v2 与缓存、Demo 网关。后续工作按 [`../AGENTS.md`](../AGENTS.md) 的顺序。
