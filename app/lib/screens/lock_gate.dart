import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';

import '../state/session.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Optional biometric / device-PIN lock. Re-locks after 30 s in the background.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  final _auth = LocalAuthentication();
  bool _unlocked = false;
  bool _busy = false;
  DateTime? _pausedAt;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _unlock());
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) _pausedAt = DateTime.now();
    if (state == AppLifecycleState.resumed && _pausedAt != null) {
      if (DateTime.now().difference(_pausedAt!) > const Duration(seconds: 30)) {
        setState(() => _unlocked = false);
        _unlock();
      }
      _pausedAt = null;
    }
  }

  Future<void> _unlock() async {
    if (!SessionScope.read(context).appLock || _busy) return;
    _busy = true;
    try {
      final ok = await _auth.authenticate(localizedReason: context.l.unlockReason, persistAcrossBackgrounding: true);
      if (mounted) setState(() => _unlocked = ok);
    } catch (_) {
      // No biometrics/PIN configured on the device: fail closed, the user can retry.
    } finally {
      _busy = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = SessionScope.of(context);
    if (!session.appLock || _unlocked) return widget.child;
    return Scaffold(
      body: GridBackdrop(
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const Icon(Icons.lock_outline, size: 56, color: Palette.accent),
            const SizedBox(height: 16),
            Text(context.l.locked, style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 24),
            FilledButton.icon(onPressed: _unlock, icon: const Icon(Icons.fingerprint), label: Text(context.l.unlock)),
          ]),
        ),
      ),
    );
  }
}
