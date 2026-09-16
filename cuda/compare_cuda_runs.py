import json, sys, glob
from collections import defaultdict

def load_manifests(pattern="manifests/manifest_*.json"):
    manifests = []
    for path in sorted(glob.glob(pattern)):
        with open(path) as f:
            manifests.append(json.load(f))
    return manifests

def main():
    manifests = load_manifests()
    if len(manifests) < 2:
        print(f"Found {len(manifests)} manifest(s). Need at least 2.")
        sys.exit(1)

    print(f"Loaded {len(manifests)} GPU manifests:\n")
    for m in manifests:
        print(f"  [{m['node_label']}]")
        print(f"    gpu          : {m.get('gpu_model','unknown')}")
        print(f"    cuda         : {m.get('cuda_version','unknown')}")
        print(f"    nvcc_flags   : {m.get('nvcc_flags','unknown')}")
        print(f"    input_hash   : {m['input_sha256'][:16]}...")
        print(f"    output_hash  : {m['raw_output_sha256'][:16]}...")
        print()

    input_hashes = {m['input_sha256'] for m in manifests}
    if len(input_hashes) > 1:
        print("RESULT: INVALID COMPARISON — input differs")
        sys.exit(2)

    print("Input identical: CONFIRMED\n")

    groups = defaultdict(list)
    for m in manifests:
        key = m.get('nvcc_flags', m.get('binary_sha256', 'unknown'))
        groups[key].append(m)

    group_hashes = {}
    for key, ms in groups.items():
        hashes = {m['raw_output_sha256'] for m in ms}
        if len(hashes) > 1:
            print(f"WARNING: same flags, different output within group {key[:40]}")
        group_hashes[key] = hashes.pop()

    if len(set(group_hashes.values())) == 1:
        print("RESULT: NO DIVERGENCE — all flag variants produced same output")
        sys.exit(0)
    else:
        print("RESULT: CUDA DIVERGENCE — GENUINE FINDING")
        print("Same input, different compile flags -> different output.\n")
        for key, h in group_hashes.items():
            print(f"    {key:48s}  output={h[:16]}...")
        sys.exit(3)

if __name__ == "__main__":
    main()