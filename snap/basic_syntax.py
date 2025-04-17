# imports
from __future__ import annotations
from contextlib import contextmanager
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
msb = b"""I am a fat bytes literal."""
msf = f"""I am a fat f-string {b}."""
ms1 = """I am a fat string with one line."""
ms2 = """I am a fat string with multiple lines.

This is an escaped sequence: \"To be or not to be.\"
"""

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

# conditionals
if a == 1:
    print("a == 1")
elif a == 2:
    print("a == 2")
else:
    print("a > 2")

# exceptions
try:
    raise Exception("oh no")
except Exception as err:
    print("saved:", err)
finally:
    pass

# assertions
assert 1 == 1

# loops
for i in range(5):
    print(i)
i = 0
while True:
    i += 1
    if i & 1:
        continue
    print(i)
    if i == 10:
        break


# functions
def add(a: int, b: int) -> int:
    return a + b

# lambdas
lamb_add = lambda a, b: a + b

# classes and decorators
@dc.dataclass(frozen=True)
class MyClass:
    a: int
    b: bool

# generators
def my_gen():
    print("hey")
    yield
    print("ho")
    yield
g = iter(my_gen())
next(g)
next(g)

# context managers
@contextmanager
def my_ctx():
    yield 1
with my_ctx() as ctx:
    print("ctx", ctx)

# asyncio
async def foo() -> int:
    global i
    return i
async def bar() -> int:
    a = 2
    def baz() -> int:
        nonlocal a
        return a

    return await foo() + baz()
