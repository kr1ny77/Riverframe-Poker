#!/usr/bin/env python3
"""Independent exact-rational oracle. Uses only the Python standard library.
Regenerate: python3 Tools/check-advanced-course.py > Tests/Fixtures/course-v4-math-oracle.json
"""
from fractions import Fraction as F
from itertools import permutations
import json


def icm(stacks, payouts):
    active = [i for i, stack in enumerate(stacks) if stack]
    assert len(stacks) - len(active) <= 1
    result = [F(0) for _ in stacks]
    for order in permutations(active):
        remaining, probability = sum(stacks), F(1)
        for rank, seat in enumerate(order):
            probability *= F(stacks[seat], remaining)
            remaining -= stacks[seat]
            # Sum the full-order probability only after every place is known.
        for rank, seat in enumerate(order):
            result[seat] += probability * payouts[rank]
    for seat, stack in enumerate(stacks):
        if stack == 0:
            result[seat] = F(payouts[-1])
    assert sum(result) == sum(payouts)
    return result


inputs = [
    ('R0-fold', [48, 30, 22], [50, 30, 20]),
    ('R0-win', [48, 52, 0], [50, 30, 20]),
    ('R0-lose', [48, 10, 42], [50, 30, 20]),
    ('R0-tie', [48, 31, 21], [50, 30, 20]),
    ('R1-fold', [40, 41, 19], [50, 30, 0]),
    ('R1-win', [40, 20, 40], [50, 30, 0]),
    ('R1-lose', [40, 60, 0], [50, 30, 0]),
    ('T50-leaf', [150, 0, 30], [90, 60, 30]),
    ('six-player', [31, 23, 19, 13, 9, 5], [60, 40, 25, 15, 5, 0]),
    ('six-symmetric', [1] * 6, [6, 5, 4, 3, 2, 1]),
]
rows = [dict(id=name, stacks=stacks, payouts=payouts,
             expected=[float(x) for x in icm(stacks, payouts)],
             rational=[str(x) for x in icm(stacks, payouts)])
        for name, stacks, payouts in inputs]
print(json.dumps(rows, indent=2))
