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
- **状态机**：`app/lib/app_controller.dart` 管理 `booting / signedOut / restoring / ready / offline / sessionExpired / webVpnExpired`。
- **GMIS 适配层**：`app/lib/gmis/gmis_client.dart` 负责登录、GMIS Cookie、JSON 解析和 302 分类；`gmis_api.dart` 封装业务接口。WebVPN ticket 由 `app/lib/webvpn/` 单独注入，不进入 GMIS Cookie。
- **数据装配**：`app/lib/gmis/live_snapshot_builder.dart` 把学生卡、已选课、培养计划、成绩、评教、通知、考场、选课列表和服务菜单装配成 `Snapshot`（schemaVersion=2）。
- **缓存**：`app/lib/storage/snapshot_cache.dart` 写应用支持目录；`secure_session_store.dart` 用 `flutter_secure_storage` 存 GMIS 会话；`webvpn_credential_store.dart` 只存 WebVPN ticket 和元数据；`sso_session_store.dart` 单独存统一身份认证的长期会话 Cookie（TGC/SESSION），用于 ticket 过期时静默续签；`auth/gmis_password_vault.dart` 可选保存 GMIS 密码（180 天上限，退出登录/手动清除即删除）。
- **登录**：`app/lib/webvpn/` 负责网页版 VPN、统一身份认证（含短信 2FA）、ticket 校验和会话状态；`live_login_page.dart` 负责 GMIS 验证码登录。SSO 成功后学号/密码先在内存里预填；GMIS 登录页默认勾选“保持登录”，成功登录后密码写入系统安全存储，供下次预填。

## 登录链路

```text
启动
  → 读取 PrefsStore（引导/学号/设置）
  → 读取 WebVpnCredentialStore（ticket + 元数据）
  → 有 ticket：请求受保护页面做轻量校验
       ├─ 200 / 302 目标页 → ticket 有效
       ├─ 302 门户 /login  → ticket 过期，清 ticket，进入 SSO
       └─ 网络错误         → 保留 ticket，进入离线
  → 有有效 ticket 且 GMIS 会话存在 → 先显示缓存，再后台刷新
  → 有有效 ticket 但没有 GMIS 会话 → 直接进入 GMIS 验证码登录
  → ticket 过期但留有 SSO 会话 → 静默换新 ticket，再按上面的规则继续
  → ticket 和 SSO 会话都失效 → 统一身份认证登录页
  → 默认进入原生统一身份认证
       ├─ 学号 + 密码（AES-128-ECB 加密）
       ├─ 若学校要求：短信验证码二次认证
       └─ 重定向链上的 ticket 候选 → 逐个校验，匿名 ticket 不接受
  → GMIS 验证码登录（RSA 加密密码；SSO 学号/密码仅内存预填）
  → GmisClient 拉取接口
  → LiveSnapshotBuilder 生成 Snapshot v2
  → SnapshotCache 缓存 + 进入 5 Tab
```

校外默认走 `w.buct.edu.cn`。校内可直接使用 `--dart-define=DIRECT_GMIS=true` 切回 `gmis.buct.edu.cn`。

## 缓存与会话

- 没有登录会话时**不展示缓存**，避免未登录看到课表。
- 有会话时先显示缓存，再后台刷新；刷新失败保留缓存并提示。
- WebVPN 过期时先用 `webvpn_silent_login.dart` 留存 SSO 会话静默换新 ticket；续签成功继续当前流程，失败才清 ticket 和 WebView Cookie、回统一身份认证。
- GMIS 过期只清 GMIS 会话，保留 ticket，回 GMIS 验证码登录。
- 网络错误不清 ticket；恢复后重新校验。
- 退出登录会清空 WebVPN ticket、SSO 会话、GMIS 会话、缓存和 WebView Cookie。
- `TermCalendar` 内置 55 学期 = `2026-08-31`；未知学期会提示周次可能不准，用户选择的第 1 周周一优先。

## 网页预览

`web/` 是 390px 可点击设计预览，不参与 Android 默认数据通路：

- 优先读 `web/data/live.json`（被忽略），没有则读 `web/data/snapshot.json`
- 课表计算在 `web/js/schedule.mjs`，与 `app/lib/schedule.dart` 保持同一套规则
- 用于设计回归和旧演示路径

## 数据边界

网页预览只读 `web/data/snapshot.json`；学校接口、Python 工具和接口笔记只在本地开发环境维护，不随仓库发布，也不参与 Android 默认数据通路。

## 安全边界

- 密码只用于登录请求，不落盘、不写日志。
- 登录 Cookie 只进系统安全存储。
- 快照只保留课表和培养进度需要的学业字段。
- 仓库不包含学校账号、Cookie、验证码、证件号、电话、住址或邮箱。
