import 'package:flutter/material.dart';

import '../api/models.dart';
import '../services/notifications.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'zone_editor_screen.dart';

/// Triggers, notifications and schedule for one camera ("Notifications & Triggers" in the mockup).
class CameraSettingsScreen extends StatefulWidget {
  const CameraSettingsScreen({super.key, required this.cameraId});

  final int cameraId;

  @override
  State<CameraSettingsScreen> createState() => _CameraSettingsScreenState();
}

class _CameraSettingsScreenState extends State<CameraSettingsScreen> {
  Camera? _camera;
  CameraConfig? _cfg;
  bool? _personAvailable;
  bool _dirty = false;
  bool _saving = false;
  Object? _error;

  static const _levels = ['low', 'medium', 'high'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final hub = context.hub;
      final results = await Future.wait([hub.camera(widget.cameraId), hub.overview()]);
      final cam = results[0] as Camera;
      if (!mounted) return;
      setState(() {
        _camera = cam;
        _cfg = cam.config;
        _personAvailable = (results[1] as Overview).personDetection;
        _dirty = false;
        _error = null;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  void _edit(VoidCallback change) => setState(() {
        change();
        _dirty = true;
      });

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await context.hub.patchCamera(widget.cameraId, config: _cfg);
      if (!mounted) return;
      setState(() => _dirty = false);
      showMessage(context, context.l.saved);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _pickTime(bool start) async {
    final s = _cfg!.schedule;
    final parts = (start ? s.start : s.end).split(':');
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1])),
    );
    if (picked == null) return;
    final v = '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    _edit(() => start ? s.start = v : s.end = v);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final cfg = _cfg;
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirm(context, title: l.unsavedTitle, body: l.unsavedBody, action: l.discard) && context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: DefaultTabController(
        length: 3,
        child: Scaffold(
          appBar: AppBar(
            title: Column(children: [
              Text(l.notificationsTriggers, style: const TextStyle(fontSize: 17)),
              if (_camera != null) Text(_camera!.name, style: const TextStyle(fontSize: 12, color: Palette.muted)),
            ]),
            bottom: TabBar(
              indicatorColor: Palette.accent,
              labelColor: Palette.accent,
              unselectedLabelColor: Palette.muted,
              tabs: [Tab(text: l.triggers), Tab(text: l.tabNotifications), Tab(text: l.schedule)],
            ),
          ),
          bottomNavigationBar: cfg == null
              ? null
              : SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                    child: FilledButton(
                      onPressed: _dirty && !_saving ? _save : null,
                      child: _saving
                          ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                          : Text(_dirty ? l.saveChanges : l.saved),
                    ),
                  ),
                ),
          body: _error != null
              ? ErrorState(error: _error!, onRetry: _load)
              : cfg == null
                  ? const Center(child: CircularProgressIndicator())
                  : TabBarView(children: [_triggers(cfg), _notifications(cfg), _schedule(cfg)]),
        ),
      ),
    );
  }

  Widget _switchRow({
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool>? onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle, style: const TextStyle(color: Palette.muted, fontSize: 12)),
      value: value,
      onChanged: onChanged,
    );
  }

  static const _sirenChoices = [10, 30, 60, 120];

  Widget _sirenPanel(CameraConfig cfg) {
    final l = context.l;
    final available = _camera?.siren != null;
    return Panel(
      padding: EdgeInsets.zero,
      child: Column(children: [
        _switchRow(
          icon: Icons.campaign_outlined,
          title: l.sirenOnPerson,
          subtitle: available ? l.sirenOnPersonHint : l.sirenUnavailable,
          value: cfg.sirenOnPerson && available,
          onChanged: available ? (v) => _edit(() => cfg.sirenOnPerson = v) : null,
        ),
        if (available) ...[
          const Divider(),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
            child: Row(children: [
              Expanded(child: Text(l.sirenDuration)),
              DropdownButton<int>(
                value: _sirenChoices.contains(cfg.sirenSeconds) ? cfg.sirenSeconds : 30,
                underline: const SizedBox.shrink(),
                items: [
                  for (final s in _sirenChoices) DropdownMenuItem(value: s, child: Text(l.seconds(s))),
                ],
                onChanged: (v) => _edit(() => cfg.sirenSeconds = v ?? 30),
              ),
            ]),
          ),
        ],
      ]),
    );
  }

  Widget _triggers(CameraConfig cfg) {
    final l = context.l;
    final level = _levels.indexOf(cfg.sensitivity).clamp(0, 2);
    return ListView(padding: const EdgeInsets.all(16), children: [
      Panel(
        padding: EdgeInsets.zero,
        child: Column(children: [
          _switchRow(
            icon: Icons.motion_photos_on_outlined,
            title: l.motionDetection,
            subtitle: l.motionDetectionHint,
            value: cfg.motion,
            onChanged: (v) => _edit(() => cfg.motion = v),
          ),
          const Divider(),
          _switchRow(
            icon: Icons.directions_walk,
            title: l.personDetection,
            subtitle: _personAvailable == false ? l.personModelMissing : l.personDetectionHint,
            value: cfg.person && _personAvailable != false,
            onChanged: _personAvailable == false ? null : (v) => _edit(() => cfg.person = v),
          ),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(child: Text(l.alertSensitivity, style: const TextStyle(fontWeight: FontWeight.w500))),
            Text([l.sensLow, l.sensMedium, l.sensHigh][level], style: const TextStyle(color: Palette.accent)),
          ]),
          Slider(
            value: level.toDouble(),
            min: 0,
            max: 2,
            divisions: 2,
            label: [l.sensLow, l.sensMedium, l.sensHigh][level],
            semanticFormatterCallback: (v) => [l.sensLow, l.sensMedium, l.sensHigh][v.round()],
            onChanged: (v) => _edit(() => cfg.sensitivity = _levels[v.round()]),
          ),
          Text(l.sensitivityHint, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        ]),
      ),
      const SizedBox(height: 12),
      Panel(
        padding: EdgeInsets.zero,
        child: _switchRow(
          icon: Icons.compress,
          title: l.recordLow,
          subtitle: l.recordLowHint,
          value: cfg.recordQuality == 'low',
          onChanged: (v) => _edit(() => cfg.recordQuality = v ? 'low' : 'high'),
        ),
      ),
      const SizedBox(height: 12),
      _sirenPanel(cfg),
      const SizedBox(height: 12),
      Panel(
        onTap: () async {
          if (_dirty) await _save();
          if (!mounted) return;
          await Navigator.push(context, MaterialPageRoute(builder: (_) => ZoneEditorScreen(cameraId: widget.cameraId)));
          _load();
        },
        child: Row(children: [
          const Icon(Icons.pentagon_outlined, color: Palette.accent),
          const SizedBox(width: 14),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(l.triggerZones, style: const TextStyle(fontWeight: FontWeight.w500)),
              const SizedBox(height: 2),
              Text(
                cfg.zones.isEmpty ? l.zonesNone : l.zonesCount(cfg.zones.length),
                style: const TextStyle(color: Palette.muted, fontSize: 12),
              ),
            ]),
          ),
          Text(l.editZones, style: const TextStyle(color: Palette.accent)),
          const Icon(Icons.chevron_right, color: Palette.muted),
        ]),
      ),
    ]);
  }

  Widget _notifications(CameraConfig cfg) {
    final l = context.l;
    return ListView(padding: const EdgeInsets.all(16), children: [
      Panel(
        padding: EdgeInsets.zero,
        child: Column(children: [
          _switchRow(
            icon: Icons.directions_walk,
            title: l.notifyPerson,
            subtitle: l.notifyPersonHint,
            value: cfg.notifyPerson,
            onChanged: (v) => _edit(() => cfg.notifyPerson = v),
          ),
          const Divider(),
          _switchRow(
            icon: Icons.motion_photos_on_outlined,
            title: l.notifyMotion,
            subtitle: l.notifyMotionHint,
            value: cfg.notifyMotion,
            onChanged: (v) => _edit(() => cfg.notifyMotion = v),
          ),
        ]),
      ),
      SectionLabel(l.soundPreview),
      Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text(l.soundPreviewHint, style: const TextStyle(color: Palette.muted, fontSize: 13)),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: Palette.danger, side: const BorderSide(color: Palette.danger)),
                onPressed: () => _preview('person'),
                icon: const Icon(Icons.directions_walk),
                label: Text(l.kindPerson),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: () => _preview('motion'),
                icon: const Icon(Icons.motion_photos_on_outlined),
                label: Text(l.kindMotion),
              ),
            ),
          ]),
        ]),
      ),
    ]);
  }

  Future<void> _preview(String kind) async {
    final label = context.l.soundTest;
    await Notifications.requestPermission();
    await Notifications.showEvent(eventId: -1, kind: kind, camera: label);
  }

  Widget _schedule(CameraConfig cfg) {
    final l = context.l;
    final s = cfg.schedule;
    final days = [l.dayMon, l.dayTue, l.dayWed, l.dayThu, l.dayFri, l.daySat, l.daySun];
    return ListView(padding: const EdgeInsets.all(16), children: [
      Panel(
        padding: EdgeInsets.zero,
        child: RadioGroup<String>(
          groupValue: s.mode,
          onChanged: (v) => _edit(() => s.mode = v!),
          child: Column(children: [
            RadioListTile(value: 'always', title: Text(l.alwaysOn), subtitle: Text(l.alwaysOnHint)),
            const Divider(),
            RadioListTile(value: 'window', title: Text(l.onSchedule), subtitle: Text(l.onScheduleHint)),
          ]),
        ),
      ),
      if (s.mode == 'window') ...[
        const SizedBox(height: 12),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(true),
                  child: Text('${l.from} ${s.start}', style: const TextStyle(fontFeatures: tabular)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _pickTime(false),
                  child: Text('${l.to} ${s.end}', style: const TextStyle(fontFeatures: tabular)),
                ),
              ),
            ]),
            const SizedBox(height: 12),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (var d = 0; d < 7; d++)
                FilterChip(
                  label: Text(days[d]),
                  selected: s.days.contains(d),
                  onSelected: (on) => _edit(() {
                    on ? s.days.add(d) : s.days.remove(d);
                    s.days.sort();
                  }),
                ),
            ]),
          ]),
        ),
      ],
    ]);
  }
}
