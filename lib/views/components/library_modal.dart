import '../../l10n/browser_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/browser_controller.dart';
import '../../models/download_item.dart';

class LibraryModal extends StatefulWidget {
  const LibraryModal({super.key, required this.browser, this.initialIndex = 0});

  final BrowserController browser;
  final int initialIndex;

  static Future<String?> show(
    BuildContext context, {
    required BrowserController browser,
    int initialIndex = 0,
  }) {
    return showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) =>
          LibraryModal(browser: browser, initialIndex: initialIndex),
    );
  }

  @override
  State<LibraryModal> createState() => _LibraryModalState();
}

class _LibraryModalState extends State<LibraryModal>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _filter = '';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 4,
      vsync: this,
      initialIndex: widget.initialIndex.clamp(0, 3),
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _exportFavorites(BuildContext context) async {
    final html = widget.browser.exportBookmarksHtml();
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_download_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Exportar Favoritos (HTML)'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Os favoritos estão formatados no padrão HTML Netscape, compatível com outros navegadores:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              Container(
                height: 160,
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Theme.of(ctx).colorScheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    html,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const BrowserText('Fechar'),
          ),
          FilledButton.icon(
            icon: const Icon(Icons.copy_rounded, size: 18),
            label: const Text('Copiar HTML'),
            onPressed: () {
              Clipboard.setData(ClipboardData(text: html));
              Navigator.pop(ctx);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('HTML copiado para a área de transferência!'),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Future<void> _importFavorites(BuildContext context) async {
    final controller = TextEditingController();
    final count = await showDialog<int>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.file_upload_outlined, color: Color(0xFF2563EB)),
            SizedBox(width: 8),
            Text('Importar Favoritos (HTML)'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Cole o conteúdo de um arquivo HTML de favoritos (exportado de qualquer navegador):',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                maxLines: 8,
                decoration: InputDecoration(
                  hintText: '<!DOCTYPE NETSCAPE-Bookmark-file-1> ...',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  isDense: true,
                ),
                style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, 0),
            child: const BrowserText('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              final added = widget.browser.importBookmarksHtml(controller.text);
              Navigator.pop(ctx, added);
            },
            child: const Text('Importar'),
          ),
        ],
      ),
    );

    if (context.mounted && count != null && count > 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('$count novos favoritos importados com sucesso!'),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final browser = widget.browser;

    return ListenableBuilder(
      listenable: browser,
      builder: (context, _) {
        final favorites = browser.data.favorites
            .where((u) => u.toLowerCase().contains(_filter))
            .toList();
        final history = browser.data.history
            .where((u) => u.toLowerCase().contains(_filter))
            .toList();
        final readingList = browser.data.readingList
            .where(
              (i) =>
                  i.title.toLowerCase().contains(_filter) ||
                  i.url.toLowerCase().contains(_filter),
            )
            .toList();
        final downloads = browser.data.downloads
            .where(
              (d) =>
                  d.fileName.toLowerCase().contains(_filter) ||
                  d.url.toLowerCase().contains(_filter),
            )
            .toList();

        return SizedBox(
          height: MediaQuery.sizeOf(context).height * 0.8,
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TabBar(
                  controller: _tabController,
                  isScrollable: true,
                  tabAlignment: TabAlignment.start,
                  tabs: [
                    Tab(
                      icon: const Icon(Icons.star_rounded, size: 20),
                      text: 'Favoritos (${browser.data.favorites.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.history_rounded, size: 20),
                      text: 'Histórico (${browser.data.history.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.menu_book_rounded, size: 20),
                      text: 'Ler Depois (${browser.data.readingList.length})',
                    ),
                    Tab(
                      icon: const Icon(Icons.download_rounded, size: 20),
                      text: 'Downloads (${browser.data.downloads.length})',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  decoration: InputDecoration(
                    hintText: 'Filtrar por nome ou link...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 20),
                    isDense: true,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    filled: true,
                    fillColor: colors.surfaceContainerLow,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(
                        color: colors.outlineVariant.withValues(alpha: 0.5),
                      ),
                    ),
                  ),
                  onChanged: (val) =>
                      setState(() => _filter = val.trim().toLowerCase()),
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    // ABA 1: FAVORITOS
                    Column(
                      children: [
                        Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 4,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.file_upload_outlined,
                                  size: 16,
                                ),
                                label: const Text('Importar'),
                                onPressed: () => _importFavorites(context),
                              ),
                              const SizedBox(width: 8),
                              TextButton.icon(
                                icon: const Icon(
                                  Icons.file_download_outlined,
                                  size: 16,
                                ),
                                label: const Text('Exportar'),
                                onPressed: () => _exportFavorites(context),
                              ),
                            ],
                          ),
                        ),
                        Expanded(
                          child: _buildList(
                            items: favorites,
                            emptyMessage: 'Nenhum favorito salvo.',
                            icon: Icons.star_rounded,
                            onDelete: (url) =>
                                browser.removeEntry(url, history: false),
                          ),
                        ),
                      ],
                    ),

                    // ABA 2: HISTÓRICO
                    Column(
                      children: [
                        if (browser.data.history.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.delete_sweep_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Limpar todo histórico'),
                                  onPressed: () => browser.clearHistory(),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: _buildList(
                            items: history,
                            emptyMessage: 'Nenhum histórico recente.',
                            icon: Icons.history_rounded,
                            onDelete: (url) =>
                                browser.removeEntry(url, history: true),
                          ),
                        ),
                      ],
                    ),

                    // ABA 3: LISTA DE LEITURA
                    _buildReadingList(readingList),

                    // ABA 4: DOWNLOADS
                    Column(
                      children: [
                        if (browser.data.downloads.isNotEmpty)
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 4,
                            ),
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton.icon(
                                  icon: const Icon(
                                    Icons.delete_sweep_rounded,
                                    size: 18,
                                  ),
                                  label: const Text('Limpar downloads'),
                                  onPressed: () => browser.clearDownloads(),
                                ),
                              ],
                            ),
                          ),
                        Expanded(child: _buildDownloadsList(downloads)),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildList({
    required List<String> items,
    required String emptyMessage,
    required IconData icon,
    required void Function(String) onDelete,
  }) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(emptyMessage, style: const TextStyle(color: Colors.grey)),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final url = items[index];
        final host = Uri.tryParse(url)?.host ?? url;
        return ListTile(
          leading: Icon(icon, size: 20),
          title: Text(host, maxLines: 1, overflow: TextOverflow.ellipsis),
          subtitle: Text(
            url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: () => onDelete(url),
          ),
          onTap: () => Navigator.pop(context, url),
        );
      },
    );
  }

  Widget _buildReadingList(List<dynamic> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: const Text(
            'Sua lista de leitura está vazia.\nAdicione páginas para ler depois sem distrações!',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: IconButton(
            icon: Icon(
              item.isRead
                  ? Icons.check_circle_rounded
                  : Icons.radio_button_unchecked_rounded,
              color: item.isRead ? Colors.green : null,
              size: 20,
            ),
            tooltip: item.isRead ? 'Marcar como não lido' : 'Marcar como lido',
            onPressed: () => widget.browser.toggleReadingItemStatus(item.id),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              decoration: item.isRead ? TextDecoration.lineThrough : null,
              color: item.isRead ? Colors.grey : null,
            ),
          ),
          subtitle: Text(
            item.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            onPressed: () => widget.browser.removeReadingItem(item.id),
          ),
          onTap: () => Navigator.pop(context, item.url),
        );
      },
    );
  }

  Widget _buildDownloadsList(List<DownloadItem> items) {
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: const Text(
            'Nenhum download registrado.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ),
      );
    }

    return ListView.builder(
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        return ListTile(
          leading: const Icon(
            Icons.file_present_rounded,
            size: 24,
            color: Color(0xFF2563EB),
          ),
          title: Text(
            item.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            '${item.formattedSize} • ${item.downloadedAt.day.toString().padLeft(2, '0')}/${item.downloadedAt.month.toString().padLeft(2, '0')} ${item.downloadedAt.hour.toString().padLeft(2, '0')}:${item.downloadedAt.minute.toString().padLeft(2, '0')} • ${item.url}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontSize: 12),
          ),
          trailing: IconButton(
            icon: const Icon(Icons.delete_outline_rounded, size: 18),
            tooltip: 'Remover da lista',
            onPressed: () => widget.browser.removeDownload(item.id),
          ),
          onTap: () => Navigator.pop(context, item.url),
        );
      },
    );
  }
}
