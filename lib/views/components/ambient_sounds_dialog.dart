import '../../l10n/browser_text.dart';

import 'package:flutter/material.dart';

import '../../controllers/browser_controller.dart';

enum AmbientSoundType {
  none('Nenhum', Icons.volume_off_rounded),
  rain('Chuva Suave', Icons.water_drop_rounded),
  whiteNoise('Ruído Branco (Foco)', Icons.graphic_eq_rounded),
  ocean('Ondas do Oceano', Icons.waves_rounded),
  space('Espaço Cósmico (Drone)', Icons.nights_stay_rounded);

  const AmbientSoundType(this.label, this.icon);
  final String label;
  final IconData icon;
}

class AmbientSoundsDialog extends StatefulWidget {
  const AmbientSoundsDialog({super.key, required this.browser});

  final BrowserController browser;

  static Future<void> show(BuildContext context, BrowserController browser) {
    return showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) => AmbientSoundsDialog(browser: browser),
    );
  }

  @override
  State<AmbientSoundsDialog> createState() => _AmbientSoundsDialogState();
}

class _AmbientSoundsDialogState extends State<AmbientSoundsDialog> {
  AmbientSoundType _currentType = AmbientSoundType.none;
  double _volume = 0.5;

  static const String _synthScript = r"""
  (() => {
    if (window.__dartAmbientAudioCtx) {
      try { window.__dartAmbientAudioCtx.close(); } catch(_) {}
    }
    window.__dartAmbientAudioCtx = null;
    window.__dartAmbientGain = null;

    window.__dartPlayAmbient = (type, volume = 0.5) => {
      try {
        if (window.__dartAmbientAudioCtx) {
          window.__dartAmbientAudioCtx.close();
        }
        if (type === 'none') return true;

        const AudioContext = window.AudioContext || window.webkitAudioContext;
        const ctx = new AudioContext();
        window.__dartAmbientAudioCtx = ctx;

        const masterGain = ctx.createGain();
        masterGain.gain.setValueAtTime(volume, ctx.currentTime);
        masterGain.connect(ctx.destination);
        window.__dartAmbientGain = masterGain;

        if (type === 'whiteNoise') {
          const bufferSize = ctx.sampleRate * 2;
          const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
          const data = buffer.getChannelData(0);
          for (let i = 0; i < bufferSize; i++) {
            data[i] = (Math.random() * 2 - 1) * 0.15;
          }
          const noise = ctx.createBufferSource();
          noise.buffer = buffer;
          noise.loop = true;
          noise.connect(masterGain);
          noise.start();
        } else if (type === 'rain') {
          const bufferSize = ctx.sampleRate * 2;
          const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
          const data = buffer.getChannelData(0);
          let b0 = 0, b1 = 0, b2 = 0;
          for (let i = 0; i < bufferSize; i++) {
            const white = Math.random() * 2 - 1;
            b0 = 0.99 * b0 + white * 0.05;
            b1 = 0.95 * b1 + white * 0.07;
            b2 = 0.85 * b2 + white * 0.1;
            data[i] = (b0 + b1 + b2) * 0.08;
          }
          const filter = ctx.createBiquadFilter();
          filter.type = 'lowpass';
          filter.frequency.setValueAtTime(800, ctx.currentTime);

          const noise = ctx.createBufferSource();
          noise.buffer = buffer;
          noise.loop = true;
          noise.connect(filter);
          filter.connect(masterGain);
          noise.start();
        } else if (type === 'ocean') {
          const bufferSize = ctx.sampleRate * 4;
          const buffer = ctx.createBuffer(1, bufferSize, ctx.sampleRate);
          const data = buffer.getChannelData(0);
          for (let i = 0; i < bufferSize; i++) {
            data[i] = (Math.random() * 2 - 1) * 0.12;
          }
          const filter = ctx.createBiquadFilter();
          filter.type = 'lowpass';
          filter.frequency.setValueAtTime(400, ctx.currentTime);

          const waveGain = ctx.createGain();
          const lfo = ctx.createOscillator();
          lfo.frequency.setValueAtTime(0.1, ctx.currentTime); // 10s por ciclo de onda
          lfo.connect(waveGain.gain);

          const noise = ctx.createBufferSource();
          noise.buffer = buffer;
          noise.loop = true;
          noise.connect(filter);
          filter.connect(waveGain);
          waveGain.connect(masterGain);
          lfo.start();
          noise.start();
        } else if (type === 'space') {
          const osc1 = ctx.createOscillator();
          const osc2 = ctx.createOscillator();
          osc1.type = 'sine';
          osc2.type = 'sine';
          osc1.frequency.setValueAtTime(108, ctx.currentTime);
          osc2.frequency.setValueAtTime(110.5, ctx.currentTime); // batimento binaural

          const toneGain = ctx.createGain();
          toneGain.gain.setValueAtTime(0.12, ctx.currentTime);
          osc1.connect(toneGain);
          osc2.connect(toneGain);
          toneGain.connect(masterGain);
          osc1.start();
          osc2.start();
        }
        return true;
      } catch (e) {
        return false;
      }
    };

    window.__dartSetAmbientVolume = (vol) => {
      if (window.__dartAmbientGain && window.__dartAmbientAudioCtx) {
        window.__dartAmbientGain.gain.setValueAtTime(vol, window.__dartAmbientAudioCtx.currentTime);
      }
    };

    window.__dartStopAmbient = () => {
      if (window.__dartAmbientAudioCtx) {
        try { window.__dartAmbientAudioCtx.close(); } catch(_) {}
        window.__dartAmbientAudioCtx = null;
      }
    };
  })();
  """;

  Future<void> _changeSound(AmbientSoundType type) async {
    setState(() => _currentType = type);
    final engine = widget.browser.current.engine;
    try {
      if (type == AmbientSoundType.none) {
        await engine.runJavaScript(
          'if(window.__dartStopAmbient) window.__dartStopAmbient();',
        );
      } else {
        await engine.runJavaScript(_synthScript);
        final jsType = switch (type) {
          AmbientSoundType.rain => 'rain',
          AmbientSoundType.whiteNoise => 'whiteNoise',
          AmbientSoundType.ocean => 'ocean',
          AmbientSoundType.space => 'space',
          _ => 'none',
        };
        await engine.runJavaScript(
          'window.__dartPlayAmbient("$jsType", $_volume);',
        );
      }
    } catch (_) {}
  }

  Future<void> _updateVolume(double value) async {
    setState(() => _volume = value);
    final engine = widget.browser.current.engine;
    try {
      await engine.runJavaScript(
        'if(window.__dartSetAmbientVolume) window.__dartSetAmbientVolume($_volume);',
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
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
                      Icons.headphones_rounded,
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
                          'Sons de Foco Ambientais',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'Áudio sintetizado para concentração profunda',
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

              // Lista de Sons
              ...AmbientSoundType.values.map((sound) {
                final isSelected = _currentType == sound;
                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: InkWell(
                    borderRadius: BorderRadius.circular(10),
                    onTap: () => _changeSound(sound),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: isSelected
                            ? colors.primary.withValues(alpha: 0.15)
                            : colors.surfaceContainerLow,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                          color: isSelected
                              ? colors.primary
                              : colors.outlineVariant.withValues(alpha: 0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            sound.icon,
                            color: isSelected
                                ? colors.primary
                                : colors.onSurfaceVariant,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              sound.label,
                              style: TextStyle(
                                fontWeight: isSelected
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                                color: isSelected ? colors.primary : null,
                              ),
                            ),
                          ),
                          if (isSelected)
                            Icon(
                              Icons.check_circle_rounded,
                              color: colors.primary,
                              size: 18,
                            ),
                        ],
                      ),
                    ),
                  ),
                );
              }),

              const SizedBox(height: 16),

              // Controle de Volume
              if (_currentType != AmbientSoundType.none) ...[
                Row(
                  children: [
                    const Icon(Icons.volume_down_rounded, size: 18),
                    Expanded(
                      child: Slider(
                        value: _volume,
                        min: 0.05,
                        max: 1.0,
                        divisions: 19,
                        label: '${(_volume * 100).round()}%',
                        onChanged: _updateVolume,
                      ),
                    ),
                    const Icon(Icons.volume_up_rounded, size: 18),
                  ],
                ),
                const SizedBox(height: 8),
              ],

              // Botão fechar
              Align(
                alignment: Alignment.centerRight,
                child: FilledButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const BrowserText('Fechar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
