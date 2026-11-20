import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

import '../models/vocab_word.dart';

class CsvImportResult {
  const CsvImportResult({
    required this.importedWords,
    required this.skippedCount,
    this.cancelled = false,
  });

  final List<VocabWord> importedWords;
  final int skippedCount;
  final bool cancelled;
}

class CsvService {
  static const List<String> _header = [
    'Front',
    'Back',
    'Context',
    'Example',
    'PartOfSpeech',
    'Source',
  ];

  /// Builds an Anki-compatible UTF-8 CSV string (with BOM for spreadsheet tools).
  String serializeToCsv(List<VocabWord> words) {
    final buffer = StringBuffer('\uFEFF');
    buffer.writeln(_header.map(_escapeCsvField).join(','));
    for (final w in words) {
      final row = [
        w.word,
        w.translation,
        w.contextSentence,
        w.exampleSentence,
        w.partOfSpeech,
        w.sourceTitle,
      ];
      buffer.writeln(row.map(_escapeCsvField).join(','));
    }
    return buffer.toString();
  }

  /// Exports vocabulary to a user-chosen CSV file via system FilePicker.
  Future<String?> exportVocabularyToFile(List<VocabWord> words) async {
    final csvText = serializeToCsv(words);
    final bytes = Uint8List.fromList(utf8.encode(csvText));
    final timestamp = DateTime.now()
        .toIso8601String()
        .replaceAll(':', '-')
        .split('.')
        .first;
    final fileName = 'languagema_anki_$timestamp.csv';

    final outputUri = await FilePicker.saveFile(
      dialogTitle: 'Експортувати словник (CSV для Anki)',
      fileName: fileName,
      mimeType: 'text/csv',
      bytes: bytes,
    );
    return outputUri?.toString();
  }

  /// Opens a CSV file (Anki / LanguageMa format) and parses [VocabWord] rows.
  Future<CsvImportResult> importVocabularyFromFile() async {
    final file = await FilePicker.pickFile(
      dialogTitle: 'Імпортувати словник із CSV (Anki)',
      type: FileType.custom,
      allowedExtensions: const ['csv', 'txt', 'tsv'],
    );

    if (file == null) {
      return const CsvImportResult(
        importedWords: [],
        skippedCount: 0,
        cancelled: true,
      );
    }

    final bytes = await file.readAsBytes();
    final content = utf8.decode(bytes, allowMalformed: true);
    return parseCsvContent(content);
  }

  CsvImportResult parseCsvContent(String rawContent) {
    final cleaned = rawContent.startsWith('\uFEFF')
        ? rawContent.substring(1)
        : rawContent;
    final delimiter = _detectDelimiter(cleaned);
    final rows = _parseRows(cleaned, delimiter: delimiter);

    final imported = <VocabWord>[];
    var skipped = 0;
    final now = DateTime.now();

    for (var i = 0; i < rows.length; i++) {
      final row = rows[i];
      if (row.isEmpty || row.every((cell) => cell.trim().isEmpty)) {
        continue;
      }

      // Skip header row if present
      if (i == 0 && _looksLikeHeader(row)) {
        continue;
      }

      final word = row[0].trim();
      final translation = row.length > 1 ? row[1].trim() : '';
      if (word.isEmpty || translation.isEmpty) {
        skipped++;
        continue;
      }

      final context = row.length > 2 ? row[2].trim() : '';
      final example = row.length > 3 ? row[3].trim() : '';
      final partOfSpeech = row.length > 4 ? row[4].trim() : '';
      final source = row.length > 5 ? row[5].trim() : 'CSV Import';

      imported.add(
        VocabWord(
          id: 'csv_${now.microsecondsSinceEpoch}_$i',
          word: word,
          translation: translation,
          contextSentence: context,
          exampleSentence: example,
          partOfSpeech: partOfSpeech,
          sourceTitle: source,
          createdAt: now,
          nextReviewAt: now,
        ),
      );
    }

    return CsvImportResult(importedWords: imported, skippedCount: skipped);
  }

  bool _looksLikeHeader(List<String> row) {
    final first = row[0].trim().toLowerCase();
    final second = row.length > 1 ? row[1].trim().toLowerCase() : '';
    return (first == 'front' || first == 'word' || first == 'слово') &&
        (second == 'back' ||
            second == 'translation' ||
            second == 'переклад' ||
            second.isEmpty);
  }

  String _detectDelimiter(String content) {
    final firstLine = content.split(RegExp(r'\r?\n')).firstWhere(
          (line) => line.trim().isNotEmpty,
          orElse: () => '',
        );
    final tabs = '\t'.allMatches(firstLine).length;
    final semicolons = ';'.allMatches(firstLine).length;
    final commas = ','.allMatches(firstLine).length;

    if (tabs > commas && tabs >= semicolons) return '\t';
    if (semicolons > commas) return ';';
    return ',';
  }

  String _escapeCsvField(String value) {
    final needsQuotes = value.contains(',') ||
        value.contains('"') ||
        value.contains('\n') ||
        value.contains('\r');
    if (!needsQuotes) return value;
    final escaped = value.replaceAll('"', '""');
    return '"$escaped"';
  }

  List<List<String>> _parseRows(String input, {String delimiter = ','}) {
    final rows = <List<String>>[];
    var currentRow = <String>[];
    final currentCell = StringBuffer();
    var inQuotes = false;

    for (var i = 0; i < input.length; i++) {
      final char = input[i];

      if (inQuotes) {
        if (char == '"') {
          final hasNextQuote = i + 1 < input.length && input[i + 1] == '"';
          if (hasNextQuote) {
            currentCell.write('"');
            i++;
          } else {
            inQuotes = false;
          }
        } else {
          currentCell.write(char);
        }
      } else {
        if (char == '"') {
          inQuotes = true;
        } else if (char == delimiter) {
          currentRow.add(currentCell.toString());
          currentCell.clear();
        } else if (char == '\r') {
          // Ignore CR, handle LF or standalone CR
          if (i + 1 >= input.length || input[i + 1] != '\n') {
            currentRow.add(currentCell.toString());
            currentCell.clear();
            rows.add(currentRow);
            currentRow = <String>[];
          }
        } else if (char == '\n') {
          currentRow.add(currentCell.toString());
          currentCell.clear();
          rows.add(currentRow);
          currentRow = <String>[];
        } else {
          currentCell.write(char);
        }
      }
    }

    if (currentCell.isNotEmpty || currentRow.isNotEmpty) {
      currentRow.add(currentCell.toString());
      rows.add(currentRow);
    }

    return rows;
  }
}
