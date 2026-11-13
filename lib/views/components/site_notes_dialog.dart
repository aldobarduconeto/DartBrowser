import 'dart:async';

import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';

class SiteNotesDialog extends StatefulWidget {
  const SiteNotesDialog({super.key, required this.browser, required this.host});

  final BrowserController browser;
  final String host;

  static Future<void> show(
    BuildContext context, {
    required BrowserController browser,
    required String host,
  }) async {
    final isMobile = MediaQuery.sizeOf(context).width < 600;

    if (isMobile) {
      await showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        builder: (ctx) => Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(ctx).viewInsets.bottom,
          ),
          child: SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.65,
            child: SiteNotesDialog(browser: browser, host: host),
          ),
        ),
      );
    } else {
      await showDialog<void>(
        context: context,
        builder: (ctx) => Dialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          clipBehavior: Clip.antiAlias,
          child: SizedBox(
            width: 520,
            height: 480,
            child: SiteNotesDialog(browser: browser, host: host),
          ),
        ),
      );
    }
  }

  @override
  State<SiteNotesDialog> createState() => _SiteNotesDialogState();
}

class _SiteNotesDialogState extends State<SiteNotesDialog> {
  late TextEditingController _controller;
  Timer? _debounceTimer;
  bool _saved = true;

  @override
  void initState() {
    super.initState();
    final currentNotes =
        widget.browser.data.preferences.getString(
          'site_notes_${widget.host}',
        ) ??
        '';
    _controller = TextEditingController(text: currentNotes);
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  void _onTextChanged(String value) {
    setState(() => _saved = false);
    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 600), () async {
      await widget.browser.data.preferences.setString(
        'site_notes_${widget.host}',
        value,
      );
      if (mounted) setState(() => _saved = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Column(
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
                  Icons.note_alt_rounded,
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
                      'Anotações do Site',
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      widget.host,
                      style: TextStyle(
                        fontSize: 12,
                        color: colors.onSurfaceVariant,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _saved
                      ? Colors.green.withValues(alpha: 0.15)
                      : Colors.orange.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      _saved ? Icons.cloud_done_rounded : Icons.sync_rounded,
                      size: 14,
                      color: _saved ? Colors.green : Colors.orange,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _saved ? 'Salvo' : 'Salvando...',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: _saved ? Colors.green : Colors.orange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: _controller,
              onChanged: _onTextChanged,
              maxLines: null,
              expands: true,
              style: const TextStyle(fontSize: 14, height: 1.5),
              decoration: const InputDecoration(
                hintText: 'Escreva anotações, lembretes, trechos de código ou resumo para este site...',
                border: InputBorder.none,
              ),
            ),
          ),
        ),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          color: colors.surfaceContainerLow,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Salvo automaticamente para ${widget.host}',
                style: TextStyle(fontSize: 11, color: colors.onSurfaceVariant),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Concluído'),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
