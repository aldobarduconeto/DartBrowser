import 'components/theme_tile.dart';
import 'components/language_tile.dart';
import '../l10n/browser_text.dart';

import 'package:flutter/material.dart';

import '../controllers/browser_controller.dart';
import '../services/window_service.dart';
import 'components/window_caption_controls.dart';
import 'components/search_engine_tile.dart';

class WelcomePage extends StatefulWidget {
  const WelcomePage({
    super.key,
    required this.browser,
    required this.onContinue,
  });

  final BrowserController browser;
  final VoidCallback onContinue;

  @override
  State<WelcomePage> createState() => _WelcomePageState();
}

class _WelcomePageState extends State<WelcomePage> {
  bool _saving = false;

  Future<void> _finish() async {
    setState(() => _saving = true);
    try {
      if (await widget.browser.completeWelcome()) {
        if (mounted) widget.onContinue();
        return;
      }
    } on Exception {
      // Keep the welcome page open so the user can retry.
    }
    if (!mounted) return;
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: BrowserText('Não foi possível salvar a configuração inicial.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: WindowService.isDesktop
          ? AppBar(
              automaticallyImplyLeading: false,
              backgroundColor: Colors.transparent,
              elevation: 0,
              title: GestureDetector(
                behavior: HitTestBehavior.translucent,
                onPanStart: (_) => WindowService.startDragging(),
                onDoubleTap: () => WindowService.maximize(),
                child: const SizedBox(
                  width: double.infinity,
                  height: kToolbarHeight,
                ),
              ),
              actions: [
                if (!WindowService.isMacOS)
                  const WindowCaptionControls(height: kToolbarHeight),
              ],
            )
          : null,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 460),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(20),
                      child: Image.asset(
                        'assets/app_icon.png',
                        width: 76,
                        height: 76,
                        cacheWidth: 228,
                        excludeFromSemantics: true,
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    browserText(context, 'Boas-vindas ao Dart Browser'),
                    style: theme.textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    browserText(
                      context,
                      'Escolha seu buscador, o tema e a posição das abas. Você pode mudar essas opções nas configurações.',
                    ),
                  ),
                  const SizedBox(height: 24),
                  ListenableBuilder(
                    listenable: widget.browser,
                    builder: (context, _) => Card(
                      child: Column(
                        children: [
                          LanguageTile(browser: widget.browser),
                          ThemeTile(browser: widget.browser),
                          SearchEngineTile(browser: widget.browser),
                          SwitchListTile(
                            secondary: const Icon(
                              Icons.vertical_split_outlined,
                            ),
                            title: const BrowserText('Abas na lateral'),
                            value: widget.browser.verticalTabs,
                            onChanged: widget.browser.setVerticalTabs,
                          ),
                        ],
                      ),
                    ),
                  ),
                  const ExpansionTile(
                    initiallyExpanded: true,
                    title: Text('Conheça o navegador'),
                    children: [
                      ListTile(
                        title: Text('Navegação e abas'),
                        subtitle: Text(
                          'Pesquise na barra de endereço, organize grupos, fixe abas, divida a tela ou use guias anônimas.',
                        ),
                      ),
                      ListTile(
                        title: Text('Biblioteca'),
                        subtitle: Text(
                          'Gerencie favoritos, histórico, lista de leitura, notas por site e downloads.',
                        ),
                      ),
                      ListTile(
                        title: Text('Leitura e mídia'),
                        subtitle: Text(
                          'Use modo leitura, busca na página, zoom, leitura em voz alta, tradução, PiP e sons de foco.',
                        ),
                      ),
                      ListTile(
                        title: Text('Ferramentas'),
                        subtitle: Text(
                          'Use a paleta de comandos, captura de página, QR Code, código-fonte e informações do site.',
                        ),
                      ),
                      ListTile(
                        title: Text('Privacidade e complementos'),
                        subtitle: Text(
                          'Configure o escudo, controle dados locais e instale extensões compatíveis.',
                        ),
                      ),
                      ListTile(
                        title: Text('Personalização'),
                        subtitle: Text(
                          'Escolha cores, posição das abas e quais ferramentas aparecem na barra lateral.',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _saving ? null : _finish,
                    child: BrowserText(
                      _saving ? 'Salvando…' : 'Começar a navegar',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
