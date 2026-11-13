import 'dart:async';

import 'package:webview_all/webview_all.dart';

import 'browser_data.dart';
import 'tab_group.dart';

class BrowserTab {
  BrowserTab({String? id, this.isIncognito = false, this.isPinned = false})
    : id = id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      lastAccessed = DateTime.now();

  final String id;
  late final engine = WebViewController();
  final bool isIncognito;

  bool isPinned;
  bool isMuted = false;
  bool hasAudio = false;
  String? customUserAgent;
  PageVisualFilter visualFilter = PageVisualFilter.none;

  int blockedAdsCount = 0;
  int blockedTrackersCount = 0;
  int get totalBlockedCount => blockedAdsCount + blockedTrackersCount;

  String? address;
  String? title;
  String? faviconUrl;
  TabGroup? group;
  String? error;
  int progress = 100;
  bool canGoBack = false;
  bool canGoForward = false;
  bool isSuspended = false;
  bool isReaderMode = false;
  double zoomLevel = 1.0;
  DateTime lastAccessed;

  Future<void>? initialization;

  void touch() {
    lastAccessed = DateTime.now();
  }

  String get host {
    final raw = address;
    if (raw == null || raw.isEmpty) return '';
    return Uri.tryParse(raw)?.host ?? '';
  }

  String? get effectiveFaviconUrl {
    if (faviconUrl != null && faviconUrl!.isNotEmpty) {
      return faviconUrl;
    }
    final currentHost = host;
    if (currentHost.isEmpty) return null;
    final cleanHost = currentHost.replaceFirst(RegExp(r'^www\.'), '');
    if (cleanHost.isEmpty) return null;
    return 'https://www.google.com/s2/favicons?domain=$cleanHost&sz=64';
  }

  String get displayTitle {
    final trimmed = title?.trim();
    if (trimmed != null && trimmed.isNotEmpty) return trimmed;
    if (host.isNotEmpty) return host;
    return isIncognito ? 'Guia Anônima' : 'Nova aba';
  }
}
