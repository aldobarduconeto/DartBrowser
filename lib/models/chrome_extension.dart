import 'dart:convert';

class ChromeExtension {
  const ChromeExtension({
    required this.id,
    required this.name,
    required this.version,
    required this.description,
    required this.origin,
    required this.source,
    required this.enabled,
    this.manifestVersion = 3,
    this.matches = const [],
    this.excludeMatches = const [],
    this.permissions = const [],
    this.actionTitle,
    this.actionPopup,
    this.actionIcon,
    this.optionsPage,
    this.backgroundSource,
    this.files = const {},
    this.isPinned = false,
    this.badgeText,
    this.isCustomScript = false,
  });

  final String id;
  final String name;
  final String version;
  final String description;
  final String origin;
  final String source;
  final bool enabled;
  final int manifestVersion;
  final List<String> matches;
  final List<String> excludeMatches;
  final List<String> permissions;
  final String? actionTitle;
  final String? actionPopup;
  final String? actionIcon;
  final String? optionsPage;
  final String? backgroundSource;
  final Map<String, String> files;
  final bool isPinned;
  final String? badgeText;
  final bool isCustomScript;

  bool get hasPopup =>
      actionPopup != null &&
      actionPopup!.isNotEmpty &&
      (files.containsKey(actionPopup) ||
          files.containsKey(actionPopup!.replaceAll(r'\', '/')) ||
          files.isNotEmpty ||
          actionPopup!.contains('<html'));

  bool get hasOptions =>
      optionsPage != null &&
      optionsPage!.isNotEmpty &&
      (files.containsKey(optionsPage) ||
          files.containsKey(optionsPage!.replaceAll(r'\', '/')) ||
          files.isNotEmpty);

  /// Retorna o conteúdo HTML do popup (ou string embutida) com assets inlinados
  String? getPopupHtml() {
    if (!hasPopup) return null;
    final normalized = actionPopup!.replaceAll(r'\', '/');
    if (files.containsKey(normalized)) {
      return _inlineHtmlAssets(files[normalized]!, normalized);
    }
    if (actionPopup!.contains('<html') || actionPopup!.contains('<body')) {
      return actionPopup;
    }
    for (final entry in files.entries) {
      if (entry.key.toLowerCase().endsWith('popup.html') ||
          entry.key.toLowerCase().endsWith(normalized.toLowerCase())) {
        return _inlineHtmlAssets(entry.value, entry.key);
      }
    }
    return null;
  }

  /// Retorna o conteúdo HTML da página de opções com assets inlinados
  String? getOptionsHtml() {
    if (!hasOptions) return null;
    final normalized = optionsPage!.replaceAll(r'\', '/');
    if (files.containsKey(normalized)) {
      return _inlineHtmlAssets(files[normalized]!, normalized);
    }
    for (final entry in files.entries) {
      if (entry.key.toLowerCase().endsWith('options.html') ||
          entry.key.toLowerCase().endsWith(normalized.toLowerCase())) {
        return _inlineHtmlAssets(entry.value, entry.key);
      }
    }
    return null;
  }

  String _inlineHtmlAssets(String html, String basePath) {
    var result = html;
    final dir = basePath.contains('/')
        ? basePath.substring(0, basePath.lastIndexOf('/') + 1)
        : '';

    for (final entry in files.entries) {
      final fileName = entry.key;
      final simpleName = fileName.contains('/')
          ? fileName.substring(fileName.lastIndexOf('/') + 1)
          : fileName;

      if (fileName.endsWith('.js')) {
        final scriptTag = RegExp(
          '<script[^>]*src=[\'"](?:$fileName|$simpleName|\\.?/?$dir$simpleName)[\'"][^>]*>\\s*</script>',
          caseSensitive: false,
        );
        if (scriptTag.hasMatch(result)) {
          result = result.replaceAll(
            scriptTag,
            '<script type="text/javascript">\n${entry.value}\n</script>',
          );
        }
      } else if (fileName.endsWith('.css')) {
        final linkTag = RegExp(
          '<link[^>]*href=[\'"](?:$fileName|$simpleName|\\.?/?$dir$simpleName)[\'"][^>]*>',
          caseSensitive: false,
        );
        if (linkTag.hasMatch(result)) {
          result = result.replaceAll(
            linkTag,
            '<style type="text/css">\n${entry.value}\n</style>',
          );
        }
      }
    }
    return result;
  }

  /// Verifica se esta extensão se aplica à [url] informada.
  bool matchesPage(String url) {
    if (!enabled) return false;
    final uri = Uri.tryParse(url);
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        uri.host.isEmpty) {
      return false;
    }

    // Regras de exclusão
    for (final pattern in excludeMatches) {
      if (matchesPattern(pattern, uri)) return false;
    }

    // Padrões de correspondência explícitos
    if (matches.isNotEmpty) {
      for (final pattern in matches) {
        if (matchesPattern(pattern, uri)) return true;
      }
      return false;
    }

    // Compatibilidade com origens legadas
    if (origin.isNotEmpty && origin != '<all_urls>') {
      final parsedOrigin = parseOrigin(origin);
      if (parsedOrigin != null) {
        return uri.origin == parsedOrigin;
      }
    }

    return origin == '<all_urls>' || origin.isEmpty;
  }

  static bool matchesPattern(String pattern, Uri uri) {
    final clean = pattern.trim();
    if (clean == '<all_urls>' || clean == '*://*/*' || clean == '*://*') {
      return true;
    }

    final match = RegExp(
      r'^(\*|https?|file|ftp)://(\*|(?:\*\.)?[a-zA-Z0-9.-]+)(/.*)?$',
    ).firstMatch(clean);
    if (match == null) {
      if (clean.contains('://')) {
        final prefix = clean.split('*').first;
        return uri.toString().startsWith(prefix);
      }
      return false;
    }

    final scheme = match[1]!;
    final host = match[2]!.toLowerCase();
    final path = match[3] ?? '/*';

    // 1. Esquema
    if (scheme != '*' && scheme != uri.scheme) return false;

    // 2. Domínio
    final uriHost = uri.host.toLowerCase();
    if (host != '*') {
      if (host.startsWith('*.')) {
        final suffix = host.substring(2);
        if (uriHost != suffix && !uriHost.endsWith('.$suffix')) {
          return false;
        }
      } else {
        if (uriHost != host) return false;
      }
    }

    // 3. Caminho
    if (path == '/*' || path == '*' || path.isEmpty) return true;
    final targetPath = uri.hasQuery ? '${uri.path}?${uri.query}' : uri.path;
    final regexStr = '^${path.split('*').map(RegExp.escape).join('.*')}\$';
    try {
      return RegExp(regexStr).hasMatch(targetPath.isEmpty ? '/' : targetPath);
    } catch (_) {
      return false;
    }
  }

  static String? parseOrigin(String input) {
    final uri = Uri.tryParse(input.trim());
    if (uri == null ||
        (uri.scheme != 'https' && uri.scheme != 'http') ||
        !uri.hasAuthority ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        (uri.path.isNotEmpty && uri.path != '/') ||
        uri.hasQuery ||
        uri.hasFragment) {
      return null;
    }
    return uri.origin;
  }

  factory ChromeExtension.fromJson(Map<String, dynamic> json) {
    final id =
        json['id'] as String? ??
        (json['name'] as String? ?? 'addon').toLowerCase().replaceAll(
          RegExp(r'[^a-z0-9]'),
          '_',
        );
    return ChromeExtension(
      id: id,
      name: json['name'] as String? ?? 'Extensão Web',
      version: json['version'] as String? ?? '1.0.0',
      description: json['description'] as String? ?? '',
      origin: json['origin'] as String? ?? '<all_urls>',
      source: json['source'] as String? ?? '',
      enabled: json['enabled'] == true,
      manifestVersion:
          json['manifestVersion'] as int? ??
          (json['manifest_version'] as int? ?? 3),
      matches:
          (json['matches'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      excludeMatches:
          (json['excludeMatches'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      permissions:
          (json['permissions'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          const [],
      actionTitle: json['actionTitle'] as String?,
      actionPopup: json['actionPopup'] as String?,
      actionIcon: json['actionIcon'] as String?,
      optionsPage: json['optionsPage'] as String?,
      backgroundSource: json['backgroundSource'] as String?,
      files:
          (json['files'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v.toString()),
          ) ??
          const {},
      isPinned: json['isPinned'] == true,
      badgeText: json['badgeText'] as String?,
      isCustomScript: json['isCustomScript'] == true,
    );
  }

  String encode() => jsonEncode({
    'id': id,
    'name': name,
    'version': version,
    'description': description,
    'origin': origin,
    'source': source,
    'enabled': enabled,
    'manifestVersion': manifestVersion,
    'matches': matches,
    'excludeMatches': excludeMatches,
    'permissions': permissions,
    'actionTitle': actionTitle,
    'actionPopup': actionPopup,
    'actionIcon': actionIcon,
    'optionsPage': optionsPage,
    'backgroundSource': backgroundSource,
    'files': files,
    'isPinned': isPinned,
    'badgeText': badgeText,
    'isCustomScript': isCustomScript,
  });

  ChromeExtension copyWith({
    String? id,
    String? name,
    String? version,
    String? description,
    String? origin,
    String? source,
    bool? enabled,
    int? manifestVersion,
    List<String>? matches,
    List<String>? excludeMatches,
    List<String>? permissions,
    String? actionTitle,
    String? actionPopup,
    String? actionIcon,
    String? optionsPage,
    String? backgroundSource,
    Map<String, String>? files,
    bool? isPinned,
    String? badgeText,
    bool? isCustomScript,
  }) => ChromeExtension(
    id: id ?? this.id,
    name: name ?? this.name,
    version: version ?? this.version,
    description: description ?? this.description,
    origin: origin ?? this.origin,
    source: source ?? this.source,
    enabled: enabled ?? this.enabled,
    manifestVersion: manifestVersion ?? this.manifestVersion,
    matches: matches ?? this.matches,
    excludeMatches: excludeMatches ?? this.excludeMatches,
    permissions: permissions ?? this.permissions,
    actionTitle: actionTitle ?? this.actionTitle,
    actionPopup: actionPopup ?? this.actionPopup,
    actionIcon: actionIcon ?? this.actionIcon,
    optionsPage: optionsPage ?? this.optionsPage,
    backgroundSource: backgroundSource ?? this.backgroundSource,
    files: files ?? this.files,
    isPinned: isPinned ?? this.isPinned,
    badgeText: badgeText ?? this.badgeText,
    isCustomScript: isCustomScript ?? this.isCustomScript,
  );

  ChromeExtension withEnabled(bool value) => copyWith(enabled: value);
  ChromeExtension withPinned(bool value) => copyWith(isPinned: value);
  ChromeExtension withBadgeText(String? value) => copyWith(badgeText: value);
}

/// Alias para compatibilidade total
typedef BrowserAddon = ChromeExtension;
