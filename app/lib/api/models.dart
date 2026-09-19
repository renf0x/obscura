/// Plain data classes mirroring the hub's JSON. Kept mutable where screens edit them in place.
library;

import 'dart:ui';

class Zone {
  Zone({required this.id, required this.name, required this.points, this.motion = true, this.person = true});

  final String id;
  String name;
  List<List<double>> points; // normalized [x, y], 0..1
  bool motion;
  bool person;

  factory Zone.fromJson(Map<String, dynamic> j) => Zone(
        id: j['id'] as String,
        name: j['name'] as String? ?? 'Zone',
        points: [for (final p in j['points'] as List) [(p[0] as num).toDouble(), (p[1] as num).toDouble()]],
        motion: j['motion'] as bool? ?? true,
        person: j['person'] as bool? ?? true,
      );

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'points': points, 'motion': motion, 'person': person};

  Zone copy() => Zone(id: id, name: name, points: [for (final p in points) [...p]], motion: motion, person: person);
}

class Schedule {
  Schedule({this.mode = 'always', this.start = '22:00', this.end = '07:00', List<int>? days})
      : days = days ?? [0, 1, 2, 3, 4, 5, 6];

  String mode;
  String start;
  String end;
  List<int> days; // 0 = Monday

  factory Schedule.fromJson(Map<String, dynamic> j) => Schedule(
        mode: j['mode'] as String? ?? 'always',
        start: j['start'] as String? ?? '22:00',
        end: j['end'] as String? ?? '07:00',
        days: [for (final d in j['days'] as List? ?? const [0, 1, 2, 3, 4, 5, 6]) d as int],
      );

  Map<String, dynamic> toJson() => {'mode': mode, 'start': start, 'end': end, 'days': days};
}

class CameraConfig {
  CameraConfig({
    required this.motion,
    required this.person,
    required this.sensitivity,
    required this.zones,
    required this.schedule,
    required this.notifyMotion,
    required this.notifyPerson,
    required this.sirenOnPerson,
    required this.sirenSeconds,
    required this.recordQuality,
  });

  bool motion;
  bool person;
  String sensitivity; // low | medium | high
  List<Zone> zones;
  Schedule schedule;
  bool notifyMotion;
  bool notifyPerson;
  bool sirenOnPerson;
  int sirenSeconds;
  String recordQuality; // high | low (sub stream)

  factory CameraConfig.fromJson(Map<String, dynamic> j) => CameraConfig(
        motion: j['motion'] as bool? ?? true,
        person: j['person'] as bool? ?? true,
        sensitivity: j['sensitivity'] as String? ?? 'medium',
        zones: [for (final z in j['zones'] as List? ?? const []) Zone.fromJson(z as Map<String, dynamic>)],
        schedule: Schedule.fromJson(j['schedule'] as Map<String, dynamic>? ?? const {}),
        notifyMotion: j['notify_motion'] as bool? ?? true,
        notifyPerson: j['notify_person'] as bool? ?? true,
        sirenOnPerson: j['siren_on_person'] as bool? ?? false,
        sirenSeconds: j['siren_seconds'] as int? ?? 30,
        recordQuality: j['record_quality'] as String? ?? 'high',
      );

  Map<String, dynamic> toJson() => {
        'motion': motion,
        'person': person,
        'sensitivity': sensitivity,
        'zones': [for (final z in zones) z.toJson()],
        'schedule': schedule.toJson(),
        'notify_motion': notifyMotion,
        'notify_person': notifyPerson,
        'siren_on_person': sirenOnPerson,
        'siren_seconds': sirenSeconds,
        'record_quality': recordQuality,
      };
}

class Camera {
  Camera({
    required this.id,
    required this.name,
    required this.vendor,
    required this.host,
    required this.port,
    required this.username,
    required this.hasPassword,
    required this.mainPath,
    required this.subPath,
    required this.enabled,
    required this.online,
    required this.config,
    this.hasCloudPassword = false,
    this.twoWay = false,
    this.canTalk = false,
    this.siren,
    this.controlError,
  });

  final int id;
  final String name;
  final String vendor;
  final String host;
  final int port;
  final String username;
  final bool hasPassword;
  final String mainPath;
  final String subPath;
  final bool enabled;
  final bool online;
  final CameraConfig config;
  final bool hasCloudPassword; // Tapo: TP-Link account password set on the hub
  final bool twoWay; // other brands: camera has a speaker
  final bool canTalk;
  final String? siren; // 'tapo' (camera's own alarm), 'speaker' (sound via speaker) or null
  final String? controlError;

  factory Camera.fromJson(Map<String, dynamic> j) => Camera(
        id: j['id'] as int,
        name: j['name'] as String,
        vendor: j['vendor'] as String,
        host: j['host'] as String,
        port: j['port'] as int,
        username: j['username'] as String? ?? '',
        hasPassword: j['has_password'] as bool? ?? false,
        mainPath: j['main_path'] as String? ?? '',
        subPath: j['sub_path'] as String? ?? '',
        enabled: j['enabled'] as bool? ?? true,
        online: j['online'] as bool? ?? false,
        config: CameraConfig.fromJson(j['config'] as Map<String, dynamic>? ?? const {}),
        hasCloudPassword: j['has_cloud_password'] as bool? ?? false,
        twoWay: j['two_way'] as bool? ?? false,
        canTalk: (j['capabilities'] as Map?)?['talk'] as bool? ?? false,
        siren: (j['capabilities'] as Map?)?['siren'] as String?,
        controlError: j['control_error'] as String?,
      );
}

class HubEvent {
  HubEvent({
    required this.id,
    required this.cameraId,
    required this.camera,
    required this.kind,
    required this.startedAt,
    required this.endedAt,
    required this.zones,
    required this.hasClip,
    required this.hasThumb,
    required this.hasTrack,
    required this.uploaded,
  });

  final int id;
  final int cameraId;
  final String camera;
  final String kind; // motion | person | manual
  final DateTime startedAt;
  final DateTime? endedAt;
  final List<String> zones;
  final bool hasClip;
  final bool hasThumb;
  final bool hasTrack; // zones and motion marks to draw over the clip
  final bool uploaded;

  static DateTime _ts(num v) => DateTime.fromMillisecondsSinceEpoch((v * 1000).round());

  factory HubEvent.fromJson(Map<String, dynamic> j) => HubEvent(
        id: j['id'] as int,
        cameraId: j['camera_id'] as int,
        camera: j['camera'] as String? ?? '',
        kind: j['kind'] as String,
        startedAt: _ts(j['started_at'] as num),
        endedAt: j['ended_at'] == null ? null : _ts(j['ended_at'] as num),
        zones: [for (final z in j['zones'] as List? ?? const []) z as String],
        hasClip: j['has_clip'] as bool? ?? false,
        hasThumb: j['has_thumb'] as bool? ?? false,
        hasTrack: j['has_track'] as bool? ?? false,
        uploaded: j['uploaded'] as bool? ?? false,
      );
}

/// Where things moved during an event, timed to the clip (seconds from its first frame).
class EventTrack {
  EventTrack.fromJson(Map<String, dynamic> j)
      : zones = [
          for (final z in j['zones'] as List? ?? const [])
            [for (final p in (z as Map<String, dynamic>)['points'] as List? ?? const []) Offset(_d((p as List)[0]), _d(p[1]))]
        ],
        marks = [
          for (final m in j['marks'] as List? ?? const [])
            TrackMark(
              _d((m as List)[0]),
              [for (final s in m[1] as List? ?? const []) (x: _d((s as List)[0]), y: _d(s[1]), r: _d(s[2]))],
              m[2] == null ? null : Rect.fromLTRB(_d(m[2][0]), _d(m[2][1]), _d(m[2][2]), _d(m[2][3])),
            )
        ];

  final List<List<Offset>> zones; // normalized polygons
  final List<TrackMark> marks; // sorted by time

  static double _d(Object? v) => (v as num).toDouble();
}

class TrackMark {
  const TrackMark(this.t, this.spots, this.person);

  final double t;
  final List<({double x, double y, double r})> spots; // normalized centre and radius
  final Rect? person; // normalized box
}

class Overview {
  Overview.fromJson(Map<String, dynamic> j)
      : hubName = j['hub_name'] as String? ?? 'Obscura hub',
        version = j['version'] as String? ?? '',
        cameras = j['cameras'] as int? ?? 0,
        online = j['online'] as int? ?? 0,
        offline = j['offline'] as int? ?? 0,
        alerts24h = j['alerts_24h'] as int? ?? 0,
        people24h = j['people_24h'] as int? ?? 0,
        personDetection = j['person_detection'] as bool? ?? false,
        storageBytes = (j['storage'] as Map?)?['bytes'] as int? ?? 0,
        diskFree = ((j['storage'] as Map?)?['disk'] as Map?)?['free'] as int?;

  final String hubName;
  final String version;
  final int cameras;
  final int online;
  final int offline;
  final int alerts24h;
  final int people24h;
  final bool personDetection;
  final int storageBytes;
  final int? diskFree;
}

class Device {
  Device.fromJson(Map<String, dynamic> j)
      : id = j['id'] as int,
        name = j['name'] as String,
        lastSeen = DateTime.fromMillisecondsSinceEpoch(((j['last_seen'] as num) * 1000).round()),
        push = j['push'] as bool? ?? false,
        current = j['current'] as bool? ?? false;

  final int id;
  final String name;
  final DateTime lastSeen;
  final bool push;
  final bool current;
}

class DiscoveredCamera {
  DiscoveredCamera.fromJson(Map<String, dynamic> j)
      : host = j['host'] as String,
        vendor = j['vendor'] as String? ?? 'generic',
        added = j['added'] as bool? ?? false;

  final String host;
  final String vendor;
  final bool added;
}
