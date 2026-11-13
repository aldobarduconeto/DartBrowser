import '../l10n/browser_text.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:webview_all/webview_all.dart';

import '../controllers/browser_controller.dart';
import '../models/chrome_extension.dart';
import '../services/chrome_extension_service.dart';
import '../services/window_service.dart';
import 'components/window_caption_controls.dart';
import 'components/extension_code_editor_dialog.dart';

class ChromeExtensionsView extends StatefulWidget {
  const ChromeExtensionsView({super.key, required this.browser});

  final BrowserController browser;

  @override
  State<ChromeExtensionsView> createState() => _ChromeExtensionsViewState();
}

class _ChromeExtensionsViewState extends State<ChromeExtensionsView>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  bool saving = false;
  bool developerMode = true;
  String searchQuery = '';
  BrowserController get browser => widget.browser;
  ChromeExtensionService get service =>
      ChromeExtensionService(browser.data.preferences);

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> save(List<ChromeExtension> value) async {
    if (!mounted || saving) return;
    setState(() => saving = true);
    try {
      await browser.saveAddons(value);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Não foi possível salvar as extensões.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => saving = false);
    }
  }

  // -------------------------------------------------------------
  // DIÁLOGO UNIVERSAL DE INSTALAÇÃO (TODAS AS PLATAFORMAS)
  // -------------------------------------------------------------

  Future<void> showUniversalInstallerDialog() async {
    int installerTab = 0;
    var userScriptCode = '';
    var manifestJsonCode = '';
    var scriptName = '';
    var scriptPattern = '<all_urls>';
    var scriptJs = '';
    var folderPath = '';

    await showDialog<void>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final colors = Theme.of(ctx).colorScheme;
          final isMobile = MediaQuery.sizeOf(ctx).width < 600;

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: isMobile ? double.infinity : 600,
              height: isMobile ? MediaQuery.sizeOf(ctx).height * 0.85 : 540,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    color: colors.surfaceContainerHigh,
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: colors.primary.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(
                            Icons.add_moderator_rounded,
                            color: colors.primary,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Text(
                            'Instalar Extensão (Universal)',
                            style: TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),

                  // SELETOR DE MODO DE INSTALAÇÃO
                  Container(
                    width: double.infinity,
                    color: colors.surfaceContainerLow,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      child: SegmentedButton<int>(
                        segments: const [
                          ButtonSegment(
                            value: 0,
                            icon: Icon(Icons.javascript_rounded, size: 16),
                            label: Text('UserScript'),
                          ),
                          ButtonSegment(
                            value: 1,
                            icon: Icon(Icons.code_rounded, size: 16),
                            label: Text('Manifesto'),
                          ),
                          ButtonSegment(
                            value: 2,
                            icon: Icon(Icons.edit_note_rounded, size: 16),
                            label: Text('Personalizado'),
                          ),
                          ButtonSegment(
                            value: 3,
                            icon: Icon(Icons.folder_zip_rounded, size: 16),
                            label: Text('CRX / Web Store'),
                          ),
                        ],
                        selected: {installerTab},
                        onSelectionChanged: (val) =>
                            setDialogState(() => installerTab = val.first),
                      ),
                    ),
                  ),

                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: IndexedStack(
                        index: installerTab,
                        children: [
                          // 0: USERSCRIPT
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cole o código de um script (GreasyFork, GitHub ou Tampermonkey):',
                                style: TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: TextField(
                                  maxLines: null,
                                  expands: true,
                                  onChanged: (v) => userScriptCode = v,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '// ==UserScript==\n// @name Meu Script\n// @match *://*/*\n// ==/UserScript==\n\nconsole.log("Olá!");',
                                    filled: true,
                                    fillColor: colors.surfaceContainerLow,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // 1: MANIFESTO JSON
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Cole o JSON do manifest.json da extensão:',
                                style: TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 12),
                              Expanded(
                                child: TextField(
                                  maxLines: null,
                                  expands: true,
                                  onChanged: (v) => manifestJsonCode = v,
                                  autocorrect: false,
                                  enableSuggestions: false,
                                  style: const TextStyle(
                                    fontFamily: 'monospace',
                                    fontSize: 12,
                                  ),
                                  decoration: InputDecoration(
                                    hintText: '{\n  "manifest_version": 3,\n  "name": "Minha Extensão",\n  "version": "1.0",\n  "permissions": ["storage"]\n}',
                                    filled: true,
                                    fillColor: colors.surfaceContainerLow,
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                ),
                              ),
                            ],
                          ),

                          // 2: PERSONALIZADO
                          SingleChildScrollView(
                            child: Column(
                              children: [
                                TextField(
                                  decoration: InputDecoration(
                                    labelText: 'Nome da Extensão',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onChanged: (v) => scriptName = v,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  decoration: InputDecoration(
                                    labelText: 'Padrão de URL',
                                    hintText: '<all_urls> ou *://*.site.com/*',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  controller: TextEditingController(
                                    text: scriptPattern,
                                  ),
                                  onChanged: (v) => scriptPattern = v,
                                ),
                                const SizedBox(height: 12),
                                TextField(
                                  minLines: 4,
                                  maxLines: 8,
                                  decoration: InputDecoration(
                                    labelText: 'Código JavaScript',
                                    hintText: '// Código a ser executado na página...',
                                    border: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onChanged: (v) => scriptJs = v,
                                ),
                              ],
                            ),
                          ),

                          // 3: PASTA LOCAL, CRX OU WEB STORE
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                isMobile
                                    ? 'Cole o link da Chrome Web Store, ID ou URL de arquivo .crx/.zip:'
                                    : 'Informe o caminho de uma pasta, arquivo .crx/.zip ou URL/ID da Chrome Web Store:',
                                style: const TextStyle(fontSize: 13),
                              ),
                              const SizedBox(height: 16),
                              TextField(
                                decoration: InputDecoration(
                                  labelText: isMobile
                                      ? 'Link da Web Store ou URL CRX'
                                      : 'Caminho da Pasta, Arquivo CRX ou Link da Web Store',
                                  hintText: isMobile
                                      ? 'Ex: https://chromewebstore.google.com/detail/... ou ID'
                                      : r'C:\...\extensao.crx ou https://chromewebstore.google.com/detail/...',
                                  prefixIcon: const Icon(
                                    Icons.extension_rounded,
                                  ),
                                  border: OutlineInputBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onChanged: (v) => folderPath = v,
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),

                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 12,
                    ),
                    color: colors.surfaceContainerLow,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const BrowserText('Cancelar'),
                        ),
                        const SizedBox(width: 8),
                        FilledButton.icon(
                          icon: const Icon(
                            Icons.download_done_rounded,
                            size: 18,
                          ),
                          label: const Text('Instalar Agora'),
                          onPressed: () async {
                            ChromeExtension? newExt;
                            String? errorMsg;

                            try {
                              if (installerTab == 0) {
                                newExt = service.importUserScript(
                                  userScriptCode,
                                );
                              } else if (installerTab == 1) {
                                newExt = service.importManifestJson(
                                  manifestJsonCode,
                                );
                              } else if (installerTab == 2) {
                                if (scriptName.trim().isEmpty) {
                                  throw const FormatException(
                                    'Informe o nome da extensão.',
                                  );
                                }
                                final id = scriptName.toLowerCase().replaceAll(
                                  RegExp(r'[^a-z0-9]'),
                                  '_',
                                );
                                newExt = ChromeExtension(
                                  id: id,
                                  name: scriptName.trim(),
                                  version: '1.0.0',
                                  description: 'Script personalizado criado no DartBrowser.',
                                  origin: scriptPattern.trim(),
                                  matches: [scriptPattern.trim()],
                                  source: scriptJs,
                                  enabled: true,
                                  isCustomScript: true,
                                );
                              } else {
                                final path = folderPath.trim();
                                if (path.toLowerCase().endsWith('.crx') ||
                                    path.toLowerCase().endsWith('.zip')) {
                                  if (path.startsWith('http://') ||
                                      path.startsWith('https://')) {
                                    newExt = await widget.browser
                                        .installExtensionFromUrl(path);
                                  } else {
                                    newExt = await service.importCrxFile(path);
                                  }
                                } else if (path.contains(
                                      'chromewebstore.google.com',
                                    ) ||
                                    RegExp(r'^[a-z]{32}$').hasMatch(path)) {
                                  newExt = await widget.browser
                                      .installExtensionFromWebStore(path);
                                } else if (path.startsWith('http://') ||
                                    path.startsWith('https://')) {
                                  newExt = await widget.browser
                                      .installExtensionFromUrl(path);
                                } else {
                                  newExt = await service.importFolder(path);
                                }
                              }
                            } catch (e) {
                              errorMsg = e.toString().replaceFirst(
                                'FormatException: ',
                                '',
                              );
                            }

                            if (errorMsg != null) {
                              if (ctx.mounted) {
                                ScaffoldMessenger.of(ctx).showSnackBar(
                                  SnackBar(
                                    content: Text(errorMsg),
                                    backgroundColor: Colors.red.shade800,
                                  ),
                                );
                              }
                              return;
                            }

                            if (newExt != null && ctx.mounted && mounted) {
                              Navigator.pop(ctx);
                              final existing = browser.addons.indexWhere(
                                (a) => a.id == newExt!.id,
                              );
                              final updated = List<ChromeExtension>.from(
                                browser.addons,
                              );
                              if (existing != -1) {
                                updated[existing] = newExt;
                              } else {
                                updated.add(newExt);
                              }
                              await save(updated);
                              if (mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Extensão "${newExt.name}" instalada e ativada com sucesso!',
                                    ),
                                    backgroundColor: Colors.green.shade800,
                                  ),
                                );
                              }
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // -------------------------------------------------------------
  // BACKUP E RESTAURAÇÃO
  // -------------------------------------------------------------

  Future<void> exportBackup() async {
    final json = service.exportBackup(browser.addons);
    await Clipboard.setData(ClipboardData(text: json));
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Backup de todas as extensões copiado para a área de transferência!',
          ),
        ),
      );
    }
  }

  Future<void> importBackupDialog() async {
    var rawText = '';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.restore_page_rounded, color: Colors.blue),
            SizedBox(width: 10),
            Text('Restaurar Backup de Extensões'),
          ],
        ),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Cole o conteúdo JSON do backup das extensões:',
                style: TextStyle(fontSize: 13),
              ),
              const SizedBox(height: 12),
              TextField(
                maxLines: 8,
                onChanged: (v) => rawText = v,
                decoration: InputDecoration(
                  hintText: '{\n  "version": "1.0",\n  "extensions": [...]\n}',
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const BrowserText('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Restaurar'),
          ),
        ],
      ),
    );

    if (confirmed == true && rawText.trim().isNotEmpty && mounted) {
      try {
        final restored = service.importBackup(rawText);
        await save(restored);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                '${restored.length} extensões restauradas com sucesso!',
              ),
              backgroundColor: Colors.green.shade800,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Falha ao restaurar: $e'),
              backgroundColor: Colors.red.shade800,
            ),
          );
        }
      }
    }
  }

  // -------------------------------------------------------------
  // POPUP VISUALIZADOR MULTIPLATAFORMA (DESKTOP E MOBILE)
  // -------------------------------------------------------------

  void openExtensionPopup(ChromeExtension addon) {
    final html = addon.getPopupHtml();
    if (html == null || html.isEmpty) return;

    final isMobile = MediaQuery.sizeOf(context).width < 600;

    if (isMobile) {
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) {
          final controller = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..loadHtmlString(html);

          return SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.65,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.extension_rounded, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          addon.actionTitle ?? addon.name,
                          style: const TextStyle(fontWeight: FontWeight.bold),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ),
                Expanded(child: WebViewWidget(controller: controller)),
              ],
            ),
          );
        },
      );
    } else {
      showDialog<void>(
        context: context,
        builder: (ctx) {
          final controller = WebViewController()
            ..setJavaScriptMode(JavaScriptMode.unrestricted)
            ..loadHtmlString(html);

          return Dialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(20),
            ),
            clipBehavior: Clip.antiAlias,
            child: SizedBox(
              width: 380,
              height: 500,
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    color: Theme.of(ctx).colorScheme.surfaceContainerHigh,
                    child: Row(
                      children: [
                        const Icon(Icons.extension_rounded, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            addon.actionTitle ?? addon.name,
                            style: const TextStyle(fontWeight: FontWeight.bold),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close_rounded, size: 18),
                          onPressed: () => Navigator.pop(ctx),
                        ),
                      ],
                    ),
                  ),
                  Expanded(child: WebViewWidget(controller: controller)),
                ],
              ),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
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
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: colors.primary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.extension_rounded,
                  color: colors.primary,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Extensões Web',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 18),
              ),
            ],
          ),
        ),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(icon: Icon(Icons.layers_rounded), text: 'Instaladas'),
            Tab(icon: Icon(Icons.storefront_rounded), text: 'Loja / Galeria'),
            Tab(icon: Icon(Icons.tune_rounded), text: 'Ferramentas'),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Exportar Backup',
            icon: const Icon(Icons.cloud_upload_outlined),
            onPressed: exportBackup,
          ),
          IconButton(
            tooltip: 'Restaurar Backup',
            icon: const Icon(Icons.cloud_download_outlined),
            onPressed: importBackupDialog,
          ),
          if (WindowService.isDesktop && !WindowService.isMacOS)
            const WindowCaptionControls(height: kToolbarHeight),
          const SizedBox(width: 4),
        ],
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ABA 1: INSTALADAS
          _buildInstalledTab(colors),

          // ABA 2: LOJA / GALERIA DE EXTENSÕES
          _buildStoreTab(colors),

          // ABA 3: FERRAMENTAS DO DESENVOLVEDOR
          _buildDeveloperToolsTab(colors),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: showUniversalInstallerDialog,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Adicionar Extensão'),
      ),
    );
  }

  // -------------------------------------------------------------
  // ABA 1: LISTA DE EXTENSÕES INSTALADAS
  // -------------------------------------------------------------

  Widget _buildInstalledTab(ColorScheme colors) {
    return ListenableBuilder(
      listenable: browser,
      builder: (context, _) {
        final allAddons = browser.addons;
        final filtered = allAddons.where((addon) {
          if (searchQuery.isEmpty) return true;
          final q = searchQuery.toLowerCase();
          return addon.name.toLowerCase().contains(q) ||
              addon.description.toLowerCase().contains(q) ||
              addon.id.toLowerCase().contains(q);
        }).toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Pesquisar entre ${allAddons.length} extensões...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: searchQuery.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => setState(() => searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: colors.surfaceContainerLow,
                  isDense: true,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                ),
                onChanged: (v) => setState(() => searchQuery = v),
              ),
            ),
            if (filtered.isEmpty)
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.extension_off_rounded,
                        size: 48,
                        color: colors.onSurfaceVariant,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Nenhuma extensão encontrada.',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      TextButton.icon(
                        icon: const Icon(Icons.storefront_rounded),
                        label: const Text('Explorar a Loja de Extensões'),
                        onPressed: () => _tabController.animateTo(1),
                      ),
                    ],
                  ),
                ),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final addon = filtered[index];
                    return _buildExtensionCard(context, addon);
                  },
                ),
              ),
          ],
        );
      },
    );
  }

  // -------------------------------------------------------------
  // ABA 2: LOJA / GALERIA DE EXTENSÕES INTEGRADAS
  // -------------------------------------------------------------

  Widget _buildStoreTab(ColorScheme colors) {
    final presets = ChromeExtensionService.getPopularPresets();

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                colors.primary.withValues(alpha: 0.15),
                colors.secondary.withValues(alpha: 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: colors.primary.withValues(alpha: 0.2)),
          ),
          child: Row(
            children: [
              Icon(Icons.storefront_rounded, size: 36, color: colors.primary),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Loja de Extensões Integrada',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Instale ferramentas completas para produtividade, segurança, modo escuro e vídeo com 1 toque em qualquer plataforma.',
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        for (final preset in presets) ...[
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(
                color: colors.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: colors.primaryContainer.withValues(alpha: 0.4),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Center(
                      child: Text(
                        preset.badgeText ?? '🧩',
                        style: const TextStyle(fontSize: 22),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Text(
                              preset.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: colors.surfaceContainerHighest,
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                'v${preset.version}',
                                style: const TextStyle(fontSize: 10),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          preset.description,
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 10),
                  ListenableBuilder(
                    listenable: browser,
                    builder: (context, _) {
                      final isInstalled = browser.addons.any(
                        (a) => a.id == preset.id,
                      );

                      if (isInstalled) {
                        return FilledButton.tonal(
                          onPressed: null,
                          child: const Text('Instalada'),
                        );
                      }

                      return FilledButton(
                        onPressed: () async {
                          final updated = List<ChromeExtension>.from(
                            browser.addons,
                          )..add(preset.copyWith(enabled: true));
                          await save(updated);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${preset.name} instalada e ativada!',
                                ),
                              ),
                            );
                          }
                        },
                        child: const Text('Instalar'),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ],
    );
  }

  // -------------------------------------------------------------
  // ABA 3: FERRAMENTAS DO DESENVOLVEDOR
  // -------------------------------------------------------------

  Widget _buildDeveloperToolsTab(ColorScheme colors) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        SwitchListTile(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
          ),
          tileColor: colors.surfaceContainerLow,
          title: const Text('Modo do Desenvolvedor'),
          subtitle: const Text(
            'Permite editar o código fonte de qualquer extensão e inspecionar APIs WebExtension.',
          ),
          value: developerMode,
          onChanged: (v) => setState(() => developerMode = v),
        ),
        const SizedBox(height: 16),
        Card(
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: colors.outlineVariant.withValues(alpha: 0.5),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Ações Rápidas de Extensão',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: showUniversalInstallerDialog,
                      icon: const Icon(Icons.add_circle_outline_rounded),
                      label: const Text('Instalar Nova'),
                    ),
                    OutlinedButton.icon(
                      onPressed: () {
                        if (browser.current.address != null) {
                          browser.reload();
                        }
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Scripts e shims recarregados em todas as abas!',
                            ),
                          ),
                        );
                      },
                      icon: const Icon(Icons.refresh_rounded),
                      label: const Text('Recarregar nas Abas'),
                    ),
                    OutlinedButton.icon(
                      onPressed: exportBackup,
                      icon: const Icon(Icons.copy_all_rounded),
                      label: const Text('Copiar Backup JSON'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // CARTÃO DE EXTENSÃO
  // -------------------------------------------------------------

  Widget _buildExtensionCard(BuildContext context, ChromeExtension addon) {
    final colors = Theme.of(context).colorScheme;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: colors.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: addon.enabled
                        ? colors.primary.withValues(alpha: 0.15)
                        : colors.surfaceContainerHighest,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      addon.badgeText ?? '🧩',
                      style: const TextStyle(fontSize: 20),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Flexible(
                            child: Text(
                              addon.name,
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 6),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: colors.surfaceContainerHighest,
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'v${addon.version}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        addon.description.isNotEmpty
                            ? addon.description
                            : 'Manifest V${addon.manifestVersion}',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Switch(
                  value: addon.enabled,
                  onChanged: (_) => browser.toggleAddon(addon),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Divider(
              height: 1,
              color: colors.outlineVariant.withValues(alpha: 0.3),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                IconButton(
                  tooltip: addon.isPinned ? 'Desafixar' : 'Fixar na barra',
                  icon: Icon(
                    addon.isPinned
                        ? Icons.push_pin_rounded
                        : Icons.push_pin_outlined,
                    size: 18,
                    color: addon.isPinned
                        ? colors.primary
                        : colors.onSurfaceVariant,
                  ),
                  onPressed: () => browser.togglePinAddon(addon),
                ),
                if (addon.hasPopup)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.open_in_new_rounded, size: 16),
                    label: const Text('Popup'),
                    onPressed: () => openExtensionPopup(addon),
                  ),
                if (developerMode)
                  TextButton.icon(
                    style: TextButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                    ),
                    icon: const Icon(Icons.code_rounded, size: 16),
                    label: const Text('Código'),
                    onPressed: () {
                      ExtensionCodeEditorDialog.show(
                        context,
                        extension: addon,
                        onSave: (updated) {
                          final list = List<ChromeExtension>.from(
                            browser.addons,
                          );
                          final idx = list.indexWhere(
                            (a) => a.id == updated.id,
                          );
                          if (idx != -1) {
                            list[idx] = updated;
                            save(list);
                          }
                        },
                      );
                    },
                  ),
                const Spacer(),
                IconButton(
                  tooltip: 'Remover extensão',
                  icon: Icon(
                    Icons.delete_outline_rounded,
                    size: 18,
                    color: colors.error,
                  ),
                  onPressed: () => browser.removeAddon(addon),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Aliases para compatibilidade total com código legado
typedef BrowserAddons = ChromeExtensionsView;
