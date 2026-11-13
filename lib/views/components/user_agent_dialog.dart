import '../../l10n/browser_text.dart';

import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';

class UserAgentDialog extends StatelessWidget {
  const UserAgentDialog({super.key, required this.browser});

  final BrowserController browser;

  static const presets = [
    (
      name: 'Padrão do Sistema',
      description: 'Identificação padrão do dispositivo atual',
      ua: null,
      icon: Icons.computer_rounded,
    ),
    (
      name: 'iPhone 15 Pro (iOS Safari)',
      description: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X)',
      ua: 'Mozilla/5.0 (iPhone; CPU iPhone OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
      icon: Icons.phone_iphone_rounded,
    ),
    (
      name: 'Google Pixel 8 (Android Chrome)',
      description: 'Mozilla/5.0 (Linux; Android 14; Pixel 8) Chrome/123.0',
      ua: 'Mozilla/5.0 (Linux; Android 14; Pixel 8) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/123.0.6312.80 Mobile Safari/537.36',
      icon: Icons.phone_android_rounded,
    ),
    (
      name: 'iPad Pro (iPadOS)',
      description: 'Mozilla/5.0 (iPad; CPU OS 17_4 like Mac OS X)',
      ua: 'Mozilla/5.0 (iPad; CPU OS 17_4 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Mobile/15E148 Safari/604.1',
      icon: Icons.tablet_mac_rounded,
    ),
    (
      name: 'macOS (Safari Desktop)',
      description: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7)',
      ua: 'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.4 Safari/605.1.15',
      icon: Icons.laptop_mac_rounded,
    ),
  ];

  static void show(BuildContext context, BrowserController browser) {
    showDialog<void>(
      context: context,
      builder: (_) => UserAgentDialog(browser: browser),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tab = browser.current;

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      title: const Row(
        children: [
          Icon(Icons.devices_rounded, color: Color(0xFF2563EB)),
          SizedBox(width: 10),
          Text('Emular dispositivo (User-Agent)'),
        ],
      ),
      content: SizedBox(
        width: 480,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Escolha como os sites reconhecerão este navegador. Ideal para testar layouts responsivos e versões móveis:',
              style: TextStyle(fontSize: 13),
            ),
            const SizedBox(height: 16),
            for (final p in presets)
              Card(
                elevation: 0,
                color: tab.customUserAgent == p.ua
                    ? colors.primaryContainer.withValues(alpha: 0.3)
                    : colors.surfaceContainerLow,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: tab.customUserAgent == p.ua
                        ? colors.primary
                        : colors.outlineVariant.withValues(alpha: 0.4),
                  ),
                ),
                child: ListTile(
                  leading: Icon(p.icon, color: colors.primary),
                  title: Text(
                    p.name,
                    style: const TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 13.5,
                    ),
                  ),
                  subtitle: Text(
                    p.description,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  trailing: tab.customUserAgent == p.ua
                      ? const Icon(
                          Icons.check_circle_rounded,
                          color: Colors.green,
                        )
                      : null,
                  onTap: () async {
                    browser.setUserAgent(tab, p.ua);
                    Navigator.pop(context);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Dispositivo alternado para: ${p.name}'),
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const BrowserText('Cancelar'),
        ),
      ],
    );
  }
}
