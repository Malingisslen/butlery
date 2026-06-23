import 'dart:convert';
import 'dart:typed_data';

/// Pure Dart WordPiece tokenizer matching BERT's tokenization.
///
/// Performs the same tokenization as HuggingFace's BertTokenizer:
/// 1. Unicode normalization and lowercasing (for cased models, skip lowercasing)
/// 2. Whitespace tokenization
/// 3. Punctuation splitting
/// 4. WordPiece subword tokenization using vocab lookup
///
/// The vocabulary must match the model's vocab.txt exactly.
class WordPieceTokenizer {
  final Map<String, int> _vocab;
  final int _unkTokenId;
  final int _clsTokenId;
  final int _sepTokenId;
  final int _padTokenId;
  final int maxInputLength;

  /// Whether this is a cased model (preserves case).
  final bool isCased;

  /// Reverse map built lazily — only needed for debug decoding.
  late final Map<int, String> _idToToken = {
    for (final e in _vocab.entries) e.value: e.key,
  };

  static const String _unkToken = '[UNK]';
  static const String _clsToken = '[CLS]';
  static const String _sepToken = '[SEP]';
  static const String _padToken = '[PAD]';
  static const String _continuationPrefix = '##';
  static const int _maxWordLength = 200;

  WordPieceTokenizer._({
    required Map<String, int> vocab,
    required this.maxInputLength,
    required this.isCased,
  }) : _vocab = vocab,
       _unkTokenId = vocab[_unkToken] ?? 0,
       _clsTokenId = vocab[_clsToken] ?? 101,
       _sepTokenId = vocab[_sepToken] ?? 102,
       _padTokenId = vocab[_padToken] ?? 0;

  /// Load vocabulary from vocab.txt content (one token per line).
  factory WordPieceTokenizer.fromVocabString(
    String vocabContent, {
    int maxInputLength = 128,
    bool isCased = true,
  }) {
    final vocab = <String, int>{};
    final lines = const LineSplitter().convert(vocabContent);
    for (var i = 0; i < lines.length; i++) {
      final token = lines[i].trim();
      if (token.isNotEmpty) {
        vocab[token] = i;
      }
    }
    return WordPieceTokenizer._(
      vocab: vocab,
      maxInputLength: maxInputLength,
      isCased: isCased,
    );
  }

  int get vocabSize => _vocab.length;
  int get clsTokenId => _clsTokenId;
  int get sepTokenId => _sepTokenId;
  int get padTokenId => _padTokenId;
  int get unkTokenId => _unkTokenId;

  /// Tokenize pre-split words into token IDs with word-to-subword alignment.
  ///
  /// Returns a [TokenizedInput] with:
  /// - inputIds: [CLS] + subword_ids + [SEP], padded to maxInputLength
  /// - attentionMask: 1 for real tokens, 0 for padding
  /// - wordIds: maps each position to the original word index (null for special/pad tokens)
  ///
  /// [words] should be pre-tokenized using the same tokenizer as CRF
  /// (whitespace + punctuation splitting from CrfIngredientParser.tokenize).
  TokenizedInput tokenizeWords(List<String> words) {
    final allSubwordIds = <int>[];
    final wordIdMapping = <int?>[];

    // [CLS]
    allSubwordIds.add(_clsTokenId);
    wordIdMapping.add(null);

    for (var wordIdx = 0; wordIdx < words.length; wordIdx++) {
      final word = isCased ? words[wordIdx] : words[wordIdx].toLowerCase();
      final subwordIds = _wordPieceTokenize(word);

      for (var j = 0; j < subwordIds.length; j++) {
        if (allSubwordIds.length >= maxInputLength - 1) {
          break; // Leave room for [SEP]
        }
        allSubwordIds.add(subwordIds[j]);
        wordIdMapping.add(wordIdx);
      }

      if (allSubwordIds.length >= maxInputLength - 1) break;
    }

    // [SEP]
    allSubwordIds.add(_sepTokenId);
    wordIdMapping.add(null);

    // Pad to maxInputLength — use Int64List directly for ONNX compatibility
    final seqLen = allSubwordIds.length;
    final inputIds = Int64List(maxInputLength);
    final attentionMask = Int64List(maxInputLength);
    final paddedWordIds = List<int?>.filled(maxInputLength, null);

    // Fill pad token for inputIds (attentionMask defaults to 0)
    for (var i = 0; i < maxInputLength; i++) {
      inputIds[i] = _padTokenId;
    }
    for (var i = 0; i < seqLen; i++) {
      inputIds[i] = allSubwordIds[i];
      attentionMask[i] = 1;
      paddedWordIds[i] = wordIdMapping[i];
    }

    return TokenizedInput(
      inputIds: inputIds,
      attentionMask: attentionMask,
      wordIds: paddedWordIds,
      sequenceLength: seqLen,
    );
  }

  /// WordPiece tokenize a single word into subword token IDs.
  ///
  /// Greedy longest-match-first algorithm:
  /// 1. Try to match the longest prefix in vocab
  /// 2. If matched, continue with the remainder prefixed by "##"
  /// 3. If no match found, return [UNK]
  List<int> _wordPieceTokenize(String word) {
    if (word.length > _maxWordLength) {
      return [_unkTokenId];
    }

    final tokens = <int>[];
    var start = 0;
    var isFirst = true;

    while (start < word.length) {
      var end = word.length;
      int? matchedId;

      while (start < end) {
        final substr = isFirst
            ? word.substring(start, end)
            : '$_continuationPrefix${word.substring(start, end)}';

        final id = _vocab[substr];
        if (id != null) {
          matchedId = id;
          break;
        }
        end--;
      }

      if (matchedId == null) {
        // No subword found — entire word is unknown
        return [_unkTokenId];
      }

      tokens.add(matchedId);
      start = end;
      isFirst = false;
    }

    return tokens.isEmpty ? [_unkTokenId] : tokens;
  }

  /// Convert token IDs back to token strings.
  List<String> decodeIds(List<int> ids) {
    return ids.map((id) => _idToToken[id] ?? _unkToken).toList();
  }
}

/// Result of tokenizing a sequence of words.
class TokenizedInput {
  /// Token IDs including [CLS], subwords, [SEP], and padding.
  /// Int64List for direct ONNX Runtime consumption (no copy needed).
  final Int64List inputIds;

  /// 1 for real tokens, 0 for padding.
  /// Int64List for direct ONNX Runtime consumption (no copy needed).
  final Int64List attentionMask;

  /// Maps each position to the original word index.
  /// null for [CLS], [SEP], and padding positions.
  final List<int?> wordIds;

  /// Number of non-padding tokens (including [CLS] and [SEP]).
  final int sequenceLength;

  TokenizedInput({
    required this.inputIds,
    required this.attentionMask,
    required this.wordIds,
    required this.sequenceLength,
  });

  /// Indices of the first subword for each original word.
  /// Used to extract word-level predictions from subword-level logits.
  late final Map<int, int> firstSubwordIndices = () {
    final result = <int, int>{};
    for (var i = 0; i < wordIds.length; i++) {
      final wordId = wordIds[i];
      if (wordId != null && !result.containsKey(wordId)) {
        result[wordId] = i;
      }
    }
    return result;
  }();
}
