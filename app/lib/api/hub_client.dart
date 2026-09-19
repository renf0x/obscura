import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'models.dart';

class HubException implements Exception {
  HubException(this.status, this.message);

  final int status;
  final String message;

  bool get unauthorized => status == 401;

  @override
  String toString() => message;
}

/// Talks to one paired hub. The token is sent only as a header, never in URLs (keeps it out of logs).
class HubClient {
  HubClient(this.baseUrl, this.token, {http.Client? client}) : _http = client ?? http.Client();

  final Uri baseUrl;
  final String token;
  final http.Client _http;

  static const _timeout = Duration(seconds: 15);

  Map<String, String> get authHeaders => {'Authorization': 'Bearer $token'};

  Uri url(String path, [Map<String, String>? query]) =>
      baseUrl.replace(path: '${baseUrl.path.replaceAll(RegExp(r'/$'), '')}$path', queryParameters: query);

  /// Pair with a code shown in the hub logs (or on another phone). Returns the device token.
  static Future<({String token, String hubName})> pair(Uri baseUrl, String code, String deviceName,
      {http.Client? client}) async {
    final c = HubClient(baseUrl, '', client: client);
    final body = await c._send('POST', '/api/pair', body: {'code': code, 'device_name': deviceName}, auth: false);
    return (token: body['token'] as String, hubName: body['hub_name'] as String? ?? 'Obscura hub');
  }

  Future<dynamic> _send(String method, String path,
      {Object? body, Map<String, String>? query, bool auth = true, Uint8List? bytes, Duration? timeout}) async {
    final req = http.Request(method, url(path, query));
    if (auth) req.headers.addAll(authHeaders);
    if (bytes != null) {
      req.headers['Content-Type'] = 'audio/mp4';
      req.bodyBytes = bytes;
    } else if (body != null) {
      req.headers['Content-Type'] = 'application/json';
      req.body = jsonEncode(body);
    }
    final http.Response res;
    try {
      res = await http.Response.fromStream(await _http.send(req).timeout(timeout ?? _timeout));
    } on TimeoutException {
      throw HubException(0, 'timeout');
    } on http.ClientException catch (e) {
      throw HubException(0, e.message);
    }
    if (res.statusCode >= 400) {
      var message = 'HTTP ${res.statusCode}';
      try {
        final detail = (jsonDecode(res.body) as Map)['detail'];
        message = detail is String ? detail : (detail is List && detail.isNotEmpty ? '${detail.first['msg']}' : message);
      } catch (_) {}
      throw HubException(res.statusCode, message);
    }
    if (res.body.isEmpty) return null;
    final type = res.headers['content-type'] ?? '';
    return type.contains('json') ? jsonDecode(utf8.decode(res.bodyBytes)) : res.bodyBytes;
  }

  Future<Overview> overview() async => Overview.fromJson(await _send('GET', '/api/overview'));

  Future<List<Camera>> cameras() async =>
      [for (final c in await _send('GET', '/api/cameras') as List) Camera.fromJson(c as Map<String, dynamic>)];

  Future<Camera> camera(int id) async => Camera.fromJson(await _send('GET', '/api/cameras/$id'));

  Future<Map<String, dynamic>> presets() async => (await _send('GET', '/api/presets') as Map).cast();

  Future<List<DiscoveredCamera>> discover() async => [
        for (final d in await _send('GET', '/api/discover') as List) DiscoveredCamera.fromJson(d as Map<String, dynamic>)
      ];

  Future<Camera> addCamera(Map<String, dynamic> body) async => Camera.fromJson(await _send('POST', '/api/cameras', body: body));

  Future<Camera> updateConnection(int id, Map<String, dynamic> body) async =>
      Camera.fromJson(await _send('PUT', '/api/cameras/$id', body: body));

  Future<Camera> patchCamera(int id, {String? name, bool? enabled, CameraConfig? config}) async =>
      Camera.fromJson(await _send('PATCH', '/api/cameras/$id', body: {
        'name': ?name,
        'enabled': ?enabled,
        if (config != null) 'config': config.toJson(),
      }));

  Future<void> deleteCamera(int id, {bool deleteEvents = false}) =>
      _send('DELETE', '/api/cameras/$id', query: {'delete_events': '$deleteEvents'});

  Future<Uint8List> snapshot(int id) async => await _send('GET', '/api/cameras/$id/snapshot') as Uint8List;

  Future<void> record(int id) => _send('POST', '/api/cameras/$id/record');

  Future<void> stopRecord(int id) => _send('DELETE', '/api/cameras/$id/record');

  /// Push-to-talk: an AAC (.m4a) recording that the hub plays through the camera's speaker.
  Future<void> talk(int id, Uint8List recording) =>
      _send('POST', '/api/cameras/$id/talk', bytes: recording, timeout: const Duration(seconds: 45));

  /// Returns how many seconds the siren will sound (0 when switched off).
  Future<int> siren(int id, bool on, {int seconds = 30}) async {
    final r = await _send('POST', '/api/cameras/$id/siren', body: {'on': on, 'seconds': seconds}) as Map;
    return r['seconds'] as int? ?? 0;
  }

  Future<({bool ok, String message})> testControl(int id) async {
    final r = await _send('POST', '/api/cameras/$id/control/test', timeout: const Duration(seconds: 30)) as Map;
    return (ok: r['ok'] as bool? ?? false, message: r['message'] as String? ?? '');
  }

  /// Video only unless [audio]: the hub then skips audio transcoding, which is also lighter on mobile data.
  Uri liveUrl(int id, {bool hd = false, bool audio = false}) =>
      url('/api/cameras/$id/live', {'quality': hd ? 'main' : 'sub', if (audio) 'audio': 'true'});

  Future<List<HubEvent>> events({int? cameraId, String? kind, DateTime? before, int limit = 50}) async {
    final list = await _send('GET', '/api/events', query: {
      'camera_id': ?cameraId?.toString(),
      'kind': ?kind,
      if (before != null) 'before': '${before.millisecondsSinceEpoch / 1000}',
      'limit': '$limit',
    }) as List;
    return [for (final e in list) HubEvent.fromJson(e as Map<String, dynamic>)];
  }

  Future<HubEvent> event(int id) async => HubEvent.fromJson(await _send('GET', '/api/events/$id'));

  Uri clipUrl(int id) => url('/api/events/$id/clip');

  Uri thumbUrl(int id) => url('/api/events/$id/thumb');

  Future<EventTrack> eventTrack(int id) async =>
      EventTrack.fromJson(await _send('GET', '/api/events/$id/track') as Map<String, dynamic>);

  Future<Uint8List> clipBytes(int id) async => await _send('GET', '/api/events/$id/clip') as Uint8List;

  Future<void> deleteEvent(int id) => _send('DELETE', '/api/events/$id');

  Future<void> deleteAllEvents({int? cameraId}) =>
      _send('DELETE', '/api/events', query: cameraId == null ? null : {'camera_id': '$cameraId'});

  Future<List<Device>> devices() async =>
      [for (final d in await _send('GET', '/api/devices') as List) Device.fromJson(d as Map<String, dynamic>)];

  Future<void> revokeDevice(int id) => _send('DELETE', '/api/devices/$id');

  Future<String> newPairingCode() async => (await _send('POST', '/api/pairing-code') as Map)['code'] as String;

  Future<void> setPush(String endpoint, String key) =>
      _send('PUT', '/api/devices/me/push', body: {'endpoint': endpoint, 'key': key});

  Future<void> clearPush() => _send('DELETE', '/api/devices/me/push');

  Future<Map<String, dynamic>> storage() async => (await _send('GET', '/api/settings/storage') as Map).cast();

  Future<void> putStorage(Map<String, dynamic> body) => _send('PUT', '/api/settings/storage', body: body);

  Future<void> setBackend(String type, Map<String, String> options) =>
      _send('POST', '/api/settings/storage/backend', body: {'type': type, 'options': options});

  Future<({bool ok, String message})> testStorage() async {
    final r = await _send('POST', '/api/settings/storage/test') as Map;
    return (ok: r['ok'] as bool, message: r['message'] as String? ?? '');
  }

  Future<Map<String, dynamic>> ntfy() async => (await _send('GET', '/api/settings/ntfy') as Map).cast();

  Future<void> putNtfy(Map<String, dynamic> body) => _send('PUT', '/api/settings/ntfy', body: body);

  Future<void> setHubName(String name) => _send('PUT', '/api/settings/name', body: {'name': name});

  /// Server-sent events from the hub, reconnecting with backoff until the stream is cancelled.
  Stream<Map<String, dynamic>> liveEvents() async* {
    var delay = const Duration(seconds: 2);
    while (true) {
      final client = http.Client();
      try {
        final req = http.Request('GET', url('/api/events/stream'))..headers.addAll(authHeaders);
        final res = await client.send(req);
        if (res.statusCode == 401) throw HubException(401, 'not paired');
        delay = const Duration(seconds: 2);
        var data = StringBuffer();
        await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
          if (line.startsWith('data:')) {
            data.write(line.substring(5).trim());
          } else if (line.isEmpty && data.isNotEmpty) {
            yield jsonDecode(data.toString()) as Map<String, dynamic>;
            data = StringBuffer();
          }
        }
      } on HubException {
        rethrow;
      } catch (_) {
        // network drop: fall through to retry
      } finally {
        client.close();
      }
      await Future<void>.delayed(delay);
      delay = delay * 2 > const Duration(minutes: 1) ? const Duration(minutes: 1) : delay * 2;
    }
  }
}
