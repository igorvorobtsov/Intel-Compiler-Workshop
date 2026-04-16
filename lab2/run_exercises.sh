#!/bin/bash
# Script to run all exercises for the Fortran Debugging lab

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

# Function to setup IFX environment
setup_ifx() {
    module unload intel/2023.2.1 2>/dev/null || true
    module switch stack stack/24.6.0 2>/dev/null
    module load intel/2025.3.0 2>/dev/null
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
    echo "  1 - Warning levels and Fortran-specific warnings"
    echo "  2 - Standard conformance checking (-stand)"
    echo "  3 - Uninitialized variable detection (-ftrapuv, -init=snan)"
    echo "  4 - Integer overflow detection (-ftrapv limitation)"
    echo "  5 - Runtime bounds checking (-check bounds)"
    echo "  6 - Floating point exception handling (-fpe0)"
    echo "  7 - Comprehensive runtime checking (-check all)"
    echo "  all - Run all exercises"
    exit 1
fi

EXERCISE=$1

# Exercise 1: Warning levels
if [ "$EXERCISE" == "1" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 1: Warning Levels and Fortran-Specific Warnings"

    show_code "warn.f90" 3 7

    setup_ifx

    echo -e "${GREEN}=== Default behavior (nounused is default) ===${NC}"
    run_cmd "ifx warn.f90 -o warn"
    echo -e "${BLUE}Notice: Remark about uncalled function (default), but NO remark about unused variable${NC}"
    echo ""

    echo -e "${GREEN}=== With -warn unused (enable unused variable remarks) ===${NC}"
    run_cmd "ifx -warn unused warn.f90 -o warn"
    echo -e "${BLUE}Notice: NOW shows remark about unused variable 'abc'${NC}"
    echo ""

    echo -e "${GREEN}=== With -warn nounused (explicit, same as default) ===${NC}"
    run_cmd "ifx -warn nounused warn.f90 -o warn"
    echo -e "${BLUE}Same as default - nounused is the default behavior${NC}"
    echo ""

    echo -e "${GREEN}=== With -warn nouncalled (suppress uncalled function remarks) ===${NC}"
    run_cmd "ifx -warn nouncalled warn.f90 -o warn"
    echo -e "${BLUE}Notice: No remarks at all - both unused and uncalled suppressed${NC}"
    echo ""

    echo -e "${GREEN}=== With -warn all (maximum warnings) ===${NC}"
    run_cmd "ifx -warn all warn.f90 -o warn"
    echo -e "${BLUE}Reports all possible issues${NC}"
    echo ""

    echo -e "${BLUE}Key points:${NC}"
    echo -e "• Default is ${YELLOW}-warn nounused${NC} (no unused variable remarks)"
    echo -e "• Uncalled functions produce remarks by default"
    echo -e "• Use ${GREEN}-warn unused${NC} during development to catch unused variables"
fi

# Exercise 2: Standard conformance
if [ "$EXERCISE" == "2" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 2: Standard Conformance Checking"

    show_code "standard.f90" 5 9

    setup_ifx

    echo -e "${GREEN}=== Default (no standard checking) ===${NC}"
    run_cmd "ifx standard.f90 -o standard"

    echo -e "${GREEN}=== With -stand f18 (Fortran 2018 standard) ===${NC}"
    run_cmd "ifx -stand f18 standard.f90 -o standard"

    echo -e "Note: -stand does not change program behavior, only strictness of checking"
fi

# Exercise 3: Uninitialized variables
if [ "$EXERCISE" == "3" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 3: Uninitialized Variable Detection"

    show_code "uninit.f90" 5 6

    setup_ifx

    echo -e "${GREEN}=== Test 1: Default (undefined behavior) ===${NC}"
    run_cmd "ifx uninit.f90 -o uninit && ./uninit"

    echo -e "${GREEN}=== Test 2a: Understanding -ftrapuv with -dryrun ===${NC}"
    echo -e "${YELLOW}Command:${NC} ifx -ftrapuv -g -O0 uninit.f90 -dryrun 2>&1 | grep -E 'fpe|init'"
    echo ""
    echo -e "${BLUE}This shows what the compiler driver translates -ftrapuv into (without compiling):${NC}"
    ifx -ftrapuv -g -O0 uninit.f90 -dryrun 2>&1 | grep -E "^\s+(-fpe[0-9]|\".*init.*\")" | head -2
    echo ""
    echo -e "${BLUE}Notice: -ftrapuv becomes both '-fpe0' and '\"-init snan\"' in the backend!${NC}"
    echo -e "${BLUE}Tip: Use '-dryrun' to see flag translation without compiling (cleaner than -v).${NC}"
    echo -e "${BLUE}This works with both ifx and ifort (Intel Fortran Compiler Classic).${NC}"
    echo ""

    echo -e "${GREEN}=== Test 2b: With -ftrapuv (composite flag: implies -init=snan + -fpe0) ===${NC}"
    echo -e "${YELLOW}Command:${NC} ifx -ftrapuv -traceback -g -O0 uninit.f90 -o uninit && ./uninit"
    echo ""
    ifx -ftrapuv -traceback -g -O0 uninit.f90 -o uninit 2>&1 && ./uninit 2>&1 || echo -e "${RED}✅ Runtime error detected! -ftrapuv caught the bug.${NC}"
    echo ""

    echo -e "${GREEN}=== Test 3: With -ftrapuv -fpe3 (WRONG: -fpe3 overrides -fpe0!) ===${NC}"
    echo -e "${YELLOW}Command:${NC} ifx -ftrapuv -fpe3 -traceback -g -O0 uninit.f90 -o uninit && ./uninit"
    echo ""
    ifx -ftrapuv -fpe3 -traceback -g -O0 uninit.f90 -o uninit 2>&1 && ./uninit 2>&1 || echo -e "${RED}Runtime error detected.${NC}"
    echo -e "${RED}⚠️  Notice: Program prints NaN without error! -fpe3 disabled FP exception trapping.${NC}"
    echo ""

    echo -e "${GREEN}=== Test 4: With -ftrapuv -fpe0 (explicit -fpe0 ensures trapping) ===${NC}"
    echo -e "${YELLOW}Command:${NC} ifx -ftrapuv -fpe0 -traceback -g -O0 uninit.f90 -o uninit && ./uninit"
    echo ""
    ifx -ftrapuv -fpe0 -traceback -g -O0 uninit.f90 -o uninit 2>&1 && ./uninit 2>&1 || echo -e "${RED}✅ Runtime error detected! Explicit -fpe0 works.${NC}"
    echo ""

    echo -e "${GREEN}=== Test 5: With -init=snan (automatically enables FP trapping) ===${NC}"
    echo -e "${YELLOW}Command:${NC} ifx -init=snan -traceback -g -O0 uninit.f90 -o uninit && ./uninit"
    echo ""
    ifx -init=snan -traceback -g -O0 uninit.f90 -o uninit 2>&1 && ./uninit 2>&1 || echo -e "${RED}✅ Runtime error detected! -init=snan works automatically.${NC}"
    echo ""

    echo -e "${GREEN}=== Test 6: With -init=snan -fpe3 (SMART: -init=snan overrides -fpe3!) ===${NC}"
    echo -e "${YELLOW}Command:${NC} ifx -init=snan -fpe3 -traceback -g -O0 uninit.f90 -o uninit && ./uninit"
    echo ""
    echo -e "${BLUE}Expected: Compiler warning: '-init=snan' disables '-fpe3'${NC}"
    ifx -init=snan -fpe3 -traceback -g -O0 uninit.f90 -o uninit 2>&1 && ./uninit 2>&1 || echo -e "${RED}✅ Runtime error STILL detected! -init=snan protected itself from -fpe3.${NC}"
    echo ""

    echo -e "${GREEN}=== Test 7: With -init=snan -fpe0 (most explicit combination) ===${NC}"
    echo -e "${YELLOW}Command:${NC} ifx -init=snan -fpe0 -traceback -g -O0 uninit.f90 -o uninit && ./uninit"
    echo ""
    ifx -init=snan -fpe0 -traceback -g -O0 uninit.f90 -o uninit 2>&1 && ./uninit 2>&1 || echo -e "${RED}✅ Runtime error detected! Most explicit and safest approach.${NC}"
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Key Learnings:${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "• ${GREEN}-ftrapuv${NC} is a composite flag that implies both -init=snan AND -fpe0"
    echo -e "• ${RED}Flag order matters${NC}: later flags can override earlier ones"
    echo -e "• ${RED}-ftrapuv -fpe3${NC} does NOT catch errors (-fpe3 overrides -fpe0)"
    echo -e "• ${GREEN}-init=snan${NC} is smarter: it protects against -fpe3 override (gives warning)"
    echo -e "• ${GREEN}Best practice${NC}: Use -init=snan -fpe0 (safest and most explicit)"
    echo -e "• Always use ${GREEN}-O0${NC} (no optimization) with these flags"
fi

# Exercise 4: Runtime checking (bounds + comprehensive)
if [ "$EXERCISE" == "4" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 4: Runtime Checking (Bounds and Comprehensive)"

    show_code "bounds_runtime.f90" 7 10

    setup_ifx

    echo -e "${GREEN}=== Default (no runtime checking) ===${NC}"
    run_cmd "ifx bounds_runtime.f90 -o bounds_runtime && ./bounds_runtime"

    echo -e "${GREEN}=== With -check bounds (runtime bounds checking) ===${NC}"
    echo -e "${YELLOW}Command:${NC} ifx -check bounds -traceback -g bounds_runtime.f90 -o bounds_runtime && ./bounds_runtime"
    echo ""
    ifx -check bounds -traceback -g bounds_runtime.f90 -o bounds_runtime 2>&1 && ./bounds_runtime 2>&1 || echo -e "${RED}Runtime bounds violation detected! Check traceback above.${NC}"
    echo ""
    echo -e "Note: -check bounds catches out-of-bounds array access at runtime"
    echo -e "Performance impact: moderate (10-50% slowdown)"
    echo ""

    echo -e "${GREEN}=== With -check all (comprehensive runtime checking) ===${NC}"
    echo -e "${YELLOW}Command:${NC} ifx -check all -traceback -g bounds_runtime.f90 -o bounds_runtime && ./bounds_runtime"
    echo ""
    ifx -check all -traceback -g bounds_runtime.f90 -o bounds_runtime 2>&1 && ./bounds_runtime 2>&1 || echo -e "${RED}Runtime error detected with -check all! Check traceback above.${NC}"
    echo ""
    echo -e "${BLUE}Note: -check all enables bounds, pointer, format, and more${NC}"
    echo -e "${RED}IMPORTANT: -check all now EXCLUDES -check uninit (changed in recent versions)${NC}"
    echo -e "${RED}           -check uninit causes failures with oneMKL/MPI libraries${NC}"
    echo -e "${YELLOW}⚠️  CAUTION: Must LINK with -check all if you compiled with it!${NC}"
    echo -e "${BLUE}Disables optimization (-O0) and overrides any -O level set${NC}"
    echo -e "${BLUE}Performance impact: severe (2-10x slowdown)${NC}"
    echo -e "${BLUE}Use during development, remove for production builds${NC}"
fi

# Exercise 5: Floating point exceptions
if [ "$EXERCISE" == "5" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 5: Floating Point Exception Handling"

    show_code "fpe.f90" 5 6

    setup_ifx

    echo -e "${GREEN}=== Default (no FP exception handling) ===${NC}"
    run_cmd "ifx fpe.f90 -o fpe && ./fpe"

    echo -e "${GREEN}=== With -fpe0 (catch FP exceptions) ===${NC}"
    echo -e "${YELLOW}Command:${NC} ifx -fpe0 -traceback -g fpe.f90 -o fpe && ./fpe"
    echo ""
    ifx -fpe0 -traceback -g fpe.f90 -o fpe 2>&1 && ./fpe 2>&1 || echo -e "${RED}Floating point exception detected! Check traceback above.${NC}"
    echo ""

    echo -e "Note: -fpe0 enables all floating-point exception handling"
    echo -e "Default is -fpe3 which disables all FP exceptions"
fi

# Exercise 6: Automatic reallocation (-assume)
if [ "$EXERCISE" == "6" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 6: Automatic Reallocation (-assume realloc_lhs)"

    show_code "assume_realloc_lhs.f90" 4 6

    setup_ifx

    echo -e "${GREEN}=== Default (automatic reallocation enabled - F2003+) ===${NC}"
    run_cmd "ifx assume_realloc_lhs.f90 -o assume_realloc_lhs && ./assume_realloc_lhs"
    echo -e "${BLUE}Notice: Array automatically resized from 2 to 3 elements${NC}"
    echo ""

    echo -e "${GREEN}=== With -assume norealloc_lhs (disable auto realloc - F95 behavior) ===${NC}"
    run_cmd "ifx -assume norealloc_lhs assume_realloc_lhs.f90 -o assume_realloc_lhs && ./assume_realloc_lhs"
    echo -e "${RED}⚠️  Notice: Array stays size 2, third element silently truncated!${NC}"
    echo -e "${RED}   This can cause silent data loss - dangerous!${NC}"
    echo ""

    echo -e "${GREEN}=== With -assume realloc_lhs (explicit enable) ===${NC}"
    run_cmd "ifx -assume realloc_lhs assume_realloc_lhs.f90 -o assume_realloc_lhs && ./assume_realloc_lhs"
    echo -e "${BLUE}Array automatically resized (same as default)${NC}"
    echo ""

    echo -e "${BLUE}========================================${NC}"
    echo -e "${BLUE}Key Learnings:${NC}"
    echo -e "${BLUE}========================================${NC}"
    echo -e "• ${GREEN}Default (IFX)${NC}: Automatic reallocation enabled (Fortran 2003+ standard)"
    echo -e "• ${GREEN}-assume realloc_lhs${NC}: Explicitly enable auto reallocation (safe)"
    echo -e "• ${RED}-assume norealloc_lhs${NC}: Disable auto reallocation (F95 legacy, dangerous)"
    echo -e "• ${RED}Silent data loss${NC}: -assume norealloc_lhs truncates without warning"
    echo -e "• ${GREEN}Best practice${NC}: Use default behavior (auto reallocation)"
    echo -e "• Only use ${RED}-assume norealloc_lhs${NC} for legacy F95 code with thorough testing"
    echo -e "• Many other ${GREEN}-assume${NC} options available: run ${GREEN}ifx -help assume${NC}"
fi

print_header "Exercise Complete!"
echo -e "${GREEN}Check the output above to understand compiler debugging options.${NC}"
