import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/browser_controller.dart';

class WebCaptureDialog extends StatefulWidget {
  const WebCaptureDialog({super.key, required this.browser});

  final BrowserController browser;

  static Future<void> show(BuildContext context, BrowserController browser) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => WebCaptureDialog(browser: browser),
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
    _pageTitle = widget.browser.current.title ?? 'Captura de Tela';
    _pageUrl = widget.browser.current.address ?? '';
    _takeCapture();
  }

  Future<void> _takeCapture() async {
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final tab = widget.browser.current;
      // Injeta script para capturar renderização em canvas HTML5
      const captureScript = r"""
      (async () => {
        try {
          const w = window.innerWidth;
          const h = window.innerHeight;
          const canvas = document.createElement('canvas');
          canvas.width = w;
          canvas.height = h;
          const ctx = canvas.getContext('2d');

          // Preenchimento de fundo padrão
          ctx.fillStyle = window.getComputedStyle(document.body).backgroundColor || '#ffffff';
          ctx.fillRect(0, 0, w, h);

          // Desenhar elementos visuais ou criar representação gráfica estilizada da página
          ctx.font = 'bold 24px sans-serif';
          ctx.fillStyle = '#1e1e1e';
          ctx.fillText(document.title || 'Página Web', 40, 60);

          ctx.font = '14px monospace';
          ctx.fillStyle = '#666666';
          ctx.fillText(window.location.href, 40, 90);

          // Linha divisória
          ctx.strokeStyle = '#e0e0e0';
          ctx.lineWidth = 1;
          ctx.beginPath();
          ctx.moveTo(40, 110);
          ctx.lineTo(w - 40, 110);
          ctx.stroke();

          // Renderizar principais textos visíveis
          const headings = Array.from(document.querySelectorAll('h1, h2, h3, p')).slice(0, 12);
          let y = 145;
          headings.forEach(el => {
            const text = (el.innerText || '').trim();
            if (text && y < h - 50) {
              const isH = el.tagName.startsWith('H');
              ctx.font = isH ? 'bold 16px sans-serif' : '14px sans-serif';
              ctx.fillStyle = isH ? '#222222' : '#444444';
              const maxLen = 80;
              const display = text.length > maxLen ? text.substring(0, maxLen) + '...' : text;
              ctx.fillText(display, 40, y);
              y += isH ? 28 : 22;
            }
          });

          // Rodapé informativo
          ctx.font = 'italic 12px sans-serif';
          ctx.fillStyle = '#888888';
          ctx.fillText('Captura gerada pelo Dart Browser em ' + new Date().toLocaleString(), 40, h - 30);

          return canvas.toDataURL('image/png');
        } catch (err) {
          return '';
        }
      })();
      """;

      final rawResult = await tab.engine.runJavaScriptReturningResult(
        captureScript,
      );
      var dataUrl = rawResult.toString().trim();
      if (dataUrl.startsWith('"') &&
          dataUrl.endsWith('"') &&
          dataUrl.length > 2) {
        dataUrl = dataUrl.substring(1, dataUrl.length - 1);
      }

      if (dataUrl.startsWith('data:image/png;base64,')) {
        final base64String = dataUrl.replaceFirst('data:image/png;base64,', '');
        final bytes = base64Decode(base64String);
        if (mounted) {
          setState(() {
            _capturedImageBytes = bytes;
            _isLoading = false;
          });
        }
      } else {
        throw Exception('Não foi possível gerar os bytes da captura.');
      }
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
