import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/hub_client.dart';
import '../l10n/app_localizations.dart';
import '../state/session.dart';
import '../theme.dart';

extension ContextX on BuildContext {
  AppLocalizations get l => AppLocalizations.of(this)!;
  HubClient get hub => SessionScope.read(this).client!;
  bool get reduceMotion => MediaQuery.of(this).disableAnimations;
}

/// Small spaced-out caps label ("LIVE OVERVIEW" in the mockup).
class SectionLabel extends StatelessWidget {
  const SectionLabel(this.text, {super.key, this.trailing});

  final String text;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 20, 4, 8),
      child: Row(children: [
        Expanded(
          child: Semantics(
            header: true,
            child: Text(text.toUpperCase(),
                style: const TextStyle(fontSize: 11, letterSpacing: 2.2, color: Palette.muted, fontWeight: FontWeight.w600)),
          ),
        ),
        ?trailing,
      ]),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.onTap, this.highlight});

  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final Color? highlight;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Palette.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: BorderSide(color: highlight ?? Palette.border),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: Padding(padding: padding, child: child)),
    );
  }
}

class StatusDot extends StatelessWidget {
  const StatusDot({super.key, required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(color: color, shape: BoxShape.circle, boxShadow: [
          BoxShadow(color: color.withValues(alpha: 0.6), blurRadius: 6),
        ]),
      ),
      const SizedBox(width: 6),
      Text(label, style: TextStyle(color: color, fontSize: 12)),
    ]);
  }
}

/// Image fetched with the device token in a header (never in the URL).
class AuthImage extends StatelessWidget {
  const AuthImage(this.url, {super.key, this.fit = BoxFit.cover, this.semanticLabel});

  final Uri url;
  final BoxFit fit;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    // Decode at the on-screen size, not the camera's full resolution: less memory and CPU per thumbnail.
    return LayoutBuilder(builder: (context, box) => _image(context, box.maxWidth));
  }

  Widget _image(BuildContext context, double width) {
    final px = width.isFinite ? (width * MediaQuery.devicePixelRatioOf(context)).round() : null;
    return Image.network(
      url.toString(),
      headers: context.hub.authHeaders,
      cacheWidth: px,
      fit: fit,
      semanticLabel: semanticLabel,
      gaplessPlayback: true,
      errorBuilder: (_, _, _) => const ColoredBox(
        color: Palette.surfaceHigh,
        child: Center(child: Icon(Icons.videocam_off_outlined, color: Palette.muted)),
      ),
    );
  }
}

class KindIcon extends StatelessWidget {
  const KindIcon(this.kind, {super.key, this.size = 20});

  final String kind;
  final double size;

  static IconData icon(String kind) => switch (kind) {
        'person' => Icons.directions_walk,
        'manual' => Icons.fiber_manual_record,
        _ => Icons.motion_photos_on_outlined,
      };

  static Color color(String kind) => kind == 'person' ? Palette.danger : Palette.accent;

  @override
  Widget build(BuildContext context) => Icon(icon(kind), size: size, color: color(kind));
}

String kindLabel(BuildContext context, String kind) => switch (kind) {
      'person' => context.l.kindPerson,
      'manual' => context.l.kindManual,
      _ => context.l.kindMotion,
    };

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.icon, required this.title, required this.body, this.action});

  final IconData icon;
  final String title;
  final String body;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 48, color: Palette.accentDim),
          const SizedBox(height: 16),
          Text(title, style: Theme.of(context).textTheme.titleMedium, textAlign: TextAlign.center),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(color: Palette.muted), textAlign: TextAlign.center),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ]),
      ),
    );
  }
}

/// Error panel with a retry action; used by every screen that loads from the hub.
class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.error, required this.onRetry});

  final Object error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.portable_wifi_off,
      title: context.l.hubUnreachable,
      body: '${context.l.hubUnreachableHint}\n\n$error',
      action: OutlinedButton.icon(onPressed: onRetry, icon: const Icon(Icons.refresh), label: Text(context.l.retry)),
    );
  }
}

/// List padding that also clears Android's navigation bar: the app draws edge-to-edge, so without it
/// the end of a long page sits under the bar and can't be scrolled into view.
EdgeInsets listPadding(BuildContext context, EdgeInsets base) =>
    base + EdgeInsets.only(bottom: MediaQuery.paddingOf(context).bottom);

void showMessage(BuildContext context, String text) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(text)));
}

void showError(BuildContext context, Object error) {
  final text = error is HubException && error.status == 0 ? context.l.hubUnreachable : '${context.l.error}: $error';
  showMessage(context, text);
}

Future<bool> confirm(BuildContext context,
    {required String title, required String body, required String action, bool destructive = true}) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      backgroundColor: Palette.surfaceHigh,
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(context.l.cancel)),
        FilledButton(
          style: destructive ? FilledButton.styleFrom(backgroundColor: Palette.danger) : null,
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(action),
        ),
      ],
    ),
  );
  return ok ?? false;
}

String formatTime(BuildContext context, DateTime t) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(t.year, t.month, t.day);
  if (day == today) return DateFormat.Hm(locale).format(t);
  if (day == today.subtract(const Duration(days: 1))) return '${context.l.yesterday}, ${DateFormat.Hm(locale).format(t)}';
  return DateFormat.MMMd(locale).add_Hm().format(t);
}

String formatBytes(BuildContext context, int bytes) {
  final f = NumberFormat.decimalPattern(Localizations.localeOf(context).toLanguageTag())..maximumFractionDigits = 1;
  const units = ['B', 'KB', 'MB', 'GB', 'TB'];
  var v = bytes.toDouble();
  var i = 0;
  while (v >= 1024 && i < units.length - 1) {
    v /= 1024;
    i++;
  }
  return '${f.format(v)} ${units[i]}';
}

/// Faint surveillance-grid backdrop behind screens. Static, so nothing to disable for reduced motion.
class GridBackdrop extends StatelessWidget {
  const GridBackdrop({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _GridPainter(), child: child);
}

class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = Palette.accent.withValues(alpha: 0.025)
      ..strokeWidth = 1;
    for (double x = 0; x < size.width; x += 32) {
      canvas.drawLine(Offset(x, 0), Offset(x, size.height), p);
    }
    for (double y = 0; y < size.height; y += 32) {
      canvas.drawLine(Offset(0, y), Offset(size.width, y), p);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
