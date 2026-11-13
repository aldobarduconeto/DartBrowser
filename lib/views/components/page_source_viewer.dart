import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/browser_controller.dart';

class PageSourceViewer extends StatefulWidget {
  const PageSourceViewer({super.key, required this.browser});

  final BrowserController browser;

  static void show(BuildContext context, BrowserController browser) {
    showDialog<void>(
      context: context,
      builder: (_) => PageSourceViewer(browser: browser),
    );
  }

  @override
  State<PageSourceViewer> createState() => _PageSourceViewerState();
}

class _PageSourceViewerState extends State<PageSourceViewer> {
  bool loading = true;
  String sourceCode = '';
  String searchQuery = '';
  final searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _fetchSource();
  }

  @override
  void dispose() {
    searchController.dispose();
    super.dispose();
  }

  Future<void> _fetchSource() async {
    const script = r"""
      (() => {
        try {
          return document.documentElement ? document.documentElement.outerHTML : '';
        } catch (e) {
          return '';
        }
      })();
    """;

    try {
      final res = await widget.browser.current.engine
          .runJavaScriptReturningResult(script);
      Object? decoded = res;
      if (decoded is String) {
        if (decoded.startsWith('"') && decoded.endsWith('"')) {
          try {
            decoded = jsonDecode(decoded);
          } catch (_) {}
        }
      }
      if (mounted) {
        setState(() {
          sourceCode = decoded?.toString() ?? '';
          loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final lines = sourceCode.split('\n');

    final filteredIndices = <int>[];
    if (searchQuery.isNotEmpty) {
      for (int i = 0; i < lines.length; i++) {
        if (lines[i].toLowerCase().contains(searchQuery.toLowerCase())) {
          filteredIndices.add(i);
        }
      }
    }

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: 800,
        height: 600,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              color: colors.surfaceContainerHigh,
              child: Row(
                children: [
                  Icon(Icons.code_rounded, color: colors.primary, size: 22),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Código-fonte da página',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                        Text(
                          '${lines.length} linhas • ${(sourceCode.length / 1024).toStringAsFixed(1)} KB',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: 'Copiar todo o código',
                    icon: const Icon(Icons.copy_rounded, size: 18),
                    onPressed: sourceCode.isEmpty
                        ? null
                        : () {
                            Clipboard.setData(ClipboardData(text: sourceCode));
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Código-fonte copiado!'),
                              ),
                            );
                          },
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(8),
              child: TextField(
                controller: searchController,
                decoration: InputDecoration(
                  hintText: 'Filtrar por trecho de código...',
                  prefixIcon: const Icon(Icons.search_rounded, size: 20),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            searchController.clear();
                            setState(() => searchQuery = '');
                          },
                        )
                      : null,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onChanged: (val) => setState(() => searchQuery = val.trim()),
              ),
            ),
            Expanded(
              child: loading
                  ? const Center(child: CircularProgressIndicator())
                  : sourceCode.isEmpty
                  ? const Center(child: Text('Código-fonte não disponível.'))
                  : Container(
                      color: const Color(0xFF1E1E1E),
                      child: ListView.builder(
                        itemCount: searchQuery.isEmpty
                            ? lines.length
                            : filteredIndices.length,
                        itemBuilder: (context, idx) {
                          final lineIndex = searchQuery.isEmpty
                              ? idx
                              : filteredIndices[idx];
                          final line = lines[lineIndex];

                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 50,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 1,
                                ),
                                alignment: Alignment.centerRight,
                                color: const Color(0xFF252526),
                                child: Text(
                                  '${lineIndex + 1}',
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 11,
                                    color: Color(0xFF858585),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                child: SelectableText(
                                  line,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                    color: Color(0xFFD4D4D4),
                                  ),
                                ),
                              ),
                            ],
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
