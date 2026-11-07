# 开发工具

这里的 Python 脚本只用于开发和只读导出，不是 Android 的默认数据通路。

## 文件

- `gmis_client.py`：GMIS 客户端（RSA 登录、Cookie、学期/课表/成绩/选课/ICS 等）。
- `gmis_cli.py`：命令行入口。
- `requirements.txt`：Python 依赖。

## 用法

```bash
python3 -m pip install -r tools/requirements.txt
python3 tools/gmis_cli.py login --user 2026201060 --cookies cookies.json
python3 tools/gmis_cli.py timetable --cookies cookies.json
```

密码只从 `GMIS_PASSWORD` 或交互提示读取，不接受命令行密码。`cookies.json` 和 `web/data/live.json` 已被忽略。
