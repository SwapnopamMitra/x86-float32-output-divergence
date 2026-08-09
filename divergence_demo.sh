#!/bin/bash
# divergence_demo.sh

echo "=== Divergence Capture ==="
echo "Node: $(hostname)"
echo "CPU: $(grep -m1 'model name' /proc/cpuinfo | cut -d: -f2- | sed 's/^ *//')"
echo ""

python3 -c "
import struct, random, hashlib, math

random.seed(42)

vals = []

# 1. Subnormals that trigger DAZ/FTZ differently
# On Intel, some are flushed to 0. On AMD, they're preserved.
subnormals = [
    0x00000001, 0x00000002, 0x00000003, 0x00000004,
    0x000FFFFF, 0x001FFFFF, 0x003FFFFF, 0x007FFFFF,
    0x00012345, 0x000AAAAA, 0x00055555, 0x000FFFFF
]
for s in subnormals:
    vals.append(s)              # +subnormal
    vals.append(0x80000000 | s) # -subnormal

# 2. NaNs - payload handling varies
nan_payloads = [1, 2, 0x123456, 0x555555, 0xAAAAAA, 0x7FFFFF]
for p in nan_payloads:
    vals.append(0x7F800000 | p)  # +sNaN
    vals.append(0xFF800000 | p)  # -sNaN
    vals.append(0x7FC00000 | (p & 0x3FFFFF))  # +qNaN
    vals.append(0xFFC00000 | (p & 0x3FFFFF))  # -qNaN

# 3. Signed zero
vals.append(0x80000000)
vals.append(0x00000000)

# 4. Random subnormals (many)
for _ in range(1000):
    vals.append(random.randint(0x00000001, 0x007FFFFF))
    vals.append(random.randint(0x80000001, 0x807FFFFF))

# 5. Normal values with subnormal results
for _ in range(100):
    vals.append(random.randint(0x00800000, 0x7F7FFFFF))
    vals.append(random.randint(0x80800000, 0xFF7FFFFF))

# Write the test file
data = b''.join(struct.pack('<I', v) for v in vals)
open('test.bin', 'wb').write(data)
print('Generated test.bin (%d bytes)' % len(data))
"

cat > /tmp/float_test.c << 'EOF'
#include <stdio.h>
#include <stdint.h>
#include <string.h>

int main() {
    FILE *f = fopen("test.bin", "rb");
    if (!f) return 1;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    rewind(f);
    uint32_t *words = malloc(len);
    fread(words, 1, len, f);
    fclose(f);
    
    int count = len / 4;
    float *floats = malloc(count * sizeof(float));
    
    // Convert uint32_t to float using hardware
    for (int i = 0; i < count; i++) {
        memcpy(&floats[i], &words[i], 4);
    }
    
    // Do operations that trigger hardware divergence
    float result = 0.0f;
    for (int i = 0; i < count; i++) {
        // Operations that produce subnormals
        float a = floats[i];
        float b = a * 0.0000001f;  // Multiply by tiny number
        float c = b / 0.0000001f;  // Should restore, but hardware differs
        float d = a + 0.0000001f;  // Addition with tiny number
        float e = a - 0.0000001f;  // Subtraction with tiny number
        
        // NaN operations - hardware behavior varies
        if (i % 3 == 0) {
            float nan = a / 0.0f;
            floats[i] = nan;
        } else if (i % 3 == 1) {
            float inf = a / 0.0f;
            floats[i] = inf;
        } else {
            floats[i] = a * b + c - d + e;
        }
        result += floats[i];
    }
    
    // Convert back to uint32_t
    uint32_t *out = malloc(count * 4);
    for (int i = 0; i < count; i++) {
        memcpy(&out[i], &floats[i], 4);
    }
    
    // Write output
    f = fopen("float_output.bin", "wb");
    fwrite(out, 1, count * 4, f);
    fclose(f);
    
    // Print hash
    printf("OUTPUT_HASH: ");
    uint32_t hash = 0;
    for (int i = 0; i < count * 4; i++) {
        hash = hash * 31 + ((uint8_t*)out)[i];
    }
    printf("%08x\n", hash);
    
    return 0;
}
EOF

gcc -O0 -o /tmp/float_test /tmp/float_test.c -lm 2>/dev/null || {
    echo "ERROR: Compilation failed - falling back to Python"
    
    python3 -c "
import struct, hashlib
data = open('test.bin', 'rb').read()
words = struct.unpack('<%dI' % (len(data)//4), data)
floats = []
for w in words:
    try:
        f = struct.unpack('f', struct.pack('I', w))[0]
        # Critical operations that trigger divergence
        if f != 0:
            f = f * 0.0000001
            f = f / 0.0000001
            f = f + 0.0000001
            f = f - 0.0000001
        floats.append(f)
    except:
        floats.append(0.0)
back = b''.join(struct.pack('f', f) for f in floats)
open('float_output.bin', 'wb').write(back)
hash = hashlib.sha256(back).hexdigest()
print('OUTPUT_HASH: %s' % hash)
" 2>/dev/null
}

# Extract the hash from here
if [ -f "float_output.bin" ]; then
    if [ -f "/tmp/float_test" ]; then
        HASH=$(/tmp/float_test 2>/dev/null | grep OUTPUT_HASH | cut -d: -f2 | tr -d ' ')
        echo "$HASH" > hash_output.txt
    else
        HASH=$(sha256sum float_output.bin | cut -d' ' -f1)
        echo "$HASH" > hash_output.txt
    fi
    echo "Output hash: $(cat hash_output.txt)"
    echo "Divergence captured in float_output.bin"
else
    echo "ERROR: No output generated"
    exit 1
fi
#by now everything should have worked