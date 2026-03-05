#!/usr/bin/env python3
"""
Generate silver training data for the neural line classifier.

Reimplements the core SwedishLineClassifier scoring logic from
lib/services/parsing/parsers/swedish_line_classifier.dart in Python.
Runs on recipe text files and produces labeled data for lines
where the classifier has high confidence (>= 0.8).

Usage:
    python generate_silver_data.py --input-dir recipes/ --output silver_data.json
    python generate_silver_data.py --input-file recipe.txt --output silver_data.json
"""

import argparse
import json
import os
import re
from pathlib import Path

# --- Constants matching Dart implementation ---

SWEDISH_UNITS = {
    # Volume
    'dl', 'l', 'ml', 'cl', 'liter',
    # Weight
    'g', 'kg', 'hg', 'gram', 'kilo',
    # Cooking measures
    'msk', 'tsk', 'krm', 'matsked', 'tesked', 'kryddmått',
    # Packaging
    'st', 'bit', 'burk', 'pkt', 'paket', 'förp', 'påse',
    'skiva', 'klyfta', 'knippe', 'nypa', 'skvätt',
    # American (often used in Swedish recipes)
    'cup', 'cups', 'tbsp', 'tsp', 'oz',
}

COOKING_VERBS = {
    # Preparation
    'skär', 'hacka', 'skala', 'riv', 'mosa', 'blanda', 'vispa', 'rör',
    'mixa', 'knåda', 'forma', 'kavla', 'fyll', 'garnera',
    # Cooking
    'koka', 'stek', 'fräs', 'grilla', 'grädda', 'baka', 'ugnssteka',
    'bryn', 'sjud', 'puttra', 'reducera', 'smält', 'värm',
    # Timing/Process
    'låt', 'vila', 'ställ', 'sätt', 'ta', 'häll', 'tillsätt', 'strö',
    'servera', 'toppa', 'lägg', 'placera', 'vänd', 'rosta',
    # Common starts
    'börja', 'förvärm', 'förbered',
}

# Top ~100 most common Swedish food words (subset of KnownIngredients.all)
SWEDISH_FOOD_WORDS = {
    'mjölk', 'smör', 'ägg', 'mjöl', 'vetemjöl', 'socker', 'salt', 'peppar',
    'lök', 'vitlök', 'morot', 'potatis', 'tomat', 'gurka', 'paprika',
    'kyckling', 'kycklingfilé', 'köttfärs', 'fläskfilé', 'nötkött', 'lax',
    'räkor', 'torsk', 'fisk', 'bacon', 'korv', 'skinka',
    'ris', 'pasta', 'spaghetti', 'nudlar', 'couscous', 'bulgur',
    'grädde', 'crème fraiche', 'gräddfil', 'yoghurt', 'ost', 'fetaost',
    'parmesan', 'mozzarella', 'cream cheese',
    'olivolja', 'rapsolja', 'vinäger', 'soja', 'fisksås', 'tomatpuré',
    'buljong', 'fond', 'kokosmjölk',
    'basilika', 'dill', 'persilja', 'koriander', 'rosmarin', 'timjan',
    'oregano', 'kanel', 'kardemumma', 'ingefära', 'chili', 'curry',
    'spiskummin', 'paprikapulver', 'gurkmeja', 'vaniljsocker',
    'kakao', 'choklad',
    'bönor', 'linser', 'kikärtor', 'kidneybönor', 'svarta bönor',
    'avokado', 'spenat', 'broccoli', 'blomkål', 'zucchini', 'aubergine',
    'champinjoner', 'svamp', 'oliver', 'majs', 'ärtor',
    'äpple', 'citron', 'lime', 'banan', 'bär', 'jordgubbar', 'hallon',
    'blåbär', 'mango', 'apelsin', 'kokos',
    'vatten', 'vin', 'öl', 'kaffe',
    'bröd', 'tortilla', 'naanbröd',
    'havregryn', 'chiafrön', 'honung', 'lönnsirap', 'sirap',
    'jäst', 'bakpulver', 'bikarbonat', 'potatismjöl', 'maizena',
    'nötter', 'mandel', 'valnötter', 'cashew', 'jordnötter',
    'lingonsylt', 'sylt', 'senap', 'ketchup', 'majonnäs',
}

# Regex patterns matching Dart implementation
QUANTITY_PATTERN = re.compile(
    r'^(\d+[\.,]?\d*|½|¼|¾|\d+\s*½|\d+\s*¼|\d+\s*¾|\d+/\d+)\s*',
    re.IGNORECASE,
)
STEP_PATTERN = re.compile(
    r'^(\d+[\.\):]|\d+\s*[\.\):]|steg\s*\d+)',
    re.IGNORECASE,
)
TIME_PATTERN = re.compile(
    r'(\d+)\s*(min(ut(er)?)?|tim(me|mar)?|h|sek(und(er)?)?)',
    re.IGNORECASE,
)
PORTIONS_PATTERN = re.compile(
    r'(\d+)\s*(port(ion(er)?)?|pers(on(er)?)?)(\s|$)',
    re.IGNORECASE,
)

INGREDIENT_HEADERS = [
    re.compile(r'^ingrediens(er)?:?\s*$', re.IGNORECASE),
    re.compile(r'^du behöver:?\s*$', re.IGNORECASE),
    re.compile(r'^detta behövs:?\s*$', re.IGNORECASE),
    re.compile(r'^det här behöver du:?\s*$', re.IGNORECASE),
]

INSTRUCTION_HEADERS = [
    re.compile(r'^(gör\s+så\s+här|så\s+gör\s+du):?\s*$', re.IGNORECASE),
    re.compile(r'^instruktion(er)?:?\s*$', re.IGNORECASE),
    re.compile(r'^tillagnin(g|gssätt):?\s*$', re.IGNORECASE),
    re.compile(r'^framställning:?\s*$', re.IGNORECASE),
    re.compile(r'^steg:?\s*$', re.IGNORECASE),
    re.compile(r'^metod:?\s*$', re.IGNORECASE),
]

# Additional sub-section headers (e.g. "Deg:", "Fyllning:", "Sås:")
SUBSECTION_PATTERN = re.compile(
    r'^[A-ZÅÄÖ][a-zåäö]+:?\s*$'
)


def is_section_header(text: str) -> bool:
    for p in INGREDIENT_HEADERS + INSTRUCTION_HEADERS:
        if p.match(text):
            return True
    if SUBSECTION_PATTERN.match(text) and len(text) < 25:
        return True
    return False


def is_metadata(text: str) -> bool:
    if len(text) > 50:
        return False
    return bool(TIME_PATTERN.search(text) or PORTIONS_PATTERN.search(text))


def score_as_ingredient(text: str) -> float:
    score = 0.0
    lower = text.lower()
    words = lower.split()

    # Quantity at start (but not step numbers)
    if QUANTITY_PATTERN.match(text) and not STEP_PATTERN.match(text):
        score += 0.4

    # Swedish units
    for unit in SWEDISH_UNITS:
        if (unit in words or
            f' {unit} ' in lower or
            f' {unit},' in lower or
            lower.endswith(f' {unit}')):
            score += 0.3
            break

    # Food words (word-set matching for single words, substring for multi-word)
    word_set = set(words)
    food_count = 0
    for food in SWEDISH_FOOD_WORDS:
        if ' ' in food:
            if food in lower:
                food_count += 1
        else:
            if food in word_set:
                food_count += 1
    score += min(food_count * 0.15, 0.3)

    # Short lines more likely ingredients
    if len(text) < 50:
        score += 0.1

    # No cooking verb at start
    first_word = words[0] if words else ''
    if first_word not in COOKING_VERBS:
        score += 0.05

    return min(score, 1.0)


def score_as_instruction(text: str) -> float:
    score = 0.0
    lower = text.lower()
    words = lower.split()

    # Step number at start
    if STEP_PATTERN.match(text):
        score += 0.35

    # Cooking verb at start
    first_word = words[0] if words else ''
    if first_word in COOKING_VERBS:
        score += 0.4

    # Cooking verbs anywhere
    verb_count = sum(1 for v in COOKING_VERBS if v in words)
    score += min(verb_count * 0.1, 0.2)

    # Longer lines more likely instructions
    if len(text) > 40:
        score += 0.1
    if len(text) > 80:
        score += 0.1

    # Ends with period
    if text.endswith('.'):
        score += 0.1

    return min(score, 1.0)


def classify_line(line: str) -> tuple[str, float]:
    """Classify a single line. Returns (label, confidence)."""
    trimmed = line.strip()

    if not trimmed:
        return 'empty', 1.0

    if is_section_header(trimmed):
        return 'sectionHeader', 0.95

    if is_metadata(trimmed):
        return 'metadata', 0.85

    ing_score = score_as_ingredient(trimmed)
    ins_score = score_as_instruction(trimmed)

    if ing_score > 0.6 and ing_score > ins_score:
        return 'ingredient', ing_score

    if ins_score >= 0.5 and ins_score > ing_score:
        return 'instruction', ins_score

    # Title check: short, no quantities, possibly capitalized
    if 3 <= len(trimmed) <= 60:
        if not QUANTITY_PATTERN.match(trimmed) and not STEP_PATTERN.match(trimmed):
            if trimmed[0] == trimmed[0].upper():
                return 'title', 0.6

    return 'noise', 0.4


def process_text(text: str, source: str = 'unknown') -> list[dict]:
    """Process a recipe text and return high-confidence labeled lines."""
    results = []
    for line in text.split('\n'):
        label, confidence = classify_line(line)
        if confidence >= 0.8:
            results.append({
                'text': line.strip() if label != 'empty' else '',
                'label': label,
                'confidence': round(confidence, 3),
                'source': source,
            })
    return results


def main():
    parser = argparse.ArgumentParser(
        description='Generate silver training data for neural line classifier'
    )
    parser.add_argument(
        '--input-dir', type=str,
        help='Directory containing .txt recipe files'
    )
    parser.add_argument(
        '--input-file', type=str,
        help='Single text file with recipes separated by blank lines'
    )
    parser.add_argument(
        '--output', type=str, default='data/silver_data.json',
        help='Output JSON file path'
    )
    parser.add_argument(
        '--min-confidence', type=float, default=0.8,
        help='Minimum confidence threshold (default: 0.8)'
    )
    args = parser.parse_args()

    all_results = []

    if args.input_dir:
        input_dir = Path(args.input_dir)
        for txt_file in sorted(input_dir.glob('*.txt')):
            text = txt_file.read_text(encoding='utf-8')
            results = process_text(text, source=txt_file.stem)
            all_results.extend(results)
            print(f'  {txt_file.name}: {len(results)} lines')

    elif args.input_file:
        text = Path(args.input_file).read_text(encoding='utf-8')
        all_results = process_text(text, source=Path(args.input_file).stem)

    else:
        parser.error('Either --input-dir or --input-file is required')

    # Filter by confidence
    filtered = [r for r in all_results if r['confidence'] >= args.min_confidence]

    # Write output
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    with open(output_path, 'w', encoding='utf-8') as f:
        json.dump(filtered, f, ensure_ascii=False, indent=2)

    # Stats
    labels = {}
    for item in filtered:
        labels[item['label']] = labels.get(item['label'], 0) + 1

    print(f'\nTotal lines: {len(filtered)} (from {len(all_results)} candidates)')
    print(f'Label distribution:')
    for label, count in sorted(labels.items(), key=lambda x: -x[1]):
        print(f'  {label}: {count}')


if __name__ == '__main__':
    main()
