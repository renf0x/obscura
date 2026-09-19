import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../api/hub_client.dart';
import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'guides_screen.dart';

class ConnectScreen extends StatefulWidget {
  const ConnectScreen({super.key});

  @override
  State<ConnectScreen> createState() => _ConnectScreenState();
}

class _ConnectScreenState extends State<ConnectScreen> {
  final _form = GlobalKey<FormState>();
  final _url = TextEditingController();
  final _code = TextEditingController();
  final _name = TextEditingController(text: 'Phone');
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _url.dispose();
    _code.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_form.currentState!.validate()) return;
    final l = context.l;
    final parsed = parseHubUrl(_url.text);
    if (parsed.issue == HubUrlIssue.insecurePublic) {
      final go = await confirm(context, title: l.insecureTitle, body: l.insecureBody, action: l.connectAnyway);
      if (!go || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await SessionScope.read(context).pair(parsed.url!, _code.text, _name.text.trim());
    } on HubException catch (e) {
      setState(() => _error = switch (e.status) {
            403 => l.pairInvalidCode,
            429 => l.pairTooMany,
            0 => l.hubUnreachableHint,
            _ => e.message,
          });
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _scan() async {
    final raw = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const _ScanScreen()));
    if (raw == null) return;
    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      setState(() {
        _url.text = data['url'] as String;
        _code.text = data['code'] as String;
      });
    } catch (_) {
      if (mounted) showMessage(context, context.l.qrInvalid);
      return;
    }
    // The QR carries everything needed: connect right away, nothing to type.
    if (mounted) await _submit();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      body: GridBackdrop(
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 440),
                child: Form(
                  key: _form,
                  child: AutofillGroup(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                      const _Brand(),
                      const SizedBox(height: 32),
                      Text(l.connectTitle, style: Theme.of(context).textTheme.headlineMedium),
                      const SizedBox(height: 8),
                      Text(l.connectSubtitle, style: const TextStyle(color: Palette.muted)),
                      const SizedBox(height: 24),
                      TextFormField(
                        controller: _url,
                        keyboardType: TextInputType.url,
                        autocorrect: false,
                        enableSuggestions: false,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.url],
                        decoration: InputDecoration(
                          labelText: l.hubAddress,
                          hintText: '192.168.1.10:7878…',
                          prefixIcon: const Icon(Icons.dns_outlined),
                        ),
                        validator: (v) => parseHubUrl(v ?? '').url == null ? l.hubAddressInvalid : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _code,
                        autocorrect: false,
                        enableSuggestions: false,
                        textCapitalization: TextCapitalization.characters,
                        textInputAction: TextInputAction.next,
                        autofillHints: const [AutofillHints.oneTimeCode],
                        decoration: InputDecoration(
                          labelText: l.pairingCode,
                          hintText: 'K7M2-QX9P4R…',
                          prefixIcon: const Icon(Icons.key_outlined),
                        ),
                        validator: (v) => (v ?? '').replaceAll(RegExp(r'[\s-]'), '').length < 6 ? l.pairingCodeInvalid : null,
                      ),
                      const SizedBox(height: 12),
                      TextFormField(
                        controller: _name,
                        textInputAction: TextInputAction.done,
                        onFieldSubmitted: (_) => _submit(),
                        decoration: InputDecoration(labelText: l.deviceName, prefixIcon: const Icon(Icons.smartphone)),
                        validator: (v) => (v ?? '').trim().isEmpty || v!.length > 40 ? l.deviceNameInvalid : null,
                      ),
                      if (_error != null) ...[
                        const SizedBox(height: 12),
                        Semantics(
                          liveRegion: true,
                          child: Text(_error!, style: const TextStyle(color: Palette.danger)),
                        ),
                      ],
                      const SizedBox(height: 20),
                      FilledButton(
                        onPressed: _busy ? null : _submit,
                        child: _busy
                            ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2))
                            : Text(l.connect),
                      ),
                      const SizedBox(height: 12),
                      OutlinedButton.icon(onPressed: _scan, icon: const Icon(Icons.qr_code_scanner), label: Text(l.scanQr)),
                      const SizedBox(height: 28),
                      Panel(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidesScreen())),
                        child: Row(children: [
                          const Icon(Icons.menu_book_outlined, color: Palette.accent),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                              Text(l.noHubYet, style: const TextStyle(fontWeight: FontWeight.w600)),
                              const SizedBox(height: 2),
                              Text(l.noHubYetBody, style: const TextStyle(color: Palette.muted, fontSize: 13)),
                            ]),
                          ),
                          const Icon(Icons.chevron_right, color: Palette.muted),
                        ]),
                      ),
                    ]),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand();

  @override
  Widget build(BuildContext context) {
    return Column(children: [
      Container(
        width: 84,
        height: 84,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Palette.accent, width: 1.5),
          boxShadow: [BoxShadow(color: Palette.accent.withValues(alpha: 0.25), blurRadius: 24)],
        ),
        child: const Icon(Icons.remove_red_eye_outlined, size: 38, color: Palette.accent),
      ),
      const SizedBox(height: 16),
      const Text('OBSCURA', style: TextStyle(letterSpacing: 10, fontSize: 20, fontWeight: FontWeight.w300)),
      const SizedBox(height: 6),
      Text(context.l.tagline.toUpperCase(),
          textAlign: TextAlign.center, style: const TextStyle(letterSpacing: 3, fontSize: 10, color: Palette.muted)),
    ]);
  }
}

class _ScanScreen extends StatefulWidget {
  const _ScanScreen();

  @override
  State<_ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<_ScanScreen> {
  bool _done = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(context.l.scanQr)),
      body: MobileScanner(
        onDetect: (capture) {
          final value = capture.barcodes.firstOrNull?.rawValue;
          if (value == null || _done) return;
          _done = true;
          Navigator.pop(context, value);
        },
      ),
    );
  }
}
