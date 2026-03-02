"""
Train a CRF model for Swedish ingredient parsing.

Reads CoNLL-format training data, trains with python-crfsuite,
evaluates on held-out test set, and exports weights as JSON
matching CrfWeights.fromJson() schema.

Dependencies: python-crfsuite, scikit-learn
Usage: python scripts/crf/train_crf.py --input training.conll --output assets/data/crf_ingredient_weights.json
"""

import argparse
import json
import os
import re
from collections import defaultdict

import pycrfsuite
from sklearn.model_selection import train_test_split
from sklearn.metrics import classification_report

# Lexicons loaded from Dart-exported JSON (single source of truth).
# Run `dart run scripts/crf/export_lexicons.dart` to regenerate.
_SCRIPT_DIR = os.path.dirname(os.path.abspath(__file__))
_LEXICON_PATH = os.path.join(_SCRIPT_DIR, 'data', 'lexicons.json')

FRACTION_CHARS = set('½¼¾⅓⅔⅛⅜⅝⅞')

# Edge case vocabularies (must match Dart CrfFeatureExtractor)
CONJUNCTIONS = {'eller', 'och', 'alternativt'}
OPTIONAL_MARKERS = {
    'ev', 'ev.', 'eventuellt', 'gärna', 'ca', 'cirka',
    'valfritt', 'drygt', 'knappt', 'lite',
}

TEXT_QUANTITIES = {
    'en', 'ett', 'två', 'tre', 'fyra', 'fem', 'sex', 'sju',
    'åtta', 'nio', 'tio', 'halv', 'halva', 'halvt',
}
PURPOSE_MARKER = 'till'

_RANGE_PATTERN = re.compile(r'^\d+-\d+$')
_PAREN_PATTERN = re.compile(r'^[()]$')

# Compound word detection (must match Dart SwedishCompoundSplitter)
_FOOD_SUFFIXES = {
    'sås', 'buljong', 'fond', 'mjölk', 'grädde', 'olja', 'smör',
    'ost', 'pulver', 'flingor', 'gryn', 'frön', 'kärnor', 'nötter',
    'bär', 'sylt', 'juice', 'vatten', 'kross', 'puré', 'pasta',
    'socker', 'sirap', 'vinäger', 'peppar', 'krydda', 'salt',
    'mjöl', 'deg', 'bröd', 'kaka', 'färs', 'filé', 'kotlett',
    'korv', 'skinka', 'fläsk', 'kött', 'fisk', 'lök',
    'press', 'kvarn', 'mos',
}
_MIN_PART_LEN = 3
_JOINERS = ['s', '']
# Compound names from lexicons (loaded with foods)
_COMPOUND_NAMES = set()  # populated in _load_lexicons


def _load_lexicons():
    if not os.path.exists(_LEXICON_PATH):
        raise FileNotFoundError(
            f'Lexicon file not found: {_LEXICON_PATH}\n'
            'Run: dart run scripts/crf/export_lexicons.dart'
        )
    with open(_LEXICON_PATH, encoding='utf-8') as f:
        data = json.load(f)
    global _COMPOUND_NAMES
    _COMPOUND_NAMES = set(data.get('compound_names', []))
    return {
        'units': set(data['units']),
        'prep_words': set(data['prep_words']),
        'size_words': set(data['size_words']),
        'foods': set(data['foods']),
    }


_lexicons = _load_lexicons()
KNOWN_UNITS = _lexicons['units']
PREP_WORDS = _lexicons['prep_words']
SIZE_WORDS = _lexicons['size_words']
KNOWN_FOODS = _lexicons['foods']


def _is_known_food_part(part):
    return part in KNOWN_FOODS or part in _FOOD_SUFFIXES


# Swedish definite form normalization (must match Dart SwedishDefiniteNormalizer)
_DEFINITE_SUFFIXES = [
    ('erna', ''),    # tomaterna → tomat
    ('arna', ''),    # lökarna → lök
    ('en', ''),      # löken → lök
    ('en', 'e'),     # grädden → grädde (restore trailing -e)
    ('et', ''),      # smöret → smör
    ('na', ''),      # äpplena → äpple
    ('n', ''),       # pastan → pasta
    ('t', ''),       # köttet → kött
]


def try_normalize_definite(word):
    """Try to strip Swedish definite suffix and match to known ingredient."""
    lower = word.lower()
    if len(lower) < 4:
        return None
    if lower in KNOWN_FOODS:
        return None
    for suffix, restore in _DEFINITE_SUFFIXES:
        if not lower.endswith(suffix):
            continue
        stripped = lower[:len(lower) - len(suffix)]
        if len(stripped) < 2:
            continue
        candidate = stripped + restore
        if candidate in KNOWN_FOODS:
            return candidate
        if not restore and stripped in KNOWN_FOODS:
            return stripped
    # Doubled consonant pattern: "nötten" → "nöt"
    for suffix in ['en', 'et']:
        if not lower.endswith(suffix):
            continue
        before = lower[:len(lower) - len(suffix)]
        if len(before) >= 3 and before[-1] == before[-2]:
            undoubled = before[:-1]
            if undoubled in KNOWN_FOODS:
                return undoubled
    return None


def try_compound_split(word):
    """Try to split a Swedish compound word into (prefix, suffix)."""
    lower = word.lower()
    if len(lower) < _MIN_PART_LEN * 2:
        return None
    if lower in _COMPOUND_NAMES or lower in KNOWN_FOODS:
        return None
    for suffix_len in range(len(lower) - _MIN_PART_LEN, _MIN_PART_LEN - 1, -1):
        suffix = lower[len(lower) - suffix_len:]
        if not _is_known_food_part(suffix):
            continue
        prefix_part = lower[:len(lower) - suffix_len]
        for joiner in _JOINERS:
            if not prefix_part.endswith(joiner):
                continue
            prefix = prefix_part if not joiner else prefix_part[:-len(joiner)]
            if len(prefix) < _MIN_PART_LEN:
                continue
            if _is_known_food_part(prefix):
                return (prefix, suffix)
    return None


def is_digit(s):
    return bool(re.match(r'^[\d,.\-/]+$', s))


def is_fraction(s):
    return any(c in FRACTION_CHARS for c in s) or bool(re.match(r'^\d+/\d+$', s))


def is_range(s):
    return bool(_RANGE_PATTERN.match(s))


def is_group_header(s):
    return s.endswith(':') and 1 < len(s) < 40


def _token_type(lower):
    """Classify token into coarse type for type-level bigrams (must match Dart)."""
    if is_digit(lower) or is_fraction(lower):
        return 'NUM'
    if lower in TEXT_QUANTITIES:
        return 'NUM'
    if lower in KNOWN_UNITS:
        return 'UNIT'
    if lower in KNOWN_FOODS:
        return 'FOOD'
    if try_normalize_definite(lower):
        return 'FOOD'
    if lower in PREP_WORDS:
        return 'PREP'
    if lower in SIZE_WORDS:
        return 'SIZE'
    if lower in CONJUNCTIONS:
        return 'CONJ'
    if lower in OPTIONAL_MARKERS:
        return 'OPT'
    if lower == PURPOSE_MARKER:
        return 'PURPOSE'
    if bool(_PAREN_PATTERN.match(lower)):
        return 'PAREN'
    if is_group_header(lower):
        return 'HEADER'
    return 'WORD'


def extract_features(tokens, i):
    """Extract features for token at position i, matching Dart CrfFeatureExtractor."""
    token = tokens[i]
    lower = token.lower()
    features = {}

    def add_token_features(word, prefix=''):
        features[f'{prefix}word.lower={word}'] = 1.0
        features[f'{prefix}word.isDigit'] = 1.0 if is_digit(word) else 0.0
        features[f'{prefix}word.isFraction'] = 1.0 if is_fraction(word) else 0.0
        features[f'{prefix}word.isUnit'] = 1.0 if word in KNOWN_UNITS else 0.0
        features[f'{prefix}word.isFood'] = 1.0 if word in KNOWN_FOODS else 0.0
        features[f'{prefix}word.isPrep'] = 1.0 if word in PREP_WORDS else 0.0
        features[f'{prefix}word.isSize'] = 1.0 if word in SIZE_WORDS else 0.0
        features[f'{prefix}word.hasComma'] = 1.0 if ',' in word else 0.0
        # Edge case features
        features[f'{prefix}word.isRange'] = 1.0 if is_range(word) else 0.0
        features[f'{prefix}word.isConjunction'] = 1.0 if word in CONJUNCTIONS else 0.0
        features[f'{prefix}word.isOptional'] = 1.0 if word in OPTIONAL_MARKERS else 0.0
        features[f'{prefix}word.isGroupHeader'] = 1.0 if is_group_header(word) else 0.0
        features[f'{prefix}word.isParen'] = 1.0 if bool(_PAREN_PATTERN.match(word)) else 0.0
        features[f'{prefix}word.isTextQty'] = 1.0 if word in TEXT_QUANTITIES else 0.0
        features[f'{prefix}word.isPurpose'] = 1.0 if word == PURPOSE_MARKER else 0.0
        # Compound word detection
        compound = try_compound_split(word)
        features[f'{prefix}word.isCompound'] = 1.0 if compound else 0.0
        if compound:
            features[f'{prefix}word.compoundSuffix={compound[1]}'] = 1.0
        # Definite form detection (löken → lök)
        base_form = try_normalize_definite(word)
        features[f'{prefix}word.isDefinite'] = 1.0 if base_form else 0.0
        if base_form:
            features[f'{prefix}word.baseForm={base_form}'] = 1.0
        # Length
        features[f'{prefix}word.len'] = len(word) / 20.0
        if len(word) >= 2:
            features[f'{prefix}word.suffix2={word[-2:]}'] = 1.0
        if len(word) >= 3:
            features[f'{prefix}word.suffix3={word[-3:]}'] = 1.0
        # Prefix features
        if len(word) >= 2:
            features[f'{prefix}word.prefix2={word[:2]}'] = 1.0

    def add_reduced_features(word, prefix):
        """Reduced feature set for window-2 context."""
        features[f'{prefix}word.isDigit'] = 1.0 if is_digit(word) else 0.0
        features[f'{prefix}word.isUnit'] = 1.0 if word in KNOWN_UNITS else 0.0
        features[f'{prefix}word.isFood'] = 1.0 if word in KNOWN_FOODS else 0.0
        features[f'{prefix}word.isPrep'] = 1.0 if word in PREP_WORDS else 0.0

    # Current token (full feature set)
    add_token_features(lower)

    # Boundary markers
    if i == 0:
        features['BOS'] = 1.0
    if i == len(tokens) - 1:
        features['EOS'] = 1.0

    # Window-1 context (full feature set)
    if i > 0:
        add_token_features(tokens[i - 1].lower(), 'prev.')
    if i < len(tokens) - 1:
        add_token_features(tokens[i + 1].lower(), 'next.')

    # Bigram features (captures word transitions)
    if i > 0:
        prev_lower = tokens[i - 1].lower()
        features[f'bigram.prev={prev_lower}|cur={lower}'] = 1.0
    if i < len(tokens) - 1:
        next_lower = tokens[i + 1].lower()
        features[f'bigram.cur={lower}|next={next_lower}'] = 1.0

    # Type-level bigram features (more generalizable)
    if i > 0:
        prev_type = _token_type(tokens[i - 1].lower())
        cur_type = _token_type(lower)
        features[f'typeBigram.prev={prev_type}|cur={cur_type}'] = 1.0
    if i < len(tokens) - 1:
        cur_type = _token_type(lower)
        next_type = _token_type(tokens[i + 1].lower())
        features[f'typeBigram.cur={cur_type}|next={next_type}'] = 1.0

    # Window-2 context (reduced feature set)
    if i > 1:
        add_reduced_features(tokens[i - 2].lower(), 'prev2.')
    if i < len(tokens) - 2:
        add_reduced_features(tokens[i + 2].lower(), 'next2.')

    return features


def read_conll(path):
    """Read CoNLL format: token\\tlabel, blank lines separate sequences."""
    sequences = []
    current_tokens = []
    current_labels = []

    with open(path, encoding='utf-8') as f:
        for line in f:
            line = line.strip()
            if not line:
                if current_tokens:
                    sequences.append((current_tokens, current_labels))
                    current_tokens = []
                    current_labels = []
                continue

            parts = line.split('\t')
            if len(parts) >= 2:
                current_tokens.append(parts[0])
                current_labels.append(parts[1])

    if current_tokens:
        sequences.append((current_tokens, current_labels))

    return sequences


def sequences_to_features(sequences):
    """Convert sequences to feature dicts for python-crfsuite."""
    X, y = [], []
    for tokens, labels in sequences:
        x_seq = []
        for i in range(len(tokens)):
            feats = extract_features(tokens, i)
            # python-crfsuite wants list of "key=value" strings
            x_seq.append({k: v for k, v in feats.items()})
        X.append(x_seq)
        y.append(labels)
    return X, y


def export_weights(model_path, output_path):
    """Export trained CRF weights to JSON matching CrfWeights.fromJson()."""
    tagger = pycrfsuite.Tagger()
    tagger.open(model_path)

    labels = tagger.labels()
    info = tagger.info()

    # Feature weights: label -> {feature: weight}
    features = defaultdict(dict)
    state_features = info.state_features
    for (attr, label), weight in state_features.items():
        if abs(weight) > 0.001:  # Skip near-zero weights
            features[label][attr] = round(weight, 4)

    # Transition weights: from_label -> {to_label: weight}
    transitions = defaultdict(dict)
    trans_features = info.transitions
    for (from_label, to_label), weight in trans_features.items():
        transitions[from_label][to_label] = round(weight, 4)

    result = {
        'features': dict(features),
        'transitions': dict(transitions),
    }

    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(result, f, indent=2, ensure_ascii=False)

    tagger.close()
    print(f'Exported weights to {output_path}')
    print(f'  Labels: {labels}')
    print(f'  Feature entries: {sum(len(v) for v in features.values())}')
    print(f'  Transition entries: {sum(len(v) for v in transitions.values())}')


def main():
    parser = argparse.ArgumentParser(description='Train CRF for ingredient parsing')
    parser.add_argument('--input', required=True, help='CoNLL training file')
    parser.add_argument('--output', required=True, help='Output JSON weights file')
    parser.add_argument('--test-size', type=float, default=0.2, help='Test set fraction')
    args = parser.parse_args()

    sequences = read_conll(args.input)
    print(f'Loaded {len(sequences)} sequences')

    X, y = sequences_to_features(sequences)

    X_train, X_test, y_train, y_test = train_test_split(
        X, y, test_size=args.test_size, random_state=42
    )
    print(f'Train: {len(X_train)}, Test: {len(X_test)}')

    # Train
    trainer = pycrfsuite.Trainer(verbose=True)
    for x_seq, y_seq in zip(X_train, y_train):
        trainer.append(x_seq, y_seq)

    trainer.set_params({
        'c1': 0.1,      # L1 regularization
        'c2': 0.01,     # L2 regularization
        'max_iterations': 200,
        'feature.possible_transitions': True,
    })

    model_path = args.output.replace('.json', '.crfsuite')
    trainer.train(model_path)

    # Evaluate
    tagger = pycrfsuite.Tagger()
    tagger.open(model_path)

    y_pred = [tagger.tag(x_seq) for x_seq in X_test]

    # Flatten for classification report
    y_test_flat = [label for seq in y_test for label in seq]
    y_pred_flat = [label for seq in y_pred for label in seq]

    print('\n' + classification_report(y_test_flat, y_pred_flat))
    tagger.close()

    # Export to JSON
    export_weights(model_path, args.output)


if __name__ == '__main__':
    main()
