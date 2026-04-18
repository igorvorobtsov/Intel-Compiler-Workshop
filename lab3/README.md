# Lab 3: Vectorization with Intel Compilers

## Overview

This lab demonstrates how to use Intel Compiler vectorization features to optimize code performance using SIMD (Single Instruction, Multiple Data) instructions. You'll learn how to enable, analyze, and understand vectorization through optimization reports.

**Compiler Used:** Intel C++ Compiler (icx) 2025.0 or newer

**Key Concepts:**
- Auto-vectorization and optimization levels
- Vectorization reports and loop multiversioning
- Vector ISA selection (SSE, AVX, AVX-512)
- Understanding compiler optimization decisions

## Prerequisites

- Completed Lab 1 (ICC vs ICX) or familiar with Intel compilers
- Basic understanding of loops and array operations

## Setup

### Load Intel Compiler Environment

Use the setup script:

```bash
source setup_icx.sh
```

Or manually load:

```bash
module switch stack stack/24.6.0
module load intel/2025.3.0
```

### Verify Installation

```bash
icx --version
```

Expected output:
```
Intel(R) oneAPI DPC++/C++ Compiler 2025.0.0 ...
```

## What is Vectorization?

**Vectorization** is the process of converting scalar operations (processing one data element at a time) into vector operations (processing multiple data elements simultaneously using SIMD instructions).

**Example:**
```c
// Scalar code (one operation per cycle)
for (int i = 0; i < 512; i++) {
    sth[i] = sin(theta[i]);
}

// Vectorized code (4-16 operations per cycle)
// Compiler automatically converts to SIMD instructions like:
// - SSE: 4 floats at once (128-bit)
// - AVX: 8 floats at once (256-bit)
// - AVX-512: 16 floats at once (512-bit)
```

**Performance benefits:**
- 2-16x speedup depending on vector width
- Better CPU resource utilization
- Essential for HPC and scientific computing

## Exercise 1: Understanding Loop Multiversioning and Vectorization

### Goal
Learn how to generate and interpret vectorization reports, with focus on understanding loop multiversioning.

### Code: vec_sin.cpp

```cpp
#include <math.h>

void foo (float * theta, float * sth)  {
  int i;
  for (i = 0; i < 512; i++)
       sth[i] = sin(theta[i]+3.1415927);
}
```

**What this code does:**
- Takes an array of 512 angles (`theta`)
- Adds π (pi) to each angle
- Computes the sine of each result
- Stores the results in the `sth` array

### Tasks

**1a. Create the Source File**

The file `vec_sin.cpp` is already provided in this lab directory.

**1b. Compile with Optimization Report**

```bash
icpx -g -O2 -xHost -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c
```

**Flag meanings:**
- **`-g`**: Include debug information
- **`-O2`**: Enable standard optimizations (includes vectorization)
- **`-xHost`**: Optimize for the current CPU architecture
- **`-qopt-report=3`**: Generate optimization report (level 3 = detailed)
- **`-qopt-report-file=stdout`**: Print report to console instead of file
- **`-c`**: Compile only (don't link)

**Note:** We use `icpx` (Intel C++ Compiler) for C++ files.

**1c. Analyze the Optimization Report**

Look for key sections in the output:

**Section 1: Loop Identification**
```
LOOP BEGIN at vec_sin.cpp(5,3)
```
This identifies the loop at line 5, column 3.

**Section 2: Vectorization Success**
```
   remark #15300: LOOP WAS VECTORIZED
```
The loop was successfully vectorized!

**Section 3: Vector Length**
```
   remark #15305: vectorization support: vector length 4
```
The compiler is processing 4 floats at once (SSE/AVX depending on CPU).

**Section 4: Loop Multiversioning**
```
LOOP BEGIN at vec_sin.cpp (5, 3)
<Multiversioned v1>
    remark #25228: Loop multiversioned for Data Dependence
...
LOOP END

LOOP BEGIN at vec_sin.cpp (5, 3)
<Multiversioned v2>
    remark #15615: Loop was not vectorized: not vectorizable due to data dependence, fall-back loop for multiversioning
LOOP END
```

**What is Loop Multiversioning?**

The compiler generates **multiple versions** of the same loop:
1. **Scalar version**: Original code, runs one element at a time
2. **Vector version**: SIMD optimized, runs multiple elements at once

At runtime, the program **checks conditions** (e.g., alignment, pointer aliasing) and **selects the best version** to execute.

**Why multiversioning here?**
The compiler is uncertain whether the pointer arguments `theta` and `sth` might **alias** (overlap in memory). For example, what if someone calls:
```c
foo(arr, arr+1);  // theta[i] and sth[i-1] would overlap!
```

**Why multiversioning in general?**
- **Safety**: If vector version requirements aren't met, fall back to scalar
- **Performance**: Choose the fastest version based on runtime conditions
- **Compiler uncertainty**: When compiler can't prove safety at compile time

Now that we've identified multiversioning due to pointer aliasing, we'll show in task 1f how to eliminate it.

**Section 5: Alternative Scalar Version**
```
<Multiversioned v2>
    remark #15615: Loop was not vectorized: not vectorizable due to data dependence, fall-back loop for multiversioning
```
This is the alternative version for edge case.

**1d. Understanding the Performance Estimate**

From the report:
- **Scalar cost: 48.000000** - Estimated cycles for scalar execution
- **Vector cost: 12.062500** - Estimated cycles for vector execution  
- **Estimated speedup: 3.968750** (approximately **~4x**) - Expected performance improvement

This means the vectorized version should be ~4x faster than the scalar version!

**1e. Try It Online**

You can experiment with this code online using Compiler Explorer:

**🔗 [Try on Godbolt: https://godbolt.org/z/6nc7Eqcda](https://godbolt.org/z/6nc7Eqcda)**

On Godbolt you can:
- Modify the code and see how it affects vectorization
- Compare different optimization flags
- View the generated assembly code
- Try different compiler versions

**Summary so far:** We've seen that the loop was vectorized BUT also multiversioned. The multiversioning adds runtime overhead (checks and branches). In the next task, we'll eliminate this multiversioning.

**1f. Eliminating Multiversioning with -fargument-noalias**

In task 1c, we identified that the compiler **multiversioned** the loop due to uncertainty about pointer aliasing between `theta` and `sth`.

**Question:** Can we eliminate this multiversioning?  
**Answer:** Yes! If we know the pointers don't overlap, we can tell the compiler.

Now let's eliminate this multiversioning by telling the compiler the pointers don't alias. Compile with the `-fargument-noalias` flag:

```bash
icpx -g -O2 -xHost -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c
```

**What changed?**

Look at the optimization report carefully:
- ✅ **`LOOP WAS VECTORIZED`** - Still present
- ❌ **`LOOP WAS MULTIVERSIONED`** - **GONE!**

The loop is still vectorized, but now there's only **one version** instead of multiple versions.

**Why did this happen?**

The **`-fargument-noalias`** flag tells the compiler to assume that pointer arguments to functions **do not alias** (do not overlap in memory).

**What is pointer aliasing?**
```c
void foo(float *theta, float *sth) {
  // Without -fargument-noalias:
  // Compiler thinks: "What if theta and sth point to overlapping memory?"
  // Example: foo(arr, arr+1) - writing to sth[i] could affect theta[i+1]!
  // Solution: Create multiple versions and check at runtime
  
  // With -fargument-noalias:
  // Compiler assumes: "theta and sth definitely point to separate memory"
  // No need for runtime checks - just use the vector version!
}
```

**Comparison:**

| Without -fargument-noalias | With -fargument-noalias |
|---------------------------|-------------------------|
| Compiler uncertain about aliasing | Compiler assumes no aliasing |
| Creates scalar + vector versions | Creates only vector version |
| Runtime check selects best version | Directly executes vector code |
| Safer (handles all cases) | Faster (no runtime overhead) |
| Slightly larger code size | Smaller code size |

**Question to consider:**
- When is it **safe** to use `-fargument-noalias`?
  - **Answer**: When you can **guarantee** that pointer arguments never overlap in memory. If they might overlap, using this flag could produce **incorrect results**!

**Result:** We've eliminated multiversioning! From now on, we'll continue using `-fargument-noalias` in all subsequent compilations to maintain this cleaner, more efficient vectorization.

**1g. Using Optimization Reports to Improve Performance**

Let's dig deeper into the vectorization report to find performance issues. We'll use a specific architecture target and **keep `-fargument-noalias`** to avoid multiversioning overhead:

```bash
icpx -g -O2 -xCORE-AVX512 -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c
```

**Look at the vector length in the report:**
```
   remark #15305: vectorization support: vector length 4
```

**Wait... something's wrong here!**

We're using `-xCORE-AVX512` which enables **256-bit AVX registers (YMM)** by default. For `float` (32-bit) data:
- **Expected vector length**: 256 bits / 32 bits = **8 floats at once**
- **Actual vector length**: Only **4 floats at once**

**Note about AVX-512 and register usage:**
- `-xCORE-AVX512` enables AVX-512 instruction set support
- **By default, Intel compilers use 256-bit YMM registers**, not 512-bit ZMM registers
- To use 512-bit ZMM registers explicitly:
  - `-mprefer-vector-width=512` (clang-based option, works with ICX)
  - `-qopt-zmm-usage=high` (legacy ICC option, still accepted by ICX)
- Why YMM by default? Compatibility and avoiding frequency throttling on some CPUs

**Why only 4 instead of 8?**

Look at the code more carefully:
```c
sth[i] = sin(theta[i]+3.1415927);
                      ^^^^^^^^^^
```

The constant `3.1415927` is a **double** (64-bit) by default in C!

**What happens internally:**
1. Load `theta[i]` as `float` (32-bit)
2. Convert `float` → `double` (64-bit) to match the constant
3. Add: `double + double` = `double`
4. Call `sin(double)` - double-precision sine
5. Convert result back: `double` → `float` 
6. Store in `sth[i]`

**The bottleneck:** Operations happen in double precision (64-bit), so only **4 doubles fit in 256-bit registers**, not 8!

**The fix:** Add `f` suffix to make it a `float` constant:

The file `vec_sin_fixed.cpp` is already provided in this lab directory with the correct float constant:
```cpp
#include <math.h>

void foo (float * theta, float * sth)  {
  int i;
  for (i = 0; i < 512; i++)
       sth[i] = sin(theta[i]+3.1415927f);  // Note the 'f' suffix!
}
```

Now compile the fixed version (keeping `-fargument-noalias`):
```bash
icpx -g -O2 -xCORE-AVX512 -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin_fixed.cpp -c
```

**Compare the results:**

| Metric | Original (3.1415927) | Fixed (3.1415927f) |
|--------|---------------------|-------------------|
| Constant type | `double` (64-bit) | `float` (32-bit) |
| Vector length | **4** (double precision) | **8** (single precision) |
| Scalar cost | 48.000000 cycles | 31.000000 cycles |
| Vector cost | 12.062500 cycles | 4.203125 cycles |
| Estimated speedup | **~4x** | **~7.3x** |
| Multiversioned | No (using `-fargument-noalias`) | No (using `-fargument-noalias`) |

**Performance improvement: Nearly 2x better speedup estimate (4x → 7.3x) by using proper float types!**

Note: Both versions use `-fargument-noalias` to avoid multiversioning overhead, allowing us to focus on the type conversion issue.

**Key lesson:** Optimization reports help you identify hidden performance problems like implicit type conversions. A simple one-character fix (`f`) doubled the vector width from 4 to 8 elements and improved the speedup estimate from ~4x to ~7.3x!

**1h. Bonus: Comparing ICC (Classic Compiler) vs ICX**

Let's see how ICC (Intel C++ Compiler Classic) handles the same code. First, switch to the ICC environment:

```bash
source setup_icc.sh
```

Now compile the original `vec_sin.cpp` with ICC:

```bash
icc -g -O2 -xHost -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c
```

**Note:** We use `icc` (not `icpx`) for ICC. It handles both C and C++ files.

**ICC Optimization Report - Key Observations:**

Look for these differences in the ICC output:

```
   remark #15476: scalar cost: 111
   remark #15477: vector cost: 20.370
   remark #15478: estimated potential speedup: 5.440
   remark #15482: vectorized math library calls: 1
   remark #15487: type converts: 2
```

**ICC vs ICX Comparison:**

| Aspect | ICX | ICC (Classic) |
|--------|-----|---------------|
| Vectorized? | ✅ Yes | ✅ Yes |
| Multiversioned? | ✅ Yes | ✅ Yes |
| Vector length | 4 (double precision) | 4 (double precision) |
| Scalar cost | 48.000000 | 111 |
| Vector cost | 12.062500 | 20.370 |
| Speedup estimate | ~4x | ~5.4x |
| Strategy | Runtime checks for aliasing | Runtime checks for aliasing |

**Why different cost estimates?**
- ICC and ICX use **different cost models** for estimating performance
- ICC's classic cost model often shows higher speedup estimates
- **Actual runtime performance** is what matters, not the estimates
- Both compilers face the same issue: vector length 4 due to double constant

Now compile the **fixed version** with ICC:

```bash
icc -g -O2 -xCORE-AVX512 -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin_fixed.cpp -c
```

**ICC Fixed Version Results:**

```
LOOP BEGIN at vec_sin_fixed.cpp(5,3)
   remark #15300: LOOP WAS VECTORIZED
   remark #26013: Compiler has chosen to target XMM/YMM vector. Try using -qopt-zmm-usage=high to override
   remark #15476: scalar cost: 109 
   remark #15477: vector cost: 10.250 
   remark #15478: estimated potential speedup: 10.610
```

**Key Observations:**

1. **Vector length: 8** - Float constant enables full YMM (256-bit) register usage
2. **No multiversioning** - Using `-fargument-noalias` eliminates it
3. **Speedup estimate: ~10.6x** - Much higher than ICX (~7.3x) due to different cost model
4. **Remark #26013** - ICC uses YMM (256-bit) by default even with `-xCORE-AVX512`
   - To use 512-bit ZMM registers: add `-qopt-zmm-usage=high`

**Summary: ICC vs ICX**

**Similarities:**
- Both vectorize and multiversion for pointer aliasing safety
- Both benefit from proper type usage (adding 'f' suffix)
- Both support `-fargument-noalias` to eliminate multiversioning
- Both achieve **2x throughput increase** (vector length 4 → 8)

**Differences:**
- **Cost models differ**: ICC shows higher speedup estimates (5.4x, 10.6x) vs ICX (~4x, ~7.3x)
- **Different scalar/vector costs**: ICC scalar cost is 109-111 vs ICX 31-48
- **Improvement ratios similar**: Both show ~2x improvement with proper types (ICC: 5.4x→10.6x, ICX: 4x→7.3x)
- **Estimates ≠ Reality**: Actual performance depends on CPU, memory bandwidth, etc.

**Key Takeaway:**
The type conversion issue (double vs float) affects **both compilers** equally. Always use matching types for optimal vectorization! Don't rely solely on speedup estimates—benchmark actual performance.

**Switch back to ICX for remaining exercises:**

```bash
source setup_icx.sh
```

### Understanding the Output

**Key remarks to look for:**

| Remark ID | Meaning |
|-----------|---------|
| `#15300` | Loop was vectorized |
| `#15301` | Loop was multiversioned |
| `#15304` | Loop was not vectorized (explains why) |
| `#15305` | Vector length (how many elements processed together) |
| `#15344` | Vector dependence found (may prevent vectorization) |
| `#15475-#15478` | Cost summary and speedup estimate |

**Common reasons for NO vectorization:**
- Loop-carried dependencies
- Non-unit stride memory access
- Complex control flow (if/else inside loop)
- Function calls to non-vectorizable functions
- Low trip count (not worth vectorizing)

### Key Takeaways

- **`-O2`** or higher enables auto-vectorization
- **`-xHost`** generates code optimized for your CPU
- **`-qopt-report=3`** shows vectorization decisions
- **Loop multiversioning** creates multiple versions for safety and performance
- **`-fargument-noalias`** eliminates multiversioning by assuming no pointer aliasing
- **Implicit type conversions** can significantly reduce vectorization efficiency
- Optimization reports help identify performance bottlenecks like type mismatches
- **Using `-xCORE-AVX512`** with proper float types: 8 elements at once (2x better than 4)
- A simple one-character fix can double vector width (4 → 8 elements) and improve speedup from ~4x to ~7.3x
- **ICC vs ICX**: Both compilers vectorize similarly, but use different cost models for speedup estimates
- **Cost estimates vs reality**: Don't rely solely on compiler estimates—benchmark actual performance
- You can experiment online at **godbolt.org**

### Questions to Consider

1. Why does the compiler multiversion this loop instead of just vectorizing it?
   - **Answer**: Because of potential pointer aliasing between `theta` and `sth`

2. What happens if the arrays are not aligned in memory?
   - **Answer**: Runtime check selects appropriate version (aligned vs unaligned loads)

3. Why is sin() vectorizable but some functions are not?
   - **Answer**: Intel provides vectorized math library (SVML - Short Vector Math Library)

4. Why does `-fargument-noalias` eliminate multiversioning?
   - **Answer**: It tells the compiler to assume pointer arguments don't overlap, removing the need for runtime aliasing checks

5. Why is the vector length only 4 instead of 8 with `-xCORE-AVX512`?
   - **Answer**: The constant `3.1415927` is a double (64-bit), forcing double-precision operations. Only 4 doubles fit in 256-bit registers instead of 8 floats.

6. How can we fix the type conversion issue?
   - **Answer**: Add 'f' suffix to make it a float constant: `3.1415927f`

7. Why do ICC and ICX show different speedup estimates for the same code?
   - **Answer**: They use different internal cost models for estimating scalar and vector execution time. ICC often shows higher estimates, but actual runtime performance depends on the hardware, not the estimate.

8. Should I use ICC or ICX for vectorization?
   - **Answer**: Use ICX (the modern LLVM-based compiler). ICC is deprecated and will be removed. Both produce similar vectorized code, but ICX is actively maintained and receives new optimizations.

## Exercise 2: Architecture-Specific Optimization Flags (-m, -x, -ax)

### Goal
Understand the differences between architecture targeting options and their impact on binary size and portability.

### Code Files

**vec_sin_fixed.cpp** (from Exercise 1 - the vectorized function):
```cpp
#include <math.h>

void foo (float * theta, float * sth)  {
  int i;
  for (i = 0; i < 512; i++)
       sth[i] = sin(theta[i]+3.1415927f);
}
```

**vec_sin_main.cpp** (main program):
```cpp
#include <cstdio>
#include <cstdlib>

// Declaration only - definition is in vec_sin_fixed.cpp
void foo (float * theta, float * sth);

int main() {
  float *theta = (float*)std::malloc(512 * sizeof(float));
  float *sth = (float*)std::malloc(512 * sizeof(float));

  // Initialize input array
  for (int i = 0; i < 512; i++) {
    theta[i] = i * 0.01f;
  }

  // Call the vectorized function
  foo(theta, sth);

  // Print a few results
  std::printf("sth[0] = %f\n", sth[0]);
  std::printf("sth[100] = %f\n", sth[100]);
  std::printf("sth[511] = %f\n", sth[511]);

  std::free(theta);
  std::free(sth);
  return 0;
}
```

**Why separate files?**
- `vec_sin_fixed.cpp` contains the compute-intensive function we want to optimize
- `vec_sin_main.cpp` contains the driver/test code
- This separation shows how architecture flags affect the compiled code, not the driver

### Understanding Architecture Flags

Intel compilers provide three main ways to target specific CPU architectures:

| Flag | Name | Purpose | Optimizations | CPU Check | Crash on Old CPU? |
|------|------|---------|---------------|-----------|-------------------|
| **`-m`** | GCC-compatible | Generic SIMD | Both Intel & non-Intel | No | ✅ Yes (Illegal Instruction) |
| **`-x`** | Intel-specific | Intel-optimized | Intel processor-specific | Yes | ❌ No (won't start) |
| **`-ax`** | Auto-dispatch | Multi-version | Intel-optimized versions | Yes | ❌ No (selects baseline) |

### Tasks

**2a. Compile with -mavx2 (GCC-compatible, generic optimization)**

```bash
icpx -O2 -mavx2 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_m
```

**Flag meaning:**
- **`-mavx2`**: Generate code for AVX2 instruction set (Haswell and newer)
- GCC-compatible flag (lowercase `-m`)
- Produces one version of the code
- **No CPU check**: Code runs immediately, crashes with "Illegal Instruction" on older CPUs
- **Generic optimization**: Optimized for both Intel and non-Intel processors (e.g., AMD)
- Uses SIMD features in a portable way
- Applied to both source files during compilation

**2b. Compile with -xCORE-AVX2 (Intel-only, with CPU check)**

```bash
icpx -O2 -xCORE-AVX2 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_x
```

**Flag meaning:**
- **`-xCORE-AVX2`**: Intel's native flag for AVX2
- Produces one version of the code
- **Intel processor-specific optimizations**: May use Intel-specific instruction timings, scheduling, and microarchitecture features
- **Adds processor check to main()**: Verifies it's an **Intel processor** with required features
- **Intel-only**: Will NOT run on AMD or other non-Intel CPUs (exits with error message)
- **Graceful exit**: Won't start if not Intel or if AVX2 not supported (no crash)

**2c. Compile with -axCORE-AVX2 (Auto-dispatch)**

```bash
icpx -O2 -axCORE-AVX2 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_ax
```

**Flag meaning:**
- **`-axCORE-AVX2`**: Auto-dispatch with AVX2 optimization
- Produces **multiple versions** of the code
- Includes baseline SSE2 version for compatibility
- Includes optimized AVX2 version for newer CPUs
- Runtime CPU detection selects the best version

**2d. Compile with multiple auto-dispatch targets**

```bash
icpx -O2 -axCORE-AVX2,CORE-AVX512 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_ax_multi
```

**Flag meaning:**
- Creates versions for: SSE2 (baseline), AVX2, and AVX-512
- Largest binary size
- Best compatibility + best performance on each CPU

**2e. Compare Binary Sizes**

```bash
ls -lh vec_sin_m vec_sin_x vec_sin_ax vec_sin_ax_multi
```

Expected results (approximate, make sure you use ICX 2025.3):

| Binary | Size | Versions Included | CPU Check? |
|--------|------|------------------|------------|
| `vec_sin_m` | ~47 KB | AVX2 only | No |
| `vec_sin_x` | ~56 KB | AVX2 only | Yes (in main) |
| `vec_sin_ax` | ~70 KB | SSE2 + AVX2 | Yes (CPUID) |
| `vec_sin_ax_multi` | ~70 KB | SSE2 + AVX2 + AVX-512 | Yes (CPUID) |

**Note:** 
- `-x` is ~20% larger than `-m` due to CPU check code and Intel-specific optimizations
- `-ax` is ~50% larger than `-x`, includes baseline + optimized versions
- Multiple auto-dispatch targets (ax_multi) have similar size to single target `-ax`

**2f. Generate Assembly and Check for CPU Detection**

Generate assembly with `-S` option to examine CPU check mechanisms:

```bash
# -mavx2: No CPU check
icpx -O2 -mavx2 -S vec_sin_main.cpp -o vec_sin_m.s

# -x: Adds CPU check to main
icpx -O2 -xCORE-AVX2 -S vec_sin_main.cpp -o vec_sin_x.s

# -ax: Uses CPUID for dispatch
icpx -O2 -axCORE-AVX2 -S vec_sin_main.cpp -o vec_sin_ax.s
```

**What is `__intel_new_feature_proc_init`?**

This is Intel's CPU feature detection function that:
- Checks which instruction sets the current CPU supports
- With `-x`: Verifies CPU has required features, exits if not
- With `-ax`: Detects available features to select best code version
- Not present with `-mavx2`: No check, code assumes AVX2 is available

**Check for CPU detection code:**

```bash
# With -mavx2: No feature initialization call
grep "__intel_new_feature_proc_init" vec_sin_m.s
# Output: (empty - no CPU checks)

# With -x: Feature initialization call added 
grep "__intel_new_feature_proc_init" vec_sin_x.s
# Output: callq __intel_new_feature_proc_init@PLT

# With -ax: Feature initialization call added for runtime dispatch
grep "__intel_new_feature_proc_init" vec_sin_ax.s
# Output: callq __intel_new_feature_proc_init@PLT
```

**Key Differences:**

| Flag | CPU Check Function | What Happens on Old CPU |
|------|-------------------|-------------------------|
| `-mavx2` | **None** (no `__intel_new_feature_proc_init`) | **Crashes** with "Illegal Instruction" |
| `-x` | **Yes** (`__intel_new_feature_proc_init` in main) | **Exits gracefully** with message |
| `-ax` | **Yes** (`__intel_new_feature_proc_init` + CPUID) | **Runs baseline version** (SSE2) |

**2g. Test Runtime Behavior**

```bash
# Try running each binary
./vec_sin_m    # May crash on old CPU (Illegal Instruction)
./vec_sin_x    # Will exit gracefully on old CPU
./vec_sin_ax   # Always runs (selects best available version)
```

### Key Differences Summary

| Aspect | -mavx2 | -xCORE-AVX2 | -axCORE-AVX2 |
|--------|--------|-------------|--------------|
| **Code versions** | One | One | Multiple (baseline + optimized) |
| **Binary size** | Smallest | Smallest | Slightly larger |
| **Optimizations** | Generic (Intel + AMD) | Intel-specific | Intel-specific |
| **CPU check** | None | Yes | Yes |
| **`__intel_new_feature_proc_init`** | ❌ No | ✅ Yes | ✅ Yes |
| **Runtime overhead** | None | Startup check | First call check (minimal) |
| **Portability** | Target CPU only | Target CPU only | Runs on older CPUs too |
| **Non-Intel CPUs** | Optimized for all | Won't run (Intel check) | Runs baseline version |
| **Old CPU behavior** | **Crash** | **Graceful exit** | **Runs baseline** |
| **Performance** | Good on all | Best on Intel | Best on Intel (each CPU) |
| **Use case** | Multi-vendor HPC | Intel HPC cluster | Distributed software |
| **Risk** | Illegal instruction crash | None | None |

### When to Use Each Option

**Use `-mavx2`:**
- ✅ Building for mixed vendor environments (Intel + AMD)
- ✅ Want portable optimization across all processors
- ✅ Maximum compatibility with non-Intel processors
- ✅ Minimal binary size
- ❌ Will crash on incompatible CPUs
- ❌ May not fully exploit Intel-specific features

**Use `-xCORE-AVX2`:**
- ✅ Building for Intel-only environments
- ✅ Want Intel processor-specific optimizations
- ✅ Graceful exit instead of crash on old CPUs
- ✅ Good for Intel HPC clusters with CPU verification
- ❌ Won't run on AMD or other non-Intel CPUs (Intel check)
- ❌ Won't run on older Intel CPUs without AVX2

**Use `-ax`:**
- ✅ Distributing software to users with different CPUs
- ✅ Need compatibility + performance
- ✅ Don't know target CPU in advance
- ❌ Larger binaries

**Use multiple `-ax` targets:**
- ✅ Supporting wide range of CPUs (servers + workstations)
- ✅ Want optimal performance on each


### Questions to Consider

1. Why is the `-ax` binary larger?
   - **Answer**: Contains multiple versions of the code (SSE2 baseline + AVX2 optimized)

2. What happens if you run `-march=core-avx2` binary on an old CPU without AVX2?
   - **Answer**: Illegal instruction error - program crashes

3. Is there a performance cost to using `-ax`?
   - **Answer**: Minimal - only CPU detection on first call, then direct calls

4. Can you combine `-x` and `-ax`?
   - **Answer**: `-x` sets baseline, `-ax` adds optimized versions on top

## Exercise 3: OpenMP SIMD Pragmas and Loop Dependencies

### Goal
Learn how to use OpenMP SIMD pragmas to force vectorization when the compiler cannot prove safety, and understand the differences between ICC and ICX compilers.

### Code: addit.c

```c
void addit(double* a, double* b, int m,
           int n, int x)
{
  for (int i = m; i < m+n; i++) {
        a[i] = b[i] + a[i-x];
  }
}
```

**What this code does:**
- Reads from array `a` at position `i-x` (offset by `x`)
- Adds corresponding element from array `b`
- Stores result back in array `a` at position `i`

**The vectorization challenge:**
- Loop has a **loop-carried dependency**: `a[i]` depends on `a[i-x]`
- Compiler must determine if iterations can overlap safely
- If `x > 0`: Forward dependency (iteration `i` needs result from `i+x`) → **Cannot vectorize**
- If `x < 0`: Backward dependency (iteration `i` needs result from `i+x`, where `i+x < i`) → **Can vectorize**

### The Problem: Compiler Uncertainty

The compiler **cannot know at compile time** whether `x` is positive or negative, so it must be conservative.

**Compiler behavior:**
- **ICC (Classic)**: Creates multiversioned code with runtime checks
- **ICX (LLVM-based)**: Refuses to vectorize (too conservative without explicit guidance)

### Tasks

**3a. Create the Source Files**

The files are provided:
- `addit.c` - Original code without pragmas
- `addit_omp.c` - Code with `#pragma omp simd`
- `addit_main.c` - Main program that calls `addit()`

**3b. Compile with ICC (Classic Compiler)**

First, set up the ICC environment:

```bash
source setup_icc.sh
```

Now compile with ICC and check the optimization report:

```bash
icc -O2 -xHost -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout addit.c -c
```

**Note:** We use `-qopt-report-phase=vec` to show only vectorization-related messages, minimizing output.

**What to look for in the report:**

```
LOOP BEGIN at addit.c(4,3)
   remark #15300: LOOP WAS VECTORIZED
   remark #15301: LOOP WAS MULTIVERSIONED
   remark #15450: unmasked unaligned unit stride loads: 2
   remark #15451: unmasked unaligned unit stride stores: 1
   remark #25015: Estimate of max trip count of loop=256
```

**ICC's approach:**
- ✅ **Vectorizes the loop**
- ✅ **Creates multiple versions** (multiversioning)
- ✅ **Runtime check** to verify `x < 0` before using vector version
- If check fails, falls back to scalar version

**3c. Compile with ICX (LLVM-based Compiler)**

Switch to ICX environment:

```bash
source setup_icx.sh
```

Now compile with ICX:

```bash
icx -O2 -xHost -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout addit.c -c
```

**What to look for in the report:**

```
LOOP BEGIN at addit.c(4,3)
   remark #15344: loop was not vectorized: vector dependence prevents vectorization
   remark #15346: vector dependence: assumed FLOW dependence between a[i] (5:9) and a[i-x] (5:18)
```

**ICX's approach:**
- ❌ **Does NOT vectorize the loop**
- Assumes potential forward dependency
- Too conservative without explicit programmer guidance

**3d. Using OpenMP SIMD Pragma to Force Vectorization**

The programmer knows that `x < 0` in their use case, so vectorization is safe. We can tell the compiler to trust us using `#pragma omp simd`:

Compile `addit_omp.c` with ICX:

```bash
icx -O2 -xHost -qopenmp -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout addit_omp.c -c
```

**Flag meanings:**
- **`-qopenmp`**: Enable OpenMP support (required for `#pragma omp simd`)
- **`-qopt-report-phase=vec`**: Show only vectorization-related messages (minimizes output)

**What changed in the report:**

```
LOOP BEGIN at addit_omp.c(6,3)
   remark #15301: SIMD LOOP WAS VECTORIZED
   remark #15305: vectorization support: vector length 4
```

**Result:**
- ✅ **Loop is now vectorized!**
- No multiversioning (pragma asserts safety)
- Direct vectorization without runtime checks

**3e. Compare the Three Approaches**

Let's create a comparison table by compiling all versions:

```bash
# ICC without pragma (multiversioned)
source setup_icc.sh
icc -O2 -xHost addit.c addit_main.c -o addit_icc

# ICX without pragma (scalar only)
source setup_icx.sh
icx -O2 -xHost addit.c addit_main.c -o addit_icx_scalar

# ICX with pragma (vectorized)
icx -O2 -xHost -qopenmp addit_omp.c addit_main.c -o addit_icx_simd
```

**Comparison:**

| Version | Compiler | Vectorized? | Multiversioned? | Runtime Check? |
|---------|----------|-------------|-----------------|----------------|
| addit.c + ICC | icc | ✅ Yes | ✅ Yes | ✅ Yes |
| addit.c + ICX | icx | ❌ No | ❌ No | N/A |
| addit_omp.c + ICX | icx | ✅ Yes | ❌ No | ❌ No |

**3f. Generate Assembly to Verify**

```bash
# ICC version
source setup_icc.sh
icc -O2 -xHost -S addit.c -o addit_icc.s

# ICX without pragma
source setup_icx.sh
icx -O2 -xHost -S addit.c -o addit_icx_scalar.s

# ICX with pragma
icx -O2 -xHost -qopenmp -S addit_omp.c -o addit_icx_simd.s
```

**Look for SIMD instructions:**

```bash
# ICC should show SIMD instructions (vmovupd, vaddpd, etc.)
grep -E "vmov|vadd" addit_icc.s | head -5

# ICX without pragma should show scalar instructions only
grep -E "vmov|vadd" addit_icx_scalar.s | head -5

# ICX with pragma should show SIMD instructions
grep -E "vmov|vadd" addit_icx_simd.s | head -5
```

**3g. Try It Online**

You can experiment with this code online using Compiler Explorer:

**🔗 [Try on Godbolt: https://godbolt.org/z/x8TxG56Gr](https://godbolt.org/z/x8TxG56Gr)**

On Godbolt you can:
- See the assembly output side-by-side
- Compare ICC vs ICX behavior
- Toggle the `#pragma omp simd` on/off
- Observe the difference in generated code

### Understanding OpenMP SIMD

**What is `#pragma omp simd`?**

OpenMP SIMD is a directive that tells the compiler:
- "I, the programmer, assert this loop can be safely vectorized"
- "Ignore conservative dependency analysis"
- "Trust me that there are no aliasing issues"

**Syntax:**
```c
#pragma omp simd [clauses]
for (...) {
  // loop body
}
```

**Common clauses:**
- `safelen(n)`: Minimum safe distance between iterations
- `simdlen(n)`: Preferred vector length
- `aligned(ptr:n)`: Pointer is n-byte aligned
- `private(var)`: Variable is private to each iteration
- `reduction(op:var)`: Reduction operation across iterations

**Example with safelen:**
```c
#pragma omp simd safelen(4)
for (int i = m; i < m+n; i++) {
  a[i] = b[i] + a[i-x];  // Safe if |x| >= 4
}
```

### ICC vs ICX: Philosophy Differences

| Aspect | ICC (Classic) | ICX (LLVM-based) |
|--------|---------------|---------------|
| **Vectorization strategy** | Aggressive with runtime checks | Conservative, needs guidance |
| **Multiversioning** | Frequently used | Less common |
| **OpenMP SIMD** | Helpful but optional | Essential for many loops |
| **Backward compatibility** | Mature, proven optimizations | Modern, evolving |
| **Best for** | Legacy codebases | New development with pragmas |

### When to Use `#pragma omp simd`

**Use it when:**
- ✅ Compiler refuses to vectorize but you know it's safe
- ✅ You have domain knowledge the compiler lacks
- ✅ You've verified no loop-carried dependencies
- ✅ You've profiled and vectorization would help

**Don't use it when:**
- ❌ You're not sure if vectorization is safe
- ❌ There are true loop-carried dependencies
- ❌ Iterations must execute in order
- ❌ Side effects depend on execution order

**If you use it incorrectly:**
- Program may produce wrong results
- Data races possible
- Undefined behavior
- Very hard to debug!

### Key Takeaways

- **ICC** is more aggressive with automatic vectorization and multiversioning
- **ICX** is more conservative and requires explicit guidance via pragmas
- **`#pragma omp simd`** forces vectorization when programmer knows it's safe
- **Loop-carried dependencies** prevent vectorization unless compiler can prove safety
- **Backward vs forward dependencies**: Backward (x < 0) is vectorizable, forward (x > 0) is not
- **OpenMP SIMD** is becoming essential for modern vectorization optimization
- **Always verify correctness** after adding SIMD pragmas

### Questions to Consider

1. Why does ICC multiversion this loop but ICX doesn't vectorize it at all?
   - **Answer**: ICC uses aggressive runtime checks; ICX prefers programmer guidance via pragmas

2. What happens if you add `#pragma omp simd` but `x > 0` at runtime?
   - **Answer**: Undefined behavior! Vectorized iterations overlap, causing data races and wrong results

3. How does `#pragma omp simd` differ from loop multiversioning?
   - **Answer**: SIMD pragma asserts safety (no checks), multiversioning verifies safety at runtime

4. When should you use ICC vs ICX?
   - **Answer**: ICC for legacy code needing auto-vectorization; ICX for new development with explicit optimization

## Exercise 4: Outer Loop Vectorization

### Goal
Understand outer loop vectorization and how knowing trip counts enables better optimization.

### Background: Inner vs Outer Loop Vectorization

When you have nested loops, the compiler can vectorize either:
- **Inner loop**: Process multiple iterations of the inner loop in parallel
- **Outer loop**: Process multiple iterations of the outer loop in parallel

**Example:**
```c
// Nested loops
for (int i = 0; i < n; i++) {        // Outer loop
    for (int j = 0; j < nd; j++) {   // Inner loop
        // work
    }
}
```

**Inner loop vectorization:** Good when inner loop has many iterations (large `nd`)  
**Outer loop vectorization:** Good when inner loop has few iterations (small `nd`) or unknown trip count

### The Problem: Distance Calculation

We want to calculate Euclidean distance from multiple points to a reference point:

```
distance = sqrt((x1-xref)² + (y1-yref)² + (z1-zref)²)
```

**Code structure:**
```c
for each point:          // Outer loop (n iterations)
    sum = 0
    for each dimension:  // Inner loop (nd iterations)
        diff = point[dim] - ref[dim]
        sum += diff * diff
    distance = sqrt(sum)
```

### Code Variants

We'll use the **same source file (`dist.c`)** compiled three different ways using different compiler flags:

**dist.c** (unified source with conditional compilation):
```c
#ifdef  KNOWN_TRIP_COUNT
#define MYDIM 3
#else                           // pt     input  vector of points
#define MYDIM nd                // ptref  input  reference point
#endif                          // dis    output vector of distances
#include <math.h>

void dist( int n, int nd, float pt[][MYDIM], float dis[], float ptref[]) {
/* calculate distance from data points to reference point */

#ifdef USE_OMP_SIMD
#pragma omp simd
#endif
    for (int ipt=0; ipt<n; ipt++) {
        float d = 0.;

        for (int j=0; j<MYDIM; j++) {
            float t = pt[ipt][j] - ptref[j];
            d+= t*t;
         }

        dis[ipt] = sqrtf(d);
    }
}
```

**Three versions to compare (single source file, different macro expansions):**

We use a single `dist.c` file for convenience, but the preprocessor macros (`-DUSE_OMP_SIMD`, `-DKNOWN_TRIP_COUNT`) produce different effective source code for each version.

1. **Version 1**: No pragma, no known trip count
   - Compile: `icx -O2 -xHost dist.c dist_main.c`
   - No `-DUSE_OMP_SIMD` → `#pragma omp simd` **not in code**
   - No `-DKNOWN_TRIP_COUNT` → `MYDIM` = `nd` (variable)
   - Result: **Inner loop vectorized**

2. **Version 2**: With pragma, unknown trip count  
   - Compile: `icx -O2 -xHost -DUSE_OMP_SIMD dist.c dist_main.c`
   - `-DUSE_OMP_SIMD` → `#pragma omp simd` **present in code**
   - No `-DKNOWN_TRIP_COUNT` → `MYDIM` = `nd` (variable)
   - Result: **Outer loop vectorized** (forced by pragma)

3. **Version 3**: With pragma and known trip count
   - Compile: `icx -O2 -xHost -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_known_main.c`
   - `-DUSE_OMP_SIMD` → `#pragma omp simd` **present in code**
   - `-DKNOWN_TRIP_COUNT` → `MYDIM` = `3` (constant)
   - Result: **Outer loop vectorized + inner loop fully unrolled**

**Key insight:** Preprocessor macros create different effective source code from the same file. This approach keeps the code organized in one place while demonstrating different optimization strategies.

### Tasks

**4a. Version 1: No Pragma, Unknown Trip Count (Inner Loop Vectorized)**

```bash
source setup_icx.sh
icx -O2 -xHost -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout dist.c -c
```

**Compilation details:**
- No `-DUSE_OMP_SIMD` flag → `#pragma omp simd` is **not in the code**
- No `-DKNOWN_TRIP_COUNT` → `MYDIM = nd` (variable)
- Uses `icx` (C compiler) with `-qopt-report-phase=vec` for vectorization messages only

**Look for in the report:**
```
LOOP BEGIN at dist.c (22, 5)
<Multiversioned v1>
    remark #15541: loop was not vectorized: outer loop is not an auto-vectorization candidate.

    LOOP BEGIN at dist.c (25, 9)
        remark #15300: LOOP WAS VECTORIZED
        remark #15305: vectorization support: vector length 8
    LOOP END
LOOP END

LOOP BEGIN at dist.c (22, 5)
<Multiversioned v2>
    remark #15615: Loop was not vectorized: not vectorizable due to data dependence, fall-back loop for multiversioning
LOOP END
```

**What happened:**
- ✅ **Inner loop WAS vectorized** (multiversioned with runtime checks)
- ❌ **Outer loop NOT vectorized** (not an auto-vectorization candidate without pragma)
- **Multiversioning present** due to potential data dependencies

**4b. Version 2: With Pragma, Unknown Trip Count (Outer Loop Vectorized)**

Now compile with `-DUSE_OMP_SIMD` to include the `#pragma omp simd` and `-qopenmp` to enable OpenMP:

```bash
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout dist.c -c
```

**Compilation details:**
- `-DUSE_OMP_SIMD` flag → `#pragma omp simd` is **in the code**
- `-qopenmp` flag → OpenMP support enabled (required for pragma to work)
- No `-DKNOWN_TRIP_COUNT` → `MYDIM = nd` (variable)

**Look for in the report:**
```
LOOP BEGIN at dist.c (20, 1)
    remark #15569: Compiler has chosen to target XMM/YMM vector. Try using -mprefer-vector-width=512 to override.
    remark #15301: SIMD LOOP WAS VECTORIZED
    remark #15305: vectorization support: vector length 16
...
    LOOP BEGIN at dist.c (25, 9)
        remark #15328: vectorization support: unmasked gather load: pt [ /dss/dsshome1/0F/di46loj/workshop/lab3/dist.c (26, 23) ]
        remark #15475: --- begin vector loop cost summary ---
        remark #15488: --- end vector loop cost summary ---
        remark #15447: --- begin vector loop memory reference summary ---
        remark #15462: unmasked indexed (or gather) loads: 1
        remark #15567: Gathers are generated due to non-unit stride index of the corresponding loads.
        remark #15474: --- end vector loop memory reference summary ---
    LOOP END
```

**What happened:**
- ✅ **Outer loop WAS vectorized** (forced by pragma)
- **Vector length 16** (processes 16 floats at once)
- Inner loop (25, 9) remains as part of vectorized computation
- No `private` clause needed - `d` and `t` are automatically private (declared inside loop)

**Note about private clause:** Variables declared inside the loop body are automatically private to each SIMD lane. A `private(var)` clause would only be necessary if variables were declared outside:
```c
float d, t;  // Declared outside
#pragma omp simd private(d, t)  // Now private clause is needed
for (int ipt=0; ipt<n; ipt++) { ... }
```

**4c. Version 3: Pragma + Known Trip Count (Outer Loop Vectorized - Best)**

Now compile with `-qopenmp`, `-DUSE_OMP_SIMD`, and `-DKNOWN_TRIP_COUNT`:

```bash
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT -qopt-report=3 -qopt-report-phase=vec,loop -qopt-report-file=stdout dist.c -c
```

**Compilation details:**
- `-qopenmp` flag → OpenMP support enabled
- `-DUSE_OMP_SIMD` flag → `#pragma omp simd` is **in the code**
- `-DKNOWN_TRIP_COUNT` → `MYDIM = 3` (constant)
- `-qopt-report-phase=vec,loop` → Show vectorization **and** loop optimization messages

**Look for in the report:**
```
LOOP BEGIN at dist.c (20, 1)
...
    remark #15301: SIMD LOOP WAS VECTORIZED
    remark #15305: vectorization support: vector length 8
    remark #15597: -- VLS-optimized vector load replaces 3 independent loads of stride 3
...
    LOOP BEGIN at dist.c (25, 9)
        remark #25436: Loop completely unrolled by 3
    LOOP END
LOOP END
```

**What happened:**
- ✅ **OUTER LOOP WAS VECTORIZED!**
- **Vector length 8** (processes 8 points simultaneously)
- **VLS optimization** - compiler recognizes and optimizes the stride-3 access pattern
- ✅ **Inner loop completely unrolled** - `remark #25436` confirms the inner loop (3 iterations) is fully unrolled
- Inner loop recognized as having exactly 3 iterations (MYDIM=3)
- **Inner loop fully unrolled** (no loop overhead)
- Compiler vectorizes across outer loop iterations
- Processes multiple points simultaneously
- **Best of both:** pragma ensures outer loop vectorization + known trip count enables inner loop unrolling

**4d. Understanding the Three Approaches**

**Version 1 (Unknown trip count, inner loop vectorized):**
```
Point 0: for j=0..nd: (x0-xref)² + (y0-yref)² + (z0-zref)² → √ [SIMD inner]
Point 1: for j=0..nd: (x1-xref)² + (y1-yref)² + (z1-zref)² → √ [SIMD inner]
Point 2: for j=0..nd: (x2-xref)² + (y2-yref)² + (z2-zref)² → √ [SIMD inner]
```
**Inner loop** vectorized, outer loop sequential

**Version 2 (OMP SIMD, outer loop vectorized):**
```
Process 4-8 points in parallel (outer loop SIMD):
  Points [0,1,2,3]: compute x², y², z² for all points simultaneously
  Result: [dist[0], dist[1], dist[2], dist[3]] in one go
```
**Outer loop** vectorized with pragma

**Version 3 (Known trip count, outer loop vectorized automatically):**
```
Process 4-8 points in parallel (outer loop SIMD):
  Vector 0: (x0-xref)²  (x1-xref)²  (x2-xref)²  (x3-xref)²
+ Vector 1: (y0-yref)²  (y1-yref)²  (y2-yref)²  (y3-yref)²
+ Vector 2: (z0-zref)²  (z1-zref)²  (z2-zref)²  (z3-zref)²
= Vector 3: sum0        sum1        sum2        sum3
  √Vector:  dist0       dist1       dist2       dist3
```
**Outer loop** vectorized automatically (inner loop unrolled)

**4e. Build and Test Programs**

```bash
# Build Version 1: No pragma, unknown trip count (inner loop vectorized)
icx -O2 -xHost dist.c dist_main.c -o dist_v1

# Build Version 2: With pragma, unknown trip count (outer loop vectorized)
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD dist.c dist_main.c -o dist_v2

# Build Version 3: Pragma + known trip count (outer loop vectorized, optimized)
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_known_main.c -o dist_v3

# Run and compare
echo "Version 1 (inner loop vectorized):"
./dist_v1

echo "Version 2 (outer loop - pragma):"
./dist_v2

echo "Version 3 (outer loop - pragma + known trip count):"
./dist_v3
```

**4f. Generate Assembly for Comparison**

```bash
icx -O2 -xHost -S dist.c -o dist_v1.s
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -S dist.c -o dist_v2.s
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT -S dist.c -o dist_v3.s
```

**Analyze the assembly:**

```bash
# Count SIMD instructions in each version
echo "Version 1 (inner loop) - SIMD instructions:"
grep -E "vmovups|vfmadd|vsqrtps" dist_v1.s | wc -l

echo "Version 2 (OMP SIMD outer) - SIMD instructions:"
grep -E "vmovups|vfmadd|vsqrtps" dist_v2.s | wc -l

echo "Version 3 (known trip count outer) - SIMD instructions:"
grep -E "vmovups|vfmadd|vsqrtps" dist_v3.s | wc -l
```

**Expected results (approximate):**
- **Version 1**: ~42 instructions (inner loop vectorized with multiversioning - multiple loop versions)
- **Version 2**: ~59 instructions (outer loop vectorized with gather loads - complex memory access)
- **Version 3**: ~14 instructions (outer loop vectorized with VLS-optimized loads - most efficient)

**Key insight:** Fewer SIMD instructions doesn't mean worse performance! Version 3 has the fewest instructions because:
- **Inner loop fully unrolled** - no loop overhead
- **VLS-optimized loads** - compiler recognizes stride-3 pattern and uses efficient vector loads
- **No multiversioning** - single optimized code path

Version 1 has more instructions due to multiversioning (multiple loop copies). Version 2 has the most due to gather instructions for unknown stride patterns.

**4g. Performance Implications**

| Aspect | V1: Unknown (Inner) | V2: OMP SIMD (Outer) | V3: Known (Outer) |
|--------|---------------------|----------------------|-------------------|
| Inner loop vectorized | ✅ Yes (multiversioned) | Part of outer | Fully unrolled |
| Outer loop vectorized | ❌ No | ✅ Yes (pragma) | ✅ Yes (pragma) |
| Vector length | 8 (inner loop) | 16 (outer loop) | 8 (outer loop) |
| Processing strategy | SIMD per point | SIMD across points | SIMD across points |
| Points per cycle | 1 (but faster inner) | 16 | 8 |
| Optimization | Multiversioned | Gather loads | VLS-optimized stride-3 |
| Code complexity | Low | Medium (pragma) | Low (macros) |
| Expected speedup | Baseline | 2-4x vs V1 | 2-4x vs V1 (best) |

**Why three different approaches?**

1. **Version 1 (Inner loop vectorized):** 
   - Compiler vectorizes inner loop with multiversioning
   - Processes one point at a time, but uses SIMD for the 3 dimensions
   - Good baseline performance

2. **Version 2 (OMP SIMD pragma):**
   - Programmer forces outer loop vectorization with `#pragma omp simd`
   - Processes multiple points in parallel
   - Requires programmer knowledge that vectorization is safe
   - `private(d, t)` would be needed if variables declared outside loop scope

3. **Version 3 (Pragma + known trip count with macro):**
   - Pragma forces outer loop vectorization
   - Compiler knows inner loop has exactly 3 iterations (MYDIM=3)
   - Inner loop fully unrolled (no loop overhead)
   - Outer loop vectorized across multiple points simultaneously
   - **Best of both worlds:** pragma ensures vectorization + constant enables unrolling

### Key Patterns for Outer Loop Vectorization

**Pattern 1: Small fixed inner loop**
```c
#define DIMS 3
for (i = 0; i < n; i++) {
    for (j = 0; j < DIMS; j++) {  // Fixed trip count
        // work
    }
}
```
✅ Compiler can vectorize outer loop

**Pattern 2: Large variable inner loop**
```c
for (i = 0; i < n; i++) {
    for (j = 0; j < m; j++) {  // Variable, unknown at compile time
        // work
    }
}
```
❌ Hard to vectorize either loop

**Pattern 3: Reduction in inner loop**
```c
for (i = 0; i < n; i++) {
    float sum = 0;
    for (j = 0; j < FIXED_SIZE; j++) {
        sum += array[i][j];  // Reduction
    }
    result[i] = sum;
}
```
✅ Outer loop vectorization ideal for this pattern

### When to Use Outer Loop Vectorization

**Good candidates:**
- ✅ Inner loop has small, fixed trip count (2-10 iterations)
- ✅ Outer loop has many iterations
- ✅ Reduction operations in inner loop
- ✅ Working with fixed-size structures (3D points, RGB pixels, etc.)

**Not suitable:**
- ❌ Inner loop has large, variable trip count
- ❌ Complex dependencies between outer iterations
- ❌ Inner loop already vectorizes well

### Practical Applications

**3D Graphics:** Processing vertices (x, y, z)
```c
for (vertex in vertices) {
    for (dim in [x, y, z]) {  // Fixed: 3 dimensions
        transform[dim] = matrix[dim] * vertex[dim];
    }
}
```

**Image Processing:** RGB pixels
```c
for (pixel in pixels) {
    for (channel in [R, G, B]) {  // Fixed: 3 channels
        adjusted[channel] = pixel[channel] * brightness;
    }
}
```

**Physics Simulations:** 3D force calculations
```c
for (particle in particles) {
    for (dim in [x, y, z]) {  // Fixed: 3 dimensions
        force[dim] = mass * acceleration[dim];
    }
}
```

### Key Takeaways

- **Inner vs outer loop vectorization**: Inner processes one outer iteration with SIMD; outer processes multiple outer iterations with SIMD
- **Version 1** (unknown trip count): Inner loop vectorized with multiversioning, outer loop sequential
- **Version 2** (OMP SIMD pragma): Forces outer loop vectorization with programmer guidance
- **Version 3** (pragma + known trip count): Outer loop vectorized by pragma, inner loop fully unrolled due to constant MYDIM=3
- Small **fixed inner loops** (2-10 iterations) enable automatic outer loop vectorization
- Use **`-DKNOWN_TRIP_COUNT`** to conditionally compile with known trip counts
- **`#pragma omp simd`** forces outer loop vectorization (no private clause needed if vars declared inside loop)
- Outer loop vectorization is ideal for **reduction patterns** with small inner loops
- **Flattened arrays** (`float *`) vs **2D arrays** (`float[][]`) affect compiler code generation
- Modern compilers choose the best vectorization strategy based on loop structure

### Questions to Consider

1. Why does Version 1 vectorize the inner loop but not the outer loop?
   - **Answer**: Compiler can handle variable `nd` with multiversioning for inner loop; outer loop needs explicit guidance or known trip count

2. Why is no `private` clause needed in the OMP SIMD pragma?
   - **Answer**: Variables `d` and `t` are declared inside the loop body, so they're automatically private to each SIMD lane. Only need `private` clause if variables are declared outside the loop.

3. Why does Version 3 have better optimization than Version 2?
   - **Answer**: Both vectorize outer loop (pragma), but V3 knows inner loop has exactly 3 iterations (MYDIM=3), so it fully unrolls it (no loop overhead)

4. Which version is best?
   - **Answer**: Version 3 (known trip count) - automatic optimization without pragma complexity, best performance

5. When would you use Version 2 (OMP SIMD) over Version 3?
   - **Answer**: When trip count is truly variable at runtime, but you know vectorization is safe

## Exercise 5: Performance Benchmarking

### Goal
Measure and compare the actual performance of different vectorization strategies and instruction sets.

### Background: From Code Analysis to Performance Measurement

In Exercise 4, we analyzed vectorization reports and assembly code. Now we'll measure **actual runtime performance** to see the real-world impact of:
- Different optimization levels (`-O1` vs `-O2`)
- Different vectorization strategies (inner vs outer loop)
- Different instruction sets (AVX vs AVX2 vs AVX-512)
- FMA (Fused Multiply-Add) instructions
- 512-bit ZMM registers

### Benchmark Code

We'll use `dist_bench.c` which runs the distance calculation on **100 million points** (larger problem for robust timing) and measures:
- **CPU model** (from /proc/cpuinfo)
- **Execution time** (seconds, averaged over 10 runs)
- **Throughput** (million points/second)
- **Performance** (GFLOPS - billion floating-point operations per second)

### Versions to Benchmark

We'll compile and test 6 different versions:

| Version | Description | Compilation Flags |
|---------|-------------|-------------------|
| **V1-O1** | No vectorization (baseline) | `-O1` |
| **V1-AVX** | Inner loop vectorized | `-O2 -xAVX` |
| **V2-AVX** | Outer loop vectorized (unknown stride) | `-O2 -xAVX -qopenmp -DUSE_OMP_SIMD` |
| **V3-AVX** | Outer + inner unrolled | `-O2 -xAVX -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT` |
| **V3-AVX2** | V3 + FMA instructions | `-O2 -xCORE-AVX2 -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT` |
| **V3-AVX512** | V3 + 512-bit ZMM registers | `-O2 -xCORE-AVX512 -qopt-zmm-usage=high -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT` |

### Tasks

**5a. Build All Benchmark Versions**

```bash
source setup_icx.sh

# Version 1 - No vectorization (baseline)
icx -O1 dist.c dist_bench.c -o bench_v1_o1

# Version 1 - Inner loop vectorized (AVX)
icx -O2 -xAVX dist.c dist_bench.c -o bench_v1_avx

# Version 2 - Outer loop vectorized (AVX, unknown stride)
icx -O2 -xAVX -qopenmp -DUSE_OMP_SIMD dist.c dist_bench.c -o bench_v2_avx

# Version 3 - Outer loop + inner unrolled (AVX)
icx -O2 -xAVX -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_bench.c -o bench_v3_avx

# Version 3 - With AVX2 (adds FMA instructions)
icx -O2 -xCORE-AVX2 -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_bench.c -o bench_v3_avx2

# Version 3 - With AVX-512 and 512-bit ZMM registers
icx -O2 -xCORE-AVX512 -qopt-zmm-usage=high -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_bench.c -o bench_v3_avx512
```

**5b. Run Benchmarks**

```bash
echo "=== Baseline: No Vectorization (-O1) ==="
./bench_v1_o1

echo ""
echo "=== Version 1: Inner Loop Vectorized (AVX) ==="
./bench_v1_avx

echo ""
echo "=== Version 2: Outer Loop Vectorized (AVX, unknown stride) ==="
./bench_v2_avx

echo ""
echo "=== Version 3: Outer Loop + Inner Unrolled (AVX) ==="
./bench_v3_avx

echo ""
echo "=== Version 3: With AVX2 (FMA instructions) ==="
./bench_v3_avx2

echo ""
echo "=== Version 3: With AVX-512 (512-bit ZMM) ==="
./bench_v3_avx512
```

**5c. Real-World Results and Analysis**

**Performance Results on Intel SPR (Sapphire Rapids):**

| Version | Time (s) | Speedup vs Baseline | Key Features |
|---------|----------|---------------------|--------------|
| V1-O1 | 0.238 | **1.00x** (baseline) | No vectorization, scalar code |
| V1-AVX | 0.168 | **1.41x** | Inner loop vectorized, unit-stride loads |
| V2-AVX | 0.211 | **1.13x** | Outer loop vectorized, gather loads penalty |
| V3-AVX | 0.138 | **1.72x** | Outer loop + inner unrolled, VLS-optimized |
| V3-AVX2 | 0.115 | **2.07x** | V3 + FMA instructions, best scalar performance |
| V3-AVX512 | 0.113 | **2.10x** | V3 + 512-bit ZMM, best overall performance |

**Important Observations:**

1. **V1-AVX beats V2-AVX despite "simpler" strategy** 
   - V1 (inner loop): Efficient unit-stride memory access, good cache locality
   - V2 (outer loop): Uses **gather instructions** due to unknown stride (nd variable)
   - **Gather loads are expensive** - V2 is only 1.13x faster vs V1's 1.41x
   - Lesson: Vectorization strategy matters less than memory access pattern!

2. **V3-AVX2 and V3-AVX512 show progressive improvement**
   - V3-AVX (1.72x): VLS-optimized stride-3 loads, inner loop unrolled
   - V3-AVX2 (2.07x): Adds FMA instructions, ~20% faster than V3-AVX
   - V3-AVX512 (2.10x): Wider registers (512-bit), marginal improvement over AVX2
   - **FMA benefits are visible** when combined with good memory access patterns

3. **V3 versions consistently outperform V1 and V2**
   - Known trip count (MYDIM=3) enables **VLS-optimized stride-3 loads**
   - No gather instructions - efficient vector loads replace scatter/gather
   - Inner loop fully unrolled - no loop overhead
   - Architecture-specific features (FMA, wider registers) provide incremental gains

**What affects performance (real factors):**

1. **Memory access pattern** (most critical!)
   - Unit stride (V1, V3): Fast sequential access
   - Gather loads (V2): Slow irregular access causing 25% performance loss vs V1
   - **VLS-optimized stride-3** (V3): Compiler recognizes pattern, enables efficient vectorization
   
2. **Instruction set features**
   - FMA instructions: Provide real benefit (~20% improvement) when memory access is optimized
   - 512-bit ZMM registers: Marginal gain (1-2%) due to memory bandwidth saturation
   - **Good memory access unlocks instruction set benefits**
   
3. **Loop structure optimization**
   - Known trip counts enable inner loop unrolling (V3 beats V1/V2)
   - Outer loop vectorization works when memory pattern is known (V3 vs V2)
   - Inner loop vectorization safe fallback for unknown patterns (V1 vs V2)

4. **CPU-specific factors**
   - Memory bandwidth becomes bottleneck with wider vectors (AVX512 only 1.5% faster than AVX2)
   - Modern CPUs (SPR) handle FMA efficiently without frequency scaling issues
   - Cache hierarchy affects performance at scale (100M points stress L3)

**5d. Understanding the Numbers**

**GFLOPS calculation:**
- Each point requires: 3 subtractions, 3 multiplications, 2 additions, 1 sqrt
- Total: ~6-7 floating-point operations per point (simplified count)
- 100 million points = 600-700 million FLOPs
- GFLOPS = FLOPs / (time × 10⁹)

**Throughput:**
- Points per second shows how many distance calculations completed
- Higher is better for real applications

**Speedup:**
- Compare each version against baseline (V1-O1)
- Speedup = Time_baseline / Time_optimized

### Key Takeaways

- **Memory access pattern matters more than vectorization strategy** - V1-AVX (inner loop, 1.41x) beats V2-AVX (outer loop, 1.13x) due to gather load overhead
- **Gather instructions are expensive** - V2-AVX uses gather loads for unknown stride, losing 20% performance vs unit-stride V1
- **Known trip counts enable VLS optimization** - V3 versions use efficient stride-3 loads instead of gathers, achieving 1.72x+ speedup
- **FMA provides real benefits with good memory patterns** - V3-AVX2 (2.07x) shows 20% gain over V3-AVX (1.72x) when combined with optimized loads
- **Memory bandwidth limits wider vectors** - V3-AVX512 (2.10x) only 1.5% faster than V3-AVX2 (2.07x), saturation point reached
- **Optimization strategy hierarchy**: Memory access (most critical) → Loop structure → Instruction set features
- **Always benchmark on real hardware** - SPR results show clear performance progression when optimizations align correctly

### Questions to Consider

1. **Why does V1-AVX beat V2-AVX despite "worse" vectorization strategy?**
   - **Answer**: V1 (1.41x) uses efficient unit-stride loads with good cache locality. V2 (1.13x) uses gather instructions because compiler doesn't know stride pattern (nd is variable). Gather loads are 3-5x slower than regular loads, causing 25% performance loss relative to V1.

2. **Why is V3-AVX2 faster than V3-AVX on SPR?**
   - **Answer**: On modern Sapphire Rapids CPUs, FMA instructions provide genuine benefit (~20% speedup) when combined with optimized memory access patterns. V3-AVX2 (2.07x) improves over V3-AVX (1.72x) because VLS-optimized loads eliminate the memory bottleneck, allowing FMA throughput to matter.

3. **Why doesn't V3-AVX512 show dramatic speedup over V3-AVX2?**
   - **Answer**: Memory bandwidth saturation - V3-AVX512 (2.10x) is only 1.5% faster than V3-AVX2 (2.07x). Can't feed data fast enough to fully utilize 512-bit units. The workload hits memory bandwidth limits before compute limits.

4. **What's the key lesson from these benchmarks?**
   - **Answer**: Performance optimization is hierarchical - memory access patterns matter most (V1 vs V2), then loop structure (V3 vs V1), then instruction set features (AVX2/512). Advanced features only help when lower levels are optimized. Always measure on target hardware - SPR shows clear progression when optimizations align.

## Exercise 6: Special Idioms - Compress Loop Pattern

### Goal
Understand how the compiler recognizes special loop patterns (idioms) and uses architecture-specific instructions for vectorization.

### Background: Compress/Expand Loop Pattern

A **compress loop** is a common pattern where you filter elements from one array into another based on a condition:

```c
int compress(float *a, float *b, int na) {
    int nb = 0;
    for (int ia = 0; ia < na; ia++) {
        if (a[ia] > 0.f)
            b[nb++] = a[ia];     // Compress: only positive values
    }
    return nb;
}
```

**The Challenge:**
- **Variable write positions**: `b[nb++]` means we don't know where to write until we evaluate the condition
- **Data-dependent control flow**: The `if` statement makes vectorization complex
- Traditional vectorization can't handle this pattern efficiently

**The Solution:**
- **AVX-512** provides `vcompressps` instruction specifically for this idiom
- Stores selected elements to memory based on a mask
- Enables efficient vectorization of compress/expand patterns

**Why AVX2 Can't Vectorize This:**
- AVX2 lacks specialized compress/expand instructions
- Would require expensive gather/scatter operations or scalar fallback
- Compiler chooses not to vectorize (scalar code is faster)

### Code: compress.c

```c
int compress(float *a, float *b, int na)
{
    int nb = 0;
    for (int ia = 0; ia < na; ia++)
    {
        if (a[ia] > 0.f)
            b[nb++] = a[ia];
    }
    return nb;
}
```

**Online Testing:**
You can experiment with this code at **[Compiler Explorer: godbolt.org/z/63oTsshKd](https://godbolt.org/z/63oTsshKd)**

### Tasks

**6a. Compile with AVX2 (No Compress Instruction)**

```bash
source setup_icx.sh
icx -xCORE-AVX2 -O2 -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout -fargument-noalias compress.c -c
```

**Compilation flags:**
- `-xCORE-AVX2`: Target AVX2 instruction set
- `-fargument-noalias`: Tell compiler pointer arguments don't overlap
- `-qopt-report-phase=vec`: Show only vectorization messages

**Look for in the report:**
```
LOOP BEGIN at compress.c(10,5)
   remark #15344: loop was not vectorized: vector dependence prevents vectorization
   remark #15346: vector dependence: assumed OUTPUT dependence between b[nb] (13:13) and b[nb] (13:13)
```

**What happened:**
- ❌ **Loop NOT vectorized**
- Compiler detects data-dependent write position (`b[nb++]`)
- AVX2 has no efficient instruction for this pattern
- Scalar code is generated

**6b. Compile with AVX-512 (With Compress Instruction)**

```bash
icx -xCORE-AVX512 -O2 -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout -fargument-noalias compress.c -c
```

**Look for in the report:**
```
LOOP BEGIN at compress.c(10,5)
   remark #15300: LOOP WAS VECTORIZED
   remark #15305: vectorization support: vector length 16
...
   remark #15478: estimated potential speedup: 3.953125
...
   remark #15497: vector compress: 1
...
```

**What happened:**
- ✅ **LOOP WAS VECTORIZED!**
- Compiler recognized the compress pattern
- Uses `vcompressps` instruction (AVX-512)
- Vector length 16 (processes 16 floats at once)

**6c. View Assembly - AVX2 vs AVX-512**

Generate assembly to see the difference:

```bash
# AVX2 - scalar code
icx -xCORE-AVX2 -O2 -S -fargument-noalias compress.c -o compress_avx2.s

# AVX-512 - vectorized with vcompresspd
icx -xCORE-AVX512 -O2 -S -fargument-noalias compress.c -o compress_avx512.s
```

**Check for compress instruction in AVX-512:**
```bash
grep "vcompress" compress_avx512.s
# Should find: vcompressps instruction
```

**AVX2 assembly pattern:**
- Simple `movss` (scalar move)
- Conditional branches
- Sequential processing

**AVX-512 assembly pattern:**
- `vcmpps` - vector compare (creates mask)
- `vcompressps` - compress floats based on mask
- Parallel processing of 16 elements

**6d. Build and Test Both Versions**

```bash
# AVX2 version (scalar)
icx -xCORE-AVX2 -O2 -fargument-noalias compress.c compress_main.c -o compress_avx2

# AVX-512 version (vectorized)
icx -xCORE-AVX512 -O2 -fargument-noalias compress.c compress_main.c -o compress_avx512

# Run and compare
echo "=== AVX2 (Scalar) ==="
./compress_avx2

echo ""
echo "=== AVX-512 (Vectorized with vcompresspd) ==="
./compress_avx512
```

**Expected results on Intel SPR:**

| Version | Time (s) | Throughput (M elem/s) | Speedup |
|---------|----------|----------------------|---------|
| AVX2 (scalar) | 0.0472 | 211.7 | 1.00x (baseline) |
| AVX-512 (vectorized) | 0.0040 | 2511.6 | **11.9x** |

- Both produce identical output (same filtered values)
- **11.9x speedup** with AVX-512 compress instruction!
- 49.9% selectivity (roughly half the elements are positive)
- Throughput increased from ~212 million to ~2512 million elements/second

**6e. Understanding the vcompressps Instruction**

**How vcompressps works:**

1. **Compare**: Create a mask of elements that match condition
   ```asm
   vcmpps k1, zmm0, zmm1, 14   ; k1 = mask (a[i] > 0)
   ```

2. **Compress**: Store only selected elements contiguously
   ```asm
   vcompressps [b+offset]{k1}, zmm0   ; Store only masked elements
   ```

3. **Count**: Update write position based on number of selected elements
   ```asm
   kmovw eax, k1              ; Get mask bits
   popcnt eax, eax            ; Count set bits
   add nb, eax                ; Update nb
   ```

**Visual example (4 elements):**
```
Input:  [-2.0f,  3.0f, -1.0f,  5.0f]
Mask:   [    0,     1,     0,     1]  (positive values)
Output: [ 3.0f,  5.0f]                (compressed)
```

### Performance Characteristics

**Real-world results on Intel SPR (10M elements, ~50% selectivity):**

- **AVX2**: 0.047s, 212 M elem/s (scalar code with branches)
- **AVX-512**: 0.004s, 2512 M elem/s (vectorized with vcompressps)
- **Speedup**: 11.9x faster with AVX-512!

**Why such dramatic speedup?**

1. **Vectorized processing**: 16 floats processed per iteration vs 1 scalar
2. **Eliminates branches**: Mask-based selection instead of conditional jumps
3. **Efficient memory writes**: vcompressps writes contiguously without checks
4. **Pipeline friendly**: No branch mispredictions, better instruction throughput

**Selectivity impact (estimated):**

| Selectivity | Elements Copied | Expected Speedup | Why |
|-------------|-----------------|------------------|-----|
| 10% positive | 10% of data | ~8-10x | Less memory pressure, more compute-bound |
| 50% positive | 50% of data | **~12x** (measured) | Balanced compute/memory |
| 90% positive | 90% of data | ~10-15x | More memory writes, but still highly efficient |

**Why selectivity matters:**
- Lower selectivity → fewer writes → less memory bandwidth needed → compute advantage dominates
- Higher selectivity → more writes → memory bandwidth matters more → still fast due to efficient vcompressps
- **Branch prediction** in scalar code suffers most at ~50% selectivity (worst case for branches)

### Other Special Idioms in AVX-512

AVX-512 includes instructions for several special patterns:

| Pattern | Instruction | Description |
|---------|-------------|-------------|
| **Compress** | `vcompress{pd,ps}` | Filter elements into contiguous array |
| **Expand** | `vexpand{pd,ps}` | Scatter elements from contiguous array |
| **Conflict Detection** | `vpconflict{d,q}` | Find duplicate indices |
| **Population Count** | `vpopcnt{d,q}` | Count set bits in vectors |

### Key Takeaways

- **Compress/expand loop patterns** are recognized as special idioms by the compiler
- **AVX2 and earlier** cannot efficiently vectorize these patterns (no specialized instructions)
- **AVX-512** provides `vcompressps`/`vcompresspd` for efficient vectorization
- The compiler **automatically recognizes** the pattern and uses the right instruction
- **Dramatic speedup on SPR**: 11.9x faster (0.047s → 0.004s) at 50% selectivity
- **Eliminates branch mispredictions**: Mask-based processing instead of conditional jumps
- **Pattern recognition** requires specific code structure (if statement with post-increment)
- **No code changes needed** - same source works optimally with AVX-512
- This demonstrates **architecture-specific** vectorization capabilities
- **Most dramatic benefit** among all exercises - compress is a perfect match for AVX-512

### Questions to Consider

1. Why can't AVX2 efficiently vectorize the compress pattern?
   - **Answer**: AVX2 lacks specialized compress/expand instructions; would need expensive gather/scatter operations

2. What makes vcompressps special?
   - **Answer**: It can store selected vector elements contiguously in memory based on a mask, exactly what compress pattern needs

3. Would this pattern vectorize with OpenMP SIMD pragma on AVX2?
   - **Answer**: No, pragma can't create instructions that don't exist; AVX2 hardware limitation

4. What other patterns benefit from AVX-512 special instructions?
   - **Answer**: Expand (inverse of compress), conflict detection (finding duplicates), histogram updates

5. How does the compiler recognize this as a compress pattern?
   - **Answer**: Looks for specific structure: loop with conditional, post-increment write index, dependent on condition

6. Why is the speedup so much higher (11.9x) than other exercises?
   - **Answer**: Compress pattern perfectly matches AVX-512 capabilities. Eliminates all branch mispredictions (huge cost at 50% selectivity), processes 16 elements in parallel, and vcompressps is highly optimized for this exact use case. Other exercises are memory-bound; compress is branch/compute-bound where AVX-512 excels.

## Running the Lab

### Using the Automated Script

```bash
# Run all exercises
./run_exercises.sh all

# Run specific exercise
./run_exercises.sh 1    # Loop multiversioning and vectorization
./run_exercises.sh 2    # Architecture-specific flags (-m, -x, -ax)
./run_exercises.sh 3    # OpenMP SIMD pragmas (ICC vs ICX)
./run_exercises.sh 4    # Outer loop vectorization
./run_exercises.sh 5    # Performance benchmarking
./run_exercises.sh 6    # Special idioms - compress loop pattern
```

### Manual Execution

**Exercise 1:**
```bash
# Setup environment
source setup_icx.sh

# Task 1b-1c: Compile and view optimization report
# Look for: LOOP WAS VECTORIZED, LOOP WAS MULTIVERSIONED
icpx -g -O2 -xHost -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c

# Task 1f: Now eliminate multiversioning by asserting no pointer aliasing
# Look for: LOOP WAS VECTORIZED (but NO multiversioning!)
icpx -g -O2 -xHost -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c

# Task 1g: Compile with -xCORE-AVX512 to investigate vector length
# Keep -fargument-noalias from now on for cleaner vectorization
# Look for: vector length 4 (should be 8 for floats - why only 4?)
icpx -g -O2 -xCORE-AVX512 -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c

# Task 1g: Compile fixed version with float constant (3.1415927f)
# Keep -fargument-noalias for optimal vectorization
# Look for: vector length 8 (now correct!), improved speedup estimate
icpx -g -O2 -xCORE-AVX512 -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin_fixed.cpp -c
```

**Exercise 2:**
```bash
# Compile with different architecture flags (both source files)
icpx -O2 -mavx2 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_m
icpx -O2 -xCORE-AVX2 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_x
icpx -O2 -axCORE-AVX2 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_ax
icpx -O2 -axCORE-AVX2,CORE-AVX512 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_ax_multi

# Compare binary sizes
ls -lh vec_sin_*

# Generate assembly to check for CPU detection
icpx -O2 -mavx2 -S vec_sin_main.cpp -o vec_sin_m.s
icpx -O2 -xCORE-AVX2 -S vec_sin_main.cpp -o vec_sin_x.s
icpx -O2 -axCORE-AVX2 -S vec_sin_main.cpp -o vec_sin_ax.s

# Check for CPU feature initialization call
grep "__intel_new_feature_proc_init" vec_sin_m.s    # Should be empty (no call)
grep "__intel_new_feature_proc_init" vec_sin_x.s    # Should find call
grep "__intel_new_feature_proc_init" vec_sin_ax.s   # Should find call

# Test runtime behavior
./vec_sin_m    # May crash on old CPU
./vec_sin_x    # Exits gracefully on old CPU
./vec_sin_ax   # Always runs
```

**Exercise 3:**
```bash
# Test with ICC (Classic)
source setup_icc.sh
icc -O2 -xHost -qopt-report=3 -qopt-report-file=stdout addit.c -c

# Test with ICX (LLVM-based) - no pragma
source setup_icx.sh
icx -O2 -xHost -qopt-report=3 -qopt-report-file=stdout addit.c -c

# Test with ICX + OpenMP SIMD pragma
icx -O2 -xHost -qopenmp -qopt-report=3 -qopt-report-file=stdout addit_omp.c -c

# Build complete programs
icc -O2 -xHost addit.c addit_main.c -o addit_icc
icx -O2 -xHost addit.c addit_main.c -o addit_icx_scalar
icx -O2 -xHost -qopenmp addit_omp.c addit_main.c -o addit_icx_simd

# Generate assembly
icc -O2 -xHost -S addit.c -o addit_icc.s
icx -O2 -xHost -S addit.c -o addit_icx_scalar.s
icx -O2 -xHost -qopenmp -S addit_omp.c -o addit_icx_simd.s

# Check for SIMD instructions
grep -E "vmovupd|vaddpd" addit_icc.s
grep -E "vmovupd|vaddpd" addit_icx_scalar.s
grep -E "vmovupd|vaddpd" addit_icx_simd.s
```

**Exercise 4:**
```bash
# Same source file (dist.c), three different compilations
source setup_icx.sh

# Version 1: No pragma (no -DUSE_OMP_SIMD), inner loop vectorized
icx -O2 -xHost -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout dist.c -c

# Version 2: With pragma (-qopenmp -DUSE_OMP_SIMD), outer loop vectorized
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout dist.c -c

# Version 3: Pragma + known trip count, outer loop optimized
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout dist.c -c

# Build complete programs
icx -O2 -xHost dist.c dist_main.c -o dist_v1
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD dist.c dist_main.c -o dist_v2
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_known_main.c -o dist_v3

# Run and compare
./dist_v1  # Inner loop SIMD
./dist_v2  # Outer loop SIMD (pragma)
./dist_v3  # Outer loop SIMD (pragma + known trip count)

# Generate assembly (same source, different flags)
icx -O2 -xHost -S dist.c -o dist_v1.s
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -S dist.c -o dist_v2.s
icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT -S dist.c -o dist_v3.s

# Compare SIMD instruction counts
grep -E "vmovups|vfmadd|vsqrtps" dist_v1.s | wc -l
grep -E "vmovups|vfmadd|vsqrtps" dist_v2.s | wc -l
grep -E "vmovups|vfmadd|vsqrtps" dist_v3.s | wc -l
```

**Exercise 5:**
```bash
# Build all benchmark versions
source setup_icx.sh

# Baseline: No vectorization
icx -O1 dist.c dist_bench.c -o bench_v1_o1

# Version 1: Inner loop vectorized (AVX)
icx -O2 -xAVX dist.c dist_bench.c -o bench_v1_avx

# Version 2: Outer loop vectorized (AVX, unknown stride)
icx -O2 -xAVX -qopenmp -DUSE_OMP_SIMD dist.c dist_bench.c -o bench_v2_avx

# Version 3: Outer loop + inner unrolled (AVX)
icx -O2 -xAVX -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_bench.c -o bench_v3_avx

# Version 3: With AVX2 (FMA instructions)
icx -O2 -xCORE-AVX2 -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_bench.c -o bench_v3_avx2

# Version 3: With AVX-512 (512-bit ZMM registers)
icx -O2 -xCORE-AVX512 -qopt-zmm-usage=high -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_bench.c -o bench_v3_avx512

# Run all benchmarks
./bench_v1_o1      # Baseline
./bench_v1_avx     # Inner loop SIMD
./bench_v2_avx     # Outer loop SIMD
./bench_v3_avx     # Outer + unrolled
./bench_v3_avx2    # + FMA
./bench_v3_avx512  # + 512-bit ZMM
```

**Exercise 6:**
```bash
# Compress loop pattern - special idiom
source setup_icx.sh

# Compile with AVX2 (no compress instruction - NOT vectorized)
icx -xCORE-AVX2 -O2 -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout -fargument-noalias compress.c -c

# Compile with AVX-512 (with vcompresspd - VECTORIZED)
icx -xCORE-AVX512 -O2 -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout -fargument-noalias compress.c -c

# Generate assembly to see vcompresspd
icx -xCORE-AVX2 -O2 -S -fargument-noalias compress.c -o compress_avx2.s
icx -xCORE-AVX512 -O2 -S -fargument-noalias compress.c -o compress_avx512.s

# Check for compress instruction
grep "vcompress" compress_avx2.s     # Should be empty
grep "vcompress" compress_avx512.s   # Should find vcompresspd

# Build and benchmark
icx -xCORE-AVX2 -O2 -fargument-noalias compress.c compress_main.c -o compress_avx2
icx -xCORE-AVX512 -O2 -fargument-noalias compress.c compress_main.c -o compress_avx512

./compress_avx2      # Scalar (AVX2)
./compress_avx512    # Vectorized (AVX-512)

# Try online: https://godbolt.org/z/63oTsshKd
```

## Summary of Key Flags

### Essential Flags
- **`-O2`** or **`-O3`**: Enable optimizations including vectorization
- **`-qopt-report=N`**: Generate optimization report (N=1-5, higher=more detail)
- **`-qopt-report-file=stdout`**: Print report to console
- **`-qopt-report-phase=vec`**: Filter to show only vectorization info
- **`-fargument-noalias`**: Assume pointer arguments don't alias (eliminates multiversioning)
- **`-S`**: Generate assembly code

### Architecture Selection

**Single-version flags (smallest binary, target CPU only):**
- **`-xHost`**: Optimize for current CPU
- **`-march=core-avx2`**: AVX2 (GCC-compatible)
- **`-xCORE-AVX2`**: AVX2 (Intel-specific)
- **`-march=skylake-avx512`**: AVX-512
- **`-xCORE-AVX512`**: AVX-512 (Intel-specific)

**Auto-dispatch flags (larger binary, multi-CPU support):**
- **`-axCORE-AVX2`**: Baseline (SSE2) + AVX2
- **`-axCORE-AVX512`**: Baseline + AVX-512
- **`-axCORE-AVX2,CORE-AVX512`**: Baseline + AVX2 + AVX-512 (multiple targets)

## Resources

- **Intel® oneAPI DPC++/C++ Compiler Developer Guide and Reference**: [https://www.intel.com/content/www/us/en/docs/dpcpp-cpp-compiler/developer-guide-reference/2025-2/overview.html](https://www.intel.com/content/www/us/en/docs/dpcpp-cpp-compiler/developer-guide-reference/2025-2/overview.html)
- **Compiler Explorer (Godbolt)**: [https://godbolt.org](https://godbolt.org)
- **Intel Intrinsics Guide**: [https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html](https://www.intel.com/content/www/us/en/docs/intrinsics-guide/index.html)

## Troubleshooting

**Report not showing?**
- Make sure you use `-qopt-report-file=stdout` or check for `.optrpt` file
- Verify optimization is enabled (`-O2` or `-O3`)

**Loop not vectorizing?**
- Check the report for remark `#15304` explaining why
- Try `-qopt-report=3` for more details
- Look for dependency or aliasing issues

**Wrong CPU detection with -xHost?**
- Check with `lscpu | grep -i flags` to see CPU features
- Manually specify with `-march=` if needed

## Conclusion

**Exercise 1 - What you learned:**
1. ✅ Compile with vectorization enabled (`-O2 -xHost`)
2. ✅ Generate optimization reports (`-qopt-report=3`)
3. ✅ Understand loop multiversioning
4. ✅ Interpret vectorization success and speedup estimates
5. ✅ Eliminate multiversioning with `-fargument-noalias`
6. ✅ Identify performance issues from vector length analysis
7. ✅ Fix implicit type conversions that limit vectorization
8. ✅ Compare ICC (Classic) vs ICX (modern LLVM-based) compilers
9. ✅ Use Compiler Explorer for online experimentation

**Key insights from Exercise 1:** 
- The compiler created multiple versions of the loop and estimated a **~4x speedup** through vectorization, processing **4 floats at once** instead of one at a time.
- Using **`-fargument-noalias`** eliminates multiversioning by telling the compiler that pointer arguments don't overlap, producing more efficient code when this assumption is safe.
- **Implicit type conversions** (double constant with float arrays) can reduce vector width by half.
- Optimization reports reveal hidden performance problems - adding a single **'f'** character doubled the vector width from **4 to 8 elements** and improved speedup from **~4x to ~7.3x**.
- **ICC vs ICX**: Both compilers vectorize similarly and both benefit from proper type usage, but they use different cost models resulting in different speedup estimates (ICC: ~5.4x→10.6x, ICX: ~4x→7.3x). Both show ~2x improvement with proper float types.
- **Compiler estimates ≠ actual performance**: Don't rely solely on speedup estimates—always benchmark on real hardware.
- Always match constant types to your data types in performance-critical code!

**Exercise 2 - What you learned:**
1. ✅ Understand differences between `-march`, `-x`, and `-ax` flags
2. ✅ Compare binary sizes across architecture targeting options
3. ✅ Generate and analyze assembly listings
4. ✅ Identify multi-version code generation with `-ax`
5. ✅ Choose appropriate flags based on deployment scenario

**Key insights from Exercise 2:**
- **`-march` and `-x`** produce single-version binaries optimized for specific CPUs
- **`-ax`** creates multiple code versions with runtime CPU detection (auto-dispatch)
- Single-version code is smaller but may crash on older CPUs (Illegal Instruction with -m)
- Auto-dispatch code is larger but runs optimally on any CPU
- Assembly analysis shows dispatcher functions and multiple implementation variants with `-ax`
- Choose based on deployment: homogeneous cluster (use `-x`) vs. distributed software (use `-ax`)

**Exercise 3 - What you learned:**
1. ✅ Understand loop-carried dependencies and vectorization challenges
2. ✅ Compare ICC (aggressive) vs ICX (conservative) vectorization strategies
3. ✅ Use `#pragma omp simd` to force vectorization
4. ✅ Analyze optimization reports to see compiler decisions
5. ✅ Verify vectorization through assembly inspection

**Key insights from Exercise 3:**
- **Loop dependencies** can prevent automatic vectorization even when it would be safe
- **ICC (Classic)** uses aggressive multiversioning with runtime checks for safety
- **ICX (LLVM-based)** is more conservative and often requires explicit pragma guidance
- **`#pragma omp simd`** tells the compiler "trust me, this is vectorizable"
- **Backward dependencies** (x < 0) are vectorizable; **forward dependencies** (x > 0) are not
- **Programmer responsibility**: Using SIMD pragmas incorrectly can cause wrong results!
- OpenMP SIMD pragmas are becoming essential for optimal performance with modern compilers

**Exercise 4 - What you learned:**
1. ✅ Understand the difference between inner and outer loop vectorization
2. ✅ Recognize when outer loop vectorization is beneficial
3. ✅ Use compile-time constants to enable outer loop vectorization
4. ✅ Analyze optimization reports for outer loop vectorization markers
5. ✅ Understand the performance benefits of known trip counts

**Key insights from Exercise 4:**
- **Outer loop vectorization** processes multiple outer iterations simultaneously
- **Small fixed inner loops** (2-10 iterations) are ideal candidates
- **Known trip counts** enable the compiler to unroll inner loops and vectorize outer loops
- **3D data** (x, y, z) is a perfect use case with MYDIM=3
- Outer loop vectorization achieves **4-8x speedup** for typical 3D workloads
- Common in **scientific computing**: graphics, physics, image processing
- Use **`#define`** or **`constexpr`** to make dimensions known at compile time
- Variable trip counts prevent outer loop vectorization (requires SIMD pragmas)

**Exercise 5 - What you learned:**
1. ✅ Measure real-world performance of different vectorization strategies
2. ✅ Compare baseline vs optimized performance with actual benchmarks
3. ✅ Understand impact of different ISA levels (AVX, AVX2, AVX-512)
4. ✅ Quantify benefits of FMA instructions and wider registers
5. ✅ Identify CPU architecture from /proc/cpuinfo
6. ✅ Interpret throughput metrics (million operations/sec, GFLOPS)

**Key insights from Exercise 5:**
- **Vectorization delivers real speedups**: 2-4x from basic vectorization (V1-AVX vs baseline)
- **Outer loop vectorization outperforms inner**: V2 and V3 show better performance than V1
- **Known trip counts matter**: V3 (outer + inner unrolled) faster than V2 (outer only)
- **FMA instructions boost performance**: AVX2 with FMA significantly faster than plain AVX
- **512-bit registers help**: AVX-512 processes 16 floats at once vs 8 for AVX2
- **Memory bandwidth limits**: Wider vectors need more memory bandwidth to stay efficient
- **Frequency throttling**: AVX-512 may cause CPU frequency reduction on some processors
- **Benchmark before optimizing**: Actual speedups vary by CPU, problem size, and memory access patterns

**Exercise 6 - What you learned:**
1. ✅ Recognize special loop patterns (idioms) like compress/expand
2. ✅ Understand AVX-512 specialized instructions (vcompresspd)
3. ✅ Identify ISA limitations (AVX2 cannot vectorize compress patterns)
4. ✅ Analyze assembly to verify instruction usage
5. ✅ Compare performance of vectorized vs scalar compress operations
6. ✅ Understand data-dependent write patterns

**Key insights from Exercise 6:**
- **Compress pattern**: Conditional store with data-dependent write position (`if (a[i] > 0) b[nb++] = a[i]`)
- **AVX-512 special instruction**: `vcompresspd` stores selected elements contiguously based on mask
- **AVX2 limitation**: No compress instruction, compiler cannot auto-vectorize this pattern
- **Pattern recognition**: Compiler automatically recognizes simple compress patterns with AVX-512
- **No pragmas needed**: Unlike complex patterns, simple compress auto-vectorizes
- **Typical speedup**: 2-4x with AVX-512 depending on selectivity (% of elements passing condition)
- **Selectivity impact**: Performance gain increases with higher selectivity (50-90% optimal)
- **Other AVX-512 idioms**: expand, conflict detection, population count all benefit from specialized instructions
- **ISA matters**: Some algorithms require specific instruction set features to vectorize efficiently
