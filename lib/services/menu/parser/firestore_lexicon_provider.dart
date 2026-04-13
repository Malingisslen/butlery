/// [LexiconProvider] backed by Firestore via [FirebaseMenuLexiconRepository].
///
/// Returns a partial [Lexicon] containing only the categories that have
/// overrides in Firestore. The caller merges this with the code defaults
/// via [CompositeLexiconProvider].
library;

import 'package:butlery/repositories/firebase/firebase_menu_lexicon_repository.dart';
import 'package:butlery/services/menu/parser/lexicon_provider.dart';

class FirestoreLexiconProvider implements LexiconProvider {
  final FirebaseMenuLexiconRepository _repository;

  const FirestoreLexiconProvider({
    required FirebaseMenuLexiconRepository repository,
  }) : _repository = repository;

  @override
  Future<Lexicon> load() async {
    final overrides = await _repository.loadOverrides();
    return Lexicon(overrides);
  }
}
