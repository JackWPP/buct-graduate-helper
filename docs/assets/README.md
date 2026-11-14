# 视觉素材目录

这里放化研助手 GitHub README、Release 和社群分享用的成品图。素材以真实 App 截图为主，手机框内的界面不是重绘的概念稿；只有品牌插画例外。

## 当前选用（v1.9.0）

| 文件 | 尺寸 | 用途 |
| --- | ---: | --- |
| `banners/readme-hero.png` | 1600×700 | README 顶部主视觉，真实截图 |
| `banners/github-social-preview.png` | 1280×640 | GitHub 仓库 Social preview（在仓库设置中手动上传） |
| `banners/release-v1.9.0.png` | 1200×630 | v1.9.0 Release 顶部宣传图 |
| `banners/release-v1.8.0.png` | 1200×630 | v1.8.0 Release 顶部宣传图（保留） |
| `banners/release-v1.7.2.png` | 1200×630 | v1.7.2 Release 顶部宣传图（保留） |
| `screenshots/release-v1.9.0-gallery.png` | 1600×930 | v1.9.0 Release 正文截图（账号管理 / 自动重连 / 添加账号） |
| `screenshots/release-v1.8.0-gallery.png` | 1600×930 | v1.8.0 Release 正文截图（保留） |
| `screenshots/release-v1.7.2-gallery.png` | 1600×930 | v1.7.2 Release 正文截图（保留） |
| `features/01-timetable.png` | 1200×675 | 课表功能专题 |
| `features/02-activity-reminder-signup.png` | 1200×675 | 活动报名与课表联动专题（v1.8.0 更新） |
| `features/03-webvpn-bridge.png` | 1200×675 | 内置 WebVPN 桥接与校外访问专题 |
| `features/04-services.png` | 1200×675 | 49 项服务入口专题 |
| `screenshots/real-ui-gallery.png` | 1600×930 | 首页、日程、活动页真实截图合集（v1.8.0 更新） |
| `social/vertical-poster-3x4.png` | 1080×1440 | 朋友圈、小红书、群聊综合海报 |
| `social/activities-poster-3x4.png` | 1080×1440 | 活动提醒与报名专题海报 |

## 使用口径

- 每次发版必须新增或更新 `banners/release-v<版本>.png`，并至少有一张 `screenshots/release-v<版本>-*.png` 放在 Release 正文；没有图的 Release 不算完成。
- Release 图放在正文顶部，截图放在正文中段；图片先提交到 `main`，再更新 GitHub Release，保证 raw 链接可访问。
- README 首图用 `banners/readme-hero.png`；`features/*` 用于“核心体验”四宫格；`screenshots/real-ui-gallery.png` 用于“实际界面”。
- GitHub Social preview 需要在仓库 Settings → Social preview 手动上传 `banners/github-social-preview.png`，不能只靠提交文件生效。
- 社媒海报可直接使用，也可以按本地海报工具包里的提示词重新生成其他尺寸。

## 制作与更新规则

- 版本号必须出现在 Release 图上；旧版本图保留，不覆盖。
- 素材以真实 App 截图或 `UI_PREVIEW` 演示身份截图为准；不接受把手机 UI 重绘成虚构页面。
- 不使用二维码、学生个人信息、真实账号、密码、Cookie 或真实姓名。
- 项目身份统一为“学生自建，非学校官方产品，学业数据以 GMIS 为准”。
- 新增素材后同步更新本文件的“当前选用”表，并在 `docs/releases/<版本>.md` 中引用。

## 模板

- Banner 参考 `banners/release-v1.7.2.png`：左侧品牌、版本号、一句用户能感知的收益；右侧真实界面；底部 GitHub Releases。
- 截图合集参考 `screenshots/release-v1.7.2-gallery.png`：一句标题 + 一句说明 + 三张真实界面 + 每张一句图注。
