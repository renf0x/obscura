import 'package:flutter/material.dart';

import '../api/models.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'guides_screen.dart';

/// Add a camera or edit its connection (host, credentials, stream paths).
class CameraEditScreen extends StatefulWidget {
  const CameraEditScreen({super.key, this.camera});

  final Camera? camera;

  @override
  State<CameraEditScreen> createState() => _CameraEditScreenState();
}

class _CameraEditScreenState extends State<CameraEditScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.camera?.name ?? '');
  late final _host = TextEditingController(text: widget.camera?.host ?? '');
  late final _port = TextEditingController(text: '${widget.camera?.port ?? 554}');
  late final _user = TextEditingController(text: widget.camera?.username ?? '');
  final _pass = TextEditingController();
  final _cloud = TextEditingController();
  late bool _twoWay = widget.camera?.twoWay ?? false;
  bool _removeCloud = false;
  bool _showCloud = false;
  late final _main = TextEditingController(text: widget.camera?.mainPath ?? '');
  late final _sub = TextEditingController(text: widget.camera?.subPath ?? '');
  late String _vendor = widget.camera?.vendor ?? 'tapo';
  bool _showPass = false;
  bool _advanced = false;
  bool _busy = false;
  Map<String, dynamic> _presets = {};
  List<DiscoveredCamera>? _found;
  bool _scanning = false;

  bool get _editing => widget.camera != null;

  @override
  void initState() {
    super.initState();
    context.hub.presets().then((p) {
      if (!mounted) return;
      setState(() => _presets = p);
      if (!_editing) _applyPreset(_vendor);
    }).catchError((_) {});
  }

  @override
  void dispose() {
    for (final c in [_name, _host, _port, _user, _pass, _cloud, _main, _sub]) {
      c.dispose();
    }
    super.dispose();
  }

  void _applyPreset(String vendor) {
    final p = _presets[vendor] as Map<String, dynamic>?;
    setState(() {
      _vendor = vendor;
      if (p != null) {
        _port.text = '${p['port']}';
        _main.text = p['main'] as String;
        _sub.text = p['sub'] as String;
      }
      if (vendor == 'generic') _advanced = true;
    });
  }

  Future<void> _scan() async {
    setState(() => _scanning = true);
    try {
      final found = await context.hub.discover();
      if (mounted) setState(() => _found = found);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    final body = {
      'name': _name.text.trim(),
      'vendor': _vendor,
      'host': _host.text.trim(),
      'port': int.parse(_port.text),
      'username': _user.text,
      // Empty password field while editing = keep the stored one.
      'password': (_editing && _pass.text.isEmpty) ? null : _pass.text,
      'main_path': _main.text.trim(),
      'sub_path': _sub.text.trim(),
      'enabled': widget.camera?.enabled ?? true,
      // TP-Link account password: null = keep, '' = remove. Only its hash is kept on the hub.
      'cloud_password': _vendor != 'tapo' || _removeCloud ? (_editing ? '' : null) : (_cloud.text.isEmpty ? null : _cloud.text),
      'two_way': _vendor != 'tapo' && _twoWay,
    };
    final hub = context.hub;
    final l = context.l;
    try {
      final cam = _editing ? await hub.updateConnection(widget.camera!.id, body) : await hub.addCamera(body);
      if (_vendor == 'tapo' && _cloud.text.isNotEmpty && !_removeCloud) {
        // Check the account password right away, so a typo shows up now and not when it's needed.
        final r = await hub.testControl(cam.id);
        if (mounted) r.ok ? showMessage(context, l.controlOk) : showMessage(context, l.controlFailed(r.message));
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  String? _pathValidator(String? v, {bool optional = false}) {
    final value = (v ?? '').trim();
    if (value.isEmpty) return optional ? null : context.l.fieldRequired;
    return RegExp(r'^/[A-Za-z0-9._~/?=&%+:,;-]{0,200}$').hasMatch(value) ? null : context.l.pathInvalid;
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? l.connectionSettings : l.addCamera)),
      body: Form(
        key: _form,
        child: ListView(padding: listPadding(context, const EdgeInsets.all(16)), children: [
          // Discovery only sees the hub's own LAN: a hub on a remote server can't find home cameras.
          if (!_editing && !isPrivateHost(context.hub.baseUrl.host))
            Panel(
              child: Row(children: [
                const Icon(Icons.info_outline, color: Palette.accent),
                const SizedBox(width: 10),
                Expanded(child: Text(l.remoteHubManual, style: const TextStyle(color: Palette.muted))),
              ]),
            )
          else if (!_editing) ...[
            Panel(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  const Icon(Icons.radar, color: Palette.accent),
                  const SizedBox(width: 10),
                  Expanded(child: Text(l.findOnNetwork, style: const TextStyle(fontWeight: FontWeight.w600))),
                  TextButton(
                    onPressed: _scanning ? null : _scan,
                    child: _scanning
                        ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : Text(l.scan),
                  ),
                ]),
                if (_found != null && _found!.isEmpty)
                  Padding(padding: const EdgeInsets.only(top: 8), child: Text(l.nothingFound, style: const TextStyle(color: Palette.muted))),
                for (final d in _found ?? const <DiscoveredCamera>[])
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    enabled: !d.added,
                    leading: const Icon(Icons.videocam_outlined),
                    title: Text(d.host),
                    subtitle: Text(d.added ? l.alreadyAdded : (_presets[d.vendor]?['label'] as String? ?? d.vendor)),
                    onTap: () {
                      _host.text = d.host;
                      if (_presets.containsKey(d.vendor)) _applyPreset(d.vendor);
                    },
                  ),
              ]),
            ),
            const SizedBox(height: 16),
          ],
          DropdownButtonFormField<String>(
            initialValue: _vendor,
            decoration: InputDecoration(labelText: l.cameraBrand, prefixIcon: const Icon(Icons.category_outlined)),
            items: [
              for (final v in ['tapo', 'hikvision', 'dahua', 'reolink', 'generic'])
                DropdownMenuItem(value: v, child: Text(_presets[v]?['label'] as String? ?? v)),
            ],
            onChanged: (v) => _applyPreset(v!),
          ),
          if (_vendor == 'tapo') ...[
            const SizedBox(height: 12),
            Panel(
              highlight: Palette.accentDim,
              onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidesScreen(open: 'tapo'))),
              child: Row(children: [
                const Icon(Icons.info_outline, color: Palette.accent),
                const SizedBox(width: 12),
                Expanded(child: Text(l.tapoHint, style: const TextStyle(fontSize: 13))),
                const Icon(Icons.chevron_right, color: Palette.muted),
              ]),
            ),
          ],
          const SizedBox(height: 12),
          TextFormField(
            controller: _name,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(labelText: l.cameraName, hintText: l.cameraNameHint),
            validator: (v) => (v ?? '').trim().isEmpty || v!.length > 40 ? l.fieldRequired : null,
          ),
          const SizedBox(height: 12),
          Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Expanded(
              flex: 3,
              child: TextFormField(
                controller: _host,
                keyboardType: TextInputType.url,
                autocorrect: false,
                enableSuggestions: false,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(labelText: l.cameraIp, hintText: '192.168.1.50…'),
                validator: (v) => RegExp(r'^[A-Za-z0-9.:-]{1,253}$').hasMatch((v ?? '').trim()) ? null : l.hostInvalid,
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextFormField(
                controller: _port,
                keyboardType: TextInputType.number,
                decoration: InputDecoration(labelText: l.port),
                validator: (v) {
                  final p = int.tryParse(v ?? '');
                  return p == null || p < 1 || p > 65535 ? l.portInvalid : null;
                },
              ),
            ),
          ]),
          const SizedBox(height: 12),
          TextFormField(
            controller: _user,
            autocorrect: false,
            enableSuggestions: false,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.username],
            decoration: InputDecoration(labelText: l.cameraUser, prefixIcon: const Icon(Icons.person_outline)),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _pass,
            obscureText: !_showPass,
            autocorrect: false,
            enableSuggestions: false,
            autofillHints: const [AutofillHints.password],
            decoration: InputDecoration(
              labelText: l.cameraPassword,
              helperText: _editing && widget.camera!.hasPassword ? l.passwordKeep : null,
              prefixIcon: const Icon(Icons.lock_outline),
              suffixIcon: IconButton(
                tooltip: _showPass ? l.hidePassword : l.showPassword,
                icon: Icon(_showPass ? Icons.visibility_off : Icons.visibility),
                onPressed: () => setState(() => _showPass = !_showPass),
              ),
            ),
          ),
          SectionLabel(l.voiceAndSiren),
          if (_vendor == 'tapo') ...[
            TextFormField(
              controller: _cloud,
              enabled: !_removeCloud,
              obscureText: !_showCloud,
              autocorrect: false,
              enableSuggestions: false,
              decoration: InputDecoration(
                labelText: l.cloudPassword,
                helperText: _editing && widget.camera!.hasCloudPassword ? l.passwordKeep : l.cloudPasswordHint,
                helperMaxLines: 3,
                prefixIcon: const Icon(Icons.record_voice_over_outlined),
                suffixIcon: IconButton(
                  tooltip: _showCloud ? l.hidePassword : l.showPassword,
                  icon: Icon(_showCloud ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => _showCloud = !_showCloud),
                ),
              ),
            ),
            if (_editing && widget.camera!.hasCloudPassword)
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: Text(l.cloudPasswordRemove),
                value: _removeCloud,
                onChanged: (v) => setState(() => _removeCloud = v ?? false),
              ),
          ] else
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(l.twoWay),
              subtitle: Text(l.twoWayHint, style: const TextStyle(color: Palette.muted, fontSize: 12)),
              value: _twoWay,
              onChanged: (v) => setState(() => _twoWay = v),
            ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l.advanced),
            subtitle: Text(l.advancedHint, style: const TextStyle(color: Palette.muted, fontSize: 12)),
            value: _advanced,
            onChanged: (v) => setState(() => _advanced = v),
          ),
          if (_advanced) ...[
            TextFormField(
              controller: _main,
              autocorrect: false,
              decoration: InputDecoration(labelText: l.mainStreamPath, hintText: '/stream1…'),
              validator: _pathValidator,
            ),
            const SizedBox(height: 12),
            TextFormField(
              controller: _sub,
              autocorrect: false,
              decoration: InputDecoration(labelText: l.subStreamPath, hintText: '/stream2…', helperText: l.subStreamHint),
              validator: (v) => _pathValidator(v, optional: true),
            ),
          ],
          const SizedBox(height: 24),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: _busy
                ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                : Text(_editing ? l.save : l.addCamera),
          ),
        ]),
      ),
    );
  }
}
