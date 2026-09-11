#!/usr/bin/env python3
"""Validate complete ordinary oracle families and total-vector shapes before publication."""
import argparse
import csv
import json
import re
from collections import Counter
from pathlib import Path

TOTAL = {'QLA': 'QLIVE', 'SMA': 'STABLE', 'UBA': 'BOUND'}
ORDINARY = {'CTLCardinality', 'CTLFireability', 'LTLCardinality', 'LTLFireability',
            'ReachabilityCardinality', 'ReachabilityFireability', 'UpperBounds',
            'ReachabilityDeadlock', 'Liveness', 'OneSafe', 'QuasiLiveness', 'StableMarking'}


def shape(path):
    lines = path.read_text().splitlines()
    if len(lines) < 2:
        raise ValueError(f'{path}: missing header or keyword')
    suffix = path.stem.rsplit('-', 1)[-1]
    if lines[1] != TOTAL[suffix]:
        raise ValueError(f'{path}: incorrect keyword {lines[1]!r}')
    body = ' '.join(lines[2:])
    tokens = body.split() if suffix == 'UBA' else list(''.join(body.split()))
    pattern = r'(?:\?|[0-9]+|\+?inf)' if suffix == 'UBA' else r'[TF?]'
    if any(not re.fullmatch(pattern, token) for token in tokens):
        raise ValueError(f'{path}: invalid verdict in vector')
    return [lines[0], lines[1], len(tokens)]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--record-totals', type=Path)
    parser.add_argument('directory', type=Path, nargs='?')
    parser.add_argument('raw', type=Path, nargs='?')
    parser.add_argument('shapes', type=Path, nargs='?')
    parser.add_argument('--models', nargs='+', help='Restrict a local stepwise reproduction to these models')
    args = parser.parse_args()
    if args.record_totals:
        shapes = {p.name: shape(p) for suffix in TOTAL for p in args.record_totals.glob(f'*-{suffix}.out')}
        if not shapes:
            raise ValueError('No total-examination skeletons were generated')
        print(json.dumps(shapes, sort_keys=True))
        return
    if not all((args.directory, args.raw, args.shapes)):
        parser.error('directory, raw CSV and recorded shapes are required')
    expected = set()
    with args.raw.open() as source:
        for row in csv.reader(source):
            if len(row) > 2 and row[2] in ORDINARY and (not args.models or row[1] in args.models):
                expected.add((row[1], row[2]))
    if not expected:
        raise ValueError('Raw CSV contains no ordinary examinations')
    counts, known = Counter(), Counter()
    for model, exam in sorted(expected):
        suffix = re.sub('[a-z]', '', exam)
        path = args.directory / f'{model}-{suffix}.out'
        lines = path.read_text().splitlines()
        if not lines or lines[0] != f'{model} {exam}':
            raise ValueError(f'{path}: wrong model/examination header')
        formulas = [line.split() for line in lines if line.startswith('FORMULA ')]
        if not formulas or any(len(parts) < 5 or parts[3] != 'TECHNIQUES' for parts in formulas):
            raise ValueError(f'{path}: missing or malformed formulas')
        counts[suffix] += 1
        known[suffix] += sum(parts[2] != '?' for parts in formulas)
    empty = [suffix for suffix in counts if not known[suffix]]
    if empty:
        raise ValueError(f'Entire ordinary examination families have no filled verdicts: {empty}')
    shapes = json.loads(args.shapes.read_text())
    for name, expected_shape in shapes.items():
        if shape(args.directory / name) != expected_shape:
            raise ValueError(f'{name}: overlay changed model, keyword or vector length')
    totals = Counter(name.rsplit('-', 1)[-1] for name in shapes)
    print(json.dumps({'ordinary_files': counts, 'known_verdicts': known, 'total_vectors': totals}, sort_keys=True))


if __name__ == '__main__':
    main()
