# GMIS 学生端接口索引

> 由 ../../research/scraped/pages_all/*.html 页面 JS 与 crawl_log.json 自动整理。参数从页面 JS 的 `data` / `queryParams` 提取，空表示页面未传参。

## 个人管理 / 个人基本信息

页面: `/student/grgl/xsxx`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| GET | `/student/grgl/xsxx_byxw` | — |
| GET | `/student/grgl/xsxx_jbxx` | — |
| POST | `/student/grgl/xsxx_jcjl` | — |
| GET | `/student/grgl/xsxx_ktzq` | — |
| POST | `/student/grgl/xsxx_kylw` | — |
| POST | `/student/pygl/pyjhcxlist` | — |
| GET | `/student/pygl/xscjcx_list` | — |

## 个人管理 / 学业进程查看

页面: `/student/grgl/xyjc`

无独立 XHR 接口。

## 个人管理 / 学期报到注册

页面: `/student/grgl/xsxqzc`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/grgl/bindXsZcXx` | — |
| POST | `/student/grgl/getzcxx` | — |
| POST | `/student/grgl/xszcaction` | — |

## 个人管理 / 新生入学登记

页面: `/student/grgl/xsrxdj`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| GET | `/student/grgl/Dmwh_getZyByyxbh` | xsbh |
| POST | `/student/grgl/deletejtzcry` | — |
| POST | `/student/grgl/deletexxgzjl` | — |
| POST | `/student/grgl/getjtzcxx` | — |
| POST | `/student/grgl/getxxgzjl` | — |
| POST | `/student/grgl/savejtcy` | — |
| POST | `/student/grgl/savexxgzjl` | — |
| POST | `/student/grgl/updatexjinfo` | — |
| POST | `/student/grgl/xsrxdjdy_new` | — |

## 个人管理 / 新生录取复查

页面: `/student/grgl/xslqfc`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/grgl/init_xslqfc` | — |
| POST | `/student/grgl/submit_xslqfc` | — |
| POST | `/student/grgl/xlrz_upload` | json |
| POST | `/student/grgl/xwzs_upload` | — |

## 个人管理 / 个人信息维护

页面: `/student/grgl/grxxxg`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| GET | `/student/grgl/Dmwh_getZyByyxbh` | xsbh |
| POST | `/student/grgl/ccqj_getzmdrop` | — |
| GET | `/student/grgl/getxxlrkz` | — |
| POST | `/student/grgl/xgxx` | xjjsonstr, editfield |

## 个人管理 / 乘车区间维护

页面: `/student/grgl/ccqjwh`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/grgl/ccqjwh_load` | — |
| POST | `/student/grgl/ccqjwh_save` | ccqj |

## 个人管理 / 学籍异动申请

页面: `/student/grgl/xjydsq`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/grgl/deletexjyd` | ids |
| POST | `/student/grgl/getxjydlistbyxssq` | — |
| GET | `/student/grgl/xjydsqsjkz` | — |

## 个人管理 / 等级考试管理

页面: `/student/grgl/djksbm`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/grgl/canCelbmks` | — |
| GET | `/student/grgl/djksbm_list` | — |
| POST | `/student/grgl/djksxxbm` | — |
| GET | `/student/grgl/getbmrecorder` | — |
| POST | `/student/grgl/uploadkszp` | xh |

## 个人管理 / 等级考试成绩

页面: `/student/grgl/djkscj`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/grgl/djkscjcx` | — |

## 个人管理 / 照片信息核对

页面: `/student/grgl/zpxxhd`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/grgl/grxxxg_uploadzp` | — |

## 个人管理 / 网上考试测评

页面: `/student/wsks/wskscp`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| GET | `/student/wsks/wskscp_list` | — |
| GET | `/student/wsks/wskscp_load` | — |

## 培养管理 / 培养方案查看

页面: `/student/pygl/pyfacx`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| GET | `/student/pygl/bindpyfacx` | — |
| POST | `/student/pygl/pyfacxlist` | xslbm, yxsh, zydm |

## 培养管理 / 培养计划提交

页面: `/student/pygl/pyjhtj`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/pygl/py_kclist` | yxsh, kcbh |
| POST | `/student/pygl/py_pyjh_addkc` | kcbh, pyfx |
| POST | `/student/pygl/py_pyjh_delkc` | kcbh |
| GET | `/student/pygl/pyjhtj_drop` | — |
| POST | `/student/pygl/pyjhtj_save` | json, dotype, pyfx, yjfx |
| POST | `/student/pygl/pyjhtjlist` | pyfx |

## 培养管理 / 培养计划查询

页面: `/student/pygl/pyjhcx`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/pygl/pyjhcxlist` | — |

## 培养管理 / 课程免修申请

页面: `/student/pygl/kcmxsq`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/pygl/kcmxsq_add` | kcbh |
| POST | `/student/pygl/kcmxsq_addimg` | — |
| POST | `/student/pygl/kcmxsq_bindtj` | — |
| POST | `/student/pygl/kcmxsq_cancel` | — |
| POST | `/student/pygl/kcmxsq_delimg` | filename |
| POST | `/student/pygl/kcmxsq_edit` | id, sqly, pycc, bh, mxcj, yycj |
| GET | `/student/pygl/kcmxsq_list` | — |
| POST | `/student/pygl/kcmxsq_qxsq` | id |

## 培养管理 / 课程开课一览

页面: `/student/pygl/xswsxk`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/default/bindyxsh` | — |
| POST | `/student/pygl/xswsxk_all` | yxsh, kcbh |
| POST | `/student/pygl/xswsxk_dx` | yxsh, kcbh |
| POST | `/student/pygl/xswsxk_jhn_tx` | bjid |
| POST | `/student/pygl/xswsxk_jhnxk` | bjid |
| POST | `/student/pygl/xswsxk_jhw_tx` | bjid |
| POST | `/student/pygl/xswsxk_jhwxk` | bjid |
| GET | `/student/pygl/xswsxk_load` | — |

## 培养管理 / 学生网上选课

页面: `/student/pygl/xswsxk_kb`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/pygl/xswsxk_kb_list` | lb, xwk, zh, jc1, jc2, yxsh, kcbh, page, rows, type |
| POST | `/student/pygl/xswsxk_kb_load` | — |
| POST | `/student/pygl/xswsxk_kb_loadkb` | — |
| POST | `/student/pygl/xswsxk_kb_xk` | lb, bjid, xkyzm |

## 培养管理 / 选课结果查询

页面: `/student/pygl/xkjgcx`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/default/bindterm` | — |
| POST | `/student/pygl/dcexcel_yw` | — |
| POST | `/student/pygl/py_kbcx_yw` | termcode |

## 培养管理 / 学生课表查询

页面: `/student/pygl/xskbcx`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/default/bindterm` | — |
| POST | `/student/pygl/dcword_kb` | — |
| POST | `/student/pygl/doprint_kb` | — |
| POST | `/student/pygl/py_kbcx_ew` | kblx, termcode |

## 培养管理 / 调课信息查询

页面: `/student/pygl/ttkcx`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/pygl/ttkcx_list` | — |

## 培养管理 / 课程考场查询

页面: `/student/pygl/kckccx`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/pygl/kckccx_list` | — |

## 培养管理 / 课程成绩查询

页面: `/student/pygl/xscjcx`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/pygl/dcword_cj` | — |
| GET | `/student/pygl/xscjcx_cjzydo` | id, type |
| POST | `/student/pygl/xscjcx_cjzylist` | — |
| GET | `/student/pygl/xscjcx_list` | — |

## 培养管理 / 全校课程总目录

页面: `/student/pygl/qxkczml`

无独立 XHR 接口。

## 培养管理 / 重缓补考申请

页面: `/student/pygl/cxhkbksq`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/pygl/cxbkbksq_bindkkbj` | — |
| POST | `/student/pygl/cxhkbksq_del` | id |
| POST | `/student/pygl/cxhkbksq_edit_save` | json |
| GET | `/student/pygl/cxhkbksq_list` | — |
| GET | `/student/pygl/cxhkbksq_sqjl` | — |

## 培养管理 / 课程教学评价

页面: `/student/pygl/wsjxpj`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/pygl/wsjxpjlist` | — |

## 培养管理 / 国际学术交流申请

页面: `/student/pygl/gjxsjlhd`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| GET | `/student/pygl/gjxsjlhd_load` | — |
| POST | `/student/pygl/gjxsjlhd_save` | json, zt |
| POST | `/student/pygl/gjxsjlhdcltj_save` | json, zt |

## 培养管理 / 专业实践（科研/学习）外出审核

页面: `/student/pygl/py_zysjwc`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| GET | `/student/pygl/zysjwc_load` | — |
| POST | `/student/pygl/zysjwc_save` | json, zt |

## 研工管理 / 学年鉴定登记

页面: `/student/yggl/xnjddj`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/yggl/xnjddj_dcword` | — |
| GET | `/student/yggl/xnjddj_load` | — |

## 研工管理 / 评优评干申请

页面: `/student/yggl/pypgsq`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| GET | `/student/yggl/pypgsq_list` | — |
| GET | `/student/yggl/pypgsq_sqlist` | — |

## 研工管理 / 困难资助申请

页面: `/student/yggl/knzzsq`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/yggl/knzzsq_jtcy_list` | sqid |
| POST | `/student/yggl/knzzsq_plxzrdcy_list` | sqid |

## 研工管理 / 三助岗位申请

页面: `/student/yggl/szgwsq`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/yggl/szgwsq_bindszlb` | — |
| GET | `/student/yggl/szgwsq_list` | gwlb |
| POST | `/student/yggl/szgwsq_save` | json, zt |
| GET | `/student/yggl/szgwsq_sqlist` | — |

## 研工管理 / 学术报告申请

页面: `/student/yggl/xshdbm`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/yggl/printword` | — |
| POST | `/student/yggl/xshdbm_bm` | id, VeriCode |
| POST | `/student/yggl/xshdbm_cklist` | — |
| POST | `/student/yggl/xshdbm_del` | hdid |
| GET | `/student/yggl/xshdbm_sfkysq` | id |
| POST | `/student/yggl/xshdbm_sqlist` | — |

## 研工管理 / 校外实习申请

页面: `/student/yggl/xwsxsq`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/yggl/xwsxsq_del` | id, ids |
| POST | `/student/yggl/xwsxsq_list` | — |

## 研工管理 / 劳动实践申请

页面: `/student/yggl/zyzfwbm`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/yggl/getldsjzsc` | — |
| POST | `/student/yggl/ldsjbm_del` | hdid |
| POST | `/student/yggl/ldsjhz_print` | — |
| POST | `/student/yggl/xshdbm_bm` | id, VeriCode |
| POST | `/student/yggl/zyzfwbm_cklist` | — |
| POST | `/student/yggl/zyzfwbm_sqlist` | — |

## 研工管理 / 体育活动申请

页面: `/student/yggl/tyydbm`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/yggl/gettyydzsc_tyyd` | — |
| POST | `/student/yggl/tyydbm_cklist` | — |
| POST | `/student/yggl/tyydbm_del` | hdid |
| POST | `/student/yggl/tyydbm_sqlist` | — |
| POST | `/student/yggl/tyydhz_print` | — |
| POST | `/student/yggl/xshdbm_bm` | id, VeriCode |

## 研工管理 / 体育运动免修申请

页面: `/student/yggl/tyyd_mxsq`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/yggl/tyyd_mxsq_del` | id, ids |
| POST | `/student/yggl/tyyd_mxsq_list` | — |

## 科研管理 / 发表论文登记

页面: `/student/bygl/xsfblwdj`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/bygl/worddy` | — |
| POST | `/student/bygl/xs_dclwcg` | — |
| POST | `/student/bygl/xwlwdjlist` | — |
| POST | `/student/bygl/zqkh_cxtj` | json |

## 科研管理 / 其他创新性成果登记

页面: `/student/bygl/xskyxmdj`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/bygl/xs_dckyxm` | — |
| POST | `/student/bygl/xskyxmdj_list` | — |
| POST | `/student/bygl/xskyxmdj_save` | datajson |

## 科研管理 / 专利情况登记

页面: `/student/bygl/xszlcgdj`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/bygl/savezlcgdjinfo` | datajson |
| POST | `/student/bygl/xs_dczlcg` | — |
| POST | `/student/bygl/zlcglist` | — |

## 科研管理 / 科研成果奖励登记

页面: `/student/bygl/xshjcgdj`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/bygl/hjqklist` | — |
| POST | `/student/bygl/savehjcgdjinfo` | datajson |
| POST | `/student/bygl/xs_hjcgdj` | — |

## 毕业与学位 / 开题报告申请

页面: `/student/pygl/lwktsq_edit`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| GET | `/student/pygl/lwktsq_edit_load` | id |
| POST | `/student/pygl/lwktsq_edit_save` | json, zt |

## 毕业与学位 / 提交开题报告

页面: `/student/pygl/xsktsq_edit`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| GET | `/student/pygl/xsktsq_edit_checkwj` | wjmc |
| POST | `/student/pygl/xsktsq_edit_jddel` | id |
| POST | `/student/pygl/xsktsq_edit_jdlist` | id |
| POST | `/student/pygl/xsktsq_edit_jdsave` | json |
| GET | `/student/pygl/xsktsq_edit_load` | id |
| POST | `/student/pygl/xsktsq_edit_save` | json, zt |
| POST | `/student/pygl/xsktsq_edit_zjdel` | id |
| POST | `/student/pygl/xsktsq_edit_zjlist` | id |
| POST | `/student/pygl/xsktsq_edit_zjsave` | json |
| POST | `/student/pygl/xsktsq_print` | — |

## 毕业与学位 / 中期报告申请

页面: `/student/pygl/zqkhsq`

无独立 XHR 接口。

## 毕业与学位 / 提交中期报告

页面: `/student/pygl/xszqkhdj`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/pygl/dcword_zq` | — |
| GET | `/student/pygl/zqkhdj_load` | — |
| POST | `/student/pygl/zqkhdj_save` | json, zt |

## 毕业与学位 / 硕士查重盲审申请

页面: `/student/bygl/xsdbsq_edit`

无独立 XHR 接口。

## 毕业与学位 / 查重盲审论文提交

页面: `/student/bygl/lwpygl`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| POST | `/student/bygl/getlwccsqbyxh` | — |
| POST | `/student/bygl/lwcsdatalist` | — |
| POST | `/student/bygl/lwpygl_bs_getmsmdxx` | pcdm |
| POST | `/student/bygl/lwpygl_savelwxx` | json, sfcc, zt |
| POST | `/student/bygl/lwpygl_savemslw` | json, sfcc, zt |
| POST | `/student/bygl/lwpygl_sslwsc` | — |
| POST | `/student/bygl/sslwsh_list` | — |
| GET | `/student/bygl/xsdbsq_edit_load` | id |
| POST | `/student/bygl/zjpsjglist` | — |
| POST | `/student/bygl/zpb_down` | — |

## 毕业与学位 / 学生学位申请

页面: `/student/bygl/xsxwsq_edit`

| 方法 | 接口 | 参数 |
| --- | --- | --- |
| GET | `/student/bygl/bindbypc` | — |
| POST | `/student/bygl/scxwlw_down` | — |
| POST | `/student/bygl/xsxwsq_edit_dy` | — |
| GET | `/student/bygl/xsxwsq_edit_load` | — |
| POST | `/student/bygl/xsxwsq_edit_save` | json, zt, yxlwshtl, dbid, yjfx, zwzy, cxd1, cxd2, cxd3, cxd4, cxd5 |
| POST | `/student/bygl/xsxwsq_edit_sqtj` | — |

## 运行期公共接口（页面 JS 未列出）

| 方法 | 接口 | 说明 |
| --- | --- | --- |
| POST | `/student/bygl/getlwxxinfo` | 抓包实际调用 |
| POST | `/student/bygl/sclwxz` | 抓包实际调用 |
| GET | `/student/default/MenuleftInfo` | 抓包实际调用 |
| POST | `/student/default/checkIsFisrtLogin` | 抓包实际调用 |
| POST | `/student/default/getUnReadTzxx` | 抓包实际调用 |
| POST | `/student/default/getUnRemindTzxx` | 抓包实际调用 |
| POST | `/student/default/gethomepagesw` | 抓包实际调用 |
| POST | `/student/default/getwelcomdata` | 抓包实际调用 |
| GET | `/student/default/getxfwcqk` | 抓包实际调用 |
| GET | `/student/default/getxscardinfo` | 抓包实际调用 |
| POST | `/student/default/getxsxyyj` | 抓包实际调用 |
| POST | `/student/default/index_position` | 抓包实际调用 |
| POST | `/student/grgl/getxssqinfo` | 抓包实际调用 |
| POST | `/student/grgl/getxssqshowinfo` | 抓包实际调用 |
| POST | `/student/grgl/getxyjcinfo` | 抓包实际调用 |
| GET | `/student/grgl/xsxqzc` | 抓包实际调用 |
| GET | `/student/grgl/zixun_load` | 抓包实际调用 |
| GET | `/student/grgl/zixun_loadnr` | 抓包实际调用 |
| POST | `/student/yggl/knzzsq_xsjbxx` | 抓包实际调用 |
