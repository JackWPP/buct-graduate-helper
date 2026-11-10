import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/app_config.dart';
import '../theme.dart';
import 'webvpn_credential.dart';
import 'webvpn_session.dart';
import 'webvpn_url.dart';

/// 在应用内打开学校网页版 VPN，统一身份认证完成后交回 Cookie。
///
/// 这里只负责认证，不读取或保存用户在网页里输入的密码。
class WebVpnLoginPage extends StatefulWidget {
  const WebVpnLoginPage({super.key});

  @override
  State<WebVpnLoginPage> createState() => _WebVpnLoginPageState();
}

class _WebVpnLoginPageState extends State<WebVpnLoginPage> {
  static const _channel = MethodChannel('edu.buct.graduate.huayan/cookies');

  late final WebViewController _web;
  var _loading = true;
  var _checking = false;
  String? _error;
  WebVpnCredential? _ticket;

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(AppConfig.userAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (_) {
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (_) {
            if (mounted) setState(() => _loading = false);
            _refreshTicket();
          },
        ),
      )
      ..loadRequest(Uri.parse('https://${WebVpnUrls.host}/login'));
  }

  Future<WebVpnCredential?> _readTicket() async {
    final raw = await _channel.invokeMethod<String>('getCookies', {
      'url': 'https://${WebVpnUrls.host}/',
    });
    final ticket = credentialFromCookieHeader(raw);
    if (mounted) setState(() => _ticket = ticket);
    return ticket;
  }

  Future<void> _refreshTicket() async {
    try {
      await _readTicket();
    } on MissingPluginException {
      // 平台不支持时保留现有错误提示。
    } catch (_) {
      // 页面跳转期间 CookieManager 偶尔读不到，下一次完成再试。
    }
  }

  Future<void> _clearCookies() async {
    try {
      await _channel.invokeMethod<void>('clearCookies');
    } catch (_) {
      // 清理失败不影响已取到的内存凭证。
    }
  }

  Future<void> _checkAndClose() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final ticket = await _readTicket();
      if (ticket == null) {
        throw const _WebVpnNotReady('还没有检测到网页版 VPN 登录状态，请先完成统一身份认证。');
      }
      await _clearCookies();
      if (!mounted) return;
      Navigator.of(context).pop(ticket);
    } on MissingPluginException {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = '当前平台暂不支持应用内网页版 VPN，请在 Android 上使用。';
      });
    } on _WebVpnNotReady catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = error.message;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _error = '读取网页版 VPN 登录状态失败，请重试。';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: HuayanColors.bg,
      appBar: AppBar(
        backgroundColor: HuayanColors.card,
        foregroundColor: HuayanColors.ink,
        title: const Text('网页版 VPN'),
        actions: [
          IconButton(
            tooltip: '刷新',
            onPressed: () => _web.reload(),
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_loading) const LinearProgressIndicator(minHeight: 2),
          Expanded(child: WebViewWidget(controller: _web)),
          SafeArea(
            top: false,
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
              color: HuayanColors.card,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    '请先完成统一身份认证。登录成功后回到这里点下面的按钮，应用会继续用学校验证码登录研究生管理系统。',
                    style: TextStyle(
                      fontSize: 12,
                      height: 1.5,
                      color: HuayanColors.sub,
                    ),
                  ),
                  if (_ticket != null) ...[
                    const SizedBox(height: 6),
                    const Text(
                      '已检测到网页版 VPN 登录状态，可以继续。',
                      key: Key('webvpn-ticket-ready'),
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: HuayanColors.ok,
                      ),
                    ),
                  ],
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(
                      _error!,
                      key: const Key('webvpn-error'),
                      style: const TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: HuayanColors.danger,
                      ),
                    ),
                  ],
                  const SizedBox(height: 10),
                  FilledButton(
                    key: const Key('webvpn-finish'),
                    onPressed: _checking ? null : _checkAndClose,
                    child: _checking
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('已完成登录，继续'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _WebVpnNotReady implements Exception {
  const _WebVpnNotReady(this.message);
  final String message;
}
