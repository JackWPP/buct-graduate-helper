# 数据样本

本目录只放构建网页预览和测试用的**学业字段样本**，不是 Android 默认数据源。

- `demo_output/`：从 GMIS 导出的课表、培养计划、已选课、成绩、评教、申请、菜单和学期信息；`web/build_snapshot.py` 用它生成 `web/data/snapshot.json`。
- `samples/`：各 GMIS 接口的响应样例，用于 Python 测试和字段对照。

不得提交密码、Cookie、验证码、证件号、电话、住址、邮箱等个人信息。`data/demo_output/profile.json` 和 `data/samples/xsxx_jbxx.json` 已在 `.gitignore` 中排除。
