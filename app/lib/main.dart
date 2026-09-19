import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:media_kit/media_kit.dart';

import 'l10n/app_localizations.dart';
import 'screens/connect_screen.dart';
import 'screens/event_screen.dart';
import 'screens/home_shell.dart';
import 'screens/lock_gate.dart';
import 'services/notifications.dart';
import 'services/push.dart';
import 'state/session.dart';
import 'theme.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  // A failing plugin must not keep the app on a blank screen: runApp below has to be reached.
  try {
    await Notifications.init();
  } catch (e) {
    debugPrint('notifications init failed: $e');
  }
  try {
    await Push.init();
  } catch (e) {
    debugPrint('push init failed: $e');
  }
  // Started by the push distributor just to show a notification: no UI needed.
  if (args.contains('--unifiedpush-bg')) return;

  MediaKit.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    systemNavigationBarColor: Palette.surface,
    statusBarIconBrightness: Brightness.light,
  ));
  final session = Session();
  await session.load();
  runApp(ObscuraApp(session: session));
}

final navigatorKey = GlobalKey<NavigatorState>();

/// Lets screens notice when another full screen covers them (e.g. to stop a live stream nobody sees).
/// Page routes only: dialogs and bottom sheets leave the screen visible and must not interrupt it.
final routeObserver = RouteObserver<PageRoute<dynamic>>();

class ObscuraApp extends StatefulWidget {
  const ObscuraApp({super.key, required this.session});

  final Session session;

  @override
  State<ObscuraApp> createState() => _ObscuraAppState();
}

class _ObscuraAppState extends State<ObscuraApp> {
  @override
  void initState() {
    super.initState();
    Notifications.tapped.addListener(_openTappedEvent);
    WidgetsBinding.instance.addPostFrameCallback((_) => _openTappedEvent());
  }

  @override
  void dispose() {
    Notifications.tapped.removeListener(_openTappedEvent);
    super.dispose();
  }

  void _openTappedEvent() {
    final id = Notifications.tapped.value;
    if (id == null || !widget.session.paired) return;
    Notifications.tapped.value = null;
    navigatorKey.currentState?.push(MaterialPageRoute(builder: (_) => EventScreen(eventId: id)));
  }

  @override
  Widget build(BuildContext context) {
    return SessionScope(
      session: widget.session,
      child: MaterialApp(
        title: 'Obscura',
        navigatorKey: navigatorKey,
        navigatorObservers: [routeObserver],
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: ListenableBuilder(
          listenable: widget.session,
          builder: (context, _) => widget.session.paired ? const LockGate(child: HomeShell()) : const ConnectScreen(),
        ),
      ),
    );
  }
}
