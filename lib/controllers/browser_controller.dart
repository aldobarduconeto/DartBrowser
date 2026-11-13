import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

import '../l10n/browser_locale.dart';
import '../models/browser_data.dart';
import '../models/browser_tab.dart';
import '../models/chrome_extension.dart';
import '../models/download_item.dart';
import '../models/reading_item.dart';
import '../models/tab_group.dart';
import '../services/browser_engine_service.dart';
import '../services/chrome_extension_service.dart';
import '../services/adblock_shield_service.dart';
import '../services/find_in_page_service.dart';
import '../services/picture_in_picture_service.dart';
import '../services/reader_mode_service.dart';
import '../services/read_aloud_service.dart';
import '../services/page_translate_service.dart';

export '../models/browser_tab.dart';

class BrowserController extends ChangeNotifier {
  BrowserController(this.data) {
    addons = _addonService.load();
  }

  final BrowserData data;
  late final localeNotifier = ValueNotifier<Locale?>(
    BrowserLocale.fromTag(data.preferences.getString('browserLocale')),
  );

  Future<void> setLocale(Locale? locale) async {
    if (locale == null) {
      await data.preferences.remove('browserLocale');
    } else {
      await data.preferences.setString(
        'browserLocale',
        BrowserLocale.tag(locale),
      );
    }
    localeNotifier.value = locale;
  }

  late final _addonService = BrowserAddonService(data.preferences);
  late final shieldService = AdBlockShieldService(data.preferences);
  late List<BrowserAddon> addons;

  final engine = const BrowserEngineService();
  late final themeNotifier = ValueNotifier<ThemeMode>(switch (data.preferences
      .getString('browserTheme')) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    'system' => ThemeMode.system,
    _ => switch (data.preferences.getBool('dark')) {
      true => ThemeMode.dark,
      false => ThemeMode.light,
      null => ThemeMode.system,
    },
  });

  bool get hasCompletedWelcome =>
      data.preferences.getBool('welcomeCompleted') ?? false;

  Future<bool> completeWelcome() =>
      data.preferences.setBool('welcomeCompleted', true);
  late final accentNotifier = ValueNotifier<BrowserAccent>(
    BrowserAccent.values.firstWhere(
      (accent) => accent.name == data.preferences.getString('browserAccent'),
      orElse: () => BrowserAccent.blue,
    ),
  );

  Future<void> setAccent(BrowserAccent accent) async {
    accentNotifier.value = accent;
    notifyListeners();
    await data.preferences.setString('browserAccent', accent.name);
  }

  late final oledNotifier = ValueNotifier<bool>(data.oledBlack);
  late final cornerRadiusNotifier = ValueNotifier<double>(data.cornerRadius);
  late final forceWebDarkNotifier = ValueNotifier<bool>(data.forceWebDarkMode);

  Future<void> setOledBlack(bool value) async {
    data.oledBlack = value;
    oledNotifier.value = value;
    notifyListeners();
    await data.preferences.setBool('oledBlack', value);
  }

  Future<void> setCornerRadius(double value) async {
    data.cornerRadius = value;
    cornerRadiusNotifier.value = value;
    notifyListeners();
    await data.preferences.setDouble('cornerRadius', value);
  }

  Future<void> setForceWebDarkMode(bool value) async {
    data.forceWebDarkMode = value;
    forceWebDarkNotifier.value = value;
    notifyListeners();
    await data.preferences.setBool('forceWebDarkMode', value);
    if (tabs.isNotEmpty && current.address != null) {
      await applyPageVisualFilter(
        current,
        value ? PageVisualFilter.dark : PageVisualFilter.none,
      );
    }
  }

  // TELA CHEIA (FULLSCREEN)
  final fullScreenNotifier = ValueNotifier<bool>(false);
  void toggleFullScreen() {
    fullScreenNotifier.value = !fullScreenNotifier.value;
    notifyListeners();
  }

  // LEITURA EM VOZ ALTA (READ ALOUD)
  final readAloudService = ReadAloudService();

  Future<void> startReadAloud() async {
    if (tabs.isNotEmpty) {
      await readAloudService.start(current.engine);
    }
  }

  Future<void> stopReadAloud() async {
    await readAloudService.stop();
  }

  // TRADUÇÃO INSTANTÂNEA DE PÁGINA
  Future<void> translateCurrentPage() async {
    if (tabs.isNotEmpty && current.address != null) {
      await PageTranslateService.translatePage(
        current.engine,
        current.address!,
      );
    }
  }

  // TELA DIVIDIDA (SPLIT SCREEN / DUAL VIEW)
  final splitScreenNotifier = ValueNotifier<bool>(false);
  final splitRatioNotifier = ValueNotifier<double>(0.5);
  int? secondaryTabIndex;

  void setSplitRatio(double ratio) {
    final clamped = ratio.clamp(0.2, 0.8);
    if ((splitRatioNotifier.value - clamped).abs() > 0.005) {
      splitRatioNotifier.value = clamped;
      notifyListeners();
    }
  }

  BrowserTab? get secondaryTab {
    if (secondaryTabIndex == null ||
        secondaryTabIndex! < 0 ||
        secondaryTabIndex! >= tabs.length) {
      return null;
    }
    return tabs[secondaryTabIndex!];
  }

  void toggleSplitScreen([int? secondIndex]) {
    if (splitScreenNotifier.value) {
      splitScreenNotifier.value = false;
      secondaryTabIndex = null;
    } else {
      if (tabs.length < 2) {
        addTab();
        secondaryTabIndex = tabs.length - 1;
      } else {
        secondaryTabIndex = secondIndex ?? (selected == 0 ? 1 : 0);
      }
      final second = secondaryTab;
      if (second != null) unawaited(_loadDeferred(second));
      splitScreenNotifier.value = true;
    }
    notifyListeners();
  }

  void setSecondaryTab(int index) {
    if (index >= 0 && index < tabs.length && index != selected) {
      secondaryTabIndex = index;
      unawaited(_loadDeferred(tabs[index]));
      notifyListeners();
    }
  }

  Future<void> openInSecondaryTab(String input) async {
    final tab = secondaryTab;
    if (tab == null || input.trim().isEmpty) return;
    await _openTab(tab, input, save: !tab.isIncognito);
  }

  void closeSplitScreen() {
    splitScreenNotifier.value = false;
    secondaryTabIndex = null;
    notifyListeners();
  }

  bool get showToolsDock => data.preferences.getBool('showToolsDock') ?? true;

  void setShowToolsDock(bool value) =>
      _setDisplayOption('showToolsDock', value);

  bool showsDockTool(String id) =>
      !(data.preferences.getStringList('hiddenDockTools') ?? []).contains(id);

  void setDockToolVisible(String id, bool visible) {
    final hidden = {...?data.preferences.getStringList('hiddenDockTools')};
    if (visible) {
      hidden.remove(id);
    } else {
      hidden.add(id);
    }
    unawaited(
      data.preferences.setStringList('hiddenDockTools', hidden.toList()),
    );
    notifyListeners();
  }

  bool get sidebarOnRight =>
      data.preferences.getBool('sidebarOnRight') ?? false;
  bool get showStartFavorites =>
      data.preferences.getBool('showStartFavorites') ?? true;
  bool get showStartRecent =>
      data.preferences.getBool('showStartRecent') ?? true;
  bool get startsOnHome => data.preferences.getBool('startsOnHome') ?? false;

  void setSidebarOnRight(bool value) =>
      _setDisplayOption('sidebarOnRight', value);
  void setShowStartFavorites(bool value) =>
      _setDisplayOption('showStartFavorites', value);
  void setShowStartRecent(bool value) =>
      _setDisplayOption('showStartRecent', value);
  void setStartsOnHome(bool value) => _setDisplayOption('startsOnHome', value);

  void _setDisplayOption(String key, bool value) {
    unawaited(data.preferences.setBool(key, value));
    notifyListeners();
  }

  String? _lastSavedSession;
  String? engineVersion;
  String? get fixedRuntimePath =>
      data.preferences.getString('fixedWebView2Runtime');

  Future<void> setFixedRuntimePath(String? folder) async {
    final saved = folder == null
        ? await data.preferences.remove('fixedWebView2Runtime')
        : await data.preferences.setString('fixedWebView2Runtime', folder);
    if (!saved) throw StateError('Não foi possível salvar o runtime.');
    notifyListeners();
  }

  final _pictureInPicture = PictureInPictureService();
  final readerService = const ReaderModeService();
  final findService = const FindInPageService();

  // -------------------------------------------------------------
  // NOTIFIERS GRANULARES (ALTA PERFORMANCE - EVITA REBUILDS GLOBAIS)
  // -------------------------------------------------------------
  final activeTabProgressNotifier = ValueNotifier<int>(100);
  final activeTabNavigationNotifier =
      ValueNotifier<({bool canBack, bool canForward, bool isLoading})>((
        canBack: false,
        canForward: false,
        isLoading: false,
      ));
  final findResultNotifier = ValueNotifier<FindInPageResult>(
    FindInPageResult.empty,
  );
  final findQueryNotifier = ValueNotifier<String>('');
  bool isFindInPageVisible = false;

  // -------------------------------------------------------------
  // ABAS E GRUPOS
  // -------------------------------------------------------------
  final tabs = <BrowserTab>[];
  int selected = 0;
  BrowserTab get current => tabs[selected];

  final groups = <TabGroup>[];
  final _closed = <({String address, TabGroup? group})>[];
  int _nextGroupId = 0;

  bool get verticalTabs => data.preferences.getBool('verticalTabs') ?? false;
  bool get compactTabs => data.preferences.getBool('compactTabs') ?? false;
  bool get canReopenTab => _closed.isNotEmpty;
  bool get savesHistory => data.preferences.getBool('savesHistory') ?? true;
  bool get restoresTabs => data.preferences.getBool('restoresTabs') ?? true;

  // -------------------------------------------------------------
  // COMPLEMENTOS E EXTENSÕES
  // -------------------------------------------------------------
  Future<void> saveAddons(List<BrowserAddon> value) async {
    if (!await _addonService.save(value)) {
      throw StateError('Não foi possível salvar os complementos.');
    }
    addons = List.unmodifiable(value);
    notifyListeners();
  }

  List<BrowserAddon> get activeAddonsForCurrentPage {
    final address = current.address;
    if (address == null || address.isEmpty) return const [];
    return addons
        .where((addon) => addon.enabled && addon.matchesPage(address))
        .toList();
  }

  List<BrowserAddon> get pinnedAddons =>
      addons.where((addon) => addon.enabled && addon.isPinned).toList();

  Future<void> togglePinAddon(BrowserAddon addon) async {
    final index = addons.indexWhere((a) => a.id == addon.id);
    if (index == -1) return;
    final updated = List<BrowserAddon>.from(addons);
    updated[index] = addon.withPinned(!addon.isPinned);
    await saveAddons(updated);
  }

  Future<void> toggleAddon(BrowserAddon addon) async {
    final index = addons.indexWhere((a) => a.id == addon.id);
    if (index == -1) return;
    final updated = List<BrowserAddon>.from(addons);
    final nextState = !addon.enabled;
    updated[index] = addon.withEnabled(nextState);
    await saveAddons(updated);
    if (current.address != null) {
      if (nextState) {
        await _addonService.run(current.engine, current.address!, [
          updated[index],
        ]);
      } else {
        await reload();
      }
    }
  }

  Future<void> removeAddon(BrowserAddon addon) async {
    final updated = addons.where((a) => a.id != addon.id).toList();
    await saveAddons(updated);
  }

  Future<BrowserAddon?> installExtensionFromWebStore(
    String extensionIdOrUrl,
  ) async {
    var cleanId = extensionIdOrUrl.trim();
    final match = RegExp(r'/detail/(?:[^/]+/)?([a-z]{32})').firstMatch(cleanId);
    if (match != null && match.group(1) != null) {
      cleanId = match.group(1)!;
    }
    try {
      final bytes = await ChromeExtensionService.downloadCrx(cleanId);
      final addon = _addonService.importCrxBytes(bytes);
      final updated = List<BrowserAddon>.from(
        addons.where((a) => a.id != addon.id),
      )..add(addon);
      await saveAddons(updated);
      if (current.address != null) {
        await _addonService.run(current.engine, current.address!, [addon]);
      }
      return addon;
    } catch (e) {
      debugPrint('[DartBrowser] Erro ao instalar extensão do Web Store ($cleanId): $e');
      rethrow;
    }
  }

  Future<BrowserAddon?> installExtensionFromUrl(String url) async {
    try {
      final bytes = await ChromeExtensionService.downloadCrxFromUrl(url);
      final addon = _addonService.importCrxBytes(bytes);
      final updated = List<BrowserAddon>.from(
        addons.where((a) => a.id != addon.id),
      )..add(addon);
      await saveAddons(updated);
      if (current.address != null) {
        await _addonService.run(current.engine, current.address!, [addon]);
      }
      return addon;
    } catch (e) {
      debugPrint('[DartBrowser] Erro ao instalar extensão da URL ($url): $e');
      rethrow;
    }
  }

  Future<void> toggleMuteCurrentTab() => toggleMuteTab(current);

  // -------------------------------------------------------------
  // ESCUDO DE PRIVACIDADE, ADBLOCK & ANTI-RASTREIO
  // -------------------------------------------------------------
  void _saveShieldStats() {
    unawaited(data.preferences.setInt('totalBlockedAds', data.totalBlockedAds));
    unawaited(
      data.preferences.setInt(
        'totalBlockedTrackers',
        data.totalBlockedTrackers,
      ),
    );
  }

  void toggleAdBlock(bool enabled) {
    data.adBlockEnabled = enabled;
    unawaited(data.preferences.setBool('adBlockEnabled', enabled));
    notifyListeners();
  }

  void toggleAntiTracking(bool enabled) {
    data.antiTrackingEnabled = enabled;
    unawaited(data.preferences.setBool('antiTrackingEnabled', enabled));
    notifyListeners();
  }

  void toggleAntiFingerprint(bool enabled) {
    data.antiFingerprintEnabled = enabled;
    unawaited(data.preferences.setBool('antiFingerprintEnabled', enabled));
    notifyListeners();
  }

  void toggleStripTrackingParams(bool enabled) {
    data.stripTrackingParams = enabled;
    unawaited(data.preferences.setBool('stripTrackingParams', enabled));
    notifyListeners();
  }

  bool isHostWhitelisted(String host) {
    return shieldService.isWhitelisted(host, data.adBlockWhitelist);
  }

  void toggleWhitelistHost(String host) {
    final clean = host.toLowerCase().trim();
    if (clean.isEmpty) return;
    if (isHostWhitelisted(clean)) {
      data.adBlockWhitelist.removeWhere((w) => w.toLowerCase().trim() == clean);
    } else {
      data.adBlockWhitelist.add(clean);
    }
    unawaited(
      data.preferences.setStringList('adBlockWhitelist', data.adBlockWhitelist),
    );
    notifyListeners();
  }

  void clearBlockStats() {
    data.totalBlockedAds = 0;
    data.totalBlockedTrackers = 0;
    _saveShieldStats();
    notifyListeners();
  }

  // -------------------------------------------------------------
  // DIAGNÓSTICO E PIP
  // -------------------------------------------------------------
  bool get canInspectPage =>
      current.address != null &&
      current.progress == 100 &&
      current.error == null;

  Future<Map<String, bool>> inspectCurrentPage() async {
    if (!canInspectPage) throw StateError('Abra uma página primeiro.');
    final tab = current;
    final address = tab.address;
    await _ensureConfigured(tab);
    final result = await engine.inspectPage(tab.engine);
    if (!tabs.contains(tab) || current != tab || tab.address != address) {
      throw StateError('A página mudou durante a verificação.');
    }
    return result;
  }

  Future<bool> enterAndroidPictureInPicture() =>
      _pictureInPicture.enterAndroidWindow();

  Future<void> togglePictureInPicture() async {
    final tab = current;
    if (tab.address != null) {
      await _pictureInPicture.enterPiP(tab.engine);
    }
  }

  Future<void> exitPictureInPicture() async {
    final tab = current;
    if (tab.address != null) {
      await _pictureInPicture.exitPiP(tab.engine);
    }
  }

  void setAutoPiPEnabled(bool value) {
    data.autoPiPEnabled = value;
    unawaited(data.preferences.setBool('autoPiPEnabled', value));
    notifyListeners();
  }

  // -------------------------------------------------------------
  // NAVEGAÇÃO E SESSÃO
  // -------------------------------------------------------------
  void setVerticalTabs(bool value) {
    unawaited(data.preferences.setBool('verticalTabs', value));
    notifyListeners();
  }

  void toggleCompactTabs() {
    unawaited(data.preferences.setBool('compactTabs', !compactTabs));
    notifyListeners();
  }

  void createGroup(BrowserTab tab, String name, int color) {
    if (!tabs.contains(tab)) return;
    final group = TabGroup(id: _nextGroupId++, name: name, color: color);
    groups.add(group);
    moveToGroup(tab, group);
  }

  void placeTab(
    BrowserTab tab,
    BrowserTab anchor, {
    required bool after,
    bool ungroup = false,
  }) {
    if (identical(tab, anchor) ||
        !tabs.contains(tab) ||
        !tabs.contains(anchor)) {
      return;
    }
    final active = current;
    final secondary = secondaryTab;
    tabs.remove(tab);
    tab.group = ungroup ? null : anchor.group;
    final anchorIndex = tabs.indexOf(anchor);
    final insertIndex = (anchorIndex + (after ? 1 : 0)).clamp(0, tabs.length);
    tabs.insert(insertIndex, tab);
    selected = tabs.indexOf(active);
    secondaryTabIndex = secondary == null ? null : tabs.indexOf(secondary);
    _saveSession();
    notifyListeners();
  }

  void moveToGroup(BrowserTab tab, TabGroup? group) {
    if (!tabs.contains(tab) || (group != null && !groups.contains(group))) {
      return;
    }
    tab.group = group;
    if (group != null) group.collapsed = false;
    _saveSession();
    notifyListeners();
  }

  void editGroup(TabGroup group, String name, int color) {
    if (!groups.contains(group)) return;
    group.name = name;
    group.color = color;
    _saveSession();
    notifyListeners();
  }

  void toggleGroup(TabGroup group) {
    group.collapsed = !group.collapsed;
    _saveSession();
    notifyListeners();
  }

  void removeGroup(TabGroup group) {
    groups.remove(group);
    for (final tab in tabs.where((tab) => tab.group == group)) {
      tab.group = null;
    }
    _saveSession();
    notifyListeners();
  }

  Future<void> setSavesHistory(bool value) async {
    await data.preferences.setBool('savesHistory', value);
    notifyListeners();
  }

  Future<void> setRestoresTabs(bool value) async {
    await data.preferences.setBool('restoresTabs', value);
    if (value) {
      _saveSession();
    } else {
      _lastSavedSession = null;
      await data.preferences.remove('groupedSession');
      await data.preferences.remove('session');
      await data.preferences.remove('selectedTab');
    }
    notifyListeners();
  }

  Future<void> clearCookies() async {
    await WebViewCookieManager().clearCookies();
  }

  Future<void> clearCache() async {
    await Future.wait([
      for (final tab in List.of(tabs))
        if (tab.initialization case final ready?)
          ready.then((_) => tab.engine.clearCache()),
    ]);
  }

  void restoreSession() {
    if (!restoresTabs) {
      addTab(address: startsOnHome ? data.home : null);
      return;
    }
    final legacy = data.preferences.getStringList('session') ?? [];
    var saved = [
      for (final address in legacy)
        (address: address, group: null as TabGroup?),
    ];
    var index = data.preferences.getInt('selectedTab') ?? 0;
    final encoded = data.preferences.getString('groupedSession');
    _lastSavedSession = encoded;
    if (encoded != null) {
      try {
        final session = jsonDecode(encoded) as Map<String, dynamic>;
        final byId = {
          for (final item in session['groups'] as List<dynamic>)
            (item as Map<String, dynamic>)['id']: TabGroup.fromJson(item),
        };
        final restoredIndex = session['selected'] as int;
        saved = [
          for (final item in session['tabs'] as List<dynamic>)
            (address: item['address'] as String, group: byId[item['group']]),
        ];
        index = restoredIndex;
        groups.addAll(byId.values);
        for (final group in groups) {
          if (group.id >= _nextGroupId) _nextGroupId = group.id + 1;
        }
      } on FormatException {
        // Recuperar sessão legada
      } on TypeError {
        // Recuperar sessão legada
      }
    }
    if (saved.isEmpty) {
      addTab(address: startsOnHome ? data.home : null);
      return;
    }
    for (final entry in saved) {
      tabs.add(
        BrowserTab()
          ..group = entry.group
          ..address = entry.address.isEmpty ? null : entry.address,
      );
    }
    selected = index.clamp(0, tabs.length - 1);
    unawaited(_loadDeferred(current));
    _syncActiveNotifiers();
    notifyListeners();
  }

  void addTab({
    String? address,
    TabGroup? group,
    bool save = true,
    bool isIncognito = false,
    bool notify = true,
  }) {
    final leavingTab = tabs.isNotEmpty && selected < tabs.length
        ? current
        : null;
    final tab = BrowserTab(isIncognito: isIncognito)..group = group;
    if (save && group != null) group.collapsed = false;
    tabs.add(tab);
    selected = tabs.length - 1;

    // Auto PiP ao sair da aba com vídeo
    if (leavingTab != null &&
        leavingTab.initialization != null &&
        leavingTab.address != null &&
        data.autoPiPEnabled) {
      unawaited(_pictureInPicture.enterPiP(leavingTab.engine));
    }
    if (notify) {
      _syncActiveNotifiers();
      notifyListeners();
    }
    if (address != null && address.isNotEmpty) {
      unawaited(open(address, save: save && !isIncognito, notify: notify));
    } else if (save && !isIncognito) {
      _saveSession();
    }
  }

  void addIncognitoTab({String? address}) {
    addTab(address: address, isIncognito: true, save: false);
  }

  Future<void> _ensureConfigured(BrowserTab tab) =>
      tab.initialization ??= _configure(tab);

  Future<void> _loadDeferred(BrowserTab tab) async {
    final address = tab.address;
    if (address == null || tab.initialization != null) return;
    await _openTab(tab, address, save: false);
  }

  Future<void> _configure(BrowserTab tab) async {
    await tab.engine.setJavaScriptMode(JavaScriptMode.unrestricted);
    try {
      await tab.engine.addJavaScriptChannel(
        'DartLinkHandler',
        onMessageReceived: (JavaScriptMessage msg) {
          _handleLinkMessage(msg.message, tab: tab);
        },
      );
    } catch (_) {}
    final hasMediaScript = await _pictureInPicture.install(tab.engine);
    final contextScript = await tab.engine.tryAddUserScript(
      const WebViewUserScript(
        source: _jsLinkContextScript,
        injectionTime: WebViewUserScriptInjectionTime.documentEnd,
      ),
    );
    await tab.engine.setNavigationDelegate(
      NavigationDelegate(
        onNavigationRequest: (request) {
          if (request.url.startsWith('dart-link://')) {
            _handleLinkMessage(
              request.url.substring('dart-link://'.length),
              tab: tab,
            );
            return NavigationDecision.prevent;
          }
          if (request.url.startsWith('dart-shield://stats')) {
            final uri = Uri.tryParse(request.url);
            if (uri != null) {
              final ads = int.tryParse(uri.queryParameters['ads'] ?? '0') ?? 0;
              final trackers =
                  int.tryParse(uri.queryParameters['trackers'] ?? '0') ?? 0;
              if (ads > 0 || trackers > 0) {
                tab.blockedAdsCount += ads;
                tab.blockedTrackersCount += trackers;
                data.totalBlockedAds += ads;
                data.totalBlockedTrackers += trackers;
                _saveShieldStats();
                notifyListeners();
              }
            }
            return NavigationDecision.prevent;
          }
          final uri = Uri.tryParse(request.url);
          if (uri == null || !BrowserData.isWeb(uri)) {
            return NavigationDecision.prevent;
          }

          // Intercepta downloads de extensões da Chrome Web Store ou pacotes .crx
          if (request.url.contains('clients2.google.com/service/update2/crx') ||
              (request.url.endsWith('.crx') &&
                  !request.url.startsWith('file:'))) {
            final extMatch =
                RegExp(r'[?&]x=id%3D([a-z]{32})').firstMatch(request.url);
            final extId = extMatch?.group(1);
            if (extId != null) {
              unawaited(installExtensionFromWebStore(extId));
            } else {
              unawaited(installExtensionFromUrl(request.url));
            }
            return NavigationDecision.prevent;
          }

          final blockResult = shieldService.shouldBlockRequest(
            requestUri: uri,
            mainHost: tab.host,
            adBlockEnabled: data.adBlockEnabled,
            antiTrackingEnabled: data.antiTrackingEnabled,
            whitelist: data.adBlockWhitelist,
          );
          if (blockResult.blocked) {
            if (blockResult.type == BlockType.ad) {
              tab.blockedAdsCount++;
              data.totalBlockedAds++;
            } else if (blockResult.type == BlockType.tracker) {
              tab.blockedTrackersCount++;
              data.totalBlockedTrackers++;
            }
            _saveShieldStats();
            notifyListeners();
            return NavigationDecision.prevent;
          }

          return NavigationDecision.navigate;
        },
        onPageStarted: (url) {
          final uri = Uri.tryParse(url);
          if (!tabs.contains(tab) || uri == null || !BrowserData.isWeb(uri)) {
            return;
          }
          tab.blockedAdsCount = 0;
          tab.blockedTrackersCount = 0;

          if (data.stripTrackingParams) {
            final clean = shieldService.cleanUrl(url);
            if (clean != url) {
              tab.engine.loadRequest(Uri.parse(clean));
              return;
            }
          }

          if (!isHostWhitelisted(tab.host)) {
            final shieldScript = shieldService.getShieldInjectionScript(
              blockAds: data.adBlockEnabled,
              antiTrack: data.antiTrackingEnabled,
              antiFingerprint: data.antiFingerprintEnabled,
              host: tab.host,
            );
            tab.engine.runJavaScript(shieldScript);
          }

          tab.address = url;
          tab.title = null;
          tab.faviconUrl = null;
          tab.error = null;
          tab.progress = 0;
          tab.isReaderMode = false;
          tab.touch();

          if (tabs.contains(tab) && current == tab) {
            activeTabProgressNotifier.value = 0;
            _syncActiveNotifiers();
          }

          if (!tab.isIncognito) _saveSession();
          _update(tab);
        },
        onUrlChange: (change) {
          final uri = Uri.tryParse(change.url ?? '');
          if (tabs.contains(tab) && uri != null && BrowserData.isWeb(uri)) {
            tab.address = change.url;
            tab.touch();
            if (!tab.isIncognito) _saveSession();
            _update(tab);
            tab.engine.runJavaScript(_jsLinkContextScript);
          }
        },
        onProgress: (progress) {
          tab.progress = progress;
          // OTIMIZAÇÃO CRÍTICA: se a aba for a ativa, atualizamos apenas o notifier do progresso
          // em vez de rebuildar toda a árvore do app centenas de vezes
          if (tabs.contains(tab) && current == tab) {
            activeTabProgressNotifier.value = progress;
            activeTabNavigationNotifier.value = (
              canBack: tab.canGoBack,
              canForward: tab.canGoForward,
              isLoading: progress < 100,
            );
          }
        },
        onWebResourceError: (error) {
          if (error.isForMainFrame != true) return;
          tab.error = 'Não foi possível carregar esta página.';
          tab.progress = 100;
          if (tabs.contains(tab) && current == tab) {
            activeTabProgressNotifier.value = 100;
            _syncActiveNotifiers();
          }
          _update(tab);
        },
        onPageFinished: (url) async {
          if (!tabs.contains(tab) || tab.address != url || tab.error != null) {
            return;
          }
          tab.progress = 100;
          tab.touch();

          if (savesHistory && !tab.isIncognito) {
            data.history.remove(url);
            data.history.insert(0, url);
            if (data.history.length > 300) data.history.removeLast();
          }

          if (tabs.contains(tab) && current == tab) {
            activeTabProgressNotifier.value = 100;
            _syncActiveNotifiers();
          }
          _update(tab);

          await Future.wait([
            if (savesHistory && !tab.isIncognito)
              data.preferences.setStringList('history', List.of(data.history)),
            _refreshNavigation(tab),
            _refreshTitle(tab, url),
            _refreshFavicon(tab, url),
            _addonService.run(tab.engine, url, addons),
            if (!hasMediaScript)
              _pictureInPicture.installForCurrentPage(tab.engine),
            if (tab.zoomLevel != 1.0) _applyZoom(tab),
            if (tab.visualFilter != PageVisualFilter.none ||
                data.forceWebDarkMode)
              applyPageVisualFilter(
                tab,
                tab.visualFilter != PageVisualFilter.none
                    ? tab.visualFilter
                    : PageVisualFilter.dark,
              ),
            if (!isHostWhitelisted(tab.host))
              tab.engine.runJavaScript(
                shieldService.getShieldInjectionScript(
                  blockAds: data.adBlockEnabled,
                  antiTrack: data.antiTrackingEnabled,
                  antiFingerprint: data.antiFingerprintEnabled,
                  host: tab.host,
                ),
              ),
            tab.engine.runJavaScript(_jsLinkContextScript),
          ]);
        },
      ),
    );
  }

  Future<void> _refreshTitle(BrowserTab tab, String url) async {
    final title = await tab.engine.getTitle();
    if (tab.address != url) return;
    tab.title = title;
    _update(tab);
  }

  Future<void> _refreshFavicon(BrowserTab tab, String url) async {
    try {
      final raw = await tab.engine.runJavaScriptReturningResult(r"""
        (function() {
          var links = Array.from(document.querySelectorAll('link[rel*="icon"], link[rel="apple-touch-icon"]'));
          if (links.length > 0) {
            var best = links.find(function(l) {
              var s = l.getAttribute('sizes') || '';
              return s.indexOf('32') !== -1 || s.indexOf('48') !== -1 || s.indexOf('64') !== -1 || s.indexOf('128') !== -1;
            }) || links.find(function(l) {
              var h = l.href || '';
              return h.indexOf('.png') !== -1 || h.indexOf('.svg') !== -1;
            }) || links[0];
            return best && best.href ? best.href : '';
          }
          return '';
        })()
      """);
      if (tab.address != url) return;
      var icon = raw.toString().trim();
      if (icon.startsWith('"') && icon.endsWith('"') && icon.length > 2) {
        icon = icon.substring(1, icon.length - 1);
      }
      if (icon.isNotEmpty && icon != 'null' && icon != 'undefined') {
        tab.faviconUrl = icon;
        _update(tab);
      }
    } catch (_) {}
  }

  Timer? _sessionDebounceTimer;

  void _saveSession() {
    if (!restoresTabs) return;
    _sessionDebounceTimer?.cancel();
    _sessionDebounceTimer = Timer(const Duration(milliseconds: 500), () {
      final nonIncognitoTabs = tabs.where((t) => !t.isIncognito).toList();
      final nonIncognitoSelected = nonIncognitoTabs.indexOf(current);
      final session = jsonEncode({
        'groups': [for (final group in groups) group.toJson()],
        'tabs': [
          for (final tab in nonIncognitoTabs)
            {'address': tab.address ?? '', 'group': tab.group?.id},
        ],
        'selected': nonIncognitoSelected != -1 ? nonIncognitoSelected : 0,
      });
      if (_lastSavedSession == session) return;
      _lastSavedSession = session;
      unawaited(
        data.preferences.setString('groupedSession', session).then((saved) {
          if (!saved && _lastSavedSession == session) _lastSavedSession = null;
        }),
      );
    });
  }

  // ECONOMIZADOR DE MEMÓRIA AUTOMÁTICO (LIBERA RAM DE ABAS INATIVAS)
  void checkMemorySaver() {
    if (!data.memorySaver || tabs.length <= 2) return;
    final now = DateTime.now();
    for (var i = 0; i < tabs.length; i++) {
      final tab = tabs[i];
      if (tab != current &&
          tab != secondaryTab &&
          !tab.isPinned &&
          !tab.isSuspended &&
          tab.address != null) {
        if (now.difference(tab.lastAccessed).inMinutes >= 25) {
          suspendTab(tab);
        }
      }
    }
  }

  Future<void> _refreshNavigation(BrowserTab tab) async {
    tab.canGoBack = await tab.engine.canGoBack();
    tab.canGoForward = await tab.engine.canGoForward();
    if (tabs.contains(tab) && current == tab) {
      _syncActiveNotifiers();
    }
    _update(tab);
  }

  void _syncActiveNotifiers() {
    if (tabs.isEmpty) return;
    final tab = current;
    activeTabProgressNotifier.value = tab.progress;
    activeTabNavigationNotifier.value = (
      canBack: tab.canGoBack,
      canForward: tab.canGoForward,
      isLoading: tab.progress < 100,
    );
  }

  void _update(BrowserTab tab) {
    if (tabs.contains(tab)) notifyListeners();
  }

  void select(int index) {
    if (index < 0 || index >= tabs.length) return;
    if (index == selected) return;
    final leavingTab = current;
    selected = index;
    final enteringTab = current;

    // PiP automático ao sair da aba com vídeo e desativação ao voltar para a página
    if (data.autoPiPEnabled) {
      if (leavingTab.initialization != null && leavingTab.address != null) {
        unawaited(_pictureInPicture.enterPiP(leavingTab.engine));
      }
      if (enteringTab.initialization != null && enteringTab.address != null) {
        unawaited(_pictureInPicture.exitPiP(enteringTab.engine));
      }
    }

    enteringTab.touch();
    unawaited(_loadDeferred(enteringTab));

    // Se a aba estava suspensa, resumir automaticamente
    if (enteringTab.isSuspended) {
      resumeTab(enteringTab);
    }

    _syncActiveNotifiers();
    checkMemorySaver();
    _saveSession();
    notifyListeners();
  }

  void closeTab(int index) {
    if (index < 0 || index >= tabs.length) return;
    final wasSelected = index == selected;
    final closed = tabs.removeAt(index);
    if (closed.initialization != null && closed.address != null) {
      unawaited(_pictureInPicture.exitPiP(closed.engine));
    }
    if (closed.address != null && !closed.isIncognito) {
      _closed.add((address: closed.address!, group: closed.group));
      if (_closed.length > 25) _closed.removeAt(0);
    }
    if (tabs.isEmpty) {
      addTab();
      return;
    }
    if (selected > index || selected == tabs.length) selected--;

    if (wasSelected) unawaited(_loadDeferred(current));
    if (wasSelected &&
        data.autoPiPEnabled &&
        current.initialization != null &&
        current.address != null) {
      unawaited(_pictureInPicture.exitPiP(current.engine));
    }

    _syncActiveNotifiers();
    checkMemorySaver();
    _saveSession();
    notifyListeners();
  }

  void closeOtherTabs(int keepIndex) {
    if (keepIndex < 0 || keepIndex >= tabs.length) return;
    final keepTab = tabs[keepIndex];
    tabs.retainWhere((t) => t == keepTab);
    selected = 0;
    unawaited(_loadDeferred(current));
    _syncActiveNotifiers();
    checkMemorySaver();
    _saveSession();
    notifyListeners();
  }

  void closeTabsToTheRight(int fromIndex) {
    if (fromIndex < 0 || fromIndex >= tabs.length - 1) return;
    tabs.removeRange(fromIndex + 1, tabs.length);
    if (selected >= tabs.length) selected = tabs.length - 1;
    unawaited(_loadDeferred(current));
    _syncActiveNotifiers();
    checkMemorySaver();
    _saveSession();
    notifyListeners();
  }

  void moveTab(int oldIndex, int newIndex) {
    if (oldIndex < 0 ||
        oldIndex >= tabs.length ||
        newIndex < 0 ||
        newIndex >= tabs.length) {
      return;
    }
    final currentTab = current;
    final tab = tabs.removeAt(oldIndex);
    tabs.insert(newIndex, tab);
    selected = tabs.indexOf(currentTab);
    _saveSession();
    notifyListeners();
  }

  void togglePinTab(BrowserTab tab) {
    tab.isPinned = !tab.isPinned;
    // Se foi fixada, mover para a área de abas fixadas (início da lista)
    if (tab.isPinned) {
      final currentTab = current;
      tabs.remove(tab);
      int insertIndex = 0;
      while (insertIndex < tabs.length && tabs[insertIndex].isPinned) {
        insertIndex++;
      }
      tabs.insert(insertIndex, tab);
      selected = tabs.indexOf(currentTab);
    }
    _saveSession();
    notifyListeners();
  }

  Future<void> toggleMuteTab(BrowserTab tab) async {
    tab.isMuted = !tab.isMuted;
    try {
      await tab.engine.runJavaScript('''
        (() => {
          document.querySelectorAll('video, audio').forEach(el => {
            el.muted = ${tab.isMuted};
          });
        })();
      ''');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> setUserAgent(BrowserTab tab, String? ua) async {
    tab.customUserAgent = ua;
    try {
      if (ua != null) {
        await tab.engine.setUserAgent(ua);
      }
      await reload();
    } catch (_) {}
    notifyListeners();
  }

  Future<void> open(
    String input, {
    bool save = true,
    bool notify = true,
  }) async {
    if (input.trim().isEmpty) return;
    await _openTab(current, input, save: save, notify: notify);
  }

  Future<void> _openTab(
    BrowserTab tab,
    String input, {
    required bool save,
    bool notify = true,
  }) async {
    tab.touch();
    final uri = BrowserData.resolve(input, engine: data.searchEngine);
    tab.address = uri.toString();
    tab.title = null;
    tab.isReaderMode = false;
    tab.isSuspended = false;
    if (save && !tab.isIncognito) _saveSession();
    tab.error = null;
    tab.progress = 0;
    if (notify) {
      if (identical(current, tab)) activeTabProgressNotifier.value = 0;
      _update(tab);
    }
    try {
      await _ensureConfigured(tab);
      if (tabs.contains(tab) && tab.address == uri.toString()) {
        await tab.engine.loadRequest(uri);
      }
    } on Exception {
      if (!tabs.contains(tab) || tab.address != uri.toString()) return;
      tab.error = 'Não foi possível abrir este endereço.';
      tab.progress = 100;
      activeTabProgressNotifier.value = 100;
      _update(tab);
    }
  }

  void duplicateTab([BrowserTab? target]) {
    final tab = target ?? current;
    addTab(
      address: tab.address,
      group: tab.group,
      isIncognito: tab.isIncognito,
    );
  }

  void reopenTab() {
    if (!canReopenTab) return;
    final closed = _closed.removeLast();
    addTab(
      address: closed.address,
      group: groups.contains(closed.group) ? closed.group : null,
    );
  }

  Future<void> stop() async {
    final tab = current;
    await _ensureConfigured(tab);
    await tab.engine.stopLoading();
    tab.progress = 100;
    activeTabProgressNotifier.value = 100;
    _update(tab);
    await _refreshNavigation(tab);
  }

  Future<void> goBack() async {
    await current.engine.goBack();
  }

  Future<void> goForward() async {
    await current.engine.goForward();
  }

  Future<void> reload() async {
    final tab = current;
    tab.touch();
    if (tab.error != null && tab.address != null) {
      await _openTab(tab, tab.address!, save: false);
      return;
    }
    await tab.engine.reload();
  }

  // -------------------------------------------------------------
  // MODO LEITURA (DISTRACTION-FREE READER MODE)
  // -------------------------------------------------------------
  Future<bool> toggleReaderMode() async {
    final tab = current;
    if (tab.address == null || tab.progress < 100) return false;

    if (tab.isReaderMode) {
      await readerService.deactivate(tab.engine);
      tab.isReaderMode = false;
      notifyListeners();
      return false;
    } else {
      final success = await readerService.activate(
        tab.engine,
        theme: data.readerTheme,
        fontSize: data.readerFontSize,
      );
      tab.isReaderMode = success;
      notifyListeners();
      return success;
    }
  }

  Future<void> setReaderTheme(String theme) async {
    data.readerTheme = theme;
    await data.preferences.setString('readerTheme', theme);
    if (current.isReaderMode) {
      await readerService.updateStyle(
        current.engine,
        theme: theme,
        fontSize: data.readerFontSize,
      );
    }
    notifyListeners();
  }

  Future<void> setReaderFontSize(double size) async {
    data.readerFontSize = size;
    await data.preferences.setDouble('readerFontSize', size);
    if (current.isReaderMode) {
      await readerService.updateStyle(
        current.engine,
        theme: data.readerTheme,
        fontSize: size,
      );
    }
    notifyListeners();
  }

  // -------------------------------------------------------------
  // CONTROLE DE ZOOM
  // -------------------------------------------------------------
  Future<void> _applyZoom(BrowserTab tab) async {
    try {
      await tab.engine.runJavaScript(
        'document.body.style.zoom = "${tab.zoomLevel}";',
      );
    } catch (_) {}
  }

  Future<void> setZoom(double level) async {
    final tab = current;
    tab.zoomLevel = level.clamp(0.5, 3.0);
    await _applyZoom(tab);
    notifyListeners();
  }

  Future<void> zoomIn() => setZoom((current.zoomLevel + 0.1).clamp(0.5, 3.0));
  Future<void> zoomOut() => setZoom((current.zoomLevel - 0.1).clamp(0.5, 3.0));
  Future<void> resetZoom() => setZoom(1.0);

  // -------------------------------------------------------------
  // LOCALIZAR NA PÁGINA (FIND IN PAGE)
  // -------------------------------------------------------------
  void openFindInPage() {
    isFindInPageVisible = true;
    notifyListeners();
  }

  void closeFindInPage() {
    isFindInPageVisible = false;
    findQueryNotifier.value = '';
    findResultNotifier.value = FindInPageResult.empty;
    unawaited(findService.clear(current.engine));
    notifyListeners();
  }

  Future<void> findInPage(String query) async {
    findQueryNotifier.value = query;
    final res = await findService.find(current.engine, query);
    findResultNotifier.value = res;
  }

  Future<void> findNext() async {
    final res = await findService.step(current.engine, forward: true);
    findResultNotifier.value = res;
  }

  Future<void> findPrevious() async {
    final res = await findService.step(current.engine, forward: false);
    findResultNotifier.value = res;
  }

  // -------------------------------------------------------------
  // ECONOMIZADOR DE MEMÓRIA (TAB SUSPEND)
  // -------------------------------------------------------------
  Future<void> suspendTab(BrowserTab tab) async {
    if (tab == current ||
        tab.isSuspended ||
        tab.address == null ||
        tab.initialization == null) {
      return;
    }
    tab.isSuspended = true;
    // Parar de carregar e limpar cache de rendering
    try {
      await tab.engine.stopLoading();
      await tab.engine.loadHtmlString('''
        <!DOCTYPE html>
        <html>
        <head><meta charset="utf-8"></head>
        <body style="background:#1a1a1a;color:#aaa;font-family:sans-serif;display:flex;height:100vh;align-items:center;justify-content:center;">
          <p>💤 Aba hibernada para economizar memória. Clique nela para reativar.</p>
        </body>
        </html>
      ''');
    } catch (_) {}
    notifyListeners();
  }

  Future<void> resumeTab(BrowserTab tab) async {
    if (!tab.isSuspended || tab.address == null) return;
    tab.isSuspended = false;
    await _openTab(tab, tab.address!, save: false);
  }

  // -------------------------------------------------------------
  // LISTA DE LEITURA ("LER DEPOIS")
  // -------------------------------------------------------------
  bool isInReadingList(String url) =>
      data.readingList.any((item) => item.url == url);

  Future<void> toggleReadingListCurrent() async {
    final address = current.address;
    if (address == null) return;
    if (isInReadingList(address)) {
      data.readingList.removeWhere((item) => item.url == address);
    } else {
      data.readingList.insert(
        0,
        ReadingItem(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
          url: address,
          title: current.title ?? current.host,
          addedAt: DateTime.now(),
        ),
      );
    }
    await data.saveReadingList();
    notifyListeners();
  }

  Future<void> removeReadingItem(String id) async {
    data.readingList.removeWhere((item) => item.id == id);
    await data.saveReadingList();
    notifyListeners();
  }

  Future<void> addToReadingList(String url, String title) async {
    if (!isInReadingList(url)) {
      data.readingList.insert(
        0,
        ReadingItem(
          id: DateTime.now().microsecondsSinceEpoch.toString(),
          url: url,
          title: title.isEmpty ? url : title,
          addedAt: DateTime.now(),
        ),
      );
      await data.saveReadingList();
      notifyListeners();
    }
  }

  Future<void> toggleReadingItemStatus(String id) async {
    final idx = data.readingList.indexWhere((item) => item.id == id);
    if (idx != -1) {
      final item = data.readingList[idx];
      data.readingList[idx] = item.copyWith(isRead: !item.isRead);
      await data.saveReadingList();
      notifyListeners();
    }
  }

  // -------------------------------------------------------------
  // CONFIGURAÇÕES GERAIS E DADOS
  // -------------------------------------------------------------
  Future<void> setHome(String? address) async {
    data.home = address;
    notifyListeners();
    if (address == null) {
      await data.preferences.remove('home');
    } else {
      await data.preferences.setString('home', address);
    }
  }

  Future<void> setSearchEngine(SearchEngine engine) async {
    data.searchEngine = engine;
    notifyListeners();
    await data.preferences.setString('searchEngine', engine.name);
  }

  Future<void> removeEntry(String address, {required bool history}) async {
    final entries = history ? data.history : data.favorites;
    entries.remove(address);
    notifyListeners();
    await data.preferences.setStringList(
      history ? 'history' : 'favorites',
      List.of(entries),
    );
  }

  Future<int> bookmarkOpenTabs() async {
    final addresses = <String>{...data.favorites};
    final additions = [
      for (final tab in tabs)
        if (!tab.isIncognito)
          if (tab.address case final String url)
            if (BrowserData.isWeb(Uri.tryParse(url) ?? Uri()) &&
                addresses.add(url))
              url,
    ];
    if (additions.isEmpty) return 0;
    data.favorites.insertAll(0, additions);
    notifyListeners();
    await data.preferences.setStringList('favorites', List.of(data.favorites));
    return additions.length;
  }

  Future<void> toggleFavorite() async {
    final address = current.address;
    if (address == null) return;
    if (!data.favorites.remove(address)) data.favorites.insert(0, address);
    notifyListeners();
    await data.preferences.setStringList('favorites', List.of(data.favorites));
  }

  Future<void> clearHistory() async {
    data.history.clear();
    notifyListeners();
    await data.preferences.remove('history');
  }

  Future<void> setTheme(ThemeMode mode) async {
    themeNotifier.value = mode;
    notifyListeners();
    await data.preferences.setString('browserTheme', mode.name);
  }

  // FILTROS VISUAIS NA PÁGINA (MODO NOTURNO INTELIGENTE, SÉPIA, CONTRASTE, ETC.)
  Future<void> applyPageVisualFilter(
    BrowserTab tab,
    PageVisualFilter filter,
  ) async {
    tab.visualFilter = filter;
    _update(tab);
    final String js;
    switch (filter) {
      case PageVisualFilter.none:
        if (data.forceWebDarkMode) {
          js = _jsDarkFilter;
        } else {
          js = '''
            (function() {
              var s = document.getElementById('__dart_browser_filter__');
              if (s) { s.remove(); }
            })();
          ''';
        }
      case PageVisualFilter.dark:
        js = _jsDarkFilter;
      case PageVisualFilter.sepia:
        js = '''
          (function() {
            var s = document.getElementById('__dart_browser_filter__') || document.createElement('style');
            s.id = '__dart_browser_filter__';
            s.textContent = 'html { filter: sepia(75%) contrast(90%) brightness(95%) !important; background-color: #fbf0d9 !important; }';
            if (!s.parentNode && document.head) document.head.appendChild(s);
          })();
        ''';
      case PageVisualFilter.grayscale:
        js = '''
          (function() {
            var s = document.getElementById('__dart_browser_filter__') || document.createElement('style');
            s.id = '__dart_browser_filter__';
            s.textContent = 'html { filter: grayscale(100%) !important; }';
            if (!s.parentNode && document.head) document.head.appendChild(s);
          })();
        ''';
      case PageVisualFilter.contrast:
        js = '''
          (function() {
            var s = document.getElementById('__dart_browser_filter__') || document.createElement('style');
            s.id = '__dart_browser_filter__';
            s.textContent = 'html { filter: contrast(160%) brightness(105%) !important; }';
            if (!s.parentNode && document.head) document.head.appendChild(s);
          })();
        ''';
    }
    try {
      await tab.engine.runJavaScript(js);
    } catch (_) {}
  }

  static const String _jsDarkFilter = '''
    (function() {
      var s = document.getElementById('__dart_browser_filter__') || document.createElement('style');
      s.id = '__dart_browser_filter__';
      s.textContent = 'html { filter: invert(90%) hue-rotate(180deg) !important; background-color: #121212 !important; } img, video, canvas, svg, [style*="background-image"] { filter: invert(100%) hue-rotate(180deg) !important; }';
      if (!s.parentNode && document.head) document.head.appendChild(s);
    })();
  ''';

  // GERENCIAMENTO DE DOWNLOADS
  Future<void> recordDownload(
    String url,
    String fileName,
    int fileSize, {
    String? filePath,
  }) async {
    final item = DownloadItem(
      id: DateTime.now().microsecondsSinceEpoch.toString(),
      url: url,
      fileName: fileName,
      fileSize: fileSize,
      downloadedAt: DateTime.now(),
      filePath: filePath,
    );
    data.downloads.insert(0, item);
    if (data.downloads.length > 200) data.downloads.removeLast();
    notifyListeners();
    await data.saveDownloads();
  }

  Future<void> removeDownload(String id) async {
    data.downloads.removeWhere((d) => d.id == id);
    notifyListeners();
    await data.saveDownloads();
  }

  Future<void> clearDownloads() async {
    data.downloads.clear();
    notifyListeners();
    await data.saveDownloads();
  }

  // EXPORTAÇÃO E IMPORTAÇÃO DE FAVORITOS (FORMATO NETSCAPE HTML PADRÃO)
  String exportBookmarksHtml() {
    final buffer = StringBuffer();
    buffer.writeln('<!DOCTYPE NETSCAPE-Bookmark-file-1>');
    buffer.writeln(
      '<META HTTP-EQUIV="Content-Type" CONTENT="text/html; charset=UTF-8">',
    );
    buffer.writeln('<TITLE>Bookmarks</TITLE>');
    buffer.writeln('<H1>Bookmarks</H1>');
    buffer.writeln('<DL><p>');
    buffer.writeln('    <DT><H3>DartBrowser Favorites</H3>');
    buffer.writeln('    <DL><p>');
    for (final url in data.favorites) {
      final uri = Uri.tryParse(url);
      final label = uri != null && uri.host.isNotEmpty ? uri.host : url;
      buffer.writeln('        <DT><A HREF="$url">$label</A>');
    }
    buffer.writeln('    </DL><p>');
    buffer.writeln('</DL><p>');
    return buffer.toString();
  }

  int importBookmarksHtml(String html) {
    final regex = RegExp(
      r'<A\s+(?:[^>]*?\s+)?HREF="([^"]+)"[^>]*>(.*?)</A>',
      caseSensitive: false,
    );
    final matches = regex.allMatches(html);
    int count = 0;
    for (final match in matches) {
      final url = match.group(1)?.trim();
      if (url != null && url.isNotEmpty) {
        final uri = Uri.tryParse(url);
        if (uri != null && BrowserData.isWeb(uri)) {
          if (!data.favorites.contains(url)) {
            data.favorites.add(url);
            count++;
          }
        }
      }
    }
    if (count > 0) {
      notifyListeners();
      unawaited(
        data.preferences.setStringList('favorites', List.of(data.favorites)),
      );
    }
    return count;
  }

  // MENU DE CONTEXTO DE LINKS, SNEAK & PEEK E DETECÇÃO DE ÁUDIO
  final linkContextNotifier =
      ValueNotifier<
        ({String? url, String? text, Offset position, bool isTouch})?
      >(null);

  void _handleLinkMessage(String raw, {BrowserTab? tab}) {
    try {
      String jsonStr = raw;
      if (jsonStr.startsWith('%7B') || jsonStr.startsWith('%22')) {
        jsonStr = Uri.decodeComponent(jsonStr);
      }
      final decoded = jsonDecode(jsonStr);
      if (decoded is! Map<String, dynamic>) return;

      final type = decoded['type'] as String?;
      if (type == 'install_webstore') {
        final extId = decoded['extensionId'] as String?;
        if (extId != null && extId.isNotEmpty) {
          unawaited(installExtensionFromWebStore(extId));
        }
        return;
      }
      if (type == 'audio') {
        final targetTab = tab ?? current;
        final hasAudio = decoded['hasAudio'] as bool? ?? false;
        if (targetTab.hasAudio != hasAudio) {
          targetTab.hasAudio = hasAudio;
          notifyListeners();
        }
        return;
      }

      final url = decoded['url'] as String?;
      if (url != null && !BrowserData.isWeb(Uri.tryParse(url) ?? Uri())) {
        return;
      }
      final text = decoded['text'] as String?;
      final x = (decoded['x'] as num?)?.toDouble() ?? 100.0;
      final y = (decoded['y'] as num?)?.toDouble() ?? 100.0;
      final isTouch = decoded['isTouch'] as bool? ?? false;

      if (!x.isFinite || !y.isFinite || x < 0 || y < 0) return;
      linkContextNotifier.value = (
        url: url,
        text: text,
        position: Offset(x, y),
        isTouch: isTouch,
      );
    } catch (_) {}
  }

  static const String _jsLinkContextScript = r"""
    (function() {
      if (window.__dartLinkHandlerInstalled) return;
      window.__dartLinkHandlerInstalled = true;

      function postToDart(payloadObj) {
        var str = JSON.stringify(payloadObj);
        if (window.DartLinkHandler && window.DartLinkHandler.postMessage) {
          window.DartLinkHandler.postMessage(str);
        } else {
          try {
            var iframe = document.createElement('iframe');
            iframe.style.display = 'none';
            iframe.src = 'dart-link://' + encodeURIComponent(str);
            (document.body || document.documentElement).appendChild(iframe);
            setTimeout(function() { iframe.remove(); }, 200);
          } catch (_) {}
        }
      }

      function findLink(node, event) {
        if (event && event.composedPath) {
          try {
            var path = event.composedPath();
            for (var i = 0; i < path.length; i++) {
              var el = path[i];
              if (el && el.tagName === 'A' && (el.href || el.getAttribute('href'))) {
                return el;
              }
            }
          } catch (_) {}
        }
        if (!node) return null;
        if (node.closest) {
          try {
            var a = node.closest('a[href], a');
            if (a && (a.href || a.getAttribute('href'))) return a;
          } catch (_) {}
        }
        var cur = node;
        while (cur && cur !== document.body && cur !== document.documentElement) {
          if (cur.tagName === 'A' && (cur.href || cur.getAttribute('href'))) return cur;
          cur = cur.parentElement;
        }
        return null;
      }

      function emitLinkEvent(coords, a, isTouch) {
        var x = coords ? coords.clientX : 0;
        var y = coords ? coords.clientY : 0;
        var fullUrl = null;
        if (a) {
          try {
            var rawHref = a.href || a.getAttribute('href') || '';
            if (rawHref && rawHref !== '#' && !rawHref.startsWith('javascript:')) {
              fullUrl = new URL(rawHref, document.baseURI || window.location.href).href;
            } else if (rawHref) {
              fullUrl = a.href || rawHref;
            }
          } catch (_) {
            fullUrl = a.href || null;
          }
        }
        postToDart({
          type: 'link',
          url: fullUrl,
          text: a ? (a.innerText || a.title || a.getAttribute('aria-label') || fullUrl || '').trim().substring(0, 150) : null,
          x: Math.round(x || 0),
          y: Math.round(y || 0),
          isTouch: isTouch
        });
      }

      // 1. Clique com botão direito (Desktop contextmenu)
      document.addEventListener('contextmenu', function(e) {
        var target = e.target;
        if (!target) return;
        var targetEl = target.nodeType === 1 ? target : target.parentElement;
        if (!targetEl) return;

        // Se o clique for em campo editável com texto, manter comportamento nativo
        if (targetEl.closest && targetEl.closest('input, textarea, [contenteditable="true"]')) return;

        var a = findLink(targetEl, e);

        e.preventDefault();
        e.stopPropagation();
        emitLinkEvent({ clientX: e.clientX, clientY: e.clientY }, a, false);
      }, true);

      // 2. Toque longo no link ou página (Móvel / Touchscreen)
      var touchTimer = null;
      var touchTarget = null;
      var touchCoords = { x: 0, y: 0 };

      document.addEventListener('touchstart', function(e) {
        if (!e.touches || e.touches.length !== 1) { cancelTouch(); return; }
        var touch = e.touches[0];
        touchCoords = { x: touch.clientX, y: touch.clientY };
        var target = e.target;
        var targetEl = target && target.nodeType === 1 ? target : (target ? target.parentElement : null);
        touchTarget = findLink(targetEl, e);

        if (touchTimer) clearTimeout(touchTimer);
        touchTimer = setTimeout(function() {
          if (touchTarget) {
            emitLinkEvent({ clientX: touchCoords.x, clientY: touchCoords.y }, touchTarget, true);
            touchTarget = null;
          }
        }, 380);
      }, { passive: true });

      document.addEventListener('touchmove', function(e) {
        if (!touchTimer || !e.touches || e.touches.length !== 1) { cancelTouch(); return; }
        var touch = e.touches[0];
        var dx = Math.abs(touch.clientX - touchCoords.x);
        var dy = Math.abs(touch.clientY - touchCoords.y);
        if (dx > 10 || dy > 10) cancelTouch();
      }, { passive: true });

      function cancelTouch() {
        if (touchTimer) {
          clearTimeout(touchTimer);
          touchTimer = null;
          touchTarget = null;
        }
      }
      document.addEventListener('touchend', cancelTouch, { passive: true });
      document.addEventListener('touchcancel', cancelTouch, { passive: true });

      // 3. Monitor de Áudio em tempo real na aba
      var lastAudioState = false;
      function checkAudioState() {
        try {
          var medias = document.querySelectorAll('video, audio');
          var isPlaying = false;
          for (var i = 0; i < medias.length; i++) {
            var m = medias[i];
            if (!m.paused && !m.ended && m.currentTime > 0 && !m.muted && (m.volume || 1) > 0) {
              isPlaying = true;
              break;
            }
          }
          if (isPlaying !== lastAudioState) {
            lastAudioState = isPlaying;
            postToDart({ type: 'audio', hasAudio: isPlaying });
          }
        } catch (_) {}
      }

      window.addEventListener('play', checkAudioState, true);
      window.addEventListener('pause', checkAudioState, true);
      window.addEventListener('ended', checkAudioState, true);
      window.addEventListener('volumechange', checkAudioState, true);
      setInterval(checkAudioState, 2000);

      // 4. Interceptador de Instalação na Chrome Web Store
      if (window.location.hostname.indexOf('chromewebstore.google.com') !== -1) {
        function checkWebStoreButtons() {
          var match = window.location.pathname.match(/\/detail\/(?:[^\/]+\/)?([a-z]{32})/);
          if (!match || !match[1]) return;
          var extId = match[1];

          var buttons = document.querySelectorAll('button, [role="button"]');
          for (var i = 0; i < buttons.length; i++) {
            var btn = buttons[i];
            if (btn.__dart_hooked) continue;
            var text = (btn.innerText || btn.textContent || '').trim().toLowerCase();
            if (text.indexOf('usar') !== -1 || text.indexOf('adicionar') !== -1 || text.indexOf('chrome') !== -1 || text.indexOf('instalar') !== -1 || text.indexOf('add') !== -1) {
              btn.__dart_hooked = true;
              btn.addEventListener('click', function(ev) {
                ev.preventDefault();
                ev.stopPropagation();
                postToDart({
                  type: 'install_webstore',
                  extensionId: extId
                });
              }, true);
            }
          }
        }
        setInterval(checkWebStoreButtons, 800);
      }
    })();
  """;

  @override
  void dispose() {
    localeNotifier.dispose();
    themeNotifier.dispose();
    accentNotifier.dispose();
    oledNotifier.dispose();
    cornerRadiusNotifier.dispose();
    forceWebDarkNotifier.dispose();
    fullScreenNotifier.dispose();
    _sessionDebounceTimer?.cancel();
    splitRatioNotifier.dispose();
    splitScreenNotifier.dispose();
    linkContextNotifier.dispose();
    activeTabProgressNotifier.dispose();
    activeTabNavigationNotifier.dispose();
    findResultNotifier.dispose();
    findQueryNotifier.dispose();
    tabs.clear();
    super.dispose();
  }
}
