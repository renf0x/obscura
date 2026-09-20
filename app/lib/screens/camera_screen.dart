import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../api/models.dart';
import '../main.dart' show routeObserver;
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/voice_controls.dart';
import 'camera_edit_screen.dart';
import 'camera_settings_screen.dart';
import 'event_screen.dart';
import 'home_screen.dart';
import 'home_shell.dart';
import 'zone_editor_screen.dart';

class CameraScreen extends StatefulWidget {
  const CameraScreen({super.key, required this.cameraId});

  final int cameraId;

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with WidgetsBindingObserver, RouteAware {
  final _player = Player();
  late final _video = VideoController(_player);
  Camera? _camera;
  List<HubEvent> _events = const [];
  Object? _error;
  bool _muted = true;
  bool _hd = false;
  bool _recording = false;
  Timer? _recordEnd;
  bool _streamAudio = false; // the open stream carries sound
  Timer? _retry;
  StreamSubscription<bool>? _ended;
  // Another screen is on top: the stream is stopped so the phone doesn't decode video nobody sees.
  bool _covered = false;
  bool _stopped = false; // the player was stopped by this screen, so resuming has to reopen it
  bool _fullscreen = false;

  @override
  void initState() {
    super.initState();
    _player.setVolume(0);
    final native = _player.platform;
    if (native is NativePlayer) {
      // Live view: no buffering, show the newest frame as soon as it arrives.
      native.setProperty('cache', 'no');
      native.setProperty('demuxer-max-bytes', '2MiB');
    }
    eventsVersion.addListener(_loadEvents);
    WidgetsBinding.instance.addObserver(this);
    // A live stream only "completes" when the connection drops (hub restart, network switch): reconnect.
    _ended = _player.stream.completed.listen((done) {
      if (done) _scheduleReconnect();
    });
    _load();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // In the background Android drops the connection and the picture freezes; stop and reopen instead.
    if (state == AppLifecycleState.paused) {
      _retry?.cancel();
      _stopped = true;
      _player.stop();
    } else if (state == AppLifecycleState.resumed && _stopped && !_covered && _camera?.enabled == true) {
      // Only after a real stop. Pulling down the notification shade or dismissing a notification
      // leaves the stream running, and reopening it there blanked the picture for a second.
      _stopped = false;
      _play();
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route is PageRoute) routeObserver.subscribe(this, route);
  }

  @override
  void didPushNext() {
    if (_fullscreen) return; // fullscreen shows this same stream
    _covered = true;
    _retry?.cancel();
    _stopped = true;
    _player.stop();
  }

  @override
  void didPopNext() {
    if (_fullscreen) {
      _fullscreen = false;
      return;
    }
    _covered = false;
    if (_camera?.enabled == true) _play();
  }

  // Sound is muted by the volume alone. The stream is opened without an audio track unless the user
  // asked for sound, so there is nothing to decode anyway, and mpv's 'aid' property is left alone:
  // setting it to 'no' kept the player silent even after the track was back.
  void _setAudio(bool on) => _player.setVolume(on ? 100 : 0);

  void _scheduleReconnect() {
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 2), () {
      final state = WidgetsBinding.instance.lifecycleState;
      if (mounted && !_covered && _camera?.enabled == true && state == AppLifecycleState.resumed) _play();
    });
  }

  @override
  void dispose() {
    _retry?.cancel();
    _recordEnd?.cancel();
    _ended?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    routeObserver.unsubscribe(this);
    eventsVersion.removeListener(_loadEvents);
    _player.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cam = await context.hub.camera(widget.cameraId);
      if (!mounted) return;
      setState(() {
        _camera = cam;
        _error = null;
      });
      if (cam.enabled && !_covered) _play();
      _loadEvents();
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _loadEvents() async {
    try {
      final events = await context.hub.events(cameraId: widget.cameraId, limit: 20);
      if (mounted) setState(() => _events = events);
    } catch (_) {}
  }

  void _play() {
    _stopped = false;
    final hub = context.hub;
    _streamAudio = !_muted;
    _setAudio(_streamAudio);
    _player.open(Media(hub.liveUrl(widget.cameraId, hd: _hd, audio: _streamAudio).toString(), httpHeaders: hub.authHeaders));
  }

  Future<void> _capture() async {
    final l = context.l;
    try {
      final bytes = await context.hub.snapshot(widget.cameraId);
      final dir = await getApplicationDocumentsDirectory();
      final stamp = DateFormat('yyyyMMdd-HHmmss').format(DateTime.now());
      final file = File('${dir.path}/obscura-${widget.cameraId}-$stamp.jpg');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      showMessage(context, l.snapshotSaved);
      await SharePlus.instance.share(ShareParams(files: [XFile(file.path, mimeType: 'image/jpeg')]));
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _toggleRecord() async {
    final hub = context.hub;
    _recordEnd?.cancel();
    if (_recording) {
      setState(() => _recording = false);
      try {
        await hub.stopRecord(widget.cameraId);
      } catch (e) {
        if (mounted) showError(context, e);
      }
      return;
    }
    setState(() => _recording = true);
    try {
      await hub.record(widget.cameraId);
      if (mounted) showMessage(context, context.l.recordingStarted);
      _recordEnd = Timer(const Duration(seconds: 30), () {
        if (mounted) setState(() => _recording = false);
      });
    } catch (e) {
      if (mounted) {
        setState(() => _recording = false);
        showError(context, e);
      }
    }
  }

  Future<void> _deleteEvents() async {
    final l = context.l;
    if (!await confirm(context, title: l.deleteAllEvents, body: l.deleteCameraEventsBody, action: l.delete)) return;
    if (!mounted) return;
    try {
      await context.hub.deleteAllEvents(cameraId: widget.cameraId);
      eventsVersion.value++;
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _togglePrivacy() async {
    final cam = _camera!;
    final l = context.l;
    if (cam.enabled &&
        !await confirm(context, title: l.privacyEnable, body: l.privacyBody, action: l.privacyEnable, destructive: false)) {
      return;
    }
    if (!mounted) return;
    try {
      await context.hub.patchCamera(cam.id, enabled: !cam.enabled);
      if (!cam.enabled) {
        await Future<void>.delayed(const Duration(seconds: 2)); // let the hub reconnect first
      } else {
        await _player.stop();
      }
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _openScreen(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final cam = _camera;
    return Scaffold(
      appBar: AppBar(
        title: Column(children: [
          Text(cam?.name ?? '', style: const TextStyle(fontSize: 17)),
          if (cam != null)
            StatusDot(
              color: !cam.enabled ? Palette.muted : (cam.online ? Palette.accent : Palette.danger),
              label: !cam.enabled ? l.privacyOn : (cam.online ? l.live : l.offline),
            ),
        ]),
        actions: [
          IconButton(
            tooltip: l.connectionSettings,
            icon: const Icon(Icons.key_outlined),
            onPressed: cam == null ? null : () => _openScreen(CameraEditScreen(camera: cam)),
          ),
          IconButton(
            tooltip: l.triggers,
            icon: const Icon(Icons.tune),
            onPressed: cam == null ? null : () => _openScreen(CameraSettingsScreen(cameraId: cam.id)),
          ),
        ],
      ),
      body: _error != null
          ? ErrorState(error: _error!, onRetry: _load)
          : cam == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: listPadding(context, const EdgeInsets.only(bottom: 24)), children: [
                  AspectRatio(
                    aspectRatio: 16 / 9,
                    child: cam.enabled ? _liveView(cam) : _privacyView(),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 16),
                    child: Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
                      _RoundAction(
                        icon: _muted ? Icons.volume_off_outlined : Icons.volume_up_outlined,
                        label: _muted ? l.unmute : l.mute,
                        onTap: cam.enabled
                            ? () {
                                setState(() => _muted = !_muted);
                                // The stream is opened without sound to save data; reopen it once sound is wanted.
                                if (!_muted && !_streamAudio) {
                                  _play();
                                } else {
                                  _setAudio(!_muted);
                                }
                              }
                            : null,
                      ),
                      _RoundAction(
                        icon: _hd ? Icons.hd : Icons.sd_outlined,
                        label: _hd ? 'HD' : 'SD',
                        onTap: cam.enabled
                            ? () {
                                setState(() => _hd = !_hd);
                                _play();
                              }
                            : null,
                      ),
                      _RoundAction(icon: Icons.photo_camera_outlined, label: l.capture, onTap: cam.enabled ? _capture : null),
                      _RoundAction(
                        icon: _recording ? Icons.stop : Icons.fiber_manual_record,
                        label: _recording ? l.stopRecording : l.record,
                        color: Palette.danger,
                        active: _recording,
                        onTap: cam.enabled ? _toggleRecord : null,
                      ),
                    ]),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      if (cam.enabled) ...[
                        SectionLabel(l.voiceAndSiren),
                        VoiceControls(
                          camera: cam,
                          onSetup: () => _openScreen(CameraEditScreen(camera: cam)),
                          // Mute the live sound while the mic is open, so the recording has no echo.
                          onRecording: (on) => _setAudio(!on && !_muted),
                        ),
                      ],
                      SectionLabel(l.quickActions),
                      Row(children: [
                        Expanded(
                          child: _QuickAction(
                            icon: cam.enabled ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            label: cam.enabled ? l.privacyMode : l.privacyDisable,
                            onTap: _togglePrivacy,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.pentagon_outlined,
                            label: l.triggerZones,
                            onTap: () => _openScreen(ZoneEditorScreen(cameraId: cam.id)),
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: _QuickAction(
                            icon: Icons.notifications_active_outlined,
                            label: l.triggers,
                            onTap: () => _openScreen(CameraSettingsScreen(cameraId: cam.id)),
                          ),
                        ),
                      ]),
                      SectionLabel(
                        l.timeline,
                        trailing: _events.isEmpty
                            ? null
                            : TextButton.icon(
                                onPressed: _deleteEvents,
                                icon: const Icon(Icons.delete_sweep_outlined, size: 18),
                                label: Text(l.delete),
                                style: TextButton.styleFrom(foregroundColor: Palette.danger, visualDensity: VisualDensity.compact),
                              ),
                      ),
                      if (_events.isEmpty)
                        Panel(child: Text(l.noEventsYet, style: const TextStyle(color: Palette.muted)))
                      else ...[
                        SizedBox(
                          height: 86,
                          child: ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _events.length,
                            separatorBuilder: (_, _) => const SizedBox(width: 8),
                            itemBuilder: (_, i) => _TimelineThumb(event: _events[i]),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Panel(
                          padding: EdgeInsets.zero,
                          child: Column(children: [
                            for (final (i, e) in _events.take(5).indexed) ...[
                              if (i > 0) const Divider(),
                              EventTile(event: e, showCamera: false),
                            ],
                          ]),
                        ),
                      ],
                    ]),
                  ),
                ]),
    );
  }

  Widget _liveView(Camera cam) {
    final l = context.l;
    return Stack(fit: StackFit.expand, children: [
      ColoredBox(
        color: Colors.black,
        child: Video(controller: _video, controls: NoVideoControls, fill: Colors.black),
      ),
      Positioned(
        left: 12,
        top: 10,
        child: StreamBuilder<bool>(
          stream: _player.stream.playing,
          builder: (_, snap) => StatusDot(
            color: snap.data == true ? Palette.danger : Palette.muted,
            label: snap.data == true ? 'LIVE' : l.connecting,
          ),
        ),
      ),
      Positioned(
        right: 12,
        top: 10,
        child: const _LiveClock(),
      ),
      Positioned(
        left: 12,
        bottom: 10,
        child: Text('CAM ${cam.id.toString().padLeft(2, '0')}\n${cam.name.toUpperCase()}',
            style: const TextStyle(fontSize: 10, letterSpacing: 1.6, shadows: [Shadow(blurRadius: 4)])),
      ),
      Positioned(
        right: 4,
        bottom: 0,
        child: IconButton(
          tooltip: l.fullscreen,
          icon: const Icon(Icons.fullscreen),
          onPressed: () {
            _fullscreen = true;
            Navigator.push(context, MaterialPageRoute(builder: (_) => _FullscreenView(controller: _video)));
          },
        ),
      ),
    ]);
  }

  Widget _privacyView() {
    return ColoredBox(
      color: Palette.surfaceHigh,
      child: Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.visibility_off_outlined, size: 40, color: Palette.muted),
          const SizedBox(height: 8),
          Text(context.l.privacyOn, style: const TextStyle(color: Palette.muted)),
        ]),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  const _RoundAction({required this.icon, required this.label, this.onTap, this.color, this.active = false});

  final IconData icon;
  final String label;
  final VoidCallback? onTap;
  final Color? color;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null || active;
    final fg = color ?? Palette.text;
    return Semantics(
      button: true,
      enabled: onTap != null,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: onTap,
        customBorder: const CircleBorder(),
        child: Opacity(
          opacity: enabled ? 1 : 0.4,
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: active ? fg.withValues(alpha: 0.2) : Palette.surfaceHigh,
                border: Border.all(color: active ? fg : Palette.border),
              ),
              child: Icon(icon, color: fg),
            ),
            const SizedBox(height: 6),
            Text(label, style: const TextStyle(fontSize: 12, color: Palette.muted)),
          ]),
        ),
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.label, required this.onTap});

  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      child: Column(children: [
        Icon(icon, color: Palette.accent),
        const SizedBox(height: 6),
        Text(label, textAlign: TextAlign.center, maxLines: 2, style: const TextStyle(fontSize: 12)),
      ]),
    );
  }
}

class _TimelineThumb extends StatelessWidget {
  const _TimelineThumb({required this.event});

  final HubEvent event;

  @override
  Widget build(BuildContext context) {
    final label = '${kindLabel(context, event.kind)}, ${formatTime(context, event.startedAt)}';
    return Semantics(
      button: true,
      label: label,
      excludeSemantics: true,
      child: InkWell(
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventScreen(eventId: event.id))),
        child: Column(children: [
          Container(
            width: 104,
            height: 60,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: KindIcon.color(event.kind).withValues(alpha: 0.7)),
            ),
            clipBehavior: Clip.antiAlias,
            child: event.hasThumb ? AuthImage(context.hub.thumbUrl(event.id)) : const ColoredBox(color: Palette.surfaceHigh),
          ),
          const SizedBox(height: 4),
          Text(DateFormat.Hm().format(event.startedAt),
              style: const TextStyle(fontSize: 11, color: Palette.muted, fontFeatures: tabular)),
        ]),
      ),
    );
  }
}

/// Ticks on its own, so only this text redraws every second, not the whole camera screen.
class _LiveClock extends StatefulWidget {
  const _LiveClock();

  @override
  State<_LiveClock> createState() => _LiveClockState();
}

class _LiveClockState extends State<_LiveClock> with WidgetsBindingObserver {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _start();
  }

  void _start() => _timer ??= Timer.periodic(const Duration(seconds: 1), (_) => setState(() {}));

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // No wakeups every second while the app is in the background.
    if (state == AppLifecycleState.resumed) {
      setState(_start);
    } else if (state == AppLifecycleState.paused) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(DateFormat('yyyy-MM-dd  HH:mm:ss').format(DateTime.now()),
        style: const TextStyle(fontSize: 12, fontFeatures: tabular, shadows: [Shadow(blurRadius: 4)]));
  }
}

class _FullscreenView extends StatelessWidget {
  const _FullscreenView({required this.controller});

  final VideoController controller;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(children: [
        Positioned.fill(child: Video(controller: controller, controls: NoVideoControls)),
        SafeArea(
          child: IconButton(
            tooltip: context.l.close,
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.pop(context),
          ),
        ),
      ]),
    );
  }
}
