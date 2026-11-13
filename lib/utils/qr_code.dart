import 'dart:math';

import 'package:flutter/material.dart';

/// Gerador independente e leve de QR Code em Dart puro para compartilhamento de URLs
class QrCode {
  QrCode(this.text) {
    _generate();
  }

  final String text;
  late final int size;
  late final List<List<bool>> modules;

  void _generate() {
    final bytes = text.codeUnits;
    // Selecionar versão apropriada (Versões 1 a 6)
    int version = 1;
    if (bytes.length > 17) version = 2;
    if (bytes.length > 32) version = 3;
    if (bytes.length > 53) version = 4;
    if (bytes.length > 78) version = 5;
    if (bytes.length > 106) version = 6;
    if (bytes.length > 134) version = 7;

    size = version * 4 + 17;
    modules = List.generate(size, (_) => List.filled(size, false));
    final isFunction = List.generate(size, (_) => List.filled(size, false));

    // 1. Finder patterns (7x7 em três cantos)
    void addFinder(int r0, int c0) {
      for (int r = -1; r <= 7; r++) {
        for (int c = -1; c <= 7; c++) {
          final row = r0 + r;
          final col = c0 + c;
          if (row >= 0 && row < size && col >= 0 && col < size) {
            isFunction[row][col] = true;
            if (r >= 0 && r <= 6 && c >= 0 && c <= 6) {
              modules[row][col] =
                  r == 0 ||
                  r == 6 ||
                  c == 0 ||
                  c == 6 ||
                  (r >= 2 && r <= 4 && c >= 2 && c <= 4);
            } else {
              modules[row][col] = false;
            }
          }
        }
      }
    }

    addFinder(0, 0);
    addFinder(0, size - 7);
    addFinder(size - 7, 0);

    // 2. Timing patterns
    for (int i = 8; i < size - 8; i++) {
      modules[6][i] = i % 2 == 0;
      isFunction[6][i] = true;
      modules[i][6] = i % 2 == 0;
      isFunction[i][6] = true;
    }

    // 3. Dark module
    modules[size - 8][8] = true;
    isFunction[size - 8][8] = true;

    // 4. Alignment patterns para versão >= 2
    if (version >= 2) {
      final pos = _alignmentPositions[version]!;
      for (final r in pos) {
        for (final c in pos) {
          if (isFunction[r][c]) continue;
          for (int dr = -2; dr <= 2; dr++) {
            for (int dc = -2; dc <= 2; dc++) {
              final row = r + dr;
              final col = c + dc;
              isFunction[row][col] = true;
              modules[row][col] =
                  max(dr.abs(), dc.abs()) == 2 || (dr == 0 && dc == 0);
            }
          }
        }
      }
    }

    // 5. Reserva de formato
    for (int i = 0; i < 9; i++) {
      if (i < size) {
        isFunction[8][i] = true;
        isFunction[i][8] = true;
      }
    }
    for (int i = 0; i < 8; i++) {
      isFunction[8][size - 1 - i] = true;
      isFunction[size - 1 - i][8] = true;
    }

    // 6. Codificação de dados e bits
    final bitStream = <int>[];
    // Modo Byte: 0100
    bitStream.addAll([0, 1, 0, 0]);
    // Contador de caracteres (8 bits para versões 1-9)
    for (int i = 7; i >= 0; i--) {
      bitStream.add((bytes.length >> i) & 1);
    }
    // Dados dos bytes
    for (final b in bytes) {
      for (int i = 7; i >= 0; i--) {
        bitStream.add((b >> i) & 1);
      }
    }

    // Total de capacidade de bits de dados para a versão (Nível L)
    final totalDataBits = _totalDataBits[version] ?? (size * size ~/ 2);
    // Terminador de 4 zeros
    while (bitStream.length < totalDataBits &&
        bitStream.length % 8 != 0 &&
        bitStream.length < totalDataBits) {
      bitStream.add(0);
    }
    while (bitStream.length % 8 != 0) {
      bitStream.add(0);
    }
    // Padding bytes 0xEC e 0x11
    final pad = [0xEC, 0x11];
    int padIdx = 0;
    while (bitStream.length < totalDataBits) {
      final p = pad[padIdx % 2];
      for (int i = 7; i >= 0; i--) {
        bitStream.add((p >> i) & 1);
      }
      padIdx++;
    }

    // Preenchimento dos módulos de dados com máscara (Máscara 0: (r + c) % 2 == 0)
    int bitIndex = 0;
    int col = size - 1;
    bool goingUp = true;

    while (col > 0) {
      if (col == 6) col--; // pular linha vertical de timing
      for (int step = 0; step < size; step++) {
        final r = goingUp ? (size - 1 - step) : step;
        for (int c = col; c >= col - 1; c--) {
          if (!isFunction[r][c]) {
            bool bit = false;
            if (bitIndex < bitStream.length) {
              bit = bitStream[bitIndex] == 1;
              bitIndex++;
            }
            // Inverter com máscara (r + c) % 2 == 0
            if ((r + c) % 2 == 0) bit = !bit;
            modules[r][c] = bit;
          }
        }
      }
      goingUp = !goingUp;
      col -= 2;
    }

    // 7. Informação de formato (Nível L, Máscara 0: valor 0x77C4)
    const formatBits = 0x77C4;
    for (int i = 0; i < 15; i++) {
      final bit = ((formatBits >> i) & 1) == 1;
      if (i < 6) {
        modules[8][i] = bit;
      } else if (i < 8) {
        modules[8][i + 1] = bit;
      } else {
        modules[8 - (i - 8) - 1][8] = bit;
      }

      if (i < 8) {
        modules[size - 1 - i][8] = bit;
      } else {
        modules[8][size - 1 - (14 - i)] = bit;
      }
    }
  }

  static const _totalDataBits = {
    1: 152,
    2: 272,
    3: 440,
    4: 640,
    5: 864,
    6: 1088,
    7: 1248,
  };

  static const _alignmentPositions = {
    2: [6, 18],
    3: [6, 22],
    4: [6, 26],
    5: [6, 30],
    6: [6, 34],
    7: [6, 22, 38],
  };
}

class QrCodeWidget extends StatelessWidget {
  const QrCodeWidget({
    super.key,
    required this.data,
    this.size = 200,
    this.color = Colors.black,
    this.backgroundColor = Colors.white,
  });

  final String data;
  final double size;
  final Color color;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    final qr = QrCode(data);
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.08),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: CustomPaint(
        painter: _QrPainter(qr: qr, color: color),
      ),
    );
  }
}

class _QrPainter extends CustomPainter {
  _QrPainter({required this.qr, required this.color});

  final QrCode qr;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final moduleSize = size.width / qr.size;

    for (int r = 0; r < qr.size; r++) {
      for (int c = 0; c < qr.size; c++) {
        if (qr.modules[r][c]) {
          final rect = Rect.fromLTWH(
            c * moduleSize,
            r * moduleSize,
            moduleSize,
            moduleSize,
          );
          canvas.drawRRect(
            RRect.fromRectAndRadius(rect, Radius.circular(moduleSize * 0.15)),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant _QrPainter oldDelegate) =>
      oldDelegate.qr != qr || oldDelegate.color != color;
}
