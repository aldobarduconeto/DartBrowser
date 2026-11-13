import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../controllers/browser_controller.dart';

class MediaSnifferDialog extends StatefulWidget {
  const MediaSnifferDialog({super.key, required this.browser});

  final BrowserController browser;

  static void show(BuildContext context, BrowserController browser) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => MediaSnifferDialog(browser: browser),
    );
  }

  @override
  State<MediaSnifferDialog> createState() => _MediaSnifferDialogState();
}

class _MediaSnifferDialogState extends State<MediaSnifferDialog> {
  bool loading = true;
  List<Map<String, dynamic>> mediaItems = [];

  @override
  void initState() {
    super.initState();
    _extractMedia();
  }

  Future<void> _extractMedia() async {
    const script = r"""
      (() => {
        try {
          const items = [];
          const seen = new Set();

          // 1. Imagens
          document.querySelectorAll('img').forEach(img => {
            const src = img.currentSrc || img.src;
            if (src && !src.startsWith('data:') && !seen.has(src)) {
              seen.add(src);
              items.push({
                type: 'image',
                url: src,
                name: img.alt || src.split('/').pop().split('?')[0] || 'Imagem',
                width: img.naturalWidth || 0,
                height: img.naturalHeight || 0
              });
            }
          });

          // 2. Vídeos
          document.querySelectorAll('video, video source').forEach(v => {
            const src = v.src;
            if (src && !seen.has(src)) {
              seen.add(src);
              items.push({
                type: 'video',
                url: src,
                name: src.split('/').pop().split('?')[0] || 'Vídeo'
              });
            }
          });

          // 3. Áudios
          document.querySelectorAll('audio, audio source').forEach(a => {
            const src = a.src;
            if (src && !seen.has(src)) {
              seen.add(src);
              items.push({
                type: 'audio',
                url: src,
                name: src.split('/').pop().split('?')[0] || 'Áudio'
              });
            }
          });

          // 4. Links de download
          const docExtensions = ['.pdf', '.zip', '.rar', '.mp3', '.mp4', '.apk', '.exe', '.docx', '.xlsx', '.csv'];
          document.querySelectorAll('a[href]').forEach(a => {
            const href = a.href;
            if (href && docExtensions.some(ext => href.toLowerCase().endsWith(ext)) && !seen.has(href)) {
              seen.add(href);
              items.push({
                type: 'document',
                url: href,
                name: a.innerText.trim() || href.split('/').pop().split('?')[0] || 'Documento'
              });
            }
          });

          return JSON.stringify(items);
        } catch (e) {
          return '[]';
        }
      })();
    """;

    try {
      final res = await widget.browser.current.engine
          .runJavaScriptReturningResult(script);
      Object? decoded = res;
      if (decoded is String) {
        decoded = jsonDecode(decoded);
        if (decoded is String) decoded = jsonDecode(decoded);
      }
      if (decoded is List) {
        final list = decoded;
        if (mounted) {
          setState(() {
            mediaItems = list
                .map((e) => Map<String, dynamic>.from(e as Map))
                .toList();
            loading = false;
          });
        }
        return;
      }
    } catch (_) {}

    if (mounted) setState(() => loading = false);
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return SizedBox(
      height: MediaQuery.sizeOf(context).height * 0.75,
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: colors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.perm_media_rounded,
                    color: colors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Mídias e Recursos da Página',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        '${mediaItems.length} recursos encontrados nesta aba',
                        style: TextStyle(
                          fontSize: 12,
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: 'Atualizar extração',
                  icon: const Icon(Icons.refresh_rounded),
                  onPressed: () {
                    setState(() => loading = true);
                    _extractMedia();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: loading
                ? const Center(child: CircularProgressIndicator())
                : mediaItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_not_supported_rounded,
                          size: 48,
                          color: colors.onSurfaceVariant,
                        ),
                        const SizedBox(height: 12),
                        const Text('Nenhuma imagem ou mídia encontrada.'),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    itemCount: mediaItems.length,
                    separatorBuilder: (_, _) => const Divider(height: 1),
                    itemBuilder: (context, index) {
                      final item = mediaItems[index];
                      final type = item['type'] as String? ?? 'image';
                      final url = item['url'] as String? ?? '';
                      final name = item['name'] as String? ?? 'Mídia';
                      final width = item['width'] as int? ?? 0;
                      final height = item['height'] as int? ?? 0;

                      IconData iconData = Icons.image_rounded;
                      Color iconColor = Colors.blue;
                      if (type == 'video') {
                        iconData = Icons.videocam_rounded;
                        iconColor = Colors.red;
                      } else if (type == 'audio') {
                        iconData = Icons.audiotrack_rounded;
                        iconColor = Colors.purple;
                      } else if (type == 'document') {
                        iconData = Icons.description_rounded;
                        iconColor = Colors.orange;
                      }

                      return ListTile(
                        leading: Container(
                          width: 44,
                          height: 44,
                          decoration: BoxDecoration(
                            color: iconColor.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Icon(iconData, color: iconColor, size: 22),
                        ),
                        title: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                        subtitle: Text(
                          width > 0 && height > 0
                              ? '$width × $height px • $url'
                              : url,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              tooltip: 'Copiar link',
                              icon: const Icon(Icons.copy_rounded, size: 18),
                              onPressed: () {
                                Clipboard.setData(ClipboardData(text: url));
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Link da mídia copiado!'),
                                  ),
                                );
                              },
                            ),
                            IconButton(
                              tooltip: 'Abrir em nova aba',
                              icon: const Icon(
                                Icons.open_in_new_rounded,
                                size: 18,
                              ),
                              onPressed: () {
                                Navigator.pop(context);
                                widget.browser.addTab(address: url);
                              },
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
