# 北京化工大学 GMIS 研究生管理系统学生端 API

目标：化研助手 App（Android / iOS）复用 Web 端全部能力，并增加课表导入与选课。
实测账号：2026201060（王海翔，化学学院，化学工程与技术，2026 级，全日制学术学位硕士）。
实测学期：2026-2027 秋季学期，`termcode=55`。

## 1. 连接参数

| 项目 | 值 |
| --- | --- |
| Base URL | `https://gmis.buct.edu.cn` |
| 登录页 | `/home/stulogin` |
| 登录提交 | `POST /home/stulogin_do` |
| 验证码 | `GET /home/verificationcode?codetype=stucode` |
| 退出 | `GET /home/logout?js=xs` |
| 协议 | HTTPS |
| 编码 | UTF-8 |
| 响应 | 业务接口返回 JSON 文本，`Content-Type` 仍为 `text/html; charset=utf-8` |

请求头基线：

```http
User-Agent: Mozilla/5.0 (Linux; Android 14) AppleWebKit/537.36 Chrome/126.0 Mobile Safari/537.36
Accept: application/json, text/javascript, */*; q=0.01
X-Requested-With: XMLHttpRequest
Referer: https://gmis.buct.edu.cn/student/default/index
Cookie: ASP.NET_SessionId=...; __SINDEXCOOKIE__=...
```

客户端解析响应时直接 `json.loads(response.text)`，不要用 `Content-Type` 判断是否为 JSON。

`__SINDEXCOOKIE__` 是学生端登录态核心，必须与 `ASP.NET_SessionId` 一起保存。会话闲置后接口返回 `302 Location: /home/stulogin`，客户端收到 302 直接进入重新登录流程。

## 2. 登录流程

### 2.1 学生端登录

1. `GET /home/stulogin`，保存服务端 Set-Cookie，同时从 HTML 中读取本次页面动态生成的 RSA 公钥：

```html
<input id="pubkey" type="hidden" value='-----BEGIN PUBLIC KEY-----...-----END PUBLIC KEY-----' />
```

2. `GET /home/verificationcode?codetype=stucode&t=<毫秒时间戳>`，返回 GIF，尺寸 102×46。

3. 用 RSA PKCS#1 v1.5 加密密码：

```python
from cryptography.hazmat.primitives import serialization, padding
key = serialization.load_pem_public_key(pubkey_pem.encode())
encrypted = key.encrypt(password.encode(), padding.PKCS1v15())
password_b64 = base64.b64encode(encrypted).decode()
```

4. `POST /home/stulogin_do`，表单字段名为 `json`，值为一个 JSON 字符串：

```json
{"UserId":"2026201060","Password":"<password_b64>","VeriCode":"2653","url":"","city":""}
```

请求示例：

```bash
curl -s 'https://gmis.buct.edu.cn/home/stulogin_do' \
  -H 'Content-Type: application/x-www-form-urlencoded' \
  --data-urlencode 'json={"UserId":"2026201060","Password":"<password_b64>","VeriCode":"2653","url":"","city":""}'
```

5. 成功响应：

```json
{"jg":"1","url":"student/default/index"}
```

失败响应：

```json
{"jg":"0","msg":"验证码错误"}
```

6. 成功后 `GET /student/default/index` 完成会话初始化，得到 `ASP.NET_SessionId` 与 `__SINDEXCOOKIE__`。

### 2.2 登录坑

`#pubkey` 每次打开 `/home/stulogin` 都会变化。把旧页面的公钥硬编码后提交，`/home/stulogin_do` 返回 500，正文异常为：

```text
Org.BouncyCastle.Crypto.InvalidCipherTextException: block incorrect
```

正确做法：每次登录重新 GET `/home/stulogin` 并解析当前 `#pubkey`。验证码错误时整页重新走一遍，不复用旧公钥。

### 2.3 选课验证码

选课提交需要第二个验证码：

```text
GET /home/verificationcode?codetype=xkyzm&t=<毫秒时间戳>
```

返回 GIF，同样交给用户输入。`xkyzm` 与登录验证码 `stucode` 是两套接口。

## 3. 首页与公共数据

| 方法 | 路径 | 参数 | 说明 |
| --- | --- | --- | --- |
| GET | `/student/default/MenuleftInfo` | `_` 毫秒时间戳 | 完整菜单树 |
| GET | `/student/default/getxscardinfo` | 无 | 学生卡片：`xh,xm,xsmc,zymc,xslb,dsxm,nj` |
| GET | `/student/default/bindterm` | 无 | 学期列表：`termcode,termname,selected` |
| GET | `/student/default/bindyxsh` | 无 | 院系列表：`xsbh,xsmc` |
| GET | `/student/default/getxfwcqk` | `type=xfqk` | 学分完成情况：总学分/必修/选修 |
| POST | `/student/default/gethomepagesw` | 无 | 首页流程卡片：注册、培养计划、选课等 |
| POST | `/student/default/index_position` | `p=/student/default/home` | 当前学期文本 |
| POST | `/student/default/getUnReadTzxx` | 无 | 未读通知计数 `{"wdtz":"0","wdzx":0}` |
| POST | `/student/default/getUnRemindTzxx` | 无 | 未提醒通知列表 |
| POST | `/student/default/getxsxyyj` | 无 | 学业预警：成绩/学籍/学分/开题/答辩 |
| POST | `/student/default/getwelcomdata` | 无 | 欢迎页：学生信息、学校信息、密码规则 |
| POST | `/student/default/checkIsFisrtLogin` | 无 | 是否首次登录，返回 `1`/`0` |
| POST | `/student/grgl/getxyjcinfo` | 无 | 学业进程节点与完成日期 |

菜单一级结构：

| 一级菜单 | 二级页面 |
| --- | --- |
| 个人管理 | 个人基本信息、学业进程查看、学期报到注册、新生入学登记、新生录取复查、个人信息维护、乘车区间维护、学籍异动申请、等级考试管理、等级考试成绩、照片信息核对、网上考试测评 |
| 培养管理 | 培养方案查看、培养计划提交、培养计划查询、课程免修申请、课程开课一览、学生网上选课、选课结果查询、学生课表查询、调课信息查询、课程考场查询、课程成绩查询、全校课程总目录、重缓补考申请、课程教学评价、国际学术交流申请、专业实践（科研/学习）外出审核 |
| 研工管理 | 学年鉴定登记、评优评干申请、困难资助申请、三助岗位申请、学术报告申请、校外实习申请、劳动实践申请、体育活动申请、体育运动免修申请 |
| 科研管理 | 发表论文登记、其他创新性成果登记、专利情况登记、科研成果奖励登记 |
| 毕业与学位 | 开题报告申请、提交开题报告、中期报告申请、提交中期报告、硕士查重盲审申请、查重盲审论文提交、学生学位申请 |

## 4. 个人管理

### 4.1 个人基本信息

`GET /student/grgl/xsxx_jbxx` 返回：

```json
{
  "jbxx": {
    "xh": "2026201060",
    "xm": "王海翔",
    "passwd": "<MD5>",
    "zydm": "081700",
    "xslb": "2",
    "nj": "2026",
    "yxsh": "021",
    "rxrq": "2026-09-09",
    "bdrq": "2026-09-09",
    "xmpy": "WANGHAIXIANG",
    "xbm": "1",
    "csrq": "2003-06-13",
    "zjlx": "01",
    "sfzh": "..."
  },
  "gzjl": [],
  "jtcy": [],
  "rxcj": [],
  "xjyd": []
}
```

同页其余 tab：

| 方法 | 路径 | 参数 | 内容 |
| --- | --- | --- | --- |
| GET | `/student/grgl/xsxx_byxw` | 无 | 培养计划课程 |
| POST | `/student/grgl/xsxx_jcjl` | 无 | 奖惩记录 |
| GET | `/student/grgl/xsxx_ktzq` | 无 | 开题情况 |
| POST | `/student/grgl/xsxx_kylw` | 无 | 科研论文 |
| POST | `/student/pygl/pyjhcxlist` | 无 | 培养计划课程明细 |
| GET | `/student/pygl/xscjcx_list` | 无 | 成绩汇总，字段见 5.7 |

### 4.2 个人信息维护

| 方法 | 路径 | 参数 | 说明 |
| --- | --- | --- | --- |
| GET | `/student/grgl/getxxlrkz` | 无 | 可修改字段清单：`zddm,kjlx` |
| POST | `/student/grgl/xgxx` | `xjjsonstr` JSON 字符串、`editfield` 逗号分隔字段名 | 提交修改，成功返回文本 `true` |
| GET | `/student/grgl/Dmwh_getZyByyxbh` | `xsbh` 院系代码 | 按院系取专业列表 |
| POST | `/student/grgl/ccqj_getzmdrop` | `sm` | 乘车区间站点下拉 |
| POST | `/student/grgl/grxxxg_uploadzp` | multipart | 上传照片 |

### 4.3 新生入学登记与录取复查

| 方法 | 路径 | 参数 |
| --- | --- | --- |
| GET | `/student/grgl/Dmwh_getZyByyxbh` | `xsbh` |
| POST | `/student/grgl/getxxgzjl` | 无 |
| POST | `/student/grgl/savexxgzjl` | 表单 JSON |
| POST | `/student/grgl/deletexxgzjl` | `id` |
| POST | `/student/grgl/getjtzcxx` | 无 |
| POST | `/student/grgl/savejtcy` | 表单 JSON |
| POST | `/student/grgl/deletejtzcry` | `id` |
| POST | `/student/grgl/updatexjinfo` | 学籍信息 JSON |
| POST | `/student/grgl/xsrxdjdy_new` | `xhs`，返回登记表打印页 |
| POST | `/student/grgl/init_xslqfc` | 无 |
| POST | `/student/grgl/submit_xslqfc` | 表单 JSON |
| POST | `/student/grgl/xlrz_upload` | multipart，`json` 参数 |
| POST | `/student/grgl/xwzs_upload` | multipart |

### 4.4 学期报到注册

| 方法 | 路径 | 参数 | 返回 |
| --- | --- | --- | --- |
| POST | `/student/grgl/getzcxx` | 无 | `{"termname":"2026-2027秋季学期","zcsj":"2026-08-24至2026-10-01","xdxq":"1","dqzt":"已注册","zcsm":""}` |
| POST | `/student/grgl/bindXsZcXx` | 无 | 注册批次信息 |
| POST | `/student/grgl/xszcaction` | 无 | 执行注册 |

`dqzt` 为当前注册状态：`已注册` / `未注册`。

### 4.5 乘车区间、学籍异动、等级考试

| 方法 | 路径 | 参数 | 说明 |
| --- | --- | --- | --- |
| POST | `/student/grgl/ccqjwh_load` | 无 | 乘车区间：`info` 学生信息、`ccqj` 当前区间 |
| POST | `/student/grgl/ccqjwh_save` | `ccqj` | 保存乘车区间 |
| POST | `/student/grgl/xjydsqsjkz` | 无 | 学籍异动申请条件 |
| GET | `/student/grgl/getxjydlistbyxssq` | 无 | 已提交异动列表 |
| POST | `/student/grgl/deletexjyd` | `id` | 删除异动申请 |
| GET | `/student/grgl/djksbm_list` | 无 | 等级考试报名项目 |
| GET | `/student/grgl/getbmrecorder` | 无 | 报名记录 |
| POST | `/student/grgl/djksxxbm` | 表单 JSON | 提交报名 |
| POST | `/student/grgl/canCelbmks` | `id` | 取消报名 |
| POST | `/student/grgl/uploadkszp` | multipart | 上传考试照片 |
| GET | `/student/grgl/djkscjcx` | 无 | 等级考试成绩 |

## 5. 培养管理

### 5.1 培养方案

| 方法 | 路径 | 参数 | 返回 |
| --- | --- | --- | --- |
| GET | `/student/pygl/bindpyfacx` | 无 | `{xslbs, yxshs, zydms}` 下拉数据 |
| GET | `/student/pygl/pyfacxlist` | `xslbm,yxsh,zydm` | `{total,rows}` 培养方案课程 |

### 5.2 培养计划

| 方法 | 路径 | 参数 | 说明 |
| --- | --- | --- | --- |
| GET | `/student/pygl/pyjhtj_drop` | 无 | 研究方向下拉：`yjfxlist` |
| POST | `/student/pygl/pyjhtjlist` | `pyfx` | 当前计划：`{pyfakc:[...],info:{...},pyhj:[...]}` |
| GET | `/student/pygl/py_kclist` | `yxsh,kcbh` | 可选课程列表 |
| POST | `/student/pygl/py_pyjh_addkc` | `kcbh,pyfx` | 加课，返回 `{zt:"1"}` |
| POST | `/student/pygl/py_pyjh_delkc` | `kcbh` | 删课，返回 `{sign:"1"}` |
| POST | `/student/pygl/pyjhtj_save` | `json,dotype,pyfx,yjfx` | 保存/提交计划；`dotype=1` 提交 |
| POST | `/student/pygl/pyjhcxlist` | 无 | 已提交计划：`{pyjh:[19 门],info:{xwxf:15,zxf:35,zgxf:44,...}}` |

`pyjh` 每门课字段：`id,xh,kcbh,xwk,kclx,kcxf,xxxq,kcmc,kclbmc,kczxs,sfwc,cj`。`sfwc=1` 表示已完成。

### 5.3 课程免修申请

| 方法 | 路径 | 参数 |
| --- | --- | --- |
| GET | `/student/pygl/kcmxsq_list` | 无 |
| POST | `/student/pygl/kcmxsq_add` | 表单 JSON |
| POST | `/student/pygl/kcmxsq_edit` | 表单 JSON |
| POST | `/student/pygl/kcmxsq_cancel` | `id` |
| POST | `/student/pygl/kcmxsq_qxsq` | `id` |
| POST | `/student/pygl/kcmxsq_bindtj` | 无 |
| POST | `/student/pygl/kcmxsq_addimg` | multipart |
| POST | `/student/pygl/kcmxsq_delimg` | `id` |

`kcmxsq_list` 返回 `{wsq,ysq,wjlj,dqxq,sqsj}`，其中 `wjlj` 是附件目录，`dqxq` 是当前学期。

### 5.4 课程开课一览（旧选课页）

`POST /student/pygl/xswsxk_all`，参数 `yxsh,kcbh,page,rows`。返回 `{total,rows}`，`total` 为 772。字段：

`RowNumber,kcbh,kcmc,xsmc,bjid,bjmc,dz,rkjsxm,kczxs,kcxf,ksz,jsz,sjms,rnrs,xkrs`

旧选课页配套接口：

| 方法 | 路径 | 参数 | 说明 |
| --- | --- | --- | --- |
| GET | `/student/pygl/xswsxk_load` | 无 | 加载已选/计划内课程 |
| POST | `/student/pygl/xswsxk_jhnxk` | `bjid` | 计划内选课 |
| POST | `/student/pygl/xswsxk_jhn_tx` | `bjid` | 计划内退选 |
| POST | `/student/pygl/xswsxk_jhwxk` | `bjid` | 计划外选课 |
| POST | `/student/pygl/xswsxk_jhw_tx` | `bjid` | 计划外退选 |
| POST | `/student/pygl/xswsxk_dx` | `yxsh,kcbh` | 选修课查询 |

### 5.5 学生网上选课（当前选课页）

元数据：

`POST /student/pygl/xswsxk_kb_load`，无参数，返回：

```json
{
  "yx": [{"xsbh":"001","xsmc":"化学工程学院"}, ... 26 个院系],
  "jc": [{"id":41,"mc":"上午1","btime":"08:00","etime":"08:45"}, ... 12 个节次]
}
```

课表网格：

`POST /student/pygl/xswsxk_kb_loadkb`，无参数，返回 `{rows,zxf,xwxf,fxwxf}`。`rows` 为 13 行（第 0 行 `无节次` + 12 个节次），每行 `jcid,mc,z1..z7`；`z1..z7` 为周一至周日，内容形如 `||##课程班名[周次] 教师[地点]`。

课程列表：

`POST /student/pygl/xswsxk_kb_list`

| 参数 | 取值 |
| --- | --- |
| `lb` | `1` 公共课、`2` 专业课、`3` 全部 |
| `xwk` | `1` 学位课、`0` 非学位课、空为全部 |
| `zh` | 星期 `1..7`，空为全部 |
| `jc1` / `jc2` | 节次 id，见上表 |
| `yxsh` | 院系代码，空为全部 |
| `kcbh` | 课程编号或课程名称，空为全部 |
| `page` / `rows` | 分页 |
| `type` | `1` 全部可选课程；`2` 仅当前选课时间段内可选的课程 |

实测：`lb=1` 公共课 15 门、`lb=2` 专业课 6 门、`lb=3` 全部返回 `{total:265,kc:[...]}`；`type=2` 按当前选课时间段过滤，实测返回 12 门。

返回字段：

`kcbh,kcmc,xsmc,bjid,bjmc,dz,sfkx,rkjsxm,kczxs,kcxf,xwk,ksz,jsz,sjms,rnrs,xkrs,kkfs,xkfs,yxkc,cjs,selected`

选课/退选：

`POST /student/pygl/xswsxk_kb_xk`

```json
{"lb":"1","bjid":"<班级id>","xkyzm":"<4位验证码>"}
```

`lb=1` 选课，`lb=0` 退选。失败返回 `{"msg":"..."}`；成功返回空对象或刷新列表。提交前先 `GET /home/verificationcode?codetype=xkyzm` 取验证码。

### 5.6 课表查询

`POST /student/pygl/py_kbcx_ew`

```json
{"kblx":"xs","termcode":"55"}
```

返回 `{rows,week}`。`rows` 为 13 行网格，字段 `jcid,sjbz,mc,z1..z7`；单元格为 HTML 片段：

```html
<br/>数值分析C1班东区[10-16周] 常延贞[科303]
```

`week` 是当前星期英文（实测 `Friday`），不是教学周。教学周要从课程 `sjms` / `ksz` / `jsz` 解析。

`POST /student/pygl/py_kbcx_yw`

```json
{"termcode":"55"}
```

返回已选课列表（14 门），每门课字段：

`Row,bjid,kcbh,bjmc,jdid,kcxf,kcmc,lxfs,ksz,jsz,sjms,skdz_zdy,dz,rkjsxm,xkrs,selected`

示例：

```json
{"kcmc":"催化化学","lxfs":"连续周","ksz":7,"jsz":14,"sjms":"星期一 下午6-下午9","dz":"科402","rkjsxm":"何静"}
```

`lxfs` 取值：`连续周` / `单周` / `双周`。`sjms` 可能包含多个时间段，用逗号分隔，例如 `星期二 上午1 -上午2,星期六 上午3-上午5`。

### 5.7 成绩查询

`GET /student/pygl/xscjcx_list`，无参数：

```json
{
  "xwklist": [],
  "fxwklist": [],
  "hjcjlist": [],
  "xftj": [{"xh":"2026201060","xwxf":0,"fxwxf":0,"zxf":0,"yxxwxf":18.5,"yxfxwxf":21.5,"yxzxf":40,"faxwxf":15,"fazxf":35}],
  "hjzxf": "0.00"
}
```

`xwklist` 学位课成绩、`fxwklist` 非学位课成绩、`hjcjlist` 合级成绩、`xftj` 学分统计、`hjzxf` 合计已修学分。字段通常含 `kcbh,kcmc,kcxf,cj,xwk,termcode,termname`。

附加接口：

| 方法 | 路径 | 参数 |
| --- | --- | --- |
| POST | `/student/pygl/xscjcx_cjzylist` | 无 |
| GET | `/student/pygl/xscjcx_cjzydo` | `id,type` |
| POST | `/student/pygl/dcword_cj` | 无，导出 Word |

### 5.8 调课、考场、评价、国际交流、专业实践

| 方法 | 路径 | 参数 | 说明 |
| --- | --- | --- | --- |
| POST | `/student/pygl/ttkcx_list` | 无 | 调课记录 |
| POST | `/student/pygl/kckccx_list` | 无 | 考场安排 |
| GET | `/student/pygl/wsjxpjlist` | 无 | 教学评价列表，14 条，字段 `termname,bjid,kcbh,bjmc,kcxf,kcmc,jsbh,jsxm,kssj,jssj,pjckcj,sfpj,yxpj` |
| GET | `/student/pygl/gjxsjlhd_load` | 无 | 国际学术交流申请 |
| POST | `/student/pygl/gjxsjlhd_save` | 表单 JSON | 保存 |
| POST | `/student/pygl/gjxsjlhdcltj_save` | 表单 JSON | 提交 |
| GET | `/student/pygl/zysjwc_load` | 无 | 专业实践外出审核 |
| POST | `/student/pygl/zysjwc_save` | 表单 JSON | 保存 |

### 5.9 重缓补考

| 方法 | 路径 | 参数 |
| --- | --- | --- |
| GET | `/student/pygl/cxhkbksq_list` | 无 |
| GET | `/student/pygl/cxhkbksq_sqjl` | 无 |
| POST | `/student/pygl/cxbkbksq_bindkkbj` | `kcbh` |
| POST | `/student/pygl/cxhkbksq_edit_save` | 表单 JSON |
| POST | `/student/pygl/cxhkbksq_del` | `id` |

`cxhkbksq_list` 返回 `{cxinfo,bkinfo,hkinfo,hk,bk,kyhk,kybk,kycx,cxshow,bkshow,hkshow}`，`cxinfo.kssj` 当前为 `2026-08-31`。

## 6. 研工管理

| 页面 | 方法 | 路径 | 参数 |
| --- | --- | --- | --- |
| 学年鉴定 | GET | `/student/yggl/xnjddj_load` | 无 |
| 学年鉴定导出 | POST | `/student/yggl/xnjddj_dcword` | 无 |
| 评优评干 | GET | `/student/yggl/pypgsq_list` | 无 |
| 评优评干申请记录 | GET | `/student/yggl/pypgsq_sqlist` | 无 |
| 困难资助家庭 | POST | `/student/yggl/knzzsq_jtcy_list` | 无 |
| 困难资助评议 | POST | `/student/yggl/knzzsq_plxzrdcy_list` | 无 |
| 困难资助学生基本信息 | POST | `/student/yggl/knzzsq_xsjbxx` | 无 |
| 三助岗位 | GET | `/student/yggl/szgwsq_list` | `gwlb` |
| 三助申请记录 | GET | `/student/yggl/szgwsq_sqlist` | 无 |
| 三助岗位类别 | POST | `/student/yggl/szgwsq_bindszlb` | 无 |
| 三助保存 | POST | `/student/yggl/szgwsq_save` | 表单 JSON |
| 学术报告 | GET | `/student/yggl/xshdbm_cklist` | 无 |
| 学术报告申请记录 | GET | `/student/yggl/xshdbm_sqlist` | 无 |
| 学术报告报名 | POST | `/student/yggl/xshdbm_bm` | `id` |
| 学术报告删除 | POST | `/student/yggl/xshdbm_del` | `id` |
| 学术报告可否申请 | GET | `/student/yggl/xshdbm_sfkysq` | `id` |
| 校外实习 | GET | `/student/yggl/xwsxsq_list` | 无 |
| 校外实习删除 | POST | `/student/yggl/xwsxsq_del` | `id` |
| 劳动实践 | GET | `/student/yggl/zyzfwbm_cklist` | 无 |
| 劳动实践申请记录 | GET | `/student/yggl/zyzfwbm_sqlist` | 无 |
| 劳动实践报名 | POST | `/student/yggl/xshdbm_bm` | `id` |
| 体育活动 | GET | `/student/yggl/tyydbm_cklist` | 无 |
| 体育活动申请记录 | GET | `/student/yggl/tyydbm_sqlist` | 无 |
| 体育活动报名 | POST | `/student/yggl/xshdbm_bm` | `id` |
| 体育免修 | GET | `/student/yggl/tyyd_mxsq_list` | 无 |
| 体育免修删除 | POST | `/student/yggl/tyyd_mxsq_del` | `id` |
| 体育场地 | POST | `/student/yggl/gettyydzsc_tyyd` | 无 |
| 志愿服务 | GET | `/student/yggl/getldsjzsc` | 无 |

## 7. 科研管理与毕业学位

### 7.1 发表论文登记

| 方法 | 路径 | 参数 |
| --- | --- | --- |
| GET | `/student/bygl/xwlwdjlist` | 无 |
| POST | `/student/bygl/zqkh_cxtj` | `json` |
| POST | `/student/bygl/xs_dclwcg` | 无 |
| POST | `/student/bygl/worddy` | 无 |

### 7.2 其他创新性成果

| 方法 | 路径 | 参数 |
| --- | --- | --- |
| GET | `/student/bygl/xskyxmdj_list` | 无 |
| POST | `/student/bygl/xskyxmdj_save` | 表单 JSON |
| POST | `/student/bygl/xs_dckyxm` | 无 |

### 7.3 专利与成果奖励

| 方法 | 路径 | 参数 |
| --- | --- | --- |
| GET | `/student/bygl/zlcglist` | 无 |
| POST | `/student/bygl/savezlcgdjinfo` | 表单 JSON |
| POST | `/student/bygl/xs_dczlcg` | 无 |
| GET | `/student/bygl/hjqklist` | 无 |
| POST | `/student/bygl/savehjcgdjinfo` | 表单 JSON |
| POST | `/student/bygl/xs_hjcgdj` | 无 |

### 7.4 开题、中期、查重盲审、学位申请

| 页面 | 方法 | 路径 | 参数 |
| --- | --- | --- | --- |
| 开题报告申请 | GET | `/student/pygl/lwktsq_edit_load` | `id` |
| 开题报告保存 | POST | `/student/pygl/lwktsq_edit_save` | 表单 JSON |
| 提交开题报告 | GET | `/student/pygl/xsktsq_edit_load` | `id` |
| 提交开题报告保存 | POST | `/student/pygl/xsktsq_edit_save` | 表单 JSON |
| 开题附件检查 | GET | `/student/pygl/xsktsq_edit_checkwj` | `wjmc` |
| 开题打印 | POST | `/student/pygl/xsktsq_print` | 无 |
| 中期申请 | GET | `/student/pygl/zqkhdj_load` | 无 |
| 中期保存 | POST | `/student/pygl/zqkhdj_save` | 表单 JSON |
| 中期导出 | POST | `/student/pygl/dcword_zq` | 无 |
| 查重盲审申请 | GET | `/student/bygl/xsdbsq_edit_load` | `id` |
| 查重盲审论文列表 | POST | `/student/bygl/lwcsdatalist` | 无 |
| 查重盲审论文保存 | POST | `/student/bygl/lwpygl_savelwxx` | `json,sfcc,zt` |
| 查重盲审盲审论文 | POST | `/student/bygl/lwpygl_savemslw` | `json,sfcc,zt` |
| 查重盲审上传 | POST | `/student/bygl/lwpygl_sslwsc` | multipart |
| 盲审审核列表 | POST | `/student/bygl/sslwsh_list` | 无 |
| 学位申请 | GET | `/student/bygl/xsxwsq_edit_load` | 无 |
| 学位申请保存 | POST | `/student/bygl/xsxwsq_edit_save` | 表单 JSON |
| 学位申请提交 | POST | `/student/bygl/xsxwsq_edit_sqtj` | 无 |
| 学位申请打印 | POST | `/student/bygl/xsxwsq_edit_dy` | 无 |

## 8. 通知、咨询、我的申请

| 方法 | 路径 | 参数 | 说明 |
| --- | --- | --- | --- |
| GET | `/student/grgl/tzgg_list` | `ksrq,jsrq,bt,page,rows` | 通知公告列表，当前空 |
| GET | `/student/grgl/zixun_load` | `_` 时间戳 | 咨询联系人：`ds,yxms,yjsy` |
| GET | `/student/grgl/zixun_loadnr` | `_` 时间戳 | 咨询内容：`{rows,xh}` |
| POST | `/student/grgl/getxssqshowinfo` | 无 | 我的申请：学生基本信息 |
| POST | `/student/grgl/getxssqinfo` | 无 | 我的申请：各流程状态列表 |

`getxssqinfo` 返回数组，每项 `{dm,mc,url,shlbz,shlcount}`，`dm` 包括 `zc` 注册、`pyjh` 培养计划、`xyjxj` 学业奖学金、`gjjxj` 国家奖学金、`knzz` 困难资助等。

## 9. 网上考试

| 方法 | 路径 | 参数 | 说明 |
| --- | --- | --- | --- |
| GET | `/student/wsks/wskscp_load` | 无 | 考试列表：`{sj1,sj2,sj3,sj4}` |
| GET | `/student/wsks/wskscp_list` | 无 | 已考记录：`[{sjmc,recid,sjid,tkmc,tkjmc,ksys,kksj,kscj,kstg}]` |

`wskscp_load.sj1` 字段：`sjid,tkjid,tikuid,tkmc,sjmc,sjms,sjlx,kssj,jssj,dtsj,sjzf,tgfs,xsw,dcks,ckdj,sfyx`。

## 10. 数据字典

### 10.1 学期 termcode

| termcode | termname |
| --- | --- |
| 55 | 2026-2027秋季学期 |
| 54 | 2025-2026春季学期 |
| 53 | 2025-2026秋季学期 |
| 52 | 2024-2025春季学期 |
| 51 | 2024-2025秋季学期 |
| 50 | 2023-2024春季学期 |
| 49 | 2023-2024秋季学期 |

完整列表由 `GET /student/default/bindterm` 返回，共 54 个学期，最早的 termcode 为 1。

### 10.2 节次

| id | 名称 | 开始 | 结束 |
| --- | --- | --- | --- |
| 41 | 上午1 | 08:00 | 08:45 |
| 42 | 上午2 | 08:50 | 09:35 |
| 43 | 上午3 | 09:45 | 10:30 |
| 44 | 上午4 | 10:40 | 11:25 |
| 46 | 上午5 | 11:30 | 12:15 |
| 47 | 下午6 | 13:30 | 14:15 |
| 48 | 下午7 | 14:20 | 15:05 |
| 49 | 下午8 | 15:15 | 16:00 |
| 52 | 下午9 | 16:05 | 16:50 |
| 57 | 晚上10 | 18:00 | 18:45 |
| 58 | 晚上11 | 18:50 | 19:35 |
| 59 | 晚上12 | 19:40 | 20:25 |

### 10.3 院系代码

由 `GET /student/default/bindyxsh` 或 `xswsxk_kb_load.yx` 返回：001 化学工程学院、002 材料科学与工程学院、003 机电工程学院、004 信息科学与技术学院、005 经济管理学院、006 理学院、007 生命科学与技术学院、008 文法学院、009 石化学院、010 联合大学、011 能源学院、012 工程硕士、013 马克思主义学院、015 导师安排、016 艺术与设计系、019 国家卓越工程师学院、020 软物质科学与工程高精尖创新中心、021 化学学院、022 数理学院、023 图书馆、028 培养办、030 国际教育学院、068 侯德榜工程师学院、069 巴黎居里工程师学院、070 党委研工部、101 高新技术研究院。

### 10.4 选课字段

| 字段 | 取值 |
| --- | --- |
| `xwk` | `1` 学位课、`0` 非学位课 |
| `lb` | `1` 公共课、`2` 专业课、`3` 全部 |
| `type` | `1` 全部课程、`2` 当前选课时间段内课程 |
| `yxkc` | `0` 可选、`1` 已选、`2` 可退选 |
| `xkfs` | `2` 显示退选按钮 |
| `sfkx` | `1` 可选跨选课程 |

## 11. 课表导入（ICS）

`py_kbcx_yw` 提供课程、周次、星期、节次、教师、地点；`xswsxk_kb_load.jc` 提供节次时间。生成 ICS 的算法：

1. 以第 1 周周一为 `term_start`。2026-2027 秋季学期（termcode=55）可用 `2026-08-31`；学期结束日 `2027-01-17`，共 20 周。
2. 对每门课解析 `sjms`：`星期一 下午6-下午9` → `weekday=0,start=下午6,end=下午9`。多段用逗号分隔。
3. 对每段生成 VEVENT，`DTSTART = term_start + weekday天 + (ksz-1)*7天 + 开始节次时间`。
4. `lxfs=连续周` → `RRULE:FREQ=WEEKLY;INTERVAL=1;COUNT=jsz-ksz+1`。
5. `lxfs=单周` → 先取 `ksz..jsz` 中的奇数周，`INTERVAL=2`，`COUNT=匹配周数`。
6. `lxfs=双周` → 先取偶数周，`INTERVAL=2`，`COUNT=匹配周数`。
7. `DTEND` 用该段结束节次的 `etime`。
8. `SUMMARY=kcmc`，`LOCATION=dz`，`DESCRIPTION` 放教师、地点、周次、节次。

仓库内 `timetable_term55.ics` 是实测生成结果，15 个 VEVENT（14 门课，其中数值分析有周二、周六两段）。

## 12. 客户端落地

| App 页面 | 数据接口 |
| --- | --- |
| 登录 | `/home/stulogin`、`/home/verificationcode?codetype=stucode`、`/home/stulogin_do` |
| 首页 | `getwelcomdata`、`gethomepagesw`、`getxfwcqk`、`getUnReadTzxx`、`index_position` |
| 我的 | `getxscardinfo`、`xsxx_jbxx`、`getxssqinfo` |
| 课程表 | `bindterm`、`py_kbcx_ew`、`py_kbcx_yw`、`xswsxk_kb_load` |
| 选课 | `xswsxk_kb_load`、`xswsxk_kb_loadkb`、`xswsxk_kb_list`、`xswsxk_kb_xk`、`/home/verificationcode?codetype=xkyzm` |
| 培养计划 | `pyjhtj_drop`、`pyjhtjlist`、`py_kclist`、`py_pyjh_addkc`、`py_pyjh_delkc`、`pyjhtj_save`、`pyjhcxlist` |
| 成绩 | `xscjcx_list`、`xscjcx_cjzylist`、`xscjcx_cjzydo` |
| 考试 | `wskscp_load`、`wskscp_list` |
| 通知 | `tzgg_list`、`getUnReadTzxx`、`getUnRemindTzxx` |

客户端会话策略：

1. 登录成功后保存 `ASP.NET_SessionId` 和 `__SINDEXCOOKIE__` 到 Keychain / EncryptedSharedPreferences。
2. 所有请求带两个 Cookie。
3. 任意接口返回 302 或跳转 `/home/stulogin`，清空本地会话并回到登录页。
4. 登录页的 RSA 公钥每次实时从 HTML 解析；验证码图片直接展示给用户。
5. 选课验证码单独请求 `codetype=xkyzm`，与登录验证码分开缓存。
6. 课表、成绩、培养计划本地缓存，进入页面先展示缓存再刷新。

## 13. 接口索引

完整接口清单见 `API_INDEX.md`：按 49 个页面分组，列出 165 个页面 JS 中出现的接口、方法与参数。运行期实际抓到的 90 个 XHR 中，公共接口与未出现在页面 JS 的接口已在本文件第 3、8、9 节补齐。总去重接口 185 个（含 1 个 UEditor 上传处理器）。
