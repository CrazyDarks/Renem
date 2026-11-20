import 'dart:convert';

import 'package:http/http.dart' as http;

class WebArticleResult {
  const WebArticleResult({
    required this.url,
    required this.title,
    required this.paragraphs,
  });

  final String url;
  final String title;
  final List<String> paragraphs;

  String get content => paragraphs.join('\n\n');
}

class WebArticleService {
  static const Map<String, String> _browserHeaders = {
    'User-Agent':
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36',
    'Accept':
        'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8',
    'Accept-Language': 'en-US,en;q=0.9,uk;q=0.8',
  };

  /// Normalizes a user-supplied URL and fetches/extracts clean article paragraphs.
  Future<WebArticleResult> fetchArticle(String rawUrl) async {
    var trimmed = rawUrl.trim();
    if (trimmed.isEmpty) {
      throw const FormatException('Введіть посилання на статтю (URL).');
    }
    if (!trimmed.startsWith('http://') && !trimmed.startsWith('https://')) {
      trimmed = 'https://$trimmed';
    }
    final uri = Uri.tryParse(trimmed);
    if (uri == null || !uri.hasAuthority || uri.host.isEmpty) {
      throw const FormatException('Некоректне посилання (URL).');
    }

    final response = await http
        .get(uri, headers: _browserHeaders)
        .timeout(const Duration(seconds: 18));

    if (response.statusCode < 200 || response.statusCode >= 400) {
      throw FormatException(
        'Не вдалося завантажити сторінку (HTTP ${response.statusCode}).',
      );
    }

    final html = utf8.decode(response.bodyBytes, allowMalformed: true);
    return parseHtmlArticle(html, fallbackUrl: uri.toString());
  }

  /// Parses raw HTML, removes scripts/styles/nav/header/footer/aside/ads/banners,
  /// and extracts a clean title and readable article paragraphs.
  static WebArticleResult parseHtmlArticle(
    String html, {
    String fallbackUrl = '',
  }) {
    final fallbackHost = Uri.tryParse(fallbackUrl)?.host ?? 'Web Article';
    final title = _extractTitle(html, fallbackHost);

    // 1. Strip HTML comments and non-content blocks (<script>, <style>, <nav>, <header>, <footer>, <aside>, etc.)
    var cleaned = html.replaceAll(
      RegExp(r'<!--[\s\S]*?-->', multiLine: true),
      ' ',
    );

    const junkTags = [
      'script',
      'style',
      'noscript',
      'nav',
      'header',
      'footer',
      'aside',
      'form',
      'svg',
      'iframe',
      'canvas',
      'button',
      'select',
      'option',
      'menu',
      'dialog',
    ];
    for (final tag in junkTags) {
      cleaned = cleaned.replaceAll(
        RegExp(
          '<$tag\\b[^>]*>[\\s\\S]*?</$tag>',
          caseSensitive: false,
          multiLine: true,
        ),
        ' ',
      );
    }

    // 2. Remove common ad / banner / cookie / sidebar / menu containers
    cleaned = cleaned.replaceAll(
      RegExp(
        r'<(div|section|ul)\b[^>]*(?:class|id|role)\s*=\s*["\x27][^"\x27]*\b(?:ad|ads|advert|advertisement|banner|cookie|consent|popup|modal|sidebar|navigation|navbar|menu|footer|header|share|social|comment|comments|related|newsletter|promo|sponsor|widget|breadcrumb)s?\b[^"\x27]*["\x27][^>]*>[\s\S]*?</\1>',
        caseSensitive: false,
        multiLine: true,
      ),
      ' ',
    );

    // 3. Prefer <article> or <main> content if available and substantial
    String scopeHtml = cleaned;
    final articleMatch = RegExp(
      r'<article\b[^>]*>([\s\S]*?)</article>',
      caseSensitive: false,
      multiLine: true,
    ).allMatches(cleaned);
    if (articleMatch.isNotEmpty) {
      final combinedArticles =
          articleMatch.map((m) => m.group(1) ?? '').join('\n');
      if (_stripAllTags(combinedArticles).length >= 160) {
        scopeHtml = combinedArticles;
      }
    } else {
      final mainMatch = RegExp(
        r'<main\b[^>]*>([\s\S]*?)</main>',
        caseSensitive: false,
        multiLine: true,
      ).firstMatch(cleaned);
      if (mainMatch != null) {
        final mainContent = mainMatch.group(1) ?? '';
        if (_stripAllTags(mainContent).length >= 160) {
          scopeHtml = mainContent;
        }
      }
    }

    // 4. Extract paragraphs from <p>, <h2>, <h3>, <blockquote>, <li>
    final paragraphs = <String>[];
    final seen = <String>{};

    final blockMatches = RegExp(
      r'<(p|h1|h2|h3|h4|blockquote|li)\b[^>]*>([\s\S]*?)</\1>',
      caseSensitive: false,
      multiLine: true,
    ).allMatches(scopeHtml);

    for (final match in blockMatches) {
      final tag = (match.group(1) ?? 'p').toLowerCase();
      final inner = match.group(2) ?? '';
      final text = _decodeAndCleanText(inner);
      if (text.isEmpty) continue;
      if (_isJunkLine(text)) continue;

      // Filter out tiny menu/list fragments unless it's a heading
      final isHeading = tag.startsWith('h');
      if (!isHeading && tag == 'li' && text.length < 35) continue;
      if (!isHeading && text.length < 22 && !text.contains('.')) continue;

      final normKey = text.toLowerCase();
      if (seen.add(normKey)) {
        paragraphs.add(text);
      }
    }

    // 5. Fallback: if the page didn't use <p> tags (e.g. <br> or <div> text blocks)
    if (paragraphs.isEmpty) {
      final withBreaks = scopeHtml.replaceAll(
        RegExp(
          r'</?(?:p|div|br|section|article|tr|li|h[1-6])\b[^>]*>',
          caseSensitive: false,
        ),
        '\n',
      );
      for (final rawLine in withBreaks.split(RegExp(r'\n+'))) {
        final text = _decodeAndCleanText(rawLine);
        if (text.length < 25 || _isJunkLine(text)) continue;
        final normKey = text.toLowerCase();
        if (seen.add(normKey)) {
          paragraphs.add(text);
        }
      }
    }

    if (paragraphs.isEmpty) {
      throw const FormatException(
        'На сторінці не знайдено текстових абзаців статті.',
      );
    }

    return WebArticleResult(
      url: fallbackUrl,
      title: title,
      paragraphs: paragraphs,
    );
  }

  static String _extractTitle(String html, String fallback) {
    // 1. Check og:title meta tag
    final ogMatch = RegExp(
      r'<meta\b[^>]+property\s*=\s*["\x27]og:title["\x27][^>]+content\s*=\s*["\x27]([^"\x27]+)["\x27]',
      caseSensitive: false,
    ).firstMatch(html);
    if (ogMatch != null) {
      final ogTitle = _decodeAndCleanText(ogMatch.group(1) ?? '');
      if (ogTitle.isNotEmpty) return ogTitle;
    }

    // 2. Check first <h1>
    final h1Match = RegExp(
      r'<h1\b[^>]*>([\s\S]*?)</h1>',
      caseSensitive: false,
    ).firstMatch(html);
    if (h1Match != null) {
      final h1Title = _decodeAndCleanText(h1Match.group(1) ?? '');
      if (h1Title.length >= 3 && h1Title.length <= 160) return h1Title;
    }

    // 3. Check <title>
    final titleMatch = RegExp(
      r'<title\b[^>]*>([\s\S]*?)</title>',
      caseSensitive: false,
    ).firstMatch(html);
    if (titleMatch != null) {
      final rawTitle = _decodeAndCleanText(titleMatch.group(1) ?? '');
      if (rawTitle.isNotEmpty) return rawTitle;
    }

    return fallback;
  }

  static bool _isJunkLine(String text) {
    final lower = text.toLowerCase();
    const junkPhrases = [
      'all rights reserved',
      'privacy policy',
      'terms of service',
      'cookie policy',
      'accept cookies',
      'use cookies',
      'skip to content',
      'skip to main content',
      'sign up for our newsletter',
      'subscribe to our newsletter',
      'advertisement',
    ];
    for (final phrase in junkPhrases) {
      if (lower == phrase ||
          (lower.contains(phrase) && text.length < 95)) {
        return true;
      }
    }
    return false;
  }

  static String _stripAllTags(String html) {
    return html.replaceAll(RegExp(r'<[^>]*>'), ' ').trim();
  }

  static String _decodeAndCleanText(String raw) {
    if (raw.isEmpty) return '';
    var text = raw.replaceAll(
      RegExp(r'<br\s*/?>', caseSensitive: false),
      ' ',
    );
    text = text.replaceAll(RegExp(r'<[^>]*>'), ' ');
    text = text
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .replaceAll('&#x27;', "'")
        .replaceAll('&apos;', "'")
        .replaceAll('&lt;', '<')
        .replaceAll('&gt;', '>')
        .replaceAll('&mdash;', '—')
        .replaceAll('&ndash;', '–')
        .replaceAll('&hellip;', '…')
        .replaceAll('&laquo;', '«')
        .replaceAll('&raquo;', '»')
        .replaceAll('&rsquo;', '’')
        .replaceAll('&lsquo;', '‘')
        .replaceAll('&rdquo;', '”')
        .replaceAll('&ldquo;', '“');

    // Numeric HTML entities (decimal &#123; and hex &#x1A;)
    text = text.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
      final code = int.tryParse(m.group(1) ?? '');
      return code != null ? String.fromCharCode(code) : '';
    });
    text = text.replaceAllMapped(
      RegExp(r'&#x([0-9a-fA-F]+);'),
      (m) {
        final code = int.tryParse(m.group(1) ?? '', radix: 16);
        return code != null ? String.fromCharCode(code) : '';
      },
    );

    return text.replaceAll(RegExp(r'\s+'), ' ').trim();
  }
}
