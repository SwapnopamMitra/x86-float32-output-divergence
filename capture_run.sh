#!/usr/bin/env bash
# capture_run.sh

set -euo pipefail

NODE_LABEL="$1"; shift
INPUT_FILE="$1"; shift

if [ "${1:-}" != "--" ]; then
  echo "expected -- before command" >&2
  exit 1
fi
shift
CMD=("$@")

STDOUT_FILE="output_${NODE_LABEL}.stdout"
STDERR_FILE="output_${NODE_LABEL}.stderr"
MANIFEST="manifest_${NODE_LABEL}.json"

# Environment fingerprint
KERNEL=$(uname -srmo 2>/dev/null || uname -a)
CPU_MODEL=$(grep -m1 "model name" /proc/cpuinfo 2>/dev/null | cut -d: -f2- | sed 's/^ *//' || echo "unknown")
CPU_FLAGS_HASH=$(grep -m1 "^flags" /proc/cpuinfo 2>/dev/null | sha256sum | cut -d' ' -f1 || echo "unknown")
GLIBC_VER=$(ldd --version 2>/dev/null | head -1 || echo "unknown")

# Binary identity
BIN_PATH=$(command -v "${CMD[0]}" || echo "")
if [ -n "$BIN_PATH" ] && [ -f "$BIN_PATH" ]; then
  BIN_HASH=$(sha256sum "$BIN_PATH" | cut -d' ' -f1)
else
  BIN_HASH="unresolved:${CMD[0]}"
fi

if [ -f "$INPUT_FILE" ]; then
  INPUT_HASH=$(sha256sum "$INPUT_FILE" | cut -d' ' -f1)
else
  INPUT_HASH="MISSING"
fi

ARTIFACT_FILE="float_output.bin"
if [ -f "$ARTIFACT_FILE" ]; then
  rm -f "$ARTIFACT_FILE"
fi
if [ -f "hash_output.txt" ]; then
  rm -f "hash_output.txt"
fi

# Run and time it
START=$(date +%s.%N)
"${CMD[@]}" > "$STDOUT_FILE" 2> "$STDERR_FILE" || true
END=$(date +%s.%N)
ELAPSED=$(echo "$END - $START" | bc 2>/dev/null || echo "unknown")

# Extract hash from stderr
OUTPUT_HASH=""
if [ -f "$STDERR_FILE" ]; then
  OUTPUT_HASH=$(grep "OUTPUT_HASH:" "$STDERR_FILE" | cut -d: -f2 | tr -d ' ' || echo "")
fi

if [ -z "$OUTPUT_HASH" ] && [ -f "$STDOUT_FILE" ]; then
  OUTPUT_HASH=$(grep "OUTPUT_HASH:" "$STDOUT_FILE" | cut -d: -f2 | tr -d ' ' || echo "")
fi

if [ -z "$OUTPUT_HASH" ] && [ -f "hash_output.txt" ]; then
  OUTPUT_HASH=$(grep HASH hash_output.txt | cut -d' ' -f2 || echo "")
fi

# If we still don't have it, compute from the artifact
if [ -z "$OUTPUT_HASH" ] && [ -f "$ARTIFACT_FILE" ]; then
  OUTPUT_HASH=$(sha256sum "$ARTIFACT_FILE" | cut -d' ' -f1)
fi

if [ -f "$ARTIFACT_FILE" ]; then
  ARTIFACT_COPY="artifact_${NODE_LABEL}_$(basename "$ARTIFACT_FILE")"
  cp "$ARTIFACT_FILE" "$ARTIFACT_COPY"
  RESULT_FILE="$ARTIFACT_COPY"
  if [ -n "$OUTPUT_HASH" ]; then
    RESULT_HASH="$OUTPUT_HASH"
  else
    RESULT_HASH=$(sha256sum "$ARTIFACT_COPY" | cut -d' ' -f1)
  fi
  RESULT_KIND="artifact_file"
else
  RESULT_FILE="$STDOUT_FILE"
  RESULT_HASH=$(sha256sum "$STDOUT_FILE" | cut -d' ' -f1)
  RESULT_KIND="stdout"
fi

STDOUT_HASH=$(sha256sum "$STDOUT_FILE" | cut -d' ' -f1)

cat > "$MANIFEST" <<EOF
{
  "node_label": "${NODE_LABEL}",
  "timestamp_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "kernel": "${KERNEL}",
  "cpu_model": "${CPU_MODEL}",
  "cpu_flags_hash": "${CPU_FLAGS_HASH}",
  "glibc_version": "$(echo "$GLIBC_VER" | head -1)",
  "command": "$(printf '%s ' "${CMD[@]}")",
  "binary_path": "${BIN_PATH}",
  "binary_sha256": "${BIN_HASH}",
  "input_file": "${INPUT_FILE}",
  "input_sha256": "${INPUT_HASH}",
  "elapsed_seconds": "${ELAPSED}",
  "result_kind": "${RESULT_KIND}",
  "result_file": "${RESULT_FILE}",
  "raw_output_sha256": "${RESULT_HASH}",
  "stdout_file": "${STDOUT_FILE}",
  "stdout_sha256": "${STDOUT_HASH}"
}
EOF

echo "wrote ${MANIFEST}"
cat "$MANIFEST"