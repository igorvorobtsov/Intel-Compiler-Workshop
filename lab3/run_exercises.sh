#!/bin/bash
# Script to run all exercises for the Vectorization lab

# Note: Not using 'set -e' to allow exercises to continue even if one fails

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Function to print section headers
print_header() {
    echo ""
    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}$1${NC}"
    echo -e "${BLUE}========================================${NC}"
}

# Function to run command and show it
run_cmd() {
    echo -e "${YELLOW}Command:${NC} $1"
    echo ""
    eval "$1" || true
    echo ""
}

# Function to setup ICX environment
setup_icx() {
    module unload intel/2023.2.1 2>/dev/null || true
    module switch stack stack/24.6.0 2>/dev/null
    module load intel/2025.3.0 2>/dev/null
}

# Function to setup ICC environment
setup_icc() {
    module unload intel/2025.3.0 2>/dev/null || true
    module switch stack stack/23.1.0 2>/dev/null
    module load intel/2023.2.1 2>/dev/null
}

# Function to show code being compiled
show_code() {
    local file=$1
    local highlight_start=$2
    local highlight_end=$3
    echo -e "${BLUE}Code being compiled ($file):${NC}"

    if [ -n "$highlight_start" ] && [ -n "$highlight_end" ]; then
        # Highlight a range of lines
        cat -n "$file" | awk -v start="$highlight_start" -v end="$highlight_end" \
            '{if (NR >= start && NR <= end) print ">>> " $0; else print $0}'
    elif [ -n "$highlight_start" ]; then
        # Highlight a single line
        cat -n "$file" | awk -v line="$highlight_start" \
            '{if (NR == line) print ">>> " $0; else print $0}'
    else
        # No highlighting
        cat -n "$file"
    fi
    echo ""
}

# Check if exercise number is provided
if [ $# -eq 0 ]; then
    echo "Usage: $0 <exercise_number>"
    echo ""
    echo "Available exercises:"
    echo "  1 - Loop multiversioning and vectorization analysis (ICX + ICC comparison)"
    echo "  2 - Architecture-specific optimization flags (-m, -x, -ax)"
    echo "  3 - OpenMP SIMD pragmas and loop dependencies (ICC vs ICX)"
    echo "  4 - Outer loop vectorization with known trip counts"
    echo "  5 - Performance benchmarking"
    echo "  6 - Special idioms - compress loop pattern (AVX-512)"
    echo "  all - Run all exercises"
    exit 1
fi

EXERCISE=$1

# Exercise 1: Loop multiversioning and vectorization
if [ "$EXERCISE" == "1" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 1: Loop Multiversioning and Vectorization"

    show_code "vec_sin.cpp"

    setup_icx

    echo -e "${GREEN}=== Compile with optimization report (using icpx for C++) ===${NC}"
    run_cmd "icpx -g -O2 -xHost -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Key Points to Notice in the Report:${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "• ${GREEN}LOOP WAS VECTORIZED${NC}: The loop was successfully converted to SIMD operations"
    echo -e "• ${GREEN}LOOP WAS MULTIVERSIONED${NC}: Compiler created multiple versions (scalar + vector)"
    echo -e "• ${GREEN}vector length 4${NC}: Processing 4 floats at once"
    echo -e "• ${GREEN}estimated potential speedup: ~4x${NC}: Expected performance improvement"
    echo ""
    echo -e "${YELLOW}Question: Why did the compiler multiversion this loop?${NC}"
    echo -e "${BLUE}Answer: Uncertainty about pointer aliasing between 'theta' and 'sth'${NC}"
    echo -e "${BLUE}        The compiler doesn't know if they might overlap in memory.${NC}"
    echo ""

    echo -e "${GREEN}=== Now let's eliminate multiversioning with -fargument-noalias ===${NC}"
    echo -e "${BLUE}This flag tells the compiler: \"pointer arguments do NOT alias\"${NC}"
    echo ""
    run_cmd "icpx -g -O2 -xHost -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}What Changed?${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "• ${GREEN}LOOP WAS VECTORIZED${NC}: Still present ✓"
    echo -e "• ${RED}LOOP WAS MULTIVERSIONED${NC}: GONE! ✗"
    echo ""
    echo -e "${YELLOW}Why did multiversioning disappear?${NC}"
    echo -e "The ${GREEN}-fargument-noalias${NC} flag tells the compiler:"
    echo -e "  \"Pointer arguments do NOT alias (overlap in memory)\""
    echo ""
    echo -e "${BLUE}Without -fargument-noalias:${NC}"
    echo -e "  Compiler: \"theta and sth might overlap, need runtime checks\""
    echo -e "  Result: Creates multiple versions (scalar + vector)"
    echo ""
    echo -e "${BLUE}With -fargument-noalias:${NC}"
    echo -e "  Compiler: \"theta and sth are guaranteed separate\""
    echo -e "  Result: Creates only vector version (faster, smaller code)"
    echo ""
    echo -e "${RED}⚠️  Warning:${NC} Only use -fargument-noalias when pointers NEVER overlap!"
    echo -e "   Using it incorrectly can produce wrong results."
    echo ""
    echo -e "${GREEN}✓ From now on, we'll keep using -fargument-noalias to avoid multiversioning overhead${NC}"
    echo ""

    echo -e "${GREEN}=== Compile with -xCORE-AVX512 to analyze vector length ===${NC}"
    echo -e "${BLUE}(keeping -fargument-noalias for cleaner vectorization)${NC}"
    echo ""
    echo -e "${YELLOW}Note about -xCORE-AVX512:${NC}"
    echo -e "  • Enables AVX-512 instruction set support"
    echo -e "  • Uses ${GREEN}256-bit YMM registers${NC} by default (not 512-bit ZMM)"
    echo -e "  • For 512-bit ZMM use: ${GREEN}-mprefer-vector-width=512${NC} (clang-based option)"
    echo -e "  • Or use: ${GREEN}-qopt-zmm-usage=high${NC} (legacy ICC option, still accepted by ICX)"
    echo -e "  • Why YMM default? Compatibility and avoiding frequency throttling"
    echo ""
    run_cmd "icpx -g -O2 -xCORE-AVX512 -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Performance Problem Detected!${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${RED}Vector length: 4${NC} (should be 8 for floats with 256-bit YMM registers!)"
    echo ""
    echo -e "${YELLOW}Why only 4 instead of 8?${NC}"
    echo -e "The constant ${RED}3.1415927${NC} is a ${RED}double (64-bit)${NC} by default in C"
    echo -e "This forces the entire computation to use double precision:"
    echo -e "  1. float → double conversion"
    echo -e "  2. double + double addition"
    echo -e "  3. sin(double) - double precision"
    echo -e "  4. double → float conversion"
    echo ""
    echo -e "${BLUE}Result:${NC} Only 4 doubles fit in 256-bit registers (not 8 floats)"
    echo -e "${BLUE}Estimated speedup:${NC} ~4x (limited by double precision)"
    echo ""

    echo -e "${GREEN}=== Using vec_sin_fixed.cpp with float constant ===${NC}"
    echo -e "${BLUE}The fixed version is already provided with the 'f' suffix${NC}"
    echo ""

    show_code "vec_sin_fixed.cpp" 5 5

    echo -e "${GREEN}=== Compile fixed version ===${NC}"
    echo -e "${BLUE}(using icpx with -fargument-noalias + -xCORE-AVX512 + float constant)${NC}"
    run_cmd "icpx -g -O2 -xCORE-AVX512 -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin_fixed.cpp -c"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Performance Comparison${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}Original (3.1415927):${NC}"
    echo -e "  • Constant type: ${RED}double (64-bit)${NC}"
    echo -e "  • Vector length: ${RED}4${NC} (double precision)"
    echo -e "  • Scalar cost: ${RED}48.000000${NC} cycles"
    echo -e "  • Vector cost: ${RED}12.062500${NC} cycles"
    echo -e "  • Estimated speedup: ${RED}~4x${NC}"
    echo ""
    echo -e "${YELLOW}Fixed (3.1415927f):${NC}"
    echo -e "  • Constant type: ${GREEN}float (32-bit)${NC}"
    echo -e "  • Vector length: ${GREEN}8${NC} (single precision)"
    echo -e "  • Scalar cost: ${GREEN}31.000000${NC} cycles"
    echo -e "  • Vector cost: ${GREEN}4.203125${NC} cycles"
    echo -e "  • Estimated speedup: ${GREEN}~7.3x${NC}"
    echo ""
    echo -e "${GREEN}Performance improvement: Nearly 2x better speedup (4x → 7.3x) with proper float types!${NC}"
    echo ""
    echo -e "${BLUE}Key lesson:${NC} Optimization reports help identify hidden issues"
    echo -e "like implicit type conversions. A simple 'f' suffix improved speedup from ~4x to ~7.3x!"
    echo ""
    echo -e "${YELLOW}Try it online:${NC} https://godbolt.org/z/6nc7Eqcda"
    echo ""

    echo -e "${GREEN}=== Bonus: Compare with ICC (Classic Compiler) ===${NC}"
    echo -e "${BLUE}Let's see how ICC handles the original code (without -fargument-noalias)${NC}"
    echo ""

    setup_icc

    echo -e "${YELLOW}ICC version:${NC}"
    icc --version 2>&1 | head -1
    echo ""

    echo -e "${GREEN}Compiling original vec_sin.cpp with ICC:${NC}"
    echo -e "${BLUE}Using icc (note: icpc is equivalent for C++, but icc works for both)${NC}"
    run_cmd "icc -g -O2 -xHost -qopt-report=3 -qopt-report-file=stdout vec_sin.cpp -c"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}ICC vs ICX Comparison${NC}"
    echo -e "${BLUE}========================================${NC}"

    echo -e "${YELLOW}ICX (without -fargument-noalias):${NC}"
    echo -e "  • ${GREEN}LOOP WAS VECTORIZED${NC}"
    echo -e "  • ${YELLOW}LOOP WAS MULTIVERSIONED${NC}"
    echo -e "  • ${BLUE}Strategy:${NC} Runtime checks for pointer aliasing"
    echo -e "  • ${BLUE}Vector length:${NC} 4 (double precision due to constant type)"
    echo -e "  • ${BLUE}Speedup estimate:${NC} ~4x (scalar: 48, vector: 12.06)"
    echo ""

    echo -e "${YELLOW}ICC (Classic):${NC}"
    echo -e "  • ${GREEN}LOOP WAS VECTORIZED${NC}"
    echo -e "  • ${YELLOW}LOOP WAS MULTIVERSIONED${NC}"
    echo -e "  • ${BLUE}Strategy:${NC} Similar multiversioning approach"
    echo -e "  • ${BLUE}Vector length:${NC} Also 4 (same type conversion issue)"
    echo -e "  • ${BLUE}Speedup estimate:${NC} ~5.4x (scalar: 111, vector: 20.370)"
    echo -e "  • ${YELLOW}Note:${NC} ICC shows higher speedup estimates (different cost model)"
    echo ""

    echo -e "${GREEN}Key Insight:${NC}"
    echo -e "Both ICC and ICX multiversion for safety when pointer aliasing is uncertain."
    echo -e "The ${GREEN}-fargument-noalias${NC} flag eliminates this overhead in both compilers."
    echo -e "ICC and ICX use ${YELLOW}different cost models${NC}, so speedup estimates vary."
    echo ""

    echo -e "${YELLOW}Now compile the fixed version with ICC:${NC}"
    run_cmd "icc -g -O2 -xCORE-AVX512 -fargument-noalias -qopt-report=3 -qopt-report-file=stdout vec_sin_fixed.cpp -c"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}ICC with Fixed Version Results${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Look for in the report:"
    echo -e "  • ${GREEN}Vector length: 8${NC} (float constant enables full YMM register usage!)"
    echo -e "  • ${GREEN}No multiversioning${NC} (using -fargument-noalias)"
    echo -e "  • ${GREEN}~10.6x speedup estimate${NC} (scalar: 109, vector: 10.25)"
    echo -e "  • ${YELLOW}Note:${NC} ICC uses YMM (256-bit) by default even with -xCORE-AVX512"
    echo -e "  • ${YELLOW}Remark #26013:${NC} Suggests using -qopt-zmm-usage=high for 512-bit ZMM"
    echo ""

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}ICC vs ICX Summary${NC}"
    echo -e "${GREEN}========================================${NC}"

    echo -e "${YELLOW}Similarities:${NC}"
    echo -e "  • Both ${GREEN}vectorize and multiversion${NC} for pointer aliasing safety"
    echo -e "  • Both benefit from ${GREEN}proper type usage${NC} (adding 'f' suffix)"
    echo -e "  • Both support ${GREEN}-fargument-noalias${NC} to eliminate multiversioning"
    echo -e "  • Both achieve ${GREEN}2x throughput${NC} increase (vector length 4 → 8)"
    echo ""

    echo -e "${YELLOW}Differences:${NC}"
    echo -e "  • ${BLUE}Cost models differ:${NC} ICC shows higher speedup estimates"
    echo -e "  • ${BLUE}ICX (original):${NC} scalar cost 48, vector cost 12.06, speedup ~4x"
    echo -e "  • ${BLUE}ICX (fixed):${NC} scalar cost 31, vector cost 4.20, speedup ~7.3x"
    echo -e "  • ${BLUE}ICC (original):${NC} scalar cost 111, vector cost 20.37, speedup ~5.4x"
    echo -e "  • ${BLUE}ICC (fixed):${NC} scalar cost 109, vector cost 10.25, speedup ~10.6x"
    echo -e "  • ${YELLOW}Estimates vary${NC}, but the improvement ratio is similar!"
    echo ""

    echo -e "${GREEN}Key Takeaway:${NC}"
    echo -e "The type conversion issue (double vs float) affects ${RED}both compilers${NC}."
    echo -e "Both compilers show ${GREEN}significant improvement${NC} with proper float types!"
    echo -e "Always use matching types for optimal vectorization!"
    echo ""

    echo -e "${BLUE}Switching back to ICX for remaining exercises...${NC}"
    setup_icx
    echo ""
fi

# Exercise 2: Architecture-specific optimization flags
if [ "$EXERCISE" == "2" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 2: Architecture-Specific Optimization Flags (-m, -x, -ax)"

    echo -e "${BLUE}Using vec_sin_fixed.cpp (vectorized function) + vec_sin_main.cpp (main program)${NC}"
    echo ""
    show_code "vec_sin_fixed.cpp"
    echo ""
    echo -e "${BLUE}Main program (vec_sin_main.cpp) - declaration only${NC}"
    show_code "vec_sin_main.cpp" 1 5

    setup_icx

    echo -e "${GREEN}=== Compile with -mavx2 (generic optimization, no CPU check) ===${NC}"
    echo -e "${BLUE}Generic: Optimized for both Intel and non-Intel (AMD) processors${NC}"
    run_cmd "icpx -O2 -mavx2 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_m"

    echo -e "${GREEN}=== Compile with -xCORE-AVX2 (Intel-specific optimization, with CPU check) ===${NC}"
    echo -e "${BLUE}Intel-specific: May use Intel processor-specific optimizations${NC}"
    run_cmd "icpx -O2 -xCORE-AVX2 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_x"

    echo -e "${GREEN}=== Compile with -axCORE-AVX2 (auto-dispatch with CPUID) ===${NC}"
    run_cmd "icpx -O2 -axCORE-AVX2 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_ax"

    echo -e "${GREEN}=== Compile with multiple auto-dispatch targets ===${NC}"
    run_cmd "icpx -O2 -axCORE-AVX2,CORE-AVX512 vec_sin_fixed.cpp vec_sin_main.cpp -o vec_sin_ax_multi"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Binary Size Comparison${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}Command:${NC} ls -lh vec_sin_m vec_sin_x vec_sin_ax vec_sin_ax_multi"
    echo ""
    ls -lh vec_sin_m vec_sin_x vec_sin_ax vec_sin_ax_multi 2>/dev/null | awk '{printf "%-20s %10s\n", $9, $5}'
    echo ""
    echo -e "${BLUE}Notice:${NC}"
    echo -e "• ${GREEN}-m and -x${NC} produce similar-sized binaries (single version)"
    echo -e "• ${YELLOW}-ax${NC} is slightly larger (includes SSE2 baseline + AVX2 optimized)"
    echo -e "• ${YELLOW}-ax with multiple targets${NC} is largest, but only slightly more"
    echo -e "  (each code version is small for simple functions)"
    echo ""

    echo -e "${GREEN}=== Generate assembly to check for CPU detection ===${NC}"
    echo -e "${BLUE}Checking main program for CPU checks, not the vectorized function${NC}"
    run_cmd "icpx -O2 -mavx2 -S vec_sin_main.cpp -o vec_sin_m.s"
    run_cmd "icpx -O2 -xCORE-AVX2 -S vec_sin_main.cpp -o vec_sin_x.s"
    run_cmd "icpx -O2 -axCORE-AVX2 -S vec_sin_main.cpp -o vec_sin_ax.s"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}CPU Feature Initialization Check${NC}"
    echo -e "${BLUE}========================================${NC}"

    echo -e "${YELLOW}Checking for __intel_new_feature_proc_init call in assembly:${NC}"
    echo ""

    echo -e "${GREEN}With -mavx2 (no CPU check):${NC}"
    INIT_M=$(grep "__intel_new_feature_proc_init" vec_sin_m.s 2>/dev/null | wc -l)
    echo "  __intel_new_feature_proc_init calls: $INIT_M"
    if [ "$INIT_M" -eq 0 ]; then
        echo -e "  ${GREEN}✓ No feature initialization - code runs directly${NC}"
        echo -e "  ${RED}⚠ Will CRASH on old CPU (Illegal Instruction)${NC}"
    fi
    echo ""

    echo -e "${GREEN}With -x (CPU check in main):${NC}"
    INIT_X=$(grep "__intel_new_feature_proc_init" vec_sin_x.s 2>/dev/null | wc -l)
    echo "  __intel_new_feature_proc_init calls: $INIT_X"
    if [ "$INIT_X" -gt 0 ]; then
        echo -e "  ${GREEN}✓ Feature initialization added to main()${NC}"
        echo -e "  ${GREEN}✓ Will EXIT GRACEFULLY on old CPU${NC}"
        grep "__intel_new_feature_proc_init" vec_sin_x.s 2>/dev/null | head -1 | sed 's/^/  Assembly: /'
    fi
    echo ""

    echo -e "${GREEN}With -ax (CPU check for dispatch):${NC}"
    INIT_AX=$(grep "__intel_new_feature_proc_init" vec_sin_ax.s 2>/dev/null | wc -l)
    echo "  __intel_new_feature_proc_init calls: $INIT_AX"
    if [ "$INIT_AX" -gt 0 ]; then
        echo -e "  ${GREEN}✓ Feature initialization for runtime dispatch${NC}"
        echo -e "  ${GREEN}✓ Will RUN BASELINE version on old CPU${NC}"
        grep "__intel_new_feature_proc_init" vec_sin_ax.s 2>/dev/null | head -1 | sed 's/^/  Assembly: /'
    fi
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Key Differences: -m vs -x vs -ax${NC}"
    echo -e "${BLUE}========================================${NC}"

    echo -e "${YELLOW}-mavx2 (generic optimization):${NC}"
    echo -e "  ✅ Optimized for ${GREEN}both Intel AND non-Intel${NC} processors (AMD, etc.)"
    echo -e "  ✅ Portable SIMD optimization"
    echo -e "  ✅ No CPU check - smallest binary"
    echo -e "  ❌ ${RED}Will CRASH on incompatible CPUs${NC}"
    echo -e "  ❌ May not use Intel-specific optimizations"
    echo ""

    echo -e "${YELLOW}-xCORE-AVX2 (Intel-specific optimization):${NC}"
    echo -e "  ✅ ${GREEN}Intel processor-specific${NC} optimizations"
    echo -e "  ✅ May use Intel-specific instruction scheduling"
    echo -e "  ✅ CPU check added - ${GREEN}graceful exit${NC} on old Intel CPUs"
    echo -e "  ❌ ${RED}Will NOT run on AMD/non-Intel processors${NC} (Intel vendor check)"
    echo ""
    echo -e "${YELLOW}Use -ax when:${NC}"
    echo -e "  ✅ Distributing software to users with different CPUs"
    echo -e "  ✅ Need both compatibility AND performance"
    echo -e "  ✅ ${GREEN}Always runs${NC} - selects best available version"
    echo -e "  ✅ Slightly larger binary (but worth it!)"
    echo ""

    echo -e "${GREEN}=== Test the binaries ===${NC}"
    echo -e "${YELLOW}Running -m version:${NC}"
    ./vec_sin_m 2>&1 || echo -e "${RED}Failed to run (CPU may not support AVX2 - Illegal Instruction)${NC}"
    echo ""
    echo -e "${YELLOW}Running -x version:${NC}"
    ./vec_sin_x 2>&1 || echo -e "${YELLOW}Exited gracefully (CPU check failed)${NC}"
    echo ""
    echo -e "${YELLOW}Running -ax version:${NC}"
    ./vec_sin_ax 2>&1 || echo -e "${RED}Failed to run${NC}"
    echo ""
fi

# Exercise 3: OpenMP SIMD pragmas
if [ "$EXERCISE" == "3" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 3: OpenMP SIMD Pragmas and Loop Dependencies (ICC vs ICX)"

    show_code "addit.c"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}The Challenge${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "This loop has a ${YELLOW}loop-carried dependency${NC}:"
    echo -e "  a[i] = b[i] + a[i-x]"
    echo -e ""
    echo -e "• If ${RED}x > 0${NC}: Forward dependency (cannot vectorize)"
    echo -e "• If ${GREEN}x < 0${NC}: Backward dependency (safe to vectorize)"
    echo -e "• Compiler ${YELLOW}doesn't know x at compile time${NC}"
    echo ""

    echo -e "${GREEN}=== Test 1: Compile with ICC (Classic Compiler) ===${NC}"
    echo -e "${BLUE}Using -qopt-report-phase=vec to show only vectorization messages${NC}"
    setup_icc
    run_cmd "icc -O2 -xHost -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout addit.c -c"

    echo -e "${BLUE}ICC Result:${NC}"
    echo -e "• ${GREEN}✅ LOOP WAS VECTORIZED${NC}"
    echo -e "• ${GREEN}✅ LOOP WAS MULTIVERSIONED${NC}"
    echo -e "• ${BLUE}Strategy:${NC} Create multiple versions with runtime checks"
    echo -e "• ${BLUE}Safe:${NC} Falls back to scalar version if x >= 0"
    echo ""

    echo -e "${GREEN}=== Test 2: Compile with ICX (LLVM-based Compiler) ===${NC}"
    echo -e "${BLUE}Using -qopt-report-phase=vec to minimize output${NC}"
    setup_icx
    run_cmd "icx -O2 -xHost -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout addit.c -c"

    echo -e "${RED}ICX Result:${NC}"
    echo -e "• ${RED}❌ loop was not vectorized: vector dependence prevents vectorization${NC}"
    echo -e "• ${RED}❌ No multiversioning${NC}"
    echo -e "• ${BLUE}Strategy:${NC} Conservative - refuses to vectorize without guidance"
    echo -e "• ${YELLOW}Needs programmer help via pragmas${NC}"
    echo ""

    echo -e "${GREEN}=== Test 3: ICX with #pragma omp simd ===${NC}"
    show_code "addit_omp.c" 4 5

    run_cmd "icx -O2 -xHost -qopenmp -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout addit_omp.c -c"

    echo -e "${GREEN}ICX with pragma Result:${NC}"
    echo -e "• ${GREEN}✅ OpenMP SIMD LOOP WAS VECTORIZED${NC}"
    echo -e "• ${GREEN}✅ vector length 4${NC} (4 doubles at once)"
    echo -e "• ${BLUE}Strategy:${NC} Trust programmer's assertion"
    echo -e "• ${YELLOW}No runtime checks${NC} - direct vectorization"
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Comparison Summary${NC}"
    echo -e "${BLUE}========================================${NC}"

    echo -e "${YELLOW}ICC (addit.c):${NC}"
    echo -e "  • Vectorized: ${GREEN}YES${NC}"
    echo -e "  • Multiversioned: ${GREEN}YES${NC}"
    echo -e "  • Runtime checks: ${GREEN}YES${NC}"
    echo -e "  • Safe for any x: ${GREEN}YES${NC}"
    echo ""

    echo -e "${YELLOW}ICX (addit.c):${NC}"
    echo -e "  • Vectorized: ${RED}NO${NC}"
    echo -e "  • Strategy: ${RED}Conservative${NC}"
    echo -e "  • Needs: ${YELLOW}Pragma guidance${NC}"
    echo ""

    echo -e "${YELLOW}ICX (addit_omp.c with #pragma omp simd):${NC}"
    echo -e "  • Vectorized: ${GREEN}YES${NC}"
    echo -e "  • Multiversioned: ${RED}NO${NC}"
    echo -e "  • Runtime checks: ${RED}NO${NC}"
    echo -e "  • Safe for any x: ${RED}NO - programmer must ensure x < 0${NC}"
    echo ""

    echo -e "${GREEN}=== Build complete programs ===${NC}"

    setup_icc
    run_cmd "icc -O2 -xHost addit.c addit_main.c -o addit_icc"

    setup_icx
    run_cmd "icx -O2 -xHost addit.c addit_main.c -o addit_icx_scalar"
    run_cmd "icx -O2 -xHost -qopenmp addit_omp.c addit_main.c -o addit_icx_simd"

    echo -e "${GREEN}=== Generate assembly for inspection ===${NC}"

    setup_icc
    run_cmd "icc -O2 -xHost -S addit.c -o addit_icc.s"

    setup_icx
    run_cmd "icx -O2 -xHost -S addit.c -o addit_icx_scalar.s"
    run_cmd "icx -O2 -xHost -qopenmp -S addit_omp.c -o addit_icx_simd.s"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}SIMD Instructions Check${NC}"
    echo -e "${BLUE}========================================${NC}"

    echo -e "${YELLOW}ICC assembly (should have SIMD):${NC}"
    grep -E "vmovupd|vaddpd" addit_icc.s | wc -l | xargs -I {} echo "  SIMD instructions found: {}"

    echo -e "${YELLOW}ICX scalar assembly (should have few/no SIMD):${NC}"
    grep -E "vmovupd|vaddpd" addit_icx_scalar.s | wc -l | xargs -I {} echo "  SIMD instructions found: {}"

    echo -e "${YELLOW}ICX with pragma assembly (should have SIMD):${NC}"
    grep -E "vmovupd|vaddpd" addit_icx_simd.s | wc -l | xargs -I {} echo "  SIMD instructions found: {}"
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Key Lessons${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "• ${GREEN}ICC${NC}: Aggressive auto-vectorization with runtime safety"
    echo -e "• ${GREEN}ICX${NC}: Conservative, requires explicit guidance"
    echo -e "• ${GREEN}#pragma omp simd${NC}: Forces vectorization (use carefully!)"
    echo -e "• ${RED}Warning:${NC} Using pragma incorrectly can cause wrong results!"
    echo -e "• ${YELLOW}Always verify:${NC} x < 0 for this specific loop"
    echo ""
    echo -e "${YELLOW}Try it online:${NC} https://godbolt.org/z/x8TxG56Gr"
    echo ""
fi

# Exercise 4: Outer loop vectorization
if [ "$EXERCISE" == "4" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 4: Outer Loop Vectorization - Three Approaches"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}The Concept${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "Nested loops can be vectorized in two ways:"
    echo -e "• ${YELLOW}Inner loop vectorization${NC}: SIMD within each outer iteration"
    echo -e "• ${YELLOW}Outer loop vectorization${NC}: SIMD across multiple outer iterations"
    echo ""
    echo -e "We'll use ${GREEN}a single source file (dist.c)${NC} with preprocessor macros:"
    echo -e "• Macros ${YELLOW}(-DUSE_OMP_SIMD, -DKNOWN_TRIP_COUNT)${NC} create different effective source code"
    echo -e "• Same file for convenience, but ${BLUE}different code after preprocessing${NC}"
    echo ""
    echo -e "Three compilation variants:"
    echo -e "  ${GREEN}V1:${NC} No macros → inner loop vectorized"
    echo -e "  ${GREEN}V2:${NC} -DUSE_OMP_SIMD → outer loop vectorized"
    echo -e "  ${GREEN}V3:${NC} -DUSE_OMP_SIMD + -DKNOWN_TRIP_COUNT → outer vectorized + inner unrolled"
    echo ""

    setup_icx

    echo -e "${GREEN}=== dist.c source (single file, macro-based variants) ===${NC}"
    show_code "dist.c" 1 18
    echo -e "${BLUE}Preprocessor macros create different effective source code:${NC}"
    echo -e "  • ${YELLOW}-DUSE_OMP_SIMD${NC} includes/excludes #pragma omp simd"
    echo -e "  • ${YELLOW}-DKNOWN_TRIP_COUNT${NC} sets MYDIM to constant (3) or variable (nd)"
    echo ""

    echo -e "${GREEN}=== Version 1: No pragma (no -DUSE_OMP_SIMD, inner loop) ===${NC}"
    echo -e "${BLUE}Compilation: No -DUSE_OMP_SIMD, MYDIM=nd (variable)${NC}"
    run_cmd "icx -O2 -xHost -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout dist.c -c"

    echo -e "${BLUE}Result:${NC}"
    echo -e "• ${GREEN}✅ Inner loop WAS vectorized${NC} (with multiversioning)"
    echo -e "• ${RED}❌ Outer loop NOT vectorized${NC} (no pragma in code)"
    echo -e "• ${YELLOW}Compiler suggests SIMD directive${NC}"
    echo ""

    echo -e "${GREEN}=== Version 2: With pragma (-qopenmp -DUSE_OMP_SIMD, outer loop) ===${NC}"
    echo -e "${BLUE}Compilation: With -qopenmp -DUSE_OMP_SIMD, MYDIM=nd (variable)${NC}"
    run_cmd "icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout dist.c -c"

    echo -e "${GREEN}Result:${NC}"
    echo -e "• ${GREEN}✅ Outer loop WAS vectorized${NC} (pragma now in code)"
    echo -e "• ${YELLOW}Inner loop:${NC} Part of vectorized computation"
    echo -e "• ${BLUE}Note:${NC} No private clause needed (d, t declared inside loop)"
    echo ""

    echo -e "${GREEN}=== Version 3: Pragma + known trip count (-qopenmp -DUSE_OMP_SIMD + -DKNOWN_TRIP_COUNT) ===${NC}"
    echo -e "${BLUE}Compilation: With -qopenmp -DUSE_OMP_SIMD, MYDIM=3 (constant)${NC}"
    echo -e "${BLUE}Using -qopt-report-phase=vec,loop to see both vectorization and loop unrolling${NC}"
    run_cmd "icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT -qopt-report=3 -qopt-report-phase=vec,loop -qopt-report-file=stdout dist.c -c"

    echo -e "${GREEN}Result:${NC}"
    echo -e "• ${GREEN}✅ OUTER LOOP WAS VECTORIZED${NC} (pragma active)"
    echo -e "• ${GREEN}✅ Vector length 8${NC} (processes 8 points simultaneously)"
    echo -e "• ${GREEN}✅ VLS-optimized${NC} (stride-3 access pattern optimized)"
    echo -e "• ${GREEN}✅ Inner loop fully unrolled${NC} (remark #25436: Loop completely unrolled by 3)"
    echo -e "• ${YELLOW}Best performance:${NC} Outer loop vectorized + inner loop unrolled + VLS optimization"
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}How Each Version Works${NC}"
    echo -e "${BLUE}========================================${NC}"

    echo -e "${YELLOW}Version 1 (Inner loop SIMD):${NC}"
    echo -e "  Point 0: [x₀, y₀, z₀] → SIMD operations → dist[0]"
    echo -e "  Point 1: [x₁, y₁, z₁] → SIMD operations → dist[1]"
    echo -e "  ${BLUE}One point at a time, but inner loop uses SIMD${NC}"
    echo ""

    echo -e "${YELLOW}Version 2 (Outer loop SIMD with pragma):${NC}"
    echo -e "  Process [Points 0,1,2,3] simultaneously:"
    echo -e "  [x₀,x₁,x₂,x₃], [y₀,y₁,y₂,y₃], [z₀,z₁,z₂,z₃] → [dist[0..3]]"
    echo -e "  ${GREEN}Multiple points at once (forced by pragma)${NC}"
    echo ""

    echo -e "${YELLOW}Version 3 (Outer loop SIMD automatic):${NC}"
    echo -e "  Vector: [x₀-xᵣₑf, x₁-xᵣₑf, x₂-xᵣₑf, x₃-xᵣₑf]² +"
    echo -e "          [y₀-yᵣₑf, y₁-yᵣₑf, y₂-yᵣₑf, y₃-yᵣₑf]² +"
    echo -e "          [z₀-zᵣₑf, z₁-zᵣₑf, z₂-zᵣₑf, z₃-zᵣₑf]² → √"
    echo -e "  ${GREEN}Multiple points at once (automatic!)${NC}"
    echo ""

    echo -e "${GREEN}=== Build complete programs ===${NC}"
    echo -e "${BLUE}Single source file (dist.c), three different macro configurations:${NC}"
    run_cmd "icx -O2 -xHost dist.c dist_main.c -o dist_v1"
    run_cmd "icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD dist.c dist_main.c -o dist_v2"
    run_cmd "icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_known_main.c -o dist_v3"

    echo -e "${GREEN}=== Run and verify correctness ===${NC}"
    echo -e "${YELLOW}Version 1 (inner loop):${NC}"
    ./dist_v1 2>&1
    echo ""
    echo -e "${YELLOW}Version 2 (outer loop - pragma):${NC}"
    ./dist_v2 2>&1
    echo ""
    echo -e "${YELLOW}Version 3 (outer loop - pragma + known trip count):${NC}"
    ./dist_v3 2>&1
    echo ""

    echo -e "${GREEN}=== Generate assembly for comparison ===${NC}"
    echo -e "${BLUE}Single source file, three different preprocessor configurations:${NC}"
    run_cmd "icx -O2 -xHost -S dist.c -o dist_v1.s"
    run_cmd "icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -S dist.c -o dist_v2.s"
    run_cmd "icx -O2 -xHost -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT -S dist.c -o dist_v3.s"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}SIMD Instructions Analysis${NC}"
    echo -e "${BLUE}========================================${NC}"

    V1_SIMD=$(grep -E "vmovups|vfmadd|vsqrtps" dist_v1.s 2>/dev/null | wc -l)
    V2_SIMD=$(grep -E "vmovups|vfmadd|vsqrtps" dist_v2.s 2>/dev/null | wc -l)
    V3_SIMD=$(grep -E "vmovups|vfmadd|vsqrtps" dist_v3.s 2>/dev/null | wc -l)

    echo -e "${YELLOW}Version 1 (inner loop):${NC}      $V1_SIMD SIMD instructions"
    echo -e "${YELLOW}Version 2 (OMP SIMD):${NC}        $V2_SIMD SIMD instructions"
    echo -e "${YELLOW}Version 3 (known trip count):${NC} $V3_SIMD SIMD instructions"
    echo ""

    echo -e "${GREEN}Analysis:${NC}"
    echo -e "• ${BLUE}Fewer instructions ≠ worse performance!${NC}"
    echo -e "• ${YELLOW}V1 (~42):${NC} More instructions due to multiversioning (multiple loop copies)"
    echo -e "• ${YELLOW}V2 (~59):${NC} Most instructions due to gather loads for unknown stride"
    echo -e "• ${YELLOW}V3 (~14):${NC} ${GREEN}Fewest but most efficient${NC} - VLS-optimized + fully unrolled inner loop"
    echo -e "• V3 achieves best performance with minimal instructions"
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Key Lessons${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "• ${GREEN}Version 1:${NC} Inner loop SIMD (multiversioned, no pragma)"
    echo -e "• ${GREEN}Version 2:${NC} Outer loop SIMD with #pragma omp simd (via -DUSE_OMP_SIMD)"
    echo -e "• ${GREEN}Version 3:${NC} Outer loop SIMD with pragma + -DKNOWN_TRIP_COUNT"
    echo -e "• ${YELLOW}Best choice:${NC} V3 for known trip counts (pragma + constant)"
    echo -e "• ${YELLOW}Use V2 when:${NC} Trip count variable but vectorization is safe"
    echo -e "• ${GREEN}Small fixed inner loops${NC} (2-10 iterations) enable V3 optimization"
    echo ""
    echo -e "${YELLOW}Practical applications:${NC}"
    echo -e "  • 3D graphics (x, y, z coordinates)"
    echo -e "  • Image processing (R, G, B channels)"
    echo -e "  • Physics simulations (3D force vectors)"
    echo -e "  • Machine learning (fixed-size feature vectors)"
    echo ""
fi

# Exercise 5: Performance benchmarking
if [ "$EXERCISE" == "5" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 5: Performance Benchmarking"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Goal: Measure Real Performance${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "We'll benchmark 6 versions with different optimizations:"
    echo -e "  ${GREEN}V1-O1:${NC}     No vectorization (baseline)"
    echo -e "  ${GREEN}V1-AVX:${NC}    Inner loop vectorized (256-bit)"
    echo -e "  ${GREEN}V2-AVX:${NC}    Outer loop vectorized (unknown stride)"
    echo -e "  ${GREEN}V3-AVX:${NC}    Outer loop + inner unrolled"
    echo -e "  ${GREEN}V3-AVX2:${NC}   V3 + FMA instructions"
    echo -e "  ${GREEN}V3-AVX512:${NC} V3 + 512-bit ZMM registers"
    echo ""
    echo -e "${YELLOW}Benchmark: 100 million 3D points (~1.2 GB), 10 runs averaged${NC}"
    echo ""

    setup_icx

    echo -e "${GREEN}=== Building all benchmark versions ===${NC}"
    echo ""

    echo -e "${BLUE}Building V1-O1 (baseline, no vectorization)...${NC}"
    run_cmd "icx -O1 dist.c dist_bench.c -o bench_v1_o1"

    echo -e "${BLUE}Building V1-AVX (inner loop vectorized)...${NC}"
    run_cmd "icx -O2 -xAVX dist.c dist_bench.c -o bench_v1_avx"

    echo -e "${BLUE}Building V2-AVX (outer loop vectorized, unknown stride)...${NC}"
    run_cmd "icx -O2 -xAVX -qopenmp -DUSE_OMP_SIMD dist.c dist_bench.c -o bench_v2_avx"

    echo -e "${BLUE}Building V3-AVX (outer loop + inner unrolled)...${NC}"
    run_cmd "icx -O2 -xAVX -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_bench.c -o bench_v3_avx"

    echo -e "${BLUE}Building V3-AVX2 (with FMA instructions)...${NC}"
    run_cmd "icx -O2 -xCORE-AVX2 -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_bench.c -o bench_v3_avx2"

    echo -e "${BLUE}Building V3-AVX512 (with 512-bit ZMM registers)...${NC}"
    run_cmd "icx -O2 -xCORE-AVX512 -qopt-zmm-usage=high -qopenmp -DUSE_OMP_SIMD -DKNOWN_TRIP_COUNT dist.c dist_bench.c -o bench_v3_avx512"

    echo ""
    echo -e "${GREEN}=== Running Benchmarks ===${NC}"
    echo -e "${YELLOW}This may take a minute...${NC}"
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Baseline: No Vectorization (-O1)${NC}"
    echo -e "${BLUE}========================================${NC}"
    ./bench_v1_o1 2>&1 | tee /tmp/bench_v1_o1.txt
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}V1-AVX: Inner Loop Vectorized${NC}"
    echo -e "${BLUE}========================================${NC}"
    ./bench_v1_avx 2>&1 | tee /tmp/bench_v1_avx.txt
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}V2-AVX: Outer Loop Vectorized (unknown stride)${NC}"
    echo -e "${BLUE}========================================${NC}"
    ./bench_v2_avx 2>&1 | tee /tmp/bench_v2_avx.txt
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}V3-AVX: Outer Loop + Inner Unrolled${NC}"
    echo -e "${BLUE}========================================${NC}"
    ./bench_v3_avx 2>&1 | tee /tmp/bench_v3_avx.txt
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}V3-AVX2: With FMA Instructions${NC}"
    echo -e "${BLUE}========================================${NC}"
    ./bench_v3_avx2 2>&1 | tee /tmp/bench_v3_avx2.txt
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}V3-AVX512: With 512-bit ZMM Registers${NC}"
    echo -e "${BLUE}========================================${NC}"
    ./bench_v3_avx512 2>&1 | tee /tmp/bench_v3_avx512.txt
    echo ""

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Performance Summary${NC}"
    echo -e "${GREEN}========================================${NC}"

    # Extract times and calculate speedups
    T_O1=$(grep "Average time:" /tmp/bench_v1_o1.txt | awk '{print $3}')
    T_V1=$(grep "Average time:" /tmp/bench_v1_avx.txt | awk '{print $3}')
    T_V2=$(grep "Average time:" /tmp/bench_v2_avx.txt | awk '{print $3}')
    T_V3=$(grep "Average time:" /tmp/bench_v3_avx.txt | awk '{print $3}')
    T_V3A2=$(grep "Average time:" /tmp/bench_v3_avx2.txt | awk '{print $3}')
    T_V3A512=$(grep "Average time:" /tmp/bench_v3_avx512.txt | awk '{print $3}')

    echo -e "${YELLOW}Version          Time(s)    Speedup vs Baseline${NC}"
    echo -e "V1-O1            $T_O1      1.00x (baseline)"
    if [ ! -z "$T_V1" ]; then
        SPD_V1=$(awk "BEGIN {printf \"%.2f\", $T_O1/$T_V1}")
        echo -e "V1-AVX           $T_V1      ${SPD_V1}x"
    fi
    if [ ! -z "$T_V2" ]; then
        SPD_V2=$(awk "BEGIN {printf \"%.2f\", $T_O1/$T_V2}")
        echo -e "V2-AVX           $T_V2      ${SPD_V2}x"
    fi
    if [ ! -z "$T_V3" ]; then
        SPD_V3=$(awk "BEGIN {printf \"%.2f\", $T_O1/$T_V3}")
        echo -e "V3-AVX           $T_V3      ${SPD_V3}x"
    fi
    if [ ! -z "$T_V3A2" ]; then
        SPD_V3A2=$(awk "BEGIN {printf \"%.2f\", $T_O1/$T_V3A2}")
        echo -e "V3-AVX2          $T_V3A2      ${SPD_V3A2}x"
    fi
    if [ ! -z "$T_V3A512" ]; then
        SPD_V3A512=$(awk "BEGIN {printf \"%.2f\", $T_O1/$T_V3A512}")
        echo -e "V3-AVX512        $T_V3A512      ${SPD_V3A512}x"
    fi
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Analysis: SPR Performance Results${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo ""
    echo -e "${GREEN}Expected Results on Intel Sapphire Rapids:${NC}"
    echo -e "V1-O1            0.238s       1.00x (baseline)"
    echo -e "V1-AVX           0.168s       1.41x"
    echo -e "V2-AVX           0.211s       1.13x"
    echo -e "V3-AVX           0.138s       1.72x"
    echo -e "V3-AVX2          0.115s       2.07x"
    echo -e "V3-AVX512        0.113s       2.10x"
    echo ""
    echo -e "${YELLOW}Key Observations:${NC}"
    echo ""
    echo -e "• ${YELLOW}V1-AVX beats V2-AVX${NC} (1.41x > 1.13x)"
    echo -e "  - V1 (inner loop): ${GREEN}Unit-stride loads${NC}, good cache locality"
    echo -e "  - V2 (outer loop): ${RED}Gather loads penalty${NC} (unknown stride)"
    echo -e "  - ${BLUE}Memory access pattern > vectorization strategy${NC}"
    echo ""
    echo -e "• ${GREEN}V3 versions show progressive improvement${NC}"
    echo -e "  - V3-AVX (1.72x): ${GREEN}VLS-optimized stride-3 loads${NC}"
    echo -e "  - V3-AVX2 (2.07x): FMA adds ${GREEN}~20% speedup${NC} over V3-AVX"
    echo -e "  - V3-AVX512 (2.10x): ${YELLOW}Only 1.5% faster${NC} - bandwidth limit"
    echo ""
    echo -e "• ${GREEN}FMA benefits with good memory access${NC}"
    echo -e "  - V3-AVX2 shows ${GREEN}genuine FMA advantage${NC} (~20% faster)"
    echo -e "  - Works because VLS-optimized loads reduce memory bottleneck"
    echo -e "  - ${BLUE}Good memory patterns unlock instruction benefits${NC}"
    echo ""
    echo -e "• ${RED}Memory bandwidth saturation${NC}"
    echo -e "  - V3-AVX512 minimal gain over V3-AVX2 (1.5%)"
    echo -e "  - 512-bit vectors hit bandwidth ceiling"
    echo -e "  - ${BLUE}Diminishing returns from wider vectors${NC}"
    echo ""
    echo -e "${GREEN}Key Lesson:${NC} ${YELLOW}Performance is hierarchical!${NC}"
    echo -e "1. ${BLUE}Memory access patterns${NC} (most critical)"
    echo -e "2. ${BLUE}Loop structure optimization${NC}"
    echo -e "3. ${BLUE}Instruction set features${NC} (incremental gains)"
    echo ""
    echo -e "${YELLOW}Always benchmark on target hardware!${NC}"
    echo ""
fi

# Exercise 6: Special idioms - compress loop pattern
if [ "$EXERCISE" == "6" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 6: Special Idioms - Compress Loop Pattern"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}The Concept: Compress Pattern${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "A ${YELLOW}compress loop${NC} filters elements from array based on a condition:"
    echo -e "  • Data-dependent write positions"
    echo -e "  • if (condition) output[count++] = input[i]"
    echo -e "  • Challenging to vectorize with traditional SIMD"
    echo ""
    echo -e "${GREEN}AVX-512 solution:${NC} vcompressps instruction"
    echo -e "  • Specialized instruction for compress/expand patterns"
    echo -e "  • Stores selected elements contiguously based on mask"
    echo -e "  • Not available in AVX2 or earlier"
    echo ""

    show_code "compress.c"

    setup_icx

    echo -e "${GREEN}=== Compile with AVX2 (no compress instruction) ===${NC}"
    echo -e "${BLUE}Flag: -xCORE-AVX2 (AVX2 lacks vcompress instruction)${NC}"
    run_cmd "icx -xCORE-AVX2 -O2 -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout -fargument-noalias compress.c -c"

    echo -e "${RED}Result with AVX2:${NC}"
    echo -e "• ${RED}❌ Loop NOT vectorized${NC}"
    echo -e "• ${YELLOW}Reason:${NC} Vector dependence (data-dependent write position)"
    echo -e "• ${YELLOW}Missing:${NC} AVX2 has no compress/expand instructions"
    echo -e "• ${BLUE}Generated:${NC} Scalar code with conditional branches"
    echo ""

    echo -e "${GREEN}=== Compile with AVX-512 (with vcompresspd) ===${NC}"
    echo -e "${BLUE}Flag: -xCORE-AVX512 (AVX-512 provides vcompresspd)${NC}"
    run_cmd "icx -xCORE-AVX512 -O2 -qopt-report=3 -qopt-report-phase=vec -qopt-report-file=stdout -fargument-noalias compress.c -c"

    echo -e "${GREEN}Result with AVX-512:${NC}"
    echo -e "• ${GREEN}✅ LOOP WAS VECTORIZED${NC}"
    echo -e "• ${GREEN}✅ Compress/expand pattern recognized${NC}"
    echo -e "• ${GREEN}✅ Vector length 16${NC} (16 floats at once)"
    echo -e "• ${BLUE}Instruction used:${NC} vcompressps (AVX-512 specific)"
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}How vcompressps Works${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "${YELLOW}Step 1: Compare${NC} - Create mask of elements matching condition"
    echo -e "  vcmpps k1, zmm0, zmm1  → k1 = [0,1,0,1] (mask for a[i] > 0)"
    echo ""
    echo -e "${YELLOW}Step 2: Compress${NC} - Store only selected elements contiguously"
    echo -e "  vcompressps [b]{k1}, zmm0  → Stores only masked values"
    echo ""
    echo -e "${YELLOW}Step 3: Count${NC} - Update write position"
    echo -e "  popcnt eax, k1  → Count how many elements selected"
    echo -e "  add nb, eax     → Update output index"
    echo ""
    echo -e "${GREEN}Example:${NC}"
    echo -e "  Input:  [-2.0f,  3.0f, -1.0f,  5.0f]"
    echo -e "  Mask:   [    0,     1,     0,     1]"
    echo -e "  Output: [ 3.0f,  5.0f]  (compressed!)"
    echo ""

    echo -e "${GREEN}=== Generate assembly for comparison ===${NC}"
    run_cmd "icx -xCORE-AVX2 -O2 -S -fargument-noalias compress.c -o compress_avx2.s"
    run_cmd "icx -xCORE-AVX512 -O2 -S -fargument-noalias compress.c -o compress_avx512.s"

    echo -e "${BLUE}Checking for vcompress instruction:${NC}"
    VCOMP_AVX2=$(grep -c "vcompress" compress_avx2.s 2>/dev/null || echo "0")
    VCOMP_AVX512=$(grep -c "vcompress" compress_avx512.s 2>/dev/null || echo "0")

    echo -e "  AVX2 assembly:    ${VCOMP_AVX2} vcompress instructions"
    echo -e "  AVX-512 assembly: ${VCOMP_AVX512} vcompress instructions"
    echo ""

    if [ "$VCOMP_AVX512" -gt 0 ]; then
        echo -e "${GREEN}✓ AVX-512 version uses vcompress instruction!${NC}"
        grep "vcompress" compress_avx512.s | head -3 | sed 's/^/  /'
    else
        echo -e "${YELLOW}Note: vcompress not found (may vary by compiler version)${NC}"
    fi
    echo ""

    echo -e "${GREEN}=== Build and benchmark both versions ===${NC}"
    run_cmd "icx -xCORE-AVX2 -O2 -fargument-noalias compress.c compress_main.c -o compress_avx2"
    run_cmd "icx -xCORE-AVX512 -O2 -fargument-noalias compress.c compress_main.c -o compress_avx512"

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}AVX2 Version (Scalar)${NC}"
    echo -e "${BLUE}========================================${NC}"
    ./compress_avx2 2>&1
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}AVX-512 Version (Vectorized)${NC}"
    echo -e "${BLUE}========================================${NC}"
    ./compress_avx512 2>&1
    echo ""

    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Performance Analysis (SPR Results)${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo ""
    echo -e "${YELLOW}Measured Performance (10M elements, ~50% selectivity):${NC}"
    echo -e "  AVX2 (scalar):       0.047s,  212 M elem/s"
    echo -e "  AVX-512 (vectorized): 0.004s, 2512 M elem/s"
    echo -e "  ${GREEN}Speedup: 11.9x faster!${NC}"
    echo ""
    echo -e "${BLUE}Why such dramatic speedup?${NC}"
    echo -e "  1. ${GREEN}Vectorized processing${NC}: 16 floats per iteration vs 1"
    echo -e "  2. ${GREEN}Eliminates branches${NC}: Mask-based selection, no jumps"
    echo -e "  3. ${GREEN}No branch mispredictions${NC}: Huge cost at 50% selectivity"
    echo -e "  4. ${GREEN}Efficient memory writes${NC}: vcompressps writes contiguously"
    echo ""
    echo -e "${GREEN}========================================${NC}"
    echo -e "${GREEN}Key Lessons${NC}"
    echo -e "${GREEN}========================================${NC}"
    echo -e "• ${YELLOW}Compress/expand${NC} are special loop patterns (idioms)"
    echo -e "• ${RED}AVX2 cannot vectorize${NC} compress patterns efficiently"
    echo -e "• ${GREEN}AVX-512 provides vcompressps${NC} specifically for this idiom"
    echo -e "• ${BLUE}Compiler recognizes${NC} the pattern automatically (no pragmas needed)"
    echo -e "• ${GREEN}Most dramatic speedup${NC} of all exercises: ${YELLOW}11.9x on SPR${NC}"
    echo -e "• ${BLUE}Perfect match${NC} between problem and hardware capability"
    echo -e "• ${GREEN}Other AVX-512 idioms:${NC} expand, conflict detection, popcnt"
    echo ""
    echo -e "${YELLOW}Try it online:${NC} https://godbolt.org/z/63oTsshKd"
    echo ""
fi

print_header "Exercise Complete!"
echo -e "${GREEN}Check the output above to understand vectorization and optimization flags.${NC}"
