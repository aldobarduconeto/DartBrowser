import 'dart:convert';

class ReadingItem {
  const ReadingItem({
    required this.id,
    required this.url,
    required this.title,
    required this.addedAt,
    this.isRead = false,
  });

  final String id;
  final String url;
  final String title;
  final DateTime addedAt;
  final bool isRead;

  ReadingItem copyWith({
    String? id,
    String? url,
    String? title,
    DateTime? addedAt,
    bool? isRead,
  }) => ReadingItem(
    id: id ?? this.id,
    url: url ?? this.url,
    title: title ?? this.title,
    addedAt: addedAt ?? this.addedAt,
    isRead: isRead ?? this.isRead,
  );

  Map<String, dynamic> toJson() => {
    'id': id,
    'url': url,
    'title': title,
    'addedAt': addedAt.toIso8601String(),
    'isRead': isRead,
  };

  factory ReadingItem.fromJson(Map<String, dynamic> json) => ReadingItem(
    id: json['id'] as String? ?? json['url'] as String,
    url: json['url'] as String,
    title: json['title'] as String? ?? json['url'] as String,
    addedAt: json['addedAt'] != null
        ? DateTime.tryParse(json['addedAt'] as String) ?? DateTime.now()
        : DateTime.now(),
    isRead: json['isRead'] == true,
  );

  String encode() => jsonEncode(toJson());

  static ReadingItem? tryDecode(String source) {
    try {
      final decoded = jsonDecode(source);
      if (decoded is Map<String, dynamic>) {
        return ReadingItem.fromJson(decoded);
      }
    } catch (_) {}
    return null;
  }
}
