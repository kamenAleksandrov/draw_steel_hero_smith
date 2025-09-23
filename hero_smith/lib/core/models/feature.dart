import 'package:flutter/foundation.dart';

@immutable
class Feature {
  final String id;
  final String type;
  final String name;
  final String className;
  final bool isSubclassFeature;
  final String? subclassName;
  final int level;
  final String description;

  const Feature({
    required this.id,
    required this.type,
    required this.name,
    required this.className,
    required this.isSubclassFeature,
    this.subclassName,
    required this.level,
    required this.description,
  });

  factory Feature.fromJson(Map<String, dynamic> json) {
    return Feature(
      id: json['id'] as String,
      type: json['type'] as String,
      name: json['name'] as String,
      className: json['class'] as String,
      isSubclassFeature: json['is_subclass_feature'] as bool? ?? false,
      subclassName: json['subclass_name'] as String?,
      level: json['level'] as int,
      description: (json['description'] ?? '') as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type,
      'name': name,
      'class': className,
      'is_subclass_feature': isSubclassFeature,
      'subclass_name': subclassName,
      'level': level,
      'description': description,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Feature && other.id == id;
  }

  @override
  int get hashCode => id.hashCode;

  @override
  String toString() {
    return 'Feature(id: $id, name: $name, class: $className, level: $level)';
  }
}