import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../api/hub_client.dart';

/// Paired hub + local preferences. Secrets live in the platform keystore, not in plain prefs.
class Session extends ChangeNotifier {
  Session({FlutterSecureStorage? storage}) : _store = storage ?? const FlutterSecureStorage();

  final FlutterSecureStorage _store;
  HubClient? client;
  String hubName = '';
  bool appLock = false;
  bool loaded = false;

  bool get paired => client != null;

  Future<void> load() async {
    final url = await _store.read(key: 'hub_url');
    final token = await _store.read(key: 'hub_token');
    hubName = await _store.read(key: 'hub_name') ?? '';
    appLock = await _store.read(key: 'app_lock') == '1';
    if (url != null && token != null) client = HubClient(Uri.parse(url), token);
    loaded = true;
    notifyListeners();
  }

  Future<void> pair(Uri url, String code, String deviceName) async {
    final result = await HubClient.pair(url, code, deviceName);
    await _store.write(key: 'hub_url', value: url.toString());
    await _store.write(key: 'hub_token', value: result.token);
    await _store.write(key: 'hub_name', value: result.hubName);
    client = HubClient(url, result.token);
    hubName = result.hubName;
    notifyListeners();
  }

  Future<void> forget() async {
    await _store.deleteAll();
    client = null;
    hubName = '';
    appLock = false;
    notifyListeners();
  }

  Future<void> setAppLock(bool on) async {
    await _store.write(key: 'app_lock', value: on ? '1' : '0');
    appLock = on;
    notifyListeners();
  }

  Future<String?> read(String key) => _store.read(key: key);

  Future<void> write(String key, String value) => _store.write(key: key, value: value);
}

class SessionScope extends InheritedNotifier<Session> {
  const SessionScope({super.key, required Session session, required super.child}) : super(notifier: session);

  static Session of(BuildContext context) => context.dependOnInheritedWidgetOfExactType<SessionScope>()!.notifier!;

  /// Read without subscribing (for callbacks).
  static Session read(BuildContext context) => context.getInheritedWidgetOfExactType<SessionScope>()!.notifier!;
}

enum HubUrlIssue { invalid, insecurePublic }

/// Parse what the user typed. Plain http is fine on LAN / Tailscale (WireGuard-encrypted),
/// but over the public internet the token would travel in clear text.
({Uri? url, HubUrlIssue? issue}) parseHubUrl(String input) {
  var text = input.trim();
  if (text.isEmpty) return (url: null, issue: HubUrlIssue.invalid);
  if (!text.contains('://')) text = 'http://$text';
  final uri = Uri.tryParse(text);
  if (uri == null || !(uri.scheme == 'http' || uri.scheme == 'https') || uri.host.isEmpty || uri.userInfo.isNotEmpty) {
    return (url: null, issue: HubUrlIssue.invalid);
  }
  final url = uri.hasPort || uri.scheme == 'https' ? uri : uri.replace(port: 7878);
  final clean = url.replace(query: null, fragment: null);
  if (url.scheme == 'http' && !isPrivateHost(url.host)) return (url: clean, issue: HubUrlIssue.insecurePublic);
  return (url: clean, issue: null);
}

bool isPrivateHost(String host) {
  if (host == 'localhost' || host.endsWith('.local') || host.endsWith('.lan') || host.endsWith('.ts.net')) return true;
  final ip = InternetAddress.tryParse(host);
  if (ip == null) return false;
  if (ip.type == InternetAddressType.IPv6) {
    return ip.isLoopback || ip.isLinkLocal || host.toLowerCase().startsWith('fd') || host.toLowerCase().startsWith('fc');
  }
  final b = ip.rawAddress;
  return b[0] == 10 ||
      b[0] == 127 ||
      (b[0] == 172 && b[1] >= 16 && b[1] <= 31) ||
      (b[0] == 192 && b[1] == 168) ||
      (b[0] == 100 && b[1] >= 64 && b[1] <= 127) || // CGNAT range used by Tailscale
      (b[0] == 169 && b[1] == 254);
}
