import 'package:flutter_test/flutter_test.dart';
import 'package:huayan/storage/secure_key_value_store.dart';
import 'package:huayan/webvpn/webvpn_credential.dart';
import 'package:huayan/webvpn/webvpn_credential_store.dart';
import 'package:huayan/webvpn/webvpn_session.dart';
import 'package:huayan/webvpn/webvpn_session_manager.dart';
import 'package:huayan/webvpn/webvpn_validator.dart';

class _MemoryStore implements SecureKeyValueStore {
  final values = <String, String>{};

  @override
  Future<void> delete(String key) async => values.remove(key);

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> write(String key, String value) async => values[key] = value;
}

class _FakeValidator implements WebVpnValidator {
  _FakeValidator(this.results);

  final List<WebVpnState> results;
  var calls = 0;

  @override
  Future<WebVpnValidation> validate(WebVpnCredential credential) async {
    final state = results[calls.clamp(0, results.length - 1)];
    calls++;
    return WebVpnValidation(state);
  }
}

void main() {
  final now = DateTime(2026, 11, 10, 10);
  const ticketName = 'wengine_vpn_ticketw_buct_edu_cn';

  WebVpnCredential credential({String value = 'ticket-1'}) {
    return WebVpnCredential(
      ticketName: ticketName,
      ticketValue: value,
      issuedAt: now,
      lastUsedAt: now,
    );
  }

  test('restore validates and writes lastValidatedAt', () async {
    final memory = _MemoryStore();
    final store = WebVpnCredentialStore(store: memory);
    await store.write(credential());
    final manager = WebVpnSessionManager(
      store: store,
      validator: _FakeValidator([WebVpnState.valid]),
      clock: () => now,
    );

    expect(await manager.restore(), WebVpnState.valid);
    final saved = await store.read();
    expect(saved?.lastValidatedAt, now);
    expect(manager.ticketHeader, '$ticketName=ticket-1');
  });

  test('expired ticket is cleared from storage', () async {
    final memory = _MemoryStore();
    final store = WebVpnCredentialStore(store: memory);
    await store.write(credential());
    final manager = WebVpnSessionManager(
      store: store,
      validator: _FakeValidator([WebVpnState.expired]),
      clock: () => now,
    );

    expect(await manager.restore(), WebVpnState.expired);
    expect(await store.read(), isNull);
    expect(manager.credential, isNull);
  });

  test('expired ticket silently renews with the stored SSO session', () async {
    final memory = _MemoryStore();
    final store = WebVpnCredentialStore(store: memory);
    await store.write(credential());
    var renewCalls = 0;
    final manager = WebVpnSessionManager(
      store: store,
      validator: _FakeValidator([WebVpnState.expired]),
      renew: () async {
        renewCalls++;
        return WebVpnSession(credential: credential(value: 'ticket-2'));
      },
      clock: () => now,
    );

    expect(await manager.restore(), WebVpnState.valid);
    expect(renewCalls, 1);
    expect(manager.ticketHeader, '$ticketName=ticket-2');
    expect((await store.read())?.ticketValue, 'ticket-2');
  });

  test('failed silent renewal leaves the session expired', () async {
    final memory = _MemoryStore();
    final store = WebVpnCredentialStore(store: memory);
    await store.write(credential());
    final manager = WebVpnSessionManager(
      store: store,
      validator: _FakeValidator([WebVpnState.expired]),
      renew: () async => null,
      clock: () => now,
    );

    expect(await manager.restore(), WebVpnState.expired);
    expect(manager.credential, isNull);
    expect(await store.read(), isNull);
  });

  test('offline validation keeps the ticket', () async {
    final memory = _MemoryStore();
    final store = WebVpnCredentialStore(store: memory);
    await store.write(credential());
    final manager = WebVpnSessionManager(
      store: store,
      validator: _FakeValidator([WebVpnState.offline]),
      clock: () => now,
    );

    expect(await manager.restore(), WebVpnState.offline);
    expect(await store.read(), isNotNull);
    expect(manager.credential, isNotNull);
  });

  test('valid state is reused inside the TTL', () async {
    var clock = now;
    final validator = _FakeValidator([WebVpnState.valid]);
    final manager = WebVpnSessionManager(
      store: WebVpnCredentialStore(store: _MemoryStore()),
      validator: validator,
      clock: () => clock,
      validationTtl: const Duration(minutes: 5),
    );
    await manager.adopt(credential());

    expect(await manager.validate(), WebVpnState.valid);
    expect(validator.calls, 0);
    clock = now.add(const Duration(minutes: 6));
    expect(await manager.validate(force: true), WebVpnState.valid);
    expect(validator.calls, 1);
  });

  test('updateTicket persists rotation and empty value invalidates', () async {
    final memory = _MemoryStore();
    final store = WebVpnCredentialStore(store: memory);
    final manager = WebVpnSessionManager(
      store: store,
      validator: _FakeValidator([WebVpnState.valid]),
      clock: () => now,
    );
    await manager.adopt(credential());

    await manager.updateTicket(ticketName, 'ticket-2');
    expect(manager.credential?.ticketValue, 'ticket-2');
    expect((await store.read())?.ticketValue, 'ticket-2');

    await manager.updateTicket(ticketName, '');
    expect(manager.credential, isNull);
    expect(await store.read(), isNull);
    expect(manager.state, WebVpnState.expired);
  });

  test('startup routes cover ticket, GMIS and offline states', () {
    expect(
      decideStartup(
        webVpn: WebVpnState.valid,
        hasCredential: true,
        hasGmisSession: true,
        hasDirectSession: false,
        defaultWebVpn: true,
      ),
      WebVpnStartupRoute.webVpnReady,
    );
    expect(
      decideStartup(
        webVpn: WebVpnState.valid,
        hasCredential: true,
        hasGmisSession: false,
        hasDirectSession: false,
        defaultWebVpn: true,
      ),
      WebVpnStartupRoute.gmisLogin,
    );
    expect(
      decideStartup(
        webVpn: WebVpnState.expired,
        hasCredential: false,
        hasGmisSession: true,
        hasDirectSession: false,
        defaultWebVpn: true,
      ),
      WebVpnStartupRoute.ssoLogin,
    );
    expect(
      decideStartup(
        webVpn: WebVpnState.offline,
        hasCredential: true,
        hasGmisSession: true,
        hasDirectSession: false,
        defaultWebVpn: true,
      ),
      WebVpnStartupRoute.offline,
    );
    expect(
      decideStartup(
        webVpn: WebVpnState.unknown,
        hasCredential: false,
        hasGmisSession: false,
        hasDirectSession: true,
        defaultWebVpn: true,
      ),
      WebVpnStartupRoute.direct,
    );
    expect(
      decideStartup(
        webVpn: WebVpnState.unknown,
        hasCredential: false,
        hasGmisSession: false,
        hasDirectSession: false,
        defaultWebVpn: true,
      ),
      WebVpnStartupRoute.ssoLogin,
    );
  });
}
