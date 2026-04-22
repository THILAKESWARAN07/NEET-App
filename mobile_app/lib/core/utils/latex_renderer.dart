import 'package:flutter/material.dart';
import 'package:flutter_math_fork/flutter_math.dart';

/// Detects if text contains LaTeX content based on common LaTeX signals
bool looksLikeLatex(String text) {
  final normalized = text.trim();
  if (normalized.isEmpty) return false;

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
  // Strip $ ... $ delimiters
  else if (stripped.startsWith('\$') && stripped.endsWith('\$')) {
    stripped = stripped.substring(1, stripped.length - 1).trim();
  }
  // Strip $$ ... $$ delimiters
  else if (stripped.startsWith('\$\$') && stripped.endsWith('\$\$')) {
    stripped = stripped.substring(2, stripped.length - 2).trim();
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
