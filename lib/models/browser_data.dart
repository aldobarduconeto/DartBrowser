import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'download_item.dart';
import 'reading_item.dart';

class BrowserData {
  BrowserData(this.preferences)
    : favorites = preferences.getStringList('favorites') ?? [],
      history = preferences.getStringList('history') ?? [],
      searchEngine = SearchEngine.values.firstWhere(
        (engine) => engine.name == preferences.getString('searchEngine'),
        orElse: () => SearchEngine.duckDuckGo,
      ),
      home = preferences.getString('home'),
      readerTheme = preferences.getString('readerTheme') ?? 'sepia',
      readerFontSize = preferences.getDouble('readerFontSize') ?? 18.0,
      memorySaver = preferences.getBool('memorySaver') ?? false,
      oledBlack = preferences.getBool('oledBlack') ?? false,
      forceWebDarkMode = preferences.getBool('forceWebDarkMode') ?? false,
      cornerRadius = preferences.getDouble('cornerRadius') ?? 16.0,
      adBlockEnabled = preferences.getBool('adBlockEnabled') ?? true,
      antiTrackingEnabled = preferences.getBool('antiTrackingEnabled') ?? true,
      antiFingerprintEnabled =
          preferences.getBool('antiFingerprintEnabled') ?? true,
      stripTrackingParams = preferences.getBool('stripTrackingParams') ?? true,
      totalBlockedAds = preferences.getInt('totalBlockedAds') ?? 0,
      totalBlockedTrackers = preferences.getInt('totalBlockedTrackers') ?? 0,
      autoPiPEnabled = preferences.getBool('autoPiPEnabled') ?? true,
      adBlockWhitelist = preferences.getStringList('adBlockWhitelist') ?? [] {
    _loadReadingList();
    _loadDownloads();
  }

  final SharedPreferences preferences;
  final List<String> favorites;
  final List<String> history;
  final List<ReadingItem> readingList = [];
  final List<DownloadItem> downloads = [];
  final List<String> adBlockWhitelist;

  SearchEngine searchEngine;
  String? home;
  String readerTheme;
  double readerFontSize;
  bool memorySaver;
  bool oledBlack;
  bool forceWebDarkMode;
  double cornerRadius;
  bool adBlockEnabled;
  bool antiTrackingEnabled;
  bool antiFingerprintEnabled;
  bool stripTrackingParams;
  bool autoPiPEnabled;
  int totalBlockedAds;
  int totalBlockedTrackers;

  void _loadReadingList() {
    final raw = preferences.getStringList('readingList');
    if (raw == null) return;
    for (final item in raw) {
      final decoded = ReadingItem.tryDecode(item);
      if (decoded != null) readingList.add(decoded);
    }
  }

  Future<void> saveReadingList() async {
    final list = [for (final item in readingList) item.encode()];
    await preferences.setStringList('readingList', list);
  }

  void _loadDownloads() {
    final raw = preferences.getStringList('browserDownloads');
    if (raw == null) return;
    for (final item in raw) {
      final decoded = DownloadItem.tryDecode(item);
      if (decoded != null) downloads.add(decoded);
    }
  }

  Future<void> saveDownloads() async {
    final list = [for (final item in downloads) item.encode()];
    await preferences.setStringList('browserDownloads', list);
  }

  static Uri resolve(
    String input, {
    SearchEngine engine = SearchEngine.duckDuckGo,
  }) {
    final value = input.trim();
    final direct = Uri.tryParse(value);
    if (direct != null && isWeb(direct) && !value.contains(RegExp(r'\s'))) {
      return direct;
    }
    final inferred = Uri.tryParse('https://$value');
    if (!value.contains('://') &&
        !value.contains(RegExp(r'\s')) &&
        inferred != null &&
        inferred.userInfo.isEmpty &&
        (inferred.host.contains('.') || inferred.host == 'localhost')) {
      return inferred;
    }
    return Uri.https(engine.host, engine.path, {engine.queryKey: value});
  }

  static bool isWeb(Uri uri) =>
      (uri.scheme == 'https' || uri.scheme == 'http') && uri.host.isNotEmpty;
}

enum SearchEngine {
  duckDuckGo('DuckDuckGo', 'duckduckgo.com', '/'),
  google('Google', 'www.google.com', '/search'),
  bing('Bing', 'www.bing.com', '/search'),
  ecosia('Ecosia', 'www.ecosia.org', '/search'),
  brave('Brave Search', 'search.brave.com', '/search'),
  yahoo('Yahoo', 'search.yahoo.com', '/search', 'p');

  const SearchEngine(this.label, this.host, this.path, [this.queryKey = 'q']);
  final String label;
  final String host;
  final String path;
  final String queryKey;
}

enum BrowserAccent {
  blue('Azul Safira', 0xFF2563EB),
  indigo('Índigo Real', 0xFF4F46E5),
  violet('Violeta Cyber', 0xFF7654C4),
  purple('Púrpura Neon', 0xFF9333EA),
  rose('Rosa Framboesa', 0xFFBA426B),
  ruby('Vermelho Rubi', 0xFFDC2626),
  orange('Laranja Sunset', 0xFFEA580C),
  amber('Âmbar Dourado', 0xFFAD6200),
  emerald('Verde Esmeralda', 0xFF059669),
  teal('Verde-petróleo', 0xFF008577),
  cyan('Ciano Oceano', 0xFF0891B2),
  slate('Grafite Minimalista', 0xFF475569);

  const BrowserAccent(this.label, this.argb);
  final String label;
  final int argb;
}

enum PageVisualFilter {
  none('Normal', Icons.brightness_auto_rounded),
  dark('Modo Noturno Inteligente', Icons.dark_mode_rounded),
  sepia('Sépia / Leitura Suave', Icons.wb_sunny_outlined),
  grayscale('Escala de Cinza (Foco)', Icons.filter_b_and_w_rounded),
  contrast('Alto Contraste', Icons.contrast_rounded);

  const PageVisualFilter(this.label, this.icon);
  final String label;
  final IconData icon;
}
