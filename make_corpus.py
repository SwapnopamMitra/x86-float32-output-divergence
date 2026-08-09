
import struct, random, hashlib

def w(vals):
    return b"".join(struct.pack("<I", v) for v in vals)

random.seed(1234567891)

blocks = []

for i in [1, 2, 3, 0x12345, 0xFFFFF, 0x1FFFFF, 0x3FFFFF, 0x7FFFFF]:
    blocks.append(i)
    blocks.append(0x80000000 | i)

for payload in [1, 2, 0x123456, 0x555555, 0x7FFFFF]:
    blocks.append(0x7F800000 | payload)
    blocks.append(0xFF800000 | payload)

blocks += [0x00000000, 0x80000000]
blocks += [0x7F800000, 0xFF800000]
blocks += [0x00800000, 0x7F7FFFFF, 0x80800000, 0xFF7FFFFF]
blocks += [random.randint(0, 0xFFFFFFFF) for _ in range(2000)]

data = w(blocks)
with open("corpus.bin", "wb") as f:
    f.write(data)

print(f"wrote corpus.bin: {len(blocks)} float32 words, {len(data)} bytes")
print(f"SHA256: {hashlib.sha256(data).hexdigest()}")
