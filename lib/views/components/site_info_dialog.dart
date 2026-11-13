import '../../l10n/browser_text.dart';

import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';

class SiteInfoDialog extends StatelessWidget {
  const SiteInfoDialog({super.key, required this.browser});

  final BrowserController browser;

  static void show(BuildContext context, BrowserController browser) {
    showDialog<void>(
      context: context,
      builder: (_) => SiteInfoDialog(browser: browser),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tab = browser.current;
    final url = tab.address ?? '';
    final uri = Uri.tryParse(url);
    final isHttps = uri?.scheme == 'https';
    final host = uri?.host ?? 'Página local';

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isHttps
                  ? Colors.green.withValues(alpha: 0.15)
                  : Colors.orange.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(
              isHttps ? Icons.lock_rounded : Icons.info_outline_rounded,
              color: isHttps ? Colors.green.shade700 : Colors.orange.shade800,
              size: 22,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isHttps ? 'Conexão segura' : 'Não seguro',
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  host,
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
      content: SizedBox(
        width: 420,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: colors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: colors.outlineVariant.withValues(alpha: 0.4),
                ),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        isHttps
                            ? Icons.verified_user_rounded
                            : Icons.warning_amber_rounded,
                        size: 18,
                        color: isHttps ? Colors.green : Colors.orange,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          isHttps
                              ? 'Suas informações (senhas ou cartões) permanecem privadas ao serem enviadas para este site.'
                              : 'Você não deve inserir informações confidenciais neste site, pois a conexão não é criptografada.',
                          style: const TextStyle(fontSize: 12.5, height: 1.35),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.language_rounded, size: 20),
              title: const Text('Protocolo'),
              subtitle: Text(uri?.scheme.toUpperCase() ?? 'DESCONHECIDO'),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.cookie_outlined, size: 20),
              title: const Text('Cookies e armazenamento do site'),
              subtitle: const Text(
                'Gerenciados automaticamente pelo motor WebView',
              ),
            ),
            ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: const Icon(Icons.fact_check_outlined, size: 20),
              title: const Text('Recursos e compatibilidade web'),
              subtitle: const Text(
                'WebGPU, WebAssembly, Service Workers, etc.',
              ),
              trailing: const Icon(Icons.chevron_right_rounded),
              onTap: () {
                Navigator.pop(context);
                if (browser.canInspectPage) {
                  _showPageCapabilities(context);
                }
              },
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const BrowserText('Fechar'),
        ),
        FilledButton.tonal(
          onPressed: () async {
            try {
              await tab.engine.runJavaScript(
                'localStorage.clear(); sessionStorage.clear();',
              );
              if (context.mounted) {
                Navigator.pop(context);
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Armazenamento do site limpo com sucesso!'),
                  ),
                );
              }
            } catch (_) {}
          },
          child: const Text('Limpar dados do site'),
        ),
      ],
    );
  }

  void _showPageCapabilities(BuildContext context) {
    final result = browser.inspectCurrentPage();
    showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Recursos da página'),
        content: SizedBox(
          width: 440,
          child: FutureBuilder<Map<String, bool>>(
            future: result,
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return const Text('Não foi possível verificar os recursos.');
              }
              final capabilities = snapshot.data;
              if (capabilities == null) {
                return const LinearProgressIndicator();
              }
              return SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final entry in capabilities.entries)
                      ListTile(
                        dense: true,
                        leading: Icon(
                          entry.value
                              ? Icons.check_circle_outline
                              : Icons.remove_circle_outline,
                          color: entry.value ? Colors.green : Colors.grey,
                        ),
                        title: Text(entry.key),
                        subtitle: Text(
                          entry.value ? 'Disponível' : 'Indisponível',
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const BrowserText('Fechar'),
          ),
        ],
      ),
    );
  }
}
