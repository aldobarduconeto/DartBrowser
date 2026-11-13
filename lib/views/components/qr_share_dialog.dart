import '../../l10n/browser_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../utils/qr_code.dart';

class QrShareDialog extends StatelessWidget {
  const QrShareDialog({super.key, required this.url});

  final String url;

  static void show(BuildContext context, String url) {
    showDialog<void>(
      context: context,
      builder: (_) => QrShareDialog(url: url),
    );
  }

  @override
  Widget build(BuildContext context) {
    final host = Uri.tryParse(url)?.host ?? url;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primaryContainer,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              Icons.qr_code_2_rounded,
              color: Theme.of(context).colorScheme.primary,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          const Text('Escanear com o celular'),
        ],
      ),
      content: SizedBox(
        width: 320,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Aponte a câmera do seu smartphone para abrir esta página instantaneamente:',
              style: TextStyle(fontSize: 13),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            QrCodeWidget(data: url, size: 210),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surfaceContainerHigh,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  const Icon(Icons.link_rounded, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      host,
                      style: const TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const BrowserText('Fechar'),
        ),
        FilledButton.icon(
          icon: const Icon(Icons.copy_rounded, size: 16),
          label: const Text('Copiar link'),
          onPressed: () {
            Clipboard.setData(ClipboardData(text: url));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Link copiado com sucesso!')),
            );
          },
        ),
      ],
    );
  }
}
