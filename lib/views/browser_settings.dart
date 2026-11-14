import 'components/theme_tile.dart';
import 'welcome_page.dart';
import 'components/browser_tools_dock.dart';
import '../l10n/browser_text.dart';

import 'package:flutter/material.dart';

import '../controllers/browser_controller.dart';
import '../models/browser_data.dart';
import 'components/search_engine_tile.dart';
import 'components/language_tile.dart';
import 'chrome_extensions_view.dart';
import 'components/library_modal.dart';
import '../services/window_service.dart';
import 'components/window_caption_controls.dart';

class BrowserSettings extends StatefulWidget {
  const BrowserSettings({super.key, required this.browser});

  final BrowserController browser;

  @override
  State<BrowserSettings> createState() => _BrowserSettingsState();
}

class _BrowserSettingsState extends State<BrowserSettings> {
  BrowserController get browser => widget.browser;
  bool clearing = false;

  Future<void> editHome() async {
    var address = browser.data.home ?? '';
    String? error;
    final result = await showDialog<String>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, update) {
          void save() {
            final uri = Uri.tryParse(address.trim());
            if (uri == null || !BrowserData.isWeb(uri)) {
              update(() => error = 'Informe um endereço HTTP ou HTTPS.');
              return;
            }
            Navigator.pop(context, uri.toString());
          }

          return AlertDialog(
            title: const BrowserText('Página inicial'),
            content: TextFormField(
              initialValue: address,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                labelText: 'Endereço',
                hintText: 'https://example.org',
                errorText: error,
              ),
              onChanged: (value) => address = value,
              onFieldSubmitted: (_) => save(),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const BrowserText('Cancelar'),
              ),
              FilledButton(onPressed: save, child: const BrowserText('Salvar')),
            ],
          );
        },
      ),
    );
    if (mounted && result != null) await browser.setHome(result);
  }

  Future<void> confirmClear(
    String label,
    String detail,
    Future<void> Function() action,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(label),
        content: Text(detail),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const BrowserText('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Limpar'),
          ),
        ],
      ),
    );
    if (!mounted || confirmed != true || clearing) return;
    setState(() => clearing = true);
    var message = 'Dados removidos.';
    try {
      await action();
    } catch (_) {
      message = 'Não foi possível concluir a limpeza.';
    } finally {
      if (mounted) {
        setState(() => clearing = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(message)));
      }
    }
  }

  void showShortcutsDialog() {
    final command = Theme.of(context).platform == TargetPlatform.macOS;
    final prefix = command ? '⌘' : 'Ctrl';

    final shortcuts = [
      ('$prefix + T', 'Nova aba'),
      ('$prefix + Shift + T', 'Reabrir aba fechada'),
      ('$prefix + W', 'Fechar aba atual'),
      ('$prefix + L', 'Focar na barra de endereço'),
      ('$prefix + R ou F5', 'Recarregar página'),
      ('$prefix + F', 'Localizar na página'),
      ('$prefix + Shift + N', 'Nova Guia Anônima'),
      ('$prefix + D', 'Adicionar/remover favoritos'),
      ('$prefix + H', 'Abrir histórico'),
      ('$prefix + U', 'Exibir código-fonte'),
      ('$prefix + M', 'Silenciar/Desilenciar aba'),
      ('$prefix + Shift + P', 'Fixar/Desafixar aba'),
      ('$prefix + (+ / -)', 'Aumentar ou diminuir zoom'),
      ('$prefix + 0', 'Redefinir zoom para 100%'),
      ('Esc', 'Fechar barra de pesquisa na página'),
    ];

    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.keyboard_rounded, color: Color(0xFF2563EB)),
            SizedBox(width: 10),
            Text('Atalhos de teclado'),
          ],
        ),
        content: SizedBox(
          width: 440,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (final (key, action) in shortcuts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(action, style: const TextStyle(fontSize: 13.5)),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: Theme.of(context)
                                .colorScheme
                                .surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            key,
                            style: const TextStyle(
                              fontFamily: 'monospace',
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
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

  Future<void> chooseRuntime() async {
    var folder = browser.fixedRuntimePath ?? '';
    final result = await showDialog<({String? folder})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Runtime do WebView2'),
        scrollable: true,
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Use o Evergreen instalado no Windows ou informe a pasta extraída de um WebView2 Fixed Version. A alteração é aplicada ao reabrir o navegador.',
            ),
            const SizedBox(height: 12),
            TextFormField(
              initialValue: folder,
              decoration: const InputDecoration(
                labelText: 'Pasta do Fixed Version',
              ),
              onChanged: (value) => folder = value.trim(),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const BrowserText('Cancelar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, (folder: null as String?)),
            child: const Text('Usar Evergreen'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, (folder: folder)),
            child: const Text('Usar pasta'),
          ),
        ],
      ),
    );
    if (!mounted || result == null) return;
    final path = result.folder;
    var message = 'Runtime selecionado. Feche e reabra o navegador.';
    try {
      if (path != null && !await browser.engine.isFixedRuntimeFolder(path)) {
        message = 'Informe a pasta que contém msedgewebview2.exe e msedge.dll.';
      } else {
        await browser.setFixedRuntimePath(path);
      }
    } catch (_) {
      message = 'Não foi possível salvar a escolha do runtime.';
    }
    if (mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(message)));
    }
  }

  void showWhitelistDialog() {
    showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final list = browser.data.adBlockWhitelist;
          return AlertDialog(
            title: const Text('Sites Permitidos (Whitelist)'),
            content: SizedBox(
              width: 400,
              child: list.isEmpty
                  ? const Text(
                      'Nenhum site na lista de permissões. Todas as páginas contam com proteção ativa.',
                    )
                  : ListView.builder(
                      shrinkWrap: true,
                      itemCount: list.length,
                      itemBuilder: (ctx, idx) {
                        final host = list[idx];
                        return ListTile(
                          dense: true,
                          title: Text(host),
                          trailing: IconButton(
                            icon: const Icon(
                              Icons.delete_outline_rounded,
                              size: 18,
                            ),
                            onPressed: () {
                              browser.toggleWhitelistHost(host);
                              setDialogState(() {});
                            },
                          ),
                        );
                      },
                    ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const BrowserText('Fechar'),
              ),
            ],
          );
        },
      ),
    );
  }

  void showEngine() {
    final result = browser.canInspectPage ? browser.inspectCurrentPage() : null;
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Compatibilidade da página'),
        content: SizedBox(
          width: 440,
          child: result == null
              ? const Text(
                  'Abra uma página e aguarde o carregamento para verificar os recursos.',
                )
              : FutureBuilder<Map<String, bool>>(
                  future: result,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return const Text(
                        'Não foi possível verificar os recursos desta página.',
                      );
                    }
                    final capabilities = snapshot.data;
                    if (capabilities == null) {
                      return const LinearProgressIndicator();
                    }
                    return SingleChildScrollView(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'APIs detectadas no documento atual. A execução pode depender de permissões, hardware e políticas do site.',
                          ),
                          for (final entry in capabilities.entries)
                            ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              leading: Icon(
                                entry.value
                                    ? Icons.check_circle_outline
                                    : Icons.remove_circle_outline,
                              ),
                              title: Text(entry.key),
                              subtitle: Text(
                                entry.value ? 'Detectado' : 'Indisponível',
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

  Future<void> editStartupPages() async {
    var input = browser.startupPages.join('\n');
    final form = GlobalKey<FormState>();
    final pages = await showDialog<List<String>>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Páginas de inicialização'),
        scrollable: true,
        content: Form(
          key: form,
          child: TextFormField(
            initialValue: input,
            minLines: 4,
            maxLines: 8,
            decoration: const InputDecoration(
              labelText: 'Um endereço HTTP ou HTTPS por linha',
              hintText: 'https://example.org',
            ),
            onChanged: (value) => input = value,
            validator: (value) {
              final lines = (value ?? '')
                  .split('\n')
                  .map((line) => line.trim());
              for (final line in lines.where((line) => line.isNotEmpty)) {
                final uri = Uri.tryParse(line);
                if (uri == null ||
                    !BrowserData.isWeb(uri) ||
                    line.contains(RegExp(r'\s'))) {
                  return 'Revise os endereços informados.';
                }
              }
              return null;
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              if (!form.currentState!.validate()) return;
              final urls = {
                for (final line in input.split('\n'))
                  if (line.trim().isNotEmpty) Uri.parse(line.trim()).toString(),
              };
              Navigator.pop(context, urls.toList());
            },
            child: const Text('Salvar'),
          ),
        ],
      ),
    );
    if (mounted && pages != null) await browser.setStartupPages(pages);
  }

  Widget section(BuildContext context, String title, List<Widget> options) =>
      Card(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
              child: Text(
                title,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ...options,
          ],
        ),
      );

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: WindowService.isMacOS
          ? const Padding(
              padding: EdgeInsets.only(left: 78.0),
              child: BackButton(),
            )
          : null,
      leadingWidth: WindowService.isMacOS ? 126.0 : null,
      title: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onPanStart: (_) => WindowService.startDragging(),
        onDoubleTap: () => WindowService.maximize(),
        child: SizedBox(
          width: double.infinity,
          height: kToolbarHeight,
          child: const Align(
            alignment: Alignment.centerLeft,
            child: BrowserText('Configurações'),
          ),
        ),
      ),
      actions: [
        if (WindowService.isDesktop && !WindowService.isMacOS)
          const WindowCaptionControls(height: kToolbarHeight),
      ],
    ),
    body: ListenableBuilder(
      listenable: browser,
      builder: (context, _) => Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.fromLTRB(12, 8, 12, 24),
            children: [
              LanguageTile(browser: browser),
              section(context, 'Navegação', [
                SearchEngineTile(browser: browser),
                ListTile(
                  leading: const Icon(Icons.home_outlined),
                  title: const BrowserText('Página inicial'),
                  subtitle: Text(
                    browser.data.home ?? 'Nenhuma página definida',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  onTap: editHome,
                  trailing: browser.data.home == null
                      ? null
                      : IconButton(
                          tooltip: 'Remover página inicial',
                          onPressed: () => browser.setHome(null),
                          icon: const Icon(Icons.close),
                        ),
                ),
              ]),

              section(context, 'Privacidade, AdBlock & Anti-Rastreio', [
                SwitchListTile(
                  secondary: const Icon(
                    Icons.shield_rounded,
                    color: Colors.green,
                  ),
                  title: const Text('Bloqueador de anúncios (AdBlock)'),
                  subtitle: const Text(
                    'Bloqueia banners, popups e anúncios invasivos, colapsando espaços vazios.',
                  ),
                  value: browser.data.adBlockEnabled,
                  onChanged: (val) {
                    browser.toggleAdBlock(val);
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.track_changes_rounded,
                    color: Colors.blue,
                  ),
                  title: const Text('Sistema Anti-Rastreio (Anti-Tracking)'),
                  subtitle: const Text(
                    'Impede rastreadores de telemetria, beacons e pixels de registrar sua navegação.',
                  ),
                  value: browser.data.antiTrackingEnabled,
                  onChanged: (val) {
                    browser.toggleAntiTracking(val);
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.fingerprint_rounded,
                    color: Colors.purple,
                  ),
                  title: const Text('Proteção Anti-Fingerprint'),
                  subtitle: const Text(
                    'Neutraliza técnicas de identificação única via Canvas e Áudio sem quebrar os sites.',
                  ),
                  value: browser.data.antiFingerprintEnabled,
                  onChanged: (val) {
                    browser.toggleAntiFingerprint(val);
                    setState(() {});
                  },
                ),
                SwitchListTile(
                  secondary: const Icon(
                    Icons.link_off_rounded,
                    color: Colors.amber,
                  ),
                  title: const Text('Limpeza de parâmetros de URL'),
                  subtitle: const Text(
                    'Remove identificadores de clique e rastreamento das URLs (utm_*, fbclid, gclid, etc.).',
                  ),
                  value: browser.data.stripTrackingParams,
                  onChanged: (val) {
                    browser.toggleStripTrackingParams(val);
                    setState(() {});
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.rule_folder_outlined),
                  title: const Text('Sites permitidos (Whitelist)'),
                  subtitle: Text(
                    '${browser.data.adBlockWhitelist.length} sites com bloqueador pausado',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: showWhitelistDialog,
                ),
                ListTile(
                  leading: const Icon(Icons.insights_rounded),
                  title: const Text('Estatísticas de Proteção'),
                  subtitle: Text(
                    '${browser.data.totalBlockedAds} anúncios e ${browser.data.totalBlockedTrackers} rastreadores bloqueados.',
                  ),
                  trailing: TextButton(
                    onPressed: () {
                      browser.clearBlockStats();
                      setState(() {});
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Estatísticas de bloqueio zeradas.'),
                        ),
                      );
                    },
                    child: const Text('Zerar'),
                  ),
                ),
              ]),

              section(context, 'Desempenho e Economia de Memória', [
                SwitchListTile(
                  secondary: const Icon(Icons.speed_rounded),
                  title: const Text('Economizador de memória'),
                  subtitle: const Text(
                    'Permite suspender abas inativas para liberar memória RAM e reduzir uso de CPU.',
                  ),
                  value: browser.data.memorySaver,
                  onChanged: (val) {
                    setState(() => browser.data.memorySaver = val);
                    browser.data.preferences.setBool('memorySaver', val);
                  },
                ),
              ]),

              section(context, 'Mídia e Vídeo (Picture-in-Picture)', [
                SwitchListTile(
                  secondary: const Icon(Icons.picture_in_picture_alt_rounded),
                  title: const Text('Picture-in-Picture Automático'),
                  subtitle: const Text(
                    'Ativa o PiP automaticamente ao sair da aba com vídeo e desativa ao voltar para a página.',
                  ),
                  value: browser.data.autoPiPEnabled,
                  onChanged: (val) {
                    setState(() => browser.data.autoPiPEnabled = val);
                    browser.setAutoPiPEnabled(val);
                  },
                ),
              ]),

              section(context, 'Modo Leitura (Reader Mode)', [
                ListTile(
                  leading: const Icon(Icons.chrome_reader_mode_outlined),
                  title: const Text('Tema do modo leitura'),
                  trailing: DropdownButton<String>(
                    value: browser.data.readerTheme,
                    items: const [
                      DropdownMenuItem(
                        value: 'sepia',
                        child: Text('Sépia (Conforto)'),
                      ),
                      DropdownMenuItem(
                        value: 'light',
                        child: Text('Papel Claro'),
                      ),
                      DropdownMenuItem(
                        value: 'dark',
                        child: BrowserText('Escuro'),
                      ),
                      DropdownMenuItem(
                        value: 'oled',
                        child: Text('OLED Preto'),
                      ),
                    ],
                    onChanged: (val) {
                      if (val != null) browser.setReaderTheme(val);
                    },
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.format_size_rounded),
                  title: const Text('Tamanho da fonte'),
                  subtitle: Slider(
                    value: browser.data.readerFontSize,
                    min: 14.0,
                    max: 26.0,
                    divisions: 6,
                    label: '${browser.data.readerFontSize.round()} px',
                    onChanged: (val) => browser.setReaderFontSize(val),
                  ),
                  trailing: Text(
                    '${browser.data.readerFontSize.round()} px',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
              ]),

              section(context, 'Aparência e Personalização', [
                ThemeTile(browser: browser),
                SwitchListTile(
                  secondary: const Icon(Icons.nightlight_round),
                  title: const Text('Forçar modo escuro na web'),
                  subtitle: const Text(
                    'Aplica inversão inteligente e alto contraste nas páginas para navegação noturna confortável.',
                  ),
                  value: browser.forceWebDarkNotifier.value,
                  onChanged: (val) => browser.setForceWebDarkMode(val),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                  child: Row(
                    children: [
                      const Icon(Icons.palette_outlined, size: 22),
                      const SizedBox(width: 16),
                      Text(
                        'Cor de destaque: ${browser.accentNotifier.value.label}',
                        style: const TextStyle(fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: [
                      for (final accent in BrowserAccent.values)
                        InkWell(
                          onTap: () => browser.setAccent(accent),
                          borderRadius: BorderRadius.circular(20),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            width: 36,
                            height: 36,
                            decoration: BoxDecoration(
                              color: Color(accent.argb),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: browser.accentNotifier.value == accent
                                    ? Theme.of(context).colorScheme.onSurface
                                    : Colors.transparent,
                                width: 2.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Color(accent.argb)
                                      .withValues(alpha: 0.35),
                                  blurRadius: 6,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: browser.accentNotifier.value == accent
                                ? const Icon(
                                    Icons.check,
                                    size: 20,
                                    color: Colors.white,
                                  )
                                : null,
                          ),
                        ),
                    ],
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.rounded_corner_rounded),
                  title: const Text('Arredondamento das bordas'),
                  subtitle: Slider(
                    value: browser.cornerRadiusNotifier.value,
                    min: 4.0,
                    max: 24.0,
                    divisions: 10,
                    label: '${browser.cornerRadiusNotifier.value.round()} px',
                    onChanged: (val) => browser.setCornerRadius(val),
                  ),
                  trailing: Text(
                    '${browser.cornerRadiusNotifier.value.round()} px',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.vertical_split_outlined),
                  title: const BrowserText('Abas na lateral'),
                  value: browser.verticalTabs,
                  onChanged: browser.setVerticalTabs,
                ),
                if (browser.verticalTabs)
                  SwitchListTile(
                    secondary: const Icon(Icons.align_horizontal_right),
                    title: const BrowserText('Barra lateral à direita'),
                    value: browser.sidebarOnRight,
                    onChanged: browser.setSidebarOnRight,
                  ),
                if (browser.verticalTabs)
                  SwitchListTile(
                    secondary: const Icon(Icons.view_sidebar_outlined),
                    title: const BrowserText('Barra lateral compacta'),
                    value: browser.compactTabs,
                    onChanged: (_) => browser.toggleCompactTabs(),
                  ),
              ]),

              section(context, 'Barra lateral de ferramentas', [
                SwitchListTile(
                  title: const Text('Mostrar barra lateral de ferramentas'),
                  subtitle: const Text(
                    'Disponível no desktop. As abas verticais têm um controle próprio.',
                  ),
                  value: browser.showToolsDock,
                  onChanged: browser.setShowToolsDock,
                ),
                if (browser.showToolsDock)
                  for (final tool in BrowserToolsDock.tools.entries)
                    SwitchListTile(
                      title: Text(tool.value),
                      value: browser.showsDockTool(tool.key),
                      onChanged: (value) =>
                          browser.setDockToolVisible(tool.key, value),
                    ),
              ]),
              section(context, 'Nova aba e inicialização', [
                ListTile(
                  leading: const Icon(Icons.restore),
                  title: const Text('Ao iniciar'),
                  subtitle: DropdownButton<StartupMode>(
                    isExpanded: true,
                    value: browser.startupMode,
                    items: [
                      for (final mode in StartupMode.values)
                        DropdownMenuItem(value: mode, child: Text(mode.label)),
                    ],
                    onChanged: (mode) {
                      if (mode != null) browser.setStartupMode(mode);
                    },
                  ),
                ),
                if (browser.startupMode == StartupMode.pages)
                  ListTile(
                    leading: const Icon(Icons.list_alt),
                    title: const Text('Páginas escolhidas'),
                    subtitle: Text(
                      browser.startupPages.isEmpty
                          ? 'Adicione os endereços para abrir ao iniciar.'
                          : browser.startupPages.join('\n'),
                    ),
                    onTap: editStartupPages,
                  ),
                SwitchListTile(
                  secondary: const Icon(Icons.bookmarks_outlined),
                  title: const BrowserText('Mostrar acesso rápido na nova aba'),
                  value: browser.showStartFavorites,
                  onChanged: browser.setShowStartFavorites,
                ),
                SwitchListTile(
                  secondary: const Icon(Icons.history),
                  title: const BrowserText(
                    'Mostrar sites recentes na nova aba',
                  ),
                  value: browser.showStartRecent,
                  onChanged: browser.setShowStartRecent,
                ),
              ]),

              section(context, 'Produtividade e Atalhos', [
                ListTile(
                  leading: const Icon(Icons.help_outline),
                  title: const Text('Rever guia de boas-vindas'),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (context) => WelcomePage(
                        browser: browser,
                        onContinue: () => Navigator.of(context).pop(),
                      ),
                    ),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.download_rounded),
                  title: const BrowserText('Central de Downloads'),
                  subtitle: Text(
                    '${browser.data.downloads.length} downloads no histórico',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => LibraryModal.show(
                    context,
                    browser: browser,
                    initialIndex: 3,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.star_rounded),
                  title: const Text('Favoritos (Importar / Exportar HTML)'),
                  subtitle: Text(
                    '${browser.data.favorites.length} favoritos salvos',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => LibraryModal.show(
                    context,
                    browser: browser,
                    initialIndex: 0,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.keyboard_rounded),
                  title: const Text('Atalhos de teclado'),
                  subtitle: const Text(
                    'Ver lista de combinações e ações rápidas',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: showShortcutsDialog,
                ),
                ListTile(
                  leading: const Icon(Icons.menu_book_rounded),
                  title: const Text('Lista de Leitura ("Ler Depois")'),
                  subtitle: Text(
                    '${browser.data.readingList.length} itens salvos',
                  ),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => LibraryModal.show(
                    context,
                    browser: browser,
                    initialIndex: 2,
                  ),
                ),
              ]),

              section(context, 'Motor de navegação', [
                ListTile(
                  leading: const Icon(Icons.language),
                  title: Text(browser.engine.name),
                  subtitle: browser.engineVersion == null
                      ? null
                      : Text('Runtime ${browser.engineVersion}'),
                ),
                if (browser.engine.usesWebView2)
                  ListTile(
                    leading: const Icon(Icons.settings_suggest_outlined),
                    title: const Text('Escolher runtime do WebView2'),
                    subtitle: Text(
                      browser.fixedRuntimePath ?? 'Evergreen do sistema',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    onTap: chooseRuntime,
                  ),
                ListTile(
                  leading: const Icon(Icons.fact_check_outlined),
                  title: const Text('Verificar compatibilidade da página'),
                  onTap: showEngine,
                ),
              ]),

              section(context, 'Complementos', [
                ListTile(
                  leading: const Icon(Icons.extension_outlined),
                  title: const BrowserText('Gerenciar extensões e scripts'),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () => Navigator.of(context).push<void>(
                    MaterialPageRoute(
                      builder: (_) => BrowserAddons(browser: browser),
                    ),
                  ),
                ),
              ]),

              section(context, 'Privacidade e dados', [
                SwitchListTile(
                  secondary: const Icon(Icons.history),
                  title: const BrowserText('Salvar histórico'),
                  subtitle: const Text(
                    'Ao desativar, as visitas futuras deixam de aparecer no histórico.',
                  ),
                  value: browser.savesHistory,
                  onChanged: browser.setSavesHistory,
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline),
                  title: const BrowserText('Limpar histórico'),
                  enabled: !clearing && browser.data.history.isNotEmpty,
                  onTap: () => confirmClear(
                    'Limpar histórico?',
                    'As páginas visitadas serão removidas do histórico.',
                    browser.clearHistory,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.cookie_outlined),
                  title: const BrowserText('Limpar cookies'),
                  enabled: !clearing,
                  onTap: () => confirmClear(
                    'Limpar cookies?',
                    'Você pode sair das suas contas nos sites.',
                    browser.clearCookies,
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.cached),
                  title: const BrowserText('Limpar cache'),
                  enabled: !clearing,
                  onTap: () => confirmClear(
                    'Limpar cache?',
                    'Os arquivos em cache do motor de navegação serão removidos.',
                    browser.clearCache,
                  ),
                ),
                if (clearing) const LinearProgressIndicator(),
              ]),
            ],
          ),
        ),
      ),
    ),
  );
}
