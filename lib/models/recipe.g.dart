// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeAdapter extends TypeAdapter<Recipe> {
  @override
  final int typeId = 0;

  @override
  Recipe read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Recipe(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String,
      portions: fields[3] as int?,
      timeMinutes: fields[4] as int?,
      ingredients: (fields[5] as List).cast<String>(),
      instructions: (fields[6] as List).cast<String>(),
      tags: (fields[7] as List?)?.cast<String>(),
      rating: fields[8] as double?,
      imageUrl: fields[9] as String?,
      mealType: fields[10] as String,
      sourceUrl: fields[11] as String?,
      createdAt: fields[12] as DateTime?,
      updatedAt: fields[13] as DateTime?,
      lastSyncedAt: fields[14] as DateTime?,
      isModifiedOffline: fields[15] as bool,
      lastCookedAt: fields[16] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, Recipe obj) {
    writer
      ..writeByte(17)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.description)
      ..writeByte(3)
      ..write(obj.portions)
      ..writeByte(4)
      ..write(obj.timeMinutes)
      ..writeByte(5)
      ..write(obj.ingredients)
      ..writeByte(6)
      ..write(obj.instructions)
      ..writeByte(7)
      ..write(obj.tags)
      ..writeByte(8)
      ..write(obj.rating)
      ..writeByte(9)
      ..write(obj.imageUrl)
      ..writeByte(10)
      ..write(obj.mealType)
      ..writeByte(11)
      ..write(obj.sourceUrl)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(14)
      ..write(obj.lastSyncedAt)
      ..writeByte(15)
      ..write(obj.isModifiedOffline)
      ..writeByte(16)
      ..write(obj.lastCookedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
