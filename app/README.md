# 化研助手 Android / Flutter 壳

和 `web/` 预览同一套页面：引导、演示登录、首页、周课表、服务、我的。课表计算在 `lib/schedule.dart`，规则与 `web/js/schedule.mjs` 一致。数据是 `assets/snapshot.json`，它是指向 `web/data/snapshot.json` 的符号链接。

演示登录不连接学校。密码不写入偏好、快照或日志。学校页面只做说明，浏览器另开，应用里没有网页会话。考试和通知保持空态。选课三屏仍不编数据。

```bash
flutter test
flutter analyze
flutter build apk --release
```

`android/app/build.gradle.kts` 里的 release 构建仍使用 debug 签名，方便本机安装。正式上架前要换成自己的密钥。
