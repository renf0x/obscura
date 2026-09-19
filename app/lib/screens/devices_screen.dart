import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Paired phones, revocation, and a QR code to pair another phone.
class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  late Future<List<Device>> _devices = context.hub.devices();

  void _refresh() => setState(() => _devices = context.hub.devices());

  Future<void> _revoke(Device d) async {
    final l = context.l;
    if (!await confirm(context, title: l.revokeTitle(d.name), body: l.revokeBody, action: l.revoke)) return;
    if (!mounted) return;
    try {
      await context.hub.revokeDevice(d.id);
      _refresh();
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  Future<void> _pairAnother() async {
    final hub = context.hub;
    try {
      final code = await hub.newPairingCode();
      if (!mounted) return;
      final payload = jsonEncode({'url': hub.baseUrl.toString(), 'code': code});
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Palette.surface,
        isScrollControlled: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Text(context.l.pairAnother, style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(context.l.pairAnotherHint, textAlign: TextAlign.center, style: const TextStyle(color: Palette.muted)),
              const SizedBox(height: 16),
              Container(
                color: Colors.white,
                padding: const EdgeInsets.all(12),
                child: QrImageView(data: payload, size: 220, semanticsLabel: context.l.qrCode),
              ),
              const SizedBox(height: 16),
              SelectableText(code, style: const TextStyle(fontSize: 24, letterSpacing: 4, fontFeatures: tabular)),
              const SizedBox(height: 4),
              Text(context.l.codeExpires, style: const TextStyle(color: Palette.muted, fontSize: 12)),
            ]),
          ),
        ),
      );
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(l.devices)),
      body: FutureBuilder(
        future: _devices,
        builder: (context, snap) {
          if (snap.hasError) return ErrorState(error: snap.error!, onRetry: _refresh);
          if (!snap.hasData) return const Center(child: CircularProgressIndicator());
          return ListView(padding: listPadding(context, const EdgeInsets.all(16)), children: [
            FilledButton.icon(onPressed: _pairAnother, icon: const Icon(Icons.qr_code_2), label: Text(l.pairAnother)),
            const SizedBox(height: 16),
            Panel(
              padding: EdgeInsets.zero,
              child: Column(children: [
                for (final (i, d) in snap.data!.indexed) ...[
                  if (i > 0) const Divider(),
                  ListTile(
                    leading: Icon(d.current ? Icons.smartphone : Icons.phone_android_outlined),
                    title: Text(d.current ? '${d.name} (${l.thisDevice})' : d.name),
                    subtitle: Text(
                      '${l.lastSeen(formatTime(context, d.lastSeen))}${d.push ? ' · ${l.pushActive}' : ''}',
                      style: const TextStyle(color: Palette.muted, fontSize: 12),
                    ),
                    trailing: d.current
                        ? null
                        : IconButton(
                            tooltip: l.revoke,
                            icon: const Icon(Icons.block, color: Palette.danger),
                            onPressed: () => _revoke(d),
                          ),
                  ),
                ],
              ]),
            ),
            const SizedBox(height: 12),
            Text(l.devicesHint, style: const TextStyle(color: Palette.muted, fontSize: 12)),
          ]);
        },
      ),
    );
  }
}
