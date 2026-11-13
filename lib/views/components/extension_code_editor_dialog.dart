import '../../l10n/browser_text.dart';

import 'package:flutter/material.dart';

import '../../models/chrome_extension.dart';

class ExtensionCodeEditorDialog extends StatefulWidget {
  const ExtensionCodeEditorDialog({
    super.key,
    required this.extension,
    required this.onSave,
  });

  final ChromeExtension extension;
  final ValueChanged<ChromeExtension> onSave;

  static Future<void> show(
    BuildContext context, {
    required ChromeExtension extension,
    required ValueChanged<ChromeExtension> onSave,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) =>
          ExtensionCodeEditorDialog(extension: extension, onSave: onSave),
    );
  }

  @override
  State<ExtensionCodeEditorDialog> createState() =>
      _ExtensionCodeEditorDialogState();
}

class _ExtensionCodeEditorDialogState extends State<ExtensionCodeEditorDialog>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late TextEditingController _jsController;
  late TextEditingController _nameController;
  late TextEditingController _matchController;
  late TextEditingController _popupController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _jsController = TextEditingController(text: widget.extension.source);
    _nameController = TextEditingController(text: widget.extension.name);
    _matchController = TextEditingController(
      text: widget.extension.matches.isNotEmpty
          ? widget.extension.matches.first
          : '<all_urls>',
    );
    _popupController = TextEditingController(
      text: widget.extension.actionPopup ?? '',
    );
  }

  @override
  void dispose() {
    _tabController.dispose();
    _jsController.dispose();
    _nameController.dispose();
    _matchController.dispose();
    _popupController.dispose();
    super.dispose();
  }

  void _save() {
    final updated = widget.extension.copyWith(
      name: _nameController.text.trim(),
      source: _jsController.text,
      matches: [_matchController.text.trim()],
      actionPopup: _popupController.text.trim().isNotEmpty
          ? _popupController.text.trim()
          : null,
    );
    widget.onSave(updated);
    Navigator.pop(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Extensão "${updated.name}" atualizada com sucesso!'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: SizedBox(
        width: isMobile ? double.infinity : 720,
        height: isMobile ? MediaQuery.sizeOf(context).height * 0.85 : 580,
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
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
                      Icons.code_rounded,
                      color: colors.primary,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.extension.name,
                          style: const TextStyle(
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'ID: ${widget.extension.id} • v${widget.extension.version}',
                          style: TextStyle(
                            fontSize: 12,
                            color: colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
            ),
            TabBar(
              controller: _tabController,
              tabs: const [
                Tab(icon: Icon(Icons.javascript_rounded), text: 'JavaScript'),
                Tab(icon: Icon(Icons.html_rounded), text: 'Popup HTML'),
                Tab(icon: Icon(Icons.tune_rounded), text: 'Configurações'),
              ],
            ),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  // ABA 1: JAVASCRIPT
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _jsController,
                      maxLines: null,
                      expands: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.surfaceContainerLow,
                        hintText: '// Código JavaScript que será injetado na página...',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colors.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ABA 2: POPUP HTML
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: TextField(
                      controller: _popupController,
                      maxLines: null,
                      expands: true,
                      autocorrect: false,
                      enableSuggestions: false,
                      style: const TextStyle(
                        fontFamily: 'monospace',
                        fontSize: 13,
                        height: 1.4,
                      ),
                      decoration: InputDecoration(
                        filled: true,
                        fillColor: colors.surfaceContainerLow,
                        hintText:
                            '<!-- HTML do Popup flutuante da extensão -->',
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(
                            color: colors.outlineVariant.withValues(alpha: 0.4),
                          ),
                        ),
                      ),
                    ),
                  ),

                  // ABA 3: CONFIGURAÇÕES
                  Padding(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        TextField(
                          controller: _nameController,
                          decoration: InputDecoration(
                            labelText: 'Nome da Extensão',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _matchController,
                          decoration: InputDecoration(
                            labelText: 'Padrão de URL correspondente',
                            helperText: 'Ex: <all_urls> ou *://*.youtube.com/*',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Text(
                          'Permissões declaradas: ${widget.extension.permissions.isEmpty ? "Nenhuma" : widget.extension.permissions.join(", ")}',
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
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              color: colors.surfaceContainerLow,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const BrowserText('Cancelar'),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.check_rounded, size: 18),
                    onPressed: _save,
                    label: const Text('Salvar Alterações'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
