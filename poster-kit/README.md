# 化研助手 · 海报素材包

这是一套“可直接投喂生图模型”的小海报素材包。目标不是让模型从零想象一个 App，而是让它基于真实截图、品牌标志和明确的版式参考，生成一张可以继续排版的产品海报。

## 先看什么

| 文件 | 用途 |
| --- | --- |
| `poster-layout-reference.png` | 1080×1440 的构图与视觉参考，决定图文位置、配色和层级 |
| `01-poster-brief.md` | 海报目标、受众、版式、字体、颜色、素材使用规则 |
| `02-image-prompt.md` | 可直接复制给生图模型的中文/英文提示词与负面词 |
| `03-copy-deck.md` | 海报上所有中英文文案，避免模型写错字 |
| `manifest.json` | 画幅、配色、素材和文案的机器可读清单 |
| `render_layout.py` | 生成 `poster-layout-reference.png` 的可复现脚本（Pillow + PingFang） |
| `assets/logo-1024.png` | 品牌标志 |
| `assets/screen-home.png` | 首页截图，已裁掉真实姓名，保留学期、评教、学分 |
| `assets/screen-timetable.jpg` | 周课表截图 |
| `assets/screen-services.jpg` | 49 项服务目录截图 |
| `assets/screen-webvpn.jpg` | 统一身份认证登录页截图，可选 |

## 直接使用流程

1. 打开生图模型，先上传 `poster-layout-reference.png` 作为构图参考。
2. 再上传 `assets/` 里的 `logo-1024.png`、`screen-home.png`、`screen-timetable.jpg`、`screen-services.jpg`。
3. 复制 `02-image-prompt.md` 的“直接出图版”提示词，整段粘贴。
4. 画幅选择 `3:4`，目标尺寸 `1080×1440`（或 2×：`2160×2880`）。
5. 如果模型把中文写错，改用提示词里的“留白排版版”，先生成无文字背景，再把 `03-copy-deck.md` 的文案用 Figma/Canva/PPT 叠上去。

## 设计原则

- 只表现真实产品：截图必须来自 `assets/`，不要让模型重画虚假的 UI。
- 文字要克制：标题、副标题、三条能力、下载信息，五层就够。
- 画面要像“产品海报”，不是“AI 概念图”：暖白纸感、钴蓝品牌色、细线、留白、编辑设计感。
- 不出现真实姓名、学号、手机号、二维码、Cookie、验证码或任何私人信息。
- 不承诺“官方产品”：页脚保留“不是学校官方产品，学业数据以 GMIS 为准”。

## 版本口径

- 产品：化研助手
- 版本：Android 测试版 `v1.7.0`（`versionCode 8`）
- 下载：`https://github.com/JackWPP/buct-graduate-helper/releases/tag/v1.7.0`
- 当前能力：5 Tab、49 项服务、真实 GMIS 数据、统一身份认证（含短信二次认证）、学术报告/劳动实践报名与自动监测。
