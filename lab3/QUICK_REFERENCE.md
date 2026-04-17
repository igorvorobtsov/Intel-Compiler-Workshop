# Quick Reference: Intel Compiler Vectorization

## Environment Setup

```bash
# ICX (Intel oneAPI DPC++/C++ Compiler)
source setup_icx.sh
# OR: module switch stack stack/24.6.0 && module load intel/2025.3.0

# ICC (Intel Classic C++ Compiler - for comparison in Exercise 3)
source setup_icc.sh
# OR: module switch stack stack/23.1.0 && module load intel/2023.2.1
```

## Running Exercises

```bash
./run_exercises.sh <1-6|all>    # Run specific or all exercises
```

## Essential Vectorization Flags

### Optimization and Reports

| Flag | Purpose | When to Use |
|------|---------|-------------|
| `-O2` | Standard optimization with vectorization | Production builds |
| `-O3` | Aggressive optimization | After profiling |
| `-qopt-report=N` | Optimization report (N=1-5) | Always when analyzing vectorization |
| `-qopt-report-file=stdout` | Print report to console | Interactive analysis |
| `-qopt-report-phase=vec` | Show only vectorization info | Minimize output clutter |
| `-fargument-noalias` | Assume pointer arguments don't alias | Eliminate multiversioning overhead |

### Architecture Selection

**Single-version flags (smallest binary, target CPU only):**

| Flag | Purpose | Behavior |
|------|---------|----------|
| `-xHost` | Optimize for current CPU | Best for homogeneous clusters |
| `-mavx2` | Generic AVX2 (Intel + AMD) | Portable, no CPU check |
| `-xCORE-AVX2` | Intel-specific AVX2 | CPU check, exits on non-Intel |
| `-xAVX` | AVX (256-bit) | Baseline SIMD |
| `-xCORE-AVX512` | AVX-512 with YMM (256-bit) default | Modern Intel CPUs |

**Auto-dispatch flags (larger binary, multi-CPU support):**

| Flag | Purpose | Behavior |
|------|---------|----------|
| `-axCORE-AVX2` | Baseline (SSE2) + AVX2 | Runtime CPU detection |
| `-axCORE-AVX512` | Baseline + AVX-512 | Runtime CPU detection |
| `-axCORE-AVX2,CORE-AVX512` | Baseline + AVX2 + AVX-512 | Multiple targets |

### OpenMP SIMD Flags

| Flag | Purpose | When to Use |
|------|---------|-------------|
| `-qopenmp` | Enable OpenMP (required for SIMD pragmas) | When using `#pragma omp simd` |

### Vector Width Control

| Flag | Purpose | Compiler |
|------|---------|----------|
| `-qopt-zmm-usage=high` | Use 512-bit ZMM registers | ICC legacy (accepted by ICX) |
| `-mprefer-vector-width=512` | Use 512-bit registers | ICX/Clang-based |
| `-mprefer-vector-width=256` | Use 256-bit registers (default) | ICX/Clang-based |

## Common Flag Combinations

### Basic Vectorization Analysis
```bash
icx -O2 -xHost -qopt-report=3 -qopt-report-file=stdout program.c -c
```

### Clean Vectorization (No Multiversioning)
```bash
icx -O2 -xHost -fargument-noalias -qopt-report=3 -qopt-report-file=stdout program.c -c
```

### Vectorization Report Only (Minimize Output)
```bash
icx -O2 -xHost -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout program.c -c
```

### OpenMP SIMD Compilation
```bash
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout program.c -c
```

### AVX-512 with 512-bit Registers
```bash
icx -O2 -xCORE-AVX512 -mprefer-vector-width=512 -fargument-noalias program.c -o program
```

### Generate Assembly for Inspection
```bash
icx -O2 -xCORE-AVX512 -S program.c -o program.s
```

### Portable Multi-CPU Binary
```bash
icx -O2 -axCORE-AVX2,CORE-AVX512 program.c -o program
```

## Vectorization Report Messages

### Success Messages

| Message | Meaning |
|---------|---------|
| `LOOP WAS VECTORIZED` | Loop successfully converted to SIMD |
| `vector length N` | Processing N elements at once |
| `estimated potential speedup: Nx` | Expected performance improvement |
| `OpenMP SIMD LOOP WAS VECTORIZED` | Pragma-forced vectorization succeeded |
| `compress/expand` | Special idiom recognized (AVX-512) |

### Multiversioning Messages

| Message | Meaning |
|---------|---------|
| `LOOP WAS MULTIVERSIONED` | Multiple versions created (runtime check) |
| `vector version` | SIMD version of loop |
| `remainder loop` | Scalar cleanup for leftover iterations |

### Failure Messages

| Message | Meaning |
|---------|---------|
| `loop was not vectorized: vector dependence` | Loop-carried dependency prevents vectorization |
| `existence of vector dependence` | Data dependency detected |
| `assumed FLOW dependence` | Read-after-write dependency |
| `assumed OUTPUT dependence` | Write-after-write dependency |
| `not vectorizable: may not be beneficial` | Compiler decided vectorization wouldn't help |

## Compiler Comparison: ICC vs ICX

| Aspect | ICC (Classic) | ICX (LLVM-based) |
|--------|---------------|------------------|
| **Vectorization** | Aggressive | Conservative |
| **Multiversioning** | Frequent | Less frequent |
| **Pragmas needed** | Rarely | Often |
| **OpenMP SIMD** | Optional | Recommended |
| **Status** | Deprecated | Current |

## OpenMP SIMD Pragmas

### Basic Loop Vectorization
```c
#pragma omp simd
for (int i = 0; i < n; i++) {
    a[i] = b[i] + c[i];
}
```

### With Conditional Compilation
```c
#ifdef USE_OMP_SIMD
#pragma omp simd
#endif
for (int i = 0; i < n; i++) {
    // loop body
}
```

### Known Trip Count Optimization
```c
#ifdef KNOWN_TRIP_COUNT
#define MYDIM 3
#else
#define MYDIM nd
#endif

#pragma omp simd
for (int i = 0; i < n; i++) {
    for (int j = 0; j < MYDIM; j++) {  // Fixed trip count
        // inner loop body
    }
}
```

## Vector Register Sizes

| ISA | Register | Width | Floats | Doubles |
|-----|----------|-------|--------|---------|
| SSE | XMM | 128-bit | 4 | 2 |
| AVX | YMM | 256-bit | 8 | 4 |
| AVX-512 | ZMM | 512-bit | 16 | 8 |

**Note:** `-xCORE-AVX512` uses YMM (256-bit) by default. Use `-mprefer-vector-width=512` or `-qopt-zmm-usage=high` for ZMM.

## CPU Feature Detection

### Intel-Specific Function
```c
__intel_new_feature_proc_init()
```

**When it appears:**
- With `-xCORE-AVX2` (Intel CPU check)
- With `-axCORE-AVX2` (runtime dispatch)

**When it's absent:**
- With `-mavx2` (no CPU check, may crash on old CPUs)

### Checking Assembly for CPU Detection
```bash
icx -O2 -xCORE-AVX2 -S program.cpp -o program.s
grep "__intel_new_feature_proc_init" program.s
```

## Special Vectorization Idioms

### Compress Pattern (AVX-512 Only)
```c
int compress(double *a, double *b, int na) {
    int nb = 0;
    for (int ia = 0; ia < na; ia++) {
        if (a[ia] > 0.)
            b[nb++] = a[ia];  // Conditional write with increment
    }
    return nb;
}
```

**Vectorization:**
- ✅ AVX-512: Auto-vectorizes with `vcompresspd` instruction
- ❌ AVX2: Cannot vectorize (no compress instruction)

**Key instruction:** `vcompresspd` - stores selected elements contiguously based on mask

## Exercise Quick Commands

### Exercise 1: Loop Multiversioning
```bash
# Basic vectorization report
icpx -g -O2 -xHost -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c

# Eliminate multiversioning
icpx -g -O2 -xHost -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c

# Analyze vector length with AVX-512
icpx -g -O2 -xCORE-AVX512 -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c

# Fixed version with float constant
icpx -g -O2 -xCORE-AVX512 -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin_fixed.cpp -c
```

### Exercise 2: Architecture Flags
```bash
# Compile with different flags
icpx -O2 -mavx2 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_m
icpx -O2 -xCORE-AVX2 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_x
icpx -O2 -axCORE-AVX2 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_ax

# Compare binary sizes
ls -lh vec_sin_*

# Check for CPU detection in assembly
icpx -O2 -mavx2 -S vec_sin_main.cpp -o vec_sin_m.s
icpx -O2 -xCORE-AVX2 -S vec_sin_main.cpp -o vec_sin_x.s
icpx -O2 -axCORE-AVX2 -S vec_sin_main.cpp -o vec_sin_ax.s
grep "__intel_new_feature_proc_init" vec_sin_*.s
```

### Exercise 3: ICC vs ICX with OpenMP SIMD
```bash
# ICC (aggressive auto-vectorization)
source setup_icc.sh
icc -O2 -xHost -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout addit.c -c

# ICX (conservative, no vectorization)
source setup_icx.sh
icx -O2 -xHost -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout addit.c -c

# ICX with OpenMP SIMD (vectorized)
icx -O2 -xHost -qopenmp -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout addit_omp.c -c
```

### Exercise 4: Outer Loop Vectorization
```bash
# Version 1: No pragma (inner loop vectorized)
icx -O2 -xHost -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout dist.c -c

# Version 2: With pragma (outer loop vectorized)
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout dist.c -c

# Version 3: Pragma + known trip count (outer loop + inner unrolled)
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout dist.c -c

# Build and test
icx -O2 -xHost dist.c dist_main.c -o dist_v1
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD dist.c dist_main.c -o dist_v2
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_known_main.c -o dist_v3
```

### Exercise 5: Performance Benchmarking
```bash
# Build all versions
icx -O1 dist.c dist_bench.c -o bench_v1_o1                                                         # Baseline
icx -O2 -xAVX dist.c dist_bench.c -o bench_v1_avx                                                  # Inner loop
icx -O2 -xAVX -qopenmp -DUSE_OMP_SIMD dist.c dist_bench.c -o bench_v2_avx                          # Outer loop
icx -O2 -xAVX -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_bench.c -o bench_v3_avx      # Outer + unrolled
icx -O2 -xCORE-AVX2 -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_bench.c -o bench_v3_avx2     # + FMA
icx -O2 -xCORE-AVX512 -qopt-zmm-usage=high -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_bench.c -o bench_v3_avx512  # + 512-bit

# Run benchmarks
./bench_v1_o1 && ./bench_v1_avx && ./bench_v2_avx && ./bench_v3_avx && ./bench_v3_avx2 && ./bench_v3_avx512
```

### Exercise 6: Compress Pattern
```bash
# AVX2 (not vectorized)
icx -xCORE-AVX2 -O2 -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout -fargument-noalias compress.c -c

# AVX-512 (vectorized with vcompresspd)
icx -xCORE-AVX512 -O2 -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout -fargument-noalias compress.c -c

# Generate assembly and check for vcompress instruction
icx -xCORE-AVX2 -O2 -S -fargument-noalias compress.c -o compress_avx2.s
icx -xCORE-AVX512 -O2 -S -fargument-noalias compress.c -o compress_avx512.s
grep "vcompress" compress_avx2.s      # Should be empty
grep "vcompress" compress_avx512.s    # Should find vcompresspd

# Build and benchmark
icx -xCORE-AVX2 -O2 -fargument-noalias compress.c compress_main.c -o compress_avx2
icx -xCORE-AVX512 -O2 -fargument-noalias compress.c compress_main.c -o compress_avx512
```

## Common Pitfalls

### 1. Double Constant with Float Arrays
```c
// BAD: Vector length 4 (double precision forced)
sth[i] = sin(theta[i] + 3.1415927);

// GOOD: Vector length 8 (single precision)
sth[i] = sin(theta[i] + 3.1415927f);  // Note the 'f'
```

### 2. Using -xHost Without Understanding
- `-xHost` optimizes for **current CPU only**
- Binary may not run on older machines
- Use `-ax` flags for portable binaries

### 3. Forgetting -qopenmp with Pragmas
```bash
# WRONG: Pragma ignored, no vectorization
icx -O2 -xHost -DUSE_OMP_SIMD program.c -o program

# CORRECT: Pragma active, vectorization enabled
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD program.c -o program
```

### 4. Using -fverbose-asm Unnecessarily
```bash
# DON'T: -fverbose-asm not needed
icx -O2 -xHost -S -fverbose-asm program.c -o program.s

# DO: Just -S is sufficient
icx -O2 -xHost -S program.c -o program.s
```

### 5. Expecting 512-bit with -xCORE-AVX512 by Default
- Default: Uses 256-bit YMM registers
- For 512-bit ZMM: Add `-mprefer-vector-width=512` or `-qopt-zmm-usage=high`

## Debugging Vectorization Issues

### Loop Not Vectorizing?

1. **Check optimization report:**
   ```bash
   icx -O2 -xHost -qopt-report=5 -qopt-report-file=stdout program.c -c
   ```

2. **Look for specific remark:**
   - `#15344`: Vector dependence prevents vectorization
   - `#15346`: Assumed dependence (aliasing issue)
   - `#15523`: Not vectorizable (complex control flow)

3. **Try -fargument-noalias:**
   ```bash
   icx -O2 -xHost -fargument-noalias -qopt-report=3 -qopt-report-file=stdout program.c -c
   ```

4. **Consider OpenMP SIMD pragma:**
   ```c
   #pragma omp simd
   for (int i = 0; i < n; i++) {
       // loop body
   }
   ```

### Suboptimal Vector Length?

1. **Check data types:** Ensure constants match array types (e.g., `3.14f` for floats)
2. **Check register width:** Use `-mprefer-vector-width=512` for ZMM registers
3. **Check ISA target:** `-xCORE-AVX512` vs `-xCORE-AVX2` vs `-xAVX`

## Performance Tips

1. **Always use `-fargument-noalias`** when pointers don't alias (eliminates multiversioning overhead)
2. **Match constant types** to data types (`f` suffix for floats)
3. **Use `#pragma omp simd`** for loops that should vectorize but don't
4. **Mark small fixed loops** with compile-time constants for outer loop vectorization
5. **Profile before optimizing** - vectorization doesn't always improve performance
6. **Test with `-qopt-report-phase=vec`** to minimize report clutter

## Online Resources

- **Intel Compiler Documentation:** https://www.intel.com/content/www/us/en/docs/cpp-compiler
- **Compiler Explorer (Godbolt):** https://godbolt.org
- **Exercise 1 on Godbolt:** https://godbolt.org/z/6nc7Eqcda
- **Exercise 3 on Godbolt:** https://godbolt.org/z/x8TxG56Gr
- **Exercise 6 on Godbolt:** https://godbolt.org/z/63oTsshKd
- **Intel Intrinsics Guide:** https://www.intel.com/content/www/us/en/docs/intrinsics-guide

## File Overview

- `vec_sin.cpp` - Basic sin() loop (Exercise 1)
- `vec_sin_fixed.cpp` - Fixed version with float constant (Exercise 1)
- `vec_sin_main.cpp` - Main program for Exercise 2
- `addit.c` - Loop dependency example (Exercise 3)
- `addit_omp.c` - With OpenMP SIMD pragma (Exercise 3)
- `addit_main.c` - Main program for addit (Exercise 3)
- `dist.c` - Unified source for outer loop vectorization (Exercise 4)
- `dist_main.c` - Main for variable trip count (Exercise 4)
- `dist_known_main.c` - Main for known trip count (Exercise 4)
- `dist_bench.c` - Benchmark main (Exercise 5)
- `compress.c` - Simple compress pattern (Exercise 6)
- `compress_main.c` - Main for compress benchmark (Exercise 6)
- `setup_icx.sh` - ICX environment setup
- `setup_icc.sh` - ICC environment setup
- `run_exercises.sh` - Automated exercise runner
- `README.md` - Complete lab documentation
- `QUICK_REFERENCE.md` - This file

## Compiler Selection Guide

| Scenario | Compiler | Flags |
|----------|----------|-------|
| **New code** | ICX | `-O2 -xHost -qopenmp -fargument-noalias` |
| **Legacy code** | ICC then ICX | Test with ICC, migrate to ICX |
| **Portable binary** | ICX | `-O2 -axCORE-AVX2,CORE-AVX512` |
| **Maximum performance** | ICX | `-O3 -xHost -qopenmp -mprefer-vector-width=512` |
| **Debugging vectorization** | ICX | `-O2 -xHost -qopt-report=5 -qopt-report-file=stdout` |

## Summary of Key Concepts

1. **Vectorization** = Processing multiple data elements simultaneously (SIMD)
2. **Multiversioning** = Compiler creates multiple code versions with runtime checks
3. **Loop-carried dependencies** can prevent vectorization
4. **ICC is aggressive**, ICX is conservative (needs pragmas)
5. **OpenMP SIMD pragmas** force vectorization when safe
6. **Outer loop vectorization** processes multiple iterations simultaneously
7. **Known trip counts** enable better optimization (inner unrolling + outer vectorization)
8. **Special idioms** like compress patterns auto-vectorize with AVX-512
9. **Type conversions** can halve vectorization efficiency
10. **Optimization reports** reveal hidden performance issues
