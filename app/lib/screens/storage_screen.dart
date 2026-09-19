import 'package:flutter/material.dart';

import '../theme.dart';
import '../widgets/common.dart';
import 'guides_screen.dart';

/// Local retention + optional off-site copy (S3, WebDAV, or any rclone remote set up on the hub).
class StorageScreen extends StatefulWidget {
  const StorageScreen({super.key});

  @override
  State<StorageScreen> createState() => _StorageScreenState();
}

class _StorageScreenState extends State<StorageScreen> {
  Map<String, dynamic>? _cfg;
  Object? _error;
  bool _busy = false;
  final _days = TextEditingController();
  final _gb = TextEditingController();
  final _path = TextEditingController();
  final _remote = TextEditingController();
  String _type = 'none';
  bool _cloud = false;
  // Backend credential fields; secrets are write-only and never shown again.
  final Map<String, TextEditingController> _opts = {
    for (final k in ['provider', 'endpoint', 'region', 'access_key_id', 'secret_access_key', 'url', 'vendor', 'user', 'pass'])
      k: TextEditingController(),
  };

  @override
  void initState() {
    super.initState();
    _opts['provider']!.text = 'Other';
    _opts['vendor']!.text = 'nextcloud';
    _load();
  }

  @override
  void dispose() {
    for (final c in [_days, _gb, _path, _remote, ..._opts.values]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final cfg = await context.hub.storage();
      if (!mounted) return;
      final cloud = cfg['cloud'] as Map;
      setState(() {
        _cfg = cfg;
        _error = null;
        _days.text = '${cfg['retention_days']}';
        _gb.text = '${cfg['max_gb']}';
        _cloud = cloud['enabled'] as bool? ?? false;
        _type = cloud['type'] as String? ?? 'none';
        _path.text = cloud['path'] as String? ?? 'obscura';
        _remote.text = cloud['remote'] as String? ?? '';
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    }
  }

  Future<void> _save() async {
    final l = context.l;
    final days = int.tryParse(_days.text);
    final gb = double.tryParse(_gb.text.replaceAll(',', '.'));
    if (days == null || days < 1 || days > 365 || gb == null || gb < 0.5) {
      showMessage(context, l.retentionInvalid);
      return;
    }
    setState(() => _busy = true);
    try {
      final hub = context.hub;
      if (_type == 's3' || _type == 'webdav') {
        final keys = _type == 's3'
            ? ['provider', 'endpoint', 'region', 'access_key_id', 'secret_access_key']
            : ['url', 'vendor', 'user', 'pass'];
        final opts = {for (final k in keys) if (_opts[k]!.text.trim().isNotEmpty) k: _opts[k]!.text.trim()};
        // Only (re)write credentials when the user typed a secret; otherwise keep the hub's config.
        if (opts.containsKey('secret_access_key') || opts.containsKey('pass')) {
          await hub.setBackend(_type, opts);
          for (final k in ['secret_access_key', 'pass']) {
            _opts[k]!.clear();
          }
        }
      }
      await hub.putStorage({
        'retention_days': days,
        'max_gb': gb,
        'cloud_enabled': _cloud && _type != 'none',
        'cloud_type': _type,
        'cloud_path': _path.text.trim(),
        'custom_remote': _remote.text.trim(),
      });
      if (mounted) showMessage(context, l.saved);
      await _load();
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    setState(() => _busy = true);
    try {
      final r = await context.hub.testStorage();
      if (mounted) showMessage(context, r.ok ? context.l.storageTestOk : '${context.l.storageTestFailed}: ${r.message}');
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(String key, String label, {bool secret = false, String? hint, TextInputType? type}) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: TextField(
        controller: _opts[key],
        obscureText: secret,
        autocorrect: false,
        enableSuggestions: false,
        keyboardType: type,
        decoration: InputDecoration(
          labelText: label,
          hintText: hint,
          helperText: secret ? context.l.secretWriteOnly : null,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final usage = _cfg?['usage'] as Map?;
    return Scaffold(
      appBar: AppBar(title: Text(l.storage)),
      body: _error != null
          ? ErrorState(error: _error!, onRetry: _load)
          : _cfg == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(padding: listPadding(context, const EdgeInsets.all(16)), children: [
                  Panel(
                    child: Row(children: [
                      const Icon(Icons.sd_storage_outlined, color: Palette.accent),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          l.storageUsage(usage?['events'] as int? ?? 0, formatBytes(context, usage?['bytes'] as int? ?? 0)),
                          style: const TextStyle(fontFeatures: tabular),
                        ),
                      ),
                    ]),
                  ),
                  SectionLabel(l.onHub),
                  Row(children: [
                    Expanded(
                      child: TextField(
                        controller: _days,
                        keyboardType: TextInputType.number,
                        decoration: InputDecoration(labelText: l.keepDays),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _gb,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: InputDecoration(labelText: l.maxGb),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 6),
                  Text(l.retentionHint, style: const TextStyle(color: Palette.muted, fontSize: 12)),
                  SectionLabel(l.cloudCopy,
                      trailing: TextButton(
                        onPressed: () =>
                            Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidesScreen(open: 'cloud'))),
                        child: Text(l.howTo),
                      )),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(l.cloudEnabled),
                    subtitle: Text(l.cloudEnabledHint, style: const TextStyle(color: Palette.muted, fontSize: 12)),
                    value: _cloud,
                    onChanged: (v) => setState(() {
                      _cloud = v;
                      if (v && _type == 'none') _type = 's3';
                    }),
                  ),
                  if (_cloud) ...[
                    const SizedBox(height: 8),
                    SegmentedButton<String>(
                      segments: [
                        const ButtonSegment(value: 's3', label: Text('S3')),
                        const ButtonSegment(value: 'webdav', label: Text('WebDAV')),
                        ButtonSegment(value: 'custom', label: Text(l.rcloneCustom)),
                      ],
                      selected: {_type},
                      onSelectionChanged: (s) => setState(() => _type = s.first),
                    ),
                    if (_type == 's3') ...[
                      _field('provider', l.s3Provider, hint: 'Other / AWS / Minio / Cloudflare…'),
                      _field('endpoint', l.s3Endpoint, hint: 'https://storage.yandexcloud.net…', type: TextInputType.url),
                      _field('region', l.s3Region, hint: 'ru-central1…'),
                      _field('access_key_id', l.s3AccessKey),
                      _field('secret_access_key', l.s3SecretKey, secret: true),
                    ],
                    if (_type == 'webdav') ...[
                      _field('url', l.webdavUrl, hint: 'https://webdav.yandex.ru…', type: TextInputType.url),
                      _field('vendor', l.webdavVendor, hint: 'nextcloud / owncloud / other…'),
                      _field('user', l.webdavUser),
                      _field('pass', l.webdavPassword, secret: true),
                    ],
                    if (_type == 'custom')
                      Padding(
                        padding: const EdgeInsets.only(top: 12),
                        child: TextField(
                          controller: _remote,
                          autocorrect: false,
                          decoration: InputDecoration(labelText: l.rcloneRemote, helperText: l.rcloneRemoteHint, helperMaxLines: 3),
                        ),
                      ),
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextField(
                        controller: _path,
                        autocorrect: false,
                        decoration: InputDecoration(labelText: l.cloudFolder, hintText: 'obscura…'),
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _save,
                    child: _busy
                        ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.save),
                  ),
                  if (_cloud) ...[
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      onPressed: _busy ? null : _test,
                      icon: const Icon(Icons.network_check),
                      label: Text(l.testConnection),
                    ),
                  ],
                ]),
    );
  }
}
