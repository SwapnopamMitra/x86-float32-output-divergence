#!/bin/bash
# run_divergence_test.sh

set -e

echo "=== Running Divergence Test ==="
echo ""

# Make scripts executable
chmod +x capture_run.sh divergence_demo.sh 2>/dev/null || true

# Generate and capture
./divergence_demo.sh
./capture_run.sh "$(hostname | tr -d '.-')" test.bin -- ./divergence_demo.sh

echo ""
echo "Manifest generated: $(ls -t manifest_*.json | head -1)"
echo ""
echo "Run on another machine and compare with: python3 compare_runs.py"
