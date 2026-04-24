import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Detects if text contains LaTeX content based on common LaTeX signals
bool looksLikeLatex(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) return false;

  if (normalized.contains(r'\(') ||
      normalized.contains(r'\)') ||
      normalized.contains(r'\[') ||
      normalized.contains(r'\]') ||
      normalized.contains(r'$$') ||
      RegExp(r'(^|[^\\])\$[^$]+\$').hasMatch(normalized)) {
    return true;
  }

  const latexSignals = <String>[
    '\\frac',
    '\\sqrt',
    '\\left',
    '\\right',
    '\\alpha',
    '\\beta',
    '\\gamma',
    '\\theta',
    '\\pi',
    '\\times',
    '\\cdot',
    '^',
    '_',
  ];

  return latexSignals.any(normalized.contains);
}

/// Strips outer LaTeX delimiters (\( \), $ $, etc.) from text.
/// Math.tex expects raw LaTeX without outer delimiters.
String stripLatexDelimiters(String text) {
  var stripped = text.trim();

  // Strip \( ... \) delimiters
  if (stripped.startsWith('\\(') && stripped.endsWith('\\)')) {
    stripped = stripped.substring(2, stripped.length - 2).trim();
  }
  // Strip $$ ... $$ delimiters
  else if (stripped.startsWith('\$\$') && stripped.endsWith('\$\$')) {
    stripped = stripped.substring(2, stripped.length - 2).trim();
  }
  // Strip \[ ... \] delimiters
  else if (stripped.startsWith('\\[') && stripped.endsWith('\\]')) {
    stripped = stripped.substring(2, stripped.length - 2).trim();
  }
  // Strip $ ... $ delimiters
  else if (stripped.startsWith('\$') && stripped.endsWith('\$')) {
    stripped = stripped.substring(1, stripped.length - 1).trim();
  }

  return stripped;
}

/// Renders text as either LaTeX (if it contains LaTeX signals) or plain text.
/// Automatically strips outer delimiters before rendering.
Widget safeMath(String text, {TextStyle? textStyle}) {
  final normalized = text.trim();
  if (normalized.isEmpty) {
    return Text('', style: textStyle);
  }

  final spans = _buildMixedContentSpans(normalized, textStyle: textStyle);
  if (spans != null) {
    return Text.rich(
      TextSpan(children: spans, style: textStyle),
    );
  }

  if (!looksLikeLatex(normalized)) {
    return Text(normalized, style: textStyle);
  }

  try {
    // Strip outer delimiters before passing to Math.tex
    final cleanedLatex = stripLatexDelimiters(normalized);
    return Math.tex(
      cleanedLatex,
      textStyle: textStyle,
    );
  } catch (_) {
    return Text(normalized, style: textStyle);
  }
}

List<InlineSpan>? _buildMixedContentSpans(String text, {TextStyle? textStyle}) {
  final delimiterRegex = RegExp(r'\\\((.+?)\\\)|\$\$(.+?)\$\$|\$(.+?)\$');
  final matches = delimiterRegex.allMatches(text).toList();

  if (matches.isEmpty) {
    return null;
  }

  final spans = <InlineSpan>[];
  var cursor = 0;

  for (final match in matches) {
    if (match.start > cursor) {
      final plain = text.substring(cursor, match.start);
      if (plain.isNotEmpty) {
        spans.add(TextSpan(text: plain, style: textStyle));
      }
    }

    final rawMath = (match.group(1) ?? match.group(2) ?? match.group(3) ?? '').trim();
    if (rawMath.isNotEmpty) {
      try {
        spans.add(
          WidgetSpan(
            alignment: PlaceholderAlignment.middle,
            child: Math.tex(rawMath, textStyle: textStyle),
          ),
        );
      } catch (_) {
        spans.add(TextSpan(text: match.group(0), style: textStyle));
      }
    } else {
      spans.add(TextSpan(text: match.group(0), style: textStyle));
    }

    cursor = match.end;
  }

  if (cursor < text.length) {
    final tail = text.substring(cursor);
    if (tail.isNotEmpty) {
      spans.add(TextSpan(text: tail, style: textStyle));
    }
  }

  return spans;
}
