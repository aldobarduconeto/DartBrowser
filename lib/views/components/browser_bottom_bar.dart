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

  Future<void> showTabs(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (sheet) => SafeArea(
      child: FractionallySizedBox(
        heightFactor: .78,
        child: ListenableBuilder(
          listenable: browser,
          builder: (context, _) => Column(
            children: [
              ListTile(
                title: const Text('Abas abertas'),
                trailing: TextButton.icon(
                  icon: const Icon(Icons.add),
                  label: const Text('Nova aba'),
                  onPressed: () {
                    Navigator.pop(sheet);
                    browser.addTab();
                    focus.requestFocus();
                  },
                ),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: browser.tabs.length,
                  itemBuilder: (context, index) {
                    final tab = browser.tabs[index];
                    return ListTile(
                      key: ObjectKey(tab),
                      selected: identical(tab, browser.current),
                      leading: Icon(
                        tab.isIncognito
                            ? Icons.visibility_off_outlined
                            : Icons.public,
                        color: tab.group == null
                            ? null
                            : Color(tab.group!.color),
                      ),
                      title: Text(
                        tab.displayTitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: tab.group == null && tab.address == null
                          ? null
                          : Text(
                              tab.group?.name ?? tab.host,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                      onTap: () {
                        focus.unfocus();
                        browser.select(index);
                        Navigator.pop(sheet);
                      },
                      trailing: IconButton(
                        tooltip: 'Fechar aba',
                        icon: const Icon(Icons.close),
                        onPressed: () => browser.closeTab(index),
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
        fillColor: isTv ? colors.surfaceContainerHighest : Colors.transparent,
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
      Widget capsule(Widget child) => Material(
        color: colors.surfaceContainerHigh,
        shape: StadiumBorder(side: BorderSide(color: colors.outlineVariant)),
        clipBehavior: Clip.antiAlias,
        child: child,
      );

      return SafeArea(
        top: false,
        minimum: const EdgeInsets.fromLTRB(12, 4, 12, 8),
        child: Padding(
          padding: const EdgeInsets.only(bottom: 6),
          child: Row(
            children: [
              capsule(back),
              const SizedBox(width: 6),
              Expanded(child: capsule(addressField)),
              const SizedBox(width: 6),
              capsule(tabsButton),
              const SizedBox(width: 4),
              capsule(menu),
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
