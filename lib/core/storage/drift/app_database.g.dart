// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $OfflineRecipesTable extends OfflineRecipes
    with TableInfo<$OfflineRecipesTable, OfflineRecipe> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $OfflineRecipesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recipeJsonMeta =
      const VerificationMeta('recipeJson');
  @override
  late final GeneratedColumn<String> recipeJson = GeneratedColumn<String>(
      'recipe_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _needsSyncMeta =
      const VerificationMeta('needsSync');
  @override
  late final GeneratedColumn<bool> needsSync = GeneratedColumn<bool>(
      'needs_sync', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("needs_sync" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _lastSyncedAtMeta =
      const VerificationMeta('lastSyncedAt');
  @override
  late final GeneratedColumn<DateTime> lastSyncedAt = GeneratedColumn<DateTime>(
      'last_synced_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, userId, recipeJson, updatedAt, needsSync, lastSyncedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'offline_recipes';
  @override
  VerificationContext validateIntegrity(Insertable<OfflineRecipe> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('recipe_json')) {
      context.handle(
          _recipeJsonMeta,
          recipeJson.isAcceptableOrUnknown(
              data['recipe_json']!, _recipeJsonMeta));
    } else if (isInserting) {
      context.missing(_recipeJsonMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('needs_sync')) {
      context.handle(_needsSyncMeta,
          needsSync.isAcceptableOrUnknown(data['needs_sync']!, _needsSyncMeta));
    }
    if (data.containsKey('last_synced_at')) {
      context.handle(
          _lastSyncedAtMeta,
          lastSyncedAt.isAcceptableOrUnknown(
              data['last_synced_at']!, _lastSyncedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id, userId};
  @override
  OfflineRecipe map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return OfflineRecipe(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      recipeJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_json'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
      needsSync: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}needs_sync'])!,
      lastSyncedAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_synced_at']),
    );
  }

  @override
  $OfflineRecipesTable createAlias(String alias) {
    return $OfflineRecipesTable(attachedDatabase, alias);
  }
}

class OfflineRecipe extends DataClass implements Insertable<OfflineRecipe> {
  /// Recipe ID
  final String id;

  /// User ID for data isolation
  final String userId;

  /// JSON-serialized recipe data
  final String recipeJson;

  /// When the recipe was last updated locally
  final DateTime updatedAt;

  /// Whether this recipe needs to be synced to Firestore
  final bool needsSync;

  /// Last sync timestamp
  final DateTime? lastSyncedAt;
  const OfflineRecipe(
      {required this.id,
      required this.userId,
      required this.recipeJson,
      required this.updatedAt,
      required this.needsSync,
      this.lastSyncedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['recipe_json'] = Variable<String>(recipeJson);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    map['needs_sync'] = Variable<bool>(needsSync);
    if (!nullToAbsent || lastSyncedAt != null) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt);
    }
    return map;
  }

  OfflineRecipesCompanion toCompanion(bool nullToAbsent) {
    return OfflineRecipesCompanion(
      id: Value(id),
      userId: Value(userId),
      recipeJson: Value(recipeJson),
      updatedAt: Value(updatedAt),
      needsSync: Value(needsSync),
      lastSyncedAt: lastSyncedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastSyncedAt),
    );
  }

  factory OfflineRecipe.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return OfflineRecipe(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      recipeJson: serializer.fromJson<String>(json['recipeJson']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      needsSync: serializer.fromJson<bool>(json['needsSync']),
      lastSyncedAt: serializer.fromJson<DateTime?>(json['lastSyncedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'recipeJson': serializer.toJson<String>(recipeJson),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'needsSync': serializer.toJson<bool>(needsSync),
      'lastSyncedAt': serializer.toJson<DateTime?>(lastSyncedAt),
    };
  }

  OfflineRecipe copyWith(
          {String? id,
          String? userId,
          String? recipeJson,
          DateTime? updatedAt,
          bool? needsSync,
          Value<DateTime?> lastSyncedAt = const Value.absent()}) =>
      OfflineRecipe(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        recipeJson: recipeJson ?? this.recipeJson,
        updatedAt: updatedAt ?? this.updatedAt,
        needsSync: needsSync ?? this.needsSync,
        lastSyncedAt:
            lastSyncedAt.present ? lastSyncedAt.value : this.lastSyncedAt,
      );
  OfflineRecipe copyWithCompanion(OfflineRecipesCompanion data) {
    return OfflineRecipe(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      recipeJson:
          data.recipeJson.present ? data.recipeJson.value : this.recipeJson,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      needsSync: data.needsSync.present ? data.needsSync.value : this.needsSync,
      lastSyncedAt: data.lastSyncedAt.present
          ? data.lastSyncedAt.value
          : this.lastSyncedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('OfflineRecipe(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('recipeJson: $recipeJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('needsSync: $needsSync, ')
          ..write('lastSyncedAt: $lastSyncedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, userId, recipeJson, updatedAt, needsSync, lastSyncedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is OfflineRecipe &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.recipeJson == this.recipeJson &&
          other.updatedAt == this.updatedAt &&
          other.needsSync == this.needsSync &&
          other.lastSyncedAt == this.lastSyncedAt);
}

class OfflineRecipesCompanion extends UpdateCompanion<OfflineRecipe> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> recipeJson;
  final Value<DateTime> updatedAt;
  final Value<bool> needsSync;
  final Value<DateTime?> lastSyncedAt;
  final Value<int> rowid;
  const OfflineRecipesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.recipeJson = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.needsSync = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  OfflineRecipesCompanion.insert({
    required String id,
    required String userId,
    required String recipeJson,
    required DateTime updatedAt,
    this.needsSync = const Value.absent(),
    this.lastSyncedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        recipeJson = Value(recipeJson),
        updatedAt = Value(updatedAt);
  static Insertable<OfflineRecipe> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? recipeJson,
    Expression<DateTime>? updatedAt,
    Expression<bool>? needsSync,
    Expression<DateTime>? lastSyncedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (recipeJson != null) 'recipe_json': recipeJson,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (needsSync != null) 'needs_sync': needsSync,
      if (lastSyncedAt != null) 'last_synced_at': lastSyncedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  OfflineRecipesCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? recipeJson,
      Value<DateTime>? updatedAt,
      Value<bool>? needsSync,
      Value<DateTime?>? lastSyncedAt,
      Value<int>? rowid}) {
    return OfflineRecipesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recipeJson: recipeJson ?? this.recipeJson,
      updatedAt: updatedAt ?? this.updatedAt,
      needsSync: needsSync ?? this.needsSync,
      lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (recipeJson.present) {
      map['recipe_json'] = Variable<String>(recipeJson.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (needsSync.present) {
      map['needs_sync'] = Variable<bool>(needsSync.value);
    }
    if (lastSyncedAt.present) {
      map['last_synced_at'] = Variable<DateTime>(lastSyncedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('OfflineRecipesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('recipeJson: $recipeJson, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('needsSync: $needsSync, ')
          ..write('lastSyncedAt: $lastSyncedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SyncQueueEntriesTable extends SyncQueueEntries
    with TableInfo<$SyncQueueEntriesTable, SyncQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncQueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recipeIdMeta =
      const VerificationMeta('recipeId');
  @override
  late final GeneratedColumn<String> recipeId = GeneratedColumn<String>(
      'recipe_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _operationMeta =
      const VerificationMeta('operation');
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
      'operation', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _queuedAtMeta =
      const VerificationMeta('queuedAt');
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
      'queued_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, userId, recipeId, operation, queuedAt, retryCount, lastError];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_queue_entries';
  @override
  VerificationContext validateIntegrity(Insertable<SyncQueueEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('recipe_id')) {
      context.handle(_recipeIdMeta,
          recipeId.isAcceptableOrUnknown(data['recipe_id']!, _recipeIdMeta));
    } else if (isInserting) {
      context.missing(_recipeIdMeta);
    }
    if (data.containsKey('operation')) {
      context.handle(_operationMeta,
          operation.isAcceptableOrUnknown(data['operation']!, _operationMeta));
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('queued_at')) {
      context.handle(_queuedAtMeta,
          queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta));
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SyncQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncQueueEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      recipeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_id'])!,
      operation: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}operation'])!,
      queuedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}queued_at'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
    );
  }

  @override
  $SyncQueueEntriesTable createAlias(String alias) {
    return $SyncQueueEntriesTable(attachedDatabase, alias);
  }
}

class SyncQueueEntry extends DataClass implements Insertable<SyncQueueEntry> {
  /// Auto-incrementing ID
  final int id;

  /// User ID for data isolation
  final String userId;

  /// Recipe ID to sync
  final String recipeId;

  /// Type of operation: create, update, delete
  final String operation;

  /// When the operation was queued
  final DateTime queuedAt;

  /// Number of sync retry attempts
  final int retryCount;

  /// Last error message if sync failed
  final String? lastError;
  const SyncQueueEntry(
      {required this.id,
      required this.userId,
      required this.recipeId,
      required this.operation,
      required this.queuedAt,
      required this.retryCount,
      this.lastError});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_id'] = Variable<String>(userId);
    map['recipe_id'] = Variable<String>(recipeId);
    map['operation'] = Variable<String>(operation);
    map['queued_at'] = Variable<DateTime>(queuedAt);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    return map;
  }

  SyncQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return SyncQueueEntriesCompanion(
      id: Value(id),
      userId: Value(userId),
      recipeId: Value(recipeId),
      operation: Value(operation),
      queuedAt: Value(queuedAt),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
    );
  }

  factory SyncQueueEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncQueueEntry(
      id: serializer.fromJson<int>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      recipeId: serializer.fromJson<String>(json['recipeId']),
      operation: serializer.fromJson<String>(json['operation']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userId': serializer.toJson<String>(userId),
      'recipeId': serializer.toJson<String>(recipeId),
      'operation': serializer.toJson<String>(operation),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
    };
  }

  SyncQueueEntry copyWith(
          {int? id,
          String? userId,
          String? recipeId,
          String? operation,
          DateTime? queuedAt,
          int? retryCount,
          Value<String?> lastError = const Value.absent()}) =>
      SyncQueueEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        recipeId: recipeId ?? this.recipeId,
        operation: operation ?? this.operation,
        queuedAt: queuedAt ?? this.queuedAt,
        retryCount: retryCount ?? this.retryCount,
        lastError: lastError.present ? lastError.value : this.lastError,
      );
  SyncQueueEntry copyWithCompanion(SyncQueueEntriesCompanion data) {
    return SyncQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      recipeId: data.recipeId.present ? data.recipeId.value : this.recipeId,
      operation: data.operation.present ? data.operation.value : this.operation,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntry(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('recipeId: $recipeId, ')
          ..write('operation: $operation, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, userId, recipeId, operation, queuedAt, retryCount, lastError);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncQueueEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.recipeId == this.recipeId &&
          other.operation == this.operation &&
          other.queuedAt == this.queuedAt &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError);
}

class SyncQueueEntriesCompanion extends UpdateCompanion<SyncQueueEntry> {
  final Value<int> id;
  final Value<String> userId;
  final Value<String> recipeId;
  final Value<String> operation;
  final Value<DateTime> queuedAt;
  final Value<int> retryCount;
  final Value<String?> lastError;
  const SyncQueueEntriesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.recipeId = const Value.absent(),
    this.operation = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
  });
  SyncQueueEntriesCompanion.insert({
    this.id = const Value.absent(),
    required String userId,
    required String recipeId,
    required String operation,
    required DateTime queuedAt,
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
  })  : userId = Value(userId),
        recipeId = Value(recipeId),
        operation = Value(operation),
        queuedAt = Value(queuedAt);
  static Insertable<SyncQueueEntry> custom({
    Expression<int>? id,
    Expression<String>? userId,
    Expression<String>? recipeId,
    Expression<String>? operation,
    Expression<DateTime>? queuedAt,
    Expression<int>? retryCount,
    Expression<String>? lastError,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (recipeId != null) 'recipe_id': recipeId,
      if (operation != null) 'operation': operation,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
    });
  }

  SyncQueueEntriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? userId,
      Value<String>? recipeId,
      Value<String>? operation,
      Value<DateTime>? queuedAt,
      Value<int>? retryCount,
      Value<String?>? lastError}) {
    return SyncQueueEntriesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      recipeId: recipeId ?? this.recipeId,
      operation: operation ?? this.operation,
      queuedAt: queuedAt ?? this.queuedAt,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (recipeId.present) {
      map['recipe_id'] = Variable<String>(recipeId.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncQueueEntriesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('recipeId: $recipeId, ')
          ..write('operation: $operation, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError')
          ..write(')'))
        .toString();
  }
}

class $JsonCacheEntriesTable extends JsonCacheEntries
    with TableInfo<$JsonCacheEntriesTable, JsonCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JsonCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _boxNameMeta =
      const VerificationMeta('boxName');
  @override
  late final GeneratedColumn<String> boxName = GeneratedColumn<String>(
      'box_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
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
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [boxName, userId, key, value, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'json_cache_entries';
  @override
  VerificationContext validateIntegrity(Insertable<JsonCacheEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('box_name')) {
      context.handle(_boxNameMeta,
          boxName.isAcceptableOrUnknown(data['box_name']!, _boxNameMeta));
    } else if (isInserting) {
      context.missing(_boxNameMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
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
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {boxName, userId, key};
  @override
  JsonCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JsonCacheEntry(
      boxName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}box_name'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      key: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}key'])!,
      value: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}value'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $JsonCacheEntriesTable createAlias(String alias) {
    return $JsonCacheEntriesTable(attachedDatabase, alias);
  }
}

class JsonCacheEntry extends DataClass implements Insertable<JsonCacheEntry> {
  /// Box name identifier (e.g., 'unified_recipes_cache')
  final String boxName;

  /// User ID for data isolation
  final String userId;

  /// Cache key
  final String key;

  /// JSON-encoded value
  final String value;

  /// When the entry was cached
  final DateTime cachedAt;
  const JsonCacheEntry(
      {required this.boxName,
      required this.userId,
      required this.key,
      required this.value,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['box_name'] = Variable<String>(boxName);
    map['user_id'] = Variable<String>(userId);
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  JsonCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return JsonCacheEntriesCompanion(
      boxName: Value(boxName),
      userId: Value(userId),
      key: Value(key),
      value: Value(value),
      cachedAt: Value(cachedAt),
    );
  }

  factory JsonCacheEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JsonCacheEntry(
      boxName: serializer.fromJson<String>(json['boxName']),
      userId: serializer.fromJson<String>(json['userId']),
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'boxName': serializer.toJson<String>(boxName),
      'userId': serializer.toJson<String>(userId),
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  JsonCacheEntry copyWith(
          {String? boxName,
          String? userId,
          String? key,
          String? value,
          DateTime? cachedAt}) =>
      JsonCacheEntry(
        boxName: boxName ?? this.boxName,
        userId: userId ?? this.userId,
        key: key ?? this.key,
        value: value ?? this.value,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  JsonCacheEntry copyWithCompanion(JsonCacheEntriesCompanion data) {
    return JsonCacheEntry(
      boxName: data.boxName.present ? data.boxName.value : this.boxName,
      userId: data.userId.present ? data.userId.value : this.userId,
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JsonCacheEntry(')
          ..write('boxName: $boxName, ')
          ..write('userId: $userId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(boxName, userId, key, value, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JsonCacheEntry &&
          other.boxName == this.boxName &&
          other.userId == this.userId &&
          other.key == this.key &&
          other.value == this.value &&
          other.cachedAt == this.cachedAt);
}

class JsonCacheEntriesCompanion extends UpdateCompanion<JsonCacheEntry> {
  final Value<String> boxName;
  final Value<String> userId;
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const JsonCacheEntriesCompanion({
    this.boxName = const Value.absent(),
    this.userId = const Value.absent(),
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  JsonCacheEntriesCompanion.insert({
    required String boxName,
    required String userId,
    required String key,
    required String value,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  })  : boxName = Value(boxName),
        userId = Value(userId),
        key = Value(key),
        value = Value(value),
        cachedAt = Value(cachedAt);
  static Insertable<JsonCacheEntry> custom({
    Expression<String>? boxName,
    Expression<String>? userId,
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (boxName != null) 'box_name': boxName,
      if (userId != null) 'user_id': userId,
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  JsonCacheEntriesCompanion copyWith(
      {Value<String>? boxName,
      Value<String>? userId,
      Value<String>? key,
      Value<String>? value,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return JsonCacheEntriesCompanion(
      boxName: boxName ?? this.boxName,
      userId: userId ?? this.userId,
      key: key ?? this.key,
      value: value ?? this.value,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (boxName.present) {
      map['box_name'] = Variable<String>(boxName.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JsonCacheEntriesCompanion(')
          ..write('boxName: $boxName, ')
          ..write('userId: $userId, ')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $ParseCacheEntriesTable extends ParseCacheEntries
    with TableInfo<$ParseCacheEntriesTable, ParseCacheEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ParseCacheEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _cacheKeyMeta =
      const VerificationMeta('cacheKey');
  @override
  late final GeneratedColumn<String> cacheKey = GeneratedColumn<String>(
      'cache_key', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _recipeJsonMeta =
      const VerificationMeta('recipeJson');
  @override
  late final GeneratedColumn<String> recipeJson = GeneratedColumn<String>(
      'recipe_json', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _parserVersionMeta =
      const VerificationMeta('parserVersion');
  @override
  late final GeneratedColumn<String> parserVersion = GeneratedColumn<String>(
      'parser_version', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
      'source', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _cachedAtMeta =
      const VerificationMeta('cachedAt');
  @override
  late final GeneratedColumn<DateTime> cachedAt = GeneratedColumn<DateTime>(
      'cached_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns =>
      [cacheKey, userId, recipeJson, parserVersion, source, cachedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'parse_cache_entries';
  @override
  VerificationContext validateIntegrity(Insertable<ParseCacheEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('cache_key')) {
      context.handle(_cacheKeyMeta,
          cacheKey.isAcceptableOrUnknown(data['cache_key']!, _cacheKeyMeta));
    } else if (isInserting) {
      context.missing(_cacheKeyMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('recipe_json')) {
      context.handle(
          _recipeJsonMeta,
          recipeJson.isAcceptableOrUnknown(
              data['recipe_json']!, _recipeJsonMeta));
    } else if (isInserting) {
      context.missing(_recipeJsonMeta);
    }
    if (data.containsKey('parser_version')) {
      context.handle(
          _parserVersionMeta,
          parserVersion.isAcceptableOrUnknown(
              data['parser_version']!, _parserVersionMeta));
    } else if (isInserting) {
      context.missing(_parserVersionMeta);
    }
    if (data.containsKey('source')) {
      context.handle(_sourceMeta,
          source.isAcceptableOrUnknown(data['source']!, _sourceMeta));
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    if (data.containsKey('cached_at')) {
      context.handle(_cachedAtMeta,
          cachedAt.isAcceptableOrUnknown(data['cached_at']!, _cachedAtMeta));
    } else if (isInserting) {
      context.missing(_cachedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {cacheKey};
  @override
  ParseCacheEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ParseCacheEntry(
      cacheKey: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}cache_key'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      recipeJson: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}recipe_json'])!,
      parserVersion: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}parser_version'])!,
      source: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}source'])!,
      cachedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}cached_at'])!,
    );
  }

  @override
  $ParseCacheEntriesTable createAlias(String alias) {
    return $ParseCacheEntriesTable(attachedDatabase, alias);
  }
}

class ParseCacheEntry extends DataClass implements Insertable<ParseCacheEntry> {
  /// SHA256 cache key (hash of userId + urlHash + contentHash + source + version)
  final String cacheKey;

  /// User ID for data isolation
  final String userId;

  /// JSON-serialized ParsedRecipe
  final String recipeJson;

  /// Parser version that created this cache entry
  final String parserVersion;

  /// Import source type (url, text, ocr, etc.)
  final String source;

  /// When the entry was cached
  final DateTime cachedAt;
  const ParseCacheEntry(
      {required this.cacheKey,
      required this.userId,
      required this.recipeJson,
      required this.parserVersion,
      required this.source,
      required this.cachedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['cache_key'] = Variable<String>(cacheKey);
    map['user_id'] = Variable<String>(userId);
    map['recipe_json'] = Variable<String>(recipeJson);
    map['parser_version'] = Variable<String>(parserVersion);
    map['source'] = Variable<String>(source);
    map['cached_at'] = Variable<DateTime>(cachedAt);
    return map;
  }

  ParseCacheEntriesCompanion toCompanion(bool nullToAbsent) {
    return ParseCacheEntriesCompanion(
      cacheKey: Value(cacheKey),
      userId: Value(userId),
      recipeJson: Value(recipeJson),
      parserVersion: Value(parserVersion),
      source: Value(source),
      cachedAt: Value(cachedAt),
    );
  }

  factory ParseCacheEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ParseCacheEntry(
      cacheKey: serializer.fromJson<String>(json['cacheKey']),
      userId: serializer.fromJson<String>(json['userId']),
      recipeJson: serializer.fromJson<String>(json['recipeJson']),
      parserVersion: serializer.fromJson<String>(json['parserVersion']),
      source: serializer.fromJson<String>(json['source']),
      cachedAt: serializer.fromJson<DateTime>(json['cachedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'cacheKey': serializer.toJson<String>(cacheKey),
      'userId': serializer.toJson<String>(userId),
      'recipeJson': serializer.toJson<String>(recipeJson),
      'parserVersion': serializer.toJson<String>(parserVersion),
      'source': serializer.toJson<String>(source),
      'cachedAt': serializer.toJson<DateTime>(cachedAt),
    };
  }

  ParseCacheEntry copyWith(
          {String? cacheKey,
          String? userId,
          String? recipeJson,
          String? parserVersion,
          String? source,
          DateTime? cachedAt}) =>
      ParseCacheEntry(
        cacheKey: cacheKey ?? this.cacheKey,
        userId: userId ?? this.userId,
        recipeJson: recipeJson ?? this.recipeJson,
        parserVersion: parserVersion ?? this.parserVersion,
        source: source ?? this.source,
        cachedAt: cachedAt ?? this.cachedAt,
      );
  ParseCacheEntry copyWithCompanion(ParseCacheEntriesCompanion data) {
    return ParseCacheEntry(
      cacheKey: data.cacheKey.present ? data.cacheKey.value : this.cacheKey,
      userId: data.userId.present ? data.userId.value : this.userId,
      recipeJson:
          data.recipeJson.present ? data.recipeJson.value : this.recipeJson,
      parserVersion: data.parserVersion.present
          ? data.parserVersion.value
          : this.parserVersion,
      source: data.source.present ? data.source.value : this.source,
      cachedAt: data.cachedAt.present ? data.cachedAt.value : this.cachedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ParseCacheEntry(')
          ..write('cacheKey: $cacheKey, ')
          ..write('userId: $userId, ')
          ..write('recipeJson: $recipeJson, ')
          ..write('parserVersion: $parserVersion, ')
          ..write('source: $source, ')
          ..write('cachedAt: $cachedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      cacheKey, userId, recipeJson, parserVersion, source, cachedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ParseCacheEntry &&
          other.cacheKey == this.cacheKey &&
          other.userId == this.userId &&
          other.recipeJson == this.recipeJson &&
          other.parserVersion == this.parserVersion &&
          other.source == this.source &&
          other.cachedAt == this.cachedAt);
}

class ParseCacheEntriesCompanion extends UpdateCompanion<ParseCacheEntry> {
  final Value<String> cacheKey;
  final Value<String> userId;
  final Value<String> recipeJson;
  final Value<String> parserVersion;
  final Value<String> source;
  final Value<DateTime> cachedAt;
  final Value<int> rowid;
  const ParseCacheEntriesCompanion({
    this.cacheKey = const Value.absent(),
    this.userId = const Value.absent(),
    this.recipeJson = const Value.absent(),
    this.parserVersion = const Value.absent(),
    this.source = const Value.absent(),
    this.cachedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  ParseCacheEntriesCompanion.insert({
    required String cacheKey,
    required String userId,
    required String recipeJson,
    required String parserVersion,
    required String source,
    required DateTime cachedAt,
    this.rowid = const Value.absent(),
  })  : cacheKey = Value(cacheKey),
        userId = Value(userId),
        recipeJson = Value(recipeJson),
        parserVersion = Value(parserVersion),
        source = Value(source),
        cachedAt = Value(cachedAt);
  static Insertable<ParseCacheEntry> custom({
    Expression<String>? cacheKey,
    Expression<String>? userId,
    Expression<String>? recipeJson,
    Expression<String>? parserVersion,
    Expression<String>? source,
    Expression<DateTime>? cachedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (cacheKey != null) 'cache_key': cacheKey,
      if (userId != null) 'user_id': userId,
      if (recipeJson != null) 'recipe_json': recipeJson,
      if (parserVersion != null) 'parser_version': parserVersion,
      if (source != null) 'source': source,
      if (cachedAt != null) 'cached_at': cachedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  ParseCacheEntriesCompanion copyWith(
      {Value<String>? cacheKey,
      Value<String>? userId,
      Value<String>? recipeJson,
      Value<String>? parserVersion,
      Value<String>? source,
      Value<DateTime>? cachedAt,
      Value<int>? rowid}) {
    return ParseCacheEntriesCompanion(
      cacheKey: cacheKey ?? this.cacheKey,
      userId: userId ?? this.userId,
      recipeJson: recipeJson ?? this.recipeJson,
      parserVersion: parserVersion ?? this.parserVersion,
      source: source ?? this.source,
      cachedAt: cachedAt ?? this.cachedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (cacheKey.present) {
      map['cache_key'] = Variable<String>(cacheKey.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (recipeJson.present) {
      map['recipe_json'] = Variable<String>(recipeJson.value);
    }
    if (parserVersion.present) {
      map['parser_version'] = Variable<String>(parserVersion.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (cachedAt.present) {
      map['cached_at'] = Variable<DateTime>(cachedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ParseCacheEntriesCompanion(')
          ..write('cacheKey: $cacheKey, ')
          ..write('userId: $userId, ')
          ..write('recipeJson: $recipeJson, ')
          ..write('parserVersion: $parserVersion, ')
          ..write('source: $source, ')
          ..write('cachedAt: $cachedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UploadQueueEntriesTable extends UploadQueueEntries
    with TableInfo<$UploadQueueEntriesTable, UploadQueueEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UploadQueueEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
      'user_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _localPathMeta =
      const VerificationMeta('localPath');
  @override
  late final GeneratedColumn<String> localPath = GeneratedColumn<String>(
      'local_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetPathMeta =
      const VerificationMeta('targetPath');
  @override
  late final GeneratedColumn<String> targetPath = GeneratedColumn<String>(
      'target_path', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _contentTypeMeta =
      const VerificationMeta('contentType');
  @override
  late final GeneratedColumn<String> contentType = GeneratedColumn<String>(
      'content_type', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('image/jpeg'));
  static const VerificationMeta _fileSizeBytesMeta =
      const VerificationMeta('fileSizeBytes');
  @override
  late final GeneratedColumn<int> fileSizeBytes = GeneratedColumn<int>(
      'file_size_bytes', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
      'status', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('pending'));
  static const VerificationMeta _retryCountMeta =
      const VerificationMeta('retryCount');
  @override
  late final GeneratedColumn<int> retryCount = GeneratedColumn<int>(
      'retry_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastErrorMeta =
      const VerificationMeta('lastError');
  @override
  late final GeneratedColumn<String> lastError = GeneratedColumn<String>(
      'last_error', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _queuedAtMeta =
      const VerificationMeta('queuedAt');
  @override
  late final GeneratedColumn<DateTime> queuedAt = GeneratedColumn<DateTime>(
      'queued_at', aliasedName, false,
      type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastAttemptAtMeta =
      const VerificationMeta('lastAttemptAt');
  @override
  late final GeneratedColumn<DateTime> lastAttemptAt =
      GeneratedColumn<DateTime>('last_attempt_at', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _entityIdMeta =
      const VerificationMeta('entityId');
  @override
  late final GeneratedColumn<String> entityId = GeneratedColumn<String>(
      'entity_id', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _entityTypeMeta =
      const VerificationMeta('entityType');
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
      'entity_type', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _metadataMeta =
      const VerificationMeta('metadata');
  @override
  late final GeneratedColumn<String> metadata = GeneratedColumn<String>(
      'metadata', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userId,
        localPath,
        targetPath,
        contentType,
        fileSizeBytes,
        status,
        retryCount,
        lastError,
        queuedAt,
        lastAttemptAt,
        entityId,
        entityType,
        metadata
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'upload_queue_entries';
  @override
  VerificationContext validateIntegrity(Insertable<UploadQueueEntry> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(_userIdMeta,
          userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta));
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('local_path')) {
      context.handle(_localPathMeta,
          localPath.isAcceptableOrUnknown(data['local_path']!, _localPathMeta));
    } else if (isInserting) {
      context.missing(_localPathMeta);
    }
    if (data.containsKey('target_path')) {
      context.handle(
          _targetPathMeta,
          targetPath.isAcceptableOrUnknown(
              data['target_path']!, _targetPathMeta));
    } else if (isInserting) {
      context.missing(_targetPathMeta);
    }
    if (data.containsKey('content_type')) {
      context.handle(
          _contentTypeMeta,
          contentType.isAcceptableOrUnknown(
              data['content_type']!, _contentTypeMeta));
    }
    if (data.containsKey('file_size_bytes')) {
      context.handle(
          _fileSizeBytesMeta,
          fileSizeBytes.isAcceptableOrUnknown(
              data['file_size_bytes']!, _fileSizeBytesMeta));
    } else if (isInserting) {
      context.missing(_fileSizeBytesMeta);
    }
    if (data.containsKey('status')) {
      context.handle(_statusMeta,
          status.isAcceptableOrUnknown(data['status']!, _statusMeta));
    }
    if (data.containsKey('retry_count')) {
      context.handle(
          _retryCountMeta,
          retryCount.isAcceptableOrUnknown(
              data['retry_count']!, _retryCountMeta));
    }
    if (data.containsKey('last_error')) {
      context.handle(_lastErrorMeta,
          lastError.isAcceptableOrUnknown(data['last_error']!, _lastErrorMeta));
    }
    if (data.containsKey('queued_at')) {
      context.handle(_queuedAtMeta,
          queuedAt.isAcceptableOrUnknown(data['queued_at']!, _queuedAtMeta));
    } else if (isInserting) {
      context.missing(_queuedAtMeta);
    }
    if (data.containsKey('last_attempt_at')) {
      context.handle(
          _lastAttemptAtMeta,
          lastAttemptAt.isAcceptableOrUnknown(
              data['last_attempt_at']!, _lastAttemptAtMeta));
    }
    if (data.containsKey('entity_id')) {
      context.handle(_entityIdMeta,
          entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta));
    }
    if (data.containsKey('entity_type')) {
      context.handle(
          _entityTypeMeta,
          entityType.isAcceptableOrUnknown(
              data['entity_type']!, _entityTypeMeta));
    }
    if (data.containsKey('metadata')) {
      context.handle(_metadataMeta,
          metadata.isAcceptableOrUnknown(data['metadata']!, _metadataMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UploadQueueEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UploadQueueEntry(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      userId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_id'])!,
      localPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}local_path'])!,
      targetPath: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}target_path'])!,
      contentType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}content_type'])!,
      fileSizeBytes: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}file_size_bytes'])!,
      status: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}status'])!,
      retryCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}retry_count'])!,
      lastError: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_error']),
      queuedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}queued_at'])!,
      lastAttemptAt: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_attempt_at']),
      entityId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_id']),
      entityType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}entity_type']),
      metadata: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}metadata']),
    );
  }

  @override
  $UploadQueueEntriesTable createAlias(String alias) {
    return $UploadQueueEntriesTable(attachedDatabase, alias);
  }
}

class UploadQueueEntry extends DataClass
    implements Insertable<UploadQueueEntry> {
  /// Unique upload ID (UUID from the upload request)
  final String id;

  /// User ID for data isolation
  final String userId;

  /// Local file path of the image to upload
  final String localPath;

  /// Target storage path in Firebase Storage
  final String targetPath;

  /// Content type of the file (e.g., 'image/jpeg')
  final String contentType;

  /// File size in bytes
  final int fileSizeBytes;

  /// Current status of the upload
  final String status;

  /// Number of retry attempts
  final int retryCount;

  /// Last error message if upload failed
  final String? lastError;

  /// When the upload was queued
  final DateTime queuedAt;

  /// When the last attempt was made
  final DateTime? lastAttemptAt;

  /// Associated entity ID (e.g., recipe ID)
  final String? entityId;

  /// Type of entity (e.g., 'recipe', 'profile')
  final String? entityType;

  /// Additional metadata as JSON string
  final String? metadata;
  const UploadQueueEntry(
      {required this.id,
      required this.userId,
      required this.localPath,
      required this.targetPath,
      required this.contentType,
      required this.fileSizeBytes,
      required this.status,
      required this.retryCount,
      this.lastError,
      required this.queuedAt,
      this.lastAttemptAt,
      this.entityId,
      this.entityType,
      this.metadata});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['local_path'] = Variable<String>(localPath);
    map['target_path'] = Variable<String>(targetPath);
    map['content_type'] = Variable<String>(contentType);
    map['file_size_bytes'] = Variable<int>(fileSizeBytes);
    map['status'] = Variable<String>(status);
    map['retry_count'] = Variable<int>(retryCount);
    if (!nullToAbsent || lastError != null) {
      map['last_error'] = Variable<String>(lastError);
    }
    map['queued_at'] = Variable<DateTime>(queuedAt);
    if (!nullToAbsent || lastAttemptAt != null) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt);
    }
    if (!nullToAbsent || entityId != null) {
      map['entity_id'] = Variable<String>(entityId);
    }
    if (!nullToAbsent || entityType != null) {
      map['entity_type'] = Variable<String>(entityType);
    }
    if (!nullToAbsent || metadata != null) {
      map['metadata'] = Variable<String>(metadata);
    }
    return map;
  }

  UploadQueueEntriesCompanion toCompanion(bool nullToAbsent) {
    return UploadQueueEntriesCompanion(
      id: Value(id),
      userId: Value(userId),
      localPath: Value(localPath),
      targetPath: Value(targetPath),
      contentType: Value(contentType),
      fileSizeBytes: Value(fileSizeBytes),
      status: Value(status),
      retryCount: Value(retryCount),
      lastError: lastError == null && nullToAbsent
          ? const Value.absent()
          : Value(lastError),
      queuedAt: Value(queuedAt),
      lastAttemptAt: lastAttemptAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAttemptAt),
      entityId: entityId == null && nullToAbsent
          ? const Value.absent()
          : Value(entityId),
      entityType: entityType == null && nullToAbsent
          ? const Value.absent()
          : Value(entityType),
      metadata: metadata == null && nullToAbsent
          ? const Value.absent()
          : Value(metadata),
    );
  }

  factory UploadQueueEntry.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UploadQueueEntry(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      localPath: serializer.fromJson<String>(json['localPath']),
      targetPath: serializer.fromJson<String>(json['targetPath']),
      contentType: serializer.fromJson<String>(json['contentType']),
      fileSizeBytes: serializer.fromJson<int>(json['fileSizeBytes']),
      status: serializer.fromJson<String>(json['status']),
      retryCount: serializer.fromJson<int>(json['retryCount']),
      lastError: serializer.fromJson<String?>(json['lastError']),
      queuedAt: serializer.fromJson<DateTime>(json['queuedAt']),
      lastAttemptAt: serializer.fromJson<DateTime?>(json['lastAttemptAt']),
      entityId: serializer.fromJson<String?>(json['entityId']),
      entityType: serializer.fromJson<String?>(json['entityType']),
      metadata: serializer.fromJson<String?>(json['metadata']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'localPath': serializer.toJson<String>(localPath),
      'targetPath': serializer.toJson<String>(targetPath),
      'contentType': serializer.toJson<String>(contentType),
      'fileSizeBytes': serializer.toJson<int>(fileSizeBytes),
      'status': serializer.toJson<String>(status),
      'retryCount': serializer.toJson<int>(retryCount),
      'lastError': serializer.toJson<String?>(lastError),
      'queuedAt': serializer.toJson<DateTime>(queuedAt),
      'lastAttemptAt': serializer.toJson<DateTime?>(lastAttemptAt),
      'entityId': serializer.toJson<String?>(entityId),
      'entityType': serializer.toJson<String?>(entityType),
      'metadata': serializer.toJson<String?>(metadata),
    };
  }

  UploadQueueEntry copyWith(
          {String? id,
          String? userId,
          String? localPath,
          String? targetPath,
          String? contentType,
          int? fileSizeBytes,
          String? status,
          int? retryCount,
          Value<String?> lastError = const Value.absent(),
          DateTime? queuedAt,
          Value<DateTime?> lastAttemptAt = const Value.absent(),
          Value<String?> entityId = const Value.absent(),
          Value<String?> entityType = const Value.absent(),
          Value<String?> metadata = const Value.absent()}) =>
      UploadQueueEntry(
        id: id ?? this.id,
        userId: userId ?? this.userId,
        localPath: localPath ?? this.localPath,
        targetPath: targetPath ?? this.targetPath,
        contentType: contentType ?? this.contentType,
        fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
        status: status ?? this.status,
        retryCount: retryCount ?? this.retryCount,
        lastError: lastError.present ? lastError.value : this.lastError,
        queuedAt: queuedAt ?? this.queuedAt,
        lastAttemptAt:
            lastAttemptAt.present ? lastAttemptAt.value : this.lastAttemptAt,
        entityId: entityId.present ? entityId.value : this.entityId,
        entityType: entityType.present ? entityType.value : this.entityType,
        metadata: metadata.present ? metadata.value : this.metadata,
      );
  UploadQueueEntry copyWithCompanion(UploadQueueEntriesCompanion data) {
    return UploadQueueEntry(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      localPath: data.localPath.present ? data.localPath.value : this.localPath,
      targetPath:
          data.targetPath.present ? data.targetPath.value : this.targetPath,
      contentType:
          data.contentType.present ? data.contentType.value : this.contentType,
      fileSizeBytes: data.fileSizeBytes.present
          ? data.fileSizeBytes.value
          : this.fileSizeBytes,
      status: data.status.present ? data.status.value : this.status,
      retryCount:
          data.retryCount.present ? data.retryCount.value : this.retryCount,
      lastError: data.lastError.present ? data.lastError.value : this.lastError,
      queuedAt: data.queuedAt.present ? data.queuedAt.value : this.queuedAt,
      lastAttemptAt: data.lastAttemptAt.present
          ? data.lastAttemptAt.value
          : this.lastAttemptAt,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      entityType:
          data.entityType.present ? data.entityType.value : this.entityType,
      metadata: data.metadata.present ? data.metadata.value : this.metadata,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UploadQueueEntry(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('localPath: $localPath, ')
          ..write('targetPath: $targetPath, ')
          ..write('contentType: $contentType, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('entityId: $entityId, ')
          ..write('entityType: $entityType, ')
          ..write('metadata: $metadata')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      userId,
      localPath,
      targetPath,
      contentType,
      fileSizeBytes,
      status,
      retryCount,
      lastError,
      queuedAt,
      lastAttemptAt,
      entityId,
      entityType,
      metadata);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UploadQueueEntry &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.localPath == this.localPath &&
          other.targetPath == this.targetPath &&
          other.contentType == this.contentType &&
          other.fileSizeBytes == this.fileSizeBytes &&
          other.status == this.status &&
          other.retryCount == this.retryCount &&
          other.lastError == this.lastError &&
          other.queuedAt == this.queuedAt &&
          other.lastAttemptAt == this.lastAttemptAt &&
          other.entityId == this.entityId &&
          other.entityType == this.entityType &&
          other.metadata == this.metadata);
}

class UploadQueueEntriesCompanion extends UpdateCompanion<UploadQueueEntry> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> localPath;
  final Value<String> targetPath;
  final Value<String> contentType;
  final Value<int> fileSizeBytes;
  final Value<String> status;
  final Value<int> retryCount;
  final Value<String?> lastError;
  final Value<DateTime> queuedAt;
  final Value<DateTime?> lastAttemptAt;
  final Value<String?> entityId;
  final Value<String?> entityType;
  final Value<String?> metadata;
  final Value<int> rowid;
  const UploadQueueEntriesCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.localPath = const Value.absent(),
    this.targetPath = const Value.absent(),
    this.contentType = const Value.absent(),
    this.fileSizeBytes = const Value.absent(),
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    this.queuedAt = const Value.absent(),
    this.lastAttemptAt = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UploadQueueEntriesCompanion.insert({
    required String id,
    required String userId,
    required String localPath,
    required String targetPath,
    this.contentType = const Value.absent(),
    required int fileSizeBytes,
    this.status = const Value.absent(),
    this.retryCount = const Value.absent(),
    this.lastError = const Value.absent(),
    required DateTime queuedAt,
    this.lastAttemptAt = const Value.absent(),
    this.entityId = const Value.absent(),
    this.entityType = const Value.absent(),
    this.metadata = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        userId = Value(userId),
        localPath = Value(localPath),
        targetPath = Value(targetPath),
        fileSizeBytes = Value(fileSizeBytes),
        queuedAt = Value(queuedAt);
  static Insertable<UploadQueueEntry> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? localPath,
    Expression<String>? targetPath,
    Expression<String>? contentType,
    Expression<int>? fileSizeBytes,
    Expression<String>? status,
    Expression<int>? retryCount,
    Expression<String>? lastError,
    Expression<DateTime>? queuedAt,
    Expression<DateTime>? lastAttemptAt,
    Expression<String>? entityId,
    Expression<String>? entityType,
    Expression<String>? metadata,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (localPath != null) 'local_path': localPath,
      if (targetPath != null) 'target_path': targetPath,
      if (contentType != null) 'content_type': contentType,
      if (fileSizeBytes != null) 'file_size_bytes': fileSizeBytes,
      if (status != null) 'status': status,
      if (retryCount != null) 'retry_count': retryCount,
      if (lastError != null) 'last_error': lastError,
      if (queuedAt != null) 'queued_at': queuedAt,
      if (lastAttemptAt != null) 'last_attempt_at': lastAttemptAt,
      if (entityId != null) 'entity_id': entityId,
      if (entityType != null) 'entity_type': entityType,
      if (metadata != null) 'metadata': metadata,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UploadQueueEntriesCompanion copyWith(
      {Value<String>? id,
      Value<String>? userId,
      Value<String>? localPath,
      Value<String>? targetPath,
      Value<String>? contentType,
      Value<int>? fileSizeBytes,
      Value<String>? status,
      Value<int>? retryCount,
      Value<String?>? lastError,
      Value<DateTime>? queuedAt,
      Value<DateTime?>? lastAttemptAt,
      Value<String?>? entityId,
      Value<String?>? entityType,
      Value<String?>? metadata,
      Value<int>? rowid}) {
    return UploadQueueEntriesCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      localPath: localPath ?? this.localPath,
      targetPath: targetPath ?? this.targetPath,
      contentType: contentType ?? this.contentType,
      fileSizeBytes: fileSizeBytes ?? this.fileSizeBytes,
      status: status ?? this.status,
      retryCount: retryCount ?? this.retryCount,
      lastError: lastError ?? this.lastError,
      queuedAt: queuedAt ?? this.queuedAt,
      lastAttemptAt: lastAttemptAt ?? this.lastAttemptAt,
      entityId: entityId ?? this.entityId,
      entityType: entityType ?? this.entityType,
      metadata: metadata ?? this.metadata,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (localPath.present) {
      map['local_path'] = Variable<String>(localPath.value);
    }
    if (targetPath.present) {
      map['target_path'] = Variable<String>(targetPath.value);
    }
    if (contentType.present) {
      map['content_type'] = Variable<String>(contentType.value);
    }
    if (fileSizeBytes.present) {
      map['file_size_bytes'] = Variable<int>(fileSizeBytes.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (retryCount.present) {
      map['retry_count'] = Variable<int>(retryCount.value);
    }
    if (lastError.present) {
      map['last_error'] = Variable<String>(lastError.value);
    }
    if (queuedAt.present) {
      map['queued_at'] = Variable<DateTime>(queuedAt.value);
    }
    if (lastAttemptAt.present) {
      map['last_attempt_at'] = Variable<DateTime>(lastAttemptAt.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<String>(entityId.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (metadata.present) {
      map['metadata'] = Variable<String>(metadata.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UploadQueueEntriesCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('localPath: $localPath, ')
          ..write('targetPath: $targetPath, ')
          ..write('contentType: $contentType, ')
          ..write('fileSizeBytes: $fileSizeBytes, ')
          ..write('status: $status, ')
          ..write('retryCount: $retryCount, ')
          ..write('lastError: $lastError, ')
          ..write('queuedAt: $queuedAt, ')
          ..write('lastAttemptAt: $lastAttemptAt, ')
          ..write('entityId: $entityId, ')
          ..write('entityType: $entityType, ')
          ..write('metadata: $metadata, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $OfflineRecipesTable offlineRecipes = $OfflineRecipesTable(this);
  late final $SyncQueueEntriesTable syncQueueEntries =
      $SyncQueueEntriesTable(this);
  late final $JsonCacheEntriesTable jsonCacheEntries =
      $JsonCacheEntriesTable(this);
  late final $ParseCacheEntriesTable parseCacheEntries =
      $ParseCacheEntriesTable(this);
  late final $UploadQueueEntriesTable uploadQueueEntries =
      $UploadQueueEntriesTable(this);
  late final RecipeDao recipeDao = RecipeDao(this as AppDatabase);
  late final SyncQueueDao syncQueueDao = SyncQueueDao(this as AppDatabase);
  late final CacheDao cacheDao = CacheDao(this as AppDatabase);
  late final UploadQueueDao uploadQueueDao =
      UploadQueueDao(this as AppDatabase);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        offlineRecipes,
        syncQueueEntries,
        jsonCacheEntries,
        parseCacheEntries,
        uploadQueueEntries
      ];
}

typedef $$OfflineRecipesTableCreateCompanionBuilder = OfflineRecipesCompanion
    Function({
  required String id,
  required String userId,
  required String recipeJson,
  required DateTime updatedAt,
  Value<bool> needsSync,
  Value<DateTime?> lastSyncedAt,
  Value<int> rowid,
});
typedef $$OfflineRecipesTableUpdateCompanionBuilder = OfflineRecipesCompanion
    Function({
  Value<String> id,
  Value<String> userId,
  Value<String> recipeJson,
  Value<DateTime> updatedAt,
  Value<bool> needsSync,
  Value<DateTime?> lastSyncedAt,
  Value<int> rowid,
});

class $$OfflineRecipesTableFilterComposer
    extends Composer<_$AppDatabase, $OfflineRecipesTable> {
  $$OfflineRecipesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeJson => $composableBuilder(
      column: $table.recipeJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get needsSync => $composableBuilder(
      column: $table.needsSync, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => ColumnFilters(column));
}

class $$OfflineRecipesTableOrderingComposer
    extends Composer<_$AppDatabase, $OfflineRecipesTable> {
  $$OfflineRecipesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeJson => $composableBuilder(
      column: $table.recipeJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get needsSync => $composableBuilder(
      column: $table.needsSync, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt,
      builder: (column) => ColumnOrderings(column));
}

class $$OfflineRecipesTableAnnotationComposer
    extends Composer<_$AppDatabase, $OfflineRecipesTable> {
  $$OfflineRecipesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get recipeJson => $composableBuilder(
      column: $table.recipeJson, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<bool> get needsSync =>
      $composableBuilder(column: $table.needsSync, builder: (column) => column);

  GeneratedColumn<DateTime> get lastSyncedAt => $composableBuilder(
      column: $table.lastSyncedAt, builder: (column) => column);
}

class $$OfflineRecipesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $OfflineRecipesTable,
    OfflineRecipe,
    $$OfflineRecipesTableFilterComposer,
    $$OfflineRecipesTableOrderingComposer,
    $$OfflineRecipesTableAnnotationComposer,
    $$OfflineRecipesTableCreateCompanionBuilder,
    $$OfflineRecipesTableUpdateCompanionBuilder,
    (
      OfflineRecipe,
      BaseReferences<_$AppDatabase, $OfflineRecipesTable, OfflineRecipe>
    ),
    OfflineRecipe,
    PrefetchHooks Function()> {
  $$OfflineRecipesTableTableManager(
      _$AppDatabase db, $OfflineRecipesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$OfflineRecipesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$OfflineRecipesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$OfflineRecipesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> recipeJson = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
            Value<bool> needsSync = const Value.absent(),
            Value<DateTime?> lastSyncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OfflineRecipesCompanion(
            id: id,
            userId: userId,
            recipeJson: recipeJson,
            updatedAt: updatedAt,
            needsSync: needsSync,
            lastSyncedAt: lastSyncedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String recipeJson,
            required DateTime updatedAt,
            Value<bool> needsSync = const Value.absent(),
            Value<DateTime?> lastSyncedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              OfflineRecipesCompanion.insert(
            id: id,
            userId: userId,
            recipeJson: recipeJson,
            updatedAt: updatedAt,
            needsSync: needsSync,
            lastSyncedAt: lastSyncedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$OfflineRecipesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $OfflineRecipesTable,
    OfflineRecipe,
    $$OfflineRecipesTableFilterComposer,
    $$OfflineRecipesTableOrderingComposer,
    $$OfflineRecipesTableAnnotationComposer,
    $$OfflineRecipesTableCreateCompanionBuilder,
    $$OfflineRecipesTableUpdateCompanionBuilder,
    (
      OfflineRecipe,
      BaseReferences<_$AppDatabase, $OfflineRecipesTable, OfflineRecipe>
    ),
    OfflineRecipe,
    PrefetchHooks Function()>;
typedef $$SyncQueueEntriesTableCreateCompanionBuilder
    = SyncQueueEntriesCompanion Function({
  Value<int> id,
  required String userId,
  required String recipeId,
  required String operation,
  required DateTime queuedAt,
  Value<int> retryCount,
  Value<String?> lastError,
});
typedef $$SyncQueueEntriesTableUpdateCompanionBuilder
    = SyncQueueEntriesCompanion Function({
  Value<int> id,
  Value<String> userId,
  Value<String> recipeId,
  Value<String> operation,
  Value<DateTime> queuedAt,
  Value<int> retryCount,
  Value<String?> lastError,
});

class $$SyncQueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $SyncQueueEntriesTable> {
  $$SyncQueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeId => $composableBuilder(
      column: $table.recipeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
      column: $table.queuedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));
}

class $$SyncQueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncQueueEntriesTable> {
  $$SyncQueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeId => $composableBuilder(
      column: $table.recipeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get operation => $composableBuilder(
      column: $table.operation, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
      column: $table.queuedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));
}

class $$SyncQueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncQueueEntriesTable> {
  $$SyncQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get recipeId =>
      $composableBuilder(column: $table.recipeId, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);
}

class $$SyncQueueEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $SyncQueueEntriesTable,
    SyncQueueEntry,
    $$SyncQueueEntriesTableFilterComposer,
    $$SyncQueueEntriesTableOrderingComposer,
    $$SyncQueueEntriesTableAnnotationComposer,
    $$SyncQueueEntriesTableCreateCompanionBuilder,
    $$SyncQueueEntriesTableUpdateCompanionBuilder,
    (
      SyncQueueEntry,
      BaseReferences<_$AppDatabase, $SyncQueueEntriesTable, SyncQueueEntry>
    ),
    SyncQueueEntry,
    PrefetchHooks Function()> {
  $$SyncQueueEntriesTableTableManager(
      _$AppDatabase db, $SyncQueueEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncQueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncQueueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncQueueEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> recipeId = const Value.absent(),
            Value<String> operation = const Value.absent(),
            Value<DateTime> queuedAt = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
          }) =>
              SyncQueueEntriesCompanion(
            id: id,
            userId: userId,
            recipeId: recipeId,
            operation: operation,
            queuedAt: queuedAt,
            retryCount: retryCount,
            lastError: lastError,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String userId,
            required String recipeId,
            required String operation,
            required DateTime queuedAt,
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
          }) =>
              SyncQueueEntriesCompanion.insert(
            id: id,
            userId: userId,
            recipeId: recipeId,
            operation: operation,
            queuedAt: queuedAt,
            retryCount: retryCount,
            lastError: lastError,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$SyncQueueEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $SyncQueueEntriesTable,
    SyncQueueEntry,
    $$SyncQueueEntriesTableFilterComposer,
    $$SyncQueueEntriesTableOrderingComposer,
    $$SyncQueueEntriesTableAnnotationComposer,
    $$SyncQueueEntriesTableCreateCompanionBuilder,
    $$SyncQueueEntriesTableUpdateCompanionBuilder,
    (
      SyncQueueEntry,
      BaseReferences<_$AppDatabase, $SyncQueueEntriesTable, SyncQueueEntry>
    ),
    SyncQueueEntry,
    PrefetchHooks Function()>;
typedef $$JsonCacheEntriesTableCreateCompanionBuilder
    = JsonCacheEntriesCompanion Function({
  required String boxName,
  required String userId,
  required String key,
  required String value,
  required DateTime cachedAt,
  Value<int> rowid,
});
typedef $$JsonCacheEntriesTableUpdateCompanionBuilder
    = JsonCacheEntriesCompanion Function({
  Value<String> boxName,
  Value<String> userId,
  Value<String> key,
  Value<String> value,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

class $$JsonCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $JsonCacheEntriesTable> {
  $$JsonCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get boxName => $composableBuilder(
      column: $table.boxName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$JsonCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $JsonCacheEntriesTable> {
  $$JsonCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get boxName => $composableBuilder(
      column: $table.boxName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get key => $composableBuilder(
      column: $table.key, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get value => $composableBuilder(
      column: $table.value, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$JsonCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $JsonCacheEntriesTable> {
  $$JsonCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get boxName =>
      $composableBuilder(column: $table.boxName, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$JsonCacheEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $JsonCacheEntriesTable,
    JsonCacheEntry,
    $$JsonCacheEntriesTableFilterComposer,
    $$JsonCacheEntriesTableOrderingComposer,
    $$JsonCacheEntriesTableAnnotationComposer,
    $$JsonCacheEntriesTableCreateCompanionBuilder,
    $$JsonCacheEntriesTableUpdateCompanionBuilder,
    (
      JsonCacheEntry,
      BaseReferences<_$AppDatabase, $JsonCacheEntriesTable, JsonCacheEntry>
    ),
    JsonCacheEntry,
    PrefetchHooks Function()> {
  $$JsonCacheEntriesTableTableManager(
      _$AppDatabase db, $JsonCacheEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JsonCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JsonCacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JsonCacheEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> boxName = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> key = const Value.absent(),
            Value<String> value = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              JsonCacheEntriesCompanion(
            boxName: boxName,
            userId: userId,
            key: key,
            value: value,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String boxName,
            required String userId,
            required String key,
            required String value,
            required DateTime cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              JsonCacheEntriesCompanion.insert(
            boxName: boxName,
            userId: userId,
            key: key,
            value: value,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JsonCacheEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $JsonCacheEntriesTable,
    JsonCacheEntry,
    $$JsonCacheEntriesTableFilterComposer,
    $$JsonCacheEntriesTableOrderingComposer,
    $$JsonCacheEntriesTableAnnotationComposer,
    $$JsonCacheEntriesTableCreateCompanionBuilder,
    $$JsonCacheEntriesTableUpdateCompanionBuilder,
    (
      JsonCacheEntry,
      BaseReferences<_$AppDatabase, $JsonCacheEntriesTable, JsonCacheEntry>
    ),
    JsonCacheEntry,
    PrefetchHooks Function()>;
typedef $$ParseCacheEntriesTableCreateCompanionBuilder
    = ParseCacheEntriesCompanion Function({
  required String cacheKey,
  required String userId,
  required String recipeJson,
  required String parserVersion,
  required String source,
  required DateTime cachedAt,
  Value<int> rowid,
});
typedef $$ParseCacheEntriesTableUpdateCompanionBuilder
    = ParseCacheEntriesCompanion Function({
  Value<String> cacheKey,
  Value<String> userId,
  Value<String> recipeJson,
  Value<String> parserVersion,
  Value<String> source,
  Value<DateTime> cachedAt,
  Value<int> rowid,
});

class $$ParseCacheEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $ParseCacheEntriesTable> {
  $$ParseCacheEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get cacheKey => $composableBuilder(
      column: $table.cacheKey, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get recipeJson => $composableBuilder(
      column: $table.recipeJson, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get parserVersion => $composableBuilder(
      column: $table.parserVersion, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnFilters(column));
}

class $$ParseCacheEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $ParseCacheEntriesTable> {
  $$ParseCacheEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get cacheKey => $composableBuilder(
      column: $table.cacheKey, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get recipeJson => $composableBuilder(
      column: $table.recipeJson, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get parserVersion => $composableBuilder(
      column: $table.parserVersion,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get source => $composableBuilder(
      column: $table.source, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get cachedAt => $composableBuilder(
      column: $table.cachedAt, builder: (column) => ColumnOrderings(column));
}

class $$ParseCacheEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $ParseCacheEntriesTable> {
  $$ParseCacheEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get cacheKey =>
      $composableBuilder(column: $table.cacheKey, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get recipeJson => $composableBuilder(
      column: $table.recipeJson, builder: (column) => column);

  GeneratedColumn<String> get parserVersion => $composableBuilder(
      column: $table.parserVersion, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get cachedAt =>
      $composableBuilder(column: $table.cachedAt, builder: (column) => column);
}

class $$ParseCacheEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ParseCacheEntriesTable,
    ParseCacheEntry,
    $$ParseCacheEntriesTableFilterComposer,
    $$ParseCacheEntriesTableOrderingComposer,
    $$ParseCacheEntriesTableAnnotationComposer,
    $$ParseCacheEntriesTableCreateCompanionBuilder,
    $$ParseCacheEntriesTableUpdateCompanionBuilder,
    (
      ParseCacheEntry,
      BaseReferences<_$AppDatabase, $ParseCacheEntriesTable, ParseCacheEntry>
    ),
    ParseCacheEntry,
    PrefetchHooks Function()> {
  $$ParseCacheEntriesTableTableManager(
      _$AppDatabase db, $ParseCacheEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ParseCacheEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ParseCacheEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ParseCacheEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> cacheKey = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> recipeJson = const Value.absent(),
            Value<String> parserVersion = const Value.absent(),
            Value<String> source = const Value.absent(),
            Value<DateTime> cachedAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              ParseCacheEntriesCompanion(
            cacheKey: cacheKey,
            userId: userId,
            recipeJson: recipeJson,
            parserVersion: parserVersion,
            source: source,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String cacheKey,
            required String userId,
            required String recipeJson,
            required String parserVersion,
            required String source,
            required DateTime cachedAt,
            Value<int> rowid = const Value.absent(),
          }) =>
              ParseCacheEntriesCompanion.insert(
            cacheKey: cacheKey,
            userId: userId,
            recipeJson: recipeJson,
            parserVersion: parserVersion,
            source: source,
            cachedAt: cachedAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ParseCacheEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ParseCacheEntriesTable,
    ParseCacheEntry,
    $$ParseCacheEntriesTableFilterComposer,
    $$ParseCacheEntriesTableOrderingComposer,
    $$ParseCacheEntriesTableAnnotationComposer,
    $$ParseCacheEntriesTableCreateCompanionBuilder,
    $$ParseCacheEntriesTableUpdateCompanionBuilder,
    (
      ParseCacheEntry,
      BaseReferences<_$AppDatabase, $ParseCacheEntriesTable, ParseCacheEntry>
    ),
    ParseCacheEntry,
    PrefetchHooks Function()>;
typedef $$UploadQueueEntriesTableCreateCompanionBuilder
    = UploadQueueEntriesCompanion Function({
  required String id,
  required String userId,
  required String localPath,
  required String targetPath,
  Value<String> contentType,
  required int fileSizeBytes,
  Value<String> status,
  Value<int> retryCount,
  Value<String?> lastError,
  required DateTime queuedAt,
  Value<DateTime?> lastAttemptAt,
  Value<String?> entityId,
  Value<String?> entityType,
  Value<String?> metadata,
  Value<int> rowid,
});
typedef $$UploadQueueEntriesTableUpdateCompanionBuilder
    = UploadQueueEntriesCompanion Function({
  Value<String> id,
  Value<String> userId,
  Value<String> localPath,
  Value<String> targetPath,
  Value<String> contentType,
  Value<int> fileSizeBytes,
  Value<String> status,
  Value<int> retryCount,
  Value<String?> lastError,
  Value<DateTime> queuedAt,
  Value<DateTime?> lastAttemptAt,
  Value<String?> entityId,
  Value<String?> entityType,
  Value<String?> metadata,
  Value<int> rowid,
});

class $$UploadQueueEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $UploadQueueEntriesTable> {
  $$UploadQueueEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get targetPath => $composableBuilder(
      column: $table.targetPath, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get queuedAt => $composableBuilder(
      column: $table.queuedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnFilters(column));
}

class $$UploadQueueEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $UploadQueueEntriesTable> {
  $$UploadQueueEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userId => $composableBuilder(
      column: $table.userId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get localPath => $composableBuilder(
      column: $table.localPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get targetPath => $composableBuilder(
      column: $table.targetPath, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get status => $composableBuilder(
      column: $table.status, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastError => $composableBuilder(
      column: $table.lastError, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get queuedAt => $composableBuilder(
      column: $table.queuedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityId => $composableBuilder(
      column: $table.entityId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get metadata => $composableBuilder(
      column: $table.metadata, builder: (column) => ColumnOrderings(column));
}

class $$UploadQueueEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UploadQueueEntriesTable> {
  $$UploadQueueEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get localPath =>
      $composableBuilder(column: $table.localPath, builder: (column) => column);

  GeneratedColumn<String> get targetPath => $composableBuilder(
      column: $table.targetPath, builder: (column) => column);

  GeneratedColumn<String> get contentType => $composableBuilder(
      column: $table.contentType, builder: (column) => column);

  GeneratedColumn<int> get fileSizeBytes => $composableBuilder(
      column: $table.fileSizeBytes, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<int> get retryCount => $composableBuilder(
      column: $table.retryCount, builder: (column) => column);

  GeneratedColumn<String> get lastError =>
      $composableBuilder(column: $table.lastError, builder: (column) => column);

  GeneratedColumn<DateTime> get queuedAt =>
      $composableBuilder(column: $table.queuedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastAttemptAt => $composableBuilder(
      column: $table.lastAttemptAt, builder: (column) => column);

  GeneratedColumn<String> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
      column: $table.entityType, builder: (column) => column);

  GeneratedColumn<String> get metadata =>
      $composableBuilder(column: $table.metadata, builder: (column) => column);
}

class $$UploadQueueEntriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UploadQueueEntriesTable,
    UploadQueueEntry,
    $$UploadQueueEntriesTableFilterComposer,
    $$UploadQueueEntriesTableOrderingComposer,
    $$UploadQueueEntriesTableAnnotationComposer,
    $$UploadQueueEntriesTableCreateCompanionBuilder,
    $$UploadQueueEntriesTableUpdateCompanionBuilder,
    (
      UploadQueueEntry,
      BaseReferences<_$AppDatabase, $UploadQueueEntriesTable, UploadQueueEntry>
    ),
    UploadQueueEntry,
    PrefetchHooks Function()> {
  $$UploadQueueEntriesTableTableManager(
      _$AppDatabase db, $UploadQueueEntriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UploadQueueEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UploadQueueEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UploadQueueEntriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> userId = const Value.absent(),
            Value<String> localPath = const Value.absent(),
            Value<String> targetPath = const Value.absent(),
            Value<String> contentType = const Value.absent(),
            Value<int> fileSizeBytes = const Value.absent(),
            Value<String> status = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            Value<DateTime> queuedAt = const Value.absent(),
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<String?> entityId = const Value.absent(),
            Value<String?> entityType = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UploadQueueEntriesCompanion(
            id: id,
            userId: userId,
            localPath: localPath,
            targetPath: targetPath,
            contentType: contentType,
            fileSizeBytes: fileSizeBytes,
            status: status,
            retryCount: retryCount,
            lastError: lastError,
            queuedAt: queuedAt,
            lastAttemptAt: lastAttemptAt,
            entityId: entityId,
            entityType: entityType,
            metadata: metadata,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String userId,
            required String localPath,
            required String targetPath,
            Value<String> contentType = const Value.absent(),
            required int fileSizeBytes,
            Value<String> status = const Value.absent(),
            Value<int> retryCount = const Value.absent(),
            Value<String?> lastError = const Value.absent(),
            required DateTime queuedAt,
            Value<DateTime?> lastAttemptAt = const Value.absent(),
            Value<String?> entityId = const Value.absent(),
            Value<String?> entityType = const Value.absent(),
            Value<String?> metadata = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UploadQueueEntriesCompanion.insert(
            id: id,
            userId: userId,
            localPath: localPath,
            targetPath: targetPath,
            contentType: contentType,
            fileSizeBytes: fileSizeBytes,
            status: status,
            retryCount: retryCount,
            lastError: lastError,
            queuedAt: queuedAt,
            lastAttemptAt: lastAttemptAt,
            entityId: entityId,
            entityType: entityType,
            metadata: metadata,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UploadQueueEntriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UploadQueueEntriesTable,
    UploadQueueEntry,
    $$UploadQueueEntriesTableFilterComposer,
    $$UploadQueueEntriesTableOrderingComposer,
    $$UploadQueueEntriesTableAnnotationComposer,
    $$UploadQueueEntriesTableCreateCompanionBuilder,
    $$UploadQueueEntriesTableUpdateCompanionBuilder,
    (
      UploadQueueEntry,
      BaseReferences<_$AppDatabase, $UploadQueueEntriesTable, UploadQueueEntry>
    ),
    UploadQueueEntry,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$OfflineRecipesTableTableManager get offlineRecipes =>
      $$OfflineRecipesTableTableManager(_db, _db.offlineRecipes);
  $$SyncQueueEntriesTableTableManager get syncQueueEntries =>
      $$SyncQueueEntriesTableTableManager(_db, _db.syncQueueEntries);
  $$JsonCacheEntriesTableTableManager get jsonCacheEntries =>
      $$JsonCacheEntriesTableTableManager(_db, _db.jsonCacheEntries);
  $$ParseCacheEntriesTableTableManager get parseCacheEntries =>
      $$ParseCacheEntriesTableTableManager(_db, _db.parseCacheEntries);
  $$UploadQueueEntriesTableTableManager get uploadQueueEntries =>
      $$UploadQueueEntriesTableTableManager(_db, _db.uploadQueueEntries);
}
