import 'dart:convert';

import 'package:webview_all/webview_all.dart';

class FindInPageResult {
  const FindInPageResult({required this.count, required this.current});

  final int count;
  final int current;

  static const empty = FindInPageResult(count: 0, current: 0);
}

class FindInPageService {
  const FindInPageService();

  Future<FindInPageResult> find(WebViewController engine, String query) async {
    if (query.trim().isEmpty) {
      await clear(engine);
      return FindInPageResult.empty;
    }

    final sanitized = jsonEncode(query.trim());
    final script =
        '''
      (() => {
        try {
          if (window.__dartFindCleanup) window.__dartFindCleanup();

          const query = $sanitized.toLowerCase();
          if (!query) return JSON.stringify({ count: 0, current: 0 });

          const marks = [];
          const walker = document.createTreeWalker(
            document.body || document.documentElement,
            NodeFilter.SHOW_TEXT,
            {
              acceptNode: function(node) {
                if (!node || !node.nodeValue) return NodeFilter.FILTER_REJECT;
                const parent = node.parentElement;
                if (!parent) return NodeFilter.FILTER_REJECT;
                const tag = parent.tagName.toLowerCase();
                if (['script', 'style', 'textarea', 'input', 'noscript'].includes(tag)) {
                  return NodeFilter.FILTER_REJECT;
                }
                return node.nodeValue.toLowerCase().includes(query)
                  ? NodeFilter.FILTER_ACCEPT
                  : NodeFilter.FILTER_SKIP;
              }
            }
          );

          const matchedNodes = [];
          while (walker.nextNode()) matchedNodes.push(walker.currentNode);

          for (const textNode of matchedNodes) {
            const parent = textNode.parentNode;
            if (!parent) continue;
            const text = textNode.nodeValue;
            const lower = text.toLowerCase();
            let idx = 0;
            const frag = document.createDocumentFragment();

            while (true) {
              const found = lower.indexOf(query, idx);
              if (found === -1) {
                frag.appendChild(document.createTextNode(text.substring(idx)));
                break;
              }
              if (found > idx) {
                frag.appendChild(document.createTextNode(text.substring(idx, found)));
              }
              const mark = document.createElement('mark');
              mark.className = '__dart_browser_find_mark__';
              mark.style.backgroundColor = '#ffeb3b';
              mark.style.color = '#000000';
              mark.style.borderRadius = '2px';
              mark.style.padding = '1px 2px';
              mark.style.boxShadow = '0 0 2px rgba(0,0,0,0.4)';
              mark.textContent = text.substring(found, found + query.length);
              frag.appendChild(mark);
              marks.push(mark);
              idx = found + query.length;
            }
            parent.replaceChild(frag, textNode);
          }

          window.__dartFindMarks = marks;
          window.__dartFindIndex = marks.length > 0 ? 0 : -1;

          window.__dartFindCleanup = () => {
            const list = window.__dartFindMarks || [];
            for (const m of list) {
              if (m.parentNode) {
                m.parentNode.replaceChild(document.createTextNode(m.textContent), m);
              }
            }
            window.__dartFindMarks = [];
            window.__dartFindIndex = -1;
          };

          if (marks.length > 0) {
            marks[0].style.backgroundColor = '#ff9800';
            marks[0].scrollIntoView({ behavior: 'smooth', block: 'center' });
            return JSON.stringify({ count: marks.length, current: 1 });
          }

          return JSON.stringify({ count: 0, current: 0 });
        } catch (e) {
          return JSON.stringify({ count: 0, current: 0 });
        }
      })();
    ''';

    try {
      final res = await engine.runJavaScriptReturningResult(script);
      Object? decoded = res;
      if (decoded is String) {
        decoded = jsonDecode(decoded);
        if (decoded is String) decoded = jsonDecode(decoded);
      }
      if (decoded is Map) {
        return FindInPageResult(
          count: (decoded['count'] as num?)?.toInt() ?? 0,
          current: (decoded['current'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}
    return FindInPageResult.empty;
  }

  Future<FindInPageResult> step(
    WebViewController engine, {
    required bool forward,
  }) async {
    final script =
        '''
      (() => {
        try {
          const marks = window.__dartFindMarks || [];
          if (!marks.length) return JSON.stringify({ count: 0, current: 0 });

          let idx = window.__dartFindIndex;
          if (idx >= 0 && idx < marks.length) {
            marks[idx].style.backgroundColor = '#ffeb3b';
          }

          if ($forward) {
            idx = (idx + 1) % marks.length;
          } else {
            idx = (idx - 1 + marks.length) % marks.length;
          }

          window.__dartFindIndex = idx;
          marks[idx].style.backgroundColor = '#ff9800';
          marks[idx].scrollIntoView({ behavior: 'smooth', block: 'center' });

          return JSON.stringify({ count: marks.length, current: idx + 1 });
        } catch (_) {
          return JSON.stringify({ count: 0, current: 0 });
        }
      })();
    ''';

    try {
      final res = await engine.runJavaScriptReturningResult(script);
      Object? decoded = res;
      if (decoded is String) {
        decoded = jsonDecode(decoded);
        if (decoded is String) decoded = jsonDecode(decoded);
      }
      if (decoded is Map) {
        return FindInPageResult(
          count: (decoded['count'] as num?)?.toInt() ?? 0,
          current: (decoded['current'] as num?)?.toInt() ?? 0,
        );
      }
    } catch (_) {}
    return FindInPageResult.empty;
  }

  Future<void> clear(WebViewController engine) async {
    try {
      await engine.runJavaScript(
        'if (window.__dartFindCleanup) window.__dartFindCleanup();',
      );
    } catch (_) {}
  }
}
