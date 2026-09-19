import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'camera_edit_screen.dart';
import 'camera_screen.dart';
import 'camera_settings_screen.dart';
import 'zone_editor_screen.dart';

class CamerasScreen extends StatefulWidget {
  const CamerasScreen({super.key});

  @override
  State<CamerasScreen> createState() => _CamerasScreenState();
}

enum _Filter { all, online, offline }

class _CamerasScreenState extends State<CamerasScreen> {
  late Future<List<Camera>> _cameras;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _cameras = context.hub.cameras();
  }

  void _refresh() => setState(() => _cameras = context.hub.cameras());

  Future<void> _open(Widget screen) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => screen));
    if (mounted) _refresh();
  }

  Future<void> _togglePrivacy(Camera c) async {
    try {
      await context.hub.patchCamera(c.id, enabled: !c.enabled);
      _refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _delete(Camera c) async {
    final l = context.l;
    if (!await confirm(context, title: l.deleteCameraTitle(c.name), body: l.deleteCameraBody, action: l.delete)) return;
    try {
      if (!mounted) return;
      await context.hub.deleteCamera(c.id);
      _refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return SafeArea(
      child: FutureBuilder(
        future: _cameras,
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error!, onRetry: _refresh);
          final all = snap.data;
          final online = all?.where((c) => c.online).length ?? 0;
          final shown = switch (_filter) {
            _Filter.all => all,
            _Filter.online => all?.where((c) => c.online).toList(),
            _Filter.offline => all?.where((c) => !c.online).toList(),
          };
          return RefreshIndicator(
            onRefresh: () async => _refresh(),
            child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(l.tabCameras, style: Theme.of(context).textTheme.headlineMedium),
                    const SizedBox(height: 4),
                    Text(l.camerasSubtitle, style: const TextStyle(color: Palette.muted)),
                  ]),
                ),
                OutlinedButton.icon(
                  onPressed: () => _open(const CameraEditScreen()),
                  icon: const Icon(Icons.add),
                  label: Text(l.addCamera),
                ),
              ]),
              const SizedBox(height: 16),
              if (all != null)
                Wrap(spacing: 8, children: [
                  for (final (f, label) in [
                    (_Filter.all, l.filterAll(all.length)),
                    (_Filter.online, l.filterOnline(online)),
                    (_Filter.offline, l.filterOffline(all.length - online)),
                  ])
                    ChoiceChip(
                      label: Text(label, style: const TextStyle(fontFeatures: tabular)),
                      selected: _filter == f,
                      onSelected: (_) => setState(() => _filter = f),
                    ),
                ]),
              const SizedBox(height: 8),
              if (shown == null)
                const Padding(padding: EdgeInsets.all(48), child: Center(child: CircularProgressIndicator()))
              else if (all!.isEmpty)
                EmptyState(
                  icon: Icons.videocam_outlined,
                  title: l.noCamerasYet,
                  body: l.noCamerasBody,
                  action: FilledButton.icon(
                    onPressed: () => _open(const CameraEditScreen()),
                    icon: const Icon(Icons.add),
                    label: Text(l.addCamera),
                  ),
                )
              else
                for (final c in shown)
                  Padding(
                    padding: const EdgeInsets.only(top: 10),
                    child: _CameraCard(
                      camera: c,
                      onOpen: () => _open(CameraScreen(cameraId: c.id)),
                      onMenu: (action) => switch (action) {
                        'settings' => _open(CameraSettingsScreen(cameraId: c.id)),
                        'zones' => _open(ZoneEditorScreen(cameraId: c.id)),
                        'edit' => _open(CameraEditScreen(camera: c)),
                        'privacy' => _togglePrivacy(c),
                        _ => _delete(c),
                      },
                    ),
                  ),
            ]),
          );
        },
      ),
    );
  }
}

class _CameraCard extends StatelessWidget {
  const _CameraCard({required this.camera, required this.onOpen, required this.onMenu});

  final Camera camera;
  final VoidCallback onOpen;
  final ValueChanged<String> onMenu;

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final c = camera;
    final (color, status) = !c.enabled
        ? (Palette.muted, l.privacyOn)
        : c.online
            ? (Palette.accent, l.online)
            : (Palette.danger, l.offline);
    return Panel(
      padding: const EdgeInsets.all(10),
      onTap: onOpen,
      child: Row(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: SizedBox(
            width: 116,
            height: 72,
            child: c.enabled && c.online
                ? AuthImage(context.hub.url('/api/cameras/${c.id}/snapshot'), semanticLabel: c.name)
                : ColoredBox(
                    color: Palette.surfaceHigh,
                    child: Icon(c.enabled ? Icons.videocam_off_outlined : Icons.visibility_off_outlined,
                        color: Palette.muted),
                  ),
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            const SizedBox(height: 6),
            StatusDot(color: color, label: status),
            const SizedBox(height: 6),
            Row(children: [
              if (c.config.person) ...[
                Icon(Icons.directions_walk, size: 14, color: Palette.muted, semanticLabel: l.personDetection),
                const SizedBox(width: 6),
              ],
              if (c.config.motion) ...[
                Icon(Icons.motion_photos_on_outlined, size: 14, color: Palette.muted, semanticLabel: l.motionDetection),
                const SizedBox(width: 6),
              ],
              Flexible(
                child: Text(c.host, maxLines: 1, overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: Palette.muted)),
              ),
            ]),
          ]),
        ),
        PopupMenuButton<String>(
          tooltip: l.moreActions,
          icon: const Icon(Icons.more_vert),
          onSelected: onMenu,
          itemBuilder: (_) => [
            PopupMenuItem(value: 'settings', child: Text(l.triggers)),
            PopupMenuItem(value: 'zones', child: Text(l.triggerZones)),
            PopupMenuItem(value: 'edit', child: Text(l.connectionSettings)),
            PopupMenuItem(value: 'privacy', child: Text(c.enabled ? l.privacyEnable : l.privacyDisable)),
            PopupMenuItem(value: 'delete', child: Text(l.delete, style: const TextStyle(color: Palette.danger))),
          ],
        ),
      ]),
    );
  }
}
