import 'dart:io';
import 'dart:math';

import 'package:flutter/material.dart';

import '../services/notifications.dart';
import '../services/push.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'guides_screen.dart';

class NotifySettingsScreen extends StatefulWidget {
  const NotifySettingsScreen({super.key});

  @override
  State<NotifySettingsScreen> createState() => _NotifySettingsScreenState();
}

class _NotifySettingsScreenState extends State<NotifySettingsScreen> {
  bool _busy = false;
  Map<String, dynamic>? _ntfy;
  final _server = TextEditingController();
  final _topic = TextEditingController();
  final _token = TextEditingController();
  bool _ntfyOn = false;

  @override
  void initState() {
    super.initState();
    _loadNtfy();
  }

  @override
  void dispose() {
    _server.dispose();
    _topic.dispose();
    _token.dispose();
    super.dispose();
  }

  Future<void> _loadNtfy() async {
    try {
      final n = await context.hub.ntfy();
      if (!mounted) return;
      setState(() {
        _ntfy = n;
        _ntfyOn = n['enabled'] as bool? ?? false;
        _server.text = n['server'] as String? ?? 'https://ntfy.sh';
        _topic.text = (n['topic'] as String?)?.isNotEmpty == true ? n['topic'] as String : _randomTopic();
      });
    } catch (_) {}
  }

  /// Public ntfy topics are readable by anyone who guesses the name, so make it unguessable.
  String _randomTopic() {
    const chars = 'abcdefghijkmnpqrstuvwxyz23456789';
    final r = Random.secure();
    return 'obscura_${List.generate(20, (_) => chars[r.nextInt(chars.length)]).join()}';
  }

  Future<void> _togglePush(bool on) async {
    setState(() => _busy = true);
    try {
      await Notifications.requestPermission();
      if (on) {
        final ok = await Push.enable();
        if (!ok && mounted) {
          final l = context.l;
          if (await confirm(context, title: l.noDistributorTitle, body: l.noDistributorBody, action: l.openGuide,
              destructive: false)) {
            if (mounted) {
              Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidesScreen(open: 'notifications')));
            }
          }
        }
      } else {
        await Push.disable();
      }
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _saveNtfy() async {
    setState(() => _busy = true);
    try {
      await context.hub.putNtfy({
        'enabled': _ntfyOn,
        'server': _server.text.trim(),
        'topic': _topic.text.trim(),
        if (_token.text.isNotEmpty) 'token': _token.text,
      });
      _token.clear();
      if (mounted) showMessage(context, context.l.saved);
      await _loadNtfy();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.tabNotifications)),
      body: ListView(padding: listPadding(context, const EdgeInsets.all(16)), children: [
        if (Platform.isAndroid) ...[
          ValueListenableBuilder(
            valueListenable: Push.status,
            builder: (_, status, _) => Panel(
              padding: EdgeInsets.zero,
              child: SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: Text(l.pushTitle),
                subtitle: Text(
                  switch (status) {
                    PushStatus.active => l.pushActiveHint,
                    PushStatus.noDistributor => l.noDistributorTitle,
                    PushStatus.error => l.pushError,
                    PushStatus.off => l.pushOffHint,
                  },
                  style: const TextStyle(color: Palette.muted, fontSize: 12),
                ),
                value: status == PushStatus.active,
                onChanged: _busy ? null : _togglePush,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Text(l.pushExplain, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        ],
        SectionLabel(l.soundPreview),
        Panel(
          child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
            Text(l.soundPreviewHint, style: const TextStyle(color: Palette.muted, fontSize: 13)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(
                child: OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(foregroundColor: Palette.danger, side: const BorderSide(color: Palette.danger)),
                  onPressed: () async {
                    await Notifications.requestPermission();
                    await Notifications.showEvent(eventId: -1, kind: 'person', camera: l.soundTest);
                  },
                  icon: const Icon(Icons.directions_walk),
                  label: Text(l.kindPerson),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await Notifications.requestPermission();
                    await Notifications.showEvent(eventId: -2, kind: 'motion', camera: l.soundTest);
                  },
                  icon: const Icon(Icons.motion_photos_on_outlined),
                  label: Text(l.kindMotion),
                ),
              ),
            ]),
          ]),
        ),
        SectionLabel(l.ntfyTitle,
            trailing: TextButton(
              onPressed: () =>
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidesScreen(open: 'notifications'))),
              child: Text(l.howTo),
            )),
        Text(l.ntfyExplain, style: const TextStyle(color: Palette.muted, fontSize: 12)),
        if (_ntfy != null) ...[
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.ntfyEnable),
            value: _ntfyOn,
            onChanged: (v) => setState(() => _ntfyOn = v),
          ),
          if (_ntfyOn) ...[
            TextField(
              controller: _server,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: InputDecoration(labelText: l.ntfyServer, hintText: 'https://ntfy.sh…'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _topic,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l.ntfyTopic,
                helperText: l.ntfyTopicHint,
                helperMaxLines: 3,
                suffixIcon: IconButton(
                  tooltip: l.generate,
                  icon: const Icon(Icons.casino_outlined),
                  onPressed: () => setState(() => _topic.text = _randomTopic()),
                ),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _token,
              obscureText: true,
              autocorrect: false,
              decoration: InputDecoration(
                labelText: l.ntfyToken,
                helperText: _ntfy!['has_token'] == true ? l.passwordKeep : l.optional,
              ),
            ),
          ],
          const SizedBox(height: 16),
          FilledButton(onPressed: _busy ? null : _saveNtfy, child: Text(l.save)),
        ],
      ]),
    );
  }
}
