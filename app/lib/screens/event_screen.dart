import 'dart:io';

import 'package:flutter/material.dart';
import 'package:gal/gal.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'home_shell.dart';

class EventScreen extends StatefulWidget {
  const EventScreen({super.key, required this.eventId});

  final int eventId;

  @override
  State<EventScreen> createState() => _EventScreenState();
}

class _EventScreenState extends State<EventScreen> with WidgetsBindingObserver {
  final _player = Player();
  late final _video = VideoController(_player);
  HubEvent? _event;
  Object? _error;
  bool _sharing = false;
  EventTrack? _track;
  bool _overlay = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Don't keep decoding the clip in the background; the user resumes it with the play button.
    if (state == AppLifecycleState.paused) _player.pause();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final hub = context.hub;
    try {
      final ev = await hub.event(widget.eventId);
      if (!mounted) return;
      setState(() {
        _event = ev;
        _error = null;
      });
      if (ev.hasTrack && _track == null) {
        hub.eventTrack(ev.id).then((t) {
          if (mounted) setState(() => _track = t);
        }).catchError((_) {});
      }
      if (ev.hasClip) {
        await _player.open(Media(hub.clipUrl(ev.id).toString(), httpHeaders: hub.authHeaders), play: true);
      } else if (ev.endedAt == null || DateTime.now().difference(ev.endedAt!) < const Duration(minutes: 1)) {
        // Clip is still being cut on the hub; check again shortly.
        Future<void>.delayed(const Duration(seconds: 5), () {
          if (mounted) _load();
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<File> _clipFile() async {
    final bytes = await context.hub.clipBytes(widget.eventId);
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/obscura-event-${widget.eventId}.mp4');
    await file.writeAsBytes(bytes);
    return file;
  }

  Future<void> _download() async {
    final l = context.l;
    setState(() => _sharing = true);
    try {
      if (!await Gal.hasAccess() && !await Gal.requestAccess()) return;
      final file = await _clipFile();
      await Gal.putVideo(file.path, album: 'Obscura');
      await file.delete();
      if (mounted) showMessage(context, l.savedToGallery);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _share() async {
    setState(() => _sharing = true);
    try {
      final file = await _clipFile();
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'video/mp4')]));
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Future<void> _delete() async {
    final l = context.l;
    if (!await confirm(context, title: l.deleteEventTitle, body: l.deleteEventBody, action: l.delete)) return;
    if (!mounted) return;
    try {
      await context.hub.deleteEvent(widget.eventId);
      eventsVersion.value++;
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final ev = _event;
    final locale = Localizations.localeOf(context).toLanguageTag();
    return Scaffold(
      appBar: AppBar(
        title: Text(ev == null ? '' : kindLabel(context, ev.kind)),
        actions: [
          if (ev != null && _track != null)
            IconButton(
              tooltip: _overlay ? l.hideOverlay : l.showOverlay,
              isSelected: _overlay,
              icon: const Icon(Icons.layers_outlined),
              selectedIcon: const Icon(Icons.layers, color: Palette.accent),
              onPressed: () => setState(() => _overlay = !_overlay),
            ),
          if (ev != null) IconButton(tooltip: l.delete, icon: const Icon(Icons.delete_outline), onPressed: _delete),
        ],
      ),
      body: _error != null
          ? ErrorState(error: _error!, onRetry: _load)
          : ev == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: listPadding(context, EdgeInsets.zero), children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: ev.hasClip
                        ? Stack(fit: StackFit.expand, children: [
                            Video(controller: _video, fill: Colors.black),
                            if (_overlay && _track != null)
                              IgnorePointer(
                                child: StreamBuilder<Duration>(
                                  stream: _player.stream.position,
                                  builder: (_, snap) => CustomPaint(
                                    painter: _TrackPainter(
                                      _track!,
                                      (snap.data ?? Duration.zero).inMilliseconds / 1000,
                                      _player.state.width,
                                      _player.state.height,
                                    ),
                                  ),
                                ),
                              ),
                          ])
                        : Stack(fit: StackFit.expand, children: [
                            if (ev.hasThumb) AuthImage(context.hub.thumbUrl(ev.id), fit: BoxFit.contain),
                            Container(
                              color: Colors.black54,
                              alignment: Alignment.center,
                              child: Column(mainAxisSize: MainAxisSize.min, children: [
                                if (ev.endedAt == null || DateTime.now().difference(ev.endedAt!).inMinutes < 1) ...[
                                  const CircularProgressIndicator(),
                                  const SizedBox(height: 12),
                                  Text(l.clipProcessing),
                                ] else
                                  Text(l.clipUnavailable),
                              ]),
                            ),
                          ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      Panel(
                        child: Column(children: [
                          _InfoRow(icon: KindIcon.icon(ev.kind), color: KindIcon.color(ev.kind), label: l.type, value: kindLabel(context, ev.kind)),
                          _InfoRow(icon: Icons.videocam_outlined, label: l.camera, value: ev.camera),
                          _InfoRow(
                            icon: Icons.schedule,
                            label: l.time,
                            value: DateFormat.yMMMd(locale).add_Hms().format(ev.startedAt),
                          ),
                          if (ev.endedAt != null)
                            _InfoRow(
                              icon: Icons.timer_outlined,
                              label: l.duration,
                              value: l.seconds(ev.endedAt!.difference(ev.startedAt).inSeconds),
                            ),
                          if (ev.zones.isNotEmpty)
                            _InfoRow(icon: Icons.pentagon_outlined, label: l.zones, value: ev.zones.join(', ')),
                          _InfoRow(
                            icon: ev.uploaded ? Icons.cloud_done_outlined : Icons.cloud_off_outlined,
                            label: l.cloudCopy,
                            value: ev.uploaded ? l.uploaded : l.notUploaded,
                          ),
                        ]),
                      ),
                      const SizedBox(height: 16),
                      Row(children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: ev.hasClip && !_sharing ? _download : null,
                            icon: _sharing
                                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                                : const Icon(Icons.download),
                            label: Text(l.download),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.outlined(
                          tooltip: l.saveOrShare,
                          onPressed: ev.hasClip && !_sharing ? _share : null,
                          icon: const Icon(Icons.ios_share),
                        ),
                      ]),
                    ]),
                  ),
                ]),
    );
  }
}

/// Trigger zones, recent motion (fading dots) and detected people drawn over the playing clip.
class _TrackPainter extends CustomPainter {
  _TrackPainter(this.track, this.at, this.videoWidth, this.videoHeight);

  final EventTrack track;
  final double at; // playback position, seconds
  final int? videoWidth;
  final int? videoHeight;

  static const _trail = 1.5; // seconds of motion history shown
  static const _personHold = 1.2; // person checks run about once a second

  @override
  void paint(Canvas canvas, Size size) {
    // Same letterboxing as the video (BoxFit.contain).
    final aspect = (videoWidth ?? 0) > 0 && (videoHeight ?? 0) > 0 ? videoWidth! / videoHeight! : 16 / 9;
    final w = size.width / size.height > aspect ? size.height * aspect : size.width;
    final h = w / aspect;
    final r = Rect.fromLTWH((size.width - w) / 2, (size.height - h) / 2, w, h);
    Offset pt(double x, double y) => Offset(r.left + x * r.width, r.top + y * r.height);

    final zoneFill = Paint()..color = Palette.accent.withValues(alpha: 0.12);
    final zoneLine = Paint()
      ..color = Palette.accent.withValues(alpha: 0.8)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (final zone in track.zones) {
      if (zone.length < 3) continue;
      final path = Path()..addPolygon([for (final p in zone) pt(p.dx, p.dy)], true);
      canvas
        ..drawPath(path, zoneFill)
        ..drawPath(path, zoneLine);
    }

    final dot = Paint();
    final box = Paint()
      ..color = Palette.danger
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2;
    for (final m in track.marks) {
      final age = at - m.t;
      if (age < -0.1) break;
      if (m.person != null && age <= _personHold) {
        canvas.drawRect(Rect.fromPoints(pt(m.person!.left, m.person!.top), pt(m.person!.right, m.person!.bottom)), box);
      }
      if (age > _trail) continue;
      final fade = 1 - age.clamp(0, _trail) / _trail;
      dot.color = const Color(0xFFFFB020).withValues(alpha: 0.25 + 0.6 * fade);
      for (final s in m.spots) {
        canvas.drawCircle(pt(s.x, s.y), (s.r * r.width).clamp(3, 18) * (0.5 + 0.5 * fade), dot);
      }
    }
  }

  @override
  bool shouldRepaint(_TrackPainter old) => old.at != at || old.track != track;
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.label, required this.value, this.color});

  final IconData icon;
  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(children: [
        Icon(icon, size: 18, color: color ?? Palette.muted),
        const SizedBox(width: 12),
        Text(label, style: const TextStyle(color: Palette.muted)),
        const SizedBox(width: 12),
        Expanded(child: Text(value, textAlign: TextAlign.end, style: const TextStyle(fontFeatures: tabular))),
      ]),
    );
  }
}
