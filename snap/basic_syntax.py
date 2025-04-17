# imports
from __future__ import annotations
import dataclasses as dc

# int literals
i1 = 0
i2 = 10
b = 100
i_ = 1_000_000
a = b

# float literals
floats = [
    0.0,
    .0,
    0.,
    1e002,
    1e-002,
    1E002,
    1E-002,
    1.e10,
    1.0e10,
]

# other literals
bool_t = True
bool_f = False
none = None
imaginary = 0j


# dict literals
c = {}
c[a] = b

# string literals
s1 = "abc"
s1 = 'abc'
s2 = u"abc"
s2 = u'abc'
fs = f"abc{a}"
fs = f'abc{a}'
bs = b"abc"
bs = b'abc'
b = 1
f = 1
u = 1

# boolean
print(not a)
print(a and b)
print(a or b)
print(a == b)
print(a != b)
print(a < b)
print(a <= b)
print(a > b)
print(a >= b)

# maths
print(+a)
print(-a)
print(a + b)
print(a - b)
print(a * b)
print(a / b)
print(a // b)
print(a % b)
print(a ** b)
# TODO: matmul

# in-place maths
i1 += a
i1 -= a
i1 *= a
i1 /= a
i1 //= a
i1 %= a
i1 **= a
# TODO: matmul

# bitwise
print(~a)
print(a & b)
print(a | b)
print(a ^ b)
print(a << b)
print(a >> b)

# in-place bitwise
i2 &= a
i2 |= a
i2 ^= a
i2 <<= a
i2 >>= a

# identity
print(a is b)
print(a is not b)

# collections
print(a in c)
print(a not in c)
print(c[a])
del c[a]


# functions
def add(a: int, b: int) -> int:
    return a + b

# classes and decorators
@dc.dataclass(frozen=True)
class MyClass:
    a: int
    b: bool
