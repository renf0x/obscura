import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

import '../api/models.dart';
import '../theme.dart';
import 'common.dart';

enum _Talk { idle, starting, recording, sending }

/// Push-to-talk and siren for one camera. The hub plays the recording through the camera speaker
/// and switches the siren off by itself after the configured time.
class VoiceControls extends StatefulWidget {
  const VoiceControls({super.key, required this.camera, required this.onSetup, this.onRecording});

  final Camera camera;
  final VoidCallback onSetup;

  /// Lets the live view mute itself while the microphone is open (no echo of the camera audio).
  final ValueChanged<bool>? onRecording;

  @override
  State<VoiceControls> createState() => _VoiceControlsState();
}

class _VoiceControlsState extends State<VoiceControls> {
  static const _maxTalk = Duration(seconds: 30);
  final _recorder = AudioRecorder();
  var _talk = _Talk.idle;
  bool _releasedEarly = false;
  DateTime? _talkStart;
  DateTime? _sirenUntil;
  bool _sirenBusy = false;
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    _recorder.dispose();
    super.dispose();
  }

  void _ticker() {
    _tick?.cancel();
    _tick = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (!mounted) return;
      final until = _sirenUntil;
      if (until != null && DateTime.now().isAfter(until)) _sirenUntil = null;
      if (_talk == _Talk.recording && DateTime.now().difference(_talkStart!) >= _maxTalk) _stopTalk();
      if (_sirenUntil == null && _talk != _Talk.recording) _tick?.cancel();
      setState(() {});
    });
  }

  // --- push-to-talk ---------------------------------------------------------
  Future<void> _startTalk() async {
    if (_talk != _Talk.idle) return;
    final l = context.l;
    setState(() {
      _talk = _Talk.starting;
      _releasedEarly = false;
    });
    try {
      if (!await _recorder.hasPermission()) {
        if (mounted) showMessage(context, l.micDenied);
        setState(() => _talk = _Talk.idle);
        return;
      }
      final dir = await getTemporaryDirectory();
      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc, sampleRate: 16000, numChannels: 1, bitRate: 48000),
        path: '${dir.path}/obscura-talk.m4a',
      );
    } catch (e) {
      if (mounted) {
        setState(() => _talk = _Talk.idle);
        showError(context, e);
      }
      return;
    }
    widget.onRecording?.call(true);
    _talkStart = DateTime.now();
    setState(() => _talk = _Talk.recording);
    _ticker();
    if (_releasedEarly) _stopTalk(); // finger lifted while the permission dialog / recorder was starting
  }

  Future<void> _stopTalk() async {
    if (_talk == _Talk.starting) {
      _releasedEarly = true;
      return;
    }
    if (_talk != _Talk.recording) return;
    final l = context.l;
    final hub = context.hub;
    final held = DateTime.now().difference(_talkStart!);
    setState(() => _talk = _Talk.sending);
    widget.onRecording?.call(false);
    File? file;
    try {
      final path = await _recorder.stop();
      if (path == null) return;
      file = File(path);
      if (held < const Duration(milliseconds: 700)) {
        if (mounted) showMessage(context, l.talkTooShort);
        return;
      }
      await hub.talk(widget.camera.id, await file.readAsBytes());
      if (mounted) showMessage(context, l.talkSent);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      unawaited(file?.delete().then((_) {}, onError: (_) {}));
      if (mounted) setState(() => _talk = _Talk.idle);
    }
  }

  // --- siren ------------------------------------------------------------------
  Future<void> _toggleSiren() async {
    final l = context.l;
    final hub = context.hub;
    final on = _sirenUntil == null;
    if (on && !await confirm(context, title: l.sirenConfirmTitle, body: l.sirenConfirmBody, action: l.sirenTurnOn)) {
      return;
    }
    setState(() => _sirenBusy = true);
    try {
      final seconds = await hub.siren(widget.camera.id, on, seconds: widget.camera.config.sirenSeconds);
      if (!mounted) return;
      setState(() => _sirenUntil = on ? DateTime.now().add(Duration(seconds: seconds)) : null);
      showMessage(context, on ? l.sirenOn(seconds) : l.sirenOff);
      if (on) _ticker();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _sirenBusy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final cam = widget.camera;
    if (!cam.canTalk && cam.siren == null) {
      return Panel(
        child: Row(
          children: [
            const Icon(Icons.record_voice_over_outlined, color: Palette.muted),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(l.talkSetupTitle),
                  const SizedBox(height: 2),
                  Text(
                    cam.vendor == 'tapo' ? l.talkSetupTapo : l.talkSetupOther,
                    style: const TextStyle(color: Palette.muted, fontSize: 12),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: widget.onSetup, child: Text(l.setUp)),
          ],
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            if (cam.canTalk) Expanded(flex: 3, child: _talkButton(context)),
            if (cam.canTalk && cam.siren != null) const SizedBox(width: 10),
            if (cam.siren != null) Expanded(flex: 2, child: _sirenButton(context)),
          ],
        ),
        if (cam.controlError != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              Expanded(
                child: Text(
                  l.controlFailed(cam.controlError!),
                  style: const TextStyle(color: Palette.danger, fontSize: 12),
                ),
              ),
              TextButton(onPressed: widget.onSetup, child: Text(l.change)),
            ]),
          ),
      ],
    );
  }

  Widget _talkButton(BuildContext context) {
    final l = context.l;
    final recording = _talk == _Talk.recording;
    final elapsed = recording ? DateTime.now().difference(_talkStart!).inSeconds : 0;
    final label = switch (_talk) {
      _Talk.recording => '${l.talking}  0:${elapsed.toString().padLeft(2, '0')}',
      _Talk.sending => l.talkSending,
      _ => l.holdToTalk,
    };
    return Semantics(
      button: true,
      label: l.holdToTalk,
      child: Listener(
        onPointerDown: (_) => _startTalk(),
        onPointerUp: (_) => _stopTalk(),
        onPointerCancel: (_) => _stopTalk(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          constraints: const BoxConstraints(minHeight: 76),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          decoration: BoxDecoration(
            color: recording ? Palette.accent.withValues(alpha: 0.16) : Palette.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: recording ? Palette.accent : Palette.border),
          ),
          child: Row(
            children: [
              _talk == _Talk.sending
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                  : Icon(recording ? Icons.mic : Icons.mic_none, color: Palette.accent, size: 28),
              const SizedBox(width: 10),
              Expanded(child: Text(label, style: const TextStyle(fontSize: 13), maxLines: 2)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sirenButton(BuildContext context) {
    final l = context.l;
    final until = _sirenUntil;
    final left = until == null ? 0 : until.difference(DateTime.now()).inSeconds + 1;
    return Panel(
      onTap: _sirenBusy ? null : _toggleSiren,
      highlight: until != null ? Palette.danger : null,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 52),
        child: Row(
          children: [
            _sirenBusy
                ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2))
                : Icon(
                    until != null ? Icons.notifications_off_outlined : Icons.campaign_outlined,
                    color: Palette.danger,
                    size: 28,
                  ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                until != null ? '${l.sirenStop}  ${left}s' : l.siren,
                style: const TextStyle(fontSize: 13),
                maxLines: 2,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
