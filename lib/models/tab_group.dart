class TabGroup {
  TabGroup({
    required this.id,
    required this.name,
    required this.color,
    this.collapsed = false,
  });

  final int id;
  String name;
  int color;
  bool collapsed;

  factory TabGroup.fromJson(Map<String, dynamic> json) => TabGroup(
    id: json['id'] as int,
    name: json['name'] as String,
    color: json['color'] as int,
    collapsed: json['collapsed'] == true,
  );

  Map<String, Object> toJson() => {
    'id': id,
    'name': name,
    'color': color,
    'collapsed': collapsed,
  };
}
