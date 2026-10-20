// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'recipe_dao.dart';

// ignore_for_file: type=lint
mixin _$RecipeDaoMixin on DatabaseAccessor<AppDatabase> {
  $OfflineRecipesTable get offlineRecipes => attachedDatabase.offlineRecipes;
  RecipeDaoManager get managers => RecipeDaoManager(this);
}

class RecipeDaoManager {
  final _$RecipeDaoMixin _db;
  RecipeDaoManager(this._db);
  $$OfflineRecipesTableTableManager get offlineRecipes =>
      $$OfflineRecipesTableTableManager(
        _db.attachedDatabase,
        _db.offlineRecipes,
      );
}
