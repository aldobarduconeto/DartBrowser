import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';
import '../browser_settings.dart';
import '../chrome_extensions_view.dart';
import 'ambient_sounds_dialog.dart';
import 'command_palette_dialog.dart';
import 'library_modal.dart';
import 'shield_dialog.dart';
import 'web_capture_dialog.dart';

class BrowserToolsDock extends StatelessWidget {
  const BrowserToolsDock({
    super.key,
    required this.browser,
    required this.onSubmit,
  });

  static const tools = {
    'commands': 'Paleta de comandos',
    'sounds': 'Sons de foco',
    'capture': 'Captura de página',
    'speech': 'Leitura em voz alta',
    'translate': 'Tradução',
    'favorites': 'Favoritos',
    'history': 'Histórico',
    'reading': 'Lista de leitura',
    'shield': 'Escudo de privacidade',
    'extensions': 'Extensões',
    'tabs': 'Posição das abas',
    'theme': 'Alternar tema',
    'settings': 'Configurações',
  };

  final BrowserController browser;
  final ValueChanged<String> onSubmit;

  Widget _dockButton({
    required BuildContext context,
    required IconData icon,
    required String tooltip,
    required VoidCallback onTap,
    Color? iconColor,
    bool isActive = false,
    String? badgeText,
  }) {
    final colors = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 2),
      child: Tooltip(
        message: tooltip,
        waitDuration: const Duration(milliseconds: 500),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            InkWell(
              borderRadius: BorderRadius.circular(10),
              onTap: onTap,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  color: isActive
                      ? colors.primary.withValues(alpha: 0.18)
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(10),
                  border: isActive
                      ? Border.all(
                          color: colors.primary.withValues(alpha: 0.35),
                        )
                      : null,
                ),
                child: Center(
                  child: Icon(
                    icon,
                    size: 19,
                    color: isActive
                        ? colors.primary
                        : (iconColor ?? colors.onSurfaceVariant),
                  ),
                ),
              ),
            ),
            if (badgeText != null && badgeText.isNotEmpty)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                decoration: BoxDecoration(
                  color: colors.primary,
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 8,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final tab = browser.current;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: 48,
      decoration: BoxDecoration(
        color: colors.surfaceContainerLow.withValues(alpha: 0.65),
        border: Border(
          right: BorderSide(
            color: colors.outlineVariant.withValues(alpha: 0.25),
            width: 1,
          ),
        ),
      ),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const SizedBox(height: 6),

          // Paleta de Comandos (Ctrl+K)
          if (browser.showsDockTool('commands'))
            _dockButton(
              context: context,
              icon: Icons.search_rounded,
              tooltip: 'Paleta de Comandos (Ctrl+K)',
              iconColor: colors.primary,
              onTap: () => CommandPaletteDialog.show(
                context,
                browser: browser,
                onSubmit: onSubmit,
                onStartReadAloud: browser.startReadAloud,
              ),
            ),

          // Sons de Foco Ambientais
          if (browser.showsDockTool('sounds'))
            _dockButton(
              context: context,
              icon: Icons.headphones_rounded,
              tooltip: 'Sons de Foco Ambientais',
              onTap: () => AmbientSoundsDialog.show(context, browser),
            ),

          // Captura de Tela (Ctrl+Shift+S)
          if (browser.showsDockTool('capture'))
            _dockButton(
              context: context,
              icon: Icons.camera_alt_rounded,
              tooltip: 'Captura de Tela da Web (Ctrl+Shift+S)',
              onTap: () => WebCaptureDialog.show(context, browser),
            ),

          // Leitura em Voz Alta (Ctrl+Shift+U)
          if (browser.showsDockTool('speech'))
            _dockButton(
              context: context,
              icon: Icons.record_voice_over_rounded,
              tooltip: browser.readAloudService.isActive
                  ? 'Pausar Leitura em Voz Alta'
                  : 'Ler Página em Voz Alta (Ctrl+Shift+U)',
              isActive: browser.readAloudService.isActive,
              onTap: () {
                if (browser.readAloudService.isActive) {
                  browser.stopReadAloud();
                } else {
                  browser.startReadAloud();
                }
              },
            ),

          // Tradutor de Página
          if (browser.showsDockTool('translate'))
            _dockButton(
              context: context,
              icon: Icons.translate_rounded,
              tooltip: 'Traduzir Página para Português',
              onTap: () => browser.translateCurrentPage(),
            ),

          const SizedBox(height: 4),
          Divider(
            height: 1,
            indent: 8,
            endIndent: 8,
            color: colors.outlineVariant.withValues(alpha: 0.25),
          ),
          const SizedBox(height: 4),

          // Favoritos
          if (browser.showsDockTool('favorites'))
            _dockButton(
              context: context,
              icon: Icons.star_outline_rounded,
              tooltip: 'Favoritos',
              onTap: () async {
                final url = await LibraryModal.show(
                  context,
                  browser: browser,
                  initialIndex: 0,
                );
                if (url != null) onSubmit(url);
              },
            ),

          // Histórico
          if (browser.showsDockTool('history'))
            _dockButton(
              context: context,
              icon: Icons.history_rounded,
              tooltip: 'Histórico de Navegação',
              onTap: () async {
                final url = await LibraryModal.show(
                  context,
                  browser: browser,
                  initialIndex: 1,
                );
                if (url != null) onSubmit(url);
              },
            ),

          // Lista de Leitura ("Ler Depois")
          if (browser.showsDockTool('reading'))
            _dockButton(
              context: context,
              icon: Icons.menu_book_rounded,
              tooltip: 'Lista de Leitura (${browser.data.readingList.length})',
              onTap: () async {
                final url = await LibraryModal.show(
                  context,
                  browser: browser,
                  initialIndex: 2,
                );
                if (url != null) onSubmit(url);
              },
            ),

          // Escudo de Proteção AdBlock
          if (browser.showsDockTool('shield'))
            _dockButton(
              context: context,
              icon: Icons.shield_outlined,
              tooltip:
                  'Escudo AdBlock & Anti-Rastreio (${tab.totalBlockedCount} bloqueados)',
              iconColor: tab.totalBlockedCount > 0
                  ? Colors.green.shade600
                  : null,
              badgeText: tab.totalBlockedCount > 0
                  ? '${tab.totalBlockedCount}'
                  : null,
              onTap: () =>
                  ShieldDialog.show(context, browser: browser, tab: tab),
            ),

          // Extensões
          if (browser.showsDockTool('extensions'))
            _dockButton(
              context: context,
              icon: Icons.extension_outlined,
              tooltip: 'Extensões Web',
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => BrowserAddons(browser: browser),
                  ),
                );
              },
            ),

          // Alternar Abas no Topo / Abas Verticais
          if (browser.showsDockTool('tabs'))
            _dockButton(
              context: context,
              icon: browser.verticalTabs
                  ? Icons.view_headline_rounded
                  : Icons.view_sidebar_rounded,
              tooltip: browser.verticalTabs
                  ? 'Mudar abas para o topo'
                  : 'Mudar abas para a lateral',
              onTap: () => browser.setVerticalTabs(!browser.verticalTabs),
            ),

          // Alternar Tema Claro / Escuro
          if (browser.showsDockTool('theme'))
            _dockButton(
              context: context,
              icon: isDark ? Icons.light_mode_rounded : Icons.dark_mode_rounded,
              tooltip: isDark ? 'Ativar tema claro' : 'Ativar tema escuro',
              onTap: () =>
                  browser.setTheme(isDark ? ThemeMode.light : ThemeMode.dark),
            ),

          // Configurações
          if (browser.showsDockTool('settings'))
            _dockButton(
              context: context,
              icon: Icons.settings_outlined,
              tooltip: 'Configurações',
              onTap: () {
                Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => BrowserSettings(browser: browser),
                  ),
                );
              },
            ),

          const SizedBox(height: 8),
        ],
      ),
    );
  }
}
