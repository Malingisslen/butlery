library;

import 'package:butlery/services/menu/parser/lexicon_provider.dart';

class CompositeLexiconProvider implements LexiconProvider {
  final LexiconProvider _code;
  final LexiconProvider _firestore;

  const CompositeLexiconProvider({
    required LexiconProvider code,
    required LexiconProvider firestore,
  }) : _code = code,
       _firestore = firestore;

  @override
  Future<Lexicon> load() async {
    final results = await Future.wait([_code.load(), _firestore.load()]);
    return results[0].mergedWith(results[1]);
  }
}
