# 发版 SOP

这份文档规定化研助手每次对外发版要改哪些文件、出哪些图、Release 怎么写。目标是让每一版都做到：**用户点开 Release 就知道这版能做什么、长什么样、下载哪个文件**。

## 1. 三条硬规则

1. **每版必须有图**：Release 正文顶部一张版本 Banner，正文中至少一张真实界面截图；没有图的 Release 不算完成。
2. **Release 面向用户**：只写“这版能做什么”，不写“这版修了什么”、不写模块名、不写“哪一层过期”这类内部技术细节、不放验证情况/测试数据。
3. **版本号全同步**：代码、README、图片、Release、文档五处版本号必须一致，缺一处都算没发完。

## 2. 发版前必须更新的文件

| 文件 | 改什么 |
| --- | --- |
| `app/pubspec.yaml` | `version: x.y.z+n` |
| `app/lib/theme.dart` | `appVersionLabel` |
| `README.md` | Version badge、当前版本、发布说明链接、文档表；界面有变化时换 `docs/assets/features/*` 或 `screenshots/real-ui-gallery.png` |
| `docs/releases/v<版本>.md` | 本版 Release 正文（模板见第 4 节） |
| `docs/assets/banners/release-v<版本>.png` | 1200×630 版本 Banner |
| `docs/assets/screenshots/release-v<版本>-gallery.png` | 1600×930 真实界面截图合集 |
| `docs/assets/README.md` | “当前选用”表加入新图，版本号同步 |
| `docs/architecture.md` | 登录、存储、缓存等实现有变化时更新 |
| `docs/testing.md` | 测试/回归方式有变化时更新 |
| `AGENTS.md`、`docs/roadmap.md` | 本机维护记录：版本、验证结论、下一步（这两个文件不进公开仓库） |
| GitHub Release | 标题、正文、`huayan-<版本>.apk`、`huayan-<版本>.apk.sha256` |

## 3. 图片规范

- **Banner**：1200×630，左侧品牌 + 版本号 + 一句用户能感知的收益，右侧真实界面，底部 GitHub Releases。参考 `docs/assets/banners/release-v1.7.2.png`。
- **截图合集**：1600×930，一句标题 + 一句说明 + 三张真实界面 + 每张一句图注。参考 `docs/assets/screenshots/release-v1.7.2-gallery.png`。
- 手机里的界面必须是真实 App 截图或 `UI_PREVIEW` 演示身份截图；不重绘、不虚构页面。
- 不出现真实姓名、学号、密码、Cookie、验证码、二维码。
- 图片先提交到 `main`，确认 raw 链接可访问后，再更新 GitHub Release；Release 正文用绝对地址：
  `https://raw.githubusercontent.com/JackWPP/buct-graduate-helper/main/docs/assets/...`
- 旧版本的图保留，不覆盖；新版本新增自己的文件。

## 4. Release 正文模板

```markdown
# 化研助手 x.y.z

> Android 测试版 · YYYY-MM-DD

<p align="center">
  <img src="https://raw.githubusercontent.com/JackWPP/buct-graduate-helper/main/docs/assets/banners/release-vx.y.z.png" width="100%">
</p>

一句话说这版让用户多做到了什么，不写修复列表。

<p align="center">
  <img src="https://raw.githubusercontent.com/JackWPP/buct-graduate-helper/main/docs/assets/screenshots/release-vx.y.z-gallery.png" width="100%">
</p>

## 这版能做什么

- 用“打开就能……”的句式写 3–5 条，每条都是用户能感知的结果。
- 不写内部模块、接口名、缓存策略、过期分层。

## 下载

- 下载下方 `huayan-x.y.z.apk`。
- 支持 Android 8.0 及以上（minSdk 24）。
- 覆盖安装；签名不同时先卸载旧版。
- 测试版说明（debug 签名，不用于正式分发）。

## 关于数据

学生自建项目，非学校官方产品；数据以学校 GMIS 为准。
```

## 5. 发版步骤

1. **改代码与版本**：`pubspec.yaml`、`theme.dart` 升版本。
2. **跑检查**：`flutter analyze`、`flutter test`、`flutter build apk --debug`、`flutter build apk --release`。
3. **出图**：按第 3 节做 Banner 和截图合集，放进 `docs/assets/`，更新 `docs/assets/README.md`。
4. **写 Release 正文**：按第 4 节模板写 `docs/releases/v<版本>.md`。
5. **更新 README**：版本 badge、当前版本、发布说明链接、文档表；界面有变化就换功能图/截图。
6. **更新本机记录**：`AGENTS.md` 的验证记录、`docs/roadmap.md` 的版本与状态。
7. **提交并推 `main`**：确认 CI 的 `flutter` 与 `web` 都绿。
8. **算 SHA-256**：`sha256sum app/build/app/outputs/flutter-apk/app-release.apk`，写进 Release 正文。
9. **建 Release**：`gh release create v<版本> huayan-<版本>.apk huayan-<版本>.apk.sha256 --title "化研助手 <版本> · <一句话>" --notes-file docs/releases/v<版本>.md --target main`。
10. **验收**：打开 Release 页面，确认 Banner、截图、下载按钮都正常；确认 `huayan-<版本>.apk` 与 `.sha256` 都在。
11. **清理**：清掉模拟器上的真实会话、含个人信息的截图和临时探针文件。

## 6. 完成标准

- [ ] 五处版本号一致（代码、README、图片、Release、文档）。
- [ ] Release 顶部有 Banner，正文有至少一张真实界面截图。
- [ ] Release 正文没有“修复列表”“验证情况”和内部技术细节。
- [ ] README 的版本、发布说明链接、文档表都已更新，`## 安全边界` 不再出现在 README。
- [ ] `docs/assets/README.md` 已加入本版图片。
- [ ] CI 全绿，Release 资产完整，图片能正常显示。
