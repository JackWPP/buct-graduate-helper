import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_flutter/webview_flutter.dart';

import '../config/app_config.dart';
import '../theme.dart';
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
  String _currentUrl = 'https://${WebVpnUrls.host}/login';

  @override
  void initState() {
    super.initState();
    _web = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..setUserAgent(AppConfig.userAgent)
      ..setNavigationDelegate(
        NavigationDelegate(
          onPageStarted: (url) {
            _currentUrl = url;
            if (mounted) setState(() => _loading = true);
          },
          onPageFinished: (url) {
            _currentUrl = url;
            if (mounted) setState(() => _loading = false);
          },
        ),
      )
      ..loadRequest(Uri.parse('https://${WebVpnUrls.host}/login'));
  }

  Future<void> _checkAndClose() async {
    if (_checking) return;
    setState(() {
      _checking = true;
      _error = null;
    });
    try {
      final raw = await _channel.invokeMethod<String>('getCookies', {
        'url': 'https://${WebVpnUrls.host}/',
      });
      final path = Uri.tryParse(_currentUrl)?.path ?? '';
      if (path.contains('/login')) {
        throw const _WebVpnNotReady('当前还在统一身份认证页，请先完成登录。');
      }
      final title = await _web.runJavaScriptReturningResult('document.title');
      if ('$title'.contains('统一身份认证')) {
        throw const _WebVpnNotReady('当前还在统一身份认证页，请先完成登录。');
      }
      final cookies = parseCookieHeader(raw);
      final session = WebVpnSession(
        baseUrl: WebVpnUrls.gmisBase,
        cookies: cookies,
      );
      if (!session.hasTicket) {
        throw const _WebVpnNotReady('还没有检测到网页版 VPN 登录状态，请先完成统一身份认证。');
      }
      if (!mounted) return;
      Navigator.of(context).pop(session);
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
