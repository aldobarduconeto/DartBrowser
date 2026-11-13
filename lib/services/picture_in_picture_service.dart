import 'package:flutter/services.dart';
import 'package:webview_all/webview_all.dart';

class PictureInPictureService {
  static const _android = MethodChannel('dart_browser/picture_in_picture');

  Future<bool> install(WebViewController engine) async {
    return await engine.tryAddUserScript(
          const WebViewUserScript(
            source: _playerControl,
            injectionTime: WebViewUserScriptInjectionTime.documentEnd,
            forMainFrameOnly: false,
          ),
        ) !=
        null;
  }

  Future<void> installForCurrentPage(WebViewController engine) async {
    try {
      await engine.runJavaScript(_playerControl);
    } on PlatformException {
      // O documento pode ter mudado enquanto o script estava sendo instalado.
    } catch (_) {}
  }

  /// Ativa o Picture-in-Picture no vídeo atualmente em reprodução na aba
  Future<bool> enterPiP(WebViewController engine) async {
    try {
      await engine.runJavaScript(_enterAutoPiPScript);
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Desativa o Picture-in-Picture e restaura a reprodução na página
  Future<bool> exitPiP(WebViewController engine) async {
    try {
      await engine.runJavaScript(_exitAutoPiPScript);
      return true;
    } catch (_) {
      return false;
    }
  }

  Future<bool> enterAndroidWindow() async {
    try {
      return await _android.invokeMethod<bool>('enter') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  static const _enterAutoPiPScript = r"""
(() => {
  try {
    function getAllVideos(root) {
      let vids = Array.from(root.querySelectorAll('video'));
      const els = root.querySelectorAll('*');
      for (const el of els) {
        if (el.shadowRoot) {
          vids = vids.concat(getAllVideos(el.shadowRoot));
        }
      }
      return vids;
    }

    const videos = getAllVideos(document);
    if (!videos.length) return;

    // Prioriza vídeo que está ativamente tocando
    let candidate = videos.find(v => !v.paused && v.currentTime > 0 && !v.ended);
    if (!candidate && videos.length === 1 && !videos[0].paused) {
      candidate = videos[0];
    }
    if (!candidate) {
      candidate = videos.find(v => !v.paused);
    }
    if (!candidate) return;

    if (document.pictureInPictureElement === candidate) return;

    candidate.removeAttribute('disablepictureinpicture');

    if (document.pictureInPictureEnabled && typeof candidate.requestPictureInPicture === 'function') {
      candidate.requestPictureInPicture().then(() => {
        candidate.setAttribute('data-dart-auto-pip', 'true');
      }).catch(() => {});
    } else if (typeof candidate.webkitSetPresentationMode === 'function') {
      candidate.webkitSetPresentationMode('picture-in-picture');
      candidate.setAttribute('data-dart-auto-pip', 'true');
    }
  } catch (_) {}
})();
""";

  static const _exitAutoPiPScript = r"""
(() => {
  try {
    if (document.pictureInPictureElement) {
      document.exitPictureInPicture().catch(() => {});
      return;
    }

    function getAllVideos(root) {
      let vids = Array.from(root.querySelectorAll('video'));
      const els = root.querySelectorAll('*');
      for (const el of els) {
        if (el.shadowRoot) {
          vids = vids.concat(getAllVideos(el.shadowRoot));
        }
      }
      return vids;
    }

    const videos = getAllVideos(document);
    for (const v of videos) {
      if (v.getAttribute('data-dart-auto-pip') === 'true' ||
          v.webkitPresentationMode === 'picture-in-picture') {
        v.removeAttribute('data-dart-auto-pip');
        if (typeof v.webkitSetPresentationMode === 'function') {
          v.webkitSetPresentationMode('inline');
        }
      }
    }
  } catch (_) {}
})();
""";

  static const _playerControl = r"""
(() => {
  if (!document.body || document.querySelector('[data-dart-browser-pip]')) {
    return;
  }

  const control = document.createElement('div');
  control.setAttribute('data-dart-browser-pip', '');
  control.style.cssText =
      'position:fixed;right:12px;bottom:12px;z-index:2147483647';
  const ui = control.attachShadow({mode: 'closed'});
  const button = document.createElement('button');
  button.type = 'button';
  button.textContent = 'PiP';
  button.title = 'Abrir vídeo em Picture-in-Picture';
  button.setAttribute('aria-label', button.title);
  button.style.cssText =
      'border:1px solid rgba(255,255,255,0.2);border-radius:8px;background:rgba(20,20,24,0.85);' +
      'backdrop-filter:blur(8px);color:#fff;padding:6px 12px;font:600 13px system-ui;cursor:pointer;' +
      'box-shadow:0 4px 12px rgba(0,0,0,0.3);transition:all 0.2s ease;';
  const status = document.createElement('div');
  status.setAttribute('role', 'status');
  status.hidden = true;
  status.style.cssText =
      'background:#202124;color:#fff;padding:6px;font:13px system-ui;border-radius:6px;margin-top:4px';
  ui.append(button, status);

  let video;
  function supportsPiP(candidate) {
    return (document.pictureInPictureEnabled &&
            typeof candidate.requestPictureInPicture === 'function') ||
        (typeof candidate.webkitSupportsPresentationMode === 'function' &&
         candidate.webkitSupportsPresentationMode('picture-in-picture'));
  }

  function update(candidate) {
    if (!(candidate instanceof HTMLVideoElement) ||
        candidate.readyState === 0 || !candidate.videoWidth) return;
    if (!supportsPiP(candidate)) return;
    candidate.removeAttribute('disablepictureinpicture');
    if (video && video.isConnected && !video.paused && candidate.paused) return;
    video = candidate;
    control.hidden = false;
  }

  control.hidden = true;
  document.body.append(control);
  for (const candidate of document.querySelectorAll('video')) update(candidate);
  for (const event of ['loadedmetadata', 'playing']) {
    document.addEventListener(event, (event) => update(event.target), true);
  }

  button.addEventListener('click', async (event) => {
    if (!event.isTrusted || !video?.isConnected) return;
    status.hidden = true;
    const candidate = video;
    try {
      if (document.pictureInPictureElement === candidate) {
        await document.exitPictureInPicture();
      } else if (document.pictureInPictureEnabled &&
                 typeof candidate.requestPictureInPicture === 'function') {
        candidate.removeAttribute('disablepictureinpicture');
        await candidate.requestPictureInPicture();
      } else if (candidate.webkitSupportsPresentationMode?.('picture-in-picture')) {
        candidate.webkitSetPresentationMode(
          candidate.webkitPresentationMode === 'picture-in-picture'
            ? 'inline' : 'picture-in-picture'
        );
      }
    } catch (_) {
      status.textContent = 'Picture-in-Picture indisponível neste vídeo.';
      status.hidden = false;
    }
  });
})();
""";
}
