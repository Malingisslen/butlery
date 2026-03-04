import 'package:flutter_test/flutter_test.dart';
import 'package:butlery/services/parsing/ner/wordpiece_tokenizer.dart';

// Minimal vocab for testing — matches BERT special tokens + common Swedish
const _testVocab = '''[PAD]
[UNK]
[CLS]
[SEP]
[MASK]
mjölk
smör
salt
dl
msk
g
2
1
,
(
)
hack
##ad
##e
##t
##s
##en
färsk
basilika
citron
##saft
##skal
stor
liten
och
peppar''';

void main() {
  late WordPieceTokenizer tokenizer;

  setUp(() {
    tokenizer = WordPieceTokenizer.fromVocabString(
      _testVocab,
      maxInputLength: 32,
      isCased: true,
    );
  });

  group('construction', () {
    test('should load vocabulary from string', () {
      expect(tokenizer.vocabSize, 31);
      expect(tokenizer.clsTokenId, 2); // [CLS] is at index 2
      expect(tokenizer.sepTokenId, 3); // [SEP] is at index 3
      expect(tokenizer.padTokenId, 0); // [PAD] is at index 0
      expect(tokenizer.unkTokenId, 1); // [UNK] is at index 1
    });
  });

  group('tokenizeWords', () {
    test('should tokenize simple known words', () {
      final result = tokenizer.tokenizeWords(['2', 'dl', 'mjölk']);

      // Should be: [CLS] 2 dl mjölk [SEP] + padding
      expect(result.sequenceLength, 5); // CLS + 3 words + SEP
      expect(result.inputIds[0], tokenizer.clsTokenId);
      expect(result.inputIds[4], tokenizer.sepTokenId);

      // Word IDs: null, 0, 1, 2, null, null...
      expect(result.wordIds[0], isNull); // CLS
      expect(result.wordIds[1], 0); // "2"
      expect(result.wordIds[2], 1); // "dl"
      expect(result.wordIds[3], 2); // "mjölk"
      expect(result.wordIds[4], isNull); // SEP
    });

    test('should handle compound words with subword tokenization', () {
      // "citronsaft" → "citron" + "##saft" (both in vocab)
      final result = tokenizer.tokenizeWords(['citronsaft']);

      // CLS + citron + ##saft + SEP = 4 tokens
      expect(result.sequenceLength, 4);
      // Both subwords should map to word 0
      expect(result.wordIds[1], 0);
      expect(result.wordIds[2], 0);
    });

    test('should produce UNK for unknown words', () {
      final result = tokenizer.tokenizeWords(['xyzzy']);

      expect(result.sequenceLength, 3); // CLS + UNK + SEP
      expect(result.inputIds[1], tokenizer.unkTokenId);
    });

    test('should pad to maxInputLength', () {
      final result = tokenizer.tokenizeWords(['salt']);

      expect(result.inputIds.length, 32);
      expect(result.attentionMask.length, 32);
      // Non-padded tokens should have attention 1
      expect(result.attentionMask[0], 1); // CLS
      expect(result.attentionMask[1], 1); // salt
      expect(result.attentionMask[2], 1); // SEP
      // Padding should have attention 0
      expect(result.attentionMask[3], 0);
      expect(result.attentionMask[31], 0);
    });

    test('should truncate long sequences', () {
      // Create a sequence longer than maxInputLength (32)
      final words = List.generate(40, (i) => 'salt');
      final result = tokenizer.tokenizeWords(words);

      expect(result.inputIds.length, 32);
      // Should have CLS at start and SEP at end
      expect(result.inputIds[0], tokenizer.clsTokenId);
      // Last non-padding token should be SEP
      final lastReal = result.attentionMask.lastIndexOf(1);
      expect(result.inputIds[lastReal], tokenizer.sepTokenId);
    });

    test('should handle empty input', () {
      final result = tokenizer.tokenizeWords([]);

      // Just CLS + SEP
      expect(result.sequenceLength, 2);
      expect(result.inputIds[0], tokenizer.clsTokenId);
      expect(result.inputIds[1], tokenizer.sepTokenId);
    });
  });

  group('firstSubwordIndices', () {
    test('should map word indices to first subword positions', () {
      // "hackad" → "hack" + "##ad" (2 subwords for word 0)
      // "salt" → "salt" (1 subword for word 1)
      final result = tokenizer.tokenizeWords(['hackad', 'salt']);

      final mapping = result.firstSubwordIndices;
      expect(mapping[0], 1); // "hackad" → position 1 (after CLS)
      expect(mapping[1], 3); // "salt" → position 3 (after CLS, hack, ##ad)
    });
  });

  group('decodeIds', () {
    test('should convert token IDs back to strings', () {
      final tokens = tokenizer.decodeIds([2, 5, 8, 3]); // CLS mjölk dl SEP
      expect(tokens, ['[CLS]', 'mjölk', 'dl', '[SEP]']);
    });

    test('should return UNK for invalid IDs', () {
      final tokens = tokenizer.decodeIds([9999]);
      expect(tokens, ['[UNK]']);
    });
  });

  group('case sensitivity', () {
    test('cased tokenizer should preserve case', () {
      final cased = WordPieceTokenizer.fromVocabString(
        _testVocab,
        maxInputLength: 32,
        isCased: true,
      );
      // "Salt" (uppercase S) not in vocab → UNK
      final result = cased.tokenizeWords(['Salt']);
      expect(result.inputIds[1], cased.unkTokenId);
    });

    test('uncased tokenizer should lowercase', () {
      // Add "salt" to vocab (which it already is at index 7)
      final uncased = WordPieceTokenizer.fromVocabString(
        _testVocab,
        maxInputLength: 32,
        isCased: false,
      );
      // "Salt" should be lowercased to "salt" and found in vocab
      final result = uncased.tokenizeWords(['Salt']);
      expect(result.inputIds[1], isNot(uncased.unkTokenId));
    });
  });
}
