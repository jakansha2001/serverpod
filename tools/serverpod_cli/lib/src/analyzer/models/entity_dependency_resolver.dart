import 'dart:math';

import 'package:serverpod_cli/src/analyzer/models/checker/analyze_checker.dart';
import 'package:serverpod_cli/src/analyzer/models/definitions.dart';
import 'package:serverpod_cli/src/generator/types.dart';
import 'package:super_string/super_string.dart';

class ModelDependencyResolver {
  /// Resolves dependencies between models, this method mutates the input.
  static void resolveModelDependencies(
    List<SerializableModelDefinition> modelDefinitions,
  ) {
    modelDefinitions.whereType<ClassDefinition>().forEach((classDefinition) {
      for (var fieldDefinition in classDefinition.fields) {
        _resolveFieldIndexes(fieldDefinition, classDefinition);
        _resolveProtocolReference(fieldDefinition, modelDefinitions);
        _resolveEnumType(fieldDefinition, modelDefinitions);
        _resolveObjectRelationReference(
          classDefinition,
          fieldDefinition,
          modelDefinitions,
        );
        _resolveListRelationReference(
          classDefinition,
          fieldDefinition,
          modelDefinitions,
        );
      }
    });
  }

  static void _resolveFieldIndexes(
    SerializableModelFieldDefinition fieldDefinition,
    ClassDefinition classDefinition,
  ) {
    var indexes = classDefinition.indexes;
    if (indexes.isEmpty) return;

    var indexesContainingField = indexes
        .where((index) => index.fields.contains(fieldDefinition.name))
        .toList();

    fieldDefinition.indexes = indexesContainingField;
  }

  static TypeDefinition _resolveProtocolReference(
      SerializableModelFieldDefinition fieldDefinition,
      List<SerializableModelDefinition> modelDefinitions) {
    return fieldDefinition.type = fieldDefinition.type.applyProtocolReferences(
      modelDefinitions,
    );
  }

  static void _resolveEnumType(
    SerializableModelFieldDefinition fieldDefinition,
    List<SerializableModelDefinition> modelDefinitions,
  ) {
    var enumDefinitionList = modelDefinitions
        .whereType<EnumDefinition>()
        .where((e) => e.className == fieldDefinition.type.className)
        .toList();

    if (enumDefinitionList.isEmpty) return;

    fieldDefinition.type.serializeEnum = enumDefinitionList.first.serialized;
  }

  static void _resolveObjectRelationReference(
    ClassDefinition classDefinition,
    SerializableModelFieldDefinition fieldDefinition,
    List<SerializableModelDefinition> modelDefinitions,
  ) {
    var relation = fieldDefinition.relation;
    if (relation is! UnresolvedObjectRelationDefinition) return;

    var referenceClass = modelDefinitions
        .cast<SerializableModelDefinition?>()
        .firstWhere(
            (model) => model?.className == fieldDefinition.type.className,
            orElse: () => null);

    if (referenceClass is! ClassDefinition) return;

    var tableName = referenceClass.tableName;
    if (tableName is! String) return;

    var foreignField = _findForeignFieldByRelationName(
      classDefinition,
      referenceClass,
      fieldDefinition.name,
      relation.name,
    );

    var relationFieldName = relation.fieldName;
    if (relationFieldName != null) {
      _resolveManualDefinedRelation(
        classDefinition,
        fieldDefinition,
        relation,
        tableName,
        relationFieldName,
      );
    } else if (relation.name == null ||
        (foreignField != null && foreignField.type.isListType)) {
      _resolveImplicitDefinedRelation(
        classDefinition,
        fieldDefinition,
        relation,
        tableName,
      );
    } else if (foreignField != null) {
      _resolveNamedForeignObjectRelation(
        fieldDefinition,
        relation,
        tableName,
        foreignField,
      );
    }
  }

  static void _resolveNamedForeignObjectRelation(
    SerializableModelFieldDefinition fieldDefinition,
    UnresolvedObjectRelationDefinition relation,
    String tableName,
    SerializableModelFieldDefinition foreignField,
  ) {
    String? foreignFieldName;

    // No need to check ObjectRelationDefinition as it will never be named on
    // the relational origin side. This case is covered by
    // checking the ForeignRelationDefinition.
    var foreignRelation = foreignField.relation;
    if (foreignRelation is UnresolvedObjectRelationDefinition) {
      foreignFieldName = foreignRelation.fieldName;
    } else if (foreignRelation is ForeignRelationDefinition) {
      foreignFieldName = foreignField.name;
    }

    if (foreignFieldName == null) return;

    fieldDefinition.relation = ObjectRelationDefinition(
      name: relation.name,
      parentTable: tableName,
      fieldName: defaultPrimaryKeyName,
      foreignFieldName: foreignFieldName,
      isForeignKeyOrigin: relation.isForeignKeyOrigin,
      nullableRelation: foreignField.type.nullable,
    );
  }

  static void _resolveImplicitDefinedRelation(
    ClassDefinition classDefinition,
    SerializableModelFieldDefinition fieldDefinition,
    UnresolvedObjectRelationDefinition relation,
    String tableName,
  ) {
    var relationFieldType = relation.nullableRelation
        ? TypeDefinition.int.asNullable
        : TypeDefinition.int;

    var foreignRelationField = SerializableModelFieldDefinition(
      name: _createImplicitForeignIdFieldName(fieldDefinition.name),
      relation: ForeignRelationDefinition(
        name: relation.name,
        parentTable: tableName,
        foreignFieldName: defaultPrimaryKeyName,
        onUpdate: relation.onUpdate,
        onDelete: relation.onDelete,
      ),
      shouldPersist: true,
      scope: fieldDefinition.scope,
      type: relationFieldType,
    );

    _injectForeignRelationField(
      classDefinition,
      fieldDefinition,
      foreignRelationField,
    );

    fieldDefinition.relation = ObjectRelationDefinition(
      parentTable: tableName,
      fieldName: '${fieldDefinition.name}Id',
      foreignFieldName: defaultPrimaryKeyName,
      isForeignKeyOrigin: true,
      nullableRelation: relation.nullableRelation,
    );
  }

  static void _resolveManualDefinedRelation(
    ClassDefinition classDefinition,
    SerializableModelFieldDefinition fieldDefinition,
    UnresolvedObjectRelationDefinition relation,
    String tableName,
    String relationFieldName,
  ) {
    var field = classDefinition.findField(relationFieldName);
    if (field == null) return;

    if (field.relation != null) {
      fieldDefinition.relation = UnresolvableObjectRelationDefinition(
        relation,
        UnresolvableReason.relationAlreadyDefinedForField,
      );
      return;
    }

    field.relation = ForeignRelationDefinition(
      name: relation.name,
      parentTable: tableName,
      foreignFieldName: defaultPrimaryKeyName,
      onUpdate: relation.onUpdate,
      onDelete: relation.onDelete,
    );

    fieldDefinition.relation = ObjectRelationDefinition(
      parentTable: tableName,
      fieldName: relationFieldName,
      foreignFieldName: defaultPrimaryKeyName,
      isForeignKeyOrigin: true,
      nullableRelation: field.type.nullable,
    );
  }

  static SerializableModelFieldDefinition? _findForeignFieldByRelationName(
    ClassDefinition classDefinition,
    ClassDefinition foreignClass,
    String fieldName,
    String? relationName,
  ) {
    var foreignFields = AnalyzeChecker.filterRelationByName(
      classDefinition,
      foreignClass,
      fieldName,
      relationName,
    );
    if (foreignFields.isEmpty) return null;

    return foreignFields.first;
  }

  static void _injectForeignRelationField(
    ClassDefinition classDefinition,
    SerializableModelFieldDefinition fieldDefinition,
    SerializableModelFieldDefinition foreignRelationField,
  ) {
    var insertIndex = max(
      classDefinition.fields.indexOf(fieldDefinition),
      0,
    );
    classDefinition.fields = [
      ...classDefinition.fields.take(insertIndex),
      foreignRelationField,
      ...classDefinition.fields.skip(insertIndex),
    ];
  }

  static void _resolveListRelationReference(
    ClassDefinition classDefinition,
    SerializableModelFieldDefinition fieldDefinition,
    List<SerializableModelDefinition> modelDefinitions,
  ) {
    var relation = fieldDefinition.relation;
    if (relation is! UnresolvedListRelationDefinition) {
      return;
    }

    var type = fieldDefinition.type;
    var referenceClassName = type.generics.first.className;

    var referenceClass =
        modelDefinitions.cast<SerializableModelDefinition?>().firstWhere(
              (model) => model?.className == referenceClassName,
              orElse: () => null,
            );

    if (referenceClass is! ClassDefinition) return;

    var tableName = classDefinition.tableName;
    if (tableName == null) return;

    if (relation.name == null) {
      var foreignFieldName =
          '_${classDefinition.tableName?.toCamelCase(isLowerCamelCase: true)}${fieldDefinition.name.toCamelCase()}${classDefinition.tableName?.toCamelCase()}Id';

      var autoRelationName = '#_relation_$foreignFieldName';

      referenceClass.fields.add(
        SerializableModelFieldDefinition(
          name: foreignFieldName,
          type: TypeDefinition.int.asNullable,
          scope: ModelFieldScopeDefinition.none,
          shouldPersist: true,
          relation: ForeignRelationDefinition(
            name: autoRelationName,
            parentTable: tableName,
            foreignFieldName: defaultPrimaryKeyName,
          ),
        ),
      );

      fieldDefinition.relation = ListRelationDefinition(
        name: autoRelationName,
        fieldName: 'id',
        foreignFieldName: foreignFieldName,
        nullableRelation: true,
        implicitForeignField: true,
      );
    } else {
      var foreignFields = referenceClass.fields.where((field) {
        var fieldRelation = field.relation;
        if (!(fieldRelation is UnresolvedObjectRelationDefinition ||
            fieldRelation is ForeignRelationDefinition)) return false;
        return fieldRelation?.name == relation.name;
      });

      if (foreignFields.isEmpty) return;

      var foreignField = foreignFields.first;

      String? foreignFieldName;

      var foreignRelation = foreignField.relation;
      if (foreignRelation is ForeignRelationDefinition) {
        foreignFieldName = foreignField.name;
      } else if (foreignRelation is UnresolvedObjectRelationDefinition) {
        foreignFieldName = foreignRelation.fieldName ??
            _createImplicitForeignIdFieldName(foreignField.name);
      }

      if (foreignFieldName == null) return;

      fieldDefinition.relation = ListRelationDefinition(
        name: relation.name,
        fieldName: 'id',
        foreignFieldName: foreignFieldName,
        nullableRelation: foreignFields.first.type.nullable,
      );
    }
  }

  static String _createImplicitForeignIdFieldName(String fieldName) {
    return '${fieldName}Id';
  }
}
