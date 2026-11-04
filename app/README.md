# 化研助手 Android / Flutter 壳

和 `web/` 预览同一套页面：首页、周课表、服务、我的。课表计算在 `lib/schedule.dart`，规则与 `web/js/schedule.mjs` 一致。数据是 `assets/snapshot.json`，它是指向 `web/data/snapshot.json` 的符号链接。

考试和通知保持空态。没有单独页面的服务入口只说明还没做，不编表单。

```bash
flutter test
flutter analyze
flutter build apk --release
```

`android/app/build.gradle.kts` 里的 release 构建仍使用 debug 签名，方便本机安装。正式上架前要换成自己的密钥。
