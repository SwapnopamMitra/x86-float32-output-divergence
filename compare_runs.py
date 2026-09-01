#!/usr/bin/env python3
import json, sys, glob
from collections import defaultdict

def load_manifests(pattern="manifest_*.json"):
    manifests = []
    for path in sorted(glob.glob(pattern)):
        with open(path) as f:
            manifests.append(json.load(f))
    return manifests

def main():
    manifests = load_manifests()
    if len(manifests) < 2:
        print(f"Found {len(manifests)} manifest(s). Need at least 2 nodes.")
        sys.exit(1)

    # Validate hash length - this catches the "83bec18b" bug
    for m in manifests:
        h = m.get('raw_output_sha256', '')
        if len(h) != 64:
            print(f"ERROR: {m['node_label']} has invalid hash length: {len(h)} chars")
            print(f"  Hash: {h}")
            print("  This usually means the script captured a short hash instead of SHA256.")
            sys.exit(2)

    print(f"Loaded {len(manifests)} node manifests:\n")
    for m in manifests:
        print(f"  [{m['node_label']}]")
        print(f"    kernel      : {m['kernel']}")
        print(f"    cpu_model   : {m['cpu_model']}")
        print(f"    output_hash : {m['raw_output_sha256'][:16]}...")
        print()

    binary_hashes = {m['binary_sha256'] for m in manifests}
    input_hashes = {m['input_sha256'] for m in manifests}
    
    if len(binary_hashes) > 1:
        print("RESULT: INVALID COMPARISON - Binary differs")
        sys.exit(2)
    
    if len(input_hashes) > 1:
        print("RESULT: INVALID COMPARISON - Input differs")
        sys.exit(2)

    print("Binary identical: CONFIRMED")
    print("Input identical: CONFIRMED\n")

    output_hashes = {m['raw_output_sha256'] for m in manifests}
    
    if len(output_hashes) == 1:
        print("RESULT: NO DIVERGENCE DETECTED")
        print("All nodes produced identical output.")
        sys.exit(0)
    else:
        print("RESULT: UNEXPLAINED DIVERGENCE - GENUINE FINDING")
        groups = defaultdict(list)
        for m in manifests:
            groups[m['raw_output_sha256']].append(m['node_label'])
        for h, nodes in groups.items():
            print(f"    {h[:16]}...  <- {nodes}")
        sys.exit(3)

if __name__ == "__main__":
    main()
