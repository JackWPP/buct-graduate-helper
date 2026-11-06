# 云端继续：化研助手

这是北京化工大学研究生管理系统的移动增强层。产品定义在 `PRD.md`，设计在 `design/`。**Android 版在 `app/`，是项目主线**；`web/` 是 390px 可点击的设计预览和回归参照，不再是功能主线。学校接口客户端是 `gmis_client.py` 和 `gmis_cli.py`。

云端代理从这里接着做，不要重开一套产品。

## 现在到哪了

Android 版（Flutter）已经能走通引导、演示登录、首页、周课表、课程详情、服务搜索、成绩空态、培养进度和设置，和网页预览同一套页面与课表规则。第一次打开先看引导。登录只核对快照里的演示学号、非空密码和按钮上的本地验证码，密码只留在内存里，提交后清掉，不进偏好。记住的学号、提醒、课程颜色写在本机 `shared_preferences`。首页在有未评课程时显示评教卡。课表可以横滑换周。课程详情可以开关单课提醒，并分享 ICS；提醒只在应用打开时出现，22:00–07:00 不提示，没有后台闹钟。学校入口只说明会打开 `gmis.buct.edu.cn` 上 `/student/` 开头的页面，不内嵌网页，也不代持会话。考试和通知仍然是空态。

Android 版当前读 `app/assets/snapshot.json`（2026-10-30 课表导出的普通文件副本），没有真实 GMIS 网络层。登录是演示登录，验证码本地生成。

网页预览仍是设计参照：`web/data/snapshot.json` 来自同一份导出，预览本身不连接学校服务器；`gmis_cli.py login` 用学校返回的验证码图，密码只从 `GMIS_PASSWORD` 或交互输入读取，Cookie 写进被忽略的 `cookies.json`。`gmis_cli.py timetable` 把只读课表写到被忽略的 `web/data/live.json`，预览优先读它；这份能力目前只服务网页预览。

## 下一轮按这个顺序

1. M0：在 `app/lib/` 里做 Dart 版 GMIS 适配层（登录、验证码、课表、选课列表），把登录页接到真实学校验证码；先在真机跑通 3 个核心接口，会话过期可重登。不要用编造数据填选课、成绩、考试或通知。
2. 选课三屏、考试倒计时、真实通知列表，设计稿没画完之前不要编数据。导出文件是空的，页面保持空态。
3. Android release 换正式签名密钥；iOS 包要在 macOS 上用 Xcode 打。
4. 深色模式设计写了跟随系统，网页预览还没做，Android 版也先保持浅色。

## 不能碰的数据

不要把密码、Cookie、验证码、证件号、电话、住址、邮箱写进代码、快照、文档或提交。这些原始文件留在本机，被 `.gitignore` 排除。`app/assets/snapshot.json` 和 `web/data/snapshot.json` 只保留课表和培养进度需要的学业字段。

## 验证命令

Android（主线）：

```bash
cd app
flutter test
flutter analyze
flutter build apk --debug
```

改课表计算后同时跑两边规则：

```bash
node --test web/js/schedule.test.mjs
cd app && flutter test
```

预览：

```bash
cd web && python3 -m http.server 8899
```

云端环境会在启动时执行 `.cursor/environment.json` 的 `start`，页面在 8899 端口。
