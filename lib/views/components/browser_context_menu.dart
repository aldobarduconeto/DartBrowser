import '../../l10n/browser_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/browser_controller.dart';
import '../../models/browser_data.dart';
import '../browser_settings.dart';
import '../chrome_extensions_view.dart';
import 'library_modal.dart';
import 'page_source_viewer.dart';
import 'qr_share_dialog.dart';
import 'reader_mode_view.dart';
import 'shield_dialog.dart';
import 'site_notes_dialog.dart';
import 'sneak_peek_dialog.dart';
import 'command_palette_dialog.dart';
import 'web_capture_dialog.dart';

class DartBrowserContextMenu {
  const DartBrowserContextMenu._();

  static bool _isMobileDevice(BuildContext context, [bool? isTouch]) {
    if (isTouch == true) return true;
    final platform = Theme.of(context).platform;
    return platform == TargetPlatform.android ||
        platform == TargetPlatform.iOS ||
        MediaQuery.sizeOf(context).width < 600;
  }

  // Helper para criar item de menu com ícone, título e atalho de teclado
  static PopupMenuItem<String> _menuItem({
    required String value,
    required IconData icon,
    required String label,
    String? shortcut,
    bool enabled = true,
    Color? iconColor,
    Color? textColor,
  }) {
    return PopupMenuItem<String>(
      value: value,
      enabled: enabled,
      height: 36,
      child: Row(
        children: [
          Icon(icon, size: 16, color: enabled ? iconColor : Colors.grey),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              label,
              style: TextStyle(
                fontSize: 13,
                color: enabled ? textColor : Colors.grey,
              ),
            ),
          ),
          if (shortcut != null) ...[
            const SizedBox(width: 12),
            Text(
              shortcut,
              style: TextStyle(
                fontSize: 11,
                color: enabled
                    ? Colors.grey
                    : Colors.grey.withValues(alpha: 0.5),
                fontFamily: 'monospace',
              ),
            ),
          ],
        ],
      ),
    );
  }

  // -------------------------------------------------------------
  // 1. MENU DE CONTEXTO DE LINKS (COM SNEAK & PEEK)
  // -------------------------------------------------------------
  static Future<void> showLinkContextMenu(
    BuildContext context, {
    required String url,
    String? linkText,
    Offset? position,
    bool isTouch = false,
    required BrowserController browser,
    ValueChanged<String>? onSubmit,
  }) async {
    final colors = Theme.of(context).colorScheme;
    final uri = Uri.tryParse(url);
    final host = uri?.host ?? url;
    final isMobile = _isMobileDevice(context, isTouch);

    // MODO DISPOSITIVOS MÓVEIS (MODAL BOTTOM SHEET ELEGANTE)
    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Informação do Link
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: colors.primary.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(
                        Icons.link_rounded,
                        color: colors.primary,
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (linkText != null && linkText.isNotEmpty)
                                ? linkText
                                : host,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 14,
                            ),
                          ),
                          Text(
                            url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: colors.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Destaque do Sneak & Peek (Espiar página)
                FilledButton.tonalIcon(
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                  icon: const Icon(Icons.remove_red_eye_rounded, size: 20),
                  label: const Text(
                    'Espiar página (Sneak & Peek)',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onPressed: () {
                    Navigator.pop(ctx);
                    SneakPeekDialog.show(
                      context,
                      url: url,
                      title: linkText,
                      browser: browser,
                      onOpenFull: onSubmit,
                    );
                  },
                ),
                const SizedBox(height: 10),
                const Divider(),

                ListTile(
                  leading: const Icon(Icons.open_in_new_rounded),
                  title: const Text('Abrir em nova aba'),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    browser.addTab(address: url);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.visibility_off_rounded,
                    color: Colors.purple,
                  ),
                  title: const Text('Abrir em Guia Anônima'),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    browser.addIncognitoTab(address: url);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.vertical_split_rounded),
                  title: const Text('Abrir em Tela Dividida'),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    browser.addTab(address: url);
                    browser.toggleSplitScreen(browser.tabs.length - 1);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.copy_rounded),
                  title: const Text('Copiar endereço do link'),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    Clipboard.setData(ClipboardData(text: url));
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Link copiado!')),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.bookmark_add_outlined),
                  title: const Text('Salvar para Ler Depois'),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    browser.addToReadingList(url, linkText ?? url);
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Salvo na lista de leitura!'),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.qr_code_2_rounded),
                  title: const BrowserText('Compartilhar via QR Code'),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    QrShareDialog.show(context, url);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const Text('Baixar destino do link'),
                  dense: true,
                  onTap: () {
                    Navigator.pop(ctx);
                    final fileName =
                        Uri.tryParse(url)?.pathSegments.lastOrNull ??
                        'download';
                    browser.recordDownload(url, fileName, 0);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Download de "$fileName" iniciado!'),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
      return;
    }

    // MODO DESKTOP (MENU SUSPENSO NO CURSOR DO MOUSE)
    final pos = position ?? Offset.zero;
    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(pos.dx, pos.dy, pos.dx, pos.dy),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        _menuItem(
          value: 'sneak_peek',
          icon: Icons.remove_red_eye_rounded,
          label: 'Espiar link (Sneak & Peek)',
          shortcut: 'Alt+Clique',
          iconColor: colors.primary,
        ),
        const PopupMenuDivider(),
        _menuItem(
          value: 'open_new_tab',
          icon: Icons.open_in_new_rounded,
          label: 'Abrir link em nova aba',
          shortcut: 'Ctrl+Clique',
        ),
        _menuItem(
          value: 'open_incognito',
          icon: Icons.visibility_off_rounded,
          label: 'Abrir link em Guia Anônima',
          iconColor: Colors.purple,
        ),
        _menuItem(
          value: 'open_split',
          icon: Icons.vertical_split_rounded,
          label: 'Abrir em Tela Dividida',
        ),
        const PopupMenuDivider(),
        _menuItem(
          value: 'copy_url',
          icon: Icons.copy_rounded,
          label: 'Copiar endereço do link',
        ),
        _menuItem(
          value: 'reading_list',
          icon: Icons.bookmark_add_outlined,
          label: 'Salvar para Ler Depois',
        ),
        _menuItem(
          value: 'qr_share',
          icon: Icons.qr_code_2_rounded,
          label: 'Compartilhar via QR Code',
        ),
        _menuItem(
          value: 'download',
          icon: Icons.download_rounded,
          label: 'Baixar arquivo do link',
        ),
      ],
    );

    if (selected == null || !context.mounted) return;

    switch (selected) {
      case 'sneak_peek':
        SneakPeekDialog.show(
          context,
          url: url,
          title: linkText,
          browser: browser,
          onOpenFull: onSubmit,
        );
      case 'open_new_tab':
        browser.addTab(address: url);
      case 'open_incognito':
        browser.addIncognitoTab(address: url);
      case 'open_split':
        browser.addTab(address: url);
        browser.toggleSplitScreen(browser.tabs.length - 1);
      case 'copy_url':
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link copiado para a área de transferência!'),
            ),
          );
        }
      case 'reading_list':
        await browser.addToReadingList(url, linkText ?? url);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Salvo na lista de leitura!')),
          );
        }
      case 'qr_share':
        QrShareDialog.show(context, url);
      case 'download':
        final fileName =
            Uri.tryParse(url)?.pathSegments.lastOrNull ?? 'download';
        await browser.recordDownload(url, fileName, 0);
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download registrado: $fileName')),
          );
        }
    }
  }

  // -------------------------------------------------------------
  // 2. MENU DE CONTEXTO DA PÁGINA / VIEWPORT
  // -------------------------------------------------------------
  static Future<void> showPageContextMenu(
    BuildContext context, {
    required Offset position,
    required BrowserController browser,
    ValueChanged<String>? onSubmit,
    bool isTouch = false,
  }) async {
    final tab = browser.current;
    final sourceAddress = tab.address;
    final hasAddress = tab.address != null && tab.address!.isNotEmpty;
    final isFavorite =
        hasAddress && browser.data.favorites.contains(tab.address);
    final isMobile = _isMobileDevice(context, isTouch);

    ClipboardData? clipData;
    try {
      clipData = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {}
    final clipText = clipData?.text?.trim();
    final hasClipboardUrl =
        clipText != null &&
        clipText.isNotEmpty &&
        BrowserData.isWeb(Uri.tryParse(clipText) ?? Uri());

    if (!context.mounted ||
        !identical(browser.current, tab) ||
        tab.address != sourceAddress) {
      return;
    }

    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.arrow_back_rounded),
                title: const BrowserText('Voltar'),
                enabled: tab.canGoBack,
                onTap: () {
                  Navigator.pop(ctx);
                  browser.goBack();
                },
              ),
              ListTile(
                leading: const Icon(Icons.arrow_forward_rounded),
                title: const BrowserText('Avançar'),
                enabled: tab.canGoForward,
                onTap: () {
                  Navigator.pop(ctx);
                  browser.goForward();
                },
              ),
              ListTile(
                leading: const Icon(Icons.refresh_rounded),
                title: const Text('Recarregar'),
                onTap: () {
                  Navigator.pop(ctx);
                  browser.reload();
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const BrowserText('Nova aba'),
                onTap: () {
                  Navigator.pop(ctx);
                  browser.addTab();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_off_rounded,
                  color: Colors.purple,
                ),
                title: const BrowserText('Nova Guia Anônima'),
                onTap: () {
                  Navigator.pop(ctx);
                  browser.addIncognitoTab();
                },
              ),
              ListTile(
                leading: const Icon(Icons.terminal_rounded, color: Colors.blue),
                title: const Text('Paleta de Comandos'),
                onTap: () {
                  Navigator.pop(ctx);
                  CommandPaletteDialog.show(
                    context,
                    browser: browser,
                    onSubmit: onSubmit ?? (url) => browser.open(url),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.deepOrange,
                ),
                title: const Text('Captura de Tela da Página'),
                onTap: () {
                  Navigator.pop(ctx);
                  WebCaptureDialog.show(context, browser);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.translate_rounded,
                  color: Colors.teal,
                ),
                title: const BrowserText('Traduzir Página para Português'),
                onTap: () {
                  Navigator.pop(ctx);
                  browser.translateCurrentPage();
                },
              ),
              if (hasAddress) ...[
                ListTile(
                  leading: Icon(
                    isFavorite
                        ? Icons.star_rounded
                        : Icons.star_outline_rounded,
                    color: isFavorite ? Colors.amber : null,
                  ),
                  title: Text(
                    isFavorite
                        ? 'Remover dos favoritos'
                        : 'Adicionar aos favoritos',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    browser.toggleFavorite();
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.shield_rounded,
                    color: Colors.green,
                  ),
                  title: Text(
                    'Escudo AdBlock & Anti-Rastreio (${tab.totalBlockedCount})',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ShieldDialog.show(context, browser: browser, tab: tab);
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.chrome_reader_mode_rounded,
                    color: Colors.teal,
                  ),
                  title: const BrowserText('Modo Leitura Limpa'),
                  onTap: () {
                    Navigator.pop(ctx);
                    ReaderModeView.show(
                      context,
                      engine: tab.engine,
                      url: tab.address!,
                    );
                  },
                ),
                ListTile(
                  leading: const Icon(
                    Icons.note_alt_outlined,
                    color: Colors.amber,
                  ),
                  title: const BrowserText('Anotações deste Site'),
                  onTap: () {
                    Navigator.pop(ctx);
                    SiteNotesDialog.show(
                      context,
                      browser: browser,
                      host: tab.host,
                    );
                  },
                ),
                ListTile(
                  leading: Icon(
                    tab.isMuted
                        ? Icons.volume_up_rounded
                        : Icons.volume_off_rounded,
                  ),
                  title: Text(
                    tab.isMuted ? 'Desativar Mudo da Aba' : 'Silenciar Aba',
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    browser.toggleMuteCurrentTab();
                  },
                ),
              ],
              ListTile(
                leading: const Icon(
                  Icons.extension_rounded,
                  color: Colors.blue,
                ),
                title: const BrowserText('Extensões Web'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => BrowserAddons(browser: browser),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.settings_outlined),
                title: const BrowserText('Configurações'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => BrowserSettings(browser: browser),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        _menuItem(
          value: 'back',
          icon: Icons.arrow_back_rounded,
          label: 'Voltar',
          shortcut: 'Alt+←',
          enabled: tab.canGoBack,
        ),
        _menuItem(
          value: 'forward',
          icon: Icons.arrow_forward_rounded,
          label: 'Avançar',
          shortcut: 'Alt+→',
          enabled: tab.canGoForward,
        ),
        _menuItem(
          value: 'reload',
          icon: Icons.refresh_rounded,
          label: 'Recarregar',
          shortcut: 'F5',
          enabled: hasAddress,
        ),
        const PopupMenuDivider(),
        _menuItem(
          value: 'new_tab',
          icon: Icons.add_rounded,
          label: 'Nova aba',
          shortcut: 'Ctrl+T',
        ),
        _menuItem(
          value: 'new_incognito',
          icon: Icons.visibility_off_rounded,
          label: 'Nova Guia Anônima',
          shortcut: 'Ctrl+Shift+N',
        ),
        if (browser.canReopenTab)
          _menuItem(
            value: 'reopen_tab',
            icon: Icons.restore_page_rounded,
            label: 'Reabrir aba fechada',
            shortcut: 'Ctrl+Shift+T',
          ),
        if (hasClipboardUrl)
          _menuItem(
            value: 'paste_and_go',
            icon: Icons.link_rounded,
            label: 'Colar e ir para link',
            iconColor: const Color(0xFF2563EB),
          ),
        _menuItem(
          value: 'command_palette',
          icon: Icons.terminal_rounded,
          label: 'Paleta de Comandos',
          shortcut: 'Ctrl+K',
          iconColor: const Color(0xFF2563EB),
        ),
        _menuItem(
          value: 'web_capture',
          icon: Icons.camera_alt_rounded,
          label: 'Captura de tela da página',
          shortcut: 'Ctrl+Shift+S',
          iconColor: Colors.deepOrange,
        ),
        _menuItem(
          value: 'translate',
          icon: Icons.translate_rounded,
          label: 'Traduzir para Português',
          iconColor: Colors.teal,
        ),
        const PopupMenuDivider(),
        if (hasAddress) ...[
          _menuItem(
            value: 'favorite',
            icon: isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
            label: isFavorite
                ? 'Remover dos favoritos'
                : 'Adicionar aos favoritos',
            shortcut: 'Ctrl+D',
            iconColor: isFavorite ? Colors.amber : null,
          ),
          _menuItem(
            value: 'reading_list',
            icon: Icons.menu_book_rounded,
            label: 'Salvar para Ler Depois',
          ),
          _menuItem(
            value: 'qr_share',
            icon: Icons.qr_code_2_rounded,
            label: 'Compartilhar via QR Code',
          ),
          _menuItem(
            value: 'view_source',
            icon: Icons.code_rounded,
            label: 'Exibir código-fonte',
            shortcut: 'Ctrl+U',
          ),
          const PopupMenuDivider(),
          _menuItem(
            value: 'shield',
            icon: Icons.shield_rounded,
            label: 'Escudo AdBlock & Anti-Rastreio (${tab.totalBlockedCount})',
            iconColor: Colors.green.shade700,
          ),
          _menuItem(
            value: 'reader_mode',
            icon: Icons.chrome_reader_mode_rounded,
            label: 'Modo Leitura Limpa',
            shortcut: 'Alt+R',
            iconColor: Colors.teal,
          ),
          _menuItem(
            value: 'site_notes',
            icon: Icons.note_alt_outlined,
            label: 'Anotações deste Site',
            iconColor: Colors.amber,
          ),
          _menuItem(
            value: 'mute_tab',
            icon: tab.isMuted
                ? Icons.volume_up_rounded
                : Icons.volume_off_rounded,
            label: tab.isMuted ? 'Desativar Mudo da Aba' : 'Silenciar Aba',
          ),
        ],
        _menuItem(
          value: 'find',
          icon: Icons.search_rounded,
          label: 'Localizar na página',
          shortcut: 'Ctrl+F',
          enabled: hasAddress,
        ),
        _menuItem(
          value: 'extensions',
          icon: Icons.extension_rounded,
          label: 'Extensões Web',
          iconColor: const Color(0xFF2563EB),
        ),
        const PopupMenuDivider(),
        _menuItem(
          value: 'split_screen',
          icon: browser.splitScreenNotifier.value
              ? Icons.fullscreen_rounded
              : Icons.vertical_split_rounded,
          label: browser.splitScreenNotifier.value
              ? 'Fechar Tela Dividida'
              : 'Tela Dividida (Split Screen)',
        ),
        _menuItem(
          value: 'fullscreen',
          icon: browser.fullScreenNotifier.value
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          label: browser.fullScreenNotifier.value
              ? 'Sair da Tela Cheia'
              : 'Tela Cheia',
          shortcut: 'F11',
        ),
        _menuItem(
          value: 'settings',
          icon: Icons.settings_outlined,
          label: 'Configurações',
        ),
      ],
    );

    if (selected == null ||
        !context.mounted ||
        !identical(browser.current, tab) ||
        tab.address != sourceAddress) {
      return;
    }

    switch (selected) {
      case 'back':
        browser.goBack();
      case 'forward':
        browser.goForward();
      case 'reload':
        browser.reload();
      case 'new_tab':
        browser.addTab();
      case 'new_incognito':
        browser.addIncognitoTab();
      case 'reopen_tab':
        browser.reopenTab();
      case 'command_palette':
        CommandPaletteDialog.show(
          context,
          browser: browser,
          onSubmit: onSubmit ?? (url) => browser.open(url),
        );
      case 'web_capture':
        WebCaptureDialog.show(context, browser);
      case 'translate':
        browser.translateCurrentPage();
      case 'paste_and_go':
        if (clipText != null) {
          if (onSubmit != null) {
            onSubmit(clipText);
          } else {
            browser.open(clipText);
          }
        }
      case 'favorite':
        await browser.toggleFavorite();
      case 'reading_list':
        if (tab.address != null) {
          await browser.addToReadingList(tab.address!, tab.displayTitle);
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Página adicionada à lista de leitura!'),
              ),
            );
          }
        }
      case 'qr_share':
        if (tab.address != null) {
          QrShareDialog.show(context, tab.address!);
        }
      case 'view_source':
        if (tab.address != null) {
          PageSourceViewer.show(context, browser);
        }
      case 'shield':
        ShieldDialog.show(context, browser: browser, tab: tab);
      case 'reader_mode':
        if (tab.address != null) {
          ReaderModeView.show(context, engine: tab.engine, url: tab.address!);
        }
      case 'site_notes':
        SiteNotesDialog.show(context, browser: browser, host: tab.host);
      case 'mute_tab':
        browser.toggleMuteCurrentTab();
      case 'extensions':
        Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => BrowserAddons(browser: browser)),
        );
      case 'find':
        browser.openFindInPage();
      case 'split_screen':
        browser.toggleSplitScreen();
      case 'fullscreen':
        browser.toggleFullScreen();
      case 'settings':
        Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => BrowserSettings(browser: browser)),
        );
    }
  }

  // -------------------------------------------------------------
  // 3. MENU DE CONTEXTO DA BARRA DE ABAS
  // -------------------------------------------------------------
  static Future<void> showTabBarContextMenu(
    BuildContext context, {
    required Offset position,
    required BrowserController browser,
    bool isTouch = false,
  }) async {
    final isMobile = _isMobileDevice(context, isTouch);

    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_rounded),
                title: const BrowserText('Nova aba'),
                onTap: () {
                  Navigator.pop(ctx);
                  browser.addTab();
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_off_rounded,
                  color: Colors.purple,
                ),
                title: const BrowserText('Nova Guia Anônima'),
                onTap: () {
                  Navigator.pop(ctx);
                  browser.addIncognitoTab();
                },
              ),
              if (browser.canReopenTab)
                ListTile(
                  leading: const Icon(Icons.restore_page_rounded),
                  title: const BrowserText('Reabrir aba fechada'),
                  onTap: () {
                    Navigator.pop(ctx);
                    browser.reopenTab();
                  },
                ),
              ListTile(
                leading: const Icon(Icons.download_rounded),
                title: const Text('Downloads'),
                onTap: () {
                  Navigator.pop(ctx);
                  LibraryModal.show(context, browser: browser, initialIndex: 3);
                },
              ),
              ListTile(
                leading: const Icon(Icons.terminal_rounded, color: Colors.blue),
                title: const Text('Paleta de Comandos'),
                onTap: () {
                  Navigator.pop(ctx);
                  CommandPaletteDialog.show(
                    context,
                    browser: browser,
                    onSubmit: (url) => browser.open(url),
                  );
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.camera_alt_rounded,
                  color: Colors.deepOrange,
                ),
                title: const Text('Captura de Tela da Página'),
                onTap: () {
                  Navigator.pop(ctx);
                  WebCaptureDialog.show(context, browser);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.translate_rounded,
                  color: Colors.teal,
                ),
                title: const BrowserText('Traduzir Página para Português'),
                onTap: () {
                  Navigator.pop(ctx);
                  browser.translateCurrentPage();
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        _menuItem(
          value: 'new_tab',
          icon: Icons.add_rounded,
          label: 'Nova aba',
          shortcut: 'Ctrl+T',
        ),
        _menuItem(
          value: 'new_incognito',
          icon: Icons.visibility_off_rounded,
          label: 'Nova Guia Anônima',
          shortcut: 'Ctrl+Shift+N',
        ),
        if (browser.canReopenTab)
          _menuItem(
            value: 'reopen_tab',
            icon: Icons.restore_page_rounded,
            label: 'Reabrir aba fechada',
            shortcut: 'Ctrl+Shift+T',
          ),
        const PopupMenuDivider(),
        _menuItem(
          value: 'bookmark_tabs',
          icon: Icons.bookmarks_outlined,
          label: 'Favoritar todas as abas abertas',
        ),
        _menuItem(
          value: 'downloads',
          icon: Icons.download_rounded,
          label: 'Central de Downloads',
        ),
        const PopupMenuDivider(),
        _menuItem(
          value: 'command_palette',
          icon: Icons.terminal_rounded,
          label: 'Paleta de Comandos',
          shortcut: 'Ctrl+K',
        ),
        _menuItem(
          value: 'web_capture',
          icon: Icons.camera_alt_rounded,
          label: 'Captura de tela da página',
          shortcut: 'Ctrl+Shift+S',
        ),
        _menuItem(
          value: 'translate',
          icon: Icons.translate_rounded,
          label: 'Traduzir para Português',
        ),
        const PopupMenuDivider(),
        _menuItem(
          value: 'tab_layout',
          icon: browser.verticalTabs
              ? Icons.view_headline_rounded
              : Icons.view_sidebar_rounded,
          label: browser.verticalTabs
              ? 'Posicionar abas no topo'
              : 'Posicionar abas na lateral',
        ),
        if (browser.tabs.length > 1)
          _menuItem(
            value: 'split_screen',
            icon: browser.splitScreenNotifier.value
                ? Icons.fullscreen_rounded
                : Icons.vertical_split_rounded,
            label: browser.splitScreenNotifier.value
                ? 'Fechar Tela Dividida'
                : 'Dividir tela (duas abas)',
          ),
        _menuItem(
          value: 'fullscreen',
          icon: browser.fullScreenNotifier.value
              ? Icons.fullscreen_exit_rounded
              : Icons.fullscreen_rounded,
          label: browser.fullScreenNotifier.value
              ? 'Sair da Tela Cheia'
              : 'Tela Cheia',
          shortcut: 'F11',
        ),
        _menuItem(
          value: 'settings',
          icon: Icons.settings_outlined,
          label: 'Configurações',
        ),
      ],
    );

    if (selected == null || !context.mounted) return;

    switch (selected) {
      case 'new_tab':
        browser.addTab();
      case 'new_incognito':
        browser.addIncognitoTab();
      case 'reopen_tab':
        browser.reopenTab();
      case 'command_palette':
        CommandPaletteDialog.show(
          context,
          browser: browser,
          onSubmit: (url) => browser.open(url),
        );
      case 'web_capture':
        WebCaptureDialog.show(context, browser);
      case 'translate':
        browser.translateCurrentPage();
      case 'bookmark_tabs':
        final count = await browser.bookmarkOpenTabs();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                count == 0
                    ? 'Nenhuma aba nova para favoritar.'
                    : '$count abas salvas nos favoritos.',
              ),
            ),
          );
        }
      case 'downloads':
        LibraryModal.show(context, browser: browser, initialIndex: 3);
      case 'tab_layout':
        browser.setVerticalTabs(!browser.verticalTabs);
      case 'split_screen':
        browser.toggleSplitScreen();
      case 'fullscreen':
        browser.toggleFullScreen();
      case 'settings':
        Navigator.of(context).push<void>(
          MaterialPageRoute(builder: (_) => BrowserSettings(browser: browser)),
        );
    }
  }

  // -------------------------------------------------------------
  // 4. MENU DE CONTEXTO PARA CARTÕES DE SITES (ACESSO RÁPIDO)
  // -------------------------------------------------------------
  static Future<void> showSiteCardContextMenu(
    BuildContext context, {
    required String url,
    required Offset position,
    required BrowserController browser,
    bool isTouch = false,
  }) async {
    final isFavorite = browser.data.favorites.contains(url);
    final isMobile = _isMobileDevice(context, isTouch);

    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.remove_red_eye_rounded),
                title: const Text('Espiar página (Sneak & Peek)'),
                onTap: () {
                  Navigator.pop(ctx);
                  SneakPeekDialog.show(context, url: url, browser: browser);
                },
              ),
              ListTile(
                leading: const Icon(Icons.open_in_new_rounded),
                title: const Text('Abrir em nova aba'),
                onTap: () {
                  Navigator.pop(ctx);
                  browser.addTab(address: url);
                },
              ),
              ListTile(
                leading: const Icon(
                  Icons.visibility_off_rounded,
                  color: Colors.purple,
                ),
                title: const Text('Abrir em Guia Anônima'),
                onTap: () {
                  Navigator.pop(ctx);
                  browser.addIncognitoTab(address: url);
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_rounded),
                title: const Text('Copiar link'),
                onTap: () {
                  Navigator.pop(ctx);
                  Clipboard.setData(ClipboardData(text: url));
                },
              ),
              ListTile(
                leading: Icon(
                  isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
                ),
                title: Text(
                  isFavorite
                      ? 'Remover do acesso rápido'
                      : 'Fixar no acesso rápido',
                ),
                onTap: () {
                  Navigator.pop(ctx);
                  browser.removeEntry(url, history: false);
                },
              ),
            ],
          ),
        ),
      );
      return;
    }

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        _menuItem(
          value: 'sneak_peek',
          icon: Icons.remove_red_eye_rounded,
          label: 'Espiar página (Sneak & Peek)',
          shortcut: 'Alt+Clique',
        ),
        const PopupMenuDivider(),
        _menuItem(
          value: 'open',
          icon: Icons.launch_rounded,
          label: 'Abrir nesta aba',
        ),
        _menuItem(
          value: 'open_new_tab',
          icon: Icons.tab_rounded,
          label: 'Abrir em nova aba',
        ),
        _menuItem(
          value: 'open_incognito',
          icon: Icons.visibility_off_rounded,
          label: 'Abrir em Guia Anônima',
        ),
        const PopupMenuDivider(),
        _menuItem(
          value: 'copy_url',
          icon: Icons.copy_rounded,
          label: 'Copiar link',
        ),
        _menuItem(
          value: 'qr_share',
          icon: Icons.qr_code_2_rounded,
          label: 'Compartilhar via QR Code',
        ),
        const PopupMenuDivider(),
        _menuItem(
          value: 'toggle_favorite',
          icon: isFavorite ? Icons.star_rounded : Icons.star_outline_rounded,
          label: isFavorite
              ? 'Remover do acesso rápido'
              : 'Fixar no acesso rápido',
          iconColor: isFavorite ? Colors.amber : null,
        ),
      ],
    );

    if (selected == null || !context.mounted) return;

    switch (selected) {
      case 'sneak_peek':
        SneakPeekDialog.show(context, url: url, browser: browser);
      case 'open':
        browser.open(url);
      case 'open_new_tab':
        browser.addTab(address: url);
      case 'open_incognito':
        browser.addIncognitoTab(address: url);
      case 'copy_url':
        await Clipboard.setData(ClipboardData(text: url));
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Link copiado para a área de transferência!'),
            ),
          );
        }
      case 'qr_share':
        QrShareDialog.show(context, url);
      case 'toggle_favorite':
        browser.removeEntry(url, history: false);
    }
  }

  // -------------------------------------------------------------
  // 5. MENU DE CONTEXTO DA BARRA DE ENDEREÇOS (OMNIBOX)
  // -------------------------------------------------------------
  static Future<void> showOmniboxContextMenu(
    BuildContext context, {
    required Offset position,
    required TextEditingController controller,
    required BrowserController browser,
    required ValueChanged<String> onSubmit,
  }) async {
    final hasSelection =
        controller.selection.isValid &&
        controller.selection.start != controller.selection.end;
    final hasText = controller.text.isNotEmpty;

    ClipboardData? clipData;
    try {
      clipData = await Clipboard.getData(Clipboard.kTextPlain);
    } catch (_) {}
    final clipText = clipData?.text?.trim();
    final hasClipboard = clipText != null && clipText.isNotEmpty;

    if (!context.mounted) return;

    final selected = await showMenu<String>(
      context: context,
      position: RelativeRect.fromLTRB(
        position.dx,
        position.dy,
        position.dx,
        position.dy,
      ),
      elevation: 6,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      items: [
        if (hasSelection)
          _menuItem(
            value: 'cut',
            icon: Icons.content_cut_rounded,
            label: 'Recortar',
            shortcut: 'Ctrl+X',
          ),
        _menuItem(
          value: 'copy',
          icon: Icons.copy_rounded,
          label: 'Copiar',
          shortcut: 'Ctrl+C',
          enabled: hasText,
        ),
        _menuItem(
          value: 'paste',
          icon: Icons.content_paste_rounded,
          label: 'Colar',
          shortcut: 'Ctrl+V',
          enabled: hasClipboard,
        ),
        if (hasClipboard)
          _menuItem(
            value: 'paste_and_go',
            icon: Icons.search_rounded,
            label: 'Colar e pesquisar',
            iconColor: const Color(0xFF2563EB),
          ),
        const PopupMenuDivider(),
        _menuItem(
          value: 'select_all',
          icon: Icons.select_all_rounded,
          label: 'Selecionar tudo',
          shortcut: 'Ctrl+A',
          enabled: hasText,
        ),
      ],
    );

    if (selected == null || !context.mounted) return;

    switch (selected) {
      case 'cut':
        if (hasSelection) {
          final selText = controller.text.substring(
            controller.selection.start,
            controller.selection.end,
          );
          await Clipboard.setData(ClipboardData(text: selText));
          final newText = controller.text.replaceRange(
            controller.selection.start,
            controller.selection.end,
            '',
          );
          controller.text = newText;
        }
      case 'copy':
        final textToCopy = hasSelection
            ? controller.text.substring(
                controller.selection.start,
                controller.selection.end,
              )
            : controller.text;
        await Clipboard.setData(ClipboardData(text: textToCopy));
      case 'paste':
        if (clipText != null) {
          if (hasSelection) {
            controller.text = controller.text.replaceRange(
              controller.selection.start,
              controller.selection.end,
              clipText,
            );
          } else {
            controller.text = clipText;
          }
        }
      case 'paste_and_go':
        if (clipText != null) {
          controller.text = clipText;
          onSubmit(clipText);
        }
      case 'select_all':
        controller.selection = TextSelection(
          baseOffset: 0,
          extentOffset: controller.text.length,
        );
    }
  }
}
