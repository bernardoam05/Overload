import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../app/providers.dart';
import '../../services/update_checker.dart';

enum PatchNoteKind { added, improved, fixed }

class PatchNoteSection {
  const PatchNoteSection(this.kind, this.items);
  final PatchNoteKind kind;
  final List<String> items;
}

class PatchNote {
  const PatchNote({
    required this.version,
    required this.date,
    required this.title,
    required this.sections,
  });
  final String version;
  final DateTime? date;
  final String title;
  final List<PatchNoteSection> sections;
}

/// Patch notes bundled in `assets/patch_notes.json`, newest first.
class PatchNotes {
  static const asset = 'assets/patch_notes.json';

  /// Settings key holding the last version whose notes were shown.
  static const seenKey = 'seen_patch_notes';

  /// Last release that shipped without patch notes. An existing user with no
  /// [seenKey] gets the notes of everything after it.
  static const baseline = '1.0.2';

  static const _kinds = {
    'new': PatchNoteKind.added,
    'improved': PatchNoteKind.improved,
    'fixed': PatchNoteKind.fixed,
  };

  /// Lenient parsing: malformed entries and sections are skipped.
  static List<PatchNote> parse(String raw) {
    final json = jsonDecode(raw);
    if (json is! List) return const [];
    final notes = <PatchNote>[];
    for (final e in json.whereType<Map>()) {
      final version = e['version'];
      if (version is! String) continue;
      final sections = <PatchNoteSection>[];
      final rawSections = e['sections'];
      if (rawSections is List) {
        for (final s in rawSections.whereType<Map>()) {
          final kind = _kinds[s['type']];
          final items = s['items'];
          if (kind == null || items is! List) continue;
          final texts = items.whereType<String>().toList();
          if (texts.isNotEmpty) sections.add(PatchNoteSection(kind, texts));
        }
      }
      notes.add(
        PatchNote(
          version: version,
          date: e['date'] is String ? DateTime.tryParse(e['date']) : null,
          title: e['title'] is String ? e['title'] as String : '',
          sections: sections,
        ),
      );
    }
    notes.sort(
      (a, b) => UpdateChecker.isNewer(a.version, b.version)
          ? -1
          : UpdateChecker.isNewer(b.version, a.version)
          ? 1
          : 0,
    );
    return notes;
  }

  /// Notes newer than [seen] and not newer than [current], newest first.
  static List<PatchNote> unseen(
    List<PatchNote> notes, {
    required String seen,
    required String current,
  }) => [
    for (final n in notes)
      if (UpdateChecker.isNewer(n.version, seen) &&
          !UpdateChecker.isNewer(n.version, current))
        n,
  ];
}

final patchNotesProvider = FutureProvider<List<PatchNote>>(
  (ref) async =>
      PatchNotes.parse(await rootBundle.loadString(PatchNotes.asset)),
);

/// Notes of the versions installed since the user last saw them.
final unseenPatchNotesProvider = FutureProvider<List<PatchNote>>((ref) async {
  final current = await ref.watch(appVersionProvider.future);
  final notes = await ref.watch(patchNotesProvider.future);
  final seen = await ref
      .read(settingsRepositoryProvider)
      .read(PatchNotes.seenKey);
  return PatchNotes.unseen(
    notes,
    seen: seen ?? PatchNotes.baseline,
    current: current,
  );
}, retry: (_, _) => null);

/// Records the running version as seen, so its notes don't show again.
Future<void> markPatchNotesSeen(WidgetRef ref) async {
  try {
    final current = await ref.read(appVersionProvider.future);
    await ref
        .read(settingsRepositoryProvider)
        .write(PatchNotes.seenKey, current);
  } catch (_) {
    // Without a version there is nothing to record; notes may show again.
  }
}
