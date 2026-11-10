import 'package:flutter/material.dart';

import 'activities/activity_models.dart';
import 'activity_page.dart';
import 'gmis/gmis_api.dart';
import 'icons.dart';
import 'remote_pages.dart';
import 'selection_page.dart';
import 'snapshot.dart';
import 'theme.dart';
import 'widgets.dart';

/// 全原生服务页的统一外壳。
///
/// 已实现的服务会被路由到各自的业务页面；尚未落字段的服务也留在应用内，
/// 用清晰的“已原生化、等待学校字段”状态代替跳浏览器。
class NativeServicePage extends StatelessWidget {
  const NativeServicePage({
    super.key,
    required this.item,
    required this.snap,
    this.api,
    this.onSessionExpired,
    this.onWebVpnExpired,
    this.onChanged,
  });

  final ServiceItem item;
  final Snapshot snap;
  final GmisApi? api;
  final VoidCallback? onSessionExpired;
  final VoidCallback? onWebVpnExpired;

  /// 提交类操作成功后的刷新回调（例如选课后刷新课表和学分）。
  final Future<void> Function()? onChanged;

  @override
  Widget build(BuildContext context) {
    final remote = _remotePage();
    if (remote != null) return remote;
    final desc = _descriptionFor(item.id);
    return Subpage(
      title: item.name,
      children: [
        HuayanCard(
          padding: const EdgeInsets.all(18),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: HuayanColors.blueSoft,
                  borderRadius: BorderRadius.circular(15),
                ),
                child: Center(
                  child: HuayanIcon(
                    serviceGlyph(item.id),
                    size: 24,
                    color: HuayanColors.blue,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      style: const TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: HuayanColors.ink,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      desc,
                      style: const TextStyle(
                        fontSize: 13,
                        height: 1.6,
                        color: HuayanColors.sub,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        HuayanCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Row(
                children: [
                  HuayanIcon('check', size: 18, color: HuayanColors.ok),
                  SizedBox(width: 8),
                  Text(
                    '应用内原生页面',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: HuayanColors.ink,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '这个入口不再打开浏览器。页面数据来自学校系统，登录状态失效时会回到登录页。',
                style: TextStyle(
                  fontSize: 13,
                  height: 1.6,
                  color: HuayanColors.sub,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        const HuayanCard(
          child: Row(
            children: [
              HuayanIcon('info', size: 18, color: HuayanColors.amberInk),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  '该功能字段正在继续接入，接入完成前不会生成示例数据。',
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.6,
                    color: HuayanColors.amberInk,
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget? _remotePage() {
    final api = this.api;
    if (api == null) return null;
    switch (item.id) {
      case 'xsxqzc':
        return RemoteInfoPage(
          title: item.name,
          intro: '注册状态来自学校系统，不在本机推断。',
          load: api.registrationStatus,
          fields: const [
            ('学期', 'termname'),
            ('注册时间', 'zcsj'),
            ('当前状态', 'dqzt'),
            ('说明', 'zcsm'),
          ],
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'ccqjwh':
        return RemoteInfoPage(
          title: item.name,
          intro: '乘车区间来自学校登记信息。',
          load: () async =>
              (await api.rawPost('/student/grgl/ccqjwh_load'))
                  as Map<String, dynamic>,
          fields: const [('乘车区间', 'ccqj')],
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'ttkcx':
        return RemoteListPage(
          title: item.name,
          intro: '调课信息来自学校系统，按学校返回展示。',
          emptyText: '暂无调课信息。',
          load: api.courseAdjustments,
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'djksbm':
        return RemoteListPage(
          title: item.name,
          intro: '可以报名的等级考试项目。',
          load: () => api.rawListGet('/student/grgl/djksbm_list'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'djkscj':
        return RemoteListPage(
          title: item.name,
          intro: '等级考试成绩。',
          load: () => api.rawListGet('/student/grgl/djkscjcx'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'pypgsq':
        return RemoteListPage(
          title: item.name,
          intro: '评优评干申请项目。',
          load: () => api.rawListGet('/student/yggl/pypgsq_list'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'szgwsq':
        return RemoteListPage(
          title: item.name,
          intro: '三助岗位列表。',
          load: () => api.rawListGet('/student/yggl/szgwsq_list'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'xshdbm':
        return ActivityPage(
          kind: ActivityKind.academicReport,
          dataSource: api,
          onSessionExpired: onSessionExpired == null
              ? null
              : () async => onSessionExpired!(),
          onWebVpnExpired: onWebVpnExpired == null
              ? null
              : () async => onWebVpnExpired!(),
        );
      case 'xwsxsq':
        return RemoteListPage(
          title: item.name,
          intro: '校外实习申请记录。',
          load: () => api.rawListGet('/student/yggl/xwsxsq_list'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'zyzfwbm':
        return ActivityPage(
          kind: ActivityKind.laborPractice,
          dataSource: api,
          onSessionExpired: onSessionExpired == null
              ? null
              : () async => onSessionExpired!(),
          onWebVpnExpired: onWebVpnExpired == null
              ? null
              : () async => onWebVpnExpired!(),
        );
      case 'tyydbm':
        return RemoteListPage(
          title: item.name,
          intro: '体育活动项目。',
          load: () => api.rawListGet('/student/yggl/tyydbm_cklist'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'tyydmxsq':
        return RemoteListPage(
          title: item.name,
          intro: '体育运动免修申请。',
          load: () => api.rawListGet('/student/yggl/tyyd_mxsq_list'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'xsfblwdj':
        return RemoteListPage(
          title: item.name,
          intro: '已经登记的科研论文。',
          load: () => api.rawListGet('/student/bygl/xwlwdjlist'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'xskycgdj':
        return RemoteListPage(
          title: item.name,
          intro: '其他创新性成果。',
          load: () => api.rawListGet('/student/bygl/xskyxmdj_list'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'xszlcgdj':
        return RemoteListPage(
          title: item.name,
          intro: '专利与成果登记。',
          load: () => api.rawListGet('/student/bygl/zlcglist'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'xshjcgdj':
        return RemoteListPage(
          title: item.name,
          intro: '科研成果奖励登记。',
          load: () => api.rawListGet('/student/bygl/hjqklist'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'kcmxsq':
        return RemoteListPage(
          title: item.name,
          intro: '课程免修申请记录。',
          load: () => api.rawListGet('/student/pygl/kcmxsq_list'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'qxkczml':
        return RemoteListPage(
          title: item.name,
          intro: '全校课程总目录，分页读取学校返回的全部课程。',
          emptyText: '学校没有返回课程目录。',
          load: api.courseCatalogRows,
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'xswsxk':
      case 'xswsxk_kb':
      case 'xkjgcx':
        return SelectionPage(
          api: api,
          snap: snap,
          onChanged: onChanged,
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'cxhkbksq':
        return RemoteListPage(
          title: item.name,
          intro: '重缓补考申请信息。',
          load: () => api.rawListGet('/student/pygl/cxhkbksq_list'),
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      case 'wskscp':
        return RemoteListPage(
          title: item.name,
          intro: '待考和已考记录都来自学校系统。',
          emptyText: '暂无网上考试。',
          load: api.onlineExamRows,
          onSessionExpired: onSessionExpired,
          onWebVpnExpired: onWebVpnExpired,
        );
      default:
        return null;
    }
  }

  String _descriptionFor(String id) {
    switch (id) {
      case 'xsxx':
      case 'xsxx_jbxx':
        return '查看学籍基本信息、培养单位和导师信息。';
      case 'pyjh':
      case 'pyjhcx':
      case 'pyfacx':
        return '查看培养方案完成度、课程分类和学分要求。';
      case 'xscj':
      case 'xscjcx':
        return '按学期查看课程成绩、学分和绩点。';
      case 'xswsxk':
      case 'xswsxk_kb':
      case 'xkjgcx':
        return '查看选课结果和可选课程。';
      case 'wsjxpj':
        return '查看待评课程和评教记录。';
      case 'kckccx':
      case 'ttkcx':
        return '查看考试安排和调课信息。';
      case 'tzgg':
        return '查看学校通知和公告。';
      case 'wskscp':
        return '查看网上考试和测评入口。';
      default:
        return '学校服务入口，已切换为应用内原生页面。';
    }
  }
}
