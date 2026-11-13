import 'package:flutter/material.dart';

import '../../services/read_aloud_service.dart';

class ReadAloudBar extends StatelessWidget {
  const ReadAloudBar({super.key, required this.service, required this.onClose});

  final ReadAloudService service;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return ListenableBuilder(
      listenable: service,
      builder: (context, _) {
        if (!service.isActive) return const SizedBox.shrink();

        return Container(
          height: 44,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: colors.surfaceContainerHighest.withValues(alpha: 0.95),
            border: Border(
              bottom: BorderSide(
                color: colors.primary.withValues(alpha: 0.4),
                width: 1.5,
              ),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.15),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Ícone e Título
              Icon(
                Icons.record_voice_over_rounded,
                size: 18,
                color: colors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Leitura em Voz Alta',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.bold,
                  color: colors.primary,
                ),
              ),
              const SizedBox(width: 16),

              // Botão Play/Pause
              IconButton(
                tooltip: service.isPlaying ? 'Pausar (Espaço)' : 'Continuar',
                visualDensity: VisualDensity.compact,
                icon: Icon(
                  service.isPlaying
                      ? Icons.pause_circle_filled_rounded
                      : Icons.play_circle_fill_rounded,
                  size: 26,
                  color: colors.primary,
                ),
                onPressed: () {
                  if (service.isPlaying) {
                    service.pause();
                  } else {
                    service.resume();
                  }
                },
              ),

              // Botão Parar
              IconButton(
                tooltip: 'Parar leitura',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.stop_circle_outlined, size: 22),
                onPressed: () {
                  service.stop();
                  onClose();
                },
              ),

              const SizedBox(width: 8),

              // Velocidade
              PopupMenuButton<double>(
                tooltip: 'Velocidade de leitura',
                initialValue: service.rate,
                onSelected: service.setRate,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: colors.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(
                      color: colors.outlineVariant.withValues(alpha: 0.5),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        '${service.rate}x',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Icon(Icons.arrow_drop_down_rounded, size: 16),
                    ],
                  ),
                ),
                itemBuilder: (context) => [
                  for (final speed in [0.75, 1.0, 1.25, 1.5, 2.0])
                    PopupMenuItem(
                      value: speed,
                      child: Text(
                        '${speed}x ${speed == 1.0 ? "(Normal)" : ""}',
                      ),
                    ),
                ],
              ),

              const Spacer(),

              // Botão Fechar barra
              IconButton(
                tooltip: 'Fechar Leitor',
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18),
                onPressed: () {
                  service.stop();
                  onClose();
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
