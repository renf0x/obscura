import 'package:flutter/widgets.dart';

class Guide {
  const Guide({required this.id, required this.icon, required this.title, required this.summary, required this.steps});

  final String id;
  final IconData icon;
  final String title;
  final String summary;
  final List<GuideStep> steps;
}

class GuideStep {
  const GuideStep(this.title, this.body, {this.code, this.warning, this.table});

  final String title;
  final String body;
  final String? code; // shown in a copyable monospace block
  final String? warning;
  final List<List<String>>? table; // first row = header
}
