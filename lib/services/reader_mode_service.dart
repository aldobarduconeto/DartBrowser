import 'dart:convert';

import 'package:webview_all/webview_all.dart';

class ReaderModeService {
  const ReaderModeService();

  Future<bool> activate(
    WebViewController engine, {
    String theme = 'sepia',
    double fontSize = 18.0,
  }) async {
    final themeJson = jsonEncode(theme);
    final script =
        '''
      (() => {
        try {
          if (document.getElementById('__dart_reader_container__')) return true;

          // Salvar estado original do body
          window.__dart_original_body__ = document.body.innerHTML;
          window.__dart_original_title__ = document.title;
          window.__dart_original_scroll__ = window.scrollY;

          // Extrair informações do artigo
          const h1 = document.querySelector('article h1, h1, .post-title, .entry-title');
          const title = h1 ? h1.innerText.trim() : document.title;

          // Procurar o container principal de conteúdo
          const selectors = [
            'article', '[itemprop="articleBody"]', '.post-content',
            '.entry-content', '.article-body', '.story-body', 'main', '.content'
          ];
          let container = null;
          for (const sel of selectors) {
            const found = document.querySelector(sel);
            if (found && found.innerText.trim().length > 300) {
              container = found;
              break;
            }
          }
          if (!container) container = document.body;

          // Extrair parágrafos e imagens relevantes
          const elements = container.querySelectorAll('p, h2, h3, h4, blockquote, figure, img, ul, ol');
          const contentNodes = [];
          let wordCount = 0;

          elements.forEach(el => {
            const tag = el.tagName.toLowerCase();
            // Ignorar elementos de anúncio, menus, sidebars ou comentários
            const className = (el.className || '').toString().toLowerCase();
            const id = (el.id || '').toString().toLowerCase();
            if (className.includes('comment') || className.includes('ad') ||
                className.includes('social') || className.includes('sidebar') ||
                className.includes('share') || id.includes('comment')) {
              return;
            }

            if (tag === 'p') {
              const text = el.innerText.trim();
              if (text.length > 25) {
                wordCount += text.split(/\\s+/).length;
                contentNodes.push('<p>' + el.innerHTML + '</p>');
              }
            } else if (['h2', 'h3', 'h4', 'blockquote', 'ul', 'ol'].includes(tag)) {
              contentNodes.push(el.outerHTML);
            } else if (tag === 'img' && el.src && el.naturalWidth > 150) {
              contentNodes.push('<div class="reader-img-wrap"><img src="' + el.src + '" alt="' + (el.alt || '') + '"/></div>');
            }
          });

          if (contentNodes.length === 0) return false;

          const readingMinutes = Math.max(1, Math.round(wordCount / 200));

          // Estilos por tema
          const themes = {
            light: { bg: '#ffffff', text: '#1a1a1a', meta: '#666666', border: '#e5e7eb' },
            sepia: { bg: '#fbf0d9', text: '#433422', meta: '#7a6752', border: '#e4d3b8' },
            dark: { bg: '#181a1b', text: '#e8e6e3', meta: '#9e9e9e', border: '#2d3134' },
            oled: { bg: '#000000', text: '#d1d5db', meta: '#6b7280', border: '#1f2937' }
          };
          const curTheme = themes[$themeJson] || themes.sepia;

          const readerHtml = `
            <div id="__dart_reader_container__" style="
              min-height: 100vh;
              background-color: \${curTheme.bg};
              color: \${curTheme.text};
              font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Georgia, serif;
              line-height: 1.75;
              padding: 48px 24px;
              box-sizing: border-box;
              transition: all 0.2s ease;
            ">
              <div style="max-width: 680px; margin: 0 auto;">
                <div style="margin-bottom: 24px; border-bottom: 1px solid \${curTheme.border}; padding-bottom: 16px;">
                  <span style="
                    display: inline-block;
                    font-size: 12px;
                    font-weight: bold;
                    letter-spacing: 1px;
                    text-transform: uppercase;
                    color: \${curTheme.meta};
                    margin-bottom: 8px;
                  ">📖 MODO LEITURA • \${readingMinutes} MIN DE LEITURA</span>
                  <h1 style="
                    font-size: 32px;
                    font-weight: 800;
                    line-height: 1.25;
                    margin: 8px 0;
                    letter-spacing: -0.5px;
                  ">\${title}</h1>
                </div>

                <div id="__dart_reader_body__" style="font-size: ${fontSize}px;">
                  \${contentNodes.join('')}
                </div>
              </div>
            </div>
          `;

          const style = document.createElement('style');
          style.id = '__dart_reader_styles__';
          style.textContent = `
            #__dart_reader_container__ p { margin-bottom: 1.5em; line-height: 1.8; }
            #__dart_reader_container__ h2, #__dart_reader_container__ h3 { margin-top: 1.8em; margin-bottom: 0.8em; font-weight: 700; }
            #__dart_reader_container__ blockquote { border-left: 4px solid \${curTheme.meta}; padding-left: 16px; margin: 1.5em 0; font-style: italic; opacity: 0.9; }
            #__dart_reader_container__ img { max-width: 100%; height: auto; border-radius: 8px; margin: 16px 0; }
            #__dart_reader_container__ .reader-img-wrap { text-align: center; }
            #__dart_reader_container__ a { color: inherit; text-decoration: underline; opacity: 0.85; }
          `;
          document.head.appendChild(style);
          document.body.innerHTML = readerHtml;
          window.scrollTo(0, 0);
          return true;
        } catch (e) {
          return false;
        }
      })();
    ''';

    try {
      final res = await engine.runJavaScriptReturningResult(script);
      return res == true || res == 'true';
    } catch (_) {
      return false;
    }
  }

  Future<void> deactivate(WebViewController engine) async {
    const script = '''
      (() => {
        try {
          if (window.__dart_original_body__) {
            document.body.innerHTML = window.__dart_original_body__;
            const style = document.getElementById('__dart_reader_styles__');
            if (style) style.remove();
            if (window.__dart_original_title__) document.title = window.__dart_original_title__;
            if (window.__dart_original_scroll__ !== undefined) {
              window.scrollTo(0, window.__dart_original_scroll__);
            }
            delete window.__dart_original_body__;
          }
        } catch (_) {}
      })();
    ''';
    try {
      await engine.runJavaScript(script);
    } catch (_) {}
  }

  Future<void> updateStyle(
    WebViewController engine, {
    required String theme,
    required double fontSize,
  }) async {
    final themeJson = jsonEncode(theme);
    final script =
        '''
      (() => {
        try {
          const container = document.getElementById('__dart_reader_container__');
          const body = document.getElementById('__dart_reader_body__');
          if (!container || !body) return;

          const themes = {
            light: { bg: '#ffffff', text: '#1a1a1a', meta: '#666666' },
            sepia: { bg: '#fbf0d9', text: '#433422', meta: '#7a6752' },
            dark: { bg: '#181a1b', text: '#e8e6e3', meta: '#9e9e9e' },
            oled: { bg: '#000000', text: '#d1d5db', meta: '#6b7280' }
          };
          const cur = themes[$themeJson] || themes.sepia;
          container.style.backgroundColor = cur.bg;
          container.style.color = cur.text;
          body.style.fontSize = '${fontSize}px';
        } catch (_) {}
      })();
    ''';
    try {
      await engine.runJavaScript(script);
    } catch (_) {}
  }
}
