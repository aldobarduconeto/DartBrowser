import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';
import '../browser_settings.dart';
import '../chrome_extensions_view.dart';
import 'library_modal.dart';
import 'page_source_viewer.dart';
import 'qr_share_dialog.dart';
import 'reader_mode_view.dart';
import 'shield_dialog.dart';
import 'web_capture_dialog.dart';

class PaletteItem {
  const PaletteItem({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.category,
    required this.onSelect,
    this.shortcut,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final String category;
  final VoidCallback onSelect;
  final String? shortcut;
}

class CommandPaletteDialog extends StatefulWidget {
  const CommandPaletteDialog({
    super.key,
    required this.browser,
    required this.onSubmit,
  });

  final BrowserController browser;
  final ValueChanged<String> onSubmit;

  static Future<void> show(
    BuildContext context, {
    required BrowserController browser,
    required ValueChanged<String> onSubmit,
  }) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => CommandPaletteDialog(
        browser: browser,
        onSubmit: onSubmit,
      ),
    );
  }

  @override
  State<CommandPaletteDialog> createState() => _CommandPaletteDialogState();
}

class _CommandPaletteDialogState extends State<CommandPaletteDialog> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _searchController.addListener(() {
      setState(() => _selectedIndex = 0);
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  List<PaletteItem> _getAllItems() {
    final browser = widget.browser;
    final currentTab = browser.current;
    final items = <PaletteItem>[];

    // 1. Ações Principais
    items.addAll([
      PaletteItem(
        title: 'Nova Aba',
        subtitle: 'Abrir uma nova página de navegação',
        icon: Icons.add_rounded,
        category: 'Ações',
        shortcut: 'Ctrl+T',
        onSelect: () => browser.addTab(),
      ),
      PaletteItem(
        title: 'Nova Guia Anônima',
        subtitle: 'Navegar sem salvar histórico ou cookies',
        icon: Icons.visibility_off_rounded,
        category: 'Ações',
        shortcut: 'Ctrl+Shift+N',
        onSelect: () => browser.addIncognitoTab(),
      ),
      PaletteItem(
        title: 'Captura de Tela da Web',
        subtitle: 'Capturar página visível e copiar ou salvar em PNG',
        icon: Icons.camera_alt_rounded,
        category: 'Ações',
        shortcut: 'Ctrl+Shift+S',
        onSelect: () => WebCaptureDialog.show(context, browser),
      ),
      PaletteItem(
        title: 'Dividir Tela (Split Screen)',
        subtitle: 'Exibir duas abas lado a lado simultaneamente',
        icon: Icons.vertical_split_rounded,
        category: 'Ações',
        onSelect: () => browser.toggleSplitScreen(),
      ),
      PaletteItem(
        title: 'Modo Leitura Sem Distrações',
        subtitle: 'Remover anúncios e focar apenas no texto do artigo',
        icon: Icons.chrome_reader_mode_rounded,
        category: 'Ações',
        onSelect: () {
          if (currentTab.address != null) {
            ReaderModeView.show(
              context,
              engine: currentTab.engine,
              url: currentTab.address!,
            );
          }
        },
      ),
      PaletteItem(
        title: 'Localizar na Página',
        subtitle: 'Buscar palavras ou termos no site atual',
        icon: Icons.search_rounded,
        category: 'Ações',
        shortcut: 'Ctrl+F',
        onSelect: () => browser.openFindInPage(),
      ),
      PaletteItem(
        title: 'Escudo AdBlock & Anti-Rastreio',
        subtitle:
            'Gerenciar bloqueador de anúncios e proteção contra rastreadores',
        icon: Icons.shield_rounded,
        category: 'Ações',
        onSelect: () =>
            ShieldDialog.show(context, browser: browser, tab: currentTab),
      ),
      PaletteItem(
        title: 'Histórico de Navegação',
        subtitle: 'Ver sites acessados anteriormente',
        icon: Icons.history_rounded,
        category: 'Ações',
        shortcut: 'Ctrl+H',
        onSelect: () =>
            LibraryModal.show(context, browser: browser, initialIndex: 1),
      ),
      PaletteItem(
        title: 'Favoritos',
        subtitle: 'Acessar seus links e páginas salvas',
        icon: Icons.star_rounded,
        category: 'Ações',
        onSelect: () =>
            LibraryModal.show(context, browser: browser, initialIndex: 0),
      ),
      PaletteItem(
        title: 'Lista de Leitura (Ler Depois)',
        subtitle: 'Artigos salvos para leitura posterior',
        icon: Icons.menu_book_rounded,
        category: 'Ações',
        onSelect: () =>
            LibraryModal.show(context, browser: browser, initialIndex: 2),
      ),
      PaletteItem(
        title: 'Downloads',
        subtitle: 'Ver arquivos baixados pelo navegador',
        icon: Icons.download_rounded,
        category: 'Ações',
        onSelect: () =>
            LibraryModal.show(context, browser: browser, initialIndex: 3),
      ),
      PaletteItem(
        title: 'Compartilhar via QR Code',
        subtitle: 'Escanear link da página no celular',
        icon: Icons.qr_code_2_rounded,
        category: 'Ações',
        onSelect: () {
          if (currentTab.address != null) {
            QrShareDialog.show(context, currentTab.address!);
          }
        },
      ),
      PaletteItem(
        title: 'Extensões Web',
        subtitle: 'Gerenciar e adicionar scripts e extensões',
        icon: Icons.extension_rounded,
        category: 'Ações',
        onSelect: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute(builder: (_) => BrowserAddons(browser: browser)),
          );
        },
      ),
      PaletteItem(
        title: 'Configurações',
        subtitle: 'Mecanismo de busca, aparência e privacidade',
        icon: Icons.settings_rounded,
        category: 'Ações',
        onSelect: () {
          Navigator.of(context).push<void>(
            MaterialPageRoute(
              builder: (_) => BrowserSettings(browser: browser),
            ),
          );
        },
      ),
      PaletteItem(
        title: 'Alternar Tema Claro / Escuro',
        subtitle: 'Mudar tema visual da interface',
        icon: Icons.dark_mode_rounded,
        category: 'Ações',
        onSelect: () {
          final isDark = Theme.of(context).brightness == Brightness.dark;
          browser.setTheme(isDark ? ThemeMode.light : ThemeMode.dark);
        },
      ),
      PaletteItem(
        title: 'Alternar Tela Cheia',
        subtitle: 'Expandir navegador para o monitor inteiro',
        icon: Icons.fullscreen_rounded,
        category: 'Ações',
        shortcut: 'F11',
        onSelect: () => browser.toggleFullScreen(),
      ),
      PaletteItem(
        title: 'Código-Fonte da Página',
        subtitle: 'Inspecionar o HTML da página atual',
        icon: Icons.code_rounded,
        category: 'Ações',
        shortcut: 'Ctrl+U',
        onSelect: () => PageSourceViewer.show(context, browser),
      ),
    ]);

    // 2. Abas Abertas
    for (int i = 0; i < browser.tabs.length; i++) {
      final tab = browser.tabs[i];
      final isCurrent = tab == currentTab;
      items.add(
        PaletteItem(
          title: tab.displayTitle,
          subtitle: tab.address ?? 'Nova aba em branco',
          icon: isCurrent ? Icons.tab_rounded : Icons.tab_unselected_rounded,
          category: 'Abas Abertas',
          shortcut: isCurrent ? 'Aba Atual' : null,
          onSelect: () => browser.select(i),
        ),
      );
    }

    // 3. Favoritos Salvos
    for (final fav in browser.data.favorites) {
      items.add(
        PaletteItem(
          title: Uri.tryParse(fav)?.host ?? fav,
          subtitle: fav,
          icon: Icons.star_outline_rounded,
          category: 'Favoritos',
          onSelect: () => widget.onSubmit(fav),
        ),
      );
    }

    // 4. Histórico Recente (últimos 15)
    final recentHistory = browser.data.history.take(15);
    for (final h in recentHistory) {
      items.add(
        PaletteItem(
          title: Uri.tryParse(h)?.host ?? h,
          subtitle: h,
          icon: Icons.history_rounded,
          category: 'Histórico Recente',
          onSelect: () => widget.onSubmit(h),
        ),
      );
    }

    return items;
  }

  List<PaletteItem> _filterItems(List<PaletteItem> all) {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      return all;
    }

    return all.where((item) {
      final matchTitle = item.title.toLowerCase().contains(query);
      final matchSub = item.subtitle.toLowerCase().contains(query);
      final matchCat = item.category.toLowerCase().contains(query);
      return matchTitle || matchSub || matchCat;
    }).toList();
  }

  void _handleSelect(PaletteItem item) {
    Navigator.of(context).pop();
    item.onSelect();
  }

  void _handleWebSearch(String query) {
    Navigator.of(context).pop();
    widget.onSubmit(query);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final allItems = _getAllItems();
    final filtered = _filterItems(allItems);

    return Dialog(
      alignment: Alignment.topCenter,
      insetPadding: const EdgeInsets.only(top: 80, left: 24, right: 24),
      backgroundColor: Colors.transparent,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 620, maxHeight: 480),
        child: Container(
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: colors.primary.withValues(alpha: 0.35),
              width: 1.2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.35),
                blurRadius: 24,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de Pesquisa da Paleta
              Padding(
                padding: const EdgeInsets.all(12),
                child: Row(
                  children: [
                    Icon(Icons.search_rounded, color: colors.primary, size: 22),
                    const SizedBox(width: 10),
                    Expanded(
                      child: TextField(
                        controller: _searchController,
                        focusNode: _focusNode,
                        autofocus: true,
                        style: const TextStyle(fontSize: 14.5),
                        decoration: InputDecoration(
                          hintText: 'Digite um comando, pesquise abas, histórico ou URLs...',
                          hintStyle: TextStyle(
                            fontSize: 13.5,
                            color: colors.onSurfaceVariant.withValues(
                              alpha: 0.6,
                            ),
                          ),
                          border: InputBorder.none,
                          isDense: true,
                        ),
                        onSubmitted: (val) {
                          if (filtered.isNotEmpty) {
                            final idx = _selectedIndex.clamp(
                              0,
                              filtered.length - 1,
                            );
                            _handleSelect(filtered[idx]);
                          } else if (val.trim().isNotEmpty) {
                            _handleWebSearch(val.trim());
                          }
                        },
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                          color: colors.outlineVariant.withValues(alpha: 0.5),
                        ),
                      ),
                      child: Text(
                        'ESC',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),

              // Lista de Resultados
              Expanded(
                child: filtered.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.travel_explore_rounded,
                                size: 36,
                                color: colors.primary,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'Pesquisar na Web por "${_searchController.text.trim()}"',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 12),
                              FilledButton.tonalIcon(
                                icon: const Icon(
                                  Icons.arrow_forward_rounded,
                                  size: 16,
                                ),
                                label: const Text('Pesquisar no Google'),
                                onPressed: () => _handleWebSearch(
                                  _searchController.text.trim(),
                                ),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        itemCount: filtered.length,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemBuilder: (context, index) {
                          final item = filtered[index];
                          final isSelected = index == _selectedIndex;

                          return InkWell(
                            onTap: () => _handleSelect(item),
                            onHover: (hovered) {
                              if (hovered && _selectedIndex != index) {
                                setState(() => _selectedIndex = index);
                              }
                            },
                            child: Container(
                              margin: const EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 2,
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 8,
                              ),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? colors.primary.withValues(alpha: 0.15)
                                    : Colors.transparent,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Row(
                                children: [
                                  Icon(
                                    item.icon,
                                    size: 18,
                                    color: isSelected
                                        ? colors.primary
                                        : colors.onSurfaceVariant,
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          item.title,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 13,
                                            fontWeight: isSelected
                                                ? FontWeight.w600
                                                : FontWeight.normal,
                                          ),
                                        ),
                                        Text(
                                          item.subtitle,
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 11,
                                            color: colors.onSurfaceVariant
                                                .withValues(alpha: 0.75),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  if (item.shortcut != null)
                                    Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 6,
                                        vertical: 2,
                                      ),
                                      decoration: BoxDecoration(
                                        color: colors.surfaceContainerLow,
                                        borderRadius: BorderRadius.circular(4),
                                        border: Border.all(
                                          color: colors.outlineVariant
                                              .withValues(alpha: 0.35),
                                        ),
                                      ),
                                      child: Text(
                                        item.shortcut!,
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: colors.onSurfaceVariant,
                                        ),
                                      ),
                                    )
                                  else
                                    Text(
                                      item.category,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        color: colors.onSurfaceVariant
                                            .withValues(alpha: 0.6),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              ),

              // Rodapé de atalhos da paleta
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: colors.surfaceContainerLow.withValues(alpha: 0.5),
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(16),
                  ),
                ),
                child: Row(
                  children: [
                    Text(
                      '↑↓ para navegar',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '↵ para selecionar',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${filtered.length} resultados',
                      style: TextStyle(
                        fontSize: 11,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
