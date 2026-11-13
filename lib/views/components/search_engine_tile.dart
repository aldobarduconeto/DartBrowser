import '../../l10n/browser_text.dart';

import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';
import '../../models/browser_data.dart';

class SearchEngineTile extends StatelessWidget {
  const SearchEngineTile({super.key, required this.browser});

  final BrowserController browser;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.search),
    title: const BrowserText('Mecanismo de busca'),
    subtitle: Text(browser.data.searchEngine.label),
    trailing: PopupMenuButton<SearchEngine>(
      tooltip: browserText(context, 'Escolher buscador'),
      initialValue: browser.data.searchEngine,
      onSelected: browser.setSearchEngine,
      itemBuilder: (_) => [
        for (final engine in SearchEngine.values)
          PopupMenuItem(value: engine, child: Text(engine.label)),
      ],
    ),
  );
}
