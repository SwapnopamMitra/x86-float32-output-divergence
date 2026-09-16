# Makefile — fat binary for cross-architecture testing
# Contains SASS for sm_75 (Turing/T4) and sm_86 (Ampere/RTX 3050)
# plus PTX fallback. Same binary file runs on both.

NVCC       := nvcc
NVCC_FLAGS := -O2 -diag-suppress 1650 \
              -gencode arch=compute_75,code=sm_75 \
              -gencode arch=compute_86,code=sm_86 \
              -gencode arch=compute_86,code=compute_86

.PHONY: all clean dirs

all: dirs \
     bin/fma_default \
     bin/fma_no_fma \
     bin/ftz_on \
     bin/ftz_off \
     bin/reduction_tree \
     bin/reduction_atomic

dirs:
	@mkdir -p bin output

bin/fma_default: kernels/fma_vs_no_fma.cu
	$(NVCC) $(NVCC_FLAGS) -DUSE_FMA -o $@ $<

bin/fma_no_fma: kernels/fma_vs_no_fma.cu
	$(NVCC) $(NVCC_FLAGS) --fmad=false -o $@ $<

bin/ftz_on: kernels/ftz_subnormal.cu
	$(NVCC) $(NVCC_FLAGS) -DUSE_FAST -o $@ $<

bin/ftz_off: kernels/ftz_subnormal.cu
	$(NVCC) $(NVCC_FLAGS) -o $@ $<

bin/reduction_tree: kernels/reduction_order.cu
	$(NVCC) $(NVCC_FLAGS) -DTREE_REDUCTION -o $@ $<

bin/reduction_atomic: kernels/reduction_order.cu
	$(NVCC) $(NVCC_FLAGS) -DATOMIC_REDUCTION -o $@ $<

clean:
	rm -rf bin output