# Quick Reference: IFX Debugging Options

## Essential Command Patterns

### Development Build (Maximum Safety)
```bash
ifx -g -O0 -traceback -warn unused -check all -fpe0 program.f90 -o program
```

### Testing Build (Balanced)
```bash
ifx -g -O0 -traceback -check bounds -fpe0 program.f90 -o program
```

### Production Build (Maximum Performance)
```bash
ifx -O2 -xHost program.f90 -o program
```

## Debug Information Flags

| Flag | Purpose | When to Use |
|------|---------|-------------|
| `-g` | Add debug symbols | Always when debugging with gdb |
| `-O0` | Disable optimization | Always when debugging |
| `-O2` | Standard optimization | Production builds only |
| `-O3` | Aggressive optimization | Production (benchmark first) |
| `-traceback` | Show source location on error | Always with runtime checks |

## Warning Flags

| Flag | Purpose | Default? |
|------|---------|----------|
| `-warn unused` | Enable unused variable remarks | No (use this for development) |
| `-warn nounused` | Suppress unused variable remarks | **Yes** (default) |
| `-warn uncalled` | Enable uncalled function remarks | Yes (as remarks) |
| `-warn nouncalled` | Suppress uncalled function remarks | No |
| `-warn all` | Enable all warnings | No |

**Note:** Default is `-warn nounused` (no unused variable remarks). Uncalled functions produce remarks by default.

## Standard Conformance

| Flag | Purpose | Use Case |
|------|---------|----------|
| `-stand f95` | Fortran 95 standard | Legacy code |
| `-stand f03` | Fortran 2003 standard | Modern code |
| `-stand f08` | Fortran 2008 standard | Modern code |
| `-stand f18` | Fortran 2018 standard | Modern code |
| `-stand f23` | Fortran 2023 standard | Recommended for new code |

## Runtime Checks

| Flag | Detects | Performance Impact | Recommendation |
|------|---------|-------------------|----------------|
| `-ftrapuv` | Uninitialized variables | Moderate | Use during testing |
| `-init=snan` | Uninitialized (with FP exceptions) | Moderate | Alternative to -ftrapuv |
| `-check bounds` | Array bounds violations | Moderate (10-50%) | Use during testing |
| `-check pointer` | Invalid pointer use | Low | Use when debugging pointers |
| `-check uninit` | Uninitialized variables (Linux) | Moderate | Can have false positives |
| `-check all` | All runtime errors | Severe (2-10x) | Development only |

**Note:** `-check all` automatically sets `-O0` and overrides any `-O` level.

## Floating-Point Exception Handling

| Flag | Catches | Default |
|------|---------|---------|
| `-fpe0` | Invalid, divide-by-zero, overflow | Use for debugging |
| `-fpe1` | Invalid, divide-by-zero only | Common choice |
| `-fpe3` | No FP exceptions | **Default** (silent Inf/NaN) |

## Common Flag Combinations

### Finding Uninitialized Variables
```bash
ifx -ftrapuv -traceback -g -O0 program.f90
```

### Finding Array Bounds Errors
```bash
ifx -check bounds -traceback -g program.f90
```

### Finding Floating-Point Errors
```bash
ifx -fpe0 -traceback -g program.f90
```

### Comprehensive Debugging
```bash
ifx -g -O0 -traceback -check all -ftrapuv -fpe0 program.f90
```

### Standard Conformance Testing
```bash
ifx -stand f23 -warn all program.f90
```

## Optimization Levels

| Level | Description | When to Use |
|-------|-------------|-------------|
| `-O0` | No optimization | Debugging only |
| `-O1` | Light optimization | Rarely used |
| `-O2` | Standard optimization | Default for production |
| `-O3` | Aggressive optimization | After profiling |
| `-xHost` | Optimize for current CPU | Production (not portable) |

**NEVER debug optimized code!** Always use `-O0` when debugging.

## Module Loading (Setup)

```bash
# Load IFX compiler
module switch stack stack/24.6.0
module load intel/2025.3.0

# Verify
ifx --version
```

Or use the script:
```bash
source setup_ifx.sh
```

## Running the Lab

```bash
# Run all exercises
./run_exercises.sh all

# Run specific exercise
./run_exercises.sh 1    # Warning levels
./run_exercises.sh 2    # Standard conformance
./run_exercises.sh 3    # Uninitialized variables
./run_exercises.sh 4    # Runtime checking (bounds + comprehensive)
./run_exercises.sh 5    # FP exceptions
./run_exercises.sh 6    # Automatic reallocation (-assume)
```

## Manual Exercise Commands

### Exercise 1: Warnings
```bash
ifx warn.f90 -o warn                        # Default (nounused is default)
ifx -warn unused warn.f90 -o warn           # Enable unused variable remarks
ifx -warn nounused warn.f90 -o warn         # Explicit suppress (same as default)
ifx -warn nouncalled warn.f90 -o warn       # Suppress uncalled function remarks
ifx -warn all warn.f90 -o warn              # Enable all warnings
```

### Exercise 2: Standards
```bash
ifx standard.f90 -o standard                # Default (lenient)
ifx -stand f18 standard.f90 -o standard    # Fortran 2018 standard
```

### Exercise 3: Uninitialized Variables
```bash
ifx uninit.f90 -o uninit && ./uninit                                    # Default (undefined)
ifx -ftrapuv -traceback -g -O0 uninit.f90 -o uninit && ./uninit        # Trap uninitialized
ifx -init=snan -fpe0 -traceback -g -O0 uninit.f90 -o uninit && ./uninit  # Signaling NaN
```

### Exercise 4: Runtime Checking (Bounds + Comprehensive)
```bash
ifx bounds_runtime.f90 -o bounds_runtime && ./bounds_runtime                          # Default (no check)
ifx -check bounds -traceback -g bounds_runtime.f90 -o bounds_runtime && ./bounds_runtime  # Bounds only
ifx -check all -traceback -g bounds_runtime.f90 -o bounds_runtime && ./bounds_runtime     # Comprehensive
```

### Exercise 5: FP Exceptions
```bash
ifx fpe.f90 -o fpe && ./fpe                          # Default (silent Inf)
ifx -fpe0 -traceback -g fpe.f90 -o fpe && ./fpe      # Catch FP exceptions
```

### Exercise 6: Automatic Reallocation
```bash
ifx assume_realloc_lhs.f90 -o assume_realloc_lhs && ./assume_realloc_lhs                    # Default (auto realloc)
ifx -assume norealloc_lhs assume_realloc_lhs.f90 -o assume_realloc_lhs && ./assume_realloc_lhs  # Disable (F95 behavior)
ifx -assume realloc_lhs assume_realloc_lhs.f90 -o assume_realloc_lhs && ./assume_realloc_lhs    # Explicit enable
```

## Debugging with GDB

```bash
# Compile with debug info
ifx -g -O0 program.f90 -o program

# Run in gdb
gdb ./program

# Common gdb commands
(gdb) run                    # Run program
(gdb) break main             # Set breakpoint at main
(gdb) break file.f90:42      # Set breakpoint at line 42
(gdb) next                   # Execute next line (step over)
(gdb) step                   # Step into function
(gdb) continue               # Continue execution
(gdb) print variable         # Print variable value
(gdb) info locals            # Show all local variables
(gdb) backtrace              # Show call stack
(gdb) where                  # Alias for backtrace
(gdb) quit                   # Exit gdb
```

## Error Message Examples

### Uninitialized Variable (-ftrapuv)
```
forrtl: severe (174): SIGSEGV, segmentation fault occurred
```

### Bounds Violation (-check bounds)
```
forrtl: severe (408): fort: (2): Subscript #1 of the array ARR has value 6 which is greater than the upper bound of 5
```

### FP Exception (-fpe0)
```
forrtl: error (65): floating divide by zero
forrtl: error (65): floating invalid
```

### Unused Variable (-warn unused)
```
warn.f90(4): warning #7712: This variable has not been used.   [ABC]
```

## Performance Impact Summary

| Check Type | Compile Time | Runtime | Executable Size |
|------------|--------------|---------|-----------------|
| `-g` | +5-10% | 0% | +50-100% |
| `-O0` vs `-O2` | -20-30% | +50-200% | +10-20% |
| `-warn unused` | +1-2% | 0% | 0% |
| `-ftrapuv` | +5-10% | +20-50% | +10-30% |
| `-check bounds` | +5-15% | +10-50% | +10-30% |
| `-check all` | +10-30% | +100-500% | +30-100% |
| `-fpe0` | +1-5% | +1-10% | +1-5% |

## Best Practices Checklist

- [ ] Use `-g -O0` for all debugging sessions
- [ ] Never debug optimized code (`-O2`/`-O3`)
- [ ] Use `-traceback` with all runtime checks
- [ ] Enable `-warn unused` during development
- [ ] Test with `-check bounds` before release
- [ ] Use `-stand f23` (or `-stand f18`) to ensure portability
- [ ] Remove runtime checks for production builds
- [ ] Profile before and after optimization
- [ ] Test thoroughly after removing checks

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Segfault, no traceback | Add `-traceback -g` |
| Works in debug, fails in optimized | Undefined behavior - use `-check all` |
| Intermittent crashes | Use `-ftrapuv` to find uninitialized variables |
| Different results on different machines | Use `-fpe0` to catch FP errors |
| Code too slow with checks | Remove checks selectively, profile first |
| False positive from `-check uninit` | Use `-ftrapuv` instead |

## Quick Decision Tree

**Starting a new project?**
→ Use: `-g -O0 -warn unused -check all -fpe0 -traceback`

**Debugging a crash?**
→ Use: `-g -O0 -traceback -check all -ftrapuv`

**Finding array bounds error?**
→ Use: `-check bounds -traceback -g`

**Finding uninitialized variable?**
→ Use: `-ftrapuv -traceback -g -O0`

**Testing for production?**
→ Use: `-g -O0 -check bounds -fpe0 -traceback`

**Building for production?**
→ Use: `-O2 -xHost` (remove all checks)

**Ensuring portability?**
→ Use: `-stand f23 -warn all`

## Additional Resources

- **Intel® Fortran Compiler Developer Guide and Reference:** https://www.intel.com/content/www/us/en/docs/fortran-compiler/developer-guide-reference/2025-3/overview.html
- **Compiler Explorer (Godbolt):** https://godbolt.org
- **GDB Manual:** https://www.gnu.org/software/gdb/documentation/

## Runtime Checks: Critical Distinctions

### -ftrapuv vs -ftrapv (IMPORTANT!)

| Flag | Purpose | ifort | ifx | gfortran |
|------|---------|-------|-----|----------|
| **`-ftrapuv`** (with 'u') | Trap **u**ninitialized variables | ✅ | ✅ | ✅ |
| **`-ftrapv`** (no 'u') | Trap integer over**f**low | ❌ | ❌ | ✅ |

**The extra "u" makes ALL the difference!**

- `-ftrapuv` = `-init=snan` + `-fpe0` (catches uninitialized variables)
- `-ftrapv` is **ignored** by Intel compilers (they print a warning)
- For integer overflow detection, use `integer(kind=8)` or test with `gfortran -ftrapv`

### Using -dryrun to Understand Flags

```bash
# See what the compiler driver actually passes to the backend
ifx -ftrapuv -g -O0 program.f90 -dryrun 2>&1 | grep -E "fpe|init"
# Shows: -fpe0 and "-init snan"
```

## File Overview

- `warn.f90` - Warning test (unused variables)
- `standard.f90` - Standard conformance test
- `uninit.f90` - Uninitialized variable test
- `bounds_runtime.f90` - Runtime bounds violation test
- `fpe.f90` - Floating-point exception test
- `assume_realloc_lhs.f90` - Automatic reallocation test
- `setup_ifx.sh` - Environment setup script
- `run_exercises.sh` - Automated exercise runner
- `README.md` - Complete lab documentation
- `QUICK_REFERENCE.md` - This file
