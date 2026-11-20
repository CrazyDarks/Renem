import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';

import '../state/app_controller.dart';
import 'word_lookup_sheet.dart';

class InteractiveTextReader extends StatefulWidget {
  const InteractiveTextReader({
    super.key,
    required this.text,
    required this.sourceTitle,
    this.textStyle,
  });

  final String text;
  final String sourceTitle;
  final TextStyle? textStyle;

  @override
  State<InteractiveTextReader> createState() => _InteractiveTextReaderState();
}

class _InteractiveTextReaderState extends State<InteractiveTextReader> {
  static final RegExp _tokenRegex = RegExp(
    r"([\p{L}]+(?:['’\-][\p{L}]+)*)|([^\p{L}]+)",
    unicode: true,
  );

  final List<TapGestureRecognizer> _recognizers = [];

  void _disposeRecognizers() {
    for (final r in _recognizers) {
      r.dispose();
    }
    _recognizers.clear();
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _disposeRecognizers();

    final controller = AppScope.of(context);
    final savedSet = controller.savedWordsNormalized;
    final scheme = Theme.of(context).colorScheme;
    final baseStyle = widget.textStyle ??
        Theme.of(context).textTheme.bodyLarge?.copyWith(
              height: 1.65,
              fontSize: 16.5,
            );

    final spans = <InlineSpan>[];
    for (final match in _tokenRegex.allMatches(widget.text)) {
      final word = match.group(1);
      final nonWord = match.group(2);

      if (word != null) {
        final isSaved = savedSet.contains(word.toLowerCase());
        final wordStart = match.start;
        final wordEnd = match.end;
        final recognizer = TapGestureRecognizer()
          ..onTap = () {
            final sentence = _extractSentence(widget.text, wordStart, wordEnd);
            showWordLookupSheet(
              context: context,
              word: word,
              contextSentence: sentence,
              sourceTitle: widget.sourceTitle,
            );
          };
        _recognizers.add(recognizer);

        spans.add(
          TextSpan(
            text: word,
            style: isSaved
                ? baseStyle?.copyWith(
                    backgroundColor:
                        scheme.primaryContainer.withValues(alpha: 0.7),
                    color: scheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  )
                : baseStyle,
            recognizer: recognizer,
          ),
        );
      } else if (nonWord != null) {
        spans.add(TextSpan(text: nonWord, style: baseStyle));
      }
    }

    return Text.rich(TextSpan(children: spans));
  }

  String _extractSentence(String fullText, int start, int end) {
    const terminators = {'.', '!', '?', '\n'};
    var s = start;
    while (s > 0 && !terminators.contains(fullText[s - 1])) {
      s--;
    }
    var e = end;
    while (e < fullText.length && !terminators.contains(fullText[e])) {
      e++;
    }
    if (e < fullText.length && fullText[e] != '\n') {
      e++;
    }
    return fullText.substring(s, e).trim();
  }
}
