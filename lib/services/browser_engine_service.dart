import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:webview_all/webview_all.dart';
import 'package:webview_all_windows/webview_all_windows.dart';

class BrowserEngineService {
  const BrowserEngineService();

  bool get usesWebView2 => defaultTargetPlatform == TargetPlatform.windows;

  String get name => switch (defaultTargetPlatform) {
    TargetPlatform.windows => 'Microsoft Edge WebView2',
    TargetPlatform.android => 'Android System WebView',
    TargetPlatform.iOS || TargetPlatform.macOS => 'WKWebView',
    TargetPlatform.linux => 'WebKitGTK',
    TargetPlatform.fuchsia => 'WebView',
  };

  Future<bool> isFixedRuntimeFolder(String folder) async {
    if (!usesWebView2 || folder.trim().isEmpty) return false;
    final directory = Directory(folder);
    if (!directory.isAbsolute) return false;
    final files = await Future.wait([
      for (final name in ['msedgewebview2.exe', 'msedge.dll'])
        File('${directory.path}${Platform.pathSeparator}$name').exists(),
    ]);
    return files.every((exists) => exists);
  }

  Future<void> initializeFixedRuntime(String folder) async {
    if (!await isFixedRuntimeFolder(folder)) {
      throw const FormatException('Pasta do WebView2 Fixed Version inválida.');
    }
    await WindowsWebViewController.ensureEnvironment(browserExePath: folder);
  }

  static String? _cachedRuntimeVersion;

  Future<String?> runtimeVersion() async {
    if (!usesWebView2) return null;
    if (_cachedRuntimeVersion != null) return _cachedRuntimeVersion;
    return _cachedRuntimeVersion =
        await WindowsWebViewController.getWebViewVersion();
  }

  Future<Map<String, bool>> inspectPage(WebViewController engine) async {
    final result = await engine.runJavaScriptReturningResult(_capabilities);
    Object? decoded = result;
    for (var attempt = 0; attempt < 2 && decoded is String; attempt++) {
      decoded = jsonDecode(decoded);
    }
    if (decoded is! Map || decoded.isEmpty) {
      throw const FormatException('Resposta de diagnóstico inválida.');
    }
    return Map<String, bool>.from(decoded);
  }

  static const _capabilities = r"""
    (() => {
      const video = document.createElement('video');
      const css = (property, value) =>
        globalThis.CSS?.supports(property, value) === true;
      return JSON.stringify({
        'Contexto seguro': globalThis.isSecureContext === true,
        'WebGPU': !!navigator.gpu,
        'WebAssembly': typeof WebAssembly === 'object',
        'WebCodecs (vídeo)': typeof VideoDecoder === 'function',
        'WebRTC': typeof RTCPeerConnection === 'function',
        'WebAuthn': typeof PublicKeyCredential === 'function',
        'Service Workers': 'serviceWorker' in navigator,
        'Web Locks': !!navigator.locks,
        'WebTransport': typeof WebTransport === 'function',
        'Picture-in-Picture': document.pictureInPictureEnabled === true ||
          typeof video.webkitSetPresentationMode === 'function',
        'CSS Container Queries': css('container-type', 'inline-size'),
        'CSS Subgrid': css('grid-template-columns', 'subgrid'),
        'CSS :has()': globalThis.CSS?.supports('selector(:has(*))') === true,
        'View Transitions': typeof document.startViewTransition === 'function'
      });
    })();
  """;
}
