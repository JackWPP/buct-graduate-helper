# 化研助手 Android/iOS 客户端（项目主线）

`app/` 是项目主线，Android 优先，iOS 共用同一套 Flutter 代码。默认入口是 `lib/live_shell.dart`：引导 → 真实 GMIS 登录 → 首页、周课表、服务、我的。课表计算在 `lib/schedule.dart`，规则与 `web/js/schedule.mjs` 对齐。

## 数据与登录

- 真实模式通过 `lib/gmis/` 访问学校接口：验证码图、RSA 登录、Cookie、课表、已选课、成绩、评教、通知、考场、选课只读列表和服务菜单。
- 登录成功后 Cookie 写系统安全存储（`flutter_secure_storage`），密码只在本次登录内存里使用，不写偏好、快照或日志。
- 离线/启动时读本机 `SnapshotCache`；没有登录会话时不展示缓存。
- `assets/snapshot.json` 只用于组件测试、截图和旧演示路径（`HuayanApp(snapshot: ...)` / `skipGate`），不是默认启动数据。
- 选课提交/退选、后台提醒和深色模式还没做；选课页明确只读。

真实登录需要手机能访问 `gmis.buct.edu.cn`（校园网或 VPN）和自己的研究生账号。仓库里没有可用账号，也不保存任何账号。

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
