import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/browser_controller.dart';

class WebCaptureDialog extends StatefulWidget {
  const WebCaptureDialog({
    super.key,
    required this.browser,
    required this.tab,
    required this.initialCapture,
  });

  final BrowserController browser;
  final BrowserTab tab;
  final Future<Uint8List?> initialCapture;

  static Future<void> show(BuildContext context, BrowserController browser) {
    final tab = browser.current;
    if (tab.address == null ||
        tab.initialization == null ||
        tab.progress < 100 ||
        tab.error != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Abra uma página e aguarde o carregamento para capturá-la.',
          ),
        ),
      );
      return Future<void>.value();
    }
    final capture = Future<Uint8List?>.sync(tab.engine.takeScreenshot);
    return showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (_) =>
          WebCaptureDialog(browser: browser, tab: tab, initialCapture: capture),
    );
  }

  @override
  State<WebCaptureDialog> createState() => _WebCaptureDialogState();
}

class _WebCaptureDialogState extends State<WebCaptureDialog> {
  bool _isLoading = true;
  String? _errorMessage;
  Uint8List? _capturedImageBytes;
  String _pageTitle = '';
  String _pageUrl = '';

  @override
  void initState() {
    super.initState();
    _pageTitle = widget.tab.title ?? 'Captura de Tela';
    _pageUrl = widget.tab.address ?? '';
    _takeCapture(widget.initialCapture);
  }

  Future<void> _takeCapture([Future<Uint8List?>? initial]) async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tab = widget.tab;
      if (!identical(tab, widget.browser.current) || tab.address != _pageUrl) {
        throw StateError('A página mudou. Abra a captura novamente.');
      }
      final bytes = await (initial ?? tab.engine.takeScreenshot());
      if (!mounted) return;
      setState(() {
        _capturedImageBytes = bytes;
        _isLoading = false;
        if (bytes == null || bytes.isEmpty) {
          _capturedImageBytes = null;
          _errorMessage = 'O motor de navegação não disponibilizou uma captura desta página.';
        }
      });
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Falha ao capturar a página: $e';
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _copyToClipboard() async {
    if (_capturedImageBytes == null) return;
    try {
      // Copiar imagem ou link e status
      await Clipboard.setData(
        ClipboardData(
          text: '$_pageTitle\n$_pageUrl\n[Captura salva no Dart Browser]',
        ),
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Dados da captura copiados para a área de transferência!',
            ),
          ),
        );
      }
    } catch (_) {}
  }

  Future<void> _saveToFile() async {
    if (_capturedImageBytes == null) return;
    try {
      final fileName =
          'DartBrowser_Screenshot_${DateTime.now().millisecondsSinceEpoch}.png';

      // Salva no diretório padrão de downloads do usuário ou diretório temporário
      Directory? targetDir;
      if (Platform.isWindows) {
        final userProfile = Platform.environment['USERPROFILE'];
        if (userProfile != null) {
          final downloadsDir = Directory('$userProfile\\Downloads');
          if (downloadsDir.existsSync()) targetDir = downloadsDir;
        }
      }

      targetDir ??= Directory.systemTemp;
      final file = File('${targetDir.path}/$fileName');
      await file.writeAsBytes(_capturedImageBytes!);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Captura salva com sucesso em:\n${file.path}'),
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Erro ao salvar imagem: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 720, maxHeight: 600),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Cabeçalho
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: colors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      Icons.camera_alt_rounded,
                      color: colors.primary,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Captura de Tela da Web',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          _pageTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
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
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 16),

              // Visualização da Imagem
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.4),
                    ),
                  ),
                  child: _isLoading
                      ? const Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 12),
                              Text('Renderizando captura de tela...'),
                            ],
                          ),
                        )
                      : _errorMessage != null
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.error_outline_rounded,
                                size: 36,
                                color: Colors.red,
                              ),
                              const SizedBox(height: 8),
                              Text(_errorMessage!),
                              const SizedBox(height: 12),
                              FilledButton.tonal(
                                onPressed: _takeCapture,
                                child: const Text('Tentar Novamente'),
                              ),
                            ],
                          ),
                        )
                      : ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: InteractiveViewer(
                            maxScale: 4.0,
                            minScale: 0.5,
                            child: Center(
                              child: Image.memory(
                                _capturedImageBytes!,
                                fit: BoxFit.contain,
                              ),
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 16),

              // Ações no rodapé
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Recapturar'),
                    onPressed: _isLoading ? null : _takeCapture,
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.copy_rounded, size: 16),
                    label: const Text('Copiar'),
                    onPressed: _capturedImageBytes == null
                        ? null
                        : _copyToClipboard,
                  ),
                  const SizedBox(width: 8),
                  FilledButton.icon(
                    icon: const Icon(Icons.download_rounded, size: 16),
                    label: const Text('Salvar PNG'),
                    onPressed: _capturedImageBytes == null ? null : _saveToFile,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
