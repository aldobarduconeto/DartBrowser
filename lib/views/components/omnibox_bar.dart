import '../../l10n/browser_text.dart';

import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';
import '../../models/browser_data.dart';
import '../../models/chrome_extension.dart';
import '../browser_settings.dart';
import '../chrome_extensions_view.dart';
import 'browser_context_menu.dart';
import 'library_modal.dart';
import 'media_sniffer_dialog.dart';
import 'page_source_viewer.dart';
import 'qr_share_dialog.dart';
import 'reader_mode_view.dart';
import 'shield_dialog.dart';
import 'site_info_dialog.dart';
import 'site_notes_dialog.dart';
import 'user_agent_dialog.dart';
import 'command_palette_dialog.dart';
import 'web_capture_dialog.dart';
import 'ambient_sounds_dialog.dart';

class OmniboxBar extends StatelessWidget {
  const OmniboxBar({
    super.key,
    required this.browser,
    required this.addressController,
    required this.addressFocus,
    required this.onSubmit,
    required this.onShowExtensionsMenu,
    required this.onOpenExtensionPopup,
  });

  final BrowserController browser;
  final TextEditingController addressController;
  final FocusNode addressFocus;
  final ValueChanged<String> onSubmit;
  final VoidCallback onShowExtensionsMenu;
  final void Function(BrowserAddon) onOpenExtensionPopup;

  void _showPageFilters(BuildContext context) {
    final tab = browser.current;
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Filtros Visuais da Página',
                style: Theme.of(ctx).textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              for (final filter in PageVisualFilter.values)
                ListTile(
                  leading: Icon(filter.icon),
                  title: Text(filter.label),
                  trailing: tab.visualFilter == filter
                      ? const Icon(Icons.check, color: Color(0xFF2563EB))
                      : null,
                  onTap: () {
                    Navigator.pop(ctx);
                    browser.applyPageVisualFilter(tab, filter);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final tab = browser.current;
    final favorite = browser.data.favorites.contains(tab.address);
    final inReadingList =
        tab.address != null && browser.isInReadingList(tab.address!);
    final isHttps = tab.address?.startsWith('https://') == true;
    final activeAddons = browser.activeAddonsForCurrentPage;
    final pinnedAddons = browser.pinnedAddons;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: tab.isIncognito
            ? (dark ? const Color(0xFF13111C) : const Color(0xFFF3E8FF))
            : colors.surface,
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.18),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          // BOTÃO VOLTAR
          IconButton(
            tooltip: 'Voltar',
            visualDensity: VisualDensity.compact,
            onPressed: tab.canGoBack ? browser.goBack : null,
            icon: const Icon(Icons.arrow_back_rounded, size: 18),
          ),

          // BOTÃO AVANÇAR
          IconButton(
            tooltip: 'Avançar',
            visualDensity: VisualDensity.compact,
            onPressed: tab.canGoForward ? browser.goForward : null,
            icon: const Icon(Icons.arrow_forward_rounded, size: 18),
          ),

          // BOTÃO RECARREGAR / PARAR
          IconButton(
            tooltip: tab.progress < 100 ? 'Parar carregamento' : 'Recarregar',
            visualDensity: VisualDensity.compact,
            onPressed: tab.address == null
                ? null
                : tab.progress < 100
                ? browser.stop
                : browser.reload,
            icon: Icon(
              tab.progress < 100 ? Icons.close_rounded : Icons.refresh_rounded,
              size: 18,
            ),
          ),

          // BOTÃO PÁGINA INICIAL
          IconButton(
            tooltip: 'Página inicial',
            visualDensity: VisualDensity.compact,
            onPressed: browser.data.home == null
                ? () => browser.addTab()
                : () => onSubmit(browser.data.home!),
            icon: const Icon(Icons.home_rounded, size: 18),
          ),
          const SizedBox(width: 4),

          // CÁPSULA DA OMNIBOX
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.translucent,
              onSecondaryTapUp: (details) =>
                  DartBrowserContextMenu.showOmniboxContextMenu(
                    context,
                    position: details.globalPosition,
                    controller: addressController,
                    browser: browser,
                    onSubmit: onSubmit,
                  ),
              child: Container(
                height: 38,
                decoration: BoxDecoration(
                  color: addressFocus.hasFocus
                      ? colors.surface
                      : colors.surfaceContainerLow,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: tab.isIncognito
                        ? Colors.purple.withValues(alpha: 0.5)
                        : addressFocus.hasFocus
                        ? colors.primary
                        : colors.outlineVariant.withValues(alpha: 0.24),
                    width: addressFocus.hasFocus ? 1.5 : 1,
                  ),
                ),
                child: Row(
                  children: [
                    // Ícone de segurança ou anonimato com clique para detalhes
                    InkWell(
                      borderRadius: BorderRadius.circular(18),
                      onTap: tab.address == null
                          ? null
                          : () => SiteInfoDialog.show(context, browser),
                      child: Padding(
                        padding: const EdgeInsets.only(left: 10, right: 6),
                        child: tab.isIncognito
                            ? const Tooltip(
                                message: 'Guia Anônima',
                                child: Icon(
                                  Icons.visibility_off_rounded,
                                  size: 15,
                                  color: Colors.purple,
                                ),
                              )
                            : Tooltip(
                                message: isHttps
                                    ? 'A conexão é segura. Clique para detalhes.'
                                    : 'Não seguro. Clique para detalhes.',
                                child: Icon(
                                  isHttps
                                      ? Icons.lock_rounded
                                      : Icons.search_rounded,
                                  size: 15,
                                  color: isHttps
                                      ? Colors.green.shade600
                                      : colors.onSurfaceVariant,
                                ),
                              ),
                      ),
                    ),

                    // Campo de texto da URL
                    Expanded(
                      child: TextField(
                        controller: addressController,
                        focusNode: addressFocus,
                        autocorrect: false,
                        keyboardType: TextInputType.url,
                        textInputAction: TextInputAction.go,
                        onSubmitted: onSubmit,
                        style: const TextStyle(fontSize: 13),
                        decoration: InputDecoration(
                          hintText:
                              'Pesquisar com ${browser.data.searchEngine.label} ou digitar URL',
                          hintStyle: TextStyle(
                            fontSize: 12.5,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: const EdgeInsets.symmetric(
                            vertical: 8,
                          ),
                        ),
                      ),
                    ),

                    // Indicador de Zoom (se diferente de 100%)
                    if (tab.zoomLevel != 1.0)
                      Tooltip(
                        message: 'Redefinir zoom para 100%',
                        child: TextButton(
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: browser.resetZoom,
                          child: Text(
                            '${(tab.zoomLevel * 100).round()}%',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                              color: colors.primary,
                            ),
                          ),
                        ),
                      ),

                    // Botão Modo Leitura
                    if (tab.address != null && tab.progress == 100)
                      IconButton(
                        tooltip: tab.isReaderMode
                            ? 'Sair do modo leitura'
                            : 'Modo leitura sem distrações',
                        visualDensity: VisualDensity.compact,
                        onPressed: () => browser.toggleReaderMode(),
                        icon: Icon(
                          Icons.chrome_reader_mode_rounded,
                          size: 18,
                          color: tab.isReaderMode
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),

                    // Botão Compartilhar via QR Code
                    if (tab.address != null)
                      IconButton(
                        tooltip: 'Escanear link no celular (QR Code)',
                        visualDensity: VisualDensity.compact,
                        onPressed: () =>
                            QrShareDialog.show(context, tab.address!),
                        icon: Icon(
                          Icons.qr_code_2_rounded,
                          size: 18,
                          color: colors.onSurfaceVariant,
                        ),
                      ),

                    // Botão Lista de Leitura ("Ler Depois")
                    if (tab.address != null)
                      IconButton(
                        tooltip: inReadingList
                            ? 'Remover de Ler Depois'
                            : 'Salvar para Ler Depois',
                        visualDensity: VisualDensity.compact,
                        onPressed: browser.toggleReadingListCurrent,
                        icon: Icon(
                          inReadingList
                              ? Icons.bookmark_added_rounded
                              : Icons.bookmark_add_outlined,
                          size: 18,
                          color: inReadingList
                              ? colors.primary
                              : colors.onSurfaceVariant,
                        ),
                      ),

                    // Escudo de Proteção AdBlock & Anti-Rastreio
                    if (tab.address != null)
                      Builder(
                        builder: (context) {
                          final isWhitelisted = browser.isHostWhitelisted(
                            tab.host,
                          );
                          final isActive =
                              (browser.data.adBlockEnabled ||
                                  browser.data.antiTrackingEnabled) &&
                              !isWhitelisted;
                          final count = tab.totalBlockedCount;

                          return Tooltip(
                            message: isActive
                                ? 'Escudo Ativo: $count itens bloqueados. Clique para detalhes.'
                                : 'Escudo Pausado neste site. Clique para ativar.',
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () => ShieldDialog.show(
                                context,
                                browser: browser,
                                tab: tab,
                              ),
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                  vertical: 4,
                                ),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(
                                      isActive
                                          ? Icons.shield_rounded
                                          : Icons.shield_outlined,
                                      size: 17,
                                      color: isActive
                                          ? (count > 0
                                                ? Colors.green.shade600
                                                : colors.primary)
                                          : Colors.grey,
                                    ),
                                    if (count > 0 && isActive) ...[
                                      const SizedBox(width: 4),
                                      Text(
                                        '$count',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green.shade700,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                            ),
                          );
                        },
                      ),

                    // Botão de Favorito
                    IconButton(
                      tooltip: favorite
                          ? 'Remover dos favoritos'
                          : 'Adicionar aos favoritos',
                      visualDensity: VisualDensity.compact,
                      onPressed: tab.address == null
                          ? null
                          : browser.toggleFavorite,
                      icon: Icon(
                        favorite
                            ? Icons.star_rounded
                            : Icons.star_border_rounded,
                        size: 19,
                        color: favorite ? Colors.amber.shade700 : null,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 6),

          // EXTENSÕES FIXADAS
          for (final addon in pinnedAddons)
            Tooltip(
              message: addon.actionTitle ?? addon.name,
              child: Stack(
                alignment: Alignment.topRight,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      addon.id.contains('dark')
                          ? Icons.dark_mode_rounded
                          : addon.id.contains('adblock')
                          ? Icons.shield_rounded
                          : addon.id.contains('json')
                          ? Icons.code_rounded
                          : addon.id.contains('markdown')
                          ? Icons.text_snippet_rounded
                          : Icons.extension_rounded,
                      size: 20,
                      color: addon.enabled
                          ? colors.primary
                          : colors.onSurfaceVariant,
                    ),
                    onPressed: () {
                      if (addon.hasPopup) {
                        onOpenExtensionPopup(addon);
                      } else {
                        browser.toggleAddon(addon);
                      }
                    },
                  ),
                  if (addon.badgeText != null && addon.badgeText!.isNotEmpty)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
                      decoration: BoxDecoration(
                        color: colors.primary,
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        addon.badgeText!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                ],
              ),
            ),

          // BOTÃO DE EXTENSÕES
          Tooltip(
            message: 'Extensões',
            child: Stack(
              alignment: Alignment.topRight,
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.extension_rounded, size: 18),
                  onPressed: onShowExtensionsMenu,
                ),
                if (activeAddons.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: colors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      '${activeAddons.length}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 9,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          // MENU PRINCIPAL EXPANDIDO
          PopupMenuButton<String>(
            tooltip: 'Menu de opções',
            icon: const Icon(Icons.more_vert_rounded, size: 18),
            onSelected: (value) async {
              switch (value) {
                case 'new_tab':
                  browser.addTab(address: browser.data.home);
                case 'command_palette':
                  CommandPaletteDialog.show(
                    context,
                    browser: browser,
                    onSubmit: onSubmit,
                  );
                case 'web_capture':
                  WebCaptureDialog.show(context, browser);
                case 'translate':
                  browser.translateCurrentPage();
                case 'ambient_sounds':
                  AmbientSoundsDialog.show(context, browser);
                case 'favorites':
                  final url = await LibraryModal.show(
                    context,
                    browser: browser,
                    initialIndex: 0,
                  );
                  if (url != null) onSubmit(url);
                case 'bookmark_tabs':
                  final count = await browser.bookmarkOpenTabs();
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          count == 0
                              ? 'Nenhuma aba nova para favoritar.'
                              : count == 1
                              ? '1 aba adicionada aos favoritos.'
                              : '$count abas adicionadas aos favoritos.',
                        ),
                      ),
                    );
                  }
                case 'history':
                  final url = await LibraryModal.show(
                    context,
                    browser: browser,
                    initialIndex: 1,
                  );
                  if (url != null) onSubmit(url);
                case 'reading_list':
                  final url = await LibraryModal.show(
                    context,
                    browser: browser,
                    initialIndex: 2,
                  );
                  if (url != null) onSubmit(url);
                case 'downloads':
                  final url = await LibraryModal.show(
                    context,
                    browser: browser,
                    initialIndex: 3,
                  );
                  if (url != null) onSubmit(url);
                case 'page_filter':
                  _showPageFilters(context);
                case 'split_screen':
                  browser.toggleSplitScreen();
                case 'fullscreen':
                  browser.toggleFullScreen();
                case 'incognito':
                  browser.addIncognitoTab();
                case 'qr_share':
                  if (tab.address != null) {
                    QrShareDialog.show(context, tab.address!);
                  }
                case 'media_sniffer':
                  MediaSnifferDialog.show(context, browser);
                case 'shield':
                  ShieldDialog.show(context, browser: browser, tab: tab);
                case 'reader_mode':
                  if (tab.address != null) {
                    ReaderModeView.show(
                      context,
                      engine: tab.engine,
                      url: tab.address!,
                    );
                  }
                case 'site_notes':
                  SiteNotesDialog.show(
                    context,
                    browser: browser,
                    host: tab.host,
                  );
                case 'view_source':
                  PageSourceViewer.show(context, browser);
                case 'user_agent':
                  UserAgentDialog.show(context, browser);
                case 'mute':
                  browser.toggleMuteTab(tab);
                case 'pin':
                  browser.togglePinTab(tab);
                case 'find':
                  browser.openFindInPage();
                case 'zoom_in':
                  await browser.zoomIn();
                case 'zoom_out':
                  await browser.zoomOut();
                case 'zoom_reset':
                  await browser.resetZoom();
                case 'duplicate':
                  browser.duplicateTab();
                case 'reopen':
                  browser.reopenTab();
                case 'pictureInPicture':
                  await browser.enterAndroidPictureInPicture();
                case 'tabLayout':
                  browser.setVerticalTabs(!browser.verticalTabs);
                case 'addons':
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => BrowserAddons(browser: browser),
                    ),
                  );
                case 'settings':
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => BrowserSettings(browser: browser),
                    ),
                  );
                case 'theme':
                  browser.setTheme(dark ? ThemeMode.light : ThemeMode.dark);
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'new_tab',
                child: Row(
                  children: [
                    Icon(Icons.add_rounded, size: 18),
                    SizedBox(width: 10),
                    BrowserText('Nova Guia (Ctrl+T)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'incognito',
                child: Row(
                  children: [
                    Icon(
                      Icons.visibility_off_rounded,
                      size: 18,
                      color: Colors.purple,
                    ),
                    SizedBox(width: 10),
                    BrowserText('Nova Guia Anônima (Ctrl+Shift+N)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'command_palette',
                child: Row(
                  children: [
                    Icon(
                      Icons.terminal_rounded,
                      size: 18,
                      color: Color(0xFF2563EB),
                    ),
                    SizedBox(width: 10),
                    BrowserText('Paleta de Comandos (Ctrl+K)'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'history',
                child: Row(
                  children: [
                    Icon(Icons.history_rounded, size: 18),
                    SizedBox(width: 10),
                    BrowserText('Histórico (Ctrl+H)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'favorites',
                child: Row(
                  children: [
                    Icon(Icons.star_rounded, size: 18),
                    SizedBox(width: 10),
                    BrowserText('Favoritos (Ctrl+D)'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'downloads',
                child: Row(
                  children: [
                    Icon(Icons.download_rounded, size: 18),
                    SizedBox(width: 10),
                    BrowserText('Central de Downloads'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              PopupMenuItem(
                enabled: false,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Zoom', style: TextStyle(color: Colors.grey)),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.remove_rounded, size: 16),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Navigator.pop(context);
                            browser.zoomOut();
                          },
                        ),
                        Text(
                          '${(tab.zoomLevel * 100).round()}%',
                          style: const TextStyle(fontSize: 12),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add_rounded, size: 16),
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Navigator.pop(context);
                            browser.zoomIn();
                          },
                        ),
                        const SizedBox(width: 4),
                        IconButton(
                          icon: Icon(
                            browser.fullScreenNotifier.value
                                ? Icons.fullscreen_exit_rounded
                                : Icons.fullscreen_rounded,
                            size: 18,
                          ),
                          tooltip: 'Tela Cheia (F11)',
                          visualDensity: VisualDensity.compact,
                          onPressed: () {
                            Navigator.pop(context);
                            browser.toggleFullScreen();
                          },
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'find',
                enabled: tab.address != null,
                child: const Row(
                  children: [
                    Icon(Icons.search_rounded, size: 18),
                    SizedBox(width: 10),
                    BrowserText('Localizar na página (Ctrl+F)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'web_capture',
                enabled: tab.address != null,
                child: const Row(
                  children: [
                    Icon(
                      Icons.camera_alt_rounded,
                      size: 18,
                      color: Colors.deepOrange,
                    ),
                    SizedBox(width: 10),
                    BrowserText('Captura de Tela (Ctrl+Shift+S)'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'translate',
                enabled: tab.address != null,
                child: const Row(
                  children: [
                    Icon(Icons.translate_rounded, size: 18, color: Colors.blue),
                    SizedBox(width: 10),
                    BrowserText('Traduzir Página para Português'),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem(
                value: 'addons',
                child: Row(
                  children: [
                    Icon(Icons.extension_rounded, size: 18),
                    SizedBox(width: 10),
                    BrowserText('Extensões Web'),
                  ],
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: Row(
                  children: [
                    Icon(Icons.settings_outlined, size: 18),
                    SizedBox(width: 10),
                    BrowserText('Configurações'),
                  ],
                ),
              ),
              PopupMenuItem(
                value: 'theme',
                child: Row(
                  children: [
                    Icon(
                      dark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
                      size: 18,
                    ),
                    SizedBox(width: 10),
                    Text(dark ? 'Tema claro' : 'Tema escuro'),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
