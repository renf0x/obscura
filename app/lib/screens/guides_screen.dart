import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../guides/guide_model.dart';
import '../guides/guides_en.dart';
import '../guides/guides_ru.dart';
import '../theme.dart';
import '../widgets/common.dart';

List<Guide> guidesFor(BuildContext context) =>
    Localizations.localeOf(context).languageCode == 'ru' ? guidesRu : guidesEn;

/// Step-by-step setup instructions, available before pairing too.
class GuidesScreen extends StatefulWidget {
  const GuidesScreen({super.key, this.open});

  /// Guide id to jump into directly (e.g. 'tapo', 'cloud').
  final String? open;

  @override
  State<GuidesScreen> createState() => _GuidesScreenState();
}

class _GuidesScreenState extends State<GuidesScreen> {
  @override
  void initState() {
    super.initState();
    if (widget.open != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        final g = guidesFor(context).where((g) => g.id == widget.open).firstOrNull;
        if (g != null) Navigator.push(context, MaterialPageRoute(builder: (_) => GuideScreen(guide: g)));
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final guides = guidesFor(context);
    return Scaffold(
      appBar: AppBar(title: Text(context.l.guides)),
      body: ListView.separated(
        padding: listPadding(context, const EdgeInsets.all(16)),
        itemCount: guides.length,
        separatorBuilder: (_, _) => const SizedBox(height: 10),
        itemBuilder: (context, i) {
          final g = guides[i];
          return Panel(
            onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GuideScreen(guide: g))),
            child: Row(children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Palette.accentDim),
                ),
                child: Icon(g.icon, color: Palette.accent),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('${(i + 1).toString().padLeft(2, '0')}  ${g.title}',
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  const SizedBox(height: 2),
                  Text(g.summary, style: const TextStyle(color: Palette.muted, fontSize: 13)),
                ]),
              ),
              const Icon(Icons.chevron_right, color: Palette.muted),
            ]),
          );
        },
      ),
    );
  }
}

class GuideScreen extends StatelessWidget {
  const GuideScreen({super.key, required this.guide});

  final Guide guide;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(guide.title)),
      body: ListView.builder(
        padding: listPadding(context, const EdgeInsets.fromLTRB(16, 8, 16, 32)),
        itemCount: guide.steps.length,
        itemBuilder: (context, i) => _StepCard(step: guide.steps[i]),
      ),
    );
  }
}

class _StepCard extends StatelessWidget {
  const _StepCard({required this.step});

  final GuideStep step;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Semantics(
            header: true,
            child: Text(step.title, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Palette.accent)),
          ),
          const SizedBox(height: 8),
          SelectableText(step.body, style: const TextStyle(height: 1.45)),
          if (step.table != null) ...[const SizedBox(height: 12), _Table(rows: step.table!)],
          if (step.code != null) ...[const SizedBox(height: 12), _CodeBlock(code: step.code!)],
          if (step.warning != null) ...[
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Palette.warning.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: Palette.warning.withValues(alpha: 0.4)),
              ),
              child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Icon(Icons.warning_amber, color: Palette.warning, size: 20),
                const SizedBox(width: 10),
                Expanded(child: Text(step.warning!, style: const TextStyle(fontSize: 13))),
              ]),
            ),
          ],
        ]),
      ),
    );
  }
}

class _CodeBlock extends StatelessWidget {
  const _CodeBlock({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: const Color(0xFF030605),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Palette.border),
      ),
      child: Stack(children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(12, 12, 52, 12),
          child: SelectableText(code,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 13, height: 1.5, color: Palette.accent)),
        ),
        Positioned(
          right: 0,
          top: 0,
          child: IconButton(
            tooltip: context.l.copy,
            icon: const Icon(Icons.copy, size: 18, color: Palette.muted),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: code));
              showMessage(context, context.l.copied);
            },
          ),
        ),
      ]),
    );
  }
}

class _Table extends StatelessWidget {
  const _Table({required this.rows});

  final List<List<String>> rows;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: Palette.border),
        children: [
          for (final (i, row) in rows.indexed)
            TableRow(
              decoration: BoxDecoration(color: i == 0 ? Palette.surfaceHigh : null),
              children: [
                for (final cell in row)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                    child: Text(cell,
                        style: TextStyle(fontSize: 13, fontWeight: i == 0 ? FontWeight.w600 : FontWeight.w400)),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
