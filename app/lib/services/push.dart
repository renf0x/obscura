import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:unifiedpush/unifiedpush.dart';

import '../api/hub_client.dart';
import 'notifications.dart';

enum PushStatus { active, noDistributor, off, error }

/// Background push without Google services: UnifiedPush delivers the hub's message through a
/// distributor app (e.g. ntfy). The payload is AES-GCM encrypted with a key only this phone and
/// the hub know, so the push relay sees nothing but ciphertext.
abstract final class Push {
  static const _store = FlutterSecureStorage();
  static final status = ValueNotifier<PushStatus>(PushStatus.off);

  static Future<void> init() async {
    final registered = await UnifiedPush.initialize(
      onNewEndpoint: (endpoint, _) => _onEndpoint(endpoint.url),
      onRegistrationFailed: (_, _) => status.value = PushStatus.error,
      onUnregistered: (_) async {
        status.value = PushStatus.off;
        await (await _loadClient())?.clearPush().catchError((_) {});
      },
      onMessage: (message, _) => _onMessage(message.content),
    );
    if (registered) status.value = PushStatus.active;
  }

  /// Returns false when no distributor app is installed (the UI then shows the ntfy guide).
  static Future<bool> enable() async {
    if (await UnifiedPush.tryUseCurrentOrDefaultDistributor()) {
      await UnifiedPush.register();
      return true;
    }
    final distributors = await UnifiedPush.getDistributors();
    if (distributors.isEmpty) {
      status.value = PushStatus.noDistributor;
      return false;
    }
    await UnifiedPush.saveDistributor(distributors.first);
    await UnifiedPush.register();
    return true;
  }

  static Future<void> disable() async {
    await UnifiedPush.unregister();
    await (await _loadClient())?.clearPush().catchError((_) {});
    status.value = PushStatus.off;
  }

  /// The background isolate has no Session, so read the pairing straight from secure storage.
  static Future<HubClient?> _loadClient() async {
    final url = await _store.read(key: 'hub_url');
    final token = await _store.read(key: 'hub_token');
    return url != null && token != null ? HubClient(Uri.parse(url), token) : null;
  }

  static Future<String> _key() async {
    var key = await _store.read(key: 'push_key');
    if (key == null) {
      final rnd = Random.secure();
      key = base64Url.encode(List<int>.generate(32, (_) => rnd.nextInt(256))).replaceAll('=', '');
      await _store.write(key: 'push_key', value: key);
    }
    return key;
  }

  static Future<void> _onEndpoint(String url) async {
    final client = await _loadClient();
    if (client == null) return;
    try {
      await client.setPush(url, await _key());
      status.value = PushStatus.active;
    } catch (_) {
      status.value = PushStatus.error;
    }
  }

  static Future<void> _onMessage(Uint8List content) async {
    final data = await decrypt(await _key(), utf8.decode(content, allowMalformed: true));
    if (data == null) return; // not from our hub, or tampered with
    await Notifications.showEvent(
      eventId: data['e'] as int,
      kind: data['k'] as String,
      camera: data['c'] as String? ?? '',
    );
  }

  @visibleForTesting
  static Future<Map<String, dynamic>?> decrypt(String keyB64, String body) async {
    try {
      final key = base64Url.decode(base64Url.normalize(keyB64));
      final blob = base64.decode(body.trim());
      if (blob.length < 12 + 16) return null;
      final box = SecretBox(
        blob.sublist(12, blob.length - 16),
        nonce: blob.sublist(0, 12),
        mac: Mac(blob.sublist(blob.length - 16)),
      );
      final plain = await AesGcm.with256bits().decrypt(box, secretKey: SecretKey(key));
      return jsonDecode(utf8.decode(plain)) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }
}
