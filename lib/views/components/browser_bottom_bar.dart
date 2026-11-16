import 'private_window.dart';
import 'navigation_surface.dart';

import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';
import '../browser_settings.dart';
import '../chrome_extensions_view.dart';
import 'library_modal.dart';

class BrowserBottomBar extends StatelessWidget {
  const BrowserBottomBar({
    super.key,
    required this.browser,
    this.isTv = false,
    required this.address,
    required this.focus,
    required this.onSubmit,
    this.onShowExtensionsMenu,
  });

  final BrowserController browser;
  final bool isTv;
  final TextEditingController address;
  final FocusNode focus;
  final ValueChanged<String> onSubmit;
  final VoidCallback? onShowExtensionsMenu;

  Future<void> showTabs(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      showDragHandle: true,
      backgroundColor: colors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheet) => SafeArea(
        child: FractionallySizedBox(
          heightFactor: .82,
          child: ListenableBuilder(
            listenable: browser,
            builder: (context, _) => Column(
              children: [
                Padding(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Row(
                    children: [
                      Text(
                        'Abas abertas (${browser.tabs.length})',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      FilledButton.tonalIcon(
                        style: FilledButton.styleFrom(
                          visualDensity: VisualDensity.compact,
                          padding: const EdgeInsets.symmetric(horizontal: 14),
                        ),
                        icon: const Icon(Icons.add_rounded, size: 18),
                        label: const Text('Nova aba'),
                        onPressed: () {
                          Navigator.pop(sheet);
                          browser.addTab();
                          focus.requestFocus();
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Expanded(
                  child: GridView.builder(
                    padding: const EdgeInsets.all(12),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          childAspectRatio: 0.88,
                          crossAxisSpacing: 10,
                          mainAxisSpacing: 10,
                        ),
                    itemCount: browser.tabs.length,
                    itemBuilder: (context, index) {
                      final tab = browser.tabs[index];
                      final isSelected = identical(tab, browser.current);
                      final host = tab.host;
                      final cleanHost =
                          host.replaceFirst(RegExp(r'^www\.'), '');
                      final faviconEndpoint = cleanHost.isNotEmpty
                          ? 'https://www.google.com/s2/favicons?domain=$cleanHost&sz=32'
                          : null;

                      return InkWell(
                        borderRadius: BorderRadius.circular(16),
                        onTap: () {
                          focus.unfocus();
                          browser.select(index);
                          Navigator.pop(sheet);
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? colors.primaryContainer.withValues(
                                    alpha: 0.35,
                                  )
                                : colors.surfaceContainerLow,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(
                              color: isSelected
                                  ? colors.primary
                                  : colors.outlineVariant.withValues(
                                      alpha: 0.35,
                                    ),
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.04),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ],
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(10, 8, 4, 4),
                                child: Row(
                                  children: [
                                    if (tab.isIncognito)
                                      const Icon(
                                        Icons.visibility_off_rounded,
                                        size: 15,
                                        color: Colors.purple,
                                      )
                                    else if (faviconEndpoint != null)
                                      ClipRRect(
                                        borderRadius: BorderRadius.circular(4),
                                        child: Image.network(
                                          faviconEndpoint,
                                          width: 15,
                                          height: 15,
                                          errorBuilder: (_, __, ___) => Icon(
                                            Icons.public_rounded,
                                            size: 15,
                                            color: colors.primary,
                                          ),
                                        ),
                                      )
                                    else
                                      Icon(
                                        Icons.public_rounded,
                                        size: 15,
                                        color: colors.primary,
                                      ),
                                    const SizedBox(width: 6),
                                    Expanded(
                                      child: Text(
                                        tab.displayTitle,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: isSelected
                                              ? FontWeight.bold
                                              : FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                    IconButton(
                                      tooltip: 'Fechar aba',
                                      visualDensity: VisualDensity.compact,
                                      padding: EdgeInsets.zero,
                                      constraints: const BoxConstraints(
                                        minWidth: 26,
                                        minHeight: 26,
                                      ),
                                      icon: const Icon(
                                        Icons.close_rounded,
                                        size: 16,
                                      ),
                                      onPressed: () {
                                        browser.closeTab(index);
                                        if (browser.tabs.isEmpty) {
                                          Navigator.pop(sheet);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ),
                              const Divider(height: 1, thickness: 0.6),
                              Expanded(
                                child: Container(
                                  margin: const EdgeInsets.all(8),
                                  decoration: BoxDecoration(
                                    color: colors.surfaceContainerHighest
                                        .withValues(alpha: 0.35),
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Center(
                                    child: Padding(
                                      padding: const EdgeInsets.all(8),
                                      child: Column(
                                        mainAxisSize: MainAxisSize.min,
                                        children: [
                                          Icon(
                                            tab.isIncognito
                                                ? Icons.visibility_off_outlined
                                                : Icons.web_rounded,
                                            size: 28,
                                            color: colors.onSurfaceVariant
                                                .withValues(alpha: 0.4),
                                          ),
                                          const SizedBox(height: 6),
                                          Text(
                                            tab.group?.name ??
                                                (cleanHost.isNotEmpty
                                                    ? cleanHost
                                                    : 'Nova aba'),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: colors.onSurfaceVariant,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tab = browser.current;
    final addressField = TextField(
      controller: address,
      focusNode: focus,
      style: isTv ? Theme.of(context).textTheme.titleLarge : null,
      keyboardType: TextInputType.url,
      textInputAction: TextInputAction.go,
      autocorrect: false,
      onSubmitted: onSubmit,
      decoration: InputDecoration(
        hintText: 'Pesquisar ou digitar endereço',
        prefixIcon: const Icon(Icons.search),
        suffixIcon: IconButton(
          tooltip: 'Abrir endereço',
          icon: const Icon(Icons.arrow_forward),
          onPressed: () => onSubmit(address.text),
        ),
        filled: true,
        fillColor: isTv ? colors.surfaceContainerLow : Colors.transparent,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(24),
          borderSide: BorderSide.none,
        ),
      ),
    );
    final back = IconButton(
      tooltip: 'Voltar',
      icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 19),
      onPressed: tab.canGoBack ? browser.goBack : null,
    );
    final tabsButton = IconButton(
      autofocus: isTv,
      tooltip: 'Abas abertas (${browser.tabs.length})',
      icon: Badge(
        label: Text('${browser.tabs.length}'),
        child: const Icon(Icons.filter_none_rounded),
      ),
      onPressed: () => showTabs(context),
    );
    final menu = PopupMenuButton<String>(
      tooltip: 'Menu',
      onSelected: (value) async {
        switch (value) {
          case 'private_window':
            await openPrivateWindow(context, browser);
          case 'private':
            browser.addIncognitoTab();
            focus.requestFocus();
          case 'forward':
            await browser.goForward();
          case 'reload':
            await browser.reload();
          case 'stop':
            await browser.stop();
          case 'bookmark':
            await browser.toggleFavorite();
          case 'find':
            browser.openFindInPage();
          case 'page_extensions':
            onShowExtensionsMenu?.call();
          case 'bookmarks':
          case 'history':
          case 'reading':
            final url = await LibraryModal.show(
              context,
              browser: browser,
              initialIndex: ['bookmarks', 'history', 'reading'].indexOf(value),
            );
            if (context.mounted && url != null) onSubmit(url);
          case 'extensions':
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => BrowserAddons(browser: browser),
              ),
            );
          case 'settings':
            await Navigator.of(context).push<void>(
              MaterialPageRoute(
                builder: (_) => BrowserSettings(browser: browser),
              ),
            );
        }
      },
      itemBuilder: (context) => [
        if (!isTv && tab.canGoForward)
          const PopupMenuItem(value: 'forward', child: Text('Avançar')),
        if (!browser.privateWindow)
          const PopupMenuItem(
            value: 'private_window',
            child: Text('Nova janela anônima'),
          ),
        const PopupMenuItem(value: 'private', child: Text('Nova guia anônima')),
        if (tab.address != null) ...[
          PopupMenuItem(
            value: tab.progress < 100 ? 'stop' : 'reload',
            child: Text(
              tab.progress < 100 ? 'Parar carregamento' : 'Recarregar',
            ),
          ),
          const PopupMenuItem(
            value: 'bookmark',
            child: Text('Alternar favorito'),
          ),
          const PopupMenuItem(
            value: 'find',
            child: Text('Localizar na página'),
          ),
        ],
        if (onShowExtensionsMenu != null)
          const PopupMenuItem(
            value: 'page_extensions',
            child: Row(
              children: [
                Icon(Icons.extension_rounded, size: 20),
                SizedBox(width: 12),
                Text('Extensões nesta página'),
              ],
            ),
          ),
        const PopupMenuItem(value: 'bookmarks', child: Text('Favoritos')),
        const PopupMenuItem(value: 'history', child: Text('Histórico')),
        const PopupMenuItem(value: 'reading', child: Text('Lista de leitura')),
        const PopupMenuItem(
          value: 'extensions',
          child: Row(
            children: [
              Icon(Icons.tune_rounded, size: 20),
              SizedBox(width: 12),
              Text('Gerenciar extensões'),
            ],
          ),
        ),
        const PopupMenuItem(value: 'settings', child: Text('Configurações')),
      ],
    );
    if (!isTv) {
      return Container(
        padding: const EdgeInsets.fromLTRB(10, 6, 10, 8),
        decoration: BoxDecoration(
          color: tab.isIncognito
              ? Color.alphaBlend(
                  colors.tertiary.withValues(alpha: .08),
                  colors.surface,
                )
              : colors.surface,
          border: Border(
            top: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.2),
              width: 0.8,
            ),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              IconButton(
                tooltip: 'Voltar',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.arrow_back_rounded, size: 20),
                onPressed: tab.canGoBack ? browser.goBack : null,
              ),
              if (tab.canGoForward)
                IconButton(
                  tooltip: 'Avançar',
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.arrow_forward_rounded, size: 20),
                  onPressed: browser.goForward,
                ),
              const SizedBox(width: 4),
              Expanded(
                child: Container(
                  height: 38,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.35),
                      width: 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 10, right: 6),
                        child: Icon(
                          tab.isIncognito
                              ? Icons.visibility_off_rounded
                              : (tab.address?.startsWith('https://') == true
                                  ? Icons.lock_rounded
                                  : Icons.search_rounded),
                          size: 15,
                          color: tab.isIncognito
                              ? Colors.purple
                              : (tab.address?.startsWith('https://') == true
                                  ? Colors.green.shade600
                                  : colors.onSurfaceVariant),
                        ),
                      ),
                      Expanded(
                        child: TextField(
                          controller: address,
                          focusNode: focus,
                          style: const TextStyle(fontSize: 13),
                          keyboardType: TextInputType.url,
                          textInputAction: TextInputAction.go,
                          autocorrect: false,
                          onSubmitted: onSubmit,
                          decoration: InputDecoration(
                            hintText: 'Pesquisar ou digitar URL',
                            hintStyle: TextStyle(
                              fontSize: 12.5,
                              color: colors.onSurfaceVariant.withValues(
                                alpha: 0.6,
                              ),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 9,
                            ),
                          ),
                        ),
                      ),
                      if (tab.address != null)
                        IconButton(
                          tooltip: tab.progress < 100 ? 'Parar' : 'Recarregar',
                          visualDensity: VisualDensity.compact,
                          icon: Icon(
                            tab.progress < 100
                                ? Icons.close_rounded
                                : Icons.refresh_rounded,
                            size: 17,
                          ),
                          onPressed: tab.progress < 100
                              ? browser.stop
                              : browser.reload,
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Tooltip(
                message: 'Abas abertas (${browser.tabs.length})',
                child: InkWell(
                  borderRadius: BorderRadius.circular(10),
                  onTap: () => showTabs(context),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(9),
                      border: Border.all(
                        color: colors.onSurface.withValues(alpha: 0.75),
                        width: 1.6,
                      ),
                    ),
                    child: Center(
                      child: Text(
                        '${browser.tabs.length}',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              menu,
            ],
          ),
        ),
      );
    }
    return Material(
      color: colors.surfaceContainer,
      child: SafeArea(
        top: false,
        child: FocusTraversalGroup(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: EdgeInsets.fromLTRB(
                  isTv ? 32 : 12,
                  8,
                  isTv ? 32 : 12,
                  0,
                ),
                child: addressField,
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton(
                    tooltip: 'Voltar',
                    icon: const Icon(Icons.arrow_back),
                    onPressed: tab.canGoBack ? browser.goBack : null,
                  ),
                  IconButton(
                    tooltip: 'Avançar',
                    icon: const Icon(Icons.arrow_forward),
                    onPressed: tab.canGoForward ? browser.goForward : null,
                  ),
                  if (onShowExtensionsMenu != null)
                    ListenableBuilder(
                      listenable: browser,
                      builder: (context, _) {
                        final activeCount =
                            browser.activeAddonsForCurrentPage.length;
                        final hasAddons = browser.addons.isNotEmpty;
                        return IconButton(
                          tooltip: activeCount > 0
                              ? 'Extensões ($activeCount ativas na página)'
                              : 'Extensões do Navegador',
                          icon: Badge(
                            isLabelVisible: activeCount > 0,
                            backgroundColor: Colors.green.shade700,
                            label: Text('$activeCount'),
                            child: Icon(
                              activeCount > 0
                                  ? Icons.extension_rounded
                                  : (hasAddons
                                        ? Icons.extension_outlined
                                        : Icons.extension_rounded),
                              color: activeCount > 0
                                  ? colors.primary
                                  : (hasAddons
                                        ? null
                                        : colors.onSurfaceVariant),
                            ),
                          ),
                          onPressed: onShowExtensionsMenu,
                        );
                      },
                    ),
                  tabsButton,
                  menu,
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
