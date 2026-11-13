import 'package:webview_all/webview_all.dart';

class PageTranslateService {
  const PageTranslateService();

  static const String _translateScript = r"""
  (() => {
    if (document.getElementById('google_translate_element')) {
      const select = document.querySelector('.goog-te-combo');
      if (select) {
        select.value = 'pt';
        select.dispatchEvent(new Event('change'));
      }
      return true;
    }

    const container = document.createElement('div');
    container.id = 'google_translate_element';
    container.style.position = 'fixed';
    container.style.top = '10px';
    container.style.right = '10px';
    container.style.zIndex = '9999999';
    container.style.backgroundColor = '#ffffff';
    container.style.padding = '8px';
    container.style.borderRadius = '8px';
    container.style.boxShadow = '0 4px 12px rgba(0,0,0,0.2)';
    document.body.appendChild(container);

    window.googleTranslateElementInit = function() {
      new google.translate.TranslateElement({
        pageLanguage: 'auto',
        includedLanguages: 'pt,en,es,fr,de,it,ja,zh-CN',
        layout: google.translate.TranslateElement.InlineLayout.SIMPLE
      }, 'google_translate_element');

      setTimeout(() => {
        const select = document.querySelector('.goog-te-combo');
        if (select) {
          select.value = 'pt';
          select.dispatchEvent(new Event('change'));
        }
      }, 500);
    };

    const s = document.createElement('script');
    s.type = 'text/javascript';
    s.src = 'https://translate.google.com/translate_a/element.js?cb=googleTranslateElementInit';
    document.head.appendChild(s);
    return true;
  })();
  """;

  static Future<void> translatePage(
    WebViewController engine,
    String currentUrl,
  ) async {
    try {
      final res = await engine.runJavaScriptReturningResult(_translateScript);
      if (res.toString() == 'false') {
        final encodedUrl = Uri.encodeComponent(currentUrl);
        engine.loadRequest(
          Uri.parse(
            'https://translate.google.com/translate?sl=auto&tl=pt&u=$encodedUrl',
          ),
        );
      }
    } catch (_) {
      final encodedUrl = Uri.encodeComponent(currentUrl);
      engine.loadRequest(
        Uri.parse(
          'https://translate.google.com/translate?sl=auto&tl=pt&u=$encodedUrl',
        ),
      );
    }
  }
}
