import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../api/models.dart';
import '../widgets/common.dart';
import 'home_screen.dart';
import 'home_shell.dart';

class EventsScreen extends StatefulWidget {
  const EventsScreen({super.key});

  @override
  State<EventsScreen> createState() => _EventsScreenState();
}

class _EventsScreenState extends State<EventsScreen> {
  final List<HubEvent> _events = [];
  String? _kind;
  bool _loading = false;
  bool _end = false;
  int _generation = 0; // ignores pages from a request made before a filter change
  Object? _error;
  final _scroll = ScrollController();

  static const _page = 40;

  @override
  void initState() {
    super.initState();
    _reload();
    eventsVersion.addListener(_reload);
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 400) _more();
    });
  }

  @override
  void dispose() {
    eventsVersion.removeListener(_reload);
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _reload() async {
    _generation++;
    _events.clear();
    _end = false;
    await _more(force: true);
  }

  Future<void> _more({bool force = false}) async {
    if ((_loading && !force) || _end) return;
    final generation = _generation;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final page = await context.hub.events(
        kind: _kind,
        before: _events.isEmpty ? null : _events.last.startedAt,
        limit: _page,
      );
      if (!mounted || generation != _generation) return;
      setState(() {
        _events.addAll(page);
        _end = page.length < _page;
      });
    } catch (e) {
      if (mounted) setState(() => _error = e);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deleteAll() async {
    final l = context.l;
    if (!await confirm(context, title: l.deleteAllEvents, body: l.deleteAllEventsBody, action: l.delete)) return;
    if (!mounted) return;
    try {
      await context.hub.deleteAllEvents();
      eventsVersion.value++;
    } catch (e) {
      if (mounted) showError(context, e);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l = context.l;
    final locale = Localizations.localeOf(context).toLanguageTag();
    // Flatten into day headers + rows so the list stays lazily built.
    final rows = <Object>[];
    DateTime? day;
    for (final e in _events) {
      final d = DateTime(e.startedAt.year, e.startedAt.month, e.startedAt.day);
      if (d != day) rows.add(day = d);
      rows.add(e);
    }
    return SafeArea(
      child: Column(children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Row(children: [
            Expanded(child: Text(l.tabEvents, style: Theme.of(context).textTheme.headlineMedium)),
            if (_events.isNotEmpty)
              IconButton(
                tooltip: l.deleteAllEvents,
                icon: const Icon(Icons.delete_sweep_outlined),
                onPressed: _deleteAll,
              ),
          ]),
        ),
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(children: [
            for (final (k, label) in [(null, l.filterAllPlain), ('person', l.kindPerson), ('motion', l.kindMotion), ('manual', l.kindManual)])
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  avatar: k == null ? null : KindIcon(k, size: 16),
                  label: Text(label),
                  selected: _kind == k,
                  onSelected: (_) {
                    setState(() => _kind = k);
                    _reload();
                  },
                ),
              ),
          ]),
        ),
        Expanded(
          child: _error != null && _events.isEmpty
              ? ErrorState(error: _error!, onRetry: _reload)
              : _events.isEmpty && !_loading
                  ? EmptyState(icon: Icons.notifications_none, title: l.noEventsYet, body: l.noEventsBody)
                  : RefreshIndicator(
                      onRefresh: _reload,
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                        itemCount: rows.length + 1,
                        itemBuilder: (context, i) {
                          if (i == rows.length) {
                            return _loading
                                ? const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
                                : const SizedBox(height: 24);
                          }
                          final row = rows[i];
                          if (row is DateTime) {
                            return SectionLabel(DateFormat.yMMMMEEEEd(locale).format(row));
                          }
                          return Padding(
                            padding: const EdgeInsets.only(bottom: 6),
                            child: Panel(padding: EdgeInsets.zero, child: EventTile(event: row as HubEvent)),
                          );
                        },
                      ),
                    ),
        ),
      ]),
    );
  }
}
