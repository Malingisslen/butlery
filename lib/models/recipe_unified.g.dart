// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_unified.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class RecipeCoreAdapter extends TypeAdapter<RecipeCore> {
  @override
  final int typeId = 1;

  @override
  RecipeCore read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return RecipeCore(
      id: fields[0] as String?,
      title: fields[1] as String,
      description: fields[2] as String,
      portions: fields[3] as int?,
      timeMinutes: fields[4] as int?,
      ingredients: (fields[5] as List).cast<String>(),
      instructions: (fields[6] as List).cast<String>(),
      tags: (fields[7] as List?)?.cast<String>(),
      rating: fields[8] as double?,
      mealType: fields[9] as String,
      sourceUrl: fields[10] as String?,
      imageUrls: (fields[11] as List?)?.cast<String>(),
      createdAt: fields[12] as DateTime?,
      updatedAt: fields[13] as DateTime?,
      createdBy: fields[14] as String?,
      isPublic: fields[15] as bool,
      lastCookedAt: fields[16] as DateTime?,
      ingredientsNormalized: (fields[17] as List?)?.cast<String>(),
      ratingCount: fields[18] as int?,
      averageRating: fields[19] as double?,
      ratingDistribution: (fields[20] as Map?)?.cast<int, int>(),
      lastRatedAt: fields[21] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, RecipeCore obj) {
    writer
      ..writeByte(22)
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
      ..write(obj.mealType)
      ..writeByte(10)
      ..write(obj.sourceUrl)
      ..writeByte(11)
      ..write(obj.imageUrls)
      ..writeByte(12)
      ..write(obj.createdAt)
      ..writeByte(13)
      ..write(obj.updatedAt)
      ..writeByte(14)
      ..write(obj.createdBy)
      ..writeByte(15)
      ..write(obj.isPublic)
      ..writeByte(16)
      ..write(obj.lastCookedAt)
      ..writeByte(17)
      ..write(obj.ingredientsNormalized)
      ..writeByte(18)
      ..write(obj.ratingCount)
      ..writeByte(19)
      ..write(obj.averageRating)
      ..writeByte(20)
      ..write(obj.ratingDistribution)
      ..writeByte(21)
      ..write(obj.lastRatedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is RecipeCoreAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
