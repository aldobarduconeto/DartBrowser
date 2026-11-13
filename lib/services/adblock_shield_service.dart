import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

enum BlockType { none, ad, tracker }

class BlockResult {
  const BlockResult({
    required this.blocked,
    required this.type,
    this.reason = '',
  });

  final bool blocked;
  final BlockType type;
  final String reason;

  static const notBlocked = BlockResult(blocked: false, type: BlockType.none);
}

class AdBlockShieldService {
  AdBlockShieldService(this.preferences);

  final SharedPreferences preferences;

  // -------------------------------------------------------------
  // LISTA DE PARÂMETROS DE RASTREAMENTO PARA LIMPEZA DE URL
  // -------------------------------------------------------------
  static const Set<String> _trackingQueryParams = {
    'fbclid',
    'gclid',
    'gbraid',
    'wbraid',
    'msclkid',
    'twclid',
    'yclid',
    'mc_eid',
    'igshid',
    'dclid',
    '_hsenc',
    '_hsmi',
    'vero_id',
    'mkt_tok',
    '_openstat',
  };

  // -------------------------------------------------------------
  // LISTA DE DOMÍNIOS DE ANÚNCIOS (AD NETWORKS & POPUPS)
  // -------------------------------------------------------------
  static const Set<String> _adDomains = {
    'doubleclick.net',
    'googlesyndication.com',
    'googleadservices.com',
    'adservice.google.com',
    'adnxs.com',
    'adform.net',
    'rubiconproject.com',
    'pubmatic.com',
    'openx.net',
    'taboola.com',
    'outbrain.com',
    'criteo.com',
    'criteo.net',
    'popads.net',
    'popcash.net',
    'propellerads.com',
    'adcolony.com',
    'unityads.unity3d.com',
    'vungle.com',
    'inmobi.com',
    'admob.com',
    'advertising.com',
    'revcontent.com',
    'mgid.com',
    'trafficfactory.biz',
    'exoclick.com',
    'adroll.com',
    'adblade.com',
    'adsterra.com',
    'bidswitch.net',
    'casalemedia.com',
    'smartadserver.com',
    'contextweb.com',
    'yieldmo.com',
    'exponential.com',
    'sovrn.com',
    'lijit.com',
    'zedo.com',
    'moatads.com',
    'adpushup.com',
  };

  // -------------------------------------------------------------
  // LISTA DE DOMÍNIOS DE RASTREADORES E TELEMETRIA
  // -------------------------------------------------------------
  static const Set<String> _trackerDomains = {
    'google-analytics.com',
    'analytics.google.com',
    'googletagmanager.com',
    'hotjar.com',
    'clarity.ms',
    'mixpanel.com',
    'segment.io',
    'segment.com',
    'amplitude.com',
    'scorecardresearch.com',
    'quantserve.com',
    'mc.yandex.ru',
    'yandex.ru/metrika',
    'facebook.com/tr',
    'connect.facebook.net/en_US/fbevents.js',
    'ads-twitter.com',
    't.co',
    'analytics.twitter.com',
    'tiktok.com/i18n/pixel',
    'analytics.tiktok.com',
    'tr.snapchat.com',
    'bat.bing.com',
    'newrelic.com',
    'nr-data.net',
    'crazyegg.com',
    'fullstory.com',
    'statcounter.com',
    'clicky.com',
    'kissmetrics.com',
    'inspectlet.com',
    'mouseflow.com',
    'smartlook.com',
    'luckyorange.com',
  };

  // -------------------------------------------------------------
  // LIMPEZA DE PARÂMETROS DE RASTREAMENTO EM URLS
  // -------------------------------------------------------------
  String cleanUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasQuery) return url;

    final filteredParams = <String, String>{};
    uri.queryParameters.forEach((key, value) {
      final lowerKey = key.toLowerCase();
      final isTrackingParam =
          lowerKey.startsWith('utm_') ||
          _trackingQueryParams.contains(lowerKey);
      if (!isTrackingParam) {
        filteredParams[key] = value;
      }
    });

    if (filteredParams.length == uri.queryParameters.length) {
      return url;
    }

    final cleanedUri = uri.replace(
      queryParameters: filteredParams.isEmpty ? null : filteredParams,
    );
    return cleanedUri.toString();
  }

  // -------------------------------------------------------------
  // VERIFICAÇÃO DE BLOQUEIO DE REQUISIÇÃO DE REDE
  // -------------------------------------------------------------
  BlockResult shouldBlockRequest({
    required Uri requestUri,
    required String? mainHost,
    required bool adBlockEnabled,
    required bool antiTrackingEnabled,
    required List<String> whitelist,
  }) {
    // 1. Se o site principal estiver na lista de permissões, não bloqueia
    if (mainHost != null && isWhitelisted(mainHost, whitelist)) {
      return BlockResult.notBlocked;
    }

    final targetHost = requestUri.host.toLowerCase();
    if (targetHost.isEmpty) return BlockResult.notBlocked;

    // Não bloqueia a própria navegação do site raiz para si mesmo
    if (mainHost != null &&
        (targetHost == mainHost.toLowerCase() ||
            targetHost.endsWith('.${mainHost.toLowerCase()}'))) {
      return BlockResult.notBlocked;
    }

    // 2. Verificação de Anúncios
    if (adBlockEnabled) {
      for (final domain in _adDomains) {
        if (targetHost == domain || targetHost.endsWith('.$domain')) {
          return BlockResult(
            blocked: true,
            type: BlockType.ad,
            reason: 'Rede de anúncio bloqueada: $domain',
          );
        }
      }
    }

    // 3. Verificação de Rastreadores
    if (antiTrackingEnabled) {
      for (final domain in _trackerDomains) {
        if (targetHost == domain || targetHost.endsWith('.$domain')) {
          return BlockResult(
            blocked: true,
            type: BlockType.tracker,
            reason: 'Rastreador de telemetria bloqueado: $domain',
          );
        }
      }

      // Verificação de caminhos de tracking específicos
      final fullPath = '${requestUri.host}${requestUri.path}'.toLowerCase();
      if (fullPath.contains('facebook.com/tr') ||
          fullPath.contains('analytics') ||
          fullPath.contains('pixel')) {
        return const BlockResult(
          blocked: true,
          type: BlockType.tracker,
          reason: 'Pixel de rastreamento bloqueado',
        );
      }
    }

    return BlockResult.notBlocked;
  }

  bool isWhitelisted(String host, List<String> whitelist) {
    final clean = host.toLowerCase().trim();
    return whitelist.any((w) => w.toLowerCase().trim() == clean);
  }

  // -------------------------------------------------------------
  // CSS PARA BLOQUEIO COSMÉTICO DE ANÚNCIOS (SEM ESPAÇOS EM BRANCO)
  // -------------------------------------------------------------
  String getCosmeticFilterCss() {
    return '''
      .ad, .ads, .adsbygoogle, [id*="google_ads"], [id*="ad-container"],
      [id*="ad_container"], .ad-banner, .banner-ad, [class*="sponsored-post"],
      aside[class*="ad"], .sponsored, [data-ad], div[class*="ad-slot"],
      div[id*="ad-slot"], .taboola-ad, .outbrain-ad, [data-ad-unit],
      iframe[src*="adservice"], iframe[src*="doubleclick"], .ads-wrapper,
      .native-ad, .ad-placeholder, #ad_banner, [aria-label*="advertisement"],
      [aria-label*="anúncio"], [aria-label*="publicidade"], .dfp-ad-slot {
        display: none !important;
        height: 0 !important;
        min-height: 0 !important;
        max-height: 0 !important;
        width: 0 !important;
        visibility: hidden !important;
        pointer-events: none !important;
        margin: 0 !important;
        padding: 0 !important;
        border: none !important;
        opacity: 0 !important;
      }
    ''';
  }

  // -------------------------------------------------------------
  // SCRIPT INJETADO DE PROTEÇÃO ANTI-RASTREIO E ANTI-FINGERPRINT
  // -------------------------------------------------------------
  String getShieldInjectionScript({
    required bool blockAds,
    required bool antiTrack,
    required bool antiFingerprint,
    required String host,
  }) {
    final cssJson = jsonEncode(getCosmeticFilterCss());

    return '''
      (() => {
        if (window.__dart_shield_active__) return;
        window.__dart_shield_active__ = true;

        let blockedAds = 0;
        let blockedTrackers = 0;

        const notifyStats = () => {
          if (blockedAds > 0 || blockedTrackers > 0) {
            try {
              const iframe = document.createElement('iframe');
              iframe.style.display = 'none';
              iframe.src = 'dart-shield://stats?ads=' + blockedAds + '&trackers=' + blockedTrackers;
              (document.body || document.documentElement).appendChild(iframe);
              setTimeout(() => iframe.remove(), 100);
            } catch (_) {}
          }
        };

        // 1. INJEÇÃO DE CSS COSMÉTICO ANTI-ANÚNCIO
        ${blockAds ? '''
          try {
            const style = document.createElement('style');
            style.id = 'dart-adblock-cosmetic-style';
            style.textContent = $cssJson;
            (document.head || document.documentElement).appendChild(style);
          } catch (_) {}

          // Limpeza ativa de elementos de anúncio no DOM
          const cleanAds = () => {
            const selectors = [
              '.ad', '.ads', '.adsbygoogle', '[id*="google_ads"]',
              '.ad-banner', '.banner-ad', '.sponsored-post',
              'iframe[src*="doubleclick"]', 'iframe[src*="adservice"]'
            ];
            selectors.forEach(sel => {
              document.querySelectorAll(sel).forEach(el => {
                if (el.style.display !== 'none') {
                  el.style.display = 'none';
                  blockedAds++;
                }
              });
            });
          };
          cleanAds();
          setInterval(cleanAds, 2500);
        ''' : ''}

        // 2. PROTEÇÃO ANTI-RASTREIO (BEACON, PING E TELEMETRIA)
        ${antiTrack ? '''
          // Bloqueio de navigator.sendBeacon para rastreadores
          if (navigator.sendBeacon) {
            const origSendBeacon = navigator.sendBeacon.bind(navigator);
            navigator.sendBeacon = function(url, data) {
              const u = String(url || '').toLowerCase();
              if (u.includes('analytics') || u.includes('telemetry') || u.includes('tracker') || u.includes('pixel')) {
                blockedTrackers++;
                notifyStats();
                return true;
              }
              return origSendBeacon(url, data);
            };
          }

          // Remoção de atributos <a ping="...">
          document.addEventListener('click', (e) => {
            const link = e.target.closest('a[ping]');
            if (link) {
              link.removeAttribute('ping');
              blockedTrackers++;
            }
          }, true);
        ''' : ''}

        // 3. PROTEÇÃO ANTI-FINGERPRINTING (CANVAS, ÁUDIO E BATERIA)
        ${antiFingerprint ? '''
          // Proteção de Canvas Fingerprinting (ruído de 1 bit imperceptível que neutraliza o hash de rastreamento)
          if (HTMLCanvasElement.prototype.toDataURL) {
            const origToDataURL = HTMLCanvasElement.prototype.toDataURL;
            HTMLCanvasElement.prototype.toDataURL = function() {
              const ctx = this.getContext('2d');
              if (ctx) {
                try {
                  const imgData = ctx.getImageData(0, 0, Math.min(this.width, 10), Math.min(this.height, 10));
                  if (imgData.data.length > 3) {
                    imgData.data[0] = (imgData.data[0] ^ 1);
                    ctx.putImageData(imgData, 0, 0);
                    blockedTrackers++;
                  }
                } catch (_) {}
              }
              return origToDataURL.apply(this, arguments);
            };
          }

          // Proteção de AudioContext Fingerprinting
          if (window.AudioBuffer && AudioBuffer.prototype.getChannelData) {
            const origGetChannelData = AudioBuffer.prototype.getChannelData;
            AudioBuffer.prototype.getChannelData = function(channel) {
              const data = origGetChannelData.apply(this, arguments);
              if (data && data.length > 10) {
                data[0] += 0.0000001;
              }
              return data;
            };
          }

          // Desativa telemetria invasiva de bateria
          if (navigator.getBattery) {
            navigator.getBattery = () => Promise.resolve({
              charging: true,
              chargingTime: 0,
              dischargingTime: Infinity,
              level: 1.0,
              addEventListener: () => {}
            });
          }
        ''' : ''}

        // Notifica estatísticas iniciais
        setTimeout(notifyStats, 1500);
      })();
    ''';
  }
}
