import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'camera_screen.dart';
import 'event_screen.dart';
import 'home_shell.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key, required this.onOpenTab});

  final ValueChanged<int> onOpenTab;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<(Overview, List<Camera>, List<HubEvent>)> _data;

  @override
  void initState() {
    super.initState();
    _data = _load();
    eventsVersion.addListener(_refresh);
  }

  @override
  void dispose() {
    eventsVersion.removeListener(_refresh);
    super.dispose();
  }

  Future<(Overview, List<Camera>, List<HubEvent>)> _load() async {
    final hub = context.hub;
    final results = await Future.wait([hub.overview(), hub.cameras(), hub.events(limit: 5)]);
    return (results[0] as Overview, results[1] as List<Camera>, results[2] as List<HubEvent>);
  }

  void _refresh() => setState(() => _data = _load());

  String _greeting() {
    final h = DateTime.now().hour;
    final l = context.l;
    return h < 5 ? l.goodNight : (h < 12 ? l.goodMorning : (h < 18 ? l.goodAfternoon : l.goodEvening));
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return GridBackdrop(
      child: SafeArea(
        child: FutureBuilder(
          future: _data,
          builder: (context, snap) {
            if (snap.hasError) return ErrorState(error: snap.error!, onRetry: _refresh);
            if (!snap.hasData) return Center(child: Semantics(label: l.loading, child: const CircularProgressIndicator()));
            final (o, cams, events) = snap.data!;
            final secure = o.offline == 0 && o.cameras > 0;
            return RefreshIndicator(
              onRefresh: () async => _refresh(),
              child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
                Row(children: [
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(_greeting().toUpperCase(),
                          style: const TextStyle(fontSize: 11, letterSpacing: 2.2, color: Palette.muted)),
                      const SizedBox(height: 6),
                      Text(
                        o.cameras == 0 ? l.noCamerasYet : (secure ? l.allSecure : l.attentionNeeded),
                        style: Theme.of(context).textTheme.headlineMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(l.camerasOnline(o.online, o.cameras), style: const TextStyle(color: Palette.muted)),
                    ]),
                  ),
                  _ShieldBadge(ok: secure),
                ]),
                const SizedBox(height: 20),
                Row(children: [
                  Expanded(child: _Stat(value: o.cameras, label: l.statTotal, color: Palette.text)),
                  const SizedBox(width: 10),
                  Expanded(child: _Stat(value: o.online, label: l.statOnline, color: Palette.accent)),
                  const SizedBox(width: 10),
                  Expanded(
                      child: _Stat(value: o.offline, label: l.statOffline, color: o.offline > 0 ? Palette.danger : Palette.muted)),
                ]),
                const SizedBox(height: 10),
                Row(children: [
                  Expanded(
                    child: _Stat(
                      value: o.alerts24h,
                      label: l.statAlerts24h,
                      color: o.alerts24h > 0 ? Palette.warning : Palette.muted,
                      onTap: () => widget.onOpenTab(2),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: _Stat(
                      value: o.people24h,
                      label: l.statPeople24h,
                      color: o.people24h > 0 ? Palette.danger : Palette.muted,
                      onTap: () => widget.onOpenTab(2),
                    ),
                  ),
                ]),
                if (!o.personDetection) ...[
                  const SizedBox(height: 10),
                  Panel(
                    highlight: Palette.warning.withValues(alpha: 0.5),
                    child: Row(children: [
                      const Icon(Icons.warning_amber, color: Palette.warning),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.personModelMissing, style: const TextStyle(fontSize: 13))),
                    ]),
                  ),
                ],
                SectionLabel(l.liveOverview,
                    trailing: TextButton(onPressed: () => widget.onOpenTab(1), child: Text(l.allCameras))),
                if (cams.isEmpty)
                  Panel(
                    onTap: () => widget.onOpenTab(1),
                    child: Row(children: [
                      const Icon(Icons.add_a_photo_outlined, color: Palette.accent),
                      const SizedBox(width: 12),
                      Expanded(child: Text(l.addFirstCamera)),
                      const Icon(Icons.chevron_right, color: Palette.muted),
                    ]),
                  )
                else
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 10,
                    crossAxisSpacing: 10,
                    childAspectRatio: 16 / 11,
                    children: [for (final c in cams.take(4)) _CameraTile(camera: c)],
                  ),
                SectionLabel(l.recentAlerts,
                    trailing: TextButton(onPressed: () => widget.onOpenTab(2), child: Text(l.seeAll))),
                if (events.isEmpty)
                  Panel(child: Text(l.noEventsYet, style: const TextStyle(color: Palette.muted)))
                else
                  Panel(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      for (final (i, e) in events.indexed) ...[
                        if (i > 0) const Divider(),
                        EventTile(event: e),
                      ],
                    ]),
                  ),
              ]),
            );
          },
        ),
      ),
    );
  }
}

class _ShieldBadge extends StatelessWidget {
  const _ShieldBadge({required this.ok});

  final bool ok;

  @override
  Widget build(BuildContext context) {
    final color = ok ? Palette.accent : Palette.warning;
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: color.withValues(alpha: 0.8), width: 1.5),
        boxShadow: [BoxShadow(color: color.withValues(alpha: 0.25), blurRadius: 20)],
      ),
      child: Icon(ok ? Icons.shield_outlined : Icons.gpp_maybe_outlined, color: color, size: 28),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label, required this.color, this.onTap});

  final int value;
  final String label;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Panel(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Semantics(
        label: '$label: $value',
        excludeSemantics: true,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('$value',
              style: TextStyle(fontSize: 26, color: color, fontWeight: FontWeight.w400, fontFeatures: tabular)),
          const SizedBox(height: 2),
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 12, color: Palette.muted)),
        ]),
      ),
    );
  }
}

class _CameraTile extends StatelessWidget {
  const _CameraTile({required this.camera});

  final Camera camera;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Semantics(
      button: true,
      label: '${camera.name}, ${camera.online ? l.online : l.offline}',
      child: Panel(
        padding: EdgeInsets.zero,
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => CameraScreen(cameraId: camera.id))),
        child: Stack(fit: StackFit.expand, children: [
          if (camera.enabled && camera.online)
            AuthImage(context.hub.url('/api/cameras/${camera.id}/snapshot'))
          else
            ColoredBox(
              color: Palette.surfaceHigh,
              child: Icon(camera.enabled ? Icons.videocam_off_outlined : Icons.visibility_off_outlined, color: Palette.muted),
            ),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Colors.transparent, Color(0xCC000000)],
                stops: [0.5, 1],
              ),
            ),
          ),
          Positioned(
            left: 10,
            right: 10,
            bottom: 8,
            child: Row(children: [
              Expanded(
                child: Text(camera.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13)),
              ),
              StatusDot(
                color: !camera.enabled ? Palette.muted : (camera.online ? Palette.accent : Palette.danger),
                label: '',
              ),
            ]),
          ),
        ]),
      ),
    );
  }
}

/// One alert row, shared by the home screen, the events list and the camera timeline.
class EventTile extends StatelessWidget {
  const EventTile({super.key, required this.event, this.showCamera = true});

  final HubEvent event;
  final bool showCamera;

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EventScreen(eventId: event.id))),
      leading: ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox(
          width: 64,
          height: 44,
          child: event.hasThumb
              ? AuthImage(context.hub.thumbUrl(event.id))
              : const ColoredBox(color: Palette.surfaceHigh),
        ),
      ),
      title: Row(children: [
        KindIcon(event.kind, size: 16),
        const SizedBox(width: 6),
        Flexible(child: Text(kindLabel(context, event.kind), overflow: TextOverflow.ellipsis)),
      ]),
      subtitle: showCamera
          ? Text(event.camera, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.muted))
          : (event.zones.isEmpty ? null : Text(event.zones.join(', '), style: const TextStyle(color: Palette.muted))),
      trailing: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.end, children: [
        Text(formatTime(context, event.startedAt),
            style: const TextStyle(fontSize: 12, color: Palette.muted, fontFeatures: tabular)),
        if (event.uploaded) ...[
          const SizedBox(height: 4),
          Icon(Icons.cloud_done_outlined, size: 14, color: Palette.accentDim, semanticLabel: context.l.uploaded),
        ],
      ]),
    );
  }
}
