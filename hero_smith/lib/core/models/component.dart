/// Base Component model representing one selectable building block for a Hero.
/// Initial minimal shape; will expand once we parse JSON seed data.
class Component {
  final String id;
  final String type; // raw type string from JSON (e.g. 'class', 'skill', etc.)
  final String name;
  final Map<String, dynamic> data; // arbitrary extra fields

  const Component({
    required this.id,
    required this.type,
    required this.name,
    this.data = const {},
  });

  factory Component.fromJson(Map<String, dynamic> json) {
    final map = Map<String, dynamic>.from(json);
    final id = map.remove('id') as String? ?? '';
    final type = map.remove('type') as String? ?? 'unknown';
    final name = map.remove('name') as String? ?? '';
    return Component(id: id, type: type, name: name, data: map);
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'name': name,
        ...data,
      };

  Component copyWith({
    String? id,
    String? type,
    String? name,
    Map<String, dynamic>? data,
  }) => Component(
        id: id ?? this.id,
        type: type ?? this.type,
        name: name ?? this.name,
        data: data ?? this.data,
      );
}
