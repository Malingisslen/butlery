import 'package:cloud_firestore/cloud_firestore.dart';

abstract class RecipeRepository {
  FirebaseFirestore get firestore;
}

class FirebaseRecipeRepository implements RecipeRepository {
  @override
  final FirebaseFirestore firestore = FirebaseFirestore.instance;
}
