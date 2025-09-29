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
    final id = json['id']?.toString();
    if (id == null || id.isEmpty) {
      throw ArgumentError('Feature JSON missing id field.');
    }

    final type = json['type']?.toString() ?? 'feature';
    final name = json['name']?.toString() ?? 'Unnamed Feature';
    final className = json['class']?.toString() ?? '';
    final subclassName = json['subclass_name']?.toString();
    final level = _tryParseInt(json['level']) ?? 0;
    final description = json['description']?.toString() ?? '';

    var isSubclassFeature = false;
    final subclassRaw = json['is_subclass_feature'];
    if (subclassRaw is bool) {
      isSubclassFeature = subclassRaw;
    } else if (subclassRaw is num) {
      isSubclassFeature = subclassRaw != 0;
    } else if (subclassRaw is String) {
      final normalized = subclassRaw.trim().toLowerCase();
      isSubclassFeature =
          normalized == 'true' || normalized == '1' || normalized == 'yes';
    }

    return Feature(
      id: id,
      type: type,
      name: name,
      className: className,
      isSubclassFeature: isSubclassFeature,
      subclassName: subclassName,
      level: level,
      description: description,
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

  static int? _tryParseInt(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is double) return value.round();
    if (value is String) {
      final trimmed = value.trim();
      if (trimmed.isEmpty) return null;
      return int.tryParse(trimmed);
    }
    return null;
  }
}
