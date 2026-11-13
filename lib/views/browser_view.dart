import '../l10n/browser_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_all/webview_all.dart';

import '../controllers/browser_controller.dart';
import '../models/chrome_extension.dart';
import '../models/tab_group.dart';
import '../services/window_service.dart';
import 'browser_settings.dart';
import 'browser_tabs.dart';
import 'chrome_extensions_view.dart';
import 'components/browser_context_menu.dart';
import 'components/find_in_page_bar.dart';
import 'components/library_modal.dart';
import 'components/omnibox_bar.dart';
import 'components/page_source_viewer.dart';
import 'components/start_page.dart';
import 'components/window_caption_controls.dart';
import 'components/command_palette_dialog.dart';
import 'components/web_capture_dialog.dart';
import 'components/read_aloud_bar.dart';
import 'components/browser_tools_dock.dart';
import 'components/browser_bottom_bar.dart';

class BrowserView extends StatefulWidget {
  const BrowserView({super.key, required this.browser, this.isTv = false});

  final BrowserController browser;
  final bool isTv;

  @override
  State<BrowserView> createState() => _BrowserViewState();
}

class _BrowserViewState extends State<BrowserView> with WidgetsBindingObserver {
  final address = TextEditingController();
  final addressFocus = FocusNode();
  bool _linkMenuOpen = false;
  final _viewportKey = GlobalKey();

  BrowserController get browser => widget.browser;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    browser.addListener(syncAddress);
    addressFocus.addListener(syncAddress);
    browser.linkContextNotifier.addListener(_onLinkContext);
    syncAddress();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (browser.data.autoPiPEnabled && browser.tabs.isNotEmpty) {
      // Ativa PiP apenas quando a janela/tela for realmente minimizada ou suspensa (não ao passar o mouse ou focar controles)
      if (state == AppLifecycleState.paused ||
          state == AppLifecycleState.hidden) {
        browser.enterAndroidPictureInPicture();
        browser.togglePictureInPicture();
      } else if (state == AppLifecycleState.resumed) {
        browser.exitPictureInPicture();
      }
    }
  }

  Future<void> _onLinkContext() async {
    final event = browser.linkContextNotifier.value;
    if (event == null || !mounted) return;
    browser.linkContextNotifier.value = null;

    if (_linkMenuOpen || ModalRoute.of(context)?.isCurrent != true) return;
    _linkMenuOpen = true;
    try {
      final box = _viewportKey.currentContext?.findRenderObject();
      if (box is! RenderBox ||
          !box.hasSize ||
          !(Offset.zero & box.size).contains(event.position)) {
        return;
      }
      final position = box.localToGlobal(event.position);
      if (event.url case final url?) {
        await DartBrowserContextMenu.showLinkContextMenu(
          context,
          url: url,
          linkText: event.text,
          position: position,
          isTouch: event.isTouch,
          browser: browser,
          onSubmit: submit,
        );
      } else {
        await DartBrowserContextMenu.showPageContextMenu(
          context,
          position: position,
          browser: browser,
          onSubmit: submit,
        );
      }
    } finally {
      _linkMenuOpen = false;
    }
  }

  void syncAddress() {
    if (addressFocus.hasFocus) return;
    final value = browser.current.address ?? '';
    if (address.text != value) address.text = value;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    browser.linkContextNotifier.removeListener(_onLinkContext);
    browser.removeListener(syncAddress);
    addressFocus.dispose();
    address.dispose();
    super.dispose();
  }

  void submit(String value) {
    addressFocus.unfocus();
    browser.open(value);
    syncAddress();
  }

  void newTab(TabGroup? group) {
    addressFocus.unfocus();
    browser.addTab(group: group);
    addressFocus.requestFocus();
  }

  void selectTab(int index) {
    addressFocus.unfocus();
    browser.select(index);
  }

  Future<void> editGroup(BrowserTab? tab, TabGroup? group) async {
    const palette = [
      Color(0xFF00897B),
      Color(0xFF1E88E5),
      Color(0xFF8E24AA),
      Color(0xFFD81B60),
      Color(0xFFEF6C00),
      Color(0xFF689F38),
    ];
    var name = group?.name ?? '';
    var color = group?.color ?? palette.first.toARGB32();
    final result = await showDialog<({String name, int color})>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) => AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          title: Text(group == null ? 'Criar grupo' : 'Editar grupo'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              TextFormField(
                autofocus: true,
                initialValue: name,
                maxLength: 40,
                decoration: InputDecoration(
                  labelText: 'Nome do grupo',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: (value) => update(() => name = value),
                onFieldSubmitted: (_) {
                  if (name.trim().isNotEmpty) {
                    Navigator.pop(context, (name: name.trim(), color: color));
                  }
                },
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                children: [
                  for (final (index, option) in palette.indexed)
                    ChoiceChip(
                      tooltip: const [
                        'Verde-petróleo',
                        'Azul',
                        'Roxo',
                        'Rosa',
                        'Laranja',
                        'Verde',
                      ][index],
                      showCheckmark: false,
                      label: Icon(
                        option.toARGB32() == color
                            ? Icons.check_circle_rounded
                            : Icons.circle,
                        color: option,
                        size: 20,
                      ),
                      selected: option.toARGB32() == color,
                      onSelected: (_) =>
                          update(() => color = option.toARGB32()),
                    ),
                ],
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const BrowserText('Cancelar'),
            ),
            FilledButton(
              onPressed: name.trim().isEmpty
                  ? null
                  : () => Navigator.pop(context, (
                      name: name.trim(),
                      color: color,
                    )),
              child: const BrowserText('Salvar'),
            ),
          ],
        ),
      ),
    );
    if (!mounted || result == null) return;
    if (group != null) {
      browser.editGroup(group, result.name, result.color);
    } else if (tab != null) {
      browser.createGroup(tab, result.name, result.color);
    }
  }

  Future<void> copyAddress() async {
    final url = browser.current.address;
    if (url == null) return;
    await Clipboard.setData(ClipboardData(text: url));
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Endereço copiado.')));
    }
  }

  void openExtensionPopup(BrowserAddon addon) {
    final html = addon.getPopupHtml();
    if (html == null || html.isEmpty) return;

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          final controller = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..loadHtmlString(html);

          return SafeArea(
            child: SizedBox(
              height: MediaQuery.sizeOf(ctx).height * 0.70,
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 6,
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.extension_rounded, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            addon.actionTitle ?? addon.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const Divider(height: 1),
                  Expanded(child: WebViewWidget(controller: controller)),
                ],
              ),
            ),
          );
        },
      );
      return;
    }

    showDialog<void>(
      context: context,
      builder: (context) {
        final controller = WebViewController()
          ..setJavaScriptMode(JavaScriptMode.unrestricted)
          ..loadHtmlString(html);

        return Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 360,
            height: 480,
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  color: Theme.of(context).colorScheme.surfaceContainerHigh,
                  child: Row(
                    children: [
                      const Icon(Icons.extension_rounded, size: 20),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          addon.actionTitle ?? addon.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close_rounded, size: 18),
                        onPressed: () => Navigator.pop(context),
                      ),
                    ],
                  ),
                ),
                Expanded(child: WebViewWidget(controller: controller)),
              ],
            ),
          ),
        );
      },
    );
  }

  void showExtensionsMenu() {
    final colors = Theme.of(context).colorScheme;
    final currentAddress = browser.current.address ?? '';
    final currentHost = Uri.tryParse(currentAddress)?.host ?? '';

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) => StatefulBuilder(
        builder: (context, setSheetState) => ListenableBuilder(
          listenable: browser,
          builder: (context, _) {
            final activeAddons = browser.activeAddonsForCurrentPage;
            final allAddons = browser.addons;

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 8,
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.extension_rounded,
                            color: colors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Extensões do Chrome',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              if (currentHost.isNotEmpty)
                                Text(
                                  'Nesta página: $currentHost',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: colors.onSurfaceVariant,
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    if (allAddons.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: Column(
                            children: [
                              Icon(
                                Icons.extension_off_rounded,
                                size: 36,
                                color: colors.onSurfaceVariant,
                              ),
                              const SizedBox(height: 8),
                              const Text('Nenhuma extensão instalada.'),
                            ],
                          ),
                        ),
                      )
                    else
                      Flexible(
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: allAddons.length,
                          separatorBuilder: (_, _) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final addon = allAddons[index];
                            final isActive = activeAddons.contains(addon);

                            return ListTile(
                              contentPadding: EdgeInsets.zero,
                              leading: Container(
                                width: 36,
                                height: 36,
                                decoration: BoxDecoration(
                                  color: addon.enabled
                                      ? colors.primary.withValues(alpha: 0.15)
                                      : colors.surfaceContainerHighest,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Center(
                                  child: Icon(
                                    addon.id.contains('dark')
                                        ? Icons.dark_mode_rounded
                                        : addon.id.contains('adblock')
                                        ? Icons.shield_rounded
                                        : addon.id.contains('markdown')
                                        ? Icons.text_snippet_rounded
                                        : Icons.extension_rounded,
                                    size: 20,
                                    color: addon.enabled
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              title: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      addon.name,
                                      style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  if (isActive)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.green.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: const Text(
                                        'Ativa',
                                        style: TextStyle(
                                          fontSize: 10,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.green,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                              subtitle: Text(
                                addon.description.isNotEmpty
                                    ? addon.description
                                    : 'Manifest V${addon.manifestVersion}',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(fontSize: 12),
                              ),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    tooltip: addon.isPinned
                                        ? 'Desafixar da barra de ferramentas'
                                        : 'Fixar na barra de ferramentas',
                                    icon: Icon(
                                      addon.isPinned
                                          ? Icons.push_pin_rounded
                                          : Icons.push_pin_outlined,
                                      size: 18,
                                      color: addon.isPinned
                                          ? colors.primary
                                          : colors.onSurfaceVariant,
                                    ),
                                    onPressed: () =>
                                        browser.togglePinAddon(addon),
                                  ),
                                  Switch(
                                    value: addon.enabled,
                                    onChanged: (_) =>
                                        browser.toggleAddon(addon),
                                  ),
                                ],
                              ),
                              onTap: () {
                                if (addon.hasPopup) {
                                  Navigator.pop(context);
                                  openExtensionPopup(addon);
                                }
                              },
                            );
                          },
                        ),
                      ),
                    const SizedBox(height: 12),
                    FilledButton.tonalIcon(
                      style: FilledButton.styleFrom(
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => BrowserAddons(browser: browser),
                          ),
                        );
                      },
                      icon: const Icon(
                        Icons.settings_suggest_rounded,
                        size: 18,
                      ),
                      label: const Text('Gerenciar extensões'),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> showSettings() => Navigator.of(context).push<void>(
    MaterialPageRoute(builder: (_) => BrowserSettings(browser: browser)),
  );

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: browser,
      builder: (context, _) {
        final tab = browser.current;
        final mobileLayout = !WindowService.isDesktop;
        final tabsWidget = BrowserTabs(
          browser: browser,
          vertical: browser.verticalTabs,
          compact: browser.verticalTabs && browser.compactTabs,
          onNewTab: newTab,
          onSelect: selectTab,
          onEditGroup: editGroup,
        );

        final command = Theme.of(context).platform == TargetPlatform.macOS;

        final isFullScreen = browser.fullScreenNotifier.value;

        return CallbackShortcuts(
          bindings: {
            // Ctrl+L: Focar na URL
            SingleActivator(
              LogicalKeyboardKey.keyL,
              meta: command,
              control: !command,
            ): () {
              addressFocus.requestFocus();
              address.selection = TextSelection(
                baseOffset: 0,
                extentOffset: address.text.length,
              );
            },
            SingleActivator(
              LogicalKeyboardKey.keyE,
              meta: command,
              control: !command,
            ): () {
              addressFocus.requestFocus();
              address.clear();
            },
            // Ctrl+T: Nova aba
            SingleActivator(
              LogicalKeyboardKey.keyT,
              meta: command,
              control: !command,
            ): () =>
                newTab(null),
            // Ctrl+Shift+T: Reabrir aba fechada
            SingleActivator(
              LogicalKeyboardKey.keyT,
              meta: command,
              control: !command,
              shift: true,
            ): browser.reopenTab,
            // Ctrl+W: Fechar aba atual
            SingleActivator(
              LogicalKeyboardKey.keyW,
              meta: command,
              control: !command,
            ): () =>
                browser.closeTab(browser.selected),
            // Ctrl+R ou F5: Recarregar
            SingleActivator(
              LogicalKeyboardKey.keyR,
              meta: command,
              control: !command,
            ): browser.reload,
            const SingleActivator(LogicalKeyboardKey.f5): browser.reload,
            // F11: Alternar Tela Cheia
            const SingleActivator(LogicalKeyboardKey.f11):
                browser.toggleFullScreen,
            // Ctrl+F: Localizar na página
            SingleActivator(
              LogicalKeyboardKey.keyF,
              meta: command,
              control: !command,
            ): browser.openFindInPage,
            // Ctrl+Shift+N: Nova guia anônima
            SingleActivator(
              LogicalKeyboardKey.keyN,
              meta: command,
              control: !command,
              shift: true,
            ): browser.addIncognitoTab,
            // Ctrl+D: Favoritar página atual
            SingleActivator(
              LogicalKeyboardKey.keyD,
              meta: command,
              control: !command,
            ): browser.toggleFavorite,
            // Ctrl+H: Histórico
            SingleActivator(
              LogicalKeyboardKey.keyH,
              meta: command,
              control: !command,
            ): () =>
                LibraryModal.show(context, browser: browser, initialIndex: 1),
            // Ctrl+U: Exibir código-fonte
            SingleActivator(
              LogicalKeyboardKey.keyU,
              meta: command,
              control: !command,
            ): () {
              if (tab.address != null) PageSourceViewer.show(context, browser);
            },
            // Ctrl+M: Silenciar aba atual
            SingleActivator(
              LogicalKeyboardKey.keyM,
              meta: command,
              control: !command,
            ): () =>
                browser.toggleMuteTab(tab),
            // Ctrl+Shift+P: Fixar/Desafixar aba
            SingleActivator(
              LogicalKeyboardKey.keyP,
              meta: command,
              control: !command,
              shift: true,
            ): () =>
                browser.togglePinTab(tab),
            // Zoom (+, -, 0)
            SingleActivator(
              LogicalKeyboardKey.equal,
              meta: command,
              control: !command,
            ): browser.zoomIn,
            SingleActivator(
              LogicalKeyboardKey.minus,
              meta: command,
              control: !command,
            ): browser.zoomOut,
            SingleActivator(
              LogicalKeyboardKey.digit0,
              meta: command,
              control: !command,
            ): browser.resetZoom,
            // Ctrl+K: Paleta de Comandos
            SingleActivator(
              LogicalKeyboardKey.keyK,
              meta: command,
              control: !command,
            ): () => CommandPaletteDialog.show(
              context,
              browser: browser,
              onSubmit: submit,
              onStartReadAloud: browser.startReadAloud,
            ),
            // Ctrl+Shift+S: Captura de Tela da Web
            SingleActivator(
              LogicalKeyboardKey.keyS,
              meta: command,
              control: !command,
              shift: true,
            ): () =>
                WebCaptureDialog.show(context, browser),
            // Ctrl+Shift+U: Leitura em Voz Alta
            SingleActivator(
              LogicalKeyboardKey.keyU,
              meta: command,
              control: !command,
              shift: true,
            ): () {
              if (browser.readAloudService.isActive) {
                browser.stopReadAloud();
              } else {
                browser.startReadAloud();
              }
            },
            // ESC: Fechar Localizar na Página
            const SingleActivator(LogicalKeyboardKey.escape): () {
              if (browser.isFindInPageVisible) browser.closeFindInPage();
            },
          },
          child: Focus(
            autofocus: true,
            child: Scaffold(
              body: SafeArea(
                bottom: !mobileLayout || isFullScreen,
                top: !WindowService.isDesktop,
                child: Row(
                  textDirection: browser.verticalTabs && browser.sidebarOnRight
                      ? TextDirection.rtl
                      : TextDirection.ltr,
                  children: [
                    // Dock lateral de ferramentas estilo Opera GX (no desktop em modo horizontal)
                    if (WindowService.isDesktop &&
                        !isFullScreen &&
                        browser.showToolsDock)
                      BrowserToolsDock(browser: browser, onSubmit: submit),

                    if (!mobileLayout && browser.verticalTabs && !isFullScreen)
                      SizedBox(
                        width: browser.compactTabs
                            ? 56
                            : (MediaQuery.sizeOf(context).width * .44).clamp(
                                140.0,
                                240.0,
                              ),
                        child: tabsWidget,
                      ),
                    Expanded(
                      key: const ValueKey('browserContent'),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          if (!mobileLayout &&
                              !browser.verticalTabs &&
                              !isFullScreen)
                            tabsWidget,

                          // Faixa de arraste e controles quando o modo de abas verticais está ativo no Desktop
                          if (browser.verticalTabs &&
                              !isFullScreen &&
                              WindowService.isDesktop)
                            Container(
                              height: 36,
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerLow.withValues(
                                  alpha: 0.5,
                                ),
                                border: Border(
                                  bottom: BorderSide(
                                    color: colors.outlineVariant.withValues(
                                      alpha: 0.25,
                                    ),
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Row(
                                children: [
                                  if (WindowService.isMacOS &&
                                      browser.sidebarOnRight)
                                    const SizedBox(width: 78),
                                  Expanded(
                                    child: GestureDetector(
                                      behavior: HitTestBehavior.translucent,
                                      onPanStart: (_) =>
                                          WindowService.startDragging(),
                                      onDoubleTap: () =>
                                          WindowService.maximize(),
                                      child: const SizedBox.expand(),
                                    ),
                                  ),
                                  if (!WindowService.isMacOS)
                                    const WindowCaptionControls(height: 36),
                                ],
                              ),
                            ),

                          // BARRA DE NAVEGAÇÃO E OMNIBOX MODULARIZADA
                          if (!mobileLayout && !isFullScreen)
                            OmniboxBar(
                              browser: browser,
                              addressController: address,
                              addressFocus: addressFocus,
                              onSubmit: submit,
                              onShowExtensionsMenu: showExtensionsMenu,
                              onOpenExtensionPopup: openExtensionPopup,
                            ),

                          // BARRA DE PROGRESSO DE ALTA PERFORMANCE (USANDO ValueListenableBuilder)
                          if (!isFullScreen)
                            ValueListenableBuilder<int>(
                              valueListenable:
                                  browser.activeTabProgressNotifier,
                              builder: (context, progress, _) {
                                if (progress >= 100 || tab.error != null) {
                                  return const SizedBox(height: 2.5);
                                }
                                return SizedBox(
                                  height: 2.5,
                                  child: LinearProgressIndicator(
                                    value: progress / 100,
                                    backgroundColor: Colors.transparent,
                                    valueColor: AlwaysStoppedAnimation<Color>(
                                      tab.isIncognito
                                          ? Colors.purple
                                          : colors.primary,
                                    ),
                                  ),
                                );
                              },
                            ),

                          // BARRA DE LOCALIZAR NA PÁGINA (FIND IN PAGE)
                          if (browser.isFindInPageVisible)
                            FindInPageBar(browser: browser),

                          // BARRA DE LEITURA EM VOZ ALTA (READ ALOUD)
                          ReadAloudBar(
                            service: browser.readAloudService,
                            onClose: browser.stopReadAloud,
                          ),

                          // BANNER DO CHROME WEB STORE
                          if (!isFullScreen &&
                              tab.address?.contains('chromewebstore.google.com/detail/') == true)
                            _buildWebStoreBanner(context, tab.address!),

                          // ÁREA DE CONTEÚDO DA PÁGINA (DESIGN FLOATING FRAMED CANVAS)
                          Expanded(
                            key: const ValueKey('pageViewport'),
                            child: Container(
                              margin: isFullScreen
                                  ? EdgeInsets.zero
                                  : const EdgeInsets.fromLTRB(4, 2, 4, 4),
                              decoration: BoxDecoration(
                                color: colors.surface,
                                borderRadius: isFullScreen
                                    ? BorderRadius.zero
                                    : BorderRadius.circular(10),
                                border: isFullScreen
                                    ? null
                                    : Border.all(
                                        color: colors.outlineVariant.withValues(
                                          alpha: 0.25,
                                        ),
                                        width: 1,
                                      ),
                              ),
                              clipBehavior: Clip.antiAlias,
                              child: Stack(
                                key: _viewportKey,
                                fit: StackFit.expand,
                                children: [
                                  LayoutBuilder(
                                    builder: (context, constraints) {
                                      final totalWidth = constraints.maxWidth;
                                      final isSplit =
                                          totalWidth >= 366 &&
                                          browser.splitScreenNotifier.value &&
                                          browser.secondaryTab != null;

                                      return ValueListenableBuilder<double>(
                                        valueListenable:
                                            browser.splitRatioNotifier,
                                        builder: (context, ratio, _) {
                                          final leftWidth = isSplit
                                              ? (totalWidth * ratio).clamp(
                                                  180.0,
                                                  totalWidth - 186.0,
                                                )
                                              : totalWidth;
                                          final rightWidth = isSplit
                                              ? totalWidth - leftWidth - 6.0
                                              : 0.0;

                                          return Row(
                                            children: [
                                              SizedBox(
                                                width: leftWidth,
                                                child: IndexedStack(
                                                  index: browser.selected,
                                                  sizing: StackFit.expand,
                                                  children: [
                                                    for (final item
                                                        in browser.tabs)
                                                      KeyedSubtree(
                                                        key: ObjectKey(item),
                                                        child:
                                                            item.address ==
                                                                    null ||
                                                                item.initialization ==
                                                                    null
                                                            ? StartPage(
                                                                browser:
                                                                    browser,
                                                                onSubmit:
                                                                    submit,
                                                                onShowSettings:
                                                                    showSettings,
                                                              )
                                                            : WebViewWidget(
                                                                controller:
                                                                    item.engine,
                                                              ),
                                                      ),
                                                  ],
                                                ),
                                              ),
                                              if (isSplit) ...[
                                                MouseRegion(
                                                  cursor: SystemMouseCursors
                                                      .resizeColumn,
                                                  child: GestureDetector(
                                                    behavior:
                                                        HitTestBehavior.opaque,
                                                    onHorizontalDragUpdate:
                                                        (details) {
                                                          final newRatio =
                                                              (leftWidth +
                                                                  details
                                                                      .delta
                                                                      .dx) /
                                                              totalWidth;
                                                          browser.setSplitRatio(
                                                            newRatio,
                                                          );
                                                        },
                                                    child: Container(
                                                      width: 6,
                                                      color: colors
                                                          .surfaceContainerHighest
                                                          .withValues(
                                                            alpha: 0.6,
                                                          ),
                                                      child: Center(
                                                        child: Container(
                                                          width: 2,
                                                          height: 32,
                                                          decoration: BoxDecoration(
                                                            color: colors
                                                                .outlineVariant,
                                                            borderRadius:
                                                                BorderRadius.circular(
                                                                  1,
                                                                ),
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                ),
                                                SizedBox(
                                                  width: rightWidth,
                                                  child: Stack(
                                                    children: [
                                                      Positioned.fill(
                                                        child:
                                                            browser
                                                                    .secondaryTab!
                                                                    .address ==
                                                                null
                                                            ? StartPage(
                                                                browser:
                                                                    browser,
                                                                onSubmit: browser
                                                                    .openInSecondaryTab,
                                                                onShowSettings:
                                                                    showSettings,
                                                              )
                                                            : WebViewWidget(
                                                                controller: browser
                                                                    .secondaryTab!
                                                                    .engine,
                                                              ),
                                                      ),
                                                      Positioned(
                                                        top: 8,
                                                        right: 8,
                                                        child: Material(
                                                          color: colors
                                                              .surfaceContainerHighest
                                                              .withValues(
                                                                alpha: 0.85,
                                                              ),
                                                          shape:
                                                              const CircleBorder(),
                                                          child: IconButton(
                                                            icon: const Icon(
                                                              Icons
                                                                  .close_rounded,
                                                              size: 18,
                                                            ),
                                                            tooltip: 'Fechar tela dividida',
                                                            onPressed: browser
                                                                .closeSplitScreen,
                                                          ),
                                                        ),
                                                      ),
                                                    ],
                                                  ),
                                                ),
                                              ],
                                            ],
                                          );
                                        },
                                      );
                                    },
                                  ),
                                  if (tab.error case final error?)
                                    ColoredBox(
                                      color: colors.surface,
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(
                                              Icons.error_outline_rounded,
                                              size: 48,
                                              color: colors.error,
                                            ),
                                            const SizedBox(height: 12),
                                            Text(
                                              error,
                                              style: const TextStyle(
                                                fontSize: 15,
                                              ),
                                            ),
                                            const SizedBox(height: 16),
                                            FilledButton.icon(
                                              onPressed: () =>
                                                  submit(tab.address!),
                                              icon: const Icon(
                                                Icons.refresh_rounded,
                                                size: 18,
                                              ),
                                              label: const Text(
                                                'Tentar novamente',
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  if (isFullScreen)
                                    Positioned(
                                      top: 12,
                                      right: 12,
                                      child: Material(
                                        color: Colors.black.withValues(
                                          alpha: 0.6,
                                        ),
                                        borderRadius: BorderRadius.circular(20),
                                        child: IconButton(
                                          icon: const Icon(
                                            Icons.fullscreen_exit_rounded,
                                            color: Colors.white,
                                          ),
                                          tooltip: 'Sair da tela cheia (F11)',
                                          onPressed: browser.toggleFullScreen,
                                        ),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          ),
                          if (mobileLayout && !isFullScreen)
                            BrowserBottomBar(
                              browser: browser,
                              isTv: widget.isTv,
                              address: address,
                              focus: addressFocus,
                              onSubmit: submit,
                              onShowExtensionsMenu: showExtensionsMenu,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildWebStoreBanner(BuildContext context, String address) {
    final match = RegExp(r'/detail/(?:[^/]+/)?([a-z]{32})').firstMatch(address);
    final extId = match?.group(1);
    if (extId == null) return const SizedBox.shrink();

    final isMobile = MediaQuery.sizeOf(context).width < 600;
    final colors = Theme.of(context).colorScheme;
    final isInstalled = browser.addons.any(
      (a) =>
          a.id.contains(extId) ||
          a.files.values.any((f) => f.contains(extId)),
    );

    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: isMobile ? 12 : 16,
        vertical: isMobile ? 6 : 8,
      ),
      decoration: BoxDecoration(
        color: isInstalled
            ? colors.surfaceContainerHigh
            : colors.primaryContainer.withValues(alpha: 0.95),
        border: Border(
          bottom: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: Row(
        children: [
          Icon(
            isInstalled ? Icons.check_circle_rounded : Icons.extension_rounded,
            size: isMobile ? 18 : 20,
            color: isInstalled ? Colors.green : colors.primary,
          ),
          SizedBox(width: isMobile ? 8 : 12),
          Expanded(
            child: Text(
              isInstalled
                  ? (isMobile
                      ? 'Extensão ativa.'
                      : 'Esta extensão está instalada e ativa no Dart Browser.')
                  : (isMobile
                      ? 'Extensão compatível!'
                      : 'Extensão compatível detectada! Clique para instalar diretamente.'),
              style: TextStyle(
                fontSize: isMobile ? 12 : 13,
                fontWeight: FontWeight.w600,
                color: isInstalled
                    ? colors.onSurface
                    : colors.onPrimaryContainer,
              ),
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(width: isMobile ? 8 : 12),
          if (!isInstalled)
            _WebStoreInstallButton(
              browser: browser,
              extensionId: extId,
              isMobile: isMobile,
            )
          else
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 8 : 12,
                  vertical: 4,
                ),
              ),
              onPressed: showExtensionsMenu,
              icon: const Icon(Icons.settings_suggest_rounded, size: 16),
              label: Text(isMobile ? 'Ver' : 'Gerenciar'),
            ),
        ],
      ),
    );
  }
}

class _WebStoreInstallButton extends StatefulWidget {
  const _WebStoreInstallButton({
    required this.browser,
    required this.extensionId,
    this.isMobile = false,
  });

  final BrowserController browser;
  final String extensionId;
  final bool isMobile;

  @override
  State<_WebStoreInstallButton> createState() => _WebStoreInstallButtonState();
}

class _WebStoreInstallButtonState extends State<_WebStoreInstallButton> {
  bool _installing = false;

  Future<void> _install() async {
    if (_installing) return;
    setState(() => _installing = true);
    try {
      final addon = await widget.browser.installExtensionFromWebStore(
        widget.extensionId,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Extensão "${addon?.name ?? 'Web'}" instalada e pronta para uso!',
            ),
            backgroundColor: Colors.green.shade800,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Não foi possível instalar a extensão: $e'),
            backgroundColor: Colors.red.shade800,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _installing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        visualDensity: VisualDensity.compact,
        padding: EdgeInsets.symmetric(
          horizontal: widget.isMobile ? 10 : 14,
          vertical: widget.isMobile ? 6 : 8,
        ),
      ),
      onPressed: _installing ? null : _install,
      icon: _installing
          ? const SizedBox(
              width: 14,
              height: 14,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.download_rounded, size: 16),
      label: Text(
        _installing
            ? 'Instalando...'
            : (widget.isMobile ? 'Instalar' : 'Instalar no Dart Browser'),
      ),
    );
  }
}
