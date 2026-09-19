import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../api/models.dart';
import '../services/push.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'devices_screen.dart';
import 'guides_screen.dart';
import 'notify_settings_screen.dart';
import 'storage_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late Future<Overview> _overview = context.hub.overview();

  void _open(Widget screen) => Navigator.push(context, MaterialPageRoute(builder: (_) => screen))
      .then((_) => mounted ? setState(() => _overview = context.hub.overview()) : null);

  Future<void> _toggleLock(bool on) async {
    final session = SessionScope.read(context);
    final l = context.l;
    if (on) {
      final auth = LocalAuthentication();
      if (!await auth.isDeviceSupported()) {
        if (mounted) showMessage(context, l.lockUnsupported);
        return;
      }
      // Prove the user can unlock before turning the lock on.
      bool ok;
      try {
        ok = await auth.authenticate(localizedReason: l.unlockReason);
      } catch (_) {
        ok = false;
      }
      if (!ok) return;
    }
    await session.setAppLock(on);
  }

  Future<void> _disconnect() async {
    final l = context.l;
    final session = SessionScope.read(context);
    if (!await confirm(context, title: l.disconnectTitle, body: l.disconnectBody, action: l.disconnect)) return;
    await Push.disable().catchError((_) {});
    await session.forget();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final session = SessionScope.of(context);
    final client = session.client!;
    return SafeArea(
      child: ListView(padding: const EdgeInsets.fromLTRB(16, 16, 16, 24), children: [
        Text(l.tabSettings, style: Theme.of(context).textTheme.headlineMedium),
        const SizedBox(height: 16),
        FutureBuilder(
          future: _overview,
          builder: (context, snap) {
            final o = snap.data;
            return Panel(
              child: Row(children: [
                const Icon(Icons.dns_outlined, color: Palette.accent, size: 32),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(o?.hubName ?? session.hubName, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
                    const SizedBox(height: 2),
                    Text(client.baseUrl.toString(),
                        maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: Palette.muted, fontSize: 12)),
                    if (o != null) ...[
                      const SizedBox(height: 6),
                      Text('v${o.version} · ${l.storedClips(formatBytes(context, o.storageBytes))}'
                          '${o.diskFree != null ? ' · ${l.diskFree(formatBytes(context, o.diskFree!))}' : ''}',
                          style: const TextStyle(color: Palette.muted, fontSize: 12)),
                    ],
                  ]),
                ),
                StatusDot(
                  color: snap.hasError ? Palette.danger : Palette.accent,
                  label: snap.hasError ? l.offline : l.online,
                ),
              ]),
            );
          },
        ),
        SectionLabel(l.hubSection),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(children: [
            ValueListenableBuilder(
              valueListenable: Push.status,
              builder: (_, status, _) => _Tile(
                icon: Icons.notifications_active_outlined,
                title: l.tabNotifications,
                subtitle: status == PushStatus.active ? l.pushActive : l.pushInactive,
                onTap: () => _open(const NotifySettingsScreen()),
              ),
            ),
            const Divider(),
            _Tile(
              icon: Icons.cloud_outlined,
              title: l.storage,
              subtitle: l.storageSubtitle,
              onTap: () => _open(const StorageScreen()),
            ),
            const Divider(),
            _Tile(
              icon: Icons.devices_outlined,
              title: l.devices,
              subtitle: l.devicesSubtitle,
              onTap: () => _open(const DevicesScreen()),
            ),
          ]),
        ),
        SectionLabel(l.appSection),
        Panel(
          padding: EdgeInsets.zero,
          child: Column(children: [
            SwitchListTile(
              secondary: const Icon(Icons.fingerprint),
              title: Text(l.appLock),
              subtitle: Text(l.appLockHint, style: const TextStyle(color: Palette.muted, fontSize: 12)),
              value: session.appLock,
              onChanged: _toggleLock,
            ),
            const Divider(),
            _Tile(
              icon: Icons.menu_book_outlined,
              title: l.guides,
              subtitle: l.guidesSubtitle,
              onTap: () => _open(const GuidesScreen()),
            ),
            const Divider(),
            _Tile(
              icon: Icons.info_outline,
              title: l.about,
              subtitle: l.aboutSubtitle,
              onTap: () => showLicensePage(context: context, applicationName: 'Obscura', applicationLegalese: 'MIT License'),
            ),
          ]),
        ),
        const SizedBox(height: 24),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: Palette.danger, side: const BorderSide(color: Palette.danger)),
          onPressed: _disconnect,
          icon: const Icon(Icons.link_off),
          label: Text(l.disconnect),
        ),
      ]),
    );
  }
}

class _Tile extends StatelessWidget {
  const _Tile({required this.icon, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => ListTile(
        leading: Icon(icon),
        title: Text(title),
        subtitle: Text(subtitle, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        trailing: const Icon(Icons.chevron_right, color: Palette.muted),
        onTap: onTap,
      );
}
