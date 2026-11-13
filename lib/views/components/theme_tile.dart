import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';

class ThemeTile extends StatelessWidget {
  const ThemeTile({super.key, required this.browser});

  final BrowserController browser;

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.brightness_6_outlined),
    title: const Text('Tema do aplicativo'),
    trailing: DropdownButton<String>(
      value:
          browser.themeNotifier.value == ThemeMode.dark &&
              browser.oledNotifier.value
          ? 'oled'
          : browser.themeNotifier.value.name,
      items: const [
        DropdownMenuItem(value: 'system', child: Text('Sistema')),
        DropdownMenuItem(value: 'light', child: Text('Claro')),
        DropdownMenuItem(value: 'dark', child: Text('Escuro')),
        DropdownMenuItem(value: 'oled', child: Text('OLED')),
      ],
      onChanged: (value) {
        if (value == null) return;
        browser.setOledBlack(value == 'oled');
        browser.setTheme(
          value == 'oled' ? ThemeMode.dark : ThemeMode.values.byName(value),
        );
      },
    ),
  );
}
