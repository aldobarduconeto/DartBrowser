import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';
import '../../l10n/browser_locale.dart';
import '../../l10n/browser_text.dart';

class LanguageTile extends StatelessWidget {
  const LanguageTile({super.key, required this.browser});

  final BrowserController browser;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Locale?>(
      valueListenable: browser.localeNotifier,
      builder: (context, locale, _) => ListTile(
        leading: const Icon(Icons.language),
        title: Text(browserText(context, 'Idioma do aplicativo')),
        subtitle: Text(
          locale == null
              ? (browserText(context, 'Seguir o sistema'))
              : BrowserLocale.label(locale),
        ),
        onTap: () => showDialog<void>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            title: Text(browserText(context, 'Escolher idioma')),
            content: SizedBox(
              width: 420,
              height: 440,
              child: ListView.builder(
                itemCount: BrowserLocale.supported.length + 1,
                itemBuilder: (context, index) {
                  final option = index == 0
                      ? null
                      : BrowserLocale.supported[index - 1];
                  return ListTile(
                    title: Text(
                      option == null
                          ? (browserText(context, 'Seguir o sistema'))
                          : BrowserLocale.label(option),
                    ),
                    trailing: locale == option ? const Icon(Icons.check) : null,
                    onTap: () async {
                      await browser.setLocale(option);
                      if (dialogContext.mounted) Navigator.pop(dialogContext);
                    },
                  );
                },
              ),
            ),
          ),
        ),
      ),
    );
  }
}
