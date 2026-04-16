# Lab 2: Debugging with Fortran Compiler (IFX)

## Overview

This lab demonstrates how to use Intel Fortran Compiler (IFX) debugging options to catch common programming errors. You'll learn how compiler flags can help detect bugs at compile-time and runtime, including uninitialized variables, array bounds violations, and floating-point exceptions.

**Compiler Used:** Intel Fortran Compiler (ifx) 2025.3.0

**Key Concepts:**
- Debug-friendly builds vs optimized builds
- Compile-time vs runtime error detection
- Warning levels and standard conformance
- Runtime checks and their performance impact
- Floating-point exception handling
- Compiler assumptions and compatibility modes

## Lab Files

The lab includes these test programs:

1. **warn.f90** - Unused variable warning
2. **standard.f90** - Standard conformance issue
3. **uninit.f90** - Uninitialized variable (undefined behavior)
4. **bounds_runtime.f90** - Array bounds violation (runtime)
5. **fpe.f90** - Floating-point exception (division by zero)
6. **assume_realloc_lhs.f90** - Automatic reallocation behavior

## Setup

### Load IFX Environment

```bash
module switch stack stack/24.6.0
module load intel/2025.3.0
```

Or use the provided script:

```bash
source setup_ifx.sh
```

### Verify Installation

```bash
ifx --version
```

Expected output:
```
ifx (IFX) 2025.3.0 ...
```

## Exercise 1: Warning Levels and Fortran-Specific Warnings

### Goal
Learn how to enable Fortran-specific warnings to catch potential issues.

### Code: warn.f90

```fortran
program warn
    implicit none
    real :: afunc, b
    integer :: abc
    
    ! abc is declared but not used
    afunc(b) = 123*b
    
    print *, "Done"
end program warn
```

**Bug:** Variable `abc` is declared but never used (potential typo or dead code).

### Tasks

**1a. Default Warnings**

```bash
ifx warn.f90 -o warn
```

**Expected:** Compiles successfully. No warnings about unused variable `abc`.

**1b. Enable Unused Variable Warnings (-warn unused)**

```bash
ifx -warn unused warn.f90 -o warn
```

**Expected:**
```
warn.f90(4): warning #7712: This variable has not been used.   [ABC]
    integer :: abc
               ^
```

**Note:** `-warn unused` catches unused variables, which often indicate:
- Typos in variable names
- Dead code
- Incomplete implementations
- Copy-paste errors

**1c. Suppress Unused Warnings (-warn nounused)**

```bash
ifx -warn nounused warn.f90 -o warn
```

**Expected:** No warning. Use this only when you have a justified reason (e.g., interface compatibility).

**1d. Warn About Uncalled Functions (-warn uncalled)**

```bash
ifx -warn uncalled warn.f90 -o warn
```

**Expected:**
```
warn.f90(7): warning #7960: The STATEMENT FUNCTION has not been called.   [AFUNC]
    afunc(b) = 123*b
    ^
```

**Note:** Statement function `afunc` is defined but never called.

### Key Takeaways

- **-warn unused** catches unused variables (recommended during development)
- **-warn uncalled** catches unused functions
- **-warn nounused** suppresses unused warnings (use sparingly)
- Warnings help catch typos, dead code, and potential bugs
- Use warnings during development, suppress only when justified

## Exercise 2: Standard Conformance Checking

### Goal
Ensure code conforms to Fortran standards for portability.

### Code: standard.f90

```fortran
module m
    implicit none
    type :: t
    end type
    contains
        pure subroutine sub(x)
            class(t), allocatable, intent(out) :: x
            allocate(x)
        end subroutine
end module m

program standard
    use m
    implicit none

    print *, "Testing standard conformance"
end program standard
```

**Issue:** In a `pure` subroutine, an `INTENT(OUT)` dummy argument must not be polymorphic (`class(t)`) according to Fortran 2018 standard. This restriction exists because polymorphic variables can have different dynamic types, and `pure` procedures must have predictable behavior without side effects.

### Tasks

**2a. Default Compilation (No Standard Checking)**

```bash
ifx standard.f90 -o standard
```

**Expected:** Compiles successfully with a warning. IFX is lenient by default.

```
standard.f90(6): warning #9000: An INTENT(OUT) dummy argument of a pure subroutine must not be polymorphic or have a polymorphic allocatable ultimate component.   [X]
        pure subroutine sub(x)
----------------------------^
```

**2b. Enforce Fortran 2018 Standard (-stand f18)**

```bash
ifx -stand f18 standard.f90 -o standard
```

**Expected:** Compilation fails with an error:
```
standard.f90(6): error #9001: Fortran 2018 requires that an INTENT(OUT) dummy argument of a pure subroutine must not be polymorphic or have a polymorphic allocatable ultimate component.   [X]
        pure subroutine sub(x)
----------------------------^
compilation aborted for standard.f90 (code 1)
```

**Note:** `-stand f18` enforces Fortran 2018 standard compliance, turning warnings into errors. Use this to ensure portability across compilers.

### Available Standards

- `-stand f95` - Fortran 95
- `-stand f03` - Fortran 2003
- `-stand f08` - Fortran 2008
- `-stand f18` - Fortran 2018
- `-stand f23` - Fortran 2023 (latest standard, recommended for new code)

### Key Takeaways

- **-stand f18** enforces Fortran 2018 standard
- Standard checking catches non-portable code constructs
- Use during development to ensure code works across compilers
- Does not change runtime behavior, only strictness of checking
- Helps catch syntax errors and deprecated features

## Exercise 3: Uninitialized Variable Detection

### Goal
Detect uninitialized variables that cause undefined behavior.

### Code: uninit.f90

```fortran
program uninit
    implicit none
    real :: a, b
    
    ! b is not initialized - undefined behavior
    a = b / 0.0
    
    print *, a
end program uninit
```

**Bug:** Variable `b` is used without initialization.

### Tasks

**3a. Default Build (Undefined Behavior)**

```bash
ifx uninit.f90 -o uninit
./uninit
```

**Expected:** Undefined behavior. May print random value, NaN, or crash.

**3b. Initialize to NaN (-ftrapuv)**

```bash
ifx -ftrapuv -traceback -g -O0 uninit.f90 -o uninit
./uninit
```

**Expected:** Runtime error with traceback showing the bug location.

```
forrtl: error (182): floating invalid - possible uninitialized real/complex variable.
Image              PC                Routine            Line        Source
uninit             0000000000404352  uninit                    6  uninit.f90
...
```

**Note:** `-ftrapuv` initializes all uninitialized local variables to a "trap value" (signaling NaN for floating-point). Behind the scenes, `-ftrapuv` **automatically enables** both `-init=snan` and `-fpe0`, which enables FP exception trapping. This causes immediate crashes when uninitialized values are used, making bugs obvious.

**3c. Signaling NaN (-init=snan)**

```bash
ifx -init=snan -fpe0 -traceback -g -O0 uninit.f90 -o uninit
./uninit
```

**Expected:** Floating-point exception with traceback.

```
forrtl: error (65): floating invalid
Image              PC                Routine            Line        Source
uninit             0000000000402D87  MAIN__                  6  uninit.f90
...
```

**Note:** `-init=snan` initializes variables to signaling NaN and disables the default `-fpe3`. We explicitly add `-fpe0` to enable all FP exception trapping.

**3d. Understanding What `-ftrapuv` Really Does (Using `-dryrun`)**

The compiler driver (like `ifx` or `ifort`) often translates high-level flags into multiple lower-level flags passed to the actual compiler backend. You can see this translation using the `-dryrun` flag, which shows what **would** be passed without actually compiling:

```bash
ifx -ftrapuv -g -O0 uninit.f90 -dryrun 2>&1 | grep -E "fpe|init"
```

**Expected output:**
```
-fpe0 \
"-init snan" \
```

**What this reveals:**
- The `-ftrapuv` flag is translated by the compiler driver
- It becomes **both** `-fpe0` AND `"-init snan"` in the backend
- This explains why `-ftrapuv` alone catches uninitialized variable errors

**Bonus: Works with both Intel compilers!**
```bash
# ifort (Classic)
module load intel/2024.2.1
ifort -ftrapuv -g -O0 uninit.f90 -dryrun 2>&1 | grep -E "fpe|init"
# Output: -fpe0 \ and "-init snan" \

# ifx (LLVM-based)
source setup_ifx.sh
ifx -ftrapuv -g -O0 uninit.f90 -dryrun 2>&1 | grep -E "fpe|init"
# Output: -fpe0 \ and "-init snan" \
```

**Comparison: `-dryrun` vs `-v`**
- **`-dryrun`**: Shows clean backend flags without compiling (recommended for understanding flags)
- **`-v`**: Shows full compilation pipeline including all steps (useful for debugging complex build issues)

**Key Learning:** Use `-dryrun` to understand what your compiler driver is actually doing behind the scenes. This is especially useful when:
- Debugging unexpected compiler behavior
- Understanding composite flags like `-ftrapuv`
- Checking if optimization flags are being applied
- Comparing different compiler versions or flags
- Verifying flag combinations before long compilations

### Critical Understanding: How `-ftrapuv` Actually Works

**Important Discovery:** `-ftrapuv` is a **composite flag** that enables multiple features!

**What `-ftrapuv` actually does (verified with `-v` verbose compilation in 4d above):**
1. Enables `-init=snan` (initializes variables to signaling NaN)
2. Enables `-fpe0` (enables all FP exception trapping)
3. These work together to catch uninitialized variable usage

**Therefore, `-ftrapuv` alone WILL catch the problem:**
```bash
# -ftrapuv automatically includes both -init=snan and -fpe0
ifx -ftrapuv -traceback -g -O0 uninit.f90 -o uninit
./uninit
# Output: forrtl: error (182): floating invalid - possible uninitialized real/complex variable.
```

### ⚠️ Critical Pitfall: Overriding `-ftrapuv` with `-fpe3`

**The problem happens when you EXPLICITLY add `-fpe3` AFTER `-ftrapuv`:**

```bash
# WRONG: -fpe3 after -ftrapuv overrides the automatic -fpe0
ifx -ftrapuv -fpe3 -traceback -g -O0 uninit.f90 -o uninit
./uninit
# Output: NaN (no error - problem NOT caught!)
```

**Why it fails:**
1. `-ftrapuv` enables both `-init=snan` and `-fpe0`
2. But `-fpe3` appearing later on the command line **overrides** the `-fpe0`
3. Variables are still initialized to sNaN, but FP exceptions are disabled
4. The division `sNaN / 0.0` produces `NaN` silently without trapping
5. Program continues with invalid result

**This is a common mistake** when combining compiler flags without understanding the order matters!

### How `-init=snan` Differs from `-ftrapuv`

**`-init=snan` alone:**
- Only initializes variables to signaling NaN
- Also automatically disables default `-fpe3` and enables FP trapping
- More focused: just the initialization part

```bash
# -init=snan automatically enables FP exception trapping
ifx -init=snan -traceback -g -O0 uninit.f90 -o uninit
./uninit
# Output: forrtl: error (182): floating invalid
```

**`-init=snan` is protected from `-fpe3` override:**
```bash
# -init=snan with explicit -fpe3: compiler gives WARNING and overrides -fpe3
ifx -init=snan -fpe3 -traceback -g -O0 uninit.f90 -o uninit
# Compiler warning: '-init=snan' disables '-fpe3'
./uninit
# Output: forrtl: error (182): floating invalid (still caught!)
```

**Key difference:** `-init=snan` is **smart** - it protects itself and overrides conflicting `-fpe3`, while `-ftrapuv` can be overridden.

### Complete Test Matrix

| Command | Variables Initialized? | FPE Trapping? | Problem Caught? |
|---------|----------------------|---------------|-----------------|
| `ifx uninit.f90` | No (random) | No (default) | ❌ No |
| `ifx -ftrapuv uninit.f90` | Yes (sNaN) | Yes (auto -fpe0) | ✅ Yes |
| `ifx -ftrapuv -fpe3 uninit.f90` | Yes (sNaN) | No (overridden) | ❌ No |
| `ifx -ftrapuv -fpe0 uninit.f90` | Yes (sNaN) | Yes (explicit) | ✅ Yes |
| `ifx -init=snan uninit.f90` | Yes (sNaN) | Yes (auto) | ✅ Yes |
| `ifx -init=snan -fpe3 uninit.f90` | Yes (sNaN) | Yes (protected!) | ✅ Yes + Warning |
| `ifx -init=snan -fpe0 uninit.f90` | Yes (sNaN) | Yes (explicit) | ✅ Yes |

### Recommendations

**Best Practice - Use `-init=snan` for safety:**
```bash
# Safest: -init=snan protects against accidental -fpe3
ifx -init=snan -fpe0 -traceback -g -O0 uninit.f90 -o uninit
```

**Alternative - Use `-ftrapuv` but be careful:**
```bash
# Works great, but don't add -fpe3 after it!
ifx -ftrapuv -traceback -g -O0 uninit.f90 -o uninit
```

**What to avoid:**
- ❌ **Never** use `-ftrapuv -fpe3` (defeats the purpose)
- ❌ Don't assume `-ftrapuv` "only" initializes variables (it does more)
- ✅ Use `-init=snan` if you need fine control over FPE modes
- ✅ Understand that flag order matters on the command line (later flags can override earlier ones)

### Key Takeaways

- **-ftrapuv** is a composite flag that enables **both** `-init=snan` AND `-fpe0`
- **-ftrapuv** alone WILL catch uninitialized variable problems (includes FP trapping)
- **-ftrapuv -fpe3** explicitly will **NOT** catch FP exceptions (later `-fpe3` overrides earlier `-fpe0`)
- **Flag order matters**: later flags on the command line can override earlier ones
- **-init=snan** is "smarter" - it protects against `-fpe3` override (compiler warns and ignores `-fpe3`)
- **-init=snan -fpe3** still catches errors + gives compiler warning: `'-init=snan' disables '-fpe3'`
- **Recommendation:** Use `-init=snan -fpe0` (safest, most explicit) OR `-ftrapuv` (convenient, but don't add `-fpe3`)
- **-traceback** provides source file and line number on crashes
- **Always use -O0** with these flags (optimizations may eliminate the checks)
- Performance impact: moderate (use during testing, remove for production)
- These flags help catch hard-to-find bugs that cause intermittent failures

## Exercise 4: Runtime Checking (Bounds and Comprehensive)

### Goal
Catch array out-of-bounds access and other runtime errors using IFX runtime checks.

### Code: bounds_runtime.f90

```fortran
program bounds_runtime
    implicit none
    integer :: arr(5)
    integer :: i, idx
    
    arr = [1, 2, 3, 4, 5]
    
    ! Runtime bounds violation - read index from variable
    idx = 6
    print *, "Array element at index", idx, ":", arr(idx)
    
end program bounds_runtime
```

**Bug:** Array `arr` has 5 elements, but code tries to access index 6.

### Tasks

**4a. Default Build (No Runtime Checking)**

```bash
ifx bounds_runtime.f90 -o bounds_runtime
./bounds_runtime
```

**Expected:** Undefined behavior. May print garbage value, crash, or silently corrupt memory.

**4b. Enable Bounds Checking (-check bounds)**

```bash
ifx -check bounds -traceback -g bounds_runtime.f90 -o bounds_runtime
./bounds_runtime
```

**Expected:** Runtime error with exact location of bounds violation.

```
forrtl: severe (408): fort: (2): Subscript #1 of the array ARR has value 6 which is greater than the upper bound of 5

Image              PC                Routine            Line        Source
bounds_runtime     0000000000402E3C  MAIN__                 10  bounds_runtime.f90
...
```

**Note:** `-check bounds` adds runtime checks for:
- Array subscript bounds
- Substring bounds
- Pointer and allocatable array bounds

**4c. Enable All Runtime Checks (-check all)**

```bash
ifx -check all -traceback -g bounds_runtime.f90 -o bounds_runtime
./bounds_runtime
```

**Expected:** Same bounds violation error, but with comprehensive checking enabled.

```
forrtl: severe (408): fort: (2): Subscript #1 of the array ARR has value 6 which is greater than the upper bound of 5
...
```

**Note:** `-check all` enables comprehensive runtime checking including:
- **bounds** - Array and substring bounds
- **pointer** - Pointer and allocatable array association status
- **uninit** - Uninitialized variables (Linux only)
- **format** - Format string checking
- **arg_temp_created** - Argument aliasing
- And more...

### Individual Check Options

You can enable specific checks instead of all:

```bash
# Only bounds checking
ifx -check bounds program.f90

# Bounds and pointer checks
ifx -check bounds,pointer program.f90

# All checks except format
ifx -check all -check noformat program.f90
```

### Key Takeaways

- **-check bounds** catches out-of-bounds array access at runtime
- **-check all** enables maximum runtime checking (bounds + pointer + uninit + more)
- Provides exact line number and which subscript is out of bounds
- Shows the invalid value and the valid range
- **-check all disables optimization** (sets -O0 automatically) and overrides any -O level
- Performance impact: `-check bounds` moderate (10-50%), `-check all` severe (2-10x)
- Use during development and testing, remove for production builds
- Catches bugs that lead to crashes, memory corruption, or security vulnerabilities

### When to Use Each Check

| Check | When to Use | Performance Impact |
|-------|-------------|-------------------|
| `-check bounds` | Always during testing | Moderate (10-50%) |
| `-check pointer` | Testing with pointers/allocatables | Low |
| `-check uninit` | Debugging intermittent bugs | Moderate |
| `-check all` | Comprehensive testing | Severe (2-10x) |

## Exercise 5: Floating Point Exception Handling

### Goal
Detect floating-point errors like division by zero, overflow, underflow.

### Code: fpe.f90

```fortran
program fpe
    implicit none
    real :: a, b
    
    b = 3.0
    a = b / 0.0    ! Division by zero
    
    print *, a
end program fpe
```

**Bug:** Division by zero produces Inf by default (no error).

### Tasks

**5a. Default Build (No FP Exception Handling)**

```bash
ifx fpe.f90 -o fpe
./fpe
```

**Expected:** Prints `Infinity` or `Inf`. No error.

**Note:** By default, IFX uses `-fpe3` which disables all floating-point exception handling. Division by zero produces Inf, not an error.

**5b. Enable FP Exception Handling (-fpe0)**

```bash
ifx -fpe0 -traceback -g fpe.f90 -o fpe
./fpe
```

**Expected:** Runtime error at the division by zero.

```
forrtl: error (65): floating divide by zero
Image              PC                Routine            Line        Source
fpe                0000000000402D87  MAIN__                  6  fpe.f90
...
```

**Note:** `-fpe0` enables all floating-point exception handling:
- Division by zero
- Overflow
- Invalid operation (e.g., sqrt of negative number)

### FP Exception Levels

- **-fpe0** - Enable all FP exception handling (invalid, divide-by-zero, overflow)
- **-fpe1** - Enable invalid and divide-by-zero only
- **-fpe3** - Disable all FP exception handling (default)

### Key Takeaways

- **-fpe0** catches floating-point errors at runtime
- Default is **-fpe3** (all FP exceptions disabled)
- Catches division by zero, overflow, invalid operations
- Performance impact: minimal
- Recommended for scientific computing where NaN/Inf indicate errors
- Use during development to catch numerical issues early

## Exercise 6: Automatic Reallocation with `-assume realloc_lhs`

### Goal
Understand how `-assume realloc_lhs` controls automatic reallocation of allocatable arrays on assignment.

### Code: assume_realloc_lhs.f90

```fortran
program assume_realloc_lhs
   implicit none
   integer, allocatable :: x(:)
   allocate( x(2) )
   print *, "Before assignment x(2): shape(x) = ", shape(x)
   x = [ 1, 2, 3 ]
   print *, "After assignment [1,2,3]: shape(x) = ", shape(x)
end program assume_realloc_lhs
```

**Issue:** Allocatable array `x` is allocated with size 2, but we assign an array of size 3. What happens?

### Tasks

**6a. Default Behavior (Fortran 2003 Standard: Automatic Reallocation)**

```bash
ifx assume_realloc_lhs.f90 -o assume_realloc_lhs
./assume_realloc_lhs
```

**Expected output:**
```
Before assignment x(2): shape(x) =            2
After assignment [1,2,3]: shape(x) =            3
```

**Note:** By default, IFX follows the **Fortran 2003 standard** which requires automatic reallocation when an allocatable array on the left-hand side (LHS) of an assignment has a different shape than the right-hand side (RHS). The array is automatically deallocated and reallocated to match the RHS shape.

**6b. Disable Automatic Reallocation (-assume norealloc_lhs)**

```bash
ifx -assume norealloc_lhs assume_realloc_lhs.f90 -o assume_realloc_lhs
./assume_realloc_lhs
```

**Expected output:**
```
Before assignment x(2): shape(x) =            2
After assignment [1,2,3]: shape(x) =            2
```

**What happened:**
- `-assume norealloc_lhs` disables automatic reallocation (Fortran 95 behavior)
- The assignment tries to fit 3 elements into an array of size 2
- Only the first 2 elements are copied, the 3rd element is silently ignored
- **This is a potential bug!** No error, no warning, just wrong results

**6c. Enable Automatic Reallocation Explicitly (-assume realloc_lhs)**

```bash
ifx -assume realloc_lhs assume_realloc_lhs.f90 -o assume_realloc_lhs
./assume_realloc_lhs
```

**Expected output:**
```
Before assignment x(2): shape(x) =            2
After assignment [1,2,3]: shape(x) =            3
```

**Note:** `-assume realloc_lhs` explicitly enables automatic reallocation (default in IFX, Fortran 2003+ standard behavior).

### Understanding `-assume` Options

The `-assume` flag controls various runtime assumptions and behaviors:

**Reallocation-related:**
- **`-assume realloc_lhs`** - Enable automatic reallocation on assignment (default, F2003+)
- **`-assume norealloc_lhs`** - Disable automatic reallocation (F95 behavior)

**Other useful `-assume` options:**
```bash
# Byte order control
-assume byterecl          # RECL in OPEN specifies bytes (not words)

# Array bounds checking (alternative to -check bounds)
-assume nobounds_check    # Disable bounds checking (default)

# Buffering control
-assume buffered_io       # Use buffered I/O (default)
-assume nobuffered_io     # Disable buffering

# Dummy argument checking
-assume dummy_aliases     # Assume dummy arguments may alias (conservative)
-assume nodummy_aliases   # Assume no aliasing (allows more optimization)

# IEEE arithmetic
-assume ieee_fpe_flags    # Save/restore IEEE FPE flags on entry/exit

# Show all assume options
ifx -help assume
```

### Why This Matters

**Fortran 2003+ Standard Behavior (automatic reallocation):**
- ✅ **Safer**: Array always has correct size after assignment
- ✅ **More convenient**: Don't need to manually reallocate
- ⚠️ **Performance cost**: Reallocation involves deallocate + allocate + copy
- ⚠️ **Memory overhead**: Temporary allocation during assignment

**Legacy Fortran 95 Behavior (`-assume norealloc_lhs`):**
- ⚠️ **Dangerous**: Silent truncation if RHS doesn't fit
- ⚠️ **Hard to debug**: No error, wrong results
- ✅ **Faster**: No reallocation overhead
- ✅ **Predictable memory**: No hidden allocations

**Real-world example where this matters:**
```fortran
! Reading variable-length data
integer, allocatable :: buffer(:)
allocate(buffer(100))

! Later in code, read different sizes
buffer = read_data_from_file(filename1)  ! Returns 150 elements
! With realloc_lhs: buffer automatically resized to 150 ✅
! With norealloc_lhs: only first 100 copied, data loss! ❌

buffer = read_data_from_file(filename2)  ! Returns 50 elements  
! With realloc_lhs: buffer resized to 50 ✅
! With norealloc_lhs: only 50 elements updated, leftover data from before! ❌
```

### When to Use Each Option

**Use default (`-assume realloc_lhs`):**
- ✅ New code (Fortran 2003+)
- ✅ When correctness is critical
- ✅ When array sizes change dynamically
- ✅ When you want standard-compliant behavior

**Use `-assume norealloc_lhs` only if:**
- ⚠️ Porting legacy Fortran 95 code that depends on old behavior
- ⚠️ Performance-critical loop where reallocation overhead is measured and significant
- ⚠️ You have verified all assignments have matching shapes
- ⚠️ You understand the risks and have thorough testing

### Key Takeaways

- **Default (IFX)**: Automatic reallocation enabled (Fortran 2003+ standard)
- **`-assume realloc_lhs`**: Explicitly enable automatic reallocation (safe, standard-compliant)
- **`-assume norealloc_lhs`**: Disable automatic reallocation (dangerous, legacy F95 behavior)
- **Silent data loss**: `-assume norealloc_lhs` can truncate data without warning
- **Performance trade-off**: Automatic reallocation is safer but slower
- **Best practice**: Use default behavior unless you have a specific reason and thorough testing
- **Legacy code**: May need `-assume norealloc_lhs` for exact F95 behavior
- **Check `-help assume`**: Many other runtime behavior options available

## Running All Exercises

Use the provided script to run all exercises automatically:

```bash
# Run all exercises
./run_exercises.sh all

# Run individual exercise
./run_exercises.sh 1  # Warning levels
./run_exercises.sh 2  # Standard conformance
./run_exercises.sh 3  # Uninitialized variables
./run_exercises.sh 4  # Runtime checking (bounds + comprehensive)
./run_exercises.sh 5  # FP exceptions
./run_exercises.sh 6  # Automatic reallocation (-assume)
```

The script shows:
- Code being compiled (with highlighted sections)
- Commands being executed
- Expected output and error messages
- Educational notes after each section

## Debugging Command Patterns

### Development Build (Recommended for Debugging)

```bash
ifx -g -O0 -traceback -warn unused -check all program.f90 -o program
```

**Includes:**
- `-g` - Debug symbols
- `-O0` - No optimization
- `-traceback` - Source location on errors
- `-warn unused` - Catch unused variables
- `-check all` - Comprehensive runtime checks

### Testing Build (Balanced Checking)

```bash
ifx -g -O0 -traceback -check bounds -fpe0 program.f90 -o program
```

**Includes:**
- `-g -O0` - Debug-friendly
- `-traceback` - Error locations
- `-check bounds` - Catch array errors
- `-fpe0` - Catch FP errors

### Production Build (Optimized, Minimal Checks)

```bash
ifx -O2 -xHost program.f90 -o program
```

**Includes:**
- `-O2` - Standard optimizations
- `-xHost` - Optimize for current CPU
- No runtime checks (maximum performance)

## Summary of Key Flags

### Debug Information
- **-g** - Add debug symbols (file names, line numbers, variables)
- **-O0** - Disable optimization (keep code structure intact)
- **-traceback** - Show source location on runtime errors

### Compile-Time Checks
- **-warn unused** - Warn about unused variables
- **-warn uncalled** - Warn about uncalled functions
- **-stand f18** - Enforce Fortran 2018 standard

### Runtime Checks
- **-ftrapuv** - Initialize locals to trap values
- **-check bounds** - Array bounds checking
- **-check all** - All runtime checks (disables optimization)
- **-fpe0** - Enable floating-point exception handling

### Important Combinations
- Always use **-O0** with runtime checks
- Always use **-traceback** with runtime checks
- Use **-g** with debuggers (gdb, cuda-gdb)
- Combine **-ftrapuv** with **-fpe0** to catch FP exceptions
- **-init=snan** disables default `-fpe3`; we explicitly add **-fpe0** for clarity

## Performance Impact

| Flag | Compile Time | Runtime | Executable Size |
|------|--------------|---------|-----------------|
| `-g` | +5-10% | None | +50-100% |
| `-O0` | -20-30% | +50-200% | +0-20% |
| `-warn unused` | +1-2% | None | None |
| `-ftrapuv -O0` | +5-10% | +20-50% | +10-30% |
| `-check bounds` | +5-15% | +10-50% | +10-30% |
| `-check all` | +10-30% | +100-500% | +30-100% |
| `-fpe0` | +1-5% | +1-10% | +1-5% |

**Note:** Percentages are approximate and depend heavily on the code.

## Best Practices

### 1. Development Workflow

**Phase 1: Initial Development**
```bash
ifx -g -O0 -warn unused -check all -fpe0 -traceback program.f90
```
Maximum checking to catch bugs early.

**Phase 2: Testing**
```bash
ifx -g -O0 -check bounds -fpe0 -traceback program.f90
```
Keep critical runtime checks.

**Phase 3: Production**
```bash
ifx -O2 -xHost program.f90
```
Remove all checks for performance.

### 2. Debugging with GDB

```bash
# Compile with debug info
ifx -g -O0 -traceback program.f90 -o program

# Run in gdb
gdb ./program

# Common gdb commands
(gdb) run              # Run program
(gdb) break main       # Set breakpoint
(gdb) next             # Next line
(gdb) print variable   # Print variable value
(gdb) backtrace        # Show call stack
```

### 3. When Runtime Checks Fail

Runtime checks are EXPENSIVE. If your production code is too slow:

1. **Profile first** - Find actual bottlenecks
2. **Remove checks selectively** - Keep bounds checking if possible
3. **Test thoroughly** - Run test suite without checks
4. **Use assertions** - Add manual checks in critical sections

### 4. Standard Conformance

Always use `-stand f23` (or `-stand f18`) during development to ensure:
- Code works on other compilers (gfortran, NAG, etc.)
- No use of deprecated features
- Portable code across platforms

### 5. Warning Management

Start strict, relax only when necessary:

```bash
# Start here (maximum warnings)
ifx -warn all program.f90

# Suppress specific warnings only when justified
ifx -warn all -warn nounused program.f90
```

## Common Errors and Solutions

### Error 1: "Segmentation fault" with no traceback

**Solution:** Recompile with `-traceback -g`:
```bash
ifx -traceback -g program.f90 -o program
./program
```

### Error 2: Optimized code behaves differently than debug code

**Cause:** Undefined behavior (uninitialized variables, bounds violations)

**Solution:** Run with comprehensive checks:
```bash
ifx -g -O0 -check all -ftrapuv -traceback program.f90
./program
```

### Error 3: Code works on one machine but crashes on another

**Cause:** Stack size, uninitialized variables, or memory corruption

**Solution:** 
1. Increase stack size: `ulimit -s unlimited`
2. Use runtime checks to find the bug
3. Check for uninitialized variables with `-ftrapuv`

### Error 4: Runtime checks make code 10x slower

**Expected:** `-check all` disables optimization and adds significant overhead.

**Solution:** Use selective checks for production:
```bash
# Keep only critical checks
ifx -O2 -check bounds -fpe0 program.f90
```

### Error 5: False positive from `-check uninit`

**Note:** `-check uninit` (Linux only) can have false positives.

**Solution:** Use `-ftrapuv` instead for uninitialized variable detection:
```bash
ifx -ftrapuv -traceback -g -O0 program.f90
```

## Resources

### Intel Documentation
- [Intel® Fortran Compiler Developer Guide and Reference](https://www.intel.com/content/www/us/en/docs/fortran-compiler/developer-guide-reference/2025-3/overview.html)

### Debugging Tools
- **gdb** - GNU Debugger (works with `-g` flag)
- **valgrind** - Memory error detection (Linux)
- **Intel Inspector** - Memory and thread error detection

### Online Resources
- [Compiler Explorer (Godbolt)](https://godbolt.org) - Compare different compiler flags online
- Use Intel compilers to see differences in warning/error messages

## Conclusion

This lab demonstrated essential compiler debugging options for Fortran development with IFX:

1. **Warnings** (-warn unused) catch typos and dead code early
2. **Standard conformance** (-stand f18) ensures portability
3. **Uninitialized variable detection** (-ftrapuv) catches undefined behavior
4. **Bounds checking** (-check bounds) prevents memory corruption
5. **FP exception handling** (-fpe0) catches numerical errors
6. **Comprehensive checking** (-check all) provides maximum safety

**Key Message:** Use aggressive checking during development, remove for production. The compiler is your first line of defense against bugs!
