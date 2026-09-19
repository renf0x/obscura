import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:obscura/api/hub_client.dart';
import 'package:obscura/api/models.dart';
import 'package:obscura/services/push.dart';
import 'package:obscura/state/session.dart';

void main() {
  group('parseHubUrl', () {
    test('adds scheme and default port', () {
      final r = parseHubUrl('192.168.1.10');
      expect(r.url.toString(), 'http://192.168.1.10:7878');
      expect(r.issue, isNull);
    });

    test('keeps https without forcing a port', () {
      final r = parseHubUrl('https://cam.example.com');
      expect(r.url.toString(), 'https://cam.example.com');
      expect(r.issue, isNull);
    });

    test('flags plain http to a public host', () {
      expect(parseHubUrl('http://8.8.8.8:7878').issue, HubUrlIssue.insecurePublic);
      expect(parseHubUrl('cam.example.com:7878').issue, HubUrlIssue.insecurePublic);
    });

    test('treats Tailscale and LAN as private', () {
      expect(parseHubUrl('100.101.102.103:7878').issue, isNull);
      expect(parseHubUrl('hub.tail1234.ts.net:7878').issue, isNull);
      expect(parseHubUrl('10.0.0.5').issue, isNull);
    });

    test('rejects junk and embedded credentials', () {
      for (final bad in ['', 'ftp://x', 'http://user:pw@10.0.0.1', '://']) {
        expect(parseHubUrl(bad).issue, HubUrlIssue.invalid, reason: bad);
      }
    });
  });

  test('push payload encrypted by the hub decrypts on the phone', () async {
    // Vector produced by hub/obscura/security.py encrypt_push() with key bytes 0..31.
    const key = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8';
    const body =
        '8b5TU6D8gfSCHVikxBpcpoiCopG2pACKJE3iJVR5o93YKDuMBjAVZcdhnfWaHjiddCNBhIClhEWHEsQNZaS4Ldzow03j/'
        '7P2T+QuOzWzywjKPI3KZ+i5jdmoIFKI6i/x/nl73ajSVyDQVlanft3CcwMVaGSWrxznkuwxznX5Y1lmtgkx0ONw';
    final data = await Push.decrypt(key, body);
    expect(data, {'e': 42, 'k': 'person', 'c': 'Входная дверь', 't': 1});
  });

  test('tampered push payload is rejected', () async {
    const key = 'AAECAwQFBgcICQoLDA0ODxAREhMUFRYXGBkaGxwdHh8';
    final blob = base64.decode(
      '8b5TU6D8gfSCHVikxBpcpoiCopG2pACKJE3iJVR5o93YKDuMBjAVZcdhnfWaHjiddCNBhIClhEWHEsQNZaS4Ldzow03j/'
      '7P2T+QuOzWzywjKPI3KZ+i5jdmoIFKI6i/x/nl73ajSVyDQVlanft3CcwMVaGSWrxznkuwxznX5Y1lmtgkx0ONw',
    );
    blob[20] ^= 1;
    expect(await Push.decrypt(key, base64.encode(blob)), isNull);
    expect(await Push.decrypt(key, 'not base64'), isNull);
  });

  group('HubClient', () {
    test('sends the token only as a header', () async {
      late http.Request seen;
      final client = HubClient(
        Uri.parse('http://10.0.0.2:7878'),
        'secret-token',
        client: MockClient((req) async {
          seen = req;
          return http.Response('[]', 200, headers: {'content-type': 'application/json'});
        }),
      );
      await client.cameras();
      expect(seen.headers['Authorization'], 'Bearer secret-token');
      expect(seen.url.toString(), isNot(contains('secret-token')));
      expect(client.liveUrl(1).toString(), isNot(contains('secret-token')));
    });

    test('surfaces the hub error detail', () async {
      final client = HubClient(
        Uri.parse('http://10.0.0.2:7878'),
        't',
        client: MockClient((_) async {
          return http.Response(
            jsonEncode({'detail': 'camera is offline'}),
            409,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      expect(
        () => client.record(1),
        throwsA(isA<HubException>().having((e) => e.message, 'message', 'camera is offline')),
      );
    });

    test('pair posts code without auth header', () async {
      late http.Request seen;
      final result = await HubClient.pair(
        Uri.parse('http://10.0.0.2:7878'),
        'ABCDE-FGHJK',
        'Pixel',
        client: MockClient((req) async {
          seen = req;
          return http.Response(
            jsonEncode({'token': 'tok', 'hub_name': 'Home'}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }),
      );
      expect(result.token, 'tok');
      expect(seen.headers.containsKey('Authorization'), isFalse);
      expect(jsonDecode(seen.body), {'code': 'ABCDE-FGHJK', 'device_name': 'Pixel'});
    });
  });

  test('camera config round-trips zones', () {
    final cfg = CameraConfig.fromJson({
      'motion': false,
      'zones': [
        {
          'id': 'z1',
          'name': 'Porch',
          'points': [
            [0, 0],
            [1, 0],
            [0.5, 1],
          ],
          'motion': false,
          'person': true,
        },
      ],
      'schedule': {
        'mode': 'window',
        'start': '22:00',
        'end': '06:00',
        'days': [5, 6],
      },
    });
    final back = CameraConfig.fromJson(jsonDecode(jsonEncode(cfg.toJson())) as Map<String, dynamic>);
    expect(back.motion, isFalse);
    expect(back.zones.single.points[2], [0.5, 1.0]);
    expect(back.zones.single.person, isTrue);
    expect(back.schedule.days, [5, 6]);
  });

  test('camera capabilities and siren settings', () {
    final cam = Camera.fromJson({
      'id': 1,
      'name': 'Door',
      'vendor': 'tapo',
      'host': '10.0.0.5',
      'port': 554,
      'has_cloud_password': true,
      'capabilities': {'talk': true, 'siren': 'tapo'},
      'config': {'siren_on_person': true, 'siren_seconds': 60},
    });
    expect(cam.canTalk, isTrue);
    expect(cam.siren, 'tapo');
    expect(cam.config.toJson()['siren_seconds'], 60);
    final old = Camera.fromJson({'id': 2, 'name': 'Old hub', 'vendor': 'generic', 'host': 'h', 'port': 554});
    expect(old.canTalk, isFalse);
    expect(old.siren, isNull);
    expect(old.config.sirenOnPerson, isFalse);
  });

  test('talk uploads raw audio with the token header', () async {
    late http.Request seen;
    final hub = HubClient(
      Uri.parse('http://10.0.0.2:7878'),
      'secret',
      client: MockClient((req) async {
        seen = req;
        return http.Response('', 204);
      }),
    );
    await hub.talk(3, Uint8List.fromList([1, 2, 3]));
    expect(seen.url.path, '/api/cameras/3/talk');
    expect(seen.headers['Content-Type'], 'audio/mp4');
    expect(seen.headers['Authorization'], 'Bearer secret');
    expect(seen.bodyBytes, [1, 2, 3]);
  });
}
