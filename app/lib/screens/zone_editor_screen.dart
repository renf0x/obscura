import 'dart:math';
import 'dart:typed_data';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../api/models.dart';
import '../theme.dart';
import '../widgets/common.dart';

/// Draw detection zones over a live snapshot. Each zone can trigger on motion, people, or both.
/// Everything can be done with buttons (add rectangle, add point, undo) — dragging is optional.
class ZoneEditorScreen extends StatefulWidget {
  const ZoneEditorScreen({super.key, required this.cameraId});

  final int cameraId;

  @override
  State<ZoneEditorScreen> createState() => _ZoneEditorScreenState();
}

class _ZoneEditorScreenState extends State<ZoneEditorScreen> {
  CameraConfig? _cfg;
  List<Zone> _zones = [];
  Uint8List? _snapshot;
  double _aspect = 16 / 9;
  int? _selected;
  bool _addPoints = false;
  int? _dragVertex;
  bool _dirty = false;
  bool _saving = false;
  Object? _error;

  static const _maxZones = 16;
  static const _maxPoints = 32;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final hub = context.hub;
    try {
      final cam = await hub.camera(widget.cameraId);
      if (!mounted) return;
      setState(() {
        _cfg = cam.config;
        _zones = [for (final z in cam.config.zones) z.copy()];
        _selected = _zones.isEmpty ? null : 0;
      });
      final shot = await hub.snapshot(widget.cameraId);
      final image = await decodeImageFromList(shot);
      if (mounted) {
        setState(() {
          _snapshot = shot;
          _aspect = image.width / image.height;
        });
      }
    } catch (e) {
      // A missing snapshot is fine (camera offline); zones can still be edited on a blank frame.
      if (mounted && _cfg == null) setState(() => _error = e);
    }
  }

  void _change(VoidCallback fn) => setState(() {
        fn();
        _dirty = true;
      });

  void _addZone() {
    if (_zones.length >= _maxZones) return;
    final n = _zones.length + 1;
    _change(() {
      _zones.add(Zone(
        id: 'z${DateTime.now().millisecondsSinceEpoch}',
        name: '${context.l.zone} $n',
        points: [[0.3, 0.3], [0.7, 0.3], [0.7, 0.7], [0.3, 0.7]],
      ));
      _selected = _zones.length - 1;
    });
  }

  Future<void> _rename(Zone z) async {
    final ctrl = TextEditingController(text: z.name);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: Palette.surfaceHigh,
        title: Text(context.l.zoneName),
        content: TextField(controller: ctrl, maxLength: 40, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(context.l.cancel)),
          FilledButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: Text(context.l.save)),
        ],
      ),
    );
    ctrl.dispose();
    if (name != null && name.isNotEmpty) _change(() => z.name = name);
  }

  Future<void> _save() async {
    final cfg = _cfg!;
    cfg.zones = _zones;
    setState(() => _saving = true);
    try {
      await context.hub.patchCamera(widget.cameraId, config: cfg);
      if (!mounted) return;
      setState(() => _dirty = false);
      showMessage(context, context.l.saved);
      Navigator.pop(context);
    } catch (e) {
      if (mounted) showError(context, e);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // --- gestures on the frame --------------------------------------------------
  Offset _norm(Offset p, Size s) => Offset((p.dx / s.width).clamp(0, 1), (p.dy / s.height).clamp(0, 1));

  void _onTap(Offset pos, Size size) {
    final n = _norm(pos, size);
    if (_addPoints && _selected != null) {
      final z = _zones[_selected!];
      if (z.points.length < _maxPoints) _change(() => z.points.add([n.dx, n.dy]));
      return;
    }
    // Otherwise select the zone under the finger.
    for (var i = _zones.length - 1; i >= 0; i--) {
      if (_contains(_zones[i].points, n)) {
        setState(() => _selected = i);
        return;
      }
    }
  }

  bool _contains(List<List<double>> pts, Offset p) {
    var inside = false;
    for (var i = 0, j = pts.length - 1; i < pts.length; j = i++) {
      final (xi, yi, xj, yj) = (pts[i][0], pts[i][1], pts[j][0], pts[j][1]);
      if ((yi > p.dy) != (yj > p.dy) && p.dx < (xj - xi) * (p.dy - yi) / (yj - yi) + xi) inside = !inside;
    }
    return inside;
  }

  /// Index of the vertex under the finger, or null when the touch lands elsewhere.
  int? _vertexAt(Offset pos, Size size) {
    if (_selected == null) return null;
    final pts = _zones[_selected!].points;
    var best = 32.0; // px: generous touch target around each vertex
    int? found;
    for (var i = 0; i < pts.length; i++) {
      final d = (Offset(pts[i][0] * size.width, pts[i][1] * size.height) - pos).distance;
      if (d < best) {
        best = d;
        found = i;
      }
    }
    return found;
  }

  void _onPanUpdate(Offset pos, Size size) {
    if (_selected == null || _dragVertex == null) return;
    final n = _norm(pos, size);
    _change(() => _zones[_selected!].points[_dragVertex!] = [n.dx, n.dy]);
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final sel = _selected == null ? null : _zones[_selected!];
    return PopScope(
      canPop: !_dirty,
      onPopInvokedWithResult: (didPop, _) async {
        if (didPop) return;
        if (await confirm(context, title: l.unsavedTitle, body: l.unsavedBody, action: l.discard) && context.mounted) {
          setState(() => _dirty = false);
          Navigator.pop(context);
        }
      },
      child: Scaffold(
        appBar: AppBar(title: Text(l.triggerZones)),
        bottomNavigationBar: _cfg == null
            ? null
            : SafeArea(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                  child: FilledButton(
                    onPressed: _dirty && !_saving ? _save : null,
                    child: Text(_dirty ? l.saveChanges : l.saved),
                  ),
                ),
              ),
        body: _error != null
            ? ErrorState(error: _error!, onRetry: _load)
            : _cfg == null
                ? const Center(child: CircularProgressIndicator())
                : ListView(padding: const EdgeInsets.all(16), children: [
                    Text(l.zonesHint, style: const TextStyle(color: Palette.muted, fontSize: 13)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: AspectRatio(
                        aspectRatio: _aspect,
                        child: LayoutBuilder(builder: (context, box) {
                          final size = box.biggest;
                          return RawGestureDetector(
                            // A plain pan loses the gesture to the surrounding list: dragging a point
                            // scrolled the page instead. This recognizer claims the touch as soon as a
                            // finger lands on a point, and leaves every other touch to the list.
                            gestures: {
                              _VertexDragRecognizer:
                                  GestureRecognizerFactoryWithHandlers<_VertexDragRecognizer>(
                                () => _VertexDragRecognizer(),
                                (r) {
                                  r.vertexAt = (p) => _vertexAt(p, size);
                                  r.onStart = (i) => _dragVertex = i;
                                  r.onUpdate = (p) => _onPanUpdate(p, size);
                                  r.onEnd = () => _dragVertex = null;
                                },
                              ),
                            },
                            child: GestureDetector(
                              onTapUp: (d) => _onTap(d.localPosition, size),
                              child: Stack(fit: StackFit.expand, children: [
                                if (_snapshot != null)
                                  Image.memory(_snapshot!, fit: BoxFit.fill, gaplessPlayback: true)
                                else
                                  const ColoredBox(color: Palette.surfaceHigh),
                                CustomPaint(painter: _ZonePainter(_zones, _selected)),
                              ]),
                            ),
                          );
                        }),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(spacing: 12, runSpacing: 4, children: [
                      _Legend(color: Palette.accent, label: l.legendBoth),
                      _Legend(color: const Color(0xFF4FC3F7), label: l.legendMotion),
                      _Legend(color: Palette.danger, label: l.legendPerson),
                    ]),
                    const SizedBox(height: 12),
                    Row(children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _zones.length < _maxZones ? _addZone : null,
                          icon: const Icon(Icons.add),
                          label: Text(l.addZone),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: sel == null ? null : () => setState(() => _addPoints = !_addPoints),
                          style: _addPoints ? OutlinedButton.styleFrom(backgroundColor: Palette.accent.withValues(alpha: 0.15)) : null,
                          icon: Icon(_addPoints ? Icons.check : Icons.add_location_alt_outlined),
                          label: Text(_addPoints ? l.doneAddingPoints : l.addPoints),
                        ),
                      ),
                    ]),
                    if (sel != null && sel.points.length > 3)
                      TextButton.icon(
                        onPressed: () => _change(() => sel.points.removeLast()),
                        icon: const Icon(Icons.undo),
                        label: Text(l.undoPoint),
                      ),
                    if (_zones.isEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 16),
                        child: Panel(child: Text(l.zonesNone, style: const TextStyle(color: Palette.muted))),
                      ),
                    for (final (i, z) in _zones.indexed)
                      Padding(
                        padding: const EdgeInsets.only(top: 10),
                        child: Panel(
                          highlight: i == _selected ? Palette.accent : null,
                          onTap: () => setState(() => _selected = i),
                          padding: const EdgeInsets.fromLTRB(14, 8, 4, 10),
                          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                            Row(children: [
                              Expanded(
                                child: Text(z.name, maxLines: 1, overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(fontWeight: FontWeight.w500)),
                              ),
                              IconButton(tooltip: l.rename, icon: const Icon(Icons.edit_outlined, size: 20), onPressed: () => _rename(z)),
                              IconButton(
                                tooltip: l.delete,
                                icon: const Icon(Icons.delete_outline, size: 20, color: Palette.danger),
                                onPressed: () async {
                                  if (!await confirm(context, title: l.deleteZoneTitle(z.name), body: l.deleteZoneBody, action: l.delete)) {
                                    return;
                                  }
                                  _change(() {
                                    _zones.removeAt(i);
                                    _selected = _zones.isEmpty ? null : 0;
                                    _addPoints = false;
                                  });
                                },
                              ),
                            ]),
                            Wrap(spacing: 8, children: [
                              FilterChip(
                                avatar: const Icon(Icons.motion_photos_on_outlined, size: 16),
                                label: Text(l.kindMotion),
                                selected: z.motion,
                                onSelected: (v) => _change(() => z.motion = v),
                              ),
                              FilterChip(
                                avatar: const Icon(Icons.directions_walk, size: 16),
                                label: Text(l.kindPerson),
                                selected: z.person,
                                onSelected: (v) => _change(() => z.person = v),
                              ),
                            ]),
                            if (!z.motion && !z.person)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(l.zoneInactive, style: const TextStyle(color: Palette.warning, fontSize: 12)),
                              ),
                          ]),
                        ),
                      ),
                  ]),
      ),
    );
  }
}

class _Legend extends StatelessWidget {
  const _Legend({required this.color, required this.label});

  final Color color;
  final String label;

  @override
  Widget build(BuildContext context) => Row(mainAxisSize: MainAxisSize.min, children: [
        Container(width: 12, height: 12, decoration: BoxDecoration(color: color.withValues(alpha: 0.4), border: Border.all(color: color))),
        const SizedBox(width: 6),
        Text(label, style: const TextStyle(fontSize: 12, color: Palette.muted)),
      ]);
}

class _ZonePainter extends CustomPainter {
  _ZonePainter(this.zones, this.selected);

  final List<Zone> zones;
  final int? selected;

  static Color colorFor(Zone z) => z.motion && z.person
      ? Palette.accent
      : z.person
          ? Palette.danger
          : z.motion
              ? const Color(0xFF4FC3F7)
              : Palette.muted;

  @override
  void paint(Canvas canvas, Size size) {
    for (final (i, z) in zones.indexed) {
      if (z.points.length < 2) continue;
      final color = colorFor(z);
      final pts = [for (final p in z.points) Offset(p[0] * size.width, p[1] * size.height)];
      final path = Path()..addPolygon(pts, true);
      canvas.drawPath(path, Paint()..color = color.withValues(alpha: i == selected ? 0.28 : 0.16));
      canvas.drawPath(
        path,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = i == selected ? 2.5 : 1.5,
      );
      if (i == selected) {
        for (final p in pts) {
          canvas.drawCircle(p, 9, Paint()..color = Palette.bg.withValues(alpha: 0.7));
          canvas.drawCircle(p, 7, Paint()..color = color);
        }
      }
      final c = pts.reduce((a, b) => a + b) / pts.length.toDouble();
      final tp = TextPainter(
        text: TextSpan(text: z.name, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600,
            shadows: const [Shadow(blurRadius: 3)])),
        textDirection: TextDirection.ltr,
      )..layout(maxWidth: max(40, size.width / 3));
      tp.paint(canvas, c - Offset(tp.width / 2, tp.height / 2));
    }
  }

  @override
  bool shouldRepaint(covariant _ZonePainter old) => true;
}

/// Drags a zone point out of a scrolling list. A [PanGestureRecognizer] needs more travel than the
/// list's vertical drag, so the list used to win and the page scrolled instead of the point moving.
/// This one takes the touch the moment it lands on a point, and ignores every other touch.
class _VertexDragRecognizer extends OneSequenceGestureRecognizer {
  late int? Function(Offset local) vertexAt;
  late void Function(int index) onStart;
  late void Function(Offset local) onUpdate;
  late VoidCallback onEnd;

  int? _pointer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    if (_pointer != null) return; // already dragging a point with another finger
    final index = vertexAt(event.localPosition);
    if (index == null) return; // not on a point: let the list scroll
    _pointer = event.pointer;
    startTrackingPointer(event.pointer, event.transform);
    resolve(GestureDisposition.accepted);
    onStart(index);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event.pointer != _pointer) return;
    if (event is PointerMoveEvent) {
      onUpdate(event.localPosition);
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _pointer = null;
    onEnd();
  }

  @override
  String get debugDescription => 'zone vertex drag';
}
