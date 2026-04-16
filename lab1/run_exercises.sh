#!/bin/bash
# Script to run all exercises for the ICC vs ICX lab

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
    echo "  1 - Observe default diagnostic behavior"
    echo "  2 - Control diagnostic severity (warnings vs errors)"
    echo "  3 - ICC native -diag-warning vs GCC-compat -Wunused-variable"
    echo "  4 - Enable -Wall and suppress with -Wno-unused-variable (ICX)"
    echo "  5 - Pragma directives for code sections (ICX)"
    echo "  6 - Suppress diagnostic in ICC with -diag-disable"
    echo "  7 - Pragma directives (ICX) - localized and file-wide"
    echo "  8 - Unknown/unsupported pragma handling"
    echo "  all - Run all exercises"
    exit 1
fi

EXERCISE=$1

# Exercise 1: Default behavior
if [ "$EXERCISE" == "1" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 1: Default Diagnostic Behavior"

    show_code "test.cpp" 4

    echo -e "${GREEN}=== ICX Default (no warnings) ===${NC}"
    setup_icx
    run_cmd "icpx test.cpp -o test_icx"

    echo -e "${GREEN}=== ICX with -Wall ===${NC}"
    run_cmd "icpx -Wall test.cpp -o test_icx"

    echo -e "${GREEN}=== ICC with -Wall (no unused variable warning!) ===${NC}"
    setup_icc
    run_cmd "icc -Wall test.cpp -o test_icc 2>&1 | grep -v 'remark #10441' || echo 'No warnings shown'"

    echo -e "${GREEN}=== ICC native: -diag-warning=177 ===${NC}"
    run_cmd "icc -diag-warning=177 test.cpp -o test_icc 2>&1 | grep -v 'remark #10441'"

    echo -e "${GREEN}=== ICC GCC-compat: -Wunused-variable also works ===${NC}"
    run_cmd "icc -Wunused-variable test.cpp -o test_icc 2>&1 | grep -v 'remark #10441'"
fi

# Exercise 2: Disable warnings as errors
if [ "$EXERCISE" == "2" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 2: Disable Warnings as Errors"

    show_code "test.cpp" 4

    echo -e "${GREEN}=== ICX: -Wall -Werror (warnings as errors) ===${NC}"
    setup_icx
    echo -e "${YELLOW}Command:${NC} icpx -Wall -Werror test.cpp -o test_icx"
    echo ""
    icpx -Wall -Werror test.cpp -o test_icx 2>&1 || echo -e "${RED}Compilation failed due to warning treated as error${NC}"
    echo ""

    echo -e "${GREEN}=== ICX: -Wall -Wno-error (warnings not as errors) ===${NC}"
    run_cmd "icpx -Wall -Wno-error test.cpp -o test_icx"

    echo -e "${GREEN}=== ICC: -diag-error=177 (diagnostic as error) ===${NC}"
    setup_icc
    echo -e "${YELLOW}Command:${NC} icc -diag-error=177 test.cpp -o test_icc"
    echo ""
    icc -diag-error=177 test.cpp -o test_icc 2>&1 | grep -v "remark #10441" || echo -e "${RED}Compilation failed due to diagnostic #177 treated as error${NC}"
    echo ""

    echo -e "${GREEN}=== ICC: -diag-warning=177 (diagnostic as warning) ===${NC}"
    run_cmd "icc -diag-warning=177 test.cpp -o test_icc 2>&1 | grep -v 'remark #10441'"
fi

# Exercise 3: ICC Native vs GCC-Compatible Options (Comparison)
if [ "$EXERCISE" == "3" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 3: ICC Native vs GCC-Compatible Options"

    show_code "test.cpp" 4

    setup_icc

    echo -e "Exercise 1 showed that ICC has two ways to enable unused variable warnings."
    echo -e "This exercise directly compares them side-by-side:"
    echo -e ""

    echo -e "${GREEN}=== ICC native: -diag-warning=177 ===${NC}"
    run_cmd "icc -diag-warning=177 test.cpp -o test_icc 2>&1 | grep -v 'remark #10441'"

    echo -e "${GREEN}=== ICC GCC-compatible: -Wunused-variable ===${NC}"
    run_cmd "icc -Wunused-variable test.cpp -o test_icc 2>&1 | grep -v 'remark #10441'"

    echo -e "Key insight: Both produce IDENTICAL output (warning #177 in Intel format)."
    echo -e "ICC accepts -W* flags for GCC compatibility, NOT Clang!"
fi

# Exercise 4: Enable all warnings and suppress specific (ICX)
if [ "$EXERCISE" == "4" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 4: Enable -Wall and Suppress with -Wno-unused-variable (ICX)"

    show_code "test.cpp" 4

    setup_icx

    echo -e "${GREEN}=== ICX: -Wall (shows warning) ===${NC}"
    run_cmd "icpx -Wall test.cpp -o test_icx"

    echo -e "${GREEN}=== ICX: -Wall -Wno-unused-variable (suppresses warning) ===${NC}"
    run_cmd "icpx -Wall -Wno-unused-variable test.cpp -o test_icx"
fi

# Exercise 5: Pragma for code sections (ICX)
if [ "$EXERCISE" == "5" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 5: Pragma Directives for Code Sections (ICX)"

    show_code "test_multiple_unused.cpp" 4 9

    setup_icx

    echo -e "${GREEN}=== ICX: Without pragma (shows warning for X) ===${NC}"
    run_cmd "icpx -Wall test.cpp -o test_icx"

    echo -e "${GREEN}=== ICX: With pragma section (X suppressed, Y warns) ===${NC}"
    run_cmd "icpx -Wall test_multiple_unused.cpp -o test_icx"

    echo -e "Note: Pragma only suppresses warning for X. Y still warns - proving scope is limited!"
fi

# Exercise 6: Suppress diagnostic in ICC
if [ "$EXERCISE" == "6" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 6: Suppress Diagnostic in ICC"

    show_code "test.cpp" 4

    setup_icc

    echo -e "${GREEN}=== ICC: -diag-warning=177 (shows warning #177) ===${NC}"
    run_cmd "icc -diag-warning=177 test.cpp -o test_icc 2>&1 | grep -v 'remark #10441'"

    echo -e "${GREEN}=== ICC native: -diag-disable=177 (suppresses warning) ===${NC}"
    run_cmd "icc -diag-warning=177 -diag-disable=177 test.cpp -o test_icc 2>&1 | grep -v 'remark #10441' || echo 'No warnings shown'"

    echo -e "${GREEN}=== ICC GCC-compat: -Wno-unused-variable (also suppresses!) ===${NC}"
    run_cmd "icc -diag-warning=177 -Wno-unused-variable test.cpp -o test_icc 2>&1 | grep -v 'remark #10441' || echo 'No warnings shown'"

    echo -e "Note: ICC's native options are -diag-warning=177 (enable) and -diag-disable=177 (suppress)."
    echo -e "ICC also accepts -Wunused-variable/-Wno-unused-variable for GCC compatibility, NOT Clang."
fi

# Exercise 7: File-wide Pragma (ICX)
if [ "$EXERCISE" == "7" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 7: File-wide Pragma Suppression (ICX)"

    setup_icx

    echo -e "Exercise 5 showed LOCALIZED pragma (push/pop) affecting only variable X."
    echo -e "This exercise shows FILE-WIDE pragma that affects ALL variables:"
    echo -e ""

    echo -e "${GREEN}=== ICX: File-wide pragma (both X and Y suppressed) ===${NC}"
    show_code "test_pragma_file.cpp" 3 9
    run_cmd "icpx -Wall test_pragma_file.cpp -o test_icx"

    echo -e "Note: Without push/pop, the pragma affects everything after it (file-wide scope)."
    echo -e "Compare to Exercise 5 where only X was suppressed using push/pop."
fi

# Exercise 8: Unknown/unsupported pragma handling
if [ "$EXERCISE" == "8" ] || [ "$EXERCISE" == "all" ]; then
    print_header "Exercise 8: Unknown/Unsupported Pragma Handling"

    show_code "test_pragmas.cpp" 4 7

    echo -e "${GREEN}=== ICX: Default (no warnings on unknown pragmas) ===${NC}"
    setup_icx
    run_cmd "icpx test_pragmas.cpp -o test_pragmas"

    echo -e "${GREEN}=== ICX: -Wall (includes -Wunknown-pragmas) ===${NC}"
    run_cmd "icpx -Wall test_pragmas.cpp -o test_pragmas"

    echo -e "${GREEN}=== ICX: Explicit -Wunknown-pragmas ===${NC}"
    run_cmd "icpx -Wunknown-pragmas test_pragmas.cpp -o test_pragmas"

    echo -e "${GREEN}=== ICX: Suppress with -Wno-unknown-pragmas ===${NC}"
    run_cmd "icpx -Wall -Wno-unknown-pragmas test_pragmas.cpp -o test_pragmas"

    echo -e "${GREEN}=== ICC: Default (WARNS on unknown pragmas!) ===${NC}"
    setup_icc
    run_cmd "icc test_pragmas.cpp -o test_pragmas 2>&1 | grep -v 'remark #10441'"

    echo -e "${GREEN}=== ICC: Suppress with -diag-disable=161,3948,13379 ===${NC}"
    run_cmd "icc -diag-disable=161,3948,13379 test_pragmas.cpp -o test_pragmas 2>&1 | grep -v 'remark #10441' || echo 'No warnings shown'"

    echo -e "Note: ICC is MORE STRICT by default - it warns about unknown pragmas."
    echo -e "ICX only warns with -Wunknown-pragmas (or -Wall which includes it)."
    echo -e ""
    echo -e "Pragmas tested:"
    echo -e "  - #pragma totallybogus: Unknown to both (both warn when enabled)"
    echo -e "  - #pragma simd: ICC Classic pragma, deprecated, NOT supported by ICX"
    echo -e "  - #pragma vector: Recognized by ICX, implemented correctly"
fi

print_header "Exercise Complete!"
echo -e "${GREEN}Check the output above to understand the differences between ICC and ICX.${NC}"
