// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'catalog_database.dart';

// ignore_for_file: type=lint
class $SettingEntriesTable extends SettingEntries
    with TableInfo<$SettingEntriesTable, SettingEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SettingEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'setting_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<SettingEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  SettingEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SettingEntry(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $SettingEntriesTable createAlias(String alias) {
    return $SettingEntriesTable(attachedDatabase, alias);
  }
}

class SettingEntry extends DataClass implements Insertable<SettingEntry> {
  final String key;
  final String value;
  const SettingEntry({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  SettingEntriesCompanion toCompanion(bool nullToAbsent) {
    return SettingEntriesCompanion(key: Value(key), value: Value(value));
  }

  factory SettingEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SettingEntry(
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

  SettingEntry copyWith({String? key, String? value}) =>
      SettingEntry(key: key ?? this.key, value: value ?? this.value);
  SettingEntry copyWithCompanion(SettingEntriesCompanion data) {
    return SettingEntry(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SettingEntry(')
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
      (other is SettingEntry &&
          other.key == this.key &&
          other.value == this.value);
}

class SettingEntriesCompanion extends UpdateCompanion<SettingEntry> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const SettingEntriesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SettingEntriesCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<SettingEntry> custom({
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

  SettingEntriesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return SettingEntriesCompanion(
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
    return (StringBuffer('SettingEntriesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $BookmarkEntriesTable extends BookmarkEntries
    with TableInfo<$BookmarkEntriesTable, BookmarkEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $BookmarkEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addedAtMeta = const VerificationMeta(
    'addedAt',
  );
  @override
  late final GeneratedColumn<DateTime> addedAt = GeneratedColumn<DateTime>(
    'added_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, name, addedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'bookmark_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<BookmarkEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('added_at')) {
      context.handle(
        _addedAtMeta,
        addedAt.isAcceptableOrUnknown(data['added_at']!, _addedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_addedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  BookmarkEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return BookmarkEntry(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      addedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}added_at'],
      )!,
    );
  }

  @override
  $BookmarkEntriesTable createAlias(String alias) {
    return $BookmarkEntriesTable(attachedDatabase, alias);
  }
}

class BookmarkEntry extends DataClass implements Insertable<BookmarkEntry> {
  final String path;
  final String name;
  final DateTime addedAt;
  const BookmarkEntry({
    required this.path,
    required this.name,
    required this.addedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['name'] = Variable<String>(name);
    map['added_at'] = Variable<DateTime>(addedAt);
    return map;
  }

  BookmarkEntriesCompanion toCompanion(bool nullToAbsent) {
    return BookmarkEntriesCompanion(
      path: Value(path),
      name: Value(name),
      addedAt: Value(addedAt),
    );
  }

  factory BookmarkEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return BookmarkEntry(
      path: serializer.fromJson<String>(json['path']),
      name: serializer.fromJson<String>(json['name']),
      addedAt: serializer.fromJson<DateTime>(json['addedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'name': serializer.toJson<String>(name),
      'addedAt': serializer.toJson<DateTime>(addedAt),
    };
  }

  BookmarkEntry copyWith({String? path, String? name, DateTime? addedAt}) =>
      BookmarkEntry(
        path: path ?? this.path,
        name: name ?? this.name,
        addedAt: addedAt ?? this.addedAt,
      );
  BookmarkEntry copyWithCompanion(BookmarkEntriesCompanion data) {
    return BookmarkEntry(
      path: data.path.present ? data.path.value : this.path,
      name: data.name.present ? data.name.value : this.name,
      addedAt: data.addedAt.present ? data.addedAt.value : this.addedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkEntry(')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('addedAt: $addedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, name, addedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is BookmarkEntry &&
          other.path == this.path &&
          other.name == this.name &&
          other.addedAt == this.addedAt);
}

class BookmarkEntriesCompanion extends UpdateCompanion<BookmarkEntry> {
  final Value<String> path;
  final Value<String> name;
  final Value<DateTime> addedAt;
  final Value<int> rowid;
  const BookmarkEntriesCompanion({
    this.path = const Value.absent(),
    this.name = const Value.absent(),
    this.addedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  BookmarkEntriesCompanion.insert({
    required String path,
    required String name,
    required DateTime addedAt,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       name = Value(name),
       addedAt = Value(addedAt);
  static Insertable<BookmarkEntry> custom({
    Expression<String>? path,
    Expression<String>? name,
    Expression<DateTime>? addedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (name != null) 'name': name,
      if (addedAt != null) 'added_at': addedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  BookmarkEntriesCompanion copyWith({
    Value<String>? path,
    Value<String>? name,
    Value<DateTime>? addedAt,
    Value<int>? rowid,
  }) {
    return BookmarkEntriesCompanion(
      path: path ?? this.path,
      name: name ?? this.name,
      addedAt: addedAt ?? this.addedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (addedAt.present) {
      map['added_at'] = Variable<DateTime>(addedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('BookmarkEntriesCompanion(')
          ..write('path: $path, ')
          ..write('name: $name, ')
          ..write('addedAt: $addedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VisitEntriesTable extends VisitEntries
    with TableInfo<$VisitEntriesTable, VisitEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VisitEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _visitedAtMeta = const VerificationMeta(
    'visitedAt',
  );
  @override
  late final GeneratedColumn<DateTime> visitedAt = GeneratedColumn<DateTime>(
    'visited_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [path, visitedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'visit_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<VisitEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('visited_at')) {
      context.handle(
        _visitedAtMeta,
        visitedAt.isAcceptableOrUnknown(data['visited_at']!, _visitedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_visitedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  VisitEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VisitEntry(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      visitedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}visited_at'],
      )!,
    );
  }

  @override
  $VisitEntriesTable createAlias(String alias) {
    return $VisitEntriesTable(attachedDatabase, alias);
  }
}

class VisitEntry extends DataClass implements Insertable<VisitEntry> {
  final String path;
  final DateTime visitedAt;
  const VisitEntry({required this.path, required this.visitedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['visited_at'] = Variable<DateTime>(visitedAt);
    return map;
  }

  VisitEntriesCompanion toCompanion(bool nullToAbsent) {
    return VisitEntriesCompanion(
      path: Value(path),
      visitedAt: Value(visitedAt),
    );
  }

  factory VisitEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VisitEntry(
      path: serializer.fromJson<String>(json['path']),
      visitedAt: serializer.fromJson<DateTime>(json['visitedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'visitedAt': serializer.toJson<DateTime>(visitedAt),
    };
  }

  VisitEntry copyWith({String? path, DateTime? visitedAt}) => VisitEntry(
    path: path ?? this.path,
    visitedAt: visitedAt ?? this.visitedAt,
  );
  VisitEntry copyWithCompanion(VisitEntriesCompanion data) {
    return VisitEntry(
      path: data.path.present ? data.path.value : this.path,
      visitedAt: data.visitedAt.present ? data.visitedAt.value : this.visitedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VisitEntry(')
          ..write('path: $path, ')
          ..write('visitedAt: $visitedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(path, visitedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VisitEntry &&
          other.path == this.path &&
          other.visitedAt == this.visitedAt);
}

class VisitEntriesCompanion extends UpdateCompanion<VisitEntry> {
  final Value<String> path;
  final Value<DateTime> visitedAt;
  final Value<int> rowid;
  const VisitEntriesCompanion({
    this.path = const Value.absent(),
    this.visitedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  VisitEntriesCompanion.insert({
    required String path,
    required DateTime visitedAt,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       visitedAt = Value(visitedAt);
  static Insertable<VisitEntry> custom({
    Expression<String>? path,
    Expression<DateTime>? visitedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (visitedAt != null) 'visited_at': visitedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  VisitEntriesCompanion copyWith({
    Value<String>? path,
    Value<DateTime>? visitedAt,
    Value<int>? rowid,
  }) {
    return VisitEntriesCompanion(
      path: path ?? this.path,
      visitedAt: visitedAt ?? this.visitedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (visitedAt.present) {
      map['visited_at'] = Variable<DateTime>(visitedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VisitEntriesCompanion(')
          ..write('path: $path, ')
          ..write('visitedAt: $visitedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CachedAssetEntriesTable extends CachedAssetEntries
    with TableInfo<$CachedAssetEntriesTable, CachedAssetEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CachedAssetEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pathMeta = const VerificationMeta('path');
  @override
  late final GeneratedColumn<String> path = GeneratedColumn<String>(
    'path',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeMeta = const VerificationMeta('size');
  @override
  late final GeneratedColumn<int> size = GeneratedColumn<int>(
    'size',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fileModifiedAtMeta = const VerificationMeta(
    'fileModifiedAt',
  );
  @override
  late final GeneratedColumn<DateTime> fileModifiedAt =
      GeneratedColumn<DateTime>(
        'file_modified_at',
        aliasedName,
        false,
        type: DriftSqlType.dateTime,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _summaryMeta = const VerificationMeta(
    'summary',
  );
  @override
  late final GeneratedColumn<String> summary = GeneratedColumn<String>(
    'summary',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thumbnailMeta = const VerificationMeta(
    'thumbnail',
  );
  @override
  late final GeneratedColumn<Uint8List> thumbnail = GeneratedColumn<Uint8List>(
    'thumbnail',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _errorMeta = const VerificationMeta('error');
  @override
  late final GeneratedColumn<String> error = GeneratedColumn<String>(
    'error',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _perceptualHashMeta = const VerificationMeta(
    'perceptualHash',
  );
  @override
  late final GeneratedColumn<int> perceptualHash = GeneratedColumn<int>(
    'perceptual_hash',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    path,
    size,
    fileModifiedAt,
    summary,
    thumbnail,
    error,
    perceptualHash,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'cached_asset_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<CachedAssetEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('path')) {
      context.handle(
        _pathMeta,
        path.isAcceptableOrUnknown(data['path']!, _pathMeta),
      );
    } else if (isInserting) {
      context.missing(_pathMeta);
    }
    if (data.containsKey('size')) {
      context.handle(
        _sizeMeta,
        size.isAcceptableOrUnknown(data['size']!, _sizeMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeMeta);
    }
    if (data.containsKey('file_modified_at')) {
      context.handle(
        _fileModifiedAtMeta,
        fileModifiedAt.isAcceptableOrUnknown(
          data['file_modified_at']!,
          _fileModifiedAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_fileModifiedAtMeta);
    }
    if (data.containsKey('summary')) {
      context.handle(
        _summaryMeta,
        summary.isAcceptableOrUnknown(data['summary']!, _summaryMeta),
      );
    }
    if (data.containsKey('thumbnail')) {
      context.handle(
        _thumbnailMeta,
        thumbnail.isAcceptableOrUnknown(data['thumbnail']!, _thumbnailMeta),
      );
    }
    if (data.containsKey('error')) {
      context.handle(
        _errorMeta,
        error.isAcceptableOrUnknown(data['error']!, _errorMeta),
      );
    }
    if (data.containsKey('perceptual_hash')) {
      context.handle(
        _perceptualHashMeta,
        perceptualHash.isAcceptableOrUnknown(
          data['perceptual_hash']!,
          _perceptualHashMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {path};
  @override
  CachedAssetEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CachedAssetEntry(
      path: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}path'],
      )!,
      size: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size'],
      )!,
      fileModifiedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}file_modified_at'],
      )!,
      summary: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}summary'],
      ),
      thumbnail: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}thumbnail'],
      ),
      error: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}error'],
      ),
      perceptualHash: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}perceptual_hash'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $CachedAssetEntriesTable createAlias(String alias) {
    return $CachedAssetEntriesTable(attachedDatabase, alias);
  }
}

class CachedAssetEntry extends DataClass
    implements Insertable<CachedAssetEntry> {
  final String path;
  final int size;
  final DateTime fileModifiedAt;

  /// 要約の JSON。読めなかった対象では null。
  final String? summary;
  final Uint8List? thumbnail;
  final String? error;
  final int? perceptualHash;
  final DateTime updatedAt;
  const CachedAssetEntry({
    required this.path,
    required this.size,
    required this.fileModifiedAt,
    this.summary,
    this.thumbnail,
    this.error,
    this.perceptualHash,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['path'] = Variable<String>(path);
    map['size'] = Variable<int>(size);
    map['file_modified_at'] = Variable<DateTime>(fileModifiedAt);
    if (!nullToAbsent || summary != null) {
      map['summary'] = Variable<String>(summary);
    }
    if (!nullToAbsent || thumbnail != null) {
      map['thumbnail'] = Variable<Uint8List>(thumbnail);
    }
    if (!nullToAbsent || error != null) {
      map['error'] = Variable<String>(error);
    }
    if (!nullToAbsent || perceptualHash != null) {
      map['perceptual_hash'] = Variable<int>(perceptualHash);
    }
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  CachedAssetEntriesCompanion toCompanion(bool nullToAbsent) {
    return CachedAssetEntriesCompanion(
      path: Value(path),
      size: Value(size),
      fileModifiedAt: Value(fileModifiedAt),
      summary: summary == null && nullToAbsent
          ? const Value.absent()
          : Value(summary),
      thumbnail: thumbnail == null && nullToAbsent
          ? const Value.absent()
          : Value(thumbnail),
      error: error == null && nullToAbsent
          ? const Value.absent()
          : Value(error),
      perceptualHash: perceptualHash == null && nullToAbsent
          ? const Value.absent()
          : Value(perceptualHash),
      updatedAt: Value(updatedAt),
    );
  }

  factory CachedAssetEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CachedAssetEntry(
      path: serializer.fromJson<String>(json['path']),
      size: serializer.fromJson<int>(json['size']),
      fileModifiedAt: serializer.fromJson<DateTime>(json['fileModifiedAt']),
      summary: serializer.fromJson<String?>(json['summary']),
      thumbnail: serializer.fromJson<Uint8List?>(json['thumbnail']),
      error: serializer.fromJson<String?>(json['error']),
      perceptualHash: serializer.fromJson<int?>(json['perceptualHash']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'path': serializer.toJson<String>(path),
      'size': serializer.toJson<int>(size),
      'fileModifiedAt': serializer.toJson<DateTime>(fileModifiedAt),
      'summary': serializer.toJson<String?>(summary),
      'thumbnail': serializer.toJson<Uint8List?>(thumbnail),
      'error': serializer.toJson<String?>(error),
      'perceptualHash': serializer.toJson<int?>(perceptualHash),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  CachedAssetEntry copyWith({
    String? path,
    int? size,
    DateTime? fileModifiedAt,
    Value<String?> summary = const Value.absent(),
    Value<Uint8List?> thumbnail = const Value.absent(),
    Value<String?> error = const Value.absent(),
    Value<int?> perceptualHash = const Value.absent(),
    DateTime? updatedAt,
  }) => CachedAssetEntry(
    path: path ?? this.path,
    size: size ?? this.size,
    fileModifiedAt: fileModifiedAt ?? this.fileModifiedAt,
    summary: summary.present ? summary.value : this.summary,
    thumbnail: thumbnail.present ? thumbnail.value : this.thumbnail,
    error: error.present ? error.value : this.error,
    perceptualHash: perceptualHash.present
        ? perceptualHash.value
        : this.perceptualHash,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  CachedAssetEntry copyWithCompanion(CachedAssetEntriesCompanion data) {
    return CachedAssetEntry(
      path: data.path.present ? data.path.value : this.path,
      size: data.size.present ? data.size.value : this.size,
      fileModifiedAt: data.fileModifiedAt.present
          ? data.fileModifiedAt.value
          : this.fileModifiedAt,
      summary: data.summary.present ? data.summary.value : this.summary,
      thumbnail: data.thumbnail.present ? data.thumbnail.value : this.thumbnail,
      error: data.error.present ? data.error.value : this.error,
      perceptualHash: data.perceptualHash.present
          ? data.perceptualHash.value
          : this.perceptualHash,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CachedAssetEntry(')
          ..write('path: $path, ')
          ..write('size: $size, ')
          ..write('fileModifiedAt: $fileModifiedAt, ')
          ..write('summary: $summary, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('error: $error, ')
          ..write('perceptualHash: $perceptualHash, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    path,
    size,
    fileModifiedAt,
    summary,
    $driftBlobEquality.hash(thumbnail),
    error,
    perceptualHash,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CachedAssetEntry &&
          other.path == this.path &&
          other.size == this.size &&
          other.fileModifiedAt == this.fileModifiedAt &&
          other.summary == this.summary &&
          $driftBlobEquality.equals(other.thumbnail, this.thumbnail) &&
          other.error == this.error &&
          other.perceptualHash == this.perceptualHash &&
          other.updatedAt == this.updatedAt);
}

class CachedAssetEntriesCompanion extends UpdateCompanion<CachedAssetEntry> {
  final Value<String> path;
  final Value<int> size;
  final Value<DateTime> fileModifiedAt;
  final Value<String?> summary;
  final Value<Uint8List?> thumbnail;
  final Value<String?> error;
  final Value<int?> perceptualHash;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const CachedAssetEntriesCompanion({
    this.path = const Value.absent(),
    this.size = const Value.absent(),
    this.fileModifiedAt = const Value.absent(),
    this.summary = const Value.absent(),
    this.thumbnail = const Value.absent(),
    this.error = const Value.absent(),
    this.perceptualHash = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  CachedAssetEntriesCompanion.insert({
    required String path,
    required int size,
    required DateTime fileModifiedAt,
    this.summary = const Value.absent(),
    this.thumbnail = const Value.absent(),
    this.error = const Value.absent(),
    this.perceptualHash = const Value.absent(),
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : path = Value(path),
       size = Value(size),
       fileModifiedAt = Value(fileModifiedAt),
       updatedAt = Value(updatedAt);
  static Insertable<CachedAssetEntry> custom({
    Expression<String>? path,
    Expression<int>? size,
    Expression<DateTime>? fileModifiedAt,
    Expression<String>? summary,
    Expression<Uint8List>? thumbnail,
    Expression<String>? error,
    Expression<int>? perceptualHash,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (path != null) 'path': path,
      if (size != null) 'size': size,
      if (fileModifiedAt != null) 'file_modified_at': fileModifiedAt,
      if (summary != null) 'summary': summary,
      if (thumbnail != null) 'thumbnail': thumbnail,
      if (error != null) 'error': error,
      if (perceptualHash != null) 'perceptual_hash': perceptualHash,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  CachedAssetEntriesCompanion copyWith({
    Value<String>? path,
    Value<int>? size,
    Value<DateTime>? fileModifiedAt,
    Value<String?>? summary,
    Value<Uint8List?>? thumbnail,
    Value<String?>? error,
    Value<int?>? perceptualHash,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return CachedAssetEntriesCompanion(
      path: path ?? this.path,
      size: size ?? this.size,
      fileModifiedAt: fileModifiedAt ?? this.fileModifiedAt,
      summary: summary ?? this.summary,
      thumbnail: thumbnail ?? this.thumbnail,
      error: error ?? this.error,
      perceptualHash: perceptualHash ?? this.perceptualHash,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (path.present) {
      map['path'] = Variable<String>(path.value);
    }
    if (size.present) {
      map['size'] = Variable<int>(size.value);
    }
    if (fileModifiedAt.present) {
      map['file_modified_at'] = Variable<DateTime>(fileModifiedAt.value);
    }
    if (summary.present) {
      map['summary'] = Variable<String>(summary.value);
    }
    if (thumbnail.present) {
      map['thumbnail'] = Variable<Uint8List>(thumbnail.value);
    }
    if (error.present) {
      map['error'] = Variable<String>(error.value);
    }
    if (perceptualHash.present) {
      map['perceptual_hash'] = Variable<int>(perceptualHash.value);
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
    return (StringBuffer('CachedAssetEntriesCompanion(')
          ..write('path: $path, ')
          ..write('size: $size, ')
          ..write('fileModifiedAt: $fileModifiedAt, ')
          ..write('summary: $summary, ')
          ..write('thumbnail: $thumbnail, ')
          ..write('error: $error, ')
          ..write('perceptualHash: $perceptualHash, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$CatalogDatabase extends GeneratedDatabase {
  _$CatalogDatabase(QueryExecutor e) : super(e);
  $CatalogDatabaseManager get managers => $CatalogDatabaseManager(this);
  late final $SettingEntriesTable settingEntries = $SettingEntriesTable(this);
  late final $BookmarkEntriesTable bookmarkEntries = $BookmarkEntriesTable(
    this,
  );
  late final $VisitEntriesTable visitEntries = $VisitEntriesTable(this);
  late final $CachedAssetEntriesTable cachedAssetEntries =
      $CachedAssetEntriesTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    settingEntries,
    bookmarkEntries,
    visitEntries,
    cachedAssetEntries,
  ];
}

typedef $$SettingEntriesTableCreateCompanionBuilder =
    SettingEntriesCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$SettingEntriesTableUpdateCompanionBuilder =
    SettingEntriesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$SettingEntriesTableFilterComposer
    extends Composer<_$CatalogDatabase, $SettingEntriesTable> {
  $$SettingEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SettingEntriesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $SettingEntriesTable> {
  $$SettingEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SettingEntriesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $SettingEntriesTable> {
  $$SettingEntriesTableAnnotationComposer({
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

class $$SettingEntriesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $SettingEntriesTable,
          SettingEntry,
          $$SettingEntriesTableFilterComposer,
          $$SettingEntriesTableOrderingComposer,
          $$SettingEntriesTableAnnotationComposer,
          $$SettingEntriesTableCreateCompanionBuilder,
          $$SettingEntriesTableUpdateCompanionBuilder,
          (
            SettingEntry,
            BaseReferences<
              _$CatalogDatabase,
              $SettingEntriesTable,
              SettingEntry
            >,
          ),
          SettingEntry,
          PrefetchHooks Function()
        > {
  $$SettingEntriesTableTableManager(
    _$CatalogDatabase db,
    $SettingEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SettingEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SettingEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SettingEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) =>
                  SettingEntriesCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => SettingEntriesCompanion.insert(
                key: key,
                value: value,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SettingEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $SettingEntriesTable,
      SettingEntry,
      $$SettingEntriesTableFilterComposer,
      $$SettingEntriesTableOrderingComposer,
      $$SettingEntriesTableAnnotationComposer,
      $$SettingEntriesTableCreateCompanionBuilder,
      $$SettingEntriesTableUpdateCompanionBuilder,
      (
        SettingEntry,
        BaseReferences<_$CatalogDatabase, $SettingEntriesTable, SettingEntry>,
      ),
      SettingEntry,
      PrefetchHooks Function()
    >;
typedef $$BookmarkEntriesTableCreateCompanionBuilder =
    BookmarkEntriesCompanion Function({
      required String path,
      required String name,
      required DateTime addedAt,
      Value<int> rowid,
    });
typedef $$BookmarkEntriesTableUpdateCompanionBuilder =
    BookmarkEntriesCompanion Function({
      Value<String> path,
      Value<String> name,
      Value<DateTime> addedAt,
      Value<int> rowid,
    });

class $$BookmarkEntriesTableFilterComposer
    extends Composer<_$CatalogDatabase, $BookmarkEntriesTable> {
  $$BookmarkEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$BookmarkEntriesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $BookmarkEntriesTable> {
  $$BookmarkEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get addedAt => $composableBuilder(
    column: $table.addedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$BookmarkEntriesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $BookmarkEntriesTable> {
  $$BookmarkEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<DateTime> get addedAt =>
      $composableBuilder(column: $table.addedAt, builder: (column) => column);
}

class $$BookmarkEntriesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $BookmarkEntriesTable,
          BookmarkEntry,
          $$BookmarkEntriesTableFilterComposer,
          $$BookmarkEntriesTableOrderingComposer,
          $$BookmarkEntriesTableAnnotationComposer,
          $$BookmarkEntriesTableCreateCompanionBuilder,
          $$BookmarkEntriesTableUpdateCompanionBuilder,
          (
            BookmarkEntry,
            BaseReferences<
              _$CatalogDatabase,
              $BookmarkEntriesTable,
              BookmarkEntry
            >,
          ),
          BookmarkEntry,
          PrefetchHooks Function()
        > {
  $$BookmarkEntriesTableTableManager(
    _$CatalogDatabase db,
    $BookmarkEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$BookmarkEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$BookmarkEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$BookmarkEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<DateTime> addedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => BookmarkEntriesCompanion(
                path: path,
                name: name,
                addedAt: addedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required String name,
                required DateTime addedAt,
                Value<int> rowid = const Value.absent(),
              }) => BookmarkEntriesCompanion.insert(
                path: path,
                name: name,
                addedAt: addedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$BookmarkEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $BookmarkEntriesTable,
      BookmarkEntry,
      $$BookmarkEntriesTableFilterComposer,
      $$BookmarkEntriesTableOrderingComposer,
      $$BookmarkEntriesTableAnnotationComposer,
      $$BookmarkEntriesTableCreateCompanionBuilder,
      $$BookmarkEntriesTableUpdateCompanionBuilder,
      (
        BookmarkEntry,
        BaseReferences<_$CatalogDatabase, $BookmarkEntriesTable, BookmarkEntry>,
      ),
      BookmarkEntry,
      PrefetchHooks Function()
    >;
typedef $$VisitEntriesTableCreateCompanionBuilder =
    VisitEntriesCompanion Function({
      required String path,
      required DateTime visitedAt,
      Value<int> rowid,
    });
typedef $$VisitEntriesTableUpdateCompanionBuilder =
    VisitEntriesCompanion Function({
      Value<String> path,
      Value<DateTime> visitedAt,
      Value<int> rowid,
    });

class $$VisitEntriesTableFilterComposer
    extends Composer<_$CatalogDatabase, $VisitEntriesTable> {
  $$VisitEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get visitedAt => $composableBuilder(
    column: $table.visitedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VisitEntriesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $VisitEntriesTable> {
  $$VisitEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get visitedAt => $composableBuilder(
    column: $table.visitedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VisitEntriesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $VisitEntriesTable> {
  $$VisitEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<DateTime> get visitedAt =>
      $composableBuilder(column: $table.visitedAt, builder: (column) => column);
}

class $$VisitEntriesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $VisitEntriesTable,
          VisitEntry,
          $$VisitEntriesTableFilterComposer,
          $$VisitEntriesTableOrderingComposer,
          $$VisitEntriesTableAnnotationComposer,
          $$VisitEntriesTableCreateCompanionBuilder,
          $$VisitEntriesTableUpdateCompanionBuilder,
          (
            VisitEntry,
            BaseReferences<_$CatalogDatabase, $VisitEntriesTable, VisitEntry>,
          ),
          VisitEntry,
          PrefetchHooks Function()
        > {
  $$VisitEntriesTableTableManager(
    _$CatalogDatabase db,
    $VisitEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VisitEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VisitEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VisitEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<DateTime> visitedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => VisitEntriesCompanion(
                path: path,
                visitedAt: visitedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required DateTime visitedAt,
                Value<int> rowid = const Value.absent(),
              }) => VisitEntriesCompanion.insert(
                path: path,
                visitedAt: visitedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VisitEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $VisitEntriesTable,
      VisitEntry,
      $$VisitEntriesTableFilterComposer,
      $$VisitEntriesTableOrderingComposer,
      $$VisitEntriesTableAnnotationComposer,
      $$VisitEntriesTableCreateCompanionBuilder,
      $$VisitEntriesTableUpdateCompanionBuilder,
      (
        VisitEntry,
        BaseReferences<_$CatalogDatabase, $VisitEntriesTable, VisitEntry>,
      ),
      VisitEntry,
      PrefetchHooks Function()
    >;
typedef $$CachedAssetEntriesTableCreateCompanionBuilder =
    CachedAssetEntriesCompanion Function({
      required String path,
      required int size,
      required DateTime fileModifiedAt,
      Value<String?> summary,
      Value<Uint8List?> thumbnail,
      Value<String?> error,
      Value<int?> perceptualHash,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$CachedAssetEntriesTableUpdateCompanionBuilder =
    CachedAssetEntriesCompanion Function({
      Value<String> path,
      Value<int> size,
      Value<DateTime> fileModifiedAt,
      Value<String?> summary,
      Value<Uint8List?> thumbnail,
      Value<String?> error,
      Value<int?> perceptualHash,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$CachedAssetEntriesTableFilterComposer
    extends Composer<_$CatalogDatabase, $CachedAssetEntriesTable> {
  $$CachedAssetEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get fileModifiedAt => $composableBuilder(
    column: $table.fileModifiedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get thumbnail => $composableBuilder(
    column: $table.thumbnail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get perceptualHash => $composableBuilder(
    column: $table.perceptualHash,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CachedAssetEntriesTableOrderingComposer
    extends Composer<_$CatalogDatabase, $CachedAssetEntriesTable> {
  $$CachedAssetEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get path => $composableBuilder(
    column: $table.path,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get size => $composableBuilder(
    column: $table.size,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get fileModifiedAt => $composableBuilder(
    column: $table.fileModifiedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get summary => $composableBuilder(
    column: $table.summary,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get thumbnail => $composableBuilder(
    column: $table.thumbnail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get error => $composableBuilder(
    column: $table.error,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get perceptualHash => $composableBuilder(
    column: $table.perceptualHash,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CachedAssetEntriesTableAnnotationComposer
    extends Composer<_$CatalogDatabase, $CachedAssetEntriesTable> {
  $$CachedAssetEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get path =>
      $composableBuilder(column: $table.path, builder: (column) => column);

  GeneratedColumn<int> get size =>
      $composableBuilder(column: $table.size, builder: (column) => column);

  GeneratedColumn<DateTime> get fileModifiedAt => $composableBuilder(
    column: $table.fileModifiedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get summary =>
      $composableBuilder(column: $table.summary, builder: (column) => column);

  GeneratedColumn<Uint8List> get thumbnail =>
      $composableBuilder(column: $table.thumbnail, builder: (column) => column);

  GeneratedColumn<String> get error =>
      $composableBuilder(column: $table.error, builder: (column) => column);

  GeneratedColumn<int> get perceptualHash => $composableBuilder(
    column: $table.perceptualHash,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$CachedAssetEntriesTableTableManager
    extends
        RootTableManager<
          _$CatalogDatabase,
          $CachedAssetEntriesTable,
          CachedAssetEntry,
          $$CachedAssetEntriesTableFilterComposer,
          $$CachedAssetEntriesTableOrderingComposer,
          $$CachedAssetEntriesTableAnnotationComposer,
          $$CachedAssetEntriesTableCreateCompanionBuilder,
          $$CachedAssetEntriesTableUpdateCompanionBuilder,
          (
            CachedAssetEntry,
            BaseReferences<
              _$CatalogDatabase,
              $CachedAssetEntriesTable,
              CachedAssetEntry
            >,
          ),
          CachedAssetEntry,
          PrefetchHooks Function()
        > {
  $$CachedAssetEntriesTableTableManager(
    _$CatalogDatabase db,
    $CachedAssetEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CachedAssetEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CachedAssetEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CachedAssetEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> path = const Value.absent(),
                Value<int> size = const Value.absent(),
                Value<DateTime> fileModifiedAt = const Value.absent(),
                Value<String?> summary = const Value.absent(),
                Value<Uint8List?> thumbnail = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int?> perceptualHash = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => CachedAssetEntriesCompanion(
                path: path,
                size: size,
                fileModifiedAt: fileModifiedAt,
                summary: summary,
                thumbnail: thumbnail,
                error: error,
                perceptualHash: perceptualHash,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String path,
                required int size,
                required DateTime fileModifiedAt,
                Value<String?> summary = const Value.absent(),
                Value<Uint8List?> thumbnail = const Value.absent(),
                Value<String?> error = const Value.absent(),
                Value<int?> perceptualHash = const Value.absent(),
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => CachedAssetEntriesCompanion.insert(
                path: path,
                size: size,
                fileModifiedAt: fileModifiedAt,
                summary: summary,
                thumbnail: thumbnail,
                error: error,
                perceptualHash: perceptualHash,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CachedAssetEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$CatalogDatabase,
      $CachedAssetEntriesTable,
      CachedAssetEntry,
      $$CachedAssetEntriesTableFilterComposer,
      $$CachedAssetEntriesTableOrderingComposer,
      $$CachedAssetEntriesTableAnnotationComposer,
      $$CachedAssetEntriesTableCreateCompanionBuilder,
      $$CachedAssetEntriesTableUpdateCompanionBuilder,
      (
        CachedAssetEntry,
        BaseReferences<
          _$CatalogDatabase,
          $CachedAssetEntriesTable,
          CachedAssetEntry
        >,
      ),
      CachedAssetEntry,
      PrefetchHooks Function()
    >;

class $CatalogDatabaseManager {
  final _$CatalogDatabase _db;
  $CatalogDatabaseManager(this._db);
  $$SettingEntriesTableTableManager get settingEntries =>
      $$SettingEntriesTableTableManager(_db, _db.settingEntries);
  $$BookmarkEntriesTableTableManager get bookmarkEntries =>
      $$BookmarkEntriesTableTableManager(_db, _db.bookmarkEntries);
  $$VisitEntriesTableTableManager get visitEntries =>
      $$VisitEntriesTableTableManager(_db, _db.visitEntries);
  $$CachedAssetEntriesTableTableManager get cachedAssetEntries =>
      $$CachedAssetEntriesTableTableManager(_db, _db.cachedAssetEntries);
}
