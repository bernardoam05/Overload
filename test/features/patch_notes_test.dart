import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:overload/features/settings/patch_notes.dart';

void main() {
  final bundled = PatchNotes.parse(File(PatchNotes.asset).readAsStringSync());

  group('bundled patch notes', () {
    test('have an entry for the pubspec version', () {
      final pubspec = File('pubspec.yaml').readAsStringSync();
      final version = RegExp(
        r'^version:\s*([\d.]+)',
        multiLine: true,
      ).firstMatch(pubspec)!.group(1);
      expect(bundled.first.version, version);
    });

    test('every entry has a title and at least one change', () {
      for (final n in bundled) {
        expect(n.title, isNotEmpty, reason: n.version);
        expect(n.date, isNotNull, reason: n.version);
        expect(n.sections, isNotEmpty, reason: n.version);
      }
    });
  });

  group('PatchNotes.parse', () {
    test('sorts newest first and skips malformed entries', () {
      final notes = PatchNotes.parse('''[
        {"version": "1.0.0", "title": "a", "sections": []},
        {"title": "no version"},
        {"version": "1.10.0", "sections": [
          {"type": "new", "items": ["x"]},
          {"type": "weird", "items": ["y"]},
          {"type": "fixed", "items": []}
        ]},
        {"version": "1.2.0"}
      ]''');
      expect(notes.map((n) => n.version), ['1.10.0', '1.2.0', '1.0.0']);
      expect(notes.first.sections, hasLength(1));
      expect(notes.first.sections.single.kind, PatchNoteKind.added);
    });
  });

  group('PatchNotes.unseen', () {
    final notes = PatchNotes.parse('''[
      {"version": "1.0.2"}, {"version": "1.1.0"},
      {"version": "1.1.1"}, {"version": "1.2.0"}
    ]''');
    List<String> unseen(String seen, String current) => PatchNotes.unseen(
      notes,
      seen: seen,
      current: current,
    ).map((n) => n.version).toList();

    test('shows every version skipped since the last viewing', () {
      expect(unseen('1.0.2', '1.1.1'), ['1.1.1', '1.1.0']);
    });

    test('shows nothing once the current version was seen', () {
      expect(unseen('1.1.1', '1.1.1'), isEmpty);
    });

    test('never shows versions newer than the installed one', () {
      expect(unseen('1.1.0', '1.1.1'), ['1.1.1']);
    });
  });
}
