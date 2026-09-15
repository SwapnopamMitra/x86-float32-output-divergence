# divergence-verifier

Independent harness for reproducing output divergence in float32 computation
across commodity hardware, on both CPU and GPU execution paths.

This repository contains the harness and the captured manifests. It contains
nothing about how divergence is resolved or whether resolution is possible.

---

## What this is

A capture-and-compare harness plus a set of manifests recording real
divergence findings on real hardware.

The manifests record two independent findings:

**CPU finding — hardware-dependent divergence.**
Five distinct CPU configurations, same binary hash, same input hash,
**five different output hashes**.

**GPU finding — path-dependent divergence.**
Two GPU architectures (Tesla T4 sm_75, RTX 3050 sm_86), six different
kernels. Same kernel across GPUs produces identical output. Different
kernels on the same GPU produce different output.

Same program. Same input. Different execution → different output.
The manifests are the record. The scripts reproduce the conditions.

---

## What this is not

This repository does not contain, reference, or depend upon any
canonicalization method, any external tool, or any resolution logic.
If canonical hashes or tool-specific outputs appear in other published
material, that is where they belong — not here.

The GPU harness uses only standard CUDA intrinsics and compiler flags.
It does not depend on any particular SDK version, driver, or architecture
beyond what the Makefile declares.

---

## Repository contents

```
divergence-verifier/
├── README.md
├── capture_run.sh                  — fingerprints binary + input + output, writes manifest
├── compare_runs.py                 — collects CPU manifests, classifies the result
├── make_corpus.py                  — generates the float32 test corpus
├── divergence_demo_guaranteed.sh   — CPU divergence trigger (math library path)
├── run_divergence_test.sh          — one-command CPU runner
├── reference_canonicalizer.py      — independent reference implementation (bit-level)
├── exhaustive_check.c              — exhaustive check over all 2^32 float32 patterns
│
├── manifests/                      — CPU manifests
│   ├── manifest_Prime.json
│   ├── manifest_c2e68d2ae4f6.json
│   ├── manifest_6e258a114c61.json
│   ├── manifest_project40c8f81744b8444da370e811d81e6c86.json
│   └── manifest_puddi.json
│
└── cuda/                           — GPU divergence harness
    ├── Makefile                    — fat binary build (sm_75 + sm_86)
    ├── kernels/
    │   ├── fma_vs_no_fma.cu
    │   ├── ftz_subnormal.cu
    │   └── reduction_order.cu
    ├── divergence_demo_cuda.sh
    ├── compare_cuda_runs.py
    ├── run_cuda_divergence_test.sh
    ├── build_fat_bundle.sh         — bundle for cross-machine transfer
    └── manifests/
        ├── manifest_gpu_fma_on_rtx3050.json
        ├── manifest_gpu_fma_on_t4.json
        ├── manifest_gpu_fma_off_rtx3050.json
        ├── manifest_gpu_fma_off_t4.json
        ├── manifest_gpu_ftz_on_rtx3050.json
        ├── manifest_gpu_ftz_on_t4.json
        ├── manifest_gpu_ftz_off_rtx3050.json
        ├── manifest_gpu_ftz_off_t4.json
        ├── manifest_gpu_red_tree_rtx3050.json
        ├── manifest_gpu_red_tree_t4.json
        ├── manifest_gpu_red_atomic_rtx3050.json
        └── manifest_gpu_red_atomic_t4.json
```

---

## CPU finding

Five nodes. Five different CPUs. Same binary, same input.

| Node | CPU | glibc | Output hash |
|------|-----|-------|-------------|
| Prime | Intel i5-12450HX | 2.39 | `b266807160a9ee69...` |
| c2e68d2ae4f6 | AMD EPYC 7B13 | 2.35 | `44b36c0f3a01cc59...` |
| 6e258a114c61 | Intel Xeon @ 2.00GHz | — | `7989a6b20cc566cd...` |
| project40c8... | AMD EPYC 7B13 | — | `a1b49047410b2620...` |
| puddi | Intel i5-1255U | — | `689c2e49eb09ec8b...` |

**Binary hash: identical across all five nodes.**
**Input hash: identical across all five nodes.**
**Output hash: five distinct values.**

---

## GPU finding

Two GPUs. Six kernels. Same binary per kernel, same input.

| Kernel | nvcc flags | Tesla T4 (sm_75, CUDA 12.8) | RTX 3050 (sm_86, CUDA 13.0) |
|--------|------------|-----------------------------|-----------------------------|
| `fma_on` | `-O2 fat -DUSE_FMA` | `9abc1b84...` | `9abc1b84...` |
| `fma_off` | `-O2 fat --fmad=false` | `c0d12da3...` | `c0d12da3...` |
| `ftz_on` | `-O2 fat -DUSE_FAST` | `8a792baa...` | `8a792baa...` |
| `ftz_off` | `-O2 fat` | `0accc3bb...` | `0accc3bb...` |
| `red_tree` | `fat -DTREE_REDUCTION` | `a2c70538...` | `a2c70538...` |
| `red_atomic` | `fat -DATOMIC_REDUCTION` | `a2c70538...` | `a2c70538...` |

**Input hash: identical across all 12 manifests (`e851cab68f6e2350...`).**
**Same kernel across two GPU architectures: identical output.**
**Different kernels on the same GPU: different output.**

The divergence source on GPU is the execution path (FMA vs non-FMA,
fast intrinsic vs accurate library, reduction order), not the hardware.

---

## Reproducing the CPU test

### 1. Generate the corpus

```bash
python make_corpus.py
```

The corpus seed is fixed. If your `corpus.bin` hash differs from the
published one, your Python or `struct` behavior is the issue — not
the hardware.

### 2. Capture a run on each node

On every node you want to test, run identically:

```bash
# if the binary writes its result to a file:
./capture_run.sh <node_label> corpus.bin --artifact <result_file> -- <command>

# if the binary writes its result to stdout:
./capture_run.sh <node_label> corpus.bin -- <command>
```

This produces `manifest_<node_label>.json`. Collect all manifests into
one directory.

### 3. Compare

```bash
python compare_runs.py
```

| Result | Meaning |
|--------|---------|
| `INVALID COMPARISON` | Binary or input hash differs — test is void |
| `NO DIVERGENCE DETECTED` | Same binary, same input, same output |
| `UNEXPLAINED DIVERGENCE — GENUINE FINDING` | Same binary, same input, different output |

---

## Reproducing the GPU test

### 1. Build fat binaries

The Makefile produces a fat binary containing SASS for sm_75
(Turing/T4) and sm_86 (Ampere/RTX 3050), plus PTX fallback. The
same binary file runs on both architectures.

```bash
cd cuda
make all
```

### 2. Transfer to each GPU machine

```bash
./build_fat_bundle.sh
# produces cuda_bundle_<timestamp>.tar.gz
```

Extract on the target machine and run:

```bash
./run_cuda_divergence_test.sh
```

The script detects pre-built binaries and skips compilation, then runs
all six kernels and writes manifests to `cuda/manifests/`.

### 3. Compare across machines

Copy all `manifest_gpu_*.json` files into one directory and run:

```bash
python3 compare_cuda_runs.py
```

The script groups manifests by kernel, verifies binary hash identity
across machines, and reports whether output hashes diverge.

---

## Sample output (CPU)

```
$ python3 compare_runs.py

Loaded 5 node manifests:

  [6e258a114c61]
    kernel      : Linux 6.6.122+ x86_64 GNU/Linux
    cpu_model   : Intel(R) Xeon(R) CPU @ 2.00GHz
    output_hash : 7989a6b20cc566cd...

  [Prime]
    kernel      : Linux 6.6.87.2-microsoft-standard-WSL2 x86_64 GNU/Linux
    cpu_model   : 12th Gen Intel(R) Core(TM) i5-12450HX
    output_hash : b266807160a9ee69...

  [c2e68d2ae4f6]
    kernel      : Linux 6.6.122+ x86_64 GNU/Linux
    cpu_model   : AMD EPYC 7B13
    output_hash : 44b36c0f3a01cc59...

  [project40c8f81744b8444da370e811d81e6c86]
    kernel      : Linux 6.17.0-1022-gcp x86_64 GNU/Linux
    cpu_model   : AMD EPYC 7B13
    output_hash : a1b49047410b2620...

  [puddi]
    kernel      : Linux 4.4.0-26100-Microsoft x86_64 GNU/Linux
    cpu_model   : 12th Gen Intel(R) Core(TM) i7-1255U
    output_hash : 689c2e49eb09ec8b...

Binary identical: CONFIRMED
Input identical:  CONFIRMED

RESULT: UNEXPLAINED DIVERGENCE — GENUINE FINDING
    7989a6b20cc566cd...  <- ['6e258a114c61']
    b266807160a9ee69...  <- ['Prime']
    44b36c0f3a01cc59...  <- ['c2e68d2ae4f6']
    a1b49047410b2620...  <- ['project40c8f81744b8444da370e811d81e6c86']
    689c2e49eb09ec8b...  <- ['puddi']
```

## Sample output (GPU)

```
$ python3 compare_cuda_runs.py

Loaded 12 GPU manifests:

  [Prime_gpu_fma_off]
    gpu        : NVIDIA GeForce RTX 3050 6GB Laptop GPU
    cuda       : 13.0
    nvcc_flags : -O2 fat --fmad=false
    input_hash : e851cab68f6e2350...
    output_hash: c0d12da384ac30a6...

  [d794f130e459_gpu_fma_off]
    gpu        : Tesla T4
    cuda       : 12.8
    nvcc_flags : -O2 fat --fmad=false
    input_hash : e851cab68f6e2350...
    output_hash: c0d12da384ac30a6...

  [Prime_gpu_fma_on]
    gpu        : NVIDIA GeForce RTX 3050 6GB Laptop GPU
    cuda       : 13.0
    nvcc_flags : -O2 fat -DUSE_FMA
    input_hash : e851cab68f6e2350...
    output_hash: 9abc1b84d3e4c0b3...

  [d794f130e459_gpu_fma_on]
    gpu        : Tesla T4
    cuda       : 12.8
    nvcc_flags : -O2 fat -DUSE_FMA
    input_hash : e851cab68f6e2350...
    output_hash: 9abc1b84d3e4c0b3...

  ... (12 manifests total)

Input identical: CONFIRMED

RESULT: CUDA DIVERGENCE — GENUINE FINDING
Same input, different compile flags -> different output.

    -O2 fat --fmad=false       output=c0d12da384ac30a6...
    -O2 fat -DUSE_FMA          output=9abc1b84d3e4c0b3...
    -O2 fat                    output=0accc3bb0f4add72...
    -O2 fat -DUSE_FAST         output=8a792baa0bd1e12f...
    fat -DATOMIC_REDUCTION     output=a2c70538651a7e92...
    fat -DTREE_REDUCTION       output=a2c70538651a7e92...
```

---

## Design constraints

`capture_run.sh` hashes the actual executable on disk (not its name),
hashes the input file before the run, clears any stale artifact before
executing, and writes a timestamped JSON manifest. It does not modify or
canonicalize output.

`compare_runs.py` enforces that all nodes ran the same capture mode
before comparing. Mixed-mode comparisons (stdout on one node, artifact
on another) are rejected as invalid.

`make_corpus.py` covers the standard float32 edge-case space:
signaling and quiet NaN variants, signed zero, subnormals, infinities,
boundary normals, and a random sample at a fixed seed.

`cuda/Makefile` builds fat binaries for cross-architecture testing.
The same binary file runs on both Turing and Ampere GPUs, so the
`binary_sha256` comparison is meaningful.

`cuda/compare_cuda_runs.py` groups manifests by kernel identity and
verifies binary hash identity before comparing outputs.

---

## Adding nodes

**CPU:** Run `capture_run.sh` on the new node. Drop the manifest into
`manifests/`. Re-run `compare_runs.py`.

**GPU:** Run `run_cuda_divergence_test.sh` on the new GPU machine. Copy
the resulting `cuda/manifests/manifest_gpu_*.json` into the same
directory as the other GPU manifests. Re-run `compare_cuda_runs.py`.

Hardware diversity is the point. Different CPU families (x86 vs ARM),
different kernels, different libc versions. The `cpu_flags_hash` field
in each manifest records the full CPU flags word for post-hoc analysis.

---

## License

MIT. The harness only. The test corpus (`corpus.bin`) is
deterministically generated by `make_corpus.py` and carries no separate
rights.
