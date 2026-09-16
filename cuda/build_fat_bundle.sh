#!/bin/bash


set -e

echo "=== Building fat binaries ==="
make clean
make all

echo ""
echo "=== Verifying fat binary contents ==="
echo "Binaries should contain sm_75 SASS, sm_86 SASS, and compute_86 PTX:"
for b in bin/*; do
    [ -f "$b" ] || continue
    echo ""
    echo "--- $b ---"
    cuobjdump --list-elf "$b" 2>/dev/null || echo "  (cuobjdump not available, skipping)"
done

echo ""
echo "=== Bundling for transfer ==="
BUNDLE="cuda_bundle_$(date +%Y%m%d_%H%M%S).tar.gz"
tar czf "$BUNDLE" \
    bin/ \
    test.bin \
    divergence_demo_cuda.sh \
    compare_cuda_runs.py \
    run_cuda_divergence_test.sh \
    kernels/ \
    Makefile

echo ""
echo "Bundle: $BUNDLE"
echo "Size:   $(du -h "$BUNDLE" | cut -f1)"
echo "SHA256: $(sha256sum "$BUNDLE" | cut -d' ' -f1)"
echo ""
echo "Transfer this file to the target machine and extract there."
echo "Then run ./run_cuda_divergence_test.sh in transfer mode."