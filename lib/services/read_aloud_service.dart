import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:webview_all/webview_all.dart';

enum ReadAloudState { stopped, playing, paused }

class ReadAloudService extends ChangeNotifier {
  ReadAloudService();

  ReadAloudState _state = ReadAloudState.stopped;
  ReadAloudState get state => _state;
  bool get isPlaying => _state == ReadAloudState.playing;
  bool get isPaused => _state == ReadAloudState.paused;
  bool get isActive => _state != ReadAloudState.stopped;

  double _rate = 1.0;
  double get rate => _rate;

  String _currentSentence = '';
  String get currentSentence => _currentSentence;

  WebViewController? _currentEngine;
  Timer? _pollerTimer;

  static const String _injectionScript = r"""
  (() => {
    if (window.__dartReadAloudInitialized) return;
    window.__dartReadAloudInitialized = true;
    window.__dartReadAloudState = {
      sentences: [],
      currentIndex: 0,
      speaking: false,
      paused: false,
      rate: 1.0,
      lang: 'pt-BR'
    };

    function extractArticleText() {
      const candidates = [
        document.querySelector('article'),
        document.querySelector('main'),
        document.querySelector('[role="main"]'),
        document.querySelector('.content'),
        document.querySelector('.post-content'),
        document.body
      ];
      let root = candidates.find(el => el != null) || document.body;
      const clone = root.cloneNode(true);
      const removeSelectors = ['script', 'style', 'nav', 'header', 'footer', 'noscript', 'iframe', 'svg', 'button', 'form', '.ad', '.ads'];
      removeSelectors.forEach(sel => {
        clone.querySelectorAll(sel).forEach(el => el.remove());
      });

      const text = clone.innerText || clone.textContent || '';
      return text.replace(/\s+/g, ' ').trim();
    }

    window.__dartReadAloudStart = (rate = 1.0) => {
      window.speechSynthesis.cancel();
      const rawText = extractArticleText();
      if (!rawText) return false;

      // Dividir em sentenças
      const sentences = rawText.match(/[^.!?]+[.!?]+(\s|$)|[^.!?]+$/g) || [rawText];
      window.__dartReadAloudState.sentences = sentences.map(s => s.trim()).filter(s => s.length > 0);
      window.__dartReadAloudState.currentIndex = 0;
      window.__dartReadAloudState.rate = rate;
      window.__dartReadAloudState.speaking = true;
      window.__dartReadAloudState.paused = false;

      speakNext();
      return true;
    };

    function speakNext() {
      const s = window.__dartReadAloudState;
      if (!s.speaking || s.paused) return;
      if (s.currentIndex >= s.sentences.length) {
        s.speaking = false;
        s.currentIndex = 0;
        return;
      }

      const text = s.sentences[s.currentIndex];
      const utter = new SpeechSynthesisUtterance(text);
      utter.rate = s.rate;

      // Detectar idioma simples (ou usar o idioma da página / pt-BR)
      const pageLang = document.documentElement.lang || 'pt-BR';
      utter.lang = pageLang;

      utter.onend = () => {
        if (s.speaking && !s.paused) {
          s.currentIndex++;
          speakNext();
        }
      };

      utter.onerror = () => {
        s.currentIndex++;
        speakNext();
      };

      window.speechSynthesis.speak(utter);
    }

    window.__dartReadAloudPause = () => {
      window.speechSynthesis.pause();
      window.__dartReadAloudState.paused = true;
      window.__dartReadAloudState.speaking = false;
    };

    window.__dartReadAloudResume = () => {
      window.__dartReadAloudState.paused = false;
      window.__dartReadAloudState.speaking = true;
      if (window.speechSynthesis.paused) {
        window.speechSynthesis.resume();
      } else {
        speakNext();
      }
    };

    window.__dartReadAloudStop = () => {
      window.speechSynthesis.cancel();
      window.__dartReadAloudState.speaking = false;
      window.__dartReadAloudState.paused = false;
      window.__dartReadAloudState.currentIndex = 0;
      window.__dartReadAloudState.sentences = [];
    };

    window.__dartReadAloudSetRate = (rate) => {
      window.__dartReadAloudState.rate = rate;
      if (window.__dartReadAloudState.speaking && !window.__dartReadAloudState.paused) {
        window.speechSynthesis.cancel();
        speakNext();
      }
    };

    window.__dartReadAloudGetStatus = () => {
      const s = window.__dartReadAloudState;
      const currentText = s.sentences[s.currentIndex] || '';
      return JSON.stringify({
        speaking: s.speaking,
        paused: s.paused,
        index: s.currentIndex,
        total: s.sentences.length,
        current: currentText.substring(0, 150)
      });
    };
  })();
  """;

  Future<void> start(WebViewController engine) async {
    _currentEngine = engine;
    try {
      await engine.runJavaScript(_injectionScript);
      await engine.runJavaScript('window.__dartReadAloudStart($_rate);');
      _state = ReadAloudState.playing;
      _startPoller();
      notifyListeners();
    } catch (e) {
      debugPrint('Erro ao iniciar leitura em voz alta: $e');
      _state = ReadAloudState.stopped;
      notifyListeners();
    }
  }

  Future<void> pause() async {
    if (_currentEngine == null) return;
    try {
      await _currentEngine!.runJavaScript('window.__dartReadAloudPause();');
      _state = ReadAloudState.paused;
      notifyListeners();
    } catch (_) {}
  }

  Future<void> resume() async {
    if (_currentEngine == null) return;
    try {
      await _currentEngine!.runJavaScript('window.__dartReadAloudResume();');
      _state = ReadAloudState.playing;
      _startPoller();
      notifyListeners();
    } catch (_) {}
  }

  Future<void> stop() async {
    _stopPoller();
    if (_currentEngine != null) {
      try {
        await _currentEngine!.runJavaScript('window.__dartReadAloudStop();');
      } catch (_) {}
    }
    _state = ReadAloudState.stopped;
    _currentSentence = '';
    notifyListeners();
  }

  Future<void> setRate(double rate) async {
    _rate = rate;
    notifyListeners();
    if (_currentEngine != null) {
      try {
        await _currentEngine!.runJavaScript(
          'window.__dartReadAloudSetRate($rate);',
        );
      } catch (_) {}
    }
  }

  void _startPoller() {
    _pollerTimer?.cancel();
    _pollerTimer = Timer.periodic(const Duration(milliseconds: 700), (_) async {
      if (_state != ReadAloudState.playing || _currentEngine == null) {
        _stopPoller();
        return;
      }
      try {
        final result = await _currentEngine!.runJavaScriptReturningResult(
          'window.__dartReadAloudGetStatus ? window.__dartReadAloudGetStatus() : "{}"',
        );
        var raw = result.toString().trim();
        if (raw.startsWith('"') && raw.endsWith('"') && raw.length > 2) {
          raw = raw.substring(1, raw.length - 1).replaceAll(r'\"', '"');
        }
        if (raw.contains('speaking')) {
          final isSpeaking = raw.contains('"speaking":true');
          final isPaused = raw.contains('"paused":true');
          if (!isSpeaking && !isPaused) {
            _state = ReadAloudState.stopped;
            _currentSentence = '';
            _stopPoller();
            notifyListeners();
          }
        }
      } catch (_) {}
    });
  }

  void _stopPoller() {
    _pollerTimer?.cancel();
    _pollerTimer = null;
  }

  @override
  void dispose() {
    _stopPoller();
    super.dispose();
  }
}
