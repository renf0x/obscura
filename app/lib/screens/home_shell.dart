import 'dart:async';

import 'package:flutter/material.dart';

import '../api/hub_client.dart';
import '../services/notifications.dart';
import '../services/push.dart';
import '../state/session.dart';
import '../widgets/common.dart';
import 'cameras_screen.dart';
import 'events_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Bumped whenever the hub reports a new or finished event, so visible lists can refresh.
final eventsVersion = ValueNotifier<int>(0);

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _tab = 0;
  StreamSubscription<Map<String, dynamic>>? _sub;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _listen();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _sub?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Keep the live connection only while visible; background alerts come through push.
    if (state == AppLifecycleState.resumed) {
      _listen();
    } else if (state == AppLifecycleState.paused) {
      _sub?.cancel();
      _sub = null;
    }
  }

  void _listen() {
    if (_sub != null) return;
    final session = SessionScope.read(context);
    _sub = session.client!.liveEvents().listen((msg) {
      if (msg['type'] != 'event') return;
      eventsVersion.value++;
      final ev = msg['event'] as Map<String, dynamic>;
      // With push active the distributor already alerts us; avoid a double sound.
      if (msg['phase'] == 'start' && Push.status.value != PushStatus.active) {
        Notifications.showEvent(eventId: ev['id'] as int, kind: ev['kind'] as String, camera: ev['camera'] as String);
      }
    }, onError: (Object e) {
      if (e is HubException && e.unauthorized && mounted) _revoked();
    });
  }

  Future<void> _revoked() async {
    final session = SessionScope.read(context);
    showMessage(context, context.l.deviceRevoked);
    await session.forget();
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    return Scaffold(
      body: IndexedStack(index: _tab, children: [
        HomeScreen(onOpenTab: (t) => setState(() => _tab = t)),
        const CamerasScreen(),
        const EventsScreen(),
        const SettingsScreen(),
      ]),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (t) => setState(() => _tab = t),
        destinations: [
          NavigationDestination(icon: const Icon(Icons.home_outlined), selectedIcon: const Icon(Icons.home), label: l.tabHome),
          NavigationDestination(
              icon: const Icon(Icons.videocam_outlined), selectedIcon: const Icon(Icons.videocam), label: l.tabCameras),
          NavigationDestination(
              icon: const Icon(Icons.notifications_none), selectedIcon: const Icon(Icons.notifications), label: l.tabEvents),
          NavigationDestination(
              icon: const Icon(Icons.settings_outlined), selectedIcon: const Icon(Icons.settings), label: l.tabSettings),
        ],
      ),
    );
  }
}
