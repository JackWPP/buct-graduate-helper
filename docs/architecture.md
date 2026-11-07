# 架构与数据流

## 三块怎么接

```text
┌──────────────────────────────┐
│ Android / iOS（Flutter）      │
│ app/                          │
│  ├─ live_shell.dart           │  5 Tab 与页面路由
│  ├─ app_controller.dart       │  启动/登录/刷新/退出状态机
│  ├─ gmis/                     │  GMIS 适配层
│  ├─ webvpn/                   │  网页版 VPN / 统一身份认证
│  ├─ storage/                  │  安全会话与快照缓存
│  └─ selection_page.dart       │  选课提交
└──────────────┬───────────────┘
               │ HTTPS
               ▼
┌──────────────────────────────┐
│ 学校系统                      │
│ w.buct.edu.cn（网页版 VPN）    │
│ gmis.buct.edu.cn（GMIS）       │
└──────────────┬───────────────┘
               │ 只读导出（可选）
               ▼
┌──────────────────────────────┐
│ web/ 390px 设计预览            │
│ web/data/snapshot.json        │
│ web/data/live.json（忽略）     │
└──────────────────────────────┘
```

## Android 主线

`app/` 是项目主线，Android 优先，iOS 共用同一套 Flutter 代码。

- **入口**：`app/lib/live_shell.dart` 负责引导、登录、5 Tab 和页面路由。
- **状态机**：`app/lib/app_controller.dart` 管理 `booting / signedOut / restoring / ready / offline / sessionExpired`。
- **GMIS 适配层**：`app/lib/gmis/gmis_client.dart` 负责登录、Cookie、302 会话过期和 JSON 解析；`gmis_api.dart` 封装业务接口。
- **数据装配**：`app/lib/gmis/live_snapshot_builder.dart` 把学生卡、已选课、培养计划、成绩、评教、通知、考场、选课列表和服务菜单装配成 `Snapshot`（schemaVersion=2）。
- **缓存**：`app/lib/storage/snapshot_cache.dart` 写应用支持目录；`secure_session_store.dart` 用 `flutter_secure_storage` 存会话。
- **登录**：`app/lib/webvpn/` 负责网页版 VPN 和统一身份认证（含短信 2FA）；`live_login_page.dart` 负责 GMIS 验证码登录。SSO 成功后学号/密码只保留在内存并预填，用户只补图形验证码。

## 登录链路

```text
启动
  → 读取 PrefsStore（引导/学号/设置）
  → 读取 SecureSessionStore（是否有 WebVPN / GMIS 会话）
  → 默认进入原生统一身份认证
       ├─ 学号 + 密码（AES-128-ECB 加密）
       ├─ 若学校要求：短信验证码二次认证
       └─ CAS ticket → wengine_vpn_ticket
  → GMIS 验证码登录（RSA 加密密码；SSO 学号/密码仅内存预填）
  → GmisClient 拉取接口
  → LiveSnapshotBuilder 生成 Snapshot v2
  → SnapshotCache 缓存 + 进入 5 Tab
```

校外默认走 `w.buct.edu.cn`。校内可直接使用 `--dart-define=DIRECT_GMIS=true` 切回 `gmis.buct.edu.cn`。

## 缓存与会话

- 没有登录会话时**不展示缓存**，避免未登录看到课表。
- 有会话时先显示缓存，再后台刷新；刷新失败保留缓存并提示。
- 退出登录会清空会话和缓存。
- `TermCalendar` 内置 55 学期 = `2026-08-31`；未知学期会提示周次可能不准，用户选择的第 1 周周一优先。

## 网页预览

`web/` 是 390px 可点击设计预览，不参与 Android 默认数据通路：

- 优先读 `web/data/live.json`（被忽略），没有则读 `web/data/snapshot.json`
- 课表计算在 `web/js/schedule.mjs`，与 `app/lib/schedule.dart` 保持同一套规则
- 用于设计回归和旧演示路径

## Python 只读导出

`tools/gmis_client.py` / `tools/gmis_cli.py` 仍保留为开发工具：

- 登录、验证码、Cookie、课表、ICS
- `tools/gmis_cli.py timetable` 可把只读课表写到 `web/data/live.json`
- 不参与 Android 默认数据通路

## 安全边界

- 密码只用于登录请求，不落盘、不写日志。
- 登录 Cookie 只进系统安全存储。
- 快照只保留课表和培养进度需要的学业字段。
- 仓库不包含学校账号、Cookie、验证码、证件号、电话、住址或邮箱。
