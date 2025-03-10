/* AUTOMATICALLY GENERATED CODE DO NOT MODIFY */
/*   To generate run: "serverpod generate"    */

// ignore_for_file: library_private_types_in_public_api
// ignore_for_file: public_member_api_docs
// ignore_for_file: implementation_imports
// ignore_for_file: use_super_parameters
// ignore_for_file: type_literal_in_constant_pattern

// ignore_for_file: no_leading_underscores_for_library_prefixes
import 'package:serverpod/serverpod.dart' as _i1;
import '../protocol.dart' as _i2;

abstract class DatabaseMigrationWarning extends _i1.SerializableEntity {
  DatabaseMigrationWarning._({
    required this.type,
    required this.message,
    required this.table,
    required this.columns,
    required this.destrucive,
  });

  factory DatabaseMigrationWarning({
    required _i2.DatabaseMigrationWarningType type,
    required String message,
    required String table,
    required List<String> columns,
    required bool destrucive,
  }) = _DatabaseMigrationWarningImpl;

  factory DatabaseMigrationWarning.fromJson(
    Map<String, dynamic> jsonSerialization,
    _i1.SerializationManager serializationManager,
  ) {
    return DatabaseMigrationWarning(
      type: serializationManager.deserialize<_i2.DatabaseMigrationWarningType>(
          jsonSerialization['type']),
      message: serializationManager
          .deserialize<String>(jsonSerialization['message']),
      table:
          serializationManager.deserialize<String>(jsonSerialization['table']),
      columns: serializationManager
          .deserialize<List<String>>(jsonSerialization['columns']),
      destrucive: serializationManager
          .deserialize<bool>(jsonSerialization['destrucive']),
    );
  }

  _i2.DatabaseMigrationWarningType type;

  String message;

  String table;

  List<String> columns;

  bool destrucive;

  DatabaseMigrationWarning copyWith({
    _i2.DatabaseMigrationWarningType? type,
    String? message,
    String? table,
    List<String>? columns,
    bool? destrucive,
  });
  @override
  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'message': message,
      'table': table,
      'columns': columns,
      'destrucive': destrucive,
    };
  }

  @override
  Map<String, dynamic> allToJson() {
    return {
      'type': type,
      'message': message,
      'table': table,
      'columns': columns,
      'destrucive': destrucive,
    };
  }
}

class _DatabaseMigrationWarningImpl extends DatabaseMigrationWarning {
  _DatabaseMigrationWarningImpl({
    required _i2.DatabaseMigrationWarningType type,
    required String message,
    required String table,
    required List<String> columns,
    required bool destrucive,
  }) : super._(
          type: type,
          message: message,
          table: table,
          columns: columns,
          destrucive: destrucive,
        );

  @override
  DatabaseMigrationWarning copyWith({
    _i2.DatabaseMigrationWarningType? type,
    String? message,
    String? table,
    List<String>? columns,
    bool? destrucive,
  }) {
    return DatabaseMigrationWarning(
      type: type ?? this.type,
      message: message ?? this.message,
      table: table ?? this.table,
      columns: columns ?? this.columns.clone(),
      destrucive: destrucive ?? this.destrucive,
    );
  }
}
