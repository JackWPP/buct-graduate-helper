<p align="center">
  <img src="design/brand/icon-256.png" width="96" alt="化研助手标志：蓝底圆角方块中的苯环，环内是三节不同颜色的课">
</p>

<h1 align="center">化研助手</h1>

<p align="center">北京化工大学研究生管理系统的移动层。<br>课表、培养进度和办事入口先在手机上读清。密码不离开自己的设备。</p>

网页预览用 2026-10-30 导出的课表快照，本身不连接学校服务器。Flutter 壳读同一份快照，周次和节次用同一套规则。学校接口是可选的只读补充。

## 界面

390px 宽的网页预览。长课名在格子里折成两行，服务页最后一组停在底部导航上方。

<table>
  <tr>
    <td align="center"><img src="docs/images/home.jpg" width="220" alt="首页：当天下午正在上的课、评教提醒和培养进度"></td>
    <td align="center"><img src="docs/images/timetable.jpg" width="220" alt="第 10 周课表，分子探针与诊疗新技术折成两行"></td>
    <td align="center"><img src="docs/images/services.jpg" width="220" alt="服务宫格，毕业与学位和网上考试完整露出"></td>
  </tr>
  <tr>
    <td align="center">首页</td>
    <td align="center">周课表</td>
    <td align="center">服务</td>
  </tr>
</table>

选课三屏、考试倒计时和通知列表还没有学校数据，页面保持空态。

## 三块怎么接在一起

<img src="docs/images/layers.png" alt="网页预览、Flutter 壳和学校接口共用 web/data/snapshot.json">

## 标志

<img src="design/brand/icon.svg" width="128" alt="化研助手标志">

外圈是苯环，里面三节颜色不同的课。主色 `#2F6BFF`，另外两节用课程色 `#7C5CFF` 和 `#12A05C`，底色 `#F5F7FA`。标志是自建的，图标里不放校徽。

矢量源文件在 [`design/brand/icon.svg`](design/brand/icon.svg)。改完图形后运行：

```bash
python3 design/brand/render_logo.py
```

这会重写网页图标、Flutter Web 图标，以及 Android、iOS 的启动图标。

## 跑起来

```bash
python3 -m pip install -r requirements.txt
python3 gmis_cli.py login --user 2026201060 --cookies cookies.json
python3 gmis_cli.py timetable --cookies cookies.json
cd web && python3 -m http.server 8899
```

登录会把学校返回的验证码图存进临时目录，终端输入 4 位数字后图片即删。密码只从环境变量 `GMIS_PASSWORD` 或交互提示读取。`login` 成功后 Cookie 写入 `cookies.json`（已被忽略）。接口返回 302 时重新执行 `login`。

`timetable` 写成 `web/data/live.json`。预览优先读它，没有就继续用 `web/data/snapshot.json`。`live.json` 不提交。

网页预览打开 http://127.0.0.1:8899/ 。云端接着做的约定在 [AGENTS.md](AGENTS.md)。

Flutter 壳在 `app/`。本机装好 Flutter 3.47 后：

```bash
cd app
flutter test
flutter build web
```

`flutter build apk` 还需要 Android SDK。已发布的 Android 包在 [v1.0.0](https://github.com/JackWPP/buct-graduate-helper/releases/tag/v1.0.0)，用调试证书签名，用来侧载试装。

## 仓库里有什么

| 文件 | 内容 |
| --- | --- |
| `web/` | 可点击的手机网页预览 |
| `app/` | Flutter 壳，Android、iOS、Web |
| `gmis_client.py` | Python 客户端：RSA 登录、Cookie、主要接口、ICS |
| `gmis_cli.py` | 命令行：登录、导出、课表 ICS、课程查询 |
| `GMIS_API.md` | 接口文档：登录、培养、选课、课表、成绩、研工、科研、毕业 |
| `API_INDEX.md` | 按 49 个页面分组的接口索引 |
| `PRD.md` | 产品需求 v0.3 |
| `design/` | 设计说明、导出稿和标志 |
| `research/` | 竞品调研和功能-接口对照 |

## Python 调用

```python
from gmis_client import GmisClient

c = GmisClient()
c.login(lambda gif: input("验证码: "), "2026201060", input("密码: "))

print(c.card())                    # 学生信息
print(c.terms()[0])                # 当前学期
print(c.timetable("55"))           # 课表网格
print(c.selected_courses("55"))    # 已选课列表
print(c.grades())                  # 成绩
print(c.course_list(lb="3", rows=20))  # 选课列表
```

课表导入：

```python
from gmis_client import GmisClient, build_ics
c = GmisClient(); c.load_cookies("cookies.json")
open("课表.ics", "w", encoding="utf-8").write(
    build_ics(c.selected_courses("55"), term_start="2026-08-31")
)
```

## 对接学校时要注意

- 登录 RSA 公钥每次 GET `/home/stulogin` 都变，必须从当前页面 `#pubkey` 解析。
- 业务接口的正文是 JSON，`Content-Type` 却是 `text/html`，按文本解析。
- `__SINDEXCOOKIE__` 和 `ASP.NET_SessionId` 一起保存。会话闲置后会 302 到 `/home/stulogin`。
- 选课验证码是 `GET /home/verificationcode?codetype=xkyzm`，和登录验证码 `stucode` 不同。
- `py_kbcx_ew.week` 是当前星期的英文，不是教学周。教学周用 `py_kbcx_yw` 的 `ksz` / `jsz`。
- 密码、Cookie、验证码、证件号、电话、住址、邮箱不进代码、快照、文档或提交。

## 文档

- [PRD.md](PRD.md)
- [design/02-handoff.md](design/02-handoff.md)
- [GMIS_API.md](GMIS_API.md)
- [API_INDEX.md](API_INDEX.md)
- [gmis_client.py](gmis_client.py)
- [gmis_cli.py](gmis_cli.py)
