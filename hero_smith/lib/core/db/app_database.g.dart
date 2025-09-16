// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ComponentsTable extends Components
    with TableInfo<$ComponentsTable, Component> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ComponentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
      'type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dataJsonMeta =
      const VerificationMeta('dataJson');
  @override
  late final GeneratedColumn<String> dataJson = GeneratedColumn<String>(
      'data_json', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('{}'));
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('seed'));
  static const VerificationMeta _parentIdMeta =
      const VerificationMeta('parentId');
  @override
  late final GeneratedColumn<String> parentId = GeneratedColumn<String>(
      'parent_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES components (id)'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, type, name, dataJson, source, parentId, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'components';
  @override
  VerificationContext validateIntegrity(Insertable<Component> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
          _typeMeta, type.isAcceptableOrUnknown(data['type']!, _typeMeta));
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('data_json')) {
      context.handle(_dataJsonMeta,
          dataJson.isAcceptableOrUnknown(data['data_json']!, _dataJsonMeta));
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    }
    if (data.containsKey('parent_id')) {
      context.handle(_parentIdMeta,
          parentId.isAcceptableOrUnknown(data['parent_id']!, _parentIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Component map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Component(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      type: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}type'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      dataJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}data_json'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      parentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parent_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $ComponentsTable createAlias(String alias) {
    return $ComponentsTable(attachedDatabase, alias);
  }
}

class Component extends DataClass implements Insertable<Component> {
  final String id;
  final String type;
  final String name;
  final String dataJson;
  final String source;
  final String? parentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Component(
      {required this.id,
      required this.type,
      required this.name,
      required this.dataJson,
      required this.source,
      this.parentId,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['type'] = Variable<String>(type);
    map['name'] = Variable<String>(name);
    map['data_json'] = Variable<String>(dataJson);
    map['source'] = Variable<String>(source);
    if (!nullToAbsent || parentId != null) {
      map['parent_id'] = Variable<String>(parentId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  ComponentsCompanion toCompanion(bool nullToAbsent) {
    return ComponentsCompanion(
      id: Value(id),
      type: Value(type),
      name: Value(name),
      dataJson: Value(dataJson),
      source: Value(source),
      parentId: parentId == null && nullToAbsent
          ? const Value.absent()
          : Value(parentId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Component.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Component(
      id: serializer.fromJson<String>(json['id']),
      type: serializer.fromJson<String>(json['type']),
      name: serializer.fromJson<String>(json['name']),
      dataJson: serializer.fromJson<String>(json['dataJson']),
      source: serializer.fromJson<String>(json['source']),
      parentId: serializer.fromJson<String?>(json['parentId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'type': serializer.toJson<String>(type),
      'name': serializer.toJson<String>(name),
      'dataJson': serializer.toJson<String>(dataJson),
      'source': serializer.toJson<String>(source),
      'parentId': serializer.toJson<String?>(parentId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Component copyWith(
          {String? id,
          String? type,
          String? name,
          String? dataJson,
          String? source,
          Value<String?> parentId = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Component(
        id: id ?? this.id,
        type: type ?? this.type,
        name: name ?? this.name,
        dataJson: dataJson ?? this.dataJson,
        source: source ?? this.source,
        parentId: parentId.present ? parentId.value : this.parentId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Component copyWithCompanion(ComponentsCompanion data) {
    return Component(
      id: data.id.present ? data.id.value : this.id,
      type: data.type.present ? data.type.value : this.type,
      name: data.name.present ? data.name.value : this.name,
      dataJson: data.dataJson.present ? data.dataJson.value : this.dataJson,
      source: data.source.present ? data.source.value : this.source,
      parentId: data.parentId.present ? data.parentId.value : this.parentId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Component(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('dataJson: $dataJson, ')
          ..write('source: $source, ')
          ..write('parentId: $parentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, type, name, dataJson, source, parentId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Component &&
          other.id == this.id &&
          other.type == this.type &&
          other.name == this.name &&
          other.dataJson == this.dataJson &&
          other.source == this.source &&
          other.parentId == this.parentId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class ComponentsCompanion extends UpdateCompanion<Component> {
  final Value<String> id;
  final Value<String> type;
  final Value<String> name;
  final Value<String> dataJson;
  final Value<String> source;
  final Value<String?> parentId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const ComponentsCompanion({
    this.id = const Value.absent(),
    this.type = const Value.absent(),
    this.name = const Value.absent(),
    this.dataJson = const Value.absent(),
    this.source = const Value.absent(),
    this.parentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ComponentsCompanion.insert({
    required String id,
    required String type,
    required String name,
    this.dataJson = const Value.absent(),
    this.source = const Value.absent(),
    this.parentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        type = Value(type),
        name = Value(name);
  static Insertable<Component> custom({
    Expression<String>? id,
    Expression<String>? type,
    Expression<String>? name,
    Expression<String>? dataJson,
    Expression<String>? source,
    Expression<String>? parentId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (type != null) 'type': type,
      if (name != null) 'name': name,
      if (dataJson != null) 'data_json': dataJson,
      if (source != null) 'source': source,
      if (parentId != null) 'parent_id': parentId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ComponentsCompanion copyWith(
      {Value<String>? id,
      Value<String>? type,
      Value<String>? name,
      Value<String>? dataJson,
      Value<String>? source,
      Value<String?>? parentId,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return ComponentsCompanion(
      id: id ?? this.id,
      type: type ?? this.type,
      name: name ?? this.name,
      dataJson: dataJson ?? this.dataJson,
      source: source ?? this.source,
      parentId: parentId ?? this.parentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (dataJson.present) {
      map['data_json'] = Variable<String>(dataJson.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (parentId.present) {
      map['parent_id'] = Variable<String>(parentId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ComponentsCompanion(')
          ..write('id: $id, ')
          ..write('type: $type, ')
          ..write('name: $name, ')
          ..write('dataJson: $dataJson, ')
          ..write('source: $source, ')
          ..write('parentId: $parentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HeroesTable extends Heroes with TableInfo<$HeroesTable, Heroe> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeroesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _classComponentIdMeta =
      const VerificationMeta('classComponentId');
  @override
  late final GeneratedColumn<String> classComponentId = GeneratedColumn<String>(
      'class_component_id', aliasedName, true,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES components (id)'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, name, classComponentId, createdAt, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'heroes';
  @override
  VerificationContext validateIntegrity(Insertable<Heroe> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('class_component_id')) {
      context.handle(
          _classComponentIdMeta,
          classComponentId.isAcceptableOrUnknown(
              data['class_component_id']!, _classComponentIdMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Heroe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Heroe(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      classComponentId: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}class_component_id']),
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $HeroesTable createAlias(String alias) {
    return $HeroesTable(attachedDatabase, alias);
  }
}

class Heroe extends DataClass implements Insertable<Heroe> {
  final String id;
  final String name;
  final String? classComponentId;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Heroe(
      {required this.id,
      required this.name,
      this.classComponentId,
      required this.createdAt,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || classComponentId != null) {
      map['class_component_id'] = Variable<String>(classComponentId);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  HeroesCompanion toCompanion(bool nullToAbsent) {
    return HeroesCompanion(
      id: Value(id),
      name: Value(name),
      classComponentId: classComponentId == null && nullToAbsent
          ? const Value.absent()
          : Value(classComponentId),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Heroe.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Heroe(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      classComponentId: serializer.fromJson<String?>(json['classComponentId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'classComponentId': serializer.toJson<String?>(classComponentId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Heroe copyWith(
          {String? id,
          String? name,
          Value<String?> classComponentId = const Value.absent(),
          DateTime? createdAt,
          DateTime? updatedAt}) =>
      Heroe(
        id: id ?? this.id,
        name: name ?? this.name,
        classComponentId: classComponentId.present
            ? classComponentId.value
            : this.classComponentId,
        createdAt: createdAt ?? this.createdAt,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Heroe copyWithCompanion(HeroesCompanion data) {
    return Heroe(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      classComponentId: data.classComponentId.present
          ? data.classComponentId.value
          : this.classComponentId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Heroe(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('classComponentId: $classComponentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, name, classComponentId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Heroe &&
          other.id == this.id &&
          other.name == this.name &&
          other.classComponentId == this.classComponentId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class HeroesCompanion extends UpdateCompanion<Heroe> {
  final Value<String> id;
  final Value<String> name;
  final Value<String?> classComponentId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const HeroesCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.classComponentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HeroesCompanion.insert({
    required String id,
    required String name,
    this.classComponentId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        name = Value(name);
  static Insertable<Heroe> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<String>? classComponentId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (classComponentId != null) 'class_component_id': classComponentId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HeroesCompanion copyWith(
      {Value<String>? id,
      Value<String>? name,
      Value<String?>? classComponentId,
      Value<DateTime>? createdAt,
      Value<DateTime>? updatedAt,
      Value<int>? rowid}) {
    return HeroesCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      classComponentId: classComponentId ?? this.classComponentId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (classComponentId.present) {
      map['class_component_id'] = Variable<String>(classComponentId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeroesCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('classComponentId: $classComponentId, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HeroComponentsTable extends HeroComponents
    with TableInfo<$HeroComponentsTable, HeroComponent> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeroComponentsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _autoIdMeta = const VerificationMeta('autoId');
  @override
  late final GeneratedColumn<int> autoId = GeneratedColumn<int>(
      'auto_id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _heroIdMeta = const VerificationMeta('heroId');
  @override
  late final GeneratedColumn<String> heroId = GeneratedColumn<String>(
      'hero_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES heroes (id)'));
  static const VerificationMeta _componentIdMeta =
      const VerificationMeta('componentId');
  @override
  late final GeneratedColumn<String> componentId = GeneratedColumn<String>(
      'component_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES components (id)'));
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('generic'));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [autoId, heroId, componentId, category, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hero_components';
  @override
  VerificationContext validateIntegrity(Insertable<HeroComponent> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('auto_id')) {
      context.handle(_autoIdMeta,
          autoId.isAcceptableOrUnknown(data['auto_id']!, _autoIdMeta));
    }
    if (data.containsKey('hero_id')) {
      context.handle(_heroIdMeta,
          heroId.isAcceptableOrUnknown(data['hero_id']!, _heroIdMeta));
    } else if (isInserting) {
      context.missing(_heroIdMeta);
    }
    if (data.containsKey('component_id')) {
      context.handle(
          _componentIdMeta,
          componentId.isAcceptableOrUnknown(
              data['component_id']!, _componentIdMeta));
    } else if (isInserting) {
      context.missing(_componentIdMeta);
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {autoId};
  @override
  HeroComponent map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HeroComponent(
      autoId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}auto_id'])!,
      heroId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hero_id'])!,
      componentId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}component_id'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $HeroComponentsTable createAlias(String alias) {
    return $HeroComponentsTable(attachedDatabase, alias);
  }
}

class HeroComponent extends DataClass implements Insertable<HeroComponent> {
  final int autoId;
  final String heroId;
  final String componentId;
  final String category;
  final DateTime createdAt;
  const HeroComponent(
      {required this.autoId,
      required this.heroId,
      required this.componentId,
      required this.category,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['auto_id'] = Variable<int>(autoId);
    map['hero_id'] = Variable<String>(heroId);
    map['component_id'] = Variable<String>(componentId);
    map['category'] = Variable<String>(category);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HeroComponentsCompanion toCompanion(bool nullToAbsent) {
    return HeroComponentsCompanion(
      autoId: Value(autoId),
      heroId: Value(heroId),
      componentId: Value(componentId),
      category: Value(category),
      createdAt: Value(createdAt),
    );
  }

  factory HeroComponent.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HeroComponent(
      autoId: serializer.fromJson<int>(json['autoId']),
      heroId: serializer.fromJson<String>(json['heroId']),
      componentId: serializer.fromJson<String>(json['componentId']),
      category: serializer.fromJson<String>(json['category']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'autoId': serializer.toJson<int>(autoId),
      'heroId': serializer.toJson<String>(heroId),
      'componentId': serializer.toJson<String>(componentId),
      'category': serializer.toJson<String>(category),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  HeroComponent copyWith(
          {int? autoId,
          String? heroId,
          String? componentId,
          String? category,
          DateTime? createdAt}) =>
      HeroComponent(
        autoId: autoId ?? this.autoId,
        heroId: heroId ?? this.heroId,
        componentId: componentId ?? this.componentId,
        category: category ?? this.category,
        createdAt: createdAt ?? this.createdAt,
      );
  HeroComponent copyWithCompanion(HeroComponentsCompanion data) {
    return HeroComponent(
      autoId: data.autoId.present ? data.autoId.value : this.autoId,
      heroId: data.heroId.present ? data.heroId.value : this.heroId,
      componentId:
          data.componentId.present ? data.componentId.value : this.componentId,
      category: data.category.present ? data.category.value : this.category,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HeroComponent(')
          ..write('autoId: $autoId, ')
          ..write('heroId: $heroId, ')
          ..write('componentId: $componentId, ')
          ..write('category: $category, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(autoId, heroId, componentId, category, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HeroComponent &&
          other.autoId == this.autoId &&
          other.heroId == this.heroId &&
          other.componentId == this.componentId &&
          other.category == this.category &&
          other.createdAt == this.createdAt);
}

class HeroComponentsCompanion extends UpdateCompanion<HeroComponent> {
  final Value<int> autoId;
  final Value<String> heroId;
  final Value<String> componentId;
  final Value<String> category;
  final Value<DateTime> createdAt;
  const HeroComponentsCompanion({
    this.autoId = const Value.absent(),
    this.heroId = const Value.absent(),
    this.componentId = const Value.absent(),
    this.category = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  HeroComponentsCompanion.insert({
    this.autoId = const Value.absent(),
    required String heroId,
    required String componentId,
    this.category = const Value.absent(),
    this.createdAt = const Value.absent(),
  })  : heroId = Value(heroId),
        componentId = Value(componentId);
  static Insertable<HeroComponent> custom({
    Expression<int>? autoId,
    Expression<String>? heroId,
    Expression<String>? componentId,
    Expression<String>? category,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (autoId != null) 'auto_id': autoId,
      if (heroId != null) 'hero_id': heroId,
      if (componentId != null) 'component_id': componentId,
      if (category != null) 'category': category,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  HeroComponentsCompanion copyWith(
      {Value<int>? autoId,
      Value<String>? heroId,
      Value<String>? componentId,
      Value<String>? category,
      Value<DateTime>? createdAt}) {
    return HeroComponentsCompanion(
      autoId: autoId ?? this.autoId,
      heroId: heroId ?? this.heroId,
      componentId: componentId ?? this.componentId,
      category: category ?? this.category,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (autoId.present) {
      map['auto_id'] = Variable<int>(autoId.value);
    }
    if (heroId.present) {
      map['hero_id'] = Variable<String>(heroId.value);
    }
    if (componentId.present) {
      map['component_id'] = Variable<String>(componentId.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeroComponentsCompanion(')
          ..write('autoId: $autoId, ')
          ..write('heroId: $heroId, ')
          ..write('componentId: $componentId, ')
          ..write('category: $category, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $HeroValuesTable extends HeroValues
    with TableInfo<$HeroValuesTable, HeroValue> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HeroValuesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _heroIdMeta = const VerificationMeta('heroId');
  @override
  late final GeneratedColumn<String> heroId = GeneratedColumn<String>(
      'hero_id', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: true,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('REFERENCES heroes (id)'));
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<int> value = GeneratedColumn<int>(
      'value', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _maxValueMeta =
      const VerificationMeta('maxValue');
  @override
  late final GeneratedColumn<int> maxValue = GeneratedColumn<int>(
      'max_value', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _doubleValueMeta =
      const VerificationMeta('doubleValue');
  @override
  late final GeneratedColumn<double> doubleValue = GeneratedColumn<double>(
      'double_value', aliasedName, true,
      type: DriftSqlType.double, requiredDuringInsert: false);
  static const VerificationMeta _textValueMeta =
      const VerificationMeta('textValue');
  @override
  late final GeneratedColumn<String> textValue = GeneratedColumn<String>(
      'text_value', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _jsonValueMeta =
      const VerificationMeta('jsonValue');
  @override
  late final GeneratedColumn<String> jsonValue = GeneratedColumn<String>(
      'json_value', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        heroId,
        key,
        value,
        maxValue,
        doubleValue,
        textValue,
        jsonValue,
        updatedAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hero_values';
  @override
  VerificationContext validateIntegrity(Insertable<HeroValue> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('hero_id')) {
      context.handle(_heroIdMeta,
          heroId.isAcceptableOrUnknown(data['hero_id']!, _heroIdMeta));
    } else if (isInserting) {
      context.missing(_heroIdMeta);
    }
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    }
    if (data.containsKey('max_value')) {
      context.handle(_maxValueMeta,
          maxValue.isAcceptableOrUnknown(data['max_value']!, _maxValueMeta));
    }
    if (data.containsKey('double_value')) {
      context.handle(
          _doubleValueMeta,
          doubleValue.isAcceptableOrUnknown(
              data['double_value']!, _doubleValueMeta));
    }
    if (data.containsKey('text_value')) {
      context.handle(_textValueMeta,
          textValue.isAcceptableOrUnknown(data['text_value']!, _textValueMeta));
    }
    if (data.containsKey('json_value')) {
      context.handle(_jsonValueMeta,
          jsonValue.isAcceptableOrUnknown(data['json_value']!, _jsonValueMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HeroValue map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HeroValue(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      heroId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hero_id'])!,
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}value']),
      maxValue: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}max_value']),
      doubleValue: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}double_value']),
      textValue: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}text_value']),
      jsonValue: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}json_value']),
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $HeroValuesTable createAlias(String alias) {
    return $HeroValuesTable(attachedDatabase, alias);
  }
}

class HeroValue extends DataClass implements Insertable<HeroValue> {
  final int id;
  final String heroId;
  final String key;
  final int? value;
  final int? maxValue;
  final double? doubleValue;
  final String? textValue;
  final String? jsonValue;
  final DateTime updatedAt;
  const HeroValue(
      {required this.id,
      required this.heroId,
      required this.key,
      this.value,
      this.maxValue,
      this.doubleValue,
      this.textValue,
      this.jsonValue,
      required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['hero_id'] = Variable<String>(heroId);
    map['key'] = Variable<String>(key);
    if (!nullToAbsent || value != null) {
      map['value'] = Variable<int>(value);
    }
    if (!nullToAbsent || maxValue != null) {
      map['max_value'] = Variable<int>(maxValue);
    }
    if (!nullToAbsent || doubleValue != null) {
      map['double_value'] = Variable<double>(doubleValue);
    }
    if (!nullToAbsent || textValue != null) {
      map['text_value'] = Variable<String>(textValue);
    }
    if (!nullToAbsent || jsonValue != null) {
      map['json_value'] = Variable<String>(jsonValue);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  HeroValuesCompanion toCompanion(bool nullToAbsent) {
    return HeroValuesCompanion(
      id: Value(id),
      heroId: Value(heroId),
      key: Value(key),
      value:
          value == null && nullToAbsent ? const Value.absent() : Value(value),
      maxValue: maxValue == null && nullToAbsent
          ? const Value.absent()
          : Value(maxValue),
      doubleValue: doubleValue == null && nullToAbsent
          ? const Value.absent()
          : Value(doubleValue),
      textValue: textValue == null && nullToAbsent
          ? const Value.absent()
          : Value(textValue),
      jsonValue: jsonValue == null && nullToAbsent
          ? const Value.absent()
          : Value(jsonValue),
      updatedAt: Value(updatedAt),
    );
  }

  factory HeroValue.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HeroValue(
      id: serializer.fromJson<int>(json['id']),
      heroId: serializer.fromJson<String>(json['heroId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<int?>(json['value']),
      maxValue: serializer.fromJson<int?>(json['maxValue']),
      doubleValue: serializer.fromJson<double?>(json['doubleValue']),
      textValue: serializer.fromJson<String?>(json['textValue']),
      jsonValue: serializer.fromJson<String?>(json['jsonValue']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'heroId': serializer.toJson<String>(heroId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<int?>(value),
      'maxValue': serializer.toJson<int?>(maxValue),
      'doubleValue': serializer.toJson<double?>(doubleValue),
      'textValue': serializer.toJson<String?>(textValue),
      'jsonValue': serializer.toJson<String?>(jsonValue),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  HeroValue copyWith(
          {int? id,
          String? heroId,
          String? key,
          Value<int?> value = const Value.absent(),
          Value<int?> maxValue = const Value.absent(),
          Value<double?> doubleValue = const Value.absent(),
          Value<String?> textValue = const Value.absent(),
          Value<String?> jsonValue = const Value.absent(),
          DateTime? updatedAt}) =>
      HeroValue(
        id: id ?? this.id,
        heroId: heroId ?? this.heroId,
        key: key ?? this.key,
        value: value.present ? value.value : this.value,
        maxValue: maxValue.present ? maxValue.value : this.maxValue,
        doubleValue: doubleValue.present ? doubleValue.value : this.doubleValue,
        textValue: textValue.present ? textValue.value : this.textValue,
        jsonValue: jsonValue.present ? jsonValue.value : this.jsonValue,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  HeroValue copyWithCompanion(HeroValuesCompanion data) {
    return HeroValue(
      id: data.id.present ? data.id.value : this.id,
      heroId: data.heroId.present ? data.heroId.value : this.heroId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      maxValue: data.maxValue.present ? data.maxValue.value : this.maxValue,
      doubleValue:
          data.doubleValue.present ? data.doubleValue.value : this.doubleValue,
      textValue: data.textValue.present ? data.textValue.value : this.textValue,
      jsonValue: data.jsonValue.present ? data.jsonValue.value : this.jsonValue,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HeroValue(')
          ..write('id: $id, ')
          ..write('heroId: $heroId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('maxValue: $maxValue, ')
          ..write('doubleValue: $doubleValue, ')
          ..write('textValue: $textValue, ')
          ..write('jsonValue: $jsonValue, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, heroId, key, value, maxValue, doubleValue,
      textValue, jsonValue, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HeroValue &&
          other.id == this.id &&
          other.heroId == this.heroId &&
          other.key == this.key &&
          other.value == this.value &&
          other.maxValue == this.maxValue &&
          other.doubleValue == this.doubleValue &&
          other.textValue == this.textValue &&
          other.jsonValue == this.jsonValue &&
          other.updatedAt == this.updatedAt);
}

class HeroValuesCompanion extends UpdateCompanion<HeroValue> {
  final Value<int> id;
  final Value<String> heroId;
  final Value<String> key;
  final Value<int?> value;
  final Value<int?> maxValue;
  final Value<double?> doubleValue;
  final Value<String?> textValue;
  final Value<String?> jsonValue;
  final Value<DateTime> updatedAt;
  const HeroValuesCompanion({
    this.id = const Value.absent(),
    this.heroId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.maxValue = const Value.absent(),
    this.doubleValue = const Value.absent(),
    this.textValue = const Value.absent(),
    this.jsonValue = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  HeroValuesCompanion.insert({
    this.id = const Value.absent(),
    required String heroId,
    required String key,
    this.value = const Value.absent(),
    this.maxValue = const Value.absent(),
    this.doubleValue = const Value.absent(),
    this.textValue = const Value.absent(),
    this.jsonValue = const Value.absent(),
    this.updatedAt = const Value.absent(),
  })  : heroId = Value(heroId),
        key = Value(key);
  static Insertable<HeroValue> custom({
    Expression<int>? id,
    Expression<String>? heroId,
    Expression<String>? key,
    Expression<int>? value,
    Expression<int>? maxValue,
    Expression<double>? doubleValue,
    Expression<String>? textValue,
    Expression<String>? jsonValue,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (heroId != null) 'hero_id': heroId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (maxValue != null) 'max_value': maxValue,
      if (doubleValue != null) 'double_value': doubleValue,
      if (textValue != null) 'text_value': textValue,
      if (jsonValue != null) 'json_value': jsonValue,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  HeroValuesCompanion copyWith(
      {Value<int>? id,
      Value<String>? heroId,
      Value<String>? key,
      Value<int?>? value,
      Value<int?>? maxValue,
      Value<double?>? doubleValue,
      Value<String?>? textValue,
      Value<String?>? jsonValue,
      Value<DateTime>? updatedAt}) {
    return HeroValuesCompanion(
      id: id ?? this.id,
      heroId: heroId ?? this.heroId,
      key: key ?? this.key,
      value: value ?? this.value,
      maxValue: maxValue ?? this.maxValue,
      doubleValue: doubleValue ?? this.doubleValue,
      textValue: textValue ?? this.textValue,
      jsonValue: jsonValue ?? this.jsonValue,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (heroId.present) {
      map['hero_id'] = Variable<String>(heroId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<int>(value.value);
    }
    if (maxValue.present) {
      map['max_value'] = Variable<int>(maxValue.value);
    }
    if (doubleValue.present) {
      map['double_value'] = Variable<double>(doubleValue.value);
    }
    if (textValue.present) {
      map['text_value'] = Variable<String>(textValue.value);
    }
    if (jsonValue.present) {
      map['json_value'] = Variable<String>(jsonValue.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HeroValuesCompanion(')
          ..write('id: $id, ')
          ..write('heroId: $heroId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('maxValue: $maxValue, ')
          ..write('doubleValue: $doubleValue, ')
          ..write('textValue: $textValue, ')
          ..write('jsonValue: $jsonValue, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $MetaEntriesTable extends MetaEntries
    with TableInfo<$MetaEntriesTable, MetaEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
      'key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
      'value', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta_entries';
  @override
  VerificationContext validateIntegrity(Insertable<MetaEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
          _keyMeta, key.isAcceptableOrUnknown(data['key']!, _keyMeta));
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
          _valueMeta, value.isAcceptableOrUnknown(data['value']!, _valueMeta));
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaEntry(
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
    );
  }

  @override
  $MetaEntriesTable createAlias(String alias) {
    return $MetaEntriesTable(attachedDatabase, alias);
  }
}

class MetaEntry extends DataClass implements Insertable<MetaEntry> {
  final String key;
  final String value;
  const MetaEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaEntriesCompanion toCompanion(bool nullToAbsent) {
    return MetaEntriesCompanion(
      key: Value(key),
      value: Value(value),
    );
  }

  factory MetaEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaEntry(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaEntry copyWith({String? key, String? value}) => MetaEntry(
        key: key ?? this.key,
        value: value ?? this.value,
      );
  MetaEntry copyWithCompanion(MetaEntriesCompanion data) {
    return MetaEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaEntry(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class MetaEntriesCompanion extends UpdateCompanion<MetaEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaEntriesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  })  : key = Value(key),
        value = Value(value);
  static Insertable<MetaEntry> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaEntriesCompanion copyWith(
      {Value<String>? key, Value<String>? value, Value<int>? rowid}) {
    return MetaEntriesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ComponentsTable components = $ComponentsTable(this);
  late final $HeroesTable heroes = $HeroesTable(this);
  late final $HeroComponentsTable heroComponents = $HeroComponentsTable(this);
  late final $HeroValuesTable heroValues = $HeroValuesTable(this);
  late final $MetaEntriesTable metaEntries = $MetaEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities =>
      [components, heroes, heroComponents, heroValues, metaEntries];
}

typedef $$ComponentsTableCreateCompanionBuilder = ComponentsCompanion Function({
  required String id,
  required String type,
  required String name,
  Value<String> dataJson,
  Value<String> source,
  Value<String?> parentId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$ComponentsTableUpdateCompanionBuilder = ComponentsCompanion Function({
  Value<String> id,
  Value<String> type,
  Value<String> name,
  Value<String> dataJson,
  Value<String> source,
  Value<String?> parentId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$ComponentsTableReferences
    extends BaseReferences<_$AppDatabase, $ComponentsTable, Component> {
  $$ComponentsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ComponentsTable _parentIdTable(_$AppDatabase db) =>
      db.components.createAlias(
          $_aliasNameGenerator(db.components.parentId, db.components.id));

  $$ComponentsTableProcessedTableManager? get parentId {
    final $_column = $_itemColumn<String>('parent_id');
    if ($_column == null) return null;
    final manager = $$ComponentsTableTableManager($_db, $_db.components)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_parentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$HeroesTable, List<Heroe>> _heroesRefsTable(
          _$AppDatabase db) =>
      MultiTypedResultKey.fromTable(db.heroes,
          aliasName: $_aliasNameGenerator(
              db.components.id, db.heroes.classComponentId));

  $$HeroesTableProcessedTableManager get heroesRefs {
    final manager = $$HeroesTableTableManager($_db, $_db.heroes).filter(
        (f) => f.classComponentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_heroesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$HeroComponentsTable, List<HeroComponent>>
      _heroComponentsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.heroComponents,
              aliasName: $_aliasNameGenerator(
                  db.components.id, db.heroComponents.componentId));

  $$HeroComponentsTableProcessedTableManager get heroComponentsRefs {
    final manager = $$HeroComponentsTableTableManager($_db, $_db.heroComponents)
        .filter((f) => f.componentId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_heroComponentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$ComponentsTableFilterComposer
    extends Composer<_$AppDatabase, $ComponentsTable> {
  $$ComponentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dataJson => $composableBuilder(
      column: $table.dataJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$ComponentsTableFilterComposer get parentId {
    final $$ComponentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.components,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ComponentsTableFilterComposer(
              $db: $db,
              $table: $db.components,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> heroesRefs(
      Expression<bool> Function($$HeroesTableFilterComposer f) f) {
    final $$HeroesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.heroes,
        getReferencedColumn: (t) => t.classComponentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroesTableFilterComposer(
              $db: $db,
              $table: $db.heroes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> heroComponentsRefs(
      Expression<bool> Function($$HeroComponentsTableFilterComposer f) f) {
    final $$HeroComponentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.heroComponents,
        getReferencedColumn: (t) => t.componentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroComponentsTableFilterComposer(
              $db: $db,
              $table: $db.heroComponents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ComponentsTableOrderingComposer
    extends Composer<_$AppDatabase, $ComponentsTable> {
  $$ComponentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get type => $composableBuilder(
      column: $table.type, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dataJson => $composableBuilder(
      column: $table.dataJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$ComponentsTableOrderingComposer get parentId {
    final $$ComponentsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.components,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ComponentsTableOrderingComposer(
              $db: $db,
              $table: $db.components,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$ComponentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ComponentsTable> {
  $$ComponentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get dataJson =>
      $composableBuilder(column: $table.dataJson, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ComponentsTableAnnotationComposer get parentId {
    final $$ComponentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.parentId,
        referencedTable: $db.components,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ComponentsTableAnnotationComposer(
              $db: $db,
              $table: $db.components,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> heroesRefs<T extends Object>(
      Expression<T> Function($$HeroesTableAnnotationComposer a) f) {
    final $$HeroesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.heroes,
        getReferencedColumn: (t) => t.classComponentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroesTableAnnotationComposer(
              $db: $db,
              $table: $db.heroes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> heroComponentsRefs<T extends Object>(
      Expression<T> Function($$HeroComponentsTableAnnotationComposer a) f) {
    final $$HeroComponentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.heroComponents,
        getReferencedColumn: (t) => t.componentId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroComponentsTableAnnotationComposer(
              $db: $db,
              $table: $db.heroComponents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$ComponentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ComponentsTable,
    Component,
    $$ComponentsTableFilterComposer,
    $$ComponentsTableOrderingComposer,
    $$ComponentsTableAnnotationComposer,
    $$ComponentsTableCreateCompanionBuilder,
    $$ComponentsTableUpdateCompanionBuilder,
    (Component, $$ComponentsTableReferences),
    Component,
    PrefetchHooks Function(
        {bool parentId, bool heroesRefs, bool heroComponentsRefs})> {
  $$ComponentsTableTableManager(_$AppDatabase db, $ComponentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ComponentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ComponentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ComponentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> type = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String> dataJson = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ComponentsCompanion(
            id: id,
            type: type,
            name: name,
            dataJson: dataJson,
            source: source,
            parentId: parentId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String type,
            required String name,
            Value<String> dataJson = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<String?> parentId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ComponentsCompanion.insert(
            id: id,
            type: type,
            name: name,
            dataJson: dataJson,
            source: source,
            parentId: parentId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$ComponentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: (
              {parentId = false,
              heroesRefs = false,
              heroComponentsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (heroesRefs) db.heroes,
                if (heroComponentsRefs) db.heroComponents
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (parentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.parentId,
                    referencedTable:
                        $$ComponentsTableReferences._parentIdTable(db),
                    referencedColumn:
                        $$ComponentsTableReferences._parentIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (heroesRefs)
                    await $_getPrefetchedData<Component, $ComponentsTable,
                            Heroe>(
                        currentTable: table,
                        referencedTable:
                            $$ComponentsTableReferences._heroesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ComponentsTableReferences(db, table, p0)
                                .heroesRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.classComponentId == item.id),
                        typedResults: items),
                  if (heroComponentsRefs)
                    await $_getPrefetchedData<Component, $ComponentsTable,
                            HeroComponent>(
                        currentTable: table,
                        referencedTable: $$ComponentsTableReferences
                            ._heroComponentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$ComponentsTableReferences(db, table, p0)
                                .heroComponentsRefs,
                        referencedItemsForCurrentItem:
                            (item, referencedItems) => referencedItems
                                .where((e) => e.componentId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$ComponentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ComponentsTable,
    Component,
    $$ComponentsTableFilterComposer,
    $$ComponentsTableOrderingComposer,
    $$ComponentsTableAnnotationComposer,
    $$ComponentsTableCreateCompanionBuilder,
    $$ComponentsTableUpdateCompanionBuilder,
    (Component, $$ComponentsTableReferences),
    Component,
    PrefetchHooks Function(
        {bool parentId, bool heroesRefs, bool heroComponentsRefs})>;
typedef $$HeroesTableCreateCompanionBuilder = HeroesCompanion Function({
  required String id,
  required String name,
  Value<String?> classComponentId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});
typedef $$HeroesTableUpdateCompanionBuilder = HeroesCompanion Function({
  Value<String> id,
  Value<String> name,
  Value<String?> classComponentId,
  Value<DateTime> createdAt,
  Value<DateTime> updatedAt,
  Value<int> rowid,
});

final class $$HeroesTableReferences
    extends BaseReferences<_$AppDatabase, $HeroesTable, Heroe> {
  $$HeroesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $ComponentsTable _classComponentIdTable(_$AppDatabase db) =>
      db.components.createAlias(
          $_aliasNameGenerator(db.heroes.classComponentId, db.components.id));

  $$ComponentsTableProcessedTableManager? get classComponentId {
    final $_column = $_itemColumn<String>('class_component_id');
    if ($_column == null) return null;
    final manager = $$ComponentsTableTableManager($_db, $_db.components)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_classComponentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static MultiTypedResultKey<$HeroComponentsTable, List<HeroComponent>>
      _heroComponentsRefsTable(_$AppDatabase db) =>
          MultiTypedResultKey.fromTable(db.heroComponents,
              aliasName:
                  $_aliasNameGenerator(db.heroes.id, db.heroComponents.heroId));

  $$HeroComponentsTableProcessedTableManager get heroComponentsRefs {
    final manager = $$HeroComponentsTableTableManager($_db, $_db.heroComponents)
        .filter((f) => f.heroId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_heroComponentsRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }

  static MultiTypedResultKey<$HeroValuesTable, List<HeroValue>>
      _heroValuesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
          db.heroValues,
          aliasName: $_aliasNameGenerator(db.heroes.id, db.heroValues.heroId));

  $$HeroValuesTableProcessedTableManager get heroValuesRefs {
    final manager = $$HeroValuesTableTableManager($_db, $_db.heroValues)
        .filter((f) => f.heroId.id.sqlEquals($_itemColumn<String>('id')!));

    final cache = $_typedResult.readTableOrNull(_heroValuesRefsTable($_db));
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: cache));
  }
}

class $$HeroesTableFilterComposer
    extends Composer<_$AppDatabase, $HeroesTable> {
  $$HeroesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$ComponentsTableFilterComposer get classComponentId {
    final $$ComponentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.classComponentId,
        referencedTable: $db.components,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ComponentsTableFilterComposer(
              $db: $db,
              $table: $db.components,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<bool> heroComponentsRefs(
      Expression<bool> Function($$HeroComponentsTableFilterComposer f) f) {
    final $$HeroComponentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.heroComponents,
        getReferencedColumn: (t) => t.heroId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroComponentsTableFilterComposer(
              $db: $db,
              $table: $db.heroComponents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<bool> heroValuesRefs(
      Expression<bool> Function($$HeroValuesTableFilterComposer f) f) {
    final $$HeroValuesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.heroValues,
        getReferencedColumn: (t) => t.heroId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroValuesTableFilterComposer(
              $db: $db,
              $table: $db.heroValues,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$HeroesTableOrderingComposer
    extends Composer<_$AppDatabase, $HeroesTable> {
  $$HeroesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$ComponentsTableOrderingComposer get classComponentId {
    final $$ComponentsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.classComponentId,
        referencedTable: $db.components,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ComponentsTableOrderingComposer(
              $db: $db,
              $table: $db.components,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HeroesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HeroesTable> {
  $$HeroesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$ComponentsTableAnnotationComposer get classComponentId {
    final $$ComponentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.classComponentId,
        referencedTable: $db.components,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ComponentsTableAnnotationComposer(
              $db: $db,
              $table: $db.components,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  Expression<T> heroComponentsRefs<T extends Object>(
      Expression<T> Function($$HeroComponentsTableAnnotationComposer a) f) {
    final $$HeroComponentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.heroComponents,
        getReferencedColumn: (t) => t.heroId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroComponentsTableAnnotationComposer(
              $db: $db,
              $table: $db.heroComponents,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }

  Expression<T> heroValuesRefs<T extends Object>(
      Expression<T> Function($$HeroValuesTableAnnotationComposer a) f) {
    final $$HeroValuesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.id,
        referencedTable: $db.heroValues,
        getReferencedColumn: (t) => t.heroId,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroValuesTableAnnotationComposer(
              $db: $db,
              $table: $db.heroValues,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return f(composer);
  }
}

class $$HeroesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HeroesTable,
    Heroe,
    $$HeroesTableFilterComposer,
    $$HeroesTableOrderingComposer,
    $$HeroesTableAnnotationComposer,
    $$HeroesTableCreateCompanionBuilder,
    $$HeroesTableUpdateCompanionBuilder,
    (Heroe, $$HeroesTableReferences),
    Heroe,
    PrefetchHooks Function(
        {bool classComponentId,
        bool heroComponentsRefs,
        bool heroValuesRefs})> {
  $$HeroesTableTableManager(_$AppDatabase db, $HeroesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeroesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeroesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeroesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> classComponentId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HeroesCompanion(
            id: id,
            name: name,
            classComponentId: classComponentId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String name,
            Value<String?> classComponentId = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HeroesCompanion.insert(
            id: id,
            name: name,
            classComponentId: classComponentId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) =>
                  (e.readTable(table), $$HeroesTableReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: (
              {classComponentId = false,
              heroComponentsRefs = false,
              heroValuesRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [
                if (heroComponentsRefs) db.heroComponents,
                if (heroValuesRefs) db.heroValues
              ],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (classComponentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.classComponentId,
                    referencedTable:
                        $$HeroesTableReferences._classComponentIdTable(db),
                    referencedColumn:
                        $$HeroesTableReferences._classComponentIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (heroComponentsRefs)
                    await $_getPrefetchedData<Heroe, $HeroesTable,
                            HeroComponent>(
                        currentTable: table,
                        referencedTable: $$HeroesTableReferences
                            ._heroComponentsRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$HeroesTableReferences(db, table, p0)
                                .heroComponentsRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.heroId == item.id),
                        typedResults: items),
                  if (heroValuesRefs)
                    await $_getPrefetchedData<Heroe, $HeroesTable, HeroValue>(
                        currentTable: table,
                        referencedTable:
                            $$HeroesTableReferences._heroValuesRefsTable(db),
                        managerFromTypedResult: (p0) =>
                            $$HeroesTableReferences(db, table, p0)
                                .heroValuesRefs,
                        referencedItemsForCurrentItem: (item,
                                referencedItems) =>
                            referencedItems.where((e) => e.heroId == item.id),
                        typedResults: items)
                ];
              },
            );
          },
        ));
}

typedef $$HeroesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HeroesTable,
    Heroe,
    $$HeroesTableFilterComposer,
    $$HeroesTableOrderingComposer,
    $$HeroesTableAnnotationComposer,
    $$HeroesTableCreateCompanionBuilder,
    $$HeroesTableUpdateCompanionBuilder,
    (Heroe, $$HeroesTableReferences),
    Heroe,
    PrefetchHooks Function(
        {bool classComponentId, bool heroComponentsRefs, bool heroValuesRefs})>;
typedef $$HeroComponentsTableCreateCompanionBuilder = HeroComponentsCompanion
    Function({
  Value<int> autoId,
  required String heroId,
  required String componentId,
  Value<String> category,
  Value<DateTime> createdAt,
});
typedef $$HeroComponentsTableUpdateCompanionBuilder = HeroComponentsCompanion
    Function({
  Value<int> autoId,
  Value<String> heroId,
  Value<String> componentId,
  Value<String> category,
  Value<DateTime> createdAt,
});

final class $$HeroComponentsTableReferences
    extends BaseReferences<_$AppDatabase, $HeroComponentsTable, HeroComponent> {
  $$HeroComponentsTableReferences(
      super.$_db, super.$_table, super.$_typedResult);

  static $HeroesTable _heroIdTable(_$AppDatabase db) => db.heroes.createAlias(
      $_aliasNameGenerator(db.heroComponents.heroId, db.heroes.id));

  $$HeroesTableProcessedTableManager get heroId {
    final $_column = $_itemColumn<String>('hero_id')!;

    final manager = $$HeroesTableTableManager($_db, $_db.heroes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_heroIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }

  static $ComponentsTable _componentIdTable(_$AppDatabase db) =>
      db.components.createAlias($_aliasNameGenerator(
          db.heroComponents.componentId, db.components.id));

  $$ComponentsTableProcessedTableManager get componentId {
    final $_column = $_itemColumn<String>('component_id')!;

    final manager = $$ComponentsTableTableManager($_db, $_db.components)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_componentIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$HeroComponentsTableFilterComposer
    extends Composer<_$AppDatabase, $HeroComponentsTable> {
  $$HeroComponentsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get autoId => $composableBuilder(
      column: $table.autoId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  $$HeroesTableFilterComposer get heroId {
    final $$HeroesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.heroId,
        referencedTable: $db.heroes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroesTableFilterComposer(
              $db: $db,
              $table: $db.heroes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ComponentsTableFilterComposer get componentId {
    final $$ComponentsTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.componentId,
        referencedTable: $db.components,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ComponentsTableFilterComposer(
              $db: $db,
              $table: $db.components,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HeroComponentsTableOrderingComposer
    extends Composer<_$AppDatabase, $HeroComponentsTable> {
  $$HeroComponentsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get autoId => $composableBuilder(
      column: $table.autoId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  $$HeroesTableOrderingComposer get heroId {
    final $$HeroesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.heroId,
        referencedTable: $db.heroes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroesTableOrderingComposer(
              $db: $db,
              $table: $db.heroes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ComponentsTableOrderingComposer get componentId {
    final $$ComponentsTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.componentId,
        referencedTable: $db.components,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ComponentsTableOrderingComposer(
              $db: $db,
              $table: $db.components,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HeroComponentsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HeroComponentsTable> {
  $$HeroComponentsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get autoId =>
      $composableBuilder(column: $table.autoId, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$HeroesTableAnnotationComposer get heroId {
    final $$HeroesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.heroId,
        referencedTable: $db.heroes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroesTableAnnotationComposer(
              $db: $db,
              $table: $db.heroes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }

  $$ComponentsTableAnnotationComposer get componentId {
    final $$ComponentsTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.componentId,
        referencedTable: $db.components,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$ComponentsTableAnnotationComposer(
              $db: $db,
              $table: $db.components,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HeroComponentsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HeroComponentsTable,
    HeroComponent,
    $$HeroComponentsTableFilterComposer,
    $$HeroComponentsTableOrderingComposer,
    $$HeroComponentsTableAnnotationComposer,
    $$HeroComponentsTableCreateCompanionBuilder,
    $$HeroComponentsTableUpdateCompanionBuilder,
    (HeroComponent, $$HeroComponentsTableReferences),
    HeroComponent,
    PrefetchHooks Function({bool heroId, bool componentId})> {
  $$HeroComponentsTableTableManager(
      _$AppDatabase db, $HeroComponentsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeroComponentsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeroComponentsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeroComponentsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> autoId = const Value.absent(),
            Value<String> heroId = const Value.absent(),
            Value<String> componentId = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              HeroComponentsCompanion(
            autoId: autoId,
            heroId: heroId,
            componentId: componentId,
            category: category,
            createdAt: createdAt,
          ),
          createCompanionCallback: ({
            Value<int> autoId = const Value.absent(),
            required String heroId,
            required String componentId,
            Value<String> category = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
          }) =>
              HeroComponentsCompanion.insert(
            autoId: autoId,
            heroId: heroId,
            componentId: componentId,
            category: category,
            createdAt: createdAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$HeroComponentsTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({heroId = false, componentId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (heroId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.heroId,
                    referencedTable:
                        $$HeroComponentsTableReferences._heroIdTable(db),
                    referencedColumn:
                        $$HeroComponentsTableReferences._heroIdTable(db).id,
                  ) as T;
                }
                if (componentId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.componentId,
                    referencedTable:
                        $$HeroComponentsTableReferences._componentIdTable(db),
                    referencedColumn: $$HeroComponentsTableReferences
                        ._componentIdTable(db)
                        .id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$HeroComponentsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HeroComponentsTable,
    HeroComponent,
    $$HeroComponentsTableFilterComposer,
    $$HeroComponentsTableOrderingComposer,
    $$HeroComponentsTableAnnotationComposer,
    $$HeroComponentsTableCreateCompanionBuilder,
    $$HeroComponentsTableUpdateCompanionBuilder,
    (HeroComponent, $$HeroComponentsTableReferences),
    HeroComponent,
    PrefetchHooks Function({bool heroId, bool componentId})>;
typedef $$HeroValuesTableCreateCompanionBuilder = HeroValuesCompanion Function({
  Value<int> id,
  required String heroId,
  required String key,
  Value<int?> value,
  Value<int?> maxValue,
  Value<double?> doubleValue,
  Value<String?> textValue,
  Value<String?> jsonValue,
  Value<DateTime> updatedAt,
});
typedef $$HeroValuesTableUpdateCompanionBuilder = HeroValuesCompanion Function({
  Value<int> id,
  Value<String> heroId,
  Value<String> key,
  Value<int?> value,
  Value<int?> maxValue,
  Value<double?> doubleValue,
  Value<String?> textValue,
  Value<String?> jsonValue,
  Value<DateTime> updatedAt,
});

final class $$HeroValuesTableReferences
    extends BaseReferences<_$AppDatabase, $HeroValuesTable, HeroValue> {
  $$HeroValuesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $HeroesTable _heroIdTable(_$AppDatabase db) => db.heroes
      .createAlias($_aliasNameGenerator(db.heroValues.heroId, db.heroes.id));

  $$HeroesTableProcessedTableManager get heroId {
    final $_column = $_itemColumn<String>('hero_id')!;

    final manager = $$HeroesTableTableManager($_db, $_db.heroes)
        .filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_heroIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
        manager.$state.copyWith(prefetchedData: [item]));
  }
}

class $$HeroValuesTableFilterComposer
    extends Composer<_$AppDatabase, $HeroValuesTable> {
  $$HeroValuesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get maxValue => $composableBuilder(
      column: $table.maxValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get doubleValue => $composableBuilder(
      column: $table.doubleValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get textValue => $composableBuilder(
      column: $table.textValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get jsonValue => $composableBuilder(
      column: $table.jsonValue, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  $$HeroesTableFilterComposer get heroId {
    final $$HeroesTableFilterComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.heroId,
        referencedTable: $db.heroes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroesTableFilterComposer(
              $db: $db,
              $table: $db.heroes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HeroValuesTableOrderingComposer
    extends Composer<_$AppDatabase, $HeroValuesTable> {
  $$HeroValuesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get maxValue => $composableBuilder(
      column: $table.maxValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get doubleValue => $composableBuilder(
      column: $table.doubleValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get textValue => $composableBuilder(
      column: $table.textValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get jsonValue => $composableBuilder(
      column: $table.jsonValue, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  $$HeroesTableOrderingComposer get heroId {
    final $$HeroesTableOrderingComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.heroId,
        referencedTable: $db.heroes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroesTableOrderingComposer(
              $db: $db,
              $table: $db.heroes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HeroValuesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HeroValuesTable> {
  $$HeroValuesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<int> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<int> get maxValue =>
      $composableBuilder(column: $table.maxValue, builder: (column) => column);

  GeneratedColumn<double> get doubleValue => $composableBuilder(
      column: $table.doubleValue, builder: (column) => column);

  GeneratedColumn<String> get textValue =>
      $composableBuilder(column: $table.textValue, builder: (column) => column);

  GeneratedColumn<String> get jsonValue =>
      $composableBuilder(column: $table.jsonValue, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$HeroesTableAnnotationComposer get heroId {
    final $$HeroesTableAnnotationComposer composer = $composerBuilder(
        composer: this,
        getCurrentColumn: (t) => t.heroId,
        referencedTable: $db.heroes,
        getReferencedColumn: (t) => t.id,
        builder: (joinBuilder,
                {$addJoinBuilderToRootComposer,
                $removeJoinBuilderFromRootComposer}) =>
            $$HeroesTableAnnotationComposer(
              $db: $db,
              $table: $db.heroes,
              $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
              joinBuilder: joinBuilder,
              $removeJoinBuilderFromRootComposer:
                  $removeJoinBuilderFromRootComposer,
            ));
    return composer;
  }
}

class $$HeroValuesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HeroValuesTable,
    HeroValue,
    $$HeroValuesTableFilterComposer,
    $$HeroValuesTableOrderingComposer,
    $$HeroValuesTableAnnotationComposer,
    $$HeroValuesTableCreateCompanionBuilder,
    $$HeroValuesTableUpdateCompanionBuilder,
    (HeroValue, $$HeroValuesTableReferences),
    HeroValue,
    PrefetchHooks Function({bool heroId})> {
  $$HeroValuesTableTableManager(_$AppDatabase db, $HeroValuesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HeroValuesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HeroValuesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HeroValuesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> heroId = const Value.absent(),
            Value<String> key = const Value.absent(),
            Value<int?> value = const Value.absent(),
            Value<int?> maxValue = const Value.absent(),
            Value<double?> doubleValue = const Value.absent(),
            Value<String?> textValue = const Value.absent(),
            Value<String?> jsonValue = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              HeroValuesCompanion(
            id: id,
            heroId: heroId,
            key: key,
            value: value,
            maxValue: maxValue,
            doubleValue: doubleValue,
            textValue: textValue,
            jsonValue: jsonValue,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String heroId,
            required String key,
            Value<int?> value = const Value.absent(),
            Value<int?> maxValue = const Value.absent(),
            Value<double?> doubleValue = const Value.absent(),
            Value<String?> textValue = const Value.absent(),
            Value<String?> jsonValue = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              HeroValuesCompanion.insert(
            id: id,
            heroId: heroId,
            key: key,
            value: value,
            maxValue: maxValue,
            doubleValue: doubleValue,
            textValue: textValue,
            jsonValue: jsonValue,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (
                    e.readTable(table),
                    $$HeroValuesTableReferences(db, table, e)
                  ))
              .toList(),
          prefetchHooksCallback: ({heroId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins: <
                  T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic>>(state) {
                if (heroId) {
                  state = state.withJoin(
                    currentTable: table,
                    currentColumn: table.heroId,
                    referencedTable:
                        $$HeroValuesTableReferences._heroIdTable(db),
                    referencedColumn:
                        $$HeroValuesTableReferences._heroIdTable(db).id,
                  ) as T;
                }

                return state;
              },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ));
}

typedef $$HeroValuesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HeroValuesTable,
    HeroValue,
    $$HeroValuesTableFilterComposer,
    $$HeroValuesTableOrderingComposer,
    $$HeroValuesTableAnnotationComposer,
    $$HeroValuesTableCreateCompanionBuilder,
    $$HeroValuesTableUpdateCompanionBuilder,
    (HeroValue, $$HeroValuesTableReferences),
    HeroValue,
    PrefetchHooks Function({bool heroId})>;
typedef $$MetaEntriesTableCreateCompanionBuilder = MetaEntriesCompanion
    Function({
  required String key,
  required String value,
  Value<int> rowid,
});
typedef $$MetaEntriesTableUpdateCompanionBuilder = MetaEntriesCompanion
    Function({
  Value<String> key,
  Value<String> value,
  Value<int> rowid,
});

class $$MetaEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));
}

class $$MetaEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));
}

class $$MetaEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaEntriesTable> {
  $$MetaEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MetaEntriesTable,
    MetaEntry,
    $$MetaEntriesTableFilterComposer,
    $$MetaEntriesTableOrderingComposer,
    $$MetaEntriesTableAnnotationComposer,
    $$MetaEntriesTableCreateCompanionBuilder,
    $$MetaEntriesTableUpdateCompanionBuilder,
    (MetaEntry, BaseReferences<_$AppDatabase, $MetaEntriesTable, MetaEntry>),
    MetaEntry,
    PrefetchHooks Function()> {
  $$MetaEntriesTableTableManager(_$AppDatabase db, $MetaEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              MetaEntriesCompanion(
            key: key,
            value: value,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String key,
            required String value,
            Value<int> rowid = const Value.absent(),
          }) =>
              MetaEntriesCompanion.insert(
            key: key,
            value: value,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MetaEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MetaEntriesTable,
    MetaEntry,
    $$MetaEntriesTableFilterComposer,
    $$MetaEntriesTableOrderingComposer,
    $$MetaEntriesTableAnnotationComposer,
    $$MetaEntriesTableCreateCompanionBuilder,
    $$MetaEntriesTableUpdateCompanionBuilder,
    (MetaEntry, BaseReferences<_$AppDatabase, $MetaEntriesTable, MetaEntry>),
    MetaEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ComponentsTableTableManager get components =>
      $$ComponentsTableTableManager(_db, _db.components);
  $$HeroesTableTableManager get heroes =>
      $$HeroesTableTableManager(_db, _db.heroes);
  $$HeroComponentsTableTableManager get heroComponents =>
      $$HeroComponentsTableTableManager(_db, _db.heroComponents);
  $$HeroValuesTableTableManager get heroValues =>
      $$HeroValuesTableTableManager(_db, _db.heroValues);
  $$MetaEntriesTableTableManager get metaEntries =>
      $$MetaEntriesTableTableManager(_db, _db.metaEntries);
}
