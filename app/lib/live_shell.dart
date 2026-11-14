import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'accounts/account_models.dart';
import 'accounts/account_session.dart';
import 'accounts/account_storage.dart';
import 'accounts/accounts_page.dart';
import 'accounts/add_account_page.dart';
import 'academics_page.dart';
import 'activities/activity_models.dart';
import 'activities/activity_notifications.dart';
import 'activity_page.dart';
import 'activities/activity_monitor.dart';
import 'app_controller.dart';
import 'auth/gmis_password_vault.dart';
import 'auth/login_flow.dart';
import 'config/app_config.dart';
import 'course_sheet.dart';
import 'gate.dart';
import 'home_page.dart';
import 'live_login_page.dart';
import 'me_page.dart';
import 'native_service_page.dart';
import 'planner/todo_controller.dart';
import 'planner/todo_models.dart';
import 'planner/todo_store.dart';
import 'prefs.dart';
import 'remind.dart';
import 'schedule.dart';
import 'services_page.dart';
import 'settings.dart';
import 'snapshot.dart';
import 'subpages.dart';
import 'theme.dart';
import 'timetable_page.dart';
import 'ui/feedback.dart';
import 'ui/startup_pages.dart';
import 'webvpn/sso_login_page.dart';
import 'webvpn/webvpn_login_page.dart';
import 'webvpn/webvpn_credential.dart';
import 'webvpn/webvpn_session.dart';
import 'webvpn/webvpn_session_manager.dart';
import 'webvpn/webvpn_validator.dart';
import 'webvpn/webview_cookies.dart';
import 'widgets.dart';

/// 真实模式的外壳：登录、会话恢复、刷新和 5 个主 Tab。
class LiveShell extends StatefulWidget {
  const LiveShell({
    super.key,
    this.now,
    this.initialTab,
    this.openCourseName,
    this.cacheDirectory,
  });

  final DateTime? now;
  final int? initialTab;
  final String? openCourseName;

  /// 测试/预览可注入缓存目录；生产为空，走应用支持目录。
  final Directory? cacheDirectory;

  @override
  State<LiveShell> createState() => _LiveShellState();
}

class _LiveShellState extends State<LiveShell> with WidgetsBindingObserver {
  late DateTime _now;
  final _settings = AppSettings();
  Timer? _clock;
  TodoController? _todos;
  String _todoProfile = '';
  final _flow = LoginFlowState();
  AccountStore? _accountStore;
  AccountBook? _accounts;
  AccountProfile? _activeAccount;
  AccountSession? _session;
  bool _switchingAccount = false;
  AccountSession? _draftSession;
  String? _autoSsoPassword;
  PrefsStore? _store;
  int _tab = 0;
  bool _onboarded = false;
  bool _guide = false;
  bool _sheetQueued = false;
  bool _reminded = false;
  String? _lastNotice;
  String _bootStage = '正在启动';
  DateTime? _lastResumeRefresh;

  AppController? get _controller => _session?.controller;
  WebVpnSessionManager? get _webVpn => _session?.webVpn;
  GmisPasswordVault? get _passwordVault => _session?.passwordVault;
  SavedGmisLogin? get _savedLogin => _session?.savedLogin;
  bool get _needsWebVpnLogin =>
      _session?.needsWebVpnLogin ?? AppConfig.useWebVpnByDefault;
  bool get _usingWebVpn => _session?.usingWebVpn ?? false;
  String? get _webVpnNotice => _session?.webVpnNotice;
  bool get _webVpnExpiryHandled => _session?.webVpnExpiryHandled ?? false;
  set _webVpnExpiryHandled(bool value) {
    final session = _session;
    if (session != null) session.webVpnExpiryHandled = value;
  }

  bool get _webVpnRenewing => _session?.webVpnRenewing ?? false;
  set _webVpnRenewing(bool value) {
    final session = _session;
    if (session != null) session.webVpnRenewing = value;
  }

  set _savedLogin(SavedGmisLogin? value) {
    final session = _session;
    if (session != null) session.savedLogin = value;
  }

  String get _notificationAccountLabel {
    if ((_accounts?.accounts.length ?? 0) < 2) return '';
    final account = _activeAccount;
    if (account == null) return '';
    return account.name.isNotEmpty ? account.name : account.id;
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _now = widget.now ?? DateTime.now();
    if (widget.now == null) {
      _clock = Timer.periodic(const Duration(minutes: 1), (_) {
        if (!mounted) return;
        setState(() => _now = DateTime.now());
      });
    }
    ActivityMonitor.instance.addListener(_onActivityChanged);
    final initial = widget.initialTab ?? 0;
    _tab = initial < 0 || initial > 4 ? 0 : initial;
    _flow.recordTab(_tab);
    _boot();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      ActivityMonitor.instance.pause();
    }
    if (state != AppLifecycleState.resumed) return;
    ActivityMonitor.instance.resume();
    final controller = _controller;
    if (controller == null || controller.phase != AppPhase.ready) return;
    final last = _lastResumeRefresh;
    final now = DateTime.now();
    if (last != null && now.difference(last) < const Duration(minutes: 10)) {
      return;
    }
    _lastResumeRefresh = now;
    controller.refresh();
    unawaited(_validateWebVpnOnResume());
  }

  Future<void> _boot() async {
    final store = await PrefsStore.tryOpen();
    store?.apply(_settings);
    _store = store;
    if (mounted) setState(() => _bootStage = '正在读取本机会话');

    final accountStore = AccountStore();
    _accountStore = accountStore;
    AccountBook? book;
    try {
      book = await accountStore.load();
    } catch (_) {
      book = null;
    }
    if (book == null) {
      book = await _buildLegacyBook();
      if (book != null) {
        try {
          await accountStore.save(book);
        } catch (_) {
          // 安全存储不可用时只在本次运行使用内存账号，不阻塞登录。
        }
      }
    }

    if (book == null || book.isEmpty) {
      final sid = store?.sid ?? '';
      final provisional = AccountProfile(
        id: sid,
        name: '',
        college: '',
        major: '',
        storageKey: legacyAccountStorageKey,
        addedAt: DateTime.now(),
        lastUsedAt: DateTime.now(),
      );
      _activeAccount = provisional;
      _accounts = const AccountBook();
    } else {
      final active = book.active ?? book.accounts.first;
      _accounts = book;
      _activeAccount = active;
    }

    final active = _activeAccount;
    if (active == null) {
      if (mounted) setState(() => _bootStage = '正在准备登录');
      return;
    }

    final session = _createSession(active);
    _session = session;
    try {
      await session.boot();
    } catch (error) {
      if (mounted) setState(() => _bootStage = '启动失败，请检查网络');
      debugPrint('启动账号会话失败: $error');
    }
    _attachController();
    _prepareAutoSso();
    if (!mounted) return;
    setState(() {
      _onboarded = store?.onboarded ?? false;
    });
    _onController();
  }

  AccountSession _createSession(AccountProfile profile) {
    final storage = AccountStorage(
      profile: profile,
      cacheDirectory: widget.cacheDirectory,
    );
    return AccountSession(
      profile: profile,
      storage: storage,
      prefs: _store,
      onWebVpnExpired: _handleWebVpnExpired,
      onStage: (stage) {
        if (!mounted) return;
        setState(() => _bootStage = stage);
      },
    );
  }

  Future<AccountBook?> _buildLegacyBook() async {
    final provisional = AccountProfile(
      id: '',
      name: '',
      college: '',
      major: '',
      storageKey: legacyAccountStorageKey,
      addedAt: DateTime.now(),
      lastUsedAt: DateTime.now(),
    );
    final storage = AccountStorage(
      profile: provisional,
      cacheDirectory: widget.cacheDirectory,
    );
    try {
      return await migrateLegacyAccountBook(
        vault: storage.passwordVault,
        cache: storage.snapshotCache,
        directSession: storage.sessionStore(),
        webVpnSession: storage.sessionStore(webVpn: true),
        prefs: _store,
      );
    } catch (_) {
      return null;
    }
  }

  void _attachController() {
    final controller = _controller;
    if (controller == null) return;
    controller.removeListener(_onController);
    controller.addListener(_onController);
  }

  void _detachController() {
    _controller?.removeListener(_onController);
  }

  bool _canAutoSso() {
    final session = _session;
    final saved = session?.savedLogin;
    if (session == null || saved == null) return false;
    if (!_settings.autoReconnect) return false;
    if (session.route == WebVpnStartupRoute.offline) return false;
    if (!saved.canAutoSso) return false;
    if (saved.autoFailedRecently(DateTime.now())) return false;
    final active = _activeAccount;
    if (active != null && active.id.isNotEmpty && saved.userId != active.id) {
      return false;
    }
    return true;
  }

  void _prepareAutoSso() {
    _autoSsoPassword = null;
    final session = _session;
    if (session == null || session.route != WebVpnStartupRoute.ssoLogin) {
      return;
    }
    if (!_canAutoSso()) return;
    _autoSsoPassword = session.savedLogin?.password;
  }

  Future<void> _onAutoSsoFailed() async {
    _autoSsoPassword = null;
    try {
      await _passwordVault?.markAutoFailure();
    } catch (_) {
      // 冷却写入失败只影响下一次自动尝试；本次仍保留预填页。
    }
    final session = _session;
    if (session != null) {
      session.webVpnNotice = '自动登录没有成功，请检查密码后重试';
    }
    if (mounted) setState(() {});
  }

  Future<void> _syncAccountProfile() async {
    final snap = _controller?.snapshot;
    if (snap == null) return;
    final id = snap.student.id.trim();
    if (id.isEmpty) return;
    final existing = _activeAccount;
    if (existing != null &&
        existing.id == id &&
        existing.name == snap.student.name &&
        existing.college == snap.student.college &&
        existing.major == snap.student.major) {
      return;
    }
    final now = DateTime.now();
    final profile = AccountProfile(
      id: id,
      name: snap.student.name,
      college: snap.student.college,
      major: snap.student.major,
      storageKey: existing?.storageKey ?? legacyAccountStorageKey,
      addedAt: existing?.addedAt ?? now,
      lastUsedAt: now,
    );
    final book = (_accounts ?? const AccountBook()).upsert(profile);
    _accounts = book;
    _activeAccount = book.active;
    try {
      await _store?.setSid(id);
      await _accountStore?.save(book);
    } catch (_) {
      // 账号册写入失败时仍可用当前会话，下次启动再尝试。
    }
    if (mounted) setState(() {});
  }

  Future<void> _openWebVpnLogin() async {
    final credential = await Navigator.of(context).push<WebVpnCredential>(
      MaterialPageRoute(builder: (_) => const WebVpnLoginPage()),
    );
    if (credential == null || !mounted) return;
    final session = _session;
    final manager = session?.webVpn;
    if (session == null || manager == null) return;
    await manager.adopt(credential, state: WebVpnState.unknown);
    final state = await manager.validate(force: true);
    if (!mounted) return;
    if (state != WebVpnState.valid) {
      session.needsWebVpnLogin = true;
      session.webVpnNotice = state == WebVpnState.expired
          ? '网页版 VPN 登录没有生效，请重新登录统一身份认证'
          : '暂时无法校验网页版 VPN 会话，请检查网络后重试';
      setState(() {});
      return;
    }
    await _acceptWebVpnSession(WebVpnSession(credential: manager.credential!));
  }

  Future<void> _acceptSsoLogin(SsoLoginSuccess result) async {
    final session = _session;
    if (session == null) return;
    _autoSsoPassword = null;
    _flow.acceptSso(result);
    _detachController();
    await session.acceptSso(result);
    _attachController();
    if (!mounted) return;
    setState(() {
      _lastNotice = null;
    });
    _onController();
  }

  Future<void> _acceptWebVpnSession(WebVpnSession session) async {
    final accountSession = _session;
    if (accountSession == null) return;
    _detachController();
    await accountSession.acceptWebVpnSession(session);
    _attachController();
    if (!mounted) return;
    setState(() {
      _lastNotice = null;
    });
    _onController();
  }

  Future<void> _useDirectLogin() async {
    final session = _session;
    if (session == null) return;
    _autoSsoPassword = null;
    _detachController();
    await session.useDirectLogin();
    _attachController();
    if (!mounted) return;
    setState(() {
      _lastNotice = null;
    });
    _onController();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _clock?.cancel();
    ActivityMonitor.instance.removeListener(_onActivityChanged);
    _todos?.removeListener(_onTodosChanged);
    _todos?.dispose();
    _flow.clear();
    _detachController();
    _session?.dispose();
    super.dispose();
  }

  void _onActivityChanged() {
    if (mounted) setState(() {});
  }

  void _onTodosChanged() {
    if (mounted) setState(() {});
  }

  void _syncTodos() {
    final snap = _controller?.snapshot;
    if (snap == null) return;
    final profile = snap.student.id.isEmpty
        ? snap.student.name
        : snap.student.id;
    if (profile.isEmpty || profile == _todoProfile) return;
    _todos?.removeListener(_onTodosChanged);
    _todos?.dispose();
    final controller = TodoController(
      store: PrefsTodoStore(profileKey: profile),
    );
    _todoProfile = profile;
    _todos = controller..addListener(_onTodosChanged);
    unawaited(controller.load());
  }

  Future<void> _stopMonitoringAndNotifications() async {
    ActivityMonitor.instance.stop();
    await ActivityNotificationService.instance.cancelAll();
  }

  Future<void> _openAccounts() async {
    final book = _accounts;
    if (book == null || book.accounts.isEmpty) {
      _openAddAccount();
      return;
    }
    await Navigator.of(context).push(
      huayanRoute<void>(
        AccountsPage(
          accounts: book.accounts,
          activeId: _activeAccount?.id,
          switching: _switchingAccount,
          onSwitch: (account) => unawaited(_switchAccount(account)),
          onAdd: _openAddAccount,
          onRemove: _removeAccount,
        ),
      ),
    );
  }

  void _openAddAccount() {
    unawaited(
      Navigator.of(context).push(
        huayanRoute<void>(
          AddAccountPage(
            existingIds: {
              for (final account
                  in _accounts?.accounts ?? const <AccountProfile>[])
                account.id,
            },
            onContinue: (sid) async {
              Navigator.of(context).pop();
              await _startAddAccount(sid);
            },
          ),
        ),
      ),
    );
  }

  Future<void> _switchAccount(AccountProfile account) async {
    if (_switchingAccount) return;
    if (_activeAccount?.id == account.id && _session != null) return;
    await _activateAccount(account);
  }

  Future<void> _activateAccount(AccountProfile account) async {
    if (_switchingAccount || !mounted) return;
    setState(() => _switchingAccount = true);
    await _stopMonitoringAndNotifications();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    _detachController();
    final old = _session;
    final session = _createSession(account);
    _session = session;
    _activeAccount = account;
    final current = _accounts ?? const AccountBook();
    final book = current.byId(account.id) == null
        ? current.upsert(account)
        : current.activate(account.id);
    _accounts = book;
    _autoSsoPassword = null;
    _flow.clear();
    try {
      await session.boot();
    } catch (error) {
      debugPrint('切换账号启动失败: $error');
    }
    old?.dispose();
    _attachController();
    _prepareAutoSso();
    try {
      await _store?.setSid(account.id);
      if (book.accounts.isNotEmpty) await _accountStore?.save(book);
    } catch (_) {
      // 账号册写入失败不阻塞本次切换。
    }
    if (!mounted) return;
    setState(() {
      _switchingAccount = false;
      _tab = 0;
      _lastNotice = null;
      _todoProfile = '';
    });
    _onController();
  }

  Future<void> _startAddAccount(String rawSid) async {
    final sid = rawSid.trim();
    if (sid.isEmpty) return;
    final existing = _accounts?.byId(sid);
    if (existing != null) {
      await _switchAccount(existing);
      return;
    }
    final now = DateTime.now();
    final profile = AccountProfile(
      id: sid,
      name: '',
      college: '',
      major: '',
      storageKey: accountStorageKeyFor(sid),
      addedAt: now,
      lastUsedAt: now,
    );
    final session = _createSession(profile);
    _draftSession = session;
    try {
      await session.boot();
    } catch (error) {
      debugPrint('准备新账号登录失败: $error');
      await _discardDraft(session);
      if (mounted) AppFeedback.show('暂时无法准备新账号登录，请检查网络');
      return;
    }

    var direct = false;
    SsoLoginSuccess? ssoResult;
    if (session.needsWebVpnLogin) {
      if (!mounted) return;
      ssoResult = await Navigator.of(context).push<SsoLoginSuccess>(
        huayanRoute<SsoLoginSuccess>(
          SsoLoginPage(
            initialSid: sid,
            notice: session.webVpnNotice,
            onSuccess: (result) => Navigator.of(context).pop(result),
            onDirect: () {
              direct = true;
              unawaited(
                session.useDirectLogin().then((_) {
                  if (mounted) Navigator.of(context).pop();
                }),
              );
            },
          ),
        ),
      );
      if (ssoResult != null) {
        await session.acceptSso(ssoResult);
      } else if (!direct) {
        await _discardDraft(session);
        return;
      }
    }

    final controller = session.controller;
    if (controller == null) {
      await _discardDraft(session);
      if (mounted) AppFeedback.show('登录页准备失败，请重试');
      return;
    }
    if (!mounted) return;
    _autoSsoPassword = null;
    final navigator = Navigator.of(context);
    final ssoPassword = ssoResult?.prefill.password;
    final completed = await navigator.push<bool>(
      huayanRoute<bool>(
        LiveLoginPage(
          controller: controller,
          initialSid: sid,
          initialPassword: ssoPassword,
          fromSso: ssoPassword != null,
          allowWebVpn: false,
          onSuccess: (loggedSid, remember, password) {
            unawaited(
              _finishAddAccount(
                session: session,
                sid: loggedSid,
                password: password,
                source: ssoPassword != null
                    ? SavedCredentialSource.sso
                    : SavedCredentialSource.gmis,
                navigator: navigator,
              ),
            );
          },
        ),
      ),
    );
    if (completed != true && identical(_draftSession, session)) {
      await _discardDraft(session);
    }
  }

  Future<void> _finishAddAccount({
    required AccountSession session,
    required String sid,
    required String? password,
    required SavedCredentialSource source,
    required NavigatorState navigator,
  }) async {
    final snap = session.controller?.snapshot;
    if (snap == null) {
      AppFeedback.show('登录后还没有拿到数据，请稍后重试');
      return;
    }
    if (snap.student.id.trim() != sid.trim()) {
      AppFeedback.show('登录学号和课表数据不一致，请重新登录');
      await _discardDraft(session);
      navigator.pop(false);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      return;
    }
    try {
      if (password == null) {
        await session.passwordVault.clear();
      } else {
        await session.passwordVault.write(sid, password, source: source);
      }
    } catch (_) {
      // 密码保存失败不影响账号登录，只是下次要手动输入。
    }
    final now = DateTime.now();
    final profile = AccountProfile(
      id: sid,
      name: snap.student.name,
      college: snap.student.college,
      major: snap.student.major,
      storageKey: session.profile.storageKey,
      addedAt: now,
      lastUsedAt: now,
    );
    await _stopMonitoringAndNotifications();
    _detachController();
    final old = _session;
    _session = session;
    _activeAccount = profile;
    final book = (_accounts ?? const AccountBook())
        .upsert(profile)
        .activate(sid);
    _accounts = book;
    _draftSession = null;
    _autoSsoPassword = null;
    _flow.clear();
    try {
      await _store?.setSid(sid);
      await _accountStore?.save(book);
    } catch (_) {
      // 账号册写入失败时先完成本次切换，下次启动再尝试。
    }
    old?.dispose();
    _attachController();
    _todoProfile = '';
    if (mounted) {
      setState(() {
        _tab = 0;
        _lastNotice = null;
        _switchingAccount = false;
      });
    }
    navigator.pop(true);
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    _onController();
  }

  Future<void> _discardDraft(AccountSession session) async {
    if (identical(_draftSession, session)) _draftSession = null;
    try {
      await session.wipe();
    } catch (_) {
      // 清理失败时至少释放运行时。
    }
    session.dispose();
  }

  Future<void> _removeAccount(AccountProfile account) async {
    final active = account.id == _activeAccount?.id;
    final book = (_accounts ?? const AccountBook()).remove(account.id);
    if (active) {
      await _stopMonitoringAndNotifications();
      _detachController();
      try {
        await _session?.wipe();
      } catch (_) {
        // 远端已不可用时仍然完成本地移除。
      }
      _session?.dispose();
      _session = null;
      _activeAccount = null;
    } else {
      try {
        final storage = AccountStorage(
          profile: account,
          cacheDirectory: widget.cacheDirectory,
        );
        await storage.clearSessionData();
        await _store?.clearTermStarts(accountId: account.storageKey);
      } catch (_) {
        // 旧账号数据清理失败不阻塞账号册更新。
      }
    }
    try {
      await PrefsTodoStore(profileKey: account.id).clear();
    } catch (_) {
      // 待办清理失败不影响账号移除。
    }
    _accounts = book;
    try {
      await _accountStore?.save(book);
    } catch (_) {
      // 账号册写入失败仍允许本次移除。
    }

    if (book.accounts.isEmpty) {
      await _store?.setSid(null);
      final now = DateTime.now();
      final provisional = AccountProfile(
        id: '',
        name: '',
        college: '',
        major: '',
        storageKey: legacyAccountStorageKey,
        addedAt: now,
        lastUsedAt: now,
      );
      _activeAccount = provisional;
      final session = _createSession(provisional);
      _session = session;
      try {
        await session.boot();
      } catch (_) {
        // 启动失败时至少回到登录页。
      }
      _attachController();
      _prepareAutoSso();
      if (mounted) {
        setState(() {
          _switchingAccount = false;
          _tab = 0;
          _lastNotice = null;
        });
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
      _onController();
      return;
    }

    if (active || _session == null) {
      final next = book.active ?? book.accounts.first;
      await _activateAccount(next);
      return;
    }
    if (mounted) {
      setState(() {});
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
    final controller = _controller;
    if (controller != null && controller.phase == AppPhase.ready) {
      ActivityMonitor.instance.start(
        controller.api,
        accountLabel: _notificationAccountLabel,
        onSessionExpired: _handleSessionExpired,
        onWebVpnExpired: _handleWebVpnExpired,
      );
    }
  }

  List<ActivityItem> _appliedActivities() {
    final seen = <String>{};
    final result = <ActivityItem>[];
    for (final kind in ActivityKind.values) {
      for (final item in ActivityMonitor.instance.feed(kind).applied) {
        if (seen.add(item.stableKey)) result.add(item);
      }
    }
    return result;
  }

  void _onController() {
    if (!mounted) return;
    setState(() {});
    _syncTodos();
    final controller = _controller;
    if (controller == null) return;
    final notice = controller.notice;
    if (notice != null && notice.isNotEmpty && notice != _lastNotice) {
      _lastNotice = notice;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        AppFeedback.show(notice);
      });
    }
    if (controller.phase == AppPhase.sessionExpired) {
      _flow.recordTab(_tab);
    }
    if (controller.phase == AppPhase.webVpnExpired) {
      unawaited(_handleWebVpnExpired());
    }
    if (controller.phase == AppPhase.ready) {
      _flow.markLoginComplete();
      _webVpnExpiryHandled = false;
      _autoSsoPassword = null;
      unawaited(_syncAccountProfile());
      ActivityMonitor.instance.start(
        controller.api,
        accountLabel: _notificationAccountLabel,
        onSessionExpired: _handleSessionExpired,
        onWebVpnExpired: _handleWebVpnExpired,
      );
      _scheduleRemind();
    }
  }

  void _setTab(int index) {
    _flow.recordTab(index);
    setState(() => _tab = index);
  }

  Future<void> _refresh() async {
    final controller = _controller;
    if (controller == null) return;
    await controller.refresh();
    if (mounted) setState(() {});
  }

  void _queueSheet() {
    final name = widget.openCourseName;
    final snap = _controller?.snapshot;
    if (_sheetQueued || name == null || name.isEmpty || snap == null) return;
    Course? course;
    for (final item in snap.courses) {
      if (item.name == name) course = item;
    }
    if (course == null) return;
    _sheetQueued = true;
    final picked = course;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _openCourse(picked, weekIndex(_now, snap.termStart));
    });
  }

  void _scheduleRemind() {
    if (_reminded) return;
    final snap = _controller?.snapshot;
    if (snap == null) return;
    final text = foregroundRemindText(
      settings: _settings,
      courses: snap.courses,
      now: _now,
      termStart: snap.termStart,
    );
    _reminded = true;
    if (text == null) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      AppFeedback.show(
        text,
        context: context,
        duration: const Duration(milliseconds: 1200),
      );
    });
  }

  void _changed() {
    _store?.save(_settings);
    setState(() {});
  }

  Future<void> _finishGuide() async {
    await _store?.setOnboarded();
    if (!mounted) return;
    setState(() {
      _onboarded = true;
      _guide = false;
    });
  }

  Future<void> _login(String sid, bool remember, String? password) async {
    if (remember) {
      await _store?.setSid(sid);
    } else {
      await _store?.setSid(null);
    }
    final vault = _passwordVault;
    if (vault != null) {
      try {
        if (password == null) {
          await vault.clear();
          _savedLogin = null;
        } else {
          await vault.write(
            sid,
            password,
            source: _flow.prefill != null
                ? SavedCredentialSource.sso
                : SavedCredentialSource.gmis,
          );
          _savedLogin = await vault.read();
        }
      } catch (_) {
        // 保存失败只影响下次预填，不阻塞登录。
      }
    }
    _autoSsoPassword = null;
    await _store?.setOnboarded();
    _flow.markLoginComplete();
    final resumeTab = _flow.resumeTab;
    if (!mounted) return;
    setState(() {
      if (resumeTab >= 0 && resumeTab <= 4) _tab = resumeTab;
    });
  }

  Future<void> _clearSavedPassword() async {
    await _passwordVault?.clear();
    if (mounted) setState(() => _savedLogin = null);
  }

  Future<void> _logout() async {
    await _stopMonitoringAndNotifications();
    if (!mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
    final session = _session;
    await session?.logout();
    _autoSsoPassword = null;
    _flow.clear();
    if (session != null) {
      session.usingWebVpn = false;
      session.needsWebVpnLogin = AppConfig.useWebVpnByDefault;
      session.webVpnNotice = null;
      session.webVpnExpiryHandled = false;
    }
    if (!mounted) return;
    setState(() {
      _tab = 0;
      _lastNotice = null;
    });
  }

  /// 会话过期时保留课表和当前 Tab，只清 GMIS 会话。
  Future<void> _handleSessionExpired() async {
    ActivityMonitor.instance.stop();
    final controller = _controller;
    if (controller == null) return;
    _flow.recordTab(_tab);
    Navigator.of(context).popUntil((route) => route.isFirst);
    await controller.expireSession();
    if (!mounted) return;
    _flow.markLoginComplete();
    final session = _session;
    if (session != null) {
      session.needsWebVpnLogin = session.usingWebVpn
          ? false
          : AppConfig.useWebVpnByDefault;
      session.webVpnNotice = null;
    }
    setState(() {
      _lastNotice = null;
    });
  }

  /// WebVPN ticket 失效：先用留存 SSO 静默续签，失败后用保存密码自动
  /// 尝试 SSO；自动失败才停在预填页面让用户补短信/密码。
  Future<void> _handleWebVpnExpired() async {
    if (_webVpnExpiryHandled || _webVpnRenewing) return;
    ActivityMonitor.instance.stop();
    final session = _session;
    final manager = _webVpn;
    var renewed = false;
    _webVpnRenewing = true;
    try {
      renewed = manager != null && await manager.renewSilently();
    } finally {
      _webVpnRenewing = false;
    }
    if (!mounted) return;
    if (renewed) {
      final credential = manager.credential;
      if (credential != null) {
        await _acceptWebVpnSession(WebVpnSession(credential: credential));
        return;
      }
    }
    _flow.recordTab(_tab);
    Navigator.of(context).popUntil((route) => route.isFirst);
    final canAuto = _canAutoSso();
    if (session != null && canAuto) {
      _autoSsoPassword = session.savedLogin?.password;
      session.webVpnExpiryHandled = true;
      session.usingWebVpn = false;
      session.needsWebVpnLogin = true;
      session.webVpnNotice = null;
      _flow.markLoginComplete();
      if (mounted) setState(() => _lastNotice = null);
      return;
    }
    _webVpnExpiryHandled = true;
    try {
      await _webVpn?.invalidate();
      await WebViewCookies.clear();
    } catch (_) {
      // 清理失败也要回到 SSO 页面。
    }
    if (!mounted) return;
    _flow.markLoginComplete();
    if (session != null) {
      session.usingWebVpn = false;
      session.needsWebVpnLogin = true;
      session.webVpnNotice = '校外访问已过期，请重新登录统一身份认证';
    }
    setState(() {
      _lastNotice = null;
    });
  }

  Future<void> _validateWebVpnOnResume() async {
    final manager = _webVpn;
    if (manager == null || !manager.hasCredential || !_usingWebVpn) return;
    final state = await manager.validate();
    if (!mounted || !_usingWebVpn) return;
    if (state == WebVpnState.expired) {
      await _handleWebVpnExpired();
    }
  }

  Future<void> _openActivities() async {
    final api = _controller?.api;
    if (api == null) return;
    final kind = await showModalBottomSheet<ActivityKind>(
      context: context,
      backgroundColor: HuayanColors.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            ListTile(
              leading: const Icon(
                Icons.flag_outlined,
                color: HuayanColors.blue,
              ),
              title: const Text('学术报告'),
              subtitle: const Text('可报名活动、我的报名和自动提醒'),
              onTap: () =>
                  Navigator.of(context).pop(ActivityKind.academicReport),
            ),
            ListTile(
              leading: const Icon(
                Icons.volunteer_activism_outlined,
                color: HuayanColors.amberInk,
              ),
              title: const Text('劳动实践'),
              subtitle: const Text('抢实践、累计劳动小时和自动提醒'),
              onTap: () =>
                  Navigator.of(context).pop(ActivityKind.laborPractice),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
    if (kind == null || !mounted) return;
    final controller = _controller;
    if (controller == null) return;
    _push(
      ActivityPage(
        kind: kind,
        dataSource: api,
        courses: _controller?.snapshot?.courses ?? const <Course>[],
        termStart: _controller?.snapshot?.termStart ?? '',
        termStartKnown: _controller?.snapshot?.termStartKnown ?? true,
        todos: _todos?.todos ?? const <TodoItem>[],
        onSessionExpired: _handleSessionExpired,
        onWebVpnExpired: _handleWebVpnExpired,
      ),
    );
  }

  void _openCourse(Course course, int week) {
    final snap = _controller?.snapshot;
    if (snap == null) return;
    openCourseSheet(
      context,
      course: course,
      week: clampWeek(week, termMaxWeek(snap.courses, _now, snap.termStart)),
      now: _now,
      termStart: snap.termStart,
      settings: _settings,
      onChanged: _changed,
    );
  }

  void _goTab(int index) {
    Navigator.of(context).popUntil((route) => route.isFirst);
    setState(() => _tab = index);
  }

  void _push(Widget page) {
    Navigator.of(context).push(huayanRoute<void>(page));
  }

  /// 选课/退选成功后刷新快照，让课表、学分和已选列表跟着更新。
  Future<void> _refreshAfterChange() async {
    await _controller?.refresh();
    if (!mounted) return;
    setState(() {});
  }

  void _openService(ServiceItem item) {
    final snap = _controller?.snapshot;
    if (snap == null) return;
    switch (item.native) {
      case 'timetable':
        _goTab(1);
      case 'progress':
        _push(ProgressPage(snap: snap));
      case 'selected':
        _push(
          SelectedPage(
            snap: snap,
            now: _now,
            onCourse: (course) =>
                _openCourse(course, weekIndex(_now, snap.termStart)),
          ),
        );
      case 'catalog':
      case 'selection':
        if (_controller?.api == null) {
          _push(CourseCatalogPage(snap: snap));
        } else {
          _push(
            NativeServicePage(
              item: item,
              snap: snap,
              api: _controller?.api,
              onChanged: _refreshAfterChange,
              onSessionExpired: _handleSessionExpired,
              onWebVpnExpired: () {
                unawaited(_handleWebVpnExpired());
              },
            ),
          );
        }
      case 'exams':
        _push(ExamsPage(count: snap.exams, items: snap.examItems));
      case 'grades':
        _push(GradesPage(snap: snap));
      case 'eval':
        _push(EvalPage(snap: snap));
      case 'profile':
        _push(ProfilePage(student: snap.student));
      case 'notices':
        _push(NoticesPage(count: snap.notices, items: snap.noticeItems));
      case 'online':
        _push(
          OnlinePage(
            snap: snap,
            onCourse: (course) =>
                _openCourse(course, weekIndex(_now, snap.termStart)),
          ),
        );
      default:
        switch (item.id) {
          case 'grjbxx':
          case 'grxxxg':
            _push(ProfilePage(student: snap.student));
          case 'xyjc':
          case 'pyfacx':
          case 'pyjhcx':
          case 'pyjhtj':
            _push(ProgressPage(snap: snap));
          case 'xjydsq':
            _push(
              ApplicationsPage(
                snap: snap,
                title: item.name,
                applicationIds: const ['zc'],
              ),
            );
          case 'knzzsq':
            _push(
              ApplicationsPage(
                snap: snap,
                title: item.name,
                applicationIds: const ['knzz'],
              ),
            );
          case 'ktlwsq':
          case 'lwktsq':
          case 'zqkhsq':
          case 'zqkhdj':
            _push(
              ApplicationsPage(
                snap: snap,
                title: item.name,
                applicationIds: const ['lwkt'],
              ),
            );
          case 'xsdbsq':
          case 'lwpygl':
          case 'xsxwsq':
          case 'lwdb':
            _push(
              ApplicationsPage(
                snap: snap,
                title: item.name,
                applicationIds: const ['lwdb'],
              ),
            );
          case 'gjxsjlhd':
          case 'py_zysjwc':
          case 'lwkt':
            _push(ApplicationsPage(snap: snap, title: item.name));
          default:
            _push(
              NativeServicePage(
                item: item,
                snap: snap,
                api: _controller?.api,
                todos: _todos?.todos ?? const <TodoItem>[],
                onChanged: _refreshAfterChange,
                onSessionExpired: _handleSessionExpired,
                onWebVpnExpired: () {
                  unawaited(_handleWebVpnExpired());
                },
              ),
            );
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_switchingAccount) {
      return const SplashPage(message: '正在切换账号');
    }
    final controller = _controller;
    if (controller == null) {
      return SplashPage(message: _bootStage);
    }
    if (!_onboarded) {
      if (!_guide) {
        return StartPage(
          onNext: () => setState(() => _guide = true),
          onSkip: _finishGuide,
        );
      }
      return GuidePage(
        updatedLabel: '学校系统',
        live: true,
        onStart: _finishGuide,
        onSkip: _finishGuide,
      );
    }
    final session = _session;
    if (session == null) {
      return SplashPage(message: _bootStage);
    }
    if (_needsWebVpnLogin || controller.phase == AppPhase.webVpnExpired) {
      final autoPassword = _autoSsoPassword;
      final saved = session.savedLogin;
      final prefillPassword = autoPassword ?? saved?.password;
      return SsoLoginPage(
        initialSid: session.initialSid,
        initialPassword: prefillPassword,
        autoSubmit: autoPassword != null,
        onAutoLoginFailed: () => unawaited(_onAutoSsoFailed()),
        onUserId: (sid) => _store?.setSid(sid),
        onSuccess: _acceptSsoLogin,
        onDirect: _useDirectLogin,
        notice: _webVpnNotice,
      );
    }
    if (controller.phase == AppPhase.booting) {
      return SplashPage(message: _bootStage);
    }
    final prefill = _flow.prefill;
    final savedLogin = session.savedLogin;
    final initialSid = prefill?.userId ?? session.initialSid;
    final initialPassword =
        prefill?.password ??
        (savedLogin != null && savedLogin.userId == initialSid
            ? savedLogin.password
            : null);
    final loginDescription = _usingWebVpn
        ? prefill != null
              ? '统一身份认证已完成，请补研究生管理系统验证码。'
              : '网页版 VPN 已连接，请登录研究生管理系统。'
        : null;
    final snap = controller.snapshot;
    if (snap == null) {
      if (controller.phase == AppPhase.restoring) {
        return const HomeSkeleton();
      }
      return LiveLoginPage(
        controller: controller,
        initialSid: initialSid,
        initialPassword: initialPassword,
        fromSso: prefill != null,
        notice: controller.error,
        onSuccess: _login,
        onWebVpnLogin: _openWebVpnLogin,
        description: loginDescription,
        webVpnLabel: _usingWebVpn ? '重新登录网页版 VPN' : '校外访问：使用网页版 VPN 登录',
      );
    }
    if (controller.phase == AppPhase.signedOut ||
        controller.phase == AppPhase.sessionExpired) {
      return LiveLoginPage(
        controller: controller,
        initialSid: initialSid,
        initialPassword: initialPassword,
        fromSso: prefill != null,
        notice: controller.error,
        onSuccess: _login,
        onWebVpnLogin: _openWebVpnLogin,
        description: loginDescription,
        webVpnLabel: _usingWebVpn ? '重新登录网页版 VPN' : '校外访问：使用网页版 VPN 登录',
      );
    }
    _queueSheet();
    return _scaffold(snap);
  }

  Widget _scaffold(Snapshot snap) {
    final bottom = MediaQuery.paddingOf(context).bottom;
    final pageBottom = 12 + bottom + 64 + 8;
    return Scaffold(
      backgroundColor: HuayanColors.bg,
      body: SafeArea(
        bottom: false,
        child: Stack(
          children: [
            Positioned(
              top: 0,
              left: 0,
              right: 0,
              bottom: pageBottom,
              child: IndexedStack(
                index: _tab,
                children: [
                  HomePage(
                    snap: snap,
                    now: _now,
                    onRefresh: _refresh,
                    lastRefreshedAt: _controller?.lastRefreshedAt,
                    offline: _controller?.phase == AppPhase.offline,
                    onCourse: (course) =>
                        _openCourse(course, weekIndex(_now, snap.termStart)),
                    onProgress: () => _push(ProgressPage(snap: snap)),
                    onNotices: () => _push(
                      NoticesPage(count: snap.notices, items: snap.noticeItems),
                    ),
                    onEval: () => _push(EvalPage(snap: snap)),
                    onGrades: () => _push(GradesPage(snap: snap)),
                    onExams: () => _push(
                      ExamsPage(count: snap.exams, items: snap.examItems),
                    ),
                    onActivities: _openActivities,
                    onSelected: () => _push(
                      SelectedPage(
                        snap: snap,
                        now: _now,
                        onCourse: (course) => _openCourse(
                          course,
                          weekIndex(_now, snap.termStart),
                        ),
                      ),
                    ),
                  ),
                  TimetablePage(
                    snap: snap,
                    now: _now,
                    settings: _settings,
                    activities: _appliedActivities(),
                    todos: _todos?.todos ?? const <TodoItem>[],
                    termStartKnown: snap.termStartKnown,
                    onToggleTodo: _todos == null
                        ? null
                        : (todo) => _todos!.toggle(todo),
                    onSaveTodo: _todos == null
                        ? null
                        : (todo) => _todos!.upsert(todo),
                    onDeleteTodo: _todos == null
                        ? null
                        : (id) => _todos!.delete(id),
                    onRefresh: _refresh,
                    lastRefreshedAt: _controller?.lastRefreshedAt,
                    offline: _controller?.phase == AppPhase.offline,
                    onCourse: _openCourse,
                    onOnline: () => _push(
                      OnlinePage(
                        snap: snap,
                        onCourse: (course) => _openCourse(
                          course,
                          weekIndex(_now, snap.termStart),
                        ),
                      ),
                    ),
                  ),
                  AcademicsPage(
                    snap: snap,
                    onRefresh: _refresh,
                    lastRefreshedAt: _controller?.lastRefreshedAt,
                    onGrades: () => _push(GradesPage(snap: snap)),
                    onExams: () => _push(
                      ExamsPage(count: snap.exams, items: snap.examItems),
                    ),
                    onProgress: () => _push(ProgressPage(snap: snap)),
                    onEval: () => _push(EvalPage(snap: snap)),
                    onSelected: () => _push(
                      SelectedPage(
                        snap: snap,
                        now: _now,
                        onCourse: (course) => _openCourse(
                          course,
                          weekIndex(_now, snap.termStart),
                        ),
                      ),
                    ),
                  ),
                  ServicesPage(
                    snap: snap,
                    onOpen: _openService,
                    onRefresh: _refresh,
                    lastRefreshedAt: _controller?.lastRefreshedAt,
                    offline: _controller?.phase == AppPhase.offline,
                    onCourse: (course) =>
                        _openCourse(course, weekIndex(_now, snap.termStart)),
                  ),
                  MePage(
                    snap: snap,
                    onRefresh: _refresh,
                    onAccounts: _openAccounts,
                    accountCount: _accounts?.accounts.length ?? 1,
                    lastRefreshedAt: _controller?.lastRefreshedAt,
                    onProfile: () => _push(ProfilePage(student: snap.student)),
                    onProgress: () => _push(ProgressPage(snap: snap)),
                    onApplications: () => _push(ApplicationsPage(snap: snap)),
                    onGrades: () => _push(GradesPage(snap: snap)),
                    onSelected: () => _push(
                      SelectedPage(
                        snap: snap,
                        now: _now,
                        onCourse: (course) => _openCourse(
                          course,
                          weekIndex(_now, snap.termStart),
                        ),
                      ),
                    ),
                    onEval: () => _push(EvalPage(snap: snap)),
                    onExams: () => _push(
                      ExamsPage(count: snap.exams, items: snap.examItems),
                    ),
                    onNotices: () => _push(
                      NoticesPage(count: snap.notices, items: snap.noticeItems),
                    ),
                    onSettings: () => _push(
                      SettingsPage(
                        snap: snap,
                        settings: _settings,
                        now: _now,
                        onChanged: _changed,
                        onLogout: _logout,
                        isLive: true,
                        hasSavedPassword: _savedLogin != null,
                        onClearSavedPassword: _clearSavedPassword,
                        onRefresh: _controller?.refresh,
                        termCode: snap.termCode,
                        accountCount: _accounts?.accounts.length ?? 1,
                        onManageAccounts: _openAccounts,
                        onTermStart: (firstMonday) async {
                          await _store?.setTermStart(
                            snap.termCode,
                            firstMonday,
                            accountId:
                                _activeAccount?.storageKey ??
                                legacyAccountStorageKey,
                          );
                          await _controller?.refresh();
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              key: const Key('tabbar'),
              left: 16,
              right: 16,
              bottom: 12 + bottom,
              child: HuayanTabBar(index: _tab, onChanged: _setTab),
            ),
          ],
        ),
      ),
    );
  }
}
