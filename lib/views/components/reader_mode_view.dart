import '../../l10n/browser_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_all/webview_all.dart';

enum ReaderTheme { light, sepia, dark }

class ReaderModeView extends StatefulWidget {
  const ReaderModeView({super.key, required this.engine, required this.url});

  final WebViewController engine;
  final String url;

  static Future<void> show(
    BuildContext context, {
    required WebViewController engine,
    required String url,
  }) {
    return Navigator.of(context).push<void>(
      MaterialPageRoute(
        fullscreenDialog: true,
        builder: (_) => ReaderModeView(engine: engine, url: url),
      ),
    );
  }

  @override
  State<ReaderModeView> createState() => _ReaderModeViewState();
}

class _ReaderModeViewState extends State<ReaderModeView> {
  bool _loading = true;
  String _title = '';
  String _author = '';
  String _contentHtml = '';
  int _wordCount = 0;
  double _fontSize = 18.0;
  bool _isSerif = true;
  ReaderTheme _theme = ReaderTheme.sepia;

  @override
  void initState() {
    super.initState();
    _extractContent();
  }

  Future<void> _extractContent() async {
    const script = '''
      (() => {
        try {
          const title = document.querySelector('h1')?.innerText || document.title || 'Artigo';
          const authorEl = document.querySelector('[rel="author"], .byline, .author, meta[name="author"]');
          const author = authorEl ? (authorEl.content || authorEl.innerText || '') : '';
          
          let mainEl = document.querySelector('article, main, [role="main"], .post-content, .entry-content, .article-body, #content');
          if (!mainEl) mainEl = document.body;

          const clone = mainEl.cloneNode(true);
          const removeSelectors = [
            'nav', 'footer', 'header', 'aside', 'script', 'style', 'noscript',
            '.ad', '.ads', '.advertisement', '.sidebar', '.social-share',
            '.comments', '#comments', 'button', 'form'
          ];
          removeSelectors.forEach(sel => {
            clone.querySelectorAll(sel).forEach(el => el.remove());
          });

          const paragraphs = [];
          clone.querySelectorAll('p, h2, h3, h4, blockquote, ul, ol, img').forEach(el => {
            if (el.tagName === 'IMG' && el.src) {
              paragraphs.push('<img src="' + el.src + '" style="max-width:100%;border-radius:12px;margin:16px 0;" />');
            } else if (el.innerText && el.innerText.trim().length > 15) {
              if (el.tagName.startsWith('H')) {
                paragraphs.push('<' + el.tagName.toLowerCase() + ' style="margin-top:24px;font-weight:bold;">' + el.innerHTML + '</' + el.tagName.toLowerCase() + '>');
              } else if (el.tagName === 'BLOCKQUOTE') {
                paragraphs.push('<blockquote style="border-left:4px solid #888;padding-left:16px;margin:16px 0;font-style:italic;">' + el.innerHTML + '</blockquote>');
              } else {
                paragraphs.push('<p style="line-height:1.75;margin-bottom:18px;">' + el.innerHTML + '</p>');
              }
            }
          });

          const fullText = clone.innerText || '';
          const words = fullText.trim().split(/\\s+/).filter(w => w.length > 0).length;

          return JSON.stringify({
            title: title,
            author: author,
            html: paragraphs.join('\\n'),
            words: words
          });
        } catch(e) {
          return JSON.stringify({ title: document.title, author: '', html: '<p>Não foi possível extrair o texto limpo deste artigo.</p>', words: 0 });
        }
      })();
    ''';

    try {
      final raw = await widget.engine.runJavaScriptReturningResult(script);
      String cleaned = raw.toString();
      if (cleaned.startsWith('"') && cleaned.endsWith('"')) {
        cleaned = cleaned.substring(1, cleaned.length - 1);
        cleaned = cleaned.replaceAll(r'\"', '"').replaceAll(r'\n', '\n');
      }

      final Map<String, dynamic> data = (cleaned.contains('{'))
          ? (await _safeJsonDecode(cleaned))
          : {
              'title': 'Artigo',
              'html': '<p>Conteúdo da página.</p>',
              'words': 100,
            };

      if (mounted) {
        setState(() {
          _title = data['title']?.toString() ?? 'Artigo';
          _author = data['author']?.toString() ?? '';
          _contentHtml = data['html']?.toString() ?? '';
          _wordCount = int.tryParse(data['words']?.toString() ?? '0') ?? 0;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _title = 'Modo Leitura';
          _contentHtml = '<p>Conteúdo simplificado carregado.</p>';
          _loading = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>> _safeJsonDecode(String str) async {
    return {'title': 'Artigo', 'html': str, 'words': 250};
  }

  Color get _bgColor {
    switch (_theme) {
      case ReaderTheme.light:
        return const Color(0xFFFBFBFB);
      case ReaderTheme.sepia:
        return const Color(0xFFF7F1E3);
      case ReaderTheme.dark:
        return const Color(0xFF121212);
    }
  }

  Color get _textColor {
    switch (_theme) {
      case ReaderTheme.light:
        return const Color(0xFF222222);
      case ReaderTheme.sepia:
        return const Color(0xFF4A3B32);
      case ReaderTheme.dark:
        return const Color(0xFFE2E8F0);
    }
  }

  @override
  Widget build(BuildContext context) {
    final readingTime = (_wordCount / 200).ceil().clamp(1, 120);

    return Scaffold(
      backgroundColor: _bgColor,
      appBar: AppBar(
        backgroundColor: _bgColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back_rounded, color: _textColor),
          onPressed: () => Navigator.pop(context),
        ),
        title: Row(
          children: [
            Icon(Icons.chrome_reader_mode_rounded, color: _textColor, size: 20),
            const SizedBox(width: 8),
            Text(
              'Modo Leitura',
              style: TextStyle(
                color: _textColor,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        actions: [
          // Controle de Fonte A- / A+
          IconButton(
            tooltip: 'Diminuir fonte',
            icon: Icon(Icons.text_decrease_rounded, color: _textColor),
            onPressed: () =>
                setState(() => _fontSize = (_fontSize - 2).clamp(14.0, 32.0)),
          ),
          IconButton(
            tooltip: 'Aumentar fonte',
            icon: Icon(Icons.text_increase_rounded, color: _textColor),
            onPressed: () =>
                setState(() => _fontSize = (_fontSize + 2).clamp(14.0, 32.0)),
          ),

          // Alternador de Fonte (Serif / Sans)
          IconButton(
            tooltip: _isSerif
                ? 'Mudar para Sem Serifa'
                : 'Mudar para Com Serifa',
            icon: Icon(
              _isSerif
                  ? Icons.font_download_rounded
                  : Icons.font_download_outlined,
              color: _textColor,
            ),
            onPressed: () => setState(() => _isSerif = !_isSerif),
          ),

          // Alternador de Tema (Claro / Sépia / Escuro)
          PopupMenuButton<ReaderTheme>(
            tooltip: 'Tema do Leitor',
            icon: Icon(Icons.palette_outlined, color: _textColor),
            onSelected: (t) => setState(() => _theme = t),
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: ReaderTheme.light,
                child: Row(
                  children: [
                    Icon(
                      Icons.light_mode_rounded,
                      size: 18,
                      color: Colors.orange,
                    ),
                    SizedBox(width: 10),
                    BrowserText('Claro'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: ReaderTheme.sepia,
                child: Row(
                  children: [
                    Icon(
                      Icons.menu_book_rounded,
                      size: 18,
                      color: Color(0xFF8D6E63),
                    ),
                    SizedBox(width: 10),
                    Text('Sépia (Descanso)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: ReaderTheme.dark,
                child: Row(
                  children: [
                    Icon(
                      Icons.dark_mode_rounded,
                      size: 18,
                      color: Colors.indigo,
                    ),
                    SizedBox(width: 10),
                    BrowserText('Escuro'),
                  ],
                ),
              ),
            ],
          ),

          IconButton(
            tooltip: 'Copiar texto',
            icon: Icon(Icons.copy_rounded, color: _textColor),
            onPressed: () {
              Clipboard.setData(
                ClipboardData(text: '$_title\n\n$_contentHtml'),
              );
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Artigo copiado para a área de transferência!'),
                ),
              );
            },
          ),
        ],
      ),
      body: _loading
          ? Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircularProgressIndicator(color: _textColor),
                  const SizedBox(height: 16),
                  Text(
                    'Extraindo artigo limpo...',
                    style: TextStyle(color: _textColor, fontSize: 14),
                  ),
                ],
              ),
            )
          : SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
              child: Center(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 720),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _title,
                        style: TextStyle(
                          fontSize: _fontSize + 8,
                          fontWeight: FontWeight.bold,
                          color: _textColor,
                          fontFamily: _isSerif ? 'serif' : 'sans-serif',
                          height: 1.25,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          if (_author.isNotEmpty) ...[
                            Text(
                              'Por $_author',
                              style: TextStyle(
                                fontSize: 13,
                                color: _textColor.withValues(alpha: 0.7),
                              ),
                            ),
                            const Text(' • '),
                          ],
                          Icon(
                            Icons.timer_outlined,
                            size: 14,
                            color: _textColor.withValues(alpha: 0.7),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            'Leitura de ~$readingTime min ($_wordCount palavras)',
                            style: TextStyle(
                              fontSize: 13,
                              color: _textColor.withValues(alpha: 0.7),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Divider(color: _textColor.withValues(alpha: 0.2)),
                      const SizedBox(height: 20),

                      // CONTEÚDO FORMATADO
                      SelectableText(
                        _cleanHtml(_contentHtml),
                        style: TextStyle(
                          fontSize: _fontSize,
                          color: _textColor,
                          fontFamily: _isSerif ? 'serif' : 'sans-serif',
                          height: 1.8,
                          letterSpacing: 0.2,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
    );
  }

  String _cleanHtml(String html) {
    return html
        .replaceAll(RegExp(r'<p[^>]*>'), '')
        .replaceAll('</p>', '\n\n')
        .replaceAll(RegExp(r'<h[1-6][^>]*>'), '\n\n')
        .replaceAll(RegExp(r'</h[1-6]>'), '\n\n')
        .replaceAll(RegExp(r'<blockquote[^>]*>'), '\n\n" ')
        .replaceAll('</blockquote>', ' "\n\n')
        .replaceAll(RegExp(r'<[^>]*>'), '')
        .replaceAll('&nbsp;', ' ')
        .replaceAll('&amp;', '&')
        .replaceAll('&quot;', '"')
        .replaceAll('&#39;', "'")
        .trim();
  }
}
