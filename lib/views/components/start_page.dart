import '../../l10n/browser_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/browser_controller.dart';
import '../../models/browser_data.dart';
import '../chrome_extensions_view.dart';
import 'browser_context_menu.dart';
import 'library_modal.dart';

class StartPage extends StatelessWidget {
  const StartPage({
    super.key,
    required this.browser,
    required this.onSubmit,
    required this.onShowSettings,
  });

  final BrowserController browser;
  final ValueChanged<String> onSubmit;
  final VoidCallback onShowSettings;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final data = browser.data;
    final links = {if (data.home != null) data.home!, ...data.favorites};
    final recent = browser.savesHistory && browser.showStartRecent
        ? data.history
              .where(
                (url) => !browser.showStartFavorites || !links.contains(url),
              )
              .take(8)
        : const <String>[];

    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onSecondaryTapUp: (details) => DartBrowserContextMenu.showPageContextMenu(
        context,
        position: details.globalPosition,
        browser: browser,
        onSubmit: onSubmit,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 36),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Center(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset(
                      'assets/app_icon.png',
                      width: 48,
                      height: 48,
                      cacheWidth: 144,
                      semanticLabel: 'Dart Browser',
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                // Barra de busca central
                Card(
                  elevation: 0,
                  color: colors.surfaceContainer,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(
                      browser.cornerRadiusNotifier.value,
                    ),
                    side: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.45),
                    ),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 8,
                    ),
                    child: Row(
                      children: [
                        PopupMenuButton<SearchEngine>(
                          tooltip: 'Alterar mecanismo de busca',
                          icon: Icon(
                            Icons.search_rounded,
                            color: colors.primary,
                            size: 22,
                          ),
                          onSelected: (engine) =>
                              browser.setSearchEngine(engine),
                          itemBuilder: (_) => [
                            for (final engine in SearchEngine.values)
                              PopupMenuItem(
                                value: engine,
                                child: Row(
                                  children: [
                                    Icon(
                                      engine == browser.data.searchEngine
                                          ? Icons.radio_button_checked_rounded
                                          : Icons
                                                .radio_button_unchecked_rounded,
                                      size: 18,
                                      color: engine == browser.data.searchEngine
                                          ? colors.primary
                                          : null,
                                    ),
                                    const SizedBox(width: 8),
                                    Text(engine.label),
                                  ],
                                ),
                              ),
                          ],
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            decoration: InputDecoration(
                              hintText:
                                  'Pesquisar com ${browser.data.searchEngine.label} ou digitar URL...',
                              border: InputBorder.none,
                              hintStyle: TextStyle(
                                color: colors.onSurfaceVariant.withValues(
                                  alpha: 0.7,
                                ),
                                fontSize: 14.5,
                              ),
                            ),
                            onSubmitted: onSubmit,
                          ),
                        ),
                        IconButton(
                          tooltip: 'Colar e pesquisar',
                          icon: Icon(
                            Icons.content_paste_rounded,
                            size: 18,
                            color: colors.onSurfaceVariant,
                          ),
                          onPressed: () async {
                            final data = await Clipboard.getData(
                              Clipboard.kTextPlain,
                            );
                            final text = data?.text?.trim();
                            if (text != null && text.isNotEmpty) {
                              onSubmit(text);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 24),

                // Atalhos rápidos
                if (browser.showStartFavorites && links.isNotEmpty)
                  _buildQuickSection(
                    context,
                    title: 'Acesso rápido',
                    icon: Icons.star_rounded,
                    urls: links.take(8),
                  ),

                if (recent.isNotEmpty)
                  _buildQuickSection(
                    context,
                    title: 'Recentes',
                    icon: Icons.history_rounded,
                    urls: recent,
                  ),

                const SizedBox(height: 24),

                // Pílulas de Ações Rápidas
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(Icons.extension_rounded, size: 16),
                      label: Text('Extensões (${browser.addons.length})'),
                      onPressed: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => BrowserAddons(browser: browser),
                        ),
                      ),
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.bookmark_outline_rounded,
                        size: 16,
                      ),
                      label: const BrowserText('Favoritos'),
                      onPressed: () async {
                        final url = await LibraryModal.show(
                          context,
                          browser: browser,
                          initialIndex: 0,
                        );
                        if (url != null) onSubmit(url);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.history_rounded, size: 16),
                      label: const BrowserText('Histórico'),
                      onPressed: () async {
                        final url = await LibraryModal.show(
                          context,
                          browser: browser,
                          initialIndex: 1,
                        );
                        if (url != null) onSubmit(url);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.menu_book_rounded, size: 16),
                      label: Text(
                        'Ler Depois (${browser.data.readingList.length})',
                      ),
                      onPressed: () async {
                        final url = await LibraryModal.show(
                          context,
                          browser: browser,
                          initialIndex: 2,
                        );
                        if (url != null) onSubmit(url);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.download_rounded, size: 16),
                      label: Text(
                        'Downloads (${browser.data.downloads.length})',
                      ),
                      onPressed: () async {
                        final url = await LibraryModal.show(
                          context,
                          browser: browser,
                          initialIndex: 3,
                        );
                        if (url != null) onSubmit(url);
                      },
                    ),
                    ActionChip(
                      avatar: const Icon(
                        Icons.visibility_off_rounded,
                        size: 16,
                      ),
                      label: const BrowserText('Nova Guia Anônima'),
                      onPressed: () => browser.addIncognitoTab(),
                    ),
                    ActionChip(
                      avatar: const Icon(Icons.settings_outlined, size: 16),
                      label: const BrowserText('Configurações'),
                      onPressed: onShowSettings,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickSection(
    BuildContext context, {
    required String title,
    required IconData icon,
    required Iterable<String> urls,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: colors.primary),
              const SizedBox(width: 8),
              Text(
                browserText(context, title),
                style: Theme.of(context).textTheme.titleSmall,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [for (final url in urls) _buildSiteCard(context, url)],
          ),
        ],
      ),
    );
  }

  Widget _buildSiteCard(BuildContext context, String url) {
    final colors = Theme.of(context).colorScheme;
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? url;
    final cleanHost = host.replaceFirst(RegExp(r'^www\.'), '');
    final initial = cleanHost.isNotEmpty ? cleanHost[0].toUpperCase() : 'W';
    final faviconEndpoint = cleanHost.isNotEmpty
        ? 'https://www.google.com/s2/favicons?domain=$cleanHost&sz=64'
        : null;

    return SizedBox(
      width: 144,
      child: Material(
        color: colors.surfaceContainer,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.35),
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          hoverColor: colors.primary.withValues(alpha: 0.08),
          onTap: () => onSubmit(url),
          onSecondaryTapUp: (details) =>
              DartBrowserContextMenu.showSiteCardContextMenu(
                context,
                url: url,
                position: details.globalPosition,
                browser: browser,
              ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  decoration: BoxDecoration(
                    color: colors.primaryContainer.withValues(alpha: 0.35),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: faviconEndpoint != null
                        ? ClipRRect(
                            borderRadius: BorderRadius.circular(6),
                            child: Image.network(
                              faviconEndpoint,
                              width: 20,
                              height: 20,
                              fit: BoxFit.contain,
                              errorBuilder: (_, _, _) => Image.network(
                                'https://icons.duckduckgo.com/ip3/$cleanHost.ico',
                                width: 20,
                                height: 20,
                                fit: BoxFit.contain,
                                errorBuilder: (_, _, _) => Text(
                                  initial,
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: colors.primary,
                                  ),
                                ),
                              ),
                            ),
                          )
                        : Text(
                            initial,
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 13,
                              color: colors.primary,
                            ),
                          ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    host,
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
