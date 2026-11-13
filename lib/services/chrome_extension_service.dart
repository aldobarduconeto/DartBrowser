import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:webview_all/webview_all.dart';

import '../models/chrome_extension.dart';

class ChromeExtensionService {
  ChromeExtensionService(this.preferences);

  final SharedPreferences preferences;
  static const _maxImportBytes = 50 * 1024 * 1024; // 50 MB

  // -------------------------------------------------------------
  // CARREGAMENTO E PERSISTÊNCIA
  // -------------------------------------------------------------

  List<ChromeExtension> load() {
    final rawList = preferences.getStringList('browserAddons');
    if (rawList == null) {
      final defaults = getPopularPresets();
      save(defaults);
      return defaults;
    }

    final extensions = <ChromeExtension>[];
    for (final value in rawList) {
      try {
        final decoded = jsonDecode(value);
        if (decoded is Map<String, dynamic>) {
          extensions.add(ChromeExtension.fromJson(decoded));
        }
      } on FormatException {
        continue;
      } on TypeError {
        continue;
      }
    }
    return extensions;
  }

  Future<bool> save(List<ChromeExtension> extensions) =>
      preferences.setStringList('browserAddons', [
        for (final ext in extensions) ext.encode(),
      ]);

  // -------------------------------------------------------------
  // BACKUP E EXPORTAÇÃO / IMPORTAÇÃO MULTIPLATAFORMA
  // -------------------------------------------------------------

  String exportBackup(List<ChromeExtension> extensions) {
    final list = [for (final ext in extensions) jsonDecode(ext.encode())];
    return const JsonEncoder.withIndent('  ').convert({
      'version': '1.0',
      'exportedAt': DateTime.now().toIso8601String(),
      'extensions': list,
    });
  }

  List<ChromeExtension> importBackup(String jsonContent) {
    final decoded = jsonDecode(jsonContent);
    if (decoded is! Map) {
      throw const FormatException('Arquivo de backup inválido.');
    }
    final rawExtensions = decoded['extensions'];
    if (rawExtensions is! List) {
      throw const FormatException('Nenhuma extensão encontrada no backup.');
    }
    final result = <ChromeExtension>[];
    for (final item in rawExtensions) {
      if (item is Map<String, dynamic>) {
        result.add(ChromeExtension.fromJson(item));
      } else if (item is Map) {
        result.add(ChromeExtension.fromJson(Map<String, dynamic>.from(item)));
      }
    }
    return result;
  }

  // -------------------------------------------------------------
  // IMPORTAÇÃO DE USERSCRIPTS (GREASYFORK / TAMPERMONKEY)
  // -------------------------------------------------------------

  ChromeExtension importUserScript(String scriptContent) {
    final clean = scriptContent.trim();
    if (clean.isEmpty) {
      throw const FormatException('O script está vazio.');
    }

    String name = 'UserScript';
    String version = '1.0.0';
    String description = 'Script de usuário importado';
    final matches = <String>[];
    final excludeMatches = <String>[];
    final permissions = <String>[];

    final headerMatch = RegExp(r'// ==UserScript==([\s\S]*?)// ==/UserScript==')
        .firstMatch(clean);

    if (headerMatch != null) {
      final header = headerMatch.group(1) ?? '';
      final lines = header.split('\n');
      for (final line in lines) {
        final trimmed = line.trim();
        if (!trimmed.startsWith('//')) continue;
        final body = trimmed.replaceFirst(RegExp(r'^\/\/\s*'), '');
        final parts = body.split(RegExp(r'\s+'));
        if (parts.length < 2) continue;
        final key = parts[0].toLowerCase();
        final value = parts.sublist(1).join(' ').trim();

        switch (key) {
          case '@name':
            name = value;
            break;
          case '@version':
            version = value;
            break;
          case '@description':
            description = value;
            break;
          case '@match':
          case '@include':
            matches.add(value);
            break;
          case '@exclude':
            excludeMatches.add(value);
            break;
          case '@grant':
            if (value != 'none') permissions.add(value);
            break;
        }
      }
    }

    if (matches.isEmpty) {
      matches.add('<all_urls>');
    }

    final id = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return ChromeExtension(
      id: id.isEmpty
          ? 'userscript_${DateTime.now().millisecondsSinceEpoch}'
          : id,
      name: name,
      version: version,
      description: description,
      origin: matches.first,
      source: clean,
      enabled: true,
      manifestVersion: 3,
      matches: matches,
      excludeMatches: excludeMatches,
      permissions: permissions,
      isCustomScript: true,
      isPinned: false,
    );
  }

  // -------------------------------------------------------------
  // IMPORTAÇÃO DE MANIFESTO JSON (UNIVERSAL / MULTIPLATAFORMA)
  // -------------------------------------------------------------

  ChromeExtension importManifestJson(
    String manifestJsonText, {
    Map<String, String> files = const {},
    String? customSource,
  }) {
    final Object? decoded;
    try {
      decoded = jsonDecode(manifestJsonText);
    } on FormatException {
      throw const FormatException(
        'O texto do manifest.json não é um JSON válido.',
      );
    }
    if (decoded is! Map) {
      throw const FormatException('Formato do manifest.json inválido.');
    }

    final manifestVersion = decoded['manifest_version'] as int? ?? 3;
    final name = decoded['name'] as String? ?? 'Extensão Web';
    final version = decoded['version'] as String? ?? '1.0.0';
    final description = decoded['description'] as String? ?? '';

    final permissions = <String>{};
    if (decoded['permissions'] is List) {
      permissions.addAll(
        (decoded['permissions'] as List).map((e) => e.toString()),
      );
    }
    if (decoded['host_permissions'] is List) {
      permissions.addAll(
        (decoded['host_permissions'] as List).map((e) => e.toString()),
      );
    }

    String? actionTitle;
    String? actionPopup;
    String? actionIcon;

    final actionMap =
        decoded['action'] ??
        decoded['browser_action'] ??
        decoded['page_action'];
    if (actionMap is Map) {
      actionTitle = actionMap['default_title']?.toString();
      actionPopup = actionMap['default_popup']?.toString();
      if (actionMap['default_icon'] is String) {
        actionIcon = actionMap['default_icon'].toString();
      } else if (actionMap['default_icon'] is Map) {
        final iconMap = actionMap['default_icon'] as Map;
        actionIcon =
            (iconMap['48'] ??
                    iconMap['32'] ??
                    iconMap['16'] ??
                    iconMap.values.firstOrNull)
                ?.toString();
      }
    }

    String? optionsPage;
    if (decoded['options_page'] is String) {
      optionsPage = decoded['options_page'].toString();
    } else if (decoded['options_ui'] is Map &&
        (decoded['options_ui'] as Map)['page'] is String) {
      optionsPage = (decoded['options_ui'] as Map)['page'].toString();
    }

    final allMatches = <String>{};
    final allExcludeMatches = <String>{};
    final compiledScripts = StringBuffer();

    if (customSource != null && customSource.trim().isNotEmpty) {
      compiledScripts.writeln(customSource);
    }

    final contentScripts = decoded['content_scripts'];
    if (contentScripts is List) {
      for (final item in contentScripts) {
        if (item is! Map) continue;
        final matches = _strings(item['matches']);
        final excludeMatches = _strings(item['exclude_matches']);
        allMatches.addAll(matches);
        allExcludeMatches.addAll(excludeMatches);

        final jsFiles = _strings(item['js']);
        final cssFiles = _strings(item['css']);

        for (final cssFile in cssFiles) {
          final normalized = cssFile.replaceAll(r'\', '/');
          final css = files[normalized] ?? files[cssFile];
          if (css != null && css.isNotEmpty) {
            compiledScripts.writeln('''
              try {
                const s = document.createElement('style');
                s.setAttribute('data-extension', ${jsonEncode(name)});
                s.textContent = ${jsonEncode(css)};
                (document.head || document.documentElement).appendChild(s);
              } catch (e) {
                console.error('Erro ao injetar CSS da extensão ${jsonEncode(name)}:', e);
              }
            ''');
          }
        }

        for (final jsFile in jsFiles) {
          final normalized = jsFile.replaceAll(r'\', '/');
          final js = files[normalized] ?? files[jsFile];
          if (js != null && js.isNotEmpty) {
            compiledScripts.writeln('''
              try {
                $js
              } catch (e) {
                console.error('Erro no script ${jsonEncode(jsFile)} da extensão ${jsonEncode(name)}:', e);
              }
            ''');
          }
        }
      }
    }

    final matchesList = allMatches.isNotEmpty
        ? allMatches.toList()
        : ['<all_urls>'];
    final id = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return ChromeExtension(
      id: id.isEmpty ? 'ext_${DateTime.now().millisecondsSinceEpoch}' : id,
      name: name,
      version: version,
      description: description,
      origin: matchesList.first,
      source: compiledScripts.toString(),
      enabled: true,
      manifestVersion: manifestVersion,
      matches: matchesList,
      excludeMatches: allExcludeMatches.toList(),
      permissions: permissions.toList(),
      actionTitle: actionTitle ?? name,
      actionPopup: actionPopup,
      actionIcon: actionIcon,
      optionsPage: optionsPage,
      files: files,
      isPinned: true,
    );
  }

  // -------------------------------------------------------------
  // IMPORTAÇÃO E DOWNLOAD DE PACOTES .CRX E .ZIP (CHROME WEB STORE)
  // -------------------------------------------------------------

  static Future<Uint8List> downloadCrx(String extensionId) async {
    final cleanId = extensionId.trim().toLowerCase();
    final url =
        'https://clients2.google.com/service/update2/crx?response=redirect&prodversion=130.0.0.0&acceptformat=crx2,crx3&x=id%3D$cleanId%26uc';
    return downloadCrxFromUrl(url);
  }

  static Future<Uint8List> downloadCrxFromUrl(String url) async {
    final client = HttpClient();
    client.userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/130.0.0.0 Safari/537.36';
    try {
      final request = await client.getUrl(Uri.parse(url));
      request.followRedirects = true;
      final response = await request.close();
      if (response.statusCode >= 200 && response.statusCode < 400) {
        final bytesBuilder = BytesBuilder(copy: false);
        await for (final chunk in response) {
          bytesBuilder.add(chunk);
        }
        final bytes = bytesBuilder.takeBytes();
        if (bytes.isNotEmpty) return bytes;
      }
      throw HttpException(
        'Falha no download da extensão (HTTP ${response.statusCode})',
      );
    } finally {
      client.close();
    }
  }

  ChromeExtension importCrxBytes(Uint8List bytes) {
    final files = CrxExtractor.extract(bytes);
    if (files.isEmpty) {
      throw const FormatException(
        'Não foi possível extrair arquivos do pacote da extensão.',
      );
    }
    String? manifestContent = files['manifest.json'];
    if (manifestContent == null) {
      final manifestKey = files.keys.firstWhere(
        (k) => k.endsWith('manifest.json'),
        orElse: () => '',
      );
      if (manifestKey.isNotEmpty) {
        manifestContent = files[manifestKey];
      }
    }
    if (manifestContent == null) {
      throw const FormatException(
        'O pacote da extensão não contém o arquivo manifest.json.',
      );
    }
    return importManifestJson(manifestContent, files: files);
  }

  Future<ChromeExtension> importCrxFile(String filePath) async {
    final file = File(filePath.trim());
    if (!await file.exists()) {
      throw const FormatException('Arquivo da extensão não encontrado.');
    }
    final bytes = await file.readAsBytes();
    return importCrxBytes(bytes);
  }

  // -------------------------------------------------------------
  // IMPORTAÇÃO DE PASTAS DE EXTENSÃO (DESKTOP)
  // -------------------------------------------------------------

  Future<ChromeExtension> importFolder(
    String folder, [
    String? optionalOrigin,
  ]) async {
    final directory = Directory(folder.trim());
    if (!await directory.exists()) {
      throw const FormatException('Pasta da extensão não encontrada.');
    }
    final root = await directory.resolveSymbolicLinks();
    var remaining = _maxImportBytes;
    final fileMap = <String, String>{};

    Future<String> readFile(String relative) async {
      final normalized = relative.replaceAll(r'\', '/');
      final parts = normalized.split('/');
      if (parts.any(
        (part) =>
            part.isEmpty || part == '.' || part == '..' || part.contains(':'),
      )) {
        throw const FormatException('O manifesto contém um caminho inválido.');
      }
      final prefix = root.endsWith(Platform.pathSeparator)
          ? root
          : '$root${Platform.pathSeparator}';
      final file = File('$prefix${parts.join(Platform.pathSeparator)}');
      if (!await file.exists()) {
        throw FormatException('Arquivo ausente na extensão: $relative');
      }
      final resolved = await file.resolveSymbolicLinks();
      final inside = Platform.isWindows
          ? resolved.toLowerCase().startsWith(prefix.toLowerCase())
          : resolved.startsWith(prefix);
      if (!inside) {
        throw const FormatException('Um arquivo aponta para fora da extensão.');
      }
      final bytes = await File(resolved)
          .openRead(0, remaining + 1)
          .expand((chunk) => chunk)
          .toList();
      remaining -= bytes.length;
      if (remaining < 0) {
        throw const FormatException('Os arquivos excedem o limite de 50 MB.');
      }
      final content = utf8.decode(bytes, allowMalformed: true);
      fileMap[normalized] = content;
      return content;
    }

    final manifestText = await readFile('manifest.json');
    final Object? decoded;
    try {
      decoded = jsonDecode(manifestText);
    } on FormatException {
      throw const FormatException('O arquivo manifest.json é inválido.');
    }
    if (decoded is! Map) {
      throw const FormatException('Formato do manifest.json inválido.');
    }

    final manifestVersion = decoded['manifest_version'] as int? ?? 3;
    if (manifestVersion != 2 && manifestVersion != 3) {
      throw const FormatException(
        'A versão do manifesto precisa ser Manifest V2 ou V3.',
      );
    }

    final name = decoded['name'] as String? ?? 'Extensão Web';
    final version = decoded['version'] as String? ?? '1.0.0';
    final description = decoded['description'] as String? ?? '';

    // Permissões
    final permissions = <String>{};
    if (decoded['permissions'] is List) {
      permissions.addAll(
        (decoded['permissions'] as List).map((e) => e.toString()),
      );
    }
    if (decoded['host_permissions'] is List) {
      permissions.addAll(
        (decoded['host_permissions'] as List).map((e) => e.toString()),
      );
    }

    // Ação / Popup
    String? actionTitle;
    String? actionPopup;
    String? actionIcon;

    final actionMap =
        decoded['action'] ??
        decoded['browser_action'] ??
        decoded['page_action'];
    if (actionMap is Map) {
      actionTitle = actionMap['default_title']?.toString();
      actionPopup = actionMap['default_popup']?.toString();
      if (actionMap['default_icon'] is String) {
        actionIcon = actionMap['default_icon'].toString();
      } else if (actionMap['default_icon'] is Map) {
        final iconMap = actionMap['default_icon'] as Map;
        actionIcon =
            (iconMap['48'] ??
                    iconMap['32'] ??
                    iconMap['16'] ??
                    iconMap.values.firstOrNull)
                ?.toString();
      }
    }

    // Página de opções
    String? optionsPage;
    if (decoded['options_page'] is String) {
      optionsPage = decoded['options_page'].toString();
    } else if (decoded['options_ui'] is Map &&
        (decoded['options_ui'] as Map)['page'] is String) {
      optionsPage = (decoded['options_ui'] as Map)['page'].toString();
    }

    // Background / Service Worker
    String? backgroundSource;
    if (decoded['background'] is Map) {
      final bg = decoded['background'] as Map;
      if (bg['service_worker'] is String) {
        try {
          backgroundSource = await readFile(bg['service_worker'].toString());
        } catch (_) {}
      } else if (bg['scripts'] is List) {
        final buffer = StringBuffer();
        for (final script in bg['scripts'] as List) {
          try {
            buffer.writeln(await readFile(script.toString()));
          } catch (_) {}
        }
        backgroundSource = buffer.toString();
      }
    }

    if (actionPopup != null && actionPopup.isNotEmpty) {
      try {
        await readFile(actionPopup);
      } catch (_) {}
    }
    if (optionsPage != null && optionsPage.isNotEmpty) {
      try {
        await readFile(optionsPage);
      } catch (_) {}
    }

    // Content scripts
    final allMatches = <String>{};
    final allExcludeMatches = <String>{};
    final compiledScripts = StringBuffer();

    final contentScripts = decoded['content_scripts'];
    if (contentScripts is List) {
      for (final item in contentScripts) {
        if (item is! Map) continue;

        final matches = _strings(item['matches']);
        final excludeMatches = _strings(item['exclude_matches']);
        allMatches.addAll(matches);
        allExcludeMatches.addAll(excludeMatches);

        final jsFiles = _strings(item['js']);
        final cssFiles = _strings(item['css']);

        for (final cssFile in cssFiles) {
          try {
            final css = await readFile(cssFile);
            compiledScripts.writeln('''
              try {
                const s = document.createElement('style');
                s.setAttribute('data-extension', ${jsonEncode(name)});
                s.textContent = ${jsonEncode(css)};
                (document.head || document.documentElement).appendChild(s);
              } catch (e) {
                console.error('Erro ao injetar CSS da extensão ${jsonEncode(name)}:', e);
              }
            ''');
          } catch (_) {}
        }

        for (final jsFile in jsFiles) {
          try {
            final js = await readFile(jsFile);
            compiledScripts.writeln('''
              try {
                $js
              } catch (e) {
                console.error('Erro no content script ${jsonEncode(jsFile)} da extensão ${jsonEncode(name)}:', e);
              }
            ''');
          } catch (_) {}
        }
      }
    }

    // Carregar outros assets comuns da pasta
    try {
      await for (final entity in directory.list(recursive: true)) {
        if (entity is File) {
          final rel = entity.path
              .substring(root.length)
              .replaceAll(r'\', '/')
              .replaceFirst(RegExp(r'^/'), '');
          if (rel.endsWith('.html') ||
              rel.endsWith('.js') ||
              rel.endsWith('.css') ||
              rel.endsWith('.json')) {
            if (!fileMap.containsKey(rel) && remaining > 0) {
              try {
                await readFile(rel);
              } catch (_) {}
            }
          }
        }
      }
    } catch (_) {}

    final matchesList = allMatches.isNotEmpty
        ? allMatches.toList()
        : [
            optionalOrigin != null && optionalOrigin.isNotEmpty
                ? '$optionalOrigin/*'
                : '<all_urls>',
          ];
    final origin = optionalOrigin != null && optionalOrigin.isNotEmpty
        ? optionalOrigin
        : (allMatches.contains('<all_urls>') || allMatches.isEmpty
              ? '<all_urls>'
              : allMatches.first);

    final id = name
        .toLowerCase()
        .replaceAll(RegExp(r'[^a-z0-9]'), '_')
        .replaceAll(RegExp(r'_+'), '_');

    return ChromeExtension(
      id: id,
      name: name,
      version: version,
      description: description,
      origin: origin,
      source: compiledScripts.toString(),
      enabled: true,
      manifestVersion: manifestVersion,
      matches: matchesList,
      excludeMatches: allExcludeMatches.toList(),
      permissions: permissions.toList(),
      actionTitle: actionTitle ?? name,
      actionPopup: actionPopup,
      actionIcon: actionIcon,
      optionsPage: optionsPage,
      backgroundSource: backgroundSource,
      files: fileMap,
      isPinned: true,
    );
  }

  // -------------------------------------------------------------
  // EXECUÇÃO E INJEÇÃO DAS EXTENSÕES NAS PÁGINAS WEB
  // -------------------------------------------------------------

  Future<void> run(
    WebViewController engine,
    String address,
    List<ChromeExtension> extensions,
  ) async {
    final uri = Uri.tryParse(address);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return;
    }

    for (final ext in extensions) {
      if (!ext.enabled || !ext.matchesPage(address)) continue;

      try {
        final runtimeShim = _generateChromeApiShim(ext, uri);
        final fullScript =
            '''
          (() => {
            try {
              $runtimeShim
              ${ext.source}
            } catch (err) {
              console.warn('[DartBrowser Extension: ' + ${jsonEncode(ext.name)} + '] Erro:', err);
            }
          })();
        ''';

        await engine.runJavaScript(fullScript);
      } on UnsupportedError {
        return;
      } on Exception {
        // Falhas não devem travar a aba
      }
    }
  }

  // -------------------------------------------------------------
  // PONTE DE EMULAÇÃO DAS APIS CHROME.* E BROWSER.*
  // -------------------------------------------------------------

  String _generateChromeApiShim(ChromeExtension ext, Uri currentUri) {
    final extensionId = ext.id;
    final manifestJson = jsonEncode({
      'name': ext.name,
      'version': ext.version,
      'description': ext.description,
      'manifest_version': ext.manifestVersion,
      'permissions': ext.permissions,
      'action': {
        'default_title': ext.actionTitle,
        'default_popup': ext.actionPopup,
      },
    });

    return '''
      // Interceptador SPA contínuo (YouTube, Twitter/X, Next.js, React)
      if (!window.__dart_spa_watcher_installed__) {
        window.__dart_spa_watcher_installed__ = true;
        const notifyNav = () => {
          window.dispatchEvent(new CustomEvent('dart_spa_nav', { detail: { url: location.href } }));
        };
        const origPush = history.pushState;
        history.pushState = function() {
          origPush.apply(this, arguments);
          setTimeout(notifyNav, 120);
        };
        const origReplace = history.replaceState;
        history.replaceState = function() {
          origReplace.apply(this, arguments);
          setTimeout(notifyNav, 120);
        };
        window.addEventListener('popstate', notifyNav);
        window.addEventListener('hashchange', notifyNav);
      }

      if (!window.__dart_ext_${extensionId}__) {
        window.__dart_ext_${extensionId}__ = true;

        const extId = ${jsonEncode(extensionId)};
        const storagePrefix = '__dart_ext_' + extId + '_';

        const listeners = {
          onMessage: [],
          onConnect: [],
          storageChanged: [],
          actionClicked: []
        };

        const createEvent = (arr) => ({
          addListener: function(fn) { if (typeof fn === 'function' && !arr.includes(fn)) arr.push(fn); },
          removeListener: function(fn) { const idx = arr.indexOf(fn); if (idx !== -1) arr.splice(idx, 1); },
          hasListener: function(fn) { return arr.includes(fn); }
        });

        const storage = {
          get: function(keys, callback) {
            return new Promise((resolve) => {
              const res = {};
              if (keys === null || keys === undefined) {
                for (let i = 0; i < localStorage.length; i++) {
                  const k = localStorage.key(i);
                  if (k && k.startsWith(storagePrefix)) {
                    const real = k.substring(storagePrefix.length);
                    try { res[real] = JSON.parse(localStorage.getItem(k)); } catch(e) { res[real] = localStorage.getItem(k); }
                  }
                }
              } else if (typeof keys === 'string') {
                const val = localStorage.getItem(storagePrefix + keys);
                if (val !== null) {
                  try { res[keys] = JSON.parse(val); } catch(e) { res[keys] = val; }
                }
              } else if (Array.isArray(keys)) {
                keys.forEach(k => {
                  const val = localStorage.getItem(storagePrefix + k);
                  if (val !== null) {
                    try { res[k] = JSON.parse(val); } catch(e) { res[k] = val; }
                  }
                });
              } else if (typeof keys === 'object') {
                Object.keys(keys).forEach(k => {
                  const val = localStorage.getItem(storagePrefix + k);
                  res[k] = val !== null ? JSON.parse(val) : keys[k];
                });
              }
              if (typeof callback === 'function') callback(res);
              resolve(res);
            });
          },
          set: function(items, callback) {
            return new Promise((resolve) => {
              if (items && typeof items === 'object') {
                Object.keys(items).forEach(k => {
                  localStorage.setItem(storagePrefix + k, JSON.stringify(items[k]));
                });
                listeners.storageChanged.forEach(fn => {
                  try { fn(items, 'local'); } catch(e) {}
                });
              }
              if (typeof callback === 'function') callback();
              resolve();
            });
          },
          remove: function(keys, callback) {
            return new Promise((resolve) => {
              const arr = Array.isArray(keys) ? keys : [keys];
              arr.forEach(k => localStorage.removeItem(storagePrefix + k));
              if (typeof callback === 'function') callback();
              resolve();
            });
          },
          clear: function(callback) {
            return new Promise((resolve) => {
              const toRemove = [];
              for (let i = 0; i < localStorage.length; i++) {
                const k = localStorage.key(i);
                if (k && k.startsWith(storagePrefix)) toRemove.push(k);
              }
              toRemove.forEach(k => localStorage.removeItem(k));
              if (typeof callback === 'function') callback();
              resolve();
            });
          },
          getBytesInUse: function(keys, callback) {
            if (typeof callback === 'function') callback(1024);
            return Promise.resolve(1024);
          }
        };

        const chromeShim = {
          runtime: {
            id: extId,
            lastError: null,
            getManifest: function() { return $manifestJson; },
            getURL: function(path) {
              if (!path) return '';
              if (path.startsWith('http') || path.startsWith('data:')) return path;
              return 'chrome-extension://' + extId + '/' + (path.startsWith('/') ? path.slice(1) : path);
            },
            sendMessage: function(msg, cb) {
              listeners.onMessage.forEach(fn => {
                try { fn(msg, { id: extId }, cb || (() => {})); } catch(e) {}
              });
              if (typeof cb === 'function') cb({ success: true });
              return Promise.resolve({ success: true });
            },
            onMessage: createEvent(listeners.onMessage),
            onConnect: createEvent(listeners.onConnect),
            onInstalled: createEvent([]),
            onStartup: createEvent([])
          },
          storage: {
            local: storage,
            sync: storage,
            managed: storage,
            session: storage,
            onChanged: createEvent(listeners.storageChanged)
          },
          tabs: {
            query: function(info, cb) {
              const list = [{
                id: 1,
                index: 0,
                active: true,
                url: location.href,
                title: document.title
              }];
              if (typeof cb === 'function') cb(list);
              return Promise.resolve(list);
            },
            get: function(id, cb) {
              const tab = { id: id || 1, url: location.href, title: document.title, active: true };
              if (typeof cb === 'function') cb(tab);
              return Promise.resolve(tab);
            },
            create: function(props, cb) {
              if (props && props.url) window.open(props.url, '_blank');
              if (typeof cb === 'function') cb({ id: 2, url: props?.url || '' });
              return Promise.resolve({ id: 2, url: props?.url || '' });
            },
            update: function(id, props, cb) {
              if (props && props.url) location.href = props.url;
              if (typeof cb === 'function') cb({ id: id, url: location.href });
              return Promise.resolve({ id: id, url: location.href });
            },
            sendMessage: function(tabId, msg, options, cb) {
              const callback = typeof options === 'function' ? options : cb;
              listeners.onMessage.forEach(fn => {
                try { fn(msg, { tab: { id: tabId, url: location.href } }, callback || (() => {})); } catch(e) {}
              });
              if (typeof callback === 'function') callback({ success: true });
              return Promise.resolve({ success: true });
            },
            executeScript: function(tabId, details, cb) {
              if (details && details.code) {
                try { eval(details.code); } catch(e) { console.error(e); }
              }
              if (typeof cb === 'function') cb([true]);
              return Promise.resolve([true]);
            },
            insertCSS: function(tabId, details, cb) {
              if (details && details.code) {
                const s = document.createElement('style');
                s.textContent = details.code;
                document.head.appendChild(s);
              }
              if (typeof cb === 'function') cb();
              return Promise.resolve();
            },
            onUpdated: createEvent([]),
            onActivated: createEvent([])
          },
          action: {
            setTitle: function(details) {},
            getTitle: function(d, cb) { if (cb) cb(${jsonEncode(ext.actionTitle ?? ext.name)}); return Promise.resolve(${jsonEncode(ext.actionTitle ?? ext.name)}); },
            setBadgeText: function(details) {},
            getBadgeText: function(d, cb) { if (cb) cb(''); return Promise.resolve(''); },
            setBadgeBackgroundColor: function(details) {},
            setIcon: function(details) {},
            onClicked: createEvent(listeners.actionClicked)
          },
          i18n: {
            getMessage: function(name) { return name; },
            getUILanguage: function() { return navigator.language || 'pt-BR'; }
          },
          permissions: {
            contains: function(p, cb) { if (cb) cb(true); return Promise.resolve(true); },
            request: function(p, cb) { if (cb) cb(true); return Promise.resolve(true); },
            getAll: function(cb) { const r = { permissions: ${jsonEncode(ext.permissions)} }; if (cb) cb(r); return Promise.resolve(r); }
          },
          scripting: {
            executeScript: function(inj, cb) {
              if (inj && inj.func) {
                try { inj.func.apply(null, inj.args || []); } catch(e) { console.error(e); }
              }
              if (typeof cb === 'function') cb();
              return Promise.resolve();
            },
            insertCSS: function(inj, cb) {
              if (inj && inj.css) {
                const s = document.createElement('style');
                s.textContent = inj.css;
                document.head.appendChild(s);
              }
              if (typeof cb === 'function') cb();
              return Promise.resolve();
            }
          },
          contextMenus: {
            create: function(opts, cb) { if (typeof cb === 'function') cb(); return 1; },
            update: function(id, opts, cb) { if (typeof cb === 'function') cb(); },
            remove: function(id, cb) { if (typeof cb === 'function') cb(); },
            removeAll: function(cb) { if (typeof cb === 'function') cb(); },
            onClicked: createEvent([])
          },
          notifications: {
            create: function(id, opts, cb) { if (typeof cb === 'function') cb(id || '1'); return Promise.resolve(id || '1'); },
            clear: function(id, cb) { if (typeof cb === 'function') cb(true); return Promise.resolve(true); }
          }
        };

        chromeShim.browserAction = chromeShim.action;
        chromeShim.extension = {
          getURL: chromeShim.runtime.getURL,
          inIncognitoContext: false
        };

        window.chrome = Object.assign(window.chrome || {}, chromeShim);
        window.browser = window.chrome;
      }
    ''';
  }

  List<String> _strings(Object? value) {
    if (value == null) return [];
    if (value is! List) return [];
    return value.map((e) => e.toString()).toList();
  }

  // -------------------------------------------------------------
  // EXTENSÕES POPULARES PRONTAS (LOJA INTEGRADA DE 1 CLIQUE)
  // -------------------------------------------------------------

  static List<ChromeExtension> getPopularPresets() => [
    const ChromeExtension(
      id: 'dark_reader_pro',
      name: 'Dark Reader Pro',
      version: '4.9.8',
      description: 'Modo escuro moderno, inteligente e de alto contraste para todos os sites da web.',
      origin: '<all_urls>',
      matches: ['<all_urls>'],
      permissions: ['<all_urls>', 'storage'],
      actionTitle: 'Dark Reader Pro',
      badgeText: '🌙',
      actionPopup: '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 16px; width: 280px; background: #181a1b; color: #e8e6e3; }
    h3 { margin-top: 0; color: #3391ff; font-size: 16px; }
    .row { display: flex; justify-content: space-between; align-items: center; margin-bottom: 12px; font-size: 14px; }
    .badge { background: #3391ff; color: #fff; padding: 2px 8px; border-radius: 12px; font-size: 11px; font-weight: bold; }
    .toggle { appearance: none; width: 40px; height: 22px; background: #3c4043; border-radius: 11px; position: relative; cursor: pointer; }
    .toggle:checked { background: #3391ff; }
    .toggle::after { content: ''; position: absolute; width: 18px; height: 18px; border-radius: 50%; background: #fff; top: 2px; left: 2px; transition: 0.2s; }
    .toggle:checked::after { transform: translateX(18px); }
  </style>
</head>
<body>
  <h3>🌙 Dark Reader Pro <span class="badge">ATIVO</span></h3>
  <div class="row">
    <span>Modo Escuro Global</span>
    <input type="checkbox" class="toggle" checked>
  </div>
</body>
</html>
''',
      source: '''
(() => {
  if (document.getElementById('dart-browser-dark-mode-style')) return;
  const style = document.createElement('style');
  style.id = 'dart-browser-dark-mode-style';
  style.textContent = `
    html {
      filter: invert(90%) hue-rotate(180deg) !important;
      background-color: #121212 !important;
    }
    img, video, iframe, canvas, svg, [style*="background-image"] {
      filter: invert(100%) hue-rotate(180deg) !important;
    }
  `;
  (document.head || document.documentElement).appendChild(style);
})();
''',
      enabled: false,
      isPinned: true,
    ),
    const ChromeExtension(
      id: 'adblock_shield_ultra',
      name: 'AdBlock Shield Ultra',
      version: '3.14.0',
      description: 'Bloqueia anúncios intrusivos, popups, banners patrocinados e rastreadores.',
      origin: '<all_urls>',
      matches: ['<all_urls>'],
      permissions: ['<all_urls>', 'declarativeNetRequest', 'storage'],
      actionTitle: 'AdBlock Shield',
      badgeText: '🛡️',
      actionPopup: '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 16px; width: 280px; background: #0f172a; color: #f8fafc; }
    h3 { margin-top: 0; color: #10b981; font-size: 16px; }
    .stat-card { background: #1e293b; padding: 12px; border-radius: 8px; margin-bottom: 12px; text-align: center; }
    .stat-val { font-size: 24px; font-weight: bold; color: #10b981; }
    .stat-lbl { font-size: 12px; color: #94a3b8; }
  </style>
</head>
<body>
  <h3>🛡️ AdBlock Shield</h3>
  <div class="stat-card">
    <div class="stat-val">Ativo</div>
    <div class="stat-lbl">Proteção contra anúncios em execução</div>
  </div>
</body>
</html>
''',
      source: '''
(() => {
  const cleanAds = () => {
    const selectors = [
      '.ad', '.ads', '.adsbygoogle', '.advertisement', '.banner-ads',
      '[id*="google_ads"]', '[id*="ad-container"]', '[class*="sponsored-post"]',
      'iframe[src*="doubleclick.net"]', 'iframe[src*="adservice"]',
      'div[data-ad]', 'aside[class*="ad"]'
    ];
    selectors.forEach(sel => {
      document.querySelectorAll(sel).forEach(el => {
        el.style.display = 'none';
        el.remove();
      });
    });
  };
  cleanAds();
  setInterval(cleanAds, 2000);
})();
''',
      enabled: false,
      isPinned: true,
    ),
    const ChromeExtension(
      id: 'youtube_enhancer_pro',
      name: 'YouTube Enhancer & PiP',
      version: '2.5.0',
      description: 'Adiciona botão de Picture-in-Picture flutuante, controle de velocidade instantâneo e pula anúncios do YouTube.',
      origin: '*://*.youtube.com/*',
      matches: ['*://*.youtube.com/*', '*://youtube.com/*'],
      permissions: ['*://*.youtube.com/*', 'storage'],
      actionTitle: 'YouTube Enhancer',
      badgeText: '▶️',
      actionPopup: '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: sans-serif; margin: 0; padding: 14px; width: 260px; background: #0f0f0f; color: #fff; }
    h4 { margin: 0 0 10px 0; color: #ff0000; }
    button { width: 100%; margin-bottom: 8px; padding: 8px; background: #272727; color: #fff; border: 1px solid #3f3f3f; border-radius: 6px; cursor: pointer; }
    button:hover { background: #3f3f3f; }
  </style>
</head>
<body>
  <h4>▶️ YouTube Enhancer</h4>
  <button onclick="parent.window.postMessage('pip','*')">Forçar Picture-in-Picture</button>
  <button onclick="parent.window.postMessage('speed_2','*')">Velocidade 2x</button>
</body>
</html>
''',
      source: '''
(() => {
  const enhanceYT = () => {
    // Pular anúncios automaticamente
    const adBtn = document.querySelector('.ytp-ad-skip-button, .ytp-ad-skip-button-modern');
    if (adBtn) adBtn.click();
    const video = document.querySelector('video');
    if (video && document.querySelector('.ad-showing')) {
      video.currentTime = video.duration || 999;
    }
  };
  setInterval(enhanceYT, 500);
})();
''',
      enabled: true,
      isPinned: true,
    ),
    const ChromeExtension(
      id: 'instant_web_translator',
      name: 'Instant Web Translator',
      version: '2.1.0',
      description: 'Adiciona uma barra sutil para traduzir qualquer página web para o Português com 1 toque.',
      origin: '<all_urls>',
      matches: ['<all_urls>'],
      permissions: ['<all_urls>'],
      actionTitle: 'Traduzir Página',
      badgeText: '🌐',
      source: '''
(() => {
  if (document.getElementById('dart-translator-bar')) return;
  const bar = document.createElement('div');
  bar.id = 'dart-translator-bar';
  bar.style.cssText = 'position:fixed;bottom:16px;right:16px;z-index:999999;background:#1e293b;color:#fff;padding:8px 14px;border-radius:24px;box-shadow:0 4px 16px rgba(0,0,0,0.3);font-family:sans-serif;font-size:13px;display:flex;align-items:center;gap:8px;cursor:pointer;';
  bar.innerHTML = '🌐 Traduzir com Google <span style="font-size:11px;opacity:0.7">✕</span>';
  bar.onclick = (e) => {
    if (e.target.tagName === 'SPAN') { bar.remove(); return; }
    window.open('https://translate.google.com/translate?sl=auto&tl=pt&u=' + encodeURIComponent(location.href), '_blank');
  };
  document.body.appendChild(bar);
})();
''',
      enabled: false,
      isPinned: true,
    ),
    const ChromeExtension(
      id: 'smooth_auto_scroll',
      name: 'Smooth Auto-Scroller',
      version: '1.4.0',
      description: 'Rolagem automática contínua e suave para leitura relaxante de artigos e livros.',
      origin: '<all_urls>',
      matches: ['<all_urls>'],
      permissions: ['<all_urls>'],
      actionTitle: 'Auto Scroll',
      badgeText: '📜',
      source: '''
(() => {
  if (window.__autoScrollActive) {
    clearInterval(window.__autoScrollInterval);
    window.__autoScrollActive = false;
    const badge = document.getElementById('dart-autoscroll-badge');
    if (badge) badge.remove();
    return;
  }
  window.__autoScrollActive = true;
  window.__autoScrollInterval = setInterval(() => {
    window.scrollBy({ top: 2, behavior: 'smooth' });
  }, 40);
  const badge = document.createElement('div');
  badge.id = 'dart-autoscroll-badge';
  badge.style.cssText = 'position:fixed;top:16px;right:16px;z-index:999999;background:#2563eb;color:#fff;padding:6px 12px;border-radius:16px;font-size:12px;font-family:sans-serif;box-shadow:0 2px 8px rgba(0,0,0,0.2);cursor:pointer;';
  badge.textContent = '📜 Rolagem Ativa (Toque para parar)';
  badge.onclick = () => {
    clearInterval(window.__autoScrollInterval);
    window.__autoScrollActive = false;
    badge.remove();
  };
  document.body.appendChild(badge);
})();
''',
      enabled: false,
      isPinned: true,
    ),
    const ChromeExtension(
      id: 'json_viewer_pro',
      name: 'JSON Prettifier & DevTools',
      version: '2.0.1',
      description: 'Formata, colore e torna interativas as respostas JSON brutas carregadas na aba.',
      origin: '<all_urls>',
      matches: ['<all_urls>'],
      permissions: ['<all_urls>'],
      actionTitle: 'JSON Prettifier',
      source: '''
(() => {
  if (document.contentType === 'application/json' ||
      document.body?.innerText?.trim()?.startsWith('{') && document.body?.innerText?.trim()?.endsWith('}')) {
    try {
      const raw = document.body.innerText.trim();
      const obj = JSON.parse(raw);
      document.body.innerHTML = '';
      const pre = document.createElement('pre');
      pre.style.cssText = 'padding: 20px; font-family: monospace; font-size: 14px; background: #1e1e1e; color: #d4d4d4; border-radius: 8px; margin: 16px; overflow: auto; line-height: 1.5;';
      pre.textContent = JSON.stringify(obj, null, 2);
      document.body.style.backgroundColor = '#121212';
      document.body.appendChild(pre);
    } catch (_) {}
  }
})();
''',
      enabled: true,
      isPinned: false,
    ),
    const ChromeExtension(
      id: 'markdown_clipper',
      name: 'Markdown Clipper',
      version: '1.2.0',
      description: 'Copia o artigo da página formatado em Markdown com links e cabeçalhos em 1 toque.',
      origin: '<all_urls>',
      matches: ['<all_urls>'],
      permissions: ['<all_urls>', 'storage'],
      actionTitle: 'Copiar Markdown',
      badgeText: 'MD',
      source: '''
(() => {
  window.__copyPageAsMarkdown = () => {
    const title = document.title;
    const url = window.location.href;
    let md = '# [' + title + '](' + url + ')\\n\\n';
    document.querySelectorAll('article p, main p, p').forEach(p => {
      const text = p.innerText.trim();
      if (text.length > 30) md += text + '\\n\\n';
    });
    navigator.clipboard.writeText(md).then(() => {
      alert('Artigo copiado em Markdown para a área de transferência!');
    });
  };
})();
''',
      enabled: false,
      isPinned: true,
    ),
    const ChromeExtension(
      id: 'secure_password_gen',
      name: 'Secure Password Generator',
      version: '1.1.0',
      description: 'Gerador de senhas aleatórias e de alta entropia disponível direto no popup da extensão.',
      origin: '<all_urls>',
      matches: ['<all_urls>'],
      permissions: ['storage'],
      actionTitle: 'Gerador de Senhas',
      badgeText: '🔑',
      actionPopup: '''
<!DOCTYPE html>
<html>
<head>
  <meta charset="utf-8">
  <style>
    body { font-family: sans-serif; padding: 14px; width: 260px; background: #111827; color: #f9fafb; margin: 0; }
    input { width: 100%; padding: 8px; box-sizing: border-box; background: #1f2937; color: #10b981; border: 1px solid #374151; border-radius: 6px; font-family: monospace; font-size: 14px; margin-bottom: 8px; }
    button { width: 100%; padding: 8px; background: #2563eb; color: #fff; border: none; border-radius: 6px; cursor: pointer; font-weight: bold; }
  </style>
</head>
<body>
  <h4 style="margin:0 0 10px 0; color:#60a5fa">🔑 Gerador de Senhas</h4>
  <input id="pwd" readonly>
  <button onclick="gen()">Gerar Nova Senha</button>
  <script>
    function gen() {
      const chars = 'abcdefghijkmnopqrstuvwxyzABCDEFGHJKLMNPQRSTUVWXYZ23456789!@#\$%^&*()-_=+';
      let res = '';
      for (let i = 0; i < 18; i++) res += chars.charAt(Math.floor(Math.random() * chars.length));
      document.getElementById('pwd').value = res;
      navigator.clipboard.writeText(res);
    }
    gen();
  </script>
</body>
</html>
''',
      source: '',
      enabled: false,
      isPinned: true,
    ),
    const ChromeExtension(
      id: 'auto_mute_tabs',
      name: 'Auto Mute Background Tabs',
      version: '1.0.0',
      description: 'Silencia automaticamente vídeos e músicas quando você muda para outra aba.',
      origin: '<all_urls>',
      matches: ['<all_urls>'],
      permissions: ['<all_urls>'],
      actionTitle: 'Auto Mute',
      badgeText: '🔕',
      source: '''
(() => {
  document.addEventListener('visibilitychange', () => {
    const media = document.querySelectorAll('video, audio');
    if (document.hidden) {
      media.forEach(m => { m.__wasMuted = m.muted; m.muted = true; });
    } else {
      media.forEach(m => { if (m.__wasMuted === false) m.muted = false; });
    }
  });
})();
''',
      enabled: false,
      isPinned: false,
    ),
  ];
}

/// Aliases para compatibilidade total com código legado
typedef BrowserAddonService = ChromeExtensionService;
typedef ChromeExtensionImporter = ChromeExtensionService;

class CrxExtractor {
  const CrxExtractor._();

  static Map<String, String> extract(Uint8List bytes) {
    int zipStart = 0;
    // Se for formato CRX ("Cr24"), localiza o início do arquivo ZIP interno (PK\x03\x04)
    if (bytes.length >= 4 &&
        bytes[0] == 0x43 &&
        bytes[1] == 0x72 &&
        bytes[2] == 0x32 &&
        bytes[3] == 0x34) {
      for (int i = 0; i <= bytes.length - 4; i++) {
        if (bytes[i] == 0x50 &&
            bytes[i + 1] == 0x4B &&
            bytes[i + 2] == 0x03 &&
            bytes[i + 3] == 0x04) {
          zipStart = i;
          break;
        }
      }
    }

    final files = <String, String>{};
    final byteData = ByteData.sublistView(bytes);
    int offset = zipStart;

    while (offset + 30 <= bytes.length) {
      // Assinatura PK\x03\x04
      if (bytes[offset] != 0x50 ||
          bytes[offset + 1] != 0x4B ||
          bytes[offset + 2] != 0x03 ||
          bytes[offset + 3] != 0x04) {
        break;
      }

      final compressionMethod = byteData.getUint16(offset + 8, Endian.little);
      final compressedSize = byteData.getUint32(offset + 18, Endian.little);
      final fileNameLength = byteData.getUint16(offset + 26, Endian.little);
      final extraLength = byteData.getUint16(offset + 28, Endian.little);

      final fileNameStart = offset + 30;
      final fileNameEnd = fileNameStart + fileNameLength;
      if (fileNameEnd > bytes.length) break;

      final rawFileName = utf8.decode(
        bytes.sublist(fileNameStart, fileNameEnd),
        allowMalformed: true,
      );
      final normalizedFileName = rawFileName.replaceAll(r'\', '/');

      final dataStart = fileNameEnd + extraLength;
      final dataEnd = dataStart + compressedSize;
      if (dataEnd > bytes.length) break;

      if (!normalizedFileName.endsWith('/')) {
        final compressedData = bytes.sublist(dataStart, dataEnd);
        Uint8List uncompressedData;

        if (compressionMethod == 0) {
          uncompressedData = compressedData;
        } else if (compressionMethod == 8) {
          try {
            uncompressedData = Uint8List.fromList(
              ZLibDecoder(raw: true).convert(compressedData),
            );
          } catch (_) {
            uncompressedData = compressedData;
          }
        } else {
          uncompressedData = compressedData;
        }

        final lower = normalizedFileName.toLowerCase();
        if (lower.endsWith('.png') ||
            lower.endsWith('.jpg') ||
            lower.endsWith('.jpeg') ||
            lower.endsWith('.gif') ||
            lower.endsWith('.webp') ||
            lower.endsWith('.ico')) {
          final mime = lower.endsWith('.png')
              ? 'image/png'
              : (lower.endsWith('.ico') ? 'image/x-icon' : 'image/jpeg');
          files[normalizedFileName] =
              'data:$mime;base64,${base64Encode(uncompressedData)}';
        } else {
          files[normalizedFileName] =
              utf8.decode(uncompressedData, allowMalformed: true);
        }
      }

      offset = dataEnd;
    }

    return files;
  }
}
