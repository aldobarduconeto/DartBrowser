import 'dart:convert';

class DownloadItem {
  const DownloadItem({
    required this.id,
    required this.url,
    required this.fileName,
    required this.fileSize,
    required this.downloadedAt,
    this.status = 'completed',
    this.filePath,
  });

  final String id;
  final String url;
  final String fileName;
  final int fileSize;
  final DateTime downloadedAt;
  final String status;
  final String? filePath;

  String get formattedSize {
    if (fileSize <= 0) return 'Tamanho desconhecido';
    if (fileSize < 1024) return '$fileSize B';
    if (fileSize < 1024 * 1024) {
      return '${(fileSize / 1024).toStringAsFixed(1)} KB';
    }
    return '${(fileSize / (1024 * 1024)).toStringAsFixed(1)} MB';
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'fileName': fileName,
    'fileSize': fileSize,
    'downloadedAt': downloadedAt.toIso8601String(),
    'status': status,
    'filePath': filePath,
  };

  factory DownloadItem.fromJson(Map<String, dynamic> json) => DownloadItem(
    id:
        json['id'] as String? ??
        DateTime.now().millisecondsSinceEpoch.toString(),
    url: json['url'] as String? ?? '',
    fileName: json['fileName'] as String? ?? 'Arquivo',
    fileSize: json['fileSize'] as int? ?? 0,
    downloadedAt: json['downloadedAt'] != null
        ? DateTime.tryParse(json['downloadedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    status: json['status'] as String? ?? 'completed',
    filePath: json['filePath'] as String?,
  );

  String encode() => jsonEncode(toJson());

  static DownloadItem? tryDecode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return DownloadItem.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}
