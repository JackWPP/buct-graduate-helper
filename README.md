# 化研助手 · GMIS API 工作区

## 交付物

| 文件 | 内容 |
| --- | --- |
| `GMIS_API.md` | 完整接口文档：登录、公共数据、个人管理、培养管理、选课、课表、成绩、研工、科研、毕业、数据字典、ICS 算法、App 页面映射 |
| `API_INDEX.md` | 按 49 个页面分组的接口索引，列出方法、路径、参数 |
| `api_catalog.json` | 165 个页面 JS 接口的结构化清单（`page,endpoint,method,params`） |
| `endpoint_catalog.json` | 页面路径 -> 页面 JS 中出现的接口路径 |
| `crawl_log.json` | 52 个页面的实际访问记录与 90 个 XHR 响应样本 |
| `samples/` | 关键接口的原始 JSON 样本 |
| `gmis_client.py` | Python 客户端：RSA 登录、Cookie 持久化、全部主要接口封装、ICS 生成 |
| `gmis_cli.py` | 命令行工具：登录、导出、课表 ICS、课程查询、选课/退选 |
| `demo_output/` | 实测导出：学生信息、菜单、学期、培养计划、成绩、课表、已选课、ICS |
| `pages_all/` | 49 个学生端页面 HTML 源码 |
| `PRD.md` | 产品需求文档 v0.3（讨论稿）：定位、功能、技术方案、版本规划、待拍板决策 |
| `research/competitor_analysis.md` | 竞品与北化研究生数字化工具调研 |
| `research/feature_api_matrix.md` | 49 页功能-API 映射与移动端可行性评估 |

## 快速开始

```bash
python3 -m pip install -r requirements.txt
python3 gmis_cli.py login --user 2026201060 --cookies cookies.json
python3 gmis_cli.py dump --cookies cookies.json --out demo_output
python3 gmis_cli.py ics --cookies cookies.json --term 55 --start 2026-08-31 --out demo_output/timetable_term55.ics
cd web && python3 -m http.server 8899
```

登录命令会先把验证码 GIF 存成 `captcha_*.png`，终端输入 4 位数字即可。密码在提示符输入，或放到环境变量 `GMIS_PASSWORD`，不要写进仓库。`login` 成功后 Cookie 写入 `cookies.json`；后续命令复用该文件，接口返回 302 时重新执行 `login`。

网页预览打开 http://127.0.0.1:8899/ 。云端接着做的约定在 [AGENTS.md](AGENTS.md)。

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

## 关键约束

- 登录 RSA 公钥每次 GET `/home/stulogin` 都变，必须从当前页面 `#pubkey` 解析。
- 所有业务接口返回 JSON 文本但 `Content-Type` 为 `text/html`，按文本解析。
- `__SINDEXCOOKIE__` + `ASP.NET_SessionId` 一起保存；会话闲置后 302 到 `/home/stulogin`。
- 选课验证码是 `GET /home/verificationcode?codetype=xkyzm`，与登录验证码 `stucode` 不同。
- `py_kbcx_ew.week` 是当前星期英文，不是教学周；教学周用 `py_kbcx_yw` 的 `ksz/jsz`。

## 文档入口

- [PRD.md](PRD.md)
- [GMIS_API.md](GMIS_API.md)
- [API_INDEX.md](API_INDEX.md)
- [gmis_client.py](gmis_client.py)
- [gmis_cli.py](gmis_cli.py)
